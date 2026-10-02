// The one place in the UI that talks to z_core.
//
// Why it exists at all: the owner's rule for M7 is that no number on screen is
// invented here. So every field below is a value the core handed over, and the
// only way it changes is a call that went to Rust and came back. A screen reads
// these fields; it never computes one.
//
// It also means a mistake is findable: if a count is wrong, it is wrong in the
// core or in the refresh below — never in a widget.
import 'dart:async';

import 'package:flutter/foundation.dart';

// Prefixed on purpose: every line below that says `z.` is a call into Rust, and
// the prefix makes that visible when reading the file rather than guessing.
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/document_text.dart' show rememberKinds;
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/core/messages.dart';

/// What the app knows before any document exists: the ground the Workspace stands
/// on, and what Home draws.
class Ground extends ChangeNotifier {
  HomeSnapshot? home;
  VaultSnapshot? vaultSnap;
  PrivacyRulesSnapshot? privacyRules;
  ProviderSnapshot? providerSnap;
  String? trouble;

  VaultState get vault => home?.vault ?? VaultState.absent;
  List<ProfileRow> get profiles => home?.profiles ?? const [];
  List<PackRow> get packs => home?.packs ?? const [];

  /// The rule sets this build carries. A pack and a rule set are the same
  /// thing seen from two screens, and both are read from the core so that
  /// adding a language never means editing a list in Dart.
  List<PackRow> get ruleSets => packs;
  List<ProviderFact> get providers => home?.providers ?? const [];
  int get entityCount => home?.identityCount ?? 0;
  int get valueCount => home?.valueCount ?? 0;
  Settings? get config => home?.settings;
  List<KindRow> get kinds => home?.kinds ?? const [];

  /// Read it all again from Rust. One snapshot per screen, not a handful of
  /// calls that can disagree.
  Future<void> refresh() async {
    try {
      home = await z.homeSnapshot();
      vaultSnap = await z.vaultSnapshot();
      privacyRules = (home?.vault == VaultState.unlocked)
          ? await z.privacyRulesSnapshot(profileId: null)
          : null;
      providerSnap = await z.providerSnapshot();
      rememberKinds(kinds);
      trouble = null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  /// Change one thing about the settings and write them back.
  Future<String?> saveConfig(Settings next) async {
    try {
      await z.saveSettings(settings: next);
      await refresh();
      return null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return humanMessage(e);
    }
  }

  String nameOfKind(Kind k) {
    for (final row in kinds) {
      if (row.kind == k) return row.label;
    }
    // Before the list has loaded. Never a made-up name for a kind.
    return '…';
  }

  int get connectedProviders => providers.where((p) => p.connected).length;

  /// Hand a provider its credential, or set up a model on this machine with no
  /// credential at all. Returns the reason it did not work, or null.
  ///
  /// Nothing comes back but a row: there is no call in the whole contract that
  /// returns a credential, and this method could not leak one if it tried.
  Future<String?> connect({
    required String id,
    required String credential,
    required String baseUrl,
    required String model,
  }) async {
    try {
      await z.connectProvider(
        provider: ProviderId(id: id),
        credential: credential,
        baseUrl: baseUrl.trim().isEmpty ? null : baseUrl.trim(),
        model: model.trim().isEmpty ? null : model.trim(),
      );
      await refresh();
      return null;
    } on ApiError catch (e) {
      return humanMessage(e);
    }
  }

  // ---------------------------------------------------------------- the vault
  //
  // Everything below reads and writes the vault through the core. The UI holds
  // no value: a card is asked for when it is opened, and a revealed value lives
  // in the same short-lived map the tokens panel uses.

  List<EntityRow> vaultRows = const [];
  String vaultQuery = '';

  /// Read the vault's list again — the search is the list, with a query.
  Future<void> readVault() async {
    if (vault != VaultState.unlocked) {
      vaultRows = const [];
      privacyRules = null;
      notifyListeners();
      return;
    }
    try {
      vaultRows = await z.searchVault(query: vaultQuery);
      privacyRules = await z.privacyRulesSnapshot(profileId: null);
      trouble = null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  Future<void> searchVaultFor(String query) async {
    vaultQuery = query;
    await readVault();
  }

  /// Run one change against the vault and read everything back. Returns the
  /// reason it did not work, or null.
  ///
  /// One path for every edit, because every edit has the same two obligations:
  /// the vault is re-sealed by the core, and the screen is re-read from it
  /// rather than patched in place.
  Future<String?> vaultEdit(Future<void> Function() act) async {
    try {
      await act();
      await refresh();
      await readVault();
      return null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return humanMessage(e);
    }
  }

  Future<String?> forget(String id) async {
    try {
      await z.disconnectProvider(provider: ProviderId(id: id));
      await refresh();
      return null;
    } on ApiError catch (e) {
      return humanMessage(e);
    }
  }
}

/// One conversation: the document, what was found in it, and what would leave.
///
/// Everything here is refreshed from the core together, because the core's own
/// `revision` ties them: a document view and a scan report from two different
/// revisions would be two different documents.
class Workbench extends ChangeNotifier {
  Workbench({
    required this.session,
    required this.profileId,
    required this.packId,
  });

  final SessionId session;
  String? profileId;
  final String packId;

  WorkspaceSnapshot? snap;
  ScanReport? report;
  String? trouble;
  bool busy = false;

  DocumentView? get document => snap?.document;
  List<Finding> get findings => snap?.findings ?? const [];
  List<TokenRow> get tokens => snap?.tokens ?? const [];
  Revision get revision => Revision(n: snap?.revision ?? 0);
  PayloadHandle? get handle => snap?.handle;
  PayloadView? get payload => snap?.payload;
  List<AnswerId> get answers => snap?.answers ?? const [];
  ScanOrigin get scanOrigin => snap?.scanOrigin ?? ScanOrigin.notScanned;

  /// Chips or plain, on the Safe side. A drawing choice; the string is the same.
  bool chips = true;

  /// What the user has selected on the Original side, and what the core says it
  /// is. The view is **never** worked out here: the Protect button's five states
  /// are `SelectionView`, decided in Rust by the same code that would do the
  /// protecting.
  Span? selection;
  SelectionView? selected;

  /// Matches what `undoLastProtection` would actually do.
  bool get canUndo => snap?.canUndo ?? false;

  /// Which tokens are showing their value right now.
  ///
  /// The text is here because the core handed it over once, when it was asked
  /// for. **Whether it may still be here is the core's answer, not this map's**
  /// — `syncReveals` asks and drops the rest. Revealing still writes nothing
  /// into the payload; what changed is that «the showing lives in the UI» is no
  /// longer true, because a screen cannot be the authority on how long a secret
  /// stays on it.
  final Map<String, String> revealed = {};
  bool tokensOpen = false;

  /// The review panel, and which finding it is pointing at.
  bool reviewOpen = false;
  int? focused;

  /// Walking mode: one suggestion at a time, with its sentence around it.
  bool walking = false;

  List<Finding> get suggested => findings
      .where((f) => f.state == MarkState.suggested)
      .toList(growable: false);

  /// Grouped by **who decided**, not by who found.
  ///
  /// Confirming the pack's suggestion is your decision, and a list that filed
  /// it under «protected automatically» would be telling you the app did
  /// something you did. Each row still names the layer that found it.
  List<Finding> get automatic => findings
      .where((f) => f.state == MarkState.protected && !f.decided)
      .toList(growable: false);
  List<Finding> get byHand => findings
      .where((f) => f.state == MarkState.protected && f.decided)
      .toList(growable: false);

  Finding? get focusedFinding {
    final id = focused;
    if (id == null) return null;
    for (final f in findings) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The three questions the owner says a user must always be able to answer by
  /// looking. These getters exist so a screen never has to work one out.
  ///
  ///   what do I have?      → [document] (the Original side)
  ///   what will leave?     → the Safe side, built in Rust, from M7.2
  ///   why was this hidden? → [findings], each carrying its own source and reason
  int get protectedCount =>
      (snap?.autoProtected ?? 0) + (snap?.userProtected ?? 0);
  int get openSuggestions => snap?.openSuggestions ?? 0;
  int get normalCount => snap?.normal ?? 0;

  Future<void> refresh() async {
    try {
      snap = await z.workspaceSnapshot(session: session);
      profileId = snap?.profileId;
      trouble = null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  /// A refusal has to outlive the refresh that follows it.
  ///
  /// `refresh()` clears `trouble` when it succeeds — and it does succeed, because
  /// asking for a snapshot is not the act that was refused. For a while that
  /// erased the sentence the core had produced one line earlier, and the press
  /// looked like success: «Always» with no vault changed nothing and said
  /// nothing (human run, 30 September). The snapshot is still taken, because the
  /// screen must show what is true now; only the sentence survives it.
  Future<void> _refreshKeeping(String? refusal) async {
    await refresh();
    if (refusal != null) trouble = refusal;
  }

  Future<String?> switchProfile(String? next) async {
    try {
      await z.switchProfile(session: session, profileId: next);
      await refresh();
      return null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return humanMessage(e);
    }
  }

  /// A scan is not a screen (the behaviour board): it runs on import, and this is
  /// the same call the Rescan button makes later.
  Future<void> rescan() async {
    busy = true;
    notifyListeners();
    String? refused;
    try {
      report = await z.scan(session: session);
      trouble = null;
    } on ApiError catch (e) {
      refused = humanMessage(e);
      trouble = refused;
    }
    busy = false;
    await _refreshKeeping(refused);
  }

  void showChips(bool on) {
    chips = on;
    notifyListeners();
  }

  /// The user drew a selection. Ask the core what it is before offering any act.
  Future<void> select(Span? span) async {
    selection = span;
    if (span == null || span.end <= span.start) {
      selected = null;
      notifyListeners();
      return;
    }
    try {
      selected = await z.inspectSelection(session: session, span: span);
      trouble = null;
    } on ApiError catch (e) {
      selected = null;
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  /// Protect what is selected. Returns what the core did, so the screen can say
  /// it — «protected in 4 places», «it snapped to two whole items».
  Future<ProtectOutcome?> protectSelection({
    required Scope scope,
    required Kind kind,
    required bool allMatches,
  }) async {
    final span = selection;
    if (span == null) return null;
    try {
      final outcome = allMatches
          ? await z.protectAllMatches(
              session: session,
              span: span,
              scope: scope,
              kind: kind,
            )
          : await z.protect(
              session: session,
              span: span,
              scope: scope,
              kind: kind,
            );
      await refresh();
      // The selection still stands, but what it *is* has changed.
      await select(span);
      return outcome;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return null;
    }
  }

  void openTokens(bool on) {
    tokensOpen = on;
    notifyListeners();
  }

  /// Show one value, for as long as the core says and no longer. The core hands
  /// over a `ttl_ms` with it; the countdown is the UI's to keep, and a value
  /// that outlived it is hidden on the next look rather than left on screen.
  Future<void> reveal(String token) async {
    try {
      final shown = await z.reveal(session: session, token: token);
      revealed[token] = shown.value;
      trouble = null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  Future<void> hideToken(String token) async {
    revealed.remove(token);
    try {
      await z.hide_(session: session, token: token);
    } on ApiError catch (e) {
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  /// Ask the core what may still be shown, and drop whatever it no longer
  /// lists — a window that ran out, or a vault that locked.
  ///
  /// Called about once a second by the panel, which is why it must not be a way
  /// of *using* the vault: `revealedTokens` judges the clock and renews
  /// nothing, so a value sitting on screen cannot hold the vault open.
  Future<void> syncReveals() async {
    if (revealed.isEmpty) return;
    try {
      final live = await z.revealedTokens(session: session);
      final names = live.map((r) => r.token).toSet();
      final gone = revealed.keys.where((t) => !names.contains(t)).toList();
      if (gone.isEmpty) return;
      for (final t in gone) {
        revealed.remove(t);
      }
    } catch (e) {
      // The authority could not be asked — a closed conversation answers
      // `InvalidSession` to every question about it — so nothing may stay
      // uncovered. A screen that keeps a value because the question failed is
      // deciding for itself how long a secret stays on it, which is the one
      // thing this design does not allow it to do. Hide first, then say why.
      revealed.clear();
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- sending

  /// Which answer is on screen. The list itself comes from the snapshot.
  AnswerId? showing;
  PayloadHandle? copiedPayload;
  bool sending = false;

  /// Send the built payload to a provider.
  ///
  /// Nothing about the outgoing text is decided here: the handle was built by
  /// the core, audited by the core, and is refused by the core if the session
  /// has moved since. This method's whole job is to pass it on and say what
  /// came back.
  Future<String?> send(String providerId) async {
    final h = handle;
    if (h == null) return 'There is nothing to send yet.';
    sending = true;
    notifyListeners();
    try {
      final answer = await z.send(
        handle: h,
        provider: ProviderId(id: providerId),
      );
      showing = answer;
      trouble = null;
      sending = false;
      await refresh();
      return null;
    } on ApiError catch (e) {
      sending = false;
      trouble = humanMessage(e);
      notifyListeners();
      return humanMessage(e);
    }
  }

  /// The other door: the user took the safe text to a model themselves and is
  /// bringing the answer back. Restoring works exactly the same way — the token
  /// store does not care how the answer travelled.
  Future<String?> pasteAnswer(String raw) async {
    if (raw.trim().isEmpty) return 'Nothing was pasted.';
    final copied = copiedPayload;
    if (copied == null)
      return 'Copy the safe text first, so the answer can be tied to that payload.';
    try {
      final answer = await z.ingestAnswer(payload: copied, raw: raw);
      showing = answer;
      trouble = null;
      await refresh();
      return null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return humanMessage(e);
    }
  }

  /// One read for everything about one answer: both views, its position, and
  /// which answers sit either side of it.
  ///
  /// The screen used to fetch the two views here and count `2 of 2` from a
  /// Dart list — two sources for one fact. Navigation would have made that a
  /// third, and a stale neighbour is how «Answer 1» ends up drawn while the
  /// copy button still belongs to «Answer 2».
  Future<AnswerSnapshot> answerFacts(AnswerId answer) =>
      z.answerSnapshot(session: session, answer: answer);

  void rememberCopiedPayload() {
    copiedPayload = handle;
  }

  void show(AnswerId? answer) {
    showing = answer;
    notifyListeners();
  }

  /// Leaving the vault, or the workspace, re-hides everything that was shown —
  /// and says so to the core, which is where a reveal now lives.
  void hideEverything() {
    // The core is told either way: it is the one that holds a reveal now, and
    // this is called from `dispose`, where nothing may depend on a listener.
    unawaited(z.hideAllReveals());
    if (revealed.isEmpty) return;
    revealed.clear();
    notifyListeners();
  }

  void openReview({bool? walk}) {
    reviewOpen = true;
    if (walk != null) walking = walk;
    // Walking starts at the first thing still waiting, not at the top of a list
    // the user has already been through.
    if (walking) focused ??= suggested.isEmpty ? null : suggested.first.id;
    notifyListeners();
  }

  void closeReview() {
    reviewOpen = false;
    notifyListeners();
  }

  void focusOn(int? id) {
    focused = id;
    notifyListeners();
  }

  /// Answer one suggestion. `Skip` is an answer that decides nothing: the core
  /// keeps it open and still counts it, which is why Send stays shut.
  Future<void> answer(int finding, FindingAnswer choice) async {
    String? refused;
    try {
      report = await z.answerFinding(
        session: session,
        finding: finding,
        answer: choice,
      );
      trouble = null;
    } on ApiError catch (e) {
      refused = humanMessage(e);
      trouble = refused;
    }
    await _refreshKeeping(refused);
    if (selection != null) await select(selection);
    // Step on to the next one still waiting, so walking is a walk.
    if (walking) {
      final left = suggested;
      focused = left.isEmpty
          ? null
          : (left.firstWhere(
              (f) => f.id != finding,
              orElse: () => left.first,
            )).id;
      if (left.isEmpty) walking = false;
    }
    notifyListeners();
  }

  /// Remember a Not Sensitive decision beyond this document. Plain
  /// `Not sensitive` remains session-only; this is the explicit durable path.
  Future<void> teachException(int finding, Scope scope) async {
    String? refused;
    try {
      report = await z.teachException(
        session: session,
        finding: finding,
        scope: scope,
      );
      trouble = null;
    } on ApiError catch (e) {
      refused = humanMessage(e);
      trouble = refused;
    }
    await _refreshKeeping(refused);
    if (selection != null) await select(selection);
    notifyListeners();
  }

  /// Why is this protected? The core answers; the screen only draws it.
  Future<Explanation?> why(Span span) async {
    try {
      return await z.explain(session: session, span: span);
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// Remove one protection, here. The counterpart to forgetting, and kept
  /// apart from it on purpose: **forget erases knowledge, unprotect changes
  /// what is protected in this document**, and neither is a gentle name for
  /// the other.
  Future<UndoOutcome?> unprotect(Span span) async {
    try {
      final out = await z.unprotect(session: session, span: span);
      await refresh();
      if (selection != null) await select(selection);
      return out;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// One step back. «Protect all 4 matches» came in as one act, so it goes out
  /// as one act — that is the core's doing, not a loop here.
  Future<UndoOutcome?> undo() async {
    try {
      final outcome = await z.undoLastProtection(session: session);
      await refresh();
      if (selection != null) await select(selection);
      return outcome;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    // A closed session takes its tokens with it. Nothing is kept behind.
    z.closeSession(session: session).catchError((_) {});
    super.dispose();
  }
}

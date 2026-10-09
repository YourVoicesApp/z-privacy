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
/// One place that knows every field of `Settings`.
///
/// The generated class has no `copyWith`, so every screen that changed one
/// setting listed all of them — and each new field was a compile error in four
/// files and a silent wrong default in any that was missed. 046/K added two,
/// and this is what it added instead of a fifth copy of the list.
extension SettingsCopy on Settings {
  Settings with_({
    int? originalPanePercent,
    bool? columnsInStep,
    bool? safeColumnOpen,
    bool? reviewPanelWide,
    bool? scanOnImport,
    int? revealSeconds,
    int? autoLockMinutes,
    String? packId,
    String? language,
    bool? firstRunDone,
  }) =>
      Settings(
        originalPanePercent: originalPanePercent ?? this.originalPanePercent,
        columnsInStep: columnsInStep ?? this.columnsInStep,
        safeColumnOpen: safeColumnOpen ?? this.safeColumnOpen,
        reviewPanelWide: reviewPanelWide ?? this.reviewPanelWide,
        scanOnImport: scanOnImport ?? this.scanOnImport,
        revealSeconds: revealSeconds ?? this.revealSeconds,
        autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
        packId: packId ?? this.packId,
        language: language ?? this.language,
        firstRunDone: firstRunDone ?? this.firstRunDone,
        // Never copied from a caller: the core reports whether a setting will
        // survive the app closing, and a screen that could set it would be a
        // screen promising something it does not do.
        sessionOnly: sessionOnly,
      );
}

class Ground extends ChangeNotifier {
  HomeSnapshot? home;
  VaultSnapshot? vaultSnap;
  PrivacyRulesSnapshot? privacyRules;
  ProviderSnapshot? providerSnap;
  String? trouble;

  VaultState get vault => home?.vault ?? VaultState.absent;

  /// Shut the vault now, from wherever a person is.
  ///
  /// 041-N made the vault the way in, which left the bar saying «Unlocked»
  /// with nothing to press. The leader, 6 October: the bar's own «Vault» opens
  /// the screen, and a second press locks it. Locking is the core's act — the
  /// timer lives there too — and the ground reads the answer back rather than
  /// assuming it.
  Future<void> lockVault() async {
    await z.vaultLock();
    await refresh();
  }
  List<ProfileRow> get profiles => home?.profiles ?? const [];
  List<PackRow> get packs => home?.packs ?? const [];

  /// Every language a person may choose, from the core's own table — the ones
  /// with rules first. 041-Q: this used to be «the languages that are coming»,
  /// and a language that was not on that short list could not be chosen at
  /// all, on a build whose vault already held a list for it.
  List<LanguageRow> languages = const [];

  /// The language's own name, for a bar or a heading. Falls back to the code,
  /// because a screen must be able to draw whatever is stored.
  String languageName(String id) {
    for (final row in languages) {
      if (row.id == id) return row.label;
    }
    return id.toUpperCase();
  }

  /// Does this build carry rules for it, or only the general ones?
  bool hasRules(String id) {
    for (final row in languages) {
      if (row.id == id) return row.hasRules;
    }
    return false;
  }

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
  // ------------------------------------------------- the owner's sessions, 064

  /// Every session the vault keeps, newest number last. Empty while the vault
  /// is shut, because the keys are in it.
  List<ConversationRow> sessions = const [];

  /// Which session is open, by number. `None` until the first one is begun or
  /// entered — and `None` again after a lock, because the core forgets the
  /// number with the key rather than leaving one no key opens.
  int? openSession;

  /// The open session's row, for a bar or a heading to name it.
  ConversationRow? get openSessionRow =>
      sessions.where((s) => s.number == openSession).firstOrNull;

  /// **Does the session question still stand?** — 064.
  ///
  /// One source for the two places that must agree: the band at an exit asks
  /// the question when this is true, and [beginThenRead] births a session when
  /// it is true. Two copies of the condition would be two screens able to
  /// disagree about whether a person was ever asked.
  ///
  /// The vault is in it because the keys are. With it shut there is no session
  /// to open and none that could be born, so a band asking for a name would
  /// promise something the core would refuse. Protection itself never needed
  /// the vault — which is why the exits stay live in that state, and say
  /// instead that these names belong to no session.
  bool get theSessionQuestionStands =>
      vault == VaultState.unlocked && openSession == null;

  /// **Begin one.** The name is asked where the press happened — in the panel
  /// for a deliberate clean break, at the exit for a person who never pressed
  /// the button. Both paths land here, and the core does the rest: 32 bytes in
  /// the vault, and every token on the bench named again from them.
  ///
  /// Returns how many tokens were renamed, so the screen can say that the
  /// names it was showing have just become this session's. Null is a refusal,
  /// already in `trouble`.
  Future<int?> beginSession(String name, {SessionId? bench}) async {
    try {
      final row = await z.conversationBegin(name: name, bench: bench);
      await refresh();
      return row.renamedTokens;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// **Enter an existing one.** Asks nothing — the owner's rule.
  Future<int?> enterSession(int number, {SessionId? bench}) async {
    try {
      final row = await z.conversationEnter(number: number, bench: bench);
      await refresh();
      return row.renamedTokens;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return null;
    }
  }

  /// **Delete one, key and file together.** Returns the name that went, so the
  /// screen can say what it was rather than a number.
  Future<String?> forgetSession(int number) async {
    try {
      final name = await z.conversationForget(number: number);
      await refresh();
      return name;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<void> renameSession(int number, String name) async {
    try {
      await z.conversationRename(number: number, name: name);
      await refresh();
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      home = await z.homeSnapshot();
      languages = await z.languages();
      vaultSnap = await z.vaultSnapshot();
      privacyRules = (home?.vault == VaultState.unlocked)
          ? await z.privacyRulesSnapshot(profileId: null)
          : null;
      providerSnap = await z.providerSnapshot();
      // The sessions and which one is open. Asked of the core, never kept here
      // as a second copy: after a lock the core answers `None` because it
      // forgot the key, and a screen holding its own idea of «open» would draw
      // a session nobody can read.
      if (home?.vault == VaultState.unlocked) {
        sessions = await z.conversations();
        openSession = await z.conversationOpen();
      } else {
        sessions = const [];
        openSession = null;
      }
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
  }) : intoList = packId;

  final SessionId session;
  String? profileId;

  /// The rule set this document is being read with. Not final since 041-D: the
  /// top bar can switch it, and what the bar says must be what ran.
  String packId;

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

  /// 046/Q — **the lines held now**, from zero, and what the core says is in
  /// them.
  ///
  /// Two fields and not one: the range is a thing the screen owns, because a
  /// person's press made it; the three numbers are facts about findings and
  /// belong to Rust. A screen that counted the protections inside a range
  /// would be a second source for a number `line_selection` already holds, and
  /// the two would disagree the first time a rescan moved one.
  ({int from, int to})? lines;
  LineSelection? linesHold;

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
    // A document that is not the one the choice was made about starts
    // protected. Here rather than in `rescan`, because a rescan of the **same**
    // document — after teaching a name, say — must not quietly undo what a
    // person chose.
    _protectIfTheDocumentChanged();
    notifyListeners();
  }

  /// What the mode was chosen about. A name and a length is enough to tell one
  /// document from another, and it is nothing of what is in them.
  String? _choseFor;

  void _protectIfTheDocumentChanged() {
    final doc = snap?.document;
    final now = doc == null ? null : '${doc.name}:${doc.text.length}';
    if (now == _choseFor) return;
    _choseFor = now;
    startProtected();
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

  /// The numbers about this document, as the core writes them. Nothing here
  /// shapes the text: a report the screen edited would no longer be the core's
  /// answer, and the whole use of it is that it is.
  Future<String> reportText() =>
      z.importReport(subject: ReportSubject.imported(session: session));

  /// A scan is not a screen (the behaviour board): it runs on import, and this is
  /// the same call the Rescan button makes later.
  Future<void> rescan() async {
    busy = true;
    // Any other scan clears the note: «after the vault opened» is about the
    // scan that is on screen, and about no later one.
    scanNote = null;
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
    // The names that still need a word are part of what a scan produced, so the
    // badge knows before anybody opens the panel.
    await refreshCandidates();
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
      final view = await z.inspectSelection(session: session, span: span);
      // 041-K: what the core will take is what the screen shows. A drag that
      // started one letter late — which is what happens at the left margin —
      // grew out to the whole word before it became anything, so the highlight
      // moves with it rather than lying about the act that is on offer.
      selection = view.wordSpan;
      selected = view;
      trouble = null;
    } on ApiError catch (e) {
      selected = null;
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  /// Take the capitalised word standing in front of the selection too —
  /// «Björn» in front of «Sandström». An offer the core finds and a person
  /// answers; nothing here is automatic.
  Future<void> alsoTakeTheWordBefore() async {
    final also = selected?.alsoBefore;
    final now = selection;
    if (also == null || now == null) return;
    await select(Span(start: also.start, end: now.end));
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

  /// A press or a drag in the gutter. The range is kept, and the core is asked
  /// what is inside it before anything is offered.
  Future<void> holdLines(int from, int to) async {
    lines = (from: from, to: to);
    notifyListeners();
    try {
      linesHold = await z.lineSelection(session: session, from: from, to: to);
      trouble = null;
    } on ApiError catch (e) {
      linesHold = null;
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  /// Let the lines go — **only ever by a press.** Nothing in this file calls it
  /// on its own: the lead's rule of 7 October is that nothing folds or opens by
  /// itself, and a selection that vanished after an act would take with it the
  /// one thing that makes a second column one press away.
  void releaseLines() {
    lines = null;
    linesHold = null;
    notifyListeners();
  }

  /// **The same cell of every held line, from one press** (046/Q).
  ///
  /// The offset is where the person pressed. Rust turns it into a cell by its
  /// order among the line's runs — never by character position, which 048
  /// measured does not survive the PDF reader — and refuses by name when the
  /// press is in the gap between two columns.
  ///
  /// **Scope and kind are not asked for, and neither is invented here.** The
  /// lead's ruling of 7 October is one press and no confirmation, which leaves
  /// two values to settle without a dialog:
  ///
  ///   * the scope is `conversation` — every appearance here, under one token,
  ///     gone when the conversation is. The narrowest scope that can cover a
  ///     column, and the only one that writes nothing into the vault, so a
  ///     press that asked nothing has promised nothing about tomorrow.
  ///   * the kind is **the core's own reading of the cell he pressed**. The
  ///     whole design is «a column reached by example», and the example names
  ///     the kind as well as the column. The kind travels inside the token, so
  ///     getting it from Rust rather than from a default here is the difference
  ///     between the model being told «an account» and being told nothing.
  Future<ProtectOutcome?> protectColumnAt(int offset) async {
    final held = lines;
    final text = document?.text;
    if (held == null || text == null || text.isEmpty) return null;
    // One character, the one under the press. The core reads only where it
    // begins; the end is here because a `Span` is a range, and it is clamped so
    // a press at the very end of the document is still a span the core accepts.
    final at = offset.clamp(0, text.length - 1);
    final one = Span(start: at, end: at + 1);
    try {
      final read = await z.inspectSelection(session: session, span: one);
      final outcome = await z.protectCellInLines(
        session: session,
        span: one,
        from: held.from,
        to: held.to,
        scope: Scope.conversation,
        kind: read.kind,
      );
      await refresh();
      // The lines are still held — see `releaseLines` — so the numbers in the
      // band have to be asked again rather than left as they were.
      await holdLines(held.from, held.to);
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
  /// The models this build can offer, from the core's catalogue.
  ///
  /// Read once when the ground is refreshed and again when a provider is
  /// connected: a model's availability follows its provider's, and no screen
  /// works that out for itself.
  List<ModelDescriptor> models = const [];

  /// Which model the next request goes to, when a person has chosen one.
  /// `null` means «the provider's configured model», which is also what a
  /// model on this machine is.
  String? chosenModel;

  /// What the next send will carry. **False is the only default there is.**
  ///
  /// Z's existing vocabulary already has «Direct API», and it means the route —
  /// this app to the provider, with the protected text. So the unredacted mode
  /// is not called «direct» anywhere a person can see: it is «the original
  /// text», which says what travels.
  bool sendOriginal = false;

  bool _gone = false;

  /// The catalogue, asked for when it is needed — by the send sheet, as it
  /// opens. Not from a scan: a scan's result does not depend on a list of model
  /// names, and making one wait on the other cost two screen tests their
  /// timing before it was taken out again.
  Future<void> refreshModels() async {
    List<ModelDescriptor> got;
    try {
      got = await z.models();
    } on ApiError {
      got = const [];
    }
    // The bench may have gone while the bridge was answering: a widget test
    // ends, and a future that lands afterwards must change nothing and tell
    // nobody.
    if (_gone) return;
    models = got;
    notifyListeners();
  }

  void chooseModel(String? modelId) {
    chosenModel = modelId;
    notifyListeners();
  }

  /// Choosing to send the original is one press, and it is never automatic:
  /// nothing in this class turns a failed protected send into this.
  void chooseOriginal(bool on) {
    sendOriginal = on;
    notifyListeners();
  }

  /// A document that arrives is protected, whatever the last one was.
  ///
  /// The owner's rule for this phase: **a new document or workspace never
  /// silently inherits Direct Mode.** A choice made about one document was
  /// made about that document — the next one begins where every document
  /// begins, and a person who wants the original says so again.
  void startProtected() {
    if (!sendOriginal) return;
    sendOriginal = false;
    notifyListeners();
  }

  /// Ask a model with the protected payload. **No argument carries the
  /// document**, here as in the core: a handle goes, and nothing else could.
  Future<String?> askModelProtected(String providerId) async {
    final h = handle;
    if (h == null) return 'There is nothing to send yet.';
    return _ask(() async {
      final said = await z.askModel(
        handle: h,
        provider: ProviderId(id: providerId),
        model: chosenModel,
        workspace: const [],
        history: const [],
      );
      lastUsage = said.usage;
      showing = said.answer;
    });
  }

  /// Ask a model with the document **as it stands**, because a person chose to.
  ///
  /// A separate function taking the text — so the only call that can carry the
  /// original is the one a human selection reaches, and a mistaken press
  /// cannot pass a document to the protected door. The core keeps the same
  /// separation in its types; this is that separation where the button is.
  Future<String?> askModelWithTheOriginal(String providerId, {required String original}) async {
    if (!sendOriginal) {
      // Not reachable from the screen, and refused here as well: the original
      // travels when the mode says so, never because a caller passed it.
      return 'Choose «The original text» first — this app does not send a '
          'document unprotected on its own.';
    }
    return _ask(() async {
      final said = await z.askModelDirectly(
        session: session,
        text: original,
        provider: ProviderId(id: providerId),
        model: chosenModel,
        workspace: const [],
        history: const [],
      );
      lastUsage = said.usage;
      // There is nothing to restore: nothing was protected.
      said_ = said.text;
    });
  }

  /// What both doors share: the busy flag, the refusal, and the refresh. The
  /// difference between them is the call, and it stays the call.
  Future<String?> _ask(Future<void> Function() door) async {
    sending = true;
    notifyListeners();
    try {
      await door();
      trouble = null;
      sending = false;
      await refresh();
      return null;
    } on ApiError catch (e) {
      sending = false;
      trouble = humanMessage(e);
      notifyListeners();
      // A failure of one door is a failure of that door. Nothing here tries
      // the other one, and the mode is not touched.
      return humanMessage(e);
    }
  }

  /// What the model wrote, when there was nothing to restore it against.
  String? said_;

  /// What the last request cost, as the provider stated it.
  ModelUsage? lastUsage;

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

  /// **The question that travels with this document** (046/N).
  ///
  /// What the person typed stays here only so the field can keep it between
  /// rebuilds; what **leaves** is `questionSafe`, which the core built, and the
  /// marks are the core's too. Nothing here works out what is sensitive: the
  /// field would have been a second scanner, and the first time the two
  /// disagreed the quieter one would win.
  String question = '';
  String questionSafe = '';
  List<Mark> questionMarks = const [];

  /// Set it, and keep what the core says about it.
  ///
  /// A new question makes the payload stale on purpose — the Safe column must
  /// not show yesterday's request — so the document is read again afterwards,
  /// the same way every act that changes what would leave does.
  Future<String?> setQuestion(String text) async {
    question = text;
    try {
      final view = await z.setQuestion(session: session, text: text);
      questionSafe = view.text;
      questionMarks = view.marks;
      trouble = null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return humanMessage(e);
    }
    await refresh();
    notifyListeners();
    return null;
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

  /// The names this document uses that no dictionary knows. One row each, with
  /// the count of places and three lines of context, as the core gathers them.
  List<NameCandidate> candidates = const [];

  /// Names this person has pressed Ignore on, for this session only. Not
  /// knowledge: nothing is written, and the next document asks again.
  final Set<String> ignored = {};

  bool reviewingNames = false;

  /// What still needs a word: the core's list, less what was ignored here.
  List<NameCandidate> get openCandidates =>
      candidates.where((c) => !ignored.contains(c.text)).toList();

  Future<void> refreshCandidates() async {
    try {
      candidates = await z.nameCandidates(session: session);
    } on ApiError {
      // A list that cannot be gathered is an empty list, never a crash: the
      // document is still open and still protected by everything else.
      candidates = const [];
    }
    notifyListeners();
  }

  /// «Al-Hassan is a family name» — taught once, then the document is scanned
  /// again so every place it stands is seen at once.
  /// What this device knows because the person said so, from the core.
  ///
  /// Kept here beside the candidates because the Names panel shows both: what
  /// Z is asking about, and what the person has already answered. Empty while
  /// the vault is shut — the list lives in the vault, and a closed vault has
  /// nothing to say rather than something to guess.
  List<UserNameRow> userNames = const [];

  /// The lists the person keeps their names in, from the core.
  List<UserListRow> userLists = const [];

  /// Which language's list a new name goes into. A list **is** a language —
  /// the owner, 6 October — so this is a pack id, and it starts as the one the
  /// document is being read with. `Workbench.adopt` sets it from the session
  /// the moment there is one, and a pack switch moves it, so the dialog offers
  /// the language on the bar rather than the one on the settings page.
  String intoList;

  /// The last import's three numbers, for the sentence under the button.
  NameImport? lastImport;

  /// What the last act on «your names» did, in a sentence. Kept here and not
  /// in the panel, because the act is the bench's and the panel is only where
  /// it is pressed — a widget that awaits the core itself is a widget that
  /// cannot be driven from a test, and in this app it would be the only one.
  String? namesSaid;

  Future<void> refreshUserNames() async {
    List<UserNameRow> got;
    List<UserListRow> lists;
    try {
      // **With the open client, and not without it** (046/G).
      //
      // This call passed nothing, so the panel always read the global vault
      // alone: a name taught or imported for a client went into that client's
      // vault and appeared on no screen at all. The core now answers with the
      // client's rows **and** the global ones, which is what the scan reads,
      // and each row says which of the two it is.
      got = await z.userNames(profileId: profileId);
      lists = await z.userLists();
    } on ApiError {
      got = const [];
      lists = const [];
    }
    if (_gone) return;
    userNames = got;
    userLists = lists;

    notifyListeners();
  }

  /// Turn a language's list off or on, or forget one with its names. Each goes
  /// through the same door as the names themselves, so the sentence and the
  /// busy flag are the same. There is no «new list» and no rename: a list is a
  /// language, it exists when its first name does, and its name is the
  /// language's.
  Future<String?> setListEnabled(String name, bool enabled) =>
      _aboutNames(() async {
        await z.setUserListEnabled(name: name, enabled: enabled);
        return enabled ? '«$name» is in use again.' : '«$name» is off — its names are still here.';
      });

  /// How many names forgetting this list would take — asked before it is done.
  Future<int> listCost(String name) async {
    try {
      return await z.userListPlan(name: name);
    } on ApiError {
      return 0;
    }
  }

  /// Move every name in one list into another language's, in one act.
  ///
  /// The repair for a list learned under the wrong language: the owner's 75
  /// Swedish surnames, taught while the bar said «Svenska» and filed under
  /// German, move in one answer rather than 75.
  Future<String?> moveList(String from, String to) => _aboutNames(() async {
        final moved = await z.moveUserList(from: from, to: to);
        if (intoList == from) intoList = to;
        return moved == 1
            ? 'Moved one name to ${to.toUpperCase()}.'
            : 'Moved $moved names to ${to.toUpperCase()}.';
      });

  Future<String?> forgetList(String name) =>
      _aboutNames(() async {
        final gone = await z.forgetUserList(name: name);
        return 'Forgot «$name» and ${gone == 1 ? "1 name" : "$gone names"}.';
      });

  /// Add one name a person typed. The core decides where it is kept.
  Future<String?> addUserName(String text, {required UserNameKind kind, required bool always}) async {
    return _aboutNames(() async {
      await z.addUserName(text: text, kind: kind, always: always, list: intoList);
      return 'Added «$text».';
    });
  }

  Future<String?> forgetUserName(UserNameRow row) async {
    return _aboutNames(() async {
      await z.forgetUserName(id: row.id, entityId: row.entityId);
      return 'Forgot «${row.text}».';
    });
  }

  /// Read a list of names. The three numbers come back from the core, which is
  /// the only thing that knows which of them were already known.
  ///
  /// `scope` is the file's answer to one question, and it is `required` here on
  /// purpose — including when it is `null`, which is «offer them and I decide».
  /// Before 046/F there was no such word and the core was told «suggest» for
  /// every row with nobody asked, so a staff list arrived as eighteen
  /// questions. A caller that cannot say which the person chose has not asked
  /// them, and a default would be this defect with a different name.
  Future<String?> importUserNames(String csv, {required Scope? scope, String? into}) async {
    return _aboutNames(() async {
      final report = await z.importUserNames(
        csv: csv,
        profileId: profileId,
        list: into ?? intoList,
        scope: scope,
      );
      if (into != null) intoList = into;
      lastImport = report;
      return importSaid(report);
    });
  }

  /// What the three acts share: the busy flag, the sentence, and the two
  /// refreshes after it. The sentence is the core's own when it refuses.
  Future<String?> _aboutNames(Future<String> Function() act) async {
    busy = true;
    namesSaid = null;
    notifyListeners();
    String? refused;
    try {
      namesSaid = await act();
    } on ApiError catch (e) {
      refused = humanMessage(e);
      namesSaid = refused;
    }
    busy = false;
    await refreshUserNames();
    // A name changes what the scanner knows, so the document is read again.
    await rescan();
    notifyListeners();
    return refused;
  }

  /// Why the last scan happened, when nobody pressed Rescan for it.
  ///
  /// `null` for a scan on import or a scan a person asked for; the band says
  /// «manual rescan» for those, and that sentence has to stay true.
  String? scanNote;

  /// Read the document again now that the vault is open.
  ///
  /// A document opened before the vault was unlocked was read without the
  /// vault layer — the rules and the pack ran, the vault did not, and the band
  /// said so. Once there is an open vault the answer can change, so the
  /// document is read again rather than left standing on an answer that is no
  /// longer the best one this build can give.
  Future<void> rescanAfterVault() async {
    await rescan();
    scanNote = 'after the vault opened';
    notifyListeners();
  }

  /// Run this document against another rule set, from the top bar.
  ///
  /// The list of packs is the core's; this only names one of them. A switch is
  /// a rescan, so the numbers that come back are the new pack's own.
  Future<String?> switchPack(String id) async {
    if (id == packId) return null;
    busy = true;
    notifyListeners();
    String? refused;
    try {
      await z.switchPack(session: session, packId: id);
      packId = id;
      // The bar is what a person reads before they add a name, so the language
      // it names is the one a new name is offered to.
      intoList = id;
    } on ApiError catch (e) {
      refused = humanMessage(e);
      trouble = refused;
    }
    busy = false;
    await rescan();
    return refused;
  }

  Future<void> teachName(String text, {required bool family}) async {
    busy = true;
    notifyListeners();
    String? refused;
    try {
      // The session, not the settings: a name met in a Swedish document is a
      // Swedish name even on a device set up in German. The owner found this
      // the hard way, 75 surnames at a time.
      await z.teachName(text: text, family: family, session: session);
      await rescan();
      await refreshUserNames();
    } on ApiError catch (e) {
      refused = humanMessage(e);
    }
    busy = false;
    // A refusal is news, not a failure, and it is the core's own sentence.
    if (refused != null) trouble = refused;
    await refreshCandidates();
  }

  void ignoreCandidate(String text) {
    ignored.add(text);
    notifyListeners();
  }

  void openNameReview() {
    reviewOpen = true;
    reviewingNames = true;
    notifyListeners();
    unawaited(refreshCandidates());
    // The person's own list is the other half of this panel, and it is asked
    // for where it is needed rather than on every scan.
    unawaited(refreshUserNames());
  }

  void closeNameReview() {
    reviewingNames = false;
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
    _gone = true;
    // A closed session takes its tokens with it. Nothing is kept behind.
    z.closeSession(session: session).catchError((_) {});
    super.dispose();
  }
}

/// What an import did, in one sentence — **including what it did not do.**
///
/// 056: the sentence used to be «2 added · 0 already known · 0 refused» for a
/// client table whose other four columns had been dropped without a word. It
/// read as success, and a person who imports a client book and is told nothing
/// was refused has been told something untrue about their own protection.
///
/// So the sentence says the values a table taught beyond its names, and names
/// the columns this build could not place. Worded here and nowhere else.
String importSaid(NameImport report) {
  final parts = <String>[
    '${report.added} added',
    '${report.alreadyKnown} already known',
    '${report.refused} refused',
    if (report.values > 0) '${report.values} values',
  ];
  final said = parts.join(' · ');
  if (report.columnsNotUsed.isEmpty) return said;
  return '$said\n${columnsNotUsedSaid(report.columnsNotUsed)}';
}

/// The columns a table carried that this build could not name a kind for.
///
/// Named, never dropped: a person must be able to see the difference between
/// «imported» and «imported the names». And it says what to do about it,
/// because a column is a word in their own file and they can change it.
/// **What a birth did, in one sentence** — 064f.
///
/// Worded here and not inside the room, for the reason `importSaid` below is:
/// a sentence built inside a widget callback cannot be read by a test, because
/// a core call started in a callback does not resume under `testWidgets`. So the
/// wording lives where it can be measured and the room only shows it.
///
/// The number is the core's own `renamedTokens`, never counted here. Zero has
/// two honest readings and they are different sentences: with no document open
/// there was nothing to rename, and with one there was nothing that needed it.
String sessionBegunSaid(int renamed, {required bool hadDocument}) {
  if (renamed == 0) {
    return hadDocument
        ? 'Begun. No name on this document needed renaming.'
        : 'Begun. No document is open, so there was nothing to rename.';
  }
  return renamed == 1
      ? 'Begun, and one name on this document moved into it.'
      : 'Begun, and $renamed names on this document moved into it.';
}

/// **What an exit may take out, once the session question is settled** — 064.
///
/// `view` is null when nothing may leave, and `refused` then carries the
/// sentence the person reads at the press: a press that does nothing and says
/// nothing is the one shape of refusal this project does not allow.
class WhatMayLeave {
  const WhatMayLeave({this.view, this.said, this.refused, this.renamed});

  /// The payload whose text may leave — **read after the birth**, never the one
  /// a `build` captured before it.
  final PayloadView? view;

  /// What the birth did, when one happened here: [sessionBegunSaid]'s sentence,
  /// carrying the core's own number. Null when no session was born.
  final String? said;

  /// Why nothing may leave.
  final String? refused;

  /// How many tokens the core renamed into the new session. Null when no birth
  /// happened; **0 is a real answer** and has its own sentence.
  final int? renamed;
}

/// **The order an exit must follow — the one helper both exits use** (064).
///
/// Copy Protected and Save as PDF are one act in two directions, and the
/// owner's rule puts the session's birth inside it: the name is asked once,
/// where the text leaves. The order is the whole of the correctness:
///
///   1. no name typed → nothing leaves, and the sentence says what to do;
///   2. `beginSession(name, bench:)` — **with the bench**, which the core now
///      refuses to do without (064f): a birth that names no document renames
///      nothing, and the text would then leave wearing pre-birth names while
///      the payload claimed the new session;
///   3. a refusal → nothing leaves, and `ground.trouble` is what it says;
///   4. **refresh the bench** — every name on it has just changed;
///   5. read the payload **again**, from the bench, and hand that one out.
///
/// ## Why this is not written inside the widget
///
/// A core call started in a widget callback does not resume under
/// `testWidgets`, so an order followed inside `onPressed` cannot be measured —
/// the same reason [sessionBegunSaid] is worded out here instead of in the
/// room. Out here a guard drives it directly, and the press above it becomes
/// one line with nothing left in it to get wrong.
///
/// ## Step 5 is the step that is easy to lose
///
/// The sheet captures its payload when it builds, and the birth happens after
/// that: **nothing rebuilds between the act and the clipboard.** A closure
/// holding the captured view would take out the pre-birth text with the new
/// session's name stamped on it — true of the snapshot, false of the names.
/// From the core's side nothing is wrong, and no core guard can see it.
Future<WhatMayLeave> beginThenRead(
  Ground ground,
  Workbench bench, {
  required String name,
}) async {
  int? renamed;
  String? said;
  if (ground.theSessionQuestionStands) {
    if (name.trim().isEmpty) {
      // Not a refusal by the core — the core is never asked. A name nobody has
      // typed is a question still open, and the next move is one word.
      return const WhatMayLeave(
        refused: 'Give it a name first — one word is enough.',
      );
    }
    renamed = await ground.beginSession(name, bench: bench.session);
    if (renamed == null) {
      return WhatMayLeave(
        refused: ground.trouble ??
            'The session was not begun, so nothing was taken out.',
      );
    }
    said = sessionBegunSaid(renamed, hadDocument: bench.document != null);
    await bench.refresh();
  }
  var view = bench.payload;
  final open = ground.openSession;
  if (open != null && view?.session?.number != open) {
    // **Look again before refusing.** A view that does not belong to the open
    // session is our own staleness and not the person's mistake, so the first
    // answer is to re-read: a dead «no» at the moment of pressing Copy would
    // be the wrong product for a fault of ours.
    await bench.refresh();
    view = bench.payload;
  }
  if (view == null) {
    return WhatMayLeave(
      said: said,
      renamed: renamed,
      refused: 'There is nothing to take out yet.',
    );
  }
  // **What this check holds, and what it does not.** `PayloadView.session` is
  // stamped when the payload is built, from whichever session was open then —
  // so it answers «was this snapshot taken inside the session», not «were its
  // tokens minted by it». Those two agree in every case but one: a birth that
  // named no document renamed nothing, and a payload built after it would
  // match here while its text wore older names. That half of the property
  // lives in the core, which refuses such a birth (064f) — and if that refusal
  // is ever removed, this check goes quiet without going red.
  if (open != null && view.session?.number != open) {
    return WhatMayLeave(
      said: said,
      renamed: renamed,
      refused: 'Close this and open it again — something changed while it was open.',
    );
  }
  return WhatMayLeave(view: view, said: said, renamed: renamed);
}

String columnsNotUsedSaid(List<String> columns) {
  final which = columns.join(', ');
  return columns.length == 1
      ? 'One column was not used: $which — name the kind for it, or it stays out.'
      : '${columns.length} columns were not used: $which — name the kind for each, or they stay out.';
}

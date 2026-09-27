// The one place in the UI that talks to z_core.
//
// Why it exists at all: the owner's rule for M7 is that no number on screen is
// invented here. So every field below is a value the core handed over, and the
// only way it changes is a call that went to Rust and came back. A screen reads
// these fields; it never computes one.
//
// It also means a mistake is findable: if a count is wrong, it is wrong in the
// core or in the refresh below — never in a widget.
import 'package:flutter/foundation.dart';

// Prefixed on purpose: every line below that says `z.` is a call into Rust, and
// the prefix makes that visible when reading the file rather than guessing.
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

/// What the app knows before any document exists: the ground the Workspace stands
/// on, and what Home draws.
class Ground extends ChangeNotifier {
  VaultState vault = VaultState.absent;
  List<ProfileRow> profiles = const [];
  List<PackRow> packs = const [];
  List<ProviderRow> providers = const [];
  int entityCount = 0;
  int valueCount = 0;
  String? trouble;

  /// Read it all again from Rust. Called on open, and after anything that could
  /// have changed it.
  Future<void> refresh() async {
    try {
      vault = await z.vaultState();
      packs = await z.packs();
      providers = await z.providers();
      // Both of these need an open vault; a locked one is not an error, it is a
      // state the UI shows in words.
      profiles = vault == VaultState.unlocked ? await z.profiles() : const [];
      if (vault == VaultState.unlocked) {
        final rows = await z.entities();
        entityCount = rows.length;
        valueCount = rows.fold<int>(0, (sum, e) => sum + e.values);
      } else {
        entityCount = 0;
        valueCount = 0;
      }
      trouble = null;
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    notifyListeners();
  }

  int get connectedProviders => providers.where((p) => p.connected).length;
}

/// One conversation: the document, what was found in it, and what would leave.
///
/// Everything here is refreshed from the core together, because the core's own
/// `revision` ties them: a document view and a scan report from two different
/// revisions would be two different documents.
class Workbench extends ChangeNotifier {
  Workbench({required this.session, required this.profileId, required this.packId});

  final SessionId session;
  final String? profileId;
  final String packId;

  DocumentView? document;
  ScanReport? report;
  List<Finding> findings = const [];
  List<TokenRow> tokens = const [];
  Revision revision = const Revision(n: 0);
  String? trouble;
  bool busy = false;

  /// The outgoing text, and the handle it was built under.
  ///
  /// Rebuilt on every refresh rather than cached, because the core ties a
  /// payload to a `revision`: a view kept from before a change is a view of a
  /// different document, and showing one would be the exact lie this column
  /// exists to prevent.
  PayloadHandle? handle;
  PayloadView? payload;

  /// Chips or plain, on the Safe side. A drawing choice; the string is the same.
  bool chips = true;

  /// What the user has selected on the Original side, and what the core says it
  /// is. The view is **never** worked out here: the Protect button's five states
  /// are `SelectionView`, decided in Rust by the same code that would do the
  /// protecting.
  Span? selection;
  SelectionView? selected;

  /// True once anything has been protected by hand, so Undo can be honest about
  /// being disabled rather than pretending to be available.
  bool get canUndo => tokens.any((t) => t.source == Source.hand);

  /// Which tokens are showing their value right now, and until when.
  ///
  /// This lives **only here**, in the UI. Revealing changes nothing in the core
  /// — `hide` has nothing to undo — and that is the invariant: reveal draws on
  /// the screen and never writes into the payload.
  final Map<String, String> revealed = {};
  final Map<String, DateTime> _revealedUntil = {};
  bool tokensOpen = false;

  /// The review panel, and which finding it is pointing at.
  bool reviewOpen = false;
  int? focused;

  /// Walking mode: one suggestion at a time, with its sentence around it.
  bool walking = false;

  List<Finding> get suggested =>
      findings.where((f) => f.state == MarkState.suggested).toList(growable: false);
  List<Finding> get automatic => findings
      .where((f) => f.state == MarkState.protected && f.source != Source.hand)
      .toList(growable: false);
  List<Finding> get byHand =>
      findings.where((f) => f.state == MarkState.protected && f.source == Source.hand).toList(growable: false);

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
  int get protectedCount => report?.auto ?? 0;
  int get openSuggestions => report?.suggested ?? 0;
  int get normalCount => report?.normal ?? 0;

  Future<void> refresh() async {
    try {
      document = await z.documentView(session: session);
      findings = await z.listFindings(session: session);
      tokens = await z.listTokens(session: session);
      revision = await z.sessionRevision(session: session);
      handle = await z.buildPayload(session: session);
      payload = await z.payloadView(handle: handle!);
      trouble = null;
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    notifyListeners();
  }

  /// A scan is not a screen (the behaviour board): it runs on import, and this is
  /// the same call the Rescan button makes later.
  Future<void> rescan() async {
    busy = true;
    notifyListeners();
    try {
      report = await z.scan(session: session);
      trouble = null;
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    busy = false;
    await refresh();
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
      trouble = e.toString();
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
          ? await z.protectAllMatches(session: session, span: span, scope: scope, kind: kind)
          : await z.protect(session: session, span: span, scope: scope, kind: kind);
      await refresh();
      // The selection still stands, but what it *is* has changed.
      await select(span);
      return outcome;
    } on ApiError catch (e) {
      trouble = e.toString();
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
      _revealedUntil[token] = DateTime.now().add(Duration(milliseconds: shown.ttlMs));
      trouble = null;
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    notifyListeners();
  }

  Future<void> hideToken(String token) async {
    revealed.remove(token);
    _revealedUntil.remove(token);
    try {
      await z.hide_(session: session, token: token);
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    notifyListeners();
  }

  /// Drop anything whose moment has passed. Called before drawing, so a value
  /// cannot sit on a screen nobody is looking at.
  void expireReveals() {
    final now = DateTime.now();
    final over = _revealedUntil.entries.where((e) => e.value.isBefore(now)).map((e) => e.key).toList();
    if (over.isEmpty) return;
    for (final t in over) {
      revealed.remove(t);
      _revealedUntil.remove(t);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- sending

  /// The answers this conversation has received, newest last, and which one is
  /// on screen. Kept as ids: the text lives in the core and is asked for by the
  /// two views, because the restored one must be built there and nowhere else.
  final List<AnswerId> answers = [];
  AnswerId? showing;
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
      final answer = await z.send(handle: h, provider: ProviderId(id: providerId));
      answers.add(answer);
      showing = answer;
      trouble = null;
      sending = false;
      notifyListeners();
      return null;
    } on ApiError catch (e) {
      sending = false;
      trouble = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  /// The other door: the user took the safe text to a model themselves and is
  /// bringing the answer back. Restoring works exactly the same way — the token
  /// store does not care how the answer travelled.
  Future<String?> pasteAnswer(String raw) async {
    if (raw.trim().isEmpty) return 'Nothing was pasted.';
    try {
      final answer = await z.ingestAnswer(session: session, raw: raw);
      answers.add(answer);
      showing = answer;
      trouble = null;
      notifyListeners();
      return null;
    } on ApiError catch (e) {
      trouble = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  Future<List<Segment>> restored(AnswerId answer) =>
      z.restoredView(session: session, answer: answer);

  Future<String> asTheModelWroteIt(AnswerId answer) =>
      z.aiView(session: session, answer: answer);

  void show(AnswerId? answer) {
    showing = answer;
    notifyListeners();
  }

  /// Leaving the vault, or the workspace, re-hides everything that was shown.
  void hideEverything() {
    if (revealed.isEmpty) return;
    revealed.clear();
    _revealedUntil.clear();
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
    try {
      report = await z.answerFinding(session: session, finding: finding, answer: choice);
      trouble = null;
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    await refresh();
    if (selection != null) await select(selection);
    // Step on to the next one still waiting, so walking is a walk.
    if (walking) {
      final left = suggested;
      focused = left.isEmpty ? null : (left.firstWhere((f) => f.id != finding, orElse: () => left.first)).id;
      if (left.isEmpty) walking = false;
    }
    notifyListeners();
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
      trouble = e.toString();
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

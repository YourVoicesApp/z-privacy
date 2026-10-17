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
import 'package:zprivacy/core/the_clipboard.dart';

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

  /// **What each session is holding in its preview**, by session number — 089
  /// rule 9. Empty for a session holding nothing, which is the ordinary state:
  /// a document that left by a door is not kept.
  ///
  /// Read with the sessions and from the same door, so the list and the rows
  /// under it are one answer rather than two that can disagree.
  Map<int, List<KeptRow>> kept = const {};

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
  /// to open and none that could be born. Protection itself never needed the
  /// vault — which is why the exits stay live in that state, and say instead
  /// that these names belong to no session.
  ///
  /// **It was `theSessionQuestionStands` until 081.** There is no question any
  /// more: the owner had the field deleted — «نريد أن نحذف أي إضافات بلا
  /// معنى… أبسط من البساطة ذاتها» — and a press that needs a session gets one
  /// called «Session N». What the predicate answers is what it always
  /// computed, so it says that now.
  bool get aSessionWouldBeBorn =>
      vault == VaultState.unlocked && openSession == null;

  /// **Write a session's language, by its number** — 080.
  ///
  /// The core's own door, added for the one case `switchPack` cannot serve: a
  /// session created with no document open. It touches no bench and rescans
  /// nothing, so a caller with a document in front of the person switches that
  /// bench as well, and the two writes say the same thing.
  Future<bool> setSessionPack(int number, String packId) async {
    try {
      await z.conversationSetPack(number: number, packId: packId);
      await refresh();
      return true;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
      notifyListeners();
      return false;
    }
  }

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

  /// **A session nobody named, named by its own number** — 081, the owner's
  /// first ruling: «لا رفض عند المخرج».
  ///
  /// 064 asked for a name where the text leaves, and refused the press that did
  /// not answer. The owner met that refusal from the other side: a person who
  /// wanted their protected text out had never come for a question, did not
  /// read the small line that replaced their copy, and pasted what was already
  /// on the clipboard. A door that must not refuse cannot ask.
  ///
  /// The number cannot be known before the birth — it is the core's, and the
  /// core assigns it — so the birth happens first and the name follows it
  /// through `conversation_rename`, which exists for exactly this reason: «the
  /// number is the identity and does not move». Nothing here predicts it from
  /// the list, which would be a guess that is wrong the first time two hands
  /// begin a session at once.
  ///
  /// A rename that fails leaves «$_aSessionCalled», which is less than was
  /// wanted and still true — and the session is open, which is what the press
  /// needed.
  Future<int?> beginSessionItNames({SessionId? bench}) async {
    try {
      final row = await z.conversationBegin(name: _aSessionCalled, bench: bench);
      await z.conversationRename(number: row.number, name: nameForSession(row.number));
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
        // 089 rule 9. One call per session, which is one sealed file read per
        // session: the same cost the row's own «N exchanges» already pays.
        final held = <int, List<KeptRow>>{};
        for (final row in sessions) {
          held[row.number] = await z.keptDocuments(number: row.number);
        }
        kept = held;
      } else {
        sessions = const [];
        openSession = null;
        kept = const {};
      }
      rememberKinds(kinds);
      trouble = null;
    } on ApiError catch (e) {
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  /// **Rename one saved document** — 089 rule 9. The name changes and the
  /// number never does, which is the same division a session's own rename
  /// keeps. Returns the core's refusal, or null when it went through.
  Future<String?> renameKept(int number, int which, bool chat, String name) async {
    try {
      await z.renameKeptDocument(number: number, which: which, chat: chat, name: name);
      await refresh();
      return null;
    } on ApiError catch (e) {
      return humanMessage(e);
    }
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
/// **Which panel stands in the workspace's one slot — 071.**
///
/// The slot is the column right of the document, and four panels claim it. It
/// held **four independent booleans**, and `workspace.dart` chose between them
/// with a precedence chain while its own comment promised «one panel at a
/// time, and the one asked for». The promise was not kept: names and review
/// excluded each other — 070 paid for that corner in a live bug — but tokens
/// and the answer were separate `if`s, so Review then Tokens put two panels in
/// one slot, sharing one width and one arrow. Measured on the glass before
/// this was written, and pinned.
///
/// Four booleans have fifteen corners that mean nothing. One value has none:
/// the wrong state is not fixed here, it is **unwritable**. The same ladder
/// this project climbed for `Piece` in the core and for `TurnVia` in a
/// session's turns — remember it, comment it, guard it, make it
/// unrepresentable.
///
/// `showing` is **not** folded in: it names *which answer*, and the chat reads
/// it too. This names *which panel*, and nothing else.
enum OpenPanel { none, names, review, tokens, answer }


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

  /// What the last **re**scan reported, and nothing is drawn from it.
  ///
  /// Every number the band shows comes from [snap], which carries them all —
  /// the counts, the vault's state, which scan it was. This holds the one thing
  /// the snapshot has not got, the per-layer counts, for the day a screen shows
  /// them. It is `null` for a document that has only ever been scanned on
  /// import, which is why nothing on the glass may ask it whether a scan has
  /// happened (item 3, 14 October).
  ScanReport? report;

  /// **What the core says about a document that came back** — 079, the import
  /// side.
  ///
  /// `null` until a document has been read; `tokens == 0` for every ordinary
  /// one, which is how the strip knows to draw nothing. Read once, where the
  /// scan that arrived with the document is read, so every door a document can
  /// arrive by — a file, a paste, the composer — asks it exactly once and no
  /// screen has to remember to (the shape item 3 paid for).
  ///
  /// Nothing here counts anything in it: the numbers and the names are the
  /// core's, and `whatCameBack` in `messages.dart` is the one place they become
  /// a sentence.
  ReturnedDocument? returned;
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

  /// **The one slot's one value — 071.** Nothing else says which panel is
  /// open, so two cannot be.
  OpenPanel panel = OpenPanel.none;

  /// Which finding the review panel is pointing at.
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
    // **Nothing here has a mode to reset any more** — rule 62. A document that
    // arrived used to be put back into the protected mode, in case the last
    // one had been sent as it stands; there is one mode now, so there is
    // nothing a new document could inherit.
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

  /// The numbers about this document, as the core writes them. Nothing here
  /// shapes the text: a report the screen edited would no longer be the core's
  /// answer, and the whole use of it is that it is.
  Future<String> reportText() =>
      z.importReport(subject: ReportSubject.imported(session: session));

  /// **The scan a document arrived with** — 14 October, item 3.
  ///
  /// The core scans as it reads, at every door a document can arrive by, so
  /// this reads what is already on the session instead of asking for a second
  /// scan. There is nothing for the glass to do but look.
  ///
  /// Calling [rescan] here — which is what both doors did until the law moved
  /// into the core — scans the same text twice, which on the owner's 734-page
  /// file is the whole of that work for nothing; and the second scan is
  /// truthfully reported as a `Rescan`, so the first thing a person read about
  /// a document they had just opened was that somebody had rescanned it.
  Future<void> readTheScanThatArrivedWithIt() async {
    // Any scan clears the note, and this one is «the scan that came with the
    // document» — no earlier note belongs to it.
    scanNote = null;
    await _refreshKeeping(null);
    // The names that still need a word are part of what a scan produced, so the
    // badge knows before anybody opens the panel.
    await refreshCandidates();
    // **And whether this document has come back to us** — 079, the import
    // side. Asked here and nowhere else, for the reason item 3 exists: four
    // doors read a document, and a question one of them remembers to ask is a
    // question three of them forget. A reading only — the core writes nothing
    // and the revision does not move — so it cannot disturb the scan above.
    await readWhetherItCameBack();
  }

  /// **Has this document come back, and what of it can we still read?** — 079.
  ///
  /// The core answers; this keeps the answer and tells the listeners. A refusal
  /// is not news a person needs here — the document is on the bench either way
  /// — so it clears the answer rather than putting a sentence over the screen.
  Future<void> readWhetherItCameBack() async {
    try {
      returned = await z.returningDocument(session: session);
    } on ApiError catch (_) {
      returned = null;
    }
    notifyListeners();
  }

  /// A scan is not a screen (the behaviour board). A document arrives scanned
  /// (item 3); this is the **re**scan — the button, a pack changed, a name
  /// taught.
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
    // **And the returning document is asked again** — 079. The second case of
    // the rule the first one is written at: a rescan is what happens after the
    // vault is opened («Last scan: after the vault opened»), and with the vault
    // open the door can name the conversation and bring back the values it was
    // taught, where a moment ago it could name nothing at all. A line that said
    // «open your vault to read them back» after the vault was opened would be
    // the band's own 14 October defect in a new place.
    await readWhetherItCameBack();
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
    // Closing takes the slot back only if this panel is the one holding it:
    // «close tokens» must not shut a review that tokens never displaced.
    if (on) {
      panel = OpenPanel.tokens;
    } else if (panel == OpenPanel.tokens) {
      panel = OpenPanel.none;
    }
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

  // **What the next send will carry is not a field any more** — rule 62, the
  // owner on 17 October. There was a flag here, and two presses on «Who
  // answers» that set it: one for the protected text and one for the document
  // as it stands. The second is deleted, so there is nothing left to choose
  // and no state to be in by accident — what the next send carries is the
  // payload, as every send does.
  //
  // «Direct API» stays in the vocabulary, and still means what it always meant
  // in it: the route, this app to the provider, with the protected text.

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

  /// Ask a model with the protected payload. **No argument carries the
  /// document**, here as in the core: a handle goes, and nothing else could.
  Future<String?> askModelProtected(String providerId) async {
    final h = handle;
    if (h == null) return 'There is nothing to send yet.';
    return _ask(leaving: payload?.text ?? '', () async {
      final said = await z.askModel(
        handle: h,
        provider: ProviderId(id: providerId),
        model: chosenModel,
        workspace: const [],
        history: const [],
      );
      lastUsage = said.usage;
      showing = said.answer;
      panel = OpenPanel.answer;
    });
  }

  // **The second door is gone** — rule 62. Beside [askModelProtected] stood a
  // function that took the document as an argument, because the person had
  // chosen on the screen to send it as it stands. It is deleted with the
  // choice, and deleted rather than left unreachable: a method on this class
  // that takes a `String` and sends it is what the next button gets wired to.
  //
  // So there is one send door on this bench, it takes no text, and the only
  // thing it can put on a wire is a payload the core built.

  /// What the door shares with the journey below it: the busy flag, the
  /// refusal, and the refresh.
  ///
  /// **And the journey, said step by step** (064/E). The owner's ruling of
  /// 9 October: the press takes the person to the chat, and there they see what
  /// was sent, then the answer when it comes back, then the answer pulled
  /// inside — unwrapped, shown restored, and written into the session. Those
  /// are three real moments of one request, so the stage is published as each
  /// one happens rather than at the end: a person watching a slow model has the
  /// right to know which of the three they are waiting in.
  Future<String?> _ask(Future<void> Function() door, {required String leaving}) async {
    sending = true;
    // **What actually left**, kept before the call rather than reconstructed
    // after it: the payload is rebuilt by the refresh below, and «the request
    // in its safe clothing» is a claim about the text that travelled.
    sentAsItLeft = leaving;
    stage = SendStage.sent;
    turn = null;
    notifyListeners();
    try {
      await door();
      trouble = null;
      sending = false;
      stage = SendStage.answered;
      notifyListeners();
      await refresh();
      // **The turn, read back from the session's own file** — and this is the
      // order the owner named: pulled inside means written, and nothing
      // restored is shown before it is. With no session open the core writes
      // nothing (`record` refuses with «there is no session open to write
      // to»), so there is no third step to show and the screen says that
      // plainly instead of pretending.
      await readTheTurn();
      return null;
    } on ApiError catch (e) {
      sending = false;
      trouble = humanMessage(e);
      stage = SendStage.refused;
      notifyListeners();
      // A failure of one door is a failure of that door. Nothing here tries
      // the other one, and the mode is not touched.
      return humanMessage(e);
    }
  }

  /// Where this request has got to. `none` until one is made.
  SendStage stage = SendStage.none;

  /// The text that travelled, in the clothing it travelled in.
  String? sentAsItLeft;

  /// The written turn, as the core restores it. Null until one is read, and
  /// null for a send that no session could keep.
  TurnRow? turn;

  /// Read the open session's last turn, restored **inside the core**.
  ///
  /// The restoring happens there and crosses the boundary already done, with
  /// `unresolved` naming every token it could not resolve: a raw turn on a
  /// screen would put `__Z_5CDD_IBAN_5B32__` in the middle of a model's
  /// sentence, which is the exact lie the restore path exists to prevent.
  Future<void> readTheTurn() async {
    final open = await _openConversation();
    if (open == null) {
      turn = null;
      stage = stage == SendStage.answered ? SendStage.keptNowhere : stage;
      notifyListeners();
      return;
    }
    try {
      final rows = await z.conversationTurns(number: open, bench: session);
      turn = rows.isEmpty ? null : rows.last;
      if (turn != null) stage = SendStage.pulledIn;
    } on ApiError catch (e) {
      // A turn that cannot be read is not an answer that did not arrive: the
      // answer is still on the screen above, and this says only that the
      // reading failed.
      turn = null;
      trouble = humanMessage(e);
    }
    notifyListeners();
  }

  Future<int?> _openConversation() async {
    try {
      return await z.conversationOpen();
    } on ApiError {
      return null;
    }
  }

  // **What the model wrote when there was nothing to restore it against** was
  // kept here, and nothing is in that state any more: every answer this app
  // receives answers a payload, so every answer has something to be restored
  // against. The field goes with the door that filled it (rule 62).

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
      panel = OpenPanel.answer;
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
      panel = OpenPanel.answer;
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
    // `panel == answer` can only mean there is one to show, because the two
    // move together here and in the three places an answer arrives.
    if (answer == null) {
      if (panel == OpenPanel.answer) {
        panel = OpenPanel.none;
      }
    } else {
      panel = OpenPanel.answer;
    }
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
      return 'Added «${theirOwnWord(text)}».';
    });
  }

  Future<String?> forgetUserName(UserNameRow row) async {
    return _aboutNames(() async {
      await z.forgetUserName(id: row.id, entityId: row.entityId);
      return 'Forgot «${theirOwnWord(row.text)}».';
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

  /// **One slot, one boolean** — 070, the owner's second finding of 9 October.
  ///
  /// He pressed Review on a 146-page document whose badge said 8 and got the
  /// *Names* panel's «No names to look at», with the «8 questions left» button
  /// still under it. The cause was here and not in either counter: this method
  /// set **both** booleans, `openReview` never cleared `reviewingNames`, and
  /// `workspace.dart` chooses between the two panels with
  /// `if (reviewingNames) … else if (reviewOpen) …`. So once the names panel
  /// had been opened, Review could never show the review again: the key read
  /// `reviewOpen == true`, called `closeReview()`, and cleared the boolean
  /// nobody was reading.
  ///
  /// `panelOpen` in the workspace already counts `reviewingNames`, so setting
  /// `reviewOpen` here was redundant **and** harmful at once.
  ///
  /// Two booleans for one slot have a fourth corner that means nothing, which
  /// is the rule written over `Piece` in the core's own api.rs and obeyed
  /// there. Four panels share this slot and four booleans describe them
  /// (`tokensOpen` and `showing` too), so the real repair is one value that
  /// names which panel is open — task **071**, with its own paper. Not dropped
  /// into tonight's fix.
  ///
  /// Reproduced by the other seat before either of us touched it, red by
  /// design, with the control beside it: `the_badge_and_the_door_test`.
  void openNameReview() {
    panel = OpenPanel.names;
    notifyListeners();
    unawaited(refreshCandidates());
    // The person's own list is the other half of this panel, and it is asked
    // for where it is needed rather than on every scan.
    unawaited(refreshUserNames());
  }

  void closeNameReview() {
    if (panel == OpenPanel.names) {
      panel = OpenPanel.none;
    }
    notifyListeners();
  }

  void openReview({bool? walk}) {
    // One value: taking the slot **is** the other panels giving way. 070 had
    // to clear a second boolean by hand here, and the bug it fixed was that
    // nobody had cleared it for a year.
    panel = OpenPanel.review;
    if (walk != null) walking = walk;
    // Walking starts at the first thing still waiting, not at the top of a list
    // the user has already been through.
    if (walking) focused ??= suggested.isEmpty ? null : suggested.first.id;
    notifyListeners();
  }

  /// **The exit's guide** — 083 rule 12, and the other half of the law 083a
  /// put in the core.
  ///
  /// The refusal is not a wall: a press that cannot take the text out opens the
  /// review on the word it is waiting for, so the person's next act is one
  /// press away instead of a sentence they have to work out. It takes the slot
  /// the one way it is taken, through [openReview], and sets the focus first
  /// because that method only fills an empty one.
  /// Returns **false when there was no word to go to** — an empty document, a
  /// refusal of another kind — which is how a press learns whether the person
  /// has somewhere to land without reading the error itself (G20).
  bool openTheReviewAtTheFirstWaitingWord({String? said}) {
    final first = theFirstWaitingWord(findings);
    if (first == null) return false;
    focused = first.id;
    // **The sentence is said where the word is** — the lead's ruling of 14 Oct
    // on rule 12. The sheet gets out of the way, so the news cannot stay behind
    // it: this is the line the workspace draws above the columns.
    if (said != null) trouble = said;
    openReview(walk: true);
    return true;
  }

  void closeReview() {
    if (panel == OpenPanel.review) {
      panel = OpenPanel.none;
    }
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

  /// **In this conversation** — every place that carries this token.
  ///
  /// The other reach the owner allows (083, ruling 3), beside [unprotect]
  /// above, which is «here». It was written in `core/un_protecting.dart` on
  /// 14 October because this file was another seat's that day and the two acts
  /// had to be readable side by side; the lead promised it would be absorbed in
  /// one line once that round was sealed, and this is that line. Both names
  /// stay where 084's search bar can call them.
  ///
  /// **The token, not the text**, by the lead's ruling: a person un-protects
  /// what they can see, and what they can see is a token; and the token's
  /// allowed set is what keeps the outgoing text honest (C4), so acting by text
  /// could leave a token in the payload that nothing explains.
  ///
  /// **The refusal survives the refresh**, which is the 30 September finding:
  /// `refresh()` sets `trouble` to null when it succeeds, so the news is put
  /// there after it. A refusal that never reaches a person is the same thing as
  /// no refusal.
  Future<UndoOutcome?> unprotectEveryPlace(Span span) async {
    try {
      final outcome = await z.unprotectEveryPlace(session: session, span: span);
      await refresh();
      if (selection != null) await select(selection);
      return outcome;
    } on ApiError catch (e) {
      await refresh();
      trouble = humanMessage(e);
      // The focus is set to what it already is: a public act that notifies and
      // touches nothing else, where `select` would clear the very sentence the
      // line above exists to keep.
      focusOn(focused);
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
    // A closed bench takes its tokens with it — and since 089 **the words are
    // kept**: every one of them is a block in the vault, so what dies here is
    // this run's index and not the person's protection. The sentence that used
    // to stand here said «nothing is kept behind», which was the trade the
    // owner withdrew on 15 October.
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

/// **The application's own language** — 080, and the only place the config's
/// pack is read.
///
/// The owner's two ways to a session's language are «chosen when the session is
/// created» and «the application's», and there is no third. This is the second
/// of them, and it is a function rather than a field read in four places
/// because the four places were the defect: the chat door read the config
/// itself and never asked the session, so a German conversation was read with
/// an English eye — 7 findings from a file, 0 from the same text pasted.
///
/// The fallback of the fallback is German, which is where this product started
/// and the only honest guess when a config has not been read yet.
String appLanguage(Ground ground) => ground.config?.packId ?? 'de';

/// **Which language reads the next text, whatever door it came through** — 080,
/// and `null` where **nobody has said** — rule 57-د.
///
/// One function, and every door calls it: the chat and a file are not two
/// worlds. «ما ينطبق على الوثائق ينطبق على الشات».
///
/// The three answers, and the third is the one the owner added on 17 October:
///
///   * a session is open and has a language of its own → that one, and nobody
///     is asked (rules 33 and 57c);
///   * there is no session and none could be born — the vault is shut, so
///     there is nowhere to keep a language → the application's, because an
///     answer that cannot be remembered is not worth asking for;
///   * **anything else → `null`, which means «ask».** A session that will be
///     born has its language chosen as it is born (rule 57b), and a session
///     created before 080 that never got one is asked **once**, before the
///     first text is read in it (rule 57-د).
///
/// It used to end `?? appLanguage(ground)` for both of the last two, and that
/// is the defect the owner met: an old session read his German text with an
/// English eye and he was never asked. A fallback is honest only where there
/// is no one to ask and nowhere to put the answer.
String? packForTheNextText(Ground ground) {
  final open = ground.openSessionRow;
  if (open != null) return open.packId;
  if (ground.aSessionWouldBeBorn) return null;
  return appLanguage(ground);
}

/// The provisional name a nameless birth is begun with, before the core's
/// number is known. One word, and never left behind as a lie: the rename that
/// follows it turns it into [nameForSession].
const _aSessionCalled = 'Session';

/// **The name a session nobody named carries** — «الجلسة 1، الجلسة 2…», 081.
///
/// One function, because three places read it: the birth that sets it, the
/// line in the sheet that must not say «Session 3 «Session 3»», and the guard
/// that measures it. A fourth copy of this string is a fourth chance to spell
/// it differently.
String nameForSession(int number) => '$_aSessionCalled $number';

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

/// **Where a request has got to** — 064/E, the owner's three steps.
///
/// «What was sent appears; the answer appears when it returns; then the answer
/// is pulled inside» — unwrapped, shown restored, and written into the session.
/// `keptNowhere` is the honest fourth: an answer came back and no session was
/// open to keep it, which the core refuses to write rather than inventing a
/// file for.
enum SendStage { none, sent, answered, pulledIn, keptNowhere, refused }

/// **What an exit may take out, once the session question is settled** — 064.
///
/// `view` is null when nothing may leave, and `refused` then carries the
/// sentence the person reads at the press: a press that does nothing and says
/// nothing is the one shape of refusal this project does not allow.
class WhatMayLeave {
  const WhatMayLeave({
    this.view,
    this.said,
    this.refused,
    this.renamed,
    this.landedOnTheWaitingWord = false,
  });

  /// The payload whose text may leave — **read after the birth**, never the one
  /// a `build` captured before it.
  final PayloadView? view;

  /// What the birth did, when one happened here: [sessionBegunSaid]'s sentence,
  /// carrying the core's own number. Null when no session was born.
  final String? said;

  /// Why nothing may leave.
  final String? refused;

  /// **The person has somewhere to land** — 083 rule 12, the lead's ruling of
  /// 14 Oct. True when the refusal opened the review on a word still waiting,
  /// which is the one case where the sheet standing in front of it would be the
  /// wall the rule removes. A press reads this instead of the error, because no
  /// surface interprets an `ApiError` by itself (G20).
  final bool landedOnTheWaitingWord;

  /// How many tokens the core renamed into the new session. Null when no birth
  /// happened; **0 is a real answer** and has its own sentence.
  final int? renamed;
}

/// **The word a review opens on: the first one still waiting, in reading
/// order** — 083, rules 4 and 12.
///
/// Not `suggested.first`. The core hands findings back in the order its layers
/// found them (`ops::list_findings` walks the session's own list), which is the
/// scan's order and not the eye's. In today's documents the two agree, and that
/// is exactly the shape that lets a wrong one stand for a year — so the order
/// is taken from the span, which is what «first» means to the person reading.
Finding? theFirstWaitingWord(List<Finding> findings) {
  Finding? first;
  for (final f in findings) {
    if (f.state != MarkState.suggested) continue;
    if (first == null || f.span.start < first.span.start) first = f;
  }
  return first;
}

/// **The order an exit must follow — the one helper both exits use** (064).
///
/// Copy Protected and Save as PDF are one act in two directions, and the
/// owner's rule puts the session's birth inside it: the name is asked once,
/// where the text leaves. The order is the whole of the correctness:
///
///   0. **the clipboard is emptied** — before the session or the payload is so
///      much as looked at (081, the owner's root rule);
///   1. **the core is asked whether anything may leave** — 083a. One law for
///      all three exits, in one function in the core, and no word of it is
///      written here: `payload_to_take_out` refuses while a word waits for the
///      person's answer. Asked **before** the birth, so a press that takes
///      nothing out leaves nothing behind it; the refusal opens the review on
///      the first waiting word rather than standing in the person's way;
///   2. no session open → **one is born, called «Session N»** by the core's own
///      number (081). Nothing is asked and nothing is refused: the exit has no
///      name to take, because the owner had the field deleted and left naming
///      to the rename control in the sessions list;
///   3. `beginSession(name, bench:)` — **with the bench**, which the core now
///      refuses to do without (064f): a birth that names no document renames
///      nothing, and the text would then leave wearing pre-birth names while
///      the payload claimed the new session. A refusal → nothing leaves, and
///      `ground.trouble` is what it says;
///   4. **refresh the bench** — every name on it has just changed — and ask the
///      core **again** for the text: what is handed out is read after the
///      birth, never before it.
///
/// ## Why this is not written inside the widget
///
/// A core call started in a widget callback does not resume under
/// `testWidgets`, so an order followed inside `onPressed` cannot be measured —
/// the same reason [sessionBegunSaid] is worded out here instead of in the
/// room. Out here a guard drives it directly, and the press above it becomes
/// one line with nothing left in it to get wrong.
///
/// ## The last step is the one that is easy to lose
///
/// The sheet captures its payload when it builds, and the birth happens after
/// that: **nothing rebuilds between the act and the clipboard.** A closure
/// holding the captured view would take out the pre-birth text with the new
/// session's name stamped on it — true of the snapshot, false of the names.
/// From the core's side nothing is wrong, and no core guard can see it. That is
/// why the text is asked for a second time, after the birth, and why both asks
/// go to the core: a text read off the bench is a text nobody was asked about.
/// ## Every exit takes the payload, and that is rule 62
///
/// There was a parameter here — `thePayloadLeaves` — and it was `false` for
/// exactly one caller: the door that sent the document as it stands, for which
/// steps 1 and 4 were about a text it did not send. The owner deleted that
/// door on 17 October, so the parameter is deleted with it rather than left
/// standing at a default: a flag that turns the payload law off is the way a
/// future door gets written without one, and the one state it allowed was the
/// state rule 62 forbids.
///
/// So all four exits — the clipboard, the PDF, a protected send through a key,
/// and the chat's own — go through step 1 and step 4, and nothing here can be
/// asked to skip them.
///
/// ## Step 0, and why it is step 0 — 081
///
/// **The owner, 13 Oct: «the work always happens on a clean container».** The
/// first act of every exit press is emptying the clipboard — before the name,
/// before the session, before the payload. Not «clear it when a copy fails»,
/// which is a branch somebody has to remember in every refusal written from
/// now on: clear first and no branch below can forget it, because there is
/// nothing left to forget.
///
/// It is here, and not in the two presses, for the reason the rest of the
/// order is here: out here a guard drives it, and a press that only says what
/// it means has nothing left in it to get wrong.
///
/// What this closes is not something the app wrote. It is what it **left**: a
/// refusal wrote nothing and erased nothing, so whatever the person had copied
/// before — on 12 Oct, the same letter in the clear — was still there to be
/// pasted into a model. The guard that stood over this counted the app's
/// writes and read a sentinel nobody would ever have on their clipboard, so it
/// was green through the whole of it. What a person pastes after pressing our
/// button is ours.
Future<WhatMayLeave> beginThenRead(Ground ground, Workbench bench) async {
  // Step 0. Nothing above this line, ever — and the rule itself lives in
  // `the_clipboard.dart`, where its five seats can read one copy of it.
  await emptyTheClipboardFirst();
  // Step 1. **The core decides whether anything may leave at all** — 083a.
  // Asked before the birth so that a press which takes nothing out leaves
  // nothing behind it either: no session, no rename, only an empty clipboard
  // and the review open on the word that is waiting.
  var got = await _whatMayLeave(bench);
  if (got.refused != null) {
    return WhatMayLeave(
      refused: got.refused,
      landedOnTheWaitingWord: got.lit,
    );
  }
  int? renamed;
  String? said;
  if (ground.aSessionWouldBeBorn) {
    // **Step 2 is not a refusal, and not a question** — 081. A person pressing
    // an exit wants their text out and is not asking to be interviewed about
    // what the drawer is called. They get «Session N», and the sessions list
    // is where they give it their own word if they ever want to.
    renamed = await ground.beginSessionItNames(bench: bench.session);
    if (renamed == null) {
      return WhatMayLeave(
        refused: ground.trouble ??
            'The session was not begun, so nothing was taken out.',
      );
    }
    said = sessionBegunSaid(renamed, hadDocument: bench.document != null);
    await bench.refresh();
  }
  // Step 4. **The text, from the core, and read again when a birth moved the
  // names.** It used to be read off the bench — `bench.payload` is the
  // workspace snapshot's own payload, the text drawn in the Safe column — and
  // reading it there asked the core nothing, which is how a word still waiting
  // for an answer went out on the clipboard and into the PDF while the send
  // refused. One law, one door, three exits (083a, contract C3).
  //
  // Asked twice only when there was a birth: that is the one event between the
  // first ask and here, and it renames every token in the text.
  if (renamed != null) {
    got = await _whatMayLeave(bench);
    if (got.refused != null) {
      return WhatMayLeave(
        said: said,
        renamed: renamed,
        refused: got.refused,
        landedOnTheWaitingWord: got.lit,
      );
    }
  }
  final view = got.view!;
  final open = ground.openSession;
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

/// The text the core lets out, or the sentence that says why it does not — and,
/// when a word is waiting, the review opened on it.
///
/// One helper rather than two call sites, because the refusal does two things
/// and both of them must happen at every exit: it says the number of words
/// waiting, and it opens the review on the first of them (083, rule 12). The
/// law itself is in the core, in one function, and nothing here re-reads a
/// count to decide anything.
Future<({PayloadView? view, String? refused, bool lit})> _whatMayLeave(
  Workbench bench,
) async {
  try {
    return (
      view: await z.payloadToTakeOut(session: bench.session),
      refused: null,
      lit: false,
    );
  } on ApiError catch (e) {
    // **No word of the error is read here** — G20 and `messages_test`'s own
    // guard: no widget interprets an `ApiError` by itself, and this helper is
    // not an exception to a rule that exists because one error came to say
    // three different things on three screens.
    //
    // Nothing needs reading. Opening the review on the first waiting word is
    // the right act whenever there **is** one, and when there is none — an
    // empty document, a refusal of another kind — the method does nothing,
    // because `theFirstWaitingWord` has nothing to hand it. The law stays in
    // the core; what is decided here is only where the person's eye goes.
    final said = humanMessage(e);
    final lit = bench.openTheReviewAtTheFirstWaitingWord(
      said: andTheClipboardIsEmpty(said),
    );
    return (view: null, refused: said, lit: lit);
  }
}

/// **The third exit: the same order, and then the send** — 064/A.
///
/// The owner's own 9 October run found this door going straight to the model:
/// the answer came back, no session was born, and nothing was written into a
/// conversation. The two manual exits had the order; this one — the only exit
/// that actually puts text on a wire — did not.
///
/// It is one function rather than two presses with the same four lines in them,
/// and it is out here for the reason [beginThenRead] is: **a core call started
/// in a widget callback does not resume under `testWidgets`**, so an order
/// written inside `onPressed` cannot be measured, and a send is an awaited core
/// call by its nature. Here a guard drives the whole order — the birth, the
/// refresh and the request — and reads what came out of the socket at the other
/// end.
///
/// One thing it does not do, deliberately: **it does not retry.** A protected
/// send that fails is reported as having failed, and there is nothing else for
/// it to reach for — since rule 62 this app has one send door, and what it
/// carries is the payload.
///
/// It read a mode here until 17 October, and chose between two core calls by
/// it. Both halves of that are gone: the choice was deleted from «Who
/// answers», and the call that took a document was deleted from the contract.
///
/// The payload it checks and the handle it sends are **one build**: both come
/// off `Workbench.snap`, so the `refresh` inside [beginThenRead] moves them
/// together and there is no window in which the view is fresh and the handle
/// stale. Were they two reads, the core would still refuse the stale one — but
/// the honest version of that sentence is that they are not two reads.
///
/// **Measured, so that nobody deletes the refresh on the strength of a green
/// suite:** with all three of [beginThenRead]'s layers taken out, this door
/// does not send pre-birth names — the core refuses the pre-birth *handle*,
/// because a birth bumps the session's revision («This request is no longer
/// current»). Four layers here; the clipboard has three, since its text comes
/// off the view and there is no core call left to refuse it. The refresh is
/// what makes the person's send happen rather than hand them a refusal to
/// decipher.
Future<WhatMayLeave> beginThenAsk(
  Ground ground,
  Workbench bench, {
  required String providerId,
}) async {
  final out = await beginThenRead(ground, bench);
  if (out.refused != null) return out;
  final bad = await bench.askModelProtected(providerId);
  if (bad != null) {
    // A birth that happened still happened, and its sentence is still true: the
    // session is open, its names are on the bench, and the send is what failed.
    return WhatMayLeave(said: out.said, renamed: out.renamed, refused: bad);
  }
  return out;
}

/// The columns a table carried that this build could not name a kind for.
///
/// Named, never dropped: a person must be able to see the difference between
/// «imported» and «imported the names». And it says what to do about it,
/// because a column is a word in their own file and they can change it.
String columnsNotUsedSaid(List<String> columns) {
  final which = columns.join(', ');
  return columns.length == 1
      ? 'One column was not used: $which — name the kind for it, or it stays out.'
      : '${columns.length} columns were not used: $which — name the kind for each, or they stay out.';
}

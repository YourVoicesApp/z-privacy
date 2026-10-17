// The shell: which screen is on, and the one place that decides it.
//
// It lives apart from `main.dart` so that the decision can be tested. That is
// not a theoretical tidiness — the first version of this code never showed the
// first-run page at all, because the settings arrive after the first frame and
// nothing asked the question again. A screen can be tested in isolation; the
// choice *between* screens can only be tested if something can build it.

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/the_clipboard.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/widgets/the_way_back.dart';
import 'package:zprivacy/core/messages.dart';

/// The three kinds a build reads today. Kept here because the core decides what
/// it can read and the UI only names the extensions that map onto it.
const _kinds = <String, DocumentKind>{
  'txt': DocumentKind.txt,
  'md': DocumentKind.txt,
  'csv': DocumentKind.txt,
  'docx': DocumentKind.docx,
  'pdf': DocumentKind.pdf,
};

class ZShell extends StatefulWidget {
  const ZShell({super.key, this.dataDir, this.ground});

  /// Where the vault lives. Passed in rather than found here, so a test can
  /// point the whole shell at a folder of its own.
  /// Where the vault goes. Null means «ask the core», which is what the app
  /// does; the tests pass a folder of their own.
  final String? dataDir;

  /// An already-started `Ground`, for tests.
  ///
  /// Not a convenience: a future created inside `testWidgets`' fake-async zone
  /// never completes, so a shell that calls into Rust from `initState` can
  /// never finish starting in a test. Handing it a `Ground` that was refreshed
  /// outside that zone leaves the thing actually under test — which screen the
  /// shell chooses — reachable.
  final Ground? ground;

  @override
  State<ZShell> createState() => _ShellState();
}

class _ShellState extends State<ZShell> {
  late final Ground _ground = widget.ground ?? Ground();
  Workbench? _bench;

  /// **The home's own conversation** (046/G).
  ///
  /// A second bench, beside the document's, and deliberately not the same one:
  /// `_bench` being non-null is what puts the Workspace on screen, so a chat
  /// held there would throw a person out of the home the moment they asked
  /// something. This one is opened at the first question and lives until the
  /// app closes, which is what «conversations are not saved» already promises.
  Workbench? _chat;
  String? _trouble;

  /// The report the core wrote about the file it would not open. Built at the
  /// moment of the refusal, because that is when the name and the size are
  /// still in hand — and a person whose document will not open needs something
  /// they can send that is not the document.
  String? _troubleReport;
  bool _vaultOpen = false;
  bool _settingsOpen = false;
  /// Passed for this run. The lasting answer is in the settings, which live in
  /// the vault — so on a device with no vault this page comes back next time,
  /// and that is the truth rather than a bug: nothing was written down.
  bool _firstRunPassed = false;

  /// The one thing in this app that watches the window.
  ///
  /// It lives here and nowhere else on purpose: a second watcher in a screen
  /// would mean two places deciding what a window event means, and neither of
  /// them is allowed to decide at all. The core is told what happened and it
  /// does the deciding — `windowFocusLost` and `windowHidden` are the two
  /// doors, and both end every reveal.
  ///
  /// The states are the measured ones, not the guessed ones (Flutter 3.44.2,
  /// Linux/GTK, written down before any of this was promised):
  ///
  ///   * `inactive` — another window took the front. It also arrives once at
  ///     startup and again during a restore, which costs nothing: covering
  ///     what is already covered asks nothing of anybody.
  ///   * `hidden` — minimised, or moved to a workspace that is not the visible
  ///     one. Both produce it, so the promise is «when the window goes», not
  ///     «when it is minimised».
  late final AppLifecycleListener _window;

  /// Report the event, then stop drawing what the screen still holds — in this
  /// frame, not when a timer next comes round. The core is emptied at once, but
  /// the panel keeps the text it was handed until it asks again, and a value
  /// drawn a second after the window went is a value that was on screen after
  /// the window went.
  ///
  /// And it fails closed. If the core cannot be told, the screen drops what it
  /// holds anyway: staying quiet used to mean the value sat there until its own
  /// time ran out. No failure of these two calls can be produced through the
  /// contract today, so that half is a guard without a red test — the same
  /// honesty as the vault room's ticker.
  Future<void> _report(Future<void> Function() tell) async {
    try {
      await tell();
    } catch (_) {
      _bench?.hideEverything();
      return;
    }
    await _bench?.syncReveals();
  }

  @override
  void initState() {
    super.initState();
    _window = AppLifecycleListener(
      onInactive: () => unawaited(_report(z.windowFocusLost)),
      onHide: () => unawaited(_report(z.windowHidden)),
    );
    // The shell itself decides which screen is on: first run, settings, the
    // vault, the workspace, home. That decision reads `Ground`, so the shell has
    // to rebuild when `Ground` changes — the screens' own `ListenableBuilder`s
    // rebuild their contents, not the choice of screen.
    //
    // Without this the first-run page never appeared at all: the settings arrive
    // after the first frame, and by then nothing asked the question again. Found
    // by running the program, not by a test.
    _ground.addListener(_groundChanged);
    if (widget.ground == null) _start();
  }

  void _groundChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    // The vault lives beside the app's own data, and the core is told once where.
    // It is the only file this program writes (gate G15).
    //
    // The screen no longer decides where that is. It used to read HOME and fall
    // back to the temp directory, which was right on Linux and wrong on Windows,
    // where HOME is usually unset — the vault would have gone to a folder the
    // system empties. The core owns these files and says where they belong.
    try {
      final dir = widget.dataDir ?? await z.defaultDataDir();
      await z.setDataDir(dir: dir);
    } on ApiError catch (e) {
      _trouble = humanMessage(e);
    }
    await _ground.refresh();
  }

  @override
  void dispose() {
    _window.dispose();
    _ground.removeListener(_groundChanged);
    _bench?.dispose();
    _chat?.dispose();
    _ground.dispose();
    super.dispose();
  }

  /// Read the home's line into the conversation and scan it.
  ///
  /// The vault gate is the same one `_begin` holds and for the same reason
  /// (041-N, the owner: «you cannot begin without an open vault») — the door
  /// opens instead of the work, and asking a model is beginning work. The
  /// session is opened once and reused, so the answers of one conversation
  /// stay in it; the text of each question replaces the last, which is what
  /// the core's one-document-per-session shape already means.
  ///
  /// It scans and stops. What happens next belongs to the screen, because it
  /// depends on what the scan found — and the one thing that may not happen
  /// here is sending.
  Future<void> _askFromHome(String text) async {
    if (_ground.vault != VaultState.unlocked) {
      setState(() => _vaultOpen = true);
      return;
    }
    // **One rule, both doors** — 080. This read `config.packId` and never
    // looked at the session at all, which is the whole of the owner's finding:
    // a German conversation read with an English eye. Since rule 57 the same
    // one function also **asks**, when the text about to be read is the first
    // in a session that does not exist yet.
    final packId = await _theLanguageOfTheTextToCome();
    if (packId == null || !mounted) return;
    try {
      var chat = _chat;
      if (chat == null || chat.packId != packId) {
        // The language the session holds, or the application's — and a change
        // of either opens a new bench rather than scanning tomorrow's question
        // with yesterday's language.
        final session = await z.openSession(profileId: null, packId: packId);
        chat?.dispose();
        chat = Workbench(session: session, profileId: null, packId: packId);
      }
      await z.importText(session: chat.session, text: text);
      await _theDocumentHasEntered(chat);
      if (!mounted) return;
      setState(() {
        _chat = chat;
        _trouble = null;
        _troubleReport = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _trouble = humanMessage(e);
        _troubleReport = null;
      });
    }
  }

  /// **The language the next text is read with** — rule 57, and the one place
  /// that decides it for every door on this screen.
  ///
  /// A session that has a language of its own is never asked again (rule 57c,
  /// rule 33): `packForTheNextText` answers for it, and for a text with no
  /// session and nowhere to keep one it answers with the application's.
  ///
  /// **A session that does not exist yet is asked** — rule 57b. The text about
  /// to be read is the first thing in a session that is born as it enters the
  /// preview (rule 55), so this is the one instant at which the question can be
  /// asked before the scanner needs the answer. The application's language is
  /// no longer taken silently here: that is exactly what the owner met on 16
  /// October when he made a session and was never asked.
  ///
  /// **And an old session is asked too, once** — rule 57-د, 17 October. A
  /// session created before 080 carries no language of its own, and until now
  /// `packForTheNextText` answered for it with the application's: the owner's
  /// German session read with an English eye, and nobody asked. It is the same
  /// question at the same instant — before the first text is read in it — and
  /// the same dialog asks it. The answer is **written into that session** by
  /// its number, so «once» is a fact about the file and not a hope: the next
  /// door finds a language and asks nothing.
  ///
  /// `null` means «not now»: the caller reads nothing, so no session is born,
  /// nothing is kept, and the screen says that rather than leaving a press that
  /// did nothing and said nothing.
  Future<String?> _theLanguageOfTheTextToCome() async {
    final said = packForTheNextText(_ground);
    if (said != null) return said;
    if (!mounted) return null;
    // Read **before** the dialog: the answer is written into this session, and
    // after the await «the open session» is a second reading of a fact that
    // this function already took.
    final old = _ground.openSessionRow;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => TheLanguageOfANewSession(ground: _ground),
    );
    if (!mounted) return null;
    if (chosen == null) {
      setState(() {
        _trouble = noLanguageSoNothingWasRead(aSessionIsOpen: old != null);
        _troubleReport = null;
      });
      return null;
    }
    if (old != null && !await _ground.setSessionPack(old.number, chosen)) {
      // The core refused and said why in its own words; a language that could
      // not be written is not a language this session has, so nothing is read
      // with it.
      if (!mounted) return null;
      setState(() {
        _trouble = _ground.trouble ?? unnamedTrouble;
        _troubleReport = null;
      });
      return null;
    }
    return chosen;
  }

  /// **A document has entered the preview** — rule 55, the glass's half of it.
  ///
  /// Two things follow every import, and neither of them belongs to one door:
  ///
  ///   * the scan the core ran as it read the text is read back onto the bench
  ///     (item 3, 14 October — the core scans at the door, this looks at what
  ///     arrived);
  ///   * **the session the document was kept in is now in the list** — born at
  ///     this very instant if there was none, by the owner's rule of 16
  ///     October — so the ground is asked again. Without it the Sessions room
  ///     draws the list as it stood before the document existed, and the rule
  ///     says «the moment it enters the preview», not «the next time something
  ///     else refreshes».
  ///
  /// One function because there are two doors on this screen and a law written
  /// at one of them is this house's most expensive trap; G37 counts the doors
  /// and reads this name in each.
  Future<void> _theDocumentHasEntered(Workbench bench) async {
    await bench.readTheScanThatArrivedWithIt();
    await _ground.refresh();
  }

  /// Open a session. Two ways in, and they ask for different things.
  ///
  /// **Typed or pasted**: nothing is asked. The text is read with the pack the
  /// settings already hold, which is the one the top bar names and can change.
  /// The owner, 6 October: the writing screen is the main screen, and a person
  /// who writes a sentence is not asking to be interviewed first.
  ///
  /// **A file**: the language is asked *after* it is chosen and before it is
  /// read, because by then there is a document to ask about — and because a
  /// file is the case where the answer is most often not the usual one. That
  /// step is temporary: 043 gives the pack a vote of its own.
  ///
  /// In both paths the scan runs the moment the text is in: nobody has to press
  /// anything to be protected. **And not because this method remembers to ask**
  /// — the import doors scan in the core since 14 October (item 3), so a door
  /// that forgot would still be a door that protects.
  Future<void> _begin({required bool typing, String? text}) async {
    // 041-N, the owner: «you cannot begin without an open vault». Not a
    // warning and not a line in a band — the door opens instead of the work.
    // Everything a person does to start — «+», a pasted page, the composer —
    // comes through here, so this is the one place that has to hold.
    if (_ground.vault != VaultState.unlocked) {
      setState(() => _vaultOpen = true);
      return;
    }

    XFile? file;
    DocumentKind? kind;
    final profileId = null as String?;

    // **080 — the language is not asked here, and not asked anywhere** — with
    // the one exception rule 57b made on 16 October: a session that is about to
    // be born has no language to read with, and the scanner needs one before it
    // reads. The session's own language, or the application's for a session
    // that has none, or the person's answer when there is no session at all.
    // 075d's «asked once in a conversation's life» is not back: this asks once
    // in a *session's* life, at the instant one begins.
    //
    // **The file is chosen first**, so the question is asked about a document
    // the person has actually picked and a cancelled file dialog asks nothing.
    if (!typing) {
      final chosen = await _aFileToRead();
      if (chosen == null) return;
      file = chosen.file;
      kind = chosen.kind;
    }
    final packId = await _theLanguageOfTheTextToCome();
    if (packId == null || !mounted) return;

    try {
      final session = await z.openSession(profileId: profileId, packId: packId);
      // **Nothing is written here any more** — 080. A document does not give a
      // session its language: the session was given one when it was created,
      // or it takes the application's, and `null` stays «never chosen» rather
      // than being filled in by whichever file happened to be opened first.
      final bench = Workbench(session: session, profileId: profileId, packId: packId);
      if (typing) {
        await z.importText(session: session, text: text ?? '');
      } else {
        await z.importDocument(
          session: session,
          name: file!.name,
          bytes: await file.readAsBytes(),
          kind: kind!,
        );
      }
      // On import, at once, with no dialog — and by the core's own hand since
      // 14 October: the scan is part of reading the document, at both doors
      // and in whatever order a caller happens to do things.
      await _theDocumentHasEntered(bench);
      _bench?.dispose();
      setState(() {
        _bench = bench;
        _trouble = null;
        _troubleReport = null;
      });
    } on ApiError catch (e) {
      // A refusal is news, not a failure: «a scanned PDF with no text layer is
      // refused with the reason, not silently imported empty».
      final report = await _reportOfRefusal(e, file);
      if (!mounted) return;
      setState(() {
        _trouble = humanMessage(e);
        _troubleReport = report;
      });
    }
  }

  /// **Open a saved document in the preview, as it was left** — 089 rule 9.
  ///
  /// The same shape as `_begin` and `_readBack`, and the same vault gate at the
  /// front of it (041-N): a bench of its own, the core puts the document back
  /// on it with every decision that was on it, and **nothing is scanned** —
  /// the marks are the ones the person left, not a new scan's.
  ///
  /// The session is entered first when it is not the open one. A document
  /// belongs to the conversation that saved it, and opening it from another
  /// conversation would put its names in a room that cannot read them.
  Future<void> _openKept(int number, int which, bool chat) async {
    if (_ground.vault != VaultState.unlocked) {
      setState(() => _vaultOpen = true);
      return;
    }
    try {
      if (_ground.openSession != number) await _ground.enterSession(number);
      // **Its own session's language, and after entering it** — rules 33 and
      // 57c. Read before the entering, as it was until 16 October, this was the
      // language of whichever session happened to be open: a German document
      // saved in one session, re-opened from another, came back on a bench that
      // reads English.
      //
      // **Through the one hand since rule 57-د**, and not `packForTheNextText`
      // on its own: coming back to a kept document is a reading of a text in a
      // session, so a session created before 080 is asked here exactly as it is
      // at the other three doors. It was the fourth door, and a law written at
      // three doors out of four is this house's most expensive trap — this one
      // would have gone on reading an old session's documents with the
      // application's eye.
      final packId = await _theLanguageOfTheTextToCome();
      if (packId == null || !mounted) return;
      final session = await z.openSession(profileId: null, packId: packId);
      final bench = Workbench(session: session, profileId: null, packId: packId);
      await z.openKeptDocument(number: number, which: which, chat: chat, bench: session);
      // **The same reading as an import, and it is the same act**: this reads
      // what the core already holds and asks for no scan of its own (item 3
      // moved the scan into the core, and a restored document carries the
      // marks it was put away with). One function rather than a second name
      // for one act — only its name speaks of an import, and what it does is
      // «look at what is on the bench».
      await bench.readTheScanThatArrivedWithIt();
      _bench?.dispose();
      setState(() {
        _bench = bench;
        _settingsOpen = false;
        _trouble = null;
        _troubleReport = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _trouble = humanMessage(e);
        _troubleReport = null;
      });
    }
  }

  /// Ask the core what it would say about a file it refused. The screen works
  /// out none of it: the name and the size go in, the sentence comes back.
  Future<String?> _reportOfRefusal(ApiError error, XFile? file) async {
    if (error is! ApiError_DocumentRefused || file == null) return null;
    try {
      final size = await file.length();
      return await z.importReport(
        subject: ReportSubject.refused(
          name: file.name,
          bytes: size > 0xFFFFFFFF ? 0xFFFFFFFF : size,
          refusal: error.reason,
        ),
      );
    } on ApiError {
      // A report about a refusal must never become a second refusal.
      return null;
    }
  }

  /// **One file chooser for both doors that take a file** — the one to work on
  /// and the one coming back (089 rule 5).
  ///
  /// Written out of `_begin` rather than beside it: the list of extensions and
  /// the sentence for a file this build cannot read are one fact each, and the
  /// second door would have been the second place to keep them — the trap
  /// 083a's three exits and 080's two language doors both cost this house.
  ///
  /// `null` means «nothing to read»: the person closed the chooser, the widget
  /// is gone, or the file is of a kind no reader here has — and in that last
  /// case the sentence is already on the screen when this returns.
  Future<({XFile file, DocumentKind kind})?> _aFileToRead() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Documents', extensions: ['pdf', 'docx', 'txt', 'md', 'csv']),
      ],
    );
    if (file == null || !mounted) return null;
    final kind = _kinds[file.name.split('.').last.toLowerCase()];
    if (kind == null) {
      setState(() {
        _trouble = 'This build reads PDF, Word and text files. '
            '«${theirOwnWord(file.name)}» is none of those.';
        // Nothing was read, so the core has nothing to report about it.
        _troubleReport = null;
      });
      return null;
    }
    return (file: file, kind: kind);
  }

  /// **«z-pdf» — the door back** (079 rule 3, built as 089 rule 5).
  ///
  /// The owner, 15 October: «خيار يدعى z-pdf يقوم بعكس العملية، يبحث عن الكود
  /// ليحوله إلى اسم». So it is the reverse act and not a second way in: the
  /// file is read into its own names and shown, and **no bench is opened for
  /// it at all**. The core's door takes no session, which is what makes «never
  /// scanned, never protected» a thing this screen cannot get wrong (G34).
  ///
  /// The vault gate is the same one `_begin` and `_askFromHome` hold, and here
  /// it is also 079 rule 8: a locked vault is a standing door, because the key
  /// to a z-pdf's meaning lives in one place. The door opens instead of a
  /// sentence about why nothing came back.
  ///
  /// One press opens the reading. There is no "Read it back" to press after
  /// it, which is the difference between this door and the banner's: a person
  /// who chose «z-pdf» has already said what they want.
  Future<void> _readBack() async {
    if (_ground.vault != VaultState.unlocked) {
      setState(() => _vaultOpen = true);
      return;
    }
    final chosen = await _aFileToRead();
    if (chosen == null) return;
    try {
      final seen = await z.readADocumentThatCameBack(
        bytes: await chosen.file.readAsBytes(),
        kind: chosen.kind,
      );
      if (!mounted) return;
      setState(() {
        _trouble = null;
        _troubleReport = null;
      });
      await showDialog<void>(
        context: context,
        builder: (_) => TheReading(seen: seen),
      );
    } on ApiError catch (e) {
      // A file that cannot be read is news here exactly as it is at the other
      // door, and it is the same report: the name, the size, the refusal's own
      // word, and nothing of what is in the file.
      final report = await _reportOfRefusal(e, chosen.file);
      if (!mounted) return;
      setState(() {
        _trouble = humanMessage(e);
        _troubleReport = report;
      });
    }
  }

  void _home() {
    final bench = _bench;
    setState(() => _bench = null);
    bench?.dispose();
    _ground.refresh();
  }

  @override
  Widget build(BuildContext context) {
    // **063 — the settings cover the work, they do not replace it.**
    //
    // Everything below `_body` is a chain of early returns and the settings
    // used to be one of them, which is why they could not be reached from a
    // document: a control that unmounted the document could not be put on the
    // document's own bar. They are a panel over whatever the chain chose now,
    // 480 wide against the right edge — the owner's number — and the chain
    // itself is untouched but for the one return that became this panel.
    return Stack(
      children: [
        _body(context),
        if (_settingsOpen)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 480,
            child: SettingsScreen(
              ground: _ground,
              // **The document in front of the person, handed to the panel** —
              // 064f. A session begun in the Sessions room has to re-derive the
              // names already on that document, and the panel had no way to
              // know which document it was: the room's «Begin» called with no
              // bench, nothing was renamed, and the payload that left
              // afterwards wore pre-birth names while claiming the session.
              // The shell is the only place that holds both the panel and the
              // bench, so it is the only place this can come from.
              bench: _bench?.session,
              // **089 rule 9: a saved document opens in the preview.** The
              // panel lists what each session is holding; only the shell can
              // put a document in front of the person, so the press comes
              // here, exactly as the «+» and «z-pdf» presses do.
              onOpenKept: (number, which, chat) =>
                  unawaited(_openKept(number, which, chat)),
              onClose: () {
                setState(() => _settingsOpen = false);
                _ground.refresh();
              },
            ),
          ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final config = _ground.config;
    if (config != null && !config.firstRunDone && !_firstRunPassed) {
      return FirstRunScreen(
        ground: _ground,
        onStart: (language, {required bool wantsVault}) async {
          // The vault screen is reached the ordinary way — the shell's own
          // door — so the first run ends in exactly one place whatever was
          // pressed.
          setState(() {
            _firstRunPassed = true;
            _vaultOpen = wantsVault;
          });
          await _ground.saveConfig(Settings(
            scanOnImport: config.scanOnImport,
            revealSeconds: config.revealSeconds,
            autoLockMinutes: config.autoLockMinutes,
            // The language picks the pack, and it must really pick it.
            //
            // This line used to read `language == 'de' ? 'de' : config.packId`,
            // which was honest only while German was the only pack there was:
            // choosing English left the pack German while the page said «This
            // picks the privacy pack». M7.10B shipped an English set and turned
            // that into a plain untruth on the first screen of the product.
            packId: language == 'de' ? 'de' : 'en',
            originalPanePercent: config.originalPanePercent,
            columnsInStep: config.columnsInStep,
            // Carried from what is already there, as every other field on this
            // page is: the first run chooses a language, and nothing else.
            safeColumnOpen: config.safeColumnOpen,
            reviewPanelWide: config.reviewPanelWide,
            language: language,
            firstRunDone: true,
            sessionOnly: config.sessionOnly,
          ));
        },
      );
    }
    // The settings used to return here, and that return is the whole of 063:
    // it is now the panel in `build` above, so the screen the chain picks below
    // stays on the glass behind it.
    // Before the Workspace, not after it: the vault has to be reachable **from
    // a document**, because that is where «Always» is pressed. Closing it puts
    // the document back exactly as it was — the bench is untouched by any of it.
    // The vault stands in front of the home, every time, until it is open:
    // on the first run after the language is chosen, and on every later start
    // where it is locked. A document already open is not interrupted — the
    // gate is about *starting* work, and a person in the middle of a review
    // whose vault auto-locked still has their document in front of them.
    final mustOpenTheVault = _bench == null && _ground.vault != VaultState.unlocked;
    if (_vaultOpen || mustOpenTheVault) {
      return VaultScreen(
        ground: _ground,
        // 075a: the profile door lives on the board now, and it needs the
        // bench it would be switching. Null when the board is opened with no
        // document open, which is a real state and the board allows for it.
        bench: _bench,
        onClose: () async {
          final was = _ground.vault;
          setState(() => _vaultOpen = false);
          await _ground.refresh();
          // A document that was read without the vault was read without a
          // whole layer. If the vault's state changed while this screen was
          // open, the answer on the other side of it can change too, so the
          // document is read again on the way back — the owner's «open the
          // vault before starting work», for a person who did not.
          final bench = _bench;
          if (bench != null && _ground.vault != was) {
            await bench.rescanAfterVault();
          }
        },
      );
    }
    final bench = _bench;
    if (bench != null) {
      return WorkspaceScreen(
        bench: bench,
        ground: _ground,
        onHome: _home,
        onVault: () => setState(() => _vaultOpen = true),
        onSettings: () => setState(() => _settingsOpen = !_settingsOpen),
        settingsOpen: _settingsOpen,
      );
    }
    return Stack(
      children: [
        HomeScreen(
          ground: _ground,
          version: coreVersion(),
          chat: _chat,
          onImport: () => _begin(typing: false),
          onReadBack: () => unawaited(_readBack()),
          onType: (text) => _begin(typing: true, text: text),
          onAsk: _askFromHome,
          onVault: () => setState(() => _vaultOpen = true),
          onSettings: () => setState(() => _settingsOpen = !_settingsOpen),
          settingsOpen: _settingsOpen,
        ),
        if (_trouble != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() {
                      _trouble = null;
                      _troubleReport = null;
                    }),
                    child: Trouble(
                      _trouble!,
                      onCopyReport: _troubleReport == null
                          ? null
                          : () async {
                              await emptyTheClipboardFirst();
                              await Clipboard.setData(
                                ClipboardData(text: _troubleReport!),
                              );
                            },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

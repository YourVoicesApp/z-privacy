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

import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/the_clipboard.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
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
  const ZShell({super.key, this.dataDir, this.ground, this.troubleAtTheStart});

  /// Where the vault lives. Passed in rather than found here, so a test can
  /// point the whole shell at a folder of its own.
  /// Where the vault goes. Null means «ask the core», which is what the app
  /// does; the tests pass a folder of their own.
  final String? dataDir;

  /// **What went wrong before any screen existed**, if anything did — the one
  /// sentence `main.dart` cannot show by itself, because it has no glass.
  ///
  /// Today it carries exactly one thing: a folder the core would not name or
  /// could not use. That is said before `runApp`, so there is no screen to put
  /// it on at the moment it happens, and a start-up fault that reaches nobody
  /// is how the whole of 18 October's fault stayed quiet for two builds.
  final String? troubleAtTheStart;

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

  // **The home's own second conversation is gone** (046/G, deleted by rule
  // 70). It existed because `_bench` being non-null was what put the Workspace
  // on screen: a chat held there would have thrown a person out of the home
  // the moment they asked something, so the home opened a bench of its own. The
  // home is gone, the Workspace is the screen, and one bench is the whole of
  // what a person is working on — so the second one is deleted rather than
  // kept for a screen nobody can reach (rule 35).
  String? _trouble;

  /// What went wrong before any screen existed, until a person presses it away.
  String? _atTheStart;

  /// The report the core wrote about the file it would not open. Built at the
  /// moment of the refusal, because that is when the name and the size are
  /// still in hand — and a person whose document will not open needs something
  /// they can send that is not the document.
  String? _troubleReport;
  bool _vaultOpen = false;
  bool _settingsOpen = false;

  /// **Which room the panel opens on, when a press named one** — rule 74, 18
  /// October 2026. `null` is «the room the settings open on», which is the
  /// settings' own default and the one place that rule lives; a door that is
  /// about a key sets this to `SettingsRoom.ai` as it opens the panel, so the
  /// sheet's «Open Settings» still lands where a key is given.
  SettingsRoom? _settingsRoom;
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
    // **The sentence from before the first frame**, kept apart from `_trouble`
    // for a measured reason: `_trouble`'s band is drawn inside `_body`, past
    // the early returns, so it is on the one screen only — and a folder that
    // cannot be used puts a person on the **first-run** page, because with no
    // folder the core has no settings to say the first run is done. The one
    // sentence that explains that would have been drawn on a screen they
    // cannot reach. It has a band of its own, over every screen.
    _atTheStart = widget.troubleAtTheStart;
    // **The folder is not set here any more** — 18 October. This condition is
    // a test door (see `ground` above), and while the one call that tells the
    // core where the files live sat behind it, a shipped app that passed a
    // `Ground` was never told. `main.dart` says it now, before `runApp`.
    // `_start()` stays for the tests that bring a folder of their own.
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
    _ground.dispose();
    super.dispose();
  }

  // **«Ask the AI» from the home is gone with the home** — rule 70, and it
  // takes rule 60-أ's band with it: that rule split the press in two «في
  // المحادثة، حيث لا جانب معاينة» — in the chat, where there is no preview
  // side — and after rule 70 there is no such place. The one screen always has
  // the middle column, so the law «you see what will leave, then you choose
  // who answers» is kept by the surface itself, which is the rule's other half
  // («وزر AI في سطح العمل يفتح جانب المعاينة دائماً قبل الأبواب») and still
  // measured in G42.
  //
  // What a person writes at the top of the screen now enters the preview, the
  // same door a file comes in by — `_begin(typing: true)` — and is asked about
  // from the middle column like everything else.

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

  /// **A question written with no document** — rule 72, 18 October 2026:
  /// «نحتاجه أن يظهر من اللحظة الأولى، وبذلك يمكننا الشات مباشرة بدون أي
  /// وثائق».
  ///
  /// It was `_begin(typing: true, text: …)`, which **imported** what was typed
  /// as a document — the way-in strip's own act, and that strip's box is gone
  /// (rule 72-أ). What is typed is the request now: protected where every
  /// question is protected, standing in the Safe column, and with no document
  /// above it the whole of what leaves (ed's `build_the_question_alone`).
  ///
  /// The vault gate and the language question are the two this shell asks at
  /// every other door: a session is about to be born, and the scanner needs a
  /// language before it reads a word (rule 57b).
  Future<void> _askWithNoDocument(String text) async {
    if (text.trim().isEmpty) return;
    if (_ground.vault != VaultState.unlocked) {
      setState(() => _vaultOpen = true);
      return;
    }
    final packId = await _theLanguageOfTheTextToCome();
    if (packId == null || !mounted) return;
    try {
      final session = await z.openSession(profileId: null, packId: packId);
      final bench = Workbench(session: session, profileId: null, packId: packId);
      // **Nothing is imported**: there is no document, and the question is the
      // whole of it. `setQuestion` is what protects it, in the session it will
      // leave from.
      final bad = await bench.setQuestion(text);
      _bench?.dispose();
      if (!mounted) {
        bench.dispose();
        return;
      }
      setState(() {
        _bench = bench;
        _trouble = bad;
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

  /// **«Remove the document»** — rule 73, the owner, 18 October 2026.
  ///
  /// The first part empties and **nothing leaves**: no exit, no bubble, no
  /// question (54-و). The kept copy stays in its session's list (54-ز) and
  /// opens again from there, because what is kept belongs to the session and
  /// not to the surface.
  ///
  /// It is a **new bench, not an emptied one**: a bench *is* a session in the
  /// core, and no door takes a document back out of one — nor should one,
  /// since 089 keeps what entered. So a fresh session is opened in the same
  /// profile and language, what was typed in the box is set in it (rule 73:
  /// the request stays unless the chat ends), the thread is read into it, and
  /// the old bench is let go. The chat itself is untouched: it belongs to the
  /// session that is open, not to the bench.
  Future<void> _removeTheDocument() async {
    final old = _bench;
    if (old == null) return;
    final text = old.question;
    try {
      final session = await z.openSession(profileId: old.profileId, packId: old.packId);
      final bench = Workbench(session: session, profileId: old.profileId, packId: old.packId);
      if (text.trim().isNotEmpty) await bench.setQuestion(text);
      await bench.readTheChat();
      old.dispose();
      if (!mounted) {
        bench.dispose();
        return;
      }
      setState(() {
        _bench = bench;
        _trouble = null;
        _troubleReport = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _trouble = humanMessage(e));
    }
  }

  /// **A new chat starts from zero** — rule 71, the owner, 18 October 2026:
  /// «المفترض أن محادثة جديدة يجب أن تبدأ من الصفر».
  ///
  /// Three things end a chat — «End the chat» under the thread, the session
  /// deleted from its room, and a new session opened — and after any of them
  /// the whole surface is empty: no document in the first part, no request, no
  /// thread in the third. This is the one place that can do it, because the
  /// bench **is** the surface: the shell holds it, so the shell is what lets
  /// it go.
  ///
  /// **It reverses the lead's B5 ruling of 090**, where «End the chat» closed
  /// the panel and left the columns standing. The owner looked at that and
  /// said what he expected instead.
  ///
  /// **What is not touched: what was kept.** The session's own list keeps the
  /// documents it was given (54-ج/ز) and the turns it holds (rule 69); this
  /// empties a surface, it does not forget anything. The person who wants the
  /// same document brings it in again by its door (rule 63), or opens the kept
  /// copy from the room.
  void _fromZero() {
    _bench?.dispose();
    setState(() {
      _bench = null;
      _trouble = null;
      _troubleReport = null;
    });
    unawaited(_ground.refresh());
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
      acceptedTypeGroups: [
        XTypeGroup(
            label: sentences.fileKindDocuments,
            extensions: const ['pdf', 'docx', 'txt', 'md', 'csv']),
      ],
    );
    if (file == null || !mounted) return null;
    final kind = _kinds[file.name.split('.').last.toLowerCase()];
    if (kind == null) {
      setState(() {
        _trouble = sentences.onlyTheseKindsAreRead(theirOwnWord(file.name));
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
  /// The vault gate is the same one `_begin` holds, and here
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

  // **There is no way home, because there is nowhere else to be** — rule 70.
  // This emptied the bench and let the first screen come back; both the press
  // (the «Documents» arrow) and the key (Alt+Left) are deleted with it.

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
        // **The panel closes on a press anywhere outside it** — rule 75, the
        // owner, 18 October 2026.
        //
        // A catcher under the panel and over the work: a press on the panel
        // hits the panel, because the panel is above this in the `Stack`, and
        // a press anywhere else closes it.
        //
        // **`opaque`, and that is the whole of the trap the house knows.** «A
        // full-screen catcher swallows the next press» was written about a
        // barrier that let the press through to what was under it; this one
        // absorbs it, so the press that closes the panel does **not** also
        // reach the gear it may be sitting on (which would reopen it) nor any
        // act on the work behind. And it is gone with the panel, so the *next*
        // press lands on whatever it is aimed at — both halves measured in
        // `the_settings_cover_the_work_test.dart`.
        if (_settingsOpen)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey<String>('settings-outside'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _settingsOpen = false);
                unawaited(_ground.refresh());
              },
            ),
          ),
        if (_settingsOpen)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 480,
            child: SettingsScreen(
              ground: _ground,
              // Rule 74: `null` means the room the settings open on.
              room: _settingsRoom,
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
              // **«z-pdf» — the door back, from the room it lives in now**
              // (rule 70). The press travels here for the same reason
              // `onOpenKept` does: only the shell may open a file chooser,
              // and the reading stands over everything.
              onReadBack: () => unawaited(_readBack()),
              // **Rule 71's other two doors.** A session deleted from the room
              // and a new session opened both end a chat, and the surface then
              // starts from zero — the panel cannot do that itself, because
              // the bench it would have to let go of is the shell's.
              onFromZero: _fromZero,
              onClose: () {
                setState(() => _settingsOpen = false);
                _ground.refresh();
              },
            ),
          ),
        // **What went wrong before there was a screen** — 18 October 2026.
        //
        // Over everything, including the settings panel and the first-run
        // page, because the fault it carries is the one that lands a person on
        // that page: `main.dart` says where the files live before `runApp`, and
        // if the core will not take that folder there are no settings, so the
        // first run reads as undone. The work band inside `_body` is past that
        // early return and could never have shown this.
        //
        // A press takes it away, exactly as the other band's does — the one
        // thing about a band that matters.
        if (_atTheStart != null)
          Positioned(
            left: 0,
            right: 0,
            top: 18,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _atTheStart = null),
                    child: Trouble(_atTheStart!),
                  ),
                ),
              ),
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
    // **One screen, and it is this one** — rule 70, the owner: «نلغي الشاشة
    // الأولى… ليصبح التطبيق فقط ثلاثة أقسام في شاشة واحدة». There is no
    // branch here any more: the Workspace is what the app is, with or without
    // a document, and the two ways in stand at the top of it.
    //
    // What was lost with the first screen is worth naming, because none of it
    // was asked for and none of it is hidden: the four tallies (identities,
    // profiles, providers, pack), the home's own second conversation, and the
    // «+» menu's z-pdf entry, which is in Settings now (rule 70 again).
    return Stack(
      children: [
        WorkspaceScreen(
          bench: _bench,
          ground: _ground,
          onImport: () => _begin(typing: false),
          // **Rule 72**: what is typed is the request, not a document. It was
          // `_begin(typing: true, text: …)` — an import — and the box that
          // called it that way is deleted (72-أ).
          onAsk: (text) => unawaited(_askWithNoDocument(text)),
          onVault: () => setState(() => _vaultOpen = true),
          onFromZero: _fromZero,
          // Rule 73: drawn only with a document in, so the press and the
          // control appear and disappear together.
          // **«No document» is an empty one, not a null one**: a session
          // that imported nothing still answers with a `DocumentView` whose
          // text is empty, measured 18 October.
          onRemoveDocument: (_bench?.document?.text ?? '').isEmpty
              ? null
              : () => unawaited(_removeTheDocument()),
          onSettings: (room) => setState(() {
            _settingsRoom = room;
            _settingsOpen = !_settingsOpen;
          }),
          settingsOpen: _settingsOpen,
        ),
        // **The refusal stands over the work, where the press was** — and it
        // is this screen's because this screen holds the doors that refuse: a
        // file of a kind no reader here has, a document the core would not
        // open, and the report a person can send that is not the document.
        //
        // It was drawn on the first screen until rule 70. The band itself is
        // unchanged, and so is the one thing about it that matters: a press on
        // it takes it away.
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

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
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
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
    _ground.dispose();
    super.dispose();
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
  /// anything to be protected.
  Future<void> _begin({required bool typing, String? text}) async {
    XFile? file;
    DocumentKind? kind;
    String packId = _ground.config?.packId ?? 'de';
    final profileId = null as String?;

    if (!typing) {
      file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Documents', extensions: ['pdf', 'docx', 'txt', 'md', 'csv']),
        ],
      );
      if (file == null || !mounted) return;
      kind = _kinds[file.name.split('.').last.toLowerCase()];
      if (kind == null) {
        setState(() {
          _trouble = 'This build reads PDF, Word and text files. «${file!.name}» is none of those.';
          // Nothing was read, so the core has nothing to report about it.
          _troubleReport = null;
        });
        return;
      }
      final chosen = await showDialog<String>(
        context: context,
        builder: (_) => ChooseLanguage(ground: _ground, fileName: file!.name),
      );
      if (chosen == null || !mounted) return;
      packId = chosen;
    }

    try {
      final session = await z.openSession(profileId: profileId, packId: packId);
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
      // On import, at once, with no dialog.
      await bench.rescan();
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

  void _home() {
    final bench = _bench;
    setState(() => _bench = null);
    bench?.dispose();
    _ground.refresh();
  }

  @override
  Widget build(BuildContext context) {
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
            language: language,
            firstRunDone: true,
            sessionOnly: config.sessionOnly,
          ));
        },
      );
    }
    if (_settingsOpen) {
      return SettingsScreen(
        ground: _ground,
        onClose: () {
          setState(() => _settingsOpen = false);
          _ground.refresh();
        },
      );
    }
    // Before the Workspace, not after it: the vault has to be reachable **from
    // a document**, because that is where «Always» is pressed. Closing it puts
    // the document back exactly as it was — the bench is untouched by any of it.
    if (_vaultOpen) {
      return VaultScreen(
        ground: _ground,
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
      );
    }
    return Stack(
      children: [
        HomeScreen(
          ground: _ground,
          version: coreVersion(),
          onImport: () => _begin(typing: false),
          onType: (text) => _begin(typing: true, text: text),
          onVault: () => setState(() => _vaultOpen = true),
          onSettings: () => setState(() => _settingsOpen = true),
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
                          : () => Clipboard.setData(ClipboardData(text: _troubleReport!)),
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

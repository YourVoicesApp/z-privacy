// The shell: which screen is on, and the one place that decides it.
//
// It lives apart from `main.dart` so that the decision can be tested. That is
// not a theoretical tidiness — the first version of this code never showed the
// first-run page at all, because the settings arrive after the first frame and
// nothing asked the question again. A screen can be tested in isolation; the
// choice *between* screens can only be tested if something can build it.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/new_session.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

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
  const ZShell({super.key, required this.dataDir, this.ground});

  /// Where the vault lives. Passed in rather than found here, so a test can
  /// point the whole shell at a folder of its own.
  final String dataDir;

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
  bool _vaultOpen = false;
  bool _settingsOpen = false;
  /// Passed for this run. The lasting answer is in the settings, which live in
  /// the vault — so on a device with no vault this page comes back next time,
  /// and that is the truth rather than a bug: nothing was written down.
  bool _firstRunPassed = false;

  @override
  void initState() {
    super.initState();
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
    try {
      await z.setDataDir(dir: widget.dataDir);
    } on ApiError catch (e) {
      _trouble = e.toString();
    }
    await _ground.refresh();
  }

  @override
  void dispose() {
    _ground.removeListener(_groundChanged);
    _bench?.dispose();
    _ground.dispose();
    super.dispose();
  }

  /// Ask for the ground, then open the session. In both paths the scan runs
  /// immediately after the text is in — nobody has to press anything to be
  /// protected, which is the behaviour board's rule for import.
  Future<void> _begin({required bool typing}) async {
    final wish = await showDialog<SessionWish>(
      context: context,
      builder: (_) => NewSessionSheet(ground: _ground, typing: typing),
    );
    if (wish == null || !mounted) return;

    XFile? file;
    DocumentKind? kind;
    if (!typing) {
      file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Documents', extensions: ['pdf', 'docx', 'txt', 'md', 'csv']),
        ],
      );
      if (file == null || !mounted) return;
      kind = _kinds[file.name.split('.').last.toLowerCase()];
      if (kind == null) {
        setState(() => _trouble = 'This build reads PDF, Word and text files. «${file!.name}» is none of those.');
        return;
      }
    }

    try {
      final session = await z.openSession(profileId: wish.profileId, packId: wish.packId);
      final bench = Workbench(session: session, profileId: wish.profileId, packId: wish.packId);
      if (typing) {
        await z.importText(session: session, text: wish.text!);
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
      });
    } on ApiError catch (e) {
      // A refusal is news, not a failure: «a scanned PDF with no text layer is
      // refused with the reason, not silently imported empty».
      setState(() => _trouble = e.toString());
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
        onStart: (language) async {
          setState(() => _firstRunPassed = true);
          await _ground.saveConfig(Settings(
            scanOnImport: config.scanOnImport,
            revealSeconds: config.revealSeconds,
            autoLockMinutes: config.autoLockMinutes,
            // The language picks the pack, which is the part with teeth today.
            packId: language == 'de' ? 'de' : config.packId,
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
    final bench = _bench;
    if (bench != null) {
      return WorkspaceScreen(bench: bench, ground: _ground, onHome: _home);
    }
    if (_vaultOpen) {
      return VaultScreen(
        ground: _ground,
        onClose: () {
          setState(() => _vaultOpen = false);
          _ground.refresh();
        },
      );
    }
    return Stack(
      children: [
        HomeScreen(
          ground: _ground,
          version: coreVersion(),
          onImport: () => _begin(typing: false),
          onType: () => _begin(typing: true),
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
                    onTap: () => setState(() => _trouble = null),
                    child: Trouble(_trouble!),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

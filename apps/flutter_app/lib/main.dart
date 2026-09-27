// Z Privacy — the UI.
//
// This layer sees and shows. It holds no secret, builds no outgoing text and
// knows nothing about the network: gate G5 forbids a network package in this
// package and a socket API anywhere in `lib/`, and every fact on screen comes
// from z_core.
//
// The whole app is two places — Home and the Workspace — because the boards make
// the Workspace the centre of everything and everything else a room off it.
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/new_session.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

Future<void> main() async {
  await RustLib.init();
  // One line on stdout, so a headless build can prove the bridge is live
  // without anyone having to look at a window.
  debugPrint('bridge ok — ${coreVersion()}');
  runApp(const ZPrivacyApp());
}

class ZPrivacyApp extends StatelessWidget {
  const ZPrivacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Z Privacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Zc.paper,
        colorScheme: ColorScheme.fromSeed(seedColor: Zc.clay, surface: Zc.paper),
        useMaterial3: true,
      ),
      home: const _Shell(),
    );
  }
}

/// The three kinds a build reads today. Kept here because the core decides what
/// it can read and the UI only names the extensions that map onto it.
const _kinds = <String, DocumentKind>{
  'txt': DocumentKind.txt,
  'md': DocumentKind.txt,
  'csv': DocumentKind.txt,
  'docx': DocumentKind.docx,
  'pdf': DocumentKind.pdf,
};

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  final _ground = Ground();
  Workbench? _bench;
  String? _trouble;
  bool _vaultOpen = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // The vault lives beside the app's own data, and the core is told once where.
    // It is the only file this program writes (gate G15).
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    try {
      await z.setDataDir(dir: '$home/.local/share/zprivacy');
    } on ApiError catch (e) {
      _trouble = e.toString();
    }
    await _ground.refresh();
  }

  @override
  void dispose() {
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

// Z Privacy — the UI.
//
// This layer sees and shows. It holds no secret, builds no outgoing text and
// knows nothing about the network: gate G5 forbids a network package in this
// package and a socket API anywhere in `lib/`, and every fact on screen comes
// from z_core.
//
// This file does three things and stops: start the bridge, set the colours, and
// say where the vault lives. Which screen is on is `ZShell`'s to decide, in a
// file of its own, so that the decision can be tested.
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';

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
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    return MaterialApp(
      title: 'Z Privacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Zc.paper,
        colorScheme: ColorScheme.fromSeed(seedColor: Zc.clay, surface: Zc.paper),
        useMaterial3: true,
      ),
      // The vault is the only file this program writes, and this is where it goes.
      home: ZShell(dataDir: '$home/.local/share/zprivacy'),
    );
  }
}

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

/// The one theme, named so that a test can measure the same one the window is
/// built with. A theme written inline is a theme no test can see.
ThemeData zTheme() => ThemeData(
      scaffoldBackgroundColor: Zc.paper,
      colorScheme: ColorScheme.fromSeed(seedColor: Zc.clay, surface: Zc.paper),
      useMaterial3: true,
      // Selecting is the one act a person performs on the document itself, and
      // it was invisible. Not missing — camouflaged: with no selection theme,
      // Material takes the scheme's primary, and the seed of this scheme is
      // `Zc.clay`, so the highlight was a warm brown at 0.40 over warm paper.
      // Measured over `Zc.paper`: clay at 0.40 gives a contrast of 1.75 and a
      // colour distance of 109; `Zc.river` at 0.40 gives 1.88 and 111, so it
      // loses nothing by either measure and is a blue nobody mistakes for the
      // page. Ink on it reads at 8.57:1.
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: Zc.river.withValues(alpha: 0.40),
        cursorColor: Zc.river,
        selectionHandleColor: Zc.river,
      ),
    );

class ZPrivacyApp extends StatelessWidget {
  const ZPrivacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Z Privacy',
      debugShowCheckedModeBanner: false,
      theme: zTheme(),
      // The vault is the only file this program writes. Where it goes is the
      // core's answer, not this file's guess — see `z_core::default_data_dir`.
      home: const ZShell(),
    );
  }
}

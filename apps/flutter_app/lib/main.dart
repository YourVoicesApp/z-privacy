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
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/l10n/app_localizations.dart';
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

/// **The root, and the one place a locale is applied** — 092.
///
/// It holds the `Ground` so that it can read the language the person chose
/// (`settings.zcfg`'s `ui_language`, which reaches the glass as
/// `Settings.language`) and put it on the `MaterialApp` above every screen.
/// The shell used to make its own; it is given this one, so there is one
/// reader of the settings and no second opinion about which language is on.
///
/// **Not the operating system's locale**, by the owner's own design: the
/// language is a choice he makes on the first screen and can change in the
/// Language room, and a machine in another country does not change what his
/// screens say. `MaterialApp.locale` is set, so Flutter never falls back to
/// the platform.
class ZPrivacyApp extends StatefulWidget {
  const ZPrivacyApp({super.key});

  @override
  State<ZPrivacyApp> createState() => _ZPrivacyAppState();
}

class _ZPrivacyAppState extends State<ZPrivacyApp> {
  final Ground _ground = Ground();

  @override
  void initState() {
    super.initState();
    _ground.addListener(_languageMayHaveChanged);
    unawaited(_ground.refresh());
  }

  @override
  void dispose() {
    _ground.removeListener(_languageMayHaveChanged);
    _ground.dispose();
    super.dispose();
  }

  /// **A change in the Language room applies without a restart** — 092's third
  /// step. The room writes the setting, the ground refreshes, and this rebuilds
  /// the application with the new locale; nothing else has to know.
  void _languageMayHaveChanged() {
    final now = theLocaleOf(_ground.config?.language ?? 'en');
    if (now != _locale) setState(() => _locale = now);
  }

  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    // **Said before the subtree is built**, which is why it is here and not in
    // an `initState`: the holder in `core/sentences.dart` is what every
    // sentence in the house reads, and it must be the locale this build is
    // about. See that file for why the sentences are not reached by context.
    theSentencesAreNow(_locale);
    return MaterialApp(
      title: 'Z Privacy',
      debugShowCheckedModeBanner: false,
      theme: zTheme(),
      // **The language is the person's, not the machine's** — 092.
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Left to right, always: Arabic is stopped (rule 56-أ's sibling), and
      // every language this list carries is written left to right.
      home: ZShell(ground: _ground),
    );
  }
}

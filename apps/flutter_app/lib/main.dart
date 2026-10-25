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
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

Future<void> main() async {
  await RustLib.init();
  // One line on stdout, so a headless build can prove the bridge is live
  // without anyone having to look at a window.
  debugPrint('bridge ok — ${coreVersion()}');
  // **Where this machine's files are, said here, before any screen** — and
  // this is the third of the three things the head of this file says it does.
  //
  // It was said by the shell until 18 October, inside `_start()`, which the
  // shell runs only when it made its own `Ground`: `if (widget.ground == null)
  // _start()`. That condition is a **test** door — a future created in
  // `testWidgets`' zone never completes, so a shell that calls into Rust from
  // `initState` can never finish starting in a test — and 092 made the root
  // hold the `Ground` so it could read the person's language from it. The two
  // met: the shipped app passed a `Ground`, the condition read «a test gave me
  // this», and `set_data_dir` was never called in the product at all. The core
  // then has no folder, `VaultState` answers `Absent` for «there is no folder»
  // exactly as it does for «there is no vault», and the owner was shown the
  // first-run page over a vault of 7938 bytes that nothing had read. Nothing
  // was written, which is the one mercy: with no folder the vault has no path
  // and `create` writes no byte.
  //
  // So it is said **once, before `runApp`**, where no screen's parameters can
  // decide it and no test door is in front of it. The shell's own `_start()`
  // stays exactly as it is, for the tests that hand it a folder of their own.
  String? folderTrouble;
  try {
    // The core answers where, as it has since `d52df12`: this file asks the
    // question and never guesses, because `HOME` is the wrong answer on
    // Windows and a temp folder is the wrong answer everywhere.
    await z.setDataDir(dir: await z.defaultDataDir());
  } on ApiError catch (e) {
    // **And a failure reaches the glass.** The sentence used to live in the
    // shell's `_trouble`, and losing it would be the same fault one layer
    // along: a person whose folder cannot be used must read why, not meet a
    // product that behaves as though they had never run it.
    folderTrouble = humanMessage(e);
  }
  runApp(ZPrivacyApp(folderTrouble: folderTrouble));
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
  const ZPrivacyApp({super.key, this.folderTrouble});

  /// What went wrong saying where the files are, if anything did. Carried
  /// through to the shell, which is the one screen that can say it.
  final String? folderTrouble;

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
      // **And the direction comes with the locale, since 25 October 2026** —
      // papers 115 and 116, the owner's Arabic. This said «left to right,
      // always: Arabic is stopped», which was true while the pack sat in the
      // core unoffered; it is not true now. `GlobalWidgetsLocalizations` is in
      // the delegates above, so `MaterialApp` wraps the whole application in a
      // `Directionality` the locale decides, and `ar` mirrors every screen.
      // Nothing here has to say right or left: what 116 had to do was find the
      // places that had said it already.
      home: ZShell(ground: _ground, troubleAtTheStart: widget.folderTrouble),
    );
  }
}

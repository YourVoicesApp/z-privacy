// The one theme — moved out of `main.dart` by paper 122, unchanged, so that the
// desktop window and the web trial are built with the same one.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';

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

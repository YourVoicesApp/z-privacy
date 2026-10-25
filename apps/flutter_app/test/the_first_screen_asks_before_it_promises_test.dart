// 117 · **The first screen asks first, and promises once** — items 6 and 2,
// the owner's look at the Arabic screens on 25 October 2026.
//
// This page drew one promise block **per offered language** before a choice,
// each under its own name. With two languages that was the page's whole
// argument: a person reads what the product does not do, in their own
// language, before choosing anything. Arabic made four, and four blocks is
// about 1 500 px — so a person on a 1000-tall window scrolled past three
// languages they do not read to reach the one they do, on the first screen
// they ever see.
//
// The shape now: the names first, in one row, and under them **one** block —
// the language that was pressed. Nothing is pre-selected, which is P2-6 and
// still this page's law, so before a choice there is no block at all and the
// page says, in every language on offer, that a language must be chosen.
//
// ## What is measured here
//
//   1. before a choice: every name is on the glass, no promise is;
//   2. after a choice: that language's promise is on the glass and no other
//      language's is;
//   3. **at 1000 px tall, with no scrolling**: the row and the whole block
//      stand inside the window. This is the number the paper asks for and the
//      one a comment cannot keep;
//   4. a language is named the same way here as the core names it — «Deutsch
//      (DE)», not «Deutsch» here and «German (DE)» there (item 2).
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/language_list.dart' show offeredLanguages;
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// The languages this page offers: the ones whose own sentences are written.
List<String> get _offered => offeredLanguages.where(theListIsWrittenIn).toList();

Future<void> _settle(WidgetTester tester, {int rounds = 3}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  }
  await tester.pumpAndSettle();
}

Future<Ground> _ready(WidgetTester tester, String name) async {
  final ground = Ground();
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-first-$name-$pid');
    if (own.existsSync()) own.deleteSync(recursive: true);
    own.createSync(recursive: true);
    addTearDown(() {
      try {
        if (own.existsSync()) own.deleteSync(recursive: true);
      } on FileSystemException {
        // A folder the core still holds is not a finding about a screen.
      }
    });
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await ground.refresh();
  });
  return ground;
}

Widget _page(Ground ground) => MaterialApp(
      home: FirstRunScreen(ground: ground, onStart: (_, {required wantsVault}) {}),
    );

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // Before a choice: every name, and not one promise. The control that makes
  // this a measurement is the second half — the page used to carry all four.
  testWidgets('the names are the question, and nothing is promised yet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_page(await _ready(tester, 'ask')));
    await _settle(tester);

    expect(_offered.length, greaterThanOrEqualTo(4),
        reason: 'fewer than four languages are offered, so this page is not the '
            'one paper 117 measured');
    for (final code in _offered) {
      expect(find.text(aLanguageInItsOwnWords(code)), findsOneWidget,
          reason: 'the name «${aLanguageInItsOwnWords(code)}» is not on the page');
      expect(find.text(lookupAppLocalizations(Locale(code)).noAccount), findsNothing,
          reason: 'the promise in «$code» stands before anybody chose a language');
    }
    // And the page says what it is waiting for, in every language it offers —
    // one line each, so that each can be read the way its own language is.
    for (final code in _offered) {
      expect(find.text(lookupAppLocalizations(Locale(code)).chooseALanguage),
          findsOneWidget,
          reason: 'the page does not ask for a language in «$code»');
    }
  });

  // ------------------------------------------------------------------ guard 2
  //
  // After a choice: one promise, and it is theirs. Each offered language is
  // pressed in turn, because «the chosen one» is the only block there is and a
  // page that drew the first one whatever was pressed would pass a one-language
  // check.
  testWidgets('choosing a language swaps the one promise under it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_page(await _ready(tester, 'swap')));
    await _settle(tester);

    for (final code in _offered) {
      await tester.tap(find.text(aLanguageInItsOwnWords(code)));
      await _settle(tester, rounds: 1);
      final theirs = lookupAppLocalizations(Locale(code));
      expect(find.text(theirs.noAccount), findsOneWidget,
          reason: 'choosing «$code» did not put its own promise on the page');
      expect(find.text(theirs.start), findsOneWidget,
          reason: 'choosing «$code» did not offer Start in that language');
      for (final other in _offered.where((c) => c != code)) {
        final notTheirs = lookupAppLocalizations(Locale(other)).noAccount;
        if (notTheirs == theirs.noAccount) continue; // two lists, one sentence
        expect(find.text(notTheirs), findsNothing,
            reason: '«$other» is still promising while «$code» is chosen');
      }
    }
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The number the paper asks for.** At 1000 px tall and after a choice, the
  // language row and the whole promise stand inside the window — measured by
  // where they are painted, not by whether a widget exists in the tree.
  testWidgets('at 1000 px the row and the whole promise are on the glass', (tester) async {
    const height = 1000.0;
    await tester.binding.setSurfaceSize(const Size(1100, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_page(await _ready(tester, 'fold')));
    await _settle(tester);

    for (final code in _offered) {
      await tester.tap(find.text(aLanguageInItsOwnWords(code)));
      await _settle(tester, rounds: 1);
      final theirs = lookupAppLocalizations(Locale(code));
      // The row's own name is the top of what must be visible; the last line
      // of the promise is the bottom of it.
      final name = tester.getRect(find.text(aLanguageInItsOwnWords(code)));
      final last = tester.getRect(find.text(theirs.onlyTheProtectedVersionIsSent));
      expect(name.top, greaterThanOrEqualTo(0),
          reason: 'the names are above the top of the window in «$code»');
      expect(last.bottom, lessThanOrEqualTo(height),
          reason: 'the promise in «$code» ends ${last.bottom.toStringAsFixed(0)} px '
              'down a ${height.toStringAsFixed(0)} px window, so a person scrolls '
              'to read what this page exists to say');
    }
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **One spelling for a language, on both screens that offer one** — item 2.
  // The core's row is what Settings and the session room draw; this page
  // composes its own, because it runs before there is a setting to read. The
  // two are held equal here, so «Deutsch (DE)» cannot become «Deutsch» on one
  // screen and «German (DE)» on the other again.
  testWidgets('a language is named the same here as the core names it', (tester) async {
    final ground = await _ready(tester, 'named');
    final rows = {for (final p in ground.packs) p.id: p.label};
    expect(rows.length, greaterThanOrEqualTo(4), reason: 'the core sent no rows');
    for (final code in _offered) {
      expect(rows[code], isNotNull,
          reason: 'the first screen offers «$code» and the core has no row for it');
      expect(aLanguageInItsOwnWords(code), rows[code],
          reason: 'the first screen says «${aLanguageInItsOwnWords(code)}» and the '
              'core says «${rows[code]}»');
    }
  });
}

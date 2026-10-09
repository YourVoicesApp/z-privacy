// 041-G · the home is the composer, and the language is asked where it matters.
//
// The owner, 6 October: «on entering the first screen we need to choose the
// language, then choose to import a file or write directly. We make the writing
// screen the main screen, adding a file is a + as in a chat, and the language
// choice appears after pressing to add a file.» And: «we make a list of
// languages, and a line separates the supported languages from the unsupported
// ones».
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für den Tresor';
const _text = 'Kunde: Nordstern Consulting GmbH, Ansprechpartner Herr Thomas Müller.';

Future<Ground> _fresh(WidgetTester tester, String name) async {
  final ground = Ground();
  await tester.runAsync(() async {
    await z.vaultLock();
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-home-$name-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    await z.setDataDir(dir: dir.path);
    await ground.refresh();
  });
  return ground;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('the home is a box ready to be written in, and asks no language first', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1000));
    final ground = await _fresh(tester, 'composer');
    String? opened;

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        ground: ground,
        version: 'z_core 0.1.0',
        onImport: () {},
        onType: (text) => opened = text,
        onAsk: (_) async {},
        onVault: () {},
        onSettings: () {},
      ),
    ));
    await settle(tester);

    final box = find.byKey(HomeScreen.composer);
    expect(box, findsOneWidget, reason: 'the home is not a box to write in');
    // The focus is already there: a person who opened this app to paste can paste.
    expect(
      tester.widget<TextField>(box).focusNode?.hasFocus ?? tester.binding.focusManager.primaryFocus != null,
      isTrue,
      reason: 'the box does not have the focus',
    );
    // And nothing asks a language before a word is written.
    expect(find.byType(ChooseLanguage), findsNothing);
    expect(find.text('Which language is this document?'), findsNothing);
    // The file is a «+», as a chat offers one.
    expect(find.byTooltip('Add a document — PDF, Word or text'), findsOneWidget);

    await tester.enterText(box, _text);
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Open and scan'));
    await settle(tester, rounds: 1);
    expect(opened, _text, reason: 'what was written did not open');
  });

  testWidgets('pasted text opens a session with the pack the settings hold', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = await _fresh(tester, 'paste');
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-home-paste-$pid');

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);

    // Past the first run — and through the vault, which since 041-N is the
    // way in rather than an offer. The passphrase goes in through the core:
    // a widget that awaits it does not resume under `testWidgets`, so no test
    // in this app presses «Create the vault» itself.
    await tester.tap(find.text('English'));
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await tester.tap(find.text('Create a vault'));
    await settle(tester);
    await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: _pass));
    await settle(tester);
    await tester.tap(find.text('Back'));
    // The way back runs through the core: close, refresh, and a frame for the
    // shell to notice. Measured at five rounds; eight is room to breathe.
    await settle(tester, rounds: 8);

    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.enterText(find.byKey(HomeScreen.composer), _text);
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Open and scan'));
    await settle(tester, rounds: 8);

    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the text did not open a session');
    // No question was asked on the way.
    expect(find.byType(ChooseLanguage), findsNothing);
  });

  testWidgets('the language list has a line, and every language under it can be chosen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    final ground = await _fresh(tester, 'languages');
    String? chosen;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LanguageChoices(
          ground: ground,
          chosen: ground.packs.first.id,
          onChoose: (id) => chosen = id,
        ),
      ),
    ));
    await settle(tester, rounds: 1);

    // Above the line: what this build has rules for, named by the core.
    final withRules = ground.languages.where((l) => l.hasRules).toList();
    final rest = ground.languages.where((l) => !l.hasRules).toList();
    expect(withRules, isNotEmpty);
    expect(rest, isNotEmpty, reason: 'the core knows only the languages it has rules for');
    for (final language in withRules) {
      expect(find.text(language.label), findsOneWidget, reason: '«${language.label}» is missing');
    }
    // The line itself, and what it is for.
    expect(find.byKey(LanguageChoices.divider), findsOneWidget, reason: 'there is no line');
    expect(find.textContaining('General rules only'), findsOneWidget,
        reason: 'the line does not say what is under it');

    // A language with rules answers, as it always did.
    await tester.tap(find.text(withRules.last.label));
    await settle(tester, rounds: 1);
    expect(chosen, withRules.last.id);

    // 041-Q — and so does every language under the line. The owner could not
    // pick Arabic on a build whose vault already held an Arabic list.
    final arabic = rest.firstWhere((l) => l.id == 'ar');
    expect(arabic.label, 'العربية', reason: 'Arabic is not named in Arabic');
    await tester.scrollUntilVisible(find.text(arabic.label), 60,
        scrollable: find.descendant(
            of: find.byKey(LanguageChoices.scroller), matching: find.byType(Scrollable)));
    await tester.tap(find.text(arabic.label));
    await settle(tester, rounds: 1);
    expect(chosen, 'ar', reason: 'a language with no pack could not be chosen');
  });
}

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

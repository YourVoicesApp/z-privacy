// 041-G · the home is the composer, and the language is asked where it matters.
//
// **Rule 57b, 16 October 2026** — the owner, after making a session he was
// never asked about: a session born of its first text asks its language once,
// before the first reading, because the scanner needs it before it reads. Rule
// 34's «opening a file does not ask» stands everywhere else, and the test
// below that measured «no question at this door» is reversed here on purpose:
// the question is the rule now, and what it may not be is a second one.
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
        onReadBack: () {},
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
    // And nothing asks a language, before a word is written or after — 080
    // took the question out of the file door altogether, so there is no class
    // left to look for: the sentence is the thing that must not appear.
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
    await settle(tester, rounds: 4);

    // **Rule 57b: the one question.** This text is the first thing in a session
    // that does not exist yet, so its language is asked here and nowhere else —
    // and nothing is read until it is answered.
    expect(
      find.text(TheLanguageOfANewSession.title),
      findsOneWidget,
      reason: 'a session was about to be born in a language nobody chose',
    );
    expect(find.byType(WorkspaceScreen), findsNothing,
        reason: 'the text was read before the person said what language it is in');
    // The old question — about the *document* — is not back: 080 took that one
    // out and this one is about the session that is being born.
    expect(find.text('Which language is this document?'), findsNothing);

    await tester.tap(find.byKey(TheLanguageOfANewSession.keyFor('de')));
    await settle(tester, rounds: 30);
    expect(find.text(TheLanguageOfANewSession.title), findsNothing,
        reason: 'the question was asked and the answer did not close it');

    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the text did not open a session');
    // **And rule 57c**: the session is born with that language, and the next
    // text in it is read with the same one without asking again.
    expect(ground.openSessionRow?.packId, 'de',
        reason: 'the session kept another language than the one that was chosen');
    expect(packForTheNextText(ground), 'de');
    expect(ground.aSessionWouldBeBorn, isFalse,
        reason: 'the session was not born of its first text');
  });

  testWidgets('rule 57-د — a session from before 080 is asked once, and «Not now» reads nothing',
      (tester) async {
    // The owner, 17 October: an old session has no language, so it asks —
    // once, before the first reading in it — and it never takes the
    // application's silently. This is the last trace of 080 that was still
    // falling back: `packForTheNextText` answered for such a session with the
    // app's language, which is how a German session came to be read with an
    // English eye and nobody was asked.
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = await _fresh(tester, 'old-session');
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-home-old-$pid');

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);
    // The first run and the vault — the same recipe as the test above, and the
    // language chosen here is **English**, so that an answer of «de» later
    // cannot be the application's own.
    await tester.tap(find.text('English'));
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await tester.tap(find.text('Create a vault'));
    await settle(tester);
    await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: _pass));
    await settle(tester);
    await tester.tap(find.text('Back'));
    await settle(tester, rounds: 8);
    expect(find.byType(HomeScreen), findsOneWidget);

    // **A session as 080 left them**: begun with no bench, so the core wrote
    // «never asked» rather than a language.
    await tester.runAsync(() async {
      await z.conversationBegin(name: 'Alt', bench: null);
      await ground.refresh();
    });
    await settle(tester, rounds: 2);
    expect(ground.openSessionRow, isNotNull, reason: 'the old session is not the open one');
    expect(ground.openSessionRow!.packId, isNull,
        reason: 'a birth with no bench invented a language, so this guard has no old session');
    expect(appLanguage(ground), 'en',
        reason: 'the application does not speak English here, so «de» would prove nothing');
    expect(packForTheNextText(ground), isNull,
        reason: 'an old session still answers for a language nobody chose');

    // 1 · «Not now» — nothing is read, nothing is written, and the screen says
    // what did not happen.
    await tester.enterText(find.byKey(HomeScreen.composer), _text);
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Open and scan'));
    await settle(tester, rounds: 4);
    expect(find.text(TheLanguageOfANewSession.title), findsOneWidget,
        reason: 'the text was about to be read in a language nobody chose');
    await tester.tap(find.text('Not now'));
    await settle(tester, rounds: 8);
    expect(find.byType(WorkspaceScreen), findsNothing,
        reason: 'the text was read after «Not now»');
    expect(ground.openSessionRow!.packId, isNull, reason: '«Not now» wrote a language anyway');
    expect(find.textContaining('Nothing was read'), findsOneWidget,
        reason: 'a press did nothing and said nothing, which reads as a broken program');

    // 2 · and the question is still owed, because «Not now» answered nothing.
    await tester.enterText(find.byKey(HomeScreen.composer), _text);
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Open and scan'));
    await settle(tester, rounds: 4);
    expect(find.text(TheLanguageOfANewSession.title), findsOneWidget,
        reason: '«Not now» was taken for an answer');
    await tester.tap(find.byKey(TheLanguageOfANewSession.keyFor('de')));
    await settle(tester, rounds: 30);

    // 3 · **once**: the answer is written into that session, by its number, so
    // the next reading in it finds a language and asks nothing. And it is the
    // same session — a question about a language does not make a second one.
    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the text did not open');
    expect(ground.sessions, hasLength(1), reason: 'the answer made a second session');
    expect(ground.openSessionRow!.packId, 'de',
        reason: 'the answer was not written into the session, so it would be asked again');
    expect(packForTheNextText(ground), 'de',
        reason: 'the next text in this session would be asked about a second time');
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

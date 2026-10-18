// 041-G · the way in is a box at the top of the one screen, and the language is
// asked where it matters.
//
// **Rule 70, 17 October 2026 — and one box since rule 72-أ, 18 October.** This
// file was `the_home_is_the_composer`: the first screen's own box, which rule
// 70 moved to a strip at the top of the work. The owner's «نعم» of 18 October
// deleted that box too — «صندوق واحد للكتابة لا اثنان» — so what these guards
// are about now is the **one** box, which stands in the first part (rule 72),
// and the «+» that stayed at the top for files.
//
// What did not change is every claim they were written for: a box ready to be
// written in, with no language asked first; what is written opening a session
// with the pack the settings hold; and rule 57-د's one question for a session
// from before 080. Only the box they reach for moved.
// it — it moved to the top of the one screen, which is where every one of
// these guards now reaches for it.
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
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für den Tresor';
const _text = 'Kunde: Nordstern Consulting GmbH, Ansprechpartner Herr Thomas Müller.';

Future<Ground> _fresh(WidgetTester tester, String name) async {
  final ground = Ground();
  await tester.runAsync(() async {
    await z.vaultLock();
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-home-$name-$pid');
    removeWhenItLetsGo(dir);
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

  testWidgets('the one box is ready to be written in, and asks no language first', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1000));
    final ground = await _fresh(tester, 'composer');
    String? opened;

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(
        bench: null,
        ground: ground,
        onImport: () {},
        onAsk: (text) => opened = text,
        onVault: () {},
        onSettings: (_) {},
      ),
    ));
    await settle(tester);

    final box = find.byKey(WorkspaceScreen.composer);
    expect(box, findsOneWidget,
        reason: 'there is no box to write in on an empty surface (rule 72)');
    // **One box, not two** — rule 72-أ: the strip's own box is deleted, and its
    // sentence with it, so the sentence is the thing that must not appear.
    expect(find.text('Write or paste your text here…'), findsNothing,
        reason: 'the second box is back at the top of the screen');
    expect(find.text('Open and scan'), findsNothing,
        reason: 'the deleted box kept its press');
    // And nothing asks a language, before a word is written or after — 080
    // took the question out of the file door altogether, so there is no class
    // left to look for: the sentence is the thing that must not appear.
    expect(find.text('Which language is this document?'), findsNothing);
    // The file is a «+», as a chat offers one.
    expect(find.byTooltip('Add a document — PDF, Word or text'), findsOneWidget);

    await tester.enterText(box, _text);
    await settle(tester, rounds: 1);
    await tester.tap(find.byKey(const ValueKey<String>('workspace-question-attach')));
    await settle(tester, rounds: 1);
    expect(opened, _text, reason: 'what was written in the one box went nowhere');
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

    expect(find.byType(WorkspaceScreen), findsOneWidget,
        reason: 'the vault did not lead on to the one screen');
    await tester.enterText(find.byKey(WorkspaceScreen.composer), _text);
    await settle(tester, rounds: 1);
    await tester.tap(find.byKey(const ValueKey<String>('workspace-question-attach')));
    await settle(tester, rounds: 4);

    // **Rule 57b: the one question.** This text is the first thing in a session
    // that does not exist yet, so its language is asked here and nowhere else —
    // and nothing is read until it is answered.
    expect(
      find.text(TheLanguageOfANewSession.title),
      findsOneWidget,
      reason: 'a session was about to be born in a language nobody chose',
    );
    // **«Nothing was read» moved twice, and this is the second time.** Under
    // rule 70 it stopped being «no work screen» — the work screen is on the
    // glass from the first frame — and became «none of the text is drawn».
    // Rule 72-أ moves it again: what the person wrote is in the one box, in
    // their own hands, so of course it is on the glass. What says the core has
    // not read it is that there is no session for it to have been read into
    // and nothing of it stands in the column that says what would leave.
    expect(ground.openSession, isNull,
        reason: 'a session was born before the person said what language it is in');
    expect(find.text('What an AI would receive stands here beside the original, word for word, '
            'before anything is sent.'), findsOneWidget,
        reason: 'the Safe column holds something, so the text was read before the language was chosen');
    // The old question — about the *document* — is not back: 080 took that one
    // out and this one is about the session that is being born.
    expect(find.text('Which language is this document?'), findsNothing);

    await tester.tap(find.byKey(TheLanguageOfANewSession.keyFor('de')));
    await settle(tester, rounds: 30);
    expect(find.text(TheLanguageOfANewSession.title), findsNothing,
        reason: 'the question was asked and the answer did not close it');

    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the text did not open a session');
    // **And it was read in that language** — rule 57c, measured on the glass
    // rather than on the session's row, and that is rule 72's doing: what is
    // typed with no document is a **request**, so what it opens is a bench and
    // not a conversation. A conversation is born at the first exit (rule 55's
    // other half, 081), so there is no row to read a pack off yet, and what
    // says the text was read with the chosen language is that it was read at
    // all: the request stands in the Safe column, protected.
    expect(
      find.textContaining('Your request is in the Safe column'),
      findsOneWidget,
      reason: 'the text was not read into the column that says what would leave',
    );
    // And the question is not asked twice: the bench that now stands has the
    // language, so the next thing typed in the box goes through it.
    expect(find.text(TheLanguageOfANewSession.title), findsNothing,
        reason: 'the language was asked again for the text it had just been asked about');
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
    expect(find.byType(WorkspaceScreen), findsOneWidget);

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
    await tester.enterText(find.byKey(WorkspaceScreen.composer), _text);
    await settle(tester, rounds: 1);
    await tester.tap(find.byKey(const ValueKey<String>('workspace-question-attach')));
    await settle(tester, rounds: 4);
    expect(find.text(TheLanguageOfANewSession.title), findsOneWidget,
        reason: 'the text was about to be read in a language nobody chose');
    await tester.tap(find.text('Not now'));
    await settle(tester, rounds: 8);
    // **What says «nothing was read» after «Not now»** — and since rule 72-أ
    // it is not «nothing of the text is drawn»: the text is in the one box,
    // where the person wrote it, and it stays there because a refusal keeps
    // their writing. What the core did not do is read it, and that is read off
    // the column that would hold what leaves.
    expect(
      find.textContaining('Your request is in the Safe column'),
      findsNothing,
      reason: 'the text was read into what leaves after «Not now»',
    );
    expect(
      tester.widget<TextField>(find.byKey(WorkspaceScreen.composer)).controller!.text,
      contains('Ansprechpartner'),
      reason: 'the writing a person was asked about was taken out of their box',
    );
    expect(ground.openSessionRow!.packId, isNull, reason: '«Not now» wrote a language anyway');
    expect(find.textContaining('Nothing was read'), findsOneWidget,
        reason: 'a press did nothing and said nothing, which reads as a broken program');

    // 2 · and the question is still owed, because «Not now» answered nothing.
    await tester.enterText(find.byKey(WorkspaceScreen.composer), _text);
    await settle(tester, rounds: 1);
    await tester.tap(find.byKey(const ValueKey<String>('workspace-question-attach')));
    await settle(tester, rounds: 4);
    expect(find.text(TheLanguageOfANewSession.title), findsOneWidget,
        reason: '«Not now» was taken for an answer');
    await tester.tap(find.byKey(TheLanguageOfANewSession.keyFor('de')));
    await settle(tester, rounds: 30);

    // 3 · **once**: the answer is written into that session, by its number, so
    // the next reading in it finds a language and asks nothing. And it is the
    // same session — a question about a language does not make a second one.
    // Both columns draw it — the original and what would leave — so the reach
    // is «anywhere on the glass».
    expect(find.textContaining('Ansprechpartner'), findsWidgets, reason: 'the text did not open');
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

// Paper 123 part B — the trial's chat (rule 87 (أ), rules 65–68), the
// keep-the-codes line (87 (ج)) and «Start over» (87 (د)), on the fake of
// the core's settled doors. Fixture text and invented names only; the
// clipboard is over memory.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart' show sentences;
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/web/the_trial.dart';
import 'package:zprivacy/widgets/the_chat_turn.dart';

import 'the_fake_web_core.dart';
import 'the_trial_test.dart' show clipboard, fixtureFont, pumpTrial, restore;
import 'trial_steps.dart';

final en = lookupAppLocalizations(const Locale('en'));
final ar = lookupAppLocalizations(const Locale('ar'));

final _token = RegExp(r'__Z_[A-Z0-9_]+__');

/// The first turn: a letter written, copied, and the answer pasted back.
Future<String> firstTurn(
  WidgetTester tester, {
  String letter = 'Dear Anna Lindqvist, about the harbour.',
}) async {
  await write(tester, letter);
  await press(tester, TheTrial.copyProtected);
  final token = _token.firstMatch(clipboard.last)!.group(0)!;
  await tester.enterText(
    find.byKey(TheTrial.answer),
    'Thank you, $token. The harbour is ready.',
  );
  await tester.pump();
  await restore(tester);
  return token;
}

Future<void> ask(WidgetTester tester, String question) async {
  await tester.enterText(find.byKey(TheTrial.compose), question);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

String safeSide(WidgetTester tester) {
  final w = tester.widget(find.byKey(TheTrial.safe));
  return w is SelectableText ? w.data! : (w as Text).data!;
}

void main() {
  testWidgets('pinned first: after the first answer a box stands for the '
      'next question (red against 87 (أ) while the trial had none)', (
    tester,
  ) async {
    await pumpTrial(tester);
    await firstTurn(tester);
    expect(find.text(en.askSomethingElseAboutThis), findsOneWidget);
  });

  testWidgets('two turns: the second question carries the first turn '
      'protected, the same name is the same token, and the document holds '
      'both turns restored', (tester) async {
    Uint8List? pdf;
    final doors = FakeWebDoors();
    clipboard.clear();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      TrialApp(
        language: 'en',
        doors: () async => doors,
        font: fixtureFont,
        onThePdf: (bytes) => pdf = bytes,
      ),
    );
    await tester.pump();
    await tester.pump();

    final anna = await firstTurn(tester);
    // The thread: one turn, coded, with «Show the text».
    expect(find.byKey(TheTrial.chat), findsOneWidget);
    expect(find.byKey(ChatTurnView.showTheText(0)), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(TheTrial.original)).readOnly,
      isTrue,
    );

    await ask(tester, 'Will Anna Lindqvist sign it?');
    expect(doors.doorsAsked, contains('z_set_question'));
    final second = safeSide(tester);
    expect(second, isNot(contains('Anna Lindqvist')));
    expect(
      second,
      contains('Thank you, $anna.'),
      reason: 'the first turn travels, protected',
    );
    expect(
      second,
      contains('Will $anna sign it?'),
      reason: 'the same name is the same token',
    );

    await press(tester, TheTrial.copyProtected);
    expect(doors.doorsAsked, contains('z_question_to_take_out'));
    expect(clipboard.last, '${en.trialKeepTheCodes}\n\n$second');

    await tester.enterText(
      find.byKey(TheTrial.answer),
      'Yes, $anna will sign on Friday.',
    );
    await tester.pump();
    await restore(tester);

    // The thread from `z_turns`: two turns, each with its own «Show the text».
    expect(find.byKey(ChatTurnView.showTheText(1)), findsOneWidget);
    await press(tester, ChatTurnView.showTheText(1));
    expect(find.byKey(ChatTurnView.bubble(1)), findsOneWidget);

    // The document: the text as written, then each answer restored, the second
    // after «Question 2» and the question as the visitor wrote it.
    final doc = find.byKey(TheTrial.document);
    String docText() => tester
        .widgetList<RichText>(
          find.descendant(of: doc, matching: find.byType(RichText)),
        )
        .map((r) => r.text.toPlainText())
        .join('\n');
    expect(
      docText(),
      allOf(
        contains('Dear Anna Lindqvist, about the harbour.'),
        contains('Thank you, Anna Lindqvist. The harbour is ready.'),
        contains(en.trialQuestionNumber(2)),
        contains('Will Anna Lindqvist sign it?'),
        contains('Yes, Anna Lindqvist will sign on Friday.'),
      ),
    );
    expect(docText(), isNot(contains('__Z_')));
    for (var i = 0; i < 5 && pdf == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    expect(pdf, isNotNull, reason: 'the PDF follows the two turns');
    // The answer box is one box: it was emptied for the next answer.
    expect(
      tester.widget<TextField>(find.byKey(TheTrial.answer)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a follow-up holds no suggestion to answer: every value the '
      'question scan finds is protected at once, a value of the document is '
      'its own token (source vault), and the question copies', (tester) async {
    final doors = await pumpTrial(tester);
    final anna = await firstTurn(tester);
    await ask(tester, 'Did Björn and Anna Lindqvist agree?');
    final set = doors.asked.where((a) => a.$1 == 'z_set_question').last.$2;
    expect(set, {'session': 1, 'text': 'Did Björn and Anna Lindqvist agree?'});
    // No «Protect it / Leave it» in the compose box: nothing waits there.
    await tester.tap(find.byKey(TheTrial.compose));
    await tester.pump();
    expect(find.byKey(TheTrial.protectIt), findsNothing);
    final safe = safeSide(tester);
    expect(safe, isNot(contains('Björn')));
    expect(safe, isNot(contains('Anna Lindqvist')));
    expect(safe, contains('Did '), reason: 'the question leaves, protected');
    expect(safe, contains(anna), reason: 'the same name is the same token');
    await press(tester, TheTrial.copyProtected);
    expect(clipboard.last, '${en.trialKeepTheCodes}\n\n$safe');
  });

  for (final (lang, t) in [('en', en), ('ar', ar)]) {
    testWidgets('the copied text starts with the keep-the-codes line in the '
        'page\'s language ($lang), and the protected side never shows it', (
      tester,
    ) async {
      await pumpTrial(tester, language: lang);
      await write(
        tester,
        lang == 'ar' ? 'كتبت آمنة الحسيني رسالة.' : 'Dear Anna Lindqvist,',
      );
      final safe = safeSide(tester);
      await press(tester, TheTrial.copyProtected);
      expect(clipboard.last.split('\n').first, t.trialKeepTheCodes);
      expect(
        t.trialKeepTheCodes,
        isNot(matches(_token)),
        reason: 'no token in the line',
      );
      expect(safe, isNot(contains(t.trialKeepTheCodes)));
      expect(safeSide(tester), isNot(contains(t.trialKeepTheCodes)));
    });
  }

  group('«Start over»', () {
    testWidgets(
      'with a document on the page it asks; «Cancel» keeps everything',
      (tester) async {
        final doors = await pumpTrial(tester);
        await firstTurn(tester);
        await press(tester, TheTrial.startOver);
        await tester.pumpAndSettle();
        expect(find.text(en.trialStartOverQuestion), findsOneWidget);
        expect(find.text(en.trialErase), findsOneWidget);
        expect(find.text(sentences.cancel), findsOneWidget);
        expect(
          find.text(en.trialNotice),
          findsOneWidget,
          reason: 'the band stands behind the question',
        );
        await tester.tap(find.byKey(TheTrial.cancelStartOver));
        await tester.pumpAndSettle();
        expect(find.byKey(TheTrial.document), findsOneWidget);
        expect(find.byKey(TheTrial.chat), findsOneWidget);
        expect(
          original(tester).text,
          'Dear Anna Lindqvist, about the harbour.',
        );
        expect(doors.closed, isEmpty);
      },
    );

    testWidgets('«Erase» empties every field, closes the session, opens a new '
        'one with the same pack, empties Z\'s copy from the clipboard — and the '
        'old tokens no longer restore', (tester) async {
      final doors = await pumpTrial(tester);
      await tester.tap(find.byKey(TheTrial.pack));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Svenska (SV)').last);
      await tester.pumpAndSettle();
      final oldToken = await firstTurn(tester);
      final oldAnswer = 'Thank you, $oldToken.';
      clipboard.clear();
      await press(tester, TheTrial.startOver);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TheTrial.erase));
      await tester.pumpAndSettle();

      expect(clipboard, [''], reason: 'Z\'s copy was the last thing on it');
      expect(doors.closed, [2], reason: 'the Swedish session was closed');
      expect(doors.asked.where((a) => a.$1 == 'z_open').last.$2, {
        'pack': 'sv',
      });
      expect(original(tester).text, isEmpty);
      expect(
        tester.widget<TextField>(find.byKey(TheTrial.answer)).controller!.text,
        isEmpty,
      );
      expect(find.byKey(TheTrial.chat), findsNothing);
      expect(find.byKey(TheTrial.document), findsNothing);
      expect(find.text(en.trialNotice), findsOneWidget);

      // A new text gets new tokens, and the old answer comes back unplaced.
      await write(tester, 'Dear Anna Lindqvist,');
      await press(tester, TheTrial.copyProtected);
      final newToken = _token.firstMatch(clipboard.last)!.group(0)!;
      expect(newToken, isNot(oldToken));
      await tester.enterText(find.byKey(TheTrial.answer), oldAnswer);
      await tester.pump();
      await restore(tester);
      await press(tester, ChatTurnView.showTheText(0));
      // The core lists the old token as unplaced, and the turn's own strip
      // says so — the app's 046/U, drawn by the same turn widget.
      expect(find.byKey(ChatTurnView.unresolved), findsOneWidget);
      final bubble = tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byKey(ChatTurnView.bubble(0)),
              matching: find.byType(SelectableText),
            ),
          )
          .textSpan!
          .toPlainText();
      expect(
        bubble,
        contains(oldToken),
        reason: 'the old token stays unplaced: nothing restores it',
      );
      expect(bubble, isNot(contains('Anna Lindqvist')));
    });

    testWidgets('with no document it does not ask', (tester) async {
      final doors = await pumpTrial(tester);
      await write(tester, 'Dear Anna Lindqvist,');
      await press(tester, TheTrial.startOver);
      await tester.pumpAndSettle();
      expect(find.text(en.trialStartOverQuestion), findsNothing);
      expect(doors.closed, [1]);
      expect(original(tester).text, isEmpty);
    });
  });

  testWidgets('the notice band stands in every new state: the chat open, a '
      'second question waiting, and after «Start over»', (tester) async {
    await pumpTrial(tester, size: const Size(390, 844));
    void band(String state) =>
        expect(find.text(en.trialNotice), findsOneWidget, reason: state);
    await firstTurn(tester);
    band('the chat open');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -3000),
    );
    await tester.pump();
    await ask(tester, 'And Björn?');
    band('a second question waiting');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 3000),
    );
    await tester.pump();
    await press(tester, TheTrial.startOver);
    await tester.pumpAndSettle();
    band('the question asked');
    await tester.tap(find.byKey(TheTrial.erase));
    await tester.pumpAndSettle();
    band('after «Start over»');
  });
}

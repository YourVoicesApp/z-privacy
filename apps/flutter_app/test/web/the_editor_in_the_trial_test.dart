// Paper 124 part B, Z's side: Scribe's editor in the web trial (rule 88,
// 88 (ح)) — the button under the answer box, «Send to the editor» under each
// restored answer, Z's copy handed over (88 (د)), and «Start over» dropping
// the editor. On the fake of the core's doors; the page's acts are recorded
// by `the_page_none.dart` (the browser's own are measured in Chrome).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart' show sentences;
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/web/the_page.dart' as page;
import 'package:zprivacy/web/the_trial.dart';
import 'package:zprivacy/widgets/the_chat_turn.dart';

import 'the_chat_in_the_trial_test.dart' show ask, firstTurn;
import 'the_trial_test.dart' show clipboard, pumpTrial, restore;
import 'trial_steps.dart';

final en = lookupAppLocalizations(const Locale('en'));
final ar = lookupAppLocalizations(const Locale('ar'));
final sv = lookupAppLocalizations(const Locale('sv'));

/// The page's acts on the editor, in order.
List<(String, String, int)> editorActs() =>
    page.thePageWasAsked.where((a) => a.$1.startsWith('editor-')).toList();

String plain(WidgetTester tester, Key key) {
  final w = tester.widget(find.byKey(key));
  return w is RichText
      ? w.text.toPlainText()
      : (w as Text).textSpan?.toPlainText() ?? w.data!;
}

void main() {
  testWidgets('pinned first: under the answer box, the Scribe button and its '
      'sentence (red while the trial had none)', (tester) async {
    // The keys by their values, so the pin compiles against the trial
    // before the button: it was measured red there.
    const scribe = ValueKey<String>('trial-scribe');
    const sentence = ValueKey<String>('trial-scribe-sentence');
    await pumpTrial(tester);
    expect(find.byKey(scribe), findsOneWidget);
    expect(find.byKey(sentence), findsOneWidget);
    expect(
      plain(tester, sentence),
      'Scribe: a text editor for writing documents.',
    );
    final box = tester.getRect(find.byKey(TheTrial.answer));
    final button = tester.getRect(find.byKey(scribe));
    expect(button.top, greaterThanOrEqualTo(box.bottom), reason: 'under it');
  });

  testWidgets('pinned first (rule 88 (ط)): at 1440 px the press splits the '
      'screen — Z in the start third, its parts stacked — not an overlay '
      '(red while the editor lay over Z)', (tester) async {
    await pumpTrial(tester);
    expect(
      tester.getRect(find.byKey(TheTrial.answer)).right,
      greaterThan(1440 / 3),
      reason: 'before the press: Z at full width',
    );
    await press(tester, TheTrial.scribe);
    await tester.pumpAndSettle();
    final answer = tester.getRect(find.byKey(TheTrial.answer));
    expect(answer.right, lessThanOrEqualTo(1440 / 3), reason: 'Z\'s third');
    final original = tester.getRect(find.byKey(TheTrial.original));
    final safe = tester.getRect(find.byKey(TheTrial.safe));
    expect(safe.top, greaterThanOrEqualTo(original.bottom), reason: 'stacked');
    expect(original.width, closeTo(safe.width, 0.5), reason: 'same width');
  });

  testWidgets('«Scribe» is bold in the sentence, and the sentence is the '
      'lead\'s in Arabic and Swedish', (tester) async {
    await pumpTrial(tester);
    final rich = tester.widget<Text>(find.byKey(TheTrial.scribeSentence));
    final first = (rich.textSpan! as TextSpan).children!.first as TextSpan;
    expect(first.text, 'Scribe');
    expect(first.style!.fontWeight, FontWeight.w700);
    expect(ar.trialScribe, 'Scribe: محرر نصوص خاص لكتابة الوثائق.');
    expect(
      sv.trialScribe,
      'Scribe: en textredigerare för att skriva dokument.',
    );
    expect(en.trialSendToTheEditor, 'Send to the editor');
    expect(ar.trialSendToTheEditor, 'أرسل إلى المحرر');
    expect(sv.trialSendToTheEditor, 'Skicka till redigeraren');
  });

  testWidgets('the button opens the editor, empty', (tester) async {
    await pumpTrial(tester);
    await press(tester, TheTrial.scribe);
    expect(editorActs(), [
      ('editor-place', 'split', 0),
      ('editor-open', '', 0),
    ]);
  });

  testWidgets('rule 88 (ط), Arabic: Z\'s third is on the right, the editor '
      'on the left; the split is 1 : 2 at 1440 px', (tester) async {
    await pumpTrial(tester, language: 'ar');
    await press(tester, TheTrial.scribe);
    await tester.pumpAndSettle();
    expect(editorActs().first, ('editor-place', 'split', 1), reason: 'rtl');
    final third = tester.getRect(find.byKey(TheTrial.zThird));
    expect(third.width, 480);
    expect(third.right, 1440, reason: 'the start side in Arabic is the right');
    final answer = tester.getRect(find.byKey(TheTrial.answer));
    expect(answer.left, greaterThanOrEqualTo(960));
  });

  testWidgets('rule 88 (ط), English: Z\'s third is on the left', (
    tester,
  ) async {
    await pumpTrial(tester);
    await press(tester, TheTrial.scribe);
    await tester.pumpAndSettle();
    final third = tester.getRect(find.byKey(TheTrial.zThird));
    expect((third.left, third.width), (0.0, 480.0));
  });

  testWidgets('the editor\'s «Close» returns Z to its full width', (
    tester,
  ) async {
    await pumpTrial(tester);
    await press(tester, TheTrial.scribe);
    await tester.pumpAndSettle();
    expect(find.byKey(TheTrial.zThird), findsOneWidget);
    page.theEditorClosed!();
    await tester.pumpAndSettle();
    expect(find.byKey(TheTrial.zThird), findsNothing);
    expect(
      tester.getRect(find.byKey(TheTrial.answer)).right,
      greaterThan(1440 / 3),
    );
  });

  testWidgets('below ${TheTrial.splitFrom.toInt()} px (a phone) the editor '
      'opens over Z, and Z keeps its full width', (tester) async {
    await pumpTrial(tester, size: const Size(390, 844));
    await press(tester, TheTrial.scribe);
    await tester.pumpAndSettle();
    expect(editorActs().first, ('editor-place', 'over', 0));
    expect(find.byKey(TheTrial.zThird), findsNothing);
  });

  testWidgets('«Copy the answer to the editor»: beside «Add an answer», '
      'disabled before an answer, then it sends the latest restored answer '
      'and opens the editor beside Z', (tester) async {
    await pumpTrial(tester);
    final button = find.byKey(TheTrial.copyTheAnswerToTheEditor);
    expect(button, findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(button).onPressed,
      isNull,
      reason: 'no answer yet',
    );
    final add = tester.getRect(find.byKey(TheTrial.restore));
    expect(tester.getRect(button).top, lessThan(add.bottom), reason: 'beside');
    expect(en.trialCopyTheAnswerToTheEditor, 'Copy the answer to the editor');
    expect(ar.trialCopyTheAnswerToTheEditor, 'انسخ الجواب إلى المحرر');
    expect(sv.trialCopyTheAnswerToTheEditor, 'Kopiera svaret till redigeraren');

    await firstTurn(tester);
    await ask(tester, 'And the boats?');
    await press(tester, TheTrial.copyProtected);
    final token = RegExp(r'__Z_[A-Z0-9_]+__').firstMatch(clipboard.last)!;
    await tester.enterText(
      find.byKey(TheTrial.answer),
      'The boats wait for ${token.group(0)}.',
    );
    await tester.pump();
    await restore(tester);
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
    await press(tester, TheTrial.copyTheAnswerToTheEditor);
    await tester.pumpAndSettle();
    expect(
      editorActs().where((a) => a.$1 == 'editor-open').single.$2,
      'The boats wait for Anna Lindqvist.',
      reason: 'the latest, restored',
    );
    expect(find.byKey(TheTrial.zThird), findsOneWidget);
  });

  testWidgets('«Start over» returns Z to its full width', (tester) async {
    await pumpTrial(tester);
    await press(tester, TheTrial.scribe);
    await tester.pumpAndSettle();
    await press(tester, TheTrial.startOver);
    await tester.pumpAndSettle();
    expect(find.byKey(TheTrial.zThird), findsNothing);
  });

  testWidgets('«Send to the editor» under each restored answer: the answer '
      'with its real names, and the editor opens', (tester) async {
    await pumpTrial(tester);
    expect(find.byKey(TheTrial.sendToTheEditor(0)), findsNothing);
    await firstTurn(tester);
    await ask(tester, 'And the boats?');
    await press(tester, TheTrial.copyProtected);
    final token = RegExp(r'__Z_[A-Z0-9_]+__').firstMatch(clipboard.last)!;
    await tester.enterText(
      find.byKey(TheTrial.answer),
      'The boats wait for ${token.group(0)}.',
    );
    await tester.pump();
    await restore(tester);

    for (final i in [0, 1]) {
      expect(find.byKey(TheTrial.sendToTheEditor(i)), findsOneWidget);
    }
    await press(tester, TheTrial.sendToTheEditor(0));
    await press(tester, TheTrial.sendToTheEditor(1));
    final opened = editorActs().where((a) => a.$1 == 'editor-open').toList();
    expect(opened.map((a) => a.$2), [
      'Thank you, Anna Lindqvist. The harbour is ready.',
      'The boats wait for Anna Lindqvist.',
    ]);
    for (final a in opened) {
      expect(a.$2, isNot(contains('__Z_')), reason: 'restored, no token');
    }
  });

  testWidgets('the trial\'s Copy hands the same text to the editor, so a '
      'paste of it counts as AI (88 (د)); «Copy Protected» hands nothing', (
    tester,
  ) async {
    await pumpTrial(tester);
    await firstTurn(tester);
    expect(
      editorActs().where((a) => a.$1 == 'editor-z-copy'),
      isEmpty,
      reason: 'the protected copy is the visitor\'s question, not AI\'s',
    );
    await press(tester, TheTrial.copyDocument);
    final handed = editorActs().where((a) => a.$1 == 'editor-z-copy').toList();
    expect(handed.single.$2, clipboard.last);
  });

  testWidgets('the chat\'s «Copy Restored» hands the answer to the editor '
      'too, once the visitor says yes', (tester) async {
    await pumpTrial(tester);
    await firstTurn(tester);
    await press(tester, ChatTurnView.showTheText(0));
    final copy = find.descendant(
      of: find.byKey(ChatTurnView.bubble(0)),
      matching: find.text(sentences.copyRestored),
    );
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    // The question first (081); a cancel hands nothing.
    expect(editorActs(), isEmpty);
    await tester.tap(find.text(sentences.copyRestored).last);
    await tester.pumpAndSettle();
    expect(editorActs(), [
      (
        'editor-z-copy',
        'Thank you, Anna Lindqvist. The harbour is ready.',
        'Thank you, Anna Lindqvist. The harbour is ready.'.length,
      ),
    ]);
    expect(clipboard.last, editorActs().single.$2);
  });

  testWidgets('«Start over» drops the editor with everything else', (
    tester,
  ) async {
    await pumpTrial(tester);
    await press(tester, TheTrial.scribe);
    await press(tester, TheTrial.startOver);
    await tester.pumpAndSettle();
    expect(editorActs().last, ('editor-drop', '', 0));
  });

  testWidgets('right to left in Arabic: the sentence reads from the right', (
    tester,
  ) async {
    await pumpTrial(tester, language: 'ar', size: const Size(390, 844));
    expect(plain(tester, TheTrial.scribeSentence), ar.trialScribe);
    final sentence = find.byKey(TheTrial.scribeSentence);
    expect(Directionality.of(tester.element(sentence)), TextDirection.rtl);
    final logo = tester.getRect(find.byKey(TheTrial.scribeLogo));
    final words = tester.getRect(sentence);
    expect(logo.left, greaterThan(words.left), reason: 'the logo first');
  });
}

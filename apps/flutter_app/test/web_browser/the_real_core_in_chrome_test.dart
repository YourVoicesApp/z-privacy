// Paper 122 — **the whole flow against ed's real `z_web` module**, in Chrome,
// and then the browser's own storage read.
//
//     scripts/check_the_trial_in_a_browser.sh <the folder z_web.js is in>
//
// which serves the module on 127.0.0.1 and names it here by
// `--dart-define=Z_WEB_MODULE=…`. Without it this test is skipped: the module
// is built from the core (`scripts/build_web_core.sh`), never committed.
//
// The flow: an invented letter is written; the core suggests two companies;
// one is left in the clear and the other protected — both by the finding,
// through `z_answer_finding`; «Copy Protected» copies text holding no value the
// core protected; the model's answer is pasted with the tokens it was given;
// the document reads the real values, and so does **the PDF itself** — the
// bytes «Save to my device» offers, read back by `pdftotext`.
@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/web/the_trial.dart';
import 'package:zprivacy/web/the_web_doors.dart';

import '../web/trial_steps.dart';
import 'the_browser_keeps_nothing_test.dart' show nothing, whatTheBrowserKeeps;
import 'the_trial_server.dart';

const module = String.fromEnvironment('Z_WEB_MODULE');

const letter =
    'Dear Jonas,\n\nOur partners at Norrvik Logistics Ltd have read the draft, '
    'and Pellam Brothers Ltd will read it next week. Please write to '
    'maren.holt@example.com or call +44 20 7946 0958.\n\nKind regards,\nIlse Carrow';

/// The values the core protects in [letter], measured on ed's module
/// (`e50b4da`): never in what leaves, and back in the document and its PDF.
const protectedValues = [
  'Pellam Brothers Ltd',
  'maren.holt@example.com',
  '+44 20 7946 0958',
  'Ilse',
  'Carrow',
];

Future<void> realTime(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 150 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('write, leave one suggestion and protect the other, copy, paste '
      'the answer, read the real values in the document and its PDF; a second '
      'turn through the chat; start over — against the real module', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
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

    Uint8List? pdf;
    await tester.pumpWidget(
      TrialApp(
        language: 'en',
        doors: () => loadTheWebDoors(module: module),
        font: theFontFromTheServer,
        onThePdf: (bytes) => pdf = bytes,
      ),
    );
    await realTime(
      tester,
      () => find.byKey(TheTrial.original).evaluate().isNotEmpty,
    );
    expect(
      find.byKey(TheTrial.original),
      findsOneWidget,
      reason: 'the module loaded',
    );

    await write(tester, letter);
    // Two suggestions wait, and nothing can leave yet.
    expect(
      tester.widget<FilledButton>(find.byKey(TheTrial.copyProtected)).onPressed,
      isNull,
    );

    await caretAt(tester, letter.indexOf('Norrvik') + 2);
    await press(tester, TheTrial.leaveIt);
    await caretAt(tester, letter.indexOf('Pellam') + 2);
    await press(tester, TheTrial.protectIt);

    await press(tester, TheTrial.copyProtected);
    expect(copied.first, '', reason: 'emptied first');
    final out = copied.last;
    for (final v in protectedValues) {
      expect(
        out,
        isNot(contains(v)),
        reason: '«$v» was protected and may not leave',
      );
    }
    expect(
      out,
      contains('Norrvik Logistics Ltd'),
      reason: 'left in the clear, it leaves as written',
    );

    final tokens = RegExp(
      r'__Z_[A-Z0-9_]+__',
    ).allMatches(out).map((m) => m.group(0)!).toList();
    expect(tokens, isNotEmpty);
    await tester.enterText(
      find.byKey(TheTrial.answer),
      'Noted. I will write to ${tokens.join(' and ')} today.',
    );
    await tester.pump();
    await press(tester, TheTrial.restore);
    await realTime(tester, () => pdf != null);

    final answer = tester
        .widget<RichText>(
          find.descendant(
            of: find.byKey(TheTrial.document),
            matching: find.byWidgetPredicate(
              (w) => w is RichText && w.text.toPlainText().startsWith('Noted.'),
            ),
          ),
        )
        .text
        .toPlainText();
    for (final v in protectedValues) {
      expect(answer, contains(v), reason: '«$v» is back in the document');
    }
    expect(answer, isNot(contains('__Z_')));

    // **The PDF itself**, the bytes «Save to my device» offers, read back by
    // `pdftotext` on the run's server: the text as written, the answer with
    // every protected value back, and no token of ours.
    expect(pdf, isNotNull, reason: 'the PDF was built');
    final read = (await tester.runAsync(
      () => theTextOfThePdf(pdf!),
    ))!.replaceAll(RegExp(r'\s+'), ' ');
    expect(read, contains('Your text Dear Jonas,'));
    expect(read, contains('The answer, with the real names Noted.'));
    for (final v in protectedValues) {
      expect(
        RegExp(RegExp.escape(v)).allMatches(read).length,
        greaterThanOrEqualTo(2),
        reason: '«$v» stands in the text as written and in the answer',
      );
    }
    expect(read, isNot(contains('__Z_')));

    // **Paper 123: a second turn through the real chat doors.** The question
    // names Ilse Carrow again; the core gives her the same tokens, and the
    // copy carries the exchange before, protected, behind the line.
    pdf = null;
    await tester.ensureVisible(find.byKey(TheTrial.compose));
    await tester.enterText(
      find.byKey(TheTrial.compose),
      'Will Ilse Carrow confirm by Friday?',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await press(tester, TheTrial.copyProtected);
    final second = copied.last;
    expect(
      second.split('\n').first,
      'Give back every code that starts with __Z_ exactly as written, with all its underscores and no changes.',
    );
    for (final v in protectedValues) {
      expect(
        second,
        isNot(contains(v)),
        reason: '«$v» may not leave in the second turn either',
      );
    }
    final secondTokens = RegExp(
      r'__Z_[A-Z0-9_]+__',
    ).allMatches(second.split('\n').last).map((m) => m.group(0)!).toList();
    expect(secondTokens, hasLength(2), reason: 'Ilse and Carrow, as tokens');
    expect(
      tokens,
      containsAll(secondTokens),
      reason: 'the same name is the same token',
    );
    await tester.enterText(
      find.byKey(TheTrial.answer),
      'Yes, ${secondTokens.join(' ')} will confirm.',
    );
    await tester.pump();
    await press(tester, TheTrial.restore);
    await realTime(tester, () => pdf != null);
    expect(pdf, isNotNull, reason: 'the PDF of both turns was built');
    final both = (await tester.runAsync(
      () => theTextOfThePdf(pdf!),
    ))!.replaceAll(RegExp(r'\s+'), ' ');
    expect(both, contains('Question 2 Will Ilse Carrow confirm by Friday?'));
    expect(both, contains('Yes, Ilse Carrow will confirm.'));
    expect(both, isNot(contains('__Z_')));

    // **«Start over»**: asked, erased, the session closed.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 6000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TheTrial.startOver));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TheTrial.erase));
    await tester.pumpAndSettle();
    expect(find.byKey(TheTrial.document), findsNothing);
    expect(copied.last, '', reason: 'Z\'s copy emptied from the clipboard');

    expect(
      await tester.runAsync(whatTheBrowserKeeps),
      nothing,
      reason: 'nothing kept after two real turns and a start over',
    );
    // Skipped with no Z_WEB_MODULE or no server: run
    // scripts/check_the_trial_in_a_browser.sh with the module's folder.
  }, skip: module.isEmpty || theTrialServer.isEmpty);
}

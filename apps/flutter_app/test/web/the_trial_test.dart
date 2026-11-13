// Paper 122 part B — the web trial's screen, on ed's shape (a fake of it).
//
// The full flow on fixtures, the providers that need the app, the notice band
// on every state, Arabic right to left, the language of the address, and the
// web entry's imports. No storage is touched here; a browser test checks the
// browser's own after a full flow (`test_browser/`).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/web/the_page.dart' as page;
import 'package:zprivacy/web/the_trial.dart';
import 'package:zprivacy/web/the_web_core.dart';

import 'the_fake_web_core.dart';
import 'trial_steps.dart';

final en = lookupAppLocalizations(const Locale('en'));
final ar = lookupAppLocalizations(const Locale('ar'));

/// Everything the trial put on the clipboard, in order.
final List<String> clipboard = <String>[];

Future<ByteData> fixtureFont() async =>
    ByteData.sublistView(File('assets/fonts/DejaVuSans.ttf').readAsBytesSync());

Future<FakeWebDoors> pumpTrial(
  WidgetTester tester, {
  String language = 'en',
  Size size = const Size(1440, 900),
}) async {
  final doors = FakeWebDoors();
  clipboard.clear();
  page.thePageWasAsked.clear();
  tester.view.physicalSize = size;
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
    TrialApp(language: language, doors: () async => doors, font: fixtureFont),
  );
  await tester.pump();
  await tester.pump();
  return doors;
}

/// The restore builds the PDF: real async work, given real time.
Future<void> restore(WidgetTester tester) async {
  await press(tester, TheTrial.restore);
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('the full flow: write, answer the suggestion, copy only the '
      'protected text, paste the answer, read it with the real names, and the '
      'PDF and its two buttons', (tester) async {
    final doors = await pumpTrial(tester);
    expect(doors.doorsAsked, ['z_open']);
    expect(doors.asked.single.$2, {'pack': 'en'});

    await write(tester, letter);
    expect(doors.doorsAsked.last, 'z_import_text');
    // A suggestion waits: nothing can leave yet, and the safe side says so.
    expect(find.text(en.oneSuggestionStillOpenSend), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(TheTrial.copyProtected)).onPressed,
      isNull,
    );

    // The caret on «Björn»: the suggestion's two answers.
    await caretAt(tester, letter.indexOf('Björn') + 2);
    expect(find.byKey(TheTrial.protectIt), findsOneWidget);
    expect(find.byKey(TheTrial.leaveIt), findsOneWidget);
    await press(tester, TheTrial.protectIt);
    // Answered by the finding behind the mark, as ed's door takes it.
    final answered = doors.asked
        .where((a) => a.$1 == 'z_answer_finding')
        .single
        .$2;
    expect(answered.keys, unorderedEquals(['session', 'finding', 'answer']));
    expect(answered['answer'], 'protect');
    expect(answered['finding'], doors.findingOf('Björn'));

    // The safe side is the core's text, and «Copy Protected» copies only it.
    final safe = tester.widget<SelectableText>(find.byKey(TheTrial.safe)).data!;
    expect(safe, isNot(contains('Lindqvist')));
    expect(safe, isNot(contains('Björn')));
    expect(safe, isNot(contains('anna@example.org')));
    expect(safe, contains('__Z_PERSON_'));
    await press(tester, TheTrial.copyProtected);
    expect(clipboard, [
      '',
      safe,
    ], reason: 'emptied first (081), then only the protected text');
    expect(find.text(en.theChatIsOnYourClipboard), findsOneWidget);

    // The model's answer, pasted back with the tokens it was given.
    final tokens = RegExp(
      r'__Z_[A-Z0-9_]+__',
    ).allMatches(safe).map((m) => m.group(0)!).toList();
    await tester.enterText(
      find.byKey(TheTrial.answer),
      'Thank you, ${tokens.first}. I will write to ${tokens.last}.',
    );
    await tester.pump();
    await restore(tester);
    expect(
      doors.doorsAsked,
      containsAllInOrder([
        'z_build_payload',
        'z_payload_to_take_out',
        'z_ingest_answer',
        'z_restored_view',
      ]),
    );

    // The document: the text as written, then the answer with real names.
    expect(find.byKey(TheTrial.document), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(TheTrial.document),
        matching: find.text(en.trialYourText),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(TheTrial.document),
        matching: find.text(letter),
      ),
      findsOneWidget,
    );
    expect(find.text(en.trialTheAnswerWithRealNames), findsOneWidget);
    final answer = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(TheTrial.document),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().startsWith('Thank you'),
        ),
      ),
    );
    expect(
      answer.text.toPlainText(),
      'Thank you, Anna Lindqvist. I will write to anna@example.org.',
    );
    expect(find.text(en.trialYourCopyIsYours), findsOneWidget);

    await press(tester, TheTrial.save);
    expect(page.thePageWasAsked.single.$1, 'save');
    expect(page.thePageWasAsked.single.$2, 'z-trial.pdf');
    expect(page.thePageWasAsked.single.$3, greaterThan(1000));
    clipboard.clear();
    await press(tester, TheTrial.copyDocument);
    expect(clipboard.first, '');
    expect(clipboard.last, contains('Thank you, Anna Lindqvist.'));
    expect(clipboard.last, contains(letter));
  });

  testWidgets('«Leave it in the clear» answers the finding, and every '
      'suggestion of the same value with it; the value leaves as written', (
    tester,
  ) async {
    final doors = await pumpTrial(tester);
    const text = 'Björn met Björn at the harbour.';
    await write(tester, text);
    expect(find.text(en.suggestionsStillOpenSend(2)), findsOneWidget);
    await caretAt(tester, 1);
    await press(tester, TheTrial.leaveIt);
    final answered = doors.asked
        .where((a) => a.$1 == 'z_answer_finding')
        .single
        .$2;
    expect(answered['answer'], 'leave');
    expect(tester.widget<SelectableText>(find.byKey(TheTrial.safe)).data, text);
    expect(
      doors.doorsAsked,
      isNot(contains('z_protect')),
      reason: 'a suggestion is answered, never protected by z_protect',
    );
  });

  test('a mark with no finding is a hand mark, and is not answered', () {
    final core = TheWebCore(FakeWebDoors())..open('en');
    const hand = WebMark(
      start: 0,
      end: 3,
      state: 'protected',
      kind: 'custom',
      source: 'hand',
      decided: true,
    );
    expect(
      () => core.answerFinding(hand, protect: false),
      throwsA(isA<WebRefusal>().having((r) => r.name, 'name', 'bad_span')),
    );
    // And a source the web cannot have is read without trouble.
    final vault = WebView.read({
      'text': 'abc',
      'marks': [
        {
          'start': 0,
          'end': 3,
          'state': 'protected',
          'token': '__Z_X_1__',
          'kind': 'person',
          'source': 'vault',
          'decided': true,
          'finding': null,
        },
      ],
    });
    expect(vault.marks.single.source, 'vault');
  });

  testWidgets('a token the core could not place stays as the model wrote it, '
      'drawn apart from the text, and goes into the PDF as it is', (
    tester,
  ) async {
    Uint8List? pdf;
    final doors = FakeWebDoors();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await write(tester, 'Dear Anna Lindqvist,');
    await press(tester, TheTrial.copyProtected);
    await tester.enterText(
      find.byKey(TheTrial.answer),
      'Thank you, __Z_PERSON_99__.',
    );
    await tester.pump();
    await restore(tester);
    final answer = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(TheTrial.document),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().startsWith('Thank you'),
        ),
      ),
    );
    expect(answer.text.toPlainText(), 'Thank you, __Z_PERSON_99__.');
    TextStyle? styleOf(String piece) {
      TextStyle? found;
      answer.text.visitChildren((span) {
        if (span is TextSpan && span.text == piece) found = span.style;
        return found == null;
      });
      return found;
    }

    expect(
      styleOf('__Z_PERSON_99__')?.backgroundColor,
      isNotNull,
      reason: 'told apart from the text',
    );
    expect(styleOf('Thank you, ')?.backgroundColor, isNull);
    expect(pdf, isNotNull);
  });

  testWidgets('a hand selection is protected everywhere it stands, and undone '
      'by the caret on it', (tester) async {
    final doors = await pumpTrial(tester);
    const text = 'Kalle met Kalle at the harbour.';
    await write(tester, text);
    original(tester).selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    await tester.pump();
    await press(tester, TheTrial.protect);
    final p = doors.asked.where((a) => a.$1 == 'z_protect').single.$2;
    expect(p, {
      'session': 1,
      'start': 0,
      'end': 5,
      'kind': 'custom',
      'scope': 'conversation',
    });
    final safe = tester.widget<SelectableText>(find.byKey(TheTrial.safe)).data!;
    expect(RegExp('__Z_CUSTOM_').allMatches(safe), hasLength(2));
    await caretAt(tester, 12);
    await press(tester, TheTrial.unprotect);
    expect(doors.asked.where((a) => a.$1 == 'z_unprotect').single.$2, {
      'session': 1,
      'start': 10,
      'end': 15,
    });
    // The safe side is read again from the core after the undo.
    expect(
      tester.widget<SelectableText>(find.byKey(TheTrial.safe)).data,
      contains('met Kalle'),
    );
  });

  testWidgets('a press on a provider or a key field says at once that the app '
      'is needed, and no field takes a key', (tester) async {
    await pumpTrial(tester);
    final fields = find.byType(EditableText).evaluate().length;
    await press(tester, TheTrial.ai);
    expect(find.byKey(TheTrial.providers), findsOneWidget);
    for (final name in theProvidersTheAppKnows) {
      expect(find.text(name), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(TheTrial.providers),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );
    expect(
      find.byType(EditableText).evaluate(),
      hasLength(fields),
      reason: 'no field opened',
    );
    await press(tester, const ValueKey<String>('trial-key-Anthropic'));
    expect(find.text(en.trialKeysNeedTheApp), findsOneWidget);
    // The message leads to the download page.
    await tester.tap(find.text(en.trialKeysNeedTheApp));
    expect(page.thePageWasAsked.last, ('go', '/en/download/', 0));
  });

  testWidgets('the notice band and the line to the front page stand on every '
      'state, outside what scrolls', (tester) async {
    Future<void> both(String state) async {
      expect(find.text(en.trialNotice), findsOneWidget, reason: state);
      expect(find.text(en.trialAboutZ), findsOneWidget, reason: state);
      expect(
        find.ancestor(
          of: find.byKey(TheTrial.notice),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
        reason: state,
      );
    }

    final doors = FakeWebDoors();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TrialApp(
        language: 'en',
        doors: () => Future<FakeWebDoors>.delayed(
          const Duration(seconds: 1),
          () => doors,
        ),
        font: fixtureFont,
      ),
    );
    await both('loading');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await both('empty');
    await write(tester, letter);
    await both('a suggestion waits');
    await press(tester, TheTrial.ai);
    await both('providers open');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pump();
    await both('scrolled to the foot');
    await tester.tap(find.byKey(TheTrial.notice));
    expect(page.thePageWasAsked.last, ('go', '/en/download/', 0));
    await tester.tap(find.byKey(TheTrial.about));
    expect(page.thePageWasAsked.last, ('go', '/en/', 0));
  });

  testWidgets('Arabic: the trial reads right to left, its sentences are the '
      'lead\'s, and the scanner starts with the Arabic pack', (tester) async {
    final doors = await pumpTrial(
      tester,
      language: 'ar',
      size: const Size(390, 844),
    );
    expect(doors.asked.single.$2, {'pack': 'ar'});
    expect(
      Directionality.of(tester.element(find.byKey(TheTrial.notice))),
      TextDirection.rtl,
    );
    expect(
      find.text(
        'هذه تجربة لـ Z على الويب. يُرجى عدم كتابة معلومات مهمة هنا. للاستعمال الحقيقي، يلزم تثبيت التطبيق.',
      ),
      findsOneWidget,
    );
    // The band starts at the right: its sign stands on the right-hand side.
    final band = tester.getRect(find.byKey(TheTrial.notice));
    expect(
      tester.getCenter(find.byIcon(Icons.info_outline)).dx,
      greaterThan(band.center.dx),
    );
    await write(tester, 'كتبت آمنة الحسيني رسالة.');
    final safe = tester.widget<SelectableText>(find.byKey(TheTrial.safe));
    expect(safe.textDirection, TextDirection.rtl);
    expect(
      tester.widget<TextField>(find.byKey(TheTrial.original)).textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('the scanner\'s language is chosen in the head, as in the app: '
      'a new pack is a new session, and the text is read again', (
    tester,
  ) async {
    final doors = await pumpTrial(tester);
    await write(tester, letter);
    await tester.tap(find.byKey(TheTrial.pack));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Svenska (SV)').last);
    await tester.pumpAndSettle();
    expect(doors.pack, 'sv');
    expect(doors.doorsAsked.toList().sublist(doors.doorsAsked.length - 2), [
      'z_open',
      'z_import_text',
    ]);
  });

  test('the language follows the page\'s address', () {
    String of(String a) => theLanguageOfTheAddress(Uri.parse(a));
    expect(of('https://z-privacy.com/sv/'), 'sv');
    expect(of('https://z-privacy.com/ar/try/'), 'ar');
    expect(of('http://127.0.0.1:8000/de/index.html'), 'de');
    expect(of('https://z-privacy.com/'), 'en');
    expect(of('https://z-privacy.com/xx/'), 'en');
    // Our own pages; Swedish has none yet (rule 86 (e)), so it goes to English.
    expect(theFrontPage('fr'), '/fr/');
    expect(theDownloadPage('sv'), '/en/download/');
  });

  test('the providers are the core\'s own labels, in its order', () {
    final mod = File('../../z_core/src/providers/mod.rs').readAsStringSync();
    final known = mod.substring(mod.indexOf('pub(crate) fn known()'));
    final files = RegExp(
      r'Box::new\((\w+)::',
    ).allMatches(known).map((m) => m.group(1)!).where((f) => f != 'fake');
    final labels = [
      for (final f in files)
        RegExp(r'fn label\(&self\) -> &.static str \{\s*"([^"]+)"')
                .firstMatch(
                  File('../../z_core/src/providers/$f.rs').readAsStringSync(),
                )
                ?.group(1) ??
            '?$f',
    ];
    expect(labels, theProvidersTheAppKnows);
  });
}

// Paper 122 §3.6 — **the trial's pictures**: English, Arabic and Swedish, at
// 390 px (a phone) and at 1440 px, written to `test/web/shots/`.
//
// Each picture is the trial after a whole flow on the fake of ed's shape: a
// letter written, its suggestion answered, the protected text copied, the
// answer pasted and read back into the document. Two pictures each: the top of
// the page (the line, the band, the two sides) and its foot (the document).
// The trial's own font, DejaVu Sans, and the icon font are loaded, so the
// letters drawn are the ones a browser draws. Invented letters only.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/web/the_trial.dart';

import 'the_fake_web_core.dart';
import 'the_trial_test.dart' show fixtureFont;
import 'trial_steps.dart';

const _letters = {
  'en':
      'Dear Anna Lindqvist,\nBjörn wrote to anna@example.org about the contract for the harbour.\nKind regards,',
  'ar':
      'السيدة آمنة الحسيني،\nكتب Björn إلى anna@example.org بشأن عقد الميناء.\nمع التحية،',
  'sv':
      'Hej Anna Lindqvist!\nBjörn skrev till anna@example.org om avtalet för hamnen.\nMed vänliga hälsningar,',
};

const _answers = {
  'en':
      'Thank you, {person}. I have read the note from {other} and will answer at {email} this week.',
  'ar': 'شكراً {person}. قرأت ملاحظة {other} وسأجيب على {email} هذا الأسبوع.',
  'sv':
      'Tack, {person}. Jag har läst meddelandet från {other} och svarar på {email} i veckan.',
};

const _whole = ValueKey<String>('the-whole-trial');

String _iconFace() {
  for (
    var here = File(Platform.resolvedExecutable).parent;
    here.path != here.parent.path;
    here = here.parent
  ) {
    if (here.path.split(Platform.pathSeparator).last == 'cache') {
      return [
        here.path,
        'artifacts',
        'material_fonts',
        'MaterialIcons-Regular.otf',
      ].join(Platform.pathSeparator);
    }
  }
  return '';
}

Future<void> _picture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_whole),
  );
  late final int bytes;
  await tester.runAsync(() async {
    final shot = await boundary.toImage();
    final png = await shot.toByteData(format: ImageByteFormat.png);
    final file = File('test/web/shots/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
    bytes = file.lengthSync();
  });
  expect(
    bytes,
    greaterThan(12000),
    reason: 'test/web/shots/$name.png came out at $bytes bytes',
  );
}

void main() {
  final icons = _iconFace();
  setUpAll(() async {
    await (FontLoader(trialFont)..addFont(fixtureFont())).load();
    if (File(icons).existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(File(icons).readAsBytesSync())),
          ))
          .load();
    }
  });

  for (final lang in const ['en', 'ar', 'sv']) {
    for (final width in const [390, 1440]) {
      testWidgets('the trial in $lang at $width px', (tester) async {
        final size = Size(width.toDouble(), width == 390 ? 844 : 900);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
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
        final doors = FakeWebDoors();
        await tester.pumpWidget(
          RepaintBoundary(
            key: _whole,
            child: TrialApp(
              language: lang,
              doors: () async => doors,
              font: fixtureFont,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final letter = _letters[lang]!;
        await write(tester, letter);
        await caretAt(tester, letter.indexOf('Björn') + 1);
        await press(tester, TheTrial.protectIt);
        await press(tester, TheTrial.copyProtected);
        final safe = tester
            .widget<SelectableText>(find.byKey(TheTrial.safe))
            .data!;
        String token(String kind) => RegExp(
          '__Z_${kind}_[0-9]+__',
        ).allMatches(safe).map((m) => m.group(0)!).first;
        final persons = RegExp(
          r'__Z_PERSON_[0-9]+__',
        ).allMatches(safe).map((m) => m.group(0)!).toList();
        await tester.enterText(
          find.byKey(TheTrial.answer),
          _answers[lang]!
              .replaceAll('{person}', persons.first)
              .replaceAll('{other}', persons.last)
              .replaceAll('{email}', token('EMAIL')),
        );
        await tester.pump();
        await press(tester, TheTrial.restore);
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }
        expect(find.byKey(TheTrial.document), findsOneWidget);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 4000),
        );
        await tester.pumpAndSettle();
        await caretAt(
          tester,
          letter.contains('Anna') ? letter.indexOf('Anna') + 1 : 0,
        );
        await tester.pumpAndSettle();
        await _picture(tester, '$lang-the-trial-$width-top');
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -4000),
        );
        await tester.pumpAndSettle();
        await _picture(tester, '$lang-the-trial-$width-the-document');
      });
    }
  }

  // Paper 123: a two-turn chat, and the «Start over» question.
  const questions = {
    'en': 'Can Anna Lindqvist sign the contract on Friday?',
    'ar': 'هل تستطيع آمنة الحسيني توقيع العقد يوم الجمعة؟',
    'sv': 'Kan Anna Lindqvist skriva under avtalet på fredag?',
  };
  const secondAnswers = {
    'en': 'Yes. {person} can sign on Friday at the harbour office.',
    'ar': 'نعم. تستطيع {person} التوقيع يوم الجمعة في مكتب الميناء.',
    'sv': 'Ja. {person} kan skriva under på fredag på hamnkontoret.',
  };
  for (final lang in const ['en', 'ar', 'sv']) {
    for (final width in const [390, 1440]) {
      testWidgets(
        'the chat in $lang at $width px, and the start-over question',
        (tester) async {
          final size = Size(width.toDouble(), width == 390 ? 844 : 900);
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
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
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          final doors = FakeWebDoors();
          await tester.pumpWidget(
            RepaintBoundary(
              key: _whole,
              child: TrialApp(
                language: lang,
                doors: () async => doors,
                font: fixtureFont,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          final letter = _letters[lang]!;
          await write(tester, letter);
          await caretAt(tester, letter.indexOf('Björn') + 1);
          await press(tester, TheTrial.protectIt);
          await press(tester, TheTrial.copyProtected);
          final first = copied.last;
          final persons = RegExp(
            r'__Z_PERSON_[0-9]+__',
          ).allMatches(first).map((m) => m.group(0)!).toList();
          final email = RegExp(
            r'__Z_EMAIL_[0-9]+__',
          ).firstMatch(first)!.group(0)!;
          await tester.enterText(
            find.byKey(TheTrial.answer),
            _answers[lang]!
                .replaceAll('{person}', persons.first)
                .replaceAll('{other}', persons.last)
                .replaceAll('{email}', email),
          );
          await tester.pump();
          await press(tester, TheTrial.restore);
          for (var i = 0; i < 6; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await tester.pump();
          }
          await tester.ensureVisible(find.byKey(TheTrial.compose));
          await tester.enterText(
            find.byKey(TheTrial.compose),
            questions[lang]!,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          await press(tester, TheTrial.copyProtected);
          final token = RegExp(
            r'__Z_PERSON_[0-9]+__',
          ).firstMatch(copied.last.split('\n\n').last)!.group(0)!;
          await tester.enterText(
            find.byKey(TheTrial.answer),
            secondAnswers[lang]!.replaceAll('{person}', token),
          );
          await tester.pump();
          await press(tester, TheTrial.restore);
          for (var i = 0; i < 6; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await tester.pump();
          }
          // The second answer's restored text open, as a visitor would read it.
          await tester.ensureVisible(find.byKey(const Key('the-chat-show-1')));
          await tester.pump();
          await tester.tap(find.byKey(const Key('the-chat-show-1')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(TheTrial.chat));
          await tester.pumpAndSettle();
          await _picture(tester, '$lang-the-chat-$width');
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -6000),
          );
          await tester.pumpAndSettle();
          await _picture(tester, '$lang-the-chat-$width-the-document');
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, 6000),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(TheTrial.startOver));
          await tester.pumpAndSettle();
          expect(find.byKey(TheTrial.startOverQuestion), findsOneWidget);
          await _picture(tester, '$lang-start-over-$width');
        },
      );
    }
  }
}

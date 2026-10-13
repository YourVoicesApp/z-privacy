// 076 — two clicks take one value: word, space, next word.
//
// **The owner, 13 Oct:** «الضغطتان تأخذان كلمة ومسافة والكلمة التالية، قيمةً
// واحدة» — two clicks take a word and a space and the word after it, as **one**
// value, not two selections.
//
// The value is a **span**, so it reads exactly as the document reads between
// its two ends: only the ends are tidied of the marks a sentence leaves
// (`wordAt`'s list, which is the core's at `z_core/src/text.rs:103`). A mark
// that falls *between* the two words stays inside the value, because taking it
// out would mean handing the core two spans and changing how the text reads —
// which this product forbids.
//
// And the line law holds here as it holds for the hand: **a selection may not
// cross a line break**, so two clicks on the last word of a line take that
// word alone and never reach down to the next line.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/widgets/document_text.dart';

import 'drawn_document.dart';

/// What two clicks on `word` would take out of `text`.
String? pair(String text, String word) {
  final at = text.indexOf(word);
  final r = wordPairAt(text, at + word.length ~/ 2);
  return r == null ? null : text.substring(r.start, r.end);
}

void main() {
  group('the value two clicks take', () {
    test('a title and the name after it, in four languages', () {
      expect(pair('Rechnung fuer Herr Mueller bitte', 'Herr'), 'Herr Mueller');
      expect(pair('skriv till Hedvig Palmgren idag', 'Hedvig'), 'Hedvig Palmgren');
      expect(pair('call Margaret Wilson today', 'Margaret'), 'Margaret Wilson');
      expect(pair('اتصل مارغريت ويلسون اليوم', 'مارغريت'), 'مارغريت ويلسون');
    });

    test('the ends are tidied and the middle is not', () {
      // The dot the sentence ends with is not part of the value…
      expect(pair('ruf Herr Mueller.', 'Herr'), 'Herr Mueller');
      expect(pair('«Herr Mueller» bitte', 'Herr'), 'Herr Mueller');
      // …but a comma that falls between the two words is inside it, because a
      // value is one stretch of the document and that is how the document
      // reads. Cutting it out would need two spans and would change the text.
      expect(pair('Rechnung Mueller, bitte zahlen', 'Mueller'), 'Mueller, bitte');
      expect(pair('اتصل ويلسون، اليوم', 'ويلسون'), 'ويلسون، اليوم');
    });

    test('a line break is not a space you may cross', () {
      expect(pair('call Margaret\nWilson today', 'Margaret'), 'Margaret');
      expect(pair('Margaret Wilson\nnext line', 'Wilson'), 'Wilson');
      expect(pair('اتصل ويلسون\nغداً', 'ويلسون'), 'ويلسون');
    });

    test('and where there is no next word, one word is the whole value', () {
      expect(pair('Herr Mueller', 'Mueller'), 'Mueller', reason: 'the end of the document');
      expect(pair('Herr Mueller ', 'Mueller'), 'Mueller', reason: 'a trailing space');
      expect(pair('Herr  Mueller', 'Herr'), 'Herr',
          reason: 'the rule says one space; two is not one, and taking less is '
              'the half a second it costs to click again');
      expect(pair('Herr — Mueller', 'Herr'), 'Herr',
          reason: 'a dash is not a word, and the value may not end on a mark');
    });

    test('two clicks on a space take nothing, as one click does', () {
      expect(wordPairAt('Herr Mueller bitte', 4), isNull);
      expect(wordPairAt('', 0), isNull);
    });
  });

  group('on the glass', () {
    const doc = 'Rechnung fuer Herr Mueller, bitte zahlen';

    Future<void> openDocument(
      WidgetTester tester,
      void Function(int, int) report,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 300,
              child: OriginalText(
                text: doc,
                marks: const [],
                onSelection: report,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String? whatIsHighlighted(WidgetTester tester) {
      final sel = drawnDocument(tester, 'Mueller').selection;
      if (sel == null || sel.isCollapsed) return null;
      return doc.substring(sel.start, sel.end);
    }

    testWidgets('two clicks on «Herr» hold «Herr Mueller», and report it', (
      tester,
    ) async {
      int? from;
      int? to;
      await openDocument(tester, (a, b) {
        from = a;
        to = b;
      });

      final at = doc.indexOf('Herr');
      final where = whereIsInDocument(tester, 'Mueller', at + 2);
      await tester.tapAt(where, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(where, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(
        whatIsHighlighted(tester),
        'Herr Mueller',
        reason: 'two clicks must hold one value of two words, and the glass '
            'holds «${whatIsHighlighted(tester)}»',
      );
      expect(
        [from, to],
        [at, at + 'Herr Mueller'.length],
        reason: 'the pair was not reported upward, so Protect would act on '
            'something other than what is drawn',
      );
    });

    testWidgets('a drag still draws its own span, before and after two clicks', (
      tester,
    ) async {
      // 076, item 4 — **the drag is the gesture that was already there**, and
      // the press-and-hold law is its own: it follows the mouse. The click and
      // the pair live in the same handler, so this is the guard that says they
      // took nothing away from the hand.
      await openDocument(tester, (_, _) {});

      Future<String?> dragAcross(WidgetTester tester) async {
        final box = tester.renderObject<RenderBox>(find.byType(EditableText));
        final drag = await tester.startGesture(
          box.localToGlobal(const Offset(4, 8)),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 60));
        await drag.moveTo(
          whereIsInDocument(tester, 'Mueller', doc.indexOf('bitte') + 2),
        );
        await tester.pump(const Duration(milliseconds: 60));
        await drag.up();
        await tester.pumpAndSettle();
        return whatIsHighlighted(tester);
      }

      final before = await dragAcross(tester);
      expect(before, contains('Herr Mueller'));
      expect(
        before!.length,
        greaterThan('Herr Mueller'.length),
        reason: 'the hand drew a span and got a word back: the click code '
            'overrode the drag',
      );

      final at = doc.indexOf('Herr');
      final where = whereIsInDocument(tester, 'Mueller', at + 2);
      await tester.tapAt(where, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(where, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(whatIsHighlighted(tester), 'Herr Mueller');

      // Past the double-click timeout first, so what follows is a **plain**
      // drag and not Flutter's own click-and-drag, which selects by whole
      // words and is its behaviour rather than ours.
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 100));
      final after = await dragAcross(tester);
      expect(after, before, reason: 'the pair left something behind in the drag');
    });

    testWidgets('two clicks far apart in time are two single clicks', (
      tester,
    ) async {
      await openDocument(tester, (_, _) {});

      // The second click comes after the double-click timeout, so Flutter's own
      // recognizer counts it as a first click again — and the rule for one
      // click is one word. This is the guard that keeps «two clicks» from
      // meaning «any second click ever».
      final at = doc.indexOf('Herr');
      final where = whereIsInDocument(tester, 'Mueller', at + 2);
      await tester.tapAt(where, kind: PointerDeviceKind.mouse);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 100));
      await tester.tapAt(where, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(whatIsHighlighted(tester), 'Herr');
    });
  });
}

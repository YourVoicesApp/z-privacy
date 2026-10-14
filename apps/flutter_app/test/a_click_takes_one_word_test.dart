// 076 — one left click takes one word, and the glass shows what will be taken.
//
// **The owner, 13 Oct, sealed:** a word begins right after a space and ends
// right before the next space; the space is never part of a one-click
// selection; the start and end of a line count as a space; and the marks a
// sentence leaves at the edges stay **out** of the value — «a one-click
// selection on `Wilson,` shows `Wilson` selected and the comma apart».
//
// **The same cases are asserted in Rust**, against `whole_words`, in
// `the_marks_a_hand_selection_leaves_behind`. The law lives in the core — it
// is what actually trims a span at protection time — and `wordAt` is the glass
// showing it before the press. Two guards, one list of cases: if either side
// drifts, its own guard reddens, which is the only honest way to hold a rule
// that must be known in two places at once.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/widgets/document_text.dart';

import 'drawn_document.dart';

String? taken(String text, String word) {
  final at = text.indexOf(word);
  final r = wordAt(text, at + word.length ~/ 2);
  return r == null ? null : text.substring(r.start, r.end);
}

void main() {
  group('the word the owner ruled', () {
    test('a name in a sentence, in four languages', () {
      expect(taken('Herr Mueller bitte', 'Mueller'), 'Mueller');
      expect(taken('Hedvig Palmgren i Falkenberg', 'Palmgren'), 'Palmgren');
      expect(taken('call Margaret today', 'Margaret'), 'Margaret');
      expect(taken('مارغريت ويلسون شخص', 'ويلسون'), 'ويلسون');
    });

    test('the marks a sentence leaves are not part of the value', () {
      expect(taken('Herr Mueller, bitte', 'Mueller'), 'Mueller');
      expect(taken('Herr "Mueller" bitte', 'Mueller'), 'Mueller');
      expect(taken('call Margaret.\nNext line', 'Margaret'), 'Margaret');
      expect(taken('مارغريت ويلسون، شخص', 'ويلسون'), 'ويلسون');
    });

    test('a mark a value is made of is kept — the filter trims, it does not split', () {
      expect(taken('Anne-Marie Berg', 'Anne-Marie'), 'Anne-Marie');
      expect(taken("O'Brien and Sons", "O'Brien"), "O'Brien");
      expect(taken('Margaret Wilson,person', 'Wilson,person'), 'Wilson,person');
      // The plus is at an edge, so 085's ruling 3 takes it. Named on its own
      // below, with what it costs.
      expect(taken('tel +49 228 oder', '+49'), '49');
    });

    test('every mark the keyboard has leaves an edge — 085, ruling 3', () {
      // The owner, 14 Oct: «وبالنسبة للرموز لا أقصد فقط هذه الرموز… بل جميع
      // الرموز الموجودة في الكيبورد». The core answers it as a complement —
      // not a letter, not a digit, not a space, and not a mark belonging to the
      // letter before it — and these are the same cases as the core's own
      // `every_mark_the_keyboard_has_leaves_an_edge`.
      const marks = <String>[
        '!', '?', '(', ')', '[', ']', '{', '}', '<', '>', '@', '#', r'$', '%',
        '&', '*', '+', '=', '/', '\\', '|', '~', '^', '_', '§', '´', '¨',
        '…', '«', '»', '„', '“', '”', '’', '—', '–', '،', '؛', '؟', '.', ',',
        ';', ':', "'", '"',
      ];
      for (final mark in marks) {
        expect(
          taken('Herr Mueller$mark bitte', 'Mueller$mark'),
          'Mueller',
          reason: 'trailing «$mark»',
        );
        expect(
          taken('Herr ${mark}Mueller bitte', '${mark}Mueller'),
          'Mueller',
          reason: 'leading «$mark»',
        );
      }
    });

    test('a diacritic is part of the word, not a mark around it', () {
      // The guard that forbids the cheap reading of ruling 3. «Anything that is
      // not a letter or a digit» would strip the Arabic harakat off a name, and
      // Z's Arabic is a whole script family.
      expect(taken('اتصل ويلسونَ غدا', 'ويلسونَ'), 'ويلسونَ');
      expect(taken('Herr Jose\u{301} bitte', 'Jose\u{301}'), 'Jose\u{301}');
    });

    test('what the widened set costs, measured: a value that starts with a mark', () {
      // Pinned, not hidden. A reference number and a phone number begin with a
      // mark that belongs to the **value**, and the word rule has no notion of
      // kind. 085's ruling 2 — numbers are not words — is where that is
      // answered, by kind, in the core. Until then the glass shows this.
      expect(taken('ref #4711 bitte', '#4711'), '4711');
      expect(taken('tel +46 8 123 oder', '+46'), '46');
      // Interior, and so untouched: an address stays one value.
      expect(taken('mail anas@mono-peak.com heute', 'anas@mono-peak.com'),
          'anas@mono-peak.com');
    });

    test('a click on a space takes nothing, and so does an empty document', () {
      expect(wordAt('Herr Mueller', 4), isNull, reason: 'the space between two words');
      expect(wordAt('Herr Mueller', 5), isNotNull, reason: 'the first letter of a word is a word');
      expect(wordAt('', 0), isNull);
      expect(wordAt('   ', 1), isNull);
    });

    test('the end of the line is an edge, not a neighbour', () {
      // The owner's rule as stated: a word ends before the next space, and a
      // line break is a space. Taking the first word of the next line would be
      // «a hand selection crossing a line break», which this product forbids.
      expect(taken('Margaret\nWilson', 'Margaret'), 'Margaret');
      expect(taken('Margaret\nWilson', 'Wilson'), 'Wilson');
    });
  });

  group('on the glass', () {
    testWidgets('a click on ordinary text selects that word and reports it', (
      tester,
    ) async {
      const doc = 'Rechnung für Herr Mueller, bitte zahlen';
      int? from;
      int? to;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 300,
              child: OriginalText(
                text: doc,
                marks: const [],
                onSelection: (a, b) {
                  from = a;
                  to = b;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A press where the word is drawn, read off the drawing — not a point
      // worked out here, which is the mistake `drawn_document` exists for.
      final at = doc.indexOf('Mueller');
      await tester.tapAt(whereIsInDocument(tester, 'Mueller', at + 3));
      await tester.pumpAndSettle();

      final drawn = drawnDocument(tester, 'Mueller');
      expect(
        drawn.selection,
        isNotNull,
        reason: 'the click selected nothing at all',
      );
      expect(
        doc.substring(drawn.selection!.start, drawn.selection!.end),
        'Mueller',
        reason: 'the glass highlights '
            '«${doc.substring(drawn.selection!.start, drawn.selection!.end)}» — '
            'the comma must stay in the text, apart from the value',
      );
      expect(
        [from, to],
        [at, at + 'Mueller'.length],
        reason: 'the selection was not reported upward, so Protect would act '
            'on something other than what is drawn',
      );
    });
  });
}

// **084, rulings 5 to 7 — the completion under the bar**, as pure functions, so
// the owner's own example is a test and not a demonstration.
//
// His guard, written into the paper: «Lin» in a document holding Lindqvist ×12
// and Lindberg ×2 → faint *Lindqvist*; Tab → the bar reads «Lindqvist»; Enter →
// the 12-place result. «Li» → nothing. Then «d» → *Lindberg*, because Lindqvist
// was refused by the typing; then «b» → nothing more fits that was not shown,
// so the faint text is gone.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/completing.dart';

/// Twelve Lindqvist and two Lindberg, as the owner's example has it.
final _doc = [
  for (var i = 0; i < 12; i++) 'Kontakta Lindqvist i dag.',
  'Lindberg svarade inte.',
  'Hälsningar till Lindberg.',
].join('\n');

void main() {
  group('the words offered are the document\'s own', () {
    test('the owner\'s example, letter by letter', () {
      final words = theWordsOf(_doc);
      final refused = <String>{};

      // Two letters: nothing. The rule starts at the third.
      expect(theWordOffered(words, 'Li', refused), isNull);

      // Three: the word that stands in the most places with that beginning.
      final first = theWordOffered(words, 'Lin', refused);
      expect(first, 'Lindqvist');

      // **Typing on refuses what was shown.** The bar remembers that, not this
      // function — and the next letter offers the next word that fits.
      refused.add(first!);
      expect(theWordOffered(words, 'Lind', refused), 'Lindberg');

      // And one letter more: nothing else fits that has not been shown, so the
      // faint text is gone and the typing goes on.
      refused.add('Lindberg');
      expect(theWordOffered(words, 'Lindb', refused), isNull);
    });

    test('a refused word does not come back while the bar holds it', () {
      final words = theWordsOf(_doc);
      // Erasing back to the third letter offers the next word that fits and has
      // not been refused — not the refused one, however well it fits.
      expect(theWordOffered(words, 'Lin', {'Lindqvist'}), 'Lindberg');
      expect(theWordOffered(words, 'Lin', {'Lindqvist', 'Lindberg'}), isNull);
      // An empty bar starts fresh, which is the bar's own act: with nothing
      // refused, the most frequent one is offered again.
      expect(theWordOffered(words, 'Lin', <String>{}), 'Lindqvist');
    });

    test('case-blind, and a tie goes to the earlier word in reading order', () {
      final words = theWordsOf('Berg och Berga\nBERG igen\nberga också\n');
      // «Berg» ×2 (Berg, BERG) and «Berga» ×2 (Berga, berga): a tie, and the
      // first one in reading order wins — with the spelling the document uses
      // there.
      expect(theWordOffered(words, 'ber', <String>{}), 'Berg');
      // Typing past it offers the other one.
      expect(theWordOffered(words, 'ber', {'Berg'}), 'Berga');
      // The typed word itself is not a completion of itself.
      expect(theWordOffered(words, 'berg', <String>{}), 'Berga');
    });

    test('the words are the glass\'s own words, marks trimmed at the edges', () {
      // The same law a click keeps: the marks a sentence leaves are not part of
      // the word, and a mark inside one stays.
      final words = theWordsOf('Herr Mueller, bitte.\nAnne-Marie O\'Brien\n');
      expect(words, contains('Mueller'));
      expect(words, contains('Anne-Marie'));
      expect(words, contains("O'Brien"));
      expect(words.where((w) => w.contains(',')), isEmpty);
      expect(words.where((w) => w.endsWith('.')), isEmpty);
    });

    test('three letters are three letters the eye sees', () {
      // Arabic: three letters, and a vowel mark on one of them is not a fourth.
      final words = theWordsOf('اتصل بالمحامي اليوم\nالمحامي كتب\n');
      expect(lettersTheEyeSees('لين'), 3);
      expect(lettersTheEyeSees('لِي'), 2, reason: 'a kasra was counted as a letter');
      expect(lettersTheEyeSees('Jose\u{301}'), 4);
      expect(theWordOffered(words, 'الم', <String>{}), 'المحامي');
      expect(theWordOffered(words, 'ال', <String>{}), isNull);
    });

    test('nothing is offered from anywhere but the open document', () {
      final words = theWordsOf('Kontakta Lindqvist i dag.\n');
      // A name that is not in this document has no completion, however much it
      // looks like one that is.
      expect(theWordOffered(words, 'Lindb', <String>{}), isNull);
      expect(theWordOffered(words, 'Nor', <String>{}), isNull);
      expect(theWordsOf(''), isEmpty);
    });
  });
}

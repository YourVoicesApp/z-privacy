// **The completion under the search bar** — 084, rulings 5 to 7, and the
// owner's own words of 14 Oct: «تبدأ الاقتراحات اعتباراً من الحرف الثالث…
// بخط شفاف أسفل الكلمة… ثم تاب ثم إنتر».
//
// Three rules shape this file, and all three are the owner's:
//
//   * **From the third character**, and «character» means what the eye sees, so
//     Arabic «لين» counts three.
//   * **The words offered are the open document's own.** Never the vault, never
//     another session, never an earlier search — nothing is stored and nothing
//     from elsewhere is shown.
//   * **Typing on refuses what was shown, and a refused word does not come
//     back**: «استمرار الكتابة يعني أن الخيار الأول لا يستمر في الظهور، يختفي،
//     لا نعود إليه». Deliberately unlike a web search box that holds its guess
//     while the letters still agree. The refusals last until the bar is
//     emptied; an empty bar starts fresh.
//
// It is a pure function over the document's text and what has been typed. The
// bar keeps the refusals in its own `State` — the only place they exist — and
// this file keeps nothing at all.
import 'package:zprivacy/widgets/document_text.dart';

/// **A character as the eye sees it** — a code point that is not a mark bound to
/// the one before it.
///
/// The owner's rule counts «لين» as three, and `String.length` counts UTF-16
/// units, so a letter outside the basic plane would reach three too soon.
/// `package:characters` would count grapheme clusters exactly — and it is not a
/// dependency of this app, only a transitive one, and one call does not buy a
/// new line in `pubspec.yaml`.
///
/// So the count is the law this project already keeps in two places: a
/// combining mark belongs to the letter in front of it (085, ruling 3 —
/// `is_edge_mark` in the core, `\p{M}` in `document_text.dart`). For Arabic
/// that is the same answer as a grapheme count, vowel marks included, which is
/// what the rule is about.
final _mark = RegExp(r'\p{M}', unicode: true);

int lettersTheEyeSees(String s) =>
    s.runes.where((r) => !_mark.hasMatch(String.fromCharCode(r))).length;

/// **The words of the document, in reading order, by the glass's own word
/// law.**
///
/// `wordAt` is what a click takes and what the highlight draws (076, and the
/// owner's white-space ruling of 14 Oct), so the completion offers exactly the
/// words a person could have selected with one press. One law for both, or the
/// bar would offer something the document does not hold as a word.
///
/// Collected once per document by the bar, not per keystroke: on the owner's
/// 221-page book this is forty thousand words.
List<String> theWordsOf(String text) {
  final out = <String>[];
  var i = 0;
  while (i < text.length) {
    final word = wordAt(text, i);
    if (word == null) {
      i++;
      continue;
    }
    if (word.end > word.start) {
      out.add(text.substring(word.start, word.end));
    }
    // Past this word, whatever the edges did with its marks: `wordAt` trims
    // them inward, so the untrimmed end is what walks on.
    final from = i;
    while (i < text.length && wordAt(text, i) != null && i <= word.end) {
      i++;
    }
    if (i == from) i++;
  }
  return out;
}

/// **The one word offered under what has been typed**, or null when there is
/// none to offer.
///
/// The word that appears **most often** with that beginning, case-blind; a tie
/// goes to the one that comes **earlier in reading order**. Not the typed word
/// itself — completing «Lindqvist» with «Lindqvist» offers nothing — and never
/// one that has already been shown and typed past.
String? theWordOffered(List<String> words, String typed, Set<String> refused) {
  final wanted = typed.trim();
  if (lettersTheEyeSees(wanted) < 3) return null;
  final key = wanted.toLowerCase();
  final refusedKeys = refused.map((w) => w.toLowerCase()).toSet();

  // Count by case-blind key, keep the first spelling seen and where it stood.
  final counted = <String, ({String word, int places, int first})>{};
  for (var at = 0; at < words.length; at++) {
    final word = words[at];
    final lower = word.toLowerCase();
    if (!lower.startsWith(key) || lower == key) continue;
    if (refusedKeys.contains(lower)) continue;
    final seen = counted[lower];
    counted[lower] = seen == null
        ? (word: word, places: 1, first: at)
        : (word: seen.word, places: seen.places + 1, first: seen.first);
  }
  if (counted.isEmpty) return null;
  final best = counted.values.reduce((a, b) {
    if (a.places != b.places) return a.places > b.places ? a : b;
    return a.first <= b.first ? a : b;
  });
  return best.word;
}

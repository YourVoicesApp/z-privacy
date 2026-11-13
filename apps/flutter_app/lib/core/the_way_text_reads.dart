// **Which way a paragraph reads** — moved here from `protected_pdf.dart` by
// paper 122, word for word, so that the desktop's z-pdf and the web trial's
// PDF lay Arabic out by the one rule. Pure Dart: no `dart:io`, no bridge.
import 'package:flutter/painting.dart' show TextDirection;

/// The strong right-to-left letters, by the blocks they fall in.
///
/// Arabic and its supplements and presentation forms; Hebrew; Syriac, Thaana,
/// NKo and Samaritan between them. **Arabic here is a script, not a language**
/// — Persian and Urdu are written with it and read the same way, so the test
/// is the block and never the pack that happens to be loaded.
final _strongRtl = RegExp(
  r'[֐-׿؀-ۿ܀-ݏݐ-ݿހ-޿'
  r'߀-߿ࠀ-࠿ࢠ-ࣿיִ-ﭏﭐ-﷿ﹰ-﻿]',
);

/// The strong left-to-right letters. Latin, Greek and Cyrillic are enough for
/// what this product reads; anything outside both sets is not strong and does
/// not get a vote.
final _strongLtr = RegExp(r'[A-Za-zÀ-ʯͰ-֏]');

/// A token, which is ours and not the person's writing.
final _token = RegExp(r'__Z_[A-Z0-9_]+__');

/// Which way this one paragraph runs, or null when it has no opinion.
///
/// **The first strong letter decides** — the Unicode rule (UAX #9, P2/P3), not
/// one of ours. So a line opening with an amount or a date takes its direction
/// from the first real word after it, which is how an Arabic payroll line that
/// begins with a number comes out right. A paragraph with no strong letter at
/// all is left to right, as the algorithm says.
///
/// **With one subtraction: a `__Z_…__` token does not vote.** Its letters are
/// Latin and they are *ours* — we put them in the person's line. Counted as
/// strong they would decide the direction of any line whose first word was
/// protected, so protecting an Arabic name would silently lay that line out
/// left to right and the same document would read differently before and after
/// protection. Protection may not change how a document reads; that is close
/// to the whole promise. So the tokens come out before the question is asked.
bool paragraphIsRightToLeft(String paragraph) =>
    paragraphDirection(paragraph) ?? false;

/// True for right to left, false for left to right, **null for a paragraph
/// with no strong letter in it at all** — a blank line, a rule of dashes, a
/// line that is only a figure.
///
/// Null is not «left to right». A neutral line takes the direction of the
/// paragraphs around it, because a blank line between two Arabic paragraphs is
/// part of that Arabic passage and not a left-to-right interruption of it.
/// Treating it as left to right split the passage in three and the blank lines
/// disappeared from the page — found by rendering a letter and looking at it,
/// not by a test.
bool? paragraphDirection(String paragraph) {
  // Replaced by a space rather than removed, so the words either side of a
  // token stay separate words.
  final letters = paragraph.replaceAll(_token, ' ');
  final rtl = _strongRtl.firstMatch(letters);
  final ltr = _strongLtr.firstMatch(letters);
  if (rtl == null && ltr == null) return null;
  if (rtl == null) return false;
  if (ltr == null) return true;
  return rtl.start < ltr.start;
}

/// One run of neighbouring paragraphs that share a direction.
///
/// Grouping matters for more than tidiness: a document with no right-to-left
/// writing in it becomes **exactly one** block, so the page it produces is the
/// page it produced before any of this existed, and a German or Swedish
/// document cannot be disturbed by work done for Arabic.
class DirectionBlock {
  const DirectionBlock(this.rtl, this.text);
  final bool rtl;
  final String text;

  /// The text as it is handed to the writer, with a RIGHT-TO-LEFT MARK in
  /// front of every right-to-left line.
  ///
  /// **Because the bidi library decides the base direction for itself**, by the
  /// same first-strong rule — and it counts the Latin letters of a `__Z_…__`
  /// token, which we put there. So a line beginning with a protected name was
  /// ordered left to right by the library while being right-aligned by us: the
  /// token sat at the left-hand end of a right-aligned Arabic line. Measured on
  /// a rendered page, which is the only place it shows.
  ///
  /// U+200F is strong, zero width and carries no glyph of its own — the page
  /// with it and the page without it are identical wherever the direction was
  /// already right. The isolates U+2067/U+2069 would say it better and were
  /// tried first; DejaVu has no glyph for them and they drew as two `.notdef`
  /// boxes on the page.
  ///
  /// Every line, not just the first: the algorithm works a paragraph at a time
  /// and a block here is several paragraphs.
  String get laidOut =>
      rtl ? text.split('\n').map((line) => '\u200F$line').join('\n') : text;

  @override
  bool operator ==(Object other) =>
      other is DirectionBlock && other.rtl == rtl && other.text == text;

  @override
  int get hashCode => Object.hash(rtl, text);

  @override
  String toString() => '${rtl ? 'rtl' : 'ltr'}: ${text.replaceAll('\n', '⏎')}';
}

/// **Which way a whole document reads, for a screen that has to lay it out** —
/// paper 116, 25 October 2026.
///
/// The first run with an opinion decides, which is `directionBlocks`'s own
/// answer read once: a German letter is left to right, an Arabic one is right
/// to left, and a letter that opens with an amount takes the direction of its
/// first real word. **A `__Z_…__` token does not vote**, which is the half that
/// matters on the glass: the Safe column is full of tokens whose letters are
/// Latin and ours, and a protected Arabic letter must not flip because we put
/// them there.
///
/// It lives here, beside the rule it reads, because the alternative is a second
/// opinion about one fact. The PDF asks the blocks paragraph by paragraph and
/// the screen asks for the document's base; neither of them owns a copy of the
/// script tables.
///
/// **This is 086's reading base applied to a layout, not a new decision.** The
/// interface's own direction is a different question with a different answer —
/// the person's choice of language — and the document may never be laid out by
/// it: an English letter in an Arabic interface still reads left to right.
TextDirection theWayTheTextReads(String text) {
  for (final block in directionBlocks(text)) {
    return block.rtl ? TextDirection.rtl : TextDirection.ltr;
  }
  return TextDirection.ltr;
}

/// Cut the text into runs of paragraphs that share a direction.
///
/// A neutral paragraph — blank, or only figures — joins whatever run it finds
/// itself in and never starts one, so the blank line inside an Arabic passage
/// stays inside it and is still a blank line on the page. Leading neutral
/// lines wait for the first paragraph that has a direction and take it.
List<DirectionBlock> directionBlocks(String text) {
  final out = <DirectionBlock>[];
  bool? dir;
  final held = <String>[];

  void close() {
    if (held.isEmpty) return;
    out.add(DirectionBlock(dir ?? false, held.join('\n')));
    held.clear();
  }

  for (final line in text.split('\n')) {
    final here = paragraphDirection(line);
    if (here != null && dir != null && here != dir) {
      close();
      dir = here;
    } else {
      dir ??= here;
    }
    held.add(line);
  }
  close();
  return out;
}

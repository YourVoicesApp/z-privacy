// The line-number gutter down the left of the document — 046/Q's gesture.
//
// **Lines are selected here; words are selected in the text.** The lead's
// decision of 7 October, and the reason it is a gutter rather than a mode: the
// text's own behaviour is 041-K's and must not change, so a drag across words
// still takes whole words and a press on a mark still asks its question. A
// second gesture living in the same pixels would have needed a modifier key or
// a mode switch, and both are things a person has to be told about.
//
// It also answers something the owner has asked for twice in other words: he
// can see where he is in a long document.
//
// Nothing here counts findings. The three numbers a selection is worth —
// «8 lines · 25 protected in them · 0 open» — come from `line_selection` in
// Rust, because they are facts about findings and a screen that worked them
// out itself would be a second source for a number the core already holds.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:zprivacy/core/palette.dart';

/// Where each logical line of `text` begins, in UTF-16 code units.
///
/// Logical and not visual: a line that wraps over three rows of the screen is
/// still one line of the document, and it is the document's lines the owner
/// counts. The last entry is the line after a trailing newline — an empty line
/// a person can still see and select, so it is one.
List<int> lineStarts(String text) {
  final out = <int>[0];
  for (var at = 0; at < text.length; at++) {
    if (text.codeUnitAt(at) == 0x0a) out.add(at + 1);
  }
  return out;
}

/// Which logical line an offset falls on, counting from zero.
///
/// One implementation, read by the press that decides whether it is inside the
/// held lines and by the card that offers the act for them. Two places that can
/// disagree about the same fact is one place already wrong.
int lineOfOffset(String text, int offset) {
  final starts = lineStarts(text);
  for (var i = starts.length - 1; i >= 0; i--) {
    if (offset >= starts[i]) return i;
  }
  return 0;
}

/// Where every logical line of the drawn text sits, and how tall the whole of
/// it is.
class GutterLayout {
  const GutterLayout({required this.tops, required this.height});

  /// The top of each logical line, in the same order as `lineStarts`.
  final List<double> tops;

  /// The height the text laid out to, so the gutter is exactly as tall.
  final double height;

  int get lines => tops.length;

  /// Which line a point `dy` down the gutter falls on.
  ///
  /// Clamped at both ends on purpose: a press in the padding under the last
  /// line means the last line, and there is no «line −1».
  int lineAt(double dy) {
    for (var i = tops.length - 1; i >= 0; i--) {
      if (dy >= tops[i]) return i;
    }
    return 0;
  }

  /// How tall line `i` is on screen — one row, or three if it wrapped.
  double heightOf(int i) {
    final next = i + 1 < tops.length ? tops[i + 1] : height;
    final tall = next - tops[i];
    return tall > 0 ? tall : 0;
  }
}

/// The lines **as the text is actually laid out**, read from the render object
/// that draws it.
///
/// Not measured again with a `TextPainter` of our own, and this is not a
/// preference — it is a defect this file was written with and caught the same
/// hour. A painter given the very same spans and the very same width laid the
/// owner's wrapping sheet out **325 pixels tall where the screen drew it 400**,
/// because `RenderEditable` lays its text out at `maxWidth` **minus a caret
/// margin** of three pixels (`_kCaretGap + cursorWidth`, both private to
/// Flutter). Three pixels moved a word to the next row, four rows became
/// seven, and a press meant for an account number protected the invoice
/// reference at the other end of the line — in three rows at once.
///
/// So there is one source of geometry here and it is the drawing. The constant
/// is Flutter's and private; the layout is ours to read.
GutterLayout linesOf(RenderEditable drawn, String text) {
  final starts = lineStarts(text);
  final tops = <double>[];
  for (final start in starts) {
    tops.add(
      drawn.getLocalRectForCaret(TextPosition(offset: start.clamp(0, text.length))).top,
    );
  }
  return GutterLayout(tops: tops, height: drawn.size.height);
}

/// Where the gutter gets the layout from, each time it needs it — null before
/// the text has been laid out once.
typedef LinesNow = GutterLayout? Function();

/// The numbers, and the press that takes a line or drags a range.
///
/// Painted rather than built as widgets: 048 measured documents of 5 770 and
/// 82 468 lines on this machine, and 82 468 `Text` widgets inside a scroll view
/// is not a gutter, it is a hang. The painter draws only the numbers inside the
/// canvas's clip, so a long document costs what a short one costs.
class LineGutter extends StatefulWidget {
  const LineGutter({
    super.key,
    required this.lines,
    required this.from,
    required this.to,
    required this.onRange,
  });

  final LinesNow lines;

  /// The lines selected now, from zero, or null for none.
  final int? from;
  final int? to;

  /// A press reports one line as both ends; a drag reports where it began and
  /// where it is now.
  final void Function(int from, int to) onRange;

  /// So a test can find the gutter itself rather than something inside it.
  static const gutter = ValueKey<String>('document-line-gutter');

  /// Wide enough for five digits, which is wider than any document 048
  /// measured. A gutter that resized itself as you scrolled would move the
  /// text under the reader's eye.
  static const width = 46.0;

  @override
  State<LineGutter> createState() => _LineGutterState();
}

class _LineGutterState extends State<LineGutter> {
  /// Where a drag began, so the range grows from the line first pressed and
  /// not from the one the pointer is over.
  int? _anchor;

  /// The layout at the moment a gesture happens, which is always after a
  /// layout — so this is never null in practice and is not guessed at when it
  /// is.
  GutterLayout? get _lay => widget.lines();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // **The drag begins where the finger went down.** Measured, 7 October: a
      // drag from line 1 to line 4 held lines **2** to 4. Flutter's default is
      // `DragStartBehavior.start`, which reports the point at which the drag
      // was *recognised* — twenty pixels past the press, which on a 25-pixel
      // line is the next one. A person who presses line 1 and pulls down to
      // line 4 means four lines, and losing the first of them is the
      // off-by-one family this project keeps finding.
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: (down) {
        final line = _lay?.lineAt(down.localPosition.dy);
        if (line == null) return;
        _anchor = line;
        widget.onRange(line, line);
      },
      onVerticalDragStart: (drag) {
        final line = _lay?.lineAt(drag.localPosition.dy);
        if (line == null) return;
        _anchor = line;
        widget.onRange(line, line);
      },
      onVerticalDragUpdate: (drag) {
        final line = _lay?.lineAt(drag.localPosition.dy);
        if (line == null) return;
        widget.onRange(_anchor ?? line, line);
      },
      // **No height here.** The gutter is stretched to the document's own
      // height by the `Stack` it is positioned in, so its box can never
      // disagree with the text beside it about how tall the document is.
      child: SizedBox(
        width: LineGutter.width,
        child: CustomPaint(
          painter: GutterPainter(
            lines: widget.lines,
            from: widget.from,
            to: widget.to,
            direction: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

/// Public so that «a long document costs what a short one costs» is a measured
/// number and not a claim: the test paints 5 000 lines into a 600-pixel clip
/// and reads `drawn`.
class GutterPainter extends CustomPainter {
  GutterPainter({
    required this.lines,
    required this.from,
    required this.to,
    required this.direction,
  });

  final LinesNow lines;
  final int? from;
  final int? to;
  final TextDirection direction;

  /// How many numbers the last paint drew, and how many lines it skipped.
  ///
  /// Read by the test that measures the clip, so that «a long document costs
  /// what a short one costs» is a number and not a claim.
  int drawn = 0;

  @override
  void paint(Canvas canvas, Size size) {
    drawn = 0;
    final layout = lines();
    if (layout == null) return;
    final clip = canvas.getLocalClipBounds();
    final lo = from == null ? -1 : (from! < to! ? from! : to!);
    final hi = from == null ? -2 : (from! < to! ? to! : from!);
    final wash = Paint()..color = Zc.clayWash;
    for (var i = 0; i < layout.lines; i++) {
      final top = layout.tops[i];
      final tall = layout.heightOf(i);
      // Only what is on screen. `getLocalClipBounds` is the viewport's own
      // rectangle when this sits inside one that clips, which the Original
      // column's scroll view does.
      if (top + tall < clip.top || top > clip.bottom) continue;
      final held = i >= lo && i <= hi;
      if (held) {
        canvas.drawRect(Rect.fromLTWH(0, top, size.width - 5, tall), wash);
      }
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: Zc.tiny.copyWith(
            color: held ? Zc.clayDeep : Zc.ink4,
            fontWeight: held ? FontWeight.w600 : null,
            letterSpacing: 0,
          ),
        ),
        textDirection: direction,
      )..layout();
      label.paint(canvas, Offset(size.width - 13 - label.width, top + 2));
      label.dispose();
      drawn += 1;
    }
    canvas.drawLine(
      Offset(size.width - 4, clip.top),
      Offset(size.width - 4, clip.bottom),
      Paint()
        ..color = Zc.lineSoft
        ..strokeWidth = 1,
    );
  }

  /// Always. The layout is read at paint time rather than carried here, so
  /// there is nothing to compare it against — and a paint costs only the
  /// numbers inside the clip, which is a windowful whatever the document's
  /// length.
  @override
  bool shouldRepaint(GutterPainter old) => true;
}

/// **Take every line** — the control at the head of the gutter.
///
/// It says the count, because the owner's own sentence asks for it: «في حال
/// تحديد الكل نحسب كم سطر في النص» — when all of it is taken, we say how many
/// lines the text has. The number is here before the press, not after it.
class AllLinesBand extends StatelessWidget {
  const AllLinesBand({super.key, required this.lines, required this.onPressed});

  final int lines;
  final VoidCallback onPressed;

  /// So a test can reach it without matching on wording.
  static const control = ValueKey<String>('document-all-lines');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: AllLinesBand.control,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.format_line_spacing, size: 13, color: Zc.ink4),
              const SizedBox(width: 6),
              Text(
                lines == 1 ? 'All 1 line' : 'All $lines lines',
                style: Zc.tiny.copyWith(letterSpacing: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

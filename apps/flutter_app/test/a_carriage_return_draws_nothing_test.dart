// 074/W8 — a carriage return on the glass: measured, and the fix dropped.
//
// ## Why this file exists instead of a fix
//
// 074's desk audit measured that a `\r` from a CRLF document is carried through
// the core into the document's own text, and then said one sentence more than
// it had measured: that the `\r` «reaches the chat, the review sheet and the
// saved PDF's embedded font, where no glyph answers U+000D». W8 was the debt
// that would have stripped it when drawing.
//
// Both halves of that sentence have now been measured, and W8 is not built:
//
//   * **in the PDF** — the programmer's probe of 9 October reported the same
//     document written with `\r\n` and with `\n` as byte-identical files. It
//     is one step stronger than that is true: `pdf` writes a random `/ID` into
//     every file it makes, so **no** two PDFs this product writes are identical
//     byte for byte, including two of the same document. What is identical is
//     every other byte — measured here uncompressed, where the page is written
//     out in the clear, so the claim is about the content and not about what a
//     compressor happened to do with it. Pinned in the last group, so the drop
//     stays true by measurement and not by our memory of having made one.
//   * **on the glass** — the lead's order was that the screen half be decided
//     «on the glass, not in the code». It is: a CRLF document is drawn in the
//     widgets the product draws it with, and the pixels are compared with the
//     LF twin's.
//
// ## What the glass said
//
// **Read, nothing differs.** Five surfaces, two drawings each, identical pixel
// for pixel. No box, no gap, no row out of place, and every line sits at the
// same y in both twins — which is the part the gutter's numbers are drawn
// against.
//
// **Selected, something does.** The carriage return is invisible *and*
// **8.95 px wide** at the document's own 14.5 px (0.62 em — DejaVu's `.notdef`
// advance, with no ink). Nobody sees an empty 9 px. A person who selects the
// text does: the highlight behind every line runs 9 px past its last letter,
// and where the `\r`'s box and the `\n`'s box overlap it is drawn twice and
// comes out darker. That is the whole of the finding, it is in the editable
// surfaces only, and it is pinned below rather than fixed — see that group's
// comment for why the obvious fix is the harmful one.
//
// ## What «on the glass» means here, and what it does not
//
// Real engine, real widgets, real font: the drawing is Flutter's own text stack
// in the software renderer `flutter test` uses, the subjects are the widgets the
// product builds — each named with the file and line it stands for — and the
// font is `assets/fonts/DejaVuSans.ttf`, the one this repository ships and the
// PDF embeds. It carries **no glyph for U+000D** (`fc-query`, 9 Oct), so if the
// engine asked the font for one it would draw `.notdef`, which in DejaVu is a
// box. The test font `flutter_test` installs by default would have made that
// measurement meaningless — it draws every glyph as a rectangle of one width —
// so the first control below proves a real font is in place before any claim
// rests on a pixel.
//
// What it is not: a compositor, a window manager, a scroll with a mouse, and
// not the fonts the owner's desktop resolves for a family the product does not
// name. Those were measured by hand the same day rather than asserted here —
// Noto Sans (what `fc-match sans-serif` answers on that machine) and DejaVu
// Sans Mono (`monospace`) carry no U+000D glyph either, so no font in play can
// draw one.
//
// ## The instrument before the subject
//
// Four controls, each a break watched to go red rather than an argument: a real
// font is loaded, an ordinary extra letter changes the pixels, a codepoint the
// font has no glyph for changes the pixels, and one more newline changes the
// geometry. Without them, «the two drawings are identical» is a sentence two
// blank canvases would also satisfy — the family named in
// `a_guard_green_for_the_wrong_reason`.
//
// Needs no native library and no built bundle, on purpose: a guard that only
// runs where someone has already run `flutter build linux --debug` is a guard
// that does not run.
//
//   Z_W8_DUMP=/some/dir flutter test test/a_carriage_return_draws_nothing_test.dart
//
// writes every drawing it makes to that folder as a PNG, which is how this
// round was looked at rather than merely asserted about.
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show FontLoader, LogicalKeyboardKey, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/protected_pdf.dart';
import 'package:zprivacy/main.dart' show zTheme;
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/line_gutter.dart';

import 'drawn_document.dart';

/// The family the probe draws in. Not a product decision: the product names no
/// family for document text and the desktop answers one. This names the font
/// the repository ships, so the measurement is the same on every machine.
const _family = 'W8-DejaVuSans';

const _shot = ValueKey<String>('w8-shot');

/// A payroll sheet in the shape the owner's own are in — columns separated by
/// runs of spaces, an account number, an amount. A trailing newline, because
/// the line after one is a line a person can still see.
const _lf =
    'staff              account no.    gross\n'
    'Hedvig Palmgren    9999 000 01    42 500\n'
    'Tobias Nyqvist     9999 000 02    34 800\n';

/// The same document as a Windows text editor writes it. `\r\n` and not a lone
/// `\r`: this is the shape the core measured arriving, and it puts the
/// character no font has a glyph for at the end of every line.
final _crlf = _lf.replaceAll('\n', '\r\n');

/// A word every twin holds, for `drawnDocument` to find the right editable by.
const _marker = 'Hedvig';

// ---------------------------------------------------------------- the subjects
//
// Five, and they are five **drawings** rather than five screens: the shape each
// surface draws document text with, named with where it stands.
final Map<String, Widget Function(String)> _subjects = {
  // The document column, with the gutter on — the one place where a shifted row
  // would leave a line number beside the wrong line.
  'the document column · document_text.dart:57': (t) => OriginalText(
    text: t,
    marks: const [],
    heldLines: null,
    onLines: (_, _) {},
  ),
  // The payload column beside it.
  'the payload column · document_text.dart:531': (t) => SafeText(text: t),
  // The review sheet's sentence around a finding. `_sentence` is private, so
  // this is its shape: the slice it hands over ends with the line's own
  // terminator, which in a CRLF document is `\r\n`.
  'the review sheet · review.dart:637': (t) => Text.rich(
    TextSpan(children: [TextSpan(text: t)]),
    style: Zc.document.copyWith(fontSize: 13.5),
  ),
  // The answer screen's restored text.
  'the restored text · answer.dart:376': (t) =>
      SelectableText(t, style: Zc.document),
  // The chat's composer — the field whose hint is «Write or paste your text
  // here…», which is how a CRLF letter reaches the chat at all. No `autofocus`
  // here, unlike the product: a blinking caret is not a property of the text,
  // and it would make two drawings of one string differ.
  'the chat composer · home.dart:473': (t) => TextField(
    controller: TextEditingController(text: t),
    minLines: 3,
    maxLines: 8,
    style: Zc.document.copyWith(fontSize: 14),
    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
  ),
};

/// The subject the controls are measured in: the document column, because it
/// carries the gutter's geometry as well as the text.
Widget Function(String) get _control => _subjects.values.first;

// ------------------------------------------------------------- the instruments

Widget _fixed(Widget subject) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(fontFamily: _family),
  home: Scaffold(
    backgroundColor: Zc.paper,
    body: Center(
      child: RepaintBoundary(
        key: _shot,
        // **The page is painted inside the boundary**, and that is not tidying.
        // A `RepaintBoundary` captures what is inside it and nothing behind it,
        // so without this the canvas is transparent and every translucent layer
        // comes back as accumulated alpha for a viewer to composite later. Two
        // overlapping layers then *look* darker in the PNG while being nothing
        // of the sort on a page. That mistake was made in this very file on
        // 9 Oct and corrected by measuring again with the page under the
        // drawing: a colour claim without an opaque ground is not a claim about
        // what anybody sees.
        child: ColoredBox(
          color: Zc.paper,
          // One box for every drawing, so that two of them can be compared.
          child: SizedBox(width: 460, height: 300, child: subject),
        ),
      ),
    ),
  ),
);

/// Pump without `pumpAndSettle`: an editable on the screen has a caret that
/// never stops blinking, and settling waits for an animation that never ends.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

/// What the renderer actually put on the canvas, as raw RGBA.
Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shot),
  );
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final data = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  image!.dispose();
  return data!.buffer.asUint8List();
}

String? get _dumpDir => Platform.environment['Z_W8_DUMP'];

Future<void> _dump(WidgetTester tester, String name) async {
  final dir = _dumpDir;
  if (dir == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shot),
  );
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final png = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  image!.dispose();
  Directory(dir).createSync(recursive: true);
  File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

/// One drawing, and everything read back **off the drawing** — never measured
/// again with a painter of our own, which is the defect `linesOf` was written
/// against.
class _Drawn {
  _Drawn(this.pixels, this.size, this.tops);
  final Uint8List pixels;
  final Size size;
  final List<double> tops;

  String get shape =>
      '${size.width.toStringAsFixed(1)}×${size.height.toStringAsFixed(1)}, '
      'rows at ${tops.map((t) => t.toStringAsFixed(1)).join(' ')}';
}

Future<_Drawn> _draw(
  WidgetTester tester,
  Widget Function(String) build,
  String text, {
  String? dumpAs,
}) async {
  await tester.pumpWidget(_fixed(build(text)));
  await _settle(tester);
  final pixels = await _pixels(tester);
  if (dumpAs != null) await _dump(tester, dumpAs);

  final starts = lineStarts(text);
  if (find.byType(EditableText).evaluate().isNotEmpty) {
    final drawn = drawnDocument(tester, _marker);
    return _Drawn(pixels, drawn.size, linesOf(drawn, text).tops);
  }
  final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
  return _Drawn(pixels, paragraph.size, [
    for (final at in starts)
      paragraph
          .getOffsetForCaret(
            TextPosition(offset: at.clamp(0, text.length)),
            Rect.zero,
          )
          .dy,
  ]);
}

/// The width a string takes in the probe's own font and style, shrink-wrapped.
Future<double> _width(WidgetTester tester, String text) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: _family),
      home: Scaffold(
        body: Center(child: Text(text, style: Zc.document)),
      ),
    ),
  );
  await _settle(tester);
  return tester.renderObject<RenderBox>(find.byType(RichText)).size.width;
}

/// A drawing in the product's **own** theme, on its own page.
///
/// The read group above compares shapes and may use any theme; a claim about a
/// colour may not. `zTheme()` carries the selection colour this product chose
/// and measured — `Zc.river` at alpha 0.40 (`main.dart:42`) — and the whole of
/// the finding below is what happens when a translucent colour is painted more
/// than once.
Widget _onPaper(Widget subject) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: zTheme(),
  home: Scaffold(
    backgroundColor: Zc.paper,
    body: Center(
      child: RepaintBoundary(
        key: _shot,
        child: ColoredBox(
          color: Zc.paper,
          child: SizedBox(
            width: 460,
            height: 300,
            child: DefaultTextStyle(
              style: const TextStyle(fontFamily: _family),
              child: subject,
            ),
          ),
        ),
      ),
    ),
  ),
);

/// Select the whole text the way a person can — focus it and press Ctrl+A.
///
/// A gesture and not a controller, because the columns are `SelectableText`s
/// and a `SelectableText` has no selection to set. The caller checks what was
/// actually selected: «nothing was painted twice» is also what an empty
/// selection says.
Future<TextSelection> _selectAll(WidgetTester tester) async {
  await tester.tap(find.byType(EditableText).first);
  await tester.pump();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
  return tester
      .state<EditableTextState>(find.byType(EditableText).first)
      .textEditingValue
      .selection;
}

/// What a layer of `top` leaves over `under`.
///
/// **Derived from the theme, never restated.** The one-layer and two-layer
/// colours below are computed from the product's own selection colour, so a
/// day when that colour changes is a day this guard follows it rather than a
/// day it starts measuring a colour nobody uses.
Color _over(Color top, Color under) => Color.fromARGB(
  255,
  ((top.r * top.a + under.r * (1 - top.a)) * 255).round(),
  ((top.g * top.a + under.g * (1 - top.a)) * 255).round(),
  ((top.b * top.a + under.b * (1 - top.a)) * 255).round(),
);

/// How many pixels of the canvas carry (near enough) this colour.
int _pixelsOf(Uint8List rgba, Color want) {
  final wr = (want.r * 255).round();
  final wg = (want.g * 255).round();
  final wb = (want.b * 255).round();
  var found = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if ((rgba[i] - wr).abs() < 6 &&
        (rgba[i + 1] - wg).abs() < 6 &&
        (rgba[i + 2] - wb).abs() < 6) {
      found++;
    }
  }
  return found;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    await (FontLoader(_family)..addFont(Future<ByteData>.value(bytes))).load();
  });

  group('the instrument, before any claim rests on a pixel', () {
    testWidgets('a real font is drawing, not the test font', (tester) async {
      final wide = await _width(tester, 'WWWW');
      final narrow = await _width(tester, 'iiii');
      // `flutter_test`'s own font gives every glyph the same advance, so these
      // two would be equal under it and every «no box was drawn» below would be
      // a claim about nothing.
      expect(
        wide,
        greaterThan(narrow * 1.5),
        reason:
            'WWWW drew $wide wide and iiii $narrow — equal widths mean the test '
            'font is still in place and this file proves nothing',
      );
    });

    testWidgets('the comparison sees one ordinary letter', (tester) async {
      final plain = await _draw(tester, _control, _lf);
      final extra = await _draw(
        tester,
        _control,
        _lf.replaceFirst('Hedvig', 'Hedvigg'),
      );
      expect(
        plain.pixels,
        isNot(extra.pixels),
        reason:
            'one more letter changed no pixel, so nothing here is comparing a drawing',
      );
    });

    testWidgets('the comparison sees a codepoint the font has no glyph for', (
      tester,
    ) async {
      // U+E000, the first private-use codepoint: DejaVu has no glyph for it,
      // exactly as it has none for U+000D. This is the control the whole
      // question rests on — it is what «a missing glyph would have shown» looks
      // like, and its PNG is dumped so it can be looked at.
      final plain = await _draw(tester, _control, _lf);
      final tofu = await _draw(
        tester,
        _control,
        _lf.replaceFirst('Hedvig', 'Hedvig\u{E000}'),
        dumpAs: 'control-a-glyph-the-font-lacks',
      );
      expect(
        plain.pixels,
        isNot(tofu.pixels),
        reason:
            'a codepoint with no glyph changed nothing on the canvas, so a `\\r` '
            'drawn as .notdef would not have been seen either',
      );
    });

    testWidgets('the geometry sees one more row', (tester) async {
      final plain = await _draw(tester, _control, _lf);
      final taller = await _draw(
        tester,
        _control,
        _lf.replaceFirst('gross\n', 'gross\n\n'),
      );
      expect(
        taller.tops.length,
        plain.tops.length + 1,
        reason: 'an added newline did not add a line',
      );
      expect(
        taller.tops,
        isNot(plain.tops),
        reason:
            'an added newline moved no row, so the geometry read here is not the '
            'drawing\'s',
      );
    });
  });

  group('read, a CRLF document is drawn as its LF twin is', () {
    for (final entry in _subjects.entries) {
      testWidgets(entry.key, (tester) async {
        final name = entry.key.split(' · ').first.replaceAll(' ', '-');
        final lf = await _draw(tester, entry.value, _lf, dumpAs: 'lf-$name');
        final crlf = await _draw(
          tester,
          entry.value,
          _crlf,
          dumpAs: 'crlf-$name',
        );

        // **This surface's own control.** The instrument group proves the
        // comparison can see a letter, and proves it in one subject. Two
        // drawings of a surface that draws nothing at all are identical too,
        // so each one is asked here to put its own text on the canvas.
        final nudged = await _draw(
          tester,
          entry.value,
          _lf.replaceFirst('Hedvig', 'Hedvigg'),
        );
        expect(
          nudged.pixels,
          isNot(lf.pixels),
          reason:
              'this surface drew two different documents the same way, so '
              '«identical» below would be a statement about an empty box',
        );

        expect(
          crlf.tops.length,
          lf.tops.length,
          reason:
              'the document has the same lines in both twins, and CRLF drew '
              '${crlf.tops.length} against ${lf.tops.length}',
        );
        expect(
          crlf.tops,
          lf.tops,
          reason:
              'a line moved: CRLF is ${crlf.shape} and LF is ${lf.shape}. The '
              'gutter draws its numbers against these tops, so a shift here is a '
              'number beside the wrong line',
        );
        expect(
          crlf.size.height,
          lf.size.height,
          reason:
              'the text laid out to a different height: CRLF ${crlf.shape} against '
              'LF ${lf.shape}',
        );
        // The **width** is deliberately not asserted here. It differs, by one
        // invisible advance per line, and that is the subject of the pin below
        // rather than a fault in what a person reads.
        expect(
          crlf.pixels,
          lf.pixels,
          reason:
              'the two drawings differ pixel for pixel, which is what a box drawn '
              'for U+000D would look like — the PNGs are in Z_W8_DUMP',
        );
      });
    }
  });

  // ------------------------------------------------------------ what was pinned
  //
  // **These were pins, and the fix flipped them. Both halves are kept.**
  //
  // What they recorded, 9–10 Oct: `RenderEditable`'s selection painter takes
  // `getBoxesForSelection(...).toSet()` and draws **one translucent rect per
  // box** (`rendering/editable.dart:2914`). `toSet()` removes only boxes that
  // are *identical*, and a selected carriage return makes the engine hand it
  // an aggregate box for the line's tail **and** the two parts inside it. At
  // alpha 0.40 the tail was therefore filled two and three times and came out
  // as a darker block at the end of every line: **8 582 pixels** of the
  // twice-painted colour in the document column, and the same 8 582 in the
  // payload column beside it, where the LF twin had none.
  //
  // What changed: the owner chose, after two pictures, to **merge the boxes
  // before they are filled** — the opaque colour was refused because the page
  // rule dissolves under it, and leaving it was refused. `paintedOnce` does
  // the arithmetic and `PaintSelectionOnce` draws it, in both columns.
  //
  // So these now assert **zero**, and the number they came from is above. The
  // one below them that did *not* flip is the cause, and it is deliberate.
  group('the selection is painted once', () {
    /// The product's own two colours, derived from the theme and never
    /// restated: one layer of the selection over the page, and two.
    (Color once, Color twice) colours() {
      final selection = zTheme().textSelectionTheme.selectionColor!;
      final once = _over(selection, Zc.paper);
      return (once, _over(selection, once));
    }

    Future<({int once, int twice, TextSelection sel})> drawSelected(
      WidgetTester tester,
      Widget column,
      String text,
      String? dumpAs,
    ) async {
      final (onceColour, twiceColour) = colours();
      await tester.pumpWidget(_onPaper(column));
      await _settle(tester);
      final sel = await _selectAll(tester);
      final pixels = await _pixels(tester);
      if (dumpAs != null) await _dump(tester, dumpAs);
      return (
        once: _pixelsOf(pixels, onceColour),
        twice: _pixelsOf(pixels, twiceColour),
        sel: sel,
      );
    }

    testWidgets('the document column, on its own page, in its own colours', (
      tester,
    ) async {
      final lf = await drawSelected(
        tester,
        OriginalText(text: _lf, marks: const [], onLines: (_, _) {}),
        _lf,
        'once-column-lf',
      );
      final crlf = await drawSelected(
        tester,
        OriginalText(text: _crlf, marks: const [], onLines: (_, _) {}),
        _crlf,
        'once-column-crlf',
      );

      // The two controls the old pin carried, unchanged: a count of nothing is
      // what an empty selection and a page with no selection on it both report.
      expect(
        [lf.sel.end, crlf.sel.end],
        [_lf.length, _crlf.length],
        reason:
            'Ctrl+A did not take the whole text (${lf.sel}, ${crlf.sel}), '
            'so neither count below is about a selected document',
      );
      expect(
        [lf.once, crlf.once],
        everyElement(greaterThan(1000)),
        reason:
            'the selection colour is barely on the page (${lf.once} and '
            '${crlf.once} pixels), so a second layer of it would be counted '
            'against nothing',
      );

      expect(
        crlf.twice,
        0,
        reason:
            'the tail is painted ${crlf.twice} pixels twice again — it was '
            '8 582 before `paintedOnce`, and the merging has stopped working',
      );
      expect(
        lf.twice,
        0,
        reason:
            'the LF twin has begun doubling, which it '
            'never did even before the fix',
      );
    });

    testWidgets('and the payload column beside it', (tester) async {
      // **Not symmetry — measurement.** This column was never measured for its
      // selection until 12 Oct, and it doubled by the same 8 582 pixels. The
      // two columns are read side by side and that comparison *is* the
      // product, so a fix on one of them would have been half a fix on the
      // screen a person is actually looking at.
      final lf = await drawSelected(tester, SafeText(text: _lf), _lf, null);
      final crlf = await drawSelected(
        tester,
        SafeText(text: _crlf),
        _crlf,
        null,
      );
      expect(crlf.sel.end, _crlf.length);
      expect([lf.once, crlf.once], everyElement(greaterThan(1000)));
      expect(
        crlf.twice,
        0,
        reason:
            'the payload column paints ${crlf.twice} pixels twice; it was '
            '8 582 before the fix reached this column too',
      );
      expect(lf.twice, 0);
    });

    testWidgets('the cause is still in the engine, and that is why the code is '
        'there', (tester) async {
      // **This one did not flip, on purpose.** The merging happens in our
      // drawing; the engine still hands us the overlapping boxes it always
      // did. The day this goes green — no overlapping pair in a selected CRLF
      // document — is the day `paintedOnce` can be deleted, and nobody will
      // know that unless it is asserted here.
      Future<List<Rect>> boxes(String text) async {
        await tester.pumpWidget(_fixed(_control(text)));
        await _settle(tester);
        final drawn = drawnDocument(tester, _marker);
        return drawn
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.length),
            )
            .map((b) => b.toRect())
            .toList();
      }

      int overlaps(List<Rect> rects) {
        var found = 0;
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            if ((rects[i].top - rects[j].top).abs() < 1 &&
                rects[i].right - rects[j].left > 0.5 &&
                rects[j].right - rects[i].left > 0.5) {
              found++;
            }
          }
        }
        return found;
      }

      final lf = await boxes(_lf);
      final crlf = await boxes(_crlf);
      expect(lf, isNotEmpty);
      expect(
        overlaps(lf),
        0,
        reason:
            'the LF twin is handed ${overlaps(lf)} overlapping pairs, so '
            'overlap is not what distinguishes a CRLF document after all',
      );
      expect(
        overlaps(crlf),
        greaterThan(0),
        reason:
            'the engine no longer overlaps its boxes for a selected carriage '
            'return — `paintedOnce` and `PaintSelectionOnce` have nothing left '
            'to do and should be removed with this test',
      );
    });

    testWidgets('the chat composer is still clear of it, by one setting', (
      tester,
    ) async {
      // Untouched by the fix and still recorded: the composer paints nothing
      // twice at the default `BoxWidthStyle.tight`, and 1 485 pixels twice at
      // `.max`. Anyone reaching for `.max` would be re-opening the defect on
      // the one surface that never had it.
      final (_, twice) = colours();

      Future<int> composer(ui.BoxWidthStyle style) async {
        final controller = TextEditingController(
          text: _crlf,
        )..selection = TextSelection(baseOffset: 0, extentOffset: _crlf.length);
        final focus = FocusNode();
        await tester.pumpWidget(
          _onPaper(
            TextField(
              controller: controller,
              focusNode: focus,
              minLines: 3,
              maxLines: 8,
              selectionWidthStyle: style,
              style: Zc.document.copyWith(fontSize: 14, fontFamily: _family),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        );
        focus.requestFocus();
        await _settle(tester);
        return _pixelsOf(await _pixels(tester), twice);
      }

      expect(
        await composer(ui.BoxWidthStyle.tight),
        0,
        reason: 'the composer has begun painting its tail twice as well',
      );
      expect(
        await composer(ui.BoxWidthStyle.max),
        greaterThan(0),
        reason:
            'the width style no longer decides it, so the warning this records '
            'is out of date',
      );
    });
  });

  group('and what the selection must not hide', () {
    // **Two guards at the altitude the decision was made at, after two that
    // were green for the wrong reason.**
    //
    // The owner refused the opaque selection colour because the page rule
    // dissolves under it. Guarding that *in pixels* was tried twice and
    // failed twice, and both failures were found by breaking rather than by
    // reading: the first compared a document holding a form feed with one
    // that did not, and passed with an opaque selection because the two
    // differ wherever the rule falls outside the selected band; the second
    // counted «the rule's colour seen through the selection» and passed with
    // an opaque selection too — `Zc.line` under the selection and the plain
    // selection over the page are ten units apart, and a page is full of
    // seams and antialiasing that land in between. **A guard that cannot tell
    // the refused option from the chosen one is not a guard.**
    //
    // So the rule is asserted where it was decided — on the colour, and on
    // the order of painting — and the picture in the paper carries the rest.
    testWidgets('the selection colour stays translucent', (tester) async {
      // The owner's ruling itself. An opaque selection hides whatever is
      // painted behind the text — the page rules are, and that is the whole
      // reason candidate two was refused after he was shown it.
      final selection = zTheme().textSelectionTheme.selectionColor!;
      expect(
        selection.a,
        lessThan(1.0),
        reason:
            'the selection colour is opaque (alpha ${selection.a}), so '
            'everything painted behind the text — the page rules above all — '
            'is hidden wherever a person selects. That is the option the '
            'owner refused on 10 Oct, with the picture in front of him',
      );
    });

    // **And the paint order is guarded, though not from here.** A fourth
    // attempt lived here: count the glyphs' own ink with a selection live, on
    // the theory that rectangles painted in front would tint it. Broken on
    // purpose — the rectangles moved above the text — and it **did not bite**,
    // so it was deleted rather than shipped. The same break reds both
    // «painted once» guards above, because rectangles in front of the words
    // are rectangles that no longer merge with what is behind them. That is
    // where the layering is held, and it was measured, not assumed.
  });

  // --------------------------------------------------------------------- ruled
  //
  // 074/W8, measured on the night of 9 October: the fix was dropped because the
  // fault is not there. **This group keeps the drop honest.** The identity holds
  // for today's `pdf` package and today's line breaker and nothing else holds it
  // for tomorrow — the day either changes, this reddens by itself instead of the
  // closure resting on our memory of a measurement.
  group('the PDF a CRLF document writes is the PDF its LF twin writes', () {
    // Every export ends with its answer page (079), so every one of these
    // carries the same token for it: the two files compared differ only in
    // what is being compared.
    const answer = '__Z_0000_CUSTOM_00000000__';
    PdfStamp stamp() => PdfStamp(
      build: 'z_core 0.0.0 · 0000-00-00 · W8',
      places: 0,
      byKind: const <String, int>{},
      sha256: '0' * 64,
    );

    test(
      'the control: the same document twice is one file but for its id',
      () async {
        // **Before the subject, the instrument.** Without this, «the two files
        // are the same» would also be what a writer that ignores its text says,
        // and «they differ» would also be what the random id says on its own.
        final once = await buildProtectedPdf(
          text: _lf,
          stamp: stamp(),
        answerToken: answer,
          compress: false,
        );
        final twice = await buildProtectedPdf(
          text: _lf,
          stamp: stamp(),
        answerToken: answer,
          compress: false,
        );
        expect(
          twice,
          isNot(once),
          reason:
              'two files of one document came out equal byte for byte, so the '
              'random id is gone and the treatment below is doing nothing',
        );
        expect(
          _withoutTheDocumentId(twice),
          _withoutTheDocumentId(once),
          reason:
              'the same document written twice differs somewhere other than its '
              'id, so nothing below can be concluded about a carriage return',
        );
      },
    );

    test(
      'uncompressed, the carriage return reaches no byte of the page',
      () async {
        // Uncompressed on purpose: here the page is written out in the clear, so
        // this is a statement about the content rather than about what a
        // compressor made of it.
        final lf = await buildProtectedPdf(
          text: _lf,
          stamp: stamp(),
        answerToken: answer,
          compress: false,
        );
        final crlf = await buildProtectedPdf(
          text: _crlf,
          stamp: stamp(),
        answerToken: answer,
          compress: false,
        );
        expect(
          lf.length,
          greaterThan(1000),
          reason: 'an empty file is not a PDF',
        );
        expect(
          String.fromCharCodes(lf.take(5)),
          '%PDF-',
          reason:
              'whatever these bytes are, two of them being equal says nothing',
        );
        expect(
          _withoutTheDocumentId(crlf),
          _withoutTheDocumentId(lf),
          reason:
              'the carriage return reached the file: ${crlf.length} bytes against '
              '${lf.length}. W8 was dropped on these two being one document',
        );
      },
    );

    test('and at the setting the product actually writes with', () async {
      final lf = await buildProtectedPdf(text: _lf, stamp: stamp(), answerToken: answer);
      final crlf = await buildProtectedPdf(text: _crlf, stamp: stamp(), answerToken: answer);
      expect(
        _withoutTheDocumentId(crlf),
        _withoutTheDocumentId(lf),
        reason:
            'compressed — which is what «Save as PDF» writes — the two '
            'documents are no longer one file',
      );
    });

    test('the control: one ordinary letter does reach the file', () async {
      final plain = await buildProtectedPdf(
        text: _lf,
        stamp: stamp(),
        answerToken: answer,
        compress: false,
      );
      final changed = await buildProtectedPdf(
        text: _lf.replaceFirst('Hedvig', 'Hedvigg'),
        stamp: stamp(),
        answerToken: answer,
        compress: false,
      );
      expect(
        _withoutTheDocumentId(changed),
        isNot(_withoutTheDocumentId(plain)),
        reason:
            'a letter changed in the document changed no byte of the PDF, so '
            'the identity above is a property of the writer and not of the '
            'carriage return',
      );
    });
  });
}

/// `/ID[<…><…>]`, the one thing in a PDF of ours that is not the document.
///
/// `pdf` 3.13.1 builds it from the clock and 32 secure-random bytes
/// (`document.dart:180`), so **no** two files this product writes are identical
/// byte for byte — not even two of one document: measured 9 Oct, the same
/// document written twice differs in 122 of its 14 524 bytes and every one of
/// them is inside these brackets. A guard asserting whole-file identity would
/// be red for a reason that has nothing to do with a carriage return, which is
/// the same mistake as being green for one.
final _documentId = RegExp(r'/ID\[<[0-9a-f]{64}><[0-9a-f]{64}>\]');

/// The file with that one value set aside, and nothing else touched.
Uint8List _withoutTheDocumentId(Uint8List bytes) {
  final text = String.fromCharCodes(bytes);
  expect(
    _documentId.allMatches(text),
    hasLength(1),
    reason:
        'the id this sets aside was not found exactly once, so either nothing '
        'was set aside or something else was',
  );
  // The same length, so that nothing after it moves and the comparison stays a
  // comparison of the bytes where they stand.
  return Uint8List.fromList(
    text.replaceAll(_documentId, '/ID[<${'0' * 64}><${'0' * 64}>]').codeUnits,
  );
}

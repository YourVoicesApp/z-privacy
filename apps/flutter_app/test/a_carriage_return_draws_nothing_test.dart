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
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/protected_pdf.dart';
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
        // One box for every drawing, so that two of them can be compared.
        child: SizedBox(width: 460, height: 300, child: subject),
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

/// The chat composer with every character of `text` selected, drawn.
///
/// The composer and not one of the read-only surfaces for one reason: a
/// selection can be **set** on a controller, while a `SelectableText`'s is made
/// by a gesture. The property measured belongs to the text layer underneath
/// both, and the document column is held to it by geometry in the same group.
Future<Uint8List> _drawSelected(
  WidgetTester tester,
  String text,
  String dumpAs,
) async {
  final controller = TextEditingController(text: text)
    ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  final focus = FocusNode();
  await tester.pumpWidget(
    _fixed(
      TextField(
        controller: controller,
        focusNode: focus,
        minLines: 3,
        maxLines: 8,
        style: Zc.document.copyWith(fontSize: 14),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    ),
  );
  focus.requestFocus();
  await _settle(tester);
  final pixels = await _pixels(tester);
  await _dump(tester, dumpAs);
  return pixels;
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

  // -------------------------------------------------------------------- the pin
  //
  // **A record of what is true today, not a wish.** Do not «fix» these two by
  // changing them to equality: they are the measurement 074/W8's screen half
  // was closed on, and the day the behaviour changes they are what says so.
  //
  // What they record: a carriage return draws no ink and still takes 8.95 px of
  // width at the document's 14.5 px — DejaVu's `.notdef` advance. Reading, that
  // costs nothing, which the group above proves. Selecting, the highlight runs
  // past the last letter of every line, and where the `\r`'s box and the `\n`'s
  // box overlap it is drawn twice and comes out darker.
  //
  // **Why the obvious fix was not made.** Stripping the `\r` *when drawing* the
  // document column would move every offset after it: the core's spans, the
  // marks, the gutter's line starts and the selection a person makes are all
  // counted in the very string being drawn, and this project has already paid
  // for one «offset that is one out» (041-K, the placeholder span). Whether
  // line endings should instead be settled **on the way in** — once, before any
  // offset exists — is a product decision, and the lead's, not a drawing fix.
  group('pinned: selected, a carriage return is not nothing', () {
    testWidgets('the highlight behind a CRLF document is not the LF one', (
      tester,
    ) async {
      final lf = await _drawSelected(tester, _lf, 'selected-lf');
      final crlf = await _drawSelected(tester, _crlf, 'selected-crlf');
      expect(
        crlf,
        isNot(lf),
        reason:
            'the selected drawings are identical, so the tail this records is '
            'gone — read the group comment and rewrite the pin, do not delete it',
      );
    });

    testWidgets('and in the document column it is painted twice over', (
      tester,
    ) async {
      // Geometry rather than pixels, because a `SelectableText`'s selection is
      // made by a gesture: these are the boxes the highlight is painted from,
      // asked of the render object that would paint it.
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

      /// Two boxes on one row that cover the same pixels — the highlight drawn
      /// over itself, which is what comes out darker.
      int overlaps(List<Rect> boxes) {
        var found = 0;
        for (var i = 0; i < boxes.length; i++) {
          for (var j = i + 1; j < boxes.length; j++) {
            if ((boxes[i].top - boxes[j].top).abs() < 1 &&
                boxes[i].right - boxes[j].left > 0.5 &&
                boxes[j].right - boxes[i].left > 0.5) {
              found++;
            }
          }
        }
        return found;
      }

      final lf = await boxes(_lf);
      final crlf = await boxes(_crlf);
      expect(
        lf,
        isNotEmpty,
        reason:
            'no selection boxes at all, so neither side of this comparison '
            'means anything',
      );
      // Measured 9 Oct: five boxes against eleven, and the three extra pairs
      // are the `\r` of each line painted over the `\n` beside it.
      expect(
        crlf.length,
        greaterThan(lf.length),
        reason:
            'the CRLF document is painted in ${crlf.length} selection boxes and '
            'its twin in ${lf.length} — on 9 Oct that was 11 against 5, and '
            'equal counts mean the tail this records is gone',
      );
      expect(
        overlaps(lf),
        0,
        reason:
            'the LF twin paints ${overlaps(lf)} of its selection boxes over each '
            'other, so «drawn twice» is not what makes the CRLF tail darker and '
            'this pin names the wrong cause',
      );
      expect(
        overlaps(crlf),
        greaterThan(0),
        reason:
            'no two of the CRLF boxes overlap any more, so the doubled tail is '
            'gone — rewrite the pin rather than deleting it',
      );
      // And how far past the last letter it runs: one `.notdef` advance.
      final lfRight = lf.map((b) => b.right).reduce((a, b) => a > b ? a : b);
      final crlfRight = crlf
          .map((b) => b.right)
          .reduce((a, b) => a > b ? a : b);
      expect(
        crlfRight - lfRight,
        closeTo(8.95, 0.5),
        reason:
            'the selection runs ${crlfRight - lfRight} past its twin, and what '
            'was measured on 9 Oct is one `.notdef` advance of 8.95 px at '
            '14.5 px',
      );
    });
  });

  // --------------------------------------------------------------------- ruled
  //
  // 074/W8, measured on the night of 9 October: the fix was dropped because the
  // fault is not there. **This group keeps the drop honest.** The identity holds
  // for today's `pdf` package and today's line breaker and nothing else holds it
  // for tomorrow — the day either changes, this reddens by itself instead of the
  // closure resting on our memory of a measurement.
  group('the PDF a CRLF document writes is the PDF its LF twin writes', () {
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
          compress: false,
        );
        final twice = await buildProtectedPdf(
          text: _lf,
          stamp: stamp(),
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
          compress: false,
        );
        final crlf = await buildProtectedPdf(
          text: _crlf,
          stamp: stamp(),
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
      final lf = await buildProtectedPdf(text: _lf, stamp: stamp());
      final crlf = await buildProtectedPdf(text: _crlf, stamp: stamp());
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
        compress: false,
      );
      final changed = await buildProtectedPdf(
        text: _lf.replaceFirst('Hedvig', 'Hedvigg'),
        stamp: stamp(),
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

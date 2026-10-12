// «When I select now there is no sign that we selected a word.»
//
// The owner's words, on the published Windows build. The drag works — Protect
// acts on what was selected — and nothing is drawn, so a person cannot see
// what they are about to protect. Selecting is the one act in this program
// that a person performs on the document itself, and it was invisible.
//
// Measured: the window's theme carries no `textSelectionTheme` at all, so the
// colour `SelectableText` hands to the painter was never a colour we chose.
// This test reads the colour the Original column will actually paint with, out
// of the widget that paints it.
@Timeout(Duration(minutes: 2))
library;

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/main.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/document_text.dart';

const _doc = 'Ansprechpartner Thomas Müller, Lindenstraße 8, 86150 Augsburg.';

Future<EditableText> pumpOriginal(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: zTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 400,
          child: OriginalText(text: _doc, marks: const []),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<EditableText>(find.byType(EditableText));
}

void main() {
  // **Where this colour is read from moved on 12 Oct, and the claim did not.**
  // These two used to ask the `EditableText` what colour it would paint a
  // selection with. Since 074/W8 the columns paint their own selection —
  // merged first, so a zero-ink character cannot have its tail filled twice —
  // and the widget's own `selectionColor` is deliberately **transparent**
  // inside them. Asking it now would measure the silencing, not the colour.
  //
  // So the question is put where the answer now lives: the theme, which is
  // what `PaintSelectionOnce` reads and what the owner's complaint was really
  // about — «the window's theme carries no `textSelectionTheme` at all».
  // That the colour then reaches the glass is not taken on trust: the pixel
  // test at the foot of this file photographs it, and the payload column is
  // photographed the same way in `a_carriage_return_draws_nothing_test.dart`.
  // **The name carries the claim's own words, and that is not decoration.**
  // `gates.sh` keeps a roster of the screen claims that must have a test and
  // finds each one by **grepping this directory for its phrase**. On 12 Oct
  // this test was renamed while its claim was moved from the widget to the
  // theme — the claim survived, the phrase did not, and a passing entry became
  // a silent skip that nobody saw until the merge. A rename here is a change
  // to a gate; the phrase «selection in blue, not in nothing» stays in the
  // title for as long as the roster asks for it.
  test('the app paints a selection in blue, not in nothing, and not opaquely', () {
    final colour = zTheme().textSelectionTheme.selectionColor;
    expect(colour, isNotNull, reason: 'nothing is given to paint a selection with');
    expect(
      colour!.a,
      greaterThan(0.15),
      reason: 'a selection painted at ${colour.a} alpha is a selection nobody sees',
    );
    expect(
      colour.a,
      lessThan(1.0),
      reason: 'an opaque selection hides the page rules painted behind the '
          'text — the owner refused exactly that on 10 Oct, with the picture '
          'in front of him',
    );
    expect(
      colour,
      Zc.river.withValues(alpha: 0.40),
      reason: 'the owner asked for blue, and the blue of this app is Zc.river',
    );
    // What was there before, for the record: a warm brown at 0.40, taken from
    // the colour scheme's seed, on warm paper.
    expect(
      colour,
      isNot(ColorScheme.fromSeed(seedColor: Zc.clay, surface: Zc.paper).primary.withValues(alpha: 0.40)),
    );
  });

  testWidgets('a drag really selects, and the colour it will be painted in is the theme\'s', (tester) async {
    await pumpOriginal(tester);
    final box = tester.renderObject<RenderBox>(find.byType(EditableText));
    final from = box.localToGlobal(const Offset(12, 8));
    final to = box.localToGlobal(const Offset(240, 8));

    // A mouse, because that is what the owner is holding: a touch drag scrolls
    // the column, and only a pointer drag selects.
    final drag = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 60));
    await drag.moveTo(to);
    await tester.pump(const Duration(milliseconds: 60));
    await drag.up();
    await tester.pumpAndSettle();

    final selection = tester.widget<EditableText>(find.byType(EditableText)).controller.selection;
    expect(
      selection.isCollapsed,
      isFalse,
      reason: 'the drag selected nothing, so this test proves nothing about its colour',
    );
    // The drag is this test's claim; the colour is the theme's, read above,
    // and the pixels are read at the foot of the file.
    expect(zTheme().textSelectionTheme.selectionColor, Zc.river.withValues(alpha: 0.40));
  });

  /// Configured is not painted. This one reads the pixels: it selects with the
  /// mouse across a plain word and a marked one, photographs the column, and
  /// says what colour is actually there.
  ///
  /// Measured on 4 October, and it answers two questions at once:
  ///
  ///   plain text under the selection   (12, 37, 60) — `Zc.river` × 0.40
  ///   a marked word under it          (247, 231, 218) — `Zc.clayWash`, opaque
  ///
  /// The second was a limit, and on 6 October the owner made the call this file
  /// said was his: the washes give way. They are drawn at 0.55 now, so the blue
  /// reads through a protected word instead of stopping at it — measured below,
  /// in the same pixels, and in `a_selection_that_stays_test.dart` against the
  /// unselected colour of the very same word.
  testWidgets('the blue is really on the screen, and it reads through a mark\'s wash', (tester) async {
    const doc = 'Herr Thomas Mueller wohnt hier und dort und zahlt.';
    final marks = [
      Mark(
        span: const Span(start: 5, end: 19),
        state: MarkState.protected,
        token: '__Z_1_PERSON_A__',
        kind: Kind.person,
        source: Source.languagePack,
        decided: false,
        sourceDetail: 'de',
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: zTheme(),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const ValueKey('shot'),
            child: SizedBox(
              width: 620,
              height: 90,
              child: OriginalText(text: doc, marks: marks),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final box = tester.renderObject<RenderBox>(find.byType(EditableText));
    final drag = await tester.startGesture(box.localToGlobal(const Offset(2, 8)), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 60));
    await drag.moveTo(box.localToGlobal(const Offset(400, 8)));
    await tester.pump(const Duration(milliseconds: 60));
    await drag.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.selection.isCollapsed,
      isFalse,
      reason: 'nothing was selected, so the pixels below prove nothing',
    );

    final shot = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    final layer = shot.debugLayer! as OffsetLayer;
    final image = await tester.runAsync(() => layer.toImage(const Rect.fromLTWH(0, 0, 620, 90)));
    final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    final px = data!.buffer.asUint8List();
    List<int> at(int x, int y) {
      final i = (y * 620 + x) * 4;
      return [px[i], px[i + 1], px[i + 2]];
    }

    // «Herr » — plain text, inside the selection. The capture has no page
    // behind it, so what is read is the selection's own colour, premultiplied.
    final blue = Zc.river.withValues(alpha: 0.40);
    final expected = [
      (blue.r * 255 * 0.40).round(),
      (blue.g * 255 * 0.40).round(),
      (blue.b * 255 * 0.40).round(),
    ];
    for (final x in [8, 20, 40]) {
      final got = at(x, 20);
      for (var c = 0; c < 3; c++) {
        expect(
          (got[c] - expected[c]).abs() <= 2,
          isTrue,
          reason: 'at x=$x the selection is $got, and the blue would be $expected',
        );
      }
    }

    // «Thomas Mueller» — marked, and inside the same selection. The wash at
    // 0.55 over the selection's own blue: no longer the opaque (247, 231, 218)
    // this test was written on, and bluer than the wash alone would be.
    final wash = at(130, 20);
    final opaque = [(Zc.clayWash.r * 255).round(), (Zc.clayWash.g * 255).round(), (Zc.clayWash.b * 255).round()];
    expect(wash, isNot(opaque), reason: 'the wash still covers the selection whole');
    expect(
      wash[2] / (wash[0] + 1) > opaque[2] / (opaque[0] + 1),
      isTrue,
      reason: 'the selected mark is no bluer than the wash itself: $wash against $opaque',
    );
  });
}

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
  testWidgets('the Original column paints its selection in blue, not in nothing', (tester) async {
    final editable = await pumpOriginal(tester);

    expect(
      editable.selectionColor,
      isNotNull,
      reason: 'nothing was given to paint a selection with',
    );
    expect(
      editable.selectionColor!.a,
      greaterThan(0.15),
      reason: 'a selection painted at ${editable.selectionColor!.a} alpha is a selection nobody sees',
    );
    expect(
      editable.selectionColor,
      Zc.river.withValues(alpha: 0.40),
      reason: 'the owner asked for blue, and the blue of this app is Zc.river',
    );
    // What was there before, for the record: a warm brown at 0.40, taken from
    // the colour scheme's seed, on warm paper.
    expect(
      editable.selectionColor,
      isNot(ColorScheme.fromSeed(seedColor: Zc.clay, surface: Zc.paper).primary.withValues(alpha: 0.40)),
    );
  });

  testWidgets('the Safe column is given the same blue, since it can be selected too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: zTheme(),
        home: const Scaffold(
          body: SizedBox(
            width: 700,
            height: 400,
            child: SafeText(text: 'Guten Tag __Z_1234_PERSON_ABCD__, Ihre Rechnung.'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.selectionColor, Zc.river.withValues(alpha: 0.40));
  });

  testWidgets('a drag really selects, and what it will paint is that same blue', (tester) async {
    final editable = await pumpOriginal(tester);
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
    expect(editable.selectionColor, Zc.river.withValues(alpha: 0.40));
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
  /// The second is a limit worth knowing rather than a defect to hide: a mark's
  /// wash is a text-span background, and a span background is painted **after**
  /// the selection rectangle, so selecting across a word that is already
  /// protected shows the wash and not the blue. Making the three washes
  /// translucent enough to show it through would change colours the owner chose,
  /// so it is his call and not this file's.
  testWidgets('the blue is really on the screen, and a mark\'s wash covers it', (tester) async {
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

    // «Thomas Mueller» — marked, and inside the same selection.
    final wash = at(130, 20);
    expect(
      [(Zc.clayWash.r * 255).round(), (Zc.clayWash.g * 255).round(), (Zc.clayWash.b * 255).round()],
      wash,
      reason: 'the mark no longer covers the selection — if that was intended, this is the test to change',
    );
  });
}

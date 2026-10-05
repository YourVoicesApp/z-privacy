// 041-C · «التحديد يظهر متقطعاً ثم يختفي» — the owner, twice.
//
// Two defects wearing one sentence, both measured on the published build before
// a line of this was written:
//
// **Broken** — a mark's wash is a text-span background, and a span background is
// painted *after* the selection rectangle. Photographed on 4 October: plain text
// under the selection is (12, 37, 60), `Zc.river` × 0.40; a marked word under
// the same selection is (247, 231, 218), `Zc.clayWash`, opaque. The blue is
// there and the wash sits on top of it, so a selection crossing protected words
// is drawn in pieces.
//
// **Gone** — the Workspace rebuilds the Original column on every selection
// change, because `onSelection` goes into the bench and the bench notifies.
// Measured: with marks on the text the selection ends `-1..-1` after that
// rebuild; with no marks at all it survives as `0..39`. The difference is the
// `TapGestureRecognizer` built fresh for every mark on every build — a new
// recognizer makes the new `TextSpan` tree unequal to the old one, and
// `SelectableText` answers an unequal span by throwing its controller away,
// and the selection with it.
//
// The gestures themselves were already right, and these tests keep them that
// way: releasing a drag over a mark — measured on, off, and inside one — never
// opened the card and never collapsed the selection, while a plain tap did ask.
@Timeout(Duration(minutes: 3))
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
const _style = TextStyle(fontSize: 14.5, height: 1.55);

Mark _mark(int start, int end, Kind kind) => Mark(
      span: Span(start: start, end: end),
      state: MarkState.protected,
      token: '__Z_1_X__',
      kind: kind,
      source: Source.languagePack,
      decided: false,
      sourceDetail: 'de',
    );

List<Mark> _marks() => [_mark(16, 29, Kind.person), _mark(31, 61, Kind.address)];

Offset _at(WidgetTester tester, int offset) {
  final box = tester.renderObject<RenderBox>(find.byType(EditableText));
  final painter = TextPainter(text: const TextSpan(text: _doc, style: _style), textDirection: TextDirection.ltr)
    ..layout(maxWidth: 700);
  return box.localToGlobal(
    painter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero) + const Offset(2, 8),
  );
}

Future<void> _dragFrom(WidgetTester tester, int from, int to) async {
  final drag = await tester.startGesture(_at(tester, from), kind: PointerDeviceKind.mouse);
  await tester.pump(const Duration(milliseconds: 60));
  await drag.moveTo(_at(tester, to));
  await tester.pump(const Duration(milliseconds: 60));
  await drag.up();
  await tester.pumpAndSettle();
}

TextSelection _selection(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.selection;

void main() {
  testWidgets('the selection survives the rebuild the Workspace does on every change', (tester) async {
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      theme: zTheme(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            builds++;
            return SizedBox(
              width: 700,
              height: 200,
              // The marks are rebuilt too, as a notifying bench rebuilds them.
              child: OriginalText(
                text: _doc,
                marks: _marks(),
                onAsk: (m) {},
                onSelection: (s, e) => setState(() {}),
              ),
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await _dragFrom(tester, 0, 40);

    expect(builds, greaterThan(1), reason: 'nothing rebuilt, so this test proves nothing');
    final sel = _selection(tester);
    expect(
      sel.isCollapsed,
      isFalse,
      reason: 'the selection died in the rebuild: ${sel.start}..${sel.end}',
    );
    expect(sel.start, 0);
    expect(sel.end, 39, reason: 'the measured end of that drag');
  });

  testWidgets('the blue is visible on a protected word, not only between them', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: zTheme(),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const ValueKey('shot'),
            child: SizedBox(width: 700, height: 90, child: OriginalText(text: _doc, marks: _marks())),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The colour of a marked word with nothing selected, for the comparison.
    Future<List<int>> pixelOverTheMark() async {
      final shot = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      final layer = shot.debugLayer! as OffsetLayer;
      final image = await tester.runAsync(() => layer.toImage(const Rect.fromLTWH(0, 0, 700, 90)));
      final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      final px = data!.buffer.asUint8List();
      // The middle of «Thomas Müller», taken from the painter rather than
      // guessed: a sample point outside the mark would make this test say
      // «visible» about a word that is not marked at all.
      final painter = TextPainter(text: const TextSpan(text: _doc, style: _style), textDirection: TextDirection.ltr)
        ..layout(maxWidth: 700);
      final boxes = painter.getBoxesForSelection(const TextSelection(baseOffset: 16, extentOffset: 29));
      final rect = boxes.first.toRect();
      final x = rect.center.dx.round();
      final y = rect.center.dy.round();
      final i = (y * 700 + x) * 4;
      return [px[i], px[i + 1], px[i + 2]];
    }

    final unselected = await pixelOverTheMark();
    await _dragFrom(tester, 0, 45);
    expect(_selection(tester).isCollapsed, isFalse, reason: 'nothing is selected, so the pixels prove nothing');
    final selected = await pixelOverTheMark();

    expect(
      selected,
      isNot(unselected),
      reason: 'a protected word looks the same selected and unselected: $selected',
    );
    // And it moved towards the blue rather than anywhere else.
    expect(
      selected[2] - unselected[2] > selected[0] - unselected[0],
      isTrue,
      reason: 'the change over the mark is not blue: $unselected → $selected',
    );
  });

  testWidgets('a drag that ends on a mark keeps its selection, and a tap still asks', (tester) async {
    var asked = 0;
    await tester.pumpWidget(MaterialApp(
      theme: zTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 200,
          child: OriginalText(text: _doc, marks: _marks(), onAsk: (m) => asked++),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Measured three ways: ending on a mark, ending off one, and a drag that
    // begins and ends inside the same mark — the hardest case, because that
    // span's own tap recognizer is in the arena for the whole gesture.
    // The ends are the measured ones: a release at the caret before offset 40
    // selects up to 39, which is what a person sees under their pointer.
    for (final (from, to, selected) in [(0, 40, 39), (0, 61, 61), (17, 27, 27)]) {
      await _dragFrom(tester, from, to);
      final sel = _selection(tester);
      expect(sel.isCollapsed, isFalse, reason: 'the drag $from→$to left nothing selected');
      expect(sel.start, from);
      expect(sel.end, selected, reason: 'the drag $from→$to selected ${sel.start}..${sel.end}');
      expect(asked, 0, reason: 'the drag $from→$to opened the mark\'s card');
    }

    // A tap without a drag is still the question this layer exists to answer.
    await tester.tapAt(_at(tester, 20), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(asked, 1, reason: 'a tap on a protected word no longer asks why');
  });
}

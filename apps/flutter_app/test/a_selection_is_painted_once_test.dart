// 074/W8 — the selection is painted once, wherever it overlaps itself.
//
// **The owner's ruling, 10 Oct 2026**, after the two pictures: merge the boxes
// before they are filled. The opaque colour was refused because the page rule
// dissolves under it, and leaving it was refused.
//
// This file guards the **pure half**: boxes in, rectangles out. Flutter hands
// the selection painter `getBoxesForSelection(...).toSet()` and fills **one
// translucent rect per box** (`rendering/editable.dart:2914`); `toSet()` drops
// only boxes that are *identical*, so a selected carriage return — whose box
// the engine returns both whole and in parts — is filled two and three times
// over and comes out darker. The arithmetic here is what stops that, and it is
// written as a function with no widget in it so it can be broken on purpose.
//
// **It may not move anything.** Merging is drawing and nothing else: the union
// of the rectangles out must cover exactly the union of the rectangles in, or
// a selection would appear to grow or shrink — and offsets, spans, marks and
// the gutter are not touched by any of this (041-K, the offset that was one
// out, is the debt this project does not pay twice).
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/widgets/document_text.dart';

/// Row 0 of the measurement of 9 Oct: the whole tail, and the two parts inside
/// it that the engine also returns.
const _tail = [
  Rect.fromLTRB(0.1, 4, 248.8, 29),
  Rect.fromLTRB(248.8, 4, 322.3, 29),
  Rect.fromLTRB(248.8, 4, 257.7, 29),
  Rect.fromLTRB(257.7, 4, 322.3, 29),
];

double _area(Iterable<Rect> rects) =>
    rects.fold(0.0, (a, r) => a + r.width * r.height);

void main() {
  test('two boxes over the same pixels become one', () {
    final out = paintedOnce(_tail);
    expect(
      out,
      hasLength(1),
      reason:
          'the row came back in ${out.length} rectangles, so something is '
          'still painted over something else',
    );
    expect(out.single.left, closeTo(0.1, 0.01));
    expect(out.single.right, closeTo(322.3, 0.01));
  });

  test('and the selection neither grows nor shrinks', () {
    // The claim that keeps this honest: merging is drawing. If the union
    // changed, a person would see their selection move.
    final out = paintedOnce(_tail);
    expect(
      _area(out),
      closeTo(322.2 * 25, 0.5),
      reason:
          'the merged rectangles cover ${_area(out)}, and the boxes they '
          'came from cover the span 0.1..322.3 on one row',
    );
  });

  test('rows stay their own', () {
    // Two rows that overlap in x and not in y are not one rectangle, however
    // much they share horizontally.
    final out = paintedOnce(const [
      Rect.fromLTRB(0, 0, 100, 25),
      Rect.fromLTRB(0, 25, 100, 50),
    ]);
    expect(out, hasLength(2), reason: 'two rows were merged into one block');
  });

  test('boxes that only touch are not overlapping', () {
    // The LF document's own shape: a line's text and the newline's tail meet
    // at an edge and are painted once each. Merging them changes nothing a
    // person sees, but inventing an overlap where there is none would mean the
    // rule fires on every document rather than on the fault.
    final out = paintedOnce(const [
      Rect.fromLTRB(0, 0, 248.8, 25),
      Rect.fromLTRB(248.8, 0, 313.4, 25),
    ]);
    expect(_area(out), closeTo(313.4 * 25, 0.5));
  });

  test('nothing in, nothing out', () {
    expect(paintedOnce(const []), isEmpty);
  });
}

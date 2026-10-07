// Where the document's own text is drawn, and where a character of it sits.
//
// **One place, and it reads the drawing rather than repeating it.**
//
// Three test files had written this out separately, each with a `TextPainter`
// of its own laid out at the width of the `OriginalText` box. When 046/Q put a
// line gutter beside the text all three began pressing in the wrong place —
// and for the same reason the gutter's own first version did: `RenderEditable`
// lays its text out at the width it is given **less a private three-pixel
// caret margin**, and it no longer fills its parent's box at all. A painter
// built in a test is never quite the drawing, and a test that presses in the
// wrong place is a test that can be green about nothing.
//
// So: the render object that draws the text answers both questions. There is
// nothing here to keep in step with the screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The text of the document, as it is laid out right now.
///
/// `marker` is a word the document contains and nothing else on the screen
/// does. It is not a convenience: the Original column holds **two** editables
/// since 046/N put a request field under the document, and reaching for the
/// first one is how a press lands in a text box while the test says the
/// document was pressed.
RenderEditable drawnDocument(WidgetTester tester, String marker) {
  for (final element in find.byType(EditableText).evaluate()) {
    final widget = element.widget;
    if (widget is EditableText && widget.controller.text.contains(marker)) {
      return (tester.state(find.byWidget(widget)) as EditableTextState).renderEditable;
    }
  }
  throw StateError('no editable on screen holds «$marker»');
}

/// Where the character at `offset` is on the screen — the middle of the stretch
/// `span` characters long that begins there, so a press lands inside it rather
/// than on its edge.
Offset whereIsInDocument(
  WidgetTester tester,
  String marker,
  int offset, {
  int span = 1,
}) {
  final drawn = drawnDocument(tester, marker);
  final from = drawn.getLocalRectForCaret(TextPosition(offset: offset));
  final to = drawn.getLocalRectForCaret(TextPosition(offset: offset + span));
  return drawn.localToGlobal(
    Offset((from.center.dx + to.center.dx) / 2, from.center.dy),
  );
}

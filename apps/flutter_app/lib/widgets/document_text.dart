// The two columns' text: the document with its marks, and the payload with its
// tokens. One file, because the two are the same drawing problem seen twice and
// they must stay visually comparable — that comparison *is* the product.
//
// Spans arrive in UTF-16 code units, which is exactly how Dart counts a string,
// so a span can be used to slice directly. The core refuses a span that falls
// inside a character, so a slice here can never cut one in half.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/line_gutter.dart';

/// The `RenderEditable` under a key, or null before the first layout.
///
/// `SelectableText` keeps it a few layers down — inside an `EditableText`,
/// inside that widget's own viewport — and exposes no handle to it. So it is
/// found by walking, and the walk stops at the first one. The alternative was
/// to copy Flutter's private caret-margin constant into this file, a number
/// that can change under us without a compile error.
RenderEditable? editableUnder(GlobalKey key) {
  final from = key.currentContext?.findRenderObject();
  if (from == null) return null;
  RenderEditable? walk(RenderObject here) {
    if (here is RenderEditable) return here;
    RenderEditable? found;
    here.visitChildren((child) {
      found ??= walk(child);
    });
    return found;
  }

  return walk(from);
}

/// **A selectable text whose selection is painted once — 074/W8.**
///
/// Flutter's own painter fills **one translucent rect per selection box**
/// (`rendering/editable.dart:2914`) and `toSet()` drops only boxes that are
/// *identical*; the engine hands it a line's tail both whole and in parts
/// whenever a zero-ink character is selected, so the tail is filled two and
/// three times and comes out darker. The owner chose merging after two
/// pictures: the opaque colour was refused because the page rule dissolves
/// under it, and leaving it was refused.
///
/// So the built-in paint is silenced **here and only here** — the chat field
/// measured zero double-paint and the global theme is untouched — and the
/// merged rectangles are drawn behind the text in this widget's own `Stack`.
///
/// **Both columns wear it.** The Original and the Safe column are the same
/// drawing problem seen twice, and measured on 12 Oct they double by the same
/// 8 582 pixels. A fix on one of them would have left the other wrong on the
/// same screen, side by side, which is the comparison this file exists for.
///
/// Three things it does not do: it does not change the colour (the marks'
/// washes are tuned against `Zc.river` at 0.40 — see `_wash`), it does not
/// touch the text or any offset in it (041-K), and it does not ask for boxes
/// on every frame — only when the selection it is given says so.
class PaintSelectionOnce extends StatefulWidget {
  const PaintSelectionOnce({
    super.key,
    required this.editable,
    required this.repaint,
    required this.child,
  });

  /// The drawing to read the selection and its boxes off. Read, never
  /// remeasured: a painter of our own is not the drawing, which is the defect
  /// `linesOf` was written against.
  final RenderEditable? Function() editable;

  /// Ticks when the selection changes. Flutter's own painter runs its
  /// `getBoxesForSelection` inside `paint`, so this costs what it already
  /// cost, plus a sort and a sweep.
  final Listenable repaint;

  final Widget child;

  @override
  State<PaintSelectionOnce> createState() => _PaintSelectionOnceState();
}

class _PaintSelectionOnceState extends State<PaintSelectionOnce> {
  /// The ground the rectangles are placed against — the editable sits a few
  /// layers inside this stack, so its own origin is asked for rather than
  /// assumed to be zero.
  final GlobalKey _plate = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // **From the theme, never written again here.** A colour stated twice
    // drifts, and this one was measured: `Zc.river` at 0.40 over the page.
    final colour =
        DefaultSelectionStyle.of(context).selectionColor ??
        Theme.of(context).textSelectionTheme.selectionColor;
    return Stack(
      key: _plate,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _SelectionOnce(
              editable: widget.editable,
              plate: _plate,
              colour: colour ?? const Color(0x00000000),
              repaint: widget.repaint,
            ),
          ),
        ),
        DefaultSelectionStyle(
          selectionColor: const Color(0x00000000),
          child: widget.child,
        ),
      ],
    );
  }
}

class _SelectionOnce extends CustomPainter {
  _SelectionOnce({
    required this.editable,
    required this.plate,
    required this.colour,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final RenderEditable? Function() editable;
  final GlobalKey plate;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = editable();
    if (drawn == null || !drawn.attached) return;
    final selection = drawn.selection;
    if (selection == null || !selection.isValid || selection.isCollapsed) {
      return;
    }
    final ground = plate.currentContext?.findRenderObject();
    if (ground is! RenderBox || !ground.attached) return;

    final at = drawn.localToGlobal(Offset.zero, ancestor: ground);
    final glass = Offset.zero & size;
    final paint = Paint()..color = colour;
    final boxes = drawn
        .getBoxesForSelection(selection)
        .map((box) => box.toRect());
    for (final rect in paintedOnce(boxes)) {
      final where = rect.shift(at);
      // Only what is inside this canvas: 048 measured documents of 82 468
      // lines, and a selection of all of them is mostly somewhere else.
      if (!where.overlaps(glass)) continue;
      canvas.drawRect(where, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionOnce old) =>
      old.colour != colour || old.editable != editable || old.plate != plate;
}

/// **The rectangles a selection should be filled with — 074/W8.**
///
/// Flutter's own selection painter takes `getBoxesForSelection(...).toSet()`
/// and fills **one translucent rect per box**
/// (`rendering/editable.dart:2914`). `toSet()` removes only boxes that are
/// *identical*, and the engine hands it a line's tail both whole and in parts
/// whenever a zero-ink character is selected — a carriage return from a
/// Windows document, measured on 9 October: eleven boxes where the same
/// document written with `\n` takes five, three of them lying over each other.
/// At alpha 0.40 paint over paint is a darker colour, so the end of every line
/// came out as a dark block.
///
/// This is the whole of the fix the owner chose, after two pictures: the
/// opaque colour was refused because the page rule dissolves under it, and
/// leaving it was refused. Merge first, then fill.
///
/// **It is arithmetic about drawing and nothing else.** The union of what comes
/// out is the union of what went in — a selection that grew or shrank by a
/// pixel would be a worse fault than the one being fixed — and no offset, span,
/// mark or line number is touched by any of it. 041-K is the debt this project
/// does not pay twice.
///
/// Rows are kept apart: boxes belong to the same row when their tops agree
/// within a pixel, which is how the engine reports them.
List<Rect> paintedOnce(Iterable<Rect> boxes) {
  final rows = <double, List<Rect>>{};
  for (final box in boxes) {
    final row = rows.keys.firstWhere(
      (top) => (top - box.top).abs() < 1,
      orElse: () => box.top,
    );
    (rows[row] ??= <Rect>[]).add(box);
  }

  final out = <Rect>[];
  for (final row in rows.values) {
    final sorted = [...row]..sort((a, b) => a.left.compareTo(b.left));
    var held = sorted.first;
    for (final box in sorted.skip(1)) {
      // Touching counts as joined: two rects that meet at an edge fill the same
      // pixels as one that spans both, so joining them costs nothing and
      // leaves fewer draws.
      if (box.left <= held.right + 0.01) {
        held = Rect.fromLTRB(
          held.left,
          held.top < box.top ? held.top : box.top,
          held.right > box.right ? held.right : box.right,
          held.bottom > box.bottom ? held.bottom : box.bottom,
        );
      } else {
        out.add(held);
        held = box;
      }
    }
    out.add(held);
  }
  return out;
}

/// **What counts as a space** — and the one place that answers it.
///
/// The owner's rule is written against spaces: a word begins right after one
/// and ends right before the next. «The start and the end of a line count as a
/// space» is his reading too, so a line break is a boundary and so is the edge
/// of the document. Both the single click and the pair ask here, because two
/// readings of «space» would be two rules.
bool _isBoundary(String text, int k) =>
    k < 0 || k >= text.length || text[k] == ' ' || text[k] == '\n';

/// **The word a single click takes — 076, the owner's rule.**
///
/// «الضغط على الاسم بالماوس من داخل النص يحدده فقط الاسم» — one left click
/// selects the word under the pointer, and he stated the boundary himself on
/// 13 October: a word **begins right after a space and ends right before the
/// next space**, and the space is never part of it. The start and the end of a
/// line count as a space.
///
/// Then the edges are tidied of the marks a sentence leaves around a word, so
/// that what is **highlighted** is what will be **protected** — his words: «a
/// one-click selection on `Wilson,` shows `Wilson` selected and the comma
/// apart». The marks are the core's own list (`z_core/src/text.rs:103`), and
/// the law lives there: `whole_words` is what actually trims the span at
/// protection time, and this is the glass showing it in advance. The two are
/// pinned to **one** set of cases — the owner's sealed ones — in
/// `the_marks_a_hand_selection_leaves_behind` (Rust) and in
/// `a_click_takes_one_word_test` (here), so a drift on either side reddens.
///
/// Returns null where there is no word to take: on a space, or in an empty
/// document.
TextRange? wordAt(String text, int at) {
  if (text.isEmpty) return null;
  final i = at.clamp(0, text.length);
  // A click on the space itself takes nothing. The owner's rule is about
  // words; inventing one from a press that pointed at no word would be the
  // screen deciding for the person, and the press costs nothing to repeat.
  if (_isBoundary(text, i)) return null;

  var start = i;
  while (start > 0 && !_isBoundary(text, start - 1)) {
    start--;
  }
  var end = i;
  while (end < text.length && !_isBoundary(text, end)) {
    end++;
  }

  // The same marks the core drops from a value's edges, so the highlight and
  // the value cannot differ. Interior marks are untouched: the filter trims, it
  // does not split — «Anne-Marie», «O'Brien» and a CSV cell stay whole.
  const edgeMarks = <String>{
    '.', ',', ';', ':', '!', '?', '…', '"', "'", '«', '»', '(', ')', '[', ']',
    '{', '}', '„', '“', '”', '‘', '’', '—', '–', '،', '؛', '؟',
  };
  while (start < end && edgeMarks.contains(text[start])) {
    start++;
  }
  while (end > start && edgeMarks.contains(text[end - 1])) {
    end--;
  }
  return start < end ? TextRange(start: start, end: end) : null;
}

/// **The value two clicks take — 076, the owner's rule.**
///
/// «الضغطتان تأخذان كلمة ومسافة والكلمة التالية، قيمةً واحدة» — the word under
/// the pointer, the space after it, and the word after that, as **one** value.
///
/// It is one **span**, so it reads exactly as the document reads between its
/// two ends: only the ends are tidied, by `wordAt` on each side. A mark that
/// falls between the two words — `Mueller, bitte` — stays inside the value,
/// because taking it out would mean two spans and a value that reads
/// differently from the text it came out of, and that is the one thing
/// protection may never do.
///
/// Where there is no second word to take, the value is the first word alone,
/// and the cases where that happens are each a decision:
///  * **a line break after the first word** — a hand selection may not cross
///    one, and the pair is a hand selection;
///  * **two spaces** — the rule says *a* space, and taking less costs the
///    person one more click while taking more protects what they never saw;
///  * **a dash or a bracket where the next word should be** — a mark is not a
///    word, and a value may not end on one;
///  * **the end of the document.**
TextRange? wordPairAt(String text, int at) {
  final first = wordAt(text, at);
  if (first == null) return null;

  // The space is looked for from the **untidied** end of the first word: the
  // comma in `Mueller, bitte` is not part of the value but it is certainly
  // part of the text, and the space is on the far side of it.
  var i = at.clamp(0, text.length);
  while (i < text.length && !_isBoundary(text, i)) {
    i++;
  }
  if (i >= text.length || text[i] != ' ') return first;

  final second = wordAt(text, i + 1);
  if (second == null) return first;
  return TextRange(start: first.start, end: second.end);
}

/// What each source is called on screen, and why the mark is there.
String sourceName(Source s) => switch (s) {
      Source.generalRule => 'Rule',
      Source.languagePack => 'Pack',
      Source.vault => 'Vault',
      Source.hand => 'You',
    };

/// The colour a source is drawn in. The vault gets its own, because «the app
/// knows who this is» is a different fact from «this looks like an IBAN».
Color sourceTint(Source s) => switch (s) {
      Source.vault => Zc.river,
      _ => Zc.clay,
    };

/// The kinds, as the core hands them over — filled by `Ground.refresh()`.
///
/// This used to be a `switch` over every `Kind`, which is exactly the
/// assumption the owner forbade on 27 September: a screen must not decide that
/// Person, Company, IBAN and Phone are all the kinds there can be. Now the list
/// comes from `kinds()`, and the day it has a user-made row in it, every screen
/// below already draws it.
final List<KindRow> kindRows = [];
final Map<Kind, String> _kindLabels = {};

void rememberKinds(List<KindRow> rows) {
  kindRows
    ..clear()
    ..addAll(rows);
  _kindLabels
    ..clear()
    ..addEntries(rows.map((r) => MapEntry(r.kind, r.label)));
}

/// Never invents a name: before the list has arrived it says nothing.
String kindName(Kind k) => _kindLabels[k] ?? '…';

/// The left column: the document as written, with what the scanner did to it
/// drawn **over** the words rather than instead of them. Nothing here is
/// replaced — this side is the original, and the boards' hard rule is that it
/// never reaches the network.
class OriginalText extends StatefulWidget {
  const OriginalText({
    super.key,
    required this.text,
    required this.marks,
    this.selection,
    this.onSelection,
    this.focus,
    this.focusKey,
    this.onAsk,
    this.onChoose,
    this.heldLines,
    this.onLines,
    this.onColumn,
  });

  final String text;
  final List<Mark> marks;

  /// The page rules, for the test that counts them: present only when the
  /// document has an edge in it at all.
  static const pageEdges = ValueKey<String>('original-page-edges');

  /// The stretch the user has selected, if any.
  final TextRange? selection;

  /// Reported in UTF-16 code units — which is what the contract's `Span` means,
  /// so the offsets go straight to the core without conversion.
  final void Function(int start, int end)? onSelection;

  /// The finding the review list is pointing at. Drawn stronger than the rest,
  /// and given an anchor so the column can be scrolled to it — this is how
  /// «page 17» becomes a place you actually arrive at.
  final Span? focus;
  final GlobalKey? focusKey;

  /// Tapping a protected word asks the one question this whole layer exists to
  /// answer: **why is this protected?**
  final void Function(Mark mark)? onAsk;

  /// Tapping a word that is still **waiting** offers the choice, where the word
  /// is. The owner, 6 October: «the suggested names must appear on the text
  /// itself, not as a separate list, and the choices a small message that
  /// disappears when it is pressed».
  ///
  /// The position is where the finger or the pointer went down, in global
  /// coordinates, because that is what a bubble has to be anchored to.
  final void Function(Mark mark, Offset at)? onChoose;

  /// 046/Q — **the lines held now**, from zero, or null for none. The gutter
  /// is drawn only when `onLines` is given, so every screen that does not
  /// offer the gesture keeps exactly the layout it had.
  final ({int from, int to})? heldLines;

  /// A press or a drag in the gutter: where it began and where it ended.
  final void Function(int from, int to)? onLines;

  /// **A press on a value inside the held lines.** One press, no confirmation:
  /// the lead's ruling of 7 October, and the asymmetry it rests on — only an
  /// act that leaves values in the clear asks, because protecting is never a
  /// leak.
  ///
  /// The offset is a place in the document, and the core turns it into a cell
  /// by its order among the line's runs. A press in the whitespace between two
  /// columns is refused there by name, and nothing here guesses a column.
  final void Function(int offset)? onColumn;

  @override
  State<OriginalText> createState() => _OriginalTextState();
}

class _OriginalTextState extends State<OriginalText> {
  /// Where a press went down, so the press can be told from a drag.
  Offset? _downAt;

  /// **The word the first of two clicks took, while a second may still come**
  /// — 076, item 3, and `null` as soon as the chance has passed.
  ///
  /// The count is kept here rather than taken from the text, and the reason
  /// was measured on 13 October. `SelectableText` does report a selection with
  /// `SelectionChangedCause.doubleTap` on the second press down — in a bare
  /// `SelectableText` the probe read `DOWN · SEL 0..8 doubleTap · UP`. But
  /// inside this widget it never arrived, and the cause is worth keeping: the
  /// **first** click has already selected that very word, so Flutter's own
  /// `selectWord` changes nothing, and `EditableText` reports nothing when the
  /// selection is unchanged. The signal is silent exactly when we have already
  /// done the right thing — a guard built on it would have been green on a
  /// document where the clicks were never counted at all.
  ///
  /// A clock of our own was measured and rejected too: a test's pointer events
  /// all carry `timeStamp` zero, and the frame clock stands still whenever no
  /// frame is drawn. A `Timer` is neither — it is what Flutter's own
  /// recognizers use, it runs on real time in the product and on the test's
  /// clock under `pump`, and `kDoubleTapTimeout` is the platform's number, not
  /// one of ours.
  TextRange? _firstClick;
  Timer? _secondChance;

  /// How far a pointer may slip between down and up and still be a press.
  ///
  /// Measured, 6 October, on the owner's «the bubble does not come out»: the
  /// marks used to carry a `TapGestureRecognizer` each, and inside a
  /// `SelectableText` that recognizer is in the gesture arena against the
  /// text's own drag-selection. Flutter gives a **mouse** one pixel of slop,
  /// so the arena went to the drag the moment the pointer moved two — and
  /// nobody presses a mouse button without moving two pixels. Measured
  /// exactly: 1 px opened the bubble, 2 px and 4 px and 8 px opened nothing
  /// at all, and no selection was made either, so the press simply vanished.
  ///
  /// So the press is read from raw pointer events, which are delivered to
  /// every listener and are in no arena, and this is the line between a press
  /// and a drag. Six pixels is a hand on a mouse; a drag that means to select
  /// a word crosses it easily.
  static const _slop = 6.0;

  /// The spans, kept between builds — **and this is what keeps a selection
  /// alive.**
  ///
  /// The Workspace rebuilds this column on every selection change: the drag
  /// reports, the bench is told, the bench notifies. Measured on the published
  /// build: a drag across protected words ended `-1..-1` after that rebuild,
  /// while the same drag on text with no marks on it survived as `0..39`. The
  /// difference was a `TapGestureRecognizer` built fresh for every mark on
  /// every build — `TextSpan` compares its recognizer by identity, so a rebuilt
  /// tree is never equal to the old one, and `SelectableText` answers an
  /// unequal span by replacing its controller, which is where the selection
  /// lived.
  ///
  /// So the spans are built once per (text, marks, focus) and handed back
  /// unchanged until one of those three really changes. The recognizers read
  /// `widget.onAsk` at the moment of the tap rather than closing over the
  /// callback they were built with, so a kept recognizer never calls into a
  /// build that has gone.
  List<InlineSpan>? _cached;
  bool _cachedChoosable = false;
  String? _cachedText;
  List<Mark>? _cachedMarks;
  Span? _cachedFocus;

  /// The text as it is drawn, so that nothing here has to work out where a line
  /// begins. `null` until the first layout, which is before any press or paint.
  final GlobalKey _drawn = GlobalKey();

  RenderEditable? _editable() => editableUnder(_drawn);

  /// The state that **owns** the selection, found by the same walk as the
  /// render object above and for the same reason: `SelectableText` keeps its
  /// `EditableText` a few layers down and hands out no handle to it. The
  /// render object can be read; only the state can be told.
  EditableTextState? _editableState() {
    EditableTextState? found;
    void walk(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(walk);
    }

    final context = _drawn.currentContext;
    if (context is Element) context.visitChildren(walk);
    return found;
  }

  /// Ticks when the selection moves, so the rectangles behind the text are
  /// redrawn once and only then — 074/W8.
  final ValueNotifier<int> _selectionChanged = ValueNotifier<int>(0);

  /// Where the lines were read, and at what size.
  ///
  /// Reading asks the laid-out text for the top of **every** logical line, and
  /// 048 holds documents of 5 770 and 82 468 lines. Doing that on every paint
  /// would make scrolling cost what opening the file cost. It is kept until the
  /// spans or the drawn size really change — the size, because that is what
  /// changes where the wraps fall.
  GutterLayout? _measured;
  List<InlineSpan>? _measuredFrom;
  Size? _measuredAt;

  GutterLayout? _lines() {
    final drawn = _editable();
    if (drawn == null || !drawn.hasSize) return null;
    final spans = _keptSpans();
    final kept = _measured;
    if (kept != null && identical(_measuredFrom, spans) && _measuredAt == drawn.size) {
      return kept;
    }
    final now = linesOf(drawn, text);
    _measured = now;
    _measuredFrom = spans;
    _measuredAt = drawn.size;
    return now;
  }

  /// A press that ended where it began, on a word that is marked.
  ///
  /// The offset is found with a painter over the very spans that are drawn, so
  /// what is hit is what is seen. A protected word asks «why is this
  /// protected»; one still waiting asks «what do you want done with it»; and a
  /// press on ordinary text asks nothing and does nothing.
  void _pressEnded(PointerUpEvent event) {
    final down = _downAt;
    _downAt = null;
    // Read and cleared before any way out of this method, so a first click can
    // never outlive the moment a second could have joined it — including when
    // the press turns out to be a drag, or to land on a mark, or inside held
    // lines, each of which is a different act and ends the pair.
    final first = _firstClick;
    _firstClick = null;
    _secondChance?.cancel();
    _secondChance = null;
    if (down == null || (event.position - down).distance > _slop) return;

    // **Asked of the text that is drawn, not of a painter built here.**
    // Measured, 7 October, on a sheet whose rows wrap: a painter given the same
    // spans and the same width wrapped the document into 13 rows where the
    // screen drew 16, because `RenderEditable` lays its text out at the width
    // it is given **less a three-pixel caret margin**. The press for an account
    // number came back as an offset on another line, and the act protected the
    // invoice reference at the far end of three rows. One geometry, and it is
    // the one on screen.
    final drawn = _editable();
    if (drawn == null) return;
    final offset = drawn.getPositionForPoint(event.position).offset;

    final marked = widget.marks.where((m) => offset >= m.span.start && offset < m.span.end);

    // **Inside held lines, a press is the column act** (046/Q) — one press and
    // no confirmation.
    //
    // With one exception, and it is not a hedge: a press on a word that is
    // **already protected** still asks «why is this protected?», because for
    // that cell the act has nothing left to do and the question is the only
    // thing the press could usefully mean. A word still *waiting* is no
    // exception: protecting its whole column is exactly the answer.
    final held = widget.heldLines;
    final column = widget.onColumn;
    if (held != null && column != null) {
      final lo = held.from < held.to ? held.from : held.to;
      final hi = held.from < held.to ? held.to : held.from;
      final line = lineOfOffset(text, offset);
      final protectedHere = marked.any((m) => m.state != MarkState.suggested);
      if (line >= lo && line <= hi && !protectedHere) {
        column(offset);
        return;
      }
    }

    for (final m in marked) {
      if (m.state == MarkState.suggested) {
        widget.onChoose?.call(m, event.position);
      } else {
        widget.onAsk?.call(m);
      }
      return;
    }

    // **076 — and here a press used to do nothing at all.** On ordinary text
    // it now takes the word under the pointer, which is the owner's «ضغطة
    // السلام»: the selection stops being work, and the Protect button that was
    // always there acts on it unchanged. Nothing above this line moved — a
    // press on a mark still asks «why», a press on a suggestion still offers
    // the choice, and a press inside held lines is still the column act.
    // **One click one word, two clicks one value of two** — the owner's two
    // rules of 13 October.
    //
    // The second click is the one that lands on **the word the first one
    // took**, which is a truer test than a radius in pixels: two quick clicks
    // on two different words are two single clicks, and nothing has to agree
    // on how far a hand may slip. A third click arms nothing, so it is a first
    // click again and takes one word — the owner has ruled on one click and on
    // two, and this is what three does.
    final one = wordAt(text, offset);
    if (one == null) return;
    final pair = first != null && first.start == one.start && first.end == one.end;
    final word = pair ? wordPairAt(text, offset) : one;
    if (word == null) return;
    if (!pair) {
      _firstClick = one;
      _secondChance = Timer(kDoubleTapTimeout, () {
        _firstClick = null;
        _secondChance = null;
      });
    }
    final state = _editableState();
    if (state == null) return;
    // Told, not drawn: the selection belongs to the editable, and setting it
    // here is what makes the highlight, the clipboard and `onSelectionChanged`
    // agree. A rectangle painted by this widget would have been a fourth
    // opinion about what is selected.
    // **After the arena, not during it.** This listener is outside the gesture
    // arena by design (see `_slop`), which is what lets it see the press at
    // all — but `SelectableText`'s own tap recognizer resolves afterwards and
    // collapses the selection to the point. Measured: setting it here directly
    // left an empty selection on the glass. So the word is taken once the
    // frame the press belongs to is done, and nothing can overwrite it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      state.userUpdateTextEditingValue(
        state.textEditingValue.copyWith(
          selection: TextSelection(baseOffset: word.start, extentOffset: word.end),
        ),
        SelectionChangedCause.tap,
      );
    });
    // **And the frame is asked for, not hoped for.** A post-frame callback runs
    // at the end of the *next* frame and schedules none itself. Measured,
    // 13 October: at this line on a first click `hasScheduledFrame` was
    // **false** — the word appeared only because Flutter's own tap handler ran
    // a moment later, moved the caret, and that scheduled the frame. A
    // selection the person asked for may not wait on a repaint somebody else
    // happens to want.
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    // The chance of a second click does not outlive the screen it was given
    // on; a pending timer in a disposed tree is an error a test reports and a
    // product leaks. The notifier is disposed here for the first time too —
    // `_SafeTextState` has always done it, this state never did.
    _secondChance?.cancel();
    _selectionChanged.dispose();
    super.dispose();
  }

  List<InlineSpan> _keptSpans() {
    final same = _cached != null &&
        _cachedText == text &&
        _cachedFocus == focus &&
        _cachedChoosable == (widget.onChoose != null) &&
        _cachedMarks != null &&
        listEquals(_cachedMarks, marks);
    if (same) return _cached!;
    _cached = _spans();
    _cachedChoosable = widget.onChoose != null;
    _cachedText = text;
    _cachedMarks = List<Mark>.unmodifiable(marks);
    _cachedFocus = focus;
    return _cached!;
  }

  String get text => widget.text;
  List<Mark> get marks => widget.marks;
  Span? get focus => widget.focus;
  GlobalKey? get focusKey => widget.focusKey;

  @override
  Widget build(BuildContext context) {
    // The press is read here rather than by a recognizer on each word: a raw
    // `Listener` sees every pointer event, takes part in no gesture arena, and
    // so cannot be out-voted by the text's own drag-selection. See `_slop`.
    //
    // It wraps the **text** and not the row: a `Listener` is a hit-test target
    // like any other, so scoping it here is what keeps a press in the gutter
    // from also being read as a press in the document.
    final body = Builder(
      builder: (inner) => Listener(
        onPointerDown: (e) => _downAt = e.position,
        onPointerUp: _pressEnded,
        child: _body(inner),
      ),
    );
    if (widget.onLines == null) return body;
    final lines = lineStarts(text).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **The control that takes every line**, at the head of the gutter —
        // the lead's words, 7 October. A band above the whole of it rather than
        // above the numbers alone: a band over the gutter would push the
        // numbers down while the text stayed, and every number would point one
        // row high for the length of the document.
        //
        // It scrolls away with the document, which is why the way *out* of a
        // selection is not here but in the band under the document, where it is
        // always on screen.
        AllLinesBand(lines: lines, onPressed: () => widget.onLines!(0, lines - 1)),
        // **A `Stack`, so the document decides how tall both columns are.**
        // The text is the only child that sizes the stack; the gutter is
        // stretched to it top and bottom. A `Row` would have had to be told a
        // height, and a height worked out here is a second opinion about where
        // the lines fall — which is the mistake that cost this file an
        // afternoon.
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: LineGutter.width),
              child: body,
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: LineGutter.width,
              child: LineGutter(
                key: LineGutter.gutter,
                lines: _lines,
                from: widget.heldLines?.from,
                to: widget.heldLines?.to,
                onRange: widget.onLines!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The document itself, with everything that is drawn over it.
  ///
  /// **The page's edges, drawn behind the words.** The owner, 7 October: «while
  /// reviewing, the page must show its beginning and its end».
  ///
  /// Painted rather than inserted: a widget span or a line of dashes inside the
  /// text would move every offset after it by one, and an offset that is one
  /// out is a protection in the wrong place — the mistake this project will not
  /// make twice. The reader puts a single form feed between page and page; this
  /// draws a rule where each one falls and leaves the text exactly as the core
  /// read it.
  Widget _body(BuildContext context) {
    final onSelection = widget.onSelection;
    return Stack(
      children: [
        if (text.contains('\u{c}'))
          Positioned.fill(
            key: OriginalText.pageEdges,
            child: CustomPaint(
              painter: PageEdgePainter(
                text: text,
                style: Zc.document,
                edges: edgesOfDocument(text),
              ),
            ),
          ),
        PaintSelectionOnce(
          editable: _editable,
          repaint: _selectionChanged,
          child: SelectableText.rich(
            key: _drawn,
            TextSpan(children: _keptSpans(), style: Zc.document),
            style: Zc.document,
            // **Always listened to now, even when nobody above is listening**
            // — 074/W8: the drawing of the selection is this widget's own
            // business, and it has to hear a change to redraw it once.
            onSelectionChanged: (sel, _) {
              _selectionChanged.value++;
              if (onSelection != null) {
                onSelection(
                  sel.start < 0 ? 0 : sel.start,
                  sel.end < 0 ? 0 : sel.end,
                );
              }
            },
          ),
        ),
        // Where «go to this finding» scrolls to — a zero-size box placed
        // *beside* the text at the focused line, never inside it.
        //
        // 041-K, measured: it used to be a `WidgetSpan` dropped into the spans,
        // and a placeholder span is one U+FFFC character in the text the
        // selection counts in. The span tree was 57 characters where the
        // document was 56, so every offset a person selected **after** the
        // focused finding came back one too high, and the protection landed one
        // character late: `J__Z_…` with the J still standing in the document.
        // The note above says an offset that is one out is the mistake this
        // project will not make twice; this was that mistake, found in a live
        // run and now out of the text for good.
        if (focus != null && focusKey != null)
          Positioned(
            top: _anchorAt(context, focus!.start),
            left: 0,
            child: SizedBox(key: focusKey, width: 0, height: 0),
          ),
      ],
    );
  }

  /// How far down the text the focused offset falls.
  ///
  /// Measured with the same painter that draws the page rules, and like them it
  /// is a drawing rather than a fact: the marks make some words bolder than
  /// this plain measurement knows, so a long document can be a line or two out.
  /// That is a scroll landing slightly high — not an offset, and nothing is
  /// protected from it.
  double _anchorAt(BuildContext context, int offset) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: Zc.document),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: MediaQuery.sizeOf(context).width);
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: offset.clamp(0, text.length), extentOffset: (offset + 1).clamp(0, text.length)),
    );
    return boxes.isEmpty ? 0 : boxes.first.toRect().top;
  }

  List<InlineSpan> _spans() {
    // Marks may arrive in any order and must not overlap on screen; the core
    // settles overlaps before they get here, so sorting is enough.
    final sorted = [...marks]..sort((a, b) => a.span.start.compareTo(b.span.start));
    final out = <InlineSpan>[];
    var at = 0;

    void upTo(int limit) {
      if (limit > at) out.add(TextSpan(text: text.substring(at, limit)));
      at = limit;
    }

    for (final m in sorted) {
      final start = m.span.start.clamp(0, text.length);
      final end = m.span.end.clamp(start, text.length);
      if (start < at) continue; // an overlap the core did not settle: skip, never double-draw
      upTo(start);
      out.add(_marked(text.substring(start, end), m));
      at = end;
    }
    upTo(text.length);
    return out;
  }

  /// Four marks, and two facts on every word.
  ///
  /// **The line says who decided. The wash says whether the vault knew.** They
  /// are different questions — the pack may find a name while a person chooses
  /// to protect it — and the core has kept them apart since task 034, as
  /// `Mark.decided` beside `Mark.source`. Before this the screen drew only the
  /// second, so who decided a word could be read in the Why sheet and nowhere
  /// on the word itself.
  ///
  /// ```text
  ///   solid  1.5  clay       a person decided it
  ///   dashed 1.5  clay       a layer decided on its own
  ///   wavy   2.0  amberEdge  still waiting for a person's word
  /// ```
  ///
  /// Waiting beats the source: an unanswered suggestion is wavy whoever found
  /// it, because it **is still the real text** — the whole of G12 made visible.
  /// And a suggested stretch stays unfilled for the same reason.
  InlineSpan _marked(String slice, Mark m) {
    final suggested = m.state == MarkState.suggested;
    final tint = suggested ? Zc.amber : sourceTint(m.source);
    final f = focus;
    final isFocus = f != null && f.start == m.span.start && f.end == m.span.end;
    // No recognizer here any more — see `_pressEnded`. The cursor still says
    // the word can be pressed, because it can.
    final pressable = (!suggested && widget.onAsk != null) || (suggested && widget.onChoose != null);
    return TextSpan(
      text: slice,
      mouseCursor: pressable ? SystemMouseCursors.click : null,
      style: TextStyle(
        // Translucent, so a selection drawn **under** the text still reads
        // through it. A span's background is painted after the selection
        // rectangle, which is why an opaque wash hid it: photographed on 4
        // October, a marked word inside a selection was (247, 231, 218) —
        // `Zc.clayWash`, unchanged by being selected — while the plain text
        // beside it was the blue. The owner's decision, 6 October: the washes
        // give way. Over paper they read a little lighter than before, and that
        // is the whole of the cost.
        backgroundColor: isFocus
            ? tint.withValues(alpha: 0.30)
            : (suggested
                  ? Zc.amberWash.withValues(alpha: _wash)
                  : (m.source == Source.vault
                        ? Zc.riverWash.withValues(alpha: _wash)
                        : Zc.clayWash.withValues(alpha: _wash))),
        color: tint,
        fontWeight: FontWeight.w600,
        // The line is drawn under every mark now, and it is the one thing the
        // focus does not touch: focus moves the wash, so that being pointed at
        // never changes what a mark is saying.
        decoration: TextDecoration.underline,
        decorationStyle: suggested
            ? TextDecorationStyle.wavy
            : (m.decided ? TextDecorationStyle.solid : TextDecorationStyle.dashed),
        decorationColor: suggested ? Zc.amberEdge : Zc.clay,
        decorationThickness: suggested ? 2.0 : 1.5,
      ),
    );
  }
}

/// How much of a mark's wash is left standing, so the selection can be seen
/// through it. Measured against `Zc.river` at 0.40, which is what the selection
/// is painted with.
const double _wash = 0.55;

/// The right column: what the AI will receive. Not a preview of the request —
/// the request. The text is built in Rust and handed over as it stands.
class SafeText extends StatefulWidget {
  const SafeText({
    super.key,
    required this.text,
    this.edges = const [],
    this.chips = true,
  });

  final String text;

  /// Where the pages begin **in this text**, from the core.
  ///
  /// 041-L. The owner, on the published build: «a screen with page numbers and
  /// a screen without». This column could not find its own edges — the payload
  /// has no form feed in it — so the builder reports them, and the same painter
  /// that rules the Original column rules this one.
  final List<PageEdge> edges;

  /// The rules, for the test that counts them against the other column's.
  static const pageEdges = ValueKey<String>('safe-page-edges');

  /// Chips draw each token as a small block; plain shows the literal token the
  /// model will read. Both are the same string — the boards' «Chips / Plain»
  /// switch changes how it is drawn and never what it says.
  final bool chips;

  static final _token = RegExp(r'__Z_[A-Z0-9]{4}_[A-Z]+_[A-Z0-9]{4}__');

  @override
  State<SafeText> createState() => _SafeTextState();
}

class _SafeTextState extends State<SafeText> {
  /// The same two things the Original column keeps, for the same reason: this
  /// column doubles its selection by the same 8 582 pixels, measured 12 Oct,
  /// and a fix on one of two columns drawn side by side is not a fix.
  final GlobalKey _drawn = GlobalKey();
  final ValueNotifier<int> _selectionChanged = ValueNotifier<int>(0);

  @override
  void dispose() {
    _selectionChanged.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The parent scrolls this widget.text. An inner Scrollable would swallow the wheel
    // over the whole payload and leave only a sliver of the outer sheet movable.
    final body = PaintSelectionOnce(
      editable: () => editableUnder(_drawn),
      repaint: _selectionChanged,
      child: SelectableText.rich(
        key: _drawn,
        TextSpan(children: _spans(), style: Zc.document),
        style: Zc.document,
        scrollPhysics: const NeverScrollableScrollPhysics(),
        onSelectionChanged: (_, _) => _selectionChanged.value++,
      ),
    );
    if (widget.edges.isEmpty) return body;
    // Painted behind the words for the reason the Original column's are: a
    // rule or a label **inside** the widget.text would move every offset after it by
    // one, and the widget.chips are drawn from offsets.
    return Stack(
      children: [
        Positioned.fill(
          key: SafeText.pageEdges,
          child: CustomPaint(
            painter: PageEdgePainter(text: widget.text, style: Zc.document, edges: widget.edges),
          ),
        ),
        body,
      ],
    );
  }

  List<InlineSpan> _spans() {
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in SafeText._token.allMatches(widget.text)) {
      if (m.start > at) out.add(TextSpan(text: widget.text.substring(at, m.start)));
      out.add(widget.chips ? _chip(m.group(0)!) : TextSpan(text: m.group(0), style: Zc.token));
      at = m.end;
    }
    if (at < widget.text.length) out.add(TextSpan(text: widget.text.substring(at)));
    return out;
  }

  /// A chip still spells the token out. Hiding it behind a friendly word would
  /// mean the user cannot check what the model actually reads.
  ///
  /// **Display only, and dressed as such (P2-7).** It used to be drawn with
  /// `clayWash` filled inside a `clayEdge` border — which in this app is not
  /// decoration but a meaning: it is the costume of a *chosen control*, worn by
  /// every selected language, every on-state toggle, every picked scope. The
  /// chip wore it while carrying no gesture at all, so it invited a press that
  /// could never answer, and the matching word in the Original column **does**
  /// answer one by opening «Why». A person read the difference as a bug in the
  /// program rather than as a difference between the two columns.
  ///
  /// So the border is gone and the fill is a neutral that names no state: this
  /// is a highlight over widget.text, not a button. Nothing was added to make it
  /// interactive — the Original column's mark stays the one way to ask «Why».
  /// The letters keep `clayDeep` and the mono face, because «Chips» and
  /// «Plain» must stay visibly the same string drawn two ways.
  InlineSpan _chip(String token) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Zc.lineSoft,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            token.replaceAll('__', ''),
            style: const TextStyle(fontFamily: Zc.mono, fontSize: 11.5, color: Zc.clayDeep, height: 1.3),
          ),
        ),
      );
}


/// Where each page begins in a column, in that column's own pixels.
///
/// **One function for both columns (041-L).** It is not only the painter that
/// needs these: keeping the two columns in step needs them too, and a second
/// piece of arithmetic for the same y is how two halves of one screen come to
/// disagree. So the layout is done once, here, and the painter and the
/// scrolling both read the answer.
///
/// Nothing is added to either text: the same spans are laid out at the same
/// width and asked where a character landed, so every offset stays exactly
/// what the core said it was.
List<double> pageEdgeYs({
  required String text,
  required TextStyle style,
  required double width,
  required List<PageEdge> edges,
}) {
  if (edges.isEmpty || width <= 0) return const [];
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  final out = <double>[];
  for (final edge in edges) {
    if (edge.at < 0 || edge.at >= text.length) continue;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: edge.at, extentOffset: edge.at + 1),
    );
    out.add(boxes.isEmpty ? double.nan : boxes.first.toRect().center.dy);
  }
  return out;
}

/// The edges of a document, found in the document itself.
///
/// The Original column can do this and the Safe column cannot: the reader puts
/// a single form feed between page and page, and it is still there. The payload
/// has no form feed — `build_payload` turns each one into an ordinary line
/// break, because a control character is of no use to a model — so that column
/// is given its edges by the core instead. Same shape, two honest sources, and
/// a test that holds them to the same labels.
List<PageEdge> edgesOfDocument(String text) {
  final out = <PageEdge>[];
  var page = 1;
  for (var at = 0; at < text.length; at++) {
    if (text.codeUnitAt(at) != 0x0c) continue;
    page += 1;
    out.add(PageEdge(at: at, page: page));
  }
  return out;
}

/// The two columns' page positions, aligned on the pages they both have.
///
/// A page can be in one column and not the other: a protection that spans a
/// break leaves the whole stretch as one token, and that boundary is simply not
/// in the payload. Pairing by **page number** rather than by row is what keeps
/// the two columns pointing at the same page when that happens. A position the
/// layout could not give is dropped with its partner, so the two lists are
/// always the same length and always about the same pages.
({List<double> mine, List<double> theirs}) alignedEdges({
  required List<PageEdge> myEdges,
  required List<double> myYs,
  required List<PageEdge> theirEdges,
  required List<double> theirYs,
}) {
  final theirs = <int, double>{};
  for (var i = 0; i < theirEdges.length && i < theirYs.length; i++) {
    if (!theirYs[i].isNaN) theirs[theirEdges[i].page] = theirYs[i];
  }
  final a = <double>[];
  final b = <double>[];
  for (var i = 0; i < myEdges.length && i < myYs.length; i++) {
    if (myYs[i].isNaN) continue;
    final match = theirs[myEdges[i].page];
    if (match == null) continue;
    a.add(myYs[i]);
    b.add(match);
  }
  return (mine: a, theirs: b);
}

/// Where the other column must sit so that the same place is under the eye.
///
/// **The most accurate basis available, and it says which one it used.** With
/// page edges in both columns it maps page to page and then measures how far
/// into that page the eye has gone, scaled by the two pages' own heights — the
/// pages are not the same length on both sides, because a token is not the
/// length of the name it replaced. With no edges to go by it falls back to the
/// plain ratio of the scrollable extents, which is all there is.
///
/// Pure on purpose: no widget, no layout, no pixels of its own, so the
/// arithmetic can be held to account on its own.
double inStepOffset({
  required double from,
  required List<double> mine,
  required List<double> theirs,
  required double myExtent,
  required double theirExtent,
}) {
  if (theirExtent <= 0) return 0;
  double ratio() => myExtent <= 0 ? 0 : (from / myExtent) * theirExtent;

  if (mine.isEmpty || mine.length != theirs.length) {
    return ratio().clamp(0.0, theirExtent);
  }

  // Above the first page break: the stretch from the top to that break is the
  // only thing the two columns can be measured against.
  if (from < mine.first) {
    final target = mine.first <= 0 ? 0.0 : (from / mine.first) * theirs.first;
    return target.clamp(0.0, theirExtent);
  }

  var i = 0;
  for (var k = 0; k < mine.length; k++) {
    if (mine[k] <= from) i = k;
  }
  final myNext = i + 1 < mine.length ? mine[i + 1] : myExtent;
  final theirNext = i + 1 < theirs.length ? theirs[i + 1] : theirExtent;
  final myHeight = myNext - mine[i];
  final theirHeight = theirNext - theirs[i];
  final into = from - mine[i];
  final scaled = myHeight <= 0 ? 0.0 : into * (theirHeight <= 0 ? 1.0 : theirHeight / myHeight);
  return (theirs[i] + scaled).clamp(0.0, theirExtent);
}

/// Where one page ends and the next begins.
///
/// A hairline and «Page N» across the column wherever a page starts. The same
/// painter serves both columns, because «the same numbering in both» is only
/// true if one piece of code decides what is drawn and what it is called.
///
/// It is not selectable, not protectable, and not sendable — and the last of
/// those is measured rather than assumed: `z_core/tests/page_edges.rs` proves
/// the outgoing text is byte-for-byte what it was before these edges were
/// reported at all.
class PageEdgePainter extends CustomPainter {
  PageEdgePainter({required this.text, required this.style, required this.edges});

  final String text;
  final TextStyle style;
  final List<PageEdge> edges;

  /// The width this painter last laid the text out at.
  ///
  /// Only a test reads it, and it reads it so that it measures **the layout
  /// that was drawn** rather than a width it worked out for itself — a test
  /// that guesses the width would pass while the screen was wrong.
  double lastWidth = 0;

  @override
  void paint(Canvas canvas, Size size) {
    lastWidth = size.width;
    final ys = pageEdgeYs(text: text, style: style, width: size.width, edges: edges);
    final line = Paint()
      ..color = Zc.line
      ..strokeWidth = 1;
    for (var i = 0; i < ys.length && i < edges.length; i++) {
      final y = ys[i];
      if (y.isNaN) continue;
      final label = TextPainter(
        text: TextSpan(text: 'Page ${edges[i].page}', style: Zc.tiny.copyWith(color: Zc.ink4)),
        textDirection: TextDirection.ltr,
      )..layout();
      const gap = 10.0;
      canvas.drawLine(Offset(0, y), Offset(size.width - label.width - gap * 2, y), line);
      label.paint(canvas, Offset(size.width - label.width, y - label.height / 2));
    }
  }

  @override
  bool shouldRepaint(PageEdgePainter old) =>
      old.text != text || old.style != style || old.edges != edges;
}

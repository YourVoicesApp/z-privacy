# 074/W8 · A character with no ink has no selection box

**The lead, 9 Oct 2026, night.** W8 began as «strip the `\r` when drawing» and
died: the programmer measured the PDF and this seat measured the glass, and a
carriage return changes nothing a person **reads**. It comes back under a
narrower name and a smaller scope — **the drawing of the selection, and nothing
else**: not the text, not the offsets, not one byte of content.

Two rulings came with it, and the first closes a door this paper must not
re-open:

- **No normalising line endings on the way in.** «Protection may not change how
  a document reads» has a brother: *restoration gives back the owner's bytes,
  with their line ends as they wrote them.* Reading is already sound, so there
  is no fault to buy that price with.
- **The pin stays an honest record**, not a wish, until the fix flips it.

## What was measured, and how to repeat it

`apps/flutter_app/test/a_carriage_return_draws_nothing_test.dart`, and

    Z_W8_DUMP=/some/dir flutter test test/a_carriage_return_draws_nothing_test.dart

writes every drawing as a PNG. It needs no native library and no built bundle.

**Read, there is nothing.** Five surfaces — the document column with its
gutter, the payload column, the review sheet's sentence, the answer's restored
text, the chat composer a letter is pasted into — each drawn twice, CRLF
against its LF twin: **identical pixel for pixel**, the same rows at the same
y. The rows matter beyond the eye: the gutter paints its numbers against
exactly those tops.

**Selected, there is this.** In the **document column**, on its own page and in
the product's own colours, a selected CRLF document carries **8 582 pixels of
the twice-painted selection colour** where its LF twin carries **none** — a
darker block at the end of every line. The **chat composer** carries none, and
not because it is safe: see candidate 1.

## The fault is the doubling, not the tail — and the mechanism is read, not guessed

A selection that includes a newline **already** draws a tail past the last
letter: in the LF twin the newline's box runs to the right edge of the text
block. That is ordinary and is not the defect.

`RenderEditable`'s selection painter takes `getBoxesForSelection(...).toSet()`
and then draws **one translucent rect per box**
(`flutter/lib/src/rendering/editable.dart:2914`). `toSet()` removes only boxes
that are **identical**. A selected carriage return makes the engine hand the
painter an aggregate box for the line's tail *and* the two parts inside it —
`248.8..322.3`, `248.8..257.7`, `257.7..322.3` on row 0 — which are not
identical. Eleven boxes where the LF twin has five, and no pair of those five
overlaps. At `Zc.river` alpha 0.40 (`main.dart:42`, itself a measured choice),
paint over paint is a darker colour.

So the defect is **one `drawRect` landing on another**, and the whole of the
answer is to stop that happening — on the platform we are about to ship to,
where CRLF is the habit and selecting text is a daily act.

## What may not move, and how that is proven

The text, the offsets, the core's spans, the marks, the gutter's `lineStarts`,
what the clipboard receives, and the bytes of a saved PDF. This project has
paid once for an offset that was one out — 041-K's placeholder span, one U+FFFC
in the span tree, every selection after it one too high and a protection
landing a character late. **Nothing in this item may touch the string being
drawn.**

The proof is already written: the «read» group and the PDF group of the file
above must stay green and unchanged through the fix. If either moves, the fix
has left the drawing and entered the document.

## The candidates — one is already measured out

1. **~~A knob that already exists~~ — measured 9 Oct, and it is dead.**
   `selectionHeightStyle` and `selectionWidthStyle` are on all three widgets we
   use. Measured against the twins at every combination: `BoxWidthStyle.tight`
   (today's default) leaves the composer clean and the column doubled;
   `.max` **doubles the composer too** (1 485 px) and does not help the column.
   `BoxHeightStyle` changes nothing. The knob is not a fix — it is a way to
   spread the defect, which is why it is now pinned as a warning rather than
   left as an idea.

2. **An opaque selection colour.** Paint over paint only darkens because the
   colour is translucent. `Zc.river` at 0.40 over `Zc.paper` composites to
   **`#A0B7CC`**; drawn opaque, one layer looks the same as three. One line, no
   geometry touched — but it changes what a selection *hides*, and that is a
   measurement, not a guess: the page-edge rules this column paints **behind**
   the text, and the amber wash behind a suggested mark. Whether a span's
   `backgroundColor` paints above or below the selection is a fact of the
   engine; measure it on a page, do not reason about it. If both survive, this
   is the whole item.

3. **Our own highlight, if 2 does not survive.** A pure function — boxes in,
   rectangles out — merging every pair that overlaps on one row, so a character
   with no ink adds no second layer; then the built-in highlight made
   transparent for that column and the merged rectangles painted behind the
   text. Testable with no widget at all, and the test is already half-written:
   the pin counts overlapping pairs today. Two cautions from this repository's
   own history: paint **only what is inside the canvas's clip**, as the gutter
   does, because 048 measured documents of 82 468 lines; and take the colour
   from the theme rather than restating it, because a colour written twice
   drifts.

**The order of work:** measure candidate 2 on a page — one drawing with a
suggested mark in it and one with a page rule in it — and bring the two
pictures back before any widget code. If it holds, the item is a line and a
comment. If it does not, design 3 and bring that back before writing it.

## The shape of done

- In the document column, **no pixel is painted twice** in either twin: the
  count that is 8 582 today is 0, and the LF twin's 0 is unchanged.
- The composer's two counts unchanged — 0 at `tight`, and the `.max` warning
  still standing, because the fix must not quietly depend on a default.
- The three pins **flip**, rewritten to assert the new truth with both halves
  of the history in their comments. A fault nobody wrote down is a fault nobody
  can prove was fixed.
- The «read» group and the PDF group unchanged and green — which is what says
  the fix stayed in the drawing.
- Gates green, with the Dart count left to the merging hand.

## Three notes from the measuring round that belong in the record

**A break that bites a different line proves nothing — and it is harder to
notice than a break that does not bite, because it is already red.** Testing a
new per-surface control, the subject was broken by making it ignore its text
outright; it went red with «no editable on screen holds Hedvig», which is the
test's own marker lookup failing and says nothing about the claim under it.
Re-broken so the surface undid the one-letter change and kept everything else,
and only then did the right control speak.

**«Two byte-identical PDFs» is not a property this product can have.** `pdf`
3.13.1 builds `/ID[<…><…>]` from the clock and 32 secure-random bytes
(`document.dart:180`): the same document written twice differs in **122 of its
14 524 bytes**, every one of them inside those brackets. A guard asserting
whole-file identity would have been red for ever for a reason that has nothing
to do with the subject — the mirror of being green for one. What is claimed,
and what the guard asserts, is identity **of everything but the one named
value**, with the guard refusing to run at all if it does not find that value
exactly once.

**A colour claim without an opaque ground is not a claim about what anybody
sees** — mine, and the reason half of this paper was nearly written about the
wrong surface. A `RepaintBoundary` captures what is inside it and nothing
behind it, so a drawing made without a page under it comes back with
accumulated alpha for a viewer to composite later: two translucent layers
*look* darker in the PNG while being nothing of the sort on a page. The first
pictures of this defect were taken that way. Measured again with the page
painted inside the boundary and the product's own theme, the composer turned
out clean and the document column turned out worse than reported. **Render it
and look** found the fault and then nearly hid it: look at a picture a person's
screen could actually show.

## 10 Oct, afternoon — the drawing's design, measured not guessed (by the design seat, recorded by the lead)

The owner chose candidate three. The arithmetic half is BUILT and green alone:
`paintedOnce(Iterable<Rect>)` in `document_text.dart` (commit `242193a` on
`fix/the-selection-is-painted-once`, over `5eda2ef`) — groups by row (tops
equal within a pixel, which is what the engine emits), unions overlaps per
row. Five guards; two breaks seen to bite; the claim that matters is the
second one: **the union out equals the union in** — a selection that grows
or shrinks a pixel is worse than the defect.

The second half, for whichever session continues, measured already:
1. Silence Flutter's own selection paint **in the document column only**
   (wrap with `TextSelectionTheme`/`DefaultSelectionStyle`, transparent) —
   the global theme stays: the chat field measured ZERO double-paint.
2. Draw the merged rectangles **behind the text** in the same `Stack` where
   `PageEdgePainter` already draws — the precedent exists, no new structure.
   `_drawn` key yields the `RenderEditable`; `onSelectionChanged` already
   fires; the colour comes FROM the theme, never rewritten (a colour written
   twice drifts).
3. Two warnings from the paper: draw only inside the panel's clip (048
   measured 82,468-line documents); recompute boxes on selection change, not
   per frame.
4. Done, as numbers: 8,582 → 0; the LF twin stays 0; the three pins FLIP
   (rewritten, not deleted, both halves of their history in the comment);
   the page rule and the amber wash visible under a live selection; a
   before/after picture in this paper at the same scale as the decision pair.

## 12 Oct — BUILT, and the scope widened by a measurement (recorded by the lead)

`b5492f4` on `fix/the-selection-is-painted-once`, full dart suite 292/0 in
the builder's tree. The numbers, as the paper demanded them:

- **8,582 → 0** in the document column; the LF twin stayed 0.
- **The third sibling was measured before the first line**: the payload
  column — covered on the 9th by the READING claim only — doubles with the
  SAME 8,582. Both columns wear the fix; «the column alone» would have left
  the defect standing beside its cure on one screen.
- The pins flipped rewritten, both halves of their history kept — and ONE
  deliberately did not flip: the engine still hands overlapping boxes, and
  the day it stops is the day this code is deleted; that pin is how anyone
  will know.
- **The owner's constraint held structurally**: the selection stays
  translucent. The opaque colour he refused was chased with three breaks —
  two passed it for reasons the pictures explained (the rule fell OUTSIDE /
  UNDER the selection, not inside it), the third did not bite and was
  DELETED rather than shipped, its record left in place.
- `selection_is_visible_test` re-seated, not excused: three guards asked the
  widget for a colour that is now transparent by design; the question moved
  to the theme — where the painter reads and where the owner's original
  complaint pointed — and the in-file pixel test that photographs the blue
  during a drag passed untouched: the colour still reaches the glass.
- Before/after at the decision pair's scale:
  `~/work-now/selection-colour/w8-before-and-after.png`.

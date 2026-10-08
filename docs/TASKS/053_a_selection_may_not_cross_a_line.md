# 053 · A selection may not cross a line

The owner, from a live run on `FarukAB_lonekorning_feb2027.txt`, looking at his
own screen: *«here is our selection problem — if there is no dot or anything it
takes the space, and then the same value becomes hard to find anywhere else.»*

He is right, and it is worse than he said.

## Measured

`text::whole_words`, at the unit, on his own line:

```
end   +0  →  "559000-0000"
end   +1  →  "559000-0000"              ← the newline alone is tidied away
end   +2  →  "559000-0000\nAdress"      ← and here it stops being a value
start -0  →  "Adress"
start -2  →  "559000-0000\nAdress"      ← the same, mirrored
```

End to end, in **his exact configuration** — English pack, Swedish document, so
the organisation number is not found by any rule and he must protect it by hand:

```
overshoot 1 :  Organisationsnummer: __Z_BEAE_CUSTOM_9A04__
               Adress: Storgatan 1, 100 00 Stockholm

overshoot 2 :  Organisationsnummer: __Z_E2BF_CUSTOM_5D27__: Storgatan 1, 100 00 Stockholm
```

## Three harms, not one

1. **The value stored is `559000-0000\nAdress`.** It will never match that
   organisation number again — not in this document, not in tomorrow's, not
   under `Profile` or `Always`. This is what the owner felt.
2. **The document that leaves has changed shape.** Two lines became one and the
   word `Adress` is gone from what the model receives. That is a direct breach
   of the rule adopted 7 October: **protection may not change how a document
   reads.** A model asked to reconcile a table is now reading a table we edited.
3. **The drawing and the act disagree, in both directions.** At overshoot 1 the
   act silently *shrinks* the person's selection; at overshoot 2 it silently
   *grows* it.

   ~~The screen shows neither: `as_whole_words` lives in the core and nothing in
   the Flutter app ever calls it.~~ **Measured false, 8 October, and the way it
   was got wrong is the lesson: the grep was for the function's *name*, not for
   the behaviour.** The app does ask, and it already redraws:
   `document_text.dart` → `workspace.dart:1237` → `bench.select()` →
   `inspect_selection`, and `session_state.dart:452-457` sets
   `selection = view.wordSpan` with 041-K's reason written beside it. So the
   highlight is not the raw drag; it is what Protect will take.

   What is left of this harm is real and smaller: the act was taking the **wrong
   span**, and the screen was faithfully drawing the wrong span. Fixing the span
   fixed both — and it is what lets the first cost below be accepted, because a
   person sees the clipped selection before pressing.

## Why

`whole_words` rule 1 grows each edge outward while `cuts_a_word` is true, and
`cuts_a_word` looks only at the character on each side of the boundary:

```rust
word_side(before, far_before) && word_side(after, far_after)
```

Standing inside `Adre|ss`, both sides are letters, so it grows to the whole of
`Adress` — **nothing ever asks whether the selection crossed a line to get
there.** Rule 2 then trims whitespace from the edges, which is why an overshoot
of exactly one character (the newline) comes out clean and hides the rest.

And the start edge is the common one. The function's own comment says so: *«at
the left margin the mouse lands after the first character, every time»* — the
very case rule 1 exists to fix is the case that now reaches backwards over a
line break.

## Do

1. **A hand selection may not cross a line break.** A value is a thing on one
   line — and 046/C already says a name ends where the name ends.

   ~~Rule 1's outward growth stops at `\n` on both edges.~~ **That would have
   changed nothing, and it is checkable in two lines:** `is_word('\n')` is false
   and `joins_a_word('\n')` is false, so `cuts_a_word` has *always* returned
   false at a line boundary. The growth never crossed a break — in both of the
   owner's cases the break is already inside the span he drew and the growth
   happens on its far side. Two characters past the number, the end edge stands
   between `A` and `d` and the newline is never consulted.

   So: a **rule 0, before anything grows.** A span drawn across a line break is
   cut down to the line it holds most of; rules 1 and 2 are untouched. «Most of
   it» is counted in characters and not bytes — four Arabic letters are eight
   bytes and would outweigh six Swedish ones — and only the characters that are
   not space, because a column of padding and the form feed that marks a page do
   not get to vote on which line a person meant.

   **A page break counts as a line break here**, with no exception, and that
   took a measurement rather than an argument — see «The crossing that nearly
   became an exception» below.
2. **Guards, and they must bite today:**
   - the unit: `end +2` and `start -2` on the owner's line both return
     `"559000-0000"` and `"Adress"` respectively;
   - end to end, English pack on the Swedish file: after an overshoot of two,
     `Adress: Storgatan 1, 100 00 Stockholm` is still its own line in the
     payload, character for character;
   - and the property that covers the whole family: for a single hand
     protection, `payload == original[..start] + token + original[end..]`.

     ~~Which `the_token_stands_where_the_value_stood.rs` already asserts — it
     does not yet run on an overshooting span. Add that case there.~~
     **Measured: that property is green on this defect and cannot see this class
     at all.** It rebuilds its expected side from `view.marks` — the core's own
     spans — so a span read too wide widens the expectation with it. That is not
     a flaw in the file: «the core checked against the core» is its own comment,
     it is what catches an offset read in the wrong units, and it is built for
     both sides being wrong together.

     The case belongs there, stated against **the document** instead: the
     value's own stretch replaced, not the stretch the core settled on. Red
     before, green after. **The shape to carry forward: a guard whose expected
     side is computed from the subject under test can only catch disagreement,
     never a wrong answer both sides share.**
3. ~~**Then make the screen tell the truth.**~~ **Already true, measured** —
   see harm 3 above. The selection redraws to `word_span` when a drag ends, so a
   person sees exactly what will be protected before the press. Nothing was
   needed on the Dart side for this item.

## And what the screenshot also shows

`PACK English` on a Swedish payroll file. `Organisationsnummer: 559000-0000` and
`Adress: Storgatan 1, 100 00 Stockholm` both leave **in the clear** because no
English rule knows those labels. That is 038-B, already written, and this is the
first time it has cost the owner a hand protection on film. It also means the
banner's «63 protected automatically · 0 need your word» is counting a document
it is only half equipped to read.

## Built — 8 October

`89a7558` and `eb52bc7` on `fix/053-a-selection-may-not-cross-a-line`, in a
worktree detached from `82d5858`, the build the owner is attacking. The table
above, measured again through `inspect_selection` — the door the bubble draws
from — before and after:

    end   +0  →  "559000-0000"             "559000-0000"
    end   +1  →  "559000-0000"             "559000-0000"
    end   +2  →  "559000-0000\nAdress"     "559000-0000"
    end   +3  →  "559000-0000\nAdress"     "559000-0000"
    start -0  →  "Adress"                  "Adress"
    start -1  →  "Adress"                  "Adress"
    start -2  →  "559000-0000\nAdress"     "Adress"
    start -3  →  "559000-0000\nAdress"     "Adress"

End to end on his own file, English pack, two characters past the number: the
payload said `Organisationsnummer: __Z_…__: Storgatan 1, 100 00 Stockholm`, and
now `Adress: Storgatan 1, 100 00 Stockholm` is its own line again, character for
character. Gates 280 PASS / 0 FAIL / 0 SKIP. Rust 519 passed / 0 failed over 66
binaries, sixteen of them new.

Breaks on purpose, each biting only its own guard: rule 0 removed → five red
plus the property case; the first line chosen instead of the longest → two;
measured in bytes → the Arabic one alone; a run of spaces allowed to be a
candidate → the column one alone; and the swallowed-break count removed from
`payload.rs` → 041-L's re-arranged test alone.

### The crossing that nearly became an exception

041-L promises the opposite for a **page** break: a selection may cross a page
boundary, the stretch leaves as one token, and the page after it keeps its own
number. The reader leaves a form feed with an ordinary newline beside it, so
every crossing of a page break is a crossing of a line break, and the two rules
meet head on. Rule 0 first stood aside for a span holding `\u{c}` — found by
`a_swallowed_break_does_not_renumber_the_pages` going red, not by reading — and
that was the easy answer and the wrong one: **the crossing was that test's setup,
never its claim.** Its claim is the numbering.

Measured instead. The scanner's pair rule cannot stand in: 038-I makes it refuse
a page break on purpose, and
`a_name_broken_across_lines.rs::the_pair_rule_does_not_read_across_a_page` has
said so since. But `occurrences` matches an **exact value** over
`whitespace_run`, and `is_whitespace` is true for U+000C:

    edges before      [2, 3]
    one hand selection of a name on a line of its own, crossing nothing
    protect every place  →  Applied { places: 2 }
    edges after       [3]          page three still says three
    form feed left in the payload  false

So the test keeps its subject with no hand crossing anything, and rule 0 needs no
exception. The three rules now say one coherent thing:

- the scanner's **pair rule** may not read across a page break (038-I);
- a **hand selection** may not either (this item);
- an **exact value the person pointed at** still may — which is the whole of the
  difference between a value and a guess.

### What the rule costs, pinned as tests rather than written here

A value the **document itself** wrapped — «Sven\nNelander», a name an extracted
PDF broke over a line end — is now protected by its longer half: «Nelander»
goes, «Sven» stays in the clear. That is a leak this item introduces, and it is
asserted on purpose in `a_selection_may_not_cross_a_line.rs`, because a property
nobody wrote down is a property nobody can prove changed.

It is accepted for three measured reasons: 038-I means the commonest instance, a
personal name the page wrapped, is already found and protected whole by the
scanner before any hand touches it; the screen redraws to the clipped span, so
the person **sees** that only «Nelander» is taken before pressing; and the harm
it replaces was silent, constant and changed the document, while this one is
visible and does not. The alternative — clipping only when an edge cuts a word —
would keep this selection whole and would let a *deliberate* two-line selection
through, which is the original harm wearing a different hat. A named choice for
the owner, not a surprise.

Also not delivered, and named: 038-B, the English pack reading a Swedish file,
is why he was protecting this by hand at all. A selection drawn across five
table rows now takes the longest row — the same shrink as the wrapped name,
visible for the same reason, not pinned separately.

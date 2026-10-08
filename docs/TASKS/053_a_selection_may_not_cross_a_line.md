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
   *grows* it. The screen shows neither: `as_whole_words` lives in the core and
   **nothing in the Flutter app ever calls it**, so the highlight is the raw
   drag and the act is something else. Against our own rule — *one source of
   geometry, and it is the drawing* — the drawing is not even consulted.

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

1. **A hand selection may not cross a line break.** Rule 1's outward growth
   stops at `\n` on both edges; rule 2 is unchanged. A value is a thing on one
   line — and 046/C already says a name ends where the name ends.
2. **Guards, and they must bite today:**
   - the unit: `end +2` and `start -2` on the owner's line both return
     `"559000-0000"` and `"Adress"` respectively;
   - end to end, English pack on the Swedish file: after an overshoot of two,
     `Adress: Storgatan 1, 100 00 Stockholm` is still its own line in the
     payload, character for character;
   - and the property that covers the whole family: for a single hand
     protection, `payload == original[..start] + token + original[end..]`, which
     `the_token_stands_where_the_value_stood.rs` already asserts — **it does not
     yet run on an overshooting span.** Add that case there.
3. **Then make the screen tell the truth.** The act must hand back the span it
   used, and the selection must redraw to it, so a person sees exactly what will
   be protected before and after the press. Until it does, the app is correcting
   people silently and they are right not to trust it.

## And what the screenshot also shows

`PACK English` on a Swedish payroll file. `Organisationsnummer: 559000-0000` and
`Adress: Storgatan 1, 100 00 Stockholm` both leave **in the clear** because no
English rule knows those labels. That is 038-B, already written, and this is the
first time it has cost the owner a hand protection on film. It also means the
banner's «63 protected automatically · 0 need your word» is counting a document
it is only half equipped to read.

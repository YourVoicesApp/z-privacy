# 051 · The round trip is proven — and the one thing it cannot see

The owner's second strike from `~/ztest/ATTACK.md`. He fed the German letter to
Z, sent the protected text to a model with two questions — *how many names are
left*, and *give me a summary that reuses some tokens, so we can test the
restore* — and pasted back what his screen showed.

## 1 · It passed, and it passed on a measurement, not on a report

| | |
|---|---|
| tokens that left | **28** occurrences, **25** distinct |
| namespaces | **one** (`4B2D`) — 046/U holds |
| tail length | 8 hex on all 28 — 046/U holds |
| distinct people | 7, one of them twice (sender and signature) |
| person names left in the clear | **0** |
| values the model's summary used | 13 |
| **values Z put back, verbatim** | **13 of 13** |

Verified against `z_core/tests/fixtures/Brief_Weber.txt`, our own letter — every
one of `Markus Weber`, `Tobias Reinhardt`, `Bahnhofstraße 27`,
`Lindemann & Partner GmbH`, the IBAN, both phone numbers, the e-mail,
`Lindenstraße 8`, `86150 Augsburg`, `L01X00T47`, `A-MW 2041`,
`Weber Elektrotechnik GmbH` and `7733-9120` is in the source letter, character
for character.

And the property the owner was actually testing: `PERSON_A5766888` stood in
**two** places in the answer, and came back **the same name in both**. Identity
is stable across one answer.

This is the first end-to-end proof of the whole product on a real document
through a real model: letter → 25 tokens → a model that never saw a name → an
answer in a third language → 13 values back, exact. **It is the film's climax,
and it is now a fact rather than a hope.**

**Do:** make it a guard. An end-to-end test over `Brief_Weber.txt` that protects,
builds the payload, feeds back an answer which reuses one person token twice, and
asserts every restored value against the fixture and the two occurrences against
each other. The unit tests in `round_trip.rs` cover the pieces; nothing covers
the chain on real data.

## 2 · My own error, recorded because the paper is the history

I counted the tokens in the text he pasted, found **zero**, and reported that
nothing came back. The text he pasted was the **restored** view: it has no tokens
*because the restore succeeded*. I measured the scar and called it the wound.
The model's note — *«the summary reused token `A5766888` twice»* — described its
own output **before** restore, which I never saw, and I called the claim false.
It was not.

**The rule:** when the subject is a round trip, name **which leg** you measured.
A count of tokens means one thing in the payload and the opposite in the answer.

## 3 · The gap that is still real — and what is *not* measured about it

Z reports every token in an answer it **cannot resolve** (`unknown_tokens`,
046/U). It has no field for the opposite: tokens that were **sent and did not
come back**. `grep` over the core and the app finds no sentence for it.

So if a model ever answers with invented values **in place of** the tokens — a
thing weaker models do — the answer has no token, Z restores nothing, and nothing
is said. `answer.dart:342` marks a restored value with a clay wash and a dotted
underline, so a restored name *is* visibly restored; an invented one is
`Piece::Words`, plain. The two differ only by the **absence** of a mark, which is
the one thing a reader does not notice.

**What is measured:** the capability is absent — no count, no sentence.
**What is NOT measured:** that any model we ship with actually does it. This
experiment did the opposite. Do not write this paper up as a defect that was
seen.

**Do**, in this order, and only after item 1:
1. `AnswerSnapshot` gains `tokens_sent` and `tokens_returned` for the document,
   both derived by scanning the text that was sent — nothing new stored.
2. The band 046/U already built says the count when it is worth saying:
   `returned == 0 && sent > 0` → *«This answer brought back none of the 25
   tokens from your document — every name in it is the model's own.»*
   Otherwise, silence: a summary legitimately uses a few.
3. Guard, and it must bite: an answer with zero tokens into a conversation that
   sent 25 must raise the band. Against today's code it fails.

## 4 · Two debts the letter showed, measured

- `Kundennummer 7733-9120` → **protected.**
  `Rechnung Nr. 2026-04471` → **in the clear, twice in the letter and three
  times in what left.** Same kind of fact — the string an office looks a client
  up by — opposite fate. **A debt.**
- The branch street → protected; `80335 München` → in the clear. The postcode
  survives the street.
- `geboren am <BORN>` protected, `in Augsburg` in the clear. The pair is broken,
  which is enough. A **question** for the owner, not a defect: does a birthplace
  belong in the shapes?

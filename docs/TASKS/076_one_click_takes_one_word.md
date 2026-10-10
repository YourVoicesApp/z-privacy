# 076 · One click takes one word: «ضغطة السلام»

**The owner, 10 Oct 2026, midday.** He found the big one himself: select a
whole line, press Protect, and the line becomes ONE token and ONE vault entry
— a blob. Search cannot find «Margaret Wilson» inside it, the same name
elsewhere takes a different token (046/U derives the token from the value,
and the blob is a different value), and an answer that mentions one cell maps
back to nothing.

My first sketch was a table workshop — parse CSV, decompose a selected row
into cells. He killed it with one sentence, and his design is better:

> **«الضغط على الاسم بالماوس من داخل النص يحدده فقط الاسم... لا جداول ولا
> أسطر ولا أعمدة — ضغطة السلام»**

One click inside the original text selects exactly the word under the
pointer. Nothing else changes: the Protect button is already there, the flow
is the old flow, the selection just stopped being work. And he names the
second gain himself: it separates the first name from the family name —
**each part is its own identity, its own token, stable wherever it appears**
— which is exactly what 046/U always wanted the value to be.

This serves the film's CSV files without a parser: a cell is a word or two,
and each click teaches one of them. The EN-3 scene («احم العمود بالمثال»)
keeps its own door and is NOT this paper.

## The design, small on purpose

1. **A single click in the ORIGINAL column selects the word under the
   pointer.** The word boundary is the text system's own (the same ICU
   segmentation the editor uses for double-click), one named function, so it
   is equally honest in Arabic, German, Swedish and English — no regex of
   ours decides what a word is (a checksum may not decide who is hidden, and
   neither may a hand-rolled boundary).
2. **Everything after the click is the existing path**: the selection feeds
   Protect exactly as a drag would. No new core API — `protect` on a span is
   already the door. Core does not change in this paper unless measurement
   says the glass cannot know the boundary honestly.
3. **Drag selection stays** for phrases, under its old law (a hand selection
   may not cross a line break). Line-blob protection remains possible and
   remains a blob — the click is the paved road, not a wall.
4. **Protection may not change how a document reads** — untouched by design:
   the click only selects.

## Measure before building

- What a click does TODAY in the original column (does it move a caret, open
  anything, fight the drag?), each with file:line.
- The word-boundary function the glass already owns, and what it yields on:
  «Margaret», «Ashford & Mills Ltd» (three clicks, three words — correct),
  German compounds, an Arabic name, a hyphenated name, a number like
  «884 210» (two clicks — correct; the owner teaches by example).
- The pin for the blob problem as it stands: one line selected+protected ⇒
  one vault entry, counted — so the paper's claim has a before.

## The shape of done

Click a name in the glass → that word alone is selected → Protect seals it →
the vault holds the word as its own value, the same word elsewhere takes the
same token, search finds it, pull-back resolves it. Measured on the film's
own CSV (five clicks on five names), guards on the boundary function and on
the click path, and the blob pin flipped into the story.

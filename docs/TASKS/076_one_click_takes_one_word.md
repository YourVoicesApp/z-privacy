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

## 13 Oct — the owner's rules for selection (sealed, his words carried)

After the lead reviewed the Carlos film frame by frame (the hand path on `FarukAB_team_EN.csv`: 0 auto, five names, each a drag → the «Protect this» dialog with 13 kind chips and «How far» → Protect), the owner set the rules. **They replace design point 1 above** (the ICU word boundary): the boundary is the owner's, stated plainly.

1. **One left click selects one word.** The word begins right after a space and ends right before the next space. **The space is never part of a one-click selection.** Left button, not right.
2. **Two clicks take a word, the space, and the next word** — one value of two words (a first and a family name in one act).
3. **Press and hold follows the mouse** — the drag, under its old law (a hand selection may not cross a line break).
4. **The punctuation filter.** At protection time the marks `. ، - ' " : ; ,` standing at the **edges** of the selection are left **outside** the value: «Wilson,» protects «Wilson» and the comma stays in the text, in the clear, where it was. The person never trims a selection by hand. A one-click selection on «Wilson,» shows «Wilson» selected and the comma apart.
   - **Lead's reading, to confirm with the owner:** edges only — a mark *inside* a word stays in it («Anne-Marie», «O'Brien», «Al-Harbi» stay one value). The filter trims; it does not split.
   - The filter is **one function in the core**, used by every door that protects a span (click, double-click, drag) — a rule written in place is not applied to its second case.

## Guards

- One click on «Margaret» in «Margaret Wilson,person» → exactly «Margaret»; on «Wilson,person» → «Wilson,person» is one space-delimited word, filtered at its edges only — measured and shown to the owner before it is called done (a CSV cell is the case where comma is *inside* the space-word; the owner's rule as written takes the whole space-word).
- Two clicks on «Margaret» → «Margaret Wilson,person» → filter → the value the owner expects: to be shown to him on the glass.
- Every mark in the list, at the start and the end, in de/en/sv/ar text: kept out of the value, present in the text.
- Arabic «،» measured in an RTL line.

## Proposals still open (the lead's, not yet ruled)

- Protect in one press, kind guessed (else Person), scope «here»; the big dialog only behind «More».
- One value protected everywhere in the document at once (`protect_all_matches` exists).
- Undo by one click on the protected word.
- Detection obeys the same edges: the film shows IBAN «SE45 5000 0000 0583 9825 7466 **on 2**» — the detector swallowed two words of the date; and the reason line called «Ltd» «a German legal form» in an English document. Two detection defects, proposed as a small separate round.

## 13 Oct — the filter, ruled exactly

The owner: **«تحذف فقط إذا متبوعة بمسافة أو مسبوقة بمسافة»** — a mark from the list is left out of the value **only when a space follows it or precedes it**. «Wilson, » → «Wilson»; «"Margaret» after a space → «Margaret»; «Anne-Marie», «O'Brien», «Wilson,person» → untouched, one value each.

- **Lead's reading, to measure and show:** the start and end of a line count as a space (a name at a line's end followed by «.» and the line break loses the dot).
- **Consequence to show the owner on the glass, not to decide for him:** in a CSV cell «Wilson,person» the comma touches no space, so one click takes «Wilson,person» whole. If he wants the cell's value alone, that is a new ruling, not a reading of this one.

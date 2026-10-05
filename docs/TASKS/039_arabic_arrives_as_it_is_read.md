# 039 · Arabic arrives as it is read

**Status: ORDERED, after Phase 4** · 5 Oct 2026 · lead → the builder the owner names · branch `fix/arabic-arrives-as-it-is-read` from `main` · **the first step of the Arabic pack, and a reader step, not a pack step.**

## Why

The owner's demo for Doha: a list of the characters of «كليلة ودمنة» taught into Z, the book put in, the names protected — «our own lists work», in Arabic, with no dictionary. Measured on `08b04aa` (`docs/THE_NUMBERS.md` §4.3): the taught layer finds **7 of 7** people in an Arabic letter given as text, and **0 of 461** in the same book given as the PDF — because the reader hands the scanner the PDF's glyph codes as they are: **205 434 Arabic presentation-form characters** (U+FB50–FDFF, FE70–FEFF) in **visual order** (the string reversed). The book's title word: 0 raw, 180 after folding and reversing. poppler reads the same file into 180 / 209 / 67 in logical order, so the file is not the problem.

## What to build

1. **Fold presentation forms** in `z_core/src/documents/pdf.rs` where a font's codes become characters: a character in the two presentation blocks becomes its NFKC form (the crate `unicode-normalization` is already a dependency; no new crate). Lam-alef ligatures (`ﻻ` and kin) become two letters. The fold is the reader's, so `DocumentView.text` is what the scanner and the screen both see, and spans stay consistent — measure that a mark drawn on a folded word lands on the right glyphs on screen.
2. **Logical order**: a line whose characters came out right-to-left-reversed is turned round before it leaves the reader. Smallest honest rule first: within a line, a run of right-to-left characters is reversed as a run, and runs of digits and Latin letters inside it keep their own order; measure on the book and on an Arabic letter saved as PDF from a word processor (the owner can make one) before deciding whether the full bidi algorithm is needed. **Do not reorder `.txt` or `.docx` text** — they arrive logical already (AR-1 proves it).
3. **Match through the vowel marks**: a vault value and a taught name compare with the Arabic combining marks (U+064B–U+0652, U+0670, tatweel U+0640) removed from both sides, while the span covers the marked text as written. That is the 461 → 562 step.
4. **Nothing else**: no Arabic rule, no honorific, no company form — those are the pack's, after this.

## Done means

- Red first: `the_arabic_book.rs` (golden six from task 038) was written to go red when the reader is fixed; flip its assertions to the new truth: presentation forms **0**, the title word **≥ 180** raw.
- With five characters taught (the fixture list in the test, Person · always), the book scans to **Person auto 461** with marks kept and **562** with step 3; a new test on AR-1 saved as PDF (the owner's file or a `.docx` printed to PDF in the test's own setup) finds its 7 taught people.
- Every German and Swedish number in `docs/THE_NUMBERS.md` unchanged to the digit (the fold touches only the two presentation blocks; a test asserts Latin text passes the fold unchanged).
- `cargo test`, gates, clippy: counts before/after; nothing of a document printed by any test.

## Not in this task

- The Arabic pack's own rules (honorifics, kinship particles, company forms, Gulf phone and ID shapes).
- The substring question for short names inside longer words (named in §4.3; a pack decision).

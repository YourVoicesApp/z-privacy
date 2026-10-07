# 038-C · Arabic arrives as it is read

**Status: WAITING — after Phase 4, third of the three measured debts (the owner's order, 5 Oct night); with 038 it forms the quality/ingestion step that precedes the Arabic pack.** · lead → the builder the owner names · branch `fix/arabic-arrives-as-it-is-read` from `main` · **an ingestion step, not a pack step.**

The owner (5 Oct, night): «هذا القياس حسم لنا مسألة العربية قبل أن نكتب سطرًا واحدًا من Arabic Language Pack: محرك Z والقوائم الشخصية قادران أصلًا على التعامل مع العربية؛ العطل في طبقة إدخال PDF.» And: «لا نبني الحزمة العربية قبل إصلاح طبقة القراءة. وإلا سنقيس فشلًا في اللغة بينما المشكلة في أن النص نفسه وصل إلى Z مشوهًا.»

## Why

The owner's demo for Doha: a list of the characters of «كليلة ودمنة» taught into Z, the book put in, the names protected — «our own lists work», in Arabic, with no dictionary. Measured on `08b04aa` (`docs/THE_NUMBERS.md` §4.3): the taught layer finds **7 of 7** people in an Arabic letter given as text, and **0 of 461** in the same book given as the PDF — because the reader hands the scanner the PDF's glyph codes as they are: **205 434 Arabic presentation-form characters** (U+FB50–FDFF, FE70–FEFF) in **visual order** (the string reversed). The book's title word: 0 raw, 180 after folding and reversing. poppler reads the same file into 180 / 209 / 67 in logical order, so the file is not the problem.

## Where it lives — the owner's shape, fixed here

This is **not «Arabic handling» inside a language pack.** It is Document/Text Ingestion, before the text reaches any pack or any user knowledge:

```text
PDF bytes
   ↓
Extract text
   ↓
Canonicalize Unicode            presentation forms → letters (NFKC on the two blocks)
   ↓
Recover logical reading order   visual → logical, per line
   ↓                            ── these two are *reading the PDF correctly*: what comes out
   ↓                               must equal what the page shows, letter for letter
Normalized matching view        diacritics dropped · Arabic-Indic digits folded · (NFC)
   ↓                            ── this one is *for comparison only*
Language Pack / User Knowledge
```

**Two layers, two rules.** The first two steps produce `DocumentView.text`: the page's own letters in the page's own order, which is what the Original column shows, what spans point into, and what a restore writes back. They change nothing a person wrote; they undo what the extraction broke. The third step is a view the matcher reads and nobody else: **Z matches `دَمْنة` to `دمنة`, and when it protects and restores it never turns the user's `دَمْنة` into `دمنة`.** «التطبيع للمقارنة، لا لتغيير الوثيقة.» Spans always address the original text; the matching view carries a position map back to it.

`.txt` and `.docx` input is already logical and canonical (AR-1 proves it): the first two steps are the PDF reader's alone, the third applies to every kind.

## What to build

1. **Canonicalize** in `z_core/src/documents/pdf.rs` where a font's codes become characters: a character in the two presentation blocks becomes its NFKC form (`unicode-normalization` is already a dependency; no new crate). Lam-alef ligatures (`ﻻ` and kin) become two letters. A test asserts Latin and German text pass this step unchanged, byte for byte.
2. **Logical order**: a line whose characters came out right-to-left-reversed is turned round before it leaves the reader. Smallest honest rule first: within a line, a run of right-to-left characters is reversed as a run, and runs of digits and Latin letters inside it keep their own order; measure on the book and on an Arabic letter saved as PDF from a word processor (the owner can make one) before deciding whether the full bidi algorithm is needed.
3. **The matching view**: a value in the vault, a taught name and a pack word compare against text with the Arabic combining marks (U+064B–U+0652, U+0670) and tatweel (U+0640) removed, and with Arabic-Indic digits (`٠١٢…`, `۰۱۲…`) read as `012…` — on both sides, at the point of comparison, with the span covering the marked text as written. AR-1's fourth phone, written in Arabic-Indic digits, is found by nothing today; after this it is found by the same phone rule as the other three.
4. **Nothing else**: no Arabic rule, no honorific, no company form — those are the pack's, after this.

## Acceptance — the numbers are the contract

The owner: «إذا خرجت الأرقام مختلفة، لا نقول إن المهمة انتهت حتى نفهم السبب.»

| measurement | today (`08b04aa`) | after this task |
|---|---|---|
| the book's title word, raw in `DocumentView.text` | 0 (180 only after folding and reversing by hand) | **180** |
| presentation-form characters in the book's text | 205 434 | **0** |
| five taught characters (Person · always), the book as PDF | 0 | **461** after canonicalization and order |
| the same, matching through the vowel marks | — | **562** |
| AR-1 as `.txt`: 7 taught people | 7 | 7 (unchanged) |
| AR-1's Arabic-Indic phone | not found | found, same kind and state as its ASCII twin |
| every German and Swedish row of `docs/THE_NUMBERS.md` | — | unchanged to the digit |

`the_arabic_book.rs` (golden six from task 038) was written to go red when the reader is fixed; flip its assertions to the new truth. A new test on AR-1 saved as PDF (the owner's file, or a `.docx` printed to PDF in the test's own setup) finds its 7 taught people. Counts of `cargo test`, gates and clippy before/after; nothing of a document printed by any test.

## The demo this makes possible (for Doha, the owner's words)

«كتاب عربي حقيقي → القارئ يفشل → التطبيع يصلحه → المستخدم يعلّم خمس شخصيات → Z يجد مئات المواضع من دون قراءة 221 صفحة.» And the lion: `دمنة` is a definite name → **Always**; `الأسد` may be a character or an ordinary word → **Suggest**. Teaching Z is not a blind word list: the user says which knowledge is certain in their world and which needs context.

## The other half of the same defect, found from the writing side (7 Oct, 046/R)

Building «Save as PDF» met this paper's defect from the opposite direction, and
the two halves are one thing:

**Our writer and our reader disagree about the same file, and the reader is the
one that is wrong.**

046/R made the PDF writer lay Arabic out as it is read — direction per
paragraph, shaping and the bidi pass on, the Latin runs isolated inside each
right-to-left line. The page is correct: measured with `pdftotext -bbox-layout`
on a client's letter, every Arabic line ends at the right margin and the German
line beside it begins at the left, and poppler extracts the Arabic in logical
order. **Our own reader, handed that same correct file, returns the words in
logical order with each word's letters in visual order** — neither one thing nor
the other. It is the same two faults this paper already names, presentation
forms and visual order, meeting us on our own output instead of a stranger's.

Why that matters more than tidiness: a file Z Privacy writes exists to be handed
to a model, and the owner will one day open an Arabic **PDF** rather than an
Arabic text file. His complaint of 7 October about Arabic text — «النص العربي
مقطع وغير مفهوم» — is what he would meet again, from a file we made ourselves.

**Nothing here changes what this task builds.** It adds one acceptance: a PDF
written by `apps/flutter_app/lib/core/protected_pdf.dart` and read back by this
reader must return the text that went in. That guard did not exist before,
because until 046/R we had no Arabic PDF of our own to test against.

## The pair of rules this and 046/R together produced

Put side by side, because they are one promise facing two directions:

> **Protection may not change how a document reads** — a `__Z_…__` token must
> not vote on direction; its letters are Latin and *we* put them in the
> person's line. (046/R, adopted 7 Oct.)
>
> **And ingestion may not either** — the reader undoes what the extraction
> broke and changes nothing a person wrote. (This task.)

Between them they answer three arguments this project has already had: why the
reader carries page edges as **positions beside** the text and not as
characters inside it; why a hyphen is joined in the **matcher** and not in the
reader; and why the matching view of step 3 is a view and not a rewrite —
«التطبيع للمقارنة، لا لتغيير الوثيقة». A normalisation that reaches the
document is ingestion changing how a document reads, which is the same fault as
a token moving a person's words about.

## Not in this task

- The Arabic pack's own rules (honorifics, kinship particles, company forms, Gulf phone and ID shapes).
- The substring question for short names inside longer words (named in §4.3; a pack decision).
- Task 038's probe and goldens, which this task's tests build on when both are ordered.

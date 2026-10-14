# 086 · Arabic is not a language, it is settings — a second reading and writing base

**Opened by the owner, 14 Oct 2026, as the first step of the road to Doha.**

> «الخطوة الأولى هي إصلاح القراءة العربي. يجب أن يُبنى على قاعدة كتابة وقراءة مختلفة أو معاكسة. العربية ليست لغة، هي إعدادات.»

This separates two things the lead had folded into one:

| | what it is | when |
|---|---|---|
| **a language pack** | rules that know this word is a name | **last**, by the owner's ruling of the same morning |
| **the reading and writing base** | which way a line is read, and how the characters arrive | **first**, this paper |

A pack is knowledge. A base is **settings**: it governs reading, writing, selection, pages and export alike, and it serves every script that is written the other way — Arabic, Persian, Urdu and the rest of the family ([[project_zprivacy_arabic_script_family]]).

## Measured, and why this is first

- An Arabic book as the PDF reader hands it over: **0 of the taught characters found**.
- The same text folded to logical order: **461**. Through the harakat: **562**.
- Five taught characters matched **462** places in the book through the §4.3 path, and the Arabic clitics rule is the reason the word-edge rule has an Arabic half at all (`z_core/src/text.rs:286-320`, `:370-377`).

So the defect is not that Z lacks Arabic knowledge. **It is that an Arabic document arrives in a shape nothing can be found in** — presentation forms, and the line's order reversed. Every rule we sealed today (076 edges, 083 protection, 084 search) rests on a word's place in the text; on an Arabic PDF today those places are wrong before any rule runs.

## Measured on the owner's own book, 14 Oct (`~/Downloads/كليلة ودمنة_26761_Foulabook.com_.pdf`, 1.5 MB, 234 pages)

Measured outside the product, on the file itself, so that nothing here depends on Z being right. Every font in it is a CID TrueType with `Identity-H` encoding, which is why the glyphs must be read through a `ToUnicode` map at all.

| what arrives | number |
|---|---|
| characters extracted | 395,091 |
| **presentation forms** (`U+FB50–FDFF`, `U+FE70–FEFF`) | **198,995** |
| ordinary Arabic letters | 63,630 |
| **bidi control characters** embedded in the text (`U+202A/B/C`) | **34,186** |
| presentation forms after an NFKC fold | **0** |
| ordinary Arabic letters after the fold | 268,394 |

So three quarters of the book's letters arrive as shapes, not letters, and the fold turns every one of them back. The word «الكتاب» is found **0 times** in the text as it arrives and **173 times** after the fold; «السلام» 0 → 8; «الملك» 0 → 3.

**The fold is necessary and not sufficient — and this is the owner's «reversed base».** *(Measured with `pdftotext`. The paragraphs that follow were later shown to describe poppler, not Z's reader — see the instrument's table below.)* Some words are never found however folded, because the letters inside them arrive in the wrong order:

- «المجرم» → `املجرم` (the `ل` and the `م` swapped): **0** occurrences even after the fold.
- The swapped spelling `امل` stands **1,640** times; the correct `الم` stands **33**.
- **323 distinct words** in the book are a single swap away from a spelling the same book writes more often.
- The reversed pairs are led by `لم` `عب` `مل` `أر` `ال` `هي` `لا` `ين`.

The cause is visible in the table above: these fonts map one glyph to several letters, and a glyph that covers two letters hands them over in the order the eye sees them, right to left, not the order the language reads them. **A ligature is where the writing base reverses**, and nothing above the reader can repair it: a word that arrives with two letters swapped is a word no rule and no hand can find.

**The owner's own text fixtures carry the same defect**, having been made from this book: `~/Documents/kalila-wa-dimna-10-pages.txt` reads «وبني الحرب» for «وبين الحرب» and «ا ُملؤذي» for «المؤذي». They are evidence of the defect, not a clean baseline, and a new baseline must be made after the reader is fixed.

## Measured through Z's own reader, 14 Oct — two of the three defects were never ours, and the real one is the spaces

The instrument (`cargo run -p z_core --example what_arrives`, built by the second programmer on `probe/what-the-reader-hands-over`, measured by the merging hand) read the same 221 pages through the ordinary import path, changed nothing, ran no scan and left the three files in `~/.local/share/zprivacy` at their old timestamps.

| | as read | NFC | NFKC |
|---|---|---|---|
| characters | 333,636 | 333,636 | 354,197 |
| words | 38,567 | 38,567 | 38,567 |
| **spaces** | **438** | **438** | 5,214 |
| lines | 38,328 | 38,328 | 38,328 |
| **lines with no space at all** | **38,110** | 38,110 | 33,339 |
| lines over 30 characters with no space | 2,284 | 2,284 | 2,451 |
| longest run with no space | 117 | 117 | 124 |
| readable | 97% | 97% | 97% |
| presentation forms (`FB50–FDFF` + `FE70–FEFF`) | **205,434** | 205,434 | **0** |
| ordinary Arabic letters | 63,528 | 63,528 | 275,176 |
| harakat | 11,791 | 11,791 | 21,325 |
| **bidi controls** | **0** | 0 | 0 |
| «الكتاب» as whole words | 0 | 0 | **5** |
| «الكتاب» anywhere in the text | 0 | 0 | **173** |
| «دمنة» as whole words | 0 | 0 | 8 |
| «دمنة» anywhere | 0 | 0 | 207 |

**What this corrects in the lead's own measurement above.** Everything I measured with `pdftotext` described poppler, not Z:

- **Our reader does not swap letters.** The instrument tried every adjacent swap in every named word, as a whole word and as a substring: the only hit in the whole book is «مدنة», once, by coincidence. The 323 swapped words, «المجرم» → «املجرم», are poppler's artifact. **The second defect of the fold section above is not ours.**
- **Our reader hands over zero bidi controls**, against poppler's 34,186, in all eleven code points. Not ours either.
- Presentation forms are real and bigger than I measured: **205,434**, and NFKC takes every one of them to zero.

**The defect that is ours, and that no paper had named: the words arrive stuck to their neighbours.** 333,636 characters and **438 spaces**. 38,110 of 38,328 lines hold no space at all, and the longest unbroken run is 117 characters. So after folding, «الكتاب» stands as a whole word in **5 places** while the string is there 173 times. The product never searches any other way: a taught name, a vault value and «protect all matches» all go through `text::occurrences`, which requires the word to stand alone (`z_core/src/text.rs:389`). **Folding the shapes and repairing the order buy almost nothing by themselves.**

This is exactly where the owner's own rule lands: «الكلمة محصورة بين مسافتين». Our reader hands over no boundaries for that rule to stand on. The reading base is first a **word-boundary** problem, and only then a shape problem.

**And a cost of the fold itself, which decides how it must be applied:** a blind NFKC over the whole text **adds 4,776 spaces** (438 → 5,214) and 9,534 harakat, because the isolated harakat forms decompose into space + mark. So NFKC applied to everything cuts words in half. The fold has to be narrowed to the letters it is meant for, never run over the whole document — which is why the older 038-C step said «the character in the two blocks becomes its NFKC form».

**The old §4.3 number, placed.** `docs/THE_NUMBERS.md` §4.3 recorded «180 after NFKC and reversing the string»; that is a string count, the ancestor of the 173 above, not a count of places the product can act on. The 461 the old paper hoped for is not bought by folding and ordering alone.

## The owner's rule for the reading base (14 Oct) — shape against place, and the defect is shown, never repaired in silence

He gave the method and then the law.

**The method (the owner):** «الكلمة محصورة بين مسافتين. الحرف بعد المسافة الأولى يأخذ قائمة الأحرف عند بدء الكلام، والأحرف قبل المسافة الثانية تأخذ قائمة شكل الحرف في آخر الكلام، وما تبقّى يُقاس بقائمة شكل الحرف في وسط الكلام.»

So a letter's **place in the space-bounded word** says which shape it must wear, and the shape it actually arrived in can be checked against it. No letter knowledge, no language — only the space and the four shape lists. Measured on the owner's book, 193,127 shape characters:

| | number | share |
|---|---|---|
| the shape agrees with its place | 184,744 | **95%** |
| the shape disagrees | 8,383 | 4% |

One amendment the lead had to add to reach that 95%: the letters that **do not join to the next one** — `ا أ إ آ د ذ ر ز و ؤ ة ى` — start the letter after them afresh, as if at a word's beginning. That is a list of shapes, not of language, so it stays inside the owner's principle.

**What the rule is for.** It is not a cure; it is a **detector**, which is better: a shape that disagrees with its place says *the order is broken here, and at this letter*. Z does not guess — it reads the evidence in the text.

| | number |
|---|---|
| words of 2+ letters in the book | 63,358 |
| **words where a shape disagrees with its place** | **7,369 places, 4,149 distinct words** |
| of those, words holding a ligature shape | 3,915 |
| distinct words one swap repairs, with exactly **one** candidate | 600 |
| with 2 candidates | 55 · with 3: 1 |
| with **no** candidate the swap rule can explain (mostly the ligatures) | 3,493 |

**The law (the owner, 14 Oct):** «الكلمات الخطأ عند الطيّ تظهر بعلامة مميزة بلون أحمر مثلاً، والضغط على الكلمة يخرج الاحتمالات الصحيحة. هكذا يظهر النص كما قرأه القارئ، لا كما يريد المستخدم أن يقرأه.»

1. **A word whose shapes disagree with their places is marked** where it stands, in the text.
2. **Pressing the marked word shows the correct possibilities** — the candidates the evidence allows: the one-swap repair, and the ligature's two letters in their proper order.
3. **Nothing is repaired in silence.** The text is shown **as the reader read it**, never as the person wishes it read. A repair is the person's answer, exactly as a protection is.
4. A word with no candidate stays marked and untouched: Z says «here the order is broken» without inventing a word.

**Why this is the right shape:** it is the suggestion model of 083 applied to reading — evidence, a question, the person's word — and it keeps the repair inside *settings*, since every candidate comes from shapes alone and no dictionary. A language pack is still not needed.

**It also answers the eye, not only the search.** The owner: Z's reader hands over text the person *can read* — the shapes draw correctly and the line runs right to left, so 95% of the book reads properly and nothing on the glass announces the defect. The document **reads right and protects wrong**: «الكتاب» stands 0 times before the fold and 173 after. And the 7,369 broken places look like misspellings to an Arabic reader too — «املجرم» for «المجرم» — so an unmarked, unrepaired Arabic document makes Z itself look broken.

**A number the lead over-read, corrected:** `check_document` reports the book «97% readable». That measures glyphs turning into characters, not characters standing in the right order. It reassured me and it should not have.

**One press answers every word with the same problem (the owner, 14 Oct):** «ضغطة على كلمة واحدة تكفي لتصبح جميع الكلمات التي لها نفس المشكلة». The answer teaches the **repair**, not the word — the defect is systematic, so one press clears every place the same shape or the same swap broke. Behind all the marked places stand only **146 distinct problems**, led by a handful of shapes.

**The lead's detector over-counts, and the 7,369 must not be quoted again until the instrument measures it.** Grouping the marked places by their cause showed the largest groups are not order defects at all: `U+FC60`, `U+FC61`, `U+FC62` (2,520 + 590 + 360 places) are **shadda-with-vowel** shapes, which fold correctly and were never broken — the detector flags them only because a mark has no place-shape to agree with. Another **2,715** places are unexplained by either the swap rule or a ligature. So the real count of wrongly ordered letters is well under half of 7,369, and the honest number has to come from `what_arrives` reading the fonts through the product's own reader, not from a script over `pdftotext`.

**STOPPED by the owner, 14 Oct:** «لا يمكنني الحكم الآن، أحتاج إلى تجربة بنفسي… اقتراح التوقف عن العربية.» Nothing of the base is built until he has tried it with his own hands. The one instrument in flight (`what_arrives`, ed, branch `probe/what-the-reader-hands-over`) continues, because it is what he will try it *with*: it reports numbers and changes no behaviour.

**Two questions for the owner, still open:**
- **The colour.** Red already means «protected» in the search box (084 rule 8). Two meanings for one colour. The lead's suggestion: the marked word keeps red but as a **line under it**, never a wash, so «red wash = protected» and «red line = the order here is broken» stay apart.
- **Does a marked word stop a text leaving?** The lead's reading: **no.** 083a stops an unanswered *privacy* suggestion; a reading repair is not one, and a book with 7,369 of them would be a wall, not a guide. The count is shown and the person may act. (But a marked word may hide a name Z cannot find, so the count belongs beside the exit, said plainly.)

## What the core knows already

- The word's edges have an Arabic half: `ARABIC_CLITICS` (`و ب ل ف ك`) and the presentation-form range `U+FE70–FEFF` are named at `text.rs:295`, `:319`.
- The harakat are kept inside a name, never torn off (`text.rs:335-345`), which today's edge-set widening (085) preserved on purpose.
- The PDF reader refuses a page it cannot read faithfully rather than half-reading it (`documents/pdf.rs:89`, `:129`) — «a name we cannot see is a name we cannot protect». **It has no fold and no ordering step**: a search for `FE70`, `presentation` or `fold` in `pdf.rs` finds nothing.
- The glass already asks for the ambient direction in two places (`document_text.dart:884`, `line_gutter.dart:198`) and hard-codes `ltr` in one (`document_text.dart:1128`).

## What the base must settle (to be measured before building)

1. **Reading.** A document arrives folded to its logical order and in ordinary letters, not presentation forms — so that a span, a count and an occurrence mean the same thing in both directions.
2. **Writing.** What Z puts out — the Safe column, a copy, a Z sheet, a z-pdf — reads back the same way it was read. A round trip proves it: read, protect, export, read again, and the same places are found.
3. **Where the base comes from.** A session's base, like its language (080): chosen when the session is born, else the app's. Not guessed per paragraph.
4. **Selection in the other direction.** 076's rules are about the word and the space, so they hold; what moves is which side «the word before» is on (`acts.dart` «Also the word before»), and where a lit word sits on the glass.
5. **The two columns.** Which side holds the original when the text is read the other way, and the W8/073 alignment must survive.
6. **The Z sheet (082).** 3 cm at the top and 2 cm at the bottom do not change. The letterhead and the stamp do not move with the script.
7. **The search bar (084).** The completion counts three letters as the eye sees them, which is already the rule (`~/محرر النصوص.md` 46ب).

## Order

1. **The measurement.** Half done above, on the file. What remains: the same book **through Z's own reader**, to see which of the three defects the reader already absorbs, and one Arabic file typed by hand as the control, since a typed line has no presentation forms and no ligature glyphs.
2. **Reading** (the core, `documents/`): fold and order, with the reader's fail-closed behaviour untouched. The old task name `fix/arabic-arrives-as-it-is-read` (039) belongs here.
3. **Writing and the round trip.**
4. **The glass:** the base as a session setting, the lit word, the columns, «the word before».
5. A language pack is **not** part of this and waits as ruled.

## Guards (pinned red first)

- **The round-trip guard:** an Arabic document read → N places found; protected and exported → read again → the same N, the same spans.
- **The presentation guard:** a PDF page of presentation forms arrives as ordinary letters; a page the reader cannot read faithfully is still refused.
- **The harakat guard** (already standing, 085): a mark on the last letter of a name is not an edge.
- **The direction guard:** a session born on the other base lights the word the eye reads first, in both columns at one offset.

## Why it is first, in the owner's order

Doha is Arabic. A pack can wait because a person can select by hand; **a document that arrives in the wrong order cannot be selected at all.**

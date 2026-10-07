# 048 · The column measurement, and the rule it was going to justify

**Status: MEASURED · THE RULE IS CANCELLED · AND 046/Q IS WHAT THE MEASUREMENT BOUGHT** · 7 Oct 2026 · programmer, at the lead's order · **no code was shipped from this.**

The owner, 7 October: «بشأن الأعمدة، نحن لا نحتاج الأعمدة. نعتمد فقط على الأسطر — في حال تحديد الكل نحسب كم سطر في النص.»

So **038-G item 6 is not being built.** This paper exists because the measurement that was going to justify it is worth keeping whatever is built instead: it says what a table costs us today, it settles two questions about the PDF reader that nobody had measured, and it corrects a sentence in 038-G's own paper that was written from the shape of the wrong file.

Nothing in this paper is a plan. Everything in it is a number taken on this machine.

---

## 1 · What stands under a column header and is reached by nothing else

Blocks found by 038-G item 6's own definition — two or more lines that split into the same number of runs on two spaces or a tab, the first being the header — and then every cell checked against every finding the build produces today.

| document | findings | table blocks | lines of 3+ cells | adjacent pairs |
|---|---|---|---|---|
| the owner's English payroll sheet, his book imported | 61 | 2 | 20 | 15 |
| DE-6 `Lohnabrechnung_Weber.txt` | 33 | 1 | 5 | 4 |
| DE-1 `Brief_Weber.txt` | 29 | 0 | 0 | 0 |
| SV-1 `Brev_Lindqvist.txt` | 16 | 0 | 0 | 0 |
| DE-3 `steuern-von-a-z.pdf` | 6 | 0 | **0** | **0** |
| DE-4 `tysk1.pdf` | 20 | 0 | **0** | **0** |

And the cells themselves, which is the half a count cannot show:

```text
the English sheet
    under «account no.»    8   "9999 000 01" … "9999 000 08"      personal data
    under «amount»         8   "42 500" "34 800" "31 200" …       not personal data
    under «date»           8   "25 February 2027" …               not personal data
    under «name»           0   — the client's book reaches every one of them

DE-6
    under «Gesamtbrutto»   4   "38.970,00" "41.400,00" "52.200,00" "36.120,00"
    under Personal-Nr. · Name · Geburtsdatum · SV-Nummer · Steuer-ID
                           0   — reached already: the shape rules take the
                               social-insurance and tax numbers and the dates,
                               and the reversed pair takes «Lindemann, Katharina»
```

**So the whole yield of a column rule was eight values in one column of one document.** Every other uncovered column is money or a date, which must **not** be protected — we spent 046/M taking an amount back out of a token so the model could do arithmetic on it.

## 2 · The two zeros, and the proof that they are not a false zero

A zero is the first trap of the control-string rule, so the zeros above were not accepted on their own. The control: how many lines in those files have three cells at all, and how many such lines sit next to another with the same count.

```text
DE-3   5 770 lines · widest whitespace run 2 spaces ·  5 lines with any double space
DE-4  82 468 lines · widest whitespace run 2 spaces ·  4 lines with any double space
```

**Not one line with three cells exists in either file.** So the rule's entry condition never occurs in 146 pages of tax prose or in 734 pages of ICD-10 — the tables of codes are safe because the shape the rule looks for is absent, not because the rule was careful. That is what closes the entry rule, and the control thread is the measurement itself.

## 3 · What the PDF reader does to a column, which nobody had measured

Statistics only, on one of the owner's own financial PDFs. **No line of his document was printed, here or in the measuring.**

```text
his bank analysis · 1 813 lines · widest whitespace run 2 spaces · 429 lines with a double space
```

Two facts, and they point in opposite directions:

* **a cell can be split out of his PDF** — a quarter of its lines carry a two-space gap, which is a column boundary by `column_gap_before`'s rule (046/M);
* **a column can never be aligned in it** — every gap is *exactly* two spaces, so there are no character positions to align by.

**This corrects 038-G item 6's own wording.** It says «columns by character position». Position is a proxy for order that survives a `.txt` and dies in a PDF, and the owner's documents are PDFs. If a column rule is ever built, cell `k` belongs under header cell `k` **by order**, with the equal cell count as the guard. The lead has accepted the correction; the sentence in 038-G is left as it stands only because the rule it belongs to is cancelled.

## 4 · And a defect in the code that is already shipped

`table_columns` exists in `scanner/rules.rs` today and does fire — measured: a `national ID` header does reach its column. Two things in it are wrong, and neither is fixed here because the rule is cancelled and a change that is not measured end to end does not enter a commit:

1. **the span is found by searching the row for the value's text** (`row.find(value)`), not by the cell's own offset — which the loop is already holding. A row that repeats a value marks the **first** occurrence while the finding claims the second. The owner's own ledger repeats «28 400» and repeats a date in every row;
2. **a grouped number in a cell is refused.** `is_numberish` allows no space, because the label path it was written for walks word by word and never sees one; a cell is a whole value, so `9999 000 01` arrives as one string and fails. This — not the position test — is why the eight account numbers stood under a header this build already knows (`en-13 account no.`) and were reached by nothing. **I had read the miss as the position test failing, and the measurement corrected me.**

Both are **measured debts** on a rule nobody is asking for today. If the rule is ever revived, (2) is the whole of what makes it work and (1) must be fixed in the same breath.

## 5 · The reader debt, with its precedent named

The information is destroyed in the **reader**, not in the scanner: a PDF's columns arrive as two spaces whatever their real width. The honest fix has a precedent in this codebase — **041-L's `page_edges`**, which carries *where a page began* as positions **alongside** the text rather than as characters inside it. Column boundaries belong to the same family: the reader records where a gap was, and nobody's offsets move.

It is **not built and not ordered.** The measurement is also why it is not needed yet: every gap in the owner's bank statement is exactly two spaces, so splitting on two-or-more recovers his cells in order today. The reader's metadata would only reach a table separated by a **single** space.

And the invariant it protects, which this project has paid for twice: **the left column is the document byte for byte, and the reader never rewrites what a person sees in order to help the matcher.** The same argument settled the hyphen-joining question in 038-C.

## 6 · What a column rule could never reach — for the disclosure line

Written by whoever measured the gap, in the words a person would read:

> Z reads a table when its rows line up and its heading names what is in them.
> It does not read:
>
> * a row with a different number of cells from its heading;
> * a table with no heading at all;
> * a heading whose word Z has never been taught — it protects what it can name, and nothing by guess;
> * a table whose columns are separated by a single space, which is how a table usually arrives inside a PDF.
>
> In those four cases the values in the table are read as ordinary text, and whatever the ordinary rules find is what is found.

## 7 · And what the owner's own answer reaches instead — 046/Q

His sentence was the better design, and the four shapes above are the argument. **He selects the lines, clicks one value, and the same cell is protected in all of them** — the cell identified by its **order** among the runs, which §3 proved is the only thing about a table that survives his PDF reader.

| | a header-driven rule (cancelled) | a person's click (046/Q) |
|---|---|---|
| the owner's sheet, `account no.` | 8 values | **8 values, in one press** |
| a row whose cell count differs from its heading | nothing | nothing — the rows selected are the rows acted on |
| a table with **no heading** | nothing | **reached** — measured |
| a heading in a language this build does not carry | nothing | **reached** — measured, on a Turkish heading |
| a heading that is not a label | nothing | **reached** |
| a table separated by a **single** space | nothing | nothing — the reader debt of §5 stands |

Measured, with the act's cost in presses:

```text
the owner's English payroll sheet · the account no. column
    selection          8 lines · 25 values already protected in them · 0 open
    protected          45  →  53        the act reached 8 places
    presses            8 by hand, one at a time  →  1
    must still reach the model   7 of 7
        42 500 · 34 800 · 31 200 · 28 400 · 27 900 · 26 500 · 2 400

DE-6 Lohnabrechnung · the Gesamtbrutto column
    selection          4 lines · 20 already protected · 0 open
    protected          29  →  33        the act reached 4 places
    presses            4  →  1
```

**That the amounts still reach the model is the real subject**, not the eight: 046/M took an amount back out of a token so the model could do arithmetic on it, and an act over lines that swallowed a row would be the same defect arriving by another door. So each value becomes **its own token** — eight accounts, eight tokens, measured — and a line is never taken whole.

Two things the measurement corrected while this was built:

* `line_selection(0, 999)` on a nine-line document answered **`lines: 1000`**. It checked the first line number and not the last — a number shaped like a fact, which is the one thing this product may never print. Found by the function's own test, on the end nobody thinks about.
* A click in the **whitespace between two columns** names no cell. It is refused in words rather than resolved to the nearest one: choosing a column for the person is the inference this whole design exists to avoid.

## Not in this paper

- The screen's gesture for selecting lines. The core answers «how many lines, how many protected, how many open» and performs the act; drawing the selection is the next item and is not built.
- Anything Arabic. The owner's priority, 7 October: not needed at present. The 045 debts stay exactly as they are, with their tests.

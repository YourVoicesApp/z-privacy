# 119 — A text we cannot trust is not protected: refuse the visual-order Arabic PDF

**Source:** ed's measurement at the published build `4920398` (26 October 2026, five fixtures made from `Risala_Alharbi.txt`, never the owner's files), and the owner's decision the same day: **fix it now, in a very narrow scope, then Z goes back to its pause.** Builder: **ed**. Branch off the Z lead tip `1ce565f`.

## What was measured

| Fixture | Today |
|---|---|
| Arabic PDF, logical order, Identity-H + ToUnicode | read exactly like the `.txt`: 19 auto · 5 waiting, the same 24 finds |
| mixed Arabic + English + digits, logical order | 8 · 2 |
| Identity-H without ToUnicode | refused by name (`UnreadableStructure`) |
| scanned, no text layer | refused by name (`ScannedPdfNoTextLayer`) |
| **the same letter in visual order + presentation forms** | **imported, not refused: 1 · 3, zero of the eight people, and a REVERSED e-mail address «protected»** |

`readable_percent` reads the reversed text as 100% readable, and it is right to: presentation forms are honest Unicode. **The meter asks «did these bytes become text?», not «is this the text that was written?».** No gate on this path can see the reversal.

## The rule (the owner's, for every language and every document type)

> **When Z cannot trust that the extracted text is faithful to the document, it must not show protection succeeding as though the text had been read correctly.**

A false protection is worse than none: it gives the person a calm the document has not earned.

## What to build, and only this

1. **A regression test with the visual-order fixture that exposed it**, red first on `1ce565f`.
2. **A testable technical marker** that the extracted text is not trustworthy. ed's own candidates: a high share of Arabic presentation forms (U+FB50–U+FDFF, U+FE70–U+FEFF), or digit runs that read reversed inside Arabic text. **Not a weak guess:** Arabic letters or RTL direction alone prove nothing, and a logical-order Arabic PDF must never be refused. Measure the marker's two sides on the five fixtures, and name the threshold and why.
3. **The refusal sits at the ONE boundary between extraction and acceptance for protection**, not at a screen or a single door, so that **no other path** (import, rescan, z-pdf read-back, paste of extracted text by any route the core offers) can carry an untrusted extraction into protection or sending. If there is more than one such boundary today, say so and close each.
4. **A refusal by name with a clear sentence:** why it was refused, in the person's words, and what to do instead (use the `.docx` or `.txt`). In the one list, with de/sv/ar beside it.
5. **Re-run all five cases:** the logical-order Arabic PDF and the mixed PDF must still import with exactly today's counts; the two existing refusals stay as they are; the visual-order one is refused with the new name.

**If a reliable distinction cannot be measured**, the owner's safer fallback applies: refuse an Arabic PDF whose text cannot be verified, rather than risk a false protection. Say which one you built, and why.

## Not in this paper

No new engine to reorder Arabic text, no OCR, no change to the detection engine, no rebuild of the PDF system. «Recovering visual-order PDFs» is a later round, postponed by the owner. And the deeper question ed's measurement opened («do we measure readable characters, or faithful extraction?») is named here and **not** turned into a research project now.

## The release

After the gates are green: a small corrective build (Linux package + the owner's Windows run), the download pages' fingerprints, deploy, GitHub release. **Then Z returns to its pause.** Meanwhile e2 publishes a temporary warning on the site (paper 118's branch), which is replaced by an exact description of the remaining limit once this ships.

## Measurement

`bash scripts/gates.sh` green; the five fixtures as committed tests with their counts; the refusal sentence in four languages; the marker's numbers on both sides of the threshold.

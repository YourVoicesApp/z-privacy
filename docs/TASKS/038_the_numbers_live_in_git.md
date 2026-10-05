# 038 · The numbers live in git

**Status: ORDERED** · 5 Oct 2026 · lead → a builder the owner names, **after Phase 4's exit report, or beside it only if Phase 4 is waiting on a review** · branch `feat/the-numbers-live-in-git` from `main`.

## Why

The owner, 5 October: «ما نحتاجه الآن هو جمع كل الأرقام للتجارب في git… وأرقام صحيحة للتجارب باللغة السويدية والعربية والألمانية». `docs/THE_NUMBERS.md` now holds every number with its ground truth — but the Swedish and Arabic rows were measured with a rig outside the repository, because both probes in `z_core/examples/` open their session with `"de"` and nothing else. A number that only the lead's machine can reproduce is a memory.

## Measured state (`main` = `08b04aa`)

- `check_document` prints numbers only; `review_names` prints names and context. Both: `open_session(None, "de".to_string())`, no way to choose a pack.
- Goldens in git: `Brief_Weber.txt` (DE-1), `Vertrag_Nordstern.txt` (DE-2). Off-machine goldens: the tax guide, tysk1 — skipped (`----`) by the gates when absent.
- Two new fixtures were added by the lead with this paper, both invented end to end: `z_core/tests/fixtures/Brev_Lindqvist.txt` (SV-1) and `z_core/tests/fixtures/Risala_Alharbi.txt` (AR-1). Their ground truth is written in `docs/THE_NUMBERS.md` §3.1 and §4.1.
- What the lead's rig printed on this build is the acceptance line of every test below; the rig's own numbers are in the paper.

## What to build

1. **One probe, `measure`** (`z_core/examples/measure.rs`): `measure <pack> <file>…`. Prints the build stamp, then per file: KiB, pages, words, chars, read ms, scan ms; `auto · suggested · normal`; tokens in the payload (`__Z_` count); `by_layer`; a line per `Kind` with auto/suggested counts; `name_candidates().len()` and the sum of occurrences; a character census (Arabic letters, Arabic presentation forms U+FB50–FDFF and FE70–FEFF, Latin letters, ASCII digits, Arabic-Indic digits). **Numbers only** — no span text, no shapes, nothing from the document, so its output can be pasted into git. A refusal prints the reason enum and the detail, as `check_document` does. The pack id is a plain argument; an unknown pack prints the error and moves on.
2. **Golden four — the Swedish letter** (`tests/the_swedish_letter.rs`): on SV-1 with pack `sv`, `(auto, suggested) == (10, 5)`; Person auto 2 and suggested 2; TaxId auto 2; Email 2; Iban 1; Phone 2 + 1; Company suggested 2; 2 name candidates. And what *is not* found, asserted as not found so the next Swedish rule turns a red line green: the BIC, the bankgiro, the plate, the VAT number, the four addresses — assert each stays in the payload text, by value, as `the_german_letter` asserts the opposite.
3. **Golden five — the Arabic letter** (`tests/the_arabic_letter.rs`): on AR-1 with pack `de` **and** with pack `sv`, `(auto, suggested) == (5, 2)` and `(4, 2)`; Email 2, Iban 1, Bic 1 (de only), Phone 1 + 2; **0 Person, 0 Company, 0 candidates**; the Arabic-Indic phone `٠١٢١٢٣٤٥٩٩` and all seven people still in the payload, asserted by value. This is the «before» the Arabic pack is measured against.
4. **Golden six — the Arabic book**, skip-if-absent like the second and third (`ZPRIVACY_ARABIC_BOOK`, default `~/Downloads/كليلة ودمنة_26761_Foulabook.com_.pdf`): 221 pages, `(auto, suggested) == (1, 0)`, the one auto is `Kind::Email`; and the reader's census pinned as the acceptance of the next reader task: presentation forms > 200 000, and the title word found **0** times raw and **≥ 150** times after NFKC + reversal. When the reader is fixed, this test must go red on purpose; say so in its comment.
5. **The contract's false protection** (DE-2, found by this measurement): add to `tests/golden_scan.rs` or a sibling a test that *names* it — the line under the closing, «Abteilung Vertragswesen», is protected as a Person today — marked as the current behaviour, not the wanted one (`#[ignore]` is not the way; assert the present number and write in the comment which paper will change it). No fix in this task.
6. **Gates**: `scripts/gates.sh` runs goldens four and five, and six with the skip; and a line that `measure` exists and prints no line longer than the census allows (a guard that the probe stayed numbers-only: grep its source for `view.text` reads other than counts — the lead will measure this by eye too).
7. **`docs/THE_NUMBERS.md`**: replace «the lead's rig» by `cargo run -p z_core --example measure -- <pack> <file>` in §2–§4, and re-run every row with the probe; any number that moves is reported, not silently updated.

## Done means

- `measure sv z_core/tests/fixtures/Brev_Lindqvist.txt` and `measure de z_core/tests/fixtures/Risala_Alharbi.txt` print the rows of the paper, to the number.
- Red first: break the Swedish salutation list and golden four reddens; drop the e-mail rule and golden five reddens; the Arabic book's test reddens when `pf > 200_000` is negated.
- `cargo test -p z_core` count before/after; `scripts/gates.sh` exit 0, count before/after (219 on `main`); clippy clean.
- No change to any rule, any pack, the reader or the scanner: this task measures, it does not move a number.

## Not in this task

- Folding Arabic presentation forms / restoring logical order in the PDF reader (its own task; this one pins its acceptance).
- Swedish identifier rules (personnummer, org.nr, bankgiro, address).
- The signature-rule fix.
- The phone rule's decimal-point stop.

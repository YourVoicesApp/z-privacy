# 107 — A save that stays: the person's own Save, apart from the doors out

**Source:** the owner, 24 October 2026, on the morning Z was to publish. Publishing is postponed for this round by his word. Builder: **ed** (core + its one press). Branch off `c0326af`. **You own `docs/CLAIMS.md` in this round**; paper 108 (e2) does not touch it and sends you its lines through the lead.

## What was measured

Windows' paper-101 run (`docs/INBOX/to-linux.md`, entries of 23 and 24 Oct) measured the session file emptying to an empty body four times, each in the same second a z-pdf was written. The lead read the tree: it is **089 rule 9** («it has left»). Copy, pull and the PDF pass one exit door (`ops/mod.rs:690`), and `the_preview_has_left` takes the conversation file's copy of the document out. The law did what it says.

Then the owner answered the open question about 22 Oct 21:35:11: **«أنا حفظت جميع الملفات عن طريق حفظ نسخة PDF»**. Saving a protected copy is how he saves his work, and it was the only save he used. He met the empty list twice and read it as loss: «the session was emptied and this we do not want». Nothing was lost (the blocks are in the vault, the z-pdf is on his disk), but the document and its decisions were no longer in the session to open again. When the owner reads it as loss, every user will.

## The ruling (the owner's «نعم», 24 Oct): option 3

**A real Save, apart from the exits.** One press that keeps the document and every decision on it in the session, and sends nothing anywhere. The PDF stays an exit exactly as it is.

## What that means in the core: say it in the code before you build it

Rule 9 covers the **automatic** copy, the one the preview keeps for the person while the document has not left. That copy still leaves at an exit, unchanged.

A copy the person **saved by name** is their will. **It stays in the session's list after any exit, until the person removes it.** Read narrower, the Save is useless for the very workflow that found it: save, then PDF, and the list is empty again. So the law gains one sentence. Z keeps no document that left, **except the ones the person told it to keep**. Write that sentence where rule 9 is written (the doc block of `the_preview_has_left` and the kept-list's home), and in CLAIMS.md if a claim there says or implies «Z keeps nothing that left». Find every such sentence: the app's own words, the arb, the guide and the site. List them in your report. Lines outside CLAIMS.md and the app go to the lead.

Measure first, then decide the shape. The tree already has a kept list (`Body.kept`, `keep_the_preview`, `kept_documents`, `rename_kept`, `open`). The cheapest true design may be a flag on a kept row («saved by the person») that `take_the_copy_out` respects, not a second store. Your call, named in the report. The one law to keep: **a single hand removes a kept copy** (the doc block above `take_the_copy_out`). A saved copy is taken out only by the person's own delete, through that same hand.

## The press

One press on the glass, **«Save»** (or the shortest true word in the one list), where a person working on a document would look for it. It must be reachable from the document's own bar, not buried in a menu. It is the product's ordinary save. A press with no session open births the session the way the other doors do (064f/rule 55: a session is born at its first document). Its sentence after a save says what happened, in the session's name: e.g. «Saved in «Session 3».» It names no file, because nothing was written outside the session file.

Sentences go into `app_en.arb` with `app_de.arb` and `app_sv.arb` beside them (the one-list law). Swedish is written, not reviewed, as in 106. Keep the new keys in one block so 108's arb edits merge beside yours without overlap.

## Pins

- **Red first:** protect a word in a fixture document, Save, then save a PDF. The session's kept list still holds the document with its decision. Red on `c0326af`, green after.
- The automatic copy still leaves: the same flow **without** Save leaves the list empty after the PDF, so rule 9 still bites.
- Relaunch survives: Save, close the core, open again, unlock, and the document is in the list with its decisions. Same fixture vault, test passphrase.
- The person's delete removes a saved copy, and nothing else does (the copy, pull, PDF and gateway exits all leave it).
- The 102 §3 guard is untouched: a save over bytes this run did not read is still `SessionChangedElsewhere`.
- Fixtures from `z_core/tests/fixtures/` only. Test vault, test passphrase. Never a real document.

## Not in this paper

The PDF's own naming, the z-pdf press's place and the restored save are all 108's. Recovery-key work (Vault Format 3) is a later round of its own.

## Measurement

ed: `bash scripts/gates.sh` green on your branch, with rust and dart counts reported, the red-first pin named, and the list of every sentence that said «nothing that left is kept». The lead merges, measures and writes `MEASURED_ON_LINUX.txt`. The owner runs Windows on the merged tip before publishing.

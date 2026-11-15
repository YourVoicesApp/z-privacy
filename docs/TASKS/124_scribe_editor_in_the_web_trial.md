# 124 — Scribe's editor in Z's web trial

**Owner of the paper:** the lead. The owner settled every point in rules 88 and 88 (ح) before this paper was written.
**Builders:**
- ed builds the editor's engine for the browser (part A).
- e2 builds the editor's glass, the button and the report (part B).

**Source:** rule 88 with its amendment (ح) in `docs/RULES_AR.md`. Read it whole first, then 85, 87 and paper 123.

**Why now:** Web Summit's competitions for Doha open in about 7–10 days (from 15 Nov). The Z trial is published first. The editor follows it as soon as it is ready, and must not delay it.

## 0 · What is there today (measured, 14–15 Nov)

**Z's trial:** `feat/web-trial` in `~/z/build-lead-122`, at 70dd7b8 (papers 122 and 123). The chat, the document and «Start over» are built.

**Scribe:**
- Repository `~/mono-scribe`, branch `feat/mission009-first-writing` at 2b277e4. The Flutter app is `flutter/` (no `web/` folder); the Rust is in `native/`.

**ed's part C report (paper 123), from the scratch worktree `~/z/scratch-scribe-wasm`:**
- All five crates build for `wasm32-unknown-unknown`.
- Two calls trap at run time, and are fixed by scratch patches:
  - `std::time` (replaced by `web-time` 1.1);
  - `std::process::id` (skipped on wasm).
- The writing report runs in node: `{"words":{"keyboard","z","paste","voice","total"},"pages"}`.
- `ms_writing_z_insert` inserts text with `Source::Z`. `ms_writing_z_copy` stores text as Z's own, so a later paste of it counts as Z (DOC-020b).
- **Size:** with the two minimum faces (Source Serif 4 roman and Noto Naskh Arabic), an estimated 1.6 MB gzipped.
- **The glass:** about 21–25 doors. `main.dart` and `writing_screen.dart` use `dart:ffi`, and 12 files import `dart:io`.

## 1 · What the visitor sees (rule 88, 88 (ح))

1. **Z stays the main screen,** for the chat with AI. Nothing in it moves.
2. **Under the answer box:** a button with Scribe's logo, beside it «**Scribe**: a text editor for writing documents.» (ar: «**Scribe**: محرر نصوص خاص لكتابة الوثائق.»).
3. **Under each restored answer:** «Send to the editor». The answer goes into the editor as AI's text (`ms_writing_z_insert`), and the editor opens.
4. **The editor opens** with, at its top:
   - «For trying only: do not write anything important or real here.»
   - «Here you can see how many words in your text AI added, and how much of it you wrote by hand.»
5. **The editor:** the visitor writes and formats in Arabic or English, as in Scribe. There is no Z column, no AI, no `.peak`, no settings, no save and no print.
6. **The writing report at the bottom** updates as the visitor writes, with the count and the share of each source, e.g.:

   > Keyboard: 120 words (62%) · AI: 58 (30%) · Paste: 15 (8%)

   - The source the engine calls `z` is shown as «AI».
   - The percentages are computed by the screen from the engine's counts.
   - Voice is not shown.
7. **A paste of text Z copied** (the restored answer, copied with the trial's own Copy) counts as AI (88 (د)). The page remembers Z's copy in memory only, through `ms_writing_z_copy`.
8. **Under the editor:** a short description, and questions and answers. The first is «Why is there a text editor here?» with the owner's answer in 88 (ح). No company is named.
9. **Leaving the page, or «Start over»,** erases the editor and its report with everything else.

## 2 · First: the shape (ed and e2 together, a short report before any build)

Scribe and Z are two repositories and two Flutter apps. Propose the shape in one short report to the lead. The lead's default, to be argued with:
- **Scribe's web editor is built in `~/mono-scribe`** as its own Flutter web entry (`lib/main_web.dart`) and wasm module. No Scribe code is copied into Z.
- **Z's `site-trial/` build includes that bundle** under `/<lang>/try/scribe/`.
- **Z's trial opens it in an overlay `<iframe>`** of the same origin, and hands it text by `postMessage`, in memory only:
  - the answer sent «to the editor»;
  - Z's copy, for 88 (د).
  - CSP grows by `frame-src 'self'` and nothing else.
- Leaving or «Start over» drops the iframe.

Name the trade-offs:
- page weight, and whether the two Flutter engines share cached files;
- focus and the IME across the frame;
- right to left;
- the CSP;
- the time it takes.

A better shape wins if it keeps the repositories apart, and is ready sooner.

## 3 · Part A (ed): the engine in the browser

1. **Work in a new worktree of `~/mono-scribe`:** branch `feat/web-editor` from 2b277e4. Bring the scratch patches over cleanly:
   - one clock (`web-time`) for every `std::time` use reached on wasm;
   - no `process::id` on wasm.
   - **The native build must not change by one byte of behaviour.**
2. **A web bridge,** as in 122: JSON in, `{"ok"}` or `{"error":"<name>"}` out, with the session as a number.
   - **Only the doors the editor and the report need** (part C's list).
   - **Not exported:** save, open, projects, cabinet, the document list, fonts on disk, PDF, print and AI. A gate proves they are absent from the module.
3. **Fonts:** Source Serif 4 roman and Noto Naskh Arabic, embedded. Name the module's size, raw and gzipped.
4. **Tests:**
   - the report's counts by source for: keyboard text, a `z_insert`, a paste of `z_copy` text, and a paste of other text;
   - Arabic and English;
   - the native and web builds give the same counts for the same steps;
   - **the control:** a paste of text Z did not copy counts as Paste.

## 4 · Part B (e2): the glass

1. **The editor's web entry in Scribe's Flutter app,** drawing the sheet from the engine's RGBA frame as the desktop does.
   - Keep `dart:ffi` and `dart:io` out of the web build by conditional imports. Do not delete what the desktop uses.
   - The toolbar is kept only where its doors are in part A's list.
2. **The report bar,** from the same table `save_report.dart` draws. Do not draw a second one.
   - Add the share per source.
   - «z» is shown as «AI».
3. **In Z's trial** (`~/z`, a new branch from 70dd7b8):
   - the Scribe button and its sentence;
   - «Send to the editor» under each restored answer;
   - opening and closing the editor;
   - the hand-over of Z's copy;
   - «Start over» and leaving drop the editor.
4. **Sentences:**
   - In Scribe's `.arb` files: the editor's two top sentences, the report's labels, and the description and the Q&A.
   - In Z's `.arb` files: the button's sentence and «Send to the editor».
   - The lead gives Arabic and Swedish. English is in §1. German, French and Spanish are marked as written with AI.
5. **Tests:**
   - **Pin first:** Z's trial has no Scribe button.
   - «Send to the editor» puts the restored answer in, and the report shows it as AI.
   - The editor's top sentences are present.
   - The share adds up to 100 % (rounding named).
   - A paste of Z's copy counts as AI; any other paste counts as Paste.
   - No save or print control exists.
   - Nothing is written to storage after a full flow (G74's browser test).
   - Right to left in Arabic.
6. **Shots:** the editor with its report, in English, Arabic and Swedish, at 390 px and 1440 px.

## 5 · Gates

- Scribe's `tools/gates.sh` and Z's `scripts/gates.sh`, both all green, with counts.
- Z's G74 and G75 run against the real modules, Scribe's included.
- Commit after the gates, never while they run.
- Do not push in either repository.

**Order:**
1. ed and e2 report the shape (§2) to the lead. Half a day at most.
2. Part A and part B are built in parallel against the agreed door shapes.
3. The lead merges, rebuilds `site-trial/` and gives the owner the preview.
4. The owner previews. The Z trial is published before this, and does not wait for it.

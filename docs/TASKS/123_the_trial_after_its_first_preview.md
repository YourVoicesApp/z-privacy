# 123 — The web trial after its first preview

**Owner of the paper:** the lead. The owner reviews the Arabic summary before anyone builds.
**Builders:**
- ed builds the core part (part A) and measures Scribe's editor in the browser (part C).
- e2 builds the screen (part B).

**Source:** rule 87 (أ)–(د) in `docs/RULES_AR.md`, and rule 88 (ز) for part C only. Read 85, 86, 87 and 88 first, then 62 and 65–68.

**Base:** `feat/web-trial` at `67cd2a9` (paper 122, merged and pushed). Branch from it.

## 0 · What is there today (measured by the lead, 14 Nov)

**The owner's preview.** The owner tested the preview on 14 Nov. English on `/sv/try/` passed in full, and so did a second Arabic run: every name came back in the document. A first Arabic run kept its tokens, and its cause was not caught.

**The trial screen** (`lib/web/the_trial.dart`) has three parts:
- the original (one field, hint «Ask a question, or paste a whole letter here.»);
- the protected side, with «Copy protected»;
- one answer box, with «Add an answer».

It then shows the document. There is no thread, no box for a second question and no way to start over except a reload.

**The restore probe.** The lead ran the BUILT `z_web_bg.wasm` in node, with invented Arabic text and pack `ar`. The tokens look like `__Z_9F3F_PERSON_A2C0__`.

| What the pasted answer held | Result |
|---|---|
| tokens with spaces around them | restored |
| a glued «،» «,» «.» «:» or «(» | restored |
| tokens in backticks or inside `**…**` | restored |
| `__` eaten on both sides (`Z_9F3F_PERSON_A2C0`), as markdown bold is when a rendered chat is copied | **plain text: not restored, not even reported** |
| one leading `_` lost | not restored |
| underscores escaped (`\_\_Z\_9F3F\_…`) | not restored |
| a space inside the token | not restored |
| lower case | not restored |
| an RLM (U+200F) inside the token | not restored |

The token finder is `z_core/src/tokens.rs:514` and `:637`. It looks for `__Z_` … `__`, and `parts_of` (`:669`) splits on `_`.

**Doors the app's chat already has** (`z_core/src/api.rs`):
- `set_question` :2777, `question` :2784;
- `build_the_question_alone` :2689;
- `chat_to_take_out` :2721, which is rule 65's copy with the history;
- `end_the_chat` :2732 and `the_open_chat` :2739;
- `conversation_record` :2404 and `conversation_turns` :2418.

**Not measured:** whether these doors run with no vault and no conversation file, as the web build is. Measuring that is ed's first step.

**The app's chat part** is `lib/widgets/the_chat.dart`:
- the thread `TheChat.thread`;
- the box `TheChat.compose`, with the hint «askSomethingElseAboutThis»;
- the paste box `TheChat.pasted`, with `addIt`;
- `copy` and `end`;
- «Show the text» per answer (`TheChat.showTheText(i)`).

## 1 · What the visitor sees after this paper

1. **The first turn is as today:** write, protect, copy, paste the answer, «Add an answer».
2. **The chat opens with the first answer** (87 (أ), rules 65–68).
   - Each answer is shown coded, with one «Show the text» that opens the restored text.
   - Under the thread is a box: «Ask something else about this». Z scans and protects it as it scans the original. The same name is the same token.
   - «Copy protected» now copies the chat as rule 65 has it: the earlier turns, protected, and the new question.
   - The visitor pastes the next answer into the same answer box.
3. **The document** holds the whole chat: the visitor's text as written, then each question and each answer restored, in order.
4. **The copied text starts with one line** (87 (ج)) asking the model to give every code back exactly as written.
   - The line is in the page's language.
   - It holds no value and no token.
5. **«Start over»** (87 (د)) sits at the top of the trial.
   - If a document is on the page, it asks once: «Everything on this page will be erased. A copy you saved on your device stays yours.» The two buttons are «Erase» and «Cancel».
   - On «Erase» it empties:
     - the original, the protected side and the answer box;
     - the thread and the document;
     - the core's session, so its tokens are gone from memory.
   - It empties the clipboard first if Z's copy was the last thing on it.
   - The page's language and the chosen pack stay.
   - The next text gets new tokens.

## 2 · Part A (ed): the core

1. **Measure first, and report before you build.** For each door in §0, does it run in the `web` build with no vault and no conversation file?
   - Name what each needs that the web lacks.
   - Propose the smallest cut by Cargo feature, as in 122: no copy of the core.
2. **The chat doors on the web.** Add them to `bridges/web` with the same JSON shape as 122 (one JSON string in, `{"ok"}` or `{"error":"<name>"}` out).
   - Doors: `z_set_question`, `z_chat_to_take_out`, `z_end_the_chat` and whatever turn listing the screen needs.
   - Write each door in the contract.
   - The answer pasted against `z_chat_to_take_out` is restored by that payload's allowed list (G9), as in the app.
3. **A token whose shape the chat page changed** (87 (ب)). This is in the core, so the app gets it too. A candidate is read as a token when ALL of these hold:
   - it is one of these forms:
     - `__` eaten on either or both sides (`Z_9F3F_PERSON_A2C0`);
     - or every `_` escaped as `\_`;
   - put back into its true shape, it is a token **in the payload's allowed list**;
   - and it stands at a word boundary: no letter or digit glued before or after it.

   Rules that stay:
   - Nothing else changes.
   - The allowed list is still asked first and still decides by itself. Widening the shapes read must not widen what a turn may carry.
   - A bare look-alike of another conversation's namespace stays text, as today.
   - Lower case, a space inside and direction marks are **not** in this ruling: report them, and do not read them.
4. **«Start over» in the core:** a door `z_close` that drops the session and everything it holds from memory.
   - A later call with that session id is refused by name.
5. **Tests:**
   - Every row of the §0 table becomes a test. The rows the ruling covers turn green; the others are pinned as they are.
   - **Pin first:** the eaten-`__` row asserts today's «plain text», red against 87 (ب).
   - **The control:** an eaten token from another namespace, and a bare token not in the allowed list, both stay text.
   - The chat doors on the web give the same history text as the native build for the same fixture turns (parity, as in 122).
   - After `z_close`, the session is refused and no token of it restores.

## 3 · Part B (e2): the screen

1. **The chat part** under the answer box, built from what `the_chat.dart` draws:
   - the thread, «Show the text», the compose box, and copy.
   - Reuse its pieces where they need no `dart:io`. Do not draw a second chat.
   - On the web there is no provider row: the key press stays as 85 (ز) has it.
2. **The answer box stays one box** for every turn. It is pasted into with Ctrl+V or the right button's «Paste». There is no clipboard-reading button: the browser would ask permission each time.
3. **The keep-the-codes line** (87 (ج)) is the first line of what «Copy protected» copies, on every turn.
   - New `.arb` sentence in all six languages; the lead writes Arabic and Swedish.
   - It is the same line in every turn.
   - It is never shown in the protected side as the visitor's own text.
4. **The document (PDF and page)** holds every turn: the visitor's text, then «Question 2», its answer, and so on, each answer restored.
5. **«Start over»**, at the top of the trial. Its question and buttons are as in §1.5. It calls `z_close`, opens a new session with the same pack and empties every field.
6. **Tests:**
   - **Pin first:** today there is no compose box after the first answer (red against 87 (أ)).
   - A two-turn flow on fixtures: the second question carries the first turn protected, and the document holds both turns restored.
   - The copied text starts with the line, in Arabic on `/ar/` and in English on `/en/`.
   - Start over:
     - with a document on the page, it asks, and «Cancel» keeps everything;
     - «Erase» empties every field and the old tokens no longer restore;
     - with no document it does not ask.
   - Nothing is written to storage after a two-turn flow and a start over (the browser test of 122).
   - The notice band shows in every new state.
7. **Shots:** a two-turn chat in English, Arabic and Swedish, and the start-over question, at 390 px and 1440 px.

## 4 · Part C (ed): measure Scribe's editor in the browser, and build nothing

This part is for rule 88 only. It is a report, not a build, and the report comes to the lead.

**Where:** read `~/mono-scribe`, and make a scratch worktree of it for the trial build. Do not touch its branches or its open work. Nothing is committed in `~/mono-scribe`.

**What to measure:**
1. Do `native/text_engine` (cosmic-text), `native/writing` and the parts of `native/writing_ffi` that the editor and the writing report need build for `wasm32-unknown-unknown`?
   - Name each crate or feature that does not build, and why.
   - The PDF (`krilla`) and the AI crate are not needed: name what leaves with them.
2. **Fonts:** which faces does the editor need for Arabic and Latin, at the least? What size are they, and how does cosmic-text take them with no system font database?
3. **Size:** what is the editor's `.wasm` size, and the size with its fonts, compressed and not?
4. **The writing report:** which call gives the counts by source (keyboard, paste, Z)? Can an insert be marked with the AI's source from outside (for rule 88 (د)), and through which door?
5. **The glass:** which Scribe Dart files draw the editor and the report through `dart:ffi`? Roughly how many doors would the web need, as in 122?

## 5 · Gates

`scripts/gates.sh` all green, with counts. This includes:
- the new token tests;
- the chat parity tests;
- G74 (the browser test) run against the real module;
- G75 (the preview checks).

Commit after the gates, never while they run. Do not push, and do not deploy.

The Dart suite rewrites paper 121's fr and es pictures: restore them with `git checkout` before you commit.

**Order:**
1. ed measures part A step 1 and reports. ed also starts part C and reports it separately.
2. ed builds part A.
3. e2 builds part B on it, and may start the chat part and «Start over» against the doors' shapes.
4. The lead merges both, rebuilds `site-trial/` and gives the owner the preview.
5. The owner previews.

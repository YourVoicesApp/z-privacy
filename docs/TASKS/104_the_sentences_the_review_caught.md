# 104 — The sentences the review caught: what we say is trimmed to what we measured

**Source:** `docs/ATTACKS/CLAIMS_REVIEW_2026-10-23.md` — the outside model (GPT-5 Codex) graded the sixteen claims at `e7a8f8f`: 8 confirmed, 3 exaggerated, 2 false, 3 not measured. **Both false verdicts are sentences, not behaviours**: the product does the right thing and the sentence promises more. The prompt's own last paragraph makes every exaggerated/false line a paper before publishing; this is that paper. Builder: **ed** (core, claims, arb, README). The site's two lines are e2's (paper 105). CLAIMS.md is touched in this paper only, so the two branches cannot collide.

Rule of the round: **no behaviour changes.** Every fix here is a sentence, a limit line, or a command — the one exception is §6, which is a test command's prerequisite. A fix that wants to change what the code does is out of scope and comes back as a question.

## 1 · C-05, false — «can never be unprotected again — not by you» meets «Undo protection»

The truth, from the tree: `undo_last_protection` (`z_core/src/ops/mod.rs:3181`, 096's undo half) takes a **cover back inside the request** — before anything leaves, no entity created or destroyed, the vault block untouched. So there IS a moment when the person un-protects by hand, and the sentence `everyDocumentCanNeverBeUnprotected` says «never — not by you».

The fix: the sentence gains its boundary. Permanence begins where the hand's choice ends — **when the words leave** (a sent message, a kept document). Proposed shape, ed words it properly in all three languages through the one list: «Once a document or message leaves protected, it cannot be unprotected again — not by you, and not by Z Privacy. Until it leaves, «Undo protection» takes a cover back.» CLAIMS.md C-05's limit line names the request-undo explicitly and cites 096. **Pin it:** a test (or an existing one extended) that asserts undo exists before send and that no API un-protects after the message left / the document was kept — the reviewer's counterexample becomes our own guard.

## 2 · C-06, false — «A vault is the only file this app writes»

`aVaultIsTheOnlyFile` (`app_en.arb:1712`) while the app also writes `sessions/*.zs` and `settings.zcfg` — both lawful, both already disclosed in C-06's own gate (the permitted-sites census). The sentence is G15's promise to the person with no vault yet; it keeps its soul and loses its lie. Proposed direction: «Your names live in one encrypted vault file…» — say what the vault IS, not that it is alone. `README.md:24` («written here and nowhere else») falls in the same stroke. CLAIMS.md C-06's limit line already lists the three file classes per the reviewer? — no: it discloses `settings.zcfg` but not sessions; add the session files.

## 3 · C-07 + C-10 + C-14, exaggerated — three limit lines, no code

- **C-07**: the limit line is already honest post-102 (it names the session gap and the next eye round). What overclaims is the claim's **title** «never lose a write». Retitle or qualify in CLAIMS.md so the headline carries the limit: the measured promise is the vault between two processes, and the session file one-process-plus-a-hand.
- **C-10**: add to the limit line that the corpus is finite — the named numbers are real limits and the measured shapes are listed, but not every encoding/boundary combination is covered.
- **C-14**: the title «says nothing about the machine» narrows to what the command measures: a path-and-symbol scrub of the Linux archive; the Windows gates are shape checks on the job, and no Windows artefact is produced by the stranger command.

## 4 · README drift (reviewer's finding 5)

`README.md:36-47` still says 314 sentences / 22 screens and «No run of it has been measured into docs/ yet». The tree says 691 sentences / 29 files (`check_the_one_list.py`) and the Windows job has run and reported (docs/INBOX, seventh–tenth reports). Rewrite the paragraph to the current truth — and since drift is the disease, prefer sentences that name the measuring command over sentences that name a number, wherever the gate already checks the number elsewhere.

## 5 · The claims file says what its gates are (reviewer's finding 6)

One sentence in `docs/CLAIMS.md`'s preamble: many proofs are source-shape gates (greps over the tree), which prove repository shape, not runtime capture — the runtime proofs are the tests, and C-04 stays «unproven» precisely because no runtime network observation exists. The reviewer had to derive this; the file should say it.

## 6 · C-02's stranger command fails on a fresh clone (reviewer's C-02)

`flutter test test/copy_report_test.dart` dies in `setUpAll` without the built bridge. The command in CLAIMS.md gains its prerequisite (`flutter build linux --debug` first, from `apps/flutter_app`), and C-02's limit line states the build requirement. If the test can instead **skip with a sentence naming the missing bridge** rather than erroring in setup, that is the better red — a stranger should read «build first», not a LateInitializationError.

## Not in this round

The download pages' placeholder red (reviewer's finding 4) is paper 103 working as designed — publishing day's swap. The homepage provider sentence and the guide's «nothing is lost silently» are e2's (105). C-04 and C-15 stay unproven on purpose; the guide's structural-not-behavioural checking (finding 1) is named, not fixed — the behaviour tests exist in Rust and the site gate never claimed to be one.

## Measurement

Ed branches off `e7a8f8f` (`feat/the-sentences-the-review-caught`), reds first where a pin is named (§1), full gates green at the end; the English-suite sentence guards must move where a meaning moved — a green suite over a changed sentence is its own finding. The lead merges, measures, and the owner's word pushes. The next outside review (there will be one at the publishing commit if time allows, else post-publish) regrades C-05/C-06 from false.

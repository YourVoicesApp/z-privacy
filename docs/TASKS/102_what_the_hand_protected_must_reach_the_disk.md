# 102 — What the hand protected must reach the disk, and what the disk refused must reach the glass

**Owner, 22 October (rule 55-ز, «نعم»):** the two-window eye round on the `78988fd` artefacts (tenth report in `docs/INBOX/to-linux.md`, screenshots 01–09) measured four product faults the night before publishing week. This paper is their fix round. Builder: **ed**, branch off the lead line at `7fb59b1` or later. Pre-publish weight: the faults break two sentences published on the live guide pages — «nothing is lost silently» and «everything protected is one block per value in your vault».
**Sources:** the tenth report's minute table (reports section «Step 5 — the lock, two windows»); ed's two code walks of 22 October (relayed in the session record; the seams are named with file:line there); the preserved folder on the Windows machine `C:\Users\anash\z\testdata\78988fd\LocalAppData-lock-r2`.

## 0 · The reds come first

Ed pins the failure before any fix, as the house does, in three shapes:

- **R1 — typed text writes nothing.** A documentless bench whose session is already open: hand-protect a word in the request; read `vault.zv` and `N.zs` after; assert the WRONG behaviour (nothing written) so the fix item flips it.
- **R2 — «Protected as …» over a refusal.** A copy whose vault fell behind the disk (another copy wrote): a protect press answers the glass «Protected as …» while `remember_blocks` was refused; no sentence appears. Pin the silence.
- **R3 — the half-write.** `the_decisions_are_written` succeeds on its session half and is refused on its blocks half: the on-disk session copy names protected places whose blocks are absent from the on-disk vault — and `open_kept` resolves them from marks+text, so the reopened document shows protected with a green glass. Pin exactly that: write the copy, refuse the vault, reopen, ask the vault for the blocks.

## 1 · The session is born at the first act worth keeping (rule 55-ز)

A hand protection in the request births the session if none is born yet — same door as the first document and the first outgoing question. Blocks are then written **the moment they happen** on every path (rule 54-أ), including the documentless bench whose session was already open (tonight's «no blocks ever» case: `name_tokens_from_the_vault` must name a documentless bench once its session exists, and `blocks_from_this_bench` must count them). The deliberately-pinned test «a question that never leaves is born into nothing» changes with the rule — its new face: a question that never leaves and was never protected is born into nothing; one hand protection is an act worth keeping.

The typed request's **text** follows the same birth: the Kept record (or a sibling) carries the question and its protections so a typed-only session survives a close — today the record has no fields for either, so «documents are saved, typed text is not» (the owner's first sentence of the night) is structural. What is NOT promised: unsent drafts in a bench never protected and never sent still die with the window, lawfully.

## 2 · A refusal reaches the glass on the protect doors

- `remember_blocks` stops swallowing: `made.unwrap_or(0)` and the `Ok(0) | Err(_)` read-swallow both surface the error instead of answering «zero new».
- `the_decisions_are_written` stops discarding: the blocks half's count/error and the `let _ =` on the session half both report; its callers (`protect`, `protect_all_matches`, `protect_cell_in_lines`, `set_question`, `protect_in_the_request`, `scan`, `answer_finding`, the undo doors) carry a disk verdict beside the memory verdict, and the glass shows `troubleVaultChangedElsewhere` where the import door already would — the wiring becomes consistent instead of one door connected and its sibling not.
- A copy that fell behind heals or says so: today `ensure_disk_unchanged` fails **every** later write until a lock+unlock, silently. After this item it fails loudly with the sentence that already exists for it; whether the copy then re-reads and retries once is ed's design decision, named in the paper's record either way.

## 3 · The session file is written like the vault is written

- A compare-before-replace for `N.zs` (the analogue of `ensure_disk_unchanged`), so a stale body can never replace a fuller one unread. The report's 21:35:11 line (2937 → 50 bytes, vault untouched) is the measured case; ed's arithmetic says the 50 bytes are an empty sealed body and no z_core writer could have produced it without the vault moving — so this item is the guard, and §6 chases the author.
- **A birth never writes over an existing `N.zs`.** The conversation number comes from the vault model's counter, so a new vault in an old folder starts at 1 and `begin_in` writes its default body over another vault's file, no question asked. The birth checks the floor first; finding a file there is a refusal with its own sentence, not an overwrite.

## 4 · The badge tells the truth on typed text

The scanner runs on the typed request (`set_question → protect_lines`), yet the badge reads the **document's** scan origin and says «Not scanned yet» forever on a documentless bench. The badge reads what actually ran. (The «Typed text» tab label over an empty `DocumentView` is part of the same seam — `Snapshot.document` is not an Option, so a documentless bench hands an empty document the glass then names; ed decides whether this round or named-for-later, and writes which.)

## 5 · The fourth rename list

`names_again_from` renames `protections`, `question_tokens`, `question_safe` and the answer-page token — and leaves `question_protections[].token`, so a session born at its first exit sends later hand-protected request words out under pre-birth names the vault can never resolve. The fourth list is renamed with its sisters. (Same family as the one-list traps in the memory: a rename applied to a list of records and its sister left.)

## 6 · Named, measured where cheap — not necessarily built this round

- **The 50-byte author.** The Windows session is asked for `dir /a` of the preserved folder's `sessions\` directory (leftover `*.new` temp files above all: the Windows `create_new` branch refuses forever after a leftover, and the refusal is swallowed today — §2 removes the silence either way). If the listing shows no leftover, the author was outside our code (folder copy, sync, antivirus) and the report says so; nothing more is owed.
- **The latent scope gap:** `protect_in_the_request` returns before `require_open_vault`/`remember_in_vault`, so Always/Profile scope on a request word is a promise nothing writes — unreachable today (the glass only passes conversation scope). Named here so the item exists the day the glass widens.
- **The owner's wish, twice tonight:** the session's name stands in the window's title bar once a session is open (today it appears only after a document). Small glass item; ed takes it in this round if it is one line in the shell's title wiring, else it is named for the next.

## 7 · Not in this round

The two-window merge question (B taking in A's work without lock+unlock) stays answered by the existing sentence; no live sync. The MSIX vault escape (rule 84's per-installer debt) is its own named debt. The Windows re-measurement of this paper's fixes belongs to the next eye round.

## Measurement

Ed: reds R1–R3 pinned first and shown red at the base commit; then the fixes, gates green including the changed pinned test's new face; `dart format --output=none`, clippy clean, the usual. The lead merges, measures on Linux (gates + a hand walk of the typed-request path on the installed build), updates `MEASURED_ON_LINUX.txt`. The Windows two-window walk re-runs at the owner's hands in the next round; the guide's sentences stand unchanged — the product rises to them.

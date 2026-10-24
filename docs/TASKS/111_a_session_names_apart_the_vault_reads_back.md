# 111 — A session names apart; the vault reads back: C-09 says where the wall is

**Source:** the owner's own Windows test, 24 October 2026 (Windows entries `d5d212d`, `8206c8a`, screenshots 14–15). Builder: **ed**, after 110 is merged. Branch off the lead tip at that moment. Files: `docs/CLAIMS.md` (C-09), and `app_en.arb` with its de/sv siblings for key `eachSessionHasItsOwnEncryption`, plus anything else that sells sessions as a wall.

## What was measured

The owner built a second session («الجلسة الثانية», root 3FEE) in the paper-101 test vault and saved a z-pdf from it. The process was ended and started again to rule out memory. He unlocked, stood in **Session 1** (root 235A), and read the file through the z-pdf door: «20 names came back from «الجلسة الثانية».» All 20, across a restart, naming the session they came from.

He **expected isolation**, and he had it from our own sentence on the Sessions panel: «Each session has its own encryption. The same name in two sessions takes two different tokens…». That sentence is true about **naming** and leaves a reader expecting a **wall** that is not there. His verdict on the behaviour: «I think the vault works excellently». So the behaviour stays. The words move.

## The truth, as the tree has it

- **Naming is per session.** The same name takes a different token in each session, and a model cannot line two sessions up. `a_token_does_not_cross_a_session.rs` measures that an **answer** restored inside a chat restores only that session's tokens (G9's allowed list). That stands.
- **The way back is the vault's, not a session's.** The z-pdf door (079: «a file read into its own names, with no bench») restores names from **every session this vault holds**, and says which session they came from. A vault that does not hold the session says so instead, verbatim on Windows: «This document carries 19 names from a session this vault does not hold (6466). Nothing here can put them back: the key that made them is not in this vault.»
- So **the vault is the boundary of who can read back, and the session decides how a value is named.**

## What moves

- **C-09's headline** stops saying «isolated». Something like «Sessions are named apart: the same name takes a different token in each», in your words. The limit gains one sentence naming the z-pdf door as the vault's: it reads back names from any session in this vault and names that session. A vault without the session cannot. G66 pins sentences, so move its pin with it.
- **`eachSessionHasItsOwnEncryption`** keeps what it says about tokens and stops implying a wall. Add one clause or sentence: anything saved from any session in this vault comes back through z-pdf in its real names. Same fact in de and sv (sv written, not reviewed).
- Find every other place that sells sessions as isolation: the site, the guide and the arb. List them. Site lines go to the lead for e2.

## Not in this paper (named, for the record)

- The z-pdf's footer counts the body (23 places, 18 values) while the read-back sentence counts the file (19 names, the document's own protected name on page 2 included). Both are honest, and on one screen they read as a conflict. It is a later paper.
- Reading a z-pdf by **importing it as a document** (not through the door back) makes the reading session protect the foreign tokens again under its own root. Measured on Windows: a 3FEE token became `__Z_235A_BIC_…__`, writing 29 B to vault.zv. A token scanned as a value is the «search lands inside our own token» family, and it writes a permanent block. It is a debt named for the round after publishing.

## Measurement

`bash scripts/gates.sh` green with counts. G56 still 17 claims, G66 moved to the new headline, and the list of «isolation» sentences found. The lead merges.

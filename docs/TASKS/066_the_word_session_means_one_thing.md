# 066 · The word «session» means one thing

**A debt created knowingly by 064, numbered so it cannot evaporate.**
**Runs immediately after `fix/the-chat-reads-like-a-chat` merges — not before,
and not never.**

064 found the core's `Session` (`z_core/src/session.rs:112`) already taken: it is
**one document's bench** — original, protections, findings, tokens, question.
The owner's session (the named, keyed, surviving thing) entered the code as
`Conversation` to avoid regenerating a bridge under a live branch.

Measured at decision time: the type `Session` appears **20** times, all
`pub(crate)` — cheap. The API parameter `session: u32` appears in **431** Dart
sites — a bridge regeneration, which is why this waited for the design seat's
branch to land.

## Do

1. `Session` → `Bench` in the core, 20 sites.
2. The API parameter `session:` → `bench:`, regenerate the bridge, let the 431
   Dart sites follow the compiler.
3. After this task, grep for the word: «session» in code refers to the owner's
   session and nothing else. One word, one thing — wherever two places can
   disagree about a fact, one is already wrong, and a noun is a place.

## Guard

`grep -rn "session" z_core/src apps/flutter_app/lib` names only the owner's
session and the API's `bench:` parameter. Run it in the task's report, pasted,
not summarised.

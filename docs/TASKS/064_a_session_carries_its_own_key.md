# 064 · A session carries its own key

**Step 4 of four, and the one that moves the bytes on disk.**
Settled with the owner, 8 Oct 2026. **Not built.** Supersedes the open questions
in `062`; `062` stays as the reasoning that led here.

> **«كل جلسة لها تشفيرها. وإلا لماذا الجلسات. نفس الاسم في جلستين يأخذ رمزين
> مختلفين.»** — the owner

---

## The shape

```
the language — the environment, as he ruled on 7 Oct
  ├── its lists        one file
  └── its sessions     one file each, one key each
```

A session is born of the act that needs it: pressing **Copy**, or exporting a
**PDF**, while no session is open. The name is asked **once**, then. Entering an
existing session asks nothing. **There is no «new session» button**, which is why
there is no argument about where it would live.

What a session keeps follows where the conversation happened:

* **inside the app** — the conversation whole;
* **outside it** — the question that was copied and the answer that came back.

## The key, and the three things derived from it

One random 32-byte key per session, sealed in the vault beside the session's
number and name. The vault holds the keys; the sessions are their own sealed
files, because `vault.zv` is re-sealed whole on every change and a conversation
inside that body would rewrite every byte the person owns on every save.

```
session key ──┬── derive(…, "z-privacy/session/1/seal")       seals the file
              ├── derive(…, "z-privacy/session/1/namespace")  the token namespace
              └── derive(…, "z-privacy/session/1/value")      the token tails
```

Three new purpose strings, never reused, as `crypto.rs:76` requires.

**This changes a shipped property of 046/U, deliberately and not quietly.** The
namespace was MAC(key, "namespace", profile ‖ document-text). It becomes the
session's own derived key. So:

| | before | now |
|---|---|---|
| same person, two documents, one session | two tokens | **one token** |
| same person, two sessions | two tokens | two tokens |
| same person, two clients | two tokens | two tokens |

046/U's rule — *stability across days and linkability across requests are the
same property* — is not repealed. It is **handed to the person**: a new session
is a clean break, the same session is continuity, and choosing between them is
now an act they perform rather than a rule we impose.

## And the owner's deletion warning becomes literally true

I told him his wording — *a protected document cannot be unprotected after its
session is deleted* — was stronger than the mechanism required, because a token
is derived and a value still in the vault could be derived again.

**With a key per session that is no longer so.** Delete the session, the key is
destroyed, and nothing derives anything. The warning is a fact, not a caution,
and the measurement `062 §B` was waiting on is no longer needed to decide it.

The warning must therefore be shown **at the moment of deletion**, and name what
dies: every document and every message protected in this session.

## Consequences to build deliberately, not discover

1. **A document opened in another session gets new tokens**, and an old answer
   restores only in its own session. That is correct, and it is the reason
   sessions are named and listed at all.
2. **A restored session whose document moved must refuse, not guess** — `062 §C`
   stands unchanged.
3. **Auto-lock must not become the power cut again** — `062 §D` stands. The
   sealed file survives a lock; only the key is forgotten, and the next unlock
   returns it.
4. **Deleting the name and deleting the map are one act here**, because the key
   is the map. They cannot be separated, so they must not be offered separately.

## Guards, written first and watched to fail

1. Protect the same name in two sessions; **the tokens differ.**
2. Protect the same name in two documents of **one** session; **the tokens are
   identical.** Against today's code this fails, which is the finding.
3. Delete a session, then try to restore an answer made in it: it refuses, and
   the refusal names the session by its name.
4. Lock the vault with a session open, unlock it, and the session is still there.
5. The vault body does **not** grow with a conversation: write a long one, and
   `vault.zv` is unchanged in size.

## Versions, settled with the builder (8 Oct, night)

Three numbers now, each owning one artifact, none borrowing another's:

* `FORMAT_VERSION` stays **2** — the envelope (Argon2 params, wrapped master)
  does not move.
* `MODEL_VERSION` 11 → **12** — session records (number, name, 32-byte key) join
  the body, their own section at the end as 11's was. **This spends the number
  the 8 Oct ruling had reserved for 046/S, which becomes 13.** The lead's ruling
  moves, said here and in the comment above the constant, not in one of them.
* `SESSION_FORMAT_VERSION = 1` — the sealed session files are not this format
  and must not borrow its version. Its comment names the other two numbers and
  what each governs, the way the MODEL_VERSION comment already does, because
  three version numbers triple the room for the two-places-disagree mistake.

And the noun: the core's `Session` (session.rs:112) is **one document's bench**,
not this task's thing. The new type is `Conversation` in code and «session» in
every word a person reads — the `p-<slug>-<n>` precedent, a code name the person
never typed. The API parameter `session: u32` keeps meaning the bench until 066
pays that debt; it is named there, numbered, and scheduled, so it cannot rot
quietly.

## Not in this task

Recovery (`059`) — **re-ordered by the owner, 8 Oct evening**: sessions are built
now, recovery is the workshop immediately after, and this is built **assuming a
recovery path will exist**. The format already satisfies that assumption — the
second wrapped-master slot does not know or care where its secret lives — so the
assumption changes wording, not bytes: the passphrase-loss warning will say
«your passphrase AND your recovery key», and the session-delete warning stays
absolute, because deletion is a chosen act no recovery undoes.

Shamir, and any «several recovery blocks» field in the format: out, as settled.

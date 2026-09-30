# The red-team harness — 28 September 2026

The attacker that produced **F-01 … F-12**, and the only thing that can
close the Hardening phase as it was specified: *the same harness, re-run,
with no change in our favour.*

It lives in the repository because it is **evidence**, not a tool. It was
kept in `/tmp` for a day, where one reboot would have ended the phase.

```
original/   Immutable adversarial harness captured from the 2026-09-28
            red-team run. Do not modify it.

ported/     Compatibility-only version for the current public API.
            Security attacks and assertions must not be weakened.
            Every divergence from original is documented.
```

`HASHES.txt` carries SHA-256 and MD5 for every file in `original/`, and
**gate G21 checks them on every build** — so no commit six months from now
can quietly edit the old attacker while we go on saying the same test still
passes.

## Running it

The harness is its own crate and is **not** a workspace member: it depends
on `z_core` by an absolute path, so it builds where it stands rather than
being carried along by every ordinary build.

```bash
cp -r redteam/2026-09-28/original /tmp/zprivacy-harness
cd /tmp/zprivacy-harness
# Point it at this checkout if the absolute path in Cargo.toml is not yours.
cargo run --bin url        # F-01 probe: loopback spoofing
cargo run --bin kdf        # F-03: unbounded Argon2 parameters
cargo run --bin fs         # F-04: symlink and temp-file games
cargo run --bin rollback   # F-02: an older valid vault
cargo run --bin trailing   # F-09: bytes after the end of ZVLT
cargo run                  # F-01 · F-05 · F-06, and F-07 with a path argument
```

## Why `ported/` exists

`original/src/main.rs` **no longer compiles**. The F-05 fix deliberately
narrowed the contract:

```text
ingest_answer(SessionId,     raw)    →    ingest_answer(PayloadHandle, raw)
```

That is a narrowing, not a softening — an answer is now bound to the payload
the model actually saw. But it means the attacker cannot be run verbatim, and
saying otherwise would be the sort of untruth this project exists to hunt.

### `ported/main_ported.rs` — the only true port

**Exactly two edits**, both forced by that signature, both named in the file's
own header:

1. `ingest_answer(s,  …)` → `ingest_answer(handle,  …)`
2. `ingest_answer(s2, …)` → `ingest_answer(handle2, …)`, where `handle2` is
   session 2's own payload.

The second preserves the attack rather than avoiding it: the question was
always *can a token minted in session 1 be restored in session 2*, and it is
still asked, from session 2's own handle. **No assertion was loosened and no
case was dropped.**

The other five attacks run unmodified.

### The other two files are **mine**, not the red team's

They are new probes, written because the original run left two findings
unproven, and they are here so that nobody later mistakes them for part of
the captured attack:

- **`oneshot.rs`** — F-06 in isolation. In `original/src/main.rs` the double
  send was masked: F-01 refused first, so that run proved nothing about the
  handle. Here the destination is never rebound, so the credential is valid
  and the only thing that can stop the second send is the handle being spent.
  It also gives the **control string** for F-01: without a rebind, exactly one
  request arrives carrying `authorization: Bearer …` and zero real values —
  which is what makes F-01's refusal specific rather than a blanket break.
- **`lockcache.rs`** — F-08 by the sharpest test there is: lock, **delete the
  vault file from disk**, then unlock with the correct passphrase. If it
  opens, a cache survived the lock and «Locked» does not mean what a person
  reads it to mean.

## What is deliberately absent

```text
target/                 1.1 GB of build output
strace captures         they contain request bodies
screenshots and logs    they may carry user data
evidence directories    kept off the machine's repository entirely
```

Only reproducible source is here, plus two synthetic fixtures that contain no
real data of any kind: `malformed.docx` and `docx/word/document.xml`, both
marked `ZXQ-DOCX-PARTIAL-77220`.

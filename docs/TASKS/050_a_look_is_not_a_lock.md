# 050 · A look is not a lock

The owner's first strike from `~/ztest/ATTACK.md` was **two copies of Z on one
vault**. The programmer answered it: `VaultStore` now remembers the exact bytes
it read, and re-reads the file before `create`, `change_passphrase` and
`with_open_mut`, refusing with `StorageRefused` if the file moved underneath.

I measured that answer on **`82d5858`** — the build the owner is attacking, not
the branch it was written on (`fix/two-swedish-signals`, `d6e44dd`, **34 commits
behind**). His patch applies to `82d5858` with offsets and his test passes there.

**And the guard bites.** With the three `ensure_disk_unchanged()?` calls disabled
and the test kept, it fails:

```
panicked at z_core/src/vault/mod.rs:583: a stale open copy must not overwrite the vault: Ok(())
```

`Ok(())` — so before this change the stale copy **erased the other copy's work
and was told it had saved**. The defect was real, the fix is real, and the test
is honest. Keep all three.

What follows is what the change does **not** do. Each item is measured, and each
is a separate press.

---

## A · The refusal names the wrong cause — twice

`ensure_disk_unchanged()` runs **before** the lock check in `with_open_mut`, so a
copy whose vault is **locked** is told the file changed:

```
LEAD-PROBE-A1  locked, disk untouched => Err(VaultLocked)                      ← true
LEAD-PROBE-A2  locked, disk changed    => Err(StorageRefused { reason:
    "vault.zv: the vault file changed on disk while this copy was open;
     lock and unlock before changing it" })                                    ← false
```

A locked vault is told **to lock**. And the second wrong name is the variant
itself. `messages.dart:72` turns `StorageRefused` into:

> *Z Privacy will not use that location — vault.zv: the vault file changed on disk…*

The location is fine. **Another window of Z wrote.** And the comment above that
line states the contract the change breaks: *«the fault is in a location, and the
reason names which one and why»*.

**Do:**
1. In `with_open_mut`, move `ensure_disk_unchanged()?` **after** the
   `(open, master)` binding, so a locked vault says `VaultLocked`.
2. Give the conflict **its own variant** — `ApiError::VaultChangedElsewhere` —
   and its own sentence, which names the cause and the next move:
   *«Another copy of Z Privacy changed this vault. Close that window, or lock and
   unlock here to take in its work.»*
   `StorageRefused` goes back to meaning a place that cannot be used.
3. Guards: a locked copy over a changed file says `VaultLocked`; a conflict says
   `VaultChangedElsewhere`; and the sentence for it contains neither the word
   *location* nor the word *lock* as an instruction to someone already locked.

## B · The window between the look and the write is still open

The look and the write are two steps, and nothing holds the file in between. Two
copies that both pass the look both write, and the second erases the first:

```
LEAD-PROBE-B  clients on disk after both wrote => [99]
```

Client **17** was accepted — `with_open_mut` returned `Ok` — and is gone. This is
the same loss as before the fix, narrowed to the span between the read and the
rename. **A look is not a lock.** It catches two windows minutes apart, which is
the real case; it cannot catch two presses in the same millisecond.

Closing it properly means the file itself says who holds it:
`flock(LOCK_EX | LOCK_NB)` on an open handle to `vault.zv`, taken for the span of
*look → seal → rename*, so the second copy waits or hears the truth. And if the
lock is held by a **whole second instance** rather than one call, then the answer
to the owner's question «أتُقفل؟» becomes yes, deliberately: the second window
opens read-only and says so.

**Do not build either yet.** The choice between *a narrow window* and *a second
window that cannot change anything* is the owner's, not ours. This paper records
the number so the choice is made on a measurement.

## C · A copy that was started first can "create" into memory and stay stuck

`create` sets `master` and `open` **before** `ensure_disk_unchanged()`. A copy
opened while no vault existed still shows the create screen after another copy
has created one; the person types a passphrase, presses create, and is refused —
with memory now holding an open vault that is not on disk, under a passphrase the
file does not know.

**Do:** re-read the file at the top of `create`, and refuse with
`VaultAlreadyExists` — the true cause — before touching `master` or `open`.
Guard: the second copy's `create` leaves `state()` unchanged.

## D · The cost — closed

A client book of 2000 on a 188 KB vault, 50 changes timed:

| | per change |
|---|---|
| with the look | **1078 µs** |
| without it | 1037 µs |

**+41 µs, +4%.** The extra read is one file read against a write of the same
file. No objection on cost; 30 call sites outside `vault/mod.rs` pay it.

---

## What I did not accept on the report

- `cargo fmt --check` was left alone because it objects to old formatting
  elsewhere. That is right, and it is also a **gate that cannot bite**: a gate
  that is red before you start cannot tell you that you turned it red. It is a
  debt, written down, not a thing to fix inside this paper.
- The report's own verification ran on `d6e44dd`. Mine ran on `82d5858`. From
  here, **measure on the tree the owner is attacking** — a green sweep 34 commits
  behind is a green sweep of a build nobody is holding.

# 052 · A seal that misnames its own maker

The owner's third strike, and the first to go all the way out of the machine and
back. He exported the protected payroll PDF from Z, handed it to an outside
model, and asked it to find the accounting problem.

## 1 · The whole chain, verified by my own hand

| | |
|---|---|
| in the source document | 8 person names · 10 national IDs · 9 phones · 10 e-mails |
| protected | **68 places, 46 values**, one namespace `EBE6`, all tails 8 hex |
| **names that leaked** | **0 of 8** (and 0 of the 20 in the list) |
| **national IDs / phones / e-mails that leaked** | **0 / 0 / 0** |
| any ID, e-mail or phone *shape* anywhere in the file | **none** |

Read back through **poppler**, not our own reader, and every search was run
first against the unprotected source as a control — 9 of 9 phones findable
there, so a zero over the protected file means something.

The seal's own arithmetic, checked independently: 68 occurrences ✓, 46 distinct
values ✓, and all eight kinds exact — Account 1 ✓ Contract 1 ✓ E-mail 10 ✓
Person 8 ✓ Personnel number 3 ✓ Phone 9 ✓ Something else 5 ✓ Tax ID 9 ✓.
**A reader with any PDF tool can check those numbers.**

And the answer came back right. Against the source:

```
line 19  25 February 2027  Nadia Berglind  …  26 500            ← salary
line 21  12 February 2027  Nadia Berglind  …   2 400  ADVANCE   ← paid out
line 33  25 February 2027  Nadia Berglind  account 7210  26 500 ← ledger: no 2 400
         Total per bank statement: 248 600 · Total per ledger: 246 200
```

The model found the 2 400 advance that never reached the ledger, named the right
person, the right date and the right amount — **and Z restored the right name.**

It could only link the two rows because the token is the same in both:

```
25 February 2027  __Z_EBE6_PERSON_42220260__ …  26 500
12 February 2027  __Z_EBE6_PERSON_42220260__ …   2 400  ADVANCE
```

**Identity without identity.** This is what 046/U item 2 is for, and the first
proof that the property earns its cost.

## 2 · The defect: the stamp in every document names the wrong build

The footer reads `z_core 0.1.0 · 2026-10-07 · f362761`. The bundle it came from
is **byte-identical** to the `82d5858` release — `libz_bridge.so` and
`libapp.so` both, sha256 equal. So the code is `82d5858`, seven commits later,
and the seal names `f362761`.

**Root cause.** `z_core/build.rs` emits `cargo:rerun-if-changed` only for paths
it can see:

```rust
for path in ["../.git/HEAD", "../.git/refs/heads", "../.git/index"] {
    if Path::new(path).exists() { … }
}
```

In a **git worktree** `.git` is not a directory but a file —
`gitdir: /home/monopeaks/mono-privacy/.git/worktrees/mono-privacy-measure`. None
of the three paths exists, so **no `rerun-if-changed` is emitted at all**, cargo
never re-runs the build script, and the stamp freezes at whatever HEAD was the
first time the crate compiled in that worktree.

Every build any of us makes is made in a worktree. **The guard fails in the only
configuration we use**, and it fails silently, and it was written to stop exactly
this — its own doc comment says the owner once looked at a page and thought
yesterday's build was still live.

It is mine: the worktree discipline is my rule.

**Do:**
1. Ask git for the path instead of guessing it:
   `git rev-parse --git-path HEAD` and `--git-path index` resolve correctly in a
   worktree, in a submodule and in a plain checkout.
2. If either path cannot be resolved, stamp `unknown` rather than a commit.
   **A stamp that admits it does not know is worth more than one that names the
   wrong commit** — the file already says so about being outside a checkout; the
   same honesty is owed here.
3. Guard, and it must bite: a test that resolves the stamp's commit and compares
   it with `git rev-parse --short=7 HEAD`, skipping only outside a checkout.
   Run in this worktree against today's code it must fail.

## 3 · The second defect: the footer cuts a row in half for a machine

The footer is drawn at the foot of each page, but in **reading order** — which is
what a model gets — it lands inside the table:

```
25 February 2027  __Z_EBE6_PERSON_722375C3__      account
z_core 0.1.0 · 2026-10-07 · f362761 · 68 places replaced, 46 values (…)
  · sha256 of the protected text c4765a50…07cc
__Z_EBE6_ACCOUNT_80DC1404__    34 800
```

A person and their amount with 150 characters of hash between them. It did not
matter here, because the answer lived on the bank side. It will matter on a
document whose answer straddles a page break, and the failure will look like the
model being wrong.

**Do:** keep the seal, move it off the reading path — last page only, or a
`/Metadata` stream plus one short line per page. **Decide what a machine reads,
not only what a person sees**, because for this product a machine is the reader.
Same family as 046/M: *a number ends where the column ends.*

## 4 · And the two debts already recorded

`Rechnung Nr. 2026-04471` in the clear while the customer number was protected
(051 §4), and the postcode surviving the street. Unchanged by today.

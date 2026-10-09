# 074 · The same product on a second platform: Windows, re-measured after a month

**The owner, 9 Oct 2026, evening:** Qatar is no longer the compass — the
programme turned out paid, which makes us the customer, not the chosen
(*«نحن الزبون... ونحن ندفع للرغبة»*). Carlos's reply is awaited seated, not
standing. The ruling that replaces it: **«يمكننا إنهاء z ووضعها على الويب
ونتابع ما نعمل عليه على المنصة. ما تبقى في z ربما أسبوع أو عشرة أيام فلماذا
التأخير»** — Z closes in a measured week-to-ten-days, goes on the web, and the
seat returns to the platform. One real person is waiting on this paper
specifically: the owner's German friend needs the Windows copy.

## What already exists — do not rebuild it

`platform/windows` (`d52df12..f03e503`, eight commits) is **fully merged into
main**: its tip is the merge-base. It left behind:

- `.github/workflows/windows-core.yml` — two jobs on `windows-latest`
  (`core`: z_core compiles, tests hold, storage protection measured; `app`: the
  whole desktop app, runner and bridge and all). **Manual dispatch only**
  since 5 Oct — it runs when a person presses «Run workflow», never on push.
- An Inno installer that produced a real `setup.exe` (one file, no
  administrator password — `12794aa`). That artifact shipped on the beta page
  and was quarantined today with the old site; the *machinery* is in the tree.
- The two platform fixes of that round: the core says where the vault lives
  instead of the screen guessing (`d52df12`), and the Unix-only guard in
  `secure_file.rs` was named and measured rather than hidden.

## The actual task: measure the drift

Since `f03e503` the tree gained a month of code that has **never run off
Linux**: sessions that carry their own key (064 a–f), the send-door writing
turns at `ingest_answer`, conversation file format 2, the exits round, the
settings panel, the EN pack, the encoding fix. Any of these may have brought a
Linux assumption with it.

1. **Desk audit first, on Linux, today.** Walk the diff `f03e503..HEAD` for
   platform assumptions: hard-coded `~/.local/share` or `/tmp` or `/` path
   joins, new `#[cfg(unix)]`/`Platform.isLinux` sites, file-locking or
   permissions calls, process spawning, anything in vault/sessions/send-door
   that touches the filesystem. The deliverable is a **list, each entry
   `file:line` + what Windows will say about it + the proposed answer** —
   before a single fix. A search is only as wide as its claim: state the
   claim of each grep beside its hits.
2. **Fix on a branch `platform/windows-round2`**, smallest honest commits,
   gates green on Linux after every one — the Linux product must not move an
   inch for Windows' sake.
3. **The real measurement is the CI run**, and it is gated on the owner's
   hands twice: his push (`git push origin --all`, queued for his return
   home) and his press on «Run workflow». Until then every claim stays
   worded as *expected*, not *measured*. When the run exists, read it like a
   tree of our own: a red job is the report we asked for.

## The shape of done

The workflow's two jobs green **on the new tip**, an installer artifact a
person can download, and the German friend's hand-test as the field
measurement — his machine is the first Windows machine this product meets.
Nothing on the live site changes in this paper; packages return to the web
only in the closing round, by the owner's word.

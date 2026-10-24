# 109 — The author of 21:35:11: one sentence in CLAIMS.md that the owner has answered

**Source:** the owner, 24 October 2026, via the Windows session: «أنا حفظت جميع الملفات عن طريق حفظ نسخة PDF». Builder: **ed**. Branch off `c0326af` as its own branch. **Not** off the parked 107 work. Two files only: `docs/CLAIMS.md` and the doc block above `write_body` in `z_core/src/ops/conversation.rs`.

## The false sentence

C-07's limit line says that on 22 October 2026 `sessions/1.zs` went from a document and eleven decisions at 21:35:03 to an empty body at 21:35:11. It calls that «a write lost, by an author this tree cannot name». The author is named now. A protected z-pdf (16 751 B) was written into `Documents\ZPrivacy` at exactly 21:35:11, and the owner confirms that saving a protected PDF was his only save. That emptying was **089 rule 9** («it has left»), the law doing what it says. It was not a lost write.

## What moves

- **C-07's limit line** names the author openly, with the date and the source. Name the Windows session's entry of 24 Oct by its **commit** (`e36c92c`), not by a path. `check_claims.py` reds on a claim that names a file absent from the tree, and that entry may not be in yours.
- **Paper 102 still answers a real class** (a run writing bytes it did not read), and its guard stays. Say exactly what it reaches, in ed's own measurement: every writer of a session body reads the file first inside the same lock, so the guard catches a read that went stale *between* a read and a write. A save cannot redden it. The single-writer census ed wrote into G36 (`crate::conversation::write(` lives in `write_body` alone in `z_core/src`) is what stands guard on the shape. Bring that census along in this paper if it can travel without 107's doors. If it cannot, name it as owed.
- **`write_body`'s doc block** cites the same second as a two-window loss, so it moves to the same truth.
- The 21:35 measurement itself stays in the record. Only its reading changes, and the change is said, not hidden: «read on 22 Oct as …; the owner named the author on 24 Oct».

## Measurement

`bash scripts/gates.sh` green. G56 still reads 17 claims, and the rust/dart counts are reported (they should not move unless the census travels). The lead merges and writes `MEASURED_ON_LINUX.txt`.

# 112 — A gate that reds at random teaches the reader to ignore reds

**Source:** e2's measurement during 108 (24 October 2026). Builder: **e2**, on the 108 branch, before it is handed to ed for the assembled run. One file: `scripts/gates.sh`.

## What was measured

G63 reddened once on a tree it does not read: «The Windows job no longer names: RUNNER_TEMP». It passed on 105, on 107's run twenty minutes earlier, and on a second run of the same committed tree. e2 put an instrument in front of the run and ran the gate's four greps twenty times each in the run's own shell. The first missed 1 in 20, the other three 0. In a quiet shell, 400 attempts missed 0.

The shape is `printf '%s\n' "$BIG" | grep -q PAT` under `set -o pipefail`. `grep -q` exits at its first match, the writer can take SIGPIPE, and the pipeline's status becomes the writer's 141, not grep's 0. A pattern that matches early in a large variable loses the race most often, which is why G63's first question is the one that reds.

## The ruling

**Replace the shape, not four lines.** e2 counted 44 lines of `gates.sh` that pipe a writer into `grep -q`. Each one becomes a form with no writer to kill: a herestring (`grep -q PAT <<<"$BIG"`), a `case`, or `grep -q PAT file` where a file already exists. Choose per line and say which in the report. Meaning must not move. A gate that was asking «is X present» still asks exactly that.

## Pins

- **Census:** a check (inside gates.sh or beside it, your call) that reds when a writer-into-`grep -q` pipe appears again, ignoring comment lines («a gate that quotes what it forbids fails on its own comment»). Prove that it bites by planting one.
- The flake instrument from 108, run again after the change: the same 20 × 4 loop in the run's own shell, 0 misses. Report the number.
- Every gate's verdict on the tree is unchanged: the same check count, and the same names green and red, before and after.

## Measurement

The full `bash scripts/gates.sh` run happens once, on ed's assembled branch (108 + 109 + 110 + 111). Your own branch needs the census pin and the instrument numbers only. The lead merges the assembled branch.

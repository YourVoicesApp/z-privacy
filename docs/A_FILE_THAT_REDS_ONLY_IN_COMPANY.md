# A teardown that can fail on its own — 133 lines in 57 test files

**Status: CAUSE MEASURED 19 Oct 2026 · one file fixed, 56 owed** · the fix in
the one file and the shared helper are on `fix/the-sentences-in-one-list-3`.

## What was seen, three times, by two hands

| run | the guard that reddened | alone, afterwards |
|---|---|---|
| mine, sitting one of 092 | «the explain card carries the column act, so no press is wasted» | green |
| the lead's, over `7caac20` | «a wrapped row still presses the cell a person pointed at» | green three times |
| mine, sitting three's gate | «a drag down the gutter takes a range, and the head control takes every line» | green |

Three different guards, three runs, **one file**, each green on its own.

## The cause, out of the gate's own report and not out of a hypothesis

`scripts/gates.sh` runs the suite with `--file-reporter="json:$DART_JSON"`, and
that file survives the run in `/tmp`. Reading it rather than guessing gave the
answer in one line — the reddening test was reported as an **error**, not a
failure, and the error is:

```text
FileSystemException: Deletion failed, path = '/tmp/zprivacy-gutter-range-1982015'
  (OS Error: Directory not empty, errno = 39)
  dart:io                                             FileSystemEntity.deleteSync
  test/a_line_is_taken_in_the_gutter_test.dart 94:35  _open.<fn>.<fn>
```

Line 94 is the test's own teardown:

```dart
addTearDown(() {
  if (here.existsSync()) here.deleteSync(recursive: true);
});
```

`deleteSync(recursive: true)` reads the folder, unlinks what it found, then
removes the folder — and the core is a live Rust library in the same process. A
file that appears between the reading and the removal (a session file being
sealed, `writing.lock`, the `zv.new` of an atomic replace) makes the last step
fail with `ENOTEMPTY`, and **the teardown throws**. The test is then reported as
an error with its own claim already proved.

That explains every observation at once: green alone, red in company, and a
*different* guard each time — the loser is whichever teardown the core happened
to be writing under.

**Two things it is not**, and both were believed for a while:

* **Not a timing budget.** The hypothesis in this file's first version was that
  `settle(tester, rounds: N)` waits a count of pumps for a number the machine
  owes. It reads well and it is wrong: the reddening test ran its full 3.8 s,
  reached its assertions, and threw afterwards. Killed by the report, which is
  the lesson — the gate writes a machine-readable record and reading it costs
  nothing.
* **Not «the teardown race» as it was already known.** The house knew
  «Directory not empty» from the *library build* («the debug bridge has no test
  features»), and it was ruled out here because that one looks different. The
  same errno from a different cause: the folder, not the bundle.

## The fix, and what is owed

`test/the_folder_lets_go.dart` — `removeWhenItLetsGo(Directory)`: try again
until the folder is gone or a short deadline passes, and **never throw**. A
teardown that can fail on its own is an instrument that can red a claim it is
not about. Its own guard is `test/the_folder_lets_go_test.dart`, which measures
what it can honestly measure and says what it cannot.

`a_line_is_taken_in_the_gutter_test.dart` uses it now, because that is where the
race bit three times.

**56 other files still delete their folder by hand — 133 lines, counted on this
tree:**

```bash
grep -rln 'deleteSync(recursive: true)' apps/flutter_app/test | wc -l   # 57
grep -rn  'deleteSync(recursive: true)' apps/flutter_app/test | wc -l   # 133
```

Every one of them is the same race and can red any guard in its file. The sweep
is one line per site and is **owed**, not done: it touches 57 files and belongs
in a commit of its own rather than inside a round about sentences. Until it is
done, a red in a full run whose message is `errno = 39` is this, and not the
guard it is reported against.

## And a second cause in the same file, still open

**Measured 20 October 2026 by the lead**, in a full gates run over a merge that
touched **no Dart at all** (094, docs and scripts only) — so it is not anything
a round changed:

```text
a_line_is_taken_in_the_gutter_test.dart
  «the explain card carries the column act, so no press is wasted»
  line 374  the WhySheet was found
  line 378  0 ZButton with text «Protect this column in the 4 held lines»
```

The file alone, run the gates' own way
(`LD_LIBRARY_PATH=…/bundle/lib flutter test --concurrency=1`), is green 10 of
10. The teardown race is **not** this one: that one throws `errno = 39` out of
a `tearDown`, and this is a finder returning nothing inside the test's own
body.

Two possibilities, and which one it is has to be pinned before anything is
changed:

1. the card's act button was not built yet when the finder ran — `settle(…,
   rounds: 16)` is a count of pumps, not a wait for a thing to exist;
2. the drag held fewer than four lines, so the button that *was* built carried
   another number in its label and the finder was looking for the wrong
   sentence.

**How to tell them apart, on the red:** print every `ZButton` label present at
that moment. One of them reading «…in the 3 held lines» says (2); none of them
being an act of the card says (1).

**Then the fix, whichever it is**: the guard waits for the button **by a key**
rather than by counting rounds, and reads the number off the bench rather than
out of a sentence. A guard that waits a fixed number of pumps for a widget
another process's load decides the timing of is the same instrument fault as
the teardown above — and since 092 the label is drawn from the one list, so a
guard that reaches for its English text would also break the day it is read in
German.

### Closed, 20 October 2026 — and which of the two it was could not be summoned

**The red was not reproduced.** The old guard, with its fixed budgets, was run
against twelve busy processes on this machine and stayed green; the file is
green ten of ten alone, and it was green inside the full run at `88d1afb`. A
flake that cannot be summoned cannot be pinned by reproduction, so the two
explanations were separated by **measurement instead**:

  * **(2) is ruled out for the healthy path.** On the deliberate red, every
    `ZButton` label on the glass was printed — the lead's own instruction — and
    the list holds «Protect this column in the 4 held lines», with the four.
    The hold is the number the card is given, `linesHold.lines`, and the guard
    now **asserts it is 4** before it looks for anything: a drag that held
    three used to fail as «0 ZButton found», which is a message about the wrong
    thing.
  * **(1) stands as the explanation** — the card arrives and the act inside it
    a moment later, which is exactly the shape of the red the lead saw (line
    374 found the `WhySheet`, line 378 found no act). It is now impossible for
    it to make a red: nothing in this guard counts pumps.

**What changed.** `columnActKey` in `why_sheet.dart` — one name with two
readers — and `settleUntil(tester, () => …)` beside `settle`: five fixed
budgets in this guard became five waits for the thing itself. The act's words
are compared against `columnActLabel(bench.linesHold!.lines)`, so neither the
sentence nor the number is typed in the test, and `actsOnTheGlass(tester)`
enumerates every act in the failure reason — kept for good, not used once,
because the next red will arrive when nobody is watching.

Measured: the file green 10/10 three times over, green under six busy
processes, and green with the fixed budget before the card **reduced to zero**,
which is the direct proof that the waits do the work the budget was guessing
at. The file also runs about a fifth faster, because a wait returns when its
condition holds instead of always spending its rounds.

### The debt this uncovered: 284 finders type a sentence the one list owns

Measured over `apps/flutter_app/test` on 20 October 2026: **458** finders reach
for a typed sentence, and **284** of them name a value that now lives in
`lib/l10n/app_en.arb` — by its exact text, or by the shape of a placeholder
sentence like «Page 2» for `pageNumber`.

While the suite reads English they are correct. They are a debt anyway, and the
same debt as this file's: each is a second copy of a sentence whose home is the
list, so a reworded value turns a guard red for the wrong reason — or, where
the assertion is `findsNothing`, leaves it **green** for the wrong reason, which
is worse. The form that does not rot is `find.text(sentences.theKey)`, reading
the one place. A sitting of 092's own, with a number to measure it against.

Queued after sitting four of 092 and after 097, by the lead's own order.

Related: `the_debug_bridge_has_no_test_features.md` (the same errno, the other
cause) · `a_guard_green_for_the_wrong_reason.md` ·
`flutter_an_instrument_that_speaks_once.md`.

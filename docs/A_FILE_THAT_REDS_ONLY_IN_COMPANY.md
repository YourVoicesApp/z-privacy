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

Related: `the_debug_bridge_has_no_test_features.md` (the same errno, the other
cause) · `a_guard_green_for_the_wrong_reason.md` ·
`flutter_an_instrument_that_speaks_once.md`.

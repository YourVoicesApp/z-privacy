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
that file survives the run — since sitting five's item 4 at one fixed place per
worktree, `/tmp/zprivacy-gates/<worktree>/dart-events.json`, named in the gate's
own PASS line, and kept on green as well as on red. Reading it rather than guessing gave the
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

### Closed, 20 October 2026 — the gates summoned the red, in the test beside it

**The red was reproduced — by the gates, in a sibling test.** It could not be
summoned by hand: the old guard stayed green against twelve busy processes on
this machine, green ten of ten alone, and green inside the full run at
`88d1afb`. But the full run over the fixed guard, at `772fad4`, reddened
**«a wrapped row still presses the cell a person pointed at»** in the same
file, on `expect(bench.linesHold!.lines, 3)` after `settle(tester, rounds: 12)`
— a different test, the same fault, and this time the suite produced it by
itself while the converted guard beside it passed in that same run. That is as
close to a pinned cause as this class allows: a fixed number of pumps waiting
for the core's answer, on a machine the rest of the suite is loading.

The two explanations for the original red were separated by **measurement**:

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

Measured: the file green 10/10 three times over, green under six and then
twelve busy processes, and green with the fixed budget before the card
**reduced to zero**, which is the direct proof that the waits do the work the
budget was guessing at. The file also runs about a fifth faster, because a wait
returns when its condition holds instead of always spending its rounds.

### Why the other budgets in that file were left alone

All sixteen were converted first, and **three tests went red** — so the sweep
was reverted and only the two measured sites keep a wait. What the three reds
taught is worth more than the sweep:

  * **A wait must be for the last thing the assertions need, not the first.**
    `bench.lines` is the screen's own range and arrives first; `linesHold` is
    the core's answer about those lines and arrives after it. A wait for the
    range let the next line read a `linesHold` that was still null — an
    ordering the twelve-round budget had been hiding rather than passing.
  * **A wait that returns early removes slack a later step was living on.**
    Three assertions downstream had been riding on the rounds an earlier
    budget spent after its own condition was already true. A budget is
    therefore not only a guess: where it sits in front of a claim that
    *nothing* happens, it is the only instrument that can give the absence time
    to fail, and the honest form is to wait for the observable thing the act
    does produce — a refusal sentence, a card opening — and assert the absence
    under that.

So this file now has waits where an arrival was measured to be late, and
budgets where the claim is an absence, each with the argument written at it.

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

**Closed, 21 October 2026** — sitting five's item two. 347 finders were
converted to `find.text(sentences.theKey)` and the gate that keeps them that
way is `G65` in `scripts/check_no_typed_sentence.py`: no floor, and the
survivors allowed by name with a reason at each. **Nineteen of the automatic
pass's 323 rewrites were wrong**, and the reason is worth more than the count —
a string that *equals* a value in the list is not necessarily *drawn from* it.
«English» is the core's language table, a form's greyed example is not a value
the person was taught, and four of the nineteen sat under `findsNothing`, where
being wrong is silent. What the item costs is written in the checker: a finder
reading a key cannot notice a **reworded** value, so the sentences a claim in
`docs/CLAIMS.md` leans on are pinned by their English in `G66`.

## A guard that crosses the seam — 096, 20 October 2026

Not a flake, and in this file because it is the same shape of mistake: **a
measurement that cannot see the thing it is about.**

096 was built in two halves. ed's core half let a hand selection land in the
request, with its own Rust guards; this half drew the request in the first part
so a hand could reach it. Both were green. The product was broken: a selection
on a word in the request came back as a span pointing **into the document**, so
the next press protected a word nobody had pointed at — in a tool whose whole
promise is about which words leave.

Measured on `e610c63`:

```text
requestBegins 69 · the entered text at 92 is «earn»
bench.select(Span(92, 96))  →  bench.selection 22..28  =  «Thomas», in the document
protectSelection(…)         →  alreadyProtected(__Z_…_PERSON_…, de:salutation)
```

The cause was reported from the glass as one line — `ops/mod.rs:1747` builds
`word_span` from `s.original_str()` out of offsets that are the request's own.
It was **five**: `inspect_selection` needs that shift in five places, and four
of them had written the document's name, while the fifth — the snapshot's — had
the arithmetic right **in its own spelling**. One law in two spellings is how
the other four came to be wrong, which is a finding the glass could not have
made: from here one wrong answer is one wrong answer, and only the file's owner
can count how many places it is written in.

**Why two green halves could not see it.** The core's guards call `protect`
directly with an entered-space span. The glass never does: `select()` replaces
what the person drew with `view.wordSpan` from `inspect_selection` (041-K,
«what the core will take is what the screen shows»). So the door the glass
always passes through was the one door no guard asked about, and each half
measured its own side of the seam.

The guard that found it — «a hand selection in the request covers that word,
and not 22..28 in the document», in
`apps/flutter_app/test/the_question_is_on_the_screen_test.dart` — was **red on
purpose** for a day by the lead's ruling, and that is the point of it: it
crosses the seam, driving the glass's own path and asking the core's own answer
back, which is the only kind of guard that can fail when two halves are each
correct alone.

### Closed, 21 October 2026 — green with nothing changed on this side

ed's fix merged at `072ab1f`, and the shift now has a name asked for by name:
`span_in_the_entered(entered, begins, from, to)`. The guard **went green with
no touch from this half** — which is the whole claim such a guard is for. Had
it needed a touch here to pass, the touch would have been the news, not the
pass: a guard that is edited to agree with the code it measures has stopped
measuring it.

What stays written down is the shape, not the bug: the door the glass always
passes through — `select()` → `inspect_selection` → `view.wordSpan` — was the
one door neither half's guards asked about, because ed's called `protect`
directly with a span already in the entered space. Each half tested the inside
of its own side of the seam.

Related: `a_split_item_needs_a_guard_that_crosses_the_seam.md` ·
`a_control_that_fails_to_bite_is_a_finding.md`

## A source that changed is measured by the one command — 096, 21 October 2026

Sitting five, item 3. In this file because it is the same fault once more: **a
measurement that cannot see the thing it is about.**

096's glass half moved the first part from `doc.marks` to `entered.marks` — not
the widget, not its callers, the **source** of what it draws. I measured the
six files I had touched (45 green, 1 red by the lead's own ruling) and reported
that. The full gates then reddened **five guards in three files I had never
opened**:

```text
the_bubble_comes_out_test.dart    a press on a waiting word opens the bubble …
marks_test.dart                   a suggestion stays wavy, whoever found it
the_choice_at_the_word_test.dart  … offers the two answers · pressing an answer
                                  applies it · Escape closes it
```

The cause was one kind of value, not one line. `EnteredText.marks` was built
from `protections` and `question_protections`, every one of them
`MarkState::Protected`; `document_view` builds its marks from `findings`, where
a `MarkState::Suggested` one lives. So the first part silently lost **every open
suggestion**: no word left waiting to be pressed, no line under anything the
scan had offered — the product's discovery door, in a round whose subject was
the request.

**Why a narrower run could not see it.** A widget's own tests pass whenever its
props are well-formed, and they were. What breaks is every *other* guard that
relied on a **kind** the new source cannot carry, and those live in files whose
names have nothing to do with the change. A subset run can see a missing value;
only the whole suite can see a missing kind.

**What the next change of a source does instead**, in order:

1. diff the two producers for the **set of states or kinds** each can emit —
   `grep` both for the enum — and say in the commit which kinds the new one
   cannot express;
2. run the one command, `bash scripts/gates.sh`, and nothing narrower;
3. settle ownership by **A/B at the base commit** rather than by reading the
   diff: `git checkout <base>` with the same `.so`, run the reddened files.
   Here that was 11/11 green at `072ab1f` and red on my head, which named the
   owner in one measurement and ended the question of whether ed's five edits
   to `inspect_selection` were in it.

The fix was one loop in the core's own file, so it went to the half that owned
it: `EnteredText.marks` now carries the document's open suggestions too, at
their own offsets, never over a protection. The five went green **with nothing
touched on this side**, measured at `af64baa` — `git diff` over those three
files and over all of `z_core` was empty — which is the same claim, and the same
discipline, as the seam guard above.

Related: `a_variant_answers_for_every_reader.md` (a new case breaks another
round's reader) · `a_split_item_needs_a_guard_that_crosses_the_seam.md`

Related: `the_debug_bridge_has_no_test_features.md` (the same errno, the other
cause) · `a_guard_green_for_the_wrong_reason.md` ·
`flutter_an_instrument_that_speaks_once.md`.

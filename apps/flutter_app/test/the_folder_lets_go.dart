// **A test's own folder, removed when the core lets go of it** — 19 October
// 2026, measured from a gate run's own report.
//
// A test that gives the core a folder of its own deletes it afterwards:
//
// ```dart
// addTearDown(() {
//   if (here.existsSync()) here.deleteSync(recursive: true);
// });
// ```
//
// and that line threw in a full gate run:
//
// ```text
// FileSystemException: Deletion failed, path = '/tmp/zprivacy-gutter-range-1982015'
//   (OS Error: Directory not empty, errno = 39)
//   dart:io  FileSystemEntity.deleteSync
//   test/a_line_is_taken_in_the_gutter_test.dart 94:35  _open.<fn>.<fn>
// ```
//
// `deleteSync(recursive: true)` reads the folder, unlinks what it found, then
// removes the folder — and the core is a live Rust library in this same
// process. A file that appears between the reading and the removal (a session
// file being sealed, `writing.lock`, the `zv.new` of an atomic replace) makes
// the last step fail with `ENOTEMPTY`, and the **teardown** throws. The test is
// then reported as an error although its own claim passed, which is why three
// different guards in one file reddened on three different runs while each
// passed alone: the loser is whichever teardown the core happened to be writing
// under.
//
// So the folder is removed **when it lets go**: tried again until it is gone or
// a short deadline passes, and never thrown out of. A teardown that fails is a
// red with nothing to do with the test's claim, and a guard whose instrument
// can fail on its own is not measuring what it says.
//
// **It is not «the directory is in use» being ignored.** If the folder is still
// there at the deadline the tests go on and the folder is left in `/tmp`, where
// the next run's own `existsSync` check deletes it; nothing is hidden and
// nothing is asserted about a thing this house does not control.
//
// **56 other test files still delete their folder by hand** — 133 lines of it,
// counted on this tree. They are the same race and the sweep is one line per
// file; it is a debt rather than this round's work, written down in
// `docs/A_FILE_THAT_REDS_ONLY_IN_COMPANY.md`.
import 'dart:io';

/// Remove [here] when the core lets go of it, and never throw.
///
/// Called from a `tearDown`, where throwing is what has to be avoided. The
/// deadline is a second and a half in twenty attempts: the race is a single
/// file write finishing, not a long piece of work, and a teardown is not a
/// place to wait on anything slow.
void removeWhenItLetsGo(Directory here) {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (!here.existsSync()) return;
    try {
      here.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      // The core wrote into it while the walk was in flight. Give it the
      // moment it needs — `sleep` and not an `await`, because a `tearDown`
      // under `testWidgets` runs in the fake-async zone where a real
      // `Future.delayed` never completes.
      sleep(const Duration(milliseconds: 75));
    }
  }
}

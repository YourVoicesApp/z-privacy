// The guard for the one teardown every test folder goes through.
//
// **What is measured here, and what is not.** The race itself — the core
// writing a file between the walk and the removal — is proved by a gate run's
// own report and not by this file:
//
// ```text
// FileSystemException: Deletion failed, path = '/tmp/zprivacy-gutter-range-1982015'
//   (OS Error: Directory not empty, errno = 39)
//   test/a_line_is_taken_in_the_gutter_test.dart 94:35  _open.<fn>.<fn>
// ```
//
// Forcing that in a single-threaded test would mean writing into the folder
// from inside `deleteSync`, which is not a thing this suite can arrange — so it
// is not faked. What is measured is the two properties the teardown needs in
// order not to be able to fail on its own: it removes a folder that has
// something in it, and it throws for nothing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'the_folder_lets_go.dart';

void main() {
  test('the folder goes, and a teardown that cannot remove one still does not throw', () {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-letsgo-$pid');
    addTearDown(() => removeWhenItLetsGo(here));
    if (here.existsSync()) here.deleteSync(recursive: true);

    // A folder with a file in it, and a folder inside that: the recursive walk
    // is the part that races, so what it walks is more than one level.
    Directory('${here.path}/sessions').createSync(recursive: true);
    File('${here.path}/vault.zv').writeAsStringSync('not a vault');
    File('${here.path}/sessions/1.zs').writeAsStringSync('not a session');

    removeWhenItLetsGo(here);
    expect(here.existsSync(), isFalse, reason: 'the folder was not removed');

    // **And nothing is thrown for a folder that is not there** — which is the
    // state every second call meets, because a tearDown can be reached twice
    // when a test fails inside another one.
    removeWhenItLetsGo(here);
    removeWhenItLetsGo(Directory('${here.path}/never-existed'));
  });
}

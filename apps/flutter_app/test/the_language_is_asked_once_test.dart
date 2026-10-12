// 075d — the language question is asked once in a conversation's life.
//
// **The owner, 10 Oct 2026:** *«الإنسان لا يحب التكرار»*. Until today every
// file opened asked «which language is this document?», and the answer died
// with the bench it was given to, so the next file asked again.
//
// **The measurement that shaped it.** `openSession`'s own documentation says
// «this is a document's bench, not one of the owner's sessions», and
// `shell.dart` makes a new bench for every file. A language kept on the bench
// is therefore a language that cannot survive the next document, let alone a
// restart. It belongs to the **conversation**, and 075c put it there:
// `ConversationRow.packId`, `String?`, where `null` means «not asked yet» and
// stays distinguishable for ever.
//
// Two halves, and this file guards both:
//
//   * **the rule** — `languageForNextDocument` answers which language reads the
//     next document and whether anybody is asked. Three states, because `null`
//     is a state: inherited in silence, asked once, or asked because there is
//     no conversation to inherit from;
//   * **the writing** — the first document of a conversation that has no
//     language writes it, through the core's own door, and the row carries it
//     afterwards. `Workbench.switchPack` cannot be that door: it returns early
//     when the pack has not changed, which it has not.
//
// The seam this file does **not** cover is the two lines of wiring inside
// `_open()` between the picker and the import, because the file picker is a
// platform channel and nothing in this suite drives it today. Said plainly
// rather than left for someone to assume.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

ConversationRow _row(String? packId) => ConversationRow(
  number: 1,
  name: 'Nordstern',
  beganAt: BigInt.from(1760000000),
  turns: 0,
  renamedTokens: 0,
  packId: packId,
);

Ground _groundWith(ConversationRow? open) {
  final g = Ground();
  if (open != null) {
    g.sessions = [open];
    g.openSession = open.number;
  }
  return g;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(
        'no $_libPath — run `flutter build linux --debug` first',
      );
    }
    await RustLib.init();
  });

  group('the rule', () {
    test('a conversation with a language is inherited, and nobody is asked', () {
      final next = languageForNextDocument(_groundWith(_row('sv')));
      expect(
        next.ask,
        isFalse,
        reason:
            'the question came back on a conversation that has already answered it',
      );
      expect(
        next.packId,
        'sv',
        reason:
            'the document is read with ${next.packId}, not the language this conversation was born into',
      );
    });

    test('a conversation that has never been asked is asked', () {
      // The control for the test above: «ask: false» is also what a rule that
      // never asks anybody would say, on every input, for ever.
      final next = languageForNextDocument(_groundWith(_row(null)));
      expect(
        next.ask,
        isTrue,
        reason: 'a conversation with no language was given one nobody chose',
      );
    });

    test('and so is a document opened with no conversation at all', () {
      expect(
        languageForNextDocument(_groundWith(null)).ask,
        isTrue,
        reason:
            'with nothing to inherit from, the app default was passed off as an answer',
      );
    });
  });

  test('the first document writes the conversation its language', () async {
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-075d-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    await z.vaultLock();
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');

    // Born with no document open, which is a real state: the owner may begin a
    // session before he has anything to work on.
    final born = await z.conversationBegin(name: 'Nordstern', bench: null);
    expect(
      born.packId,
      isNull,
      reason:
          'the session was born already knowing a language, so this test '
          'cannot show that the first document is what teaches it one',
    );

    // What `_open()` does when the rule says «ask»: the bench is opened with
    // the answer, and the same answer is written to the conversation through
    // the core's own door.
    final session = await z.openSession(packId: 'sv');
    await z.switchPack(session: session, packId: 'sv');

    final after = (await z.conversations()).firstWhere(
      (r) => r.number == born.number,
    );
    expect(
      after.packId,
      'sv',
      reason:
          'the first document did not teach the conversation its language, '
          'so the question comes back on the next file',
    );

    // And the rule now says so, which is the two halves meeting.
    final g = _groundWith(after);
    expect(languageForNextDocument(g).ask, isFalse);
    expect(languageForNextDocument(g).packId, 'sv');
  });
}

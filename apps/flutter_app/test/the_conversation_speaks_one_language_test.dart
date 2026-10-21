// 080 — the conversation speaks one language, and nobody is asked.
//
// **The owner's field run, 13 Oct 2026:** a German PDF dragged in gave 7
// findings; the same text copied and pasted into the chat gave 0. The two doors
// read the same words with two different languages — the file door asked the
// session, the chat door read the application's pack and never looked at a
// session at all. «ما ينطبق على الوثائق ينطبق على الشات».
//
// **His rule, sealed the same day:** a text — typed, pasted or read from a file
// — is scanned with **its session's language**; a session that has none takes
// **the application's**; there is no third source. And two ways only to a
// session's own language: chosen when the session is created, or the app's.
//
// **Rule 57-د, 17 October, narrows the fallback.** A session that exists and
// never chose a language is **asked** — once, before the first text is read in
// it — and the answer is written into that session. The application's language
// is the fallback only where there is nobody to ask and nowhere to keep an
// answer: no session, and none that could be born. So `packForTheNextText`
// answers `null` for «nobody has said», and the three guards below are read
// against that: the owner's own case was an old session reading his German
// with an English eye while nobody asked him anything.
//
// So 075d's «the question is asked once in a conversation's life» is gone with
// the question itself. A question at the file door was the third source, and a
// third source is how two doors come to disagree. What this file guards now:
//
//   * **the rule** — `packForTheNextText` answers which language reads the next
//     text, whatever door it came through, and asks nobody anything;
//   * **the fallback** — a text with no session and no session to come follows
//     the application's, a session that has a language of its own does not, and
//     a session that never chose answers «ask me» (rule 57-د);
//   * **the write** — `conversationSetPack` puts a language on a session by its
//     number, with no document open, which is the only way the first of the
//     owner's two ways can hold when a session is created from the room.
//
// Two things this file does **not** cover, said plainly rather than left to be
// assumed: that each door really calls the one function, and that the
// application's pack is read in one place, are both grep-shaped facts about the
// source and live in `gates.sh` as G27 — a Dart test cannot see a second reader
// it does not import. And the file picker is a platform channel nothing in this
// suite drives.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

ConversationRow _row(String? packId) => ConversationRow(
  number: 1,
  name: 'Nordstern',
  beganAt: BigInt.from(1760000000),
  turns: 0,
  renamedTokens: 0,
  packId: packId,
);

/// The application's own language, written where it really lives — the config
/// — and read back the way every screen reads it.
///
/// Through the core and not into a field: `Ground.config` is a getter over the
/// home snapshot, and a test that set a field would be measuring its own
/// fixture. One of the two values 080 fused: the pack and the interface
/// language are one choice, so they are written together here as the settings
/// card writes them.
Future<void> _appLanguage(String id, {Ground? ground}) async {
  final g = ground ?? Ground();
  await g.refresh();
  final c = g.config;
  if (c == null) return;
  await g.saveConfig(Settings(
    scanOnImport: c.scanOnImport,
    revealSeconds: c.revealSeconds,
    autoLockMinutes: c.autoLockMinutes,
    packId: id,
    originalPanePercent: c.originalPanePercent,
    columnsInStep: c.columnsInStep,
    safeColumnOpen: c.safeColumnOpen,
    reviewPanelWide: c.reviewPanelWide,
    language: id,
    firstRunDone: c.firstRunDone,
    sessionOnly: c.sessionOnly,
  ));
}

/// A ground whose **config is the real one** and whose session row is the
/// fixture. The config has to be read from the core, because that is where
/// every screen reads it from; a test that set the field would be measuring its
/// own fixture and would have been green through the owner's defect.
Future<Ground> _groundWith(ConversationRow? open) async {
  final g = Ground();
  await g.refresh();
  if (open != null) {
    g.sessions = [open];
    g.openSession = open.number;
  } else {
    g.sessions = const [];
    g.openSession = null;
  }
  return g;
}

void main() {
  late final Directory own;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(
        buildTheBridgeFirst,
      );
    }
    await RustLib.init();
    // **A folder of this file's own.** `_appLanguage` writes the config for
    // real, because that is the only place a screen reads it from — and
    // without this it would write the person's own settings file.
    own = Directory('${Directory.systemTemp.path}/zprivacy-080-config-$pid');
    removeWhenItLetsGo(own);
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
  });

  tearDownAll(() {
    removeWhenItLetsGo(own);
  });

  group('the rule', () {
    test('a session with a language of its own is read in it, not the app\'s', () async {
      await _appLanguage('en');
      final g = await _groundWith(_row('de'));
      expect(
        packForTheNextText(g),
        'de',
        reason: 'the session says German, the application says English, and the '
            'text is read in ${packForTheNextText(g)} — which is the owner\'s '
            'own defect: 7 findings from a file, 0 from the same words pasted',
      );
    });

    test('a session with no language of its own is asked, and takes nothing', () async {
      await _appLanguage('en');
      expect(
        packForTheNextText(await _groundWith(_row(null))),
        isNull,
        reason: 'a session that never chose a language was given one nobody chose — '
            'which is the owner\'s own case, and rule 57-د is his answer to it',
      );
    });

    test('and so does a text with no session at all', () async {
      await _appLanguage('en');
      expect(
        packForTheNextText(await _groundWith(null)),
        'en',
        reason: 'with no session to ask, the application\'s own language was not used',
      );
    });

    test('the app\'s language is the fallback only where an answer could not be kept', () async {
      // The control that gives the three above their meaning: change the one
      // value and every answer that depends on it moves, in one step.
      await _appLanguage('de');
      expect(appLanguage(await _groundWith(null)), 'de');
      // A text with no session, and the vault shut so none could be born:
      // nobody to ask, nowhere to put the answer, so the app's is honest.
      expect(packForTheNextText(await _groundWith(null)), 'de');
      // A session that never chose does **not** move with the app's language,
      // because nothing answers for it — rule 57-د.
      expect(packForTheNextText(await _groundWith(_row(null))), isNull);
      // And a session with its own language does not move with it either.
      expect(packForTheNextText(await _groundWith(_row('en'))), 'en',
          reason: 'the app\'s language overrode a session\'s own');
    });
  });

  test('a new session follows the app\'s language and an old one keeps its own', () async {
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-080-$pid');
    removeWhenItLetsGo(dir);
    addTearDown(() {
      removeWhenItLetsGo(dir);
    });
    await z.vaultLock();
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');

    final ground = Ground();
    await ground.refresh();
    await _appLanguage('de', ground: ground);

    // **The room's way**: a session created with a language of its own, written
    // by its number with no document open — the door 080 added to the core,
    // because `switch_pack` needs a bench and a session may be created without
    // one.
    final chosen = await z.conversationBegin(name: 'Nordstern', bench: null);
    expect(chosen.packId, isNull, reason: 'a birth with no bench invented a language');
    expect(await ground.setSessionPack(chosen.number, 'en'), isTrue,
        reason: 'the language could not be written: ${ground.trouble}');
    await ground.refresh();
    expect(
      ground.sessions.firstWhere((r) => r.number == chosen.number).packId,
      'en',
      reason: 'the session does not carry the language it was created with',
    );

    // Now the application's language changes. The session that chose one keeps
    // it; and a text with no session, **with this vault open**, is asked —
    // rule 57b, because the session it would be read into is about to be born
    // and its language is the person's to choose at that instant.
    //
    // This assertion read `'sv'` until 17 October, and the value was never
    // consumed in that state: the shell asked the question first and threw the
    // answer away. Rule 57-د put the asking in the function, so «ask» is now
    // something the type can say, and the guard says it here.
    await _appLanguage('sv', ground: ground);
    expect(
      packForTheNextText(await _groundWith(_row('en'))),
      'en',
      reason: 'a session that chose its own language followed the app instead',
    );
    expect(
      packForTheNextText(await _groundWith(null)),
      isNull,
      reason: 'a text with an open vault and no session took a language nobody chose',
    );
  });
}

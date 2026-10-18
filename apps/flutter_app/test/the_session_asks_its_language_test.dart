// **Rules 56 and 57** — the owner, 16 October 2026, after working in Swedish
// and then making a session he was never asked about: «لم يسألني عن لغة
// الجلسة».
//
//   * **56** — Swedish is offered beside German and English, everywhere a
//     language is chosen. Arabic stays unoffered until he says otherwise, and
//     the pack is in the core either way: «offered» is about what a person is
//     shown, never about what was deleted.
//   * **57a** — a session does not begin before the person picks its language,
//     and **nothing is pre-marked**. The form ticked the application's own
//     language and took it from anyone who only pressed «Begin», which is a
//     question answered on the person's behalf.
//   * **57c** — after that, nothing in the session asks again: its language is
//     its own (rule 33).
//
// 57b — the question a document's own birth asks — lives where that door is:
// `the_home_is_the_composer_test.dart`, at the composer the owner uses.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ett lösenord långt nog för en session';

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Future<Ground> fresh(WidgetTester tester, String name) async {
  final ground = Ground();
  await tester.runAsync(() async {
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-057-$name-$pid');
    removeWhenItLetsGo(dir);
    addTearDown(() {
      removeWhenItLetsGo(dir);
    });
    await z.vaultLock();
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    await ground.refresh();
  });
  return ground;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('rule 56 — Swedish is offered, Arabic is not, and both are in the core',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await fresh(tester, 'offered');

    // The core's own labels, so nothing here spells a language for itself.
    final offered = ground.packs.where((p) => offeredLanguages.contains(p.id)).toList();
    expect(
      offered.map((p) => p.id).toList()..sort(),
      ['de', 'en', 'sv'],
      reason: 'the languages offered on the glass are ${offered.map((p) => p.id).toList()}',
    );
    // **Not offered is not absent**: Arabic is a language this build knows and
    // does not show, which is the half of rule 56 that is easy to lose.
    expect(
      ground.languages.any((l) => l.id == 'ar'),
      isTrue,
      reason: 'Arabic is not even in the language table, so «not offered» measures nothing',
    );
    expect(offeredLanguages, isNot(contains('ar')));

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.language),
    ));
    await settle(tester);
    for (final p in offered) {
      expect(find.text(p.label), findsWidgets,
          reason: 'the App language card does not offer «${p.label}»');
    }
  });

  testWidgets('rule 57a — no session begins before a language is picked', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await fresh(tester, 'asks');

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.sessions),
    ));
    await settle(tester);

    // A name, and no language: the press does nothing at all. Before rule 57a
    // this made a session in the application's language — ticked for the
    // person and taken from them.
    await tester.enterText(find.byType(TextField).first, 'Faruk AB');
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Begin'), warnIfMissed: false);
    await settle(tester, rounds: 3);
    expect(
      ground.sessions,
      isEmpty,
      reason: 'a session was begun in a language nobody chose: ${ground.sessions}',
    );

    // And with the language picked — Swedish, the owner's own case — it begins
    // in that language and in no other.
    final swedish = ground.packs.firstWhere((p) => p.id == 'sv');
    await tester.tap(find.text(swedish.label));
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Begin'));
    // The birth is three core calls deep (begin, the language, the bench's own
    // rescan) and each needs a real turn of the loop: `testWidgets` runs in a
    // fake-async zone, where an FFI future resumes only inside `runAsync`.
    await settle(tester, rounds: 20);

    expect(ground.sessions, hasLength(1), reason: 'the session was not begun');
    final row = ground.sessions.first;
    expect(row.name, 'Faruk AB');
    expect(row.packId, 'sv', reason: 'the session was begun in «${row.packId}»');

    // **Rule 57c**: its language is its own, and the next text in it is read
    // with that and asks nothing. The application's language is German here —
    // the default — so a session that had taken it silently would read 'de'.
    expect(appLanguage(ground), isNot('sv'),
        reason: 'the app language is already Swedish, so this proves nothing');
    expect(packForTheNextText(ground), 'sv',
        reason: 'the next text in this session would be read in another language');
    expect(ground.aSessionWouldBeBorn, isFalse,
        reason: 'a session is open, so nothing may ask again');
  });
}

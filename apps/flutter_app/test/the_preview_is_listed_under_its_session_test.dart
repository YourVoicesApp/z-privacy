// 089 rule 9 on the glass — **the documents a session is holding**.
//
// The owner, 15 Oct 2026: «تُدرج المستندات المحفوظة تحت اسم المحادثة في قائمة
// المحادثات، كما تُدرج المحادثات اليوم، ولكل منها «إعادة تسمية». والضغط عليها
// يفتحها في المعاينة كما تُركت».
//
// The core's half is in `z_core/tests/the_preview_keeps_what_it_holds.rs`,
// eleven guards, each break of the rule driven by its own door. These are the
// two things a person sees:
//
//   * the row, under the session's own name, saying what it is and how much is
//     protected on it — the core's own handle («doc1») and the core's own
//     count, because no number on this screen is worked out in Dart;
//   * the press, which is the shell's to answer: only the shell holds a bench,
//     so the row hands the three numbers up and nothing else.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein genügend langes Kennwort für die Vorschau';

/// A line the German pack finds names and an identifier in, so the row's count
/// is a real number rather than zero.
const _letter = 'Kundennummer 8841-2270 für Herrn Stefan Keller, Nordstern Consulting GmbH.';

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a session lists what its preview holds, and the row is the press',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final int number;
    await tester.runAsync(() async {
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-089-glass-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      // A conversation, and then a file opened into it — the owner's own order.
      final first = await z.openSession(packId: 'de');
      await z.conversationBegin(name: 'die Mahnung', bench: first);
      number = (await z.conversationOpen())!;
      await z.closeSession(session: first);
      final session = await z.openSession(packId: 'de');
      await z.conversationEnter(number: number, bench: session);
      await z.importDocument(
        session: session,
        name: 'Mahnung.txt',
        // **UTF-8, not the string's code units.** «für» has a ü in it, so
        // `codeUnits` hands the reader bytes it rightly refuses: «this file is
        // not UTF-8 (byte 24 is not valid)». Measured, not guessed.
        bytes: utf8.encode(_letter),
        kind: DocumentKind.txt,
      );
      await z.closeSession(session: session);
      await ground.refresh();
    });

    // The core kept it, and the glass is about to say so. Asked first, because
    // a row that is missing for want of a document would be a green test about
    // nothing.
    final held = ground.kept[number] ?? const [];
    expect(held, hasLength(1), reason: 'the core kept no document, so there is nothing to draw');
    expect(held.first.handle, 'doc1');
    expect(held.first.protected, greaterThan(0));

    int? opened;
    int? which;
    bool? chat;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          ground: ground,
          onClose: () {},
          room: SettingsRoom.sessions,
          onOpenKept: (n, w, c) {
            opened = n;
            which = w;
            chat = c;
          },
        ),
      ),
    );
    await settle(tester);

    expect(find.text('die Mahnung'), findsOneWidget, reason: 'the session is not listed');
    // **The row, in the core's own words**: the handle, the name, the count.
    final row = find.textContaining('doc1 · Mahnung.txt');
    expect(row, findsOneWidget, reason: 'the saved document is not listed under its session');
    expect(
      tester.widget<Text>(row.first).data,
      contains('protected place'),
      reason: 'the row does not say how much is protected on it',
    );
    // **And «Rename» is offered**, one per document — beside the session's own.
    expect(
      find.byTooltip('Rename this document'),
      findsOneWidget,
      reason: 'a saved document cannot be renamed',
    );

    // **The press hands the three numbers up and does nothing itself.**
    await tester.tap(find.byKey(Key('kept-$number-doc1')));
    await settle(tester, rounds: 1);
    expect(opened, number, reason: 'the press did not name the session');
    expect(which, 1, reason: 'the press did not name the document');
    expect(chat, isFalse, reason: 'a file from the computer was pressed as a chat');
  });

  testWidgets('a session holding nothing draws no row at all', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    await tester.runAsync(() async {
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-089-glass-empty-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      final session = await z.openSession(packId: 'de');
      await z.conversationBegin(name: 'die leere', bench: session);
      await z.closeSession(session: session);
      await ground.refresh();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.sessions),
      ),
    );
    await settle(tester);

    // The control for the test above: with nothing held, nothing is drawn — not
    // an empty box, not a «no documents» line. A document that left by a door
    // is not kept, and that is the rule rather than a loss.
    expect(find.text('die leere'), findsOneWidget);
    expect(find.textContaining('doc1'), findsNothing);
    expect(find.byTooltip('Rename this document'), findsNothing);
  });
}

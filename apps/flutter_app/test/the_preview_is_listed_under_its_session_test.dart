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
// **And since rule 55** (the owner, 16 October): a session that holds only
// documents — nothing written to a model in it at all — is in that list from
// the instant its first document enters the preview, under the name the core
// gives a session nobody named. The third test is where the core's spelling of
// that name and the glass's are measured against each other.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/messages.dart';
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
    // The document's own name is isolated in the row (16 October): a
    // right-to-left name beside «doc1 ·» would otherwise drag the handle out
    // of order. The row is found through the same function that writes it.
    final row = find.textContaining('doc1 · ${theirOwnWord('Mahnung.txt')}');
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

  testWidgets('a session born of its first document is listed under its own number',
      (tester) async {
    // **Rule 55 on the glass** — the owner, 16 October: a session appears in
    // the list the moment its first document enters the preview, with the
    // document under its name. Nothing is written to a model here and no
    // session is begun: a file is opened, and that is the whole act.
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final int number;
    await tester.runAsync(() async {
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-055-glass-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      final session = await z.openSession(packId: 'de');
      await z.importDocument(
        session: session,
        name: 'Mahnung.txt',
        bytes: utf8.encode(_letter),
        kind: DocumentKind.txt,
      );
      await z.closeSession(session: session);
      await ground.refresh();
      number = (await z.conversationOpen())!;
    });

    // **One name, two languages.** The core writes the name of a session
    // nobody named, and the glass spells the same words in `nameForSession` —
    // the send sheet reads it to tell an unnamed session from a named one. If
    // either side changed its spelling this is where it is caught.
    expect(ground.sessions, hasLength(1), reason: 'no session was born of the first document');
    expect(
      ground.sessions.first.name,
      nameForSession(number),
      reason: 'the core and the glass spell an unnamed session differently',
    );
    final held = ground.kept[number] ?? const [];
    expect(held, hasLength(1), reason: 'the first document was not kept');
    expect(held.first.handle, 'doc1');

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.sessions),
      ),
    );
    await settle(tester);

    expect(
      find.text(nameForSession(number)),
      findsOneWidget,
      reason: 'a session that holds only documents is not in the list',
    );
    expect(
      find.textContaining('doc1 · ${theirOwnWord('Mahnung.txt')}'),
      findsOneWidget,
      reason: 'its first document is not listed under it',
    );
    expect(find.byTooltip('Rename this document'), findsOneWidget);
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

// 075b — pressing a session's name opens what that session kept.
//
// **The owner, 10 Oct 2026:** «الجلسة تحفظ الملفات التي ذهبت والإجابات… الضغط
// على اسم الجلسة». The Sessions list used to *select* a session and leave the
// person standing where they were, which the lead named exactly: selection
// without showing is half an answer.
//
// Four claims, and the first two are about the drawing rather than the door,
// because a door that opens an empty box answers nothing:
//
//   * what the session kept is drawn — the question, the answer, and the names
//     this session could not restore, said as words and not left as a gap;
//   * a session that has sent nothing says so, and does not look like a
//     conversation that was lost. «Nothing yet», «the file is empty» and «it
//     could not be read» are three states and this screen spells three;
//   * the name in the panel's Sessions room is a press target that opens it;
//   * so is the name in the head, which until today was a fact and not a door
//     by a decision written into `bits.dart` — the owner reversed it and the
//     old reasoning is kept there beside the new.
//
// What this file does **not** prove, and nothing here pretends otherwise: that
// the core keeps a turn across a restart. That is `the_third_exit_test`'s
// guard 6 and 075c's three, and this screen reads what they write.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/conversation_view.dart';
import 'the_folder_lets_go.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
  }
  await tester.pumpAndSettle();
}

ConversationRow _row({
  int number = 3,
  String name = 'Nordstern',
  int turns = 1,
}) => ConversationRow(
  number: number,
  name: name,
  beganAt: BigInt.from(1760000000),
  turns: turns,
  renamedTokens: 0,
);

TurnRow _turn() => TurnRow(
  question: const [
    Segment(text: 'What does ', piece: Piece.words),
    Segment(text: 'Hedvig Palmgren', piece: Piece.restored),
    Segment(text: ' earn?', piece: Piece.words),
  ],
  answer: const [
    Segment(text: 'The gross figure for ', piece: Piece.words),
    Segment(text: 'Hedvig Palmgren', piece: Piece.restored),
    Segment(text: ' is 42 500, and ', piece: Piece.words),
    Segment(text: '__Z_7K2M_PERSON_9QX4__', piece: Piece.unresolved),
    Segment(text: ' is not in this session.', piece: Piece.words),
  ],
  at: BigInt.from(1760000100),
  unresolved: const ['__Z_7K2M_PERSON_9QX4__'],
  // A turn kept before a turn could say what answered it, or what it was
  // about. These four tests are about what the screen *shows* of a restored
  // turn, and it must show it whether or not the file knew — so the fixture
  // states the one truthful thing about itself and nothing more. Both fields
  // arrived one commit apart, and the second was written here in the same act
  // as the first rather than waiting for the compiler to ask twice.
  via: const TurnVia.notRecorded(),
  document: const TurnDocument.notRecorded(),
  // **A turn older than the chats** (format 6, rule 67): it belongs to no
  // numbered chat and names no saved document, which is the same truthful zero
  // the reader gives a file written before this round. These four tests are
  // about what the screen shows of a **restored** turn, so the two coded sides
  // carry the stored form of the halves above — the form everything in this
  // file is drawn from is the restored one, and a fixture that put prose in the
  // coded fields would be claiming a protection it never made.
  chatNumber: 0,
  keptHandle: null,
  questionAsItLeft: 'What does __Z_1A2B_PERSON_3C4D__ earn?',
  answerAsWritten:
      'The gross figure for __Z_1A2B_PERSON_3C4D__ is 42 500, and '
      '__Z_7K2M_PERSON_9QX4__ is not in this session.',
);

Future<void> _pumpView(WidgetTester tester, Widget view) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
  await settle(tester);
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

  testWidgets('what the session kept is what is drawn', (tester) async {
    await _pumpView(tester, ConversationView(row: _row(), turns: [_turn()]));

    expect(find.byKey(ConversationView.screen), findsOneWidget);
    expect(
      find.text('Nordstern'),
      findsOneWidget,
      reason: 'the handle is not on the screen',
    );
    expect(
      find.textContaining('42 500'),
      findsOneWidget,
      reason:
          'what came back is not drawn, so the screen shows a session and '
          'not its conversation',
    );
    expect(
      find.textContaining('earn?'),
      findsOneWidget,
      reason:
          'what was asked is not drawn, and the owner asked for both halves',
    );
    // The unresolved name is **said**, not silently left as a token in the
    // middle of a sentence — the lie the restore path exists to prevent.
    expect(
      find.textContaining('could not be restored'),
      findsOneWidget,
      reason: 'a name this session cannot resolve is passed off as prose',
    );
  });

  testWidgets('a session that has sent nothing says so', (tester) async {
    await _pumpView(
      tester,
      ConversationView(row: _row(turns: 0), turns: const []),
    );
    expect(
      find.textContaining('Nothing has been sent'),
      findsOneWidget,
      reason:
          'an empty conversation is drawn as an empty box, which reads the '
          'same as one that was lost',
    );

    // And the third state is not the second: a reading that failed says so.
    await _pumpView(
      tester,
      ConversationView(
        row: _row(turns: 2),
        turns: const [],
        trouble: 'The vault is shut, so this session cannot be read.',
      ),
    );
    expect(
      find.textContaining('cannot be read'),
      findsOneWidget,
      reason:
          'a conversation that could not be read is drawn as one that is '
          'empty, and those are not the same fact',
    );
    expect(find.textContaining('Nothing has been sent'), findsNothing);
  });

  testWidgets('the name in the head is the door', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final ConversationRow row;
    await tester.runAsync(() async {
      final dir = Directory(
        '${Directory.systemTemp.path}/zprivacy-075b-head-$pid',
      );
      removeWhenItLetsGo(dir);
      addTearDown(() {
        removeWhenItLetsGo(dir);
      });
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: 'Hedvig Palmgren 9999 000 01');
      row = await z.conversationBegin(name: 'Nordstern', bench: session);
      await ground.refresh();
    });

    expect(
      ground.openSessionRow?.number,
      row.number,
      reason:
          'no session is open, so the head draws nothing and the press '
          'below would prove nothing',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: TheOpenSession(ground: ground)),
        ),
      ),
    );
    await settle(tester);

    expect(
      find.byKey(ConversationView.door),
      findsOneWidget,
      reason: 'the name in the head is not a press target',
    );
    await tester.tap(find.byKey(ConversationView.door));
    await settle(tester);
    expect(
      find.byKey(ConversationView.screen),
      findsOneWidget,
      reason: 'pressing the session name opened nothing',
    );
    expect(
      find.textContaining('Nothing has been sent'),
      findsOneWidget,
      reason:
          'a newborn session has sent nothing, and the screen should say '
          'that rather than show a blank',
    );
  });

  testWidgets('and so is the name in the panel\'s Sessions room', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    await tester.runAsync(() async {
      final dir = Directory(
        '${Directory.systemTemp.path}/zprivacy-075b-room-$pid',
      );
      removeWhenItLetsGo(dir);
      addTearDown(() {
        removeWhenItLetsGo(dir);
      });
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
      final session = await z.openSession(packId: 'de');
      // **One session, and the document's own** — rule 55, 16 October: the text
      // entering the preview births the session it is kept in, so a
      // `conversationBegin` on top of it would make a second row and this room
      // would hold two doors. The session is renamed instead, which is what a
      // person does here: «Session 1» is the name it takes and «Merkur» is the
      // one they give it.
      await z.importText(session: session, text: 'Tobias Nyqvist 9999 000 02');
      final born = (await z.conversationOpen())!;
      await z.conversationRename(number: born, name: 'Merkur');
      await ground.refresh();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          ground: ground,
          onClose: () {},
          room: SettingsRoom.sessions,
        ),
      ),
    );
    await settle(tester);

    expect(
      find.text('Merkur'),
      findsOneWidget,
      reason: 'the room lists no session',
    );
    expect(
      find.byKey(ConversationView.door),
      findsOneWidget,
      reason: 'the session\'s name in the room is not a press target',
    );
    await tester.tap(find.byKey(ConversationView.door));
    await settle(tester);
    expect(
      find.byKey(ConversationView.screen),
      findsOneWidget,
      reason: 'the list still selects and shows nothing — half an answer',
    );
  });
}

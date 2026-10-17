// **The session list records both doors** — rule 69, the owner, 17 October 2026.
//
// «يجب أن يظهر في الجلسة ووثيقة رقم 1 أنه تم إرسال وثيقة للذكاء الاصطناعي وتم
// الإجابة» — under the document that entered: that it was sent to the AI, and
// that it was answered.
//
// Two halves, and the second is the one worth guarding: **the anchor is the
// document's own handle**, stamped on the payload when it was built, so the
// line is about this row and not about whichever of its neighbours shares a
// name. A follow-up question carries no document and no handle — the chat's
// first turn names it and `chatNumber` carries the rest of the chat with it —
// so «answered» is read across the whole chat the document began. Both of
// those are measured here, because a later round reaching for the *name*
// instead would be green on every tree anybody tests.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

KeptRow _kept({
  int number = 1,
  bool chat = false,
  String handle = 'doc1',
  String name = 'die Mahnung.pdf',
}) => KeptRow(
  number: number,
  chat: chat,
  handle: handle,
  name: name,
  at: BigInt.from(1760000000),
  protected: 3,
);

TurnRow _turn({
  required TurnDocument about,
  String? kept,
  int chat = 1,
  bool answered = true,
}) => TurnRow(
  via: const TurnVia.notRecorded(),
  document: about,
  // **The two the round added**: which chat this turn belongs to, and which
  // kept document the chat began with. `null` is a follow-up question — it
  // carries no document, by rule 67.
  chatNumber: chat,
  keptHandle: kept,
  questionAsItLeft: 'Was steht da?',
  answerAsWritten: answered ? 'Das steht da.' : '',
  question: const [Segment(text: 'Was steht da?', piece: Piece.words)],
  answer: answered
      ? const [Segment(text: 'Das steht da.', piece: Piece.words)]
      : const [],
  at: BigInt.from(1760000100),
  unresolved: const [],
);

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // The line itself, through the room a person reads it in — and through the
  // core's own door for the turn, so what is drawn comes out of a sealed
  // session file rather than out of a fixture.
  testWidgets('the room says a kept document was sent to AI and answered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    await tester.runAsync(() async {
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-rule69-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      addTearDown(() {
        // Best effort, for the race named in
        // `later_is_not_an_answer_test.dart`: a write that lands as the test
        // ends makes `deleteSync` throw «Directory not empty».
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        } on FileSystemException {
          // Left behind rather than red for something no claim is about.
        }
      });
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
      // Rule 55: the text entering the preview births the session it is kept
      // in, so this is one session holding one written document — «chat1».
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: 'Tobias Nyqvist 9999 000 02');
      final bench = Workbench(session: session, profileId: null, packId: 'de');
      addTearDown(bench.dispose);
      await bench.rescan();
      for (final f in bench.suggested) {
        await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();
      // **One exchange about it, through a door that anchors it.**
      // `conversationRecord` is the by-hand door and says so: it is called
      // with two strings and no payload, so it writes `kept: None` on purpose
      // — «inventing one would be the guess rule 69's number exists to
      // refuse». A turn that names a document can therefore only come from a
      // door that had the payload, so this walks the manual pair a person
      // walks: the safe text is taken out, and the answer is brought back
      // against that payload.
      await ground.refresh();
      if (ground.aSessionWouldBeBorn) {
        await ground.beginSessionItNames(bench: bench.session);
        await bench.refresh();
      }
      bench.rememberCopiedPayload();
      await bench.pasteAnswer('Das steht da.');
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.sessions),
    ));
    await settle(tester);

    expect(find.textContaining('chat1'), findsOneWidget,
        reason: 'the room lists no kept document, so nothing below is measured');
    expect(find.text('sent to AI · answered'), findsOneWidget,
        reason: 'the session does not record that the document was sent and answered');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // The two silences, read from the one function that words the line — no
  // panel, no vault, because what is under test is what the data can say.
  test('a document nothing was sent about says nothing', () {
    final doc = _kept();
    expect(theDoorsOfAKeptDocument(doc, const []), isNull,
        reason: 'a document with no turns claims to have been sent');
    expect(
      theDoorsOfAKeptDocument(doc, [_turn(about: const TurnDocument.typed(), kept: 'chat1')]),
      isNull,
      reason: 'a turn about another document was read onto this one',
    );
    expect(
      theDoorsOfAKeptDocument(doc, [_turn(about: const TurnDocument.notRecorded())]),
      isNull,
      reason: 'a turn that names no document was read onto one anyway',
    );
  });

  test('a document sent with no answer back says exactly that', () {
    final doc = _kept();
    expect(
      theDoorsOfAKeptDocument(doc, [
        _turn(
          about: const TurnDocument.named(name: 'die Mahnung.pdf'),
          kept: 'doc1',
          answered: false,
        ),
      ]),
      'sent to AI · no answer yet',
    );
  });

  // ------------------------------------------------------------------ guard 3
  test('the handle is the anchor, so two documents of one name are told apart', () {
    // Two files a person gave the same name — the case the first form of this
    // function could only answer with silence.
    final a = _kept(number: 1, handle: 'doc1');
    final b = _kept(number: 2, handle: 'doc2');
    final turns = [
      _turn(about: const TurnDocument.named(name: 'die Mahnung.pdf'), kept: 'doc2'),
    ];
    expect(theDoorsOfAKeptDocument(b, turns), 'sent to AI · answered',
        reason: 'the document the turn names says nothing about itself');
    expect(theDoorsOfAKeptDocument(a, turns), isNull,
        reason: 'the other document of the same name took the credit');

    // And two written texts in one session: «typed» is not the anchor either.
    final chat1 = _kept(number: 1, chat: true, handle: 'chat1', name: '');
    final chat2 = _kept(number: 2, chat: true, handle: 'chat2', name: '');
    final typed = [_turn(about: const TurnDocument.typed(), kept: 'chat2')];
    expect(theDoorsOfAKeptDocument(chat2, typed), 'sent to AI · answered');
    expect(theDoorsOfAKeptDocument(chat1, typed), isNull,
        reason: 'one of two written texts took the credit for the other');
  });

  // ------------------------------------------------------------------ guard 4
  test('a follow-up question answers for the document its chat began with', () {
    // Rule 67: the second question carries no document, so it carries no
    // handle — and the chat it is in does. The line must read «answered»
    // whichever turn of that chat the answer came back in.
    final doc = _kept(handle: 'doc1');
    final first = _turn(
      about: const TurnDocument.named(name: 'die Mahnung.pdf'),
      kept: 'doc1',
      answered: false,
    );
    final second = _turn(about: const TurnDocument.notRecorded(), chat: 1);
    expect(theDoorsOfAKeptDocument(doc, [first]), 'sent to AI · no answer yet',
        reason: 'the first turn went out and nothing came back yet');
    expect(theDoorsOfAKeptDocument(doc, [first, second]), 'sent to AI · answered',
        reason: 'the answer came back in the chat’s second turn and the line did not say so');

    // **And a turn of another chat is not borrowed.** A second chat in the
    // same session, about nothing this document began, says nothing about it.
    final elsewhere = _turn(about: const TurnDocument.notRecorded(), chat: 2);
    expect(theDoorsOfAKeptDocument(doc, [first, elsewhere]), 'sent to AI · no answer yet',
        reason: 'another chat’s answer was read as this document’s');
  });
}

// **The session list records both doors** — rule 69, the owner, 17 October 2026.
//
// «يجب أن يظهر في الجلسة ووثيقة رقم 1 أنه تم إرسال وثيقة للذكاء الاصطناعي وتم
// الإجابة» — under the document that entered: that it was sent to the AI, and
// that it was answered.
//
// Two halves, and the second is the one worth guarding: a turn says what it was
// **about** as a file's name or as «the person typed it», never as the kept
// document's own number. So where two documents of a session cannot be told
// apart, the line is not drawn at all — a line under the wrong document would
// be worse than no line. That silence is measured here, because it is the kind
// of thing a later round would «fix» by guessing.
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

TurnRow _turn({required TurnDocument about, bool answered = true}) => TurnRow(
  via: const TurnVia.notRecorded(),
  document: about,
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
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
      // Rule 55: the text entering the preview births the session it is kept
      // in, so this is one session holding one written document — «chat1».
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: 'Tobias Nyqvist 9999 000 02');
      // One exchange about it, written through the core's own door: the person
      // typed the text, so that is what the turn says it was about.
      await z.conversationRecord(
        question: 'Was steht da?',
        answer: 'Das steht da.',
        via: const TurnVia.notRecorded(),
        document: const TurnDocument.typed(),
      );
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
    expect(theDoorsOfAKeptDocument(doc, [doc], const []), isNull,
        reason: 'a document with no turns claims to have been sent');
    expect(
      theDoorsOfAKeptDocument(doc, [doc], [_turn(about: const TurnDocument.typed())]),
      isNull,
      reason: 'a turn about a typed text was read onto a file',
    );
    expect(
      theDoorsOfAKeptDocument(doc, [doc], [_turn(about: const TurnDocument.notRecorded())]),
      isNull,
      reason: 'a turn that does not say what it was about was read onto a document anyway',
    );
  });

  test('a document sent with no answer back says exactly that', () {
    final doc = _kept();
    expect(
      theDoorsOfAKeptDocument(
        doc,
        [doc],
        [_turn(about: const TurnDocument.named(name: 'die Mahnung.pdf'), answered: false)],
      ),
      'sent to AI · no answer yet',
    );
  });

  // ------------------------------------------------------------------ guard 3
  test('two documents a turn cannot tell apart are both left silent', () {
    // Two written texts in one session: every «typed» turn matches both, so
    // neither may claim it.
    final chat1 = _kept(number: 1, chat: true, handle: 'chat1', name: '');
    final chat2 = _kept(number: 2, chat: true, handle: 'chat2', name: '');
    final typed = [_turn(about: const TurnDocument.typed())];
    expect(theDoorsOfAKeptDocument(chat1, [chat1, chat2], typed), isNull,
        reason: 'one of two written texts took the credit for the other');
    expect(theDoorsOfAKeptDocument(chat2, [chat1, chat2], typed), isNull);
    // And the same for two files a person gave the same name.
    final a = _kept(number: 1, handle: 'doc1');
    final b = _kept(number: 2, handle: 'doc2');
    final named = [_turn(about: const TurnDocument.named(name: 'die Mahnung.pdf'))];
    expect(theDoorsOfAKeptDocument(a, [a, b], named), isNull,
        reason: 'two documents with one name, and the line went under one of them');
    expect(theDoorsOfAKeptDocument(b, [a, b], named), isNull);
    // The control: alone, it is said — so the silences above are the rule
    // biting and not the function saying nothing at all.
    expect(theDoorsOfAKeptDocument(a, [a], named), 'sent to AI · answered');
    expect(theDoorsOfAKeptDocument(chat1, [chat1], typed), 'sent to AI · answered');
  });
}

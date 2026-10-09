// 064/D · The session question stands in both places, and is answered once.
//
// The owner's ruling, 9 October: the session question belongs **in the chat
// screen itself when the person has no session**, and in the screen after the
// filter — the review page, where 064 put it. Both through the one helper.
//
// ## Two places, one question, one answer
//
// «The name is asked once» is the owner's own rule, so two surfaces asking it
// cannot mean two answers. The name a person types in the chat is a **wish**
// kept on the ground — not a session, which only an exit may begin — and the
// review page's field carries that wish rather than asking again. A person who
// names their work in the chat and then presses «Ask the AI» must find their
// own word already in the sheet; finding an empty field there would be the
// product asking twice and the rule broken in the only way that matters.
//
// ## What the chat's question cannot do
//
// It cannot begin the session, and it does not pretend to: «Ask the AI» scans
// and opens the review, and the birth happens where the text leaves — the
// clipboard, the PDF, or a send through a key. So the chat's band says what
// will begin it, and the band on the review page says the same thing about its
// own doors. One wording, two closing sentences, because the acts differ.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/widgets/the_session_question.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Kunde: Nordstern Consulting GmbH\nIBAN DE02120300000000202051\n';

Future<void> _settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Future<({Ground ground, Workbench bench})> _ready(
  WidgetTester tester,
  String name, {
  bool withAVault = true,
  bool withASession = false,
}) async {
  late final ({Ground ground, Workbench bench}) made;
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-both-$name-$pid');
    if (own.existsSync()) own.deleteSync(recursive: true);
    own.createSync(recursive: true);
    addTearDown(() {
      if (own.existsSync()) own.deleteSync(recursive: true);
    });
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    if (withAVault) {
      await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för frågan');
    }
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    // The gate is not what this file measures, and an unanswered suggestion
    // draws a warning band of its own in the composer.
    for (final f in bench.suggested) {
      await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
    }
    await bench.refresh();
    await ground.refresh();
    if (withASession) {
      final renamed = await ground.beginSession('Jupiter', bench: session);
      if (renamed == null) throw StateError('no session: ${ground.trouble}');
      await bench.refresh();
    }
    made = (ground: ground, bench: bench);
  });
  return made;
}

Widget _home(({Ground ground, Workbench bench}) g) => MaterialApp(
  home: HomeScreen(
    ground: g.ground,
    version: 'z_core 0.1.0',
    chat: g.bench,
    onImport: () {},
    onType: (_) {},
    onAsk: (_) async {},
    onVault: () {},
    onSettings: () {},
  ),
);

Widget _sheet(({Ground ground, Workbench bench}) g) => MaterialApp(
  home: Scaffold(body: SendSheet(bench: g.bench, ground: g.ground)),
);

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('the chat asks it, in the house’s own words', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'chat');
    await tester.pumpWidget(_home(g));
    await _settle(tester);

    expect(g.ground.theSessionQuestionStands, isTrue, reason: 'the fixture has no question to ask');
    final band = find.byKey(TheSessionQuestion.band);
    expect(band, findsOneWidget, reason: 'the chat screen does not ask for a session at all');
    expect(
      find.descendant(of: band, matching: find.textContaining('has no session yet')),
      findsOneWidget,
      reason: 'the chat’s band does not say what it is about',
    );
    expect(
      find.descendant(of: band, matching: find.textContaining('What is this one about?')),
      findsOneWidget,
      reason: 'the field does not ask the room’s own question',
    );
    final r = tester.getRect(band);
    expect(r.right, lessThanOrEqualTo(1100), reason: 'the band is off the window: $r');
    expect(r.height, greaterThan(40), reason: 'the band has no height: $r');
  });

  // ------------------------------------------------------------------ guard 2
  testWidgets('the name typed in the chat is the name the review page carries', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'carried');
    await tester.pumpWidget(_home(g));
    await _settle(tester);

    await tester.enterText(find.byKey(TheSessionQuestion.field), 'Nordstern ledger');
    await _settle(tester);
    expect(g.ground.sessionNameWished, 'Nordstern ledger',
        reason: 'what was typed in the chat is kept nowhere the other surface can read');

    // The sheet, as «Ask the AI» opens it — a fresh widget, the same ground.
    await tester.pumpWidget(_sheet(g));
    await _settle(tester);
    expect(
      find.widgetWithText(TextField, 'Nordstern ledger'),
      findsOneWidget,
      reason: 'the review page asked for the name again, which is the one rule this must not break',
    );
  });

  // ------------------------------------------------------------------ guard 3
  testWidgets('a session open: neither place asks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'open', withASession: true);

    await tester.pumpWidget(_home(g));
    await _settle(tester);
    expect(find.byKey(TheSessionQuestion.band), findsNothing,
        reason: 'the chat asks for a session while one is open');

    await tester.pumpWidget(_sheet(g));
    await _settle(tester);
    expect(find.byKey(TheSessionQuestion.band), findsNothing,
        reason: 'the review page asks for a session while one is open');
  });

  // ------------------------------------------------------------------ guard 4
  testWidgets('no vault: neither place asks, because none could be born', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'novault', withAVault: false);

    await tester.pumpWidget(_home(g));
    await _settle(tester);
    expect(find.byKey(TheSessionQuestion.band), findsNothing,
        reason: 'the chat asks for a session the vault cannot keep');
  });

  // ------------------------------------------------------------------ guard 5
  testWidgets('the wish is a wish: nothing is born until an exit is pressed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'wish');
    await tester.pumpWidget(_home(g));
    await _settle(tester);

    await tester.enterText(find.byKey(TheSessionQuestion.field), 'Saturn');
    await _settle(tester);

    // Typing a name is not beginning a session, and «Ask the AI» does not
    // begin one either: the birth belongs where the text leaves.
    //
    // **Every core read here is inside `runAsync`**: a real FFI future does not
    // complete in the fake-async zone a widget test runs in, and the first
    // version of this guard hung for ten minutes on `await z.conversations()`
    // in the test body — silently, with four guards green above it.
    late final int before;
    late final int? openBefore;
    await tester.runAsync(() async {
      before = (await z.conversations()).length;
      openBefore = await z.conversationOpen();
    });
    expect(before, 0, reason: 'typing a name began a session');
    expect(openBefore, isNull, reason: 'a session is open and nothing was pressed');

    // And the helper, driven with the wish, is what begins it — the same one
    // helper both surfaces' exits use.
    late final WhatMayLeave out;
    late final String born;
    await tester.runAsync(() async {
      out = await beginThenRead(g.ground, g.bench, name: g.ground.sessionNameWished);
      born = (await z.conversations()).single.name;
    });
    expect(out.refused, isNull, reason: 'the wish was refused: ${out.refused}');
    expect(born, 'Saturn',
        reason: 'the session was born under another name than the one typed in the chat');
  });
}

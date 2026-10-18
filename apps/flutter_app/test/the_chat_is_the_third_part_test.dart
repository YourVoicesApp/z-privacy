// **The chat: the third part of the one screen** — rules 65, 66, 67 and 68,
// the owner, 17 October 2026.
//
// «الترحيل يفتح قسم المحادثة في الشاشة الثالثة دائماً… تظهر الإجابة داخل الشات
// مرمزة مع زر عرض النص ليظهر في فقاعة… كل سؤال تالٍ في المحادثة نفسها يحمل
// التبادلات السابقة محمية.»
//
// Two of these guards are the ones paper 090 B7 asks for — a question sent and
// answered, and a second question in the same chat — and they are written
// through the real doors: a fake provider answers, the core writes the turns,
// and what is read is what the panel draws from them.
//
// **Five more are carried forward from `the_chat_reads_like_a_chat_test.dart`**,
// which measured the first screen's chat and went with that screen. Its
// findings were about the *shape* of a conversation and they outlive the
// screen: the writing is below the thread, the thread scrolls and the writing
// does not, the newest turn is on the glass when it arrives, and no window a
// person can drag to overflows. Each of those cost a measurement to find — at
// 900×520 the answer was once **never built**, which no eye on a 1920 screen
// would ever catch — so they are measured again here, against the panel that
// replaced it.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/the_chat.dart';
import 'the_folder_lets_go.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für den Tresor';

/// A letter with one name a general rule protects on its own, so there is a
/// token in what leaves and a value to come home.
const _doc = 'Sehr geehrter Herr Thomas Müller,\n'
    'die Rechnung über 42 500 EUR ist beglichen.\n';

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

List<String> overflows(WidgetTester tester) {
  final found = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    found.add(e.toString());
  }
  return found;
}

/// A document on a bench, every suggestion answered, in a session with a
/// vault — and the fake provider connected, so a question can be asked and
/// answered without a network.
///
/// `fake_provider` is a core feature flag, which is why the key is a literal
/// nobody could use: the answer comes from the core itself.
Future<({Ground ground, Workbench bench})> _ready(WidgetTester tester, String name) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-chat-$name-$pid');
    removeWhenItLetsGo(dir);
    addTearDown(() {
      // Best effort: the core may still be writing in here as the test ends,
      // and `deleteSync` then throws «Directory not empty» over a file that
      // appeared during its own walk — see the note in
      // `later_is_not_an_answer_test.dart`, where that race went red.
      try {
        removeWhenItLetsGo(dir);
      } on FileSystemException {
        // A temporary directory left behind is not a failure of a claim here.
      }
    });
    await z.vaultLock();
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    final session = await z.openSession(profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await bench.rescan();
    for (final f in bench.suggested) {
      await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
    }
    await bench.refresh();
    await z.connectProvider(
      provider: const ProviderId(id: 'fake'),
      credential: 'not-a-real-credential',
      baseUrl: null,
      model: null,
    );
    addTearDown(() async => z.disconnectProvider(provider: const ProviderId(id: 'fake')));
    await ground.refresh();
    await bench.refreshModels();
  });
  return (ground: ground, bench: bench);
}

/// The first question, through the sheet's own hand — which is how a person
/// asks it: «Choose who answers» and then a door. Nothing of the chat is
/// involved yet; the chat is what opens when the answer arrives.
Future<void> _askTheFirst(
  WidgetTester tester,
  ({Ground ground, Workbench bench}) g, {
  String question = 'Worum geht es?',
}) async {
  await tester.runAsync(() async {
    await g.bench.setQuestion(question);
    final bad = await beginThenAsk(g.ground, g.bench, providerId: 'fake');
    expect(bad.refused, isNull, reason: 'the first question did not go: ${bad.refused}');
  });
  await settle(tester);
}

Future<void> _pumpTheWork(
  WidgetTester tester,
  ({Ground ground, Workbench bench}) g, {
  Size size = const Size(1600, 1000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: WorkspaceScreen(
      bench: g.bench,
      ground: g.ground,
      onImport: () {},
      onAsk: (_) {},
      onVault: () {},
    ),
  ));
  await settle(tester);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // B7's first: a question is sent, an answer comes back, and the chat is open
  // with that answer **coded**. The name is nowhere on the glass until «Show
  // the text» is pressed, and then it is in the bubble and only there.
  testWidgets('a question answered opens the chat, coded, with the name only in the bubble',
      (tester) async {
    final g = await _ready(tester, 'first');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g);

    expect(find.byType(TheChat), findsOneWidget,
        reason: 'the answer did not open the third part of the screen');
    expect(g.bench.chatTurns, hasLength(1), reason: 'the send wrote no turn');

    Finder inChat(Finder f) => find.descendant(of: find.byType(TheChat), matching: f);

    // **Coded.** What travelled is what is drawn: the token, not the name.
    expect(inChat(find.textContaining('__Z_')), findsWidgets,
        reason: 'the thread does not draw what actually left');
    expect(inChat(find.textContaining('Thomas Müller')), findsNothing,
        reason: 'the thread draws a name the model never saw — rule 66');
    // And the two sides are named, with the door that answered.
    expect(inChat(find.text('you')), findsOneWidget);
    expect(inChat(find.textContaining('coded')), findsWidgets);

    // **One press, and the names are back — in the bubble.**
    expect(find.byKey(TheChat.bubble(0)), findsNothing,
        reason: 'the restored text is on the glass before anybody asked for it');
    await tester.tap(find.byKey(TheChat.showTheText(0)));
    await settle(tester, rounds: 2);
    final bubble = find.byKey(TheChat.bubble(0));
    expect(bubble, findsOneWidget, reason: '«Show the text» opened nothing');
    expect(
      find.descendant(of: bubble, matching: find.textContaining('Thomas Müller')),
      findsOneWidget,
      reason: 'the bubble did not put the name back',
    );
    // A second press puts it away again: the state is the person's.
    await tester.tap(find.byKey(TheChat.showTheText(0)));
    await settle(tester, rounds: 2);
    expect(find.byKey(TheChat.bubble(0)), findsNothing,
        reason: 'the bubble cannot be closed');

    expect(overflows(tester), isEmpty, reason: 'the chat overflows at 1600×1000');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // B7's second: a second question, typed in the compose box, and two turns in
  // the thread. The document is **not** sent again (rule 67) — what carries
  // the conversation is the history the core builds from the stored turns —
  // and the arrow names the door the first question chose.
  testWidgets('a second question in the compose box makes a second turn, to the same door',
      (tester) async {
    final g = await _ready(tester, 'second');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g);

    // The door is named on the arrow, because a person pressing it is sending
    // their words to somebody.
    expect(find.byKey(TheChat.arrow), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(TheChat.arrow), matching: find.textContaining('➤')),
      findsOneWidget,
      reason: 'the arrow does not say who answers',
    );

    await tester.enterText(find.byKey(TheChat.compose), 'Und der Betrag?');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(TheChat.arrow));
    await settle(tester, rounds: 20);

    expect(g.bench.chatTurns, hasLength(2),
        reason: 'the second question did not become a turn of this chat');
    // **The same chat**, which is what makes the history travel.
    expect(
      g.bench.chatTurns.map((t) => t.chatNumber).toSet(),
      hasLength(1),
      reason: 'the second question opened a chat of its own',
    );
    // **The document went once.** The second turn carries the question alone,
    // so it names no kept document — rule 67's «الوثيقة لا تُرسل مرة ثانية».
    expect(g.bench.chatTurns.first.keptHandle, isNotNull,
        reason: 'the first turn does not name the document it took');
    expect(g.bench.chatTurns.last.keptHandle, isNull,
        reason: 'the follow-up carried the document a second time');
    expect(g.bench.chatTurns.last.questionAsItLeft, contains('Betrag'),
        reason: 'the second question is not what left');

    // The box is empty again, because the question went.
    expect(
      tester.widget<TextField>(find.byKey(TheChat.compose)).controller!.text,
      isEmpty,
      reason: 'the question that went is still in the box',
    );
    // **Two turns, two «Show the text» presses — one per answer**, and the
    // newest is the one on the glass: the panel keeps the end of the thread in
    // view as a turn arrives.
    expect(find.byKey(TheChat.showTheText(1)), findsOneWidget);
    // The first turn's is **above the fold**, and that is the shape after ed's
    // A1: the first question of a chat is the whole payload the model saw —
    // document, `--- Request ---`, request — so one exchange is taller than
    // the panel. A `ListView` does not build what is off it and `find.byKey`
    // is blind to a widget that was never built, so the thread is dragged back
    // to it rather than asked about it where it is not.
    //
    // Dragged, not `scrollUntilVisible`: that one asks for **the** scrollable
    // of a subtree, and every coded side in the thread is a `SelectableText`
    // with a scroller of its own, so the thread holds as many as it has turns.
    // The loop is bounded, so a panel that never draws the first turn fails
    // here instead of scrolling for ever.
    for (var tries = 0;
        tries < 12 && find.byKey(TheChat.showTheText(0)).evaluate().isEmpty;
        tries++) {
      await tester.drag(find.byKey(TheChat.thread), const Offset(0, 300));
      await settle(tester, rounds: 2);
    }
    expect(find.byKey(TheChat.showTheText(0)), findsOneWidget,
        reason: 'the first turn of the chat is not drawn, even scrolled to');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **An answer brought back on a copy of the whole chat has no question** —
  // ed's A4, and the shape it makes on the glass: the chat *is* its payload,
  // so storing that as the question would put the conversation inside itself.
  // The thread must draw an answer with no «you» line above it rather than an
  // empty box claiming the person asked nothing.
  testWidgets('an answer added to a copied chat is drawn with no question above it',
      (tester) async {
    final g = await _ready(tester, 'added');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g);

    // Copy the chat — the core builds the text and binds the handle — then
    // bring an answer back to it.
    await tester.tap(find.byKey(TheChat.copy));
    await settle(tester, rounds: 6);
    expect(g.bench.copied?.what, WhatWasCopied.theChat,
        reason: 'copying the chat bound no handle of its own');

    await tester.tap(find.byKey(TheChat.add));
    await settle(tester, rounds: 2);
    await tester.enterText(find.byKey(TheChat.pasted), 'Es geht um die Rechnung.');
    await settle(tester, rounds: 2);
    await tester.tap(find.text('Add it to the chat'));
    await settle(tester, rounds: 20);

    expect(g.bench.chatTurns, hasLength(2), reason: 'the added answer wrote no turn');
    final added = g.bench.chatTurns.last;
    expect(added.questionAsItLeft, isEmpty,
        reason: 'the core stored the chat as the question of its own answer');
    // One «you» line on the glass, for the turn that had a question.
    expect(
      find.descendant(of: find.byType(TheChat), matching: find.text('you')),
      findsOneWidget,
      reason: 'the thread drew a question nobody asked',
    );
    // And the answer that came back by hand says so, rather than naming a key.
    expect(
      find.descendant(
        of: find.byType(TheChat),
        matching: find.textContaining('brought back by hand'),
      ),
      findsOneWidget,
      reason: 'the thread claims a key answered what a person carried',
    );
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **Carried forward: the shape of a chat.** The owner, 8 October: «الكتابة في
  // أسفل الشاشة والإجابة تظهر في أعلى» — the writing at the bottom, the answer
  // above it. Measured as rects, because this was once right in the tree and
  // wrong on the glass.
  testWidgets('the writing is below the thread, and against the bottom of the panel',
      (tester) async {
    final g = await _ready(tester, 'shape');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g, size: const Size(1500, 950));

    final panel = tester.getRect(find.byKey(TheChat.panel));
    final box = tester.getRect(find.byKey(TheChat.compose));
    final answer = tester.getRect(find.byKey(TheChat.showTheText(0)));
    expect(box.top, greaterThan(answer.top),
        reason: 'the writing is above the answer: $box against $answer');
    // **Against the bottom, measured as what stands between them** rather
    // than as a number of pixels. The first form of this said «within 120 px
    // of the panel's foot» and read 168: the three acts `Wrap` into two runs
    // at the panel's own width, which is the drawing rule 65 asks for and not
    // a floating box. What the claim is really about is that **nothing but
    // the acts** is below the writing, and that they sit on the panel's floor.
    final actsBottom = [TheChat.copy, TheChat.add, TheChat.end]
        .map((k) => tester.getRect(find.byKey(k)).bottom)
        .reduce((a, b) => a > b ? a : b);
    expect(box.bottom, lessThan(actsBottom),
        reason: 'the acts are above the writing, not under it: $box in $panel');
    expect(panel.bottom - actsBottom, lessThan(24),
        reason: 'the writing and its acts float in the middle of the panel: '
            'the last act ends at $actsBottom in $panel');
    expect(overflows(tester), isEmpty, reason: 'the chat overflows at 1500×950');
  });

  // ------------------------------------------------------------------ guard 5
  //
  // **Carried forward: the thread scrolls and the writing does not.** A
  // composer that travels with the thread is not a composer, it is a
  // paragraph — and at a short window the first screen's chat put its own last
  // line 44 px below the glass.
  testWidgets('the thread scrolls under a writing box that stays where it is', (tester) async {
    final g = await _ready(tester, 'scroll');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g, size: const Size(1400, 700));

    final before = tester.getRect(find.byKey(TheChat.compose));
    await tester.drag(find.byType(TheChat), const Offset(0, -200));
    await settle(tester, rounds: 2);
    final after = tester.getRect(find.byKey(TheChat.compose));
    expect(after, before, reason: 'the writing box moved with the thread: $before → $after');
    expect(overflows(tester), isEmpty, reason: 'the chat overflows at 1400×700');
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **Carried forward: the smallest window the work is measured at.** The
  // claim is the one the first screen's chat was measured for — at a short
  // window its own last line was once 44 px below the glass, and the acts
  // under the thread are the first thing that would fall off — but the size it
  // was measured at went with that screen. The chat was the whole window then;
  // it is one of three parts beside two columns now, and at 900×520 it is the
  // **work surface** that does not fit: the safe column's own head overflows
  // by 16 px at 185 px wide and its body by 449 px, with no chat involved.
  //
  // So the floor is the window this application actually opens at —
  // `gtk_window_set_default_size(window, 1280, 720)` in
  // `linux/runner/my_application.cc`, the same size `the_name_at_the_exit_test`
  // calls «every door on the glass». Measured, with the panel open: every
  // control of the chat is inside it and nothing overflows.
  testWidgets('at the window the app opens at, the chat is on the glass, acts and all',
      (tester) async {
    const floor = Size(1280, 720);
    final g = await _ready(tester, 'tight');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g, size: floor);

    for (final key in [TheChat.compose, TheChat.arrow, TheChat.copy, TheChat.add, TheChat.end]) {
      final it = find.byKey(key);
      expect(it, findsOneWidget, reason: 'a control of the chat is gone at $floor: $key');
      final r = tester.getRect(it);
      expect(r.right, lessThanOrEqualTo(floor.width),
          reason: 'it hangs off the window: $r ($key)');
      expect(r.bottom, lessThanOrEqualTo(floor.height),
          reason: 'it is below the glass: $r ($key)');
    }
    expect(overflows(tester), isEmpty, reason: 'the chat overflows at $floor');

    // **And the box «Add an answer» opens does not push its own act off the
    // glass.** The claim is `reviewJourney`'s, moved with the door: the
    // sheet's «Paste AI answer» opened a box at a 1280×720 window and that
    // journey measured that its footer stayed reachable. The box is at the
    // foot of the chat now, so the measurement is here.
    //
    // **With an answer really on the clipboard**, because the box reads it on
    // the press and fills to its own height: an empty clipboard opens a short
    // box and a sentence, which is the easy half of the shape. This is what a
    // person meets, and it is what found the 57 px the panel used to overflow
    // by with the three acts standing beside it.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': List.filled(9, 'Die Rechnung ist beglichen.').join('\n')}
          : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(TheChat.add));
    await settle(tester, rounds: 4);
    expect(find.byKey(TheChat.pasted), findsOneWidget,
        reason: '«Add an answer» opened no box');
    expect(tester.widget<TextField>(find.byKey(TheChat.pasted)).controller!.text,
        contains('beglichen'),
        reason: 'the box opened without what was on the clipboard');
    // The box, the writing above it, and the press that spends it: all three
    // inside the window, with the three acts given way to (they are measured
    // above, before the box opened).
    for (final key in [TheChat.pasted, TheChat.compose, TheChat.addIt]) {
      final it = find.byKey(key);
      expect(it, findsOneWidget, reason: 'the open box lost a control: $key');
      final r = tester.getRect(it);
      expect(r.bottom, lessThanOrEqualTo(floor.height),
          reason: 'the open paste box pushed a control below the glass: $r ($key)');
    }
    expect(overflows(tester), isEmpty,
        reason: 'the chat overflows at $floor with the paste box open');
  });

  // ------------------------------------------------------------------ guard 7
  //
  // **«End the chat» ends what the next question carries** — rule 68, and
  // nothing else: the turns stay in the session, and the columns stay on the
  // glass.
  // **Rule 71 reversed half of this guard on 18 October.** «The work is
  // untouched: the two columns are where they were» was the lead's B5 ruling
  // and the owner has taken it back — ending a chat empties the whole surface
  // now, and the emptying is the **shell's** act (`onFromZero`), which this
  // file does not mount. So what is measured here is the half that is this
  // panel's own: the press ends the chat in the core, asks nothing, closes the
  // panel, and keeps every turn in the session. That the surface then empties
  // is measured in `the_chat_from_the_first_moment_test`, against a harness
  // that can let a bench go the way the shell does.
  testWidgets('ending the chat asks nothing, ends it in the core, and keeps what was said',
      (tester) async {
    final g = await _ready(tester, 'end');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g);

    final was = g.bench.openChat;
    expect(was, greaterThan(0), reason: 'no chat was open, so ending one proves nothing');

    // **One press, and nothing asked** — 54-و: a confirmation whose two
    // answers differ in nothing a person would want back is work that does
    // not help. The turns stay in the session either way, which is the whole
    // reason there is no question here.
    await tester.tap(find.byKey(TheChat.end));
    await settle(tester, rounds: 10);
    expect(find.text('End this chat?'), findsNothing,
        reason: 'ending the chat asks a question that guards nothing');

    expect(find.byType(TheChat), findsNothing, reason: 'the panel stands over an ended chat');
    expect(g.bench.openChat, isNot(was), reason: 'the core still reports the same chat open');
    // The thread is empty on this bench, which is what the panel reads.
    expect(g.bench.chatTurns, isEmpty, reason: 'the ended chat still has turns on the bench');
    // And the session kept every turn of it — the Sessions room draws them
    // under the document they were about (rule 69).
    await tester.runAsync(() async {
      final open = await z.conversationOpen();
      final rows = await z.conversationTurns(number: open!, bench: g.bench.session);
      expect(rows, isNotEmpty, reason: 'ending the chat threw away what was said');
    });
  });
}

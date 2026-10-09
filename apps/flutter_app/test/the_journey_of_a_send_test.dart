// 064/E · The journey of a send: what left, what came back, what was kept.
//
// The owner's ruling, 9 October: the press takes the person to the chat screen,
// and there, in order — what was sent appears (the request in its safe
// clothing), the answer appears when it returns, and then the answer is
// **pulled inside**: unwrapped, shown restored, and written into the session.
//
// ## The rule inside the third step
//
// «The restored text is not shown before it is written» — the check and the act
// read one object. So the third step draws `Workbench.turn`, read back from the
// session's own file by `conversation_turns` and restored **inside the core**,
// and it cannot appear before the thing it is about exists. The two halves of
// this round meet exactly here: the other seat's write at `ingest_answer`, and
// this screen reading what it wrote.
//
// ## What this file measures that nothing else can
//
//   * the **stage sequence**, collected from the bench's own notifications
//     while one request runs: sent → answered → pulled in. A press cannot be
//     awaited under `testWidgets`, but a listener can record what the bench
//     said as it went;
//   * that the text in step one is **what travelled** — a token, never the
//     value — and that the text in step three is what the turn holds, with the
//     real value back in it;
//   * the fourth honest state: an answer that no session was open to keep, and
//     the sentence that says so rather than a blank.
//
// ## What no guard here holds, said rather than implied
//
// **That the press lands in the chat.** The workspace's AI door routes home
// when the sheet answers `true`, and `true` is returned only after the awaited
// core call — which does not resume under `testWidgets`, so the press cannot be
// followed to its end in any widget test in this app. What is measured instead
// is everything the landing shows: the three steps, their order on the glass,
// the text in each, and the sentence underneath. The one line between the press
// and the chat is read by eye, and it is one line for exactly that reason.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/the_journey.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _iban = 'DE02120300000000202051';
const _letter = 'Bitte überweisen Sie auf IBAN $_iban bis Freitag.';

/// What the fake model writes back — with the token in it, so the restoring has
/// something real to do. Filled in once the payload is known.
String _reply = 'Verstanden.';

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Future<({Ground ground, Workbench bench, List<String> bodies})> _ready(
  String name, {
  bool withASession = true,
  bool withAVault = true,
}) async {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-journey-$name-$pid');
  if (own.existsSync()) own.deleteSync(recursive: true);
  own.createSync(recursive: true);
  addTearDown(() {
    if (own.existsSync()) own.deleteSync(recursive: true);
  });
  final ground = Ground();
  await z.vaultLock();
  await z.setDataDir(dir: own.path);
  if (withAVault) {
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för resan');
  }
  final session = await z.openSession(profileId: null, packId: 'de');
  final bench = Workbench(session: session, profileId: null, packId: 'de');
  await z.importText(session: session, text: _letter);
  await bench.rescan();
  for (final f in bench.suggested) {
    await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
  }
  await bench.refresh();
  await ground.refresh();
  if (withASession) {
    final renamed = await ground.beginSession('Resan', bench: session);
    if (renamed == null) throw StateError('no session: ${ground.trouble}');
    await bench.refresh();
  }
  final bodies = <String>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    bodies.add(await utf8.decodeStream(req));
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': _reply},
          },
        ],
      }));
    await req.response.close();
  });
  await z.connectProvider(
    provider: const ProviderId(id: 'openai'),
    credential: 'sk-test-not-a-real-credential',
    baseUrl: 'http://127.0.0.1:${server.port}',
    model: 'the-configured-one',
  );
  await ground.refresh();
  addTearDown(() async {
    await server.close(force: true);
    await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
  });
  return (ground: ground, bench: bench, bodies: bodies);
}

/// The model's answer, written to carry the payload's own token back — which is
/// what gives the restoring something to put back.
String _answerCarrying(PayloadView payload) {
  final token = RegExp(r'__Z_[A-Za-z0-9_]+__').firstMatch(payload.text)?.group(0);
  if (token == null) throw StateError('the payload carries no token: ${payload.text}');
  return 'Die Zahlung an $token ist angewiesen.';
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  test('the three steps happen in order, and the third one is the written turn', () async {
    final g = await _ready('order');
    _reply = _answerCarrying(g.bench.payload!);

    // The bench's own account of where it got to, collected as it went: a
    // press cannot be awaited under `testWidgets`, and the order is the claim.
    final stages = <SendStage>[];
    void watch() {
      if (stages.isEmpty || stages.last != g.bench.stage) stages.add(g.bench.stage);
    }
    g.bench.addListener(watch);
    addTearDown(() => g.bench.removeListener(watch));

    final out = await beginThenAsk(g.ground, g.bench, name: '', providerId: 'openai');
    expect(out.refused, isNull, reason: 'the send was refused: ${out.refused}');

    expect(
      stages,
      [SendStage.sent, SendStage.answered, SendStage.pulledIn],
      reason: 'the journey did not happen in the owner’s order: $stages',
    );

    // Step one: what travelled. A token, and never the value.
    expect(g.bench.sentAsItLeft, isNotNull, reason: 'the bench does not keep what left');
    expect(g.bench.sentAsItLeft, contains('__Z_'), reason: 'what left carries no token');
    expect(g.bench.sentAsItLeft!.contains(_iban), isFalse, reason: 'the real IBAN is what left');
    expect(g.bodies.single, contains('__Z_'), reason: 'the wire carries no token');

    // Step three: the written turn, restored inside the core.
    final turn = g.bench.turn;
    expect(turn, isNotNull, reason: 'nothing was read back from the session’s file');
    final answer = turn!.answer.map((s) => s.text).join();
    expect(answer, contains(_iban),
        reason: 'the turn was not restored — the value never came back: $answer');
    expect(answer.contains('__Z_'), isFalse, reason: 'a raw token survived into the restored turn');
    // And it is the core's own marking that says which pieces were put back.
    expect(turn.answer.any((s) => s.piece == Piece.restored), isTrue,
        reason: 'no piece of the answer is marked as restored, so the colour would be Dart’s guess');
    expect(turn.unresolved, isEmpty, reason: 'this session minted the token it is reading back');
  });

  // ------------------------------------------------------------------ guard 2
  testWidgets('the chat draws the three steps, with the restored answer in the third',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final ({Ground ground, Workbench bench, List<String> bodies}) g;
    await tester.runAsync(() async {
      g = await _ready('glass');
      _reply = _answerCarrying(g.bench.payload!);
      final out = await beginThenAsk(g.ground, g.bench, name: '', providerId: 'openai');
      expect(out.refused, isNull, reason: 'the send was refused: ${out.refused}');
    });

    await tester.pumpWidget(MaterialApp(
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
    ));
    await _settle(tester);

    final band = find.byKey(TheJourney.band);
    expect(band, findsOneWidget, reason: 'the chat does not draw the journey at all');
    for (final step in [TheJourney.sent, TheJourney.answered, TheJourney.pulledIn]) {
      expect(find.byKey(step), findsOneWidget, reason: 'the journey is missing a step: $step');
    }
    // In the owner's order, on the glass and not only in the tree.
    final sent = tester.getRect(find.byKey(TheJourney.sent));
    final answered = tester.getRect(find.byKey(TheJourney.answered));
    final pulled = tester.getRect(find.byKey(TheJourney.pulledIn));
    expect(sent.top, lessThan(answered.top), reason: 'the answer is drawn above what was sent');
    expect(answered.top, lessThan(pulled.top), reason: 'the pulled-in step is above the answer');
    expect(pulled.bottom, lessThanOrEqualTo(1000), reason: 'the third step is off the glass: $pulled');

    // What was sent, readable after the fact — with the token, not the value.
    expect(
      find.descendant(of: find.byKey(TheJourney.sent), matching: find.textContaining('__Z_')),
      findsOneWidget,
      reason: 'the first step does not show the text that travelled',
    );
    // The restored value, in the third step, drawn from the written turn.
    expect(
      find.descendant(
        of: find.byKey(TheJourney.pulledIn),
        matching: find.textContaining(_iban, findRichText: true),
      ),
      findsOneWidget,
      reason: 'the third step does not show the restored answer the core wrote',
    );
    // The kept-sentence, in the form that is true while a session is open.
    expect(find.textContaining('This session keeps its conversation'), findsOneWidget,
        reason: 'the chat does not say what is kept while a session is open');
  });

  // ------------------------------------------------------------------ guard 3
  testWidgets('an answer no session could keep says so, and promises nothing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final ({Ground ground, Workbench bench, List<String> bodies}) g;
    await tester.runAsync(() async {
      // **No vault, which is the only state this send happens in** — and the
      // first form of this guard got that wrong: it locked the vault after
      // connecting, and the key is sealed *in* the vault, so the send came
      // back «No AI provider is connected» and the stage was `refused`. With
      // no vault the key is kept for this run only, the provider answers, and
      // no session can be born — which is the honest fourth state.
      g = await _ready('nokeep', withASession: false, withAVault: false);
      _reply = _answerCarrying(g.bench.payload!);
      final out = await beginThenAsk(g.ground, g.bench, name: '', providerId: 'openai');
      expect(out.refused, isNull, reason: 'the send was refused: ${out.refused}');
    });

    await tester.pumpWidget(MaterialApp(
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
    ));
    await _settle(tester);

    expect(g.bench.stage, SendStage.keptNowhere,
        reason: 'the bench claims a turn was kept with no session open: ${g.bench.stage}');
    expect(g.bench.turn, isNull, reason: 'a turn was read back from a session that does not exist');
    expect(
      find.descendant(
        of: find.byKey(TheJourney.pulledIn),
        matching: find.textContaining('no session is open to keep it'),
      ),
      findsOneWidget,
      reason: 'the third step does not say that nothing was kept',
    );
    expect(find.textContaining('No session is open — nothing of this conversation is kept'),
        findsOneWidget,
        reason: 'the chat’s own line still promises something about a conversation it does not keep');
    expect(find.textContaining('This session keeps its conversation'), findsNothing,
        reason: 'the chat promises a session is keeping this, with none open');
  });
}

// 064/A · The third exit — the door that sends through a key.
//
// The owner, on his own 9 October run: he met the name question on the review
// page, pressed a connected provider, the answer came back — and **no session
// was born and nothing was written into a conversation.** The two manual exits
// go through `beginThenRead`; this door went straight to the model. 064 was
// «the name is asked where the text leaves», and this is where the text
// actually leaves.
//
// ## The instrument: a fake provider that keeps the request body
//
// Every other guard of this feature measures what the app *holds* — the
// clipboard, a file, a rect. This one measures **what left the machine**: an
// `HttpServer` on loopback, connected as a provider's endpoint, keeping every
// request body it is given. A clipboard probe answers «what was copied»; this
// answers the question the product exists for. It is also the only instrument
// here that can tell a text built before the birth from one built after it,
// because both are «a payload» to everything on this side of the socket.
//
// ## What this file cannot measure
//
// **A widget that awaits the core does not resume under `testWidgets`** —
// written above `begin` in `a_session_is_a_room_in_the_panel_test.dart`, and a
// send is an awaited core call by its nature. So the order lives in
// `beginThenAsk`, out where a guard drives it, and the press above it is three
// lines with nothing in it to get wrong. The one press measured on the glass
// below is the press that **refuses**: it returns before the core is touched,
// so it completes.
//
// ## The boundary with the other seat
//
// Writing the turn — question, answer, time — into the session's file is the
// core's half, on `fix/the-send-door-writes-the-turn`: `ingest_answer` is the
// chokepoint every protected door ends at, `ask_model_directly` writes its own,
// and `conversation_turns(number:, bench:)` reads them back **restored inside
// the core**. Guard 6 pins today's truth rather than asserting the half that
// has not landed, and says in full what it becomes — so neither seat can think
// the other one did it.
//
// Its premise, though, is mine and is measured today: at the moment the send
// happens a session is open, because `record` refuses with «there is no session
// open to write to» and would write nothing, silently.
//
// ## Each guard watched red against its own break — and two of them did not
//
// Measured, not assumed, and the two that stayed green are the finding:
//
//   * **no birth at the door at all** (the state the owner met): guards 1, 3, 4,
//     5 and 6 go red. The sharp one is 3 — a nameless send reaches the model;
//   * **the post-birth `refresh` removed on its own**: everything stays
//     **green**, because `beginThenRead`'s look-again branch refreshes when the
//     view does not belong to the open session. The same shape 064 found for
//     the clipboard, and worth knowing before deleting a line that «nothing
//     tests»;
//   * **all three Dart layers removed** (refresh, look-again, the provenance
//     refusal): guard 1 goes red — and *not* with a pre-birth name on the wire.
//     The core refuses: «This request is no longer current. Review the text
//     again before sending.» A birth bumps the session's revision, which makes
//     the handle built before it stale, and `ask_model` takes a handle. So this
//     door has **four** layers and the clipboard has three: there the text is
//     taken from the view and no core call is left to refuse it. What the
//     refresh buys here is the person's send actually happening instead of a
//     refusal they would have to work out for themselves;
//   * **the empty-name check removed**: guard 3 stays **green**, because the
//     core refuses an empty session name as input (064e). What goes red is
//     guard 5 — the house sentence «Give it a name first» and the trip back to
//     the field are what the Dart check is for;
//   * **the door dead while the question stands**: guard 5, for the gate it
//     would make;
//   * **a birth at every press, open session or not**: guard 2 — a send inside
//     an open session refused for want of a name, which is asking a question
//     the owner's rule says was settled once.
//
// ## The fixture overlaps `the_name_at_the_exit_test.dart` on purpose
//
// `_ownDir` and the bench-with-a-vault are a second copy of that file's
// helpers, which are private to it. This one needs two things it does not — a
// connected provider and every finding answered — and the right home for the
// shared half is the `test/support/` this suite still does not have. Named as
// the same debt, not invented here.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/send_sheet.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _wide = Size(1200, 1000);

/// One value the general rules protect on their own, so «the name that must
/// never travel» is a single string to look for.
const _iban = 'DE02120300000000202051';
const _letter = 'Bitte überweisen Sie auf IBAN $_iban bis Freitag.';

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Directory _ownDir(String name) {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-third-$name-$pid');
  if (own.existsSync()) own.deleteSync(recursive: true);
  addTearDown(() {
    if (own.existsSync()) own.deleteSync(recursive: true);
  });
  return own;
}

/// A bench with a scanned, fully answered document, a vault, and a provider
/// whose endpoint is a server in this process.
///
/// `bodies` is what left the machine, in order.
Future<({Workbench bench, Ground ground, List<String> bodies})> _ready(
  String name, {
  String text = _letter,
}) async {
  final own = _ownDir(name);
  final ground = Ground();
  // **Lock first.** The core's vault state is global to the isolate, so a test
  // that ran earlier in this file's isolate can leave one unlocked — the leak
  // that cost `shell_test`'s `reviewJourney` its own premise on 9 October.
  await z.vaultLock();
  await z.setDataDir(dir: own.path);
  await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för tredje utgången');
  final session = await z.openSession(profileId: null, packId: 'de');
  final bench = Workbench(session: session, profileId: null, packId: 'de');
  await z.importText(session: session, text: text);
  await bench.rescan();
  // A send is gated on zero open suggestions and there is no «send anyway», so
  // answering is part of arriving at this door — and it is also what puts
  // tokens on the bench for a birth to rename.
  for (final f in bench.suggested) {
    await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
  }
  await bench.refresh();
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
            'message': {'role': 'assistant', 'content': 'Verstanden.'},
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
  return (bench: bench, ground: ground, bodies: bodies);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  test('a send through a key begins the session, and only its names travel', () async {
    final g = await _ready('wire');
    final before = g.bench.payload;
    expect(before, isNotNull, reason: 'no payload was built, so this guard measures nothing');
    final preBirth = g.bench.tokens.map((t) => t.token).toList();
    expect(preBirth, isNotEmpty, reason: 'nothing is protected, so there are no names to rename');
    expect(before!.text, contains(preBirth.first),
        reason: 'the payload does not carry the bench’s own tokens');
    expect(await z.conversationOpen(), isNull, reason: 'the fixture already opened a session');

    final out = await beginThenAsk(g.ground, g.bench, name: 'Mars', providerId: 'openai');

    expect(out.refused, isNull, reason: 'the send was refused: ${out.refused}');
    // The birth, read from the core rather than from the screen that asked for it.
    final rows = await z.conversations();
    expect(rows, hasLength(1), reason: 'the send through a key began no session');
    expect(await z.conversationOpen(), rows.single.number,
        reason: 'a session was born and not entered');
    expect(out.renamed, isNotNull, reason: 'no birth was reported to the press');
    expect(out.renamed, greaterThan(0), reason: 'the birth renamed nothing on a bench with tokens');
    // **The house's one wording, carrying the core's own number** — and it is
    // compared against `sessionBegunSaid` rather than against a string spelt
    // here, because a second wording of this sentence is the thing the
    // function exists to prevent. (It spells a one as «one», which is why a
    // `contains('1')` reading of it was wrong: measured, not assumed.)
    expect(out.said, sessionBegunSaid(out.renamed!, hadDocument: true),
        reason: 'the door wrote its own sentence instead of the house’s');

    // ---- what actually left the machine
    expect(g.bodies, hasLength(1), reason: 'the model was never contacted');
    final sent = g.bodies.single;
    final postBirth = g.bench.tokens.map((t) => t.token).toList();
    // **The control that gives the next assertion its meaning.** If a birth
    // renamed nothing, «no pre-birth name travelled» would be green over a
    // text that never changed. The two sets have to be different first.
    expect(postBirth.first, isNot(preBirth.first),
        reason: 'the birth did not rename the bench, so no reading below can tell the two texts apart');
    expect(sent, contains(postBirth.first),
        reason: 'what travelled wears neither the old names nor the new ones');
    for (final t in preBirth) {
      expect(sent.contains(t), isFalse,
          reason: 'the pre-birth name «$t» left the machine after the session was born');
    }
    // And the one that is the whole product: the value itself never travels.
    expect(sent.contains(_iban), isFalse, reason: 'the real IBAN left the machine');
  });

  // ------------------------------------------------------------------ guard 2
  test('a send inside an open session begins no second one, and asks no name', () async {
    final g = await _ready('open');
    final renamed = await g.ground.beginSession('Jupiter', bench: g.bench.session);
    expect(renamed, isNotNull, reason: 'the fixture could not begin a session: ${g.ground.trouble}');
    await g.bench.refresh();
    expect(g.ground.theSessionQuestionStands, isFalse,
        reason: 'the question still stands inside an open session');

    // **No name, and that is correct here**: the question is asked once, and
    // this session answered it. A door that asked again would be asking a
    // question the owner's rule says is settled.
    final out = await beginThenAsk(g.ground, g.bench, name: '', providerId: 'openai');

    expect(out.refused, isNull, reason: 'a send inside an open session was refused: ${out.refused}');
    expect(out.said, isNull, reason: 'the press was told a birth happened when none did');
    expect(out.renamed, isNull, reason: 'a number was reported for a birth that did not happen');
    expect(await z.conversations(), hasLength(1), reason: 'a second session was born at the door');
    expect(g.bodies, hasLength(1), reason: 'the model was never contacted');
    expect(g.bodies.single, contains(g.bench.tokens.first.token),
        reason: 'what travelled does not wear this session’s names');
  });

  // ------------------------------------------------------------------ guard 3
  test('a nameless send takes nothing out, and the zero has a one beside it', () async {
    final g = await _ready('noname');

    final out = await beginThenAsk(g.ground, g.bench, name: '   ', providerId: 'openai');

    expect(out.refused, isNotNull, reason: 'a nameless send was allowed');
    expect(out.refused, contains('name'), reason: 'the refusal does not say what is missing');
    expect(g.bodies, isEmpty, reason: 'a nameless send reached the model');
    expect(await z.conversations(), isEmpty, reason: 'a nameless send began a session anyway');

    // **The one beside the zero.** The same fixture, the same socket, one word
    // typed — and it travels. Without this, the empty `bodies` above could be
    // an instrument that never sees anything.
    final second = await beginThenAsk(g.ground, g.bench, name: 'Saturn', providerId: 'openai');
    expect(second.refused, isNull, reason: 'the named send was refused too: ${second.refused}');
    expect(g.bodies, hasLength(1),
        reason: 'nothing reaches this server at all, so the zero above measures nothing');
  });

  // ------------------------------------------------------------------ guard 4
  test('the direct door begins a session too, though the payload is not what leaves', () async {
    final g = await _ready('direct');
    // Direct Mode is a chosen thing, never automatic — `chooseOriginal` is the
    // only way into it, here as on the glass.
    g.bench.chooseOriginal(true);

    final out = await beginThenAsk(g.ground, g.bench, name: 'Neptun', providerId: 'openai');

    expect(out.refused, isNull, reason: 'the direct door was refused: ${out.refused}');
    expect(await z.conversations(), hasLength(1),
        reason: 'the direct door sent without beginning a session');
    expect(out.renamed, greaterThan(0), reason: 'the birth renamed nothing on a bench with tokens');
    // **No payload view, and that is the point of the parameter.** What leaves
    // here is the document as it stands; a helper that insisted on a payload
    // would refuse this door with «There is nothing to take out yet» on a
    // bench that has nothing to build.
    expect(out.view, isNull, reason: 'the direct door was handed a payload it does not send');
    expect(g.bodies, hasLength(1), reason: 'the model was never contacted');
    // Its own promise, and the reason it is a separate door with a separate
    // name in the core: the document travels as it stands, because a person
    // chose that. The session is still born — this door is an exit.
    expect(g.bodies.single, contains(_iban), reason: 'Direct Mode did not send the original');
  });

  // ------------------------------------------------------------------ guard 5
  testWidgets('the door is live while the question stands, and a nameless press sends nothing',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final ({Workbench bench, Ground ground, List<String> bodies}) g;
    await tester.runAsync(() async => g = await _ready('press'));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SendSheet(bench: g.bench, ground: g.ground)),
    ));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    // The label is the route and not the protocol, and loopback is «on this
    // computer», so the door is found by what every one of them starts with.
    final door = find.widgetWithText(ZButton, 'Send to Local AI');
    final anySend = door.evaluate().isEmpty
        ? find.widgetWithText(ZButton, 'Send to Direct API')
        : door;
    expect(anySend, findsOneWidget, reason: 'no send door on the page with a provider connected');
    // **It asks, it does not gate** — the same property the other two doors
    // have: live while the question stands.
    expect(tester.widget<ZButton>(anySend).onPressed, isNotNull,
        reason: 'the send door is dead while the question stands, so the question is a gate');

    await tester.tap(anySend);
    await _settle(tester);

    // Nothing left, and the person is standing where the missing word goes.
    expect(g.bodies, isEmpty, reason: 'a nameless press sent the text to the model');
    expect(find.byKey(SendSheet.theSessionBand), findsOneWidget,
        reason: 'the refused press left the person on the doors page, away from the field');
    expect(find.textContaining('Give it a name first'), findsOneWidget,
        reason: 'the refusal does not say what is missing, where it is missing');
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **The boundary, pinned to today's truth** — the other seat's half, named
  // rather than asserted. See `feedback_pin_the_fault_to_prove_the_fix`: a
  // guard that asserts the fix before the fix exists is a red line in a green
  // suite, and a guard that says nothing lets both halves believe the other
  // one did it.
  //
  // What is **mine** and holds today: a session is open at the moment the send
  // happens. That is the premise the core's write leans on —
  // `ops::conversation::record` refuses with «there is no session open to
  // write to», and would therefore write nothing, silently, for every send
  // from a sheet that forgot to begin one.
  //
  // What is **his** and is not here yet (`fix/the-send-door-writes-the-turn`):
  // `ingest_answer` writes the turn for every protected door, and
  // `ask_model_directly` writes its own. When that lands, this guard becomes:
  //
  //   * `row.turns` is 1, not 0;
  //   * `conversation_turns(number: row.number, bench: g.bench.session)` gives
  //     one row back, **restored inside the core** — never a raw turn on a
  //     screen, because a token in the middle of a model's sentence is the
  //     exact lie that cost the owner his trust in the restore path;
  //   * its `question` is '' here, and that is a real state and not a missing
  //     one: nothing was typed into the workspace's question field;
  //   * its `answer` carries «Verstanden.» — this fixture's own fake reply;
  //   * `unresolved` is a number that is said out loud, not hidden.
  test('a send with a newborn session leaves a conversation file with no turn in it — pinned', () async {
    final g = await _ready('turn');

    final out = await beginThenAsk(g.ground, g.bench, name: 'Merkur', providerId: 'openai');

    expect(out.refused, isNull, reason: 'the send was refused: ${out.refused}');
    expect(g.bodies, hasLength(1), reason: 'nothing was sent, so there is no turn to look for');
    final row = (await z.conversations()).single;
    // Mine, and the whole of what the other half needs from this one.
    expect(await z.conversationOpen(), row.number,
        reason: 'no session is open at the send, so the core’s write would be a silent zero');
    // His, pinned as it stands today. **This number is expected to flip to 1.**
    expect(row.turns, 0,
        reason: 'turns are being written already — if the core half has landed, this guard is '
            'the one that must change: read the turn back with conversation_turns and assert '
            'the question, the answer and the unresolved count');
  });
}

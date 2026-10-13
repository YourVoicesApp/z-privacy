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
// core's half: `ingest_answer` is the chokepoint every protected door ends at,
// `ask_model_directly` writes its own, and `conversation_turns(number:, bench:)`
// reads them back **restored inside the core**. Guard 6 was written as a **pin**
// while that half did not exist — it asserted the zero and spelt out what it
// would become — and it went red by itself in the first full run after the
// merge brought the write in. It asserts the turn now.
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
//   * **the birth-by-number removed** (081): guard 5 goes red. There is no
//     empty-name check left to remove — the owner took the refusal out on 13
//     Oct — and what stands in its place is `beginSessionItNames`, which is
//     what guard 5 now measures. The core still refuses an empty name as input
//     (064e), which is why the Dart side names it «Session» and renames it to
//     «Session N» rather than sending nothing;
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
  //
  // **081.** This asserted the refusal, and a zero with a one beside it to
  // prove the socket was real. The owner took the refusal out on 13 Oct, so
  // what is left to measure is the pair it becomes: a press with nothing typed
  // is named by the core's number, a press with a word is named by the word,
  // and **both travel**. Two fixtures rather than one, because the first press
  // now opens a session and a second press inside it begins nothing — which is
  // guard 2's property and would make this one measure the wrong thing.
  test('a nameless send is named by its number, and a named one by the word', () async {
    final g = await _ready('noname');

    final out = await beginThenAsk(g.ground, g.bench, name: '   ', providerId: 'openai');

    expect(out.refused, isNull, reason: 'a nameless send was refused: ${out.refused}');
    final rows = await z.conversations();
    expect(rows, hasLength(1), reason: 'a nameless send began no session');
    expect(rows.single.name, 'Session ${rows.single.number}',
        reason: 'a session nobody named carries «${rows.single.name}» instead of its '
            'own number, so the sessions list is a list of blanks');
    expect(g.bodies, hasLength(1), reason: 'the nameless send reached no model');
    expect(g.bodies.single.contains(_iban), isFalse, reason: 'the real IBAN left the machine');

    // **The one beside it**: the person's own word, kept as it was typed.
    final second = await _ready('noname-but-named');
    final named = await beginThenAsk(second.ground, second.bench, name: 'Saturn', providerId: 'openai');
    expect(named.refused, isNull, reason: 'the named send was refused: ${named.refused}');
    final namedRows = await z.conversations();
    expect(namedRows, hasLength(1), reason: 'the named send began no session');
    expect(namedRows.single.name, 'Saturn',
        reason: 'the word the person typed was replaced by a number');
    expect(second.bodies, hasLength(1), reason: 'the named send reached no model');
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
  //
  // **081 · the nameless press is no longer refused.** It asserted «nothing was
  // sent» and «Give it a name first», which was 064's rule; the owner replaced
  // it on 13 Oct, from the other side of it: a person who wants their text out
  // never came for the question, and a small line where their copy should have
  // been is a failure of the application to them. A session is born instead,
  // called «Session N» by the core's own number.
  //
  // The press is driven through `beginThenAsk` for the reason this whole file
  // exists: a send is an awaited core call, and a widget callback that awaits
  // the core does not resume under `testWidgets`. The tap below measures what a
  // tap can — that the door is live while the question stands.
  testWidgets('the door is live while the question stands, and a nameless press begins one',
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

    // **The press, with nothing in the field.** The provider is the one
    // `_ready` connected, and the door above is the same act.
    final preBirth = g.bench.tokens.map((t) => t.token).toList();
    expect(preBirth, isNotEmpty, reason: 'nothing is protected, so a birth renames nothing');
    final out = await tester.runAsync(
      () => beginThenAsk(g.ground, g.bench, name: '', providerId: 'openai'),
    );
    await _settle(tester);

    expect(out!.refused, isNull, reason: 'a nameless press was refused: ${out.refused}');
    final born = g.ground.openSession;
    expect(born, isNotNull,
        reason: 'the press neither began a session nor refused: ${g.ground.trouble}');
    expect(g.ground.openSessionRow?.name, 'Session $born',
        reason: 'a session nobody named must carry its own number as its name');
    expect(find.textContaining('Give it a name first'), findsNothing,
        reason: 'the refusal the owner met is still on the glass');

    // And the send happened, wearing the names of the session just born.
    expect(g.bodies, hasLength(1), reason: 'the model was never contacted');
    final sent = g.bodies.single;
    expect(sent.contains(_iban), isFalse, reason: 'the real IBAN left the machine');
    for (final t in preBirth) {
      expect(sent.contains(t), isFalse,
          reason: 'the pre-birth name «$t» left the machine after the session was born');
    }
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **The boundary, and the pin did its work.** This guard was written while
  // the core's half did not exist: it asserted today's truth — a newborn
  // session's file with **no** turn in it — and said in full what it would
  // become. The other seat's write landed in this tree at the merge, the pinned
  // number went red in the next full run, and nothing had to remember to come
  // back and look. That is the whole value of pinning a fault rather than
  // leaving a silence (`feedback_pin_the_fault_to_prove_the_fix`).
  //
  // What is **mine** and holds today: a session is open at the moment the send
  // happens. That is the premise the core's write leans on —
  // `ops::conversation::record` refuses with «there is no session open to
  // write to», and would therefore write nothing, silently, for every send
  // from a sheet that forgot to begin one.
  //
  // What is **his**: `ingest_answer` writes the turn for every protected door
  // and `ask_model_directly` writes its own, and `conversation_turns` reads
  // them back **restored inside the core** — never a raw turn on a screen,
  // because a token in the middle of a model's sentence is the exact lie that
  // cost the owner his trust in the restore path.
  test('a send with a newborn session writes its turn into that session\'s file', () async {
    final g = await _ready('turn');

    final out = await beginThenAsk(g.ground, g.bench, name: 'Merkur', providerId: 'openai');

    expect(out.refused, isNull, reason: 'the send was refused: ${out.refused}');
    expect(g.bodies, hasLength(1), reason: 'nothing was sent, so there is no turn to look for');
    final row = (await z.conversations()).single;
    // Mine, and the whole of what the other half needs from this one.
    expect(await z.conversationOpen(), row.number,
        reason: 'no session is open at the send, so the core’s write would be a silent zero');

    // His, now that it is here: one exchange, written into this session's own
    // file by the core, at the choke point every protected door ends at.
    expect(row.turns, 1, reason: 'the send wrote no turn into the session it had just begun');
    final turns = await z.conversationTurns(number: row.number, bench: g.bench.session);
    expect(turns, hasLength(1), reason: 'the file holds ${turns.length} turns for one send');
    final turn = turns.single;

    // **An empty question is a real state, not a missing one.** Nothing was
    // typed into the workspace's question field here, and the owner sent a
    // document with nothing asked of it hours before this round — which was
    // 046/N's whole finding. «Not written» and «lost» must not be spelt the
    // same, so this is asserted as empty rather than skipped.
    expect(turn.question.map((s) => s.text).join(), isEmpty,
        reason: 'a question was written into a turn where none was typed');
    // The answer, restored by the core. The fixture's fake provider says
    // «Verstanden.», and this payload's tokens do not appear in it — so there
    // is nothing to restore and nothing unresolved, which is itself the honest
    // reading of this send.
    expect(turn.answer.map((s) => s.text).join(), contains('Verstanden'),
        reason: 'the turn does not carry what the model said');
    expect(turn.unresolved, isEmpty,
        reason: 'tokens from another session appeared in an answer this one never sent');
    expect(turn.at.toInt(), greaterThan(0), reason: 'the turn carries no time');
  });
}

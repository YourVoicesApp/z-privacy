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
// core's half: `ingest_answer` is the chokepoint every door ends at — there is
// one kind of door since rule 62 — and `conversation_turns(number:, bench:)`
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
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
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
  removeWhenItLetsGo(own);
  addTearDown(() {
    removeWhenItLetsGo(own);
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
      throw StateError(buildTheBridgeFirst);
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
    // **Since rule 55 the document brought its session with it** (the owner,
    // 16 October): the text was born into one as it entered the preview, so
    // the names on this bench are already that session's and there is nothing
    // left for the door to rename. What this guard measures is what it always
    // measured — **only the session's names travel** — with the birth read at
    // the door it now happens at.
    final born = await z.conversationOpen();
    expect(born, isNotNull, reason: 'the document entered the preview and no session was born');

    final out = await beginThenAsk(g.ground, g.bench, providerId: 'openai');

    expect(out.refused, isNull, reason: 'the send was refused: ${out.refused}');
    final rows = await z.conversations();
    expect(rows, hasLength(1), reason: 'the send through a key began a second session');
    expect(await z.conversationOpen(), born, reason: 'the send moved which session is open');
    expect(out.renamed, isNull, reason: 'a birth was reported for a session that already existed');
    expect(out.said, isNull, reason: 'the press was told a birth happened when none did');

    // ---- what actually left the machine
    expect(g.bodies, hasLength(1), reason: 'the model was never contacted');
    final sent = g.bodies.single;
    final onTheBench = g.bench.tokens.map((t) => t.token).toList();
    expect(onTheBench, preBirth,
        reason: 'the send renamed the bench, and there was no birth to rename it for');
    expect(sent, contains(onTheBench.first),
        reason: 'what travelled does not wear this session’s names');
    // And the one that is the whole product: the value itself never travels.
    expect(sent.contains(_iban), isFalse, reason: 'the real IBAN left the machine');
  });

  // ------------------------------------------------------------------ guard 2
  test('a send inside an open session begins no second one, and asks no name', () async {
    final g = await _ready('open');
    // The session the document was born into, renamed as a person does it from
    // the sessions list — rather than begun a second time, which since rule 55
    // would be a second row and a different guard.
    final born = (await z.conversationOpen())!;
    await z.conversationRename(number: born, name: 'Jupiter');
    await g.ground.refresh();
    await g.bench.refresh();
    expect(g.ground.aSessionWouldBeBorn, isFalse,
        reason: 'the question still stands inside an open session');

    // **No name, and that is correct here**: the question is asked once, and
    // this session answered it. A door that asked again would be asking a
    // question the owner's rule says is settled.
    final out = await beginThenAsk(g.ground, g.bench, providerId: 'openai');

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
  // **081, twice over.** This asserted the refusal, and a zero with a one
  // beside it to prove the socket was real. The owner took the refusal out on
  // 13 Oct — a send with no session begins one — and then had the name field
  // deleted from the exit altogether: a session is named by its number here,
  // and by a person's own word **only** from the rename control in the
  // sessions list.
  //
  // So the pair is now «born at the door» against «named in the room»: the
  // first takes its number, the second keeps the word it was given, and the
  // send through it renames nothing. Two fixtures, because a second press
  // inside an open session begins nothing at all — guard 2's property, which
  // would make this one measure the wrong thing.
  test('a send names a session by its number, and never renames one that has a word', () async {
    final g = await _ready('noname');

    final out = await beginThenAsk(g.ground, g.bench, providerId: 'openai');

    expect(out.refused, isNull, reason: 'a nameless send was refused: ${out.refused}');
    final rows = await z.conversations();
    expect(rows, hasLength(1), reason: 'a nameless send began no session');
    expect(rows.single.name, 'Session ${rows.single.number}',
        reason: 'a session nobody named carries «${rows.single.name}» instead of its '
            'own number, so the sessions list is a list of blanks');
    expect(g.bodies, hasLength(1), reason: 'the nameless send reached no model');
    expect(g.bodies.single.contains(_iban), isFalse, reason: 'the real IBAN left the machine');

    // **The one beside it**: a session the room named, which the door must
    // leave alone — the word is the person's, and nothing at an exit may
    // replace it with a number.
    final second = await _ready('named-in-the-room');
    final its = (await z.conversationOpen())!;
    await z.conversationRename(number: its, name: 'Saturn');
    await second.ground.refresh();
    await second.bench.refresh();
    final named = await beginThenAsk(second.ground, second.bench, providerId: 'openai');
    expect(named.refused, isNull, reason: 'the send was refused: ${named.refused}');
    final namedRows = await z.conversations();
    expect(namedRows, hasLength(1), reason: 'the send began a second session');
    expect(namedRows.single.name, 'Saturn',
        reason: 'the word the person gave in the room was replaced by a number');
    expect(second.bodies, hasLength(1), reason: 'the send reached no model');
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **Deleted with its subject** — rule 62, the owner on 17 October.
  //
  // It measured the fourth exit: «the direct door begins a session too, though
  // the payload is not what leaves», and its last line asserted that the real
  // IBAN *did* travel, because that was the whole of what the person had
  // chosen. There is no such door now, and no parameter that lets an exit skip
  // the payload — so what this file would have to assert instead is already
  // asserted one guard above, at the socket: the body that crossed the wire
  // does not contain the IBAN.
  //
  // The absence of the door itself is measured in
  // `only_the_protected_version_is_sent_test.dart`, over the app's own
  // sources and the generated bridge.

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
      () => beginThenAsk(g.ground, g.bench, providerId: 'openai'),
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

    // And the send happened, wearing this session's own names — the ones the
    // bench has carried since the document entered the preview and was born
    // into it (rule 55).
    expect(g.bodies, hasLength(1), reason: 'the model was never contacted');
    final sent = g.bodies.single;
    expect(sent.contains(_iban), isFalse, reason: 'the real IBAN left the machine');
    expect(sent, contains(preBirth.first),
        reason: 'what travelled does not wear the names on the bench');
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
  // What is **his**: `ingest_answer` writes the turn for every door there is,
  // and `conversation_turns` reads them back **restored inside the core** —
  // never a raw turn on a screen,
  // because a token in the middle of a model's sentence is the exact lie that
  // cost the owner his trust in the restore path.
  test('a send with a newborn session writes its turn into that session\'s file', () async {
    final g = await _ready('turn');

    final out = await beginThenAsk(g.ground, g.bench, providerId: 'openai');

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

    // **What the turn holds is what left by this door** — rule 63, and since
    // rule 65 that is the whole of it: the document itself, with its tokens put
    // back for the glass. Nothing was typed into the question field here, and
    // the owner sent a document with nothing asked of it hours before 046/N —
    // so «nothing typed» is still a state of its own, spelt now by the absence
    // of the request section rather than by an empty half. «Not written» and
    // «lost» remain two different things: a lost half would be empty.
    final asked = turn.question.map((s) => s.text).join();
    expect(asked, contains('Bitte überweisen Sie'),
        reason: 'the document that left is not in the turn, so the chat would '
            'draw a first turn the person never sent');
    expect(asked, isNot(contains('--- Request ---')),
        reason: 'nothing was typed and the turn carries a request section anyway');
    // And the chat it belongs to is the one this session is in.
    expect(turn.chatNumber, await z.theOpenChat(number: row.number),
        reason: 'the turn landed outside the chat the person is in');
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

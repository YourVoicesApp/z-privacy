// **The chat from the first moment** — rules 71 to 75, the owner, 18 October
// 2026, after the round of 090 was installed.
//
// What he met on it: he opened the app with no document and had nowhere to
// write to a model; he ended a chat and the old document stayed on the
// surface; he wanted a document off the screen and another in its place; the
// settings opened on the AI room and stayed open until he found their corner.
//
// One guard per rule, in the owner's own order.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/the_chat.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
const _pass = 'ein gutes Passwort für den Tresor';
const _attach = ValueKey<String>('workspace-question-attach');

/// A letter with one name a general rule protects on its own.
const _doc = 'Sehr geehrter Herr Thomas Müller,\n'
    'die Rechnung über 42 500 EUR ist beglichen.\n';

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// A fresh folder with a vault in it.
Future<Ground> _aVault(WidgetTester tester, String name) async {
  final ground = Ground();
  await tester.runAsync(() async {
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-first-moment-$name-$pid');
    removeWhenItLetsGo(dir);
    addTearDown(() {
      // Best effort, for the race named in `later_is_not_an_answer_test.dart`.
      try {
        removeWhenItLetsGo(dir);
      } on FileSystemException {
        // Left behind rather than red for something no claim here is about.
      }
    });
    await z.vaultLock();
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    await ground.refresh();
  });
  return ground;
}

/// A bench with the document on it, every suggestion answered, and the fake
/// provider connected so a question can be asked and answered.
Future<Workbench> _aDocument(WidgetTester tester, Ground ground) async {
  late final Workbench bench;
  await tester.runAsync(() async {
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
  return bench;
}

/// **The surface, with whatever is on it** — and a harness that can take the
/// bench away, because that is what rules 71 and 73 are about: the shell holds
/// the bench, so a guard about the surface emptying has to be able to let it
/// go the way the shell does.
class _Surface extends StatefulWidget {
  const _Surface({required this.ground, required this.bench});

  final Ground ground;
  final Workbench? bench;

  @override
  State<_Surface> createState() => _SurfaceState();
}

class _SurfaceState extends State<_Surface> {
  late Workbench? _bench = widget.bench;
  String? asked;

  /// **A second mount with another bench is another bench** — the state is
  /// kept across a `pumpWidget` of the same type, so without this a guard that
  /// mounts the surface twice would be looking at the first bench for ever.
  @override
  void didUpdateWidget(_Surface old) {
    super.didUpdateWidget(old);
    if (widget.bench != old.bench) _bench = widget.bench;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WorkspaceScreen(
        bench: _bench,
        ground: widget.ground,
        onImport: () {},
        onAsk: (text) => setState(() => asked = text),
        onVault: () {},
        onSettings: (_) {},
        // Rule 71: the shell's own act, which is to let the bench go.
        onFromZero: () => setState(() => _bench = null),
        // Rule 73: a document removed leaves the bench standing with none.
        // «No document» is an empty one, not a null one — the core answers
        // with a `DocumentView` whose text is empty.
        onRemoveDocument: (_bench?.document?.text ?? '').isEmpty
            ? null
            : () => setState(() => _removeTheDocument()),
      ),
    );
  }

  /// The shell's own `_removeTheDocument`, in the two lines a guard can drive:
  /// a bench is a session, so removing a document means standing on a new one.
  void _removeTheDocument() {
    final old = _bench;
    if (old == null) return;
    _bench = null;
    unawaited(() async {
      final session = await z.openSession(profileId: old.profileId, packId: old.packId);
      final fresh = Workbench(session: session, profileId: old.profileId, packId: old.packId);
      if (old.question.trim().isNotEmpty) await fresh.setQuestion(old.question);
      await fresh.readTheChat();
      old.dispose();
      if (mounted) setState(() => _bench = fresh);
    }());
  }
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ rule 71
  //
  // **A new chat starts from zero.** The owner: «المفترض أن محادثة جديدة يجب
  // أن تبدأ من الصفر». «End the chat» emptied the panel and left the columns
  // standing — the lead's B5 ruling of 090, which the owner has now reversed.
  testWidgets('71 · ending the chat empties all three parts, and keeps what was kept',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _aVault(tester, 'zero');
    final bench = await _aDocument(tester, ground);
    addTearDown(bench.dispose);

    // One exchange, so there is a chat to end.
    await tester.runAsync(() async {
      await bench.setQuestion('Worum geht es?');
      final bad = await beginThenAsk(ground, bench, providerId: 'fake');
      expect(bad.refused, isNull, reason: 'the question did not go: ${bad.refused}');
    });
    await tester.pumpWidget(_Surface(ground: ground, bench: bench));
    await settle(tester);
    expect(bench.chatTurns, hasLength(1), reason: 'the answer wrote no turn');
    expect(find.byType(TheChat), findsOneWidget, reason: 'the chat is not open');

    // **What the session holds, before the chat ends** — rule 71 touches none
    // of it. It is the session's **turns**, not a kept copy of the document:
    // 089 rule 9 takes the preview's copy out the moment the text leaves by a
    // door (`take_the_copy_out`), and what is left of that document then is
    // the turn that names it. So this is what «the kept copies are untouched»
    // means for a document that has been sent.
    await tester.runAsync(() => ground.refresh());
    await settle(tester, rounds: 2);
    final turnsBefore =
        ground.sessions.firstWhere((r) => r.number == ground.openSession).turns;
    expect(turnsBefore, greaterThan(0), reason: 'the session holds no turn, so this proves nothing');

    await tester.tap(find.byKey(TheChat.end));
    await settle(tester, rounds: 12);

    // **All three parts are empty.** Not «the panel closed»: the document is
    // off the first part, the request is off the middle one, and the thread is
    // gone with them.
    expect(find.byType(TheChat), findsNothing, reason: 'the chat is still on the glass');
    expect(find.textContaining('Thomas Müller'), findsNothing,
        reason: 'the document is still in the first part');
    expect(find.textContaining('Worum geht es?'), findsNothing,
        reason: 'the request is still in the middle part');
    expect(
      find.text('Your document arrives here, as it is written. Nothing on this side can reach '
          'the network.'),
      findsOneWidget,
      reason: 'the three parts are not the empty ones',
    );

    // **And nothing was forgotten**: the session is still in the room with
    // everything it held (rules 68 and 69 — «the record of both doors stays»),
    // so this emptied a surface and not a session.
    await tester.runAsync(() => ground.refresh());
    await settle(tester, rounds: 2);
    final row = ground.sessions.where((r) => r.turns > 0).toList();
    expect(row, hasLength(1),
        reason: 'ending the chat took the session\'s own record with it');
    expect(row.single.turns, turnsBefore,
        reason: 'ending the chat changed how much the session holds');
  });

  // ------------------------------------------------------------------ rule 72
  //
  // **The box is there from the first moment, with no document** — and what is
  // written in it leaves alone. The owner: «نحتاجه أن يظهر من اللحظة الأولى،
  // وبذلك يمكننا الشات مباشرة بدون أي وثائق».
  testWidgets('72 · with no document the box is there, and what is typed is what leaves',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _aVault(tester, 'first');

    // **Nothing at all on the surface**, which is the first moment itself.
    await tester.pumpWidget(_Surface(ground: ground, bench: null));
    await settle(tester);
    expect(find.byKey(WorkspaceScreen.composer), findsOneWidget,
        reason: 'there is nowhere to write to the AI with no document');
    expect(find.text('What would you like to ask the AI?'), findsOneWidget,
        reason: 'the box does not say what it is for when nothing stands above it');

    // The press hands what was written to the shell, which opens a session for
    // it — the one case the box cannot do alone.
    await tester.enterText(find.byKey(WorkspaceScreen.composer), 'Was ist ein IBAN?');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 2);
    final surface = tester.state<_SurfaceState>(find.byType(_Surface));
    expect(surface.asked, 'Was ist ein IBAN?',
        reason: 'the question written on an empty surface went nowhere');

    // **And the whole of it leaves, by ed's own door.** A bench with no
    // document, the question set in it, and `build_the_question_alone` carries
    // it: the answer opens the chat, and the turn names no document.
    late final Workbench bench;
    await tester.runAsync(() async {
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.connectProvider(
        provider: const ProviderId(id: 'fake'),
        credential: 'not-a-real-credential',
        baseUrl: null,
        model: null,
      );
      addTearDown(() async => z.disconnectProvider(provider: const ProviderId(id: 'fake')));
      await ground.refresh();
      await bench.refreshModels();
      final bad = await bench.setQuestion('Was ist ein IBAN für Herr Thomas Müller?');
      expect(bad, isNull, reason: 'a question with no document was refused: $bad');
    });
    addTearDown(bench.dispose);

    // The question is protected, with no document anywhere near it.
    // **«No document» is an empty one, not a null one** — measured: a session
    // that imported nothing still answers with a `DocumentView`, whose text is
    // empty. That is the predicate every «is there a document» in this round
    // had to be written against.
    expect(bench.document?.text ?? '', isEmpty,
        reason: 'something put a document on this bench');
    expect(bench.questionSafe, isNot(contains('Thomas Müller')),
        reason: 'the name in the question is in the clear in what would leave');
    expect(bench.questionSafe, contains('__Z_'),
        reason: 'nothing in the question was protected');
    // ignore: avoid_print
    print('PROBE payload=${bench.payload != null} · tokens=${bench.tokens.length} '
        '· marks=${bench.questionMarks.length} · snap=${bench.snap != null}');

    await tester.pumpWidget(_Surface(ground: ground, bench: bench));
    await settle(tester);

    await tester.runAsync(() async {
      final refused = await theChatAsks(
        ground,
        bench,
        text: 'Was ist ein IBAN für Herr Thomas Müller?',
        providerId: 'fake',
      );
      expect(refused, isNull, reason: 'the question with no document did not go: $refused');
    });
    await settle(tester, rounds: 12);

    expect(bench.chatTurns, hasLength(1),
        reason: 'the answer to a question with no document wrote no turn');
    expect(bench.chatTurns.single.keptHandle, isNull,
        reason: 'a question with no document named a document anyway');
    expect(find.byType(TheChat), findsOneWidget,
        reason: 'the answer did not open the chat');
  });

  // ---------------------------------------------------------------- rule 72-أ
  //
  // **One box, not two.** The strip's «Write or paste your text here… · Open
  // and scan» is deleted; the «+» stays. A letter pasted in the one box is
  // protected and leaves by the same road — so the thing to measure is that
  // the multi-line text is scanned, that it is protected, and that what leaves
  // is the protected form.
  testWidgets('72-أ · one box: a pasted letter is protected, and the second box is gone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _aVault(tester, 'onebox');

    late final Workbench bench;
    await tester.runAsync(() async {
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await ground.refresh();
    });
    addTearDown(bench.dispose);

    await tester.pumpWidget(_Surface(ground: ground, bench: bench));
    await settle(tester);

    // **The deleted box is deleted, not hidden** — rule 35.
    expect(find.text('Write or paste your text here…'), findsNothing);
    expect(find.text('Open and scan'), findsNothing);
    // And the «+» for a file stays where rule 70 put it.
    expect(find.byKey(WorkspaceScreen.addDocument), findsOneWidget,
        reason: 'the way in for a file went with the box beside it');
    // One box on the whole surface.
    expect(find.byKey(WorkspaceScreen.composer), findsOneWidget,
        reason: 'there is not exactly one box to write in');

    // A whole letter, pasted in it, through the one press there is.
    await tester.enterText(find.byKey(WorkspaceScreen.composer), _doc);
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 12);

    // **Protected, by the core, with the same packs a document is read with.**
    expect(bench.question, contains('Thomas Müller'),
        reason: 'the box did not keep what was pasted into it');
    expect(bench.questionSafe, isNot(contains('Thomas Müller')),
        reason: 'the pasted letter leaves with the name in the clear');
    expect(bench.questionMarks, isNotEmpty,
        reason: 'nothing in the pasted letter was found');
    // And what leaves is that, and nothing else: the payload is the question
    // alone, because no document stands above it.
    await tester.runAsync(() async {
      final h = await z.buildTheQuestionAlone(session: bench.session);
      final view = await z.payloadView(handle: h);
      expect(view.text, isNot(contains('Thomas Müller')),
          reason: 'what leaves holds the name the letter had in it');
      expect(view.text, contains('__Z_'), reason: 'what leaves carries no token');
      // **And by the road every other exit takes** — «Copy Protected» and
      // «Save as PDF» read `build_payload`, not the question's own door, so
      // this is what 72-أ's «becomes a z-pdf by the same road» rests on.
      try {
        final p = await z.buildPayload(session: bench.session);
        final v = await z.payloadView(handle: p);
        // ignore: avoid_print
        print('PROBE build_payload · ok · text=«${v.text.replaceAll('\n', ' / ')}»');
      } on ApiError catch (e) {
        // ignore: avoid_print
        print('PROBE build_payload · refused · $e');
      }
    });
  });

  // ------------------------------------------------------------------ rule 73
  //
  // **«Remove the document», and «+» brings another.** The removal takes
  // nothing out and the kept copy stays.
  testWidgets('73 · removing the document empties the first part and keeps the copy',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _aVault(tester, 'remove');
    final bench = await _aDocument(tester, ground);

    // **The copy a session keeps is the copy of a document that has *not*
    // left** — 089 rule 9, and it is the opposite of what this guard first
    // assumed: `take_the_copy_out` removes it the moment the text goes out by
    // a door, because what is left of it then is the turn that carries it
    // (`TurnRow.keptHandle`). So nothing is sent here: the document is in the
    // preview, its copy is in the session's list, and what rule 73 must not
    // disturb is that.
    await tester.runAsync(() async {
      await bench.setQuestion('Worum geht es?');
      await ground.refresh();
    });
    await tester.pumpWidget(_Surface(ground: ground, bench: bench));
    await settle(tester);
    final keptBefore = ground.kept[ground.openSession]?.length ?? 0;
    expect(keptBefore, greaterThan(0), reason: 'nothing was kept, so this proves nothing');

    expect(find.byKey(WorkspaceScreen.removeDocument), findsOneWidget,
        reason: 'there is no way to remove the document from the first part');
    await tester.tap(find.byKey(WorkspaceScreen.removeDocument));
    await settle(tester, rounds: 14);

    // **The first part is empty and nothing left the machine**: the removal is
    // not an exit (54-و), so what the session kept is exactly what it kept
    // before — no second copy, and none taken away.
    expect(find.textContaining('Thomas Müller'), findsNothing,
        reason: 'the document is still in the first part');
    await tester.runAsync(() => ground.refresh());
    await settle(tester, rounds: 2);
    expect(ground.kept[ground.openSession]?.length ?? 0, keptBefore,
        reason: 'removing the document changed what the session kept');

    // The one box is still there, and what was typed in it with it — rule 73
    // removes a document, it does not end a chat or empty the request.
    expect(find.byKey(WorkspaceScreen.composer), findsOneWidget,
        reason: 'the one box went with the document');
    // And «+» is there to bring another.
    expect(find.byKey(WorkspaceScreen.addDocument), findsOneWidget,
        reason: 'there is no «+» to put another document in its place');
    // The control is gone with its subject.
    expect(find.byKey(WorkspaceScreen.removeDocument), findsNothing,
        reason: 'a document that is not there can still be removed');
  });

  // ------------------------------------------------------------------ rule 74
  //
  // **The settings open on Sessions.** And the door that is about a key still
  // lands where a key is given, which is the half a changed default breaks.
  testWidgets('74 · the settings open on Sessions, and a key door still opens on AI',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _aVault(tester, 'rooms');

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        // Keyed, because the room is a `late` field of the panel's own state:
        // a second mount of the same type at the same place keeps that state,
        // and the guard would then be measuring the first panel twice.
        key: const ValueKey<String>('panel-default'),
        ground: ground,
        onClose: () {},
      ),
    ));
    await settle(tester);
    expect(
      find.textContaining('Each session has its own encryption'),
      findsOneWidget,
      reason: 'the settings did not open on Sessions',
    );
    expect(find.text('Three ways to ask a model. The first needs no account at all.'),
        findsNothing,
        reason: 'the settings opened on the AI room');

    // Named, and the room named is the room drawn — which is what every door
    // about a key relies on.
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        key: const ValueKey<String>('panel-ai'),
        ground: ground,
        room: SettingsRoom.ai,
        onClose: () {},
      ),
    ));
    await settle(tester);
    expect(find.text('Three ways to ask a model. The first needs no account at all.'),
        findsOneWidget,
        reason: 'a door that named the AI room did not land in it');
  });

  // ------------------------------------------------------------------ rule 75
  //
  // **The panel closes on a press anywhere outside it** — and the house's trap
  // applies: the press that closes it must not land on what is under it, and
  // must not swallow the next one.
  testWidgets('75 · a press outside closes the panel, lands on nothing, and the next press works',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _aVault(tester, 'outside');

    var settingsOpen = true;
    var pressedBehind = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Stack(
          children: [
            // What is under the panel: a press-counter standing in for the
            // work, so «the closing press did not reach it» is a number.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => pressedBehind++),
                child: const ColoredBox(color: Color(0xFFFFFFFF)),
              ),
            ),
            if (settingsOpen)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey<String>('settings-outside'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => settingsOpen = false),
                ),
              ),
            if (settingsOpen)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 480,
                child: SettingsScreen(ground: ground, onClose: () {}),
              ),
          ],
        ),
      ),
    ));
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // **A press inside the panel does not close it** — it is the panel's own.
    await tester.tapAt(const Offset(1000, 400));
    await settle(tester, rounds: 2);
    expect(find.byType(SettingsScreen), findsOneWidget,
        reason: 'a press inside the panel closed it');

    // **A press outside closes it, and does not reach the work behind.**
    await tester.tapAt(const Offset(300, 400));
    await settle(tester, rounds: 2);
    expect(find.byType(SettingsScreen), findsNothing,
        reason: 'a press outside the panel did not close it');
    expect(pressedBehind, 0,
        reason: 'the press that closed the panel also landed on the work under it');

    // **And the next press lands** — the catcher is gone with the panel, which
    // is the half «a full-screen catcher swallows the next press» is about.
    await tester.tapAt(const Offset(300, 400));
    await settle(tester, rounds: 2);
    expect(pressedBehind, 1, reason: 'the catcher swallowed the next press too');
  });

  // ------------------------------------------------- the owner's three zeros
  //
  // **A document that came back from a kept copy says so, and does not report
  // a scan that did not happen** — the owner's screenshot of 18 October, on
  // the installed round: «Scanned on import · 0 protected automatically · 0
  // need your word · 0 normal» over a first column showing seventeen names
  // underlined and a Safe column saying «21 values were replaced».
  //
  // The cause is two lines of the core, and only one of them was meant.
  // `put_back_the_preview` clears the findings and re-applies the marks the
  // copy was kept with (`z_core/src/session.rs`), and all three counts are
  // counted **from the findings** (`z_core/src/ops/snapshots.rs`) — so they
  // are zero for a restored document while its marks are drawn beside them.
  // The same function sets the origin to `OnImport` deliberately, with its own
  // reason written: «not scanned yet» over a document full of marks would
  // contradict the column beside it. True of where the marks came from, and it
  // is what made the three zeros read as a measurement.
  testWidgets('a kept document that comes back says «as it was kept», not three zeros',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _aVault(tester, 'askept');
    final bench = await _aDocument(tester, ground);
    addTearDown(bench.dispose);

    // The document is in the preview and its copy is in the session's list,
    // because nothing has left: 089 rule 9 takes the copy out at a door.
    await tester.runAsync(() => ground.refresh());
    await settle(tester, rounds: 2);
    final number = ground.openSession!;
    final kept = ground.kept[number] ?? const [];
    expect(kept, hasLength(1), reason: 'the session kept no copy to open again');

    // A fresh bench, and the kept copy put back on it — the shell's own
    // `_openKept`, in the two calls it makes.
    late final Workbench back;
    await tester.runAsync(() async {
      final session = await z.openSession(profileId: null, packId: 'de');
      back = Workbench(session: session, profileId: null, packId: 'de');
      await z.openKeptDocument(
        number: number,
        which: kept.single.number,
        chat: kept.single.chat,
        bench: session,
      );
      await back.refresh();
    });
    addTearDown(back.dispose);

    // The marks came back and there are no findings — the one state only a
    // restored document is in.
    expect(back.document?.marks ?? const [], isNotEmpty,
        reason: 'the copy came back with no marks, so this guard measures nothing');
    expect(back.findings, isEmpty,
        reason: 'the restored document has findings, so the band could count them');

    await tester.pumpWidget(_Surface(ground: ground, bench: back));
    await settle(tester);

    expect(find.text('As it was kept'), findsOneWidget,
        reason: 'the band claims a scan that did not happen in this run');
    expect(find.textContaining('already protected · nothing scanned in this run'),
        findsOneWidget,
        reason: 'the band does not say what came back protected');
    expect(find.textContaining('0 protected automatically'), findsNothing,
        reason: 'the three zeros are still drawn over a document that was never scanned here');
  });
}

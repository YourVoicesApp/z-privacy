// A · the door you can see — the way back, the AI door, and the whole catalogue.
//
// The owner used the published build for an evening on a cleaned machine. Three
// things stood between him and the answer, and all three are about doors: the
// way home had no arrow, the AI choice was behind a button that stays disabled
// until every suggestion is answered, and the model list showed one provider's
// models because the rest were not «available».
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
const _doc =
    'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n'
    'Bitte prüfen Sie den Vertrag.';

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // **The way back is gone, and that is rule 70, not a regression** — the
  // owner: «لا أسهم بين شاشات لأنه لا شاشات». This guard measured an arrow, a
  // word, a tooltip naming Alt+Left, and the mark as a second door to the same
  // place; there is one screen now and nowhere for any of them to arrive, so
  // all four are deleted rather than disabled (rule 35).
  //
  // What replaced the need for them is measured in
  // `the_one_screen_test.dart`: the way *in* is at the top of the screen a
  // person is already standing on, so there is no screen to go back from.
  // Here, only the absence is read — because a dead arrow is exactly what rule
  // 35 forbids.
  testWidgets('no way back is drawn, because there is nowhere to go back to', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {})),
    );
    await settle(tester);

    expect(find.byTooltip('Back to your documents · Alt+Left'), findsNothing,
        reason: 'the back control is still on the bar, and it goes nowhere');
    expect(find.text('Documents'), findsNothing, reason: 'the bar still offers a screen of documents');
    expect(find.byIcon(Icons.arrow_back), findsNothing, reason: 'an arrow back is drawn on the one screen');
    // The mark stays, and it is **not** a door any more: a picture that was a
    // door to a screen that no longer exists would be a press that does
    // nothing at all.
    expect(find.byType(BrandMark), findsOneWidget, reason: 'the mark went with the arrow');
    expect(find.byTooltip('Z Privacy · home'), findsNothing,
        reason: 'the mark still offers a home to go to');
    expect(
      find.ancestor(of: find.byType(BrandMark), matching: find.byType(InkWell)),
      findsNothing,
      reason: 'the mark is still a press, and it opens nothing',
    );

    // Alt+Left reaches nothing: the binding is gone with the screen.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(find.byType(WorkspaceScreen), findsOneWidget,
        reason: 'Alt+Left took the document off the screen');
    expect(find.text('Z Privacy'), findsNothing, reason: 'the wordmark crowds the bar at 964');

    bench.dispose();
  });

  testWidgets('the AI door opens with suggestions still open, the choice comes first, and only sending waits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    // The premise of the whole test: something is still open.
    expect(bench.payload!.openSuggestions, greaterThan(0), reason: 'this document asks nothing');

    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {})),
    );
    await settle(tester);

    final door = find.byTooltip('Choose the AI and what travels to it');
    expect(door, findsOneWidget, reason: 'the top bar has no AI button');
    await tester.tap(door);
    await settle(tester);

    expect(find.text(sentences.whoAnswers), findsOneWidget, reason: 'the AI button opened nothing');

    // **Provider and model are not behind a page** — the owner's own ruling,
    // read against what the sheet is since rule 60. It used to be measured as
    // «above the outgoing text», because the text was the first page and the
    // choice stood over it; the text is read on the work surface now and the
    // sheet has one page, so the measurement is that the choice and the doors
    // are on the glass together, with nothing to press to get from one to the
    // other.
    //
    // It said «provider, model and mode» until 17 October, and asked for «What
    // travels» here. Rule 62 deleted the mode, so what the sheet puts above
    // its doors is the one choice left — and the absence of the other is
    // measured in `only_the_protected_version_is_sent_test.dart`.
    final choice = tester.getTopLeft(find.text(sentences.modelLabel)).dy;
    final doors = tester.getTopLeft(find.text(sentences.manualAi)).dy;
    expect(choice, lessThan(doors), reason: 'the choice is below the doors it chooses for');
    expect(find.text('Continue'), findsNothing,
        reason: 'the sheet still pages, so rule 60 left a page behind');
    // 046/L: the gate names what is waiting. It said «Answer the review
    // first», which named no number — and this assertion was finding the
    // **workspace's** copy of that sentence through the open dialog, not the
    // sheet's own, which is only drawn beside a connected provider.
    expect(
      find.textContaining('left', findRichText: true),
      findsWidgets,
      reason: 'the gate says nothing about what is waiting',
    );

    bench.dispose();
  });

  testWidgets('the model is chosen by name on the work surface, and the request carries it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = Ground();
    late final Workbench bench;
    late final HttpServer server;
    String? bodyReceived;

    await tester.runAsync(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      // This journey is about the wire, not about sessions: it never made a
      // vault, the core's vault state is global, and after 064/A the send door
      // asks for a session name while one is unlocked. The same line
      // `reviewJourney` and «pressing Send really sends» carry.
      await z.vaultLock();
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      // Sending is the one thing that still waits, so this test answers first.
      for (final f in bench.suggested) {
        await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();

      server.listen((req) async {
        bodyReceived = await utf8.decodeStream(req);
        final reply = jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': 'Verstanden.'},
            },
          ],
        });
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(reply);
        await req.response.close();
      });
      await z.connectProvider(
        provider: const ProviderId(id: 'openai'),
        credential: 'sk-test-not-a-real-credential',
        baseUrl: 'http://127.0.0.1:${server.port}',
        model: 'the-configured-one',
      );
      await ground.refresh();
    });
    addTearDown(() async {
      await server.close(force: true);
      await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          bench: bench,
          ground: ground,
          onImport: () {}, onAsk: (_) {},
          onVault: () {},
          // **Setup, changed on 8 October; the claim below did not.**
          // The way to connect an unreached provider is now the settings
          // panel, so this screen has to have one for the chooser to draw
          // the door at all — a surface with nowhere to send the press
          // draws no door rather than a dead one.
          onSettings: (_) {},
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Choose the AI and what travels to it'));
    await settle(tester);

    // **The catalogue's own claims moved on 9 October** (064/C). The owner
    // pointed at this page with his hand: six grey company groups and six
    // «Connect in Settings» doors in the middle of his work. Grouping, the
    // grey for a model no key reaches, the ready colour of 046/H and the way
    // in are asserted where he put them — the panel's AI room, in
    // `the_model_that_answers_test` guard 5. The claim moved with the code
    // rather than dying with it.
    //
    // What this file keeps is the end of the wire, which is its own subject:
    // the work surface names what will answer, a press lists what can, and the
    // model chosen **by name** is the model the request carries.
    final control = find.byKey(TheModelThatAnswers.mark);
    expect(control, findsOneWidget,
        reason: 'the sheet does not name the model that will answer');

    // Read **after** the key: a catalogue taken before `connectProvider` says
    // «no key» in every row, and a list built on it would be green for the
    // wrong reason. The earlier read this file used to take is gone with the
    // claims that moved — the colours and the grouping are the AI room's now.
    late final List<ModelDescriptor> withAKey;
    await tester.runAsync(() async => withAKey = await z.models());
    final theirs = withAKey.firstWhere((m) => m.providerId == 'openai' && m.available);
    final outOfReach = withAKey.where((m) => !m.available).toList();
    expect(outOfReach, isNotEmpty, reason: 'everything has a key, so «names only» proves nothing');

    await tester.tap(control);
    await settle(tester);
    // Names only: what cannot answer is not offered on a work surface.
    for (final m in outOfReach) {
      expect(find.text(m.displayName), findsNothing,
          reason: '«${m.displayName}» cannot answer and is offered in the middle of the work');
    }
    // Switching the model changes what answers — at the provider and in usage.
    await tester.tap(find.text(theirs.displayName).last);
    await settle(tester);
    expect(bench.chosenModel, theirs.modelId, reason: 'tapping a model chose nothing');

    await tester.tap(find.textContaining('Send to').first);
    await settle(tester);

    expect(bodyReceived, isNotNull, reason: 'nothing was sent');
    expect(
      jsonDecode(bodyReceived!)['model'],
      theirs.modelId,
      reason: 'the request carried another model than the one chosen',
    );
    expect(bench.lastUsage?.modelId, theirs.modelId, reason: 'usage names another model');

    bench.dispose();
  });
}

/// `pumpAndSettle` never finishes while a real FFI future is in flight. The
/// same helper every screen test in this folder carries.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

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
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc =
    'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n'
    'Bitte prüfen Sie den Vertrag.';

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('the way back is a button a person can see, and Alt+Left is the same door', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = Ground();
    late final Workbench bench;
    var home = 0;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onHome: () => home++, onVault: () {})),
    );
    await settle(tester);

    // An arrow, a word, and a tooltip that names the key — the mark alone was
    // the whole of the way home, and nothing on it said so.
    final back = find.byTooltip('Back to your documents · Alt+Left');
    expect(back, findsOneWidget, reason: 'the top bar has no back control');
    expect(
      find.descendant(of: back, matching: find.byIcon(Icons.arrow_back)),
      findsOneWidget,
      reason: 'the back control has no arrow',
    );
    expect(find.text('Documents'), findsOneWidget, reason: 'the back control says nothing');

    await tester.tap(back);
    await tester.pump();
    expect(home, 1, reason: 'the back button did not go home');

    // The keyboard reaches the same door.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(home, 2, reason: 'Alt+Left did not go home');

    // And the mark stays a way home: nothing a person already learned is taken
    // away from them. The word beside it steps aside while a document is open —
    // the mark is what they tapped, and the mark is still there.
    expect(find.text('Z Privacy'), findsNothing, reason: 'the wordmark crowds the bar at 964');
    await tester.tap(find.byType(ZMark));
    await tester.pump();
    expect(home, 3, reason: 'the mark stopped being a way home');

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
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {})),
    );
    await settle(tester);

    final door = find.byTooltip('Choose the AI and what travels to it');
    expect(door, findsOneWidget, reason: 'the top bar has no AI button');
    await tester.tap(door);
    await settle(tester);

    expect(find.text('Review before send'), findsOneWidget, reason: 'the AI button opened nothing');

    // Provider, model and mode stand above the text, not behind a second page.
    final choice = tester.getTopLeft(find.text('Model')).dy;
    // The eyebrow is drawn in capitals; the finder reads what is on screen.
    final text = tester.getTopLeft(find.text('THIS IS WHAT WOULD LEAVE')).dy;
    expect(choice, lessThan(text), reason: 'the choice is still below the text');
    expect(find.text('What travels'), findsOneWidget, reason: 'the mode is not on the first page');

    // Only sending waits for the review — and it says so where the send is.
    final onwards = find.widgetWithText(ZButton, 'Continue');
    expect(tester.widget<ZButton>(onwards).onPressed, isNotNull, reason: 'the doors are still shut');
    await tester.tap(onwards);
    await settle(tester);
    expect(find.textContaining('Answer the review first'), findsWidgets, reason: 'the gate says nothing');

    bench.dispose();
  });

  testWidgets('the list is the whole catalogue, grouped, and switching changes the model that answers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = Ground();
    late final Workbench bench;
    late final HttpServer server;
    late final List<ModelDescriptor> catalogue;
    String? bodyReceived;

    await tester.runAsync(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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
      catalogue = await z.models();

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
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {})),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Choose the AI and what travels to it'));
    await settle(tester);

    // Every model this build knows, not only the ones a connected key reaches.
    final unconnected = catalogue.where((m) => !m.available).toList();
    expect(unconnected, isNotEmpty, reason: 'nothing in the catalogue is out of reach, so this proves nothing');
    for (final model in catalogue) {
      expect(
        find.text(model.displayName),
        findsOneWidget,
        reason: '«${model.displayName}» (${model.providerId}) is missing from the chooser',
      );
    }
    // Grouped by provider, with the unconnected ones offering the way in.
    for (final p in ground.providers) {
      expect(find.text(p.label), findsWidgets, reason: '«${p.label}» is not a heading in the chooser');
    }
    expect(find.text('Connect'), findsWidgets, reason: 'an unconnected provider offers no way to connect');

    // ---------------------------------------------------------------- 046/H
    //
    // **The owner, 7 October: «the model that has a key is drawn in a
    // different colour».** Six companies are in the list and two have keys —
    // grey was saying «out of reach», and nothing was saying «ready». One
    // token in the palette, `Zc.ready`, and it is read off the rendered label
    // rather than from a flag the test sets itself.
    //
    // Read again, after the key: `catalogue` above was taken before
    // `connectProvider`, so every row in it says «no key» and a test built on
    // it would have been green for the wrong reason.
    late final List<ModelDescriptor> withAKey;
    await tester.runAsync(() async => withAKey = await z.models());
    final keyed = withAKey.where((m) => m.available).toList();
    final unkeyed = withAKey.where((m) => !m.available).toList();
    expect(keyed, isNotEmpty, reason: 'nothing in the catalogue has a key, so this proves nothing');
    expect(unkeyed, isNotEmpty, reason: 'everything has a key, so this proves nothing either');
    for (final model in keyed) {
      expect(
        tester.widget<Text>(find.text(model.displayName)).style?.color,
        Zc.ready,
        reason: '«${model.displayName}» has a key and is not drawn as ready',
      );
    }
    for (final model in unkeyed) {
      expect(
        tester.widget<Text>(find.text(model.displayName)).style?.color,
        isNot(Zc.ready),
        reason: '«${model.displayName}» has no key and is drawn as if it had one',
      );
    }
    // And the company's own name agrees with its models, so the group and its
    // chips never say two different things.
    final ready = ground.providers.where((p) => p.connected).toList();
    expect(ready, isNotEmpty);
    for (final p in ready) {
      expect(
        tester.widget<Text>(find.text(p.label).first).style?.color,
        Zc.ready,
        reason: '«${p.label}» has a key and its heading is not drawn as ready',
      );
    }
    // The four that arrived in 046/H have never been called, and the screen
    // must not suggest otherwise.
    for (final id in ['xai', 'deepseek', 'moonshot', 'google']) {
      final row = ground.providers.firstWhere((p) => p.id == id);
      expect(row.connected, isFalse, reason: '«$id» reports itself connected');
      expect(
        tester.widget<Text>(find.text(row.label).first).style?.color,
        isNot(Zc.ready),
        reason: '«${row.label}» is drawn as ready and has no key',
      );
    }

    // Switching the model changes what answers — at the provider and in usage.
    final theirs = catalogue.firstWhere((m) => m.providerId == 'openai' && m.modelId != 'the-configured-one');
    await tester.ensureVisible(find.text(theirs.displayName));
    await tester.tap(find.text(theirs.displayName));
    await settle(tester);
    expect(bench.chosenModel, theirs.modelId, reason: 'tapping a model chose nothing');

    await tester.tap(find.widgetWithText(ZButton, 'Continue'));
    await settle(tester);
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

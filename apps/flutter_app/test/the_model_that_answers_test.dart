// 064/C · The model that answers — named always, listed on a press.
//
// The owner pointed at the send sheet with his own hand on 9 October: six grey
// company groups and six «Connect in Settings» doors standing in the middle of
// his work. His ruling, in his words: the name of the model that holds the key
// is **always visible** in the chat screen, pressing it opens **a list of model
// names only** — no groups, no grey, no Connect — and the whole catalogue moves
// to the AI room in the panel.
//
// So this is a **move**, not a second implementation: the grouped catalogue
// with its greyed chips and its way in is exactly what the panel's AI room
// should hold, and the work surfaces carry one control that names what will
// answer and lists what can. «What travels» stays where it is — a mode is not a
// catalogue.
//
// ## What the move costs, and who paid it
//
// `a_door_you_can_see_test`'s «the list is the whole catalogue, grouped» was
// measured on the sheet, because that is where the catalogue was on 8 October.
// Its claims about grouping, grey and the way in now belong to the AI room and
// are asserted there, in that file, with the ruling and its date named — the
// claim moves with the code rather than dying with it.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/send_sheet.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Kunde: Nordstern Consulting GmbH\nIBAN DE02120300000000202051\n';

Future<void> _settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// A bench, a ground, and — when asked for — a provider whose endpoint is a
/// server in this process, so «connected» is a fact and not a flag.
/// The model id the fixture configured the provider with — the catalogue's
/// own, read from the core.
String configured = '';

Future<({Ground ground, Workbench bench})> _ready(
  WidgetTester tester,
  String name, {
  bool connected = true,
}) async {
  late final ({Ground ground, Workbench bench}) made;
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-model-$name-$pid');
    if (own.existsSync()) own.deleteSync(recursive: true);
    own.createSync(recursive: true);
    addTearDown(() {
      if (own.existsSync()) own.deleteSync(recursive: true);
    });
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för modellen');
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    await bench.refreshModels();
    if (connected) {
      // **Configured with a model the catalogue really carries**, so the
      // control's ordinary path — an id to its own display name — is the one
      // measured. The fallback for an id this build never heard of is its own
      // assertion at the end of guard 1.
      configured = bench.models.firstWhere((m) => m.providerId == 'openai').modelId;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"choices":[{"message":{"role":"assistant","content":"Verstanden."}}]}');
        await req.response.close();
      });
      await z.connectProvider(
        provider: const ProviderId(id: 'openai'),
        credential: 'sk-test-not-a-real-credential',
        baseUrl: 'http://127.0.0.1:${server.port}',
        model: configured,
      );
      addTearDown(() async {
        await server.close(force: true);
        await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
      });
    }
    await ground.refresh();
    await bench.refreshModels();
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

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('the chat names the model that will answer, always', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'named');
    await tester.pumpWidget(_home(g));
    await _settle(tester);

    final control = find.byKey(TheModelThatAnswers.mark);
    expect(control, findsOneWidget, reason: 'the chat screen does not say which model will answer');
    // The configured model's own name, from the catalogue — the screen carries
    // no model name of its own, which is what the catalogue exists for.
    final its = g.bench.models.firstWhere((m) => m.modelId == configured);
    expect(
      find.descendant(of: control, matching: find.textContaining(its.displayName)),
      findsOneWidget,
      reason: 'the control does not name the model that holds the key',
    );
    final r = tester.getRect(control);
    expect(r.right, lessThanOrEqualTo(1200), reason: 'the control is off the window: $r');
    expect(r.height, greaterThan(10), reason: 'the control has no height: $r');

    // **And a model this build never heard of still answers, so its id is what
    // is said.** A provider can be configured with anything its own endpoint
    // serves; «saying the id» is truer than saying nothing, and a silent
    // control here would be a screen hiding what is about to receive the text.
    await tester.runAsync(() async {
      await z.configureProvider(
        provider: const ProviderId(id: 'openai'),
        model: 'a-model-this-build-never-heard-of',
      );
      await g.ground.refresh();
      await g.bench.refreshModels();
    });
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byKey(TheModelThatAnswers.mark),
        matching: find.textContaining('a-model-this-build-never-heard-of'),
      ),
      findsOneWidget,
      reason: 'a model the catalogue does not know is not named at all',
    );
  });

  // ------------------------------------------------------------------ guard 2
  testWidgets('the press opens names only — no groups, no grey, no Connect', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'list');
    await tester.pumpWidget(_home(g));
    await _settle(tester);

    await tester.tap(find.byKey(TheModelThatAnswers.mark));
    await _settle(tester);

    final reachable = g.bench.models.where((m) => m.available).toList();
    final out = g.bench.models.where((m) => !m.available).toList();
    expect(reachable, isNotEmpty, reason: 'nothing is reachable, so this guard proves nothing');
    expect(out, isNotEmpty, reason: 'everything is reachable, so «no grey» proves nothing either');

    for (final m in reachable) {
      expect(find.text(m.displayName), findsWidgets,
          reason: '«${m.displayName}» can answer and is not in the list');
    }
    // **The owner's three noes, each measured.**
    for (final m in out) {
      expect(find.text(m.displayName), findsNothing,
          reason: '«${m.displayName}» cannot answer and is offered anyway — this is the grey he pointed at');
    }
    expect(find.text('Connect in Settings'), findsNothing,
        reason: 'a Connect door stands in the list the owner asked to be names only');
    for (final p in g.ground.providers.where((p) => !p.connected)) {
      expect(find.text(p.label), findsNothing,
          reason: '«${p.label}» is a company heading in a list of model names');
    }

    // And choosing one by its name changes what will answer.
    final other = reachable.firstWhere((m) => m.modelId != 'the-configured-one');
    await tester.tap(find.text(other.displayName).last);
    await _settle(tester);
    expect(g.bench.chosenModel, other.modelId, reason: 'pressing a name chose nothing');
    expect(
      find.descendant(of: find.byKey(TheModelThatAnswers.mark), matching: find.textContaining(other.displayName)),
      findsOneWidget,
      reason: 'the control still names the model that was replaced',
    );
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **The place was a measurement, and this is the guard that pays for it.**
  // The control stood in the composer's own row first — beside «Ask the AI»,
  // where a chat puts it. A third element in that row takes its width from the
  // `Wrap` holding the two buttons, they wrap onto a second line, the pinned
  // band grows, and at 900×760 the page's own last line ended at y = 804: 44 px
  // below the glass, inside the band's own scroller, where nothing the composer
  // draws complains. `the_chat_reads_like_a_chat_test` guard b is what caught
  // it, in a file this round did not touch.
  //
  // So the control is in the strip that never scrolls, and the window where it
  // went wrong is measured here from now on.
  testWidgets('at 900×760 the control is on the glass and the composer keeps its place',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'tight');
    // **The ordinary state, deliberately.** With a suggestion still open the
    // composer's band draws the gate's own warning box as well, and that band
    // scrolls inside itself by design — measured: the page's last line then
    // lies at y = 857 of 760, which is the band scrolling and not the fault
    // this guard is about. Answering first puts the composer in the shape the
    // owner's chat is in when he presses send.
    await tester.runAsync(() async {
      for (final f in g.bench.suggested) {
        await z.answerFinding(session: g.bench.session, finding: f.id, answer: FindingAnswer.protect);
      }
      await g.bench.refresh();
    });
    await tester.pumpWidget(_home(g));
    await _settle(tester);

    final control = find.byKey(TheModelThatAnswers.mark);
    expect(control, findsOneWidget, reason: 'the control is gone at 900×760');
    final r = tester.getRect(control);
    expect(r.right, lessThanOrEqualTo(900), reason: 'the control hangs off the window: $r');
    expect(r.bottom, lessThanOrEqualTo(760), reason: 'the control is below the glass: $r');

    // The line the composer's band ends with — the one that was pushed to
    // y = 804. Measured here as a rect, because the fault did not move the
    // control: it moved what the control was standing beside.
    final last = find.textContaining('Nothing is uploaded');
    expect(last, findsOneWidget, reason: 'the page’s last line is past the end of a scroller again');
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(760),
        reason: 'the page’s last line ends at y=${tester.getRect(last).bottom.toStringAsFixed(0)} '
            'in a 760 px window — the composer’s band grew again');
  });

  // ------------------------------------------------------------------ guard 3
  testWidgets('nothing connected: one line and one door, not a catalogue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'empty', connected: false);
    await tester.pumpWidget(_home(g));
    await _settle(tester);

    final control = find.byKey(TheModelThatAnswers.mark);
    expect(control, findsOneWidget,
        reason: 'with no key the chat says nothing at all about the AI that would answer');
    expect(find.descendant(of: control, matching: find.textContaining('No AI connected')), findsOneWidget,
        reason: 'the control does not say that nothing can answer yet');
    // Not a catalogue: no company name and no model name is drawn on this
    // screen when none of them can answer.
    for (final p in g.ground.providers) {
      expect(find.text(p.label), findsNothing, reason: '«${p.label}» is drawn on the chat with no key anywhere');
    }
  });

  // ------------------------------------------------------------------ guard 4
  testWidgets('the review page carries the control and not the catalogue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'sheet');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SendSheet(bench: g.bench, ground: g.ground, onSettings: () {})),
    ));
    await _settle(tester);

    expect(find.byKey(TheModelThatAnswers.mark), findsOneWidget,
        reason: 'the review page does not name the model that will answer');
    // The six groups and the six doors the owner pointed at.
    expect(find.text('Connect in Settings'), findsNothing,
        reason: 'the Connect doors are still standing in the middle of the work');
    for (final p in g.ground.providers.where((p) => !p.connected)) {
      expect(find.text(p.label), findsNothing,
          reason: '«${p.label}» is still a heading on the review page');
    }
    // And the mode is untouched: it was never part of the catalogue.
    expect(find.text('Protected text'), findsOneWidget, reason: 'the mode chips went with the catalogue');
    expect(find.text('The original text'), findsOneWidget, reason: 'the mode chips went with the catalogue');
  });

  // ------------------------------------------------------------------ guard 5
  testWidgets('the catalogue is in the panel’s AI room, grouped, with grey and the way in',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'room');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsScreen(ground: g.ground, onClose: () {}, room: SettingsRoom.ai),
      ),
    ));
    await _settle(tester);

    // Every model this build knows, not only the ones a key reaches — the
    // claim that moved out of `a_door_you_can_see_test` with the code.
    for (final m in g.bench.models) {
      expect(find.text(m.displayName), findsWidgets,
          reason: '«${m.displayName}» (${m.providerId}) is missing from the AI room');
    }
    // Grouped by company, and the colour the owner asked for on 7 October: a
    // model whose key is here reads as ready, one whose key is not stays grey.
    for (final p in g.ground.providers) {
      expect(find.text(p.label), findsWidgets, reason: '«${p.label}» is not a heading in the AI room');
    }
    final keyed = g.bench.models.where((m) => m.available).toList();
    final unkeyed = g.bench.models.where((m) => !m.available).toList();
    expect(keyed, isNotEmpty, reason: 'nothing has a key, so the colours prove nothing');
    expect(unkeyed, isNotEmpty, reason: 'everything has a key, so the colours prove nothing');
    for (final m in keyed) {
      expect(tester.widget<Text>(find.text(m.displayName).first).style?.color, Zc.ready,
          reason: '«${m.displayName}» has a key and is not drawn as ready');
    }
    for (final m in unkeyed) {
      expect(tester.widget<Text>(find.text(m.displayName).first).style?.color, isNot(Zc.ready),
          reason: '«${m.displayName}» has no key and is drawn as if it had one');
    }
  });
}

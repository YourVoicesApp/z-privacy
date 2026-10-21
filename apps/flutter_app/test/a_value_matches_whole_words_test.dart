// 041-P on the screen, after 083c deleted the dialog it was written about:
// **a hand selection carries the kind the scanner found on exactly that
// stretch, and nothing else.**
//
// The owner's hand-made protections went out as `CUSTOM` and a model reads
// `PERSON`, so the core learned to offer a person for one or two capitalised
// words — a guess, and the last of four. On 14 Oct the lead ruled that guess
// out: the kind is the scanner's own finding on that exact span, or `CUSTOM`.
// Measured here, on this file's own document: «Björn Sandström» is still
// `PERSON`, because the Swedish pack found it whole — so 041-P's promise is
// kept by the finding rather than by the shape of the words — and «Sandström»
// **alone** is now `CUSTOM`, which is the cost, and which 076's second click
// answers by taking the pair.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/core/protecting.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
const _doc = 'Protokoll 2026\nBjörn Sandström ringde klockan 14 om fakturan 55123.\n';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  testWidgets('a name selected by hand is protected at once, as the kind the scanner found',
      (tester) async {
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-kind-$pid');
      removeWhenItLetsGo(dir);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'sv');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'sv');
      await bench.rescan();
    });

    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
    ));
    await settle(tester);

    Span spanOf(String needle) {
      final at = _doc.indexOf(needle);
      return Span(start: at, end: at + needle.length);
    }

    // The name, drawn by hand.
    await tester.runAsync(() => bench.select(spanOf('Björn Sandström')));
    await settle(tester, rounds: 2);
    await tester.tap(find.widgetWithText(ZButton, sentences.protectAct));
    await settle(tester, rounds: 3);

    // **No dialog, and it is already done** — 083, ruling 1.
    expect(find.text('Cancel'), findsNothing, reason: 'a dialog stood in the way');
    expect(bench.tokens, isNotEmpty, reason: 'the press protected nothing');
    expect(
      bench.tokens.first.token,
      contains('_PERSON_'),
      reason: 'the token is ${bench.tokens.first.token}, and a model reads the kind inside it',
    );
    expect(bench.tokens.first.kind, Kind.person);

    // **And the cost of that ruling is paid back by 085 ruling 1** (15 October).
    // It read: «a click on the surname alone is not what the scanner found —
    // the finding covers both words — so the kind is honestly unknown». A name
    // the app read for itself is one finding per word now, so the surname **is**
    // a finding and carries its kind. Nothing guesses: it is still the pack's
    // own answer over exactly this word.
    await tester.runAsync(() => bench.select(spanOf('Sandström')));
    await settle(tester, rounds: 2);
    expect(bench.selected!.kind, Kind.person,
        reason: 'one word of a name is a finding of its own now, and carries its kind');

    // And an invoice number is not a person: the app has no opinion, and says so.
    await tester.runAsync(() => bench.select(spanOf('55123')));
    await settle(tester, rounds: 2);
    expect(bench.selected!.kind, Kind.custom, reason: 'a number was offered as a person');

    bench.dispose();
  });

  /// **A drag over the whole of a name that is already ours says so** — the
  /// lead's ruling of 15 October, on the glass.
  ///
  /// The scanner gives one token per word, so the whole name is two of them and
  /// matched no single protection: the bar said «Protect» over a value entirely
  /// ours. The view now answers at the same finer grain and **lists** the
  /// tokens, which is a field and not a sixth button state — and the bar prints
  /// them as they stand in the text.
  testWidgets('a drag over a whole name already ours is told so, and both tokens are named',
      (tester) async {
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      final dir = Directory('${Directory.systemTemp.path}/zp-both-tokens');
      removeWhenItLetsGo(dir);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: 'Sehr geehrter Herr Stefan Keller, danke.\n');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
    ));
    await settle(tester);

    const doc = 'Sehr geehrter Herr Stefan Keller, danke.\n';
    final at = doc.indexOf('Stefan Keller');
    await tester.runAsync(
      () => bench.select(Span(start: at, end: at + 'Stefan Keller'.length)),
    );
    await settle(tester, rounds: 2);

    expect(bench.selected!.protectedAs, hasLength(2),
        reason: 'a name the pack protected is one token per word, and both are ours');
    expect(protectStateOf(bench.selected), ProtectState.known,
        reason: 'the button offered a press over a value already ours');
    expect(find.textContaining('Already protected as'), findsOneWidget);
    for (final token in bench.selected!.protectedAs) {
      expect(find.textContaining(token), findsOneWidget,
          reason: 'the bar did not name «$token»');
    }

    bench.dispose();
  });
}

// «The bubble does not come out» — the owner, 6 October, on the published
// build, with 68 words waiting for his word.
//
// Measured before anything was changed, and this is the whole defect: each
// marked word carried a `TapGestureRecognizer`, and inside a `SelectableText`
// that recognizer stands in the gesture arena against the text's own
// drag-selection. Flutter gives a **mouse** one pixel of slop, so the arena
// went to the drag the moment the pointer moved two pixels — and nobody
// presses a mouse button without moving two pixels.
//
//     slip     before            after
//     1 px     bubble opens      bubble opens
//     2 px     nothing at all    bubble opens
//     4 px     nothing at all    bubble opens
//     8 px     nothing at all    a drag, as it should be
//
// «Nothing at all» is exact: no bubble, and no selection either. The press
// vanished. So the press is now read from raw pointer events, which reach
// every listener and are in no arena.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drawn_document.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// Ten pages of a Swedish letter — the shape of the attachment the owner spent
/// twenty minutes in, so the column is long and the marks are many.
String _tenPages() {
  final out = StringBuffer();
  for (var page = 1; page <= 10; page++) {
    out.writeln('Sida $page av tio — Nordstern Konsult AB');
    for (var line = 0; line < 18; line++) {
      out.writeln('Hej, Lars Reinholdsson har granskat avtalet med Anna Pettersson.');
    }
    if (page < 10) out.write('\u{c}');
  }
  return out.toString();
}

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a press on a waiting word opens the bubble even when the mouse slips', (tester) async {
    final ground = Ground();
    final doc = _tenPages();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-bubble-out-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'sv');
      await z.importText(session: session, text: doc);
      bench = Workbench(session: session, profileId: null, packId: 'sv');
      await bench.rescan();
    });

    // A laptop window, not a test bench.
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);
    expect(bench.suggested, isNotEmpty, reason: 'nothing is waiting, so this proves nothing');

    // Taken from the text as it is drawn — see `drawn_document.dart`. This
    // used to lay the document out with a painter of its own over the
    // `OriginalText` box, which stopped being where the text is the moment a
    // gutter stood beside it.
    final waiting = bench.suggested.first;
    final at = whereIsInDocument(
      tester,
      'Nordstern',
      waiting.span.start,
      span: waiting.span.end - waiting.span.start,
    );

    Future<void> away() async {
      await tester.tapAt(const Offset(1240, 770), kind: PointerDeviceKind.mouse);
      await settle(tester, rounds: 2);
      expect(find.byType(ChoiceBubble), findsNothing, reason: 'the bubble would not close');
    }

    // A press that does not move at all — this always worked.
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await settle(tester, rounds: 3);
    expect(find.byType(ChoiceBubble), findsOneWidget, reason: 'an exact press opened nothing');
    await away();

    // And a press by a hand on a mouse. Two pixels used to be the end of it.
    for (final slip in [1.0, 2.0, 4.0]) {
      final press = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 40));
      await press.moveBy(Offset(slip, 0));
      await tester.pump(const Duration(milliseconds: 40));
      await press.up();
      await settle(tester, rounds: 3);
      expect(find.byType(ChoiceBubble), findsOneWidget,
          reason: 'a press that slipped ${slip}px opened nothing');
      await away();
    }

    // A real drag is still a drag: it selects, and asks nothing.
    final drag = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 40));
    await drag.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await drag.up();
    await settle(tester, rounds: 3);
    expect(find.byType(ChoiceBubble), findsNothing, reason: 'a drag across the word opened a bubble');

    bench.dispose();
  });

  testWidgets('the bar\'s «Vault» is a door, and a second press offers to lock it', (tester) async {
    final ground = Ground();
    late final Workbench bench;
    var toTheVault = 0;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-bar-door-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: 'Herr Thomas Müller schreibt.\n');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () => toTheVault++),
    ));
    await settle(tester);

    // With no vault, the fact says so and the press goes straight there.
    expect(find.text('None'), findsOneWidget, reason: 'the bar does not say the vault is missing');
    await tester.tap(find.text('None'));
    await settle(tester, rounds: 2);
    expect(toTheVault, 1, reason: 'the bar\'s «Vault» is still only a sentence');

    // With one open, the press asks which of the two things it meant — and
    // «Lock now» is the thing a person wants on standing up from the desk.
    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort für die Leiste');
      await ground.refresh();
      await bench.rescan();
    });
    await settle(tester);
    expect(find.text('Unlocked'), findsOneWidget);

    await tester.tap(find.text('Unlocked'));
    await settle(tester, rounds: 3);
    expect(find.text('Lock now'), findsOneWidget, reason: 'an open vault offers no way to shut it');

    await tester.tap(find.text('Lock now'));
    await settle(tester, rounds: 6);
    expect(ground.vault, VaultState.locked, reason: '«Lock now» did not lock it');
    expect(toTheVault, 1, reason: 'locking went to the vault screen as well');

    bench.dispose();
  });
}

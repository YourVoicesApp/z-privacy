// 041-F · the choice at the word, and a handle between the two columns.
//
// The owner, 6 October: «the suggested names must appear on the text itself,
// not as a separate list, and the choices a small message that disappears when
// it is pressed» — and «the ability to change the size of the two screens, the
// text screen and the result screen».
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drawn_document.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/review.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc =
    'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'Lieferung an Lindenstraße 8, 86150 Augsburg.\n';

Future<(Workbench, Ground)> _open(WidgetTester tester, {String? dir}) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    await z.vaultLock();
    final home = Directory(dir ?? '${Directory.systemTemp.path}/zprivacy-choice-$pid');
    if (dir == null && home.existsSync()) home.deleteSync(recursive: true);
    home.createSync(recursive: true);
    await z.setDataDir(dir: home.path);
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    await z.importText(session: session, text: _doc);
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await bench.rescan();
  });
  return (bench, ground);
}

Future<void> _pump(WidgetTester tester, Workbench bench, Ground ground, {VoidCallback? onVault}) async {
  await tester.binding.setSurfaceSize(const Size(1500, 1000));
  await tester.pumpWidget(
    MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: onVault ?? () {}),
    ),
  );
  await settle(tester);
}

/// Where a waiting word stands on the screen — taken from the text as it is
/// drawn. See `drawn_document.dart` for why this file no longer lays the
/// document out for itself.
Offset _atSuggestion(WidgetTester tester, Workbench bench) {
  final waiting = bench.suggested.first;
  return whereIsInDocument(
    tester,
    'Nordstern',
    waiting.span.start,
    span: waiting.span.end - waiting.span.start,
  );
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a press on a waiting word offers the four answers, where the word is', (tester) async {
    final (bench, ground) = await _open(tester);
    await _pump(tester, bench, ground);
    expect(bench.suggested, isNotEmpty, reason: 'nothing is waiting, so this proves nothing');

    await tester.tapAt(_atSuggestion(tester, bench), kind: PointerDeviceKind.mouse);
    await settle(tester);

    expect(find.byType(ChoiceBubble), findsOneWidget, reason: 'the word opened nothing');
    for (final act in ['Protect', 'Not sensitive', 'Skip']) {
      expect(find.text(act), findsWidgets, reason: '«$act» is not in the bubble');
    }
    // «Always» carries its state, as it has since 041-B.
    expect(find.text('Always · needs a vault'), findsOneWidget);
    // And the side panel is not what a word opens.
    expect(find.byType(ReviewPanel), findsNothing, reason: 'the word opened the review list');

    bench.dispose();
  });

  testWidgets('pressing an answer applies it and the bubble goes', (tester) async {
    final (bench, ground) = await _open(tester);
    await _pump(tester, bench, ground);
    final waiting = bench.suggested.length;

    await tester.tapAt(_atSuggestion(tester, bench), kind: PointerDeviceKind.mouse);
    await settle(tester);
    await tester.tap(
      find.descendant(of: find.byType(ChoiceBubble), matching: find.text('Protect')),
    );
    await settle(tester, rounds: 8);

    expect(find.byType(ChoiceBubble), findsNothing, reason: 'the bubble stayed after the press');
    expect(bench.suggested.length, lessThan(waiting), reason: 'the answer did nothing');

    bench.dispose();
  });

  testWidgets('Escape closes it and changes nothing', (tester) async {
    final (bench, ground) = await _open(tester);
    await _pump(tester, bench, ground);
    final waiting = bench.suggested.length;

    await tester.tapAt(_atSuggestion(tester, bench), kind: PointerDeviceKind.mouse);
    await settle(tester);
    expect(find.byType(ChoiceBubble), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    expect(find.byType(ChoiceBubble), findsNothing, reason: 'Escape left the bubble open');
    expect(bench.suggested.length, waiting, reason: 'Escape answered something');

    bench.dispose();
  });

  testWidgets('the handle moves the two columns, keeps both, and is remembered', (tester) async {
    final home = '${Directory.systemTemp.path}/zprivacy-handle-$pid';
    final dir = Directory(home);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final (bench, ground) = await _open(tester, dir: home);
    await _pump(tester, bench, ground);

    double originalWidth() =>
        tester.getSize(find.byKey(const ValueKey<String>('workspace-original-pane'))).width;
    final before = originalWidth();

    // Drag the handle to the right: the Original column grows.
    final handle = tester.getCenter(find.byType(MouseRegion).at(0));
    final splitter = tester.widgetList<MouseRegion>(find.byType(MouseRegion))
        .where((m) => m.cursor == SystemMouseCursors.resizeColumn);
    expect(splitter, isNotEmpty, reason: 'there is no handle between the columns');
    final at = tester.getCenter(
      find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn),
    );
    await tester.dragFrom(at, const Offset(160, 0));
    await settle(tester, rounds: 6);
    expect(originalWidth(), greaterThan(before + 100), reason: 'the drag moved nothing');
    expect(handle.dx, isNotNull);

    // And it cannot be dragged shut: a column that disappears cannot be compared.
    await tester.dragFrom(
      tester.getCenter(
        find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn),
      ),
      const Offset(-2000, 0),
    );
    await settle(tester, rounds: 6);
    expect(originalWidth(), greaterThanOrEqualTo(280), reason: 'a column was dragged shut');

    // The file remembers where it was left.
    late final Settings kept;
    await tester.runAsync(() async {
      await ground.refresh();
      kept = ground.config!;
    });
    expect(kept.originalPanePercent, lessThan(50), reason: 'the handle was not remembered: ${kept.originalPanePercent}');

    bench.dispose();
  });
}

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

// 041-B · one decision per name, on the screen.
//
// Measured on DE-1 (`Brief_Weber.txt`) before any of this was written: 28
// findings, 8 of them suggested, and two of those values stand in two places —
// «2026-04471» as a Contract and «Lindenstraße 8, 86150 Augsburg» as an
// Address. The owner answered each of them twice. The core settles that in one
// call now; these are the two things the screen owes him on top of it: the card
// must say how many places one press will clear, and «Always» must say what it
// needs instead of refusing into a sentence drawn at the other end of the
// window.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _de1 = '../../z_core/tests/fixtures/Brief_Weber.txt';

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a card says how many places one press settles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-places-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: File(_de1).readAsStringSync());
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    // The premise, from the core rather than from this file.
    final twice = bench.suggested.where((f) => f.occurrences > 1).toList();
    expect(twice, isNotEmpty, reason: 'nothing in DE-1 stands in two places any more');

    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {})),
    );
    await settle(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);

    expect(
      find.textContaining('in ${twice.first.occurrences} places'),
      findsWidgets,
      reason: 'the card does not say how many places the press will clear',
    );
    // And a value that stands once says nothing of the sort.
    expect(find.textContaining('in 1 places'), findsNothing);

    bench.dispose();
  });

  testWidgets('«Always» carries what it needs, and the way to it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = Ground();
    late final Workbench bench;
    var vault = 0;
    await tester.runAsync(() async {
      // No vault at all: this is the state the owner was in.
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-always-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: File(_de1).readAsStringSync());
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });
    expect(ground.vault, VaultState.absent, reason: 'this case is the one without a vault');

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () => vault++),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);

    // The button says what it needs — on itself, where the press happens.
    expect(find.text('Always'), findsNothing, reason: 'the button still promises what it cannot do');
    final needs = find.text('Always · needs a vault');
    expect(needs, findsWidgets, reason: '«Always» does not say what it needs');
    // And one sentence says what Always even is.
    expect(
      find.textContaining('protect this value in every document from now on'),
      findsWidgets,
      reason: 'nothing explains what Always means',
    );

    await tester.tap(needs.first);
    await settle(tester);
    expect(vault, 1, reason: 'the button did not open the vault screen');
    expect(bench.trouble, isNull, reason: 'it refused instead of offering the way in');

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

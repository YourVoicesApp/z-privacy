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

/// The review row's own «Protect», by the key the panel gives it.
const _rowProtectKey = ValueKey<String>('review-protect');

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
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {})),
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

  /// **The other half of 041-B, after the owner deleted the button it was
  /// about** — 083, ruling 8 (14 Oct).
  ///
  /// «Always» said what it needed — «Always · needs a vault» — and opened the
  /// vault screen rather than refusing into a sentence at the other end of the
  /// window. That repair was right and the button is gone: «Always» wrote
  /// knowledge that outlived the conversation, and 083's model has none («no
  /// name memory across sessions»).
  ///
  /// What is left to hold is better than the old claim: **the review needs no
  /// vault at all.** Both of its answers work with no vault on the machine, and
  /// nothing in it asks for one.
  testWidgets('the review asks for no vault, and both answers work without one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    final ground = Ground();
    late final Workbench bench;
    var vault = 0;
    await tester.runAsync(() async {
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
    final before = bench.openSuggestions;
    expect(before, greaterThan(0), reason: 'nothing waits, so no answer can be measured');

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () => vault++),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);

    for (final gone in [
      'Always',
      'Always · needs a vault',
      'Always · unlock the vault',
      'Not sensitive in profile',
      'Not sensitive everywhere',
    ]) {
      expect(find.text(gone), findsNothing, reason: '«$gone» is deleted, not hidden');
    }
    expect(
      find.textContaining('protect this value in every document from now on'),
      findsNothing,
      reason: 'the sentence about a deleted button is still on the screen',
    );

    // And the answer a person gives now needs nothing of the vault.
    await tester.tap(find.byKey(_rowProtectKey).first);
    await settle(tester, rounds: 12);
    expect(bench.openSuggestions, lessThan(before), reason: 'the answer did not land');
    expect(bench.trouble, isNull, reason: 'it refused: ${bench.trouble}');
    expect(vault, 0, reason: 'the review sent a person to the vault screen');

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

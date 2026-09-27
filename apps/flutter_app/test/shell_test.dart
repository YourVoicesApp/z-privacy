// M7.1 — the shell, tested against the real core.
//
// The owner's rule for M7 is that no number on screen is invented in Dart. A
// widget test is the only way to hold that to account: it pumps the real screens
// against the real library, then reads the pixels' text and compares it with what
// the core says when asked directly.
//
// One thing to know before reading: every call into Rust below is wrapped in
// `tester.runAsync`. `testWidgets` runs inside a fake-async zone, and a real FFI
// future never completes in one — the first version of this file hung for ten
// minutes on `await ground.refresh()` before that was the answer.
//
// Needs the native library, so run once:  flutter build linux --debug
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// A document with something for each layer to find, so the band's numbers are
/// not all zero — a screen that only ever shows 0 proves nothing.
const _doc = 'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n'
    'Bitte prüfen Sie den Vertrag.';

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    // The runner is started with LD_LIBRARY_PATH pointing at the built bundle.
    await RustLib.init();
  });

  testWidgets('Home draws the ground as the core reports it, not as Dart guesses', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final VaultState vault;
    late final List<PackRow> packs;
    late final List<ProviderRow> providers;
    await tester.runAsync(() async {
      await ground.refresh();
      // What the core says, asked directly. The screen must agree with these.
      vault = await z.vaultState();
      packs = await z.packs();
      providers = await z.providers();
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        ground: ground,
        version: 'z_core 0.1.0',
        onImport: () {},
        onType: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Z Privacy'), findsOneWidget);
    expect(find.text('Import a document'), findsOneWidget);

    // The pack's label is the pack's own, never a string typed into a screen.
    expect(packs, isNotEmpty, reason: 'this build carries a pack');
    expect(find.textContaining(packs.first.label), findsOneWidget);

    // The provider count on screen is the core's count.
    final connected = providers.where((p) => p.connected).length;
    expect(find.text('$connected'), findsWidgets);

    // And the vault line says the state the core is in — not a friendlier version
    // of it. A locked vault must look locked.
    switch (vault) {
      case VaultState.unlocked:
        expect(find.textContaining('identities the app knows'), findsOneWidget);
      case VaultState.locked:
        expect(find.text('Locked'), findsOneWidget);
      case VaultState.absent:
        expect(find.text('None'), findsOneWidget);
    }
  });

  testWidgets('the Workspace band reports the scan the core ran, number for number',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    // The core's own report, for comparison.
    final report = bench.report!;
    expect(report.auto + report.suggested, greaterThan(0), reason: 'the scan found something to show');

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await tester.pumpAndSettle();

    // The band, word for word as the design board writes it, with the core's
    // numbers substituted in.
    expect(find.text('Scanned on import'), findsOneWidget);
    expect(
      find.text('${report.auto} protected automatically · ${report.suggested} need your word · '
          '${report.normal} normal'),
      findsOneWidget,
      reason: 'the band shows the core numbers and nothing rounded or recomputed',
    );

    // The two columns exist and each carries its hard rule.
    expect(find.text('ORIGINAL — LOCAL ONLY'), findsOneWidget);
    expect(find.text('SAFE — AI WILL RECEIVE'), findsOneWidget);
    expect(find.text('Never sent to AI · Send cannot read this side'), findsOneWidget);

    // Typed text has no file name, and the bar says so rather than inventing one.
    expect(find.text('Typed text'), findsOneWidget);
    expect(find.text('1 page'), findsOneWidget);

    // The vault's state is on the bar, and it is the state inside the report —
    // one source, so the bar and the band can never contradict each other.
    final onBar = switch (report.vault) {
      VaultState.unlocked => 'Unlocked',
      VaultState.locked => 'Locked',
      VaultState.absent => 'None',
    };
    expect(find.text(onBar), findsOneWidget);

    bench.dispose();
  });
}

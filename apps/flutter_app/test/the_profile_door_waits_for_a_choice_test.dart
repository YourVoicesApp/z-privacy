// 075a — the Profiles door recedes while there is nothing to choose between.
//
// **The owner, 10 Oct 2026:** he never understood the Profiles dialog, and the
// reason is that he never needed it — one profile exists, so the dialog asks
// him to choose between «Everywhere» and the only thing there is. The lead's
// ruling is 067's, applied again: the catalogue of models left the work
// surfaces for the settings panel and the work surfaces kept only what they
// could act on. Profiles do the same. **No PROFILE control in the header and
// no dialog that can interrupt, while the vault holds at most one profile.**
//
// What this file asserts, and the fourth is the one nobody asked for:
//
//   * with one profile, the workspace header carries no profile door at all;
//   * with two, it is back — which is also the control for the first, because
//     «the door is not there» is what a broken finder says too;
//   * with one, the door is still **on the board**, so nothing a person could
//     do yesterday became impossible today. A control that recedes must leave
//     a way in for whoever goes looking, or it has not receded — it has gone;
//   * a bench that is **already inside** a profile keeps the control, however
//     few profiles exist. Hiding it there would leave a person in a state they
//     can neither see nor leave, and this screen's own rule is that the work
//     surface names what actually ran.
//
// A separate file from `shell_test.dart` for that file's own stated reason: the
// vault is one per process, and tests that make one must not run beside tests
// that assume there is none.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// Real futures do not complete inside `testWidgets`' fake-async zone — the
/// reason is written at the head of `shell_test.dart`.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _freshVault(String name) async {
  await z.vaultLock();
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-ui-$name-$pid');
  removeWhenItLetsGo(dir);
  await z.setDataDir(dir: dir.path);
  await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
}

const _doc =
    'Internal reference: 9999 000 01\nNothing general should learn it.';

/// A workspace with a document read on it, and `profiles` profiles in the
/// vault. Returns the ground and the bench so the caller can switch one on.
Future<(Ground, Workbench)> _workspace(
  WidgetTester tester,
  String vaultName, {
  required int profiles,
}) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    await _freshVault(vaultName);
    for (var i = 0; i < profiles; i++) {
      await z.createProfile(name: 'Client ${i + 1}', session: null);
    }
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    await z.importText(session: session, text: _doc);
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await bench.rescan();
  });
  addTearDown(bench.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: WorkspaceScreen(
        bench: bench,
        ground: ground,
        onImport: () {}, onAsk: (_) {},
        onVault: () {},
      ),
    ),
  );
  await settle(tester);
  return (ground, bench);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(
        buildTheBridgeFirst,
      );
    }
    await RustLib.init();
  });

  testWidgets('one profile: the header offers no door at all', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final (ground, _) = await _workspace(tester, 'profiles-one', profiles: 1);
    expect(
      ground.profiles,
      hasLength(1),
      reason: 'the vault does not hold the one profile this test is about',
    );
    expect(
      find.byKey(ProfileSwitcher.door),
      findsNothing,
      reason:
          'the header still carries the profile door while there is nothing '
          'to choose between',
    );
  });

  testWidgets('two profiles: the door is back', (tester) async {
    // The control for the test above: «findsNothing» is also what a finder
    // looking for the wrong key reports, every time, for ever.
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _workspace(tester, 'profiles-two', profiles: 2);
    expect(
      find.byKey(ProfileSwitcher.door),
      findsOneWidget,
      reason: 'with a real choice to make, the header must carry the door',
    );
    await tester.tap(find.byKey(ProfileSwitcher.door));
    await settle(tester);
    expect(
      find.byType(ProfileSwitcher),
      findsOneWidget,
      reason: 'the door is drawn but opens nothing',
    );
  });

  testWidgets('one profile: the board still opens it, for whoever looks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await _freshVault('profiles-board');
      await z.createProfile(name: 'Client 1', session: null);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });
    addTearDown(bench.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultScreen(ground: ground, bench: bench, onClose: () {}),
      ),
    );
    await settle(tester);

    expect(
      find.byKey(ProfileSwitcher.door),
      findsOneWidget,
      reason:
          'the door left the header and is nowhere on the board either, so a '
          'conversation can no longer be put into the one profile that exists',
    );
    await tester.tap(find.byKey(ProfileSwitcher.door));
    await settle(tester);
    expect(find.byType(ProfileSwitcher), findsOneWidget);
  });

  testWidgets('a bench already in a profile keeps the control', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final (ground, bench) = await _workspace(
      tester,
      'profiles-in',
      profiles: 1,
    );
    await tester.runAsync(() => bench.switchProfile(ground.profiles.first.id));
    await settle(tester);

    expect(
      bench.profileId,
      isNotNull,
      reason: 'the bench did not enter the profile, so this proves nothing',
    );
    expect(
      find.byKey(ProfileSwitcher.door),
      findsOneWidget,
      reason:
          'a bench inside a profile shows no profile, so a person is in a '
          'state they can neither see nor leave',
    );
  });
}

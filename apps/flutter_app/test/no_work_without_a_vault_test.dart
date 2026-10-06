// 041-N · There is no work without an open vault.
//
// The owner, 6 October, after a live run: «you cannot begin without an open
// vault; pressing + must open the vault, or even entering the application».
//
// 041-E put the vault in front of the work as an offer with «Later» beside it.
// This is the same door with the offer taken out: everything Z learns while a
// person works is kept in the vault, so work started without one is work
// thrown away at the end of the day.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein ausreichend langes Passwort';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  Future<(Directory, Ground)> aFreshDevice(WidgetTester tester, String tag) async {
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-must-vault-$tag-$pid');
    final ground = Ground();
    await tester.runAsync(() async {
      await z.vaultLock();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
    });
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);
    return (dir, ground);
  }

  testWidgets('the first run has no «Later»: the vault is the way in', (tester) async {
    await aFreshDevice(tester, 'first');

    expect(find.byType(FirstRunScreen), findsOneWidget);
    await tester.tap(find.text('English'));
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Start'));
    await settle(tester);

    expect(find.text('Create a vault'), findsOneWidget, reason: 'the vault step is not on the first run');
    expect(find.text('Later'), findsNothing, reason: '«Later» is still a way past the vault');

    // And the only button there leads to the vault, not to the home.
    await tester.tap(find.text('Create a vault'));
    await settle(tester);
    expect(find.byType(VaultScreen), findsOneWidget, reason: 'the first run did not end at the vault');
    expect(find.byType(HomeScreen), findsNothing, reason: 'the home was reached with no vault');
  });

  testWidgets('a locked vault stands in front of the composer, and opening it lets the work begin',
      (tester) async {
    final (dir, ground) = await aFreshDevice(tester, 'locked');

    // A device that has been used before: a vault exists, the first run is
    // done, and this launch finds it locked.
    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      await _firstRunIsDone(ground);
      await z.vaultLock();
      await ground.refresh();
    });
    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);

    expect(find.byType(VaultScreen), findsOneWidget,
        reason: 'a locked vault let the app start without being opened');
    expect(find.byType(HomeScreen), findsNothing);

    // Opened, the home is there — and the composer with it.
    await tester.runAsync(() async {
      await z.vaultUnlockWithPassphrase(passphrase: _pass);
      await ground.refresh();
    });
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget, reason: 'an open vault did not reach the home');
  });

  testWidgets('with the vault locked, starting work opens the vault instead', (tester) async {
    final (dir, ground) = await aFreshDevice(tester, 'begin');

    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      await _firstRunIsDone(ground);
    });
    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget, reason: 'an open vault should reach the home');

    // The vault locks under them — and the home is still theirs to read.
    await tester.runAsync(() async {
      await z.vaultLock();
      await ground.refresh();
    });
    await settle(tester);

    // Whatever starts work now leads to the vault: this is the «+» the owner
    // pressed, and the composer behind it.
    expect(find.byType(VaultScreen), findsOneWidget,
        reason: 'the composer was offered with the vault shut');
  });
}

/// A device that has been set up before: the language was chosen and the first
/// run is behind it. Written through the same door the first run uses.
Future<void> _firstRunIsDone(Ground ground) async {
  final now = await z.settings();
  await ground.saveConfig(Settings(
    originalPanePercent: now.originalPanePercent,
    columnsInStep: now.columnsInStep,
    scanOnImport: now.scanOnImport,
    revealSeconds: now.revealSeconds,
    autoLockMinutes: now.autoLockMinutes,
    packId: now.packId,
    language: now.language,
    firstRunDone: true,
    sessionOnly: now.sessionOnly,
  ));
  await ground.refresh();
}

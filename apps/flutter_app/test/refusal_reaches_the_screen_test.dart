// The press that needed a vault and said nothing — human run, 30 September.
//
// The core has refused «Always» without a vault since M4, and it names the
// refusal. The screen caught that sentence and then threw it away: `answer()`
// set `trouble`, and the `refresh()` on the very next line cleared it again on
// success. Nothing was drawn, nothing changed, and the button looked exactly as
// pressable as the ones beside it. A refusal that never reaches a person is the
// same thing as no refusal at all.
//
// Its own file because it needs a device with **no vault**, and the vault is one
// per process — the same reason `vault_screen_test.dart` stands apart.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für die Reise';

/// A document the German pack is unsure about, so there is something to answer.
const _doc =
    'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000';

/// Real futures do not complete inside `testWidgets`' fake-async zone. Same
/// helper, same reason, as the head of `shell_test.dart`.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory dir;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
    dir = Directory('${Directory.systemTemp.path}/zprivacy-refusal-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Opens the document, opens the review, and returns the bench.
  Future<Workbench> bench(WidgetTester tester, Ground ground) async {
    late final Workbench b;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      b = Workbench(session: session, profileId: null, packId: 'de');
      await b.rescan();
      b.openReview();
    });
    return b;
  }

  testWidgets('Always without a vault says which vault is missing, and the '
      'suggestion stays open', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    final b = await bench(tester, ground);

    expect(
      b.snap!.vault,
      VaultState.absent,
      reason: 'this test only means anything on a device with no vault',
    );
    final waiting = b.suggested.length;
    expect(waiting, greaterThan(0), reason: 'there is something to answer');

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: b, ground: ground, onHome: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Always').first);
    await settle(tester);

    // The core's own sentence, not one this test wrote out again: with no vault
    // on the device the next move is to make one, and the line says so.
    expect(
      find.text(humanMessage(const ApiError_VaultAbsent())),
      findsOneWidget,
      reason: 'the refusal is drawn, not swallowed by the refresh after it',
    );
    // And the press changed nothing, which is the other half of not lying.
    expect(
      b.suggested.length,
      waiting,
      reason: 'a refused press leaves the suggestion waiting',
    );

    b.dispose();
  });

  testWidgets('a locked vault is a different sentence from no vault at all', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      await z.vaultLock();
    });

    final ground = Ground();
    final b = await bench(tester, ground);
    expect(b.snap!.vault, VaultState.locked);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: b, ground: ground, onHome: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Always').first);
    await settle(tester);

    expect(
      find.text(humanMessage(const ApiError_VaultLocked())),
      findsOneWidget,
      reason: 'there is a vault here; the next move is to unlock it, not make one',
    );

    b.dispose();
  });
}

// M7.8 — the Z Vault room, against a real vault on disk.
//
// A separate file from `shell_test.dart` on purpose: the vault is one per
// process, and a test that creates one must not run beside tests that assume
// there is none.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/entity_detail.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für den Test';

/// Real futures do not complete inside `testWidgets`' fake-async zone, and a
/// spinner waiting on one never stops. See the head of `shell_test.dart`.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
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
    dir = Directory('${Directory.systemTemp.path}/zprivacy-vault-screen-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('the vault room: locked, made, filled, searched, and pruned', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    await tester.runAsync(ground.refresh);

    await tester.pumpWidget(MaterialApp(home: VaultScreen(ground: ground, onClose: () {})));
    await settle(tester);

    // ---------------------------------------------------------- absent
    // It does not pretend to be an empty list. It says what is missing.
    expect(ground.vault, VaultState.absent);
    expect(find.text('There is no vault yet'), findsOneWidget);
    expect(find.textContaining('the only file this app writes'), findsOneWidget);
    expect(find.text('Create the vault'), findsOneWidget);

    // ---------------------------------------------------------- made
    late final int entityId;
    late final int valueId;
    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      entityId = await z.createEntity(
        kind: EntityKind.client,
        label: 'Nordstern',
        profileId: null,
      );
      valueId = await z.setValue(
        entity: entityId,
        kind: Kind.company,
        text: 'Nordstern Consulting GmbH',
        policy: Policy.always,
      );
      await z.addValueAlias(entity: entityId, valueId: valueId, alias: 'Nordstern Consulting');
      await z.createEntity(kind: EntityKind.person, label: 'Müller', profileId: null);
      await ground.refresh();
      await ground.readVault();
    });
    await settle(tester);

    expect(ground.vault, VaultState.unlocked);
    expect(find.text('Nordstern'), findsOneWidget);
    expect(find.text('Müller'), findsOneWidget);
    // The bar counts what the core reported, and counts it in English: «1
    // value», not «1 values». The first version of this screen got that wrong
    // and this line is why it did not stay wrong.
    expect(find.text('2 identities · 1 value'), findsOneWidget);

    // ---------------------------------------------------------- searched
    // The search runs inside Rust, over real values, and finds one by a value
    // that no label mentions.
    await tester.runAsync(() => ground.searchVaultFor('Consulting'));
    await settle(tester, rounds: 1);
    expect(ground.vaultRows, hasLength(1));
    expect(find.text('Müller'), findsNothing);
    await tester.runAsync(() => ground.searchVaultFor(''));
    await settle(tester, rounds: 1);
    expect(ground.vaultRows, hasLength(2));

    // ---------------------------------------------------------- opened
    await tester.tap(find.text('Nordstern'));
    await settle(tester);
    expect(find.byType(EntityDetail), findsOneWidget);
    expect(find.text('Client · Nordstern'), findsOneWidget);

    // A value is hidden until it is asked for — here as everywhere else.
    expect(find.textContaining('Nordstern Consulting GmbH'), findsNothing);
    expect(find.text('Show'), findsOneWidget);
    // And the kind's name came from the core's list, not a switch in Dart.
    expect(kindRows, isNotEmpty);
    expect(find.text(kindName(Kind.company)), findsOneWidget);

    await tester.tap(find.text('Show'));
    await settle(tester);
    expect(find.text('Nordstern Consulting GmbH'), findsOneWidget);
    // Its spellings come with it: they are the same secret.
    expect(find.text('Nordstern Consulting'), findsOneWidget);

    // ---------------------------------------------------------- pruned
    // Forgetting one spelling leaves the value, and the screen is re-read from
    // the core rather than patched here.
    await tester.runAsync(() async {
      await ground.vaultEdit(() => z.removeValueAlias(
            entity: entityId,
            valueId: valueId,
            alias: 'Nordstern Consulting',
          ));
    });
    await settle(tester);
    await tester.runAsync(() async {
      final shown = await z.revealValue(entity: entityId, valueId: valueId);
      expect(shown.aliases, isEmpty);
      expect(shown.value, 'Nordstern Consulting GmbH');
    });

    // ---------------------------------------------------------- locked
    await tester.runAsync(() async {
      await z.vaultLock();
      await ground.refresh();
      await ground.readVault();
    });
    await settle(tester);
    expect(ground.vault, VaultState.locked);
    expect(ground.vaultRows, isEmpty, reason: 'a locked vault lists nothing');
  });
}

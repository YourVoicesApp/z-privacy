// 041-E · the vault, before the work.
//
// The owner: «the vault should be opened before starting work so we can save
// the words; the suggested words are either kept in the vault or given back
// every time; and pressing Always should offer the vault.»
//
// The third is done — «Always» has carried its own state and opened the vault
// since 041-B. The two that were missing are here: the band under the header
// said «No vault» and could not be pressed, and the first page a person ever
// sees never mentioned the vault at all.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Kunde: Nordstern Consulting GmbH\nAnsprechpartner: Herr Thomas Müller\n';
const _pass = 'ein gutes Passwort';

Directory _own(String name) {
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-before-work-$name-$pid');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  return dir;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('the band\'s vault line is the way in, and says which way', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    final ground = Ground();
    late Workbench bench;
    var toTheVault = 0;

    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: _own('band').path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () => toTheVault++),
    ));
    await settle(tester);

    // The sentence is still said — and now it can be pressed.
    expect(find.textContaining('No vault'), findsOneWidget);
    final make = find.text('Create a vault');
    expect(make, findsOneWidget, reason: 'the band says what is wrong and offers nothing');
    await tester.tap(make);
    await settle(tester);
    expect(toTheVault, 1, reason: 'the band line is still only a sentence');

    // A vault that exists but is shut asks for the other word.
    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      await z.vaultLock();
      await ground.refresh();
      await bench.rescan();
    });
    await settle(tester);
    expect(find.textContaining('Vault locked'), findsOneWidget);
    expect(find.text('Create a vault'), findsNothing, reason: 'it offers to make a vault that exists');
    expect(find.text('Unlock'), findsOneWidget);

    bench.dispose();
  });

  testWidgets('a document opened without a vault is read again once there is one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    final ground = Ground();
    late Workbench bench;

    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: _own('rescan').path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    // Scanned with no vault: no vault layer, and the report says why.
    expect(bench.report!.vault, VaultState.absent);
    expect(
      bench.report!.byLayer.any((l) => l.source == Source.vault),
      isFalse,
      reason: 'a vault layer without a vault',
    );

    // A vault, with a value this document contains — what the owner means by
    // «so we can save the words».
    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      final entity = await z.createEntity(kind: EntityKind.client, label: 'Nordstern', profileId: null);
      await z.setValue(
        entity: entity,
        kind: Kind.company,
        text: 'Nordstern Consulting GmbH',
        policy: Policy.always,
      );
      await ground.refresh();
      await bench.rescanAfterVault();
    });

    expect(bench.report!.vault, VaultState.unlocked);
    expect(
      bench.report!.byLayer.any((l) => l.source == Source.vault && l.count > 0),
      isTrue,
      reason: 'the vault layer did not reach by_layer: ${bench.report!.byLayer}',
    );
    expect(bench.scanNote, isNotNull, reason: 'the band cannot say why this scan happened');

    bench.dispose();
  });

  testWidgets('the whole way: a document, the band, the vault, and back to the work', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    final ground = Ground();
    final dir = _own('journey');
    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);

    // Past the first run — and «Later», because a vault is offered and never
    // forced.
    await tester.tap(find.text('English'));
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await tester.tap(find.text('Later'));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget, reason: '«Later» did not reach Home');

    await tester.tap(find.text('New private session'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, _doc);
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Open and scan'));
    await settle(tester);
    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the session did not open');

    // The band, pressed.
    await tester.tap(find.text('Create a vault'));
    await settle(tester);
    expect(find.byType(VaultScreen), findsOneWidget, reason: 'the band did not open the vault');

    await tester.enterText(find.byType(TextField).at(0), _pass);
    await tester.enterText(find.byType(TextField).at(1), _pass);
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Create the vault'));
    await settle(tester, rounds: 8);

    // Back to the work, by the door the person came through.
    await tester.tap(find.text('Back'));
    await settle(tester, rounds: 10);
    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the vault screen did not give the document back');
    expect(find.textContaining('No vault'), findsNothing, reason: 'the band still says there is no vault');
    expect(
      find.textContaining('after the vault'),
      findsOneWidget,
      reason: 'the band does not say the document was read again',
    );
  });

  testWidgets('the first page offers the vault and explains it, and never insists', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    final ground = Ground();
    final dir = _own('first-run');
    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);

    await tester.tap(find.text('English'));
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Start'));
    await settle(tester);

    // One sentence saying why, and two ways on.
    expect(
      find.textContaining('What you teach Z'),
      findsOneWidget,
      reason: 'the page offers a vault without saying what it is for',
    );
    expect(find.text('Create a vault'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    // Creating goes straight there, and the first run is over either way.
    await tester.tap(find.text('Create a vault'));
    await settle(tester);
    expect(find.byType(VaultScreen), findsOneWidget, reason: '«Create a vault» went nowhere');
  });
}

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

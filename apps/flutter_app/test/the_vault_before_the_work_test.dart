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
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
const _doc = 'Kunde: Nordstern Consulting GmbH\nAnsprechpartner: Herr Thomas Müller\n';
const _pass = 'ein gutes Passwort';

Directory _own(String name) {
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-before-work-$name-$pid');
  removeWhenItLetsGo(dir);
  dir.createSync(recursive: true);
  return dir;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
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
      home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () => toTheVault++),
    ));
    await settle(tester);

    // The sentence is still said — and now it can be pressed.
    expect(find.textContaining('No vault'), findsOneWidget);
    final make = find.text(sentences.createAVault);
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
    expect(find.text(sentences.createAVault), findsNothing, reason: 'it offers to make a vault that exists');
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

    // Past the first run — and through the vault, which since 041-N is the
    // way in rather than an offer. The passphrase goes in through the core:
    // a widget that awaits it does not resume under `testWidgets`, so no test
    // in this app presses «Create the vault» itself.
    await tester.tap(find.text('English'));
    await settle(tester, rounds: 1);
    await tester.tap(find.text(sentences.start));
    await settle(tester);
    await tester.tap(find.text(sentences.createAVault));
    await settle(tester);
    await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: _pass));
    await settle(tester);
    await tester.tap(find.text(sentences.back));
    // The way back runs through the core: close, refresh, and a frame for the
    // shell to notice.
    await settle(tester, rounds: 8);
    // **And it leads on to the one screen** — rule 70. It led to Home until
    // 17 October; what is behind the vault now is the work itself, with
    // nothing in it and the way in at the top of it.
    expect(find.byType(WorkspaceScreen), findsOneWidget,
        reason: 'the vault did not lead on to the work');
    // Rule 72-أ: the «+» for a file, and the one box in the first part.
    expect(find.byKey(WorkspaceScreen.addDocument), findsOneWidget,
        reason: 'the way in for a file is not on the screen the vault leads to');
    expect(find.byKey(WorkspaceScreen.composer), findsOneWidget,
        reason: 'the box a person writes in is not on the screen the vault leads to');

    // 041-G — the box is the way in: no sheet, no question, just the text.
    // By key, because this screen has more than one field in it.
    await tester.enterText(find.byKey(WorkspaceScreen.composer), _doc);
    await settle(tester, rounds: 1);
    // **Rule 72-أ, 18 October 2026**: the strip's box and its «Open and scan»
    // are deleted, and the one box is the request box in the first part. What
    // is written there is the request — protected, and the whole of what leaves
    // when no document stands above it — so this is the same act through the
    // one door there is now.
    await tester.tap(find.byKey(const ValueKey<String>('workspace-question-attach')));
    await settle(tester);
    // **Rule 57b (the owner, 16 October)**: the first text of a new session is
    // asked which language it is in — once, before anything is read, because the
    // scanner needs it before it reads. The fixture answers it exactly as a
    // person does; after that nothing in the session asks again (57c).
    if (find.text(TheLanguageOfANewSession.title).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(TheLanguageOfANewSession.keyFor('de')));
      await settle(tester, rounds: 20);
    }
    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the session did not open');

    // 041-N changed what this journey is. The band used to be where a person
    // first met the vault, because a document could be opened without one; now
    // the vault is behind them before the first word is typed, so the band has
    // nothing to ask for and the sentences that asked are gone.
    expect(find.textContaining('No vault'), findsNothing, reason: 'the band asks for a vault that is open');
    expect(find.text(sentences.createAVault), findsNothing, reason: 'the band offers a vault that exists');
    expect(find.textContaining('Vault locked'), findsNothing, reason: 'the band says a shut vault is shut');

    // What the top bar says instead, which is the whole of what is left to
    // say about it: the vault is open.
    expect(find.text(sentences.vaultIsUnlocked), findsOneWidget, reason: 'the bar does not say the vault is open');
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
    await tester.tap(find.text(sentences.start));
    await settle(tester);

    // One sentence saying why, and one way on. 041-E offered the vault with a
    // «Later» beside it; 041-N took the «Later» out, because what Z learns
    // while a person works is kept in the vault and nowhere else.
    //
    // **And since 089 the sentence leads with what the owner's rule keeps**:
    // every word you protect, not only «the values you protect for good».
    // Looked for by the words a person reads, so a rewording that quietly
    // narrows the promise again is a red here.
    expect(
      find.textContaining('Every word you protect lives here'),
      findsOneWidget,
      reason: 'the page asks for a vault without saying what it keeps',
    );
    expect(find.text(sentences.createAVault), findsOneWidget);
    expect(find.text('Later'), findsNothing, reason: 'there is still a way past the vault');

    // And it goes straight there.
    await tester.tap(find.text(sentences.createAVault));
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

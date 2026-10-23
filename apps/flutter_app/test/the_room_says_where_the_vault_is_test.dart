// **«Your vault is in …»** — 098 item 2, the glass half.
//
// On 20 October the owner's installed Windows build asked him to create a new
// vault while his own vault sat on the same disc. Two installs can do that
// there: a package installed from the `.msix` has its `%LOCALAPPDATA%`
// redirected into the package's own data folder, so `data_dir.rs`'s single
// answer lands in two places — and **no screen in this product named the
// folder**, so a person in that position has nothing to read and no way to
// tell «a second vault» from «my vault is gone».
//
// Which path each Windows install really uses is a measurement for a Windows
// machine (`docs/INBOX/to-windows.md`) and no path is asserted here. This is
// the other half: the room says which folder, in both of the states that
// matter.
//
// **Two sentences, because one of them would be a lie.** With a vault in that
// folder it reads «Your vault is in …». With none — the owner's own screen —
// it reads «A vault here would be in …», which is the state where a person
// most needs the folder and the one a single sentence would get wrong.
//
// And the folder is the **core's** answer, not the screen's: the folder here is
// a temporary one, never the default this machine would choose, so a screen
// that printed `defaultDataDir()` could not show it. That is the whole fault
// the MSIX install would have had — right on Linux, right on the installer
// build, wrong on exactly the install the owner met.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
const _pass = 'ein genügend langes kennwort hier';

Future<void> settle(WidgetTester tester, {int rounds = 3}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

void main() {
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-which-folder-$pid');

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
    removeWhenItLetsGo(dir);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() => removeWhenItLetsGo(dir));

  Future<Ground> room(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ground = Ground();
    await tester.runAsync(ground.refresh);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsScreen(ground: ground, room: SettingsRoom.vault, onClose: () {}),
      ),
    ));
    await settle(tester);
    return ground;
  }

  testWidgets('the vault room names the folder, with a vault and without one', (tester) async {
    // 1 · the owner's own screen: the folder exists, the vault does not.
    final ground = await room(tester);
    expect(ground.vault, VaultState.absent,
        reason: 'this folder is new, so there is no vault in it to read');
    expect(find.text(dir.path), findsOneWidget,
        reason: 'the room does not say which folder it looked in — which is the '
            'screen the owner was asked to create a new vault on');
    expect(find.text(sentences.aVaultHereWouldBeIn), findsOneWidget,
        reason: 'the label promises a vault in a folder that holds none');
    expect(find.text(sentences.yourVaultIsIn), findsNothing,
        reason: 'there is no vault, and «your vault is in» would be a sentence '
            'about a file that does not exist');

    // 2 · and with one, the same folder under the sentence that is now true.
    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      await ground.refresh();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsScreen(ground: ground, room: SettingsRoom.vault, onClose: () {}),
      ),
    ));
    await settle(tester);
    expect(find.text(sentences.yourVaultIsIn), findsOneWidget,
        reason: 'the vault is open in that folder and the room still will not say so');
    expect(find.text(dir.path), findsOneWidget,
        reason: 'the folder went quiet as soon as there was a vault in it');
  });
}

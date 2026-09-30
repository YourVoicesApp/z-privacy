// Which screen is on — the decision itself, not the screens.
//
// This file exists because of a bug that no screen test could have found: the
// shell read `Ground` to choose a screen but did not listen to it, so the
// settings arrived after the first frame and the first-run page never appeared.
// Running the program found it. This test makes sure running it is not the only
// thing that would.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

Future<void> setDataDirForTest(String path) => z.setDataDir(dir: path);

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
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
    dir = Directory('${Directory.systemTemp.path}/zprivacy-shell-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('a fresh device opens on the first-run page, not on Home', (tester) async {
    // Tall enough for both promises: since P2-6 the page carries the German
    // and the English text until a language is chosen, because it has no
    // right to assume one.
    await tester.binding.setSurfaceSize(const Size(1300, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Started outside the fake-async zone, for the reason written on
    // `ZShell.ground`. What is under test is the decision, not the startup.
    final ground = Ground();
    await tester.runAsync(() async {
      await setDataDirForTest(dir.path);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);

    expect(find.byType(FirstRunScreen), findsOneWidget,
        reason: 'the shell must show the first-run page while the core says it is due');
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('No Z Privacy server.'), findsOneWidget);

    // Passing it leaves for Home, in this run at least — the lasting answer
    // needs a vault to be written into, and this device has none.
    //
    // The language is chosen first because there is no Start before one: this
    // test is about which screen the shell picks, and it has to make the
    // page's own decision to get past it.
    await tester.tap(find.text('English'));
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Start'));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.text('Open Z Vault'), findsOneWidget);
  });
}

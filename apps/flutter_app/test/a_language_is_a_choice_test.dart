// 041-Q on the screen: a language with no rules of its own can be chosen, and
// the bar says what ran.
//
// The owner, 6 October, on a build whose vault already held an Arabic list: he
// could not choose Arabic. «The language list holds every language; we have no
// problem with the language rules — we will not include them all.»
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _letter = 'السيد محمد الحربي\nالبريد: m.alharbi@example.com\n';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('the bar names the language, and says when all it has is the general rules',
      (tester) async {
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-lang-choice-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _letter);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);

    // The table reached the screen, and Arabic is in it, named in Arabic.
    expect(ground.languages.length, greaterThan(60), reason: 'the core sent a short list');
    expect(ground.languageName('ar'), 'العربية');
    expect(ground.hasRules('de'), isTrue);
    expect(ground.hasRules('ar'), isFalse);

    // German is a pack: the bar says the pack's own label.
    expect(find.textContaining('Deutsch'), findsWidgets, reason: 'the bar does not name German');

    // Switched to Arabic — which used to be refused outright.
    String? refused;
    await tester.runAsync(() async {
      refused = await bench.switchPack('ar');
    });
    await settle(tester);
    expect(refused, isNull, reason: 'Arabic was refused: $refused');
    expect(bench.packId, 'ar');

    // And the bar says what ran, in the language's own name.
    expect(find.textContaining('العربية'), findsOneWidget, reason: 'the bar does not name Arabic');
    expect(find.textContaining('general rules'), findsOneWidget,
        reason: 'the bar claims rules this build does not have');

    bench.dispose();
  });
}

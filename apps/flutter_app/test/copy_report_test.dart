// «Copy report»: what lands in the clipboard is what the core said, and nothing
// a screen worked out.
//
// The button exists for a tester in another country whose document will not
// open and who cannot send us the document. So two things are tested, and the
// second is the one that matters: that the text is the core's own, and that it
// carries no word of the document or of anything found in it.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// The letter, shortened: enough of it that the scanner finds people, a date of
/// birth and an account — all the things a report must not repeat.
const _doc =
    'Sehr geehrter Herr Markus Weber,\n'
    'Kunde: Nordstern Consulting GmbH\n'
    'Geboren am 3.4.1978, Steuernummer 151/815/08154\n'
    'IBAN: DE89370400440532013000\n';

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory dir;
  final copied = <String>[];

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
    dir = Directory('${Directory.systemTemp.path}/zprivacy-report-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
    // The clipboard is the platform's; in a test it is whatever we record.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('the button copies the core\'s own report, and none of the words', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await settle(tester);

    expect(find.byType(CopyReportButton), findsOneWidget, reason: 'no way to copy a report');
    expect(find.byTooltip('Copy report'), findsOneWidget, reason: 'the icon says nothing on its own');

    copied.clear();
    await tester.tap(find.byType(CopyReportButton));
    await settle(tester);

    expect(copied, hasLength(1), reason: 'the press copied nothing');
    final text = copied.single;

    // What the core says, word for word — not one figure worked out in Dart.
    late final String fromCore;
    await tester.runAsync(() async => fromCore = await bench.reportText());
    expect(text, fromCore);

    // And the promise: numbers, never the document.
    for (final word in ['Weber', 'Markus', 'Nordstern', 'DE89370400440532013000', '151/815/08154', '3.4.1978']) {
      expect(text.contains(word), isFalse, reason: '«$word» is in the copied report');
    }
    expect(text, contains('Z Privacy'));
    expect(text, contains('readable'));
    expect(text, contains('tokens'));
    // The button says it has been pressed, so nobody presses it twice wondering.
    expect(find.byTooltip('Copied'), findsOneWidget);
  });
}

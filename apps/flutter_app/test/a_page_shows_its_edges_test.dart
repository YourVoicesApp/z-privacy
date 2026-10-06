// 041-J · «while reviewing, the page must show its beginning and its end».
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _three =
    'Seite eins mit Herr Thomas Müller.\n\u{c}'
    'Seite zwei mit Frau Sophie Schneider.\n\u{c}'
    'Seite drei: IBAN DE89370400440532013000.\n';
const _one = 'Nur eine Seite, mit Herr Thomas Müller darin.\n';

Future<(Workbench, Ground)> _open(WidgetTester tester, String text) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    await z.vaultLock();
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-pages-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    await z.setDataDir(dir: dir.path);
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    await z.importText(session: session, text: text);
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await bench.rescan();
  });
  await tester.binding.setSurfaceSize(const Size(1500, 1000));
  await tester.pumpWidget(
    MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {})),
  );
  await settle(tester);
  return (bench, ground);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a document of three pages draws its edges, and one page draws none', (tester) async {
    final (bench, _) = await _open(tester, _three);
    expect(bench.document!.pages, 3, reason: 'the reader did not count three pages');
    expect(
      bench.document!.text.split('\u{c}').length - 1,
      2,
      reason: 'three pages, two edges',
    );
    expect(
      find.byKey(OriginalText.pageEdges),
      findsOneWidget,
      reason: 'the column draws no page edges',
    );
    bench.dispose();

    final (single, _) = await _open(tester, _one);
    expect(
      find.byKey(OriginalText.pageEdges),
      findsNothing,
      reason: 'a document of one page has an edge drawn in it',
    );
    single.dispose();
  });

  testWidgets('the edge is for the person reading: it never reaches the payload', (tester) async {
    final (bench, _) = await _open(tester, _three);
    late final String safe;
    await tester.runAsync(() async {
      for (final f in bench.suggested) {
        await z.answerFinding(session: bench.session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();
      safe = bench.payload!.text;
    });
    expect(safe.contains('\u{c}'), isFalse, reason: 'the page edge travelled to the model');
    expect(safe.contains('Seite drei'), isTrue, reason: 'the last page is not in what would leave');
    bench.dispose();
  });

  testWidgets('the bar goes to a page', (tester) async {
    final (bench, _) = await _open(tester, _three);
    await tester.tap(find.byTooltip('Go to a page'));
    await settle(tester);
    await tester.tap(find.text('Page 2').last);
    await settle(tester);

    final focused = bench.focusedFinding;
    expect(focused, isNotNull, reason: 'nothing was pointed at');
    expect(focused!.place?.page, 2, reason: 'the jump landed on page ${focused.place?.page}');
    bench.dispose();
  });
}

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

// «I have 17 names for you to look at» — on the screen, and from the core.
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
import 'package:zprivacy/widgets/name_review.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// A staff list, as one is written. «Kowalski» and «Yilmaz» are in no
/// dictionary this build ships with; «Thomas» and «Sophie» are.
const _doc =
    'Projektteam 2026\n'
    'Kowalski, Thomas — Bauleitung\n'
    'Yilmaz, Sophie — Elektroplanung\n'
    'Die Bauleitung liegt bei Thomas Kowalski.\n'
    'Rückfragen an Sophie Yilmaz.\n';

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
    dir = Directory('${Directory.systemTemp.path}/zprivacy-names-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('the names panel asks once per name, with what the decision is worth', (tester) async {
    tester.view.physicalSize = const Size(1700, 1000);
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

    // The badge knows before the panel is opened, because a scan produced it.
    expect(bench.openCandidates.length, 2, reason: 'the core found no names to ask about');
    expect(find.text('Names'), findsOneWidget);
    expect(find.text('2'), findsWidgets, reason: 'the badge says how many decisions wait');

    await tester.tap(find.text('Names'));
    await settle(tester);

    expect(find.byType(NameReviewPanel), findsOneWidget);
    expect(find.text('2 names to look at'), findsOneWidget);
    // One row per name — never one per occurrence.
    expect(find.text('Kowalski'), findsOneWidget);
    expect(find.text('Yilmaz'), findsOneWidget);
    // What the decision is worth, as the core counted it.
    expect(find.text('2 places · 1 page'), findsNWidgets(2));
    expect(find.text('Add as family name'), findsNWidgets(2));
    // And a line of context, as the document writes it.
    expect(
      find.textContaining('Kowalski, Thomas', findRichText: true),
      findsWidgets,
      reason: 'a row without an example is a row nobody can decide on',
    );

    // Ignore asks no more about that one, and writes nothing.
    await tester.tap(find.text('Ignore').first);
    await settle(tester);
    expect(find.text('1 name to look at'), findsOneWidget);
    expect(bench.ignored.length, 1);
  });
}

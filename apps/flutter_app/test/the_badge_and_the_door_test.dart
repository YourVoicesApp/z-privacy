// **The owner's second finding of 9 October**, on steuern-von-a-z.pdf, 146
// pages, from the 3701ee8 bundle.
//
// He pressed **Review**, whose badge said **8**, and the panel that opened said
// **«No names to look at»** — the *Names* panel's own sentence, with the
// separate «8 questions left — go to the first» button still sitting below it.
// A counter promising eight answers, and a door opening a room about something
// else.
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
import 'package:zprivacy/widgets/review.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// A staff list **and** a contract number, because the two counters come from
/// two different places and this test needs both non-zero at once.
///
/// Measured, not assumed: the staff list alone gives **zero findings** — its
/// two unknown surnames are *candidates*, which is a different list from the
/// suggestions the Review badge counts. The contract number is what leaves a
/// question open («Suggested/Contract»), and the IBAN is protected outright.
/// Without the number both guards below failed at their own precondition,
/// which is a red that proves nothing about the product.
const _doc =
    'Projektteam 2026\n'
    'Rechnung 2026-114\n'
    'Al-Hassan, Mahmoud — Bauleitung\n'
    'Okonkwo, Sophie — Elektroplanung\n'
    'Die Bauleitung liegt bei Mahmoud Al-Hassan.\n'
    'Rückfragen an Sophie Okonkwo.\n'
    'IBAN: DE89 3704 0044 0532 0130 00\n';

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
    dir = Directory('${Directory.systemTemp.path}/zprivacy-badge-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<(Workbench, Ground)> ready(WidgetTester tester) async {
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
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);
    return (bench, ground);
  }

  /// **The control: with nothing else open, Review opens the review.**
  ///
  /// Without this the test below could pass on a button that never works, and
  /// the finding would be «the Review button is broken» instead of what it is.
  testWidgets('review opens the review when no other panel is open', (tester) async {
    final (bench, _) = await ready(tester);
    expect(
      bench.openSuggestions > 0,
      isTrue,
      reason: 'this document must leave questions open, or the badge means nothing',
    );

    await tester.tap(find.text('Review'));
    await settle(tester);

    expect(find.byType(ReviewPanel), findsOneWidget);
    expect(find.byType(NameReviewPanel), findsNothing);
  });

  /// **The finding: the badge says eight and the door opens the other room.**
  ///
  /// The two panels share one slot and are chosen by two independent booleans —
  /// `reviewingNames` first, `reviewOpen` second. `openNameReview()` sets
  /// **both**, so once the names panel has been opened the Review button cannot
  /// show the review at all: one press reads «already open» and calls
  /// `closeReview()`, which clears the boolean nobody is reading.
  ///
  /// Two bools for one slot have a fourth corner that means nothing — the rule
  /// this codebase already states above `Piece`, where it is obeyed.
  testWidgets('review opens the review even after the names panel has been opened', (tester) async {
    final (bench, _) = await ready(tester);
    final waiting = bench.openSuggestions;
    expect(waiting > 0, isTrue, reason: 'the badge must be promising something');

    await tester.tap(find.text('Names'));
    await settle(tester);
    expect(find.byType(NameReviewPanel), findsOneWidget, reason: 'the names panel is what was asked for');

    // Now the act the owner performed: press Review, whose badge is the count
    // of questions still open.
    await tester.tap(find.text('Review'));
    await settle(tester);

    expect(
      find.byType(ReviewPanel),
      findsOneWidget,
      reason: 'the badge said $waiting questions and the door must open that room',
    );
    expect(
      find.byType(NameReviewPanel),
      findsNothing,
      reason: 'and it must not be the names panel, which is what the owner met',
    );
    expect(
      find.text('No names to look at'),
      findsNothing,
      reason: 'the owner pressed a button promising $waiting answers and read this sentence',
    );
  });
}

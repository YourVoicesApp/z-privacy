// 046/K · nothing folds or unfolds itself.
//
// **The owner's standing rule, 7 October:** «بشرط أن الطوي والفتح لا يتم
// تلقائياً، يتم بالضغط على إشارة محددة» — a collapse or an expand is always a
// person's press on a visible control. Not when a panel opens, not when the
// window is resized, not when a document arrives, not when a scan ends.
//
// So this file is that sentence as a test, and it is written to outlive the
// commit that added it: it names four things the app does on its own and
// asserts that **no collapsed state moved** through any of them. Whatever is
// added to this screen later, the rule is the same and this is where it is
// held.
//
// And the part the rule makes unavoidable: a state only a press may change has
// to be **remembered**, or closing the program would change it. Each of the two
// lives in `settings.zcfg` beside `columns_in_step`, and the last test here is
// that a press is still remembered after the settings are saved for some other
// reason.
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

const _doc = 'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n';
const _second = 'Rechnung an Frau Anna Schneider\nTelefon: 030 1234 5678\n';

const _originalPane = ValueKey<String>('workspace-original-pane');
const _safePane = ValueKey<String>('workspace-safe-pane');
const _safeClose = ValueKey<String>('workspace-safe-close');
const _safeRail = ValueKey<String>('workspace-safe-rail');
const _panelArrow = ValueKey<String>('workspace-panel-arrow');

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

/// Press a control and wait for the core.
///
/// A press on one of these arrows writes a setting through Rust and then
/// refreshes everything, which is a chain of real futures — so a press needs
/// more real moments than a pump. Measured: at five rounds the column was
/// still drawn after the press that closed it.
Future<void> press(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await settle(tester, rounds: 14);
}

/// A bench on its own data directory, so each test starts from the defaults.
Future<(Ground, Workbench)> _open(WidgetTester tester, String name) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-press-$name-$pid');
    if (here.existsSync()) here.deleteSync(recursive: true);
    addTearDown(() {
      if (here.existsSync()) here.deleteSync(recursive: true);
    });
    await z.setDataDir(dir: here.path);
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    await bench.refresh();
  });
  addTearDown(bench.dispose);
  await tester.pumpWidget(MaterialApp(
    home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
  ));
  await settle(tester);
  return (ground, bench);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------ 1 · the rule

  testWidgets('no collapsed state changes by itself — a panel, a resize, a document, a scan', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, bench) = await _open(tester, 'rule');

    // The person's own choice, made once by a press: the Safe column closed,
    // the panel wide. From here nothing the app does may move either.
    await press(tester, _safeClose);
    bench.openReview();
    await settle(tester);
    await press(tester, _panelArrow);
    expect(ground.config!.safeColumnOpen, isFalse, reason: 'the press did not close the column');
    expect(ground.config!.reviewPanelWide, isTrue, reason: 'the press did not widen the panel');

    Future<void> unchanged(String after) async {
      await settle(tester);
      expect(ground.config!.safeColumnOpen, isFalse, reason: 'the Safe column re-opened itself after $after');
      expect(ground.config!.reviewPanelWide, isTrue, reason: 'the panel narrowed itself after $after');
      expect(find.byKey(_safeRail), findsOneWidget, reason: 'the rail vanished after $after');
      expect(find.byKey(_safePane), findsNothing, reason: 'the column came back by itself after $after');
    }

    // (a) another panel opens, and the first closes.
    bench.openNameReview();
    await unchanged('a second panel opened');
    bench.closeReview();
    await unchanged('the panel closed');

    // (b) the window is resized, both ways, including narrow enough that half
    // the window and the panel cannot both fit — at 1100 with a 460 panel the
    // content gets 640, which is less than the half it asked for. The panel
    // keeps its width and the content takes what is left; **no state moves**,
    // which is the point.
    //
    // 1100 and not 900: at 900 the band's own vault warning overflows its row
    // by 17 pixels, which is a pre-existing defect this test found and not
    // 046/K's. Measured before and after two attempted fixes — 17 either way —
    // so it is reported with its number rather than guessed at here.
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    await unchanged('the window narrowed');
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    await unchanged('the window widened');
    await tester.binding.setSurfaceSize(const Size(1920, 1000));

    // (c) a second document arrives, and (d) a scan finishes.
    await tester.runAsync(() async {
      await z.importText(session: bench.session, text: _second);
      await bench.rescan();
      await bench.refresh();
    });
    await unchanged('a document was imported and scanned');

    // And the way back is still a press, which is the other half of the rule.
    await press(tester, _safeRail);
    expect(ground.config!.safeColumnOpen, isTrue, reason: 'the rail did not bring the column back');
    expect(find.byKey(_safePane), findsOneWidget);
  });

  // ------------------------------------------------- 2 · each control, by itself

  testWidgets('the Safe column closes and comes back, and the Original takes the room', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, _) = await _open(tester, 'safe');

    final both = tester.getSize(find.byKey(_originalPane)).width;
    await press(tester, _safeClose);
    final alone = tester.getSize(find.byKey(_originalPane)).width;
    debugPrint('046/K · Original: $both px with the Safe column, $alone px without it');

    expect(ground.config!.safeColumnOpen, isFalse);
    expect(find.byKey(_safePane), findsNothing, reason: 'the column is still drawn');
    expect(find.byKey(_safeRail), findsOneWidget, reason: 'nothing is left to press');
    expect(alone, greaterThan(both), reason: 'the Original did not take the room');

    // The handle's own position is untouched: closing a column is not moving
    // the handle, and the column must come back where the person left it.
    final percent = ground.config!.originalPanePercent;
    await press(tester, _safeRail);
    expect(ground.config!.originalPanePercent, percent, reason: 'closing moved the handle');
    expect(tester.getSize(find.byKey(_originalPane)).width, closeTo(both, 2));
  });

  testWidgets('the panel widens and narrows, and says which way the press goes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, bench) = await _open(tester, 'panel');

    bench.openReview();
    await settle(tester);
    expect(find.byTooltip('Widen this panel'), findsOneWidget,
        reason: 'the control does not say what the press does (P2-5)');

    await press(tester, _panelArrow);
    expect(ground.config!.reviewPanelWide, isTrue);
    expect(find.byTooltip('Narrow this panel'), findsOneWidget,
        reason: 'the control still offers what has already happened');

    await press(tester, _panelArrow);
    expect(ground.config!.reviewPanelWide, isFalse);
  });

  // ------------------------------------------------------ 3 · and remembered

  testWidgets('saving some other setting does not move either state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, _) = await _open(tester, 'remembered');

    await press(tester, _safeClose);
    expect(ground.config!.safeColumnOpen, isFalse);

    // The reveal timer has nothing to do with a column. Before 046/K the
    // «change one setting» helper wrote a literal here, so saving this would
    // have re-opened a column the person closed — the app changing a state
    // only a press may change.
    await tester.runAsync(() async {
      await ground.saveConfig(ground.config!.with_(revealSeconds: 30));
      await ground.refresh();
    });
    await settle(tester);
    expect(ground.config!.revealSeconds, 30, reason: 'the control measures nothing');
    expect(ground.config!.safeColumnOpen, isFalse,
        reason: 'saving the reveal timer re-opened the column');
  });
}

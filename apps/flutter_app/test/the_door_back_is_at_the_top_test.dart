// 108 item 3 · «z-pdf» stands at the top of the screen.
//
// The owner, 24 October 2026: «زر جلب وثيقة Z-PDF نجعله خياراً منفصلاً في أعلى
// الشاشة؛ الآن مكانه مخفي» — the button that brings a Z-PDF document back is
// to be a separate option at the top of the screen; where it is now is hidden.
//
// **This amends rule 70's placing, and both dates are his.** On 17 October the
// first screen was deleted and its «+» menu with it, and the press went into
// the Settings panel by his own word («نجعل الإعدادات تحتوي على إدخال z-pdf»).
// Reachable is not findable: on his own Windows evenings he did not find it.
// The act is unchanged — `_readBack` in the shell, the vault gate of 079 rule
// 8 included — and only the place it is pressed from moved.
//
// ## What is measured here
//
//   * the door is on the glass, in the band above the three parts, with and
//     without a document — it takes no bench at all;
//   * **it does not cost the bar its contents at 900**, which is the number
//     this bar is governed by: 2.8 px of margin before 064/B, 0 with the
//     session's name on it, and «a new element in the tree breaks every
//     `.first`». A fresh tree per width, because an overflow is reported once
//     per render object for its whole life;
//   * a press reaches the shell's callback — the press is pure glass, so this
//     one really is a tap;
//   * **the shell hands it down**, which is the half no signature can catch:
//     `a_test_door_may_not_gate_a_product_act` is this house's own name for a
//     product act that nobody wired, 401 tests green;
//   * and the Settings room no longer offers a second press, because one act
//     pressed in two places is two things to keep true.
//
// **Watched red before it was trusted**: with the `if (onReadBack != null)`
// block taken off `_TopBar` — the product exactly as at `c0326af` — guard 1
// reads «no z-pdf door at the top of the screen» and guard 5 «the shell's own
// screen has no door back».
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
const _doc = 'Kunde: Nordstern Consulting GmbH\nIBAN DE02120300000000202051\n';

/// The press, by what it is. Spelled here as the one place this file names it,
/// so a reader sees that nothing in it looks for the word on the button.
const _theDoorBack = ValueKey<String>('top-bar-z-pdf');

Future<void> _settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

List<String> _overflows(WidgetTester tester) {
  final found = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    found.add(e.toString());
  }
  return found;
}

Directory _ownDir(String name) {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-doorback-$name-$pid');
  removeWhenItLetsGo(own);
  addTearDown(() {
    removeWhenItLetsGo(own);
  });
  return own;
}

/// A vault, a document on a bench, and a session with the name it is given —
/// the state the bar is at its most crowded in.
Future<({Ground ground, Workbench bench})> _ready(
  WidgetTester tester,
  String name, {
  String sessionName = 'Nordstern',
}) async {
  late final ({Ground ground, Workbench bench}) made;
  await tester.runAsync(() async {
    final own = _ownDir(name);
    own.createSync(recursive: true);
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för dörren');
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    await ground.refresh();
    final renamed = await ground.beginSession(sessionName, bench: session);
    if (renamed == null) throw StateError('the fixture could not begin a session: ${ground.trouble}');
    await bench.refresh();
    made = (ground: ground, bench: bench);
  });
  return made;
}

Widget _workspace(
  ({Ground ground, Workbench bench})? g, {
  Ground? empty,
  VoidCallback? onReadBack,
}) => MaterialApp(
  home: WorkspaceScreen(
    bench: g?.bench,
    ground: g?.ground ?? empty!,
    onImport: () {}, onAsk: (_) {},
    onVault: () {},
    onSettings: (_) {},
    onReadBack: onReadBack,
  ),
);

/// A device that has been set up before, written through the door the first run
/// uses — the same helper `no_work_without_a_vault_test` keeps.
Future<void> _firstRunIsDone(Ground ground) async {
  final now = await z.settings();
  await ground.saveConfig(Settings(
    originalPanePercent: now.originalPanePercent,
    columnsInStep: now.columnsInStep,
    safeColumnOpen: true,
    reviewPanelWide: false,
    scanOnImport: now.scanOnImport,
    revealSeconds: now.revealSeconds,
    autoLockMinutes: now.autoLockMinutes,
    packId: now.packId,
    language: now.language,
    firstRunDone: true,
    sessionOnly: now.sessionOnly,
  ));
  await ground.refresh();
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('the door back stands at the top, over the work, and a press reaches the shell',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var cameBack = 0;
    final g = await _ready(tester, 'top');
    await tester.pumpWidget(_workspace(g, onReadBack: () => cameBack += 1));
    await _settle(tester);

    final door = find.byKey(_theDoorBack);
    expect(door, findsOneWidget, reason: 'no z-pdf door at the top of the screen');
    final r = tester.getRect(door);
    // **In the band above the work.** «At the top of the screen» is a place and
    // not a feeling: the three parts begin under the bar and the strip, and
    // this press stands over both.
    final parts = find.text('ORIGINAL — LOCAL ONLY');
    expect(parts, findsOneWidget, reason: 'the first part is not drawn, so there is no work to be above');
    expect(r.bottom, lessThan(tester.getRect(parts).top),
        reason: 'the door back is drawn inside the work rather than above it: $r');
    expect(r.right, lessThanOrEqualTo(1400), reason: 'the door back is off a 1400-wide window: $r');
    expect(_overflows(tester), isEmpty, reason: 'the bar overflows at 1400 with the door back on it');

    // The press is pure glass — no core call behind it — so this one is a tap.
    await tester.tap(door);
    await tester.pump();
    expect(cameBack, 1, reason: 'the press at the top of the screen opened nothing');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **The number this bar is governed by.** 064/B measured 2.8 px of margin at
  // 900 before the session's name was on it and 0 after, and the lead's rule
  // was given before that line: if 900 cannot hold all of it, the page count
  // is the first thing sacrificed. A new element here is a layout change
  // whether or not it is drawn as one — 063 shipped a settings door at x = 907
  // on a 900-wide window, green, because three guards asked whether it existed
  // and none asked where it was.
  //
  // **Measured, 24 October 2026:** the door is 109.5 px wide and stands at
  // x 887.2–996.7 on a 1400-wide window and at 612.3–721.8 on a 900-wide one,
  // with no overflow at either. The bar pays for it out of the session's name,
  // which comes back from its full width to 91 px with an ellipsis at 900 —
  // the name gives way, it does not push, which is this bar's own law.
  testWidgets('900 wide holds it, with a document, a session and a name that is a sentence',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'w900',
        sessionName: 'the quarterly reconciliation against the Nordstern ledger, second pass');
    await tester.pumpWidget(_workspace(g, onReadBack: () {}));
    await _settle(tester);

    final door = find.byKey(_theDoorBack);
    expect(door, findsOneWidget, reason: 'the door back is gone at 900 wide');
    final r = tester.getRect(door);
    expect(r.right, lessThanOrEqualTo(900),
        reason: 'the door back hangs off a 900-wide window at $r — 063’s own defect again');
    expect(_overflows(tester), isEmpty,
        reason: 'the bar overflows at 900 with the door back on it: it must be paid for, not pushed');

    // The last control on this bar is the one 063 lost; a new element may not
    // put it where no press reaches it.
    final settings = find.byTooltip('Settings');
    expect(settings, findsWidgets, reason: 'no settings door on the bar to measure');
    expect(tester.getRect(settings.first).right, lessThanOrEqualTo(900),
        reason: 'the door back pushed the settings door off the glass');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **It takes no bench at all** (079 rule 5), so the ordinary case for it is a
  // person with a z-pdf on their disc and nothing on the surface.
  testWidgets('with nothing open the door back is still there', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());
    await tester.pumpWidget(_workspace(null, empty: ground, onReadBack: () {}));
    await _settle(tester, rounds: 2);

    expect(find.byKey(_theDoorBack), findsOneWidget,
        reason: 'the door back waits for a document it never needed');
    expect(_overflows(tester), isEmpty, reason: 'the bar overflows with nothing on the surface');
  });

  // ------------------------------------------------------------------ guard 4
  testWidgets('no shell behind the screen, no door drawn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());
    await tester.pumpWidget(_workspace(null, empty: ground));
    await _settle(tester, rounds: 2);

    expect(find.byKey(_theDoorBack), findsNothing,
        reason: 'a door that opens nothing is drawn — 083a, and rule 35');
  });

  // ------------------------------------------------------------------ guard 5
  //
  // **The half no signature catches.** A nullable callback the shell forgets to
  // pass is a product act nobody can reach, with every other guard in this file
  // green: `a_test_door_may_not_gate_a_product_act` is the house's own name for
  // it, and it cost 401 green tests once.
  testWidgets('the shell gives its screen the door', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final own = _ownDir('shell');
    own.createSync(recursive: true);
    final ground = Ground();
    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: own.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för skalet');
      await ground.refresh();
      await _firstRunIsDone(ground);
    });

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: own.path, ground: ground)));
    await _settle(tester);

    final screen = find.byType(WorkspaceScreen);
    expect(screen, findsOneWidget, reason: 'the shell is not on the work screen: ${ground.vault}');
    expect(tester.widget<WorkspaceScreen>(screen).onReadBack, isNotNull,
        reason: 'the shell’s own screen has no door back — nobody wired the act');
    expect(find.byKey(_theDoorBack), findsOneWidget,
        reason: 'the door back is not on the glass of the app’s own screen');
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **One act, one press.** The Vault room keeps the sentence that says what a
  // z-pdf is — that is a privacy statement and the room's own job — and offers
  // no second door: two presses for one act are two things to keep true, and a
  // sentence there naming where the press stands would be a third.
  testWidgets('the settings room says what a z-pdf is and presses nothing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsScreen(
          ground: ground,
          room: SettingsRoom.vault,
          onClose: () {},
        ),
      ),
    ));
    await _settle(tester, rounds: 2);

    expect(find.text(sentences.zPdfReadBack), findsOneWidget,
        reason: 'the vault room stopped saying what a z-pdf is');
    expect(find.text(sentences.chooseAZPdfFile), findsNothing,
        reason: 'the settings still press the door back — one act, two places');
    expect(find.byKey(const ValueKey<String>('settings-z-pdf')), findsNothing,
        reason: 'the old press is still in the panel');
  });
}

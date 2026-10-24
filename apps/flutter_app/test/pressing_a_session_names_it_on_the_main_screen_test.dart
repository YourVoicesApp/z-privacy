// 108 item 1 · A press on a session puts its name on the main screen.
//
// The owner, 24 October 2026, out of his own Windows evenings: «عند الضغط على
// الجلسة يجب أن يظهر اسم الجلسة على الشاشة الرئيسة» — when the session is
// pressed, its name must stand on the main screen.
//
// ## What was wrong, exactly
//
// The name was already drawn in the head whenever a session was open — 064/B,
// and since 22 October with no document in the preview either. What was
// missing is the **press**: since 075b a press on a session's name was a look
// (`showConversation`), and the only act that moved «which session is open»
// was the row's own «Enter». So a person who pressed the name he could see,
// read what it kept and closed it, stood in front of a head still naming the
// session he had left — which is exactly what the owner met.
//
// ## How this is driven, and in two ways on purpose
//
// The order lives in one function, `goToTheSession`, because two presses make
// the same act — the room's row and the head's own chip — and a law written at
// one of two doors is this house's most expensive trap. Guards 1 to 3 drive
// that function exactly as the presses do (`beginThenRead`'s own reason) and
// read the head, which is where the owner's claim is.
//
// Guard 4 is the other half: a **real tap** on a real row in the panel, which
// is what proves the `InkWell` reaches the function at all — «a test door may
// not gate a product act» is what this house calls a wired-to-nothing press,
// and it cost 401 green tests once.
//
// **And the tap completes, which is worth writing down**: a core call started
// from a widget callback does finish under `testWidgets` when the settling
// gives it real time (`runAsync` with a delay, ten rounds here).
// `a_session_is_a_room_in_the_panel_test` records the opposite about its own
// «Enter» press — measured on 19 October and left in its comment — so one of
// the two readings is about something else in that press rather than about the
// harness. Named rather than quietly contradicted.
//
// **Watched red before it was trusted**: with the `ground.enterSession` line
// taken out of `goToTheSession` — which is the product exactly as it stood at
// `c0326af` — guard 1 reads «the head still names «andra»» and guard 2 reads
// «the core still holds 2 open».
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/conversation_view.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
const _doc = 'Kunde: Nordstern Consulting GmbH\nIBAN DE02120300000000202051\n';

Future<void> _settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// A vault, a document on a bench, and more than one session — "andra" the
/// open one, because that is the state in which «the head names the one I
/// pressed» is a claim at all.
///
/// **Numbers are never written here.** The import above births one of its own
/// (rule 55: a session is born at its first document), so the two named ones
/// are 2 and 3 — this file learnt that from its own red. Every row is found by
/// the name the fixture gave it.
Future<({Ground ground, Workbench bench})> _twoSessions(WidgetTester tester, String name) async {
  late final ({Ground ground, Workbench bench}) made;
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-press-$name-$pid');
    removeWhenItLetsGo(own);
    own.createSync(recursive: true);
    addTearDown(() {
      removeWhenItLetsGo(own);
    });
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för trycket');
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    await ground.refresh();
    for (final one in ['första', 'andra']) {
      final renamed = await ground.beginSession(one, bench: session);
      if (renamed == null) throw StateError('the fixture could not begin a session: ${ground.trouble}');
    }
    await bench.refresh();
    made = (ground: ground, bench: bench);
  });
  return made;
}

Widget _workspace(({Ground ground, Workbench bench}) g) => MaterialApp(
  home: WorkspaceScreen(
    bench: g.bench,
    ground: g.ground,
    onImport: () {}, onAsk: (_) {},
    onVault: () {},
    onSettings: (_) {},
  ),
);

/// The press, driven the way the two call sites drive it — and **not awaited to
/// the end**, because the last thing it does is open a dialog that stands until
/// a person closes it. The real async time is what lets the core call inside it
/// finish; the pumps afterwards are what draw the result.
Future<void> _press(
  WidgetTester tester,
  ({Ground ground, Workbench bench}) g,
  ConversationRow row,
) async {
  final context = tester.element(find.byType(WorkspaceScreen));
  await tester.runAsync(() async {
    unawaited(goToTheSession(context, g.ground, row, bench: g.bench.session));
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('pressing the other session puts its name in the head', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _twoSessions(tester, 'head');
    await tester.pumpWidget(_workspace(g));
    await _settle(tester);

    // The premise, stated rather than assumed: the session begun last is the
    // open one and the head says so.
    final andra = g.ground.sessions.firstWhere((s) => s.name == 'andra');
    expect(g.ground.openSession, andra.number,
        reason: 'the fixture did not leave «andra» open');
    expect(
      find.descendant(of: find.byKey(TheOpenSession.mark), matching: find.textContaining('andra')),
      findsOneWidget,
      reason: 'the head does not name the open session before the press',
    );

    final first = g.ground.sessions.firstWhere((s) => s.name == 'första');
    await _press(tester, g, first);

    // **The core moved**, which is the one source the head reads.
    expect(g.ground.openSession, first.number,
        reason: 'the press did not make the pressed session the open one — the core still holds '
            '${g.ground.openSession}');
    expect(
      find.descendant(of: find.byKey(TheOpenSession.mark), matching: find.textContaining('första')),
      findsOneWidget,
      reason: 'the head does not name the session that was pressed',
    );
    expect(
      find.descendant(of: find.byKey(TheOpenSession.mark), matching: find.textContaining('andra')),
      findsNothing,
      reason: 'the head still names the session the person left',
    );
    // And the look itself still happened: entering is not instead of showing.
    expect(find.byKey(ConversationView.screen), findsOneWidget,
        reason: 'the press entered the session and never showed what it kept');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **The session a person is already in costs no call and no re-derivation.**
  // The head's own chip presses the same function, and it is always this case:
  // if it entered anyway, every look at your own session would re-name the
  // tokens on the document in front of you.
  testWidgets('pressing the session you are in enters nothing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _twoSessions(tester, 'same');
    await tester.pumpWidget(_workspace(g));
    await _settle(tester);

    final open = g.ground.sessions.firstWhere((s) => s.name == 'andra');
    final was = g.ground.openSession;
    await _press(tester, g, open);

    expect(g.ground.openSession, was, reason: 'a look at the open session moved which one is open');
    expect(find.byKey(ConversationView.screen), findsOneWidget,
        reason: 'a press on the open session showed nothing');
    expect(
      find.descendant(of: find.byKey(TheOpenSession.mark), matching: find.textContaining('andra')),
      findsOneWidget,
      reason: 'the head stopped naming the session it is in',
    );
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **The press itself, in the room it is made in** — the half the three guards
  // above leave out, because they drive the function the two presses call. This
  // is a real tap on a real row, in the panel mounted on its own, and what it
  // measures is that the `InkWell` on a session's name reaches
  // `goToTheSession`: the head is not in this tree, and «which session the core
  // holds open» is the one fact the head reads.
  //
  // It is here and not in `a_session_is_a_room_in_the_panel_test` because the
  // claim is this paper's; that file measures the room.
  testWidgets('a tap on the session’s name in the room enters it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _twoSessions(tester, 'tap');
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        ground: g.ground,
        onClose: () {},
        room: SettingsRoom.sessions,
        bench: g.bench.session,
      ),
    ));
    await _settle(tester);

    final andra = g.ground.sessions.firstWhere((s) => s.name == 'andra');
    expect(g.ground.openSession, andra.number, reason: 'the fixture did not leave «andra» open');

    final name = find.text('första');
    expect(name, findsOneWidget, reason: 'the room does not draw the other session’s name');
    await tester.tap(name);
    await _settle(tester, rounds: 10);

    final first = g.ground.sessions.firstWhere((s) => s.name == 'första');
    expect(g.ground.openSession, first.number,
        reason: 'the press on the name is still a look — the core holds '
            '${g.ground.openSession}');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **A rename keeps the press's answer true**, because the head reads the
  // ground's own row and never a string a screen kept — the seam lesson: a
  // guard cannot tell two sources apart while they agree, so this is the case
  // where they would differ.
  testWidgets('a renamed session is renamed in the head', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _twoSessions(tester, 'rename');
    await tester.pumpWidget(_workspace(g));
    await _settle(tester);

    final open = g.ground.sessions.firstWhere((s) => s.name == 'andra');
    await tester.runAsync(() => g.ground.renameSession(open.number, 'tredje kvartalet'));
    await _settle(tester);

    expect(
      find.descendant(
        of: find.byKey(TheOpenSession.mark),
        matching: find.textContaining('tredje kvartalet'),
      ),
      findsOneWidget,
      reason: 'the head carries a name of its own rather than the session’s',
    );
  });
}

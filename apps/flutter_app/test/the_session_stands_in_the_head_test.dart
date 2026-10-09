// 064/B · A session is a direction of work, so its name stands in the head.
//
// The owner, 9 October: he made his first session, opened it, and found its
// name **only** in the panel's list while the head of the screen carried the
// file's name alone. His reason, in his words: «أكثر من جلسة يعني أكثر اتجاه
// عمل» — more than one session means more than one direction of work. So while
// a session is open its name stands at the top of the screen, beside the
// document's. The ink line inside the send sheet stays; this is its sibling on
// the main glass.
//
// ## The constraint was measured before a line was written
//
// The workspace's top bar is the most crowded strip in this app, and its own
// comments carry the numbers: 41 px over at a 900-wide window once the back
// control and the AI door were on it, and **2.8 px** of margin after
// «Documents» was made to give way. A name added there is a layout change
// whether or not it is drawn as one — 063 shipped a settings door at x = 907
// on a 900-wide window, green, because three guards asked whether it existed
// and none asked where it was.
//
// So the lead's rule for this bar, given before the line: **if 900 cannot hold
// all of it, the page count is the first thing sacrificed** — the Page menu
// says it again whenever there is more than one page, and nothing but the
// session's own name says the session.
//
// ## Two instruments, two properties
//
//   * «is this name on the glass and reachable» → a rect, against the bar's
//     rect and the window;
//   * «is anything laid out past its box» → the drained overflow count, **with
//     a fresh tree per width**, because `DebugOverflowIndicatorMixin` reports
//     once per render object for its whole life and a second reading down the
//     same tree comes back empty whatever the truth is.
//
// And the zero is only worth quoting next to a one, so a deliberately narrow
// window reads non-zero in the same file.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Kunde: Nordstern Consulting GmbH\nIBAN DE02120300000000202051\n';

Future<void> _settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// Everything drained, as a list, so a count is a count and an undrained
/// exception never surfaces in a later test as that test's own fault.
List<String> _overflows(WidgetTester tester) {
  final found = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    found.add(e.toString());
  }
  return found;
}

Future<({Ground ground, Workbench bench})> _ready(
  WidgetTester tester,
  String name, {
  bool withASession = true,
  bool withAVault = true,
  String sessionName = 'Nordstern',
}) async {
  late final ({Ground ground, Workbench bench}) made;
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-head-$name-$pid');
    if (own.existsSync()) own.deleteSync(recursive: true);
    own.createSync(recursive: true);
    addTearDown(() {
      if (own.existsSync()) own.deleteSync(recursive: true);
    });
    final ground = Ground();
    // The core's vault state is global to the isolate; this fixture states its
    // own premise rather than inheriting one.
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    if (withAVault) {
      await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för huvudet');
    }
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    await ground.refresh();
    if (withASession) {
      final renamed = await ground.beginSession(sessionName, bench: session);
      if (renamed == null) throw StateError('the fixture could not begin a session: ${ground.trouble}');
      await bench.refresh();
    }
    made = (ground: ground, bench: bench);
  });
  return made;
}

Widget _workspace(({Ground ground, Workbench bench}) g) => MaterialApp(
  home: WorkspaceScreen(
    bench: g.bench,
    ground: g.ground,
    onHome: () {},
    onVault: () {},
    onSettings: () {},
  ),
);

Widget _home(Ground ground, Workbench? chat) => MaterialApp(
  home: HomeScreen(
    ground: ground,
    version: 'z_core 0.1.0 · 3701ee8',
    chat: chat,
    onImport: () {},
    onType: (_) {},
    onAsk: (_) async {},
    onVault: () {},
    onSettings: () {},
  ),
);

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('the document’s head names the session it is being worked in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'workspace');
    await tester.pumpWidget(_workspace(g));
    await _settle(tester);

    final mark = find.byKey(TheOpenSession.mark);
    expect(mark, findsOneWidget, reason: 'the head says nothing about the open session');
    // Its name, not its number alone: the number is the identity, the name is
    // what a person called this direction of work.
    expect(
      find.descendant(of: mark, matching: find.textContaining('Nordstern')),
      findsOneWidget,
      reason: 'the head does not carry the session’s own name',
    );
    // **Beside the file's name, and both on the glass.** The two facts are one
    // statement — this document, in this session — so a guard that found the
    // name anywhere on the screen would not be measuring the owner's claim.
    final doc = find.text('Typed text');
    expect(doc, findsOneWidget, reason: 'the document’s own name left the bar');
    final r = tester.getRect(mark);
    final d = tester.getRect(doc);
    expect(r.left, greaterThan(d.left), reason: 'the session is drawn before the document it is about');
    expect((r.center.dy - d.center.dy).abs(), lessThan(14),
        reason: 'the two names are not on one line: session $r, document $d');
    expect(r.right, lessThanOrEqualTo(1400), reason: 'the session’s name is off a 1400-wide window: $r');
    expect(_overflows(tester), isEmpty, reason: 'the bar overflows at 1400 with the session on it');
  });

  // ------------------------------------------------------------------ guard 2
  testWidgets('no session, nothing drawn — on neither head', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'none', withASession: false);
    await tester.pumpWidget(_workspace(g));
    await _settle(tester);
    expect(find.byKey(TheOpenSession.mark), findsNothing,
        reason: 'an empty session mark stands in the bar with no session open');

    await tester.pumpWidget(_home(g.ground, g.bench));
    await _settle(tester);
    expect(find.byKey(TheOpenSession.mark), findsNothing,
        reason: 'the chat’s head claims a session that does not exist');
  });

  // ------------------------------------------------------------------ guard 3
  testWidgets('900 wide holds it, and the instrument that says so can read a one', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // **A fresh tree for the reading**, because an overflow is reported once
    // per render object and a second width down the same tree reads empty.
    await tester.binding.setSurfaceSize(const Size(900, 900));
    final narrow = await _ready(tester, 'w900');
    await tester.pumpWidget(_workspace(narrow));
    await _settle(tester);
    final at900 = _overflows(tester);
    final mark900 = find.byKey(TheOpenSession.mark);
    expect(mark900, findsOneWidget, reason: 'the session’s name is gone at 900 wide');
    final r900 = tester.getRect(mark900);
    expect(r900.right, lessThanOrEqualTo(900),
        reason: 'the session’s name hangs off a 900-wide window at $r900 — 063’s own defect again');
    expect(at900, isEmpty, reason: 'the bar overflows at 900 with the session on it: $at900');

    // **The one beside the zero.** A window nobody ships, so that the empty
    // reading above is known to be a measurement and not a blind instrument.
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final tiny = await _ready(tester, 'w420');
    await tester.pumpWidget(_workspace(tiny));
    await _settle(tester);
    expect(_overflows(tester), isNotEmpty,
        reason: 'a 420-wide window reports no overflow, so this file cannot read one at all');
  });

  // ------------------------------------------------------------------ guard 5
  //
  // Watched red against its own break: with the `Flexible` taken off the name
  // in the bar, this name's own rect reaches **x = 1040.5** on a 900-wide
  // window — `Rect.fromLTRB(110, 22, 1040.5, 48)`, the x = 907 family exactly.
  //
  // **A name is a sentence when a person writes one.** «What is this one
  // about?» invites exactly that, and the bar it lands on had 2.8 px of margin
  // before 064/B. So the long name is measured at the width where it hurts,
  // and the thing it must not do is push the last control on the bar off the
  // glass — which is precisely what 063 shipped, green, at x = 907.
  testWidgets('a session named with a sentence gives way, and takes nothing off the glass',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'longname',
        sessionName: 'the quarterly reconciliation against the Nordstern ledger, second pass');
    await tester.pumpWidget(_workspace(g));
    await _settle(tester);

    final mark = find.byKey(TheOpenSession.mark);
    expect(mark, findsOneWidget, reason: 'the long name is not drawn at all');
    final r = tester.getRect(mark);
    expect(r.right, lessThanOrEqualTo(900), reason: 'the name itself hangs off the window: $r');
    expect(_overflows(tester), isEmpty,
        reason: 'a long session name overflows the bar at 900 — it must give way, not push');

    // The settings door is the last control on this bar and the one 063 lost.
    final door = find.byTooltip('Settings');
    expect(door, findsWidgets, reason: 'no settings door on the bar to measure');
    final d = tester.getRect(door.first);
    expect(d.right, lessThanOrEqualTo(900),
        reason: 'the long name pushed the settings door to $d, where no press reaches it');
  });

  // ------------------------------------------------------------------ guard 4
  testWidgets('the chat’s head names it too, and the build stamp keeps its place', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'chat');
    await tester.pumpWidget(_home(g.ground, g.bench));
    await _settle(tester);

    final mark = find.byKey(TheOpenSession.mark);
    expect(mark, findsOneWidget, reason: 'the chat’s head says nothing about the open session');
    expect(
      find.descendant(of: mark, matching: find.textContaining('Nordstern')),
      findsOneWidget,
      reason: 'the chat’s head does not carry the session’s name',
    );
    final r = tester.getRect(mark);
    expect(r.right, lessThanOrEqualTo(1100), reason: 'the name is off an 1100-wide window: $r');
    expect(r.top, lessThan(120), reason: 'the name is not in the head of the screen: $r');
    // The stamp is the longest thing on that strip and it was given room to
    // shrink rather than room to overflow — so a new neighbour must not have
    // taken its place entirely.
    expect(find.textContaining('z_core 0.1.0'), findsOneWidget,
        reason: 'the build stamp was pushed off the strip');
    expect(_overflows(tester), isEmpty, reason: 'the chat’s head overflows with the session on it');
  });
}

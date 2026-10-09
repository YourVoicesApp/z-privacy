// 063 · The settings cover the work, they do not replace it.
//
// Measured defect: `shell.dart` is a chain of early returns and settings were
// one of them, so opening them **unmounted the document**. The owner could not
// reach the settings from a document at all — not because the button was
// forgotten in the top bar, but because it could not have existed there: a
// full-screen settings page reached from a document would have hidden the
// document.
//
// So there are two halves to prove and they fail for different reasons:
//   1. there is a way to the settings from a screen that has a bar, and
//   2. taking it leaves the work on the screen.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// Carries something a general rule protects on its own — no vault needed for
/// the finding, so this test is about the panel and nothing else.
const _doc = 'Bitte überweisen Sie auf IBAN DE02120300000000202051 bis Freitag.';
const _needle = 'DE02120300000000202051';

/// **The owner's 480**, stated once in this file and asserted against the
/// product everywhere below. Written here rather than read from the widget: a
/// guard that takes its number from the thing it measures can only ever catch
/// disagreement, never a wrong answer the two of them share.
const panelWidth = 480.0;

/// The two windows these guards stand in. Named, because the size used to be
/// written twice in every guard that measured a rect against it — once in
/// `setSurfaceSize` and again as a literal in the `expect`. Change one and the
/// other goes quietly wrong: at a wider surface the press-through guard's
/// `dx > 1120` would have admitted a point that is **not** under the panel and
/// then proved nothing about leaking, green. Wherever two places can disagree
/// about one fact, one of them is already wrong.
const wide = Size(1600, 1100);
const narrow = Size(900, 800);

/// The one control. It is the same tooltip in the top bar and in the panel's
/// own corner, because it is the same widget in the same place on the glass —
/// the owner's «تغلق بالضغط عليها», and the reason `findsOneWidget` below is an
/// assertion and not an accident.
final _door = find.byTooltip('Settings');

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// Every error the last frames reported, drained.
///
/// `takeException` hands back one at a time and a frame can report several; an
/// overflow is reported through exactly this path, once per render object. It
/// has to be drained either way — an exception left standing fails the test at
/// the end, where it would be read as this test's own fault.
List<String> complaints(WidgetTester tester) {
  final found = <String>[];
  while (true) {
    final e = tester.takeException();
    if (e == null) break;
    found.add(e.toString());
  }
  return found;
}

/// Whether `node` is `root` or sits somewhere under it.
bool isUnder(Object? node, RenderObject root) {
  var at = node is RenderObject ? node : null;
  while (at != null) {
    if (at == root) return true;
    at = at.parent;
  }
  return false;
}

/// Everything a press at `at` would reach, named by whether it is in the work.
///
/// Said this way rather than «did a sheet open», because an absorbed press and
/// a press that opened nothing look identical from the outside, and only one of
/// them is the panel doing its job.
bool pressReachesTheWork(WidgetTester tester, Offset at) {
  final work = tester.renderObject(find.byType(WorkspaceScreen));
  final result = tester.hitTestOnBinding(at);
  return result.path.any((entry) => isUnder(entry.target, work));
}

/// What a person can read, out of the span tree rather than out of the state.
bool documentIsDrawn(WidgetTester tester, String needle) =>
    tester.widgetList<SelectableText>(find.byType(SelectableText)).any(
          (t) => (t.textSpan?.toPlainText() ?? t.data ?? '').contains(needle),
        );

Directory ownDir(String name) {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-panel-$name-$pid');
  if (own.existsSync()) own.deleteSync(recursive: true);
  addTearDown(() {
    if (own.existsSync()) own.deleteSync(recursive: true);
  });
  return own;
}

/// Past the first run and into a document, the way a person gets there.
Future<Ground> aDocumentOnTheBench(WidgetTester tester, String name) async {
  final ground = Ground();
  final own = ownDir(name);
  await tester.runAsync(() async {
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await ground.refresh();
  });

  await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: own.path, ground: ground)));
  await settle(tester);

  // The language, then Start — which does not leave the page, it opens the
  // vault section on it — then «Create a vault», which is what hands the shell
  // its `wantsVault` and stands the vault screen up. 041-N: the vault is the
  // way in.
  await tester.tap(find.text('English'));
  await settle(tester, rounds: 1);
  await tester.tap(find.text('Start'));
  await settle(tester);
  await tester.tap(find.text('Create a vault'));
  await settle(tester);
  // Through the core, not the two fields: a widget that awaits the core does
  // not resume under `testWidgets`, which is why no test in this app presses
  // «Create the vault» itself.
  await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort für den Tresor'));
  await settle(tester);
  final back = find.text('Back');
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await settle(tester, rounds: 8);
  }

  // By key since 064/D: the session question stands at the end of the chat
  // while a person has no session and comes **first** in the tree, so this
  // reach — «the first field on the page» — was putting the document into the
  // session's name field and opening nothing.
  await tester.enterText(find.byKey(HomeScreen.composer), _doc);
  await settle(tester, rounds: 1);
  await tester.tap(find.text('Open and scan'));
  await settle(tester);

  expect(find.byType(WorkspaceScreen), findsOneWidget,
      reason: 'the document did not open, so nothing below is measured');
  expect(documentIsDrawn(tester, _needle), isTrue,
      reason: 'the document is not drawn before the panel opens either, so this test proves nothing');
  return ground;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ---------------------------------------------------------------- guard a

  testWidgets('the settings open over a document and the document is still there', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await aDocumentOnTheBench(tester, 'over-the-work');

    expect(_door, findsOneWidget,
        reason: 'a document is open and the bar has no way to the settings — which is the half of '
            '063 that is about reach: a person with a document in front of them cannot get there');

    await tester.tap(_door);
    await settle(tester);

    expect(find.byType(SettingsScreen), findsOneWidget, reason: 'the settings did not open');
    // The whole of 063: the work is behind the panel, not replaced by it.
    expect(find.byType(WorkspaceScreen), findsOneWidget,
        reason: 'the settings replaced the screen instead of covering it, which is the defect '
            'shell.dart:373 was measured to have');
    expect(documentIsDrawn(tester, _needle), isTrue,
        reason: 'the document is no longer drawn behind the panel');

    // 480 is the owner's number and belongs in a guard rather than in a comment.
    expect(tester.getSize(find.byType(SettingsScreen)).width, panelWidth,
        reason: 'the panel is not $panelWidth wide');
    final box = tester.getRect(find.byType(SettingsScreen));
    expect(box.right, wide.width, reason: 'the panel is not against the right edge');
    expect(box.top, 0, reason: 'the panel does not start at the top');
    expect(box.bottom, wide.height, reason: 'the panel does not reach the bottom');
  });

  // ---------------------------------------------------------------- guard b

  testWidgets('the same press that opens the panel closes it', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await aDocumentOnTheBench(tester, 'twice');

    await tester.tap(_door);
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget, reason: 'the first press did not open it');

    // Exactly one control while it is open, in the place the finger already
    // is: a second control under the panel would be a control nobody can press.
    expect(_door, findsOneWidget,
        reason: 'with the panel open there is not exactly one settings control on the glass');

    // Said here as well as in guard a on purpose. A press that opens something
    // and a press that shuts it again is true of a full-screen page too, so
    // without this line this guard would go green on the very code 063 exists
    // to replace — which it did, measured, on the way here.
    expect(find.byType(WorkspaceScreen), findsOneWidget,
        reason: 'the thing being toggled is not a panel over the work');

    await tester.tap(_door);
    await settle(tester);
    expect(find.byType(SettingsScreen), findsNothing, reason: 'the second press did not close it');
    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'closing the panel lost the work');
  });

  // ---------------------------------------------------------------- guard c

  testWidgets('at 900 wide with the panel open, nothing overflows', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await aDocumentOnTheBench(tester, 'narrow');

    // The narrow case is **measured, not reasoned about**, and the measuring
    // found something: the settings door is last on the top bar, and the bar's
    // own content came to 941 px at this document — so at 900 it overflowed by
    // 41 and the door sat at x=907, off the glass, where no press could reach
    // it. The bar was already 5.9 px over at 900 before the door existed. Two
    // words on it give way under pressure now and the count at 900 is zero,
    // which is why this reads `isEmpty` rather than a difference.
    //
    // What it does not cover: the vault is open on this walk, so the band's
    // own 17-pixel warning row is not standing. That debt is unmeasured here.
    //
    // The count is taken with the panel shut first all the same — a number
    // whose before is unknown is not a measurement.
    //
    // **And the wide reading is drained before the window narrows**, which is
    // not tidiness. `DebugOverflowIndicatorMixin` reports **once per render
    // object for its whole life**: `_overflowReportNeeded` is cleared on the
    // first report and never set again. So on one tree the bar can complain at
    // 1600 and is then silent at 900 for ever — and an undrained 1600 report
    // would arrive in the reading below wearing 900's name, while the 900
    // reading itself came back empty. That is this guard going green on a bar
    // that overflows at both widths. Found by monopeaks-5e, who hit the same
    // mixin reading five window heights down one tree and got «overflows at
    // exactly 360», with every shorter height silent.
    expect(complaints(tester), isEmpty, reason: 'this build already overflows at 1600');

    await tester.binding.setSurfaceSize(narrow);
    await settle(tester);
    final shut = complaints(tester);

    // Geometry, because a count cannot be trusted to rise twice and a rect can
    // always be read. This is the property the count was standing in for: the
    // door is **on the glass**, not merely in the tree. At 941 px of bar it sat
    // at x=907.4 in a 900-wide view — mounted, found by every finder, pressable
    // by nobody.
    void doorIsOnTheGlass(String when) {
      final box = tester.getRect(_door);
      expect(box.right, lessThanOrEqualTo(narrow.width),
          reason: 'the settings door hangs off the right edge at ${narrow.width}, $when: $box');
      expect(box.left, greaterThanOrEqualTo(0),
          reason: 'the settings door is off the left edge at ${narrow.width}, $when: $box');
      expect(box.bottom, lessThanOrEqualTo(narrow.height),
          reason: 'the settings door is below the window at ${narrow.width}, $when: $box');
    }

    doorIsOnTheGlass('with the panel shut');

    await tester.tap(_door);
    await settle(tester);
    final open = complaints(tester);

    doorIsOnTheGlass('with the panel open');

    // Same reason as in guard b: «nothing overflows at 900» is easiest of all
    // to satisfy by not putting a panel there, so what is being measured is
    // named before the count is read.
    expect(find.byType(WorkspaceScreen), findsOneWidget,
        reason: 'the work is not behind the panel, so this is not the narrow case 063 is about');
    expect(tester.getSize(find.byType(SettingsScreen)).width, panelWidth,
        reason: 'the panel is not $panelWidth wide at ${narrow.width}, so the '
            '${narrow.width - panelWidth} left for the work is not what was measured');

    // **Both readings are asserted, and they are about different things.**
    // `shut` is the only reliable reading the *bar* will ever give at 900 —
    // once per render object, so whatever it says here it will never say
    // again on this tree. `open` is about the panel, whose render objects are
    // new and can therefore still speak. Asserting only `open` left this guard
    // green on a 2.8-pixel bar overflow, measured: that is what reverting one
    // of the two Flexible wrappers does, and the control said nothing until
    // this line existed.
    expect(shut, isEmpty, reason: 'the work behind the panel overflows at 900: $shut');
    expect(open, isEmpty, reason: 'the panel overflows at 900, with the bar reporting $shut');
  });

  // ------------------------------------------------------- covering is stopping

  // A panel that covers the work must also stop the work from being pressed
  // through it. A `Material` paints over what is behind it and takes none of
  // its presses — so without one line in `settings.dart` a press on an empty
  // stretch of the panel lands in whatever is under that pixel, and at 1600 the
  // right 480 has the Workspace's own review buttons under it.
  testWidgets('a press on the panel does not reach the work behind it', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await aDocumentOnTheBench(tester, 'does-not-leak');

    // The AI door, measured to be under the panel's 480 rather than assumed to
    // be: the review buttons sit at x=99 and would have proved nothing, which
    // is what the first version of this guard reported before it was pointed
    // anywhere.
    final ai = find.byTooltip('Choose the AI and what travels to it');
    expect(ai, findsOneWidget, reason: 'the AI door is not on this screen');
    final at = tester.getCenter(ai);
    expect(at.dx, greaterThan(wide.width - panelWidth),
        reason: 'the AI door is not under where the $panelWidth panel will stand, so a press '
            'there would prove nothing about leaking');

    // Before: that point is the work, and a press there reaches it. Without
    // this line the assertion below could hold because the point was never
    // over anything.
    expect(pressReachesTheWork(tester, at), isTrue,
        reason: 'a press at the AI door does not reach the work even with no panel up');

    await tester.tap(_door);
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // And the point is inside the panel that actually stood up, not inside one
    // worked out by arithmetic. This is the line a changed window cannot fool:
    // the rect is the panel's own.
    expect(tester.getRect(find.byType(SettingsScreen)).contains(at), isTrue,
        reason: 'the point pressed below is not inside the panel, so nothing below is measured');

    // After: the same point, with the panel over it. Two of them — the strip
    // at the top, which is a bar, and a point in the middle of the room, which
    // is the panel's own background and the place a press is most likely to
    // fall through.
    expect(pressReachesTheWork(tester, at), isFalse,
        reason: 'a press on the panel\'s top strip reached the work behind it');
    final middle = tester.getCenter(find.byType(SettingsScreen));
    expect(pressReachesTheWork(tester, middle), isFalse,
        reason: 'a press in the middle of the panel reached the work behind it');

    // And the act, not only the hit test: nothing opened, and the panel stayed.
    await tester.tapAt(at);
    await settle(tester);
    expect(find.byType(SendSheet), findsNothing,
        reason: 'the press went through the panel and opened the AI sheet in the work behind it');
    expect(find.byType(SettingsScreen), findsOneWidget,
        reason: 'a press on the panel closed the panel');
  });

  // ---------------------------------------------------------------- point 4

  testWidgets('the vault screen has no way to the settings', (tester) async {
    // Tall: until a language is chosen the first-run page carries both
    // promises, and at 1000 high «Create a vault» is below the fold — where a
    // finder reports it missing rather than reports it unreachable.
    await tester.binding.setSurfaceSize(const Size(1400, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    final own = ownDir('vault-door');
    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: own.path);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: own.path, ground: ground)));
    await settle(tester);
    await tester.tap(find.text('English'));
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await tester.tap(find.text('Create a vault'));
    await settle(tester);

    // No bench and no open vault: the shell stands the vault screen in front,
    // and there the only act is opening the vault.
    expect(find.byType(VaultScreen), findsOneWidget, reason: 'the vault screen is not the one showing');
    expect(_door, findsNothing, reason: 'the vault screen offers the settings, and 063 says it must not');
  });

  // ------------------------------------------------- the instrument's control

  // Guard c asserts a count is zero. A count that cannot rise is not a
  // measurement, so here is the same instrument reading a layout that does
  // overflow, on purpose.
  testWidgets('control · the overflow count can rise', (tester) async {
    await tester.binding.setSurfaceSize(const Size(300, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Row(children: [SizedBox(width: 400, height: 10), SizedBox(width: 400, height: 10)]),
      ),
    );
    await tester.pump();

    final seen = complaints(tester);
    expect(seen, isNotEmpty, reason: 'the instrument cannot see an overflow, so guard c measures nothing');
    expect(seen.first, contains('overflowed'), reason: 'what it saw was not an overflow');
  });
}

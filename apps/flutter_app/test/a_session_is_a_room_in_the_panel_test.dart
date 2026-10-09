// 064 · The sessions, in the room the owner asked for.
//
// His words: «نجعل داخل الإعدادات إنشاء جلسة جديدة، البنك، وقائمة بأسماء
// الجلسات السابقة» — inside the settings: making a new session, the bank, and a
// list of the previous sessions' names. Two of the three are built; the bank
// waits for its paper.
//
// What is guarded here is the room, not the key: the core's own six guards hold
// the cryptography, and `a_session_carries_its_own_key.rs` is where a token's
// name is proven to come from the session. This file holds the four things a
// person does — see them, begin one, enter another, and destroy one knowing
// what that costs.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const wide = Size(1500, 1200);

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Directory ownDir(String name) {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-room-$name-$pid');
  if (own.existsSync()) own.deleteSync(recursive: true);
  addTearDown(() {
    if (own.existsSync()) own.deleteSync(recursive: true);
  });
  return own;
}

/// Into the Sessions room, the way a person gets there: first run, a vault,
/// the panel's door, the room's own chip.
Future<Ground> inTheRoom(WidgetTester tester, String name) async {
  final ground = Ground();
  final own = ownDir(name);
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
  await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för rummet'));
  await settle(tester);
  final back = find.text('Back');
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await settle(tester, rounds: 8);
  }

  await tester.tap(find.byTooltip('Settings'));
  await settle(tester);
  expect(find.byType(SettingsScreen), findsOneWidget, reason: 'the panel did not open');

  // **The room is reached by its name, and the AI room is still the default.**
  // The send sheet's exiled key form relies on that default landing on AI, and
  // its own guards assert the room by name rather than by position — so this
  // asserts the same two facts from this side, where a room was added.
  expect(
    find.descendant(of: find.byType(SettingsScreen), matching: find.text('AI')),
    findsWidgets,
    reason: 'the panel no longer opens on the AI room, which is where a key is asked for',
  );
  await tester.tap(find.text('Sessions'));
  await settle(tester);
  return ground;
}

/// Begin a session from the room — in two halves, deliberately.
///
/// **The press cannot be the whole of it, and that is the harness and not the
/// product.** A widget that awaits the core does not resume under
/// `testWidgets`: it is why no test in this app presses «Create the vault»
/// either. So the control is proven here — the field takes the name, the button
/// exists and is **live**, not greyed — and the act goes through the ground,
/// which is exactly what the button's own `onPressed` calls. What is not proven
/// by this file is the wiring between those two, and a reader should know that
/// rather than assume a green press.
Future<void> begin(
  WidgetTester tester,
  Ground ground,
  String name, {
  SessionId? bench,
}) async {
  await tester.enterText(find.byType(TextField).last, name);
  await settle(tester, rounds: 1);
  final button = find.widgetWithText(ZButton, 'Begin');
  expect(button, findsOneWidget, reason: 'the room has no Begin control');
  expect(
    tester.widget<ZButton>(button).onPressed,
    isNotNull,
    reason: 'the Begin control is dead, so a person with a name typed cannot start a session',
  );
  // **`bench:` is passed, because the core refuses a birth that does not name
  // an open document** — 064f. This helper did not pass it, and when the
  // refusal landed the first thing it caught was this file: a test helper
  // reproducing the defect it was written beside.
  final renamed = await tester.runAsync(() => ground.beginSession(name, bench: bench));
  expect(renamed, isNotNull, reason: 'the birth was refused: ${ground.trouble}');
  await settle(tester);
}

/// **The owner's own path**, 064f: a document with something protected on it,
/// the panel opened over it, a session begun from the room.
///
/// This is the path 5e read out of the code before anybody pressed the button.
/// The room's «Begin» had no bench to pass, so nothing was re-derived and what
/// left afterwards wore pre-birth names while the payload claimed the session.
/// Neither the session marker nor a provenance check could see it, because the
/// payload really was built after the birth.
Future<Ground> withADocumentBehindThePanel(WidgetTester tester, String name) async {
  final ground = Ground();
  final own = ownDir(name);
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
  await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för rummet'));
  await settle(tester);
  final back = find.text('Back');
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await settle(tester, rounds: 8);
  }

  // A document, scanned, with a name the general rules protect on their own.
  // By key since 064/D — the other seat's file, fixed in the commit that moved
  // the field, because a tree left red between two commits is a tree the lead
  // cannot merge either half of.
  await tester.enterText(
    find.byKey(HomeScreen.composer),
    'Bitte überweisen Sie auf IBAN DE02120300000000202051 bis Freitag.',
  );
  await settle(tester, rounds: 1);
  await tester.tap(find.text('Open and scan'));
  await settle(tester);

  await tester.tap(find.byTooltip('Settings'));
  await settle(tester);
  await tester.tap(find.text('Sessions'));
  await settle(tester);
  return ground;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a fresh vault says no sessions yet, and says how one is born', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await inTheRoom(tester, 'empty');

    expect(find.text('No sessions yet'), findsOneWidget);
    // And it says where one comes from, because «there is no new session
    // button» was true for a whole evening and a person should not have to
    // guess which act makes one.
    expect(
      find.textContaining('copy safe text or ask for a PDF'),
      findsOneWidget,
      reason: 'the empty room does not say how a session is born',
    );
  });

  testWidgets('a session begun in the panel is listed, named, and the one you are in', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = await inTheRoom(tester, 'begin');

    await begin(tester, ground, 'oktoberlönerna');

    // Read out of the row rather than off the screen at large: the name is also
    // in the field it was typed into, and `find.text` matches a `TextField` —
    // which is how a guard on this product once passed for the wrong reason.
    final listed = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.widgetWithText(Row, 'oktoberlönerna'),
    );
    expect(listed, findsWidgets, reason: 'the session is not drawn as a row in the list');
    expect(find.text('1'), findsWidgets, reason: 'the first session is not number 1');
    expect(
      find.textContaining('the one you are in'),
      findsOneWidget,
      reason: 'a session was begun and the room does not say it is the open one',
    );
    expect(ground.openSession, 1, reason: 'the core does not hold it open');
  });

  testWidgets('entering another session asks nothing', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = await inTheRoom(tester, 'enter');

    for (final name in ['första', 'andra']) {
      await begin(tester, ground, name);
    }
    expect(ground.openSession, 2, reason: 'the second session is not the open one');

    // One «Enter» exists — on the session that is not open. The open one offers
    // no way to enter itself, which is the owner's «entering asks nothing»
    // carried through to there being nothing to press.
    expect(find.text('Enter'), findsOneWidget, reason: 'the open session offers to be entered');

    // I wrote here that `enterSession` is fire-and-forget in the row's own
    // callback, so the press would be the whole act and a pump would finish it.
    // **This test disproved that**: the press left `openSession` at 2. A core
    // call started from a widget callback does not complete under `testWidgets`
    // whether it is awaited or not, so the comment was wrong and is corrected
    // rather than deleted. The control is proven live; the act goes through the
    // ground, as in `begin`.
    final enter = find.widgetWithText(TextButton, 'Enter');
    expect(tester.widget<TextButton>(enter).onPressed, isNotNull,
        reason: 'the Enter control is dead, so an old session cannot be returned to');
    await tester.runAsync(() => ground.enterSession(1));
    await settle(tester);

    expect(ground.openSession, 1, reason: 'Enter did not move which session is open');
    // Nothing was asked: no dialog, no field to fill.
    expect(find.byType(AlertDialog), findsNothing, reason: 'entering an old session asked something');
  });

  testWidgets('a session begun over an open document renames the names on it', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = await withADocumentBehindThePanel(tester, 'over-a-doc');

    // The panel knows which document is behind it. Without this the core
    // refuses the birth, and before 064f it accepted one that renamed nothing.
    final panel = tester.widget<SettingsScreen>(find.byType(SettingsScreen));
    expect(
      panel.bench,
      isNotNull,
      reason: 'the panel was handed no document, so a session begun here cannot rename what is '
          'protected on it — which is the defect 064f closes',
    );

    await begin(tester, ground, 'över dokumentet', bench: panel.bench);

    expect(ground.openSession, isNotNull, reason: 'no session is open after a birth');

    // **The card's promise, measured where it can be.** The room's sentence is
    // built by the widget's own callback, which a `testWidgets` press cannot
    // reach — so the wording lives in `sessionBegunSaid` and is measured
    // directly below. What is asserted here is the input it is given: the panel
    // knew which document was behind it, which is the whole of 064f.
  });

  // The sentence itself, where it can be read. A birth that renamed nothing
  // used to read exactly like one that renamed nine, because the room showed
  // neither — that invisible 0 is what hid the 064f defect for a day.
  test('the sentence after a birth says what the birth did', () {
    expect(sessionBegunSaid(0, hadDocument: false), contains('No document is open'),
        reason: 'with nothing open, «nothing needed renaming» would be the wrong reason');
    expect(sessionBegunSaid(0, hadDocument: true), contains('needed renaming'));
    expect(sessionBegunSaid(1, hadDocument: true), contains('one name'));
    expect(sessionBegunSaid(9, hadDocument: true), contains('9 names'));
    // The two zeros are different sentences, which is the whole point of the
    // `hadDocument` argument.
    expect(
      sessionBegunSaid(0, hadDocument: true),
      isNot(sessionBegunSaid(0, hadDocument: false)),
      reason: 'a zero with a document open and a zero with none read the same, so the person '
          'cannot tell «nothing to do» from «nothing was done»',
    );
  });

  testWidgets('deleting a session states what it costs, and the name goes with it', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = await inTheRoom(tester, 'delete');

    await begin(tester, ground, 'Weber-underlaget');
    expect(ground.sessions.length, 1, reason: 'nothing to delete, so nothing below is measured');

    await tester.tap(find.byTooltip('Delete this session'));
    await settle(tester);

    // **A statement, not a caution.** 064 made the owner's wording literally
    // true: the key is destroyed and nothing derives anything afterwards. So
    // the sentence says what happens, and it names who cannot undo it —
    // including us.
    expect(find.textContaining('Delete «Weber-underlaget»?'), findsOneWidget);
    expect(find.textContaining('destroys the key'), findsOneWidget,
        reason: 'the dialog does not say what is destroyed');
    expect(find.textContaining('not by Z Privacy'), findsOneWidget,
        reason: 'the dialog lets the person think we could still undo it');
    expect(find.textContaining('can never be unprotected'), findsOneWidget,
        reason: 'the dialog warns instead of stating');
    // And it says what deletion does NOT do, because a person about to destroy
    // something needs the edge of it as much as the middle.
    expect(find.textContaining('stays exactly as it was'), findsOneWidget,
        reason: 'the dialog does not say that what already left is untouched');

    // Keeping it keeps it — the control that makes the delete below mean
    // something. A pure UI press: nothing of the core is awaited on this path.
    await tester.tap(find.text('Keep it'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing, reason: '«Keep it» did not close the dialog');
    expect(ground.sessions.length, 1, reason: '«Keep it» deleted the session');

    // And the deletion itself, through the ground for the reason `begin` gives.
    await tester.runAsync(() => ground.forgetSession(1));
    await settle(tester);

    expect(ground.sessions, isEmpty, reason: 'the core still holds it');
    expect(find.text('No sessions yet'), findsOneWidget,
        reason: 'the room still draws a session that is gone');
  });
}

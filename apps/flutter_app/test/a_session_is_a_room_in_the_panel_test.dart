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
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
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
  removeWhenItLetsGo(own);
  addTearDown(() {
    removeWhenItLetsGo(own);
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
  await tester.tap(find.text(sentences.start));
  await settle(tester);
  await tester.tap(find.text(sentences.createAVault));
  await settle(tester);
  await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för rummet'));
  await settle(tester);
  final back = find.text(sentences.back);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await settle(tester, rounds: 8);
  }

  await tester.tap(find.byTooltip('Settings'));
  await settle(tester);
  expect(find.byType(SettingsScreen), findsOneWidget, reason: 'the panel did not open');

  // **The room is reached by its name, and the AI room is still the default.**
  // **The panel opens on Sessions since rule 74** (the owner, 18 October 2026),
  // so this room is where it lands and there is nothing to press to get here.
  // The sentence that stood here said the opposite — the default was the AI
  // room, and the send sheet's «Open Settings» relied on landing there; that
  // reliance is gone, because every door about a key names `SettingsRoom.ai`
  // itself now.
  //
  // And «Sessions» is on the glass twice while this room stands — the tab and
  // the room's own title — so a press on the word would be ambiguous. The room
  // is read by the sentence only it has.
  expect(
    find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.textContaining('Each session has its own encryption'),
    ),
    findsOneWidget,
    reason: 'the panel did not open on the Sessions room (rule 74)',
  );
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
  final button = find.widgetWithText(ZButton, sentences.begin);
  expect(button, findsOneWidget, reason: 'the room has no Begin control');
  // **Rule 57a, 16 October**: a name is not enough. The language is the
  // person's to choose and nothing is pre-marked, so the control is dead until
  // they pick one — which is what the owner met from the other side when a
  // session took the application's language without asking him. The law itself
  // is measured in `the_session_asks_its_language_test`; here it is the step a
  // person takes, and on a second birth in the same panel their earlier choice
  // is still on the form, so the press is already live.
  if (tester.widget<ZButton>(button).onPressed == null) {
    final language = ground.packs.firstWhere((p) => offeredLanguages.contains(p.id));
    await tester.tap(find.text(language.label));
    await settle(tester, rounds: 1);
  }
  expect(
    tester.widget<ZButton>(button).onPressed,
    isNotNull,
    reason: 'the Begin control is dead with a name typed and a language chosen',
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
  await tester.tap(find.text(sentences.start));
  await settle(tester);
  await tester.tap(find.text(sentences.createAVault));
  await settle(tester);
  await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för rummet'));
  await settle(tester);
  final back = find.text(sentences.back);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await settle(tester, rounds: 8);
  }

  // A document, scanned, with a name the general rules protect on their own.
  // By key since 064/D — the other seat's file, fixed in the commit that moved
  // the field, because a tree left red between two commits is a tree the lead
  // cannot merge either half of.
  await tester.enterText(
    find.byKey(WorkspaceScreen.composer),
    'Bitte überweisen Sie auf IBAN DE02120300000000202051 bis Freitag.',
  );
  await settle(tester, rounds: 1);
  // **Rule 72-أ, 18 October 2026**: the strip's box and its «Open and scan»
  // are deleted. The one box is the request box in the first part, and its own
  // press is what sends a text through the shell — the same act, one door on.
  await tester.tap(find.byKey(const ValueKey<String>('workspace-question-attach')));
  await settle(tester);
  // **Rule 57b (the owner, 16 October)**: the first text of a new session is
  // asked which language it is in — once, before anything is read, because the
  // scanner needs it before it reads. The fixture answers it exactly as a
  // person does; after that nothing in the session asks again (57c).
  if (find.text(TheLanguageOfANewSession.title).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(TheLanguageOfANewSession.keyFor('de')));
    await settle(tester, rounds: 20);
  }

  await tester.tap(find.byTooltip('Settings'));
  await settle(tester);
  await settle(tester);
  return ground;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  testWidgets('a fresh vault says no sessions yet, and says how one is born', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await inTheRoom(tester, 'empty');

    expect(find.text(sentences.noSessionsYet), findsOneWidget);
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
    expect(find.text(sentences.enter), findsOneWidget, reason: 'the open session offers to be entered');

    // I wrote here that `enterSession` is fire-and-forget in the row's own
    // callback, so the press would be the whole act and a pump would finish it.
    // **This test disproved that**: the press left `openSession` at 2. A core
    // call started from a widget callback does not complete under `testWidgets`
    // whether it is awaited or not, so the comment was wrong and is corrected
    // rather than deleted. The control is proven live; the act goes through the
    // ground, as in `begin`.
    final enter = find.widgetWithText(TextButton, sentences.enter);
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

  // **081 · rename lives in the sessions list** — the owner's second ruling.
  //
  // It is here because a session born of a press is called «Session N», and a
  // person who wants their own word for it has to be able to give it one
  // without the application asking at the exit. «الرقم هو الهوية ولا يتحرك»:
  // what moves is the word on the row, and nothing else.
  testWidgets('renaming a session changes the word and not the number', (tester) async {
    await tester.binding.setSurfaceSize(wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = await inTheRoom(tester, 'rename');

    await begin(tester, ground, 'Session 1');
    expect(ground.sessions.length, 1, reason: 'nothing to rename, so nothing below is measured');
    final before = ground.sessions.single;
    expect(before.name, 'Session 1',
        reason: 'the fixture is not a session carrying its own number as a name');

    await tester.tap(find.byTooltip('Rename this session'));
    await settle(tester);

    // It asks for one word, and states what does **not** change — because a
    // person renaming the drawer their protected work is in needs the edge of
    // the act as much as the middle.
    expect(find.textContaining(sentences.renameSessionNumber(1)), findsOneWidget);
    expect(find.textContaining('The number stays 1'), findsOneWidget,
        reason: 'the dialog does not say that the number is the identity');
    expect(find.textContaining('nothing that was protected in it changes'), findsOneWidget,
        reason: 'the dialog lets a person fear the rename touches their work');

    // **Keeping the name keeps it** — the control that gives the rename below
    // its meaning. A pure UI press: nothing of the core is awaited here.
    await tester.tap(find.text(sentences.keepTheName));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing, reason: '«Keep the name» left the dialog open');
    expect(ground.sessions.single.name, 'Session 1',
        reason: '«Keep the name» renamed it anyway');

    // The act itself, through the ground: a core call started in a widget
    // callback does not complete under `testWidgets`, whether awaited or not —
    // this file's own «entering» guard measured that and says so. The control
    // is the live press above; the act is driven where it can finish.
    await tester.tap(find.byTooltip('Rename this session'));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey<String>('rename-this-session')), 'oktoberlönerna');
    await settle(tester, rounds: 1);
    final doIt = find.widgetWithText(TextButton, sentences.renameIt);
    expect(tester.widget<TextButton>(doIt).onPressed, isNotNull,
        reason: 'the Rename control is dead, so a session cannot be given a word');
    await tester.tap(find.text(sentences.keepTheName));
    await settle(tester);
    await tester.runAsync(() => ground.renameSession(before.number, 'oktoberlönerna'));
    await settle(tester);

    final after = ground.sessions.single;
    expect(after.name, 'oktoberlönerna', reason: 'the session kept its old word');
    expect(after.number, before.number,
        reason: 'the number moved with the name, so the identity of the session moved');
    expect(after.turns, before.turns, reason: 'the rename touched what the session holds');
    expect(after.beganAt, before.beganAt, reason: 'the rename moved when the session began');
    // Read back from the core, not from the screen that asked for it.
    final rows = await tester.runAsync(() => z.conversations());
    expect(rows!.single.name, 'oktoberlönerna',
        reason: 'the word changed on the glass and not in the vault');
    expect(rows.single.number, before.number, reason: 'the vault moved the number');

    // And the row on the glass carries it.
    expect(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.widgetWithText(Row, 'oktoberlönerna'),
      ),
      findsWidgets,
      reason: 'the list still shows the old word',
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
    // The name is isolated in the question (16 October), through the one
    // function that writes it: a right-to-left name in «Delete «…»?» would
    // otherwise drag the punctuation around it out of order.
    expect(
      find.textContaining('Delete «${theirOwnWord('Weber-underlaget')}»?'),
      findsOneWidget,
    );
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
    expect(find.text(sentences.noSessionsYet), findsOneWidget,
        reason: 'the room still draws a session that is gone');
  });
}

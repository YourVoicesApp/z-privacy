// 046/L · «Later» is not an answer, and a gate hands over its key.
//
// **The owner, 7 October:** «لأنه الآن في حال كانت ريفو تحتوي على أي خيار، لا
// يمكن الانتقال إلى الخطوات التالية.» One open item and he could not go on.
//
// Measured, and the diagnosis is not what the complaint says. `send` refuses
// with `OpenSuggestions { count }` while a question is unanswered — correct,
// and it stays. But `answer_finding` on `Skip` carries the core's own comment,
// «Skipping is not deciding: it stays open and stays counted», and `Skip` sat
// **in the same row as the two answers, in the same shape**. So it reads as a
// decision, the count does not fall when it is pressed, and what a reasonable
// person concludes is «the review is blocking me» rather than «that button
// meant later».
//
// It was never the gate. The gate stays shut while a question is open and that
// is the one sentence this product rests on. **We are not loosening the rule —
// we are making it answerable in one press from wherever he is.** These tests
// are that distinction: the first two hold the rule, the rest hold the key.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// One document, one open question: a local telephone number, which the German
/// pack offers rather than decides. Everything else in it is proven.
const _one = 'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'Telefon: 0171 2345678\n';

const _goKey = ValueKey<String>('workspace-go-to-question');
const _protectKey = ValueKey<String>('workspace-one-protect');
const _leaveKey = ValueKey<String>('workspace-one-leave');
const _laterKey = ValueKey<String>('review-later');

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

Future<(Ground, Workbench)> _open(WidgetTester tester, String name, {String text = _one}) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-later-$name-$pid');
    removeWhenItLetsGo(here);
    addTearDown(() {
      // **Best effort, and that is the claim this directory is under.** The
      // core may still be writing in here when the test ends — a session's
      // body is written when the first opening of a run spends a chat (A3) —
      // and `deleteSync(recursive: true)` then throws «Directory not empty»
      // over a file that appeared during its own walk. Measured: this file
      // red in a gate run at 00:04 on 18 October and green by itself, and the
      // same race took `zprivacy-ask-names-…` on 17 October. A temporary
      // directory that outlives a test proves nothing either way, so a
      // failure to remove it is not a failure of the test.
      try {
        removeWhenItLetsGo(here);
      } on FileSystemException {
        // Left behind on purpose, rather than red for a reason no claim here
        // is about. Fifty-five files in this suite own a directory like this
        // one; one helper for all of them is the real fix and is written down
        // as a debt.
      }
    });
    await z.setDataDir(dir: here.path);
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: text);
    await bench.rescan();
    await bench.refresh();
  });
  addTearDown(bench.dispose);
  await tester.pumpWidget(MaterialApp(
    home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
  ));
  await settle(tester);
  return (ground, bench);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // --------------------------------------------------------------- 1 · the rule

  /// **046/L's finding outlived its own button** — 083, ruling 5 (14 Oct).
  ///
  /// What this file found on 7 October was not «Skip» and not «Later»: it was
  /// that **a thing which is not an answer may not be drawn as one.** The first
  /// repair gave it its own word and its own line, inside the card. The owner's
  /// ruling went further and took it out of the card altogether: leaving a word
  /// for later is the **Next** button, which is not an answer, is not drawn
  /// among them, and is not even in the same half of the window.
  ///
  /// So the shape this test used to measure is gone, and what is left to hold
  /// is the deletion — «Later» and «Skip» are not in the review at all. That
  /// Next keeps the count where it is lives in
  /// `the_review_in_two_forms_test.dart`, with the rest of the walk.
  testWidgets('«Later» and «Skip» are gone from the review, not moved inside it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'later');

    final before = bench.openSuggestions;
    expect(before, greaterThan(0), reason: 'the fixture has nothing to answer');

    bench.openReview(walk: true);
    await settle(tester);

    for (final gone in ['Later — stays open', 'Later', 'Skip']) {
      expect(find.text(gone), findsNothing, reason: '«$gone» is still drawn in the review');
    }
    expect(find.byKey(_laterKey), findsNothing);
    // And the two that are left are the two the owner named.
    expect(find.text('Protect'), findsWidgets);
    expect(find.text('Leave it'), findsWidgets);
    expect(bench.openSuggestions, before, reason: 'drawing the panel answered something');
  });

  // ---------------------------------------------------------------- 2 · the key

  testWidgets('the blocked gate names the count, and takes him to it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'key');
    expect(bench.openSuggestions, 1, reason: 'this test is written for the one-question case');

    // The old line said «Answer the review first» and named nothing.
    expect(find.text('Answer the review first'), findsNothing);
    expect(find.text('1 question left — go to it'), findsOneWidget,
        reason: 'the gate does not say how many are left');

    // Send is still shut. The rule is not loosened.
    final send = tester.widget<ZButton>(
      find.widgetWithText(ZButton, 'Choose who answers'),
    );
    expect(send.onPressed, isNull, reason: 'the door opened with a question still open');

    // And the press hands over the key: the review opens, on that finding.
    await tester.tap(find.byKey(_goKey));
    await settle(tester);
    // 071: one value names the open panel, so «the review is open» is asked
    // of that value rather than of a boolean beside three others.
    expect(
      bench.panel,
      OpenPanel.review,
      reason: 'the review did not open — the slot holds ${bench.panel}',
    );
    expect(bench.focused, bench.suggested.first.id, reason: 'it did not go to the question');
  });

  testWidgets('one question is answerable from where he stands, both ways', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'answerable');
    expect(bench.openSuggestions, 1);

    // What it is, so the two answers are about something.
    expect(find.textContaining('The one left is'), findsOneWidget);

    await tester.tap(find.byKey(_protectKey));
    await settle(tester, rounds: 12);
    expect(bench.openSuggestions, 0, reason: 'protecting it from here did not answer it');

    // The door is open now, and the way-through line is gone with the question.
    final send = tester.widget<ZButton>(
      find.widgetWithText(ZButton, 'Choose who answers'),
    );
    expect(send.onPressed, isNotNull, reason: 'the door stayed shut with nothing open');
    expect(find.byKey(_goKey), findsNothing);
  });

  // ------------------------------------------------------- 3 · all of them

  /// Two values a German letter writes that the pack **offers** rather than
  /// decides: a company by its legal form, and a second one beside it.
  testWidgets('select all protects in one press, and asks before leaving any in the clear', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const many = 'Kunde: Nordstern Consulting GmbH\n'
        'Lieferant: Westfalen Logistik GmbH\n'
        'Partner: Rheinland Technik GmbH\n';
    final (_, bench) = await _open(tester, 'all', text: many);
    expect(bench.openSuggestions, greaterThan(1),
        reason: 'the fixture has fewer than two open, so «all» measures nothing');
    final count = bench.openSuggestions;

    bench.openReview();
    await settle(tester);
    // 083 ruling 6 names the two acts: «Protect all» and «Skip all». The
    // number is on the badge beside each and in the confirmation's own
    // sentence, which is where P2-5 needs it — a count inside a label that
    // also has to fit a narrow panel was the thing that made «Leave all 3 in
    // the clear» as long as the panel is wide.
    expect(find.text('Protect all'), findsOneWidget);
    expect(find.text('Skip all'), findsOneWidget);
    expect(find.text('Protect all $count'), findsNothing,
        reason: 'the old name is still drawn');

    // **Protect them all: one press, no question.** Over-protecting is never a
    // leak, so asking would be a toll on the safe direction.
    await tester.tap(find.byKey(ValueKey<String>('review-all-protect')));
    await settle(tester, rounds: 16);
    expect(bench.openSuggestions, 0, reason: 'one press did not take all of them');
  });

  testWidgets('leaving them all in the clear asks once, with the number in the sentence', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const many = 'Kunde: Nordstern Consulting GmbH\n'
        'Lieferant: Westfalen Logistik GmbH\n'
        'Partner: Rheinland Technik GmbH\n';
    final (_, bench) = await _open(tester, 'all-leave', text: many);
    final count = bench.openSuggestions;
    expect(count, greaterThan(1));

    bench.openReview();
    await settle(tester);
    await tester.tap(find.byKey(ValueKey<String>('review-all-leave')));
    await settle(tester);

    // **The dangerous direction asks, and the number is in the question.** A
    // confirmation that does not say how many is not a confirmation.
    expect(find.text('Leave $count words in the clear?'), findsOneWidget,
        reason: 'one press was about to leave $count values in the clear with no question');
    expect(find.textContaining('All $count of them'), findsOneWidget);
    expect(bench.openSuggestions, count, reason: 'it acted before the answer');

    // Cancel means nothing happened.
    await tester.tap(find.widgetWithText(ZButton, 'Cancel'));
    await settle(tester);
    expect(bench.openSuggestions, count, reason: 'cancelling still answered them');

    // And the act itself carries the number too.
    await tester.tap(find.byKey(ValueKey<String>('review-all-leave')));
    await settle(tester);
    // «Yes — …», not the same words as the button that opened the dialog: the
    // first version of this test could not tell the two apart, which is how it
    // found that two acts were wearing one name at once.
    await tester.tap(find.widgetWithText(ZButton, 'Yes — leave all $count in the clear'));
    await settle(tester, rounds: 16);
    expect(bench.openSuggestions, 0, reason: 'the confirmed act did nothing');
  });

  testWidgets('and the other way leaves it in the clear, which is also an answer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'leave');
    expect(bench.openSuggestions, 1);

    await tester.tap(find.byKey(_leaveKey));
    await settle(tester, rounds: 12);
    expect(bench.openSuggestions, 0, reason: 'leaving it in the clear did not answer it');
    // It is **not** protected: «leave it» is a decision to send it as written,
    // and the count falling is the whole difference from «Later».
    //
    // Measured as «the phone is in neither list» rather than as a ratio: an
    // answered «not sensitive» leaves the marks entirely, so the first version
    // of this test compared 2 protected against 2 marks and failed for a
    // reason that had nothing to do with the decision.
    final marks = bench.document!.marks;
    // Three since 085 ruling 1 (15 October): this fixture's name is a given
    // name and a surname, so what the app read for itself is two marks and
    // not one.
    expect(marks.length, 3, reason: 'the phone is still marked: $marks');
    expect(
      marks.every((m) => m.state == MarkState.protected),
      isTrue,
      reason: 'something is still waiting: $marks',
    );
    // **The one open question in this fixture is the company.** Measured, in
    // the core, after guessing wrong twice: «Herr Thomas Müller» is proven by
    // its salutation and a local number after «Telefon:» is proven by its
    // label, so both of those are Auto, and the thing still waiting is
    // «Nordstern Consulting GmbH» — a run ending in a legal form, which is
    // evidence and not proof.
    //
    // Two wrong guesses about my own fixture is the argument for measuring one
    // rather than reading it: a test that had happened to pass on a guess
    // would have been green about the wrong value.
    expect(
      marks.any((m) => m.kind == Kind.company),
      isFalse,
      reason: 'the company was protected after a decision to leave it in the clear',
    );
  });
}

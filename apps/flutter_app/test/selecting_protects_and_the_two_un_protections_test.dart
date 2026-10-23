// **083c and 083d on the glass** — the owner's rulings 1 and 3.
//
// One press protects, with no dialog and no question, every place of the value
// in this conversation. And the only choices left are the two that undo it:
// **here**, or **in this conversation** — with no «everywhere», and with the
// number in the broad act's own name.
//
// The core's half of both laws is in
// `z_core/tests/selecting_protects_and_un_protecting_asks_how_far.rs`, watched
// red there break by break. These are the presses.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/why_sheet.dart';

import 'drawn_document.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// One name in three places, and a telephone number the Swedish pack proves
/// from its label — so the document holds both a value a person must take by
/// hand and one the app took by itself.
const _doc =
    'Kontakta Lindqvist i dag.\n'
    'Lindqvist skrev avtalet.\n'
    'Hälsningar till Lindqvist.\n'
    'Telefon: 070 123 45 67\n';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Span _spanOf(String needle, {int nth = 0}) {
  var at = -1;
  for (var i = 0; i <= nth; i++) {
    at = _doc.indexOf(needle, at + 1);
  }
  return Span(start: at, end: at + needle.length);
}

void main() {
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-selection-$pid');

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
    removeWhenItLetsGo(dir);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    removeWhenItLetsGo(dir);
  });

  Future<Workbench> ready(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'sv');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'sv');
      await bench.rescan();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await settle(tester);
    return bench;
  }

  testWidgets('one press protects every place, with no dialog and nothing asked', (tester) async {
    final bench = await ready(tester);
    await tester.runAsync(() => bench.select(_spanOf('Lindqvist')));
    await settle(tester, rounds: 2);
    expect(bench.selected!.matches, 3, reason: 'the measured document changed');

    // The badge says what one press settles — the second button it replaces
    // («Protect all matches») is gone, because there is nothing left for it to
    // mean.
    final button = tester.widget<ZButton>(find.widgetWithText(ZButton, sentences.protectAct));
    expect(button.badge, 3);
    expect(find.text('Protect all matches'), findsNothing);

    await tester.tap(find.widgetWithText(ZButton, sentences.protectAct));
    await settle(tester, rounds: 10);

    // **No dialog stood in the way** — ruling 1. The dialog's own words are
    // gone from the window, and the act is already done.
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Protect this'), findsNothing);
    final name = bench.tokens.where((t) => t.kind == Kind.custom).toList();
    expect(name.length, 1, reason: 'the hand selection made ${name.length} tokens');
    expect(
      bench.payload!.text.split(name.first.token).length - 1,
      3,
      reason: 'one press did not settle all three places',
    );
    expect(bench.payload!.text, isNot(contains('Lindqvist')));
  });

  testWidgets('the card offers two ways to undo it, and only two', (tester) async {
    final bench = await ready(tester);
    await tester.runAsync(() => bench.select(_spanOf('Lindqvist')));
    await settle(tester, rounds: 2);
    await tester.tap(find.widgetWithText(ZButton, sentences.protectAct));
    await settle(tester, rounds: 10);

    // Open the card on the middle place, the way a person does: a press on the
    // protected word in the text.
    await tester.tapAt(whereIsInDocument(tester, 'Lindqvist', _spanOf('Lindqvist', nth: 1).start, span: 9));
    await settle(tester, rounds: 6);
    expect(find.byType(WhySheet), findsOneWidget, reason: 'the word opened no card');

    expect(find.text(kRemoveHere), findsWidgets);
    // **The owner's words, not the product's own function.** Asking
    // `removeInThisConversation(3)` what it says and then looking for that is a
    // guard that cannot fail: breaking the name breaks both sides at once, and
    // the break that proved it reddened nothing. So the two things the ruling
    // asks for are spelled out here — the reach, and the number.
    // And looked for **inside the card**, because «3 places» is also what the
    // press said under the column a moment ago («Protected as …, in 3 places»)
    // — the second break that reddened nothing, and the second time in one
    // round that a guard was green because the string it wanted was somewhere
    // else on the screen.
    final inTheCard = find.descendant(of: find.byType(WhySheet), matching: find.byType(Text));
    final words = tester.widgetList<Text>(inTheCard).map((t) => t.data ?? '').toList();
    expect(
      // **The owner's own name for it, and he changed it on 17 October**:
      // rule 55-هـ makes the container a «session» everywhere a sentence
      // names it, and this option is one of the places he pointed at. The
      // helper that builds the string keeps its old identifier, because the
      // core's `Scope::Conversation` does — the glass is what the rule is
      // about.
      words.where((w) => w.contains('in this session')),
      isNotEmpty,
      reason: 'the second choice is not offered by the name the owner gave it: $words',
    );
    expect(
      words.where((w) => w.contains('3 places')),
      isNotEmpty,
      reason: 'the act that uncovers three places does not say how many: $words',
    );
    // **No «everywhere».** The owner struck it out; «Forget everywhere» is a
    // different act about knowledge, and this document taught none.
    expect(find.text('Remove protection everywhere'), findsNothing);
    expect(find.text('Remove it everywhere'), findsNothing);
  });

  testWidgets('«here» uncovers one place and leaves the others their token', (tester) async {
    final bench = await ready(tester);
    await tester.runAsync(() => bench.select(_spanOf('Lindqvist')));
    await settle(tester, rounds: 2);
    await tester.tap(find.widgetWithText(ZButton, sentences.protectAct));
    await settle(tester, rounds: 10);
    final token = bench.tokens.where((t) => t.kind == Kind.custom).first.token;

    await tester.tapAt(whereIsInDocument(tester, 'Lindqvist', _spanOf('Lindqvist', nth: 1).start, span: 9));
    await settle(tester, rounds: 6);
    await tester.tap(find.widgetWithText(ZButton, kRemoveHere));
    await settle(tester, rounds: 10);

    expect(bench.payload!.text.split(token).length - 1, 2, reason: 'the other places lost the token');
    expect(bench.payload!.text.split('Lindqvist').length - 1, 1,
        reason: 'the uncovered place does not read as the document reads');
  });

  testWidgets('«in this session» uncovers every place that carries the token', (tester) async {
    final bench = await ready(tester);
    await tester.runAsync(() => bench.select(_spanOf('Lindqvist')));
    await settle(tester, rounds: 2);
    await tester.tap(find.widgetWithText(ZButton, sentences.protectAct));
    await settle(tester, rounds: 10);
    final before = bench.tokens.length;

    await tester.tapAt(whereIsInDocument(tester, 'Lindqvist', _spanOf('Lindqvist', nth: 1).start, span: 9));
    await settle(tester, rounds: 6);
    await tester.tap(find.widgetWithText(ZButton, removeInThisConversation(3)));
    await settle(tester, rounds: 12);

    expect(bench.payload!.text.split('Lindqvist').length - 1, 3, reason: 'a place stayed protected');
    expect(bench.tokens.length, before - 1, reason: 'the token nothing points at any more is still kept');
    // And the value the app protected by itself is untouched: the breadth is
    // the token's, not the document's.
    expect(bench.payload!.text, isNot(contains('070 123 45 67')));
  });
}

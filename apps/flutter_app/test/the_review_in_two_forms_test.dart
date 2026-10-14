// **083b · The review in two forms** — the owner's rulings of 14 October.
//
// In the text: Review takes both columns to the first waiting word, lights it,
// and puts its **two** buttons beside it; Review becomes «Next 3/7»; answering
// moves on by itself; Next leaves a word for later; with nothing waiting the
// button is gone.
//
// In the list: only what waits, with «Protect all» and «Skip all» at its foot,
// and the confirmation kept on the one door that uncovers words in a batch.
//
// Every guard here was watched red against `b69611f` — the whole product half of
// this branch put back and the tests left standing. What that run proves is in
// the commit message, test by test.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/going_to_a_word.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/review.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _originalPane = ValueKey<String>('workspace-original-pane');
const _safePane = ValueKey<String>('workspace-safe-pane');

/// **Measured, not invented** (`cargo run -p z_core --example` probe, 14 Oct):
/// the German pack leaves **four** words waiting here and protects two by
/// itself — «2026-114» twice (one value, two places), «Anna Weber», «55-900»,
/// and the customer number and the IBAN taken without asking. Three distinct
/// answers, one of them covering two places, is the smallest document that can
/// hold every ruling of 083b at once.
///
/// The thirty lines in front of them are not padding: the first waiting word
/// has to be **off the screen** before «both columns land on it» can mean
/// anything.
final _doc = [
  'Projektteam 2026',
  for (var i = 1; i <= 30; i++) 'Zeile $i des Protokolls ohne Zahlen.',
  'Rechnung 2026-114 liegt vor.',
  'Ansprechpartner: Anna Weber',
  'Rechnungsnummer 55-900 ist offen.',
  'Rechnung 2026-114 ist bezahlt.',
  'Kundennummer 44812',
  'IBAN: DE89 3704 0044 0532 0130 00',
].join('\n');

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// The column's own scroller, by its key — not by its place among every
/// scrollable on the screen, which is what `columns_in_step_test` found out the
/// hard way: each `SelectableText` brings one of its own.
ScrollController _railOf(WidgetTester tester, Key pane) {
  final view = tester.widget<SingleChildScrollView>(
    find.descendant(of: find.byKey(pane), matching: find.byType(SingleChildScrollView)).first,
  );
  return view.controller!;
}

String _wordOf(Workbench bench, Finding f) =>
    bench.document!.text.substring(f.span.start, f.span.end);

/// What the one button on the acts bar says right now, or null when it is gone.
String? _theWalkButton(WidgetTester tester) {
  final labels = tester
      .widgetList<ZButton>(find.byType(ZButton))
      .map((b) => b.label)
      .where((l) => l == 'Review' || l.startsWith('Next '))
      .toList();
  return labels.isEmpty ? null : labels.first;
}

void main() {
  late Directory dir;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
    dir = Directory('${Directory.systemTemp.path}/zprivacy-two-forms-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<Workbench> ready(WidgetTester tester) async {
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
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await settle(tester);
    expect(bench.openSuggestions, 4, reason: 'the document the guards were measured on changed');
    return bench;
  }

  /// **Ruling 14, on its own and without a window**: the walk's order and the
  /// exits' guide are one law. `theFirstWaitingWord` lives in
  /// `session_state.dart` and is the other seat's file, so the two cannot yet
  /// be one function — this is the guard that holds them to one answer until
  /// they can be.
  test('the walk and the exits\' guide agree about which word is first', () {
    const where = Span(start: 0, end: 4);
    Finding at(int id, int start, MarkState state) => Finding(
      id: id,
      span: Span(start: start, end: start + 4),
      kind: Kind.contract,
      source: Source.generalRule,
      decided: false,
      reason: 'measured',
      state: state,
      entities: const [],
      occurrences: 1,
    );
    // Deliberately out of reading order, which is the shape the core hands
    // back: its layers find things in their own order.
    final findings = [
      at(1, 900, MarkState.suggested),
      at(2, 100, MarkState.protected),
      at(3, 300, MarkState.suggested),
      at(4, 200, MarkState.suggested),
    ];

    final waiting = theWaitingWordsInReadingOrder(findings);
    expect(waiting.map((f) => f.id), [4, 3, 1], reason: 'not the order a person reads');
    expect(waiting.first.id, theFirstWaitingWord(findings)!.id);
    expect(theWalkIsAt(waiting, waiting[1]), 1);

    // «After» is by span, so a word that has just been answered — and is no
    // longer in the list at all — still knows where it stood.
    expect(theWaitingWordAfter(findings, waiting[0])!.id, 3);
    expect(theWaitingWordAfter(findings, at(99, 200, MarkState.protected))!.id, 3);
    expect(theWaitingWordAfter(findings, waiting.last)!.id, 4, reason: 'it must come round');
    expect(theWaitingWordAfter(const [], null), isNull);
    expect(where.start, 0);
  });

  testWidgets('Review goes to the first waiting word, and both columns land on it', (tester) async {
    final bench = await ready(tester);
    final first = theFirstWaitingWord(bench.findings)!;
    expect(
      _railOf(tester, _originalPane).offset,
      0,
      reason: 'the document starts at the top, or nothing below is a landing',
    );
    expect(_theWalkButton(tester), 'Review');

    await tester.tap(find.text('Review'));
    await settle(tester);

    expect(bench.focused, first.id, reason: 'the walk did not start at the first waiting word');
    expect(_wordOf(bench, first), '2026-114');
    // **Read after the landing, and not before it.** Measured: opening the
    // panel remounts the columns, so a controller taken before the press is a
    // controller attached to nothing — an assertion from the framework, in a
    // test whose subject is elsewhere.
    expect(
      _railOf(tester, _originalPane).offset,
      greaterThan(0),
      reason: 'the Original column did not go to the word',
    );
    expect(
      _railOf(tester, _safePane).offset,
      greaterThan(0),
      reason: 'the Safe column stayed behind — the two columns must land together',
    );
    // The word's own two buttons, where the word is.
    expect(find.byKey(ChoiceBubble.protectKey), findsOneWidget);
    expect(find.byKey(ChoiceBubble.leaveKey), findsOneWidget);
    expect(_theWalkButton(tester), 'Next 1/4', reason: 'Review did not become Next with the count');
  });

  testWidgets('Next leaves the word for later: the walk moves, the count does not', (tester) async {
    final bench = await ready(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);
    final waiting = theWaitingWordsInReadingOrder(bench.findings);

    await tester.tap(find.text('Next 1/4'));
    await settle(tester);

    expect(bench.focused, waiting[1].id);
    expect(_wordOf(bench, waiting[1]), 'Anna Weber');
    expect(_theWalkButton(tester), 'Next 2/4');
    expect(
      bench.openSuggestions,
      4,
      reason: 'Next answered something — then it was not «leave it for later» at all',
    );
  });

  testWidgets('answering moves the walk on by itself, in reading order', (tester) async {
    final bench = await ready(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);
    final waiting = theWaitingWordsInReadingOrder(bench.findings);
    expect(_wordOf(bench, waiting[1]), 'Anna Weber');

    await tester.tap(find.byKey(ChoiceBubble.protectKey));
    await settle(tester);

    // **One answer, every place** (ruling 7): «2026-114» stood twice, and both
    // places are settled — so the walk's next word is the one after it in
    // reading order and the count has fallen by two.
    expect(bench.openSuggestions, 2);
    expect(bench.focused, waiting[1].id, reason: 'the walk did not step on by itself');
    expect(_theWalkButton(tester), 'Next 1/2');
    expect(find.byKey(ChoiceBubble.protectKey), findsOneWidget,
        reason: 'the next word must arrive with its own buttons beside it');
  });

  testWidgets('two buttons at the word, and the deleted five are nowhere', (tester) async {
    final bench = await ready(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);
    expect(bench.focused, isNotNull);

    expect(find.text('Protect'), findsWidgets);
    expect(find.text('Leave it'), findsWidgets);
    for (final gone in [
      'Always',
      'Always · needs a vault',
      'Always · unlock the vault',
      'Not sensitive',
      'Not sensitive in profile',
      'Not sensitive everywhere',
      'Later — stays open',
      'Skip',
    ]) {
      expect(find.text(gone), findsNothing, reason: '«$gone» is deleted, not hidden — ruling 8');
    }
  });

  testWidgets('the list holds only what waits, and says where the rest is', (tester) async {
    final bench = await ready(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);
    expect(find.byType(ReviewPanel), findsOneWidget);

    // What waits is in it…
    expect(find.text('55-900'), findsWidgets);
    expect(find.text('Anna Weber'), findsWidgets);
    // …and what the app took by itself is not. It is in the text, marked where
    // it stands — ruling 6.
    expect(find.text('44812'), findsNothing);
    expect(find.text('DE89 3704 0044 0532 0130 00'), findsNothing);
    expect(find.text('Protected automatically'), findsNothing);
    expect(find.text('Decided by you'), findsNothing);
    expect(bench.automatic, isNotEmpty, reason: 'nothing was auto-protected, so the guard is empty');

    // **How many rows the list is given, and not how many it drew.**
    //
    // Measured, and it is the whole reason this line exists: with the list put
    // back to «every finding», the two auto-protected rows sit **below the
    // fold**, a `ListView` never builds them, and `find.text` is blind to a
    // widget that was never built — so the absences above were all green while
    // the panel held six rows instead of four. The delegate's own count is
    // what the list was asked to hold, built or not.
    final list = tester.widget<ListView>(
      find.descendant(of: find.byType(ReviewPanel), matching: find.byType(ListView)),
    );
    expect(
      list.childrenDelegate.estimatedChildCount,
      4,
      reason: 'the list holds rows for words nobody has to answer',
    );
  });

  testWidgets('Skip all asks first: Cancel changes nothing, Yes leaves them all', (tester) async {
    final bench = await ready(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);

    // What the app protected by itself, before any of this: «Skip all» must not
    // add to it, and the IBAN and the customer number were tokens from the
    // first scan.
    final already = bench.tokens.length;
    expect(already, 2, reason: 'the measured document changed');

    await tester.tap(find.text('Skip all'));
    await settle(tester);
    expect(find.text('Leave 4 words in the clear?'), findsOneWidget,
        reason: 'the one door that uncovers words in a batch asked nothing — ruling 9');

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(bench.openSuggestions, 4, reason: 'Cancel changed something');

    await tester.tap(find.text('Skip all'));
    await settle(tester);
    await tester.tap(find.text('Yes — leave all 4 in the clear'));
    // **Four answers, one after the other, each through the bridge.** Measured:
    // with the four pumps every other guard uses, three had landed and the
    // fourth had not — a red that says «Skip all left one word waiting» about a
    // test that did not wait.
    await settle(tester, rounds: 12);
    expect(
      bench.openSuggestions,
      0,
      reason: 'left waiting: '
          '${theWaitingWordsInReadingOrder(bench.findings).map((f) => _wordOf(bench, f)).toList()}',
    );
    expect(
      bench.tokens.length,
      already,
      reason: 'a word was protected by a press that said «leave»',
    );
  });

  /// **A refusal in the review still reaches the screen** — the law
  /// `refusal_reaches_the_screen_test.dart` was written for, kept after its own
  /// subject was deleted.
  ///
  /// That file measured «Always» without a vault: the core refused, `answer()`
  /// set `trouble`, and the `refresh()` on the next line wiped it before
  /// anything was drawn. «Always» is gone with ruling 8, so the press is gone —
  /// but the mechanism it repaired is the one every answer still runs through.
  /// The refusal measured here is the one the core can still give an answer:
  /// a finding that is not there.
  testWidgets('a refusal from an answer survives the refresh that follows it', (tester) async {
    final bench = await ready(tester);

    await tester.runAsync(() => bench.answer(90001, FindingAnswer.protect));
    await settle(tester);

    expect(
      bench.trouble,
      isNotNull,
      reason: 'the refusal was wiped by the refresh that follows every answer',
    );
    expect(bench.openSuggestions, 4, reason: 'a refused answer changed something');
  });

  testWidgets('with nothing waiting the button is gone, and the list says where to look', (tester) async {
    final bench = await ready(tester);
    await tester.tap(find.text('Review'));
    await settle(tester);

    await tester.tap(find.text('Protect all'));
    await settle(tester, rounds: 12);

    expect(bench.openSuggestions, 0);
    expect(_theWalkButton(tester), isNull, reason: 'the button is gone, not disabled — ruling 10');
    expect(find.byKey(ChoiceBubble.protectKey), findsNothing,
        reason: 'the bubble stayed on a word that has been settled');
    expect(
      find.textContaining('Nothing is waiting'),
      findsWidgets,
      reason: 'the empty list must say that what is protected is in the text',
    );
  });
}

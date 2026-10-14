// **084 · the search bar on the glass** — the owner's bar of 14 Oct.
//
// Type a word, see how many places it stands in and what each one is, and act
// on them. The core's half is in
// `z_core/tests/the_search_bar_reads_what_covers_each_place.rs`, watched red
// break by break; the completion's half is in
// `the_completion_offers_the_documents_own_words_test.dart`. These are the
// presses.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/find_in_document.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _originalPane = ValueKey<String>('workspace-original-pane');
const _safePane = ValueKey<String>('workspace-safe-pane');

/// Measured with a core probe before this was written: «Lindqvist» stands in
/// four whole-word places — one inside the name the pack asks about, one inside
/// the company it asks about, and two alone — and the telephone number is
/// protected without asking.
final _doc = [
  'Anna Lindqvist skrev avtalet.',
  for (var i = 1; i <= 24; i++) 'Rad $i i protokollet utan namn.',
  'Kontakta Lindqvist i dag.',
  'Lindqvist AB levererar på fredag.',
  'Hälsningar till Lindqvist.',
  'Telefon: 070 123 45 67',
].join('\n');

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

ScrollController _railOf(WidgetTester tester, Key pane) {
  final view = tester.widget<SingleChildScrollView>(
    find.descendant(of: find.byKey(pane), matching: find.byType(SingleChildScrollView)).first,
  );
  return view.controller!;
}

String? _theGoButton(WidgetTester tester) {
  final labels = tester
      .widgetList<ZButton>(find.byType(ZButton))
      .map((b) => b.label)
      .where((l) => l == 'Go to it' || l.startsWith('Next '))
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
    dir = Directory('${Directory.systemTemp.path}/zprivacy-find-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<Workbench> ready(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1700, 1100);
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
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await settle(tester);
    return bench;
  }

  Future<void> searchFor(WidgetTester tester, String word) async {
    await tester.enterText(find.byKey(FindInDocument.field), word);
    await settle(tester, rounds: 2);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, rounds: 8);
  }

  testWidgets('the bar is in plain sight, and a word gives its places and their states', (tester) async {
    await ready(tester);
    // **In plain sight** — ruling 1. Not behind a key, not behind a menu, and
    // drawn before anything is typed.
    expect(find.byKey(FindInDocument.field), findsOneWidget);

    await searchFor(tester, 'Lindqvist');

    Finder inTheBar(String text) => find.descendant(
      of: find.byType(FindInDocument),
      matching: find.textContaining(text),
    );
    expect(inTheBar('«Lindqvist» — 4 places'), findsOneWidget);
    // One place inside the company the pack still asks about, one inside the
    // name it asks about, and two alone.
    expect(find.text('2 waiting'), findsOneWidget);
    expect(find.text('2 in the clear'), findsOneWidget);
    // And the ruling (c) sentence, where the act is: Protect will not answer a
    // suggestion wider than the typed word.
    expect(inTheBar('still wait for your word'), findsOneWidget);
    // **Inside the bar**, because the document holds «Lindqvist AB» too and a
    // finder that does not say where it is looking reads the text under it.
    expect(inTheBar('Lindqvist AB'), findsOneWidget);
  });

  testWidgets('a word that is not there says so, and nothing else changes', (tester) async {
    final bench = await ready(tester);
    final marks = bench.document!.marks.length;
    await searchFor(tester, 'Nordstern');
    expect(
      find.descendant(
        of: find.byType(FindInDocument),
        matching: find.textContaining('is not in this document'),
      ),
      findsOneWidget,
    );
    expect(_theGoButton(tester), isNull, reason: 'there is nowhere to go');
    expect(bench.document!.marks.length, marks, reason: 'a search changed the document');
  });

  testWidgets('three letters offer the document\'s own word, and Tab takes it', (tester) async {
    await ready(tester);
    Finder inTheBar(String text) => find.descendant(
      of: find.byType(FindInDocument),
      matching: find.textContaining(text),
    );
    await tester.enterText(find.byKey(FindInDocument.field), 'Li');
    await settle(tester, rounds: 2);
    expect(inTheBar('Tab takes it'), findsNothing, reason: 'two letters offered something');

    await tester.enterText(find.byKey(FindInDocument.field), 'Lin');
    await settle(tester, rounds: 2);
    expect(inTheBar('Lindqvist'), findsWidgets);
    expect(inTheBar('Tab takes it'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await settle(tester, rounds: 2);
    expect(tester.widget<TextField>(find.byKey(FindInDocument.field)).controller!.text, 'Lindqvist');
    // Taken, so the faint line is gone: a word is not its own completion.
    expect(inTheBar('Tab takes it'), findsNothing);
  });

  testWidgets('Go to lands both columns on the place, and becomes Next', (tester) async {
    await ready(tester);
    await searchFor(tester, 'Lindqvist');
    expect(_theGoButton(tester), 'Go to it');

    await tester.tap(find.byKey(FindInDocument.goKey));
    await settle(tester, rounds: 8);

    // The label says where the walk **is**, as the review's Next does.
    expect(_theGoButton(tester), 'Next 1/4', reason: 'the walk did not move on');
    // The first place is on the first line, so the proof that both columns
    // landed is the **second** place, far down the document.
    await tester.tap(find.byKey(FindInDocument.goKey));
    await settle(tester, rounds: 8);
    expect(_theGoButton(tester), 'Next 2/4');
    expect(_railOf(tester, _originalPane).offset, greaterThan(0),
        reason: 'the Original column did not go to the place');
    expect(_railOf(tester, _safePane).offset, greaterThan(0),
        reason: 'the Safe column stayed behind — both columns land together');
  });

  testWidgets('Protect takes the places in the clear and leaves the wider suggestion', (tester) async {
    final bench = await ready(tester);
    await searchFor(tester, 'Lindqvist');
    final waiting = bench.openSuggestions;

    await tester.tap(find.byKey(FindInDocument.protectKey));
    await settle(tester, rounds: 14);

    // The two clear places are protected, under one token…
    expect(find.text('2 protected'), findsOneWidget);
    expect(find.text('2 in the clear'), findsNothing);
    // …and the suggestions are untouched: «Lindqvist AB» is more than what was
    // typed, and the review is where it is answered (084, ruling (c)).
    expect(find.text('2 waiting'), findsOneWidget);
    expect(bench.openSuggestions, waiting, reason: 'the bar answered a suggestion');
  });

  testWidgets('the two un-protections act from the bar, each at its own breadth', (tester) async {
    final bench = await ready(tester);
    await searchFor(tester, 'Lindqvist');
    await tester.tap(find.byKey(FindInDocument.protectKey));
    await settle(tester, rounds: 14);
    expect(find.text('2 protected'), findsOneWidget);

    // Stand on a protected place: the walk's first press goes to the first
    // place, which is inside the name the pack asks about — so walk to the one
    // that was just protected.
    await tester.tap(find.byKey(FindInDocument.goKey));
    await settle(tester, rounds: 6);
    await tester.tap(find.byKey(FindInDocument.goKey));
    await settle(tester, rounds: 6);

    expect(find.byKey(FindInDocument.hereKey), findsOneWidget,
        reason: 'the walk is not standing on a protected place');
    expect(find.byKey(FindInDocument.everyKey), findsOneWidget);

    await tester.tap(find.byKey(FindInDocument.everyKey));
    await settle(tester, rounds: 14);
    expect(find.text('2 protected'), findsNothing, reason: 'the token kept a place');
    expect(find.text('2 in the clear'), findsOneWidget);
    expect(bench.payload!.text.split('Lindqvist').length - 1, greaterThan(1));
  });

  /// **Nothing typed is ever stored** — ruling «what is typed is never stored»,
  /// and rule 47. Measured over every file the app writes, not promised.
  testWidgets('after a search, no file the app writes holds the typed word', (tester) async {
    await ready(tester);
    await searchFor(tester, 'Lindqvist');
    expect(find.textContaining('4 places'), findsOneWidget, reason: 'the search did not run');

    final holding = <String>[];
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      final bytes = f.readAsBytesSync();
      if (String.fromCharCodes(bytes).contains('Lindqvist')) holding.add(f.path);
    }
    expect(
      holding,
      isEmpty,
      reason: 'the word is in a file the app wrote: $holding',
    );
  });
}

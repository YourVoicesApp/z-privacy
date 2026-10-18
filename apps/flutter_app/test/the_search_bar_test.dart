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
import 'the_folder_lets_go.dart';

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

/// **A document that has come back** — 079, and the fixture e2's two findings
/// of 15 October need. A token of ours stands in the text with no protection
/// over it, because it arrived *as text*.
///
/// The word searched for is `person`, and it stands in two places: once as a
/// plain word in the clear, and once **inside** the token — `_` is not
/// alphanumeric, so `occurrences` reads `PERSON` between two of them as a word
/// standing alone, and the token place is therefore one of the places the bar
/// offers to protect. Measured, not assumed: the bar's own count says «2 in
/// the clear» below before anything is pressed.
///
/// The plain one is first on purpose. The loop kept the **last** place's
/// outcome, so with the token place last the press said «this is already
/// protected» about a press that had just protected something.
const _ourToken = '__Z_9F3A_PERSON_K7QX__';
final _cameBack = [
  'Vi har en person i listan.',
  for (var i = 1; i <= 6; i++) 'Rad $i i protokollet utan namn.',
  'Avtalet gick till $_ourToken i mars.',
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

/// Every sentence on the glass that begins with a word, read off the `Text`
/// widgets themselves. The said line is a private widget, and asking for the
/// string by `find.text` was the guard that went green because the string it
/// wanted was somewhere else on the screen (083c). This reads what is written
/// and prints all of it when it is wrong.
List<String> _saidStartingWith(WidgetTester tester, String word) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((line) => line.startsWith(word))
    .toList();

List<String> _everyLine(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((line) => line.isNotEmpty)
    .toList();

String? _theGoButton(WidgetTester tester) {
  final labels = tester
      .widgetList<ZButton>(find.byType(ZButton))
      .map((b) => b.label)
      .where((l) => l == 'Go to it' || l.startsWith('Next '))
      .toList();
  return labels.isEmpty ? null : labels.first;
}


/// **A word of the person's own, as a sentence now carries it** — 17 October:
/// every such word is isolated (`theirOwnWord` on the glass,
/// `text::their_own_word` in the core), so it stands between `U+2068` and
/// `U+2069` wherever one of our sentences quotes it.
///
/// The pair is written out here as literals rather than taken from the
/// product's own function on purpose: a guard that asked with `theirOwnWord`
/// would follow it wherever it went, and would stay green the day it stopped
/// isolating anything.
///
/// Two shapes, because the quotation marks are not always ours to put: a
/// heading says «Client · ⁨Nordstern⁩» with no marks at all, and a dialog says
/// «Forget ⁨…⁩?» with them.
String isolated(String word) => '\u2068$word\u2069';
String quoted(String word) => '«${isolated(word)}»';

void main() {
  late Directory dir;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
    dir = Directory('${Directory.systemTemp.path}/zprivacy-find-$pid');
    removeWhenItLetsGo(dir);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    removeWhenItLetsGo(dir);
  });

  Future<Workbench> ready(WidgetTester tester, {String? text}) async {
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'sv');
      await z.importText(session: session, text: text ?? _doc);
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
    expect(inTheBar('${quoted("Lindqvist")} — 4 places'), findsOneWidget);
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

  /// **One press, one sentence, and the sentence counts every place** — e2's
  /// second finding of 15 October, pinned red before it was fixed: the loop
  /// kept only the **last** place's outcome, so two places protected under one
  /// token came back `Applied { places: 1 }` and the bar said «Protected as
  /// Z_…» about two of them. The count the bar shows was right all along,
  /// which is why nothing noticed: the lie was in the sentence.
  testWidgets('one press over two places in the clear says both of them', (tester) async {
    await ready(tester);
    await searchFor(tester, 'Lindqvist');
    expect(find.text('2 in the clear'), findsOneWidget, reason: 'the fixture moved');

    await tester.tap(find.byKey(FindInDocument.protectKey));
    await settle(tester, rounds: 14);

    final said = _saidStartingWith(tester, 'Protected');
    expect(said, hasLength(1), reason: 'the press said this, on one glass: ${_everyLine(tester)}');
    expect(
      said.first,
      contains('in 2 places'),
      reason: 'two places were protected and the press said «${said.first}»',
    );
  });

  /// **A place that is already a token of ours is not protected again, and does
  /// not swallow the press** — 079 rule 5 at the bar, e2's first finding.
  ///
  /// The core refuses a hand over a token at the door, before the vault is
  /// taught anything (G32), so nothing was ever minted here — and that is
  /// exactly why this was invisible: the refusal arrived as the **last**
  /// outcome of the loop and became the whole press's sentence, over a press
  /// that had just protected a real place. The word «person» stands in two
  /// places of this document, one of them inside the token.
  testWidgets('a token of ours among the places protects the others and keeps itself', (tester) async {
    final bench = await ready(tester, text: _cameBack);
    await searchFor(tester, 'person');
    expect(find.text('2 in the clear'), findsOneWidget,
        reason: 'the token place is not among the places offered: ${_everyLine(tester)}');
    final before = bench.tokens.length;

    await tester.tap(find.byKey(FindInDocument.protectKey));
    await settle(tester, rounds: 14);

    // The plain place is protected, under one new token…
    expect(bench.tokens.length, before + 1, reason: 'the press minted ${bench.tokens.length - before} tokens');
    expect(find.text('1 protected'), findsOneWidget, reason: 'the clear place was not protected');
    // …the token that arrived stands exactly as it arrived, in the text that
    // would leave the machine…
    expect(bench.payload!.text, contains(_ourToken), reason: 'a second token was minted over the first');
    expect(bench.payload!.text.split(_ourToken).length - 1, 1, reason: 'the token is in the payload twice');
    // …and the sentence is about what happened, not about the last place the
    // loop looked at.
    final said = _saidStartingWith(tester, 'Protected');
    expect(said, hasLength(1), reason: 'the press said this, on one glass: ${_everyLine(tester)}');
    expect(_saidStartingWith(tester, 'This is already protected'), isEmpty,
        reason: 'a press that protected a place said it had protected nothing');
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

// M7.1 — the shell, tested against the real core.
//
// The owner's rule for M7 is that no number on screen is invented in Dart. A
// widget test is the only way to hold that to account: it pumps the real screens
// against the real library, then reads the pixels' text and compares it with what
// the core says when asked directly.
//
// One thing to know before reading: every call into Rust below is wrapped in
// `tester.runAsync`. `testWidgets` runs inside a fake-async zone, and a real FFI
// future never completes in one — the first version of this file hung for ten
// minutes on `await ground.refresh()` before that was the answer.
//
// Needs the native library, so run once:  flutter build linux --debug
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/protect_dialog.dart';
import 'package:zprivacy/widgets/review.dart';
import 'package:zprivacy/widgets/tokens.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// A document with something for each layer to find, so the band's numbers are
/// not all zero — a screen that only ever shows 0 proves nothing.
const _doc = 'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n'
    'Bitte prüfen Sie den Vertrag.';

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    // The runner is started with LD_LIBRARY_PATH pointing at the built bundle.
    await RustLib.init();
  });

  testWidgets('Home draws the ground as the core reports it, not as Dart guesses', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final VaultState vault;
    late final List<PackRow> packs;
    late final List<ProviderRow> providers;
    await tester.runAsync(() async {
      await ground.refresh();
      // What the core says, asked directly. The screen must agree with these.
      vault = await z.vaultState();
      packs = await z.packs();
      providers = await z.providers();
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        ground: ground,
        version: 'z_core 0.1.0',
        onImport: () {},
        onType: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Z Privacy'), findsOneWidget);
    expect(find.text('Import a document'), findsOneWidget);

    // The pack's label is the pack's own, never a string typed into a screen.
    expect(packs, isNotEmpty, reason: 'this build carries a pack');
    expect(find.textContaining(packs.first.label), findsOneWidget);

    // The provider count on screen is the core's count.
    final connected = providers.where((p) => p.connected).length;
    expect(find.text('$connected'), findsWidgets);

    // And the vault line says the state the core is in — not a friendlier version
    // of it. A locked vault must look locked.
    switch (vault) {
      case VaultState.unlocked:
        expect(find.textContaining('identities the app knows'), findsOneWidget);
      case VaultState.locked:
        expect(find.text('Locked'), findsOneWidget);
      case VaultState.absent:
        expect(find.text('None'), findsOneWidget);
    }
  });

  testWidgets('the Workspace band reports the scan the core ran, number for number',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });

    // The core's own report, for comparison.
    final report = bench.report!;
    expect(report.auto + report.suggested, greaterThan(0), reason: 'the scan found something to show');

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await tester.pumpAndSettle();

    // The band, word for word as the design board writes it, with the core's
    // numbers substituted in.
    expect(find.text('Scanned on import'), findsOneWidget);
    expect(
      find.text('${report.auto} protected automatically · ${report.suggested} need your word · '
          '${report.normal} normal'),
      findsOneWidget,
      reason: 'the band shows the core numbers and nothing rounded or recomputed',
    );

    // The two columns exist and each carries its hard rule.
    expect(find.text('ORIGINAL — LOCAL ONLY'), findsOneWidget);
    expect(find.text('SAFE — AI WILL RECEIVE'), findsOneWidget);
    expect(find.text('Never sent to AI · Send cannot read this side'), findsOneWidget);

    // Typed text has no file name, and the bar says so rather than inventing one.
    expect(find.text('Typed text'), findsOneWidget);
    expect(find.text('1 page'), findsOneWidget);

    // The vault's state is on the bar, and it is the state inside the report —
    // one source, so the bar and the band can never contradict each other.
    final onBar = switch (report.vault) {
      VaultState.unlocked => 'Unlocked',
      VaultState.locked => 'Locked',
      VaultState.absent => 'None',
    };
    expect(find.text(onBar), findsOneWidget);

    bench.dispose();
  });

  testWidgets('the two columns show the core\'s own two strings, and only those',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      // Answer everything, so there are real tokens on the Safe side. There is
      // no «send anyway»; the only way past a suggestion is to answer it.
      for (final f in bench.findings.where((f) => f.state == MarkState.suggested)) {
        await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();
      // Plain, so the token text is really in the span tree rather than inside
      // a chip widget — this test is about the string, not the drawing.
      bench.showChips(false);
    });

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await tester.pumpAndSettle();

    final original = _plainOf(tester, OriginalText);
    final safe = _plainOf(tester, SafeText);

    // 1 · Nothing is lost in the drawing. The left column splits the text at
    // every mark to colour it; if that splitter ever dropped or reordered a
    // slice, this is where it shows.
    expect(original, bench.document!.text,
        reason: 'the Original column must be the document, character for character');

    // 2 · The right column is the payload the core built — not a copy the UI
    // assembled from the document and the token table.
    expect(safe, bench.payload!.text,
        reason: 'the Safe column must be the core\'s payload, character for character');

    // 3 · Control string first, then the claim.
    expect(original, contains('Thomas Müller'), reason: 'the original really holds the name');
    expect(bench.tokens, isNotEmpty, reason: 'something was protected, so there is something to check');
    for (final t in bench.tokens) {
      expect(safe, contains(t.token), reason: 'every token the core minted is on the Safe side');
    }
    for (final secret in ['Thomas Müller', 'Nordstern Consulting GmbH', 'DE89370400440532013000']) {
      expect(safe, isNot(contains(secret)), reason: '«$secret» is drawn on the side that leaves');
    }

    // 4 · And the sentence under the column tells the truth about suggestions.
    expect(bench.payload!.openSuggestions, 0);
    expect(find.textContaining('This is exactly what the AI will receive'), findsOneWidget);

    bench.dispose();
  });

  testWidgets('the Protect button is in the state the core says, not one Dart worked out',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    late final int nameStart;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      nameStart = _doc.indexOf('Thomas Müller');
    });

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await tester.pumpAndSettle();

    // DISABLED — nothing selected, and the hint says what to do about it.
    expect(protectStateOf(bench.selected), ProtectState.disabled);
    expect(find.text('Select text, then Protect'), findsOneWidget);
    expect(find.text('Nothing protected by hand yet'), findsOneWidget);

    // READY — a selection the core recognises. The kind is the pack's, and the
    // count is the core's; neither is worked out in Dart.
    await tester.runAsync(() async {
      await bench.select(Span(start: nameStart, end: nameStart + 'Thomas Müller'.length));
    });
    await tester.pumpAndSettle();
    expect(protectStateOf(bench.selected), ProtectState.ready);
    expect(bench.selected!.kind, Kind.person, reason: 'the pack guessed, not the screen');
    expect(find.text('Select text, then Protect'), findsNothing);

    // Protect it, and the state the button reports changes to KNOWN — because
    // the core now says so, not because a flag was set here.
    late final ProtectOutcome? outcome;
    await tester.runAsync(() async {
      outcome = await bench.protectSelection(
        scope: Scope.conversation,
        kind: Kind.person,
        allMatches: false,
      );
    });
    await tester.pumpAndSettle();
    expect(outcome, isA<ProtectOutcome_Applied>());
    expect(protectStateOf(bench.selected), ProtectState.known);
    expect(bench.selected!.protectedAs, isNotNull);
    expect(bench.selected!.protectedBy, Source.hand);
    expect(find.textContaining('Already protected as'), findsOneWidget);

    // Undo is live now, and its hint is gone with it.
    expect(bench.canUndo, isTrue);
    expect(find.text('Nothing protected by hand yet'), findsNothing);

    // SNAPS — a selection that cuts the protected name in half. The core names
    // the whole item it would take instead, and nothing is changed by asking.
    await tester.runAsync(() async {
      await bench.select(Span(start: nameStart + 4, end: nameStart + 20));
    });
    await tester.pumpAndSettle();
    expect(protectStateOf(bench.selected), ProtectState.snaps);
    expect(bench.selected!.snapsTo, hasLength(1));
    expect(find.textContaining('cuts into something already protected'), findsOneWidget);

    // And undo takes the act back whole.
    late final UndoOutcome? undone;
    await tester.runAsync(() async {
      undone = await bench.undo();
    });
    await tester.pumpAndSettle();
    expect(undone, isA<UndoOutcome_Undone>());
    expect(bench.canUndo, isFalse);

    bench.dispose();
  });

  testWidgets('Review shows three groups, says where each sits, and Skip decides nothing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A real document, so findings carry a page and a paragraph. Typed text is
    // all one paragraph and would prove nothing about «page 17».
    const doc = 'Angebot 2026\n\n'
        'Kunde: Nordstern Consulting GmbH\n\n'
        'Ansprechpartner: Herr Thomas Müller\n\n'
        'IBAN: DE89370400440532013000\n\n'
        'Bitte prüfen Sie den Vertrag und antworten Sie kurz.';

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importDocument(
        session: session,
        name: 'Angebot.txt',
        bytes: Uint8List.fromList(utf8.encode(doc)),
        kind: DocumentKind.txt,
      );
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      bench.openReview();
    });

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewPanel), findsOneWidget);
    expect(bench.suggested, isNotEmpty, reason: 'the pack is unsure about something here');
    expect(bench.automatic, isNotEmpty, reason: 'and sure about something else');

    // The two groups are named apart, because the difference is the whole point.
    expect(find.text('WAITING FOR YOUR WORD'), findsOneWidget);
    expect(find.text('PROTECTED AUTOMATICALLY'), findsOneWidget);

    // Every finding says where it sits, and the place is the core's own.
    final placed = bench.findings.where((f) => f.place != null).toList();
    expect(placed, isNotEmpty, reason: 'a document gives every finding a place');
    for (final f in placed.take(3)) {
      expect(
        find.text('Page ${f.place!.page} · ¶${f.place!.paragraph}'),
        findsWidgets,
        reason: 'the row shows the core\'s place, not a counted guess',
      );
    }
    // And the paragraphs really differ, so the numbers mean something.
    expect(placed.map((f) => f.place!.paragraph).toSet().length, greaterThan(1));

    // SKIP decides nothing: still open, still counted, Send still shut.
    final first = bench.suggested.first;
    final openBefore = bench.openSuggestions;
    await tester.runAsync(() async => bench.answer(first.id, FindingAnswer.skip));
    await tester.pumpAndSettle();
    expect(bench.openSuggestions, openBefore, reason: 'skipping is not deciding');
    expect(bench.payload!.openSuggestions, openBefore);

    // PROTECT does decide, and every number follows in one move.
    await tester.runAsync(() async => bench.answer(first.id, FindingAnswer.protect));
    await tester.pumpAndSettle();
    expect(bench.openSuggestions, openBefore - 1);
    expect(bench.report!.suggested, bench.openSuggestions);
    expect(bench.payload!.openSuggestions, bench.openSuggestions);

    bench.dispose();
  });

  testWidgets('Reveal draws on the screen and does not touch what leaves', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    late final String safeBefore;
    late final int revisionBefore;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      for (final f in bench.suggested) {
        await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();
      bench.openTokens(true);
      safeBefore = bench.payload!.text;
      revisionBefore = bench.revision.n;
    });

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TokensPanel), findsOneWidget);
    expect(bench.tokens, isNotEmpty);
    final token = bench.tokens.firstWhere((t) => t.kind == Kind.person).token;
    expect(find.text(token), findsWidgets, reason: 'the token itself is on screen, spelled out');

    // Nothing of the real value is in the panel before Reveal is pressed. The
    // Original column shows it, of course — that is what that column is for, and
    // scoping the search to the panel is the honest way to ask this question.
    Finder inPanel(Finder what) =>
        find.descendant(of: find.byType(TokensPanel), matching: what);
    expect(inPanel(find.textContaining('Thomas Müller')), findsNothing,
        reason: 'the tokens panel does not show values until asked');

    await tester.runAsync(() async => bench.reveal(token));
    await tester.pumpAndSettle();

    // It is on screen now — locally, for a moment.
    expect(bench.revealed[token], 'Thomas Müller');
    expect(inPanel(find.text('Thomas Müller')), findsOneWidget);

    // And this is the invariant: what leaves has not moved a character, and the
    // session's revision has not turned — so no handle has gone stale either.
    late final String safeAfter;
    late final int revisionAfter;
    await tester.runAsync(() async {
      await bench.refresh();
      safeAfter = bench.payload!.text;
      revisionAfter = bench.revision.n;
    });
    expect(safeAfter, safeBefore, reason: 'Reveal wrote into the payload');
    expect(revisionAfter, revisionBefore, reason: 'Reveal turned the revision, invalidating handles');
    expect(safeAfter, isNot(contains('Thomas Müller')));

    // Hide takes it off the screen; nothing else changed either way.
    await tester.runAsync(() async => bench.hideToken(token));
    await tester.pumpAndSettle();
    expect(bench.revealed[token], isNull);
    expect(inPanel(find.text('Thomas Müller')), findsNothing);

    bench.dispose();
  });
}


/// The plain text of one column, read out of the rendered span tree rather than
/// out of the state object — so the test sees what a person would see.
String _plainOf(WidgetTester tester, Type column) {
  final selectable = tester.widget<SelectableText>(
    find.descendant(of: find.byType(column), matching: find.byType(SelectableText)),
  );
  return selectable.textSpan!.toPlainText();
}

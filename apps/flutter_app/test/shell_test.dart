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
import 'package:zprivacy/screens/answer.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
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
        onVault: () {},
        onSettings: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Z Privacy'), findsOneWidget);
    expect(find.text('Import a document'), findsOneWidget);
    expect(find.text('New private session'), findsOneWidget);
    expect(find.text('Open Z Vault'), findsOneWidget);
    // No invented history: a session lives in memory, and Home says so once.
    expect(find.text('LOCAL CONVERSATIONS'), findsNothing);
    expect(find.textContaining('Conversations are not saved after you close the app'),
        findsOneWidget);

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

  testWidgets('Send is shut while a suggestion is open, and the manual door needs no key',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
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

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await tester.pumpAndSettle();

    // Shut, with the reason beside it. There is no «send anyway» to look for.
    expect(bench.payload!.openSuggestions, greaterThan(0));
    expect(find.text('Answer the review first'), findsOneWidget);
    expect(find.textContaining('send anyway'), findsNothing);

    // Answer everything, and the door opens.
    await tester.runAsync(() async {
      for (final f in bench.suggested) {
        await z.answerFinding(session: bench.session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();
    });
    await tester.pumpAndSettle();
    expect(bench.payload!.openSuggestions, 0);
    expect(find.text('Answer the review first'), findsNothing);

    // The sheet offers the door that needs no account at all, first.
    await tester.tap(find.text('Send safe version'));
    await tester.pumpAndSettle();
    expect(find.byType(SendSheet), findsOneWidget);
    expect(find.text('Use AI yourself'), findsOneWidget);
    expect(find.text('Copy safe text'), findsOneWidget);
    expect(find.textContaining('no account, no key'), findsOneWidget);

    // And the other two doors are reachable from here without leaving: one for
    // a provider on the internet, one for a model on this machine.
    expect(find.text('Send from here'), findsOneWidget);
    expect(find.text('A model on this machine'), findsOneWidget);

    // Nothing is connected in this test, so the internet door shows its form —
    // address, model, key — and says where the key would live.
    expect(find.text('API KEY'), findsOneWidget);
    expect(find.textContaining('kept in memory for this run only'), findsOneWidget);

    // The local door is a fold, and it is below the sheet's scroll: it has to be
    // brought into view before it can be tapped, exactly as a person would.
    final localDoor = find.text('Set up a local model');
    await tester.ensureVisible(localDoor);
    await settle(tester, rounds: 1);
    await tester.tap(localDoor);
    await settle(tester, rounds: 1);

    // A model on this machine is asked for no key at all — one field fewer, not
    // an empty one. The internet door's own key field is still on screen, so the
    // claim is about the count: opening this door added a form and no key.
    expect(find.text('API KEY'), findsOneWidget,
        reason: 'the local form added a second key field');
    expect(find.text('ADDRESS'), findsNWidgets(2), reason: 'two forms, two addresses');
    expect(find.textContaining('literal loopback address'), findsOneWidget);
    expect(find.text('http://127.0.0.1:11434'), findsWidgets);

    // What the sheet shows is the payload, not a copy assembled for display.
    final shown = tester
        .widget<SelectableText>(
          find.descendant(of: find.byType(SendSheet), matching: find.byType(SelectableText)).first,
        )
        .textSpan!
        .toPlainText();
    expect(shown, bench.payload!.text);

    // Bring an answer back by hand — the token store does not care how it
    // travelled — and the real values come home.
    final safe = bench.payload!.text;
    await tester.runAsync(() async {
      await bench.pasteAnswer('Danke. Zusammenfassung:\n$safe');
    });
    await settle(tester);
    expect(bench.answers, hasLength(1));

    late final List<Segment> segments;
    late final String raw;
    await tester.runAsync(() async {
      segments = await bench.restored(bench.answers.first);
      raw = await bench.asTheModelWroteIt(bench.answers.first);
    });
    final restored = segments.map((s) => s.text).join();
    expect(raw, isNot(contains('Thomas Müller')), reason: 'the answer as it arrived holds no value');
    expect(restored, contains('Thomas Müller'), reason: 'and restoring puts it back, here');
    expect(segments.any((s) => s.restored), isTrue, reason: 'the core marks what it put back');

    bench.dispose();
  });

  testWidgets('the answer is shown twice: restored, and as the model wrote it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
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
      await bench.pasteAnswer('Verstanden:\n${bench.payload!.text}');
    });

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await settle(tester);

    expect(find.byType(AnswerPanel), findsOneWidget);
    expect(find.text('Restored'), findsOneWidget);
    expect(find.text('As the model wrote it'), findsOneWidget);

    Finder inPanel(Finder f) => find.descendant(of: find.byType(AnswerPanel), matching: f);

    // Restored is what opens, and the real value is in it — locally.
    expect(inPanel(find.textContaining('Thomas Müller')), findsOneWidget);

    // The other view is the same answer with the tokens still in it.
    await tester.tap(find.text('As the model wrote it'));
    await settle(tester);
    expect(inPanel(find.textContaining('Thomas Müller')), findsNothing);
    expect(inPanel(find.textContaining('__Z_')), findsOneWidget);

    bench.dispose();
  });

  testWidgets('pressing Send really sends, and only the safe text arrives', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // A server on this machine, standing in for a provider. `dart:io` is allowed
    // in a test; gate G5b forbids it in `lib/`, which is the part that ships.
    late final HttpServer server;
    String? bodyReceived;
    String? authReceived;
    final ground = Ground();
    late final Workbench bench;
    late final String safe;

    await tester.runAsync(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      for (final f in bench.suggested) {
        await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();
      safe = bench.payload!.text;

      server.listen((req) async {
        bodyReceived = await utf8.decodeStream(req);
        authReceived = req.headers.value('authorization');
        final reply = jsonEncode({
          'choices': [
            {'message': {'role': 'assistant', 'content': 'Verstanden:\n$safe'}}
          ]
        });
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(reply);
        await req.response.close();
      });

      // A loopback address over plain http — the one case the core allows, and
      // the one that makes a local model possible at all.
      await z.connectProvider(
        provider: const ProviderId(id: 'openai'),
        credential: 'sk-test-not-a-real-credential',
        baseUrl: 'http://127.0.0.1:${server.port}',
        model: 'a-model-name',
      );
      await ground.refresh();
    });
    addTearDown(() => server.close(force: true));

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await settle(tester);

    await tester.tap(find.text('Send safe version'));
    await settle(tester);
    expect(find.byType(SendSheet), findsOneWidget);
    // The connected provider is offered, with the model it was configured with.
    expect(find.textContaining('a-model-name'), findsOneWidget);

    await tester.tap(find.textContaining('Send to '));
    await settle(tester);

    // It went, and it came back.
    expect(bench.trouble, isNull, reason: 'the send failed: ${bench.trouble}');
    expect(bench.answers, hasLength(1));
    expect(bodyReceived, isNotNull, reason: 'the server was never contacted');

    // And what arrived is the payload, character for character, with nothing of
    // the original anywhere in the request.
    final sent = jsonDecode(bodyReceived!) as Map<String, dynamic>;
    expect((sent['messages'] as List).first['content'], safe);
    expect(sent['model'], 'a-model-name');
    for (final secret in ['Thomas Müller', 'Nordstern Consulting GmbH', 'DE89370400440532013000']) {
      expect(bodyReceived, isNot(contains(secret)));
    }
    expect(authReceived, 'Bearer sk-test-not-a-real-credential');

    // The answer panel opened on its own with the restored view.
    await settle(tester);
    expect(find.byType(AnswerPanel), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AnswerPanel), matching: find.textContaining('Thomas Müller')),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
    });
    bench.dispose();
  });

  // ------------------------------------------------------------ truthfulness
  //
  // The owner named this category on 27 September: every field a screen shows
  // as a fact must have a real source of truth, because in a privacy product
  // the honesty of the interface is part of the security. `truthfulness.rs`
  // checks it inside the core; this checks the same thing where a person would
  // read it — on the screen, in words.
  testWidgets('what the screens say is what the core says, word for word', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    late final ScanReport report;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      report = bench.report!;
    });

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
    ));
    await settle(tester, rounds: 2);

    // The band's sentence, built from the core's three numbers.
    expect(report.suggested, greaterThan(0), reason: 'the fixture leaves something open');
    expect(
      find.text('${report.auto} protected automatically · ${report.suggested} need your word · '
          '${report.normal} normal'),
      findsOneWidget,
    );

    // The Safe column may not say «exactly what the AI will receive» while
    // anything is open. It says the open count instead, and the count is the
    // core's — this is the sentence that was wrong for five milestones.
    expect(find.textContaining('This is exactly what the AI will receive'), findsNothing);
    expect(
      find.textContaining(report.suggested == 1
          ? 'One suggestion is still open'
          : '${report.suggested} suggestions are still open'),
      findsOneWidget,
    );

    // An open suggestion is drawn on the document, not only counted. Before
    // task 033 the core never produced a suggested mark at all, so the badge
    // said «3 need your word» over a document with nothing marked.
    final suggestedMarks =
        bench.document!.marks.where((m) => m.state == MarkState.suggested).length;
    expect(suggestedMarks, report.suggested,
        reason: 'the marks drawn and the number announced must be the same thing');

    // Answer them, and every one of those statements changes together.
    await tester.runAsync(() async {
      for (final f in bench.suggested) {
        await z.answerFinding(session: bench.session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();
      await bench.rescan();
    });
    await settle(tester, rounds: 2);

    expect(bench.report!.suggested, 0);
    expect(find.textContaining('suggestions are still open'), findsNothing);
    expect(find.textContaining('This is exactly what the AI will receive'), findsOneWidget);
    expect(
      bench.document!.marks.where((m) => m.state == MarkState.suggested).length,
      0,
      reason: 'nothing is waiting, so nothing is marked as waiting',
    );

    bench.dispose();
  });
}
/// `pumpAndSettle` never finishes while a real FFI future is in flight: the
/// spinner waiting on it is an animation that does not stop. So give the future
/// a real moment outside the fake-async zone, then settle.
/// Several rounds, because one is not enough: a rebuild can *start* the next
/// future — a send finishing puts the answer panel on screen, and that panel
/// then asks the core for two views of the answer.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// The plain text of one column, read out of the rendered span tree rather than
/// out of the state object — so the test sees what a person would see.
String _plainOf(WidgetTester tester, Type column) {
  final selectable = tester.widget<SelectableText>(
    find.descendant(of: find.byType(column), matching: find.byType(SelectableText)),
  );
  return selectable.textSpan!.toPlainText();
}

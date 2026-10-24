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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/widgets/the_chat.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/core/protecting.dart';
import 'package:zprivacy/widgets/review.dart';
import 'package:zprivacy/widgets/connect_form.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/widgets/tokens.dart';
import 'package:zprivacy/widgets/vault_forms.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// A document with something for each layer to find, so the band's numbers are
/// not all zero — a screen that only ever shows 0 proves nothing.
const _doc =
    'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n'
    'Bitte prüfen Sie den Vertrag.';

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(
        buildTheBridgeFirst,
      );
    }
    // The runner is started with LD_LIBRARY_PATH pointing at the built bundle.
    await RustLib.init();
  });

  // **The four tallies went with the first screen, and so did the one guard
  // that read them** — rule 70. What they said is still said, in the room that
  // is about the program rather than about a document: the vault's own state
  // and its count of identities, and the build stamp that would otherwise have
  // left the glass altogether. Same claim, same words, the surface the owner's
  // ruling leaves standing.
  testWidgets('the settings draw the ground as the core reports it, not as Dart guesses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final VaultState vault;
    late final int identities;
    late final String stamp;
    await tester.runAsync(() async {
      await ground.refresh();
      // What the core says, asked directly. The screen must agree with these.
      vault = await z.vaultState();
      identities = (await z.vaultSnapshot()).identityCount;
    });
    // The core's own line, read outside the zone like everything else it says.
    stamp = coreVersion();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            ground: ground,
            room: SettingsRoom.vault,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The vault line says the state the core is in — not a friendlier version
    // of it. A locked vault must look locked.
    switch (vault) {
      case VaultState.unlocked:
        expect(find.text('Unlocked · $identities identities'), findsOneWidget,
            reason: 'the room does not say the count the core reports');
      case VaultState.locked:
        expect(find.text(sentences.vaultIsLocked), findsOneWidget);
      case VaultState.absent:
        expect(find.text(sentences.vaultIsNone), findsOneWidget);
    }

    // **The build stamp, verbatim.** It is the core's own line and the one
    // thing a person sends with a report about a program that misbehaved; it
    // stood in the head of the first screen, and it stands in the head of this
    // panel for exactly as long as there is a panel.
    expect(find.text(stamp), findsOneWidget,
        reason: 'the build stamp is nowhere on the glass since the first screen went');
    expect(stamp, contains('z_core'), reason: 'the core stopped naming itself, so the line above proves nothing');
  });

  testWidgets('the Workspace band reports the scan the core ran, number for number', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      // What the shell does at both doors: the core scanned as it read (14
      // October, item 3), and the bench reads what arrived. A `rescan()` here
      // would be a second scan of the same text, and the band would then
      // truthfully say «manual rescan» — which is the next guard down.
      await bench.readTheScanThatArrivedWithIt();
    });

    expect(
      bench.snap,
      isNotNull,
      reason: 'the workspace is drawn from a snapshot',
    );
    expect(
      bench.report,
      isNull,
      reason: 'nothing on the glass asked for a scan, and the band must not need one',
    );
    expect(
      (bench.snap!.autoProtected + bench.snap!.openSuggestions),
      greaterThan(0),
      reason: 'the scan found something to show',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(sentences.scannedOnImport), findsOneWidget);
    expect(
      find.text(
        '${bench.snap!.autoProtected} protected automatically · ${bench.snap!.openSuggestions} need your word · '
        '${bench.snap!.normal} normal',
      ),
      findsOneWidget,
      reason: 'the band shows the snapshot numbers, derived from findings',
    );

    // The two columns exist and each carries its hard rule.
    expect(find.text('ORIGINAL — LOCAL ONLY'), findsOneWidget);
    expect(find.text('SAFE — AI WILL RECEIVE'), findsOneWidget);
    expect(
      find.text(sentences.neverSentToAiSendCannotRead),
      findsOneWidget,
    );

    // Typed text has no file name, and the bar says so rather than inventing one.
    expect(find.text(sentences.typedText), findsOneWidget);
    expect(find.text(sentences.onePage), findsOneWidget);

    // The vault's state is on the bar, and it is the state inside the snapshot —
    // one source, so the bar and the band can never contradict each other.
    final onBar = switch (bench.snap!.vault) {
      VaultState.unlocked => 'Unlocked',
      VaultState.locked => 'Locked',
      VaultState.absent => 'None',
    };
    expect(find.text(onBar), findsOneWidget);

    bench.dispose();
  });

  testWidgets('a rescan is named a rescan, not scanned on import', (
    tester,
  ) async {
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
      await bench.rescan();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(bench.scanOrigin, ScanOrigin.rescan);
    expect(find.text(sentences.lastScanManualRescan), findsOneWidget);
    expect(find.text(sentences.scannedOnImport), findsNothing);
    bench.dispose();
  });

  testWidgets('the two columns show the core\'s own two strings, and only those', (
    tester,
  ) async {
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
      for (final f in bench.findings.where(
        (f) => f.state == MarkState.suggested,
      )) {
        await z.answerFinding(
          session: session,
          finding: f.id,
          answer: FindingAnswer.protect,
        );
      }
      await bench.refresh();
      // Plain, so the token text is really in the span tree rather than inside
      // a chip widget — this test is about the string, not the drawing.
      bench.showChips(false);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final original = _plainOf(tester, OriginalText);
    final safe = _plainOf(tester, SafeText);

    // 1 · Nothing is lost in the drawing. The left column splits the text at
    // every mark to colour it; if that splitter ever dropped or reordered a
    // slice, this is where it shows.
    expect(
      original,
      bench.document!.text,
      reason:
          'the Original column must be the document, character for character',
    );

    // 2 · The right column is the payload the core built — not a copy the UI
    // assembled from the document and the token table.
    expect(
      safe,
      bench.payload!.text,
      reason:
          'the Safe column must be the core\'s payload, character for character',
    );

    // 3 · Control string first, then the claim.
    expect(
      original,
      contains('Thomas Müller'),
      reason: 'the original really holds the name',
    );
    expect(
      bench.tokens,
      isNotEmpty,
      reason: 'something was protected, so there is something to check',
    );
    for (final t in bench.tokens) {
      expect(
        safe,
        contains(t.token),
        reason: 'every token the core minted is on the Safe side',
      );
    }
    for (final secret in [
      'Thomas Müller',
      'Nordstern Consulting GmbH',
      'DE89370400440532013000',
    ]) {
      expect(
        safe,
        isNot(contains(secret)),
        reason: '«$secret» is drawn on the side that leaves',
      );
    }

    // 4 · And the sentence under the column tells the truth about suggestions.
    expect(bench.payload!.openSuggestions, 0);
    expect(
      find.textContaining('This is exactly what the AI will receive'),
      findsOneWidget,
    );

    bench.dispose();
  });

  testWidgets(
    'the Protect button is in the state the core says, not one Dart worked out',
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

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // DISABLED — nothing selected, and the hint says what to do about it.
      expect(protectStateOf(bench.selected), ProtectState.disabled);
      expect(find.text(sentences.selectTextThenProtect), findsOneWidget);
      expect(
        bench.canUndo,
        isTrue,
        reason: 'the scan created protections, so undo would actually undo',
      );

      // READY — a selection the core recognises and has not protected. Since
      // 3 October a name after a salutation is protected on sight, so the one
      // thing in this document that is still only a guess is the company: a run
      // ending in «GmbH» can be a company or a sentence about companies.
      final companyStart = _doc.indexOf('Nordstern Consulting GmbH');
      await tester.runAsync(() async {
        await bench.select(
          Span(
            start: companyStart,
            end: companyStart + 'Nordstern Consulting GmbH'.length,
          ),
        );
      });
      await tester.pumpAndSettle();
      expect(protectStateOf(bench.selected), ProtectState.ready);
      expect(
        bench.selected!.kind,
        Kind.company,
        reason: 'the pack guessed, not the screen',
      );
      expect(find.text(sentences.selectTextThenProtect), findsNothing);

      // Protect it, and the state the button reports changes to KNOWN — because
      // the core now says so, not because a flag was set here.
      late final ProtectOutcome? outcome;
      await tester.runAsync(() async {
        outcome = await bench.protectSelection(
          scope: Scope.conversation,
          kind: Kind.company,
          allMatches: false,
        );
      });
      await tester.pumpAndSettle();
      expect(outcome, isA<ProtectOutcome_Applied>());
      expect(protectStateOf(bench.selected), ProtectState.known);
      expect(bench.selected!.protectedAs, isNotEmpty);
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
      // **Two, since 085 ruling 1** (15 October): the drag cuts into both
      // words of the name, and each of them is a protected item of its own, so
      // the core names both of the whole items it would take.
      expect(bench.selected!.snapsTo, hasLength(2));
      // And the bar's own sentence for two, which was already written and had
      // no caller until the law made a name two items.
      expect(
        find.textContaining('spans 2 protected items'),
        findsOneWidget,
      );

      // And undo takes the act back whole.
      late final UndoOutcome? undone;
      await tester.runAsync(() async {
        undone = await bench.undo();
      });
      await tester.pumpAndSettle();
      expect(undone, isA<UndoOutcome_Undone>());
      expect(bench.canUndo, bench.snap?.canUndo ?? false);

      bench.dispose();
    },
  );

  testWidgets(
    'Review shows only what waits, says where each sits, and the core\'s Skip decides nothing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // A real document, so findings carry a page and a paragraph. Typed text is
      // all one paragraph and would prove nothing about «page 17».
      const doc =
          'Angebot 2026\n\n'
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

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReviewPanel), findsOneWidget);
      expect(
        bench.suggested,
        isNotEmpty,
        reason: 'the pack is unsure about something here',
      );
      expect(
        bench.automatic,
        isNotEmpty,
        reason: 'and sure about something else',
      );

      // **The groups are gone, and with them the question they answered**
      // (083, ruling 6, 14 Oct). The list holds what waits; what the app
      // protected by itself and what a person decided are seen in the text,
      // where they are. So the two titles are not drawn, and neither is the
      // row of a value nobody has to answer.
      expect(find.text('WAITING FOR YOUR WORD'), findsNothing);
      expect(find.text('PROTECTED AUTOMATICALLY'), findsNothing);
      final auto = bench.automatic.first;
      expect(
        find.text(bench.document!.text.substring(auto.span.start, auto.span.end)),
        findsNothing,
        reason: 'a value the app took by itself is in the list, where nothing waits for it',
      );

      // Every waiting word says where it sits, and the place is the core's own.
      final placed = bench.suggested.where((f) => f.place != null).toList();
      expect(
        placed,
        isNotEmpty,
        reason: 'a document gives every finding a place',
      );
      for (final f in placed.take(3)) {
        expect(
          find.text('Page ${f.place!.page} · ¶${f.place!.paragraph}'),
          findsWidgets,
          reason: 'the row shows the core\'s place, not a counted guess',
        );
      }
      // And the paragraphs really differ, so the numbers mean something.
      expect(
        bench.findings.where((f) => f.place != null).map((f) => f.place!.paragraph).toSet().length,
        greaterThan(1),
      );

      // **SKIP decides nothing** — and no button says it any more: leaving a
      // word for later is the Next press, which answers nothing at all
      // (ruling 5). What is measured here is the core's own `Skip`, which 083
      // does not touch: it stays open, stays counted, and the door stays shut.
      // The day the core loses it, this is where that is noticed.
      final first = bench.suggested.first;
      final openBefore = bench.openSuggestions;
      await tester.runAsync(
        () async => bench.answer(first.id, FindingAnswer.skip),
      );
      await tester.pumpAndSettle();
      expect(
        bench.openSuggestions,
        openBefore,
        reason: 'skipping is not deciding',
      );
      expect(bench.payload!.openSuggestions, openBefore);

      // PROTECT does decide, and every number follows in one move.
      await tester.runAsync(
        () async => bench.answer(first.id, FindingAnswer.protect),
      );
      await tester.pumpAndSettle();
      expect(bench.openSuggestions, openBefore - 1);
      expect(bench.report!.suggested, bench.openSuggestions);
      expect(bench.payload!.openSuggestions, bench.openSuggestions);

      bench.dispose();
    },
  );

  // And the other way a screen can keep a secret: not by being told to hold it,
  // but by failing to ask. If the authority cannot be reached, the honest move
  // is to hide — a screen that keeps a value because the question failed is
  // deciding for itself how long a secret stays on it, which is the whole thing
  // this design refuses.
  //
  // Reachable, not hypothetical: a session closed in the core answers
  // `InvalidSession` to every question about it.
  testWidgets('when the core cannot be asked, the panel hides rather than keeps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    late final SessionId session;
    await tester.runAsync(() async {
      await freshVaultForUiTest('asking-fails');
      await ground.refresh();
      session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      for (final f in bench.suggested) {
        await z.answerFinding(
          session: session,
          finding: f.id,
          answer: FindingAnswer.protect,
        );
      }
      await bench.refresh();
      bench.openTokens(true);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final token = bench.tokens.firstWhere((t) => t.kind == Kind.person).token;
    await tester.runAsync(() async => bench.reveal(token));
    await tester.pumpAndSettle();

    // **The value of the token that was revealed**, read from the bench rather
    // than written down here: since 085 ruling 1 (15 October) the name in this
    // document is one token per word, so a reveal of one of them shows one
    // word. Which word is not what this test is about — that the panel shows
    // what was revealed, and stops showing it, is.
    final shown = bench.revealed[token]!;
    expect(['Thomas', 'Müller'], contains(shown));

    Finder inPanel(Finder what) =>
        find.descendant(of: find.byType(TokensPanel), matching: what);
    expect(inPanel(find.text(shown)), findsOneWidget);

    // The conversation is closed underneath the screen. Nothing is told to
    // hide; the next question simply cannot be answered.
    await tester.runAsync(() => z.closeSession(session: session));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      if (inPanel(find.text(shown)).evaluate().isEmpty) break;
    }

    expect(
      inPanel(find.text(shown)),
      findsNothing,
      reason: 'the value stayed on screen when the core could not be asked',
    );
    expect(bench.revealed, isEmpty, reason: 'the UI still holds the text');
  });

  // The screen's half of «a reveal does not live past a lock». The core is the
  // authority — it stops listing the token — and this proves the panel asks and
  // obeys rather than keeping the text because nobody told it to let go.
  //
  // A vault is made on purpose: locking with nothing open is not a lock, and
  // must not take down a reveal no key was turned on.
  testWidgets('locking the vault takes the revealed tokens with it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await freshVaultForUiTest('tokens-and-the-lock');
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      for (final f in bench.suggested) {
        await z.answerFinding(
          session: session,
          finding: f.id,
          answer: FindingAnswer.protect,
        );
      }
      await bench.refresh();
      bench.openTokens(true);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final token = bench.tokens.firstWhere((t) => t.kind == Kind.person).token;
    await tester.runAsync(() async => bench.reveal(token));
    await tester.pumpAndSettle();

    final shown = bench.revealed[token]!;
    Finder inPanel(Finder what) =>
        find.descendant(of: find.byType(TokensPanel), matching: what);
    expect(
      inPanel(find.text(shown)),
      findsOneWidget,
      reason: 'the reveal did not reach the panel',
    );

    // The vault closes. Nothing here is told to hide: the panel finds out by
    // asking, on its own second-by-second tick.
    await tester.runAsync(() => z.vaultLock());
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      if (inPanel(find.text(shown)).evaluate().isEmpty) break;
    }

    expect(
      inPanel(find.text(shown)),
      findsNothing,
      reason: 'the value stayed in the panel after the vault was locked',
    );
    expect(bench.revealed[token], isNull, reason: 'the UI still holds the text');
  });

  testWidgets('Reveal draws on the screen and does not touch what leaves', (
    tester,
  ) async {
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
        await z.answerFinding(
          session: session,
          finding: f.id,
          answer: FindingAnswer.protect,
        );
      }
      await bench.refresh();
      bench.openTokens(true);
      safeBefore = bench.payload!.text;
      revisionBefore = bench.revision.n;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TokensPanel), findsOneWidget);
    expect(bench.tokens, isNotEmpty);
    final token = bench.tokens.firstWhere((t) => t.kind == Kind.person).token;
    expect(
      find.text(token),
      findsWidgets,
      reason: 'the token itself is on screen, spelled out',
    );

    // Nothing of the real value is in the panel before Reveal is pressed. The
    // Original column shows it, of course — that is what that column is for, and
    // scoping the search to the panel is the honest way to ask this question.
    Finder inPanel(Finder what) =>
        find.descendant(of: find.byType(TokensPanel), matching: what);
    expect(
      inPanel(find.textContaining('Thomas Müller')),
      findsNothing,
      reason: 'the tokens panel does not show values until asked',
    );

    await tester.runAsync(() async => bench.reveal(token));
    await tester.pumpAndSettle();

    // It is on screen now — locally, for a moment. One word, because the name
    // is one token per word since 085 ruling 1 (15 October).
    final shown = bench.revealed[token]!;
    expect(['Thomas', 'Müller'], contains(shown));
    expect(inPanel(find.text(shown)), findsOneWidget);

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
    expect(
      revisionAfter,
      revisionBefore,
      reason: 'Reveal turned the revision, invalidating handles',
    );
    expect(safeAfter, isNot(contains('Thomas Müller')));

    // Hide takes it off the screen; nothing else changed either way.
    await tester.runAsync(() async => bench.hideToken(token));
    await tester.pumpAndSettle();
    expect(bench.revealed[token], isNull);
    expect(inPanel(find.text(shown)), findsNothing);

    bench.dispose();
  });

  testWidgets(
    'Send is shut while a suggestion is open, and the manual door needs no key',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ground = Ground();
      late final Workbench bench;
      await tester.runAsync(() async {
        // **This journey is about the doors, not about sessions — said out
        // loud**, in `reviewJourney`'s own words and for its own reason: the
        // core's vault state is global, an earlier test in this file leaves
        // one unlocked, and with one unlocked the sheet begins a session at
        // the press — «and the nameless press copied nothing». Measured here
        // too: with a vault made for this test, «Copy Protected» wrote nothing
        // at all and the sheet kept standing.
        //
        // What it means for the tail below: with no vault there is no session,
        // so an answer brought back by hand is kept nowhere — which is the
        // state the chat says out loud, and what is measured there.
        await z.vaultLock();
        await ground.refresh();
        final session = await z.openSession(packId: 'de');
        await z.importText(session: session, text: _doc);
        bench = Workbench(session: session, profileId: null, packId: 'de');
        await bench.rescan();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            bench: bench,
            ground: ground,
            onImport: () {}, onAsk: (_) {},
            onVault: () {},
            // Given a panel to open because this test asks the sheet for its
            // way to the settings, and a surface with nowhere to send the
            // press draws no door rather than a dead one. The other fourteen
            // mounts in this file are left alone: fourteen doors that open
            // nothing would be fourteen lies the compiler was enforcing.
            onSettings: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shut, and the line beside it names the count and offers the way
      // through (046/L). It used to say «Answer the review first», which named
      // no number, no value and no way in. There is still no «send anyway» to
      // look for — that is the half of this that did not change.
      final open = bench.payload!.openSuggestions;
      expect(open, greaterThan(0));
      expect(
        find.textContaining('question', findRichText: true),
        findsWidgets,
        reason: 'the shut door says nothing about what is waiting',
      );
      expect(find.textContaining('send anyway'), findsNothing);

      // Answer everything, and the door opens.
      await tester.runAsync(() async {
        for (final f in bench.suggested) {
          await z.answerFinding(
            session: bench.session,
            finding: f.id,
            answer: FindingAnswer.protect,
          );
        }
        await bench.refresh();
      });
      await tester.pumpAndSettle();
      expect(bench.payload!.openSuggestions, 0);
      // With nothing open the way-through line is gone with the questions.
      expect(find.textContaining('questions left'), findsNothing);
      expect(find.textContaining('question left'), findsNothing);

      // **What is drawn is the payload, not a copy assembled for display** —
      // and since rule 60 the place it is drawn is the preview side of the work
      // surface, which says so in its own subtitle: «The request itself, not a
      // preview of it». Read through «Plain», the side's own control, because
      // «Chips» draws each token as a widget and a widget is not a character.
      await tester.tap(find.text(sentences.drawnPlain));
      await tester.pumpAndSettle();
      final shown = tester
          .widget<SelectableText>(
            find
                .descendant(
                  of: find.byKey(const ValueKey<String>('workspace-safe-pane')),
                  matching: find.byType(SelectableText),
                )
                .first,
          )
          .textSpan!
          .toPlainText();
      expect(shown, bench.payload!.text);

      // The sheet offers the door that needs no account at all, first — and it
      // offers it on the only page it has.
      await tester.tap(find.text(sentences.chooseWhoAnswers));
      await tester.pumpAndSettle();
      expect(find.byType(SendSheet), findsOneWidget);
      expect(find.text(sentences.manualAi), findsOneWidget);
      expect(find.text(sentences.copyProtected), findsOneWidget);
      expect(find.textContaining('no account, no key'), findsOneWidget);

      // Copy Protected is the first door's act — take it while it is on screen,
      // before the local fold is scrolled into view.
      final clip = _ClipboardProbe(tester)..install();
      await tester.tap(find.text(sentences.copyProtected));
      await settle(tester, rounds: 8);
      final safe = bench.payload!.text;
      expect(
        clip.text,
        safe,
        reason: 'Copy Protected puts the SafePayload on the clipboard, exactly',
      );
      for (final secret in [
        'Thomas Müller',
        'Nordstern Consulting GmbH',
        'DE89370400440532013000',
      ]) {
        expect(
          clip.text,
          isNot(contains(secret)),
          reason: '«$secret» left on the Copy Protected path',
        );
      }

      // And the other two doors are reachable from here without leaving: one for
      // a provider on the internet, one for a model on this machine.
      expect(find.text(sentences.directApi), findsOneWidget);
      expect(find.text(sentences.localAi), findsOneWidget);

      // **The setup changed on 8 October; the claim above did not.** Both doors
      // used to show their own `ConnectForm` here — address, model, key — and
      // this test asserted the fields: one API KEY, two ADDRESS, the loopback
      // sentence. The owner moved every one of those out of the work: «وضعنا
      // إعدادات الذكاء في شاشة الإعدادات وبالتالي لا تظهر أثناء العمل أبداً».
      //
      // So what the sheet is asked for here is what it now offers — the way to
      // the one place a key is given, and no form. **The field claims were not
      // dropped**: they are about `ConnectForm`'s own content and they moved
      // with it, to `the_keys_live_in_the_settings_test.dart`, where they are
      // asserted against the settings panel at the 444 px its content really
      // gets.
      expect(
        find.byType(ConnectForm),
        findsNothing,
        reason: 'a key form stands in the send flow, where the owner said it never appears',
      );
      expect(
        find.text(sentences.openSettings),
        findsWidgets,
        reason: 'no form and no way to reach the place a key is given',
      );

      // **Bring an answer back by hand, on a bench with no key at all.**
      //
      // This journey never makes a vault — that is its subject: «the manual
      // door needs no key». Since rule 69 an exchange is kept in the session's
      // own file, and a session is named from a key, so there is nothing here
      // for this answer to be kept in. What is measured is therefore what this
      // bench can honestly say: the chat opens where the work is (rule 65) and
      // it says in words that nothing is keeping what came back, rather than
      // drawing a thread that does not exist.
      //
      // **The pair itself — the answer coded, the names restored — is measured
      // through the same door with a session**: «the answer is coded in the
      // thread, and the names come back in its bubble» below, and
      // `the_chat_is_the_third_part_test`. It was measured here from
      // `bench.answers`, the payload's own list, which needed no session;
      // `answerFacts` fed the panel rule 65 deleted and the session's turn is
      // the one source now.
      await tester.runAsync(() async {
        await bench.pasteAnswer('Danke. Zusammenfassung:\n$safe');
      });
      await settle(tester);
      expect(bench.chatTurns, isEmpty,
          reason: 'a turn was kept on a bench with no vault to name a session');
      expect(find.byType(TheChat), findsOneWidget,
          reason: 'the answer did not open the third part of the screen');
      expect(
        find.descendant(
          of: find.byType(TheChat),
          matching: find.textContaining(theChatKeepsNothing),
        ),
        findsOneWidget,
        reason: 'an answer no session can keep is drawn as though it were kept',
      );
      expect(
        find.descendant(
          of: find.byType(TheChat),
          matching: find.textContaining('Thomas Müller'),
        ),
        findsNothing,
        reason: 'the panel drew a name the model never saw',
      );

      bench.dispose();
    },
  );

  // **«Shown twice» became «coded, and the names one press away»** — rule 66,
  // 17 October. The panel had a tab over the whole of it — «Restored» or «As
  // the model wrote it» — and the owner's ruling turns that around: the thread
  // draws what travelled, coded, and the restored text opens in a bubble under
  // the answer it belongs to. Both views are still on the glass; what changed
  // is which of them is the default and how far the other one is.
  testWidgets(
    'the answer is coded in the thread, and the names come back in its bubble',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1700, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ground = Ground();
      late final Workbench bench;
      await tester.runAsync(() async {
        await freshVaultForUiTest('coded-thread');
        await ground.refresh();
        final session = await z.openSession(packId: 'de');
        await z.importText(session: session, text: _doc);
        bench = Workbench(session: session, profileId: null, packId: 'de');
        await bench.rescan();
        for (final f in bench.suggested) {
          await z.answerFinding(
            session: session,
            finding: f.id,
            answer: FindingAnswer.protect,
          );
        }
        await bench.refresh();
        // The session first, then the handle: a birth renames every token in
        // it, and a payload remembered before it would carry the old names.
        await aSessionToKeepItIn(ground, bench);
        bench.rememberCopiedPayload();
        await bench.pasteAnswer('Verstanden:\n${bench.payload!.text}');
      });

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
        ),
      );
      await settle(tester);

      expect(find.byType(TheChat), findsOneWidget);
      Finder inChat(Finder f) =>
          find.descendant(of: find.byType(TheChat), matching: f);

      // **Coded is what the thread draws**, and the name is not in it.
      expect(inChat(find.textContaining('__Z_')), findsWidgets);
      expect(inChat(find.textContaining('Thomas Müller')), findsNothing,
          reason: 'the thread draws a name the model never saw');
      // And no tab over the panel: there is nothing to switch any more.
      expect(find.text('As the model wrote it'), findsNothing);

      // **One press, and the names are in the bubble** — and nowhere else.
      await tester.tap(find.byKey(TheChat.showTheText(0)));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(TheChat.bubble(0)),
          matching: find.textContaining('Thomas Müller'),
        ),
        findsOneWidget,
        reason: 'the restored value is not in the bubble the press opened',
      );

      bench.dispose();
    },
  );

  testWidgets('Copy Restored leaves the clipboard untouched until confirmed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    late final String restored;
    late final String raw;
    await tester.runAsync(() async {
      await freshVaultForUiTest('copy-restored');
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      for (final f in bench.suggested) {
        await z.answerFinding(
          session: session,
          finding: f.id,
          answer: FindingAnswer.protect,
        );
      }
      await bench.refresh();
      // The session first, then the handle, for the reason above.
      await aSessionToKeepItIn(ground, bench);
      bench.rememberCopiedPayload();
      await bench.pasteAnswer('Verstanden:\n${bench.payload!.text}');
      // **Read from the turn the core wrote**, which is what the thread draws:
      // the restored segments and the answer as it arrived. `answerFacts` fed
      // the panel that is gone, and asking the session for its own turn is one
      // source rather than two for the same pair.
      final turn = bench.chatTurns.last;
      restored = turn.answer.map((s) => s.text).join();
      raw = turn.answerAsWritten;
    });

    final clip = _ClipboardProbe(tester)..install();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await settle(tester);

    Finder inPanel(Finder f) =>
        find.descendant(of: find.byType(TheChat), matching: f);

    // **The press lives in the bubble since rule 66**: the restored text and
    // the way to copy it are one thing, opened together.
    await tester.tap(find.byKey(TheChat.showTheText(0)));
    await settle(tester);
    expect(inPanel(find.text(sentences.copyRestored)), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(restored, contains('Thomas Müller'));

    // **Brought into view before it is pressed.** The press lives in the
    // bubble, the bubble opens under the turn it belongs to, and after ed's A1
    // the first turn is the whole payload the model saw — so «Copy Restored»
    // stood 33 px under a 1100-tall window and `tap` derived an offset outside
    // the render tree. Only a press sees a scroller's clip.
    await tester.ensureVisible(inPanel(find.text(sentences.copyRestored)));
    await settle(tester, rounds: 2);
    await tester.tap(inPanel(find.text(sentences.copyRestored)));
    await tester.pumpAndSettle();

    expect(find.text(sentences.copyRestoredTextQuestion), findsOneWidget);
    expect(find.textContaining('real protected values'), findsOneWidget);
    expect(find.textContaining('system clipboard'), findsOneWidget);
    expect(
      find.textContaining('Other applications may be able to read'),
      findsOneWidget,
    );
    // **081, the lead's ruling of 13 October: this is an exit press.** The
    // emptying happens before the question is even asked, so the real values
    // are still not on the clipboard — and whatever the person had copied
    // before is not there either, which is what the old `'SENTINEL'` reading
    // allowed and the owner's leak walked through.
    expect(
      clip.wrote,
      [''],
      reason: 'the press must empty the clipboard before it asks, and write '
          'nothing else until the person confirms: it wrote ${clip.wrote}',
    );
    expect(clip.text, '', reason: 'the restored values reached the clipboard unasked');

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // **A cancelled confirmation leaves the clipboard empty, not old.** The
    // press answered for the clipboard that follows it, whatever the person
    // then chose — so nothing of the real values, and nothing from before.
    expect(clip.wrote, [''], reason: 'Cancel wrote something: ${clip.wrote}');
    expect(clip.text, '', reason: 'Cancel left the clipboard holding something');
    expect(
      find.text(sentences.restoredTextCopied),
      findsNothing,
    );

    await tester.tap(inPanel(find.text(sentences.copyRestored)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(sentences.copyRestored),
      ),
    );
    await tester.pumpAndSettle();

    // Two presses so far, each with its own emptying, and one write of the
    // restored text after the person said so.
    expect(clip.wrote, ['', '', restored],
        reason: 'the confirmed press did not empty and then copy: ${clip.wrote}');
    expect(clip.text, restored);
    expect(
      find.text(sentences.restoredTextCopied),
      findsOneWidget,
    );
    expect(find.textContaining('Copied securely'), findsNothing);

    // The warning is not a one-time tutorial: the next press asks again.
    await tester.tap(inPanel(find.text(sentences.copyRestored)));
    await tester.pumpAndSettle();
    expect(find.text(sentences.copyRestoredTextQuestion), findsOneWidget);
    // And the third press emptied it again before asking — so the values the
    // person copied a moment ago are **gone** while the question stands.
    expect(clip.wrote, ['', '', restored, ''],
        reason: 'the press that asks again did not empty first: ${clip.wrote}');
    expect(clip.text, '', reason: 'the restored text survived the next press');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(clip.wrote, ['', '', restored, ''],
        reason: 'Cancel wrote something: ${clip.wrote}');
    expect(clip.text, '',
        reason: 'a cancelled press left the old restored text to be pasted — '
            'which is the owner’s own leak, in the panel instead of the exit');

    // **The coded copy is not behind a tab any more** — rule 66, and the claim
    // moves with the door rather than going.
    //
    // The panel had «As the model wrote it» over the whole of it and the coded
    // copy stood on that side. The thread draws the coded form by default now,
    // so there is nothing to switch to, and what takes it out is rule 65's own
    // door at the foot of the chat: «Copy the chat», which hands over the
    // **payload** — what would leave by the app's own door, protected (the
    // owner, 24 October 2026: «خارج التطبيق لا يأخذ إلا ما يراه المستخدم على
    // الشاشة»). The in-app door sends that same payload with the exchange
    // before it added on top; the clipboard is the payload alone. What was being measured here — **a
    // coded copy asks nothing and leaves no name behind** — is measured on
    // that door.
    //
    // **A question is typed first, and that is not scenery.** This walk never
    // typed one — it copied the payload out and pasted an answer back — so
    // under the law above there is nothing on the screen that would leave, and
    // the press has nothing to take out: measured, the clipboard came back
    // empty (the press empties first and writes only on success, 081). With a
    // question in the box the claim this guard is about can be measured at
    // all: **a coded copy asks nothing and leaves no name behind.** The name
    // in it is the one the document taught, so `set_question` protects it with
    // the same packs the document was read with (rule 72-ب).
    expect(find.text('As the model wrote it'), findsNothing,
        reason: 'the tab rule 66 deleted is back over the answer');
    await tester.runAsync(() => bench.setQuestion('Was schuldet Thomas Müller?'));
    await settle(tester, rounds: 2);
    await tester.tap(inPanel(find.text(sentences.copyTheChat)));
    await settle(tester, rounds: 4);
    expect(find.byType(AlertDialog), findsNothing,
        reason: 'taking the coded chat out asked a question it does not need to ask');
    expect(clip.text, contains('__Z_'),
        reason: 'what left carries no token, so it is not the payload: «${clip.text}»');
    expect(clip.text, isNot(contains('Thomas Müller')),
        reason: 'the chat that left holds a name the model never saw');
    expect(clip.text, isNot(contains(raw)),
        reason: 'the answer the model wrote left with the payload — the clipboard is '
            'what would leave, and the exchange before it is the in-app door’s addition');

    bench.dispose();
  });

  testWidgets(
    'profiles are created, renamed, switched, and scope what the vault learns',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const taught = 'ZXQPROFILEONLY778899';
      const doc =
          'Internal reference: $taught\nNo general rule should know this value.';
      final ground = Ground();
      late final Workbench bench;
      late final SessionId session;

      // **The first profile is setup since 075a**, not a step of this test.
      // The header's profile door now waits until there is something to choose
      // — two profiles, or a bench already inside one — so a vault with none
      // offers no way in from this screen, by design. Every claim below is
      // still made here: creating, renaming, switching and scoping. Only the
      // state they start from is stated rather than clicked, and creating the
      // *first* profile from the board is covered by
      // `the_profile_door_waits_for_a_choice_test.dart`.
      late final String first;
      await tester.runAsync(() async {
        await freshVaultForUiTest('profiles');
        first = await z.createProfile(name: 'Client A', session: null);
        await ground.refresh();
        session = await z.openSession(packId: 'de');
        await z.importText(session: session, text: doc);
        bench = Workbench(session: session, profileId: null, packId: 'de');
        await bench.switchProfile(first);
        await bench.rescan();
      });
      addTearDown(bench.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
        ),
      );
      await settle(tester);

      // By the door's name and not by the word on it: the top bar reads
      // «Client A» now that the bench is inside it, and a finder that hunts a
      // label follows the label about.
      await tester.tap(find.byKey(ProfileSwitcher.door));
      await settle(tester);
      expect(find.byType(ProfileSwitcher), findsOneWidget);

      /// In the dialog, not merely on the screen: since 075a the top bar names
      /// the profile the bench is in, so an unscoped finder for a profile's
      /// name answers twice and says nothing about this list.
      Finder inDialog(Finder of) =>
          find.descendant(of: find.byType(ProfileSwitcher), matching: of);

      expect(inDialog(find.text('Client A')), findsOneWidget);
      expect(inDialog(find.text(sentences.profileActive)), findsOneWidget);

      await tester.tap(find.text(sentences.createProfile));
      await settle(tester);
      expect(find.byType(ProfileForm), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(ProfileForm),
          matching: find.byType(TextField),
        ),
        'Client B',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(ProfileForm),
          matching: find.text(sentences.createIt),
        ),
      );
      await settle(tester);
      expect(find.text('Client B'), findsOneWidget);

      await tester.tap(find.text('Rename').first);
      await settle(tester);
      expect(find.byType(ProfileForm), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(ProfileForm),
          matching: find.byType(TextField),
        ),
        'Nordstern',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(ProfileForm),
          matching: find.text('Rename'),
        ),
      );
      await settle(tester);
      expect(inDialog(find.text('Nordstern')), findsOneWidget);
      expect(find.text('Client A'), findsNothing);

      // Client B is active after it was created. Switch back to the renamed
      // profile from the UI; the top bar must show the human name, not the ID.
      await tester.tap(find.text(sentences.profileSwitch).at(1));
      await settle(tester);
      await tester.tap(find.text(sentences.done));
      await settle(tester);
      expect(find.text('Nordstern'), findsOneWidget);
      expect(bench.profileId, isNotNull);

      // And switching can go the other way from the same top-bar entry.
      await tester.tap(find.text('Nordstern').first);
      await settle(tester);
      await tester.tap(find.text(sentences.profileSwitch).last);
      await settle(tester);
      await tester.tap(find.text(sentences.done));
      await settle(tester);
      expect(find.text('Client B'), findsOneWidget);

      // Leave the open conversation in Nordstern before teaching a profile-scoped
      // value, then prove another profile does not inherit it.
      await tester.tap(find.text('Client B').first);
      await settle(tester);
      await tester.tap(find.text(sentences.profileSwitch).last);
      await settle(tester);
      await tester.tap(find.text(sentences.done));
      await settle(tester);
      expect(find.text('Nordstern'), findsOneWidget);

      late final String profileA;
      late final String profileB;
      await tester.runAsync(() async {
        await ground.refresh();
        profileA = ground.profiles.firstWhere((p) => p.name == 'Nordstern').id;
        profileB = ground.profiles.firstWhere((p) => p.name == 'Client B').id;
        expect(bench.profileId, profileA);

        final start = doc.indexOf(taught);
        await z.protect(
          session: session,
          span: Span(start: start, end: start + taught.length),
          scope: Scope.profile,
          kind: Kind.custom,
        );
        await bench.refresh();

        final b = await z.openSession(profileId: profileB, packId: 'de');
        await z.importText(session: b, text: doc);
        await z.scan(session: b);
        final bTokens = await z.listTokens(session: b);
        // **Rule 58, the owner on 16 October** — «البلوك يعبر من ملف عميل إلى
        // ملف عميل… فالبلوك في خزنة المستخدم لا في ملف العميل». The line that
        // stood here asked that Client B inherit nothing at all, and it was
        // parked while two rules of his collided: 089 rule 1 (every word that
        // took a token is a block in **his** vault and comes back wherever it
        // stands) against 079 rule two (a value of one profile is not loaded
        // in another). He has now ruled for the block, with one condition —
        // nothing on the glass may say where or when the word was first
        // protected — which the core measures by name
        // (`a_blocks_card_says_no_where_and_no_when`).
        //
        // So B reads the word back, and what B is **not** told is anything
        // about Client A: the finding names the block and no identity. The
        // profile's own half of rule two is measured in the core, in
        // `vault_layer::rule_two_a_value_in_another_profile_is_not_loaded`.
        expect(
          bTokens,
          isNotEmpty,
          reason: 'the word Client A protected did not come back for Client B (rule 58)',
        );
        const aBlock = 'a word you protected';
        final named = (await z.listFindings(session: b))
            .where((f) => f.source == Source.vault)
            .expand((f) => f.entities)
            .where((who) => who != aBlock)
            .toList();
        expect(
          named,
          isEmpty,
          reason: "Client A's own knowledge crossed with the block: $named",
        );
        await z.closeSession(session: b);

        final a = await z.openSession(profileId: profileA, packId: 'de');
        await z.importText(session: a, text: doc);
        await z.scan(session: a);
        final aTokens = await z.listTokens(session: a);
        expect(
          aTokens.where((t) => t.kind == Kind.custom),
          isNotEmpty,
          reason: 'Client A should auto-protect the value taught in Client A',
        );
        final safe = await z.payloadView(
          handle: await z.buildPayload(session: a),
        );
        expect(safe.text, isNot(contains(taught)));
        await z.closeSession(session: a);
      });
    },
  );

  testWidgets('pressing Send really sends, and only the safe text arrives', (
    tester,
  ) async {
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
      // **This journey is about the wire, not about sessions** — the same line
      // and the same reason as `reviewJourney`'s, one door further along. It
      // never made a vault; the core's vault state is global and an earlier
      // test in this file leaves one unlocked, so after 064/A the send door
      // asked it for a session name and the nameless press sent nothing. A
      // journey that measures the bytes and the Authorization header should
      // not depend on session state at all, and this line says so.
      //
      // The state it stops covering — a send **with** a session, and what the
      // wire then carries — is measured in `the_third_exit_test`, whose fake
      // provider keeps the request body: guard 1 proves the names on it are
      // the newborn session's and none of the pre-birth ones.
      await z.vaultLock();
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      for (final f in bench.suggested) {
        await z.answerFinding(
          session: session,
          finding: f.id,
          answer: FindingAnswer.protect,
        );
      }
      await bench.refresh();
      safe = bench.payload!.text;

      server.listen((req) async {
        bodyReceived = await utf8.decodeStream(req);
        authReceived = req.headers.value('authorization');
        final reply = jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': 'Verstanden:\n$safe'},
            },
          ],
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

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await settle(tester);

    await tester.tap(find.text(sentences.chooseWhoAnswers));
    await settle(tester);
    expect(find.byType(SendSheet), findsOneWidget);
    // The connected provider is offered, with the model it was configured
    // with — read in **its own line**, «label · model · endpoint».
    //
    // It used to be `textContaining('a-model-name')` anywhere on the glass,
    // and that was unambiguous only while the sheet had two pages: the
    // chooser named the model on the first and this line named it on the
    // second. Rule 60 put them on one page, so the loose finder matches twice
    // and a guard that wants «the door offers the configured model» has to say
    // which of the two it means. The chooser's claim — which model will answer
    // — is measured by `a_door_you_can_see_test` at the wire.
    expect(
      find.textContaining('· a-model-name ·'),
      findsOneWidget,
      reason: 'the Direct API door does not name the model this provider was configured with',
    );

    await tester.tap(find.textContaining('Send to '));
    await settle(tester);

    // It went, and it came back.
    expect(bench.trouble, isNull, reason: 'the send failed: ${bench.trouble}');
    // **What proves the answer arrived, in a journey with no session.** The
    // record of an exchange is the session's own turn since rule 69, and this
    // test locks the vault on purpose — «about the wire, not about sessions»,
    // the line above — so there is no session to keep a turn in and the chat
    // draws nothing. `lastUsage` is written from the `ModelAnswer` the bridge
    // decoded, so it is set only if a model answered, which is the whole of
    // what this line ever claimed. The turn is measured where a session
    // exists: `the_chat_is_the_third_part_test` and `the_third_exit_test`.
    expect(bench.lastUsage, isNotNull,
        reason: 'no answer came back through the door');
    expect(bodyReceived, isNotNull, reason: 'the server was never contacted');

    // And what arrived is the payload, character for character, with nothing of
    // the original anywhere in the request.
    final sent = jsonDecode(bodyReceived!) as Map<String, dynamic>;
    expect((sent['messages'] as List).first['content'], safe);
    expect(sent['model'], 'a-model-name');
    for (final secret in [
      'Thomas Müller',
      'Nordstern Consulting GmbH',
      'DE89370400440532013000',
    ]) {
      expect(bodyReceived, isNot(contains(secret)));
    }
    expect(authReceived, 'Bearer sk-test-not-a-real-credential');

    // **The chat opened on its own** — rule 65: an answer does not land on a
    // screen of its own any more, the third part of this one opens where the
    // work is. That much is true with no session: the panel stands, and it
    // says in words that nothing is keeping what came back.
    //
    // **What the thread draws is measured where a session exists**, which is
    // not a reach this test can make: it locks the vault on purpose, so there
    // is no session, no turn, and nothing for the thread to draw. The coded
    // thread and the name behind «Show the text» are rules 65 and 66, and
    // they are measured against a real exchange in «the answer is coded in
    // the thread» above and in `the_chat_is_the_third_part_test`, both of
    // which begin a session first. Pressing `showTheText(0)` here found no
    // widget at all — the honest shape of a chat with nothing in it.
    await settle(tester);
    expect(find.byType(TheChat), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TheChat),
        matching: find.textContaining('Thomas Müller'),
      ),
      findsNothing,
      reason: 'the thread drew a name the model never saw',
    );
    expect(
      find.descendant(
        of: find.byType(TheChat),
        matching: find.textContaining(theChatKeepsNothing),
      ),
      findsOneWidget,
      reason: 'an answer no session can keep is drawn as though it were kept',
    );

    await tester.runAsync(() async {
      await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
    });
    bench.dispose();
  });

  // ------------------------------------------------------ 1280×720 review flow
  //
  // The human run could not reach Copy Protected / the manual door / Send from
  // here at this size: the payload swallowed the wheel, and the doors lived
  // below the window. These tests walk the journey, not just takeException().

  for (final size in const [
    Size(1280, 720),
    Size(1366, 768),
    Size(1580, 980),
  ]) {
    testWidgets(
      'the send review stays usable at ${size.width.toInt()}×${size.height.toInt()}',
      (tester) async {
        await reviewJourney(
          tester,
          size: size,
          text: longContract(sections: 48, extras: 4),
        );
      },
    );
  }

  testWidgets('many findings keep the review footer on screen at 1280×720', (
    tester,
  ) async {
    await reviewJourney(
      tester,
      size: const Size(1280, 720),
      text: longContract(sections: 24, extras: 28),
      requireManyProtections: true,
    );
  });

  testWidgets(
    'a long SafePayload keeps the review footer on screen at 1280×720',
    (tester) async {
      await reviewJourney(
        tester,
        size: const Size(1280, 720),
        text: longContract(sections: 90, extras: 2),
        requireLongPayload: true,
      );
    },
  );

  testWidgets('open suggestions do not push the review footer off 1280×720', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(
        session: session,
        text: longContract(sections: 36, extras: 20),
      );
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });
    addTearDown(bench.dispose);

    expect(
      bench.payload!.openSuggestions,
      greaterThan(5),
      reason: 'this case is the many-suggestions shape, not the golden two',
    );

    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              host = ctx;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    showDialog<void>(
      context: host,
      builder: (_) => SendSheet(bench: bench, ground: ground),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SendSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectOnScreen(
      tester,
      find.text('Cancel'),
      because: 'Cancel stays in the footer with suggestions open',
    );
    // The warning stays in the sheet, in the sheet's own words. Its wording on
    // the work surface is a second sentence about the same state and not a
    // substitute: with this sheet open, that one is behind the modal barrier.
    expect(find.textContaining('suggestions are still open'), findsOneWidget);
    // 041-A: open suggestions no longer shut this door. They shut the **send**,
    // and the sentence beside the send button says so. The owner spent his
    // first evening unable to reach the provider list at all, because the only
    // way to it ran through a button that waits for a finished review — and
    // choosing who answers is not a reward for finishing one.
    //
    // It was measured on «Continue», the step from the review page to the
    // doors; rule 60 deleted that page, so it is measured on the door itself.
    expectOnScreen(
      tester,
      find.text(sentences.copyProtected),
      because: 'the doors are not on the glass while suggestions are open',
    );
    final manual = tester.widget<InkWell>(
      find
          .ancestor(of: find.text(sentences.copyProtected), matching: find.byType(InkWell))
          .first,
    );
    expect(
      manual.onTap,
      isNotNull,
      reason: 'the doors are shut while suggestions are open',
    );
    await wheelOver(tester, find.byKey(SendSheet.bodyKey), 600);
    expectOnScreen(
      tester,
      find.text('Cancel'),
      because: 'wheeling the sheet must not move Cancel',
    );
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------------ truthfulness
  //
  // The owner named this category on 27 September: every field a screen shows
  // as a fact must have a real source of truth, because in a privacy product
  // the honesty of the interface is part of the security. `truthfulness.rs`
  // checks it inside the core; this checks the same thing where a person would
  // read it — on the screen, in words.
  testWidgets('what the screens say is what the core says, word for word', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
      ),
    );
    await settle(tester, rounds: 2);

    // The band's sentence, built from the core's three numbers.
    expect(
      report.suggested,
      greaterThan(0),
      reason: 'the fixture leaves something open',
    );
    expect(
      find.text(
        '${report.auto} protected automatically · ${report.suggested} need your word · '
        '${report.normal} normal',
      ),
      findsOneWidget,
    );

    // The Safe column may not say «exactly what the AI will receive» while
    // anything is open. It says the open count instead, and the count is the
    // core's — this is the sentence that was wrong for five milestones.
    expect(
      find.textContaining('This is exactly what the AI will receive'),
      findsNothing,
    );
    expect(
      find.textContaining(
        report.suggested == 1
            ? 'One suggestion is still open'
            : '${report.suggested} suggestions are still open',
      ),
      findsOneWidget,
    );

    // An open suggestion is drawn on the document, not only counted. Before
    // task 033 the core never produced a suggested mark at all, so the badge
    // said «3 need your word» over a document with nothing marked.
    final suggestedMarks = bench.document!.marks
        .where((m) => m.state == MarkState.suggested)
        .length;
    expect(
      suggestedMarks,
      report.suggested,
      reason: 'the marks drawn and the number announced must be the same thing',
    );

    // Answer them, and every one of those statements changes together.
    await tester.runAsync(() async {
      for (final f in bench.suggested) {
        await z.answerFinding(
          session: bench.session,
          finding: f.id,
          answer: FindingAnswer.protect,
        );
      }
      await bench.refresh();
      await bench.rescan();
    });
    await settle(tester, rounds: 2);

    expect(bench.report!.suggested, 0);
    expect(find.textContaining('suggestions are still open'), findsNothing);
    expect(
      find.textContaining('This is exactly what the AI will receive'),
      findsOneWidget,
    );
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> freshVaultForUiTest(String name) async {
  await z.vaultLock();
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-ui-$name-$pid');
  removeWhenItLetsGo(dir);
  await z.setDataDir(dir: dir.path);
  await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
}

/// **A session for the chat to keep a turn in** — rules 65 and 69.
///
/// An exchange is kept in the session's own file now, not beside the payload
/// in memory: `answerFacts` fed the panel rule 65 deleted, and the thread
/// reads `conversation_turns`. So a test that wants a turn to exist has to
/// have had a session born, which is what every exit door does by itself
/// (rule 55, 081) — and what the four guards below were doing implicitly while
/// the answer lived on the bench.
///
/// It needs a vault, because a birth renames this document's tokens from the
/// session's own key. With no vault there is no session, the answer is kept
/// nowhere, and the chat says exactly that (`theChatKeepsNothing`) — an
/// honest screen, and not the one these guards are about.
Future<void> aSessionToKeepItIn(Ground ground, Workbench bench) async {
  await ground.refresh();
  // **And it no longer begins one.** Five lines stood here that asked
  // `aSessionWouldBeBorn` and called `beginSessionItNames` — the glass's own
  // birth dance, written when the law lived in the screen. It is the core's
  // now: a session is born as the document enters the preview (rule 55c) and
  // again for a question that leaves with no document (rule 55-و), so by the
  // time these guards have a document on the bench there is a session, and
  // the dance was a second answer to a question already answered. What is
  // left is the one thing this helper was ever for: read the ground, so the
  // guard measures the state rather than arranging it.
  expect(ground.aSessionWouldBeBorn, isFalse,
      reason: 'the core did not begin a session for the document in the preview');
}

/// Captures clipboard writes. Widget tests have no system clipboard; this is
/// how we prove Copy Restored does not write until the person confirms.
///
/// **[wrote] keeps the order** — 081. The rule is «empty the clipboard, then
/// decide», and an order is a sequence: a count cannot tell «emptied, then
/// copied» from «copied, then emptied», and the second is the one failure that
/// would pass every other instrument here. The same instrument stands in
/// `the_name_at_the_exit_test.dart`; three copies of it in this suite want a
/// `test/support/`, named here as the debt it already was.
class _ClipboardProbe {
  _ClipboardProbe(this.tester);

  final WidgetTester tester;
  String? text = 'SENTINEL';

  /// Every write, in the order it was made.
  final List<String?> wrote = <String?>[];

  int get writes => wrote.length;

  void install() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            text = args['text'] as String?;
            wrote.add(text);
            return null;
          case 'Clipboard.getData':
            if (text == null) return null;
            return <String, dynamic>{'text': text};
          case 'Clipboard.hasStrings':
            return <String, dynamic>{'value': text != null && text!.isNotEmpty};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
  }
}

/// The plain text of one column, read out of the rendered span tree rather than
/// out of the state object — so the test sees what a person would see.
String _plainOf(WidgetTester tester, Type column) {
  final selectable = tester.widget<SelectableText>(
    find.descendant(
      of: find.byType(column),
      matching: find.byType(SelectableText),
    ),
  );
  return selectable.textSpan!.toPlainText();
}

/// A contract long enough to reproduce the 1280×720 review overflow. The golden
/// four-line `_doc` never fills the preview, so it cannot catch the blocker.
String longContract({int sections = 48, int extras = 4}) {
  final b = StringBuffer()
    ..writeln('Kunde: Nordstern Consulting GmbH')
    ..writeln('Ansprechpartner: Herr Thomas Müller')
    ..writeln('Telefon: +49 171 2345678')
    ..writeln('E-Mail: t.mueller@nordstern-consulting.de')
    ..writeln('IBAN: DE89370400440532013000')
    ..writeln('BIC: COBADEFFXXX');
  for (var i = 0; i < extras; i++) {
    b.writeln(
      'Kontakt $i: person$i@nordstern.example, +49 30 ${10000000 + i}, Firma$i GmbH',
    );
  }
  for (var i = 0; i < sections; i++) {
    b.writeln();
    b.writeln(
      'Abschnitt $i. Die Vertragsparteien vereinbaren die in diesem Abschnitt '
      'genannten Leistungen. Die Zusammenarbeit umfasst Beratung, Dokumentation '
      'und laufende Abstimmung zwischen den Häusern. Zahlungen erfolgen auf das '
      'oben genannte Konto. Änderungen bedürfen der Schriftform. Vertrauliche '
      'Angaben bleiben auf diesem Gerät und werden nicht an Dritte weitergegeben.',
    );
  }
  return b.toString();
}

/// The widget's paint box sits inside the test surface. `tester.tap` will hit
/// an off-stage control, so on-screen is the thing the human run actually lost.
void expectOnScreen(
  WidgetTester tester,
  Finder finder, {
  required String because,
}) {
  expect(finder, findsOneWidget, reason: because);
  final rect = tester.getRect(finder);
  final size = tester.binding.renderViews.first.size;
  expect(
    rect.top >= -1 &&
        rect.bottom <= size.height + 1 &&
        rect.left >= -1 &&
        rect.right <= size.width + 1 &&
        rect.height > 8 &&
        rect.width > 8,
    isTrue,
    reason: '$because — rect $rect sits outside $size',
  );
}

/// A wheel over one named region, and nowhere else.
///
/// It was `wheelOverPreview` and it took no argument, because the sheet had
/// one scroller and the payload was in it. Rule 60 moved the payload to the
/// work surface, so the two things this journey measures are now in two
/// different routes — and a helper that guesses which one it is wheeling is
/// how a guard comes to pass for the wrong reason.
Future<void> wheelOver(
  WidgetTester tester,
  Finder region,
  double dy, {
  Offset? at,
}) async {
  expect(region, findsOneWidget, reason: 'nothing to wheel: the named region is not on the glass');
  // **A tall region's own centre is not on the window.** The payload is some
  // thousands of pixels of text inside a scroller, so `getCenter` names a
  // point far below the glass, a scroll event sent there lands on nothing, and
  // every assertion after it measures nothing. Where a caller knows the point
  // it means, it says so.
  await tester.sendEventToBinding(
    PointerScrollEvent(
      position: at ?? tester.getCenter(region),
      scrollDelta: Offset(0, dy),
    ),
  );
  await tester.pump();
}

/// Open a document, wheel the payload in the preview side, keep the door in
/// its footer, open the sheet and take the first exit. This is the journey that
/// failed at 1280×720 — and since rule 60 its two halves are in two routes: the
/// outgoing text on the work surface, the acts in the sheet.
Future<void> reviewJourney(
  WidgetTester tester, {
  required Size size,
  required String text,
  bool requireManyProtections = false,
  bool requireLongPayload = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    // **This journey is about the sheet, not about sessions — said out loud.**
    // It never made a vault, but the core's vault state is global and an
    // earlier test in this file leaves one unlocked, so after 064 the sheet
    // asked this journey for a session name and the nameless press copied
    // nothing. One line makes the journey's own premise explicit and the file
    // order-independent. The state it stops covering — the question standing,
    // at 1280×720 — is measured in `the_name_at_the_exit_test`, which presses
    // the doors with it up.
    await z.vaultLock();
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    await z.importText(session: session, text: text);
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await bench.rescan();
    for (final f in bench.suggested) {
      await z.answerFinding(
        session: session,
        finding: f.id,
        answer: FindingAnswer.protect,
      );
    }
    await bench.refresh();
  });
  addTearDown(bench.dispose);

  expect(bench.payload, isNotNull);
  expect(bench.payload!.openSuggestions, 0);
  expect(
    bench.payload!.text.length,
    greaterThan(4000),
    reason: 'a short payload will not reproduce the review overflow',
  );
  if (requireLongPayload) {
    expect(
      bench.payload!.text.length,
      greaterThan(12000),
      reason: 'the long-SafePayload case must be longer than the golden letter',
    );
  }
  if (requireManyProtections) {
    expect(
      bench.payload!.protectedCount,
      greaterThan(10),
      reason:
          'the many-findings case must mint more tokens than the golden letter',
    );
  }

  final clip = _ClipboardProbe(tester)..install();

  await tester.pumpWidget(
    MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  // **The journey's other premise, said out loud: the preview side is open.**
  //
  // `safeColumnOpen` is remembered in `zcfg`, the tests share one data
  // directory, and another file in this suite closes that side by a press and
  // leaves it closed. A journey that assumed it would measure nothing here and
  // fail with «the preview side is not drawing the payload» — which names the
  // symptom and hides the cause. So the state is read and, if it is shut, the
  // rail opens it: a press, which is the only thing the owner's rule of 046/K
  // allows to move it.
  if (ground.config?.safeColumnOpen == false) {
    await tester.tap(find.byKey(const ValueKey<String>('workspace-safe-rail')));
    await tester.pumpAndSettle();
  }
  expect(
    find.byKey(const ValueKey<String>('workspace-safe-pane')),
    findsOneWidget,
    reason: 'the preview side is shut, so this journey has no payload to wheel',
  );

  // **1 · the payload and the acts, where rule 60 left them.**
  //
  // The law this journey was written for has not moved: the outgoing text may
  // not share a scroller with the acts, and nothing a person needs may fall off
  // a 1280×720 window. What moved is the text — it is read in the preview side
  // of the work surface now, so the side is where the law is measured. Its body
  // scrolls; the door in its footer does not travel with it.
  expectOnScreen(
    tester,
    find.text(sentences.chooseWhoAnswers),
    because: 'the door into the three exits must be reachable at this size',
  );
  final payload = find.descendant(
    of: find.byKey(const ValueKey<String>('workspace-safe-pane')),
    matching: find.byType(SafeText),
  );
  expect(payload, findsOneWidget, reason: 'the preview side is not drawing the payload');
  final textBefore = tester.getRect(payload);
  final doorBefore = tester.getRect(find.text(sentences.chooseWhoAnswers));
  // 120 pixels below the side's own top: past its header, inside the scroller,
  // and on the window whatever the payload's height is.
  final side = tester.getRect(find.byKey(const ValueKey<String>('workspace-safe-pane')));
  await wheelOver(tester, payload, 800, at: Offset(side.center.dx, side.top + 120));
  expect(
    tester.getRect(payload).top,
    lessThan(textBefore.top),
    reason:
        'the wheel over the payload must move the payload, not vanish into SelectableText',
  );
  expect(
    tester.getRect(find.text(sentences.chooseWhoAnswers)),
    doorBefore,
    reason: 'wheeling the payload moved the door it is read beside',
  );
  expectOnScreen(
    tester,
    find.text(sentences.chooseWhoAnswers),
    because: 'the door remains clickable after the wheel',
  );
  expect(tester.takeException(), isNull);

  // **2 · the sheet, which has one page.**
  await tester.tap(find.text(sentences.chooseWhoAnswers));
  await tester.pumpAndSettle();
  expect(find.byType(SendSheet), findsOneWidget);
  expect(find.text(sentences.whoAnswers), findsOneWidget);
  expect(
    find.text('Continue'),
    findsNothing,
    reason: 'the sheet still pages, so rule 60 left a page behind',
  );
  expect(tester.takeException(), isNull);

  expectOnScreen(
    tester,
    find.text('Cancel'),
    because: 'Cancel is the fixed footer, not in the body',
  );
  // **«Paste AI answer» is not one of these any more** — rule 65, 17 October.
  // The way back from a manual door is «Add an answer» at the foot of the
  // chat, where the thread it joins is: a second paste door inside the sheet
  // would be a way back into a conversation the sheet cannot see. The
  // sentence under «Manual AI» says where it went, and `send_sheet.dart`
  // names the rule where the button stood.
  for (final primary in const [
    'Copy Protected',
    'Manual AI',
    'Direct API',
  ]) {
    expectOnScreen(
      tester,
      find.text(primary),
      because:
          '$primary must be hittable without stretching the window — and the '
          'choice now stands above the doors, which is the height rule 60 added',
    );
  }

  final footerBefore = tester.getRect(find.byKey(SendSheet.footerKey));
  final body = tester.widget<SingleChildScrollView>(
    find.byKey(SendSheet.bodyKey),
  );
  final position = body.controller!.position;
  expect(
    position.maxScrollExtent,
    greaterThan(40),
    reason: 'the body must actually overflow, or the wheel assertion is empty',
  );
  final offsetBefore = position.pixels;

  await wheelOver(tester, find.byKey(SendSheet.bodyKey), 800);

  expect(
    position.pixels,
    greaterThan(offsetBefore),
    reason: 'the wheel over the doors moved nothing',
  );
  expect(
    tester.getRect(find.byKey(SendSheet.footerKey)),
    footerBefore,
    reason: 'wheeling the body must not move the footer',
  );
  expectOnScreen(
    tester,
    find.text('Cancel'),
    because: 'Cancel remains clickable after the wheel',
  );
  expect(tester.takeException(), isNull);

  // **3 · the first door, taken.**
  //
  // Brought back into view on purpose: step 2 wheeled this page 800 pixels to
  // measure that the footer stays put, so the door is where that wheel left it.
  // A `tap` on an off-stage control hits nothing and says nothing.
  await tester.ensureVisible(find.text(sentences.copyProtected));
  await tester.pumpAndSettle();
  await tester.tap(find.text(sentences.copyProtected));
  await settle(tester, rounds: 1);
  expect(find.text(sentences.copied), findsOneWidget);
  expect(
    clip.text,
    bench.payload!.text,
    reason: 'Copy Protected copies the SafePayload, exactly',
  );
  // **4 · the way back is not in the sheet any more** — rule 65.
  //
  // This journey used to press «Paste AI answer» here and measure that the box
  // it opened did not kick the footer off a 1280×720 window. The door is gone
  // from the sheet and the box opens at the foot of the chat now, so the claim
  // is not weakened — it is measured where the box is, under «Add an answer»
  // in `the_chat_is_the_third_part_test`'s guard at the window the app opens
  // at. Pressing a label that is not there would have failed; asserting its
  // absence here would be a second copy of G41's own roster.
  expect(tester.takeException(), isNull);
}

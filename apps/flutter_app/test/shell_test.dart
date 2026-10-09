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
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/protect_dialog.dart';
import 'package:zprivacy/widgets/review.dart';
import 'package:zprivacy/screens/answer.dart';
import 'package:zprivacy/widgets/connect_form.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/widgets/tokens.dart';
import 'package:zprivacy/widgets/vault_forms.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

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
        'no $_libPath — run `flutter build linux --debug` first',
      );
    }
    // The runner is started with LD_LIBRARY_PATH pointing at the built bundle.
    await RustLib.init();
  });

  testWidgets('Home draws the ground as the core reports it, not as Dart guesses', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          ground: ground,
          version: 'z_core 0.1.0',
          onImport: () {},
          onType: (_) {},
          onAsk: (_) async {},
          onVault: () {},
          onSettings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Z Privacy'), findsOneWidget);
    // 041-G — the home is the composer. «Import a document» and «New private
    // session» were two buttons and one of them opened a sheet that asked a
    // language first; the page is a box to write in now, with a «+» for a file,
    // and the vault is still a press away.
    // The box, by its key: 064/D put a second field on this page — the session
    // question, while a person has no session — and the claim here is about
    // the box a person writes in, not about how many fields the page has.
    expect(find.byKey(HomeScreen.composer), findsOneWidget,
        reason: 'the home is not a box to write in');
    expect(find.byTooltip('Add a document — PDF, Word or text'), findsOneWidget);
    expect(find.text('Open Z Vault'), findsOneWidget);
    // No invented history: Home says what is kept, once, and says it in the
    // form that is true right now. **064/E changed the sentence, not the
    // claim:** a session keeps its conversation sealed in the vault since the
    // core began writing turns, so «conversations are not saved» is the honest
    // line only while no session is open — which is this journey's own state.
    expect(find.text('LOCAL CONVERSATIONS'), findsNothing);
    expect(
      find.textContaining(
        'No session is open — nothing of this conversation is kept',
      ),
      findsOneWidget,
    );

    // The pack's label is the pack's own, never a string typed into a screen —
    // and it is the pack **in use**, read from the settings, not the first one
    // installed. It also says what the app will do with it, which depends on a
    // setting rather than on a sentence someone wrote once.
    expect(packs, isNotEmpty, reason: 'this build carries a pack');
    final inUse = packs.firstWhere(
      (p) => p.id == ground.config?.packId,
      orElse: () => packs.first,
    );
    final scans = ground.config?.scanOnImport ?? true;
    expect(
      find.text(
        '${inUse.label} · ${scans ? "scan on import" : "scan when you ask"}',
      ),
      findsOneWidget,
    );

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
      await bench.rescan();
    });

    expect(
      bench.snap,
      isNotNull,
      reason: 'the workspace is drawn from a snapshot',
    );
    expect(
      (bench.snap!.autoProtected + bench.snap!.openSuggestions),
      greaterThan(0),
      reason: 'the scan found something to show',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scanned on import'), findsOneWidget);
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
      find.text('Never sent to AI · Send cannot read this side'),
      findsOneWidget,
    );

    // Typed text has no file name, and the bar says so rather than inventing one.
    expect(find.text('Typed text'), findsOneWidget);
    expect(find.text('1 page'), findsOneWidget);

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
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(bench.scanOrigin, ScanOrigin.rescan);
    expect(find.text('Last scan: manual rescan'), findsOneWidget);
    expect(find.text('Scanned on import'), findsNothing);
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
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
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
          home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // DISABLED — nothing selected, and the hint says what to do about it.
      expect(protectStateOf(bench.selected), ProtectState.disabled);
      expect(find.text('Select text, then Protect'), findsOneWidget);
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
      expect(find.text('Select text, then Protect'), findsNothing);

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
      expect(
        find.textContaining('cuts into something already protected'),
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
    'Review shows three groups, says where each sits, and Skip decides nothing',
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
          home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
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

      // The two groups are named apart, because the difference is the whole point.
      expect(find.text('WAITING FOR YOUR WORD'), findsOneWidget);
      expect(find.text('PROTECTED AUTOMATICALLY'), findsOneWidget);

      // Every finding says where it sits, and the place is the core's own.
      final placed = bench.findings.where((f) => f.place != null).toList();
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
        placed.map((f) => f.place!.paragraph).toSet().length,
        greaterThan(1),
      );

      // SKIP decides nothing: still open, still counted, Send still shut.
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
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final token = bench.tokens.firstWhere((t) => t.kind == Kind.person).token;
    await tester.runAsync(() async => bench.reveal(token));
    await tester.pumpAndSettle();

    Finder inPanel(Finder what) =>
        find.descendant(of: find.byType(TokensPanel), matching: what);
    expect(inPanel(find.text('Thomas Müller')), findsOneWidget);

    // The conversation is closed underneath the screen. Nothing is told to
    // hide; the next question simply cannot be answered.
    await tester.runAsync(() => z.closeSession(session: session));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      if (inPanel(find.text('Thomas Müller')).evaluate().isEmpty) break;
    }

    expect(
      inPanel(find.text('Thomas Müller')),
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
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final token = bench.tokens.firstWhere((t) => t.kind == Kind.person).token;
    await tester.runAsync(() async => bench.reveal(token));
    await tester.pumpAndSettle();

    Finder inPanel(Finder what) =>
        find.descendant(of: find.byType(TokensPanel), matching: what);
    expect(
      inPanel(find.text('Thomas Müller')),
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
      if (inPanel(find.text('Thomas Müller')).evaluate().isEmpty) break;
    }

    expect(
      inPanel(find.text('Thomas Müller')),
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
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
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
    expect(inPanel(find.text('Thomas Müller')), findsNothing);

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
            onHome: () {},
            onVault: () {},
            // Given a panel to open because this test asks the sheet for its
            // way to the settings, and a surface with nowhere to send the
            // press draws no door rather than a dead one. The other fourteen
            // mounts in this file are left alone: fourteen doors that open
            // nothing would be fourteen lies the compiler was enforcing.
            onSettings: () {},
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

      // The sheet offers the door that needs no account at all, first. Continue
      // is the step into that door — the payload review does not share a scroller
      // with the actions.
      await tester.tap(find.text('Review what will leave'));
      await tester.pumpAndSettle();
      expect(find.byType(SendSheet), findsOneWidget);

      // What the sheet shows is the payload, not a copy assembled for display.
      final shown = tester
          .widget<SelectableText>(
            find
                .descendant(
                  of: find.byType(SendSheet),
                  matching: find.byType(SelectableText),
                )
                .first,
          )
          .textSpan!
          .toPlainText();
      expect(shown, bench.payload!.text);

      await enterAiMode(tester);
      expect(find.text('Manual AI'), findsOneWidget);
      expect(find.text('Copy Protected'), findsOneWidget);
      expect(find.textContaining('no account, no key'), findsOneWidget);

      // Copy Protected is the first door's act — take it while it is on screen,
      // before the local fold is scrolled into view.
      final clip = _ClipboardProbe(tester)..install();
      await tester.tap(find.text('Copy Protected'));
      await settle(tester, rounds: 1);
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
      expect(find.text('Direct API'), findsOneWidget);
      expect(find.text('Local AI'), findsOneWidget);

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
        find.text('Open Settings'),
        findsWidgets,
        reason: 'no form and no way to reach the place a key is given',
      );

      // Bring an answer back by hand — the token store does not care how it
      // travelled — and the real values come home.
      await tester.runAsync(() async {
        await bench.pasteAnswer('Danke. Zusammenfassung:\n$safe');
      });
      await settle(tester);
      expect(bench.answers, hasLength(1));

      late final List<Segment> segments;
      late final String raw;
      await tester.runAsync(() async {
        segments = (await bench.answerFacts(bench.answers.first)).restored;
        raw = (await bench.answerFacts(bench.answers.first)).asWritten;
      });
      final restored = segments.map((s) => s.text).join();
      expect(
        raw,
        isNot(contains('Thomas Müller')),
        reason: 'the answer as it arrived holds no value',
      );
      expect(
        restored,
        contains('Thomas Müller'),
        reason: 'and restoring puts it back, here',
      );
      expect(
        segments.any((s) => s.piece == Piece.restored),
        isTrue,
        reason: 'the core marks what it put back',
      );

      bench.dispose();
    },
  );

  testWidgets(
    'the answer is shown twice: restored, and as the model wrote it',
    (tester) async {
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
          await z.answerFinding(
            session: session,
            finding: f.id,
            answer: FindingAnswer.protect,
          );
        }
        await bench.refresh();
        bench.rememberCopiedPayload();
        await bench.pasteAnswer('Verstanden:\n${bench.payload!.text}');
      });

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
        ),
      );
      await settle(tester);

      expect(find.byType(AnswerPanel), findsOneWidget);
      expect(find.text('Restored'), findsOneWidget);
      expect(find.text('As the model wrote it'), findsOneWidget);

      Finder inPanel(Finder f) =>
          find.descendant(of: find.byType(AnswerPanel), matching: f);

      // Restored is what opens, and the real value is in it — locally.
      expect(inPanel(find.textContaining('Thomas Müller')), findsOneWidget);

      // The other view is the same answer with the tokens still in it.
      await tester.tap(find.text('As the model wrote it'));
      await settle(tester);
      expect(inPanel(find.textContaining('Thomas Müller')), findsNothing);
      expect(inPanel(find.textContaining('__Z_')), findsOneWidget);

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
      bench.rememberCopiedPayload();
      await bench.pasteAnswer('Verstanden:\n${bench.payload!.text}');
      final segments = (await bench.answerFacts(bench.answers.first)).restored;
      restored = segments.map((s) => s.text).join();
      raw = (await bench.answerFacts(bench.answers.first)).asWritten;
    });

    final clip = _ClipboardProbe(tester)..install();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await settle(tester);

    Finder inPanel(Finder f) =>
        find.descendant(of: find.byType(AnswerPanel), matching: f);

    expect(inPanel(find.text('Copy Restored')), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(restored, contains('Thomas Müller'));

    await tester.tap(inPanel(find.text('Copy Restored')));
    await tester.pumpAndSettle();

    expect(find.text('Copy restored text?'), findsOneWidget);
    expect(find.textContaining('real protected values'), findsOneWidget);
    expect(find.textContaining('system clipboard'), findsOneWidget);
    expect(
      find.textContaining('Other applications may be able to read'),
      findsOneWidget,
    );
    expect(
      clip.writes,
      0,
      reason: 'the clipboard is not written before confirmation',
    );
    expect(clip.text, 'SENTINEL');

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(clip.writes, 0);
    expect(clip.text, 'SENTINEL');
    expect(
      find.text('Restored text copied to the system clipboard.'),
      findsNothing,
    );

    await tester.tap(inPanel(find.text('Copy Restored')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Copy Restored'),
      ),
    );
    await tester.pumpAndSettle();

    expect(clip.writes, 1);
    expect(clip.text, restored);
    expect(
      find.text('Restored text copied to the system clipboard.'),
      findsOneWidget,
    );
    expect(find.textContaining('Copied securely'), findsNothing);

    // The warning is not a one-time tutorial: the next press asks again.
    await tester.tap(inPanel(find.text('Copy Restored')));
    await tester.pumpAndSettle();
    expect(find.text('Copy restored text?'), findsOneWidget);
    expect(clip.writes, 1);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(clip.writes, 1);
    expect(clip.text, restored);

    await tester.tap(find.text('As the model wrote it'));
    await settle(tester);
    expect(inPanel(find.text('Copy Protected')), findsOneWidget);
    expect(inPanel(find.text('Copy Restored')), findsNothing);
    expect(find.text('Copy'), findsNothing);

    await tester.tap(inPanel(find.text('Copy Protected')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(clip.text, raw);
    expect(clip.text, isNot(contains('Thomas Müller')));
    expect(clip.text, contains('__Z_'));

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

      await tester.runAsync(() async {
        await freshVaultForUiTest('profiles');
        await ground.refresh();
        session = await z.openSession(packId: 'de');
        await z.importText(session: session, text: doc);
        bench = Workbench(session: session, profileId: null, packId: 'de');
        await bench.rescan();
      });
      addTearDown(bench.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Everywhere').first);
      await settle(tester);
      expect(find.byType(ProfileSwitcher), findsOneWidget);

      await tester.tap(find.text('Create profile'));
      await settle(tester);
      expect(find.byType(ProfileForm), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(ProfileForm),
          matching: find.byType(TextField),
        ),
        'Client A',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(ProfileForm),
          matching: find.text('Create'),
        ),
      );
      await settle(tester);
      expect(find.text('Client A'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      await tester.tap(find.text('Create profile'));
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
          matching: find.text('Create'),
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
      expect(find.text('Nordstern'), findsOneWidget);
      expect(find.text('Client A'), findsNothing);

      // Client B is active after it was created. Switch back to the renamed
      // profile from the UI; the top bar must show the human name, not the ID.
      await tester.tap(find.text('Switch').at(1));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.text('Nordstern'), findsOneWidget);
      expect(bench.profileId, isNotNull);

      // And switching can go the other way from the same top-bar entry.
      await tester.tap(find.text('Nordstern').first);
      await settle(tester);
      await tester.tap(find.text('Switch').last);
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.text('Client B'), findsOneWidget);

      // Leave the open conversation in Nordstern before teaching a profile-scoped
      // value, then prove another profile does not inherit it.
      await tester.tap(find.text('Client B').first);
      await settle(tester);
      await tester.tap(find.text('Switch').last);
      await settle(tester);
      await tester.tap(find.text('Done'));
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
        expect(
          bTokens.where((t) => t.kind == Kind.custom),
          isEmpty,
          reason: 'Client B must not inherit values taught to Client A',
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
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Review what will leave'));
    await settle(tester);
    expect(find.byType(SendSheet), findsOneWidget);
    await enterAiMode(tester);
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
    for (final secret in [
      'Thomas Müller',
      'Nordstern Consulting GmbH',
      'DE89370400440532013000',
    ]) {
      expect(bodyReceived, isNot(contains(secret)));
    }
    expect(authReceived, 'Bearer sk-test-not-a-real-credential');

    // The answer panel opened on its own with the restored view.
    await settle(tester);
    expect(find.byType(AnswerPanel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AnswerPanel),
        matching: find.textContaining('Thomas Müller'),
      ),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
    });
    bench.dispose();
  });

  // ------------------------------------------------------ 1280×720 review flow
  //
  // The human run could not reach Copy Protected / Paste AI answer / Send from
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
    expectOnScreen(
      tester,
      find.text('Continue'),
      because: 'Continue stays in the footer with suggestions open',
    );
    expect(find.textContaining('suggestions are still open'), findsOneWidget);
    // 041-A: open suggestions no longer shut this door. They shut the **send**,
    // and the sentence beside the send button says so. The owner spent his
    // first evening unable to reach the provider list at all, because the only
    // way to it ran through a button that waits for a finished review — and
    // choosing who answers is not a reward for finishing one.
    final continueBtn = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Continue'), matching: find.byType(InkWell))
          .first,
    );
    expect(
      continueBtn.onTap,
      isNotNull,
      reason: 'the doors are shut while suggestions are open',
    );
    await wheelOverPreview(tester, 600);
    expectOnScreen(
      tester,
      find.text('Cancel'),
      because: 'wheeling the preview must not move Cancel',
    );
    expectOnScreen(
      tester,
      find.text('Continue'),
      because: 'wheeling the preview must not move Continue',
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
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
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
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  await z.setDataDir(dir: dir.path);
  await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
}

/// Captures clipboard writes. Widget tests have no system clipboard; this is
/// how we prove Copy Restored does not write until the person confirms.
class _ClipboardProbe {
  _ClipboardProbe(this.tester);

  final WidgetTester tester;
  String? text = 'SENTINEL';
  int writes = 0;

  void install() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            writes += 1;
            final args = Map<String, dynamic>.from(call.arguments as Map);
            text = args['text'] as String?;
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

Future<void> enterAiMode(WidgetTester tester) async {
  expectOnScreen(
    tester,
    find.text('Continue'),
    because: 'Continue is the footer step into AI mode',
  );
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('Manual AI'), findsOneWidget);
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

Future<void> wheelOverPreview(WidgetTester tester, double dy) async {
  final preview = find.byKey(SendSheet.previewKey);
  expect(
    preview,
    findsOneWidget,
    reason: 'the payload preview is the only scroller on review',
  );
  await tester.sendEventToBinding(
    PointerScrollEvent(
      position: tester.getCenter(preview),
      scrollDelta: Offset(0, dy),
    ),
  );
  await tester.pump();
}

/// Open a document, reach Review before send, wheel the preview, keep the
/// footer, click through to AI mode. This is the journey that failed at 1280×720.
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
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  expectOnScreen(
    tester,
    find.text('Review what will leave'),
    because: 'the workspace review door itself must be reachable at this size',
  );
  await tester.tap(find.text('Review what will leave'));
  await tester.pumpAndSettle();
  expect(find.byType(SendSheet), findsOneWidget);
  expect(find.text('Review before send'), findsOneWidget);
  expect(tester.takeException(), isNull);

  expectOnScreen(
    tester,
    find.text('Cancel'),
    because: 'Cancel is the fixed footer, not in the preview',
  );
  expectOnScreen(
    tester,
    find.text('Continue'),
    because: 'Continue is the fixed footer, not in the preview',
  );
  expect(
    find.text('Copy Protected'),
    findsNothing,
    reason:
        'the AI doors live on the next page so they cannot steal the preview wheel',
  );

  final footerBefore = tester.getRect(find.byKey(SendSheet.footerKey));
  final continueBefore = tester.getRect(find.text('Continue'));
  final preview = tester.widget<SingleChildScrollView>(
    find.byKey(SendSheet.previewKey),
  );
  final position = preview.controller!.position;
  expect(
    position.maxScrollExtent,
    greaterThan(40),
    reason:
        'the preview must actually overflow, or the wheel assertion is empty',
  );
  final offsetBefore = position.pixels;

  await wheelOverPreview(tester, 800);

  expect(
    position.pixels,
    greaterThan(offsetBefore),
    reason:
        'the wheel over the payload must move the preview, not vanish into SelectableText',
  );
  expect(
    tester.getRect(find.byKey(SendSheet.footerKey)),
    footerBefore,
    reason: 'wheeling the preview must not move the footer',
  );
  expect(
    tester.getRect(find.text('Continue')),
    continueBefore,
    reason: 'Continue stays put while the payload moves',
  );
  expectOnScreen(
    tester,
    find.text('Cancel'),
    because: 'Cancel remains clickable after the wheel',
  );
  expectOnScreen(
    tester,
    find.text('Continue'),
    because: 'Continue remains clickable after the wheel',
  );
  expect(tester.takeException(), isNull);

  await enterAiMode(tester);
  expect(tester.takeException(), isNull);
  expectOnScreen(
    tester,
    find.text('Cancel'),
    because: 'Cancel stays in the footer on the AI page',
  );
  expectOnScreen(
    tester,
    find.text('Back'),
    because: 'Back is the footer return to the preview',
  );
  expectOnScreen(
    tester,
    find.text('Copy Protected'),
    because:
        'Copy Protected is a primary action and must be hittable without stretching the window',
  );
  expectOnScreen(
    tester,
    find.text('Paste AI answer'),
    because:
        'Paste AI answer is a primary action and must be hittable without stretching the window',
  );
  expectOnScreen(
    tester,
    find.text('Direct API'),
    because:
        'Send from here is a primary action and must be hittable without stretching the window',
  );

  await tester.tap(find.text('Copy Protected'));
  await settle(tester, rounds: 1);
  expect(find.text('Copied'), findsOneWidget);
  expect(
    clip.text,
    bench.payload!.text,
    reason: 'Copy Protected copies the SafePayload, exactly',
  );
  await tester.tap(find.text('Paste AI answer'));
  await tester.pump();
  expect(find.textContaining('Paste the model'), findsOneWidget);
  expectOnScreen(
    tester,
    find.text('Back'),
    because: 'opening the paste box must not kick Back off the screen',
  );
  expect(tester.takeException(), isNull);

  await tester.tap(find.text('Back'));
  await tester.pumpAndSettle();
  expect(find.byKey(SendSheet.previewKey), findsOneWidget);
  expectOnScreen(
    tester,
    find.text('Continue'),
    because: 'Back returns to the review page with Continue on screen',
  );
  expect(tester.takeException(), isNull);
}

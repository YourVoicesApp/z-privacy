// 041-L — the two columns show the same pages, and move together.
//
// The owner, 6 October, on the published build: «ترتيب الصفحات غير متماثل؛ أعمل
// على الشاشة الأولى ولا أجد عملي في الشاشة الثانية؛ شاشة فيها رقم الصفحات وشاشة
// لا.»
//
// What leaves the device is held to account in `z_core/tests/page_edges.rs`,
// measured against the build before this one. What is held to account here is
// the other half: that the two columns say the same thing about the same page,
// and that the arithmetic which keeps them in step can be read on its own.
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
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/widgets/document_text.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// Three pages, invented. The form feed is what the reader leaves between one
/// page and the next, and the company on page one is long enough that its token
/// moves every offset after it.
const _three = 'Seite eins\n\nKunde: Nordstern Consulting GmbH\n'
    '\u{c}'
    'Seite zwei\n\nRechnung an Thomas Müller\n'
    '\u{c}'
    'Seite drei\n\nMit freundlichen Grüßen\n';

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// Tall enough to scroll in a 1000-pixel window, and twelve pages deep so a
/// page can be arrived at rather than guessed. Invented, like every fixture.
String _tall() {
  final b = StringBuffer();
  for (var page = 1; page <= 12; page++) {
    b.write('Seite $page\n\n');
    b.write('Kunde: Nordstern Consulting GmbH\n');
    b.write('Ansprechpartner: Thomas Müller\n');
    b.write('Betrag und Bemerkungen zu dieser Seite.\n\n');
    if (page < 12) b.write('\u{c}');
  }
  return b.toString();
}

/// A column's own scroll controller, found by the column rather than by its
/// position among every scrollable on the screen.
///
/// Measured: the Workspace has four scrollables, because each `SelectableText`
/// brings one of its own with an extent of zero. Taking «the first two» would
/// have read the Original column and the inside of its own text.
ScrollController _railOf(WidgetTester tester, Key pane) {
  final view = tester.widget<SingleChildScrollView>(
    find.descendant(of: find.byKey(pane), matching: find.byType(SingleChildScrollView)).first,
  );
  return view.controller!;
}

/// The painter a column handed its edges to.
PageEdgePainter _painterAt(WidgetTester tester, Key key) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)),
  );
  return paint.painter! as PageEdgePainter;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------ the arithmetic, on its own

  group('the step is arithmetic before it is a screen', () {
    test('with no edges it is the ratio of the two extents', () {
      expect(
        inStepOffset(from: 50, mine: const [], theirs: const [], myExtent: 100, theirExtent: 200),
        200 * 0.5,
      );
      // And a column with nothing to scroll is simply at the top.
      expect(
        inStepOffset(from: 50, mine: const [], theirs: const [], myExtent: 100, theirExtent: 0),
        0,
      );
    });

    test('above the first page it measures against that first page', () {
      // Half way to my first break is half way to theirs, wherever theirs is.
      expect(
        inStepOffset(from: 50, mine: const [100], theirs: const [80], myExtent: 400, theirExtent: 400),
        40,
      );
    });

    test('on a page it carries how far into that page the eye has gone', () {
      // Page two begins at 100 here and at 80 there; the pages are 100 and 50
      // tall, because a token is not the length of the name it replaced. A
      // quarter of the way down my page is a quarter of the way down theirs.
      final at = inStepOffset(
        from: 125,
        mine: const [100, 200],
        theirs: const [80, 130],
        myExtent: 400,
        theirExtent: 400,
      );
      expect(at, 80 + 25 * (50 / 100));
    });

    test('a page edge lands exactly on its partner', () {
      expect(
        inStepOffset(from: 200, mine: const [100, 200], theirs: const [80, 130], myExtent: 400, theirExtent: 400),
        130,
        reason: 'the one place the two columns can be certain about is a page edge',
      );
    });

    test('it never asks a column to go past its end', () {
      expect(
        inStepOffset(from: 10_000, mine: const [100], theirs: const [80], myExtent: 400, theirExtent: 300),
        300,
      );
    });

    test('lists of different lengths fall back rather than pair the wrong pages', () {
      expect(
        inStepOffset(from: 50, mine: const [100, 200], theirs: const [80], myExtent: 100, theirExtent: 200),
        100,
        reason: 'two edges against one must not be paired by position',
      );
    });
  });

  group('pages are paired by their number, never by their row', () {
    test('a page missing from one column drops out of both lists', () {
      // The payload lost page two's break: a protection spanned it. Page three
      // must still be paired with page three.
      final paired = alignedEdges(
        myEdges: const [PageEdge(at: 10, page: 2), PageEdge(at: 20, page: 3)],
        myYs: const [100, 200],
        theirEdges: const [PageEdge(at: 18, page: 3)],
        theirYs: const [150],
      );
      expect(paired.mine, const [200.0]);
      expect(paired.theirs, const [150.0]);
    });

    test('a position the layout could not give drops out with its partner', () {
      final paired = alignedEdges(
        myEdges: const [PageEdge(at: 10, page: 2), PageEdge(at: 20, page: 3)],
        myYs: const [double.nan, 200],
        theirEdges: const [PageEdge(at: 8, page: 2), PageEdge(at: 18, page: 3)],
        theirYs: const [80, 150],
      );
      expect(paired.mine, const [200.0]);
      expect(paired.theirs, const [150.0]);
    });
  });

  test('a document finds its own edges, and page one is not one of them', () {
    final edges = edgesOfDocument(_three);
    expect(edges.length, 2);
    expect(edges.map((e) => e.page), const [2, 3]);
    expect(_three.codeUnitAt(edges.first.at), 0x0c);
  });

  // ------------------------------------------------ the two columns

  testWidgets('a three-page document draws two edges in both columns, with the same numbers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      final here = Directory('${Directory.systemTemp.path}/zprivacy-step-$pid');
      if (here.existsSync()) here.deleteSync(recursive: true);
      addTearDown(() {
        if (here.existsSync()) here.deleteSync(recursive: true);
      });
      await z.setDataDir(dir: here.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _three);
      await bench.rescan();
      // A suggestion is not a protection, and a payload with none would have no
      // token in it to move the offsets apart.
      for (final f in bench.findings.where((f) => f.state == MarkState.suggested)) {
        await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
      }
      await bench.refresh();
    });
    addTearDown(bench.dispose);

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);

    // Control first: three pages, and something was protected.
    expect(bench.document!.pages, 3);
    expect(bench.tokens, isNotEmpty, reason: 'nothing was protected, so no offset moved');

    // **Both** columns carry the layer. One of them could not before: the
    // payload has no form feed to find.
    expect(find.byKey(OriginalText.pageEdges), findsOneWidget);
    expect(find.byKey(SafeText.pageEdges), findsOneWidget,
        reason: 'the Safe column has no page edges — the defect this task is about');

    final original = _painterAt(tester, OriginalText.pageEdges);
    final safe = _painterAt(tester, SafeText.pageEdges);

    expect(original.edges.length, 2);
    expect(
      safe.edges.map((e) => e.page).toList(),
      original.edges.map((e) => e.page).toList(),
      reason: 'the two columns number the same pages differently',
    );

    // **And each column's offsets are its own.** This is the whole task: the
    // two texts are not the same length, because a token is not the length of
    // the name it replaced, so an edge is in a different place in each.
    final doc = bench.document!.text;
    final payload = bench.payload!.text;

    expect(
      safe.edges.map((e) => e.at).toList(),
      isNot(original.edges.map((e) => e.at).toList()),
      reason: 'the Safe column was handed the document\'s offsets',
    );

    for (var i = 0; i < 2; i++) {
      final page = original.edges[i].page;
      // Each edge points at a break **in the text its column draws**.
      expect(doc.codeUnitAt(original.edges[i].at), 0x0c,
          reason: 'page $page is not at a form feed in the document');
      expect(payload.codeUnitAt(safe.edges[i].at), 0x0a,
          reason: 'page $page is not at a line break in the payload');
      // And the defect, said as a test: the document's own offset does not
      // point at that break in the payload, so a column drawing with it would
      // rule the page in the wrong place.
      expect(
        safe.edges[i].at == original.edges[i].at,
        isFalse,
        reason: 'page $page happens to coincide, so this case proves nothing — '
            'change the fixture so a token moves it',
      );
    }

    expect(payload.contains('\u{c}'), isFalse,
        reason: 'a control character travelled to a model');
  });

  testWidgets('scrolling one column moves the other, and Apart stops it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      final here = Directory('${Directory.systemTemp.path}/zprivacy-scroll-$pid');
      if (here.existsSync()) here.deleteSync(recursive: true);
      addTearDown(() {
        if (here.existsSync()) here.deleteSync(recursive: true);
      });
      await z.setDataDir(dir: here.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _tall());
      await bench.rescan();
      await bench.refresh();
    });
    addTearDown(bench.dispose);

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);

    expect(bench.document!.pages, 12);
    final left = _railOf(tester, _ColumnsStateKeys.originalPane);
    final right = _railOf(tester, _ColumnsStateKeys.safePane);
    // Control: a column with nothing to scroll could not fail this test.
    expect(left.position.maxScrollExtent, greaterThan(0));
    expect(right.position.maxScrollExtent, greaterThan(0));
    expect(right.offset, 0);

    // In step: moving the Original takes the Safe column with it.
    left.jumpTo(left.position.maxScrollExtent / 3);
    await settle(tester, rounds: 2);
    expect(right.offset, greaterThan(0),
        reason: 'the Safe column stayed where it was — the owner\'s complaint exactly');

    // And it is **where the same page is**, not merely somewhere.
    final original = _painterAt(tester, OriginalText.pageEdges);
    final safe = _painterAt(tester, SafeText.pageEdges);
    final paired = alignedEdges(
      myEdges: original.edges,
      myYs: pageEdgeYs(
        text: bench.document!.text,
        style: Zc.document,
        width: original.lastWidth,
        edges: original.edges,
      ),
      theirEdges: safe.edges,
      theirYs: pageEdgeYs(
        text: bench.payload!.text,
        style: Zc.document,
        width: safe.lastWidth,
        edges: safe.edges,
      ),
    );
    expect(
      right.offset,
      closeTo(
        inStepOffset(
          from: left.offset,
          mine: paired.mine,
          theirs: paired.theirs,
          myExtent: left.position.maxScrollExtent,
          theirExtent: right.position.maxScrollExtent,
        ),
        1.0,
      ),
      reason: 'the screen and the arithmetic disagree about where the page is',
    );

    // Apart: each column is its own again.
    await tester.tap(find.byKey(_ColumnsStateKeys.stepLock));
    await settle(tester);
    final parked = right.offset;
    left.jumpTo(left.position.maxScrollExtent / 2);
    await settle(tester, rounds: 2);
    expect(right.offset, parked, reason: 'Apart did not let the columns go');
  });

  testWidgets('the columns start in step, and the link can be opened and shut', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      final here = Directory('${Directory.systemTemp.path}/zprivacy-lock-$pid');
      if (here.existsSync()) here.deleteSync(recursive: true);
      addTearDown(() {
        if (here.existsSync()) here.deleteSync(recursive: true);
      });
      await z.setDataDir(dir: here.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _three);
      await bench.rescan();
      await bench.refresh();
    });
    addTearDown(bench.dispose);

    // The core's answer, before any screen: on, because the complaint was that
    // the second column did not follow the first.
    expect(ground.config!.columnsInStep, isTrue);

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);

    // It says what is true now, not what pressing it will do.
    expect(find.text('In step'), findsOneWidget);
    expect(find.text('Apart'), findsNothing);

    await tester.tap(find.byKey(_ColumnsStateKeys.stepLock));
    await settle(tester);
    expect(find.text('Apart'), findsOneWidget);
    expect(find.text('In step'), findsNothing);

    // And it is kept, beside the handle's position, in the one durable store
    // this app has before a vault exists.
    await tester.runAsync(ground.refresh);
    expect(ground.config!.columnsInStep, isFalse,
        reason: 'the choice was not kept, so it would be undone at the next launch');

    await tester.tap(find.byKey(_ColumnsStateKeys.stepLock));
    await settle(tester);
    expect(find.text('In step'), findsOneWidget);
    await tester.runAsync(ground.refresh);
    expect(ground.config!.columnsInStep, isTrue);
  });
}

/// The keys the Workspace exposes for this test, named here so the test does
/// not reach into a private class.
class _ColumnsStateKeys {
  static const stepLock = ValueKey<String>('workspace-step-lock');
  static const originalPane = ValueKey<String>('workspace-original-pane');
  static const safePane = ValueKey<String>('workspace-safe-pane');
}

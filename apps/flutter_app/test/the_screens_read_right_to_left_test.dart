// 116 item 1 · When the interface is Arabic, the screens read right to left.
//
// The owner, 25 October 2026: Arabic means «إمكانية قراءة الشاشات بهذه اللغة» —
// the ability to read the screens in this language. A right-to-left interface
// is not a translation: it is the same screens, mirrored, and the places that
// do not mirror are the places somebody wrote a side down.
//
// ## What this file measures, and why it measures rects
//
// Flutter mirrors a great deal on its own — a `Row`'s children, the logical
// `MainAxisAlignment.start`, a `Text` with no `textAlign` — and nothing at all
// of what was written in **physical** directions: `EdgeInsets.fromLTRB`,
// `Alignment.centerLeft`, `Positioned(left:)`, `Border(left:)`. The second
// kind cannot be found by reading the glass for a word, because a symmetric
// `fromLTRB(18, 13, 18, 13)` is perfectly correct and a lopsided one is not.
// So each guard here forces `Directionality.rtl` over a real screen and asks
// **where things landed** — the same instrument 064/B and 063 used for the
// crowded bar, pointed at the other axis.
//
// `Directionality.rtl` is forced rather than taken from a locale because
// `app_ar.arb` is paper 115's and is not in this tree yet. The layout is the
// half that can be measured today; the words come over it when 115 lands, and
// the owner looks at the screens himself before Arabic is published.
//
// ## And the one thing that must NOT mirror
//
// **The document keeps its own direction.** An English letter in an Arabic
// interface still reads left to right, and an Arabic letter in an English one
// reads right to left — the direction belongs to the text (086's reading
// base), not to the person's choice of interface. That is guard 5, and it is
// the one that was wrong on `bfd79e6` in the worst way: the document column
// asked `Directionality.of(context)`, which is the **interface's** answer.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/line_gutter.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// A German letter: every word of it reads left to right, whatever the
/// interface is doing.
const _german = 'Sehr geehrter Herr Markus Weber,\n'
    'IBAN: DE89370400440532013000\n'
    'Mit freundlichen Grüßen\n';

/// And an Arabic one, for the mirror of the same law.
const _arabic = 'حضرة السيد ماركوس فيبر،\n'
    'رقم الحساب: DE89370400440532013000\n'
    'وتفضلوا بقبول فائق الاحترام\n';

const _width = 1400.0;

Future<void> _settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Future<({Ground ground, Workbench bench})> _ready(
  WidgetTester tester,
  String name, {
  String text = _german,
}) async {
  late final ({Ground ground, Workbench bench}) made;
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-rtl-$name-$pid');
    removeWhenItLetsGo(own);
    own.createSync(recursive: true);
    addTearDown(() {
      removeWhenItLetsGo(own);
    });
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för spegeln');
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: text);
    await bench.rescan();
    await ground.refresh();
    made = (ground: ground, bench: bench);
  });
  return made;
}

/// The screen as an Arabic reader meets it: the same widget tree, mirrored by
/// the one thing that decides it.
Widget _mirrored(Widget child) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

Widget _asItIs(Widget child) => MaterialApp(
      home: Directionality(textDirection: TextDirection.ltr, child: child),
    );

Widget _workspace(({Ground ground, Workbench bench}) g) => WorkspaceScreen(
      bench: g.bench,
      ground: g.ground,
      onImport: () {}, onAsk: (_) {},
      onVault: () {},
      onSettings: (_) {},
      onReadBack: () {},
    );

/// Which half of the window a rect sits in — the whole question this file asks,
/// in one word a failure message can carry.
String _side(Rect r, [double width = _width]) =>
    r.center.dx < width / 2 ? 'the left half' : 'the right half';

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // **The bar's own ends change places.** The mark and the product's name open
  // the bar; the settings door closes it. Mirrored, the mark is on the right
  // and the door on the left — and nothing in between may be left behind,
  // which is what a lopsided padding does.
  testWidgets('the top bar mirrors: the mark opens it on the right, the settings door closes it on the left',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(_width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'bar');

    await tester.pumpWidget(_asItIs(_workspace(g)));
    await _settle(tester);
    final markLtr = tester.getRect(find.byType(BrandMark));
    final doorLtr = tester.getRect(find.byTooltip('Settings').first);
    expect(_side(markLtr), 'the left half', reason: 'the mark does not open the bar in an LTR interface');
    expect(_side(doorLtr), 'the right half', reason: 'the settings door does not close the bar in LTR');

    await tester.pumpWidget(_mirrored(_workspace(g)));
    await _settle(tester);
    final mark = tester.getRect(find.byType(BrandMark));
    final door = tester.getRect(find.byTooltip('Settings').first);
    expect(_side(mark), 'the right half',
        reason: 'mirrored, the mark is still in ${_side(mark)} at $mark');
    expect(_side(door), 'the left half',
        reason: 'mirrored, the settings door is still in ${_side(door)} at $door');
    // And the two have swapped, not merely moved: the mark opens the bar.
    expect(mark.center.dx, greaterThan(door.center.dx),
        reason: 'mirrored, the mark does not stand before the door as a reader meets them');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **The three parts read in the reader's own order.** Original, Safe, Chat
  // left to right becomes Original, Safe, Chat **right to left** — the first
  // part is where the eye starts, which in Arabic is the right edge.
  testWidgets('the three parts mirror: the original is where reading begins', (tester) async {
    await tester.binding.setSurfaceSize(const Size(_width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'parts');

    await tester.pumpWidget(_mirrored(_workspace(g)));
    await _settle(tester);

    final original = tester.getRect(find.byKey(_originalPane));
    final safe = tester.getRect(find.byKey(_safePane));
    expect(original.center.dx, greaterThan(safe.center.dx),
        reason: 'mirrored, the original column is not where an Arabic reader starts: '
            'original $original, safe $safe');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The gutter belongs to the document, not to the interface**, and the first
  // form of this guard had that backwards: it asked for the numbers to mirror
  // when the *interface* did, with a German document in front of it. They must
  // stand beside the **line starts** — on the left of a German letter whatever
  // the interface is doing, and on the right of an Arabic one. Written with a
  // physical `left:` until today, which put them on the far side of every
  // Arabic document anybody reviewed.
  testWidgets('the line numbers stand beside the line starts, in either interface',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(_width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final (what, text, startsOnTheLeft) in [
      ('a German letter', _german, true),
      ('an Arabic letter', _arabic, false),
    ]) {
      final g = await _ready(tester, 'gutter-${startsOnTheLeft ? 'de' : 'ar'}', text: text);
      for (final (interface, wrap) in [('English', _asItIs), ('Arabic', _mirrored)]) {
        await tester.pumpWidget(wrap(_workspace(g)));
        await _settle(tester);
        final gutter = find.byKey(LineGutter.gutter);
        expect(gutter, findsWidgets,
            reason: 'no line gutter on the glass for $what in an $interface interface');
        final g1 = tester.getRect(gutter.first);
        final column = tester.getRect(find.byKey(_originalPane));
        final onTheLeft = g1.center.dx < column.center.dx;
        expect(onTheLeft, startsOnTheLeft,
            reason: '$what in an $interface interface: the numbers are in '
                '${onTheLeft ? 'the left' : 'the right'} half of their column ($g1 in $column), '
                'and that letter\u2019s lines begin on '
                '${startsOnTheLeft ? 'the left' : 'the right'}');
      }
    }
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **The settings panel covers the end of the window, not the right of it.**
  // 063 put it «480 wide against the right edge — the owner's number». Against
  // the *end*: in Arabic that is the left.
  //
  // **Mounted through the shell, because the first form of this guard measured
  // nothing.** It pumped `SettingsScreen` on its own, which fills whatever box
  // it is given, so `panel.left` was 0 in both directions and the guard was
  // green about a `Positioned` it never saw. The placing lives in the shell's
  // own `Stack`, so the shell is what has to be on the glass.
  testWidgets('the settings panel covers the end of the window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(_width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final own = Directory('${Directory.systemTemp.path}/zprivacy-rtl-panel-$pid');
    removeWhenItLetsGo(own);
    own.createSync(recursive: true);
    addTearDown(() {
      removeWhenItLetsGo(own);
    });
    final ground = Ground();
    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: own.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för panelen');
      await ground.refresh();
      final now = await z.settings();
      await ground.saveConfig(Settings(
        originalPanePercent: now.originalPanePercent,
        columnsInStep: now.columnsInStep,
        safeColumnOpen: true,
        reviewPanelWide: false,
        scanOnImport: now.scanOnImport,
        revealSeconds: now.revealSeconds,
        autoLockMinutes: now.autoLockMinutes,
        packId: now.packId,
        language: now.language,
        firstRunDone: true,
        sessionOnly: now.sessionOnly,
      ));
      await ground.refresh();
    });

    await tester.pumpWidget(_mirrored(ZShell(dataDir: own.path, ground: ground)));
    await _settle(tester);
    await tester.tap(find.byTooltip('Settings').first);
    await _settle(tester);

    final panel = find.byType(SettingsScreen);
    expect(panel, findsOneWidget, reason: 'the panel did not open on the shell');
    final r = tester.getRect(panel);
    expect(r.left, lessThan(1),
        reason: 'mirrored, the panel does not cover the end of the window — it is at $r, '
            'so it is still against the physical right edge');
    expect(r.width, closeTo(480, 1),
        reason: 'the panel is ${r.width} wide and the owner\u2019s number is 480');
  });

  // ------------------------------------------------------------------ guard 5
  //
  // **The document keeps its own direction, measured as a difference.**
  //
  // The first form of this guard asked «is the German letter's first word in
  // the left half of its column while the interface is mirrored» — and passed,
  // twice, for two different wrong reasons: it was reading whichever column
  // held the word first (both hold «Sehr geehrter Herr»; only the name between
  // them is replaced), and a line that wraps to the full width of its box
  // starts at the left edge whichever direction laid it out. A guard that
  // cannot fail is a guard that proves nothing.
  //
  // So the question is asked as a **difference**: lay the same document out in
  // an English interface and in an Arabic one, and the words must land in the
  // same place inside their own column. That is the law in one sentence — the
  // direction belongs to the text (086's reading base) and not to the person's
  // choice of interface — and nothing about wrapping or column width can make
  // it pass by accident.
  testWidgets('mirroring the interface does not move a left-to-right document', (tester) async {
    await tester.binding.setSurfaceSize(const Size(_width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'doc-ltr');

    await tester.pumpWidget(_asItIs(_workspace(g)));
    await _settle(tester);
    final wordLtr = _inItsText(tester, 'Sehr');
    final ibanLtr = _inItsText(tester, 'DE89370400440532013000');

    await tester.pumpWidget(_mirrored(_workspace(g)));
    await _settle(tester);
    final wordRtl = _inItsText(tester, 'Sehr');
    final ibanRtl = _inItsText(tester, 'DE89370400440532013000');

    expect(wordLtr, isNotNull, reason: 'the first word is not in the original column at all');
    expect(ibanLtr, isNotNull, reason: 'the IBAN is not in the original column at all');
    expect(wordRtl, closeTo(wordLtr!, 1),
        reason: 'the interface mirrored and the German letter moved with it: the first word sits '
            '${wordLtr.toStringAsFixed(1)} into its column in English and '
            '${wordRtl!.toStringAsFixed(1)} in Arabic — the document followed the interface '
            'instead of its own reading base');
    expect(ibanRtl, closeTo(ibanLtr!, 1),
        reason: 'the IBAN moved when the interface mirrored: ${ibanLtr.toStringAsFixed(1)} → '
            '${ibanRtl!.toStringAsFixed(1)} — a bidi pass nobody asked for reordered a number '
            'the person has to read against their bank statement');
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **And the mirror of it**: an Arabic document does not move when the
  // interface is English. Together the two say the direction is the text's,
  // because a tree that simply ignored direction altogether would fail one of
  // them — the Arabic letter must start at the far side of its own column.
  testWidgets('an Arabic document reads from its own side, in either interface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(_width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'doc-rtl', text: _arabic);

    await tester.pumpWidget(_asItIs(_workspace(g)));
    await _settle(tester);
    final atLtr = _inItsText(tester, 'حضرة');

    await tester.pumpWidget(_mirrored(_workspace(g)));
    await _settle(tester);
    final atRtl = _inItsText(tester, 'حضرة');

    expect(atLtr, isNotNull, reason: 'the Arabic letter’s first word is not in its column');
    expect(atRtl, closeTo(atLtr!, 1),
        reason: 'the Arabic letter moved when the interface changed: '
            '${atLtr.toStringAsFixed(1)} → ${atRtl!.toStringAsFixed(1)}');
    // And it really is laid out from its own side, so this pair is not two
    // measurements of a tree that ignores direction: the first word of an
    // Arabic letter stands at the **end** of its own box, within a few pixels,
    // in both interfaces.
    final endLtr = _fromTheEndOfItsText(tester, 'حضرة');
    expect(endLtr, isNotNull);
    expect(endLtr!, lessThan(8),
        reason: 'the Arabic letter’s first word is ${endLtr.toStringAsFixed(1)} px from the end '
            'of its own box, so it was laid out left to right');
  });
}

/// How far into **the text's own box** a word begins — and that box, not the
/// column, is the measurement.
///
/// Probed before it was settled, because the first form of this compared the
/// word with the **column** and read a 139.5 px difference between the two
/// interfaces. The probe said where it came from: the text block is narrower
/// than its part (the person's own split leaves slack), and the block hugs the
/// part's start — which mirrors, as interface furniture should. The words
/// inside it had not moved at all: 0.1 px into the text box in English and
/// 0.1 px in Arabic.
///
/// So the law this file is for — the document reads its own way — is a question
/// about the text and not about where its block sits in a part. A guard that
/// asked the wider question would have failed on a correct screen and made
/// somebody «fix» the interface's own mirroring.
double? _inItsText(WidgetTester tester, String word) {
  final column = find.byKey(_originalPane);
  final rect = _rectOfWord(tester, word, within: column);
  if (rect == null) return null;
  final text = find.descendant(of: column, matching: find.byType(SelectableText));
  if (text.evaluate().isEmpty) return null;
  return rect.left - tester.getRect(text.first).left;
}

/// And how far from the **end** of its own box — the question an Arabic
/// document answers, which is the half that proves the pair is not measuring a
/// tree that ignores direction.
double? _fromTheEndOfItsText(WidgetTester tester, String word) {
  final column = find.byKey(_originalPane);
  final rect = _rectOfWord(tester, word, within: column);
  if (rect == null) return null;
  final text = find.descendant(of: column, matching: find.byType(SelectableText));
  if (text.evaluate().isEmpty) return null;
  return tester.getRect(text.first).right - rect.right;
}

const _originalPane = ValueKey<String>('workspace-original-pane');
const _safePane = ValueKey<String>('workspace-safe-pane');

/// Where a word of the document is drawn.
///
/// **Through the render object, and the right one.** «A `TextPainter` is not an
/// `EditableText`'s layout» is one of this house's own lessons, and the first
/// form of this helper walked `RenderParagraph`s and found nothing at all: the
/// document column is a `SelectableText`, which keeps its `EditableText` a few
/// layers down, and that paints through a **`RenderEditable`**. The column's own
/// code says so in `_editableState`'s doc comment — «the render object can be
/// read; only the state can be told» — and this walks the tree the same way,
/// for the object rather than for the state.
///
/// Both kinds are looked for, because the Safe column and the bands are
/// ordinary rich text and the Original is editable.
///
/// **And the search is scoped to one column, which the second form of this
/// guard needed.** «Sehr geehrter Herr» stands in the Original *and* in the
/// Safe column — only the name between them is replaced — so a walk of the
/// whole tree answered with whichever came first and the guard then compared
/// that rect with the Original's box. Green, about the wrong column. A
/// measurement of «where is this word» must say **which** of the two.
Rect? _rectOfWord(WidgetTester tester, String word, {required Finder within}) {
  Rect? answer;
  void look(RenderObject render) {
    if (answer != null) return;
    String? text;
    List<TextBox> boxes = const [];
    int at = -1;
    if (render is RenderEditable) {
      text = render.text?.toPlainText();
      at = text?.indexOf(word) ?? -1;
      if (at >= 0) {
        boxes = render.getBoxesForSelection(
          TextSelection(baseOffset: at, extentOffset: at + word.length),
        );
      }
    } else if (render is RenderParagraph) {
      text = render.text.toPlainText();
      at = text.indexOf(word);
      if (at >= 0) {
        boxes = render.getBoxesForSelection(
          TextSelection(baseOffset: at, extentOffset: at + word.length),
        );
      }
    }
    if (at >= 0 && boxes.isNotEmpty) {
      final local = boxes.first.toRect();
      final origin = (render as RenderBox).localToGlobal(local.topLeft);
      answer = Rect.fromLTWH(origin.dx, origin.dy, local.width, local.height);
      return;
    }
    render.visitChildren(look);
  }

  final root = within.evaluate().single.renderObject;
  if (root == null) return null;
  look(root);
  return answer;
}

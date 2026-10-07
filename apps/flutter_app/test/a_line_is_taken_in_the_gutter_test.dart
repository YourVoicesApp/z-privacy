// 046/Q · the gesture — lines are taken in the gutter, words in the text.
//
// **The lead's decision, 7 October:** a line-number gutter down the left of the
// document column. Click a number to take that line, drag to take a range, a
// control at its head to take them all — and nothing in the text's own
// behaviour changes, so 041-K's word selection and the questions a mark asks
// are untouched. No mode, no modifier key, no collision.
//
// With it: the three numbers said **before** any press, a press on a value
// inside the held lines performing the act with no confirmation, the refusal
// shown as a sentence that says *why* the app cannot choose a column, and
// nothing folding or opening by itself.
//
// Two things this file is written to catch, because both are mistakes already
// made in this project:
//
//   * **the offset shifted by the gutter.** The press used to read its layout
//     width back from this widget's own render box; with a gutter beside the
//     text that box is the whole row, so the painter would lay the text out
//     tens of pixels too wide and a press would land on the wrong word. An
//     offset that is one out is a protection in the wrong place. The test
//     presses an account number and asserts **that value** left the payload
//     and that the amount beside it did not.
//   * **a guard green for the wrong reason.** Every press here goes through
//     the real `Listener` at a point taken from the real `RenderParagraph`, so
//     what is hit is what is drawn; and the refusal test asserts the sentence
//     says why rather than merely that something failed.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/line_gutter.dart';
import 'package:zprivacy/widgets/why_sheet.dart';

import 'drawn_document.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

const _originalPane = ValueKey<String>('workspace-original-pane');
const _band = ValueKey<String>('held-lines-band');

/// A payroll sheet in the shape the owner's own is in: cells separated by two
/// or more spaces, an account column, and amounts that must still reach the
/// model. Line 0 is the heading, lines 1..4 are the rows.
const _sheet = 'staff              account no.    gross\n'
    'Hedvig Palmgren    9999 000 01    42 500\n'
    'Tobias Nyqvist     9999 000 02    34 800\n'
    'Amina Saleh        9999 000 03    31 200\n'
    'Jonatan Ferm       9999 000 04    28 400\n';

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

/// The same sheet with long rows, so that **every row wraps** in the column.
///
/// This is the document that makes the width matter. With rows that fit on one
/// visual line, laying the text out at the wrong width changes no offset at
/// all — measured: the press test below passes against the old defect on
/// `_sheet`. A wrapped row is where a width that is 46 pixels out moves a
/// press onto a different line of the document.
const _wide = 'reference                                                    '
    'period                        staff              account no.    gross\n'
    'invoice 2027-0001 issued in the city of Stockholm for the month of '
    'February 2027      month 02                      Hedvig Palmgren    '
    '9999 000 01    42 500\n'
    'invoice 2027-0002 issued in the city of Stockholm for the month of '
    'February 2027      month 02                      Tobias Nyqvist     '
    '9999 000 02    34 800\n'
    'invoice 2027-0003 issued in the city of Stockholm for the month of '
    'February 2027      month 02                      Amina Saleh        '
    '9999 000 03    31 200\n';

Future<(Ground, Workbench)> _open(WidgetTester tester, String name, {String text = _sheet}) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-gutter-$name-$pid');
    if (here.existsSync()) here.deleteSync(recursive: true);
    addTearDown(() {
      if (here.existsSync()) here.deleteSync(recursive: true);
    });
    await z.setDataDir(dir: here.path);
    await ground.refresh();
    final session = await z.openSession(packId: 'en');
    bench = Workbench(session: session, profileId: null, packId: 'en');
    await z.importText(session: session, text: text);
    await bench.rescan();
    await bench.refresh();
  });
  addTearDown(bench.dispose);
  await tester.pumpWidget(MaterialApp(
    home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
  ));
  await settle(tester);
  return (ground, bench);
}

/// Where the character at `offset` is on the screen, from the text as it is
/// drawn — `drawn_document.dart` says why no test in this app lays the document
/// out for itself any more.
Offset _whereIs(WidgetTester tester, int offset) =>
    whereIsInDocument(tester, 'Hedvig', offset, span: 1);

/// Where a line's number sits in the gutter: the gutter's own x, and the y the
/// drawn text puts that line at.
Offset _gutterAt(WidgetTester tester, int line, {String text = _sheet}) {
  final starts = lineStarts(text);
  final y = _whereIs(tester, starts[line]).dy;
  final box = tester.renderObject<RenderBox>(find.byKey(LineGutter.gutter));
  return Offset(box.localToGlobal(Offset.zero).dx + LineGutter.width / 2, y);
}

/// The index in the sheet of the start of a string.
int _indexOf(String what, {String text = _sheet}) {
  final at = text.indexOf(what);
  if (at < 0) throw StateError('«$what» is not in the sheet');
  return at;
}

/// How many values are protected in the document right now.
///
/// The **marks**, and not `Workbench.protectedCount`: that one counts findings
/// the scanner raised, and a protection made by hand down a column raises no
/// finding — so it stayed at zero through an act that protected four values.
/// Measured on the first run of this file, and it is the shape of a guard that
/// is green for the wrong reason: the refusal test below would have passed
/// against zero whatever the act did.
int _protectedNow(Workbench bench) =>
    bench.document!.marks.where((m) => m.state == MarkState.protected).length;

String _bandSays(WidgetTester tester) {
  final texts = find.descendant(of: find.byKey(_band), matching: find.byType(Text));
  final out = <String>[];
  for (final element in texts.evaluate()) {
    final widget = element.widget;
    if (widget is Text && widget.data != null) out.add(widget.data!);
  }
  return out.join(' ⏎ ');
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------- 1 · the gutter, and one line

  testWidgets('a press in the gutter takes that line, and the core says what is in it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'one');

    expect(find.byKey(LineGutter.gutter), findsOneWidget,
        reason: 'the document has no line gutter');
    expect(find.byKey(_band), findsNothing,
        reason: 'the band is there before any line is held');

    await tester.tapAt(_gutterAt(tester, 2));
    await settle(tester, rounds: 12);

    expect(bench.lines, isNotNull, reason: 'the press held no lines');
    expect(bench.lines!.from, 2, reason: 'the press took the wrong line');
    expect(bench.lines!.to, 2, reason: 'a press is one line, not a range');
    // The numbers are the core's. The screen is asserted to be *showing* them,
    // not to have worked them out.
    final hold = bench.linesHold;
    expect(hold, isNotNull, reason: 'the core was not asked what the line holds');
    expect(hold!.lines, 1);
    expect(_bandSays(tester), contains('1 line'), reason: _bandSays(tester));
    // The number, whichever way the sentence is turned — «in it» for one line
    // and «in them» for several, which is a wording the band may change and
    // this test has no business holding still.
    expect(_bandSays(tester), contains('${hold.protected} protected in'),
        reason: 'the band does not say the core number: ${_bandSays(tester)}');
    expect(_bandSays(tester), contains('${hold.open} open'), reason: _bandSays(tester));
  });

  // ------------------------------------------------ 2 · a drag, and all of it

  testWidgets('a drag down the gutter takes a range, and the head control takes every line', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'range');

    await tester.dragFrom(_gutterAt(tester, 1), _gutterAt(tester, 4) - _gutterAt(tester, 1));
    await settle(tester, rounds: 12);
    expect(bench.lines, isNotNull, reason: 'the drag held nothing');
    expect(bench.lines!.from, 1, reason: 'the range did not begin where the drag began');
    expect(bench.lines!.to, 4, reason: 'the range did not end where the drag ended');
    expect(bench.linesHold!.lines, 4, reason: 'the core counted a different number of lines');

    // And every line. The count is the document's own — six, because the sheet
    // ends in a newline and the empty line after it is a line a person can see.
    await tester.tap(find.byKey(AllLinesBand.control));
    await settle(tester, rounds: 12);
    expect(bench.linesHold!.lines, lineStarts(_sheet).length,
        reason: 'all is not every line of the document');
  });

  // ------------------------------- 3 · one press, and the column is protected

  testWidgets('one press on a value protects that cell in every held line, and the amounts still leave', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'column');

    final before = _protectedNow(bench);
    final tokensBefore = bench.tokens.length;

    await tester.dragFrom(_gutterAt(tester, 1), _gutterAt(tester, 4) - _gutterAt(tester, 1));
    await settle(tester, rounds: 12);

    // One press, on the account number of the first held row.
    await tester.tapAt(_whereIs(tester, _indexOf('9999 000 01') + 2));
    await settle(tester, rounds: 20);

    expect(_protectedNow(bench), before + 4,
        reason: 'one press reached ${_protectedNow(bench) - before} places, not 4');
    expect(bench.tokens.length, tokensBefore + 4,
        reason: 'each value must be its own token — 046/M');

    // **What leaves.** Every account number is gone from the payload and every
    // amount is still in it: a line taken whole would have swallowed the row,
    // which is 046/M's defect arriving by another door.
    final leaves = bench.payload!.text;
    for (final account in ['9999 000 01', '9999 000 02', '9999 000 03', '9999 000 04']) {
      expect(leaves.contains(account), isFalse, reason: '$account is still in what leaves');
    }
    for (final amount in ['42 500', '34 800', '31 200', '28 400']) {
      expect(leaves.contains(amount), isTrue, reason: '$amount no longer reaches the model');
    }
    // And the heading's own cell, on line 0, was never in the selection.
    expect(leaves.contains('account no.'), isTrue,
        reason: 'the heading was outside the held lines and must be untouched');
  });

  // ----------------------------------------- 4 · the gap between two columns

  testWidgets('a press between two columns says why, and protects nothing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'gap');

    await tester.dragFrom(_gutterAt(tester, 1), _gutterAt(tester, 4) - _gutterAt(tester, 1));
    await settle(tester, rounds: 12);
    final before = _protectedNow(bench);
    // A control: the act **does** work on this document, so a later zero is a
    // refusal and not a test that was never going to protect anything.
    expect(before, 0, reason: 'the sheet already had protections before the act');

    // The run of spaces between «Hedvig Palmgren» and its account number.
    await tester.tapAt(_whereIs(tester, _indexOf('    9999 000 01') + 1));
    await settle(tester, rounds: 16);

    expect(_protectedNow(bench), before,
        reason: 'a press in the gap protected something anyway');
    final said = bench.trouble ?? '';
    // **Why, and not merely that it will not.** The sentence names the place
    // and the refusal; and it is specifically *not* the one `BadSpan` carries,
    // which would tell him to select again in the same place.
    expect(said, contains('between two columns'), reason: 'the sentence does not say where: «$said»');
    expect(said.toLowerCase(), contains('will not choose'),
        reason: 'the sentence does not say why the app cannot choose: «$said»');
    expect(said.contains('could not be read'), isFalse,
        reason: 'the press was read perfectly; that sentence is false here: «$said»');
  });

  // ------------------------------------- 5 · nothing folds or opens by itself

  testWidgets('the lines stay held through the act, and go only by a press', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'held');

    await tester.dragFrom(_gutterAt(tester, 1), _gutterAt(tester, 4) - _gutterAt(tester, 1));
    await settle(tester, rounds: 12);
    await tester.tapAt(_whereIs(tester, _indexOf('9999 000 01') + 2));
    await settle(tester, rounds: 20);

    // The owner's standing rule of 7 October, and the reason it matters here:
    // the second column of the same rows has to be one press away.
    expect(bench.lines, isNotNull, reason: 'the act released the lines by itself');
    expect(bench.linesHold!.lines, 4, reason: 'the numbers were not asked again after the act');
    expect(bench.linesHold!.protected, greaterThanOrEqualTo(4),
        reason: 'the band still shows what the selection held before the act');

    // A rescan is the app doing something on its own. It may not move this.
    await tester.runAsync(() => bench.rescan());
    await settle(tester, rounds: 10);
    expect(bench.lines, isNotNull, reason: 'a rescan released the lines');

    // And one press lets them go.
    await tester.tap(find.widgetWithText(ZButton, 'Let the lines go'));
    await settle(tester, rounds: 8);
    expect(bench.lines, isNull, reason: 'the press did not release the lines');
    expect(find.byKey(_band), findsNothing, reason: 'the band outlived its selection');
  });

  // ---------------------------------- 6 · a protected word still asks its why

  testWidgets('inside the held lines, a word already protected still asks why', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'why');

    await tester.dragFrom(_gutterAt(tester, 1), _gutterAt(tester, 4) - _gutterAt(tester, 1));
    await settle(tester, rounds: 12);
    await tester.tapAt(_whereIs(tester, _indexOf('9999 000 01') + 2));
    await settle(tester, rounds: 20);
    final after = _protectedNow(bench);
    expect(after, 4, reason: 'the first press did not protect the column, so this proves nothing');

    // The same cell again. For this one the act has nothing left to do, so the
    // press means the one other thing it can mean — «why is this protected?»
    await tester.tapAt(_whereIs(tester, _indexOf('9999 000 02') + 2));
    await settle(tester, rounds: 16);

    expect(_protectedNow(bench), after, reason: 'the second press protected something again');
    // By its type, not by a word on it: "Why" is also written on a button, and
    // matching a word is how a guard goes green while the sheet never opened.
    expect(find.byType(WhySheet), findsOneWidget,
        reason: 'a protected word inside a selection asked nothing');
  });

  // --------------------------------------------- 7 · a row that wraps

  testWidgets('a wrapped row still presses the cell a person pointed at', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'wrapped', text: _wide);

    // Every row wraps here, so a gutter number sits beside a block of two or
    // three screen rows and a press has to be read against the layout that was
    // drawn. **The control for the width**: laying the text out at the row's
    // width instead of the text's is 46 pixels out, which on an unwrapped
    // document moves no offset and here moves the press onto another line.
    final gutter = tester.renderObject<RenderBox>(find.byKey(LineGutter.gutter));
    expect(gutter.size.height, greaterThan(lineStarts(_wide).length * 30),
        reason: 'nothing wrapped, so this test proves nothing about width');

    await tester.dragFrom(
      _gutterAt(tester, 1, text: _wide),
      _gutterAt(tester, 3, text: _wide) - _gutterAt(tester, 1, text: _wide),
    );
    await settle(tester, rounds: 12);
    expect(bench.linesHold!.lines, 3, reason: 'the drag did not hold three wrapped rows');

    final before = _protectedNow(bench);
    await tester.tapAt(_whereIs(tester, _indexOf('9999 000 01', text: _wide) + 2));
    await settle(tester, rounds: 20);

    expect(_protectedNow(bench), before + 3,
        reason: 'the press reached ${_protectedNow(bench) - before} of three wrapped rows');
    final leaves = bench.payload!.text;
    for (final account in ['9999 000 01', '9999 000 02', '9999 000 03']) {
      expect(leaves.contains(account), isFalse, reason: '$account is still in what leaves');
    }
    for (final amount in ['42 500', '34 800', '31 200']) {
      expect(leaves.contains(amount), isTrue, reason: '$amount no longer reaches the model');
    }
  });

  // ------------------------------------------------------- 8 · what it costs

  test('a long document costs what a short one costs', () {
    // 048 measured documents of 5 770 and 82 468 lines on this machine. The
    // gutter draws numbers with a painter and skips every line outside the
    // canvas's clip, so that a document's length cannot become a frame's cost.
    const lines = 5000;
    const row = 24.0;
    final layout = GutterLayout(
      tops: List<double>.generate(lines, (i) => i * row),
      height: lines * row,
    );
    final painter = GutterPainter(
      lines: () => layout,
      from: 10,
      to: 20,
      direction: TextDirection.ltr,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // A window 600 pixels tall, which is what the column gets on a laptop.
    canvas.clipRect(const Rect.fromLTWH(0, 1200, LineGutter.width, 600));
    painter.paint(canvas, const Size(LineGutter.width, lines * row));
    recorder.endRecording().dispose();

    expect(painter.drawn, lessThan(40),
        reason: 'the painter drew ${painter.drawn} of $lines numbers for a 600-pixel window');
    expect(painter.drawn, greaterThan(0), reason: 'the clip hid everything, which is the false zero');
  });

  testWidgets('reading every line of a long document is paid once', (tester) async {
    // The honest cost of the gutter: the top of **every** logical line, asked
    // of the text that is drawn. It is kept per (spans, drawn size) in the
    // widget, so this is what a document costs when it arrives and when the
    // window is resized — not what it costs per frame.
    const lines = 3000;
    final text = List<String>.generate(lines, (i) => 'row $i has a value 9999 000 $i').join('\n');
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SelectableText.rich(
            TextSpan(text: text),
            style: Zc.document,
          ),
        ),
      ),
    ));
    await tester.pump();
    final state = tester.state(find.byType(EditableText)) as EditableTextState;
    final clock = Stopwatch()..start();
    final layout = linesOf(state.renderEditable, text);
    clock.stop();
    expect(layout.lines, lines, reason: 'a line was lost or invented');
    // A number, not a feeling. Printed so the report can quote it.
    // ignore: avoid_print
    print('linesOf · $lines lines · ${clock.elapsedMilliseconds} ms · '
        'height ${layout.height.round()}');
    expect(clock.elapsedMilliseconds, lessThan(4000),
        reason: 'reading $lines lines took ${clock.elapsedMilliseconds} ms');
  });
}

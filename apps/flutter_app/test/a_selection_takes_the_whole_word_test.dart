// 041-K · The offsets a selection reports are the document's own, and a
// selection drawn by hand takes whole words.
//
// Two defects, both from the owner's live run on 6 October, both measured here:
//
//  1. a zero-size `WidgetSpan` used to be dropped into the text as the scroll
//     anchor for «go to this finding». A placeholder span is one U+FFFC
//     character in the string the selection counts in, so every offset after
//     the focused finding came back one too high and the protection landed one
//     character late — `J__Z_…`, with the J still standing.
//  2. at the left margin the pointer lands after the first character, so the
//     core grows a selection out to whole words before it becomes anything.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/document_text.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Jonas Bjarne skrev avtalet.\nHälsningar, Björn Sandström\n';

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('the text the selection counts in is the document, character for character', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OriginalText(
          text: _doc,
          marks: const [],
          // A finding is focused, as one is through a whole review.
          focus: const Span(start: 28, end: 38),
          focusKey: key,
          onSelection: (_, _) {},
        ),
      ),
    ));
    await tester.pump();

    final shown = tester.widget<SelectableText>(find.byType(SelectableText));
    final plain = shown.textSpan!.toPlainText();
    expect(plain.length, _doc.length,
        reason: 'the span tree is ${plain.length} characters where the document is ${_doc.length}');
    expect(plain.contains('￼'), isFalse, reason: 'a placeholder is still inside the text');
    expect(plain.indexOf('Björn'), _doc.indexOf('Björn'),
        reason: 'a word after the focused finding sits at the wrong offset');
    // And the thing «go to this finding» scrolls to is still there, beside it.
    expect(find.byKey(key), findsOneWidget, reason: 'the scroll anchor went missing with the placeholder');
  });

  testWidgets('a selection that starts one character late protects the whole word', (tester) async {
    late final Workbench bench;
    late final SelectionView view;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-wholeword-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      final session = await z.openSession(packId: 'sv');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'sv');
      await bench.rescan();

      // «onas Bjarne» — the drag that starts after the first character.
      await bench.select(const Span(start: 1, end: 12));
      view = bench.selected!;
    });

    // The screen's own selection moved with it: what is highlighted is what
    // will happen.
    expect(bench.selection, const Span(start: 0, end: 12),
        reason: 'the highlight still shows the selection that was drawn');
    expect(view.wordSpan, const Span(start: 0, end: 12));

    await tester.runAsync(() async {
      await bench.protectSelection(scope: Scope.once, kind: Kind.person, allMatches: false);
      await bench.refresh();
    });
    final safe = bench.payload?.text ?? '';
    expect(safe.startsWith('__Z_'), isTrue, reason: 'the first letter was left behind: $safe');
    bench.dispose();
  });

  testWidgets('the capitalised word in front is offered, and taking it is a press', (tester) async {
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-wordbefore-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      final session = await z.openSession(packId: 'sv');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'sv');
      await bench.rescan();
      await bench.select(Span(start: _doc.indexOf('Sandström'), end: _doc.indexOf('Sandström') + 9));
    });

    expect(bench.selected!.alsoBefore, isNotNull, reason: '«Björn» was not offered');
    await tester.runAsync(() => bench.alsoTakeTheWordBefore());
    expect(bench.selection!.start, _doc.indexOf('Björn'), reason: 'the offer did not extend the selection');
    expect(bench.selection!.end, _doc.indexOf('Sandström') + 9);
    bench.dispose();
  });
}

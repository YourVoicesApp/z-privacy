// 046/N on the screen · the request, and the column that says what leaves.
//
// **The owner, 7 October:** «ليس لدينا شات — شات مع نموذج. بمعنى أنه إذا لدينا
// وثيقة مشفرة وكل شيء فيها تمام، ماذا يحصل عند الانتقال إلى الخطوة التالية؟
// نحتاج إلى نسخ الملف.»
//
// The core half is in `z_core/tests/the_question_travels_with_it.rs`. Here is
// the half a person touches, and the one assertion that matters most:
// **a name typed into the field is a token in the Safe column before anything
// is pressed.** The field does not scan itself — `setQuestion` hands the
// sentence to the core — so what this file proves is that the screen shows the
// core's answer and not its own.
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
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// A German letter with a person the salutation proves, so the document has a
/// token to lend the question.
const _doc = 'Ansprechpartner: Herr Thomas Müller\nBetrag: 42 500\n';

const _field = ValueKey<String>('workspace-question');
const _attach = ValueKey<String>('workspace-question-attach');

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

Future<(Ground, Workbench)> _open(WidgetTester tester, String name) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-ask-$name-$pid');
    if (here.existsSync()) here.deleteSync(recursive: true);
    addTearDown(() {
      if (here.existsSync()) here.deleteSync(recursive: true);
    });
    await z.setDataDir(dir: here.path);
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    // Every question answered, so the only thing under test is the request.
    for (final f in bench.suggested) {
      await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
    }
    await bench.refresh();
  });
  addTearDown(bench.dispose);
  await tester.pumpWidget(MaterialApp(
    home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
  ));
  await settle(tester);
  return (ground, bench);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a name typed into the request is a token in the Safe column', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'token');

    expect(find.text('What should the AI do with this?'), findsOneWidget,
        reason: 'there is no door to a model from the document');
    final before = bench.payload!.text;
    expect(before.contains('--- Request ---'), isFalse);

    await tester.enterText(find.byKey(_field), 'What did Thomas Müller earn?');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);

    final after = bench.payload!.text;
    expect(after, contains('--- Request ---'),
        reason: 'the request is not in the column that says what leaves');
    expect(after, isNot(contains('Thomas Müller')),
        reason: 'a name a person typed is in the column in the clear');
    // The **same** token the document gave him, or the model cannot see that
    // the question is about somebody in the sheet.
    final token = before
        .split(RegExp(r'\s+'))
        .firstWhere((w) => w.startsWith('__Z_'), orElse: () => '');
    expect(token, isNotEmpty, reason: 'the document protected nobody, so this proves nothing');
    expect(after.split('--- Request ---').last, contains(token),
        reason: 'the request minted a second token for one person');

    // And the screen says what the core did, with the core's own number.
    expect(find.textContaining('one value replaced'), findsOneWidget);
    expect(find.textContaining('not here yet'), findsOneWidget,
        reason: 'the screen promises a conversation it does not have');
  });

  testWidgets('taking the request out leaves the document as it was', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'out');
    final bare = bench.payload!.text;

    await tester.enterText(find.byKey(_field), 'Summarise it.');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);
    expect(bench.payload!.text, isNot(bare));

    await tester.tap(find.widgetWithText(ZButton, 'Take it out'));
    await settle(tester, rounds: 16);
    expect(bench.payload!.text, bare,
        reason: 'taking the request out left something behind in what leaves');
  });

  testWidgets('the act says whether the request is in yet, and never says «Send»', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'names');

    // Empty: the act is shut and says what an empty request means, because a
    // document may be sent with no instruction and that is not a failure.
    expect(
      tester.widget<ZButton>(find.widgetWithText(ZButton, 'Add it to what will leave')).onPressed,
      isNull,
    );
    expect(find.textContaining('no request'), findsOneWidget);

    await tester.enterText(find.byKey(_field), 'Summarise it.');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);

    // Once it is in, the act says so rather than offering to do it again.
    expect(find.text('In what will leave'), findsOneWidget);
    // **This press never sends.** The word is not on this control, because the
    // gate and the review are still the only way out.
    expect(find.widgetWithText(ZButton, 'Send'), findsNothing);
    expect(bench.question, 'Summarise it.');
  });
}

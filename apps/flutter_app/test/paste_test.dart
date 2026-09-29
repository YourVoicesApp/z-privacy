// P2-1 — «Paste AI answer» must actually paste.
//
// His framing of 29 September, and the line the tests are built around:
//
//     Paste is an act of **editing**, not of processing.
//
// So it fills a field and does nothing else: no answer, no restore, no vault
// write, no network — and, after F-05, no change to which payload the answer
// will be tied to.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/send_sheet.dart';

/// Stand in for the system clipboard. `null` is «nothing there»; throwing is
/// «the platform would not answer».
String? _clipboard;
bool _clipboardThrows = false;

void _installClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.getData') {
        if (_clipboardThrows) throw PlatformException(code: 'nope');
        return _clipboard == null ? null : <String, dynamic>{'text': _clipboard};
      }
      if (call.method == 'Clipboard.setData') return null;
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

/// A session with something to protect, and the sheet open on its AI page.
Future<Workbench> _sheet(WidgetTester tester, Ground ground) async {
  late final Workbench bench;
  await tester.runAsync(() async {
    final session = await z.openSession(profileId: null, packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: 'E-Mail: a.weber@nordstern.de');
    await bench.rescan();
    await ground.refresh();
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SendSheet(bench: bench, ground: ground)),
  ));
  await settle(tester);
  // Step past the review page to the three doors.
  await tester.tap(find.text('Continue'));
  await settle(tester);
  return bench;
}

void main() {
  setUpAll(() async => RustLib.init());
  setUp(() {
    _clipboard = null;
    _clipboardThrows = false;
  });

  testWidgets('Paste puts the clipboard in the field, exactly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installClipboard(tester);
    final ground = Ground();
    await _sheet(tester, ground);

    const answer = 'Hello __Z_1234_PERSON_ABCD__, your note is ready.';
    _clipboard = answer;
    await tester.tap(find.text('Paste AI answer'));
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, answer, reason: 'the field is not the clipboard');
  });

  testWidgets('Paste replaces what is already in the field', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installClipboard(tester);
    final ground = Ground();
    await _sheet(tester, ground);

    _clipboard = 'first answer';
    await tester.tap(find.text('Paste AI answer'));
    await settle(tester);

    _clipboard = 'second answer';
    await tester.tap(find.text('Paste AI answer'));
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'second answer',
        reason: 'the second paste appended instead of replacing');
  });

  testWidgets('an empty clipboard says so, and does not crash', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installClipboard(tester);
    final ground = Ground();
    await _sheet(tester, ground);

    _clipboard = null;
    await tester.tap(find.text('Paste AI answer'));
    await settle(tester);

    expect(find.text('There is no text on the clipboard.'), findsOneWidget);
    // The box still opens: they may want to type the answer by hand.
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('a clipboard that will not answer gives a sentence, not an exception',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installClipboard(tester);
    final ground = Ground();
    await _sheet(tester, ground);

    _clipboardThrows = true;
    await tester.tap(find.text('Paste AI answer'));
    await settle(tester);

    expect(find.text('Z Privacy could not read the clipboard.'), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
  });

  /// The one that matters after F-05: pressing Paste must not re-aim the
  /// answer at a different payload.
  testWidgets('Paste changes nothing but the field', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installClipboard(tester);
    final ground = Ground();
    final bench = await _sheet(tester, ground);

    // Copy first, which is what binds the answer to a payload.
    await tester.tap(find.text('Copy Protected'));
    await settle(tester);
    final bound = bench.copiedPayload;
    expect(bound, isNotNull, reason: 'copying did not bind a payload');

    _clipboard = 'an answer from some model';
    await tester.tap(find.text('Paste AI answer'));
    await settle(tester);

    expect(bench.copiedPayload, bound, reason: 'Paste re-aimed the answer at another payload');
    expect(bench.answers, isEmpty, reason: 'Paste created an answer by itself');
  });
}

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
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/bits.dart';
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

/// The workspace itself, without opening the sheet.
Future<Workbench> _sheetlessWorkspace(WidgetTester tester, Ground ground) async {
  late final Workbench bench;
  await tester.runAsync(() async {
    final session = await z.openSession(profileId: null, packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: 'E-Mail: a.weber@nordstern.de');
    await bench.rescan();
    await ground.refresh();
  });
  await tester.pumpWidget(MaterialApp(
    home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
  ));
  await settle(tester);
  return bench;
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

  _p22();
  _p23();

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

/// P2-2 — a button's name describes the act its own press causes.
///
/// His rule of 29 September, and a new member of the family we have been
/// hunting: the earlier lies were about **states** reported wrongly; this one
/// is about an **act** named for something two steps away.
void _p22() {
  testWidgets('the workspace offers Review, and sends nothing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installClipboard(tester);
    _clipboard = 'SENTINEL — the clipboard must not be written by Review';

    final ground = Ground();
    final bench = await _sheetlessWorkspace(tester, ground);

    // The door is named for what the press does.
    expect(find.text('Review what will leave'), findsOneWidget);
    expect(find.text('Send safe version'), findsNothing);
    // «Send» belongs only where a request really leaves. The rule is about
    // **controls**: the left column's caption «Send cannot read this side» is
    // prose about the app's own parts, not a promise about a press.
    final buttonWords = tester
        .widgetList<ZButton>(find.byType(ZButton))
        .map((b) => b.label)
        .toList();
    expect(
      buttonWords.where((l) => l.contains('Send')),
      isEmpty,
      reason: 'a button on the workspace promises a send: $buttonWords',
    );
    // And it is distinct from the suggestions «Review» in the left column.
    expect(find.text('Review'), findsOneWidget);

    await tester.tap(find.text('Review what will leave'));
    await settle(tester);

    // It opened the sheet — and did nothing else.
    expect(find.text('THIS IS WHAT WOULD LEAVE'), findsOneWidget);
    expect(bench.answers, isEmpty, reason: 'Review created an answer');
    expect(bench.copiedPayload, isNull, reason: 'Review bound a payload');
    final still = await Clipboard.getData(Clipboard.kTextPlain);
    expect(still?.text, startsWith('SENTINEL'), reason: 'Review wrote to the clipboard');
  });
}

/// P2-3 — the routes are named by what they mean to a person.
void _p23() {
  testWidgets('the three routes are Manual AI, Direct API and Local AI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installClipboard(tester);
    final ground = Ground();
    await _sheet(tester, ground);

    expect(find.text('Manual AI'), findsOneWidget);
    expect(find.text('Direct API'), findsOneWidget);
    expect(find.text('Local AI'), findsOneWidget);
    expect(find.textContaining('Use an AI chat you already have'), findsOneWidget);
    expect(find.textContaining('Runs through an AI service on this computer'), findsNothing);
    expect(find.textContaining('Use an AI service running on this computer'), findsOneWidget);

    // «OpenAI-compatible» is a protocol, and never the name of a route a
    // person picks. It does not belong on this sheet at all.
    expect(find.textContaining('OpenAI-compatible'), findsNothing);
  });

  /// «Local» is a promise about where the text goes, so the core decides it
  /// from the address — the same test the network door enforces.
  testWidgets('the core says whether an endpoint is on this computer', (tester) async {
    await tester.runAsync(() async {
      // Default is the remote OpenAI address.
      var facts = (await z.providerSnapshot()).providers;
      expect(facts.first.onThisComputer, isFalse,
          reason: 'a remote address was called local');

      await z.configureProvider(
        provider: const ProviderId(id: 'openai'),
        baseUrl: 'http://127.0.0.1:11434',
        model: 'llama3.2',
      );
      facts = (await z.providerSnapshot()).providers;
      expect(facts.first.onThisComputer, isTrue,
          reason: 'a loopback address was not called local');
      expect(facts.first.label, 'OpenAI-compatible',
          reason: 'the protocol is still reported for the settings screen');
    });
  });
}

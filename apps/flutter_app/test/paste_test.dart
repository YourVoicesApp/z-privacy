// P2-1 — «Paste AI answer» must actually paste.
//
// His framing of 29 September, and the line the tests are built around:
//
//     Paste is an act of **editing**, not of processing.
//
// So it fills a field and does nothing else: no answer, no restore, no vault
// write, no network — and, after F-05, no change to which payload the answer
// will be tied to.
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drawn_document.dart';
import 'package:flutter/material.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/widgets/connect_form.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/widgets/why_sheet.dart';

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
    home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
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
  _p24();
  _p27();

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

/// P2-4 — «Forget the key» may only stand where a key is held.
///
/// The local door's own text is «No key, no account», and it offered to forget
/// one. The cause was under the screen: the core answered «sealed in the vault»
/// for a login whose credential is empty, so both facts are pinned here — what
/// the core says, and what the form draws from it.
void _p24() {
  Future<ProviderFact> currentRow() async =>
      (await z.providerSnapshot()).providers.firstWhere((p) => p.id == 'openai');

  Future<void> showForm(WidgetTester tester, ProviderFact row, {required bool local}) async {
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConnectForm(ground: ground, row: row, local: local)),
    ));
    await settle(tester);
  }

  testWidgets('a model on this machine offers Disconnect, not «Forget the key»', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => z.disconnectProvider(provider: const ProviderId(id: 'openai')));

    late final ProviderFact row;
    await tester.runAsync(() async {
      await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
      await z.connectProvider(
        provider: const ProviderId(id: 'openai'),
        credential: '',
        baseUrl: 'http://127.0.0.1:11434',
        model: 'llama3.2',
      );
      row = await currentRow();
    });

    // The core first: connected, on this computer, holding nothing.
    expect(row.connected, isTrue);
    expect(row.onThisComputer, isTrue);
    expect(row.credentialState, CredentialState.missing,
        reason: 'a login with an empty credential claimed a home for a key');

    await showForm(tester, row, local: true);
    expect(find.text('Forget the key'), findsNothing,
        reason: 'the «No key, no account» door offered to forget a key');
    expect(find.text('Disconnect'), findsOneWidget,
        reason: 'a local connection could no longer be taken away');

    // The same address seen through the Direct API card — one provider, two
    // doors. Neither of them may promise to seal a key at an address that
    // needs none.
    await showForm(tester, row, local: false);
    expect(find.text('No key is needed at this address.'), findsOneWidget);
    expect(find.textContaining('sealed in the vault'), findsNothing,
        reason: 'the vault was said to hold a key that was never given');
    expect(find.text('Forget the key'), findsNothing);
  });

  testWidgets('a key that is held is still offered to be forgotten', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => z.disconnectProvider(provider: const ProviderId(id: 'openai')));

    late final ProviderFact row;
    await tester.runAsync(() async {
      await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
      await z.connectProvider(
        provider: const ProviderId(id: 'openai'),
        credential: 'sk-test-not-a-real-key',
        baseUrl: 'https://api.openai.com',
        model: 'gpt-4o-mini',
      );
      row = await currentRow();
    });

    expect(row.credentialState, isNot(CredentialState.missing));

    await showForm(tester, row, local: false);
    expect(find.text('Forget the key'), findsOneWidget,
        reason: 'a stored key cannot be taken away');
    expect(find.text('Disconnect'), findsNothing,
        reason: 'two words for one act, drawn at once');
  });

  testWidgets('nothing connected offers neither', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late final ProviderFact row;
    await tester.runAsync(() async {
      await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
      row = await currentRow();
    });

    expect(row.connected, isFalse);
    await showForm(tester, row, local: false);
    expect(find.text('Forget the key'), findsNothing);
    expect(find.text('Disconnect'), findsNothing);
    expect(find.text('Connect'), findsOneWidget);
  });
}

/// P2-7 — the last of the human run's P2 list.
///
/// The chip in the Safe column carried no gesture and never had: the defect was
/// that it **looked** like one. In this app `clayWash` inside a `clayEdge`
/// border is the costume of a chosen control — every selected language, every
/// on-state toggle, every picked scope wears it — and the chip wore it while
/// answering nothing, next to a column where the matching word really does
/// answer by opening «Why».
///
/// So this test pins exactly two things, and no third: the chip offers no press
/// and does not dress as though it did, and «Why» is reached from the Original
/// column. Nothing was added to the chip; nothing is expected of it.
void _p27() {
  testWidgets('a Safe-column chip is display only, and Why lives on the Original side',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const word = 'Nordstern Consulting GmbH';
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: 'Kunde: $word');
      await bench.rescan();
      // A suggestion is not a protection, and there is no «send anyway»: the
      // only way to a real token is to answer.
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

    // Control string first: without a token there is no chip to judge.
    expect(bench.tokens, isNotEmpty, reason: 'nothing was protected, so there is no chip');
    expect(bench.chips, isTrue, reason: 'the column is not drawing chips');

    // ------------------------------------------------ the chip: no press
    final chipLabel = find.descendant(
      of: find.byType(SafeText),
      matching: find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('Z_')),
    );
    expect(chipLabel, findsWidgets, reason: 'the Safe column drew no chip');

    // No span on the Safe side carries a tap, and none asks for the hand
    // cursor — the two ways this app makes text pressable.
    final safeSpan = tester
        .widget<SelectableText>(
          find.descendant(of: find.byType(SafeText), matching: find.byType(SelectableText)),
        )
        .textSpan!;
    safeSpan.visitChildren((span) {
      if (span is TextSpan) {
        expect(span.recognizer, isNull, reason: 'a Safe-column span became pressable');
        expect(span.mouseCursor, isNot(SystemMouseCursors.click),
            reason: 'a Safe-column span asks for the hand cursor');
      }
      return true;
    });
    // And the app's own tap primitive is nowhere above it.
    expect(find.ancestor(of: chipLabel.first, matching: find.byType(InkWell)), findsNothing);

    // ------------------------------------------------ the chip: no costume
    // The heart of his rule. A control state in this app is a fill **inside a
    // border**; a display-only chip is a highlight over text.
    final box = tester.widget<Container>(
      find.ancestor(of: chipLabel.first, matching: find.byType(Container)).first,
    );
    final skin = box.decoration! as BoxDecoration;
    expect(skin.border, isNull, reason: 'a bordered chip reads as a button');
    expect(skin.color, isNot(Zc.clayWash),
        reason: 'the chip is wearing the colour this app uses for a chosen control');

    // Pressing it changes nothing at all.
    final safeBefore = bench.payload!.text;
    final chipsBefore = bench.chips;
    await tester.tap(chipLabel.first);
    await settle(tester);
    expect(find.byType(WhySheet), findsNothing, reason: 'the chip opened something');
    expect(find.byType(Dialog), findsNothing, reason: 'the chip opened a dialog');
    expect(bench.payload!.text, safeBefore, reason: 'the chip changed what would leave');
    expect(bench.chips, chipsBefore);
    expect(bench.trouble, isNull, reason: 'the chip produced a complaint');

    // ------------------------------------------------ Why, on the other side
    final originalSpan = tester
        .widget<SelectableText>(
          find.descendant(of: find.byType(OriginalText), matching: find.byType(SelectableText)),
        )
        .textSpan!;
    TextSpan? marked;
    originalSpan.visitChildren((span) {
      if (span is TextSpan && span.text == word) marked = span;
      return true;
    });
    expect(marked, isNotNull, reason: 'the protected word is not its own span');
    expect(marked!.mouseCursor, SystemMouseCursors.click,
        reason: 'the one pressable thing does not say so to a pointer');

    // Pressed where it is drawn, the way a person presses it. Until 041-K/the
    // bubble task this reached into the span's own `TapGestureRecognizer` and
    // called it; the marks carry no recognizer any more, because inside a
    // `SelectableText` one is out-voted by the text's drag-selection the
    // moment a mouse slips two pixels. The press is a pointer event now, so
    // this test presses.
    final at = bench.document!.text.indexOf(word);
    // From the drawing, not from a painter built here — see
    // `drawn_document.dart`.
    final whereItIs = whereIsInDocument(tester, word, at, span: word.length);
    await tester.tapAt(whereItIs, kind: PointerDeviceKind.mouse);
    await settle(tester);
    expect(find.byType(WhySheet), findsOneWidget, reason: 'the Original mark did not open Why');
    expect(find.text('Why is this protected?'), findsOneWidget);
    expect(find.text(word), findsWidgets, reason: 'Why opened on the wrong word');
  });
}

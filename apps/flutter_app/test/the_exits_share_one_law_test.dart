// 083a · The three exits share one law — contract C3, closed on the app's side.
//
// The owner, 14 Oct 2026: **«a paragraph is not left until its words' fate is
// decided.»** Until this round that was true of one exit out of three.
//
// A send through a key refused with `OpenSuggestions` and the glass killed its
// own button as well (G12). Copy Protected and Save as PDF asked the core
// nothing at all: `beginThenRead` read `bench.payload` — the workspace
// snapshot's own payload, the text drawn in the Safe column — and handed it to
// the clipboard or to the PDF writer with the waiting word standing in it
// exactly as the person had written it. That is contract item C3, open since
// the contract was sealed, and this file is the measurement that closes it.
//
// ## What each guard measures, and where it stands
//
//   * **the clipboard**, through a probe that starts holding the person's own
//     letter — because the leak of 12 October was not what the app wrote, it
//     was what the app **left** (081);
//   * **the wire**, through a server in this process: the question the product
//     exists for is not «what did we hold» but «what left the machine»;
//   * **the folder**, for the PDF: a file either exists or it does not;
//   * **the review**, because rule 12 makes the refusal a guide: the panel is
//     open, walking, and lit on the first waiting word **in reading order**.
//
// ## What this file cannot measure
//
// **A widget callback that awaits the core does not resume under
// `testWidgets`.** With the law in the core every exit press now awaits a core
// call, so the presses are driven through the order's own helpers —
// `beginThenRead` and `beginThenAsk` — inside `tester.runAsync`, which is how
// every other order in this suite is measured. What the glass still answers
// for itself is asserted on the glass: that the presses are **live** while a
// word waits, since a refusal that cannot be pressed cannot guide anybody.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/send_sheet.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _wide = Size(1200, 1000);

/// A letter this build reads as **one** waiting word and two values protected
/// by the rules themselves — measured, not assumed: company suggested, person
/// and IBAN automatic. The fixture asserts all three, so a build that changes
/// its mind says so by name instead of quietly proving nothing.
const _company = 'Nordstern Consulting GmbH';
const _iban = 'DE89370400440532013000';
const _letter = 'Kunde: $_company\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: $_iban\n'
    'Wir bitten um eine Verlängerung des Zahlungsziels.';

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Directory _ownDir(String name) {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-onelaw-$name-$pid');
  if (own.existsSync()) own.deleteSync(recursive: true);
  addTearDown(() {
    if (own.existsSync()) own.deleteSync(recursive: true);
  });
  return own;
}

/// Captures clipboard writes — a widget test has no system clipboard.
///
/// The third copy of this instrument in this suite (`the_name_at_the_exit_test`
/// and `shell_test` hold the others, each private to its file). Named as the
/// same debt they name: the right home is a `test/support/` this suite does not
/// have, and inventing that structure inside this round would be picking a
/// surface nobody asked for.
class _ClipboardProbe {
  _ClipboardProbe(this.tester);

  final WidgetTester tester;
  String? text = 'SENTINEL';
  final List<String?> wrote = <String?>[];

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
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }
}

/// A bench on the letter with its word still waiting, a vault, a provider whose
/// endpoint is a server in this process, and a folder for the PDF.
///
/// `bodies` is what left the machine, in order — empty is the whole of guard 3.
Future<({Workbench bench, Ground ground, List<String> bodies, Directory out})> _waiting(
  String name, {
  String text = _letter,
}) async {
  final own = _ownDir(name);
  final out = _ownDir('$name-pdf')..createSync(recursive: true);
  final ground = Ground();
  // **Lock first.** The vault state is global to the isolate, so an earlier
  // test in this file can leave one unlocked.
  await z.vaultLock();
  await z.setDataDir(dir: own.path);
  await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för en lag');
  final session = await z.openSession(profileId: null, packId: 'de');
  final bench = Workbench(session: session, profileId: null, packId: 'de');
  await z.importText(session: session, text: text);
  await bench.rescan();

  final bodies = <String>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    bodies.add(await utf8.decodeStream(req));
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'Verstanden.'},
          },
        ],
      }));
    await req.response.close();
  });
  await z.connectProvider(
    provider: const ProviderId(id: 'openai'),
    credential: 'sk-test-not-a-real-credential',
    baseUrl: 'http://127.0.0.1:${server.port}',
    model: 'the-configured-one',
  );
  await ground.refresh();
  addTearDown(() async {
    await server.close(force: true);
    await z.disconnectProvider(provider: const ProviderId(id: 'openai'));
  });
  return (bench: bench, ground: ground, bodies: bodies, out: out);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // **The clipboard.** The probe starts holding the letter itself, which is how
  // the owner's leak happened: he had copied it minutes earlier, the app
  // refused quietly, and the original was still there to be pasted into a
  // model. So the subject is not what the app wrote — it is what a paste reads.
  testWidgets('Copy Protected puts nothing out while a word waits, and the review opens on it',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    probe.text = _letter;
    late final ({Workbench bench, Ground ground, List<String> bodies, Directory out}) g;
    await tester.runAsync(() async {
      g = await _waiting('copy');
    });

    // The fixture, named: one word waiting and two values already protected.
    expect(g.bench.suggested, hasLength(1),
        reason: 'the fixture must leave exactly one word waiting');
    expect(g.bench.tokens, isNotEmpty,
        reason: 'nothing is protected by itself, so there is no control string');
    expect(g.bench.payload?.text, contains(_company),
        reason: 'the waiting word is not in the Safe column, so there was nothing to leak');

    // **Since rule 55 the document brought a session with it** (16 October):
    // it was born as the text entered the preview. So what this guard asks is
    // the thing it always meant — the refused press added nothing — and it
    // asks it by counting on both sides of the press.
    final before = (await tester.runAsync(() => z.conversations()))!.length;

    final out = await tester.runAsync(() => beginThenRead(g.ground, g.bench));

    expect(out!.view, isNull, reason: 'the exit handed out text while a word waited');
    expect(out.refused, contains('nothing left Z'),
        reason: 'the refusal does not say that nothing left: ${out.refused}');
    expect(out.refused, contains('One word waits'),
        reason: 'the refusal does not name what is waiting: ${out.refused}');

    // What a person would now paste: nothing. Not «the old letter», which is
    // what a quiet refusal used to leave them with.
    expect(probe.text, '',
        reason: 'the clipboard holds ${probe.text?.length} characters after a refused exit');
    expect(probe.text, isNot(contains(_company)));
    expect(probe.wrote, [''],
        reason: 'the one write of a refused press is the emptying: ${probe.wrote}');

    // **A refusal is a guide** — rule 12. The review is open, walking, and lit
    // on the word that is waiting.
    expect(g.bench.panel, OpenPanel.review, reason: 'the refusal opened no review');
    expect(g.bench.walking, isTrue, reason: 'the review opened on a list, not on the word');
    expect(g.bench.focused, g.bench.suggested.single.id,
        reason: 'the review is open on another word than the one waiting');

    // And nothing was created on the way: a press that takes nothing out
    // leaves nothing behind it either.
    final rows = await tester.runAsync(() => z.conversations());
    expect(rows, hasLength(before),
        reason: 'a refused exit began a session the person never got anything out of: $rows');
  });

  // ----------------------------------------------------------------- guard 1b
  //
  // **The sheet gets out of the way** — the lead's ruling of 14 Oct on rule 12:
  // «a sheet standing in front of the lit word is a wall». So the press takes
  // nothing out, the sheet closes, the sentence is said on the workspace's own
  // line, and the person lands on the word.
  //
  // A real press, and it resumes: the core call inside it completes in
  // `_settle`'s `runAsync` windows, which is also how `the_name_at_the_exit`'s
  // two presses are measured.
  testWidgets('the refused press closes the sheet and says it where the word is',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    probe.text = _letter;
    late final ({Workbench bench, Ground ground, List<String> bodies, Directory out}) g;
    await tester.runAsync(() async {
      g = await _waiting('sheet');
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ZButton(
            label: 'Open it',
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => SendSheet(
                bench: g.bench,
                ground: g.ground,
                saveFolder: g.out.path,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open it'));
    await _settle(tester);
    expect(find.byType(SendSheet), findsOneWidget, reason: 'the sheet never opened');

    await tester.tap(find.text('Copy Protected'));
    await _settle(tester, rounds: 16);

    expect(find.byType(SendSheet), findsNothing,
        reason: 'the sheet stands in front of the word it is telling the person about');
    expect(probe.text, '', reason: 'the press left something on the clipboard');
    expect(probe.text, isNot(contains(_company)));
    expect(
      g.bench.trouble,
      'One word waits for your answer — nothing left Z.\n'
      'Nothing was copied — the clipboard is empty.',
      reason: 'the news is not where the person landed: ${g.bench.trouble}',
    );
    expect(g.bench.panel, OpenPanel.review);
    expect(g.bench.focused, g.bench.suggested.single.id);
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **The glass does not carry its own copy of the law.** The presses stay
  // live, because a refusal that cannot be pressed cannot open the review —
  // rule 12. The one wall left standing is Direct Mode's, and it is named here
  // so that nobody removes it by accident: that door sends the document **as
  // it stands** and `ask_model_directly` asks no law, so a press there while a
  // word waits would put the clear text on the wire.
  testWidgets('the exits are pressable while a word waits, and Direct Mode is not',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final ({Workbench bench, Ground ground, List<String> bodies, Directory out}) g;
    await tester.runAsync(() async {
      g = await _waiting('glass');
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SendSheet(bench: g.bench, ground: g.ground, saveFolder: g.out.path),
      ),
    ));
    await _settle(tester);

    for (final label in ['Copy Protected', 'Save as PDF']) {
      expect(
        tester.widget<ZButton>(find.widgetWithText(ZButton, label)).onPressed,
        isNotNull,
        reason: '$label is dead while a word waits, so the refusal can guide nobody',
      );
    }
    final sends = find.byWidgetPredicate(
      (w) => w is ZButton && (w.label.startsWith('Send to') || w.label == 'Send'),
    );
    expect(sends, findsWidgets, reason: 'no send door is on the glass at all');
    expect(
      tester.widgetList<ZButton>(sends).every((b) => b.onPressed != null),
      isTrue,
      reason: 'the protected send is dead while a word waits — the glass is '
          'carrying a copy of the law the core now holds',
    );
    // And it says nothing about the count beside a press that will say it
    // itself: one state, one wording (046/L).
    expect(find.textContaining('still waits'), findsNothing,
        reason: 'the sheet words the waiting word a second time, beside a '
            'press whose refusal words it from messages.dart');

    // The one wall: Direct Mode. Chosen through the method the chip calls —
    // `chooseOriginal` is the product's own door and notifies, where writing
    // the field would leave the glass drawing the old answer. The chip itself
    // sits below this sheet's fold, and reaching it is another file's subject.
    g.bench.chooseOriginal(true);
    await _settle(tester);
    expect(g.bench.sendOriginal, isTrue, reason: 'the mode was not chosen');
    // The wall names itself where it stands, and nowhere else.
    expect(find.textContaining('still waits'), findsOneWidget,
        reason: 'the one dead door does not say why it is dead');
    expect(
      tester.widgetList<ZButton>(sends).every((b) => b.onPressed == null),
      isTrue,
      reason: 'Direct Mode is pressable while a word waits, and it sends the '
          'document as it stands',
    );
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The wire.** The one exit that actually puts text on a socket, measured at
  // the socket: nothing crossed it.
  test('the send puts nothing on the wire while a word waits', () async {
    final g = await _waiting('wire');
    // The document's own session, born as it entered the preview (rule 55);
    // what this guard asks is that the refused send adds none.
    final before = (await z.conversations()).length;
    final out = await beginThenAsk(g.ground, g.bench, providerId: 'openai');
    expect(out.refused, isNotNull, reason: 'the send was not refused at all');
    expect(out.refused, contains('nothing left Z'));
    expect(g.bodies, isEmpty, reason: 'a request crossed the wire while a word waited');
    expect(await z.conversations(), hasLength(before),
        reason: 'the refused send began a session anyway');
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **Answer it, and all three open.** The same presses, nothing else changed —
  // which is what makes the refusal a step in the work rather than a wall.
  test('one answer opens the clipboard, the file and the wire', () async {
    final g = await _waiting('answered');
    final waiting = g.bench.suggested.single;
    await z.answerFinding(
      session: g.bench.session,
      finding: waiting.id,
      answer: FindingAnswer.protect,
    );
    await g.bench.refresh();
    expect(g.bench.suggested, isEmpty);

    // The clipboard's text and the PDF's text are one read — the helper both
    // presses call.
    final may = await beginThenRead(g.ground, g.bench);
    expect(may.refused, isNull, reason: 'the exit still refuses: ${may.refused}');
    expect(may.view, isNotNull);
    expect(may.view!.text, isNot(contains(_company)),
        reason: 'the word that was waiting left in the clear after being protected');
    expect(may.view!.text, isNot(contains(_iban)));
    expect(may.view!.text, contains('Verlängerung'),
        reason: 'the text that may leave is not the letter at all — the control');
    expect(may.view!.openSuggestions, 0);

    // And the wire: one request, carrying tokens and no value.
    final sent = await beginThenAsk(g.ground, g.bench, providerId: 'openai');
    expect(sent.refused, isNull, reason: 'the send still refuses: ${sent.refused}');
    expect(g.bodies, hasLength(1), reason: 'nothing crossed the wire');
    expect(g.bodies.single, isNot(contains(_company)));
    expect(g.bodies.single, isNot(contains(_iban)));
  });

  // ------------------------------------------------------------------ guard 5
  //
  // **The first waiting word is the first one in reading order.**
  //
  // The core hands findings back in the order its layers found them
  // (`ops::list_findings` walks `session.findings`), which is the scan's order
  // and not the eye's. In this build's fixtures the two agree — which is
  // exactly the shape that lets a wrong one stand for a year — so this guard
  // hands the function a list in which they do not.
  test('the review opens on the first waiting word in reading order', () {
    Finding at(int id, int start, MarkState state) => Finding(
          id: id,
          span: Span(start: start, end: start + 5),
          kind: Kind.person,
          source: Source.languagePack,
          decided: false,
          reason: 'r',
          state: state,
          entities: const [],
          occurrences: 1,
        );

    // Found last, standing first — and a protected one in front of both, which
    // is not an answer anybody is waiting for.
    final findings = [
      at(1, 400, MarkState.protected),
      at(2, 300, MarkState.suggested),
      at(3, 120, MarkState.suggested),
    ];
    expect(theFirstWaitingWord(findings)?.id, 3,
        reason: 'the review opens on the word the scan found first, not the one '
            'the eye reads first');
    expect(theFirstWaitingWord([at(1, 10, MarkState.protected)]), isNull,
        reason: 'a document with nothing waiting has no word to open on');
    expect(theFirstWaitingWord(const []), isNull);
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **The number in the sentence is the number of words.** Two waiting, and the
  // line the person reads says two.
  test('the refusal names how many words are waiting', () async {
    final g = await _waiting(
      'two',
      text: 'Kunde: $_company\n'
          'Ansprechpartner: Herr Thomas Müller\n'
          'Auftraggeber: Südwind Logistik GmbH\n'
          'IBAN: $_iban\n'
          'Wir bitten um eine Verlängerung des Zahlungsziels.',
    );
    expect(g.bench.suggested, hasLength(2), reason: 'the fixture leaves two words waiting');
    final out = await beginThenRead(g.ground, g.bench);
    expect(out.refused, '2 words wait for your answer — nothing left Z.');
  });
}

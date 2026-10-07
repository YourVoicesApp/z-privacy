// 046/O — «Save as PDF»: the file on the disk carries the protected text and
// not one original value.
//
// The owner, 7 October: «زرُّ النسخ نحافظ عليه كما هو، ونضيف إليه خيار نسخة PDF
// ليقوم التطبيق بحفظ النص في الجهاز كملف PDF.» Copy Protected is untouched; a
// second act stands beside it and writes a file. Neither sends anything.
//
// ## Why this test is not a byte search over the file
//
// A PDF that embeds a TrueType font writes its text as **glyph indices** in a
// CID font (`/Type0`, `/Encoding /Identity-H`), not as readable characters. So
// `grep` finds «Markus Weber» nowhere in the file even when the page shows it in
// full, compressed or not. A guard built on that search is green for a reason
// that has nothing to do with protection — the family named in
// `a_guard_green_for_the_wrong_reason`.
//
// `the byte search cannot see a value even when it is there` below proves it: it
// writes a PDF with an original in the clear, uncompressed, and shows the byte
// search still does not find it. **That is the test the requirement asks for,
// and it is the test that must not be believed.** It is kept because the next
// person to touch this file will reach for it.
//
// So the file is read back the way a reader reads it, and the reader is our own:
// `z_core::documents::pdf`, which decodes `Identity-H` through the font's own
// `/ToUnicode` map. Seven tests, and the first two are the instrument rather
// than the subject:
//
//   * the control — an original written in the clear **is** found by that
//     reader, so the reader is not blind and an absence it reports means
//     something;
//   * the byte search, kept and shown not to work;
//   * the promise — the real payload's PDF yields no original value, while the
//     reader does yield the tokens whole, so the file is not simply empty;
//   * the paging, because a real document is not one page and the footer is
//     the page's;
//   * the way back, the refusal, and the folder.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/protected_pdf.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/send_sheet.dart';

/// A sha256-shaped string that is not one: the control's footer must carry
/// something of the right length without pretending to be a real digest.
final _zeroes = '0' * 64;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// A German letter whose findings are every one of them automatic. No `GmbH`
/// line: a company by its legal form is **offered**, and an open suggestion
/// would leave a real value standing in the payload — which this test would
/// then read as a leak when it is the fixture's fault.
const _letter =
    'Sehr geehrter Herr Markus Weber,\n'
    'Geboren am 3.4.1978, Steuernummer 151/815/08154\n'
    'IBAN: DE89370400440532013000\n'
    'Telefon: 0211 4567890\n'
    'Mit freundlichen Grüßen\n';

/// Every original the letter contains, including the halves of a name that is
/// protected whole — if «Weber» came back alone the promise is broken.
const _originals = <String>[
  'Markus Weber',
  'Markus',
  'Weber',
  '3.4.1978',
  '151/815/08154',
  'DE89370400440532013000',
  '0211 4567890',
];

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// What our own PDF reader gets out of these bytes, with runs of whitespace
/// collapsed to one space. The product's reader, on the product's own file —
/// `kind: pdf`, so no guessing is involved.
///
/// **The collapse is the point, not a convenience.** A PDF positions each word
/// separately, so the reader hands back one word per line and a raw search for
/// «Markus Weber» would miss it while a person reading the page sees it plainly.
/// Searching the flattened text is therefore the *stronger* test: a value
/// counts as readable when its characters come back in order, however the page
/// broke them. It is also what keeps the token check meaningful — a token split
/// across two lines comes back with a space inside it and is not found.
Future<String> readBack(Uint8List bytes) async =>
    (await readView(bytes)).text.replaceAll(RegExp(r'\s+'), ' ');

/// The whole view, when the page count is the thing being asked about.
Future<DocumentView> readView(Uint8List bytes) async {
  final session = await z.openSession(profileId: null, packId: 'de');
  final view = await z.importDocument(
    session: session,
    name: 'read-back.pdf',
    bytes: bytes,
    kind: DocumentKind.pdf,
  );
  await z.closeSession(session: session);
  return view;
}

void main() {
  late Directory data;
  late Directory out;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    // The asset bundle and the platform channels, before anything asks for
    // them: the embedded font is read through `rootBundle`.
    TestWidgetsFlutterBinding.ensureInitialized();
    await RustLib.init();
    data = Directory('${Directory.systemTemp.path}/zprivacy-pdf-data-$pid');
    out = Directory('${Directory.systemTemp.path}/zprivacy-pdf-out-$pid');
    for (final d in [data, out]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
      d.createSync(recursive: true);
    }
    await z.setDataDir(dir: data.path);
  });

  tearDownAll(() {
    for (final d in [data, out]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  // ------------------------------------------------------------------ control
  //
  // Before the promise is tested, the instrument is tested. If this one ever
  // fails, the promise below proves nothing at all.
  test('the control: an original written in the clear is found by our own reader', () async {
    final bytes = await buildProtectedPdf(
      text: 'Sehr geehrter Herr Markus Weber,\nIBAN: DE89370400440532013000\n',
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 0,
        byKind: <String, int>{},
        sha256: _zeroes,
      ),
    );
    final text = await readBack(bytes);
    expect(text, contains('Markus Weber'),
        reason: 'our reader cannot read our own PDF, so no absence it reports means anything');
    expect(text, contains('DE89370400440532013000'));
  });

  test('the byte search cannot see a value even when it is there', () async {
    // Uncompressed on purpose — the requirement's own suggestion, shown here to
    // be insufficient rather than taken on trust. The text is glyph indices;
    // removing the Flate layer does not make it letters.
    final bytes = await buildProtectedPdf(
      text: 'Sehr geehrter Herr Markus Weber,\n',
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 0,
        byKind: <String, int>{},
        sha256: _zeroes,
      ),
      compress: false,
    );
    expect(String.fromCharCodes(bytes).contains('/FlateDecode'), isFalse,
        reason: 'this file was asked for uncompressed and is not');
    expect(String.fromCharCodes(bytes).contains('Markus Weber'), isFalse,
        reason: 'if a byte search ever starts working, this comment is wrong and '
            'the search may be trusted again');
    // And the reader, on the same bytes, does see it.
    expect(await readBack(bytes), contains('Markus Weber'));
  });

  // ------------------------------------------------------------------ the promise
  testWidgets('the saved file carries the tokens and no original value', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _letter);
      await bench.rescan();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SendSheet(bench: bench, ground: ground, saveFolder: out.path)),
    ));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(bench.openSuggestions, 0,
        reason: 'the fixture asks something, so an original still stands in the payload '
            'and this test would blame the file for the fixture');
    final payload = bench.payload!;
    expect(payload.protectedCount, greaterThan(0), reason: 'nothing was protected at all');
    final tokens = bench.tokens.map((t) => t.token).toList();
    expect(tokens, isNotEmpty);

    expect(find.text('Save as PDF'), findsOneWidget, reason: 'there is no second act');
    await tester.tap(find.text('Save as PDF'));
    await settle(tester, rounds: 16);

    final written = out.listSync().whereType<File>().toList();
    expect(written, hasLength(1), reason: 'the press wrote ${written.length} files');
    final file = written.single;
    expect(file.path, endsWith('.pdf'));

    // 5 — it said where it went, and said it on the screen.
    expect(find.textContaining(file.path), findsOneWidget,
        reason: 'the file was written without a word about where');

    // **Every one of these crosses to native code**, and a `testWidgets` body
    // runs on a replaced clock: an await on one of them here waits for a turn
    // of the real loop that this body never gives, and `--timeout` cannot fire
    // because the isolate is blocked outside Dart. Measured on 3 October in
    // another product: eleven minutes, zero CPU, blocked in `ep_poll`.
    late final String back;
    await tester.runAsync(() async => back = await readBack(await file.readAsBytes()));

    // 4 — the promise. Not one original value, by our own reader.
    for (final original in _originals) {
      expect(back.contains(original), isFalse, reason: '«$original» is readable in the PDF');
    }
    // And the file is not merely empty: every token came back, and whole. A
    // token split by a line break would restore as nothing.
    for (final token in tokens) {
      expect(back, contains(token), reason: '«$token» did not survive the page');
    }

    // 3 — the footer states only what can be checked.
    expect(back, contains(payload.protectedCount.toString()));
    expect(back, contains(sha256OfText(payload.text)));
    expect(back, contains('z_core '));
    for (final brand in ['Z Privacy', 'Serial', 'Seal', 'Certified', 'Verified']) {
      expect(back.contains(brand), isFalse, reason: '«$brand» is decoration, not evidence');
    }
  });

  // A real document is not one page. `TextOverflow.span` is what lets the body
  // flow, and the footer is the page's, not the document's — a stamp on page
  // one and nothing after it would leave fifty pages with no provenance and a
  // reader with no way to tell a loose page came from this file.
  test('a long document pages itself, and every page carries the footer', () async {
    final line = 'Sehr geehrter Herr __Z_0000_PERSON_0000__, hier steht ein Satz, '
        'der lang genug ist, um eine Zeile zu füllen und die Seite zu füllen.\n';
    final digest = sha256OfText(line * 120);
    final bytes = await buildProtectedPdf(
      text: line * 120,
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 120,
        byKind: const <String, int>{'Person': 1},
        sha256: digest,
      ),
    );
    final view = await readView(bytes);
    expect(view.pages, greaterThan(1), reason: 'a text of 120 lines came out as one page');
    final stamps = digest.allMatches(view.text.replaceAll(RegExp(r'\s+'), '')).length;
    expect(stamps, view.pages,
        reason: 'the footer is on $stamps of ${view.pages} pages');
    // And the last line survived the paging, so nothing was dropped at a break.
    expect(view.text.replaceAll(RegExp(r'\s+'), ' '), contains('die Seite zu füllen.'));
  });

  // ------------------------------------------------------------- the way back
  //
  // 6 says the two acts read as what they are, and the door says «Restoring
  // works the same either way». It does not, unless taking the text out by this
  // door binds the answer to this payload the way the clipboard does:
  // `pasteAnswer` refuses with «Copy the safe text first» when nothing is
  // bound, and a person who saved a PDF, took it to a model and came back would
  // be told to do something they just did.
  testWidgets('an answer can be pasted back after a save, not only after a copy', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _letter);
      await bench.rescan();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SendSheet(bench: bench, ground: ground, saveFolder: out.path)),
    ));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // Save, and **do not** copy.
    await tester.tap(find.text('Save as PDF'));
    await settle(tester, rounds: 16);
    expect(find.textContaining('Saved to'), findsOneWidget);

    final answer = bench.payload!.text.replaceFirst('Sehr geehrter', 'Antwort an');
    late final String? refusal;
    await tester.runAsync(() async => refusal = await bench.pasteAnswer(answer));
    expect(refusal, isNull,
        reason: 'the answer could not come back through the door it went out of');
  });

  // A save that cannot happen must say so and give the button back.
  //
  // **This test was green with the disk's own catch deleted**, because the
  // catch-all below it answers too and its sentence also contains «could not».
  // So it asserted «a failure is reported» while claiming to assert «the disk's
  // failure is reported by name» — green for a broader reason than its own
  // subject. What makes the two branches different is the sentence a person
  // reads, so that is what is asserted: the folder it could not write into.
  testWidgets('a save that cannot happen says so, and the button comes back', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _letter);
      await bench.rescan();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // A folder under a file: it cannot be made, and it is not /proc or
        // anything else the machine might one day allow.
        body: SendSheet(bench: bench, ground: ground, saveFolder: '$_libPath/nowhere'),
      ),
    ));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    await tester.tap(find.text('Save as PDF'));
    await settle(tester, rounds: 16);

    expect(find.textContaining('Saved to'), findsNothing, reason: 'it claims a file it has not got');
    expect(find.textContaining('could not write into $_libPath/nowhere'), findsOneWidget,
        reason: 'the refusal does not name the folder, so it cannot be acted on');
    expect(find.text('Save as PDF'), findsOneWidget, reason: 'the button is still «Saving…»');
    expect(bench.copiedPayload, isNull, reason: 'a refusal bound a payload nothing took');
  });

  test('the stated folder is the one the owner was told', () {
    expect(protectedPdfFolder(), '${Platform.environment['HOME']}/Documents/zprivacy');
  });
}

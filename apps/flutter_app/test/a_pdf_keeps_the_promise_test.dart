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
  late Directory arabicOut;

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
    arabicOut = Directory('${Directory.systemTemp.path}/zprivacy-pdf-ar-$pid');
    for (final d in [data, out, arabicOut]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
      d.createSync(recursive: true);
    }
    await z.setDataDir(dir: data.path);
  });

  tearDownAll(() {
    for (final d in [data, out, arabicOut]) {
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

  // ------------------------------------------- 046/R · Arabic, written to be read
  //
  // The owner: «وأفرح إذا حسمنا مشكلة اللغة العربية». The refusal that stood
  // here is gone, because the page is right — rendered and looked at, not
  // inferred from a test that did not throw.
  //
  // **What distinguishes a right page from a mirrored one, measured.** Our own
  // reader walks the content stream, and dart_pdf emits words into it in
  // logical order whatever the direction — so the Latin islands come back at
  // the *same* indices either way and an order assertion over them cannot tell
  // the two apart. What does tell them apart is the glyphs: a shaped,
  // bidi-ordered page is written in Arabic **presentation forms**
  // (U+FB50..U+FEFF) and an unshaped one in **base letters** (U+0620..U+064A).
  // Measured on 7 October: 20 presentation / 0 base when the direction is set,
  // 0 presentation / 20 base when it is not.
  final shaped = RegExp(r'[\uFB50-\uFDFF\uFE70-\uFEFF]');
  final unshaped = RegExp(r'[\u0620-\u064A]');

  const arabicLine = 'رقم الحساب: __Z_0001_IBAN_0003__ والمبلغ 1,250.00 يورو';
  const germanLine = 'Sehr geehrter Herr __Z_0001_PERSON_0002__, Grüßen aus Köln.';

  test('an Arabic paragraph is shaped and laid out right to left', () async {
    final bytes = await buildProtectedPdf(
      text: arabicLine,
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 1,
        byKind: const <String, int>{'IBAN': 1},
        sha256: _zeroes,
      ),
    );
    final back = await readBack(bytes);
    expect(shaped.hasMatch(back), isTrue,
        reason: 'no Arabic presentation form in the file, so nothing was shaped');
    expect(unshaped.hasMatch(back), isFalse,
        reason: 'base Arabic letters are in the file, so the bidi pass never ran '
            'and the page is mirrored');
  });

  test('a Latin run inside an Arabic line is not reversed', () async {
    final bytes = await buildProtectedPdf(
      text: arabicLine,
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 1,
        byKind: const <String, int>{'IBAN': 1},
        sha256: _zeroes,
      ),
    );
    final back = await readBack(bytes);
    // **The part that goes wrong quietly.** A token or an amount swept up in
    // the reversal comes out backwards and restores as nothing, while the page
    // still looks like Arabic to anyone who cannot read it.
    expect(back, contains('__Z_0001_IBAN_0003__'),
        reason: 'the token did not survive the right-to-left run whole');
    expect(back, contains('1,250.00'), reason: 'the amount was reversed');
    expect(back.contains('00.052,1'), isFalse);
    expect(back.indexOf('__Z_0001_IBAN_0003__'), lessThan(back.indexOf('1,250.00')),
        reason: 'the two Latin islands swapped places');
  });

  test('a Latin-only page is untouched by the Arabic work', () async {
    final bytes = await buildProtectedPdf(
      text: 'Sehr geehrter Herr __Z_0001_PERSON_0002__,\n$germanLine\nRäksmörgås å ä ö.',
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 1,
        byKind: const <String, int>{'Person': 1},
        sha256: _zeroes,
      ),
    );
    final back = await readBack(bytes);
    expect(shaped.hasMatch(back), isFalse, reason: 'a German page was shaped');
    // Order, which is the thing a reordering fix would break.
    expect(back.indexOf('Sehr'), lessThan(back.indexOf('Grüßen')));
    expect(back.indexOf('Grüßen'), lessThan(back.indexOf('Köln')));
    expect(back.indexOf('Köln'), lessThan(back.indexOf('Räksmörgås')));
    expect(back, contains('__Z_0001_PERSON_0002__'));
  });

  test('direction is per paragraph, not per file', () async {
    // The real shape of a client's document: a German line, an Arabic line and
    // a German line again. One setting for the file gets one of them wrong.
    final bytes = await buildProtectedPdf(
      text: '$germanLine\n$arabicLine\nMit freundlichen Grüßen',
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 2,
        byKind: const <String, int>{'Person': 1, 'IBAN': 1},
        sha256: _zeroes,
      ),
    );
    final back = await readBack(bytes);
    expect(shaped.hasMatch(back), isTrue, reason: 'the Arabic line was not shaped');
    expect(unshaped.hasMatch(back), isFalse, reason: 'the Arabic line is mirrored');
    expect(back.indexOf('Sehr'), lessThan(back.indexOf('Mit freundlichen')),
        reason: 'the German lines were reordered by the Arabic line beside them');
    expect(back, contains('__Z_0001_PERSON_0002__'));
    expect(back, contains('__Z_0001_IBAN_0003__'));
  });

  test('the direction of a paragraph is its own first strong letter', () {
    expect(paragraphIsRightToLeft('Sehr geehrter Herr'), isFalse);
    expect(paragraphIsRightToLeft('السيد المحترم'), isTrue);
    expect(paragraphIsRightToLeft('שלום'), isTrue, reason: 'Hebrew is right to left too');
    // A number first does not decide: the first **strong** letter does, which
    // is the Unicode rule and not a rule of ours.
    expect(paragraphIsRightToLeft('1,250.00 يورو'), isTrue);
    // **And a token does not decide either**, though its letters are Latin and
    // strong. We put it there. If it voted, protecting the first name on an
    // Arabic line would lay that line out left to right, and the document
    // would read differently after protection than before it.
    expect(paragraphIsRightToLeft('__Z_0001_IBAN_0003__ والمبلغ'), isTrue);
    expect(paragraphIsRightToLeft('__Z_0001_IBAN_0003__ und mehr'), isFalse);
    expect(paragraphIsRightToLeft('__Z_0001_PERSON_0002__'), isFalse,
        reason: 'a line that is only a token has no direction of its own');
    // Nothing strong at all is left to right, as the algorithm says.
    expect(paragraphIsRightToLeft('1,250.00 — 42 %'), isFalse);
    expect(paragraphIsRightToLeft(''), isFalse);
  });

  // Found by rendering a letter and looking at it, not by a test: with a blank
  // line counted as left to right, an Arabic passage was cut into three blocks
  // and its blank lines vanished from the page. A neutral line has no opinion
  // and must take the one around it.
  test('a blank line inside a passage does not break it in two', () {
    expect(paragraphDirection(''), isNull);
    expect(paragraphDirection('   '), isNull);
    expect(paragraphDirection('1,250.00 — 42 %'), isNull);
    expect(paragraphDirection('__Z_0001_PERSON_0002__'), isNull,
        reason: 'a line that is only a token is ours, so it has no direction');
    expect(paragraphDirection('السيد'), isTrue);
    expect(paragraphDirection('Sehr'), isFalse);

    expect(
      directionBlocks('السيد المحترم\n\nمع خالص التحية'),
      const [DirectionBlock(true, 'السيد المحترم\n\nمع خالص التحية')],
      reason: 'the blank line split the Arabic passage in two',
    );
    expect(
      directionBlocks('Sehr geehrter Herr,\n\nMit freundlichen Grüßen'),
      const [DirectionBlock(false, 'Sehr geehrter Herr,\n\nMit freundlichen Grüßen')],
      reason: 'a document with no Arabic in it is no longer one block, so its '
          'page is not the page it was before this existed',
    );
    expect(
      directionBlocks('Sehr geehrter Herr,\n\nالسيد المحترم\n\nMit Grüßen'),
      const [
        DirectionBlock(false, 'Sehr geehrter Herr,\n'),
        DirectionBlock(true, 'السيد المحترم\n'),
        DirectionBlock(false, 'Mit Grüßen'),
      ],
      reason: 'the blank lines went to the wrong side of the change',
    );
    // Leading neutral lines wait for the first paragraph that has a direction.
    expect(directionBlocks('\n\nالسيد'), const [DirectionBlock(true, '\n\nالسيد')]);
  });

  // Paging is the thing the Partition wrapper could have cost: a Column with
  // `stretch` gives the same tight width and threw `PdfTooBigPageException`
  // here, because it does not hand `canSpan` through to its child.
  test('a long Arabic document pages itself too', () async {
    final line = 'نحيطكم علماً بأننا استلمنا المستندات الخاصة بالسنة المالية '
        'المنصرمة وقد تمت مراجعتها بالكامل من قبل الفريق المختص.\n';
    final digest = sha256OfText(line * 120);
    final bytes = await buildProtectedPdf(
      text: line * 120,
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 0,
        byKind: const <String, int>{},
        sha256: digest,
      ),
    );
    final view = await readView(bytes);
    expect(view.pages, greaterThan(1), reason: '120 Arabic lines came out as one page');
    final stamps = digest.allMatches(view.text.replaceAll(RegExp(r'\s+'), '')).length;
    expect(stamps, view.pages, reason: 'the footer is on $stamps of ${view.pages} pages');
    expect(shaped.hasMatch(view.text), isTrue, reason: 'the pages are not shaped');
    expect(unshaped.hasMatch(view.text), isFalse, reason: 'the pages are mirrored');
  });

  // The bidi library decides the base direction for itself, by the same
  // first-strong rule — and it counts a token's Latin letters, which we put
  // there. A line beginning with a protected name was therefore **ordered**
  // left to right by the library while being **aligned** right by us, and the
  // token sat at the wrong end of the line. Measured on the rendered page at
  // 150 dpi, and fixed with a mark the page cannot show.
  test('every right-to-left line carries the mark that sets its direction', () {
    const rlm = '\u200F';
    expect(const DirectionBlock(false, 'Sehr geehrter Herr,\nGrüßen').laidOut,
        'Sehr geehrter Herr,\nGrüßen',
        reason: 'a left-to-right block was marked, so a German page changed');
    expect(const DirectionBlock(true, 'السيد\n\nالمحترم').laidOut,
        '$rlm' 'السيد\n$rlm\n$rlm' 'المحترم',
        reason: 'the algorithm works a paragraph at a time, and a block is '
            'several paragraphs — one mark at the front is not enough');
  });

  testWidgets('a document with Arabic in it is saved, not refused', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: 'السيد محمد المحترم\nIBAN: DE89370400440532013000\n');
      await bench.rescan();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SendSheet(bench: bench, ground: ground, saveFolder: arabicOut.path)),
    ));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.tap(find.text('Save as PDF'));
    await settle(tester, rounds: 16);

    expect(find.textContaining('backwards'), findsNothing, reason: 'it still refuses');
    expect(find.textContaining('Saved to'), findsOneWidget, reason: 'nothing was written');
    final written = arabicOut.listSync().whereType<File>().toList();
    expect(written, hasLength(1));
    late final String back;
    await tester.runAsync(() async => back = await readBack(await written.single.readAsBytes()));
    expect(shaped.hasMatch(back), isTrue, reason: 'the saved file is not shaped');
    expect(unshaped.hasMatch(back), isFalse, reason: 'the saved file is mirrored');
    // And the promise of O still holds on an Arabic document.
    expect(back.contains('DE89370400440532013000'), isFalse,
        reason: 'the IBAN is readable in the PDF');
  });

  test('the stated folder is the one the owner was told', () {
    expect(protectedPdfFolder(), '${Platform.environment['HOME']}/Documents/zprivacy');
  });
}

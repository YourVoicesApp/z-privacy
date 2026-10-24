// 108 item 4 · The reading of a z-pdf can be saved, as an ordinary PDF.
//
// The owner, 24 October 2026: «نجعل وثيقة z-pdf يمكننا حفظها بعد فك التشفير…
// أعتقد فقط يكفي خيار حفظها في الذاكرة كوثيقة pdf» — **saving only; printing
// is out by his own word.**
//
// ## What the file must be, and must not claim
//
// It is the person's own document with their own values in it. So it carries
// **no answer page**, **no footer** — no build stamp, no count of protected
// places, no digest — and **no mark**: `z-pdf · protected copy` is a claim
// about what a page is, and a page holding values in the clear that wore it
// would be the worst file this product could write. Every one of those is
// measured below, on the bytes, through the product's own reader.
//
// ## What the measurement corrected in the paper's own plan
//
// «Pass `ReturnedDocument.restored` through as it is» is the paper's rule, and
// the first run of guard 1 refused the file it made: **`restored` is not the
// body of the z-pdf.** It is everything the reader read out of it, and that
// includes the footer this app writes on every page — «z-pdf · protected copy
// · z_core … · 3 places replaced · sha256 of the protected text» and the
// digest on the line under it — and the answer page's `Z-pdf : <token>`. A
// straight pass-through writes a file that **claims a protection it does not
// have**, with a digest that no longer describes it, over values standing in
// the clear. The paper's other rule for this item is that nothing in the file
// may claim protection, so the two lines this application wrote are dropped by
// `theDocumentWithoutOurOwnLines`, which is measured here from both sides: our
// lines gone, every line of the person's own kept whole and in order.
//
// ## The reader, and why a byte search will not do
//
// `pdf_byte_search_cannot_see_its_own_text`: a PDF's text is glyph indices, so
// a search over the bytes finds nothing whether the value is in the file or
// not. These guards read the written file back with the **core's own** PDF
// reader and flatten the result, which is also how `a_pdf_keeps_the_promise`
// measures the opposite promise about the other file.
//
// ## Watched red before it was trusted
//
// With the press taken off `TheReading` — the product as at `c0326af` — guard
// 1 reads «there is nothing in the reading to press» and guard 2 «nothing was
// written». With `buildPlainPdf` given the protected builder's footer, guard 1
// reads the stamp in a file that claims no protection.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/protected_pdf.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/the_way_back.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// A letter whose every name the general rules protect on their own, so the
/// whole way round can be walked with no review waiting.
const _letter = 'Sehr geehrter Herr Markus Weber,\n'
    'IBAN: DE89370400440532013000\n'
    'Mit freundlichen Grüßen\n';

/// The token of a name **this vault cannot resolve** — it was minted in some
/// other session, which is the ordinary state of a z-pdf read in the wrong
/// place (C-09). It must come out of the save exactly as it stands.
const _aTokenFromElsewhere = '__Z_7f3a_IBAN_4c18__';

Future<void> _settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  }
  await tester.pumpAndSettle();
}

Directory _dir(String name) {
  final d = Directory('${Directory.systemTemp.path}/zprivacy-plain-$name-$pid');
  removeWhenItLetsGo(d);
  d.createSync(recursive: true);
  addTearDown(() {
    removeWhenItLetsGo(d);
  });
  return d;
}

/// The product's own reader, on the product's own file, flattened — a value
/// counts as readable when its characters come back in order however the page
/// broke them.
Future<String> _readBack(Uint8List bytes) async {
  final session = await z.openSession(profileId: null, packId: 'de');
  final view = await z.importDocument(
    session: session,
    name: 'read-back.pdf',
    bytes: bytes,
    kind: DocumentKind.pdf,
  );
  await z.closeSession(session: session);
  return view.text.replaceAll(RegExp(r'\s+'), ' ');
}

/// **The whole way round, through the product**: a letter protected by the
/// general rules, taken out as a z-pdf, and read back by the door that takes
/// no bench at all (079 rule 5). What comes back is what the reading draws.
Future<ReturnedDocument> _aZPdfReadBack(WidgetTester tester, Directory data) async {
  late final ReturnedDocument seen;
  await tester.runAsync(() async {
    await z.vaultLock();
    await z.setDataDir(dir: data.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för avkodningen');
    final ground = Ground();
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _letter);
    await bench.rescan();
    await ground.refresh();
    // **Through the exit door, because that is what mints the answer page's
    // token** — the one the sheet's own press reads. A rescan's payload has
    // none: a z-pdf without its answer page is not one, and the token belongs
    // to the act of taking the text out.
    final leaving = await beginThenRead(ground, bench);
    final payload = leaving.view;
    if (payload == null) {
      throw StateError('the fixture could not take the text out: ${bench.troubleToShow}');
    }
    final token = payload.answerPageToken;
    if (token == null) throw StateError('the payload carries no answer page token');
    final zpdf = await buildProtectedPdf(
      text: payload.text,
      answerToken: token,
      sessionLanguage: null,
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · fixture',
        places: payload.protectedCount,
        byKind: const <String, int>{},
        sha256: sha256OfText(payload.text),
      ),
    );
    seen = await z.readADocumentThatCameBack(bytes: zpdf, kind: DocumentKind.pdf);
    bench.dispose();
  });
  return seen;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    TestWidgetsFlutterBinding.ensureInitialized();
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // The paper's own pin: a z-pdf read back through the test vault, saved, and
  // the saved file read back through a real reader — the restored value in it,
  // and no token for it.
  testWidgets('the restored value is in the saved file, and its token is not', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final data = _dir('round-data');
    final out = _dir('round-out');
    final seen = await _aZPdfReadBack(tester, data);
    expect(seen.broughtBack, greaterThan(0),
        reason: 'the fixture brought no name back, so there is nothing to save');

    final path = '${out.path}${Platform.pathSeparator}restored.pdf';
    await tester.pumpWidget(MaterialApp(
      home: TheReading(seen: seen, cameFrom: 'Mahnung.pdf', whereToSave: (_) async => path),
    ));
    await _settle(tester, rounds: 2);

    final press = find.byKey(TheReading.thePress);
    expect(press, findsOneWidget, reason: 'there is nothing in the reading to press');
    // And the file says what it will be **before** the press.
    expect(find.text(sentences.aPlainPdfOfTheRestoredText), findsOneWidget,
        reason: 'nothing on the glass says this file claims no protection');

    await tester.tap(press);
    await _settle(tester, rounds: 16);

    expect(File(path).existsSync(), isTrue, reason: 'nothing was written');
    expect(find.textContaining(path), findsOneWidget,
        reason: 'the file was written without a word about where');

    late final String back;
    await tester.runAsync(() async => back = await _readBack(await File(path).readAsBytes()));

    // **The name is in it, and the token for it is not.**
    expect(back, contains('Markus Weber'),
        reason: 'the restored value did not reach the file — the save wrote the protected text');
    expect(back.contains('__Z_'), isFalse,
        reason: 'a token is in a file whose whole point is the names put back: $back');
    // **And it claims nothing.** No answer page, no footer, no mark.
    expect(back.contains('Z-pdf'), isFalse, reason: 'the plain file wears the z-pdf mark: $back');
    expect(back.contains('z_core 0.0.0'), isFalse, reason: 'the plain file carries a build stamp');
    expect(back.contains('places replaced'), isFalse,
        reason: 'the plain file counts protected places over values in the clear: $back');
    expect(back.contains('sha256'), isFalse,
        reason: 'the plain file carries a digest sentence: $back');
    expect(back.contains('Zprivacy-svara'), isFalse,
        reason: 'the answer page’s own word is in the plain file: $back');
    // **And the person's own document is whole**: every line of the letter, in
    // the order it was written. Dropping our two lines may not cost a word of
    // theirs.
    for (final line in ['Sehr geehrter Herr Markus Weber,', 'Mit freundlichen Grüßen']) {
      expect(back, contains(line), reason: '«$line» did not reach the file');
    }
    expect(back.indexOf('Markus Weber'), lessThan(back.indexOf('Mit freundlichen')),
        reason: 'the lines came out in a different order than they went in');
  });

  // ------------------------------------------------------------------ guard 1b
  //
  // **The stripper, driven on its own**, so what it drops and what it keeps are
  // read as text rather than through a PDF reader — and so the assumption it
  // rests on is pinned: every pack's mark begins with «z-pdf ·», and the
  // answer line is `Z-pdf :` in every pack, because «z-pdf» is a product name
  // the one list keeps the same in every language. The day a pack words that
  // differently, this is red instead of quietly blind.
  test('our own two lines go, and nothing of the person’s does', () {
    const raw = 'z-pdf · protected copy · z_core 0.1.0 · 2026-10-24 · abc · '
        '3 places replaced, 1 value (1 person) · sha256 of the protected text\n'
        'd41d8cd98f00b204e9800998ecf8427ed41d8cd98f00b204e9800998ecf8427e\n'
        'Sehr geehrter Herr Markus Weber,\n'
        '\n'
        'Ihre IBAN DE89370400440532013000 ist notiert.\n'
        'Z-pdf : Zprivacy-svara\n'
        'z-pdf · protected copy · z_core 0.1.0 · 2026-10-24 · abc\n';
    final out = theDocumentWithoutOurOwnLines(
        [const Segment(text: raw, piece: Piece.words)]);
    expect(out, 'Sehr geehrter Herr Markus Weber,\n\n'
        'Ihre IBAN DE89370400440532013000 ist notiert.');

    // A hash in the person's own letter is their text: it is only dropped
    // directly under a footer line of ours.
    final theirs = theDocumentWithoutOurOwnLines([
      const Segment(
          text: 'Der Prüfwert lautet\n'
              'd41d8cd98f00b204e9800998ecf8427ed41d8cd98f00b204e9800998ecf8427e',
          piece: Piece.words)
    ]);
    expect(theirs, contains('d41d8cd98f00b204e9800998ecf8427e'),
        reason: 'a digest the person wrote themselves was taken out of their document');

    // The prefixes this rests on, against the one list itself.
    for (final lang in ['en', 'de', 'sv']) {
      expect(theSentencesAFileCarries(lang).zPdfProtectedCopy, startsWith('z-pdf ·'),
          reason: 'the «$lang» mark no longer begins with the product name, so the '
              'stripper above cannot see it');
      expect(theSentencesAFileCarries(lang).zPdfAnswerLine('X'), startsWith('Z-pdf :'),
          reason: 'the «$lang» answer line no longer begins as the stripper expects');
    }
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **A token that stayed a token stays one.** `Piece.unresolved` is a name
  // this vault has no key for, and the one thing a save may never do is invent
  // a name for it (079 rule 7's own law, in a file this time).
  testWidgets('a token that could not be resolved is written as it stands', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final out = _dir('unresolved');
    const seen = ReturnedDocument(
      restored: [
        Segment(text: 'Sehr geehrter Herr ', piece: Piece.words),
        Segment(text: 'Stefan Keller', piece: Piece.restored),
        Segment(text: ', Ihre IBAN ', piece: Piece.words),
        Segment(text: _aTokenFromElsewhere, piece: Piece.unresolved),
        Segment(text: ' ist notiert.', piece: Piece.words),
      ],
      tokens: 2,
      vault: VaultState.unlocked,
      names: 2,
      broughtBack: 1,
      unresolved: [_aTokenFromElsewhere],
      conversations: [],
      unknownNamespaces: [],
    );

    final path = '${out.path}${Platform.pathSeparator}restored.pdf';
    await tester.pumpWidget(MaterialApp(
      home: TheReading(seen: seen, whereToSave: (_) async => path),
    ));
    await _settle(tester, rounds: 2);
    await tester.tap(find.byKey(TheReading.thePress));
    await _settle(tester, rounds: 16);

    late final String back;
    await tester.runAsync(() async => back = await _readBack(await File(path).readAsBytes()));
    expect(back, contains('Stefan Keller'), reason: 'the value that came back is not in the file');
    expect(back, contains(_aTokenFromElsewhere),
        reason: 'the token that stayed a token is not in the file as it stood: $back');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **«Not now» writes nothing and says nothing.** A person who opens a save
  // dialog and closes it has not asked for anything, and a sentence about a
  // save that did not happen is noise on a screen.
  testWidgets('closing the save dialog writes no file', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final out = _dir('notnow');
    const seen = ReturnedDocument(
      restored: [Segment(text: 'Ein Satz.', piece: Piece.words)],
      tokens: 0,
      vault: VaultState.unlocked,
      names: 0,
      broughtBack: 0,
      unresolved: [],
      conversations: [],
      unknownNamespaces: [],
    );
    var asked = 0;
    await tester.pumpWidget(MaterialApp(
      home: TheReading(
        seen: seen,
        whereToSave: (_) async {
          asked += 1;
          return null;
        },
      ),
    ));
    await _settle(tester, rounds: 2);
    await tester.tap(find.byKey(TheReading.thePress));
    await _settle(tester, rounds: 6);

    expect(asked, 1, reason: 'the press did not ask where the file should go');
    expect(out.listSync(), isEmpty, reason: 'a file was written for a save nobody confirmed');
    expect(find.textContaining(out.path), findsNothing,
        reason: 'the screen says where a file went, and no file went anywhere');
    // The press is live again: a save that did not happen leaves nothing behind.
    expect(find.text(sentences.saveAsAPlainPdf), findsOneWidget,
        reason: 'the press is still «Saving…» after a dialog that was closed');
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **The name it suggests is never the name of the file being read back.** A
  // save dialog proposing the z-pdf's own name is a save dialog proposing to
  // overwrite it — and the suggestion is a convenience, so a person who read a
  // file with no name of its own still gets one that names the act.
  test('the suggested name stands beside the z-pdf and never on it', () {
    expect(theNameForARestoredPdf('Mahnung-Nordstern-protected-2026-10-24.pdf'),
        'Mahnung-Nordstern-protected-2026-10-24-restored.pdf');
    expect(theNameForARestoredPdf(null), 'restored.pdf');
    expect(theNameForARestoredPdf('   '), 'restored.pdf');
    expect(theNameForARestoredPdf('../../etc/passwd'), 'restored.pdf');
    expect(theNameForARestoredPdf('Mahnung.pdf'), 'Mahnung-restored.pdf');
  });
}

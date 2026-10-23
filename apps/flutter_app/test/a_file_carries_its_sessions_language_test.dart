// **A file carries the language of the session it left** — rule 80, the owner,
// 21 October 2026, `docs/RULES_AR.md`: «تذييل z-pdf وعلامة «نسخة محمية» وعنوان
// الصفحة المضافة بلغة الجلسة التي خرج منها الملف، والإنجليزية حين لا لغة
// للجلسة».
//
// The interface stays on this machine; the file travels. So the sentences a
// z-pdf **holds** are worded for whoever reads the document, and the holder in
// `core/sentences.dart` — «what the glass is showing now» — is not asked for
// any of them. A person who reads German documents in an English interface
// must not be handed a protected copy with an English footer.
//
// ## Why this file exists beside the two halves it measures
//
// Each half is correct on its own and the product can still be wrong, which is
// this house's own lesson about a split item: `theLanguageAFileCarries` can
// answer «de» all day while the send sheet never passes it, and
// `buildProtectedPdf` can word a German footer that nothing ever asks for. The
// guard that fails in that case is the one that crosses the seam — a press on
// the glass, a file on the disk, read back through the core's own reader — and
// that is guard 4 below. The three before it exist so that when 4 goes red the
// reason is one thing and not three.
//
// ## And every assertion reads the list rather than typing German
//
// «geschützte Kopie» typed here would be a second copy of a sentence whose
// home is `lib/l10n/app_de.arb` (092, sitting five, item 2). What is measured
// is the property itself — the words in the file are the **German list's**
// words and not the **English list's** — with a control that the two lists
// differ at each key used, because a guard comparing a sentence with itself is
// green for nothing.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
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
import 'package:zprivacy/widgets/send_sheet.dart';
import 'the_bridge_the_tests_speak_through.dart';
import 'the_folder_lets_go.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// A short German letter with one value the general rules take out, so a
/// payload with something in it reaches the door. **No word of the footer's own
/// is in it**: every assertion below looks for footer words in the file, and a
/// document that happened to contain them would answer for the footer.
const _letter = 'Guten Tag, bitte überweisen Sie auf IBAN '
    'DE02120300000000202051 bis Freitag.';

const _answer = '__Z_0001_OTHER_0004__';

PdfStamp _stamp() => const PdfStamp(
      build: 'z_core 0.0.0 · 0000-00-00 · rule 80',
      places: 1,
      byKind: <String, int>{'Person': 1},
      sha256:
          '0000000000000000000000000000000000000000000000000000000000000000',
    );

Directory _own(String name) {
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-r80-$name-$pid');
  removeWhenItLetsGo(dir);
  addTearDown(() => removeWhenItLetsGo(dir));
  return dir;
}

/// The text of a PDF, through **the core's own reader** — the same door an
/// import comes in by, so what is asserted is what a reader really finds in
/// the file rather than what we believe we wrote.
Future<String> _readBack(List<int> bytes) async {
  final session = await z.openSession(profileId: null, packId: 'de');
  final view = await z.importDocument(
    session: session,
    name: 'read-back.pdf',
    bytes: Uint8List.fromList(bytes),
    kind: DocumentKind.pdf,
  );
  await z.closeSession(session: session);
  return view.text.replaceAll(RegExp(r'\s+'), ' ');
}

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
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
  // **The list a file is worded from, by its session's code.** Three answers
  // and one of them is the owner's second sentence: English where there is no
  // language. The holder is left where every other guard expects it, in
  // English, so «German» here cannot be the glass having changed.
  test('a file is worded from its session’s list, and from English where there is none',
      () {
    theSentencesAreNow(const Locale('en'));
    final de = theSentencesAFileCarries('de');
    final none = theSentencesAFileCarries(null);

    expect(de.zPdfProtectedCopy, isNot(none.zPdfProtectedCopy),
        reason: 'the German and the English say the same thing at this key, so '
            'no guard in this file can tell one list from the other');
    expect(none.zPdfProtectedCopy, sentences.zPdfProtectedCopy,
        reason: 'the fallback is not the source list');

    // **An unwritten list is English, by the one law and not a second one** —
    // and since paper 106 (23 October 2026) Swedish is not one of them: a file
    // that leaves a Swedish session is worded in Swedish, by the same reading
    // of the same law. `fr` below is the law's remaining subject, which is why
    // it is here and not only for symmetry.
    expect(theSentencesAFileCarries('sv').zPdfProtectedCopy,
        isNot(none.zPdfProtectedCopy),
        reason: 'the Swedish list is written, so a file from a Swedish session '
            'may not carry the source list words');
    expect(theSentencesAFileCarries('fr').zPdfProtectedCopy,
        none.zPdfProtectedCopy,
        reason: 'a code with no list at all refused instead of answering English');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **Which session's language a payload's file carries** — the law, with no
  // vault and no file: a row is a row. The three `null`s are the three ways a
  // file ends up in English, and they are asserted one by one because each is
  // a different fact about the product and only the answer is shared.
  test('the language a file carries is the payload’s session’s, or none', () {
    final ground = Ground()
      ..sessions = [
        ConversationRow(
          number: 3,
          name: 'Session 3',
          beganAt: BigInt.from(1761004800),
          turns: 0,
          renamedTokens: 0,
          packId: 'de',
        ),
        ConversationRow(
          number: 4,
          name: 'Session 4',
          beganAt: BigInt.from(1761004800),
          turns: 0,
          renamedTokens: 0,
        ),
      ];

    expect(
      theLanguageAFileCarries(
          ground, const PayloadSession(number: 3, name: 'Session 3')),
      'de',
      reason: 'a payload from a German session carries no language, so the '
          'footer of its file will be worded from the wrong list',
    );
    // «Never asked» is not «no language» (075c), and for a **file** the two
    // have one answer: there is nothing to word it from but the source.
    expect(
      theLanguageAFileCarries(
          ground, const PayloadSession(number: 4, name: 'Session 4')),
      isNull,
      reason: 'a session nobody asked answered with a language anyway',
    );
    // A payload that belongs to no session at all — the ordinary state of a
    // protected copy taken before any session was born.
    expect(theLanguageAFileCarries(ground, null), isNull);
    // And a shut vault, which is the state that cannot be told from the two
    // above and is written down at the law: the rows come out of the vault
    // with the keys, so there is nothing to read.
    expect(
      theLanguageAFileCarries(
          Ground(), const PayloadSession(number: 3, name: 'Session 3')),
      isNull,
      reason: 'a session this vault does not hold answered with a language',
    );
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The builder words the file from the code it is given**, read back out of
  // the bytes. This is the half that could be right while nothing asked for
  // it; guard 4 is the half that asks.
  test('the footer in the bytes is the session’s language, not the glass’s',
      () async {
    final data = _own('bytes')..createSync(recursive: true);
    await z.vaultLock();
    await z.setDataDir(dir: data.path);
    theSentencesAreNow(const Locale('en'));

    final de = theSentencesAFileCarries('de');
    final en = theSentencesAFileCarries(null);
    expect(de.placesReplaced(1), isNot(en.placesReplaced(1)),
        reason: 'the two lists count places in the same words');
    expect(de.sha256OfTheProtectedText('x'), isNot(en.sha256OfTheProtectedText('x')),
        reason: 'the two lists name the digest in the same words');

    final german = await _readBack(await buildProtectedPdf(
      text: _letter,
      stamp: _stamp(),
      answerToken: _answer,
      sessionLanguage: 'de',
    ));
    expect(german, contains(de.zPdfProtectedCopy),
        reason: 'the mark on the page is not the German list’s');
    expect(german, contains(de.placesReplaced(1)),
        reason: 'the count’s words are not the German list’s');
    expect(german.contains(en.zPdfProtectedCopy), isFalse,
        reason: 'the English mark is in a file that left a German session');
    expect(german.contains(en.placesReplaced(1)), isFalse,
        reason: 'the English count is in a file that left a German session');

    // The control, on the same two assertions: with no session language the
    // file is English, so neither half above is simply what this builder
    // always writes.
    final english = await _readBack(await buildProtectedPdf(
      text: _letter,
      stamp: _stamp(),
      answerToken: _answer,
      sessionLanguage: null,
    ));
    expect(english, contains(en.zPdfProtectedCopy),
        reason: 'a file from no session is not English');
    expect(english.contains(de.zPdfProtectedCopy), isFalse,
        reason: 'a file from no session carries the German mark');
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **The seam: a press on the glass, in English, over a German session.**
  //
  // Nothing is handed to `saveProtectedPdf` here — the sheet is mounted, the
  // button is pressed, and the file is read off the disk. A send sheet that
  // never passed the language, or passed the interface's, fails only here: the
  // three guards above would all still be green.
  testWidgets('a German session’s file carries a German footer in an English interface',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    theSentencesAreNow(const Locale('en'));

    final data = _own('seam');
    final out = _own('seam-out')..createSync(recursive: true);
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: data.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein Kennsatz lang genug');
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _letter);
      await bench.rescan();
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SendSheet(bench: bench, ground: ground, saveFolder: out.path),
      ),
    ));
    await _settle(tester);
    // The press itself, which births the session on its way — the door the
    // owner actually uses, and the only one that proves the thread.
    await tester.tap(find.text(sentences.saveAsPdf));
    await _settle(tester, rounds: 16);

    final born = ground.openSession;
    expect(born, isNotNull,
        reason: 'the press did not open a session: ${ground.trouble}');
    expect(ground.rowOfSession(born!)?.packId, 'de',
        reason: 'the session the press made is not German, so this guard is '
            'measuring something else');

    final written = out.listSync().whereType<File>().toList();
    expect(written, hasLength(1), reason: 'the press wrote no file');
    late final String back;
    await tester.runAsync(
        () async => back = await _readBack(await written.single.readAsBytes()));

    final de = theSentencesAFileCarries('de');
    final en = theSentencesAFileCarries(null);
    expect(back, contains(de.zPdfProtectedCopy),
        reason: 'the file this press wrote is not marked in the session’s '
            'language — the sheet is not passing it, or is passing the glass’s');
    expect(back.contains(en.zPdfProtectedCopy), isFalse,
        reason: 'the English mark is in a file that left a German session');
    // And the glass is still in English, which is the other half of the
    // claim: the file changed language and the interface did not.
    expect(sentences.zPdfProtectedCopy, en.zPdfProtectedCopy,
        reason: 'the interface’s holder moved, so «English interface» is not '
            'what was measured');
    expect(find.text(sentences.saveAsPdf), findsOneWidget,
        reason: 'the button is still «Saving…», so nothing finished');
  });

  // ------------------------------------------------------------------ guard 5
  //
  // **And the control at the same door**: no vault, so no session can be born,
  // so the payload belongs to none — and the file is English. Without this,
  // guard 4 is also satisfied by a sheet that words every file in German.
  testWidgets('a file that left no session carries the source’s words',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    theSentencesAreNow(const Locale('en'));

    final data = _own('nosession');
    final out = _own('nosession-out')..createSync(recursive: true);
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: data.path);
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _letter);
      await bench.rescan();
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SendSheet(bench: bench, ground: ground, saveFolder: out.path),
      ),
    ));
    await _settle(tester);
    await tester.tap(find.text(sentences.saveAsPdf));
    await _settle(tester, rounds: 16);

    expect(ground.openSession, isNull,
        reason: 'a session was born without a vault, so «no session» is not '
            'the state this guard measures');
    final written = out.listSync().whereType<File>().toList();
    expect(written, hasLength(1), reason: 'the press wrote no file');
    late final String back;
    await tester.runAsync(
        () async => back = await _readBack(await written.single.readAsBytes()));

    final de = theSentencesAFileCarries('de');
    final en = theSentencesAFileCarries(null);
    expect(back, contains(en.zPdfProtectedCopy),
        reason: 'a file that left no session is not worded from the source — '
            'and the bench it came off is German, which is the pack this '
            'guard exists to keep out of a file');
    expect(back.contains(de.zPdfProtectedCopy), isFalse,
        reason: 'the bench’s own pack reached the footer: a document’s '
            'language is not a session’s');
  });
}

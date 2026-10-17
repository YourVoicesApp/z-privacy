// 079 · z-pdf: the answer page — the export's half.
//
// The owner, 13 Oct 2026, evening: every z-pdf the app exports ends with one
// extra page. On top, «Z-pdf : Zprivacy-svara» — and the value is **protected
// with the same session key as the document**, so the page carries an ordinary
// token of that session and never the key: «لا أقصد أنها تحصل على المفتاح، أقصد
// أنها تحصل رمزاً ثابتاً يمكن العودة إليه». In the middle, a faint circle for the
// answer. At the bottom, **the same footer every other page of this export
// carries**. And every page says, beside that footer, that it is a z-pdf.
//
// ## How each guard reads the file
//
// **Through our own reader, never a byte search** — a PDF that embeds a
// TrueType font writes glyph indices, and a byte search over it is blind to its
// own text (`a_pdf_keeps_the_promise_test` keeps the proof). The reader is the
// import path of `z_core`, on the bytes the press wrote to the disk.
//
// The reader hands back one word per line — a PDF positions each word on its
// own — and one form feed between page and page. So «the last page's first
// line» is read as the page's first words in the order the page draws them,
// and «exactly one token» is counted over the whole page: if a second token
// stood anywhere on the answer page, this would see it.
//
// ## What is out of this file
//
// The import door — finding the token when a document comes back, the «z-pdf»
// entry, the banner — is the other half of 079 and is not built here. What is
// measured here is that the token **can** find its way back: pasted as an
// answer in its own session it restores to exactly «Zprivacy-svara», and in
// another session it is named unknown and restores nothing.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/send_sheet.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _wide = Size(1500, 1000);

/// The word the answer page protects. Written here rather than imported, so a
/// change to it in the product is a red here and not a silent agreement.
const _answerWord = 'Zprivacy-svara';

/// Two documents, each with one value the general rules protect by
/// themselves and nothing else to argue about — measured in the fixture below,
/// so a build that starts suggesting a word in either says so by name.
const _letter = 'Bitte überweisen Sie auf IBAN DE02120300000000202051 bis Freitag.';
const _other = 'Zahlung an IBAN DE44500105175407324931, Freitag bestätigt.';

/// A letter this build reads as one waiting word (the company is offered,
/// never taken) beside two values it protects by itself.
const _waitingLetter = 'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n'
    'Wir bitten um eine Verlängerung des Zahlungsziels.';

/// A token, by the shape `TokenMint` writes it.
final _tokenShape = RegExp(r'__Z_[A-Z0-9]{4}_[A-Z0-9]+_[A-Z0-9]{4,8}__');

Future<void> _settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Directory _ownDir(String name) {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-answer-$name-$pid');
  if (own.existsSync()) own.deleteSync(recursive: true);
  own.createSync(recursive: true);
  addTearDown(() {
    if (own.existsSync()) own.deleteSync(recursive: true);
  });
  return own;
}

/// A fresh vault of its own, unlocked, with nothing in it.
///
/// **Locked first**: the vault is global to the isolate, so a test before this
/// one can leave one open on another folder.
Future<Ground> _aVault(String name) async {
  await z.vaultLock();
  await z.setDataDir(dir: _ownDir('$name-vault').path);
  await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för en svarssida');
  final ground = Ground();
  await ground.refresh();
  return ground;
}

/// A bench on [text], scanned. The fixture says how many words wait, so a
/// guard never blames the product for the fixture.
Future<Workbench> _aBench(String text, {required int waiting}) async {
  final session = await z.openSession(profileId: null, packId: 'de');
  final bench = Workbench(session: session, profileId: null, packId: 'de');
  await z.importText(session: session, text: text);
  await bench.rescan();
  expect(bench.openSuggestions, waiting,
      reason: 'the fixture leaves ${bench.openSuggestions} words waiting, not $waiting');
  return bench;
}

/// The pages our own reader gets out of these bytes, each with its whitespace
/// collapsed — one word per line becomes one line of words.
Future<List<String>> _pages(Uint8List bytes) async {
  final session = await z.openSession(profileId: null, packId: 'de');
  try {
    final view = await z.importDocument(
      session: session,
      name: 'read-back.pdf',
      bytes: bytes,
      kind: DocumentKind.pdf,
    );
    final pages = view.text
        .split('\f')
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .toList();
    expect(pages, hasLength(view.pages),
        reason: 'the reader counted ${view.pages} pages and handed back ${pages.length}');
    return pages;
  } finally {
    await z.closeSession(session: session);
  }
}

/// Press «Save as PDF» on a sheet over [bench], and hand back the one file it
/// wrote — or none.
///
/// The sheet is opened as a dialog, the way the product opens it: a refused
/// press closes the sheet (the lead's ruling on 083 rule 12), and closing a
/// sheet that was the app's only route would be a test of something else.
Future<File?> _pressSave(
  WidgetTester tester,
  Ground ground,
  Workbench bench,
  Directory out,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<bool>(
            context: context,
            builder: (_) => SendSheet(bench: bench, ground: ground, saveFolder: out.path),
          ),
          child: const Text('Open the sheet'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open the sheet'));
  await _settle(tester);
  await tester.tap(find.text('Save as PDF'));
  // **Until the press has finished, not until the file exists.** The bytes
  // reach the disk one step before the press binds the payload an answer is
  // tied to — measured: a file on the disk and `copiedPayload` still null —
  // so a teardown on the file's word cut the press in half. The sheet's own
  // sentence is the press's last act; a refused press closes the sheet.
  for (var i = 0; i < 40; i++) {
    await _settle(tester, rounds: 2);
    if (find.textContaining('Saved to').evaluate().isNotEmpty) break;
    if (find.byType(SendSheet).evaluate().isEmpty) break;
  }
  final written = out.listSync().whereType<File>().toList();
  expect(written.length, lessThanOrEqualTo(1), reason: 'one press wrote ${written.length} files');
  // The tree goes, dialog and all, so a second press in one test opens a
  // sheet of its own and not the one still standing from the first.
  await tester.pumpWidget(const SizedBox.shrink());
  return written.isEmpty ? null : written.single;
}

/// The answer page's token: the last page must open with `Z-pdf :` and carry
/// exactly one token, and this hands that token back.
String _answerToken(List<String> pages) {
  final last = pages.last;
  expect(last, startsWith('Z-pdf : '),
      reason: 'the last page does not open with «Z-pdf :» — it opens with '
          '«${last.length > 60 ? last.substring(0, 60) : last}»');
  final tokens = _tokenShape.allMatches(last).map((m) => m.group(0)!).toList();
  expect(tokens, hasLength(1), reason: 'the answer page carries ${tokens.length} tokens: $tokens');
  expect(last, startsWith('Z-pdf : ${tokens.single} '),
      reason: 'the token on the answer page is not the word after «Z-pdf :»');
  return tokens.single;
}

/// Paste [raw] back as an answer on [bench] and read what the core restores.
Future<AnswerSnapshot> _pasteBack(Workbench bench, String raw) async {
  final refused = await bench.pasteAnswer(raw);
  expect(refused, isNull, reason: 'the answer could not come back: $refused');
  return z.answerSnapshot(session: bench.session, answer: bench.showing!);
}

String _read(List<Segment> segments) => segments.map((s) => s.text).join();

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    TestWidgetsFlutterBinding.ensureInitialized();
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // **The top line, and the way back.** The last page opens with «Z-pdf :» and
  // one token; that token is of this session — its namespace is the one the
  // document's own tokens wear — and pasted back here it restores to exactly
  // the word, and nothing else.
  testWidgets('the last page is the answer page, and its token restores to the word', (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final Ground ground;
    late final Workbench bench;
    await tester.runAsync(() async {
      ground = await _aVault('restores');
      bench = await _aBench(_letter, waiting: 0);
    });
    final file = await _pressSave(tester, ground, bench, _ownDir('restores-pdf'));
    expect(file, isNotNull, reason: 'the press wrote no file');

    late final List<String> pages;
    await tester.runAsync(() async => pages = await _pages(await file!.readAsBytes()));
    expect(pages.length, greaterThanOrEqualTo(2),
        reason: 'one page: the document is there and the answer page is not');
    final token = _answerToken(pages);

    // Of this session: the document's own token, minted from the same key,
    // wears the same namespace. The control first — the document has one.
    final documentTokens = _tokenShape.allMatches(pages.first).map((m) => m.group(0)!).toList();
    expect(documentTokens, isNotEmpty, reason: 'the document page carries no token, so nothing is compared');
    expect(token.substring(0, 8), documentTokens.first.substring(0, 8),
        reason: 'the answer page wears another namespace than the document: $token vs ${documentTokens.first}');
    expect(token, isNot(contains(_answerWord)), reason: 'the word stands on the page in the clear');
    expect(pages.any((p) => p.contains(_answerWord)), isFalse,
        reason: 'the word is readable somewhere in the file');

    // And it finds its way back: exactly the word, nothing named unknown.
    late final AnswerSnapshot snap;
    await tester.runAsync(() async => snap = await _pasteBack(bench, token));
    expect(snap.unknownTokens, isEmpty,
        reason: 'the answer page\'s token is unknown in the session that printed it');
    expect(_read(snap.restored), _answerWord,
        reason: 'the token did not restore to exactly the word');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **In another session it is foreign.** The same press in a second session,
  // and the first session's token pasted there: named unknown, restored to
  // nothing. The control stands in the same answer — the second session's own
  // answer token comes back as the word — so «nothing restored» is isolation
  // and not a restorer that restores nothing.
  testWidgets('another session names the token unknown and restores nothing of it', (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final Ground ground;
    late final Workbench first;
    await tester.runAsync(() async {
      ground = await _aVault('foreign');
      first = await _aBench(_letter, waiting: 0);
    });
    final one = await _pressSave(tester, ground, first, _ownDir('foreign-one'));
    expect(one, isNotNull, reason: 'the first press wrote no file');
    late final String firstToken;
    await tester.runAsync(() async {
      firstToken = _answerToken(await _pages(await one!.readAsBytes()));
      await z.closeSession(session: first.session);
    });

    // A second session, born on a second bench by the core's own door.
    late final Workbench second;
    await tester.runAsync(() async {
      second = await _aBench(_other, waiting: 0);
      await z.conversationBegin(name: 'another session', bench: second.session);
      await ground.refresh();
      await second.refresh();
    });
    final two = await _pressSave(tester, ground, second, _ownDir('foreign-two'));
    expect(two, isNotNull, reason: 'the second press wrote no file');
    late final String secondToken;
    await tester.runAsync(() async => secondToken = _answerToken(await _pages(await two!.readAsBytes())));
    expect(secondToken, isNot(firstToken),
        reason: 'two sessions printed the same answer token, so there is no isolation to measure');

    late final AnswerSnapshot snap;
    await tester.runAsync(() async => snap = await _pasteBack(second, '$firstToken / $secondToken'));
    expect(snap.unknownTokens, [firstToken],
        reason: 'the first session\'s token was not named unknown in the second: ${snap.unknownTokens}');
    final restored = _read(snap.restored);
    expect(restored, '$firstToken / $_answerWord',
        reason: 'the foreign token was restored, dropped, or the control did not restore: «$restored»');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **One export, one stamp, on every page — the answer page included** — and
  // every page says it is a z-pdf. The footer of the answer page is read
  // against the footer of the document's own page, word for word.
  testWidgets('the answer page carries the same footer, and every page says z-pdf', (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final Ground ground;
    late final Workbench bench;
    await tester.runAsync(() async {
      ground = await _aVault('footer');
      bench = await _aBench(_letter, waiting: 0);
    });
    final file = await _pressSave(tester, ground, bench, _ownDir('footer-pdf'));
    expect(file, isNotNull, reason: 'the press wrote no file');
    late final List<String> pages;
    await tester.runAsync(() async => pages = await _pages(await file!.readAsBytes()));
    expect(pages.length, greaterThanOrEqualTo(2), reason: 'there is no answer page to read');
    _answerToken(pages);

    // The footer of this export, as the document's page carries it: from the
    // mark to the end of the sha256, which is the stamp of this one request.
    // Read by its two ends and not by its place on the page — the reader hands
    // a body page's footer back **before** its body, the order the page draws
    // them in, so «the end of the page» is not where a footer is.
    final digest = RegExp(r'[0-9a-f]{64}').firstMatch(pages.first)?.group(0);
    expect(digest, isNotNull, reason: 'the document page carries no sha256 — no stamp to compare');
    final footer = RegExp(r'z-pdf\b.*?[0-9a-f]{64}');
    final first = footer.firstMatch(pages.first)?.group(0);
    expect(first, isNotNull, reason: 'the document page has no footer from the mark to the stamp');
    expect(first, contains(digest));
    for (final (i, page) in pages.indexed) {
      expect(page, contains('z-pdf'), reason: 'page ${i + 1} of ${pages.length} does not say it is a z-pdf');
      expect(footer.firstMatch(page)?.group(0), first,
          reason: 'page ${i + 1} of ${pages.length} carries another footer than this export\'s, or none');
    }
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **The 083a law holds with the page.** A word waits; the press writes no
  // file at all — so no answer page either, and nothing minted for one.
  testWidgets('with a word waiting the press writes no file, so no answer page', (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final Ground ground;
    late final Workbench bench;
    await tester.runAsync(() async {
      ground = await _aVault('waits');
      bench = await _aBench(_waitingLetter, waiting: 1);
    });
    final out = _ownDir('waits-pdf');
    final file = await _pressSave(tester, ground, bench, out);
    expect(file, isNull, reason: 'a file was written while a word waited: ${file?.path}');
    expect(out.listSync(), isEmpty, reason: 'the folder holds something after a refused press');
    expect(bench.panel, OpenPanel.review, reason: 'the refusal did not open the review on the word');
  });

  // -------------------------------------------------------------- the measure
  //
  // **Fixed per session — or not?** Paper 079 says the answer token is fixed
  // per session; an older paper (046/U) derived token names from the document.
  // Two documents, one session, two presses: the two answer pages are read
  // back and compared. The control beside it: the two documents' own tokens
  // are different values and must differ, so «the same» is about the word and
  // not about a mint that names everything alike.
  testWidgets('two documents in one session print the same answer token', (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late final Ground ground;
    late final Workbench first;
    await tester.runAsync(() async {
      ground = await _aVault('fixed');
      first = await _aBench(_letter, waiting: 0);
    });
    final one = await _pressSave(tester, ground, first, _ownDir('fixed-one'));
    expect(one, isNotNull, reason: 'the first press wrote no file');
    late final List<String> onePages;
    await tester.runAsync(() async {
      onePages = await _pages(await one!.readAsBytes());
      await z.closeSession(session: first.session);
    });
    final session = ground.openSession;
    expect(session, isNotNull, reason: 'the first press began no session');

    // The second document opens **inside** that session: no birth at its exit.
    late final Workbench second;
    await tester.runAsync(() async => second = await _aBench(_other, waiting: 0));
    expect(ground.aSessionWouldBeBorn, isFalse, reason: 'the second press would begin a new session');
    final two = await _pressSave(tester, ground, second, _ownDir('fixed-two'));
    expect(two, isNotNull, reason: 'the second press wrote no file');
    late final List<String> twoPages;
    await tester.runAsync(() async => twoPages = await _pages(await two!.readAsBytes()));
    expect(ground.openSession, session, reason: 'the second press left the session it was in');

    final a = _answerToken(onePages);
    final b = _answerToken(twoPages);
    final docA = _tokenShape.firstMatch(onePages.first)!.group(0)!;
    final docB = _tokenShape.firstMatch(twoPages.first)!.group(0)!;
    // ignore: avoid_print
    print('measured · answer tokens: $a | $b · document tokens: $docA | $docB');
    expect(docA, isNot(docB), reason: 'two different values took one token — the control');
    expect(docA.substring(0, 8), docB.substring(0, 8),
        reason: 'the two documents are not in one namespace, so they are not in one session');
    expect(a, b, reason: 'the answer token differs between two documents of one session');
  });
}

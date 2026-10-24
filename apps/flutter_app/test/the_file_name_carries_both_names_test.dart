// 108 item 2 · The PDF press asks for a name, and the file carries both.
//
// The owner, 24 October 2026: «نجعل اسم الجلسة داخل باسم الوثيقة. والحفظ يحتاج
// إلى كتابة اسم للوثيقة من قبل المستخدم».
//
// ## The trap this closes, measured on his own machine
//
// A protected copy was named `<session>-protected-<date>.pdf`, and the
// session's name is **ours**: a session nobody named is «Session 1». So two
// vaults' copies of one day arrive in `Documents\ZPrivacy` under one name, the
// second becomes `…-2.pdf`, and nothing in either name says which work it is.
// That is what the Windows read-back of 22 October fell into.
//
// ## And the sentence that comes with asking
//
// **A file name is the one thing about a protected copy that is not
// protected.** It stands in a folder listing, a backup, a sync, an attachment
// — the direction nobody looks at. 081 took the document's own name out of
// here for exactly that reason; asking for one makes it the person's choice,
// so the limit is said where the typing happens and not in a guide.
//
// ## Watched red before it was trusted
//
// With the dialog taken out of the press — the product as at `c0326af` —
// guard 1 reads «the press wrote a file without asking what to call it» and
// guard 2 «the file name says nothing of the document the person was working
// on». With `_clean`'s own refusal taken out of `saveProtectedPdf`, guard 5
// reads a written file where it expects a sentence.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/protected_pdf.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/widgets/the_name_for_the_file.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';
import 'the_press_that_asks_for_a_name.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
/// **Everything in it is protected by the general rules**, so no exit is
/// waiting on the person's word: a suggestion standing open refuses the press
/// before any file name is reached, and this file would then be blaming the
/// naming for the fixture. The same letter `a_pdf_keeps_the_promise` uses, for
/// the same reason.
const _letter = 'Sehr geehrter Herr Markus Weber,\n'
    'Geboren am 3.4.1978, Steuernummer 151/815/08154\n'
    'IBAN: DE89370400440532013000\n'
    'Telefon: 0211 4567890\n'
    'Mit freundlichen Grüßen\n';

Future<void> _settle(WidgetTester tester, {int rounds = 16}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  }
  await tester.pumpAndSettle();
}

Directory _dir(String name) {
  final d = Directory('${Directory.systemTemp.path}/zprivacy-name-$name-$pid');
  removeWhenItLetsGo(d);
  d.createSync(recursive: true);
  addTearDown(() {
    removeWhenItLetsGo(d);
  });
  return d;
}

/// A vault, a document with something to protect in it, and a session the
/// person named — so the file name has two real names to carry.
Future<({Ground ground, Workbench bench, Directory out})> _ready(
  WidgetTester tester,
  String name, {
  String sessionName = 'Nordstern',
}) async {
  late final ({Ground ground, Workbench bench, Directory out}) made;
  final data = _dir('$name-data');
  final out = _dir('$name-out');
  await tester.runAsync(() async {
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: data.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för namnet');
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _letter);
    await bench.rescan();
    await ground.refresh();
    final renamed = await ground.beginSession(sessionName, bench: session);
    if (renamed == null) throw StateError('the fixture could not begin a session: ${ground.trouble}');
    await bench.refresh();
    made = (ground: ground, bench: bench, out: out);
  });
  return made;
}

Widget _sheet(({Ground ground, Workbench bench, Directory out}) g) => MaterialApp(
      home: Scaffold(
        body: SendSheet(bench: g.bench, ground: g.ground, saveFolder: g.out.path),
      ),
    );

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    TestWidgetsFlutterBinding.ensureInitialized();
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('the press asks before it writes, and says the name is not protected',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final g = await _ready(tester, 'asks');
    await tester.pumpWidget(_sheet(g));
    await _settle(tester);

    await tester.tap(find.text(sentences.saveAsPdf));
    await tester.pumpAndSettle();

    expect(find.byKey(TheNameForTheFile.field), findsOneWidget,
        reason: 'the press wrote a file without asking what to call it');
    expect(find.text(sentences.theFileNameIsNotProtected), findsOneWidget,
        reason: 'the dialog asks for a name and says nothing about where it goes');
    expect(g.out.listSync(), isEmpty, reason: 'a file was written before the name was given');

    // **«Not now» is nothing at all**: no file, and no session born either —
    // the dialog stands in front of `beginThenRead` for that reason.
    final sessions = g.ground.sessions.length;
    await tester.tap(find.byKey(TheNameForTheFile.cancel));
    await _settle(tester, rounds: 6);
    expect(g.out.listSync(), isEmpty, reason: 'closing the dialog wrote a file');
    expect(g.ground.sessions.length, sessions, reason: 'closing the dialog born a session');
  });

  // ------------------------------------------------------------------ guard 2
  testWidgets('the file carries the typed name, the session’s name and the date',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final g = await _ready(tester, 'both');
    await tester.pumpWidget(_sheet(g));
    await _settle(tester);
    expect(g.bench.openSuggestions, 0,
        reason: 'the fixture leaves a suggestion open, so the exit refuses before a name is asked');

    await saveAsPdfCalled(tester, 'Mahnung Feldmann');
    await _settle(tester);

    final written = g.out.listSync().whereType<File>().toList();
    expect(written, hasLength(1), reason: 'the press wrote ${written.length} files');
    final name = written.single.uri.pathSegments.last;
    expect(name, contains('Mahnung Feldmann'),
        reason: 'the file name says nothing of the document the person was working on: $name');
    expect(name, contains('Nordstern'),
        reason: 'the file name says nothing of the session it left: $name');
    // The date stays — it is what tells a Tuesday's copy from a Wednesday's.
    final today = DateTime.now();
    final day = '${today.year}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    expect(name, contains(day), reason: 'the file name carries no date: $name');
    expect(name, endsWith('.pdf'));
    // **The person's own word first**, because a folder listing sorts by what
    // stands in front and that is what they are looking for.
    expect(name.indexOf('Mahnung'), lessThan(name.indexOf('Nordstern')),
        reason: 'ours stands in front of theirs: $name');
    // One spelling of a path, whatever platform this is
    // (`a_path_is_compared_in_one_spelling`): the folder listing's own answer
    // is what the screen says.
    expect(find.textContaining(written.single.path), findsOneWidget,
        reason: 'the path on the glass is not the path the folder prints');
  });

  // ------------------------------------------------------------------ guard 3
  testWidgets('an empty name is refused with a sentence, and the dialog stays', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final g = await _ready(tester, 'empty');
    await tester.pumpWidget(_sheet(g));
    await _settle(tester);

    await tester.tap(find.text(sentences.saveAsPdf));
    await tester.pumpAndSettle();
    // Nothing typed, and then a space — a name that is not a name.
    await tester.enterText(find.byKey(TheNameForTheFile.field), '   ');
    await tester.pump();
    await tester.tap(find.byKey(TheNameForTheFile.save));
    await tester.pumpAndSettle();

    expect(find.text(sentences.aNameIsNeededForThisDocument), findsOneWidget,
        reason: 'an empty name was taken in silence');
    expect(find.byKey(TheNameForTheFile.field), findsOneWidget,
        reason: 'the dialog closed on a refusal, so the person has nowhere to answer');
    expect(g.out.listSync(), isEmpty, reason: 'a file was written with no name');

    // And the refusal goes away when a name arrives: a sentence about a state
    // that is over is a screen saying something untrue.
    await tester.enterText(find.byKey(TheNameForTheFile.field), 'Mahnung');
    await tester.pumpAndSettle();
    expect(find.text(sentences.aNameIsNeededForThisDocument), findsNothing,
        reason: 'the refusal stands over a name that was given');
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **A name a person typed may hold anything.** `/` and `\` are both path
  // separators somewhere (`a_path_is_compared_in_one_spelling`), and Windows
  // refuses `: * ? " < > |` in a file name altogether — so one hand cleans the
  // name for both platforms, by allowing rather than by listing, and this
  // measures the result on whichever one the suite is running on.
  testWidgets('a name that is a path, or holds what a platform refuses, lands in the folder',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final g = await _ready(tester, 'path');
    await tester.pumpWidget(_sheet(g));
    await _settle(tester);

    await saveAsPdfCalled(tester, r'Mahnung/Feldmann*2:"<>|\x');
    await _settle(tester);

    final written = g.out.listSync().whereType<File>().toList();
    expect(written, hasLength(1),
        reason: 'the save went somewhere else, or nowhere: ${written.length} files in the folder');
    final name = written.single.uri.pathSegments.last;
    for (final refused in ['/', r'\', ':', '*', '?', '"', '<', '>', '|']) {
      expect(name.contains(refused), isFalse,
          reason: '«$refused» came through into the file name: $name');
    }
    // **The person's own word survived the cleaning**: a name made safe is not
    // a name thrown away.
    expect(name, contains('Mahnung'), reason: 'the cleaning took the name with it: $name');
    // And it is in the folder the save was given — the other half of what a
    // `/` in a name would have meant.
    expect(File('${g.out.path}${Platform.pathSeparator}$name').existsSync(), isTrue,
        reason: 'the file is not in the folder the save was given: $name');
  });

  // ------------------------------------------------------------------ guard 4b
  //
  // **And a name that is nothing but a path is refused, by the writer.** This
  // is why the refusal is said twice: the dialog sees characters and cannot
  // know that `../../` leaves nothing behind, and the one hand that cleans a
  // name is the one that can say so. Nothing is written, and the sheet carries
  // the sentence.
  testWidgets('a name that cleans away to nothing is refused, and the sheet says so',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final g = await _ready(tester, 'nothing');
    await tester.pumpWidget(_sheet(g));
    await _settle(tester);

    await saveAsPdfCalled(tester, '../../');
    await _settle(tester);

    expect(g.out.listSync(), isEmpty, reason: 'a file was written for a name that is a path');
    expect(find.text(sentences.aNameIsNeededForThisDocument), findsOneWidget,
        reason: 'nothing on the glass says why no file was written');
  });

  // ------------------------------------------------------------------ guard 5
  //
  // **Said twice, on purpose.** The dialog refuses an empty name first; this is
  // the writer refusing it again, because a door that can be called from two
  // places is a door that will be. No file, and a sentence rather than a
  // throw.
  test('the writer refuses an empty name too', () async {
    final out = _dir('writer');
    final said = await saveProtectedPdf(
      text: 'Ein Satz.',
      answerToken: '__Z_0000_ANSWER_0000__',
      sessionName: 'Nordstern',
      documentName: '   ',
      sessionLanguage: null,
      folder: out.path,
      stamp: PdfStamp(
        build: 'z_core 0.0.0 · 0000-00-00 · control',
        places: 0,
        byKind: <String, int>{},
        sha256: '0' * 64,
      ),
    );
    expect(said.path, isNull, reason: 'a file was written for a name nobody gave');
    expect(said.trouble, sentences.aNameIsNeededForThisDocument,
        reason: 'the writer refused in words nobody wrote for it');
    expect(out.listSync(), isEmpty, reason: 'the folder holds a file after a refusal');
  });
}

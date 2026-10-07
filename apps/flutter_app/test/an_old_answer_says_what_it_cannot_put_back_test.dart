// 046/U item 1, on the screen · an answer from another conversation says so.
//
// **The owner, 7 October:** «ما نحتاجه فعلاً هو إعادة فكّ تشفير الوثيقة في حال
// ابتعدتُ لعدة أيام وكان هناك وثائق أخرى في هذه المدة.»
//
// He comes back after days away, with other documents in between, and pastes
// the answer he was given. Until this, every token of that older conversation
// came back **as the model's own words**: he read
// `__Z_5CDD_IBAN_5B32__` in the middle of a sentence about his own account,
// with nothing on the screen to tell him whether the app had failed or the
// model had written that.
//
// This file is the screen half of the fix, and it asserts the two things that
// make it a fix rather than a note in a changelog:
//
//   * the band is **above** the answer and says how many tokens this
//     conversation does not know, and names them;
//   * the token in the text is **not drawn as the answer** — it carries the
//     struck mark, so no reading of that sentence can take it for words the
//     model wrote.
//
// And the control, because a warning that fires on an ordinary answer is worse
// than no warning: this conversation's own answer restores with the band
// absent.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/answer.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'a passphrase long enough for two days apart';

const _letter = 'Sehr geehrte Frau Hedvig Palmgren,\n'
    'der Kontostand von GB29 NWBK 6016 1331 9268 19 beträgt 42 500 EUR.\n';

/// The same letter with one figure changed — a **different document**, and
/// since 046/U item 2 that is what gives an old answer names this conversation
/// does not know. The same file now keeps its names, which is the point of
/// item 2; an edited one honestly does not, which is why item 1 had to exist
/// first.
const _edited = 'Sehr geehrte Frau Hedvig Palmgren,\n'
    'der Kontostand von GB29 NWBK 6016 1331 9268 19 beträgt 42 900 EUR.\n';

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

/// The style of the drawn run whose text is exactly [text].
///
/// Read from the span tree, so what is asserted is the decoration the screen
/// asked for — the thing this change is about.
TextStyle? _styleOf(WidgetTester tester, String text) {
  final texts = tester.widgetList<SelectableText>(
    find.descendant(of: find.byType(AnswerPanel), matching: find.byType(SelectableText)),
  );
  for (final t in texts) {
    TextStyle? found;
    t.textSpan?.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.style;
        return false;
      }
      return true;
    });
    if (found != null) return found;
  }
  return null;
}

/// One working day in a client's profile: the letter, the account protected so
/// the **vault keeps it**, and the text that would go to a model.
Future<(Workbench, String)> _aDay(
  WidgetTester tester,
  String profile, {
  String document = _letter,
}) async {
  late Workbench bench;
  late String text;
  await tester.runAsync(() async {
    final session = await z.openSession(profileId: profile, packId: 'de');
    bench = Workbench(session: session, profileId: profile, packId: 'de');
    await z.importText(session: session, text: document);
    await bench.rescan();
    const iban = 'GB29 NWBK 6016 1331 9268 19';
    final at = document.indexOf(iban);
    await bench.select(Span(start: at, end: at + iban.length));
    await bench.protectSelection(scope: Scope.profile, kind: Kind.iban, allMatches: false);
    await bench.refresh();
    text = bench.payload!.text;
  });
  return (bench, text);
}

String _tokenIn(String text, String kind) {
  for (final word in text.split(RegExp(r'\s+'))) {
    final w = word.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    if (w.startsWith('__Z_') && w.endsWith('__') && w.contains(kind)) return w;
  }
  throw StateError('no $kind token in «$text»');
}

Future<String> _aProfile(WidgetTester tester, Ground ground, String name) async {
  late String id;
  await tester.runAsync(() async {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-days-$name-$pid');
    if (here.existsSync()) here.deleteSync(recursive: true);
    addTearDown(() {
      if (here.existsSync()) here.deleteSync(recursive: true);
    });
    await z.setDataDir(dir: here.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    await ground.refresh();
    id = await z.createProfile(name: 'Nordstern', session: null);
  });
  return id;
}

Future<void> _pump(WidgetTester tester, Workbench bench) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SizedBox(width: 760, child: AnswerPanel(bench: bench, width: 760))),
  ));
  await settle(tester);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('an answer from another conversation says so, by name, above the answer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    final profile = await _aProfile(tester, ground, 'band');

    // Monday.
    final (monday, mondayText) = await _aDay(tester, profile);
    final oldIban = _tokenIn(mondayText, '_IBAN_');
    final oldPerson = _tokenIn(mondayText, '_PERSON_');
    await tester.runAsync(() async {
      await z.closeSession(session: monday.session);
    });
    monday.dispose();

    // Friday — one figure changed, so another document, the same client, and
    // Monday's answer in hand.
    final (friday, _) = await _aDay(tester, profile, document: _edited);
    addTearDown(friday.dispose);
    final fromMonday = 'I checked $oldIban for $oldPerson: the balance is 42 500.';
    await tester.runAsync(() async {
      friday.rememberCopiedPayload();
      await friday.pasteAnswer(fromMonday);
    });
    await _pump(tester, friday);

    // **The band, above the answer.**
    expect(find.byKey(AnswerPanel.unresolved), findsOneWidget,
        reason: 'the answer came back with nothing said about it');
    expect(
      find.textContaining('2 tokens this conversation does not know', findRichText: true),
      findsOneWidget,
      reason: 'the count is not on the screen',
    );
    // **Named**, because a count on its own is a claim and the names are what
    // let a person find them in the text in front of them.
    expect(find.textContaining(oldIban, findRichText: true), findsWidgets,
        reason: 'the token is not named');
    expect(find.textContaining(oldPerson, findRichText: true), findsWidgets,
        reason: 'the second token is not named');

    // **And not drawn as the answer.** This is the assertion that makes it a
    // fix: the run carrying the token is struck through, so no reading of the
    // sentence can take it for the model's own words.
    final struck = _styleOf(tester, oldIban);
    expect(struck, isNotNull, reason: 'the token is not drawn as its own run');
    expect(struck!.decoration, TextDecoration.lineThrough,
        reason: 'the token is drawn like the rest of the sentence');
    expect(struck.color, Zc.amber, reason: 'amber is this app’s «not decided» and nothing else is');
  });

  testWidgets('this conversation’s own answer restores with nothing said', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    final profile = await _aProfile(tester, ground, 'control');

    final (today, text) = await _aDay(tester, profile);
    addTearDown(today.dispose);
    final iban = _tokenIn(text, '_IBAN_');
    await tester.runAsync(() async {
      today.rememberCopiedPayload();
      await today.pasteAnswer('I checked $iban: the balance is 42 500.');
    });
    await _pump(tester, today);

    // **The control.** A warning that fires on an ordinary answer is worse than
    // no warning, and this is the case the band must stay out of.
    expect(find.byKey(AnswerPanel.unresolved), findsNothing,
        reason: 'the band fired on an answer this conversation made');
    final put = _styleOf(tester, 'GB29 NWBK 6016 1331 9268 19');
    expect(put, isNotNull, reason: 'the account was not put back');
    expect(put!.decorationStyle, TextDecorationStyle.dotted,
        reason: 'put back here, locally — the fourth mark');
  });
}

// **079 on the glass: a document that came back** — the import side.
//
// The core's half is in `z_core/tests/a_document_that_comes_back_is_translated.rs`,
// watched red break by break, and the hand's half in
// `a_returning_document_is_not_protected_again.rs`. These are the two things a
// person sees:
//
//   * **the line under the band**, which says whose names these are, how many
//     came back, and — since 089 — why any name that is still a token could not
//     be read: it came from a conversation this vault does not hold, or it was
//     protected before this build began keeping every protected word. The
//     sentence that stood here until 15 October said «this conversation's own
//     names are kept only while it is open», and the owner withdrew it;
//   * **no Protect press over a token**, because one would mint a second token
//     over the first and the answer would come back unreadable.
//
// And the one thing they must not see: that line over an ordinary document.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/protecting.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/the_way_back.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

const _pass = 'ein genügend langes kennwort hier';

/// A German answer carrying the tokens of a conversation this machine does not
/// hold — which is what a document from another machine looks like, and the
/// honest case to draw: nothing can be brought back, and the line says so by
/// the namespace's own four digits.
const _back =
    'Sehr geehrter Herr __Z_7f3a_PERSON_9b21__,\n'
    '\n'
    'wir haben Ihre Zahlung auf die IBAN __Z_7f3a_IBAN_4c18__ erhalten.\n'
    'Telefon: __Z_7f3a_PHONE_2b55__\n';

/// An ordinary German letter, with nothing of ours in it.
const _plain =
    'Sehr geehrter Herr Stefan Keller,\n'
    '\n'
    'wir haben Ihre Zahlung erhalten. Vielen Dank.\n';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Span _spanOf(String doc, String needle) {
  final at = doc.indexOf(needle);
  return Span(start: at, end: at + needle.length);
}

void main() {
  late Directory dir;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
    dir = Directory('${Directory.systemTemp.path}/zprivacy-came-back-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
    // **A vault, open, for every test here but the last.** It is not scenery:
    // the app refuses to begin without one (041-N), so a returning document
    // can only arrive on a bench with an open vault — and with none open the
    // door can name no conversation at all, which is the last test's own
    // measurement rather than the state the others should be read in.
    await z.vaultCreateWithPassphrase(passphrase: _pass);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// The workspace over one document, read through the **real** door: the core
  /// scans as it imports (item 3) and the bench reads both answers in one call,
  /// so nothing here remembers to ask the returning-document question.
  Future<Workbench> ready(WidgetTester tester, String doc) async {
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.readTheScanThatArrivedWithIt();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await settle(tester);
    return bench;
  }

  testWidgets('a document that came back says so, and says where its names are from', (tester) async {
    final bench = await ready(tester, _back);

    // The core answered at the import door, through the one call the bench
    // makes — not because this test asked.
    expect(bench.returned, isNotNull, reason: 'the bench never asked whether it came back');
    expect(bench.returned!.tokens, 3, reason: 'the core read ${bench.returned!.tokens} places');
    expect(bench.returned!.names, 3);
    expect(bench.returned!.broughtBack, 0);
    expect(bench.returned!.unresolved.length, 3);
    expect(bench.returned!.unknownNamespaces, ['7f3a']);

    // **The sentence, on the glass**, read as the person reads it so that a
    // change to the wording is a red here and not a silent rewording.
    //
    // This document's names are from a namespace no conversation of this vault
    // holds — another machine — so that is the cause the line names, with the
    // count and the handle. It does **not** say «protected before Z Privacy
    // began keeping every protected word», because that cause belongs to the
    // names whose conversation is here and these have none (089 rule 4).
    final said = find.textContaining('3 names from a conversation this vault does not hold');
    expect(said, findsOneWidget, reason: 'the line that says where these names are from is not drawn');
    final line = tester.widget<Text>(said.first).data!;
    expect(line, contains('7f3a'), reason: 'the line does not name the namespace: $line');
    expect(
      line,
      isNot(contains('kept only while')),
      reason: 'the withdrawn sentence is still on the glass: $line',
    );
    // One place words it: the strip draws what `messages.dart` says.
    expect(line, whatCameBack(bench.returned!));
  });

  testWidgets('an ordinary document draws no such line', (tester) async {
    final bench = await ready(tester, _plain);
    expect(bench.returned, isNotNull);
    expect(bench.returned!.tokens, 0, reason: 'a letter with no token in it was read as one');
    expect(whatCameBack(bench.returned!), isNull);
    expect(find.textContaining('stay as tokens'), findsNothing);
    expect(find.textContaining('came back from'), findsNothing);
    // The control: this document is scanned and protected as any other, so the
    // absence above is «nothing came back» and not «nothing happened».
    expect(bench.scanOrigin, ScanOrigin.onImport);
    expect(bench.snap!.autoProtected, greaterThan(0),
        reason: 'the ordinary letter was not protected, so the comparison says nothing');
  });

  testWidgets('no Protect press is offered over a token, and the line says why', (tester) async {
    final bench = await ready(tester, _back);
    await tester.runAsync(() => bench.select(_spanOf(_back, '__Z_7f3a_PHONE_2b55__')));
    await settle(tester, rounds: 3);

    // The core's own answer about the span Protect would take.
    expect(bench.selected!.onAToken, isTrue);
    expect(protectStateOf(bench.selected), ProtectState.alreadyOurs);

    final button = tester.widget<ZButton>(find.widgetWithText(ZButton, 'Protect'));
    expect(button.onPressed, isNull, reason: 'Protect can be pressed over a token');
    expect(button.hint, theTokenIsAlreadyOurs,
        reason: 'the disabled press does not say why — «${button.hint}»');
    // And no second press beside it that would reach across the token: «also
    // the word before» widens the selection and protects it, so over
    // «Telefon: __Z_…__» it is the same act by another name.
    expect(find.widgetWithText(ZButton, 'Also the word before'), findsNothing,
        reason: 'a press is offered that would protect across the token');

    // Nothing was minted by looking at it.
    expect(bench.tokens, isEmpty);
    expect(bench.payload!.text, contains('__Z_7f3a_PHONE_2b55__'));
  });

  testWidgets('the whole way round: protect, take it out, bring it back, read it', (tester) async {
    // **The owner's own Friday**, through the glass and the real doors: a
    // German letter protected, taken out at the exit that mints the answer
    // page, and the answer brought back in. Nothing is faked — the text that
    // comes back is the text the exit handed out.
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _plain);
      // Protected by hand, so the name in the letter is one this conversation
      // minted and nothing else in the tree knows.
      await z.protect(
        session: session,
        span: _spanOf(_plain, 'Stefan Keller'),
        scope: Scope.conversation,
        kind: Kind.person,
      );
      await z.conversationBegin(name: 'die Mahnung', bench: session);
      final taken = await z.payloadToTakeOut(session: session);
      // The answer: the protected pages, a reply, and the answer page's line.
      final back = '${taken.text}\n\nVielen Dank.\n\nZ-pdf : ${taken.answerPageToken}\n';
      await z.importText(session: session, text: back);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.readTheScanThatArrivedWithIt();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await settle(tester);

    // The core recognised it, named the conversation, and brought the name back.
    expect(bench.returned!.conversations.length, 1);
    expect(bench.returned!.conversations.first.name, 'die Mahnung');
    expect(bench.returned!.conversations.first.answerPage, isTrue,
        reason: 'the answer page did not prove where this document came from');
    // **Two names, since 085 ruling 1** (15 October): the import scans, so the
    // salutation had already protected «Stefan» and «Keller» as a token each
    // before the hand reached them, and both come back.
    expect(bench.returned!.broughtBack, 2);
    expect(bench.returned!.unresolved, isEmpty);
    expect(find.textContaining('2 names came back from «die Mahnung»'), findsOneWidget);
    // Nothing about names staying tokens, because none did.
    expect(find.textContaining('stay as tokens'), findsNothing);

    // **A press, not a side effect**: the reading opens because a person asked.
    expect(find.widgetWithText(ZButton, 'Read it back'), findsOneWidget);
    await tester.tap(find.widgetWithText(ZButton, 'Read it back'));
    await settle(tester, rounds: 4);
    expect(find.text('Read back'), findsOneWidget, reason: 'the reading did not open');

    // The value is on the glass, and no token is.
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join('\n');
    expect(shown, contains('Stefan Keller'), reason: 'the name did not come back on the glass');
    expect(shown, contains('Vielen Dank'), reason: 'the reply was dropped');
    expect(shown, contains('Z-pdf : Zprivacy-svara'),
        reason: 'the answer page read as a token instead of its own word');
    expect(shown.contains('__Z_'), isFalse, reason: 'a token is still standing in the reading');

    // And the document on the bench is untouched: what the exits may take out
    // is still the text that arrived, not the reading.
    expect(bench.document!.text, contains('__Z_'));
  });

  testWidgets('with the vault shut it names no conversation, and says which act opens it',
      (tester) async {
    // **The second case of the rule the first one is written at.** With no
    // vault open, the namespace is derived from a key this machine cannot
    // reach: every namespace would be reported as one no conversation here
    // holds, which is false and names the wrong cause. So the vault answers
    // first, and the sentence carries the act that answers it.
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ground = Ground();
    late final Workbench sender;
    late final String back;
    late final int number;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _plain);
      await z.protect(
        session: session,
        span: _spanOf(_plain, 'Stefan Keller'),
        scope: Scope.conversation,
        kind: Kind.person,
      );
      await z.conversationBegin(name: 'die zweite Mahnung', bench: session);
      number = (await z.conversationOpen())!;
      final taken = await z.payloadToTakeOut(session: session);
      back = '${taken.text}\n\nZ-pdf : ${taken.answerPageToken}\n';
      sender = Workbench(session: session, profileId: null, packId: 'de');
    });
    // The bench that minted the names is closed — which is what opening a
    // document does on the glass — and the vault is shut behind it.
    sender.dispose();
    await tester.runAsync(() async {
      await z.vaultLock();
      await ground.refresh();
    });

    late final Workbench bench;
    await tester.runAsync(() async {
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: back);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.readTheScanThatArrivedWithIt();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await settle(tester);

    expect(bench.returned!.vault, isNot(VaultState.unlocked));
    expect(bench.returned!.tokens, greaterThan(0), reason: 'the places are read with no vault');
    expect(bench.returned!.conversations, isEmpty);
    // **And not a word about a conversation this vault does not hold.**
    expect(find.textContaining('does not hold'), findsNothing);
    expect(find.textContaining('stay as tokens'), findsNothing);
    expect(find.textContaining('unlock or create your vault'), findsOneWidget,
        reason: 'the line does not say which act would answer it');
    expect(find.widgetWithText(ZButton, 'Read it back'), findsNothing,
        reason: 'a reading was offered when nothing could be read');

    // Open the vault and rescan — which is what a person does, and what the
    // band calls «after the vault opened». The door is asked again.
    await tester.runAsync(() async {
      await z.vaultUnlockWithPassphrase(passphrase: _pass);
      await ground.refresh();
      await bench.rescan();
    });
    await settle(tester, rounds: 3);

    expect(bench.returned!.vault, VaultState.unlocked);
    expect(bench.returned!.conversations.length, 1,
        reason: 'with the vault open the conversation is still not named');
    expect(bench.returned!.conversations.first.number, number);
    expect(bench.returned!.conversations.first.answerPage, isTrue,
        reason: 'the answer page is the only proof left once the bench is gone, and it was silent');
    expect(find.textContaining('came back from «die zweite Mahnung»'), findsOneWidget);
    // **And the name comes back** — 089 rules 1 and 4, on the glass, in the
    // owner's own case: nothing was ever taught to this vault, the bench that
    // minted the token is disposed of, the vault was locked and opened again,
    // and the word is still read because it is a block. This expectation was
    // `0` until 15 October, with «the line says so in the owner's own cost»
    // written over it.
    // **Two**, and the number is the measurement: «Stefan Keller» after a
    // salutation is one token per word since 085 ruling 1, so the letter left
    // with two names and two blocks were made. The press in this test asked
    // for the pair as one selection and met what the scan had already
    // protected — which is why the count is the document's, not the press's.
    expect(bench.returned!.broughtBack, 2,
        reason: 'the hand-protected name did not come back from its blocks');
    expect(find.textContaining('stay as tokens'), findsNothing,
        reason: 'a name was said to stay a token when the block brought it back');

    // And the reading opens — the press that was not offered while the vault
    // was shut, a few lines above, because then there was nothing to read.
    expect(find.widgetWithText(ZButton, 'Read it back'), findsOneWidget,
        reason: 'the reading was not offered once the blocks could answer');
    await tester.tap(find.widgetWithText(ZButton, 'Read it back'));
    await settle(tester, rounds: 4);
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join('\n');
    expect(shown, contains('Stefan Keller'), reason: 'the block did not reach the glass');
    expect(shown.contains('__Z_'), isFalse, reason: 'a token is still standing in the reading');
  });

  testWidgets('the door that refuses it words it the same way', (tester) async {
    final bench = await ready(tester, _back);
    final span = _spanOf(_back, '__Z_7f3a_IBAN_4c18__');
    // The press the button does not offer, made at the core's door anyway —
    // which is the reason the law is in both places.
    late final ProtectOutcome outcome;
    await tester.runAsync(() async {
      outcome = await z.protect(
        session: bench.session,
        span: span,
        scope: Scope.conversation,
        kind: Kind.iban,
      );
    });
    expect(outcome, isA<ProtectOutcome_StandsOnAToken>());
    expect(
      (outcome as ProtectOutcome_StandsOnAToken).token,
      '__Z_7f3a_IBAN_4c18__',
      reason: 'the refusal does not name the token standing there',
    );
    await tester.runAsync(() => bench.refresh());
    await settle(tester, rounds: 2);
    expect(bench.tokens, isEmpty, reason: 'a token was minted over a token');
  });

  // ------------------------------------------------------------- 089 rule 5
  //
  // **The explicit door, and the reading both doors show.** 079 rule 3 was
  // decided on 13 October and never built: the only way back was to open the
  // file as a document and press the banner. The owner asked for the button
  // again on 15 October — «نفس هذا الزر نحتاجه الآن» — and the core's half of
  // it is a door with no session in its signature, so «never scanned, never
  // protected» is a state this screen cannot reach (G34, and
  // `z_core/tests/the_door_back.rs`).

  testWidgets('the + menu offers the way back, and it is not the way in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());
    var toWorkOn = 0;
    var cameBack = 0;

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        ground: ground,
        version: 'z_core 0.1.0',
        onImport: () => toWorkOn += 1,
        onReadBack: () => cameBack += 1,
        onType: (_) {},
        onAsk: (_) async {},
        onVault: () {},
        onSettings: () {},
      ),
    ));
    await settle(tester, rounds: 2);

    // The «+» is still one press and still says what it is for.
    final plus = find.byTooltip('Add a document — PDF, Word or text');
    expect(plus, findsOneWidget);
    await tester.tap(plus);
    await tester.pumpAndSettle();

    expect(find.text('Add a document'), findsOneWidget,
        reason: 'the + lost the entry it has always had');
    expect(
      find.text('z-pdf — read a protected document back'),
      findsOneWidget,
      reason: 'the + menu has no «z-pdf» entry: 079 rule 3 is still unbuilt',
    );

    // **One press opens it**, and it is the other door: a file coming back is
    // not a file to work on, and the two callbacks are two acts.
    await tester.tap(find.text('z-pdf — read a protected document back'));
    await tester.pumpAndSettle();
    expect(cameBack, 1, reason: 'the z-pdf entry opened nothing');
    expect(toWorkOn, 0, reason: 'the z-pdf entry opened the ordinary import door');

    // The control: the first entry still does what it did, so the number above
    // is «the right door» and not «the only door left».
    await tester.tap(plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a document'));
    await tester.pumpAndSettle();
    expect(toWorkOn, 1, reason: 'the ordinary import door stopped working');
    expect(cameBack, 1);
  });

  testWidgets('the reading names every token that stayed a token', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // A reading as the core hands one back: a value put back, a token that
    // stayed one, and the words between them. Built here rather than measured
    // through the door, because what is under test is the drawing — the door
    // itself is measured in Rust, on files.
    const seen = ReturnedDocument(
      restored: [
        Segment(text: 'Sehr geehrter Herr ', piece: Piece.words),
        Segment(text: 'Stefan Keller', piece: Piece.restored),
        Segment(text: ', Ihre IBAN ', piece: Piece.words),
        Segment(text: '__Z_7f3a_IBAN_4c18__', piece: Piece.unresolved),
        Segment(text: ' ist notiert.', piece: Piece.words),
      ],
      tokens: 2,
      vault: VaultState.unlocked,
      names: 2,
      broughtBack: 1,
      unresolved: ['__Z_7f3a_IBAN_4c18__'],
      conversations: [
        ReturnedFrom(number: 1, name: 'die Mahnung', broughtBack: 1, unresolved: 1, answerPage: false),
      ],
      unknownNamespaces: [],
    );

    await tester.pumpWidget(const MaterialApp(home: TheReading(seen: seen)));
    await tester.pumpAndSettle();

    // The reading itself is one `Text.rich`, and `find.text` is blind to those
    // — so it is read through its own spans, which is also the only way to see
    // that a value really was put back where it stood.
    final rich = tester
        .widgetList<Text>(find.byType(Text))
        .where((w) => w.textSpan != null)
        .map((w) => w.textSpan!.toPlainText())
        .join('\n');
    expect(rich, contains('Stefan Keller'), reason: 'the value was not put back in the reading');
    expect(rich, contains('__Z_7f3a_IBAN_4c18__'),
        reason: 'a token that stayed a token was dropped from the reading');

    // And it is **named**, one by one, beside the reading — 079 rule 7: never
    // silently dropped. This is a plain `Text`, which is why `find.text` sees
    // exactly one of them and not the one standing in the rich text above.
    expect(find.text('What stayed a token'), findsOneWidget,
        reason: 'the reading does not name what stayed a token');
    expect(find.text('__Z_7f3a_IBAN_4c18__'), findsOneWidget,
        reason: 'the token was marked in place and never named on its own');

    // The sentence over it is the one place that counts them.
    expect(find.text(whatCameBack(seen)!), findsOneWidget);
  });
}

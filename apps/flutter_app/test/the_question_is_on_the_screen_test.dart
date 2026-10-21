// 046/N on the screen · the request, and the column that says what leaves.
//
// **The owner, 7 October:** «ليس لدينا شات — شات مع نموذج. بمعنى أنه إذا لدينا
// وثيقة مشفرة وكل شيء فيها تمام، ماذا يحصل عند الانتقال إلى الخطوة التالية؟
// نحتاج إلى نسخ الملف.»
//
// The core half is in `z_core/tests/the_question_travels_with_it.rs`. Here is
// the half a person touches, and the one assertion that matters most:
// **a name typed into the field is a token in the Safe column before anything
// is pressed.** The field does not scan itself — `setQuestion` hands the
// sentence to the core — so what this file proves is that the screen shows the
// core's answer and not its own.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/the_chat.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// A German letter with a person the salutation proves, so the document has a
/// token to lend the question.
const _doc = 'Ansprechpartner: Herr Thomas Müller\nBetrag: 42 500\n';

const _field = ValueKey<String>('workspace-question');
const _attach = ValueKey<String>('workspace-question-attach');

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

/// `vault: true` makes one before the document is opened, which only the guard
/// that needs a **session** asks for: a session is born at an exit (rule 55)
/// and it renames this document's tokens from its own key, so there has to be
/// a key. The other guards here are about the request in the column and are
/// left exactly as they were — a vault in all of them would be a condition
/// nobody measured.
Future<(Ground, Workbench)> _open(
  WidgetTester tester,
  String name, {
  bool vault = false,
}) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-ask-$name-$pid');
    removeWhenItLetsGo(here);
    addTearDown(() {
      removeWhenItLetsGo(here);
    });
    await z.vaultLock();
    await z.setDataDir(dir: here.path);
    if (vault) await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort dafür');
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    // Every question answered, so the only thing under test is the request.
    for (final f in bench.suggested) {
      await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
    }
    await bench.refresh();
  });
  addTearDown(bench.dispose);
  await tester.pumpWidget(MaterialApp(
    home: WorkspaceScreen(bench: bench, ground: ground, onImport: () {}, onAsk: (_) {}, onVault: () {}),
  ));
  await settle(tester);
  return (ground, bench);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  testWidgets('a name typed into the request is a token in the Safe column', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'token');

    expect(find.text('What should the AI do with this?'), findsOneWidget,
        reason: 'there is no door to a model from the document');
    final before = bench.payload!.text;
    expect(before.contains('--- Request ---'), isFalse);

    await tester.enterText(find.byKey(_field), 'What did Thomas Müller earn?');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);

    final after = bench.payload!.text;
    expect(after, contains('--- Request ---'),
        reason: 'the request is not in the column that says what leaves');
    expect(after, isNot(contains('Thomas Müller')),
        reason: 'a name a person typed is in the column in the clear');
    // The **same** token the document gave him, or the model cannot see that
    // the question is about somebody in the sheet.
    final token = before
        .split(RegExp(r'\s+'))
        .firstWhere((w) => w.startsWith('__Z_'), orElse: () => '');
    expect(token, isNotEmpty, reason: 'the document protected nobody, so this proves nothing');
    expect(after.split('--- Request ---').last, contains(token),
        reason: 'the request minted a second token for one person');

    // And the screen says what the core did, with the core's own number.
    // Two values since 085 ruling 1 (15 October): the name he typed is a given
    // name and a surname, and each is a token of its own.
    expect(find.textContaining('2 values replaced'), findsOneWidget);

    // ----------------------------------------------------------- 096, 72-ب
    //
    // **And the first part draws that request as original text.** Until now
    // the request lived in the box and nowhere else, so a word in it could not
    // be covered by hand and a suggestion in it was reviewed nowhere. The core
    // hands one text with one offset space; this measures that the glass draws
    // *that* text and those marks, and not a second copy of its own.
    final entered = bench.entered!;
    final original = tester.widget<OriginalText>(find.byType(OriginalText));
    expect(original.text, entered.text,
        reason: 'the first part draws something other than the one entered text');
    expect(original.marks, entered.marks,
        reason: 'the first part draws its own marks instead of the core\'s');

    // The request is in that text, in the clear, after where the core says it
    // begins — `requestBegins` is **read** and never counted here.
    final typedAt = entered.text.indexOf('Thomas Müller', entered.requestBegins);
    expect(typedAt, greaterThanOrEqualTo(entered.requestBegins),
        reason: 'the name typed into the request is not in the request half');
    expect(entered.marks.any((m) => m.span.start <= typedAt && m.span.end > typedAt),
        isTrue,
        reason: 'the name in the request is drawn without the cover the same '
            'name has in the document');

  });

  /// **A hand reaches a word in the request through the same door** — 096,
  /// rule 72-ب, and the guard that crosses the seam.
  ///
  /// **This one was red on purpose for a day**, by the lead's ruling, because
  /// it is the only guard in either half that can fail while both halves are
  /// green: a seam with a sound guard on each side and nothing across it is
  /// how two finished halves make one broken product. It drives the glass's
  /// own path — `select()` replaces what the person drew with `view.wordSpan`
  /// from `inspect_selection` (041-K, «what the core will take is what the
  /// screen shows») — and asks the core's own answer back. Measured on
  /// `e610c63`, before the fix:
  ///
  /// ```text
  /// requestBegins 69 · the text at 92 is «earn»
  /// select(Span(92, 96))  →  selection 22..28  =  «Thomas», in the document
  /// protectSelection(…)   →  alreadyProtected(__Z_…_PERSON_…, de:salutation)
  /// ```
  ///
  /// A hand drawn over a word in the request protected a word in the document
  /// that nobody had pointed at, with no refusal and no sentence — in a tool
  /// whose whole promise is about which words leave.
  ///
  /// **It went green at `072ab1f` with nothing here changed**, which is the
  /// claim this file is allowed to make about the core. The cause was not the
  /// one line reported from the glass: `inspect_selection` needed the shift in
  /// **five** places and four of them had written the document's name instead,
  /// while the fifth — the snapshot's — had the arithmetic right in its own
  /// spelling, and one law in two spellings is how the other four came to be
  /// wrong. The shift now has a name and is asked for by it,
  /// `span_in_the_entered` in `z_core/src/ops/mod.rs`. ed's own Rust guards had
  /// called `protect` directly with an entered-space span and never passed
  /// through `inspect_selection`, which is why both halves could be green: the
  /// one door the glass always goes through was the one door no guard asked
  /// about.
  testWidgets('a hand selection in the request covers that word, and not 22..28 in the document', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'byhand');

    await tester.enterText(find.byKey(_field), 'What did Thomas Müller earn?');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);

    final entered = bench.entered!;
    // «earn»
    // is nobody's name and no rule finds it, so a cover over it can only be
    // the person's own — and it has to work in the request as it does in the
    // document.
    final earn = entered.text.indexOf('earn', entered.requestBegins);
    expect(earn, greaterThan(entered.requestBegins), reason: 'the word is not in the request');
    ProtectOutcome? said;
    Span? snapped;
    await tester.runAsync(() async {
      await bench.select(Span(start: earn, end: earn + 'earn'.length));
      snapped = bench.selection;
      said = await bench.protectSelection(
          scope: Scope.once, kind: Kind.project, allMatches: false);
      await bench.select(null);
    });
    expect(snapped, isNotNull, reason: 'the core refused to inspect the selection');
    expect(snapped!.start, earn,
        reason: 'the core snapped a selection at $earn «earn» out to '
            '${snapped!.start}..${snapped!.end} '
            '«${entered.text.substring(snapped!.start, snapped!.end)}»');
    expect(said, isNotNull, reason: 'the door answered nothing at all');
    await settle(tester, rounds: 12);

    final covered = bench.entered!;
    // The reason names what it saw: a cover that landed on another offset and
    // a cover that never happened are two different faults, and a bare «false»
    // tells them apart for nobody.
    final inRequest = covered.marks
        .map((m) => '${m.span.start}..${m.span.end} '
            '«${covered.text.substring(m.span.start, m.span.end)}» ${m.token}')
        .join(' | ');
    expect(covered.marks.any((m) => m.span.start == earn), isTrue,
        reason: 'a hand selection at $earn covered nothing. The door answered '
            '${said.runtimeType}. requestBegins=${covered.requestBegins}, '
            'the slice at $earn is «${covered.text.substring(earn, earn + 4)}», '
            'every cover is [$inRequest], and the app said «${bench.trouble ?? ''}»');
    expect(bench.payload!.text, isNot(contains('earn')),
        reason: 'the word covered by hand in the request still leaves in the clear');
  });

  /// **No unprotected text in the middle part** — 096's new guard, rule 35 and
  /// rule 72-ب together.
  ///
  /// The middle column had two drawings: the payload, and a footer carrying
  /// `questionSafe` for the case where a request stood with no document. Two
  /// drawings of what leaves are two things to keep true, and the day one of
  /// them is built from something other than the payload is the day the middle
  /// shows a person text that is not what the AI receives. So the law is the
  /// strongest form of it: **the middle draws the payload's own text, and
  /// nothing else.**
  testWidgets('no unprotected text stands in the middle part', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'middle');

    String middleNow() => tester.widget<SafeText>(find.byType(SafeText)).text;

    // Before anything is asked: one drawing, and it is the payload's.
    expect(middleNow(), bench.payload!.text,
        reason: 'the middle draws something other than what leaves');
    expect(middleNow(), isNot(contains('Thomas Müller')),
        reason: 'the document\'s own name stands in the middle in the clear');

    await tester.enterText(find.byKey(_field), 'What did Thomas Müller earn?');
    await settle(tester, rounds: 2);
    // **Typed and not yet sent**: the box holds it, and the middle may not
    // have grown a second drawing of it in the clear.
    expect(middleNow(), isNot(contains('Thomas Müller')),
        reason: 'a name typed into the box reached the middle before it was protected');

    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);

    // And after: still one drawing, still the payload's, the name replaced.
    expect(middleNow(), bench.payload!.text,
        reason: 'the middle grew a second drawing of what leaves');
    expect(middleNow(), isNot(contains('Thomas Müller')),
        reason: 'the name a person typed stands in the middle in the clear');
    expect(middleNow(), contains('__Z_'),
        reason: 'nothing in the middle is a token, so this proves nothing');
    expect(find.byType(SafeText), findsOneWidget,
        reason: 'the middle draws what leaves in two places');
  });

  /// **The sentence that is gone, because it became false** — rule 67.
  ///
  /// It said «Each question is asked on its own: the model does not see the
  /// earlier ones», and it was true for as long as `askModelProtected` passed
  /// `history: const []`. The owner found what that cost — «لا أستطيع أن أتابع
  /// الشات معه على نفس الموضوع» — and the core now carries the turns of the
  /// open chat with every later question. A sentence that was honest while the
  /// debt stood is a lie the moment it is paid, so this test is turned over: it
  /// measures that the sentence is **not** on the glass, which is the one way
  /// a line removed in one round does not come back in the next one.
  ///
  /// The other half of the pair stays for now and is measured below: the
  /// **request** is replaced, and the **answers** are kept — two different
  /// things, and a line saying only «the second question replaces this» is
  /// true of the request and misleading about what a person can still see.
  testWidgets('the screen no longer says that each question is asked alone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'alone');

    await tester.enterText(find.byKey(_field), 'Summarise it.');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);

    expect(
      find.textContaining('the model does not see the earlier ones'),
      findsNothing,
      reason: 'the screen tells a person the model has no memory of the '
          'earlier questions, and since rule 67 it has one',
    );
    // And the other half of the pair: what is replaced, and what is kept. The
    // wording moved with rule 65 — «the answers are kept» became «the chat
    // keeps every exchange», which is where they are kept now and the word the
    // owner's own ruling uses for this part (G41 reads every sentence for it).
    // The claim is the one that was always being measured: both halves are
    // said, so neither is read as loss.
    expect(find.textContaining('a new question replaces this one'), findsOneWidget);
    expect(
      find.textContaining('the chat keeps every exchange'),
      findsOneWidget,
      reason: 'the screen says the request is replaced and is silent about the '
          'answers, which is the half a person would read as loss',
    );
    expect(bench.question, 'Summarise it.');
  });

  /// **The pair, in the thread** — rules 65 and 66.
  ///
  /// The owner asked that the answer appear under the question rather than in a
  /// third screen, and 046/N's answer was a quote at the head of the panel,
  /// following its «Restored / As the model wrote it» tab. The chat answers it
  /// better and with no tab at all: the question stands immediately above the
  /// answer it was asked with, both **coded** — what actually travelled — and
  /// the restored text is one press away, per answer.
  ///
  /// So the assertion that moved is the one that mattered: the pair is legible,
  /// and neither side of it claims the model read a name it never saw.
  testWidgets('the chat shows the question above its answer, as it left', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, bench) = await _open(tester, 'quoted', vault: true);

    await tester.enterText(find.byKey(_field), 'What did Thomas Müller earn?');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);

    // An answer through the door that works offline: the safe text goes out by
    // hand and comes back. The thread then has a turn to draw.
    //
    // **The session is already there, and that is now measured rather than
    // arranged.** Five lines stood here that began one by hand, because the
    // law used to live in the screen; the core births at the first document in
    // the preview (rule 55c) and at the first question that leaves with none
    // (rule 55-و), so a bench with a document on it has a session. Without one
    // the answer would be kept nowhere, the chat would have nothing to draw,
    // and the panel would say so in `theChatKeepsNothing` — an honest screen,
    // and not the shape rules 65 and 66 are about, which is why this asserts
    // instead of arranging.
    await tester.runAsync(() async {
      await ground.refresh();
      expect(ground.aSessionWouldBeBorn, isFalse,
          reason: 'the core kept no session for the document in the preview');
      bench.rememberCopiedPayload();
      await bench.pasteAnswer('They earned 42 500.');
    });
    await settle(tester, rounds: 12);

    expect(find.byType(TheChat), findsOneWidget, reason: 'the answer did not open the chat');
    inChat(String text) => find.descendant(
          of: find.byType(TheChat),
          matching: find.textContaining(text),
        );

    // **Both sides are coded**, and the thread says so of each: «you · coded»
    // above, the answerer and «coded» below.
    expect(inChat('you'), findsWidgets, reason: 'the question’s side is not named');
    expect(find.descendant(of: find.byType(TheChat), matching: find.text('coded')),
        findsWidgets, reason: 'the thread does not say that what it draws is coded');

    // **The question as it left**: the token, never the name. A thread that
    // quoted the person’s own sentence here would be saying the model read it.
    expect(inChat('__Z_'), findsWidgets, reason: 'the question is not drawn as it left');
    expect(inChat('Thomas Müller'), findsNothing,
        reason: 'the thread quotes a name the model never saw');

    // **And the question is above the answer**, which is the whole of what
    // 046/N asked for: read as a pair, in the order they happened.
    final sides = tester.widgetList<Text>(
      find.descendant(of: find.byType(TheChat), matching: find.byType(Text)),
    );
    expect(sides, isNotEmpty);
    final you = tester.getRect(find.descendant(
      of: find.byType(TheChat),
      matching: find.text('you'),
    ).first);
    final answered = tester.getRect(find.descendant(
      of: find.byType(TheChat),
      matching: find.byKey(TheChat.showTheText(0)),
    ));
    expect(you.top, lessThan(answered.top),
        reason: 'the question is drawn below the answer it was asked with');

    // **The names come back in the bubble, and only there** — rule 66.
    expect(inChat('42 500'), findsWidgets, reason: 'the answer is not in the thread');
    await tester.tap(find.byKey(TheChat.showTheText(0)));
    await settle(tester, rounds: 2);
    expect(find.byKey(TheChat.bubble(0)), findsOneWidget,
        reason: '«Show the text» opened no bubble');
    // No `dispose` here: `_open` registered one as a tear-down, and calling it
    // twice is an error the harness reports as a failure of the test.
  });

  testWidgets('taking the request out leaves the document as it was', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'out');
    final bare = bench.payload!.text;

    await tester.enterText(find.byKey(_field), 'Summarise it.');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);
    expect(bench.payload!.text, isNot(bare));

    await tester.tap(find.widgetWithText(ZButton, 'Take it out'));
    await settle(tester, rounds: 16);
    expect(bench.payload!.text, bare,
        reason: 'taking the request out left something behind in what leaves');
  });

  testWidgets('the act says whether the request is in yet, and never says «Send»', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, bench) = await _open(tester, 'names');

    // Empty: the act is shut and says what an empty request means, because a
    // document may be sent with no instruction and that is not a failure.
    expect(
      tester.widget<ZButton>(find.widgetWithText(ZButton, 'Add it to what will leave')).onPressed,
      isNull,
    );
    expect(find.textContaining('no request'), findsOneWidget);

    await tester.enterText(find.byKey(_field), 'Summarise it.');
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(_attach));
    await settle(tester, rounds: 16);

    // Once it is in, the act says so rather than offering to do it again.
    expect(find.text('In what will leave'), findsOneWidget);
    // **This press never sends.** The word is not on this control, because the
    // gate and the review are still the only way out.
    expect(find.widgetWithText(ZButton, 'Send'), findsNothing);
    expect(bench.question, 'Summarise it.');
  });
}

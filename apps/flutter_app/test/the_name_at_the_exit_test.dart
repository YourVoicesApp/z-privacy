// 064 · The name at the exit — the question asked where the text leaves.
//
// The owner's rule: a session is born of the act that needs it, and the name is
// asked once, there. The panel's Sessions room is the deliberate path and has
// its own file; this one holds the other path — the person who never pressed
// that button and is one press away from taking text out of the machine.
//
// ## What this file can measure, and what it cannot
//
// **A widget that awaits the core does not resume under `testWidgets`.** It is
// why no test in this app presses «Create the vault», and it is written above
// `begin` in `a_session_is_a_room_in_the_panel_test.dart`. So the wire «this
// press reaches `conversationBegin` with `bench:`» is not provable here, and no
// guard below pretends to press it. What is provable, and is:
//
//   * the strip's three states, on the glass, each distinguishable from the
//     other two — the whole reason a person can know whose names are leaving;
//   * the doors staying live while the question stands: it asks, it does not gate;
//   * an empty name taking nothing out — by the clipboard, with its control
//     beside it, because a zero is only worth quoting next to a one;
//   * **the press copying what the bench holds at the press, not what the last
//     build captured** — a real press, a real clipboard probe;
//   * `beginThenRead`'s order, driven through the ground inside `runAsync`: the
//     text it hands back wears the session's names and none of the pre-birth
//     ones, and its sentence carries the core's own number.
//
// The other end of that last property is in the core, from the other seat:
// `every_token_that_leaves_belongs_to_the_session` in
// `z_core/tests/a_session_carries_its_own_key.rs`. Two files, one property,
// each holding its own end — and the wire between them named here rather than
// implied by a green press.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

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

/// One value the general rules protect on their own, and nothing else to argue
/// about: one token, so «the pre-birth name» is a single string to look for.
const _letter = 'Bitte überweisen Sie auf IBAN DE02120300000000202051 bis Freitag.';
const _other = 'Zahlung an IBAN DE44500105175407324931, Freitag bestätigt.';
const _nothingToProtect = 'Hej, allt är bra idag.';

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Directory _ownDir(String name) {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-exit-$name-$pid');
  if (own.existsSync()) own.deleteSync(recursive: true);
  addTearDown(() {
    if (own.existsSync()) own.deleteSync(recursive: true);
  });
  return own;
}

/// Captures clipboard writes — a widget test has no system clipboard.
///
/// A copy of `_ClipboardProbe` in `shell_test.dart:1674`, which is private to
/// that file, and of the smaller one in `copy_report_test.dart:57`. Three copies
/// of one instrument want a `test/support/` this suite does not have; inventing
/// that structure inside this round would be picking a surface nobody asked for,
/// so it is named here as a debt instead.
///
/// `text` starts at a sentinel so that a **false read** — a probe that answers
/// something nobody wrote — is visible as itself.
class _ClipboardProbe {
  _ClipboardProbe(this.tester);

  final WidgetTester tester;
  String? text = 'SENTINEL';
  int writes = 0;

  void install() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            writes += 1;
            final args = Map<String, dynamic>.from(call.arguments as Map);
            text = args['text'] as String?;
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

/// A bench with a scanned document, and the ground, with no widget at all.
Future<({Workbench bench, Ground ground})> _benchOnly(
  String name, {
  bool withAVault = true,
  String text = _letter,
}) async {
  final own = _ownDir(name);
  final ground = Ground();
  await z.vaultLock();
  await z.setDataDir(dir: own.path);
  if (withAVault) {
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för utgången');
  }
  final session = await z.openSession(profileId: null, packId: 'de');
  final bench = Workbench(session: session, profileId: null, packId: 'de');
  await z.importText(session: session, text: text);
  await bench.rescan();
  await ground.refresh();
  return (bench: bench, ground: ground);
}

/// The sheet, open on its second page — where the two exits are.
///
/// `Continue` is dead while the payload is null, so **arriving at the doors is
/// itself a measurement**: a guard that stands here has proven a payload exists
/// on the way in, and no guard in this file mounts the doors any other way.
Future<({Workbench bench, Ground ground, Directory out})> _atTheDoors(
  WidgetTester tester,
  String name, {
  bool withAVault = true,
  String text = _letter,
  bool toTheDoors = true,
}) async {
  late final ({Workbench bench, Ground ground}) made;
  await tester.runAsync(() async {
    made = await _benchOnly(name, withAVault: withAVault, text: text);
  });
  final out = _ownDir('$name-pdf')..createSync(recursive: true);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SendSheet(bench: made.bench, ground: made.ground, saveFolder: out.path),
    ),
  ));
  await _settle(tester);
  final onward = find.text('Continue');
  expect(onward, findsOneWidget, reason: 'the sheet did not open on its first page');
  expect(
    tester.widget<ZButton>(find.widgetWithText(ZButton, 'Continue')).onPressed,
    isNotNull,
    reason: 'Continue is dead, so there is no payload and this fixture proves nothing',
  );
  if (toTheDoors) {
    await tester.tap(onward);
    await _settle(tester);
  }
  return (bench: made.bench, ground: made.ground, out: out);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('the question stands on the page before the doors, and gates neither',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // **On the review page, not above the doors** — and that is a measured
    // placement, not a preference: the prose band is 202px and the doors page
    // has 124px of room with nothing connected, where it cost «Open Settings»
    // its place under the scroll. See `_theBand`'s own comment, and guard 8.
    final g = await _atTheDoors(tester, 'band', toTheDoors: false);

    expect(g.ground.vault, VaultState.unlocked, reason: 'the fixture has no vault');
    expect(g.ground.openSession, isNull, reason: 'the fixture already opened a session');

    // The sentence, scoped to the sheet — not `find.text` loose in the tree.
    expect(
      find.descendant(
        of: find.byType(SendSheet),
        matching: find.textContaining('has no session yet'),
      ),
      findsOneWidget,
      reason: 'the sheet does not say that these names belong to no session',
    );
    // The room's hint, word for word: two doors, one birth, one question.
    expect(find.textContaining('What is this one about?'), findsOneWidget,
        reason: 'the field does not ask the room’s question');
    expect(find.textContaining('behind this sheet'), findsOneWidget,
        reason: 'the sentence is not true from where it is read');

    // **In the tree is not on the glass.** A rect with a size, inside the
    // sheet's own box, inside the view.
    final band = find.byKey(SendSheet.theSessionBand);
    expect(band, findsOneWidget, reason: 'no band at all');
    final r = tester.getRect(band);
    final sheet = tester.getRect(find.byType(SendSheet));
    expect(r.width, greaterThan(100), reason: 'the band has no width');
    expect(r.height, greaterThan(40), reason: 'the band has no height');
    expect(r.left >= sheet.left - 0.5 && r.right <= sheet.right + 0.5, isTrue,
        reason: 'the band is $r, outside the sheet $sheet');
    expect(r.top >= sheet.top - 0.5 && r.bottom <= sheet.bottom + 0.5, isTrue,
        reason: 'the band is $r, outside the sheet $sheet');
    expect(r.right <= _wide.width && r.bottom <= _wide.height, isTrue,
        reason: 'the band is $r, off a ${_wide.width}×${_wide.height} view');

    // ---------------------------------------------------------------- guard 2
    // Onward to the doors: the question does not follow in prose, it follows
    // as one line that says what the press will do — and **both doors are live
    // in the same pump.** The question asks; it does not gate. Break: make it
    // a gate and watch this go red.
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(find.byKey(SendSheet.theSessionBand), findsNothing,
        reason: 'the prose band followed to the doors page, where it does not fit');
    expect(find.textContaining('either door begins it'), findsOneWidget,
        reason: 'the doors page says nothing about the session the press will begin');
    for (final label in ['Copy Protected', 'Save as PDF']) {
      expect(
        tester.widget<ZButton>(find.widgetWithText(ZButton, label)).onPressed,
        isNotNull,
        reason: '«$label» is dead while the question stands, so the band is a gate',
      );
    }
  });

  // ------------------------------------------------------------------ guard 3
  testWidgets('a session open: no question, and the line says whose names these are',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _atTheDoors(tester, 'open');

    // Through the ground, not the press — the harness, not the product.
    final renamed = await tester.runAsync(
      () => g.ground.beginSession('VAT questions', bench: g.bench.session),
    );
    expect(renamed, isNotNull, reason: 'the birth was refused: ${g.ground.trouble}');
    await tester.runAsync(() => g.bench.refresh());
    await _settle(tester);

    expect(find.byKey(SendSheet.theSessionBand), findsNothing,
        reason: 'the question is asked again although a session is open');
    expect(
      find.descendant(
        of: find.byType(SendSheet),
        matching: find.textContaining('VAT questions'),
      ),
      findsOneWidget,
      reason: 'the sheet does not name the session whose names are about to leave',
    );
    // This is the guard that proves the two states are **distinguishable**,
    // which is the whole reason the small line exists.
    expect(find.textContaining('has no session yet'), findsNothing);
  });

  // ------------------------------------------------------------------ guard 4
  testWidgets('a nameless press takes nothing out — and the same press, named, does',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    final g = await _atTheDoors(tester, 'nameless', toTheDoors: false);

    // Whitespace, not emptiness: a name that is only spaces is the same
    // question still unanswered, and the core cleans before it judges.
    expect(find.byKey(SendSheet.theSessionBand), findsOneWidget);
    await tester.enterText(find.byKey(SendSheet.theSessionName), '   ');
    await _settle(tester, rounds: 1);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Copy Protected'));
    await _settle(tester);

    expect(probe.writes, 0, reason: 'a nameless press copied');
    expect(probe.text, 'SENTINEL', reason: 'something was written to the clipboard');
    expect(g.out.listSync(), isEmpty, reason: 'a nameless press wrote a file');
    expect(find.textContaining('Give it a name first'), findsOneWidget,
        reason: 'nothing was copied and nothing said why');
    expect(g.ground.openSession, isNull, reason: 'a nameless press began a session');

    // **And it put the person at the field**, one page back, with the cursor
    // in it — not in a dead end telling them to go looking for it.
    expect(find.byKey(SendSheet.theSessionBand), findsOneWidget,
        reason: 'the refusal left the person away from the question it is about');
    final field = tester.widget<TextField>(find.byKey(SendSheet.theSessionName));
    expect(field.focusNode?.hasFocus, isTrue,
        reason: 'the field did not take the cursor, so the next keystroke goes nowhere');

    // **The control, in the same test.** The zero above is only worth quoting
    // beside this one: the same press, with a session, writes the payload.
    final renamed = await tester.runAsync(
      () => g.ground.beginSession('VAT questions', bench: g.bench.session),
    );
    expect(renamed, isNotNull, reason: 'the birth was refused: ${g.ground.trouble}');
    await tester.runAsync(() => g.bench.refresh());
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Copy Protected'));
    await _settle(tester);

    expect(probe.writes, 1, reason: 'the named press did not copy');
    expect(probe.text, g.bench.payload!.text, reason: 'the clipboard is not the payload');
  });

  // ------------------------------------------------------------------ guard 5
  testWidgets('the press copies what the bench holds now, not what the build captured',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    final g = await _atTheDoors(tester, 'fresh');

    // **A session first, through the ground.** Without one the band stands,
    // and a press with an empty field is refused for want of a name — which is
    // guard 4's property, not this one. Measured, not assumed: the first run of
    // this guard copied nothing, because `document.name` is empty for text that
    // was typed rather than opened, so the pre-filled field was empty.
    final renamed = await tester.runAsync(
      () => g.ground.beginSession('VAT questions', bench: g.bench.session),
    );
    expect(renamed, isNotNull, reason: 'the birth was refused: ${g.ground.trouble}');
    await tester.runAsync(() => g.bench.refresh());
    await _settle(tester);

    final captured = g.bench.payload!.text;
    final beforeToken = g.bench.tokens.first.token;

    // The document changes under the sheet, and **no frame is pumped after
    // it** — so the press lands on the tree that was built before the change
    // and its closure holds the older payload. That is the shape of the fault
    // a birth at the exit walks into: the act changes the bench, and nothing
    // rebuilds between the act and the clipboard.
    await tester.runAsync(() async {
      await z.importText(session: g.bench.session, text: _other);
      await g.bench.rescan();
    });
    final held = g.bench.payload!.text;
    expect(held, isNot(captured), reason: 'the fixture did not change the payload');

    await tester.tap(find.text('Copy Protected'));
    await _settle(tester);

    expect(probe.writes, 1, reason: 'the press did not copy');
    expect(probe.text, held, reason: 'the clipboard carries the captured text, not the bench’s');
    expect(probe.text!.contains(beforeToken), isFalse,
        reason: 'a token from before the change left this machine');
  });

  // ------------------------------------------------------------------ guard 6
  testWidgets('beginThenRead hands back the session’s names, and the core’s number',
      (tester) async {
    late final ({Workbench bench, Ground ground}) g;
    await tester.runAsync(() async => g = await _benchOnly('order'));

    final before = g.bench.payload!;
    final beforeToken = g.bench.tokens.first.token;
    expect(before.session, isNull, reason: 'the fixture already belongs to a session');
    expect(before.text.contains(beforeToken), isTrue, reason: 'the fixture protects nothing');

    final out = await tester.runAsync(
      () => beginThenRead(g.ground, g.bench, name: 'VAT questions'),
    );
    expect(out, isNotNull, reason: 'runAsync could not run the order at all');
    expect(out!.view, isNotNull, reason: 'nothing may leave: ${out.refused}');

    final view = out.view!;
    // Provenance: the text that would leave says which session it belongs to.
    expect(view.session?.name, 'VAT questions',
        reason: 'the text that would leave belongs to no session');
    // And what actually leaves: not one pre-birth name among it. This is the
    // property the core holds from its own end; here it is held of the string
    // the exit would put on the clipboard.
    expect(view.text.contains(beforeToken), isFalse,
        reason: 'the pre-birth name «$beforeToken» is still in the text that would leave');
    expect(view.text, isNot(before.text), reason: 'the text did not change at all');

    // The sentence is the core's number, in the house's one wording — never a
    // count of the screen's own.
    expect(out.renamed, isNotNull);
    expect(out.renamed, g.bench.tokens.length,
        reason: 'the core renamed ${out.renamed} of ${g.bench.tokens.length} tokens');
    expect(out.said, sessionBegunSaid(out.renamed!, hadDocument: true),
        reason: 'the exit writes its own wording instead of the house’s');
  });

  // ------------------------------------------------------------------ guard 6b
  test('a zero gets its own sentence, not «0 names»', () async {
    final g = await _benchOnly('zero', text: _nothingToProtect);
    expect(g.bench.tokens, isEmpty,
        reason: 'the fixture protects something, so this is not the zero case');

    final out = await beginThenRead(g.ground, g.bench, name: 'nothing in it');
    expect(out.view, isNotNull, reason: 'nothing may leave: ${out.refused}');
    expect(out.renamed, 0);
    expect(out.said, contains('needed renaming'),
        reason: 'the zero was printed as a number instead of being read aloud');
    expect(out.said, isNot(contains('0 ')), reason: '«0 names» is not a sentence');
  });

  // ------------------------------------------------------------------ guard 7
  //
  // **The question may not cost a door its place on the glass.** The human run
  // of 046/O lost Copy Protected, Paste AI answer and Send from here below the
  // window at 1280×720, and `shell_test`'s journeys were written to walk that
  // size rather than trust `takeException`. The band stands in exactly the
  // state the owner meets on a fresh machine — a vault, no session yet — so it
  // is measured at his smallest plausible window, with the band standing.
  //
  // It found what it was written to find: the band as first drawn pushed
  // «Direct API» 34px under the fold. The three doors' titles are asserted,
  // not the buttons, because a title is the door's own anchor and a scrolled
  // door is a door a person has to look for.
  testWidgets('the question standing leaves every door on the glass at 1280×720',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _atTheDoors(tester, 'small');
    expect(g.ground.theSessionQuestionStands, isTrue,
        reason: 'the question does not stand, so this measures nothing');
    expect(find.byKey(SendSheet.theSessionBand), findsNothing,
        reason: 'the prose band is on the doors page again — the 202px that cost a door');

    final view = tester.binding.renderViews.first.size;
    for (final label in ['Manual AI', 'Paste AI answer', 'Direct API']) {
      final it = find.text(label);
      expect(it, findsOneWidget, reason: '«$label» is not in the tree at all');
      final r = tester.getRect(it);
      expect(
        r.top >= -1 && r.bottom <= view.height + 1 && r.height > 8,
        isTrue,
        reason: '«$label» at $r is off a $view window while the question stands',
      );
    }
    expect(g.ground.openSession, isNull);
  });

  // ------------------------------------------------------------------ guard 8
  //
  // **A door must still answer while the question stands**, and a rect cannot
  // tell you that it will. Guard 7 holds the doors' places against the view;
  // this one presses, because the fault it was written for is invisible to a
  // rect: `the_keys_live_in_the_settings` went red with «Open Settings» at
  // y 850–893 on a 950-tall window — **inside the window and under the sheet's
  // own scroller**, clipped, with `tester.tap` deriving an offset that «would
  // not hit test on the specified widget». Only a press sees a clip.
  //
  // Reproduced here before it was fixed, so it is this file's finding and not
  // somebody's fixture. One thing it also measured, and reported rather than
  // absorbed: at **1280×720 with nothing connected that door is already under
  // the scroll with nothing of mine on the page** — switched off entirely and
  // the press still missed. That fault predates 064.
  testWidgets('with the question standing, the settings door still answers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var asked = 0;
    late final ({Workbench bench, Ground ground}) made;
    await tester.runAsync(() async => made = await _benchOnly('door'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SendSheet(
          bench: made.bench,
          ground: made.ground,
          onSettings: () => asked += 1,
        ),
      ),
    ));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(made.ground.theSessionQuestionStands, isTrue,
        reason: 'the question does not stand, so this measures nothing');

    final door = find.widgetWithText(ZButton, 'Open Settings');
    expect(door, findsWidgets, reason: 'no way to reach the one place a key is given');
    await tester.tap(door.first);
    await _settle(tester);
    expect(asked, 1, reason: 'the door is on the glass and did not answer the press');
  });

  // ---------------------------------------------------------- the vault is shut
  testWidgets('no vault: no question is asked, and the text says it has no session',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    final g = await _atTheDoors(tester, 'novault', withAVault: false);

    expect(g.ground.vault, isNot(VaultState.unlocked));
    // A question that cannot be answered is not asked: the keys are in the
    // vault, so no session could be born for this press to belong to.
    expect(find.byKey(SendSheet.theSessionBand), findsNothing,
        reason: 'the sheet asks for a session the shut vault cannot make');
    expect(find.textContaining('made for this document alone'), findsOneWidget,
        reason: 'nothing says these names belong to no session');

    // And the door still works, because protection never needed the vault.
    await tester.tap(find.text('Copy Protected'));
    await _settle(tester);
    expect(probe.writes, 1, reason: 'a shut vault stopped a copy that sends nothing');
    expect(probe.text, g.bench.payload!.text);
  });
}

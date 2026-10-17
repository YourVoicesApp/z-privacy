// Rule 60 — the review page is deleted, and the text it showed is read in the
// preview side of the work surface.
//
// **The rule rests on a premise about the screen, and this file is that
// premise.** «What will leave is seen in the preview side itself» is true of
// the work surface as it is drawn — «Safe — AI will receive», the payload word
// for word — and it stops being true the moment a door opens the three exits
// over a *closed* side. `safeColumnOpen` is a remembered setting: a person who
// pressed the rail once meets a closed side for ever after. So the deletion is
// safe only while every door that opens the sheet opens that side first, and
// the one hand that does it is `theWayToTheDoors`.
//
// **Opening it is not the app folding things by itself** — 046/K, the owner's
// rule, is about a state moving with no press behind it: a panel opening, a
// window resizing, a document arriving, a scan ending. Those four are measured
// in `the_states_change_only_by_a_press_test.dart`, which also names this as
// its fifth case: a press on the AI door opens the side, because that door's
// own law is «what leaves is seen».
//
// **And one door is not here yet.** The chat has no preview side at all, so
// there is nothing for the hand to open for it; the owner is being asked
// whether that press splits in two. The last guard in this file is that
// question, parked, with his words as its reason.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

const _doc = 'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n'
    'Abteilung Vertragswesen, Projekt Wintermond.\n';

const _safePane = ValueKey<String>('workspace-safe-pane');
const _safeClose = ValueKey<String>('workspace-safe-close');
const _safeRail = ValueKey<String>('workspace-safe-rail');

/// The chat's own band — rule 60-أ. Keyed, because this file asks whether the
/// text is **in it** rather than anywhere on the page.
const _whatWouldLeave = ValueKey<String>('home-what-would-leave');

/// A press writes a setting through Rust and refreshes everything after it, so
/// a press needs real moments and not pumps — the number comes from
/// `the_states_change_only_by_a_press_test`, which measured five as too few.
Future<void> settle(WidgetTester tester, {int rounds = 14}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

Future<void> press(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await settle(tester);
}

/// A bench on its own data directory, with every suggestion answered — so the
/// sheet this file opens has a payload and no question standing in front of it.
Future<(Ground, Workbench)> _open(WidgetTester tester, String name) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-seen-$name-$pid');
    if (here.existsSync()) here.deleteSync(recursive: true);
    addTearDown(() {
      if (here.existsSync()) here.deleteSync(recursive: true);
    });
    await z.setDataDir(dir: here.path);
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    for (final f in bench.suggested) {
      await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
    }
    await bench.refresh();
  });
  addTearDown(bench.dispose);
  return (ground, bench);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('the AI door opens the preview side, and then the doors — 1280×720', (tester) async {
    // The size the human run failed at, and the size rule 60 has to hold at:
    // if the side and the sheet cannot both be on this window, the text is not
    // «seen» whatever the code says.
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, bench) = await _open(tester, 'ai-door');

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);
    expect(bench.payload, isNotNull, reason: 'nothing was built, so there is nothing to see');
    expect(bench.payload!.openSuggestions, 0, reason: 'a question is standing, and this is not that test');

    // **«Plain» first, while the side is still open and nothing stands over
    // it.** The sheet is a modal route: with it up, a press on the side's own
    // controls lands on the barrier and is swallowed, which is how this guard
    // first measured chips it had asked to be turned off. «Chips» draws each
    // token as a widget, and a widget is not a character.
    await tester.tap(find.text('Plain'));
    await settle(tester, rounds: 3);

    // The person's own press, once: the side is shut and stays shut.
    await press(tester, _safeClose);
    expect(ground.config!.safeColumnOpen, isFalse, reason: 'the press did not close the side');
    expect(find.byKey(_safePane), findsNothing, reason: 'the side is still drawn');
    expect(find.byKey(_safeRail), findsOneWidget, reason: 'the rail is not there to bring it back');
    // The premise of the whole file, measured rather than assumed: with the
    // side shut there is **no** copy of the outgoing text anywhere.
    expect(
      find.byType(SafeText),
      findsNothing,
      reason: 'the payload is drawn somewhere else as well, so this file measures nothing',
    );

    // The door a person reaches for when the side is shut.
    await tester.tap(find.byTooltip('Choose the AI and what travels to it'));
    await settle(tester);

    expect(find.text('Who answers'), findsOneWidget, reason: 'the AI door opened nothing');
    expect(
      ground.config!.safeColumnOpen,
      isTrue,
      reason: 'the door opened the three exits over a closed preview side — rule 60 broken on the glass',
    );
    final payload = find.descendant(of: find.byKey(_safePane), matching: find.byType(SafeText));
    expect(payload, findsOneWidget, reason: 'the side came back without the payload in it');

    // On the glass, not merely in the tree: the rect has to be inside the
    // window, which is the whole of what the 1280×720 run lost.
    final rect = tester.getRect(payload);
    final size = tester.binding.renderViews.first.size;
    expect(
      rect.top >= -1 && rect.left >= -1 && rect.height > 8 && rect.width > 8,
      isTrue,
      reason: 'the outgoing text sits outside $size — rect $rect',
    );
    // And the doors are standing, so the press reached its own destination too.
    for (final door in const ['Manual AI', 'Copy Protected', 'Direct API']) {
      expect(find.text(door), findsOneWidget, reason: '«$door» is not on the glass');
    }

    // And the text that is seen is the text that would leave.
    final shown = tester
        .widget<SelectableText>(
          find.descendant(of: find.byKey(_safePane), matching: find.byType(SelectableText)).first,
        )
        .textSpan!
        .toPlainText();
    expect(shown, bench.payload!.text, reason: 'what is seen is not what would leave');
  });

  testWidgets('the side’s own door needs no opening, and takes the same hand', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, bench) = await _open(tester, 'side-door');

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);

    // This door stands **inside** the side, so it cannot be pressed with the
    // side shut — which is why the hand is about the other door. What is
    // measured here is that going through the hand costs this door nothing: the
    // side it is standing in is not closed, re-opened or scrolled by the press.
    expect(ground.config!.safeColumnOpen, isTrue, reason: 'the side is shut on a fresh data directory');
    await tester.tap(find.text('Choose who answers'));
    await settle(tester, rounds: 6);
    expect(find.text('Who answers'), findsOneWidget, reason: 'the side’s door opened nothing');
    expect(ground.config!.safeColumnOpen, isTrue, reason: 'the hand closed the side it was asked to open');
  });

  // **Rule 60-أ — the owner's answer, 17 October.** The chat's press splits in
  // two: «Ask the AI» protects the text and draws it in a band above the
  // composer, and the band carries the door to the three exits. So the chat
  // gets the step rule 60 took out of it — «see what will leave» — and keeps
  // it in the one place a chat has room for it.
  //
  // This guard was parked with his question as its name. What it measures now
  // is every half of his ruling: no sheet before the band, the outgoing text
  // on the glass and read as characters, the door inside the band, «Cancel»
  // landing back on the band, and the band refusing to describe a text the
  // person has since changed.
  testWidgets('the chat door shows what will leave — rule 60-أ', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, chat) = await _open(tester, 'chat-door');

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        ground: ground,
        chat: chat,
        version: 'z_core 0.1.0',
        onImport: () {},
        onReadBack: () {},
        onType: (_) {},
        // The shell's own `onAsk` reads the line into a bench and scans it;
        // this bench is already that bench, scanned and answered, so the hand
        // the screen calls has nothing left to do. What is measured here is
        // what the **screen** does after the asking, which is the half of the
        // act rule 60-أ is about.
        onAsk: (_) async {},
        onVault: () {},
        onSettings: () {},
      ),
    ));
    await settle(tester, rounds: 3);
    expect(chat.payload, isNotNull, reason: 'nothing was built, so there is nothing to see');
    expect(chat.payload!.openSuggestions, 0, reason: 'a question is standing, and this is not that test');

    // Nothing is claimed before the press: a band that stood there on its own
    // would be describing a text nobody has asked about.
    expect(find.byType(SafeText), findsNothing, reason: 'the band is drawn before anything was asked');

    // The text the bench was scanned with, because the band's claim is about
    // the text in the box — a guard that typed something else would measure a
    // band telling a lie and call it a pass.
    await tester.enterText(find.byKey(HomeScreen.composer), _doc);
    await settle(tester, rounds: 2);
    await tester.tap(find.text('Ask the AI'));
    await settle(tester, rounds: 8);

    // **No sheet before the band** — the owner's own order.
    expect(
      find.byType(SendSheet),
      findsNothing,
      reason: 'the chat opened the three exits before the person saw what would leave',
    );

    // The outgoing text, on the glass, inside the band.
    final band = find.byKey(_whatWouldLeave);
    expect(band, findsOneWidget, reason: 'the chat drew no band for what would leave');
    final payload = find.descendant(of: band, matching: find.byType(SafeText));
    expect(payload, findsOneWidget, reason: 'the band carries no copy of the outgoing text');
    final rect = tester.getRect(payload);
    final size = tester.binding.renderViews.first.size;
    expect(
      rect.top >= -1 && rect.left >= -1 && rect.height > 8 && rect.width > 8,
      isTrue,
      reason: 'the outgoing text sits outside $size — rect $rect',
    );

    // **Characters, not chips.** The band has no «Chips / Plain» switch of its
    // own, so it draws the text the way the model reads it; a `WidgetSpan` per
    // token would put `U+FFFC` where a word should be.
    final shown = tester
        .widget<SelectableText>(
          find.descendant(of: band, matching: find.byType(SelectableText)).first,
        )
        .textSpan!
        .toPlainText();
    expect(shown, chat.payload!.text, reason: 'what is seen is not what would leave');

    // The door stands in the band, and it opens the exits.
    final door = find.descendant(of: band, matching: find.text('Choose who answers'));
    expect(door, findsOneWidget, reason: 'the door is not in the band that draws the text');
    await tester.tap(door);
    await settle(tester, rounds: 6);
    expect(find.text('Who answers'), findsOneWidget, reason: 'the band’s door opened nothing');

    // **«Cancel» comes back to the band, and nothing is lost.**
    await tester.tap(find.text('Cancel'));
    await settle(tester, rounds: 6);
    expect(find.byType(SendSheet), findsNothing, reason: 'Cancel left the sheet standing');
    expect(find.byKey(_whatWouldLeave), findsOneWidget, reason: 'Cancel took the band with it');
    expect(
      tester.widget<TextField>(find.byKey(HomeScreen.composer)).controller!.text,
      _doc,
      reason: 'Cancel emptied the question',
    );

    // **And the band does not describe a text that has changed.** One press
    // rebuilds it, and that press is named and standing — see the ruling in
    // `home.dart`'s own band.
    await tester.enterText(find.byKey(HomeScreen.composer), '$_doc Noch ein Satz.');
    await settle(tester, rounds: 3);
    expect(
      find.byKey(_whatWouldLeave),
      findsNothing,
      reason: 'the band kept claiming a text the person had already changed',
    );
    expect(find.byType(SafeText), findsNothing, reason: 'the outgoing text is still drawn somewhere');
  });
}

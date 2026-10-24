// 108 item 5 · The address to write to, in the settings — and no door at all.
//
// The owner, 24 October 2026: «نضع إيميل الفيدباك في التطبيق في الإعدادات…
// ونجعل zprivacy@mono-peak.com هو إيميل التواصل».
//
// **And then he narrowed it the same day, which is the product.** The first
// shape of this item was a press that handed `mailto:` to the operating system
// through the door the guide link uses. His narrowing: one copyable box with
// the address, one sentence beside it, **the app opens nothing and sends
// nothing** — and the site is not touched for this item.
//
// So what is measured here is a fact on the glass and the **absence** of a
// door, which is the harder half: a card that merely looks quiet is not a card
// that cannot start a process. The guard reads the whole settings panel for
// anything pressable carrying the address, and the one place in this
// application that can start another program is measured as having exactly
// one caller — `_GuideCard` — in `one_line_opens_the_guide_test` beside it.
//
// **Watched red before it was trusted**: with the card taken out of the room,
// guard 1 reads «the room does not carry the address at all»; with the box
// replaced by the `ZButton` of this item's first shape, guard 2 reads a
// pressable control at the address.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/the_address_to_write_to.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

Future<Ground> _inTheRoom(WidgetTester tester) async {
  final ground = Ground();
  await tester.runAsync(() => ground.refresh());
  await tester.pumpWidget(MaterialApp(
    home: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.language),
  ));
  await tester.pumpAndSettle();
  return ground;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('the room carries the address, in a box, with its one sentence', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _inTheRoom(tester);

    expect(find.text(sentences.writeToUs), findsOneWidget,
        reason: 'the room does not carry the address at all');
    // The address itself, and only once: two copies of one address are two
    // things to keep true.
    expect(find.text(theContactAddress), findsOneWidget,
        reason: 'the address is drawn ${find.text(theContactAddress).evaluate().length} time(s)');
    // **Copyable**, which is what the owner asked for in place of a press:
    // selectable text gives the person the characters with the platform's own
    // copy, and needs no controller a stateless card cannot dispose.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('settings-write-to-us')),
        matching: find.byType(SelectableText),
      ),
      findsOneWidget,
      reason: 'the address cannot be selected, so a person cannot copy it',
    );
    // The two sentences: what to do with it, and what not to put in a letter.
    expect(find.text(sentences.copyTheAddressAndWriteToUs), findsOneWidget,
        reason: 'nothing says what to do with the address');
    expect(find.text(sentences.describeTheProblemNotYourDocuments), findsOneWidget,
        reason: 'nothing says not to send the document itself');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **Nothing to press.** The owner's narrowing in the one form a guard can
  // read: no control in this panel carries the address, and the card holds no
  // button, link or gesture at all.
  testWidgets('the address is not a door — there is nothing to press', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _inTheRoom(tester);

    final card = find.byKey(const ValueKey<String>('settings-write-to-us'));
    expect(card, findsOneWidget);
    for (final kind in <String, Finder>{
      'a button': find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
      'an ink well': find.descendant(of: card, matching: find.byType(InkWell)),
      'a gesture': find.descendant(of: card, matching: find.byType(GestureDetector)),
    }.entries) {
      expect(kind.value, findsNothing, reason: 'the box is a door: it holds ${kind.key}');
    }
    // And nowhere in the room is the address the label of a control.
    expect(find.widgetWithText(ButtonStyleButton, theContactAddress), findsNothing,
        reason: 'a press carries the address — the mailto door is back');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The address is spelled once in this application.** One constant, in a
  // file whose whole subject it is, so «which address does the app show» has
  // one answer — and the site's own footer carries the same characters, which
  // `check_site.sh` is what holds equal.
  test('one address, one spelling', () {
    expect(theContactAddress, 'zprivacy@mono-peak.com');
  });
}

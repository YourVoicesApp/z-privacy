// **One line in Settings opens the guide, in the language the glass is in** —
// paper 100, rule 83, the owner's «نعم» of 22 October 2026.
//
// The law is «one text in one place»: the guide is a page on the site, and the
// application carries a single press that opens it. So what can go wrong here
// is not what the page says — `scripts/check_site_claims.py` holds the page's
// 34 named controls against the one list — but **which address the press
// carries, and whether the press is there at all**.
//
// ## What is measured, and what cannot be
//
// The press itself starts a browser, and a test may not open a window on the
// machine it runs on. So the file is split the way `core/the_system_browser.dart`
// is split: [theGuideAddress] and [theCommandToOpen] are values, measured here;
// `openInTheBrowser` is those two values handed to `Process.start`, and the
// one thing about it that a guard can hold is that the control exists, is
// live, and carries the address — which the widget guard below does without
// pressing it.
//
// Needs the native library for the panel, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/the_system_browser.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // **The address, in each language the site serves it in** — and English for
  // everything else, which is the same fallback the sentences themselves take.
  test('the guide’s address is the page for the language the glass is in', () {
    expect(theGuideAddress('en'), 'https://z-privacy.com/en/guide/');
    expect(theGuideAddress('de'), 'https://z-privacy.com/de/guide/');
    expect(theGuideAddress('ar'), 'https://z-privacy.com/ar/guide/');

    // A language the site has no guide page for is the English page rather
    // than an address that answers 404 — a dead link is a dead control.
    expect(theGuideAddress('sv'), 'https://z-privacy.com/en/guide/',
        reason: 'Swedish has no guide page, so the press must land on the '
            'English one and not on nothing');
    expect(theGuideAddress('fr'), 'https://z-privacy.com/en/guide/');
    expect(theGuideAddress(''), 'https://z-privacy.com/en/guide/');

    // **The closing slash**, because that is what the page calls canonical:
    // without it the server answers a redirect, and one page would have two
    // spellings. `scripts/check_site_claims.py` holds this literal and the
    // site's own href equal; this says the same thing from the app's side.
    for (final code in theGuideSpeaks) {
      expect(theGuideAddress(code), endsWith('/guide/'));
      expect(theGuideAddress(code), startsWith('https://z-privacy.com/'));
    }
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **What would be run, without running it.** The address is the last
  // argument in every case and it is a separate argument, never a word in a
  // command line: `openInTheBrowser` passes these to `Process.start` with no
  // shell, so nothing in an address can become a second command.
  test('the opener is the platform’s own, and the address is its own argument', () {
    final command = theCommandToOpen('https://z-privacy.com/en/guide/');
    if (Platform.isLinux) {
      expect(command?.run, 'xdg-open');
      expect(command?.args, ['https://z-privacy.com/en/guide/']);
    } else if (Platform.isWindows) {
      expect(command?.run, 'rundll32');
      expect(command?.args,
          ['url.dll,FileProtocolHandler', 'https://z-privacy.com/en/guide/']);
    }
    expect(command, isNotNull,
        reason: 'this platform has no opener, so the press could only ever say '
            'that it could not open a browser');
    // The address is one argument whole — not split, not quoted, not joined
    // into a line somebody else would parse.
    expect(command!.args.last, 'https://z-privacy.com/en/guide/');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The press is on the glass, in the room the paper left to this seat, and
  // it carries the address.** Not pressed: a press would start a browser on
  // whatever machine this runs on. What is measured is everything up to the
  // press — the room, the control, that it is live, and that its label is the
  // address rather than a word, which is what a person reads before another
  // program opens.
  testWidgets('the Language room carries one live press at the guide’s address',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
          ground: ground, onClose: () {}, room: SettingsRoom.language),
    ));
    await tester.pumpAndSettle();

    expect(find.text(sentences.howToUseZPrivacy), findsOneWidget,
        reason: 'the room does not carry the guide at all');
    final press = find.byKey(const ValueKey<String>('settings-the-guide'));
    expect(press, findsOneWidget, reason: 'there is no press to open the guide');
    expect(tester.widget<ZButton>(press).onPressed, isNotNull,
        reason: 'the press is dead, and a dead control is a finding (rule 35)');
    // **Through `theMachinesOwnWord` since 116**, which is the law and not a
    // decoration: an address drawn in an Arabic panel without the isolate put
    // its closing slash at the front of the line. The label is compared with
    // the isolated form rather than with the bare one, so that the day the
    // isolate is dropped this line says so instead of the glass — and the
    // address **inside** it is still the address, letter for letter.
    expect(tester.widget<ZButton>(press).label, theMachinesOwnWord(theGuideAddress('en')),
        reason: 'the press does not say where it is going — and the address is '
            'also the one thing left to a person by hand if no browser opens');
    expect(tester.widget<ZButton>(press).label.contains(theGuideAddress('en')), isTrue,
        reason: 'the address itself is not in the label at all');

    // And the card says what the press does before it is pressed, which is the
    // half of rule 35 that is about the person rather than about the control.
    expect(find.text(sentences.theGuideOpensInYourBrowser), findsOneWidget,
        reason: 'nothing on the glass says that a browser will open');
    // The refusal is not drawn until a press fails: a sentence about a failure
    // standing before the failure would be a screen saying something untrue.
    expect(find.text(sentences.couldNotOpenYourBrowser), findsNothing,
        reason: 'the room says the browser could not be opened before anybody '
            'pressed anything');
  });
}

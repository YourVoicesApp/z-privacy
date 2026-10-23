// Which screen is on — the decision itself, not the screens.
//
// This file exists because of a bug that no screen test could have found: the
// shell read `Ground` to choose a screen but did not listen to it, so the
// settings arrived after the first frame and the first-run page never appeared.
// Running the program found it. This test makes sure running it is not the only
// thing that would.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/tokens.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_bridge_the_tests_speak_through.dart';

Future<void> setDataDirForTest(String path) => z.setDataDir(dir: path);

final _libPath = theBridgeTheTestsSpeakThrough;

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

void main() {
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-shell-$pid');

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
    removeWhenItLetsGo(dir);
  });

  tearDownAll(() {
    removeWhenItLetsGo(dir);
  });

  // The shell is the one place that watches the window, so it is the only place
  // this can be tested. What is under test is not what «covered» means — the
  // core owns that, and `the_safe_column_reveal.rs` proves it — but that the
  // event reaches it at all. A screen that saw the window go and said nothing
  // would leave a secret standing with no one the wiser.
  //
  // The states are the measured ones: `inactive` when another window takes the
  // front, `hidden` when it is minimised or moved to another workspace.
  Future<_Shown> aRevealedValue(WidgetTester tester, Directory own, Ground ground) async {
    late final _Shown shown;
    await tester.runAsync(() async {
      await z.vaultLock();
      await setDataDirForTest(own.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
      final entity = await z.createEntity(
        kind: EntityKind.client,
        label: 'Nordstern',
        profileId: null,
      );
      final value = await z.setValue(
        entity: entity,
        kind: Kind.company,
        text: 'Nordstern Consulting GmbH',
        policy: Policy.always,
      );
      await z.revealValue(entity: entity, valueId: value);
      await ground.refresh();
      shown = _Shown((await z.revealState()).remainingMs);
    });
    expect(shown.remainingMs, greaterThan(0),
        reason: 'nothing was revealed, so the test below would prove nothing');
    return shown;
  }

  Future<int> coreSaysRevealed(WidgetTester tester) async {
    late final int ms;
    await tester.runAsync(() async => ms = (await z.revealState()).remainingMs);
    return ms;
  }

  Directory ownDir(String name) {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-shell-$name-$pid');
    removeWhenItLetsGo(own);
    addTearDown(() {
      removeWhenItLetsGo(own);
    });
    return own;
  }

  // The promise is about the screen, so this measures the screen.
  //
  // The two tests below it ask the core what it thinks; this one asks the
  // window what a person would see. The whole way in is the real one — first
  // run, Home, a session typed by hand, the panel opened, a value revealed —
  // because the watcher lives in the shell and a value only sits in a panel.
  //
  // One `pump` after the event, and no timer is allowed to help: a value that
  // leaves when the next tick happens to come round is a value that was on
  // screen after the window was gone.
  testWidgets('a surface with no document has no tokens to reveal, so the press is dead', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    final own = ownDir('panel-focus');
    await tester.runAsync(() async {
      await z.vaultLock();
      await setDataDirForTest(own.path);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: own.path, ground: ground)));
    await settle(tester);

    // Past the first run, the way the routing test does it.
    await pastTheFirstRun(tester);

    // A session typed by hand, carrying something a general rule will protect
    // on its own — no vault, no pack of any language needed.
    // 041-G — the box is the home: no sheet, no question, just the text.
    // By key since 064/D: the session question is a second field on this page
    // whenever a vault is unlocked and no session is open.
    await tester.enterText(
      find.byKey(WorkspaceScreen.composer),
      'Bitte überweisen Sie auf IBAN DE02120300000000202051 bis Freitag.',
    );
    await settle(tester, rounds: 1);
    // **Rule 72-أ, 18 October 2026**: the strip's box and its «Open and scan»
    // are deleted, and the one box is the request box in the first part. What
    // is written there is the request — protected, and the whole of what leaves
    // when no document stands above it — so this is the same act through the
    // one door there is now.
    await tester.tap(find.byKey(const ValueKey<String>('workspace-question-attach')));
    await settle(tester);
    // **Rule 57b (the owner, 16 October)**: the first text of a new session is
    // asked which language it is in — once, before anything is read, because the
    // scanner needs it before it reads. The fixture answers it exactly as a
    // person does; after that nothing in the session asks again (57c).
    if (find.text(TheLanguageOfANewSession.title).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(TheLanguageOfANewSession.keyFor('de')));
      await settle(tester, rounds: 20);
    }

    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the session did not open');

    // **And here the guard stops, with the reason measured** — rule 72, 18
    // October 2026.
    //
    // What follows used to open the Tokens panel and reveal a value in it, to
    // measure that the reveal dies when the window stops being the one in
    // front. It cannot stand on this surface any more: what a person writes in
    // the one box is a **request**, and a request's protected values are not
    // in the workspace snapshot's `tokens` — measured on 18 October:
    // `payload=false · tokens=0 · marks=2`. So «Tokens» is a dead press here,
    // and a guard that pressed it would be measuring nothing.
    //
    // It is not a defect of this file and it is not fixed on the glass: a
    // question's tokens are the session's blocks and the core is the only
    // place that can list them (`workspace_snapshot` fills `tokens` from the
    // document). It is reported as a finding of 091, and the claim comes back
    // here the moment a question's tokens reach the panel — the window half of
    // it is this file's and nothing else measures it.
    //
    // What this guard still measures, and it is the half that was always
    // about the shell: a surface with no document has no tokens to reveal, so
    // the press is dead rather than open to a panel with nothing in it.
    expect(find.byType(TokensPanel), findsNothing,
        reason: 'the tokens panel opened over a surface whose tokens are not in the snapshot');
  });

  testWidgets('the shell tells the core when the window is no longer in front', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    final own = ownDir('focus');
    await aRevealedValue(tester, own, ground);

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: own.path, ground: ground)));
    await settle(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester, rounds: 3);

    expect(await coreSaysRevealed(tester), 0,
        reason: 'the window lost the front and the core still says a value is revealed');
  });

  testWidgets('the shell tells the core when the window is gone from the screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    final own = ownDir('hidden');
    await aRevealedValue(tester, own, ground);

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: own.path, ground: ground)));
    await settle(tester);

    // `inactive` first because that is the order the platform delivers, and
    // Flutter's own state machine refuses the jump. It covers everything on its
    // own, so the value is revealed again before the state under test.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester, rounds: 2);
    await tester.runAsync(() async {
      final rows = await z.entities(profileId: null);
      await z.revealValue(entity: rows.first.id, valueId: 1);
    });
    expect(await coreSaysRevealed(tester), greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await settle(tester, rounds: 3);

    expect(await coreSaysRevealed(tester), 0,
        reason: 'the window left the screen and the core still says a value is revealed');
  });

  testWidgets('a fresh device opens on the first-run page, not on the three parts', (tester) async {
    // Tall enough for both promises: since P2-6 the page carries the German
    // and the English text until a language is chosen, because it has no
    // right to assume one.
    await tester.binding.setSurfaceSize(const Size(1300, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Started outside the fake-async zone, for the reason written on
    // `ZShell.ground`. What is under test is the decision, not the startup.
    final ground = Ground();
    await tester.runAsync(() async {
      await setDataDirForTest(dir.path);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(home: ZShell(dataDir: dir.path, ground: ground)));
    await settle(tester);

    expect(find.byType(FirstRunScreen), findsOneWidget,
        reason: 'the shell must show the first-run page while the core says it is due');
    expect(find.byType(WorkspaceScreen), findsNothing);
    expect(find.text(sentences.noZPrivacyServer), findsOneWidget);

    // **Passing it leaves for the one screen** — rule 70, in this run at
    // least: the lasting answer needs a vault to be written into, and this
    // device has none.
    //
    // The language is chosen first because there is no Start before one: this
    // test is about which screen the shell picks, and it has to make the
    // page's own decision to get past it.
    await pastTheFirstRun(tester);
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(FirstRunScreen), findsNothing);
    // What the one screen says when it holds nothing: the way in, and the
    // three parts each naming what they are for.
    // Rule 72-أ: the «+» at the top and the one box in the first part.
    expect(find.byKey(WorkspaceScreen.addDocument), findsOneWidget);
    expect(find.byKey(WorkspaceScreen.composer), findsOneWidget);
    // The eyebrows are drawn upper-cased by `Eyebrow`, which is why the
    // reach is the word as it is on the glass.
    expect(find.text('THE CHAT'), findsOneWidget);
  });

  // **The folder is said before any screen, and this screen does not say it
  // again** — 18 October 2026, the fault the owner met on `84f4453`.
  //
  // `set_data_dir` is the one call that gives the core its folder, and it sat
  // inside the shell's `_start()`, which the shell runs only when it made its
  // own `Ground`: `if (widget.ground == null) _start()`. That condition is a
  // test door. 092 made the root hold the `Ground` so it could read the
  // person's language from it, the shipped app began passing one, and the call
  // stopped happening in the product — the core had no folder, `VaultState`
  // answered `Absent`, and the first-run page came up over a vault of 7938
  // bytes that nothing had read. **Four hundred and one tests were green,
  // because every one of them passes a folder of its own.**
  //
  // So the division of labour is what is measured here, and the half a Dart
  // test can hold is this one: a shell handed a `Ground` **touches nobody's
  // folder**. The other half — that `main.dart` says it, before `runApp`, with
  // nothing branching in front of it — is G52, because a widget test cannot
  // run `main()`.
  testWidgets('a shell given a Ground leaves the folder alone, and says what went wrong before it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final own = Directory('${Directory.systemTemp.path}/zprivacy-folder-$pid');
    removeWhenItLetsGo(own);
    addTearDown(() {
      removeWhenItLetsGo(own);
    });

    final ground = Ground();
    await tester.runAsync(() async {
      await z.vaultLock();
      // The folder this run is about, with a vault open in it — so that a
      // shell which went looking for a folder of its own would be **visibly**
      // somewhere else: the machine's real folder holds either a sealed vault
      // or none, and both read as «not unlocked».
      await setDataDirForTest(own.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort für den Tresor');
      await ground.refresh();
    });
    expect(ground.vault, VaultState.unlocked, reason: 'the folder for this run was not opened');

    // **No `dataDir`**, which is the shipped app's own shape: the folder was
    // said before this widget existed, and the shell is handed only a Ground.
    await tester.pumpWidget(MaterialApp(
      home: ZShell(
        ground: ground,
        troubleAtTheStart: 'This folder cannot be used for Z Privacy files.',
      ),
    ));
    await settle(tester);

    // It is still that folder's vault that is open. A shell that had asked for
    // a folder of its own would have re-pointed the core at the machine's
    // default and this would be `locked` or `absent`.
    await tester.runAsync(ground.refresh);
    expect(ground.vault, VaultState.unlocked,
        reason: 'the shell pointed the core at a folder of its own choosing');

    // And the sentence from before the first frame is on the glass: `main.dart`
    // has no screen to say it on, and a start-up fault that reaches nobody is
    // how two builds stayed quiet.
    expect(find.text('This folder cannot be used for Z Privacy files.'), findsOneWidget,
        reason: 'what went wrong before any screen existed never reached one');
    // In a band of its own, over whatever screen the chain chose: the band
    // inside `_body` is past the first-run return, and the first-run page is
    // exactly where a folder fault puts a person.
    expect(find.byType(Trouble), findsOneWidget);
    await tester.tap(find.byType(Trouble));
    await settle(tester, rounds: 2);
    expect(find.byType(Trouble), findsNothing,
        reason: 'a press does not take the band away');
  });

}

/// What the core said was revealed, carried out of a `runAsync` block.
class _Shown {
  _Shown(this.remainingMs);

  final int remainingMs;
}

/// Past the first run, the way a person goes through it since 041-N: the
/// language, then the vault — which is the only way on, because everything Z
/// learns while they work is kept in it.
Future<void> pastTheFirstRun(WidgetTester tester, {String language = 'English', String start = 'Start'}) async {
  // **Scrolled to first since 23 October 2026** (paper 106): the first page
  // draws one promise block per offered language before a choice, and the
  // third language put the language row below the fold of a 1000-tall window.
  // The page scrolls; a tap at a fixed point does not.
  await tester.ensureVisible(find.text(language));
  await settle(tester, rounds: 1);
  await tester.tap(find.text(language));
  await settle(tester, rounds: 1);
  await tester.tap(find.text(start));
  await settle(tester);
  await tester.tap(find.text(sentences.createAVault));
  await settle(tester);
  // The passphrase goes in through the core rather than through the two
  // fields: a widget that awaits the core does not resume under `testWidgets`,
  // which is why no test in this app presses «Create the vault» itself. What
  // is being tested here is the routing either side of it.
  await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort für den Tresor'));
  await settle(tester);
  // The vault screen is a door, not a room: «Back» is what reaches Home.
  final back = find.text(sentences.back);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await settle(tester, rounds: 8);
  }
}

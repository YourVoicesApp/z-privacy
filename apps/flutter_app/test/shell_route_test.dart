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
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/shell.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/tokens.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

Future<void> setDataDirForTest(String path) => z.setDataDir(dir: path);

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory dir;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
    dir = Directory('${Directory.systemTemp.path}/zprivacy-shell-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
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
    if (own.existsSync()) own.deleteSync(recursive: true);
    addTearDown(() {
      if (own.existsSync()) own.deleteSync(recursive: true);
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
  testWidgets('a revealed value leaves the panel in the frame after the window does', (tester) async {
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
      find.byKey(HomeScreen.composer),
      'Bitte überweisen Sie auf IBAN DE02120300000000202051 bis Freitag.',
    );
    await settle(tester, rounds: 1);
    await tester.tap(find.text('Open and scan'));
    await settle(tester);

    expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the session did not open');

    await tester.tap(find.text('Tokens'));
    await settle(tester);
    expect(find.byType(TokensPanel), findsOneWidget, reason: 'the tokens panel did not open');

    await tester.tap(find.text('Reveal'));
    await settle(tester);

    Finder inPanel(Finder what) =>
        find.descendant(of: find.byType(TokensPanel), matching: what);
    expect(
      inPanel(find.textContaining('DE02120300000000202051')),
      findsOneWidget,
      reason: 'the reveal did not reach the panel, so nothing below is measured',
    );

    // The window stops being the one in front. Inside `runAsync` because the
    // report and the ask that follows it are real calls into Rust; in the
    // running program they finish in microseconds and the next frame is
    // already without the value.
    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();

    expect(
      inPanel(find.textContaining('DE02120300000000202051')),
      findsNothing,
      reason: 'the value was still drawn a frame after the window was no longer in front',
    );
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

  testWidgets('a fresh device opens on the first-run page, not on Home', (tester) async {
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
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('No Z Privacy server.'), findsOneWidget);

    // Passing it leaves for Home, in this run at least — the lasting answer
    // needs a vault to be written into, and this device has none.
    //
    // The language is chosen first because there is no Start before one: this
    // test is about which screen the shell picks, and it has to make the
    // page's own decision to get past it.
    await pastTheFirstRun(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.text('Open Z Vault'), findsOneWidget);
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
  await tester.tap(find.text(language));
  await settle(tester, rounds: 1);
  await tester.tap(find.text(start));
  await settle(tester);
  await tester.tap(find.text('Create a vault'));
  await settle(tester);
  // The passphrase goes in through the core rather than through the two
  // fields: a widget that awaits the core does not resume under `testWidgets`,
  // which is why no test in this app presses «Create the vault» itself. What
  // is being tested here is the routing either side of it.
  await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort für den Tresor'));
  await settle(tester);
  // The vault screen is a door, not a room: «Back» is what reaches Home.
  final back = find.text('Back');
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    await settle(tester, rounds: 8);
  }
}

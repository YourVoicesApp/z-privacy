// P1-4, the half that only a widget test can prove:
//
//     Expiry changes the content, and never the geometry.
//
// His hardest case, and the one that caught me twice in the human run: rest
// the pointer on «Edit», let the reveal run out **without moving**, then
// press. It must reach Edit — not empty space, and not another button.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/entity_detail.dart';

const _pass = 'ein gutes Passwort für die Zeile';

/// Two clocks have to move together here, and that is the whole difficulty.
///
///   * The widget's `Timer.periodic` lives in the test's **fake** clock, and
///     only `pump(duration)` advances it.
///   * The `revealState()` call inside that timer is a real future into Rust,
///     which never completes inside the fake-async zone — only `runAsync`
///     lets it finish.
///
/// So each round does both: advance the fake clock enough to fire the ticker,
/// then allow real time for the answer to come back.
Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
  }
}

void main() {
  setUpAll(() async => RustLib.init());

  testWidgets('a reveal running out moves nothing under the pointer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final EntityCard card;
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('zprivacy-reveal-row-');
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      // Two seconds: long enough to see, short enough to wait out.
      final now = await z.settings();
      await z.saveSettings(
        settings: Settings(
          scanOnImport: now.scanOnImport,
          revealSeconds: 2,
          autoLockMinutes: now.autoLockMinutes,
          packId: now.packId,
          language: now.language,
          firstRunDone: now.firstRunDone,
          sessionOnly: now.sessionOnly,
        ),
      );
      final entity = await z.createEntity(
        kind: EntityKind.client,
        label: 'Nordstern',
        profileId: null,
      );
      await z.setValue(
        entity: entity,
        kind: Kind.company,
        text: 'Nordstern Consulting GmbH',
        policy: Policy.always,
      );
      card = await z.entity(entityId: entity);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EntityDetail(
          card: card,
          ground: ground,
          onChanged: () async {},
          onGone: () {},
        ),
      ),
    ));
    await tester.pump();

    // ------------------------------------------------- hidden to begin with
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.text('Reveal'), findsOneWidget);
    // Edit and Delete exist **while hidden** — they used to appear only after
    // a reveal, which is what made the row change shape.
    expect(find.text('Edit'), findsOneWidget);
    // Two «Delete»s on this screen: the identity's and the value's. What
    // matters is that the value's exists while hidden.
    expect(find.text('Delete'), findsNWidgets(2));
    final editWhenHidden = tester.getRect(find.text('Edit'));

    // ------------------------------------------------- revealed
    // Pressed inside `runAsync` on purpose: `_reveal` starts the ticker, and
    // a `Timer.periodic` created in the fake zone can never resolve the FFI
    // future inside its own callback. Started here it is a real timer, so the
    // path under test is the real one.
    await tester.runAsync(() async {
      await tester.tap(find.text('Reveal'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.text('Nordstern Consulting GmbH'), findsOneWidget);
    expect(find.textContaining('Revealed · '), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(
      tester.getRect(find.text('Edit')),
      editWhenHidden,
      reason: 'revealing moved Edit',
    );

    // ------------------------------------------------- the pointer stays put
    // Rest on Edit and do not move it again for the rest of the test.
    final onEdit = tester.getCenter(find.text('Edit'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: onEdit);
    addTearDown(mouse.removePointer);
    await tester.pump();

    // Let the core's window run out while nothing moves. Real time, because
    // the ticker is a real timer and the core reads a real clock.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      if (find.text('Hidden').evaluate().isNotEmpty) break;
    }

    expect(find.text('Nordstern Consulting GmbH'), findsNothing,
        reason: 'the value outlived the core window');
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.text('Reveal'), findsOneWidget, reason: 'the control did not turn back');
    expect(
      tester.getRect(find.text('Edit')),
      editWhenHidden,
      reason: 'the expiry moved Edit out from under the pointer',
    );

    // And a press where the pointer already is reaches Edit.
    await tester.tapAt(onEdit);
    await settle(tester, rounds: 4);
    // The Edit dialog is a value form; its title proves the press landed.
    expect(find.text('Edit this value'), findsOneWidget,
        reason: 'the press did not reach Edit');
  });

  // The other half of «a reveal does not outlive its vault»: the core ends the
  // reveal when the vault closes, and this is the screen keeping its side of
  // that. The window here is 300 seconds — the longest a person can set — so
  // nothing below can pass because a window quietly ran out, and auto-lock is
  // off so the only thing acting is the lock itself.
  testWidgets('locking the vault takes the reveal with it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final EntityCard card;
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('zprivacy-reveal-lock-');
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      final now = await z.settings();
      await z.saveSettings(
        settings: Settings(
          scanOnImport: now.scanOnImport,
          revealSeconds: 300,
          autoLockMinutes: 0,
          packId: now.packId,
          language: now.language,
          firstRunDone: now.firstRunDone,
          sessionOnly: now.sessionOnly,
        ),
      );
      final entity = await z.createEntity(
        kind: EntityKind.client,
        label: 'Nordstern',
        profileId: null,
      );
      await z.setValue(
        entity: entity,
        kind: Kind.company,
        text: 'Nordstern Consulting GmbH',
        policy: Policy.always,
      );
      card = await z.entity(entityId: entity);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EntityDetail(
          card: card,
          ground: ground,
          onChanged: () async {},
          onGone: () {},
        ),
      ),
    ));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Reveal'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.text('Nordstern Consulting GmbH'), findsOneWidget,
        reason: 'the reveal did not start');

    // The vault locks. Not this screen, and not this widget: nothing here is
    // told to hide, and the row has to find out by asking the core.
    await tester.runAsync(() => z.vaultLock());
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      if (find.text('Hidden').evaluate().isNotEmpty) break;
    }

    expect(find.text('Nordstern Consulting GmbH'), findsNothing,
        reason: 'the value stayed on screen after the vault was locked');
    expect(find.text('Hidden'), findsOneWidget);
  });
}

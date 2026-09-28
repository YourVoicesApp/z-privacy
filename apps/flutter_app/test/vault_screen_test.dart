// M7.8 — the Z Vault room, against a real vault on disk.
//
// A separate file from `shell_test.dart` on purpose: the vault is one per
// process, and a test that creates one must not run beside tests that assume
// there is none.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/vault.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/entity_detail.dart';
import 'package:zprivacy/widgets/vault_forms.dart';
import 'package:zprivacy/widgets/why_sheet.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für den Test';

/// Real futures do not complete inside `testWidgets`' fake-async zone, and a
/// spinner waiting on one never stops. See the head of `shell_test.dart`.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
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
    dir = Directory('${Directory.systemTemp.path}/zprivacy-vault-screen-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('the vault room: locked, made, filled, searched, and pruned', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    await tester.runAsync(ground.refresh);

    await tester.pumpWidget(MaterialApp(home: VaultScreen(ground: ground, onClose: () {})));
    await settle(tester);

    // ---------------------------------------------------------- absent
    // It does not pretend to be an empty list. It says what is missing.
    expect(ground.vault, VaultState.absent);
    expect(find.text('There is no vault yet'), findsOneWidget);
    expect(find.textContaining('the only file this app writes'), findsOneWidget);
    expect(find.text('Create the vault'), findsOneWidget);

    // ---------------------------------------------------------- made
    late final int entityId;
    late final int valueId;
    await tester.runAsync(() async {
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      entityId = await z.createEntity(
        kind: EntityKind.client,
        label: 'Nordstern',
        profileId: null,
      );
      valueId = await z.setValue(
        entity: entityId,
        kind: Kind.company,
        text: 'Nordstern Consulting GmbH',
        policy: Policy.always,
      );
      await z.addValueAlias(entity: entityId, valueId: valueId, alias: 'Nordstern Consulting');
      await z.createEntity(kind: EntityKind.person, label: 'Müller', profileId: null);
      await ground.refresh();
      await ground.readVault();
    });
    await settle(tester);

    expect(ground.vault, VaultState.unlocked);
    expect(find.text('Nordstern'), findsOneWidget);
    expect(find.text('Müller'), findsOneWidget);
    // The bar counts what the core reported, and counts it in English: «1
    // value», not «1 values». The first version of this screen got that wrong
    // and this line is why it did not stay wrong.
    expect(find.text('2 identities · 1 value'), findsOneWidget);

    // ---------------------------------------------------------- searched
    // The search runs inside Rust, over real values, and finds one by a value
    // that no label mentions.
    await tester.runAsync(() => ground.searchVaultFor('Consulting'));
    await settle(tester, rounds: 1);
    expect(ground.vaultRows, hasLength(1));
    expect(find.text('Müller'), findsNothing);
    await tester.runAsync(() => ground.searchVaultFor(''));
    await settle(tester, rounds: 1);
    expect(ground.vaultRows, hasLength(2));

    // ---------------------------------------------------------- opened
    await tester.tap(find.text('Nordstern'));
    await settle(tester);
    expect(find.byType(EntityDetail), findsOneWidget);
    expect(find.text('Client · Nordstern'), findsOneWidget);

    // A value is hidden until it is asked for — here as everywhere else.
    expect(find.textContaining('Nordstern Consulting GmbH'), findsNothing);
    expect(find.text('Show'), findsOneWidget);
    // And the kind's name came from the core's list, not a switch in Dart.
    expect(kindRows, isNotEmpty);
    expect(find.text(kindName(Kind.company)), findsOneWidget);

    await tester.tap(find.text('Show'));
    await settle(tester);
    expect(find.text('Nordstern Consulting GmbH'), findsOneWidget);
    // Its spellings come with it: they are the same secret.
    expect(find.text('Nordstern Consulting'), findsOneWidget);

    // ---------------------------------------------------------- pruned
    // Forgetting one spelling leaves the value, and the screen is re-read from
    // the core rather than patched here.
    await tester.runAsync(() async {
      await ground.vaultEdit(() => z.removeValueAlias(
            entity: entityId,
            valueId: valueId,
            alias: 'Nordstern Consulting',
          ));
    });
    await settle(tester);
    await tester.runAsync(() async {
      final shown = await z.revealValue(entity: entityId, valueId: valueId);
      expect(shown.aliases, isEmpty);
      expect(shown.value, 'Nordstern Consulting GmbH');
    });

    // ---------------------------------------------------------- locked
    await tester.runAsync(() async {
      await z.vaultLock();
      await ground.refresh();
      await ground.readVault();
    });
    await settle(tester);
    expect(ground.vault, VaultState.locked);
    expect(ground.vaultRows, isEmpty, reason: 'a locked vault lists nothing');
    expect(find.text('The vault is locked'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    final unlockTrouble = vaultKeyTroubleFor(const ApiError.vaultAuthenticationFailed());
    expect(unlockTrouble, contains('Could not unlock the vault'));
    expect(unlockTrouble, contains('may be incorrect, or the vault may be corrupted or modified'));
    expect(unlockTrouble, isNot(contains('That is not the passphrase')));
  });

  testWidgets('settings are the core\'s, and say where they live', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    // The vault made by the test above is locked by now, so open it again:
    // settings kept in a locked vault are not readable, and that is the point.
    await tester.runAsync(() async {
      await z.vaultUnlockWithPassphrase(passphrase: _pass);
      await ground.refresh();
    });

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.privacy),
    ));
    await settle(tester);

    expect(ground.config, isNotNull);
    expect(ground.config!.sessionOnly, isFalse, reason: 'an open vault keeps them');
    expect(find.text('Scan a document the moment it arrives'), findsOneWidget);

    // «Answer every suggestion before sending» is not a switch, and the room
    // says why. There is no «send anyway» to find anywhere in Settings.
    expect(find.text('Answer every suggestion before sending'), findsOneWidget);
    expect(find.textContaining('there is no «send anyway»'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget, reason: 'exactly one thing here is a switch');

    // A number that the core bounds, not the screen: ask for far too much and
    // the core hands back its own limit.
    final before = ground.config!;
    await tester.runAsync(() => ground.saveConfig(Settings(
          scanOnImport: before.scanOnImport,
          revealSeconds: 99999,
          autoLockMinutes: before.autoLockMinutes,
          packId: before.packId,
          language: before.language,
          firstRunDone: before.firstRunDone,
          sessionOnly: before.sessionOnly,
        )));
    await settle(tester, rounds: 1);
    expect(ground.config!.revealSeconds, 300, reason: 'the core clamped it, and the screen shows that');
  });

  testWidgets('the first run says four things, in the language it is offering', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    await tester.runAsync(ground.refresh);
    String? chosen;

    await tester.pumpWidget(MaterialApp(
      home: FirstRunScreen(ground: ground, onStart: (l) => chosen = l),
    ));
    await settle(tester, rounds: 1);

    for (final line in ['No account.', 'No ads.', 'No analytics.', 'No Z Privacy server.']) {
      expect(find.text(line), findsOneWidget);
    }
    expect(find.textContaining('Your original data stays on this device'), findsOneWidget);
    expect(find.text('by YourVoices'), findsOneWidget);
    // No e-mail, no sign-up, nothing to fill in.
    expect(find.byType(TextField), findsNothing);

    // Choosing Deutsch writes the page in German — a page that asked the
    // question only in English would be asking it in the answer.
    await tester.tap(find.text('Deutsch'));
    await settle(tester, rounds: 1);
    expect(find.text('Kein Konto.'), findsOneWidget);
    expect(find.text('Keine Werbung.'), findsOneWidget);
    expect(find.text('Starten'), findsOneWidget);
    // And it is honest about what the choice does today — the owner's own words.
    expect(find.text('German privacy rules enabled.'), findsOneWidget);
    expect(find.text('Interface translation is coming later.'), findsOneWidget);

    await tester.tap(find.text('Starten'));
    await settle(tester, rounds: 1);
    expect(chosen, 'de');
  });

  testWidgets('a protected word can say why, and forgetting shows its cost first',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Stands on its own: it makes whatever it needs rather than leaning on
    // what an earlier test in this file left behind. Test order is not a
    // fixture, and treating it as one has cost this project two red runs.
    const doc = 'Kunde: Nordstern Consulting GmbH bittet um Auskunft.';
    final ground = Ground();
    late final Workbench bench;
    late final Explanation why;
    await tester.runAsync(() async {
      final here = Directory('${Directory.systemTemp.path}/zprivacy-why-$pid');
      if (here.existsSync()) here.deleteSync(recursive: true);
      addTearDown(() {
        if (here.existsSync()) here.deleteSync(recursive: true);
      });
      await z.setDataDir(dir: here.path);
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      final e = await z.createEntity(
        kind: EntityKind.client,
        label: 'Nordstern',
        profileId: null,
      );
      final v = await z.setValue(
        entity: e,
        kind: Kind.company,
        text: 'Nordstern Consulting GmbH',
        policy: Policy.always,
      );
      await z.addValueAlias(entity: e, valueId: v, alias: 'Nordstern Consulting');
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      final at = doc.indexOf('Nordstern Consulting GmbH');
      why = (await bench.why(Span(
        start: at,
        end: at + 'Nordstern Consulting GmbH'.length,
      )))!;
    });

    // «Source: Vault» is what this replaces.
    expect(why.headline, 'You taught Z Privacy this value');
    expect(why.entity, isNotNull);
    expect(why.learnedAt > BigInt.zero, isTrue, reason: 'it knows when it was taught');

    await tester.pumpWidget(MaterialApp(
      home: WhySheet(
        why: why,
        word: 'Nordstern Consulting GmbH',
        span: const Span(start: 7, end: 32),
        onChanged: () async {},
        onUnprotect: (_) async {},
      ),
    ));
    await settle(tester, rounds: 1);

    expect(find.text('Why is this protected?'), findsOneWidget);
    expect(find.text('You taught Z Privacy this value'), findsOneWidget);
    expect(find.text('Forget everywhere'), findsWidgets);

    // The two acts are offered under their own names, and the sheet says which
    // is which — «forget» must never be a gentle word for «unprotect».
    expect(find.text('Remove protection'), findsOneWidget);
    expect(
      find.textContaining('leaves this document exactly as it is'),
      findsOneWidget,
    );

    // Other spellings are the same secret, so they wait to be asked for.
    expect(find.text('Nordstern Consulting'), findsNothing);

    // Forgetting shows what it costs **before** it happens, with numbers.
    await tester.tap(find.text('Forget everywhere').first);
    await settle(tester, rounds: 2);
    expect(find.textContaining('Forget «Nordstern Consulting GmbH»?'), findsOneWidget);
    expect(find.text('THIS WILL REMOVE'), findsOneWidget);
    expect(find.text('IT WILL NOT CHANGE'), findsOneWidget);
    expect(find.textContaining('already protected'), findsWidgets);
    // His own sentence, in the sheet.
    expect(
      find.textContaining('does not remove protection already applied in this document'),
      findsOneWidget,
    );
    // And what an empty `still_known_by` means, said strictly: a statement
    // about tomorrow, not about this minute.
    expect(
      find.textContaining('nothing kept on this device will recognise the value again'),
      findsOneWidget,
    );

    // And Cancel means nothing happened.
    await tester.tap(find.text('Cancel'));
    await settle(tester, rounds: 2);
    await tester.runAsync(() async {
      expect(
        (await z.searchVault(query: 'Nordstern Consulting GmbH')).length,
        1,
        reason: 'Cancel forgot something',
      );
    });

    bench.dispose();
  });
}

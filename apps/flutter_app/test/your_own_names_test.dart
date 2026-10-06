// 041-D · the names a person builds themselves, on the screen.
//
// The owner is preparing Swedish and German lists for a demonstration on
// Friday. What the panel owes him is small and must be exact: add a name in two
// presses, read a file of them in and be told what happened in numbers he can
// check, see his own library without going looking for it, and take one back
// with one press. All of it needs the vault, and says so where the press is.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/name_review.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Kunde: Nordstern Consulting GmbH\nAnsprechpartner: Herr Thomas Müller\n';

Future<Workbench> _bench(WidgetTester tester, Ground ground, {required bool vault}) async {
  late final Workbench bench;
  await tester.runAsync(() async {
    await z.vaultLock();
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-own-${vault ? "with" : "without"}-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
    if (vault) await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
    await ground.refresh();
    final session = await z.openSession(packId: 'de');
    await z.importText(session: session, text: _doc);
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await bench.rescan();
  });
  return bench;
}

Future<void> _openNames(WidgetTester tester, Workbench bench, Ground ground, {VoidCallback? onVault}) async {
  await tester.binding.setSurfaceSize(const Size(1500, 1000));
  await tester.pumpWidget(
    MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: onVault ?? () {}),
    ),
  );
  await settle(tester);
  bench.openNameReview();
  await settle(tester);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a name is two presses, and it joins a list a person can see', (tester) async {
    final ground = Ground();
    final bench = await _bench(tester, ground, vault: true);
    await _openNames(tester, bench, ground);

    expect(find.text('Your names'), findsOneWidget, reason: 'the panel does not show what you taught it');
    expect(find.text('Nothing yet.'), findsOneWidget);

    // One: open the form. Two: type and add.
    await tester.tap(find.text('Add a name'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Lindqvist');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(bench.userNames.map((r) => r.text), contains('Lindqvist'));
    expect(find.text('Lindqvist'), findsWidgets, reason: 'the name is not in the list on screen');
    expect(find.textContaining('family name'), findsWidgets, reason: 'the row does not say what it is');

    // And one press takes it back.
    await tester.tap(find.byTooltip('Forget «Lindqvist»'));
    // A press that calls into Rust needs the real clock more than once: the
    // call, the refreshed list, and the rescan that follows it are three
    // futures, and `settle` gives each round one real moment.
    await settle(tester, rounds: 10);
    expect(bench.userNames, isEmpty, reason: 'forgetting left the name behind');
    expect(find.text('Forgot «Lindqvist».'), findsOneWidget, reason: 'the panel says nothing about it');

    bench.dispose();
  });

  testWidgets('a list is read and counted, and a file without a type column is refused', (tester) async {
    final ground = Ground();
    final bench = await _bench(tester, ground, vault: true);
    await _openNames(tester, bench, ground);

    // The file goes through the core, which is what counts: the screen's job is
    // to show the three numbers, not to work them out.
    late final String? refused;
    await tester.runAsync(() async {
      await bench.addUserName('Lindqvist', kind: UserNameKind.family, always: false);
      refused = await bench.importUserNames(
        'name,type,source,licence\n'
        'Anneli,given,SCB 2024,CC0\n'
        'Lindqvist,family,SCB 2024,CC0\n'
        'Olle Berg,given,,\n',
      );
    });
    expect(refused, isNull);
    expect(bench.lastImport!.added, 1);
    expect(bench.lastImport!.alreadyKnown, 1);
    expect(bench.lastImport!.refused, 1);

    await settle(tester);
    expect(bench.userNames.map((r) => r.text), containsAll(<String>['Anneli', 'Lindqvist']));

    // A file with no «type» column is refused in a sentence that names it.
    late final String? bad;
    await tester.runAsync(() async => bad = await bench.importUserNames('name\nAnneli\n'));
    expect(bad, isNotNull);
    expect(bad, contains('type'), reason: 'the refusal does not say what is missing: $bad');

    bench.dispose();
  });

  testWidgets('without a vault both acts say what they need and open it', (tester) async {
    final ground = Ground();
    final bench = await _bench(tester, ground, vault: false);
    var toTheVault = 0;
    await _openNames(tester, bench, ground, onVault: () => toTheVault++);

    expect(ground.vault, VaultState.absent, reason: 'this case is the one without a vault');
    expect(find.text('Add a name'), findsNothing, reason: 'the button promises what it cannot do');
    final add = find.text('Add a name · Needs a vault');
    expect(add, findsOneWidget);
    expect(find.text('Import a list · Needs a vault'), findsOneWidget);
    expect(
      find.textContaining('Your names live in the vault'),
      findsOneWidget,
      reason: 'nothing says why it is shut',
    );

    await tester.tap(add);
    await settle(tester);
    expect(toTheVault, 1, reason: 'the button did not open the way to a vault');

    bench.dispose();
  });

  testWidgets('the rule set in the top bar is a choice, and the list is the core\'s', (tester) async {
    final ground = Ground();
    final bench = await _bench(tester, ground, vault: true);
    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {})),
    );
    await settle(tester);

    late final List<PackRow> packs;
    await tester.runAsync(() async => packs = await z.packs());
    expect(packs.length, greaterThan(1), reason: 'one pack is not a choice, so this proves nothing');

    await tester.tap(find.byTooltip('Read this document with another rule set'));
    await settle(tester);
    // Every pack this build carries, named by the core and not by Dart.
    for (final p in packs) {
      expect(find.text(p.label), findsWidgets, reason: '«${p.label}» is missing from the list');
    }

    final other = packs.firstWhere((p) => p.id != bench.packId);
    await tester.tap(find.text(other.label).last);
    await settle(tester, rounds: 8);
    expect(bench.packId, other.id, reason: 'choosing a rule set did not switch to it');

    bench.dispose();
  });


  testWidgets('a list has a name, a count and a switch, and off is not forgotten', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-lists-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      // Two lists, each with a name of its own.
      await z.addUserName(
        text: 'Okonkwo',
        kind: UserNameKind.family,
        always: false,
        list: 'ar',
      );
      await z.addUserName(
        text: 'Lindqvist',
        kind: UserNameKind.family,
        always: false,
        list: 'sv',
      );
      await bench.refreshUserNames();
    });

    await _openNames(tester, bench, ground);

    // «Your names» is at the foot of a panel that scrolls, and a list that
    // scrolls does not build what is below the window — so the test goes there
    // the way a person would.
    await tester.drag(find.byType(NameReviewPanel), const Offset(0, -500));
    await settle(tester, rounds: 2);
    // Each list says its language and how many names are in it — a list **is**
    // a language, and «العربية» has no pack in this build at all, which is the
    // point: a person builds that list by hand before the pack exists.
    // The heads are rich text — a name, a count and sometimes «off» in one
    // line — so the finder has to read inside the spans.
    expect(find.textContaining('العربية', findRichText: true), findsOneWidget);
    expect(find.textContaining('Svenska', findRichText: true), findsWidgets);
    expect(find.byType(Switch), findsNWidgets(bench.userLists.length));

    // Turning one off leaves its names on screen — faded, not gone.
    final head = find
        .ancestor(
          of: find.textContaining('العربية', findRichText: true),
          matching: find.byType(Row),
        )
        .first;
    await tester.tap(find.descendant(of: head, matching: find.byType(Switch)));
    await settle(tester, rounds: 8);

    expect(
      bench.userLists.firstWhere((l) => l.name == 'ar').enabled,
      isFalse,
      reason: 'the switch did not turn the list off',
    );
    expect(
      bench.userNames.where((r) => r.list == 'ar').length,
      1,
      reason: 'a switch forgot a name',
    );
    expect(
      find.textContaining('Okonkwo', findRichText: true),
      findsWidgets,
      reason: 'the names of an off list vanished',
    );
    expect(
      find.textContaining('off', findRichText: true),
      findsWidgets,
      reason: 'nothing says the list is off',
    );

    bench.dispose();
  });
}

/// Pumps with a real moment between them — and **no `pumpAndSettle`**.
///
/// Measured here: once «Your names» holds a list, the panel carries a `Switch`,
/// and `pumpAndSettle` on this screen never returns — it waits for a frame
/// where nothing is scheduled, and that frame does not come. Explicit pumps
/// settle everything this file asserts about, which is what the other screen
/// tests get from `pumpAndSettle` anyway.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

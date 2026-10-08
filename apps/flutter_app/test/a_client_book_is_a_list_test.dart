// 054 + 056 · a client book becomes a list, and the sentence says what it did
// not do.
//
// The two defects are one: **nothing is discarded quietly.** 054 — a row typed
// `person` or `company` had the list the person chose accepted and thrown
// away, so the only kind of list a client book ever makes never became one.
// 056 — the same for columns: `name` and `type` were read and every other
// column was dropped, while the report said `added: 2, refused: 0`.
//
// What is measured here is the half a person reads: the sentence after the
// import, and the list head with its count and its switch.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// A client table as a real one is shaped: one row per client, and the columns
/// that matter.
const _table = 'name,type,kundnummer,avtal\n'
    'Hedvig Palmgren,person,448217,AVT-2026-118\n'
    'Faruk AB,company,449073,AVT-2026-204\n';

/// Every file in this suite keeps its own: the panel waits on the core, and a
/// `pumpAndSettle` cannot see a native future at all.
Future<void> _settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

NameImport _report({
  int added = 2,
  int values = 0,
  List<String> columnsNotUsed = const [],
}) =>
    NameImport(
      added: added,
      alreadyKnown: 0,
      refused: 0,
      reasons: const [],
      values: values,
      columnsNotUsed: columnsNotUsed,
    );

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------ the sentence

  test('a plain list of names still says the three numbers it always said', () {
    expect(importSaid(_report()), '2 added · 0 already known · 0 refused');
  });

  test('a table says the values it taught as well as the names', () {
    expect(
      importSaid(_report(values: 4)),
      '2 added · 0 already known · 0 refused · 4 values',
    );
  });

  /// **The sentence 056 is about.** «2 added · 0 refused» for a table whose
  /// other columns were dropped read as success and was not.
  test('and it names the columns it could not place', () {
    final said = importSaid(_report(values: 2, columnsNotUsed: ['handläggare', 'rabattkod']));
    expect(said, contains('2 added'));
    expect(said, contains('2 columns were not used: handläggare, rabattkod'));
    expect(said, contains('name the kind for each'));
  });

  test('one column is one column, in its own words', () {
    expect(
      columnsNotUsedSaid(['rabattkod']),
      'One column was not used: rabattkod — name the kind for it, or it stays out.',
    );
  });

  // ----------------------------------------------------- the list on the screen

  /// **054's third consequence, on the screen it was invisible on.**
  ///
  /// `UserListRow.enabled` — «off means the scanner is not told about them» —
  /// could not be reached for the only list the owner has, because the list did
  /// not exist. The head carries its name, its two counts and its switch.
  testWidgets('a client book appears as a list, with its counts and its switch',
      (tester) async {
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-book-list-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord långt nog');
      await ground.refresh();
      final session = await z.openSession(packId: 'sv');
      bench = Workbench(session: session, profileId: null, packId: 'sv');
      await bench.importUserNames(_table, scope: Scope.always, into: 'sv');
    });

    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
      ),
    );
    await _settle(tester);
    bench.openNameReview();
    await _settle(tester);

    final lists = bench.userLists;
    expect(lists.length, 1, reason: 'the client book did not become a list: $lists');
    expect(lists.single.name, 'sv');
    expect(
      (lists.single.names, lists.single.values),
      (2, 4),
      reason: 'the list counts the names and the numbers apart: $lists',
    );

    // The switch is the point of a list, and it is on the screen for this one.
    expect(find.byType(Switch), findsWidgets);
    // And the panel does not call this «nothing yet» while it holds a book.
    expect(find.text('Nothing yet.'), findsNothing);
  });
}

// 071 — four booleans for one slot, measured before anything is redesigned.
//
// **The slot** is the column to the right of the document, and **four things
// claim it**: the names panel (`reviewingNames`), the review panel
// (`reviewOpen`), the tokens panel (`tokensOpen`) and the answer panel
// (`showing != null`). `workspace.dart` says in its own comment, where they are
// drawn, «one panel at a time, and the one asked for».
//
// It is not one at a time. The names and review panels exclude each other —
// 070 paid for that in a live bug — but tokens and the answer are **separate
// `if`s in the same list**, and none of the doors closes the others:
// `openReview` clears `reviewingNames` only, `openTokens` sets its own
// boolean, `show` sets its own. So two presses put two panels in one slot,
// sharing one width and one arrow.
//
// **This was a pin, and 071 flipped it.** Both halves are kept. What it
// recorded: Review then Tokens drew two panels in one slot, measured on the
// glass, because `openReview` cleared `reviewingNames` alone while tokens and
// the answer were separate `if`s that no door closed. What it asserts now: the
// slot holds one panel, and the second press **replaces** the first rather
// than joining it — not because the drawing was taught to behave, but because
// `OpenPanel` leaves nowhere to write «both».
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/review.dart';
import 'package:zprivacy/widgets/tokens.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Rechnung für Herrn Thomas Müller, IBAN DE89370400440532013000.';

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('one panel stands in the slot, and the second press takes it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-071-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });
    addTearDown(bench.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          bench: bench,
          ground: ground,
          onImport: () {}, onAsk: (_) {},
          onVault: () {},
        ),
      ),
    );
    await settle(tester);

    // The control first: with nothing asked for, the slot is empty. Without
    // this, «two panels» below could be two panels that are always there.
    expect(find.byType(ReviewPanel), findsNothing);
    expect(find.byType(TokensPanel), findsNothing);
    expect(
      bench.tokens,
      isNotEmpty,
      reason: 'the document produced no tokens, so the Tokens panel below has '
          'nothing to open for and this measures nothing',
    );

    // Two presses, as a person makes them: the two doors are independent and
    // neither closes the other.
    bench.openReview();
    bench.openTokens(true);
    await settle(tester);

    expect(
      find.byType(TokensPanel),
      findsOneWidget,
      reason: 'the tokens panel did not open, so the claim below is about an '
          'empty slot rather than about one panel replacing another',
    );
    expect(
      find.byType(ReviewPanel),
      findsNothing,
      reason: 'the review panel is still standing beside the tokens panel — '
          'two panels in a slot that holds one, which is what this file was '
          'written to record and 071 to make unwritable',
    );
    expect(
      bench.panel,
      OpenPanel.tokens,
      reason: 'the value says ${bench.panel} while the screen shows tokens, so '
          'the drawing and the state have parted company',
    );

    // And back the other way: the first door still takes the slot from the
    // second, or «replaces» would only be true in one direction.
    bench.openReview();
    await settle(tester);
    expect(find.byType(ReviewPanel), findsOneWidget);
    expect(find.byType(TokensPanel), findsNothing);
  });
}

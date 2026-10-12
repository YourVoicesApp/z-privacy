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
// **This file is a pin: it asserts what is true today, not what should be.**
// 070's own note names the repair — «one value that names which panel is open
// — task 071, with its own paper» — and when that lands these expectations
// flip. Do not «fix» them by changing the numbers; rewrite them with both
// halves of the history, the way the house does.
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

  testWidgets('today: two panels stand in the one slot, and the screen says they do not', (
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
          onHome: () {},
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
      find.byType(ReviewPanel),
      findsOneWidget,
      reason: 'the review panel did not open, so the pair below is not a pair',
    );
    expect(
      find.byType(TokensPanel),
      findsOneWidget,
      reason: 'the tokens panel did not open',
    );

    // **The pin.** Both are on the glass at once, in a slot whose own comment
    // says one panel at a time. 071 makes this impossible rather than merely
    // unlikely; when it lands, this expectation is the one that flips.
    final both = tester.getRect(find.byType(ReviewPanel));
    final tokens = tester.getRect(find.byType(TokensPanel));
    expect(
      both.overlaps(tokens),
      isFalse,
      reason: 'the two panels are drawn over each other rather than beside, '
          'which is a different fault from the one this pins',
    );
    expect(
      both.width + tokens.width,
      greaterThan(both.width),
      reason: 'two panels share the slot today — 071 is the repair, and this '
          'line is the record that they did',
    );
  });
}

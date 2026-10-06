// 041-P on the screen: the dialog a person opens by hand starts on the kind
// the model understands.
//
// The owner's hand-made protections went out as `CUSTOM`, and a model reads
// `PERSON`. The core now offers a person for one or two capitalised words —
// its last guess of all, after the pack and the findings — and this is the
// dialog showing it.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/protect_dialog.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Protokoll 2026\nBjörn Sandström ringde klockan 14 om fakturan 55123.\n';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('a name selected by hand opens the dialog on Person, and a number does not',
      (tester) async {
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-kind-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'sv');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'sv');
      await bench.rescan();
    });

    await tester.binding.setSurfaceSize(const Size(1500, 1000));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);

    Span spanOf(String needle) {
      final at = _doc.indexOf(needle);
      return Span(start: at, end: at + needle.length);
    }

    // The name, drawn by hand.
    await tester.runAsync(() => bench.select(spanOf('Björn Sandström')));
    await settle(tester, rounds: 2);
    await tester.tap(find.widgetWithText(ZButton, 'Protect'));
    await settle(tester, rounds: 3);

    expect(find.byType(ProtectDialog), findsOneWidget, reason: 'Protect opened no dialog');
    final dialog = tester.widget<ProtectDialog>(find.byType(ProtectDialog));
    expect(dialog.view.kind, Kind.person,
        reason: 'the dialog opens on ${dialog.view.kind}, and a model reads PERSON');

    await tester.tap(find.text('Cancel'));
    await settle(tester, rounds: 2);

    // And an invoice number is not a person: the app has no opinion, and says so.
    await tester.runAsync(() => bench.select(spanOf('55123')));
    await settle(tester, rounds: 2);
    expect(bench.selected!.kind, Kind.custom, reason: 'a number was offered as a person');

    bench.dispose();
  });
}

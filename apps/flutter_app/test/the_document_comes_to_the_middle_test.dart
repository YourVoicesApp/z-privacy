// 046/K · while he is reviewing, the document comes to the middle.
//
// **The owner, 7 October:** «ما أريده فعلاً هو جعل النص في حالة المعاينة ينتقل
// إلى نصف الشاشة ليصبح مركزياً بدلاً من تركه إلى جانب الهامش.» The text, while
// he is reviewing, in the middle of the screen at about half its width — not
// pressed against the left margin.
//
// Measured state before: `Expanded(_Columns)` took everything the side panel
// left, so at 1920 with a 460 panel the columns were ~1460 wide and began hard
// against the left edge. That edge is the margin he means.
//
// This file is the measurement rather than an opinion: it reports the width of
// each column with a panel open and with none, so the choice between «half,
// centred» and «half, centred, with the Safe column folded» is made on numbers
// a person can read.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

const _doc = 'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Thomas Müller\n'
    'IBAN: DE89370400440532013000\n'
    'Betrag und Bemerkungen zu dieser Seite, lang genug um zu brechen.\n';

const _originalPane = ValueKey<String>('workspace-original-pane');
const _safePane = ValueKey<String>('workspace-safe-pane');

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  testWidgets('with a panel open the columns are half the window and centred', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      final here = Directory('${Directory.systemTemp.path}/zprivacy-middle-$pid');
      if (here.existsSync()) here.deleteSync(recursive: true);
      addTearDown(() {
        if (here.existsSync()) here.deleteSync(recursive: true);
      });
      await z.setDataDir(dir: here.path);
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _doc);
      await bench.rescan();
      await bench.refresh();
    });
    addTearDown(bench.dispose);

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {}),
    ));
    await settle(tester);

    // **With no panel open nothing changed**, which is the half of this that
    // must be provable: the owner's complaint is about reviewing, and a
    // document being read alone should still have the whole window.
    final wideLeft = tester.getSize(find.byKey(_originalPane)).width;
    final wideRight = tester.getSize(find.byKey(_safePane)).width;
    final wideFrom = tester.getTopLeft(find.byKey(_originalPane)).dx;
    debugPrint('046/K · no panel  : left ${wideLeft.round()} · right ${wideRight.round()} · starts at ${wideFrom.round()}');
    expect(wideFrom, lessThan(40), reason: 'with no panel the document should keep the window');
    expect(wideLeft + wideRight, greaterThan(1400));

    // Now the review, which is the state he described.
    bench.openReview();
    await settle(tester);

    final left = tester.getSize(find.byKey(_originalPane)).width;
    final right = tester.getSize(find.byKey(_safePane)).width;
    final from = tester.getTopLeft(find.byKey(_originalPane)).dx;
    final to = tester.getTopRight(find.byKey(_safePane)).dx;
    debugPrint('046/K · reviewing : left ${left.round()} · right ${right.round()} · from ${from.round()} to ${to.round()}');

    // Half the window, within the rounding a border costs.
    expect(left + right, closeTo(960, 24),
        reason: 'the columns are not half the window: ${left + right}');

    // **Centred in what the panel leaves**, which is the owner's own word.
    // The panel is 460 at this width, so the free space is 0..1460 and its
    // middle is 730. The block's own middle must sit there.
    const panel = 460.0;
    expect((from + to) / 2, closeTo((1920 - panel) / 2, 24),
        reason: 'the block is not centred in the space the panel leaves');
    expect(from, greaterThan(200), reason: 'the document still begins at the left margin');
  });
}

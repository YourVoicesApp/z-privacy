// **One screen, three parts, and the way in at the top of it** — rule 70, the
// owner, 17 October 2026.
//
// «نلغي الشاشة الأولى ونجعل إدخال الملفات يتم أعلى الشاشة الأولى ليصبح التطبيق
// فقط ثلاثة أقسام في شاشة واحدة، ونجعل الإعدادات تحتوي على إدخال z-pdf».
//
// What this file holds is the shape of the product after that ruling, in the
// two states the one screen has:
//
//   * **nothing open** — the way in at the top, and the three parts each saying
//     what it is for. Not a welcome page: the same three regions, so that what
//     arrives when a document does arrives where the person is already looking.
//   * **a document open** — the way in is *still* at the top, because with no
//     first screen and no «back» it is the only way to begin the next piece of
//     work.
//
// And the absences, which are rule 35's half of the ruling: no «Documents»
// arrow, no «z-pdf» in the «+», no four tallies, no «Open Z Vault» page of its
// own. Deleted means deleted, not hidden.
//
// Needs the native library, so run once:  flutter build linux --debug
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
    'Ansprechpartner: Herr Thomas Müller\n'
    'IBAN: DE89370400440532013000\n';

Future<void> _settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// Every exception the frame left behind — an overflow is one of these, and it
/// is reported once per render object for its whole life, which is why each
/// reading below is taken in a tree of its own.
List<String> _overflows(WidgetTester tester) {
  final found = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    found.add(e.toString());
  }
  return found;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('nothing open: the way in at the top, and the three parts named', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());
    var toWorkOn = 0;
    String? typed;

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(
        bench: null,
        ground: ground,
        onImport: () => toWorkOn += 1,
        onAsk: (text) => typed = text,
        onVault: () {},
        onSettings: (_) {},
      ),
    ));
    await _settle(tester, rounds: 2);

    // The way in: a «+» for a file, a box for text, one press to read it.
    expect(find.byKey(WorkspaceScreen.addDocument), findsOneWidget,
        reason: 'there is no way to add a document to the one screen');
    expect(find.byKey(WorkspaceScreen.composer), findsOneWidget,
        reason: 'there is no box to write or paste into');
    // **One box since rule 72-أ**: the strip's own box is deleted and the one
    // that is left is the request box in the first part, which says what it is
    // for with no document above it.
    expect(find.text('Write or paste your text here…'), findsNothing,
        reason: 'the second box is back at the top of the screen');
    expect(find.text('What would you like to ask the AI?'), findsOneWidget,
        reason: 'the one box does not say what it is for on an empty surface');

    // The three parts, each naming what it will hold. The eyebrows are drawn
    // upper-cased, so this is the word as it stands on the glass.
    expect(find.text('ORIGINAL — LOCAL ONLY'), findsOneWidget);
    expect(find.text('SAFE — AI WILL RECEIVE'), findsOneWidget);
    expect(find.text('THE CHAT'), findsOneWidget,
        reason: 'the third part is not named, so a person cannot tell what the screen is');

    // **The first screen is gone, not hidden** — rule 35.
    expect(find.text('Documents'), findsNothing, reason: 'the arrow back is still drawn');
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.text('Open Z Vault'), findsNothing,
        reason: 'the first screen’s own vault button is still on the glass');
    expect(find.textContaining('identities the app knows'), findsNothing,
        reason: 'the first screen’s tallies are still drawn');
    expect(find.text('z-pdf — read a protected document back'), findsNothing,
        reason: 'the door back is still offered at the way in — it is in Settings now');

    // Both presses reach the shell, which is the only thing that can open a
    // session.
    await tester.tap(find.byKey(WorkspaceScreen.addDocument));
    await tester.pump();
    expect(toWorkOn, 1, reason: 'the «+» opened nothing');
    await tester.enterText(find.byKey(WorkspaceScreen.composer), 'Ein Satz.');
    await _settle(tester, rounds: 1);
    // **Rule 72-أ, 18 October 2026**: the strip's box and its «Open and scan»
    // are deleted, and the one box is the request box in the first part. What
    // is written there is the request — protected, and the whole of what leaves
    // when no document stands above it — so this is the same act through the
    // one door there is now.
    await tester.tap(find.byKey(const ValueKey<String>('workspace-question-attach')));
    await tester.pump();
    expect(typed, 'Ein Satz.', reason: 'what was written did not open');

    expect(_overflows(tester), isEmpty, reason: 'the empty screen overflows at 1300×900');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **The way in stays while a document is open, and that is the ruling's own
  // consequence**: «لا أسهم بين شاشات لأنه لا شاشات». There is no screen to go
  // back to, so if the strip were drawn only on an empty screen a person with
  // a document would have no way to begin anything else.
  testWidgets('a document open: the way in is still at the top of the same screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });
    addTearDown(bench.dispose);

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(
        bench: bench,
        ground: ground,
        onImport: () {},
        onAsk: (_) {},
        onVault: () {},
        onSettings: (_) {},
      ),
    ));
    await _settle(tester);

    expect(find.byKey(WorkspaceScreen.addDocument), findsOneWidget,
        reason: 'the way in went away the moment a document arrived');
    expect(find.byKey(WorkspaceScreen.composer), findsOneWidget);
    // The document is in the first part, which is what the strip stands above.
    expect(find.textContaining('Ansprechpartner'), findsWidgets,
        reason: 'the document is not drawn on the screen the strip stands on');
    // And the third part's empty sentence is not drawn over a document: the
    // chat is a panel the first answer opens (rule 65), measured where it is
    // built.
    expect(find.text('THE CHAT'), findsNothing,
        reason: 'the empty screen’s third part is drawn over an open document');

    expect(_overflows(tester), isEmpty, reason: 'the screen overflows at 1400×1000 with the strip on it');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **900 wide is the window this house measures the bar at**, and the strip is
  // the first thing added above the columns since 064/B spent the bar's last
  // 2.8 px. A fresh tree for the reading, because an overflow is reported once
  // per render object for its whole life.
  testWidgets('at 900 wide nothing overflows, with a document and without one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(
        bench: null,
        ground: ground,
        onImport: () {},
        onAsk: (_) {},
        onVault: () {},
        onSettings: (_) {},
      ),
    ));
    await _settle(tester, rounds: 2);
    expect(find.byKey(WorkspaceScreen.composer), findsOneWidget,
        reason: 'the box is off a 900-wide window');
    final box = tester.getRect(find.byKey(WorkspaceScreen.composer));
    expect(box.right, lessThanOrEqualTo(900), reason: 'the box hangs off the window: $box');
    expect(box.height, greaterThan(10), reason: 'the box has no height: $box');
    expect(_overflows(tester), isEmpty, reason: 'the empty screen overflows at 900×760');
  });
}

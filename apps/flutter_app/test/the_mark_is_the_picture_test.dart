// 072 · The mark on the screens is the owner's picture, not a lettered tile.
//
// His words, 9 October: «أريد أن تظهر صورة الشعار في شاشات التطبيق» — I want the
// logo picture to appear in the app's screens. What stood there was `ZMark`: a
// clay square with a Z in it, drawn in Dart. The picture itself — the
// lighthouse in a ring, his own — is `BrandMark`, built from
// `assets/brand/zprivacy-128.png` by `scripts/build_brand.py`, and it stood in
// exactly one place: the bottom-right **corner** of the first page, at 0.9
// opacity, under a comment that said so on purpose — «once, in the corner of
// the first page a person ever sees, and nowhere else in the app. A product
// that shows its badge on every screen is a product talking about itself.»
//
// The owner has ruled otherwise, and the reasoned sentence is quoted where it
// stood rather than deleted: the picture is in the heads now. What his word does
// **not** overturn is the half of that sentence about restraint — one picture
// per screen, never two, and small where it would stand over a person's work.
//
// Four places, by the lead's weighting: the first page a person ever sees
// (large), the chat's head, the panel's head, and the workspace's bar — the
// last two are a **swap** of the lettered tile for the picture at the same
// size, so nothing moves on either strip.
//
// ## Why a size and a rect, and not «it is there»
//
// The workspace bar is the strip this round has already cost 6.2 px twice over,
// and it had 2.8 px of margin before any of it. A swap is width-neutral in
// theory; the guard reads the overflow count with a fresh tree so that «in
// theory» is not what ships. And the first page's mark is measured as a size,
// because «large» is the owner's word and a 16 px picture would satisfy a
// finder.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Kunde: Nordstern Consulting GmbH\nIBAN DE02120300000000202051\n';

Future<void> _settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

List<String> _overflows(WidgetTester tester) {
  final found = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    found.add(e.toString());
  }
  return found;
}

Future<({Ground ground, Workbench bench})> _ready(WidgetTester tester, String name) async {
  late final ({Ground ground, Workbench bench}) made;
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-mark-$name-$pid');
    if (own.existsSync()) own.deleteSync(recursive: true);
    own.createSync(recursive: true);
    addTearDown(() {
      if (own.existsSync()) own.deleteSync(recursive: true);
    });
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för märket');
    final session = await z.openSession(profileId: null, packId: 'de');
    final bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    await ground.refresh();
    made = (ground: ground, bench: bench);
  });
  return made;
}

/// The picture's own size, read off the widget rather than off its box.
double _markSize(WidgetTester tester) => tester.widget<BrandMark>(find.byType(BrandMark)).size;

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('the first page a person sees carries the picture, large', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'first');
    await tester.pumpWidget(MaterialApp(
      home: FirstRunScreen(ground: g.ground, onStart: (_, {required bool wantsVault}) {}),
    ));
    await _settle(tester);

    expect(find.byType(BrandMark), findsOneWidget, reason: 'the first page draws no picture at all');
    // «Large» is his word, and this is the number it was given: 64 px, the
    // badge's own default and nearly twice the lettered tile it replaced (38).
    expect(_markSize(tester), greaterThanOrEqualTo(56),
        reason: 'the picture is ${_markSize(tester)} px on the page the owner asked for it large');
    final r = tester.getRect(find.byType(BrandMark));
    expect(r.right, lessThanOrEqualTo(1200), reason: 'the picture is off the window: $r');
    expect(r.width, greaterThanOrEqualTo(56), reason: 'the picture has no width on the glass: $r');
    // And the lettered tile is gone from it: one identity on one screen.
    expect(find.byType(ZMark), findsNothing, reason: 'the lettered tile still stands beside the picture');
    expect(_overflows(tester), isEmpty, reason: 'the first page overflows with the picture on it');
  });

  // ------------------------------------------------------------------ guard 2
  testWidgets('the chat’s head and the panel’s head carry it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'chat');

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        ground: g.ground,
        version: 'z_core 0.1.0',
        chat: g.bench,
        onImport: () {},
        onType: (_) {},
        onAsk: (_) async {},
        onVault: () {},
        onSettings: () {},
      ),
    ));
    await _settle(tester);
    expect(find.byType(BrandMark), findsOneWidget, reason: 'the chat’s head draws no picture');
    expect(find.byType(ZMark), findsNothing, reason: 'the chat’s head still wears the lettered tile');
    final chat = tester.getRect(find.byType(BrandMark));
    expect(chat.top, lessThan(120), reason: 'the picture is not in the head of the chat: $chat');
    expect(_overflows(tester), isEmpty, reason: 'the chat’s head overflows with the picture on it');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SettingsScreen(ground: g.ground, onClose: () {})),
    ));
    await _settle(tester);
    expect(find.byType(BrandMark), findsOneWidget, reason: 'the panel’s head draws no picture');
    final panel = tester.getRect(find.byType(BrandMark));
    expect(panel.top, lessThan(80), reason: 'the picture is not in the panel’s head: $panel');
    expect(_overflows(tester), isEmpty, reason: 'the panel’s head overflows with the picture on it');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The swap cost the crowded strip nothing, and that is read rather than
  // reasoned about.** This bar had 2.8 px of margin before this round, and this
  // round has already spent 6.2 px of it twice by accident. The picture is the
  // same 28 px the lettered tile was, so the count at 900 must be what it was:
  // empty. A fresh tree, because an overflow is reported once per render object
  // for its whole life.
  testWidgets('the workspace bar wears it, and 900 wide still holds', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'bar');
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(
        bench: g.bench,
        ground: g.ground,
        onHome: () {},
        onVault: () {},
        onSettings: () {},
      ),
    ));
    await _settle(tester);

    expect(find.byType(BrandMark), findsOneWidget, reason: 'the work screen draws no picture');
    expect(find.byType(ZMark), findsNothing, reason: 'the bar still wears the lettered tile');
    expect(_markSize(tester), 28, reason: 'the picture is not the size the tile was, so the bar moved');
    final r = tester.getRect(find.byType(BrandMark));
    expect(r.right, lessThanOrEqualTo(900), reason: 'the picture is off a 900-wide window: $r');
    expect(_overflows(tester), isEmpty, reason: 'the bar overflows at 900 with the picture on it');
  });
}

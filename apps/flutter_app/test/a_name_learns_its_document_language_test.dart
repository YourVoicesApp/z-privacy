// 041-I/2 · The language a name is learned in is the document's, not the
// device's — and a list taught under the wrong one moves in a single act.
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
const _pass = 'ett tillräckligt långt lösenord';

/// A Swedish letter, of the kind the owner was working on.
const _swedish =
    'Hej,\n'
    'Lars Reinholdsson har granskat avtalet.\n'
    'Med vänliga hälsningar\n'
    'Anna Pettersson\n';

Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

void main() {
  late Directory dir;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  /// A device set up in German, with an open vault — the owner's own.
  Future<(Workbench, Ground)> aGermanDevice(WidgetTester tester, String tag) async {
    final ground = Ground();
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      dir = Directory('${Directory.systemTemp.path}/zprivacy-doclang-$tag-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: _pass);
      // German is what a fresh device starts with, which is the premise of
      // the whole defect — said here rather than assumed.
      expect((await z.settings()).packId, 'de');
      await ground.refresh();
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _swedish);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });
    await tester.binding.setSurfaceSize(const Size(1700, 1000));
    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}, onVault: () {})),
    );
    await settle(tester);
    return (bench, ground);
  }

  testWidgets('a name taught from a Swedish document is a Swedish name', (tester) async {
    final (bench, _) = await aGermanDevice(tester, 'teach');

    // The owner's run: the session is switched to Swedish, the bar says so.
    await tester.runAsync(() async {
      await bench.switchPack('sv');
      await bench.teachName('Reinholdsson', family: true);
      await bench.refreshUserNames();
    });
    await settle(tester);

    final lists = {for (final l in bench.userLists) l.name: l.names};
    expect(lists['sv'], 1, reason: 'the Swedish name is not in the Swedish list: $lists');
    expect(lists.containsKey('de'), isFalse, reason: 'a German list was made for a Swedish name: $lists');
    // And the dialog for a typed name offers the same language the bar names.
    expect(bench.intoList, 'sv', reason: 'the «Add a name» dialog would still say German');
    bench.dispose();
  });

  testWidgets('a list learned under the wrong language moves in one act', (tester) async {
    final (bench, _) = await aGermanDevice(tester, 'move');

    // Taught before the switch — three names in the device's language, which
    // is how the owner ended with 75 Swedish surnames under German.
    await tester.runAsync(() async {
      for (final name in ['Pettersson', 'Bergström', 'Lindqvist']) {
        await bench.teachName(name, family: true);
      }
      await bench.refreshUserNames();
    });
    await settle(tester);
    expect({for (final l in bench.userLists) l.name: l.names}['de'], 3,
        reason: 'the three are not in the German list to begin with');

    await tester.runAsync(() => bench.moveList('de', 'sv'));
    await settle(tester);

    final after = {for (final l in bench.userLists) l.name: l.names};
    expect(after['sv'], 3, reason: 'the names did not arrive: $after');
    expect(after.containsKey('de'), isFalse, reason: 'the emptied list is still on the screen: $after');
    expect(bench.namesSaid, contains('3'), reason: 'the screen did not say how many moved');
    bench.dispose();
  });
}

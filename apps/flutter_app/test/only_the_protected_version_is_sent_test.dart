// **Rule 62 — only the protected version is sent to AI through Z.** The owner,
// 17 October, after the attacker's م1: the «original text» choice is deleted
// from «Who answers». Whatever door the text leaves by, what leaves is the
// protected version; a person who wants to send their own document as it
// stands sends it themselves, outside Z.
//
// So the first screen's promise and the site's — «Only the protected version
// is sent to AI through Z Privacy» — are true of the whole program rather than
// of one of two modes, and this file is where that is measured.
//
// Two halves, because a deleted choice is two facts:
//
//   * **the glass offers it nowhere.** A chip with no alternative is deleted,
//     not hidden (rule 35), so the section itself is gone and not greyed;
//   * **no door in this app can carry a document to a model.** A closed door
//     on the glass with its handle still in the code is the state it is
//     re-opened from tomorrow with nobody deciding to. The second half is
//     measured over the app's own sources, generated bridge included — because
//     the bridge is the handle, and it is written by a generator rather than by
//     a hand that could be told.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

const _doc = 'Kunde: Nordstern Consulting GmbH\n'
    'Ansprechpartner: Herr Thomas Müller\n';

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

/// «Who answers», open over a document with something in it to protect.
Future<Workbench> _sheet(WidgetTester tester, String name) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final here = Directory('${Directory.systemTemp.path}/zprivacy-rule62-$name-$pid');
    removeWhenItLetsGo(here);
    addTearDown(() {
      removeWhenItLetsGo(here);
    });
    await z.setDataDir(dir: here.path);
    final session = await z.openSession(packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    await bench.rescan();
    await ground.refresh();
  });
  addTearDown(bench.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SendSheet(bench: bench, ground: ground)),
  ));
  await settle(tester);
  return bench;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  testWidgets('«Who answers» offers no way to send the original — rule 62', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _sheet(tester, 'glass');

    // The page is the right one, so «findsNothing» below is about this page
    // and not about a sheet that failed to open.
    expect(find.text(sentences.whoAnswers), findsOneWidget, reason: 'the sheet did not open');

    // The section, its two chips and the sentence that warned about one of
    // them. Each named separately: a guard that asked only about the chip
    // would pass over a heading left standing on its own.
    for (final gone in <String>[
      'What travels',
      'The original text',
      'Protected text',
    ]) {
      expect(
        find.text(gone),
        findsNothing,
        reason: '«$gone» is still on «Who answers», so the choice was hidden rather than deleted',
      );
    }
    expect(
      find.textContaining('goes as it is written'),
      findsNothing,
      reason: 'the warning about sending the original is still drawn, so the mode it warned about is still reachable',
    );

    // And the sheet still says what does leave, in the one place it says it.
    expect(
      find.textContaining('characters would leave this device'),
      findsOneWidget,
      reason: 'the page no longer says what travels at all, which is not what rule 62 asked for',
    );
  });

  test('no door in this app carries a document to a model — rule 62', () async {
    // The handles, by the names they had: the bridge call, the mode on the
    // bench, the press that chose it, and the bench door that took a document
    // as an argument. Any one of them left in the tree is the door still being
    // there with only its chip taken off the glass.
    const handles = <String>[
      'askModelDirectly',
      'askModelWithTheOriginal',
      'sendOriginal',
      'chooseOriginal',
    ];
    final found = <String>[];
    final lib = Directory('lib');
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = await file.readAsString();
      for (final handle in handles) {
        if (text.contains(handle)) found.add('${file.path} names «$handle»');
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'a door that sends a document as it stands is still in this app:\n${found.join('\n')}',
    );
  });
}

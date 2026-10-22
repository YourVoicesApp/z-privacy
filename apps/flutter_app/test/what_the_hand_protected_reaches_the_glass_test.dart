// **What the disk refused must reach the glass, and the badge must say what
// ran** — paper 102 §2 and §4, the glass half of the two-window eye round on
// the `78988fd` artefacts (the tenth report's own minute table).
//
// Three guards, each for a sentence the owner read on his own screen and found
// false:
//
//   * «Not scanned yet» stood for ever over a typed request the scanner had
//     just read, because the badge read the **document's** scan origin and
//     there was no document;
//   * the session he had just picked from the room was named nowhere at the
//     top until a document was brought in;
//   * and «Protected as …, in 5 places» was answered for twenty-four minutes
//     by a copy whose every write the disk refused, with no sentence anywhere.
//     The sentence for it is published and was unreachable: the one function
//     every protect door writes through threw the refusal away.
//
// The Rust side measures the disk (`what_the_hand_protected_reaches_the_disk`);
// this measures the screen, because «nothing is lost silently» is a promise
// about what a person is told.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'the_bridge_the_tests_speak_through.dart';
import 'the_folder_lets_go.dart';

final _libPath = theBridgeTheTestsSpeakThrough;
const _pass = 'ein gutes Passwort für den Tresor';

/// A document with two names no dictionary knows: only a hand protects them,
/// so what the guards below press is the person's own decision.
const _doc = 'Payroll run, February\n'
    'Prepared by: Hedvig Palmgren\n'
    'Checked by: Ingmar Takala\n';

/// What is typed with nothing above it. «Rückruf» is in no pack we ship.
const _request = 'Herr Thomas Müller bittet um Rückruf';

Future<void> _settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// A folder of this file's own with a vault in it — and the folder itself,
/// because two of the guards below read and write `vault.zv` the way a second
/// window would.
Future<(Ground, Directory)> _aVault(WidgetTester tester, String name) async {
  final ground = Ground();
  final dir = Directory('${Directory.systemTemp.path}/zprivacy-glass-$name-$pid');
  await tester.runAsync(() async {
    removeWhenItLetsGo(dir);
    addTearDown(() {
      try {
        removeWhenItLetsGo(dir);
      } on FileSystemException {
        // Left behind rather than red for something no claim here is about.
      }
    });
    await z.vaultLock();
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    await ground.refresh();
  });
  return (ground, dir);
}

Widget _surface(Ground ground, Workbench? bench) => MaterialApp(
      home: WorkspaceScreen(
        bench: bench,
        ground: ground,
        onImport: () {},
        onAsk: (_) {},
        onVault: () {},
      ),
    );

/// A span over a text, by the word's own characters.
Span _spanOf(String whole, String word) {
  final at = whole.indexOf(word);
  final start = whole.substring(0, at).length;
  return Span(start: start, end: start + word.length);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  testWidgets('a typed request says it was read, and names no document', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, _) = await _aVault(tester, 'typed');
    late final Workbench bench;
    await tester.runAsync(() async {
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      addTearDown(bench.dispose);
      await bench.setQuestion(_request);
      await ground.refresh();
    });
    await tester.pumpWidget(_surface(ground, bench));
    await _settle(tester);

    expect(
      find.text(sentences.scannedAsYouTyped),
      findsOneWidget,
      reason: 'the band does not say that what was typed was read',
    );
    expect(
      find.text(sentences.notScannedYet),
      findsNothing,
      reason: 'the band still says «Not scanned yet» over a request the scanner read',
    );
    // **And it names no document**, because there is none: the snapshot's
    // `document` is not an `Option`, so an empty one used to be drawn as a
    // typed-text file on the bar.
    expect(
      find.text(sentences.typedText),
      findsNothing,
      reason: 'the bar names a document over a bench that holds none',
    );
    // The three counts are the scan's findings, and a request has none: one
    // false line removed, and what the request replaced is said under the box.
    expect(
      find.text(sentences.protectedAutomaticallyNeedYourWord(0, 0, 0)),
      findsNothing,
      reason: 'the band counts a document that is not there',
    );
  });

  // ------------------------------------------------------------------ guard 2
  testWidgets('the session a person picked is named at the top with no document', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, _) = await _aVault(tester, 'named');
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.conversationBegin(name: 'Nordstern', bench: null);
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      addTearDown(bench.dispose);
      await ground.refresh();
    });
    await tester.pumpWidget(_surface(ground, bench));
    await _settle(tester);

    final mark = find.byKey(TheOpenSession.mark);
    expect(
      mark,
      findsOneWidget,
      reason: 'the top of the screen says nothing about the session that is open',
    );
    expect(
      find.descendant(of: mark, matching: find.textContaining('Nordstern')),
      findsOneWidget,
      reason: 'the session is on the bar without its own name',
    );
  });

  // ------------------------------------------------------------------ guard 3
  testWidgets('a press whose vault was refused says so on the glass', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (ground, dir) = await _aVault(tester, 'refused');
    late final Workbench bench;
    await tester.runAsync(() async {
      final session = await z.openSession(profileId: null, packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      addTearDown(bench.dispose);
      await bench.refresh();
      // One cover, so the vault file holds this bench's work and this copy
      // knows what it last wrote.
      await z.protect(
        session: session,
        span: _spanOf(_doc, 'Palmgren'),
        scope: Scope.conversation,
        kind: Kind.person,
      );
      // **What a second window still holds**: an earlier state of this very
      // vault, which is exactly what the other copy would write back.
      final vault = File('${dir.path}/vault.zv');
      final aside = File('${dir.path}/what-the-other-copy-holds');
      await vault.copy(aside.path);
      await z.protect(
        session: session,
        span: _spanOf(_doc, 'Takala'),
        scope: Scope.conversation,
        kind: Kind.person,
      );
      await aside.copy(vault.path);
      // The press the owner made for twenty-four minutes.
      await z.protect(
        session: session,
        span: _spanOf(_doc, 'February'),
        scope: Scope.conversation,
        kind: Kind.custom,
      );
      await bench.refresh();
    });
    await tester.pumpWidget(_surface(ground, bench));
    await _settle(tester);

    expect(
      find.text(sentences.troubleVaultChangedElsewhere),
      findsOneWidget,
      reason: 'the disk refused every write and the screen says nothing of it',
    );
  });
}

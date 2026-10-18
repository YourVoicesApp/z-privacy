// The gateway, on the screen: a model chosen from the core's catalogue, and a
// bench with one send door.
//
// **It measured a mode until 17 October** — «a mode a person cannot be in by
// accident», which was the honest guard while there were two of them. Rule 62
// deleted the second, so what is left to measure is that there is nothing to
// choose and nothing to inherit: the model, and a send that carries the
// payload. The absence itself is measured in
// `only_the_protected_version_is_sent_test.dart`.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'the_folder_lets_go.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _doc = 'Kunde: Nordstern Consulting GmbH\nAnsprechpartner: Herr Thomas Müller\n';

void main() {
  late Directory dir;

  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
    dir = Directory('${Directory.systemTemp.path}/zprivacy-gateway-$pid');
    removeWhenItLetsGo(dir);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    removeWhenItLetsGo(dir);
  });

  testWidgets('the catalogue comes from the core, and no model is named in Dart', (tester) async {
    late final List<ModelDescriptor> catalogue;
    await tester.runAsync(() async => catalogue = await z.models());

    expect(catalogue, isNotEmpty, reason: 'the core offers no models');
    // More than one provider, so a chooser is a chooser.
    final providers = catalogue.map((m) => m.providerId).toSet();
    expect(providers.length, greaterThanOrEqualTo(2), reason: '$providers');
    for (final model in catalogue) {
      expect(model.displayName, isNotEmpty);
      expect(model.capabilities, contains(ModelCapability.text));
    }
    // And the one thing a screen may not do: carry a model's name itself.
    //
    // Read inside `runAsync`, because a real future does not complete in the
    // fake-async zone a widget test runs in — the same reason every other test
    // in this folder has a `settle` helper.
    late final String dart;
    await tester.runAsync(
      () async => dart = await File('lib/widgets/send_sheet.dart').readAsString(),
    );
    for (final model in catalogue) {
      expect(
        dart.contains(model.modelId),
        isFalse,
        reason: '«${model.modelId}» is written into the send sheet, which the catalogue exists to prevent',
      );
    }
  });

  testWidgets('a workbench sends the payload, and there is nothing else to choose', (tester) async {
    late final Workbench bench;
    await tester.runAsync(() async {
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      // The catalogue is asked for when it is needed — by the send sheet as it
      // opens, and here by the test that is standing in for it. A scan does
      // not fetch it: making one wait on the other cost two screen tests their
      // timing, and a scan's result does not depend on a list of model names.
      await bench.refreshModels();
    });

    expect(bench.chosenModel, isNull, reason: 'the provider\'s own model answers until one is chosen');
    expect(bench.models, isNotEmpty, reason: 'the chooser would open empty');

    // A model is chosen by its id, from the catalogue, and cleared back to the
    // provider's own.
    final first = bench.models.first.modelId;
    bench.chooseModel(first);
    expect(bench.chosenModel, first);
    bench.chooseModel(null);
    expect(bench.chosenModel, isNull);

    // A send with no provider connected is refused, and it stays refused: the
    // bench has no second door to retry it through — and since rule 62 it has
    // no second door at all.
    await tester.runAsync(() async {
      final said = await bench.askModelProtected('openai');
      expect(said, isNotNull, reason: 'an unconnected provider answered');
    });
    bench.dispose();
  });

  // **The rule this test measured is answered by deletion** — rule 62.
  //
  // It walked the owner's own order: choose the original → open another
  // document → the mode is back to protected, «which is the one thing it may
  // never do». There is no mode to inherit now, so the guard that measured the
  // inheriting is gone and the one that measures the absence stands in
  // `only_the_protected_version_is_sent_test.dart`.
  //
  // What is kept from it is the half that is still about this file: a document
  // that arrives is scanned, and the bench that holds it sends a payload.
  testWidgets('a document that arrives is read, and what it sends is the payload', (tester) async {
    late final Workbench bench;
    await tester.runAsync(() async {
      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
    });
    expect(bench.suggested, isNotEmpty, reason: 'the first document was not read');

    // Another document arrives into the same workbench, and the bench holds
    // that one. Read as the document rather than as a count of suggestions:
    // what arrives second here is «ein ganz anderes Dokument, ohne Namen», and
    // a guard that asked it for findings would be asking it for the one thing
    // it was written not to have.
    const other = 'Ein ganz anderes Dokument, ohne Namen.';
    await tester.runAsync(() async {
      await z.importText(session: bench.session, text: other);
      await bench.rescan();
    });
    expect(bench.document?.text, contains('ohne Namen'),
        reason: 'the second document did not reach the bench');

    // And the only send this bench has takes no text: it is refused for want
    // of a provider, never for want of a mode.
    await tester.runAsync(() async {
      final said = await bench.askModelProtected('openai');
      expect(said, isNotNull, reason: 'an unconnected provider answered');
    });
    bench.dispose();
  });
}

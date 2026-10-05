// The gateway, on the screen: a model chosen from the core's catalogue, and a
// mode a person cannot be in by accident.
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
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await z.setDataDir(dir: dir.path);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
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

  testWidgets('a workbench starts protected, and the original is a chosen thing', (tester) async {
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

    // The default is the only default there is.
    expect(bench.sendOriginal, isFalse, reason: 'a workbench must not start unprotected');
    expect(bench.chosenModel, isNull, reason: 'the provider\'s own model answers until one is chosen');
    expect(bench.models, isNotEmpty, reason: 'the chooser would open empty');

    // Choosing is one press, and nothing else changes it.
    bench.chooseOriginal(true);
    expect(bench.sendOriginal, isTrue);
    bench.chooseOriginal(false);
    expect(bench.sendOriginal, isFalse);

    // A model is chosen by its id, from the catalogue, and cleared back to the
    // provider's own.
    final first = bench.models.first.modelId;
    bench.chooseModel(first);
    expect(bench.chosenModel, first);
    bench.chooseModel(null);
    expect(bench.chosenModel, isNull);

    // A send with no provider connected is refused, and it stays refused: the
    // bench has no path that retries without protection.
    await tester.runAsync(() async {
      final said = await bench.askModel('openai', original: _doc);
      expect(said, isNotNull, reason: 'an unconnected provider answered');
    });
    expect(bench.sendOriginal, isFalse, reason: 'a failed protected send changed the mode');
    bench.dispose();
  });
}

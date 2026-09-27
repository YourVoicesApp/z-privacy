// The whole contract, called from Dart, on the real Rust library.
//
// This is the proof that M1 asks for: every function on the surface can be
// called today and answers with a typed error instead of killing the isolate.
// "No panic crosses the boundary" is checked here, not hoped for.
//
// Needs the native library, so run once:  flutter build linux --debug
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

void main() {
  setUpAll(() async {
    final lib = File(_libPath);
    if (!lib.existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    // The default loader finds libz_bridge.so on the library path; the test
    // runner is started with LD_LIBRARY_PATH pointing at the built bundle.
    await RustLib.init();
  });

  test('the window reads its version from Rust', () {
    expect(coreVersion(), startsWith('z_core 0.'));
  });

  test('every call on the contract answers; none of them crashes', () async {
    final session = const SessionId(id: 1);
    final handle = const PayloadHandle(id: 1, session: 1, revision: 1);
    final answer = const AnswerId(id: 1);
    final span = const Span(start: 0, end: 4);
    final provider = const ProviderId(id: 'openai');

    // The whole surface, in the order it appears in the contract.
    final calls = <String, Future<void> Function()>{
      'openSession': () => openSession(packId: 'de'),
      'closeSession': () => closeSession(session: session),
      'sessionRevision': () => sessionRevision(session: session),
      'importText': () => importText(session: session, text: 'Hallo'),
      'documentView': () => documentView(session: session),
      'scan': () => scan(session: session),
      'protect': () =>
          protect(session: session, span: span, scope: Scope.once, kind: Kind.person),
      'protectAllMatches': () => protectAllMatches(
          session: session, span: span, scope: Scope.conversation, kind: Kind.company),
      'undoLastProtection': () => undoLastProtection(session: session),
      'addAlias': () => addAlias(session: session, token: 't', alias: 'a'),
      'listFindings': () => listFindings(session: session),
      'answerFinding': () => answerFinding(
          session: session, finding: 1, answer: FindingAnswer.protect),
      'reveal': () => reveal(session: session, token: 't'),
      'hide': () => hide_(session: session, token: 't'),
      'listTokens': () => listTokens(session: session),
      'buildPayload': () => buildPayload(session: session),
      'payloadView': () => payloadView(handle: handle),
      'send': () => send(handle: handle, provider: provider),
      'ingestAnswer': () => ingestAnswer(session: session, raw: 'x'),
      'restoredView': () => restoredView(session: session, answer: answer),
      'aiView': () => aiView(session: session, answer: answer),
      'vaultState': () => vaultState(),
      'vaultUnlock': () => vaultUnlockWithPassphrase(passphrase: 'x'),
      'vaultLock': () => vaultLock(),
      'profiles': () => profiles(),
      'switchProfile': () => switchProfile(session: session, profileId: 'p'),
      'packs': () => packs(),
      'switchPack': () => switchPack(session: session, packId: 'de'),
      'providers': () => providers(),
      'testProvider': () => testProvider(provider: provider),
    };

    final unexpected = <String>[];
    for (final entry in calls.entries) {
      try {
        await entry.value();
        // Nothing on the surface is built yet, so a success is the surprise.
        unexpected.add('${entry.key}: returned instead of erroring');
      } on ApiError catch (e) {
        // A typed error is the pass: the contract answered in its own words.
        if (e is! ApiError_NotImplemented) {
          unexpected.add('${entry.key}: ${e.runtimeType}');
        }
      } catch (e) {
        // Anything else — a panic turned into PanicException, a type error —
        // is exactly what this test exists to catch.
        unexpected.add('${entry.key}: ${e.runtimeType} $e');
      }
    }
    expect(unexpected, isEmpty, reason: 'calls that did not answer cleanly');
    expect(calls.length, 30, reason: 'the contract has 30 functions');
  });
}

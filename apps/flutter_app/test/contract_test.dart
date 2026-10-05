// The whole contract, called from Dart, on the real Rust library.
//
// The invariant this file defends is G7: **no panic crosses the boundary.** Every
// call answers — with a value, or with a typed ApiError the UI can read. Anything
// else (a PanicException, a type error, a dead isolate) fails the test.
//
// It also walks the real sequence, so the Dart side is proven to reach what the
// core can already do: import, scan, protect, build, send.
//
// Needs the native library, so run once:  flutter build linux --debug
import 'dart:io';
import 'dart:typed_data';

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
      throw StateError(
        'no $_libPath — run `flutter build linux --debug` first',
      );
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
      'importDocument': () => importDocument(
        session: session,
        name: 'leer.txt',
        bytes: Uint8List.fromList('Kunde: Nordstern GmbH'.codeUnits),
        kind: DocumentKind.txt,
      ),
      'documentView': () => documentView(session: session),
      'importReport': () => importReport(subject: ReportSubject.imported(session: session)),
      'nameCandidates': () => nameCandidates(session: session),
      'models': () => models(),
      'askModel': () async {
        // No provider is connected in this test, so the refusal is the answer:
        // the call is reached, and the protected door takes a handle.
        try {
          final handle = await buildPayload(session: session);
          await askModel(
            handle: handle,
            provider: const ProviderId(id: 'openai'),
            workspace: const [],
            history: const [],
          );
        } on ApiError {
          // named, not swallowed
        }
      },
      'askModelDirectly': () async {
        try {
          await askModelDirectly(
            session: session,
            text: 'hello',
            provider: const ProviderId(id: 'openai'),
            workspace: const [],
            history: const [],
          );
        } on ApiError {
          // the same: a door that refuses is a door that was reached
        }
      },
      'teachName': () async {
        // The vault is locked in this test, so the refusal is the answer: the
        // call is reached, and it says what it needs.
        try {
          await teachName(text: 'Kowalski', family: true);
        } on ApiError {
          // named, not swallowed: `messages_test` holds the sentence
        }
      },
      'forgetName': () async {
        try {
          await forgetName(id: 1);
        } on ApiError {
          // a vault that is not open has nothing to forget
        }
      },
      'taughtNames': () async {
        try {
          await taughtNames();
        } on ApiError {
          // the same
        }
      },
      'scan': () => scan(session: session),
      'protect': () => protect(
        session: session,
        span: span,
        scope: Scope.once,
        kind: Kind.person,
      ),
      'protectAllMatches': () => protectAllMatches(
        session: session,
        span: span,
        scope: Scope.conversation,
        kind: Kind.company,
      ),
      'undoLastProtection': () => undoLastProtection(session: session),
      'addAlias': () => addAlias(session: session, token: 't', alias: 'a'),
      'listFindings': () => listFindings(session: session),
      'answerFinding': () => answerFinding(
        session: session,
        finding: 1,
        answer: FindingAnswer.protect,
      ),
      'teachException': () =>
          teachException(session: session, finding: 1, scope: Scope.always),
      'reveal': () => reveal(session: session, token: 't'),
      'hide': () => hide_(session: session, token: 't'),
      'listTokens': () => listTokens(session: session),
      'buildPayload': () => buildPayload(session: session),
      'payloadView': () => payloadView(handle: handle),
      'send': () => send(handle: handle, provider: provider),
      'ingestAnswer': () => ingestAnswer(payload: handle, raw: 'x'),
      'restoredView': () => restoredView(session: session, answer: answer),
      'aiView': () => aiView(session: session, answer: answer),
      'vaultState': () => vaultState(),
      'vaultUnlock': () => vaultUnlockWithPassphrase(passphrase: 'x'),
      'vaultLock': () => vaultLock(),
      'profiles': () => profiles(),
      'switchProfile': () => switchProfile(session: session, profileId: 'p'),
      'renameProfile': () =>
          renameProfile(profileId: 'p', name: 'Test renamed'),
      'packs': () => packs(),
      'ruleSets': () => ruleSets(),
      'revealState': () => revealState(),
      'hideValue': () => hideValue(),
      'revealedTokens': () => revealedTokens(session: session),
      'hideAllReveals': () => hideAllReveals(),
      'windowFocusLost': () => windowFocusLost(),
      'windowHidden': () => windowHidden(),
      'setProfileLanguages': () => setProfileLanguages(profileId: 'p-none', languages: ['de']),
      'teachLabelRule': () => teachLabelRule(label: 'Mandantenkennung', kind: Kind.customerNo, profileId: null),
      'forgetLabelRule': () => forgetLabelRule(id: 1),
      'labelRules': () => labelRules(),
      'switchPack': () => switchPack(session: session, packId: 'de'),
      'providers': () => providers(),
      'connectProvider': () => connectProvider(
        provider: provider,
        credential: 'sk-test',
        baseUrl: 'https://api.openai.com',
      ),
      'configureProvider': () => configureProvider(provider: provider),
      'renameEntity': () => renameEntity(entityId: 1, label: 'Test'),
      'moveEntity': () => moveEntity(entityId: 1),
      'deleteValue': () => deleteValue(entity: 1, valueId: 1),
      'removeValueAlias': () =>
          removeValueAlias(entity: 1, valueId: 1, alias: 'x'),
      'searchVault': () => searchVault(query: 'x'),
      'kinds': () => kinds(),
      'explain': () => explain(session: session, span: span),
      'unprotect': () => unprotect(session: session, span: span),
      'forgetPlan': () => forgetPlan(entity: 1, valueId: 1, everywhere: false),
      'forgetValue': () =>
          forgetValue(entity: 1, valueId: 1, everywhere: false),
      'forgetException': () => forgetException(id: 1),
      'settings': () => settings(),
      'saveSettings': () => saveSettings(
        settings: const Settings(
          scanOnImport: true,
          revealSeconds: 20,
          autoLockMinutes: 15,
          packId: 'de',
          language: 'en',
          firstRunDone: false,
          sessionOnly: true,
        ),
      ),
      'inspectSelection': () => inspectSelection(session: session, span: span),
      'disconnectProvider': () => disconnectProvider(provider: provider),
      'testProvider': () => testProvider(provider: provider),
      // The vault (M4). Called against a locked, absent vault here: the answers
      // must still be answers.
      'setDataDir': () => setDataDir(dir: Directory.systemTemp.path),
      // The core's own answer for where the vault belongs. Called here so the
      // contract stays whole; what it must *say* is checked in Rust, on every
      // platform the suite runs on.
      'defaultDataDir': () => defaultDataDir(),
      'vaultCreateWithPassphrase': () =>
          vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort'),
      'vaultChangePassphrase': () => vaultChangePassphrase(
        old: 'ein gutes Passwort',
        replacement: 'ein anderes Passwort',
      ),
      'entities': () => entities(),
      'entity': () => entity(entityId: 1),
      'createEntity': () =>
          createEntity(kind: EntityKind.client, label: 'Test', profileId: null),
      'deleteEntity': () => deleteEntity(entityId: 1),
      'setValue': () => setValue(
        entity: 1,
        valueId: null,
        kind: Kind.company,
        text: 'Test GmbH',
        policy: Policy.always,
      ),
      'addValueAlias': () =>
          addValueAlias(entity: 1, valueId: 1, alias: 'Test'),
      'revealValue': () => revealValue(entity: 1, valueId: 1),
      'createProfile': () => createProfile(name: 'Test'),
      'homeSnapshot': () => homeSnapshot(),
      'workspaceSnapshot': () => workspaceSnapshot(session: session),
      'vaultSnapshot': () => vaultSnapshot(),
      'privacyRulesSnapshot': () => privacyRulesSnapshot(),
      'providerSnapshot': () => providerSnapshot(),
      'answerSnapshot': () => answerSnapshot(session: session, answer: answer),
    };

    final crashed = <String>[];
    final pending = <String>[];
    for (final entry in calls.entries) {
      try {
        await entry.value();
        // A value came back: the call is built and answered.
      } on ApiError catch (e) {
        // A typed error is also an answer — the contract speaking in its own
        // words. Only the "not built yet" ones are worth listing.
        if (e is ApiError_NotImplemented) pending.add(entry.key);
      } catch (e) {
        // Anything else is what this test exists to catch: a panic turned into
        // PanicException, a type error, a dead isolate.
        crashed.add('${entry.key}: ${e.runtimeType} $e');
      }
    }
    expect(crashed, isEmpty, reason: 'calls that did not answer cleanly');
    // Gate G17 checks this number against `pub fn` in api.rs, so a function
    // added to the contract and forgotten here fails the build rather than
    // passing quietly — which is what happened when the contract went from 52
    // to 54 and this line still said 52.
    expect(calls.length, 87, reason: 'the contract has 87 functions');
    // ignore: avoid_print
    print('still NotImplemented (${pending.length}): $pending');
    await vaultLock();
  });

  test('a document protects itself, driven from Dart', () async {
    // The M3 turn, through the bridge: nothing is selected by hand.
    const doc =
        'Kunde: Nordstern Consulting GmbH\n'
        'Telefon: +49 171 2345678\n'
        'IBAN: DE89 3704 0044 0532 0130 00\n'
        'BIC: COBADEFFXXX\n';
    final session = await openSession(packId: 'de');
    await importText(session: session, text: doc);

    final report = await scan(session: session);
    expect(report.auto, 3, reason: 'phone, IBAN and BIC can be proven');
    expect(
      report.suggested,
      1,
      reason: 'the company name is a habit, not a proof',
    );

    final findings = await listFindings(session: session);
    expect(findings.length, 4);
    for (final f in findings) {
      expect(f.reason, isNotEmpty, reason: 'every finding says why');
      expect(f.span.end, greaterThan(f.span.start));
    }

    // A BIC is a BIC, in the token as everywhere else.
    final tokens = await listTokens(session: session);
    expect(tokens.any((t) => t.token.contains('_BIC_')), isTrue);
    expect(tokens.any((t) => t.kind == Kind.bic), isTrue);

    // G12 from Dart: the open suggestion blocks the send, and says how many.
    final handle = await buildPayload(session: session);
    final view = await payloadView(handle: handle);
    expect(view.text, isNot(contains('COBADEFFXXX')));
    expect(
      view.text,
      contains('Nordstern'),
      reason: 'still open, so still in the clear',
    );

    try {
      await send(
        handle: handle,
        provider: const ProviderId(id: 'openai'),
      );
      fail('a send with an open suggestion must be refused');
    } on ApiError_OpenSuggestions catch (e) {
      expect(e.count, 1);
    }

    // Answer it, and the door opens as far as the provider.
    final open = findings.firstWhere((f) => f.state == MarkState.suggested);
    await answerFinding(
      session: session,
      finding: open.id,
      answer: FindingAnswer.protect,
    );
    final fresh = await buildPayload(session: session);
    try {
      await send(
        handle: fresh,
        provider: const ProviderId(id: 'openai'),
      );
      fail('nothing is connected, so nothing can be sent');
    } on ApiError_NetworkRefused catch (e) {
      expect(e.reason, isA<NetworkRefusal_NotConnected>());
      expect(e.detail, contains('openai'));
    }
    await closeSession(session: session);
  });

  test(
    'the UI learns that a provider is connected, and never the credential',
    () async {
      // M6 from the other side. There is no call anywhere in the contract that
      // returns a credential — this test is what that sentence looks like in code.
      final dir = Directory.systemTemp.createTempSync(
        'zprivacy-provider-contract-$pid-',
      );
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      await setDataDir(dir: dir.path);
      await vaultLock();

      final rows = await providers();
      expect(rows, isNotEmpty);
      final before = rows.firstWhere((r) => r.id == 'openai');
      expect(before.label, isNotEmpty);
      expect(before.baseUrl, startsWith('https://'));

      // Every field Dart can see about a provider, by name. If a credential is ever
      // added to this type, this list stops matching and someone has to explain why.
      expect(
        ProviderRow(
          id: before.id,
          label: before.label,
          connected: before.connected,
          sessionOnly: before.sessionOnly,
          baseUrl: before.baseUrl,
          model: before.model,
          credentialRequired: before.credentialRequired,
        ).toString(),
        isNotEmpty,
        reason:
            'ProviderRow has exactly seven fields, none of them a credential',
      );

      final connected = await connectProvider(
        provider: const ProviderId(id: 'openai'),
        credential: 'sk-test-not-a-real-credential',
        baseUrl: 'https://api.openai.com',
      );
      expect(connected.connected, isTrue);
      expect(
        connected.sessionOnly,
        isTrue,
        reason:
            'no vault is open in this test, so the UI must say it is temporary',
      );

      // A plain http address off this machine is refused as it is typed.
      try {
        await connectProvider(
          provider: const ProviderId(id: 'openai'),
          credential: 'sk-test',
          baseUrl: 'http://api.openai.com',
        );
        fail('a plain http provider address must be refused');
      } on ApiError_NetworkRefused catch (e) {
        expect(e.reason, isA<NetworkRefusal_InsecureUrl>());
      }

      final gone = await disconnectProvider(
        provider: const ProviderId(id: 'openai'),
      );
      expect(gone.connected, isFalse);
    },
  );
}

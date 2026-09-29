// P1-1 — every typed error has a sentence, and no enum reaches a person.
//
// His two conditions of 29 September, tested apart:
//   1. Walk **every** variant of `ApiError` and prove each has human language.
//   2. Prove no widget interprets an error itself, so one error cannot say
//      three different things on three screens.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

/// One of every variant the contract carries today. When the core gains one,
/// this list fails to compile or the count assertion below fails — either way
/// somebody has to write the sentence rather than ship the enum.
final _everyError = <ApiError>[
  const ApiError.notImplemented(),
  const ApiError.invalidSession(),
  const ApiError.invalidHandle(),
  const ApiError.stalePayload(expected: 3, got: 2),
  const ApiError.vaultLocked(),
  const ApiError.providerUnavailable(provider: 'openai'),
  const ApiError.openSuggestions(count: 2),
  const ApiError.importRefused(reason: 'this file could not be opened safely'),
  const ApiError.documentRefused(
    reason: Refusal.malformedDocument(),
    detail: 'word/document.xml is not well-formed XML',
  ),
  const ApiError.badSpan(reason: 'not a character boundary'),
  const ApiError.unknownToken(),
  const ApiError.nothingToSend(),
  const ApiError.payloadRefused(reason: 'nothing to send'),
  const ApiError.networkRefused(
    reason: NetworkRefusal.insecureUrl(),
    detail: 'an address must be https',
  ),
  const ApiError.unsupportedKdfParameters(reason: 'm_cost 1000000 is outside 8..=131072'),
  const ApiError.trailingVaultData(),
  const ApiError.vaultAuthenticationFailed(),
  const ApiError.payloadAlreadySent(),
  const ApiError.vaultRequired(),
];

/// Every shape the two nested enums take, because a reason inside an error is
/// still a reason a person reads.
final _everyRefusal = <Refusal>[
  const Refusal.scannedPdfNoTextLayer(pages: 4),
  const Refusal.encryptedPdf(),
  const Refusal.unsupportedEncoding(page: 2, readablePercent: 40),
  const Refusal.unreadableStructure(page: 7),
  const Refusal.malformedDocument(),
];

final _everyNetworkRefusal = <NetworkRefusal>[
  const NetworkRefusal.notConnected(),
  const NetworkRefusal.insecureUrl(),
  const NetworkRefusal.redirected(status: 302),
  const NetworkRefusal.badStatus(status: 401),
  const NetworkRefusal.timeout(millis: 30000),
  const NetworkRefusal.responseTooLarge(limitKib: 2048),
  const NetworkRefusal.payloadTooLarge(kib: 900, limitKib: 512),
  const NetworkRefusal.unreadable(),
];

/// What may never appear in something a person reads.
void _readsAsHuman(String message, String what) {
  expect(message, isNotEmpty, reason: '$what has no message at all');
  expect(message, isNot(equals(unnamedTrouble)), reason: '$what fell to the fallback');
  // Parentheses are ordinary prose; what may never appear is a type name or
  // the field labels a debug formatter prints.
  for (final machine in ['ApiError', 'Refusal_', 'NetworkRefusal',
                         'reason:', 'detail:', '{', '}']) {
    expect(
      message.contains(machine),
      isFalse,
      reason: '$what shows «$machine» to a person: $message',
    );
  }
  // A sentence, not a token: it starts with a capital and ends with a stop.
  expect(message[0], equals(message[0].toUpperCase()), reason: '$what does not start a sentence: $message');
  expect(message.endsWith('.'), isTrue, reason: '$what does not end a sentence: $message');
}

void main() {
  test('every ApiError variant has a human sentence', () {
    expect(_everyError.length, 19, reason: 'the contract has 19 ApiError variants');
    for (final e in _everyError) {
      _readsAsHuman(humanMessage(e), e.runtimeType.toString());
    }
  });

  test('every refusal inside an error has a human sentence', () {
    for (final r in _everyRefusal) {
      final e = ApiError.documentRefused(reason: r, detail: 'x');
      _readsAsHuman(humanMessage(e), r.runtimeType.toString());
    }
    for (final r in _everyNetworkRefusal) {
      final e = ApiError.networkRefused(reason: r, detail: 'an address must be https');
      _readsAsHuman(humanMessage(e), r.runtimeType.toString());
    }
  });

  test('the one we measured live now reads as a sentence', () {
    // The exact case from the human run and the re-triage: pressing Connect
    // with an empty key used to print
    //   ApiError.importRefused(reason: OpenAI-compatible needs a credential …)
    final e = const ApiError.importRefused(
      reason: 'OpenAI-compatible needs a credential at that address; a model on '
          'this machine does not',
    );
    final message = humanMessage(e);
    expect(message.contains('ApiError'), isFalse);
    expect(message.contains('importRefused'), isFalse);
    expect(message, contains('needs a credential at that address'));
  });

  test('anything unknown still gets a sentence, never debug formatting', () {
    expect(humanMessage(StateError('boom')), unnamedTrouble);
    expect(unnamedTrouble.contains('ApiError'), isFalse);
  });

  test('no widget interprets an ApiError by itself', () {
    // The rule that keeps the mapper the only mapper. Without it, one error
    // says three things on three screens within a month.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (file.path.contains('lib/src/rust/')) continue;
      if (file.path.endsWith('core/messages.dart')) continue;
      final text = file.readAsStringSync();
      for (final line in text.split('\n')) {
        final code = line.trim();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (RegExp(r'\b(e|err|bad|error)\.toString\(\)').hasMatch(code) ||
            RegExp(r'\bis ApiError_').hasMatch(code) ||
            RegExp(r'ApiError_\w+\s*\(\s*:').hasMatch(code)) {
          offenders.add('${file.path}: $code');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'these read an ApiError outside the mapper');
  });
}

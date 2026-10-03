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
  const ApiError.inputRefused(reason: 'a profile needs a name you will recognise'),
  const ApiError.notFound(reason: 'there is no rule set called «sv»'),
  const ApiError.vaultAbsent(),
  const ApiError.vaultAlreadyExists(),
  const ApiError.storageRefused(reason: 'the vault folder: a temporary file was left behind'),
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
    expect(_everyError.length, 23,
        reason: 'the contract has 23 ApiError variants');
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

  // What the owner saw on 3 October: a Swedish annual report whose page 5 is
  // four fifths readable, and a screen that said «Page 5 could not be read as
  // text.» He read that as «it thinks the page is an image». The core knew
  // more than the screen passed on — the share that decoded, and what to do
  // about it — and both belong in the sentence.
  test('a page that half decoded says how much, and what to do', () {
    const refusal = Refusal.unsupportedEncoding(page: 5, readablePercent: 79);
    final said = humanMessage(
      const ApiError.documentRefused(reason: refusal, detail: ''),
    );
    expect(said, contains('5'), reason: 'the page is in the sentence');
    expect(said, contains('79'), reason: 'the share that decoded is what the core measured');
    expect(
      said.toLowerCase(),
      anyOf(contains('save'), contains('paste')),
      reason: 'a refusal without a next move leaves the person with nothing to do',
    );
  });

  test('the one we measured live now reads as a sentence', () {
    // The exact case from the human run and the re-triage: pressing Connect
    // with an empty key used to print
    //   ApiError.importRefused(reason: OpenAI-compatible needs a credential …)
    //
    // And the word was wrong twice over: it was debug formatting, **and**
    // nothing was being imported. The core now calls this what it is.
    final e = const ApiError.inputRefused(
      reason: 'OpenAI-compatible needs a credential at that address; a model on '
          'this machine does not',
    );
    final message = humanMessage(e);
    expect(message.contains('ApiError'), isFalse);
    expect(message.contains('inputRefused'), isFalse);
    expect(message, contains('needs a credential at that address'));
  });

  test('the split gave each story its own next move', () {
    // One sentence for «change what you typed», «name something else» and
    // «there is no vault» was the name's own defect one layer up: a person
    // cannot act on a word that covers three different situations.
    final input = humanMessage(const ApiError.inputRefused(reason: 'a profile needs a name'));
    final missing = humanMessage(const ApiError.notFound(reason: 'that profile is not in this vault'));
    final absent = humanMessage(const ApiError.vaultAbsent());
    final already = humanMessage(const ApiError.vaultAlreadyExists());
    final storage = humanMessage(
        const ApiError.storageRefused(reason: 'the vault folder: a temporary file was left behind'));

    expect({input, missing, absent, already, storage}.length, 5,
        reason: 'two of the five stories are told with the same sentence');
    // The two that need no string say the whole fact themselves, so no reason
    // can be worded wrongly into them.
    expect(absent, contains('no vault on this device'));
    expect(already, contains('will not write over'));
    // And a location that cannot be used is not blamed on the person.
    expect(storage, startsWith('Z Privacy will not use that location'));
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

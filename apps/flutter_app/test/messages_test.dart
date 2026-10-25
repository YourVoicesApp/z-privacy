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

import 'a_path_in_one_spelling.dart';

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
  const ApiError.sessionWithoutItsDocument(reason: 'a document is open and this call did not name it'),
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
  const ApiError.betweenColumns(),
  const ApiError.vaultChangedElsewhere(),
  const ApiError.storagePermissionsKept(
    reason: 'vault.zv: the folder that holds it is set to 500',
  ),
];

/// Every shape the two nested enums take, because a reason inside an error is
/// still a reason a person reads.
///
/// **All twelve, and counted** (17 October, from two sides at once: e2's
/// reading of the attacker's B3-4 and this round's خ5). Five of them were
/// listed here and the other seven — every limit the reader has — were not, so
/// the screen could answer «This file could not be opened safely» to a bomb,
/// to a file one byte too big and to an empty one alike, and this guard was
/// green while it did. It is a sentence, it names no type and it ends with a
/// stop, so every check in `_readsAsHuman` passed over it. A list of examples
/// is only as good as its claim to be the whole list, so the count is part of
/// the test.
final _everyRefusal = <Refusal>[
  const Refusal.scannedPdfNoTextLayer(pages: 4),
  const Refusal.encryptedPdf(),
  const Refusal.unsupportedEncoding(page: 2, readablePercent: 40),
  const Refusal.unreadableStructure(page: 7),
  const Refusal.malformedDocument(),
  // 26 against 25, not 25 against 25: ن16 made the core round the figure
  // **up**, so a file it refuses can no longer measure exactly the limit.
  const Refusal.documentTooLarge(mib: 26, limitMib: 25),
  const Refusal.tooManyPages(pages: 2400, limit: 2000),
  const Refusal.textTooLarge(limitMib: 8),
  const Refusal.compressionBomb(ratio: 946),
  const Refusal.tooManyParts(parts: 521, limit: 512),
  const Refusal.tookTooLong(millis: 20000),
  const Refusal.emptyDocument(),
];

/// **All nine of the network's own** — ن15, the same lesson as the twelve
/// above: this list held eight, and the ninth (`unreachable`) was the one
/// falling through to a sentence that fitted them all.
final _everyNetworkRefusal = <NetworkRefusal>[
  const NetworkRefusal.notConnected(),
  const NetworkRefusal.insecureUrl(),
  const NetworkRefusal.redirected(status: 302),
  const NetworkRefusal.badStatus(status: 401),
  const NetworkRefusal.timeout(millis: 30000),
  const NetworkRefusal.responseTooLarge(limitKib: 2048),
  const NetworkRefusal.payloadTooLarge(kib: 900, limitKib: 512),
  const NetworkRefusal.unreadable(),
  const NetworkRefusal.unreachable(),
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
    expect(_everyError.length, 27,
        reason: 'the contract has 27 ApiError variants');
    for (final e in _everyError) {
      _readsAsHuman(humanMessage(e), e.runtimeType.toString());
    }
  });

  test('every refusal inside an error has a human sentence', () {
    expect(_everyRefusal.length, 12,
        reason: 'the contract has 12 Refusal variants');
    for (final r in _everyRefusal) {
      final e = ApiError.documentRefused(reason: r, detail: 'x');
      _readsAsHuman(humanMessage(e), r.runtimeType.toString());
    }
    expect(_everyNetworkRefusal.length, 9,
        reason: 'the contract has 9 NetworkRefusal variants');
    for (final r in _everyNetworkRefusal) {
      final e = ApiError.networkRefused(reason: r, detail: 'an address must be https');
      _readsAsHuman(humanMessage(e), r.runtimeType.toString());
    }
  });

  /// **050/A · the conflict's sentence does not blame the folder.**
  ///
  /// The first answer to the owner's two-copies attack refused with
  /// `StorageRefused`, which reads «Z Privacy will not use that location — the
  /// vault file changed on disk while this copy was open; lock and unlock
  /// before changing it». Three things wrong in one line: the location is
  /// fine, the cause is another window of this program, and «lock and unlock»
  /// was also being said to copies that were already locked.
  ///
  /// The locked half is fixed in the core and measured there
  /// (`a_locked_copy_over_a_changed_file_says_it_is_locked`). This is the half
  /// a person reads.
  test('a vault changed by another window does not blame the folder', () {
    final said = humanMessage(const ApiError.vaultChangedElsewhere());
    expect(said.toLowerCase(), isNot(contains('location')),
        reason: 'the place is fine, and saying otherwise sends them to look at it: $said');
    expect(said.toLowerCase(), contains('another copy'),
        reason: 'the cause is a second window of Z, and the sentence must name it: $said');
    expect(
      said.toLowerCase(),
      anyOf(contains('close'), contains('lock and unlock')),
      reason: 'a refusal without a next move leaves them holding a vault they cannot save: $said',
    );
    // And the control: the variant it was carved out of still means a place.
    final place = humanMessage(
      const ApiError.storageRefused(reason: 'the vault folder: a temporary file was left behind'),
    );
    expect(place.toLowerCase(), contains('location'),
        reason: 'StorageRefused went back to meaning a place that cannot be used: $place');
  });

  /// **058 · a locked folder is told the promise, not only the cause.**
  ///
  /// The lead's condition: *a sentence that names the cause and omits the
  /// promise has said the small half.* Z is not refusing the folder — it could
  /// write there, and is deferring to a decision — so «Z Privacy will not use
  /// that location» would be wrong for the second time in one morning, and
  /// this is the variant that exists to be able to say so.
  test('a folder the person locked hears that Z will not change it', () {
    final said = humanMessage(
      const ApiError.storagePermissionsKept(
        reason: 'vault.zv: the folder that holds it is set to 500',
      ),
    );
    expect(said.toLowerCase(), contains('will not change a permission'),
        reason: 'the promise is the half they cannot find out any other way: $said');
    expect(said.toLowerCase(), isNot(contains('will not use that location')),
        reason: 'the location is the one they chose, and it is usable: $said');
    expect(
      said.toLowerCase(),
      allOf(contains('change the permission yourself'), contains('another')),
      reason: 'both next moves are theirs to pick: $said',
    );
    // The control: the variant this was carved out of still means a place
    // found unsuitable, which is a different next move.
    final place = humanMessage(
      const ApiError.storageRefused(reason: 'the vault folder: a temporary file was left behind'),
    );
    expect(place.toLowerCase(), contains('location'));
    expect(place.toLowerCase(), isNot(contains('will not change a permission')));
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

  /// **B3-4 · a limit that is not said is a limit the person cannot act on.**
  ///
  /// The attacker pushed a 25 MiB + 1 file, a DOCX part of 8 MiB + 1 and a
  /// 946× bomb through the core: it named all three, and the screen said «This
  /// file could not be opened safely» to each. The number is the whole of the
  /// news — it is what tells a person whether to split the file, convert it,
  /// or walk away from it.
  test('a limit on the screen says the number it is', () {
    final said = <Refusal, String>{
      // 26 against 25 since ن16: the core rounds the figure up, so «25 MiB
      // against a 25 MiB limit» is a shape it can no longer produce.
      const Refusal.documentTooLarge(mib: 26, limitMib: 25): '25',
      const Refusal.tooManyPages(pages: 2400, limit: 2000): '2000',
      const Refusal.textTooLarge(limitMib: 8): '8',
      const Refusal.compressionBomb(ratio: 946): '946',
      const Refusal.tooManyParts(parts: 521, limit: 512): '512',
      const Refusal.tookTooLong(millis: 20000): '20',
    };
    said.forEach((refusal, number) {
      final message = humanMessage(
        ApiError.documentRefused(reason: refusal, detail: ''),
      );
      expect(message, contains(number),
          reason: '${refusal.runtimeType} does not say its limit: $message');
    });
  });

  /// And the bomb is not a scanned page. The core used to reach
  /// `ScannedPdfNoTextLayer` for a 946× page stream, and the screen turned that
  /// into «This PDF is a picture of a page with no text in it» — a false
  /// sentence about a true refusal.
  /// **ن15 · the two that were left** — the independent attacker's last note,
  /// 17 October. Both were the same defect as the limits above, one layer
  /// further in: a sentence that fits every case says nothing about the one
  /// that happened.
  test('a host that answered nothing says so, and a broken file says how', () {
    final unreachable = humanMessage(
      const ApiError.networkRefused(reason: NetworkRefusal.unreachable(), detail: ''),
    );
    _readsAsHuman(unreachable, 'NetworkRefusal_Unreachable');
    expect(unreachable, isNot(contains('did not work')),
        reason: 'the ninth network refusal still falls to the sentence that fits all nine');
    expect(unreachable, contains('nothing answered'),
        reason: 'the one fact this refusal carries — that nothing answered — is not said');

    // And the core's own detail reaches the glass, which is where the words a
    // person can act on were sitting all along.
    final broken = humanMessage(
      const ApiError.documentRefused(
        reason: Refusal.malformedDocument(),
        detail: 'this PDF lists no pages',
      ),
    );
    _readsAsHuman(broken, 'Refusal_MalformedDocument with a detail');
    expect(broken, contains('lists no pages'),
        reason: 'the core said what was wrong with the file and the screen dropped it');
    // With no detail the general sentence is still there, because a refusal
    // that carries nothing must not read as an empty line.
    final bare = humanMessage(
      const ApiError.documentRefused(reason: Refusal.malformedDocument(), detail: ''),
    );
    _readsAsHuman(bare, 'Refusal_MalformedDocument with no detail');
    expect(bare, contains('damaged or incomplete'));
  });

  test('a compression bomb is not described as a picture of a page', () {
    final said = humanMessage(
      const ApiError.documentRefused(
        reason: Refusal.compressionBomb(ratio: 946),
        detail: '',
      ),
    );
    expect(said.toLowerCase(), isNot(contains('picture')));
    expect(said.toLowerCase(), isNot(contains('scan')));
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
    //
    // **The names are compared in one spelling** — `oneSpelling`, and the
    // reason is in that file: on Windows this listing says
    // `lib\core\messages.dart`, both exemptions below missed, and the mapper
    // was reported as its own offender along with every generated file (the
    // Windows suite's red of 21 October, run 39548354872). The file itself is
    // still read through the entry the platform handed over.
    final offenders = <String>[];
    var sawTheMapper = false;
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final name = oneSpelling(file.path);
      if (!name.endsWith('.dart')) continue;
      if (name.contains('lib/src/rust/')) continue;
      if (name.endsWith('core/messages.dart')) {
        sawTheMapper = true;
        continue;
      }
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
    // **And the exemption bit.** A census that exempts a file it never reached
    // is a census of nothing, and both of these exemptions were exactly that on
    // Windows.
    expect(
      sawTheMapper,
      isTrue,
      reason: 'the walk never reached core/messages.dart, so its exemption proves nothing',
    );
    // The other platform's spelling, measured here, because this is the only
    // platform that runs this line on every round.
    expect(oneSpelling(r'lib\core\messages.dart').endsWith('core/messages.dart'), isTrue,
        reason: 'the mapper is exempt on Windows too, or it is its own offender there');
    expect(oneSpelling(r'lib\src\rust\api\mirrors.freezed.dart').contains('lib/src/rust/'), isTrue,
        reason: 'the generated files are out of this census on Windows too');
  });

  /// **One outcome, one sentence** — the fold of 15 October, and the table
  /// `protectSaid` is written against.
  ///
  /// Every sentence is spelled out here rather than asked of the product: a
  /// table that reads its expectation from the function it is testing is green
  /// whatever the function says, which is the shape this round has already
  /// paid for twice. Break an arm and exactly one line of this fails.
  test('every protect outcome has one sentence, and only a column is told about cells', () {
    const token = '__Z_17A9_CUSTOM_0F63__';
    const here = Span(start: 10, end: 19);
    // **116.** Every one of these sentences now draws its token through
    // `theMachinesOwnWord`, so the expected line carries the isolate too — and
    // carries it through the product's own function rather than as two code
    // points written here, so that this table follows the law instead of
    // restating it. `Lindqvist AB` is a name the vault was given, so it takes
    // the other isolate, which is G44's half of the same rule.
    final drawn = theMachinesOwnWord(token);
    final who = theirOwnWord('Lindqvist AB');
    final said = <(ProtectOutcome, ProtectAct), String>{
      // Applied — the one arm whose **shape** the press changes.
      (const ProtectOutcome.applied(token: token, places: 1), ProtectAct.aSelection):
          'Protected as $drawn.',
      (const ProtectOutcome.applied(token: token, places: 1), ProtectAct.aPlaceTheBarFound):
          'Protected as $drawn.',
      (const ProtectOutcome.applied(token: token, places: 1), ProtectAct.aCell):
          'Protected one cell, as $drawn.',
      (const ProtectOutcome.applied(token: token, places: 3), ProtectAct.aSelection):
          'Protected as $drawn, in 3 places.',
      (const ProtectOutcome.applied(token: token, places: 3), ProtectAct.aPlaceTheBarFound):
          'Protected as $drawn, in 3 places.',
      (const ProtectOutcome.applied(token: token, places: 3), ProtectAct.aCell):
          'Protected 3 cells down that column, the first as $drawn.',
      // A column that was already protected top to bottom. Only a column can
      // answer «0 places»: a selection and the bar's fold answer with the
      // outcome the core gave instead, which is why there is no row for them.
      (const ProtectOutcome.applied(token: token, places: 0), ProtectAct.aCell):
          'Every cell in that column was already protected.',
      // Already protected — **and by whom**, at every press. The bar left that
      // half out until today, and a person told «already protected» without
      // being told by what has to go and look.
      (
        const ProtectOutcome.alreadyProtected(token: token, source: Source.hand, sourceDetail: 'selected by you'),
        ProtectAct.aPlaceTheBarFound,
      ): 'Already protected as $drawn, by you.',
      (
        const ProtectOutcome.alreadyProtected(token: token, source: Source.vault, sourceDetail: 'Z Vault · CLIENT #17'),
        ProtectAct.aSelection,
      ): 'Already protected as $drawn, by vault.',
      // The vault's question, answered by the core after the act.
      (const ProtectOutcome.belongsToEntity(entity: 'Lindqvist AB', token: token), ProtectAct.aCell):
          'That belongs to $who and keeps its token $drawn.',
      // Snapped — one wording, and the press supplies the subject.
      (const ProtectOutcome.snapped(spans: [here]), ProtectAct.aSelection):
          'The selection cuts into protected text, so nothing changed. It would snap to 1 whole item.',
      (const ProtectOutcome.snapped(spans: [here]), ProtectAct.aCell):
          'That cell cuts into protected text, so nothing changed. It would snap to 1 whole item.',
      (const ProtectOutcome.snapped(spans: [here, here]), ProtectAct.aPlaceTheBarFound):
          'That place cuts into protected text, so nothing changed. It would snap to 2 whole items.',
      // 079 rule 5 — one state, one wording, whichever press reached it.
      (const ProtectOutcome.standsOnAToken(token: token), ProtectAct.aSelection):
          theTokenIsAlreadyOurs,
      (const ProtectOutcome.standsOnAToken(token: token), ProtectAct.aCell):
          theTokenIsAlreadyOurs,
      (const ProtectOutcome.standsOnAToken(token: token), ProtectAct.aPlaceTheBarFound):
          theTokenIsAlreadyOurs,
    };
    for (final row in said.entries) {
      expect(
        protectSaid(row.key.$1, row.key.$2),
        row.value,
        reason: 'the sentence for ${row.key.$1.runtimeType} at ${row.key.$2.name} has changed',
      );
    }

    // And **every** variant has a sentence at **every** press: a sixth variant
    // stops the build in `protectSaid` itself, and a press added to the enum
    // cannot reach an empty line.
    final everyOutcome = <ProtectOutcome>[
      const ProtectOutcome.applied(token: token, places: 2),
      const ProtectOutcome.alreadyProtected(token: token, source: Source.languagePack, sourceDetail: 'sv:name'),
      const ProtectOutcome.belongsToEntity(entity: 'Anna', token: token),
      const ProtectOutcome.snapped(spans: [here]),
      const ProtectOutcome.standsOnAToken(token: token),
    ];
    for (final outcome in everyOutcome) {
      for (final act in ProtectAct.values) {
        final line = protectSaid(outcome, act);
        expect(line, isNotEmpty);
        expect(line.endsWith('.'), isTrue, reason: 'not a sentence: $line');
        expect(line.contains('ProtectOutcome'), isFalse, reason: 'the enum reached a person: $line');
      }
    }
  });

  test('a source is named in one place, and it is the mapper', () {
    // `sourceName` moved out of `widgets/document_text.dart` the day the
    // outcome sentences were folded: a sentence that names who protected
    // something cannot be written in `core` while the words it needs live in a
    // widget. Four sources, four words, one file (G33's neighbour).
    expect(Source.values.map(sourceName).toList(), ['Rule', 'Pack', 'Vault', 'You']);
  });
}

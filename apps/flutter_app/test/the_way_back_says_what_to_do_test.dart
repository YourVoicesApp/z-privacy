// **«Read back» tells the person what to do** — the owner's own test of the
// installed `0ad706b`, 16 October 2026.
//
// He opened a protected PDF through «z-pdf» and met a dialog that named a
// reason and offered no act: «11 names stay as tokens: they were protected
// before Z Privacy began keeping every protected word.» He could not tell what
// to do about it. And the line itself did not read as English: his session is
// called «ألماني 1», and inside an English sentence the bidirectional
// algorithm pulled the digits and the quotes into the Arabic run, so the glass
// drew «This document came back from «11 .«ألماني names stay…».
//
// Three laws, measured here on the one function that writes the sentence
// (`whatCameBack` — the dialog draws it and counts nothing itself):
//
//   1. **A shut vault asks to be opened**, and never gives the other reason.
//      089 rule 4: a locked vault is a standing door, not a verdict about what
//      this machine holds.
//   2. **Every name the person chose is isolated**, so a sentence keeps its
//      order whatever language the name is in.
//   3. **Every reason ends with the act that answers it** — unlock it, protect
//      it again, or the plain truth that nothing here can bring it back.
//
// Pure Dart: the sentence is built from a reading, and a reading is a value.
// What the core puts in one is measured in Rust, on real files.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

/// The owner's own session name, which is where the order went wrong.
const _his = 'ألماني 1';

/// U+2068 FIRST STRONG ISOLATE … U+2069 POP DIRECTIONAL ISOLATE.
const _fsi = '⁨';
const _pdi = '⁩';

ReturnedDocument reading({
  required VaultState vault,
  int broughtBack = 0,
  List<ReturnedFrom> from = const [],
  int unresolved = 0,
  List<String> unknown = const [],
}) =>
    ReturnedDocument(
      restored: const [],
      tokens: broughtBack + unresolved,
      vault: vault,
      names: broughtBack + unresolved,
      broughtBack: broughtBack,
      unresolved: List.generate(unresolved, (i) => '__Z_f610_PERSON_000${i}__'),
      conversations: from,
      unknownNamespaces: unknown,
    );

ReturnedFrom his({required int broughtBack, required int unresolved}) =>
    ReturnedFrom(
      number: 1,
      name: _his,
      broughtBack: broughtBack,
      unresolved: unresolved,
      answerPage: false,
    );

void main() {
  group('a shut vault asks to be opened', () {
    test('locked, with a conversation named beside it', () {
      // The shape the owner met: something is known about where the document
      // came from, and nothing came back. The reason is the lock and nothing
      // else — «protected before Z began keeping them» is a statement about
      // the vault's contents, and a shut vault has not been asked.
      final said = whatCameBack(reading(
        vault: VaultState.locked,
        unresolved: 11,
        from: [his(broughtBack: 0, unresolved: 11)],
      ))!;
      expect(said, contains('unlock or create your vault'),
          reason: 'a locked vault did not ask to be unlocked');
      expect(said, isNot(contains('began keeping every protected word')),
          reason: 'a locked vault was told why its own blocks do not hold a name');
    });

    test('locked, with nothing named', () {
      final said = whatCameBack(
        reading(vault: VaultState.locked, unresolved: 11),
      )!;
      expect(said, contains('unlock or create your vault'));
      expect(said, isNot(contains('began keeping every protected word')));
    });

    test('absent — there is no vault to unlock, and the sentence allows for it', () {
      final said = whatCameBack(
        reading(vault: VaultState.absent, unresolved: 11),
      )!;
      expect(said, contains('unlock or create your vault'),
          reason: 'a person with no vault was told to unlock one');
      expect(said, isNot(contains('began keeping every protected word')));
    });
  });

  group('a name the person chose is isolated', () {
    test('the session name comes back wrapped, in both sentences that name it', () {
      final back = whatCameBack(reading(
        vault: VaultState.unlocked,
        broughtBack: 8,
        unresolved: 3,
        from: [his(broughtBack: 8, unresolved: 3)],
      ))!;
      expect(back, contains('«$_fsi$_his$_pdi»'),
          reason: 'the name came back from «$_his» without an isolate around it');
      // And the other clause, the one for a document that brought nothing back.
      final none = whatCameBack(reading(
        vault: VaultState.unlocked,
        unresolved: 11,
        from: [his(broughtBack: 0, unresolved: 11)],
      ))!;
      expect(none, contains('«$_fsi$_his$_pdi»'),
          reason: 'the «came back from» clause interpolates the name bare');
    });

    test('no sentence interpolates a name without its isolates', () {
      // The control: the raw name may appear **only** between the two
      // characters. A sentence that holds it bare anywhere is the defect.
      for (final said in <String>[
        whatCameBack(reading(
          vault: VaultState.unlocked,
          broughtBack: 8,
          unresolved: 3,
          from: [his(broughtBack: 8, unresolved: 3)],
        ))!,
        whatCameBack(reading(
          vault: VaultState.locked,
          unresolved: 11,
          from: [his(broughtBack: 0, unresolved: 11)],
        ))!,
      ]) {
        expect(said.replaceAll('$_fsi$_his$_pdi', ''), isNot(contains(_his)),
            reason: 'a name stands bare in «$said»');
      }
    });

    test('our own words are not isolated — the function is for theirs', () {
      final said = whatCameBack(
        reading(vault: VaultState.unlocked, unresolved: 11, unknown: const ['f610']),
      )!;
      expect(said, contains('(f610)'), reason: 'the namespace is ours and reads as itself');
      expect(said, isNot(contains('$_fsi(f610)')));
    });
  });

  group('every reason ends with the act that answers it', () {
    test('the lock — open it', () {
      final said = whatCameBack(
        reading(vault: VaultState.locked, unresolved: 11),
      )!;
      expect(said, contains('unlock or create your vault'));
    });

    test('no block — protect it again, and it comes back from then on', () {
      final said = whatCameBack(reading(
        vault: VaultState.unlocked,
        unresolved: 11,
        from: [his(broughtBack: 0, unresolved: 11)],
      ))!;
      expect(said, contains('began keeping every protected word'),
          reason: 'the reason itself is gone');
      expect(said, contains('protect the names again'),
          reason: 'the dialog named a reason and left the person with nowhere to go');
      // And in the singular, because one name is the commoner case.
      final one = whatCameBack(reading(
        vault: VaultState.unlocked,
        unresolved: 1,
        from: [his(broughtBack: 0, unresolved: 1)],
      ))!;
      expect(one, contains('protect the name again'));
      expect(one, isNot(contains('protect the names again')));
    });

    test('two causes, and the sentence states neither as the one that happened — م4', () {
      // **The independent attacker, 17 October.** He exported a session's text,
      // changed one hex digit in the tail of a token, and read the file back.
      // Nothing came back to the wrong owner — that held — but the dialog
      // explained it with a cause nobody had proved: «it was protected before
      // Z Privacy began keeping every protected word». A token edited after
      // the export has no block either, and this build cannot tell the two
      // apart from what it is given.
      //
      // So the law: **a sentence does not state a cause the core has not
      // proved.** It names both, and ends with the one act that tells them
      // apart by what happens next.
      final one = whatCameBack(reading(
        vault: VaultState.unlocked,
        unresolved: 1,
        from: [his(broughtBack: 0, unresolved: 1)],
      ))!;
      expect(one, contains('changed after the file left'),
          reason: 'only one of the two causes is named, and it is the one nobody proved');
      expect(one, contains('protect the name again'),
          reason: 'the act that answers it is gone');
      expect(one, contains('if it comes back'),
          reason: 'the person is given two causes and no way to tell which is theirs');

      final many = whatCameBack(reading(
        vault: VaultState.unlocked,
        unresolved: 11,
        from: [his(broughtBack: 0, unresolved: 11)],
      ))!;
      expect(many, contains('changed after the file left'));
      expect(many, contains('protect the names again'));
      expect(many, contains('if they come back'));
    });

    test('another machine’s key — plainly, that there is no way back', () {
      final said = whatCameBack(
        reading(vault: VaultState.unlocked, unresolved: 11, unknown: const ['f610']),
      )!;
      expect(said, contains('Nothing here can put them back'),
          reason: 'a name that cannot come back was left looking like a name that could');
      expect(said, contains('not in this vault'));
      // One name, one key: the two numbers in this sentence are different
      // numbers, and reading one off the other said «11 names … the key that
      // made it» on the owner's own file.
      final one = whatCameBack(
        reading(vault: VaultState.unlocked, unresolved: 1, unknown: const ['f610']),
      )!;
      expect(one, contains('Nothing here can put it back: the key that made it is'));
      final two = whatCameBack(
        reading(vault: VaultState.unlocked, unresolved: 4, unknown: const ['f610', 'a71c']),
      )!;
      expect(two, contains('the keys that made them are'));
    });

    test('an ordinary document gets no sentence at all', () {
      expect(whatCameBack(reading(vault: VaultState.unlocked)), isNull,
          reason: 'a letter with no token in it was given a line about tokens');
    });
  });
}

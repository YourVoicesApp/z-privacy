// **The sentences in one list** — 092, 18 October 2026, the owner: «نحتاج الآن
// أن نعقد قوائم الجمل قائمة باللغة الإنكليزية، ثم نقوم بنسخها إلى اللغات
// الأخرى، ثم نقوم بتفعيل الترجمة داخل التطبيق».
//
// Four guards, and each measures one of the three steps the owner named.
//
// **Why no `find.text('…')` in English anywhere here.** That reach is what the
// round exists to make impossible: a guard that looks for an English sentence
// on the glass passes only while the glass speaks English, and the paper makes
// it a gate failure by itself. Every reach below is by **key** — the sentence
// a key names, in the locale under test.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/l10n/app_localizations_de.dart';
import 'package:zprivacy/l10n/app_localizations_en.dart';
import 'package:zprivacy/l10n/app_localizations_sv.dart';

void main() {
  // ------------------------------------------------------------------ guard 1
  //
  // **Every key in the English list is in the other two** — the gate G50 asks
  // this of the files; this asks it of the generated classes, which is the
  // same question one layer down and the one that would actually break a
  // screen. A key missing from a copy is a sentence that falls back to
  // English at run time, silently.
  test('every sentence the English list names is in the German and the Swedish', () {
    final en = AppLocalizationsEn();
    final de = AppLocalizationsDe();
    final sv = AppLocalizationsSv();
    // The generated classes carry one getter or method per key, so «the same
    // keys» is «the same interface» — and Dart has no reflection here. What
    // can be measured without it is the thing that matters: the three classes
    // answer the same **named** sentences, read through the one list each.
    for (final sentence in <String>[
      en.theKeyIsBehindTheLockedVault,
      en.theChatKeepsNothing,
      en.unnamedTrouble,
      en.troubleVaultLocked,
      en.refusalEncryptedPdf,
      en.networkUnreachable,
    ]) {
      expect(sentence.trim(), isNotEmpty, reason: 'an English sentence is empty');
    }
    for (final sentence in <String>[
      de.theKeyIsBehindTheLockedVault,
      de.theChatKeepsNothing,
      de.unnamedTrouble,
      de.troubleVaultLocked,
      de.refusalEncryptedPdf,
      de.networkUnreachable,
    ]) {
      expect(sentence.trim(), isNotEmpty, reason: 'a German sentence is empty');
    }
    // **The Swedish is the English, and that is the state 56-أ holds.** Not an
    // oversight: the file exists so the gate can count it and so the day it is
    // translated is a change to values and not a change to the tree. The first
    // screen does not offer Svenska while this is true.
    expect(sv.theChatKeepsNothing, en.theChatKeepsNothing,
        reason: 'the Swedish values have started to differ from the English — '
            'then 56-أ is satisfied and the first screen may offer Svenska');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **The German is German** — the half of G50 that no count can measure: a
  // value copied from the English is a key that was never translated.
  test('the German list says something other than the English', () {
    final en = AppLocalizationsEn();
    final de = AppLocalizationsDe();
    expect(de.theKeyIsBehindTheLockedVault, isNot(en.theKeyIsBehindTheLockedVault));
    expect(de.troubleVaultLocked, isNot(en.troubleVaultLocked));
    expect(de.refusalEmptyDocument, isNot(en.refusalEmptyDocument));
    // And the house's own vocabulary, where the paper fixed it: a token is a
    // «Platzhalter» and never a «Token», a vault is a «Tresor».
    expect(de.belongsToEntity('Nordstern', '__Z_1234_PERSON_ABCD__'),
        contains('Platzhalter'),
        reason: 'the German calls a token something other than «Platzhalter»');
    expect(de.troubleVaultLocked, contains('Tresor'),
        reason: 'the German calls the vault something other than «Tresor»');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The switch itself**: the one holder the house reads, and what the core's
  // outcomes become in each locale. This is `messages.dart` under `de` —
  // forty-nine call sites in `session_state.dart` reach their sentences
  // exactly this way, with no context between them and the list.
  test('the core’s outcomes are worded in the language the application is in', () {
    // English first, because it is the source and the fallback.
    theSentencesAreNow(const Locale('en'));
    expect(unnamedTrouble, AppLocalizationsEn().unnamedTrouble);
    expect(humanMessage('not an ApiError'), AppLocalizationsEn().unnamedTrouble);

    // And then German, with nothing else changed.
    theSentencesAreNow(const Locale('de'));
    expect(unnamedTrouble, AppLocalizationsDe().unnamedTrouble,
        reason: 'the one holder did not reach the sentences the core’s outcomes use');
    expect(humanMessage('not an ApiError'), AppLocalizationsDe().unnamedTrouble);
    expect(theKeyIsBehindTheLockedVault,
        AppLocalizationsDe().theKeyIsBehindTheLockedVault);

    // An unknown code is English, not a refusal — the source list is the
    // honest answer for a language nobody has translated.
    expect(theLocaleOf('fr'), const Locale('en'));
    expect(theLocaleOf('de'), const Locale('de'));

    // Left as English, so no guard after this one meets a German glass it did
    // not ask for.
    theSentencesAreNow(const Locale('en'));
    expect(unnamedTrouble, AppLocalizationsEn().unnamedTrouble);
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **The letters the German needs are in the sentences, and they lay out** —
  // and the half of the paper's «measure one screen with each» that a widget
  // test cannot answer is said here rather than faked.
  //
  // `flutter test` draws with a test font in which **every glyph has the same
  // width**: measured while writing this guard, «aou s a» and «äöü ß å» both
  // came to 99.75 px. So a width comparison proves nothing about whether a
  // shipped font can draw an umlaut — it proves only that the harness is the
  // harness. What the glass does with those letters is a measurement on the
  // built application, on the owner's own screen, and it is reported as owed.
  //
  // What this does measure, and it is the thing that would actually break a
  // sentence: the letters survive the list — the ARB is read as UTF-8, the
  // generated Dart carries them, and a `Text` of them lays out with a size.
  testWidgets('the German letters are in the sentences, and they lay out', (tester) async {
    final de = AppLocalizationsDe();
    // «Öffnen» carries the capital, and «weiß» the sharp s — both in the one
    // sentence, which is why it is the one read for them.
    expect(de.troubleVaultLocked, contains('Ö'),
        reason: 'the German lost its capital umlaut between the file and the class');
    expect(de.troubleVaultLocked, contains('ß'),
        reason: 'the German lost its sharp s between the file and the class');
    // And the small umlauts, each read in a sentence that has one: «Passwort
    // … versuchen» carries ü, «Gewohnheiten … gewählt» carries ä.
    expect(de.refusalEncryptedPdf, contains('ü'),
        reason: 'the German lost its u-umlaut between the file and the class');
    expect(de.noLanguageAndNoSession, contains('ä'),
        reason: 'the German lost its a-umlaut between the file and the class');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            '${de.troubleVaultLocked} äöü ß å',
            key: const ValueKey<String>('letters'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byKey(const ValueKey<String>('letters')));
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));
    expect(tester.takeException(), isNull,
        reason: 'laying out the German letters threw');
  });
}

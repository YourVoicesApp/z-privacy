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
import 'package:zprivacy/core/a_date_in_words.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/l10n/app_localizations_de.dart';
import 'package:zprivacy/l10n/app_localizations_en.dart';
import 'package:zprivacy/l10n/app_localizations_sv.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';

void main() {
  // Guard 5 mounts a screen that asks the core, so the bridge is started —
  // the other four are about the list and need nothing native.
  setUpAll(() async => RustLib.init());

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
  // ------------------------------------------------------------------ guard 5
  //
  // **The three parts, on the glass, in German** — 092's second sitting, and
  // the one measurement that crosses every layer the round touched: the ARB,
  // the generated class, the holder, and a screen that reads it with no
  // `Localizations` above it.
  //
  // Every reach is by **key**, out of the German class, for the reason at the
  // head of this file: a guard that looked for «Geschützt — das erhält die KI»
  // as a string of its own would be a second German list beside the one the
  // round exists to make the only one.
  testWidgets('the three parts speak the language the application is in', (tester) async {
    // The size the one screen's own guard uses: tall enough for the three
    // parts to stand, which is what `shell_route_test` measured them at.
    await tester.binding.setSurfaceSize(const Size(1300, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();

    // **No bench**, which is rule 70's own first state: the three parts with
    // nothing in them yet, each saying the one thing it is for. It is also the
    // state that needs no document and no session, so this guard measures the
    // sentences and nothing else.
    final ground = Ground();
    await tester.runAsync(ground.refresh);

    // The one line that turns the application German. No delegates are mounted
    // below it and none are needed: the holder is what every sentence in the
    // house reads, which is the whole shape of `core/sentences.dart`.
    theSentencesAreNow(const Locale('de'));
    addTearDown(() => theSentencesAreNow(const Locale('en')));

    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScreen(
        bench: null,
        ground: ground,
        onImport: () {},
        onAsk: (_) {},
        onVault: () {},
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    }
    await tester.pumpAndSettle();

    // The three parts' own names, upper-cased by `Eyebrow` the way the glass
    // draws them.
    for (final name in <String>[de.originalLocalOnly, de.safeAiWillReceive, de.theChatTitle]) {
      expect(find.text(name.toUpperCase()), findsOneWidget,
          reason: 'a part of the one screen is not named in the language the app is in');
    }
    // And the English is gone from them — the half a «does it say the German»
    // guard cannot measure on its own, because a screen could say both.
    expect(find.text(en.originalLocalOnly.toUpperCase()), findsNothing);
    expect(find.text(en.safeAiWillReceive.toUpperCase()), findsNothing);

    // One sentence from each part, so that the parts' bodies are measured and
    // not only their heads: the way in, the empty middle column, and the chat's
    // own first line.
    expect(find.text(de.yourDocumentArrivesHere), findsOneWidget);
    expect(find.text(de.whatAnAiWouldReceiveStandsHere), findsOneWidget);
    expect(find.text(de.theChatOpensHereWithTheFirstAnswer), findsOneWidget);
    // And rule 72's box is in the first part from the first moment, with its
    // hint in the same language.
    expect(find.text(de.askAQuestionOrPasteALetter), findsOneWidget);

    // The house's vocabulary where the round fixed it: «Sprachpaket», never
    // «Pack». Asked of the list rather than of this screen, because the field
    // it labels is on the work bar and an empty surface has no document for
    // the bar to be about.
    expect(de.packLabel, 'Sprachpaket');
    expect(de.vaultLabel, 'Tresor');
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **A language can be a scanner language and not yet an interface language**
  // — rule 56-أ, and the hole this closes was live on an installed build: the
  // Language room offered «Svenska», the press wrote `ui_language = 'sv'`
  // because one choice writes both values (080), `theLocaleOf` accepted it
  // because `sv` is in `supportedLocales`, and the app drew `app_sv.arb` —
  // which is the English copy. A person chose Swedish and read English, and
  // nothing anywhere said so.
  //
  // One law, three readers, and this measures the law and two of the readers:
  // `theListIsWrittenIn` is the question, `theLocaleOf` is the fallback, and
  // the first screen's offer is guarded in `vault_screen_test`.
  test('a language whose list is still the English source does not carry the interface', () {
    // German is written: its promise differs from the source's in every line.
    expect(theListIsWrittenIn('de'), isTrue,
        reason: 'the German list reads as untranslated, so the app would draw English');
    // English is the source and is written by definition — nothing is compared
    // with itself.
    expect(theListIsWrittenIn('en'), isTrue);
    // Swedish is not, and that is 56-أ's stated state rather than an oversight.
    expect(theListIsWrittenIn('sv'), isFalse,
        reason: 'the Swedish values have started to differ — then 56-أ is '
            'satisfied, Svenska carries the interface, and this guard changes');
    // A code nobody has a file for at all.
    expect(theListIsWrittenIn('fr'), isFalse);

    // **And the fallback.** The locale the root applies is a language the glass
    // can speak, never the one it merely has a file for.
    expect(theLocaleOf('de'), const Locale('de'));
    expect(theLocaleOf('sv'), const Locale('en'),
        reason: 'the root would draw a Swedish list that is written in English');
    expect(theLocaleOf('fr'), const Locale('en'));

    // The holder, asked the same question the root asks it: a code whose list
    // is not written reaches the English sentences and not an empty screen.
    theSentencesAreNow(theLocaleOf('sv'));
    addTearDown(() => theSentencesAreNow(const Locale('en')));
    expect(sentences.noAccount, AppLocalizationsEn().noAccount);

    // And the sentence the Language room draws for such a language exists in
    // every list, naming the language it is about.
    expect(AppLocalizationsDe().theInterfaceIsEnglishUntilTranslated('Svenska'),
        contains('Svenska'));
    expect(AppLocalizationsDe().theInterfaceIsEnglishUntilTranslated('Svenska'),
        isNot(AppLocalizationsEn().theInterfaceIsEnglishUntilTranslated('Svenska')));
  });

  // ------------------------------------------------------------------ guard 7
  //
  // **A date reads in the words of the language the glass is in** — 092's
  // fourth sitting, and the guard that would have caught the fault the vault
  // board's own test found: `DateFormat('d MMM y', 'de')` **throws**
  // `LocaleDataException` until `intl`'s locale data has been loaded, and the
  // load now happens inside `theDayItWas` on the first date any screen draws.
  //
  // Two hand-written `const months` lists stood where this function is, one in
  // `vault.dart` and one in `why_sheet.dart` — twenty-four English
  // abbreviations between them, and the lead's ruling was to ask `intl` with
  // the locale rather than key twelve words.
  test('a date reads in the words of the language the glass is in', () {
    // A fixed instant, so the guard says the same thing in every month:
    // 9 October 2025, 00:00 UTC.
    const when = 1759968000;

    theSentencesAreNow(const Locale('de'));
    addTearDown(() => theSentencesAreNow(const Locale('en')));
    final german = theDayItWas(when);
    expect(german, contains('Okt'),
        reason: 'the German date does not carry a German month — $german');

    theSentencesAreNow(const Locale('en'));
    final english = theDayItWas(when);
    expect(english, contains('Oct'),
        reason: 'the English date does not carry an English month — $english');

    // **The order is the house's own**, which is why the English line reads as
    // it always did: the day first, then the month, then the year.
    expect(english.startsWith('9 '), isTrue, reason: english);

    // A zero is not a date, and says so in the language of the glass.
    expect(theDayItWas(0), AppLocalizationsEn().taughtOnUnknown);
    theSentencesAreNow(const Locale('de'));
    expect(theDayItWas(0), AppLocalizationsDe().taughtOnUnknown);
    expect(AppLocalizationsDe().taughtOnUnknown,
        isNot(AppLocalizationsEn().taughtOnUnknown));
  });

}

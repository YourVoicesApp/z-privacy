// **The sentences, in the language the application is in** — 092, 18 October
// 2026, the owner: «نحتاج الآن أن نعقد قوائم الجمل قائمة باللغة الإنكليزية، ثم
// نقوم بنسخها إلى اللغات الأخرى، ثم نقوم بتفعيل الترجمة داخل التطبيق».
//
// The list itself is `lib/l10n/app_en.arb` and its copies, and Flutter's own
// `gen-l10n` turns them into `AppLocalizations`. This file is the one thing
// that tooling does not answer: **how a sentence is reached**.
//
// ## Why not `AppLocalizations.of(context)` everywhere
//
// Because the two places that word the most sentences have no context, and a
// context cannot be invented:
//
//   * `core/session_state.dart` is a `ChangeNotifier` with forty-nine of them
//     — every refusal the core hands back becomes a sentence there, in a class
//     that is deliberately not a widget;
//   * `core/messages.dart` is a set of pure functions the core's outcomes pass
//     through, and «one place turns the core's numbers into language» is the
//     rule it exists for.
//
// So the list is **looked up by locale**, not by widget tree, and held here:
// one holder, set by the one widget that decides the locale (the app root),
// before anything below it builds. `lookupAppLocalizations` is the generated
// function that does it, so the lookup is the tooling's and not ours.
//
// ## What this costs, said out loud
//
// A widget that reads `sentences` does not depend on the `Localizations`
// inherited widget, so it is not rebuilt *by* a locale change. It does not have
// to be: the locale comes from `settings.zcfg` through `Ground`, and the root
// that reads it rebuilds the whole application when it changes — the holder is
// set in that same build, before the subtree. A locale that changed without
// rebuilding the root would leave stale sentences, and there is no such path:
// `MaterialApp.locale` is the root's own state.
//
// ## And why English is the fallback
//
// The list is English at its source, so a reader that runs before any root has
// set a locale — a widget test that mounts one screen, a unit test of a
// sentence — words English and keeps saying what it always said. Sixty test
// files depend on that, and so does the rule that the English file is the
// source rather than a translation of something else.
import 'package:flutter/widgets.dart' show Locale;

import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/l10n/app_localizations_en.dart';

AppLocalizations _sentences = AppLocalizationsEn();

/// The sentences the glass is showing now.
AppLocalizations get sentences => _sentences;

/// **Said once, by the root, as the locale is applied.** Not a setter on a
/// class: there is one application, one locale at a time, and the name says
/// what the act is rather than what it stores.
void theSentencesAreNow(Locale locale) =>
    _sentences = lookupAppLocalizations(locale);

/// **And one more reader asks a locale directly, for a different reason** —
/// the lead, 19 October 2026, for the sentences `protected_pdf.dart` writes.
///
/// What the z-pdf footer puts **into a file** is in that session's language
/// (rule 33), not the interface's: the file travels, the interface does not,
/// and a person who reads German documents in an English interface must not
/// receive a PDF whose footer is English. So those sentences are read with
/// `lookupAppLocalizations(Locale(sessionLanguage))` and **never through the
/// holder above**, which is «what the glass is showing now».
///
/// The rule, stated once for whoever migrates the next file: **the holder is
/// for the interface.** Wherever a sentence belongs to something other than
/// the interface — a file that leaves, a page that is choosing the language
/// itself — the locale is asked for directly. Migrating such a file through
/// the holder by habit would write German words into an English session's
/// document, and nothing on any screen would say so.
///
/// **Built on 21 October 2026, when the owner ruled it** — rule 80,
/// `docs/RULES_AR.md`: the z-pdf footer, the «protected copy» mark and the
/// added page's title are in the language of the session the file left, and
/// English where that session has none.
///
/// `null` is «this file left no session, or a session nobody asked» — the
/// third state 075c is careful about, and English is the answer to it because
/// English is the list's own source. A code whose list is **not written yet**
/// is English too, by [theLocaleOf] and not by a second rule: Swedish is a
/// scanner pack and not an interface, so a file from a Swedish session carries
/// the source's words rather than a column of English values pretending to be
/// Swedish. One law, read in two places.
AppLocalizations theSentencesAFileCarries(String? sessionLanguage) =>
    lookupAppLocalizations(theLocaleOf(sessionLanguage ?? 'en'));

/// **Is this language's list written, or is it still the source's?** — rule
/// 56-أ, 19 October 2026, as one question with three readers.
///
/// A language can be two different things in this product and the two do not
/// arrive together: a **scanner** language, which is a pack of rules in the
/// core, and an **interface** language, which is a column of values in
/// `lib/l10n`. Swedish is the first and not yet the second — `app_sv.arb` is a
/// copy of the English, and 56-أ says so out loud: the file exists so the gate
/// can count it, and the values differ on the day somebody writes them.
///
/// The three readers, and why the law cannot live in any one of them:
///
///   * the **first screen** offers a language only if the promise it would
///     draw is in that language — four «no» lines under a Swedish name, in
///     English, is the fault P2-6 fixed there once already;
///   * **[theLocaleOf]** answers English for such a code, so the root draws a
///     language it can actually speak;
///   * the **Language room** draws one line saying which of the two this
///     language is, rather than switching the interface silently.
///
/// Written here because the first screen had it inline and the other two then
/// had to agree with it by hand — one law in three languages, and the quietest
/// copy wins the day they disagree.
///
/// **What it measures**: the first screen's own promise — the four «no» lines,
/// the two paragraphs and the rule line. Not an arbitrary sample: a language
/// that cannot say *what this product does not do* cannot carry the interface
/// of a privacy product, whatever else is translated in it. The day a language
/// is half-written this answers «no» until the promise is done, which is the
/// side to be wrong on.
bool theListIsWrittenIn(String code) {
  // The source list is written by definition; nothing is compared with itself.
  if (code == 'en') return true;
  // **A code with no list at all answers «no», and does not throw.** It did:
  // `lookupAppLocalizations` raises `FlutterError` for an unsupported locale,
  // and this function is a question anybody in the house may ask about any
  // code. No product caller asks about one today — both of them walk
  // `offeredLanguages` — so the throw would have waited for the next reader.
  // The guard asked about «fr» and found it before that reader existed.
  if (!AppLocalizations.supportedLocales.any((l) => l.languageCode == code)) {
    return false;
  }
  final t = lookupAppLocalizations(Locale(code));
  final en = AppLocalizationsEn();
  return t.noAccount != en.noAccount ||
      t.noAds != en.noAds ||
      t.noAnalytics != en.noAnalytics ||
      t.noZPrivacyServer != en.noZPrivacyServer ||
      t.originalDataStaysHere != en.originalDataStaysHere ||
      t.onlyTheProtectedVersionIsSent != en.onlyTheProtectedVersionIsSent ||
      t.theseRulesWillBeEnabled != en.theseRulesWillBeEnabled;
}

/// The locale a language code names, for the one place that applies it.
///
/// The code is the core's — `settings.zcfg`'s `ui_language`, which reaches the
/// glass as `Settings.language`. An unknown code is English, for the same
/// reason English is the fallback above: it is the source list, and a code
/// nobody translated is better read than refused.
///
/// **And a code whose list is not written yet is English too** — 19 October,
/// and it is a fallback rather than a refusal on purpose. The setting keeps
/// what the person chose: they picked Svenska, the scanner reads Swedish, and
/// `ui_language` says `sv` because that is true. What the glass can speak is a
/// different fact, and it belongs to the list's state rather than to their
/// choice — so this answers with the language the sentences exist in, and the
/// Language room says both out loud. Storing English instead would make the
/// room lie about a choice the person actually made.
Locale theLocaleOf(String code) =>
    theListIsWrittenIn(code) ? Locale(code) : const Locale('en');

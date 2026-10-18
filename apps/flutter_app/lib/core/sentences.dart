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

/// The locale a language code names, for the one place that applies it.
///
/// The code is the core's — `settings.zcfg`'s `ui_language`, which reaches the
/// glass as `Settings.language`. An unknown code is English, for the same
/// reason English is the fallback above: it is the source list, and a code
/// nobody translated is better read than refused.
Locale theLocaleOf(String code) =>
    AppLocalizations.supportedLocales.any((l) => l.languageCode == code)
        ? Locale(code)
        : const Locale('en');

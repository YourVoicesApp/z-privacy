// First run — one page, once.
//
// Not an onboarding of ten screens. Four lines of what this program does not do,
// two lines of what it does, a language, and away. No e-mail, no account, no
// permission it does not need.
//
// It is written in both languages because the choice on it is a language choice:
// a page that asked «Deutsch oder English?» in English only would be asking the
// question in the answer.
//
// That was written here as a comment while the code did the opposite — the state
// began at `en`, so a fresh install read the promise in English and the German
// text existed only for someone who had already found the button. P2-6: nothing
// is assumed. Before a choice **both** promises stand on the page, neither
// button is on, and there is no Start yet.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/language_list.dart' show offeredLanguages;

/// What the product does not do, and what it does — in one place per language.
///
/// The two paragraphs carry a correction of the owner's, 30 September: «your
/// original data stays on this device» must not be read as «it can never
/// leave», because `Copy Restored` exists and puts real values on the clipboard
/// when a person asks for them. The sentence names that exception itself rather
/// than being quietly wrong about it.
class _Promise {
  const _Promise({
    required this.name,
    required this.nots,
    required this.paragraphs,
    required this.rules,
    required this.start,
  });

  /// The language's own name for itself.
  final String name;
  final List<String> nots;
  final List<String> paragraphs;

  /// What choosing this language actually does — said before Start, because a
  /// person picking «Deutsch» must not have to discover afterwards that only
  /// the rules changed.
  final List<String> rules;
  final String start;
}

/// **One promise, read out of the language it is about** — 092.
///
/// There were two of these, written by hand: `_de` in German and `_en` in
/// English, the same six claims in two places. The list carries them now, so
/// the panel for a language is the panel **of** that language — every sentence
/// from `lookupAppLocalizations(Locale(code))`, which is the generated lookup
/// and not a second table of ours. A language added to `offeredLanguages`
/// brings its own panel with it and nothing here changes.
///
/// **One sentence is gone rather than translated**: «Die übrige
/// Benutzeroberfläche ist derzeit auf Englisch» — the rest of the interface is
/// in English for now. 092 is what made it false, and a false sentence on the
/// first screen of the product is worse than a missing one. It is deleted and
/// not reworded, because what it warned about no longer exists.
_Promise _promiseOf(String code) {
  final t = lookupAppLocalizations(Locale(code));
  return _Promise(
    name: t.thisLanguageName,
    nots: [t.noAccount, t.noAds, t.noAnalytics, t.noZPrivacyServer],
    paragraphs: [t.originalDataStaysHere, t.onlyTheProtectedVersionIsSent],
    rules: [t.theseRulesWillBeEnabled],
    start: t.start,
  );
}

/// **The languages this page can be read in** — rule 56-أ, as arithmetic
/// rather than as a second list beside `offeredLanguages`.
///
/// Swedish is offered everywhere else a language is chosen (rule 56), and its
/// file is still a copy of the English: 56-أ says the file exists so the gate
/// can count it, and the values differ the day somebody translates them. A
/// button marked «Svenska» on **this** page would hand a person four English
/// promises under a Swedish name — which is the fault P2-6 fixed here once
/// already, in the other direction.
///
/// So the page asks the list instead of holding an opinion: a language belongs
/// on it when the promise it would draw is **in** that language. For the source
/// language that is true by definition; for any other it is true the day its
/// values stop being the English ones, and nothing here changes on that day.
List<String> _languagesThisPageSpeaks() {
  final source = _promiseOf('en');
  bool readable(String code) {
    if (code == 'en') return true;
    final p = _promiseOf(code);
    return p.nots.join('\u0000') != source.nots.join('\u0000') ||
        p.paragraphs.join('\u0000') != source.paragraphs.join('\u0000') ||
        p.rules.join('\u0000') != source.rules.join('\u0000');
  }

  return offeredLanguages.where(readable).toList();
}

class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key, required this.ground, required this.onStart});

  final Ground ground;
  /// `wantsVault` is always true since 041-N — the vault is the way in, not an
  /// offer — and the parameter stays so the shell's door keeps one shape.
  final void Function(String language, {required bool wantsVault}) onStart;

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  /// Null until a person chooses. **Not** a default — this page has no right to
  /// one, because the question it asks is which language they read.
  String? _language;

  /// The second step: the vault, before any work.
  ///
  /// The owner's sentence in 041-E was «the vault should be opened before
  /// starting work so we can save the words», and this page offered it with a
  /// «Later» beside it. 041-N, after a live run: «you cannot begin without an
  /// open vault». So the offer became the way in. There is no «Later» here any
  /// more — not because a person must be pushed, but because everything Z
  /// learns while they work is kept in the vault, and work done without one is
  /// work thrown away at the end of the day.
  bool _atTheVault = false;

  @override
  Widget build(BuildContext context) {
    // The languages on offer here, and the panel of the one that was chosen —
    // each built from that language's own list (092).
    //
    // **This page reads by locale and not through `sentences`.** The holder is
    // set from `Settings.language`, and on a first run there is no setting yet:
    // the language is being chosen on this very page and is written to the core
    // only by `onStart`. So every sentence below is read out of the list the
    // button names, which is also why both panels can stand on the page at
    // once — two languages, one glass, which no single holder can do.
    final languages = _languagesThisPageSpeaks();
    final chosen = _language == null ? null : _promiseOf(_language!);
    final t = _language == null ? null : lookupAppLocalizations(Locale(_language!));
    return Scaffold(
      body: Stack(
        children: [
          Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // **The picture, large, where a person looks first** —
                    // 072, the owner on 9 October: «أريد أن تظهر صورة الشعار في
                    // شاشات التطبيق». The lettered tile that stood here was
                    // drawn in Dart; this is his own picture, from the one
                    // asset `scripts/build_brand.py` generates.
                    const BrandMark(size: 64),
                    const SizedBox(width: 13),
                    Text('Z Privacy', style: Zc.h1.copyWith(fontSize: 28)),
                  ],
                ),
                const SizedBox(height: 30),

                // Before a choice: both, each under its own name so nobody has
                // to work out which language they are reading. After a choice:
                // theirs alone.
                if (chosen == null)
                  for (final code in languages)
                    _Block(_promiseOf(code), named: true)
                else
                  _Block(chosen, named: false),

                const SizedBox(height: 8),
                // **The word for «language» in every language on offer** while
                // the answer is unknown, each out of its own list and joined
                // here — so it was «Sprache · Language» and still is, and a
                // third language would say its own word without this line
                // being touched.
                Eyebrow(chosen == null
                    ? languages
                        .map((c) => lookupAppLocalizations(Locale(c)).languageWord)
                        .join(' · ')
                    : t!.languageWord),
                const SizedBox(height: 9),
                Row(
                  children: [
                    for (final code in languages)
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: _Lang(
                          // A language's own name for itself: «Deutsch» is
                          // what German calls German, in every language.
                          label: lookupAppLocalizations(Locale(code)).thisLanguageName,
                          on: _language == code,
                          onTap: () => setState(() => _language = code),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (chosen == null)
                  // Why there is no Start yet, in both languages — a control
                  // that is absent has to be accounted for, like a disabled one.
                  Text(
                    // One line per language on offer, each in its own: a page
                    // that asked in one language would be asking the question
                    // in the answer.
                    languages
                        .map((c) => lookupAppLocalizations(Locale(c)).chooseALanguage)
                        .join('\n'),
                    style: Zc.small,
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: Zc.panel(fill: Zc.clayWash, edge: Zc.clayEdge, radius: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in chosen.rules)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              line,
                              style: Zc.small.copyWith(
                                color: Zc.clayDeep,
                                fontWeight: line == chosen.rules.first ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!_atTheVault)
                    ZButton(
                      label: chosen.start,
                      filled: true,
                      onPressed: () => setState(() => _atTheVault = true),
                    )
                  else ...[
                    Eyebrow(t!.yourVault),
                    const SizedBox(height: 8),
                    // What the vault is for, said before it is offered. The
                    // reason this sentence reaches as far as it does is kept
                    // with the sentence, at `@vaultWhy` in the list.
                    Text(t.vaultWhy, style: Zc.small),
                    const SizedBox(height: 14),
                    ZButton(
                      label: t.createAVault,
                      filled: true,
                      onPressed: () => widget.onStart(_language!, wantsVault: true),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.onePassphrase,
                      style: Zc.tiny.copyWith(letterSpacing: 0),
                    ),
                  ],
                ],
                const SizedBox(height: 34),
                // The byline, in the chosen language while there is one —
                // «von YourVoices» — and in the source list's words before,
                // where the page is speaking every language at once and this
                // line cannot be in all of them.
                Text(
                    (t ?? lookupAppLocalizations(const Locale('en'))).byYourVoices,
                    style: Zc.tiny.copyWith(letterSpacing: 0.4)),
              ],
            ),
          ),
        ),
          ),
          // **The sentence that used to stand here, and what replaced it.**
          // It read: «The mark itself, once, in the corner of the first page a
          // person ever sees — and nowhere else in the app. A product that
          // shows its badge on every screen is a product talking about itself;
          // this one has work to do.» The owner ruled otherwise on 9 October —
          // he wants his picture in the app's screens — so the mark moved into
          // this page's own head, where a person looks first, and the heads of
          // the chat, the panel and the work bar wear it at their own sizes.
          // One picture per screen, never two: the reason the old sentence gave
          // still holds against a badge in every corner.
        ],
      ),
    );
  }
}

/// One language's promise: the four lines, then the two sentences.
class _Block extends StatelessWidget {
  const _Block(this.promise, {required this.named});

  final _Promise promise;

  /// Headed by the language's name — only while both are on the page.
  final bool named;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: named ? 24 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (named) ...[
              Eyebrow(promise.name),
              const SizedBox(height: 8),
            ],
            for (final line in promise.nots)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Zc.ink,
                  ),
                ),
              ),
            const SizedBox(height: 11),
            for (final paragraph in promise.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(paragraph, style: Zc.body.copyWith(fontSize: 15, height: 1.6)),
              ),
          ],
        ),
      );
}

class _Lang extends StatelessWidget {
  const _Lang({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: on ? Zc.clayWash : Zc.card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: on ? Zc.clayEdge : Zc.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? Zc.clayDeep : Zc.ink2,
              ),
            ),
          ),
        ),
      );
}

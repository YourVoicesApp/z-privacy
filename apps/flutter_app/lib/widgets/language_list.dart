// The language list, in the two places a person meets it: the top bar of an
// open document, and the step between choosing a file and reading it.
//
// The owner, 6 October: «we make a list of languages, and a line separates the
// supported languages from the unsupported ones». So the list has two halves:
// above the line what this build carries rules for, with the one in use
// marked; below it every other language.
//
// 041-Q, the same evening, after he could not choose Arabic on a build whose
// vault already held an Arabic list: «the language list holds every language;
// we have no problem with the language rules — we will not include them all».
// So **both halves can be chosen**. Below the line a language runs the general
// rules, the person's own list for it, and nothing else — and the row says so
// rather than promising something that is coming.
//
// **Neither half is written here.** Both come from the core's own table of
// languages, so the day a language gets rules it moves across the line by one
// row changing, and no screen is left saying otherwise.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

/// **The languages offered on the glass** — 080 («نبدأ بلغتين»), and **rule
/// 56** since 16 October 2026: Swedish beside German and English, after the
/// owner worked in it.
///
/// The word «offered» is exact: the Arabic pack is in the core, untouched and
/// measured, and nothing is deleted — it stays unoffered until the owner says
/// so (rule 56's own second half). What this list decides is what a person is
/// **shown** when they choose the language of a session: in the room where a
/// session is created, in Settings where the application's own language is
/// set, in the head of an open document, which writes the open session's
/// language through the same core door, and at the birth of a session that
/// a document brings with it (rule 57b).
///
/// One list, every reader, because a second copy of «de, en, sv» is a second
/// chance to disagree the day a fourth pack is offered — and the day Arabic is,
/// one row changes here and nothing else.
const offeredLanguages = <String>['de', 'en', 'sv'];

/// The sheet after a file was chosen is **gone** — 080. It asked «which
/// language is this document?», which the owner replaced with two sources and
/// no third: a session's language is chosen when the session is created, or it
/// is the application's. A question at the file door was the third, and a class
/// nobody calls is a surface that still has to be read by whoever comes next.

/// The list itself: the languages with rules, a line, and all the rest.
class LanguageChoices extends StatelessWidget {
  const LanguageChoices({
    super.key,
    required this.ground,
    required this.chosen,
    required this.onChoose,
    this.plannedChoosable = true,
  });

  final Ground ground;
  final String? chosen;
  final void Function(String id) onChoose;

  /// Kept so the two callers read the same, and true since 041-Q: a language
  /// without rules is still a language a person may work in.
  final bool plannedChoosable;

  /// The line, so a test can find it by what it is rather than by looking for
  /// a one-pixel box among many.
  static const divider = ValueKey<String>('languages-supported-line');

  /// The scroller, likewise: seventy-odd languages do not fit a dialog.
  static const scroller = ValueKey<String>('languages-scroller');

  @override
  Widget build(BuildContext context) {
    final withRules = ground.languages.where((l) => l.hasRules).toList();
    final rest = ground.languages.where((l) => !l.hasRules).toList();

    return ConstrainedBox(
      // Tall enough to read, short enough to leave the buttons on screen.
      constraints: const BoxConstraints(maxHeight: 330),
      child: Scrollbar(
        child: ListView(
          key: scroller,
          shrinkWrap: true,
          primary: true,
          children: [
            for (final language in withRules) _Choice(language: language, chosen: chosen, onChoose: onChoose),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(key: divider, height: 1, color: Zc.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                child: Text(sentences.generalRulesOnlyNoDictionary, style: Zc.tiny),
              ),
              for (final language in rest)
                _Choice(language: language, chosen: chosen, onChoose: plannedChoosable ? onChoose : null),
            ],
          ],
        ),
      ),
    );
  }
}

/// One language, and whether it is the one in use.
class _Choice extends StatelessWidget {
  const _Choice({required this.language, required this.chosen, required this.onChoose});

  final LanguageRow language;
  final String? chosen;
  final void Function(String id)? onChoose;

  @override
  Widget build(BuildContext context) {
    final picked = language.id == chosen;
    final press = onChoose;
    return InkWell(
      onTap: press == null ? null : () => press(language.id),
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Icon(
              picked ? Icons.check : Icons.check_box_outline_blank,
              size: 16,
              color: picked ? Zc.river : Colors.transparent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                language.label,
                style: Zc.body.copyWith(color: language.hasRules || press != null ? Zc.ink : Zc.ink4),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              language.id.toUpperCase(),
              style: Zc.tiny.copyWith(color: Zc.ink4),
            ),
          ],
        ),
      ),
    );
  }
}

/// **The one question a new session asks** — rule 57, the owner on 16 October
/// 2026: «لم يسألني عن لغة الجلسة».
///
/// Rule 34 says opening a file asks nothing, and it still does — **except for
/// the one case rule 57b names**: the file is the first thing to enter a brand
/// new session, so there is no session language yet and the scanner needs one
/// *before* it reads. Asked here, once in a session's life; rule 57c is that
/// nothing in it asks again.
///
/// **Nothing is pre-marked.** The application's own language used to be ticked
/// and taken silently if the person pressed on — which is how the owner made a
/// session in a language he was never asked about. A question whose answer is
/// already filled in is not a question.
///
/// `null` is the answer «not this», and it is not a failure: no language, no
/// reading, no session, nothing kept. The caller returns and the glass is as
/// it was.
class TheLanguageOfANewSession extends StatelessWidget {
  const TheLanguageOfANewSession({super.key, required this.ground});

  final Ground ground;

  /// For the guard, and for the shell: one key per offered language.
  static ValueKey<String> keyFor(String id) => ValueKey<String>('new-session-language-$id');

  /// **A getter and no longer a `const`** — 092. Two readers reach this by
  /// name (the shell, and the guard that presses it), so the name stays and
  /// only where the words come from changes.
  static String get title => sentences.whichLanguageIsThisText;

  @override
  Widget build(BuildContext context) {
    final offered = ground.packs.where((p) => offeredLanguages.contains(p.id)).toList();
    return AlertDialog(
      backgroundColor: Zc.paper,
      title: Text(title, style: Zc.h2),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sentences.theSessionLanguageExplained, style: Zc.small),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in offered)
                  ZButton(
                    key: keyFor(p.id),
                    label: p.label,
                    onPressed: () => Navigator.of(context).pop(p.id),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        ZButton(label: sentences.notNow, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

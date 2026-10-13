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
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

/// **The languages offered on the glass** — 080, the owner: «نبدأ بلغتين».
///
/// Two, for now, and the word «offered» is exact: the Swedish and Arabic packs
/// are in the core, untouched and measured, and nothing is deleted. What this
/// list decides is what a person is **shown** when they choose the language of
/// a session — in the room where a session is created, in Settings where the
/// application's own language is set, and in the head of an open document,
/// which writes the open session's language through the same core door.
///
/// One list, three readers, because three copies of «de, en» are three chances
/// to disagree the day a third pack is offered.
const offeredLanguages = <String>['de', 'en'];

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
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 8, 6, 4),
                child: Text('General rules only — no dictionary yet', style: Zc.tiny),
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

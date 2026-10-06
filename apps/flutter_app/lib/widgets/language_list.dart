// The language list, in the two places a person meets it: the top bar of an
// open document, and the step between choosing a file and reading it.
//
// The owner, 6 October: «we make a list of languages, and a line separates the
// supported languages from the unsupported ones». So the list has two halves:
// above the line what this build actually carries, from `packs()`, with the one
// in use marked; below it what is coming, greyed, unchoosable, each with the
// word «coming» beside it.
//
// **Neither half is written here.** Both come from the core — the installed
// ones from the rule sets, the planned ones from a list that lives beside the
// packs themselves — so the day a language ships it moves across the line by
// being written once, and no screen is left promising something that arrived or
// was dropped.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/bits.dart';

/// The sheet shown after a file is chosen and before it is read.
///
/// One button, because there is one question: which rules read this document.
/// It is temporary and says so in the code rather than on screen — 043 gives
/// the pack a vote of its own, and this step goes when it lands.
class ChooseLanguage extends StatefulWidget {
  const ChooseLanguage({super.key, required this.ground, required this.fileName});

  final Ground ground;

  /// What the person picked, so the sheet can name it. Shown, never read.
  final String fileName;

  @override
  State<ChooseLanguage> createState() => _ChooseLanguageState();
}

class _ChooseLanguageState extends State<ChooseLanguage> {
  String? _packId;

  @override
  void initState() {
    super.initState();
    // What they chose last time, which is what the settings hold.
    _packId = widget.ground.config?.packId ??
        (widget.ground.packs.isNotEmpty ? widget.ground.packs.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Which language is this document?', style: Zc.h2),
              const SizedBox(height: 4),
              Text(
                widget.fileName,
                style: Zc.small.copyWith(color: Zc.ink3),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              LanguageChoices(
                ground: widget.ground,
                chosen: _packId,
                onChoose: (id) => setState(() => _packId = id),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ZButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  ZButton(
                    label: 'Open',
                    filled: true,
                    onPressed: _packId == null
                        ? null
                        : () => Navigator.of(context).pop(_packId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list itself: the packs this build carries, a line, and what is coming.
class LanguageChoices extends StatelessWidget {
  const LanguageChoices({
    super.key,
    required this.ground,
    required this.chosen,
    required this.onChoose,
  });

  final Ground ground;
  final String? chosen;
  final void Function(String id) onChoose;

  /// The line, so a test can find it by what it is rather than by looking for
  /// a one-pixel box among many.
  static const divider = ValueKey<String>('languages-supported-line');

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final pack in ground.packs)
          InkWell(
            onTap: () => onChoose(pack.id),
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    pack.id == chosen ? Icons.check : Icons.check_box_outline_blank,
                    size: 16,
                    color: pack.id == chosen ? Zc.river : Colors.transparent,
                  ),
                  const SizedBox(width: 8),
                  Text(pack.label, style: Zc.body),
                ],
              ),
            ),
          ),
        if (ground.plannedPacks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(key: divider, height: 1, color: Zc.line),
          const SizedBox(height: 8),
          for (final planned in ground.plannedPacks)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Text(planned.label, style: Zc.body.copyWith(color: Zc.ink4)),
                  const SizedBox(width: 10),
                  Text('coming', style: Zc.tiny.copyWith(color: Zc.ink4)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

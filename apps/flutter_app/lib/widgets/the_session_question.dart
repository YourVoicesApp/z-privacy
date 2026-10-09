// The session question — one wording, wherever it is asked.
//
// The owner's rule is that a session is born of the act that needs it and the
// name is asked **once**. On 9 October he put the question in two places: the
// chat screen, when a person has no session, and the screen after the filter.
// Two surfaces asking one question cannot mean two answers, so what a person
// types is a **wish** kept on the ground — not a session, which only an exit
// may begin — and every surface reads and writes that one wish.
//
// What differs between the surfaces is a single sentence: which act begins it.
// The chat's "Ask the AI" opens the review; the review's own doors are where
// the text leaves. So `closing` is a parameter and everything else is not.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';

class TheSessionQuestion extends StatefulWidget {
  const TheSessionQuestion({
    super.key,
    required this.ground,
    required this.closing,
    this.fieldKey,
    this.focusNode,
  });

  final Ground ground;

  /// The one sentence that differs: what will begin the session, from here.
  final String closing;

  /// A surface that already had a key on this field keeps it, so the guards
  /// written against that surface go on measuring the same thing.
  final Key? fieldKey;

  /// A press that could not proceed brings the person back to this field, so
  /// the surface that owns that press owns the node.
  final FocusNode? focusNode;

  /// Found by what they are, never by the words on them.
  static const band = ValueKey<String>('the-session-question');
  static const field = ValueKey<String>('the-session-question-field');

  @override
  State<TheSessionQuestion> createState() => _TheSessionQuestionState();
}

class _TheSessionQuestionState extends State<TheSessionQuestion> {
  late final TextEditingController _name =
      TextEditingController(text: widget.ground.sessionNameWished);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: TheSessionQuestion.band,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: Zc.panel(fill: Zc.warmCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This conversation has no session yet', style: Zc.h2),
          const SizedBox(height: 6),
          const Text(
            'A session has its own key. The same name in two sessions takes two '
            'different tokens, and inside one session it takes the same token '
            'wherever it appears — that is how you choose what an AI can line up '
            'and what it cannot.',
            style: Zc.small,
          ),
          const SizedBox(height: 10),
          TextField(
            key: widget.fieldKey ?? TheSessionQuestion.field,
            controller: _name,
            focusNode: widget.focusNode,
            style: Zc.body.copyWith(color: Zc.ink),
            // **Written to the ground on every keystroke**, because the other
            // surface may be the one that reads it: a person who names their
            // work here and presses on finds their own word in the sheet, and
            // an empty field there would be this product asking twice.
            onChanged: widget.ground.wishSessionName,
            decoration: InputDecoration(
              filled: true,
              fillColor: Zc.card,
              isDense: true,
              // **The room's hint, word for word.** One question, however many
              // places it is asked in.
              hintText: 'What is this one about?',
              hintStyle: Zc.body.copyWith(color: Zc.ink4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Zc.line),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.closing, style: Zc.small),
        ],
      ),
    );
  }
}

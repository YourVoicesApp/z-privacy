// The journey of a send — what left, what came back, what was kept.
//
// The owner's ruling, 9 October: the press takes the person to the chat screen,
// and there, in order: what was sent appears — the request in its safe clothing
// — then the answer appears when it returns, and then the answer is **pulled
// inside**: unwrapped, shown restored, and written into the session.
//
// Three moments of one request, drawn as three, because a person watching a
// slow model has the right to know which of them they are waiting in. The stage
// is the bench's and is published as each one happens; nothing here decides
// where a request has got to.
//
// **And the restored text is the written turn's.** `Workbench.turn` is read
// back from the session's own file after the write, restored **inside the
// core**, with `unresolved` naming every token it could not resolve. So the
// third step cannot appear before the thing it is about exists, and the text in
// it is the text that was kept — the check and the act read one object. A raw
// turn drawn here would put `__Z_5CDD_IBAN_5B32__` in the middle of a model's
// sentence, which is the exact lie the restore path exists to prevent.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

class TheJourney extends StatelessWidget {
  const TheJourney({super.key, required this.bench, required this.ground});

  final Workbench bench;
  final Ground ground;

  static const band = ValueKey<String>('the-journey');
  static const sent = ValueKey<String>('the-journey-sent');
  static const answered = ValueKey<String>('the-journey-answered');
  static const pulledIn = ValueKey<String>('the-journey-pulled-in');

  @override
  Widget build(BuildContext context) {
    final stage = bench.stage;
    if (stage == SendStage.none) return const SizedBox.shrink();
    final left = bench.sentAsItLeft;
    return Container(
      key: band,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: Zc.panel(fill: Zc.card, edge: Zc.line, radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1 · What was sent. Named as what it is: the text that travelled,
          // with the tokens in it, because that is the whole promise and a
          // person should be able to read what they sent after they sent it.
          _step(
            key: TheJourney.sent,
            on: true,
            title: bench.sendOriginal
                ? 'Sent — the document as it stands, because you chose that'
                : 'Sent — your request in its safe clothing',
            child: left == null || left.isEmpty
                ? Text('Nothing was built to send.', style: Zc.small.copyWith(color: Zc.ink4))
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: Zc.panel(fill: Zc.paper, radius: 8),
                    child: Text(left, style: Zc.document.copyWith(fontSize: 13)),
                  ),
          ),
          const SizedBox(height: 10),
          // 2 · The answer, when it comes back. Drawn as waiting until it does,
          // so the gap between the two is a state and not a blank screen.
          _step(
            key: TheJourney.answered,
            on: stage != SendStage.sent,
            title: switch (stage) {
              SendStage.sent => 'Waiting for the answer…',
              SendStage.refused => 'The request did not go through',
              _ => 'The answer came back',
            },
            child: stage == SendStage.refused
                ? Text(
                    bench.trouble ?? 'It did not go through, and nothing was kept.',
                    style: Zc.small.copyWith(color: Zc.amber),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          // 3 · Pulled inside: unwrapped, shown restored, and written into the
          // session. The three are one step because they are one act — and the
          // text below is the written turn's own, restored by the core.
          _step(
            key: TheJourney.pulledIn,
            on: stage == SendStage.pulledIn,
            title: switch (stage) {
              SendStage.pulledIn => 'Pulled in — restored here, and kept in this session',
              SendStage.keptNowhere => 'Not kept — no session is open to keep it',
              _ => 'Not pulled in yet',
            },
            child: stage == SendStage.pulledIn
                ? _theTurn(bench.turn!)
                : stage == SendStage.keptNowhere
                    ? Text(
                        'The answer is above and the real values are restored on this screen. '
                        'Nothing of this conversation is written anywhere: a session is what '
                        'keeps one, and none is open.',
                        style: Zc.small.copyWith(color: Zc.ink3),
                      )
                    : null,
          ),
        ],
      ),
    );
  }

  /// One step: a mark, a sentence, and whatever the step has to show.
  Widget _step({required Key key, required bool on, required String title, Widget? child}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              on ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              size: 15,
              color: on ? Zc.ready : Zc.ink4,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Zc.small.copyWith(
                  color: on ? Zc.ink : Zc.ink3,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        if (child != null) ...[
          const SizedBox(height: 7),
          Padding(padding: const EdgeInsets.only(left: 23), child: child),
        ],
      ],
    );
  }

  /// The written turn, as the core restored it.
  ///
  /// The colour follows the `Piece` the core put on each segment — there is no
  /// text search for `__Z_` anywhere on this screen, and no decision here about
  /// what was a token. `unresolved` is said as a number, not hidden: a name
  /// this session cannot resolve is a fact about the answer.
  Widget _theTurn(TurnRow turn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: Zc.panel(fill: Zc.paper, radius: 8),
          child: Text.rich(
            TextSpan(
              children: [
                for (final s in turn.answer)
                  TextSpan(
                    text: s.text,
                    style: switch (s.piece) {
                      Piece.restored => Zc.document.copyWith(
                        fontSize: 13,
                        color: Zc.clayDeep,
                        fontWeight: FontWeight.w600,
                      ),
                      Piece.unresolved => Zc.document.copyWith(fontSize: 13, color: Zc.amber),
                      _ => Zc.document.copyWith(fontSize: 13),
                    },
                  ),
              ],
            ),
          ),
        ),
        if (turn.unresolved.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            turn.unresolved.length == 1
                ? 'One name in this answer belongs to another session and could not be restored.'
                : '${turn.unresolved.length} names in this answer belong to another session and '
                      'could not be restored.',
            style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.amber),
          ),
        ],
      ],
    );
  }
}

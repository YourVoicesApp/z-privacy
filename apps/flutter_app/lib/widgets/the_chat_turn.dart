// **One exchange of the chat, drawn** — rules 65 and 66, moved out of
// `the_chat.dart` unchanged by paper 123: what went, what came back, coded,
// and the one press that puts the names back. It needs nothing of the core —
// a turn arrives as [ChatTurnShown] — so the app's chat and the web trial's
// chat draw their turns with this one widget and there is no second chat.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/the_clipboard.dart';
import 'package:zprivacy/widgets/plain_bits.dart';

/// What a piece of a restored answer is: the model's own words, a value put
/// back here, or a token nothing could place — the core's three, by name.
enum ChatPiece { words, restored, unresolved }

/// One turn, as the chat draws it: the question as it left (empty for an
/// answer brought back on a copy of the whole chat), who answered, the answer
/// as it arrived, and the answer restored, in the core's own pieces.
class ChatTurnShown {
  const ChatTurnShown({
    required this.questionAsItLeft,
    required this.who,
    required this.answerAsWritten,
    required this.answer,
    this.unresolved = const [],
  });

  final String questionAsItLeft;
  final String who;
  final String answerAsWritten;
  final List<(String text, ChatPiece piece)> answer;
  final List<String> unresolved;
}

/// One exchange: what went, what came back, and the one press that puts the
/// names back.
class ChatTurnView extends StatelessWidget {
  const ChatTurnView({
    super.key,
    required this.turn,
    required this.at,
    required this.open,
    required this.onShow,
    required this.onSaid,
    required this.coded,
  });

  final ChatTurnShown turn;

  /// How a coded side is painted: the app's Safe-column painter on the
  /// desktop, the trial's own token text on the web (the desktop's painter
  /// reads the core's page edges, which the web has no bridge for).
  final Widget Function(String text) coded;
  final int at;
  final bool open;
  final VoidCallback onShow;
  final void Function(String?) onSaid;

  /// One key per turn, so a press lands on the answer it was drawn under
  /// rather than on whichever bubble happens to be first.
  static Key showTheText(int at) => Key('the-chat-show-$at');
  static Key bubble(int at) => Key('the-chat-bubble-$at');

  /// The strip that says an answer carries tokens this session cannot place —
  /// 046/U, kept from the answer panel because the law is the same law.
  static const unresolved = ValueKey<String>('the-chat-unresolved');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **A turn without a question is a real turn** — and the only one
        // there is: an answer brought back on a copy of the whole chat. Its
        // payload *is* the chat, so storing that as the question would put the
        // conversation inside itself and send every word of it twice as
        // history. The core writes no question for it, and this draws no «you»
        // line — an empty box above an answer would be the app claiming the
        // person asked nothing when they asked everything.
        if (turn.questionAsItLeft.isNotEmpty) ...[
          _Side(
            who: sentences.theChatYou,
            text: turn.questionAsItLeft,
            tint: Zc.ink3,
            coded: coded,
          ),
          const SizedBox(height: 8),
        ],
        _Side(
          who: turn.who,
          text: turn.answerAsWritten,
          tint: Zc.river,
          coded: coded,
        ),
        const SizedBox(height: 6),
        // **One button per answer, and the default is coded** — rule 66.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ZButton(
            key: ChatTurnView.showTheText(at),
            label: open ? sentences.hideTheText : sentences.showTheText,
            icon: open
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            onPressed: onShow,
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          _Bubble(turn: turn, at: at, onSaid: onSaid),
        ],
      ],
    );
  }
}

/// One side of one exchange, coded. The painter is the Safe column's own, so a
/// token is drawn the same way wherever a person meets it.
class _Side extends StatelessWidget {
  const _Side({
    required this.who,
    required this.text,
    required this.tint,
    required this.coded,
  });

  final String who;
  final String text;
  final Color tint;
  final Widget Function(String text) coded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              who,
              style: Zc.tiny.copyWith(color: tint, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text(
              sentences.theChatCoded,
              style: Zc.tiny.copyWith(color: Zc.ink4),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: Zc.panel(fill: Zc.paper, radius: 9),
          // Characters, not chips: this is what the model read, and a chip per
          // token would put `U+FFFC` where a word should be.
          child: coded(text),
        ),
      ],
    );
  }
}

/// **The restored answer, in a bubble** — rule 66.
///
/// The segments are the core's, the fourth mark is the one the answer panel
/// drew, the «unresolved» strip is 046/U's, and «Copy Restored» keeps 081's
/// order: the clipboard is emptied before the question is asked, so a person
/// who cancels is left with an empty clipboard rather than with whatever they
/// had copied before.
class _Bubble extends StatefulWidget {
  const _Bubble({required this.turn, required this.at, required this.onSaid});

  final ChatTurnShown turn;
  final int at;
  final void Function(String?) onSaid;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  @override
  Widget build(BuildContext context) {
    final turn = widget.turn;
    final unknown = turn.unresolved;
    return Container(
      key: ChatTurnView.bubble(widget.at),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: Zc.panel(fill: Zc.clayWash, edge: Zc.clayEdge, radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sentences.theTextWithYourNamesBack,
            style: Zc.tiny.copyWith(
              color: Zc.clayDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (unknown.isNotEmpty) ...[
            Container(
              key: ChatTurnView.unresolved,
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
              decoration: Zc.panel(
                fill: Zc.amberWash,
                edge: Zc.amberEdge,
                radius: 9,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unknown.length == 1
                        ? sentences.thisAnswerCarriesOneUnknownToken
                        : sentences.thisAnswerCarriesUnknownTokens(
                            unknown.length,
                          ),
                    style: Zc.small.copyWith(
                      color: Zc.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    unknown.join('\n'),
                    style: Zc.tiny.copyWith(
                      letterSpacing: 0,
                      fontFamily: Zc.mono,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          SelectableText.rich(
            TextSpan(
              children: [
                for (final (text, piece) in turn.answer)
                  TextSpan(
                    text: text,
                    style: switch (piece) {
                      // The fourth mark: dotted for a value that was put back
                      // here, locally — the only place a word can carry it,
                      // because it is the only place a value comes back.
                      ChatPiece.restored => const TextStyle(
                        backgroundColor: Zc.clayWash,
                        color: Zc.clayDeep,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: Zc.clayDeep,
                        decorationThickness: 1.5,
                      ),
                      // A token nothing could place is not drawn as the
                      // answer: amber, struck through, because it is the one
                      // thing in the text that is not what the sentence
                      // appears to say.
                      ChatPiece.unresolved => const TextStyle(
                        backgroundColor: Zc.amberWash,
                        color: Zc.amber,
                        fontFamily: Zc.mono,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Zc.amberEdge,
                        decorationThickness: 1.5,
                      ),
                      ChatPiece.words => null,
                    },
                  ),
              ],
            ),
            style: Zc.document,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ZButton(
                label: sentences.copyRestored,
                icon: Icons.copy_outlined,
                onPressed: () => unawaited(
                  _copyRestored(turn.answer.map((s) => s.$1).join()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            unknown.isEmpty
                ? sentences.theMarkedWordsWerePutBackHere
                : sentences.theDottedWordsWerePutBackHere,
            style: Zc.tiny.copyWith(letterSpacing: 0),
          ),
        ],
      ),
    );
  }

  /// 081, and the order is the answer panel's own: the clipboard is emptied
  /// **before** the question, so a cancel leaves it empty rather than leaving
  /// whatever was on it before.
  Future<void> _copyRestored(String text) async {
    await emptyTheClipboardFirst();
    if (!mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Zc.paper,
        title: Text(sentences.copyRestoredTextQuestion, style: Zc.h2),
        content: Text(sentences.thisWillPlaceTheRealValues, style: Zc.body),
        actions: [
          ZButton(
            label: sentences.cancel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ZButton(
            label: sentences.copyRestored,
            filled: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    widget.onSaid(sentences.restoredTextCopied);
  }
}

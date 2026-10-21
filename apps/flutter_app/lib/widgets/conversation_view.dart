// 075b — a session's own conversation, opened by pressing its name.
//
// **The owner, 10 Oct 2026:** «الجلسة تحفظ الملفات التي ذهبت والإجابات… الضغط
// على اسم الجلسة» — the session keeps what went and what came back, and
// pressing its name must bring that screen up. Until today the Sessions list
// *selected* a session and left the person standing where they were, which the
// lead named exactly: selection without showing is half an answer.
//
// **Nothing here decides what a token was.** The colour of each piece follows
// the `Piece` the core put on it, and the text is restored **inside** the core
// before it crosses — `the_journey.dart` carries the same rule and the same
// reason: a raw turn on a screen puts `__Z_5CDD_IBAN_5B32__` in the middle of a
// model's sentence, which is the lie the restore path exists to prevent.
//
// **What it cannot say, and does not pretend to.** A session's file holds a
// *fingerprint* of the document it was about, not its name (`vault/model.rs`),
// so this screen says what was asked and what came back and is silent about
// which file it was — rather than reading the name off the bench that happens
// to be open now, which would be right in the only session anybody tests and
// wrong in every other. The lead has ruled the name will be kept; when the row
// carries one, it belongs in the head below.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

/// What a session kept, drawn. Given its turns rather than fetching them, so
/// the drawing can be measured without a vault, a key or a model.
class ConversationView extends StatelessWidget {
  const ConversationView({
    super.key,
    required this.row,
    required this.turns,
    this.trouble,
  });

  final ConversationRow row;
  final List<TurnRow> turns;

  /// Said on the screen rather than swallowed: a conversation that could not be
  /// read is not a conversation that is empty.
  final String? trouble;

  /// Found by what it is, never by the words on it.
  static const screen = ValueKey<String>('the-conversation');

  /// The press that opens one, wherever a session's name is drawn.
  static const door = ValueKey<String>('open-this-conversation');

  String get _when {
    final at = DateTime.fromMillisecondsSinceEpoch(row.beganAt.toInt() * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: screen,
      backgroundColor: Zc.paper,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${row.number}',
                    style: Zc.small.copyWith(
                      fontFamily: Zc.mono,
                      color: Zc.ink4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.name,
                      overflow: TextOverflow.ellipsis,
                      style: Zc.h2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$_when · ${row.turns == 1 ? '1 exchange' : '${row.turns} exchanges'}',
                style: Zc.tiny.copyWith(color: Zc.ink4, letterSpacing: 0),
              ),
              const SizedBox(height: 14),
              Flexible(child: _body()),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  ZButton(
                    label: sentences.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (trouble != null) return Trouble(trouble!);
    if (turns.isEmpty) {
      // **Three states, not two.** «Nothing was sent yet» is not «the file is
      // empty» and neither is «it could not be read»; a screen that spelt them
      // the same would report a lost conversation as a quiet one.
      return Text(
        sentences.nothingSentFromThisSessionYet,
        style: Zc.small.copyWith(color: Zc.ink3),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final turn in turns) _turn(turn),
        ],
      ),
    );
  }

  Widget _turn(TurnRow turn) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(sentences.youAsked),
          const SizedBox(height: 4),
          // An empty question is a real state and 046/N's whole finding: a
          // document may be sent with nothing asked of it.
          turn.question.isEmpty
              ? Text(
                  sentences.nothingWasAskedDocumentWentAlone,
                  style: Zc.small.copyWith(color: Zc.ink4),
                )
              : _pieces(turn.question),
          const SizedBox(height: 10),
          Eyebrow(sentences.itAnswered),
          const SizedBox(height: 4),
          _pieces(turn.answer, boxed: true),
          if (turn.unresolved.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              sentences.namesBelongToAnotherSession(
                  turn.unresolved.length, turn.unresolved.join(', ')),
              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.amber),
            ),
          ],
        ],
      ),
    );
  }

  /// The pieces as the core marked them. No text search for `__Z_` anywhere.
  Widget _pieces(List<Segment> segments, {bool boxed = false}) {
    final text = Text.rich(
      TextSpan(
        children: [
          for (final s in segments)
            TextSpan(
              text: s.text,
              style: switch (s.piece) {
                Piece.restored => Zc.document.copyWith(
                  fontSize: 13,
                  color: Zc.clayDeep,
                  fontWeight: FontWeight.w600,
                ),
                Piece.unresolved => Zc.document.copyWith(
                  fontSize: 13,
                  color: Zc.amber,
                ),
                _ => Zc.document.copyWith(fontSize: 13),
              },
            ),
        ],
      ),
    );
    if (!boxed) return text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: Zc.panel(fill: Zc.card, radius: 8),
      child: text,
    );
  }
}

/// Open one. The only loader, so every door reads the same way.
///
/// The turns are restored inside the core and come back already done; a failure
/// to read them is shown as itself rather than drawn as an empty conversation.
Future<void> showConversation(
  BuildContext context,
  ConversationRow row, {
  SessionId? bench,
}) async {
  List<TurnRow> turns = const [];
  String? trouble;
  try {
    // The bench, where the caller has one: the core names this session's
    // tokens from its own key, and a reader with no document in front of it
    // still gets the turns — with more of them unresolved, which the screen
    // says in words rather than leaving as a gap.
    turns = await z.conversationTurns(number: row.number, bench: bench);
  } on ApiError catch (e) {
    trouble = humanMessage(e);
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => ConversationView(row: row, turns: turns, trouble: trouble),
  );
}

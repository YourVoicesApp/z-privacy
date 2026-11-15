// Small pieces used on more than one screen. Nothing here holds state.

import 'package:flutter/material.dart';

import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/widgets/conversation_view.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/document_text.dart' show kindName;

export 'package:zprivacy/widgets/plain_bits.dart';

/// The mark. A plain square with a Z — the boards' one piece of identity.
/// The owner's own picture: a lighthouse in a ring, on a night.
///
/// One asset, generated with every other size from `brand/source.png` by
/// `scripts/build_brand.py` — no screen chooses a file by name but this one,
/// and no icon in this repository is edited by hand.
///
/// Distinct from [ZMark], which is the lettered tile the shell and the
/// workspace already wear. This is the badge, and it appears once: in the
/// corner of the first page a person ever sees.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/brand/zprivacy-128.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class ZMark extends StatelessWidget {
  const ZMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Zc.clay, borderRadius: BorderRadius.circular(size * 0.26)),
      alignment: Alignment.center,
      child: Text(
        'Z',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.58,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }
}

// **`plural(n, one, many)` is deleted** — 092, 20 October.
//
// «1 value» and «2 values», built from a number and the English noun handed to
// it. A test caught «1 values» in the vault bar once, which is what it was
// written for; what no test could catch is that German cannot be made this
// way. Every one of its nine call sites is an ICU plural in the one list now,
// one key per sentence, and the noun is inside the sentence where a translator
// can reach it.

/// **The choice, at the word.**
///
/// The owner, 6 October: «the suggested names must appear on the text itself,
/// not as a separate list, and the choices a small message that disappears when
/// it is pressed».
///
/// So a press on a word that is still waiting opens this, anchored where the
/// press happened; the four answers are the four the review panel has, named
/// the same; pressing one applies it and closes; pressing anywhere else, or
/// Escape, closes it and does nothing. It never opens the review panel — that
/// list is what the Review button is for, and it is still there for the person
/// who wants to walk through what is left.
///
/// It stays inside the window: near the bottom it flips above the word, and it
/// is clamped to both edges. A bubble half off the screen is a bubble that
/// cannot be answered.
/// **The word's own two buttons** — 083, rulings 4, 7 and 8.
///
/// The owner, 6 October: «the suggested names must appear on the text itself,
/// not as a separate list, and the choices a small message that disappears when
/// it is pressed». On 14 October he said how many choices: **two.** «Protect»
/// and «Leave it», and nothing else — «Always», «Not sensitive in profile» and
/// «Not sensitive everywhere» are deleted, not hidden, and «Later» is no longer
/// a button at all but the **Next** that walks past this word (ruling 5).
///
/// It answers nothing itself. The press is reported upward, because the walk
/// has to know when a word has been answered: answering moves on by itself, and
/// a widget that calls `bench.answer` and forgets cannot say when to move. One
/// act, one owner — the workspace's walk.
class ChoiceBubble extends StatelessWidget {
  const ChoiceBubble({
    super.key,
    required this.finding,
    required this.at,
    required this.onAnswer,
    required this.onDone,
  });

  final Finding finding;

  /// Where the word is, in the window's own coordinates: where a press landed,
  /// or where the walk found the word on the glass.
  final Offset at;

  /// «Protect» and «Leave it», reported rather than performed.
  final void Function(FindingAnswer) onAnswer;

  /// Close it and answer nothing — a press beside the bubble, or Escape.
  final VoidCallback onDone;

  static const protectKey = ValueKey<String>('word-protect');
  static const leaveKey = ValueKey<String>('word-leave');

  static const double _width = 320;

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    // Guessed tall enough to decide which way to open, and never used as a
    // size: the bubble is as tall as its own content.
    const guess = 150.0;
    final below = at.dy + 14;
    final flip = below + guess > window.height;
    final left = (at.dx - _width / 2).clamp(12.0, (window.width - _width - 12).clamp(12.0, double.infinity));

    return Positioned(
      left: left,
      top: flip ? null : below,
      bottom: flip ? (window.height - at.dy + 14) : null,
      width: _width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Zc.card,
            border: Border.all(color: Zc.clayEdge),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(kindName(finding.kind), style: Zc.tiny.copyWith(color: Zc.ink4)),
                  const Spacer(),
                  // What one press settles, from the core. 041-B counts it.
                  if (finding.occurrences > 1)
                    Text(sentences.inPlacesCount(finding.occurrences), style: Zc.tiny.copyWith(color: Zc.clay)),
                ],
              ),
              const SizedBox(height: 5),
              Text(finding.reason, style: Zc.small.copyWith(color: Zc.ink3), maxLines: 3),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _BubbleAct(
                    key: protectKey,
                    label: sentences.protectAct,
                    primary: true,
                    onPressed: () => onAnswer(FindingAnswer.protect),
                  ),
                  // **«Leave it», and it is an answer.** The count falls, the
                  // word stays as it is written, and every other place of the
                  // same word is answered with it — the core's own
                  // `dismissed`, which is why one «Leave it» on twelve
                  // «Lindqvist» is one stop and not twelve (ruling 7).
                  _BubbleAct(
                    key: leaveKey,
                    label: sentences.leaveIt,
                    onPressed: () => onAnswer(FindingAnswer.notSensitive),
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

class _BubbleAct extends StatelessWidget {
  const _BubbleAct({super.key, required this.label, required this.onPressed, this.primary = false});

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Zc.clay : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: primary ? Colors.transparent : Zc.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary ? Colors.white : Zc.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// **The open session's name, in the head of the screen** — 064/B.
///
/// The owner, 9 October: he made his first session, opened it, and found its
/// name only in the panel's list while the head of the screen carried the
/// file's name alone. His reason is why this is a fact and not a decoration:
/// «more than one session means more than one direction of work». A person
/// working in one has to be able to see which one, in the place they look for
/// what they are working on.
///
/// Drawn **only while one is open**, and read from the ground's own row rather
/// than from a name a screen kept: after a lock the core answers «none», and a
/// head holding its own idea of «open» would name a session nobody can read.
///
/// **It was a fact and not a door, and the owner changed that on 10 Oct 2026**
/// (075b): «الضغط على اسم الجلسة» — wherever a session's name is drawn,
/// pressing it opens what that session kept. The earlier reasoning stands as a
/// record of why it was not one: a head is not a place to put a new act, and
/// the sessions room was one press away in the panel. What it did not weigh is
/// that the name is the only thing on the screen a person *wants* to press,
/// and a name that answers nothing teaches them it is decoration.
class TheOpenSession extends StatelessWidget {
  const TheOpenSession({
    super.key,
    required this.ground,
    this.compact = false,
    this.bench,
  });

  final Ground ground;

  /// Tight, for the workspace's bar — the most crowded strip in the app, where
  /// 2.8 px was the whole margin at 900 before this was added.
  final bool compact;

  /// The document in front of the person, when there is one. Passed to the
  /// core so this session's tokens are named from its own key.
  final SessionId? bench;

  /// Found by what it is, never by the words on it.
  static const mark = ValueKey<String>('the-open-session');

  @override
  Widget build(BuildContext context) {
    final row = ground.openSessionRow;
    if (row == null) return const SizedBox.shrink();
    return Tooltip(
      // The number is the identity and never moves; the name is the handle a
      // person chose. Both, because a renamed session is still that one.
      message: sentences.sessionNamesAreThisSessions(row.number),
      child: InkWell(
        key: ConversationView.door,
        // **The same press as the room's row** — paper 108 item 1, 24 October
        // 2026. Here it is always a look: this chip draws the session that is
        // open, so `goToTheSession` enters nothing and the reading comes up as
        // it did. One function for the two presses, because the owner's rule is
        // about the press and not about where it was made.
        onTap: () => goToTheSession(context, ground, row, bench: bench),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          key: mark,
        padding: compact
            ? const EdgeInsets.fromLTRB(8, 3, 9, 3)
            : const EdgeInsets.fromLTRB(10, 5, 11, 5),
        decoration: Zc.panel(fill: Zc.clayWash, radius: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: compact ? 13 : 14, color: Zc.clayDeep),
            SizedBox(width: compact ? 6 : 7),
            // Flexible with an ellipsis: a long name gives way, it does not
            // push its neighbours off the glass. The bar taught that on
            // 3 October and 063 paid for it at x = 907.
            Flexible(
              child: Text(
                row.name,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: compact ? 12.5 : 13,
                  fontWeight: FontWeight.w600,
                  color: Zc.clayDeep,
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// **The model that will answer: named always, listed on a press** — 064/C.
///
/// The owner pointed at the send sheet with his hand on 9 October: six grey
/// company groups and six «Connect in Settings» doors standing in the middle of
/// his work. His ruling: the name of the model that holds the key is always
/// visible where the work happens, a press on it opens a list of **model names
/// only** — no groups, no grey, no Connect — and the whole catalogue lives in
/// the AI room in the panel.
///
/// So this control answers one question, «who answers if I press send», and the
/// list offers only what can actually answer. A name that cannot answer is not
/// an option; it is a thing to set up, and setting up happens in the panel.
///
/// The name is the catalogue's own `displayName`, never a string written here —
/// `model_gateway_test` holds the rule that no screen in this app carries a
/// model's name.
class TheModelThatAnswers extends StatelessWidget {
  const TheModelThatAnswers({
    super.key,
    required this.ground,
    required this.bench,
    this.onSettings,
  });

  final Ground ground;
  final Workbench bench;

  /// The way to the AI room, for the state where nothing can answer yet. Null
  /// means this surface has nowhere to send the press, and then the line is
  /// said without a door rather than with a dead one.
  final VoidCallback? onSettings;

  static const mark = ValueKey<String>('the-model-that-answers');

  /// The catalogue's own name for an id, and the id itself when this build does
  /// not know it — a provider configured with a model the catalogue never heard
  /// of is still the model that will answer, and saying its id is truer than
  /// saying nothing.
  String _nameOf(String id) {
    for (final m in bench.models) {
      if (m.modelId == id) return m.displayName;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final reachable = bench.models.where((m) => m.available).toList();
    final connected = ground.providers.where((p) => p.connected).toList();
    final chosen = bench.chosenModel;
    // Four states, and exactly one is ever on the glass. The third is honest
    // rather than clever: with two keys and no choice made, each door sends to
    // its own provider's configured model, and no single name is the answer.
    final label = chosen != null
        ? _nameOf(chosen)
        : connected.length == 1
            ? _nameOf(connected.single.model)
            : connected.length > 1
                ? sentences.asEachProviderIsConfigured
                : sentences.noAiConnected;
    final face = Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
      decoration: Zc.panel(fill: Zc.card, edge: Zc.line, radius: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected.isEmpty ? Icons.cloud_off_outlined : Icons.auto_awesome_outlined,
            size: 14,
            color: connected.isEmpty ? Zc.ink4 : Zc.clayDeep,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: connected.isEmpty ? Zc.ink3 : Zc.ink,
              ),
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            size: 17,
            color: reachable.isEmpty ? Zc.ink4 : Zc.ink3,
          ),
        ],
      ),
    );
    if (reachable.isEmpty) {
      // Nothing can answer: one line and one door, which is not a catalogue.
      // The owner's complaint was six companies in the middle of his work, and
      // a single way in is the opposite of that.
      return Tooltip(
        message: onSettings == null
            ? sentences.noProviderIsConnected
            : sentences.connectAnAiInSettings,
        child: InkWell(
          key: mark,
          borderRadius: BorderRadius.circular(20),
          onTap: onSettings,
          child: face,
        ),
      );
    }
    return PopupMenuButton<String>(
      key: mark,
      tooltip: sentences.chooseWhichModelAnswers,
      onSelected: bench.chooseModel,
      itemBuilder: (_) => [
        for (final m in reachable)
          PopupMenuItem<String>(
            value: m.modelId,
            child: Row(
              children: [
                Icon(
                  m.modelId == chosen ? Icons.check : Icons.check_box_outline_blank,
                  size: 15,
                  color: m.modelId == chosen ? Zc.river : Colors.transparent,
                ),
                const SizedBox(width: 9),
                // A name, and nothing else: no company heading, no endpoint,
                // no «connect». The list is what can answer now.
                Text(m.displayName, style: Zc.small.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
      child: face,
    );
  }
}

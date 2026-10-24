// Small pieces used on more than one screen. Nothing here holds state.

import 'package:flutter/material.dart';

import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/widgets/conversation_view.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/document_text.dart' show kindName;

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

/// A small caps label, the boards' section marker.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Zc.label.copyWith(color: color ?? Zc.ink4));
}

/// A fact the core reported: a number and what it counts. Never a computed number.
class Tally extends StatelessWidget {
  const Tally({super.key, required this.value, required this.what, this.tint});

  final String value;
  final String what;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Zc.number.copyWith(color: tint ?? Zc.ink)),
        const SizedBox(height: 5),
        Text(what, style: Zc.small),
      ],
    );
  }
}

/// The app's own button. Two weights and one disabled look, so that «disabled»
/// is a real state everywhere rather than a greyed accident in one place.
class ZButton extends StatelessWidget {
  const ZButton({
    super.key,
    required this.label,
    this.onPressed,
    this.filled = false,
    this.tint,
    this.badge,
    this.icon,
    this.hint,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? tint;
  final int? badge;
  final IconData? icon;

  /// Shown beside a disabled button, because the boards' rule is that a disabled
  /// control must say *why*: «Select text, then Protect».
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    final accent = tint ?? Zc.clay;
    final fg = filled ? Colors.white : (on ? accent : Zc.ink4);
    final bg = filled ? (on ? accent : Zc.line) : (on ? Colors.white : Zc.paper);

    final button = Opacity(
      opacity: on ? 1 : 0.75,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: filled ? Colors.transparent : (on ? Zc.clayEdge : Zc.line)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 8)],
                // Flexible, and wrapping rather than clipping. A label is the
                // only place a person can read what a press will do, so where
                // the space is too narrow the button grows taller — it never
                // hides a word. No ellipsis for the same reason: «Forget from
                // this profile…» would drop the scope and leave the bare act.
                //
                // Loose fit, so a button with room is still exactly its own
                // width; this changes nothing until something squeezes it.
                Flexible(
                  child: Text(
                    label,
                    softWrap: true,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: filled ? Colors.white24 : Zc.amberWash,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: filled ? Colors.white : Zc.amber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!on && hint != null) {
      // **No `mainAxisSize.min` here, and a tight `Flexible`.**
      //
      // The pair is the trap: a `min` row sizes itself to its children's
      // natural widths and gives a flex child nothing, so the hint took the
      // width it wanted and the row overran its own bounds — 58 pixels, with
      // the reason a person needs running off the edge of the screen. It is
      // the same shape as the three overflows of 2 October, and the answer is
      // the same one: the row gives, the sentence is not shortened.
      //
      // Reached for the first time by 046/J, which finds twelve more values on
      // a payroll sheet: a document that had nothing to answer now has
      // something, so this disabled button with its hint is drawn where it
      // never was before.
      return Row(
        children: [
          // The button gives too, not only the sentence beside it: `ZButton`
          // wraps its own label (P2-5), and it can only do that if something
          // bounds its width. Unbounded, the button alone was already wider
          // than the row and flexing the hint changed nothing — measured
          // twice, 58 pixels both times.
          Flexible(child: button),
          const SizedBox(width: 10),
          Flexible(
            fit: FlexFit.tight,
            child: Text(hint!, style: Zc.small.copyWith(color: Zc.ink4)),
          ),
        ],
      );
    }
    return button;
  }
}

/// A line of trouble, in the core's own words. The UI does not rewrite an error:
/// a typed `ApiError` already says what happened, and inventing a friendlier
/// sentence here is how a real reason gets lost.
class Trouble extends StatelessWidget {
  const Trouble(this.text, {super.key, this.onCopyReport});

  final String text;

  /// Offered only when the core has written a report about this refusal. A
  /// person whose document will not open has something to send that is not the
  /// document.
  final VoidCallback? onCopyReport;

  @override
  Widget build(BuildContext context) {
    final copy = onCopyReport;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: Zc.panel(fill: Zc.amberWash, edge: Zc.amberEdge, radius: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Zc.amber),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: Zc.small.copyWith(color: Zc.amber))),
          if (copy != null) ...[
            const SizedBox(width: 9),
            CopyReportButton(onCopy: copy),
          ],
        ],
      ),
    );
  }
}

/// «Copy report» — numbers about a document, never a word of it.
///
/// The text it copies is written by the core and nowhere else, so what lands in
/// the clipboard cannot differ from what the core would say. The button only
/// says whether it has been pressed.
class CopyReportButton extends StatefulWidget {
  CopyReportButton({super.key, required this.onCopy, String? label, this.compact = false})
      : label = label ?? sentences.copyReport;

  final VoidCallback onCopy;
  final String label;

  /// The icon alone, with the words in a tooltip. The top bar is full: the
  /// labelled button overflowed it by 79 pixels at 964 wide, measured.
  final bool compact;

  @override
  State<CopyReportButton> createState() => _CopyReportButtonState();
}

class _CopyReportButtonState extends State<CopyReportButton> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(_done ? Icons.check : Icons.copy_all_outlined, size: 15);
    final style = TextButton.styleFrom(
      foregroundColor: Zc.ink,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    void press() {
      widget.onCopy();
      setState(() => _done = true);
    }

    if (widget.compact) {
      return Tooltip(
        message: _done ? sentences.copied : widget.label,
        child: TextButton(onPressed: press, style: style, child: icon),
      );
    }
    return TextButton.icon(
      onPressed: press,
      icon: icon,
      label: Text(_done ? sentences.copied : widget.label, style: Zc.small),
      style: style,
    );
  }
}

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

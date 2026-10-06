// Small pieces used on more than one screen. Nothing here holds state.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
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

/// «1 value» and «2 values». Small, and the first thing a person notices when
/// it is wrong — a test caught «1 values» in the vault bar before anyone saw it.
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? "${one}s")}';

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
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          const SizedBox(width: 10),
          Flexible(child: Text(hint!, style: Zc.small.copyWith(color: Zc.ink4))),
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
  const CopyReportButton({super.key, required this.onCopy, this.label = 'Copy report', this.compact = false});

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
        message: _done ? 'Copied' : widget.label,
        child: TextButton(onPressed: press, style: style, child: icon),
      );
    }
    return TextButton.icon(
      onPressed: press,
      icon: icon,
      label: Text(_done ? 'Copied' : widget.label, style: Zc.small),
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
class ChoiceBubble extends StatelessWidget {
  const ChoiceBubble({
    super.key,
    required this.bench,
    required this.finding,
    required this.at,
    required this.onVault,
    required this.onDone,
  });

  final Workbench bench;
  final Finding finding;

  /// Where the press happened, in the window's own coordinates.
  final Offset at;

  /// Where «Always» sends a person who has no vault — the same door the review
  /// panel's button opens, and the same sentence on it.
  final VoidCallback onVault;
  final VoidCallback onDone;

  static const double _width = 320;

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    final vault = bench.snap?.vault ?? VaultState.absent;
    final vaultOpen = vault == VaultState.unlocked;
    final needs = vault == VaultState.locked ? 'Always · unlock the vault' : 'Always · needs a vault';
    // Guessed tall enough to decide which way to open, and never used as a
    // size: the bubble is as tall as its own content.
    const guess = 190.0;
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
                    Text('in ${finding.occurrences} places', style: Zc.tiny.copyWith(color: Zc.clay)),
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
                    label: 'Protect',
                    primary: true,
                    onPressed: () {
                      unawaited(bench.answer(finding.id, FindingAnswer.protect));
                      onDone();
                    },
                  ),
                  _BubbleAct(
                    label: vaultOpen ? 'Always' : needs,
                    onPressed: () {
                      if (vaultOpen) {
                        unawaited(bench.answer(finding.id, FindingAnswer.always));
                        onDone();
                      } else {
                        onDone();
                        onVault();
                      }
                    },
                  ),
                  _BubbleAct(
                    label: 'Not sensitive',
                    onPressed: () {
                      unawaited(bench.answer(finding.id, FindingAnswer.notSensitive));
                      onDone();
                    },
                  ),
                  _BubbleAct(
                    label: 'Skip',
                    onPressed: () {
                      unawaited(bench.answer(finding.id, FindingAnswer.skip));
                      onDone();
                    },
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
  const _BubbleAct({required this.label, required this.onPressed, this.primary = false});

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

// Small pieces used on more than one screen. Nothing here holds state.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';

/// The mark. A plain square with a Z — the boards' one piece of identity.
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
                Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
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
  const Trouble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}

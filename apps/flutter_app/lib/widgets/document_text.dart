// The two columns' text: the document with its marks, and the payload with its
// tokens. One file, because the two are the same drawing problem seen twice and
// they must stay visually comparable — that comparison *is* the product.
//
// Spans arrive in UTF-16 code units, which is exactly how Dart counts a string,
// so a span can be used to slice directly. The core refuses a span that falls
// inside a character, so a slice here can never cut one in half.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

/// What each source is called on screen, and why the mark is there.
String sourceName(Source s) => switch (s) {
      Source.generalRule => 'Rule',
      Source.languagePack => 'Pack',
      Source.vault => 'Vault',
      Source.hand => 'You',
    };

/// The colour a source is drawn in. The vault gets its own, because «the app
/// knows who this is» is a different fact from «this looks like an IBAN».
Color sourceTint(Source s) => switch (s) {
      Source.vault => Zc.river,
      _ => Zc.clay,
    };

String kindName(Kind k) => switch (k) {
      Kind.person => 'Person',
      Kind.company => 'Company',
      Kind.email => 'E-mail',
      Kind.phone => 'Phone',
      Kind.iban => 'IBAN',
      Kind.bic => 'BIC',
      Kind.account => 'Account',
      Kind.taxId => 'Tax ID',
      Kind.customerNo => 'Customer no.',
      Kind.address => 'Address',
      Kind.contract => 'Contract',
      Kind.project => 'Project',
      Kind.client => 'Client',
      Kind.custom => 'Custom',
    };

/// The left column: the document as written, with what the scanner did to it
/// drawn **over** the words rather than instead of them. Nothing here is
/// replaced — this side is the original, and the boards' hard rule is that it
/// never reaches the network.
class OriginalText extends StatelessWidget {
  const OriginalText({
    super.key,
    required this.text,
    required this.marks,
    this.selection,
    this.onSelection,
  });

  final String text;
  final List<Mark> marks;

  /// The stretch the user has selected, if any.
  final TextRange? selection;

  /// Reported in UTF-16 code units — which is what the contract's `Span` means,
  /// so the offsets go straight to the core without conversion.
  final void Function(int start, int end)? onSelection;

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(children: _spans(), style: Zc.document),
      style: Zc.document,
      onSelectionChanged: onSelection == null
          ? null
          : (sel, _) => onSelection!(
                sel.start < 0 ? 0 : sel.start,
                sel.end < 0 ? 0 : sel.end,
              ),
    );
  }

  List<InlineSpan> _spans() {
    // Marks may arrive in any order and must not overlap on screen; the core
    // settles overlaps before they get here, so sorting is enough.
    final sorted = [...marks]..sort((a, b) => a.span.start.compareTo(b.span.start));
    final out = <InlineSpan>[];
    var at = 0;

    for (final m in sorted) {
      final start = m.span.start.clamp(0, text.length);
      final end = m.span.end.clamp(start, text.length);
      if (start < at) continue; // an overlap the core did not settle: skip, never double-draw
      if (start > at) out.add(TextSpan(text: text.substring(at, start)));
      out.add(_marked(text.substring(start, end), m));
      at = end;
    }
    if (at < text.length) out.add(TextSpan(text: text.substring(at)));
    return out;
  }

  /// A protected stretch is filled; a suggested one is underlined and left in
  /// the clear. The difference is deliberate and is the whole of G12 made
  /// visible: an unanswered suggestion **is still the real text**.
  InlineSpan _marked(String slice, Mark m) {
    final suggested = m.state == MarkState.suggested;
    final tint = suggested ? Zc.amber : sourceTint(m.source);
    return TextSpan(
      text: slice,
      style: TextStyle(
        backgroundColor: suggested ? Zc.amberWash : (m.source == Source.vault ? Zc.riverWash : Zc.clayWash),
        color: tint,
        fontWeight: FontWeight.w600,
        decoration: suggested ? TextDecoration.underline : null,
        decorationStyle: TextDecorationStyle.wavy,
        decorationColor: Zc.amberEdge,
      ),
    );
  }
}

/// The right column: what the AI will receive. Not a preview of the request —
/// the request. The text is built in Rust and handed over as it stands.
class SafeText extends StatelessWidget {
  const SafeText({super.key, required this.text, this.chips = true});

  final String text;

  /// Chips draw each token as a small block; plain shows the literal token the
  /// model will read. Both are the same string — the boards' «Chips / Plain»
  /// switch changes how it is drawn and never what it says.
  final bool chips;

  static final _token = RegExp(r'__Z_[A-Z0-9]{4}_[A-Z]+_[A-Z0-9]{4}__');

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(children: _spans(), style: Zc.document),
      style: Zc.document,
    );
  }

  List<InlineSpan> _spans() {
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in _token.allMatches(text)) {
      if (m.start > at) out.add(TextSpan(text: text.substring(at, m.start)));
      out.add(chips ? _chip(m.group(0)!) : TextSpan(text: m.group(0), style: Zc.token));
      at = m.end;
    }
    if (at < text.length) out.add(TextSpan(text: text.substring(at)));
    return out;
  }

  /// A chip still spells the token out. Hiding it behind a friendly word would
  /// mean the user cannot check what the model actually reads.
  InlineSpan _chip(String token) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Zc.clayWash,
            border: Border.all(color: Zc.clayEdge),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            token.replaceAll('__', ''),
            style: const TextStyle(fontFamily: Zc.mono, fontSize: 11.5, color: Zc.clayDeep, height: 1.3),
          ),
        ),
      );
}

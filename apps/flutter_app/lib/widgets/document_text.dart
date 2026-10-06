// The two columns' text: the document with its marks, and the payload with its
// tokens. One file, because the two are the same drawing problem seen twice and
// they must stay visually comparable — that comparison *is* the product.
//
// Spans arrive in UTF-16 code units, which is exactly how Dart counts a string,
// so a span can be used to slice directly. The core refuses a span that falls
// inside a character, so a slice here can never cut one in half.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

/// The kinds, as the core hands them over — filled by `Ground.refresh()`.
///
/// This used to be a `switch` over every `Kind`, which is exactly the
/// assumption the owner forbade on 27 September: a screen must not decide that
/// Person, Company, IBAN and Phone are all the kinds there can be. Now the list
/// comes from `kinds()`, and the day it has a user-made row in it, every screen
/// below already draws it.
final List<KindRow> kindRows = [];
final Map<Kind, String> _kindLabels = {};

void rememberKinds(List<KindRow> rows) {
  kindRows
    ..clear()
    ..addAll(rows);
  _kindLabels
    ..clear()
    ..addEntries(rows.map((r) => MapEntry(r.kind, r.label)));
}

/// Never invents a name: before the list has arrived it says nothing.
String kindName(Kind k) => _kindLabels[k] ?? '…';

/// The left column: the document as written, with what the scanner did to it
/// drawn **over** the words rather than instead of them. Nothing here is
/// replaced — this side is the original, and the boards' hard rule is that it
/// never reaches the network.
class OriginalText extends StatefulWidget {
  const OriginalText({
    super.key,
    required this.text,
    required this.marks,
    this.selection,
    this.onSelection,
    this.focus,
    this.focusKey,
    this.onAsk,
    this.onChoose,
  });

  final String text;
  final List<Mark> marks;

  /// The stretch the user has selected, if any.
  final TextRange? selection;

  /// Reported in UTF-16 code units — which is what the contract's `Span` means,
  /// so the offsets go straight to the core without conversion.
  final void Function(int start, int end)? onSelection;

  /// The finding the review list is pointing at. Drawn stronger than the rest,
  /// and given an anchor so the column can be scrolled to it — this is how
  /// «page 17» becomes a place you actually arrive at.
  final Span? focus;
  final GlobalKey? focusKey;

  /// Tapping a protected word asks the one question this whole layer exists to
  /// answer: **why is this protected?**
  final void Function(Mark mark)? onAsk;

  /// Tapping a word that is still **waiting** offers the choice, where the word
  /// is. The owner, 6 October: «the suggested names must appear on the text
  /// itself, not as a separate list, and the choices a small message that
  /// disappears when it is pressed».
  ///
  /// The position is where the finger or the pointer went down, in global
  /// coordinates, because that is what a bubble has to be anchored to.
  final void Function(Mark mark, Offset at)? onChoose;

  @override
  State<OriginalText> createState() => _OriginalTextState();
}

class _OriginalTextState extends State<OriginalText> {
  /// One recognizer per protected mark, rebuilt when the marks change and
  /// disposed with them — a gesture recognizer left behind is a leak that
  /// nothing complains about until it is a lot of them.
  final List<TapGestureRecognizer> _taps = [];

  /// The spans, kept between builds — **and this is what keeps a selection
  /// alive.**
  ///
  /// The Workspace rebuilds this column on every selection change: the drag
  /// reports, the bench is told, the bench notifies. Measured on the published
  /// build: a drag across protected words ended `-1..-1` after that rebuild,
  /// while the same drag on text with no marks on it survived as `0..39`. The
  /// difference was a `TapGestureRecognizer` built fresh for every mark on
  /// every build — `TextSpan` compares its recognizer by identity, so a rebuilt
  /// tree is never equal to the old one, and `SelectableText` answers an
  /// unequal span by replacing its controller, which is where the selection
  /// lived.
  ///
  /// So the spans are built once per (text, marks, focus) and handed back
  /// unchanged until one of those three really changes. The recognizers read
  /// `widget.onAsk` at the moment of the tap rather than closing over the
  /// callback they were built with, so a kept recognizer never calls into a
  /// build that has gone.
  List<InlineSpan>? _cached;
  bool _cachedChoosable = false;
  String? _cachedText;
  List<Mark>? _cachedMarks;
  Span? _cachedFocus;

  @override
  void dispose() {
    _clearTaps();
    super.dispose();
  }

  void _clearTaps() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  List<InlineSpan> _keptSpans() {
    final same = _cached != null &&
        _cachedText == text &&
        _cachedFocus == focus &&
        _cachedChoosable == (widget.onChoose != null) &&
        _cachedMarks != null &&
        listEquals(_cachedMarks, marks);
    if (same) return _cached!;
    _cached = _spans();
    _cachedChoosable = widget.onChoose != null;
    _cachedText = text;
    _cachedMarks = List<Mark>.unmodifiable(marks);
    _cachedFocus = focus;
    return _cached!;
  }

  String get text => widget.text;
  List<Mark> get marks => widget.marks;
  Span? get focus => widget.focus;
  GlobalKey? get focusKey => widget.focusKey;

  @override
  Widget build(BuildContext context) {
    final onSelection = widget.onSelection;
    return SelectableText.rich(
      TextSpan(children: _keptSpans(), style: Zc.document),
      style: Zc.document,
      onSelectionChanged: onSelection == null
          ? null
          : (sel, _) => onSelection(
                sel.start < 0 ? 0 : sel.start,
                sel.end < 0 ? 0 : sel.end,
              ),
    );
  }

  List<InlineSpan> _spans() {
    _clearTaps();
    // Marks may arrive in any order and must not overlap on screen; the core
    // settles overlaps before they get here, so sorting is enough.
    final sorted = [...marks]..sort((a, b) => a.span.start.compareTo(b.span.start));
    final out = <InlineSpan>[];
    var at = 0;
    var anchored = false;

    void upTo(int limit) {
      // The anchor is a zero-size widget dropped in at the focused offset. It
      // adds nothing to the text — `toPlainText` still returns the document —
      // and gives `ensureVisible` something to aim at.
      final f = focus;
      if (!anchored && f != null && focusKey != null && f.start >= at && f.start <= limit) {
        if (f.start > at) out.add(TextSpan(text: text.substring(at, f.start)));
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(key: focusKey, width: 0, height: 0),
        ));
        at = f.start;
        anchored = true;
      }
      if (limit > at) out.add(TextSpan(text: text.substring(at, limit)));
      at = limit;
    }

    for (final m in sorted) {
      final start = m.span.start.clamp(0, text.length);
      final end = m.span.end.clamp(start, text.length);
      if (start < at) continue; // an overlap the core did not settle: skip, never double-draw
      upTo(start);
      out.add(_marked(text.substring(start, end), m));
      at = end;
    }
    upTo(text.length);
    return out;
  }

  /// Four marks, and two facts on every word.
  ///
  /// **The line says who decided. The wash says whether the vault knew.** They
  /// are different questions — the pack may find a name while a person chooses
  /// to protect it — and the core has kept them apart since task 034, as
  /// `Mark.decided` beside `Mark.source`. Before this the screen drew only the
  /// second, so who decided a word could be read in the Why sheet and nowhere
  /// on the word itself.
  ///
  /// ```text
  ///   solid  1.5  clay       a person decided it
  ///   dashed 1.5  clay       a layer decided on its own
  ///   wavy   2.0  amberEdge  still waiting for a person's word
  /// ```
  ///
  /// Waiting beats the source: an unanswered suggestion is wavy whoever found
  /// it, because it **is still the real text** — the whole of G12 made visible.
  /// And a suggested stretch stays unfilled for the same reason.
  InlineSpan _marked(String slice, Mark m) {
    final suggested = m.state == MarkState.suggested;
    final tint = suggested ? Zc.amber : sourceTint(m.source);
    final f = focus;
    final isFocus = f != null && f.start == m.span.start && f.end == m.span.end;
    TapGestureRecognizer? tap;
    final ask = widget.onAsk;
    final choose = widget.onChoose;
    if (!suggested && ask != null) {
      // Read through the widget at tap time: this recognizer outlives the build
      // that made it, and a closure over `ask` would outlive it too.
      tap = TapGestureRecognizer()..onTap = () => widget.onAsk?.call(m);
      _taps.add(tap);
    } else if (suggested && choose != null) {
      // A word still waiting answers a different question — not «why is this
      // protected» but «what do you want done with it» — and it is answered
      // where the word is.
      tap = TapGestureRecognizer()
        ..onTapUp = (details) => widget.onChoose?.call(m, details.globalPosition);
      _taps.add(tap);
    }
    return TextSpan(
      text: slice,
      recognizer: tap,
      mouseCursor: tap == null ? null : SystemMouseCursors.click,
      style: TextStyle(
        // Translucent, so a selection drawn **under** the text still reads
        // through it. A span's background is painted after the selection
        // rectangle, which is why an opaque wash hid it: photographed on 4
        // October, a marked word inside a selection was (247, 231, 218) —
        // `Zc.clayWash`, unchanged by being selected — while the plain text
        // beside it was the blue. The owner's decision, 6 October: the washes
        // give way. Over paper they read a little lighter than before, and that
        // is the whole of the cost.
        backgroundColor: isFocus
            ? tint.withValues(alpha: 0.30)
            : (suggested
                  ? Zc.amberWash.withValues(alpha: _wash)
                  : (m.source == Source.vault
                        ? Zc.riverWash.withValues(alpha: _wash)
                        : Zc.clayWash.withValues(alpha: _wash))),
        color: tint,
        fontWeight: FontWeight.w600,
        // The line is drawn under every mark now, and it is the one thing the
        // focus does not touch: focus moves the wash, so that being pointed at
        // never changes what a mark is saying.
        decoration: TextDecoration.underline,
        decorationStyle: suggested
            ? TextDecorationStyle.wavy
            : (m.decided ? TextDecorationStyle.solid : TextDecorationStyle.dashed),
        decorationColor: suggested ? Zc.amberEdge : Zc.clay,
        decorationThickness: suggested ? 2.0 : 1.5,
      ),
    );
  }
}

/// How much of a mark's wash is left standing, so the selection can be seen
/// through it. Measured against `Zc.river` at 0.40, which is what the selection
/// is painted with.
const double _wash = 0.55;

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
    // The parent scrolls this text. An inner Scrollable would swallow the wheel
    // over the whole payload and leave only a sliver of the outer sheet movable.
    return SelectableText.rich(
      TextSpan(children: _spans(), style: Zc.document),
      style: Zc.document,
      scrollPhysics: const NeverScrollableScrollPhysics(),
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
  ///
  /// **Display only, and dressed as such (P2-7).** It used to be drawn with
  /// `clayWash` filled inside a `clayEdge` border — which in this app is not
  /// decoration but a meaning: it is the costume of a *chosen control*, worn by
  /// every selected language, every on-state toggle, every picked scope. The
  /// chip wore it while carrying no gesture at all, so it invited a press that
  /// could never answer, and the matching word in the Original column **does**
  /// answer one by opening «Why». A person read the difference as a bug in the
  /// program rather than as a difference between the two columns.
  ///
  /// So the border is gone and the fill is a neutral that names no state: this
  /// is a highlight over text, not a button. Nothing was added to make it
  /// interactive — the Original column's mark stays the one way to ask «Why».
  /// The letters keep `clayDeep` and the mono face, because «Chips» and
  /// «Plain» must stay visibly the same string drawn two ways.
  InlineSpan _chip(String token) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Zc.lineSoft,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            token.replaceAll('__', ''),
            style: const TextStyle(fontFamily: Zc.mono, fontSize: 11.5, color: Zc.clayDeep, height: 1.3),
          ),
        ),
      );
}

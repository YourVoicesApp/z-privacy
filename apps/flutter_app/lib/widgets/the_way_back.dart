// **The way back** — 079's import side on the glass, for both doors that reach
// it.
//
// There are two, and they are one reading: the banner under the band over a
// document that turned out to carry our tokens (079 rule 4), and the «z-pdf»
// entry in the + menu, which is the explicit door the owner asked for twice —
// 079 rule 3, built as 089 rule 5. The reading itself belongs to neither of
// them, so it lives here rather than in the screen that happened to need it
// first: two copies of it would be two answers about one document, and the
// sentence above it is already written in exactly one place (`whatCameBack`).
//
// Nothing here works anything out. `Piece` is the core's own field — the words
// as they arrived, the values put back, the tokens that stayed tokens — and no
// text in this file is searched for `__Z_`.

import 'package:flutter/material.dart';

import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

/// **The document with its names back in it.**
///
/// A reading and not an edit: there is nothing to press but «Close». Through
/// the banner, what is on the bench is still the document that arrived, which
/// is the one text the exits may take out; through the z-pdf door there is no
/// bench at all, by the law of that door (079 rule 5).
///
/// One title for both doors, because it is one act: a person who presses
/// «z-pdf» and a person who presses «Read it back» are looking at the same
/// answer about the same kind of file, and a second wording would be a second
/// state that does not exist.
class TheReading extends StatelessWidget {
  const TheReading({super.key, required this.seen});

  final ReturnedDocument seen;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sentences.readBackPanel, style: Zc.h2),
              const SizedBox(height: 6),
              Text(whatCameBack(seen) ?? '', style: Zc.small),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: Zc.panel(fill: Zc.paper, radius: 8),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              for (final piece in seen.restored)
                                TextSpan(
                                  text: piece.text,
                                  style: switch (piece.piece) {
                                    Piece.restored => Zc.document.copyWith(
                                      fontSize: 13,
                                      color: Zc.clayDeep,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    Piece.unresolved =>
                                      Zc.document.copyWith(fontSize: 13, color: Zc.amber),
                                    _ => Zc.document.copyWith(fontSize: 13),
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      // **Every token that stayed a token, by name, one by
                      // one** — 079 rule 7: «never silently dropped». They are
                      // marked where they stand in the reading above, and
                      // named here as a list, because a name standing twice in
                      // a long document is easy to miss twice. `unresolved` is
                      // the core's own list and it is names, never values.
                      //
                      // The heading carries no number: the line above it is
                      // the one place that counts them (`whatCameBack`), and a
                      // second count is a second thing to keep true.
                      if (seen.unresolved.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(sentences.whatStayedAToken, style: Zc.tiny),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final token in seen.unresolved)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: Zc.panel(fill: Zc.amberWash, radius: 6, edge: Zc.amberEdge),
                                child: Text(
                                  token,
                                  style: Zc.token.copyWith(fontSize: 12, color: Zc.amber),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
}

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

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:zprivacy/core/protected_pdf.dart';
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
///
/// **And since 24 October 2026 there is one thing to press** — the owner, paper
/// 108 item 4: «نجعل وثيقة z-pdf يمكننا حفظها بعد فك التشفير… أعتقد فقط يكفي
/// خيار حفظها في الذاكرة كوثيقة pdf». It is still a reading and not an edit:
/// the press writes what is on this screen to a file the person names in their
/// own system's dialog, and changes nothing. **Saving only — printing is out by
/// his own word.**
class TheReading extends StatefulWidget {
  const TheReading({super.key, required this.seen, this.cameFrom, this.whereToSave});

  final ReturnedDocument seen;

  /// **The name of the file this reading came out of**, where the door that
  /// opened it has one — only so the save dialog can suggest a name beside it
  /// («…-restored.pdf»). Never drawn, never sent, and never written into the
  /// file: a file name is the person's own and stays on their machine.
  final String? cameFrom;

  /// **Where the file goes, asked of the system** — null is the product's own
  /// path: `getSaveLocation`, the platform's save dialog. A test passes a hand
  /// of its own, because no dialog can open under `flutter test`; the same
  /// shape as `SendSheet.saveFolder` and for the same reason.
  ///
  /// The suggestion goes in, the chosen path comes back, and `null` from it is
  /// «not now» — nothing is written and nothing is said.
  final Future<String?> Function(String suggested)? whereToSave;

  /// The press, by what it is.
  static const thePress = ValueKey<String>('the-reading-save-as-pdf');

  @override
  State<TheReading> createState() => _TheReadingState();
}

class _TheReadingState extends State<TheReading> {
  bool _saving = false;
  String? _savedTo;
  String? _trouble;

  /// The platform's own save dialog. Two lines, and they are the two that
  /// cannot be measured without a desktop — which is why the hand above exists
  /// and why this is the whole of what it replaces.
  Future<String?> _theSystemAsks(String suggested) async {
    // **No type group.** The dialog is a save and not an open: the name it
    // suggests already ends in `.pdf`, and a filter would only hide the
    // person's other files from a list they are choosing a folder in. One
    // fewer word on the glass is also one fewer word to translate for no
    // reason.
    final place = await getSaveLocation(suggestedName: suggested);
    return place?.path;
  }

  /// **The restored text, written where the person said.**
  ///
  /// `seen.restored` is handed to the writer as it came from the core: this
  /// screen does not flatten it, search it, or decide what any piece of it was
  /// (`buildPlainPdf` holds the one hand that joins the pieces).
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _trouble = null;
      _savedTo = null;
    });
    final ask = widget.whereToSave ?? _theSystemAsks;
    String? path;
    try {
      path = await ask(theNameForARestoredPdf(widget.cameFrom));
    } catch (e) {
      // **The one call in this press that leaves the program.** A dialog that
      // cannot be opened — no portal, a platform this build does not know —
      // would otherwise leave the press on «Saving…» for the rest of the
      // session with nothing on the screen to say why, which is the fault
      // `saveProtectedPdf`'s own catch exists for. A person is told what
      // happened to them.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _trouble = sentences.couldNotAskWhereToSaveIt(theMachinesOwnWord('$e'));
      });
      return;
    }
    if (!mounted) return;
    if (path == null) {
      // The dialog was closed: nothing was written, so nothing is said. A
      // sentence about a save nobody asked for is noise.
      setState(() => _saving = false);
      return;
    }
    final out = await savePlainPdf(restored: widget.seen.restored, path: path);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedTo = out.path;
      _trouble = out.trouble;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seen = widget.seen;
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
              const SizedBox(height: 14),
              // **What the file would be, said before it is written** — paper
              // 108 item 4. This is the person's own document with their own
              // values in it: no answer page, no footer, no mark, and nothing
              // in it that claims a protection. A press that writes values in
              // the clear in a privacy product says so where it is pressed,
              // and not in a guide.
              Text(sentences.aPlainPdfOfTheRestoredText, style: Zc.small),
              if (_savedTo != null) ...[
                const SizedBox(height: 8),
                // Where it went, in full. «Saved» is not an answer to «where».
                Text(sentences.savedToWhere(theMachinesOwnWord(_savedTo!)),
                    style: Zc.small.copyWith(color: Zc.ink2)),
              ],
              if (_trouble != null) ...[
                const SizedBox(height: 8),
                Trouble(_trouble!),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ZButton(
                    key: TheReading.thePress,
                    label: _saving ? sentences.saving : sentences.saveAsAPlainPdf,
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: _saving ? null : () => unawaited(_save()),
                  ),
                  const SizedBox(width: 10),
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

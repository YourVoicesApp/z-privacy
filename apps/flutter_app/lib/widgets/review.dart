// Review, **in the list** — the second of its two forms (083, ruling 6).
//
// The owner, 14 Oct: the review is lived **in the text** — the word lit where
// it stands, with its two buttons beside it and Next carrying the count — and
// the list is what answers «what is left?». So this panel holds **only what
// waits**, with «Protect all» and «Skip all» at its foot. The three groups it
// used to draw are gone with the question they answered: what the app protected
// by itself and what a person decided are **seen in the text**, which is where
// they are, and a list that repeats them buries the one group that still needs a
// press.
//
// The one-at-a-time form that used to live here (`_Walk`, and the icon that
// switched to it) is gone for the same reason: it is now the walk in the text,
// and two walks would be two laws about which word is next.
//
// Every row carries the rule that flagged it and where it sits. «Page 17» is the
// core's own `Place`, kept through protection — the row can still jump there
// after everything has been replaced.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/going_to_a_word.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';

class ReviewPanel extends StatelessWidget {
  const ReviewPanel({super.key, required this.bench, required this.width});

  final Workbench bench;

  /// Set by the Workspace from the window's width: two columns must stay
  /// readable, and a panel that squeezes them off the screen is worse than a
  /// narrow panel.
  final double width;

  @override
  Widget build(BuildContext context) {
    final open = theWaitingWordsInReadingOrder(bench.findings);

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(left: BorderSide(color: Zc.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(open.length),
          Container(height: 1, color: Zc.lineSoft),
          Expanded(child: _List(bench: bench, open: open)),
          // **At its foot, and fixed there.** The paper says «at its foot»; a
          // row inside the scroller would be at the foot of forty words, which
          // is three flicks away from the person who wanted all of them in one
          // press. Two words waiting need no «all»: their own buttons are right
          // there.
          if (open.length > 1) ...[
            Container(height: 1, color: Zc.lineSoft),
            _AllOfThem(bench: bench, open: open),
          ],
        ],
      ),
    );
  }

  Widget _header(int open) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(sentences.reviewAct),
                const SizedBox(height: 4),
                Text(
                  open == 0
                      ? sentences.nothingIsWaitingForYou
                      : sentences.thingsWaitingForYourWord(open),
                  style: Zc.small.copyWith(
                    color: open == 0 ? Zc.ink3 : Zc.amber,
                    fontWeight: open == 0 ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: sentences.close,
            icon: const Icon(Icons.close, size: 18),
            color: Zc.ink3,
            onPressed: bench.closeReview,
          ),
        ],
      ),
    );
  }
}

/// **Only what waits**, in reading order — ruling 6.
class _List extends StatelessWidget {
  const _List({required this.bench, required this.open});

  final Workbench bench;
  final List<Finding> open;

  @override
  Widget build(BuildContext context) {
    if (open.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          bench.findings.isEmpty
              ? sentences.theScanFoundNothingHere
              // Not «the list is empty»: what the app protected and what you
              // decided are in the text, and this is where to look for them.
              : sentences.nothingIsWaitingWhatIsProtected,
          style: Zc.small,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [for (final f in open) _Row(bench: bench, finding: f)],
    );
  }
}

/// One waiting word: what it is, why it was flagged, where it sits, and its two
/// answers.
class _Row extends StatelessWidget {
  const _Row({required this.bench, required this.finding});

  final Workbench bench;
  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final focused = bench.focused == finding.id;
    final tint = finding.state == MarkState.suggested
        ? Zc.amber
        : sourceTint(finding.source);
    final text = bench.document == null
        ? ''
        : bench.document!.text.substring(finding.span.start, finding.span.end);

    return InkWell(
      onTap: () => bench.focusOn(focused ? null : finding.id),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: focused ? tint.withValues(alpha: 0.07) : Zc.paper,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: focused ? tint.withValues(alpha: 0.45) : Zc.lineSoft,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: Zc.document.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _Tag(kindName(finding.kind), Zc.ink4),
              ],
            ),
            const SizedBox(height: 5),
            Text(finding.reason, style: Zc.small.copyWith(color: Zc.ink3)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                _Tag(
                  sentences.foundBySource(sourceName(finding.source)),
                  sourceTint(finding.source),
                ),
                if (finding.decided) _Tag(sentences.youDecided, Zc.clay),
                if (finding.place != null)
                  _Tag(
                    sentences.pageAndParagraph(
                        finding.place!.page, finding.place!.paragraph),
                    Zc.ink4,
                  ),
                // What one press will settle. The core counts the places; this
                // line only reads the number, and says nothing when a value
                // stands once — «in 1 places» is noise, and wrong English.
                if (finding.occurrences > 1)
                  _Tag(sentences.inPlacesCount(finding.occurrences), Zc.clay),
                if (finding.entities.length > 1)
                  _Tag(
                    sentences.identitiesClaimIt(finding.entities.length),
                    Zc.river,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _Answers(bench: bench, finding: finding),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.tint);

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: tint,
        ),
      ),
    );
  }
}

/// **All of them, in one press — and the two directions do not cost the same.**
///
/// 041-O, queued since the owner's first evening, and his words on 7 October:
/// «خيار مثل تحديد الكل… هذا مفيد جداً في القوائم». On his own payroll sheet
/// that was eighteen presses.
///
/// **The asymmetry is the design and not an oversight**, so it is written here
/// where someone would otherwise tidy it into symmetry:
///
///   * **«Protect all»** is one press and asks nothing. Over-protecting is
///     never a leak; the worst case is a token where a person wanted a word,
///     and that is undone in one press on the row itself.
///   * **«Skip all»** asks once, with the number in the sentence — the owner
///     kept this confirmation by name on 14 Oct (ruling 9): it is **the one
///     door that uncovers words in a batch.** One press may not expose eighteen
///     people, and a confirmation that does not say how many is not a
///     confirmation.
///
/// If the two were built the same way, the cheap direction would be as
/// expensive as the dangerous one — or, far worse, the dangerous one would
/// become as cheap as the cheap one.
class _AllOfThem extends StatelessWidget {
  const _AllOfThem({required this.bench, required this.open});

  final Workbench bench;
  final List<Finding> open;

  static const protectKey = ValueKey<String>('review-all-protect');
  static const leaveKey = ValueKey<String>('review-all-leave');

  Future<void> _leaveThemAll(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (inner) => AlertDialog(
        backgroundColor: Zc.paper,
        title: Text(sentences.leaveWordsInTheClearQuestion(open.length), style: Zc.h2),
        content: Text(
          sentences.leaveAllInTheClearExplained(open.length),
          style: Zc.body,
        ),
        actions: [
          ZButton(label: sentences.cancel, onPressed: () => Navigator.of(inner).pop(false)),
          ZButton(
            // The number is in the act's own name, which is P2-5's rule and
            // the reason this dialog exists at all — **and «Yes» in front of
            // it**, so the confirmation is not word for word the same as the
            // button that opened it. Two different acts wearing one name on
            // screen at the same time is the same family of defect as a chip
            // that looks pressable: found here by a test that could not tell
            // which of the two to press.
            label: sentences.yesLeaveAllInTheClear(open.length),
            filled: true,
            onPressed: () => Navigator.of(inner).pop(true),
          ),
        ],
      ),
    );
    if (sure != true) return;
    for (final f in open) {
      await bench.answer(f.id, FindingAnswer.notSensitive);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ZButton(
            key: protectKey,
            label: sentences.protectAll,
            icon: Icons.shield_outlined,
            badge: open.length,
            onPressed: bench.busy
                ? null
                : () async {
                    // By id and not by index: one answer settles every place
                    // of the same word (ruling 7), so the list shortens under
                    // this loop and an id that is already answered is a
                    // no-change in the core rather than an error.
                    for (final f in open) {
                      await bench.answer(f.id, FindingAnswer.protect);
                    }
                  },
          ),
          ZButton(
            key: leaveKey,
            label: sentences.skipAll,
            badge: open.length,
            onPressed: bench.busy ? null : () => _leaveThemAll(context),
          ),
        ],
      ),
    );
  }
}

/// **Two answers, and the walk is where «later» went** — rulings 5, 7 and 8.
///
/// What was here on 13 October: Protect · Always · Not sensitive · Not
/// sensitive in profile · Not sensitive everywhere, and «Later» on a line of
/// its own. The owner, 14 Oct: two buttons, no more. The three that are gone
/// are **deleted and not hidden** — «Always» and the two «remember this»
/// scopes wrote knowledge that outlived the conversation, and 083's model has
/// no such thing: «No name memory across sessions».
///
/// **046/L's finding survives the deletion of its own button.** «Later» sat in
/// this row, the same size and shape as the two answers, so it read as a
/// decision while the count did not fall — and the conclusion a reasonable
/// person drew was «the review is blocking me». The answer then was to give it
/// its own line and its own shape. The answer now is better: **leaving a word
/// for later is the Next button**, which is not in this row at all and not even
/// in this panel. A thing that is not an answer may not be drawn as one, and
/// the surest way is for it not to be drawn here.
///
/// There is still no button that sends anyway. That one was deleted from the
/// product.
class _Answers extends StatelessWidget {
  const _Answers({required this.bench, required this.finding});

  /// Named so a test presses the thing a person presses.
  static const protectKey = ValueKey<String>('review-protect');
  static const leaveKey = ValueKey<String>('review-leave');

  final Workbench bench;
  final Finding finding;

  @override
  Widget build(BuildContext context) {
    Widget one(
      Key key,
      String label,
      FindingAnswer a,
      Color tint, {
      bool filled = false,
    }) => Material(
      color: filled ? tint : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        key: key,
        onTap: () => bench.answer(finding.id, a),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: filled ? Colors.transparent : Zc.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : tint,
            ),
          ),
        ),
      ),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        one(protectKey, sentences.protectAct, FindingAnswer.protect, Zc.clay, filled: true),
        one(leaveKey, sentences.leaveIt, FindingAnswer.notSensitive, Zc.ink3),
      ],
    );
  }
}

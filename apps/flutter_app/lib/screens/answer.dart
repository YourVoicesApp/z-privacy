// The answer — in your words, and in the model's.
//
// Two views of one string, and the boards give both a fixed button because the
// difference is the point:
//
//   Restored   the answer with your real values put back, here, locally.
//   AI view    the answer exactly as the model wrote it, tokens and all.
//
// Copy is two named acts, never one button:
//
//   Copy Restored    the real values — confirmed every time, then the system clipboard.
//   Copy Protected   tokens still in the text — the manual path out to a model.
//
// The restored view is **built in Rust** and arrives as segments, each saying
// whether it is plain text or a value that came back. Rebuilding it in Dart
// would mean the UI holding the token table, and it does not.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

class AnswerPanel extends StatefulWidget {
  const AnswerPanel({super.key, required this.bench, this.width});

  final Workbench bench;

  /// Set by the Workspace from the window's width: two columns must stay
  /// readable, and a panel that squeezes them off the screen is worse than a
  /// narrow panel.
  ///
  /// **`null` is the home's shape** (046/G): the answer sits under the question
  /// in the page's own flow, with no width of its own and no column border, and
  /// it grows to the height of what the model wrote instead of filling a column.
  /// Everything else about it — the two views, the fourth mark on a restored
  /// value, the two named copies and the clipboard confirmation — is the same
  /// code, because the owner's rule is that a sentence lives in one place.
  final double? width;

  /// True when this is the home's inline answer rather than the Workspace's
  /// column.
  bool get inline => width == null;

  /// The band that says an answer carries tokens this conversation cannot
  /// resolve (046/U). Named so a test finds it by what it is rather than by
  /// the words on it.
  static const unresolved = ValueKey<String>('answer-unresolved-tokens');

  @override
  State<AnswerPanel> createState() => _AnswerPanelState();
}

class _AnswerPanelState extends State<AnswerPanel> {
  bool _restored = true;
  Future<AnswerSnapshot>? _facts;
  AnswerId? _for;

  /// What the last copy did, in words. Kept here rather than flashed: the
  /// restored path must never claim the clipboard is still ours after writing.
  String? _copyNote;

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final answer = bench.showing;
    if (answer == null) return const SizedBox.shrink();

    // Everything about this answer in one read: both views, its position, and
    // its neighbours. One answer, one source.
    if (_for != answer) {
      _for = answer;
      _facts = bench.answerFacts(answer);
    }

    final inline = widget.inline;
    return Container(
      width: widget.width,
      decoration: inline
          ? Zc.panel(fill: Zc.card, radius: 12)
          : const BoxDecoration(
              color: Zc.card,
              border: Border(left: BorderSide(color: Zc.line)),
            ),
      child: Column(
        mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('The answer'),
                      const SizedBox(height: 4),
                      // The position and the two arrows come from the same
                      // snapshot as the text below. The screen used to count
                      // `2 of 2` from a Dart list — a second source for a
                      // fact Rust already holds, and the moment navigation
                      // existed it would have become a third.
                      FutureBuilder<AnswerSnapshot>(
                        future: _facts,
                        builder: (context, snap) {
                          final facts = snap.data;
                          if (facts == null) {
                            return const Text('…', style: Zc.small);
                          }
                          if (facts.total == 1) {
                            return const Text(
                              'One answer in this conversation.',
                              style: Zc.small,
                            );
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Step(
                                icon: Icons.chevron_left,
                                tip: 'Previous answer',
                                to: facts.previous,
                                onGo: bench.show,
                              ),
                              Text(
                                'Answer ${facts.index} of ${facts.total}.',
                                style: Zc.small,
                              ),
                              _Step(
                                icon: Icons.chevron_right,
                                tip: 'Next answer',
                                to: facts.next,
                                onGo: bench.show,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Zc.ink3,
                  onPressed: () => bench.show(null),
                ),
              ],
            ),
          ),
          // The two fixed buttons. Both always here, both always pressable —
          // the boards ask for that because a view you cannot get back to is a
          // view you cannot trust.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Tab(
                  label: 'Restored',
                  on: _restored,
                  onTap: () => setState(() {
                    _restored = true;
                    _copyNote = null;
                  }),
                ),
                _Tab(
                  label: 'As the model wrote it',
                  on: !_restored,
                  onTap: () => setState(() {
                    _restored = false;
                    _copyNote = null;
                  }),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Zc.lineSoft),
          // **The question at the head of its answer** (046/N).
          //
          // The owner asked that the answer appear under the question and not
          // in a third screen, and it never was in a third screen — this panel
          // has lived in the workspace all along. What was missing was not
          // geometry but the **legibility of the pair**: side by side, nothing
          // said which request this answered. Stacking the panel under the
          // field would have fought 046/K's centred half for no gain.
          //
          // It follows the tab, which is the only honest way to quote it: in
          // the restored view it is the question **as the person typed it**,
          // and in the model's view it is the question **as the model received
          // it**. Showing the raw sentence above «as the model wrote it» would
          // say the model had read a name it never saw.
          if (_quoted(bench).isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: Zc.warmCard,
                border: Border(bottom: BorderSide(color: Zc.lineSoft)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You asked', style: Zc.tiny.copyWith(color: Zc.ink4)),
                  const SizedBox(height: 3),
                  SelectableText(
                    _quoted(bench),
                    style: Zc.small.copyWith(color: Zc.ink2),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          // A column fills its height; a page grows to the text. The builder is
          // the same one either way.
          _Fill(
            inline: inline,
            child: FutureBuilder<AnswerSnapshot>(
              future: _facts,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(18),
                    child: Trouble('${snap.error}'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Zc.clay,
                      ),
                    ),
                  );
                }
                final segments = snap.data!.restored;
                final raw = snap.data!.asWritten;
                final unknown = snap.data!.unknownTokens;
                return ListView(
                  // On the home this list is inside the page's own scroller,
                  // so it must take its height from its children and scroll
                  // with the page rather than against it.
                  shrinkWrap: inline,
                  physics: inline ? const NeverScrollableScrollPhysics() : null,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    // **An answer this conversation cannot restore says so,
                    // above the answer** (046/U).
                    //
                    // The owner, 7 October: he comes back after days away, with
                    // other documents in between, and pastes the answer he was
                    // given. Until this, every token of that older conversation
                    // came back **as the model's own words** — he would read
                    // `__Z_5CDD_IBAN_5B32__` in the middle of a sentence about
                    // his account with nothing to tell him whether the app had
                    // failed or the model had written that.
                    //
                    // Above and not below: it changes how the whole answer is
                    // to be read, and a warning under the text is a warning
                    // read after the damage.
                    if (_restored && unknown.isNotEmpty) ...[
                      Container(
                        key: AnswerPanel.unresolved,
                        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                        decoration: Zc.panel(fill: Zc.amberWash, edge: Zc.amberEdge, radius: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.help_outline, size: 16, color: Zc.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    unknown.length == 1
                                        ? 'This answer carries 1 token this conversation does not '
                                              'know — it was made in another conversation.'
                                        : 'This answer carries ${unknown.length} tokens this '
                                              'conversation does not know — they were made in '
                                              'another conversation.',
                                    style: Zc.small.copyWith(
                                      color: Zc.amber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // **Named, so the sentence can be checked.** A
                            // count on its own is a claim; the names are what
                            // let a person find them in the text in front of
                            // them.
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                unknown.join('\n'),
                                style: Zc.tiny.copyWith(letterSpacing: 0, fontFamily: Zc.mono),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                // The honest rule, said where it is needed:
                                // restoring across days works for what was
                                // kept, and nothing else.
                                'They are left exactly as the model wrote them. Restoring an older '
                                'answer works for values you chose to keep — «this client» or '
                                '«always» — because the vault still has those.',
                                style: Zc.tiny.copyWith(letterSpacing: 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_restored)
                      SelectableText.rich(
                        TextSpan(
                          children: [
                            for (final seg in segments)
                              TextSpan(
                                text: seg.text,
                                // The fourth mark: dotted for a value that was
                                // put back here, locally. The other three live
                                // in the document's own column; this is the only
                                // place a word can carry this one, because it is
                                // the only place a value comes back.
                                style: switch (seg.piece) {
                                  // The fourth mark: dotted for a value that
                                  // was put back here, locally.
                                  Piece.restored => const TextStyle(
                                    backgroundColor: Zc.clayWash,
                                    color: Zc.clayDeep,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationStyle: TextDecorationStyle.dotted,
                                    decorationColor: Zc.clayDeep,
                                    decorationThickness: 1.5,
                                  ),
                                  // **And a token we could not resolve is not
                                  // drawn as the answer.** Amber, which in
                                  // this app means «not decided, still in the
                                  // clear» and is the only honest colour for
                                  // a name standing where a value should be.
                                  // Struck through, because it is the one
                                  // thing in the text that is not what the
                                  // sentence appears to say.
                                  Piece.unresolved => const TextStyle(
                                    backgroundColor: Zc.amberWash,
                                    color: Zc.amber,
                                    fontFamily: Zc.mono,
                                    fontSize: 13,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Zc.amberEdge,
                                    decorationThickness: 1.5,
                                  ),
                                  Piece.words => null,
                                },
                              ),
                          ],
                        ),
                        style: Zc.document,
                      )
                    else
                      SelectableText(raw, style: Zc.document),
                    const SizedBox(height: 16),
                    Text(
                      _restored
                          ? unknown.isEmpty
                                ? 'The marked words were put back here, on this device. The model '
                                      'never saw them.'
                                : 'The dotted words were put back here, on this device. The struck '
                                      'ones are tokens this conversation cannot put back.'
                          : 'This is the answer exactly as it arrived, with the tokens still in it.',
                      style: Zc.tiny.copyWith(letterSpacing: 0),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Zc.warmCard,
              border: Border(top: BorderSide(color: Zc.lineSoft)),
            ),
            child: FutureBuilder<AnswerSnapshot>(
              future: _facts,
              builder: (context, snap) {
                // Both texts come from the same snapshot as the position and
                // the neighbours, so a copy can never belong to a different
                // answer from the one on screen.
                final restoredText = snap.hasData
                    ? snap.data!.restored.map((s) => s.text).join()
                    : '';
                final protectedText = snap.hasData ? snap.data!.asWritten : '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ZButton(
                          label: _restored ? 'Copy Restored' : 'Copy Protected',
                          icon: Icons.copy_all_outlined,
                          onPressed: !snap.hasData
                              ? null
                              : () {
                                  if (_restored) {
                                    unawaited(_copyRestored(restoredText));
                                  } else {
                                    unawaited(_copyProtected(protectedText));
                                  }
                                },
                        ),
                        const SizedBox(width: 9),
                        if (bench.answers.length > 1)
                          Expanded(
                            child: Text(
                              'Earlier answers stay in this conversation until you close it.',
                              style: Zc.tiny.copyWith(letterSpacing: 0),
                            ),
                          ),
                      ],
                    ),
                    if (_copyNote != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _copyNote!,
                        style: Zc.tiny.copyWith(letterSpacing: 0),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The question this answer answered, in the words the current tab is about.
  ///
  /// Empty when there was no request: a document may be sent with no
  /// instruction, and a head that said «You asked» over nothing would be a
  /// sentence about something that did not happen.
  String _quoted(Workbench bench) =>
      _restored ? bench.question.trim() : bench.questionSafe.trim();

  /// The restored string holds the real values. The clipboard is the system's,
  /// so writing it is named and confirmed every time — not a tutorial, a
  /// secret leaving the app.
  Future<void> _copyRestored(String text) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Zc.paper,
        title: const Text('Copy restored text?', style: Zc.h2),
        content: const Text(
          'This will place the real protected values on your system clipboard. Other applications may be able to read the clipboard.',
          style: Zc.body,
        ),
        actions: [
          ZButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ZButton(
            label: 'Copy Restored',
            filled: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copyNote = 'Restored text copied to the system clipboard.');
  }

  Future<void> _copyProtected(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copyNote = null);
  }
}

/// `Expanded` in a column, and plain in a page.
///
/// One widget rather than two copies of the body: the Workspace's answer fills
/// the column it is given, and the home's grows to what the model wrote.
class _Fill extends StatelessWidget {
  const _Fill({required this.inline, required this.child});

  final bool inline;
  final Widget child;

  @override
  Widget build(BuildContext context) => inline ? child : Expanded(child: child);
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? Zc.clayWash : Zc.paper,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? Zc.clayEdge : Zc.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: on ? Zc.clayDeep : Zc.ink3,
            ),
          ),
        ),
      ),
    );
  }
}


/// One arrow. Disabled when the core says there is nothing on that side —
/// never because a screen worked out that it is at an end.
class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.tip, required this.to, required this.onGo});

  final IconData icon;
  final String tip;

  /// The answer to move to, straight from the snapshot. `null` is the end.
  final AnswerId? to;
  final void Function(AnswerId?) onGo;

  @override
  Widget build(BuildContext context) {
    final on = to != null;
    return IconButton(
      tooltip: on ? tip : null,
      icon: Icon(icon, size: 18),
      color: on ? Zc.clay : Zc.ink4.withValues(alpha: 0.4),
      visualDensity: VisualDensity.compact,
      onPressed: on ? () => onGo(to) : null,
    );
  }
}

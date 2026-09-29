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
  const AnswerPanel({super.key, required this.bench, required this.width});

  final Workbench bench;

  /// Set by the Workspace from the window's width: two columns must stay
  /// readable, and a panel that squeezes them off the screen is worse than a
  /// narrow panel.
  final double width;

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

    return Container(
      width: widget.width,
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(left: BorderSide(color: Zc.line)),
      ),
      child: Column(
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
          Expanded(
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
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    if (_restored)
                      SelectableText.rich(
                        TextSpan(
                          children: [
                            for (final seg in segments)
                              TextSpan(
                                text: seg.text,
                                style: seg.restored
                                    ? const TextStyle(
                                        backgroundColor: Zc.clayWash,
                                        color: Zc.clayDeep,
                                        fontWeight: FontWeight.w600,
                                      )
                                    : null,
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
                          ? 'The marked words were put back here, on this device. The model never '
                                'saw them.'
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

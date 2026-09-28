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
  Future<(List<Segment>, String)>? _both;
  AnswerId? _for;

  /// What the last copy did, in words. Kept here rather than flashed: the
  /// restored path must never claim the clipboard is still ours after writing.
  String? _copyNote;

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final answer = bench.showing;
    if (answer == null) return const SizedBox.shrink();

    // Both views of the same answer, fetched once per answer.
    if (_for != answer) {
      _for = answer;
      _both = Future.wait([
        bench.restored(answer),
        bench.asTheModelWroteIt(answer),
      ]).then((r) => (r[0] as List<Segment>, r[1] as String));
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
                      Text(
                        bench.answers.length == 1
                            ? 'One answer in this conversation.'
                            : 'Answer ${bench.answers.indexOf(answer) + 1} of ${bench.answers.length}.',
                        style: Zc.small,
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
            child: FutureBuilder<(List<Segment>, String)>(
              future: _both,
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
                final (segments, raw) = snap.data!;
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
            child: FutureBuilder<(List<Segment>, String)>(
              future: _both,
              builder: (context, snap) {
                final restoredText = snap.hasData
                    ? snap.data!.$1.map((s) => s.text).join()
                    : '';
                final protectedText = snap.hasData ? snap.data!.$2 : '';
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

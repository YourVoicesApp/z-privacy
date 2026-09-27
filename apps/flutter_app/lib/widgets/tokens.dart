// The tokens panel.
//
// One rule governs this whole file, and it is one of the three the boards call
// non-negotiable: **Reveal draws on the screen and never writes into the
// payload.** So nothing here calls anything that could change the outgoing text,
// and the value that appears lives in the UI's own map, for as long as the core
// said and no longer.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';

class TokensPanel extends StatefulWidget {
  const TokensPanel({super.key, required this.bench, required this.width});

  final Workbench bench;

  /// Set by the Workspace from the window's width: two columns must stay
  /// readable, and a panel that squeezes them off the screen is worse than a
  /// narrow panel.
  final double width;

  @override
  State<TokensPanel> createState() => _TokensPanelState();
}

class _TokensPanelState extends State<TokensPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // A revealed value has a life; something has to end it even if nobody
    // touches the app again.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => widget.bench.expireReveals());
  }

  @override
  void dispose() {
    _tick?.cancel();
    // Leaving re-hides everything that was shown.
    widget.bench.hideEverything();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final tokens = bench.tokens;

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
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Active Z tokens'),
                      const SizedBox(height: 4),
                      Text(
                        tokens.isEmpty
                            ? 'Nothing is protected yet.'
                            : '${tokens.length} ${tokens.length == 1 ? "value stands" : "values stand"} '
                                'behind a token in this conversation.',
                        style: Zc.small,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 18),
                  color: Zc.ink3,
                  onPressed: () => bench.openTokens(false),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Zc.lineSoft),
          Expanded(
            child: tokens.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'A token appears here the moment something is protected.',
                      style: Zc.small,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                    children: [for (final t in tokens) _TokenRow(bench: bench, row: t)],
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
            decoration: const BoxDecoration(
              color: Zc.warmCard,
              border: Border(top: BorderSide(color: Zc.lineSoft)),
            ),
            child: Text(
              'Revealing shows a value on this screen for a moment. It changes nothing in '
              'the Safe column — what leaves the device is the same string before and after.',
              style: Zc.tiny.copyWith(letterSpacing: 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({required this.bench, required this.row});

  final Workbench bench;
  final TokenRow row;

  @override
  Widget build(BuildContext context) {
    final shown = bench.revealed[row.token];
    final tint = sourceTint(row.source);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: Zc.panel(fill: Zc.paper, edge: Zc.lineSoft, radius: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  row.token,
                  style: const TextStyle(fontFamily: Zc.mono, fontSize: 12, color: Zc.clayDeep),
                ),
              ),
              IconButton(
                tooltip: 'Copy the token',
                icon: const Icon(Icons.copy_all_outlined, size: 15),
                color: Zc.ink4,
                visualDensity: VisualDensity.compact,
                onPressed: () => Clipboard.setData(ClipboardData(text: row.token)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Wrap, not Row: «This conversation» plus a long kind name is wider
          // than the panel, and a tag pushed off the edge is a fact nobody reads.
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _Tag(kindName(row.kind), Zc.ink4),
              _Tag(sourceName(row.source), tint),
              _Tag(
                switch (row.scope) {
                  Scope.once => 'Once',
                  Scope.conversation => 'This conversation',
                  Scope.always => 'Always',
                },
                Zc.ink4,
              ),
            ],
          ),
          if (row.sourceDetail.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(row.sourceDetail, style: Zc.tiny.copyWith(letterSpacing: 0)),
          ],
          const SizedBox(height: 9),
          if (shown == null)
            ZButton(
              label: 'Reveal',
              icon: Icons.visibility_outlined,
              onPressed: () => bench.reveal(row.token),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: Zc.panel(fill: Zc.card, edge: Zc.clayEdge, radius: 7),
                    child: SelectableText(shown, style: Zc.document.copyWith(fontSize: 13.5)),
                  ),
                ),
                const SizedBox(width: 8),
                ZButton(
                  label: 'Hide',
                  icon: Icons.visibility_off_outlined,
                  onPressed: () => bench.hideToken(row.token),
                ),
              ],
            ),
        ],
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
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tint)),
    );
  }
}

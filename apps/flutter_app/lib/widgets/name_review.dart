// «I have 17 names for you to look at.»
//
// The owner's measure of this phase is not how many names Z knows; it is how
// few small decisions a person makes before a document is understood. So this
// panel never shows an occurrence. It shows a **name**, once, with what the
// decision is worth — how many places it stands in, and how many pages — and
// three lines of context, because one look should be enough.
//
// Three acts, and what each one means is written where it is pressed:
//
//   Add as family name   teach Z the word, and every place it stands is seen
//   Add person           protect this person, here and now
//   Ignore               not a name; do not ask again in this session
//
// No dictionary editor. Z brings what needs a decision, and nothing else.

import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

class NameReviewPanel extends StatelessWidget {
  const NameReviewPanel({super.key, required this.bench, required this.width});

  final Workbench bench;
  final double width;

  @override
  Widget build(BuildContext context) {
    final open = bench.openCandidates;
    return Container(
      width: width,
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
                      Text(
                        open.isEmpty
                            ? 'No names to look at'
                            : open.length == 1
                            ? '1 name to look at'
                            : '${open.length} names to look at',
                        style: Zc.h2,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        open.isEmpty
                            ? 'Z knows every name this document uses.'
                            : 'Words this document uses as names, that Z does not know yet.',
                        style: Zc.small.copyWith(color: Zc.ink3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 18),
                  color: Zc.ink3,
                  onPressed: bench.closeNameReview,
                ),
              ],
            ),
          ),
          Container(height: 1, color: Zc.lineSoft),
          Expanded(
            child: open.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: open.length,
                    separatorBuilder: (_, _) => Container(height: 1, color: Zc.lineSoft),
                    itemBuilder: (_, i) => _Row(bench: bench, candidate: open[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.bench, required this.candidate});

  final Workbench bench;
  final NameCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final places = candidate.occurrences == 1 ? '1 place' : '${candidate.occurrences} places';
    final pages = candidate.pages == 1 ? '1 page' : '${candidate.pages} pages';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  candidate.text,
                  overflow: TextOverflow.ellipsis,
                  style: Zc.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              // What the decision is worth, from the core and not worked out here.
              Text('$places · $pages', style: Zc.tiny.copyWith(color: Zc.ink4)),
            ],
          ),
          const SizedBox(height: 4),
          Text(candidate.why, style: Zc.tiny.copyWith(color: Zc.ink3)),
          const SizedBox(height: 8),
          // Up to three lines, as the document writes them.
          for (final example in candidate.examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                example,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Zc.small.copyWith(color: Zc.ink2, fontFamily: Zc.mono),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Act(
                label: candidate.family ? 'Add as family name' : 'Add as given name',
                primary: true,
                onPressed: bench.busy
                    ? null
                    : () => bench.teachName(candidate.text, family: candidate.family),
              ),
              _Act(
                label: 'Ignore',
                onPressed: bench.busy ? null : () => bench.ignoreCandidate(candidate.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({required this.label, required this.onPressed, this.primary = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return primary
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Zc.river,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label, style: Zc.small.copyWith(color: Colors.white)),
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: Zc.ink,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label, style: Zc.small),
          );
  }
}

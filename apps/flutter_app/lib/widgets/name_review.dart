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

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

class NameReviewPanel extends StatelessWidget {
  const NameReviewPanel({super.key, required this.bench, required this.width, required this.onVault});

  final Workbench bench;
  final double width;

  /// Adding a name writes to the vault, so without one the acts say what they
  /// need and this opens it — the same door, and the same sentence, as the
  /// «Always» button in the review.
  final VoidCallback onVault;

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
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                for (final c in open) ...[
                  _Row(bench: bench, candidate: c),
                  Container(height: 1, color: Zc.lineSoft),
                ],
                YourNames(bench: bench, onVault: onVault),
              ],
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

/// **Your names** — what this device knows because you said so.
///
/// The owner is building Swedish and German lists of his own, and until now
/// there was no plain way to put one in: a name had to appear in a document
/// first, be noticed, and be answered. Two acts here, and a list under them, so
/// a person can see their own library without going looking for it.
///
/// Both acts write to the vault, so both say what they need when there is none
/// — the same button-carries-its-state rule as «Always» in the review, and the
/// same door.
class YourNames extends StatefulWidget {
  const YourNames({super.key, required this.bench, required this.onVault});

  final Workbench bench;
  final VoidCallback onVault;

  @override
  State<YourNames> createState() => _YourNamesState();
}

class _YourNamesState extends State<YourNames> {
  final _text = TextEditingController();
  UserNameKind _kind = UserNameKind.family;
  bool _always = false;
  bool _adding = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _vaultOpen => (widget.bench.snap?.vault ?? VaultState.absent) == VaultState.unlocked;

  String get _needs =>
      (widget.bench.snap?.vault ?? VaultState.absent) == VaultState.locked
          ? 'Unlock the vault'
          : 'Needs a vault';

  /// Fire the act and let the bench say what happened. Nothing here awaits the
  /// core: the bench owns the act, the sentence and the busy flag, and this
  /// panel is rebuilt when it notifies.
  void _add() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    unawaited(widget.bench.addUserName(text, kind: _kind, always: _always));
  }

  Future<void> _import() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Name lists', extensions: ['csv', 'txt']),
      ],
    );
    if (file == null || !mounted) return;
    final csv = await file.readAsString();
    if (!mounted) return;
    unawaited(widget.bench.importUserNames(csv));
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.bench.userNames;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: Zc.lineSoft),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Text('Your names', style: Zc.h2)),
              Text(
                rows.isEmpty ? '' : '${rows.length}',
                style: Zc.tiny.copyWith(color: Zc.ink4),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Names this device knows because you said so. They are kept in your '
            'vault, on this computer.',
            style: Zc.small.copyWith(color: Zc.ink3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Act(
                label: _vaultOpen ? 'Add a name' : 'Add a name · $_needs',
                primary: _vaultOpen,
                onPressed: widget.bench.busy
                    ? null
                    : _vaultOpen
                        ? () => setState(() => _adding = !_adding)
                        : widget.onVault,
              ),
              _Act(
                label: _vaultOpen ? 'Import a list' : 'Import a list · $_needs',
                onPressed: widget.bench.busy ? null : (_vaultOpen ? _import : widget.onVault),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _vaultOpen
                ? 'A list is a CSV with a «name» and a «type» column: given, family, person or company.'
                : 'Your names live in the vault, so adding one needs it open.',
            style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
          ),
          if (_adding && _vaultOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              style: Zc.body,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Zc.paper,
                hintText: 'Lindqvist',
                hintStyle: Zc.body.copyWith(color: Zc.ink4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Zc.line),
                ),
              ),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in UserNameKind.values)
                  _Pick(
                    label: _kindWord(k),
                    on: _kind == k,
                    onTap: () => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Pick(label: 'Suggest', on: !_always, onTap: () => setState(() => _always = false)),
                _Pick(label: 'Always', on: _always, onTap: () => setState(() => _always = true)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _always
                  ? 'Always: protected the moment it appears, in every document.'
                  : 'Suggest: Z marks it and waits for your word.',
              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
            ),
            const SizedBox(height: 8),
            _Act(label: 'Add', primary: true, onPressed: widget.bench.busy ? null : _add),
          ],
          if (widget.bench.namesSaid != null) ...[
            const SizedBox(height: 10),
            Text(widget.bench.namesSaid!, style: Zc.small.copyWith(color: Zc.river)),
          ],
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              _vaultOpen ? 'Nothing yet.' : '',
              style: Zc.small.copyWith(color: Zc.ink4),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: row.text, style: Zc.body.copyWith(fontWeight: FontWeight.w600)),
                            TextSpan(
                              text: '  ${_kindWord(row.kind)}${row.always ? " · always" : ""}',
                              style: Zc.tiny.copyWith(color: Zc.ink4),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Forget «${row.text}»',
                      icon: const Icon(Icons.close, size: 15),
                      color: Zc.ink4,
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.bench.busy
                          ? null
                          : () => unawaited(widget.bench.forgetUserName(row)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

String _kindWord(UserNameKind k) => switch (k) {
      UserNameKind.given => 'given name',
      UserNameKind.family => 'family name',
      UserNameKind.person => 'person',
      UserNameKind.company => 'company',
    };

/// A one-of-these chip, the same shape the send sheet uses for its choices.
class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on ? Zc.river.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: on ? Zc.river : Zc.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Zc.small.copyWith(
            color: on ? Zc.river : Zc.ink3,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

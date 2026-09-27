// The Workspace — the centre of everything.
//
// M7.1 builds the frame: the top bar that says what ground this conversation
// stands on, and the band under it that reports the scan. Both are real: the
// counts are the core's `ScanReport`, and the vault line is the core's own
// `VaultState`, carried inside that report so the two can never disagree.
//
// The two columns arrive in M7.2. Until then each says which milestone fills it,
// which is a placeholder for the *reader* of the code — not mock data on screen.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({
    super.key,
    required this.bench,
    required this.ground,
    required this.onHome,
  });

  final Workbench bench;
  final Ground ground;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bench,
      builder: (context, _) => Scaffold(
        body: Column(
          children: [
            _TopBar(bench: bench, ground: ground, onHome: onHome),
            _Band(bench: bench),
            if (bench.trouble != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Trouble(bench.trouble!),
              ),
            Expanded(child: _Columns(bench: bench)),
          ],
        ),
      ),
    );
  }
}

/// The seven things that change the ground the Workspace stands on. In M7.1 they
/// *report* — each becomes an act in its own milestone, and the behaviour board
/// already says what each must ask before it changes an open document.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.bench, required this.ground, required this.onHome});

  final Workbench bench;
  final Ground ground;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final doc = bench.document;
    final profile = bench.profileId == null
        ? 'Everywhere'
        : ground.profiles.firstWhere(
            (p) => p.id == bench.profileId,
            orElse: () => ProfileRow(id: bench.profileId!, name: bench.profileId!),
          ).name;
    final pack = ground.packs.firstWhere(
      (p) => p.id == bench.packId,
      orElse: () => PackRow(id: bench.packId, label: bench.packId),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(bottom: BorderSide(color: Zc.line)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onHome,
            borderRadius: BorderRadius.circular(9),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Row(
                children: [
                  ZMark(size: 28),
                  SizedBox(width: 10),
                  Text('Z Privacy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Zc.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 22),
          if (doc != null) ...[
            Icon(
              doc.kind == DocumentKind.pdf
                  ? Icons.picture_as_pdf_outlined
                  : doc.kind == DocumentKind.docx
                      ? Icons.article_outlined
                      : Icons.notes_outlined,
              size: 16,
              color: Zc.ink3,
            ),
            const SizedBox(width: 7),
            Text(
              doc.name.isEmpty ? 'Typed text' : doc.name,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Zc.ink),
            ),
            const SizedBox(width: 9),
            Text(
              doc.pages == 1 ? '1 page' : '${doc.pages} pages',
              style: Zc.small.copyWith(color: Zc.ink4),
            ),
          ],
          const Spacer(),
          _Fact(label: 'Profile', value: profile),
          _Fact(label: 'Pack', value: pack.label),
          _Fact(
            label: 'Vault',
            value: switch (bench.report?.vault ?? ground.vault) {
              VaultState.unlocked => 'Unlocked',
              VaultState.locked => 'Locked',
              VaultState.absent => 'None',
            },
            tint: (bench.report?.vault ?? ground.vault) == VaultState.unlocked ? Zc.river : Zc.ink4,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.tint});

  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Eyebrow(label),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tint ?? Zc.ink2),
          ),
        ],
      ),
    );
  }
}

/// «Scanned on import — 7 protected automatically · 2 need your word · 428 normal».
/// Every one of those numbers is `ScanReport`, straight from the core.
class _Band extends StatelessWidget {
  const _Band({required this.bench});

  final Workbench bench;

  @override
  Widget build(BuildContext context) {
    final r = bench.report;
    final locked = (r?.vault ?? VaultState.absent) != VaultState.unlocked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
      decoration: const BoxDecoration(
        color: Zc.clayWash,
        border: Border(bottom: BorderSide(color: Zc.clayEdge)),
      ),
      child: Row(
        children: [
          if (bench.busy) ...[
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: Zc.clayDeep),
            ),
            const SizedBox(width: 10),
            const Text('Scanning…', style: TextStyle(fontSize: 13, color: Zc.clayDeep)),
          ] else if (r == null) ...[
            const Text('Not scanned yet', style: TextStyle(fontSize: 13, color: Zc.clayDeep)),
          ] else ...[
            const Icon(Icons.check, size: 15, color: Zc.clayDeep),
            const SizedBox(width: 8),
            const Text(
              'Scanned on import',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Zc.clayDeep),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '${r.auto} protected automatically · ${r.suggested} need your word · ${r.normal} normal',
                style: const TextStyle(fontSize: 13, color: Zc.clayDeep),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
          // Said out loud, because a locked vault means the app cannot recognise
          // your own people. The core puts the state in the report for this line.
          //
          // Flexible, not a bare Text: this band is the one place where two long
          // sentences meet, and a narrow window must shorten a warning rather
          // than overflow it off the screen where nobody reads it.
          if (locked && r != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(
                  r.vault == VaultState.locked
                      ? 'Vault locked — rules and pack ran, the vault layer did not'
                      : 'No vault — nothing is recognised by name',
                  style: Zc.small.copyWith(color: Zc.amber, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two columns, which are the product's essence and not decoration. M7.1
/// stands them up with their headers and their one hard rule each; M7.2 fills them.
class _Columns extends StatelessWidget {
  const _Columns({required this.bench});

  final Workbench bench;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Side(
            eyebrow: 'Original — local only',
            rule: 'Never sent to AI · Send cannot read this side',
            tint: Zc.ink4,
            child: _pending('M7.2 draws the document here, with its marks'),
          ),
        ),
        Container(width: 1, color: Zc.line),
        Expanded(
          child: _Side(
            eyebrow: 'Safe — AI will receive',
            rule: 'The request itself, not a preview of it',
            tint: Zc.clay,
            child: _pending('M7.2 draws the payload here, built in Rust'),
          ),
        ),
      ],
    );
  }

  Widget _pending(String what) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(what, style: Zc.small.copyWith(color: Zc.ink4), textAlign: TextAlign.center),
        ),
      );
}

class _Side extends StatelessWidget {
  const _Side({required this.eyebrow, required this.rule, required this.tint, required this.child});

  final String eyebrow;
  final String rule;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(eyebrow, color: tint),
              const SizedBox(height: 4),
              Text(rule, style: Zc.tiny.copyWith(letterSpacing: 0)),
            ],
          ),
        ),
        Container(height: 1, color: Zc.lineSoft),
        Expanded(child: child),
      ],
    );
  }
}

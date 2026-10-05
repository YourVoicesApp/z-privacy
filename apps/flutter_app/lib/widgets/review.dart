// Review — the gate before Send.
//
// Three groups, because the boards insist the difference is visible: what the
// app protected **automatically**, what it **suggests** and is still waiting on,
// and what **you** protected by hand. A list that mixed them would hide the one
// question that matters: which of these did I decide?
//
// Every row carries the rule that flagged it and where it sits. «Page 17» is the
// core's own `Place`, kept through protection — the review list can still jump
// there after everything has been replaced.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';

class ReviewPanel extends StatelessWidget {
  const ReviewPanel({super.key, required this.bench, required this.width, required this.onVault});

  final Workbench bench;

  /// Where «Always» sends a person who has no vault yet. The answer row needs
  /// it, so the panel carries it: a button that cannot do what it says must at
  /// least open the door that would let it.
  final VoidCallback onVault;

  /// Set by the Workspace from the window's width: two columns must stay
  /// readable, and a panel that squeezes them off the screen is worse than a
  /// narrow panel.
  final double width;

  @override
  Widget build(BuildContext context) {
    final open = bench.suggested;

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
          Expanded(
            child: bench.walking && open.isNotEmpty
                ? _Walk(bench: bench, onVault: onVault)
                : _List(bench: bench, onVault: onVault),
          ),
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
                const Eyebrow('Review'),
                const SizedBox(height: 4),
                Text(
                  open == 0
                      ? 'Nothing is waiting for you.'
                      : open == 1
                      ? 'One thing is waiting for your word.'
                      : '$open things are waiting for your word.',
                  style: Zc.small.copyWith(
                    color: open == 0 ? Zc.ink3 : Zc.amber,
                    fontWeight: open == 0 ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (open > 0)
            IconButton(
              tooltip: bench.walking
                  ? 'Show the whole list'
                  : 'Walk them one at a time',
              icon: Icon(
                bench.walking ? Icons.list : Icons.directions_walk,
                size: 18,
              ),
              color: Zc.ink3,
              onPressed: () => bench.openReview(walk: !bench.walking),
            ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, size: 18),
            color: Zc.ink3,
            onPressed: bench.closeReview,
          ),
        ],
      ),
    );
  }
}

/// The whole list, in its three groups.
class _List extends StatelessWidget {
  const _List({required this.bench, required this.onVault});

  final Workbench bench;
  final VoidCallback onVault;

  @override
  Widget build(BuildContext context) {
    final suggested = bench.suggested;
    final automatic = bench.automatic;
    final byHand = bench.byHand;

    if (bench.findings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'The scan found nothing in this document.',
          style: Zc.small,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        if (suggested.isNotEmpty) ...[
          _GroupTitle('Waiting for your word', suggested.length, Zc.amber),
          for (final f in suggested)
            _Row(bench: bench, finding: f, answerable: true, onVault: onVault),
          const SizedBox(height: 16),
        ],
        if (automatic.isNotEmpty) ...[
          _GroupTitle('Protected automatically', automatic.length, Zc.clay),
          for (final f in automatic)
            _Row(bench: bench, finding: f, answerable: false, onVault: onVault),
          const SizedBox(height: 16),
        ],
        if (byHand.isNotEmpty) ...[
          _GroupTitle('Decided by you', byHand.length, Zc.ink3),
          for (final f in byHand)
            _Row(bench: bench, finding: f, answerable: false, onVault: onVault),
        ],
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title, this.count, this.tint);

  final String title;
  final int count;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Eyebrow(title, color: tint),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One finding: what it is, why it was flagged, where it sits, and — when it is
/// still open — the three answers.
class _Row extends StatelessWidget {
  const _Row({
    required this.bench,
    required this.finding,
    required this.answerable,
    required this.onVault,
  });

  final Workbench bench;
  final Finding finding;
  final bool answerable;
  final VoidCallback onVault;

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
                  'found by ${sourceName(finding.source).toLowerCase()}',
                  sourceTint(finding.source),
                ),
                if (finding.decided) _Tag('you decided', Zc.clay),
                if (finding.place != null)
                  _Tag(
                    'Page ${finding.place!.page} · ¶${finding.place!.paragraph}',
                    Zc.ink4,
                  ),
                // What one press will settle. The core counts the places; this
                // line only reads the number, and says nothing when a value
                // stands once — «in 1 places» is noise, and wrong English.
                if (finding.occurrences > 1)
                  _Tag('in ${finding.occurrences} places', Zc.clay),
                if (finding.entities.length > 1)
                  _Tag(
                    '${finding.entities.length} identities claim it',
                    Zc.river,
                  ),
              ],
            ),
            if (answerable) ...[
              const SizedBox(height: 10),
              _Answers(bench: bench, finding: finding, onVault: onVault),
            ],
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

/// The three answers. «Skip» is offered and is honest about what it costs: the
/// item stays in the clear and still counts, so Send stays shut. There is no
/// fourth button that sends anyway — that one was deleted from the product.
class _Answers extends StatelessWidget {
  const _Answers({required this.bench, required this.finding, required this.onVault});

  final Workbench bench;
  final Finding finding;
  final VoidCallback onVault;

  @override
  Widget build(BuildContext context) {
    Widget one(
      String label,
      FindingAnswer a,
      Color tint, {
      bool filled = false,
    }) => Material(
      color: filled ? tint : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
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

    Widget remember(String label, Scope scope) => Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () => bench.teachException(finding.id, scope),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Zc.line),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Zc.ink3,
            ),
          ),
        ),
      ),
    );

    // «Always» writes to the vault, so without an open vault the core refuses
    // it — correctly, and into `bench.trouble`, which the Workspace draws once
    // at the **top of the window**, under the band. The owner pressed this
    // button in the right-hand panel and saw nothing happen, because the
    // sentence was four hundred pixels away and above the fold.
    //
    // So the button carries its own state: it says what it needs, and the
    // press opens the door that would satisfy it. Nothing is refused that was
    // not asked for.
    // Three states, two sentences, because «there is no vault» and «the vault
    // is locked» ask different things of a person — the same distinction the
    // core's two refusals have always made.
    final vault = bench.snap?.vault ?? VaultState.absent;
    final vaultOpen = vault == VaultState.unlocked;
    final needs = vault == VaultState.locked ? 'Always · unlock the vault' : 'Always · needs a vault';
    Widget always() => Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: vaultOpen ? () => bench.answer(finding.id, FindingAnswer.always) : onVault,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: vaultOpen ? Zc.line : Zc.lineSoft),
          ),
          child: Text(
            vaultOpen ? 'Always' : needs,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: vaultOpen ? Zc.river : Zc.ink4,
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            one('Protect', FindingAnswer.protect, Zc.clay, filled: true),
            always(),
            one('Not sensitive', FindingAnswer.notSensitive, Zc.ink3),
            if (bench.profileId != null)
              remember('Not sensitive in profile', Scope.profile),
            remember('Not sensitive everywhere', Scope.always),
            one('Skip', FindingAnswer.skip, Zc.ink4),
          ],
        ),
        const SizedBox(height: 6),
        // What «Always» is, in one sentence, beside the button rather than in
        // a document nobody opens.
        Text(
          vaultOpen
              ? 'Always: protect this value in every document from now on.'
              : vault == VaultState.locked
              ? 'Always: protect this value in every document from now on — it is kept in '
                    'the vault, which is locked.'
              : 'Always: protect this value in every document from now on — it is kept in '
                    'the vault, so it needs one.',
          style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
        ),
      ],
    );
  }
}

/// WALKING — one at a time, with the sentence it lives in, because a word out of
/// its sentence is not enough to decide about.
class _Walk extends StatelessWidget {
  const _Walk({required this.bench, required this.onVault});

  final Workbench bench;
  final VoidCallback onVault;

  @override
  Widget build(BuildContext context) {
    final open = bench.suggested;
    final current = bench.focusedFinding ?? open.first;
    final at = open.indexWhere((f) => f.id == current.id);
    final doc = bench.document;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Text(
              '${at < 0 ? 1 : at + 1} of ${open.length}',
              style: Zc.small.copyWith(color: Zc.ink4),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              color: Zc.ink3,
              onPressed: at > 0 ? () => bench.focusOn(open[at - 1].id) : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              color: Zc.ink3,
              onPressed: at >= 0 && at < open.length - 1
                  ? () => bench.focusOn(open[at + 1].id)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (doc != null)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: Zc.panel(fill: Zc.paper, edge: Zc.lineSoft, radius: 10),
            child: Text.rich(
              _sentence(doc.text, current.span),
              style: Zc.document.copyWith(fontSize: 13.5),
            ),
          ),
        const SizedBox(height: 12),
        Text(current.reason, style: Zc.small),
        const SizedBox(height: 6),
        Row(
          children: [
            _Tag(kindName(current.kind), Zc.ink4),
            const SizedBox(width: 6),
            _Tag(
              'found by ${sourceName(current.source).toLowerCase()}',
              sourceTint(current.source),
            ),
            if (current.place != null) ...[
              const SizedBox(width: 6),
              _Tag(
                'Page ${current.place!.page} · ¶${current.place!.paragraph}',
                Zc.ink4,
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _Answers(bench: bench, finding: current, onVault: onVault),
        const SizedBox(height: 10),
        Text(
          'Skip leaves it in the clear and still counted — skipping is not deciding.',
          style: Zc.tiny.copyWith(letterSpacing: 0),
        ),
      ],
    );
  }

  /// The sentence around a finding, with the finding itself standing out. Cut on
  /// sentence marks and line ends; if no boundary is near, a window of characters.
  TextSpan _sentence(String text, Span span) {
    const reach = 180;
    var from = span.start;
    while (from > 0 &&
        span.start - from < reach &&
        !'.!?\n'.contains(text[from - 1])) {
      from--;
    }
    var to = span.end;
    while (to < text.length &&
        to - span.end < reach &&
        !'.!?\n'.contains(text[to])) {
      to++;
    }
    if (to < text.length && to - span.end < reach) to++;

    return TextSpan(
      children: [
        if (from > 0)
          const TextSpan(
            text: '… ',
            style: TextStyle(color: Zc.ink4),
          ),
        TextSpan(text: text.substring(from, span.start)),
        TextSpan(
          text: text.substring(span.start, span.end),
          style: const TextStyle(
            backgroundColor: Zc.amberWash,
            color: Zc.amber,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: text.substring(span.end, to)),
        if (to < text.length)
          const TextSpan(
            text: ' …',
            style: TextStyle(color: Zc.ink4),
          ),
      ],
    );
  }
}

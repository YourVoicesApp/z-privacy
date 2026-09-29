// «Why is this protected?» — and, if the answer is «because you taught me»,
// the way to make it forget.
//
// The owner's ninth question, 28 September. «Source: Vault» is technically true
// and answers nobody; this is the answer a person can judge. And the rule it
// serves is the one he set for this phase:
//
//   Everything Z Privacy learns from the user must be **visible, explainable,
//   editable and forgettable**.
//
// Forgetting shows its effect before it happens, because a button that says
// «forget» has to be trusted, and trust needs a number.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/core/messages.dart';

class WhySheet extends StatefulWidget {
  const WhySheet({
    super.key,
    required this.why,
    required this.word,
    required this.span,
    required this.onChanged,
    required this.onUnprotect,
  });

  final Explanation why;
  final String word;
  final Span span;

  /// Removing the protection here — a different act from forgetting, offered
  /// under its own name.
  final Future<void> Function(Span span) onUnprotect;

  /// Called when something was forgotten, so the document can be scanned again
  /// with the knowledge gone.
  final Future<void> Function() onChanged;

  @override
  State<WhySheet> createState() => _WhySheetState();
}

class _WhySheetState extends State<WhySheet> {
  bool _showSpellings = false;
  String? _trouble;

  @override
  Widget build(BuildContext context) {
    final why = widget.why;
    final taught = why.entity != null && why.valueId != null;
    // A **rule** the person taught is also learned knowledge, but it has no
    // entity or value — so the sheet used to fall through to «nothing was
    // learned from this», three lines under a headline saying they taught it.
    final taughtRule = why.headline.contains('taught Z Privacy this rule');

    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why is this protected?', style: Zc.h2),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: Zc.panel(fill: Zc.card, radius: 9),
                child: Text(widget.word, style: Zc.document, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 18),

              // The headline — a sentence, not a category.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 16, color: taught ? Zc.river : Zc.clay),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      why.headline,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: taught ? Zc.river : Zc.clayDeep,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final line in why.because)
                Padding(
                  padding: const EdgeInsets.only(left: 25, bottom: 4),
                  child: Text(line, style: Zc.small),
                ),

              const SizedBox(height: 18),
              _Row('What it is', kindName(why.kind)),
              _Row('Where it applies', why.applies),
              _Row('Decided by', why.decided ? 'You' : 'Z Privacy, on its own'),
              if (why.learnedAt > BigInt.zero)
                _Row('Taught on', _day(why.learnedAt.toInt())),
              _Row('Token', why.token, mono: true),

              if (why.aliases.isNotEmpty) ...[
                const SizedBox(height: 8),
                // Other spellings are the same secret, so they wait to be asked
                // for — the same habit as everywhere else in this app.
                InkWell(
                  onTap: () => setState(() => _showSpellings = !_showSpellings),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(_showSpellings ? Icons.expand_less : Icons.expand_more,
                            size: 16, color: Zc.river),
                        const SizedBox(width: 5),
                        Text(
                          plural(why.aliases.length, 'other spelling'),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Zc.river),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showSpellings)
                  Padding(
                    padding: const EdgeInsets.only(left: 21, top: 4),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        for (final a in why.aliases)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Zc.riverWash,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(a, style: const TextStyle(fontSize: 12.5, color: Zc.river)),
                          ),
                      ],
                    ),
                  ),
              ],

              if (_trouble != null) ...[const SizedBox(height: 12), Trouble(_trouble!)],
              const SizedBox(height: 20),
              // Wrap: three buttons and a long label do not fit a narrow sheet,
              // and a button pushed off the edge is a choice nobody can make.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  ZButton(label: 'Close', onPressed: () => Navigator.of(context).pop()),
                  ZButton(
                    label: 'Remove protection',
                    onPressed: () async {
                      await widget.onUnprotect(widget.span);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  if (taught)
                    ZButton(
                      label: 'Forget here',
                      tint: Zc.amber,
                      onPressed: () => _forget(everywhere: false),
                    ),
                  if (taught)
                    ZButton(
                      label: 'Forget everywhere',
                      tint: Zc.amber,
                      onPressed: () => _forget(everywhere: true),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // The two acts, named apart. The commonest way to lose a user's
              // trust here would be to let one quietly do the other.
              Text(
                taught || taughtRule
                    ? 'Remove protection changes this document. Forget erases what Z Privacy '
                        'learned, and leaves this document exactly as it is.'
                    : 'Remove protection changes this document. Nothing was learned from this, '
                        'so there is nothing to forget.',
                style: Zc.tiny.copyWith(letterSpacing: 0),
              ),
              if (taughtRule) ...[
                const SizedBox(height: 10),
                Text(
                  'The rule itself is kept in your vault. Forget it in '
                  'Z Vault → My Privacy Rules → Rules I taught.',
                  style: Zc.tiny.copyWith(letterSpacing: 0),
                ),
              ],
              if (!taught && !taughtRule) ...[
                const SizedBox(height: 10),
                Text(
                  why.decided
                      ? 'Nothing was learned from this — you protected it here, and Undo takes '
                          'it back.'
                      : 'Nothing was learned from this. A rule recognised the shape, and no '
                          'record of it was kept.',
                  style: Zc.tiny.copyWith(letterSpacing: 0),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _forget({required bool everywhere}) async {
    final why = widget.why;
    final e = why.entity;
    final v = why.valueId;
    if (e == null || v == null) return;

    ForgetPlan plan;
    try {
      plan = await z.forgetPlan(entity: e, valueId: v, everywhere: everywhere);
    } on ApiError catch (err) {
      setState(() => _trouble = humanMessage(err));
      return;
    }
    if (!mounted) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => _ForgetSheet(plan: plan, everywhere: everywhere),
    );
    if (sure != true || !mounted) return;

    try {
      final done = await z.forgetValue(entity: e, valueId: v, everywhere: everywhere);
      // The core reports what still recognises it. It must be nothing — and if
      // it is not, the user is told rather than reassured.
      // After «everywhere» nothing may still know it. After a scoped forget
      // another profile legitimately might, and the preview already said so.
      if (everywhere && done.stillKnownBy.isNotEmpty && mounted) {
        setState(() => _trouble =
            'Forgotten, but ${done.stillKnownBy.join(", ")} still recognises it. '
            'Please tell us — this should not be possible.');
        return;
      }
      // `onChanged` looks again; it does **not** take anything back. A rescan
      // never removes a protection (task 037) — which is what makes it safe to
      // call here at all.
      await widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (err) {
      if (mounted) setState(() => _trouble = humanMessage(err));
    }
  }

  /// A date from seconds. The fact is the timestamp; this is only how it reads.
  String _day(int seconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// What forgetting will take away — shown before it happens, with its numbers.
class _ForgetSheet extends StatelessWidget {
  const _ForgetSheet({required this.plan, required this.everywhere});

  final ForgetPlan plan;
  final bool everywhere;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Forget «${plan.what}»?', style: Zc.h2),
              const SizedBox(height: 14),
              const Eyebrow('This will remove'),
              const SizedBox(height: 7),
              _Line(plural(plan.values, 'protected value')),
              if (plan.aliases > 0) _Line(plural(plan.aliases, 'spelling')),
              if (plan.identities > 0)
                _Line('${plural(plan.identities, "identity", "identities")} left holding nothing'),
              for (final p in plan.profiles) _Line('its place in $p'),
              const SizedBox(height: 16),
              const Eyebrow('It will NOT change'),
              const SizedBox(height: 7),
              for (final k in plan.keeps) _Line(k, keeps: true),
              const SizedBox(height: 10),
              // What forgetting does, and the two things it does not do.
              //
              // This said «nothing kept on this device will recognise the value
              // again», which was an overclaim: F-02 means an older valid vault
              // copy can be restored and bring the value back. The owner's
              // wording of 29 September, verbatim — it neither frightens nor
              // promises what we do not hold.
              Text(
                plan.stillKnownBy.isEmpty
                    ? 'Forget removes this value from the current vault and from future '
                        'recognition by that vault. It does not remove protection already '
                        'applied in this document, and an older valid copy of the vault may '
                        'restore the value later.'
                    : '${plan.stillKnownBy.join(", ")} would still recognise it — forgetting here '
                        'does not reach into another client\u2019s records.',
                style: Zc.tiny.copyWith(
                  letterSpacing: 0,
                  color: plan.stillKnownBy.isEmpty ? Zc.ink4 : Zc.amber,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ZButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
                  const Spacer(),
                  ZButton(
                    label: everywhere ? 'Forget everywhere' : 'Forget',
                    filled: true,
                    tint: Zc.amber,
                    onPressed: () => Navigator.of(context).pop(true),
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

class _Line extends StatelessWidget {
  const _Line(this.text, {this.keeps = false});

  final String text;
  final bool keeps;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(keeps ? Icons.remove : Icons.close, size: 14, color: keeps ? Zc.ink4 : Zc.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: Zc.small.copyWith(color: keeps ? Zc.ink3 : Zc.ink2)),
            ),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text(label, style: Zc.small.copyWith(color: Zc.ink4))),
            Expanded(
              child: SelectableText(
                value,
                style: mono
                    ? const TextStyle(fontFamily: Zc.mono, fontSize: 12, color: Zc.clayDeep)
                    : Zc.small.copyWith(color: Zc.ink),
              ),
            ),
          ],
        ),
      );
}

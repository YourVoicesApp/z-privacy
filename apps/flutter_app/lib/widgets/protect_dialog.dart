// The Protect dialog, and the five states of the button that opens it.
//
// The behaviour board's rule is the one that shaped this file: «the mistake in
// this app will not be a colour; it will be what happens on the press.» So the
// state is not decided here — it is read off `SelectionView`, which the core
// computes with the same code that would do the protecting. A widget that works
// out for itself whether something is already protected will eventually disagree
// with the core, and the user will be the one who finds out.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';

/// The five states, named as the board names them.
enum ProtectState { disabled, ready, known, asks, snaps }

ProtectState protectStateOf(SelectionView? v) {
  if (v == null || v.empty) return ProtectState.disabled;
  if (v.protectedAs != null) return ProtectState.known;
  if (v.snapsTo.isNotEmpty) return ProtectState.snaps;
  if (v.entities.isNotEmpty) return ProtectState.asks;
  return ProtectState.ready;
}

/// What the user chose in the dialog.
class ProtectWish {
  const ProtectWish({required this.scope, required this.kind, required this.allMatches});

  final Scope scope;
  final Kind kind;
  final bool allMatches;
}

class ProtectDialog extends StatefulWidget {
  const ProtectDialog({super.key, required this.view, required this.selectedText});

  final SelectionView view;
  final String selectedText;

  @override
  State<ProtectDialog> createState() => _ProtectDialogState();
}

class _ProtectDialogState extends State<ProtectDialog> {
  late Scope _scope;
  late Kind _kind;
  late bool _all;

  @override
  void initState() {
    super.initState();
    // One appearance and one place are the same thing, so the scope starts at
    // «this conversation» only when there is more than one place to cover.
    _scope = widget.view.matches > 1 ? Scope.conversation : Scope.once;
    _kind = widget.view.kind;
    _all = widget.view.matches > 1;
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final asks = v.entities.isNotEmpty;

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
              const Text('Protect this', style: Zc.h2),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: Zc.panel(fill: Zc.card, radius: 9),
                child: Text(widget.selectedText, style: Zc.document, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
              if (asks) ...[
                const SizedBox(height: 14),
                // ASKS. The vault already knows this value under an identity, so
                // the first thing offered is the one that keeps the same token —
                // two identities for one thing is how a model starts seeing two
                // different people.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: Zc.panel(fill: Zc.riverWash, edge: Zc.river.withValues(alpha: 0.3), radius: 9),
                  child: Text(
                    v.entities.length == 1
                        ? 'The vault knows this as ${v.entities.first}. Protecting it here keeps that '
                            'identity’s token, so the model reads one person and not two.'
                        : 'Two identities claim this: ${v.entities.join(" and ")}. Protect it here and '
                            'the app will not choose between them — open the vault to settle it.',
                    style: Zc.small.copyWith(color: Zc.river),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Eyebrow('What is it'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final k in Kind.values)
                    _Pill(
                      label: kindName(k),
                      chosen: _kind == k,
                      // The pack's guess is marked, so a user can see that the
                      // app had an opinion and that they are free to overrule it.
                      hint: k == v.kind && k != Kind.custom,
                      onTap: () => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'The kind travels inside the token, on purpose: the model must know it is '
                'answering about a bank account and not a name.',
                style: Zc.tiny.copyWith(letterSpacing: 0),
              ),
              const SizedBox(height: 18),
              const Eyebrow('How far'),
              const SizedBox(height: 8),
              _ScopeRow(
                scope: Scope.once,
                chosen: _scope,
                title: 'Once',
                what: 'This place in this document only.',
                onTap: (s) => setState(() => _scope = s),
              ),
              _ScopeRow(
                scope: Scope.conversation,
                chosen: _scope,
                title: 'This conversation',
                what: 'Every appearance here, under one token.',
                onTap: (s) => setState(() => _scope = s),
              ),
              _ScopeRow(
                scope: Scope.always,
                chosen: _scope,
                title: 'Always',
                what: 'Kept in the vault and found by itself from now on.',
                onTap: (s) => setState(() => _scope = s),
              ),
              if (v.matches > 1) ...[
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => setState(() => _all = !_all),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _all,
                          onChanged: (on) => setState(() => _all = on ?? false),
                          activeColor: Zc.clay,
                        ),
                        Expanded(
                          child: Text(
                            'Protect all ${v.matches} matches — all of them get the same token, '
                            'otherwise the model reads them as different people.',
                            style: Zc.small,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  ZButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  ZButton(
                    label: 'Protect',
                    filled: true,
                    onPressed: () => Navigator.of(context).pop(
                      ProtectWish(scope: _scope, kind: _kind, allMatches: _all),
                    ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.chosen, required this.onTap, this.hint = false});

  final String label;
  final bool chosen;
  final bool hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chosen ? Zc.clayWash : Zc.card,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: chosen ? Zc.clayEdge : Zc.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint) ...[
                const Icon(Icons.auto_awesome, size: 11, color: Zc.clay),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: chosen ? FontWeight.w600 : FontWeight.w500,
                  color: chosen ? Zc.clayDeep : Zc.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.scope,
    required this.chosen,
    required this.title,
    required this.what,
    required this.onTap,
  });

  final Scope scope;
  final Scope chosen;
  final String title;
  final String what;
  final void Function(Scope) onTap;

  @override
  Widget build(BuildContext context) {
    final on = scope == chosen;
    return InkWell(
      onTap: () => onTap(scope),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: on ? Zc.clayWash : Zc.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: on ? Zc.clayEdge : Zc.line),
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: on ? Zc.clay : Zc.ink4,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? Zc.clayDeep : Zc.ink,
                    ),
                  ),
                  Text(what, style: Zc.small.copyWith(color: Zc.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

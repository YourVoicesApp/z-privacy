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
  const ProtectWish({required this.scope, required this.kind});

  final Scope scope;
  final Kind kind;
}

class ProtectDialog extends StatefulWidget {
  const ProtectDialog({
    super.key,
    required this.view,
    required this.selectedText,
    required this.vault,
    required this.inAProfile,
    required this.profileName,
  });

  final SelectionView view;
  final String selectedText;

  /// The two widest scopes write to the vault, so they need one open. A closed
  /// door says why it is closed — the boards' rule for every disabled control.
  final VaultState vault;
  final bool inAProfile;
  final String profileName;

  @override
  State<ProtectDialog> createState() => _ProtectDialogState();
}

class _ProtectDialogState extends State<ProtectDialog> {
  late Scope _scope;
  late Kind _kind;

  @override
  void initState() {
    super.initState();
    // One appearance and one place are the same thing, so the scope starts at
    // «this conversation» only when there is more than one place to cover.
    _scope = widget.view.matches > 1 ? Scope.conversation : Scope.once;
    _kind = widget.view.kind;
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
                  // The list comes from the core. A screen that walked
                  // `Kind.values` would be deciding what kinds exist.
                  for (final row in kindRows)
                    _Pill(
                      label: row.label,
                      chosen: _kind == row.kind,
                      // The pack's guess is marked, so a user can see that the
                      // app had an opinion and that they are free to overrule it.
                      hint: row.kind == v.kind && row.kind != Kind.custom,
                      onTap: () => setState(() => _kind = row.kind),
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
              // Four steps, each wider than the last. The first two are about
              // this conversation; the last two are promises about tomorrow,
              // and a promise about tomorrow has to be written in the vault.
              _ScopeRow(
                scope: Scope.once,
                chosen: _scope,
                title: 'Just here',
                what: 'This one place. The same words elsewhere are left alone.',
                onTap: (s) => setState(() => _scope = s),
              ),
              _ScopeRow(
                scope: Scope.conversation,
                chosen: _scope,
                title: 'This conversation',
                what: v.matches > 1
                    ? 'All ${v.matches} places here, under one token. Gone when this '
                        'conversation is.'
                    : 'Every appearance here, under one token. Gone when this conversation is.',
                onTap: (s) => setState(() => _scope = s),
              ),
              _ScopeRow(
                scope: Scope.profile,
                chosen: _scope,
                title: 'Remember for ${widget.profileName}',
                what: widget.inAProfile
                    ? 'Kept in the vault under this client, so their next document finds it '
                        'by itself — and no other client\u2019s does.'
                    : 'This conversation is not in a profile, so there is no client to '
                        'remember it for.',
                enabled: widget.inAProfile && widget.vault == VaultState.unlocked,
                why: !widget.inAProfile
                    ? 'open a profile first'
                    : 'the vault is closed, and this is kept in the vault',
                onTap: (s) => setState(() => _scope = s),
              ),
              _ScopeRow(
                scope: Scope.always,
                chosen: _scope,
                title: 'Remember everywhere',
                what: 'Kept in the vault for every client, and found by itself from now on.',
                enabled: widget.vault == VaultState.unlocked,
                why: 'the vault is closed, and this is kept in the vault',
                onTap: (s) => setState(() => _scope = s),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ZButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  ZButton(
                    label: 'Protect',
                    filled: true,
                    onPressed: () => Navigator.of(context).pop(
                      ProtectWish(scope: _scope, kind: _kind),
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
    this.enabled = true,
    this.why,
  });

  final Scope scope;
  final Scope chosen;
  final String title;
  final String what;
  final void Function(Scope) onTap;
  final bool enabled;

  /// Why it cannot be chosen. A greyed row with no reason is the commonest way
  /// an app lies about what it can do.
  final String? why;

  @override
  Widget build(BuildContext context) {
    final on = scope == chosen && enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
      onTap: enabled ? () => onTap(scope) : null,
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
                  if (!enabled && why != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        why!,
                        style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.amber),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

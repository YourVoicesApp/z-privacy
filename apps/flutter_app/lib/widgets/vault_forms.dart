// The forms of the vault: the key, an identity, a value, a spelling, a profile.
//
// One habit runs through all of them: **the screen never holds a value.** A
// field is filled from `reveal_value` when the user asks to edit, the edit goes
// back through the core, and the list is read again rather than patched. That is
// slower to write and impossible to get subtly wrong.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';

/// Making a vault, opening one, or changing its passphrase.
class VaultKeyForm extends StatefulWidget {
  const VaultKeyForm({
    super.key,
    required this.ground,
    required this.creating,
    required this.onDone,
    this.changing = false,
  });

  final Ground ground;
  final bool creating;
  final bool changing;
  final VoidCallback onDone;

  @override
  State<VaultKeyForm> createState() => _VaultKeyFormState();
}

class _VaultKeyFormState extends State<VaultKeyForm> {
  final _one = TextEditingController();
  final _two = TextEditingController();
  String? _trouble;
  bool _busy = false;

  @override
  void dispose() {
    _one.dispose();
    _two.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsTwo = widget.creating || widget.changing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.changing) ...[
          const Text('Change the passphrase', style: Zc.h2),
          const SizedBox(height: 6),
          Text(
            'Only 32 bytes are re-wrapped — the vault itself is not decrypted and not '
            'rewritten. Everything in it stays exactly where it is.',
            style: Zc.small,
          ),
          const SizedBox(height: 16),
        ],
        _field(widget.changing ? 'Current passphrase' : 'Passphrase', _one),
        if (needsTwo) ...[
          const SizedBox(height: 10),
          _field(widget.changing ? 'New passphrase' : 'Again', _two),
        ],
        if (widget.creating) ...[
          const SizedBox(height: 7),
          Text(
            'There is no way back. Nobody holds a copy of this, and no reset exists — '
            'the passphrase never leaves this device and nothing on our side could '
            'recover the vault without it.',
            style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.amber),
          ),
        ],
        if (_trouble != null) ...[const SizedBox(height: 12), Trouble(_trouble!)],
        const SizedBox(height: 14),
        ZButton(
          label: _busy
              ? 'Working…'
              : widget.changing
                  ? 'Change it'
                  : widget.creating
                      ? 'Create the vault'
                      : 'Unlock',
          filled: true,
          onPressed: _busy ? null : _go,
        ),
      ],
    );
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _trouble = null;
    });
    String? bad;
    try {
      if (widget.changing) {
        await z.vaultChangePassphrase(old: _one.text, replacement: _two.text);
      } else if (widget.creating) {
        if (_one.text != _two.text) {
          bad = 'The two passphrases are not the same.';
        } else if (_one.text.trim().length < 8) {
          bad = 'A vault passphrase should be long enough to be worth having.';
        } else {
          await z.vaultCreateWithPassphrase(passphrase: _one.text);
        }
      } else {
        final out = await z.vaultUnlockWithPassphrase(passphrase: _one.text);
        if (out is VaultUnlockOutcome_WrongPassphrase) bad = 'That is not the passphrase.';
      }
    } on ApiError catch (e) {
      bad = e.toString();
    }
    await widget.ground.refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _trouble = bad;
      if (bad == null) {
        _one.clear();
        _two.clear();
      }
    });
    if (bad == null) {
      widget.onDone();
      if (widget.changing && context.mounted) Navigator.of(context).maybePop();
    }
  }

  Widget _field(String label, TextEditingController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: 5),
          TextField(
            controller: c,
            obscureText: true,
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Zc.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Zc.line),
              ),
            ),
          ),
        ],
      );
}

/// A new identity: what sort of thing it is, what to call it, and where it lives.
class EntityForm extends StatefulWidget {
  const EntityForm({super.key, required this.ground});

  final Ground ground;

  @override
  State<EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<EntityForm> {
  final _label = TextEditingController();
  EntityKind _kind = EntityKind.client;
  String? _profile;
  String? _trouble;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('A new identity', style: Zc.h2),
              const SizedBox(height: 6),
              Text(
                'An identity is how a person thinks — «Client Nordstern» — and the values '
                'inside it are what the scanner matches.',
                style: Zc.small,
              ),
              const SizedBox(height: 18),
              const Eyebrow('Name'),
              const SizedBox(height: 6),
              TextField(
                controller: _label,
                autofocus: true,
                decoration: _box('Client Nordstern'),
              ),
              const SizedBox(height: 16),
              const Eyebrow('Sort'),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final k in EntityKind.values)
                    _Pick(
                      label: entityKindLabel(k),
                      on: _kind == k,
                      onTap: () => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Eyebrow('Loaded in'),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _Pick(label: 'Everywhere', on: _profile == null, onTap: () => setState(() => _profile = null)),
                  for (final p in widget.ground.profiles)
                    _Pick(label: p.name, on: _profile == p.id, onTap: () => setState(() => _profile = p.id)),
                ],
              ),
              if (_trouble != null) ...[const SizedBox(height: 12), Trouble(_trouble!)],
              const SizedBox(height: 20),
              Row(
                children: [
                  ZButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  ZButton(
                    label: 'Create',
                    filled: true,
                    onPressed: () async {
                      try {
                        final id = await z.createEntity(
                          kind: _kind,
                          label: _label.text,
                          profileId: _profile,
                        );
                        if (context.mounted) Navigator.of(context).pop(id);
                      } on ApiError catch (e) {
                        setState(() => _trouble = e.toString());
                      }
                    },
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

/// A value inside an identity — new, or an existing one opened for editing.
class ValueForm extends StatefulWidget {
  const ValueForm({super.key, required this.entity, this.existing});

  final int entity;

  /// When set, the form opens with the real value in it: editing a value means
  /// seeing it, and the core is asked for it the same way Reveal asks.
  final ValueRow? existing;

  @override
  State<ValueForm> createState() => _ValueFormState();
}

class _ValueFormState extends State<ValueForm> {
  final _text = TextEditingController();
  Kind _kind = Kind.person;
  Policy _policy = Policy.always;
  String? _trouble;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _kind = e.kind;
      _policy = e.policy;
      _loading = true;
      _fill(e);
    } else if (kindRows.isNotEmpty) {
      _kind = kindRows.first.kind;
    }
  }

  Future<void> _fill(ValueRow row) async {
    try {
      final shown = await z.revealValue(entity: widget.entity, valueId: row.id);
      if (mounted) {
        setState(() {
          _text.text = shown.value;
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _trouble = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.existing == null ? 'A new value' : 'Edit this value', style: Zc.h2),
              const SizedBox(height: 16),
              const Eyebrow('The value'),
              const SizedBox(height: 6),
              TextField(
                controller: _text,
                autofocus: widget.existing == null,
                enabled: !_loading,
                style: Zc.document.copyWith(fontSize: 14),
                decoration: _box(_loading ? 'reading it from the vault…' : 'Nordstern Consulting GmbH'),
              ),
              const SizedBox(height: 16),
              const Eyebrow('What it is'),
              const SizedBox(height: 7),
              // From the core's list, never from a switch here.
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final row in kindRows)
                    _Pick(label: row.label, on: _kind == row.kind, onTap: () => setState(() => _kind = row.kind)),
                ],
              ),
              const SizedBox(height: 16),
              const Eyebrow('How to treat it'),
              const SizedBox(height: 7),
              _PolicyRow(
                policy: Policy.always,
                chosen: _policy,
                title: 'Always protect',
                what: 'Found by itself and replaced, with no question.',
                onTap: (p) => setState(() => _policy = p),
              ),
              _PolicyRow(
                policy: Policy.suggest,
                chosen: _policy,
                title: 'Suggest',
                what: 'Found, and put to you before anything is sent.',
                onTap: (p) => setState(() => _policy = p),
              ),
              _PolicyRow(
                policy: Policy.manual,
                chosen: _policy,
                title: 'Keep, do not hunt',
                what: 'Kept so its spellings and its token stay stable — but not looked for.',
                onTap: (p) => setState(() => _policy = p),
              ),
              if (_trouble != null) ...[const SizedBox(height: 12), Trouble(_trouble!)],
              const SizedBox(height: 20),
              Row(
                children: [
                  ZButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  ZButton(
                    label: 'Save',
                    filled: true,
                    onPressed: _loading
                        ? null
                        : () async {
                            try {
                              await z.setValue(
                                entity: widget.entity,
                                valueId: widget.existing?.id,
                                kind: _kind,
                                text: _text.text,
                                policy: _policy,
                              );
                              if (context.mounted) Navigator.of(context).pop(true);
                            } on ApiError catch (e) {
                              setState(() => _trouble = e.toString());
                            }
                          },
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

/// A new profile — one dictionary per client.
class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key});

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _name = TextEditingController();
  String? _trouble;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('A new profile', style: Zc.h2),
              const SizedBox(height: 6),
              Text(
                'One dictionary per client. Only the identities of the profile you open are '
                'loaded — opening the vault is not a blank cheque.',
                style: Zc.small,
              ),
              const SizedBox(height: 16),
              TextField(controller: _name, autofocus: true, decoration: _box('Client Nordstern')),
              if (_trouble != null) ...[const SizedBox(height: 12), Trouble(_trouble!)],
              const SizedBox(height: 18),
              Row(
                children: [
                  ZButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  ZButton(
                    label: 'Create',
                    filled: true,
                    onPressed: () async {
                      try {
                        await z.createProfile(name: _name.text);
                        if (context.mounted) Navigator.of(context).pop();
                      } on ApiError catch (e) {
                        setState(() => _trouble = e.toString());
                      }
                    },
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

InputDecoration _box(String hint) => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Zc.card,
      hintText: hint,
      hintStyle: Zc.small.copyWith(color: Zc.ink4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Zc.line),
      ),
    );

String entityKindLabel(EntityKind k) => switch (k) {
      EntityKind.client => 'Client',
      EntityKind.person => 'Person',
      EntityKind.company => 'Company',
      EntityKind.project => 'Project',
      EntityKind.custom => 'Something else',
    };

class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? Zc.riverWash : Zc.card,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: on ? Zc.river.withValues(alpha: 0.4) : Zc.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: on ? FontWeight.w600 : FontWeight.w500,
              color: on ? Zc.river : Zc.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.policy,
    required this.chosen,
    required this.title,
    required this.what,
    required this.onTap,
  });

  final Policy policy;
  final Policy chosen;
  final String title;
  final String what;
  final void Function(Policy) onTap;

  @override
  Widget build(BuildContext context) {
    final on = policy == chosen;
    return InkWell(
      onTap: () => onTap(policy),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: on ? Zc.riverWash : Zc.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: on ? Zc.river.withValues(alpha: 0.4) : Zc.line),
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: on ? Zc.river : Zc.ink4,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Zc.river : Zc.ink),
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

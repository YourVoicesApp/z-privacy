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
import 'package:zprivacy/core/messages.dart';

// Kept as a name, not as a second opinion: it forwards to the one mapper.
// It used to carry its own sentence for a wrong passphrase and fall back to
// the enum's debug formatting for everything else — which is exactly the
// «one error, three sentences» drift the mapper exists to prevent.
String vaultKeyTroubleFor(ApiError e) => humanMessage(e);

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
  /// The confirmation of the **new** passphrase when changing.
  ///
  /// Changing used to ask for the new one exactly once. A typo there locks a
  /// person out of a vault that already holds their work, and the screen's own
  /// warning says there is no way back — so this is the more dangerous of the
  /// two places to type blind, not the safer one.
  final _three = TextEditingController();
  String? _trouble;
  bool _busy = false;

  /// Visibility is **per field** and starts off for both. Showing one must not
  /// show the other: the commonest reason to look is to check a typo in the
  /// one you just typed.
  ///
  /// This writes nothing to the core. It changes `obscureText` and nothing
  /// else — no call, no setting, no record of having looked.
  bool _showOne = false;
  bool _showTwo = false;
  bool _showThree = false;

  @override
  void initState() {
    super.initState();
    // Typing **and pasting** both move the match line. Pasting is how most
    // people enter a passphrase they already keep somewhere, and a match line
    // that only followed keystrokes would be wrong exactly then.
    _one.addListener(_reread);
    _two.addListener(_reread);
    _three.addListener(_reread);
  }

  void _reread() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _one.removeListener(_reread);
    _two.removeListener(_reread);
    _three.removeListener(_reread);
    _one.dispose();
    _two.dispose();
    _three.dispose();
    super.dispose();
  }

  /// Does the pair agree? Comparing here is allowed because these two are
  /// **input that has not been sent** — presentation state, not a security
  /// fact anyone stores. Rust remains the decision: it refuses a passphrase
  /// that is too short whatever this says, and the button being enabled is
  /// never taken as permission.
  bool get _needsTwo => widget.creating || widget.changing;

  /// The two fields that must agree. When creating they are the passphrase and
  /// its confirmation; when changing they are the **new** passphrase and its
  /// confirmation — never the current one, which is meant to differ.
  (String, String) get _pair =>
      widget.changing ? (_two.text, _three.text) : (_one.text, _two.text);

  bool get _confirms => widget.creating || widget.changing;
  bool get _allFilled =>
      _one.text.isNotEmpty &&
      (!_needsTwo || _two.text.isNotEmpty) &&
      (!widget.changing || _three.text.isNotEmpty);
  bool get _agree => !_confirms || _pair.$1 == _pair.$2;
  bool get _canSubmit => !_busy && _allFilled && _agree;

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
        _field(
          widget.changing ? 'Current passphrase' : 'Passphrase',
          _one,
          shown: _showOne,
          onToggle: () => setState(() => _showOne = !_showOne),
        ),
        if (needsTwo) ...[
          const SizedBox(height: 10),
          _field(
            widget.changing ? 'New passphrase' : 'Confirm passphrase',
            _two,
            shown: _showTwo,
            onToggle: () => setState(() => _showTwo = !_showTwo),
          ),
        ],
        // The line is about the pair that must agree — the new passphrase and
        // its confirmation — never about current-vs-new, which are meant to
        // differ.
        if (widget.changing) ...[
          const SizedBox(height: 10),
          _field(
            'Confirm new passphrase',
            _three,
            shown: _showThree,
            onToggle: () => setState(() => _showThree = !_showThree),
          ),
        ],
        if (_confirms && _pair.$1.isNotEmpty && _pair.$2.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            _agree ? 'Passphrases match' : 'Passphrases do not match',
            key: const Key('passphrase-match'),
            style: Zc.tiny.copyWith(
              letterSpacing: 0,
              color: _agree ? Zc.river : Zc.amber,
            ),
          ),
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
        if (_trouble != null) ...[
          const SizedBox(height: 12),
          Trouble(_trouble!),
        ],
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
          onPressed: _canSubmit ? _go : null,
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
        if (_two.text != _three.text) {
          bad = 'Passphrases do not match';
        } else {
          await z.vaultChangePassphrase(old: _one.text, replacement: _two.text);
        }
      } else if (widget.creating) {
        // No length rule here. The core owns that decision and refuses a short
        // passphrase by name; a copy of the rule in this widget is a second
        // opinion that will drift, and the mapper already words the refusal.
        //
        // The pair is compared before the button enables — but the call is
        // still made only when they agree, so a mismatch cannot slip through
        // if the button's state is ever wrong.
        if (_one.text != _two.text) {
          bad = 'Passphrases do not match';
        } else {
          await z.vaultCreateWithPassphrase(passphrase: _one.text);
        }
      } else {
        await z.vaultUnlockWithPassphrase(passphrase: _one.text);
      }
    } on ApiError catch (e) {
      bad = vaultKeyTroubleFor(e);
    }
    await widget.ground.refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _trouble = bad;
      if (bad == null) {
        _one.clear();
        _two.clear();
        _three.clear();
      }
    });
    if (bad == null) {
      widget.onDone();
      if (widget.changing && context.mounted) Navigator.of(context).maybePop();
    }
  }

  Widget _field(
    String label,
    TextEditingController c, {
    required bool shown,
    required VoidCallback onToggle,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Eyebrow(label),
      const SizedBox(height: 5),
      TextField(
        controller: c,
        // Hidden by default, and toggling touches only this. The controller is
        // never rebuilt, so the value cannot be lost or altered by looking.
        obscureText: !shown,
        // The passphrase is never a semantics value: a screen reader, a
        // screenshot service or an accessibility dump must not be a way out.
        // Only the field's own name is announced.
        obscuringCharacter: '•',
        onSubmitted: (_) => _canSubmit ? _go() : null,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Zc.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Zc.line),
          ),
          suffixIcon: IconButton(
            tooltip: shown ? 'Hide $label' : 'Show $label',
            icon: Icon(
              shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 17,
            ),
            color: Zc.ink3,
            onPressed: onToggle,
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
                  _Pick(
                    label: 'Everywhere',
                    on: _profile == null,
                    onTap: () => setState(() => _profile = null),
                  ),
                  for (final p in widget.ground.profiles)
                    _Pick(
                      label: p.name,
                      on: _profile == p.id,
                      onTap: () => setState(() => _profile = p.id),
                    ),
                ],
              ),
              if (_trouble != null) ...[
                const SizedBox(height: 12),
                Trouble(_trouble!),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  ZButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
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
                        setState(() => _trouble = humanMessage(e));
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
          _trouble = humanMessage(e);
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
              Text(
                widget.existing == null ? 'A new value' : 'Edit this value',
                style: Zc.h2,
              ),
              const SizedBox(height: 16),
              const Eyebrow('The value'),
              const SizedBox(height: 6),
              TextField(
                controller: _text,
                autofocus: widget.existing == null,
                enabled: !_loading,
                style: Zc.document.copyWith(fontSize: 14),
                decoration: _box(
                  _loading
                      ? 'reading it from the vault…'
                      : 'Nordstern Consulting GmbH',
                ),
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
                    _Pick(
                      label: row.label,
                      on: _kind == row.kind,
                      onTap: () => setState(() => _kind = row.kind),
                    ),
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
                what:
                    'Kept so its spellings and its token stay stable — but not looked for.',
                onTap: (p) => setState(() => _policy = p),
              ),
              if (_trouble != null) ...[
                const SizedBox(height: 12),
                Trouble(_trouble!),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  ZButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
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
                              if (context.mounted)
                                Navigator.of(context).pop(true);
                            } on ApiError catch (e) {
                              setState(() => _trouble = humanMessage(e));
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
  const ProfileForm({super.key, this.profile, this.ground});

  final ProfileRow? profile;

  /// Needed only for the rule sets this build carries. Optional so the older
  /// call sites keep working; without it the language row is not drawn, and
  /// the profile keeps whatever the core gave it.
  final Ground? ground;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _name = TextEditingController();
  String? _trouble;

  /// Which rule sets this client's documents are written in. A list, because a
  /// firm that works in two languages runs both in the same scan.
  late Set<String> _languages;

  @override
  void initState() {
    super.initState();
    _name.text = widget.profile?.name ?? '';
    _languages = {...?widget.profile?.languages};
  }

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
              Text(
                widget.profile == null ? 'A new profile' : 'Rename profile',
                style: Zc.h2,
              ),
              const SizedBox(height: 6),
              Text(
                widget.profile == null
                    ? 'One dictionary per client. Only the identities of the profile you open are '
                          'loaded — opening the vault is not a blank cheque.'
                    : 'The profile ID stays the same. Only the name a person reads changes.',
                style: Zc.small,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: _box('Client Nordstern'),
                onSubmitted: (_) => _save(),
              ),
              if (widget.ground != null) ...[
                const SizedBox(height: 16),
                const Eyebrow('Languages used in documents'),
                const SizedBox(height: 4),
                Text(
                  'More than one may be on. A document with a German label and an '
                  'English one is read by both in a single scan.',
                  style: Zc.tiny.copyWith(color: Zc.ink4),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    // The sets name themselves; this screen does not know what
                    // languages exist, and adding one must not touch it.
                    for (final set in widget.ground!.ruleSets)
                      _Pick(
                        label: set.label,
                        on: _languages.contains(set.id),
                        onTap: () => setState(() {
                          if (!_languages.remove(set.id)) _languages.add(set.id);
                        }),
                      ),
                  ],
                ),
              ],
              if (_trouble != null) ...[
                const SizedBox(height: 12),
                Trouble(_trouble!),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  ZButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  ZButton(
                    label: widget.profile == null ? 'Create' : 'Rename',
                    filled: true,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      final name = _name.text.trim();
      final profile = widget.profile;
      final chosen = _languages.toList()..sort();
      if (profile == null) {
        final id = await z.createProfile(name: name);
        // The core gives a new profile the device's pack. Only overwrite that
        // when the person actually chose something, so an empty selection is
        // never read as «no rule sets at all».
        final row = chosen.isEmpty
            ? ProfileRow(id: id, name: name, languages: const [])
            : await z.setProfileLanguages(profileId: id, languages: chosen);
        if (mounted) Navigator.of(context).pop(row);
      } else {
        await z.renameProfile(profileId: profile.id, name: name);
        final row = chosen.isEmpty
            ? ProfileRow(id: profile.id, name: name, languages: profile.languages)
            : await z.setProfileLanguages(profileId: profile.id, languages: chosen);
        if (mounted) Navigator.of(context).pop(row);
      }
    } on ApiError catch (e) {
      setState(() => _trouble = humanMessage(e));
    }
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
            border: Border.all(
              color: on ? Zc.river.withValues(alpha: 0.4) : Zc.line,
            ),
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
          border: Border.all(
            color: on ? Zc.river.withValues(alpha: 0.4) : Zc.line,
          ),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? Zc.river : Zc.ink,
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

/// Teach a label rule — the owner's form of 29 September, in his words:
///
/// ```text
/// When Z Privacy sees:            [ Mandantenkennung ]
/// Protect the value after it as:  [ Customer Number ]
/// Where:                          [ Profile — Nordstern ]
/// ```
///
/// Deliberately not here: a regular-expression field, a pattern language, or
/// anything that suggests a rule on its own. A word, a kind, a scope — and the
/// kinds come from the core (`kinds()`), because a screen may not decide what
/// sorts of thing exist.
class TeachRuleSheet extends StatefulWidget {
  const TeachRuleSheet({super.key, required this.ground, this.profileId});

  final Ground ground;

  /// The profile the Privacy Rules screen is showing, offered as the default
  /// scope. `null` means the rule is being taught from the everywhere view.
  final String? profileId;

  @override
  State<TeachRuleSheet> createState() => _TeachRuleSheetState();
}

class _TeachRuleSheetState extends State<TeachRuleSheet> {
  final _label = TextEditingController();
  Kind _kind = Kind.customerNo;
  late String? _profile = widget.profileId;
  String? _trouble;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _trouble = null;
    });
    try {
      await z.teachLabelRule(label: _label.text, kind: _kind, profileId: _profile);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      // A refusal is news. The core names the reason; the screen does not
      // invent one, and does not print the enum around it.
      setState(() {
        _saving = false;
        _trouble = humanMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ground;
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
              const Text('Teach a rule', style: Zc.h2),
              const SizedBox(height: 6),
              Text(
                'A rule is a word and what comes after it. Z Privacy protects the '
                'value that follows and stops at the end of that field.',
                style: Zc.small,
              ),
              const SizedBox(height: 18),
              const Eyebrow('When Z Privacy sees'),
              const SizedBox(height: 6),
              TextField(
                controller: _label,
                autofocus: true,
                decoration: _box('Mandantenkennung'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Eyebrow('Protect the value after it as'),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  // The kinds come from the core. A screen may not decide what
                  // sorts of thing exist in the world.
                  for (final row in g.kinds)
                    _Pick(
                      label: row.label,
                      on: row.kind == _kind,
                      onTap: () => setState(() => _kind = row.kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Eyebrow('Where'),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _Pick(
                    label: 'Everywhere',
                    on: _profile == null,
                    onTap: () => setState(() => _profile = null),
                  ),
                  for (final p in g.profiles)
                    _Pick(
                      label: 'Profile — ${p.name}',
                      on: _profile == p.id,
                      onTap: () => setState(() => _profile = p.id),
                    ),
                ],
              ),
              if (_trouble != null) ...[
                const SizedBox(height: 12),
                Trouble(_trouble!),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ZButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  ZButton(
                    label: 'Save rule',
                    filled: true,
                    onPressed: _saving || _label.text.trim().isEmpty ? null : _save,
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

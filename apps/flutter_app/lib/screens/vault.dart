// Z Vault — the room where the app learns who your people are.
//
// It is the second most important screen after the Workspace, because it is the
// only one where the fourth detection layer is made. Everything here is the
// core's: a value is read through `reveal_value` and shown for a moment, the
// search runs inside Rust over secrets and hands back rows only, and every edit
// goes through one path that re-seals the vault and re-reads the list.
//
// The shape is the owner's:
//
//   Profiles → Entities → Values → Aliases → Protection policy
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/entity_detail.dart';
import 'package:zprivacy/widgets/vault_forms.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, required this.ground, required this.onClose});

  final Ground ground;
  final VoidCallback onClose;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _search = TextEditingController();
  Timer? _typing;
  int? _open;
  EntityCard? _card;
  String? _profileFilter;

  @override
  void initState() {
    super.initState();
    widget.ground.readVault();
  }

  @override
  void dispose() {
    _typing?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEntity(int? id) async {
    setState(() {
      _open = id;
      _card = null;
    });
    if (id == null) return;
    try {
      final card = await z.entity(entityId: id);
      if (mounted) setState(() => _card = card);
    } on ApiError catch (e) {
      if (mounted) setState(() => widget.ground.trouble = e.toString());
    }
  }

  Future<void> _reload() async {
    await widget.ground.readVault();
    if (_open != null) await _openEntity(_open);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ground;
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) => Scaffold(
        body: Column(
          children: [
            _bar(g),
            if (g.trouble != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Trouble(g.trouble!),
              ),
            Expanded(
              child: switch (g.vault) {
                VaultState.unlocked => _open == null ? _list(g) : _entity(g),
                _ => _closed(g),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Ground g) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(bottom: BorderSide(color: Zc.line)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _open == null ? widget.onClose : () => _openEntity(null),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left, size: 18, color: Zc.ink3),
                  const SizedBox(width: 4),
                  Text(
                    _open == null ? 'Back' : 'All identities',
                    style: Zc.small,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.lock_outline, size: 17, color: Zc.river),
          const SizedBox(width: 8),
          const Text(
            'Z Vault',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Zc.ink,
            ),
          ),
          const SizedBox(width: 10),
          Text(switch (g.vaultSnap?.vault ?? g.vault) {
            VaultState.unlocked =>
              '${plural(g.vaultSnap?.identityCount ?? g.entityCount, "identity", "identities")} · ${plural(g.vaultSnap?.valueCount ?? g.valueCount, "value")}',
            VaultState.locked => 'Locked',
            VaultState.absent => 'Not created on this device',
          }, style: Zc.small.copyWith(color: Zc.ink4)),
          const Spacer(),
          if (g.vault == VaultState.unlocked) ...[
            ZButton(
              label: 'Change passphrase',
              onPressed: () => _passphrase(g),
            ),
            const SizedBox(width: 9),
            ZButton(
              label: 'Lock',
              icon: Icons.lock,
              onPressed: () async {
                await z.vaultLock();
                await g.refresh();
                await g.readVault();
                if (mounted) setState(() => _open = null);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Locked or absent: the room says what is missing and offers the one act
  /// that would change it. It does not pretend to be empty.
  Widget _closed(Ground g) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              g.vault == VaultState.locked
                  ? 'The vault is locked'
                  : 'There is no vault yet',
              style: Zc.h2,
            ),
            const SizedBox(height: 8),
            Text(
              g.vault == VaultState.locked
                  ? 'Your identities are on this device, sealed. Until it is open the scanner '
                        'still runs its rules and its pack — an IBAN is still caught — but not who.'
                  : 'A vault is the only file this app writes. It holds your people and their '
                        'values, encrypted with a passphrase that never leaves this device. '
                        'Without one, nothing is recognised by name.',
              style: Zc.body,
            ),
            const SizedBox(height: 18),
            VaultKeyForm(
              ground: g,
              creating: g.vault == VaultState.absent,
              onDone: _reload,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(Ground g) {
    final rows = _profileFilter == null
        ? g.vaultRows
        : g.vaultRows.where((r) => r.profileId == _profileFilter).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Zc.card,
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 17,
                      color: Zc.ink4,
                    ),
                    hintText: 'Search this device — names, values, spellings',
                    hintStyle: Zc.small.copyWith(color: Zc.ink4),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: Zc.line),
                    ),
                  ),
                  onChanged: (q) {
                    // The search runs in Rust over real values, so it is not run
                    // on every keystroke.
                    _typing?.cancel();
                    _typing = Timer(
                      const Duration(milliseconds: 180),
                      () => g.searchVaultFor(q),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              ZButton(
                label: 'New identity',
                filled: true,
                icon: Icons.add,
                onPressed: () async {
                  final made = await showDialog<int>(
                    context: context,
                    builder: (_) => EntityForm(ground: g),
                  );
                  await _reload();
                  if (made != null) await _openEntity(made);
                },
              ),
            ],
          ),
        ),
        if (g.profiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(
              children: [
                const Eyebrow('Profile'),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _Chip(
                        label: 'All',
                        on: _profileFilter == null,
                        onTap: () => setState(() => _profileFilter = null),
                      ),
                      for (final p in g.profiles)
                        _Chip(
                          label: p.name,
                          on: _profileFilter == p.id,
                          onTap: () => setState(() => _profileFilter = p.id),
                        ),
                    ],
                  ),
                ),
                ZButton(
                  label: 'New profile',
                  onPressed: () async {
                    final made = await showDialog<ProfileRow>(
                      context: context,
                      builder: (_) => ProfileForm(ground: g),
                    );
                    await g.refresh();
                    await _reload();
                    if (made != null) setState(() => _profileFilter = made.id);
                  },
                ),
              ],
            ),
          ),
        _taught(g),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    g.vaultQuery.isEmpty
                        ? 'No identities yet. The first one is usually the client whose documents '
                              'you work on.'
                        : 'Nothing on this device matches «${g.vaultQuery}».',
                    style: Zc.small,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  children: [
                    for (final row in rows)
                      _EntityRowTile(
                        row: row,
                        profiles: g.profiles,
                        onTap: () => _openEntity(row.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// What Z Privacy has learned from you — the owner's «My Privacy Rules».
  Widget _taught(Ground g) {
    final rules = g.privacyRules;
    final values = rules?.values ?? const <TaughtValueRow>[];
    final exceptions = rules?.exceptions ?? const <TaughtExceptionRow>[];
    final labelRules = rules?.labelRules ?? const <LabelRuleRow>[];
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      decoration: Zc.panel(fill: Zc.warmCard, edge: Zc.lineSoft, radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('My Privacy Rules'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              _Learned(
                title: 'Values I taught',
                count: '${values.length}',
                what:
                    'names, companies, numbers — found by themselves from now on',
                live: true,
              ),
              _Learned(
                title: 'Rules I taught',
                count: '${labelRules.length}',
                what: 'words that say what follows them — «after Mandantenkennung → customer number»',
                live: true,
              ),
              _Learned(
                title: 'Exceptions I taught',
                count: '${exceptions.length}',
                what: 'values you explicitly excluded from protection',
                live: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RuleSection(
            title: 'Values I taught',
            empty: 'No taught values yet.',
            children: [
              for (final row in values.take(5))
                _TaughtValueTile(
                  row: row,
                  kind: g.nameOfKind(row.kind),
                  onOpen: () => _openEntity(row.entityId),
                  onForget: () => g.vaultEdit(
                    () => z.forgetValue(
                      entity: row.entityId,
                      valueId: row.valueId,
                      everywhere: false,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _RuleSection(
            title: 'Rules I taught',
            empty: 'No rules taught yet.',
            children: [
              for (final row in labelRules.take(5))
                _TaughtRuleTile(
                  row: row,
                  kind: g.nameOfKind(row.kind),
                  onForget: () => g.vaultEdit(() => z.forgetLabelRule(id: row.id)),
                ),
              _TeachRuleButton(ground: g, profileId: rules?.profileId),
            ],
          ),
          const SizedBox(height: 10),
          _RuleSection(
            title: 'Exceptions I taught',
            empty: 'No saved exceptions yet.',
            children: [
              for (final row in exceptions.take(5))
                _TaughtExceptionTile(
                  row: row,
                  kind: g.nameOfKind(row.kind),
                  onForget: () =>
                      g.vaultEdit(() => z.forgetException(id: row.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entity(Ground g) {
    final card = _card;
    if (card == null) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Zc.river),
        ),
      );
    }
    return EntityDetail(
      ground: g,
      card: card,
      onChanged: _reload,
      onGone: () => _openEntity(null),
    );
  }

  Future<void> _passphrase(Ground g) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Zc.paper,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: VaultKeyForm(
              ground: g,
              creating: false,
              changing: true,
              onDone: _reload,
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.title,
    required this.empty,
    required this.children,
    this.live = true,
  });

  final String title;
  final String empty;
  final List<Widget> children;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: live ? 1 : 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Zc.ink,
            ),
          ),
          const SizedBox(height: 6),
          if (children.isEmpty)
            Text(empty, style: Zc.tiny.copyWith(letterSpacing: 0))
          else
            Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _TaughtValueTile extends StatelessWidget {
  const _TaughtValueTile({
    required this.row,
    required this.kind,
    required this.onOpen,
    required this.onForget,
  });

  final TaughtValueRow row;
  final String kind;
  final VoidCallback onOpen;
  final Future<String?> Function() onForget;

  @override
  Widget build(BuildContext context) {
    return _RuleTile(
      title: row.value,
      subtitle:
          '$kind · ${_scope(row.profileName)} · Taught: ${_taughtOn(row.taughtAt)}',
      why: row.why,
      onOpen: onOpen,
      onForget: onForget,
    );
  }
}

class _TaughtExceptionTile extends StatelessWidget {
  const _TaughtExceptionTile({
    required this.row,
    required this.kind,
    required this.onForget,
  });

  final TaughtExceptionRow row;
  final String kind;
  final Future<String?> Function() onForget;

  @override
  Widget build(BuildContext context) {
    return _RuleTile(
      title: row.value,
      subtitle:
          'Do not protect as $kind · ${_scope(row.profileName)} · Taught: ${_taughtOn(row.taughtAt)}',
      why: row.why,
      onForget: onForget,
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.title,
    required this.subtitle,
    required this.why,
    this.onOpen,
    required this.onForget,
  });

  final String title;
  final String subtitle;
  final String why;
  final VoidCallback? onOpen;
  final Future<String?> Function() onForget;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: Zc.panel(fill: Zc.card, edge: Zc.lineSoft, radius: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Zc.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: Zc.tiny.copyWith(letterSpacing: 0)),
          const SizedBox(height: 5),
          Text(why, style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (onOpen != null)
                ZButton(label: 'Open', onPressed: onOpen)
              else
                const Spacer(),
              if (onOpen != null) const Spacer(),
              ZButton(label: 'Forget', onPressed: () async => onForget()),
            ],
          ),
        ],
      ),
    );
  }
}

String _scope(String? profile) =>
    profile == null ? 'Everywhere' : 'Profile: $profile';

String _taughtOn(BigInt seconds) {
  if (seconds == BigInt.zero) return 'unknown';
  final date = DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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
              fontWeight: FontWeight.w600,
              color: on ? Zc.river : Zc.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EntityRowTile extends StatelessWidget {
  const _EntityRowTile({
    required this.row,
    required this.profiles,
    required this.onTap,
  });

  final EntityRow row;
  final List<ProfileRow> profiles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = row.profileId == null
        ? 'Everywhere'
        : profiles
              .firstWhere(
                (p) => p.id == row.profileId,
                orElse: () =>
                    ProfileRow(id: row.profileId!, name: row.profileId!, languages: const []),
              )
              .name;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: Zc.panel(fill: Zc.card, radius: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Zc.riverWash,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                entityKindName(row.kind),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Zc.river,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Zc.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${plural(row.values, "value")} · ${row.policySummary} · $profile',
                    style: Zc.small.copyWith(color: Zc.ink4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Zc.ink4),
          ],
        ),
      ),
    );
  }
}

String entityKindName(EntityKind k) => switch (k) {
  EntityKind.client => 'CLIENT',
  EntityKind.person => 'PERSON',
  EntityKind.company => 'COMPANY',
  EntityKind.project => 'PROJECT',
  EntityKind.custom => 'OTHER',
};

/// One group of what the app has learned. A group that does not exist yet says
/// so rather than being left out.
class _Learned extends StatelessWidget {
  const _Learned({
    required this.title,
    required this.count,
    required this.what,
    required this.live,
  });

  final String title;
  final String count;
  final String what;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: live ? 1 : 0.6,
      child: SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: live ? Zc.river : Zc.ink4,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Zc.ink2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(what, style: Zc.tiny.copyWith(letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}


/// One rule the person taught, and the one act it allows: forgetting it.
///
/// Forgetting a rule is knowledge only — a document open now keeps every token
/// it already has. That is §3 of the invariants, and the core proves it in
/// `rule_sets.rs`; this tile only has to not say otherwise.
class _TaughtRuleTile extends StatelessWidget {
  const _TaughtRuleTile({required this.row, required this.kind, required this.onForget});

  final LabelRuleRow row;
  final String kind;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final scope = row.profileName ?? 'Everywhere';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('After «${row.label}:» → $kind', style: Zc.body),
                const SizedBox(height: 2),
                Text(scope, style: Zc.tiny.copyWith(color: Zc.ink4)),
              ],
            ),
          ),
          ZButton(label: 'Forget', onPressed: onForget),
        ],
      ),
    );
  }
}

/// His form, in his words:
///
///   When Z Privacy sees:      [ Mandantenkennung ]
///   Protect the value after it as: [ Customer Number ]
///   Where:                    [ Profile — Nordstern ]
///
/// No regular expressions, no pattern language, no «we noticed you did this
/// five times». A word, a kind, a scope.
class _TeachRuleButton extends StatelessWidget {
  const _TeachRuleButton({required this.ground, required this.profileId});

  final Ground ground;
  final String? profileId;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ZButton(
          label: 'Teach a rule',
          icon: Icons.add,
          onPressed: () async {
            final taught = await showDialog<bool>(
              context: context,
              builder: (_) => TeachRuleSheet(ground: ground, profileId: profileId),
            );
            if (taught == true) await ground.refresh();
          },
        ),
      ),
    );
  }
}

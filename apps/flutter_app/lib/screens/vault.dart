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

import 'package:zprivacy/core/a_date_in_words.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/reveal.dart';
import 'package:zprivacy/widgets/entity_detail.dart';
import 'package:zprivacy/widgets/vault_forms.dart';
import 'package:zprivacy/widgets/why_sheet.dart';
import 'package:zprivacy/core/messages.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({
    super.key,
    required this.ground,
    required this.onClose,
    this.bench,
  });

  final Ground ground;
  final VoidCallback onClose;

  /// The open document's bench, when there is one. The board is where the
  /// profile door lives now that the work surfaces have let it go, and
  /// switching a conversation's profile is a thing done **to** a bench.
  final Workbench? bench;

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
    // After the build, not inside it. `readVault` notifies straight away when
    // the vault is not open — it has nothing to read and says so — and a
    // listener marked dirty while the tree is being built is an unsound
    // rebuild: `'!_dirty': is not true`, measured the moment 041-E made this
    // screen reachable from inside a document and from the first run. It was
    // only ever opened from Home before, where nothing else was building.
    unawaited(Future<void>.microtask(() {
      if (mounted) widget.ground.readVault();
    }));
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
      if (mounted) setState(() => widget.ground.trouble = humanMessage(e));
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
                    _open == null ? sentences.back: sentences.allIdentities,
                    style: Zc.small,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.lock_outline, size: 17, color: Zc.river),
          const SizedBox(width: 8),
          Text(
            sentences.zVault,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Zc.ink,
            ),
          ),
          const SizedBox(width: 10),
          // **And the blocks, counted** — 089 rule 1. The owner's complaint
          // that opened the round was that the app could not tell him what it
          // had kept («التطبيق ما زال لا يستطيع معرفة منتجه»), and this is the
          // one line in the app that says how much it keeps. A count and never
          // a word: the identities and the values below are rows a person
          // taught on purpose and reviews by name, and a block is a word they
          // already protected — the only door that reads one back is the
          // document that asks for it by its own token.
          Text(switch (g.vaultSnap?.vault ?? g.vault) {
            VaultState.unlocked => [
              sentences.identitiesCount(g.vaultSnap?.identityCount ?? g.entityCount),
              sentences.valuesCount(g.vaultSnap?.valueCount ?? g.valueCount),
              if ((g.vaultSnap?.blockCount ?? 0) > 0)
                sentences.protectedWordsCount(g.vaultSnap!.blockCount),
            ].join(' · '),
            VaultState.locked => sentences.vaultIsLocked,
            VaultState.absent => sentences.notCreatedOnThisDevice,
          }, style: Zc.small.copyWith(color: Zc.ink4)),
          const Spacer(),
          if (g.vault == VaultState.unlocked) ...[
            ZButton(
              label: sentences.changePassphrase,
              onPressed: () => _passphrase(g),
            ),
            const SizedBox(width: 9),
            ZButton(
              label: sentences.lockTheVault,
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
                  ? sentences.theVaultIsLocked: sentences.thereIsNoVaultYet,
              style: Zc.h2,
            ),
            const SizedBox(height: 8),
            Text(
              g.vault == VaultState.locked
                  ? sentences.yourIdentitiesAreSealed: sentences.aVaultIsTheOnlyFile,
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
                    hintText: sentences.searchThisDevice,
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
                label: sentences.newIdentity,
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
                Eyebrow(sentences.profile),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _Chip(
                        label: sentences.filterAll,
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
                // **The door the header let go of — 075a.** While the vault
                // holds one profile the work surfaces carry no profile
                // control, so this is where a person who goes looking finds
                // the choice. A control that recedes must leave a way in, or
                // it has not receded: it has gone, and something that could be
                // done yesterday cannot be done today.
                //
                // Only with a bench: choosing a profile is a thing done **to**
                // an open document's conversation, and the board can be opened
                // with none.
                if (widget.bench != null) ...[
                  ZButton(
                    key: ProfileSwitcher.door,
                    label: sentences.sessionProfile,
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (_) =>
                            ProfileSwitcher(bench: widget.bench!, ground: g),
                      );
                      await g.refresh();
                      await _reload();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                ZButton(
                  label: sentences.newProfile,
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
                        ? sentences.noIdentitiesYet// What they typed, isolated: the sentence keeps its
                        // order whatever language they searched in.
                        : sentences.nothingMatchesQuery(theirOwnWord(g.vaultQuery)),
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
          // The settings room's own key, because `Eyebrow` upper-cases what
          // it is given and the two spellings were one word.
          Eyebrow(sentences.myPrivacyRules),
          const SizedBox(height: 8),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              _Learned(
                title: sentences.valuesITaught,
                count: '${values.length}',
                what:
                    sentences.valuesITaughtWhat,
                live: true,
              ),
              _Learned(
                title: sentences.rulesITaught,
                count: '${labelRules.length}',
                what: sentences.rulesITaughtWhat,
                live: true,
              ),
              _Learned(
                title: sentences.exceptionsITaught,
                count: '${exceptions.length}',
                what: sentences.exceptionsITaughtWhat,
                live: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RuleSection(
            title: sentences.valuesITaught,
            empty: sentences.noTaughtValuesYet,
            children: [
              for (final row in values.take(5))
                _TaughtValueTile(
                  row: row,
                  kind: g.nameOfKind(row.kind),
                  ground: g,
                  onOpen: () => _openEntity(row.entityId),
                  // The reach comes from the act the button names. It passed
                  // `everywhere: false` under a button reading «Forget
                  // everywhere», which on knowledge held in no profile happened
                  // to look the same and would not have stayed that way.
                  onForget: (everywhere) => g.vaultEdit(
                    () => z.forgetValue(
                      entity: row.entityId,
                      valueId: row.valueId,
                      everywhere: everywhere,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _RuleSection(
            title: sentences.rulesITaught,
            empty: sentences.noRulesTaughtYet,
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
            title: sentences.exceptionsITaught,
            empty: sentences.noSavedExceptionsYet,
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

/// A value the vault protects, in the list of what it was taught.
///
/// Human run, 30 September: this card printed the value as its heading, while
/// the same value one screen deeper — the identity card — sat behind dots, a
/// «Reveal» and a clock. Two rooms behind one passphrase, and the rule applied
/// in only one of them. It is the same door here now, and the same machine
/// behind it; the row itself no longer carries the text at all.
class _TaughtValueTile extends StatefulWidget {
  const _TaughtValueTile({
    required this.row,
    required this.kind,
    required this.ground,
    required this.onOpen,
    required this.onForget,
  });

  final TaughtValueRow row;
  final String kind;
  final Ground ground;
  final VoidCallback onOpen;

  /// Takes the reach, because the tile is where the act is named.
  final Future<String?> Function(bool everywhere) onForget;

  @override
  State<_TaughtValueTile> createState() => _TaughtValueTileState();
}

class _TaughtValueTileState extends State<_TaughtValueTile>
    with RevealHold<_TaughtValueTile> {
  @override
  void dispose() {
    endReveal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final shown = shownFor(row.valueId);
    return _RuleTile(
      title: SizedBox(
        // Fixed, so the time running out changes the content and not the
        // height: the buttons below must not move out from under a pointer
        // that is already resting on one. The identity card holds the same
        // rule for the same reason — `reveal_row_test.dart`.
        height: 20,
        child: Row(
          children: [
            Expanded(
              child: shown == null
                  ? Text(
                      '••••••••••••',
                      style: Zc.small.copyWith(color: Zc.ink4, letterSpacing: 2),
                    )
                  : Text(
                      shown.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Zc.ink,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              revealLabel(row.valueId),
              key: Key('taught-reveal-state-${row.valueId}'),
              style: Zc.tiny.copyWith(
                letterSpacing: 0,
                color: shown == null ? Zc.ink4 : Zc.river,
              ),
            ),
          ],
        ),
      ),
      subtitle:
          sentences.kindScopeTaughtOn(widget.kind, _scope(row.profileName), theDayItWas(row.taughtAt.toInt())),
      why: row.why,
      forgetLabel: forgetLabelFor(row.profileId),
      leading: SizedBox(
        // One width for both words, so «Hide» does not shift what follows it.
        width: 142,
        child: ZButton(
          label: shown == null ? sentences.reveal: sentences.hide,
          icon: shown == null
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          onPressed: shown == null
              ? () => reveal(
                  row.entityId,
                  row.valueId,
                  onTrouble: (m) =>
                      setState(() => widget.ground.trouble = m),
                )
              : hideNow,
        ),
      ),
      onOpen: widget.onOpen,
      onForget: () async {
        // Named by the reach, and asked before it is done. Forgetting is the
        // one act here that cannot be taken back.
        final everywhere = row.profileId == null;
        final sure = await confirmForget(
          context,
          entity: row.entityId,
          valueId: row.valueId,
          everywhere: everywhere,
          action: forgetLabelFor(row.profileId),
          onTrouble: (m) => setState(() => widget.ground.trouble = m),
        );
        if (!sure) return null;
        await hideNow();
        return widget.onForget(everywhere);
      },
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
      // An exception is a value its owner declared **not** sensitive, and the
      // list exists so that declaration can be read back. It stays legible.
      title: _PlainTitle(row.value),
      subtitle:
          sentences.doNotProtectAsKindScopeTaughtOn(kind, _scope(row.profileName), theDayItWas(row.taughtAt.toInt())),
      why: row.why,
      forgetLabel: forgetLabelFor(row.profileId),
      onForget: () async {
        final sure = await confirmForgetPlainly(
          context,
          what: row.value,
          goes: sentences.theExceptionGoes,
          action: forgetLabelFor(row.profileId),
        );
        if (!sure) return null;
        return onForget();
      },
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.title,
    required this.subtitle,
    required this.why,
    required this.forgetLabel,
    this.onOpen,
    this.leading,
    required this.onForget,
  });

  /// The card's first line — a widget, not a string, because a value the vault
  /// is protecting is not drawn as text until a person asks for it.
  final Widget title;
  final String subtitle;
  final String why;

  /// The scope travels in the name of the act, not in the small line above it:
  /// the tile used to show a bare «Forget» over «Everywhere» set in the card's
  /// smallest type, and a person had to assemble the meaning from the two.
  final String forgetLabel;
  final VoidCallback? onOpen;

  /// An action that belongs before «Open» — the reveal, where there is one.
  final Widget? leading;
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
          title,
          const SizedBox(height: 3),
          Text(subtitle, style: Zc.tiny.copyWith(letterSpacing: 0)),
          const SizedBox(height: 5),
          Text(why, style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4)),
          const SizedBox(height: 8),
          // A Wrap, not a Row: «Forget from this profile» is a longer name than
          // «Forget», and on a 330 px card it overflowed the row by 49 px — the
          // scope has to be readable, so the layout gives way, not the name.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ?leading,
              if (onOpen != null) ZButton(label: sentences.openIdentity, onPressed: onOpen),
              ZButton(label: forgetLabel, onPressed: () async => onForget()),
            ],
          ),
        ],
      ),
    );
  }
}

/// The old heading, kept for the lines that are still text.
class _PlainTitle extends StatelessWidget {
  const _PlainTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Zc.ink,
        ),
      );
}

/// **The client's own name, isolated** — the law of 16 October, and this is
/// one place for both callers: a profile named «ألماني» in an English line
/// pulls what follows it into its own direction without the pair.
String _scope(String? profile) => profile == null
    ? sentences.everywhere: sentences.profileNamed(theirOwnWord(profile));

/// The name of the forget act for knowledge with this reach.
///
/// Decided by `profileId` — a fact from the core — and never by reading the
/// display line beside it. The profile's **name** stays out of the button for
/// the same reason it stays out of «Where it applies»: a reach is not a client.
String forgetLabelFor(String? profileId) =>
    profileId == null ? kForgetEverywhere : kForgetThisProfile;

// **The date this screen used to format itself** is `theDayItWas` now, in
// `core/a_date_in_words.dart` — there were two copies of it with two `const
// months` lists, here and in `why_sheet.dart`, and twenty-four hand-written
// English words between them.

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
        ? sentences.everywhere: profiles
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
                    // Three facts the core counted, joined by a middle dot:
                    // the count is a sentence of its own now, because German
                    // cannot take a number with a noun handed to it.
                    '${sentences.valuesCount(row.values)} · ${row.policySummary} · '
                    '${theirOwnWord(profile)}',
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

/// **The chip's word, which is the form's word upper-cased** — 092.
///
/// There were two switches over `EntityKind`, this one in capitals for the chip
/// on an identity row and `entityKindLabel` in title case for the forms: one
/// word in two places, and two German values waiting to disagree. The chip
/// shouts the same word the form says, exactly as `Eyebrow` does with every
/// label it is given.
String entityKindName(EntityKind k) => entityKindLabel(k).toUpperCase();

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
    final scope = row.profileName ?? sentences.everywhere;
    // The rule above its action, rather than beside it: the act's name now
    // carries its scope, and a name that long beside an `Expanded` label
    // squeezed the button until its own text overflowed by 58 px.
    // The label is the person's own word — «Kundennummer:», «المرجع:» — so it
    // is isolated and the arrow stays on the right side of it.
    final line = sentences.afterLabelProtectAs(theirOwnWord(row.label), kind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line, style: Zc.body),
          const SizedBox(height: 2),
          Text(scope, style: Zc.tiny.copyWith(color: Zc.ink4)),
          const SizedBox(height: 7),
          ZButton(
            label: forgetLabelFor(row.profileId),
            onPressed: () async {
              final sure = await confirmForgetPlainly(
                context,
                what: line,
                goes: sentences.theRuleGoes,
                action: forgetLabelFor(row.profileId),
              );
              if (sure) onForget();
            },
          ),
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
          label: sentences.teachARule,
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

// Settings — four small rooms, not one long page.
//
// The owner's division, and the reason it is a division: a person looking for
// «where does my API key live» should not have to scroll past the reveal
// duration to find out.
//
//   AI                 the three doors
//   Privacy            what the app does by itself
//   Language & rules   the detection engine, and the interface
//   Vault & security   the key, the lock, and where a credential lives
//
// Nothing here can make something leave the device. These switches decide only
// how far the app goes on its own — and one of them is missing on purpose:
// there is no «send anyway», not as a setting, not as a hidden flag.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/connect_form.dart';

enum SettingsRoom { ai, privacy, language, vault }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.ground, required this.onClose, this.room});

  final Ground ground;
  final VoidCallback onClose;
  final SettingsRoom? room;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsRoom _room = widget.room ?? SettingsRoom.ai;

  @override
  Widget build(BuildContext context) {
    final g = widget.ground;
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) => Scaffold(
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
              decoration: const BoxDecoration(
                color: Zc.card,
                border: Border(bottom: BorderSide(color: Zc.line)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Row(
                        children: [
                          Icon(Icons.chevron_left, size: 18, color: Zc.ink3),
                          SizedBox(width: 4),
                          Text('Back', style: Zc.small),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Zc.ink)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _rooms(),
                  Container(width: 1, color: Zc.line),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: switch (_room) {
                          SettingsRoom.ai => _AiRoom(ground: g),
                          SettingsRoom.privacy => _PrivacyRoom(ground: g),
                          SettingsRoom.language => _LanguageRoom(ground: g),
                          SettingsRoom.vault => _VaultRoom(ground: g),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rooms() {
    Widget one(SettingsRoom r, String label, IconData icon) {
      final on = _room == r;
      return InkWell(
        onTap: () => setState(() => _room = r),
        child: Container(
          width: 210,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          color: on ? Zc.clayWash : Colors.transparent,
          child: Row(
            children: [
              Icon(icon, size: 17, color: on ? Zc.clayDeep : Zc.ink3),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                    color: on ? Zc.clayDeep : Zc.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Zc.warmCard,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          one(SettingsRoom.ai, 'AI', Icons.hub_outlined),
          one(SettingsRoom.privacy, 'Privacy', Icons.shield_outlined),
          one(SettingsRoom.language, 'Language & rules', Icons.translate),
          one(SettingsRoom.vault, 'Vault & security', Icons.lock_outline),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- AI

class _AiRoom extends StatelessWidget {
  const _AiRoom({required this.ground});

  final Ground ground;

  @override
  Widget build(BuildContext context) {
    final rows = ground.providers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('AI', 'Three ways to ask a model. The first needs no account at all.'),
        _Card(
          title: 'Manual AI',
          what: 'Use an AI chat you already have. Copy the safe text out of the Workspace, '
              'paste it into whatever model you use, and bring the answer back. Nothing to '
              'set up, nothing to pay for, and the restoring works exactly the same.',
          child: Text(
            'Always available — it is the «Review what will leave» sheet, first door.',
            style: Zc.small.copyWith(color: Zc.ink4),
          ),
        ),
        for (final row in rows)
          _Card(
            // Named for the route a person chose, not the protocol. The
            // protocol is a fact about this card and is stated below, beside
            // the endpoint — which is the only place it answers a question
            // anyone actually has.
            title: 'Direct API',
            what: row.credentialRequired
                ? 'Connect to a remote AI provider with your API credential. The key goes in '
                    'once and never comes back out — no screen in this app can show it to you '
                    'again.'
                : 'At this address no credential is needed.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Spec('Protocol', row.label),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Dot(on: row.connected),
                    const SizedBox(width: 8),
                    Text(
                      switch (row.credentialState) {
                        CredentialState.encryptedInVault => 'Connected · key sealed in the vault',
                        CredentialState.sessionOnly => 'Connected · key kept for this run only',
                        CredentialState.missing => row.connected ? 'Connected · no key needed' : 'Not connected',
                      },
                      style: Zc.small.copyWith(
                        color: row.connected ? Zc.ink2 : Zc.ink4,
                        fontWeight: row.connected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConnectForm(ground: ground, row: row, local: false),
              ],
            ),
          ),
        if (rows.isNotEmpty)
          _Card(
            title: 'Local AI',
            what: 'Runs through an AI service on this computer — llama.cpp, Ollama, LM '
                'Studio, anything that answers the same shape. No key, no account, and the '
                'request never leaves this computer. Plain http is accepted only for a '
                'literal loopback address.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Spec('Protocol', rows.first.label),
                const SizedBox(height: 10),
                ConnectForm(ground: ground, row: rows.first, local: true),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Privacy

class _PrivacyRoom extends StatelessWidget {
  const _PrivacyRoom({required this.ground});

  final Ground ground;

  @override
  Widget build(BuildContext context) {
    final c = ground.config;
    if (c == null) return const Text('…', style: Zc.small);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Privacy', 'What the app does by itself, and how far it goes without asking.'),
        if (c.sessionOnly) ...[
          Trouble(
            'There is no vault open, so these are for this run only. The vault is the one file '
            'this app writes — without it, nothing is remembered.',
          ),
          const SizedBox(height: 16),
        ],
        _Switch(
          on: c.scanOnImport,
          title: 'Scan a document the moment it arrives',
          what: 'No dialog, no button. Turning this off means a document sits unprotected until '
              'you press Rescan — which is exactly the moment the boards were written to avoid.',
          onChanged: (v) => ground.saveConfig(_with(c, scanOnImport: v)),
        ),
        _Fixed(
          title: 'Answer every suggestion before sending',
          what: 'Not a setting. A suggestion that has not been answered is never quietly treated '
              'as safe, and there is no «send anyway» — not here, not in a hidden flag, not '
              'anywhere in the code.',
        ),
        _Number(
          value: c.revealSeconds,
          title: 'A revealed value stays for',
          unit: 'seconds',
          min: 3,
          max: 300,
          what: 'Revealing draws on the screen and never writes into what leaves. This is only '
              'how long it stays drawn.',
          onChanged: (v) => ground.saveConfig(_with(c, revealSeconds: v)),
        ),
        _Fixed(
          title: 'Token rotation',
          what: 'Not built yet. When it is, it will live here: whether a permanent token keeps '
              'its number across sessions, or is drawn again each time so two conversations '
              'cannot be linked by it.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Language

class _LanguageRoom extends StatelessWidget {
  const _LanguageRoom({required this.ground});

  final Ground ground;

  @override
  Widget build(BuildContext context) {
    final c = ground.config;
    if (c == null) return const Text('…', style: Zc.small);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title(
          'Language & rules',
          'A privacy pack is a detection engine, not the language of the interface — and more '
          'than one pack can run in a single scan, so this is a starting point rather than the '
          'only rules allowed. The interface itself is English.',
        ),
        _Card(
          title: 'Privacy pack',
          what: 'Which habits the scanner knows: salutations, company forms, the way a customer '
              'number is written. This is the one with teeth.',
          child: Wrap(
            spacing: 8,
            children: [
              for (final p in ground.packs)
                _Pick(
                  label: p.label,
                  on: c.packId == p.id,
                  onTap: () => ground.saveConfig(_with(c, packId: p.id)),
                ),
            ],
          ),
        ),
        _Card(
          title: 'Interface',
          what: 'English today. The German translation is not written yet — and a half-German '
              'screen in a privacy product is worse than an English one, so the switch waits '
              'until every line is there rather than showing you a mixture.',
          child: Row(
            children: [
              _Pick(label: 'English', on: true, onTap: () {}),
              const SizedBox(width: 8),
              Opacity(
                opacity: 0.5,
                child: _Pick(label: 'Deutsch', on: false, onTap: () {}),
              ),
              const SizedBox(width: 12),
              Text('not translated yet', style: Zc.tiny.copyWith(letterSpacing: 0)),
            ],
          ),
        ),
        _Card(
          title: 'My privacy rules',
          what: 'Not built yet. Rules you write yourself — a customer number format only your '
              'office uses, a project codename — will live here, beside the pack rather than '
              'inside it.',
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Vault

class _VaultRoom extends StatelessWidget {
  const _VaultRoom({required this.ground});

  final Ground ground;

  @override
  Widget build(BuildContext context) {
    final c = ground.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Vault & security', 'The key, the lock, and where a credential lives.'),
        _Card(
          title: 'Z Vault',
          what: switch (ground.vault) {
            VaultState.unlocked => 'Open. Your identities are loaded and the fourth detection '
                'layer is running.',
            VaultState.locked => 'Locked. The rules and the pack still run — an IBAN is still '
                'caught — but not who it belongs to.',
            VaultState.absent => 'Not created on this device. Nothing is recognised by name.',
          },
          child: Row(
            children: [
              _Dot(on: ground.vault == VaultState.unlocked),
              const SizedBox(width: 8),
              Text(
                switch (ground.vault) {
                  VaultState.unlocked => 'Unlocked · ${ground.entityCount} identities',
                  VaultState.locked => 'Locked',
                  VaultState.absent => 'None',
                },
                style: Zc.small,
              ),
            ],
          ),
        ),
        if (c != null)
          _Number(
            value: c.autoLockMinutes,
            title: 'Lock the vault after',
            unit: 'minutes unused · 0 = never',
            min: 0,
            max: 240,
            what: 'Kept by the vault itself, not by a timer in a screen: every way into it '
                'checks the clock first, so a bug in the interface cannot leave it open.',
            onChanged: (v) => ground.saveConfig(_with(c, autoLockMinutes: v)),
          ),
        _Card(
          title: 'Encrypted local credential storage',
          what: 'A provider key has two homes and no third: sealed inside the vault when one is '
              'open, or in memory for this run when there is none. Never a file in the clear, '
              'and never returned to the interface — there is no call in the whole contract '
              'that gives one back.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in ground.providers.where((p) => p.credentialState != CredentialState.missing))
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '${p.label} · ${switch (p.credentialState) {
                      CredentialState.encryptedInVault => 'sealed in the vault',
                      CredentialState.sessionOnly => 'in memory, gone when the app closes',
                      CredentialState.missing => 'no key stored',
                    }}',
                    style: Zc.small,
                  ),
                ),
              if (ground.providers.every((p) => p.credentialState == CredentialState.missing))
                Text('No provider holds a credential.', style: Zc.small.copyWith(color: Zc.ink4)),
            ],
          ),
        ),
        _Card(
          title: 'Device-bound protection',
          what: 'Not built yet. A key tied to this device’s own authentication would sit '
              'above the layer above, without changing what is stored — the same records, one '
              'more lock.',
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- pieces

Settings _with(
  Settings c, {
  bool? scanOnImport,
  int? revealSeconds,
  int? autoLockMinutes,
  String? packId,
  String? language,
  bool? firstRunDone,
}) =>
    Settings(
      scanOnImport: scanOnImport ?? c.scanOnImport,
      revealSeconds: revealSeconds ?? c.revealSeconds,
      autoLockMinutes: autoLockMinutes ?? c.autoLockMinutes,
      packId: packId ?? c.packId,
      language: language ?? c.language,
      firstRunDone: firstRunDone ?? c.firstRunDone,
      // Where the handle between the two columns was left. No screen here
      // changes it; it travels so that saving a setting does not move it.
      originalPanePercent: c.originalPanePercent,
      columnsInStep: c.columnsInStep,
      // **Carried, never set** (046/K). This helper is «change one setting»,
      // and writing a literal here would mean that saving the reveal timer
      // re-opened a column the person had closed — the app changing a state
      // only a press may change, which is the one thing the rule forbids.
      safeColumnOpen: c.safeColumnOpen,
      reviewPanelWide: c.reviewPanelWide,
      sessionOnly: c.sessionOnly,
    );

class _Title extends StatelessWidget {
  const _Title(this.title, this.what);

  final String title;
  final String what;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Zc.h1),
            const SizedBox(height: 7),
            Text(what, style: Zc.body),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.what, required this.child});

  final String title;
  final String what;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: Zc.panel(fill: Zc.card, radius: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink)),
            const SizedBox(height: 5),
            Text(what, style: Zc.small),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );
}

/// Something that is not a setting, and says why it is not.
class _Fixed extends StatelessWidget {
  const _Fixed({required this.title, required this.what});

  final String title;
  final String what;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: Zc.panel(fill: Zc.warmCard, edge: Zc.lineSoft, radius: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: Zc.ink4),
                const SizedBox(width: 7),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink2)),
              ],
            ),
            const SizedBox(height: 5),
            Text(what, style: Zc.small),
          ],
        ),
      );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.on,
    required this.title,
    required this.what,
    required this.onChanged,
  });

  final bool on;
  final String title;
  final String what;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(17, 13, 13, 13),
        decoration: Zc.panel(fill: Zc.card, radius: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink)),
                  const SizedBox(height: 4),
                  Text(what, style: Zc.small),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Switch(value: on, activeThumbColor: Zc.clay, onChanged: onChanged),
          ],
        ),
      );
}

class _Number extends StatelessWidget {
  const _Number({
    required this.value,
    required this.title,
    required this.unit,
    required this.what,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final String title;
  final String unit;
  final String what;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: Zc.panel(fill: Zc.card, radius: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink)),
                ),
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  color: Zc.ink3,
                  onPressed: value > min ? () => onChanged(_step(value, -1)) : null,
                ),
                Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Zc.clayDeep)),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  color: Zc.ink3,
                  onPressed: value < max ? () => onChanged(_step(value, 1)) : null,
                ),
                Flexible(
                  child: Text(unit, style: Zc.small.copyWith(color: Zc.ink4), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(what, style: Zc.small),
          ],
        ),
      );

  int _step(int from, int by) {
    final step = from >= 60 ? 15 : (from >= 20 ? 5 : 1);
    return (from + by * step).clamp(min, max);
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: on ? Zc.river : Zc.ink4, shape: BoxShape.circle),
      );
}

class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: on ? Zc.clayWash : Zc.paper,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: on ? Zc.clayEdge : Zc.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? Zc.clayDeep : Zc.ink2,
              ),
            ),
          ),
        ),
      );
}


/// A technical fact about a card: its name and its value, small and plain.
///
/// «OpenAI-compatible» lives here — it is how Z Privacy talks to the service,
/// which is worth knowing when you are typing an endpoint, and answers
/// nothing at all when you are choosing a route.
class _Spec extends StatelessWidget {
  const _Spec(this.name, this.value);

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(name, style: Zc.tiny.copyWith(color: Zc.ink4, letterSpacing: 0)),
        ),
        Expanded(
          child: Text(value, style: Zc.tiny.copyWith(fontFamily: Zc.mono, letterSpacing: 0)),
        ),
      ],
    );
  }
}

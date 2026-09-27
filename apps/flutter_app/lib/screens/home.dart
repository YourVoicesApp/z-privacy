// Home — what stays on this device, and what leaves it.
//
// Every number on this screen was reported by z_core.
//
// Three acts and one sentence, by the owner's decision of 27 September. There is
// deliberately **no list of past conversations**: a session lives in memory and
// ends with the app, while the vault and the profiles are the permanent things.
// Saving conversations would open a row of questions of its own — the original
// or only the safe version, under which key, what happens to old tokens, can a
// person erase every trace — and those deserve a stage of their own rather than
// a feature slipped in here.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.ground,
    required this.onImport,
    required this.onType,
    required this.onVault,
    required this.version,
  });

  final Ground ground;
  final VoidCallback onImport;
  final VoidCallback onType;
  final VoidCallback onVault;
  final String version;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ground,
      builder: (context, _) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(34, 40, 34, 40),
              children: [
                Row(
                  children: [
                    const ZMark(size: 36),
                    const SizedBox(width: 12),
                    const Text('Z Privacy', style: Zc.h1),
                    const Spacer(),
                    Text(version, style: Zc.tiny.copyWith(fontFamily: Zc.mono)),
                  ],
                ),
                const SizedBox(height: 26),
                const Text('What stays on this device, and what leaves it.', style: Zc.h2),
                const SizedBox(height: 10),
                const Text(
                  'Bring in a document and it is scanned before you read it. What the scanner is '
                  'sure of is already protected; what it is unsure of it asks you about. Then you '
                  'see the exact text that will go.',
                  style: Zc.body,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 11,
                  runSpacing: 11,
                  children: [
                    ZButton(label: 'Import a document', filled: true, icon: Icons.description_outlined, onPressed: onImport),
                    ZButton(label: 'New private session', icon: Icons.edit_outlined, onPressed: onType),
                    ZButton(label: 'Open Z Vault', icon: Icons.lock_outline, tint: Zc.river, onPressed: onVault),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'PDF · Word · TXT to begin with.   Nothing is uploaded to be read.   '
                  'Conversations are not saved after you close the app.',
                  style: Zc.small.copyWith(color: Zc.ink4),
                ),
                const SizedBox(height: 30),
                if (ground.trouble != null) ...[Trouble(ground.trouble!), const SizedBox(height: 18)],
                _ground(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The four facts that decide what a scan can do today. All four from Rust.
  Widget _ground(BuildContext context) {
    final vault = switch (ground.vault) {
      VaultState.unlocked => ('${ground.entityCount}', 'identities the app knows, holding ${ground.valueCount} values'),
      VaultState.locked => ('Locked', 'the vault layer is skipped — rules and the pack still run'),
      VaultState.absent => ('None', 'no vault on this device yet — names are not recognised'),
    };
    final tint = ground.vault == VaultState.unlocked ? Zc.river : Zc.ink4;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: Zc.panel(fill: Zc.card),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Tally(value: vault.$1, what: 'Z Vault — ${vault.$2}', tint: tint)),
          _divider(),
          Expanded(
            flex: 2,
            child: Tally(
              value: '${ground.profiles.length}',
              what: ground.vault == VaultState.unlocked
                  ? 'Profiles — one dictionary per client'
                  : 'Profiles — readable when the vault is open',
            ),
          ),
          _divider(),
          Expanded(
            flex: 2,
            child: Tally(
              value: '${ground.connectedProviders}',
              what: 'AI providers connected of ${ground.providers.length} — each receives the safe version only',
            ),
          ),
          _divider(),
          Expanded(
            flex: 2,
            child: Tally(
              value: ground.packs.isEmpty ? '—' : ground.packs.first.id.toUpperCase(),
              what: ground.packs.isEmpty
                  ? 'No privacy pack installed'
                  : '${ground.packs.first.label} · scan on import',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: Zc.lineSoft,
      );

}

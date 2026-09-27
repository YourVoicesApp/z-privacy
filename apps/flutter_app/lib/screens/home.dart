// Home — what stays on this device, and what leaves it.
//
// Every number on this screen was reported by z_core. Where the core has nothing
// to report, the screen says so in words instead of showing a plausible number:
// the list of past conversations is the clear case — nothing is stored between
// runs yet, so Home says that rather than drawing five rows of invented history.
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
    required this.version,
  });

  final Ground ground;
  final VoidCallback onImport;
  final VoidCallback onType;
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
                Row(
                  children: [
                    ZButton(label: 'Import a document', filled: true, icon: Icons.description_outlined, onPressed: onImport),
                    const SizedBox(width: 11),
                    ZButton(label: 'New private chat', icon: Icons.edit_outlined, onPressed: onType),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'PDF · Word · TXT to begin with.   Nothing is uploaded to be read.',
                  style: Zc.small.copyWith(color: Zc.ink4),
                ),
                const SizedBox(height: 30),
                if (ground.trouble != null) ...[Trouble(ground.trouble!), const SizedBox(height: 18)],
                _ground(context),
                const SizedBox(height: 22),
                _conversations(),
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

  /// The boards show a list of local conversations here. The core keeps none
  /// between runs, so this says that instead of showing history that is not there.
  Widget _conversations() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: Zc.panel(fill: Zc.warmCard, edge: Zc.lineSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Local conversations'),
          const SizedBox(height: 9),
          Text(
            'A conversation lives while the app is open and is not written anywhere. '
            'Nothing from an earlier run is listed here because nothing was kept — '
            'the vault is the only file this app writes.',
            style: Zc.small,
          ),
        ],
      ),
    );
  }
}

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.ground,
    required this.onImport,
    required this.onType,
    required this.onVault,
    required this.onSettings,
    required this.version,
  });

  final Ground ground;

  /// The **+**: choose a file. The language is asked afterwards, because by
  /// then there is a document to ask about.
  final VoidCallback onImport;

  /// What was typed or pasted, opened with the pack the settings already hold.
  /// No question before it: a person who writes a sentence is not asking to be
  /// interviewed.
  final void Function(String text) onType;
  final VoidCallback onVault;
  final VoidCallback onSettings;
  final String version;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.onType(text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ground = widget.ground;
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
                    // The stamp is three times the length of «z_core 0.1.0», so
                    // it is given room to shrink rather than room to overflow —
                    // the workspace top bar taught that lesson on 3 October.
                    Flexible(
                      child: Text(
                        widget.version,
                        style: Zc.tiny.copyWith(fontFamily: Zc.mono),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.tune, size: 18),
                      color: Zc.ink3,
                      onPressed: widget.onSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const Text('What stays on this device, and what leaves it.', style: Zc.h2),
                const SizedBox(height: 10),
                const Text(
                  'Write or paste what you want to send an AI. It is scanned before you read it: '
                  'what the scanner is sure of is already protected, what it is unsure of it asks '
                  'you about, and then you see the exact text that would go.',
                  style: Zc.body,
                ),
                const SizedBox(height: 18),
                // **The composer is the home.** The owner, 6 October: the
                // writing screen is the main screen, and a file is a «+» as it
                // is in a chat. So the box is the first thing on the page and
                // the first thing with the focus — a person who opened this
                // app to paste a letter can paste it.
                Container(
                  decoration: Zc.panel(fill: Zc.card, radius: 12),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _text,
                        focusNode: _focus,
                        autofocus: true,
                        minLines: 5,
                        maxLines: 12,
                        style: Zc.document.copyWith(fontSize: 14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Write or paste your text here…',
                          hintStyle: Zc.body.copyWith(color: Zc.ink4),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // The file, as a chat offers one.
                          Tooltip(
                            message: 'Add a document — PDF, Word or text',
                            child: IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              color: Zc.clay,
                              onPressed: widget.onImport,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PDF · Word · TXT',
                            style: Zc.tiny.copyWith(color: Zc.ink4),
                          ),
                          const Spacer(),
                          // Flexible, because the disabled button carries a
                          // sentence beside it and a narrow window must wrap it
                          // rather than push it off the edge — the same lesson
                          // the top bar taught on 3 October.
                          Flexible(
                            child: ZButton(
                              label: 'Open and scan',
                              filled: true,
                              icon: Icons.shield_outlined,
                              onPressed: _text.text.trim().isEmpty ? null : _open,
                              hint: _text.text.trim().isEmpty ? 'Write or paste something first' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Nothing is uploaded to be read.   Conversations are not saved after you close '
                  'the app.',
                  style: Zc.small.copyWith(color: Zc.ink4),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ZButton(
                    label: 'Open Z Vault',
                    icon: Icons.lock_outline,
                    tint: Zc.river,
                    onPressed: widget.onVault,
                  ),
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
    final ground = widget.ground;
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
          Expanded(flex: 2, child: _pack(ground)),
        ],
      ),
    );
  }

  /// The pack **in use**, and what the app will actually do with it.
  ///
  /// This card used to read `packs.first` and say «scan on import» whatever the
  /// setting was. Both were true today by accident — one pack installed, the
  /// setting on by default — and both would have become quiet untruths the day
  /// either changed. The same family as «0 tries left».
  Widget _pack(Ground ground) {
    if (ground.packs.isEmpty) {
      return const Tally(value: '—', what: 'No privacy pack installed');
    }
    final id = ground.config?.packId;
    final chosen = ground.packs.firstWhere(
      (p) => p.id == id,
      orElse: () => ground.packs.first,
    );
    final scans = ground.config?.scanOnImport ?? true;
    return Tally(
      value: chosen.id.toUpperCase(),
      what: '${chosen.label} · ${scans ? "scan on import" : "scan when you ask"}',
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        color: Zc.lineSoft,
      );

}

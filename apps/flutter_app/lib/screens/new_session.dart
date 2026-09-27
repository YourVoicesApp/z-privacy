// New session — the one screen that exists because a scan needs a ground to stand
// on: which profile's identities are loaded, and which pack's rules run.
//
// Both lists come from the core. If the vault is locked there are no profiles to
// offer, and the screen says what that costs rather than hiding the choice.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

class NewSessionSheet extends StatefulWidget {
  const NewSessionSheet({super.key, required this.ground, required this.typing});

  final Ground ground;

  /// True when the user chose «new private chat»: there is no file, so the sheet
  /// also takes the text.
  final bool typing;

  @override
  State<NewSessionSheet> createState() => _NewSessionSheetState();
}

/// What the sheet hands back: enough to open a session, and the text if any.
class SessionWish {
  const SessionWish({required this.profileId, required this.packId, this.text});

  final String? profileId;
  final String packId;
  final String? text;
}

class _NewSessionSheetState extends State<NewSessionSheet> {
  String? _profileId;
  String? _packId;
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _packId = widget.ground.packs.isNotEmpty ? widget.ground.packs.first.id : null;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ground;
    final canGo = _packId != null && (!widget.typing || _text.text.trim().isNotEmpty);

    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.typing ? 'New private chat' : 'Import a document', style: Zc.h2),
              const SizedBox(height: 6),
              Text(
                'The scan runs the moment this opens — the document is never once '
                'unprotected in front of you.',
                style: Zc.small,
              ),
              const SizedBox(height: 22),
              const Eyebrow('Privacy pack'),
              const SizedBox(height: 8),
              if (g.packs.isEmpty)
                const Trouble('No privacy pack is installed, so only the general rules would run.')
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in g.packs)
                      _Choice(
                        label: p.label,
                        chosen: _packId == p.id,
                        onTap: () => setState(() => _packId = p.id),
                      ),
                  ],
                ),
              const SizedBox(height: 7),
              Text(
                'A detection engine, not the language of the interface.',
                style: Zc.tiny.copyWith(color: Zc.ink4, letterSpacing: 0),
              ),
              const SizedBox(height: 20),
              const Eyebrow('Profile'),
              const SizedBox(height: 8),
              if (g.vault != VaultState.unlocked)
                Text(
                  g.vault == VaultState.locked
                      ? 'The vault is locked, so no client dictionary is loaded. The general '
                          'rules and the pack still run — an IBAN is still caught, but not whose.'
                      : 'There is no vault on this device yet, so nothing is recognised by name.',
                  style: Zc.small,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Choice(
                      label: 'Everywhere',
                      chosen: _profileId == null,
                      onTap: () => setState(() => _profileId = null),
                    ),
                    for (final p in g.profiles)
                      _Choice(
                        label: p.name,
                        chosen: _profileId == p.id,
                        onTap: () => setState(() => _profileId = p.id),
                      ),
                  ],
                ),
              if (widget.typing) ...[
                const SizedBox(height: 20),
                const Eyebrow('Your text'),
                const SizedBox(height: 8),
                TextField(
                  controller: _text,
                  maxLines: 7,
                  minLines: 5,
                  onChanged: (_) => setState(() {}),
                  style: Zc.document,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Zc.card,
                    hintText: 'Write or paste what you want to ask about…',
                    hintStyle: Zc.body.copyWith(color: Zc.ink4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Zc.line),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  ZButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  ZButton(
                    label: widget.typing ? 'Open and scan' : 'Choose a file',
                    filled: true,
                    onPressed: canGo
                        ? () => Navigator.of(context).pop(SessionWish(
                              profileId: _profileId,
                              packId: _packId!,
                              text: widget.typing ? _text.text : null,
                            ))
                        : null,
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

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.chosen, required this.onTap});

  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chosen ? Zc.clayWash : Zc.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: chosen ? Zc.clayEdge : Zc.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: chosen ? FontWeight.w600 : FontWeight.w500,
              color: chosen ? Zc.clayDeep : Zc.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

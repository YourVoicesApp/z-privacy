// One identity, opened: its values, their spellings, and what to do with each.
//
// The shape the owner asked for, top to bottom:
//
//   Client: Nordstern
//     Company  Nordstern Consulting GmbH   aliases: Nordstern · Nordstern Consulting
//     Person   Thomas Müller               aliases: Herr Müller · T. Müller
//     IBAN     DE…
//
// A value is hidden until asked for, like everywhere else in this app, and is
// hidden again when this screen is left.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/vault_forms.dart';
import 'package:zprivacy/core/messages.dart';

class EntityDetail extends StatefulWidget {
  const EntityDetail({
    super.key,
    required this.ground,
    required this.card,
    required this.onChanged,
    required this.onGone,
  });

  final Ground ground;
  final EntityCard card;
  final Future<void> Function() onChanged;
  final VoidCallback onGone;

  @override
  State<EntityDetail> createState() => _EntityDetailState();
}

class _EntityDetailState extends State<EntityDetail> {
  /// Values shown right now, with their spellings. Only in this screen's head,
  /// and cleared when it closes.
  final Map<int, RevealedValue> _shown = {};

  /// Milliseconds the **core** says are left. Read, never counted down here.
  int _remaining = 0;

  /// Asks the core once a second. This ticker draws a number for a person to
  /// read; it has no authority to keep a value on screen. When the core
  /// answers 0 — or answers about a different value — what is shown is
  /// dropped in the same frame.
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _shown.clear();
    unawaited(z.hideValue());
    super.dispose();
  }

  Future<void> _reveal(int valueId) async {
    try {
      final v = await z.revealValue(entity: widget.card.id, valueId: valueId);
      if (!mounted) return;
      setState(() {
        // One at a time, matching the core.
        _shown
          ..clear()
          ..[valueId] = v;
        _remaining = v.ttlMs;
      });
      _watch();
    } on ApiError catch (e) {
      if (mounted) setState(() => widget.ground.trouble = humanMessage(e));
    }
  }

  void _watch() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      final state = await z.revealState();
      if (!mounted) return;
      final over = state.remainingMs == 0 ||
          state.valueId == null ||
          !_shown.containsKey(state.valueId);
      setState(() {
        _remaining = state.remainingMs;
        if (over) _shown.clear();
      });
      if (over) {
        _tick?.cancel();
        _tick = null;
      }
    });
  }

  Future<void> _hideNow() async {
    _tick?.cancel();
    _tick = null;
    await z.hideValue();
    if (mounted) setState(() {
      _shown.clear();
      _remaining = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entityKindLabel(card.kind)} · ${card.label}', style: Zc.h2),
                  const SizedBox(height: 5),
                  Text(
                    card.values.isEmpty
                        ? 'No values yet. A value is what the scanner matches — a name, a company, '
                            'an IBAN.'
                        : '${plural(card.values.length, "value")}, each with its own spellings '
                            'and its own policy.',
                    style: Zc.small,
                  ),
                ],
              ),
            ),
            ZButton(label: 'Rename', onPressed: () => _rename(card)),
            const SizedBox(width: 8),
            ZButton(label: 'Move', onPressed: () => _move(card)),
            const SizedBox(width: 8),
            ZButton(label: 'Delete', tint: Zc.amber, onPressed: () => _deleteEntity(card)),
          ],
        ),
        const SizedBox(height: 18),
        for (final v in card.values) _value(card, v),
        const SizedBox(height: 6),
        ZButton(
          label: 'Add a value',
          filled: true,
          icon: Icons.add,
          onPressed: () async {
            final made = await showDialog<bool>(
              context: context,
              builder: (_) => ValueForm(entity: card.id),
            );
            if (made == true) await widget.onChanged();
          },
        ),
      ],
    );
  }

  Widget _value(EntityCard card, ValueRow v) {
    final shown = _shown[v.id];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: Zc.panel(fill: Zc.card, radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: Zc.clayWash, borderRadius: BorderRadius.circular(5)),
                child: Text(
                  kindName(v.kind),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Zc.clayDeep),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                switch (v.policy) {
                  Policy.always => 'Always protect',
                  Policy.suggest => 'Suggest',
                  Policy.manual => 'Kept, not hunted',
                },
                style: Zc.small.copyWith(color: Zc.ink4),
              ),
              const Spacer(),
              Text(
                plural(v.aliases, 'spelling'),
                style: Zc.small.copyWith(color: Zc.ink4),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ------------------------------------------------ the value line
          //
          // **Expiry changes the content, never the geometry.** The row keeps
          // its height and its controls keep their places, so a TTL running
          // out cannot move a button out from under the pointer. That is not
          // tidiness: in the human run a press meant for «Edit» landed on
          // nothing, twice, because the buttons only existed while revealed.
          SizedBox(
            // Fixed so the line does not change height between masked and
            // revealed. 34 overflowed the document style by 7.5px — found by
            // running it, and the stripe was drawn over the value itself.
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: shown == null
                      ? Text(
                          '••••••••••••',
                          style: Zc.document.copyWith(color: Zc.ink4, letterSpacing: 2),
                        )
                      : SelectableText(
                          shown.value,
                          maxLines: 1,
                          style: Zc.document.copyWith(fontWeight: FontWeight.w600),
                        ),
                ),
                const SizedBox(width: 10),
                // The time the **core** reports, drawn for a person to read.
                Text(
                  shown == null ? 'Hidden' : 'Revealed · ${(_remaining / 1000).ceil()}s',
                  key: Key('reveal-state-${v.id}'),
                  style: Zc.tiny.copyWith(
                    letterSpacing: 0,
                    color: shown == null ? Zc.ink4 : Zc.river,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          // One row of controls, always the same, always in the same order.
          // Only the first one changes its word.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                // A fixed width so «Reveal» and «Hide» occupy the same space
                // and nothing after them shifts when the word changes. Sized
                // for the longer word **with its icon** — 92 looked right and
                // overflowed by 47, which a widget test caught rather than a
                // person.
                width: 142,
                child: ZButton(
                  label: shown == null ? 'Reveal' : 'Hide',
                  icon: shown == null ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  onPressed: shown == null ? () => _reveal(v.id) : _hideNow,
                ),
              ),
              ZButton(
                label: 'Add a spelling',
                onPressed: () => _addAlias(card, v),
              ),
              ZButton(
                label: 'Edit',
                onPressed: () async {
                  final saved = await showDialog<bool>(
                    context: context,
                    builder: (_) => ValueForm(entity: card.id, existing: v),
                  );
                  if (saved == true) {
                    await _hideNow();
                    await widget.onChanged();
                  }
                },
              ),
              ZButton(
                label: 'Delete',
                tint: Zc.amber,
                onPressed: () => _run(() => z.deleteValue(entity: card.id, valueId: v.id)),
              ),
            ],
          ),
          // The spellings sit **below** the controls, so their appearing and
          // disappearing cannot move a button either.
          if (shown != null && shown.aliases.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Eyebrow('Also written'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final a in shown.aliases)
                  _Alias(
                    text: a,
                    onRemove: () => _run(() => z.removeValueAlias(
                          entity: card.id,
                          valueId: v.id,
                          alias: a,
                        )),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// One path for every edit: do it in the core, then read everything back.
  Future<void> _run(Future<void> Function() act) async {
    final bad = await widget.ground.vaultEdit(act);
    if (bad == null) {
      setState(_shown.clear);
      await widget.onChanged();
    }
  }

  Future<void> _addAlias(EntityCard card, ValueRow v) async {
    final text = await _ask(
      title: 'Another spelling',
      what: 'The same value written differently — «Herr Müller», «T. Müller». Every spelling '
          'keeps the same token, so the model reads one person and not three.',
      hint: 'Herr Müller',
    );
    if (text == null || text.trim().isEmpty) return;
    await _run(() => z.addValueAlias(entity: card.id, valueId: v.id, alias: text));
  }

  Future<void> _rename(EntityCard card) async {
    final text = await _ask(title: 'Rename', what: 'What to call this identity.', hint: card.label);
    if (text == null || text.trim().isEmpty) return;
    await _run(() => z.renameEntity(entityId: card.id, label: text));
  }

  Future<void> _move(EntityCard card) async {
    final chosen = await showDialog<_Move>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Zc.paper,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Move this identity', style: Zc.h2),
                const SizedBox(height: 6),
                Text(
                  'An identity in a profile is loaded only when that profile is open. One that '
                  'belongs everywhere is always loaded.',
                  style: Zc.small,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    ActionChip(
                      label: const Text('Everywhere'),
                      onPressed: () => Navigator.of(context).pop(const _Move(null)),
                    ),
                    for (final p in widget.ground.profiles)
                      ActionChip(
                        label: Text(p.name),
                        onPressed: () => Navigator.of(context).pop(_Move(p.id)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await _run(() => z.moveEntity(entityId: card.id, profileId: chosen.id));
  }

  Future<void> _deleteEntity(EntityCard card) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Zc.paper,
        title: const Text('Delete this identity?', style: Zc.h2),
        content: Text(
          '«${card.label}» and its ${plural(card.values.length, "value")} are removed from the vault. '
          'Documents already protected keep their tokens; the next document will not '
          'recognise these values again.',
          style: Zc.body,
        ),
        actions: [
          ZButton(label: 'Keep it', onPressed: () => Navigator.of(context).pop(false)),
          ZButton(label: 'Delete', filled: true, tint: Zc.amber, onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (sure != true) return;
    final bad = await widget.ground.vaultEdit(() => z.deleteEntity(entityId: card.id));
    if (bad == null) widget.onGone();
  }

  Future<String?> _ask({required String title, required String what, required String hint}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Zc.paper,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Zc.h2),
                const SizedBox(height: 6),
                Text(what, style: Zc.small),
                const SizedBox(height: 14),
                TextField(
                  controller: c,
                  autofocus: true,
                  onSubmitted: (v) => Navigator.of(context).pop(v),
                  decoration: InputDecoration(
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
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    ZButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
                    const Spacer(),
                    ZButton(label: 'Save', filled: true, onPressed: () => Navigator.of(context).pop(c.text)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Move {
  const _Move(this.id);

  final String? id;
}

class _Alias extends StatelessWidget {
  const _Alias({required this.text, required this.onRemove});

  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
      decoration: BoxDecoration(
        color: Zc.riverWash,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Zc.river.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 12.5, color: Zc.river, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 13, color: Zc.river),
            ),
          ),
        ],
      ),
    );
  }
}

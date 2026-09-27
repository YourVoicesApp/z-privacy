// Review Before Send — the last screen before anything leaves the device, and
// the three ways out of it.
//
// The boards and the owner both insist on the same thing here: Z Privacy must
// not look like a product for people who know what an API key is. So this sheet
// offers three doors, and the first one needs no account at all:
//
//   1. Copy the safe text        take it to any model yourself, paste the answer back
//   2. A connected provider      the request goes from here
//   3. A model on this machine   no key, no account, nothing leaves the machine
//
// The text shown is the payload the core built. It is not re-assembled here, and
// what is copied to the clipboard is the same string that would be sent.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';

class SendSheet extends StatefulWidget {
  const SendSheet({super.key, required this.bench, required this.ground});

  final Workbench bench;
  final Ground ground;

  @override
  State<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<SendSheet> {
  final _pasted = TextEditingController();
  bool _copied = false;
  bool _pasting = false;
  String? _trouble;

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final payload = bench.payload;
    final open = payload?.openSuggestions ?? 0;
    final connected = widget.ground.providers.where((p) => p.connected).toList();

    return Dialog(
      backgroundColor: Zc.paper,
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Review before send', style: Zc.h2),
                        const SizedBox(height: 4),
                        Text(
                          payload == null
                              ? 'There is nothing to send.'
                              : '${payload.protectedCount} values replaced · '
                                  '${payload.text.length} characters would leave this device.',
                          style: Zc.small,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Zc.ink3,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Zc.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (open > 0) ...[
                      Trouble(
                        open == 1
                            ? 'One suggestion is still open. It stands in the text below as written, '
                                'and nothing can be sent until you answer it. There is no «send anyway».'
                            : '$open suggestions are still open. They stand in the text below as '
                                'written, and nothing can be sent until you answer them. There is no '
                                '«send anyway».',
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Eyebrow('This is what would leave'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: Zc.panel(fill: Zc.card, radius: 10),
                      child: payload == null
                          ? const Text('Nothing is built.', style: Zc.small)
                          : SafeText(text: payload.text, chips: false),
                    ),
                    if (_trouble != null) ...[const SizedBox(height: 14), Trouble(_trouble!)],
                    const SizedBox(height: 22),
                    _door(
                      title: 'Use AI yourself',
                      what: 'Copy the text above, paste it into any model you like, and bring the '
                          'answer back here. Restoring works the same either way — no account, no key.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ZButton(
                                label: _copied ? 'Copied' : 'Copy safe text',
                                icon: _copied ? Icons.check : Icons.copy_all_outlined,
                                onPressed: payload == null
                                    ? null
                                    : () async {
                                        await Clipboard.setData(ClipboardData(text: payload.text));
                                        if (mounted) setState(() => _copied = true);
                                      },
                              ),
                              const SizedBox(width: 10),
                              ZButton(
                                label: _pasting ? 'Hide the box' : 'Paste AI answer',
                                icon: Icons.content_paste_go,
                                onPressed: () => setState(() => _pasting = !_pasting),
                              ),
                            ],
                          ),
                          if (_pasting) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pasted,
                              maxLines: 8,
                              minLines: 4,
                              style: Zc.document.copyWith(fontSize: 13.5),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Zc.card,
                                hintText: 'Paste the model’s answer here…',
                                hintStyle: Zc.body.copyWith(color: Zc.ink4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Zc.line),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ZButton(
                              label: 'Restore the real values',
                              filled: true,
                              onPressed: () async {
                                final bad = await bench.pasteAnswer(_pasted.text);
                                if (!context.mounted) return;
                                if (bad == null) {
                                  Navigator.of(context).pop(true);
                                } else {
                                  setState(() => _trouble = bad);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _door(
                      title: connected.isEmpty ? 'Send from here' : 'Send from here',
                      what: connected.isEmpty
                          ? 'No provider is connected. A provider with no key is shown here rather '
                              'than hidden — open Providers to connect one, or use the door above.'
                          : 'The request goes from this app. Only the text above travels; the '
                              'provider still sees the ordinary facts of a connection — your address, '
                              'the time, the model.',
                      child: connected.isEmpty
                          ? const SizedBox.shrink()
                          : Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: [
                                for (final p in connected)
                                  ZButton(
                                    label: bench.sending ? 'Sending…' : 'Send to ${p.label}',
                                    filled: true,
                                    icon: Icons.send_outlined,
                                    onPressed: open > 0 || bench.sending || payload == null
                                        ? null
                                        : () async {
                                            final bad = await bench.send(p.id);
                                            if (!context.mounted) return;
                                            if (bad == null) {
                                              Navigator.of(context).pop(true);
                                            } else {
                                              setState(() => _trouble = bad);
                                            }
                                          },
                                    hint: open > 0 ? 'Answer the review first' : null,
                                  ),
                              ],
                            ),
                    ),
                    if (connected.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final p in connected)
                        Text(
                          '${p.label} · ${p.model} · ${p.baseUrl}'
                          '${p.sessionOnly ? "  (key kept for this run only)" : ""}',
                          style: Zc.tiny.copyWith(letterSpacing: 0),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _door({required String title, required String what, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: Zc.panel(fill: Zc.warmCard, edge: Zc.lineSoft, radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink)),
          const SizedBox(height: 5),
          Text(what, style: Zc.small),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

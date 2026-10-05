// Review Before Send — the last screen before anything leaves the device, and
// the three ways out of it.
//
// The boards and the owner both insist on the same thing here: Z Privacy must
// not look like a product for people who know what an API key is. So this sheet
// offers three doors, and the first one needs no account at all:
//
//   1. Copy Protected            take the SafePayload to any model yourself, paste the answer back
//   2. A connected provider      the request goes from here
//   3. A model on this machine   no key, no account, nothing leaves the machine
//
// The text shown is the payload the core built. It is not re-assembled here, and
// what is copied to the clipboard is the same string that would be sent.
//
// Layout is a window, not a font size. At 1280×720 the sheet is:
//
//   header   fixed
//   body     the only scroll — preview on the first page, the three doors on the
//            second. The payload never shares a scroller with the actions.
//   footer   Cancel / Back / Continue, always on screen
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/connect_form.dart';
import 'package:zprivacy/widgets/document_text.dart';

class SendSheet extends StatefulWidget {
  const SendSheet({super.key, required this.bench, required this.ground});

  final Workbench bench;
  final Ground ground;

  /// The payload preview — the only region that accepts a wheel on the first page.
  static const previewKey = ValueKey<String>('send-sheet-preview');

  /// Cancel / Back / Continue. Never inside the preview scroller.
  static const footerKey = ValueKey<String>('send-sheet-footer');

  @override
  State<SendSheet> createState() => _SendSheetState();
}

enum _SheetPage { review, ai }

class _SendSheetState extends State<SendSheet> {
  @override
  void initState() {
    super.initState();
    // The catalogue, at the moment it is needed: a chooser that opens empty is
    // a chooser nobody can use.
    unawaited(widget.bench.refreshModels());
  }

  final _pasted = TextEditingController();
  final _previewScroll = ScrollController();
  bool _copied = false;
  bool _pasting = false;

  /// Read the clipboard and put it in the answer field. Nothing else.
  ///
  /// **Paste is an act of editing, not of processing** (the owner, 29
  /// September). It creates no answer, restores nothing, touches no vault and
  /// opens no socket — and it does not change which payload the answer will
  /// be tied to, so the F-05 binding is exactly where it was.
  ///
  /// The button used to only open and close this box, which is why a person
  /// pressed «Paste» and nothing was pasted.
  Future<void> _paste() async {
    String? text;
    try {
      // Read **only** on the press. Nothing watches the clipboard.
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text;
    } catch (_) {
      // A platform exception is not a sentence. The person is told what
      // happened to them, not what happened to the channel.
      if (mounted) {
        setState(() {
          _pasting = true;
          _trouble = 'Z Privacy could not read the clipboard.';
        });
      }
      return;
    }
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      // The box still opens: they may want to type the answer by hand.
      setState(() {
        _pasting = true;
        _trouble = 'There is no text on the clipboard.';
      });
      return;
    }
    setState(() {
      _pasting = true;
      _trouble = null;
      // Replaced whole, not inserted at the cursor. This field holds one
      // complete answer from a model; it is not a general text editor, and
      // «where did my cursor leave off» is a question it should never raise.
      _pasted.text = text!;
      _pasted.selection = TextSelection.collapsed(offset: text.length);
    });
  }
  String? _trouble;
  _SheetPage _page = _SheetPage.review;

  @override
  void dispose() {
    _pasted.dispose();
    _previewScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final payload = bench.payload;
    final open = payload?.openSuggestions ?? 0;
    return ListenableBuilder(
      listenable: widget.ground,
      builder: (context, _) {
        final connected = widget.ground.providers
            .where((p) => p.connected)
            .toList();

        return Dialog(
          backgroundColor: Zc.paper,
          insetPadding: const EdgeInsets.all(40),
          child: LayoutBuilder(
            builder: (context, incoming) {
              // A bounded height is what lets the body be Expanded and the
              // footer stay put. Capping at 820 keeps the sheet from eating a
              // large window; clamping to the incoming max is what fits 720p.
              final width = incoming.maxWidth.isFinite
                  ? incoming.maxWidth.clamp(0.0, 780.0)
                  : 780.0;
              final height = incoming.maxHeight.isFinite
                  ? incoming.maxHeight.clamp(0.0, 820.0)
                  : 820.0;
              return SizedBox(
                width: width,
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(payload),
                    Container(height: 1, color: Zc.line),
                    Expanded(
                      child: _page == _SheetPage.review
                          ? _preview(payload, open)
                          : _aiDoors(payload, open, connected),
                    ),
                    _footer(context, open: open, payload: payload),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _header(PayloadView? payload) {
    return Padding(
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
    );
  }

  /// Payload only. Suggestions and a trouble line belong here because they
  /// describe the text; the doors do not.
  Widget _preview(PayloadView? payload, int open) {
    return SingleChildScrollView(
      key: SendSheet.previewKey,
      controller: _previewScroll,
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
          if (_trouble != null) ...[
            const SizedBox(height: 14),
            Trouble(_trouble!),
          ],
        ],
      ),
    );
  }

  Widget _aiDoors(
    PayloadView? payload,
    int open,
    List<ProviderFact> connected,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_trouble != null) ...[
            Trouble(_trouble!),
            const SizedBox(height: 14),
          ],
          _door(
            // The three routes are named by **what they mean to a person**,
            // not by the protocol underneath: which AI, and where does it run?
            // «OpenAI-compatible» answers neither of those questions — it is
            // how Z Privacy speaks, and it belongs in the settings beside the
            // endpoint (the owner, 30 September).
            title: 'Manual AI',
            what:
                'Use an AI chat you already have. Copy the text above, paste it into any '
                'model you like, and bring the answer back here. Restoring works the same '
                'either way — no account, no key.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ZButton(
                      label: _copied ? 'Copied' : 'Copy Protected',
                      icon: _copied ? Icons.check : Icons.copy_all_outlined,
                      onPressed: payload == null
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: payload.text),
                              );
                              widget.bench.rememberCopiedPayload();
                              if (mounted) setState(() => _copied = true);
                            },
                    ),
                    ZButton(
                      label: 'Paste AI answer',
                      icon: Icons.content_paste_go,
                      onPressed: _paste,
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
                      final bad = await widget.bench.pasteAnswer(_pasted.text);
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
          if (widget.bench.models.isNotEmpty) _ModelAndMode(bench: widget.bench),
          _door(
            title: 'Direct API',
            what: connected.isEmpty
                ? 'Connect to a remote AI provider with your API credential. Only the text '
                      'above would travel; the provider still sees the ordinary facts of a '
                      'connection — your address, the time, the model.'
                : 'The request goes from this app. Only the text above travels; the '
                      'provider still sees the ordinary facts of a connection — your address, '
                      'the time, the model.',
            child: connected.isEmpty
                ? _connectHere(local: false)
                : Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final p in connected)
                        ZButton(
                          label: widget.bench.sending
                              ? 'Sending…'
                              // The route, not the protocol. And «Local AI»
                              // only when the core says the endpoint really
                              // is on this computer — the word is a promise
                              // about where the text goes.
                              : 'Send to ${p.onThisComputer ? "Local AI" : "Direct API"}',
                          filled: true,
                          icon: Icons.send_outlined,
                          onPressed:
                              open > 0 ||
                                  widget.bench.sending ||
                                  (payload == null && !widget.bench.sendOriginal)
                              ? null
                              : () async {
                                  final bad = await widget.bench.askModel(
                                    p.id,
                                    original: widget.bench.document?.text ?? '',
                                  );
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
                '${p.label} · ${p.model} · ${p.endpoint}'
                '${p.credentialState == CredentialState.sessionOnly ? "  (key kept for this run only)" : ""}',
                style: Zc.tiny.copyWith(letterSpacing: 0),
              ),
            const SizedBox(height: 10),
            _More(
              label: 'Change the address, the model, or the key',
              child: _connectHere(local: false),
            ),
          ],
          const SizedBox(height: 14),
          _door(
            title: 'Local AI',
            what:
                'Use an AI service running on this computer — llama.cpp, Ollama, LM '
                'Studio, anything that answers the same shape. No key, no account, and '
                'the request never leaves this computer. It is the only route that sees '
                'none of the ordinary facts above.',
            child: _More(
              label: 'Set up a local model',
              child: _connectHere(local: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(
    BuildContext context, {
    required int open,
    required PayloadView? payload,
  }) {
    return Container(
      key: SendSheet.footerKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
      decoration: const BoxDecoration(
        color: Zc.paper,
        border: Border(top: BorderSide(color: Zc.line)),
      ),
      child: Row(
        children: [
          ZButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          if (_page == _SheetPage.ai) ...[
            ZButton(
              label: 'Back',
              onPressed: () => setState(() {
                _page = _SheetPage.review;
                _pasting = false;
              }),
            ),
            const SizedBox(width: 10),
          ],
          if (_page == _SheetPage.review)
            ZButton(
              label: 'Continue',
              filled: true,
              onPressed: payload == null || open > 0
                  ? null
                  : () => setState(() => _page = _SheetPage.ai),
            ),
        ],
      ),
    );
  }

  /// The form, for whichever provider row this door is about.
  Widget _connectHere({required bool local}) {
    final rows = widget.ground.providers;
    if (rows.isEmpty)
      return const Text('This build knows no providers.', style: Zc.small);
    return ConnectForm(ground: widget.ground, row: rows.first, local: local);
  }

  Widget _door({
    required String title,
    required String what,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: Zc.panel(fill: Zc.warmCard, edge: Zc.lineSoft, radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Zc.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(what, style: Zc.small),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A fold. The form behind it is for the person who wants it, and out of the
/// way of the person who does not — which is most people, most of the time.
class _More extends StatefulWidget {
  const _More({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  State<_More> createState() => _MoreState();
}

class _MoreState extends State<_More> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Zc.clay,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Zc.clay,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[const SizedBox(height: 10), widget.child],
      ],
    );
  }
}

/// Which model answers, and what travels to it.
///
/// Two choices and no third. The second one is the only place in this app
/// where a person can decide to send their document as it stands, and it says
/// so in those words: «Direct API» already means the route in Z's vocabulary —
/// this app to the provider, with the protected text — so the unredacted mode
/// is never called «direct» on a screen.
class _ModelAndMode extends StatelessWidget {
  const _ModelAndMode({required this.bench});

  final Workbench bench;

  @override
  Widget build(BuildContext context) {
    final available = bench.models.where((m) => m.available).toList();
    final listed = available.isEmpty ? bench.models : available;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: Zc.panel(fill: Zc.card, edge: Zc.line, radius: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Model', style: Zc.tiny.copyWith(color: Zc.ink4)),
          const SizedBox(height: 6),
          // The names come from the core's catalogue. No model is named in
          // this file, which is the point of the catalogue.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: 'As configured',
                on: bench.chosenModel == null,
                onTap: () => bench.chooseModel(null),
              ),
              for (final model in listed)
                _Chip(
                  label: model.displayName,
                  on: bench.chosenModel == model.modelId,
                  onTap: () => bench.chooseModel(model.modelId),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('What travels', style: Zc.tiny.copyWith(color: Zc.ink4)),
          const SizedBox(height: 6),
          Row(
            children: [
              _Chip(
                label: 'Protected text',
                on: !bench.sendOriginal,
                onTap: () => bench.chooseOriginal(false),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'The original text',
                on: bench.sendOriginal,
                warn: true,
                onTap: () => bench.chooseOriginal(true),
              ),
            ],
          ),
          if (bench.sendOriginal) ...[
            const SizedBox(height: 8),
            Text(
              'The document goes as it is written, with your names and numbers in '
              'it. The connection is encrypted; the text is not replaced.',
              style: Zc.small.copyWith(color: Zc.amber),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap, this.warn = false});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final tint = warn ? Zc.amber : Zc.river;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: on ? tint : Zc.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Zc.small.copyWith(
            color: on ? tint : Zc.ink3,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

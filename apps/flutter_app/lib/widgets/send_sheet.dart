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
// **8 October — no key is asked for here.** The owner: «وضعنا إعدادات الذكاء في
// شاشة الإعدادات وبالتالي لا تظهر أثناء العمل أبداً» — the AI settings live in the
// settings screen, so they never appear during work. This sheet used to carry a
// `ConnectForm` — endpoint, model, API key — in four places, and one of them was
// on the page it opens on: a person who pressed ✨AI to choose a model was one
// press from a key form. It carries none now. Each route that needs a credential
// says so in a line and offers the way to the settings panel, which 063 made
// able to stand over the work. The form's one home is `settings.dart`'s
// `_AiRoom`, where it already was — nothing was added there.
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
import 'package:zprivacy/core/protected_pdf.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/core.dart' show coreVersion;
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';

class SendSheet extends StatefulWidget {
  const SendSheet({
    super.key,
    required this.bench,
    required this.ground,
    this.saveFolder,
    this.onSettings,
  });

  final Workbench bench;
  final Ground ground;

  /// The way to the settings panel, which is the one place a provider's
  /// address, model and key are asked for.
  ///
  /// Nullable, and not required as `bench` is, for the reason 063 gave for
  /// `_TopBar`: a surface with nowhere to send the press draws no door rather
  /// than a dead one. Requiring it would have made every test that opens this
  /// sheet pass `() {}` — doors that open nothing, with the compiler enforcing
  /// the lie.
  final VoidCallback? onSettings;

  /// Where «Save as PDF» writes. Null is the product's own place,
  /// `~/Documents/zprivacy`, and nothing in the product passes anything else —
  /// a test gives a temporary folder so that running the tests never writes
  /// into the person's documents.
  final String? saveFolder;

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

  /// Where the last save went, in full. A path is the whole of the answer to
  /// «where did it go», so it is shown whole and not as «Saved».
  String? _savedTo;
  bool _saving = false;

  /// Write the protected text to a file, and say where it went.
  ///
  /// The same text Copy Protected copies, and like Copy it sends nothing. The
  /// numbers in the footer are the core's: the places are
  /// `PayloadView.protected_count`, and a kind is counted only for a token that
  /// actually stands in **this** text — a footer describing the file must be
  /// about the file.
  Future<void> _savePdf(PayloadView payload) async {
    setState(() {
      _saving = true;
      _trouble = null;
      _savedTo = null;
    });
    final byKind = <String, int>{};
    for (final row in widget.bench.tokens) {
      if (!payload.text.contains(row.token)) continue;
      final name = widget.ground.nameOfKind(row.kind);
      byKind[name] = (byKind[name] ?? 0) + 1;
    }
    final out = await saveProtectedPdf(
      text: payload.text,
      documentName: widget.bench.document?.name ?? '',
      folder: widget.saveFolder,
      stamp: PdfStamp(
        build: coreVersion(),
        places: payload.protectedCount,
        byKind: byKind,
        sha256: sha256OfText(payload.text),
      ),
    );
    // **The act is taking the text out, not the clipboard.** `pasteAnswer`
    // refuses with «Copy the safe text first» unless a payload is bound, so
    // without this a person who saved the PDF, took it to a model and came back
    // would be told to do the thing they had just done — and the door above
    // promises that restoring works the same either way. Bound only on a save
    // that happened: a refusal took no text anywhere.
    if (out.path != null) widget.bench.rememberCopiedPayload();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedTo = out.path;
      _trouble = out.trouble;
    });
  }

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
      listenable: Listenable.merge([widget.ground, widget.bench]),
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
          // Provider, model and mode first. A person opens this sheet to
          // decide **who answers**; the text they are about to send is the
          // second question, and the doors are the third.
          _ModelAndMode(bench: widget.bench, ground: widget.ground, onSettings: widget.onSettings),
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
                'Use an AI chat you already have. Take the text above — to the clipboard, '
                'or as a PDF saved on this machine — paste it into any model you like, and '
                'bring the answer back here. Restoring works the same either way — no '
                'account, no key. Neither way sends anything from here.',
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
                    // The second way out, and the only difference from the
                    // first is where the text lands. It writes a file on this
                    // machine; it opens nothing and sends nothing.
                    ZButton(
                      label: _saving ? 'Saving…' : 'Save as PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: payload == null || _saving
                          ? null
                          : () => _savePdf(payload),
                    ),
                    ZButton(
                      label: 'Paste AI answer',
                      icon: Icons.content_paste_go,
                      onPressed: _paste,
                    ),
                  ],
                ),
                if (_savedTo != null) ...[
                  const SizedBox(height: 10),
                  // **Said in words, in full.** «Saved» is not an answer to
                  // «where», and a person who cannot find the file has to
                  // trust us that there is one.
                  Text(
                    'Saved to ${_savedTo!}\n'
                    'The protected text, with the build stamp, the counts and a sha256 of '
                    'that text in the footer. Nothing was sent.',
                    style: Zc.small.copyWith(color: Zc.ink2),
                  ),
                ],
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
                ? _toTheSettings(
                    context,
                    'No provider is connected. The address and the key are given once, in '
                    'Settings — this screen never asks for them.',
                  )
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
                                  // Two doors, and the mode names which. The
                                  // document is an argument of one of them
                                  // only.
                                  final bad = widget.bench.sendOriginal
                                      ? await widget.bench.askModelWithTheOriginal(
                                          p.id,
                                          original: widget.bench.document?.text ?? '',
                                        )
                                      : await widget.bench.askModelProtected(p.id);
                                  if (!context.mounted) return;
                                  if (bad == null) {
                                    Navigator.of(context).pop(true);
                                  } else {
                                    setState(() => _trouble = bad);
                                  }
                                },
                          // **The count, here too** (046/L). This sheet held a
                          // second copy of «Answer the review first» — two
                          // places wording one promise, and the weaker
                          // wording. The workspace's own line now names the
                          // number and offers the way through; this one at
                          // least names the number, because a person reading
                          // it has already left that line behind.
                          hint: open == 1
                              ? '1 question left — answer it first'
                              : open > 1
                                  ? '$open questions left — answer them first'
                                  : null,
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
            _toTheSettings(
              context,
              'The address, the model and the key are changed in Settings.',
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
            child: _toTheSettings(
              context,
              'A model on this computer is set up in Settings — there is no key to give.',
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
              // Open suggestions do not shut this door any more: they shut the
              // send, where the sentence beside the button says so. The reason
              // was once that a person who cannot reach the doors cannot
              // connect a provider either — which stopped being the reason on
              // 8 October, when connecting moved to the settings panel. The
              // door still opens, because choosing **who answers** is not a
              // reward for finishing the review.
              onPressed: payload == null
                  ? null
                  : () => setState(() => _page = _SheetPage.ai),
            ),
        ],
      ),
    );
  }

  /// One line about why there is nothing to fill in here, and the way to the
  /// place where there is.
  ///
  /// **The sheet closes on the way out**, and that is the whole reason this is
  /// a door and not a form. 063's settings are a `Positioned` inside
  /// `ZShell.build`, inside the route `MaterialApp`'s Navigator holds, while
  /// this sheet is a route pushed on top of that one — so with the sheet still
  /// up the panel stands under the modal barrier. Measured on `fcdbabd`: a hit
  /// test at the panel's own door and at the middle of its room both return
  /// false, and the front-most target over the panel is the barrier's
  /// `_RenderColoredBox`. The panel **still paints**, full rect, merely dimmed
  /// — so a person would watch the settings open and find they answer nothing.
  /// That is worse than a door that did not open, and it is why this pops
  /// first and asks second.
  Widget _toTheSettings(BuildContext context, String why) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(why, style: Zc.small.copyWith(color: Zc.ink2)),
        if (widget.onSettings != null) ...[
          const SizedBox(height: 10),
          ZButton(
            label: 'Open Settings',
            icon: Icons.tune,
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSettings!();
            },
          ),
        ],
      ],
    );
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

/// Which model answers, and what travels to it.
///
/// **The whole catalogue, grouped by provider** — not only the models a
/// connected key can reach. A person with one provider connected used to see
/// one provider's models and no sign that this build knows any others, which
/// made the choice look smaller than it is; and the way to connect the rest
/// was two doors further down, under a button that stayed disabled until the
/// review was finished.
///
/// So an unconnected provider's models are shown greyed, with the way in beside
/// the provider's own name rather than two doors away.
///
/// **8 October: the way in is a door, not a form.** The form used to open right
/// here, on the page this sheet opens on — a person who pressed ✨AI to choose a
/// model was one press from an endpoint, a model name and an API key. The owner:
/// the AI settings live in the settings screen and never appear during work. So
/// «Connect in Settings» closes the sheet and opens the panel, which 063 made
/// able to stand over the document.
///
/// The second choice is the only place in this app where a person can decide
/// to send their document as it stands, and it says so in those words:
/// «Direct API» already means the route in Z's vocabulary — this app to the
/// provider, with the protected text — so the unredacted mode is never called
/// «direct» on a screen.
class _ModelAndMode extends StatefulWidget {
  const _ModelAndMode({required this.bench, required this.ground, this.onSettings});

  final Workbench bench;
  final Ground ground;

  /// The way to the settings panel. Null means this chooser has nowhere to send
  /// the press, and then it draws no door rather than a dead one.
  final VoidCallback? onSettings;

  @override
  State<_ModelAndMode> createState() => _ModelAndModeState();
}

class _ModelAndModeState extends State<_ModelAndMode> {
  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    // The catalogue's own order, grouped. Dart neither sorts the providers nor
    // names them: both come from the core.
    final order = <String>[];
    final byProvider = <String, List<ModelDescriptor>>{};
    for (final model in bench.models) {
      byProvider.putIfAbsent(model.providerId, () {
        order.add(model.providerId);
        return <ModelDescriptor>[];
      }).add(model);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: Zc.panel(fill: Zc.card, edge: Zc.line, radius: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Model', style: Zc.tiny.copyWith(color: Zc.ink4)),
          const SizedBox(height: 6),
          _Chip(
            label: 'As configured',
            on: bench.chosenModel == null,
            onTap: () => bench.chooseModel(null),
          ),
          for (final id in order) ...[
            const SizedBox(height: 12),
            _provider(context, id, byProvider[id] ?? const []),
          ],
          if (order.isEmpty) ...[
            const SizedBox(height: 10),
            const Text('This build carries no catalogue.', style: Zc.small),
          ],
          const SizedBox(height: 14),
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

  /// One provider: its name, its models, and — when it is not connected — the
  /// way in, beside the name rather than two doors away.
  Widget _provider(BuildContext context, String id, List<ModelDescriptor> models) {
    final rows = widget.ground.providers.where((p) => p.id == id).toList();
    final row = rows.isEmpty ? null : rows.first;
    // «Connected» is the core's word, and a model that needs no credential is
    // reachable whether or not anything is stored — which is why this reads
    // the catalogue's own `available` rather than deciding for itself.
    final reachable = models.any((m) => m.available);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              row?.label ?? id,
              style: Zc.small.copyWith(
                color: reachable ? Zc.ready : Zc.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
            // The way in, and it leads out of this sheet. Drawn only when
            // there is somewhere for it to lead: a surface that was given no
            // panel shows no door rather than one that does nothing.
            if (!reachable && row != null && widget.onSettings != null) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onSettings!();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Zc.clay,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Connect in Settings',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final model in models)
              _Chip(
                label: model.displayName,
                on: widget.bench.chosenModel == model.modelId,
                // **The colour the owner asked for**: a model whose key is
                // here reads as ready, and one whose key is not stays as it
                // was — greyed, with the door to the settings beside its
                // company's name.
                // `available` is the core's own word for it, so the screen
                // decides nothing.
                ready: model.available,
                // Greyed, not hidden: a model this build knows about is worth
                // seeing even when the key for it is not here yet.
                onTap: model.available ? () => widget.bench.chooseModel(model.modelId) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.warn = false,
    this.ready = false,
  });

  final String label;
  final bool on;

  /// `null` means out of reach: the chip is drawn and says its name, and a
  /// press does nothing because there is nothing behind it yet.
  final VoidCallback? onTap;
  final bool warn;

  /// **A key for this provider is in this run** (046/H, the owner: «the model
  /// that has a key is drawn in a different colour»).
  ///
  /// Not the same fact as `on`, which is «this is the one I chose», and not the
  /// same as reachable, which was being said in grey alone. Grey says «off»;
  /// this says «ready», and the two readings are what a person needs in a list
  /// of six companies of which two have keys.
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final tint = warn
        ? Zc.amber
        : ready
            ? Zc.ready
            : Zc.river;
    final reachable = onTap != null;
    return Opacity(
      opacity: reachable ? 1 : 0.45,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          // A ready chip carries its colour even before it is chosen, which is
          // the whole point: the difference a person is looking for is «can
          // this answer me», not «did I already press it».
          color: on
              ? tint.withValues(alpha: 0.12)
              : ready
                  ? Zc.readyWash
                  : Colors.transparent,
          border: Border.all(
            color: on
                ? tint
                : ready
                    ? Zc.readyEdge
                    : Zc.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Zc.small.copyWith(
            color: on || ready ? tint : Zc.ink3,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      ),
    );
  }
}

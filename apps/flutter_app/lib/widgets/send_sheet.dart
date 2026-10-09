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

  /// The session question, directly above the two exits.
  ///
  /// Keyed because what a guard asserts about it is **presence or absence**:
  /// the strip has three states and they are told apart by which one is there.
  static const theSessionBand = ValueKey<String>('send-sheet-session-band');

  /// The one field the band carries.
  static const theSessionName = ValueKey<String>('send-sheet-session-name');

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
    // **The document's name, offered and not imposed.** A pre-filled field
    // still asks; an empty one in front of the only button that matters is a
    // stall. It stays the person's to replace.
    _sessionName.text = widget.bench.document?.name ?? '';
  }

  final _pasted = TextEditingController();
  final _sessionName = TextEditingController();
  final _nameFocus = FocusNode();
  final _previewScroll = ScrollController();

  /// What the birth said, once one has happened at this sheet — the core's own
  /// number in the house's one wording. Kept rather than recomputed: asking
  /// again would be asking a different question and getting a different answer.
  String? _begun;
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
    _sessionName.dispose();
    _nameFocus.dispose();
    _previewScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.ground, widget.bench]),
      builder: (context, _) {
        // **Read inside the builder, not above it.** A notify from the bench
        // re-runs this closure and not `build`, so a payload captured one line
        // up would keep the sheet — its counts, its preview, and the text its
        // exits take out — showing a snapshot from before whatever just
        // changed. That was latent while nothing in the sheet could change the
        // bench; 064's birth at an exit is what made it reachable.
        final payload = widget.bench.payload;
        final open = payload?.openSuggestions ?? 0;
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
          // **The session question first, and only while it stands.** The
          // comment this replaces said provider and model come first, because
          // a person opens this sheet to decide who answers. That holds for
          // every other visit: this question is asked once, it gates both
          // exits, and measured below `_ModelAndMode` it began at y 888 on a
          // 1000-tall window — a question nobody would see without scrolling.
          // Who answers can also be changed in the panel; this cannot.
          if (widget.ground.theSessionQuestionStands) ...[
            _theBand(),
            const SizedBox(height: 16),
          ],
          _ModelAndMode(bench: widget.bench, ground: widget.ground, onSettings: widget.onSettings),
          const SizedBox(height: 16),
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

  /// **Whose names are about to leave** — the three states, in one place.
  ///
  /// Exactly one of them is on the glass, because a person who cannot tell
  /// them apart cannot know what they are about to take out:
  ///
  ///   * the text belongs to a session → its name, in the sheet's small ink;
  ///   * it belongs to none, and one could be born → the question, with its field;
  ///   * it belongs to none and none could be born → one line saying so.
  ///
  /// **The first state is read off the payload, not off the app.**
  /// `ground.openSession` answers «which session is open»; this line claims
  /// «whose names are in this text». They are two questions and they agree in
  /// every case but one — a text built before the session began. The claim is
  /// about the text, so it is taken from the text.
  Widget _whoseNames(PayloadView? payload) {
    final whose = payload?.session;
    if (whose != null) {
      return Text(
        'Session ${whose.number} «${whose.name}» · these names are this session’s',
        style: Zc.small.copyWith(color: Zc.ink4),
      );
    }
    if (!widget.ground.theSessionQuestionStands) {
      // No session, and none that could be born — the keys are in the vault
      // and it is shut. Not a fault and not a warning: a true sentence about
      // this text, and the only thing in this state that would go unsaid.
      return Text(
        'No session — these names were made for this document alone.',
        style: Zc.small.copyWith(color: Zc.ink4),
      );
    }
    final named = _sessionName.text.trim();
    return Text(
      named.isEmpty
          // **«Any door», because there are three** (064/A). It read «either
          // door» while the exits were the clipboard and the PDF; the send
          // through a key begins the session too now, and it is the only one
          // of the three that puts the text on a wire. A sentence that counted
          // the doors wrongly would be a sentence a person could check.
          ? 'No session yet — name it on the page before; any door here begins it.'
          : 'Any door here begins session «$named».',
      style: Zc.small.copyWith(color: Zc.ink4),
    );
  }

  /// **The question, in prose, on the page before the doors** — and the
  /// placement is a measurement, not a preference.
  ///
  /// It was drawn directly above the two exits, which is where the act is. It
  /// does not fit there. The sheet is capped at 820px tall, so on **every**
  /// window from 900px up the doors page has the same room — and with no
  /// provider connected there is **124px** between the last door and the
  /// bottom of its scroller, measured at 1100×950, against this band's 202px.
  /// A band there pushed «Open Settings» under the scroll, and since 067 exiled
  /// the key form from this sheet that door is the only place a key can be
  /// given: a question about naming would have cost a person their only way to
  /// connect a model. (At 1280×720 with nothing connected that door is already
  /// under the scroll **without** anything of mine — a fault that predates this
  /// work and is reported, not quietly absorbed.)
  ///
  /// So the prose is asked here, where the payload's own scroller yields the
  /// room, directly above the text it is about; the doors page carries one line
  /// saying what the press will do, and a press with no name comes back to this
  /// field rather than refusing into a dead end.
  Widget _theBand() {
    // The question. **Not a dialog**: a dialog over this sheet is a third
    // storey whose dismissing press looks like «cancel the send», and it would
    // cover the two buttons it is about. It is also not a gate — the doors
    // stay live beside it. It is the question answered before it is needed.
    // The prose is whole here. It was cut to three lines while this stood
    // above the doors, where 202px cost a door its place; on this page the
    // payload's own scroller gives the room back, so the question keeps the
    // words it was approved with.
    return Container(
      key: SendSheet.theSessionBand,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: Zc.panel(fill: Zc.warmCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This conversation has no session yet', style: Zc.h2),
          const SizedBox(height: 6),
          const Text(
            'A session has its own key. The same name in two sessions takes two '
            'different tokens, and inside one session it takes the same token '
            'wherever it appears — that is how you choose what an AI can line up '
            'and what it cannot.',
            style: Zc.small,
          ),
          const SizedBox(height: 10),
          TextField(
            key: SendSheet.theSessionName,
            controller: _sessionName,
            focusNode: _nameFocus,
            style: Zc.body.copyWith(color: Zc.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: Zc.card,
              isDense: true,
              // **The room's hint, word for word.** Two doors, one birth, one
              // question: a person who meets it twice meets one thing.
              hintText: 'What is this one about?',
              hintStyle: Zc.body.copyWith(color: Zc.ink4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Zc.line),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // **Every clause is true from here, which is not where it was
          // written for.** «behind this sheet», not the room's «in front of
          // you»: the panel stands beside the document, this sheet covers it.
          // «on the page after this», because the doors are no longer the
          // next thing under this field. And no number before the act — the
          // count a person is told is the one the core returns, after the
          // renaming it is counting.
          //
          // **The third act is named here too** (064/A): a send through a
          // connected key begins the session as the other two do, and it is
          // the one that actually puts the text on a wire. The last clause
          // keeps its exact promise for all three — nothing has left *yet* —
          // because it is read before any of them is pressed.
          const Text(
            'Copy Protected, Save as PDF, or a send to a connected AI — on the '
            'page after this — begins it. Everything already protected on the '
            'document behind this sheet is renamed into it — nothing has left '
            'this machine yet, so nothing that did is affected.',
            style: Zc.small,
          ),
        ],
      ),
    );
  }

  /// A press that took nothing out of the machine, and why, where it happened.
  ///
  /// The field takes focus while the question is the thing in the way, so the
  /// next keystroke lands where it is needed. **Refusal is leaving**, which is
  /// why there is no Cancel in the band: closing this sheet takes nothing out,
  /// and that is what refusing means here.
  void _nothingLeft(WhatMayLeave out) {
    final needsAName =
        widget.ground.theSessionQuestionStands && _sessionName.text.trim().isEmpty;
    setState(() {
      _trouble = out.refused;
      // **Back to the question, not a dead end.** The field is one page back
      // because the prose does not fit above the doors, so the press that
      // cannot proceed takes the person to the field instead of telling them
      // to go looking for it. Nothing left the machine — which is what
      // refusing means here, and why there is no Cancel in the band.
      if (needsAName) _page = _SheetPage.review;
    });
    if (needsAName) _nameFocus.requestFocus();
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
          _whoseNames(payload),
          if (_begun != null) ...[
            const SizedBox(height: 8),
            // The number in this sentence is the core's answer to the call
            // this sheet made. Nothing here counts anything.
            Text(_begun!, style: Zc.small.copyWith(color: Zc.ready)),
          ],
          const SizedBox(height: 12),
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
                      // **The order is not written here.** `beginThenRead`
                      // holds it, where a guard can drive it; this press reads
                      // the name, takes what it is handed, and says so.
                      onPressed: payload == null
                          ? null
                          : () async {
                              final out = await beginThenRead(
                                widget.ground,
                                widget.bench,
                                name: _sessionName.text,
                              );
                              if (!mounted) return;
                              if (out.view == null) {
                                _nothingLeft(out);
                                return;
                              }
                              await Clipboard.setData(
                                // The fresh view, never the captured one.
                                ClipboardData(text: out.view!.text),
                              );
                              widget.bench.rememberCopiedPayload();
                              if (!mounted) return;
                              setState(() {
                                _copied = true;
                                _trouble = null;
                                _begun = out.said ?? _begun;
                              });
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
                          : () async {
                              final out = await beginThenRead(
                                widget.ground,
                                widget.bench,
                                name: _sessionName.text,
                              );
                              if (!mounted) return;
                              if (out.view == null) {
                                _nothingLeft(out);
                                return;
                              }
                              if (out.said != null) {
                                setState(() => _begun = out.said);
                              }
                              // The same fresh view the clipboard would get —
                              // and the footer's per-kind counts are built from
                              // its text, so a stale one would have counted
                              // nothing over fully protected text.
                              await _savePdf(out.view!);
                            },
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
                                  // **The order is not written here either.**
                                  // `beginThenAsk` holds it — the name, the
                                  // birth, the refresh, and then the right one
                                  // of the two calls, because the mode names
                                  // which and the document is an argument of
                                  // one of them only. This press reads the
                                  // name, takes what it is handed, and says
                                  // so. The owner's own run found this door
                                  // sending with no session born at all.
                                  final out = await beginThenAsk(
                                    widget.ground,
                                    widget.bench,
                                    name: _sessionName.text,
                                    providerId: p.id,
                                  );
                                  // The State's own `mounted`, not the
                                  // context's: this closure uses
                                  // `State.context`, and the analyzer is right
                                  // that the two checks are not the same one.
                                  if (!mounted) return;
                                  if (out.refused != null) {
                                    // A birth that happened is still said,
                                    // even when the send that followed it
                                    // failed: the session is open and the
                                    // names on the bench are its, and a
                                    // person who is told only «it failed»
                                    // would not know that.
                                    if (out.said != null) _begun = out.said;
                                    _nothingLeft(out);
                                    return;
                                  }
                                  Navigator.of(context).pop(true);
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

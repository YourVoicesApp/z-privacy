// Who Answers — the last screen before anything leaves the device, and the
// three ways out of it.
//
// **17 October, rule 60: the review page is gone.** The sheet used to open on
// a page of its own that showed the outgoing text — «Review before send», then
// «Continue» to the doors. The owner's ruling removes it: what will leave is
// read in the preview side of the work surface, where it already stands word
// for word («Safe — AI will receive»), and a second copy of it one press away
// was the same text asked for twice. What the page also held — which model
// answers and what travels to it — moved to the head of this one, so the
// choice still stands above the doors and not behind a page.
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
//   body     the only scroll — the choice and the three doors. The outgoing
//            text is not in here at all (rule 60), so nothing shares a
//            scroller with the actions.
//   footer   Cancel, always on screen
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/widgets/the_name_for_the_file.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/protected_pdf.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/the_clipboard.dart' show andTheClipboardIsEmpty;
import 'package:zprivacy/src/rust/api/core.dart' show coreVersion;
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

/// **The per-kind tally the protected PDF's footer states — 068.**
///
/// Read off the payload it describes, and off nothing else. The core counts it
/// from `allowed_token_ids` in the same pass that builds the text, so the
/// figure and the text are made together and cannot describe different things.
///
/// **What it replaced, and why the replacement is not a tidy-up.** This was
/// computed here by walking the bench's *current* tokens and keeping the ones
/// whose string could be found in the outgoing text. Two sources. A payload
/// captured before a session was born carries tokens the bench no longer
/// holds, so nothing matched and the footer said **no kinds at all about a
/// fully protected document** — every name in the file hidden, and the page
/// describing it claiming none were. A number about the payload comes from the
/// payload.
///
/// **`nameOf` is the naming door, not a whole `Ground`**, and that is the
/// shape of the dependency rather than a convenience: this needs one thing —
/// what a kind is called — and `Ground.kinds` is a getter over state the core
/// owns, so demanding the whole object would have made the rule unmeasurable
/// without a vault. The product passes `Ground.nameOfKind`, which invents no
/// name and answers «…» before the core has said what a kind is called; this
/// prints whatever that door gives and substitutes nothing prettier.
///
/// Counts are **summed** into the name rather than assigned, so that if two
/// kinds ever share a label the footer states their total instead of silently
/// dropping one.
Map<String, int> footerTally(PayloadView payload, String Function(Kind) nameOf) {
  final out = <String, int>{};
  for (final tally in payload.byKind) {
    final name = nameOf(tally.kind);
    out[name] = (out[name] ?? 0) + tally.count;
  }
  return out;
}

/// **The way into the doors, and it opens the preview side first.**
///
/// Rule 60 takes away the page that showed the outgoing text, on the ground
/// that the work surface shows it already. That ground is a premise about the
/// screen, and the screen can refuse it: the preview side is closed by a press
/// and stays closed — `safeColumnOpen` is remembered in `zcfg` — so a door
/// that opened this sheet over a closed side would stand a person on the three
/// exits with the text they are about to send nowhere on the glass. The rule
/// would have been kept in the code and broken on the glass.
///
/// So the order is written **once, here**, where a guard can drive it, and not
/// in the widgets that draw the doors. That is this house's oldest lesson about
/// a law written at one door out of several.
///
/// **This opens the side; nothing here ever closes it.** The owner's rule of
/// 046/K — «الطوي والفتح لا يتم تلقائياً، يتم بالضغط على إشارة محددة» — is
/// about the app moving that state by itself: a panel opening, a window
/// narrowing, a document arriving, a scan ending. Those four are measured in
/// `the_states_change_only_by_a_press_test.dart` and none of them is this. A
/// press on a door whose own law is «what leaves is seen» is a press, and the
/// test names it as the fifth case so that the two rules stand side by side
/// rather than looking like a contradiction.
///
/// **And it is the one hand again, since rule 70.** The chat had a hand of its
/// own for one day — rule 60-أ, for a chat that had no preview side to open.
/// The screen that had no preview side is gone, so this hand's law covers
/// every door to the exits there is: see the note where the second one stood.
Future<bool?> theWayToTheDoors(
  BuildContext context, {
  required Ground ground,
  required Workbench bench,
  VoidCallback? onSettings,
}) async {
  final config = ground.config;
  if (config != null && !config.safeColumnOpen) {
    await ground.saveConfig(config.with_(safeColumnOpen: true));
  }
  // The config write is a round trip to the core, so the context this was
  // called with may be gone by now.
  if (!context.mounted) return null;
  return showDialog<bool>(
    context: context,
    builder: (_) =>
        SendSheet(bench: bench, ground: ground, onSettings: onSettings),
  );
}

// **The chat's own hand is gone, and so is the case it was written for** —
// rule 70 settles rule 60-أ's first half.
//
// That rule split the press in two «في المحادثة، حيث لا جانب معاينة» — in the
// chat, where there is no preview side. The first screen was that place: its
// chat had no columns, so «Ask the AI» drew the outgoing text in a band above
// the composer and the band carried the one door onward. One screen with three
// parts has no such state — every question is asked beside the middle column
// that draws what will leave — so the hand is deleted rather than kept for a
// screen nobody can reach (rule 35), and [theWayToTheDoors] above is the one
// hand again. The rule's other half is untouched and still measured: the AI
// door on the work surface opens the preview side before the doors.

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

  /// Where «Save as PDF» writes. Null is the product's own place — the folder
  /// the core names, which is `~/Documents/zprivacy` on Linux — and nothing in
  /// the product passes anything else; a test gives a temporary folder so that
  /// running the tests never writes into the person's documents.
  final String? saveFolder;

  /// The sheet's one scrolling region — the choice and the three doors.
  ///
  /// It was `previewKey` while the sheet had two pages and the first one was
  /// the outgoing text; rule 60 took that page away, and the key is named
  /// after what is actually in here so that a guard cannot wheel one thing
  /// while believing it wheels another.
  static const bodyKey = ValueKey<String>('send-sheet-body');

  /// Cancel. Never inside the body's scroller.
  static const footerKey = ValueKey<String>('send-sheet-footer');

  @override
  State<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<SendSheet> {
  @override
  void initState() {
    super.initState();
    // The catalogue, at the moment it is needed: a chooser that opens empty is
    // a chooser nobody can use.
    unawaited(widget.bench.refreshModels());
  }

  final _bodyScroll = ScrollController();

  /// What the birth said, once one has happened at this sheet — the core's own
  /// number in the house's one wording. Kept rather than recomputed: asking
  /// again would be asking a different question and getting a different answer.
  String? _begun;
  bool _copied = false;

  /// Where the last save went, in full. A path is the whole of the answer to
  /// «where did it go», so it is shown whole and not as «Saved».
  String? _savedTo;
  bool _saving = false;

  /// Write the protected text to a file, and say where it went.
  ///
  /// The same text Copy Protected copies, and like Copy it sends nothing.
  ///
  /// **Both numbers in the footer are the core's, and each comes from the
  /// payload it describes** — 068's Dart half. The places are
  /// `PayloadView.protectedCount`; the per-kind tally is `PayloadView.byKind`,
  /// counted in the core from `allowed_token_ids` in the same pass that made
  /// the text.
  ///
  /// It used to be counted here, and the rule it was written for was right —
  /// «a footer describing the file must be about the file» — but the means
  /// crossed **two sources**: it walked the bench's *current* tokens and kept
  /// the ones whose string it could find in the outgoing text. A payload
  /// captured before a session was born has tokens the bench no longer holds,
  /// so the search matched nothing and the footer counted **zero kinds over a
  /// fully protected document** — a file whose every name was hidden,
  /// described as hiding none. One source cannot disagree with itself; two can
  /// only be unlikely to.
  Future<void> _savePdf(PayloadView payload, String documentName) async {
    setState(() {
      _saving = true;
      _trouble = null;
      _savedTo = null;
    });
    final byKind = footerTally(payload, widget.ground.nameOfKind);
    // **The answer page's token is the core's, from this same view** — 079.
    // The door the exit asked mints it after the law, so a view that carries
    // none did not come through that door, and a z-pdf without its answer page
    // is not one: nothing is written rather than half of it.
    final answerToken = payload.answerPageToken;
    if (answerToken == null) {
      setState(() {
        _saving = false;
        _trouble = sentences.couldNotBuildThePdf;
      });
      return;
    }
    final out = await saveProtectedPdf(
      text: payload.text,
      answerToken: answerToken,
      // **The payload's own session, not the app's** — the same rule
      // `_whoseNames` follows: the claim is about this text, so it is taken
      // from this text. And never `bench.document.name`, which is the person's
      // own file name (081).
      sessionName: payload.session?.name ?? '',
      // **The person's own word for this document** — paper 108 item 2. It is
      // in the **file name** and nowhere inside the file: 081 took the
      // document's own name out of the PDF and that stands. What this fixes is
      // two vaults' copies of one day arriving under one name.
      documentName: documentName,
      // **And the language the file carries, from the same session** — rule
      // 80, the owner, 21 October 2026. The sentences that go *into* a z-pdf
      // are in the language of the session it left, so the one place that
      // knows which session that was says it here; `saveProtectedPdf` reads
      // the list and the glass's own holder is not consulted at all. Null is
      // «no session, or no language» and means English, which is the law's
      // other half and lives with it in `theLanguageAFileCarries`.
      sessionLanguage: theLanguageAFileCarries(widget.ground, payload.session),
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

  String? _trouble;

  @override
  void dispose() {
    _bodyScroll.dispose();
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
                    Expanded(child: _aiDoors(payload, open, connected)),
                    _footer(context),
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
                // **The name of what is left** — rule 60. «Review before
                // send» named the page this sheet no longer has, and the
                // reviewing is done on the work surface; what happens here is
                // choosing who answers. The counts line below it is unchanged,
                // and it is the only place the character count is said.
                Text(sentences.whoAnswers, style: Zc.h2),
                const SizedBox(height: 4),
                Text(
                  payload == null
                      ? sentences.thereIsNothingToSend: sentences.valuesReplacedCharacters(
                          payload.protectedCount, payload.text.length),
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
      // A session nobody named is already «Session N», and «Session 3 «Session
      // 3»» is the app reading its own placeholder back to the person (081).
      // **Every language the house names in** (117), and not this screen's:
      // the name was written at the birth and the language may have moved
      // since — `isTheHouseName` says why in full. Comparing against the
      // interface's word alone would make a session born in Arabic look like
      // one a person named, the moment the app was switched to German.
      final named = isTheHouseName(whose.name, whose.number)
          ? sentences.sessionNumber(whose.number)
          // **Isolated** — the owner's test of 16 October: an Arabic name in
          // an English line pulls the number and the quotes into its own
          // direction. One pair of characters, one function, every sentence.
          : sentences.sessionNumberNamed(whose.number, theirOwnWord(whose.name));
      return Text(
        sentences.theseNamesAreThisSessions(named),
        style: Zc.small.copyWith(color: Zc.ink4),
      );
    }
    if (!widget.ground.aSessionWouldBeBorn) {
      // No session, and none that could be born — the keys are in the vault
      // and it is shut. Not a fault and not a warning: a true sentence about
      // this text, and the only thing in this state that would go unsaid.
      return Text(
        sentences.noSessionNamesForThisDocument,
        style: Zc.small.copyWith(color: Zc.ink4),
      );
    }
    // **«Any door», because there are three** (064/A). It read «either door»
    // while the exits were the clipboard and the PDF; the send through a key
    // begins the session too now, and it is the only one of the three that puts
    // the text on a wire. A sentence that counted the doors wrongly would be a
    // sentence a person could check — and since 081 it names no name, because
    // there is none to name until the door is pressed.
    return Text(
      sentences.noSessionYetAnyDoorBeginsOne,
      style: Zc.small.copyWith(color: Zc.ink4),
    );
  }

  /// A press that took nothing out of the machine, and why, where it happened.
  ///
  /// **Refusal is leaving**: closing this sheet takes nothing out, and that is
  /// what refusing means here. Until 081 this also walked the person back to
  /// the name field a page earlier — there is no field to walk back to now, and
  /// no press is refused for want of a word.
  /// The sheet stays and says it — for the refusals a person cannot act on from
  /// anywhere else. The one that **can** be acted on, a word still waiting,
  /// closes this sheet instead: see [_outOfTheWay].
  void _nothingLeft(WhatMayLeave out) {
    setState(() {
      // **And the clipboard is empty** — 081. `beginThenRead` empties it as its
      // first act, so a refusal can state this instead of hoping for it. The
      // person is told because a paste that gives back nothing reads as a
      // broken application unless somebody said so first — «المستخدم لا يدرك
      // أنه نفس النسخ القديم», which was the owner's own first reading of it.
      _trouble = andTheClipboardIsEmpty(
        out.refused ?? sentences.nothingLeftTheMachine,
      );
    });
  }

  /// **A sheet in front of the lit word is a wall** — the lead's ruling of 14
  /// Oct on 083 rule 12.
  ///
  /// The press took nothing out and the review is already open on the first
  /// word still waiting, with the sentence on the workspace's own line. So this
  /// sheet gets out of the way and the person lands on the word, one press from
  /// answering it — rather than reading a refusal in front of the thing it is
  /// about.
  ///
  /// `false`, because nothing left: the Workspace moves a person off their
  /// document only when something did (`showDialog<bool>` at
  /// `workspace.dart:715`).
  bool _outOfTheWay(WhatMayLeave out) {
    if (!out.landedOnTheWaitingWord) return false;
    Navigator.of(context).pop(false);
    return true;
  }

  Widget _aiDoors(
    PayloadView? payload,
    int open,
    List<ProviderFact> connected,
  ) {
    return SingleChildScrollView(
      key: SendSheet.bodyKey,
      controller: _bodyScroll,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **The choice stands above the doors** — the owner's own hand on
          // this sheet («a door you can see»), kept through rule 60. It was
          // above the outgoing text on a first page; the text is read on the
          // work surface now, and the rule it was built for — the model and
          // the mode are not behind a second page — holds here because there
          // is no second page left to put them behind.
          _WhichModel(bench: widget.bench, ground: widget.ground, onSettings: widget.onSettings),
          const SizedBox(height: 16),
          // **A warning before sending stays where the sending is.** The work
          // surface says this too, in its own words, beside the text that is
          // standing as written — but this sheet is a modal route over it, so
          // with the sheet open that sentence is behind the barrier and off the
          // glass. The law it carries is the one this product rests on, so it
          // is said where the press is.
          if (open > 0) ...[
            Trouble(
              open == 1
                  ? sentences.oneSuggestionStillOpenSend
                  : sentences.suggestionsStillOpenSend(open),
            ),
            const SizedBox(height: 16),
          ],
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
            title: sentences.manualAi,
            what:
                sentences.manualAiSheetWhat,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ZButton(
                      label: _copied ? sentences.copied : sentences.copyProtected,
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
                              );
                              if (!mounted) return;
                              if (out.view == null) {
                                if (!_outOfTheWay(out)) _nothingLeft(out);
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
                      label: _saving ? sentences.saving : sentences.saveAsPdf,
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: payload == null || _saving
                          ? null
                          : () async {
                              // **The name first, and before anything else
                              // happens** — paper 108 item 2, the owner, 24
                              // October 2026. Asked before `beginThenRead`
                              // deliberately: that call **births a session**
                              // when none is open, and a person who closes
                              // this dialog has pressed nothing. Nothing is
                              // born, nothing is read, nothing is written.
                              final named = await askForTheNameOfTheDocument(context);
                              if (named == null || !mounted) return;
                              final out = await beginThenRead(
                                widget.ground,
                                widget.bench,
                              );
                              if (!mounted) return;
                              if (out.view == null) {
                                if (!_outOfTheWay(out)) _nothingLeft(out);
                                return;
                              }
                              if (out.said != null) {
                                setState(() => _begun = out.said);
                              }
                              // The same fresh view the clipboard would get —
                              // and the footer's per-kind counts are built from
                              // its text, so a stale one would have counted
                              // nothing over fully protected text.
                              await _savePdf(out.view!, named);
                            },
                    ),
                    // **«Paste AI answer» moved to the chat** — rule 65: the
                    // two buttons under the thread are «Copy the chat» and
                    // «Add an answer», and an answer brought back belongs
                    // beside the conversation it joins rather than inside the
                    // sheet that chooses who answers. The press, the
                    // clipboard read and its two refusals went with it, in
                    // `widgets/the_chat.dart`.
                  ],
                ),
                if (_savedTo != null) ...[
                  const SizedBox(height: 10),
                  // **Said in words, in full.** «Saved» is not an answer to
                  // «where», and a person who cannot find the file has to
                  // trust us that there is one.
                  Text(
                    // Two sentences, joined by the screen: G55 refuses a
                    // newline inside a value, and this was the sentence that
                    // taught the gate's own author so.
                    '${sentences.savedToWhere(theMachinesOwnWord(_savedTo!))}\n'
                    '${sentences.whatThePdfHolds}',
                    style: Zc.small.copyWith(color: Zc.ink2),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _door(
            title: sentences.directApi,
            what: connected.isEmpty
                ? sentences.directApiSheetWhatRemote: sentences.directApiSheetWhatConnected,
            child: connected.isEmpty
                ? _toTheSettings(
                    context,
                    sentences.noProviderIsConnected,
                  )
                : Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final p in connected)
                        ZButton(
                          label: widget.bench.sending
                              ? sentences.sending// The route, not the protocol. And «Local AI»
                              // only when the core says the endpoint really
                              // is on this computer — the word is a promise
                              // about where the text goes.
                              : sentences.sendToNamed(p.onThisComputer
                                  ? sentences.localAi
                                  : sentences.directApi),
                          filled: true,
                          icon: Icons.send_outlined,
                          // **A guide, not a wall** — 083 rule 12. The count
                          // no longer kills the press: the law is one function
                          // in the core, every exit asks it, and the refusal
                          // opens the review on the first waiting word. A dead
                          // button can guide nobody, and a button that decides
                          // for itself is the second copy of a law this round
                          // exists to remove.
                          //
                          // **And there is no second press with a wall** —
                          // rule 62, 17 October. One door here sent the
                          // document as it stands and had to stay a wall,
                          // because a word still waiting would have gone out
                          // in the clear; the owner deleted that door, so what
                          // is left is this press, the law behind it, and
                          // nothing to be dead for but a text that was never
                          // built.
                          onPressed: widget.bench.sending || payload == null
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
                                    if (!_outOfTheWay(out)) _nothingLeft(out);
                                    return;
                                  }
                                  Navigator.of(context).pop(true);
                                },
                          // **A hint belongs where a wall is** — 083a, and
                          // 046/L's own rule finally applied to this line.
                          //
                          // It explained a dead button: the count killed every
                          // send, and the sheet said «answer them first». The
                          // protected press is a guide now (rule 12) — it says
                          // the one sentence `messages.dart` holds and opens
                          // the review on the word — so a second wording
                          // beside it would be two places wording one state,
                          // which is the defect this line was the weaker half
                          // of. The one button that was still a wall, and
                          // named itself here, is deleted (rule 62) — so there
                          // is no wall on this page left to explain.
                        ),
                    ],
                  ),
          ),
          if (connected.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final p in connected)
              Text(
                '${p.label} · ${p.model} · ${p.endpoint}'
                '${p.credentialState == CredentialState.sessionOnly ? sentences.providerKeyThisRunOnly : ""}',
                style: Zc.tiny.copyWith(letterSpacing: 0),
              ),
            const SizedBox(height: 10),
            _toTheSettings(
              context,
              sentences.theAddressTheModelTheKey,
            ),
          ],
          const SizedBox(height: 14),
          _door(
            title: sentences.localAi,
            what:
                sentences.localAiSheetWhat,
            child: _toTheSettings(
              context,
              sentences.aModelOnThisComputer,
            ),
          ),
        ],
      ),
    );
  }

  /// Cancel, and nothing else. It takes no payload and no count because it
  /// decides nothing about them — rule 60 left this footer one job.
  Widget _footer(BuildContext context) {
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
            label: sentences.cancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          // **«Back» and «Continue» went with the page they moved between** —
          // rule 60. One page needs no paging, and «Cancel» is the whole of
          // what a footer owes a person here: a way out that takes nothing out.
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
            label: sentences.openSettings,
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

/// Which model answers.
///
/// **9 October: the catalogue left this page.** It held the whole of it,
/// grouped by company, with an unconnected provider's models greyed and
/// «Connect in Settings» beside each company's name — six groups and six doors,
/// which is what the owner pointed at with his hand in the middle of his work.
/// His ruling: the name of the model that will answer is what a work surface
/// shows, a press on it lists **names only**, and the catalogue belongs in the
/// AI room in the panel. [TheModelThatAnswers] is that control, on this page
/// and in the chat, and the room is where a person goes to set something up.
///
/// What is kept here is the previous ruling's reason: the way in is a **door**,
/// not a form. The form used to open on this page, so a person who pressed
/// ✨AI to choose a model was one press from an endpoint and an API key; the
/// owner put the AI settings in the panel so that they never appear during
/// work, and 063 made the panel able to stand over the document.
///
/// **And there is no second choice here any more** — rule 62, the owner on
/// 17 October. Below the model stood the one place in this app where a person
/// could decide to send their document as it stands; the choice is deleted, so
/// what this card asks is the one question the page is named for. «Direct API»
/// keeps its own meaning in Z's vocabulary — the route, this app to the
/// provider, with the protected text.
class _WhichModel extends StatefulWidget {
  const _WhichModel({required this.bench, required this.ground, this.onSettings});

  final Workbench bench;
  final Ground ground;

  /// The way to the settings panel. Null means this chooser has nowhere to send
  /// the press, and then it draws no door rather than a dead one.
  final VoidCallback? onSettings;

  @override
  State<_WhichModel> createState() => _WhichModelState();
}

class _WhichModelState extends State<_WhichModel> {
  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: Zc.panel(fill: Zc.card, edge: Zc.line, radius: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sentences.modelLabel, style: Zc.tiny.copyWith(color: Zc.ink4)),
          const SizedBox(height: 6),
          // **The catalogue moved; the control stayed** — 064/C, the owner's
          // own hand on this page: six grey company groups and six «Connect in
          // Settings» doors in the middle of his work. What belongs here is
          // the one question this page raises — who answers if I press send —
          // and the list of what actually can. The grouped catalogue, the
          // greyed names and the way in are in the AI room, where setting
          // something up is what a person came to do.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TheModelThatAnswers(
              ground: widget.ground,
              bench: bench,
              // Only when pressing it would open the panel: the sheet's own
              // rule since 063, kept by passing on what it was given.
              onSettings: widget.onSettings == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onSettings!();
                    },
            ),
          ),
          // **«What travels» was a question here, and it is not one any
          // more** — rule 62. Two chips stood below this line, «Protected
          // text» and «The original text», with an amber sentence under the
          // second one. The owner deleted the second choice, and a choice with
          // no alternative is deleted and not greyed (rule 35), so the whole
          // section goes rather than leaving a heading over one chip that can
          // only be on.
          //
          // The page still says what travels, where it says it once: the line
          // under «Who answers» names the values replaced and the characters
          // that would leave this device.
        ],
      ),
    );
  }
}

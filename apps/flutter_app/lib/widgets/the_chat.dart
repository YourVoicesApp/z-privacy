// **The third part: the chat** — rules 65, 66, 67 and 68, the owner, 17 October
// 2026.
//
// «الترحيل يفتح قسم المحادثة في الشاشة الثالثة دائماً… وتُلغى شاشة الجواب
// المستقلة» — the answer is not a destination any more. It is a line in a
// conversation that opens with the first answer and stays until the chat ends.
//
// What stood here was `AnswerPanel`: one answer at a time, «Answer 2 of 2» with
// arrows either side, and a «Restored / As the model wrote it» switch over the
// whole panel. Three things make this not that:
//
//   * **the thread, not the answer** (65). Every turn of the chat that is open,
//     in order, each side named — so a person reads the conversation rather
//     than navigating a list of replies.
//   * **coded by default** (66). The question as it left and the answer as the
//     model wrote it, tokens and all, because that is what actually travelled.
//     The restored text is one press away, in a bubble, per answer — never the
//     default and never the whole panel's state: «لا يظهر الجواب مباشرة بلا
//     ترميز».
//   * **it continues** (67). The compose box at the foot sends the next
//     question to the same door, and the core carries the earlier turns with
//     it. Nothing of the history is assembled here; this panel never builds
//     what leaves.
//
// **Nothing here decides what a token was.** The coded sides are drawn by
// `SafeText`, the same painter the Safe column uses, so a token looks the same
// wherever it stands; the restored side is the core's own segments, with the
// fourth mark on a value that came back and amber on a token nothing could
// place — the drawing `AnswerPanel` had, kept exactly, because the law is the
// same law.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/the_clipboard.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';

class TheChat extends StatefulWidget {
  const TheChat({
    super.key,
    required this.bench,
    required this.ground,
    this.width,
    this.onSettings,
    this.onEnded,
  });

  final Workbench bench;
  final Ground ground;

  /// Set by the Workspace from the window's width, as every panel in that slot
  /// is: the two columns are the product and must stay readable behind it.
  final double? width;

  /// The way to the settings, when there is one — 063. Null while the panel is
  /// already open, and then no door is drawn rather than a dead one.
  final VoidCallback? onSettings;

  /// **The chat ended, so the surface starts from zero** — rule 71, 18
  /// October 2026. The press ends the chat in the core (that is this panel's
  /// own act); what the surface then does is the shell's, and this is how it
  /// is told. Null where a guard mounts the panel alone, and then only the
  /// surface emptying is missing.
  final VoidCallback? onEnded;

  /// For the guards: the panel, the box a person writes the next question in,
  /// the arrow that sends it, and the three acts under the thread.
  static const panel = ValueKey<String>('the-chat');
  static const compose = ValueKey<String>('the-chat-compose');
  static const arrow = ValueKey<String>('the-chat-send');
  static const copy = ValueKey<String>('the-chat-copy');
  static const add = ValueKey<String>('the-chat-add');

  /// **The thread itself**, because it is a scroller and a guard has to say
  /// which one. The panel holds three — the thread, the compose box and the
  /// paste box, both fields being scrollers of their own — so «the scrollable
  /// in the chat» is not a reach that names anything. A turn above the fold is
  /// not drawn at all (a `ListView` builds what is on the glass), and after
  /// ed's A1 the first turn is the whole payload the model saw, so reaching an
  /// older turn means scrolling this one by name.
  static const thread = ValueKey<String>('the-chat-thread');

  /// The box an answer from outside is pasted into. Keyed, because this panel
  /// has two fields in it — the compose box comes first in the tree — and
  /// «the first field on the page» is the reach that has cost this house a
  /// guard before (064/D).
  static const pasted = ValueKey<String>('the-chat-pasted');
  static const end = ValueKey<String>('the-chat-end');

  /// The press that puts what was pasted into the chat. Keyed beside [add]
  /// because the two stand in the same place: [add] opens the box and closes
  /// it again, this one spends what is in it.
  static const addIt = ValueKey<String>('the-chat-add-it');

  /// The strip that says an answer carries tokens this session cannot place —
  /// 046/U, kept from the answer panel because the law is the same law.
  static const unresolved = ValueKey<String>('the-chat-unresolved');

  /// One key per turn, so a press lands on the answer it was drawn under
  /// rather than on whichever bubble happens to be first.
  static Key showTheText(int at) => Key('the-chat-show-$at');
  static Key bubble(int at) => Key('the-chat-bubble-$at');

  @override
  State<TheChat> createState() => _TheChatState();
}

class _TheChatState extends State<TheChat> {
  final _text = TextEditingController();
  final _pasted = TextEditingController();
  final _thread = ScrollController();

  /// Which answer's restored text is open, by its place in the thread. Null is
  /// the ordinary state: rule 66 says coded unless a person asks.
  int? _open;

  /// Whether the box for an answer brought back from outside is open.
  bool _adding = false;

  /// What the last press said — a refusal, or what a copy did. Kept on screen
  /// rather than flashed: a person must be able to look back at what happened.
  String? _said;

  /// How many turns the thread held when it was last scrolled to its end.
  int _wasAt = 0;

  @override
  void dispose() {
    _text.dispose();
    _pasted.dispose();
    _thread.dispose();
    super.dispose();
  }

  /// **Keep the newest turn where the person is looking.**
  ///
  /// The thread opens at its end, as a chat does, and only when the number of
  /// turns **changes** — a jump on every frame is a conversation a person
  /// cannot scroll back through. The first screen's chat paid for this lesson
  /// twice: at 900×520 the answer was measured never to be built, because the
  /// end of a scroller nobody moved is not where a `ListView` builds.
  void _keepTheEndInView(int turns) {
    if (turns == _wasAt) return;
    _wasAt = turns;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_thread.hasClients) return;
      _thread.jumpTo(_thread.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final turns = bench.chatTurns;
    _keepTheEndInView(turns.length);
    // Who the arrow sends to. The door the chat's first question chose, named
    // by the provider list — never a model name invented here.
    final door = bench.chatProvider;
    final row = door == null
        ? null
        : widget.ground.providers.where((p) => p.id == door).firstOrNull;
    final name = row?.label ?? door;
    // **The vault's state, before the press** — the owner, 18 October 2026.
    //
    // His key is sealed in the vault; the vault auto-locked while he read an
    // answer; and he found out by sending a question into a door that could
    // not be reached. The bench knows the vault's state and the panel draws
    // the door, so the two together can say it first — and the sentence is the
    // one the refusal would have used, worded once in `messages.dart`.
    //
    // Read as «the door this chat chose is not reachable while the vault is
    // shut», not as «a key is in there»: a locked vault answers nothing about
    // its contents, so `connected` is false for every sealed door and the
    // honest line is about the state, not the contents. A key given for this
    // run only keeps the door connected, and then nothing is said.
    final theKeyCannotBeReached =
        widget.ground.vault == VaultState.locked && row != null && !row.connected;
    return Container(
      key: TheChat.panel,
      width: widget.width,
      decoration: const BoxDecoration(
        color: Zc.card,
        border: BorderDirectional(start: BorderSide(color: Zc.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(sentences.theChatTitle),
                      const SizedBox(height: 4),
                      Text(
                        turns.length == 1
                            ? sentences.oneExchangeCarriedIntoTheNext
                            : sentences.exchangesCarriedIntoTheNext(turns.length),
                        style: Zc.small,
                      ),
                    ],
                  ),
                ),
                // Closing the panel does not end the chat — rule 68 has two
                // ends and this is neither of them. The columns stay, and
                // «Show the chat» in the Safe footer brings it back.
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Zc.ink3,
                  tooltip: sentences.putTheChatAwayItIsNotEnded,
                  onPressed: () => bench.closeThePanel(),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Zc.lineSoft),
          Expanded(
            child: ListView(
              key: TheChat.thread,
              controller: _thread,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              children: [
                if (turns.isEmpty)
                  Text(
                    // **«chat», not «conversation»** — rule 55-هـ: on the
                    // glass the word for a container is «session», and this
                    // part is «The chat» in the owner's own ruling. G41 reads
                    // every sentence in this app for that word.
                    sentences.theFirstAnswerOpensTheChatHere,
                    style: Zc.small.copyWith(color: Zc.ink4),
                  ),
                for (var at = 0; at < turns.length; at++) ...[
                  _Turn(
                    turn: turns[at],
                    at: at,
                    open: _open == at,
                    onShow: () => setState(() => _open = _open == at ? null : at),
                    onSaid: (line) => setState(() => _said = line),
                  ),
                  const SizedBox(height: 14),
                ],
                // **An answer nothing could keep says so** — the honest state
                // the journey's `keptNowhere` named. Said under the thread,
                // which is where a person looks for what was kept.
                //
                // Read from the bench's own state and not from «was a key
                // used»: the first form of this asked `chatProvider != null`,
                // and an answer brought back **by hand** with no session then
                // left the panel saying «The first answer opens the chat
                // here» — the one sentence that was certainly untrue, since an
                // answer had arrived and nothing had kept it.
                if (turns.isEmpty && bench.keptNowhere)
                  Text(theChatKeepsNothing, style: Zc.small.copyWith(color: Zc.amber)),
              ],
            ),
          ),
          if (theKeyCannotBeReached)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                theKeyIsBehindTheLockedVault,
                style: Zc.small.copyWith(color: Zc.amber, fontWeight: FontWeight.w600),
              ),
            ),
          if (_said != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Trouble(_said!),
            ),
          // **The compose box** — rule 65: the arrow, and the name of who
          // answers beside it.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: const BoxDecoration(
              color: Zc.warmCard,
              border: Border(top: BorderSide(color: Zc.lineSoft)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: Zc.panel(fill: Zc.card, radius: 9),
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                        child: TextField(
                          key: TheChat.compose,
                          controller: _text,
                          minLines: 1,
                          maxLines: 4,
                          style: Zc.document.copyWith(fontSize: 13.5),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: sentences.askSomethingElseAboutThis,
                            hintStyle: Zc.body.copyWith(color: Zc.ink4),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => unawaited(_send()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // **The door is named on the arrow**, because a person
                    // pressing it is sending their words to somebody: «➤
                    // Grok». With no door chosen yet the arrow says so and
                    // opens the sheet instead of sending into nothing.
                    _Arrow(
                      name: name,
                      busy: bench.sending,
                      empty: _text.text.trim().isEmpty,
                      onSend: door == null ? null : () => unawaited(_send()),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // **One thing at a time, under the thread.** The three acts of
                // rules 65 and 68 stand here — until the box for an answer
                // from outside is open, and then they give way to it and to
                // its own pair.
                //
                // **Measured, and that is why it is drawn this way.** With the
                // three acts and the box both standing, the panel overflowed
                // the window the application opens at by 57 px: the acts
                // `Wrap` into two runs at this width, the box is four lines
                // and a button, and the thread above had already been squeezed
                // to nothing by the `Expanded` — so there was no space left to
                // take and «Add it to the chat» fell off the glass. A person in
                // the middle of bringing an answer back is not copying the
                // chat or ending it, so what gives way is the part that is not
                // the act in hand.
                if (_adding) ...[
                  TextField(
                    key: TheChat.pasted,
                    controller: _pasted,
                    minLines: 3,
                    maxLines: 5,
                    style: Zc.document.copyWith(fontSize: 13.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Zc.card,
                      hintText: sentences.pasteTheAnswerYouWereGiven,
                      hintStyle: Zc.body.copyWith(color: Zc.ink4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Zc.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ZButton(
                        key: TheChat.addIt,
                        label: sentences.addItToTheChat,
                        filled: true,
                        onPressed: () => unawaited(_add()),
                      ),
                      // **The way out of the box**, and it is the same press
                      // that opened it: one state, one toggle. Named «Not
                      // now», because «Cancel» beside a filled «Add it» reads
                      // as cancelling the answer rather than closing the box.
                      ZButton(
                        key: TheChat.add,
                        label: sentences.notNow,
                        onPressed: () => unawaited(_openTheBox()),
                      ),
                    ],
                  ),
                ] else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ZButton(
                        key: TheChat.copy,
                        label: sentences.copyTheChat,
                        icon: Icons.copy_all_outlined,
                        onPressed: turns.isEmpty ? null : () => unawaited(_copy()),
                      ),
                      ZButton(
                        key: TheChat.add,
                        label: sentences.addAnAnswer,
                        icon: Icons.content_paste_go,
                        // **It pastes.** The owner, 29 September, on the press
                        // this one inherits: a button called «Paste» that only
                        // opened a box is a button that did nothing. So the
                        // clipboard is read on the press — only on the press,
                        // nothing here watches it — and the box opens with what
                        // was on it.
                        onPressed: () => unawaited(_openTheBox()),
                      ),
                      ZButton(
                        key: TheChat.end,
                        label: sentences.endTheChat,
                        icon: Icons.stop_circle_outlined,
                        onPressed: turns.isEmpty ? null : () => unawaited(_end()),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Send what is in the box. **The order lives in `theChatAsks`**, where a
  /// guard can drive it; this press reads the box, says what came back, and
  /// empties the box only when something actually went.
  Future<void> _send() async {
    final door = widget.bench.chatProvider;
    final text = _text.text.trim();
    if (door == null || text.isEmpty || widget.bench.sending) return;
    final bad = await theChatAsks(
      widget.ground,
      widget.bench,
      text: text,
      providerId: door,
    );
    if (!mounted) return;
    setState(() {
      _said = bad;
      // The question stays in the box when it did not go: it is their
      // writing, and a refusal they can act on is a refusal they can retry.
      if (bad == null) _text.clear();
    });
  }

  /// **Copy the whole chat, as it left.** The core builds the text and binds
  /// the handle; this press says what happened.
  Future<void> _copy() async {
    final bad = await copyTheChat(widget.ground, widget.bench);
    if (!mounted) return;
    setState(() => _said = bad ?? sentences.theChatIsOnYourClipboard);
  }

  /// **Open the box, with what is on the clipboard in it** — moved here from
  /// the send sheet by rule 65, with its behaviour and its two refusals.
  ///
  /// Paste is an act of editing and not of processing (the owner, 29
  /// September): it creates no answer, restores nothing, touches no vault and
  /// opens no socket. A second press shuts the box again.
  Future<void> _openTheBox() async {
    if (_adding) {
      setState(() => _adding = false);
      return;
    }
    String? text;
    try {
      // Read **only** on the press. Nothing watches the clipboard.
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text;
    } catch (_) {
      // A platform exception is not a sentence: the person is told what
      // happened to them, not what happened to the channel.
      if (!mounted) return;
      setState(() {
        _adding = true;
        _said = sentences.couldNotReadTheClipboard;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _adding = true;
      if (text == null || text.isEmpty) {
        // The box still opens: they may want to type the answer by hand.
        _said = sentences.thereIsNoTextOnTheClipboard;
        return;
      }
      _said = null;
      // Replaced whole, not inserted at the cursor: this field holds one
      // complete answer from a model, and «where did my cursor leave off» is a
      // question it should never raise.
      _pasted.text = text;
      _pasted.selection = TextSelection.collapsed(offset: text.length);
    });
  }

  /// **An answer brought back from outside** — rule 66's second half: it is
  /// ingested exactly like one that came through a key, and shown coded with
  /// its own «Show the text».
  Future<void> _add() async {
    final bad = await widget.bench.pasteAnswer(_pasted.text);
    if (!mounted) return;
    setState(() {
      _said = bad;
      if (bad == null) {
        _pasted.clear();
        _adding = false;
      }
    });
  }

  /// **End it** — rule 68, and **nothing is asked first**.
  ///
  /// There was a confirmation here for one draft, and the owner's own rule
  /// took it out (54-و: «عمل إضافي لا يفيد»): ending a chat loses nothing. The
  /// turns stay in the session and the Sessions room keeps them under the
  /// document they were about, so a dialog would be a question whose two
  /// answers differ in nothing a person would want back. One press.
  Future<void> _end() async {
    final bad = await widget.bench.endTheChat();
    if (!mounted) return;
    // **Rule 71, after the core has ended it and not before**: the surface
    // empties when there is a chat that has actually ended. A refusal leaves
    // the surface alone and says so.
    if (bad == null) widget.onEnded?.call();
    if (!mounted) return;
    setState(() {
      _said = bad;
      // The box belongs to the chat that ended, not to the next one.
      if (bad == null) _text.clear();
    });
  }
}

/// One exchange: what went, what came back, and the one press that puts the
/// names back.
class _Turn extends StatelessWidget {
  const _Turn({
    required this.turn,
    required this.at,
    required this.open,
    required this.onShow,
    required this.onSaid,
  });

  final TurnRow turn;
  final int at;
  final bool open;
  final VoidCallback onShow;
  final void Function(String?) onSaid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **A turn without a question is a real turn** — and the only one
        // there is: an answer brought back on a copy of the whole chat. Its
        // payload *is* the chat, so storing that as the question would put the
        // conversation inside itself and send every word of it twice as
        // history. The core writes no question for it, and this draws no «you»
        // line — an empty box above an answer would be the app claiming the
        // person asked nothing when they asked everything.
        if (turn.questionAsItLeft.isNotEmpty) ...[
          _Side(who: 'you', text: turn.questionAsItLeft, tint: Zc.ink3),
          const SizedBox(height: 8),
        ],
        _Side(who: whoAnswered(turn.via), text: turn.answerAsWritten, tint: Zc.river),
        const SizedBox(height: 6),
        // **One button per answer, and the default is coded** — rule 66.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ZButton(
            key: TheChat.showTheText(at),
            label: open ? sentences.hideTheText : sentences.showTheText,
            icon: open ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            onPressed: onShow,
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          _Bubble(turn: turn, at: at, onSaid: onSaid),
        ],
      ],
    );
  }
}

/// One side of one exchange, coded. The painter is the Safe column's own, so a
/// token is drawn the same way wherever a person meets it.
class _Side extends StatelessWidget {
  const _Side({required this.who, required this.text, required this.tint});

  final String who;
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              who,
              style: Zc.tiny.copyWith(color: tint, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text('coded', style: Zc.tiny.copyWith(color: Zc.ink4)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: Zc.panel(fill: Zc.paper, radius: 9),
          // Characters, not chips: this is what the model read, and a chip per
          // token would put `U+FFFC` where a word should be.
          child: SafeText(text: text, chips: false),
        ),
      ],
    );
  }
}

/// **The restored answer, in a bubble** — rule 66.
///
/// The segments are the core's, the fourth mark is the one the answer panel
/// drew, the «unresolved» strip is 046/U's, and «Copy Restored» keeps 081's
/// order: the clipboard is emptied before the question is asked, so a person
/// who cancels is left with an empty clipboard rather than with whatever they
/// had copied before.
class _Bubble extends StatefulWidget {
  const _Bubble({required this.turn, required this.at, required this.onSaid});

  final TurnRow turn;
  final int at;
  final void Function(String?) onSaid;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  @override
  Widget build(BuildContext context) {
    final turn = widget.turn;
    final unknown = turn.unresolved;
    return Container(
      key: TheChat.bubble(widget.at),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: Zc.panel(fill: Zc.clayWash, edge: Zc.clayEdge, radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sentences.theTextWithYourNamesBack,
            style: Zc.tiny.copyWith(color: Zc.clayDeep, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (unknown.isNotEmpty) ...[
            Container(
              key: TheChat.unresolved,
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
              decoration: Zc.panel(fill: Zc.amberWash, edge: Zc.amberEdge, radius: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unknown.length == 1
                        ? sentences.thisAnswerCarriesOneUnknownToken
                        : sentences.thisAnswerCarriesUnknownTokens(unknown.length),
                    style: Zc.small.copyWith(color: Zc.amber, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    unknown.join('\n'),
                    style: Zc.tiny.copyWith(letterSpacing: 0, fontFamily: Zc.mono),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          SelectableText.rich(
            TextSpan(
              children: [
                for (final seg in turn.answer)
                  TextSpan(
                    text: seg.text,
                    style: switch (seg.piece) {
                      // The fourth mark: dotted for a value that was put back
                      // here, locally — the only place a word can carry it,
                      // because it is the only place a value comes back.
                      Piece.restored => const TextStyle(
                        backgroundColor: Zc.clayWash,
                        color: Zc.clayDeep,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: Zc.clayDeep,
                        decorationThickness: 1.5,
                      ),
                      // A token nothing could place is not drawn as the
                      // answer: amber, struck through, because it is the one
                      // thing in the text that is not what the sentence
                      // appears to say.
                      Piece.unresolved => const TextStyle(
                        backgroundColor: Zc.amberWash,
                        color: Zc.amber,
                        fontFamily: Zc.mono,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Zc.amberEdge,
                        decorationThickness: 1.5,
                      ),
                      Piece.words => null,
                    },
                  ),
              ],
            ),
            style: Zc.document,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ZButton(
                label: sentences.copyRestored,
                icon: Icons.copy_outlined,
                onPressed: () => unawaited(_copyRestored(
                  turn.answer.map((s) => s.text).join(),
                )),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            unknown.isEmpty
                ? sentences.theMarkedWordsWerePutBackHere
                : sentences.theDottedWordsWerePutBackHere,
            style: Zc.tiny.copyWith(letterSpacing: 0),
          ),
        ],
      ),
    );
  }

  /// 081, and the order is the answer panel's own: the clipboard is emptied
  /// **before** the question, so a cancel leaves it empty rather than leaving
  /// whatever was on it before.
  Future<void> _copyRestored(String text) async {
    await emptyTheClipboardFirst();
    if (!mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Zc.paper,
        title: Text(sentences.copyRestoredTextQuestion, style: Zc.h2),
        content: Text(
          sentences.thisWillPlaceTheRealValues,
          style: Zc.body,
        ),
        actions: [
          ZButton(label: sentences.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          ZButton(
            label: sentences.copyRestored,
            filled: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    widget.onSaid(sentences.restoredTextCopied);
  }
}

/// The send arrow, with the name of who answers on it.
class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.name,
    required this.busy,
    required this.empty,
    required this.onSend,
  });

  final String? name;
  final bool busy;
  final bool empty;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final on = onSend != null && !busy && !empty;
    return Tooltip(
      message: name == null
          ? sentences.chooseWhoAnswersInTheMiddleFirst
          : sentences.sendThisQuestionTo(name!),
      child: ConstrainedBox(
        // Bounded, because its sibling is `Expanded` and `ZButton` flexes its
        // own label — measured on the way-in strip, where an unbounded one was
        // a render assertion.
        constraints: const BoxConstraints(maxWidth: 190),
        child: ZButton(
          key: TheChat.arrow,
          label: name == null ? sentences.chooseWhoAnswers : '➤ $name',
          filled: true,
          onPressed: on ? onSend : null,
        ),
      ),
    );
  }
}

// Home — what stays on this device, and what leaves it. **And the conversation.**
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
//
// ---
//
// **046/G, the owner, 7 October:** «after the vault I go to a chat screen — does
// it exist?» The measured answer was no. This screen was a composer: the model
// lived in a sheet that could only be opened from the Workspace, so it existed
// only once a document was open, and the answer lived in a third destination.
// From the home there was no door to a model at all.
//
// So the box below is the conversation's line, the AI door is here, and the
// answer appears under the question. **Nothing moved in the Workspace** — the
// sheet is the same sheet and the answer is the same widget, in its inline
// shape.
//
// And the gate is the same gate, said out loud: type → protect in place → see
// what will leave → send. Asking is blocked while a suggestion is unanswered,
// and the button carries the reason beside it. A chat that could send before
// the review is answered would break the one promise this product makes.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/answer.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/send_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.ground,
    required this.onImport,
    required this.onType,
    required this.onVault,
    required this.onSettings,
    this.settingsOpen = false,
    required this.version,
    required this.onAsk,
    this.chat,
  });

  final Ground ground;

  /// The home's own conversation, once there is one. `null` until the first
  /// question — a session is not opened for a screen that was only looked at.
  final Workbench? chat;

  /// Ask with what is in the line: open the conversation if there is none,
  /// read the text into it and scan it. What happens next is this screen's,
  /// because it depends on what the scan found.
  final Future<void> Function(String text) onAsk;

  /// The **+**: choose a file. The language is asked afterwards, because by
  /// then there is a document to ask about.
  final VoidCallback onImport;

  /// What was typed or pasted, opened with the pack the settings already hold.
  /// No question before it: a person who writes a sentence is not asking to be
  /// interviewed.
  final void Function(String text) onType;
  final VoidCallback onVault;
  final VoidCallback onSettings;

  /// Whether the settings panel is standing over this page. The heading hides
  /// its own door while it is — the panel covers the right 480 and this door
  /// is under it — so there is exactly one «Settings» on the glass, and it is
  /// the panel's. 063. The shell sets this and shows the panel, so the two
  /// facts have one owner; a Home standing on its own has no panel over it.
  final bool settingsOpen;
  final String version;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// The conversation's own scroller — the middle band, and the only thing on
  /// this page that scrolls.
  final _conversation = ScrollController();

  /// Which answer the conversation was last taken to the end for. Null until
  /// there is one, and compared rather than counted so that re-reading an old
  /// answer does not drag the person away from where they were looking.
  AnswerId? _shown;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _conversation.dispose();
    super.dispose();
  }

  /// True while the question is being read and scanned.
  bool _asking = false;

  /// What the last ask said, when it said anything: «open the vault first»,
  /// or the core's own refusal.
  String? _said;

  void _open() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.onType(text);
    _text.clear();
  }

  /// **The conversation's one act.**
  ///
  /// Read the line, scan it, and — only if there is nothing left to answer —
  /// open the same sheet the Workspace opens, where the exact text that would
  /// leave is shown before anything is sent. When there **is** something to
  /// answer the sheet does not open and the screen says so, with the door to
  /// the place the answering happens. «Send anyway» does not exist.
  Future<void> _ask() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _asking = true;
      _said = null;
    });
    await widget.onAsk(text);
    if (!mounted) return;
    final chat = widget.chat;
    setState(() {
      _asking = false;
      // The vault gate turned the press into a door instead of work, or the
      // core refused the text. Either way the line is still there to try again.
      _said = chat?.trouble;
    });
    if (chat == null || !mounted) return;
    if (chat.openSuggestions > 0) return;
    await showDialog<bool>(
      context: context,
      // Only when pressing it would **open** the panel. The shell's
      // `onSettings` is a toggle, so handing it on while the panel is
      // already standing would give the sheet a door labelled «Open
      // Settings» that shuts them. A surface with nowhere to send the
      // press draws no door — 063's rule, and this is the case it covers.
      builder: (_) => SendSheet(
        bench: chat,
        ground: widget.ground,
        onSettings: widget.settingsOpen ? null : widget.onSettings,
      ),
    );
  }

  /// Keep the newest answer where the person is looking.
  ///
  /// The conversation opens at its end, as a chat does. Without this the
  /// arrangement would be right and the screen still wrong: at 900×520 the
  /// answer was measured to be *never built* — the end of a scroller nobody
  /// moved — and «the answer appears above the writing» would have been true
  /// of the layout and false of the screen.
  ///
  /// Only when the answer **changes**, never on every frame, because a jump on
  /// every frame is a conversation a person cannot scroll back through.
  void _keepTheAnswerInView() {
    final showing = widget.chat?.showing;
    if (showing == _shown) return;
    _shown = showing;
    if (showing == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_conversation.hasClients) return;
      _conversation.jumpTo(_conversation.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ground = widget.ground;
    final chat = widget.chat;
    // One read of each fact, named once. `openSuggestions` is the core's own
    // count — the screen never works it out.
    final empty = _text.text.trim().isEmpty;
    final waiting = chat?.openSuggestions ?? 0;
    final blocked = waiting > 0;
    return ListenableBuilder(
      // The conversation changes what this page draws, so the page listens to
      // it as well as to the ground.
      listenable: chat == null ? ground : Listenable.merge([ground, chat]),
      builder: (context, _) {
        _keepTheAnswerInView();
        return Scaffold(
          body: Center(
            child: LayoutBuilder(
              builder: (context, room) => ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
              // **The chat reads like a chat.** The owner, 8 October:
              // «الكتابة في أسفل الشاشة والإجابة تظهر في أعلى» — the writing
              // at the bottom of the screen, and the answer above it.
              //
              // This was one `ListView` with the writing box as its fourth
              // child and the answer as its eighth, so the person wrote at the
              // top and the answer arrived underneath: the reverse of every
              // chat they have used. Three bands now, and the middle one is
              // the only thing that scrolls — a composer that travels with the
              // thread is not a composer, it is a paragraph.
              child: Column(
                children: [
                  // 1 · The strip. Fixed, because a chat's name does not
                  // scroll away from it.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(34, 30, 34, 0),
                    child: Row(
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
                        if (!widget.settingsOpen)
                          SettingsDoor(open: false, onTap: widget.onSettings),
                      ],
                    ),
                  ),
                  // 2 · The conversation. The page's own opening matter is at
                  // the top of it and scrolls away as a chat's empty state
                  // does; the answer is last, so it stands directly above the
                  // writing.
                  Expanded(
                    child: ListView(
                      controller: _conversation,
                      padding: const EdgeInsets.fromLTRB(34, 24, 34, 14),
                      children: [
                        const Text('What stays on this device, and what leaves it.', style: Zc.h2),
                        const SizedBox(height: 10),
                        const Text(
                          'Write or paste what you want to send an AI. It is scanned before you read it: '
                          'what the scanner is sure of is already protected, what it is unsure of it asks '
                          'you about, and then you see the exact text that would go.',
                          style: Zc.body,
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ZButton(
                            label: 'Open Z Vault',
                            icon: Icons.lock_outline,
                            tint: Zc.river,
                            onPressed: widget.onVault,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (ground.trouble != null) ...[Trouble(ground.trouble!), const SizedBox(height: 18)],
                        _ground(context),
                        // **The answer, under the question and above the
                        // writing, in this screen.** The same widget the
                        // Workspace draws, in its inline shape, so the two
                        // views, the fourth mark, the two named copies and the
                        // clipboard confirmation are one implementation and
                        // not two.
                        if (chat != null && chat.showing != null) ...[
                          const SizedBox(height: 22),
                          AnswerPanel(bench: chat),
                        ],
                      ],
                    ),
                  ),
                  // 3 · The writing. Pinned, with whatever the last press has
                  // to say standing immediately over it — which is where a
                  // chat puts «this did not go».
                  //
                  // **Capped at half the window, and it scrolls inside its own
                  // band.** Three bands in a `Column` have a floor that one
                  // scroller did not: measured on the first build, at 360 px of
                  // height this page reported «A RenderFlex overflowed by 53
                  // pixels on the bottom» — an overflow stripe where the old
                  // shape would merely have scrolled. The cap is what removes
                  // it: the writing gives way before the conversation is pushed
                  // off the glass, and the box a person types in is the first
                  // thing its own scroll shows.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: room.maxHeight / 2),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_said != null) ...[Trouble(_said!), const SizedBox(height: 10)],
                        // **The gate, said out loud and with the way through it.**
                        //
                        // A question that scanned up something unsure is not sent, and
                        // this is where the person is told what is waiting and where
                        // the answering happens — the Workspace's own review, which is
                        // what «Open and scan» opens.
                        if (blocked) ...[
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                            decoration: Zc.panel(fill: Zc.warmCard, radius: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  waiting == 1
                                      ? 'One word in your question is not certain yet.'
                                      : '$waiting words in your question are not certain yet.',
                                  style: Zc.body,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Z does not send a question with an unanswered '
                                  'suggestion in it. Open it to say yes or no to each '
                                  'one, and then ask.',
                                  style: Zc.small.copyWith(color: Zc.ink3),
                                ),
                                const SizedBox(height: 9),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ZButton(
                                    label: 'Open the question and answer them',
                                    icon: Icons.fact_check_outlined,
                                    // The line still holds the question — it is not
                                    // cleared by asking, because it is the question and
                                    // a person may want to change it. So the review
                                    // opens on exactly the text that was scanned.
                                    onPressed: empty ? null : _open,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // **The composer is the home.** The owner, 6 October: the
                        // writing screen is the main screen, and a file is a «+» as it
                        // is in a chat. So the box has the focus — a person who opened
                        // this app to paste a letter can paste it — and since
                        // 8 October it is where a chat keeps it, at the bottom.
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
                                minLines: 3,
                                maxLines: 8,
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
                                  // Flexible, because a disabled button carries a
                                  // sentence beside it and a narrow window must wrap it
                                  // rather than push it off the edge — the same lesson
                                  // the top bar taught on 3 October.
                                  Flexible(
                                    child: Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        // The review path, unchanged: the two columns,
                                        // the suggestions, protecting by hand.
                                        ZButton(
                                          label: 'Open and scan',
                                          icon: Icons.shield_outlined,
                                          onPressed: empty ? null : _open,
                                          hint: empty ? 'Write or paste something first' : null,
                                        ),
                                        // **The AI door, on the home** (046/G). The
                                        // reason is on the button, because «send
                                        // anyway» does not exist and never will.
                                        ZButton(
                                          label: 'Ask the AI',
                                          filled: true,
                                          icon: Icons.auto_awesome_outlined,
                                          onPressed: empty || _asking || blocked ? null : () => unawaited(_ask()),
                                          hint: empty
                                              ? 'Write or paste something first'
                                              : blocked
                                              ? waiting == 1
                                                    ? 'Answer the one suggestion first'
                                                    : 'Answer the $waiting suggestions first'
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          // Two sentences, one space between them. There were three,
                          // on the first screen of the product — 046/D's sweep found
                          // it in Dart after the two in the core. Under the writing
                          // now, which is where a chat keeps the line about itself.
                          'Nothing is uploaded to be read. Conversations are not saved after you close '
                          'the app.',
                          style: Zc.small.copyWith(color: Zc.ink4),
                        ),
                        ],
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

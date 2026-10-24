// The Workspace — the centre of everything.
//
// The frame: the top bar that says what ground this conversation stands on, and
// the band under it that reports the scan. Both are real: the counts are the
// core's `ScanReport`, and the vault line is the core's own `VaultState`, carried
// inside that report so the two can never disagree.
//
// And the two columns, which are the product's essence and not decoration:
//
//   left   the document as written, with what the scanner did drawn over it.
//          Nothing here is replaced, and nothing here can reach the network.
//   right  the request itself. Not a preview of it, not a rebuilt copy of it —
//          the string the core will hand to a provider, shown as it stands.
//
// They are side by side and typographically identical on purpose. The whole
// claim of this product is that a person can compare them.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/going_to_a_word.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/un_protecting.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/core/the_clipboard.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/acts.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/find_in_document.dart';
import 'package:zprivacy/widgets/the_chat.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/widgets/line_gutter.dart';
import 'package:zprivacy/widgets/name_review.dart';
import 'package:zprivacy/widgets/review.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/widgets/the_way_back.dart';
import 'package:zprivacy/widgets/tokens.dart';
import 'package:zprivacy/widgets/vault_forms.dart';
import 'package:zprivacy/widgets/why_sheet.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.bench,
    required this.ground,
    required this.onImport,
    required this.onAsk,
    required this.onVault,
    this.onRemoveDocument,
    this.onSettings,
    this.onFromZero,
    this.onReadBack,
    this.settingsOpen = false,
  });

  /// **The document, or nothing yet** — rule 70.
  ///
  /// It was required until 17 October, because there was a first screen to
  /// stand on while there was no document. There is none: this screen is the
  /// app, and «no document» is a state of it rather than a different place.
  /// Null draws the same three parts, each with the one sentence that says
  /// what it will hold.
  final Workbench? bench;
  final Ground ground;

  /// **The one box a person writes in, and the press that opens a file
  /// chooser.** Named on the screen itself so a guard can reach either
  /// without knowing which private widget draws it.
  ///
  /// **One box since rule 72-أ** (18 October 2026): this name pointed at the
  /// strip's own box at the top of the screen, and that box is deleted. It
  /// points at the request box in the first part now — the one place a person
  /// writes, a short question or a whole letter, with a document above it or
  /// with none at all.
  static const composer = _TheQuestion.field;
  static const addDocument = ValueKey<String>('the-way-in-add');

  /// Rule 73's own press, in the first part.
  static const removeDocument = ValueKey<String>('workspace-remove-document');

  /// **The two ways in, at the top of the screen** — rule 70, the owner:
  /// «نجعل إدخال الملفات يتم أعلى الشاشة». A file to work on, and text the
  /// person writes or pastes. Both open a session and replace what is on the
  /// bench, which is what they did from the first screen.
  ///
  /// **Required, where `onSettings` beside them is not**, and the difference is
  /// measured: a screen with no way in is a screen a person can be stranded
  /// on, and since rule 70 deleted the first screen these are the only two
  /// ways anything enters. Fifty mounts passing `() {}` would be fifty doors
  /// that open nothing; two required parameters are two compiler errors in the
  /// one place a door is forgotten.
  final VoidCallback onImport;

  /// **What the person wrote, with no document and no session yet** — rule 72,
  /// 18 October 2026.
  ///
  /// It was `onType`, and it meant «import this text as a document»: the way
  /// in strip's own box read a letter and the shell opened a session for it.
  /// Rule 72-أ deleted that box, and rule 72 gave what is typed its own
  /// meaning — it is **the request**, protected in the middle column and sent
  /// to the chat like any question, the whole of what leaves when no document
  /// stands above it. So this is the door for a first question asked on an
  /// empty surface: the shell opens a session (asking its language, as rule
  /// 57b requires) and sets the question in it. With a bench already there the
  /// box needs no door at all — `setQuestion` is the bench's own.
  final void Function(String text) onAsk;

  /// Open the vault screen over this one. Required rather than optional: a
  /// Workspace that cannot reach the vault has buttons that refuse into a
  /// sentence nobody sees, which is exactly what 041-B is about.
  final VoidCallback onVault;

  /// **«z-pdf» — the door back, at the top of the screen** — the owner, 24
  /// October 2026 (paper 108 item 3): «زر جلب وثيقة Z-PDF نجعله خياراً منفصلاً
  /// في أعلى الشاشة؛ الآن مكانه مخفي».
  ///
  /// This **amends rule 70's placing** (17 October 2026), which put the press
  /// in the Settings panel when the first screen's «+» menu was deleted with
  /// the screen. It was reachable there and the owner could not find it, which
  /// is the whole of what a hidden door is. Both dates stand because both are
  /// his: the act did not change, only where it is pressed.
  ///
  /// Nullable for the reason `onSettings` is: only the shell may open a file
  /// chooser, and a screen mounted by a guard about something else has nowhere
  /// to send the press — so the bar draws no door rather than a dead one.
  final VoidCallback? onReadBack;

  /// Open the settings panel, or shut it — one press does both, because the
  /// shell holds the state and this is the only thing that moves it.
  ///
  /// Null, and not required as `onVault` is, because the bar draws the door
  /// only when there is somewhere for it to go. The paper asked for «exactly
  /// as it already takes onVault», and `_TopBar` does take it exactly that
  /// way — but requiring it **here** would have made fifty places in the test
  /// suite pass `() {}`, which is fifty doors that open nothing: a lie the
  /// compiler would have been enforcing. What 063 was actually about is not a
  /// screen that could not be *given* the door — it is a screen nobody gave it
  /// to, which no signature can catch and
  /// `the_settings_cover_the_work_test.dart` does.
  ///
  /// **It takes a room since rule 74** (18 October 2026), and `null` means «the
  /// room the settings open on» — which is the settings' own default and the
  /// one place that rule lives. A door that needs a particular room names it:
  /// every «Open Settings» that is about a key says `SettingsRoom.ai`, because
  /// a door to a key that lands in the Sessions list is a door that does not
  /// answer.
  final void Function(SettingsRoom? room)? onSettings;

  /// **The surface starts from zero** — rule 71, 18 October 2026. Called when
  /// a chat ends under the thread; the shell is what lets the bench go,
  /// because the bench **is** the surface.
  ///
  /// Nullable for the reason `onSettings` is: a screen mounted by a guard
  /// about something else has nowhere to send it, and requiring it would have
  /// put `() {}` in fifty mounts — fifty acts that do nothing, a lie the
  /// compiler would enforce. «End the chat» still ends the chat in the core
  /// wherever this is null; only the surface emptying is missing, and the
  /// guard that measures *that* gives it a real one.
  final VoidCallback? onFromZero;

  /// **«Remove the document»** — rule 73, 18 October 2026: «نحتاج إلى خيار حذف
  /// الوثيقة وإضافة وثيقة أخرى».
  ///
  /// It empties the first part and takes nothing out — no exit, no bubble, no
  /// question (54-و) — and the document's kept copy stays in its session's
  /// list (54-ز), where it can be opened again. The chat and what is typed in
  /// the box stay: this removes a document, it does not end a chat (rule 71
  /// is the one that does).
  ///
  /// The shell's, because the bench is the shell's: removing means standing on
  /// a bench with no document, which is the state rule 72 made ordinary.
  final VoidCallback? onRemoveDocument;

  /// Whether the panel is already standing over this screen, so the bar can
  /// hide its own door while the panel covers the spot that door sits in. One
  /// owner sets both this and the panel — the shell — so the two cannot
  /// disagree, and a Workspace standing on its own has no panel over it.
  final bool settingsOpen;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  /// What the last act did, in the core's terms. Kept on screen rather than
  /// flashed in a toast: a user should be able to look back at what happened.
  String? _said;

  /// The anchor the Original column drops in at the word we are looking at.
  final _focusKey = GlobalKey();
  int? _wasFocused;

  /// **Where the window is looking** — the one slot the wash and the anchor
  /// read, and the reason 084's bar can go to a word that no finding covers.
  ///
  /// It follows the bench's focused finding whenever that changes (see
  /// `_jumpIfMoved`), so the review's list, the exits' guide and the walk all
  /// keep lighting what they always lit; and the search bar sets it directly
  /// for a place in the clear, which has no finding to focus.
  Span? _lookingAt;

  /// Remember the panel's width, which is a state only a press may change.
  ///
  /// Written through the core's settings beside `columnsInStep`, for the reason
  /// 046/K makes explicit: a state the app may not change by itself is a state
  /// it must be able to remember, or closing the program would change it for
  /// the person at every launch.
  void _rememberPanelWidth(bool wide) {
    final config = widget.ground.config;
    if (config == null || config.reviewPanelWide == wide) return;
    unawaited(widget.ground.saveConfig(config.with_(reviewPanelWide: wide)));
  }

  /// The word a person just pressed, and where on the screen they pressed it.
  ///
  /// The owner, 6 October: «the suggested names must appear on the text itself,
  /// not as a separate list, and the choices a small message that disappears
  /// when it is pressed». So the choice is a bubble at the word, and the review
  /// panel is what somebody opens from the Review button when they want the
  /// list of what is left — never what a press on a word opens.
  Finding? _choosing;
  Offset _choosingAt = Offset.zero;

  /// **Whose bubble it is**, and it decides one thing: whether a press anywhere
  /// else closes it.
  ///
  /// A bubble a person opened by pressing a word is dismissed by pressing
  /// beside it — the owner's «disappears when it is pressed», which cuts both
  /// ways. A bubble the **walk** put at a word is not that: it is the review's
  /// own form in the text, and the full-screen catcher would swallow the very
  /// press that walks on. Measured, not reasoned: with one barrier for both,
  /// «Next 1/4» closed the bubble and the walk stood still — and so did
  /// «Protect all» and «Skip all», because the barrier is over the panel too.
  bool _choosingFromTheWalk = false;

  void _closeBubble() {
    if (_choosing != null) setState(() => _choosing = null);
  }

  /// The word as the findings have it now, or null when it no longer waits.
  static Finding? _stillWaiting(Workbench bench, Finding? word) {
    if (word == null) return null;
    final now = bench.findings.where(
      (f) => f.id == word.id && f.state == MarkState.suggested,
    );
    return now.isEmpty ? null : now.first;
  }

  /// **The review, lived in the text** — 083 rulings 4, 5 and 14.
  ///
  /// One press: go to a word that is waiting, light it, and draw its own two
  /// buttons beside it. The first press lands on the first waiting word in
  /// reading order — the same word the exits' guide lands on (083a), through
  /// the same [theFirstWaitingWord] — and every press after that leaves the lit
  /// word for later and goes to the one after it.
  ///
  /// The list opens with it, and that is the second form rather than a second
  /// act: `openReview(walk: true)` both takes the panel's slot and turns on the
  /// state's own step-to-the-next-one, which is what makes an **answer** move
  /// the walk without a press (ruling 5).
  Future<void> _walk() async {
    final bench = widget.bench;
    // Every act below this line belongs to a document. Since rule 70 this
    // screen is also the screen with no document on it, and its own controls
    // are the only callers — so «nothing to walk through» is said once, here,
    // rather than assumed six times.
    if (bench == null) return;
    final lit = bench.focusedFinding;
    final walking = bench.walking && lit != null && lit.state == MarkState.suggested;
    final go = walking
        ? theWaitingWordAfter(bench.findings, lit)
        : theFirstWaitingWord(bench.findings);
    if (go == null) {
      // Nothing waits: the button that called this is already gone, and a
      // press that arrived with the last answer must not leave a bubble on a
      // word that has been settled.
      _closeBubble();
      return;
    }
    bench.openReview(walk: true);
    await _goTo(go);
  }

  /// **Go to a span** — 084's fourth act, and the same movement as the walk's.
  ///
  /// No bubble: the bar's result line is where that place's acts are, and a
  /// word in the clear has no question to answer at it. What this does is light
  /// the span and bring both columns to it.
  Future<void> _goToSpan(Span where) async {
    final bench = widget.bench;
    if (bench == null) return;
    setState(() {
      _lookingAt = where;
      // The walk's bubble belongs to the walk; a search took us elsewhere.
      _choosing = null;
    });
    await goToTheWord(bench, where, anchor: _focusKey);
  }

  /// Go to one word and put its buttons where it landed. The movement is the
  /// one function's; what is left here is the bubble, which belongs to this
  /// screen because it is drawn over both columns and over the panel.
  Future<void> _goTo(Finding word) async {
    final bench = widget.bench;
    if (bench == null) return;
    setState(() {
      _lookingAt = word.span;
      // Seen, so `_jumpIfMoved` does not move it a second time: this method
      // owns this movement and measures where it landed.
      _wasFocused = word.id;
    });
    final at = await goToTheWord(
      bench,
      word.span,
      anchor: _focusKey,
      finding: word.id,
    );
    if (!mounted) return;
    setState(() {
      // **No place on the glass, no buttons.** A word in a column that is not
      // drawn — nothing open, a frame that has not run — would otherwise put
      // its two buttons in the corner of the window, beside nothing.
      _choosing = at == null ? null : word;
      _choosingAt = at ?? Offset.zero;
      _choosingFromTheWalk = true;
    });
  }

  /// **Answering moves the walk on by itself** — ruling 5.
  ///
  /// The next word is taken **here**, by reading order, after the answer has
  /// landed: `Workbench.answer` steps the focus on by itself too, but it reads
  /// the core's own order — the order its layers found things in — and the
  /// walk's order is the eye's. That file is the other seat's, so the walk
  /// asks for the word it wants rather than taking the one it is given, and
  /// `the_review_in_two_forms_test.dart` holds it to reading order. When
  /// `session_state.dart` is next open, that step becomes
  /// [theWaitingWordAfter] and this line becomes a no-op.
  Future<void> _answer(Finding word, FindingAnswer choice) async {
    final bench = widget.bench;
    if (bench == null) return;
    // **Only the walk walks on.** A person who pressed a word in the text
    // answered *that* word: the bubble goes and they are left where they were
    // reading, which is what they asked for. Moving them to another word
    // because they answered this one would be the app deciding where to look
    // next, and that is the Review press's own job.
    final walking = _choosingFromTheWalk;
    _closeBubble();
    await bench.answer(word.id, choice);
    if (!mounted || !walking) return;
    final next = theWaitingWordAfter(bench.findings, word);
    if (next == null) {
      // The last answer: nothing is lit, nothing is waiting, and the exits are
      // open. Ruling 10, which is also why the Next button is gone by now.
      bench.focusOn(null);
      return;
    }
    await _goTo(next);
  }

  /// Go to a page by pointing the column's own anchor at it.
  ///
  /// The anchor already exists — it is how «page 17» in the review list became
  /// a place a person arrives at — so going to a page is choosing which finding
  /// it points at: the first one on that page.
  void _goToPage(int page) {
    final bench = widget.bench;
    if (bench == null) return;
    final onIt = bench.findings.where((f) => f.place?.page == page);
    if (onIt.isEmpty) {
      // Nothing was found on it, so there is nothing to point at — and saying
      // so is better than a jump that does not happen.
      setState(() => _said = sentences.pageHasNothingMarked(page));
      return;
    }
    // The same one function the walk uses (ruling 14). A page is a word to
    // arrive at, and the only thing that differs is which word.
    unawaited(_goTo(onIt.first));
  }

  /// «Page 17» has to be a place you arrive at, not a label. When the review
  /// list points somewhere new, the column scrolls there after the frame that
  /// drew the anchor.
  void _jumpIfMoved() {
    final bench = widget.bench;
    if (bench == null) return;
    final now = bench.focused;
    if (now == _wasFocused) return;
    _wasFocused = now;
    // The focus moved, so what we are looking at moved with it — set here and
    // not in the setter of a second slot, because this is the one place that
    // notices the change, however it was made.
    final span = bench.focusedFinding?.span;
    _lookingAt = span;
    if (now == null || span == null) return;
    // **One movement, one owner** — 083, ruling 14, and a defect measured when
    // 084's bar shortened this column: this used to do its own
    // `ensureVisible`, so a focus change moved the word **twice** — once
    // through the one function, which measures where the word landed so the
    // walk can put the word's two buttons beside it, and once here,
    // afterwards, which moved the word out from under them. The bubble was
    // then drawn at y=1028 in a window 1000 tall, and the press that should
    // have answered a suggestion landed on nothing.
    //
    // So this path goes through the same function as every other, and `_goTo`
    // — which moves the focus itself — marks the change as seen before it
    // calls, so there is never a second movement for one word.
    unawaited(goToTheWord(bench, span, anchor: _focusKey));
  }

  /// The way to the settings, handed on **only while the panel is shut**, and
  /// **naming the room it opens** — rule 74, 18 October 2026.
  ///
  /// The panel used to open on whatever its own default was, and the owner's
  /// ruling moved that default to «Sessions»: the room he wants first is the
  /// list of what he kept. But the send sheet's «Open Settings» is a door to
  /// **a key**, and a door that lands a person in the wrong room is a door
  /// that does not answer. So the room travels with the press: the gear opens
  /// the room rule 74 names, and every door that is about a credential says
  /// «AI» out loud.
  ///
  /// The shell's `onSettings` is a toggle — `_settingsOpen = !_settingsOpen`
  /// — and the ✨AI control stays on the bar while the panel stands, so the
  /// send sheet can be opened over an open panel. Handing the toggle on there
  /// would give the sheet a door labelled «Open Settings» that **shuts** them.
  /// Null instead: the sheet says its line, draws no door, and closing it
  /// uncovers the panel that is already there. A surface with nowhere to send
  /// the press draws no door — 063's rule, in a case that only shows up from
  /// the sheet.
  void Function(SettingsRoom? room)? get _toSettings =>
      widget.settingsOpen ? null : widget.onSettings;

  /// The gear: no room named, so the settings open on the room rule 74 names.
  VoidCallback? get _toTheSettings {
    final open = _toSettings;
    return open == null ? null : () => open(null);
  }

  /// The same door for a press that is about a key: the AI room, by name.
  VoidCallback? get _toTheKeys {
    final open = _toSettings;
    return open == null ? null : () => open(SettingsRoom.ai);
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    _jumpIfMoved();
    return ListenableBuilder(
      // **Both**, since 046/K. This screen has always read `ground` — the pack
      // label, the handle's remembered position — while listening only to
      // `bench`, so a `ground` change was redrawn whenever the bench happened
      // to notify next. The two column states are changed by a press that
      // touches `ground` and nothing else, so that «happened to» became a
      // column that did not come back. Measured by the rule test: the config
      // said open and the screen still drew the rail.
      // **`Listenable.merge` takes nulls and ignores them**, which is why a
      // screen with no bench listens to the ground alone without a branch
      // here: `List<Listenable?>` is the signature.
      listenable: Listenable.merge([bench, widget.ground]),
      // **Alt+Left is gone with the screen it went back to** — rule 70, «لا
      // أسهم بين شاشات لأنه لا شاشات». It was the back door of every document
      // reader there is, and the owner reached for it before he found the
      // arrow; there is no longer anywhere for it to arrive.
      // `CallbackShortcuts` needs somewhere for the keys to land, so the focus
      // node under it is autofocused: nothing else on this screen takes focus
      // on arrival.
      builder: (context, _) => CallbackShortcuts(
        bindings: {
          // A bubble closes the way every small thing closes.
          const SingleActivator(LogicalKeyboardKey.escape): _closeBubble,
        },
        // **The focus arrives in the box at the top** — rule 70, and the
        // reason is the owner's own, carried over from the first screen: «a
        // person who opened this app to paste a letter can paste it». So the
        // autofocus that stood here, on nothing but a holder for the keys, is
        // on the writing box instead; the keys still land because the box is
        // inside this subtree and nothing in a `TextField` eats Escape. Two
        // autofocus requests in one scope is a framework warning, which is why
        // this is a move and not an addition.
        child: Focus(
        child: Scaffold(
        body: Stack(
          children: [
        Column(
          children: [
            _TopBar(
              bench: bench,
              ground: widget.ground,
              onPage: _goToPage,
              onVault: widget.onVault,
              onLockVault: () => unawaited(widget.ground.lockVault()),
              onSettings: _toTheSettings,
              onReadBack: widget.onReadBack,
              settingsOpen: widget.settingsOpen,
            ),
            // **The way in for a file, at the top of the screen** — rule 70,
            // and one door since rule 72-أ: the box that stood beside the «+»
            // is deleted and what is typed goes in the request box in the
            // first part, which is the one place a person writes.
            //
            // **A strip of its own and not a part of the bar**, and the reason
            // is measured: with «Documents» on it the bar's own content came to
            // 2.8 px of slack at a 900-wide window (064/B, and it cost the page
            // count its place). Deleting that control gives back about 110 px
            // — enough for a «+», nowhere near enough for a box a person
            // writes a letter into. The bar keeps its facts; the entry gets its
            // own row, directly under it, which is «أعلى الشاشة» either way.
            _TheWayIn(onImport: widget.onImport, busy: bench?.busy ?? false),
            if (bench != null) _Band(bench: bench, onVault: widget.onVault),
            // **A document that came back says so, in its own line** — 079,
            // the import side. Under the band and not in it: that row already
            // holds the two longest sentences on this screen and overflowed by
            // 15 pixels the first time a third child was drawn in it
            // (14 October, item 3). This one is about the document rather than
            // about the scan, and it is drawn only when there is a token in it.
            if (bench != null) _CameBack(bench: bench),
            // **And what the disk said, if the act itself said nothing** —
            // paper 102 §2. `troubleToShow` is the act's own refusal or the
            // standing verdict, because the fault this band was reddened for
            // is one a press cannot report: the press *did* protect, in
            // memory, and only the disk refused.
            if (bench?.troubleToShow != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Trouble(bench!.troubleToShow!),
              ),
            // **The three parts, with nothing in them yet** — rule 70. Not a
            // second screen and not a page of prose: the same three regions,
            // each saying the one thing it is for, so that what arrives when a
            // document does is in the place the person was already looking at.
            if (bench == null)
              Expanded(child: _TheThreePartsEmpty(onAsk: widget.onAsk))
            else
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // A side panel takes a third of the window, never more than
                  // 460 and never less than 280: the two columns are the product
                  // and must stay readable behind whatever is open over them.
                  final panel = (box.maxWidth * 0.33).clamp(280.0, 460.0);
                  // **While a panel is open the document comes to the middle**
                  // (046/K, the owner: «أريد جعل النص في حالة المعاينة ينتقل
                  // إلى نصف الشاشة ليصبح مركزياً بدلاً من تركه إلى جانب
                  // الهامش»).
                  //
                  // `Expanded` took everything the panel left, so at 1920 the
                  // columns were 1460 wide and began hard against the left
                  // edge while the review sat on the right. That edge is the
                  // margin he means.
                  //
                  // Capped at half the window and centred in what is left.
                  // Nothing here touches `_Columns`, the split inside it, or
                  // `originalPanePercent` — the person's own setting keeps its
                  // meaning, applied to a narrower block.
                  // 071 — one value, so «is a panel open» is one question
                  // with one answer rather than four booleans ORed together.
                  final panelOpen = bench.panel != OpenPanel.none;
                  // **The panel's second width, reached by a press** (046/K,
                  // the owner: «الطوي والفتح لا يتم تلقائياً، يتم بالضغط على
                  // إشارة محددة»). Wider is a state the person chose and it is
                  // remembered in `zcfg`; nothing here widens by itself.
                  final wide = widget.ground.config?.reviewPanelWide ?? false;
                  final panelWidth = wide
                      ? (box.maxWidth * 0.5).clamp(380.0, 760.0)
                      : panel;
                  return Row(
                    children: [
                      Expanded(
                        child: _Middle(
                          centred: panelOpen,
                          width: box.maxWidth / 2,
                          child: _Columns(
                          bench: bench,
                          ground: widget.ground,
                          said: _said,
                          focusKey: _focusKey,
                          onSettings: _toTheKeys,
                          onRemoveDocument: widget.onRemoveDocument,
                          onSay: (line) => setState(() => _said = line),
                          onWalk: () => unawaited(_walk()),
                          onGoToSpan: _goToSpan,
                          lookingAt: _lookingAt,
                          onChoose: (mark, at) {
                            // The finding behind the mark, by the place it
                            // stands: a mark carries no id, and the span is
                            // what the two share.
                            final found = bench.findings.where(
                              (f) => f.span.start == mark.span.start && f.span.end == mark.span.end,
                            );
                            if (found.isEmpty) return;
                            setState(() {
                              _choosing = found.first;
                              _choosingAt = at;
                              _choosingFromTheWalk = false;
                            });
                          },
                          ),
                        ),
                      ),
                      // The names panel takes the same place as the review
                      // panel: one panel at a time, and the one asked for.
                      // One arrow for whichever panel is open, because it is
                      // about the panel's width and not about its contents.
                      // Four copies of it would be four places to word one act.
                      if (panelOpen)
                        _PanelArrow(
                          wide: wide,
                          onTap: () => _rememberPanelWidth(!wide),
                        ),
                      // **One slot, one value, one panel — 071.** This was a
                      // precedence chain over four booleans, and two of them
                      // were separate `if`s: Review then Tokens drew both, in
                      // a slot whose comment above promises one. A `switch`
                      // over the value cannot draw two, and the analyzer makes
                      // it name every panel there is.
                      switch (bench.panel) {
                        OpenPanel.none => const SizedBox.shrink(),
                        OpenPanel.names => NameReviewPanel(
                          bench: bench,
                          ground: widget.ground,
                          width: panelWidth,
                          onVault: widget.onVault,
                        ),
                        OpenPanel.review => ReviewPanel(
                          bench: bench,
                          width: panelWidth,
                        ),
                        OpenPanel.tokens => TokensPanel(
                          bench: bench,
                          width: panelWidth,
                        ),
                        // **The third part of the one screen** — rule 65.
                        // `AnswerPanel` stood here: one answer at a time, with
                        // arrows between answers and a switch over the whole
                        // panel. The conversation stands here now, coded, with
                        // the compose box at its foot — and the answer is a
                        // line in it rather than a place to go.
                        OpenPanel.chat => TheChat(
                          bench: bench,
                          ground: widget.ground,
                          width: panelWidth,
                          onSettings: _toTheKeys,
                          // **Rule 71**: the chat ends and the surface starts
                          // from zero. The panel ends the chat in the core;
                          // what the surface then does is the shell's.
                          onEnded: widget.onFromZero,
                        ),
                      },
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        // The choice at the word. Over everything, because it belongs to the
        // word and not to a column; and nothing else on this screen moves while
        // it is open.
        // **The buttons belong to a word that is still waiting.** Read from the
        // findings rather than kept beside them: «Protect all» in the list, or
        // an answer given at another place of the same word, takes the question
        // away — and a bubble left over it would offer an answer to a word that
        // has one. Measured: after «Protect all» the walk's bubble stood on a
        // settled word with nothing waiting anywhere.
        if (bench != null && _stillWaiting(bench, _choosing) != null) ...[
          if (!_choosingFromTheWalk)
            Positioned.fill(
              // A press anywhere else closes it and does nothing — the owner's
              // «disappears when it is pressed» cuts both ways. Only for a
              // bubble a press opened; see `_choosingFromTheWalk`.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeBubble,
              ),
            ),
          ChoiceBubble(
            finding: _stillWaiting(bench, _choosing)!,
            at: _choosingAt,
            onAnswer: (choice) => unawaited(_answer(_choosing!, choice)),
            onDone: _closeBubble,
          ),
        ],
          ],
        ),
      ),
      ),
      ),
    );
  }
}

/// **The way in for a file, at the top of the screen** — rule 70, and one box
/// since rule 72-أ.
///
/// The owner, 17 October: «نلغي الشاشة الأولى ونجعل إدخال الملفات يتم أعلى
/// الشاشة» — both doors that bring a text in used to stand on a first screen
/// that no longer exists, so the file door stands here, drawn whether or not
/// something is already open. With no first screen and no «back», this is the
/// only way to begin the next piece of work; the document it replaces is not
/// lost, because a document in the preview is kept (089 rule 9) and the
/// Sessions room opens it again.
///
/// **The box that stood beside it is deleted** — rule 72-أ, the owner's «نعم»
/// of 18 October: «صندوق واحد للكتابة لا اثنان». It was «Write or paste your
/// text here… · Open and scan», and it was a second place to write: what is
/// typed goes in the request box in the first part now (rule 72), where it is
/// protected, where it leaves from, and where it becomes a z-pdf by the same
/// road. Rule 35 is the reason it is deleted rather than hidden.
///
/// **z-pdf is not here.** It was the second entry of this «+» menu until rule
/// 70 put it in Settings: it is the reverse act, never scanned and never put
/// on a bench, and a person who means it has already said so. One press, one
/// meaning — so this «+» is a button and not a menu.
class _TheWayIn extends StatelessWidget {
  const _TheWayIn({required this.onImport, required this.busy});

  final VoidCallback onImport;

  /// True while the core is reading something. The press goes quiet rather
  /// than queueing a second import behind the first.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      decoration: const BoxDecoration(
        color: Zc.warmCard,
        border: Border(bottom: BorderSide(color: Zc.line)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: sentences.addADocumentPdfWordOrText,
            child: IconButton(
              key: WorkspaceScreen.addDocument,
              onPressed: busy ? null : onImport,
              icon: const Icon(Icons.add, size: 20),
              color: Zc.clay,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 10),
          // **What the «+» is for, in words** — because a bare icon at the top
          // of an empty screen is a control nobody can be sure of, and the
          // sentence it used to stand beside («Write or paste your text
          // here…») was the deleted box's.
          Expanded(
            child: Text(
              sentences.addADocumentOrWriteToTheAi,
              style: Zc.small.copyWith(color: Zc.ink4),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// **The three parts with nothing in them yet** — rule 70.
///
/// Not a welcome page: the same three regions this screen always has, each
/// saying the one thing it is for. A person who writes in the strip above
/// watches the first of them fill, which is why the sentences describe the
/// places and not the product.
///
/// The two columns' own words are the ones the `_Side` headers use, so the
/// empty screen and the full one call the same region the same thing.
class _TheThreePartsEmpty extends StatelessWidget {
  const _TheThreePartsEmpty({required this.onAsk});

  /// **Rule 72: the box is here from the first moment.** The first part draws
  /// it with no document and no session at all, and the press hands what was
  /// written to the shell, which opens a session for it. Before this the three
  /// parts were three sentences and a person with no document had nowhere to
  /// write — which is the whole of what the owner met.
  final void Function(String text) onAsk;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _part(
          sentences.originalLocalOnly,
          sentences.neverSentToAiSendCannotRead,
          sentences.yourDocumentArrivesHere,
          Zc.ink4,
          // Rule 72: and under that sentence, the one box — so the first thing
          // a person can do on an empty surface is write to the AI.
          footer: _TheQuestion(onAsk: onAsk),
        ),
        Container(width: 1, color: Zc.line),
        _part(
          sentences.safeAiWillReceive,
          sentences.theRequestItselfNotAPreview,
          sentences.whatAnAiWouldReceiveStandsHere,
          Zc.clay,
        ),
        Container(width: 1, color: Zc.line),
        _part(
          sentences.theChatTitle,
          sentences.yourQuestionsAndWhatCameBack,
          // **«Chat» and not «the conversation»** — rule 55-هـ, and G41 is what
          // said so: on the glass the word for a container is «session», and
          // this part is called «The chat» in the owner's own ruling (65).
          sentences.theChatOpensHereWithTheFirstAnswer,
          Zc.river,
        ),
      ],
    );
  }

  Widget _part(
    String eyebrow,
    String rule,
    String what,
    Color tint, {
    Widget? footer,
  }) =>
      Expanded(
        child: Container(
          color: Zc.paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(eyebrow, color: tint),
                    const SizedBox(height: 4),
                    Text(rule, style: Zc.tiny.copyWith(letterSpacing: 0)),
                    const SizedBox(height: 16),
                    Text(what, style: Zc.small.copyWith(color: Zc.ink4)),
                  ],
                ),
              ),
              // The box is given the rest of the part rather than a height of
              // its own: it is a box a letter can be pasted into, and the part
              // it stands in is as tall as the window.
              if (footer != null) Flexible(child: SingleChildScrollView(child: footer)),
            ],
          ),
        ),
      );
}

/// The seven things that change the ground the Workspace stands on. In M7.1 they
/// *report* — each becomes an act in its own milestone, and the behaviour board
/// already says what each must ask before it changes an open document.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.bench,
    required this.ground,
    required this.onPage,
    required this.onVault,
    required this.onLockVault,
    required this.onSettings,
    required this.onReadBack,
    required this.settingsOpen,
  });

  /// Null while nothing is open — rule 70. The bar then states the two facts
  /// that are still true of the app (the vault, and the way to the settings)
  /// and says nothing about a document, a profile or a pack, because there is
  /// no document for any of those to be about.
  final Workbench? bench;
  final Ground ground;

  /// Go to a page: the Original column scrolls to the first finding on it.
  final void Function(int page) onPage;

  /// The bar's own way to the vault, and its own way to shut it.
  final VoidCallback onVault;
  final VoidCallback onLockVault;

  /// The bar's way to the settings — 063. Until it existed the settings were
  /// worse than a dead end from a document: they were unreachable, because a
  /// full-screen settings page reached from here would have hidden the
  /// document. Null means this bar has nowhere to send a press, and then it
  /// draws no door rather than a dead one.
  final VoidCallback? onSettings;

  /// **The door back** — paper 108 item 3. Null means no shell behind this
  /// screen, and then no door is drawn: `WorkspaceScreen.onReadBack` carries
  /// the whole of why.
  final VoidCallback? onReadBack;
  final bool settingsOpen;

  /// The door back, so a guard reaches it by what it is and not by the word on
  /// it — the same reason `_VaultRoom.theDoorBack` had one in the room this
  /// press came from.
  static const theDoorBack = ValueKey<String>('top-bar-z-pdf');

  @override
  Widget build(BuildContext context) {
    final bench = this.bench;
    final doc = bench?.document;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(bottom: BorderSide(color: Zc.line)),
      ),
      child: Row(
        children: [
          // **The way back is gone, and so is the screen it went back to** —
          // rule 70, the owner: «لا أسهم بين شاشات لأنه لا شاشات». What stood
          // here was an arrow and the word «Documents», and the mark beside it
          // was a second door to the same place. One screen has no «back», and
          // a control that goes nowhere is deleted rather than disabled
          // (rule 35).
          //
          // What is left is the mark itself, which is not a door: the owner's
          // picture, at the lettered tile's own 28 px (072). The product's own
          // name stands beside it only while no document does — the bar
          // overflowed by 50 px at 964 wide once the AI door was on it, and of
          // everything standing there the name is the one thing a person is not
          // reading when their own document is open.
          const Padding(
            padding: EdgeInsets.all(3),
            child: BrandMark(size: 28),
          ),
          // **A document is a document when it has text in it** — paper 102
          // §4. `WorkspaceSnapshot.document` is not an `Option`, so a bench
          // with nothing on it hands the glass an **empty** `DocumentView`
          // whose name is empty too — and this row then drew the notes icon
          // and «Typed text» over a surface that held no document at all. The
          // owner read that label beside «Not scanned yet» on the night of the
          // two windows. (Making the field an `Option` is the one-screen
          // round's, named in the paper: it is a change every reader of the
          // snapshot pays for, and this reads the text it already has.)
          if (doc == null || doc.text.isEmpty) ...[
            const SizedBox(width: 10),
            const Text(
              'Z Privacy',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Zc.ink),
            ),
            // **And the session's name stands as soon as a session is open** —
            // the owner's wish, twice on 22 October: he picked session 1 from
            // the room and the top of the screen said nothing of it until a
            // document was brought in, because the only place the session's
            // name was drawn sat inside the branch below. A session is what
            // the work belongs to, document or no document.
            if (ground.openSessionRow != null) ...[
              const SizedBox(width: 9),
              Flexible(child: TheOpenSession(ground: ground, compact: true)),
            ],
          ],
          const SizedBox(width: 14),
          if (doc != null && doc.text.isNotEmpty) ...[
            Icon(
              doc.kind == DocumentKind.pdf
                  ? Icons.picture_as_pdf_outlined
                  : doc.kind == DocumentKind.docx
                  ? Icons.article_outlined
                  : Icons.notes_outlined,
              size: 16,
              color: Zc.ink3,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                doc.name.isEmpty ? sentences.typedText : doc.name,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Zc.ink,
                ),
              ),
            ),
            // **The session, beside the document it is being worked in** —
            // 064/B, the owner's own words: more than one session means more
            // than one direction of work, and he found his first one named
            // only in the panel's list.
            //
            // It stands next to the file's name because the two are one
            // statement: this document, in this session.
            //
            // **One gap, either way.** The first form of this drew its own
            // 9 px spacer unconditionally, beside a widget that draws nothing
            // when no session is open — and 9 px against this bar's 2.8 px of
            // margin is 6.2 px over at 900, which is exactly what
            // `the_settings_cover_the_work_test` then read with the panel up.
            // A spacer is an element too.
            if (ground.openSessionRow != null) ...[
              const SizedBox(width: 9),
              Flexible(child: TheOpenSession(ground: ground, compact: true)),
            ],
            // Flexible for the same reason the word «Documents» is, and
            // measured in the same breath: the back control alone brought 900
            // from 41 px over to 2.8, which is a margin of one and a half
            // pixels — a longer pack name or a second page would spend it. The
            // page count is the lowest-value text on a crowded bar and the
            // Page menu says it again whenever there is more than one.
            //
            // **And 2.8 px is what the session's name spends** (064/B). The
            // lead's rule, given before the line was written: if 900 cannot
            // hold all of it, the count is the first thing sacrificed — the
            // Page menu says it again, and nothing but the session's own name
            // says the session.
            //
            // **And it cannot hold both: 6.2 px over at 900** with the count
            // standing beside the session's name, 0 with it stepping aside —
            // measured with a fresh tree for the reading, because an overflow
            // is reported once per render object for its whole life. So the
            // sacrifice has a number, and it is this one.
            if (ground.openSessionRow == null) ...[
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  doc.pages == 1 ? sentences.onePage : sentences.pagesCount(doc.pages),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Zc.small.copyWith(color: Zc.ink4),
                ),
              ),
            ],
          ],
          const Spacer(),
          // **Everything the bar says about a document, behind one gate.**
          //
          // The profile that ran, and the rule set that ran: two facts about a
          // reading, and with nothing being read there is nothing truthful for
          // either of them to say. They were computed at the head of this
          // build and handed down; each now takes the bench and works its own
          // sentence out, which is what made this gate one line instead of
          // five nullable locals (rule 70).
          if (bench != null) ...[
            // **The profile door, only while there is a profile to choose.**
            // 075a, and 067's rule applied a second time: a work surface keeps
            // what it can act on and the catalogue lives on the board. With one
            // profile in the vault the only choice this dialog offers is
            // «Everywhere» or the single thing there is, which is the control
            // the owner says he never understood because he never needed it.
            //
            // The second half of the condition is not symmetry: a bench already
            // **inside** a profile must keep the control however few exist, or a
            // person stands in a state they can neither see nor leave — and this
            // top bar's own rule is that it names what actually ran.
            if (ground.profiles.length > 1 || bench.profileId != null)
              _ProfileFact(bench: bench, ground: ground),
            _PackFact(bench: bench, ground: ground),
          ],
          // The permanent door. 041-N made the vault the way in, and the bar
          // was left stating a fact nobody could act on: the only ways back to
          // it from a document were the review panels' buttons, and a person
          // with nothing to review had none. One press opens it; a second,
          // while it is open, shuts it — the thing a person wants when they
          // stand up from the desk.
          _Fact(
            label: sentences.vaultLabel,
            value: switch (bench?.snap?.vault ?? ground.vault) {
              VaultState.unlocked => sentences.vaultIsUnlocked,
              VaultState.locked => sentences.vaultIsLocked,
              VaultState.absent => sentences.vaultIsNone,
            },
            tint: (bench?.snap?.vault ?? ground.vault) == VaultState.unlocked
                ? Zc.river
                : Zc.ink4,
            onTap: () async {
              final open = (bench?.snap?.vault ?? ground.vault) == VaultState.unlocked;
              if (!open) {
                onVault();
                return;
              }
              // Open already: the press asks which of the two things it meant.
              final what = await showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(1e4, 54, 12, 0),
                color: Zc.paper,
                // **Not `const` any more** — a widget that holds a sentence
                // reads it from the list, and the list is read at run time.
                items: [
                  PopupMenuItem(value: 'open', child: Text(sentences.openZVault)),
                  PopupMenuItem(value: 'lock', child: Text(sentences.lockNow)),
                ],
              );
              if (what == 'open') onVault();
              if (what == 'lock') onLockVault();
            },
            hint: (bench?.snap?.vault ?? ground.vault) == VaultState.unlocked
                ? sentences.openZVaultOrLockItNow
                : sentences.openZVault,
          ),
          // **«z-pdf» — the door back, beside the vault that gives it its
          // meaning** (paper 108 item 3, the owner, 24 October 2026).
          //
          // Here rather than in the Settings panel, which is where rule 70 put
          // it on 17 October: «الآن مكانه مخفي». The place is next to the
          // vault's own state on purpose — the names a z-pdf carries live in
          // the vault, and with it locked this press opens the vault instead
          // of a file (079 rule 8, held in the shell, travelling unchanged).
          //
          // **Drawn with or without a document**, because the door takes no
          // bench at all: a person who has a z-pdf on their disc and nothing
          // on the surface is the ordinary case for it.
          //
          // The word is the product's own, which is why it is written here and
          // not in the one list — «z-pdf» is the same in every language, and
          // G50 names it as one of the two product names that may stand in a
          // file (`'Z Privacy'` is the other, eight lines above).
          if (onReadBack != null) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: sentences.chooseAZPdfFile,
              child: TextButton.icon(
                key: theDoorBack,
                onPressed: onReadBack,
                icon: const Icon(Icons.undo_outlined, size: 16),
                label: const Text('z-pdf',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: Zc.river,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
          // **Which page.** The owner, 7 October: a page must show its
          // beginning and its end — and once it does, a person wants to go to
          // one. The column scrolls to the first finding on that page, or to
          // the page's own edge when nothing on it was found.
          if (doc != null && doc.pages > 1) ...[
            const SizedBox(width: 10),
            PopupMenuButton<int>(
              tooltip: sentences.goToAPage,
              onSelected: onPage,
              itemBuilder: (_) => [
                for (var page = 1; page <= doc.pages; page++)
                  PopupMenuItem<int>(value: page, child: Text(sentences.pageNumber(page), style: Zc.small)),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sentences.pageWord,
                      style: Zc.small.copyWith(color: Zc.ink3, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Zc.ink3),
                ],
              ),
            ),
          ],
          // The AI door, open at any time. The choice of provider, model and
          // mode is not a reward for finishing the review: it is the first
          // thing a person wants to see, and the review gates the **send**.
          if (doc != null) ...[
            const SizedBox(width: 14),
            Tooltip(
              message: sentences.chooseTheAiAndWhatTravels,
              child: TextButton.icon(
                // **A send lands in the chat, and the chat is on this screen**
                // — rule 65. It used to answer `true` and the press took the
                // person *home*, to the one place a conversation was drawn.
                // There is no home: the third part of this screen opens by
                // itself when the answer arrives (`session_state.dart`), so
                // what this press has to do is open the doors and nothing
                // else. The answer the sheet gives is no longer read by
                // anybody — a send moves nobody anywhere.
                // **The order is not written here** — `theWayToTheDoors`
                // holds it, where a guard can drive it: the preview side is
                // opened first, because rule 60 took the sheet's own copy of
                // the outgoing text away and this door can be pressed with
                // that side closed.
                onPressed: () async {
                  await theWayToTheDoors(
                    context,
                    ground: ground,
                    bench: bench!,
                    onSettings: onSettings,
                  );
                },
                icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: const Text('AI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: Zc.clay,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
          // Numbers about this document, for a person who cannot send us the
          // document itself. The core writes every line of it.
          if (doc != null) ...[
            const SizedBox(width: 6),
            CopyReportButton(
              compact: true,
              onCopy: () async {
                // The emptying first, and the report read into a name of its
                // own: with the `await` inside the call, a `reportText()` that
                // threw wrote nothing and left the clipboard holding whatever
                // was there — the same shape as the owner's 12 October leak.
                await emptyTheClipboardFirst();
                final report = await bench!.reportText();
                await Clipboard.setData(ClipboardData(text: report));
              },
            ),
          ],
          // **The settings, 063.** Last on the bar, beside the AI door, and
          // drawn only while the panel is shut: the panel covers the right 480
          // and this spot is under it, so the door a person presses to close it
          // is the panel's own — the same widget, at the same point on the
          // glass, because the two paddings are the same 18/13.
          if (!settingsOpen && onSettings != null) ...[
            const SizedBox(width: 4),
            SettingsDoor(open: false, onTap: onSettings!),
          ],
        ],
      ),
    );
  }
}

/// **The rule set that ran, and the way to change it** — the bar's own fact.
///
/// Written out of `_TopBar` by rule 70, and not for tidiness: the bar now
/// stands over a screen with no document on it, and «which pack read this» has
/// no truthful answer there. A fact that needs a bench takes one, so the bar's
/// own `if (bench != null)` is the whole of the difference — rather than five
/// locals computed at the head of a build that may have nothing to compute
/// them from.
class _PackFact extends StatelessWidget {
  const _PackFact({required this.bench, required this.ground});

  final Workbench bench;
  final Ground ground;

  @override
  Widget build(BuildContext context) {
    // What actually ran, not what the session was opened with. A profile may
    // run two rule sets at once, and naming only one of them here would say
    // «German» over a document whose English label had just been detected.
    final active = ground.profiles
        .where((p) => p.id == bench.profileId)
        .expand((p) => p.languages)
        .toList();
    final ran = active.isEmpty ? [bench.packId] : active;
    // One name per language, from the core's table — so the bar, the menu and
    // the vault's lists all call a language the same thing.
    final packLabel = ran.map(ground.languageName).join(' · ');
    // «general rules» is said when **nothing** that ran has rules of its own.
    final bare = ran.every((id) => !ground.hasRules(id));
    return PopupMenuButton<String>(
          tooltip: sentences.readThisDocumentWithAnotherRuleSet,
          enabled: !bench.busy && ground.packs.isNotEmpty,
          onSelected: (id) => bench.switchPack(id),
          itemBuilder: (_) => [
            for (final p in ground.packs.where((p) => offeredLanguages.contains(p.id)))
              PopupMenuItem<String>(
                value: p.id,
                child: Row(
                  children: [
                    Icon(
                      ran.contains(p.id) ? Icons.check : Icons.check_box_outline_blank,
                      size: 15,
                      color: ran.contains(p.id) ? Zc.river : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    Text(p.label, style: Zc.small),
                  ],
                ),
              ),
            // A line, and under it every other language **that is
            // offered**. The owner, 6 October: the list shows both, and the
            // line is what tells them apart — and since 041-Q both halves can
            // be chosen, because a language with no dictionary still has the
            // general rules, the vault, and the person's own list. The list is
            // the core's, filtered by what 080 offers: this menu writes the
            // open session's language through `switch_pack`, so it is a third
            // door to the same value and may not offer what the other two do
            // not. Nothing is deleted — the packs are in the core, and the
            // day a third is offered one list changes.
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              enabled: false,
              child: Text(sentences.generalRulesOnly, style: Zc.tiny),
            ),
            for (final other in ground.languages
                .where((l) => !l.hasRules && offeredLanguages.contains(l.id)))
              PopupMenuItem<String>(
                value: other.id,
                child: Row(
                  children: [
                    Icon(
                      ran.contains(other.id) ? Icons.check : Icons.check_box_outline_blank,
                      size: 15,
                      color: ran.contains(other.id) ? Zc.river : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(other.label, style: Zc.small)),
                    const SizedBox(width: 10),
                    Text(other.id.toUpperCase(), style: Zc.tiny.copyWith(color: Zc.ink4)),
                  ],
                ),
              ),
          ],
          // The bar names the language — from the core's table, so one
          // language has one name everywhere — and says when all it has is
          // the general rules. «Svenska» and «العربية · general rules» are
          // read the same way: this is what ran.
          child: _Fact(
            label: sentences.packLabel,
            value: bare ? sentences.packWithGeneralRules(packLabel) : packLabel,
          ),
        );
  }
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({required this.bench, required this.ground});

  final Workbench bench;
  final Ground ground;

  @override
  Widget build(BuildContext context) {
    // **The profile's own name, worked out where it is drawn** — moved in from
    // the head of `_TopBar.build` by rule 70, for the same reason the pack's
    // was: the bar stands over a screen with no bench on it, and a local
    // computed from one cannot be computed there at all.
    final value = bench.profileId == null
        ? sentences.everywhere
        : ground.profiles
              .firstWhere(
                (p) => p.id == bench.profileId,
                orElse: () =>
                    ProfileRow(id: bench.profileId!, name: bench.profileId!, languages: const []),
              )
              .name;
    final enabled = ground.vault == VaultState.unlocked;
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: InkWell(
        key: ProfileSwitcher.door,
        onTap: enabled
            ? () => showDialog<void>(
                context: context,
                builder: (_) => ProfileSwitcher(bench: bench, ground: ground),
              )
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Eyebrow(sentences.profile),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Zc.ink2,
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 14, color: Zc.ink4),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileSwitcher extends StatefulWidget {
  const ProfileSwitcher({super.key, required this.bench, required this.ground});

  /// The one door to this dialog, wherever it stands. Named so a guard can ask
  /// «is there a way in from here» rather than hunting for a word on a screen.
  static const door = ValueKey<String>('profile-door');

  final Workbench bench;
  final Ground ground;

  @override
  State<ProfileSwitcher> createState() => _ProfileSwitcherState();
}

class _ProfileSwitcherState extends State<ProfileSwitcher> {
  String? _trouble;
  late List<ProfileRow> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = [...widget.ground.profiles];
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.bench.profileId;
    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sentences.profiles, style: Zc.h2),
              const SizedBox(height: 6),
              Text(
                sentences.chooseWhichClientDictionary,
                style: Zc.small,
              ),
              const SizedBox(height: 16),
              _row(
                title: sentences.everywhere,
                subtitle:
                    sentences.onlyIdentitiesForEveryProfile,
                active: current == null,
                onSwitch: current == null ? null : () => _switch(null),
              ),
              for (final p in _profiles)
                _row(
                  title: p.name,
                  subtitle: p.id,
                  active: current == p.id,
                  onSwitch: current == p.id ? null : () => _switch(p.id),
                  onRename: () => _rename(p),
                ),
              const SizedBox(height: 12),
              ZButton(
                label: sentences.createProfile,
                icon: Icons.add,
                onPressed: _create,
              ),
              if (_trouble != null) ...[
                const SizedBox(height: 12),
                Trouble(_trouble!),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  const Spacer(),
                  ZButton(
                    label: sentences.done,
                    filled: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row({
    required String title,
    required String subtitle,
    required bool active,
    required VoidCallback? onSwitch,
    VoidCallback? onRename,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: Zc.panel(
        fill: active ? Zc.clayWash : Zc.card,
        edge: active ? Zc.clayEdge : Zc.lineSoft,
        radius: 9,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Zc.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
                ),
              ],
            ),
          ),
          if (onRename != null) ...[
            ZButton(label: sentences.rename, onPressed: onRename),
            const SizedBox(width: 8),
          ],
          ZButton(
            label: active ? sentences.profileActive : sentences.profileSwitch,
            filled: !active,
            onPressed: onSwitch,
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final made = await showDialog<ProfileRow>(
      context: context,
      builder: (_) => ProfileForm(ground: widget.ground, session: widget.bench.session),
    );
    if (!mounted || made == null) return;
    setState(() {
      _profiles = [..._profiles.where((p) => p.id != made.id), made];
      _trouble = null;
    });
    await widget.ground.refresh();
    final bad = await widget.bench.switchProfile(made.id);
    if (!mounted) return;
    setState(() => _trouble = bad);
  }

  Future<void> _rename(ProfileRow profile) async {
    final renamed = await showDialog<ProfileRow>(
      context: context,
      builder: (_) => ProfileForm(profile: profile, ground: widget.ground),
    );
    if (!mounted || renamed == null) return;
    setState(() {
      _profiles = [for (final p in _profiles) p.id == renamed.id ? renamed : p];
      _trouble = null;
    });
    await widget.ground.refresh();
    await widget.bench.refresh();
    if (mounted) setState(() => _trouble = null);
  }

  Future<void> _switch(String? profileId) async {
    final bad = await widget.bench.switchProfile(profileId);
    if (!mounted) return;
    setState(() => _trouble = bad);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.tint, this.onTap, this.hint});

  final String label;
  final String value;
  final Color? tint;

  /// A fact that can be acted on — the vault since 041-N, which is the way in
  /// and so is never absent from the bar.
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final fact = Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Eyebrow(label),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: tint ?? Zc.ink2,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return fact;
    return Tooltip(
      message: hint ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: fact,
      ),
    );
  }
}

/// «Scanned on import — 7 protected automatically · 2 need your word · 428 normal».
/// Every one of those numbers is `ScanReport`, straight from the core.
/// **What a returning document carries** — 079, the import side.
///
/// Nothing at all for an ordinary document: `tokens == 0` is the core's own
/// answer to «is this a returning document», so this widget asks one number and
/// draws nothing rather than a line that says zero.
///
/// The sentence is `whatCameBack` in `messages.dart`, which is the one place
/// the app turns the core's numbers into language — and the names that stay
/// tokens are the owner's cost said out loud, in the lead's words.
class _CameBack extends StatelessWidget {
  const _CameBack({required this.bench});

  final Workbench bench;

  @override
  Widget build(BuildContext context) {
    final seen = bench.returned;
    if (seen == null) return const SizedBox.shrink();
    final said = whatCameBack(seen);
    if (said == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(
        color: Zc.riverWash,
        border: Border(bottom: BorderSide(color: Zc.clayEdge)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.undo, size: 15, color: Zc.river),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              said,
              style: const TextStyle(fontSize: 13, color: Zc.river),
            ),
          ),
          // **A press, not a side effect** — the lead's own rule for this door.
          // The reading exists either way; opening it is a person's act, and
          // nothing is protected, written or learned by looking.
          //
          // Offered only when there is something to read back: with nothing
          // brought back the strip has already said everything there is.
          if (seen.broughtBack > 0) ...[
            const SizedBox(width: 12),
            ZButton(
              label: sentences.readItBack,
              onPressed: () => showDialog<void>(
                context: context,
                // **The document's own name travels, for the save dialog's
                // suggestion only** — paper 108 item 4. Through this door the
                // reading is of the document on the bench, so its name is what
                // a «…-restored.pdf» stands beside in a folder. It is drawn
                // nowhere and written into nothing.
                builder: (_) => TheReading(seen: seen, cameFrom: bench.document?.name),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.bench, required this.onVault});

  final Workbench bench;

  /// The way to the vault from the band's own line. The line said «No vault»
  /// and could not be pressed: the owner read it, agreed with it, and had
  /// nowhere to go.
  final VoidCallback onVault;

  @override
  Widget build(BuildContext context) {
    // **Every line of this band comes from the snapshot** — 14 October, item 3.
    //
    // It read `bench.report`, which is what a *scan call* returned, and a
    // document that was scanned on the way in has never made one: the band
    // would have said «Not scanned yet» over a document whose every name was
    // already protected. The snapshot carries all of it — which scan it was,
    // the counts, and the vault's own state.
    // **And the request is read the moment it is typed** — paper 102 §4.
    //
    // `scanOrigin` is the **document's**: `mark_scanned` sets it in the scan
    // door and at the import doors. A bench with no document therefore kept it
    // at `notScanned` for ever, and this band said «Not scanned yet» beside a
    // Safe column that was showing tokens — over a request `set_question` had
    // just read with the same packs, the same vault and the same lists a
    // document is read with («1 values were replaced» is that reading saying
    // so). A badge that reads one fact and reports another is the shape this
    // band was rebuilt for in the first place.
    //
    // So: with nothing above it, what was read is the request, and the band
    // says that instead of the document's silence.
    final noDocument = (bench.document?.text ?? '').isEmpty;
    final theRequestWasRead = noDocument && bench.question.trim().isNotEmpty;
    final scanned = bench.scanOrigin != ScanOrigin.notScanned || theRequestWasRead;
    // **A document that came back from a kept copy, told apart from one this
    // run scanned** — the owner's three zeros of 18 October.
    //
    // Asked of the two facts the snapshot has, because it has no third: a
    // restored document is the one state where there are **marks and no
    // findings at all**, and a scan that found nothing leaves no marks. The
    // honest means would be one flag from the core — this is an inference, and
    // it is written down as one; it is sound today and the day the core says
    // it, this reads that instead.
    final marksOnIt = bench.document?.marks.length ?? 0;
    final asKept = bench.snap != null && bench.findings.isEmpty && marksOnIt > 0;
    final vault = bench.snap?.vault ?? VaultState.absent;
    final locked = vault != VaultState.unlocked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
      decoration: const BoxDecoration(
        color: Zc.clayWash,
        border: Border(bottom: BorderSide(color: Zc.clayEdge)),
      ),
      child: Row(
        children: [
          if (bench.busy) ...[
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Zc.clayDeep,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              sentences.scanning,
              style: TextStyle(fontSize: 13, color: Zc.clayDeep),
            ),
          ] else if (!scanned) ...[
            Text(
              sentences.notScannedYet,
              style: TextStyle(fontSize: 13, color: Zc.clayDeep),
            ),
          ] else ...[
            const Icon(Icons.check, size: 15, color: Zc.clayDeep),
            const SizedBox(width: 8),
            Text(
              // A scan nobody asked for says why it happened, rather than
              // calling itself manual.
              //
              // **And a document that came back from a kept copy says that
              // instead** — the owner's screenshot of 18 October: «Scanned on
              // import · 0 protected automatically · 0 need your word · 0
              // normal» over a document whose first column showed seventeen
              // names underlined.
              //
              // The cause is in two lines of the core, and only one of them was
              // meant: `put_back_the_preview` clears the findings and re-applies
              // the kept marks (`session.rs`), and the three counts are counted
              // **from the findings** (`snapshots.rs`) — so they are all zero
              // for a restored document, while the marks it came back with are
              // drawn beside them. The same function sets the origin to
              // `OnImport` on purpose, with its own reason: «not scanned yet»
              // over a document full of marks would contradict the column
              // beside it. True of where the marks came from — and it turned
              // the three zeros into a sentence that reads as a measurement.
              //
              // So this says what is true: the document is as it was kept, and
              // the number is the one the core has — the marks that came back
              // with it. Re-scanning it to fill the three counts would be a
              // second opinion about protections that came from the vault,
              // which 089 rule 9 exists to avoid.
              // The request's own reading comes first when there is nothing
              // above it: every other case here is a sentence about a
              // document, and this surface has none.
              theRequestWasRead
                  ? sentences.scannedAsYouTyped
                  : asKept
                      ? sentences.asItWasKept
                      : bench.scanNote != null
                          ? sentences.lastScanNote(bench.scanNote!)
                          : switch (bench.scanOrigin) {
                              ScanOrigin.onImport => sentences.scannedOnImport,
                              ScanOrigin.rescan => sentences.lastScanManualRescan,
                              ScanOrigin.notScanned => sentences.notScannedYet,
                            },
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Zc.clayDeep,
              ),
            ),
            // **And the three counts are the document's, so they are drawn
            // where there is one** — paper 102 §4. They are counted from the
            // scan's findings, which a request has none of: over a
            // documentless bench this line read «0 protected automatically ·
            // 0 need your word · 0 normal» beside a request whose tokens were
            // on the glass. What the request replaced is said under the box
            // the person typed it in, by the one sentence that counts the
            // request's own marks — so this is one false line removed and no
            // true one hidden.
            if (!noDocument) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  asKept
                      ? sentences.alreadyProtectedNothingScanned(marksOnIt)
                      : sentences.protectedAutomaticallyNeedYourWord(
                          bench.snap?.autoProtected ?? 0,
                          bench.openSuggestions,
                          bench.normalCount,
                        ),
                  style: const TextStyle(fontSize: 13, color: Zc.clayDeep),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
          // **No `Spacer` here** (14 October, item 3). A spacer is a third
          // flexible child, and it took a third of the band's free width for
          // emptiness — so the warning's share was 174 pixels, the act inside
          // it needs more than that on its own, and the band overflowed by 15
          // pixels in a 1000-pixel window. Measured by `paste_test`, which
          // draws this band with no vault: the warning was invisible until
          // then, because it was drawn only when a *scan call* had returned.
          //
          // The counts take one share and the warning two, which keeps the
          // warning against the right edge without a child whose only job is
          // to be wide.
          const SizedBox(width: 12),
          // Said out loud, because a locked vault means the app cannot recognise
          // your own people. The core puts the state in the report for this line.
          //
          // Flexible, not a bare Text: this band is the one place where two long
          // sentences meet, and a narrow window must shorten a warning rather
          // than overflow it off the screen where nobody reads it.
          if (locked && scanned)
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: InkWell(
                  onTap: onVault,
                  borderRadius: BorderRadius.circular(7),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            vault == VaultState.locked
                                ? sentences.vaultLockedRulesAndPackRan
                                : sentences.noVaultNothingRecognisedByName,
                            style: Zc.small.copyWith(
                              color: Zc.amber,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // The act, in the band, where the fact is. «Create» and
                        // «Unlock» are different moves and the line knows which
                        // one this is — the same distinction the core's two
                        // refusals make.
                        Text(
                          vault == VaultState.locked
                              ? sentences.unlock
                              : sentences.createAVault,
                          style: Zc.small.copyWith(
                            color: Zc.clayDeep,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two columns.
class _Columns extends StatefulWidget {
  const _Columns({
    required this.bench,
    required this.ground,
    required this.said,
    required this.onSay,
    required this.focusKey,
    required this.onChoose,
    required this.onWalk,
    required this.onGoToSpan,
    required this.lookingAt,
    this.onSettings,
    this.onRemoveDocument,
  });

  final Workbench bench;
  final Ground ground;
  final String? said;
  final void Function(String) onSay;
  final GlobalKey focusKey;
  final void Function(Mark mark, Offset at) onChoose;

  /// Review, and then Next — the walk, which is the screen's because it moves
  /// both columns and draws the word's buttons over them.
  final VoidCallback onWalk;

  /// Going to a span — the search bar's fourth act, through the same one
  /// function the walk uses (083, ruling 14).
  final Future<void> Function(Span where) onGoToSpan;

  /// **Where the window is looking**, so the Original column can wash it and
  /// drop its anchor there. Null means «nowhere in particular», and then the
  /// focused finding is what is lit, exactly as before 084.
  final Span? lookingAt;

  /// Handed down to the Safe column's footer, which opens the send sheet —
  /// and the sheet carries the only door to where a provider's key is given.
  final VoidCallback? onSettings;

  /// Rule 73: «Remove the document», in the first part, beside the acts that
  /// are about the document.
  final VoidCallback? onRemoveDocument;

  @override
  State<_Columns> createState() => _ColumnsState();
}

/// **The handle between the two columns.**
///
/// The owner, 6 October: «the ability to change the size of the two screens,
/// the text screen and the result screen». Dragged with the mouse, and neither
/// side may fall below [_floor] — the whole claim of this product is that a
/// person can compare the two sides, and a column that has been dragged shut
/// cannot be compared with anything.
///
/// Where it was left is a per-device preference and lives in `settings.zcfg`
/// beside the first-run flag: the Workspace is drawn long before any vault
/// exists, so the vault is the one place it could not live.
class _ColumnsState extends State<_Columns> {
  static const double _floor = 280;

  /// The Original column, for the test that drags the handle.
  static const originalPane = ValueKey<String>('workspace-original-pane');

  /// The Safe column. Named for the same reason its neighbour is: a test that
  /// found these two by their position among every scrollable on the screen
  /// would pass or fail on the order of unrelated widgets.
  static const safePane = ValueKey<String>('workspace-safe-pane');

  /// The button that lets the columns go their own way, for the test.
  static const stepLock = ValueKey<String>('workspace-step-lock');

  /// What the file says, until a drag says otherwise. Null means «not yet read».
  double? _percent;
  bool _dragging = false;

  /// One controller each, so one column can be told where the other has gone.
  final _left = ScrollController();
  final _right = ScrollController();

  /// Null until a tap says otherwise, like `_percent`: the file's answer is
  /// the answer until this session's person gives another.
  bool? _inStep;

  /// Which column is being followed right now.
  ///
  /// Without this the two controllers chase each other: moving the right one
  /// fires its own listener, which moves the left, which moves the right. The
  /// column the hand is on leads until it stops.
  String? _leading;

  /// The width each column's text was laid out at, remembered from the build so
  /// the scroll listener can lay the same text out the same way. A different
  /// width would give different page positions, and the columns would step to
  /// the wrong place — quietly, which is worse.
  double _leftWidth = 0;
  double _rightWidth = 0;

  @override
  void initState() {
    super.initState();
    _left.addListener(() => _follow(from: 'left'));
    _right.addListener(() => _follow(from: 'right'));
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  bool get _stepping =>
      _inStep ?? widget.ground.config?.columnsInStep ?? true;

  /// Move the other column to the place that matches this one.
  void _follow({required String from}) {
    if (!_stepping) return;
    if (_leading != null && _leading != from) return;
    final doc = widget.bench.document;
    final safe = widget.bench.payload;
    if (doc == null || safe == null) return;
    final me = from == 'left' ? _left : _right;
    final other = from == 'left' ? _right : _left;
    if (!me.hasClients || !other.hasClients) return;

    _leading = from;
    final myText = from == 'left' ? doc.text : safe.text;
    final theirText = from == 'left' ? safe.text : doc.text;
    final myEdges = from == 'left' ? edgesOfDocument(doc.text) : safe.pageEdges;
    final theirEdges = from == 'left' ? safe.pageEdges : edgesOfDocument(doc.text);
    final myWidth = from == 'left' ? _leftWidth : _rightWidth;
    final theirWidth = from == 'left' ? _rightWidth : _leftWidth;

    final pairs = alignedEdges(
      myEdges: myEdges,
      myYs: pageEdgeYs(text: myText, style: Zc.document, width: myWidth, edges: myEdges),
      theirEdges: theirEdges,
      theirYs: pageEdgeYs(text: theirText, style: Zc.document, width: theirWidth, edges: theirEdges),
    );
    final target = inStepOffset(
      from: me.offset,
      mine: pairs.mine,
      theirs: pairs.theirs,
      myExtent: me.position.maxScrollExtent,
      theirExtent: other.position.maxScrollExtent,
    );
    if ((other.offset - target).abs() > 0.5) other.jumpTo(target);
    // Released on the next frame rather than here: `jumpTo` fires the other
    // controller's listener before this one returns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leading == from) _leading = null;
    });
  }

  /// **Collapse the Safe column, or bring it back — by a press and only by a
  /// press** (046/K).
  ///
  /// The owner's rule in one line: «الطوي والفتح لا يتم تلقائياً، يتم بالضغط
  /// على إشارة محددة». So nothing in this file closes this column when a panel
  /// opens, when the window narrows, when a document arrives or when a scan
  /// ends — and `the_states_change_only_by_a_press_test.dart` is that sentence
  /// as a test.
  ///
  /// Remembered in `zcfg`, like the step lock and the handle's position, for
  /// the reason the rule makes unavoidable: a state the app may not change by
  /// itself must survive the app closing, or closing it would change it.
  void _toggleSafe() {
    final config = widget.ground.config;
    if (config == null) return;
    unawaited(widget.ground.saveConfig(
      config.with_(safeColumnOpen: !config.safeColumnOpen),
    ));
  }

  /// Let them go their own way, or bring them back — and remember which.
  void _toggleStep() {
    final now = !_stepping;
    setState(() => _inStep = now);
    final config = widget.ground.config;
    if (config == null || config.columnsInStep == now) return;
    unawaited(widget.ground.saveConfig(config.with_(columnsInStep: now)));
    if (now) _follow(from: 'left');
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final ground = widget.ground;
    final doc = bench.document;
    // **096, rule 72-ب** — what the person entered, as one text. The first
    // part draws this; `doc` is still read for everything that is *about* a
    // document (the search bar, «Remove the document», the acts that need one).
    final entered = bench.entered;
    final safe = bench.payload;
    final kept = (ground.config?.originalPanePercent ?? 50).toDouble();
    final percent = _percent ?? kept;

    return LayoutBuilder(
      builder: (context, box) {
        // The handle is three pixels of grab and one of line. Below the floor
        // on either side it simply does not go: a column dragged shut is a
        // comparison nobody can make.
        const handle = 7.0;
        // The Safe column's own state, read from the person's settings and
        // never from what else is on screen (046/K).
        final safeOpen = ground.config?.safeColumnOpen ?? true;
        // Closed, the column becomes a rail that still carries its arrow: a
        // handle is what makes a collapse undoable, and a collapse with no
        // handle is a thing a person has lost.
        const rail = 26.0;
        final usable = box.maxWidth - (safeOpen ? handle : rail);
        final lowest = usable <= _floor * 2 ? usable / 2 : _floor;
        final left = safeOpen
            ? (usable * percent / 100).clamp(lowest, usable - lowest)
            // Closed, the Original has the whole of it. The person's own
            // `originalPanePercent` is untouched and is what the column
            // returns to.
            : usable;
        // `_Side` pads its scroll view by 18 on each side; the text is laid out
        // inside that. Kept here so the scroll listener measures the same
        // layout this build drew, never a guess at it.
        _leftWidth = left - 36;
        _rightWidth = usable - left - 36;

        return Row(
          children: [
            SizedBox(
              // Named, so a test can measure the column itself rather than
              // something inside it.
              key: _ColumnsState.originalPane,
              width: left,
              child: _Side(
                eyebrow: sentences.originalLocalOnly,
                rule: sentences.neverSentToAiSendCannotRead,
                tint: Zc.ink4,
                controller: _left,
                // The control sits here because this is the column a person
                // reads and scrolls: the complaint it answers was «I work on
                // the first screen and do not find my work on the second».
                trailing: safeOpen ? _StepLock(inStep: _stepping, onTap: _toggleStep) : null,
                // **The search bar** — 084. On the column a person reads,
                // because that is the text it searches: «the bar searches the
                // original column», so a protected name is still found by its
                // name and its token is shown beside it.
                banner: doc == null
                    ? null
                    : FindInDocument(
                        bench: bench,
                        onGoTo: widget.onGoToSpan,
                        onSay: widget.onSay,
                      ),
                // **The box is in the footer whether or not a document is
                // in** — rule 72, 18 October 2026: «صندوق المحادثة حاضر من
                // اللحظة الأولى، في الثلث الأول، بلا وثيقة». What the person
                // writes is what enters — a short question or a whole letter —
                // and with no document above it, it is the whole of what
                // leaves. Everything else in this footer is **about** a
                // document and is drawn only when there is one.
                footer: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // **What a selection of lines is worth, before any
                          // press** (046/Q). Above the acts, because it is the
                          // reason one of them is about to be worth pressing.
                          if (doc != null && bench.lines != null) _LineBand(bench: bench),
                          if (doc != null && widget.said != null) _Said(widget.said!),
                          // **The acts stay with no document**, and that is
                          // rule 72's doing rather than an oversight: a letter
                          // written in the box is protected like any text, so
                          // its tokens exist and «Tokens» is how a person sees
                          // them. The presses that need a selection are dead
                          // without one, as they always were — the bar does
                          // not pretend otherwise.
                          ActsBar(
                            bench: bench,
                            ground: ground,
                            onSay: widget.onSay,
                            onWalk: widget.onWalk,
                          ),
                          if (doc != null) ...[
                          // **«Remove the document»** — rule 73, in the first
                          // part, under the acts that are about the document
                          // and above the box that is not. It takes nothing
                          // out: no exit, no bubble, no question (54-و), and
                          // the kept copy stays in the session's list (54-ز)
                          // to be opened again. Drawn only with a document in,
                          // because with none there is nothing to remove.
                          if (widget.onRemoveDocument != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: ZButton(
                                  key: WorkspaceScreen.removeDocument,
                                  label: sentences.removeTheDocument,
                                  icon: Icons.close,
                                  onPressed:
                                      bench.busy ? null : widget.onRemoveDocument,
                                ),
                              ),
                            ),
                          // **What should the model do with this?** (046/N.)
                          //
                          // Under the document, where the person is reading
                          // it, because the question is about this document
                          // and nothing else. It is **not** in the send sheet:
                          // that sheet's own row of acts belongs to 046/O in
                          // another worktree, and two sessions editing one row
                          // is how a merge loses a line.
                          ],
                          _TheQuestion(bench: bench),
                        ],
                      ),
                // **The request is original text, like the document** — rule
                // 72-ب. One text from the core, one offset space, so the
                // marks, the hand selection, the question a tap asks and the
                // page arithmetic are the ones the document already had: a
                // word typed into the request is covered by the same hand
                // through the same doors. The `--- Request ---` line is in the
                // text the core built, so it is drawn by being there (rule
                // 64's line stays) and not by a second widget that would have
                // to agree with it.
                child: entered == null || entered.text.isEmpty
                    ? _Empty(sentences.nothingIsOpen)
                    : Builder(
                        builder: (inner) => OriginalText(
                          text: entered.text,
                          marks: entered.marks,
                          // **One slot for «where we are looking»**: it
                          // follows the focused finding, and the search bar can
                          // put a span in it that no finding covers.
                          focus: widget.lookingAt ?? bench.focusedFinding?.span,
                          focusKey: widget.focusKey,
                          onSelection: (start, end) => bench.select(
                            end > start ? Span(start: start, end: end) : null,
                          ),
                          // Tapping a protected word asks the question this
                          // whole layer exists to answer.
                          onAsk: (mark) => _ask(inner, bench, entered.text, mark,
                              column: _offerFor(bench, entered.text, mark)),
                          // And tapping one that is still waiting answers it.
                          onChoose: widget.onChoose,
                          // 046/Q — lines are taken in the gutter, words in
                          // the text, so neither gesture has to ask which one
                          // a press meant.
                          heldLines: bench.lines,
                          onLines: (from, to) => unawaited(bench.holdLines(from, to)),
                          onColumn: (offset) => unawaited(_column(bench, offset)),
                        ),
                      ),
              ),
            ),
            if (!safeOpen)
              _SafeRail(onTap: _toggleSafe)
            else
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() => _dragging = true),
                onHorizontalDragUpdate: (drag) {
                  final wanted = (left + drag.delta.dx).clamp(lowest, usable - lowest);
                  setState(() => _percent = wanted / usable * 100);
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _dragging = false);
                  // `_percent` and not the `percent` this build closed over:
                  // that one is where the handle **was** when the drag began,
                  // and writing it back remembers the wrong place. Measured by
                  // the test that drags twice.
                  _remember(_percent ?? percent);
                },
                child: SizedBox(
                  width: handle,
                  child: Center(
                    child: Container(
                      width: 1,
                      color: _dragging ? Zc.clay : Zc.line,
                    ),
                  ),
                ),
              ),
            ),
            if (safeOpen)
            Expanded(
              key: _ColumnsState.safePane,
              child: _Side(
                eyebrow: sentences.safeAiWillReceive,
                rule: sentences.theRequestItselfNotAPreview,
                tint: Zc.clay,
                trailing: _SafeTrailing(bench: bench, onClose: _toggleSafe),
                controller: _right,
                // **Only what leaves, and one drawing of it** — rule 35 and
                // 096, rule 72-ب.
                //
                // This had a second drawing under it: `questionSafe`, the
                // question's own protected form, drawn as a footer because on
                // 18 October a bench with a request and no document had no
                // payload and this column said «There is nothing to send
                // yet.» over a request that was about to leave. The core
                // answers that case itself now — `build_payload` sends
                // `WhatWouldLeave::TheQuestionAlone` to the one builder, so
                // the snapshot carries a payload for a request standing by
                // itself — and a second drawing of what leaves is a second
                // thing to keep true. The payload carries the request.
                footer: safe == null
                    ? null
                    : _SafeFooter(
                        payload: safe,
                        bench: bench,
                        ground: ground,
                        onSettings: widget.onSettings,
                      ),
                child: safe == null
                    ? _Empty(sentences.thereIsNothingToSendYet)
                    : SafeText(
                        text: safe.text,
                        edges: safe.pageEdges,
                        chips: bench.chips,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// **What the card may offer**, when the word it explains stands inside the
  /// held lines (046/Q).
  ///
  /// The lead's ruling, 7 October: a press on an already-protected cell asks
  /// its question **and** carries the instruction, because on the owner's own
  /// sheet the cell he presses may be the one his list already protected — and
  /// a press that can mean only one of the two loses his intent with no hint
  /// that the act was there.
  ///
  /// `null` when the word is outside the held lines, because the cell's order
  /// is read from **its own** line: offering the act for a word on another line
  /// would protect a column he never pointed at.
  ColumnOffer? _offerFor(Workbench bench, String entered, Mark mark) {
    final held = bench.lines;
    final hold = bench.linesHold;
    if (held == null || hold == null) return null;
    final lo = held.from < held.to ? held.from : held.to;
    final hi = held.from < held.to ? held.to : held.from;
    // The entered text and not the document: one offset space since 096, and
    // a line number counted in the other text would point at another row.
    final line = lineOfOffset(entered, mark.span.start);
    if (line < lo || line > hi) return null;
    return ColumnOffer(
      lines: hold.lines,
      act: () => _column(bench, mark.span.start),
    );
  }

  /// **One press, and the same cell is protected down every held line.**
  ///
  /// No dialog: the lead's ruling of 7 October, resting on the asymmetry L
  /// established — only an act that leaves values **in the clear** asks, and
  /// asks with the number in the sentence. Protecting is never a leak, so it
  /// may happen on one press.
  ///
  /// A press in the gap between two columns comes back as a refusal with its
  /// own name, and `Workbench` turns it into the sentence that says why the app
  /// cannot choose a column. Nothing is snapped to the nearest cell.
  Future<void> _column(Workbench bench, int offset) async {
    final outcome = await bench.protectColumnAt(offset);
    if (outcome == null) {
      // The core refused, and the refusal is already worded. Say it where the
      // acts say everything else, so a press that did nothing cannot look like
      // a press that was not noticed.
      final trouble = bench.trouble;
      if (trouble != null) widget.onSay(trouble);
      return;
    }
    // **A column is told about cells**, which is the one difference the fold of
    // 15 October kept: `ProtectAct.aCell` is why «protected one cell» is not
    // «protected», and why `places: 0` reads «every cell in that column was
    // already protected» here and nowhere else. 079 rule 5 included: the core
    // refuses per cell and answers this only when **no** cell was protected,
    // so «one cell of this column was a token» is still «protected N cells».
    widget.onSay(protectSaid(outcome, ProtectAct.aCell));
  }

  /// Where the handle was left, kept for the next time this document is open.
  ///
  /// Written through the core's settings, which is the only durable per-device
  /// store this app has and already holds the first-run flag. Nothing of the
  /// person's work goes with it: it is a number between 20 and 80, and the core
  /// clamps it again on the way in.
  void _remember(double percent) {
    final config = widget.ground.config;
    if (config == null) return;
    final rounded = percent.round().clamp(20, 80);
    if (rounded == config.originalPanePercent) return;
    unawaited(widget.ground.saveConfig(config.with_(originalPanePercent: rounded)));
  }
}

/// **«8 lines · 25 protected in them · 0 open»** — what a selection of lines
/// holds, said before anything is pressed (046/Q).
///
/// Not one of these three numbers is worked out here. They come back from
/// `line_selection` in Rust, because they are facts about findings, and a
/// screen that counted them would be a second source for a number the core
/// already holds — the two would disagree the first time a rescan moved one.
///
/// The way out of a selection is here rather than at the head of the gutter,
/// because this band is under the document and always on screen while the
/// gutter's head scrolls away. Nothing releases the lines on its own: an act
/// leaves them held, so the next column is one press away.
class _LineBand extends StatelessWidget {
  const _LineBand({required this.bench});

  final Workbench bench;

  static const band = ValueKey<String>('held-lines-band');

  @override
  Widget build(BuildContext context) {
    final hold = bench.linesHold;
    return Container(
      key: _LineBand.band,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(
        color: Zc.clayWash,
        border: Border(top: BorderSide(color: Zc.clayEdge)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Before the core has answered it says nothing rather than a
                  // zero, by the same rule `kindName` follows: a number that is
                  // not known yet is not «none».
                  hold == null
                      ? sentences.readingWhatThoseLinesHold
                      : hold.lines == 1
                            ? sentences.oneLineProtectedOpen(hold.protected, hold.open)
                            : sentences.linesProtectedOpen(
                                hold.lines, hold.protected, hold.open),
                  style: Zc.small.copyWith(color: Zc.clayDeep, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  sentences.pressAValueToProtectEveryHeldLine,
                  style: Zc.tiny.copyWith(letterSpacing: 0),
                ),
              ],
            ),
          ),
          ZButton(
            label: sentences.letTheLinesGo,
            icon: Icons.close,
            onPressed: bench.releaseLines,
          ),
        ],
      ),
    );
  }
}

/// What the last act did. In the core's words, with its numbers.
class _Said extends StatelessWidget {
  const _Said(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(top: BorderSide(color: Zc.lineSoft)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 15, color: Zc.clay),
          const SizedBox(width: 9),
          Expanded(
            child: Text(line, style: Zc.small.copyWith(color: Zc.ink2)),
          ),
        ],
      ),
    );
  }
}

/// «Why is this protected?» — asked of the core, drawn by the sheet, and if
/// something is forgotten the document is scanned again so the screen matches
/// what the app now knows.
Future<void> _ask(
  BuildContext context,
  Workbench bench,
  String entered,
  Mark mark, {
  ColumnOffer? column,
}) async {
  final why = await bench.why(mark.span);
  if (why == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => WhySheet(
      why: why,
      word: entered.substring(mark.span.start, mark.span.end),
      span: mark.span,
      onChanged: bench.rescan,
      // The two choices the owner allows, each through the one function 084
      // will call as well (083, ruling 3).
      onUnprotect: (span) async => unprotectHere(bench, span),
      onUnprotectEveryPlace: (span) async => unprotectInThisConversation(bench, span),
      column: column,
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.what);

  final String what;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        what,
        style: Zc.small.copyWith(color: Zc.ink4),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// Whether the two columns move together.
///
/// 041-L. It says what is true now, not what pressing it will do — the same
/// rule as every other state in this app: «In step» with the link closed, «Apart»
/// with it open. A person who wants to read one column on its own says so once,
/// and the answer is kept beside the handle's position.
class _StepLock extends StatelessWidget {
  const _StepLock({required this.inStep, required this.onTap});

  final bool inStep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        key: _ColumnsState.stepLock,
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                inStep ? Icons.link : Icons.link_off,
                size: 14,
                color: inStep ? Zc.clayDeep : Zc.ink4,
              ),
              const SizedBox(width: 5),
              Text(
                inStep ? sentences.inStep : sentences.apart,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: inStep ? Zc.clayDeep : Zc.ink4,
                ),
              ),
            ],
          ),
        ),
      );
}

/// «Chips / Plain». Both draw the same string; one of them draws it the way the
/// model will read it, character for character.
class _ChipSwitch extends StatelessWidget {
  const _ChipSwitch({required this.bench});

  final Workbench bench;

  @override
  Widget build(BuildContext context) {
    Widget one(String label, bool chips) {
      final on = bench.chips == chips;
      return InkWell(
        onTap: () => bench.showChips(chips),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: on ? Zc.clayWash : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: on ? Zc.clayEdge : Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: on ? Zc.clayDeep : Zc.ink4,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        one(sentences.drawnAsChips, true),
        const SizedBox(width: 4),
        one(sentences.drawnPlain, false),
      ],
    );
  }
}

/// The sentence under the Safe column. It is the one place the app admits that
/// an unanswered suggestion is **still the real text** — which is what G12 is
/// about, said in words where the consequence is visible.
/// **The foot of the Safe column: what would leave, and the way out.**
///
/// **The payload is an option since rule 72** (18 October 2026). A bench with
/// no document has none — the core builds one from a document, and
/// `build_the_question_alone` is what carries a question by itself — and yet
/// there **is** something to send: the question, protected. So the counts come
/// from whichever of the two is standing, and the door is the same door.
class _SafeFooter extends StatelessWidget {
  const _SafeFooter({
    required this.payload,
    required this.bench,
    required this.ground,
    this.onSettings,
  });

  final PayloadView? payload;
  final Workbench bench;
  final Ground ground;

  /// Handed on to the send sheet, which carries the only door to the place a
  /// provider's key is given. Null means there is no panel to open, and then
  /// the sheet draws no door.
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final view = payload;
    // With no document, nothing is waiting: a question is scanned as it is
    // set, and `set_question` refuses one that still has a word waiting.
    final open = view?.openSuggestions ?? 0;
    // How much was replaced in what would leave — the document's payload when
    // there is one, the question's own marks when the question is all there is.
    // Both are the core's count; neither is worked out here.
    final replaced = view?.protectedCount ?? bench.questionMarks.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 13),
      decoration: BoxDecoration(
        color: open > 0 ? Zc.amberWash : Zc.warmCard,
        border: const Border(top: BorderSide(color: Zc.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            open == 0
                ? exactlyWhatWouldLeave(replaced)
                : open == 1
                ? sentences.oneSuggestionStillOpen
                : sentences.suggestionsStillOpen(open),
            style: Zc.small.copyWith(
              color: open > 0 ? Zc.amber : Zc.ink3,
              fontWeight: open > 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          // Wrap: the hint beside a disabled button is a whole sentence, and a
          // narrow column must put it on the next line rather than off the edge.
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ZButton(
                // **The name of the act this press causes** — the owner's rule
                // of 29 September, applied again now that the act has changed.
                //
                // It was «Review what will leave», and that was honest while
                // the press opened a page showing the outgoing text. Rule 60
                // took that page away: what will leave is read **here**, in
                // the side this button stands in, and the press opens the
                // three doors. So the name says choosing, which is what the
                // sheet is now, and the reviewing is not promised by a button
                // because it is already on the glass.
                //
                // Still not «Send»: a person may take the manual path with
                // Copy Protected and never send at all, so «Send» would be a
                // promise we do not keep. And still not the bare «Review»,
                // which the left column already uses for the list of
                // suggestions.
                label: sentences.chooseWhoAnswers,
                filled: true,
                icon: Icons.fact_check_outlined,
                // Disabled while anything is open — and the reason is beside it,
                // because «send anyway» does not exist and never will.
                //
                // Through the same one hand as the top bar's door, although
                // this press comes from inside the preview side and could not
                // find it closed: two doors and one order, so that a reader
                // does not have to check which of them keeps the law.
                onPressed: open > 0
                    ? null
                    : () => unawaited(theWayToTheDoors(
                        context,
                        ground: ground,
                        bench: bench,
                        onSettings: onSettings,
                      )),
                hint: null,
              ),
              // **The way back to the chat, for a person who put it away** —
              // rule 65. It said «Show the answer» and showed one; the chat is
              // the thing to come back to now, and it is drawn only while
              // there is one and it is not already standing.
              if (bench.chatTurns.isNotEmpty && bench.panel != OpenPanel.chat)
                ZButton(
                  label: sentences.showTheChat,
                  icon: Icons.forum_outlined,
                  onPressed: bench.openTheChat,
                ),
            ],
          ),
          // **A gate that does not hand you the key is a wall** (046/L).
          //
          // The owner, 7 October: «في حال كانت ريفو تحتوي على أي خيار، لا يمكن
          // الانتقال إلى الخطوات التالية.» The door stays shut while a question
          // is open — that does not change and it is the one sentence this
          // product rests on. What changes is that the rule is now **answerable
          // in one press from where he stands**: the line says how many are
          // left and what the first one is, it takes him to it, and when there
          // is exactly one it carries the two answers itself.
          //
          // «Answer the review first» said none of that: it named no number, no
          // value and no way through.
          if (open > 0) ...[
            const SizedBox(height: 9),
            _TheWayThrough(bench: bench, ground: ground, open: open),
          ],
        ],
      ),
    );
  }
}

/// **The request that travels with the document** (046/N).
///
/// The owner, 7 October: «ليس لدينا شات — شات مع نموذج… لا يوجد خيار مثلاً
/// مباشرة إلى الشات.» A document used to reach the model with no request at
/// all, so whatever came back was its own guess at what was wanted.
///
/// Three things this widget does **not** do, and each is the point:
///
///   * it does not decide what is sensitive. `setQuestion` hands the sentence
///     to the core, which reads it with the same packs, the same vault and the
///     same lists the document was read with — and with what this document has
///     already protected, so a name that is a token in the sheet is the *same*
///     token here. A field that scanned itself would be a second scanner;
///   * it does not send. The question joins what leaves, and what leaves still
///     leaves through the review and the one gate;
///   * it does not promise a conversation. One question at a time replaces the
///     last, and the line under it says so rather than letting a person
///     discover it by losing something.
/// **The one box a person writes in** — rules 72 and 72-أ, 18 October 2026.
///
/// It was the request box under a document («What should the AI do with
/// this?», 046/N) and it is the only box on the screen now: the owner's «نعم»
/// of 18 October deleted the second one at the top. Three states, one widget:
///
///   * **a document above it** — what is typed is the addition under the
///     document (rule 64, the payload's `--- Request ---`);
///   * **a bench with no document** — what is typed is the whole of what
///     leaves, and ed's `build_the_question_alone` carries it;
///   * **no bench at all**, on an empty surface — the press hands the text to
///     the shell, which opens a session for it (and asks its language, rule
///     57b) and sets it there. That is the one case this box cannot do by
///     itself, because a question has to be protected *in* a session and
///     there is none yet.
class _TheQuestion extends StatefulWidget {
  const _TheQuestion({this.bench, this.onAsk});

  /// The bench, when there is one. Null on an empty surface — rule 72: the box
  /// is there from the first moment, with no document and no session.
  final Workbench? bench;

  /// The door for the no-bench case, handed down from the screen.
  final void Function(String text)? onAsk;

  static const field = ValueKey<String>('workspace-question');
  static const attach = ValueKey<String>('workspace-question-attach');

  @override
  State<_TheQuestion> createState() => _TheQuestionState();
}

class _TheQuestionState extends State<_TheQuestion> {
  late final TextEditingController _text =
      TextEditingController(text: widget.bench?.question ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final typed = _text.text.trim();
    final attached = bench?.question.trim() ?? '';
    // **The one press, and what it means depends on what is standing.** With a
    // bench it sets the question in that session; with none it hands the text
    // to the shell, which opens a session for it. The label is the same word
    // in both cases — nothing leaves at this press, in either.
    final press = typed.isEmpty || typed == attached || (bench?.busy ?? false)
        ? null
        : bench == null
            ? (widget.onAsk == null ? null : () => widget.onAsk!(typed))
            : () => unawaited(bench.setQuestion(typed));
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      color: Zc.warmCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **The question above the box says what the box is for**, and with
          // no document there is no «this» to point at — rule 72: with nothing
          // above it, what is written here is the whole of what leaves.
          Text(
            (bench?.document?.text ?? '').isEmpty
                ? sentences.whatWouldYouLikeToAskTheAi
                : sentences.whatShouldTheAiDoWithThis,
            style: Zc.tiny.copyWith(color: Zc.ink4),
          ),
          const SizedBox(height: 5),
          Container(
            decoration: Zc.panel(fill: Zc.card, radius: 9),
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
            child: TextField(
              key: _TheQuestion.field,
              controller: _text,
              minLines: 2,
              maxLines: 5,
              style: Zc.body,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: (bench?.document?.text ?? '').isEmpty
                    ? sentences.askAQuestionOrPasteALetter
                    : sentences.reconcileSectionAgainstSection,
                hintStyle: Zc.small.copyWith(color: Zc.ink4),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 9,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ZButton(
                key: _TheQuestion.attach,
                // The act's own name says what it does and where it goes
                // (P2-5). Not «Send»: nothing leaves until the review and the
                // gate are satisfied, and this press does neither.
                label: typed == attached && typed.isNotEmpty
                    ? sentences.inWhatWillLeave
                    : sentences.addItToWhatWillLeave,
                icon: Icons.help_outline,
                onPressed: press,
                hint: typed.isEmpty && attached.isEmpty
                    ? sentences.aDocumentCanBeSentWithNoRequest
                    : null,
              ),
              if (attached.isNotEmpty && bench != null)
                ZButton(
                  label: sentences.takeItOut,
                  onPressed: bench.busy
                      ? null
                      : () {
                          _text.clear();
                          unawaited(bench.setQuestion(''));
                        },
                ),
            ],
          ),
          if (attached.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              // Measured facts, both of them the core's: how many words of the
              // question were replaced, and that the Safe column is where it
              // can be read before anything is pressed.
              (bench?.questionMarks ?? const []).isEmpty
                  ? sentences.yourRequestNothingToProtect
                  : bench!.questionMarks.length == 1
                      ? sentences.yourRequestOneValueReplaced
                      : sentences.yourRequestValuesReplaced(
                          bench.questionMarks.length),
              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.clayDeep),
            ),
            const SizedBox(height: 3),
            // **Two sentences, because two different things are in play**
            // (046/N, the lead's wording and the distinction my own report
            // turned up): the **request** is replaced, and the **answers** are
            // kept. A line saying only «the second question replaces this» is
            // true of the request and misleading about what a person can still
            // see.
            Text(
              // **Rewritten by rule 67**, which made its second half the
              // smaller truth: the answers were «kept», and what they are now
              // is a conversation that carries itself forward. The first half
              // stands and is still the thing a person needs to know before
              // they type: this box holds one request, and the next question
              // replaces it.
              sentences.oneRequestAtATime,
              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
            ),
            // **And the sentence that stood here is gone, because the debt was
            // paid** — rule 67, 17 October.
            //
            // It said «Each question is asked on its own: the model does not
            // see the earlier ones», and it was honest for as long as
            // `history` was `const []`. The core now carries the turns of the
            // open chat with every later question, so the line became a lie
            // the moment that landed and went with it. Deleted, not reworded:
            // what the chat does is drawn in the chat itself.
            //
            // `the_question_is_on_the_screen_test.dart` measures that it is
            // not here, which is how a line removed in one round stays
            // removed.
          ],
        ],
      ),
    );
  }
}

/// **The one question, answerable from here** (046/L).
///
/// Three things, and the third is the owner's own case: how many are left, the
/// way to the first of them, and — when exactly one is open — the two answers
/// on this line so he never has to go looking. On his own sheet, with his list
/// imported, that is the real case: 61 findings and one open question, an
/// address.
///
/// No fourth button that sends anyway. The gate is not loosened; it is handed
/// its key.
class _TheWayThrough extends StatelessWidget {
  const _TheWayThrough({required this.bench, required this.ground, required this.open});

  final Workbench bench;
  final Ground ground;
  final int open;

  static const goKey = ValueKey<String>('workspace-go-to-question');
  static const protectKey = ValueKey<String>('workspace-one-protect');
  static const leaveKey = ValueKey<String>('workspace-one-leave');

  @override
  Widget build(BuildContext context) {
    final waiting = bench.suggested;
    final first = waiting.isEmpty ? null : waiting.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ZButton(
              key: goKey,
              // The number is in the name of the act, not in a line under it
              // (P2-5). «1 question left — go to it» is a different sentence
              // from «Answer the review first», and it is the one a person can
              // act on.
              label: open == 1
                  ? sentences.oneQuestionLeftGoToIt
                  : sentences.questionsLeftGoToTheFirst(open),
              icon: Icons.east,
              onPressed: first == null
                  ? null
                  : () {
                      bench.openReview(walk: true);
                      bench.focusOn(first.id);
                    },
            ),
            // **And when there is only one, it is answerable right here.**
            if (open == 1 && first != null) ...[
              ZButton(
                key: protectKey,
                label: sentences.protectIt,
                icon: Icons.shield_outlined,
                onPressed: bench.busy
                    ? null
                    : () => unawaited(bench.answer(first.id, FindingAnswer.protect)),
              ),
              ZButton(
                key: leaveKey,
                label: sentences.leaveItInTheClear,
                onPressed: bench.busy
                    ? null
                    : () => unawaited(bench.answer(first.id, FindingAnswer.notSensitive)),
              ),
            ],
          ],
        ),
        if (open == 1 && first != null) ...[
          const SizedBox(height: 6),
          // What it is, so the two answers above are about something. The kind
          // is the core's own word for it.
          Text(
            sentences.theOneLeftIsKind(
                ground.nameOfKind(first.kind).toLowerCase()),
            style: Zc.tiny.copyWith(letterSpacing: 0),
          ),
        ],
      ],
    );
  }
}

/// **The Safe column, collapsed to a rail that still carries its arrow.**
///
/// 046/K. The rail exists for one reason and it is the owner's: a person who
/// closed something must be able to open it again, and the only thing that can
/// promise that is a control still on the screen.
class _SafeRail extends StatelessWidget {
  const _SafeRail({required this.onTap});

  final VoidCallback onTap;

  static const named = ValueKey<String>('workspace-safe-rail');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      decoration: const BoxDecoration(
        color: Zc.warmCard,
        border: Border(left: BorderSide(color: Zc.line)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          IconButton(
            key: named,
            tooltip: sentences.showWhatTheAiWillReceive,
            icon: const Icon(Icons.chevron_left, size: 18),
            color: Zc.clay,
            visualDensity: VisualDensity.compact,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// The Safe column's own two controls: the chip switch it has always had, and
/// the arrow that closes the column (046/K).
class _SafeTrailing extends StatelessWidget {
  const _SafeTrailing({required this.bench, required this.onClose});

  final Workbench bench;
  final VoidCallback onClose;

  static const closeKey = ValueKey<String>('workspace-safe-close');

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipSwitch(bench: bench),
        IconButton(
          key: closeKey,
          tooltip: sentences.hideThisColumn,
          icon: const Icon(Icons.chevron_right, size: 18),
          color: Zc.ink3,
          visualDensity: VisualDensity.compact,
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// **An arrow, and what it does said in its own tooltip.**
///
/// The owner's standing rule of 7 October: «بشرط أن الطوي والفتح لا يتم
/// تلقائياً، يتم بالضغط على إشارة محددة» — a collapse or an expand is always a
/// person's press on a visible control. So this is a control, it says which way
/// it goes, and it is **always drawn while a panel is open**: a collapsed thing
/// that leaves no handle is a thing a person has lost.
class _PanelArrow extends StatelessWidget {
  const _PanelArrow({required this.wide, required this.onTap});

  final bool wide;
  final VoidCallback onTap;

  /// Named, so a test presses the control a person presses.
  static const named = ValueKey<String>('workspace-panel-arrow');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      child: Column(
        children: [
          const SizedBox(height: 12),
          IconButton(
            key: named,
            // P2-5: the name of the act carries what it does.
            tooltip: wide ? sentences.narrowThisPanel : sentences.widenThisPanel,
            icon: Icon(wide ? Icons.chevron_right : Icons.chevron_left, size: 18),
            color: Zc.ink3,
            visualDensity: VisualDensity.compact,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Half the window, in the middle of what is left — or the whole of it.
///
/// One widget rather than a conditional tree, so the case where no panel is
/// open is provably the case that existed before 046/K: `centred: false`
/// returns the child untouched.
class _Middle extends StatelessWidget {
  const _Middle({required this.centred, required this.width, required this.child});

  final bool centred;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!centred) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.eyebrow,
    required this.rule,
    required this.tint,
    required this.child,
    this.controller,
    this.trailing,
    this.footer,
    this.banner,
  });

  final String eyebrow;
  final String rule;
  final Color tint;
  final Widget child;

  /// **In plain sight, above the text and outside the scroller** — 084's bar
  /// (ruling 1). It stays where the eye goes first while the document scrolls
  /// under it, which is the whole of «not hidden behind a key or a menu».
  final Widget? banner;

  /// Given from outside so the two columns can be kept in step (041-L).
  final ScrollController? controller;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(eyebrow, color: tint),
                    const SizedBox(height: 4),
                    Text(rule, style: Zc.tiny.copyWith(letterSpacing: 0)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        Container(height: 1, color: Zc.lineSoft),
        ?banner,
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: child,
          ),
        ),
        // **The footer gives, and nothing is pushed off the screen.**
        //
        // It used to sit here at its natural height after an `Expanded`, so the
        // moment it grew by a line the column overran — measured at exactly
        // **1 pixel** when 046/N added the request field under the document,
        // which is the same family as the three overflows of 2 October and the
        // 58 of 046/K: a row or a column with no give, breaking on the next
        // string somebody adds.
        //
        // `Flexible` so it takes what it needs up to what is left, and a
        // scroller inside it so a short window scrolls the acts rather than
        // hiding them. The reason a person needs is never the thing that falls
        // off the edge.
        if (footer != null)
          Flexible(
            child: SingleChildScrollView(child: footer),
          ),
      ],
    );
  }
}

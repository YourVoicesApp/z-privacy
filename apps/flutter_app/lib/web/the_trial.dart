// **Z on the web, for trying it** — paper 122 part B, rules 85 and 86.
//
// The first screen of the trial is Z's chat, as the app draws it: the
// original on one side, what an AI would receive on the other, the answer
// brought back by a paste. What is not here, on purpose: the vault,
// conversations, kept documents, the settings rooms, z-pdf, the user's lists
// and profiles (§1.8).
//
// **The protection runs in the visitor's browser** (rule 85 (a)): every mark,
// token and restored word is the core's, through `TheWebCore`, and nothing of
// the text goes to any server — the page is served with `connect-src 'self'`
// and the core has no network code at all.
//
// **Leaving the page keeps nothing** (rule 85 (c)): the session lives in this
// state and in the core's memory, and nothing here touches any storage.
//
// **Two lines are always on the glass**, above everything that scrolls: the
// one small line to today's front page (§6, the owner's ruling of 12 Nov) and
// the notice band (rule 85 (d)).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/the_clipboard.dart';
import 'package:zprivacy/core/the_way_text_reads.dart';
import 'package:zprivacy/core/theme.dart';
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/web/the_page.dart' as page;
import 'package:zprivacy/web/the_trial_pdf.dart';
import 'package:zprivacy/web/the_web_core.dart';
import 'package:zprivacy/widgets/plain_bits.dart';
import 'package:zprivacy/widgets/the_chat_turn.dart';

/// The interface languages of the trial: the app's six (`language_list.dart`).
const trialLanguages = ['en', 'ar', 'de', 'fr', 'es', 'sv'];

/// **The language follows the page's address** (§1.8): `/en/…`, `/ar/…`,
/// `/sv/…`. Anything else is English, the list's source.
String theLanguageOfTheAddress(Uri address) {
  for (final segment in address.pathSegments) {
    if (segment.isEmpty) continue;
    return trialLanguages.contains(segment) ? segment : 'en';
  }
  return 'en';
}

/// **Where the two links go** — our own pages, on our own origin. The front
/// page as it is today (§6) and its download page. The site has no Swedish
/// pages yet (rule 86 (e), a paper of its own), so Swedish goes to English.
String theFrontPage(String language) =>
    Uri(pathSegments: ['', _siteLanguage(language), '']).path;
String theDownloadPage(String language) =>
    Uri(pathSegments: ['', _siteLanguage(language), 'download', '']).path;
String _siteLanguage(String language) => language == 'sv' ? 'en' : language;

/// The providers as the app lists them — the core's own labels, in its order
/// (`z_core/src/providers/mod.rs`, `known()`); a guard reads that file. Drawn
/// so the visitor sees what the app can do; none of them works here (85 (g)).
const theProvidersTheAppKnows = [
  'OpenAI-compatible',
  'Anthropic',
  'xAI (Grok)',
  'DeepSeek',
  'Moonshot (Kimi)',
  'Google (Gemini)',
];

/// The trial's own font: the app's DejaVu Sans, bundled, so the browser
/// fetches no font from anywhere but our origin (Latin, Arabic, Swedish).
const trialFont = 'dejavu_sans';

ThemeData theTrialTheme() {
  final base = zTheme();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: trialFont),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: trialFont),
  );
}

/// The web root: the trial and nothing else.
class TrialApp extends StatelessWidget {
  const TrialApp({
    super.key,
    required this.language,
    required this.doors,
    this.font,
    this.onThePdf,
  });

  final String language;

  /// The core's module, loaded once (`the_web_doors.dart` in a browser, a
  /// fake in a test).
  final Future<WebDoors> Function() doors;

  /// The PDF's font; read from the bundle when not given.
  final Future<ByteData> Function()? font;

  /// Handed the PDF's bytes when they are built — for a test to read the very
  /// file «Save to my device» offers. The page itself passes nothing.
  final ValueChanged<Uint8List>? onThePdf;

  @override
  Widget build(BuildContext context) {
    final locale = Locale(language);
    theSentencesAreNow(locale);
    return MaterialApp(
      title: 'Z Privacy',
      debugShowCheckedModeBanner: false,
      theme: theTrialTheme(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TheTrial(
        language: language,
        doors: doors,
        font: font ?? theTrialFont,
        onThePdf: onThePdf,
      ),
    );
  }
}

class TheTrial extends StatefulWidget {
  const TheTrial({
    super.key,
    required this.language,
    required this.doors,
    required this.font,
    this.onThePdf,
  });

  final String language;
  final Future<WebDoors> Function() doors;
  final Future<ByteData> Function() font;
  final ValueChanged<Uint8List>? onThePdf;

  static const about = ValueKey<String>('trial-about');
  static const notice = ValueKey<String>('trial-notice');
  static const pack = ValueKey<String>('trial-pack');
  static const ai = ValueKey<String>('trial-ai');
  static const providers = ValueKey<String>('trial-providers');
  static const note = ValueKey<String>('trial-note');
  static const original = ValueKey<String>('trial-original');
  static const protect = ValueKey<String>('trial-protect');
  static const unprotect = ValueKey<String>('trial-unprotect');
  static const protectIt = ValueKey<String>('trial-protect-it');
  static const leaveIt = ValueKey<String>('trial-leave-it');
  static const safe = ValueKey<String>('trial-safe');
  static const copyProtected = ValueKey<String>('trial-copy-protected');
  static const answer = ValueKey<String>('trial-answer');
  static const restore = ValueKey<String>('trial-restore');
  static const document = ValueKey<String>('trial-document');
  static const copyDocument = ValueKey<String>('trial-document-copy');
  static const save = ValueKey<String>('trial-document-save');
  static const yours = ValueKey<String>('trial-document-yours');

  // Paper 123: the chat, and «Start over».
  static const chat = ValueKey<String>('trial-chat');
  static const compose = ValueKey<String>('trial-compose');
  static const startOver = ValueKey<String>('trial-start-over');
  static const startOverQuestion = ValueKey<String>(
    'trial-start-over-question',
  );
  static const erase = ValueKey<String>('trial-erase');
  static const cancelStartOver = ValueKey<String>('trial-start-over-cancel');

  @override
  State<TheTrial> createState() => _TheTrialState();
}

class _TheTrialState extends State<TheTrial> {
  TheWebCore? _core;
  bool _failed = false;
  late String _pack = webPacks.contains(widget.language)
      ? widget.language
      : 'en';

  final _MarkedController _text = _MarkedController();
  final TextEditingController _answer = TextEditingController();
  Timer? _reading;
  WebView _view = WebView.empty;

  /// What the protected side shows: the text that would leave, or why not.
  String? _safe;
  String? _safeWhyNot;

  /// The exchanges of the open chat, from the core's `z_turns`, and their
  /// document (paper 123: the chat, rules 65–68 and 87 (أ)). The page keeps no
  /// copy of a turn of its own: the document's words are the core's restored
  /// forms — the first turn's question is the visitor's text as written.
  final List<_Exchange> _done = [];

  Uint8List? _pdf;

  /// The chat is open once the first answer is in: the original is then read
  /// only, and the next question is written in the compose box.
  bool get _chatOpen => _done.isNotEmpty;

  /// The next question, with the core's marks over it, and its text as typed
  /// when it left — for the document, which holds the visitor's own words.
  final _MarkedController _question = _MarkedController();
  Timer? _asking;

  /// Whether the clipboard's last text is Z's own copy, so «Start over» empties
  /// it (87 (د)). The page never reads the clipboard to find out: a browser
  /// would ask the visitor's permission for that.
  bool _ourCopyIsOnTheClipboard = false;

  String? _note;
  bool _noteIsTheApp = false;
  bool _providersOpen = false;

  @override
  void initState() {
    super.initState();
    // The acts under the original follow the caret and the selection.
    _text.addListener(_moved);
    _question.addListener(_moved);
    unawaited(_start());
  }

  void _moved() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    try {
      final doors = await widget.doors();
      final core = TheWebCore(doors)..open(_pack);
      if (!mounted) return;
      setState(() {
        _core = core;
        _readTheSafeSide();
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _reading?.cancel();
    _asking?.cancel();
    _text.removeListener(_moved);
    _question.removeListener(_moved);
    _text.dispose();
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ the acts

  void _said(String? note, {bool theApp = false}) => setState(() {
    _note = note;
    _noteIsTheApp = theApp;
  });

  /// Every refusal by its name, in a sentence the app already has.
  String _refusal(WebRefusal r) {
    final count = (r.detail['count'] as num?)?.toInt() ?? 0;
    return switch (r.name) {
      'open_suggestions' =>
        count == 1 ? sentences.oneWordWaits : sentences.wordsWait(count),
      'invalid_session' => sentences.troubleInvalidSession,
      'invalid_handle' => sentences.troubleInvalidHandle,
      'stale_payload' => sentences.troubleStalePayload,
      'bad_span' => sentences.troubleBadSpan,
      'unknown_token' => sentences.troubleUnknownToken,
      'nothing_to_send' => sentences.troubleNothingToSend,
      'no_payload' => sentences.copyTheSafeTextFirst,
      _ => sentences.unnamedTrouble,
    };
  }

  void _act(void Function(TheWebCore core) act) {
    final core = _core;
    if (core == null) return;
    try {
      act(core);
    } on WebRefusal catch (r) {
      _said(_refusal(r));
    }
  }

  void _show(WebView view) {
    _view = view;
    _text.view = view;
    if (_text.text != view.text) {
      final at = _text.selection;
      _text.value = TextEditingValue(
        text: view.text,
        selection: at.isValid && at.end <= view.text.length
            ? at
            : TextSelection.collapsed(offset: view.text.length),
      );
    }
    _readTheSafeSide();
  }

  /// The protected side, from the core: the text that would leave, or the
  /// reason it may not (open suggestions, nothing yet).
  void _readTheSafeSide() {
    final core = _core;
    if (core == null) return;
    if (_chatOpen) return _readTheQuestionToTakeOut(core);
    if (_view.text.trim().isEmpty) {
      _safe = null;
      _safeWhyNot = sentences.thereIsNothingToSendYet;
      return;
    }
    final open = _view.suggestions;
    if (open > 0) {
      _safe = null;
      _safeWhyNot = open == 1
          ? sentences.oneSuggestionStillOpenSend
          : sentences.suggestionsStillOpenSend(open);
      return;
    }
    try {
      _safe = core.takeOut().text;
      _safeWhyNot = null;
    } on WebRefusal catch (r) {
      _safe = null;
      _safeWhyNot = _refusal(r);
    }
  }

  /// With the chat open, the protected side is the chat as it would leave:
  /// every earlier turn, protected, and the new question (rule 65).
  void _readTheQuestionToTakeOut(TheWebCore core) {
    if (_question.text.trim().isEmpty) {
      _safe = null;
      _safeWhyNot = sentences.thereIsNothingToSendYet;
      return;
    }
    // A question never holds a suggestion: the core's question scan (046/N)
    // protects every value it finds at once. An open suggestion can only be
    // the document's, and the core's refusal says so by name below.
    try {
      _safe = core.questionToTakeOut().text;
      _safeWhyNot = null;
    } on WebRefusal catch (r) {
      _safe = null;
      _safeWhyNot = _refusal(r);
    }
  }

  /// The next question, scanned and protected by the core as the original is
  /// (`z_set_question`): a name already protected is the same token here.
  void _askedSomethingElse(String _) {
    _asking?.cancel();
    _asking = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _act(
        (core) => setState(() {
          _note = null;
          _showTheQuestion(core.setQuestion(_question.text).view);
        }),
      );
    });
  }

  void _showTheQuestion(WebView view) {
    _question.view = view;
    _readTheSafeSide();
  }

  void _written(String _) {
    _reading?.cancel();
    _reading = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _act(
        (core) => setState(() {
          _note = null;
          _show(core.importText(_text.text));
        }),
      );
    });
  }

  void _choosePack(String? pack) {
    if (pack == null || pack == _pack) return;
    _act(
      (core) => setState(() {
        _pack = pack;
        core.open(pack);
        _note = null;
        _show(_text.text.isEmpty ? WebView.empty : core.importText(_text.text));
      }),
    );
  }

  WebMark? get _markHere {
    final at = _text.selection;
    if (!at.isValid) return null;
    return _view.markAt(at.isCollapsed ? at.baseOffset : at.start);
  }

  void _protectTheSelection() {
    final at = _text.selection;
    if (!at.isValid || at.isCollapsed) return;
    // A hand selection settles every place of the value in the conversation
    // (083c); its kind is the person's own, `custom`.
    _act(
      (core) => setState(() {
        _note = null;
        _show(
          core
              .protect(
                at.start,
                at.end,
                kind: 'custom',
                scope: WebScope.conversation,
              )
              .view,
        );
      }),
    );
  }

  void _unprotect(WebMark m) => _act(
    (core) => setState(() {
      _note = null;
      _show(core.unprotect(m.start, m.end));
    }),
  );

  void _answerTheSuggestion(WebMark m, {required bool protect}) => _act(
    (core) => setState(() {
      _note = null;
      _show(core.answerFinding(m, protect: protect));
    }),
  );

  /// «Copy Protected»: the clipboard emptied first (081), then only the text
  /// the core says may leave.
  ///
  /// **The first line asks the model to keep the codes** (87 (ج)): the same
  /// line on every turn, in the page's language, holding no value and no
  /// token. It is put on the clipboard only — never shown on the protected
  /// side as the visitor's own text.
  Future<void> _copyProtected() async {
    final t = AppLocalizations.of(context);
    await emptyTheClipboardFirst();
    _ourCopyIsOnTheClipboard = false;
    final core = _core;
    if (core == null) return;
    try {
      final out = _chatOpen ? core.questionToTakeOut() : core.takeOut();
      await Clipboard.setData(
        ClipboardData(text: '${t.trialKeepTheCodes}\n\n${out.text}'),
      );
      _ourCopyIsOnTheClipboard = true;
      _said(sentences.theChatIsOnYourClipboard);
    } on WebRefusal catch (r) {
      _said(andTheClipboardIsEmpty(_refusal(r)));
    }
  }

  /// The answer pasted into the one answer box, whatever turn it belongs to:
  /// restored against what was copied last, and the chat grows by one turn.
  Future<void> _restore() async {
    final pasted = _answer.text;
    if (pasted.trim().isEmpty) return _said(sentences.nothingWasPasted);
    final core = _core;
    if (core == null) return;
    final List<WebTurn> turns;
    try {
      core.restore(pasted);
      turns = core.turns();
    } on WebRefusal catch (r) {
      return _said(_refusal(r));
    }
    // The document is on the glass at once; its PDF follows, and «Save to
    // my device» waits for it. A PDF that cannot be built takes nothing from
    // what the visitor reads.
    setState(() {
      _note = null;
      _done
        ..clear()
        ..addAll([for (final turn in turns) _Exchange(turn)]);
      _pdf = null;
      _answer.clear();
      _question.clear();
      _question.view = WebView.empty;
      _readTheSafeSide();
    });
    await _buildThePdf();
  }

  Future<void> _buildThePdf() async {
    final t = lookupAppLocalizations(Locale(widget.language));
    final count = _done.length;
    try {
      final pdf = await buildTheTrialPdf(
        yourText: _done.first.turn.question.text,
        exchanges: [
          for (var i = 0; i < _done.length; i++)
            (
              i == 0 ? null : _done[i].turn.question.text,
              _done[i].turn.answer.text,
            ),
        ],
        t: t,
        pageIsRightToLeft:
            theWayALanguageIsRead(widget.language) == TextDirection.rtl,
        font: await widget.font(),
      );
      if (mounted && _done.length == count) {
        setState(() => _pdf = pdf);
        widget.onThePdf?.call(pdf);
      }
    } on Object {
      if (mounted) _said(sentences.unnamedTrouble);
    }
  }

  /// The document as text: the same parts, in the same order, as its PDF.
  String _theDocumentAsText(AppLocalizations t) {
    final out = StringBuffer(
      '${t.trialYourText}\n\n${_done.first.turn.question.text}',
    );
    for (var i = 0; i < _done.length; i++) {
      final turn = _done[i].turn;
      if (i > 0) {
        out.write(
          '\n\n${t.trialQuestionNumber(i + 1)}\n\n${turn.question.text}',
        );
      }
      out.write('\n\n${t.trialTheAnswerWithRealNames}\n\n${turn.answer.text}');
    }
    return out.toString();
  }

  Future<void> _copyTheDocument() async {
    final t = AppLocalizations.of(context);
    await emptyTheClipboardFirst();
    _ourCopyIsOnTheClipboard = false;
    if (_done.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _theDocumentAsText(t)));
    _ourCopyIsOnTheClipboard = true;
  }

  /// **«Start over»** (87 (د)). With a document on the page it asks once;
  /// with none it erases at once.
  Future<void> _startOver() async {
    if (_done.isNotEmpty) {
      final t = AppLocalizations.of(context);
      final erase = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: TheTrial.startOverQuestion,
          backgroundColor: Zc.paper,
          content: Text(t.trialStartOverQuestion, style: Zc.body),
          actions: [
            TextButton(
              key: TheTrial.cancelStartOver,
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(sentences.cancel),
            ),
            FilledButton(
              key: TheTrial.erase,
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Zc.clay),
              child: Text(t.trialErase),
            ),
          ],
        ),
      );
      if (erase != true || !mounted) return;
    }
    await _erase();
  }

  /// Everything on the page goes, and the core's session with it: the
  /// clipboard first, when Z's own copy is the last thing on it; then
  /// `z_close` and a new session with the same pack. The page's language and
  /// the pack stay; the next text gets new tokens.
  Future<void> _erase() async {
    if (_ourCopyIsOnTheClipboard) {
      await emptyTheClipboardFirst();
      _ourCopyIsOnTheClipboard = false;
    }
    _reading?.cancel();
    _asking?.cancel();
    final core = _core;
    if (core == null || !mounted) return;
    try {
      core.startOver(_pack);
    } on WebRefusal catch (r) {
      return _said(_refusal(r));
    }
    setState(() {
      _done.clear();
      _pdf = null;
      _note = null;
      _providersOpen = false;
      _view = WebView.empty;
      _text.view = WebView.empty;
      _text.clear();
      _question.view = WebView.empty;
      _question.clear();
      _answer.clear();
      _readTheSafeSide();
    });
  }

  void _save() {
    final pdf = _pdf;
    if (pdf != null) page.saveToTheDevice(pdf, 'z-trial.pdf');
  }

  void _theAppIsNeeded() => _said(sentences.trialKeysNeedTheApp, theApp: true);

  // ------------------------------------------------------------ the glass

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Zc.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _aboutLine(t),
            _noticeBand(t),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: box.maxWidth < 600 ? 14 : 28,
                    vertical: 16,
                  ),
                  child: _failed
                      ? Text(sentences.unnamedTrouble, style: Zc.body)
                      : _core == null
                      ? const SizedBox(
                          height: 2,
                          child: LinearProgressIndicator(color: Zc.clay),
                        )
                      : _work(t, wide: box.maxWidth >= 900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutLine(AppLocalizations t) => Container(
    color: Zc.card,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    alignment: AlignmentDirectional.centerStart,
    child: InkWell(
      key: TheTrial.about,
      onTap: () => page.goTo(theFrontPage(widget.language)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          t.trialAboutZ,
          style: Zc.small.copyWith(
            color: Zc.river,
            decoration: TextDecoration.underline,
            decorationColor: Zc.river,
          ),
        ),
      ),
    ),
  );

  Widget _noticeBand(AppLocalizations t) => Material(
    color: Zc.amberWash,
    child: InkWell(
      key: TheTrial.notice,
      onTap: () => page.goTo(theDownloadPage(widget.language)),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Zc.amberEdge)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Zc.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.trialNotice,
                style: Zc.small.copyWith(color: Zc.amber),
              ),
            ),
            const Icon(Icons.download_outlined, size: 18, color: Zc.amber),
          ],
        ),
      ),
    ),
  );

  Widget _work(AppLocalizations t, {required bool wide}) {
    final original = _originalSide(t);
    final safe = _safeSide(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(t),
        if (_providersOpen) ...[const SizedBox(height: 10), _providers(t)],
        if (_note != null) ...[const SizedBox(height: 10), _noteLine()],
        const SizedBox(height: 14),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: original),
                const SizedBox(width: 16),
                Expanded(child: safe),
              ],
            ),
          )
        else ...[
          original,
          const SizedBox(height: 14),
          safe,
        ],
        const SizedBox(height: 16),
        _answerSide(t),
        if (_chatOpen) ...[const SizedBox(height: 16), _theChat(t)],
        if (_chatOpen) ...[const SizedBox(height: 18), _document(t)],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _head(AppLocalizations t) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 18,
    runSpacing: 10,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/brand/zprivacy-64.png',
              width: 30,
              height: 30,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Z Privacy', style: Zc.h2),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.packLabel.toUpperCase(), style: Zc.label),
          const SizedBox(width: 8),
          DropdownButton<String>(
            key: TheTrial.pack,
            value: _pack,
            underline: const SizedBox.shrink(),
            style: Zc.body.copyWith(color: Zc.river, fontFamily: trialFont),
            items: [
              for (final p in webPacks)
                DropdownMenuItem(
                  value: p,
                  child: Text(aLanguageInItsOwnWords(p)),
                ),
            ],
            onChanged: _choosePack,
          ),
        ],
      ),
      // **«Start over»** at the top of the trial (87 (د)).
      OutlinedButton.icon(
        key: TheTrial.startOver,
        onPressed: _core == null ? null : () => unawaited(_startOver()),
        icon: const Icon(Icons.restart_alt, size: 18),
        label: Text(t.trialStartOver),
      ),
      TextButton.icon(
        key: TheTrial.ai,
        onPressed: () => setState(() => _providersOpen = !_providersOpen),
        icon: const Icon(Icons.auto_awesome_outlined, size: 18, color: Zc.clay),
        label: Text(t.roomAi, style: Zc.body.copyWith(color: Zc.clay)),
      ),
    ],
  );

  /// **The providers and keys, drawn as in the app and none of them working**
  /// (rule 85 (g)): a press on a row or on its key field says at once that the
  /// app is needed. No field here takes a key — there is no text field at all.
  Widget _providers(AppLocalizations t) => Container(
    key: TheTrial.providers,
    decoration: Zc.panel(),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.whoAnswers, style: Zc.h2),
        const SizedBox(height: 8),
        for (final name in theProvidersTheAppKnows)
          InkWell(
            key: ValueKey<String>('trial-provider-$name'),
            onTap: _theAppIsNeeded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name, style: Zc.body.copyWith(color: Zc.ink)),
                  ),
                  Container(
                    key: ValueKey<String>('trial-key-$name'),
                    width: 180,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: Zc.panel(fill: Zc.warmCard, radius: 8),
                    child: Text(
                      t.apiKeyLabel,
                      style: Zc.small.copyWith(color: Zc.ink4),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _noteLine() {
    final line = Text(
      _note!,
      style: Zc.small.copyWith(color: _noteIsTheApp ? Zc.clayDeep : Zc.ink2),
    );
    return Container(
      key: TheTrial.note,
      decoration: Zc.panel(fill: Zc.clayWash, edge: Zc.clayEdge, radius: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _noteIsTheApp
          ? InkWell(
              onTap: () => page.goTo(theDownloadPage(widget.language)),
              child: Row(
                children: [
                  Expanded(child: line),
                  const Icon(
                    Icons.download_outlined,
                    size: 18,
                    color: Zc.clayDeep,
                  ),
                ],
              ),
            )
          : line,
    );
  }

  Widget _side({
    required String title,
    required Widget child,
    required Color fill,
  }) => Container(
    decoration: Zc.panel(fill: fill),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title.toUpperCase(), style: Zc.label),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _originalSide(AppLocalizations t) {
    final here = _markHere;
    final selected = _text.selection.isValid && !_text.selection.isCollapsed;
    return _side(
      title: t.originalLocalOnly,
      fill: Zc.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: TheTrial.original,
            controller: _text,
            // Once the chat is open the original is what the chat is about;
            // the next words go into the compose box, and «Start over» begins
            // a new text.
            readOnly: _chatOpen,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textDirection: theWayTheTextReads(_text.text),
            style: Zc.document.copyWith(fontFamily: trialFont),
            decoration: InputDecoration(
              hintText: sentences.askAQuestionOrPasteALetter,
              hintStyle: Zc.body.copyWith(color: Zc.ink4),
              border: InputBorder.none,
            ),
            onChanged: _written,
            onTap: () => setState(() {}),
          ),
          // The original's acts stand until the chat opens: from then on it
          // is the text the chat is about, and it does not change under it.
          if (!_chatOpen) const SizedBox(height: 10),
          if (!_chatOpen)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: TheTrial.protect,
                  onPressed: selected && here == null
                      ? _protectTheSelection
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: Zc.clay),
                  child: Text(t.protectAct),
                ),
                if (here != null && here.protected)
                  OutlinedButton.icon(
                    key: TheTrial.unprotect,
                    onPressed: () => _unprotect(here),
                    icon: const Icon(Icons.undo, size: 16),
                    label: Text(t.undoProtection),
                  ),
                if (here != null && here.suggested) ...[
                  OutlinedButton.icon(
                    key: TheTrial.protectIt,
                    onPressed: () => _answerTheSuggestion(here, protect: true),
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: Text(t.protectIt),
                  ),
                  OutlinedButton(
                    key: TheTrial.leaveIt,
                    onPressed: () => _answerTheSuggestion(here, protect: false),
                    child: Text(t.leaveItInTheClear),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _safeSide(AppLocalizations t) => _side(
    title: t.safeAiWillReceive,
    fill: Zc.warmCard,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: _safe != null
              ? SelectableText(
                  _safe!,
                  key: TheTrial.safe,
                  textDirection: theWayTheTextReads(_safe!),
                  style: Zc.document.copyWith(fontFamily: trialFont),
                )
              : Text(_safeWhyNot ?? '', key: TheTrial.safe, style: Zc.small),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            key: TheTrial.copyProtected,
            onPressed: _safe == null ? null : _copyProtected,
            style: FilledButton.styleFrom(backgroundColor: Zc.clay),
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: Text(t.copyProtected),
          ),
        ),
      ],
    ),
  );

  Widget _answerSide(AppLocalizations t) => _side(
    title: t.addAnAnswer,
    fill: Zc.card,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: TheTrial.answer,
          controller: _answer,
          minLines: 4,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: Zc.document.copyWith(fontFamily: trialFont),
          decoration: InputDecoration(
            hintText: t.pasteTheAnswerYouWereGiven,
            hintStyle: Zc.body.copyWith(color: Zc.ink4),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            key: TheTrial.restore,
            onPressed: _restore,
            style: FilledButton.styleFrom(backgroundColor: Zc.river),
            child: Text(t.addAnAnswer),
          ),
        ),
      ],
    ),
  );

  /// **The chat** (rule 87 (أ), rules 65–68), under the answer box: the
  /// thread, each answer coded with one «Show the text», drawn by the app's
  /// own turn widget (`the_chat_turn.dart`) — and the box for the next
  /// question. «Copy Protected» above then copies the chat with its history,
  /// and the next answer goes into the same answer box.
  Widget _theChat(AppLocalizations t) {
    return Container(
      key: TheTrial.chat,
      decoration: Zc.panel(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Eyebrow(sentences.theChatTitle),
          const SizedBox(height: 12),
          for (var i = 0; i < _done.length; i++) ...[
            ChatTurnView(
              turn: _done[i].shown,
              at: i,
              open: _openTurn == i,
              onShow: () =>
                  setState(() => _openTurn = _openTurn == i ? null : i),
              onSaid: (line) => _said(line),
              coded: _coded,
            ),
            const SizedBox(height: 14),
          ],
          Container(
            decoration: Zc.panel(fill: Zc.warmCard, radius: 9),
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
            child: TextField(
              key: TheTrial.compose,
              controller: _question,
              minLines: 1,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textDirection: theWayTheTextReads(_question.text),
              style: Zc.document.copyWith(
                fontFamily: trialFont,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: sentences.askSomethingElseAboutThis,
                hintStyle: Zc.body.copyWith(color: Zc.ink4),
              ),
              onChanged: _askedSomethingElse,
            ),
          ),
        ],
      ),
    );
  }

  /// Which answer's restored text is open — rule 66: coded unless asked.
  int? _openTurn;

  /// A coded side, tokens drawn as tokens. The app's Safe-column painter reads
  /// the core's page edges through its bridge, which the web has none of; this
  /// draws the same characters with the token style, in the trial's font.
  static Widget _coded(String text) => Text.rich(
    TextSpan(
      children: [
        for (final (piece, isToken) in _tokensIn(text))
          TextSpan(
            text: piece,
            style: isToken
                ? const TextStyle(color: Zc.clayDeep, fontSize: 13)
                : null,
          ),
      ],
    ),
    textDirection: theWayTheTextReads(text),
    style: Zc.document.copyWith(fontSize: 13.5),
  );

  static List<(String, bool)> _tokensIn(String text) {
    final out = <(String, bool)>[];
    var at = 0;
    for (final m in RegExp(r'__Z_[A-Z0-9_]+__').allMatches(text)) {
      if (m.start > at) out.add((text.substring(at, m.start), false));
      out.add((m.group(0)!, true));
      at = m.end;
    }
    if (at < text.length) out.add((text.substring(at), false));
    return out;
  }

  /// **The document, inside the page** (rule 85 (b), paper 123 §3.4): the
  /// visitor's text as written, then each answer restored — and before every
  /// answer after the first, its question as the visitor wrote it — the same
  /// parts, in the same order, as the PDF behind «Save to my device».
  Widget _document(AppLocalizations t) {
    final asked = _done.first.turn.question.text;
    return Container(
      key: TheTrial.document,
      decoration: BoxDecoration(
        color: Zc.card,
        border: Border.all(color: Zc.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.trialYourText, style: Zc.h2),
          const SizedBox(height: 8),
          Text(
            asked,
            textDirection: theWayTheTextReads(asked),
            style: Zc.document,
          ),
          for (var i = 0; i < _done.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 18),
              Text(t.trialQuestionNumber(i + 1), style: Zc.h2),
              const SizedBox(height: 8),
              Text(
                _done[i].turn.question.text,
                textDirection: theWayTheTextReads(_done[i].turn.question.text),
                style: Zc.document,
              ),
            ],
            const SizedBox(height: 18),
            Text(t.trialTheAnswerWithRealNames, style: Zc.h2),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  for (final p in _done[i].turn.answer.pieces)
                    TextSpan(
                      text: p.text,
                      style: switch (p.piece) {
                        'restored' => const TextStyle(
                          color: Zc.river,
                          fontWeight: FontWeight.w600,
                        ),
                        'unresolved' => const TextStyle(
                          color: Zc.amber,
                          backgroundColor: Zc.amberWash,
                        ),
                        _ => null,
                      },
                    ),
                ],
              ),
              textDirection: theWayTheTextReads(_done[i].turn.answer.text),
              style: Zc.document,
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              OutlinedButton.icon(
                key: TheTrial.copyDocument,
                onPressed: _copyTheDocument,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: Text(t.trialCopy),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    key: TheTrial.save,
                    onPressed: _pdf == null ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: Zc.clay),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: Text(t.trialSaveToMyDevice),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.trialYourCopyIsYours,
                    key: TheTrial.yours,
                    style: Zc.small,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The original, with the core's marks drawn on it: protected in clay,
/// a suggestion in amber — the app's two hands.
class _MarkedController extends TextEditingController {
  WebView view = WebView.empty;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (view.marks.isEmpty ||
        view.text != text ||
        (withComposing && value.composing.isValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final marks = [...view.marks]..sort((a, b) => a.start.compareTo(b.start));
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in marks) {
      if (m.start < at || m.end > text.length) continue;
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: m.protected
              ? const TextStyle(
                  color: Zc.clayDeep,
                  backgroundColor: Zc.clayWash,
                  decoration: TextDecoration.underline,
                  decorationColor: Zc.clay,
                )
              : const TextStyle(
                  color: Zc.amber,
                  backgroundColor: Zc.amberWash,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: Zc.amberEdge,
                ),
        ),
      );
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

/// One exchange of the trial's chat: the core's turn — the question as it
/// left and the answer as it arrived, and both restored.
class _Exchange {
  _Exchange(this.turn);

  final WebTurn turn;

  ChatTurnShown get shown => ChatTurnShown(
    questionAsItLeft: turn.questionAsItLeft,
    who: sentences.answeredByHand,
    answerAsWritten: turn.answerAsWritten,
    unresolved: turn.unresolved,
    answer: [
      for (final p in turn.answer.pieces)
        (
          p.text,
          switch (p.piece) {
            'restored' => ChatPiece.restored,
            'unresolved' => ChatPiece.unresolved,
            _ => ChatPiece.words,
          },
        ),
    ],
  );
}

// **The search bar** — 084, and the owner's own words of 14 Oct: «وجدت ما كان
// ينقصنا في كل هذه العملية… شريط بحث في الوثيقة. هذا يحل الإشكال الأكبر.»
//
// Until now a person had to *find* a name by hand before Z could do anything
// with it. This is the bar: type a word, see how many places it stands in and
// what each one is, and act on them — protect, un-protect here, un-protect in
// this conversation, go to the word.
//
// **Everything on it reads one list** — `findInDocument`, the core's own
// `occurrences` with what covers each place — so the count, the colours and
// the four acts cannot come to disagree. A place's state is the state of what
// **covers** it, which is the reading that corrected the paper: one
// «Lindqvist» can be inside a protected «Anna Lindqvist», inside a waiting
// «Lindqvist AB», and alone in the clear, in one document.
//
// **The colours are the box's, never the text's** (ruling 8, and the owner's
// correction to the lead: «الكلمة الحمراء في مستطيل البحث، وفي النص الكلمة
// تبقى كما هي. لا نغيّر في إعدادات النص»). Watery red for protected, watery
// blue for found-and-still-waiting; in the clear wears neither, because it is
// the absence of both. The document's own marks are untouched by this file.
//
// **Nothing typed is ever stored.** The word lives in a `TextEditingController`
// for as long as the bar is on screen, the refusals live in this `State`, and
// `settings.zcfg` cannot hold a search history by construction (G18a).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/completing.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/protecting.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/un_protecting.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

class FindInDocument extends StatefulWidget {
  const FindInDocument({
    super.key,
    required this.bench,
    required this.onGoTo,
    required this.onSay,
  });

  final Workbench bench;

  /// Going to a place is the **screen's**: it moves both columns and lights the
  /// span (083, ruling 14). The bar says which place; it does no moving itself.
  final Future<void> Function(Span where) onGoTo;

  /// What an act did, said where the acts are.
  final void Function(String) onSay;

  static const field = ValueKey<String>('find-field');
  static const protectKey = ValueKey<String>('find-protect');
  static const hereKey = ValueKey<String>('find-unprotect-here');
  static const everyKey = ValueKey<String>('find-unprotect-every');
  static const goKey = ValueKey<String>('find-go');

  @override
  State<FindInDocument> createState() => _FindInDocumentState();
}

class _FindInDocumentState extends State<FindInDocument> {
  final _typed = TextEditingController();
  final _focus = FocusNode();

  /// The words of the open document, by the glass's own word law — built when
  /// the document changes and not per keystroke.
  List<String> _words = const [];
  String? _builtFor;

  /// **What has been shown and typed past.** The owner: a refused word does not
  /// come back. They last until the bar is emptied.
  final _refused = <String>{};
  String? _offered;

  /// The result, and **which place the walk is standing on** — `-1` before the
  /// first press, because «Go to it» has not happened yet. Null places mean
  /// «nothing searched», which is not the same as «nothing found».
  ///
  /// It says where the walk **is**, not where it will go next: the two acts
  /// beside it — un-protect here, and in this conversation — are about the
  /// place a person is looking at, and a guard found this reading by standing
  /// on a waiting place and being offered nothing.
  List<FoundPlace>? _places;
  String _searched = '';
  int _at = -1;
  bool _busy = false;

  @override
  void dispose() {
    _typed.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _wordsOfTheDocument() {
    final doc = widget.bench.document;
    final mark = doc == null ? null : '${doc.name}:${doc.text.length}';
    if (mark == _builtFor) return;
    _builtFor = mark;
    _words = doc == null ? const [] : theWordsOf(doc.text);
  }

  void _typing(String now) {
    setState(() {
      if (now.trim().isEmpty) {
        // **An empty bar starts fresh** — the refusals go with it.
        _refused.clear();
        _offered = null;
        _places = null;
        return;
      }
      // **Typing on refuses what was shown** (ruling 7). Only on a letter
      // added: erasing back offers the next word that fits and has not been
      // refused, which is the owner's own way out.
      final grew = now.length > _searchedLength;
      if (grew && _offered != null) _refused.add(_offered!);
      _searchedLength = now.length;
      _offered = theWordOffered(_words, now, _refused);
    });
  }

  int _searchedLength = 0;

  void _takeTheOffer() {
    final offer = _offered;
    if (offer == null) return;
    setState(() {
      _typed.text = offer;
      _typed.selection = TextSelection.collapsed(offset: offer.length);
      _searchedLength = offer.length;
      // Taken, not refused: the faint text goes because the word is now the
      // typed word, and a word is not its own completion.
      _offered = null;
    });
  }

  Future<void> _search() async {
    final word = _typed.text.trim();
    if (word.isEmpty) return;
    setState(() => _busy = true);
    try {
      final places = await z.findInDocument(session: widget.bench.session, word: word);
      if (!mounted) return;
      setState(() {
        _places = places;
        _searched = word;
        _at = -1;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _places = const []);
      widget.onSay(sentences.theSearchWasRefused('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _again() async {
    if (_places == null) return;
    await _search();
  }

  FoundPlace? get _here {
    final places = _places;
    if (places == null || places.isEmpty || _at < 0) return null;
    return places[_at.clamp(0, places.length - 1)];
  }

  Future<void> _go() async {
    final places = _places;
    if (places == null || places.isEmpty) return;
    // The next one, coming round at the end as the review's walk does.
    final next = (_at + 1) % places.length;
    await widget.onGoTo(places[next].span);
    if (!mounted) return;
    setState(() => _at = next);
  }

  Future<void> _act(Future<void> Function() act) async {
    setState(() => _busy = true);
    await act();
    await _again();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    _wordsOfTheDocument();
    final places = _places;
    final here = _here;
    final protected = places?.where((p) => p.state == FoundState.protected).length ?? 0;
    final waiting = places?.where((p) => p.state == FoundState.waiting).length ?? 0;
    final clear = places?.where((p) => p.state == FoundState.clear).length ?? 0;
    // The suggestions that are **wider than the typed word**: what «Protect»
    // will not touch, said out loud (ruling (c)).
    final wider = <String>{
      for (final p in places ?? const <FoundPlace>[])
        if (p.state == FoundState.waiting && _widerThanTyped(p)) _textOf(p.coveredBy!),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(
        color: Zc.riverWash,
        border: Border(bottom: BorderSide(color: Zc.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // **The bar itself, in plain sight and blue** (ruling 1).
                    // `Shortcuts` first, because Tab is a focus key everywhere
                    // else in this window and here it takes the completion.
                    CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.tab): _takeTheOffer,
                      },
                      child: TextField(
                        key: FindInDocument.field,
                        controller: _typed,
                        focusNode: _focus,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Zc.paper,
                          prefixIcon: const Icon(Icons.search, size: 17, color: Zc.river),
                          hintText: sentences.findAWordInThisDocument,
                          hintStyle: Zc.small.copyWith(color: Zc.ink4),
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: const BorderSide(color: Zc.river),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: const BorderSide(color: Zc.river),
                          ),
                        ),
                        onChanged: _typing,
                        onSubmitted: (_) => unawaited(_search()),
                      ),
                    ),
                    // **The completion, faint and under the word** (ruling 5).
                    // Tab takes it; typing on refuses it.
                    if (_offered != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 3),
                        // Two texts and a gap, not a run of spaces inside one
                        // literal: G25 reads such a run as a sentence somebody
                        // wrapped by accident, and it is right to — a gap
                        // belongs to the layout.
                        child: Row(
                          children: [
                            Text(
                              _offered!,
                              style: Zc.small.copyWith(color: Zc.ink4),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              sentences.tabTakesIt,
                              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ZButton(
                label: sentences.findAct,
                filled: true,
                onPressed: _busy ? null : () => unawaited(_search()),
              ),
            ],
          ),
          if (places != null) ...[
            const SizedBox(height: 9),
            // **One result line** — the word, how many places, and what each
            // one is. The two colours are here, in the box.
            Wrap(
              spacing: 7,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  places.isEmpty
                      // The word they searched for, isolated: the count after
                      // it is ours and must stay after it.
                      ? sentences.notInThisDocument(theirOwnWord(_searched))
                      : '«${theirOwnWord(_searched)}» — ${places.length} '
                            '${places.length == 1 ? "place" : "places"}:',
                  style: Zc.small.copyWith(fontWeight: FontWeight.w600),
                ),
                if (protected > 0) _Count(sentences.countProtected(protected), Zc.clay, Zc.clayWash),
                if (waiting > 0) _Count(sentences.countWaiting(waiting), Zc.river, Zc.riverWash),
                if (clear > 0) _Count(sentences.countInTheClear(clear), Zc.ink3, null),
              ],
            ),
            if (wider.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                // Ruling (c), said where the act is: Protect will not answer
                // these, because they are more than what was typed.
                sentences.placesInsideWaitingWords(wider.length, wider.join(' · ')),
                style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink3),
              ),
            ],
            if (places.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  ZButton(
                    key: FindInDocument.goKey,
                    label: _at < 0 ? sentences.goToIt : sentences.nextOfWaitingCount(_at + 1, places.length),
                    icon: Icons.east,
                    onPressed: _busy ? null : () => unawaited(_go()),
                  ),
                  if (clear > 0)
                    ZButton(
                      key: FindInDocument.protectKey,
                      label: sentences.protectAct,
                      filled: true,
                      badge: clear,
                      onPressed: _busy
                          ? null
                          : () => unawaited(_act(() async {
                                // **Only the places in the clear** — ruling
                                // (c). The waiting ones are more than what was
                                // typed, and the review is where they are
                                // answered.
                                final outcome = await protectThePlacesInTheClear(
                                  widget.bench,
                                  [
                                    for (final p in places)
                                      if (p.state == FoundState.clear) p.span,
                                  ],
                                );
                                if (outcome != null) {
                                  widget.onSay(protectSaid(outcome, ProtectAct.aPlaceTheBarFound));
                                }
                              })),
                    ),
                  if (here != null && here.state == FoundState.protected) ...[
                    ZButton(
                      key: FindInDocument.hereKey,
                      label: sentences.unProtectHere,
                      onPressed: _busy
                          ? null
                          : () => unawaited(_act(() async {
                                await unprotectHere(widget.bench, here.span);
                              })),
                    ),
                    if (protected > 1)
                      ZButton(
                        key: FindInDocument.everyKey,
                        label: sentences.unProtectInThisSession(protected),
                        onPressed: _busy
                            ? null
                            : () => unawaited(_act(() async {
                                  await unprotectInThisConversation(widget.bench, here.span);
                                })),
                      ),
                  ],
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool _widerThanTyped(FoundPlace p) {
    final cover = p.coveredBy;
    if (cover == null) return false;
    return cover.start < p.span.start || cover.end > p.span.end;
  }

  String _textOf(Span span) {
    final doc = widget.bench.document;
    if (doc == null) return '';
    final end = span.end.clamp(0, doc.text.length);
    final start = span.start.clamp(0, end);
    return doc.text.substring(start, end);
  }

}

/// One count, on its own wash. The colour belongs to the box.
class _Count extends StatelessWidget {
  const _Count(this.label, this.tint, this.wash);

  final String label;
  final Color tint;
  final Color? wash;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: wash == null ? Zc.lineSoft : Colors.transparent),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tint),
      ),
    );
  }
}

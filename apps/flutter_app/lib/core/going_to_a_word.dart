// Going to a word — **one function, and the only one** (083, ruling 14).
//
// The owner, 14 Oct: «الانتقال إلى كلمة هو نظام بحث عن كلمة». Review is its
// first caller; 084's Find (Ctrl+F) is the second, and it must be the same
// function or the two will drift — the defect this project has paid for twice
// already, in 068 and 071. So the walk owns no movement of its own: it says
// *which* word, and this file is *how* one is arrived at.
//
// Nothing here draws anything. The lighting is the column's own
// (`OriginalText.focus` paints the wash and drops the anchor at the span); the
// scrolling is the anchor's; and what this adds is the one act that joins them
// — and the answer to «where did it land», which is what lets the word's own
// two buttons be drawn beside it instead of in a panel on the far side of the
// window.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

/// **The words still waiting, in the order a person reads them** — 083, rulings
/// 4 and 5.
///
/// Not `bench.suggested`: the core hands findings back in the order its layers
/// found them, which is the scan's order and not the eye's. The same sentence
/// is written over [theFirstWaitingWord] in `session_state.dart`, which answers
/// «the first» for the exits' guide (083a) — and the two must agree, which is
/// why `the_review_in_two_forms_test.dart` asserts that this list's first
/// element **is** that function's answer. One law, two callers, one guard that
/// reddens if they ever part; when `session_state.dart` is next open, that
/// function becomes `theWaitingWordsInReadingOrder(findings).firstOrNull` and
/// the guard becomes a tautology, which is the right end for it.
List<Finding> theWaitingWordsInReadingOrder(List<Finding> findings) {
  final waiting = findings.where((f) => f.state == MarkState.suggested).toList();
  waiting.sort((a, b) => a.span.start.compareTo(b.span.start));
  return List<Finding>.unmodifiable(waiting);
}

/// Where `lit` stands among them, or `-1` when it is not one of them.
int theWalkIsAt(List<Finding> waiting, Finding? lit) {
  if (lit == null) return -1;
  return waiting.indexWhere((f) => f.id == lit.id);
}

/// **The next word to go to, and why it comes round again.**
///
/// Forward through reading order from the word that was lit. After the last one
/// it starts again at the first, because **Next is how a word is left for
/// later** (ruling 5) — a walk that stopped at the end would leave every word a
/// person passed over unreachable, with the exits still shut and no way back to
/// them but the list. Answering takes a word out of this list, so a walk that
/// is being answered still ends; only a walk of nothing but Next goes round.
///
/// **«After» is by span and not by position in the list**, which is what makes
/// one function serve both presses: a word that was just answered is no longer
/// in the list at all, and asking «which index was it» would then answer «it is
/// not there» and send the walk back to the top. Where the word *stood* is
/// still the right question, and the span is the only thing that still knows
/// it.
Finding? theWaitingWordAfter(List<Finding> findings, Finding? lit) {
  final waiting = theWaitingWordsInReadingOrder(findings);
  if (waiting.isEmpty) return null;
  if (lit == null) return waiting.first;
  for (final f in waiting) {
    if (f.span.start > lit.span.start) return f;
  }
  return waiting.first;
}

/// **Go to a word: light it, put the columns on it, and say where it landed.**
///
/// `anchor` is the zero-size marker the Original column drops at the lit span
/// (`OriginalText.focusKey`), so this needs no knowledge of how text is laid
/// out — the column already did that work for the wash.
///
/// Returns the centre of the word on the glass, in the window's own
/// coordinates, or **null when it is not drawn**: no document, a column that is
/// not on screen, a word that the frame has not laid out yet. A null is not a
/// failure to report — it is «there is nowhere to put the buttons», and the
/// caller then draws none rather than drawing them at the corner of the window.
///
/// **The other column.** Landing is a scroll of the Original column, and the
/// Safe column follows it through the step lock, page edge to page edge
/// (`_follow` in `workspace.dart`, W8/073's own alignment). With the lock off
/// it does not follow, because the person pressed a control that says «do not
/// move the other column with this one» and 046/K's rule is that the app
/// changes such a state by no act of its own. If the owner wants a word to
/// override that, it is one line here and a sentence in the paper.
Future<Offset?> goToTheWord(
  Workbench bench,
  Finding word, {
  required GlobalKey anchor,
}) async {
  // The lighting is the focus, and the focus is the bench's one slot for it:
  // this does not keep a second «where we are looking», which would be the two
  // sources of one fact that 070 cost a day.
  if (bench.focused != word.id) bench.focusOn(word.id);

  // **A frame, asked for and then waited on.** `addPostFrameCallback` schedules
  // no frame of its own, so without the second line the callback can sit
  // unrun — measured in 076, where a guard stayed green because of exactly
  // this. The anchor also has to exist before it can be scrolled to, and it
  // only exists once the column has drawn it at the new span.
  final landed = Completer<Offset?>();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final there = anchor.currentContext;
    if (there == null) {
      landed.complete(null);
      return;
    }
    await Scrollable.ensureVisible(
      there,
      // A third of the way down, not at the very top: a word with nothing above
      // it reads as the start of the document rather than as a place in it.
      alignment: 0.3,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    landed.complete(whereItIsOnTheGlass(anchor));
  });
  WidgetsBinding.instance.scheduleFrame();
  return landed.future;
}

/// Where a marker sits on the glass, in the window's coordinates — null when it
/// is not drawn. Its own function because the walk and the press both ask it,
/// and because a `RenderBox` that is not laid out answers nothing safe.
Offset? whereItIsOnTheGlass(GlobalKey marker) {
  final there = marker.currentContext;
  if (there == null) return null;
  final box = there.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero);
}

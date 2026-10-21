// The acts under the Original column, each in the state the behaviour board
// gives it. A disabled control here always says *why* it is disabled — «Select
// text, then Protect» — because a greyed button with no reason is the most
// common way an app lies about what it can do.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/going_to_a_word.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/protecting.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';

class ActsBar extends StatelessWidget {
  const ActsBar({
    super.key,
    required this.bench,
    required this.ground,
    required this.onSay,
    required this.onWalk,
  });

  final Workbench bench;
  final Ground ground;

  /// **Review, and then Next** — 083 rulings 4 and 5. The press belongs to the
  /// Workspace, because going to a word moves its columns and draws the word's
  /// own two buttons beside it; this bar only says what the button is called
  /// and when it is there at all.
  final VoidCallback onWalk;

  /// How the screen reports what the core just did. Every act says its result
  /// out loud — «protected in 4 places», «it snapped to two whole items» —
  /// because otherwise a press that did something unexpected looks like a press
  /// that did nothing.
  final void Function(String) onSay;

  @override
  Widget build(BuildContext context) {
    final v = bench.selected;
    final state = protectStateOf(v);
    // The walk, read rather than kept: the lit word is the bench's one focus
    // slot, and where it stands among the waiting ones is the count the button
    // wears. Both come from the one function (083 ruling 14), so the button and
    // the walk cannot disagree about which word is next.
    final waiting = theWaitingWordsInReadingOrder(bench.findings);
    final at = theWalkIsAt(waiting, bench.focusedFinding);
    final walking = bench.walking && at >= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
      decoration: const BoxDecoration(
        color: Zc.warmCard,
        border: Border(top: BorderSide(color: Zc.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _protect(context, state, v),
              // 041-K: a surname selected on its own, with a capitalised word
              // one space in front of it. Offered, never taken: «Björn
              // Sandström» is two decisions and the second one is the
              // person's.
              //
              // **Not over a token either** — 079 rule 5, and the second case
              // of the rule beside it: the press widens the selection and
              // protects it, so over `Herr __Z_…_PERSON_…__` it would reach
              // across the token and the door would refuse it. A button that
              // cannot work should not be drawn, which is the whole reason
              // `on_a_token` is a state and not an error.
              if (v != null &&
                  v.alsoBefore != null &&
                  state != ProtectState.known &&
                  state != ProtectState.alreadyOurs)
                ZButton(
                  label: sentences.alsoTheWordBefore,
                  icon: Icons.chevron_left,
                  onPressed: bench.busy ? null : () => unawaited(bench.alsoTakeTheWordBefore()),
                  hint: sentences.alsoTheWordBeforeHint,
                ),
              ZButton(
                label: sentences.undoProtection,
                icon: Icons.undo,
                onPressed: bench.canUndo ? () => _undo(context) : null,
                hint: bench.canUndo ? null : sentences.nothingToUndoHint,
              ),
              ZButton(
                label: sentences.rescanAct,
                icon: Icons.refresh,
                onPressed: bench.busy ? null : () => _rescan(context),
              ),
              // **Review becomes Next, and carries the count** — 083 rulings
              // 4, 5 and 10.
              //
              // One button for one act: go to the word that is waiting. The
              // first press is «Review» and lands on the first one in reading
              // order; after that it is «Next 3/7» — where the walk is, out of
              // how many are left — and each press leaves the lit word for
              // later and goes to the one after it. Answering needs no press
              // here at all: it moves on by itself.
              //
              // **With nothing waiting the button is gone, not disabled**
              // (ruling 10): the exits are open, and the badge was never
              // allowed to read zero for the same reason — a control that says
              // nothing is waiting still looks like something is.
              if (waiting.isNotEmpty)
                ZButton(
                  label: walking ? sentences.nextOfWaitingCount(at + 1, waiting.length) : sentences.reviewAct,
                  icon: walking ? Icons.east : Icons.fact_check_outlined,
                  tint: Zc.amber,
                  badge: walking ? null : waiting.length,
                  onPressed: bench.busy ? null : onWalk,
                ),
              // Names this document uses that Z does not know. The badge is
              // how many decisions are waiting — and with none waiting it is
              // gone, not zero, like the one beside it.
              ZButton(
                label: sentences.namesAct,
                icon: Icons.person_search_outlined,
                tint: bench.openCandidates.isNotEmpty ? Zc.river : null,
                badge: bench.openCandidates.isEmpty ? null : bench.openCandidates.length,
                onPressed: bench.busy
                    ? null
                    : () => bench.panel == OpenPanel.names
                        ? bench.closeNameReview()
                        : bench.openNameReview(),
                hint: bench.openCandidates.isEmpty
                    ? sentences.zKnowsEveryNameHere
                    : null,
              ),
              ZButton(
                label: sentences.tokensAct,
                icon: Icons.key_outlined,
                badge: bench.tokens.isEmpty ? null : bench.tokens.length,
                onPressed: bench.tokens.isEmpty ? null : () => bench.openTokens(bench.panel != OpenPanel.tokens),
                hint: bench.tokens.isEmpty ? sentences.nothingIsProtectedYetHint : null,
              ),
            ],
          ),
          if (state == ProtectState.known) ...[
            const SizedBox(height: 10),
            _Known(view: v!),
          ],
          if (state == ProtectState.snaps) ...[
            const SizedBox(height: 10),
            Text(
              v!.snapsTo.length == 1
                  ? sentences.selectionCutsIntoProtected
                  : sentences.selectionSpansProtectedItems(v.snapsTo.length),
              style: Zc.small.copyWith(color: Zc.amber, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  /// The five states, in one place, so no two of them can drift apart.
  Widget _protect(BuildContext context, ProtectState state, SelectionView? v) {
    return switch (state) {
      // DISABLED — and the hint says what to do about it.
      ProtectState.disabled => ZButton(
          label: sentences.protectAct,
          filled: true,
          hint: sentences.selectTextThenProtect,
        ),
      // KNOWN — no dialog. The only act offered is Undo, above.
      ProtectState.known => ZButton(
          label: sentences.protectAct,
          filled: true,
          hint: sentences.alreadyProtectedSeeBelow,
        ),
      // ALREADY OURS — **079 rule 5**. The selection is standing on a token
      // this program put there, in a document that has come back. A press would
      // mint a second token over the first and the answer would come back
      // unreadable, so there is no press: the sentence is the one the core's
      // outcome carries, worded in one place (`theTokenIsAlreadyOurs`).
      //
      // No Undo beside it either — there is nothing of this document to undo —
      // which is why it is not `known`.
      // **Not `const` since 092**: the hint is a sentence from the one list
      // now, and a list that answers in the language the app is in cannot be
      // a compile-time constant. The widget is the same widget.
      ProtectState.alreadyOurs => ZButton(
          label: sentences.protectAct,
          filled: true,
          hint: theTokenIsAlreadyOurs,
        ),
      // SNAPS — it will act, but on whole items, and it says so first.
      ProtectState.snaps => ZButton(
          label: sentences.protectWholeItems,
          filled: true,
          badge: v!.snapsTo.length,
          onPressed: () => _press(context),
        ),
      // READY — **one press, and it is protected** (083, ruling 1). No dialog
      // opens; the badge says how many places this one press settles, which is
      // what «Protect all matches» used to be a second button for.
      _ => ZButton(
          label: sentences.protectAct,
          filled: true,
          badge: (v?.matches ?? 0) > 1 ? v!.matches : null,
          onPressed: () => _press(context),
        ),
    };
  }

  /// **The press** — 083, ruling 1. What was a dialog is now one act, and what
  /// it did is said where the press happened.
  Future<void> _press(BuildContext context) async {
    final outcome = await protectTheSelection(bench);
    if (outcome == null) return;
    if (!context.mounted) return;
    // **What it did, in the one place that words it** — the fold of 15 Oct, and
    // G33. Every outcome this press can meet is answered in `protectSaid`,
    // including 079 rule 5, which is reachable from here only if the button's
    // state and the core's answer ever disagree — which is exactly why the law
    // is at the door as well as on the button.
    onSay(protectSaid(outcome, ProtectAct.aSelection));
  }

  Future<void> _undo(BuildContext context) async {
    final outcome = await bench.undo();
    if (outcome == null) return;
    onSay(switch (outcome) {
      UndoOutcome_NothingToUndo() => sentences.thereWasNothingToUndo,
      // **Every token the act uncovered, named** — since 15 October the core
      // hands back the list rather than the first of them: one act can hold
      // several (a column takes one cell per held line, and «Stefan Keller» is
      // two words and two tokens), and «Took back T» about two of them was one
      // sentence true of one.
      UndoOutcome_Undone(:final tokens, :final places, :final createdEntity) => createdEntity == null
          ? (places == 1
              ? sentences.tookBackTokens(tokens.join(sentences.andBetweenNames))
              : sentences.tookBackTokensInPlaces(tokens.join(sentences.andBetweenNames), places))
          : sentences.tookBackTokensIdentityStays(
              tokens.join(sentences.andBetweenNames), createdEntity),
    });
  }

  Future<void> _rescan(BuildContext context) async {
    await bench.rescan();
    final snap = bench.snap;
    if (snap == null) return;
    onSay(
      sentences.scannedAgainReport(
          snap.autoProtected, snap.userProtected, snap.openSuggestions, snap.normal),
    );
  }
}

/// KNOWN. «Already protected as Z_PERSON_72A, from Z Vault · CLIENT #17.»
class _Known extends StatelessWidget {
  const _Known({required this.view});

  final SelectionView view;

  @override
  Widget build(BuildContext context) {
    final source = view.protectedBy;
    // **One sentence, two faces.** The tokens stay in the mono face, so the
    // sentence is asked for with a mark where they go and drawn in two runs;
    // the tail that names the source is part of the same line in the list.
    final around = aroundTheValue((mark) => source == null
        ? sentences.alreadyProtectedAsTokens(mark)
        : sentences.alreadyProtectedAsFrom(
            mark,
            sourceName(source),
            view.protectedDetail.isEmpty ? '' : ' · ${view.protectedDetail}'));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: Zc.panel(
        fill: source == Source.vault ? Zc.riverWash : Zc.clayWash,
        edge: source == Source.vault ? Zc.river.withValues(alpha: 0.3) : Zc.clayEdge,
        radius: 9,
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 15, color: source == Source.vault ? Zc.river : Zc.clayDeep),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Zc.small.copyWith(color: source == Source.vault ? Zc.river : Zc.clayDeep),
                children: [
                  TextSpan(text: around.before),
                  TextSpan(
                    // The tokens as they stand in the text — one per word of
                    // what the app read for itself (085 ruling 1).
                    text: view.protectedAs.join(' '),
                    style: const TextStyle(fontFamily: Zc.mono, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: around.after),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

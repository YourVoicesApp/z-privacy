// The acts under the Original column, each in the state the behaviour board
// gives it. A disabled control here always says *why* it is disabled — «Select
// text, then Protect» — because a greyed button with no reason is the most
// common way an app lies about what it can do.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/going_to_a_word.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/widgets/protect_dialog.dart';

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
              if (v != null && v.alsoBefore != null && state != ProtectState.known)
                ZButton(
                  label: 'Also the word before',
                  icon: Icons.chevron_left,
                  onPressed: bench.busy ? null : () => unawaited(bench.alsoTakeTheWordBefore()),
                  hint: 'Takes the capitalised word in front of the selection too',
                ),
              if (state == ProtectState.ready || state == ProtectState.asks)
                if ((v?.matches ?? 0) > 1)
                  ZButton(
                    label: 'Protect all matches',
                    badge: v!.matches,
                    onPressed: () => _open(context, all: true),
                  ),
              ZButton(
                label: 'Undo protection',
                icon: Icons.undo,
                onPressed: bench.canUndo ? () => _undo(context) : null,
                hint: bench.canUndo ? null : 'Nothing to undo',
              ),
              ZButton(
                label: 'Rescan',
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
                  label: walking ? 'Next ${at + 1}/${waiting.length}' : 'Review',
                  icon: walking ? Icons.east : Icons.fact_check_outlined,
                  tint: Zc.amber,
                  badge: walking ? null : waiting.length,
                  onPressed: bench.busy ? null : onWalk,
                ),
              // Names this document uses that Z does not know. The badge is
              // how many decisions are waiting — and with none waiting it is
              // gone, not zero, like the one beside it.
              ZButton(
                label: 'Names',
                icon: Icons.person_search_outlined,
                tint: bench.openCandidates.isNotEmpty ? Zc.river : null,
                badge: bench.openCandidates.isEmpty ? null : bench.openCandidates.length,
                onPressed: bench.busy
                    ? null
                    : () => bench.panel == OpenPanel.names
                        ? bench.closeNameReview()
                        : bench.openNameReview(),
                hint: bench.openCandidates.isEmpty
                    ? 'Z knows every name this document uses'
                    : null,
              ),
              ZButton(
                label: 'Tokens',
                icon: Icons.key_outlined,
                badge: bench.tokens.isEmpty ? null : bench.tokens.length,
                onPressed: bench.tokens.isEmpty ? null : () => bench.openTokens(bench.panel != OpenPanel.tokens),
                hint: bench.tokens.isEmpty ? 'Nothing is protected yet' : null,
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
                  ? 'That selection cuts into something already protected. Protect would take the '
                      'whole item instead.'
                  : 'That selection spans ${v.snapsTo.length} protected items. Protect would take '
                      'each of them whole, under its own token.',
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
      ProtectState.disabled => const ZButton(
          label: 'Protect',
          filled: true,
          hint: 'Select text, then Protect',
        ),
      // KNOWN — no dialog. The only act offered is Undo, above.
      ProtectState.known => const ZButton(
          label: 'Protect',
          filled: true,
          hint: 'Already protected — see below',
        ),
      // SNAPS — it will act, but on whole items, and it says so first.
      ProtectState.snaps => ZButton(
          label: 'Protect whole items',
          filled: true,
          badge: v!.snapsTo.length,
          onPressed: () => _open(context, all: false),
        ),
      // ASKS and READY both open the dialog; the dialog itself carries the
      // vault's question when there is one.
      _ => ZButton(label: 'Protect', filled: true, onPressed: () => _open(context, all: false)),
    };
  }

  Future<void> _open(BuildContext context, {required bool all}) async {
    final v = bench.selected;
    final span = bench.selection;
    final doc = bench.document;
    if (v == null || span == null || doc == null) return;

    final wish = await showDialog<ProtectWish>(
      context: context,
      builder: (_) => ProtectDialog(
        view: v,
        selectedText: doc.text.substring(span.start, span.end),
        vault: ground.vault,
        inAProfile: bench.profileId != null,
        profileName: bench.profileId == null
            ? 'this client'
            : ground.profiles
                .firstWhere(
                  (p) => p.id == bench.profileId,
                  orElse: () => ProfileRow(id: bench.profileId!, name: 'this client', languages: const []),
                )
                .name,
      ),
    );
    if (wish == null) return;

    final outcome = await bench.protectSelection(
      scope: wish.scope,
      kind: wish.kind,
      // The scope decides the breadth now; «protect all matches» is the button
      // that picks «this conversation» for you.
      allMatches: all,
    );
    if (outcome == null) return;
    onSay(switch (outcome) {
      ProtectOutcome_Applied(:final token, :final places) => places == 1
          ? 'Protected as $token.'
          : 'Protected as $token, in $places places.',
      ProtectOutcome_AlreadyProtected(:final token, :final source) =>
        'Already protected as $token, by ${sourceName(source).toLowerCase()}.',
      ProtectOutcome_BelongsToEntity(:final entity, :final token) =>
        'That belongs to $entity and keeps its token $token.',
      ProtectOutcome_Snapped(:final spans) =>
        'The selection cut into protected text, so nothing changed. It would snap to '
            '${spans.length} whole ${spans.length == 1 ? "item" : "items"}.',
    });
  }

  Future<void> _undo(BuildContext context) async {
    final outcome = await bench.undo();
    if (outcome == null) return;
    onSay(switch (outcome) {
      UndoOutcome_NothingToUndo() => 'There was nothing to undo.',
      UndoOutcome_Undone(:final token, :final places, :final createdEntity) => createdEntity == null
          ? (places == 1
              ? 'Took back $token.'
              : 'Took back $token, in all $places places — it went in as one act, so it came out as one.')
          : 'Took back $token. The identity $createdEntity is still in the vault.',
    });
  }

  Future<void> _rescan(BuildContext context) async {
    await bench.rescan();
    final snap = bench.snap;
    if (snap == null) return;
    onSay(
      'Scanned again: ${snap.autoProtected} protected automatically · ${snap.userProtected} by you · ${snap.openSuggestions} need your word · ${snap.normal} normal.',
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
                  const TextSpan(text: 'Already protected as '),
                  TextSpan(
                    text: view.protectedAs,
                    style: const TextStyle(fontFamily: Zc.mono, fontWeight: FontWeight.w600),
                  ),
                  if (source != null)
                    TextSpan(
                      text: ', from ${sourceName(source)}'
                          '${view.protectedDetail.isEmpty ? "" : " · ${view.protectedDetail}"}.',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// **Selecting is protecting** — 083, ruling 1, sealed by the owner on 13 Oct:
// «أي تحديد هو تشفير… الخيارات هي في فك التشفير». Select, and it is protected.
// No dialog, no scope to pick, no kind to pick, no question.
//
// A function and not screen code, because 084's search bar will protect a word
// it has just found with the same one act.
//
// **What was here until today:** `widgets/protect_dialog.dart`, which asked for
// a scope and a kind before anything happened. It is **deleted, not hidden**.
// The scope is the conversation, because that is the only reach 083's model
// has; and the kind is the one the scanner already found on that exact stretch,
// or `CUSTOM` — never a guess, which is the core's own ruling and is written
// where the core answers it (`inspect_selection`).
//
// The five button states the dialog's file also held are below: they are read
// off `SelectionView`, which the core computes with the same code that would do
// the protecting. A widget that works out for itself whether something is
// already protected will eventually disagree with the core, and the user will
// be the one who finds out.
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

/// The states of the Protect button, named as the behaviour board names them.
///
/// **`asks` is gone with the dialog it belonged to** (083 ruling 1). It meant
/// «the vault knows this value under an identity, so put a question first», and
/// there is no question any more: a selection protects, and when the value
/// belongs to an identity the **core** says so in the outcome — «that belongs
/// to X and keeps its token Y» — which the acts bar prints where the press
/// happened. A state whose name promises a question nobody asks is a state that
/// lies, so it is one fewer.
///
/// **`alreadyOurs` is 079's state** — the selection is standing on a token this
/// program put there, in a document that has come back. It is not `known`:
/// `known` means this document has a protection over that stretch and offers
/// Undo, and there is none — the token arrived as text. So the press is not
/// offered at all, and the line beside it says why.
enum ProtectState { disabled, ready, known, snaps, alreadyOurs }

ProtectState protectStateOf(SelectionView? v) {
  if (v == null || v.empty) return ProtectState.disabled;
  // **Before `known`, and before everything else**: the core answers this on
  // the span Protect would really take, and a press over it would mint a second
  // token over the first (079 rule 5).
  if (v.onAToken) return ProtectState.alreadyOurs;
  // **A list and not one token** since 085 ruling 1 (15 October): a name the
  // app read for itself is one token per word, so a selection over the whole of
  // «Katrin Sommer» is two of them and is no less already ours for that.
  if (v.protectedAs.isNotEmpty) return ProtectState.known;
  if (v.snapsTo.isNotEmpty) return ProtectState.snaps;
  return ProtectState.ready;
}

/// **Protect what is selected, at once** — every place of it in this
/// conversation, under one token.
///
/// «One answer per word per conversation» is the same law the review's two
/// buttons keep (083b, ruling 7): a hand selection of `Lindqvist` settles every
/// `Lindqvist` in the conversation, so a person decides about a **value** and
/// not about a byte range.
///
/// **The breadth comes from the scope, not from a second door** — measured,
/// after a break in the guard reddened nothing and sent me to look: with
/// `Scope::Conversation` the plain `protect` already takes all three places of
/// `Lindqvist`, exactly as `protect_all_matches` does, and `Scope::Once` is
/// what takes one. So this calls the one door and lets the scope say how far,
/// and «Protect all matches» is left with no caller at all — which is why its
/// button is gone rather than merely folded in.
///
/// Returns what the core did, so the press can say it. Null when there is
/// nothing selected, or when the core refused — and then the refusal is already
/// in `bench.trouble`, where the screen draws it.
Future<ProtectOutcome?> protectTheSelection(Workbench bench) {
  final v = bench.selected;
  if (v == null || v.empty) return Future<ProtectOutcome?>.value();
  return bench.protectSelection(
    // The only reach 083's model has. No «everywhere», and no profile:
    // a conversation's values belong to its session (rulings 15–17).
    scope: Scope.conversation,
    // The scanner's own answer on this exact stretch, or `Custom`. The screen
    // adds nothing to it: `SelectionView.kind` is the core's field, and the
    // core is where «never a guess from a second classifier» is enforced.
    kind: v.kind,
    // The scope above is the breadth; this door is the one-place one, and the
    // core spreads it across the conversation itself.
    allMatches: false,
  );
}

/// **Protect the places the bar found in the clear** — 084's first act, and a
/// function because the bar is not the only thing that will ask.
///
/// **One `Scope.once` per place, and that is the whole of ruling (c)** —
/// measured, after the guard caught the other reading: a single
/// `Scope.conversation` protect on one clear place comes back
/// `Applied { places: 4 }` and protects **every** place of the word, including
/// the ones standing inside «Anna Lindqvist» and «Lindqvist AB» that nobody
/// has answered yet. That is more than the person typed, and it leaves «Anna»
/// and «AB» beside a token with their own suggestions still waiting.
///
/// Place by place instead: the two clear ones become
/// `[Waiting, Protected, Waiting, Protected]`, the waiting ones are untouched,
/// and — measured, not hoped — **both places carry the same token**, because a
/// token is named from (client, document, value) and not from the act. So one
/// press is still one decision with one token in the payload.
///
/// **Why this is narrower than a hand selection** (083c, which takes every
/// place with `Scope.conversation`): a selection is the word the person drew,
/// and the owner's law is that a selection is their will. The bar's act is
/// about *the places it found*, among them places inside words they did not
/// type — and the lead ruled on 14 Oct that those are left to the review, which
/// is also what keeps the exits shut until they are answered.
///
/// The kind of each place comes from the core's one answer for that span.
///
/// **One press, one answer, and the answer counts every place** — e2's two
/// findings of 15 October, and the second of them was a sentence that lied:
/// the loop kept only the *last* place's outcome, so two places protected
/// under one token came back `Applied { places: 1 }` and the bar said
/// «Protected as T.» about two. A place that refused — snapped, or a value the
/// vault knows under an identity — was swallowed outright whenever a later
/// place succeeded.
///
/// So the fold is the one the core already does for a column
/// (`ops::protect_cell_in_lines`), place by place instead of cell by cell, and
/// it is written here because `core` is where the acts live and because no
/// sentence is written in this file: the number and the token go to
/// `protectSaid`, which is the only place that words them (G33).
///
/// **A place that is already a token of ours is not pressed on at all** —
/// 079 rule 5, e2's first finding. The core refuses it at the door either way
/// (`a_token_already_stands_there`, before the vault is taught anything, which
/// is G32), so this changes nothing about what is minted; what it changes is
/// that the app stops asking for an act it has already been told it may not
/// have, and that those places are counted apart from the ones that refused
/// for some other reason. A search whose word is a token of ours finds nothing
/// but tokens — every place of one search is the same text — so «nothing was
/// protected, and a token is why» is the whole answer when it happens.
Future<ProtectOutcome?> protectThePlacesInTheClear(Workbench bench, List<Span> clear) async {
  if (clear.isEmpty) return null;
  var places = 0;
  var tokensOfOurs = 0;
  var token = '';
  var standing = '';
  ProtectOutcome? refused;
  try {
    for (final where in clear) {
      final view = await z.inspectSelection(session: bench.session, span: where);
      if (view.onAToken) {
        tokensOfOurs += 1;
        // The token standing there, read from the document and never minted:
        // the field means «which token», and this place *is* one.
        if (standing.isEmpty) standing = _theTextAt(bench, where);
        continue;
      }
      final outcome = await z.protect(
        session: bench.session,
        span: where,
        scope: Scope.once,
        kind: view.kind,
      );
      switch (outcome) {
        // The token of the first place that was really protected — every place
        // of one search carries the same one, because a token is named from
        // (client, document, value) and not from the act (measured, 084).
        case ProtectOutcome_Applied(token: final t):
          places += 1;
          if (token.isEmpty) token = t;
        // Already protected, snapped, or a value an identity owns: honest
        // answers for one place, and none of them stops the rest. Kept so the
        // press can say one of them when **nothing** was protected, instead of
        // saying «protected in 0 places».
        //
        // **A wildcard on purpose, and the only one in the round.** This file
        // asks one question — was this place protected — so a sixth variant
        // belongs here among «something else» and is carried out whole to the
        // one switch that must name it. That switch is exhaustive, so the
        // build still stops: in `protectSaid`, where the sentence is.
        default:
          refused ??= outcome;
      }
    }
    await bench.refresh();
    final still = bench.selection;
    if (still != null) await bench.select(still);
    if (places > 0) return ProtectOutcome.applied(token: token, places: places);
    if (tokensOfOurs > 0) return ProtectOutcome.standsOnAToken(token: standing);
    return refused;
  } on ApiError catch (e) {
    // The refusal after the refresh, for the reason `un_protecting.dart` gives.
    await bench.refresh();
    bench.trouble = humanMessage(e);
    bench.focusOn(bench.focused);
    return null;
  }
}

/// What stands at a place, for the one field that asks «which token». Clamped
/// the way the bar's own reader is: a document can change under a span that was
/// measured a moment ago, and a crash is not an answer.
String _theTextAt(Workbench bench, Span where) {
  final doc = bench.document;
  if (doc == null) return '';
  final end = where.end.clamp(0, doc.text.length);
  final start = where.start.clamp(0, end);
  return doc.text.substring(start, end);
}

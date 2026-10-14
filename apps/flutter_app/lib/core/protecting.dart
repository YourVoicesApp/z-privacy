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
enum ProtectState { disabled, ready, known, snaps }

ProtectState protectStateOf(SelectionView? v) {
  if (v == null || v.empty) return ProtectState.disabled;
  if (v.protectedAs != null) return ProtectState.known;
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
Future<ProtectOutcome?> protectThePlacesInTheClear(Workbench bench, List<Span> clear) async {
  if (clear.isEmpty) return null;
  ProtectOutcome? last;
  try {
    for (final where in clear) {
      final view = await z.inspectSelection(session: bench.session, span: where);
      last = await z.protect(
        session: bench.session,
        span: where,
        scope: Scope.once,
        kind: view.kind,
      );
    }
    await bench.refresh();
    final still = bench.selection;
    if (still != null) await bench.select(still);
    return last;
  } on ApiError catch (e) {
    // The refusal after the refresh, for the reason `un_protecting.dart` gives.
    await bench.refresh();
    bench.trouble = humanMessage(e);
    bench.focusOn(bench.focused);
    return null;
  }
}

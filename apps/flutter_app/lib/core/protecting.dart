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
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

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

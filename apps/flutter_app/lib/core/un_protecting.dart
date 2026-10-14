// Un-protecting, in the two ways the owner allows — **and functions, not
// screen code**, because 084's search bar will offer the same two acts over a
// word it has just found (083, ruling 3; the lead's instruction of 14 Oct).
//
// There is no third way. «Everywhere» was struck out by the owner: a
// conversation is as far as un-protection reaches, and knowledge is forgotten
// by a different act under its own name («Forget»), which this file does not
// touch.
//
// **The boundary, named rather than hidden.** The one-place act already exists
// as `Workbench.unprotect`, in `core/session_state.dart`, which is the other
// seat's file — so the every-place act cannot be its sibling there today. It
// lives here instead, calls the core through the same bridge, and brings the
// bench back up to date through its **public** surface. e2 absorbs it in one
// line when his round is sealed, exactly as `theFirstWaitingWord` will be
// absorbed; until then this file is the one place both acts can be read side by
// side, which is worth more than tidiness.
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

/// **Here** — this one place, and the other places keep the protection and the
/// token they had.
///
/// The token stays what it was for the places that were not touched, which is
/// what keeps the outgoing text honest: the payload still carries that token
/// where it is still protected, and the uncovered place reads as the document
/// reads. Measured end to end before this was built — three places, «here» on
/// the middle one, the payload came out with two tokens and the name in the
/// clear once, and a model answer quoting the token still restored.
Future<UndoOutcome?> unprotectHere(Workbench bench, Span span) =>
    bench.unprotect(span);

/// **In this conversation** — every place that carries this token.
///
/// **The token, not the text**, by the lead's ruling of 14 Oct: a person
/// un-protects what they can see, and what they can see is a token; and the
/// token's allowed set is what keeps the payload honest (C4), so acting by text
/// could leave a token in the outgoing text that nothing explains. Inside one
/// conversation a value and a token are one to one today, so the owner's «every
/// appearance in this conversation» is met exactly. If aliases ever split the
/// two, the token is still the right unit — and that day it goes to the owner
/// as a ruling rather than being decided in a widget.
Future<UndoOutcome?> unprotectInThisConversation(Workbench bench, Span span) async {
  try {
    final outcome = await z.unprotectEveryPlace(session: bench.session, span: span);
    await bench.refresh();
    final still = bench.selection;
    if (still != null) await bench.select(still);
    return outcome;
  } on ApiError catch (e) {
    // **The refusal survives the refresh**, which is the whole of the 30
    // September finding: `refresh()` sets `trouble` to null on success, so the
    // news is put there *after* it and the listeners are told afterwards. A
    // refusal that never reaches a person is the same thing as no refusal.
    await bench.refresh();
    bench.trouble = humanMessage(e);
    // Told through a public act that notifies and touches nothing else:
    // `notifyListeners` is protected to subclasses, and `select` would clear
    // the very sentence this line exists to keep. The focus is set to what it
    // already is.
    bench.focusOn(bench.focused);
    return null;
  }
}

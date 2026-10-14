// Un-protecting, in the two ways the owner allows — **and functions, not
// screen code**, because 084's search bar will offer the same two acts over a
// word it has just found (083, ruling 3; the lead's instruction of 14 Oct).
//
// There is no third way. «Everywhere» was struck out by the owner: a
// conversation is as far as un-protection reaches, and knowledge is forgotten
// by a different act under its own name («Forget»), which this file does not
// touch.
//
// **The boundary is gone, and these two names are not.** Both acts are now
// `Workbench`'s own — `unprotect` and `unprotectEveryPlace`, one above the
// other in `core/session_state.dart`, which is where every other act that
// touches the bench lives. This file was written while that file was another
// seat's, so that the every-place act would not have to wait for a round to
// seal; the lead's promise was that it would be absorbed in one line each, and
// this is it.
//
// They stay because the names are the owner's two words — «here» and «in this
// conversation» — and 084 will call them by those names from a search result
// where no bench method's name would read as the act.
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

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
/// Inside one conversation a value and a token are one to one today, so the
/// owner's «every appearance in this conversation» is met exactly. If aliases
/// ever split the two, the token is still the right unit — and that day it goes
/// to the owner as a ruling rather than being decided in a widget.
Future<UndoOutcome?> unprotectInThisConversation(Workbench bench, Span span) =>
    bench.unprotectEveryPlace(span);

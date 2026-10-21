import 'package:flutter/services.dart';
import 'package:zprivacy/core/sentences.dart';

/// **The first act of every press that puts something on the clipboard** — 081.
///
/// The owner, 13 October 2026: *«العمل دائماً يحدث على حافظة نظيفة»* — the work
/// always happens on a clean container. The press clears the clipboard **before**
/// anything else is looked at, and only then decides whether anything goes out.
///
/// ## Why first, and not when something fails
///
/// Because «clear it if the copy fails» is a branch, and a branch is something
/// every refusal written from now on has to remember. The owner's own leak, 12
/// October, was exactly a refusal that remembered to write nothing and forgot
/// that it had erased nothing: a nameless press at the exit refused with one
/// small line, and the German letter he had copied minutes earlier was still on
/// the clipboard to be pasted into a model. The application did not put the
/// original out. It left it.
///
/// Cleared first, there is nothing left to forget, and no order of branches
/// below can get it wrong.
///
/// ## Why it is one function
///
/// Because this rule has five seats — the exit's three doors through
/// `beginThenRead`, the answer panel's two copies, the report button, the
/// trouble report and a token's own name — and a rule written in place is not
/// applied to its second case. One function, called by each of them, and a gate
/// that refuses a surface which writes the clipboard without calling it.
///
/// **A cancelled confirmation leaves the clipboard empty, not old**, which is
/// the lead's ruling of 13 October on «Copy Restored»: the press answers for
/// the clipboard that follows it, whatever the person then chooses.
Future<void> emptyTheClipboardFirst() =>
    Clipboard.setData(const ClipboardData(text: ''));

/// The news a refused exit leaves behind: the refusal's own sentence, and the
/// one thing about the clipboard a person cannot find out any other way.
///
/// It lives here because it is a sentence **about this rule**: the press emptied
/// the clipboard and then took nothing out, so a paste gives back nothing — and
/// «a paste that gives back nothing reads as a broken application unless
/// somebody said so first» (the owner's own first reading of his 12 October
/// leak). Two surfaces say it now — the sheet, and the workspace the sheet gets
/// out of the way for (083 rule 12) — so it is worded once.
String andTheClipboardIsEmpty(String refusal) =>
    '$refusal\n${sentences.andTheClipboardIsEmptySentence}';

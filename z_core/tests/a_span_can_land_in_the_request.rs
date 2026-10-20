// **A span can land in the request** — 096, rule 72-ب, the owner's «نعم» of
// 20 October 2026: «هذا النص يجب أن يظهر في القسم الأول من الشاشة حتى يتمكن
// المستخدم من تغطية الأمور الخاصة».
//
// What is written in the chat box is a thing that **enters**, like the
// document: with a document above it, it is the addition under the document
// after `--- Request ---`; with none, it is the whole original. So the
// person's hand must reach a word in the request through the doors it reaches
// a word in the document by, with the same outcomes and the same audit.
//
// **The shape, and this file is its contract:** one text, one offset space.
//
// ```text
//   the entered text = document ++ "\n\n--- Request ---\n" ++ request
//                    = request                                    (no document)
// ```
//
// Every door's span is UTF-16 units over **that** text. The document comes
// first, so every document offset is what it always was — no protection, no
// finding and no page edge moves — and where a span lands is **arithmetic,
// never a claim**: there is no `place` field for a caller to get wrong, which
// is «make the wrong state unrepresentable» applied to the one thing a second
// field could lie about.
//
// The alternative was a `Span` that names its half. It is not built, and the
// reason is written here because the next reader will think of it: the
// document is a reading and sixty-eight places in this core read `original`
// as «the document» — the kept copy, the page edges, the audit's own bound,
// the reader. A span that carried its half would also let a caller write
// «Request» over an offset inside the document, which this shape cannot
// express.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a request";

/// The letter on the bench, with one name in it.
const DOC: &str = "Payroll run, February\nPrepared by: Hedvig Palmgren\nAmount: 42 500\n";

/// What the person types under it. «Rückruf» is in no list and no dictionary:
/// only a hand can protect it, which is the whole of what this file measures.
const REQUEST: &str = "Herr Thomas Müller bittet um Rückruf";

/// The line the payload writes between the two, and the one the first part
/// draws. Spelled once in the core; spelled here so a change there reds this
/// file rather than moving a test's arithmetic silently.
const THE_LINE: &str = "\n\n--- Request ---\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-req-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// A bench with the document on it and the request typed under it.
fn ready(with_document: bool) -> SessionId {
    let s = open_session(None, "de".to_string()).expect("open");
    if with_document {
        import_text(s, DOC.to_string()).expect("import");
        scan(s).expect("scan");
        for f in list_findings(s).expect("findings") {
            if f.state == MarkState::Suggested {
                answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
            }
        }
    }
    set_question(s, REQUEST.to_string()).expect("the request");
    s
}

/// The one text, as this file's own arithmetic builds it — the contract above,
/// written out so that a test says what it means rather than asking the thing
/// it is measuring.
fn entered(with_document: bool) -> String {
    if with_document {
        format!("{DOC}{THE_LINE}{REQUEST}")
    } else {
        REQUEST.to_string()
    }
}

/// A span over the entered text, by the word's own characters.
fn span_of(word: &str, with_document: bool) -> Span {
    let text = entered(with_document);
    let at = text.find(word).expect("the word is in the entered text");
    let start = text[..at].encode_utf16().count() as u32;
    Span { start, end: start + word.encode_utf16().count() as u32 }
}

/// What would leave: the payload's own text.
fn what_leaves(s: SessionId) -> String {
    payload_view(build_payload(s).expect("a payload")).expect("the view").text
}

// --------------------------------------------- 1 · the hand reaches the request

/// **A hand selection in the request takes the word.** «Rückruf» is in no
/// list; the scan does not offer it; the hand covers it, and what leaves
/// carries a token where it stood.
#[test]
fn a_hand_selection_in_the_request_takes_the_word() {
    let _g = serial();
    fresh_vault("hand");
    let s = ready(true);
    let outcome = protect(s, span_of("Rückruf", true), Scope::Conversation, Kind::Person)
        .expect("the hand's own door");
    assert!(
        matches!(outcome, ProtectOutcome::Applied { .. }),
        "the hand's press in the request answered {outcome:?}"
    );
    let left = what_leaves(s);
    assert!(
        !left.contains("Rückruf"),
        "the word the hand covered is still in the text that leaves: {left}"
    );
}

/// **The same word in the document and in the request takes one token** —
/// one value, one token (rule 49), because it is one block in one vault.
#[test]
fn the_same_word_in_the_document_and_the_request_takes_one_token() {
    let _g = serial();
    fresh_vault("one");
    // The English pack, because «Prepared by:» is an English row — with the
    // German one nothing is found and the test would measure an unprotected
    // document, which is the control this file learned to assert elsewhere.
    let s = open_session(None, "en".to_string()).expect("open");
    import_text(s, "Prepared by: Hedvig Palmgren\n".to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    set_question(s, "Was verdient Hedvig Palmgren?".to_string()).expect("the request");
    let left = what_leaves(s);
    // **The set of tokens in each half, not a count.** Her name is two words,
    // so it is two tokens by 085 — one token per word — and what this measures
    // is that each word carries the **same** token on both sides of the line.
    // A count would have been the wrong claim and said so loudly: four tokens
    // for one person reads like a defect and is the rule working.
    let tokens_in = |half: &str| -> Vec<String> {
        let mut out: Vec<String> = half
            .split(|c: char| !(c.is_alphanumeric() || c == '_'))
            .filter(|w| w.starts_with("__Z_") && w.ends_with("__") && w.contains("_PERSON_"))
            .map(str::to_string)
            .collect();
        out.sort();
        out.dedup();
        out
    };
    let (document_half, request_half) = left
        .split_once("--- Request ---")
        .expect("the payload carries the document and the request");
    let in_document = tokens_in(document_half);
    let in_request = tokens_in(request_half);
    assert!(
        !in_document.is_empty() && !in_request.is_empty(),
        "her name stands in both halves and one of them carries no token: {left}"
    );
    assert_eq!(
        in_document, in_request,
        "the same name took different tokens on the two sides of the line — the \
         model would read two people"
    );
}

/// **Undo reaches the request too.** The hand covers a word there and takes it
/// back, and what leaves says so.
#[test]
fn a_hand_protection_in_the_request_can_be_undone() {
    let _g = serial();
    fresh_vault("undo");
    let s = ready(true);
    protect(s, span_of("Rückruf", true), Scope::Conversation, Kind::Person).expect("protect");
    assert!(!what_leaves(s).contains("Rückruf"), "the cover did not take");
    let undone = unprotect(s, span_of("Rückruf", true)).expect("the undo door");
    assert!(
        matches!(undone, UndoOutcome::Undone { .. }),
        "the undo in the request answered {undone:?}"
    );
    assert!(
        what_leaves(s).contains("Rückruf"),
        "the word is still covered after the hand took the cover back"
    );
}

// ------------------------------------------------------------ 2 · the refusals

/// **A span that crosses the `--- Request ---` line is refused.** It is a line,
/// and «protection may not change how a document reads» already forbids a
/// selection that crosses one.
#[test]
fn a_span_that_crosses_the_request_line_is_refused() {
    let _g = serial();
    fresh_vault("cross");
    let s = ready(true);
    let text = entered(true);
    let at = text.find("--- Request ---").expect("the line is in the entered text");
    let before = text[..at].encode_utf16().count() as u32;
    let crossing = Span { start: before.saturating_sub(6), end: before + 40 };
    let refused = protect(s, crossing, Scope::Conversation, Kind::Person);
    // **The reason, not only the refusal.** Before this round every span past
    // the document's last character was out of range, so this test would have
    // been green for the wrong reason — the trap this house pays for most
    // often. The sentence has to name the line.
    match refused {
        Err(ApiError::BadSpan { reason }) => assert!(
            reason.contains("request"),
            "refused, but for the wrong reason: «{reason}»"
        ),
        other => panic!("a selection across the request line answered {other:?}"),
    }
}

/// **A column act in the request is refused by name.** A request has no
/// columns; doing the document's thing silently would be «one answer
/// answering another kind's question».
#[test]
fn a_column_act_in_the_request_is_refused_by_name() {
    let _g = serial();
    fresh_vault("column");
    let s = ready(true);
    let span = span_of("Rückruf", true);
    let refused = protect_cell_in_lines(s, span, 0, 1, Scope::Conversation, Kind::Person);
    // The reason again, for the same reason.
    match refused {
        Err(ApiError::BadSpan { reason }) => assert!(
            reason.contains("column") || reason.contains("request"),
            "refused, but for the wrong reason: «{reason}»"
        ),
        other => panic!("a column act in the request answered {other:?}"),
    }
}

// ------------------------------------------------- 3 · with no document at all

/// **The request is the whole original** — rule 72's surface, where the entered
/// text is the request and its offsets start at zero.
#[test]
fn with_no_document_the_request_is_the_whole_original() {
    let _g = serial();
    fresh_vault("alone");
    let s = ready(false);
    let outcome = protect(s, span_of("Rückruf", false), Scope::Conversation, Kind::Person)
        .expect("the hand's own door, with no document under it");
    assert!(
        matches!(outcome, ProtectOutcome::Applied { .. }),
        "the hand's press on a question-only surface answered {outcome:?}"
    );
    let left = what_leaves(s);
    assert!(
        !left.contains("Rückruf"),
        "the word the hand covered left the machine: {left}"
    );
    assert!(
        !left.contains("Müller"),
        "the scan's own finding in the request left the machine: {left}"
    );
}

// ------------------------------------------------------- 4 · what e2 draws

/// **The snapshot hands the one text, its request's own start, and the marks
/// of both halves in that one space** — the contract the glass draws from, so
/// that no screen works out where the request begins for itself.
#[test]
fn the_snapshot_hands_the_one_text_with_the_requests_own_start() {
    let _g = serial();
    fresh_vault("snapshot");
    let s = ready(true);
    // **One cover in each half, both by hand** — and the document's is by hand
    // on purpose: this fixture is read with the German pack, which does not
    // know the English label «Prepared by:», so a test that expected the scan
    // to cover the document here would have been measuring a premise the
    // fixture does not hold. Said out loud, because the first version of this
    // test did exactly that.
    protect(s, span_of("Palmgren", true), Scope::Conversation, Kind::Person)
        .expect("the hand, in the document");
    protect(s, span_of("Rückruf", true), Scope::Conversation, Kind::Person)
        .expect("the hand, in the request");
    let snap = workspace_snapshot(s).expect("the one read the screen draws");
    let entered = snap.entered;
    assert_eq!(
        entered.text,
        format!("{DOC}{THE_LINE}{REQUEST}"),
        "the one text is not the document, the line and the request"
    );
    let begins = entered.request_begins as usize;
    let units: Vec<u16> = entered.text.encode_utf16().collect();
    assert_eq!(
        String::from_utf16_lossy(&units[begins..]),
        REQUEST,
        "the request does not begin where the snapshot says it does"
    );
    // A mark from each half, in the one space: the document's name and the
    // word the hand covered in the request.
    let word_of = |m: &Mark| {
        String::from_utf16_lossy(&units[m.span.start as usize..m.span.end as usize])
    };
    let words: Vec<String> = entered.marks.iter().map(word_of).collect();
    assert!(
        words.iter().any(|w| w == "Rückruf"),
        "the request's own cover is not in the marks: {words:?}"
    );
    assert!(
        words.iter().any(|w| w == "Palmgren"),
        "the document's own cover is not in the marks: {words:?}"
    );
    assert!(
        entered.marks.iter().any(|m| (m.span.start as usize) < begins),
        "no mark of the document's half: {words:?}"
    );
    assert!(
        entered.marks.iter().any(|m| (m.span.start as usize) >= begins),
        "no mark of the request's half: {words:?}"
    );
}

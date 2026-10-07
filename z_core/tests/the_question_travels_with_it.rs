// 046/N, second half · the question is in the column that says what leaves.
//
// **The decision, and the invariant it rests on** (the lead, 8 October): the
// promise is that the **left** column is the document byte for byte. The right
// column means **everything that leaves**. So a question that leaves and is not
// in that column makes the column a lie — the one shape this whole round has
// been spent removing, a screen claiming less than the engine does.
//
// The first half of 046/N put the protection in `ask_model`, which was the
// promise. This half puts the question where a person can **read** it before
// pressing anything.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough to ask something";
const DOC: &str = "Payroll run, February\nPrepared by: Hedvig Palmgren\nAmount: 42 500\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-asks-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");
}

/// A document with everything answered — the state a person is in when they
/// would type a question.
fn ready(pack: &str) -> SessionId {
    let s = open_session(None, pack.to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    s
}

/// What the Safe column shows, which is the same string that would be sent.
fn leaving(s: SessionId) -> String {
    payload_view(build_payload(s).expect("payload")).expect("view").text
}

// ------------------------------------------------------- 1 · it is in there

/// **The measurement the lead asked for: read the question in that column.**
#[test]
fn the_safe_column_shows_the_question() {
    let _g = serial();
    fresh_vault("shows");
    let s = ready("en");
    let before = leaving(s);
    assert!(!before.contains("--- Request ---"), "a request appeared before one was asked");

    set_question(s, "Organise these records and tell me where the problem is.".to_string())
        .expect("question");
    let after = leaving(s);

    assert!(
        after.contains("--- Request ---"),
        "the question is not in the column that says what leaves: {after:?}"
    );
    assert!(after.contains("Organise these records"), "{after:?}");
    // The document is still all of itself, and the question is after it.
    assert!(after.starts_with(&before), "the question moved the document: {after:?}");
    close_session(s).ok();
}

/// **And a name typed into it is a token there, the document's own token.**
///
/// This is the whole of why the question belongs in this column rather than
/// beside it: a person has to be able to see that what they typed was
/// protected, before anything is pressed.
#[test]
fn a_name_in_the_question_reads_as_a_token_in_that_column() {
    let _g = serial();
    fresh_vault("token");
    let s = ready("en");
    let document_token = leaving(s)
        .split_whitespace()
        .find(|w| w.starts_with("__Z_"))
        .expect("the document protected her")
        .to_string();

    let view = set_question(s, "What did Hedvig Palmgren earn?".to_string()).expect("question");
    assert!(
        !view.text.contains("Hedvig Palmgren"),
        "the question's own view shows the name in the clear: {:?}",
        view.text
    );
    assert_eq!(view.marks.len(), 1, "the field has nothing to draw: {:?}", view.marks);
    assert_eq!(view.marks[0].kind, Kind::Person);

    let after = leaving(s);
    assert!(!after.contains("Hedvig Palmgren"), "{after:?}");
    assert!(
        after.contains(&document_token),
        "the question used a second token for one person: {after:?}"
    );
    close_session(s).ok();
}

/// A question makes a payload built before it **stale**, because the Safe
/// column must not show yesterday's request and a handle from before it must
/// not be sendable.
#[test]
fn a_payload_built_before_the_question_is_stale() {
    let _g = serial();
    fresh_vault("stale");
    let s = ready("en");
    let old = build_payload(s).expect("payload");
    set_question(s, "Summarise it.".to_string()).expect("question");
    match payload_view(old) {
        Err(ApiError::StalePayload { .. }) => {}
        other => panic!("a payload from before the question is still readable: {other:?}"),
    }
    close_session(s).ok();
}

// ---------------------------------------------------------- 2 · and the rest

/// **Asking again replaces the question**, and nothing accumulates: a
/// conversation of several turns is not here yet, and `history` with roles
/// stays the debt it has been since Phase 4.
#[test]
fn a_second_question_replaces_the_first() {
    let _g = serial();
    fresh_vault("second");
    let s = ready("en");
    set_question(s, "First question.".to_string()).expect("one");
    set_question(s, "Second question.".to_string()).expect("two");
    let after = leaving(s);
    assert!(after.contains("Second question."), "{after:?}");
    assert!(!after.contains("First question."), "the questions piled up: {after:?}");
    assert_eq!(
        after.matches("--- Request ---").count(),
        1,
        "two requests in one payload: {after:?}"
    );
    close_session(s).ok();
}

/// **An empty question leaves no trace at all**, and nothing of our own
/// invention is put in its place.
#[test]
fn no_question_adds_nothing() {
    let _g = serial();
    fresh_vault("empty");
    let s = ready("en");
    let bare = leaving(s);
    set_question(s, "   ".to_string()).expect("blank");
    assert_eq!(leaving(s), bare, "a blank question changed what leaves");
    close_session(s).ok();
}

/// And the answer is restored through the question's tokens: the model may
/// answer about the person the question named, and a person must read the name
/// back rather than the token.
#[test]
fn an_answer_about_the_question_is_restored() {
    let _g = serial();
    fresh_vault("restore");
    let s = ready("en");
    set_question(s, "Compare it with Contact person: Eleanor Whitfield.".to_string())
        .expect("question");
    let h = build_payload(s).expect("payload");
    let said = ask_model(h, ProviderId { id: "fake".to_string() }, None, Vec::new(), Vec::new())
        .expect("ask")
        .text;
    let answer = ingest_answer(h, said).expect("ingest");
    let back: String = restored_view(s, answer)
        .expect("restored")
        .into_iter()
        .map(|seg| seg.text)
        .collect();
    assert!(
        back.contains("Eleanor Whitfield"),
        "a token the question introduced was not restored: {back:?}"
    );
    close_session(s).ok();
}

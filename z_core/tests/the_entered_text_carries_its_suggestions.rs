// **The one text must be able to say «this word is waiting»** — the second
// seam of 096, measured A/B by e2 on `072ab1f` against its own head.
//
// Rule 72-ب made the first part draw `entered.marks` instead of
// `document.marks`, because the person types into one text and a screen that
// reads two would disagree with itself. But `EnteredText.marks` was built from
// `s.protections` and `s.question_protections` alone — **every one of them
// `Protected`** — while `document_view` builds its marks from the protections
// **and** the findings, where a `Suggested` one lives. So the moment the glass
// moved to the one text, every open suggestion fell off it: no word waiting to
// be pressed, no wavy line under anything the scan had offered. Five guards in
// three Dart files e2 never touched went red, and they are green on
// `072ab1f` — the halves each told the truth about themselves.
//
// **The law this file holds:** the first part is one read with no arithmetic of
// its own, so the contract has to carry everything it draws. Parity is the
// claim, not a list of states somebody remembered: for the document's half,
// what `entered.marks` says must be **what `document.marks` says**, word for
// word, state for state, in that order — both read out of one snapshot, so
// there is no second read to disagree with.
//
// **And the request's half, measured rather than assumed.** The paper asked
// for «the request's suggestions as `QuestionView.marks` has them». There are
// none, and the reason is in `protect_lines`: it mints a token for every cover
// it makes and pushes `MarkState::Protected`, the only state it can push, and
// `set_question` then drops any mark without a token. A request has no
// findings list at all. So the last test here holds that limit **on purpose**:
// the day a request can offer something, it reds and names this file.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a request";

/// **The letter the scan actually *offers* something in.** The first draft of
/// this file used the sibling's three-line payroll note, and its two red tests
/// were red for the wrong reason — «nothing is waiting in this document» —
/// because every cover that scan makes is `Auto`, which is `Protected` the
/// moment it is made. A guard needs an open suggestion to measure one, so the
/// document is the German letter whose bank name `the_box_and_the_bank_are_findings_too.rs`
/// measures at `MarkState::Suggested`.
const DOC: &str = include_str!("fixtures/Mahnung_Feldmann.txt");
const REQUEST: &str = "Herr Thomas Müller bittet um Rückruf";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-entered-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// **Nothing answered.** The state a person is in while the scan's offers are
/// still on the screen — which is the state the glass lost.
fn waiting() -> SessionId {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    set_question(s, REQUEST.to_string()).expect("the request");
    s
}

fn word(text: &str, span: Span) -> String {
    let units: Vec<u16> = text.encode_utf16().collect();
    String::from_utf16_lossy(units.get(span.start as usize..span.end as usize).unwrap_or_default())
}

/// (the characters, the state, whether it carries a token, where it sits) —
/// everything a mark says that the glass acts on.
///
/// **The place is in here since the `place` debt was paid.** It was left out
/// when this file was written — `document_view` filled `place` from
/// `s.place_of(..)` and the one text carried `None` for every mark — and a
/// parity guard that compares three of four fields is a parity guard for three
/// fields. Review says «page 17» from this, so a screen reading the one text
/// could not say where anything was.
fn said(text: &str, m: &Mark) -> (String, MarkState, bool, Option<Place>) {
    (word(text, m.span), m.state, m.token.is_some(), m.place)
}

#[test]
fn the_one_text_says_everything_the_document_column_said() {
    let _g = serial();
    fresh_vault("parity");
    let s = waiting();
    let snap = workspace_snapshot(s).expect("snapshot");
    assert!(
        snap.open_suggestions > 0,
        "nothing is waiting in this document, so this file measures nothing"
    );

    let column: Vec<(String, MarkState, bool, Option<Place>)> =
        snap.document.marks.iter().map(|m| said(&snap.document.text, m)).collect();
    // **And the places exist to be compared.** Without this the comparison
    // below passes with `None` on both sides and proves nothing — the shape
    // that made the first draft of this file red for the wrong reason.
    assert!(
        column.iter().any(|(_, _, _, place)| place.is_some()),
        "no mark in the document column sits anywhere, so comparing places measures nothing: {column:?}"
    );
    let begins = snap.entered.request_begins;
    let one_text: Vec<(String, MarkState, bool, Option<Place>)> = snap
        .entered
        .marks
        .iter()
        .filter(|m| m.span.start < begins)
        .map(|m| said(&snap.entered.text, m))
        .collect();
    assert_eq!(
        one_text, column,
        "the one text does not say what the document column says, and the first \
         part draws the one text: a word nobody can press is a word nobody can \
         protect"
    );
}

#[test]
fn a_waiting_word_is_waiting_in_the_one_text_too() {
    let _g = serial();
    fresh_vault("waiting");
    let s = waiting();
    let snap = workspace_snapshot(s).expect("snapshot");

    let waiting_in_the_column: Vec<String> = snap
        .document
        .marks
        .iter()
        .filter(|m| m.state == MarkState::Suggested)
        .map(|m| word(&snap.document.text, m.span))
        .collect();
    assert!(
        !waiting_in_the_column.is_empty(),
        "the document column offers nothing, so this test measures nothing"
    );
    let waiting_in_the_one_text: Vec<String> = snap
        .entered
        .marks
        .iter()
        .filter(|m| m.state == MarkState::Suggested)
        .map(|m| word(&snap.entered.text, m.span))
        .collect();
    assert_eq!(
        waiting_in_the_one_text, waiting_in_the_column,
        "«{waiting_in_the_column:?}» is waiting in the document and «{waiting_in_the_one_text:?}» \
         in the one text the person reads"
    );
    // And it is waiting rather than half-protected: no token, because nothing
    // has been minted for a word nobody has answered.
    for m in snap.entered.marks.iter().filter(|m| m.state == MarkState::Suggested) {
        assert!(
            m.token.is_none(),
            "a waiting word carries a token «{:?}» — nothing was minted for it",
            m.token
        );
    }
}

#[test]
fn a_cover_in_the_request_is_still_in_the_one_text() {
    let _g = serial();
    fresh_vault("request");
    let s = waiting();
    let snap = workspace_snapshot(s).expect("snapshot");

    let begins = snap.entered.request_begins;
    let in_the_request: Vec<(String, MarkState, bool, Option<Place>)> = snap
        .entered
        .marks
        .iter()
        .filter(|m| m.span.start >= begins)
        .map(|m| said(&snap.entered.text, m))
        .collect();
    assert!(
        !in_the_request.is_empty(),
        "the request holds a name the scan covers and the one text says nothing about it"
    );
    assert!(
        in_the_request.iter().all(|(_, state, token, _)| *state == MarkState::Protected && *token),
        "a cover in the request is not protected with a token: {in_the_request:?}"
    );
    // **And it sits nowhere, because a request has no pages.** `place_of`
    // answers from the document's own page and paragraph table, and the
    // request was typed into a box — so `None` here is the truth and not a
    // field nobody filled. Held so that filling the document's places does not
    // quietly give the request a page it does not have.
    assert!(
        in_the_request.iter().all(|(_, _, _, place)| place.is_none()),
        "a cover in the request claims a page: {in_the_request:?}"
    );
}

/// **The limit, pinned on purpose.** A request cannot offer anything today:
/// `protect_lines` pushes the one state it can push and mints a token for
/// every cover, `set_question` drops a mark without one, and there is no
/// findings list for a request. The day that changes this test reds, and the
/// snapshot's request half is where the fix belongs.
#[test]
fn a_request_offers_nothing_yet_and_this_is_where_that_is_written() {
    let _g = serial();
    fresh_vault("limit");
    let s = waiting();
    let snap = workspace_snapshot(s).expect("snapshot");

    let begins = snap.entered.request_begins;
    let waiting_there: Vec<String> = snap
        .entered
        .marks
        .iter()
        .filter(|m| m.span.start >= begins && m.state == MarkState::Suggested)
        .map(|m| word(&snap.entered.text, m.span))
        .collect();
    assert!(
        waiting_there.is_empty(),
        "a request offers «{waiting_there:?}» now — good, and this is the test to \
         rewrite: the one text must carry it, and `QuestionView.marks` is where \
         the glass would read it from"
    );
}

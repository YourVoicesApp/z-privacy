// **A question alone leaves by every door** — 091, rules 72 and 72-أ.
//
// The chat box is there from the first moment, with no document in the app at
// all (rule 72), and a person pastes a letter into it (72-أ: one box, and what
// is pasted leaves by the same road as anything else). Measured by e2 on
// `8510d82`: on that surface «Choose who answers» worked and the two manual
// doors were dead.
//
// **Why they were dead.** `build_payload` refused `NothingToSend` on an empty
// *document*, and the manual doors are the readers of `build_payload`:
// «Copy Protected», «Save as PDF» and the pull all end at
// `payload_to_take_out`, which asks it. The model door did not, because it
// asks `build_the_question_alone` — so one surface had one door open out of
// four, and which door a person found open depended on which builder the press
// happened to use.
//
// **The ruling: one law for the four doors.** When the document is empty and a
// question stands, the payload **is** the question alone, whichever door asks
// for it; `NothingToSend` keeps its meaning for the case of nothing at all.
// One function answers «what would leave this bench» and every door asks that
// one function, because a law written at one door out of several is the trap
// this house pays for most often.
//
// The second item is the panel: the snapshot's token list came from the
// document's protections only, so the blocks the question itself made were
// invisible (`payload=false · tokens=0 · marks=2`) and the Tokens panel was a
// dead press on the one surface where those blocks are all there are. They are
// counted now, from the tokens `set_question` wrote when it protected the
// words — never from a second scan, which would be a second standard for the
// same text.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a question alone";

/// What a person pastes: the lead's own German letter, which is in this tree
/// already. It carries two people, an account and a BIC, so «protected» here
/// is a measurement and not a hope.
const LETTER: &str = include_str!("fixtures/Mahnung_Keller.txt");

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-alone-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");
}

/// **A bench with no document in it at all** — the first moment of rule 72.
///
/// Said out loud because every claim in this file depends on it: nothing is
/// imported, so `document_view` is empty and there is no preview to take out.
/// What stands is whatever the person typed or pasted into the box.
fn an_empty_bench() -> SessionId {
    let s = open_session(None, "de".to_string()).expect("open");
    assert!(
        document_view(s).expect("the document").text.is_empty(),
        "this fixture is about a bench with no document, and this one has one"
    );
    s
}

/// The letter pasted into the box, protected by the one door that protects a
/// question — and a control that it really did protect somebody, so that no
/// claim below is made about text that never had a name in it.
fn pasted(s: SessionId) {
    let view = set_question(s, LETTER.to_string()).expect("the paste");
    assert!(
        view.marks.len() >= 4,
        "the paste protected {} things, so nothing below would measure a protected text",
        view.marks.len()
    );
    assert_eq!(
        list_findings(s).expect("findings").iter().filter(|f| f.state == MarkState::Suggested).count(),
        0,
        "a question opens no review queue of its own (046/N), so no door below is refused by C3"
    );
}

/// The text with our own tokens taken out of it, so that no claim about a word
/// standing in the clear is answered by the token that protects it.
fn in_the_clear(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    while let Some(at) = rest.find("__Z_") {
        out.push_str(&rest[..at]);
        let tail = &rest[at + 4..];
        match tail.find("__") {
            Some(end) => rest = &tail[end + 2..],
            None => {
                rest = tail;
                break;
            }
        }
    }
    out.push_str(rest);
    out
}

// ------------------------------------------------------- 1 · the manual doors

/// **«Copy Protected» on a question-only surface.** The door the clipboard and
/// the pull both end at hands back the protected text, with no document in the
/// app at all.
#[test]
fn a_pasted_letter_with_no_document_leaves_by_the_manual_door() {
    let _g = serial();
    fresh_vault("copy");
    let s = an_empty_bench();
    pasted(s);
    let out = payload_to_take_out(s).expect("the copy door");
    let clear = in_the_clear(&out.text);
    assert!(
        !clear.contains("Stefan Keller") && !clear.contains("Beate Hoffmann"),
        "a name left the machine in the clear: {clear}"
    );
    assert!(
        !clear.contains("DE89"),
        "the account left the machine in the clear: {clear}"
    );
    assert!(
        out.protected_count >= 4,
        "the text that left carried {} protections",
        out.protected_count
    );
}

/// **«Save as PDF» on the same surface.** The press refuses by its own words
/// («its answer page had no token») unless the view carries the token the
/// export door mints — 079 — so the core's half of «a z-pdf that reads back»
/// is that the token is there. It was minted only for a document before this
/// round, which is exactly how the press came to be dead here.
#[test]
fn the_pdf_door_mints_its_answer_page_for_a_question_alone() {
    let _g = serial();
    fresh_vault("pdf");
    let s = an_empty_bench();
    pasted(s);
    let out = payload_to_take_out(s).expect("the export door");
    assert!(
        out.answer_page_token.is_some(),
        "no answer-page token, so the PDF press writes nothing and says so"
    );
    let token = out.answer_page_token.unwrap_or_default();
    assert!(
        !in_the_clear(&token).contains("Zprivacy"),
        "the answer page's own word must leave as a token, not as itself: {token}"
    );
}

/// **The model door, which already worked, still works** — a guard that would
/// otherwise be the easiest thing to break while making the other three open:
/// the question alone is what travels, and the echo provider answers it.
#[test]
fn the_model_door_still_takes_the_question_alone() {
    let _g = serial();
    fresh_vault("model");
    let s = an_empty_bench();
    pasted(s);
    let handle = build_payload(s).expect("the send door's own builder");
    let answer = ask_model(
        handle,
        ProviderId { id: "fake".to_string() },
        None,
        Vec::new(),
    )
    .expect("the model door");
    assert!(!answer.text.is_empty(), "the echo provider answered nothing");
}

/// **And `NothingToSend` keeps its meaning.** An empty box with no document is
/// nothing at all, at every door, named rather than silently empty — and the
/// export door mints nothing on its way to refusing (079: a refused exit
/// prints no page).
#[test]
fn an_empty_box_with_no_document_still_refuses_by_name() {
    let _g = serial();
    fresh_vault("empty");
    let s = an_empty_bench();
    assert!(
        matches!(build_payload(s), Err(ApiError::NothingToSend)),
        "an empty bench must refuse by name: {:?}",
        build_payload(s).map(|_| "a payload")
    );
    assert!(
        matches!(payload_to_take_out(s), Err(ApiError::NothingToSend)),
        "the manual door must refuse by the same name"
    );
    assert!(
        list_tokens(s).expect("tokens").is_empty(),
        "a refused export minted something: {:?}",
        list_tokens(s).map(|t| t.len())
    );
    // A question of pure whitespace is nothing too: the refusal is about what
    // would leave, not about whether a field was touched.
    set_question(s, "   \n  ".to_string()).expect("a blank question");
    assert!(
        matches!(build_payload(s), Err(ApiError::NothingToSend)),
        "whitespace is nothing to send"
    );
}

// ------------------------------------------------------------- 2 · the panel

/// **The blocks a question made are on the surface where they are all there
/// is.** e2's measurement was `payload=false · tokens=0 · marks=2`: the panel
/// counted the document's protections, and there was no document.
#[test]
fn the_blocks_a_question_made_are_counted_on_its_own_surface() {
    let _g = serial();
    fresh_vault("panel");
    let s = an_empty_bench();
    pasted(s);
    let rows = list_tokens(s).expect("the panel's own list");
    assert!(
        rows.len() >= 4,
        "the panel shows {} of the blocks this paste made",
        rows.len()
    );
    let snapshot = workspace_snapshot(s).expect("the one read the screen draws");
    assert_eq!(
        snapshot.token_count as usize,
        rows.len(),
        "the count and the list are two answers to one question"
    );
    assert!(
        snapshot.payload.is_some(),
        "the Safe column has nothing to draw on a surface that is about to send"
    );
    // **From the tokens `set_question` wrote, not from a second scan.** Every
    // row is a block of a value this paste protected: a row the panel shows
    // must be revealable, which is the whole of what the press does.
    for row in &rows {
        reveal(s, row.token.clone()).expect("the panel's press");
    }
}

/// **And a block of the document is still a block of the document.** The law
/// above is about the surface where the question is all there is; a bench with
/// a document in it answers exactly as it did before, which is what keeps this
/// from being a second standard for the same panel.
#[test]
fn a_document_on_the_bench_still_answers_for_its_own_blocks() {
    let _g = serial();
    fresh_vault("both");
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, LETTER.to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    let of_the_document = list_tokens(s).expect("tokens").len();
    assert!(of_the_document >= 4, "the document protected {of_the_document} things");
    set_question(s, "Was schuldet er?".to_string()).expect("a question about it");
    assert_eq!(
        list_tokens(s).expect("tokens").len(),
        of_the_document,
        "a question about a document may not change what the document's own panel shows"
    );
}

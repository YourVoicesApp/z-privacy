// Paper 123 §2.2 and §2.4, rules 87 (أ) and 87 (د) · **the trial's chat, as in
// the app**.
//
// The lead's ruling of 14 November: what a person carries to their own model
// at turn two and after is **exactly what `ask_model` hands the gateway** — the
// one exchange before, built by `the_chat_so_far`, then the question alone —
// from the same builders, and no wider. This file holds the two equal over a
// three-turn chat, with the echo provider, which repeats what it was told.
//
// And «Start over» (`web::close`): the bench and the session it writes into go
// together, a later call is refused by name, and none of its tokens restores.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for the trial's chat";

/// Invented.
const DOC: &str = "Payroll run, February\nPrepared by: Hedvig Palmgren\nContact: hedvig.palmgren@example.com\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-trial-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");
    dir
}

fn gone(dir: std::path::PathBuf) {
    let _ = vault_lock();
    if dir.starts_with(std::env::temp_dir()) {
        let _ = std::fs::remove_dir_all(&dir);
    }
}

fn ready() -> SessionId {
    let bench = open_session(None, "en".to_string()).expect("open");
    import_text(bench, DOC.to_string()).expect("import");
    for f in list_findings(bench).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(bench, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    bench
}

/// The echo's answer, split into what it was told: the instructions and the
/// payload. Read from the **last** marker of the echo's own frame, because a
/// history from the third turn on holds an earlier echo inside it.
fn told(said: &str) -> (String, String) {
    const FRAME: &str = "]\nVerstanden. Ihr Text lautet:\n";
    let instructions = said
        .strip_prefix("[instructions: ")
        .and_then(|rest| rest.rsplit_once(FRAME).map(|(i, _)| i.to_string()))
        .unwrap_or_default();
    let payload = said
        .rsplit_once(FRAME)
        .map_or(said, |(_, p)| p)
        .strip_suffix("\n— Ende der Antwort.")
        .unwrap_or_default()
        .to_string();
    (instructions, payload)
}

fn ask_alone(bench: SessionId) -> String {
    let handle = build_the_question_alone(bench).expect("the question alone");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new()).expect("ask").text
}

#[test]
fn the_trials_take_out_is_what_the_model_is_handed() {
    let _g = serial();
    let dir = fresh_vault("handed");
    let bench = ready();
    // Turn one leaves with its document, as the trial's first copy does.
    let first = build_payload(bench).expect("build");
    ask_model(first, ProviderId { id: "fake".to_string() }, None, Vec::new()).expect("turn one");

    for (turn, question) in [
        (2, "And what does Hedvig Palmgren earn?"),
        (3, "Write to hedvig.palmgren@example.com about it."),
    ] {
        set_question(bench, question.to_string()).expect("question");
        let out = z_core::web::question_to_take_out(bench).expect("take out");
        let said = ask_alone(bench);
        let (instructions, payload) = told(&said);
        assert!(!instructions.is_empty(), "turn {turn}: the model was handed no history");
        assert_eq!(
            out.text,
            format!("{instructions}\n\n{payload}"),
            "turn {turn}: the take-out is not what ask_model handed the gateway"
        );
        assert!(!out.text.contains("Hedvig Palmgren"), "turn {turn}: a name left in the clear");
        // The take-out's own payload is the question alone, as the model's was.
        assert_eq!(payload_view(out.handle).expect("view").text, payload);
    }
    close_session(bench).ok();
    gone(dir);
}

/// The answer pasted against the take-out's handle restores every name the
/// chat carried, and its turn keeps its question.
#[test]
fn an_answer_against_the_take_out_restores_and_keeps_its_question() {
    let _g = serial();
    let dir = fresh_vault("keeps");
    let bench = ready();
    let first = build_payload(bench).expect("build");
    let carried = payload_view(first).expect("view").text;
    ingest_answer(first, format!("Noted: {carried}")).expect("turn one");
    set_question(bench, "Is the address hedvig.palmgren@example.com right?".to_string()).expect("question");
    let out = z_core::web::question_to_take_out(bench).expect("take out");
    // The answer names a token born in turn one, not in this question.
    let answer = ingest_answer(out.handle, format!("Yes. {carried}")).expect("ingest");
    let restored: String = restored_view(bench, answer).expect("restored").iter().map(|s| s.text.as_str()).collect();
    assert!(restored.contains("Hedvig Palmgren"), "a name the chat carried came home as a code");
    let number = conversation_open().expect("open").expect("a session");
    let turns = conversation_turns(number, Some(bench)).expect("turns");
    assert_eq!(turns.len(), 2, "two exchanges, two turns");
    assert!(
        turns[1].question_as_it_left.contains("Is the address"),
        "the second turn lost its question"
    );
    close_session(bench).ok();
    gone(dir);
}

/// **Start over**: everything of the bench is refused by name afterwards, and
/// none of its tokens restores on the bench that comes next.
#[test]
fn start_over_forgets_the_bench_and_its_session() {
    let _g = serial();
    let dir = fresh_vault("over");
    let bench = ready();
    let first = build_payload(bench).expect("build");
    let carried = payload_view(first).expect("view").text;
    let answer = ingest_answer(first, carried.clone()).expect("turn one");
    let number = conversation_open().expect("open").expect("a session");

    z_core::web::close(bench).expect("close");
    assert_eq!(document_view(bench).err(), Some(ApiError::InvalidSession));
    assert_eq!(restored_view(bench, answer).err(), Some(ApiError::InvalidSession));
    assert_eq!(ingest_answer(first, carried.clone()).err(), Some(ApiError::InvalidSession));
    assert_eq!(z_core::web::close(bench).err(), Some(ApiError::InvalidSession));
    assert_eq!(conversation_open().expect("open"), None, "the session is still open");
    assert!(conversations().expect("rows").iter().all(|r| r.number != number), "the session is still listed");

    // The next text is a new bench; the old codes pasted into it stay codes.
    let next = ready();
    let payload = build_payload(next).expect("build");
    let id = ingest_answer(payload, carried.clone()).expect("ingest");
    let segments = restored_view(next, id).expect("restored");
    let text: String = segments.iter().map(|s| s.text.as_str()).collect();
    assert!(!text.contains("Hedvig Palmgren"), "an old token restored after Start over");
    assert!(segments.iter().any(|s| s.piece == Piece::Unresolved), "the old codes were not reported");
    close_session(next).ok();
    gone(dir);
}

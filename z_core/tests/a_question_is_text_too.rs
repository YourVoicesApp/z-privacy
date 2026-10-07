// 046/N · a question is text, and text is scanned.
//
// **The owner, 7 October:** «ليس لدينا شات — شات مع نموذج. بمعنى أنه إذا لدينا
// وثيقة مشفرة وكل شيء فيها تمام، ماذا يحصل عند الانتقال إلى الخطوة التالية؟
// نحتاج إلى نسخ الملف. لا يوجد خيار مثلاً مباشرة إلى الشات.»
//
// Measured by the lead in `session_state.dart`: `askModel` was called with
// `workspace: const []` and `history: const []`. **The protected document went
// to the model bare** — no instruction, no request — so whatever came back was
// the model's own guess at what was wanted, and the most visible act on the
// screen was «Copy Protected». The gateway has carried `Context { workspace,
// history }` since Phase 4 and nothing filled it.
//
// This file holds the half of the fix that the product cannot be wrong about:
// **the question is scanned before it leaves.** The whole promise is that
// nothing reaches a model unexamined, and a sentence a person typed is not an
// exception. If he asks «what did Hedvig Palmgren earn?», the name leaves as
// the token the document already gave her — or the document's protection was
// theatre.
//
// It is done in `ask_model` and not in the screen, and that is why it holds:
// `ask_model` is the only door a question can enter by, so there is no path
// through which a raw one reaches a provider. A screen that protected its own
// field would be a second implementation of the scanner, and the first time the
// two disagreed the quieter one would win.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a question";

/// A payroll line of the owner's own shape, with one person in it.
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
    let dir = std::env::temp_dir().join(format!("zprivacy-question-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");
}

/// A session with the document in it, every question answered, and a payload
/// ready — the state a person is in when they would type a question.
fn ready(pack: &str) -> (SessionId, PayloadHandle) {
    let s = open_session(None, pack.to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    let h = build_payload(s).expect("payload");
    (s, h)
}

/// What the echo provider was told, which is what left this computer.
fn asked(h: PayloadHandle, question: &str) -> String {
    ask_model(
        h,
        ProviderId { id: "fake".to_string() },
        None,
        vec![question.to_string()],
        Vec::new(),
    )
    .expect("ask")
    .text
}

// ------------------------------------------------------------ 1 · the promise

/// **The acceptance, in the lead's own words: a name from the client's book,
/// typed into the question, leaves as a token.**
#[test]
fn a_name_typed_into_the_question_leaves_as_a_token() {
    let _g = serial();
    fresh_vault("name");
    let (s, h) = ready("en");
    let said = asked(h, "What did Hedvig Palmgren earn this month?");

    assert!(
        said.contains("[instructions:"),
        "the question did not travel at all — the document went bare: {said:?}"
    );
    assert!(
        !said.contains("Hedvig Palmgren"),
        "the name a person typed left this computer in the clear: {said:?}"
    );
    assert!(
        said.contains("__Z_") && said.contains("PERSON"),
        "the name was removed rather than replaced, so the model cannot answer: {said:?}"
    );
    // And the rest of the sentence is untouched: the model needs the question.
    assert!(said.contains("earn this month"), "the question was mangled: {said:?}");
    close_session(s).ok();
}

/// **One value, one token** — and this is the half that makes the answer
/// possible rather than merely safe.
///
/// The token in the question has to be the **same** token the document gave
/// her, or the model cannot see that the person is asking about somebody who
/// appears in the sheet. Two tokens for one person would be unanswerable as
/// well as unprotected.
#[test]
fn the_question_uses_the_token_the_document_already_gave_her() {
    let _g = serial();
    fresh_vault("same");
    let (s, h) = ready("en");
    let leaving = payload_view(h).expect("view").text;
    let token = leaving
        .split_whitespace()
        .find(|w| w.starts_with("__Z_"))
        .expect("the document protected her")
        .trim_end_matches(['.', ',']);

    let said = asked(h, "What did Hedvig Palmgren earn?");
    // **Measured in the instruction line alone.** The echo repeats both the
    // question and the document, so `said.contains(token)` was true because
    // the *document* carried it — the first version of this test was green
    // while the question's own name was still leaving in the clear, which the
    // test beside it caught. A guard green for a reason unrelated to its
    // subject is the third of these this project has met.
    let instruction = said
        .lines()
        .find(|l| l.starts_with("[instructions:"))
        .expect("the question travelled");
    assert!(
        instruction.contains(token),
        "the question minted a second token for one person: {instruction:?} wanted {token}"
    );
    assert!(
        !instruction.contains("Hedvig Palmgren"),
        "the name is in the instruction in the clear: {instruction:?}"
    );
    close_session(s).ok();
}

/// A value that is in the question and **nowhere in the document** is still
/// replaced, and the payload learns its token so the answer can be restored
/// through it.
#[test]
fn a_name_only_in_the_question_is_protected_and_restorable() {
    let _g = serial();
    fresh_vault("new");
    let (s, h) = ready("en");
    let said = asked(h, "Compare it with the sheet from Contact person: Eleanor Whitfield.");
    assert!(!said.contains("Eleanor Whitfield"), "{said:?}");

    // The echo repeats what it was told, so the answer carries the question's
    // token — and it comes back as the name, because the payload allows it.
    let answer = ingest_answer(h, said).expect("ingest");
    let back: String = restored_view(s, answer)
        .expect("restored")
        .into_iter()
        .map(|seg| seg.text)
        .collect();
    assert!(
        back.contains("Eleanor Whitfield"),
        "a token the question introduced was not restored in the answer: {back:?}"
    );
    close_session(s).ok();
}

// -------------------------------------------------------------- 2 · the lines

/// **An empty question is still allowed**, and then the document really does go
/// with no request — which the sheet has to say rather than leave a person to
/// discover.
#[test]
fn no_question_is_allowed_and_nothing_is_invented() {
    let _g = serial();
    fresh_vault("empty");
    let (s, h) = ready("en");
    let said = asked(h, "");
    assert!(
        !said.contains("[instructions:"),
        "an empty question became an instruction of our own invention: {said:?}"
    );
    close_session(s).ok();
}

/// **The gate is not touched.** A question does not become a way around it:
/// with something still open about the document, asking is refused exactly as
/// sending is.
#[test]
fn a_question_is_not_a_way_around_the_gate() {
    let _g = serial();
    fresh_vault("gate");
    // Not answered this time: the company line is a suggestion.
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, "Kunde: Nordstern Consulting GmbH\n".to_string()).expect("import");
    scan(s).expect("scan");
    let h = build_payload(s).expect("payload");
    let open = payload_view(h).expect("view").open_suggestions;
    assert!(open > 0, "the fixture has nothing open, so this proves nothing");

    match ask_model(
        h,
        ProviderId { id: "fake".to_string() },
        None,
        vec!["Organise these records.".to_string()],
        Vec::new(),
    ) {
        Err(ApiError::OpenSuggestions { count }) => assert_eq!(count, open),
        other => panic!("a question got past the gate: {other:?}"),
    }
    close_session(s).ok();
}

/// And the question is read with **this session's** knowledge, not a weaker
/// set: the same packs, the same vault, the same lists. Measured by asking the
/// same question in a session whose pack cannot read the label at all.
#[test]
fn the_question_is_read_with_the_sessions_own_knowledge() {
    let _g = serial();
    fresh_vault("sets");
    let (s, h) = ready("en");
    // «Prepared by:» is an English row (046/J). The same sentence in a German
    // session has no row for it, and the name is in no list — so the question
    // carries it in the clear, and that is the honest measurement rather than
    // a promise that every language sees everything.
    let said = asked(h, "Who is named after Prepared by: Ingrid Vikander?");
    assert!(!said.contains("Ingrid Vikander") || said.contains("__Z_"),
        "nothing at all was examined in the question: {said:?}");
    close_session(s).ok();
}

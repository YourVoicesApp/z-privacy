// **The owner's first finding of 9 October, measured.**
//
// He sent a request through the key from inside Z — a provider connected, the
// send button on the review page — saw the session name suggested, read the
// answer that came back, and then opened the Sessions room. It said **«No
// sessions yet»**. Nothing was born and nothing was written: a conversation
// left the machine and the app kept no record that it had happened.
//
// 064 wired the two exits it was written for, Copy and the PDF. The send door
// is a third exit, and it was connected to neither half: no birth, and — the
// half this file measures — **no turn written even when a session was open**.
// Both protected doors (`send`, `ask_model`) end at `ingest_answer`, which read
// `open_conversation` only to stamp the answer record with it, and the direct
// door stored nothing at all by its own comment.
//
// The owner's standing rule, in his words: المحادثاتُ داخل التطبيق تُحفظ كاملةً
// في الجلسة — a conversation inside the app is kept whole in its session.
//
// What is measured here is the core's half: **a turn is written by the core, at
// the one place every answer arrives, and read back restored.** The birth is
// the shell's half (`monopeaks-5e`, `fix/the-third-exit`), and the guard that
// watches what truly left the machine is his too.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for the third exit";

/// One person in one payroll line — the owner's own document shape.
const DOC: &str = "Payroll run, February\nPrepared by: Hedvig Palmgren\nAmount: 42 500\n";
const NAME: &str = "Hedvig Palmgren";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-third-exit-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");
}

/// A bench with the document in it and every suggestion answered — the state a
/// person is in when they press Send.
fn bench() -> SessionId {
    // The English pack, because the document's label is English: measured, not
    // assumed — with the Swedish pack this document yields **zero** findings and
    // nothing is protected, so two guards below were failing on a document with
    // no tokens in it rather than on the defect.
    let s = open_session(None, "en".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    s
}

fn fake() -> ProviderId {
    ProviderId { id: "fake".to_string() }
}

/// Segments flattened, which is what a person would read on the screen.
fn read(segments: &[Segment]) -> String {
    segments.iter().map(|s| s.text.as_str()).collect()
}

/// The first token in a payload's safe text, found the way `restore` finds one.
///
/// By the marks and not by `split_whitespace`: a token stands where a name
/// stood, and a name is followed by a comma or a line ending as often as by a
/// space. Splitting on spaces made two guards below fail with «the payload
/// carries a token» — red, but for a reason that was mine and not the
/// product's, which is a red that proves nothing.
fn first_token(text: &str) -> String {
    let start = text.find("__Z_").expect("the payload carries a token");
    let after = start + "__Z_".len();
    let end = after + text[after..].find("__").expect("a token closes") + "__".len();
    text[start..end].to_string()
}

// ------------------------------------------------- 0 · the instrument itself

/// **The control for every test below: the reader can see a turn.**
///
/// Written with the door 064 shipped — `conversation_record` — and read back
/// through the new one. If this is green and the guards below are red, the
/// writer is silent; if this were red too, the reader would be broken and the
/// guards would prove nothing. An instrument is believed after it has been
/// watched to bite, never before.
#[test]
fn the_reader_sees_a_turn_the_old_door_wrote() {
    let _g = serial();
    fresh_vault("control");
    let b = bench();
    let row = conversation_begin("the control".to_string(), Some(b)).expect("begin");

    assert!(
        conversation_turns(row.number, Some(b)).expect("turns").is_empty(),
        "a session nobody has written to holds no turns, and that is not an error"
    );

    conversation_record("asked".to_string(), "answered".to_string()).expect("record");
    let turns = conversation_turns(row.number, Some(b)).expect("turns");
    assert_eq!(turns.len(), 1, "the reader did not see a turn the writer wrote");
    assert_eq!(read(&turns[0].question), "asked");
    assert_eq!(read(&turns[0].answer), "answered");
}

// ------------------------------------------------- 1 · the protected door

/// **The finding itself: a send through the key, with a session open, writes a
/// turn.**
///
/// Red before this branch: `ask_model` answered, `open_conversation` was set,
/// and the session's file stayed empty.
#[test]
fn a_question_sent_through_the_key_is_written_into_the_session() {
    let _g = serial();
    fresh_vault("protected");
    let b = bench();
    let row = conversation_begin("February payroll".to_string(), Some(b)).expect("begin");
    set_question(b, format!("What did {NAME} earn?")).expect("question");
    let h = build_payload(b).expect("payload");

    let said = ask_model(h, fake(), None, Vec::new(), Vec::new()).expect("ask");
    assert!(!said.text.is_empty(), "the echo answered nothing, so nothing is being measured");

    let turns = conversation_turns(row.number, Some(b)).expect("turns");
    assert_eq!(
        turns.len(),
        1,
        "a question went through the key and the session kept no record of it"
    );

    // **Restored on the way out of the file, which is the whole reason the read
    // goes through the core.** What is on disk is the protected form; what a
    // screen receives is the name, because the session's own store put it back.
    let answer = read(&turns[0].answer);
    assert!(
        answer.contains(NAME),
        "the stored answer did not restore to the name: {answer}"
    );
    assert!(
        !answer.contains("__Z_"),
        "a token reached the boundary unresolved, which is the lie 046/U ended: {answer}"
    );
    assert!(
        read(&turns[0].question).contains(NAME),
        "the question the person typed did not come back as they typed it"
    );
    assert!(
        turns[0].unresolved.is_empty(),
        "this session made every token in this turn, so none of them is unresolved"
    );
}

/// **The same door with nothing typed: an empty question is written, not
/// refused.**
///
/// A document may be sent with no question — that was 046/N's whole finding —
/// and refusing here would redden the very press the owner used this morning.
/// «Nothing was typed» and «something was lost» must not be spelled the same,
/// and they are not: the emptiness comes from the empty question itself.
#[test]
fn a_document_sent_with_no_question_still_leaves_a_turn() {
    let _g = serial();
    fresh_vault("no-question");
    let b = bench();
    let row = conversation_begin("no question".to_string(), Some(b)).expect("begin");
    let h = build_payload(b).expect("payload");

    ask_model(h, fake(), None, Vec::new(), Vec::new()).expect("ask");

    let turns = conversation_turns(row.number, Some(b)).expect("turns");
    assert_eq!(turns.len(), 1, "a document left and nothing was written");
    assert_eq!(read(&turns[0].question), "", "nothing was typed, so the question is empty");
    assert!(!read(&turns[0].answer).is_empty(), "the answer half is what did happen");
}

// ------------------------------------------------- 2 · the direct door

/// **Direct Mode is a conversation too.**
///
/// It stores no answer record — there is no payload to restore one against —
/// and that was read as «it keeps nothing», which is a different claim. What
/// left is exactly what is kept: the text as it stands, and nothing to put
/// back.
#[test]
fn the_direct_door_writes_what_it_sent_as_it_sent_it() {
    let _g = serial();
    fresh_vault("direct");
    let b = bench();
    let row = conversation_begin("as it stands".to_string(), Some(b)).expect("begin");
    // The «original text» choice lives on the screen, not in the contract: the
    // core's direct door takes the text and is the separation itself.

    ask_model_directly(b, DOC.to_string(), fake(), None, Vec::new(), Vec::new()).expect("direct");

    let turns = conversation_turns(row.number, Some(b)).expect("turns");
    assert_eq!(turns.len(), 1, "a document left the machine as it stands and nothing was written");
    assert!(
        read(&turns[0].question).contains(NAME),
        "the direct door sent the name, so the record holds the name"
    );
    assert!(
        turns[0].unresolved.is_empty(),
        "nothing was protected, so there is nothing that failed to resolve"
    );
}

// ------------------------------------------------- 3 · the door from outside

/// **The half the owner's own division names: a question copied out, an answer
/// brought back.**
///
/// `ingest_answer` is the door the app's paste-back flow uses, and it is the
/// same choke point the two provider doors end at. One write serves all three,
/// which is why it was put there and not in `ask_model`.
#[test]
fn an_answer_brought_back_from_outside_is_written_too() {
    let _g = serial();
    fresh_vault("outside");
    let b = bench();
    let row = conversation_begin("copied out".to_string(), Some(b)).expect("begin");
    set_question(b, format!("Who prepared this? {NAME}")).expect("question");
    let h = build_payload(b).expect("payload");
    let token = first_token(&payload_view(h).expect("view").text);

    ingest_answer(h, format!("{token} prepared it.")).expect("ingest");

    let turns = conversation_turns(row.number, Some(b)).expect("turns");
    assert_eq!(turns.len(), 1, "an answer came back from outside and nothing was written");
    assert!(
        read(&turns[0].answer).contains(NAME),
        "the brought-back answer did not restore from the file"
    );
}

// ------------------------------------------------- 4 · G9 in a stored turn

/// **A token from somewhere else is not restored out of a session's file.**
///
/// This is why a turn carries the list of tokens its payload was allowed to
/// hold. Restoring a stored turn against everything the session ever minted
/// would be invariant G9 traded for a field, and the owner has already met what
/// that costs: an answer from another conversation reading like the model's own
/// sentence with a stranger's token in the middle of it.
#[test]
fn a_stored_turn_restores_only_what_its_payload_carried() {
    let _g = serial();
    fresh_vault("g9");
    let b = bench();
    let row = conversation_begin("not ours".to_string(), Some(b)).expect("begin");
    let h = build_payload(b).expect("payload");
    let ours = first_token(&payload_view(h).expect("view").text);
    const STRANGER: &str = "__Z_5CDD_IBAN_5B32__";

    ingest_answer(h, format!("{ours} and {STRANGER} both.")).expect("ingest");

    let turns = conversation_turns(row.number, Some(b)).expect("turns");
    assert_eq!(turns.len(), 1);
    let text = read(&turns[0].answer);
    assert!(text.contains(NAME), "our own token must be restored: {text}");
    assert!(
        text.contains(STRANGER),
        "a stranger's token stays word for word, because the model really wrote it: {text}"
    );
    assert_eq!(
        turns[0].unresolved,
        vec![STRANGER.to_string()],
        "and it is named, not swallowed"
    );
    assert!(
        turns[0].answer.iter().any(|s| s.piece == Piece::Unresolved),
        "it is a piece of its own, so a screen can show it as what it is"
    );
}

/// **Read without the document that made it, a conversation resolves nothing —
/// and says so.**
///
/// The Sessions room may be opened with no document loaded. The honest answer
/// there is every token by name in `unresolved`, never the stored form printed
/// as though it were prose.
#[test]
fn a_session_read_without_a_bench_names_what_it_cannot_resolve() {
    let _g = serial();
    fresh_vault("no-bench");
    let b = bench();
    let row = conversation_begin("no bench".to_string(), Some(b)).expect("begin");
    let h = build_payload(b).expect("payload");
    ask_model(h, fake(), None, Vec::new(), Vec::new()).expect("ask");

    let turns = conversation_turns(row.number, None).expect("turns");
    assert_eq!(turns.len(), 1, "the turn is in the file either way");
    assert!(
        !turns[0].unresolved.is_empty(),
        "with no store nothing can be put back, and that is said rather than hidden"
    );
    assert!(
        !read(&turns[0].answer).contains(NAME),
        "no name may appear without the store that holds it"
    );
}

// ------------------------------------------------- 5 · the state that stays

/// **A send with no session open still succeeds, and writes nothing.**
///
/// **Ruled, 9 October: the core does not refuse.** A send with no session is an
/// honest state that stays. The deciding measurement was 5e's: the vault may be
/// locked, and a locked vault *cannot* give birth to a session — so a blanket
/// refusal would turn a state the screen reports truthfully («No session —
/// these names were made for this document alone») into a closed door at the
/// worst possible moment.
///
/// So the question is the boundary's work, asked at the two places the owner
/// named — the chat screen and the screen after the filter — and never forced
/// at the bottom. The same family as the 94 call sites that were measured
/// before enforcement was rejected there: fifty doors that open nothing.
///
/// This test therefore pins a ruling and not a convenience. Changing it means
/// the ruling changed.
#[test]
fn a_send_with_no_session_open_is_not_refused_today() {
    let _g = serial();
    fresh_vault("no-session");
    let b = bench();
    let h = build_payload(b).expect("payload");

    ask_model(h, fake(), None, Vec::new(), Vec::new()).expect("a send with no session still sends");

    assert_eq!(
        conversations().expect("rows").len(),
        0,
        "no session was open, so none was invented to write into"
    );
}

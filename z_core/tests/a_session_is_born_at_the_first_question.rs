// **A session is born at the first question that leaves with no document** —
// rule 55-و, the owner's «نعم» of 18 October 2026, beside rule 55: a session
// is born of the act that needs it, and the chat without a document is a whole
// session — its turns stored, the next question carrying the earlier ones
// (rule 67), «Copy the chat» working, and the session in the room under its
// name.
//
// **What was measured on `ef0bc89`, through the core's own doors**: a letter
// pasted into the box with no document, then an exit — and no session was
// born, so no turn was stored, the chat door refused `NothingToSend`, and a
// second question carried nothing. Rule 67 did not live on rule 72's surface.
//
// **And the honest other half of that measurement**: the *screen* begins a
// session of its own at an exit when none is open (`theChatAsks` →
// `beginSessionItNames`), so the product does remember. What was wrong was
// therefore not that the chat forgets but that the law lived in the screen —
// one birth with two causes, written twice, in two languages, and the quieter
// copy would have won the first time they disagreed. The ruling says the
// birth is the core's: **one birth, two causes, no second path.**
//
// So the birth here is the same function a document's is — `a_session_is_born`
// — reached by a second cause rather than a second path.
//
// **Where it had to go, and why that is not a detail.** A birth renames every
// token in the session to the session's own naming and clears every payload
// already built (064f, `names_again_from`). So it cannot live in a door that
// is *handed* a payload — `ask_model` and `send` would invalidate the very
// handle they were given — and it cannot live in the instrument the workspace
// snapshot draws the Safe column with, which runs on every read and would
// make a session out of a question nobody had sent. It lives where an exit
// builds: the copy/pull/PDF door, and the builder the model door asks. The
// screen's own comment says the same thing in its own words: the handle is
// built after the birth, never before it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a first question";

/// A letter pasted into the box — the lead's own, already in this tree.
const LETTER: &str = include_str!("fixtures/Mahnung_Keller.txt");

/// A question with one name in it, for the doors that do not need a whole
/// letter to prove anything.
const A_QUESTION: &str = "Was schuldet Herr Stefan Keller der Muster Handel GmbH?";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-born-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");
}

/// A bench with no document in it at all, and no session open — rule 72's
/// first moment, and the state every claim in this file is about.
///
/// The control is said out loud: if a session were already open, every «one
/// session» below would be measuring the wrong birth.
fn an_empty_bench() -> SessionId {
    let s = open_session(None, "de".to_string()).expect("open");
    assert!(
        document_view(s).expect("the document").text.is_empty(),
        "this file is about a bench with no document, and this one has one"
    );
    assert!(
        conversations().expect("the room").is_empty(),
        "a session was already open, so nothing below measures a birth"
    );
    s
}

/// What the person typed, through the one door that protects a question.
fn typed(s: SessionId, text: &str) {
    set_question(s, text.to_string()).expect("the question");
}

/// The same, for a first paste that **must** have had something to protect.
///
/// The control is here and not in `typed`, because a follow-up like «Und
/// wann?» has no name in it and protects nothing — a real state, and the
/// reason a blanket control would have measured the wrong thing. It is the
/// first paste that every claim about protected text below depends on.
fn pasted(s: SessionId, text: &str) {
    let view = set_question(s, text.to_string()).expect("the paste");
    assert!(
        !view.marks.is_empty(),
        "the paste protected nothing, so nothing below would measure a protected text"
    );
}

fn the_only_session() -> ConversationRow {
    let rows = conversations().expect("the room");
    assert_eq!(rows.len(), 1, "the room holds {} sessions, expected one", rows.len());
    rows.into_iter().next().expect("the one row")
}

// ------------------------------------------------- 1 · the birth at each exit

/// **The manual door.** A letter pasted in the box and taken out by the copy
/// door — the first exit of a question alone — is born into a session, named
/// by the house as every nameless birth is.
#[test]
fn a_question_taken_out_with_no_document_is_born_into_a_session() {
    let _g = serial();
    fresh_vault("copy");
    let s = an_empty_bench();
    pasted(s, LETTER);
    let out = payload_to_take_out(s).expect("the copy door");
    let row = the_only_session();
    // **In the language of the bench it was born on** (117): this one reads
    // German, so the house's own name for it is German.
    assert_eq!(
        row.name,
        format!("Sitzung {}", row.number),
        "a nameless birth carries the house's name, in the birth language"
    );
    assert_eq!(row.turns, 0, "nothing was answered, so there is no turn yet");
    // **The text that left belongs to the session it was born into**, which is
    // the whole reason the birth is before the build: a payload stamped with a
    // session whose names it does not wear is 064f's own trap.
    assert_eq!(
        out.session.map(|w| w.number),
        Some(row.number),
        "the text that left names no session, or names another one"
    );
    assert!(
        kept_documents(row.number).expect("the kept list").is_empty(),
        "a session with no document is keeping one"
    );
}

/// **The model door**, through the builder it asks: the question goes, the
/// answer comes back, and the turn is written in the session that was born for
/// it.
#[test]
fn a_question_sent_to_a_model_with_no_document_is_born_into_a_session() {
    let _g = serial();
    fresh_vault("model");
    let s = an_empty_bench();
    pasted(s, A_QUESTION);
    let handle = build_the_question_alone(s).expect("the exit's own builder");
    let answer = ask_model(
        handle,
        ProviderId { id: "fake".to_string() },
        None,
        Vec::new(),
    )
    .expect("the model door");
    assert!(!answer.text.is_empty(), "the echo provider answered nothing");
    let row = the_only_session();
    assert_eq!(row.turns, 1, "the exchange was not written in the session");
}

// --------------------------------------------------- 2 · it is a whole session

/// **Its turns are stored, and the next question carries them** — rule 67 on
/// rule 72's surface, which is what the ruling is for.
#[test]
fn the_chat_of_a_question_only_session_carries_its_earlier_turns() {
    let _g = serial();
    fresh_vault("chat");
    let s = an_empty_bench();
    pasted(s, A_QUESTION);
    let first = build_the_question_alone(s).expect("built");
    ask_model(first, ProviderId { id: "fake".to_string() }, None, Vec::new()).expect("asked");
    // «Copy the chat» works on this surface: it refused `NothingToSend` before
    // the ruling, because there was no session for a chat to live in.
    let taken = chat_to_take_out(s).expect("the chat door");
    assert!(
        !taken.what_leaves.text.is_empty(),
        "the chat a person takes away is empty"
    );
    typed(s, "Und wann?");
    let second = build_the_question_alone(s).expect("built again");
    let answer = ask_model(second, ProviderId { id: "fake".to_string() }, None, Vec::new())
        .expect("asked again");
    // The echo provider says back what it was shown, so the earlier turn's own
    // label is the measurement that it travelled.
    assert!(
        answer.text.contains("Earlier request"),
        "the second question left without the first turn beside it"
    );
    assert_eq!(the_only_session().turns, 2, "two exchanges, one session");
}

/// **The room shows it**: under its name, with an empty kept list, and with
/// both doors of the exchange true — rule 69's «sent · answered».
#[test]
fn the_room_shows_it_with_an_empty_kept_list_and_both_doors() {
    let _g = serial();
    fresh_vault("room");
    let s = an_empty_bench();
    pasted(s, A_QUESTION);
    let handle = build_the_question_alone(s).expect("built");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new()).expect("asked");
    let row = the_only_session();
    assert!(
        kept_documents(row.number).expect("the kept list").is_empty(),
        "there was no document, so nothing is kept"
    );
    let turns = conversation_turns(row.number, Some(s)).expect("the turns");
    assert_eq!(turns.len(), 1, "one exchange");
    let turn = &turns[0];
    assert!(!turn.question_as_it_left.is_empty(), "the «sent» half is empty");
    assert!(!turn.answer_as_written.is_empty(), "the «answered» half is empty");
    assert!(
        turn.kept_handle.is_none(),
        "the turn names a saved document, and this exchange carried none"
    );
    assert_eq!(turn.chat_number, 1, "the first chat of a newborn session is chat 1");
}

// ------------------------------------------------------------ 3 · the controls

/// **No empty sessions** — rule 55's own words, and the reason the birth is at
/// the exit and not at the typing. The snapshot builds a payload on every read
/// of this surface (091), so a birth in the builder would make a session out
/// of a question nobody sent.
///
/// **Its face changed with rule 55-ز (22 October 2026) and its body did not,
/// which is the whole of why that rule is safe.** A birth now also happens at
/// the first act worth keeping, and a cover the person's own **hand** put on
/// the request is one. The question pasted below is protected the moment it is
/// set — `set_question` scans it — so if «worth keeping» had been written as
/// «the request has protections», this test would have reddened and the rule
/// would have made a session out of typing. It is the hand that is the act: a
/// scan is a reading, and the sibling test below protects by hand and is born.
#[test]
fn a_question_that_never_leaves_is_born_into_nothing() {
    let _g = serial();
    fresh_vault("never");
    let s = an_empty_bench();
    pasted(s, A_QUESTION);
    for _ in 0..3 {
        let snap = workspace_snapshot(s).expect("the screen's one read");
        assert!(snap.payload.is_some(), "091: the Safe column draws the question");
    }
    assert!(
        conversations().expect("the room").is_empty(),
        "a session was born of a question that never left"
    );
}

/// **One cover the hand put on the request is an act worth keeping** — rule
/// 55-ز, the owner's «نعم» of 22 October 2026, measured from the other side of
/// the boundary the test above holds.
///
/// Nothing has left the machine here and nothing is sent: the person typed a
/// sentence with no document and protected one word of it by hand. That is a
/// decision, it is permanent (089 rule 1), and before this rule it was written
/// nowhere at all — not the block, because the bench never took a session's
/// naming, and not the file, because the writer asked only about a document.
/// Thirteen minutes of the owner's own work, in two windows, with «Protected
/// as …» on both glasses.
#[test]
fn one_cover_the_hand_put_on_the_request_is_born_into_a_session() {
    let _g = serial();
    fresh_vault("hand");
    let s = an_empty_bench();
    // **A word no list we ship knows**, so the cover below is the hand's own
    // work and not a scan's: «Rückruf» is in no pack, which is why the request
    // file uses it too. A word the scan already covers would come back
    // `AlreadyProtected` and write no record of the person's at all — measured,
    // the first time this test was written against «Keller», which the German
    // pack protects after «Herr».
    const BY_HAND: &str = "Bitte um Rückruf heute";
    typed(s, BY_HAND);
    assert!(
        conversations().expect("the room").is_empty(),
        "typing alone made a session, which is the very thing rule 55 forbids"
    );

    let at = BY_HAND.find("Rückruf").expect("the fixture");
    let start = BY_HAND[..at].encode_utf16().count() as u32;
    let span = Span { start, end: start + "Rückruf".encode_utf16().count() as u32 };
    let outcome = protect(s, span, Scope::Conversation, Kind::Person).expect("the hand");
    assert!(
        matches!(outcome, ProtectOutcome::Applied { .. }),
        "the press did not protect by hand, so nothing below measures a birth: {outcome:?}"
    );

    let row = the_only_session();
    assert_eq!(row.turns, 0, "a session was born of an act, not of an exchange");
    assert!(
        vault_snapshot().expect("the vault room").block_count > 0,
        "the session was born and the word the hand covered is still in no block"
    );
}

/// **Rule 71 still holds: ending the chat starts from zero in the same
/// session.** The chat ends by the person's hand; the session is still open,
/// so the next question that leaves joins its next chat and does **not** make
/// a second session.
#[test]
fn ending_the_chat_starts_from_zero_without_a_second_birth() {
    let _g = serial();
    fresh_vault("ended");
    let s = an_empty_bench();
    pasted(s, A_QUESTION);
    let first = build_the_question_alone(s).expect("built");
    ask_model(first, ProviderId { id: "fake".to_string() }, None, Vec::new()).expect("asked");
    let row = the_only_session();
    let next_chat = end_the_chat(row.number).expect("the person's own hand");
    assert_eq!(next_chat, 2, "the chat after the first is chat 2");
    typed(s, "Und die Rechnung?");
    let second = build_the_question_alone(s).expect("built again");
    let answer = ask_model(second, ProviderId { id: "fake".to_string() }, None, Vec::new())
        .expect("asked again");
    assert!(
        !answer.text.contains("Earlier request"),
        "the chat that ended was carried into the next one"
    );
    let after = the_only_session();
    assert_eq!(after.number, row.number, "a second session was born inside an open one");
    assert_eq!(after.turns, 2, "both exchanges are the session's record");
    let turns = conversation_turns(after.number, Some(s)).expect("the turns");
    assert_eq!(
        turns.iter().filter(|t| t.chat_number == 2).count(),
        1,
        "the second exchange is not in the second chat: {:?}",
        turns.iter().map(|t| t.chat_number).collect::<Vec<_>>()
    );
}

/// **The screen's own sequence still makes one session, not two.**
///
/// Today's glass begins a session itself at an exit when none is open, then
/// builds the handle and sends — which is why the product remembers on this
/// surface and why the ruling is about *where the law lives*, not about a
/// forgotten chat. With the core birthing too, this route must still produce
/// exactly one session: the core's law asks whether one is open before it
/// births anything, so the screen's dance becomes redundant rather than
/// doubled. Its removal is the glass's own round.
#[test]
fn the_screens_own_birth_still_makes_one_session_and_not_two() {
    let _g = serial();
    fresh_vault("screen");
    let s = an_empty_bench();
    pasted(s, A_QUESTION);
    // The step the screen takes when `aSessionWouldBeBorn`: a nameless birth,
    // named by the house, with the bench passed so its tokens are re-derived.
    let begun = conversation_begin("Session".to_string(), Some(s)).expect("the screen's birth");
    let handle = build_the_question_alone(s).expect("built after that birth");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new()).expect("asked");
    let row = the_only_session();
    assert_eq!(row.number, begun.number, "the exit was born into a second session");
    assert_eq!(row.turns, 1, "one exchange, in the session the screen began");
}

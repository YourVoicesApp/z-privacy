// 090 part A · The chat remembers — rules 63–68, the owner's «نعم» of 17 October.
//
// **What he met:** he sent «إنجليزي 1» to Grok with a request under it, the
// answer came back right, and then he wanted to ask a second question about the
// same letter. There was nowhere to write it, and the screen told him why:
// «Each question is asked on its own: the model does not see the earlier
// ones.» That sentence was true — `askModelProtected` passed `history: const
// []` and nothing anywhere filled `Context.history` — and his ruling turns it
// around: «لا أستطيع أن أتابع الشات معه على نفس الموضوع». Inside the app there
// are no documents; the app is a chat (rule 63).
//
// So this file measures the four things the core owes that chat:
//
// 1. the history is **built here**, out of the stored turns of the open chat,
//    in the protected form they travelled in (rule 67);
// 2. a question that follows another leaves **by itself** — the document is not
//    sent a second time;
// 3. a chat **ends** when the person says so, and when the application closes,
//    and a chat that ended is not carried into the next one (rule 68);
// 4. the chat **leaves by a door** that hands out the very text the model was
//    shown, and takes nothing out of the preview that never left (rule 65).
//
// Everything here is read from the echo provider's own answer, which repeats
// what it was told: `[instructions: …]`. That makes it a strict instrument — if
// a name were restored on its way into the history, the name would be in the
// answer, and the assertions below name it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a chat";

/// One person in it, and a sentence a model can answer about.
const DOC: &str = "Payroll run, February\nPrepared by: Hedvig Palmgren\nAmount: 42 500\n";

/// The name in the document. Never allowed to appear in anything that leaves.
const NAME: &str = "Hedvig Palmgren";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-chat-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");
    dir
}

/// A bench that closes itself even when a test panics — otherwise the next
/// test's birth with no open document is refused (064f) and the second red has
/// nothing to do with its own claim.
struct Bench(SessionId);

impl Drop for Bench {
    fn drop(&mut self) {
        close_session(self.0).ok();
    }
}

/// The document on a bench, every finding answered, a session born under it.
fn ready(pack: &str) -> (Bench, u32) {
    let held = Bench(open_session(None, pack.to_string()).expect("open"));
    import_text(held.0, DOC.to_string()).expect("import");
    scan(held.0).expect("scan");
    for f in list_findings(held.0).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(held.0, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    // **Rule 55**: the session was born when the document entered the preview,
    // so there is one to write turns into and nobody had to press anything.
    let number = conversation_open().expect("open session").expect(
        "no session was born at the first document, so no turn can be written and \
         this file would measure nothing",
    );
    // **The control string of every claim below.** The first run of this file
    // read the document with the Swedish pack while its labels are English, so
    // nothing was found, nothing was protected, and the name travelled in the
    // clear — through a history whose whole claim is that it carries tokens.
    // Every «the name is not here» assertion was about a document that had
    // never been protected. So the fixture proves itself first.
    let safe = payload_view(build_payload(held.0).expect("build")).expect("view").text;
    assert!(
        safe.contains("__Z_") && !safe.contains(NAME),
        "the fixture protected nobody, so nothing below would measure anything"
    );
    (held, number)
}

/// Ask with the whole document, the way the first question of a chat does.
fn ask_with_the_document(bench: SessionId, question: &str) -> String {
    set_question(bench, question.to_string()).expect("question");
    let handle = build_payload(bench).expect("build");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new())
        .expect("ask")
        .text
}

/// Ask with the question alone, the way every later question does.
fn ask_the_question_alone(bench: SessionId, question: &str) -> String {
    set_question(bench, question.to_string()).expect("question");
    let handle = build_the_question_alone(bench).expect("the question alone");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new())
        .expect("ask")
        .text
}

/// What the echo was told, which is what left this computer as the context.
fn the_instructions(said: &str) -> String {
    let after = said.split("[instructions: ").nth(1).unwrap_or("");
    after.rsplit_once("]\n").map_or(String::new(), |(before, _)| before.to_string())
}

/// **The earlier-request half of a history, alone.**
///
/// Written after a pin left this file green. Sabotaging `ingest_answer` to keep
/// only the request — the old behaviour, without the document — changed
/// nothing: the assertions found «--- Request ---» and the document in the
/// history all the same, because the **answer** half is the echo's own text and
/// the echo repeats the payload it was sent. The claim is about the question
/// side, so it has to be asked of the question side.
fn the_earlier_request(told: &str) -> String {
    told.split("--- Earlier request ---")
        .nth(1)
        .unwrap_or("")
        .split("--- Earlier answer ---")
        .next()
        .unwrap_or("")
        .to_string()
}

/// **As close to closing the application as one process gets.**
///
/// The folder is set again, which reloads the vault from disk and empties the
/// run's list of chats it has opened — the two things a new process starts
/// with. What it does *not* reset is everything else the core holds in memory,
/// so it is a stand-in and said to be one; the measurement with two real
/// processes is `two_copies_never_lose_a_write.rs`'s shape.
fn close_the_app_and_reopen(dir: &std::path::Path, bench: SessionId) {
    close_session(bench).ok();
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
}

// ------------------------------------------------------------------ A1

/// **The second question carries the first turn, as it left** — rule 67.
///
/// The one assertion this round exists for. The second request's instructions
/// hold the first payload **as the model saw it** — the document, the
/// `--- Request ---` line and the request — and the first answer **as the model
/// wrote it**. Nothing is restored on the way in: the name is in neither half,
/// the token is in both.
///
/// And nothing *more*: one earlier request and one earlier answer, counted,
/// because a history that grew by itself would be the model paying for text
/// twice.
#[test]
fn a_second_question_carries_the_first_turn_as_it_left() {
    let _g = serial();
    let dir = fresh_vault("carries");
    let (held, number) = ready("en");
    let bench = held.0;

    let first = ask_with_the_document(bench, "What does this letter say?");
    assert!(
        the_instructions(&first).is_empty(),
        "the first question of a chat carried a history, and there was nothing before it"
    );

    let second = ask_the_question_alone(bench, "And the amount?");
    let told = the_instructions(&second);

    assert!(told.contains("--- Earlier request ---"), "the second question carried no history");
    // **Asked of the request half alone**, because the answer half is the
    // echo's own repetition of the payload and would answer for it.
    let asked = the_earlier_request(&told);
    assert!(
        asked.contains("--- Request ---"),
        "the earlier request in the history is not the payload as it left: the \
         document and the request travelled together and the history holds only half of it"
    );
    assert!(
        asked.contains("Payroll run, February"),
        "the document the first question carried is not in the history, so the \
         model is being asked a follow-up about a letter it cannot see"
    );
    assert!(
        asked.contains("What does this letter say?"),
        "the first question's own words are not in the history"
    );
    assert!(
        told.contains("--- Earlier answer ---") && told.contains("Ende der Antwort"),
        "the first answer is not in the history, so the model is answering its own answer blind"
    );
    assert!(
        !told.contains(NAME),
        "a name was restored on its way into the history — the protection of the \
         document was theatre from the second question onwards"
    );
    assert!(
        told.contains("__Z_"),
        "the history carries no token at all, so it is not the text that left"
    );
    assert_eq!(
        told.matches("--- Earlier request ---").count(),
        1,
        "the history holds more than the one turn there was"
    );
    assert_eq!(told.matches("--- Earlier answer ---").count(), 1, "the same, on the answer side");

    // And the turns themselves are the two that happened, both in chat 1.
    let rows = conversation_turns(number, Some(bench)).expect("turns");
    assert_eq!(rows.len(), 2, "two questions were asked and the session holds something else");
    assert!(
        rows.iter().all(|r| r.chat_number == 1),
        "the two turns of one chat are not in one chat"
    );
    assert_eq!(the_open_chat(number).expect("the open chat"), 1);

    let _ = std::fs::remove_dir_all(&dir);
}

// ------------------------------------------------------------------ A2

/// **A question that follows another leaves by itself** — rule 67's other half:
/// «والوثيقة لا تُرسل مرة ثانية إلا إن أدخلها المستخدم من جديد».
#[test]
fn a_follow_up_question_leaves_without_the_document() {
    let _g = serial();
    let dir = fresh_vault("alone");
    let (held, _) = ready("en");
    let bench = held.0;

    ask_with_the_document(bench, "What does this letter say?");

    set_question(bench, "And the amount?".to_string()).expect("question");
    let handle = build_the_question_alone(bench).expect("the question alone");
    let view = payload_view(handle).expect("view");

    assert_eq!(view.text.trim(), "And the amount?", "the question did not leave by itself");
    assert!(
        !view.text.contains("Payroll run"),
        "the document was sent a second time, and the person put it in once"
    );
    assert!(!view.text.contains(NAME), "the name is in the clear in what would leave");

    // **And what may come back is wider than what stands in it** — G9. The
    // answer to three words names what the first request showed the model, so
    // the tokens of this chat are allowed even though they are not in this
    // text. Measured through a restore: the echo repeats the history, and the
    // name comes back out of it.
    let said = ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new())
        .expect("ask");
    let answer = said.answer.expect("an answer id");
    let restored: String = restored_view(bench, answer)
        .expect("restore")
        .into_iter()
        .map(|s| s.text)
        .collect();
    assert!(
        restored.contains(NAME),
        "a token the first request carried was not allowed back, so the person \
         reads their own token in the answer instead of the name it stands for"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// A question nobody typed is nothing to send, and the refusal says which thing
/// is missing rather than sending a label with no sentence under it.
#[test]
fn a_follow_up_with_no_question_in_it_is_refused() {
    let _g = serial();
    let dir = fresh_vault("empty");
    let (held, _) = ready("en");

    match build_the_question_alone(held.0) {
        Err(ApiError::NothingToSend) => {}
        other => panic!("an empty follow-up was built or refused for the wrong reason: {other:?}"),
    }

    let _ = std::fs::remove_dir_all(&dir);
}

// ------------------------------------------------------------------ A3

/// **A chat that ended is not carried into the next one** — rule 68.
///
/// The turns stay: rule 69 shows them in the session's room, and a chat that
/// ended is not a chat that was deleted. What ends is what a new question
/// carries with it.
#[test]
fn a_chat_that_ended_is_not_carried_into_the_next_one() {
    let _g = serial();
    let dir = fresh_vault("ended");
    let (held, number) = ready("en");
    let bench = held.0;

    ask_with_the_document(bench, "What does this letter say?");
    assert_eq!(the_open_chat(number).expect("the open chat"), 1);

    let now = end_the_chat(number).expect("end");
    assert_eq!(now, 2, "ending a chat did not spend its number");
    assert_eq!(the_open_chat(number).expect("the open chat"), 2);

    let said = ask_with_the_document(bench, "And what does this one say?");
    assert!(
        the_instructions(&said).is_empty(),
        "the chat the person ended travelled with the next question anyway"
    );

    // Both turns are still there, each naming its own chat.
    let rows = conversation_turns(number, Some(bench)).expect("turns");
    assert_eq!(rows.len(), 2, "ending a chat deleted a turn, and it was only meant to end it");
    assert_eq!(rows[0].chat_number, 1);
    assert_eq!(rows[1].chat_number, 2, "the turn after the end is in the chat after it");

    let _ = std::fs::remove_dir_all(&dir);
}

/// **And closing the application ends it too** — rule 68's other half, which
/// needs no call: a run that did not open the session cannot find a chat open
/// in it.
#[test]
fn a_new_run_does_not_continue_the_chat_it_finds() {
    let _g = serial();
    let dir = fresh_vault("newrun");
    let (held, number) = ready("en");
    let bench = held.0;

    ask_with_the_document(bench, "What does this letter say?");
    assert_eq!(the_open_chat(number).expect("the open chat"), 1);
    drop(held);

    close_the_app_and_reopen(&dir, bench);
    conversation_enter(number, None).expect("enter");
    assert_eq!(
        the_open_chat(number).expect("the open chat"),
        2,
        "the chat the person left behind was still open in a run that did not open it"
    );

    // And the turn it holds is not carried: the bench is gone with the run, so
    // this is asked of the file itself.
    let held = Bench(open_session(None, "en".to_string()).expect("open"));
    import_text(held.0, DOC.to_string()).expect("import");
    scan(held.0).expect("scan");
    for f in list_findings(held.0).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(held.0, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    conversation_enter(number, Some(held.0)).expect("enter with the bench");
    let said = ask_with_the_document(held.0, "What does the new letter say?");
    assert!(
        the_instructions(&said).is_empty(),
        "yesterday's chat travelled with today's first question"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **Looking at another session and coming back is not the end of a chat.**
///
/// The run bump is the first opening in a run and no other, which is what makes
/// an auto-lock, a glance at the session list and a second bench all harmless.
#[test]
fn entering_the_same_session_again_in_one_run_keeps_its_chat() {
    let _g = serial();
    let dir = fresh_vault("again");
    let (held, number) = ready("en");
    let bench = held.0;

    ask_with_the_document(bench, "What does this letter say?");
    conversation_enter(number, Some(bench)).expect("enter again");
    assert_eq!(
        the_open_chat(number).expect("the open chat"),
        1,
        "coming back to a session ended the chat the person is in the middle of"
    );
    let said = ask_the_question_alone(bench, "And the amount?");
    assert!(
        the_instructions(&said).contains("--- Earlier request ---"),
        "the chat was lost by entering the session it belongs to"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

// ------------------------------------------------------------------ A4

/// **What a person copies out is what the model was shown** — rule 65's copy.
#[test]
fn the_chat_a_person_takes_away_is_the_text_the_model_was_shown() {
    let _g = serial();
    let dir = fresh_vault("copy");
    let (held, _) = ready("en");
    let bench = held.0;

    ask_with_the_document(bench, "What does this letter say?");
    let out = chat_to_take_out(bench).expect("the chat");

    assert!(out.what_leaves.text.contains("--- Earlier request ---"), "the copy has no turn in it");
    assert!(out.what_leaves.text.contains("What does this letter say?"), "the question is not in the copy");
    assert!(out.what_leaves.text.contains("Ende der Antwort"), "the answer is not in the copy");
    assert!(
        !out.what_leaves.text.contains(NAME),
        "the name left this machine on the clipboard, which is the one thing this \
         program exists to prevent"
    );
    assert!(out.what_leaves.text.contains("__Z_"), "the copy carries no token, so it is not what left");

    // The same text the next question would carry, built by the one function:
    // the echo repeats the history, so the two can be compared in full.
    let said = ask_the_question_alone(bench, "And the amount?");
    let told = the_instructions(&said);
    assert!(
        told.starts_with(&out.what_leaves.text),
        "the copy in a person's hand and the history the model is shown are two \
         different texts"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **Copying the chat takes nothing out of the preview** — 089 rule 9, and the
/// reason this door is the one that does not call `the_preview_has_left`.
///
/// Every byte of a chat left by another door, which took the preview's copy
/// with it then. Doing it here would delete the copy of whatever document is on
/// the bench **now** — and that one may never have left. Pinned, because the
/// uniform thing to do is the wrong thing here and a later tidy-up will want to
/// make it uniform.
#[test]
fn copying_the_chat_leaves_a_document_that_never_left_in_the_preview() {
    let _g = serial();
    let dir = fresh_vault("preview");
    let (held, number) = ready("en");
    let bench = held.0;

    ask_with_the_document(bench, "What does this letter say?");
    // The document left by the send, so its copy went with it (rule 9).
    assert!(
        kept_documents(number).expect("kept").is_empty(),
        "the document that left is still in the preview's list"
    );

    // A second document, which has not left anything.
    import_text(bench, "Hej Stefan Keller, ditt konto är öppet.".to_string()).expect("import");
    scan(bench).expect("scan");
    let before = kept_documents(number).expect("kept");
    assert_eq!(before.len(), 1, "the new document was not kept, so this proves nothing");

    chat_to_take_out(bench).expect("the chat");

    let after = kept_documents(number).expect("kept");
    assert_eq!(
        after.len(),
        1,
        "copying the chat deleted the preview's copy of a document that never left"
    );
    assert_eq!(after[0].handle, before[0].handle, "and it deleted a different one");

    let _ = std::fs::remove_dir_all(&dir);
}

/// **The chat is a door, and a door asks the one law** — C3, G28.
#[test]
fn the_chat_does_not_leave_while_a_word_waits() {
    let _g = serial();
    let dir = fresh_vault("waits");
    let (held, _) = ready("en");
    let bench = held.0;

    ask_with_the_document(bench, "What does this letter say?");
    // A document with something still open on it, on the same bench: a surname
    // that is in no list and ends like an English one, so it is **offered** and
    // nobody has answered.
    import_text(bench, "The contract was signed by John Harrowson in Leeds.".to_string())
        .expect("import");
    scan(bench).expect("scan");
    let open = list_findings(bench)
        .expect("findings")
        .iter()
        .filter(|f| f.state == MarkState::Suggested)
        .count();
    assert!(open > 0, "nothing is waiting, so this proves nothing");

    match chat_to_take_out(bench) {
        Err(ApiError::OpenSuggestions { count }) => {
            assert_eq!(count as usize, open, "the refusal counted something else")
        }
        other => panic!("the fourth door carries its own exception to the law: {other:?}"),
    }

    let _ = std::fs::remove_dir_all(&dir);
}

/// **Every token standing in a text, in the shape `tokens.rs` writes them.**
fn tokens_in(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut rest = text;
    while let Some(at) = rest.find("__Z_") {
        let from = &rest[at..];
        match from[4..].find("__") {
            Some(end) => {
                let stop = 4 + end + 2;
                out.push(from[..stop].to_string());
                rest = &from[stop..];
            }
            None => break,
        }
    }
    out
}

// ------------------------------------------------------------ rules 66 and 69

/// **A turn carries both sides twice: as they travelled, and restored** —
/// rule 66, «تظهر الإجابة داخل الشات مرمزة مع زر عرض النص».
///
/// The thread is drawn coded and the bubble behind «Show the text» is drawn
/// restored, and both come out of **one** read of one file: two reads could
/// draw two different exchanges. `AnswerSnapshot::as_written` answers for the
/// live answer alone and has nothing to say about the question as it left, or
/// about a turn read back a week later.
#[test]
fn a_turn_carries_both_sides_coded_and_restored() {
    let _g = serial();
    let dir = fresh_vault("coded");
    let (held, number) = ready("en");
    let bench = held.0;

    ask_with_the_document(bench, "What does this letter say?");
    let rows = conversation_turns(number, Some(bench)).expect("turns");
    let turn = rows.last().expect("the turn");

    assert!(
        turn.question_as_it_left.contains("__Z_"),
        "the question as it left carries no token, so the thread would be drawn from \
         something other than what left"
    );
    assert!(
        !turn.question_as_it_left.contains(NAME),
        "the coded side holds the name in the clear"
    );
    assert!(
        turn.answer_as_written.contains("Ende der Antwort"),
        "the answer as written is not what the model wrote"
    );
    assert!(!turn.answer_as_written.contains(NAME), "the answer as written was restored");

    // And the restored halves, beside them, in the same row.
    let restored: String = turn.question.iter().map(|s| s.text.as_str()).collect();
    assert!(
        restored.contains(NAME),
        "the restored half put nothing back, so the bubble would show a token"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **A turn names the document it carried, and the number outlives the copy** —
/// rule 69, and the reason the anchor is a number and not a name.
///
/// Rule 9 takes the preview's copy out the moment the text leaves, so by the
/// time the room is drawn there is nothing in the list to match on: the number
/// is all that is left of the document that went. A name would not do — a
/// person may rename a saved document, and two may share a name.
#[test]
fn a_turn_names_the_document_it_carried_after_the_copy_is_gone() {
    let _g = serial();
    let dir = fresh_vault("anchor");
    let (held, number) = ready("en");
    let bench = held.0;

    let before = kept_documents(number).expect("kept");
    assert_eq!(before.len(), 1, "the document was not kept, so this proves nothing");
    let handle = before[0].handle.clone();

    ask_with_the_document(bench, "What does this letter say?");
    assert!(
        kept_documents(number).expect("kept").is_empty(),
        "the document that left is still in the list, so the anchor is not needed yet"
    );

    let rows = conversation_turns(number, Some(bench)).expect("turns");
    assert_eq!(
        rows[0].kept_handle.as_deref(),
        Some(handle.as_str()),
        "the turn does not name the document it carried, so «sent · answered» has \
         nothing to stand under"
    );

    // **And a follow-up names none**, because it carried none (rule 67). What
    // ties it to the document is the chat number, which both turns share.
    let said = ask_the_question_alone(bench, "And the amount?");
    assert!(!said.is_empty());
    let rows = conversation_turns(number, Some(bench)).expect("turns");
    assert_eq!(rows.len(), 2);
    assert_eq!(
        rows[1].kept_handle, None,
        "a follow-up claimed to carry the document it was told not to send again"
    );
    assert_eq!(rows[0].chat_number, rows[1].chat_number, "the two turns are not in one chat");

    let _ = std::fs::remove_dir_all(&dir);
}

/// **An answer brought back against the chat's own copy asks nothing new, and
/// restores every name the chat ever carried** — rule 65's copy and G9.
///
/// «Add an answer» binds the answer to a payload and restores by that payload's
/// allowed list. Bound to whatever handle was last on the table, a token born
/// in the *second* question would come home as a token — so the copy carries
/// the handle of itself, and its list covers every turn.
///
/// And the turn it writes has **no question of its own**: nothing new was
/// asked, and the transcript written back in would put the chat inside itself
/// and carry it twice to the next model.
#[test]
fn an_answer_against_the_chats_own_copy_asks_nothing_new_and_restores_every_name() {
    let _g = serial();
    let dir = fresh_vault("copyback");
    let (held, number) = ready("en");
    let bench = held.0;

    // Turn one carries the document, so its token is born there.
    ask_with_the_document(bench, "What does this letter say?");
    let first = conversation_turns(number, Some(bench)).expect("turns")[0]
        .question_as_it_left
        .clone();
    let born_first = tokens_in(&first);
    assert!(!born_first.is_empty(), "the document protected nobody");

    // Turn two carries an IBAN typed into the question, so **this** token is
    // born in a later turn — the one a copy bound to the wrong handle loses.
    set_question(bench, "And is IBAN DE02120300000000202051 right?".to_string())
        .expect("question");
    let later = build_the_question_alone(bench).expect("the question alone");
    let born_later: Vec<String> = tokens_in(&payload_view(later).expect("view").text)
        .into_iter()
        .filter(|t| !born_first.contains(t))
        .collect();
    assert!(
        !born_later.is_empty(),
        "no token was born in the second question, so this measures nothing"
    );
    ask_model(later, ProviderId { id: "fake".to_string() }, None, Vec::new()).expect("ask");

    // The person copies the chat, asks a model in a browser, comes back.
    let out = chat_to_take_out(bench).expect("the chat");
    let answered = format!(
        "{} is the person and {} is the account.",
        born_first[0], born_later[0]
    );
    ingest_answer(out.handle, answered).expect("paste");

    let rows = conversation_turns(number, Some(bench)).expect("turns");
    let turn = rows.last().expect("the pasted turn");
    assert!(
        turn.question_as_it_left.is_empty(),
        "the whole chat was written back in as a question the person never typed"
    );
    assert_eq!(turn.via, TurnVia::Pasted, "a turn the person carried says something else");
    let restored: String = turn.answer.iter().map(|s| s.text.as_str()).collect();
    // **Not «the full name is back»**: one click takes one word (085), so the
    // first token stands for one half of a name and asserting the whole of it
    // failed on a document that was protected perfectly. The claim is the one
    // that matters — nothing came home still wearing a token — and the IBAN,
    // which is one value in one token, says it by name.
    assert!(
        !restored.contains("__Z_"),
        "a token came home as a token: {restored}"
    );
    assert!(
        restored.contains("DE02120300000000202051"),
        "the token born in the second question came home unresolved, which is exactly \
         what binding the paste to the wrong payload does"
    );
    assert!(turn.unresolved.is_empty(), "the turn names a token it could not place");
    // **And it stands under the document the chat began with** (rule 69): the
    // transcript holds that document word for word.
    assert_eq!(
        turn.kept_handle, rows[0].kept_handle,
        "an answer brought back against the chat's copy is anchored somewhere else than \
         the chat's own document"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **An answer the person carried back by hand joins the chat they are in** —
/// rule 66's second half, and A4's one confirmation: «Add an answer» needs no
/// new door, so what had to be checked is that the door it already uses writes
/// the turn the same way — carried by hand, and in the open chat.
#[test]
fn an_answer_brought_back_by_hand_joins_the_open_chat() {
    let _g = serial();
    let dir = fresh_vault("pasted");
    let (held, number) = ready("en");
    let bench = held.0;

    // The person's own path: set the question, build what would leave, take it
    // out through the exit door, come back with an answer from a browser.
    set_question(bench, "What does this letter say?".to_string()).expect("question");
    let handle = build_payload(bench).expect("build");
    payload_to_take_out(bench).expect("the exit");
    ingest_answer(handle, "It is a payroll line.".to_string()).expect("paste");

    let rows = conversation_turns(number, Some(bench)).expect("turns");
    let turn = rows.last().expect("the pasted turn");
    assert_eq!(turn.via, TurnVia::Pasted, "a turn the person carried says something else");
    assert_eq!(
        turn.chat_number,
        the_open_chat(number).expect("the open chat"),
        "an answer brought back by hand landed outside the chat the person is in"
    );
    // **And it names the document it was about** — which is the whole reason
    // the anchor is stamped on the payload when it is built and not read off
    // the bench when the answer arrives: the copy went out of the list at the
    // exit above, so the bench has nothing left to name.
    assert!(
        turn.kept_handle.is_some(),
        "a pasted answer names no document, so rule 69 would draw «sent · answered» \
         under nothing for the one path that always goes out and comes back by hand"
    );

    // And it travels with the next question like any other turn.
    let said = ask_the_question_alone(bench, "And the amount?");
    assert!(
        the_instructions(&said).contains("It is a payroll line."),
        "the answer the person carried back is not carried on"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// A chat nobody has had is nothing to take out, and it says so by name rather
/// than handing over an empty string that reads like a chat with nothing in it.
#[test]
fn a_session_with_no_chat_in_it_has_nothing_to_take_out() {
    let _g = serial();
    let dir = fresh_vault("nochat");
    let (held, _) = ready("en");

    match chat_to_take_out(held.0) {
        Err(ApiError::NothingToSend) => {}
        other => panic!("an empty chat was handed out: {other:?}"),
    }

    let _ = std::fs::remove_dir_all(&dir);
}

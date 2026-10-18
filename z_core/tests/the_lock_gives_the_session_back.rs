// **A lock takes the session away; the unlock gives it back** — 18 October
// 2026, the owner, on the installed `34ed785`.
//
// He asked a question, xAI answered, the chat drew the exchange. The vault
// auto-locked while he read it. He pressed Unlock in the band, typed the same
// question again, and «the message did not arrive». It had: it was answered
// into a **session born on the spot**, while the chat he was looking at stayed
// in the session before it — so the thread he was reading stopped being the
// thread the panel drew, and nothing on the glass said anything was wrong.
//
// `vault_lock` clears `open_conversation` because the way into a sealed file
// goes with the master key (064, 062 §D), and its own comment named the other
// half: «the next unlock **plus an `enter`** brings both back». The unlock half
// existed; the `enter` half was nobody's — no screen called it, and rule 55's
// birth-at-the-first-exit then did exactly what it says.
//
// **The number is not secret**, which is why the fix belongs here and not on a
// screen: what the key guards is the way into the file, and «which session was
// open» is a fact about this run that no passphrase protects. 064 let it go
// with the key as a side effect of one line, not as a law.
//
// Three states, and each is measured rather than reasoned about:
//
//   1. a session open, locked, unlocked → the **same** session is open again,
//      its turns are still in it, and no new one was born;
//   2. nothing open, locked, unlocked → nothing is entered and nothing is
//      born, because there was nothing to give back;
//   3. a session open, locked, **forgotten from the room**, unlocked → the
//      unlock succeeds, nothing is left open, and no session is born in its
//      place.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für die Sitzung";

/// One letter with one name a general rule protects on its own, so a session
/// has something of the person's to hold.
const DOC: &str = "Sehr geehrter Herr Thomas Müller,\ndie Rechnung ist beglichen.\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// A fresh folder with a vault in it, and nothing else.
///
/// One `Core` serves every test in this binary, so the folder is new for each
/// one: `set_data_dir` is also what clears the number a lock kept, and a test
/// that inherited one from the test before it would be measuring that instead.
fn a_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-lock-gives-back-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
}

/// A document on a bench — which **is** a session, since rule 55: it is born
/// as the text enters the preview, and it is the one that is open from here on.
/// Measured rather than assumed: the room holds exactly one, and it is open.
fn a_document_in_its_session(name: &str) -> (SessionId, u32) {
    a_vault(name);
    let bench = open_session(None, "de".to_string()).expect("open");
    import_text(bench, DOC.to_string()).expect("import");
    let number = conversation_open().expect("open").expect("rule 55 bore no session");
    (bench, number)
}

/// One exchange written into the open session, the way an answer writes one.
fn one_turn_in_it() {
    conversation_record(
        "Worum geht es?".to_string(),
        "Um die Rechnung.".to_string(),
        TurnVia::NotRecorded,
        TurnDocument::Typed,
    )
    .expect("record");
}

#[test]
fn an_unlock_enters_the_session_the_lock_took_away() {
    let _guard = serial();
    let (bench, number) = a_document_in_its_session("same");
    one_turn_in_it();

    vault_lock().expect("lock");
    // The way in went with the key, and that half is unchanged.
    assert_eq!(
        conversation_open().expect("open"),
        None,
        "a locked vault left a session open, so the file could be read without the key"
    );

    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");

    // **The same number, not a new one.** This is the owner's whole complaint:
    // a question asked after his Unlock went into a session born on the spot.
    assert_eq!(
        conversation_open().expect("open"),
        Some(number),
        "the unlock did not give the session back, so the next exit would be born into a new one"
    );
    // And it is the session that was there, turns and all.
    let turns = conversation_turns(number, Some(bench)).expect("turns");
    assert_eq!(turns.len(), 1, "the session came back without what was in it");
    // Nothing was born: the room holds the one session it held before.
    let rooms = conversations().expect("rooms");
    assert_eq!(rooms.len(), 1, "a session was born by an unlock: {rooms:?}");
    // And the chat was not spent, so a question asked now carries what was
    // said before it (rule 68: this run has already opened this session).
    assert_eq!(
        the_open_chat(number).expect("chat"),
        turns[0].chat_number,
        "the unlock spent the chat number, so the thread the panel draws is empty"
    );
}

#[test]
fn an_unlock_with_nothing_taken_away_opens_nothing() {
    let _guard = serial();
    // **A vault and no document**: rule 55 bears a session at the first
    // document entering a preview, so with no document there is nothing open —
    // which is the state a person is in the moment they unlock at startup.
    a_vault("nothing");
    assert_eq!(conversation_open().expect("open"), None);

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");

    assert_eq!(
        conversation_open().expect("open"),
        None,
        "an unlock opened a session in a run that never had one"
    );
    assert!(
        conversations().expect("rooms").is_empty(),
        "an unlock bore a session out of nothing"
    );
}

#[test]
fn an_unlock_whose_session_was_forgotten_leaves_nothing_open() {
    let _guard = serial();
    let (_bench, number) = a_document_in_its_session("forgotten");
    one_turn_in_it();

    vault_lock().expect("lock");
    // Forgotten while the vault was shut — which needs it open, so this is the
    // order a person would walk: unlock, forget, lock again.
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    conversation_forget(number).expect("forget");
    vault_lock().expect("lock");

    // The unlock still succeeds — the one act asked for — and leaves nothing
    // open, because there is nothing to enter.
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert_eq!(
        conversation_open().expect("open"),
        None,
        "the unlock entered a session that no longer exists"
    );
    assert!(
        conversations().expect("rooms").is_empty(),
        "the unlock bore a session in place of the one that was forgotten"
    );
}

#[test]
fn the_number_is_spent_once() {
    let _guard = serial();
    let (_bench, number) = a_document_in_its_session("spent");
    one_turn_in_it();

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert_eq!(conversation_open().expect("open"), Some(number));

    // A second unlock with no lock in between: there is nothing kept, so this
    // enters nothing — and what is open stays open, because nothing closed it.
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert_eq!(
        conversation_open().expect("open"),
        Some(number),
        "a second unlock changed which session is open"
    );
}

// The reveal in the safe column, and the lock.
//
// The behaviour board that promised «Hide Again works on its own — after the
// window, on losing focus, when the vault locks, when the panel closes» is the
// one titled *the Safe side and the answer*. So the promise was made about
// **these** reveals, and these had no state in the core at all: `ops::reveal`
// handed over the value with a `ttl_ms` and forgot, and `ops::hide` only
// checked that the token was real. Every one of the four ways a reveal was
// supposed to end was left to the screen, including the lock.
//
// The owner's rule for what the lock ends: **everything**, for every source.
// Not «what the vault knows» — a person who turns the key is not asked to work
// out which layer found each secret on their screen. It holds by construction
// rather than by memory: the vault counts its locks, each reveal remembers the
// count it was born under, and the read door drops anything older. So the
// auto-lock is covered too, because the read door judges the clock first.
//
// Two of these tests say the rule out loud, by the leader's instruction: a
// hand-protected token goes when the vault locks, and a hand-protected token
// can still be revealed while the vault is locked. The rule is about the
// moment of a lock, not about the state of being locked.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für die Säule";

/// Deliberately plain German. Nothing here has the shape of an IBAN or an
/// e-mail, and nothing stands after a label the German pack knows — so the
/// only layer that can find «Blaues Dach» is the vault, and «Nordlicht» is
/// protected by hand and by nothing else.
const DOC: &str = "Das Vorhaben Blaues Dach gehört zum Programm Nordlicht.";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle is in the document");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    let len: usize = needle.chars().map(char::len_utf16).sum();
    Span { start: start as u32, end: (start + len) as u32 }
}

struct Ground {
    session: SessionId,
    /// A token the vault found, by knowing the thing by name.
    from_vault: String,
    /// A token the person made, and no layer would have found.
    by_hand: String,
    entity: u32,
    value_id: u32,
}

fn a_document_with_both(reveal_seconds: u32, auto_lock_minutes: u32) -> Ground {
    // One `Core` serves this whole binary: `serial()` orders the tests, it does
    // not reset them.
    let _ = hide_all_reveals();
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-safe-column-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");

    let current = settings().expect("settings");
    save_settings(Settings { reveal_seconds, auto_lock_minutes, ..current }).expect("save");

    let entity = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("entity");
    let value_id = set_value(entity, None, Kind::Project, "Blaues Dach".to_string(), Policy::Always)
        .expect("value");

    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, DOC.to_string()).expect("import");
    scan(session).expect("scan");
    protect(session, span_of(DOC, "Nordlicht"), Scope::Conversation, Kind::Project).expect("protect");

    let rows = list_tokens(session).expect("tokens");
    let from_vault = rows
        .iter()
        .find(|r| r.source == Source::Vault)
        .unwrap_or_else(|| panic!("no vault-sourced token in {rows:?}"))
        .token
        .clone();
    let by_hand = rows
        .iter()
        .find(|r| r.source == Source::Hand)
        .unwrap_or_else(|| panic!("no hand-made token in {rows:?}"))
        .token
        .clone();
    Ground { session, from_vault, by_hand, entity, value_id }
}

fn shown(session: SessionId) -> Vec<String> {
    revealed_tokens(session)
        .expect("revealed")
        .into_iter()
        .map(|r| r.token)
        .collect()
}

#[test]
fn the_core_says_which_tokens_are_shown() {
    let _guard = serial();
    let g = a_document_with_both(300, 0);
    assert!(shown(g.session).is_empty(), "something is shown before anyone asked");

    reveal(g.session, g.by_hand.clone()).expect("reveal");
    let live = revealed_tokens(g.session).expect("revealed");
    assert_eq!(live.len(), 1);
    assert_eq!(live[0].token, g.by_hand);
    assert!(live[0].remaining_ms > 0, "shown with no time left");
}

#[test]
fn hiding_one_token_ends_it_in_the_core() {
    let _guard = serial();
    let g = a_document_with_both(300, 0);
    reveal(g.session, g.by_hand.clone()).expect("reveal");
    hide(g.session, g.by_hand.clone()).expect("hide");
    assert!(shown(g.session).is_empty(), "hiding left the reveal standing in the core");
}

#[test]
fn a_token_from_the_vault_goes_when_the_vault_is_locked() {
    let _guard = serial();
    let g = a_document_with_both(300, 0);
    reveal(g.session, g.from_vault.clone()).expect("reveal");
    assert_eq!(shown(g.session), vec![g.from_vault.clone()]);

    vault_lock().expect("lock");

    assert!(
        shown(g.session).is_empty(),
        "a value the vault knows is still shown after the vault was locked"
    );
}

/// The rule said out loud, part one.
#[test]
fn a_token_protected_by_hand_goes_when_the_vault_is_locked() {
    let _guard = serial();
    let g = a_document_with_both(300, 0);
    reveal(g.session, g.by_hand.clone()).expect("reveal");
    assert_eq!(shown(g.session), vec![g.by_hand.clone()]);

    vault_lock().expect("lock");

    assert!(
        shown(g.session).is_empty(),
        "the lock left a hand-protected value on screen: the key covers what the person sees, \
         not only what the vault owns"
    );
}

/// The rule said out loud, part two: about the moment of a lock, not the state
/// of being locked. A locked vault must not make the safe column unreadable.
#[test]
fn a_hand_token_can_still_be_revealed_while_the_vault_is_locked() {
    let _guard = serial();
    let g = a_document_with_both(300, 0);
    vault_lock().expect("lock");

    reveal(g.session, g.by_hand.clone()).expect("reveal while locked");
    assert_eq!(
        shown(g.session),
        vec![g.by_hand.clone()],
        "a locked vault swallowed a reveal that had nothing to do with it"
    );
    // And asking again does not take it away.
    assert_eq!(shown(g.session), vec![g.by_hand]);
}

#[test]
#[cfg(feature = "test_clock")]
fn the_vault_locking_itself_takes_the_tokens_too() {
    let _guard = serial();
    let g = a_document_with_both(300, 1);
    reveal(g.session, g.by_hand.clone()).expect("reveal");
    assert_eq!(shown(g.session).len(), 1);

    z_core::test_clock::age_vault_unused(61);

    assert!(
        shown(g.session).is_empty(),
        "the vault locked itself and the tokens stayed on screen"
    );
    assert_eq!(vault_state().expect("state"), VaultState::Locked);
}

/// The trap, guarded: if asking counted as using the vault, a panel that asks
/// once a second would hold the vault open for as long as a value is on it.
#[test]
#[cfg(feature = "test_clock")]
fn asking_about_a_revealed_token_does_not_postpone_the_vault_lock() {
    let _guard = serial();
    let g = a_document_with_both(300, 1);
    reveal(g.session, g.by_hand.clone()).expect("reveal");

    for _ in 0..61 {
        z_core::test_clock::age_vault_unused(1);
        let _ = revealed_tokens(g.session).expect("revealed");
    }

    assert_eq!(
        vault_state().expect("state"),
        VaultState::Locked,
        "asking about a revealed token kept the vault open past its limit"
    );
}

#[test]
fn one_door_covers_the_vault_value_and_the_tokens() {
    let _guard = serial();
    let g = a_document_with_both(300, 0);
    reveal(g.session, g.by_hand.clone()).expect("token");
    reveal_value(g.entity, g.value_id).expect("vault value");
    assert_eq!(shown(g.session).len(), 1);
    assert!(reveal_state().expect("state").remaining_ms > 0);

    hide_all_reveals().expect("cover everything");

    assert!(shown(g.session).is_empty(), "a token stayed shown");
    assert_eq!(reveal_state().expect("state").remaining_ms, 0, "the vault value stayed shown");
}

#[test]
fn closing_the_conversation_ends_what_it_was_showing() {
    let _guard = serial();
    let g = a_document_with_both(300, 0);
    reveal(g.session, g.by_hand.clone()).expect("reveal");
    close_session(g.session).expect("close");

    match revealed_tokens(g.session) {
        Err(ApiError::InvalidSession) => {}
        other => panic!("a closed session still answers about its reveals: {other:?}"),
    }
}

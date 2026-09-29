// P1-4 — the core owns the reveal, and a screen may only ask.
//
// His rule of 29 September: a countdown drawn in Flutter is for a person to
// read, **never permission** to keep a value on screen. So the authority is
// tested here, where it lives.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für das Enthüllen";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// A vault with one value, and the reveal window turned down so the test does
/// not sit waiting. The window is a setting the core already owns.
fn a_value(seconds: u32) -> (u32, u32) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-reveal-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");

    let current = settings().expect("settings");
    save_settings(Settings { reveal_seconds: seconds, ..current }).expect("save");

    let entity = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("entity");
    let value = set_value(entity, None, Kind::Company, "Nordstern Consulting GmbH".to_string(), Policy::Always)
        .expect("value");
    (entity, value)
}

#[test]
fn nothing_is_revealed_until_it_is_asked_for() {
    let _guard = serial();
    let _ = a_value(30);
    let state = reveal_state().expect("state");
    assert_eq!(state.remaining_ms, 0);
    assert!(state.value_id.is_none(), "something is revealed before anyone asked");
}

#[test]
fn a_reveal_reports_its_own_remaining_time_and_then_ends() {
    let _guard = serial();
    let (entity, value) = a_value(3);

    let shown = reveal_value(entity, value).expect("reveal");
    assert_eq!(shown.value, "Nordstern Consulting GmbH");

    let first = reveal_state().expect("state");
    assert_eq!(first.value_id, Some(value), "the core does not know what it revealed");
    assert!(first.remaining_ms > 0 && first.remaining_ms <= 3_000, "{}", first.remaining_ms);

    // It goes down, read from the clock rather than counted.
    std::thread::sleep(std::time::Duration::from_millis(600));
    let later = reveal_state().expect("state");
    assert!(
        later.remaining_ms < first.remaining_ms,
        "the remaining time did not move: {} then {}",
        first.remaining_ms,
        later.remaining_ms
    );

    // And when the window is over the core says so, whatever anyone's timer
    // believes. This is the honesty test: the screen cannot extend a reveal.
    std::thread::sleep(std::time::Duration::from_millis(2_600));
    let over = reveal_state().expect("state");
    assert_eq!(over.remaining_ms, 0, "the reveal outlived its window");
    assert!(over.value_id.is_none(), "an expired reveal is still named");
}

#[test]
fn hiding_by_hand_ends_it_at_once() {
    let _guard = serial();
    let (entity, value) = a_value(60);
    reveal_value(entity, value).expect("reveal");
    assert!(reveal_state().expect("state").remaining_ms > 0);

    hide_value().expect("hide");
    let state = reveal_state().expect("state");
    assert_eq!(state.remaining_ms, 0);
    assert!(state.value_id.is_none());
}

#[test]
fn revealing_again_gets_a_fresh_window() {
    let _guard = serial();
    let (entity, value) = a_value(3);
    reveal_value(entity, value).expect("reveal");
    std::thread::sleep(std::time::Duration::from_millis(900));
    let worn = reveal_state().expect("state").remaining_ms;

    reveal_value(entity, value).expect("reveal again");
    let fresh = reveal_state().expect("state").remaining_ms;
    assert!(fresh > worn, "a second reveal did not start a new window: {worn} then {fresh}");
}

/// One at a time. Revealing a second value ends the first, so two secrets are
/// never on screen at once because a screen forgot to clear one.
#[test]
fn only_one_value_is_revealed_at_a_time() {
    let _guard = serial();
    let (entity, first) = a_value(60);
    let second = set_value(entity, None, Kind::Person, "Thomas Müller".to_string(), Policy::Always)
        .expect("second value");

    reveal_value(entity, first).expect("reveal first");
    reveal_value(entity, second).expect("reveal second");
    assert_eq!(reveal_state().expect("state").value_id, Some(second));
}

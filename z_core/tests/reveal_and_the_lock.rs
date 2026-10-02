// A reveal does not outlive the vault it came from.
//
// The behaviour board of 27 September wrote three ways a reveal ends: the
// window, losing focus, and **locking the vault**. Only the first was ever
// built. What the code did instead: `core.revealed` was held beside the vault,
// not inside it, so `lock()` closed the vault and left the reveal standing —
// and `vault_lock()` is not even the path that matters, because the auto-lock
// fires inside `Vault::tick()` and never passes through it.
//
// Two mistakes are easy here, and both are tested below:
//
//   * fixing only the lock a person presses, and leaving the clock's own lock
//     holding a revealed secret;
//   * fixing it by having the reveal *ask* the vault, which would make every
//     250ms poll from the screen count as use — a reveal on screen would then
//     postpone the auto-lock for as long as it was there, which is worse than
//     the bug it replaced.
//
// The reveal window here is 300 seconds — the longest a person can set — so
// that nothing below can pass because a window quietly ran out on its own.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für das Schloss";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// A vault with one value in it, a reveal window, and an auto-lock limit.
///
/// `auto_lock_minutes = 0` means never, which is how the tests about the hand
/// keep the clock out of their way.
fn a_value(reveal_seconds: u32, auto_lock_minutes: u32) -> (u32, u32) {
    // One `Core` serves every test in this binary, so whatever the test before
    // left revealed is still revealed. `serial()` orders them; it does not
    // reset them.
    let _ = hide_value();
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-reveal-lock-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");

    let current = settings().expect("settings");
    save_settings(Settings { reveal_seconds, auto_lock_minutes, ..current }).expect("save");

    let entity = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("entity");
    let value = set_value(entity, None, Kind::Company, "Nordstern Consulting GmbH".to_string(), Policy::Always)
        .expect("value");
    (entity, value)
}

fn reveal_one(entity: u32, value: u32) {
    reveal_value(entity, value).expect("reveal");
    let state = reveal_state().expect("state");
    assert!(state.remaining_ms > 0, "the reveal did not start");
}

#[test]
fn a_reveal_ends_when_the_vault_is_locked_by_hand() {
    let _guard = serial();
    let (entity, value) = a_value(300, 0);
    reveal_one(entity, value);

    vault_lock().expect("lock");

    let state = reveal_state().expect("state");
    assert!(state.value_id.is_none(), "a value is still revealed from a locked vault");
    assert_eq!(state.remaining_ms, 0, "the reveal is still counting after the lock");
}

/// The case the owner's reading of the paper actually describes, and the one a
/// line in `vault_lock()` would never have reached: the vault locks itself.
#[test]
#[cfg(feature = "test_clock")]
fn a_reveal_ends_when_the_vault_locks_itself() {
    let _guard = serial();
    // A window of five minutes against a limit of one: both are offered on the
    // same settings page, so this is a setting a person can really hold.
    let (entity, value) = a_value(300, 1);
    reveal_one(entity, value);

    z_core::test_clock::age_vault_unused(61);

    let state = reveal_state().expect("state");
    assert!(state.value_id.is_none(), "the reveal outlived the vault's own lock");
    assert_eq!(state.remaining_ms, 0);
}

/// The trap in the obvious fix. If asking about the reveal counts as using the
/// vault, a screen that polls four times a second holds the vault open for as
/// long as the value is on it.
#[test]
#[cfg(feature = "test_clock")]
fn asking_about_a_reveal_does_not_postpone_the_lock() {
    let _guard = serial();
    let (entity, value) = a_value(300, 1);
    reveal_one(entity, value);

    // A minute of the screen's own polling, one second at a time: sixty-one
    // asks and sixty-one seconds. If the ask renews the clock, the limit is
    // never reached and the vault stays open forever.
    for _ in 0..61 {
        z_core::test_clock::age_vault_unused(1);
        let _ = reveal_state().expect("state");
    }

    assert_eq!(
        vault_state().expect("state"),
        VaultState::Locked,
        "asking about the reveal kept the vault open past its limit"
    );
}

/// The shape of the truthfulness class: two independent reports of one fact
/// have to agree. The reveal is asked **first**, so the answer cannot be the
/// one a prior `vault_state()` had already corrected.
#[test]
#[cfg(feature = "test_clock")]
fn the_vault_and_the_reveal_tell_one_story() {
    let _guard = serial();
    let (entity, value) = a_value(300, 1);
    reveal_one(entity, value);

    z_core::test_clock::age_vault_unused(61);

    let reveal = reveal_state().expect("reveal state");
    let vault = vault_state().expect("vault state");
    assert!(
        !(vault == VaultState::Locked && reveal.value_id.is_some()),
        "the vault says locked and the reveal says {:?} is on screen",
        reveal.value_id
    );
    assert_eq!(vault, VaultState::Locked);
    assert_eq!(reveal.remaining_ms, 0);
}

/// True by construction once the reveal lives inside the open state — and the
/// test is here so that moving the field back tomorrow is loud.
#[test]
fn a_reveal_does_not_come_back_when_the_vault_is_opened_again() {
    let _guard = serial();
    let (entity, value) = a_value(300, 0);
    reveal_one(entity, value);

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");

    let state = reveal_state().expect("state");
    assert!(state.value_id.is_none(), "an old reveal came back with the vault");
}

/// Hiding is not a way in. A person pressing «Hide» on a vault that locked
/// itself a second ago must not be answered with a refusal about the vault.
#[test]
fn hiding_while_the_vault_is_locked_is_no_error_and_no_trace() {
    let _guard = serial();
    let (entity, value) = a_value(300, 0);
    reveal_one(entity, value);

    vault_lock().expect("lock");
    hide_value().expect("hiding after a lock must not be an error");

    let state = reveal_state().expect("state");
    assert_eq!(state.remaining_ms, 0);
}

/// The seam itself, held to its promise: it can only bring the lock closer.
#[test]
#[cfg(feature = "test_clock")]
fn the_test_clock_can_only_bring_the_lock_closer() {
    let _guard = serial();
    let (entity, value) = a_value(300, 1);
    reveal_one(entity, value);

    z_core::test_clock::age_vault_unused(30);
    assert_eq!(
        vault_state().expect("state"),
        VaultState::Unlocked,
        "thirty seconds is not a minute, and the seam locked early"
    );

    // That read counted as use, so the clock starts again from here.
    z_core::test_clock::age_vault_unused(61);
    assert_eq!(vault_state().expect("state"), VaultState::Locked);

    // And ageing a locked vault brings nothing back.
    z_core::test_clock::age_vault_unused(61);
    assert_eq!(vault_state().expect("state"), VaultState::Locked);
}

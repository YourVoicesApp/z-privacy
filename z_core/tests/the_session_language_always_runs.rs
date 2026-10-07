// 046/A · the language a person chose in the bar is the language that runs.
//
// Measured by the lead on `fad220f`, with a client profile open and English
// chosen: `Client number`, `Account number` and `VAT number` were not found at
// all, and three telephone numbers that are automatic without a profile became
// three questions. Nothing was wrong with the English rows. They were never
// asked.
//
// Two facts met:
//
//   * `active_sets` let the profile's language list **replace** the session's;
//   * `create_profile` was born `vec![default_pack_id()]` — on this device,
//     German — so every client made on an English document was a German client.
//
// So the one place where «German only» was still true in this build was not in
// a pack or a rule set. It was in the profile.
//
// The rule these tests hold: **the session's language is always active, and the
// profile's languages are added to it.** A letter can be German and English at
// once — the comment above `scan` already said so — and a list that replaces
// cannot say that.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for the film";

/// Both labels in one document: an English row (`en-16`) and a German one
/// (`de-14`). Which of them is found says which sets ran.
const BOTH: &str = "Client number: 440821\nKundennummer: 7781\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-film-lang-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// The values found in this document, as the text they cover.
fn found(session: SessionId, doc: &str) -> Vec<String> {
    let mut out: Vec<String> = list_findings(session)
        .expect("findings")
        .into_iter()
        .map(|f| {
            doc.chars()
                .skip(f.span.start as usize)
                .take((f.span.end - f.span.start) as usize)
                .collect::<String>()
        })
        .collect();
    out.sort();
    out
}

fn scanned(profile: Option<&str>, pack: &str, doc: &str) -> SessionId {
    let s = open_session(profile.map(str::to_string), pack.to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    s
}

fn languages_of(profile: &str) -> Vec<String> {
    profiles()
        .expect("profiles")
        .into_iter()
        .find(|p| p.id == profile)
        .expect("the profile we just made")
        .languages
}

// ---------------------------------------------------------------- 1 · the film

/// **The acceptance the lead wrote: a profile session in `en` finds the client
/// number.**
///
/// This is the first line of the film. The owner opens the client's document,
/// English is chosen in the bar, and `Client number: 440821` is protected
/// without being asked about. Before this change the profile's German list
/// replaced `en`, so `en-16` never ran and the number went to the model.
#[test]
fn a_profile_does_not_silence_the_session_language() {
    let _g = serial();
    fresh_vault("silence");
    let p = create_profile("Harrow Lane Logistics".to_string(), None).expect("profile");
    // The profile is deliberately left as a German one, which is what the old
    // `create_profile` made and what every vault written before today holds.
    set_profile_languages(p.clone(), vec!["de".to_string()]).expect("languages");

    let s = scanned(Some(&p), "en", BOTH);
    let values = found(s, BOTH);
    assert!(
        values.iter().any(|v| v == "440821"),
        "the English client number was not found in an English session: {values:?}"
    );
    close_session(s).ok();
}

/// **And the profile's own languages are added, not traded away.**
///
/// The same scan finds the German number too. This is the half that must not be
/// lost while fixing the other half: a firm's languages are a property of the
/// client, and a letter may be in two languages at once.
#[test]
fn the_profile_languages_are_added_to_the_session() {
    let _g = serial();
    fresh_vault("added");
    let p = create_profile("Harrow Lane Logistics".to_string(), None).expect("profile");
    set_profile_languages(p.clone(), vec!["de".to_string()]).expect("languages");

    let s = scanned(Some(&p), "en", BOTH);
    let values = found(s, BOTH);
    assert!(
        values.iter().any(|v| v == "440821") && values.iter().any(|v| v == "7781"),
        "one language ran and the other did not: {values:?}"
    );
    close_session(s).ok();
}

/// A control, so the two tests above measure the profile and nothing else: with
/// no profile at all, the English session has always found the English row.
#[test]
fn without_a_profile_the_session_language_already_ran() {
    let _g = serial();
    fresh_vault("control");
    let s = scanned(None, "en", BOTH);
    let values = found(s, BOTH);
    assert!(
        values.iter().any(|v| v == "440821"),
        "the control is broken: English does not find its own row even with no profile: {values:?}"
    );
    assert!(
        !values.iter().any(|v| v == "7781"),
        "a German row ran in a session with no profile and no German: {values:?}"
    );
    close_session(s).ok();
}

/// The same value is not found twice when the profile lists the session's own
/// language. A duplicate here would be two marks on one number, and the person
/// would have to act twice on one fact.
#[test]
fn a_language_listed_twice_is_still_one_language() {
    let _g = serial();
    fresh_vault("twice");
    let p = create_profile("Harrow Lane Logistics".to_string(), None).expect("profile");
    set_profile_languages(p.clone(), vec!["en".to_string(), "de".to_string()])
        .expect("languages");

    let s = scanned(Some(&p), "en", BOTH);
    let values = found(s, BOTH);
    assert_eq!(
        values.iter().filter(|v| v.as_str() == "440821").count(),
        1,
        "the client number was found more than once: {values:?}"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 2 · the birth

/// **A client made while reading an English document is an English client.**
///
/// The old line was `vec![default_pack_id()]` — the device's pack, which on the
/// owner's machine is German. It was not a wrong default so much as a default
/// that could not be right: the one thing the app knows at that moment is the
/// language of the document in front of the person.
#[test]
fn a_new_profile_is_born_in_the_language_of_its_session() {
    let _g = serial();
    fresh_vault("birth");
    let s = open_session(None, "en".to_string()).expect("open");
    let p = create_profile("Harrow Lane Logistics".to_string(), Some(s)).expect("profile");
    assert_eq!(
        languages_of(&p),
        vec!["en".to_string()],
        "the client was born in a language nobody had chosen"
    );
    close_session(s).ok();
}

/// And with no session to ask — the vault screen, where a client can be made
/// before any document is open — the device's pack is still the answer.
#[test]
fn with_no_session_the_device_pack_is_still_the_fallback() {
    let _g = serial();
    fresh_vault("fallback");
    let p = create_profile("Harrow Lane Logistics".to_string(), None).expect("profile");
    assert_eq!(
        languages_of(&p),
        vec![settings().expect("settings").pack_id],
        "a profile made with no document open did not take the device's language"
    );
}

/// A handle that no longer names a session must not quietly become German
/// either: it is a mistake by the caller, and the answer is the device's pack,
/// which is the same answer as «no session at all».
#[test]
fn a_closed_session_falls_back_rather_than_guessing() {
    let _g = serial();
    fresh_vault("closed");
    let s = open_session(None, "en".to_string()).expect("open");
    close_session(s).ok();
    let p = create_profile("Harrow Lane Logistics".to_string(), Some(s)).expect("profile");
    assert_eq!(
        languages_of(&p),
        vec![settings().expect("settings").pack_id],
        "a dead session handle decided a client's languages"
    );
}

// 046/U item 1 · an answer this conversation cannot restore says so.
//
// **The owner, 7 October:** «ما نحتاجه فعلاً هو إعادة فكّ تشفير الوثيقة في حال
// ابتعدتُ لعدة أيام وكان هناك وثائق أخرى في هذه المدة.»
//
// The lead measured it on the merge of `97a1367`: the same document, the same
// client, the value protected at `Scope::Profile` so the **vault keeps it** —
// and days later the tokens have different names, so Tuesday's answer restores
// on Friday to a sentence with `__Z_5CDD_IBAN_5B32__` standing in the middle
// of it. **No error, no warning, nothing.**
//
// Two faults. The token is minted per session, so a value the vault keeps
// still gets a new name next time — that is item 2, and it is not touched
// here. This file is item 1, the half that **stops a lie today**: a person who
// pastes an answer we cannot restore must be told, by name, how many tokens
// this conversation does not know. One line in `tokens::restore` said «not
// ours: it stays word for word», and that line is why a token can be read as
// the model's own words.
//
// The measurement below is the lead's, written as a test: two sessions of the
// same profile, the same value, and the answer from the first pasted into the
// second.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for two days apart";

const LETTER: &str = "Sehr geehrte Frau Hedvig Palmgren,\n\
der Kontostand von GB29 NWBK 6016 1331 9268 19 beträgt 42 500 EUR.\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-days-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

fn span_of(text: &str, what: &str) -> Span {
    let at = text.find(what).expect("the value is in the letter");
    Span {
        start: text[..at].encode_utf16().count() as u32,
        end: text[..at + what.len()].encode_utf16().count() as u32,
    }
}

/// One working day: open the document in this profile, protect the IBAN so the
/// **vault keeps it**, and build what would go to the model.
fn a_day(profile: &str) -> (SessionId, PayloadHandle, String) {
    let s = open_session(Some(profile.to_string()), "de".to_string()).expect("session");
    import_text(s, LETTER.to_string()).expect("import");
    scan(s).expect("scan");
    protect(s, span_of(LETTER, "GB29 NWBK 6016 1331 9268 19"), Scope::Profile, Kind::Iban)
        .expect("protect the account");
    let handle = build_payload(s).expect("payload");
    let text = payload_view(handle).expect("the text").text;
    (s, handle, text)
}

fn token_in(text: &str, kind: &str) -> String {
    for word in text.split_whitespace() {
        let word = word.trim_matches(|c: char| !c.is_ascii_alphanumeric() && c != '_');
        if word.starts_with("__Z_") && word.ends_with("__") && word.contains(kind) {
            return word.to_string();
        }
    }
    panic!("no {kind} token in «{text}»");
}

/// **The lead's measurement, as it stands today.**
///
/// Not a fix and not a wish: the token's name is minted per session, so the
/// same value in the same client is a different token the next day. It is
/// recorded here because item 2 is about to change it, and a property nobody
/// wrote down is a property nobody can prove changed.
#[test]
fn today_the_same_value_gets_a_new_token_the_next_day() {
    let _g = serial();
    fresh_vault("renamed");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    let (first, _, monday) = a_day(&profile);
    let was = token_in(&monday, "_IBAN_");
    close_session(first).ok();

    let (second, _, friday) = a_day(&profile);
    let now = token_in(&friday, "_IBAN_");
    close_session(second).ok();

    assert_ne!(
        was, now,
        "the token is stable already, so item 2 is either done or this test is measuring nothing"
    );
    vault_lock().ok();
}

/// **The fault this file closes.** Monday's answer, pasted on Friday.
///
/// It must not come back as if the model had written `__Z_…__` in the middle
/// of a sentence. The view reports every token it could not resolve, by name,
/// and the piece carrying one is **not** the model's own words.
#[test]
fn an_answer_from_another_conversation_is_reported_and_not_passed_through() {
    let _g = serial();
    fresh_vault("reported");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    let (monday, _, monday_text) = a_day(&profile);
    let old_iban = token_in(&monday_text, "_IBAN_");
    let old_person = token_in(&monday_text, "_PERSON_");
    close_session(monday).ok();

    // Friday. The same letter, the same client — and the model's answer from
    // Monday is what he has in front of him.
    let (friday, handle, _) = a_day(&profile);
    let from_monday = format!("I checked {old_iban} for {old_person}: the balance is 42 500.");
    let answer = ingest_answer(handle, from_monday.clone()).expect("ingest");

    let snap = answer_snapshot(friday, answer).expect("the snapshot");

    // **Reported, by name.** Both of them, and nothing else.
    assert_eq!(
        snap.unknown_tokens.len(),
        2,
        "the view reports {:?} of the two tokens it cannot resolve",
        snap.unknown_tokens
    );
    assert!(snap.unknown_tokens.contains(&old_iban), "{:?}", snap.unknown_tokens);
    assert!(snap.unknown_tokens.contains(&old_person), "{:?}", snap.unknown_tokens);

    // **And not passed through as the answer.** The piece that holds the token
    // says what it is, so no screen can draw it as the model's own words.
    let unresolved: Vec<&Segment> = snap
        .restored
        .iter()
        .filter(|seg| seg.piece == Piece::Unresolved)
        .collect();
    assert_eq!(unresolved.len(), 2, "{:?}", snap.restored.iter().map(|s| &s.text).collect::<Vec<_>>());
    assert!(unresolved.iter().any(|s| s.text == old_iban));
    assert!(unresolved.iter().any(|s| s.text == old_person));
    // Nothing was invented and nothing was dropped: the answer still reads as
    // the model wrote it.
    let whole: String = snap.restored.iter().map(|s| s.text.as_str()).collect();
    assert_eq!(whole, from_monday, "the restored view is no longer the answer");

    close_session(friday).ok();
    vault_lock().ok();
}

/// **The control.** An answer carrying **this** conversation's own tokens
/// restores, reports nothing, and is not marked — so the test above fails for
/// the reason it names and not because every token is now called unknown.
#[test]
fn this_conversation_s_own_answer_still_restores_with_nothing_reported() {
    let _g = serial();
    fresh_vault("control");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    let (today, handle, text) = a_day(&profile);
    let iban = token_in(&text, "_IBAN_");
    let answer = ingest_answer(handle, format!("I checked {iban}: the balance is 42 500."))
        .expect("ingest");
    let snap = answer_snapshot(today, answer).expect("the snapshot");

    assert!(snap.unknown_tokens.is_empty(), "{:?}", snap.unknown_tokens);
    assert!(
        snap.restored.iter().any(|s| s.piece == Piece::Restored && s.text.contains("GB29")),
        "the account was not put back: {:?}",
        snap.restored.iter().map(|s| &s.text).collect::<Vec<_>>()
    );
    assert!(
        !snap.restored.iter().any(|s| s.piece == Piece::Unresolved),
        "a token of this conversation was called unknown"
    );

    close_session(today).ok();
    vault_lock().ok();
}

/// A word that merely looks like one of ours is **text**, not an unresolved
/// token: the model is free to write `__Z_` in a sentence about tokens, and a
/// warning about that would be a false alarm a person cannot act on.
#[test]
fn something_that_is_not_a_token_is_not_reported() {
    let _g = serial();
    fresh_vault("lookalike");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");
    let (today, handle, _) = a_day(&profile);

    let prose = "Tokens look like __Z_ and end in __, which is how you spot them.".to_string();
    let answer = ingest_answer(handle, prose.clone()).expect("ingest");
    let snap = answer_snapshot(today, answer).expect("the snapshot");

    assert!(snap.unknown_tokens.is_empty(), "{:?}", snap.unknown_tokens);
    let whole: String = snap.restored.iter().map(|s| s.text.as_str()).collect();
    assert_eq!(whole, prose);

    close_session(today).ok();
    vault_lock().ok();
}

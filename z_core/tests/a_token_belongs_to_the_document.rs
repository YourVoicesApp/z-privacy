// 046/U item 2 · a token's name comes from the value and the document, not
// from the conversation.
//
// **The owner, 7 October:** «ما نحتاجه فعلاً هو إعادة فكّ تشفير الوثيقة في حال
// ابتعدتُ لعدة أيام وكان هناك وثائق أخرى في هذه المدة.»
//
// The lead's shape, chosen over two others and for a reason that is the whole
// design: **stability across days and linkability across requests are the same
// property.** A name derived from the value and the client alone would hand a
// provider «the same hidden person is in these two documents» — and over a
// year of an accountant's work that is the *shape* of his client book, built
// out of requests we sent ourselves. Not a name, but exactly the class of
// thing this product exists to withhold.
//
// So the name is a keyed function of **(the client, the document's own bytes,
// the value)**, under a key derived from the vault's master key that never
// leaves this crate. Then:
//
//   * the same file, the same client, the same value → the same token for
//     ever, with **nothing stored**;
//   * a file moved or renamed still restores, because the path was never part
//     of it;
//   * an **edited** file gives new names — honest, because it is a different
//     document, and 046/U item 1 makes that case say so instead of passing the
//     old tokens through as prose. Item 1 is what lets item 2 be strict.
//   * two clients never share a name for the same spelling, which the
//     per-session prefix was only providing by accident.
//
// **The cost, named here because a later round will meet it:** when one
// conversation spans two documents — «compare this payroll with last month's»
// — the same person carries two different names and a model cannot tell they
// are one. Nothing is lost today, because `Context.workspace` goes out empty.
// Whoever builds multi-document context must decide this deliberately rather
// than discover it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a stable name";

const LETTER: &str = "Sehr geehrte Frau Hedvig Palmgren,\n\
der Kontostand von GB29 NWBK 6016 1331 9268 19 beträgt 42 500 EUR.\n";

/// The same letter with one word changed. A different document, so different
/// names — and item 1 is what makes that safe to say.
const EDITED: &str = "Sehr geehrte Frau Hedvig Palmgren,\n\
der Kontostand von GB29 NWBK 6016 1331 9268 19 beträgt 42 900 EUR.\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-stable-{name}-{}", std::process::id()));
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

const IBAN: &str = "GB29 NWBK 6016 1331 9268 19";

/// One working day with **no session open**, which since 064 is the state in
/// which a name is random: the only test below that wants it is the one about a
/// shut vault. Every other day goes through `a_day_in`, because a name only
/// becomes stable inside a session now.
fn a_day_at(profile: Option<&str>, document: &str, scope: Scope) -> String {
    let s = open_session(profile.map(str::to_string), "de".to_string()).expect("session");
    import_text(s, document.to_string()).expect("import");
    scan(s).expect("scan");
    let outcome = protect(s, span_of(document, IBAN), scope, Kind::Iban).expect("protect");
    let token = match outcome {
        ProtectOutcome::Applied { token, .. } | ProtectOutcome::AlreadyProtected { token, .. } => token,
        other => panic!("the account was not protected: {other:?}"),
    };
    close_session(s).ok();
    token
}

/// One day's work, in a named session — 064.
///
/// `talk: None` begins a session; `Some(n)` enters that one. Every day in this
/// file now happens **inside** a session, because that is where a token's name
/// comes from since 064: the document's text and the client are no longer
/// inputs to it at all.
fn a_day_in(talk: Option<u32>, profile: Option<&str>, document: &str) -> (u32, String) {
    let s = open_session(profile.map(str::to_string), "de".to_string()).expect("session");
    import_text(s, document.to_string()).expect("import");
    scan(s).expect("scan");
    let number = match talk {
        Some(n) => {
            conversation_enter(n, Some(s)).expect("enter");
            n
        }
        None => conversation_begin("dagens arbete".to_string(), Some(s))
            .expect("begin")
            .number,
    };
    let outcome = protect(s, span_of(document, IBAN), Scope::Profile, Kind::Iban).expect("protect");
    let token = match outcome {
        ProtectOutcome::Applied { token, .. } | ProtectOutcome::AlreadyProtected { token, .. } => token,
        other => panic!("the account was not protected: {other:?}"),
    };
    close_session(s).ok();
    (number, token)
}

/// **The property the owner asked for, and 064 moved its unit.**
///
/// It read: *days apart, other documents in between, and the same file opened
/// again — the same token.* The unit was the document's own text. Since 064 it
/// is **the session**, by his own ruling «كل جلسة لها تشفيرها», so the sentence
/// now reads: days apart, other documents in between, and the same **session**
/// entered again — the same token. Nothing stored between the two, exactly as
/// before.
///
/// Both halves are kept here on purpose. A reader who finds only the new one
/// cannot tell that the old property was given up deliberately rather than
/// lost.
#[test]
fn the_same_session_gives_the_same_token_days_apart() {
    let _g = serial();
    fresh_vault("stable");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    let (talk, monday) = a_day_in(None, Some(&profile), LETTER);
    // Other work in between, in the same client and in another document, which
    // is the case his sentence names.
    let _other = a_day_in(Some(talk), Some(&profile), EDITED);
    let (_, friday) = a_day_in(Some(talk), Some(&profile), LETTER);

    assert_eq!(monday, friday, "the same value in the same session got a new name");

    // And the vault being shut and opened again does not move it: the key is in
    // the vault, so «days apart» survives a lock, which is what 062 §D asked.
    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    let (_, next_week) = a_day_in(Some(talk), Some(&profile), LETTER);
    assert_eq!(monday, next_week, "a lock and an unlock lost the session's names");
    vault_lock().ok();
}

/// **Two sessions never share a name for the same spelling** — which is where
/// 046/U's between-clients property went.
///
/// It used to be two *clients*: the client was in the namespace, so one
/// spelling in two clients took two names. 064 took the client out and put the
/// session in, so the guarantee is now drawn where the person draws it — by
/// starting a session.
#[test]
fn two_sessions_do_not_share_a_name_for_the_same_value() {
    let _g = serial();
    fresh_vault("clients");
    let one = create_profile("Nordstern".to_string(), None).expect("profile one");
    let two = create_profile("Lindqvist".to_string(), None).expect("profile two");

    let (first, in_one) = a_day_in(None, Some(&one), LETTER);
    let (second, in_two) = a_day_in(None, Some(&two), LETTER);
    assert_ne!(first, second, "the fixture opened one session, not two");

    assert_ne!(in_one, in_two, "two sessions share a token for the same account");
    // And each is still stable in its own session.
    assert_eq!(in_one, a_day_in(Some(first), Some(&one), LETTER).1);
    assert_eq!(in_two, a_day_in(Some(second), Some(&two), LETTER).1);
    vault_lock().ok();
}

/// **And the thing 064 gave up, pinned so it cannot be given up by accident
/// twice:** two clients *inside one session* now share a name for one spelling.
///
/// This is not a defect and the assertion is not a wish — it is the record of a
/// decision. The owner's ruling makes the session the unit of linkability, so a
/// person who puts two clients in one session has chosen that, visibly, by
/// doing it. Before 064 the client was in the namespace and this was `assert_ne`.
/// If someone ever needs it back, this line is where they will find out that it
/// was deliberate.
#[test]
fn two_clients_in_one_session_now_share_a_name() {
    let _g = serial();
    fresh_vault("one-room");
    let one = create_profile("Nordstern".to_string(), None).expect("profile one");
    let two = create_profile("Lindqvist".to_string(), None).expect("profile two");

    let (talk, in_one) = a_day_in(None, Some(&one), LETTER);
    let (_, in_two) = a_day_in(Some(talk), Some(&two), LETTER);

    assert_eq!(
        in_one, in_two,
        "two clients in one session took two names — which 064 removed on purpose, so either          this is a regression or the ruling changed and this test should say so"
    );
    vault_lock().ok();
}

/// **This one inverted, and that is the whole of 064.**
///
/// It read: *a different document gives a different name, which is what keeps
/// the shape of a client's book out of a provider's hands.* The document's text
/// was in the namespace, so one value in two files took two names — and 046/U
/// wrote down the cost it could not pay: one conversation spanning two
/// documents gave the same person two names and a model could not tell they
/// were one.
///
/// 064 pays it. **Inside one session the name is the same across documents**,
/// which is the owner's continuity; **across sessions it differs**, which is
/// what keeps the book out of a provider's hands. The protection did not go
/// away — the person now draws the line, where before we drew it for them.
#[test]
fn another_document_in_the_same_session_keeps_the_name() {
    let _g = serial();
    fresh_vault("documents");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    let (talk, here) = a_day_in(None, Some(&profile), LETTER);
    let (_, there) = a_day_in(Some(talk), Some(&profile), EDITED);
    assert_eq!(
        here, there,
        "two documents in one session gave one value two names, so a model cannot tell they are          the same person — the cost 046/U wrote down and 064 exists to pay"
    );

    // And the half that did not change: another session, another name, so a
    // provider holding a year of requests still cannot line the two up.
    let (_, elsewhere) = a_day_in(None, Some(&profile), EDITED);
    assert_ne!(
        here, elsewhere,
        "two sessions share a name for one value, so the shape of a client's book is visible          to whoever holds the requests"
    );
    vault_lock().ok();
}

/// **The document's bytes are not an input any more, not even by one space.**
///
/// It read: *the path was never part of it, so a file moved or renamed still
/// restores — the document is its bytes*, and it proved that one extra byte was
/// enough to separate two names. Since 064 neither the path nor the bytes are
/// in the namespace, so a document and the same document plus a space keep
/// **one** name inside a session. The old safety net — an edited document
/// honestly getting new names — moves to 062 §C's refusal, which says what
/// happened where a changed name merely failed to resolve.
#[test]
fn an_edited_document_keeps_its_name_inside_the_session() {
    let _g = serial();
    fresh_vault("bytes");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    let (talk, same) = a_day_in(None, Some(&profile), LETTER);
    let (_, with_a_space) = a_day_in(Some(talk), Some(&profile), &format!("{LETTER} "));
    assert_eq!(
        same, with_a_space,
        "one space changed the name, so the document's bytes are still in the namespace"
    );

    // And the session says its document moved, which is the net that replaced
    // the changed name. `None` would mean «nothing to compare» and is not «yes».
    let s = open_session(Some(profile), "de".to_string()).expect("session");
    import_text(s, format!("{LETTER} ")).expect("import");
    conversation_enter(talk, Some(s)).expect("enter");
    assert_eq!(
        conversation_document_matches(s).expect("asked"),
        Some(false),
        "the session did not notice that its document is not the one it began with"
    );
    close_session(s).ok();
    vault_lock().ok();
}

/// **A locked vault has no key, so there is no derived name** — and the token
/// falls back to the random one it always was.
///
/// Said out loud rather than left to be discovered: restoration across days
/// works for what the vault keeps, and with the vault shut it keeps nothing.
#[test]
fn without_a_vault_the_name_is_random_again() {
    let _g = serial();
    fresh_vault("locked");
    vault_lock().expect("lock");

    // `Conversation` and not `Profile`: keeping a value for a client needs the
    // vault open, so with it shut the only scopes that exist are the ones that
    // store nothing — which is item 3's rule arriving as a compile-time fact.
    let first = a_day_at(None, LETTER, Scope::Conversation);
    let second = a_day_at(None, LETTER, Scope::Conversation);
    assert_ne!(
        first, second,
        "a name was stable with the vault locked, which means it came from somewhere else"
    );
}

/// The shape is unchanged where it matters: the kind still travels in the
/// name, and the whole thing is still one word a model will not break.
#[test]
fn the_shape_still_carries_the_kind() {
    let _g = serial();
    fresh_vault("shape");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");
    let (_, token) = a_day_in(None, Some(&profile), LETTER);

    assert!(token.starts_with("__Z_"), "{token}");
    assert!(token.ends_with("__"), "{token}");
    assert!(token.contains("_IBAN_"), "{token}");
    assert!(!token.contains(IBAN), "the value is in its own token: {token}");
    assert!(
        !token.contains(' ') && !token.contains('\n'),
        "a token a model can break in two: {token}"
    );
    vault_lock().ok();
}

/// **And the whole point, end to end:** Monday's answer restores on Friday.
#[test]
fn an_answer_from_monday_restores_on_friday() {
    let _g = serial();
    fresh_vault("restores");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    // Monday: protect, send, and keep what the model said — **in a session**,
    // which is where a name's stability lives since 064. Begun before the
    // payload is built, which is the owner's own order: the session is born at
    // the exit, and the names that leave are the session's names.
    let monday = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(monday, LETTER.to_string()).expect("import");
    scan(monday).expect("scan");
    let talk = conversation_begin("Nordstern-brevet".to_string(), Some(monday))
        .expect("begin")
        .number;
    protect(monday, span_of(LETTER, IBAN), Scope::Profile, Kind::Iban).expect("protect");
    let handle = build_payload(monday).expect("payload");
    let token = payload_view(handle)
        .expect("the text")
        .text
        .split_whitespace()
        .map(|w| w.trim_matches(|c: char| !c.is_ascii_alphanumeric() && c != '_'))
        .find(|w| w.starts_with("__Z_") && w.contains("_IBAN_"))
        .expect("the account's token")
        .to_string();
    let said = format!("I checked {token}: the balance is 42 500.");
    close_session(monday).ok();

    // Friday: the same file, a new bench, the **same session** entered again,
    // and Monday's answer pasted in. Entering asks nothing, by the owner's rule.
    let friday = open_session(Some(profile), "de".to_string()).expect("session");
    import_text(friday, LETTER.to_string()).expect("import");
    scan(friday).expect("scan");
    conversation_enter(talk, Some(friday)).expect("enter");
    protect(friday, span_of(LETTER, IBAN), Scope::Profile, Kind::Iban).expect("protect");
    let fresh = build_payload(friday).expect("payload");
    let answer = ingest_answer(fresh, said).expect("ingest");
    let snap = answer_snapshot(friday, answer).expect("snapshot");

    assert!(
        snap.unknown_tokens.is_empty(),
        "Monday's answer still carries names Friday does not know: {:?}",
        snap.unknown_tokens
    );
    let whole: String = snap.restored.iter().map(|s| s.text.as_str()).collect();
    assert!(whole.contains(IBAN), "the account did not come back: {whole}");
    assert!(
        snap.restored.iter().any(|s| s.piece == Piece::Restored),
        "nothing was marked as put back"
    );
    close_session(friday).ok();
    vault_lock().ok();
}

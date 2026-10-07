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

/// One working day: open this document in this profile, protect the account at
/// `Scope::Profile` so the vault keeps the value, and report the token.
fn a_day(profile: Option<&str>, document: &str) -> String {
    a_day_at(profile, document, Scope::Profile)
}

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

/// **The property the owner asked for.** Days apart, other documents in
/// between, and the same file opened again: the same token, with nothing
/// stored between the two.
#[test]
fn the_same_document_gives_the_same_token_days_apart() {
    let _g = serial();
    fresh_vault("stable");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    let monday = a_day(Some(&profile), LETTER);
    // Other work in between, in the same client and in another document, which
    // is the case his sentence names.
    let _other = a_day(Some(&profile), EDITED);
    let friday = a_day(Some(&profile), LETTER);

    assert_eq!(monday, friday, "the same value in the same file got a new name");
    vault_lock().ok();
}

/// **Two clients never share a name for the same spelling.**
///
/// The per-session prefix was providing this by accident; losing it while
/// making names stable would be a real leak between clients, so it is a test
/// and not a comment.
#[test]
fn two_clients_do_not_share_a_name_for_the_same_value() {
    let _g = serial();
    fresh_vault("clients");
    let one = create_profile("Nordstern".to_string(), None).expect("profile one");
    let two = create_profile("Lindqvist".to_string(), None).expect("profile two");

    let in_one = a_day(Some(&one), LETTER);
    let in_two = a_day(Some(&two), LETTER);

    assert_ne!(in_one, in_two, "two clients share a token for the same account");
    // And each is still stable in its own client.
    assert_eq!(in_one, a_day(Some(&one), LETTER));
    assert_eq!(in_two, a_day(Some(&two), LETTER));
    vault_lock().ok();
}

/// **A different document gives a different name**, which is what keeps the
/// shape of a client's book out of a provider's hands.
#[test]
fn another_document_gives_another_name_for_the_same_value() {
    let _g = serial();
    fresh_vault("documents");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    let here = a_day(Some(&profile), LETTER);
    let there = a_day(Some(&profile), EDITED);

    assert_ne!(
        here, there,
        "the same value carries one name across two documents, so a provider can line them up"
    );
    vault_lock().ok();
}

/// **The path was never part of it**, so a file moved or renamed still
/// restores. The document is its bytes.
#[test]
fn the_same_bytes_under_another_name_still_restore() {
    let _g = serial();
    fresh_vault("bytes");
    let profile = create_profile("Nordstern".to_string(), None).expect("profile");

    // `import_text` carries no path at all, so the comparison that matters is
    // the same bytes reaching the core twice with nothing else alike about the
    // session. That is what the two days above already prove; what this adds
    // is that one extra byte of difference is enough to separate them.
    let same = a_day(Some(&profile), LETTER);
    let with_a_space = a_day(Some(&profile), &format!("{LETTER} "));
    assert_ne!(same, with_a_space, "a document and a document plus a space are the same document");
    assert_eq!(same, a_day(Some(&profile), LETTER));
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
    let token = a_day(Some(&profile), LETTER);

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

    // Monday: protect, send, and keep what the model said.
    let monday = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(monday, LETTER.to_string()).expect("import");
    scan(monday).expect("scan");
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

    // Friday: the same file, a new conversation, and Monday's answer pasted in.
    let friday = open_session(Some(profile), "de".to_string()).expect("session");
    import_text(friday, LETTER.to_string()).expect("import");
    scan(friday).expect("scan");
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

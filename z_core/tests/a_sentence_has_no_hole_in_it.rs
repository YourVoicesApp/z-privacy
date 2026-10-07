// 046/D · a sentence a person reads is one line of prose.
//
// From the owner's own screen. `protect` with `Scope::Profile` and no client
// open refused with this, verbatim:
//
// ```text
// this conversation is not in a profile, so there is no profile to remember it
//                       for — choose «always», or open a profile first
// ```
//
// **Nineteen spaces inside the sentence**, because the Rust literal was wrapped
// across two lines with no trailing `\` to tell the compiler that the newline
// and the indentation are not part of the string. It is the kind of thing a
// jury sees before it hears anything.
//
// The sweep found a **second** one, which the paper did not know about: the Why
// card's sentence for a protection whose reason no longer exists carried two
// holes of eighteen spaces each. Two sentences were the fix.
//
// The class is held by **gate G25** and `scripts/check_sentences.py`, which
// reads every string literal in the core and works the value out the way rustc
// does — because the fix is two sentences and the gate is what stops the third.
// This file holds the one a person actually met.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein langes Passwort für einen Satz";
const DOC: &str = "Kunde: Nordstern Consulting GmbH\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-sentence-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

/// **The sentence the owner met, read as a person reads it.**
#[test]
fn the_refusal_for_this_client_reads_as_one_sentence() {
    let _g = serial();
    fresh_vault("profile");
    // A session with no client open, which is the whole condition.
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");

    let said = match protect(
        s,
        span_of(DOC, "Nordstern Consulting GmbH"),
        Scope::Profile,
        Kind::Company,
    ) {
        Err(ApiError::InputRefused { reason }) => reason,
        other => panic!("expected a refusal in words, got {other:?}"),
    };

    assert!(
        !said.contains("  "),
        "the refusal carries a run of spaces inside it: {said:?}"
    );
    assert!(
        !said.contains('\n'),
        "the refusal carries a line break a screen would have to guess about: {said:?}"
    );
    // And it still says both ways out, which is what the sentence is for. The
    // hole sat exactly between these two words.
    assert!(said.contains("remember it for"), "{said:?}");
    assert!(said.contains("«always»"), "the way out is not named: {said:?}");
    assert!(said.contains("open a profile first"), "{said:?}");
    close_session(s).ok();
}

/// And every other refusal this path can produce, in the same breath — because
/// one sentence read correctly proves nothing about the next one.
///
/// Three refusals, each for its own reason, each a single line of prose.
#[test]
fn no_refusal_on_this_path_carries_a_hole() {
    let _g = serial();
    fresh_vault("every");
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");

    let mut said: Vec<String> = Vec::new();
    // «This client», with no client.
    if let Err(ApiError::InputRefused { reason }) =
        protect(s, span_of(DOC, "Nordstern"), Scope::Profile, Kind::Company)
    {
        said.push(reason);
    }
    // A book kept for this client, with no client (046/F).
    if let Err(ApiError::InputRefused { reason }) = import_user_names(
        "name,type\nHedvig Palmgren,person\n".to_string(),
        None,
        "sv".to_string(),
        Some(Scope::Profile),
    ) {
        said.push(reason);
    }
    // A scope that is about a place, for a list that has none (046/F).
    if let Err(ApiError::InputRefused { reason }) = import_user_names(
        "name,type\nHedvig Palmgren,person\n".to_string(),
        None,
        "sv".to_string(),
        Some(Scope::Once),
    ) {
        said.push(reason);
    }

    assert_eq!(said.len(), 3, "a refusal on this path stopped refusing: {said:?}");
    for reason in &said {
        assert!(!reason.contains("  "), "a run of spaces: {reason:?}");
        assert!(!reason.contains('\n'), "a line break: {reason:?}");
        assert!(!reason.contains('\t'), "a tab: {reason:?}");
        assert!(
            reason.trim() == reason,
            "a sentence padded at one end: {reason:?}"
        );
    }
    close_session(s).ok();
}

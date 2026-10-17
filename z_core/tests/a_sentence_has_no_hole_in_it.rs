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

/// **A word of the person's own, inside a sentence of ours, is isolated** —
/// the owner's test of 16 October, held as a class on 17 October.
///
/// The glass has `theirOwnWord` and forty sentences went through it; the
/// core's own sentences arrive at the glass **finished**, so a word quoted
/// here and not isolated here can never be isolated at all. His session
/// «ألماني 1» inside an English line drew as «came back from «11 .«ألماني» —
/// every word right and the order nonsense — and the same algorithm is in
/// every reason the scanner writes about a name it found.
///
/// Measured on the surface where it matters most: the Why card's own reason,
/// about a name in a document whose script is not the sentence's. The pair is
/// `U+2068 … U+2069`, and the assertion is that the name stands **between**
/// them rather than anywhere in the line.
#[test]
fn a_reason_that_quotes_a_persons_word_isolates_it() {
    let _g = serial();
    fresh_vault("isolated");
    // An Arabic name after a German title: the reason for it is English prose,
    // and this is the sentence the owner met.
    // **Two names, and the German one is the control.** An Arabic name after a
    // German title is what the owner met, and the pack may or may not shape it
    // as a name; «Müller» after «Herr» it certainly finds, so the sentence
    // this guard reads exists whatever the scanner makes of the other. The law
    // is about every word of theirs, not only the ones in another script.
    const LETTER: &str =
        "Sehr geehrter Herr Müller,\nSehr geehrter Herr مصطفى,\nIhre Akte liegt vor.\n";
    let s = open_session(None, "de".to_string()).expect("open");
    // **The import's own reading, and no second one.** An import scans (14
    // October), and the salutation protects the name after «Herr» on sight —
    // which makes it a block. A second `scan` here would be the second
    // reading, where the block answers first and the sentence becomes «your
    // vault knows this value»: true, and not the sentence this guard is about.
    import_text(s, LETTER.to_string()).expect("import");

    let reasons: Vec<String> = list_findings(s)
        .expect("findings")
        .into_iter()
        .map(|f| f.reason)
        .filter(|reason| reason.contains('«'))
        .collect();
    assert!(
        !reasons.is_empty(),
        "no reason on this document quotes a word, so this guard measures nothing: {:?}",
        list_findings(s).expect("findings").into_iter().map(|f| f.reason).collect::<Vec<_>>()
    );
    // **And the sentence this guard really reads, named** — the first pin
    // aimed at «a title introduces the person who follows it» and the guard
    // stayed green, because the reason in play is the salutation's other
    // wording and the quoted word is built in `pack.said()`. A pin that does
    // not bite is a guard measuring something else than its author thinks.
    for reason in &reasons {
        // Every quoted run is isolated: the opening mark is followed by the
        // first of the pair, and the closing one preceded by the second.
        assert!(
            !reason.contains("«\u{2069}") && !reason.contains("\u{2068}»"),
            "an empty isolate: {reason:?}"
        );
        assert!(
            reason.matches('«').count() == reason.matches('\u{2068}').count(),
            "a word is quoted without being isolated: {reason:?}"
        );
        assert!(
            reason.matches('»').count() == reason.matches('\u{2069}').count(),
            "a quoted word is left open at one end: {reason:?}"
        );
    }
    // And the person's own word really is the thing between the pair, not our
    // sentence around it.
    assert!(
        reasons.iter().any(|reason| reason.contains("\u{2068}مصطفى\u{2069}")
            || reason.contains("\u{2068}Müller\u{2069}")
            || reason.contains("\u{2068}Herr\u{2069}")),
        "no reason has a person's word between the pair: {reasons:?}"
    );
    close_session(s).ok();
}

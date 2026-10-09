// 068 · A figure about the payload comes from the payload.
//
// The owner's rule, at `docs/TASKS/022_shell.md:3`: «لا mock data بعد ربط
// الشاشة — كلّ رقم على الشاشة قاله الـcore», governing that file «and everything
// after it».
//
// **The narrower sentence is the true one.** The protected-PDF footer carries
// three numbers from three origins, and only one of them was a defect:
//
//   places   PayloadView.protected_count      the core
//   sha256   sha256OfText(payload.text)       outside, and CANNOT be wrong —
//                                             a function of the exact string
//                                             being written, same breath, one
//                                             source
//   by kind  payload.text.contains(token)     outside, and COULD be wrong — it
//                                             crossed two sources, the outgoing
//                                             text against the bench's current
//                                             tokens
//
// Measured by the design seat on a payload captured before a session was born:
// the per-kind tally came out **empty** over a fully protected document — a
// footer counting nothing about a file whose every name was hidden. «No
// arithmetic outside the core» would have condemned the sha256, which is
// correct by construction; «a figure about the payload must come from the
// payload» condemns only the one that can disagree with itself.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för en räkning";

/// Two people and one account, so a tally has something to be wrong about.
const DOC: &str = "Kund: Hedvig Palmgren och Tomas Lindqvist.\n\
                   Betalning till GB29 NWBK 6016 1331 9268 19 i oktober.\n\
                   Hedvig Palmgren skriver under.";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-figure-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// Protect one stretch by hand and report the token.
fn protect_text(session: SessionId, doc: &str, what: &str, kind: Kind) -> String {
    let at = doc.find(what).expect("the fixture must contain it");
    let outcome = protect(
        session,
        Span { start: at as u32, end: (at + what.len()) as u32 },
        Scope::Conversation,
        kind,
    )
    .expect("protect");
    match outcome {
        ProtectOutcome::Applied { token, .. } | ProtectOutcome::AlreadyProtected { token, .. } => token,
        other => panic!("«{what}» was not protected: {other:?}"),
    }
}

fn count_of(view: &PayloadView, kind: Kind) -> u32 {
    view.by_kind.iter().find(|t| t.kind == kind).map(|t| t.count).unwrap_or(0)
}

// ------------------------------------------------------------------ the tally

/// **The footer's own numbers, from the payload that the footer describes.**
///
/// Distinct tokens, not places: «Hedvig Palmgren» stands twice in this document
/// and is one token, while `protected_count` counts both places. The two answer
/// different questions and the footer shows both, so the test holds both.
#[test]
fn a_payload_counts_the_kinds_standing_in_its_own_text() {
    let _g = serial();
    fresh_vault("tally");

    let s = open_session(None, "sv".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    let one = protect_text(s, DOC, "Hedvig Palmgren", Kind::Person);
    let two = protect_text(s, DOC, "Tomas Lindqvist", Kind::Person);
    let iban = protect_text(s, DOC, "GB29 NWBK 6016 1331 9268 19", Kind::Iban);
    assert_ne!(one, two, "the fixture gave two people one token");

    let view = payload_view(build_payload(s).expect("build")).expect("view");

    assert_eq!(
        count_of(&view, Kind::Person),
        2,
        "two people stand in this text and the tally says {:?}",
        view.by_kind
    );
    assert_eq!(count_of(&view, Kind::Iban), 1, "the account was not counted: {:?}", view.by_kind);
    assert_eq!(
        count_of(&view, Kind::Email),
        0,
        "a kind that is not in the text was counted: {:?}",
        view.by_kind
    );

    // Every token the tally counts really is in the text that will leave — the
    // whole of «a figure about the payload comes from the payload».
    for token in [&one, &two, &iban] {
        assert!(
            view.text.contains(token),
            "the tally counted «{token}», which does not stand in the outgoing text"
        );
    }

    // Distinct tokens, and places, are different numbers here — which is why
    // neither can stand in for the other in the footer.
    let distinct: u32 = view.by_kind.iter().map(|t| t.count).sum();
    assert_eq!(distinct, 3, "three names stand in this text: {:?}", view.by_kind);
    assert_eq!(
        view.protected_count, 4,
        "«Hedvig Palmgren» stands twice, so there are four places for three tokens"
    );
    close_session(s).ok();
}

/// **And a payload built before a protection does not count it.**
///
/// This is the shape of the defect the tally replaces: a figure taken from one
/// moment and a text from another. Here both come from the same build, so the
/// older payload counts what stood in *it* — not what stands in the bench now.
#[test]
fn an_older_payload_counts_what_stood_in_itself() {
    let _g = serial();
    fresh_vault("older");

    let s = open_session(None, "sv".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    protect_text(s, DOC, "Hedvig Palmgren", Kind::Person);
    let before = payload_view(build_payload(s).expect("build")).expect("view");
    assert_eq!(count_of(&before, Kind::Person), 1);
    assert_eq!(count_of(&before, Kind::Iban), 0);

    // A second protection, and a second payload.
    protect_text(s, DOC, "GB29 NWBK 6016 1331 9268 19", Kind::Iban);
    let after = payload_view(build_payload(s).expect("build")).expect("view");
    assert_eq!(count_of(&after, Kind::Iban), 1, "the new account is not counted: {:?}", after.by_kind);

    // The older view still describes itself, and its text really lacks the
    // account's token — so a footer built from it would be true of its own file.
    assert_eq!(
        count_of(&before, Kind::Iban),
        0,
        "an older payload's tally changed under it, so the figure is not about that payload"
    );
    assert!(
        before.text.contains("GB29 NWBK 6016 1331 9268 19"),
        "the fixture's older payload should still carry the account in the clear, or the \
         comparison above is not about a figure at all"
    );
    close_session(s).ok();
}

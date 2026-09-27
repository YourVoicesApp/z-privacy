// Invariant G6: any change that affects the safe text invalidates every payload
// handle built before it.
//
// The list of mutating calls below is walked one by one. A call that is not
// built yet answers `NotImplemented` and is counted as pending — so the day it
// lands, this test starts holding it to the rule without anyone editing it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::type_complexity)]

use z_core::api::*;

const DOC: &str = "Herr Thomas Müller arbeitet bei Nordstern GmbH.";

fn fresh_session_with_payload() -> (SessionId, PayloadHandle) {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    let h = build_payload(s).expect("build");
    // A freshly built payload can be looked at.
    assert!(payload_view(h).is_ok(), "a fresh handle must be viewable");
    (s, h)
}

#[test]
fn stale_payload_after_a_document_change() {
    let (s, handle) = fresh_session_with_payload();
    let before = session_revision(s).expect("revision").n;

    import_text(s, "Ein anderer Text.".to_string()).expect("second import");
    let after = session_revision(s).expect("revision").n;
    assert!(after > before, "importing must raise the revision");

    // The old handle is refused, and says both numbers so the UI can explain.
    match payload_view(handle) {
        Err(ApiError::StalePayload { expected, got }) => {
            assert_eq!(expected, after);
            assert_eq!(got, before);
        }
        other => panic!("expected StalePayload, got {other:?}"),
    }
    match send(handle, ProviderId { id: "openai".to_string() }) {
        Err(ApiError::StalePayload { .. }) => {}
        other => panic!("send must refuse a stale handle, got {other:?}"),
    }
}

#[test]
fn stale_payload_after_every_mutating_call() {
    // name, and the call. Each one must either be unbuilt, or make handles stale.
    let mutators: Vec<(&str, fn(SessionId) -> Option<ApiError>)> = vec![
        ("import_text", |s| import_text(s, "Neuer Text".to_string()).err()),
        ("protect", |s| {
            protect(s, Span { start: 5, end: 18 }, Scope::Conversation, Kind::Person).err()
        }),
        ("protect_all_matches", |s| {
            protect_all_matches(s, Span { start: 5, end: 18 }, Scope::Conversation, Kind::Person).err()
        }),
        ("undo_last_protection", |s| undo_last_protection(s).err()),
        ("add_alias", |s| add_alias(s, "t".to_string(), "a".to_string()).err()),
        ("answer_finding", |s| answer_finding(s, 1, FindingAnswer::Protect).err()),
        ("switch_profile", |s| switch_profile(s, "p".to_string()).err()),
        ("switch_pack", |s| switch_pack(s, "en".to_string()).err()),
    ];

    let mut pending = Vec::new();
    for (name, call) in mutators {
        let (s, handle) = fresh_session_with_payload();
        let before = session_revision(s).expect("revision").n;

        if let Some(ApiError::NotImplemented) = call(s) {
            pending.push(name);
            assert_eq!(
                session_revision(s).expect("revision").n,
                before,
                "{name}: a call that did nothing must not raise the revision"
            );
            continue;
        }

        assert!(
            session_revision(s).expect("revision").n > before,
            "{name}: a mutating call must raise the revision"
        );
        assert!(
            matches!(payload_view(handle), Err(ApiError::StalePayload { .. })),
            "{name}: the handle built before it must be stale"
        );
        close_session(s).expect("close");
    }
    // Recorded, not hidden: this is the honest state of the contract today.
    eprintln!("pending mutators (not built yet): {pending:?}");
}

#[test]
fn looking_does_not_change_anything() {
    // Reveal and hide are the heart of the product's promise: they draw on the
    // screen and never touch the request. Here that is a number that must not move.
    let (s, handle) = fresh_session_with_payload();
    let before = session_revision(s).expect("revision").n;

    let _ = reveal(s, "__Z_0000_PERSON_0000__".to_string());
    let _ = hide(s, "__Z_0000_PERSON_0000__".to_string());
    let _ = document_view(s);
    let _ = list_tokens(s);
    let _ = payload_view(handle);

    assert_eq!(
        session_revision(s).expect("revision").n,
        before,
        "looking at things must never raise the revision"
    );
    assert!(payload_view(handle).is_ok(), "the handle must still be good");
}

#[test]
fn a_handle_is_never_trusted_over_the_store() {
    let (_s, handle) = fresh_session_with_payload();

    // A handle claiming a revision it was not built on is refused, even though
    // the payload itself is current.
    let forged = PayloadHandle { revision: handle.revision + 7, ..handle };
    assert!(matches!(payload_view(forged), Err(ApiError::StalePayload { .. })));

    // An id that was never issued is not a payload.
    let unknown = PayloadHandle { id: 9999, ..handle };
    assert!(matches!(payload_view(unknown), Err(ApiError::InvalidHandle)));

    // A session that does not exist.
    let nowhere = PayloadHandle { session: 9999, ..handle };
    assert!(matches!(payload_view(nowhere), Err(ApiError::InvalidSession)));
}

#[test]
fn nothing_to_build_is_said_plainly() {
    let s = open_session(None, "de".to_string()).expect("open");
    assert!(matches!(build_payload(s), Err(ApiError::NothingToSend)));
}

#[test]
fn a_fresh_handle_reaches_the_provider_check() {
    // Proof of order: freshness is decided before the network is even considered,
    // so a stale request never gets as far as a provider.
    let (_s, handle) = fresh_session_with_payload();
    match send(handle, ProviderId { id: "openai".to_string() }) {
        Err(ApiError::ProviderUnavailable { provider }) => assert_eq!(provider, "openai"),
        other => panic!("expected the provider door to be closed, got {other:?}"),
    }
}

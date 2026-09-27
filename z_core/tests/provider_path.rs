// The whole path with no network at all: build, audit, send, answer, restore.
//
// The echo provider is behind the `fake_provider` feature, so this file only
// exists in a build made for the tests — a release has no such provider to pick.
// It echoes the safe text back, which makes the round trip strict: a value that
// escaped on the way out would come home as itself.
#![cfg(feature = "fake_provider")]
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const DOC: &str = "Kunde: Nordstern Consulting GmbH\n\
Guten Tag Herr Thomas Müller,\n\
IBAN: DE89370400440532013000";

fn fake() -> ProviderId {
    ProviderId { id: "fake".to_string() }
}

fn settle(s: SessionId) {
    loop {
        let open: Vec<u32> = list_findings(s)
            .expect("findings")
            .into_iter()
            .filter(|f| f.state == MarkState::Suggested)
            .map(|f| f.id)
            .collect();
        if open.is_empty() {
            break;
        }
        for id in open {
            answer_finding(s, id, FindingAnswer::Protect).expect("protect");
        }
    }
}

#[test]
fn the_whole_path_runs_without_a_socket_and_without_a_vault() {
    // No vault in this test, on purpose: a credential with nowhere sealed to go
    // must be kept in memory for this run only, and must *say so*.
    let rows = providers().expect("rows");
    let row = rows.iter().find(|r| r.id == "fake").expect("the echo provider is listed");
    assert!(!row.connected, "nothing is connected before a credential is given");
    assert_eq!(row.model, "echo");

    let connected = connect_provider(fake(), "no-credential-needed".to_string(), None).expect("connect");
    assert!(connected.connected);
    assert!(
        connected.session_only,
        "with no vault open, a credential is temporary and the row admits it"
    );

    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    settle(s);

    let handle = build_payload(s).expect("build");
    let safe = payload_view(handle).expect("view").text;
    for secret in ["Thomas Müller", "Nordstern Consulting GmbH", "DE89370400440532013000"] {
        assert!(!safe.contains(secret), "«{secret}» is still in the safe text");
    }

    let answer = send(handle, fake()).expect("send");

    // What came back is the safe text inside a sentence: still no real value.
    let raw = ai_view(s, answer).expect("raw");
    assert!(raw.starts_with("Verstanden."), "{raw}");
    for secret in ["Thomas Müller", "Nordstern Consulting GmbH", "DE89370400440532013000"] {
        assert!(!raw.contains(secret), "«{secret}» came back from the provider");
    }

    // And restoring puts the real values back, here, locally.
    let restored: String = restored_view(s, answer)
        .expect("restore")
        .into_iter()
        .map(|seg| seg.text)
        .collect();
    for secret in ["Thomas Müller", "Nordstern Consulting GmbH", "DE89370400440532013000"] {
        assert!(restored.contains(secret), "«{secret}» did not come back: {restored}");
    }

    // The same handle again: the session did not change, so it is still fresh and
    // a second send is simply a second answer.
    let again = send(handle, fake()).expect("send again");
    assert_ne!(again.id, answer.id, "two answers, two ids");

    // A change to the session, and the old handle is refused before the provider.
    protect(s, Span { start: 0, end: 5 }, Scope::Conversation, Kind::Custom).expect("protect");
    match send(handle, fake()) {
        Err(ApiError::StalePayload { .. }) => {}
        other => panic!("a stale handle must not reach a provider, got {other:?}"),
    }

    // The connection test sends the word «ping» and times it.
    let millis = test_provider(fake()).expect("ping");
    assert!(millis < 5_000, "an echo answers at once, took {millis} ms");

    // An unknown provider is named, not guessed at.
    match send(build_payload(s).expect("build"), ProviderId { id: "gemini".to_string() }) {
        Err(ApiError::NetworkRefused { reason: NetworkRefusal::NotConnected, detail }) => {
            assert!(detail.contains("gemini"), "{detail}")
        }
        other => panic!("expected an unconnected provider, got {other:?}"),
    }

    // Forgetting works with no vault too.
    let gone = disconnect_provider(fake()).expect("disconnect");
    assert!(!gone.connected);
    assert!(!gone.session_only, "nothing is left to be temporary");
    close_session(s).expect("close");
}

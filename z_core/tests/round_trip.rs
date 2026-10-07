// The whole heart of Z Privacy, with no scanner, no vault and no interface:
//
//   original → protect → safe payload → (a provider's answer) → restored
//
// If this passes and no code can send the original through the contract, the
// product's core is proven before anything is built around it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const DOC: &str = "Herr Thomas Müller arbeitet bei Nordstern GmbH.";

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle is in the document");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    let len: usize = needle.chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + len) as u32,
    }
}

fn token_of(outcome: ProtectOutcome) -> String {
    match outcome {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("expected Applied, got {other:?}"),
    }
}

fn joined(segments: &[Segment]) -> String {
    segments.iter().map(|s| s.text.as_str()).collect()
}

#[test]
fn round_trip_original_to_safe_to_answer_to_restored() {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");

    let person = token_of(
        protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person).expect("person"),
    );
    let company = token_of(
        protect(s, span_of(DOC, "Nordstern GmbH"), Scope::Conversation, Kind::Company)
            .expect("company"),
    );

    // 1. What leaves the device.
    let handle = build_payload(s).expect("build");
    let safe = payload_view(handle).expect("view").text;
    assert_eq!(safe, format!("Herr {person} arbeitet bei {company}."));
    assert!(!safe.contains("Thomas Müller") && !safe.contains("Nordstern GmbH"));

    // 2. What a provider answers, in its own words, using the tokens it was given.
    let raw = format!("Bitte kontaktieren Sie {person} bei {company}.");
    let answer = ingest_answer(handle, raw.clone()).expect("ingest");

    // 3. AI View: exactly what came back, tokens and all.
    assert_eq!(ai_view(s, answer).expect("ai view"), raw);

    // 4. Restored View: the words put back, locally.
    let segments = restored_view(s, answer).expect("restored");
    assert_eq!(
        joined(&segments),
        "Bitte kontaktieren Sie Thomas Müller bei Nordstern GmbH."
    );

    // The UI needs to know which words it put back, to mark them.
    let restored: Vec<&str> = segments
        .iter()
        .filter(|x| x.piece == Piece::Restored)
        .map(|x| x.text.as_str())
        .collect();
    assert_eq!(restored, vec!["Thomas Müller", "Nordstern GmbH"]);
    assert!(
        segments.iter().any(|x| x.piece == Piece::Words),
        "the model's own words are marked as its own"
    );
}

#[test]
fn round_trip_leaves_a_token_it_does_not_know_alone() {
    // Invariant G9: restore replaces what this session minted, and nothing that
    // merely looks like a token. The core does not guess.
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    let person = token_of(
        protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person).expect("person"),
    );
    let handle = build_payload(s).expect("build");

    let raw = format!("{person} und __Z_FAKE_123__ und __Z_ohne_Ende und __Z_9999_PERSON_9999__.");
    let answer = ingest_answer(handle, raw).expect("ingest");
    let text = joined(&restored_view(s, answer).expect("restored"));

    assert!(text.starts_with("Thomas Müller und "));
    assert!(text.contains("__Z_FAKE_123__"), "an invented token stays as it is: {text}");
    assert!(text.contains("__Z_ohne_Ende"), "an unfinished one too: {text}");
    assert!(
        text.contains("__Z_9999_PERSON_9999__"),
        "a token in our own shape but not ours is still not ours: {text}"
    );
}

#[test]
fn round_trip_does_not_cross_sessions() {
    // Two conversations, the same name. An answer from one must mean nothing in
    // the other — which is what the per-session namespace is for.
    let a = open_session(None, "de".to_string()).expect("open a");
    import_text(a, DOC.to_string()).expect("import a");
    let token_a = token_of(
        protect(a, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person).expect("a"),
    );

    let b = open_session(None, "de".to_string()).expect("open b");
    import_text(b, DOC.to_string()).expect("import b");
    let token_b = token_of(
        protect(b, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person).expect("b"),
    );
    assert_ne!(token_a, token_b);
    let handle_b = build_payload(b).expect("build b");

    // Session B is handed an answer built with A's token.
    let answer = ingest_answer(handle_b, format!("Bitte {token_a} anrufen.")).expect("ingest");
    let text = joined(&restored_view(b, answer).expect("restored"));
    assert_eq!(
        text, format!("Bitte {token_a} anrufen."),
        "B must not be able to read A's tokens"
    );
    assert!(!text.contains("Thomas Müller"));
}

#[test]
fn round_trip_restores_every_spelling_to_its_own_value() {
    // The alias goes out as the same token; coming back, the entry's primary
    // spelling is what the reader sees. One entity, one name in the answer.
    let doc = "Thomas Müller kommt. Herr Müller unterschreibt.";
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    let token = token_of(
        protect(s, span_of(doc, "Thomas Müller"), Scope::Conversation, Kind::Person).expect("protect"),
    );
    add_alias(s, token.clone(), "Herr Müller".to_string()).expect("alias");

    let handle = build_payload(s).expect("build");
    let safe = payload_view(handle).expect("view").text;
    assert_eq!(safe.matches(&token).count(), 2);

    let answer = ingest_answer(handle, format!("{token} hat unterschrieben.")).expect("ingest");
    assert_eq!(
        joined(&restored_view(s, answer).expect("restored")),
        "Thomas Müller hat unterschrieben."
    );
}

#[test]
fn round_trip_says_when_an_answer_is_not_there() {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    assert!(matches!(
        restored_view(s, AnswerId { id: 77 }),
        Err(ApiError::UnknownToken)
    ));
    assert!(matches!(ai_view(s, AnswerId { id: 77 }), Err(ApiError::UnknownToken)));
}

#[test]
fn round_trip_an_answer_coming_in_does_not_stale_a_handle() {
    // Receiving is not changing: the payload that was sent is still the payload
    // that was sent, so the handle stays good and the UI need not rebuild.
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person).expect("protect");
    let handle = build_payload(s).expect("build");

    ingest_answer(handle, "Alles gut.".to_string()).expect("ingest");
    assert!(payload_view(handle).is_ok(), "an incoming answer must not stale the handle");
}

#[test]
fn round_trip_restores_only_tokens_from_the_originating_payload() {
    let s = open_session(None, "de".to_string()).expect("open");

    let doc_a = "Person A ist Anna Weber.";
    import_text(s, doc_a.to_string()).expect("import a");
    let token_a = token_of(
        protect(s, span_of(doc_a, "Anna Weber"), Scope::Conversation, Kind::Person).expect("protect a"),
    );
    let payload_a = build_payload(s).expect("payload a");

    let doc_b = "Person B ist Bernd Bauer.";
    import_text(s, doc_b.to_string()).expect("import b");
    let token_b = token_of(
        protect(s, span_of(doc_b, "Bernd Bauer"), Scope::Conversation, Kind::Person).expect("protect b"),
    );
    let payload_b = build_payload(s).expect("payload b");
    assert_ne!(token_a, token_b);

    let raw = format!("{token_a} / {token_a} / {token_b} / __Z_9999_PERSON_9999__");
    let answer = ingest_answer(payload_a, raw).expect("ingest a answer");
    let text = joined(&restored_view(s, answer).expect("restored"));

    assert_eq!(
        text,
        format!("Anna Weber / Anna Weber / {token_b} / __Z_9999_PERSON_9999__"),
        "the answer may reuse a token from its payload, but not borrow another payload's token"
    );

    import_text(s, "Ein neues Dokument ohne diese Namen.".to_string()).expect("change after answer");
    assert_eq!(
        joined(&restored_view(s, answer).expect("restored after change")),
        format!("Anna Weber / Anna Weber / {token_b} / __Z_9999_PERSON_9999__"),
        "the answer keeps the frozen allow-list of its originating payload"
    );

    let answer_b = ingest_answer(payload_b, format!("{token_b} antwortet.")).expect("ingest b answer");
    assert_eq!(
        joined(&restored_view(s, answer_b).expect("restored b")),
        "Bernd Bauer antwortet."
    );
}

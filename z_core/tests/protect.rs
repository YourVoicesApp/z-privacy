// Protect, in every state the behaviour board names, and what each state does
// to the payload.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const DOC: &str =
    "Kunde: Nordstern GmbH. Ansprechpartner: Thomas Müller. Rückfragen an Thomas Müller.";

/// The span Flutter would report for `needle`, counted in UTF-16 units.
fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle is in the document");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    let len: usize = needle.chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + len) as u32,
    }
}

fn session_with_doc() -> SessionId {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    s
}

fn payload_text(s: SessionId) -> String {
    let h = build_payload(s).expect("build");
    payload_view(h).expect("view").text
}

#[test]
fn protecting_once_replaces_that_place_only() {
    let s = session_with_doc();
    let outcome = protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person)
        .expect("protect");

    let token = match outcome {
        ProtectOutcome::Applied { token, places } => {
            assert_eq!(places, 1, "Protect takes one place; All Matches takes the rest");
            token
        }
        other => panic!("expected Applied, got {other:?}"),
    };

    let text = payload_text(s);
    assert!(text.contains(&token), "the token must stand where the name was");
    assert_eq!(
        text.matches("Thomas Müller").count(),
        1,
        "the second place is still in the clear, because Once means once"
    );
    assert!(text.contains("Nordstern GmbH"), "nothing else was touched");
}

#[test]
fn protecting_the_same_selection_again_says_so_and_changes_nothing() {
    let s = session_with_doc();
    let span = span_of(DOC, "Thomas Müller");
    let first = protect(s, span, Scope::Conversation, Kind::Person).expect("protect");
    let token = match first {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("expected Applied, got {other:?}"),
    };
    let revision = session_revision(s).expect("revision").n;

    match protect(s, span, Scope::Conversation, Kind::Person).expect("protect again") {
        ProtectOutcome::AlreadyProtected { token: t, source, .. } => {
            assert_eq!(t, token, "the same thing keeps the same token");
            assert_eq!(source, Source::Hand);
        }
        other => panic!("expected AlreadyProtected, got {other:?}"),
    }
    assert_eq!(
        session_revision(s).expect("revision").n,
        revision,
        "saying 'already protected' is not a change"
    );
}

#[test]
fn a_selection_that_cuts_a_protected_item_snaps_to_it() {
    let s = session_with_doc();
    let full = span_of(DOC, "Thomas Müller");
    protect(s, full, Scope::Conversation, Kind::Person).expect("protect");
    let revision = session_revision(s).expect("revision").n;

    // Half of the protected name, plus the word before it.
    let cutting = Span {
        start: full.start - 3,
        end: full.start + 6,
    };
    match protect(s, cutting, Scope::Conversation, Kind::Person).expect("protect") {
        ProtectOutcome::Snapped { spans } => {
            assert_eq!(spans.len(), 1);
            assert_eq!(spans[0], full, "it snaps to the whole item, never half of one");
        }
        other => panic!("expected Snapped, got {other:?}"),
    }
    assert_eq!(
        session_revision(s).expect("revision").n,
        revision,
        "snapping changed nothing, so no handle went stale"
    );
}

#[test]
fn all_matches_uses_one_token_for_every_place() {
    let s = session_with_doc();
    let outcome = protect_all_matches(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person)
        .expect("all matches");
    let (token, places) = match outcome {
        ProtectOutcome::Applied { token, places } => (token, places),
        other => panic!("expected Applied, got {other:?}"),
    };
    assert_eq!(places, 2, "the name stands twice in this document");

    let text = payload_text(s);
    assert_eq!(
        text.matches(&token).count(),
        2,
        "both places carry the same token — two tokens would read as two people"
    );
    assert!(!text.contains("Thomas Müller"), "no place is left in the clear");
    assert_eq!(list_tokens(s).expect("tokens").len(), 1, "one value, one row");
}

#[test]
fn different_values_get_different_tokens() {
    let s = session_with_doc();
    let person = match protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person)
        .expect("person")
    {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("{other:?}"),
    };
    let company = match protect(s, span_of(DOC, "Nordstern GmbH"), Scope::Conversation, Kind::Company)
        .expect("company")
    {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("{other:?}"),
    };
    assert_ne!(person, company);
    assert!(person.contains("_PERSON_"), "{person}");
    assert!(company.contains("_COMPANY_"), "{company}");

    let rows = list_tokens(s).expect("tokens");
    assert_eq!(rows.len(), 2);
    assert!(rows.iter().any(|r| r.kind == Kind::Person && r.source == Source::Hand));
}

#[test]
fn the_same_value_selected_twice_reuses_its_token() {
    let s = session_with_doc();
    let first = match protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person)
        .expect("first")
    {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("{other:?}"),
    };
    // The second appearance, selected by hand rather than by All Matches.
    let second_at = DOC.rfind("Thomas Müller").expect("second");
    let start: usize = DOC[..second_at].chars().map(char::len_utf16).sum();
    let span = Span {
        start: start as u32,
        end: (start + "Thomas Müller".chars().map(char::len_utf16).sum::<usize>()) as u32,
    };
    match protect(s, span, Scope::Conversation, Kind::Person).expect("second") {
        ProtectOutcome::Applied { token, .. } => assert_eq!(token, first, "one value, one token"),
        other => panic!("expected Applied, got {other:?}"),
    }
    assert_eq!(list_tokens(s).expect("tokens").len(), 1);
}

#[test]
fn undo_takes_back_the_whole_act() {
    let s = session_with_doc();
    protect_all_matches(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person)
        .expect("all matches");
    assert_eq!(document_view(s).expect("view").marks.len(), 2);

    match undo_last_protection(s).expect("undo") {
        UndoOutcome::Undone { places, created_entity, .. } => {
            assert_eq!(places, 2, "one act went in, one act comes out");
            assert_eq!(created_entity, None, "the vault arrives in M4");
        }
        other => panic!("expected Undone, got {other:?}"),
    }
    assert!(document_view(s).expect("view").marks.is_empty());
    assert!(list_tokens(s).expect("tokens").is_empty(), "the panel drops it too");
    assert!(payload_text(s).contains("Thomas Müller"), "the name is back in the clear");
}

#[test]
fn an_alias_protects_the_other_spelling_under_the_same_token() {
    let s = open_session(None, "de".to_string()).expect("open");
    let doc = "Thomas Müller kommt. Herr Müller unterschreibt.";
    import_text(s, doc.to_string()).expect("import");

    let token = match protect(s, span_of(doc, "Thomas Müller"), Scope::Conversation, Kind::Person)
        .expect("protect")
    {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("{other:?}"),
    };
    let places = add_alias(s, token.clone(), "Herr Müller".to_string()).expect("alias");
    assert_eq!(places, 1);

    let text = payload_text(s);
    assert_eq!(text.matches(&token).count(), 2, "both spellings, one token");
    assert!(!text.contains("Müller"), "no spelling left in the clear: {text}");
    assert!(matches!(
        add_alias(s, "__Z_0000_PERSON_0000__".to_string(), "x".to_string()),
        Err(ApiError::UnknownToken)
    ));
}

#[test]
fn reveal_shows_the_value_and_nothing_else_moves() {
    let s = session_with_doc();
    let token = match protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person)
        .expect("protect")
    {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("{other:?}"),
    };
    let handle = build_payload(s).expect("build");
    let before = payload_view(handle).expect("view").text;

    let shown = reveal(s, token.clone()).expect("reveal");
    assert_eq!(shown.value, "Thomas Müller");
    assert!(shown.ttl_ms > 0, "a revealed value hides itself again");
    hide(s, token).expect("hide");

    assert_eq!(
        payload_view(handle).expect("view").text,
        before,
        "revealing must not change one character of what will be sent"
    );
    assert!(matches!(
        reveal(s, "__Z_0000_PERSON_0000__".to_string()),
        Err(ApiError::UnknownToken)
    ));
}

#[test]
fn a_bad_selection_is_refused_with_a_reason() {
    let s = session_with_doc();
    for span in [
        Span { start: 9999, end: 10_000 },
        Span { start: 10, end: 4 },
        Span { start: 7, end: 7 },
    ] {
        match protect(s, span, Scope::Once, Kind::Person) {
            Err(ApiError::BadSpan { reason }) => assert!(!reason.is_empty()),
            other => panic!("expected BadSpan for {span:?}, got {other:?}"),
        }
    }
}

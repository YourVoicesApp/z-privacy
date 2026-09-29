// P1-2 — «Answer N of M» becomes usable instead of being a dead fact.
//
// His conditions of 29 September, each its own assertion. Nothing new is
// built: these are the answers already in memory for this conversation. No
// history, no persistence, no list of conversations.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// A session with `n` answers, each naming itself, and the protected e-mail
/// restored into every one of them.
fn a_session_with(answers: &[&str]) -> (SessionId, Vec<AnswerId>) {
    let session = open_session(None, "de".to_string()).expect("session");
    let doc = "Frage an das Modell: a.weber@nordstern.de";
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let token = list_tokens(session).expect("tokens")[0].token.clone();

    let mut ids = Vec::new();
    for text in answers {
        // Each answer needs its own payload: after F-05 an answer is bound to
        // the payload the model saw, which is the point of the stale test.
        let handle = build_payload(session).expect("payload");
        ids.push(ingest_answer(handle, format!("{text} {token}")).expect("answer"));
    }
    (session, ids)
}

fn text_of(session: SessionId, answer: AnswerId) -> String {
    restored_view(session, answer)
        .expect("restored")
        .into_iter()
        .map(|s| s.text)
        .collect()
}

/// His first test, step by step.
#[test]
fn a_person_can_walk_back_to_the_first_answer_and_forward_again() {
    let (session, ids) = a_session_with(&["ANSWER-A", "ANSWER-B"]);
    let (a, b) = (ids[0], ids[1]);

    // On B: «Answer 2 of 2», and there is a way back but not forward.
    let on_b = answer_snapshot(session, b).expect("snapshot b");
    assert_eq!((on_b.index, on_b.total), (2, 2));
    assert_eq!(on_b.previous.map(|p| p.id), Some(a.id), "no way back from the last answer");
    assert!(on_b.next.is_none(), "the last answer offers a next");

    // Previous → A, and everything on the screen is A's.
    let on_a = answer_snapshot(session, on_b.previous.expect("previous")).expect("snapshot a");
    assert_eq!((on_a.index, on_a.total), (1, 2));
    assert_eq!(on_a.answer.id, a.id);
    assert!(on_a.as_written.contains("ANSWER-A"), "the raw view is not A's");
    assert!(on_a.restored.iter().any(|s| s.text.contains("ANSWER-A")), "restored is not A's");
    assert!(
        on_a.restored.iter().any(|s| s.text.contains("a.weber@nordstern.de")),
        "A's restored view lost the real value"
    );
    assert!(!on_a.as_written.contains("ANSWER-B"), "A's view carries B's text");
    assert!(on_a.previous.is_none(), "the first answer offers a previous");

    // Next → B again, and the views follow.
    let back_on_b = answer_snapshot(session, on_a.next.expect("next")).expect("snapshot b again");
    assert_eq!((back_on_b.index, back_on_b.total), (2, 2));
    assert!(back_on_b.as_written.contains("ANSWER-B"));
    assert!(!back_on_b.as_written.contains("ANSWER-A"));
}

/// The copy buttons take their text from the same snapshot as the position,
/// so «showing A while copying B» cannot happen.
#[test]
fn what_a_copy_would_write_belongs_to_the_answer_on_screen() {
    let (session, ids) = a_session_with(&["ANSWER-A", "ANSWER-B"]);
    for (id, name) in ids.iter().zip(["ANSWER-A", "ANSWER-B"]) {
        let snap = answer_snapshot(session, *id).expect("snapshot");
        let restored: String = snap.restored.iter().map(|s| s.text.clone()).collect();
        assert!(restored.contains(name), "Copy Restored would write another answer");
        assert!(snap.as_written.contains(name), "Copy Protected would write another answer");
        assert_eq!(text_of(session, snap.answer), restored, "two reads of one answer differ");
    }
}

/// His second test: one answer, both controls off.
#[test]
fn one_answer_offers_nowhere_to_go() {
    let (session, ids) = a_session_with(&["ONLY"]);
    let only = answer_snapshot(session, ids[0]).expect("snapshot");
    assert_eq!((only.index, only.total), (1, 1));
    assert!(only.previous.is_none() && only.next.is_none());
}

/// His stale test: walking A → B → A changes no history.
///
/// It matters because of F-05 — an answer is bound to the tokens of the
/// payload that produced it. If looking at an old answer rebound anything,
/// restoring would start guessing again.
#[test]
fn walking_between_answers_changes_no_history() {
    let (session, ids) = a_session_with(&["ANSWER-A", "ANSWER-B"]);
    let (a, b) = (ids[0], ids[1]);

    let before: Vec<(u32, String, String)> = ids
        .iter()
        .map(|id| {
            let s = answer_snapshot(session, *id).expect("snapshot");
            (s.answer.id, s.as_written.clone(), text_of(session, *id))
        })
        .collect();

    // A → B → A, the way a person would press.
    for step in [a, b, a] {
        answer_snapshot(session, step).expect("walk");
    }

    let after: Vec<(u32, String, String)> = ids
        .iter()
        .map(|id| {
            let s = answer_snapshot(session, *id).expect("snapshot");
            (s.answer.id, s.as_written.clone(), text_of(session, *id))
        })
        .collect();

    assert_eq!(before, after, "walking between answers moved an answer's own history");

    // And the tokens of the conversation are untouched by looking.
    let tokens = list_tokens(session).expect("tokens");
    assert_eq!(tokens.len(), 1, "navigation changed the token table");
}

// Teach once → the rescan finds every place.
//
// Its own file because it needs a vault, and a vault is one per process — the
// same reason `vault_layer.rs` and `the_safe_column_reveal.rs` stand apart.
// One test, in the order a person does it: import, see what needs a word,
// answer, and watch the document become understood.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const TEAM: &str = "Projektteam 2026\n\
    Kowalski, Thomas — Bauleitung\n\
    Yilmaz, Sophie — Elektroplanung\n\
    Die Bauleitung liegt bei Thomas Kowalski.\n\
    Rückfragen an Sophie Yilmaz.\n\
    Nur Richter dürfen entscheiden, an Bauer ist nichts zu senden.\n";

fn people(session: SessionId) -> Vec<(MarkState, String)> {
    let text = document_view(session).expect("view").text;
    let units: Vec<u16> = text.encode_utf16().collect();
    list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == Kind::Person)
        .map(|f| {
            (
                f.state,
                String::from_utf16_lossy(
                    units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
                ),
            )
        })
        .collect()
}

#[test]
fn a_person_answers_twice_and_a_whole_document_is_understood() {
    let dir = std::env::temp_dir().join(format!("zprivacy-teach-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).expect("a folder of its own");
    set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    vault_create_with_passphrase("ein gutes Passwort für die Reise".to_string()).expect("a vault");

    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, TEAM.to_string()).expect("import");
    let before = scan(session).expect("scan");
    assert!(
        people(session).is_empty(),
        "nothing is known about these people yet, which is the premise: {:?}",
        people(session)
    );

    // What needs a word, and what each word is worth.
    let candidates = name_candidates(session).expect("candidates");
    assert_eq!(candidates.len(), 2, "two names for a whole document");
    assert!(candidates.iter().all(|c| c.occurrences == 2 && !c.examples.is_empty()));

    // Two answers. This is all a person does.
    let mut decisions = 0u32;
    for candidate in &candidates {
        teach_name(candidate.text.clone(), true, None).expect("teach");
        decisions += 1;
    }
    assert_eq!(decisions, 2);
    let learned = taught_names().expect("taught");
    assert_eq!(learned.len(), 2);
    assert!(learned.iter().all(|row| row.family), "both were taught as surnames");

    // And the rescan sees every place, including the lines nobody read.
    let after = scan(session).expect("rescan");
    let marked = people(session);
    for expected in ["Thomas Kowalski", "Sophie Yilmaz"] {
        assert!(
            marked.iter().any(|(_, text)| text == expected),
            "«{expected}» is still unseen after it was taught: {marked:?}"
        );
    }
    assert!(
        after.suggested > before.suggested,
        "the teaching changed nothing: {before:?} then {after:?}"
    );
    // Offered, never protected by the teaching alone: Z was told what kind of
    // word this is, not that it must be hidden.
    for (state, text) in &marked {
        assert_eq!(*state, MarkState::Suggested, "«{text}» was protected by a lesson");
    }
    // And the review list is empty, because Z asks only about what still needs
    // a word.
    assert!(
        name_candidates(session).expect("candidates").is_empty(),
        "a name already taught was offered for review again"
    );

    // Reversible, and one word at a time.
    assert_eq!(
        teach_name("kowalski".to_string(), true, None).expect("again"),
        learned.iter().find(|r| r.text == "Kowalski").expect("it").id,
        "taught twice is taught once"
    );
    assert!(matches!(
        teach_name("Thomas Kowalski".to_string(), true, None),
        Err(ApiError::InputRefused { .. })
    ));
    for row in &learned {
        forget_name(row.id).expect("forget");
    }
    assert!(taught_names().expect("list").is_empty());
    // Forgetting is knowledge only: the open document keeps what it has, and a
    // rescan is what reconsiders it.
    assert!(!people(session).is_empty(), "forgetting a lesson emptied the document");

    // A locked vault has nothing to say, rather than a flag to check.
    vault_lock().expect("lock");
    assert!(taught_names().is_err(), "a locked vault listed what it holds");
    let session = open_session(None, "de".to_string()).expect("open again");
    import_text(session, TEAM.to_string()).expect("import");
    scan(session).expect("scan");
    assert!(
        people(session).is_empty(),
        "a locked vault still answered: {:?}",
        people(session)
    );

    let _ = std::fs::remove_dir_all(&dir);
}

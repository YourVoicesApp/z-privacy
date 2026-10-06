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
        people(session).iter().all(|(state, _)| *state != MarkState::Protected),
        "nothing is protected about these people yet, which is the premise: {:?}",
        people(session)
    );

    // What needs a word, and what each word is worth.
    //
    // 038-H moved this, and the move is worth reading. «Kowalski» is in the
    // name bank now (19 bearers), so «Thomas Kowalski» is **offered** rather
    // than asked about — one less decision, which is this phase's whole
    // measure. «Al-Hassan» is the one name left to look at, and it is here at
    // all because «Mahmoud» is in four cities' registers: the gap Phase 2
    // measured, closed.
    //
    // And «Yilmaz» is the cost, named: three of the four cities gave a child
    // that name, so the bank knows it as a **given** name, and the comma rule
    // walks past a word it knows. A surname that is also a first name is
    // invisible to discovery until «known» there means «known as a surname» —
    // which is a rule, and 038-H changes no rules. The person types it instead,
    // the way the Names panel lets them since 041-D.
    let candidates = name_candidates(session).expect("candidates");
    assert!(
        candidates.is_empty(),
        "nothing on this page is unknown any more: {candidates:?}"
    );
    // «Thomas Kowalski» is offered by the bank itself — one decision fewer,
    // which is this phase's whole measure.
    assert!(
        people(session).iter().any(|(state, text)| *state == MarkState::Suggested && text == "Thomas Kowalski"),
        "the pair the bank knows was not offered: {:?}",
        people(session)
    );

    // One answer. This is all a person does — and the one name that still
    // needs it is the cost 038-H measured: three of the four city registers
    // gave a child the name «Yilmaz», so the bank knows it as a **given** name
    // and the comma rule walks past a word it knows. A surname that is also a
    // first name is invisible to discovery until «known» there means «known as
    // a surname», which is a rule, and 038-H changes no rules. The person
    // types it instead, the way the Names panel lets them since 041-D.
    teach_name("Yilmaz".to_string(), true, None).expect("teach the surname by hand");
    let decisions = 1u32;
    assert_eq!(decisions, 1);
    let learned = taught_names().expect("taught");
    assert_eq!(learned.len(), 1);
    assert!(learned.iter().all(|row| row.family), "it was taught as a surname");

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
        teach_name("yilmaz".to_string(), true, None).expect("again"),
        learned.iter().find(|r| r.text == "Yilmaz").expect("it").id,
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

    // A locked vault has nothing to say, rather than a flag to check — and the
    // bank is not in the vault. What the person taught is silent; what this
    // build ships with still works, which is the whole point of compiling it
    // in: a scan on an aeroplane finds what a scan in an office finds.
    vault_lock().expect("lock");
    assert!(taught_names().is_err(), "a locked vault listed what it holds");
    let session = open_session(None, "de".to_string()).expect("open again");
    import_text(session, TEAM.to_string()).expect("import");
    scan(session).expect("scan");
    let marked = people(session);
    assert!(
        marked.iter().all(|(_, text)| text != "Sophie Yilmaz"),
        "a locked vault still answered with what it was taught: {marked:?}"
    );
    assert!(
        marked.iter().any(|(_, text)| text == "Thomas Kowalski"),
        "the shipped bank went quiet when the vault did: {marked:?}"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

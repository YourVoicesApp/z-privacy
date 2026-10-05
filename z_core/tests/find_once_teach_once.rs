// Find once → Review once → Teach once → Protect everywhere.
//
// The owner's measure for this phase is not how many names Z knows. It is how
// few decisions a person makes before a document is understood: «I have 17
// names for you to look at» for a file of 700 pages.
//
// So Z does not try to own a dictionary of every surname on earth. It notices
// the names a document keeps using, gathers each one once with the count of its
// places and three lines of context, and asks. One answer teaches it, and the
// rescan finds every occurrence — including the ones nobody read.
//
// Three things are kept apart and stay apart: **Base**, the lists this build
// ships with; **User**, what the person taught, in the vault; and
// **Candidate**, what nobody has decided. A candidate protects nothing.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]


use z_core::api::*;

fn a_device(name: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("zprivacy-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).expect("a folder of its own");
    set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    dir
}

fn people(session: SessionId, doc: &str) -> Vec<(MarkState, String)> {
    let units: Vec<u16> = doc.encode_utf16().collect();
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

/// A page of a staff list, as a real document writes one: the surnames are
/// Polish, Arabic and Turkish, and no German dictionary has them.
const TEAM: &str = "Projektteam 2026\n\
    Kowalski, Thomas — Bauleitung\n\
    Al-Hassan, Mahmoud — Statik\n\
    Yilmaz, Sophie — Elektroplanung\n\
    Die Bauleitung liegt bei Thomas Kowalski.\n\
    Rückfragen an Mahmoud Al-Hassan oder an Sophie Yilmaz.\n\
    Weitere Unterlagen: Anlage 3, Berlin, Hauptstadt der Bundesrepublik.\n\
    Nur Richter dürfen entscheiden, an Bauer ist nichts zu senden.\n";

#[test]
fn a_document_offers_its_unknown_names_once_each_with_what_a_decision_is_worth() {
    let _dir = a_device("discover");
    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, TEAM.to_string()).expect("import");
    scan(session).expect("scan");

    let found = name_candidates(session).expect("candidates");
    let names: Vec<String> = found.iter().map(|c| c.text.clone()).collect();
    assert_eq!(
        names,
        vec!["Kowalski".to_string(), "Yilmaz".to_string()],
        "one row per name, the most places first"
    );

    // What a single decision is worth is on the row: the places and the pages.
    for candidate in &found {
        assert_eq!(candidate.occurrences, 2, "«{}» stands twice", candidate.text);
        assert!(candidate.family, "both rules read the place of a given name");
        assert!(!candidate.examples.is_empty() && candidate.examples.len() <= 3);
        assert!(
            candidate.examples.iter().all(|line| line.contains(&candidate.text)),
            "an example that does not show the name is not an example: {:?}",
            candidate.examples
        );
        assert!(!candidate.why.is_empty(), "a person deciding is owed the reason");
    }

    // And what it does **not** find: a comma is not enough on its own, and the
    // function-word guard of Phase 1 holds here too.
    for not_a_name in ["Berlin", "Anlage", "Richter", "Bauer", "Hauptstadt", "Projektteam"] {
        assert!(
            !names.contains(&not_a_name.to_string()),
            "«{not_a_name}» was offered as a name"
        );
    }
}

#[test]
fn a_candidate_protects_nothing_until_it_is_taught() {
    let _dir = a_device("candidate");
    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, TEAM.to_string()).expect("import");
    let before = scan(session).expect("scan");
    assert!(
        !name_candidates(session).expect("candidates").is_empty(),
        "nothing to review, so this test proves nothing"
    );
    let marked = people(session, TEAM);
    assert!(
        marked.iter().all(|(_, text)| !text.contains("Kowalski") && !text.contains("Al-Hassan")),
        "a candidate was protected before anybody said so: {marked:?}"
    );
    // The scan is the scan it was: discovery is a separate layer and adds no
    // findings of its own.
    assert_eq!(
        (before.auto, before.suggested),
        (scan(session).expect("again").auto, scan(session).expect("again").suggested)
    );
}

/// The gap this phase measured, named so that it is not discovered twice.
///
/// «Al-Hassan, Mahmoud» is the very form rule one is built for, and it finds
/// nothing — because the evidence the rule needs is the **given** name, and
/// «Mahmoud» is in neither list this build ships with. Measured on the same
/// source as the surnames: Wikidata's given names of German citizens would
/// bring «Tobias» (rank 97) and «Markus» (65), and still not «Mahmoud».
///
/// So the next source question is not a longer German list. It is the names of
/// the people who live in Germany, which is a different list — and the same
/// answer the surnames gave for «Haddad» and «Demir».
#[test]
fn a_name_whose_given_half_is_unknown_is_still_invisible() {
    let _dir = a_device("gap");
    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, TEAM.to_string()).expect("import");
    scan(session).expect("scan");
    let names: Vec<String> = name_candidates(session)
        .expect("candidates")
        .into_iter()
        .map(|c| c.text)
        .collect();
    assert!(
        !names.contains(&"Al-Hassan".to_string()),
        "«Al-Hassan» is found now — the given-name list was widened, and this \
         test is the one to rewrite with the new numbers: {names:?}"
    );
}

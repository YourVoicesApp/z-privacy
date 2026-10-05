// Phase 3: German is the first implementation of a contract, not the contract.
//
// Three things are independent, and the test for that is the one the owner
// wrote: **Device Swedish · UI English · Document Arabic · Active Pack Arabic**
// must be sayable. This file holds what can be measured today — that the
// second language is data, that it needs no German code, and that German did
// not move when the floor was lifted.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

fn findings(pack: &str, doc: &str) -> Vec<(MarkState, Kind, String)> {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    let out = list_findings(session)
        .expect("findings")
        .into_iter()
        .map(|f| {
            (
                f.state,
                f.kind,
                String::from_utf16_lossy(
                    units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
                ),
            )
        })
        .collect();
    let _ = close_session(session);
    out
}

fn people(pack: &str, doc: &str) -> Vec<String> {
    findings(pack, doc)
        .into_iter()
        .filter(|(_, kind, _)| *kind == Kind::Person)
        .map(|(_, _, text)| text)
        .collect()
}

/// A Swedish letter, read by the Swedish pack. Not one line of German took part.
#[test]
fn a_swedish_letter_is_read_by_a_pack_that_is_only_data() {
    // «Herr Andersson» is a salutation and a surname; «Lars Andersson» is the
    // pair; «Med vänliga hälsningar» is the closing before a signature.
    assert_eq!(
        people("sv", "Hej, jag skriver till Herr Lars Andersson om avtalet."),
        vec!["Lars Andersson".to_string()],
        "the shared salutation rule, reading Swedish words"
    );
    assert_eq!(
        people("sv", "Avtalet undertecknades av Anna Nilsson i Stockholm."),
        vec!["Anna Nilsson".to_string()],
        "the shared pair rule, reading the Swedish name lists"
    );
    // And what a list of 150 does not reach is a candidate, which is the
    // Phase 2 mechanism working in a language it was not written for.
    assert!(
        people("sv", "Avtalet undertecknades av Anna Lindberg i Stockholm.").is_empty(),
        "«Lindberg» is not among the 150 surnames, so it is nobody yet"
    );
    assert_eq!(
        people("sv", "Med vänliga hälsningar\nErik Johansson"),
        vec!["Erik Johansson".to_string()],
        "the shared signature rule, reading the Swedish closings"
    );
}

/// The Swedish function-word trap, found the same way German's was.
#[test]
fn a_swedish_word_that_is_also_a_name_opens_nothing() {
    for doc in [
        "Och Lindberg är inte ett namn i den här satsen.",
        "Bara Andersson får besluta om detta.",
        "Som Johansson skrev i sitt brev.",
    ] {
        assert!(
            people("sv", doc).is_empty(),
            "«{doc}» named a person: {:?}",
            people("sv", doc)
        );
    }
}

/// Swedish labels, in the same rows as every other language's.
#[test]
fn swedish_labels_are_rows_like_every_other_language() {
    let found = findings("sv", "Kundnummer: 7733-9120\nTelefon: 08 123 456 78\nE-post: a.lind@exempel.se");
    let kinds: Vec<Kind> = found.iter().map(|(_, kind, _)| *kind).collect();
    assert!(kinds.contains(&Kind::CustomerNo), "{found:?}");
    assert!(kinds.contains(&Kind::Phone), "{found:?}");
    assert!(kinds.contains(&Kind::Email), "{found:?}");
}

/// German did not move when the floor was lifted under it. This is the whole
/// of item 2 of the owner's paper: the same numbers as the baseline, or stop.
#[test]
fn german_reads_exactly_what_it_read_before() {
    assert_eq!(
        people("de", "Sehr geehrter Herr Thomas Müller, vielen Dank."),
        vec!["Thomas Müller".to_string()]
    );
    assert_eq!(people("de", "Prim. Dr. Ludwig Neuner (Klinikum Freistadt)"), vec!["Ludwig Neuner".to_string()]);
    assert_eq!(people("de", "Thomas Müller hat den Vertrag unterschrieben."), vec!["Thomas Müller".to_string()]);
    assert!(people("de", "Beschwerden der Frau (N95.1)").is_empty());
    assert!(people("de", "An Müller GmbH, Lindenstraße 8").is_empty());
    // And German's own three rules, which no other pack carries.
    let plate = findings("de", "Mein Fahrzeug mit dem Kennzeichen A-MW 2041 war da.");
    assert!(plate.iter().any(|(_, kind, _)| *kind == Kind::Vehicle), "{plate:?}");
}

/// A pack's own rules are declared, and the number of them is the measure of
/// the contract: German needs three, Swedish needs none.
#[test]
fn what_each_pack_needs_beyond_the_shared_rules_is_declared() {
    let packs = packs().expect("the installed packs");
    let de = packs.iter().find(|p| p.id == "de").expect("German");
    let sv = packs.iter().find(|p| p.id == "sv").expect("Swedish");
    assert_eq!(de.locale, "de-DE");
    assert_eq!(sv.locale, "sv-SE");
    assert_eq!(
        de.own_rules,
        vec![
            "vehicle plates".to_string(),
            "local telephone numbers".to_string(),
            "street addresses".to_string()
        ],
        "German's three, each one a national format"
    );
    assert!(
        sv.own_rules.is_empty(),
        "Swedish needed a rule of its own, which is the thing to explain: {:?}",
        sv.own_rules
    );
    assert!(!de.provenance.is_empty() && !sv.provenance.is_empty(), "a pack says where its names came from");
    assert!(de.given > 0 && de.family > 0 && sv.given > 0 && sv.family > 0);
}

/// The device's language is a default and never a lock. A session is opened
/// with the pack it is asked for, whatever the machine says.
#[test]
fn the_pack_is_what_was_asked_for_and_not_what_the_machine_is() {
    // Two packs, one after the other, in one process.
    assert_eq!(people("de", "Sehr geehrte Frau Anna Weber,"), vec!["Anna Weber".to_string()]);
    assert_eq!(
        people("sv", "Hej Herr Lars Andersson,"),
        vec!["Lars Andersson".to_string()]
    );
    // And a pack this build has never heard of scans with less knowledge
    // rather than failing — the rule the label sets already followed.
    let session = open_session(None, "ar".to_string()).expect("an unknown pack still opens");
    import_text(session, "Kundennummer: 41-88203".to_string()).expect("import");
    let report = scan(session).expect("and still scans");
    assert!(report.normal > 0, "{report:?}");
    let _ = close_session(session);
}

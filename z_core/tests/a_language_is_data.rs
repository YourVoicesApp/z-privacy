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

/// **One word per name since 085 ruling 1** (15 October): a name the app read
/// for itself is one finding per word, so every pair below is two. Which words
/// are found, and by which rule, is what this file measures and is unchanged.
///
/// A Swedish letter, read by the Swedish pack. Not one line of German took part.
#[test]
fn a_swedish_letter_is_read_by_a_pack_that_is_only_data() {
    // «Herr Andersson» is a salutation and a surname; «Lars Andersson» is the
    // pair; «Med vänliga hälsningar» is the closing before a signature.
    assert_eq!(
        people("sv", "Hej, jag skriver till Herr Lars Andersson om avtalet."),
        vec!["Lars".to_string(), "Andersson".to_string()],
        "the shared salutation rule, reading Swedish words"
    );
    assert_eq!(
        people("sv", "Avtalet undertecknades av Anna Nilsson i Stockholm."),
        vec!["Anna".to_string(), "Nilsson".to_string()],
        "the shared pair rule, reading the Swedish name lists"
    );
    // And what a list of 150 does not reach is a candidate, which is the
    // Phase 2 mechanism working in a language it was not written for.
    //
    // 038-B/1 moved the line this test draws, and moved it on purpose:
    // «Lindberg» is not in the 150 either, but it **ends** like a Swedish
    // surname, and that is now a signal of a dictionary hit's strength. So the
    // word that is nobody until somebody says so has to be one that ends like
    // nothing — «Mazur» is such a word, and it stands in the Swedish magazine
    // SV-16 as a name to look at.
    assert_eq!(
        people("sv", "Avtalet undertecknades av Anna Lindberg i Stockholm."),
        vec!["Anna".to_string(), "Lindberg".to_string()],
        "«-berg» is how a Swedish surname ends, and the pair rule reads it"
    );
    assert!(
        people("sv", "Avtalet undertecknades av Anna Mazur i Stockholm.").is_empty(),
        "«Mazur» is in no list and ends like nothing, so it is nobody yet"
    );
    assert_eq!(
        people("sv", "Med vänliga hälsningar\nErik Johansson"),
        vec!["Erik".to_string(), "Johansson".to_string()],
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
        vec!["Thomas".to_string(), "Müller".to_string()]
    );
    assert_eq!(people("de", "Prim. Dr. Ludwig Neuner (Klinikum Freistadt)"), vec!["Ludwig".to_string(), "Neuner".to_string()]);
    assert_eq!(people("de", "Thomas Müller hat den Vertrag unterschrieben."), vec!["Thomas".to_string(), "Müller".to_string()]);
    assert!(people("de", "Beschwerden der Frau (N95.1)").is_empty());
    assert!(people("de", "An Müller GmbH, Lindenstraße 8").is_empty());
    // And German's own three rules, which no other pack carries.
    let plate = findings("de", "Mein Fahrzeug mit dem Kennzeichen A-MW 2041 war da.");
    assert!(plate.iter().any(|(_, kind, _)| *kind == Kind::Vehicle), "{plate:?}");
}

/// **Every language names itself, and carries its code** — paper 117 item 2,
/// 25 October 2026, from the owner's look at the Arabic screens.
///
/// Settings drew «German (DE)», «English (EN)», «Svenska (SV)», «العربية».
/// Two faults in one line of four: German was named in **English**, and
/// Arabic carried **no code**. A person scanning a list for their own
/// language looks for the word they would write themselves, and the code is
/// what tells two spellings of one language apart.
///
/// So the shape is the law rather than four literals: a row's label ends with
/// its own id in brackets, and the word before the brackets is not the
/// language's English name unless English is what that language calls itself.
/// The second half is what would have caught «German (DE)» — it is the one a
/// literal list could never express, because the list would have been written
/// from the same mistake.
#[test]
fn every_language_names_itself_and_carries_its_code() {
    let rows = packs().expect("the installed packs");
    assert!(rows.len() >= 4, "fewer rows than this build carries packs: {rows:?}");
    for row in &rows {
        let code = format!(" ({})", row.id.to_uppercase());
        assert!(
            row.label.ends_with(&code),
            "«{}» does not end with its own code «{}» — a person cannot tell two \
             spellings of one language apart without it",
            row.label,
            code.trim()
        );
        let own_name = row.label[..row.label.len() - code.len()].trim().to_string();
        assert!(!own_name.is_empty(), "«{}» is a code and no name", row.label);
        // The English name is what a **reason** uses, and it is a different
        // field in the pack for exactly that purpose. Where a language's own
        // word differs from its English name, the label must carry the own
        // word — which is the half that catches «German (DE)». The English
        // names are written here because `in_english` is the core's own and
        // not in the public row; they are facts about four languages, and a
        // fifth that is missing from this table simply is not checked.
        let in_english: &[(&str, &str)] =
            &[("de", "German"), ("en", "English"), ("sv", "Swedish"), ("ar", "Arabic")];
        if let Some((_, english)) = in_english.iter().find(|(id, _)| *id == row.id) {
            // English is the one language whose own word **is** its English
            // name, so it is the exception the rule has to name.
            assert!(
                own_name != *english || row.id == "en",
                "«{}» names {} in English, and a language is named in its own words",
                row.label,
                english
            );
        }
    }
    // And the four this build carries, by name, so that a shape nobody reads
    // cannot pass over an empty list.
    let by_id: std::collections::BTreeMap<_, _> =
        rows.iter().map(|r| (r.id.as_str(), r.label.as_str())).collect();
    assert_eq!(by_id.get("de"), Some(&"Deutsch (DE)"));
    assert_eq!(by_id.get("en"), Some(&"English (EN)"));
    assert_eq!(by_id.get("sv"), Some(&"Svenska (SV)"));
    assert_eq!(by_id.get("ar"), Some(&"العربية (AR)"));
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
    assert_eq!(people("de", "Sehr geehrte Frau Anna Weber,"), vec!["Anna".to_string(), "Weber".to_string()]);
    assert_eq!(
        people("sv", "Hej Herr Lars Andersson,"),
        vec!["Lars".to_string(), "Andersson".to_string()]
    );
    // And a pack this build has never heard of scans with less knowledge
    // rather than failing — the rule the label sets already followed.
    let session = open_session(None, "ar".to_string()).expect("an unknown pack still opens");
    import_text(session, "Kundennummer: 41-88203".to_string()).expect("import");
    let report = scan(session).expect("and still scans");
    assert!(report.normal > 0, "{report:?}");
    let _ = close_session(session);
}

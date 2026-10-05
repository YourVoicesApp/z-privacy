// German Name Dictionary V1 — the owner's experiment, item by item.
//
// 310 names: 300 given names from Berlin 2023 and the ten commonest surnames in
// Germany. The question he asked is not «does a dictionary help» but a narrower
// and better one: **did these 300 names improve Person detection without
// raising false positives?** If yes, widen the source; if no, do not assume a
// bigger dictionary would have been better.
//
// So the dictionary is a signal and never a verdict, in his own four tiers:
//
//   Herr Thomas Müller   very high — and it was already protected outright
//   Thomas Müller        high      — offered, because two names stand in a row
//   Thomas               a match, and no certainty
//   Müller               a possible surname, not always enough
//
// Item E of the paper asks for nine tests. Two of them live beside the loader
// in `packs/de_names.rs` (it loads; German letters survive), the suite and the
// gates are the seventh, and the rest are here.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

fn findings_of(doc: &str) -> Vec<(MarkState, Kind, String, String)> {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    list_findings(s)
        .expect("findings")
        .into_iter()
        .map(|f| {
            let text = String::from_utf16_lossy(
                units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
            );
            (f.state, f.kind, text, f.reason)
        })
        .collect()
}

fn people(doc: &str) -> Vec<(MarkState, String)> {
    findings_of(doc)
        .into_iter()
        .filter(|(_, kind, _, _)| *kind == Kind::Person)
        .map(|(state, _, text, _)| (state, text))
        .collect()
}

/// E3 — a salutation and a name is the strongest case there is, and the
/// dictionary must not touch it: it was protected outright before V1 existed,
/// and it is protected outright now, once and not twice.
#[test]
fn a_salutation_and_a_name_is_protected_outright_and_only_once() {
    let found = people("Sehr geehrter Herr Thomas Müller, vielen Dank.");
    assert_eq!(found, vec![(MarkState::Protected, "Thomas Müller".to_string())]);
}

/// E4 — two names in a row, with nothing in front of them. This is the case
/// the dictionary exists for: the pack had no way to see it before, because
/// nothing in the sentence says «a person follows».
#[test]
fn a_given_name_and_a_surname_in_a_row_are_offered() {
    let found = people("Thomas Müller hat den Vertrag am 3. März unterschrieben.");
    assert_eq!(
        found,
        vec![(MarkState::Suggested, "Thomas Müller".to_string())],
        "two names in a row are offered for a word, never protected by the list alone"
    );
    // And the reason says which list said so, because a person asked to decide
    // is owed the reason.
    let reason = findings_of("Thomas Müller hat den Vertrag am 3. März unterschrieben.")
        .into_iter()
        .find(|(_, kind, _, _)| *kind == Kind::Person)
        .map(|(_, _, _, reason)| reason)
        .unwrap_or_default();
    assert!(reason.contains("dictionary") || reason.contains("name list"), "«{reason}»");
}

/// E5 — a single hit is a match and nothing more. Neither half of a name, on
/// its own, is a person: this is the line the whole experiment stands on.
#[test]
fn a_single_name_on_its_own_is_never_a_person() {
    for doc in [
        "Thomas wurde am Montag geliefert.",
        "Müller ist die Antwort.",
        "Im August fahren wir.",
        "Die Rose blüht im Garten.",
        "Der Max liegt bei 40 Grad.",
    ] {
        assert!(people(doc).is_empty(), "«{doc}» named a person: {:?}", people(doc));
    }
}

/// E6 — nothing the pack already did may change. Each of these was found by a
/// rule that existed before the dictionary, and each must still be found by it.
#[test]
fn the_rules_that_were_there_before_still_hold() {
    assert_eq!(
        people("Ansprechpartner: Frau Anna Weber"),
        vec![(MarkState::Protected, "Anna Weber".to_string())],
        "the salutation rule"
    );
    assert_eq!(
        people("Prim. Dr. Ludwig Neuner (Klinikum Freistadt)"),
        vec![(MarkState::Protected, "Ludwig Neuner".to_string())],
        "the title rule"
    );
    assert!(
        people("Beschwerden der Frau (N95.1)").is_empty(),
        "and the shape of a name still rules an ICD code out"
    );
    // A company is still a company, and is not read as two names.
    let company: Vec<String> = findings_of("Kunde: Nordstern Consulting GmbH")
        .into_iter()
        .filter(|(_, kind, _, _)| *kind == Kind::Company)
        .map(|(_, _, text, _)| text)
        .collect();
    assert_eq!(company, vec!["Nordstern Consulting GmbH".to_string()]);
}

/// E8 — a small German set, positive and negative, written as a person writes.
#[test]
fn a_small_german_set_positive_and_negative() {
    // Positive: a person is named, and the scanner says so one way or another.
    for doc in [
        "Herr Thomas Müller",
        "Frau Sophie Schneider hat angerufen.",
        "Thomas Müller",
        "Mit freundlichen Grüßen\nLukas Fischer",
        "Dr. Marie Hoffmann",
    ] {
        assert!(!people(doc).is_empty(), "«{doc}» names nobody");
    }
    // Negative: these name nobody, and a dictionary hit inside them changes
    // nothing. «August» and «Rose» and «Max» are in the 300.
    for doc in [
        "Im August 2026 liefern wir.",
        "Die Rose im Garten ist rot.",
        "Der Max der Messwerte liegt bei 40.",
        "Beschwerden der Frau (N95.1)",
        "Rechnung Nr. 2026-04471 vom 14. September",
        "Die Lieferung erfolgt nach Berlin.",
        "Kunde: Nordstern Consulting GmbH",
    ] {
        assert!(people(doc).is_empty(), "«{doc}» named a person: {:?}", people(doc));
    }
}

/// The dictionary may never protect anything by itself. Written as its own
/// test because it is the promise of item B and the leader's framing both: a
/// word is not raised to Auto by a list of names.
#[test]
fn the_dictionary_never_protects_anything_by_itself() {
    for doc in [
        "Thomas Müller",
        "Sophie Schneider und Lukas Fischer",
        "Marie Weber, Anna Becker, Felix Wagner",
    ] {
        for (state, text) in people(doc) {
            assert_eq!(
                state,
                MarkState::Suggested,
                "«{text}» was protected by the name list alone, in «{doc}»"
            );
        }
    }
}

/// The measurement that decides whether to widen the source, written as a test
/// so that widening it cannot be done quietly.
///
/// Nine of the 300 given names are ordinary German words when they begin a
/// sentence — `An` (rank 175), `August` (176), `Nur` (224), `Max` (145), `Rose`
/// (100), `Mark` (244), `Ida`, `Emma`, `Ben`. They are real names, used in
/// Berlin, and they belong in the list. What keeps them harmless is the other
/// half of the rule: the surname must be one of the ten.
///
/// Swept over the owner's two large files — 10,385 capitalised words in the tax
/// book and 99,031 in the Austrian document — the rule as built fires **zero**
/// times. If the surname half were loosened to «any capitalised word», it would
/// fire 6 times in the tax book, all six wrong («An EU-Listung», «August
/// BGBl», «An Finanzamt», «Nur Unternehmer»…), and 9 times in the Austrian
/// document, of which 5 are wrong («Nur Störung», «Amelie Q73»…) and one is a
/// person nothing finds today: Anna Mildschuh.
///
/// Eleven false for one true. So the surname list is what may be widened, and
/// «any capitalised word» is what may not — and this test is what fails if
/// somebody tries.
#[test]
fn a_german_word_that_is_also_a_name_stays_harmless() {
    for doc in [
        "An Beispiel 3 ist zu erkennen, dass die Frist läuft.",
        "August BGBl. II Nr. 42 vom 3. März.",
        "Nur Unternehmer dürfen die Erklärung abgeben.",
        "An Finanzamt Berlin-Mitte, Abteilung 4.",
        "Max Zulässige Höhe laut Anlage 2.",
        "Rose Blüte und Blatt, Anlage 7.",
    ] {
        assert!(
            people(doc).is_empty(),
            "«{doc}» named a person — a given name that is also a German word has been \
             let through, which means the surname half of the rule was loosened: {:?}",
            people(doc)
        );
    }
}

// German prose is not a form, and a label in it is not a label.
//
// The owner scanned a 146-page book of tax terms on 3 October. Seven values
// were protected automatically and three of them were the words «und», «muss»
// and «setzt»; seventeen more waited for his word and they were «des», «bei»,
// «das», «mit», «zu». Every one of them came from the same thing: a label rule
// that had just been taught to work without a colon, firing on an ordinary
// sentence — «Geburtsdatum und seine Steuernummer», «in Rechnung gestellt»,
// «E-Mail versenden».
//
// And one of those words was then protected in **every** place it occurred,
// including inside other words, so the safe text read «Ges[token]heitswesen».
//
// A label with a colon is a form. A label without one is only a label when
// what follows it is shaped like a value.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

fn findings_of(doc: &str) -> Vec<(MarkState, Kind, String)> {
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
            (f.state, f.kind, text)
        })
        .collect()
}

#[test]
fn a_label_in_a_sentence_takes_no_ordinary_word() {
    for sentence in [
        "Damit er die Lohnsteuerabzugsmerkmale abrufen kann, benötigt er dessen Geburtsdatum und seine Steuernummer.",
        "Die Kosten werden in Rechnung gestellt und dem Kunden mitgeteilt.",
        "Bitte das Formular per E-Mail versenden, nicht per Fax.",
        "Dem Umstand wurde Rechnung getragen.",
    ] {
        let found = findings_of(sentence);
        assert!(
            found.is_empty(),
            "a sentence is not a form, and «{sentence}» gave {found:?}"
        );
    }
}

#[test]
fn a_label_without_a_colon_still_takes_a_value() {
    let found = findings_of("Ich beziehe mich auf den Vertrag mit der Kundennummer 7733-9120 vom Mai.");
    assert_eq!(
        found.iter().map(|(_, k, t)| (*k, t.as_str())).collect::<Vec<_>>(),
        vec![(Kind::CustomerNo, "7733-9120")],
        "the letter's own case must keep working: {found:?}"
    );

    let found = findings_of("Steuernummer 143/815/08154 und USt-IdNr. DE123456789 sind oben.");
    assert_eq!(found.len(), 2, "both identifiers, and nothing else: {found:?}");
}

/// A value protected once is protected in every **place** it stands — not in
/// every string of letters that happens to contain it.
#[test]
fn a_protected_word_does_not_spread_inside_other_words() {
    let doc = "Herr Tobias Reinhardt war da. Die Reinhardtstraße 4 liegt daneben.";
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let handle = build_payload(s).expect("build");
    let safe = payload_view(handle).expect("view").text;

    assert!(!safe.contains("Reinhardt war"), "the name itself is protected: {safe}");
    assert!(
        safe.contains("Reinhardtstraße"),
        "the street kept a name inside it, and the token went in the middle of a word: {safe}"
    );
}

/// Measured in the tax book: a table of amounts whose columns ran together —
/// «6.000.000193030bis einschl. 13.000.000233550» — and the piece
/// «000.000274050» was offered as a telephone number.
#[test]
fn a_run_of_zeros_is_not_a_telephone_number() {
    let found = findings_of("Die Spalte zeigt 000.000274050 als Betrag.");
    assert!(found.is_empty(), "no telephone number begins with three zeros: {found:?}");

    let found = findings_of("Telefon 03018 272-2721 erreichen Sie uns.");
    assert_eq!(found.len(), 1, "a real service number is still found: {found:?}");
    assert_eq!(found[0].1, Kind::Phone);
}

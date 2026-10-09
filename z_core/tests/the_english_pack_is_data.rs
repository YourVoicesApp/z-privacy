// **The third language is data too** — the owner's item of 9 October.
//
// His words: «قواعد اللغة السويدية تشابه الإنكليزية، حتى الأسماء التي تنتهي
// بـ ‎-son» — Swedish's habits resemble English's, down to the surnames ending
// in `-son`. So English arrives the way Swedish did: a locale, word lists, a
// name list and a line of provenance, read by rules that already exist.
//
// `en` has shipped as a **rule set** since 29 September (labels: a National
// Insurance number, a VAT number, a sort code). What it had no part of was
// **discovery** — the half that finds a person no list knows. A document could
// be scanned with the English labels and the person in it was nobody.
//
// Measured on the film's own English letter, EN-1, so what this file asserts is
// what the owner will see on camera.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// The film's EN-1, as the shapes that matter: an honorific before a surname,
/// a role under a signature, a company's legal form, and a letter's closing.
/// Copied into the test so the guard is deterministic and reaches no file.
const LETTER: &str = "\
PELLBROOK & VANCE
Chartered Accountants

Harrow Lane Logistics Ltd
Leeds LS11 9QT

Dear Ms Whitfield,

We will take over the monthly payroll from 1 February.
As discussed with Mr Hale, overtime for the Leeds depot will be reported
separately from the Manchester figures.

Yours sincerely,

Rowan Pellbrook
Partner, Pellbrook & Vance
";

/// A document of the same shape with no person in it — the control. If the
/// pack offers somebody here, it is offering words rather than names.
const NOBODY: &str = "\
Harrow Lane Logistics Ltd
Leeds LS11 9QT

Client number: 440821
Invoice number: 2027-0114

Payment is due thirty days from the date of this letter. The February run is
ready and the figures for the depot are set out at the end of it.

Yours sincerely,
";

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

// ------------------------------------------------------- 1 · the pack exists

/// **English is the third pack, and the list of packs is the one list.**
#[test]
fn english_is_installed_and_carries_its_names() {
    let row = packs()
        .expect("packs")
        .into_iter()
        .find(|p| p.id == "en")
        .expect("English is in the installed list");
    assert_eq!(row.locale, "en-GB", "the pack names its locale, and the rows read it");
    assert!(
        row.given > 100 && row.family > 100,
        "the row reports the names the pack carries, and it reported {} given and {} family",
        row.given,
        row.family
    );
}

// ------------------------------------------------------- 2 · the film's letter

/// **The honorific, the closing and the role, reading English words.**
///
/// Every name here is one no list knows — the film's documents were written
/// that way on purpose — so what finds them is the form and nothing else.
#[test]
fn the_films_english_letter_is_read_by_a_pack_of_english_words() {
    let found = people("en", LETTER);
    for name in ["Whitfield", "Hale", "Rowan Pellbrook"] {
        assert!(
            found.iter().any(|f| f == name),
            "«{name}» is what the English forms in this letter point at, and the pack found {found:?}"
        );
    }
}

/// **The company's legal form is read as an organisation.**
#[test]
fn an_english_company_ends_in_its_legal_form() {
    let orgs: Vec<String> = findings("en", LETTER)
        .into_iter()
        .filter(|(_, kind, _)| *kind == Kind::Company)
        .map(|(_, _, text)| text)
        .collect();
    assert!(
        orgs.iter().any(|o| o.contains("Harrow Lane Logistics Ltd")),
        "«Ltd» is how an English company's name ends, and the pack found {orgs:?}"
    );
}

// ------------------------------------------------------- 3 · the control

/// **A document with no person in it offers nobody.**
#[test]
fn a_document_with_no_names_offers_nobody() {
    let found = people("en", NOBODY);
    assert!(
        found.is_empty(),
        "this document holds no person, and the pack offered {found:?}"
    );
}

/// **«-son» is a surname's ending in English as it is in Swedish** — the
/// owner's own sentence, and the reason it is in the pack.
///
/// Measured in the pack's own CC0 list: **25 of its 150 British family names
/// end in `-son`** — Wilson, Johnson, Robinson, Thompson, Anderson, Jackson.
/// So the ending offers a name the rules would otherwise walk past, exactly as
/// it does in Swedish, and it can never protect one by itself.
#[test]
fn an_english_surname_that_ends_in_son_is_offered() {
    assert_eq!(
        people("en", "The contract was signed by John Harrowson in Leeds."),
        vec!["John Harrowson".to_string()],
        "«Harrowson» is in no list and ends like an English surname"
    );
    // And the trap that ending carries, which Swedish does not have: English
    // builds ordinary nouns the same way.
    for word in ["Person", "Reason", "Season", "Comparison"] {
        assert!(
            people("en", &format!("{word} Harrow was recorded in the depot system.")).is_empty(),
            "«{word}» ends in «son» and is an ordinary English word, never a name"
        );
    }
}

// ------------------------------------------------------- 4 · nothing moved

/// German and Swedish read exactly what they read before.
#[test]
fn the_other_two_packs_did_not_move() {
    assert_eq!(
        people("de", "Ich schreibe an Herrn Thomas Müller wegen des Vertrages."),
        vec!["Thomas Müller".to_string()],
    );
    assert_eq!(
        people("sv", "Avtalet undertecknades av Anna Nilsson i Stockholm."),
        vec!["Anna Nilsson".to_string()],
    );
}

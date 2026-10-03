// A title is not a name, and «Frau» is not always a salutation.
//
// The owner imported a 734-page Austrian ICD-10 document on 3 October and said
// the protection had landed on the wrong part of the text. It had. Measured,
// seven things were protected automatically and five of them were wrong:
//
//   «besonderer Dank gilt Frau ⟦Mag⟧. Gudrun Spitzwieser»   the title, while
//                                                           the name stayed bare
//   «bei der Frau ⟦(N95.1⟧)»  ·  «Frau ⟦(N90.4⟧)»           ICD-10 codes
//   «bei der Frau ⟦(N81.1⟧)»  ·  «bei der Frau ⟦(N81.0⟧)»
//
// Two causes, and both are about what a name is. In medical German «Frau» is an
// ordinary noun — «Beschwerden der Frau», «bei der Frau» — and a salutation is
// not preceded by an article. And whatever follows a salutation has to be
// shaped like a name: letters, perhaps a hyphen, no digits and no brackets.
//
// The third thing is what the owner expected and did not get: the team page of
// that document is a column of doctors — Dr. Andreas Egger, Dr. Florian
// Röthlin, Prim. Dr. Ludwig Neuner, DI Bernhard Pesec, Ing. Mag. Alexander
// Wölfl — and not one of them was protected, because a title only counted
// **after** a salutation. In German and Austrian writing the title is how a
// name is introduced; it stands in the clear, and the name after it does not.
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

fn people(doc: &str) -> Vec<String> {
    findings_of(doc)
        .into_iter()
        .filter(|(_, kind, _)| *kind == Kind::Person)
        .map(|(_, _, text)| text)
        .collect()
}

#[test]
fn an_icd_code_after_frau_is_not_a_person() {
    // The exact line from the owner's document, four times over.
    let people = people(
        "Schmerzen und Klimakterium bei der Frau (N95.1)\n\
         Beschwerden der Frau (N90.4)\n\
         Prolaps bei der Frau (N81.1)\n\
         Senkung bei der Frau (N81.0)\n",
    );
    assert!(people.is_empty(), "a code is not a person: {people:?}");
}

#[test]
fn frau_as_an_ordinary_noun_names_nobody() {
    assert!(people("Beschwerden der Frau sind häufig.").is_empty());
    assert!(people("Die Gesundheit der Frau und des Mannes.").is_empty());
    // And the salutation still works where it is one.
    assert_eq!(people("Sehr geehrte Frau Anna Weber,"), vec!["Anna Weber"]);
    assert_eq!(people("Herr Thomas Müller hat unterschrieben."), vec!["Thomas Müller"]);
}

/// Refusing a salutation that follows an article was the first fix tried for
/// the ICD codes, and the first golden letter refused it: «den» here is a
/// relative pronoun, and the person after it is a person.
#[test]
fn a_word_like_den_in_front_of_a_salutation_takes_nothing_away() {
    assert_eq!(
        people("…, den Herr Tobias Reinhardt am 3. März 2025 unterzeichnet hat."),
        vec!["Tobias Reinhardt"]
    );
}

#[test]
fn an_austrian_title_is_stepped_over_and_the_name_is_taken() {
    assert_eq!(
        people("besonderer Dank gilt Frau Mag. Gudrun Spitzwieser für die Mitarbeit"),
        vec!["Gudrun Spitzwieser"],
        "the token landed on «Mag» in the owner's document"
    );
}

#[test]
fn a_title_at_the_start_of_a_name_protects_the_name() {
    // The team page, as it is written there.
    assert_eq!(people("Dr. Andreas Egger"), vec!["Andreas Egger"]);
    assert_eq!(people("Prim. Dr. Ludwig Neuner (Klinikum Freistadt, OÖG)"), vec!["Ludwig Neuner"]);
    assert_eq!(people("Ing. Mag. Alexander Wölfl"), vec!["Alexander Wölfl"]);
    assert_eq!(people("DI Bernhard Pesec (dothealth)"), vec!["Bernhard Pesec"]);
    assert_eq!(people("Univ.-Prof. Dr. med. Barbara Maier"), vec!["Barbara Maier"]);
}

#[test]
fn a_title_with_no_name_after_it_is_nothing() {
    assert!(people("Dr. med.").is_empty(), "a title alone names nobody");
    assert!(people("Mag.").is_empty());
    // A title inside a word is part of that word, not a title.
    assert!(people("Die Praxis liegt in der Dr.-Ing.-Straße 14.").is_empty());
}

#[test]
fn a_degree_after_the_name_is_left_where_it_stands() {
    assert_eq!(people("Dr. Hannes Schnabl MSc"), vec!["Hannes Schnabl"]);
    assert_eq!(people("Mag. Petra Paretta, MBA"), vec!["Petra Paretta"]);
}

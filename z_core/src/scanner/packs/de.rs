//! The German privacy pack.
//!
//! Three kinds of knowledge, and each one's confidence is a decision:
//!
//! Labels — `Kundennummer:`, `Telefon:` — used to live here as a Rust table.
//! Since 29 September they are rows in `scanner/sets/de.rs` and run through the
//! shared engine, so another language can be active at the same time. What is
//! left in this file is the German knowledge that is not a label: a salutation,
//! a legal form, the shape of an address.
//! * **A salutation names the person who follows it.** → `Auto`, and the name
//!   only: `Frau` itself stays in the clear so the model can still write a
//!   correct German reply.
//!
//!   It was a `Suggest` until 3 October, on the reading that «after `Frau`
//!   usually comes a person — usually». The owner scanned a letter of his own
//!   that day and said: «it did not hide the names… not one of the seven people
//!   was encrypted». A salutation in a German letter is not a guess about the
//!   next word; it is a word written to introduce a person. The confidence
//!   moved, the span did not, and `golden_scan.rs` recorded the change with its
//!   reason rather than absorbing it.
//! * **A signature is a name too** (3 October). A line of its own under a
//!   closing formula, or above a line that says what the person's role is.
//!   The owner signs his own name with no salutation in front of it, so nothing
//!   in this file had seen it — and after he had answered every question the
//!   app asked, his name was still in the text that would have left.
//! * **A company form is a hint too.** A run ending in `GmbH` is very probably a
//!   company, but a document can also discuss «die GmbH» in general. → `Suggest`.

use crate::api::Kind;

use super::pack::{bare, is_label, is_numberish, starts_upper, trimmed_end, LanguagePack, NameOrder, Word};
use crate::scanner::{Candidate, Confidence};

const PACK: &str = "de";

/// German, as the first implementation of the pack contract.
///
/// Every field points at a list that was already in this file: the data did not
/// change when it became data. What is **not** here is what is not language —
/// an e-mail address, an IBAN, a telephone number in international form — and
/// what is here beyond the lists is three rules no other language can use,
/// named in `extra` with the reason each one cannot be generalised.
pub(crate) fn pack() -> LanguagePack {
    LanguagePack {
        locale: "de-DE",
        id: PACK,
        label: "Deutsch",
        version: "1",
        salutations: SALUTATIONS,
        titles: TITLES,
        title_parts: TITLE_PARTS,
        degrees: DEGREES,
        function_words: FUNCTION_WORDS,
        stop_words: STOP_WORDS,
        closings: CLOSINGS,
        roles: ROLES,
        company_forms: COMPANY_FORMS,
        conjunctions: CONJUNCTIONS,
        order: NameOrder::GivenThenFamily,
        names: super::de_names::CSV,
        provenance: "Berlin, Bonn, Dortmund and Koeln newborn registers (CC BY 3.0 DE · CC0 · DL-DE-Zero 2.0) · Wikidata (CC0) · sigpwned/popular-names-by-country (CC0) — see z_core/assets/licenses/german_names_sources.md",
        extra: &[
            // A national plate format: «B-MW 2041» says where a car is
            // registered in Germany. Nothing about it generalises.
            ("vehicle plates", plates),
            // A local number written after the German word for telephone:
            // «Telefon: 089 1234 5678» has no country code, so the only thing
            // that says it is a number is the German word in front of it.
            ("local telephone numbers", local_phones),
            // A street line as German addresses are written: the street word is
            // part of the name («Lindenstraße 8») and the postcode is five
            // digits before the town.
            ("street addresses", addresses),
        ],
    }
}

/// Conjunctions a German company name may carry: «Lindemann & Partner»,
/// «Müller und Söhne». A list, because the rule is the same everywhere and
/// only the words change.
const CONJUNCTIONS: &[&str] = &["&", "und"];


/// Salutations and titles: what follows one of these is probably a person.
const SALUTATIONS: &[&str] = &["Herr", "Herrn", "Frau", "Fr.", "Hr."];

/// Titles that introduce a person, German and Austrian, as they are written.
///
/// Measured on a 734-page Austrian document whose team page is a column of
/// doctors: not one of them was protected, because a title only counted when a
/// salutation stood in front of it. In this writing the title **is** how a name
/// is introduced — «Prim. Dr. Ludwig Neuner», «Ing. Mag. Alexander Wölfl» — so
/// a title starts a name as well as sitting inside one.
const TITLES: &[&str] = &[
    "Dr.", "Dr", "Dr.in", "DDr.", "MMag.", "Mag.", "Mag", "Mag.a", "Prof.", "Prof",
    "Univ.-Prof.", "Univ.-Doz.", "Priv.-Doz.", "PD", "Prim.", "Prim", "DI", "Dipl.-Ing.",
    "Dipl.-Kfm.", "Ing.", "Bakk.",
];

/// The parts of a Latin title that never stand on their own: «Dr. med. univ.».
/// Stepped over inside a chain, and never the start of one — in German every
/// noun is capitalised, so «med. Abteilung» would otherwise name a person.
const TITLE_PARTS: &[&str] = &["med.", "rer.", "nat.", "phil.", "techn.", "univ.", "h.c.", "mult."];

/// German function words that are also given names in the dictionary.
///
/// `An` (at, to) is rank 175 of the 300 and `Nur` (only) is rank 224 — real
/// names, used in Berlin, and they belong in the list. But V2 widened the
/// surnames from ten to 601, of which 43 are ordinary German words (Koch a
/// cook, Richter a judge, Bauer a farmer), and the pair of those two facts is
/// «An Müller GmbH» — how a German letter is addressed — or «Nur Richter
/// dürfen entscheiden», which offered a protection on the word «only».
/// Measured: that pair never occurs in 880 pages of the owner's documents, and
/// it is one line of ordinary business German away.
///
/// A function word cannot open a name. It is kept here, in the rule, and not
/// taken out of the owner's list: the list says what Berlin named its children,
/// which is true, and this says what a sentence can mean, which is also true.
/// German words that are also given names, and are words far more often.
///
/// «An» and «Nur» came from Phase 1's measurement. «Per», «Mal» and «Anders»
/// come from 038-H's: the bank carries 5,712 given names where there were 300,
/// and three of the new ones are ordinary German function words — measured on
/// the two large German documents, which write «per Post», «Mal sehen» and
/// «anders als geplant» and mean none of them as a name. Without this list,
/// «Per Post versandt» offers «Per Post» as a person, and «per Post» is in
/// every second German business letter.
///
/// The cost, named: a person really called Per, Mal or Anders is not offered
/// by the dictionary rule in a German document. They are still protected by a
/// salutation, a title, a signature or a person's own word — the same price
/// «An» and «Nur» have paid since Phase 1.
const FUNCTION_WORDS: &[&str] = &["an", "nur", "per", "mal", "anders"];

/// Degrees that follow a name. They are not part of it and do not start one.
const DEGREES: &[&str] = &["MBA", "MSc", "BSc", "BA", "MA", "LL.M.", "PhD", "MPH", "MAS", "CFA"];

/// The legal forms a German company name ends with.
const COMPANY_FORMS: &[&str] = &[
    "GmbH", "AG", "UG", "KG", "OHG", "GbR", "SE", "e.K.", "eG", "mbH", "KGaA",
];

/// Capitalised words that start a sentence but belong to no name.
const STOP_WORDS: &[&str] = &[
    "Die", "Der", "Das", "Den", "Dem", "Des", "Ein", "Eine", "Einer", "Eines", "Unser", "Unsere",
    "Ihr", "Ihre", "Seine", "Mit", "Von", "An", "Bei", "Für", "Und", "Als", "Auch", "Diese",
    "Dieser", "Dieses", "Im", "In", "Am", "Zur", "Zum", "Wir", "Sie", "Es", "Herzlich",
];

/// Words that make a street name.
const STREET_ENDINGS: &[&str] = &[
    "straße", "strasse", "str.", "str", "weg", "platz", "allee", "gasse", "ring", "damm", "ufer",
];

/// The last word of a German closing formula, lowercased.
const CLOSINGS: &[&str] = &["grüßen", "grüssen", "grüße", "grüsse", "hochachtungsvoll"];

/// What a line under a signature says about the person who signed.
const ROLES: &[&str] = &[
    "geschäftsführer", "geschäftsführerin", "inhaber", "inhaberin", "i.a.", "ppa.", "prokurist",
    "vorstand", "mitglied",
];

/// Words that name a telephone number before one is written.
const PHONE_WORDS: &[&str] = &[
    "telefon", "telefonnummer", "tel", "tel.", "mobil", "handy", "durchwahl", "fax", "rufnummer",
];

/// `A-MW 2041` — a German plate: a town's letters, a hyphen, letters, a number.
fn plates(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare(word.text);
        let Some((town, letters)) = w.split_once('-') else { continue };
        let town_ok = (1..=3).contains(&town.chars().count())
            && town.chars().all(|c| c.is_uppercase() && c.is_alphabetic());
        let letters_ok = (1..=2).contains(&letters.chars().count())
            && letters.chars().all(|c| c.is_uppercase() && c.is_alphabetic());
        if !town_ok || !letters_ok {
            continue;
        }
        let Some(number) = words.get(i + 1) else { continue };
        if number.newline_before {
            continue;
        }
        let digits = bare(number.text);
        if digits.is_empty() || digits.chars().count() > 4 || !digits.chars().all(|c| c.is_ascii_digit()) {
            continue;
        }
        out.push(super::people::candidate(
            &pack(),
            word.start,
            trimmed_end(number),
            Kind::Vehicle,
            Confidence::Auto,
            "plate",
            "the shape of a German registration plate".to_string(),
        ));
    }
}

/// `mobil unter 0171 9876543` — a local number is only a number until a word
/// nearby says it is a telephone. Then it is one, and it is not a question.
fn local_phones(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare(word.text);
        let local = w.len() >= 3 && w.starts_with('0') && w.chars().all(|c| c.is_ascii_digit());
        if !local {
            continue;
        }
        // A telephone word earlier on the same line, within a few words.
        let mut said_phone = false;
        let mut back = i;
        while back > 0 {
            back -= 1;
            let Some(prev) = words.get(back) else { break };
            if prev.newline_before || i - back > 6 {
                break;
            }
            if PHONE_WORDS.contains(&bare(prev.text).to_lowercase().trim_end_matches(':')) {
                said_phone = true;
                break;
            }
        }
        if !said_phone {
            continue;
        }
        // The number may be written in groups: «089 1234 5699».
        let mut last = i;
        let mut j = i + 1;
        while let Some(next) = words.get(j) {
            let n = bare(next.text);
            if next.newline_before || n.is_empty() || !n.chars().all(|c| c.is_ascii_digit()) || j - i > 3 {
                break;
            }
            last = j;
            j += 1;
        }
        let Some(end_word) = words.get(last) else { continue };
        out.push(super::people::candidate(
            &pack(),
            word.start,
            trimmed_end(end_word),
            Kind::Phone,
            Confidence::Auto,
            "local-phone",
            "a local telephone number, written after a word that names one".to_string(),
        ));
    }
}

/// «Hafenstraße 14, 20359 Hamburg» — a street, a house number, a postcode, a town.
fn addresses(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare(word.text);
        let is_postcode = w.len() == 5 && w.chars().all(|c| c.is_ascii_digit());
        if !is_postcode {
            continue;
        }
        // A town must follow.
        let Some(town) = words.get(i + 1) else { continue };
        if !starts_upper(town.text) {
            continue;
        }
        // Walk left: a house number, then a street.
        let mut first = i;
        if i >= 2 {
            let house = words.get(i - 1);
            let street = words.get(i - 2);
            if let (Some(house), Some(street)) = (house, street) {
                let house_ok = is_numberish(bare(house.text));
                let s = bare(street.text).to_lowercase();
                let street_ok = STREET_ENDINGS.iter().any(|e| s.ends_with(e));
                if house_ok && street_ok {
                    first = i - 2;
                    // A street may be two words: «Berliner Allee», «Alter
                    // Markt». The word before it joins when it is capitalised
                    // and is not the end of the sentence before it.
                    if let Some(before) = first.checked_sub(1).and_then(|k| words.get(k)) {
                        let b = bare(before.text);
                        let joins = starts_upper(b)
                            && !b.is_empty()
                            && !STOP_WORDS.contains(&b)
                            && !is_label(before.text)
                            && !before.text.ends_with(',')
                            && !before.text.ends_with('.')
                            && !before.text.ends_with(':')
                            && !words.get(first).is_some_and(|w| w.newline_before);
                        if joins {
                            first -= 1;
                        }
                    }
                }
            }
        }
        let Some(start_word) = words.get(first) else { continue };
        out.push(super::people::candidate(
            &pack(),
            start_word.start,
            trimmed_end(town),
            Kind::Address,
            Confidence::Suggest,
            "address",
            "a postcode and a town, with a street before them — an address, if this one is a person's".to_string(),
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn found(text: &str) -> Vec<(Kind, Confidence, String)> {
        crate::scanner::packs::people::scan_with(text, &pack(), &[])
            .into_iter()
            .map(|c| {
                (
                    c.kind,
                    c.confidence,
                    text.get(c.start..c.end).unwrap_or_default().to_string(),
                )
            })
            .collect()
    }

    #[test]
    fn a_salutation_points_at_the_name_and_leaves_the_salutation() {
        // «Frau» stays in the clear: the model still needs it to write a correct
        // German reply, and it hides nothing on its own. What changed on
        // 3 October is the confidence, not the span: the salutation is the
        // proof, so the name after it is protected rather than asked about.
        assert_eq!(
            found("Frau Anna Weber übernimmt."),
            vec![(Kind::Person, Confidence::Auto, "Anna Weber".to_string())]
        );
        assert_eq!(
            found("Herr Dr. Schneider ruft an."),
            vec![(Kind::Person, Confidence::Auto, "Schneider".to_string())]
        );
    }

    #[test]
    fn a_company_form_takes_the_whole_name() {
        assert_eq!(
            found("Kunde: Nordstern Consulting GmbH"),
            vec![(
                Kind::Company,
                Confidence::Suggest,
                "Nordstern Consulting GmbH".to_string()
            )]
        );
        assert_eq!(
            found("Die Hamburger Hafen Logistik GmbH & Co. KG liefert."),
            vec![(
                Kind::Company,
                Confidence::Suggest,
                "Hamburger Hafen Logistik GmbH & Co. KG".to_string()
            )]
        );
        // A sentence about companies in general is not a company name.
        assert!(found("Die GmbH ist eine Rechtsform.").is_empty());
    }


    #[test]
    fn an_address_needs_a_postcode_and_a_town() {
        assert_eq!(
            found("Lieferung an die Hafenstraße 14, 20359 Hamburg."),
            vec![(
                Kind::Address,
                Confidence::Suggest,
                "Hafenstraße 14, 20359 Hamburg".to_string()
            )]
        );
        // A bare five-digit number is not an address.
        assert!(found("Die Rechnung 20359 ist offen.").is_empty());
    }

    #[test]
    fn every_finding_says_which_pack_and_why() {
        for c in crate::scanner::packs::people::scan_with("Frau Anna Weber, Kundennummer: 41-88203, Nordstern Consulting GmbH", &pack(), &[]) {
            assert!(c.source_detail.starts_with("de:"), "{}", c.source_detail);
            assert!(!c.reason.is_empty());
        }
    }
}

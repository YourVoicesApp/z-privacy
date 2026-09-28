//! The German privacy pack.
//!
//! Three kinds of knowledge, and each one's confidence is a decision:
//!
//! * **A label is proof of what follows.** After `Kundennummer:` comes a customer
//!   number; nothing else does. → `Auto`.
//! * **A salutation is a hint about the next word.** After `Frau` usually comes a
//!   person — usually. → `Suggest`, and the name only: `Frau` itself stays in the
//!   clear so the model can still write a correct German reply.
//! * **A company form is a hint too.** A run ending in `GmbH` is very probably a
//!   company, but a document can also discuss «die GmbH» in general. → `Suggest`.

use crate::api::{Kind, Source};

use crate::scanner::{Candidate, Confidence};

const PACK: &str = "de";

/// Salutations and titles: what follows one of these is probably a person.
const SALUTATIONS: &[&str] = &["Herr", "Herrn", "Frau", "Fr.", "Hr."];
/// Titles that sit between the salutation and the name.
const TITLES: &[&str] = &["Dr.", "Dr", "Prof.", "Prof", "Dipl.-Ing.", "Ing."];
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

/// A label, what it proves, and how its value is written.
struct Label {
    word: &'static str,
    kind: Kind,
    shape: Shape,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Shape {
    /// Digits with separators: a telephone number, a customer number.
    Number,
    /// One word with no spaces: an address, a tax id.
    Word,
    /// Letters and digits in groups: an IBAN, a BIC.
    Grouped,
}

const LABELS: &[Label] = &[
    Label { word: "telefon", kind: Kind::Phone, shape: Shape::Number },
    Label { word: "tel", kind: Kind::Phone, shape: Shape::Number },
    Label { word: "tel.", kind: Kind::Phone, shape: Shape::Number },
    Label { word: "mobil", kind: Kind::Phone, shape: Shape::Number },
    Label { word: "handy", kind: Kind::Phone, shape: Shape::Number },
    Label { word: "fax", kind: Kind::Phone, shape: Shape::Number },
    Label { word: "e-mail", kind: Kind::Email, shape: Shape::Word },
    Label { word: "email", kind: Kind::Email, shape: Shape::Word },
    Label { word: "mail", kind: Kind::Email, shape: Shape::Word },
    Label { word: "iban", kind: Kind::Iban, shape: Shape::Grouped },
    Label { word: "bic", kind: Kind::Bic, shape: Shape::Grouped },
    Label { word: "kontonummer", kind: Kind::Account, shape: Shape::Number },
    Label { word: "konto", kind: Kind::Account, shape: Shape::Number },
    Label { word: "kundennummer", kind: Kind::CustomerNo, shape: Shape::Number },
    Label { word: "kunden-nr.", kind: Kind::CustomerNo, shape: Shape::Number },
    Label { word: "kundennr.", kind: Kind::CustomerNo, shape: Shape::Number },
    Label { word: "steuernummer", kind: Kind::TaxId, shape: Shape::Word },
    Label { word: "steuer-nr.", kind: Kind::TaxId, shape: Shape::Word },
    Label { word: "ust-idnr.", kind: Kind::TaxId, shape: Shape::Word },
    Label { word: "ust-id", kind: Kind::TaxId, shape: Shape::Word },
    Label { word: "umsatzsteuer-id", kind: Kind::TaxId, shape: Shape::Word },
];

/// One whitespace-separated token, with its byte range.
struct Word<'a> {
    start: usize,
    end: usize,
    text: &'a str,
    /// True when a line break sits between this word and the one before it.
    ///
    /// Two of the pack's rules need this: a name does not run past the end of a
    /// line, and neither does a labelled value. Without it, «Ansprechpartner:
    /// Herr Thomas Müller\nTelefon:» reads as a three-word name.
    newline_before: bool,
}

/// Is this word a label — «Telefon:», «BIC:» — rather than a value?
///
/// A label ends a value: `IBAN: DE89 … 00` must stop before `BIC:`, or one
/// finding swallows the next.
fn is_label(word: &str) -> bool {
    word.ends_with(':')
}

fn words(text: &str) -> Vec<Word<'_>> {
    let mut out = Vec::new();
    let mut index = 0usize;
    for token in text.split_whitespace() {
        if let Some(offset) = text.get(index..).and_then(|rest| rest.find(token)) {
            let start = index + offset;
            let end = start + token.len();
            let gap = text.get(index..start).unwrap_or_default();
            out.push(Word {
                start,
                end,
                text: token,
                newline_before: gap.contains('\n'),
            });
            index = end;
        }
    }
    out
}

/// The word without the punctuation a sentence puts around it.
fn bare(word: &str) -> &str {
    word.trim_matches(|c: char| matches!(c, ',' | ';' | ':' | '.' | '!' | '?' | '"' | '(' | ')' | '»' | '«'))
}

/// Same, but keeping a trailing dot, which belongs to «Dr.» and «e.K.».
fn bare_keep_dot(word: &str) -> &str {
    word.trim_matches(|c: char| matches!(c, ',' | ';' | ':' | '!' | '?' | '"' | '(' | ')' | '»' | '«'))
}

fn starts_upper(word: &str) -> bool {
    bare(word).chars().next().is_some_and(char::is_uppercase)
}

fn is_numberish(word: &str) -> bool {
    let w = bare(word);
    !w.is_empty()
        && w.chars().any(|c| c.is_ascii_digit())
        && w.chars().all(|c| c.is_ascii_digit() || matches!(c, '+' | '-' | '/' | '(' | ')' | '.' | ' '))
}

/// The end of `word`'s range with sentence punctuation trimmed off.
fn trimmed_end(word: &Word<'_>) -> usize {
    let cut = word.text.len() - word.text.trim_end_matches([',', ';', ':', '.', '!', '?', '"', ')', '»']).len();
    word.end.saturating_sub(cut)
}

pub(crate) fn scan(text: &str) -> Vec<Candidate> {
    let words = words(text);
    let mut out = Vec::new();
    salutations(&words, &mut out);
    companies(&words, &mut out);
    labelled(&words, &mut out);
    addresses(&words, &mut out);
    out
}

fn candidate(
    start: usize,
    end: usize,
    kind: Kind,
    confidence: Confidence,
    rule: &str,
    reason: String,
) -> Candidate {
    Candidate {
        start,
        end,
        kind,
        confidence,
        source: Source::LanguagePack,
        source_detail: format!("{PACK}:{rule}"),
        reason,
        entities: Vec::new(),
        also: Vec::new(),
    }
}

/// «Herr Thomas Müller» → the name, not the salutation.
fn salutations(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare_keep_dot(word.text);
        if !SALUTATIONS.iter().any(|s| s.eq_ignore_ascii_case(w)) {
            continue;
        }
        let mut j = i + 1;
        // Step over a title: «Herr Dr. Schneider».
        let mut title = None;
        while let Some(next) = words.get(j) {
            if next.newline_before {
                break;
            }
            let n = bare_keep_dot(next.text);
            if TITLES.iter().any(|t| t.eq_ignore_ascii_case(n)) {
                title = Some(n.to_string());
                j += 1;
            } else {
                break;
            }
        }
        // Then up to three capitalised words: «Anna Weber», «von der Leyen».
        let first = j;
        let mut last = None;
        while let Some(next) = words.get(j) {
            if next.newline_before || is_label(next.text) {
                break;
            }
            let n = bare(next.text);
            let is_name = starts_upper(n) || matches!(n, "von" | "van" | "de" | "der" | "zu");
            if is_name && j - first < 3 && !n.is_empty() {
                last = Some(j);
                // A word ending the phrase (comma, full stop) closes the name.
                if next.text.ends_with(',') || next.text.ends_with('.') || next.text.ends_with(';') {
                    break;
                }
                j += 1;
            } else {
                break;
            }
        }
        let (Some(last), Some(start_word)) = (last, words.get(first)) else {
            continue;
        };
        let Some(end_word) = words.get(last) else { continue };
        let reason = match title {
            Some(t) => format!("a name after «{w} {t}» — the German pack expects a person there, but only you can be sure"),
            None => format!("a name after «{w}» — the German pack expects a person there, but only you can be sure"),
        };
        out.push(candidate(
            start_word.start,
            trimmed_end(end_word),
            Kind::Person,
            Confidence::Suggest,
            "salutation",
            reason,
        ));
    }
}

/// «Nordstern Consulting GmbH» — and «GmbH & Co. KG» as one form.
fn companies(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare_keep_dot(word.text);
        if !COMPANY_FORMS.contains(&w) {
            continue;
        }
        // Walk left over capitalised words to the start of the name.
        let mut first = i;
        while first > 0 {
            // Do not walk back across a line break.
            if words.get(first).is_some_and(|w| w.newline_before) {
                break;
            }
            let Some(prev) = words.get(first - 1) else { break };
            let p = bare(prev.text);
            // A label, a comma or a full stop ends the name to the left:
            // «Kunde: Nordstern GmbH» is not called «Kunde Nordstern GmbH».
            let closes = prev.text.ends_with(':')
                || prev.text.ends_with(',')
                || prev.text.ends_with(';')
                || prev.text.ends_with('.');
            let function_word = STOP_WORDS.contains(&p);
            if !closes
                && !function_word
                && starts_upper(p)
                && !p.is_empty()
                && !SALUTATIONS.iter().any(|s| s.eq_ignore_ascii_case(p))
            {
                first -= 1;
            } else {
                break;
            }
        }
        if first == i {
            // «die GmbH» on its own is a word about companies, not a company.
            continue;
        }
        // «GmbH & Co. KG» keeps going to the right.
        let mut last = i;
        if let (Some(amp), Some(co), Some(kg)) = (words.get(i + 1), words.get(i + 2), words.get(i + 3)) {
            if bare(amp.text) == "&"
                && bare_keep_dot(co.text).eq_ignore_ascii_case("Co.")
                && COMPANY_FORMS.contains(&bare_keep_dot(kg.text))
            {
                last = i + 3;
            }
        }
        let (Some(start_word), Some(end_word)) = (words.get(first), words.get(last)) else {
            continue;
        };
        out.push(candidate(
            start_word.start,
            trimmed_end(end_word),
            Kind::Company,
            Confidence::Suggest,
            "company-form",
            format!("a name ending in «{w}», which is a German legal form — probably this client's company"),
        ));
    }
}

/// «Kundennummer: 41-88203» — the label says what follows.
fn labelled(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        if !word.text.ends_with(':') {
            continue;
        }
        let label = word.text.trim_end_matches(':').to_lowercase();
        let Some(found) = LABELS.iter().find(|l| l.word == label) else {
            continue;
        };
        let first = i + 1;
        let mut last = None;
        let mut j = first;
        while let Some(next) = words.get(j) {
            if next.newline_before || is_label(next.text) {
                break;
            }
            let n = bare(next.text);
            let fits = match found.shape {
                Shape::Number => is_numberish(n) || (j == first && n.starts_with('+') && n.len() > 1),
                Shape::Word => j == first && !n.is_empty(),
                Shape::Grouped => !n.is_empty() && n.chars().all(|c| c.is_ascii_alphanumeric()),
            };
            if fits && j - first < 8 {
                last = Some(j);
                j += 1;
            } else {
                break;
            }
        }
        let (Some(last), Some(start_word)) = (last, words.get(first)) else {
            continue;
        };
        let Some(end_word) = words.get(last) else { continue };
        out.push(candidate(
            start_word.start,
            trimmed_end(end_word),
            found.kind,
            // A label is proof of what follows, so the pack may act alone here.
            Confidence::Auto,
            "label",
            format!("the value written after «{}:», which says what it is", word.text.trim_end_matches(':')),
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
                }
            }
        }
        let Some(start_word) = words.get(first) else { continue };
        out.push(candidate(
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
        scan(text)
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
        // German reply, and it hides nothing on its own.
        assert_eq!(
            found("Frau Anna Weber übernimmt."),
            vec![(Kind::Person, Confidence::Suggest, "Anna Weber".to_string())]
        );
        assert_eq!(
            found("Herr Dr. Schneider ruft an."),
            vec![(Kind::Person, Confidence::Suggest, "Schneider".to_string())]
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
    fn a_label_is_proof_of_what_follows() {
        assert_eq!(
            found("Kundennummer: 41-88203"),
            vec![(Kind::CustomerNo, Confidence::Auto, "41-88203".to_string())]
        );
        assert_eq!(
            found("USt-IdNr.: DE811728394"),
            vec![(Kind::TaxId, Confidence::Auto, "DE811728394".to_string())]
        );
        assert_eq!(
            found("Telefon: 0171 2345678"),
            vec![(Kind::Phone, Confidence::Auto, "0171 2345678".to_string())]
        );
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
        for c in scan("Frau Anna Weber, Kundennummer: 41-88203, Nordstern Consulting GmbH") {
            assert!(c.source_detail.starts_with("de:"), "{}", c.source_detail);
            assert!(!c.reason.is_empty());
        }
    }
}

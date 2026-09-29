//! German label rules.
//!
//! Every row here was a line of Rust in `packs/de.rs` before 29 September. The
//! behaviour is the same; what changed is that Swedish can now be added beside
//! it without either file knowing about the other.

use crate::api::{Kind, Source};

use crate::scanner::rules::{Boundary, LabelRule, Validator};
use crate::scanner::Confidence;

use super::RuleSet;

/// `(id, label, kind, validator, decision)` — the whole set, as rows.
///
/// The decision is **per row**, not per set. A label is usually proof of what
/// follows, but not always: «Ansprechpartner» names a person the way a
/// salutation does, and the owner's ruling of 29 September keeps it a
/// question. Making the column exist is what lets one row change its mind
/// later without the set changing its nature.
// NOTE — «Ansprechpartner» is a row, and it is a **Suggest**.
//
// It was held back on 29 September because adding it as an `Auto` would have
// changed what the scanner decides, where M7.10B was a move of words into
// data. The golden fixture caught exactly that drift. The owner's ruling the
// same day: put the word in the data, keep the judgement where it was.
//
// So the knowledge stops being a hidden case in the logic while the security
// policy stays measured. If a real corpus later shows the label is precise
// enough, one row changes from `Suggest` to `Auto` — a deliberate decision
// with a test of its own, not an accident of a refactor.
const ROWS: &[(&str, &str, Kind, Validator, Confidence)] = &[
    ("de-01", "telefon", Kind::Phone, Validator::Number, Confidence::Auto),
    ("de-02", "tel", Kind::Phone, Validator::Number, Confidence::Auto),
    ("de-03", "tel.", Kind::Phone, Validator::Number, Confidence::Auto),
    ("de-04", "mobil", Kind::Phone, Validator::Number, Confidence::Auto),
    ("de-05", "handy", Kind::Phone, Validator::Number, Confidence::Auto),
    ("de-06", "fax", Kind::Phone, Validator::Number, Confidence::Auto),
    ("de-07", "e-mail", Kind::Email, Validator::Word, Confidence::Auto),
    ("de-08", "email", Kind::Email, Validator::Word, Confidence::Auto),
    ("de-09", "mail", Kind::Email, Validator::Word, Confidence::Auto),
    ("de-10", "iban", Kind::Iban, Validator::Grouped, Confidence::Auto),
    ("de-11", "bic", Kind::Bic, Validator::Grouped, Confidence::Auto),
    ("de-12", "kontonummer", Kind::Account, Validator::Number, Confidence::Auto),
    ("de-13", "konto", Kind::Account, Validator::Number, Confidence::Auto),
    ("de-14", "kundennummer", Kind::CustomerNo, Validator::Number, Confidence::Auto),
    ("de-15", "kunden-nr.", Kind::CustomerNo, Validator::Number, Confidence::Auto),
    ("de-16", "kundennr.", Kind::CustomerNo, Validator::Number, Confidence::Auto),
    ("de-17", "steuernummer", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("de-18", "steuer-nr.", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("de-19", "ust-idnr.", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("de-20", "ust-id", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("de-21", "umsatzsteuer-id", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("de-22", "ansprechpartner", Kind::Person, Validator::Name, Confidence::Suggest),
];

/// Words that sit between a label and a name and are not part of it.
/// They stay in the clear: a model still needs them to write correctly.
const HONORIFICS: &[&str] = &["herr", "herrn", "frau", "fr.", "hr.", "dr.", "dr", "prof.", "prof", "dipl.-ing.", "ing."];

pub(crate) fn set() -> RuleSet {
    RuleSet {
        id: "de",
        label: "German (DE)",
        honorifics: HONORIFICS.iter().map(|h| (*h).to_string()).collect(),
        rules: ROWS
            .iter()
            .map(|(id, label, kind, validator, decision)| LabelRule {
                id: (*id).to_string(),
                label: (*label).to_string(),
                kind: *kind,
                boundary: Boundary::AfterLabelSameField,
                decision: *decision,
                set: "de".to_string(),
                validator: *validator,
                source: Source::LanguagePack,
            })
            .collect(),
    }
}

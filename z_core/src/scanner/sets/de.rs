//! German label rules.
//!
//! Every row here was a line of Rust in `packs/de.rs` before 29 September. The
//! behaviour is the same; what changed is that Swedish can now be added beside
//! it without either file knowing about the other.

use crate::api::{Kind, Source};

use crate::scanner::rules::{Boundary, LabelRule, Validator};
use crate::scanner::Confidence;

use super::RuleSet;

/// `(id, label, kind, validator)` — the whole set, as rows.
const ROWS: &[(&str, &str, Kind, Validator)] = &[
    ("de-01", "telefon", Kind::Phone, Validator::Number),
    ("de-02", "tel", Kind::Phone, Validator::Number),
    ("de-03", "tel.", Kind::Phone, Validator::Number),
    ("de-04", "mobil", Kind::Phone, Validator::Number),
    ("de-05", "handy", Kind::Phone, Validator::Number),
    ("de-06", "fax", Kind::Phone, Validator::Number),
    ("de-07", "e-mail", Kind::Email, Validator::Word),
    ("de-08", "email", Kind::Email, Validator::Word),
    ("de-09", "mail", Kind::Email, Validator::Word),
    ("de-10", "iban", Kind::Iban, Validator::Grouped),
    ("de-11", "bic", Kind::Bic, Validator::Grouped),
    ("de-12", "kontonummer", Kind::Account, Validator::Number),
    ("de-13", "konto", Kind::Account, Validator::Number),
    ("de-14", "kundennummer", Kind::CustomerNo, Validator::Number),
    ("de-15", "kunden-nr.", Kind::CustomerNo, Validator::Number),
    ("de-16", "kundennr.", Kind::CustomerNo, Validator::Number),
    ("de-17", "steuernummer", Kind::TaxId, Validator::Word),
    ("de-18", "steuer-nr.", Kind::TaxId, Validator::Word),
    ("de-19", "ust-idnr.", Kind::TaxId, Validator::Word),
    ("de-20", "ust-id", Kind::TaxId, Validator::Word),
    ("de-21", "umsatzsteuer-id", Kind::TaxId, Validator::Word),
    ("de-22", "ansprechpartner", Kind::Person, Validator::Name),
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
            .map(|(id, label, kind, validator)| LabelRule {
                id: (*id).to_string(),
                label: (*label).to_string(),
                kind: *kind,
                boundary: Boundary::AfterLabelSameField,
                // A label is proof of what follows, so a set may act alone.
                decision: Confidence::Auto,
                set: "de".to_string(),
                validator: *validator,
                source: Source::LanguagePack,
            })
            .collect(),
    }
}

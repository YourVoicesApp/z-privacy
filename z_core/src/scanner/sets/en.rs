//! English label rules.
//!
//! The first set added **after** the engine became data — and it needed no
//! scanner change at all, which is the only evidence that the engine is really
//! open rather than a `match` moved into another file.

use crate::api::{Kind, Source};

use crate::scanner::rules::{Boundary, LabelRule, Validator};
use crate::scanner::Confidence;

use super::RuleSet;

/// `(id, label, kind, validator)` — the whole set, as rows.
const ROWS: &[(&str, &str, Kind, Validator)] = &[
    ("en-01", "telephone", Kind::Phone, Validator::Number),
    ("en-02", "phone", Kind::Phone, Validator::Number),
    ("en-03", "tel", Kind::Phone, Validator::Number),
    ("en-04", "mobile", Kind::Phone, Validator::Number),
    ("en-05", "cell", Kind::Phone, Validator::Number),
    ("en-06", "fax", Kind::Phone, Validator::Number),
    ("en-07", "e-mail", Kind::Email, Validator::Word),
    ("en-08", "email", Kind::Email, Validator::Word),
    ("en-09", "iban", Kind::Iban, Validator::Grouped),
    ("en-10", "bic", Kind::Bic, Validator::Grouped),
    ("en-11", "swift", Kind::Bic, Validator::Grouped),
    ("en-12", "account number", Kind::Account, Validator::Number),
    ("en-13", "account no.", Kind::Account, Validator::Number),
    ("en-14", "customer number", Kind::CustomerNo, Validator::Number),
    ("en-15", "customer no.", Kind::CustomerNo, Validator::Number),
    ("en-16", "client number", Kind::CustomerNo, Validator::Number),
    ("en-17", "account", Kind::Account, Validator::Number),
    ("en-18", "vat number", Kind::TaxId, Validator::Word),
    ("en-19", "vat id", Kind::TaxId, Validator::Word),
    ("en-20", "tax id", Kind::TaxId, Validator::Word),
    ("en-21", "tax number", Kind::TaxId, Validator::Word),
    ("en-22", "contact person", Kind::Person, Validator::Name),
    ("en-23", "contact", Kind::Person, Validator::Name),
    ("en-24", "attention", Kind::Person, Validator::Name),
];

/// Words that sit between a label and a name and are not part of it.
/// They stay in the clear: a model still needs them to write correctly.
const HONORIFICS: &[&str] = &["mr", "mr.", "mrs", "mrs.", "ms", "ms.", "miss", "dr", "dr.", "prof", "prof."];

pub(crate) fn set() -> RuleSet {
    RuleSet {
        id: "en",
        label: "English (EN)",
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
                set: "en".to_string(),
                validator: *validator,
                source: Source::LanguagePack,
            })
            .collect(),
    }
}

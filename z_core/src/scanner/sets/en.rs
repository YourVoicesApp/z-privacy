//! English label rules.
//!
//! The first set added **after** the engine became data — and it needed no
//! scanner change at all, which is the only evidence that the engine is really
//! open rather than a `match` moved into another file.

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
const ROWS: &[(&str, &str, Kind, Validator, Confidence)] = &[
    ("en-01", "telephone", Kind::Phone, Validator::Number, Confidence::Auto),
    ("en-02", "phone", Kind::Phone, Validator::Number, Confidence::Auto),
    ("en-03", "tel", Kind::Phone, Validator::Number, Confidence::Auto),
    ("en-04", "mobile", Kind::Phone, Validator::Number, Confidence::Auto),
    ("en-05", "cell", Kind::Phone, Validator::Number, Confidence::Auto),
    ("en-06", "fax", Kind::Phone, Validator::Number, Confidence::Auto),
    ("en-07", "e-mail", Kind::Email, Validator::Word, Confidence::Auto),
    ("en-08", "email", Kind::Email, Validator::Word, Confidence::Auto),
    ("en-09", "iban", Kind::Iban, Validator::Grouped, Confidence::Auto),
    ("en-10", "bic", Kind::Bic, Validator::Grouped, Confidence::Auto),
    ("en-11", "swift", Kind::Bic, Validator::Grouped, Confidence::Auto),
    ("en-12", "account number", Kind::Account, Validator::Number, Confidence::Auto),
    ("en-13", "account no.", Kind::Account, Validator::Number, Confidence::Auto),
    ("en-14", "customer number", Kind::CustomerNo, Validator::Number, Confidence::Auto),
    ("en-15", "customer no.", Kind::CustomerNo, Validator::Number, Confidence::Auto),
    ("en-16", "client number", Kind::CustomerNo, Validator::Number, Confidence::Auto),
    ("en-17", "account", Kind::Account, Validator::Number, Confidence::Auto),
    ("en-18", "vat number", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("en-19", "vat id", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("en-20", "tax id", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("en-21", "tax number", Kind::TaxId, Validator::Word, Confidence::Auto),
    ("en-22", "contact person", Kind::Person, Validator::Name, Confidence::Auto),
    ("en-23", "contact", Kind::Person, Validator::Name, Confidence::Auto),
    ("en-24", "attention", Kind::Person, Validator::Name, Confidence::Auto),
    // 046/J — **the labels an English payroll sheet names a person with.**
    //
    // Measured on the owner's own sheet, written in English for the film, with
    // the client's list imported: 49 findings, 49 protected, 0 questions — a
    // clean screen, and twelve values in the clear behind it. One of them was
    // the managing director's own name, which no person rule could reach
    // because `en` has no pack at all (that is B). A label does not need one.
    //
    // An office or an act, so **Auto**, by the same reasoning as the Swedish
    // rows: «Managing Director:» names who holds the post and «Approved by:»
    // names who did the thing. «Contact person» above is the one of this family
    // that stays a question, because the owner ruled that word a question in
    // German on 29 September and one language may not answer differently.
    ("en-25", "managing director", Kind::Person, Validator::Name, Confidence::Auto),
    ("en-26", "prepared by", Kind::Person, Validator::Name, Confidence::Auto),
    ("en-27", "approved by", Kind::Person, Validator::Name, Confidence::Auto),
    ("en-28", "authorised by", Kind::Person, Validator::Name, Confidence::Auto),
    ("en-29", "authorized by", Kind::Person, Validator::Name, Confidence::Auto),
    ("en-30", "case handler", Kind::Person, Validator::Name, Confidence::Auto),
    // The identity number by its name as well as by its shape. The shape rule
    // in `general_rules.rs` finds it in a table column where no label reaches;
    // a label finds it where the shape is written in a way no rule predicted.
    // Both are Auto and both agree, so one value stays one finding.
    //
    // `TaxId`, as the Swedish «personnummer» row has been since it was
    // written: in the Nordic countries this number **is** the tax registration
    // number, so a second kind for the same value would be two answers to one
    // question.
    ("en-31", "national id", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("en-32", "national id number", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("en-33", "national identity number", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("en-34", "national insurance number", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("en-35", "personal id", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("en-36", "personal identity number", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("en-37", "social security number", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("en-38", "ssn", Kind::TaxId, Validator::Number, Confidence::Auto),
    // A company's own registration number. `Kind::Company` is the name, not
    // the number, so this is `Contract` — the kind this build already uses for
    // «a reference a document is filed under», which is what a registration
    // number is to the letter that quotes it.
    ("en-39", "registration number", Kind::Contract, Validator::Number, Confidence::Auto),
    ("en-40", "company number", Kind::Contract, Validator::Number, Confidence::Auto),
    ("en-41", "company registration number", Kind::Contract, Validator::Number, Confidence::Auto),
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
            .map(|(id, label, kind, validator, decision)| LabelRule {
                id: (*id).to_string(),
                label: (*label).to_string(),
                kind: *kind,
                boundary: Boundary::AfterLabelSameField,
                decision: *decision,
                set: "en".to_string(),
                validator: *validator,
                source: Source::LanguagePack,
            })
            .collect(),
    }
}

//! Swedish label rules.
//!
//! The third set, and the second added without a line of scanner code — which
//! is what the head of this folder promises. It is small on purpose: enough
//! rows to prove the engine is open, and the pack's word lists in
//! `packs/sv.rs` do the work on names.

use crate::api::{Kind, Source};

use crate::scanner::rules::{Boundary, LabelRule, Validator};
use crate::scanner::Confidence;

use super::RuleSet;

/// `(id, label, kind, validator, decision)` — the whole set, as rows.
const ROWS: &[(&str, &str, Kind, Validator, Confidence)] = &[
    ("sv-01", "telefon", Kind::Phone, Validator::Number, Confidence::Auto),
    ("sv-02", "mobil", Kind::Phone, Validator::Number, Confidence::Auto),
    ("sv-03", "e-post", Kind::Email, Validator::Any, Confidence::Auto),
    ("sv-04", "epost", Kind::Email, Validator::Any, Confidence::Auto),
    // A Swedish personal number is a national identifier with a check digit.
    // The row says what it is; the arithmetic, if we ever add it, is a
    // `Validator` in Rust and never a row — the rule this folder opens with.
    ("sv-05", "personnummer", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("sv-06", "organisationsnummer", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("sv-07", "org.nr", Kind::TaxId, Validator::Number, Confidence::Auto),
    ("sv-08", "kundnummer", Kind::CustomerNo, Validator::Number, Confidence::Auto),
    ("sv-09", "fakturanummer", Kind::Contract, Validator::Number, Confidence::Auto),
    // «Adress» names a place, and a place is a question rather than a fact:
    // the same decision German made for its own address label.
    ("sv-10", "adress", Kind::Address, Validator::Any, Confidence::Suggest),
    // `Name` and not `Any` since 046/J: `Any` takes the **first word only**,
    // so «Kontaktperson: Anna Nilsson» offered «Anna» and left the surname in
    // the clear. Half a name offered is the shape of defect 038-I was about.
    //
    // And it stays a **question**, which is the one row of 046/J's list that
    // does: the owner ruled on 29 September that «Ansprechpartner» — the same
    // word in German — names a person the way a salutation does and is still
    // a question. One language may not quietly answer differently from
    // another about the same concept. If that ruling changes it changes for
    // both rows at once.
    ("sv-11", "kontaktperson", Kind::Person, Validator::Name, Confidence::Suggest),
    // 038-B/2, from the owner's own Swedish supplement: a magazine credits the
    // photographer beside the picture, and the three labels it uses are these.
    // A credit is **proof** — nobody writes «Foto:» before anything but a
    // person — so these protect without asking, and they are the first rows in
    // this folder to do that for a name.
    //
    // `NamePair` and not `Name`, measured on the same page: «Bild: Stockholm»
    // is a caption, and one capitalised word after these labels is not a
    // credit. The price of Auto is a given name **and** a surname.
    ("sv-12", "foto", Kind::Person, Validator::NamePair, Confidence::Auto),
    ("sv-13", "fotograf", Kind::Person, Validator::NamePair, Confidence::Auto),
    ("sv-14", "bild", Kind::Person, Validator::NamePair, Confidence::Auto),
    // 046/J — **a label that names a person is the only thing that finds a
    // name no dictionary of ours will ever hold.**
    //
    // Measured on the owner's own payroll sheet, the page a camera points at,
    // with only the name in the director's slot changed:
    //
    // ```text
    //     «Sven Hallgren»      the pair rule fires, and the name is offered
    //     «Anas Alhaddad»      not a finding at all
    //     «Mohammed Barakat»   not a finding at all
    // ```
    //
    // «Sven» is one of the 150 Swedish given names this build carries, so the
    // pair rule had a known half to work from. An Arabic given name is in no
    // list we carry, and there was no row for «Verkställande direktör:» — so
    // the name left the device with no card, no question and no mark. The
    // owner is Arabic-speaking and his own name sits in that slot.
    //
    // A silent leak is the worst class of defect this project has, and the
    // answer cannot be a longer dictionary: it has to be a rule that does not
    // care where a name comes from. That is what a label is.
    //
    // **Auto, and the reason it is allowed to be:** these labels are an
    // office or an act, not a slot. «Verkställande direktör:» names the
    // person who holds the office and «Sammanställd av:» names the one who
    // did the work — the same strength a salutation has, which has protected
    // without asking since 3 October. `Validator::Name`, so the whole name is
    // taken and not its first word.
    ("sv-15", "verkställande direktör", Kind::Person, Validator::Name, Confidence::Auto),
    ("sv-16", "vd", Kind::Person, Validator::Name, Confidence::Auto),
    ("sv-17", "sammanställd av", Kind::Person, Validator::Name, Confidence::Auto),
    ("sv-18", "attesterad av", Kind::Person, Validator::Name, Confidence::Auto),
    ("sv-19", "godkänd av", Kind::Person, Validator::Name, Confidence::Auto),
    ("sv-20", "handläggare", Kind::Person, Validator::Name, Confidence::Auto),
];

/// What Swedish puts between a label and a name.
const HONORIFICS: &[&str] = &["herr", "fru", "fröken", "dr", "dr.", "prof", "prof."];

pub(crate) fn set() -> RuleSet {
    RuleSet {
        id: "sv",
        label: "Svenska (SV)",
        honorifics: HONORIFICS.iter().map(|h| (*h).to_string()).collect(),
        rules: ROWS
            .iter()
            .map(|(id, label, kind, validator, decision)| LabelRule {
                id: (*id).to_string(),
                label: (*label).to_string(),
                kind: *kind,
                boundary: Boundary::AfterLabelSameField,
                decision: *decision,
                set: "sv".to_string(),
                validator: *validator,
                source: Source::LanguagePack,
            })
            .collect(),
    }
}

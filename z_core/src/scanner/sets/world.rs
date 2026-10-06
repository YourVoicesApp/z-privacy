//! The rows that are the same in every language.
//!
//! 041-Q, from the owner: «the language list holds every language; we have no
//! problem with the language rules, we will not include them all». A language
//! with no pack of its own still runs the general rules — and three of the
//! labels a letter writes beside a bank value are not words of any language.
//! `BIC`, `SWIFT` and `IBAN` are ISO abbreviations, written the same in an
//! Arabic letter and a Danish one.
//!
//! Measured, 6 October, on AR-1 (the invented Arabic letter): under the German
//! pack the scan found 5 auto · 2 waiting; under a bare «ar» it found 4 · 2,
//! and the missing one was a **BIC** — caught only because the German set
//! happens to carry the row `de-11 bic`. A Swedish or Arabic reader lost it for
//! no reason anybody could defend. With these rows always on, «ar» finds 5 · 2
//! like German, and German is unchanged because overlapping candidates settle
//! into one finding.
//!
//! What may **not** come here: a word that belongs to a language. «Konto» is
//! German, «konto» is Swedish, and «account» is English — each stays in its
//! own file. The test for whether a row belongs here is whether a person
//! writing in Japanese would write it in Latin letters exactly like this.

use crate::api::{Kind, Source};
use crate::scanner::rules::{Boundary, LabelRule, Validator};
use crate::scanner::Confidence;

use super::RuleSet;

/// `id · label · kind · validator · decision`.
const ROWS: &[(&str, &str, Kind, Validator, Confidence)] = &[
    ("zz-01", "bic", Kind::Bic, Validator::Grouped, Confidence::Auto),
    ("zz-02", "swift", Kind::Bic, Validator::Grouped, Confidence::Auto),
    ("zz-03", "iban", Kind::Iban, Validator::Grouped, Confidence::Auto),
];

/// Not a language: the rows every scan runs, whatever language is chosen.
pub(crate) fn set() -> RuleSet {
    RuleSet {
        id: "zz",
        label: "Every language",
        honorifics: Vec::new(),
        rules: ROWS
            .iter()
            .map(|(id, label, kind, validator, decision)| LabelRule {
                id: (*id).to_string(),
                label: (*label).to_string(),
                kind: *kind,
                boundary: Boundary::AfterLabelSameField,
                decision: *decision,
                set: "zz".to_string(),
                validator: *validator,
                // A general rule, because it belongs to no language — and the
                // band's layer counts say so without a special case.
                source: Source::GeneralRule,
            })
            .collect(),
    }
}

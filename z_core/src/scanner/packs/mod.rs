//! Privacy packs: the habits of one language.
//!
//! A pack knows **forms** — that a word after «Frau» is usually a person, that a
//! run ending in «GmbH» is a company, that whatever follows «Kundennummer:» is a
//! customer number. It never contains a real person: that is the vault's job, and
//! the difference is why switching packs can leak nothing.
//!
//! A pack is not the language of the interface, and the screen says so in its
//! first line.

pub(crate) mod de;
pub(crate) mod de_names;

use super::Candidate;

/// Run the pack named by `id`. An unknown id simply contributes nothing — a
/// missing pack must never be an error that stops a document from being scanned.
pub(crate) fn scan(text: &str, id: &str) -> Vec<Candidate> {
    match id {
        "de" => de::scan(text),
        _ => Vec::new(),
    }
}

/// The packs this build carries. The label belongs to the pack, not to a screen:
/// a rules engine names itself, and the UI only draws what it is told (task 022).
pub(crate) fn installed() -> Vec<crate::api::PackRow> {
    // Read from the rule sets, never listed again here. Two lists of the same
    // fact drift, and this one already did: `en` shipped as a rule set on 29
    // September while this function still said German was the only pack, so
    // First Run offered a language it could not actually select.
    crate::scanner::sets::all()
        .into_iter()
        .map(|s| crate::api::PackRow {
            id: s.id.to_string(),
            label: s.label.to_string(),
        })
        .collect()
}

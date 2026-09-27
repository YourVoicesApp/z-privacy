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

use super::Candidate;

/// Run the pack named by `id`. An unknown id simply contributes nothing — a
/// missing pack must never be an error that stops a document from being scanned.
pub(crate) fn scan(text: &str, id: &str) -> Vec<Candidate> {
    match id {
        "de" => de::scan(text),
        _ => Vec::new(),
    }
}

/// The packs that exist today, in the order the UI lists them.
pub(crate) fn installed() -> Vec<String> {
    vec!["de".to_string()]
}

//! The name lists a pack ships with — and not one verdict among them.
//!
//! The owner's rule, in his own order: «Herr Thomas Müller» is very high
//! confidence, «Thomas Müller» is high, «Thomas» alone is a dictionary match
//! and no certainty, «Müller» alone is a possible surname and not always
//! enough. So the list is a **signal**: it can make the scanner offer a name it
//! would otherwise have walked past, and it can never make it protect one by
//! itself. A dictionary hit is not a person confirmed.
//!
//! Where the names come from, what each licence requires, and what was taken
//! from each source: `z_core/assets/licenses/german_names_sources.md`. The file
//! itself is built by `scripts/build_de_names.py`, so the owner's own CSV can
//! replace it with no work by hand.
//!
//! Compiled in. There is no file to read at run time and no network to reach —
//! a scan on an aeroplane finds exactly what a scan in an office finds.

use std::collections::{BTreeMap, BTreeSet};
use std::sync::OnceLock;

/// The bank as shipped: tiers 1 and 2, 12,732 names, built by
/// `scripts/build_de_names.py` from four cities' newborn registers and
/// Wikidata. Tier 3 — a name one single city ever used — is written beside it
/// and compiled into nothing: 60,548 rows nobody reads would be 14 MB of
/// download in every copy of the product.
pub(crate) const CSV: &str = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/assets/de_names_v2.csv"));

/// Which tiers this build actually believes.
///
/// A tier is a measurement, not a guess: each one was run against every German
/// golden and the Swedish control before it was put here, and the numbers are
/// in `docs/THE_NUMBERS.md`. A tier that cost a false protection anywhere does
/// not go in this list, whatever it would have gained.
pub(crate) const LOADED_TIERS: &[u8] = &[1];

/// Names folded to lowercase, because a name is matched by its letters and not
/// by its case — and the shape of the word is judged elsewhere, by the rules
/// that already know what a name looks like.
pub(crate) struct Dictionary {
    given: BTreeSet<String>,
    family: BTreeSet<String>,
}

impl Dictionary {
    pub(crate) fn given(&self, word: &str) -> bool {
        self.given.contains(&word.to_lowercase())
    }

    pub(crate) fn family(&self, word: &str) -> bool {
        self.family.contains(&word.to_lowercase())
    }

    /// How many of each were loaded. A pack's row carries it now, so the list
    /// of installed languages can say what each one knows.
    pub(crate) fn counts(&self) -> (usize, usize) {
        (self.given.len(), self.family.len())
    }
}

/// Read once per pack, for the life of the process.
///
/// Keyed by the pack's locale, because every pack has its own lists and a
/// dictionary that belonged to one language was the thing Phase 3 set out to
/// remove. German's own is still reachable by its locale, and so is Swedish's,
/// with no code between them.
pub(crate) fn dictionary_of(locale: &'static str, csv: &'static str) -> &'static Dictionary {
    static LOADED: OnceLock<std::sync::Mutex<BTreeMap<&'static str, &'static Dictionary>>> =
        OnceLock::new();
    let cache = LOADED.get_or_init(|| std::sync::Mutex::new(BTreeMap::new()));
    // A pack's lists are read once and then live as long as the process: the
    // leak is deliberate and bounded by the number of packs this build carries.
    let mut held = match cache.lock() {
        Ok(held) => held,
        // A poisoned lock here would mean a panic while parsing a shipped CSV.
        // Reading it again is the honest answer, and it cannot poison twice.
        Err(poisoned) => poisoned.into_inner(),
    };
    if let Some(found) = held.get(locale) {
        return found;
    }
    let made: &'static Dictionary = Box::leak(Box::new(parse(csv)));
    held.insert(locale, made);
    made
}

/// German's lists, by name, for the tests that measure them.
#[cfg(test)]
pub(crate) fn dictionary() -> &'static Dictionary {
    dictionary_of("de-DE", CSV)
}

/// Three fields this code needs, and none of them can hold a comma: the name
/// and the type are the first two, and the tier is the last. Everything
/// between them may be quoted prose and is left alone — a full CSV reader
/// would be a dependency for nothing.
fn parse(text: &str) -> Dictionary {
    let mut given = BTreeSet::new();
    let mut family = BTreeSet::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with("name,") {
            continue;
        }
        // The tier is the last field, and a row whose tier this build does not
        // believe is read past: the file is the whole bank, the dictionary is
        // what has been measured.
        //
        // A file with **no** tier column is a file from before tiers — the
        // Swedish pack's is one — and all of it loads. Reading its last field
        // as a tier and finding prose there once emptied the Swedish
        // dictionary without a word: SV-1 lost two of its four people, and the
        // German task that caused it had never touched Swedish. The control
        // caught it, which is what a control is for.
        if let Some(tier) = line.rsplit(',').next().and_then(|t| t.trim().parse::<u8>().ok()) {
            if !LOADED_TIERS.contains(&tier) {
                continue;
            }
        }
        let mut fields = line.splitn(3, ',');
        let (Some(name), Some(kind)) = (fields.next(), fields.next()) else { continue };
        let name = name.trim().to_lowercase();
        if name.is_empty() {
            continue;
        }
        match kind.trim() {
            "given" => given.insert(name),
            "family" => family.insert(name),
            _ => false,
        };
    }
    Dictionary { given, family }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_dictionary_loads_the_names_it_ships_with() {
        let (given, family) = dictionary().counts();
        // 038-H. Given names are tiered by how many of four city registers
        // carry them, and only tier 1 — three cities or four — is loaded.
        // Tier 2 was measured on every golden and did not earn its place: it
        // found no person any golden was missing, and it turned «Vorfinanzierung,
        // da …» into a name to look at, because two cities once gave a child
        // the name «Da».
        assert_eq!(given, 5712, "the given names in three cities or four");
        // Family names: Wikidata's German citizens with at least ten bearers,
        // plus the one of V1's CC0 ten that Wikidata does not have — no
        // family-name item labelled «Schmidt» in German has German-citizen
        // holders there, and it is the second commonest surname in the country.
        assert_eq!(family, 3246, "the family names of tier 1");
    }

    #[test]
    fn german_letters_survive_the_way_in() {
        // Two rows of the file carry a character outside ASCII, and both are the
        // point: a dictionary that loses «Müller» is a dictionary about English.
        assert!(dictionary().family("Müller"), "the commonest surname in Germany");
        assert!(dictionary().given("Ömer"), "a name used in Germany, and not Germanic");
        assert!(!dictionary().given("müller"), "a surname is not a given name");
        // Case is not part of a name's identity here.
        assert!(dictionary().given("THOMAS") && dictionary().given("thomas"));
    }
}

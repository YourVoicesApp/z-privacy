//! Swedish, as proof that the second language is data.
//!
//! Nothing in this file is a rule. It is a locale, four word lists, a name
//! list and a line of provenance — and the rules that read it are the same
//! rules that read German, in `de.rs`'s shared half. `extra` is **empty**: the
//! three things German needs that nothing else can use (a national plate
//! format, a local number written after the German word for telephone, a
//! German street line) have no Swedish counterpart here, and inventing one
//! would be inventing a rule nobody measured.
//!
//! What it is **not**: a Swedish dictionary. 150 given names and 150 surnames
//! are enough to prove that a pack can be added without touching the core, and
//! the owner's rule stands — the little that is precise beats the much that is
//! noisy. The lists come from the same CC0 source as the German surnames, with
//! the same query and `Q34` in place of `Q183`.

use super::pack::{LanguagePack, NameOrder};

/// The names, as the build ships them.
pub(crate) const CSV: &str =
    include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/assets/sv_names_v1.csv"));

/// «Herr Andersson», «Fru Lindgren» — and the modern Swedish letter uses
/// «Hej» and a first name, which is why the salutation list is short and the
/// signature and the given-and-surname pair do most of the work.
const SALUTATIONS: &[&str] = &["Herr", "Fru", "Fröken", "Hr", "Fr"];

/// Swedish titles, as they stand before a name.
const TITLES: &[&str] = &["Dr.", "Dr", "Prof.", "Prof", "Docent", "Civ.ing.", "Ing.", "Adv.", "Leg."];

/// Nothing in Swedish plays the part the Latin fragments play in German
/// («Dr. med. univ.»), so this is empty rather than copied.
const TITLE_PARTS: &[&str] = &[];

/// Degrees that follow a name.
const DEGREES: &[&str] = &["MBA", "MSc", "BSc", "PhD", "civ.ek."];

/// Swedish words that are also given names and may not open one: «Och» (and),
/// «Som» (as), «Men» (but), «Bara» (only) — the same trap German has with
/// «An» and «Nur», found the same way.
const FUNCTION_WORDS: &[&str] = &["och", "som", "men", "bara", "att", "för"];

/// Capitalised words that begin a sentence and belong to no name.
const STOP_WORDS: &[&str] = &[
    "Den", "Det", "De", "Denna", "Detta", "Dessa", "En", "Ett", "Vi", "Vår", "Våra", "Jag",
    "Hej", "Med", "Till", "Från", "Enligt", "Samt", "Och", "Men", "Som",
];

/// What a Swedish letter says before the signature.
const CLOSINGS: &[&str] = &["hälsningar", "vänligen", "hälsning", "mvh"];

/// The legal forms a Swedish company name ends with.
const COMPANY_FORMS: &[&str] = &["AB", "HB", "KB", "AB.", "Ekonomisk", "Handelsbolag", "Kommanditbolag"];

/// «Lindgren & Söner», «Andersson och Partner».
const CONJUNCTIONS: &[&str] = &["&", "och"];

/// What a Swedish signature writes under the name.
const ROLES: &[&str] = &["vd", "ägare", "chef", "ordförande", "styrelseledamot", "konsult"];

pub(crate) fn pack() -> LanguagePack {
    LanguagePack {
        locale: "sv-SE",
        id: "sv",
        label: "Svenska",
        version: "1",
        salutations: SALUTATIONS,
        titles: TITLES,
        title_parts: TITLE_PARTS,
        degrees: DEGREES,
        function_words: FUNCTION_WORDS,
        stop_words: STOP_WORDS,
        closings: CLOSINGS,
        roles: ROLES,
        company_forms: COMPANY_FORMS,
        conjunctions: CONJUNCTIONS,
        order: NameOrder::GivenThenFamily,
        names: CSV,
        provenance: "Wikidata (CC0) — given and family names of people recorded as Swedish citizens; see z_core/assets/licenses/swedish_names_sources.md",
        extra: &[],
    }
}

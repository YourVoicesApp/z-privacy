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

/// What makes a Swedish word a surname: how it ends.
///
/// The owner's sentence, 6 October: «every word ending in son is a surname in
/// Sweden; in Denmark perhaps sen». A patronymic is not a dictionary entry —
/// it is a pattern, and Sweden has a few million of them. So the ending is a
/// signal of exactly the strength a dictionary hit has: it can make the scanner
/// **offer** a name it would have walked past, and it can never protect one by
/// itself.
///
/// Each one below earned its place on SV-1 and on five pages of a Swedish
/// research magazine; the ones that earned nothing, or that brought ordinary
/// words with them, are not here and the task's report says which and why.
///
/// `-dotter` is the old feminine patronymic — Andersdotter — and the owner
/// added it. Iceland's `-dóttir` and `-sson` belong to an Icelandic pack if one
/// is ever built; they are not Swedish and are not here.
///
/// Danish `-sen` is deliberately absent: this is the Swedish pack, and
/// «Hilsen» — what a Danish letter closes with — ends in it.
/// Measured on SV-1 and on five pages of a Swedish research magazine, and what
/// is here is what earned its place:
///
/// ```text
///     son      Pettersson · Reinholdsson · Ericsson · Holgersson · Johansson
///              · Karlsson · Larsson · Ragnarsson        — the owner's own case
///     ström    Bergström · Rådström
///     qvist    Lindqvist
///     berg     Ekeberg · Wallenberg
///     lund     Eklund · Marklund
///     gren     Holmgren
///     stedt    Wallerstedt
///     dotter   nothing in either document — the owner's addition, and a
///              patronymic no Swedish common noun can collide with
/// ```
///
/// And what was deleted, each with the measurement that deleted it:
///
/// ```text
///     ling     «AI-utveckling», «Bröstcancerbehandling» — `-ling` builds
///              ordinary Swedish nouns, and five pages gave two of them against
///              one surname. The one surname it would have found, «Hjerling»,
///              is still a name to look at.
///     holm     «Stockholm». A city, and not one surname in either document.
///     sson     every word ending in «sson» ends in «son»; this was the same
///              rule written twice.
///     strom · kvist · blom · dahl   real endings that caught nothing here.
///              They come back the day a document earns them, with the
///              measurement that earns them.
/// ```
const FAMILY_SUFFIXES: &[&str] = &["son", "dotter", "ström", "qvist", "berg", "lund", "gren", "stedt"];

/// What a Swedish signature writes under the name.
/// What a Swedish text calls a person's part in something.
///
/// Read two ways: under a name on its own line, which is a signature, and
/// beside a name in a sentence, which is 038-B/2. The six added on 7 October
/// are the owner's, from his supplement — «Projektledare är Cicek Cavdar» was
/// in the clear until the second reading existed.
const ROLES: &[&str] = &[
    "vd",
    "ägare",
    "chef",
    "ordförande",
    "styrelseledamot",
    "konsult",
    "projektledare",
    "professor",
    "forskningssekreterare",
    "programchef",
    "direktör",
    // 046/J, from the owner's own payroll sheet: «Sammanställd av: Amina
    // Saleh, Löneassistent». The label above carries that line now, and this
    // is the role beside the name on the same page — the «X, <role>» shape
    // 038-B/2 reads. Added because a document we hold writes it, which is the
    // only reason any word in this file is here.
    "löneassistent",
];

/// "«<role> är X»" — what stands between the role and the name.
///
/// Data, because it is a word of the language and not a rule of the world. The
/// German pack's list is empty until the same shape is measured on a German
/// page.
const COPULAS: &[&str] = &["är"];

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
        copulas: COPULAS,
        company_forms: COMPANY_FORMS,
        conjunctions: CONJUNCTIONS,
        family_suffixes: FAMILY_SUFFIXES,
        order: NameOrder::GivenThenFamily,
        names: CSV,
        provenance: "Wikidata (CC0) — given and family names of people recorded as Swedish citizens; see z_core/assets/licenses/swedish_names_sources.md",
        extra: &[],
    }
}

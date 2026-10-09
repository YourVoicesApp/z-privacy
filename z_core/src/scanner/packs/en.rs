//! English, as the third language and the second proof that a pack is data.
//!
//! The owner's sentence, 9 October: «قواعد اللغة السويدية تشابه الإنكليزية، حتى
//! الأسماء التي تنتهي بـ ‎-son» — Swedish's habits resemble English's, down to
//! the surnames ending in `-son`. This file is what that sentence looks like as
//! data: a locale, four word lists, a name list and a line of provenance. Not
//! one rule, and not one line of code outside this file.
//!
//! **What was already here, and what was missing.** `scanner/sets/en.rs` has
//! carried the English *labels* since 29 September — a National Insurance
//! number, a VAT number, a sort code. What English had no part of was
//! **discovery**: the half that finds a person no list knows. A document could
//! be read with the English labels and the person in it was nobody. That is the
//! hole this closes, and it is why the pack row for `en` used to report an
//! empty locale and zero names.
//!
//! What it is **not**: an English dictionary. 149 given names and 150 surnames
//! are the same proof the Swedish list is, from the same CC0 source with one
//! country code changed, and the owner's rule stands — the little that is
//! precise beats the much that is noisy. `extra` is **empty**: the three rules
//! German needs that nothing else can use have no English counterpart, and
//! inventing one would be inventing a rule nobody measured.

use super::pack::{LanguagePack, NameOrder};

/// The names, as the build ships them.
pub(crate) const CSV: &str =
    include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/assets/en_names_v1.csv"));

/// «Dear Ms Whitfield», «As discussed with Mr Hale».
///
/// The honorific and not the greeting: «Dear» opens an English letter and says
/// nothing about what follows it being a person — «Dear Sir», «Dear all»,
/// «Dear Harrow Lane». What carries a name is `Mr`/`Mrs`/`Ms`, and on the
/// film's own letter those two lines are the only reason two of its people are
/// found at all.
const SALUTATIONS: &[&str] = &["Mr", "Mrs", "Ms", "Miss", "Mx", "Mr.", "Mrs.", "Ms.", "Dame"];

/// English titles, as they stand before a name.
const TITLES: &[&str] = &["Dr", "Dr.", "Prof", "Prof.", "Rev", "Rev.", "Hon", "Hon.", "Sir", "Lord", "Lady"];

/// Nothing in English plays the part the Latin fragments play in German
/// («Dr. med. univ.»), so this is empty rather than copied.
const TITLE_PARTS: &[&str] = &[];

/// Letters that follow an English name. The accountancy ones are here because
/// the documents this pack was measured on are an accountant's: a letterhead
/// reading «Chartered Accountants» writes `FCA` and `ACA` after a partner.
const DEGREES: &[&str] = &[
    "MBA", "MSc", "BSc", "BA", "MA", "PhD", "LLB", "LLM", "FCA", "ACA", "ACCA", "FCCA", "CIMA",
    "MBE", "OBE", "CBE",
];

/// English words that may not open a name.
const FUNCTION_WORDS: &[&str] = &[
    "and", "or", "but", "the", "a", "an", "of", "for", "with", "from", "to", "as", "that", "this",
    "our", "your", "his", "her", "their", "is", "are", "was", "were", "please", "thank",
];

/// Capitalised words that begin a sentence, or label a line, and belong to no
/// name.
///
/// **The last row is the price of `-son`.** English builds ordinary nouns with
/// the same ending that builds its surnames — and one of them, «Person», is the
/// first word of the line the film's letter uses to introduce its contact
/// («Contact person:»). Swedish has no such collision, which is why its pack
/// needs no list like this and why the ending is cheap there and is not here.
/// Every word below is a common noun that ends in `-son` and is nobody:
/// measured against the pack's own 150 surnames, not one of them is a name in
/// that list.
const STOP_WORDS: &[&str] = &[
    "The", "This", "That", "These", "Those", "We", "Our", "I", "My", "You", "Your",
    "Dear", "If", "As", "And", "But", "First", "Second", "Third",
    "Payment", "Invoice", "Account", "Client", "Contact", "Email", "Telephone", "Mobile", "Date",
    // The `-son` nouns.
    "Person", "Reason", "Season", "Lesson", "Comparison", "Poison", "Prison", "Treason",
    "Garrison", "Unison", "Arson", "Venison", "Crimson",
];

/// What an English letter says before the signature. The last word of the
/// phrase, because that is the word standing above the name: «Yours
/// sincerely,» then a line, then «Rowan Pellbrook».
const CLOSINGS: &[&str] = &["sincerely", "faithfully", "regards", "truly", "yours"];

/// The legal forms an English company name ends with.
const COMPANY_FORMS: &[&str] = &[
    "Ltd", "Ltd.", "Limited", "LLP", "LLC", "Inc", "Inc.", "Incorporated", "plc", "PLC", "Plc",
    "Corp", "Corp.", "Corporation",
];

/// «Pellbrook & Vance», «Harrow Lane and Partners».
const CONJUNCTIONS: &[&str] = &["&", "and"];

/// What makes an English word a surname: how it ends.
///
/// **The owner's own sentence, and now measured rather than believed.** Of the
/// 150 British family names in this pack's CC0 list, **25 end in `-son`** —
/// Wilson, Johnson, Robinson, Thompson, Anderson, Jackson and nineteen more.
/// One surname in six. That is a signal of exactly the strength a dictionary
/// hit has: it can make the scanner **offer** a name it would have walked
/// past, and it can never protect one by itself.
///
/// And what was rejected, each with the measurement that rejected it, counted
/// over those same 150 names:
///
/// ```text
///     s        31 of 150 — Jones · Williams · Davies · Evans · Roberts.
///              The commonest ending there is, and the most ambiguous there
///              is: English makes a plural of almost every noun with it, so
///              the rule would offer every capitalised plural in a document
///              as somebody's surname. The most frequent ending is not the
///              most useful one.
///     ton      3 of 150 — Hamilton · Johnston · Burton. Real, and it brings
///              ordinary words with it (Button, Cotton, Carton). Three is not
///              enough to pay for that; it comes back the day a document earns
///              it, with the measurement that earns it.
///     ham · ley · wood · man · ing · don · well   1 of 150 each. One is not
///              a pattern.
///     field · brook · worth · by   0 of 150, though every one of them really
///              is an English surname ending. The list is 150 names and not
///              the language; an ending that catches nothing in it has not
///              earned a place in the build.
/// ```
///
/// The ending's cost in English is written above `STOP_WORDS`: «Person» and
/// «Reason» end in `-son` too, and they are set aside by name.
const FAMILY_SUFFIXES: &[&str] = &["son"];

/// What an English text calls a person's part in something.
///
/// Read two ways, as the Swedish list is: under a name on its own line, which
/// is a signature — «Rowan Pellbrook / Partner, Pellbrook & Vance» — and beside
/// a name in a sentence. Each one is a word the film's three documents write,
/// which is the only reason any word in this file is here.
const ROLES: &[&str] = &[
    "director",
    "partner",
    "manager",
    "officer",
    "accountant",
    "bookkeeper",
    "supervisor",
    "controller",
    "treasurer",
    "secretary",
    "chairman",
    "chair",
    "owner",
    "consultant",
    "administrator",
    "solicitor",
    "auditor",
];

/// "«<role> is X»" — what stands between the role and the name.
///
/// Data, because it is a word of the language and not a rule of the world. The
/// Swedish list holds «är» and the German one is empty until the same shape is
/// measured on a German page.
const COPULAS: &[&str] = &["is"];

pub(crate) fn pack() -> LanguagePack {
    LanguagePack {
        locale: "en-GB",
        id: "en",
        label: "English",
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
        provenance: "Wikidata (CC0) — given and family names of people recorded as British citizens; see z_core/assets/licenses/english_names_sources.md",
        extra: &[],
    }
}

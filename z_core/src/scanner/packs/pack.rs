//! What a language pack is, as a contract rather than as a folder.
//!
//! The label side of this scanner became data a long time ago: a rule set is
//! rows in a file, and `sets/mod.rs` says so in its first line — «adding a
//! language is adding a file here, **no scanner code changes**», with a test
//! that builds a set this build never heard of and proves it detects.
//!
//! The **people** side was not. How a name is introduced — a salutation, a
//! title, a signature, a surname before a comma — lived as constants and
//! functions inside `packs/de.rs`, so German was not the first implementation
//! of anything; it was the implementation. This file is the contract those
//! constants fill, and the reason a second language is data and a third is a
//! decision about data.
//!
//! **What is deliberately not here**: an e-mail address, a telephone number, an
//! IBAN, a BIC. Those are shapes, not language, and they stay in
//! `general_rules.rs` where every pack gets them for nothing. A detector moves
//! into a pack only for a real linguistic reason — a German local number
//! written after the German word for telephone is one, and it is named as such
//! in the pack that owns it.

use crate::scanner::Candidate;

/// One whitespace-separated token, with its byte range.
pub(crate) struct Word<'a> {
    pub start: usize,
    pub end: usize,
    pub text: &'a str,
    /// True when a line break sits between this word and the one before it.
    ///
    /// Two of the pack's rules need this: a name does not run past the end of a
    /// line, and neither does a labelled value. Without it, «Ansprechpartner:
    /// Herr Thomas Müller\nTelefon:» reads as a three-word name.
    pub newline_before: bool,
    /// True when a **page** ended between this word and the one before it.
    ///
    /// A different fact from a line break, and 038-I is why it had to become
    /// one: a name wrapped at the end of a line is still one name, and a rule
    /// may read across it — but the bottom of a page and the top of the next
    /// are separated by whatever the page carries in between, so a word there
    /// is not the neighbour it looks like.
    pub page_break_before: bool,
}

/// Is this word a label — «Telefon:», «BIC:» — rather than a value?
///
/// A label ends a value: `IBAN: DE89 … 00` must stop before `BIC:`, or one
/// finding swallows the next.
pub(crate) fn is_label(word: &str) -> bool {
    word.ends_with(':')
}

pub(crate) fn words(text: &str) -> Vec<Word<'_>> {
    let mut out = Vec::new();
    let mut index = 0usize;
    for token in text.split_whitespace() {
        if let Some(offset) = text.get(index..).and_then(|rest| rest.find(token)) {
            let start = index + offset;
            let end = start + token.len();
            let gap = text.get(index..start).unwrap_or_default();
            out.push(Word {
                start,
                end,
                text: token,
                newline_before: gap.contains('\n'),
                page_break_before: gap.contains('\u{c}'),
            });
            index = end;
        }
    }
    out
}

/// The word without the punctuation a sentence puts around it.
pub(crate) fn bare(word: &str) -> &str {
    word.trim_matches(|c: char| matches!(c, ',' | ';' | ':' | '.' | '!' | '?' | '"' | '(' | ')' | '»' | '«'))
}

/// Same, but keeping a trailing dot, which belongs to «Dr.» and «e.K.».
pub(crate) fn bare_keep_dot(word: &str) -> &str {
    word.trim_matches(|c: char| matches!(c, ',' | ';' | ':' | '!' | '?' | '"' | '(' | ')' | '»' | '«'))
}

pub(crate) fn starts_upper(word: &str) -> bool {
    bare(word).chars().next().is_some_and(char::is_uppercase)
}

pub(crate) fn is_numberish(word: &str) -> bool {
    let w = bare(word);
    !w.is_empty()
        && w.chars().any(|c| c.is_ascii_digit())
        && w.chars().all(|c| c.is_ascii_digit() || matches!(c, '+' | '-' | '/' | '(' | ')' | '.' | ' '))
}

/// The end of `word`'s range with sentence punctuation trimmed off.
pub(crate) fn trimmed_end(word: &Word<'_>) -> usize {
    let cut = word.text.len() - word.text.trim_end_matches([',', ';', ':', '.', '!', '?', '"', ')', '»']).len();
    word.end.saturating_sub(cut)
}

/// A rule one language needs, and its name.
///
/// The name is not decoration: `packs()` reports it, so «what German still
/// needs that Swedish does not» is a list a person can read rather than a
/// thing to be found by grepping.
pub(crate) type PackRule = (&'static str, fn(&[Word<'_>], &mut Vec<Candidate>));

/// Which half of a name comes first, where a pack needs to say.
///
/// Declared now because the contract is the thing being judged, and a contract
/// that cannot express «Kim Min-jun» is a German contract with other words in
/// it. Nothing reads it yet: both packs this build carries write the given name
/// first, and a rule that branched on it would be a rule nothing tests.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(dead_code, reason = "declared so the contract can express it; both packs this build carries write the given name first, and a rule that branched on it would be a rule nothing tests")]
pub(crate) enum NameOrder {
    GivenThenFamily,
    FamilyThenGiven,
}

/// One language's worth of knowledge about how people are named.
///
/// Every field is a list of words or a convention — nothing here is code. The
/// rules that read it live in `people.rs` and are the same rules for every
/// pack; what a pack adds beyond them, it declares in `extra`, and that list is
/// the honest measure of how language-specific a pack still is.
pub(crate) struct LanguagePack {
    /// `de-DE`, `sv-SE`. The id a profile stores is the short form (`de`), and
    /// this is the full one, for a report and for a future list of installable
    /// packs.
    pub locale: &'static str,
    /// The short id this pack answers to.
    pub id: &'static str,
    /// What the pack calls itself, in its own language.
    ///
    /// The list the UI draws comes from the rule sets, which carry the label a
    /// person chose to see — «Deutsch (DE)». This one is the pack's own name,
    /// kept for the day a pack ships without a rule set beside it.
    #[allow(dead_code, reason = "a pack names itself; the UI reads the rule set's label today")]
    pub label: &'static str,
    /// The pack's own version, so a vault or a report can say which knowledge
    /// produced a finding.
    pub version: &'static str,

    /// Words that introduce a person: «Herr», «Frau», «Fru».
    pub salutations: &'static [&'static str],
    /// Titles that stand before a name and are not part of it.
    pub titles: &'static [&'static str],
    /// Parts of a Latin title that never stand alone: «med.», «rer.».
    pub title_parts: &'static [&'static str],
    /// Degrees that follow a name and are not part of it.
    pub degrees: &'static [&'static str],
    /// Words of the language that are also given names, and may not open one:
    /// German «An» and «Nur» are a preposition and an adverb.
    pub function_words: &'static [&'static str],
    /// Capitalised words that start a sentence and belong to no name.
    pub stop_words: &'static [&'static str],
    /// What a letter says before the signature: «Mit freundlichen Grüßen».
    pub closings: &'static [&'static str],
    /// What a person writes under their name: «Geschäftsführer», «VD». A role
    /// is not part of the name, and a signature rule that did not know them
    /// read «Markus Weber Geschäftsführer» as a three-word name.
    pub roles: &'static [&'static str],
    /// The legal forms a company name ends with: «GmbH», «AB».
    pub company_forms: &'static [&'static str],
    /// Conjunctions a company name may contain: «Müller **und** Partner».
    pub conjunctions: &'static [&'static str],
    /// Endings that make a word a surname in this language, whatever dictionary
    /// knows it — Swedish `-sson`, `-ström`, `-berg`.
    ///
    /// The owner's sentence: «every word ending in son is a surname in Sweden».
    /// It is a **signal**, exactly as a dictionary hit is: it can make the
    /// scanner offer a name it would have walked past, and it can never protect
    /// one by itself. Empty for a language whose surnames are not built this
    /// way — German's is empty, and that is why nothing German moves.
    pub family_suffixes: &'static [&'static str],
    /// Which half comes first.
    #[allow(dead_code, reason = "see NameOrder: declared, and nothing branches on it yet")]
    pub order: NameOrder,

    /// The name lists, as the CSV the build ships, and where it came from.
    pub names: &'static str,
    /// One line naming the sources and their licences. The full text lives in
    /// `z_core/assets/licenses/`, and this is the pointer a report prints.
    pub provenance: &'static str,

    /// Rules this language needs that no other language can use.
    ///
    /// A national vehicle plate, a national way of writing a local telephone
    /// number: real, and not generalisable. The length of this list is the
    /// measure of the contract — a pack that needs nothing here is a pack that
    /// is pure data, which is what the second one should be.
    pub extra: &'static [PackRule],
}

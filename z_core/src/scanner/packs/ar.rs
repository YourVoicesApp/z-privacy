//! Arabic — the first pack whose script has no capital letter.
//!
//! The owner, 25 October 2026, handed over his own list of Arabic names and the
//! doctrine that goes with it: **the sentences, a bounded name library, and a
//! few rules that can be measured — never unbounded coverage.** So this file is
//! a locale, four word lists, his library and two rules, and the rules are here
//! rather than in the shared engine for a reason worth writing down.
//!
//! # Why the shared engine cannot see Arabic, and why that is not a bug
//!
//! `people::name_shaped` asks `starts_upper` of every word before anything else
//! looks at it. In German and Swedish that question is the first signal a name
//! gives: a capitalised word in the middle of a sentence is a noun or a name,
//! and the dictionary then says which. **Arabic has no capital letter**, so
//! `char::is_uppercase` is false for every letter of every Arabic word and the
//! whole of `people.rs` — the pair, the walk, the reversed pair, the role —
//! finds nothing in an Arabic document. Measured on `Risala_Alharbi.txt`
//! (AR-1): a bare Arabic session found 5 auto and 2 waiting before this paper,
//! all seven of them from the general rules — an IBAN, a BIC, three telephone
//! numbers and two e-mail addresses — and **not one of its eight people**.
//!
//! The tempting fix is to make `starts_upper` answer «yes» for an uncased
//! script. It was not done, and the measurement is the reason: the pair rule
//! may return a name **without** asking the dictionary (`require_known` is
//! false for a salutation's own walk), so every two adjacent Arabic words in
//! every Arabic document would have become a person. A script with no case does
//! not have a weaker version of the German signal; it has a different signal,
//! and the different signal is written here.
//!
//! # The two rules, and the discipline they keep
//!
//! Exactly the Auto/Suggested discipline the German name bank has, with the two
//! halves swapped — because in German case proposes and the dictionary
//! confirms, while in Arabic the dictionary proposes and a form word confirms:
//!
//!   * **`ar-1`, a name after a salutation or a title → Auto.** «نothing but a
//!     person follows «Frau»» is the owner's own rule for German, and Arabic
//!     writes the same proof with «السيد», «السيدة», «الدكتورة», «الأستاذ»,
//!     «المهندسة». The words after it are taken by **shape** — Arabic letters,
//!     no digits, not a function word, at most four of them, never across a
//!     line — so a name no list has ever heard of is still protected: AR-1's
//!     first person is «كاترين لندمان», who is in no Arabic name library and
//!     would be missed by a dictionary for ever.
//!   * **`ar-2`, a known given name standing alone → Suggested.** This is where
//!     the owner's library earns its place, and it waits for his word because a
//!     great many Arabic given names are also ordinary words — «أمل» is hope,
//!     «نور» is light, «سلام» is peace. A dictionary hit is a signal and never
//!     a verdict, which is the sentence `de_names.rs` opens with.
//!
//! # Harakat, and no NFKC anywhere near this
//!
//! 897 of the owner's 2414 names carry a vowel mark. A document may write the
//! same name with the marks or without them, so the index below is **folded**:
//! `as_the_pack_reads_it` drops the harakat and the tatweel and nothing else,
//! and the word a document offers is folded the same way before it is looked
//! up. That is «both ways» — «أَحْمَد» in the library is found in a document
//! that writes «أحمد», and a document that writes «أَحْمَد» finds the name the
//! library wrote bare.
//!
//! **NFKC is not used and may not be**: it decomposes the Arabic isolated mark
//! forms into space + mark and cuts words in two, which `text.rs` measures by
//! name. The fold here is `text::as_a_person_reads_it` — NFC, with the
//! characters nobody can see dropped — and then the marks.
//!
//! # What this pack does not carry, and says so
//!
//! The library is a list of **given** names: it holds no surnames, so
//! `family_suffixes` is empty and `ar-2` never claims a family name. Arabic
//! surnames are mostly a nisba — «الحربي», «العمري» — and an ending rule for
//! them is a measurement nobody has made yet. `greetings`, `roles` and
//! `copulas` are empty for the same reason: AR-1 is a formal letter and opens
//! with a salutation, not a greeting, so there is nothing in it to measure a
//! greeting on, and a word in one of these lists that no document of ours has
//! shown is a guess dressed as data.

use std::collections::BTreeSet;
use std::sync::OnceLock;

use super::pack::{bare, LanguagePack, NameOrder, Word};
use super::people;
use crate::scanner::{Candidate, Confidence, Kind};

/// The owner's library, as the build ships it — built by
/// `scripts/build_ar_names.py` from `~/الأسماء العربية.txt`, so his own file
/// stays the source and this is only its reading.
pub(crate) const CSV: &str =
    include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/assets/ar_names_v1.csv"));

/// Words that introduce a person, and are never part of the name.
///
/// Measured on AR-1, which uses «السيدة» for the person it is addressed to and
/// «السيد» for two men. Both genders of a measured word are here, because a
/// gender is not a second guess — it is the same word.
const SALUTATIONS: &[&str] = &["السيد", "السيدة", "السادة", "سيدي", "سيدتي"];

/// Titles that stand before a name and are not part of it.
///
/// Every one of these stands in AR-1 in one of its two genders: «الدكتورة
/// أميرة الحداد», «الأستاذ يوسف العمري», «المهندسة سارة البراك». The bare forms
/// without «ال» are here too, because a letter may write «دكتور أحمد».
const TITLES: &[&str] = &[
    "الدكتور", "الدكتورة", "دكتور", "دكتورة", "د.",
    "الأستاذ", "الأستاذة", "أستاذ", "أستاذة", "أ.",
    "المهندس", "المهندسة", "مهندس", "مهندسة",
    "الشيخ", "الشيخة", "المحامي", "المحامية", "الأستاذ الدكتور",
];

/// The courtesy words a letter puts **around** a name — before it and after it
/// — which are neither titles nor part of the name.
///
/// AR-1's own line is the measurement: «السيدة الفاضلة كاترين لندمان
/// المحترمة،». One of these before the name is stepped over; one after it ends
/// the name, which is how «المحترمة» stays in the clear.
const COURTESIES: &[&str] = &[
    "الفاضلة", "الفاضل", "المحترم", "المحترمة", "الكريم", "الكريمة",
    "الموقر", "الموقرة", "حفظه", "حفظها",
];

/// Ordinary Arabic words that end a name run.
///
/// Not a list of «words that are also names» — that is the Suggested side's
/// problem and it is answered by waiting rather than by a list. These are the
/// prepositions and the connectives that actually follow a name in AR-1:
/// «بتاريخ 3 مارس», «من قسم المبيعات», «في فرعنا», «أو الجوال». A name run that
/// did not stop at them would swallow the sentence.
const FUNCTION_WORDS: &[&str] = &[
    "في", "من", "إلى", "على", "عن", "مع", "و", "أو", "ثم", "قد", "كان", "كانت",
    "بتاريخ", "التالي", "التالية", "الذي", "التي", "هو", "هي", "هذا", "هذه",
    "لدى", "لديكم", "بن؟", "رقم", "اسم", "الساعة", "يوم", "بعد", "قبل", "حتى",
    "إنّ", "أن", "أنّ", "لا", "ما", "كل", "بعض", "غير", "بين", "حول", "عند",
];

/// Words that begin a sentence and belong to no name — the uncased script's
/// version of a stop word, and deliberately short: without a capital letter
/// there is no «capitalised word that opens a sentence» to defend against, so
/// the only entries are the ones AR-1 showed next to a name.
const STOP_WORDS: &[&str] = &["الموضوع", "شكراً", "وتفضلوا", "وقد", "وكما", "للاستفسار"];

/// The legal forms an Arabic company name ends with: «ذ.م.م» is a limited
/// company, «ش.م.ك» a Kuwaiti shareholding one. From AR-1's own signature,
/// «شركة الحربي للتقنيات الكهربائية ذ.م.م».
const COMPANY_FORMS: &[&str] = &["ذ.م.م", "ش.م.م", "ش.م.ك", "ش.م.س", "المحدودة", "وشركاه"];

/// «شركة لندمان وشركاه» — what joins two names in one company's.
const CONJUNCTIONS: &[&str] = &["و", "&", "وشركاه"];

/// The Arabic harakat, the tatweel, and nothing else.
///
/// Dropped for matching only. The library keeps every mark the owner typed and
/// so does the document: this fold answers a question and hands back no text,
/// the same contract `people::name_shaped` keeps.
fn without_marks(word: &str) -> String {
    word.chars()
        .filter(|c| !matches!(c, '\u{064B}'..='\u{0652}' | '\u{0670}' | '\u{0640}' | '\u{0653}'..='\u{0655}'))
        .collect()
}

/// **How this pack reads a word** — the reading base's own fold, then the marks.
pub(crate) fn as_the_pack_reads_it(word: &str) -> String {
    without_marks(&crate::text::as_a_person_reads_it(word))
}

/// Arabic punctuation a sentence puts around a word, beside the Latin marks
/// `bare` already trims: the Arabic comma, semicolon, question mark and full
/// stop. AR-1 writes «لندمان المحترمة،» and a candidate that carried that comma
/// would be protecting a mark.
fn bare_ar(word: &str) -> &str {
    bare(word).trim_matches(|c: char| matches!(c, '\u{060C}' | '\u{061B}' | '\u{061F}' | '\u{06D4}'))
}

/// The owner's library, folded, read once for the life of the process.
fn given_names() -> &'static BTreeSet<String> {
    static LOADED: OnceLock<BTreeSet<String>> = OnceLock::new();
    LOADED.get_or_init(|| {
        let mut out = BTreeSet::new();
        for line in CSV.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') || line.starts_with("name,") {
                continue;
            }
            let mut fields = line.splitn(3, ',');
            let (Some(name), Some(kind)) = (fields.next(), fields.next()) else { continue };
            if kind.trim() != "given" {
                continue;
            }
            let folded = as_the_pack_reads_it(name.trim());
            // Two letters at least, for the reason `name_shaped` gives: a
            // single letter is an initial, and a document is full of them.
            if folded.chars().count() >= 2 {
                out.insert(folded);
            }
        }
        out
    })
}

/// Is this word shaped like a part of an Arabic name?
///
/// Arabic letters, and the marks that sit on them. No digit, no Latin letter,
/// no bracket — which is what stops the run at «(yousef.alomari@…)» in AR-1 —
/// and not one of the words that end a name.
fn could_be_part_of_a_name(word: &str) -> bool {
    let w = bare_ar(word);
    let folded = as_the_pack_reads_it(w);
    folded.chars().count() >= 2
        && w.chars().all(|c| {
            matches!(c, '\u{0600}'..='\u{06FF}' | '\u{0750}'..='\u{077F}' | '\u{FB50}'..='\u{FEFF}')
                && !matches!(c, '\u{0660}'..='\u{0669}' | '\u{06F0}'..='\u{06F9}')
        })
        && !FUNCTION_WORDS.contains(&folded.as_str())
        && !STOP_WORDS.contains(&folded.as_str())
        && !COMPANY_FORMS.contains(&folded.as_str())
        // **A form word is never part of a name, and never a name either** —
        // `people::name_shaped` says this three times over, each time after the
        // suite found the same fault in a new list, and this file reproduced it
        // on its first run: «السيدة» is a given name in the owner's own library
        // (his line 1118), so `ar-2` offered the salutation of AR-1's opening
        // line as a person to look at, and «السيّد» folds to «السيد» and did it
        // twice more. Said here, once, so both rules get the same answer.
        && !is_a_form_word(w)
}

fn is_a_form_word(word: &str) -> bool {
    let folded = as_the_pack_reads_it(bare_ar(word));
    SALUTATIONS.contains(&folded.as_str())
        || TITLES.contains(&folded.as_str())
        || COURTESIES.contains(&folded.as_str())
}

/// Where a word ends once the marks a sentence put on it are left out.
fn end_without_marks(word: &Word<'_>) -> usize {
    let text = word.text;
    let kept = bare_ar(text);
    match text.find(kept) {
        Some(at) => word.start + at + kept.len(),
        None => word.end,
    }
}

/// **`ar-1`: whoever follows a salutation or a title is a person.**
///
/// The one proof an uncased script gives for free, and the only rule in this
/// pack that protects by itself. It takes the courtesy chain first — «السيدة
/// الفاضلة» — then up to four words of the name, and it stops at the end of the
/// line, at a function word, at a courtesy word and at anything that is not
/// Arabic letters.
///
/// Four, because AR-1 writes «السيد طارق بن سعود الريحاني»: a full Arabic name
/// is a given name, «بن», the father's name and the family's. Five would have
/// taken «بتاريخ» on the one line where the name is already four words long,
/// and the function word is what stops it there — the cap is the second fence
/// and not the first.
fn names_after_a_salutation(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    let mut at = 0usize;
    while let Some(here) = words.get(at) {
        let folded = as_the_pack_reads_it(bare_ar(here.text));
        let opener = SALUTATIONS.contains(&folded.as_str()) || TITLES.contains(&folded.as_str());
        if !opener {
            at += 1;
            continue;
        }
        // Step over the chain of form words: «السائق السيد», «السيدة الفاضلة».
        let mut from = at + 1;
        while let Some(next) = words.get(from) {
            if next.newline_before || !is_a_form_word(next.text) {
                break;
            }
            from += 1;
        }
        let mut last: Option<usize> = None;
        for step in 0..4 {
            let Some(word) = words.get(from + step) else { break };
            if word.newline_before || !could_be_part_of_a_name(word.text) {
                break;
            }
            last = Some(from + step);
            // A word the sentence closed — «الحداد،» — is the last of the name.
            if bare_ar(word.text) != word.text {
                break;
            }
        }
        let (Some(end_index), Some(first)) = (last, words.get(from)) else {
            at += 1;
            continue;
        };
        let Some(end_word) = words.get(end_index) else {
            at += 1;
            continue;
        };
        out.push(people::candidate(
            &pack(),
            first.start,
            end_without_marks(end_word),
            Kind::Person,
            Confidence::Auto,
            "salutation",
            "the words after an Arabic salutation or title, which nothing but a person follows"
                .to_string(),
        ));
        at = end_index + 1;
    }
}

/// **`ar-2`: a word the owner's library knows is a name to look at.**
///
/// Suggested, never Auto, and one word at a time: a great many Arabic given
/// names are ordinary words, and the library holds given names only — so there
/// is nothing here that could honestly claim the family name beside it.
///
/// A word already inside an `ar-1` run is left alone: the settler drops the
/// smaller of two findings over the same text, and offering a person's given
/// name a second time as a question about one word would be two findings about
/// one name.
fn a_name_the_library_knows(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    let known = given_names();
    for word in words {
        if !could_be_part_of_a_name(word.text) {
            continue;
        }
        let folded = as_the_pack_reads_it(bare_ar(word.text));
        if !known.contains(&folded) {
            continue;
        }
        out.push(people::candidate(
            &pack(),
            word.start,
            end_without_marks(word),
            Kind::Person,
            Confidence::Suggest,
            "name-library",
            "a given name in your Arabic name library — a dictionary match, and your word decides"
                .to_string(),
        ));
    }
}

/// **`ar-3`: a long number written in Arabic-Indic digits.**
///
/// The hole this closes was measured on AR-1 before it existed: the letter
/// writes an internal extension as «تحويلتها الداخلية ٠١٢١٢٣٤٥٩٩», and **every
/// rule in this program was blind to it**. The general rules walk bytes and ask
/// `is_ascii_digit`, which is false for «٠» — so a number a reader sees as a
/// number was in the clear, in a document whose other three telephone numbers
/// were all found. Ten digits of a person's extension, invisible because they
/// were typed in the script the rest of the letter is written in.
///
/// Same window as the general rule it mirrors — eight digits to fifteen — and
/// the same answer, **Suggested**: an order number and an invoice number look
/// the same, so the person's word decides. One shape must not be two rules with
/// two opinions, and this is deliberately a copy of that one's judgement rather
/// than a stricter or looser opinion of its own.
///
/// Separators are the space and the dash, as there. A date needs no special
/// clause here: «٢٧/١١/١٩٧٩» is cut by its slashes into runs of two, two and
/// four, and none of them reaches eight — which is why the general rule's own
/// date test has no counterpart below.
///
/// **What this does not do**: the checksum rules — an IBAN's mod-97, a card's
/// Luhn — still read ASCII digits only. An IBAN is ASCII by its own
/// specification and AR-1 writes it that way; a card number in Arabic-Indic
/// digits is a measurement nobody has made, and a rule written for it would be
/// a guess with a checksum in it.
fn numbers_in_arabic_digits(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    let is_digit = |c: char| matches!(c, '\u{0660}'..='\u{0669}' | '\u{06F0}'..='\u{06F9}');
    let mut at = 0usize;
    while let Some(first) = words.get(at) {
        if !bare_ar(first.text).chars().any(is_digit) {
            at += 1;
            continue;
        }
        let from = first.start;
        // The run: this word and the ones after it on the same line that hold
        // nothing but Arabic-Indic digits and the separators.
        let mut last = at;
        let mut digits = 0usize;
        let mut ok = true;
        let mut step = at;
        while let Some(word) = words.get(step) {
            if step > at && word.newline_before {
                break;
            }
            let w = bare_ar(word.text);
            if !w.chars().all(|c| is_digit(c) || matches!(c, '-' | '\u{2013}')) {
                if step == at {
                    ok = false;
                }
                break;
            }
            digits += w.chars().filter(|c| is_digit(*c)).count();
            last = step;
            step += 1;
        }
        if ok && (8..=15).contains(&digits) {
            let Some(end_word) = words.get(last) else { break };
            out.push(people::candidate(
                &pack(),
                from,
                end_without_marks(end_word),
                Kind::Phone,
                Confidence::Suggest,
                "digits-local",
                "a long number written in Arabic-Indic digits — a telephone number looks like \
                 this, and so can an order or an invoice number, so your word decides"
                    .to_string(),
            ));
        }
        at = last + 1;
    }
}

pub(crate) fn pack() -> LanguagePack {
    LanguagePack {
        locale: "ar-SA",
        id: "ar",
        label: "العربية",
        in_english: "Arabic",
        version: "1",
        salutations: SALUTATIONS,
        greetings: &[],
        titles: TITLES,
        title_parts: &[],
        degrees: &[],
        function_words: FUNCTION_WORDS,
        stop_words: STOP_WORDS,
        closings: &[],
        roles: &[],
        copulas: &[],
        company_forms: COMPANY_FORMS,
        conjunctions: CONJUNCTIONS,
        family_suffixes: &[],
        order: NameOrder::GivenThenFamily,
        names: CSV,
        provenance: "the owner's own Arabic name library — 1292 male and 1135 female given names, 2427 lines and 2414 distinct; see z_core/assets/licenses/arabic_names_sources.md",
        extra: &[
            ("names after a salutation", names_after_a_salutation),
            ("names the owner's library knows", a_name_the_library_knows),
            ("numbers in Arabic-Indic digits", numbers_in_arabic_digits),
        ],
    }
}

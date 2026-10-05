//! The German privacy pack.
//!
//! Three kinds of knowledge, and each one's confidence is a decision:
//!
//! Labels — `Kundennummer:`, `Telefon:` — used to live here as a Rust table.
//! Since 29 September they are rows in `scanner/sets/de.rs` and run through the
//! shared engine, so another language can be active at the same time. What is
//! left in this file is the German knowledge that is not a label: a salutation,
//! a legal form, the shape of an address.
//! * **A salutation names the person who follows it.** → `Auto`, and the name
//!   only: `Frau` itself stays in the clear so the model can still write a
//!   correct German reply.
//!
//!   It was a `Suggest` until 3 October, on the reading that «after `Frau`
//!   usually comes a person — usually». The owner scanned a letter of his own
//!   that day and said: «it did not hide the names… not one of the seven people
//!   was encrypted». A salutation in a German letter is not a guess about the
//!   next word; it is a word written to introduce a person. The confidence
//!   moved, the span did not, and `golden_scan.rs` recorded the change with its
//!   reason rather than absorbing it.
//! * **A signature is a name too** (3 October). A line of its own under a
//!   closing formula, or above a line that says what the person's role is.
//!   The owner signs his own name with no salutation in front of it, so nothing
//!   in this file had seen it — and after he had answered every question the
//!   app asked, his name was still in the text that would have left.
//! * **A company form is a hint too.** A run ending in `GmbH` is very probably a
//!   company, but a document can also discuss «die GmbH» in general. → `Suggest`.

use crate::api::{Kind, Source};

use crate::scanner::{Candidate, Confidence};

const PACK: &str = "de";

/// Salutations and titles: what follows one of these is probably a person.
const SALUTATIONS: &[&str] = &["Herr", "Herrn", "Frau", "Fr.", "Hr."];
/// Titles that introduce a person, German and Austrian, as they are written.
///
/// Measured on a 734-page Austrian document whose team page is a column of
/// doctors: not one of them was protected, because a title only counted when a
/// salutation stood in front of it. In this writing the title **is** how a name
/// is introduced — «Prim. Dr. Ludwig Neuner», «Ing. Mag. Alexander Wölfl» — so
/// a title starts a name as well as sitting inside one.
const TITLES: &[&str] = &[
    "Dr.", "Dr", "Dr.in", "DDr.", "MMag.", "Mag.", "Mag", "Mag.a", "Prof.", "Prof",
    "Univ.-Prof.", "Univ.-Doz.", "Priv.-Doz.", "PD", "Prim.", "Prim", "DI", "Dipl.-Ing.",
    "Dipl.-Kfm.", "Ing.", "Bakk.",
];
/// The parts of a Latin title that never stand on their own: «Dr. med. univ.».
/// Stepped over inside a chain, and never the start of one — in German every
/// noun is capitalised, so «med. Abteilung» would otherwise name a person.
const TITLE_PARTS: &[&str] = &["med.", "rer.", "nat.", "phil.", "techn.", "univ.", "h.c.", "mult."];
/// German function words that are also given names in the dictionary.
///
/// `An` (at, to) is rank 175 of the 300 and `Nur` (only) is rank 224 — real
/// names, used in Berlin, and they belong in the list. But V2 widened the
/// surnames from ten to 601, of which 43 are ordinary German words (Koch a
/// cook, Richter a judge, Bauer a farmer), and the pair of those two facts is
/// «An Müller GmbH» — how a German letter is addressed — or «Nur Richter
/// dürfen entscheiden», which offered a protection on the word «only».
/// Measured: that pair never occurs in 880 pages of the owner's documents, and
/// it is one line of ordinary business German away.
///
/// A function word cannot open a name. It is kept here, in the rule, and not
/// taken out of the owner's list: the list says what Berlin named its children,
/// which is true, and this says what a sentence can mean, which is also true.
const FUNCTION_WORDS: &[&str] = &["an", "nur"];

/// Degrees that follow a name. They are not part of it and do not start one.
const DEGREES: &[&str] = &["MBA", "MSc", "BSc", "BA", "MA", "LL.M.", "PhD", "MPH", "MAS", "CFA"];
/// The legal forms a German company name ends with.
const COMPANY_FORMS: &[&str] = &[
    "GmbH", "AG", "UG", "KG", "OHG", "GbR", "SE", "e.K.", "eG", "mbH", "KGaA",
];
/// Capitalised words that start a sentence but belong to no name.
const STOP_WORDS: &[&str] = &[
    "Die", "Der", "Das", "Den", "Dem", "Des", "Ein", "Eine", "Einer", "Eines", "Unser", "Unsere",
    "Ihr", "Ihre", "Seine", "Mit", "Von", "An", "Bei", "Für", "Und", "Als", "Auch", "Diese",
    "Dieser", "Dieses", "Im", "In", "Am", "Zur", "Zum", "Wir", "Sie", "Es", "Herzlich",
];

/// Words that make a street name.
const STREET_ENDINGS: &[&str] = &[
    "straße", "strasse", "str.", "str", "weg", "platz", "allee", "gasse", "ring", "damm", "ufer",
];

/// One whitespace-separated token, with its byte range.
struct Word<'a> {
    start: usize,
    end: usize,
    text: &'a str,
    /// True when a line break sits between this word and the one before it.
    ///
    /// Two of the pack's rules need this: a name does not run past the end of a
    /// line, and neither does a labelled value. Without it, «Ansprechpartner:
    /// Herr Thomas Müller\nTelefon:» reads as a three-word name.
    newline_before: bool,
}

/// Is this word a label — «Telefon:», «BIC:» — rather than a value?
///
/// A label ends a value: `IBAN: DE89 … 00` must stop before `BIC:`, or one
/// finding swallows the next.
fn is_label(word: &str) -> bool {
    word.ends_with(':')
}

fn words(text: &str) -> Vec<Word<'_>> {
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
            });
            index = end;
        }
    }
    out
}

/// The word without the punctuation a sentence puts around it.
fn bare(word: &str) -> &str {
    word.trim_matches(|c: char| matches!(c, ',' | ';' | ':' | '.' | '!' | '?' | '"' | '(' | ')' | '»' | '«'))
}

/// Same, but keeping a trailing dot, which belongs to «Dr.» and «e.K.».
fn bare_keep_dot(word: &str) -> &str {
    word.trim_matches(|c: char| matches!(c, ',' | ';' | ':' | '!' | '?' | '"' | '(' | ')' | '»' | '«'))
}

fn starts_upper(word: &str) -> bool {
    bare(word).chars().next().is_some_and(char::is_uppercase)
}

fn is_numberish(word: &str) -> bool {
    let w = bare(word);
    !w.is_empty()
        && w.chars().any(|c| c.is_ascii_digit())
        && w.chars().all(|c| c.is_ascii_digit() || matches!(c, '+' | '-' | '/' | '(' | ')' | '.' | ' '))
}

/// The end of `word`'s range with sentence punctuation trimmed off.
fn trimmed_end(word: &Word<'_>) -> usize {
    let cut = word.text.len() - word.text.trim_end_matches([',', ';', ':', '.', '!', '?', '"', ')', '»']).len();
    word.end.saturating_sub(cut)
}

pub(crate) fn scan(text: &str) -> Vec<Candidate> {
    let words = words(text);
    let mut out = Vec::new();
    salutations(&words, &mut out);
    titled_names(&words, &mut out);
    dictionary_names(&words, &mut out);
    signatures(&words, &mut out);
    companies(&words, &mut out);
    addresses(&words, &mut out);
    plates(&words, &mut out);
    local_phones(&words, &mut out);
    out
}

fn candidate(
    start: usize,
    end: usize,
    kind: Kind,
    confidence: Confidence,
    rule: &str,
    reason: String,
) -> Candidate {
    Candidate {
        start,
        end,
        kind,
        confidence,
        source: Source::LanguagePack,
        source_detail: format!("{PACK}:{rule}"),
        reason,
        entities: Vec::new(),
        also: Vec::new(),
    }
}

/// The last word of a German closing formula, lowercased.
const CLOSINGS: &[&str] = &["grüßen", "grüssen", "grüße", "grüsse", "hochachtungsvoll"];
/// What a line under a signature says about the person who signed.
const ROLES: &[&str] = &[
    "geschäftsführer", "geschäftsführerin", "inhaber", "inhaberin", "i.a.", "ppa.", "prokurist",
    "vorstand", "mitglied",
];
/// Words that name a telephone number before one is written.
const PHONE_WORDS: &[&str] = &[
    "telefon", "telefonnummer", "tel", "tel.", "mobil", "handy", "durchwahl", "fax", "rufnummer",
];

/// The words of each line, as indices. Blank lines disappear, which is what we
/// want: a signature usually has one above it.
fn lines(words: &[Word<'_>]) -> Vec<Vec<usize>> {
    let mut out: Vec<Vec<usize>> = Vec::new();
    for (i, word) in words.iter().enumerate() {
        if i == 0 || word.newline_before {
            out.push(Vec::new());
        }
        if let Some(line) = out.last_mut() {
            line.push(i);
        }
    }
    out
}

/// The name under «Mit freundlichen Grüßen», and the name above
/// «Geschäftsführer».
///
/// The owner's letter of 3 October is why this exists: he signs his own name
/// with no salutation in front of it, so the salutation rule never saw it, and
/// after he had answered all fourteen questions his name was still in the text
/// that would have left the machine — three times.
fn signatures(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    let lines = lines(words);
    for (n, line) in lines.iter().enumerate() {
        if line.len() < 2 || line.len() > 3 {
            continue;
        }
        let all_names = line.iter().all(|&i| {
            words.get(i).is_some_and(|w| {
                let b = bare(w.text);
                starts_upper(b) && !b.is_empty() && !is_numberish(b) && !is_label(w.text)
            })
        });
        if !all_names {
            continue;
        }
        let closing_above = n > 0
            && lines
                .get(n - 1)
                .and_then(|l| l.last())
                .and_then(|&i| words.get(i))
                .is_some_and(|w| CLOSINGS.contains(&bare(w.text).to_lowercase().as_str()));
        let role_below = lines
            .get(n + 1)
            .and_then(|l| l.first())
            .and_then(|&i| words.get(i))
            .is_some_and(|w| ROLES.contains(&bare_keep_dot(w.text).to_lowercase().as_str()));
        if !closing_above && !role_below {
            continue;
        }
        let (Some(&first), Some(&last)) = (line.first(), line.last()) else { continue };
        let (Some(start_word), Some(end_word)) = (words.get(first), words.get(last)) else {
            continue;
        };
        let why = if closing_above {
            "a name on its own line under a closing formula — that is a signature"
        } else {
            "a name on its own line above what the person's role is — that is a signature"
        };
        out.push(candidate(
            start_word.start,
            trimmed_end(end_word),
            Kind::Person,
            Confidence::Auto,
            "signature",
            why.to_string(),
        ));
    }
}

/// `A-MW 2041` — a German plate: a town's letters, a hyphen, letters, a number.
fn plates(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare(word.text);
        let Some((town, letters)) = w.split_once('-') else { continue };
        let town_ok = (1..=3).contains(&town.chars().count())
            && town.chars().all(|c| c.is_uppercase() && c.is_alphabetic());
        let letters_ok = (1..=2).contains(&letters.chars().count())
            && letters.chars().all(|c| c.is_uppercase() && c.is_alphabetic());
        if !town_ok || !letters_ok {
            continue;
        }
        let Some(number) = words.get(i + 1) else { continue };
        if number.newline_before {
            continue;
        }
        let digits = bare(number.text);
        if digits.is_empty() || digits.chars().count() > 4 || !digits.chars().all(|c| c.is_ascii_digit()) {
            continue;
        }
        out.push(candidate(
            word.start,
            trimmed_end(number),
            Kind::Vehicle,
            Confidence::Auto,
            "plate",
            "the shape of a German registration plate".to_string(),
        ));
    }
}

/// `mobil unter 0171 9876543` — a local number is only a number until a word
/// nearby says it is a telephone. Then it is one, and it is not a question.
fn local_phones(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare(word.text);
        let local = w.len() >= 3 && w.starts_with('0') && w.chars().all(|c| c.is_ascii_digit());
        if !local {
            continue;
        }
        // A telephone word earlier on the same line, within a few words.
        let mut said_phone = false;
        let mut back = i;
        while back > 0 {
            back -= 1;
            let Some(prev) = words.get(back) else { break };
            if prev.newline_before || i - back > 6 {
                break;
            }
            if PHONE_WORDS.contains(&bare(prev.text).to_lowercase().trim_end_matches(':')) {
                said_phone = true;
                break;
            }
        }
        if !said_phone {
            continue;
        }
        // The number may be written in groups: «089 1234 5699».
        let mut last = i;
        let mut j = i + 1;
        while let Some(next) = words.get(j) {
            let n = bare(next.text);
            if next.newline_before || n.is_empty() || !n.chars().all(|c| c.is_ascii_digit()) || j - i > 3 {
                break;
            }
            last = j;
            j += 1;
        }
        let Some(end_word) = words.get(last) else { continue };
        out.push(candidate(
            word.start,
            trimmed_end(end_word),
            Kind::Phone,
            Confidence::Auto,
            "local-phone",
            "a local telephone number, written after a word that names one".to_string(),
        ));
    }
}

/// Is this word shaped like a name? A capital letter, then letters — a hyphen
/// or an apostrophe is a name («Müller-Lüdenscheidt», «O\'Brien»); a digit or a
/// bracket is not. This is the whole of what «(N95.1» failed to be.
fn name_shaped(word: &str) -> bool {
    let n = bare(word).trim_end_matches(['.', ',', ';', ':']);
    // Two letters at least. A single capital is an initial, and in the owner's
    // ICD-10 document the chapter letters — G, K, N, P, W — stand alone on
    // their own lines near a «DI» or a «Dr»: the rule protected 28,853 of them
    // as people, and the payload's own audit refused to build at all («a
    // protected value still stands 28,851 times where at most 3 was expected»).
    n.chars().count() >= 2
        && starts_upper(n)
        && n.chars().all(|c| c.is_alphabetic() || c == '-' || c == '\'' || c == '\u{2019}')
        && !STOP_WORDS.contains(&n)
        && !DEGREES.contains(&n)
}

/// Step over a chain of titles: «Dr.», «Prim. Dr.», «Univ.-Prof. Dr. med.».
/// Returns where the chain ends and what it said, or `None` if there is no
/// title here at all.
fn title_chain(words: &[Word<'_>], from: usize) -> Option<(usize, String)> {
    let mut at = from;
    let mut said: Vec<String> = Vec::new();
    while let Some(next) = words.get(at) {
        if at > from && next.newline_before {
            break;
        }
        let n = bare_keep_dot(next.text);
        let known = TITLES.iter().any(|t| t.eq_ignore_ascii_case(n))
            || (!said.is_empty() && TITLE_PARTS.iter().any(|t| t.eq_ignore_ascii_case(n)));
        if !known {
            break;
        }
        said.push(n.to_string());
        at += 1;
    }
    (!said.is_empty()).then(|| (at, said.join(" ")))
}

/// The name that follows: up to three words, each shaped like one.
fn name_from(words: &[Word<'_>], first: usize) -> Option<(usize, usize)> {
    let mut j = first;
    let mut last = None;
    while let Some(next) = words.get(j) {
        // A bracket opens something that is not the name: «Ludwig Neuner
        // (Klinikum Freistadt, OÖG)» is one person and one hospital.
        if next.newline_before || is_label(next.text) || next.text.starts_with(['(', '[', '{', '«', '"']) {
            break;
        }
        let n = bare(next.text);
        let joiner = matches!(n, "von" | "van" | "de" | "der" | "zu");
        if (name_shaped(next.text) || joiner) && j - first < 3 {
            last = Some(j);
            // A word carrying a comma, a full stop or a closing bracket ends it.
            if next.text.ends_with([',', '.', ';', ')', ':']) {
                break;
            }
            j += 1;
        } else {
            break;
        }
    }
    last.map(|last| (first, last))
}

/// «Herr Thomas Müller» → the name, not the salutation.
fn salutations(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare_keep_dot(word.text);
        if !SALUTATIONS.iter().any(|s| s.eq_ignore_ascii_case(w)) {
            continue;
        }
        // An article in front of it was tried here first — «bei der Frau
        // (N95.1)» — and taken out again: the first golden letter says «den
        // Herr Tobias Reinhardt am 3. März», where «den» is a relative
        // pronoun, not an article, and the rule lost a real person. The shape
        // of what **follows** does the work instead, and does it in every one
        // of the four cases measured.
        // Step over a title: «Herr Dr. Schneider», «Frau Mag. Spitzwieser».
        let (j, title) = match title_chain(words, i + 1) {
            Some((at, said)) => (at, Some(said)),
            None => (i + 1, None),
        };
        let Some((first, last)) = name_from(words, j) else { continue };
        let Some(start_word) = words.get(first) else { continue };
        let Some(end_word) = words.get(last) else { continue };
        let reason = match title {
            Some(t) => format!("a name after «{w} {t}» — a German salutation names the person who follows it"),
            None => format!("a name after «{w}» — a German salutation names the person who follows it"),
        };
        out.push(candidate(
            start_word.start,
            trimmed_end(end_word),
            Kind::Person,
            Confidence::Auto,
            "salutation",
            reason,
        ));
    }
}

/// «Prim. Dr. Ludwig Neuner» → the name. The title stays in the clear.
///
/// The owner's words, on a page of twenty-odd doctors none of which was
/// protected: «the name after Dr. is supposed to be encrypted».
fn titled_names(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    let mut i = 0usize;
    while i < words.len() {
        // Only the start of a chain, so «Dr.» inside «Prim. Dr. …» is not read
        // twice — and a salutation in front of it leaves the work to that rule.
        let follows_title = i
            .checked_sub(1)
            .and_then(|k| words.get(k))
            .is_some_and(|prev| {
                let n = bare_keep_dot(prev.text);
                TITLES.iter().any(|t| t.eq_ignore_ascii_case(n))
                    || TITLE_PARTS.iter().any(|t| t.eq_ignore_ascii_case(n))
                    || SALUTATIONS.iter().any(|t| t.eq_ignore_ascii_case(n))
            });
        let Some((after, said)) = title_chain(words, i) else {
            i += 1;
            continue;
        };
        if follows_title {
            i += 1;
            continue;
        }
        if let Some((first, last)) = name_from(words, after) {
            if let (Some(start_word), Some(end_word)) = (words.get(first), words.get(last)) {
                out.push(candidate(
                    start_word.start,
                    trimmed_end(end_word),
                    Kind::Person,
                    Confidence::Auto,
                    "title",
                    format!("a name after «{said}» — a title introduces the person who follows it"),
                ));
            }
        }
        i = after.max(i + 1);
    }
}

/// «Thomas Müller» — two names in a row, and nothing in the sentence saying so.
///
/// The one thing the German Name Dictionary V1 adds. Everything else about a
/// person this pack already knew: a salutation names the person after it, a
/// title introduces one. What it could not see was a name standing on its own
/// in a sentence — a signature, a line in a table, «… hat Thomas Müller
/// unterschrieben» — because nothing there announces a person.
///
/// Three rules hold it to a signal rather than a verdict:
///
/// * **both halves**, a given name then a surname. One hit is a word that
///   happens to be in a list: «Im August», «Die Rose», «Der Max».
/// * **offered, never protected.** `Confidence::Suggest`, always. A list of
///   310 names may not decide that a word is somebody's name; a person decides,
///   or another rule does.
/// * **it yields.** A salutation or a title in front means another rule owns
///   this name and has already protected it, so this one says nothing.
fn dictionary_names(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    let names = super::de_names::dictionary();
    let mut i = 0usize;
    while i + 1 < words.len() {
        let (Some(first), Some(second)) = (words.get(i), words.get(i + 1)) else { break };
        let given = bare(first.text).trim_end_matches(['.', ',', ';', ':']);
        let family = bare(second.text).trim_end_matches(['.', ',', ';', ':']);
        if !(name_shaped(first.text) && name_shaped(second.text))
            || second.newline_before
            || FUNCTION_WORDS.contains(&given.to_lowercase().as_str())
            || !names.given(given)
            || !names.family(family)
        {
            i += 1;
            continue;
        }
        // Another rule's ground: a salutation or a title in front of this pair
        // protects it outright, and two findings on one name is one too many.
        let claimed = i.checked_sub(1).and_then(|k| words.get(k)).is_some_and(|prev| {
            let n = bare_keep_dot(prev.text);
            SALUTATIONS.iter().any(|t| t.eq_ignore_ascii_case(n))
                || TITLES.iter().any(|t| t.eq_ignore_ascii_case(n))
                || TITLE_PARTS.iter().any(|t| t.eq_ignore_ascii_case(n))
        });
        if claimed {
            i += 2;
            continue;
        }
        out.push(candidate(
            first.start,
            trimmed_end(second),
            Kind::Person,
            // Never Auto. This is the whole of item B of the owner's paper.
            Confidence::Suggest,
            "name-dictionary",
            format!(
                "«{given}» is one of the 300 given names and «{family}» one of the ten surnames in the German name dictionary — two names in a row, offered for your word"
            ),
        ));
        i += 2;
    }
}

/// «Nordstern Consulting GmbH» — and «GmbH & Co. KG» as one form.
fn companies(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare_keep_dot(word.text);
        // A company at the end of a sentence carries the sentence's full stop:
        // «… bei Nordstern GmbH.» was invisible to this rule until 3 October,
        // because the dot that belongs to «e.K.» is kept and the one that
        // belongs to the sentence looks exactly like it. Both spellings are
        // tried, so neither form is lost.
        let trimmed = w.trim_end_matches('.');
        if !COMPANY_FORMS.contains(&w) && !COMPANY_FORMS.contains(&trimmed) {
            continue;
        }
        // Walk left over capitalised words to the start of the name.
        let mut first = i;
        while first > 0 {
            // Do not walk back across a line break.
            if words.get(first).is_some_and(|w| w.newline_before) {
                break;
            }
            let Some(prev) = words.get(first - 1) else { break };
            let p = bare(prev.text);
            // A label, a comma or a full stop ends the name to the left:
            // «Kunde: Nordstern GmbH» is not called «Kunde Nordstern GmbH».
            let closes = prev.text.ends_with(':')
                || prev.text.ends_with(',')
                || prev.text.ends_with(';')
                || prev.text.ends_with('.');
            let function_word = STOP_WORDS.contains(&p);
            // «Lindemann & Partner GmbH» is one name. The walk steps over the
            // «&» — or «und» — when a capitalised word stands on the far side
            // of it, and stops otherwise, so «die GmbH und wir» is left alone.
            if !closes && matches!(p, "&" | "und" | "+") {
                let before = first.checked_sub(2).and_then(|k| words.get(k));
                let joins = before.is_some_and(|b| {
                    let t = bare(b.text);
                    starts_upper(t) && !t.is_empty() && !STOP_WORDS.contains(&t) && !b.newline_before
                });
                if joins {
                    first -= 1;
                    continue;
                }
                break;
            }
            if !closes
                && !function_word
                && starts_upper(p)
                && !p.is_empty()
                && !SALUTATIONS.iter().any(|s| s.eq_ignore_ascii_case(p))
            {
                first -= 1;
            } else {
                break;
            }
        }
        if first == i {
            // «die GmbH» on its own is a word about companies, not a company.
            continue;
        }
        // «GmbH & Co. KG» keeps going to the right.
        let mut last = i;
        if let (Some(amp), Some(co), Some(kg)) = (words.get(i + 1), words.get(i + 2), words.get(i + 3)) {
            if bare(amp.text) == "&"
                && bare_keep_dot(co.text).eq_ignore_ascii_case("Co.")
                && COMPANY_FORMS.contains(&bare_keep_dot(kg.text))
            {
                last = i + 3;
            }
        }
        let (Some(start_word), Some(end_word)) = (words.get(first), words.get(last)) else {
            continue;
        };
        out.push(candidate(
            start_word.start,
            trimmed_end(end_word),
            Kind::Company,
            Confidence::Suggest,
            "company-form",
            format!("a name ending in «{w}», which is a German legal form — probably this client's company"),
        ));
    }
}

/// «Hafenstraße 14, 20359 Hamburg» — a street, a house number, a postcode, a town.
fn addresses(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare(word.text);
        let is_postcode = w.len() == 5 && w.chars().all(|c| c.is_ascii_digit());
        if !is_postcode {
            continue;
        }
        // A town must follow.
        let Some(town) = words.get(i + 1) else { continue };
        if !starts_upper(town.text) {
            continue;
        }
        // Walk left: a house number, then a street.
        let mut first = i;
        if i >= 2 {
            let house = words.get(i - 1);
            let street = words.get(i - 2);
            if let (Some(house), Some(street)) = (house, street) {
                let house_ok = is_numberish(bare(house.text));
                let s = bare(street.text).to_lowercase();
                let street_ok = STREET_ENDINGS.iter().any(|e| s.ends_with(e));
                if house_ok && street_ok {
                    first = i - 2;
                    // A street may be two words: «Berliner Allee», «Alter
                    // Markt». The word before it joins when it is capitalised
                    // and is not the end of the sentence before it.
                    if let Some(before) = first.checked_sub(1).and_then(|k| words.get(k)) {
                        let b = bare(before.text);
                        let joins = starts_upper(b)
                            && !b.is_empty()
                            && !STOP_WORDS.contains(&b)
                            && !is_label(before.text)
                            && !before.text.ends_with(',')
                            && !before.text.ends_with('.')
                            && !before.text.ends_with(':')
                            && !words.get(first).is_some_and(|w| w.newline_before);
                        if joins {
                            first -= 1;
                        }
                    }
                }
            }
        }
        let Some(start_word) = words.get(first) else { continue };
        out.push(candidate(
            start_word.start,
            trimmed_end(town),
            Kind::Address,
            Confidence::Suggest,
            "address",
            "a postcode and a town, with a street before them — an address, if this one is a person's".to_string(),
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn found(text: &str) -> Vec<(Kind, Confidence, String)> {
        scan(text)
            .into_iter()
            .map(|c| {
                (
                    c.kind,
                    c.confidence,
                    text.get(c.start..c.end).unwrap_or_default().to_string(),
                )
            })
            .collect()
    }

    #[test]
    fn a_salutation_points_at_the_name_and_leaves_the_salutation() {
        // «Frau» stays in the clear: the model still needs it to write a correct
        // German reply, and it hides nothing on its own. What changed on
        // 3 October is the confidence, not the span: the salutation is the
        // proof, so the name after it is protected rather than asked about.
        assert_eq!(
            found("Frau Anna Weber übernimmt."),
            vec![(Kind::Person, Confidence::Auto, "Anna Weber".to_string())]
        );
        assert_eq!(
            found("Herr Dr. Schneider ruft an."),
            vec![(Kind::Person, Confidence::Auto, "Schneider".to_string())]
        );
    }

    #[test]
    fn a_company_form_takes_the_whole_name() {
        assert_eq!(
            found("Kunde: Nordstern Consulting GmbH"),
            vec![(
                Kind::Company,
                Confidence::Suggest,
                "Nordstern Consulting GmbH".to_string()
            )]
        );
        assert_eq!(
            found("Die Hamburger Hafen Logistik GmbH & Co. KG liefert."),
            vec![(
                Kind::Company,
                Confidence::Suggest,
                "Hamburger Hafen Logistik GmbH & Co. KG".to_string()
            )]
        );
        // A sentence about companies in general is not a company name.
        assert!(found("Die GmbH ist eine Rechtsform.").is_empty());
    }


    #[test]
    fn an_address_needs_a_postcode_and_a_town() {
        assert_eq!(
            found("Lieferung an die Hafenstraße 14, 20359 Hamburg."),
            vec![(
                Kind::Address,
                Confidence::Suggest,
                "Hafenstraße 14, 20359 Hamburg".to_string()
            )]
        );
        // A bare five-digit number is not an address.
        assert!(found("Die Rechnung 20359 ist offen.").is_empty());
    }

    #[test]
    fn every_finding_says_which_pack_and_why() {
        for c in scan("Frau Anna Weber, Kundennummer: 41-88203, Nordstern Consulting GmbH") {
            assert!(c.source_detail.starts_with("de:"), "{}", c.source_detail);
            assert!(!c.reason.is_empty());
        }
    }
}

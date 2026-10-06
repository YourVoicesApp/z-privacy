//! The rules about people — the same rules for every language.
//!
//! The shared half of a language pack. Not one word in this file is German,
//! Swedish or English: every word these rules look for comes out of the
//! [`LanguagePack`] they are handed, which is what makes the second language
//! data and a third one a decision about data.
//!
//! Five rules, and they are the whole of it: a **salutation** names the person
//! after it; a **title** introduces one and itself stays in the clear; two
//! **known names in a row** are a person, offered and never protected; a
//! **closing** is followed by a signature; a **legal form** ends a company
//! name. And one thing that is not a rule but a question — `discover_names`,
//! the Phase 2 mechanism that notices the names a document uses which no list
//! knows, here for the same reason: a language should get it by being data.
//!
//! What is **not** here is what is not language: an e-mail address, a
//! telephone number in international form, an IBAN, a BIC. Those live in
//! `general_rules.rs`, where every pack gets them for nothing. And what one
//! language needs that no other can use — a national plate, a national way of
//! writing a local number — stays in that language's own file and is declared
//! in its pack's `extra`, so the list can be counted rather than found by
//! reading.

use crate::api::{Kind, Source};
use crate::scanner::{Candidate, Confidence};

use super::de_names;
use super::pack::{
    bare, bare_keep_dot, is_label, is_numberish, starts_upper, trimmed_end, words, LanguagePack,
    Word,
};

/// Every rule that is about people rather than about one language.
pub(crate) fn scan_with(
    text: &str,
    pack: &LanguagePack,
    taught: &[(String, bool)],
) -> Vec<Candidate> {
    let words = words(text);
    let mut out = Vec::new();
    salutations(&words, pack, &mut out);
    titled_names(&words, pack, &mut out);
    dictionary_names(&words, pack, taught, &mut out);
    reversed_pairs(text, &words, pack, taught, &mut out);
    signatures(&words, pack, &mut out);
    companies(&words, pack, &mut out);
    // And what this language needs that no other can use, each named in its
    // pack so the list can be counted.
    for (_, rule) in pack.extra {
        rule(&words, &mut out);
    }
    out
}

pub(crate) fn candidate(
    pack: &LanguagePack,
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
        source_detail: format!("{}:{rule}", pack.id),
        reason,
        entities: Vec::new(),
        also: Vec::new(),
    }
}

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
fn signatures(words: &[Word<'_>], pack: &LanguagePack, out: &mut Vec<Candidate>) {
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
                .is_some_and(|w| pack.closings.contains(&bare(w.text).to_lowercase().as_str()));
        let role_below = lines
            .get(n + 1)
            .and_then(|l| l.first())
            .and_then(|&i| words.get(i))
            .is_some_and(|w| pack.roles.contains(&bare_keep_dot(w.text).to_lowercase().as_str()));
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
            pack,
            start_word.start,
            trimmed_end(end_word),
            Kind::Person,
            Confidence::Auto,
            "signature",
            why.to_string(),
        ));
    }
}

/// Is this word shaped like a name? A capital letter, then letters — a hyphen
/// or an apostrophe is a name («Müller-Lüdenscheidt», «O\'Brien»); a digit or a
/// bracket is not. This is the whole of what «(N95.1» failed to be.
fn name_shaped(word: &str, pack: &LanguagePack) -> bool {
    let n = bare(word).trim_end_matches(['.', ',', ';', ':']);
    // Two letters at least. A single capital is an initial, and in the owner's
    // ICD-10 document the chapter letters — G, K, N, P, W — stand alone on
    // their own lines near a «DI» or a «Dr»: the rule protected 28,853 of them
    // as people, and the payload's own audit refused to build at all («a
    // protected value still stands 28,851 times where at most 3 was expected»).
    n.chars().count() >= 2
        && starts_upper(n)
        && n.chars().all(|c| c.is_alphabetic() || c == '-' || c == '\'' || c == '\u{2019}')
        && !pack.stop_words.contains(&n)
        && !pack.degrees.contains(&n)
}

/// Step over a chain of titles: «Dr.», «Prim. Dr.», «Univ.-Prof. Dr. med.».
/// Returns where the chain ends and what it said, or `None` if there is no
/// title here at all.
fn title_chain(words: &[Word<'_>], from: usize, pack: &LanguagePack) -> Option<(usize, String)> {
    let mut at = from;
    let mut said: Vec<String> = Vec::new();
    while let Some(next) = words.get(at) {
        if at > from && next.newline_before {
            break;
        }
        let n = bare_keep_dot(next.text);
        let known = pack.titles.iter().any(|t| t.eq_ignore_ascii_case(n))
            || (!said.is_empty() && pack.title_parts.iter().any(|t| t.eq_ignore_ascii_case(n)));
        if !known {
            break;
        }
        said.push(n.to_string());
        at += 1;
    }
    (!said.is_empty()).then(|| (at, said.join(" ")))
}

/// The name that follows: up to three words, each shaped like one.
fn name_from(words: &[Word<'_>], first: usize, pack: &LanguagePack) -> Option<(usize, usize)> {
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
        if (name_shaped(next.text, pack) || joiner) && j - first < 3 {
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
fn salutations(words: &[Word<'_>], pack: &LanguagePack, out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare_keep_dot(word.text);
        if !pack.salutations.iter().any(|s| s.eq_ignore_ascii_case(w)) {
            continue;
        }
        // An article in front of it was tried here first — «bei der Frau
        // (N95.1)» — and taken out again: the first golden letter says «den
        // Herr Tobias Reinhardt am 3. März», where «den» is a relative
        // pronoun, not an article, and the rule lost a real person. The shape
        // of what **follows** does the work instead, and does it in every one
        // of the four cases measured.
        // Step over a title: «Herr Dr. Schneider», «Frau Mag. Spitzwieser».
        let (j, title) = match title_chain(words, i + 1, pack) {
            Some((at, said)) => (at, Some(said)),
            None => (i + 1, None),
        };
        let Some((first, last)) = name_from(words, j, pack) else { continue };
        let Some(start_word) = words.get(first) else { continue };
        let Some(end_word) = words.get(last) else { continue };
        let reason = match title {
            Some(t) => format!("a name after «{w} {t}» — a German salutation names the person who follows it"),
            None => format!("a name after «{w}» — a German salutation names the person who follows it"),
        };
        out.push(candidate(
            pack,
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
fn titled_names(words: &[Word<'_>], pack: &LanguagePack, out: &mut Vec<Candidate>) {
    let mut i = 0usize;
    while i < words.len() {
        // Only the start of a chain, so «Dr.» inside «Prim. Dr. …» is not read
        // twice — and a salutation in front of it leaves the work to that rule.
        let follows_title = i
            .checked_sub(1)
            .and_then(|k| words.get(k))
            .is_some_and(|prev| {
                let n = bare_keep_dot(prev.text);
                pack.titles.iter().any(|t| t.eq_ignore_ascii_case(n))
                    || pack.title_parts.iter().any(|t| t.eq_ignore_ascii_case(n))
                    || pack.salutations.iter().any(|t| t.eq_ignore_ascii_case(n))
            });
        let Some((after, said)) = title_chain(words, i, pack) else {
            i += 1;
            continue;
        };
        if follows_title {
            i += 1;
            continue;
        }
        if let Some((first, last)) = name_from(words, after, pack) {
            if let (Some(start_word), Some(end_word)) = (words.get(first), words.get(last)) {
                out.push(candidate(
                    pack,
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

/// A word this document uses as a name, which no dictionary of ours knows.
///
/// Phase 2's whole idea: Z does not need a dictionary of every surname on
/// earth. It needs to **notice** the names a document keeps using, gather each
/// one once, and ask about it once — «I have 17 names for you to look at» for a
/// 700-page file. What comes back is a candidate, never a finding: nothing here
/// protects anything, and nothing here writes to a dictionary.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct NameHint {
    /// Where the word sits in the text, so the session can keep the place.
    pub start: usize,
    pub end: usize,
    /// What the document is using it as.
    pub family: bool,
    /// Which rule noticed it, for the «why» a person is owed.
    pub rule: &'static str,
}

/// The two rules of Phase 1 of Phase 2, measured and no wider.
///
/// **«Kowalski, Thomas»** — a word, a comma, then a given name this build
/// knows. That is a list of people, written the way lists of people are
/// written, and the word before the comma is a surname. The comma alone proves
/// nothing: «Berlin, Hauptstadt» is not a person.
///
/// **«Mahmoud Al-Hassan»** — a known given name, then a word that is shaped
/// like a name and is in no dictionary. The given name is the evidence; the
/// word after it is the candidate.
///
/// Neither fires on a lone capitalised word, and the function-word guard of
/// Phase 1 holds here too: «An Bauer» and «Nur Richter» are a preposition and
/// an adverb, whatever follows them.
pub(crate) fn discover_names(
    text: &str,
    pack: &LanguagePack,
    taught: &dyn Fn(&str) -> bool,
) -> Vec<NameHint> {
    let names = de_names::dictionary_of(pack.locale, pack.names);
    let words = words(text);
    let mut out: Vec<NameHint> = Vec::new();
    let known = |word: &str| {
        let bare = bare(word).trim_end_matches(['.', ',', ';', ':']);
        names.given(bare) || names.family(bare) || taught(bare)
    };

    // Where a trimmed slice really sits. `bare` takes characters off **both**
    // ends, so a span built as «the word's start plus the trimmed length»
    // points at the wrong place as soon as anything was trimmed from the front:
    // measured on the owner's 734-page file, «(BMASGPK)» came back as
    // «(BMASGP». A span that is one character out is a protection in the wrong
    // place, which is the one mistake this project will not make twice.
    let span_of = |word: &Word<'_>, slice: &str| -> (usize, usize) {
        let at = word.text.find(slice).unwrap_or(0);
        (word.start + at, word.start + at + slice.len())
    };

    for (i, word) in words.iter().enumerate() {
        let bare_now = bare(word.text).trim_end_matches([',', ';', ':']);
        // «Kowalski, Thomas» — the comma is part of the form, so it is read
        // from the raw word and not trimmed away first.
        if word.text.ends_with(',') && name_shaped(bare_now, pack) && !known(bare_now) {
            let next = words.get(i + 1);
            let follows_given = next.is_some_and(|n| {
                let n_bare = bare(n.text).trim_end_matches(['.', ',', ';', ':']);
                !n.newline_before
                    && names.given(n_bare)
                    && !pack.function_words.contains(&n_bare.to_lowercase().as_str())
            });
            if follows_given {
                let (start, end) = span_of(word, bare_now);
                out.push(NameHint {
                    start,
                    end,
                    family: true,
                    rule: "surname-before-a-known-given-name",
                });
                continue;
            }
        }
        // «Mahmoud Al-Hassan» — a known given name, then an unknown name.
        let given = bare(word.text).trim_end_matches(['.', ',', ';', ':']);
        if !names.given(given)
            || pack.function_words.contains(&given.to_lowercase().as_str())
            || !name_shaped(word.text, pack)
        {
            continue;
        }
        let Some(next) = words.get(i + 1) else { continue };
        if next.newline_before || is_label(next.text) || next.text.starts_with(['(', '[', '«', '"']) {
            continue;
        }
        let candidate = bare(next.text).trim_end_matches(['.', ',', ';', ':']);
        if name_shaped(candidate, pack) && !known(candidate) && !pack.company_forms.contains(&candidate) {
            let (start, end) = span_of(next, candidate);
            out.push(NameHint {
                start,
                end,
                family: true,
                rule: "unknown-name-after-a-known-given-name",
            });
        }
    }
    out
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
fn dictionary_names(
    words: &[Word<'_>],
    pack: &LanguagePack,
    taught: &[(String, bool)],
    out: &mut Vec<Candidate>,
) {
    let names = de_names::dictionary_of(pack.locale, pack.names);
    // Three layers, kept apart: what this build ships with, what the person
    // taught, and — in `discover_names` — what nobody has decided yet. A
    // taught name is as good as a shipped one here: the person said so.
    let taught_given = |word: &str| taught.iter().any(|(t, family)| !family && t.eq_ignore_ascii_case(word));
    let taught_family = |word: &str| taught.iter().any(|(t, family)| *family && t.eq_ignore_ascii_case(word));
    let mut i = 0usize;
    while i + 1 < words.len() {
        let (Some(first), Some(second)) = (words.get(i), words.get(i + 1)) else { break };
        let given = bare(first.text).trim_end_matches(['.', ',', ';', ':']);
        let family = bare(second.text).trim_end_matches(['.', ',', ';', ':']);
        if !(name_shaped(first.text, pack) && name_shaped(second.text, pack))
            || second.newline_before
            || pack.function_words.contains(&given.to_lowercase().as_str())
            || !(names.given(given) || taught_given(given))
            || !(names.family(family) || taught_family(family) || ends_like_a_family_name(second.text, pack))
        {
            i += 1;
            continue;
        }
        // Another rule's ground: a salutation or a title in front of this pair
        // protects it outright, and two findings on one name is one too many.
        let claimed = i.checked_sub(1).and_then(|k| words.get(k)).is_some_and(|prev| {
            let n = bare_keep_dot(prev.text);
            pack.salutations.iter().any(|t| t.eq_ignore_ascii_case(n))
                || pack.titles.iter().any(|t| t.eq_ignore_ascii_case(n))
                || pack.title_parts.iter().any(|t| t.eq_ignore_ascii_case(n))
        });
        if claimed {
            i += 2;
            continue;
        }
        out.push(candidate(
            pack,
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
fn companies(words: &[Word<'_>], pack: &LanguagePack, out: &mut Vec<Candidate>) {
    for (i, word) in words.iter().enumerate() {
        let w = bare_keep_dot(word.text);
        // A company at the end of a sentence carries the sentence's full stop:
        // «… bei Nordstern GmbH.» was invisible to this rule until 3 October,
        // because the dot that belongs to «e.K.» is kept and the one that
        // belongs to the sentence looks exactly like it. Both spellings are
        // tried, so neither form is lost.
        let trimmed = w.trim_end_matches('.');
        if !pack.company_forms.contains(&w) && !pack.company_forms.contains(&trimmed) {
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
            let function_word = pack.stop_words.contains(&p);
            // «Lindemann & Partner GmbH» is one name. The walk steps over the
            // «&» — or «und» — when a capitalised word stands on the far side
            // of it, and stops otherwise, so «die GmbH und wir» is left alone.
            // «Lindemann & Partner», «Lindgren och Söner» — the words are the
            // pack's, so nothing in this file knows what German is.
            if !closes && (pack.conjunctions.contains(&p) || p == "+") {
                let before = first.checked_sub(2).and_then(|k| words.get(k));
                let joins = before.is_some_and(|b| {
                    let t = bare(b.text);
                    starts_upper(t) && !t.is_empty() && !pack.stop_words.contains(&t) && !b.newline_before
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
                && !pack.salutations.iter().any(|s| s.eq_ignore_ascii_case(p))
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
            if pack.conjunctions.contains(&bare(amp.text))
                && bare_keep_dot(co.text).eq_ignore_ascii_case("Co.")
                && pack.company_forms.contains(&bare_keep_dot(kg.text))
            {
                last = i + 3;
            }
        }
        let (Some(start_word), Some(end_word)) = (words.get(first), words.get(last)) else {
            continue;
        };
        out.push(candidate(
            pack,
            start_word.start,
            trimmed_end(end_word),
            Kind::Company,
            Confidence::Suggest,
            "company-form",
            format!("a name ending in «{w}», which is a German legal form — probably this client's company"),
        ));
    }
}


/// Does this word end the way a surname ends in this language?
///
/// The owner's rule, and a signal of exactly a dictionary hit's strength: it can
/// make the scanner offer a name, never protect one. Three conditions keep it
/// off ordinary words, and each one was measured:
///
/// * **a capital**, because a Swedish sentence does not capitalise its nouns —
///   «person» is a word, «Person» at the start of a sentence is caught by the
///   stop-word list, and nothing else in five pages of Swedish prose survives
///   both;
/// * **five letters at least**, so «son» and «berg» standing alone are words;
/// * **not a word the pack already set aside** — a stop word or a function
///   word is never a name, whatever it ends with.
fn ends_like_a_family_name(word: &str, pack: &LanguagePack) -> bool {
    if pack.family_suffixes.is_empty() {
        return false;
    }
    let bare = bare(word);
    if bare.chars().count() < 5 || !bare.chars().next().is_some_and(char::is_uppercase) {
        return false;
    }
    let lower = bare.to_lowercase();
    if pack.stop_words.iter().any(|w| w.eq_ignore_ascii_case(bare))
        || pack.function_words.contains(&lower.as_str())
        || pack.roles.iter().any(|w| w.eq_ignore_ascii_case(bare))
        || pack.closings.iter().any(|w| w.eq_ignore_ascii_case(bare))
    {
        return false;
    }
    // The ending must be an ending, not the whole word: «Berg» is a mountain.
    pack.family_suffixes
        .iter()
        .any(|suffix| lower.len() > suffix.len() && lower.ends_with(suffix))
}

/// «Reinhardt, Tobias» — the way a ledger, a staff list and a form write a
/// person: the surname, a comma, the given name.
///
/// Phase 2 could only **discover** this form: `discover_names` fires when the
/// word before the comma is a surname nobody knows, and offers it as a name to
/// look at. That had two faults, and 038-H made the second one visible.
///
/// * A person whose surname **is** known was found by nothing at all. «Demir»
///   is a given name in three city registers now, so the comma rule walked past
///   it and Yusuf Demir vanished from the review — knowing more names found
///   fewer people.
/// * And a candidate is not a finding: the person stood in the clear while the
///   app asked whether the word was a name.
///
/// So the pair is a rule. **The evidence is the given name after the comma**,
/// which is the same evidence `dictionary_names` uses in the other direction;
/// the word before it is a surname whether this build has heard of it or not.
/// `Confidence::Suggest`, always — a list of names may not decide that a word
/// is somebody's name, which is item B of the owner's paper and holds here too.
///
/// What it yields to: a label in front («Name: Lindemann, Katharina») is
/// another rule's ground and protects outright, and the discovery rule still
/// offers an unknown surname as a name to look at.
fn reversed_pairs(
    text: &str,
    words: &[Word<'_>],
    pack: &LanguagePack,
    taught: &[(String, bool)],
    out: &mut Vec<Candidate>,
) {
    let names = de_names::dictionary_of(pack.locale, pack.names);
    let taught_given = |word: &str| taught.iter().any(|(t, family)| !family && t.eq_ignore_ascii_case(word));
    let mut i = 0usize;
    while i + 1 < words.len() {
        let (Some(first), Some(second)) = (words.get(i), words.get(i + 1)) else { break };
        // The comma is part of the form, so it is read before anything is
        // trimmed away.
        let family = bare(first.text).trim_end_matches([',', ';', ':']);
        let given = bare(second.text).trim_end_matches(['.', ',', ';', ':']);
        if !first.text.ends_with(',')
            || second.newline_before
            || !name_shaped(family, pack)
            || !name_shaped(second.text, pack)
            || pack.function_words.contains(&family.to_lowercase().as_str())
            || pack.function_words.contains(&given.to_lowercase().as_str())
            || pack.stop_words.iter().any(|w| w.eq_ignore_ascii_case(family))
            || !(names.given(given) || taught_given(given))
        {
            i += 1;
            continue;
        }
        // **A list entry ends where its field ends.** Measured on 734 pages of
        // an ICD-10 catalogue: «Ösophagus, Pars abdominalis» and
        // «Mehrlingsgeburt, Art der Geburt» are Latin and German running on,
        // and «Pars» and «Art» are given names four and three cities gave a
        // child. Six false offers on one document. What the real rows have and
        // those do not is the end of a field after the given name: the line
        // ends, or a column's run of spaces begins. A single space and another
        // word is a phrase continuing, and this rule leaves it alone.
        let ends_the_field = match words.get(i + 2) {
            None => true,
            Some(next) => {
                next.newline_before
                    || text
                        .get(trimmed_end(second)..next.start)
                        .is_some_and(|gap| gap.contains('\t') || gap.contains("  "))
            }
        };
        if !ends_the_field {
            i += 1;
            continue;
        }
        // A label or a salutation in front owns this name already.
        let claimed = i.checked_sub(1).and_then(|k| words.get(k)).is_some_and(|prev| {
            let n = bare_keep_dot(prev.text);
            let bare_label = n.trim_end_matches(':');
            pack.salutations.iter().any(|t| t.eq_ignore_ascii_case(n))
                || pack.titles.iter().any(|t| t.eq_ignore_ascii_case(n))
                || pack.title_parts.iter().any(|t| t.eq_ignore_ascii_case(n))
                || prev.text.ends_with(':')
                || crate::scanner::sets::all()
                    .iter()
                    .any(|set| set.rules.iter().any(|rule| rule.label.eq_ignore_ascii_case(bare_label)))
        });
        if claimed {
            i += 2;
            continue;
        }
        // Both halves known is a stronger line than one, and the reason says
        // which — a person deciding is owed the difference.
        let both = names.family(family)
            || taught.iter().any(|(t, f)| *f && t.eq_ignore_ascii_case(family))
            || ends_like_a_family_name(family, pack);
        out.push(candidate(
            pack,
            first.start,
            trimmed_end(second),
            Kind::Person,
            Confidence::Suggest,
            "name-reversed-pair",
            if both {
                format!("«{family}, {given}» — a surname and a given name this build knows, written the way a list of people is written")
            } else {
                format!("«{given}» is a given name this build knows, and «{family}» stands before it with a comma — the way a list of people is written")
            },
        ));
        i += 2;
    }
}

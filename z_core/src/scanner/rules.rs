//! Label rules as **data**, and one engine that runs them.
//!
//! Before this file the words a language uses — `Kundennummer`, `Telefon` —
//! lived inside `packs/de.rs` as a Rust table that only the German pass could
//! read. Adding English meant a second pass; adding Swedish meant a third. The
//! owner's ruling of 29 September ends that: the words become rows, the
//! matching becomes one engine, and **a new language is a new rule set plus
//! golden tests — not a line of scanner**.
//!
//! What stays in Rust is what cannot be written as a row: the deterministic
//! detectors (an IBAN's own mod-97 checksum, an e-mail's shape), and the
//! [`Validator`]s, because a country that writes its numbers strangely needs
//! arithmetic, not vocabulary.
//!
//! ## The rule
//!
//! Exactly the fields the owner named, and no more:
//!
//! ```text
//! RuleId · Label · Kind · Boundary · Decision · Source · Scope · Validator?
//! ```
//!
//! `Scope` is not a field here because a built-in rule's scope *is* its set —
//! the set is switched on or off per profile. A rule a person teaches carries
//! its own scope and reaches this engine through [`LabelRule::taught`].

use crate::api::{Kind, Source};

use super::{Candidate, Confidence};

/// Where the value after a label ends.
///
/// One variant today, on purpose. The owner's rule: no «everything after the
/// word» boundary, or we bring back the bug where `IBAN:` swallowed `BIC:` and
/// the line below it. A second boundary is added the day a rule set needs one
/// and a golden test shows what it must not eat.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Boundary {
    /// `Kundennummer: 48392` — take the value and stop at the end of the field:
    /// a line break, or the next label this engine knows.
    AfterLabelSameField,
}

/// How the value after a label must be written, for the rule to fire.
///
/// This is the `Validator?` of the owner's shape. `Any` is the «?» — a rule
/// that trusts its label completely.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Validator {
    /// Digits with separators: a telephone number, a customer number.
    Number,
    /// One word with no spaces: an address, a tax id.
    Word,
    /// Letters and digits in groups: an IBAN, a BIC.
    Grouped,
    /// A person's name: consecutive capitalised words, with any honorific the
    /// set lists skipped so it stays in the clear — a model still needs «Herr»
    /// to write a correct German reply.
    Name,
    /// Two capitalised words at least — a given name **and** a surname.
    ///
    /// 038-B/2. A magazine credits its photographer as «Foto: Gonzalo
    /// Irigoyen», and that is proof enough to protect without asking. But the
    /// same three labels caption pictures: «Bild: Stockholm» is a city, and
    /// `Name` would have taken it, because `Name` asks only for a capital. A
    /// label this strong has to be paid for with a shape this strict.
    NamePair,
    /// Whatever follows, as one word. Used by rules a person teaches, who
    /// should not have to describe a shape to be understood.
    Any,
}

/// One label rule. Built in, or taught by the person using the program.
#[derive(Debug, Clone)]
pub(crate) struct LabelRule {
    /// Stable across runs, so a `Why?` sheet can name the exact rule.
    pub id: String,
    /// The word before the colon, already lowercased.
    pub label: String,
    pub kind: Kind,
    pub boundary: Boundary,
    pub decision: Confidence,
    /// The rule set that carries it (`de`, `en`), or `you` when taught.
    pub set: String,
    pub validator: Validator,
    /// Which layer the finding will be attributed to.
    pub source: Source,
}

impl LabelRule {
    /// A rule a person taught. Its decision is `Auto` for the same reason a
    /// built-in label is: they told us what the word means, and second-guessing
    /// a direct instruction is its own kind of dishonesty.
    pub(crate) fn taught(id: String, label: String, kind: Kind) -> Self {
        Self {
            id,
            label: crate::text::nfc(&label).to_lowercase(),
            kind,
            boundary: Boundary::AfterLabelSameField,
            decision: Confidence::Auto,
            set: "you".to_string(),
            validator: Validator::Any,
            source: Source::Hand,
        }
    }

    /// The sentence the review row and the `Why?` sheet show.
    fn reason(&self, written: &str) -> String {
        if self.set == "you" {
            format!("you taught Z Privacy that the value after «{written}:» is a {}", kind_word(self.kind))
        } else {
            format!("the value written after «{written}:», which says what it is")
        }
    }

    fn detail(&self) -> String {
        format!("{}:{}", self.set, self.id)
    }
}

fn kind_word(kind: Kind) -> &'static str {
    match kind {
        Kind::Person => "person",
        Kind::Company => "company",
        Kind::Email => "e-mail address",
        Kind::Phone => "phone number",
        Kind::Iban => "IBAN",
        Kind::Bic => "BIC",
        Kind::Account => "account number",
        Kind::TaxId => "tax ID",
        Kind::CustomerNo => "customer number",
        Kind::Address => "address",
        Kind::IdCard => "identity card number",
        Kind::Birthdate => "date of birth",
        Kind::Vehicle => "vehicle plate",
        Kind::SocialInsuranceNo => "social-insurance number",
        Kind::EmployeeNo => "personnel number",
        Kind::Contract => "contract",
        Kind::Project => "project",
        Kind::Client => "client",
        Kind::Custom => "protected value",
    }
}

/// One whitespace-separated token with its byte range.
struct Word<'a> {
    start: usize,
    text: &'a str,
    newline_before: bool,
    /// **Is the space before this word a column boundary?** (046/M.)
    ///
    /// Two or more spaces, or a tab. One space is a thousands separator and
    /// keeps a number together — `42 500`, `9999 000 01`. Two is a table
    /// laying out its columns, and nothing on the far side of it is part of
    /// the number on this side.
    ///
    /// The lead measured what its absence cost on the film's own payroll
    /// sheet. Section B reads
    ///
    /// ```text
    ///     25 February 2027   Hedvig Palmgren      account 7210     42 500
    /// ```
    ///
    /// and the `account` row protected **`7210     42 500`** — so every one of
    /// the eight ledger amounts went to the model inside a token. The demo's
    /// whole point is that the model finds a 2 400 difference by arithmetic on
    /// amounts and dates while seeing no names, and it was being asked to do
    /// that with half the numbers gone. It might still have answered from the
    /// reconciliation lines at the foot, which is worse: a demo that works by
    /// luck.
    ///
    /// And wrong on its own terms: `7210` is a ledger account code, not
    /// anybody's bank account, and the amount beside it is not personal data
    /// at all.
    ///
    /// This is 038-G/3's family — «the phone rule stops where a grouped id
    /// stands» — arriving from the other side.
    column_gap_before: bool,
}

fn words(text: &str) -> Vec<Word<'_>> {
    let mut out = Vec::new();
    let mut newline = false;
    let mut gap = 0usize;
    let mut tab = false;
    let mut cursor = 0usize;
    for (i, ch) in text.char_indices() {
        if ch.is_whitespace() {
            if cursor < i {
                out.push(Word {
                    start: cursor,
                    text: &text[cursor..i],
                    newline_before: newline,
                    column_gap_before: gap > 1 || tab,
                });
                newline = false;
                gap = 0;
                tab = false;
            }
            if ch == '\n' {
                newline = true;
            }
            if ch == '\t' {
                tab = true;
            }
            gap += 1;
            cursor = i + ch.len_utf8();
        }
    }
    if cursor < text.len() {
        out.push(Word {
            start: cursor,
            text: &text[cursor..],
            newline_before: newline,
            column_gap_before: gap > 1 || tab,
        });
    }
    out
}

fn bare(word: &str) -> &str {
    word.trim_matches(|c: char| !c.is_alphanumeric() && c != '+' && c != '@' && c != '.' && c != '-' && c != '/')
}

fn trimmed_end(word: &Word<'_>) -> usize {
    let trimmed = word.text.trim_end_matches([',', ';', '.', ')', ':']);
    word.start + trimmed.len()
}

fn is_numberish(value: &str) -> bool {
    !value.is_empty()
        && value.chars().any(|c| c.is_ascii_digit())
        && value.chars().all(|c| c.is_ascii_digit() || matches!(c, '-' | '/' | '.' | '(' | ')' | '+'))
}

/// Run every rule over the text. One pass, whatever the language.
///
/// The engine is deliberately ignorant of *which* language it is running: it is
/// handed rows and it matches rows. That is the whole point — the test that
/// proves it is `a_rule_set_this_build_never_heard_of_still_works`, which adds
/// a fictional set from a fixture and changes no line in this file.
pub(crate) fn scan_with(text: &str, rules: &[LabelRule], honorifics: &[String]) -> Vec<Candidate> {
    if rules.is_empty() {
        return Vec::new();
    }
    let mut columns = table_columns(text, rules);
    // The longest label any set carries, in words. `Contact person:` is two,
    // and nothing today is three — but the engine reads it from the data
    // rather than assuming, so a set may add a longer one without asking.
    let widest = rules
        .iter()
        .map(|r| r.label.split_whitespace().count())
        .max()
        .unwrap_or(1)
        .clamp(1, 4);
    // The last word of every label this set knows, so the loop below can leave
    // ordinary prose alone in one comparison.
    let tails: Vec<&str> = rules
        .iter()
        .filter_map(|r| r.label.split_whitespace().last())
        .collect();
    let words = words(text);
    let mut out = Vec::new();
    for (i, word) in words.iter().enumerate() {
        // A label is a label with a colon or without one. The owner's letter of
        // 3 October writes «mit der Kundennummer 7733-9120» and «Steuernummer
        // 143/815/08154» and «USt-IdNr. DE123456789», and the colon was the one
        // thing standing between those three values and being protected. What
        // keeps this from firing on ordinary prose is the validator: the word
        // after the label still has to be shaped like the value the row names.
        let tail = crate::text::nfc(word.text.trim_end_matches(':')).to_lowercase();
        if !tails.contains(&tail.as_str()) {
            continue;
        }
        // Read the label backwards from its last word: «person:» alone, then
        // «contact person:», and keep the longest any rule claims. A label of
        // several words must not cross a line break.
        let mut best: Option<(&LabelRule, usize, String)> = None;
        for span in 1..=widest {
            if span > i + 1 {
                break;
            }
            let first = i + 1 - span;
            let Some(run) = words.get(first..=i) else { break };
            if run.iter().skip(1).any(|w| w.newline_before) {
                break;
            }
            let written: String = run.iter().map(|w| w.text).collect::<Vec<_>>().join(" ");
            let label = crate::text::nfc(written.trim_end_matches(':')).to_lowercase();
            if let Some(rule) = rules.iter().filter(|r| r.label == label).max_by_key(|r| r.label.len()) {
                best = Some((rule, first, written.trim_end_matches(':').to_string()));
            }
        }
        let Some((rule, _label_start, written)) = best else { continue };
        // A label with a colon is a form. A label without one is a word in a
        // sentence until what follows it is shaped like a value.
        //
        // Measured on 146 pages of German tax prose: «Geburtsdatum und seine
        // Steuernummer» protected the word «und» as a date of birth, «in
        // Rechnung gestellt» offered «gestellt» as a contract, «E-Mail
        // versenden» protected «versenden». Seven values protected on that
        // book and three of them were ordinary German words.
        let wrote_colon = word.text.ends_with(':');
        let Boundary::AfterLabelSameField = rule.boundary;
        let mut first = i + 1;
        // «Rechnung Nr. 2026-04471», «Kunden-Nr 7733» — a number word between
        // the label and the value belongs to the label, not to the value.
        if let Some(next) = words.get(first) {
            let n = crate::text::nfc(bare(next.text)).to_lowercase();
            if !next.newline_before && matches!(n.as_str(), "nr" | "nr." | "-nr" | "-nr." | "nummer") {
                first += 1;
            }
        }
        let mut last = None;
        let mut j = first;
        // An honorific directly after the label is not part of the name.
        if rule.validator == Validator::Name {
            while let Some(next) = words.get(j) {
                if next.newline_before {
                    break;
                }
                let n = crate::text::nfc(bare(next.text)).to_lowercase();
                if honorifics.contains(&n) {
                    j += 1;
                } else {
                    break;
                }
            }
        }
        let value_start = j;
        if !wrote_colon {
            // Without a colon the value must carry a digit: an identifier, a
            // number, a date. A plain word never qualifies, in any language
            // whose nouns are capitalised.
            let shaped = words
                .get(value_start)
                .is_some_and(|w| !w.newline_before && bare(w.text).chars().any(|c| c.is_ascii_digit()));
            if !shaped {
                continue;
            }
        }
        while let Some(next) = words.get(j) {
            // The field ends at a line break, or where another label begins —
            // this is what stops «IBAN:» from eating the «BIC:» line under it.
            if next.newline_before || is_label(next.text, rules) {
                break;
            }
            // **And a number ends at a column boundary** (046/M). Only for the
            // two validators that read a run of digits across spaces: a name
            // may legitimately be laid out with two spaces between its words,
            // and a `Word`/`Any` value is one word anyway.
            if matches!(rule.validator, Validator::Number | Validator::Grouped)
                && next.column_gap_before
                && j > value_start
            {
                break;
            }
            let n = bare(next.text);
            let fits = match rule.validator {
                Validator::Number => is_numberish(n) || (j == value_start && n.starts_with('+') && n.len() > 1),
                Validator::Word | Validator::Any => j == value_start && !n.is_empty(),
                Validator::Grouped => !n.is_empty() && n.chars().all(|c| c.is_ascii_alphanumeric()),
                Validator::Name | Validator::NamePair => starts_upper(n) && j - value_start < 4,
            };
            if fits && j - value_start < 8 {
                last = Some(j);
                j += 1;
                // **A name ends at a comma** (046/C).
                //
                // `bare()` strips the comma before the word is judged, so
                // «Whitfield,» reads as «Whitfield» and the run kept going
                // through «Finance Director» — one Person finding with a job
                // title inside the token, which is what the lead measured on
                // both English film documents. The title is nobody's secret
                // and the model needs it to write the sentence, exactly as it
                // needs the honorific this run already steps over.
                //
                // The word **before** the comma is taken, because that is
                // where the name ends; `trimmed_end` then leaves the comma
                // out of the span.
                //
                // Only for a name. A grouped value writes an IBAN in groups
                // and a number may be written «1,234» — neither is a sentence
                // that a comma ends.
                //
                // **And only once the name is already whole**, which is the
                // line measurement drew rather than taste. «Ansprechpartner:
                // Müller, Thomas» is the German reversed pair, and behind a
                // label it is covered by **this** rule and by nothing else —
                // `reversed_pairs` wants the surname at the start of a line,
                // so stopping at every comma left «Thomas» in the clear beside
                // a protected «Müller», which is the exact shape of the defect
                // the owner met in 038-I. A comma after one word is the
                // reversed shape; after two it is a job title.
                //
                // What this costs, named so it is a decision: «Label:
                // Surname, Role» — one name and a role — keeps the role inside
                // the name. Measured on all four film documents: not one
                // writes that shape, and
                // `a_name_ends_where_the_name_ends.rs` pins it.
                //
                // And it cannot reach the two rules that read across a comma
                // on purpose: the German reversed pair «Nachname, Vorname» and
                // the Swedish «X, <role>» are in `packs/people.rs`, not in
                // this label path. Both are measured in
                // `a_name_ends_where_the_name_ends.rs` rather than trusted.
                if matches!(rule.validator, Validator::Name | Validator::NamePair)
                    && next.text.ends_with(',')
                    && j - value_start >= 2
                {
                    break;
                }
            } else {
                break;
            }
        }
        let (Some(last), Some(start_word)) = (last, words.get(value_start)) else {
            continue;
        };
        // One capitalised word is not a pair. Checked here rather than inside
        // the loop because the loop takes the run and only afterwards is there
        // a run to measure.
        if rule.validator == Validator::NamePair && last == value_start {
            continue;
        }
        let Some(end_word) = words.get(last) else { continue };
        out.push(Candidate {
            start: start_word.start,
            end: trimmed_end(end_word),
            kind: rule.kind,
            confidence: rule.decision,
            source: rule.source,
            source_detail: rule.detail(),
            reason: rule.reason(&written),
            entities: Vec::new(),
            also: Vec::new(),
        });
    }
    out.append(&mut columns);
    out
}

/// **A table says what its columns are once, at the top.**
///
/// A label rule reads the word before a value; in a table the word before a
/// value is whatever stands in the column to its left, and the label is three
/// lines up. So a ledger's four birth dates and four personnel numbers carry no
/// label at all — measured on DE-6, where the one date with a word in front of
/// it was protected and the four in the column were not.
///
/// The smallest honest version, and every condition earns its place:
///
/// * a **block** is two or more lines that each split into the same number of
///   cells on runs of two spaces or a tab — one space is prose;
/// * the first line of the block is the **header**, and a header cell counts
///   only when it is a label some active rule set already knows (`Geburtsdatum`,
///   `Personal-Nr.`, `Name` …). Dart invents nothing and nor does this: the
///   vocabulary is the pack's;
/// * a cell belongs to a column when it **starts** within the header cell's own
///   span of characters, give or take two — which is what makes a left-aligned
///   column a column;
/// * and the value still has to pass the row's own validator, so a word under
///   `Geburtsdatum` that is not a date is not protected as one.
///
/// A table of codes has no header this build knows, so nothing happens to it.
/// That is what keeps 734 pages of ICD-10 — every page of it a table — outside
/// this rule, and it is measured rather than hoped for: zero findings there.
fn table_columns(text: &str, rules: &[LabelRule]) -> Vec<Candidate> {
    let mut out = Vec::new();
    let lines: Vec<(usize, &str)> = line_offsets(text);
    let mut at = 0usize;
    while at < lines.len() {
        let Some((_header_start, header)) = lines.get(at).copied() else { break };
        let header_cells = cells(header);
        if header_cells.len() < 2 {
            at += 1;
            continue;
        }
        // The rows under it, while they keep the same number of cells.
        let mut rows: Vec<(usize, &str)> = Vec::new();
        let mut next = at + 1;
        while let Some((start, line)) = lines.get(next).copied() {
            if cells(line).len() != header_cells.len() {
                break;
            }
            rows.push((start, line));
            next += 1;
        }
        if rows.is_empty() {
            at += 1;
            continue;
        }
        for (column_at, column_text) in &header_cells {
            let wanted = crate::text::nfc(column_text.trim_end_matches(':')).to_lowercase();
            let Some(rule) = rules.iter().find(|r| r.label == wanted) else { continue };
            for (row_start, row) in &rows {
                for (cell_at, value) in cells(row) {
                    // Left-aligned, give or take two characters.
                    if cell_at + 2 < *column_at || *column_at + 2 < cell_at {
                        continue;
                    }
                    let value = value.trim();
                    // The cell still has to be the shape the row names: a word
                    // under «Geburtsdatum» that is not a date is not a date.
                    let fits = match rule.validator {
                        Validator::Number => is_numberish(value),
                        Validator::Word | Validator::Any => !value.is_empty(),
                        Validator::Grouped => value.chars().all(|c| c.is_ascii_alphanumeric() || c == ' '),
                        Validator::Name => starts_upper(value),
                        // In a table a cell is one value, so the pair has to be
                        // inside the cell.
                        Validator::NamePair => {
                            let mut words = value.split_whitespace();
                            words.next().is_some_and(starts_upper)
                                && words.next().is_some_and(starts_upper)
                        }
                    };
                    if value.is_empty() || !fits {
                        continue;
                    }
                    let Some(offset) = row.find(value) else { continue };
                    let start = row_start + offset;
                    out.push(Candidate {
                        start,
                        end: start + value.len(),
                        kind: rule.kind,
                        confidence: rule.decision,
                        source: rule.source,
                        source_detail: rule.detail(),
                        reason: format!(
                            "under «{column_text}» in a table, and that column's own header says what stands in it"
                        ),
                        entities: Vec::new(),
                        also: Vec::new(),
                    });
                }
            }
        }
        at = next.max(at + 1);
    }
    out
}

/// Every line with where it starts.
fn line_offsets(text: &str) -> Vec<(usize, &str)> {
    let mut out = Vec::new();
    let mut at = 0usize;
    for line in text.split('\n') {
        out.push((at, line));
        at += line.len() + 1;
    }
    out
}

/// A line's cells: runs separated by two or more spaces, or a tab. One space is
/// prose, which is the whole of what keeps a sentence out of this rule.
fn cells(line: &str) -> Vec<(usize, &str)> {
    let mut out = Vec::new();
    let bytes = line.as_bytes();
    let mut i = 0usize;
    while i < bytes.len() {
        while matches!(bytes.get(i), Some(b' ' | b'\t')) {
            i += 1;
        }
        let start = i;
        let mut end = i;
        while i < bytes.len() {
            match bytes.get(i) {
                Some(b'\t') => break,
                Some(b' ') if bytes.get(i + 1) == Some(&b' ') => break,
                Some(_) => {
                    i += 1;
                    end = i;
                }
                None => break,
            }
        }
        if end > start {
            if let Some(cell) = line.get(start..end) {
                out.push((start, cell));
            }
        }
        if i == start {
            i += 1;
        }
    }
    out
}

fn starts_upper(value: &str) -> bool {
    value.chars().next().is_some_and(|c| c.is_uppercase())
}

/// Is this word a label any active rule knows? Used as a boundary, so a rule
/// set switched off cannot stop another set's field.
fn is_label(word: &str, rules: &[LabelRule]) -> bool {
    let Some(stripped) = word.strip_suffix(':') else { return false };
    let lowered = crate::text::nfc(stripped).to_lowercase();
    rules.iter().any(|r| r.label == lowered)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scanner::sets;

    /// Text → (kind, what was captured), for the sets named.
    fn found(text: &str, active: &[&str]) -> Vec<(Kind, String)> {
        let active: Vec<String> = active.iter().map(|a| (*a).to_string()).collect();
        let rules = sets::rules_for(&active);
        scan_with(text, &rules, &sets::honorifics_for(&active))
            .into_iter()
            .map(|c| (c.kind, text[c.start..c.end].to_string()))
            .collect()
    }

    #[test]
    fn a_label_is_proof_of_what_follows_in_german() {
        assert_eq!(
            found("Kundennummer: 41-88203", &["de"]),
            vec![(Kind::CustomerNo, "41-88203".to_string())]
        );
        assert_eq!(
            found("USt-IdNr.: DE811728394", &["de"]),
            vec![(Kind::TaxId, "DE811728394".to_string())]
        );
    }

    /// The owner's own example, and the reason this milestone exists: one
    /// document, two languages, one scan.
    #[test]
    fn one_document_can_be_german_and_english_at_once() {
        let text = "Kundennummer: 48291\nContact person: Anna Weber\n";
        let hits = found(text, &["de", "en"]);
        assert!(
            hits.contains(&(Kind::CustomerNo, "48291".to_string())),
            "the German label was missed: {hits:?}"
        );
        assert!(
            hits.contains(&(Kind::Person, "Anna Weber".to_string())),
            "the English label was missed: {hits:?}"
        );
    }

    #[test]
    fn a_set_that_is_switched_off_finds_nothing() {
        assert!(found("Customer number: 5822", &["de"]).is_empty());
        assert_eq!(
            found("Customer number: 5822", &["en"]),
            vec![(Kind::CustomerNo, "5822".to_string())]
        );
    }

    /// The bug this boundary exists to prevent: a labelled value must stop at
    /// the end of its field, never run into the next line's label.
    #[test]
    fn a_value_stops_at_the_end_of_its_field() {
        let text = "IBAN: DE89 3704 0044 0532 0130 00\nBIC: COBADEFFXXX\n";
        let hits = found(text, &["de"]);
        assert_eq!(
            hits,
            vec![
                (Kind::Iban, "DE89 3704 0044 0532 0130 00".to_string()),
                (Kind::Bic, "COBADEFFXXX".to_string()),
            ],
            "the IBAN swallowed the line below it"
        );
    }

    /// An honorific belongs to the letter, not to the name: a model still needs
    /// «Mr.» — and «Herr» — to write a correct reply.
    ///
    /// Tested through English because German deliberately has no
    /// «Ansprechpartner» row; see the note at the head of `sets/de.rs`.
    #[test]
    fn an_honorific_stays_in_the_clear() {
        assert_eq!(
            found("Contact person: Mr. Thomas Müller", &["en"]),
            vec![(Kind::Person, "Thomas Müller".to_string())]
        );
    }

    /// «Ansprechpartner» is data **and** still a question.
    ///
    /// Both halves matter, and they are asserted together on purpose: the word
    /// must no longer be a hidden case in the logic, and the security decision
    /// must be the one it always was. Flipping this row to `Auto` is allowed
    /// one day — by a deliberate decision with its own test, which is exactly
    /// what this assertion forces someone to write.
    #[test]
    fn ansprechpartner_is_a_row_and_stays_a_suggestion() {
        let rules = sets::rules_for(&["de".to_string()]);
        let rule = rules
            .iter()
            .find(|r| r.label == "ansprechpartner")
            .expect("«Ansprechpartner» is no longer in the German rows");
        assert_eq!(rule.kind, Kind::Person);
        assert_eq!(
            rule.decision,
            Confidence::Suggest,
            "the label became Auto — that is a change of judgement, not of data"
        );
        assert_eq!(
            found("Ansprechpartner: Herr Thomas Müller", &["de"]),
            vec![(Kind::Person, "Thomas Müller".to_string())],
            "the honorific must stay in the clear"
        );
    }

    /// **The architectural test.**
    ///
    /// A rule set that exists nowhere in `scanner/sets/` — built here, in the
    /// test, out of nothing but rows — must detect. If this passes, the list is
    /// open. If it ever needs a line added to `scan_with` to pass, then we did
    /// not build an engine, we moved a `match` into another file.
    #[test]
    fn a_rule_set_this_build_never_heard_of_still_works() {
        let swedish = vec![
            LabelRule {
                id: "sv-01".to_string(),
                label: "kundnummer".to_string(),
                kind: Kind::CustomerNo,
                boundary: Boundary::AfterLabelSameField,
                decision: Confidence::Auto,
                set: "sv".to_string(),
                validator: Validator::Number,
                source: Source::LanguagePack,
            },
            LabelRule {
                id: "sv-02".to_string(),
                label: "kontaktperson".to_string(),
                kind: Kind::Person,
                boundary: Boundary::AfterLabelSameField,
                decision: Confidence::Auto,
                set: "sv".to_string(),
                validator: Validator::Name,
                source: Source::LanguagePack,
            },
        ];
        let text = "Kundnummer: 90210\nKontaktperson: Erik Lindqvist\n";
        let hits: Vec<(Kind, String)> = scan_with(text, &swedish, &[])
            .into_iter()
            .map(|c| (c.kind, text[c.start..c.end].to_string()))
            .collect();
        assert_eq!(
            hits,
            vec![
                (Kind::CustomerNo, "90210".to_string()),
                (Kind::Person, "Erik Lindqvist".to_string()),
            ],
            "a new language needed a scanner change — the list is not open"
        );
    }

    /// A rule a person taught runs in the same engine as a built-in row, and
    /// says so when asked why.
    #[test]
    fn a_taught_rule_detects_and_explains_itself() {
        let taught = vec![LabelRule::taught(
            "u1".to_string(),
            "Mandantenkennung".to_string(),
            Kind::CustomerNo,
        )];
        let text = "Mandantenkennung: 7781-B";
        let hits = scan_with(text, &taught, &[]);
        assert_eq!(hits.len(), 1, "the taught rule did not fire: {hits:?}");
        assert_eq!(&text[hits[0].start..hits[0].end], "7781-B");
        assert_eq!(hits[0].source, Source::Hand, "a taught rule is the user's own");
        assert!(
            hits[0].reason.contains("you taught Z Privacy"),
            "the reason does not say who taught it: {}",
            hits[0].reason
        );
        assert_eq!(hits[0].source_detail, "you:u1");
    }
}

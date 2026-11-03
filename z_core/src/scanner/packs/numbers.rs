//! A number written over several words, read once for every pack that needs
//! one — paper 120.
//!
//! French and Spanish write their national numbers in groups: a NIR as
//! `2 91 06 75 118 042 18`, a SIRET as `512 479 361 00028`, a Seguridad
//! Social number as `28/51739246/65`. The pack rules that read them are one
//! walk and one question each — *is this run the shape, and does its check come
//! out?* — and the walk is written here once, so that no rule reads a run its
//! own way and a second rule reads it another.
//!
//! **What a run is.** One to seven words on one line, each made of letters,
//! digits and the three separators `.` `-` `/` (and a `+` at its very start).
//! The run is handed to the rule as its **compact** form — every separator and
//! space taken out — and as its **groups**, the lengths between separators, so
//! that a rule can say «grouped as the office groups it» rather than only «the
//! right number of digits». The longest run is asked first, and a run that
//! matched is stepped over whole: a number is not found again from its second
//! group.

use crate::api::Kind;
use crate::scanner::{Candidate, Confidence};

use super::pack::{bare, is_label, LanguagePack, Word};

/// The most words a run may take: the NIR's seven groups.
const LONGEST: usize = 7;

/// What a rule is shown of a run.
pub(crate) struct Run {
    /// Every separator taken out: `29106751180421 8`, `ES B64819378`.
    pub compact: String,
    /// The lengths between separators, in order: `[1, 2, 2, 2, 3, 3, 2]`.
    pub groups: Vec<usize>,
    /// The words just before the run on its own line, lower-cased and bare —
    /// where a label («SIREN», «numéro fiscal :») stands.
    pub before: Vec<String>,
}

impl Run {
    /// Does one of `labels` stand in the few words before the run?
    pub fn labelled(&self, labels: &[&str]) -> bool {
        self.before.iter().any(|w| labels.contains(&w.as_str()))
    }

    pub fn grouped(&self, shapes: &[&[usize]]) -> bool {
        shapes.contains(&self.groups.as_slice())
    }
}

/// What a rule answers about a run it recognises.
pub(crate) struct Verdict {
    pub kind: Kind,
    pub confidence: Confidence,
    pub rule: &'static str,
    pub reason: String,
}

/// Can this word be part of a run at all?
fn runnable(word: &str, first: bool) -> bool {
    let b = bare(word);
    !b.is_empty()
        && !is_label(word)
        && b.chars().any(|c| c.is_ascii_alphanumeric())
        && b.char_indices().all(|(at, c)| {
            c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | '/') || (c == '+' && first && at == 0)
        })
}

/// Read every run in `words` with `rule`, longest first, and push what it
/// recognises as a candidate of `pack`.
pub(crate) fn read_runs(
    words: &[Word<'_>],
    pack: &LanguagePack,
    out: &mut Vec<Candidate>,
    rule: &dyn Fn(&Run) -> Option<Verdict>,
) {
    let mut i = 0usize;
    while i < words.len() {
        let mut matched = None;
        for length in (1..=LONGEST).rev() {
            let Some(run) = run_at(words, i, length) else { continue };
            if let Some(verdict) = rule(&run) {
                matched = Some((length, verdict));
                break;
            }
        }
        let Some((length, verdict)) = matched else {
            i += 1;
            continue;
        };
        let (Some(first), Some(last)) = (words.get(i), words.get(i + length - 1)) else { break };
        let (start, _) = bare_span(first);
        let (_, end) = bare_span(last);
        out.push(super::people::candidate(pack, start, end, verdict.kind, verdict.confidence, verdict.rule, verdict.reason));
        i += length;
    }
}

/// Where the bare word sits inside its raw one.
fn bare_span(word: &Word<'_>) -> (usize, usize) {
    let b = bare(word.text);
    let at = word.text.find(b).unwrap_or(0);
    (word.start + at, word.start + at + b.len())
}

fn run_at(words: &[Word<'_>], from: usize, length: usize) -> Option<Run> {
    let slice = words.get(from..from + length)?;
    let mut compact = String::new();
    let mut groups = Vec::new();
    for (k, word) in slice.iter().enumerate() {
        if k > 0 && (word.newline_before || word.page_break_before) {
            return None;
        }
        // A word that carries a full stop or a comma at its end closes the
        // run: «… 512 479 361. Le reste» is a number and then a sentence.
        if k + 1 < length && word.text.ends_with([',', ';', ':', '.', '!', '?', ')']) {
            return None;
        }
        if !runnable(word.text, k == 0) {
            return None;
        }
        for piece in bare(word.text).split(['.', '-', '/']) {
            if piece.is_empty() {
                continue;
            }
            groups.push(piece.chars().filter(char::is_ascii_alphanumeric).count());
            compact.push_str(piece);
        }
    }
    let first = slice.first()?;
    // The words before it on its line, nearest first — no further than four,
    // which is «N° de Sécurité sociale :» and no more.
    let mut before = Vec::new();
    let mut k = from;
    let mut on_line = !first.newline_before;
    while on_line && k > 0 && before.len() < 4 {
        k -= 1;
        let Some(prev) = words.get(k) else { break };
        let b = bare(prev.text).to_lowercase();
        if !b.is_empty() {
            before.push(b);
        }
        on_line = !prev.newline_before;
    }
    Some(Run { compact, groups, before })
}

// --------------------------------------------------------------- the checks

/// Digits only, and how many.
pub(crate) fn digits(s: &str, n: usize) -> bool {
    s.len() == n && s.bytes().all(|b| b.is_ascii_digit())
}

/// `n mod 97` over a run of decimal digits of any length.
pub(crate) fn mod97(s: &str) -> Option<u32> {
    let mut r = 0u32;
    for b in s.bytes() {
        if !b.is_ascii_digit() {
            return None;
        }
        r = (r * 10 + u32::from(b - b'0')) % 97;
    }
    Some(r)
}

pub(crate) use crate::scanner::general_rules::luhn_ok;

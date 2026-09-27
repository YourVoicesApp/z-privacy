//! The scanner: it finds, it does not protect.
//!
//! Two rules from the owner shape this module:
//!
//! * **It produces findings, never a payload.** Protection goes through the same
//!   token engine as a selection made by hand — there is no second path to
//!   hiding something, so there is no second place for a bug to live.
//! * **One value, one finding.** When a general rule and a language pack see the
//!   same thing, the result is one finding that names both, not two overlapping
//!   protections.

pub(crate) mod general_rules;
pub(crate) mod packs;

use crate::api::{Kind, Source};

/// How sure the scanner is — and therefore whether it may act alone.
///
/// `Auto` means «this cannot reasonably be anything else» (an IBAN that passes
/// its checksum). Everything a person would have to look at twice is `Suggest`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Confidence {
    Auto,
    Suggest,
}

/// One thing the scanner found, with everything needed to say **why**.
#[derive(Debug, Clone)]
pub(crate) struct Candidate {
    /// Byte range in the original.
    pub start: usize,
    pub end: usize,
    pub kind: Kind,
    pub confidence: Confidence,
    pub source: Source,
    /// The rule or pack that saw it: `iban`, `phone-intl`, `de:salutation`…
    pub source_detail: String,
    /// A sentence a person can read, shown in the review list.
    pub reason: String,
}

impl Candidate {
    fn len(&self) -> usize {
        self.end.saturating_sub(self.start)
    }
}

/// Run every layer, then settle the overlaps into one finding each.
pub(crate) fn scan(text: &str, pack: &str) -> Vec<Candidate> {
    let mut all = general_rules::scan(text);
    all.extend(packs::scan(text, pack));
    settle(all)
}

/// One value, one finding.
///
/// Sorted so the winner comes first — highest confidence, then the longest span,
/// then the general rule before a pack (arithmetic before habit) — and anything
/// overlapping a kept finding is folded into it: its layer is added to the
/// reason, so the review list can still say that two layers agreed.
fn settle(mut all: Vec<Candidate>) -> Vec<Candidate> {
    all.sort_by(|a, b| {
        a.start
            .cmp(&b.start)
            .then_with(|| rank_confidence(a.confidence).cmp(&rank_confidence(b.confidence)))
            .then_with(|| b.len().cmp(&a.len()))
            .then_with(|| rank_source(a.source).cmp(&rank_source(b.source)))
    });

    let mut kept: Vec<Candidate> = Vec::with_capacity(all.len());
    for candidate in all {
        let clash = kept
            .iter_mut()
            .find(|k| candidate.start < k.end && k.start < candidate.end);
        match clash {
            Some(keeper) => {
                if keeper.kind == candidate.kind {
                    // The same thing, seen twice. Say so once — and two layers
                    // agreeing is itself a reason to be sure.
                    let also = format!("{} agreed as well", candidate.source_detail);
                    if !keeper.reason.contains(&also) {
                        keeper.reason = format!("{} · {}", keeper.reason, also);
                    }
                    if keeper.confidence == Confidence::Suggest && candidate.confidence == Confidence::Auto {
                        keeper.confidence = Confidence::Auto;
                    }
                }
                // A different kind overlapping a stronger finding is simply
                // superseded: a local-phone shape inside an IBAN is not an ally,
                // and saying it "agreed" would be a lie in the review list.
            }
            None => kept.push(candidate),
        }
    }
    kept.sort_by_key(|c| c.start);
    kept
}

fn rank_confidence(c: Confidence) -> u8 {
    match c {
        Confidence::Auto => 0,
        Confidence::Suggest => 1,
    }
}

fn rank_source(s: Source) -> u8 {
    match s {
        Source::GeneralRule => 0,
        Source::LanguagePack => 1,
        Source::Vault => 2,
        Source::Hand => 3,
    }
}

/// How many ordinary words are left — everything the scanner did not point at.
///
/// A plain, stated definition: whitespace-separated words that touch no finding.
/// The number is counted, never written down in the code; the golden fixture's
/// expected value lives in its test.
pub(crate) fn plain_word_count(text: &str, found: &[Candidate]) -> u32 {
    let mut count = 0u32;
    let mut index = 0usize;
    for word in text.split_whitespace() {
        // Find this word's position, walking forward so repeats are counted right.
        let at = match text.get(index..).and_then(|rest| rest.find(word)) {
            Some(offset) => index + offset,
            None => continue,
        };
        let end = at + word.len();
        index = end;
        if !found.iter().any(|c| c.start < end && at < c.end) {
            count = count.saturating_add(1);
        }
    }
    count
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_value_seen_by_two_layers_is_one_finding() {
        // "IBAN:" is a German-pack label, and the number itself passes the mod-97
        // check. Two layers, one thing — and the reason must name both.
        let text = "IBAN: DE89 3704 0044 0532 0130 00";
        let found = scan(text, "de");
        assert_eq!(found.len(), 1, "{found:?}");
        let only = found.first().expect("one");
        assert_eq!(only.confidence, Confidence::Auto);
        assert!(only.reason.contains("agreed as well"), "{}", only.reason);
    }

    #[test]
    fn plain_words_are_what_is_left() {
        let text = "Herr Thomas Müller hat die Nummer +49 171 2345678 genannt.";
        let found = scan(text, "de");
        let plain = plain_word_count(text, &found);
        let words = text.split_whitespace().count() as u32;
        assert!(plain < words, "some words are inside findings");
        assert!(plain > 0, "not every word is a finding");
    }
}

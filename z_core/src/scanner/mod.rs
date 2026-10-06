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
pub(crate) mod languages;
pub(crate) mod packs;
pub(crate) mod rules;
pub(crate) mod sets;

use std::collections::{BTreeMap, BTreeSet};

use crate::api::{Kind, Policy, Source};
use crate::text::nfc;
use crate::vault::model::{UserException, VaultHint};

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
    /// The vault identities that claim this text: none, one, or — when more than
    /// one — a conflict the app must ask about rather than settle silently.
    pub entities: Vec<String>,
    /// Other layers that saw the same thing and called it the same kind.
    ///
    /// Kept as a list and not only folded into `reason`, because «two rules
    /// agree» is an answer to «why is this protected?» and an answer should not
    /// have to be parsed out of a sentence. (Task 036.)
    pub also: Vec<String>,
}

impl Candidate {
    fn len(&self) -> usize {
        self.end.saturating_sub(self.start)
    }
}

/// Run every layer, then settle the overlaps into one finding each.
///
/// `hints` is what the vault can recognise **for the active profile**, and it is
/// empty while the vault is locked — which is how «locked means the layer does not
/// exist» is true without a flag anywhere.
/// `active` is every rule set switched on for this profile — one document may
/// be German and English at once, and both are asked in the same pass.
/// `taught` is what the person themself added; it reaches the same engine as a
/// built-in row, because a rule is a rule whoever wrote it.
pub(crate) fn scan(
    text: &str,
    active: &[String],
    taught: &[rules::LabelRule],
    hints: &[VaultHint],
    exceptions: &[UserException],
    names: &[(String, bool)],
) -> Vec<Candidate> {
    let mut all = general_rules::scan(text);
    for id in active {
        all.extend(packs::scan(text, id, names));
    }
    let mut label_rules = sets::rules_for(active);
    label_rules.extend(taught.iter().cloned());
    all.extend(rules::scan_with(text, &label_rules, &sets::honorifics_for(active)));
    all.extend(vault_pass(text, hints));
    all.retain(|candidate| !excepted(text, candidate, exceptions));
    settle(all)
}

fn excepted(text: &str, candidate: &Candidate, exceptions: &[UserException]) -> bool {
    let Some(found) = text.get(candidate.start..candidate.end) else {
        return false;
    };
    exceptions.iter().any(|ex| ex.matches(candidate.kind, found))
}

/// What the vault itself recognises. This is the only layer that knows *who*.
fn vault_pass(text: &str, hints: &[VaultHint]) -> Vec<Candidate> {
    // Group by spelling, so that one text claimed by two identities is seen as
    // the conflict it is instead of becoming two overlapping protections.
    let mut by_spelling: BTreeMap<String, Vec<&VaultHint>> = BTreeMap::new();
    for hint in hints {
        by_spelling.entry(nfc(&hint.text)).or_default().push(hint);
    }

    let mut out = Vec::new();
    for group in by_spelling.values() {
        let Some(first) = group.first() else { continue };
        let claimants: BTreeSet<String> = group.iter().map(|h| h.entity_handle.clone()).collect();
        let entities: Vec<String> = claimants.iter().cloned().collect();
        let conflict = entities.len() > 1;

        let confidence = if conflict {
            // The owner's third rule: never choose silently.
            Confidence::Suggest
        } else {
            match first.policy {
                Policy::Always => Confidence::Auto,
                Policy::Suggest => Confidence::Suggest,
                // Kept in the vault so its aliases and token stay stable, but
                // never found by itself.
                Policy::Manual => continue,
            }
        };
        // Neither the handle («CLIENT #01») nor the label. The owner's ruling
        // of 29 September: the identity's name is needed where a person picks
        // or manages one — not repeated in an explanation merely because we
        // hold it. `CLIENT #01` said nothing to a human; the label is the
        // client's own name and is exactly what the vault protects.
        let reason = if conflict {
            "two identities in your vault claim this spelling — the app will not choose for you"
                .to_string()
        } else {
            "your vault knows this value".to_string()
        };
        let detail = if conflict {
            "vault:conflict".to_string()
        } else {
            format!("vault:{}", first.entity_handle)
        };

        for (start, end) in crate::text::occurrences(text, &first.text) {
            out.push(Candidate {
                start,
                end,
                kind: first.kind,
                confidence,
                source: Source::Vault,
                source_detail: detail.clone(),
                reason: reason.clone(),
                entities: entities.clone(),
                also: Vec::new(),
            });
        }
    }
    out
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
                // Whoever wins, the identities that claimed this text are kept:
                // the review list must be able to name them.
                for entity in &candidate.entities {
                    if !keeper.entities.contains(entity) {
                        keeper.entities.push(entity.clone());
                    }
                }
                if keeper.kind == candidate.kind {
                    // The same thing, seen twice. Say so once — and two layers
                    // agreeing is itself a reason to be sure.
                    let also = format!("{} agreed as well", candidate.source_detail);
                    if !keeper.reason.contains(&also) {
                        keeper.reason = format!("{} · {}", keeper.reason, also);
                    }
                    if !keeper.also.contains(&candidate.source_detail) {
                        keeper.also.push(candidate.source_detail.clone());
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

/// Arithmetic first, then the vault (it knows *who*), then the language's habits.
fn rank_source(s: Source) -> u8 {
    match s {
        Source::GeneralRule => 0,
        Source::Vault => 1,
        Source::LanguagePack => 2,
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
        let found = scan(text, &["de".to_string()], &[], &[], &[], &[]);
        assert_eq!(found.len(), 1, "{found:?}");
        let only = found.first().expect("one");
        assert_eq!(only.confidence, Confidence::Auto);
        assert!(only.reason.contains("agreed as well"), "{}", only.reason);
    }

    #[test]
    fn plain_words_are_what_is_left() {
        let text = "Herr Thomas Müller hat die Nummer +49 171 2345678 genannt.";
        let found = scan(text, &["de".to_string()], &[], &[], &[], &[]);
        let plain = plain_word_count(text, &found);
        let words = text.split_whitespace().count() as u32;
        assert!(plain < words, "some words are inside findings");
        assert!(plain > 0, "not every word is a finding");
    }
}

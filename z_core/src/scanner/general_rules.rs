//! What can be found without understanding a single word of the language.
//!
//! These rules look at shape, and where they can, at arithmetic. An IBAN is
//! checked against its own checksum, so calling it an IBAN is not a guess. That
//! is what earns [`Confidence::Auto`] here: not «probably», but «this cannot
//! reasonably be anything else».
//!
//! Anything that a person would have to look at twice stays
//! [`Confidence::Suggest`]. The owner's rule for M3: never raise the catch rate
//! at the cost of a false positive.

use crate::api::{Kind, Source};

use super::{Candidate, Confidence};

/// Every general rule, over the whole text.
pub(crate) fn scan(text: &str) -> Vec<Candidate> {
    let mut out = Vec::new();
    ibans(text, &mut out);
    emails(text, &mut out);
    phones(text, &mut out);
    out
}

fn candidate(
    start: usize,
    end: usize,
    kind: Kind,
    confidence: Confidence,
    rule: &str,
    reason: &str,
) -> Candidate {
    Candidate {
        start,
        end,
        kind,
        confidence,
        source: Source::GeneralRule,
        source_detail: rule.to_string(),
        reason: reason.to_string(),
    }
}

fn is_word_byte(b: u8) -> bool {
    b.is_ascii_alphanumeric()
}

/// True when `at` is not in the middle of a word — so `DE12…` inside
/// `XYDE12…` is not read as an IBAN.
fn boundary_before(bytes: &[u8], at: usize) -> bool {
    match at.checked_sub(1).and_then(|i| bytes.get(i)) {
        Some(b) => !is_word_byte(*b),
        None => true,
    }
}

fn boundary_after(bytes: &[u8], at: usize) -> bool {
    match bytes.get(at) {
        Some(b) => !is_word_byte(*b),
        None => true,
    }
}

// ---------------------------------------------------------------- IBAN

/// An IBAN, proven by its own mod-97 checksum.
///
/// The groups of an IBAN are uppercase letters and digits separated by single
/// spaces, so the run stops by itself at the next ordinary word — «… 0130 00 ist
/// das Konto» ends at `00`. Then the longest group boundary that passes the
/// checksum wins, which is why a valid IBAN followed by a number is not read as
/// one long broken one.
fn ibans(text: &str, out: &mut Vec<Candidate>) {
    let bytes = text.as_bytes();
    let mut i = 0usize;
    while i + 4 <= bytes.len() {
        let two_letters = bytes
            .get(i)
            .zip(bytes.get(i + 1))
            .is_some_and(|(a, b)| a.is_ascii_uppercase() && b.is_ascii_uppercase());
        let two_digits = bytes
            .get(i + 2)
            .zip(bytes.get(i + 3))
            .is_some_and(|(a, b)| a.is_ascii_digit() && b.is_ascii_digit());
        if !(two_letters && two_digits && boundary_before(bytes, i)) {
            i += 1;
            continue;
        }

        // Collect the groups: uppercase alnum runs joined by single spaces.
        let mut groups: Vec<(usize, usize)> = Vec::new();
        let mut at = i;
        loop {
            let group_start = at;
            while bytes
                .get(at)
                .is_some_and(|b| b.is_ascii_digit() || b.is_ascii_uppercase())
            {
                at += 1;
            }
            if at == group_start {
                break;
            }
            groups.push((group_start, at));
            let next_is_group = bytes.get(at) == Some(&b' ')
                && bytes
                    .get(at + 1)
                    .is_some_and(|b| b.is_ascii_digit() || b.is_ascii_uppercase());
            if next_is_group {
                at += 1;
            } else {
                break;
            }
        }

        let mut matched = None;
        for take in (1..=groups.len()).rev() {
            let Some((_, group_end)) = groups.get(take - 1) else { continue };
            let end = *group_end;
            let slice = text.get(i..end).unwrap_or_default();
            let compact: String = slice.chars().filter(|c| !c.is_whitespace()).collect();
            if (15..=34).contains(&compact.len())
                && boundary_after(bytes, end)
                && iban_checksum_ok(&compact)
            {
                matched = Some(end);
                break;
            }
        }
        match matched {
            Some(end) => {
                out.push(candidate(
                    i,
                    end,
                    Kind::Iban,
                    Confidence::Auto,
                    "iban",
                    "an IBAN: the country, the length and its own mod-97 checksum all agree",
                ));
                i = end;
            }
            None => i += 1,
        }
    }
}

/// ISO 7064 mod-97-10: move the first four characters to the end, letters become
/// numbers, the whole thing modulo 97 must be 1.
fn iban_checksum_ok(compact: &str) -> bool {
    if compact.len() < 5 {
        return false;
    }
    let (head, tail) = compact.split_at(4);
    let mut remainder: u32 = 0;
    for ch in tail.chars().chain(head.chars()) {
        let value = match ch {
            '0'..='9' => ch as u32 - '0' as u32,
            'A'..='Z' => ch as u32 - 'A' as u32 + 10,
            _ => return false,
        };
        // Two digits at a time for letters, one for digits.
        remainder = if value > 9 {
            (remainder * 100 + value) % 97
        } else {
            (remainder * 10 + value) % 97
        };
    }
    remainder == 1
}

// ---------------------------------------------------------------- e-mail

/// An address: something, an `@`, a domain with a dot and a real ending.
fn emails(text: &str, out: &mut Vec<Candidate>) {
    let bytes = text.as_bytes();
    for (at, _) in text.char_indices().filter(|(_, c)| *c == '@') {
        // Left: the local part.
        let mut start = at;
        while let Some(prev) = start.checked_sub(1) {
            match bytes.get(prev) {
                Some(b) if b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'%' | b'+' | b'-') => {
                    start = prev;
                }
                _ => break,
            }
        }
        // Right: the domain.
        let mut end = at + 1;
        while let Some(b) = bytes.get(end) {
            if b.is_ascii_alphanumeric() || matches!(b, b'.' | b'-') {
                end += 1;
            } else {
                break;
            }
        }
        // Trim a trailing dot: "an@example.com." ends a sentence.
        while end > at + 1 && bytes.get(end - 1) == Some(&b'.') {
            end -= 1;
        }
        if start == at || end <= at + 1 {
            continue;
        }
        let domain = text.get(at + 1..end).unwrap_or_default();
        let tld_ok = domain
            .rsplit_once('.')
            .is_some_and(|(_, tld)| tld.len() >= 2 && tld.chars().all(|c| c.is_ascii_alphabetic()));
        if tld_ok {
            out.push(candidate(
                start,
                end,
                Kind::Email,
                Confidence::Auto,
                "email",
                "an e-mail address: a local part, an @, and a domain with a real ending",
            ));
        }
    }
}

// ---------------------------------------------------------------- phone

/// A number in international form is unmistakable; a local one is a suggestion,
/// because an order number can look exactly like it.
fn phones(text: &str, out: &mut Vec<Candidate>) {
    let bytes = text.as_bytes();
    let mut i = 0usize;
    while i < bytes.len() {
        let starts_intl = bytes.get(i) == Some(&b'+') && bytes.get(i + 1).is_some_and(|b| b.is_ascii_digit());
        let starts_local = bytes.get(i) == Some(&b'0')
            && bytes.get(i + 1).is_some_and(|b| b.is_ascii_digit())
            && boundary_before(bytes, i);
        if !(starts_intl || starts_local) {
            i += 1;
            continue;
        }
        let mut end = i + 1;
        let mut digits = 0usize;
        let mut last_digit_end = i + 1;
        while let Some(b) = bytes.get(end) {
            if b.is_ascii_digit() {
                digits += 1;
                end += 1;
                last_digit_end = end;
            } else if matches!(b, b' ' | b'-' | b'/' | b'(' | b')' | b'.')
                && bytes.get(end + 1).is_some_and(|n| n.is_ascii_digit())
            {
                end += 1;
            } else {
                break;
            }
        }
        if starts_intl {
            digits += 0; // the '+' carries no digit
        } else {
            digits += 1; // the leading 0
        }
        if (8..=15).contains(&digits) && boundary_after(bytes, last_digit_end) {
            if starts_intl {
                out.push(candidate(
                    i,
                    last_digit_end,
                    Kind::Phone,
                    Confidence::Auto,
                    "phone-intl",
                    "a telephone number in international form (+…), which nothing else looks like",
                ));
            } else {
                out.push(candidate(
                    i,
                    last_digit_end,
                    Kind::Phone,
                    Confidence::Suggest,
                    "phone-local",
                    "a number in local telephone form — but an order or invoice number can look the same, so your word decides",
                ));
            }
            i = last_digit_end;
            continue;
        }
        i += 1;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn found(text: &str) -> Vec<(Kind, Confidence, String)> {
        scan(text)
            .into_iter()
            .map(|c| (c.kind, c.confidence, text.get(c.start..c.end).unwrap_or_default().to_string()))
            .collect()
    }

    #[test]
    fn an_iban_is_proven_not_guessed() {
        // A real-shaped German IBAN with a correct checksum.
        let good = "IBAN: DE89 3704 0044 0532 0130 00 ist das Konto.";
        // This module reports what each rule saw; the digits inside an IBAN also
        // look like a local telephone number, and settling that overlap into one
        // finding is the scanner's job (see scanner::tests).
        assert!(
            found(good).contains(&(
                Kind::Iban,
                Confidence::Auto,
                "DE89 3704 0044 0532 0130 00".to_string()
            )),
            "{:?}",
            found(good)
        );

        // One digit changed: the checksum fails, so we do not call it an IBAN.
        let bad = "IBAN: DE89 3704 0044 0532 0130 01 ist das Konto.";
        assert!(
            !found(bad).iter().any(|(k, _, _)| *k == Kind::Iban),
            "a failing checksum must not be called an IBAN: {:?}",
            found(bad)
        );
    }

    #[test]
    fn an_iban_inside_a_longer_word_is_not_an_iban() {
        let text = "XXDE89370400440532013000 und DE89 3704 0044 0532 0130 00";
        let ibans: Vec<_> = found(text).into_iter().filter(|(k, _, _)| *k == Kind::Iban).collect();
        assert_eq!(ibans.len(), 1, "{ibans:?}");
    }

    #[test]
    fn an_email_needs_a_real_ending() {
        assert_eq!(
            found("Schreiben an t.mueller@nordstern-consulting.de."),
            vec![(
                Kind::Email,
                Confidence::Auto,
                "t.mueller@nordstern-consulting.de".to_string()
            )]
        );
        assert!(found("a@b").is_empty());
        assert!(found("@nordstern.de").is_empty(), "a mention is not an address");
    }

    #[test]
    fn an_international_number_is_certain_a_local_one_is_a_question() {
        assert_eq!(
            found("Telefon: +49 171 2345678"),
            vec![(Kind::Phone, Confidence::Auto, "+49 171 2345678".to_string())]
        );
        assert_eq!(
            found("Telefon: 0171 2345678"),
            vec![(Kind::Phone, Confidence::Suggest, "0171 2345678".to_string())]
        );
        // Too short to be a telephone number, so nothing is claimed.
        assert!(found("Zimmer 0171").is_empty());
    }

    #[test]
    fn every_candidate_says_why() {
        for c in scan("t.mueller@nordstern.de +49 171 2345678 DE89 3704 0044 0532 0130 00") {
            assert!(!c.reason.is_empty(), "a finding with no reason is not allowed");
            assert!(!c.source_detail.is_empty(), "the rule must name itself");
        }
    }
}

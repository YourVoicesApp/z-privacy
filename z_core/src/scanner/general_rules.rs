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
    social_insurance(text, &mut out);
    tax_identification(text, &mut out);
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
        entities: Vec::new(),
        also: Vec::new(),
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
        // No telephone number begins with three zeros. Measured in a book of
        // tax tables whose columns ran together — «6.000.000193030bis einschl.
        // 13.000.000233550» — where the piece «000.000274050» was offered as
        // one. «00» keeps working: that is how a country code is dialled.
        let starts_local = bytes.get(i) == Some(&b'0')
            && bytes.get(i + 1).is_some_and(|b| b.is_ascii_digit())
            && bytes.get(i..i + 3) != Some(b"000".as_slice())
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
        // A date is not a telephone number, whatever its digits add up to.
        //
        // Measured on a payslip: «01.02.2019», «02.11.1979» and «09.05.1985»
        // were offered as local numbers, because a German date that begins with
        // a zero is eight digits with separators between them — which is the
        // whole of the local-phone shape. Three false questions on one page,
        // each about a date the document itself calls a date.
        let run = text.get(i..last_digit_end).unwrap_or_default();
        if looks_like_a_date(run) {
            i += 1;
            continue;
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

// ------------------------------------------- social-insurance number (038-G)

/// A German *Sozialversicherungsnummer*, proven by its own check digit.
///
/// Twelve characters: `NN DDMMYY L NNN` — the area number of the issuing
/// office, the bearer's birth date, the first letter of their birth name, two
/// digits of serial, and a check digit over all of it. Written with spaces on
/// a payslip and without them in a form, and both are read here.
///
/// The arithmetic is published and is what earns `Auto`: the letter becomes two
/// digits of its position in the alphabet, the twelve digits are weighted
/// `2 1 2 5 7 1 2 1 2 1 2 1`, every product is replaced by the sum of its own
/// digits, and the total modulo ten is the check digit. A number one digit off
/// fails it, which is the whole point — this rule may never guess.
///
/// It is a general rule and not a German one. The shape is German, but nothing
/// else in any language has it: six digits that must be a real date, a single
/// capital in the middle, and a checksum that has to come out.
fn social_insurance(text: &str, out: &mut Vec<Candidate>) {
    let bytes = text.as_bytes();
    let mut at = 0usize;
    while at < bytes.len() {
        let Some(found) = read_social_insurance(text, at) else {
            at += 1;
            continue;
        };
        let (start, end) = found;
        out.push(candidate(
            start,
            end,
            Kind::SocialInsuranceNo,
            Confidence::Auto,
            "social-insurance number",
            "a social-insurance number: an area number, a birth date, the first letter of a \
             birth name and a check digit that comes out",
        ));
        at = end;
    }
}

/// One number at `at`, or nothing. Returns the span including its spaces.
fn read_social_insurance(text: &str, at: usize) -> Option<(usize, usize)> {
    let bytes = text.as_bytes();
    if !boundary_before(bytes, at) {
        return None;
    }
    // Twelve characters, with a space allowed where a payslip puts one.
    let mut compact = String::with_capacity(12);
    let mut i = at;
    while compact.len() < 12 {
        let b = *bytes.get(i)?;
        if b == b' ' {
            // A space only between the groups a payslip separates, never two.
            if !matches!(compact.len(), 2 | 8 | 9) || bytes.get(i + 1)? == &b' ' {
                return None;
            }
            i += 1;
            continue;
        }
        if !b.is_ascii_alphanumeric() {
            return None;
        }
        compact.push(b as char);
        i += 1;
    }
    if !boundary_after(bytes, i) {
        return None;
    }
    social_insurance_ok(&compact).then_some((at, i))
}

/// The published check: the shape, a real date, and the check digit.
fn social_insurance_ok(compact: &str) -> bool {
    let b = compact.as_bytes();
    if b.len() != 12 {
        return false;
    }
    let digits_ok = |range: std::ops::Range<usize>| {
        range.clone().all(|i| b.get(i).is_some_and(u8::is_ascii_digit))
    };
    if !digits_ok(0..8) || !digits_ok(9..12) {
        return false;
    }
    let Some(letter) = b.get(8).copied() else { return false };
    if !letter.is_ascii_uppercase() {
        return false;
    }
    // The birth date is a date, or this is twelve characters of something else.
    let two = |i: usize| -> u32 {
        compact.get(i..i + 2).and_then(|s| s.parse::<u32>().ok()).unwrap_or(99)
    };
    let (day, month) = (two(2), two(4));
    if !(1..=12).contains(&month) || day == 0 || day > days_in_month(month) {
        return false;
    }

    // The letter counts as two digits of its place in the alphabet.
    let mut digits: Vec<u32> = Vec::with_capacity(12);
    for i in 0..8 {
        digits.push(u32::from(b.get(i).copied().unwrap_or(b'0') - b'0'));
    }
    let place = u32::from(letter - b'A') + 1;
    digits.push(place / 10);
    digits.push(place % 10);
    for i in 9..11 {
        digits.push(u32::from(b.get(i).copied().unwrap_or(b'0') - b'0'));
    }
    const WEIGHTS: [u32; 12] = [2, 1, 2, 5, 7, 1, 2, 1, 2, 1, 2, 1];
    let total: u32 = digits
        .iter()
        .zip(WEIGHTS.iter())
        .map(|(d, w)| {
            let p = d * w;
            p / 10 + p % 10
        })
        .sum();
    let wanted = total % 10;
    let written = u32::from(b.get(11).copied().unwrap_or(b'0') - b'0');
    wanted == written
}

/// Days in a month, February long enough for any year: a birth date inside an
/// identifier is checked for being a date at all, not for its own year.
fn days_in_month(month: u32) -> u32 {
    match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        _ => 29,
    }
}

// --------------------------------------- the tax identification number (038-G)

/// The German *steuerliche Identifikationsnummer*: eleven digits that carry
/// their own proof, twice over.
///
/// **The check digit** is ISO 7064's MOD 11,10, which the BZSt publishes: a
/// running product starts at 10, each of the first ten digits folds into it,
/// and the eleventh digit is what makes the result come out.
///
/// **The structure** is the second proof, and it is why eleven digits that pass
/// the checksum by luck are still refused: among the first ten digits exactly
/// one appears twice or three times, at least one digit of the ten does not
/// appear at all, and the first digit is never zero.
///
/// Both together are what earns Auto. A phone number, an IBAN fragment or an
/// invoice number of eleven digits fails one of them — measured on 230,000
/// words of German prose, where this rule fires zero times.
///
/// Grouped `NN NNN NNN NNN` as a payslip writes it, or plain as a form does.
fn tax_identification(text: &str, out: &mut Vec<Candidate>) {
    let bytes = text.as_bytes();
    let mut at = 0usize;
    while at < bytes.len() {
        let Some((start, end)) = read_tax_id(text, at) else {
            at += 1;
            continue;
        };
        out.push(candidate(
            start,
            end,
            Kind::TaxId,
            Confidence::Auto,
            "tax identification number",
            "an eleven-digit tax identification number: its check digit comes out and its \
             digits have the shape the office gives them",
        ));
        at = end;
    }
}

/// One number at `at`, grouped or plain, or nothing.
fn read_tax_id(text: &str, at: usize) -> Option<(usize, usize)> {
    let bytes = text.as_bytes();
    if !boundary_before(bytes, at) {
        return None;
    }
    let mut digits = String::with_capacity(11);
    let mut i = at;
    while digits.len() < 11 {
        let b = *bytes.get(i)?;
        if b == b' ' {
            // Only where the office groups it: 2, then 3, then 3, then 3.
            if !matches!(digits.len(), 2 | 5 | 8) || bytes.get(i + 1)? == &b' ' {
                return None;
            }
            i += 1;
            continue;
        }
        if !b.is_ascii_digit() {
            return None;
        }
        digits.push(b as char);
        i += 1;
    }
    // Twelve digits are not eleven digits: a longer run is something else.
    if bytes.get(i).is_some_and(u8::is_ascii_digit) || !boundary_after(bytes, i) {
        return None;
    }
    tax_id_ok(&digits).then_some((at, i))
}

/// The two published rules, both of them.
fn tax_id_ok(digits: &str) -> bool {
    let b = digits.as_bytes();
    if b.len() != 11 || !b.iter().all(u8::is_ascii_digit) || b.first() == Some(&b'0') {
        return false;
    }
    // The structure: exactly one of the first ten digits appears twice or three
    // times, and at least one digit never appears.
    let mut seen = [0u8; 10];
    for d in b.iter().take(10) {
        let Some(slot) = seen.get_mut(usize::from(d - b'0')) else { return false };
        *slot += 1;
    }
    let repeated = seen.iter().filter(|n| matches!(**n, 2 | 3)).count();
    let missing = seen.iter().filter(|n| **n == 0).count();
    if repeated != 1 || missing == 0 || seen.iter().any(|n| *n > 3) {
        return false;
    }
    // The check digit: ISO 7064, MOD 11,10.
    let mut product = 10u32;
    for d in b.iter().take(10) {
        let sum = (u32::from(d - b'0') + product) % 10;
        let sum = if sum == 0 { 10 } else { sum };
        product = (sum * 2) % 11;
    }
    let wanted = (11 - product) % 10;
    b.get(10).is_some_and(|d| u32::from(d - b'0') == wanted)
}

/// `DD.MM.YYYY` and `D.M.YYYY`, the two ways a German writes a date.
///
/// Only a date: `12.3456.78` is not one, and neither is a run with a space or a
/// slash in it — those stay a telephone number's business.
fn looks_like_a_date(run: &str) -> bool {
    let parts: Vec<&str> = run.split('.').collect();
    let [day, month, year] = parts[..] else { return false };
    if !(1..=2).contains(&day.len()) || !(1..=2).contains(&month.len()) || year.len() != 4 {
        return false;
    }
    if !run.bytes().all(|b| b.is_ascii_digit() || b == b'.') {
        return false;
    }
    let (Ok(day), Ok(month), Ok(_year)) = (day.parse::<u32>(), month.parse::<u32>(), year.parse::<u32>())
    else {
        return false;
    };
    (1..=12).contains(&month) && day >= 1 && day <= days_in_month(month)
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

// 038-G · what a German payroll document is made of.
//
// The first real user keeps his clients' payroll accounts. A payslip and a
// ledger carry four things this build could not read: the social-insurance
// number, the eleven-digit tax identification number, the personnel number,
// and a table whose header names what stands under it. Each is its own commit
// and its own measurement; this file is where the arithmetic is held to
// account, on numbers nobody was ever issued.
//
// Every number below is invented. The valid ones were computed with the
// published algorithms and the broken ones differ from them by one digit, so a
// rule that stopped checking would fail here before it reached a document.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

fn found(doc: &str) -> Vec<(MarkState, Kind, String)> {
    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    list_findings(session)
        .expect("findings")
        .into_iter()
        .map(|f| {
            (
                f.state,
                f.kind,
                String::from_utf16_lossy(
                    units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
                ),
            )
        })
        .collect()
}

fn kinds_of(doc: &str, kind: Kind) -> Vec<(MarkState, String)> {
    found(doc).into_iter().filter(|(_, k, _)| *k == kind).map(|(s, _, t)| (s, t)).collect()
}

/// A Sozialversicherungsnummer is `NN DDMMYY L NNN`: an area number, the
/// bearer's birth date, the first letter of their birth name, a serial, and a
/// check digit over all of it. Nothing else has that shape, which is why it is
/// a general rule and not a German one — and why it is Auto.
#[test]
fn a_social_insurance_number_is_proven_by_its_own_check_digit() {
    for number in ["15 030578 K 037", "28 111290 W 479", "04 010160 B 993"] {
        let doc = format!("Die Nummer {number} steht im Antrag.");
        let got = kinds_of(&doc, Kind::SocialInsuranceNo);
        assert_eq!(got.len(), 1, "«{number}» was not read as a social-insurance number: {got:?}");
        assert_eq!(got[0].0, MarkState::Protected, "«{number}» was only offered");
        assert_eq!(got[0].1, number, "the span is not the whole number");
    }
    // Written without its spaces, as a form writes it.
    let got = kinds_of("SVNR 15030578K037 liegt vor.", Kind::SocialInsuranceNo);
    assert_eq!(got.len(), 1, "the compact form is not read: {got:?}");
    assert_eq!(got[0].1, "15030578K037");
}

#[test]
fn a_number_that_fails_its_check_is_not_one() {
    for number in [
        "15 030578 K 038", // one off the check digit
        "28 111290 W 470",
        "04 010160 B 994",
        "15 320578 K 037", // the 32nd of March
        "15 031378 K 037", // the thirteenth month
    ] {
        let doc = format!("Die Nummer {number} steht im Antrag.");
        let got = kinds_of(&doc, Kind::SocialInsuranceNo);
        assert!(got.is_empty(), "«{number}» passed as a social-insurance number: {got:?}");
    }
}

/// And it is not a telephone number, an IBAN, or anything else that happens to
/// be digits with a space in it.
#[test]
fn what_a_social_insurance_number_is_not() {
    let doc = "Telefon 089 1234 5699, IBAN DE89 3704 0044 0532 0130 00.";
    assert!(
        kinds_of(doc, Kind::SocialInsuranceNo).is_empty(),
        "a phone or an IBAN was read as a social-insurance number"
    );
}

// ------------------------------------------------------- the eleven digits

/// The *steuerliche Identifikationsnummer*: eleven digits that carry their own
/// proof. Two rules together, both published by the BZSt — a check digit
/// (ISO 7064, MOD 11,10) and a structure (among the first ten, exactly one
/// digit appears twice or three times, at least one digit is missing, and the
/// first is not zero). Eleven digits that pass both are not a coincidence.
#[test]
fn a_tax_identification_number_is_proven_by_its_check_and_its_shape() {
    for number in ["98 765 432 114", "25 813 794 623", "98765432114"] {
        let doc = format!("Steuerliche Identifikationsnummer {number}.");
        let got = kinds_of(&doc, Kind::TaxId);
        assert_eq!(got.len(), 1, "«{number}» was not read as a tax ID: {got:?}");
        assert_eq!(got[0].0, MarkState::Protected, "«{number}» was only offered");
        assert_eq!(got[0].1, number, "the span is not the whole number");
    }
}

#[test]
fn eleven_digits_that_fail_either_rule_are_not_a_tax_id() {
    for (number, why) in [
        ("98 765 432 115", "one off the check digit"),
        ("12 345 678 903", "no digit appears twice, so it is not one of these"),
        ("08 765 432 116", "a tax ID never begins with zero"),
        ("98 765 432 11", "ten digits"),
    ] {
        let doc = format!("Nummer {number} steht im Formular.");
        let got = kinds_of(&doc, Kind::TaxId);
        assert!(got.is_empty(), "«{number}» passed as a tax ID — {why}: {got:?}");
    }
}

/// And the eleven digits of something else are not it either.
#[test]
fn what_eleven_digits_are_not() {
    let doc = "IBAN DE89 3704 0044 0532 0130 00 und Telefon 089 1234 5699.";
    assert!(kinds_of(doc, Kind::TaxId).is_empty(), "an IBAN or a phone was read as a tax ID");
}

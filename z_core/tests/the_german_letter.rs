// The letter the owner wrote to try the scanner, and what it leaves behind.
//
// His words on 3 October: «it did not hide the names, it gave me 14 choices,
// and when I had answered them it went through. Not one of the seven people
// was encrypted.» The measurement said worse: after answering every one of the
// fourteen, what would have left the machine still carried his own name three
// times, his date of birth, his identity card number, his vehicle plate, his
// customer number twice and his tax number.
//
// Every value in the fixture is invented by its author.
//
// This file is the guard that was missing: not «how many were found», but
// **what is still in the clear when the person has done everything the app
// asked of them**.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const LETTER: &str = include_str!("fixtures/Brief_Weber.txt");

/// Import, scan, answer every suggestion the way a person would, and hand back
/// the text that would actually leave.
fn what_would_leave() -> (ScanReport, String) {
    let session = open_session(None, "de".to_string()).expect("session");
    import_text(session, LETTER.to_string()).expect("import");
    let report = scan(session).expect("scan");
    for finding in list_findings(session).expect("findings") {
        if finding.state == MarkState::Suggested {
            answer_finding(session, finding.id, FindingAnswer::Protect).expect("answer");
        }
    }
    let handle = build_payload(session).expect("payload");
    let text = payload_view(handle).expect("view").text;
    (report, text)
}

#[test]
fn nothing_of_his_own_is_left_in_the_clear() {
    let (_, safe) = what_would_leave();
    for value in [
        "Markus Weber",
        "27.11.1979",
        "L01X00T47",
        "A-MW 2041",
        "7733-9120",
        "143/815/08154",
        "DE123456789",
    ] {
        assert!(
            !safe.contains(value),
            "«{value}» would have left the machine after every question was answered"
        );
    }
}

/// And the people are protected without being asked about: a salutation is
/// proof enough, which is the owner's ruling of 3 October.
#[test]
fn the_people_are_protected_without_being_asked() {
    let (report, safe) = what_would_leave();
    for name in [
        "Katharina Lindemann",
        "Tobias Reinhardt",
        "Amira Haddad",
        "Jonas Petersen",
        "Sophie Brandt",
        "Yusuf Demir",
        "Markus Weber",
    ] {
        assert!(!safe.contains(name), "«{name}» is still in the clear");
    }
    assert!(
        report.auto >= 12,
        "the seven people and the five shapes should be protected before anyone is asked: {report:?}"
    );
}

/// The salutation itself stays, so the model can still write a German reply —
/// and the company keeps its whole name, because the name is the identifier.
#[test]
fn the_salutation_stays_and_the_company_is_whole() {
    let (_, safe) = what_would_leave();
    assert!(safe.contains("Sehr geehrte Frau "), "the salutation was taken with the name");
    assert!(safe.contains("Herr "), "«Herr» is not a secret");
    assert!(
        !safe.contains("Lindemann &"),
        "the company's name starts before «&», and the whole of it is the identifier"
    );
    assert!(!safe.contains("Weber Elektrotechnik"), "the company name is still in the clear");
}

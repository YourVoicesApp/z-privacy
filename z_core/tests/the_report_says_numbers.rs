// The report a person copies when something is wrong.
//
// Its whole promise is negative: a tester in another country can send us this
// instead of the document, and it must be safe to paste into an e-mail, an
// issue, a chat. So the test is written the same way — not «does it contain the
// numbers» alone, but «does it contain nothing else».
//
// The letter is the right file to hold it to: it is nothing but values. Seven
// people, a date of birth, an identity card, a plate, a tax number, a customer
// number, three addresses, two companies, an invoice number. If a report can
// leak, it leaks here.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use z_core::api::*;

fn letter() -> Vec<u8> {
    std::fs::read(concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/Brief_Weber.txt")).expect("the letter")
}

#[test]
fn the_report_carries_the_numbers_and_none_of_the_words() {
    let session = open_session(None, "de".to_string()).expect("open");
    import_document(session, "/home/anas/Dokumente/Brief_Weber.txt".to_string(), letter(), DocumentKind::Txt)
        .expect("import");
    let report = scan(session).expect("scan");
    let text = import_report(ReportSubject::Imported { session }).expect("report");

    // The numbers are there, and they are the core's own.
    // The extension and not the name: a file name carries the client's.
    assert!(text.contains("file        .txt"), "{text}");
    assert!(!text.contains("Brief_Weber"), "the report is named after the person: {text}");
    assert!(text.contains(&format!("protected   {:<5}", report.auto)), "{text}");
    assert!(text.contains(&format!("waiting     {:<5}", report.suggested)), "{text}");
    assert!(text.contains("readable    100%"), "{text}");
    assert!(text.contains("Person ×"), "the kinds are counted by name: {text}");

    // And the path it was opened from is not, because that says which folders a
    // person keeps their work in.
    assert!(!text.contains("Dokumente"), "the report carries the path: {text}");

    // Now the promise. Every word of every finding, checked against the report.
    let units: Vec<u16> = document_view(session).expect("view").text.encode_utf16().collect();
    let findings = list_findings(session).expect("findings");
    assert!(findings.len() >= 20, "the letter should be full of them: {}", findings.len());
    for finding in &findings {
        let value = String::from_utf16_lossy(
            units.get(finding.span.start as usize..finding.span.end as usize).unwrap_or_default(),
        );
        for word in value.split_whitespace().filter(|w| w.chars().count() > 2) {
            assert!(
                !text.contains(word),
                "«{word}» is in the report, and it is a thing the scanner found ({:?})",
                finding.kind
            );
        }
    }
    // Said once by name as well, because this is the one it was written for.
    assert!(!text.contains("Weber"), "the report names the person: {text}");
}

#[test]
fn a_refused_file_still_has_a_report() {
    // No session, because nothing was imported: a refusal is exactly the moment
    // a person needs something to send.
    let text = import_report(ReportSubject::Refused {
        name: "C:\\Users\\Jonas\\Desktop\\Rechnung.pdf".to_string(),
        bytes: 5_109_029,
        refusal: Refusal::UnsupportedEncoding { page: 14, readable_percent: 41 },
    })
    .expect("a report about a file we would not read");

    assert!(text.contains("file        .pdf"), "{text}");
    assert!(
        !text.contains("Jonas") && !text.contains("Desktop") && !text.contains("Rechnung"),
        "the Windows path or the file's name is in it: {text}"
    );
    assert!(text.contains("4989 KiB"), "{text}");
    assert!(text.contains("UnsupportedEncoding"), "the refusal is named: {text}");
    assert!(text.contains("page: 14") && text.contains("41"), "with its own numbers: {text}");
    assert!(text.contains("z_core"), "and the build that refused it: {text}");
    // The stamp, whole: a report from a tester in another country is worth
    // having only if it can be put back to the build that wrote it.
    assert!(
        text.contains(&z_core::core_version()),
        "the report does not name its own build: {text}"
    );
    let stamp = text.lines().find(|l| l.starts_with("build")).unwrap_or_default();
    assert_eq!(stamp.split(" · ").count(), 3, "version, date, commit: «{stamp}»");
}

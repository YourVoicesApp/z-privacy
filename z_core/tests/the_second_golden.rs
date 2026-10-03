// The second golden: 146 pages of public German prose.
//
// The first golden is a letter — a form, full of values. This one is the
// opposite and that is its use: a book of tax terms where almost nothing is
// anybody's. What it holds the scanner to is the other side of the promise —
// **not** «did you find it» but «did you leave the language alone».
//
// It caught exactly that on 3 October. The run that taught labels to work
// without a colon turned «Geburtsdatum und seine Steuernummer» into a date of
// birth called «und», and that word was then hidden in every place it stood,
// inside other words as well: 1,380 tokens across the book, and the safe text
// read «Ges[token]heitswesen».
//
// The book is the owner's own file and a megabyte of it, so it does not live
// in the repository. When it is not on the machine this test says so and stops;
// `scripts/gates.sh` prints that as a skip, never as a pass.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::path::PathBuf;

use z_core::api::*;

fn book() -> Option<PathBuf> {
    let path = match std::env::var("ZPRIVACY_SECOND_GOLDEN") {
        Ok(name) => PathBuf::from(name),
        Err(_) => PathBuf::from(std::env::var("HOME").ok()?).join("Documents/steuern-von-a-z.pdf"),
    };
    path.is_file().then_some(path)
}

#[test]
fn the_book_of_tax_terms_is_left_alone() {
    let Some(path) = book() else {
        println!("the second golden is not on this machine — nothing was measured");
        return;
    };
    let bytes = std::fs::read(&path).expect("the book");
    let session = open_session(None, "de".to_string()).expect("open");
    let view = import_document(session, "steuern-von-a-z.pdf".to_string(), bytes, DocumentKind::Pdf)
        .expect("146 pages of it are readable");
    assert_eq!(view.pages, 146);

    let report = scan(session).expect("scan");
    // Two values the book really carries — a ministry's telephone number and an
    // address for ordering publications — and three more offered for a word.
    // These numbers are asserted here and nowhere else: if a rule starts
    // reading German prose as a form again, this is what notices.
    assert_eq!(
        (report.auto, report.suggested),
        (2, 3),
        "the scanner found things in a public book that are nobody's: {report:?}"
    );

    let units: Vec<u16> = view.text.encode_utf16().collect();
    let text_of = |f: &Finding| {
        String::from_utf16_lossy(
            units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
        )
    };
    for finding in list_findings(session).expect("findings") {
        let text = text_of(&finding);
        assert!(
            text.chars().any(|c| c.is_ascii_digit() || c == '@'),
            "«{text}» is an ordinary German word, not a value ({:?})",
            finding.kind
        );
    }

    // And the proof in the thing that leaves: a book nobody is named in should
    // carry almost no tokens at all.
    let handle = build_payload(session).expect("build");
    let safe = payload_view(handle).expect("view").text;
    let tokens = safe.matches("__Z_").count();
    assert!(
        tokens <= 8,
        "{tokens} tokens in a public book — a word of the language is being hidden"
    );
}

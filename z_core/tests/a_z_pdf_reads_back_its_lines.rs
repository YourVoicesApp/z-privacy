// **«The app does not know its own product»** — the owner, 15 October.
//
// Z writes a z-pdf and Z reads it back, and it read back with **every word on
// its own line**: 195 of 195 lines on his German z-pdf, 146 of 146 on
// `invoice_check_EN`, 300 of 300 on `FarukAB`. `pdftotext` reads the same three
// files as 31, 23 and 61 lines, so the files were never the problem.
//
// **The cause is the reader, and the writer is innocent.** `text_runs` made one
// run of each `BT … ET` block — «one paragraph, which is usually one line»,
// said its comment — and a layout engine writes one text object **per word**,
// because it has already measured where each word goes. A text object is a
// grouping with no typographic meaning at all. A line is a **y**.
//
// So the reader gathers across `BT`/`ET` now and closes a line when the
// vertical position changes, which is the rule it already applied to `Tm` and
// now applies to all three movers. Measured after:
//
//     ألماني-protected    195 one-word lines of 195  →   9 of 30
//     invoice_check_EN    146 of 146                 →   0 of 22
//     FarukAB_lonekorning 300 of 300                 →   2 of 60
//
// The nine that remain are nine words that really do stand alone — «Herrn» on
// its own line in a German address block is the shape the owner's own letter
// has.
//
// The three files are his, on this machine, and this guard says so rather than
// pretending to measure what is not here — the same shape the golden PDFs use.
// What is measured **everywhere** is the synthetic case beside the reader
// itself (`documents::pdf::tests::a_pdf_that_positions_every_word_separately_reads_back_its_lines`),
// which writes a PDF exactly the way the `pdf` package writes one.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::path::PathBuf;

use z_core::api::*;

/// The owner's own z-pdfs, when they are on this machine.
fn saved(name: &str) -> Option<PathBuf> {
    let path = PathBuf::from(std::env::var("HOME").ok()?).join("Documents/zprivacy").join(name);
    path.is_file().then_some(path)
}

const THREE: [&str; 3] = [
    "ألماني-protected-2026-10-15.pdf",
    "invoice_check_EN-protected-2026-10-09.pdf",
    "FarukAB_lonekorning_feb2027-protected-2026-10-09.pdf",
];

fn read_it(path: &PathBuf) -> String {
    let bytes = std::fs::read(path).expect("the file is there");
    let session = open_session(None, "de".to_string()).expect("open");
    let view = import_document(
        session,
        path.file_name().unwrap_or_default().to_string_lossy().to_string(),
        bytes,
        DocumentKind::Pdf,
    )
    .expect("a z-pdf our own writer made must be readable");
    let text = view.text.clone();
    close_session(session).ok();
    text
}

/// **A z-pdf reads back with the lines it was written with.**
#[test]
fn a_z_pdf_is_not_read_one_word_to_a_line() {
    let mut measured = 0;
    for name in THREE {
        let Some(path) = saved(name) else {
            println!("{name} is not on this machine — nothing was measured for it");
            continue;
        };
        measured += 1;
        let text = read_it(&path);
        let lines: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
        let alone = lines.iter().filter(|l| l.split_whitespace().count() == 1).count();
        assert!(!lines.is_empty(), "{name} read back empty");
        assert!(
            alone * 2 < lines.len(),
            "{name}: {alone} of {} lines hold a single word, so the reader is still cutting a \
             line wherever the writer started a text object",
            lines.len()
        );
    }
    if measured == 0 {
        println!("none of the owner's z-pdfs is on this machine — nothing was measured");
    }
}

/// **And every token in it is still one atom.**
///
/// The whole of the door back rests on this: a token that read back as
/// `__Z_F610_PERSON_343AD503` and `__` on two lines is a token nothing can
/// resolve, and a name that cannot be resolved is a name a person is told did
/// not come back. Asked of the real files, because this is exactly the property
/// a line change could break while every count stayed the same.
#[test]
fn every_token_in_a_z_pdf_reads_back_whole() {
    for name in THREE {
        let Some(path) = saved(name) else { continue };
        let text = read_it(&path);
        let mut found = 0;
        for piece in text.split_whitespace() {
            if !piece.contains("__Z_") {
                continue;
            }
            found += 1;
            // Trimmed of the sentence's own marks, a token is `__Z_…__` whole:
            // four parts between the fences and nothing split off it.
            let bare = piece.trim_matches(|c: char| !c.is_alphanumeric() && c != '_');
            assert!(
                bare.starts_with("__Z_") && bare.ends_with("__") && bare.len() > 10,
                "{name}: «{piece}» is half a token"
            );
        }
        assert!(found > 0, "{name}: no token at all, so this proves nothing about tokens");
    }
}

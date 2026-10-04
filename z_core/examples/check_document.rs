//! What does the reader make of this file?
//!
//!     cargo run -p z_core --example check_document -- a.pdf b.docx c.txt
//!
//! Prints **numbers only** — pages, characters, paragraphs, or the named refusal.
//! Never a line of the document's text: a tool for checking a reader must not
//! become a way to spill a document into a terminal or a log.

use std::path::Path;

use z_core::api::{ApiError, DocumentKind};

fn kind_of(path: &Path) -> Option<DocumentKind> {
    match path.extension().and_then(|e| e.to_str())?.to_lowercase().as_str() {
        "txt" | "md" | "csv" => Some(DocumentKind::Txt),
        "docx" => Some(DocumentKind::Docx),
        "pdf" => Some(DocumentKind::Pdf),
        _ => None,
    }
}

fn main() {
    let files: Vec<String> = std::env::args().skip(1).collect();
    // Which build said these numbers. The same stamp the window shows and the
    // copied report carries, so a measurement can be put back to a commit.
    println!("{}", z_core::core_version());
    if files.is_empty() {
        println!("usage: check_document <file> [file …]");
        return;
    }
    for name in files {
        let path = Path::new(&name);
        let shown = path.file_name().and_then(|n| n.to_str()).unwrap_or("?");
        let Some(kind) = kind_of(path) else {
            println!("{shown:>44}  —  not a kind this build reads");
            continue;
        };
        let bytes = match std::fs::read(path) {
            Ok(bytes) => bytes,
            Err(e) => {
                println!("{shown:>44}  —  could not be opened: {e}");
                continue;
            }
        };
        let session = match z_core::api::open_session(None, "de".to_string()) {
            Ok(session) => session,
            Err(e) => {
                println!("{shown:>44}  —  no session: {e}");
                continue;
            }
        };
        let started = std::time::Instant::now();
        match z_core::api::import_document(session, shown.to_string(), bytes.clone(), kind) {
            Ok(view) => {
                let read_ms = started.elapsed().as_millis();
                let words = view.text.split_whitespace().count();
                // How much of it reads as text at all. A wrong font mapping shows
                // up here as a low number, without anything being printed.
                let total = view.text.chars().count().max(1);
                let readable = view
                    .text
                    .chars()
                    .filter(|c| c.is_alphanumeric() || c.is_whitespace() || c.is_ascii_punctuation() || "«»—–…".contains(*c))
                    .count();
                let expected = std::env::var("EXPECT").ok().filter(|w| !w.is_empty()).map(|word| {
                    let found = view.text.to_lowercase().contains(&word.to_lowercase());
                    format!("  «{word}»: {}", if found { "found" } else { "MISSING" })
                });
                // And what the scanner makes of it: how many it protects by
                // itself, how many it offers, and how many tokens the text that
                // would leave actually carries. Counts, never the things counted
                // — a word wrongly protected shows up as a token count that is
                // far too high, which is how «und» was caught on 3 October.
                let scanning = std::time::Instant::now();
                let (auto, suggest, tokens) = match z_core::api::scan(session) {
                    Ok(report) => {
                        let tokens = z_core::api::build_payload(session)
                            .and_then(z_core::api::payload_view)
                            .map(|p| p.text.matches("__Z_").count().to_string())
                            .unwrap_or_else(|_| "—".to_string());
                        (report.auto.to_string(), report.suggested.to_string(), tokens)
                    }
                    Err(_) => ("—".to_string(), "—".to_string(), "—".to_string()),
                };
                let scan_ms = scanning.elapsed().as_millis();
                println!(
                    "{shown:>44}  {:>8} KiB  {:>4} pages  {:>7} words  {:>8} chars  {:>3}% readable  \
                     {auto:>4} protected  {suggest:>4} waiting  {tokens:>6} tokens  \
                     read {read_ms:>6} ms  scan {scan_ms:>6} ms{}",
                    bytes.len() / 1024,
                    view.pages,
                    words,
                    total,
                    readable * 100 / total,
                    expected.unwrap_or_default()
                );
            }
            Err(ApiError::DocumentRefused { reason, detail }) => {
                // The reason names a font or a filter, which is the structure of
                // the file and not a word of anybody's text — and it is the whole
                // use of this probe when a document is refused.
                println!(
                    "{shown:>44}  {:>8} KiB  refused: {reason:?}\n{:>46}{detail}",
                    bytes.len() / 1024,
                    ""
                );
            }
            Err(other) => println!("{shown:>44}  —  {other}"),
        }
        let _ = z_core::api::close_session(session);
    }
}

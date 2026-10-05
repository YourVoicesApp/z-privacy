//! What would a person be asked about this document?
//!
//!     cargo run -p z_core --example review_names -- file.pdf
//!
//! The owner's measure of Phase 2, printed: how many names need a decision,
//! what each decision is worth, and one line of context for each.
//!
//! **This one prints text from the document** — the name and the line it stands
//! in — and `check_document` beside it deliberately does not. The difference is
//! the question: «how many pages did it read» is answered by numbers, and «what
//! would I be asked about this file» cannot be. So it is the owner's tool for
//! his own files, it is not what the product does (nothing in the app prints a
//! document anywhere — G11), and it should not be piped into a log.

use std::path::Path;

use z_core::api::{DocumentKind, SessionId};

fn kind_of(path: &Path) -> Option<DocumentKind> {
    match path.extension().and_then(|e| e.to_str())?.to_lowercase().as_str() {
        "txt" | "md" | "csv" => Some(DocumentKind::Txt),
        "docx" => Some(DocumentKind::Docx),
        "pdf" => Some(DocumentKind::Pdf),
        _ => None,
    }
}

fn main() {
    println!("{}", z_core::core_version());
    for name in std::env::args().skip(1) {
        let path = Path::new(&name);
        let Some(kind) = kind_of(path) else {
            println!("{name}: not a kind this build reads");
            continue;
        };
        let Ok(bytes) = std::fs::read(path) else {
            println!("{name}: could not be opened");
            continue;
        };
        let shown = path.file_name().and_then(|n| n.to_str()).unwrap_or("?");
        let Ok(session) = z_core::api::open_session(None, "de".to_string()) else { continue };
        match z_core::api::import_document(session, shown.to_string(), bytes, kind) {
            Ok(view) => {
                let report = z_core::api::scan(session).ok();
                let candidates = z_core::api::name_candidates(session).unwrap_or_default();
                println!(
                    "\n{shown} — {} pages, {} protected, {} waiting, and {} name(s) to look at",
                    view.pages,
                    report.as_ref().map_or(0, |r| r.auto),
                    report.as_ref().map_or(0, |r| r.suggested),
                    candidates.len()
                );
                for candidate in &candidates {
                    println!(
                        "  {:<18} {:>3} places · {:>3} pages   {}",
                        candidate.text,
                        candidate.occurrences,
                        candidate.pages,
                        candidate.examples.first().map(String::as_str).unwrap_or("")
                    );
                }
            }
            Err(e) => println!("{shown}: {e}"),
        }
        let _ = z_core::api::close_session(session);
        let _: SessionId = session;
    }
}

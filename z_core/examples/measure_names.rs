//! What a tier of the name bank does to every golden, measured.
//!
//!     cargo run -p z_core --example measure_names -- [pack] [file …]
//!
//! For each document: the counts the band shows, then **the texts** of what was
//! protected and what is being asked about, so a person can judge which of them
//! are names and which are not. This is a development tool for the task that
//! changes pack data, and it is the one place a document's own words may be
//! printed — it is run by hand, on fixtures we wrote and on the owner's own
//! machine, and it prints no numbers it did not measure.
// A development tool, and held to the product's lints only where that helps:
// it reads files named on the command line and says so when they will not open.
#![allow(clippy::indexing_slicing, clippy::expect_used)]

use std::collections::BTreeMap;
use std::path::Path;

use z_core::api::*;

fn kind_of(path: &Path) -> Option<DocumentKind> {
    match path.extension().and_then(|e| e.to_str())?.to_lowercase().as_str() {
        "txt" | "md" | "csv" => Some(DocumentKind::Txt),
        "docx" => Some(DocumentKind::Docx),
        "pdf" => Some(DocumentKind::Pdf),
        _ => None,
    }
}

fn main() {
    let mut args: Vec<String> = std::env::args().skip(1).collect();
    let pack = if !args.is_empty() && (args[0] == "de" || args[0] == "sv" || args[0] == "en") {
        args.remove(0)
    } else {
        "de".to_string()
    };
    println!("{} · pack {pack}", z_core::core_version());
    for name in args {
        let path = Path::new(&name);
        let shown = path.file_name().and_then(|n| n.to_str()).unwrap_or("?");
        let Some(kind) = kind_of(path) else { continue };
        let Ok(bytes) = std::fs::read(path) else {
            println!("{shown}: could not be read");
            continue;
        };
        let Ok(session) = open_session(None, pack.clone()) else { continue };
        if kind == DocumentKind::Txt {
            let text = String::from_utf8_lossy(&bytes).to_string();
            if import_text(session, text).is_err() {
                println!("{shown}: refused");
                continue;
            }
        } else if import_document(session, shown.to_string(), bytes, kind).is_err() {
            println!("{shown}: refused");
            continue;
        }
        let Ok(report) = scan(session) else {
            println!("{shown}: scan refused");
            continue;
        };
        let findings = list_findings(session).expect("findings");
        let text = document_view(session).map(|d| d.text).unwrap_or_default();
        let slice = |f: &Finding| -> String {
            text.chars()
                .skip(f.span.start as usize)
                .take((f.span.end - f.span.start) as usize)
                .collect()
        };
        let mut protected: BTreeMap<String, (Kind, u32)> = BTreeMap::new();
        let mut suggested: BTreeMap<String, (Kind, u32)> = BTreeMap::new();
        for f in &findings {
            let into = if f.state == MarkState::Protected { &mut protected } else { &mut suggested };
            let row = into.entry(slice(f)).or_insert((f.kind, 0));
            row.1 += 1;
        }
        let found = name_candidates(session).unwrap_or_default();
        let candidates = found.len();
        println!(
            "\n{shown}: auto {} · suggested {} · normal {} · candidates {candidates}",
            report.auto, report.suggested, report.normal
        );
        let people = |rows: &BTreeMap<String, (Kind, u32)>| {
            rows.iter().filter(|(_, (k, _))| *k == Kind::Person).count()
        };
        println!("  persons: {} protected · {} suggested", people(&protected), people(&suggested));
        if !found.is_empty() {
            println!("  names to look at:");
            for c in &found {
                println!("    «{}» ×{}", c.text, c.occurrences);
            }
        }
        for (what, rows) in [("protected", &protected), ("suggested", &suggested)] {
            println!("  {what}:");
            for (value, (kind, times)) in rows {
                let times = if *times > 1 { format!(" ×{times}") } else { String::new() };
                println!("    {kind:?}  «{value}»{times}");
            }
        }
    }
}

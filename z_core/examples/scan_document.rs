//! A raw document, protecting itself before anyone touches it.
//!
//!     cargo run -p z_core --example scan_document
//!
//! This is the turn M3 was for: nobody selected anything. The document came in,
//! three layers looked at it, and what could be proven was hidden — while what
//! was merely likely waits, in the clear, for a word from the user.

use z_core::api::*;

const FIXTURE: &str = include_str!("../tests/fixtures/Vertrag_Nordstern.txt");

fn main() -> Result<(), ApiError> {
    let session = open_session(None, "de".to_string())?;
    import_text(session, FIXTURE.to_string())?;

    let report = scan(session)?;
    println!("SCAN — Vertrag_Nordstern.txt, German pack");
    println!("  ✓ {} protected automatically", report.auto);
    println!("  ? {} need review", report.suggested);
    println!("  ○ {} normal text items\n", report.normal);

    println!("WHICH LAYER CAUGHT WHAT");
    for layer in &report.by_layer {
        let name = match layer.source {
            Source::GeneralRule => "general rules".to_string(),
            Source::LanguagePack => format!("language pack «{}»", layer.detail),
            Source::Vault => "your vault".to_string(),
            Source::Hand => "your hand".to_string(),
        };
        println!("  {:>2}  {name}", layer.count);
    }
    println!();

    println!("EVERY FINDING SAYS WHY");
    for finding in list_findings(session)? {
        let state = match finding.state {
            MarkState::Protected => "protected",
            MarkState::Suggested => "ASKS YOU ",
        };
        // The text itself is read from the fixture, not from the core: the core
        // hands out spans, and a value never travels just to be printed.
        let start = finding.span.start as usize;
        let end = finding.span.end as usize;
        let shown: String = FIXTURE.chars().skip(start).take(end.saturating_sub(start)).collect();
        println!("  [{state}] {:?}  «{shown}»", finding.kind);
        println!("             {}", finding.reason);
    }
    println!();

    let handle = build_payload(session)?;
    let safe = payload_view(handle)?;
    println!("SAFE — the first eleven lines of what would leave the device");
    for line in safe.text.lines().take(11) {
        println!("  {line}");
    }
    println!();

    match send(handle, ProviderId { id: "openai".to_string() }) {
        Err(ApiError::OpenSuggestions { count }) => {
            println!("  send is refused: {count} suggestions are still unanswered.");
            println!("  There is no «send anyway» — answer them with Protect or Not Sensitive.");
        }
        other => println!("  send answered: {other:?}"),
    }
    Ok(())
}

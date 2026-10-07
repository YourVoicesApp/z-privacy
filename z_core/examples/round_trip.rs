//! The heart of Z Privacy, printed.
//!
//!     cargo run -p z_core --example round_trip
//!
//! No scanner, no vault, no interface: a document, two protections, the text
//! that would leave the device, an answer in tokens, and the answer read back.

use z_core::api::*;

const DOC: &str = "Herr Thomas Müller arbeitet bei Nordstern GmbH.";

fn span_of(doc: &str, needle: &str) -> Result<Span, ApiError> {
    let byte = doc.find(needle).ok_or(ApiError::BadSpan {
        reason: format!("«{needle}» is not in the document"),
    })?;
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    let len: usize = needle.chars().map(char::len_utf16).sum();
    Ok(Span {
        start: start as u32,
        end: (start + len) as u32,
    })
}

fn token_of(outcome: ProtectOutcome) -> Result<String, ApiError> {
    match outcome {
        ProtectOutcome::Applied { token, .. } => Ok(token),
        other => Err(ApiError::BadSpan {
            reason: format!("expected a protection, got {other:?}"),
        }),
    }
}

fn main() -> Result<(), ApiError> {
    let session = open_session(None, "de".to_string())?;
    import_text(session, DOC.to_string())?;

    let person = token_of(protect(
        session,
        span_of(DOC, "Thomas Müller")?,
        Scope::Conversation,
        Kind::Person,
    )?)?;
    let company = token_of(protect(
        session,
        span_of(DOC, "Nordstern GmbH")?,
        Scope::Conversation,
        Kind::Company,
    )?)?;

    let handle = build_payload(session)?;
    let safe = payload_view(handle)?;

    println!("ORIGINAL — stays on this device");
    println!("  {DOC}\n");
    println!("SAFE — this, and only this, would leave");
    println!("  {}\n", safe.text);

    println!("TOKENS — what the model is told about each thing, never the thing");
    for row in list_tokens(session)? {
        println!("  {}  {:?}  {:?}", row.token, row.kind, row.scope);
    }
    println!();

    // What a provider might answer, using the tokens it was given.
    let raw = format!("Bitte kontaktieren Sie {person} bei {company}. __Z_FAKE_123__ ist unbekannt.");
    let answer = ingest_answer(handle, raw)?;

    println!("AI VIEW — exactly what came back");
    println!("  {}\n", ai_view(session, answer)?);

    let restored = restored_view(session, answer)?;
    let text: String = restored.iter().map(|s| s.text.as_str()).collect();
    println!("RESTORED — read on this device, with your words back");
    println!("  {text}\n");

    println!("  put back here: {:?}", restored.iter().filter(|s| s.piece == Piece::Restored).map(|s| &s.text).collect::<Vec<_>>());
    println!("  the invented token was left alone, because it is not ours.");

    // And the one thing that must be impossible: there is no call that would
    // take the original text and send it. `send` only accepts a handle.
    match send(handle, ProviderId { id: "openai".to_string() }) {
        Err(ApiError::ProviderUnavailable { provider }) => {
            println!("\n  send({provider}) is refused for now: the network arrives in M6.");
        }
        other => println!("\n  send answered: {other:?}"),
    }
    Ok(())
}

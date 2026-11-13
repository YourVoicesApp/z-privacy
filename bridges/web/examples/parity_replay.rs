//! **The parity replay** — paper 122 §2.4.
//!
//! Reads a transcript the browser build wrote (`tests/web/parity.mjs`): one
//! JSON line per call, `{"door","request","response"}`. Each request is
//! replayed, in order, through the same doors built against the **native**
//! core, and each native response is printed as a JSON line of its own, so
//! that the script can compare the two after naming the tokens (a token's
//! letters are drawn at random, per session, on both sides).
//!
//! A line may carry `"from": {"call": i, "prefix": p}`: its request's `text`
//! is the core's own text from call `i` (a pasted answer holds the payload's
//! tokens, and this side's tokens are its own), so it is rebuilt as `p` + the
//! `text` of **this side's** answer to call `i`.
//!
//! `cargo run --example parity_replay -- <transcript.jsonl>`

use std::io::Write;

fn main() -> std::process::ExitCode {
    let Some(path) = std::env::args().nth(1) else {
        eprintln!("usage: parity_replay <transcript.jsonl>");
        return std::process::ExitCode::from(2);
    };
    let Ok(text) = std::fs::read_to_string(&path) else {
        eprintln!("cannot read the transcript");
        return std::process::ExitCode::from(2);
    };
    let mut out = std::io::stdout().lock();
    let mut answered: Vec<String> = Vec::new();
    for line in text.lines().filter(|l| !l.trim().is_empty()) {
        let Ok(serde_json::Value::Object(call)) = serde_json::from_str::<serde_json::Value>(line) else {
            eprintln!("a transcript line is not an object");
            return std::process::ExitCode::from(2);
        };
        let (Some(door), Some(request)) = (
            call.get("door").and_then(|v| v.as_str()),
            call.get("request").and_then(|v| v.as_str()),
        ) else {
            eprintln!("a transcript line has no door or request");
            return std::process::ExitCode::from(2);
        };
        let request = match call.get("from") {
            None => request.to_string(),
            Some(from) => match rebuilt(request, from, &answered) {
                Some(r) => r,
                None => {
                    eprintln!("a `from` names no text this side answered");
                    return std::process::ExitCode::from(2);
                }
            },
        };
        let Some(response) = z_web::doors::call(door, &request) else {
            eprintln!("not a door: {door}");
            return std::process::ExitCode::from(2);
        };
        let row = serde_json::json!({ "door": door, "response": response });
        answered.push(response);
        if writeln!(out, "{row}").is_err() {
            return std::process::ExitCode::from(1);
        }
    }
    std::process::ExitCode::SUCCESS
}

/// The request with its `text` taken from this side's own earlier answer.
fn rebuilt(request: &str, from: &serde_json::Value, answered: &[String]) -> Option<String> {
    let index = usize::try_from(from.get("call")?.as_u64()?).ok()?;
    let prefix = from.get("prefix")?.as_str()?;
    let earlier: serde_json::Value = serde_json::from_str(answered.get(index)?).ok()?;
    let text = earlier.get("ok")?.get("text")?.as_str()?;
    let mut request: serde_json::Value = serde_json::from_str(request).ok()?;
    request.as_object_mut()?.insert("text".into(), serde_json::Value::String(format!("{prefix}{text}")));
    Some(request.to_string())
}

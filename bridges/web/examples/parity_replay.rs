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
//! `text` of **this side's** answer to call `i`. With `"payload": j` as well,
//! its `payload` is this side's own `payload` from call `j`: a handle carries
//! the session's revision, and with a vault the app's side counts one more
//! (the birth names its tokens again), so the web's handle would be stale here.
//!
//! **`--vault <dir>`** (paper 123): the app keeps a chat in a session of its
//! vault, and the native core has no other place for one. So for the chat's
//! transcript the replay first makes a vault in `<dir>` — a temporary folder
//! the script made, never the owner's — and the native side's chat is the app's
//! own: a sealed session file. The web's is the page's memory. What is compared
//! is what each hands out.
//!
//! A line may carry `"finding": {"call": i, "start": s, "end": e}`: its
//! request's `finding` is the id **this side's** answer to call `i` gives the
//! mark at that span. With a vault the app's scan sees its own blocks and
//! numbers its findings differently; the place is the same place.
//!
//! With `--vault`, a line `{"door":"__fresh_vault"}` makes a new vault in a new
//! folder under `<dir>` before the calls after it: the app's vault remembers
//! every protected word across sessions (089), the trial remembers nothing, so
//! each language's chat starts from an empty vault, as the web starts empty.
//!
//! `cargo run --example parity_replay -- [--vault <dir>] <transcript.jsonl>`

use std::io::Write;

fn main() -> std::process::ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (vault, path) = match args.as_slice() {
        [flag, dir, path] if flag == "--vault" => (Some(dir.clone()), path.clone()),
        [path] => (None, path.clone()),
        _ => {
            eprintln!("usage: parity_replay [--vault <dir>] <transcript.jsonl>");
            return std::process::ExitCode::from(2);
        }
    };
    let mut vaults = 0u32;
    let mut fresh_vault = |dir: &str| -> bool {
        vaults += 1;
        let folder = std::path::Path::new(dir).join(format!("vault-{vaults}"));
        z_core::api::set_data_dir(folder.to_string_lossy().to_string())
            .and_then(|()| {
                z_core::api::vault_create_with_passphrase("a passphrase for the parity replay only".to_string())
            })
            .is_ok()
    };
    if let Some(dir) = vault.as_deref() {
        if !fresh_vault(dir) {
            eprintln!("the replay's vault could not be made");
            return std::process::ExitCode::from(2);
        }
    }
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
        if door == "__fresh_vault" {
            let made = vault.as_deref().is_some_and(&mut fresh_vault);
            if !made {
                eprintln!("a fresh vault was asked for and could not be made");
                return std::process::ExitCode::from(2);
            }
            let response = r#"{"ok":{}}"#.to_string();
            let row = serde_json::json!({ "door": door, "response": response });
            answered.push(response);
            if writeln!(out, "{row}").is_err() {
                return std::process::ExitCode::from(1);
            }
            continue;
        }
        let request = match call.get("finding") {
            None => request.to_string(),
            Some(at) => match finding_of(request, at, &answered) {
                Some(r) => r,
                None => {
                    eprintln!("a `finding` names no mark this side answered");
                    return std::process::ExitCode::from(2);
                }
            },
        };
        let request = match call.get("from") {
            None => request,
            Some(from) => match rebuilt(&request, from, &answered) {
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
    let fields = request.as_object_mut()?;
    fields.insert("text".into(), serde_json::Value::String(format!("{prefix}{text}")));
    if let Some(j) = from.get("payload") {
        let j = usize::try_from(j.as_u64()?).ok()?;
        let made: serde_json::Value = serde_json::from_str(answered.get(j)?).ok()?;
        fields.insert("payload".into(), made.get("ok")?.get("payload")?.clone());
    }
    Some(request.to_string())
}

/// The request with its `finding` taken from this side's own view: the mark of
/// call `i`'s answer that stands at the same span.
fn finding_of(request: &str, at: &serde_json::Value, answered: &[String]) -> Option<String> {
    let index = usize::try_from(at.get("call")?.as_u64()?).ok()?;
    let (start, end) = (at.get("start")?.as_u64()?, at.get("end")?.as_u64()?);
    let earlier: serde_json::Value = serde_json::from_str(answered.get(index)?).ok()?;
    let marks = earlier.get("ok")?.get("view")?.get("marks")?.as_array()?;
    let mark = marks.iter().find(|m| {
        m.get("start").and_then(|v| v.as_u64()) == Some(start)
            && m.get("end").and_then(|v| v.as_u64()) == Some(end)
            && m.get("state").and_then(|v| v.as_str()) == Some("suggested")
    })?;
    let mut request: serde_json::Value = serde_json::from_str(request).ok()?;
    request.as_object_mut()?.insert("finding".into(), mark.get("finding")?.clone());
    Some(request.to_string())
}

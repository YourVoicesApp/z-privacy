//! The fifteen doors, as plain Rust: one JSON string in, one JSON string out.
//! Ten from paper 122, five from paper 123 (the chat, and «Start over»).
//!
//! Nothing here is the browser's. `lib.rs` hands these to wasm-bindgen on
//! `wasm32`, and the parity replay calls them natively, so the two sides of
//! the comparison run the same translation over two builds of the same core.
//!
//! **The answer is always `{"ok": …}` or `{"error": "<name>", …}`.** An error
//! carries its variant's name in snake case and numbers only: no free text of
//! the core's crosses this door, since a reason may quote the document.
//! Offsets are UTF-16 code units, which is what the core's `Span` already is
//! and what a JavaScript string counts.

use serde_json::{json, Map, Value};
use z_core::api::{
    self, ApiError, DocumentView, Finding, FindingAnswer, Kind, Mark, MarkState, PayloadHandle, Piece,
    ProtectOutcome, Scope, ScanReport, Segment, SessionId, Source, Span, UndoOutcome,
};

/// The language packs the trial offers.
pub const PACKS: [&str; 6] = ["en", "ar", "de", "fr", "es", "sv"];

/// Every door by its exported name, for the replay.
pub const DOORS: [&str; 15] = [
    "z_open",
    "z_import_text",
    "z_scan",
    "z_protect",
    "z_unprotect",
    "z_answer_finding",
    "z_build_payload",
    "z_payload_to_take_out",
    "z_ingest_answer",
    "z_restored_view",
    "z_set_question",
    "z_question_to_take_out",
    "z_turns",
    "z_end_the_chat",
    "z_close",
];

/// Call a door by name. `None` for a name that is not a door.
pub fn call(door: &str, request: &str) -> Option<String> {
    let f: fn(&str) -> String = match door {
        "z_open" => z_open,
        "z_import_text" => z_import_text,
        "z_scan" => z_scan,
        "z_protect" => z_protect,
        "z_unprotect" => z_unprotect,
        "z_answer_finding" => z_answer_finding,
        "z_build_payload" => z_build_payload,
        "z_payload_to_take_out" => z_payload_to_take_out,
        "z_ingest_answer" => z_ingest_answer,
        "z_restored_view" => z_restored_view,
        "z_set_question" => z_set_question,
        "z_question_to_take_out" => z_question_to_take_out,
        "z_turns" => z_turns,
        "z_end_the_chat" => z_end_the_chat,
        "z_close" => z_close,
        _ => return None,
    };
    Some(f(request))
}

// ---------------------------------------------------------------- the frame

/// A refusal of this door's own, before the core is asked.
#[derive(Debug)]
enum Refused {
    /// The request is not the shape this door reads.
    BadRequest,
    /// The request needs the vault, which the trial does not have.
    NotOnWeb,
    /// A chat door was asked before anything was read: there is no chat.
    NoChat,
    /// The core said no.
    Core(ApiError),
}

impl From<ApiError> for Refused {
    fn from(e: ApiError) -> Self {
        Refused::Core(e)
    }
}

type Answer = Result<Value, Refused>;

fn door(request: &str, body: impl FnOnce(&Map<String, Value>) -> Answer) -> String {
    let answer = match serde_json::from_str::<Value>(request) {
        Ok(Value::Object(fields)) => body(&fields),
        _ => Err(Refused::BadRequest),
    };
    match answer {
        Ok(v) => json!({ "ok": v }).to_string(),
        Err(e) => error_json(&e).to_string(),
    }
}

fn error_json(e: &Refused) -> Value {
    match e {
        Refused::BadRequest => json!({ "error": "bad_request" }),
        Refused::NotOnWeb => json!({ "error": "not_on_web" }),
        Refused::NoChat => json!({ "error": "no_chat" }),
        Refused::Core(e) => match e {
            ApiError::StalePayload { expected, got } => {
                json!({ "error": "stale_payload", "expected": expected, "got": got })
            }
            ApiError::OpenSuggestions { count } => json!({ "error": "open_suggestions", "count": count }),
            ApiError::DocumentRefused { reason, .. } => {
                json!({ "error": "document_refused", "reason": variant_name(reason) })
            }
            ApiError::NetworkRefused { reason, .. } => {
                json!({ "error": "network_refused", "reason": variant_name(reason) })
            }
            // Every other variant by its name alone: the ones with a field
            // carry a sentence, and a sentence may quote the document.
            other => json!({ "error": variant_name(other) }),
        },
    }
}

/// `StalePayload { .. }` → `stale_payload`. The name only, never the fields:
/// it is read off the `Debug` form up to the first character that is not part
/// of an identifier.
fn variant_name(v: &impl std::fmt::Debug) -> String {
    let debug = format!("{v:?}");
    let name: String = debug.chars().take_while(|c| c.is_ascii_alphanumeric()).collect();
    let mut out = String::with_capacity(name.len() + 4);
    for (i, c) in name.chars().enumerate() {
        if c.is_ascii_uppercase() {
            if i > 0 {
                out.push('_');
            }
            out.push(c.to_ascii_lowercase());
        } else {
            out.push(c);
        }
    }
    out
}

fn uint(fields: &Map<String, Value>, name: &str) -> Result<u32, Refused> {
    fields
        .get(name)
        .and_then(Value::as_u64)
        .and_then(|n| u32::try_from(n).ok())
        .ok_or(Refused::BadRequest)
}

fn string<'a>(fields: &'a Map<String, Value>, name: &str) -> Result<&'a str, Refused> {
    fields.get(name).and_then(Value::as_str).ok_or(Refused::BadRequest)
}

fn session_of(fields: &Map<String, Value>) -> Result<SessionId, Refused> {
    Ok(SessionId { id: uint(fields, "session")? })
}

fn span_of(fields: &Map<String, Value>) -> Result<Span, Refused> {
    Ok(Span { start: uint(fields, "start")?, end: uint(fields, "end")? })
}

const KINDS: [Kind; 19] = [
    Kind::Person,
    Kind::Company,
    Kind::Email,
    Kind::Phone,
    Kind::Iban,
    Kind::Bic,
    Kind::Account,
    Kind::TaxId,
    Kind::CustomerNo,
    Kind::Address,
    Kind::Contract,
    Kind::Project,
    Kind::Client,
    Kind::IdCard,
    Kind::Birthdate,
    Kind::Vehicle,
    Kind::SocialInsuranceNo,
    Kind::EmployeeNo,
    Kind::Custom,
];

fn kind_of(name: &str) -> Result<Kind, Refused> {
    KINDS.into_iter().find(|k| variant_name(k) == name).ok_or(Refused::BadRequest)
}

// ---------------------------------------------------------------- the views

fn source_name(s: Source) -> String {
    variant_name(&s)
}

fn span_json(s: Span) -> Value {
    json!({ "start": s.start, "end": s.end })
}

/// The view, with each mark's finding id when it has one: the id is what
/// `z_answer_finding` takes. A mark and a finding are matched by their span,
/// the same place in the same text; a mark the person made by hand has none.
fn view_json(v: &DocumentView, findings: &[Finding]) -> Value {
    let marks: Vec<Value> = v
        .marks
        .iter()
        .map(|m| {
            let finding = findings
                .iter()
                .find(|f| f.span == m.span && f.state == m.state)
                .or_else(|| findings.iter().find(|f| f.span == m.span))
                .map(|f| f.id);
            mark_json(m, finding)
        })
        .collect();
    json!({ "text": v.text, "marks": marks })
}

fn mark_json(m: &Mark, finding: Option<u32>) -> Value {
    json!({
        "start": m.span.start,
        "end": m.span.end,
        "state": match m.state { MarkState::Protected => "protected", MarkState::Suggested => "suggested" },
        "token": m.token,
        "kind": variant_name(&m.kind),
        "source": source_name(m.source),
        "decided": m.decided,
        "finding": finding,
    })
}

fn segments_json(segments: &[Segment]) -> Value {
    let text: String = segments.iter().map(|s| s.text.as_str()).collect();
    let pieces: Vec<Value> = segments
        .iter()
        .map(|s| {
            let piece = match s.piece {
                Piece::Words => "words",
                Piece::Restored => "restored",
                Piece::Unresolved => "unresolved",
            };
            json!({ "text": s.text, "piece": piece })
        })
        .collect();
    json!({ "text": text, "segments": pieces })
}

fn current_view(session: SessionId) -> Answer {
    let view = api::document_view(session)?;
    let findings = api::list_findings(session)?;
    Ok(view_json(&view, &findings))
}

fn counts_json(r: &ScanReport) -> Map<String, Value> {
    let mut m = Map::new();
    m.insert("auto".into(), json!(r.auto));
    m.insert("suggested".into(), json!(r.suggested));
    m.insert("normal".into(), json!(r.normal));
    m
}

fn protect_json(o: &ProtectOutcome) -> Value {
    match o {
        ProtectOutcome::Applied { token, places } => json!({ "applied": { "token": token, "places": places } }),
        ProtectOutcome::AlreadyProtected { token, source, .. } => {
            json!({ "already_protected": { "token": token, "source": source_name(*source) } })
        }
        ProtectOutcome::BelongsToEntity { entity, token } => {
            json!({ "belongs_to_entity": { "entity": entity, "token": token } })
        }
        ProtectOutcome::Snapped { spans } => {
            json!({ "snapped": { "spans": spans.iter().copied().map(span_json).collect::<Vec<_>>() } })
        }
        ProtectOutcome::StandsOnAToken { token } => json!({ "stands_on_a_token": { "token": token } }),
    }
}

fn undo_json(o: &UndoOutcome) -> Value {
    match o {
        UndoOutcome::NothingToUndo => json!({ "nothing_to_undo": {} }),
        UndoOutcome::Undone { tokens, places, .. } => json!({ "undone": { "tokens": tokens, "places": places } }),
    }
}

fn handle_json(h: PayloadHandle) -> Value {
    json!({ "id": h.id, "session": h.session, "revision": h.revision })
}

// ---------------------------------------------------------------- the doors

/// `{"pack"}` → `{"session"}`. The trial has no profile and no vault.
pub fn z_open(request: &str) -> String {
    door(request, |f| {
        let pack = string(f, "pack")?;
        if !PACKS.contains(&pack) {
            return Err(Refused::BadRequest);
        }
        let s = api::open_session(None, pack.to_string())?;
        Ok(json!({ "session": s.id }))
    })
}

/// `{"session","text"}` → `{"view"}`. The text arrives scanned.
pub fn z_import_text(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        let view = api::import_text(session, string(f, "text")?.to_string())?;
        let findings = api::list_findings(session)?;
        Ok(json!({ "view": view_json(&view, &findings) }))
    })
}

/// `{"session"}` → `{"auto","suggested","normal","view"}`.
pub fn z_scan(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        let report = api::scan(session)?;
        let mut out = counts_json(&report);
        out.insert("view".into(), current_view(session)?);
        Ok(Value::Object(out))
    })
}

/// `{"session","start","end","kind","scope"?}` → `{"outcome","view"}`.
///
/// `scope` is `once` (the default) or `conversation`. `profile` and `always`
/// are promises about tomorrow, kept in a vault the trial does not have:
/// `not_on_web`.
pub fn z_protect(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        let span = span_of(f)?;
        let kind = kind_of(string(f, "kind")?)?;
        let scope = match f.get("scope") {
            None | Some(Value::Null) => Scope::Once,
            Some(Value::String(s)) => match s.as_str() {
                "once" => Scope::Once,
                "conversation" => Scope::Conversation,
                "profile" | "always" => return Err(Refused::NotOnWeb),
                _ => return Err(Refused::BadRequest),
            },
            Some(_) => return Err(Refused::BadRequest),
        };
        let outcome = api::protect(session, span, scope, kind)?;
        Ok(json!({ "outcome": protect_json(&outcome), "view": current_view(session)? }))
    })
}

/// `{"session","start","end"}` → `{"outcome","view"}`.
pub fn z_unprotect(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        let outcome = api::unprotect(session, span_of(f)?)?;
        Ok(json!({ "outcome": undo_json(&outcome), "view": current_view(session)? }))
    })
}

/// `{"session","finding","answer"}` → `{"outcome","view"}` — the suggestion's
/// own buttons. `finding` is the mark's `finding` id.
///
/// * `protect` — protect it, and every place holding the same value, in this
///   conversation. The suggestion is decided.
/// * `leave` — it is not sensitive: the suggestion goes, every place of the
///   same value with it, and the value stays in the payload as written.
/// * `always` — would be kept in the vault: `not_on_web`.
///
/// `outcome` is the scan's counts after the answer.
pub fn z_answer_finding(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        let finding = uint(f, "finding")?;
        let answer = match string(f, "answer")? {
            "protect" => FindingAnswer::Protect,
            "leave" => FindingAnswer::NotSensitive,
            "always" => return Err(Refused::NotOnWeb),
            _ => return Err(Refused::BadRequest),
        };
        let report = api::answer_finding(session, finding, answer)?;
        Ok(json!({ "outcome": Value::Object(counts_json(&report)), "view": current_view(session)? }))
    })
}

/// `{"session"}` → `{"payload":{"id","session","revision"}}`.
pub fn z_build_payload(request: &str) -> String {
    door(request, |f| {
        let handle = api::build_payload(session_of(f)?)?;
        Ok(json!({ "payload": handle_json(handle) }))
    })
}

/// `{"session"}` → `{"text","protected_count","open_suggestions"}`.
pub fn z_payload_to_take_out(request: &str) -> String {
    door(request, |f| {
        let v = api::payload_to_take_out(session_of(f)?)?;
        Ok(json!({ "text": v.text, "protected_count": v.protected_count, "open_suggestions": v.open_suggestions }))
    })
}

/// `{"payload":{"id","session","revision"},"text"}` → `{"answer"}`.
pub fn z_ingest_answer(request: &str) -> String {
    door(request, |f| {
        let p = f.get("payload").and_then(Value::as_object).ok_or(Refused::BadRequest)?;
        let handle = PayloadHandle { id: uint(p, "id")?, session: uint(p, "session")?, revision: uint(p, "revision")? };
        let answer = api::ingest_answer(handle, string(f, "text")?.to_string())?;
        Ok(json!({ "answer": answer.id }))
    })
}

/// `{"session","answer"}` → `{"text","segments":[{"text","piece"}]}`.
pub fn z_restored_view(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        let answer = api::AnswerId { id: uint(f, "answer")? };
        let segments = api::restored_view(session, answer)?;
        Ok(segments_json(&segments))
    })
}

// ---------------------------------------------------------------- the chat
//
// Paper 123, rule 87 (أ): the chat comes to the trial as it is in the app
// (rules 65–68). The first turn is the one 122 built: `z_build_payload` and
// `z_payload_to_take_out`, then `z_ingest_answer` — that answer writes the
// chat's first turn, its question the document as it left. Every turn after
// it: `z_set_question`, `z_question_to_take_out`, `z_ingest_answer` against the
// handle the take-out gave. The chat lives in this page's memory and nowhere
// else; `z_close` drops it.

/// `{"session","text"}` → `{"text","marks"}` — the next question, scanned and
/// protected as the document was: the same name is the same token.
///
/// `text` is the question **as it would leave**; `marks` are over the text as
/// it was typed (UTF-16), in the view's mark shape with `finding` null — a
/// question's marks are not findings to answer.
pub fn z_set_question(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        let q = api::set_question(session, string(f, "text")?.to_string())?;
        let marks: Vec<Value> = q.marks.iter().map(|m| mark_json(m, None)).collect();
        Ok(json!({ "text": q.text, "marks": marks }))
    })
}

/// `{"session"}` → `{"text","payload":{"id","session","revision"}}` — what
/// «Copy protected» copies at turn two and after.
///
/// **Exactly what the app's `ask_model` hands its model**, from the same
/// builders: the one exchange before (as it travelled, protected), then the
/// question alone. The payload is the question's: an answer pasted against it
/// is restored by its allowed list — the question's tokens and every token the
/// chat has carried — and the turn it writes keeps its question.
///
/// Refused as `nothing_to_send` with no question set, and `open_suggestions`
/// while a word waits.
pub fn z_question_to_take_out(request: &str) -> String {
    door(request, |f| {
        let out = z_core::web::question_to_take_out(session_of(f)?)?;
        Ok(json!({ "text": out.text, "payload": handle_json(out.handle) }))
    })
}

/// `{"session"}` → `{"chat","turns":[…]}` — every turn of the session this
/// bench writes into, in order: `chat` is the open chat's number, and each turn
/// is `{"chat","question_as_it_left","answer_as_written","question":{"text",
/// "segments"},"answer":{"text","segments"},"unresolved"}` — the coded form the
/// thread draws (rule 66) and the restored form «Show the text» opens, from one
/// read. No session yet (nothing has been read): `{"chat":1,"turns":[]}`.
pub fn z_turns(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        api::document_view(session)?;
        let Some(number) = api::conversation_open()? else {
            return Ok(json!({ "chat": 1, "turns": [] }));
        };
        let chat = api::the_open_chat(number)?;
        let turns: Vec<Value> = api::conversation_turns(number, Some(session))?
            .iter()
            .map(|t| {
                json!({
                    "chat": t.chat_number,
                    "question_as_it_left": t.question_as_it_left,
                    "answer_as_written": t.answer_as_written,
                    "question": segments_json(&t.question),
                    "answer": segments_json(&t.answer),
                    "unresolved": t.unresolved,
                })
            })
            .collect();
        Ok(json!({ "chat": chat, "turns": turns }))
    })
}

/// `{"session"}` → `{"chat"}` — rule 68: the open chat ends, its turns stay,
/// and the next question carries none of them. `chat` is the number of the
/// chat open now. `no_chat` when nothing has been read yet.
pub fn z_end_the_chat(request: &str) -> String {
    door(request, |f| {
        let session = session_of(f)?;
        api::document_view(session)?;
        let Some(number) = api::conversation_open()? else {
            return Err(Refused::NoChat);
        };
        Ok(json!({ "chat": api::end_the_chat(number)? }))
    })
}

/// `{"session"}` → `{}` — **Start over**, rule 87 (د): the bench and its
/// session leave memory together. Every later call with this session is
/// refused as `invalid_session`, and none of its tokens restores on the bench
/// that comes next. Open a new one with `z_open` (same pack) for the next text.
pub fn z_close(request: &str) -> String {
    door(request, |f| {
        z_core::web::close(session_of(f)?)?;
        Ok(json!({}))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_are_snake_case_and_carry_no_fields() {
        assert_eq!(variant_name(&Kind::SocialInsuranceNo), "social_insurance_no");
        assert_eq!(variant_name(&Kind::TaxId), "tax_id");
        assert_eq!(variant_name(&ApiError::InputRefused { reason: "Anna".into() }), "input_refused");
        assert_eq!(variant_name(&Source::LanguagePack), "language_pack");
    }

    #[test]
    fn every_kind_reads_back() {
        for k in KINDS {
            assert!(matches!(kind_of(&variant_name(&k)), Ok(back) if back == k));
        }
    }

    #[test]
    fn a_request_that_is_not_an_object_is_bad() {
        assert_eq!(z_open("[]"), r#"{"error":"bad_request"}"#);
        assert_eq!(z_open(r#"{"pack":"xx"}"#), r#"{"error":"bad_request"}"#);
    }
}

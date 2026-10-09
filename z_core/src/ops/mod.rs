//! The work behind the contract.
//!
//! `api.rs` is kept as a bare surface — one line per function — so that the
//! gates can read every signature and so the contract is easy to see whole.
//! What each call actually does lives here.

mod vault;
mod snapshots;
pub(crate) mod conversation;

pub(crate) use vault::*;
pub(crate) use snapshots::*;

use std::collections::BTreeMap;

use crate::api::{
    ApiError, ApiResult, AnswerId, DocumentKind, Finding, FindingAnswer, LayerCount, Segment, DocumentView, Kind,
    Explanation, Mark, MarkState, PackRow, PayloadHandle, PayloadView, ProtectOutcome, ProviderId,
    LineSelection, NameCandidate, ProviderRow, QuestionView, ReportSubject, RevealedToken,
    RevealedValue,
    SelectionView, RescanOutcome, Revision, ScanReport, Scope, SessionId, Source, Span, SwitchOutcome,
    TaughtReach, TokenRow, UndoOutcome,
};
use crate::secret::Secret;
use crate::vault::model::{ProviderLogin, UserException};
use crate::scanner;
use crate::session::FindingRecord;
use crate::payload::SafePayload;
use crate::session::{with_core, with_session, AnswerRecord, Protection, Session};
use crate::text;
use crate::tokens::{restore, TokenEntry};

// How long a revealed value stays on screen is a setting now (task 030); see
// `ops::vault::reveal_ttl_ms`.

// ---------------------------------------------------------------- session

pub(crate) fn open_session(profile_id: Option<String>, pack_id: String) -> ApiResult<SessionId> {
    let id = with_core(|core| core.open(profile_id, pack_id));
    Ok(SessionId { id })
}

pub(crate) fn close_session(session: SessionId) -> ApiResult<()> {
    if with_core(|core| core.close(session.id)) {
        Ok(())
    } else {
        Err(ApiError::InvalidSession)
    }
}

pub(crate) fn session_revision(session: SessionId) -> ApiResult<Revision> {
    with_session(session.id, |s| Revision { n: s.revision }).ok_or(ApiError::InvalidSession)
}

// ---------------------------------------------------------------- document

pub(crate) fn import_text(session: SessionId, text_in: String) -> ApiResult<DocumentView> {
    // Typed text goes through the same reader as a .txt file, so that a paragraph
    // is numbered the same way whether it was typed or opened.
    let read = if text_in.trim().is_empty() {
        None
    } else {
        Some(crate::documents::txt::extract(
            text_in.as_bytes(),
            &crate::documents::Budget::new(),
        )?)
    };
    let view = with_session(session.id, |s| {
        match read {
            Some(extracted) => {
                s.original = crate::secret::Secret::new(extracted.text);
                s.places = extracted.places;
                s.pages = extracted.pages;
            }
            None => {
                s.original = crate::secret::Secret::new(text_in);
                s.places = Vec::new();
                s.pages = 1;
            }
        }
        s.doc_name = String::new();
        s.doc_kind = DocumentKind::Txt;
        // A new document means the old protections describe nothing. Payloads
        // are kept so an old handle can still explain itself as stale.
        s.protections.clear();
        s.findings.clear();
        s.scan_origin = crate::api::ScanOrigin::NotScanned;
        s.bump();
        view_of(s)
    })
    .ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    view
}

/// Read a file, here, from memory. Nothing is written to disk on the way (G15).
pub(crate) fn import_document(
    session: SessionId,
    name: String,
    bytes: Vec<u8>,
    kind: DocumentKind,
) -> ApiResult<DocumentView> {
    let extracted = crate::documents::extract(&bytes, kind)?;
    // The file's bytes are dropped here, at the end of this call. They were never
    // written anywhere, and the text lives only inside the session's Secret.
    let view = with_session(session.id, |s| {
        s.original = crate::secret::Secret::new(extracted.text);
        s.places = extracted.places;
        s.pages = extracted.pages;
        s.doc_name = name;
        s.doc_bytes = bytes.len().min(u32::MAX as usize) as u32;
        s.readable = extracted.readable;
        s.doc_kind = kind;
        s.protections.clear();
        s.findings.clear();
        s.scan_origin = crate::api::ScanOrigin::NotScanned;
        s.bump();
        view_of(s)
    })
    .ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    view
}

/// Gather the names this document uses that no dictionary knows.
///
/// One row per name, not one per occurrence: a person reviewing a 734-page file
/// cannot be shown 18 lines about one word. The count of occurrences and the
/// count of pages are on the row because together they say what the decision is
/// worth, and three lines of context are there because one look should be
/// enough to decide.
pub(crate) fn name_candidates(session: SessionId) -> ApiResult<Vec<NameCandidate>> {
    with_core(|core| {
        let (s, vault) = core.session_and_vault(session.id).ok_or(ApiError::InvalidSession)?;
        let text = s.original_str().to_string();
        // What the person has already taught is no longer a candidate: the
        // review list is what still needs a decision, and nothing else.
        let taught = vault.taught_names(s.profile_id.as_deref());
        let is_taught = |word: &str| taught.iter().any(|(t, _)| t.eq_ignore_ascii_case(word));
        // Whichever pack this session runs: discovery belongs to the contract,
        // not to German.
        let hints = crate::scanner::packs::discover(&text, &s.pack_id, &is_taught);

        // One row per spelling. The first hint's rule is kept as the «why»:
        // they are rules about the same word, and the first is the one that
        // noticed it.
        let mut rows: BTreeMap<String, (bool, &'static str)> = BTreeMap::new();
        for hint in &hints {
            let Some(word) = text.get(hint.start..hint.end) else { continue };
            rows.entry(word.to_string()).or_insert((hint.family, hint.rule));
        }

        let mut out: Vec<NameCandidate> = Vec::new();
        for (word, (family, rule)) in rows {
            let places = text::occurrences(&text, &word);
            let mut pages: Vec<u32> = places
                .iter()
                .filter_map(|(start, _)| s.place_of(*start).map(|p| p.page))
                .collect();
            pages.sort_unstable();
            pages.dedup();
            let examples = places
                .iter()
                .take(3)
                .map(|(start, end)| line_around(&text, *start, *end))
                .collect();
            out.push(NameCandidate {
                text: word,
                family,
                occurrences: places.len() as u32,
                pages: pages.len().max(1) as u32,
                examples,
                why: match rule {
                    "surname-before-a-known-given-name" => {
                        "it stands before a comma and a given name this build knows — the way a list of people is written".to_string()
                    }
                    _ => "it stands straight after a given name this build knows".to_string(),
                },
            });
        }
        // The most places first: one decision there is worth the most.
        out.sort_by(|a, b| b.occurrences.cmp(&a.occurrences).then(a.text.cmp(&b.text)));
        Ok(out)
    })
}

/// The line a word stands in, trimmed, so three of them fit on a screen.
fn line_around(text: &str, start: usize, end: usize) -> String {
    let from = text.get(..start).map_or(0, |head| head.rfind('\n').map_or(0, |at| at + 1));
    let to = text.get(end..).map_or(text.len(), |tail| {
        tail.find('\n').map_or(text.len(), |at| end + at)
    });
    let line = text.get(from..to).unwrap_or_default();
    if line.chars().count() <= 160 {
        return line.trim().to_string();
    }
    // A paragraph can be a single line of 2,000 characters, and the first 160
    // of it may not contain the name at all — measured on the German letter,
    // where the example shown for «Demir» was a sentence about somebody else.
    // So the window is centred on the word.
    let head = start.saturating_sub(from);
    let before = 70usize;
    let want = head.saturating_sub(before);
    let open = line.char_indices().map(|(i, _)| i).rfind(|i| *i <= want).unwrap_or(0);
    let close = line
        .char_indices()
        .map(|(i, _)| i)
        .find(|i| *i >= (end.saturating_sub(from)).saturating_add(before))
        .unwrap_or(line.len());
    let window = line.get(open..close).unwrap_or_default().trim();
    let left = if open > 0 { "…" } else { "" };
    let right = if close < line.len() { "…" } else { "" };
    format!("{left}{window}{right}")
}

/// The report a person can copy and send when something is wrong.
///
/// **Numbers only.** Not one character of the document, and not one character of
/// anything the scanner found — the kinds are counted by name, never shown. The
/// use of it is a tester in another country who cannot send us the document
/// itself: this is what can be said about a file without saying anything that is
/// in it. Written here because the screen must not be able to invent a number
/// of its own (G11, and the behaviour board's rule that no figure on screen is
/// worked out in Dart).
pub(crate) fn import_report(subject: ReportSubject) -> ApiResult<String> {
    let mut out = String::new();
    out.push_str("Z Privacy — document report\n");
    out.push_str(&format!("{:<12}{}\n", "build", crate::core_version()));
    match subject {
        ReportSubject::Refused {
            name,
            bytes,
            refusal,
        } => {
            out.push_str(&format!("{:<12}{}\n", "file", file_extension(&name)));
            out.push_str(&format!("{:<12}{} KiB\n", "size", bytes / 1024));
            // The refusal by its own name and its own numbers, as the core wrote
            // it — a sentence translated for a screen is not what a report needs.
            out.push_str(&format!("{:<12}{refusal:?}\n", "refused"));
        }
        ReportSubject::Imported { session } => {
            let report = with_session(session.id, |s| {
                let text = s.original_str().to_string();
                let mut auto: BTreeMap<String, u32> = BTreeMap::new();
                let mut waiting: BTreeMap<String, u32> = BTreeMap::new();
                for finding in &s.findings {
                    let row = if finding.state == MarkState::Protected {
                        &mut auto
                    } else {
                        &mut waiting
                    };
                    *row.entry(format!("{:?}", finding.kind)).or_default() += 1;
                }
                (
                    s.protections.len(),
                    s.doc_name.clone(),
                    s.doc_bytes,
                    s.doc_kind,
                    s.pages,
                    s.readable,
                    text.split_whitespace().count(),
                    text.chars().count(),
                    auto,
                    waiting,
                )
            })
            .ok_or(ApiError::InvalidSession)?;
            let (tokens, name, bytes, kind, pages, readable, words, chars, auto, waiting) = report;
            out.push_str(&format!("{:<12}{}\n", "file", file_extension(&name)));
            out.push_str(&format!("{:<12}{} KiB\n", "size", bytes / 1024));
            out.push_str(&format!("{:<12}{kind:?}\n", "kind"));
            out.push_str(&format!("{:<12}{pages}\n", "pages"));
            out.push_str(&format!("{:<12}{words}\n", "words"));
            out.push_str(&format!("{:<12}{chars}\n", "characters"));
            out.push_str(&format!("{:<12}{readable}%\n", "readable"));
            out.push_str(&format!(
                "{:<12}{:<5}{}\n",
                "protected",
                auto.values().sum::<u32>(),
                by_kind(&auto)
            ));
            out.push_str(&format!(
                "{:<12}{:<5}{}\n",
                "waiting",
                waiting.values().sum::<u32>(),
                by_kind(&waiting)
            ));
            out.push_str(&format!("{:<12}{tokens}\n", "tokens"));
        }
    }
    Ok(out)
}

/// `Person ×7, Address ×3` — the kinds counted, with nothing of what they hold.
fn by_kind(counts: &BTreeMap<String, u32>) -> String {
    if counts.is_empty() {
        return String::new();
    }
    let mut rows: Vec<(&String, &u32)> = counts.iter().collect();
    // Most of them first: a report is read top to bottom.
    rows.sort_by(|a, b| b.1.cmp(a.1).then(a.0.cmp(b.0)));
    let named: Vec<String> = rows.iter().map(|(kind, n)| format!("{kind} ×{n}")).collect();
    format!("({})", named.join(", "))
}

/// The file's **extension**, and nothing else of what it is called.
///
/// This began as the file name, with the path stripped off — and the first test
/// of the report caught the mistake: the letter is called `Brief_Weber.txt`, so
/// the report named the person it was written to. A German desktop is full of
/// `Rechnung_Müller.pdf` and `Vertrag Nordstern GmbH.docx`. A report meant to be
/// safe to paste into an e-mail cannot carry a file name, and the only part of
/// one that helps us is the extension.
fn file_extension(name: &str) -> String {
    let last = name.rsplit(['/', '\\']).next().unwrap_or(name);
    match last.rsplit_once('.') {
        Some((before, ext)) if !before.is_empty() && !ext.is_empty() && ext.len() <= 8 => {
            format!(".{}", ext.to_lowercase())
        }
        _ => "(no extension)".to_string(),
    }
}

pub(crate) fn document_view(session: SessionId) -> ApiResult<DocumentView> {
    with_session(session.id, view_of).ok_or(ApiError::InvalidSession)?
}

/// The original text with a mark for everything the scanner has to say about
/// it, in UTF-16 spans for Dart.
///
/// Two kinds, and both matter:
///
/// * **Protected** — replaced on the way out, one per protection.
/// * **Suggested** — an open finding, **still standing in the clear**. Until
///   task 033 these were never emitted at all: `MarkState::Suggested` existed
///   in the type and nothing ever produced one, so the review badge could say
///   «3 need your word» while the document showed no sign of any of them. The
///   truthfulness tests found it by comparing the count with the marks.
fn view_of(s: &mut Session) -> ApiResult<DocumentView> {
    let mut marks = Vec::with_capacity(s.protections.len() + s.findings.len());
    for p in &s.protections {
        let span: Span = text::bytes_to_span(s.original_str(), p.start, p.end)?;
        marks.push(Mark {
            span,
            state: MarkState::Protected,
            token: Some(p.token.clone()),
            kind: p.kind,
            source: p.source,
            decided: p.decided,
            source_detail: p.source_detail.clone(),
            place: s.place_of(p.start),
        });
    }
    for f in &s.findings {
        if f.state != MarkState::Suggested {
            continue;
        }
        // Never over a protection: the drawing must not put two marks on one
        // stretch, and a protected thing is not waiting for anything.
        if s.protections.iter().any(|p| p.start < f.end && f.start < p.end) {
            continue;
        }
        marks.push(Mark {
            span: text::bytes_to_span(s.original_str(), f.start, f.end)?,
            state: MarkState::Suggested,
            // No token: an open suggestion has not been given one, and saying
            // otherwise would be the same class of untruth.
            token: None,
            kind: f.kind,
            source: f.source,
            // Nothing has been decided about an open suggestion — that is what
            // makes it one.
            decided: false,
            source_detail: f.source_detail.clone(),
            place: s.place_of(f.start),
        });
    }
    marks.sort_by_key(|m| m.span.start);
    Ok(DocumentView {
        text: s.original_str().to_string(),
        marks,
        name: s.doc_name.clone(),
        kind: s.doc_kind,
        pages: s.pages,
    })
}

// ---------------------------------------------------------------- payload

pub(crate) fn build_payload(session: SessionId) -> ApiResult<PayloadHandle> {
    // **Read before the payload is built, and stamped into it** — 064d. The
    // session a payload belongs to is a fact about the snapshot, so it is taken
    // at the moment of the snapshot and not looked up again later when the
    // answer could have changed. `None` is a payload built with no session
    // open, which is the state a forgotten question at the exit leaves and the
    // one thing in 064 that used to be invisible.
    let whose = with_core(|core| {
        let number = core.open_conversation?;
        if core.vault.state() != crate::api::VaultState::Unlocked {
            return None;
        }
        core.vault
            .conversations()
            .into_iter()
            .find(|(n, _, _)| *n == number)
            .map(|(number, name, _)| crate::api::PayloadSession { number, name })
    });
    with_session(session.id, |s| {
        if s.original.is_empty() {
            return Err(ApiError::NothingToSend);
        }
        let id = s.take_payload_id();
        let payload = SafePayload::build(s, id, whose);
        // Invariant G3, enforced at run time and not only in the tests: a payload
        // that does not pass its own audit is never handed out.
        payload.audit(s)?;
        let handle = payload.handle();
        s.payloads.insert(id, payload);
        s.trim_payloads();
        Ok(handle)
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn payload_view(handle: PayloadHandle) -> ApiResult<PayloadView> {
    with_payload(handle, |p| p.view())
}

pub(crate) fn send(handle: PayloadHandle, provider: ProviderId) -> ApiResult<AnswerId> {
    // The freshness check happens before anything else: a stale request must not
    // even reach a provider, let alone be posted.
    let _fresh = with_payload(handle, |p| p.id)?;

    // Invariant G12: open suggestions stop a send, whatever the payload was built
    // for. There is no «Send anyway» — the user answers Protect or Not Sensitive,
    // and the count reaches zero. That is the whole reason the switch does not
    // exist in the code.
    let open = with_session(handle.session, |s| s.open_suggestions()).ok_or(ApiError::InvalidSession)?;
    if open > 0 {
        return Err(ApiError::OpenSuggestions { count: open });
    }
    // Everything above held the core's lock briefly and let it go. From here the
    // wire is open, and no lock is held while a provider takes its time.
    let login = login_for(&provider.id)?;
    // The protected path, through the gateway: a handle, never text. The
    // instructions are empty in this call because `send` is the old door and
    // keeps its promise exactly — a workspace that has something to say uses
    // `ask_model`, which is the same gateway with a context.
    let raw = crate::providers::ask(
        handle,
        &provider.id,
        login.credential.expose(),
        &login.base,
        &login.model,
        "",
    )?;

    // The raw answer stays here. What the UI gets is an id; what it can then ask
    // for is the restored view, or the model's own words, both from this store.
    ingest_answer(handle, raw.text)
}

/// The protected door: a handle, a model, and what the workspace has to say.
pub(crate) fn ask_model(
    handle: PayloadHandle,
    provider: ProviderId,
    model: Option<String>,
    workspace: Vec<String>,
    history: Vec<String>,
) -> ApiResult<crate::api::ModelAnswer> {
    // Everything `send` checks, it checks here too, and for the same reasons:
    // a stale payload must not reach a provider, and an open suggestion stops
    // a send with no «anyway» anywhere in the code (G12).
    let _fresh = with_payload(handle, |p| p.id)?;
    let open = with_session(handle.session, |s| s.open_suggestions()).ok_or(ApiError::InvalidSession)?;
    if open > 0 {
        return Err(ApiError::OpenSuggestions { count: open });
    }
    // **A question is text, and text is scanned** (046/N).
    //
    // The owner, 7 October: «ليس لدينا شات — شات مع نموذج… لا يوجد خيار مثلاً
    // مباشرة إلى الشات.» A document used to reach the model bare, with
    // `workspace` and `history` both empty, so whatever came back was the
    // model's own guess at what was wanted. A question travels with it now.
    //
    // And it travels **protected**. This is the one hole big enough to sink
    // the product: the whole promise is that nothing reaches a model
    // unexamined, and a sentence a person typed is not an exception. If he
    // asks «what did Hedvig Palmgren earn?», the name has to leave as the
    // token the document already gave it, or the protection of the document
    // was theatre.
    //
    // It is done **here** rather than in the screen, and that is the whole of
    // why the promise holds: `ask_model` is the only door a question can enter
    // by, so there is no path through which a raw one reaches a provider. A
    // screen that protected its own field would be a second implementation of
    // the scanner, and the first time the two disagreed the quieter one would
    // win.
    let safe = protect_lines(handle.session, workspace)?;
    allow_tokens(handle, &safe.tokens)?;
    let workspace = safe.text;
    let answer = crate::gateway::send(crate::gateway::Request {
        target: crate::gateway::Target {
            provider_id: provider.id.clone(),
            model_id: model,
        },
        task: crate::gateway::Task::Answer,
        context: crate::gateway::Context { workspace, history },
        body: crate::gateway::Body::Protected(handle),
    })?;
    // The answer is kept where every answer is kept, so the restored view and
    // the model's own words are both reachable by id.
    let id = ingest_answer(handle, answer.text.clone())?;
    Ok(crate::api::ModelAnswer {
        answer: Some(id),
        text: answer.text,
        usage: answer.usage,
    })
}

/// **Set the question that travels with this document** (046/N).
///
/// It is protected **here**, when it is set, and not in the payload builder:
/// protecting mints tokens, and `SafePayload::build` holds the session
/// immutably on purpose — the payload is a view of a conversation and may not
/// change it. So the one place that mints is the one place a person decides
/// something.
///
/// What comes back is the protected text, so the screen can show what it just
/// did, and the marks over the **raw** question, so the field can draw them the
/// way the document's own column does. Both are measurements of one act; a
/// screen that worked either of them out for itself would be a second scanner.
pub(crate) fn set_question(session: SessionId, text: String) -> ApiResult<QuestionView> {
    let safe = protect_lines(session.id, vec![text.clone()])?;
    let question_safe = safe.text.first().cloned().unwrap_or_default();
    let tokens = safe.tokens.clone();
    with_session(session.id, |s| {
        s.question = crate::secret::Secret::new(text.clone());
        s.question_safe = question_safe.clone();
        s.question_tokens = tokens.clone();
    })
    .ok_or(ApiError::InvalidSession)?;
    // A new question is a new thing that would leave, so a payload built
    // before it is stale: the Safe column must not show yesterday's request,
    // and a handle from before it must not be sendable. `bump` is the same
    // call every act that changes the document makes.
    with_session(session.id, |s| s.bump()).ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    Ok(QuestionView {
        text: question_safe,
        marks: safe.marks.first().cloned().unwrap_or_default(),
    })
}

/// The question as it stands: what was typed, and what would leave.
pub(crate) fn question(session: SessionId) -> ApiResult<QuestionView> {
    with_session(session.id, |s| QuestionView {
        text: s.question_safe.clone(),
        marks: Vec::new(),
    })
    .ok_or(ApiError::InvalidSession)
}

/// What `protect_lines` found: the safe text, the marks over the original, and
/// the tokens it used.
pub(crate) struct ProtectedLines {
    pub text: Vec<String>,
    pub marks: Vec<Vec<Mark>>,
    pub tokens: Vec<String>,
}

/// Protect every line a person typed, against this session's own knowledge.
///
/// The same layers the document was read with — the general shapes, the active
/// packs, the vault's values, the person's own lists — because a question read
/// by a weaker set of rules would be a second, quieter standard for the same
/// text (046/N).
///
/// **One value, one token.** `token_for` is asked first, so a name the document
/// already replaced leaves the question as the *same* token: the model has to
/// be able to see that the person is asking about somebody who appears in the
/// sheet, and two tokens for one person would make the question unanswerable
/// as well as unprotected.
///
/// A new value — one that is in the question and nowhere in the document —
/// gets a token of its own, and that token is added to the payload's allowed
/// list so the answer can be restored through it.
///
/// **Everything found is replaced, whether the scan was sure or not.** A
/// question is typed in the moment and must not open a second review queue
/// beside the document's: that would be a way around the gate, which 046/N is
/// explicitly forbidden to touch. Over-protecting is never a leak — the worst
/// case is a token where a person wanted a word — and the asymmetry 046/L drew
/// is the same one.
fn protect_lines(session: u32, lines: Vec<String>) -> ApiResult<ProtectedLines> {
    name_tokens_from_the_vault(session);
    if lines.iter().all(|l| l.trim().is_empty()) {
        let marks = lines.iter().map(|_| Vec::new()).collect();
        return Ok(ProtectedLines { text: lines, marks, tokens: Vec::new() });
    }
    let (sets, taught, hints, exceptions, names) = with_core(|core| {
        let (s, vault) = core.session_and_vault(session).ok_or(ApiError::InvalidSession)?;
        let sets = active_sets(s, vault);
        let profile = s.profile_id.clone();
        Ok((
            sets,
            vault.label_rules(profile.as_deref()),
            vault.hints(profile.as_deref()),
            vault.exceptions(profile.as_deref()),
            vault.taught_names(profile.as_deref()),
        ))
    })?;

    // **What this document has already protected is knowledge too.**
    //
    // «Hedvig Palmgren» is protected in the sheet because «Prepared by:» names
    // her there. In the question «what did Hedvig Palmgren earn?» there is no
    // label and her name is in no list we ship, so the scanner finds nothing —
    // and without this pass the name left in the clear **while the document's
    // copy of it was a token**. Protected on one line and bare on the next is
    // worse than either: it tells the model exactly which token the name
    // belongs to.
    let known: Vec<(String, String, Kind)> = with_core(|core| {
        let s = core.get(session).ok_or(ApiError::InvalidSession)?;
        Ok(s
            .tokens
            .all_secrets()
            .into_iter()
            .filter_map(|v| {
                let token = s.tokens.token_for(&v)?.to_string();
                let kind = s.tokens.get(&token)?.kind;
                Some((v, token, kind))
            })
            .collect())
    })?;

    let mut out = Vec::with_capacity(lines.len());
    let mut all_marks = Vec::with_capacity(lines.len());
    let mut minted: Vec<String> = Vec::new();
    for raw in &lines {
        // **One walk over the text the person typed.**
        //
        // The first version of this rewrote the line with the known values and
        // then ran the scanner over the rewritten line, which produced the
        // right text and **no marks at all** for a known value — and offsets
        // over a string the person had never seen for the rest. Both halves are
        // gathered as spans over the raw line instead, and the substitution
        // happens once, at the end.
        let mut hits: Vec<(usize, usize, Kind, Option<String>, Source, String)> = Vec::new();
        for (value, token, kind) in &known {
            if value.trim().is_empty() {
                continue;
            }
            for (start, end) in crate::text::occurrences(raw, value) {
                hits.push((
                    start,
                    end,
                    *kind,
                    Some(token.clone()),
                    Source::Vault,
                    "already protected in this document".to_string(),
                ));
            }
        }
        for c in scanner::scan(raw, &sets, &taught, &hints, &exceptions, &names) {
            hits.push((c.start, c.end, c.kind, None, c.source, c.source_detail.clone()));
        }
        // Longest first at the same start, and a value we already have a token
        // for wins a tie: it is certain, and reusing its token is what makes
        // the question answerable as well as safe.
        hits.sort_by_key(|(s, e, _, t, _, _)| (*s, std::cmp::Reverse(*e - *s), t.is_none()));

        let mut safe = String::with_capacity(raw.len());
        let mut marks: Vec<Mark> = Vec::new();
        let mut cursor = 0usize;
        for (start, end, kind, existing, source, detail) in hits {
            if start < cursor || end > raw.len() || start >= end {
                continue;
            }
            let (Some(before), Some(value)) = (raw.get(cursor..start), raw.get(start..end)) else {
                continue;
            };
            safe.push_str(before);
            let token = match existing {
                Some(t) => t,
                None => with_core(|core| {
                    let s = core.get(session).ok_or(ApiError::InvalidSession)?;
                    if let Some(already) = s.tokens.token_for(value) {
                        return Ok(already.to_string());
                    }
                    let fresh = s.mint.mint(kind, value, &s.tokens);
                    s.tokens.insert(
                        fresh.clone(),
                        crate::tokens::TokenEntry {
                            value: crate::secret::Secret::new(value.to_string()),
                            aliases: Vec::new(),
                            kind,
                            // The question belongs to this conversation and to
                            // no document, so nothing here is written to the
                            // vault: asking about a name is not teaching it.
                            scope: Scope::Conversation,
                            source,
                            decided: false,
                            source_detail: detail.clone(),
                        },
                    );
                    Ok(fresh)
                })?,
            };
            if !minted.contains(&token) {
                minted.push(token.clone());
            }
            safe.push_str(&token);
            if let Ok(span) = crate::text::bytes_to_span(raw, start, end) {
                marks.push(Mark {
                    span,
                    state: MarkState::Protected,
                    token: Some(token),
                    kind,
                    source,
                    source_detail: detail,
                    decided: false,
                    // A question has no pages and no paragraphs: it is one line
                    // a person typed, and «page 1» about it would be a number
                    // with nothing behind it.
                    place: None,
                });
            }
            cursor = end;
        }
        if let Some(rest) = raw.get(cursor..) {
            safe.push_str(rest);
        }
        out.push(safe);
        all_marks.push(marks);
    }

    Ok(ProtectedLines { text: out, marks: all_marks, tokens: minted })
}

/// **The answer may echo a token this text introduced**, and a token the
/// payload does not allow is not restored — `restore` reads
/// `allowed_token_ids` and leaves anything else exactly as the model wrote it.
/// So the payload learns them, or a person would read their own token back in
/// the answer instead of the name it stands for.
fn allow_tokens(handle: PayloadHandle, tokens: &[String]) -> ApiResult<()> {
    if tokens.is_empty() {
        return Ok(());
    }
    with_core(|core| {
        let s = core.get(handle.session).ok_or(ApiError::InvalidSession)?;
        let payload = s.payloads.get_mut(&handle.id).ok_or(ApiError::InvalidHandle)?;
        for token in tokens {
            if !payload.allowed_token_ids.iter().any(|t| t == token) {
                payload.allowed_token_ids.push(token.clone());
            }
        }
        Ok(())
    })
}

/// The direct door: text the person chose to send as it stands.
///
/// It takes a session so that the refusal can be about this workspace, and it
/// touches nothing in it: nothing is built, nothing is consumed, and no answer
/// is stored, because there is no payload to restore an answer against.
pub(crate) fn ask_model_directly(
    session: SessionId,
    text: String,
    provider: ProviderId,
    model: Option<String>,
    workspace: Vec<String>,
    history: Vec<String>,
) -> ApiResult<crate::api::ModelAnswer> {
    if with_session(session.id, |s| s.id).is_none() {
        return Err(ApiError::InvalidSession);
    }
    if text.trim().is_empty() {
        return Err(ApiError::InputRefused {
            reason: "there is nothing to send".to_string(),
        });
    }
    // Taken before the text is moved into the request: what is recorded is the
    // thing that was sent, from the same variable, so the record and the wire
    // cannot be given two different documents.
    let kept = text.clone();
    let answer = crate::gateway::send(crate::gateway::Request {
        target: crate::gateway::Target {
            provider_id: provider.id.clone(),
            model_id: model,
        },
        task: crate::gateway::Task::Answer,
        context: crate::gateway::Context { workspace, history },
        body: crate::gateway::Body::Direct(zeroize::Zeroizing::new(text)),
    })?;
    // **Direct Mode is a conversation too** — the owner's rule is that a
    // conversation inside the app is kept whole in its session, and this door
    // is inside the app.
    //
    // Its own write rather than the shared one, because this path has no
    // handle and stores no answer record: there is nothing to restore against.
    // So the allowed list is empty, which is the truth and not a gap — the
    // text left as it stands, and what is kept is exactly what left.
    let open = with_core(|core| core.open_conversation);
    if let Some(number) = open {
        with_core(|core| {
            crate::ops::conversation::record_in(core, number, kept, answer.text.clone(), Vec::new())
        })?;
    }
    Ok(crate::api::ModelAnswer {
        answer: None,
        text: answer.text,
        usage: answer.usage,
    })
}

// ---------------------------------------------------------------- providers (M6)

/// Every provider this build knows, and whether it can be used right now.
///
/// There is no function anywhere in the contract that returns a credential. This
/// is the only thing the UI learns about one: that it exists, and whether it will
/// still exist tomorrow.
/// Every model this build can offer, from every provider's own list.
///
/// Built from the same two facts the provider list is built from — what the
/// provider says it offers, and whether this run can reach it — so a model
/// cannot be «available» on one screen and not on another.
pub(crate) fn models() -> ApiResult<Vec<crate::api::ModelDescriptor>> {
    let connected: Vec<(String, bool)> = providers()?
        .into_iter()
        .map(|row| (row.id, row.connected))
        .collect();
    let mut out = Vec::new();
    for provider in crate::providers::known() {
        let base = provider.default_base();
        let reachable = connected
            .iter()
            .find(|(id, _)| id == provider.id())
            .is_some_and(|(_, ok)| *ok);
        for model in provider.models() {
            out.push(crate::api::ModelDescriptor {
                provider_id: provider.id().to_string(),
                model_id: model.id.to_string(),
                display_name: model.display.to_string(),
                capabilities: model.capabilities.to_vec(),
                context_k: model.context_k,
                credential_required: provider.credential_required(base),
                available: reachable,
            });
        }
    }
    Ok(out)
}

pub(crate) fn providers() -> ApiResult<Vec<ProviderRow>> {
    let mut rows = Vec::new();
    for provider in crate::providers::known() {
        let sealed = login_in_vault(provider.id());
        let in_session = with_core(|core| core.session_logins.get(provider.id()).cloned());
        let login = sealed.clone().or_else(|| in_session.clone());
        let connected = login
            .as_ref()
            .is_some_and(|l| login_is_usable(provider.as_ref(), l));
        rows.push(ProviderRow {
            id: provider.id().to_string(),
            label: provider.label().to_string(),
            connected,
            // Asked of the credential, not of the record that carries it: a
            // keyless local login is not «a key kept for this run only».
            session_only: connected
                && sealed.is_none()
                && in_session.as_ref().is_some_and(holds_credential),
            base_url: login
                .as_ref()
                .map(|l| l.base.clone())
                .unwrap_or_else(|| provider.default_base().to_string()),
            model: login
                .as_ref()
                .map(|l| l.model.clone())
                .unwrap_or_else(|| provider.default_model().to_string()),
            // Asked of the provider, at this address. Not a rule of the world.
            credential_required: provider.credential_required(
                login
                    .as_ref()
                    .map(|l| l.base.as_str())
                    .unwrap_or_else(|| provider.default_base()),
            ),
        });
    }
    Ok(rows)
}

/// Hand a provider its credential.
///
/// Where it goes is decided by one thing only: whether a vault is open.
///
/// * open   → into the vault, sealed, and it is there next time.
/// * locked → into memory for this run, and the row says `session_only`.
///
/// There is no third case. The owner's rule was explicit: no fallback to a file,
/// so either the credential is encrypted or it is told to the user as temporary.
pub(crate) fn connect_provider(provider: ProviderId, credential: String, base_url: Option<String>, model: Option<String>) -> ApiResult<ProviderRow> {
    let known = crate::providers::find(&provider.id)?;
    let credential = credential.trim().to_string();
    let base = base_url
        .map(|b| b.trim().to_string())
        .filter(|b| !b.is_empty())
        .unwrap_or_else(|| known.default_base().to_string());
    // The address is checked before the credential is stored, so that a typo is
    // an error the user sees now rather than the first time they press Send.
    crate::providers::check_url_for(&base)?;
    let bound_to = crate::providers::destination_of(&base)?;
    // A model on this machine needs no credential, and refusing to connect to
    // one for want of a key would shut the most private door in the product.
    // Everywhere else, an empty credential connects nothing and says so.
    if credential.is_empty() && known.credential_required(&base) {
        return Err(ApiError::InputRefused {
            reason: format!(
                "{} needs a credential at that address; a model on this machine does not",
                known.label()
            ),
        });
    }

    let login = ProviderLogin {
        credential: Secret::new(credential),
        base,
        bound_to,
        model: model
            .map(|m| m.trim().to_string())
            .filter(|m| !m.is_empty())
            .unwrap_or_else(|| known.default_model().to_string()),
    };
    let id = provider.id.clone();
    let sealed = with_core(|core| {
        core.vault
            .with_open_mut(|vault| {
                vault.provider_logins.insert(id.clone(), login.clone());
                Ok(())
            })
            .is_ok()
    });
    if !sealed {
        with_core(|core| core.session_logins.insert(provider.id.clone(), login));
    } else {
        // Sealed now, so the memory copy would only be a second place to leak from.
        with_core(|core| core.session_logins.remove(&provider.id));
    }
    crate::session::bump_truth();
    row_for(&provider.id)
}

/// Change the address or the model.
///
/// The UI cannot pass a credential back — it never had one — so changing an
/// endpoint writes the new destination without quietly moving the old key to it.
/// Changing only the model keeps the credential where it is.
pub(crate) fn configure_provider(provider: ProviderId, base_url: Option<String>, model: Option<String>) -> ApiResult<ProviderRow> {
    let known = crate::providers::find(&provider.id)?;
    let existing = login_in_vault(&provider.id)
        .or_else(|| with_core(|core| core.session_logins.get(&provider.id).cloned()));

    let base = base_url
        .map(|b| b.trim().to_string())
        .filter(|b| !b.is_empty())
        .or_else(|| existing.as_ref().map(|l| l.base.clone()))
        .unwrap_or_else(|| known.default_base().to_string());
    crate::providers::check_url_for(&base)?;
    let bound_to = crate::providers::destination_of(&base)?;

    let login = match existing {
        Some(l) => {
            let already_usable = login_is_usable(known.as_ref(), &l);
            let same_destination = l.bound_to == bound_to;
            let has_credential = !l.credential.expose().is_empty();
            let valid_without_credential = !has_credential && already_usable && !known.credential_required(&base);
            let (credential, bound_to) = if same_destination || valid_without_credential {
                (l.credential.clone(), bound_to)
            } else {
                (Secret::new(String::new()), l.bound_to)
            };
            ProviderLogin {
                credential,
                base,
                bound_to,
                model: model
                    .map(|m| m.trim().to_string())
                    .filter(|m| !m.is_empty())
                    .unwrap_or(l.model),
            }
        }
        // Nothing stored yet. A provider that needs no credential at this
        // address can be set up here; anywhere else this is «connect first».
        None if !known.credential_required(&base) => ProviderLogin {
            credential: Secret::new(String::new()),
            base,
            bound_to,
            model: model
                .map(|m| m.trim().to_string())
                .filter(|m| !m.is_empty())
                .unwrap_or_else(|| known.default_model().to_string()),
        },
        None => return Err(crate::providers::not_connected(&provider.id)),
    };

    let id = provider.id.clone();
    let sealed = with_core(|core| {
        core.vault
            .with_open_mut(|vault| {
                vault.provider_logins.insert(id.clone(), login.clone());
                Ok(())
            })
            .is_ok()
    });
    if !sealed {
        with_core(|core| core.session_logins.insert(provider.id.clone(), login));
    }
    row_for(&provider.id)
}

/// Forget a credential — in the vault and in memory both, in one call.
pub(crate) fn disconnect_provider(provider: ProviderId) -> ApiResult<ProviderRow> {
    let _known = crate::providers::find(&provider.id)?;
    let id = provider.id.clone();
    with_core(|core| {
        let _ = core.vault.with_open_mut(|vault| {
            vault.provider_logins.remove(&id);
            Ok(())
        });
        core.session_logins.remove(&id);
    });
    row_for(&provider.id)
}

/// Ask a provider to answer the word `ping`, and time it.
pub(crate) fn test_provider(provider: ProviderId) -> ApiResult<u32> {
    let login = login_for(&provider.id)?;
    crate::providers::ping(
        &provider.id,
        login.credential.expose(),
        &login.base,
        &login.model,
    )
}

/// The vault's copy, if the vault is open. A locked vault answers «nothing here»
/// rather than an error: the credential simply is not available, which is the
/// same shape as never having been given.
pub(crate) fn login_in_vault(id: &str) -> Option<ProviderLogin> {
    with_core(|core| core.vault.with_open(|vault| vault.provider_logins.get(id).cloned()).ok().flatten())
}

/// The credential to use: the vault's if it is open, this run's otherwise.
pub(crate) fn login_for(id: &str) -> ApiResult<ProviderLogin> {
    let found = login_in_vault(id).or_else(|| with_core(|core| core.session_logins.get(id).cloned()));
    let login = found.ok_or_else(|| crate::providers::not_connected(id))?;
    let provider = crate::providers::find(id)?;
    if !login_is_usable(provider.as_ref(), &login) {
        return Err(crate::providers::not_connected(id));
    }
    Ok(login)
}

/// Does this login actually hold a credential?
///
/// A login record is **not** a credential. A model on this machine is stored
/// with an empty one, so «a record exists» and «a key is held» are two facts,
/// and every sentence that says where a key lives has to ask this one — or it
/// tells a person their vault is holding something it has never seen.
pub(crate) fn holds_credential(login: &ProviderLogin) -> bool {
    !login.credential.expose().is_empty()
}

pub(crate) fn login_is_usable(provider: &dyn crate::providers::Provider, login: &ProviderLogin) -> bool {
    if crate::providers::destination_of(&login.base).ok().as_deref() != Some(login.bound_to.as_str()) {
        return false;
    }
    !login.credential.expose().is_empty() || !provider.credential_required(&login.base)
}

fn row_for(id: &str) -> ApiResult<ProviderRow> {
    providers()?
        .into_iter()
        .find(|r| r.id == id)
        .ok_or_else(|| ApiError::ProviderUnavailable { provider: id.to_string() })
}

/// Look a handle up and check it twice: the stored payload must be built on the
/// session's current revision, and the handle itself must name that same
/// revision. The store is trusted, never the handle.
pub(crate) fn with_payload<R>(handle: PayloadHandle, f: impl FnOnce(&SafePayload) -> R) -> ApiResult<R> {
    with_session(handle.session, |s| {
        let revision = s.revision;
        let payload = s.payloads.get(&handle.id).ok_or(ApiError::InvalidHandle)?;
        payload.check_fresh(revision)?;
        if handle.revision != payload.revision {
            return Err(ApiError::StalePayload {
                expected: revision,
                got: handle.revision,
            });
        }
        Ok(f(payload))
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn reserve_payload_for_send<R>(handle: PayloadHandle, f: impl FnOnce(&SafePayload) -> R) -> ApiResult<R> {
    with_session(handle.session, |s| {
        let revision = s.revision;
        let payload = s.payloads.get_mut(&handle.id).ok_or(ApiError::InvalidHandle)?;
        payload.reserve_send(revision, handle.revision)?;
        Ok(f(payload))
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn finish_payload_send(handle: PayloadHandle, consume: bool) {
    with_session(handle.session, |s| {
        if let Some(payload) = s.payloads.get_mut(&handle.id) {
            payload.finish_send(consume);
        }
    });
}

pub(crate) fn with_payload_record<R>(handle: PayloadHandle, f: impl FnOnce(&SafePayload) -> R) -> ApiResult<R> {
    with_session(handle.session, |s| {
        let payload = s.payloads.get(&handle.id).ok_or(ApiError::InvalidHandle)?;
        if handle.revision != payload.revision {
            return Err(ApiError::StalePayload {
                expected: payload.revision,
                got: handle.revision,
            });
        }
        Ok(f(payload))
    })
    .ok_or(ApiError::InvalidSession)?
}

// ---------------------------------------------------------------- protect

/// Read a selection without touching it.
///
/// Everything the Protect button needs to choose among its five states, decided
/// here rather than in a widget: the same code that would do the protecting
/// answers what it *would* do.
pub(crate) fn inspect_selection(session: SessionId, span: Span) -> ApiResult<SelectionView> {
    with_core(|core| {
        let vault_hints = {
            let profile = core.get(session.id).and_then(|s| s.profile_id.clone());
            core.vault.hints(profile.as_deref())
        };
        let vault_exceptions = {
            let profile = core.get(session.id).and_then(|s| s.profile_id.clone());
            core.vault.exceptions(profile.as_deref())
        };
        let vault_names = {
            let profile = core.get(session.id).and_then(|s| s.profile_id.clone());
            core.vault.taught_names(profile.as_deref())
        };
        let s = core.get(session.id).ok_or(ApiError::InvalidSession)?;
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        let selected = s
            .original_str()
            .get(start..end)
            .ok_or_else(|| ApiError::BadSpan {
                reason: "the selection is not on a character boundary".to_string(),
            })?
            .to_string();

        if selected.trim().is_empty() {
            return Ok(SelectionView {
                empty: true,
                kind: Kind::Custom,
                matches: 0,
                protected_as: None,
                protected_by: None,
                protected_detail: String::new(),
                entities: Vec::new(),
                snaps_to: Vec::new(),
                word_span: span,
                also_before: None,
            });
        }

        // What Protect will really take, and the offer beside it. Worked out
        // here so the bubble can draw the truth before anything is pressed.
        let (word_start, word_end) = text::whole_words(s.original_str(), start, end);
        let (word_start, word_end) = if word_start < word_end {
            (word_start, word_end)
        } else {
            (start, end)
        };
        let word_span = text::bytes_to_span(s.original_str(), word_start, word_end)?;
        let also_before = text::capitalised_word_before(s.original_str(), word_start)
            .map(|(b, e)| text::bytes_to_span(s.original_str(), b, e))
            .transpose()?;

        // What it touches. Exactly one, exactly covering it, is «already
        // protected»; anything else that overlaps means Protect would snap.
        let touched: Vec<Protection> = s
            .protections
            .iter()
            .filter(|p| p.start < end && start < p.end)
            .cloned()
            .collect();
        let exact = touched
            .iter()
            .find(|p| p.start == start && p.end == end)
            .filter(|_| touched.len() == 1);

        let mut snaps_to = Vec::new();
        if exact.is_none() {
            for p in &touched {
                snaps_to.push(text::bytes_to_span(s.original_str(), p.start, p.end)?);
            }
        }

        // The pack's guess, from the pack — never from the screen. In order:
        //
        // 1. a finding or a protection that covers *exactly* this stretch. This
        //    is the best answer because it came from a scan of the whole
        //    document, and the German pack's rules are contextual: «Thomas
        //    Müller» is a name because «Herr» stood before it, and that word is
        //    outside the selection.
        // 2. the scanner run over the selected text alone — which catches an
        //    IBAN or an e-mail in text no scan has looked at.
        // 3. a mark that merely overlaps, as a last resort.
        //
        // Anything else is `Custom`, and the user picks. A wrong guess is worse
        // than no guess: the kind travels inside the token, and the model reads it.
        let exact_kind = s
            .protections
            .iter()
            .find(|p| p.start == start && p.end == end)
            .map(|p| p.kind)
            .or_else(|| {
                s.findings
                    .iter()
                    .find(|f| f.start == start && f.end == end)
                    .map(|f| f.kind)
            });
        let guessed = exact_kind.or_else(|| {
            scanner::scan(&selected, std::slice::from_ref(&s.pack_id), &[], &vault_hints, &vault_exceptions, &vault_names)
                .into_iter()
                .find(|c| c.start == 0 && c.end == selected.len())
                .map(|c| c.kind)
        });

        let from_mark = s
            .protections
            .iter()
            .find(|p| p.start < end && start < p.end)
            .map(|p| p.kind)
            .or_else(|| {
                s.findings
                    .iter()
                    .find(|f| f.start < end && start < f.end)
                    .map(|f| f.kind)
            });

        let entities: Vec<String> = vault_hints
            .iter()
            .filter(|h| text::nfc(&h.text) == text::nfc(&selected))
            .map(|h| h.entity_handle.clone())
            .collect();

        Ok(SelectionView {
            empty: false,
            kind: guessed.or(from_mark).or_else(|| looks_like_a_person(&selected)).unwrap_or(Kind::Custom),
            matches: text::occurrences(s.original_str(), &selected).len() as u32,
            protected_as: exact.map(|p| p.token.clone()),
            protected_by: exact.map(|p| p.source),
            protected_detail: exact.map(|p| p.source_detail.clone()).unwrap_or_default(),
            entities,
            snaps_to,
            word_span,
            also_before,
        })
    })
}

/// One or two capitalised words, and nothing else in them.
///
/// 041-P, from the owner's live run: his hand-made protections went out as
/// `CUSTOM`, and a model reads `PERSON`. The dialog has to offer *something*
/// first, and when a person draws a line round «Björn Sandström» the honest
/// default is a person — not because the app knows, but because this is the
/// commonest thing a hand selects in a letter, and the dialog is where it is
/// confirmed or changed before anything happens.
///
/// It is the **last** guess, after the pack, the finding under the selection
/// and the mark that overlaps it. Each of those knows more than this does.
/// Three words or more is prose, a lower-case word is a word, and anything
/// carrying a digit or a mark is not a name — all of those stay `Custom`.
fn looks_like_a_person(selected: &str) -> Option<Kind> {
    let words: Vec<&str> = selected.split_whitespace().collect();
    if words.is_empty() || words.len() > 2 {
        return None;
    }
    for word in &words {
        let mut chars = word.chars();
        match chars.next() {
            Some(first) if first.is_uppercase() => {}
            _ => return None,
        }
        // A hyphen inside a name is a name — «Al-Hassan», «Marie-Luise» — and
        // everything else that is not a letter says this is not one.
        if !chars.all(|c| c.is_alphabetic() || c == '-' || c == '\'') {
            return None;
        }
    }
    Some(Kind::Person)
}

/// Why is this protected?
///
/// Built from what the core already knows and has never put together in one
/// place: the protection says who found it and who decided it, the finding
/// under it says the particulars and who else agreed, and the vault says when
/// it was taught and under which identity.
pub(crate) fn explain(session: SessionId, span: Span) -> ApiResult<Explanation> {
    // The vault is read first and separately: reading it inside the session
    // lock would be a lock inside a lock (G19).
    let known = vault_facts_for(session, span)?;
    // Same reason, same shape: the taught rules' scopes are read here, outside
    // the session lock, and looked up as plain data inside it.
    let taught_scopes = taught_rule_scopes();
    with_session(session.id, |s| {
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        let p = s
            .protections
            .iter()
            .find(|p| p.start < end && start < p.end)
            .ok_or_else(|| ApiError::BadSpan {
                reason: "nothing is protected there".to_string(),
            })?
            .clone();
        let finding = s.findings.iter().find(|f| f.start < p.end && p.start < f.end).cloned();

        // A rule the person taught reaches here as `Source::Hand`, because
        // they decided it — but «You protected this by hand» would be false:
        // they did not select these words, they taught a word to look for.
        let taught_rule = p.source == Source::Hand && p.source_detail.starts_with("you:");
        // The rule's own reach, read from the vault by the id inside the
        // detail («you:u3»), so the card answers about the rule rather than
        // about the protection the rule happened to produce here.
        let taught_scope = if taught_rule {
            p.source_detail
                .strip_prefix("you:u")
                .and_then(|n| n.parse::<u32>().ok())
                .and_then(|id| taught_scopes.get(&id).cloned())
        } else {
            None
        };
        // And the set is read from the finding, never assumed. This line said
        // «A German privacy rule» whatever fired, which was true only while
        // German was the only set there was — the «0 tries left» shape exactly.
        let set_label = set_label_of(&p.source_detail);
        let headline = match (p.source, p.decided) {
            _ if taught_rule => "You taught Z Privacy this rule".to_string(),
            (Source::Hand, _) => "You protected this by hand".to_string(),
            (Source::Vault, _) => "You taught Z Privacy this value".to_string(),
            (Source::LanguagePack, true) => format!("{set_label} found it, and you agreed"),
            (Source::LanguagePack, false) => set_label,
            (Source::GeneralRule, true) => "A shape that needs no language, and you agreed".to_string(),
            (Source::GeneralRule, false) => "A shape that needs no language".to_string(),
        };

        // The particulars. A protection with nothing to say about itself is the
        // black box arriving, so this is never allowed to come out empty.
        let mut because = Vec::new();
        if let Some(f) = &finding {
            because.push(f.reason.clone());
            for other in &f.also {
                because.push(format!("{other} agreed as well"));
            }
            if !f.also.is_empty() {
                because.insert(0, format!("{} rules agree", f.also.len() + 1));
            }
        } else if p.source == Source::Hand {
            because.push("You selected these words yourself".to_string());
        }
        if let Some(when) = known.as_ref().map(|k| k.learned_at).filter(|w| *w > 0) {
            because.push(format!("Kept in your vault since {}", day_of(when)));
        }
        if because.is_empty() {
            because.push(p.source_detail.clone());
        }
        if p.orphaned {
            // Said plainly, because it is the one case where the reason a thing
            // was protected no longer exists and the protection does.
            because.push(
                // Wrapped with «\\», which is the only way: without it the
                // newline and the indentation after it are **in the sentence**,
                // and this one carried two holes of eighteen spaces each onto
                // the Why card (046/D).
                "What found this no longer claims it — the value was forgotten, or the pack \
                 changed. It stays protected here so that taking it back does not expose it. \
                 «Remove protection» is the way to take it back."
                    .to_string(),
            );
        }

        // «Where it applies» names a **reach**, never a client. Neither the
        // profile id nor its display name appears here: the name belongs where
        // a person chooses or manages a profile, and repeating it in an
        // explanation is the EXPOSURE rule broken for no gain.
        let applies = if taught_rule {
            // A taught rule's reach is the rule's own scope, not the scope of
            // the protection it produced in this document.
            taught_scope.clone().unwrap_or_else(|| "Everywhere".to_string())
        } else {
            match p.scope {
                Scope::Once => "This one place".to_string(),
                Scope::Conversation => "This conversation".to_string(),
                Scope::Profile => match &s.profile_id {
                    Some(_) => "This profile".to_string(),
                    None => "This conversation".to_string(),
                },
                Scope::Always => "Everywhere".to_string(),
            }
        };

        Ok(Explanation {
            headline,
            because,
            kind: p.kind,
            scope: p.scope,
            applies,
            // A rule the person taught **was** decided by them — once, when
            // they taught the word. «Z Privacy, on its own» under a headline
            // that says «You taught Z Privacy this rule» is one card calling
            // itself a liar.
            decided: p.decided || taught_rule,
            token: p.token.clone(),
            learned_at: known.as_ref().map(|k| k.learned_at).unwrap_or(0),
            entity: known.as_ref().map(|k| k.entity),
            value_id: known.as_ref().map(|k| k.value_id),
            // The reach of what «Forget» would act on. Read from the vault
            // beside the value itself, so the button's name and the act's
            // breadth cannot come to disagree.
            taught_reach: known.as_ref().map(|k| {
                if k.in_profile {
                    TaughtReach::ThisProfile
                } else {
                    TaughtReach::Everywhere
                }
            }),
            aliases: known.map(|k| k.aliases).unwrap_or_default(),
        })
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) struct KnownValue {
    pub entity: u32,
    pub value_id: u32,
    pub learned_at: u64,
    pub aliases: Vec<String>,
    /// Does the identity holding it belong to a profile? The reach of the
    /// knowledge, which is not the reach of the protection standing over it.
    pub in_profile: bool,
}

/// What the vault knows about the text in this span, if anything.
fn vault_facts_for(session: SessionId, span: Span) -> ApiResult<Option<KnownValue>> {
    let text = with_session(session.id, |s| {
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        Ok(s.original_str().get(start..end).unwrap_or_default().to_string())
    })
    .ok_or(ApiError::InvalidSession)??;
    Ok(crate::ops::value_matching(&text))
}

/// A date a person can read, without a calendar dependency: the civil date from
/// days since 1970, by the standard algorithm.
fn day_of(seconds: u64) -> String {
    const MONTHS: [&str; 12] = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    let days = (seconds / 86_400) as i64 + 719_468;
    let era = if days >= 0 { days } else { days - 146_096 } / 146_097;
    let doe = days - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = if m <= 2 { y + 1 } else { y };
    let month = MONTHS.get((m as usize).saturating_sub(1)).copied().unwrap_or("?");
    format!("{d} {month} {year}")
}

/// What a selection drawn with a mouse actually covers.
///
/// 041-K: the pointer lands after the first character at the left margin, so a
/// name selected at the start of a line used to be protected from its *second*
/// letter — `J__Z_…`, with the J still in the text. Every path that turns a
/// selection into an act goes through here first, so the rule is one rule and
/// not three, and a caller that is already exact gets its own span back.
pub(crate) fn as_whole_words(session: SessionId, span: Span) -> ApiResult<Span> {
    with_session(session.id, |s| {
        let text = s.original_str();
        let (start, end) = text::span_to_bytes(text, span)?;
        let (start, end) = text::whole_words(text, start, end);
        if start >= end {
            // Nothing but marks and space: leave it as drawn and let the act
            // refuse it with its own sentence.
            return Ok(span);
        }
        text::bytes_to_span(text, start, end)
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn protect(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    let span = as_whole_words(session, span)?;
    // The scope decides the breadth. Until task 034 it was only a label — the
    // breadth came from which function was called — so «this conversation»
    // could protect one place and «always» could reach nothing at all.
    if matches!(scope, Scope::Always | Scope::Profile) {
        require_open_vault()?;
    }
    remember_in_vault(session, span, scope, kind)?;
    let every_place = !matches!(scope, Scope::Once);
    let outcome = protect_inner(session, span, scope, kind, every_place)?;
    crate::session::bump_truth();
    Ok(outcome)
}

/// `Profile` and `Always` are promises about **tomorrow**, and a promise about
/// tomorrow has to be written down. Both put the value in the vault; they differ
/// only in whether it belongs to this profile or to every one.
///
/// The vault must be open, and the refusal says so rather than protecting here
/// and quietly failing the part the user actually asked for.
fn remember_in_vault(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<()> {
    let profile_only = match scope {
        Scope::Profile => true,
        Scope::Always => false,
        _ => return Ok(()),
    };
    let (text, profile) = with_session(session.id, |s| {
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        let text = s
            .original_str()
            .get(start..end)
            .ok_or_else(|| ApiError::BadSpan {
                reason: "the selection is not on a character boundary".to_string(),
            })?
            .to_string();
        Ok((text, s.profile_id.clone()))
    })
    .ok_or(ApiError::InvalidSession)??;

    if profile_only && profile.is_none() {
        return Err(ApiError::InputRefused {
            // The sentence 046/D was written for: nineteen spaces sat between
            // «it» and «for», because the literal was wrapped across two lines
            // with no «\\» to eat the newline and the indentation.
            reason: "this conversation is not in a profile, so there is no profile to remember \
                     it for — choose «always», or open a profile first"
                .to_string(),
        });
    }
    let wanted = if profile_only { profile } else { None };
    crate::ops::learn_value(wanted, kind, text)
}

pub(crate) fn protect_all_matches(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    let span = as_whole_words(session, span)?;
    if matches!(scope, Scope::Always | Scope::Profile) {
        require_open_vault()?;
    }
    remember_in_vault(session, span, scope, kind)?;
    let outcome = protect_inner(session, span, scope, kind, true)?;
    crate::session::bump_truth();
    Ok(outcome)
}

/// The lines of this document, as byte ranges, newline not included.
fn line_ranges(text: &str) -> Vec<(usize, usize)> {
    let mut out = Vec::new();
    let mut at = 0usize;
    for line in text.split('\n') {
        out.push((at, at + line.len()));
        at += line.len() + 1;
    }
    out
}

/// The runs of a line, split on **two or more spaces or a tab**.
///
/// One space groups a number and two separate a column — 046/M drew that line
/// for a run of words and 048 measured it on the owner's own bank statement,
/// where every gap the PDF reader emits is exactly two spaces. It is the only
/// thing about a table that survives his reader, which is why the cell is
/// identified by its **order** here and never by a character position.
fn runs(line: &str) -> Vec<(usize, usize)> {
    let mut out = Vec::new();
    let bytes = line.as_bytes();
    let mut i = 0usize;
    while i < bytes.len() {
        while matches!(bytes.get(i), Some(b' ' | b'\t')) {
            i += 1;
        }
        let start = i;
        let mut end = i;
        while i < bytes.len() {
            match bytes.get(i) {
                Some(b'\t') => break,
                Some(b' ') if bytes.get(i + 1) == Some(&b' ') => break,
                Some(_) => {
                    i += 1;
                    end = i;
                }
                None => break,
            }
        }
        if end > start {
            out.push((start, end));
        }
        if i == start {
            i += 1;
        }
    }
    out
}

/// **What a selection of lines holds** (046/Q).
///
/// The owner, 7 October: «نعتمد فقط على الأسطر — في حال تحديد الكل نحسب كم سطر
/// في النص.» The line is the unit a person works with, so the count of lines
/// is said out loud — and with it the two numbers that decide what an act over
/// them is worth: how many values in there are already protected, and how many
/// are still waiting.
///
/// The core answers it because they are facts about **findings**, and a screen
/// that counted them would be a second source for a number Rust already holds.
pub(crate) fn line_selection(session: SessionId, from: u32, to: u32) -> ApiResult<LineSelection> {
    with_session(session.id, |s| {
        let text = s.original_str();
        let lines = line_ranges(text);
        let (lo, hi) = (from.min(to) as usize, from.max(to) as usize);
        // **Both ends, not only the first.** Checking `lo` alone returned
        // `lines: 1000` for a nine-line document — a number shaped like a fact,
        // which is the one thing this product may never print. Found by this
        // function's own test, on the end nobody thinks about.
        let (Some(first), Some(last)) = (lines.get(lo), lines.get(hi)) else {
            return Err(ApiError::BadSpan {
                reason: "that line is not in this document".to_string(),
            });
        };
        let (start, end) = (first.0, last.1);
        let inside = |a: usize, b: usize| a < end && start < b;
        let protected = s.protections.iter().filter(|p| inside(p.start, p.end)).count() as u32;
        let open = s
            .findings
            .iter()
            .filter(|f| f.state == MarkState::Suggested && inside(f.start, f.end))
            .count() as u32;
        Ok(LineSelection {
            lines: (hi - lo + 1) as u32,
            protected,
            open,
        })
    })
    .ok_or(ApiError::InvalidSession)?
}

/// **The same cell, in every selected line** (046/Q).
///
/// He selects the lines, clicks **one** value, and the cell it stands in is
/// protected in all of them. No inference about what a column means: the
/// column is reached by **example**, and the example is a person's own click.
///
/// Measured in 048: a column rule driven by a header list would have reached
/// eight values in one column of one document and would have missed a table
/// with no header, a header in a language we do not carry, or a header that is
/// not a label. This reaches all of them, because a person pointed.
///
/// The cell is cell **k** of the row, counting runs separated by two or more
/// spaces or a tab — by order, never by character position, which is the one
/// thing 048 proved does not survive the PDF reader on his real documents.
///
/// **Each value becomes its own token.** Never the line as one token: a line
/// swallowed whole would destroy the row and take the amounts with it, which
/// is 046/M's defect arriving by another door.
pub(crate) fn protect_cell_in_lines(
    session: SessionId,
    span: Span,
    from: u32,
    to: u32,
    scope: Scope,
    kind: Kind,
) -> ApiResult<ProtectOutcome> {
    if matches!(scope, Scope::Always | Scope::Profile) {
        require_open_vault()?;
    }
    // Which cell was clicked, and in which line.
    let (which, lo, hi) = with_session(session.id, |s| {
        let text = s.original_str();
        let (start, _end) = text::span_to_bytes(text, span)?;
        let lines = line_ranges(text);
        let (lo, hi) = (from.min(to) as usize, from.max(to) as usize);
        let here = lines
            .iter()
            .position(|(a, b)| start >= *a && start <= *b)
            .ok_or_else(|| ApiError::BadSpan {
                reason: "that selection is not on a line of this document".to_string(),
            })?;
        let Some((line_start, line_end)) = lines.get(here).copied() else {
            return Err(ApiError::BadSpan {
                reason: "that selection is not on a line of this document".to_string(),
            });
        };
        let line = text.get(line_start..line_end).unwrap_or_default();
        let inner = start - line_start;
        // **Refused, never snapped to the nearest cell.** The press was read
        // perfectly; it simply points at the gap between two columns, and
        // choosing one for the person is the inference this whole design
        // exists to avoid. Its own type, so the screen can say *why* rather
        // than «that selection could not be read», which would be false.
        let which = runs(line)
            .iter()
            .position(|(a, b)| inner >= *a && inner < *b)
            .ok_or(ApiError::BetweenColumns)?;
        Ok((which, lo, hi))
    })
    .ok_or(ApiError::InvalidSession)??;

    // The same cell of every line in the range, as spans, before anything is
    // changed: protecting shifts nothing in the original, but reading the
    // document once and acting afterwards is the habit that keeps offsets
    // honest.
    let wanted = with_session(session.id, |s| {
        let text = s.original_str();
        let lines = line_ranges(text);
        let mut out: Vec<Span> = Vec::new();
        for index in lo..=hi {
            let Some((line_start, line_end)) = lines.get(index).copied() else { continue };
            let line = text.get(line_start..line_end).unwrap_or_default();
            let Some((a, b)) = runs(line).get(which).copied() else { continue };
            if let Ok(span) = text::bytes_to_span(text, line_start + a, line_start + b) {
                out.push(span);
            }
        }
        out
    })
    .ok_or(ApiError::InvalidSession)?;

    let mut places = 0u32;
    let mut token = String::new();
    for one in wanted {
        remember_in_vault(session, one, scope, kind)?;
        match protect_inner(session, one, scope, kind, false)? {
            ProtectOutcome::Applied { token: t, .. } => {
                places = places.saturating_add(1);
                if token.is_empty() {
                    token = t;
                }
            }
            // Already protected, or snapped to a whole item: both are honest
            // outcomes for one line and neither stops the rest.
            ProtectOutcome::AlreadyProtected { token: t, .. } if token.is_empty() => {
                token = t;
            }
            _ => {}
        }
    }
    crate::session::bump_truth();
    Ok(ProtectOutcome::Applied { token, places })
}

fn protect_inner(
    session: SessionId,
    span: Span,
    scope: Scope,
    kind: Kind,
    all_matches: bool,
) -> ApiResult<ProtectOutcome> {
    // Before the lock below, not inside it: this takes the core lock itself.
    name_tokens_from_the_vault(session.id);
    with_session(session.id, |s| {
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        let selected = match s.original_str().get(start..end) {
            Some(text) => text.to_string(),
            None => {
                return Err(ApiError::BadSpan {
                    reason: "the selection is not on a character boundary".to_string(),
                })
            }
        };

        // Already protected? Say by whom, and change nothing.
        let touched: Vec<&Protection> = s
            .protections
            .iter()
            .filter(|p| p.start < end && start < p.end)
            .collect();
        if let [only] = touched.as_slice() {
            if only.start == start && only.end == end {
                return Ok(ProtectOutcome::AlreadyProtected {
                    token: only.token.clone(),
                    source: only.source,
                    source_detail: only.source_detail.clone(),
                });
            }
        }
        // The selection cut into protected text, or spanned several: hand back
        // the whole items and do nothing. A half-replacement could leave part of
        // a real name in the payload.
        if !touched.is_empty() {
            let mut spans = Vec::with_capacity(touched.len());
            for p in &touched {
                spans.push(text::bytes_to_span(s.original_str(), p.start, p.end)?);
            }
            return Ok(ProtectOutcome::Snapped { spans });
        }

        // One value, one token: if this text is already known here, reuse it.
        let token = match s.tokens.token_for(&selected) {
            Some(existing) => existing.to_string(),
            None => {
                let minted = s.mint.mint(kind, &selected, &s.tokens);
                s.tokens.insert(
                    minted.clone(),
                    TokenEntry {
                        value: crate::secret::Secret::new(selected.clone()),
                        aliases: Vec::new(),
                        kind,
                        scope,
                        source: Source::Hand,
                        decided: true,
                        source_detail: "selected by you".to_string(),
                    },
                );
                minted
            }
        };

        let act = s.take_act_id();
        let mut places = Vec::new();
        if all_matches {
            places.extend(text::occurrences(s.original_str(), &selected));
        } else {
            places.push((start, end));
        }

        let mut applied = 0u32;
        for (from, to) in places {
            // Never overlap what is already protected.
            if s.protections.iter().any(|p| p.start < to && from < p.end) {
                continue;
            }
            s.protections.push(Protection {
                start: from,
                end: to,
                token: token.clone(),
                act,
                kind,
                scope,
                source: Source::Hand,
                source_detail: "selected by you".to_string(),
                decided: true,
                orphaned: false,
            });
            applied = applied.saturating_add(1);
        }
        s.protections.sort_by_key(|p| p.start);
        if applied == 0 {
            return Err(ApiError::BadSpan {
                reason: "nothing was protected: the selection is already covered".to_string(),
            });
        }
        s.bump();
        Ok(ProtectOutcome::Applied { token, places: applied })
    })
    .ok_or(ApiError::InvalidSession)?
}

/// Turn one range into a protection, for any layer.
///
/// The scanner does not have its own way of hiding something: it comes through
/// here, exactly like a selection made by hand. One path to protection means one
/// place for a bug to live.
#[allow(clippy::too_many_arguments)]
fn protect_range(
    s: &mut Session,
    start: usize,
    end: usize,
    kind: Kind,
    scope: Scope,
    source: Source,
    detail: &str,
    act: u32,
    decided: bool,
) -> Option<String> {
    let value = s.original_str().get(start..end)?.to_string();
    if s.protections.iter().any(|p| p.start < end && start < p.end) {
        return None;
    }
    let token = match s.tokens.token_for(&value) {
        Some(existing) => existing.to_string(),
        None => {
            let minted = s.mint.mint(kind, &value, &s.tokens);
            s.tokens.insert(
                minted.clone(),
                TokenEntry {
                    value: crate::secret::Secret::new(value),
                    aliases: Vec::new(),
                    kind,
                    scope,
                    source,
                    decided,
                    source_detail: detail.to_string(),
                },
            );
            minted
        }
    };
    s.protections.push(Protection {
        start,
        end,
        token: token.clone(),
        act,
        kind,
        scope,
        source,
        source_detail: detail.to_string(),
        decided,
        orphaned: false,
    });
    s.protections.sort_by_key(|p| p.start);
    Some(token)
}

/// Remove one protection, here, by a person's word.
///
/// The one thing that takes a protection back. A rescan does not; forgetting a
/// value does not. Those change what the app *knows*; this changes what is
/// *protected in this document*, and the two are kept apart on purpose.
pub(crate) fn unprotect(session: SessionId, span: Span) -> ApiResult<UndoOutcome> {
    with_session(session.id, |s| {
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        let Some(hit) = s.protections.iter().find(|p| p.start < end && start < p.end).cloned() else {
            return Ok(UndoOutcome::NothingToUndo);
        };
        let before = s.protections.len();
        s.protections.retain(|p| !(p.start == hit.start && p.end == hit.end));
        let places = before.saturating_sub(s.protections.len()) as u32;

        // A token nothing points at any more is not kept: it would sit in the
        // panel standing for nothing.
        if !s.protections.iter().any(|p| p.token == hit.token) {
            s.tokens.remove(&hit.token);
        }
        // And the finding goes with it, so the review list does not keep a row
        // for something that is no longer protected.
        s.findings.retain(|f| !(f.start == hit.start && f.end == hit.end));
        s.bump();
        Ok(UndoOutcome::Undone {
            token: hit.token,
            places,
            created_entity: None,
        })
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn undo_last_protection(session: SessionId) -> ApiResult<UndoOutcome> {
    let outcome = with_session(session.id, |s| {
        let last_act = match s.protections.iter().map(|p| p.act).max() {
            Some(act) => act,
            None => return Ok(UndoOutcome::NothingToUndo),
        };
        let token = s
            .protections
            .iter()
            .find(|p| p.act == last_act)
            .map(|p| p.token.clone())
            .unwrap_or_default();
        let before = s.protections.len();
        s.protections.retain(|p| p.act != last_act);
        let places = before.saturating_sub(s.protections.len()) as u32;

        // If that token is no longer anywhere, it stops being a token of this
        // conversation — the panel must not keep showing it.
        if !s.protections.iter().any(|p| p.token == token) {
            s.tokens.remove(&token);
        }
        s.bump();
        Ok(UndoOutcome::Undone {
            token,
            places,
            // M4: set when the act had also created a vault identity.
            created_entity: None,
        })
    })
    .ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    outcome
}

pub(crate) fn add_alias(session: SessionId, token: String, alias: String) -> ApiResult<u32> {
    with_session(session.id, |s| {
        if !s.tokens.add_alias(&token, alias.clone()) {
            return Err(ApiError::UnknownToken);
        }
        // Teaching a spelling also protects the places where it stands.
        let act = s.take_act_id();
        let (kind, scope, source, detail) = match s.tokens.get(&token) {
            Some(e) => (e.kind, e.scope, e.source, e.source_detail.clone()),
            None => return Err(ApiError::UnknownToken),
        };
        let mut applied = 0u32;
        for (from, to) in text::occurrences(s.original_str(), &alias) {
            if s.protections.iter().any(|p| p.start < to && from < p.end) {
                continue;
            }
            s.protections.push(Protection {
                start: from,
                end: to,
                token: token.clone(),
                act,
                kind,
                scope,
                source,
                source_detail: detail.clone(),
                // Adding a spelling is a person's act, and survives a rescan
                // like every other one.
                decided: true,
                orphaned: false,
            });
            applied = applied.saturating_add(1);
        }
        s.protections.sort_by_key(|p| p.start);
        if applied > 0 {
            s.bump();
        }
        Ok(applied)
    })
    .ok_or(ApiError::InvalidSession)?
}

// ---------------------------------------------------------------- tokens

pub(crate) fn list_tokens(session: SessionId) -> ApiResult<Vec<TokenRow>> {
    with_session(session.id, |s| {
        let in_use = s.tokens_in_use();
        Ok(s.tokens.rows(&in_use))
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn reveal(session: SessionId, token: String) -> ApiResult<RevealedValue> {
    // Read before the session lock is taken. `reveal_ttl_ms` locks the core
    // itself, and the core's mutex is not re-entrant: asking for it from inside
    // a call that already holds it is a deadlock, not an error — the whole
    // program simply stops. Found the moment the settings landed.
    let ttl_ms = reveal_ttl_ms();
    // And the lock count, for the same reason and in the same place: both of
    // these take the core's mutex, which `with_session` is about to hold.
    let locks_at = crate::ops::vault::vault_locks_now();
    with_session(session.id, |s| {
        let Some(entry) = s.tokens.get(&token) else {
            return Err(ApiError::UnknownToken);
        };
        let out = RevealedValue {
            token: token.clone(),
            // Handed over because the user asked to see it, for a moment, locally.
            value: entry.value.expose().to_string(),
            aliases: entry.aliases.iter().map(|a| a.expose().to_string()).collect(),
            ttl_ms,
        };
        // And recorded, instead of handing over a deadline and forgetting.
        // After the token is found, so a press that found nothing shows nothing.
        s.revealed.insert(
            token,
            crate::session::ShownToken {
                until: std::time::Instant::now()
                    + std::time::Duration::from_millis(u64::from(ttl_ms)),
                locks_at,
            },
        );
        Ok(out)
    })
    .ok_or(ApiError::InvalidSession)?
}

/// What is shown in the safe column right now, and for how much longer.
///
/// The value is not in the answer: it was handed over once, when it was
/// revealed. This is the authority on *whether* it may still be on a screen,
/// and a panel asks it about once a second — so it judges and renews nothing.
pub(crate) fn revealed_tokens(session: SessionId) -> ApiResult<Vec<RevealedToken>> {
    // Judged here, before the session lock: a vault whose minutes have run out
    // locks on this line, and the count it moves is the one every record below
    // is measured against.
    let locks = crate::ops::vault::vault_locks_now();
    with_session(session.id, |s| {
        s.revealed
            .retain(|_, shown| shown.locks_at == locks && crate::session::ms_left(shown.until) > 0);
        s.revealed
            .iter()
            .map(|(token, shown)| RevealedToken {
                token: token.clone(),
                remaining_ms: crate::session::ms_left(shown.until),
            })
            .collect()
    })
    .ok_or(ApiError::InvalidSession)
}

/// End every reveal there is: the vault's value, and every token in every
/// session.
///
/// One door, so that the window losing focus, the window being hidden, and a
/// person asking for everything to be covered are three callers of one act and
/// not three acts.
pub(crate) fn hide_all_reveals() -> ApiResult<()> {
    with_core(|core| {
        core.vault.end_reveal();
        core.hide_every_token();
    });
    Ok(())
}

pub(crate) fn hide(session: SessionId, token: String) -> ApiResult<()> {
    // Ends the reveal where it now lives. It still refuses a token that is not
    // real, so the UI can trust its own state.
    with_session(session.id, |s| {
        if s.tokens.contains(&token) {
            s.revealed.remove(&token);
            Ok(())
        } else {
            Err(ApiError::UnknownToken)
        }
    })
    .ok_or(ApiError::InvalidSession)?
}

// ---------------------------------------------------------------- answer

pub(crate) fn ingest_answer(payload: PayloadHandle, raw: String) -> ApiResult<AnswerId> {
    with_payload_record(payload, |_| ())?;
    // Read before the answer is stored, so the answer carries the session it was
    // actually taken in rather than whichever one is open when it is next read.
    let in_session = with_core(|core| {
        core.open_conversation.and_then(|number| {
            core.vault
                .conversations()
                .into_iter()
                .find(|(n, _, _)| *n == number)
                .map(|(n, name, _)| (n, name))
        })
    });
    // **The turn is written here, and written first** — the owner's first
    // finding of 9 October.
    //
    // Here, because here is where every answer arrives: `send` and `ask_model`
    // both end at this function, and so does the app's own paste-back flow for
    // an answer brought in from outside. That is both halves of the owner's
    // division in 062 §F — what happened inside the app, and what was copied
    // out and came back — closed at one place. Putting it in `ask_model`
    // instead would have covered one door of three and left the next one
    // somebody opens uncovered, which is exactly how the send door came to be
    // a third exit nobody had wired.
    //
    // First, because a half-kept conversation is worse than a refused one. If
    // the file cannot be written — the vault locked while the model was
    // thinking is the real case — then nothing has been stored in memory
    // either, and the error is the whole truth rather than an answer the app
    // claims to have kept and has not. The error goes through **unchanged**:
    // `VaultLocked` has to stay `VaultLocked`, because the screen that sees it
    // locks, and a refusal reworded here would take that away.
    if let Some((number, _)) = in_session.clone() {
        let gathered = with_session(payload.session, |s| {
            (
                // The question in the form that left, not as it was typed: the
                // file keeps both halves as they travelled, so nothing on disk
                // resolves to a name except through this session's own store.
                s.question_safe.clone(),
                s.payloads
                    .get(&payload.id)
                    .map(|p| p.allowed_token_ids.clone())
                    .unwrap_or_default(),
            )
        })
        .ok_or(ApiError::InvalidSession)?;
        let (question, allowed) = gathered;
        with_core(|core| {
            crate::ops::conversation::record_in(core, number, question, raw.clone(), allowed)
        })?;
    }
    let out = with_session(payload.session, |s| {
        let id = s.take_answer_id();
        s.answers.insert(
            id,
            AnswerRecord {
                id,
                session: payload.session,
                payload: payload.id,
                raw,
                conversation: in_session,
            },
        );
        // An answer coming in changes nothing about what would go out, so the
        // revision does not move and no handle goes stale.
        Ok(AnswerId { id })
    })
    .ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    out
}

pub(crate) fn restored_view(session: SessionId, answer: AnswerId) -> ApiResult<Vec<Segment>> {
    Ok(restoration(session, answer)?.segments)
}

/// The restored answer **and the names it could not resolve** (046/U).
///
/// One walk over the answer for both, because the count in the sentence and
/// the marks in the text have to be the same fact. `restored_view` is the
/// segments alone, for every screen that was reading them before this.
pub(crate) fn restoration(session: SessionId, answer: AnswerId) -> ApiResult<crate::tokens::Restoration> {
    // **An answer whose session was deleted cannot be restored, and says so by
    // name** — 064 guard 3. The key died with the session, so nothing derives
    // the names in this answer any more: not us, not anybody. That is what
    // makes the owner's deletion warning a fact rather than a caution, and a
    // refusal that named only a number would not be what he called it.
    //
    // Asked of the vault, not of the bench: the bench may still hold a store in
    // memory from before the deletion, and restoring out of that would be the
    // product quietly contradicting the warning it just showed.
    let gone = with_core(|core| {
        let s = core.sessions_get(session.id)?;
        let record = s.answers.get(&answer.id)?;
        let (number, name) = record.conversation.clone()?;
        if core.vault.state() != crate::api::VaultState::Unlocked {
            return None;
        }
        let still_there = core.vault.conversations().iter().any(|(n, _, _)| *n == number);
        if still_there { None } else { Some(name) }
    });
    if let Some(name) = gone {
        return Err(ApiError::PayloadRefused {
            reason: format!(
                "this answer was taken in the session «{name}», which has been deleted. \
                 Its key was destroyed with it, so nothing can be unprotected from it again."
            ),
        });
    }
    with_session(session.id, |s| match s.answers.get(&answer.id) {
        Some(answer) => {
            let payload = s.payloads.get(&answer.payload).ok_or(ApiError::InvalidHandle)?;
            Ok(restore(&answer.raw, &s.tokens, &payload.allowed_token_ids))
        }
        None => Err(ApiError::UnknownToken),
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn ai_view(session: SessionId, answer: AnswerId) -> ApiResult<String> {
    with_session(session.id, |s| match s.answers.get(&answer.id) {
        Some(answer) => Ok(answer.raw.clone()),
        None => Err(ApiError::UnknownToken),
    })
    .ok_or(ApiError::InvalidSession)?
}

// ---------------------------------------------------------------- scan (M3)


/// The pack this device starts a new profile with.
pub(crate) fn default_pack_id() -> String {
    with_core(|core| core.config.get().default_privacy_pack.clone())
}

/// Which rule sets run for this session.
///
/// **The session's language is always active, and the profile's languages are
/// added to it.** Two lines below, `scan` reads the hints and the taught rules
/// of a profile and says in its own comment that a document may be German and
/// English at once — a list that *replaced* the session's language could not
/// say that, and it did not: a client profile is born with one language, so
/// choosing English in the bar ran German rows (046/A). The person's choice in
/// front of the document is the one thing here that is never a guess.
///
/// A firm's languages are still a property of the client they work for. They
/// are a widening, not a swap. The order is the session's language first,
/// because that is the document being read, and duplicates are dropped so that
/// one number is never two marks.
fn active_sets(s: &Session, vault: &crate::vault::VaultStore) -> Vec<String> {
    let mut sets = vec![s.pack_id.clone()];
    let from_profile = s
        .profile_id
        .as_deref()
        .map(|id| vault.languages_of(id))
        .unwrap_or_default();
    for language in from_profile {
        if !sets.contains(&language) {
            sets.push(language);
        }
    }
    sets
}

/// The language a session is reading in — `None` when the handle names no
/// session that is still open.
///
/// Takes the core lock, so it is read **before** any `with_core` closure that
/// needs it, for the reason `create_profile` states in full.
pub(crate) fn session_pack(session: Option<SessionId>) -> Option<String> {
    let session = session?;
    crate::session::with_session(session.id, |s| s.pack_id.clone())
}

/// **Name this session's tokens from the vault's key** — 046/U item 2.
///
/// Idempotent, and it does nothing while the vault is shut. Called wherever a
/// token might be minted, because the two facts it needs — the document's
/// bytes and the vault's key — arrive at different moments: a person may
/// unlock the vault long after opening the file.
///
/// **Tokens already minted keep their names.** That is not tidiness, it is the
/// only honest choice: renaming a token that has already gone to a model would
/// make the answer in that person's hand unrestorable.
///
/// **064 moved where the names come from, and did not repeal that sentence.**
/// The namespace is the open session's key now, not `profile ‖ document-text`,
/// so this asks `naming_of` rather than `naming_for`. The one case where names
/// *do* move is a session's birth, and it moves them for the reason this
/// comment gives rather than against it: at a birth nothing has gone to a model
/// yet, because the birth is the first exit. The promise attaches at the
/// boundary.
///
/// With no session open there is no key, and the tokens keep the random names
/// they have always had — exactly what a shut vault gives, and for the same
/// reason: nothing for a stable name to be stable for.
fn name_tokens_from_the_vault(session: u32) {
    with_core(|core| {
        let Some(number) = core.open_conversation else { return };
        let Some((s, _)) = core.session_and_vault(session) else { return };
        if s.mint.names_from_the_vault() || s.original.is_empty() {
            return;
        }
        if let Some(naming) = core.vault.naming_of(number) {
            if let Some((s, _)) = core.session_and_vault(session) {
                s.mint.name_from(naming);
            }
        }
    });
}

pub(crate) fn scan(session: SessionId) -> ApiResult<ScanReport> {
    // Before the scan, because the scan protects what the vault already knows
    // and those tokens must carry the derived name like every other.
    name_tokens_from_the_vault(session.id);
    let report = with_core(|core| {
        let vault_state = core.vault.state();
        let (s, vault) = core.session_and_vault(session.id).ok_or(ApiError::InvalidSession)?;
        if s.original.is_empty() {
            return Err(ApiError::NothingToSend);
        }
        let sets = active_sets(s, vault);
        // Empty while the vault is locked: the layer is skipped by having nothing
        // to say, not by a flag someone could forget to check.
        let profile = s.profile_id.clone();
        let hints = vault.hints(profile.as_deref());
        let exceptions = vault.exceptions(profile.as_deref());
        let taught = vault.label_rules(profile.as_deref());
        let names = vault.taught_names(profile.as_deref());
        rescan_with(s, &sets, &taught, &hints, &exceptions, &names);
        mark_scanned(s);
        Ok(report_of(s, vault_state))
    })?;
    crate::session::bump_truth();
    Ok(report)
}

/// One rescan, used by the Rescan button and by switching a pack or a profile.
///
/// They were two loops with different rules until task 037, and the difference
/// was the ninth lie: switching a pack **kept** a protection the new pack no
/// longer claimed, while pressing Rescan **dropped** it. So forgetting a value
/// and then rescanning put that value back in the clear — in the Safe column,
/// one press after the user had asked the app to be *more* careful.
///
/// The rule now, and it has no exceptions: **a rescan never takes a protection
/// back.** What a layer no longer claims is marked `orphaned` and kept, and the
/// only thing that removes a protection is a person asking for that.
fn rescan_with(
    s: &mut Session,
    active: &[String],
    taught: &[crate::scanner::rules::LabelRule],
    hints: &[crate::vault::model::VaultHint],
    exceptions: &[crate::vault::model::UserException],
    names: &[(String, bool)],
) -> u32 {
    let candidates = scanner::scan(s.original_str(), active, taught, hints, exceptions, names);

    // Nothing is dropped. What is no longer claimed says so.
    let mut orphaned = 0u32;
    for p in s.protections.iter_mut() {
        let claim = candidates.iter().find(|c| c.start == p.start && c.end == p.end);
        match claim {
            None if !p.orphaned && p.source != Source::Hand => {
                p.orphaned = true;
                orphaned = orphaned.saturating_add(1);
            }
            Some(c) => {
                p.orphaned = false;
                // Who claims it **now**. Forgetting a value from the vault
                // while the pack still recognises the shape leaves the thing
                // protected for a different reason — and «You taught Z Privacy
                // this value» would then be a false answer to «why?».
                if p.source != Source::Hand && (p.source != c.source || p.source_detail != c.source_detail) {
                    p.source = c.source;
                    p.source_detail = c.source_detail.clone();
                }
            }
            None => {}
        }
    }

    // A decided finding keeps its id, its reason and its place.
    s.findings.retain(|f| f.decided);
    let act = s.take_act_id();

    for c in &candidates {
        // «Not sensitive» was an answer, and a rescan is not a new question.
        if s.is_dismissed(c.start, c.end) {
            continue;
        }
        if s.findings.iter().any(|f| f.start < c.end && c.start < f.end) {
            continue;
        }
        let covered = s.protections.iter().any(|p| p.start < c.end && c.start < p.end);
        let state = if covered {
            MarkState::Protected
        } else {
            match c.confidence {
                scanner::Confidence::Auto => {
                    // `Scope::Conversation` means every place in this document,
                    // and that is what it now does when a layer protects as well
                    // as when a person answers. The owner's letter is why: his
                    // own name is written three times and only the signature
                    // carries the proof, so protecting the proven one and
                    // leaving the others was how his name stayed in the clear
                    // after he had answered every question the app asked.
                    let selected = s.original_str().get(c.start..c.end).map(str::to_string);
                    let mut here = None;
                    if let Some(selected) = selected {
                        for (from, to) in text::occurrences(s.original_str(), &selected) {
                            if s.protections.iter().any(|p| p.start < to && from < p.end) {
                                continue;
                            }
                            let got = protect_range(
                                s, from, to, c.kind, Scope::Conversation, c.source, &c.source_detail, act, false,
                            );
                            if from == c.start {
                                here = got;
                            }
                        }
                    }
                    match here {
                        Some(_) => MarkState::Protected,
                        None => continue,
                    }
                }
                scanner::Confidence::Suggest => MarkState::Suggested,
            }
        };
        let id = s.take_finding_id();
        s.findings.push(FindingRecord {
            id,
            start: c.start,
            end: c.end,
            kind: c.kind,
            source: c.source,
            source_detail: c.source_detail.clone(),
            reason: c.reason.clone(),
            state,
            decided: false,
            entities: c.entities.clone(),
            also: c.also.clone(),
        });
    }

    // One more pass, because order decided the state above and order is not a
    // fact about a document.
    //
    // A candidate is Suggested when nothing protects its place **yet**. An
    // Auto candidate further down the page then protects every occurrence of
    // its value — the owner's own letter is why — and a place that was offered
    // a moment ago is now protected, while the finding over it still says it
    // is waiting. Measured on DE-1 the day the name bank grew: «Markus Weber»
    // on line 16 was offered, the signature on line 22 protected both places,
    // and pressing Protect on the offer answered «that place is already
    // covered by another protection». A suggestion that cannot be answered is
    // a review that cannot be finished, and Send stays shut behind it.
    //
    // Nothing here detects anything: it is the state of a finding brought back
    // into line with what the session has actually protected.
    let covered: Vec<(usize, usize)> = s.protections.iter().map(|p| (p.start, p.end)).collect();
    for f in s.findings.iter_mut() {
        if f.state == MarkState::Suggested
            && !f.decided
            && covered.iter().any(|(start, end)| *start < f.end && f.start < *end)
        {
            f.state = MarkState::Protected;
        }
    }

    s.normal_words = scanner::plain_word_count(s.original_str(), &candidates);
    s.bump();
    orphaned
}


/// The counts, as the band under the Original header reports them. Every number
/// here is counted from the state; none of them is written into the code.
fn report_of(s: &Session, vault: crate::api::VaultState) -> ScanReport {
    let auto = s.findings.iter().filter(|f| f.state == MarkState::Protected).count() as u32;
    let suggested = s.findings.iter().filter(|f| f.state == MarkState::Suggested).count() as u32;

    let mut per_layer: BTreeMap<(u8, String), u32> = BTreeMap::new();
    for p in &s.protections {
        let detail = match p.source {
            Source::LanguagePack => s.pack_id.clone(),
            _ => String::new(),
        };
        *per_layer.entry((layer_key(p.source), detail)).or_insert(0) += 1;
    }
    let by_layer = per_layer
        .into_iter()
        .map(|((key, detail), count)| LayerCount {
            source: layer_of(key),
            detail,
            count,
        })
        .collect();

    ScanReport {
        auto,
        suggested,
        normal: s.normal_words,
        by_layer,
        vault,
    }
}

fn layer_key(s: Source) -> u8 {
    match s {
        Source::GeneralRule => 0,
        Source::LanguagePack => 1,
        Source::Vault => 2,
        Source::Hand => 3,
    }
}

/// Where a taught rule applies, in the words a person reads. `None` when the
/// rule is gone — forgotten since the document was scanned, which is allowed
/// and must not be answered with a guess.
fn taught_rule_scopes() -> std::collections::BTreeMap<u32, String> {
    with_core(|core| {
        core.vault
            .with_open(|v| {
                v.label_rules
                    .iter()
                    .map(|r| {
                        // A reach, not a client. The profile's display name
                        // stays on the screens that manage profiles.
                        let scope = match &r.profile_id {
                            Some(_) => "This profile".to_string(),
                            None => "Everywhere".to_string(),
                        };
                        (r.id, scope)
                    })
                    .collect()
            })
            .unwrap_or_default()
    })
}

/// «de:label» → «A German (DE) privacy rule». The set names itself; a screen
/// may not, and neither may this sentence.
fn set_label_of(source_detail: &str) -> String {
    let id = source_detail.split(':').next().unwrap_or_default();
    crate::scanner::sets::all()
        .into_iter()
        .find(|s| s.id == id)
        .map(|s| format!("A {} privacy rule", s.label))
        .unwrap_or_else(|| "A privacy rule".to_string())
}

fn layer_of(key: u8) -> Source {
    match key {
        0 => Source::GeneralRule,
        1 => Source::LanguagePack,
        2 => Source::Vault,
        _ => Source::Hand,
    }
}

pub(crate) fn list_findings(session: SessionId) -> ApiResult<Vec<Finding>> {
    with_session(session.id, |s| {
        let mut out = Vec::with_capacity(s.findings.len());
        // How many places hold the same value in the same state. Counted here,
        // over a list that is already in memory and is per document — a letter
        // has tens of these, not thousands — so the pairwise count is cheaper
        // than the map it would take to avoid it.
        let same_value = |record: &crate::session::FindingRecord| -> u32 {
            let whole = s.original_str();
            let Some(text) = whole.get(record.start..record.end) else { return 1 };
            s.findings
                .iter()
                .filter(|other| {
                    other.kind == record.kind
                        && other.state == record.state
                        && whole.get(other.start..other.end) == Some(text)
                })
                .count()
                .max(1) as u32
        };
        for f in &s.findings {
            out.push(Finding {
                occurrences: same_value(f),
                decided: f.decided,
                id: f.id,
                span: text::bytes_to_span(s.original_str(), f.start, f.end)?,
                kind: f.kind,
                source: f.source,
                reason: f.reason.clone(),
                state: f.state,
                entities: f.entities.clone(),
                // Kept against the original, so it still says «page 17» after
                // everything around it has been replaced.
                place: s.place_of(f.start),
            });
        }
        Ok(out)
    })
    .ok_or(ApiError::InvalidSession)?
}

/// Every suggestion in this document that holds the same value as `record`,
/// youngest first by id, with `record` itself among them.
///
/// Same text **and** same kind: «Müller» the person and «Müller» in a company's
/// name are two different claims about one spelling, and a decision about one
/// of them is not a decision about the other.
///
/// Ids rather than indices, because the caller removes and rewrites rows as it
/// goes and an index taken before that is an index into a list that no longer
/// exists.
fn same_value_suggestions(s: &crate::session::Session, record: &crate::session::FindingRecord) -> Vec<u32> {
    let whole = s.original_str();
    let Some(text) = whole.get(record.start..record.end) else {
        return vec![record.id];
    };
    s.findings
        .iter()
        .filter(|f| {
            f.state == MarkState::Suggested
                && f.kind == record.kind
                && whole.get(f.start..f.end) == Some(text)
        })
        .map(|f| f.id)
        .collect()
}

pub(crate) fn answer_finding(session: SessionId, finding: u32, answer: FindingAnswer) -> ApiResult<ScanReport> {
    let vault_state = vault_state()?;
    // «Always» is a promise about tomorrow, so it is written to the vault — and
    // **before** the session lock is taken, not inside it. Gate G19: the core's
    // mutex is not re-entrant, and a lock taken under a lock does not fail, it
    // stops the program.
    if matches!(answer, FindingAnswer::Always) {
        require_open_vault()?;
        let learn = with_session(session.id, |s| {
            s.findings
                .iter()
                .find(|f| f.id == finding && f.state == MarkState::Suggested)
                .and_then(|f| {
                    s.original_str()
                        .get(f.start..f.end)
                        .map(|t| (t.to_string(), f.kind))
                })
        })
        .ok_or(ApiError::InvalidSession)?;
        if let Some((text, kind)) = learn {
            learn_value(None, kind, text)?;
        }
    }
    let report = with_session(session.id, |s| {
        let Some(index) = s.findings.iter().position(|f| f.id == finding) else {
            return Err(ApiError::UnknownToken);
        };
        let Some(record) = s.findings.get(index).cloned() else {
            return Err(ApiError::UnknownToken);
        };
        if record.state != MarkState::Suggested {
            // Answering something already protected is not an error, and not a
            // change either.
            return Ok(report_of(s, vault_state));
        }
        match answer {
            FindingAnswer::Skip => {
                // Skipping is not deciding: it stays open and stays counted.
                Ok(report_of(s, vault_state))
            }
            FindingAnswer::NotSensitive => {
                // Remember the answer, not only the removal. A rescan would
                // otherwise ask again as if nothing had been said.
                if let Some(text) = s.original_str().get(record.start..record.end) {
                    let value = crate::secret::Secret::new(text.to_string());
                    s.dismissed.push(crate::session::Dismissed { value });
                }
                // Every place that holds the same value, not only the one
                // whose button was pressed: «this is not sensitive» is said
                // about a value, and `dismissed` already works that way — the
                // other places would have come back empty-handed on the next
                // rescan anyway, after asking once more for nothing.
                for id in same_value_suggestions(s, &record) {
                    if let Some(at) = s.findings.iter().position(|f| f.id == id) {
                        s.findings.remove(at);
                    }
                }
                s.bump();
                Ok(report_of(s, vault_state))
            }
            FindingAnswer::Protect | FindingAnswer::Always => {
                // One act for the whole decision, so one step back takes it
                // back whole — the same shape the hand path has had since it
                // learned to say «in 3 places».
                let act = s.take_act_id();
                let detail = record.source_detail.clone();
                let group = same_value_suggestions(s, &record);
                let mut applied = 0u32;
                for id in group {
                    let Some(at) = s.findings.iter().position(|f| f.id == id) else { continue };
                    let Some(place) = s.findings.get(at).cloned() else { continue };
                    let protected = protect_range(
                        s,
                        place.start,
                        place.end,
                        place.kind,
                        Scope::Conversation,
                        place.source,
                        if id == record.id { &detail } else { &place.source_detail },
                        act,
                        // A person answered. This is what keeps it through a rescan.
                        true,
                    );
                    if protected.is_none() {
                        // Already covered by something else. That is not a
                        // failure of the decision, only of this one place.
                        continue;
                    }
                    applied = applied.saturating_add(1);
                    if let Some(f) = s.findings.get_mut(at) {
                        f.state = MarkState::Protected;
                        // A person decided. This is what carries it through a
                        // rescan, and what puts it under «protected by you».
                        f.decided = true;
                        f.reason = match answer {
                            FindingAnswer::Always => format!("{} · confirmed by you, and kept in the vault", f.reason),
                            _ => format!("{} · confirmed by you", f.reason),
                        };
                    }
                }
                if applied == 0 {
                    return Err(ApiError::BadSpan {
                        reason: "that place is already covered by another protection".to_string(),
                    });
                }
                s.bump();
                Ok(report_of(s, vault_state))
            }
        }
    })
    .ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    report
}

/// Teach a durable exception from a suggestion, with an explicit durable scope.
///
/// Plain `NotSensitive` remains a conversation dismissal. This call is the
/// separate «remember this decision» path, so persistent knowledge cannot be
/// created by accident.
pub(crate) fn teach_exception(session: SessionId, finding: u32, scope: Scope) -> ApiResult<ScanReport> {
    let report = with_core(|core| {
        let vault_state = core.vault.state();
        let (text, kind, profile) = {
            let s = core.get(session.id).ok_or(ApiError::InvalidSession)?;
            let record = s
                .findings
                .iter()
                .find(|f| f.id == finding && f.state == MarkState::Suggested)
                .ok_or(ApiError::UnknownToken)?;
            let text = s
                .original_str()
                .get(record.start..record.end)
                .ok_or_else(|| ApiError::BadSpan {
                    reason: "that suggestion is not on a character boundary".to_string(),
                })?
                .to_string();
            (text, record.kind, s.profile_id.clone())
        };
        let target_profile = match scope {
            Scope::Profile => profile.ok_or_else(|| ApiError::InputRefused {
                reason: "this conversation is not in a profile, so there is no profile exception to remember"
                    .to_string(),
            })?,
            Scope::Always => String::new(),
            _ => {
                return Err(ApiError::InputRefused {
                    reason: "a saved exception must be for this profile or everywhere".to_string(),
                })
            }
        };
        let profile_id = match scope {
            Scope::Profile => Some(target_profile),
            Scope::Always => None,
            _ => unreachable!(),
        };
        let trimmed = text.trim().to_string();
        if trimmed.is_empty() {
            return Err(ApiError::BadSpan {
                reason: "an empty value cannot be taught as an exception".to_string(),
            });
        }
        core.vault.with_open_mut(|vault| {
            if !vault
                .exceptions
                .iter()
                .any(|ex| ex.profile_id == profile_id && ex.matches(kind, &trimmed))
            {
                let id = vault.take_exception_id();
                vault.exceptions.push(UserException {
                    id,
                    kind,
                    value: Secret::new(trimmed.clone()),
                    profile_id: profile_id.clone(),
                    learned_at: crate::vault::model::now_seconds(),
                });
            }
            Ok(())
        })?;
        let s = core.get(session.id).ok_or(ApiError::InvalidSession)?;
        if let Some(index) = s.findings.iter().position(|f| f.id == finding) {
            s.findings.remove(index);
        }
        s.dismissed.push(crate::session::Dismissed {
            value: Secret::new(trimmed),
        });
        s.bump();
        Ok(report_of(s, vault_state))
    })?;
    crate::session::bump_truth();
    Ok(report)
}

pub(crate) fn packs() -> ApiResult<Vec<PackRow>> {
    Ok(scanner::packs::installed())
}

// ---------------------------------------------------------------- switching

/// Rescan while keeping every protection that already exists.
///
/// The design board's rule for both switches: **a token once given is never
/// silently taken back.** So nothing is cleared; the layers only add what is not
/// already covered, and a protection whose layer no longer claims it becomes
/// yours (manual) instead of disappearing.
fn rescan_keeping(session: SessionId, _pack: &str) -> ApiResult<(u32, u32)> {
    with_core(|core| {
        let (s, vault) = core.session_and_vault(session.id).ok_or(ApiError::InvalidSession)?;
        let profile = s.profile_id.clone();
        let sets = active_sets(s, vault);
        let hints = vault.hints(profile.as_deref());
        let exceptions = vault.exceptions(profile.as_deref());
        let taught = vault.label_rules(profile.as_deref());
        let kept_tokens = s.tokens_in_use().len() as u32;
        // The same rule as the Rescan button, because they are the same act:
        // look again, and take nothing back.
        let names = vault.taught_names(profile.as_deref());
        let orphaned = rescan_with(s, &sets, &taught, &hints, &exceptions, &names);
        Ok((kept_tokens, orphaned))
    })
}

pub(crate) fn switch_profile(session: SessionId, profile_id: Option<String>) -> ApiResult<SwitchOutcome> {
    let pack = with_session(session.id, |s| {
        s.profile_id = profile_id;
        s.pack_id.clone()
    })
    .ok_or(ApiError::InvalidSession)?;
    let (kept_tokens, _) = rescan_keeping(session, &pack)?;
    let revision = with_session(session.id, |s| s.revision).ok_or(ApiError::InvalidSession)?;
    Ok(SwitchOutcome { kept_tokens, revision })
}

pub(crate) fn switch_pack(session: SessionId, pack_id: String) -> ApiResult<RescanOutcome> {
    // 041-Q: any language in the table, with rules or without. Without, the
    // general rules and the person's own list do the work and no other
    // language's dictionary is left running — see `scanner::languages`.
    if !scanner::languages::known(&pack_id) {
        return Err(ApiError::NotFound {
            reason: format!("«{pack_id}» is not a language this build knows"),
        });
    }
    with_session(session.id, |s| s.pack_id = pack_id.clone()).ok_or(ApiError::InvalidSession)?;
    let (_, changed_to_manual) = rescan_keeping(session, &pack_id)?;
    let revision = with_session(session.id, |s| s.revision).ok_or(ApiError::InvalidSession)?;
    Ok(RescanOutcome {
        changed_to_manual,
        revision,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::{MarkState, Span};
    use crate::session::FindingRecord;

    /// Invariant G12. There are no findings until M3, so this test makes one by
    /// hand: the rule is the point, not where the finding came from.
    #[test]
    fn g12_a_payload_cannot_be_sent_while_a_suggestion_is_open() {
        let doc = "Frau Anna Weber übernimmt.";
        let s = open_session(None, "de".to_string()).expect("open");
        import_text(s, doc.to_string()).expect("import");
        protect(s, Span { start: 5, end: 15 }, Scope::Conversation, Kind::Person).expect("protect");
        let handle = build_payload(s).expect("build");

        // With nothing open, send gets as far as the provider door and stops
        // there because nothing is connected — not because of a suggestion.
        assert!(matches!(
            send(handle, ProviderId { id: "openai".to_string() }),
            Err(ApiError::NetworkRefused {
                reason: crate::api::NetworkRefusal::NotConnected,
                ..
            })
        ));

        // One unanswered suggestion, and the door is shut before that.
        with_session(s.id, |session| {
            session.findings.push(FindingRecord {
                id: 1,
                start: 0,
                end: 4,
                kind: Kind::Person,
                source: Source::LanguagePack,
                source_detail: "de".to_string(),
                reason: "a word after «Frau»".to_string(),
                state: MarkState::Suggested,
                decided: false,
                entities: Vec::new(),
                also: Vec::new(),
            });
        })
        .expect("session");

        match send(handle, ProviderId { id: "openai".to_string() }) {
            Err(ApiError::OpenSuggestions { count }) => assert_eq!(count, 1),
            other => panic!("a send with an open suggestion must be refused, got {other:?}"),
        }

        // Answering it (here: marking it not sensitive) clears the way again, and
        // the refusal goes back to being about the provider, not the review.
        with_session(s.id, |session| {
            session.findings.clear();
        })
        .expect("session");
        assert!(matches!(
            send(handle, ProviderId { id: "openai".to_string() }),
            Err(ApiError::NetworkRefused {
                reason: crate::api::NetworkRefusal::NotConnected,
                ..
            })
        ));
    }

    #[test]
    fn g11_no_view_prints_the_users_words() {
        let doc = "Kunde: Nordstern Consulting GmbH";
        let s = open_session(None, "de".to_string()).expect("open");
        let view = import_text(s, doc.to_string()).expect("import");
        assert!(!format!("{view:?}").contains("Nordstern"), "{view:?}");

        protect(s, Span { start: 7, end: 32 }, Scope::Conversation, Kind::Company).expect("protect");
        let handle = build_payload(s).expect("build");
        let payload = payload_view(handle).expect("view");
        assert!(!format!("{payload:?}").contains("Nordstern"));

        let token = list_tokens(s).expect("tokens").first().expect("one").token.clone();
        let shown = reveal(s, token).expect("reveal");
        assert!(!format!("{shown:?}").contains("Nordstern"), "{shown:?}");

        let answer = ingest_answer(handle, "ok".to_string()).expect("ingest");
        let segments = restored_view(s, answer).expect("restored");
        assert!(!format!("{segments:?}").contains("ok"), "{segments:?}");
    }
}

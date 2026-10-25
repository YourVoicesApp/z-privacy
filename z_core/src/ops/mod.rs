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
    Explanation, FoundPlace, FoundState, Mark, MarkState, PackRow, PayloadHandle, PayloadView, ProtectOutcome, ProviderId,
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
            &crate::documents::Budget::new(text_in.len()),
        )?)
    };
    with_session(session.id, |s| {
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
    })
    .ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    the_scan_that_arrives_with_the_document(session)?;
    // 089 rule 9, after the scan: the marks it just made are decisions too, and
    // a copy saved before them would re-open as a document nobody had looked
    // at. `import_text` leaves the name empty, so this one is a `chatN`.
    with_core(|core| conversation::keep_the_preview(core, session.id))?;
    // Read **after** the scan: a view carries the marks, and a view with none
    // on it was the answer this door used to give about a document it had just
    // read.
    with_session(session.id, view_of).ok_or(ApiError::InvalidSession)?
}

/// **The scan a document arrives with** — the detection round of 14 October,
/// item 3.
///
/// Both import doors installed the text, cleared the findings, wrote
/// `ScanOrigin::NotScanned` and returned. Nothing was wrong with any of that
/// except what it left to whoever called next: `list_findings` came back empty,
/// `workspace_snapshot` carried no mark, and a value the vault already knows —
/// a `Policy::Always` value, put back by the scan as `auto` and never asked
/// about — simply was not there. A person who opens a document and sees nothing
/// happen has met a broken product on their first press.
///
/// Two Dart doors remembered to scan and nothing made them, which is the shape
/// of trap this house has paid for before: one rule written at one door out of
/// several (083a's three exits, 080's two language doors). And a test that
/// imports and then answers findings answers nothing — that is how
/// `the_session_remembers_its_three` claimed «a bench with one protected name»
/// for four guards and had none.
///
/// So the scan is at the door. `scan` stays public, because a rescan is a real
/// act of its own: the Rescan button, a pack changed, a name taught.
///
/// **`NothingToSend` is not a refusal here.** An empty document is nothing to
/// scan rather than something that failed, and the composer imports an empty
/// string when a conversation opens with no text at all.
fn the_scan_that_arrives_with_the_document(session: SessionId) -> ApiResult<()> {
    match scan(session) {
        Ok(_) | Err(ApiError::NothingToSend) => Ok(()),
        Err(other) => Err(other),
    }
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
    with_session(session.id, |s| {
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
    })
    .ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    // The same law at this door as at the other one, and the same line of code
    // asking it: a .docx and a .pdf are read by a different reader and arrive
    // at the same session (item 3).
    the_scan_that_arrives_with_the_document(session)?;
    // 089 rule 9, the same line at this door too — and this one carries the
    // file's name, so it is a `docN`.
    with_core(|core| conversation::keep_the_preview(core, session.id))?;
    with_session(session.id, view_of).ok_or(ApiError::InvalidSession)?
}

/// **Has this document come back, and what of it can we still read?** — 079,
/// the import side.
///
/// The seam is one function in `returning`, and the whole of what crosses it is
/// a text in and a reading out: no token store, no map from a token to a value,
/// no key. See that module for how a token finds its conversation and what the
/// three sources are; `api::returning_document` says what the door promises.
///
/// **A reading.** Nothing is written here — not a turn, not the vault, not a
/// protection — and `bump_truth` is deliberately not called: a question that
/// moved the displayed truth would redraw the screen that asked it.
pub(crate) fn returning_document(session: SessionId) -> ApiResult<crate::api::ReturnedDocument> {
    // Named from the vault first, as every door that reads tokens does: a bench
    // whose mint still carries a random namespace would not be recognised as
    // its own conversation's, and this is the one door where that matters more
    // than anywhere else.
    name_tokens_from_the_vault(session.id);
    with_core(|core| {
        let text = core
            .sessions_get(session.id)
            .ok_or(ApiError::InvalidSession)?
            .original_str()
            .to_string();
        Ok(as_a_reading(crate::returning::returning_document(core, &text)))
    })
}

/// **z-pdf, the door back: a file read into its own names, with no bench** —
/// 079 rule 3, built as 089 rule 5, and the owner's own words of 15 October:
/// «خيار يدعى z-pdf يقوم بعكس العملية، يبحث عن الكود ليحوله إلى اسم».
///
/// **It takes no session, and that is the whole of «never scanned, never
/// protected»** (079 rule 5, *forbidden, absolutely*). A flag on an import
/// door would have made the law something a caller remembers at a door that
/// protects by law — item 3's own shape, read backwards. With no session there
/// is no bench: nothing to install a document on, nothing for a protection to
/// land on, and nothing to scan. G34 reads the signature, not the promise.
///
/// The bytes are read by the same readers every other door uses — a .pdf, a
/// .docx, a text file — and refused by name when they cannot be read honestly,
/// which is why the file's own name is not a parameter: the refusal names the
/// cause, and the screen that holds the file names the file.
///
/// `name_tokens_from_the_vault` is **not** called, and cannot be: it names one
/// bench's mint, and there is no bench here. A bench of the conversation that
/// is still in memory is read through `core.benches()` exactly as the other
/// door reads it, and a bench that never joined a conversation carries a
/// random namespace no token of a z-pdf can match anyway.
pub(crate) fn read_a_document_that_came_back(bytes: Vec<u8>, kind: DocumentKind) -> ApiResult<crate::api::ReturnedDocument> {
    let extracted = crate::documents::extract(&bytes, kind)?;
    // The file's bytes are dropped at the end of this call, and the text with
    // them: nothing is written anywhere (G15), and no session holds either.
    Ok(with_core(|core| {
        as_a_reading(crate::returning::returning_document(core, &extracted.text))
    }))
}

/// One reading, worded once — the two doors that read a returning document
/// hand back the same shape, so they cannot come to differ in what they report
/// about it. The seam itself is `returning::returning_document`; this is only
/// the crate's own answer put into the contract's words.
fn as_a_reading(read: crate::returning::Returned) -> crate::api::ReturnedDocument {
    crate::api::ReturnedDocument {
        restored: read.restored,
        tokens: read.tokens,
        vault: read.vault,
        names: read.names,
        brought_back: read.brought_back,
        unresolved: read.unresolved,
        conversations: read
            .conversations
            .into_iter()
            .map(|c| crate::api::ReturnedFrom {
                number: c.number,
                name: c.name,
                brought_back: c.brought_back,
                unresolved: c.unresolved,
                answer_page: c.answer_page,
            })
            .collect(),
        unknown_namespaces: read.unknown_namespaces,
    }
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

/// **Which of the owner's sessions a payload belongs to** — 064d.
///
/// A fact about the snapshot, so it is taken at the moment of the snapshot and
/// never looked up again later, when the answer could have changed. `None` is a
/// payload built with no session open, which is the state a forgotten question
/// at the exit leaves and the one thing in 064 that used to be invisible.
///
/// One function, because all three builders stamp it and three copies of this
/// lookup would be three answers to «whose payload is this».
fn the_session_this_belongs_to(
    core: &mut crate::session::Core,
) -> Option<crate::api::PayloadSession> {
    let number = core.open_conversation?;
    if core.vault.state() != crate::api::VaultState::Unlocked {
        return None;
    }
    core.vault
        .conversations()
        .into_iter()
        .find(|(n, _, _)| *n == number)
        .map(|(number, name, _)| crate::api::PayloadSession { number, name })
}

/// **What this bench would hand to a door, before any door is chosen** — 091,
/// the owner's rules 72 and 72-أ: the chat box is there from the first moment,
/// with no document in the app at all, and one box means a letter pasted into
/// it leaves by the same road as anything else.
///
/// **One function, because the alternative was measured.** `build_payload`
/// refused an empty *document*, and the three manual doors are its readers —
/// «Copy Protected», «Save as PDF» and the pull all end at
/// `payload_to_take_out`, which asks it — while the model door asks
/// `build_the_question_alone` and therefore worked. So on the one surface the
/// owner now starts from, one door out of four was open, and which one
/// depended on which builder a press happened to use. That is the shape this
/// house has paid for four times: a law written at one door out of several.
///
/// It answers about the **bench**, which is why it is not
/// `payload::WhatThePayloadIs`: that one answers about a payload that exists,
/// and its third case is a chat, which no bench ever is.
enum WhatWouldLeave {
    /// Nothing at all — no document, and no question with a word in it. This
    /// is what `NothingToSend` still means, at every door.
    Nothing,
    /// A document, and whatever question stands beside it: `SafePayload::build`
    /// puts the two together with `--- Request ---` between them.
    TheDocumentAndItsRequest,
    /// No document, and a question in the box.
    TheQuestionAlone,
}

/// The one reading of the bench, asked by every door and by the panel.
///
/// The question is measured **trimmed**: a box holding two spaces and a
/// newline is nothing to send, because the refusal is about what would leave
/// and not about whether a field was ever touched. `build_the_question_alone`
/// has read it that way since rule 67.
fn what_would_leave(s: &Session) -> WhatWouldLeave {
    if !s.original.is_empty() {
        WhatWouldLeave::TheDocumentAndItsRequest
    } else if !s.question_safe.trim().is_empty() {
        WhatWouldLeave::TheQuestionAlone
    } else {
        WhatWouldLeave::Nothing
    }
}

pub(crate) fn build_payload(session: SessionId) -> ApiResult<PayloadHandle> {
    // **Asked first, and outside every borrow.** The question-alone builder
    // takes the core whole, and the core's lock is not re-entrant: asking for
    // it from inside a session borrow is not an error but a stop.
    match with_session(session.id, |s| what_would_leave(s)).ok_or(ApiError::InvalidSession)? {
        WhatWouldLeave::Nothing => return Err(ApiError::NothingToSend),
        // **One builder for one text.** The question alone is built in exactly
        // one place, whichever door asked — the model door has asked that
        // builder since rule 67, and a second one here would be two texts the
        // day either changed.
        // **The instrument, not the door**: this one is asked by the snapshot on
        // every read, so it builds and births nothing. The exits reach the same
        // builder through their own law (`build_the_question_alone`,
        // `payload_to_take_out`).
        WhatWouldLeave::TheQuestionAlone => return with_core(|core| the_question_alone(core, session)),
        WhatWouldLeave::TheDocumentAndItsRequest => {}
    }
    let whose = with_core(the_session_this_belongs_to);
    with_session(session.id, |s| {
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

/// **Nothing leaves while a word waits** — contract C3, invariant G12.
///
/// The owner, 14 Oct 2026: «a paragraph is not left until its words' fate is
/// decided». The review is how that is lived; this function is how it is
/// guaranteed, and it is **one** function because the law used to be written at
/// one exit out of three.
///
/// A send through a key refused (G12). Copy Protected and Save as PDF asked the
/// core nothing at all: they took the Safe column's text and put it on the
/// clipboard or in a file with the waiting word standing in it as the person
/// wrote it. Two green halves, one leaking product — which is why no exit may
/// carry its own copy of this check, in Rust or in Dart.
///
/// There is no «leave anyway». The person answers Protect or Leave it and the
/// count reaches zero; that is the whole reason no such switch exists here.
fn no_word_waits(session: u32) -> ApiResult<()> {
    let open = with_session(session, |s| s.open_suggestions()).ok_or(ApiError::InvalidSession)?;
    if open > 0 {
        return Err(ApiError::OpenSuggestions { count: open });
    }
    Ok(())
}

/// **The text that may leave this machine** — the one door the manual exits ask.
///
/// Copy Protected and Save as PDF end here, so the law above reaches them
/// without either press holding a copy of it. It is deliberately **not**
/// `build_payload`: that one is the instrument the workspace snapshot draws the
/// Safe column with on every read, and a refusal there would blank the column
/// the person reads *while* they answer — 083 rule 4 moves both columns to the
/// waiting word, and 084 washes that word in both of them.
///
/// So `build_payload` goes on telling the truth, including how many words are
/// waiting, and this door decides who may take the text away.
pub(crate) fn payload_to_take_out(session: SessionId) -> ApiResult<PayloadView> {
    no_word_waits(session.id)?;
    // **A session for what is about to leave** — rule 55-و, asked before the
    // mint and before the build: a birth re-derives every token of the bench,
    // so a payload built first would wear pre-birth names while claiming the
    // newborn session (064f).
    a_session_for_what_leaves(session)?;
    // **The answer page's token, minted after the law and never before it** —
    // 079. A refused exit prints no page, so it mints nothing either. Minted
    // here, at the one door both manual exits ask, rather than in the PDF's
    // own press: the word is protected with the session's key, the key is in
    // the core, and the screen is handed the token and never the word.
    //
    // Named from the vault first, as every other mint is, so a bench whose
    // session is open prints that session's name for the word.
    name_tokens_from_the_vault(session.id);
    with_session(session.id, |s| {
        // **Whatever would leave gets its answer page** — and the condition is
        // the same reading of the bench the builder makes, not a second one.
        // It used to ask for a document, so the PDF press on a question-only
        // surface was handed a view with no token and refused in its own words
        // («its answer page had no token»): the door was open and the press
        // still would not write. A refused exit prints no page, so `Nothing`
        // mints nothing (079).
        if !matches!(what_would_leave(s), WhatWouldLeave::Nothing) {
            s.answer_page_token();
        }
    })
    .ok_or(ApiError::InvalidSession)?;
    let out = payload_view(build_payload(session)?);
    // **089 rule 9: it has left.** Copy, pull and the PDF all come through this
    // door, and the copy in the conversation's file goes with the text — after
    // the view is built, because a refusal above takes nothing out and must
    // therefore take nothing away. The blocks stay in the vault.
    if out.is_ok() {
        with_core(|core| conversation::the_preview_has_left(core, session.id));
    }
    out
}

/// **The question alone, for a question that follows another** — rule 67.
///
/// The first question of a chat travels with the document: `build_payload` puts
/// the two together with `--- Request ---` between them, and that is what the
/// model was shown. A second question does not — the owner's rule says the
/// document is not sent again unless the person puts it in again — so what
/// leaves is the question and nothing else, and what has already been said
/// travels beside it as the history (`ask_model`).
///
/// **No text crosses the contract here either.** The screen calls
/// [`set_question`] as it always has, which protects the words with the same
/// packs, the same vault and the same lists the document was read with; this
/// door hands back a handle to what that produced. There is no argument on it
/// through which a raw question could arrive, which is the same promise
/// `build_payload` has made since M2.
///
/// It refuses an empty question with `NothingToSend`, the way `build_payload`
/// refuses an empty document: a follow-up with nothing in it is nothing to
/// send, and the refusal names what is missing rather than sending a label with
/// no sentence under it.
pub(crate) fn build_the_question_alone(session: SessionId) -> ApiResult<PayloadHandle> {
    // **The exit's own law, before the handle exists** — rule 55-و. This is a
    // door text leaves by: the screen builds here and sends in the same act, so
    // the birth belongs in front of the build and nowhere after it.
    a_session_for_what_leaves(session)?;
    with_core(|core| the_question_alone(core, session))
}

/// **The building itself**, with the core in hand and no law of its own.
///
/// Split out for one reason, and it is the distinction this file already draws
/// at `payload_to_take_out`: the workspace snapshot asks `build_payload` on
/// **every read** to draw the Safe column, and a birth there would make a
/// session out of a question nobody has sent — «no empty sessions» is rule 55's
/// own words. So the instrument the screen draws with reaches this function,
/// and the door text leaves by reaches it through the law above. One builder
/// either way: the text that leaves is assembled in exactly one place.
fn the_question_alone(
    core: &mut crate::session::Core,
    session: SessionId,
) -> ApiResult<PayloadHandle> {
    {
        let whose = the_session_this_belongs_to(core);
        // **What this chat has already been allowed to carry** — G9, and the
        // reason a follow-up can be read at all. Taken before the bench is
        // borrowed, because both come out of the one core.
        let chat = crate::ops::conversation::the_chat_so_far(core)?;
        let s = core.get(session.id).ok_or(ApiError::InvalidSession)?;
        if s.question_safe.trim().is_empty() {
            return Err(ApiError::NothingToSend);
        }
        let id = s.take_payload_id();
        let mut allowed = s.question_tokens.clone();
        allowed.extend(chat.allowed);
        let text = s.question_safe.clone();
        let payload = SafePayload::of_the_question_alone(s, id, whose, text, allowed);
        // **Audited like any other payload** — G3. The question was protected
        // against *this* bench a moment ago, so the bound the audit draws from
        // this document's places is the right one to hold it to.
        payload.audit(s)?;
        let handle = payload.handle();
        s.payloads.insert(id, payload);
        s.trim_payloads();
        Ok(handle)
    }
}

/// **A session for what is about to leave** — rule 55-و, the owner's «نعم» of
/// 18 October 2026.
///
/// The second cause of the one birth (`conversation::a_session_is_born`): a
/// question that leaves with no document in the app is a session, because «the
/// chat without a document is a whole session» — its turns stored, the next
/// question carrying the earlier ones, «Copy the chat» working, and the row in
/// the room under its name.
///
/// **One function, asked by every exit**, which is the shape `no_word_waits`
/// has for the same reason: the law used to live in the *screen*, which began
/// a session of its own whenever an exit found none open. That is one law in
/// two languages, and the quieter copy wins the day they disagree.
///
/// **Nothing here births for a document**: that cause fires when the document
/// enters the preview (rule 55c), long before any exit, and asking again at the
/// exit would be a second answer to the same question. A session already open
/// is left exactly as it is — which is also why ending a chat starts the
/// surface from zero *inside* the session it belongs to (rule 71) rather than
/// beginning a second one.
///
/// **A locked vault never refuses the exit.** There is no key to seal a
/// session with, so the text still leaves and nothing is written down — the
/// same answer `keep_the_preview` gives a document that arrives before the
/// vault is open.
fn a_session_for_what_leaves(session: SessionId) -> ApiResult<()> {
    with_core(|core| {
        if crate::ops::conversation::open_in(core).is_some() {
            return Ok(());
        }
        let Some(s) = core.get(session.id) else {
            return Err(ApiError::InvalidSession);
        };
        if !matches!(what_would_leave(s), WhatWouldLeave::TheQuestionAlone) {
            return Ok(());
        }
        match crate::ops::conversation::a_session_is_born(core, session) {
            Ok(_) => Ok(()),
            Err(ApiError::VaultLocked) => Ok(()),
            Err(other) => Err(other),
        }
    })
}

/// **The chat, for the person to take away** — rule 65's copy, the fourth door.
///
/// **The payload itself, which is what an outside model is shown** — the
/// owner's ruling of 24 October 2026: «النسخ فقط ما هو موجود على الشاشة… خارج
/// التطبيق لا يأخذ إلا ما يراه المستخدم على الشاشة؛ داخل التطبيق نرسل فقط
/// السؤال السابق والنقطة الحالية».
///
/// **One payload, two doors, and the law has two sides rather than two texts:**
///
///   * what a person carries to a model of their own is the payload as it
///     stands — the current question, protected, exactly what would leave by
///     the app's own door. That side does not move: what leaves is what the
///     person was shown;
///   * **inside** the app the same payload travels with one **addition**: the
///     exchange before it, put there by the core's one history function
///     (`ops::conversation::the_chat_so_far`, read by `ask_model` alone). The
///     model holds nothing of the chat, so that addition is what makes a
///     follow-up answerable; a person's own chat holds its thread already, so
///     outside the app the addition would be the same words twice.
///
/// Until this round the door handed over the chat's whole transcript, which is
/// what the register records (C-13). **The cost is said rather than hidden:**
/// no door hands a person their whole conversation now, and the whole of it
/// stays readable in the session's own room (rule 69). The owner accepts that
/// for now, and his intent is that the first development round closes it.
///
/// **The door is still the chat's** (rule 65): with no chat in the session
/// there is nothing to take out, and it says so by name rather than handing
/// over the bench. And **the list of tokens this copy may bring home is still
/// the whole chat's**: an answer the person carries back may name a token born
/// in any turn, and it comes home in their own name — the measurement in
/// `an_answer_against_the_chats_own_copy_asks_nothing_new_and_restores_every_name`.
///
/// **It asks the one law** (`no_word_waits`, G28/C3): it is a door text leaves
/// this machine by, and a door that carried its own exception is the shape this
/// house has paid for four times.
///
/// **It does not take the preview's copy out, and that is a reason, not an
/// exception** — 089 rule 9. Every byte here left by one of the other three
/// doors, each of which took the copy with it then. Doing it here would delete
/// the copy of whatever document is on the bench *now*, which may never have
/// left at all — `the_preview_has_left`'s own comment names the measurement.
///
/// **And it is not audited against the bench**, which the other builders are.
/// The audit bounds how often a protected value may stand in **one** document's
/// payload; a chat holds that document as often as it was sent, and holds the
/// model's own words beside it, so the bound says nothing true here and would
/// refuse an honest transcript. What makes this text safe is where it comes
/// from: the session's file, every line of which crossed an audited door on its
/// way out, and nothing is assembled here that was not already in it.
pub(crate) fn chat_to_take_out(session: SessionId) -> ApiResult<crate::api::ChatToTakeOut> {
    no_word_waits(session.id)?;
    let handle = build_the_chat(session)?;
    // **The handle goes with the text, and that is not a convenience.** An
    // answer brought back by hand is restored against the payload it is bound
    // to (G9), so «Add an answer» after «Copy the chat» must bind to *this*
    // copy — whose allowed list covers every token the chat ever carried. Bound
    // to whatever handle was last on the table, a token born in the third
    // question would come home unresolved and the person would read their own
    // token in the answer.
    Ok(crate::api::ChatToTakeOut { what_leaves: payload_view(handle)?, handle })
}

/// The chat as one payload, kept like any other so that what leaves is named by
/// a handle and read through one accessor.
fn build_the_chat(session: SessionId) -> ApiResult<PayloadHandle> {
    // **Is there a chat at all?** This is the chat's own door, and a session
    // nobody has written in is nothing to take out — the law rule 65 gave it,
    // unchanged by the ruling that changed *what* it hands over. `lines` is
    // the one exchange before (110), so it is empty exactly when the open chat
    // holds no turn.
    let chat = with_core(crate::ops::conversation::the_chat_so_far)?;
    if chat.lines.is_empty() {
        return Err(ApiError::NothingToSend);
    }
    // **And what it hands over is the payload** — the one the app's own door
    // would send from here, built by `the_question_alone`. There is always a
    // chat at this door (the line above refuses otherwise), so the document
    // has gone once with the question that carried it and rule 67 does not
    // send it again: what would leave now is the question, protected.
    //
    // **Two readings of «what is on the screen», and this is the one that was
    // chosen.** The Safe column is drawn with `build_payload`, so it shows the
    // protected document **and** the request under it even in a follow-up. The
    // clipboard takes the **payload** — the request alone — which is the
    // reading that matches the ruling's own reason: the person's own chat
    // already holds the document they pasted with the first question, and
    // handing it over again is the waste this round removes.
    //
    // Nothing is assembled here: no history, and no sentence of ours around
    // it. The addition of one earlier exchange belongs to the in-app door.
    let question = with_core(|core| the_question_alone(core, session))?;
    let what_will_leave = payload_view(question)?.text;
    with_core(|core| {
        let whose = the_session_this_belongs_to(core);
        let text = what_will_leave;
        let s = core.get(session.id).ok_or(ApiError::InvalidSession)?;
        let id = s.take_payload_id();
        let payload = SafePayload::of_the_chat(s, id, whose, text, chat.allowed, chat.kept);
        let handle = payload.handle();
        s.payloads.insert(id, payload);
        s.trim_payloads();
        Ok(handle)
    })
}

pub(crate) fn send(handle: PayloadHandle, provider: ProviderId) -> ApiResult<AnswerId> {
    // The freshness check happens before anything else: a stale request must not
    // even reach a provider, let alone be posted.
    let _fresh = with_payload(handle, |p| p.id)?;

    // Invariant G12, and the same law the two manual exits now obey: whatever
    // the payload was built for, it does not go while a word waits.
    no_word_waits(handle.session)?;
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
    let out = ingest_answer(
        handle,
        raw.text,
        // This door does not go through the gateway, so there is nothing to
        // resolve: the login's model is the model that answered.
        crate::api::TurnVia::Through {
            provider: provider.id.clone(),
            model: login.model.clone(),
        },
    );
    // 089 rule 9: the text has left this machine, so the preview's copy goes.
    with_core(|core| conversation::the_preview_has_left(core, handle.session));
    out
}

/// The protected door: a handle, a model, and what the workspace has to say.
///
/// **It no longer takes a history, and that is rule 67** — the owner, 17
/// October, after finding he could not ask a second question about the same
/// letter: «لا أستطيع أن أتابع الشات معه على نفس الموضوع». The screen used to
/// pass one and passed `const []`, every time, for every caller — so every
/// question reached the model alone and whatever came back was an answer to a
/// stranger.
///
/// The parameter is **deleted** rather than filled in by the screen, because
/// the history is the stored turns of this chat and nothing else may be in it.
/// A `Vec<String>` on this signature is a place where somebody could put the
/// restored text of a turn — the person's own names, on their way back out to
/// a model — and no amount of care at the call site is worth a door that
/// cannot be opened by mistake. It is the same reason the question is protected
/// here and not in the screen.
pub(crate) fn ask_model(
    handle: PayloadHandle,
    provider: ProviderId,
    model: Option<String>,
    workspace: Vec<String>,
) -> ApiResult<crate::api::ModelAnswer> {
    // Everything `send` checks, it checks here too, and for the same reasons:
    // a stale payload must not reach a provider, and a word still waiting stops
    // a send with no «anyway» anywhere in the code (G12).
    let _fresh = with_payload(handle, |p| p.id)?;
    no_word_waits(handle.session)?;
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
    // 089 rule 1. A name a person typed into their question took a token and
    // left the machine wearing it, so it is a block like any other — and the
    // answer that comes back carrying that token is read by the blocks after
    // this bench is gone, which is the whole complaint the rule answers.
    with_core(|core| the_decisions_are_written(core, handle.session));
    allow_tokens(handle, &safe.tokens)?;
    let workspace = safe.text;
    // **The one exchange before this one, built by the core** — rule 67 as
    // amended on 24 October 2026 (110): the previous question and its answer,
    // without the document, and nothing older.
    //
    // Read here, one line before the send, so that what travels is what the
    // file holds at the moment of the send and not what it held when a screen
    // last looked. In the protected form they were stored in: the question as
    // it left and the answer as it arrived, never restored — `the_chat_so_far`
    // says the rest.
    let history = with_core(crate::ops::conversation::the_chat_so_far)?.lines;
    let answer = crate::gateway::send(crate::gateway::Request {
        target: crate::gateway::Target {
            provider_id: provider.id.clone(),
            model_id: model,
        },
        task: crate::gateway::Task::Answer,
        context: crate::gateway::Context { workspace, history },
        payload: handle,
    })?;
    // The answer is kept where every answer is kept, so the restored view and
    // the model's own words are both reachable by id.
    let id = ingest_answer(
        handle,
        answer.text.clone(),
        crate::api::TurnVia::Through {
            provider: answer.usage.provider_id.clone(),
            model: answer.usage.model_id.clone(),
        },
    )?;
    // 089 rule 9: the document left through the gateway, so the preview's copy
    // goes with it. The blocks it made stay in the vault.
    with_core(|core| conversation::the_preview_has_left(core, handle.session));
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
    with_core(|core| the_decisions_are_written(core, session.id));
    let tokens = safe.tokens.clone();
    let marks = safe.marks.first().cloned().unwrap_or_default();
    with_session(session.id, |s| {
        s.question = crate::secret::Secret::new(text.clone());
        s.question_tokens = tokens.clone();
        // **The scan's own covers, kept as records** — 096. They used to exist
        // only as a substituted string, and a hand cannot undo a substitution.
        // The records are the fact; `question_safe` is derived from them a line
        // below, by the one function that derives it.
        //
        // The old records go with the old text: a record over words nobody
        // wrote any more would move a token onto a place the person never
        // covered.
        s.question_protections = marks
            .iter()
            .filter_map(|mark| {
                let token = mark.token.clone()?;
                let (start, end) = crate::text::span_to_bytes(&text, mark.span).ok()?;
                Some(crate::session::Protection {
                    start,
                    end,
                    token,
                    act: 0,
                    kind: mark.kind,
                    scope: Scope::Conversation,
                    source: mark.source,
                    source_detail: mark.source_detail.clone(),
                    decided: false,
                    orphaned: false,
                })
            })
            .collect();
        s.question_safe = s.the_request_as_it_leaves();
    })
    .ok_or(ApiError::InvalidSession)?;
    // A new question is a new thing that would leave, so a payload built
    // before it is stale: the Safe column must not show yesterday's request,
    // and a handle from before it must not be sendable. `bump` is the same
    // call every act that changes the document makes.
    with_session(session.id, |s| s.bump()).ok_or(ApiError::InvalidSession)?;
    crate::session::bump_truth();
    // **Read back rather than remembered**: the safe text is derived from the
    // records now, so the one that is handed out is the one the session holds.
    let question_safe =
        with_session(session.id, |s| s.question_safe.clone()).ok_or(ApiError::InvalidSession)?;
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
        // Read before the two borrows below, which take the core whole.
        let open_now = core.open_conversation;
        let (s, vault) = core.session_and_vault(session).ok_or(ApiError::InvalidSession)?;
        let sets = active_sets(s, vault);
        let profile = s.profile_id.clone();
        Ok((
            sets,
            vault.label_rules(profile.as_deref()),
            vault.hints(profile.as_deref(), open_now),
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
///
/// **A key the vault is holding is not a key that was never given** — 18
/// October 2026, the owner, who read «No AI provider is connected. Add an
/// address and a key first.» about a key sealed in his own vault. The cause
/// was true and is above: `login_in_vault` reads through `with_open`, which
/// fails while the vault is shut, and what is left is this run's own logins —
/// so a sealed key is «no credential in this run». The *sentence* was the
/// fault, and a sentence can only be as good as the reason it is given, so
/// the reason is told apart here: with nothing found and a vault that is
/// **shut**, the refusal names the vault. With no vault at all there is
/// nothing to unlock and nothing could have been sealed, so that stays
/// «nothing is connected» — the two states differ in what to do next, which
/// is the whole of what a refusal is for.
pub(crate) fn login_for(id: &str) -> ApiResult<ProviderLogin> {
    let found = login_in_vault(id).or_else(|| with_core(|core| core.session_logins.get(id).cloned()));
    let Some(login) = found else {
        return Err(if with_core(|core| core.vault.state()) == crate::api::VaultState::Locked {
            crate::providers::vault_locked(id)
        } else {
            crate::providers::not_connected(id)
        });
    };
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
/// **The search bar's one reading** — 084. See `api::find_in_document`.
///
/// A place's state is the state of what **covers** it: a protection, a finding
/// nobody has answered, or nothing. Measured before this was written, on a
/// document holding «Anna Lindqvist» protected, «Lindqvist AB» waiting and
/// «Lindqvist» alone three times — `inspect_selection` could not tell the
/// third from the second, because its `snaps_to` is built from protections
/// alone. This is that reading, and the only one the bar has.
pub(crate) fn find_in_document(session: SessionId, word: String) -> ApiResult<Vec<FoundPlace>> {
    with_session(session.id, |s| {
        let wanted = word.trim();
        if wanted.is_empty() {
            return Ok(Vec::new());
        }
        let whole = s.original_str();
        let mut out = Vec::new();
        // The product's own search, in reading order.
        for (start, end) in text::occurrences(whole, wanted) {
            // What covers this place — the protection first, because a place
            // can be inside a finding **and** inside the protection that
            // answered it, and «protected» is the state a person acts on.
            let protection = s.protections.iter().find(|p| p.start <= start && end <= p.end);
            let finding = s
                .findings
                .iter()
                .find(|f| f.state == MarkState::Suggested && f.start <= start && end <= f.end);
            let (state, token, covered, kind) = match (protection, finding) {
                (Some(p), _) => (
                    FoundState::Protected,
                    Some(p.token.clone()),
                    Some((p.start, p.end)),
                    p.kind,
                ),
                (None, Some(f)) => (FoundState::Waiting, None, Some((f.start, f.end)), f.kind),
                (None, None) => (FoundState::Clear, None, None, Kind::Custom),
            };
            out.push(FoundPlace {
                span: text::bytes_to_span(whole, start, end)?,
                state,
                token,
                covered_by: covered
                    .map(|(a, b)| text::bytes_to_span(whole, a, b))
                    .transpose()?,
                kind,
            });
        }
        Ok(out)
    })
    .ok_or(ApiError::InvalidSession)?
}

/// **A span in the one space every span leaving this core is in** — the
/// entered text's own UTF-16 units, counted from its first character.
///
/// `where_it_lands` answers in the **half's** byte offsets, because that is
/// what the half's text and the half's records are indexed by; everything the
/// glass draws is indexed from the start of the entered text. The distance
/// between the two is one number, and the day it is left out the answer is not
/// wrong by a little: it names a different word, in the other half, with no
/// refusal and no sentence. e2 measured exactly that on `e610c63` — a hand
/// drawn over a word in the request was answered with a word out of the
/// document, and the press that followed said «already protected» about it.
///
/// So the shift has a name and is asked for by it. Five places needed it and
/// four of them had written the document's name instead; the fifth, the
/// snapshot's, had the arithmetic right in its own spelling — and one law in
/// two spellings is how the first four came to be wrong.
pub(crate) fn span_in_the_entered(
    entered: &str,
    begins: usize,
    from: usize,
    to: usize,
) -> ApiResult<Span> {
    text::bytes_to_span(entered, begins + from, begins + to)
}

pub(crate) fn inspect_selection(session: SessionId, span: Span) -> ApiResult<SelectionView> {
    with_core(|core| {
        let vault_hints = {
            let profile = core.get(session.id).and_then(|s| s.profile_id.clone());
            let open_now = core.open_conversation;
            core.vault.hints(profile.as_deref(), open_now)
        };
        // The exceptions and the taught names are not read here any more: they
        // were the scanner's, and the scanner is no longer run over a
        // selection. The hints below still are — they answer «which identity
        // claims this value», which is a fact the vault holds and not a guess
        // about what the value is.
        let s = core.get(session.id).ok_or(ApiError::InvalidSession)?;
        // **096: the half, once, at the top.** A selection in the request is
        // answered from the request's own text and its own records — the same
        // questions, asked of the half the hand is in. Everything below reads
        // `half` and `records` rather than the document, so there is one
        // answer and not two implementations of it.
        let lands = where_it_lands(s, span)?;
        let half = match lands {
            WhereItLands::InTheRequest { .. } => s.question.expose().to_string(),
            WhereItLands::InTheDocument { .. } => s.original_str().to_string(),
        };
        let records: Vec<Protection> = match lands {
            WhereItLands::InTheRequest { .. } => s.question_protections.clone(),
            WhereItLands::InTheDocument { .. } => s.protections.clone(),
        };
        let findings: Vec<(usize, usize, Kind)> = match lands {
            // A request has no findings list of its own: what the scan found
            // in it became a record the moment it was set, so the records are
            // the whole answer there.
            WhereItLands::InTheRequest { .. } => Vec::new(),
            WhereItLands::InTheDocument { .. } => {
                s.findings.iter().map(|f| (f.start, f.end, f.kind)).collect()
            }
        };
        let (start, end) = match lands {
            WhereItLands::InTheRequest { start, end } => (start, end),
            WhereItLands::InTheDocument { start, end } => (start, end),
        };
        // **And the distance from the half's offsets to the one the glass
        // draws in**, resolved here beside the half for the same reason the
        // half is resolved here: so that nothing below asks the question twice
        // and nothing below answers it with the document's name.
        //
        // The request's own start, and not `unwrap_or(0)`: a zero would mean
        // «the document» and would be this fault again, in a quieter voice.
        let begins = match lands {
            WhereItLands::InTheRequest { .. } => {
                s.request_begins_at().ok_or_else(|| ApiError::BadSpan {
                    reason: "that selection lands in a request this session does not have"
                        .to_string(),
                })?
            }
            WhereItLands::InTheDocument { .. } => 0,
        };
        let entered = s.entered_text();
        let selected = half
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
                protected_as: Vec::new(),
                protected_by: None,
                protected_detail: String::new(),
                entities: Vec::new(),
                snaps_to: Vec::new(),
                word_span: span,
                also_before: None,
                // Nothing but space: there is no token under it either.
                on_a_token: false,
            });
        }

        // What Protect will really take, and the offer beside it. Worked out
        // here so the bubble can draw the truth before anything is pressed.
        let (word_start, word_end) = text::whole_words(half.as_str(), start, end);
        let (word_start, word_end) = if word_start < word_end {
            (word_start, word_end)
        } else {
            (start, end)
        };
        let word_span = span_in_the_entered(&entered, begins, word_start, word_end)?;
        let also_before = text::capitalised_word_before(half.as_str(), word_start)
            .map(|(b, e)| span_in_the_entered(&entered, begins, b, e))
            .transpose()?;

        // What it touches. **Protections that tile the selection** are «already
        // protected»; anything else that overlaps means Protect would snap.
        //
        // One exactly covering it was the whole of this until 085 ruling 1
        // (15 October). A name the app read for itself is now one token per
        // word, so a hand drawn over «Katrin Sommer» covers two protections
        // and matched neither — and the glass was told «not protected» about a
        // value entirely ours. The lead's ruling of the same day: the view
        // answers at the same finer grain, and it **lists** the tokens rather
        // than growing a sixth state on the button.
        let mut touched: Vec<Protection> = records
            .iter()
            .filter(|p| p.start < end && start < p.end)
            .cloned()
            .collect();
        touched.sort_by_key(|p| p.start);
        let ours = they_tile(
            half.as_str(),
            touched.iter().map(|p| (p.start, p.end)).collect(),
            start,
            end,
        );

        let mut snaps_to = Vec::new();
        if !ours {
            for p in &touched {
                snaps_to.push(span_in_the_entered(&entered, begins, p.start, p.end)?);
            }
        }

        // **The kind of what the scanner found on exactly this stretch, and
        // nothing else** — 083, ruling 1, and the lead's ruling of 14 Oct on
        // the question the paper left open.
        //
        // With the protection dialog deleted there is no one left to ask, so
        // this answer travels inside the token and the model reads it. It comes
        // from the scan of the **whole document**, which is the only reading
        // with the context in it: «Thomas Müller» is a name because «Herr»
        // stood in front of it, and that word is outside the selection.
        //
        // **What was here until today, and why all three are gone:** the
        // scanner run over the selected text alone, then the kind of a mark
        // that merely *overlapped*, then `looks_like_a_person` — a shape test
        // on the words themselves. Each of them is a second classifier, and
        // the lead's words are «never a guess from a second classifier».
        //
        // **What that costs, measured on the five parity fixtures and written
        // where the cost is paid:** a value taken **whole** keeps its kind
        // exactly — 0 of 95 became `Custom` — and a click **inside** a
        // two-word value loses it, all 58 of them, which 076 answers with a
        // second click on the pair. Across every word of all five, the named
        // share falls from 37% to 2%. And the one case that is a real loss:
        // **a name the scanner missed, selected by hand, is now `Custom` and
        // not `Person`** — the very case hand selection exists for. The lead
        // chose it anyway, because in German every noun is capitalised and a
        // heuristic that guesses «person» from a word's shape will mislead the
        // model more often than «we do not know» ever will. An honest unknown
        // over a confident guess, and if the owner overrules it, it comes back
        // as a ruling and not as a heuristic.
        //
        // **And «exactly this stretch» is now one word or several** (085
        // ruling 1, 15 October). Since the scanner gives one finding per word
        // of a name, a selection drawn over «Katrin Sommer» covers two of them
        // and matched none of them exactly — so the kind the pack had found
        // went missing at the very moment a person took the whole value. The
        // answer is read at the finer grain instead of guessed at: the
        // findings that touch the selection must all lie **inside** it, agree
        // on their kind, and leave nothing in it but whitespace uncovered.
        // That is still the scan's own answer and still no second classifier —
        // a click *inside* a word is unchanged, because the finding there
        // reaches past the selection.
        let whole = half.as_str();
        let covering = |items: Vec<(usize, usize, Kind)>| -> Option<Kind> {
            let mut here: Vec<(usize, usize, Kind)> =
                items.into_iter().filter(|(from, to, _)| *from < end && start < *to).collect();
            here.sort_by_key(|(from, _, _)| *from);
            let kind = here.first().map(|(_, _, kind)| *kind)?;
            if here.iter().any(|(_, _, other)| *other != kind) {
                return None;
            }
            they_tile(whole, here.iter().map(|(from, to, _)| (*from, *to)).collect(), start, end)
                .then_some(kind)
        };
        let exact_kind = covering(records.iter().map(|p| (p.start, p.end, p.kind)).collect())
            .or_else(|| covering(findings.clone()));

        let entities: Vec<String> = vault_hints
            .iter()
            .filter(|h| text::nfc(&h.text) == text::nfc(&selected))
            .map(|h| h.entity_handle.clone())
            .collect();

        Ok(SelectionView {
            empty: false,
            kind: exact_kind.unwrap_or(Kind::Custom),
            matches: text::occurrences(half.as_str(), &selected).len() as u32,
            // Every token standing in this selection, in reading order, and
            // empty when the selection is not ours. One token for one word, so
            // a two-word name says both — `acts.dart` prints them as they
            // stand in the text.
            protected_as: if ours { touched.iter().map(|p| p.token.clone()).collect() } else { Vec::new() },
            // Who and why, when they agree. Two words of one name are found by
            // one rule, so this is the ordinary case; two values of different
            // provenance under one drag is not something to answer in one
            // line, and «we do not know» is the honest reading of it.
            protected_by: first_if_all_agree(&touched, ours, |p| p.source),
            protected_detail: first_if_all_agree(&touched, ours, |p| p.source_detail.clone())
                .unwrap_or_default(),
            entities,
            snaps_to,
            word_span,
            also_before,
            // **079 rule 5, as the glass must see it.** Asked over `word_span`
            // and not over the drawn span, because `word_span` is what Protect
            // would really take (041-K) — a drag that stops one character short
            // of a token's closing `__` would otherwise be offered a press that
            // the door then refuses, which is a button that lies.
            on_a_token: the_token_standing_in(half.as_str(), word_start, word_end).is_some(),
        })
    })
}

/// **Do these spans cover this stretch, leaving nothing in it but whitespace?**
///
/// The question `inspect_selection` has to ask twice since 085 ruling 1
/// (15 October) — once of the protections, to say «this is already ours», and
/// once of the findings, to say what kind the scanner called it. A name the app
/// read for itself is one span per word, so «exactly this stretch» is no longer
/// one span and is not a guess either: the spans must all lie **inside** the
/// stretch, and what is left between and around them must be whitespace.
///
/// Both clauses matter. A span reaching outside means the person clicked
/// **inside** a value, which is not that value — the line the lead drew on
/// 14 October and nothing here moves it. A non-space word left over means the
/// selection holds something nobody named: «Katrin Sommer» is two spans and a
/// space, «Katrin Sommer unter» is two spans and a word.
fn they_tile(whole: &str, mut spans: Vec<(usize, usize)>, start: usize, end: usize) -> bool {
    spans.retain(|(from, to)| *from < end && start < *to);
    if spans.is_empty() {
        return false;
    }
    if spans.iter().any(|(from, to)| *from < start || end < *to) {
        return false;
    }
    spans.sort_by_key(|(from, _)| *from);
    let mut at = start;
    for (from, to) in &spans {
        if whole.get(at..*from).is_some_and(|gap| !gap.trim().is_empty()) {
            return false;
        }
        at = (*to).max(at);
    }
    !whole.get(at..end).is_some_and(|tail| !tail.trim().is_empty())
}

/// One answer for several protections, or none when they do not give the same.
fn first_if_all_agree<T: PartialEq>(
    touched: &[Protection],
    ours: bool,
    read: impl Fn(&Protection) -> T,
) -> Option<T> {
    if !ours {
        return None;
    }
    let first = touched.first().map(&read)?;
    touched.iter().all(|p| read(p) == first).then_some(first)
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
    let taught_labels = taught_rule_labels();
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
        // **The rule behind this protection, whether it won the finding or was
        // folded into it** — the ruling of 16 October.
        //
        // A word the person once protected is a block (rule 50), and from then
        // on the block claims it in every reading; the block's hint is `Always`
        // and outranks the taught rule in `scanner::settle`, so the rule the
        // person actually taught became a folded layer. The card is where that
        // is put right: the block repeats a decision, it never makes one, so
        // the decision leads and the block says it was kept.
        //
        // It stays within rule 58's condition: neither sentence says where or
        // when the word was first protected.
        let rule_id = if taught_rule {
            p.source_detail.strip_prefix("you:u").and_then(|n| n.parse::<u32>().ok())
        } else {
            finding
                .as_ref()
                .and_then(|f| f.also.iter().find_map(|d| d.strip_prefix("you:u")))
                .and_then(|n| n.parse::<u32>().ok())
        };
        // The rule's own reach, read from the vault by the id inside the
        // detail («you:u3»), so the card answers about the rule rather than
        // about the protection the rule happened to produce here.
        let taught_scope = rule_id.and_then(|id| taught_scopes.get(&id).cloned());
        // And the set is read from the finding, never assumed. This line said
        // «A German privacy rule» whatever fired, which was true only while
        // German was the only set there was — the «0 tries left» shape exactly.
        let set_label = set_label_of(&p.source_detail);
        // **A block is not a taught value, and the card may not say it is** —
        // 089 rule 1. A block is a word the person protected somewhere once;
        // nobody taught it, there is no identity behind it, and «You taught Z
        // Privacy this value» over it would be the card calling itself a
        // liar the way 046's «CLIENT #01» line did. The detail carries the
        // claimant the vault layer wrote, so the card reads the fact instead
        // of guessing from the source.
        let from_a_block = p.source == Source::Vault
            && p.source_detail == format!("vault:{}", crate::vault::model::BLOCK_HANDLE);
        // A block that repeats a rule of the person's own reads as the rule:
        // see `rule_id` above. A block that repeats nothing reads as itself.
        let the_rule_leads = taught_rule || (from_a_block && rule_id.is_some());
        let headline = match (p.source, p.decided) {
            _ if the_rule_leads => "You taught Z Privacy this rule".to_string(),
            (Source::Hand, _) => "You protected this by hand".to_string(),
            _ if from_a_block => "You protected this word before, and Z Privacy kept it".to_string(),
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
            // **Each clause once, and each one a sentence** — the measured
            // defect of 16 October was «2 rules agree · your vault knows this
            // value · you:u1 agreed as well · you:u1 agreed as well»: the
            // winner's reason already carries the folded clauses that
            // `scanner::settle` wrote into it, and the loop below added them a
            // second time, as ids. So the folded clauses are taken out of the
            // reason and said once, by `layer_sentence`.
            let written: Vec<String> = f.also.iter().map(|d| format!("{d} agreed as well")).collect();
            let mine: Vec<String> = f
                .reason
                .split(" · ")
                .filter(|clause| !written.iter().any(|already| already == clause))
                .map(str::to_string)
                .collect();
            let folded: Vec<String> = f.also.iter().map(|d| layer_sentence(d, &taught_labels)).collect();
            // The person's own decision first, then what the app can say for
            // itself. Same order as the headline, so the card reads as one
            // voice rather than two.
            let (decisions, others): (Vec<String>, Vec<String>) =
                folded.into_iter().partition(|line| line.starts_with("You taught"));
            if !f.also.is_empty() {
                because.push(format!("{} rules agree", f.also.len() + 1));
            }
            because.extend(decisions);
            because.extend(mine);
            because.extend(others);
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
        let applies = if the_rule_leads {
            // A taught rule's reach is the rule's own scope, not the scope of
            // the protection it produced in this document.
            taught_scope.clone().unwrap_or_else(|| "Everywhere".to_string())
        } else {
            match p.scope {
                Scope::Once => "This one place".to_string(),
                Scope::Conversation => "This session".to_string(),
                Scope::Profile => match &s.profile_id {
                    Some(_) => "This profile".to_string(),
                    None => "This session".to_string(),
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
            //
            // **And a block is the same argument** (089 rule 1): the person
            // protected that word once, in some conversation, and this
            // document is where the decision arrived. The protection itself
            // stays `decided: false`, because that flag is what a **rescan**
            // reads and a rescan's rules are not changed by this round; what
            // changes is the one place a person is told whose decision it was.
            decided: p.decided || the_rule_leads || from_a_block,
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
            // What «in this conversation» would uncover, counted where the
            // places are.
            places: s.protections.iter().filter(|q| q.token == p.token).count() as u32,
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
/// **Which half of the entered text a span lands in** — 096, rule 72-ب.
///
/// One text, one offset space: the document, the `--- Request ---` line, then
/// the request. The document comes first, so a document span's offsets are
/// exactly what they always were, and **where a span lands is arithmetic**
/// rather than a field a caller could fill in wrongly.
///
/// The offsets that come back are local to the half they are in — bytes into
/// `original` for the document, bytes into `question` for the request — so
/// every act below works on one string and never on a join.
pub(crate) enum WhereItLands {
    InTheDocument { start: usize, end: usize },
    InTheRequest { start: usize, end: usize },
}

/// **Judge the half on the span the person drew, then snap to whole words
/// inside that half** — and in that order, which is a measurement and not a
/// preference.
///
/// Pinned: a selection drawn across the `--- Request ---` line was snapped
/// first, and snapping moved its start forward past the line — so the span
/// that had to be refused for crossing arrived inside the request and
/// protected two words there. A refusal about what somebody drew may not be
/// decided on a span nobody drew.
fn the_hand_lands(
    session: SessionId,
    span: Span,
) -> ApiResult<(Option<(usize, usize)>, Span)> {
    with_session(session.id, |s| {
        let lands = where_it_lands(s, span)?;
        let entered = s.entered_text();
        let (from, to) = text::span_to_bytes(&entered, span)?;
        let begins = s.request_begins_at().unwrap_or(0);
        let (lo, hi, local) = match lands {
            WhereItLands::InTheRequest { .. } => {
                let raw = s.question.expose();
                let (x, y) = text::whole_words(raw, from - begins, to.saturating_sub(begins));
                if x >= y {
                    (from, to, Some((from - begins, to.saturating_sub(begins))))
                } else {
                    (begins + x, begins + y, Some((x, y)))
                }
            }
            WhereItLands::InTheDocument { .. } => {
                let document = s.original_str();
                let (x, y) = text::whole_words(document, from, to);
                if x >= y {
                    (from, to, None)
                } else {
                    (x, y, None)
                }
            }
        };
        Ok((local, text::bytes_to_span(&entered, lo, hi)?))
    })
    .ok_or(ApiError::InvalidSession)?
}

/// The request's own offsets, or `None` when the span is the document's — the
/// one question every routed door asks, so that none of them repeats the
/// arithmetic.
fn lands_in_the_request(session: SessionId, span: Span) -> ApiResult<Option<(usize, usize)>> {
    with_session(session.id, |s| match where_it_lands(s, span)? {
        WhereItLands::InTheRequest { start, end } => Ok(Some((start, end))),
        WhereItLands::InTheDocument { .. } => Ok(None),
    })
    .ok_or(ApiError::InvalidSession)?
}

/// A selection may not cross the line between them, which is not a new law:
/// «protection may not change how a document reads» already forbids a
/// selection that crosses a line break, and this is a line.
fn where_it_lands(s: &Session, span: Span) -> ApiResult<WhereItLands> {
    let entered = s.entered_text();
    let (start, end) = text::span_to_bytes(&entered, span)?;
    let Some(begins) = s.request_begins_at() else {
        return Ok(WhereItLands::InTheDocument { start, end });
    };
    let document_ends = s.original_str().len();
    if start >= begins {
        return Ok(WhereItLands::InTheRequest {
            start: start - begins,
            end: end.saturating_sub(begins),
        });
    }
    if end > document_ends {
        return Err(ApiError::BadSpan {
            reason: "a selection may not cross the «--- Request ---» line: the document and \
                     the request are one text and two things, and a token over the line would \
                     change how both of them read"
                .to_string(),
        });
    }
    Ok(WhereItLands::InTheDocument { start, end })
}

pub(crate) fn as_whole_words(session: SessionId, span: Span) -> ApiResult<Span> {
    with_session(session.id, |s| {
        // **The entered text, not the document** — a selection in the request
        // snaps to its words as a selection in the document does.
        let entered = s.entered_text();
        let text = entered.as_str();
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

/// **A token is not a value, and a hand may not protect one** — 079 rule 5.
///
/// The scanner's half of this law is one line in `scanner::scan`: a candidate
/// standing on a token is dropped after every layer and before they settle. A
/// hand is the other half, and it was still open the day that line landed —
/// pinned red, deliberately, because refusing it needed a word on the glass and
/// the word belonged to this round.
///
/// What it was: a selection drawn over `__Z_7f3a_PHONE_2b55__` came back
/// `Applied`. A second token was minted **over** the first, the first vanished
/// from the text, and what left the machine no longer carried the identifier
/// the other conversation can resolve — so its answer restored to a token
/// instead of to a value, silently, which is the shape of lie 046/U exists to
/// end.
///
/// **One function, asked by each of the three doors a hand can protect
/// through**, and asked *before* `remember_in_vault`: `Scope::Always` writes
/// the value into the vault before anything is protected, so a law placed any
/// later would have taught the vault a token of ours. Enumerated by class, the
/// way 083a's three exits were — `protect`, `protect_all_matches`,
/// `protect_cell_in_lines` — and G32 reads each door's own body for the call,
/// and reads that it comes before `remember_in_vault` in it.
///
/// Returns the token standing there, which is a name and never a value.
fn a_token_already_stands_there(session: SessionId, span: Span) -> ApiResult<Option<String>> {
    with_session(session.id, |s| {
        // The entered text: a token the person pasted into the request is as
        // much a token of ours as one in a document that came back (079 rule 5).
        let entered = s.entered_text();
        let (start, end) = text::span_to_bytes(&entered, span)?;
        Ok(the_token_standing_in(&entered, start, end))
    })
    .ok_or(ApiError::InvalidSession)?
}

/// The overlap itself, over bytes — **the one place in this file that asks
/// where the tokens stand.**
///
/// Two callers, and they are two different questions about one fact: the door
/// above refuses an act, and `inspect_selection` stops the act being offered.
/// Asking `tokens::token_spans` twice here would be the same shape as the
/// scanner asking it per layer — one law, read in one place, so the two answers
/// cannot drift. It takes the text rather than a session because the selection
/// already holds the core's lock, which is not reentrant.
fn the_token_standing_in(text: &str, start: usize, end: usize) -> Option<String> {
    crate::tokens::token_spans(text)
        .into_iter()
        .find(|(from, to)| start < *to && *from < end)
        .and_then(|(from, to)| text.get(from..to).map(str::to_string))
}

pub(crate) fn protect(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    // **096: the hand reaches the request through this very door.** The half
    // is judged on the span the person drew and the words are snapped inside
    // that half; the request's path is below and the document's is the rest of
    // this function, unchanged.
    let (in_the_request, span) = the_hand_lands(session, span)?;
    if let Some((start, end)) = in_the_request {
        return protect_in_the_request(session, start, end, scope, kind);
    }
    // 079 rule 5, before the vault is taught anything.
    if let Some(token) = a_token_already_stands_there(session, span)? {
        return Ok(ProtectOutcome::StandsOnAToken { token });
    }
    // The scope decides the breadth. Until task 034 it was only a label — the
    // breadth came from which function was called — so «this conversation»
    // could protect one place and «always» could reach nothing at all.
    if matches!(scope, Scope::Always | Scope::Profile) {
        require_open_vault()?;
    }
    remember_in_vault(session, span, scope, kind)?;
    let every_place = !matches!(scope, Scope::Once);
    let outcome = protect_inner(session, span, scope, kind, every_place)?;
    // 089 rule 1, before the displayed truth moves: the count on the vault
    // screen is one of the facts that just changed.
    with_core(|core| the_decisions_are_written(core, session.id));
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
            reason: "this session is not in a profile, so there is no profile to remember \
                     it for — choose «always», or open a profile first"
                .to_string(),
        });
    }
    let wanted = if profile_only { profile } else { None };
    crate::ops::learn_value(wanted, kind, text)
}

pub(crate) fn protect_all_matches(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    let span = as_whole_words(session, span)?;
    // The same law at this door, and the same line asking it (079 rule 5).
    if let Some(token) = a_token_already_stands_there(session, span)? {
        return Ok(ProtectOutcome::StandsOnAToken { token });
    }
    if matches!(scope, Scope::Always | Scope::Profile) {
        require_open_vault()?;
    }
    remember_in_vault(session, span, scope, kind)?;
    let outcome = protect_inner(session, span, scope, kind, true)?;
    with_core(|core| the_decisions_are_written(core, session.id));
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
    // **A request has no columns** — 096, and «one answer may not answer
    // another kind's question»: doing the document's thing to a span in the
    // request would protect a cell of a table nobody wrote.
    if lands_in_the_request(session, span)?.is_some() {
        return Err(ApiError::BadSpan {
            reason: "a column act asks about a table, and the request is not one: \
                     the selection lands in the request"
                .to_string(),
        });
    }
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
    let mut on_a_token = 0u32;
    let mut token = String::new();
    for one in wanted {
        // 079 rule 5, **per cell and not per act**: one cell of a column that
        // holds a token stops that cell, exactly as a cell that is already
        // protected does — «both are honest outcomes for one line and neither
        // stops the rest». A column of nothing but tokens is the act that has
        // done nothing, and it says so below rather than claiming 0 places.
        if let Some(standing) = a_token_already_stands_there(session, one)? {
            on_a_token = on_a_token.saturating_add(1);
            if token.is_empty() {
                token = standing;
            }
            continue;
        }
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
            // **And this arm cannot swallow 079's outcome**, which is the one
            // thing a reader should check here: `protect_inner` never returns
            // `StandsOnAToken` — the law is asked above, per cell, before this
            // call — so the token case is counted in `on_a_token` and answered
            // after the loop. An explicit arm here would be unreachable code
            // claiming to handle something, which is its own lie.
            _ => {}
        }
    }
    with_core(|core| the_decisions_are_written(core, session.id));
    crate::session::bump_truth();
    // **Nothing was protected and a token is why**, which is a different thing
    // from «every cell was already protected» and gets the sentence that says
    // so. The outcome is matched exhaustively by both presses that can reach
    // here, which is the reason it is an outcome and not an error.
    if places == 0 && on_a_token > 0 {
        return Ok(ProtectOutcome::StandsOnAToken { token });
    }
    Ok(ProtectOutcome::Applied { token, places })
}

/// **A hand protection inside the request** — 096, rule 72-ب.
///
/// The same door, the same store and the same mint as the document's path, so
/// **the same word takes the same token on both sides of the line** (rule 49:
/// one value, one token, because it is one block in one vault). What differs
/// is only where the record is written and that the safe request is derived
/// again afterwards.
fn protect_in_the_request(
    session: SessionId,
    start: usize,
    end: usize,
    scope: Scope,
    kind: Kind,
) -> ApiResult<ProtectOutcome> {
    // Before the session lock, as the document's path does it: this takes the
    // core lock itself.
    name_tokens_from_the_vault(session.id);
    let outcome = with_session(session.id, |s| {
        let raw = s.question.expose().to_string();
        let Some(selected) = raw.get(start..end).map(str::to_string) else {
            return Err(ApiError::BadSpan {
                reason: "the selection is not on a character boundary".to_string(),
            });
        };
        if selected.trim().is_empty() {
            return Err(ApiError::BadSpan {
                reason: "nothing but space was selected".to_string(),
            });
        }
        // Already covered? Say by whom and change nothing — the document's own
        // answer to the same question.
        if let Some(already) = s
            .question_protections
            .iter()
            .find(|p| p.start < end && start < p.end)
        {
            if already.start == start && already.end == end {
                return Ok(ProtectOutcome::AlreadyProtected {
                    token: already.token.clone(),
                    source: already.source,
                    source_detail: already.source_detail.clone(),
                });
            }
            // The selection cut into a cover or spanned several: hand the whole
            // items back and do nothing, as the document's path does.
            let mut spans = Vec::new();
            let begins = s.request_begins_at().unwrap_or(0);
            let entered = s.entered_text();
            for p in s.question_protections.iter().filter(|p| p.start < end && start < p.end) {
                spans.push(text::bytes_to_span(&entered, begins + p.start, begins + p.end)?);
            }
            return Ok(ProtectOutcome::Snapped { spans });
        }
        // One value, one token — the store is the session's, so a name the
        // document already covers keeps its token here.
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
        // **Every place of it in the request** unless the person asked for this
        // one only — the same ladder `Scope` means on the document's side.
        let places: Vec<(usize, usize)> = if matches!(scope, Scope::Once) {
            vec![(start, end)]
        } else {
            text::occurrences(&raw, &selected)
        };
        let mut applied = 0u32;
        for (from, to) in places {
            if s.question_protections.iter().any(|p| p.start < to && from < p.end) {
                continue;
            }
            s.question_protections.push(Protection {
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
        s.question_protections.sort_by_key(|p| p.start);
        if applied == 0 {
            return Err(ApiError::BadSpan {
                reason: "nothing was protected: the selection is already covered".to_string(),
            });
        }
        // The safe request is a view of the records, so it is derived again
        // rather than patched — one fact, one source.
        s.question_safe = s.the_request_as_it_leaves();
        if !s.question_tokens.contains(&token) {
            s.question_tokens.push(token.clone());
        }
        // A new thing would leave, so a payload built before it is stale —
        // exactly as a new question makes one stale.
        s.bump();
        Ok(ProtectOutcome::Applied { token, places: applied })
    })
    .ok_or(ApiError::InvalidSession)??;
    with_core(|core| the_decisions_are_written(core, session.id));
    crate::session::bump_truth();
    Ok(outcome)
}

/// **Taking a cover back inside the request** — 096, the undo half.
fn unprotect_in_the_request(
    session: SessionId,
    start: usize,
    end: usize,
) -> ApiResult<UndoOutcome> {
    let outcome = with_session(session.id, |s| {
        let touched: Vec<(usize, usize, String)> = s
            .question_protections
            .iter()
            .filter(|p| p.start < end && start < p.end)
            .map(|p| (p.start, p.end, p.token.clone()))
            .collect();
        if touched.is_empty() {
            return UndoOutcome::NothingToUndo;
        }
        let mut tokens: Vec<String> = Vec::new();
        for (_, _, token) in &touched {
            if !tokens.iter().any(|t| t == token) {
                tokens.push(token.clone());
            }
        }
        s.question_protections
            .retain(|p| !touched.iter().any(|(a, b, _)| p.start == *a && p.end == *b));
        s.question_safe = s.the_request_as_it_leaves();
        s.bump();
        // **No entity is created or destroyed by an undo in the request**: the
        // block stays in the vault (089, protection is permanent), and what
        // this takes back is the cover on these places.
        UndoOutcome::Undone { tokens, places: touched.len() as u32, created_entity: None }
    })
    .ok_or(ApiError::InvalidSession)?;
    with_core(|core| the_decisions_are_written(core, session.id));
    crate::session::bump_truth();
    Ok(outcome)
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

/// **Here** — the protection off every place this selection covers, and
/// nothing else.
///
/// The one thing that takes a protection back. A rescan does not; forgetting a
/// value does not. Those change what the app *knows*; this changes what is
/// *protected in this document*, and the two are kept apart on purpose.
///
/// **Every item the selection spans, not the first one it touches** — the
/// lead's ruling of 15 October, closing a seam between 085 and 089. Since 085
/// ruling 1 «Stefan Keller» is two protections, one per word, and this door
/// took the first and left the second: a press that did half of what it said.
/// A selection is the person's will (085), and `inspect_selection` already
/// tells the glass that the selection spans two protected items — so the act
/// follows the selection. One mark is one item, so a click is unchanged.
pub(crate) fn unprotect(session: SessionId, span: Span) -> ApiResult<UndoOutcome> {
    // 096: the same door reaches the request.
    if let Some((start, end)) = lands_in_the_request(session, span)? {
        return unprotect_in_the_request(session, start, end);
    }
    let outcome = with_session(session.id, |s| {
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        let touched: Vec<(usize, usize, String)> = s
            .protections
            .iter()
            .filter(|p| p.start < end && start < p.end)
            .map(|p| (p.start, p.end, p.token.clone()))
            .collect();
        if touched.is_empty() {
            return Ok(UndoOutcome::NothingToUndo);
        }
        let covers = |a: usize, b: usize| touched.iter().any(|(x, y, _)| a == *x && b == *y);
        let before = s.protections.len();
        s.protections.retain(|p| !covers(p.start, p.end));
        let places = before.saturating_sub(s.protections.len()) as u32;

        // **Named, and all of them** — the outcome carries every token this act
        // uncovered rather than the first, which is the shape
        // `a_loop_that_reports_its_last_answer` is named for: one sentence
        // about two acts, true of one of them.
        let mut tokens: Vec<String> = Vec::new();
        for (_, _, token) in &touched {
            if !tokens.iter().any(|t| t == token) {
                tokens.push(token.clone());
            }
        }
        // A token nothing points at any more is not kept: it would sit in the
        // panel standing for nothing.
        for token in &tokens {
            if !s.protections.iter().any(|p| &p.token == token) {
                s.tokens.remove(token);
            }
        }
        // And the findings go with them, so the review list does not keep a row
        // for something that is no longer protected.
        s.findings.retain(|f| !covers(f.start, f.end));
        s.bump();
        Ok(UndoOutcome::Undone {
            tokens,
            places,
            created_entity: None,
        })
    })
    .ok_or(ApiError::InvalidSession)?;
    // **089 rule 9, and rule 6's other half**: «Here» uncovers one place, and
    // it is remembered with the saved document. The blocks do not move — a
    // block is never deleted — and the copy in the preview now has one fewer
    // mark, which is what the person did.
    with_core(|core| the_decisions_are_written(core, session.id));
    outcome
}

/// **Every place that carries these tokens, in this conversation** — 083,
/// ruling 3. See `api::unprotect_every_place` for why the token and not the
/// text is the unit.
///
/// **Every token the selection spans**, by the same ruling of 15 October that
/// `unprotect` above carries: one press over «Stefan Keller» reaches both of
/// the blocks that two words made, exempts both, and deletes neither.
///
/// **And the block is exempted here, not deleted** — 089 rules 2 and 6. «In
/// this conversation» is one of the two un-protect options the owner kept, and
/// what it writes down is an exemption on the word's block: the block stands,
/// the word still comes back through the door, and it simply stops being found
/// in this one conversation. A word with no block — every document protected
/// before 15 October 2026 — has nothing to exempt and that is not an error.
pub(crate) fn unprotect_every_place(session: SessionId, span: Span) -> ApiResult<UndoOutcome> {
    // **096: «every place» now has two halves.** A span in the request takes
    // its own covers back; a span in the document takes the document's, and
    // the request's records carrying the same token go with them — or the
    // person would see a word uncovered in one half and covered in the other,
    // which is the shape 049 forbids.
    if let Some((start, end)) = lands_in_the_request(session, span)? {
        return unprotect_in_the_request(session, start, end);
    }
    // The word is read before the protection is taken off, because afterwards
    // nothing on the bench says which word it was. Read under the session lock
    // and the vault written after it: the core's mutex is not re-entrant.
    let words = with_session(session.id, |s| {
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        let mut out: Vec<String> = Vec::new();
        for p in s.protections.iter().filter(|p| p.start < end && start < p.end) {
            if let Some(word) = s.original_str().get(p.start..p.end) {
                if !out.iter().any(|w| w == word) {
                    out.push(word.to_string());
                }
            }
        }
        Ok(out)
    })
    .ok_or(ApiError::InvalidSession)??;
    let outcome = with_session(session.id, |s| {
        let (start, end) = text::span_to_bytes(s.original_str(), span)?;
        let mut tokens: Vec<String> = Vec::new();
        for p in s.protections.iter().filter(|p| p.start < end && start < p.end) {
            if !tokens.iter().any(|t| t == &p.token) {
                tokens.push(p.token.clone());
            }
        }
        if tokens.is_empty() {
            return Ok(UndoOutcome::NothingToUndo);
        }
        // The ranges first, because the findings are matched by range and the
        // protections are about to be gone.
        let ranges: Vec<(usize, usize)> = s
            .protections
            .iter()
            .filter(|p| tokens.iter().any(|t| t == &p.token))
            .map(|p| (p.start, p.end))
            .collect();
        let before = s.protections.len();
        s.protections.retain(|p| !tokens.iter().any(|t| t == &p.token));
        let places = before.saturating_sub(s.protections.len()) as u32;

        // Nothing points at those tokens any more, by construction — so they
        // stop being tokens of this conversation, exactly as the one-place act
        // does when it takes the last one.
        for token in &tokens {
            s.tokens.remove(token);
        }
        // And the findings go with them: a review row for something that is no
        // longer protected is a row about nothing.
        s.findings.retain(|f| !ranges.iter().any(|(a, b)| f.start == *a && f.end == *b));
        s.bump();
        Ok(UndoOutcome::Undone {
            tokens,
            places,
            created_entity: None,
        })
    })
    .ok_or(ApiError::InvalidSession)?;
    // Only for a press that actually took a protection off: an exemption
    // written for a press that undid nothing would silence a word in a
    // conversation on the strength of a miss. **Every word the press reached**,
    // for the same reason the act reaches every one of them.
    if matches!(outcome, Ok(UndoOutcome::Undone { .. })) {
        with_core(|core| {
            let Some(number) = core.open_conversation else {
                // No conversation open: there is nothing for «in this
                // conversation» to name, and nothing is written. The
                // protection is still off.
                return;
            };
            for word in &words {
                core.vault.exempt_block(word, number);
            }
        });
    }
    // And the copy in the preview, which now holds fewer marks (rule 9).
    with_core(|core| the_decisions_are_written(core, session.id));
    outcome
}

pub(crate) fn undo_last_protection(session: SessionId) -> ApiResult<UndoOutcome> {
    let outcome = with_session(session.id, |s| {
        let last_act = match s.protections.iter().map(|p| p.act).max() {
            Some(act) => act,
            None => return Ok(UndoOutcome::NothingToUndo),
        };
        // **Every token of that act, not the first.** One act can hold several:
        // `protect_cell_in_lines` takes one cell in each held line under one
        // act id, and each cell is its own value and its own token. This said
        // «Took back T» about all of them until 15 October.
        let mut tokens: Vec<String> = Vec::new();
        for p in s.protections.iter().filter(|p| p.act == last_act) {
            if !tokens.iter().any(|t| t == &p.token) {
                tokens.push(p.token.clone());
            }
        }
        let before = s.protections.len();
        s.protections.retain(|p| p.act != last_act);
        let places = before.saturating_sub(s.protections.len()) as u32;

        // A token that is no longer anywhere stops being a token of this
        // conversation — the panel must not keep showing it.
        for token in &tokens {
            if !s.protections.iter().any(|p| &p.token == token) {
                s.tokens.remove(token);
            }
        }
        s.bump();
        Ok(UndoOutcome::Undone {
            tokens,
            places,
            // M4: set when the act had also created a vault identity.
            created_entity: None,
        })
    })
    .ok_or(ApiError::InvalidSession)?;
    with_core(|core| the_decisions_are_written(core, session.id));
    crate::session::bump_truth();
    outcome
}

pub(crate) fn add_alias(session: SessionId, token: String, alias: String) -> ApiResult<u32> {
    let applied = with_session(session.id, |s| {
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
    .ok_or(ApiError::InvalidSession)?;
    // A spelling taught is places protected, so it is a decision like any
    // other (rule 9) — and the word is a block like any other (rule 1).
    with_core(|core| the_decisions_are_written(core, session.id));
    applied
}

// ---------------------------------------------------------------- tokens

/// **The blocks standing on this surface** — the Tokens panel's own list, and
/// the count beside it in the snapshot.
///
/// A block is in use because a protection carries it, and the protections are
/// the document's. **When the question is all there is**, the blocks the
/// question itself made are the blocks on the surface — measured by e2 on
/// `8510d82` as `payload=false · tokens=0 · marks=2`, a panel with nothing in
/// it on the one surface where those two marks were everything the person had
/// protected, and therefore a dead press.
///
/// They come from the tokens `set_question` wrote when it protected the words
/// — the same act that drew the marks — and **never from a second scan**: a
/// list assembled by looking at the text again would be a second standard for
/// one text, and the first time the two disagreed the quieter one would win.
///
/// The condition is the one reading of the bench every door makes. With a
/// document on the bench the panel answers exactly as it did before: a
/// question *about* a document does not change what that document's panel
/// shows, which is what keeps this from being two panels.
pub(crate) fn list_tokens(session: SessionId) -> ApiResult<Vec<TokenRow>> {
    with_session(session.id, |s| {
        let mut in_use = s.tokens_in_use();
        if matches!(what_would_leave(s), WhatWouldLeave::TheQuestionAlone) {
            for token in &s.question_tokens {
                if !in_use.iter().any(|t| t == token) {
                    in_use.push(token.clone());
                }
            }
        }
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

/// **What the bench is holding, in the three states a turn records.**
///
/// `doc_name` is empty for text the person typed — `import_text` sets no name
/// because there is no file — and that is «Typed», not «we do not know». The
/// third state belongs to turns written before the field existed, so no live
/// path here can produce it.
fn document_of(session: u32) -> crate::api::TurnDocument {
    match with_session(session, |s| s.doc_name.clone()) {
        Some(name) if !name.trim().is_empty() => crate::api::TurnDocument::Named { name },
        Some(_) => crate::api::TurnDocument::Typed,
        // No bench at all: a caller that lost its session has a bigger problem
        // than a name, and inventing one here would be the guess this whole
        // field exists to refuse.
        None => crate::api::TurnDocument::NotRecorded,
    }
}

pub(crate) fn ingest_answer(
    payload: PayloadHandle,
    raw: String,
    via: crate::api::TurnVia,
) -> ApiResult<AnswerId> {
    // **What was asked is what left by this door** — rule 63: what the session
    // keeps is the record of the two doors, and rule 65: the whole of what left
    // moves into the chat.
    //
    // Until today this was `question_safe` — the request without the document
    // it was about. A chat drawn from that would show the person a first turn
    // they never sent, and the history the next question carries (rule 67)
    // would be a question the model was never shown with its document. So the
    // turn holds the payload **as it left**: document, `--- Request ---`,
    // request — or, for a follow-up, the question alone, which is also exactly
    // what left.
    //
    // Read through `view()`, which is the one accessor a payload's text leaves
    // by outside the network folder — the same string the Safe column is drawn
    // with. The other accessor has exactly one reader and G16 names it; this
    // comment may not even spell it, which is how blunt that gate is.
    let as_it_left = with_payload_record(payload, |p| p.view().text)?;
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
        let (allowed, kept, what_it_was) = with_session(payload.session, |s| {
            s.payloads
                .get(&payload.id)
                .map(|p| (p.allowed_token_ids.clone(), p.kept(), Some(p.what_it_is())))
                .unwrap_or_default()
        })
        .ok_or(ApiError::InvalidSession)?;
        // The question in the form that left, not as it was typed: the file
        // keeps both halves as they travelled, so nothing on disk resolves to a
        // name except through this session's own store.
        //
        // **Except when what left was the chat itself.** «Add an answer» after
        // «Copy the chat» binds the answer to the copy, so that every token the
        // chat ever carried is restored in it — and nothing new was asked. The
        // transcript written back in as a question would put the chat inside
        // itself, show the person a question they never typed, and carry the
        // whole thing twice to the next model. The payload is asked what it
        // was rather than this door remembering.
        let question = match what_it_was {
            Some(crate::payload::WhatThePayloadIs::TheChatItself) => String::new(),
            _ => as_it_left,
        };
        let document = document_of(payload.session);
        with_core(|core| {
            crate::ops::conversation::record_in(
                core,
                number,
                crate::ops::conversation::Exchange {
                    question,
                    answer: raw.clone(),
                    allowed,
                    via,
                    document,
                    kept,
                },
            )
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
                // The session's name is the person's own word.
                "this answer was taken in the session «{}», which has been deleted. \
                 Its key was destroyed with it, so nothing can be unprotected from it again.",
                crate::text::their_own_word(&name)
            ),
        });
    }
    // **The bench's store, and the blocks behind it** — the same ruling the
    // cold read of a turn follows (`ops::conversation::turns`): an answer taken
    // in a conversation whose bench is gone resolves from the vault's blocks,
    // and a token the payload did not allow stays a token however well they
    // know it. `with_core` rather than `with_session` because the vault has to
    // be in hand beside the store, and both are read, never written.
    with_core(|core| {
        let s = core.sessions_get(session.id).ok_or(ApiError::InvalidSession)?;
        let kept = s.answers.get(&answer.id).ok_or(ApiError::UnknownToken)?;
        let payload = s.payloads.get(&kept.payload).ok_or(ApiError::InvalidHandle)?;
        let vault = &core.vault;
        let ask = |token: &str| vault.block_value_for(token);
        let values = crate::tokens::Values::and_blocks(&s.tokens, &ask);
        Ok(restore(&kept.raw, &values, &payload.allowed_token_ids))
    })
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
        // **Asked of the bench, not of its document** — rule 55-ز. This read
        // `|| s.original.is_empty()` until 22 October, so a bench whose only
        // work was a typed request never took the open session's naming: its
        // tokens kept the random names a shut vault gives, and
        // `blocks_from_this_bench` — which asks `names_from_the_vault` before
        // it writes anything — therefore wrote **no block at all**, on any
        // act, for as long as that bench lived. A naming is about the session,
        // not about what happens to be on the bench (064, `Naming::of_session`
        // has no document in its input), so there was nothing for the document
        // to decide here.
        if s.mint.names_from_the_vault() {
            return;
        }
        if let Some(naming) = core.vault.naming_of(number) {
            if let Some((s, _)) = core.session_and_vault(session) {
                s.mint.name_from(naming);
            }
        }
    });
}

/// **Every word this bench has given a token becomes a block in the vault** —
/// 089 rule 1, and the owner's own rule of 15 October: «كل كلمة يأخذ رمزاً… هي
/// بلوك غير قابل للحذف من خزنة المستخدم».
///
/// **The bench's own token store is the list, and there is no second one.** A
/// word takes a token in exactly one way — `TokenMint::mint`, into
/// `TokenStore::insert` — and the store is what that writes into, keyed by the
/// token the word carries **now**: a session's birth renames every key with it
/// (`Session::names_again_from`), so a ledger of my own would be a seventh
/// place holding a token as a string and a seventh chance of drift. Keying the
/// blocks off the store also settles rule 5 by construction: «Leave it» inserts
/// nothing, so a word left in the clear makes no block, and there is no second
/// rule anywhere that has to remember that.
///
/// **What is left out, and why.**
///
///   * **The answer page's own word** (`ANSWER_PAGE_WORD`). It is minted by
///     this bench like any other because the owner asked for it to be protected
///     like any other, and it is ours: a block of it would protect the word
///     «Zprivacy-svara» in every document a person ever opens, for ever.
///     `TokenStore::words_it_named` drops it, beside the store, so no caller
///     can forget.
///   * **A bench that does not yet name from the vault's key.** Before a
///     conversation is born the names are random, they are about to be renamed,
///     and there is no conversation for them to belong to. Nothing is lost by
///     waiting: the birth drains the bench itself
///     (`ops::conversation::take_the_names`).
///
/// **One pass, one file write, per act** — a scan that protects eleven names
/// reseals `vault.zv` once. Returns a count and never a value.
///
/// **And a write that fails heals itself**, which is the other gain of having
/// no ledger: if the vault refuses the write (another copy changed the file
/// under us, `ensure_disk_unchanged`), the words are still in the bench's
/// store, so the next act writes them. A queue of its own would have had to be
/// replayed by somebody.
pub(crate) fn blocks_from_this_bench(
    core: &mut crate::session::Core,
    session: u32,
) -> ApiResult<u32> {
    let words = match core.get(session) {
        Some(s) if s.mint.names_from_the_vault() => s.tokens.words_it_named(),
        // Not a refusal: a bench that does not yet name from a session's key
        // has nothing a block could belong to, and the birth that gives it one
        // writes them all (rule 55-ز moved that birth to the first act worth
        // keeping, so the wait is now one act long at most).
        _ => return Ok(0),
    };
    core.vault.remember_blocks(&words)
}

/// **What just happened is written down** — 089 rules 1–2 and rule 9, in one
/// call because they are one moment.
///
/// A person protected a word, or confirmed a suggestion, or a scan put a value
/// back. Two things are then true and both have to be on disk: the word is a
/// **block** in the vault, for ever; and the document in the preview now has
/// one more decision on it, so a power cut must find it with that decision.
///
/// **One function rather than two calls at seven doors.** The list of doors
/// that can make a decision is the same list for both facts, and two calls at
/// each is one chance per door to write half of what happened. G35 reads this
/// name in every door's body, and G36 reads that this is where both are
/// written.
pub(crate) fn the_decisions_are_written(core: &mut crate::session::Core, session: u32) {
    let blocks = blocks_from_this_bench(core, session);
    // The copy is replaced, never added to: the bench holds the number of the
    // document it is working on. A failure to write it leaves the copy as it
    // was — older, never wrong — and the next act writes it again.
    //
    // **And it is not written at all beside a refused block** — paper 102 §3,
    // the sharpest of the three faults the two-window round measured, because
    // the glass stays green through it: `sessions/1.zs` was written while
    // `vault.zv` was refused, so the disk held a document naming twenty-three
    // protected places whose blocks were in no vault — and `open_kept`
    // rebuilds the token store from the marks and the text, so that document
    // re-opens **showing them protected**. A copy older than the vault is
    // never wrong; a copy ahead of it is a promise the vault cannot keep.
    let refused = match blocks {
        Ok(_) => conversation::keep_the_preview(core, session).err(),
        Err(refusal) => Some(refusal),
    };
    // **And what the disk said is recorded, not discarded** — paper 102 §2.
    //
    // Both halves were thrown away here: the blocks' answer was a count whose
    // `0` also meant «refused», and the copy's error was discarded by name
    // with `let _ =`. A write that fails still heals itself — the words stay in
    // the bench's store and the next act writes them — but **only if a later
    // write can succeed**, and a copy whose vault fell behind refuses every
    // one of them until it is healed. So the verdict is a state the glass can
    // read, and the person is told the one thing they can act on.
    //
    // The blocks' refusal is the one reported when both could fail: it is the
    // one that breaks 089 rule 1, and it is also the one that stops the copy.
    core.the_disk_said(refused);
}

pub(crate) fn scan(session: SessionId) -> ApiResult<ScanReport> {
    // Before the scan, because the scan protects what the vault already knows
    // and those tokens must carry the derived name like every other.
    name_tokens_from_the_vault(session.id);
    let report = with_core(|core| {
        let vault_state = core.vault.state();
        let open_now = core.open_conversation;
        let (s, vault) = core.session_and_vault(session.id).ok_or(ApiError::InvalidSession)?;
        if s.original.is_empty() {
            return Err(ApiError::NothingToSend);
        }
        let sets = active_sets(s, vault);
        // Empty while the vault is locked: the layer is skipped by having nothing
        // to say, not by a flag someone could forget to check.
        let profile = s.profile_id.clone();
        let hints = vault.hints(profile.as_deref(), open_now);
        let exceptions = vault.exceptions(profile.as_deref());
        let taught = vault.label_rules(profile.as_deref());
        let names = vault.taught_names(profile.as_deref());
        rescan_with(s, &sets, &taught, &hints, &exceptions, &names);
        mark_scanned(s);
        Ok(report_of(s, vault_state))
    })?;
    with_core(|core| the_decisions_are_written(core, session.id));
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
                            // **One answer may never answer another kind's
                            // question** — the lead's ruling of 15 October,
                            // and C3's spirit: nothing is settled without the
                            // person's word.
                            //
                            // A decision about a word reaches every place
                            // where that word **stands alone**, and never a
                            // place lying inside a finding of another kind.
                            // 085 ruling 1 made this ordinary: «Katharina
                            // Lindemann» is the client of DE-1 and «Lindemann
                            // & Partner GmbH» is her employer, so her
                            // surname's own token was taking the company's
                            // first word — with `_PERSON_` inside it — and the
                            // company line stopped waiting for the answer it
                            // was waiting for. Now it keeps its question, and
                            // the person's answer decides it whole.
                            //
                            // Asked of the **settled** candidates and not of
                            // `s.findings`, which is still being built in this
                            // very loop: settle leaves no two candidates
                            // overlapping, so a candidate's own place can
                            // never be refused by this, and where the other
                            // kind is itself `Auto` it protects its whole span
                            // and settle has already decided as it always did.
                            if candidates
                                .iter()
                                .any(|other| other.kind != c.kind && other.start < to && from < other.end)
                            {
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
/// **The word each taught rule was taught** — read beside the scopes, outside
/// the session lock, for the same reason (G19).
///
/// The Why card needs it since the ruling of 16 October: a rule folded into a
/// finding another layer won used to reach the card as its bare source id
/// («you:u1»), which is not a sentence, and the one thing the person would
/// recognise — the word they typed — was the part that got lost.
fn taught_rule_labels() -> std::collections::BTreeMap<u32, String> {
    with_core(|core| {
        core.vault
            .with_open(|v| v.label_rules.iter().map(|r| (r.id, r.label.clone())).collect())
            .unwrap_or_default()
    })
}

/// One folded layer, as a sentence a person can read.
///
/// A set says «de:company-form agreed as well» and that is the shape every
/// guard since 046 has read; a **rule of the person's own** says what they
/// taught, because «you:u1» tells them nothing they know.
///
/// **The word they typed is isolated** — `text::their_own_word`, which is
/// `U+2068 … U+2069` — because it is theirs and may be in any script, and an
/// Arabic label inside an English sentence drags the quotation marks around
/// it. The glass has `theirOwnWord()` for the same job and cannot use it here:
/// what it is handed is a finished sentence, so the one place that writes this
/// one isolates it. It was the pair written out by hand until 17 October; one
/// function now, on both sides of the bridge, so that the next sentence to
/// need it has somewhere to call.
fn layer_sentence(detail: &str, labels: &std::collections::BTreeMap<u32, String>) -> String {
    match detail
        .strip_prefix("you:u")
        .and_then(|n| n.parse::<u32>().ok())
        .and_then(|id| labels.get(&id))
    {
        Some(label) => format!(
            "You taught Z Privacy to protect what follows «{}»",
            crate::text::their_own_word(label)
        ),
        None if detail.starts_with("you:") => "You taught Z Privacy this rule".to_string(),
        None => format!("{detail} agreed as well"),
    }
}

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

/// «de:label» → «A German privacy rule». The set names itself; a screen may
/// not, and neither may this sentence.
///
/// **And it asks for the language's English name, not its label** — paper 117
/// item 2. The label was «German (DE)» and this sentence read correctly by
/// accident; the day a language is named in its own words, «A Deutsch (DE)
/// privacy rule» is the second kind of wrong `LanguagePack::in_english` was
/// written for («a legal form in Svenska»). A reason is an English sentence:
/// the core is English only and the host translates what it shows.
///
/// A set with no pack beside it keeps its label, which is the honest fallback
/// — a name somebody can look up beats no name at all.
///
/// **Not reached by any fixture in this tree, and that is said out loud.** A
/// `LanguagePack` source only survives until the word becomes a vault block,
/// and since 089 every protected word is one — so every explanation the tests
/// can reach answers «You protected this word before». The guard that would
/// hold this line needs a scan whose finding is neither blocked nor protected,
/// which is a fixture of its own and not this round's.
fn set_label_of(source_detail: &str) -> String {
    let id = source_detail.split(':').next().unwrap_or_default();
    let in_english = crate::scanner::packs::installed_packs()
        .into_iter()
        .find(|p| p.id == id)
        .map(|p| p.in_english.to_string());
    crate::scanner::sets::all()
        .into_iter()
        .find(|s| s.id == id)
        .map(|s| format!("A {} privacy rule", in_english.unwrap_or_else(|| s.label.to_string())))
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
    with_core(|core| the_decisions_are_written(core, session.id));
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
                reason: "this session is not in a profile, so there is no profile exception to remember"
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
        let open_now = core.open_conversation;
        let (s, vault) = core.session_and_vault(session.id).ok_or(ApiError::InvalidSession)?;
        let profile = s.profile_id.clone();
        let sets = active_sets(s, vault);
        let hints = vault.hints(profile.as_deref(), open_now);
        let exceptions = vault.exceptions(profile.as_deref());
        let taught = vault.label_rules(profile.as_deref());
        let kept_tokens = s.tokens_in_use().len() as u32;
        // The same rule as the Rescan button, because they are the same act:
        // look again, and take nothing back.
        let names = vault.taught_names(profile.as_deref());
        let orphaned = rescan_with(s, &sets, &taught, &hints, &exceptions, &names);
        // 089 rule 1, for both switches at once: this is the one call a changed
        // pack and a changed profile both come through, and a rescan protects
        // what the new layers claim.
        the_decisions_are_written(core, session.id);
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
    // **And the open session learns it too** — 075c. The header is the one
    // place a language is changed, and this is the one call it comes through,
    // so the record follows the bench here instead of the screen having to
    // remember to tell the core twice. A failure to write it is not allowed to
    // undo a rescan the person can already see: it is reported by the next
    // read of the row, which is `None` or the old value, and never a lie about
    // which language the document was just scanned in.
    let open_now = with_core(|core| core.open_conversation);
    if let Some(number) = open_now {
        with_core(|core| core.vault.set_pack(number, &pack_id))?;
    }
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

        let answer =
            ingest_answer(handle, "ok".to_string(), crate::api::TurnVia::Pasted).expect("ingest");
        let segments = restored_view(s, answer).expect("restored");
        assert!(!format!("{segments:?}").contains("ok"), "{segments:?}");
    }
}

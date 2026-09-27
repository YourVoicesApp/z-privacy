//! The work behind the contract.
//!
//! `api.rs` is kept as a bare surface — one line per function — so that the
//! gates can read every signature and so the contract is easy to see whole.
//! What each call actually does lives here.

mod vault;

pub(crate) use vault::*;

use std::collections::BTreeMap;

use crate::api::{
    ApiError, ApiResult, AnswerId, DocumentKind, Finding, FindingAnswer, LayerCount, Segment, DocumentView, Kind,
    Mark, MarkState, PackRow, PayloadHandle, PayloadView, ProtectOutcome, ProviderId, ProviderRow, RevealedValue,
    RescanOutcome, Revision, ScanReport, Scope, SessionId, Source, Span, SwitchOutcome, TokenRow,
    UndoOutcome,
};
use crate::secret::Secret;
use crate::vault::model::ProviderLogin;
use crate::scanner;
use crate::session::FindingRecord;
use crate::payload::SafePayload;
use crate::session::{with_core, with_session, Protection, Session};
use crate::text;
use crate::tokens::{restore, TokenEntry};

/// How long a revealed value stays on screen before it hides itself.
const REVEAL_TTL_MS: u32 = 20_000;

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
        s.bump();
        view_of(s)
    })
    .ok_or(ApiError::InvalidSession)?
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
        s.doc_kind = kind;
        s.protections.clear();
        s.findings.clear();
        s.bump();
        view_of(s)
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn document_view(session: SessionId) -> ApiResult<DocumentView> {
    with_session(session.id, view_of).ok_or(ApiError::InvalidSession)?
}

/// The original text with one mark per protection, in UTF-16 spans for Dart.
fn view_of(s: &mut Session) -> ApiResult<DocumentView> {
    let mut marks = Vec::with_capacity(s.protections.len());
    for p in &s.protections {
        let span: Span = text::bytes_to_span(s.original_str(), p.start, p.end)?;
        marks.push(Mark {
            span,
            state: MarkState::Protected,
            token: Some(p.token.clone()),
            kind: p.kind,
            source: p.source,
            source_detail: p.source_detail.clone(),
            place: s.place_of(p.start),
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
    with_session(session.id, |s| {
        if s.original.is_empty() {
            return Err(ApiError::NothingToSend);
        }
        let id = s.take_payload_id();
        let payload = SafePayload::build(s, id);
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
    let raw = crate::providers::ask(
        handle,
        &provider.id,
        login.credential.expose(),
        &login.base,
        &login.model,
    )?;

    // The raw answer stays here. What the UI gets is an id; what it can then ask
    // for is the restored view, or the model's own words, both from this store.
    ingest_answer(SessionId { id: handle.session }, raw)
}

// ---------------------------------------------------------------- providers (M6)

/// Every provider this build knows, and whether it can be used right now.
///
/// There is no function anywhere in the contract that returns a credential. This
/// is the only thing the UI learns about one: that it exists, and whether it will
/// still exist tomorrow.
pub(crate) fn providers() -> ApiResult<Vec<ProviderRow>> {
    let mut rows = Vec::new();
    for provider in crate::providers::known() {
        let sealed = login_in_vault(provider.id());
        let in_session = with_core(|core| core.session_logins.get(provider.id()).cloned());
        let login = sealed.clone().or_else(|| in_session.clone());
        rows.push(ProviderRow {
            id: provider.id().to_string(),
            label: provider.label().to_string(),
            connected: login.is_some(),
            session_only: sealed.is_none() && in_session.is_some(),
            base_url: login
                .as_ref()
                .map(|l| l.base.clone())
                .unwrap_or_else(|| provider.default_base().to_string()),
            model: login
                .as_ref()
                .map(|l| l.model.clone())
                .unwrap_or_else(|| provider.default_model().to_string()),
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
pub(crate) fn connect_provider(provider: ProviderId, credential: String, base_url: Option<String>) -> ApiResult<ProviderRow> {
    let known = crate::providers::find(&provider.id)?;
    let credential = credential.trim().to_string();
    if credential.is_empty() {
        return Err(ApiError::ImportRefused {
            reason: "a provider needs a credential; an empty one connects nothing".to_string(),
        });
    }
    let base = base_url
        .map(|b| b.trim().to_string())
        .filter(|b| !b.is_empty())
        .unwrap_or_else(|| known.default_base().to_string());
    // The address is checked before the credential is stored, so that a typo is
    // an error the user sees now rather than the first time they press Send.
    crate::providers::check_url_for(&base)?;

    let login = ProviderLogin {
        credential: Secret::new(credential),
        base,
        model: known.default_model().to_string(),
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
fn login_in_vault(id: &str) -> Option<ProviderLogin> {
    with_core(|core| core.vault.with_open(|vault| vault.provider_logins.get(id).cloned()).ok().flatten())
}

/// The credential to use: the vault's if it is open, this run's otherwise.
fn login_for(id: &str) -> ApiResult<ProviderLogin> {
    let found = login_in_vault(id).or_else(|| with_core(|core| core.session_logins.get(id).cloned()));
    found.ok_or_else(|| {
        crate::providers::not_connected(id)
    })
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

// ---------------------------------------------------------------- protect

pub(crate) fn protect(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    protect_inner(session, span, scope, kind, false)
}

pub(crate) fn protect_all_matches(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    protect_inner(session, span, scope, kind, true)
}

fn protect_inner(
    session: SessionId,
    span: Span,
    scope: Scope,
    kind: Kind,
    all_matches: bool,
) -> ApiResult<ProtectOutcome> {
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
                let minted = s.mint.mint(kind, &s.tokens);
                s.tokens.insert(
                    minted.clone(),
                    TokenEntry {
                        value: crate::secret::Secret::new(selected.clone()),
                        aliases: Vec::new(),
                        kind,
                        scope,
                        source: Source::Hand,
                        source_detail: "selected by you".to_string(),
                    },
                );
                minted
            }
        };

        let act = s.take_act_id();
        let mut places = Vec::new();
        if all_matches {
            places.extend(occurrences(s.original_str(), &selected));
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
) -> Option<String> {
    let value = s.original_str().get(start..end)?.to_string();
    if s.protections.iter().any(|p| p.start < end && start < p.end) {
        return None;
    }
    let token = match s.tokens.token_for(&value) {
        Some(existing) => existing.to_string(),
        None => {
            let minted = s.mint.mint(kind, &s.tokens);
            s.tokens.insert(
                minted.clone(),
                TokenEntry {
                    value: crate::secret::Secret::new(value),
                    aliases: Vec::new(),
                    kind,
                    scope,
                    source,
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
    });
    s.protections.sort_by_key(|p| p.start);
    Some(token)
}

/// Every place `needle` appears in `haystack`, as byte ranges, left to right and
/// non-overlapping.
fn occurrences(haystack: &str, needle: &str) -> Vec<(usize, usize)> {
    let mut out = Vec::new();
    if needle.is_empty() {
        return out;
    }
    let mut from = 0usize;
    while let Some(rest) = haystack.get(from..) {
        match rest.find(needle) {
            Some(at) => {
                let start = from + at;
                let end = start + needle.len();
                out.push((start, end));
                from = end;
            }
            None => break,
        }
    }
    out
}

pub(crate) fn undo_last_protection(session: SessionId) -> ApiResult<UndoOutcome> {
    with_session(session.id, |s| {
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
    .ok_or(ApiError::InvalidSession)?
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
        for (from, to) in occurrences(s.original_str(), &alias) {
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
    with_session(session.id, |s| match s.tokens.get(&token) {
        Some(entry) => Ok(RevealedValue {
            token,
            // Handed over because the user asked to see it, for a moment, locally.
            value: entry.value.expose().to_string(),
            ttl_ms: REVEAL_TTL_MS,
        }),
        None => Err(ApiError::UnknownToken),
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn hide(session: SessionId, token: String) -> ApiResult<()> {
    // Revealing never changed anything here, so hiding has nothing to undo: the
    // showing lives in the UI. This call only confirms the token is real, so the
    // UI can trust its own state.
    with_session(session.id, |s| {
        if s.tokens.contains(&token) {
            Ok(())
        } else {
            Err(ApiError::UnknownToken)
        }
    })
    .ok_or(ApiError::InvalidSession)?
}

// ---------------------------------------------------------------- answer

pub(crate) fn ingest_answer(session: SessionId, raw: String) -> ApiResult<AnswerId> {
    with_session(session.id, |s| {
        let id = s.take_answer_id();
        s.answers.insert(id, raw);
        // An answer coming in changes nothing about what would go out, so the
        // revision does not move and no handle goes stale.
        Ok(AnswerId { id })
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn restored_view(session: SessionId, answer: AnswerId) -> ApiResult<Vec<Segment>> {
    with_session(session.id, |s| match s.answers.get(&answer.id) {
        Some(raw) => Ok(restore(raw, &s.tokens)),
        None => Err(ApiError::UnknownToken),
    })
    .ok_or(ApiError::InvalidSession)?
}

pub(crate) fn ai_view(session: SessionId, answer: AnswerId) -> ApiResult<String> {
    with_session(session.id, |s| match s.answers.get(&answer.id) {
        Some(raw) => Ok(raw.clone()),
        None => Err(ApiError::UnknownToken),
    })
    .ok_or(ApiError::InvalidSession)?
}

// ---------------------------------------------------------------- scan (M3)

pub(crate) fn scan(session: SessionId) -> ApiResult<ScanReport> {
    with_core(|core| {
        let vault_state = core.vault.state();
        let (s, vault) = core.session_and_vault(session.id).ok_or(ApiError::InvalidSession)?;
        if s.original.is_empty() {
            return Err(ApiError::NothingToSend);
        }
        let pack = s.pack_id.clone();
        // Empty while the vault is locked: the layer is skipped by having nothing
        // to say, not by a flag someone could forget to check.
        let hints = vault.hints(s.profile_id.as_deref());
        let candidates = scanner::scan(s.original_str(), &pack, &hints);

        // What you protected by hand is never touched by a rescan; what a layer
        // decided is recomputed from scratch.
        s.protections.retain(|p| p.source == Source::Hand);
        s.findings.clear();
        let act = s.take_act_id();

        for c in &candidates {
            // Your word wins: a candidate under a hand protection is not reported.
            if s.protections.iter().any(|p| p.start < c.end && c.start < p.end) {
                continue;
            }
            let state = match c.confidence {
                scanner::Confidence::Auto => {
                    match protect_range(s, c.start, c.end, c.kind, Scope::Conversation, c.source, &c.source_detail, act) {
                        Some(_) => MarkState::Protected,
                        // Already covered by something else: not reported twice.
                        None => continue,
                    }
                }
                scanner::Confidence::Suggest => MarkState::Suggested,
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
                entities: c.entities.clone(),
            });
        }

        s.normal_words = scanner::plain_word_count(s.original_str(), &candidates);
        s.bump();
        Ok(report_of(s, vault_state))
    })
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
        for f in &s.findings {
            out.push(Finding {
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

pub(crate) fn answer_finding(session: SessionId, finding: u32, answer: FindingAnswer) -> ApiResult<ScanReport> {
    let vault_state = vault_state()?;
    with_session(session.id, |s| {
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
                s.findings.remove(index);
                s.bump();
                Ok(report_of(s, vault_state))
            }
            FindingAnswer::Protect | FindingAnswer::Always => {
                let act = s.take_act_id();
                // Note for M4: `Always` will also write a vault identity. Until
                // the vault exists it protects here and says so in the reason.
                let detail = record.source_detail.clone();
                let protected = protect_range(
                    s,
                    record.start,
                    record.end,
                    record.kind,
                    Scope::Conversation,
                    record.source,
                    &detail,
                    act,
                );
                if protected.is_none() {
                    return Err(ApiError::BadSpan {
                        reason: "that place is already covered by another protection".to_string(),
                    });
                }
                if let Some(f) = s.findings.get_mut(index) {
                    f.state = MarkState::Protected;
                    f.reason = match answer {
                        FindingAnswer::Always => format!("{} · confirmed by you, to be kept in the vault (M4)", f.reason),
                        _ => format!("{} · confirmed by you", f.reason),
                    };
                }
                s.bump();
                Ok(report_of(s, vault_state))
            }
        }
    })
    .ok_or(ApiError::InvalidSession)?
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
fn rescan_keeping(session: SessionId, pack: &str) -> ApiResult<(u32, u32)> {
    with_core(|core| {
        let (s, vault) = core.session_and_vault(session.id).ok_or(ApiError::InvalidSession)?;
        let hints = vault.hints(s.profile_id.as_deref());
        let candidates = scanner::scan(s.original_str(), pack, &hints);
        let kept_tokens = s.tokens_in_use().len() as u32;

        // Anything a layer used to claim and no longer does becomes manual.
        let mut changed_to_manual = 0u32;
        for p in s.protections.iter_mut() {
            let still_claimed = candidates.iter().any(|c| c.start == p.start && c.end == p.end);
            if !still_claimed && p.source != Source::Hand {
                p.source = Source::Hand;
                p.source_detail = "kept from an earlier layer, now yours".to_string();
                changed_to_manual = changed_to_manual.saturating_add(1);
            }
        }

        s.findings.clear();
        let act = s.take_act_id();
        for c in &candidates {
            let covered = s.protections.iter().any(|p| p.start < c.end && c.start < p.end);
            let state = if covered {
                MarkState::Protected
            } else {
                match c.confidence {
                    scanner::Confidence::Auto => {
                        match protect_range(s, c.start, c.end, c.kind, Scope::Conversation, c.source, &c.source_detail, act) {
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
                entities: c.entities.clone(),
            });
        }
        s.normal_words = scanner::plain_word_count(s.original_str(), &candidates);
        s.bump();
        Ok((kept_tokens, changed_to_manual))
    })
}

pub(crate) fn switch_profile(session: SessionId, profile_id: String) -> ApiResult<SwitchOutcome> {
    let pack = with_session(session.id, |s| {
        s.profile_id = Some(profile_id);
        s.pack_id.clone()
    })
    .ok_or(ApiError::InvalidSession)?;
    let (kept_tokens, _) = rescan_keeping(session, &pack)?;
    let revision = with_session(session.id, |s| s.revision).ok_or(ApiError::InvalidSession)?;
    Ok(SwitchOutcome { kept_tokens, revision })
}

pub(crate) fn switch_pack(session: SessionId, pack_id: String) -> ApiResult<RescanOutcome> {
    if !scanner::packs::installed().iter().any(|p| p.id == pack_id) {
        return Err(ApiError::ImportRefused {
            reason: format!("there is no privacy pack called «{pack_id}»"),
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
                entities: Vec::new(),
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

        let answer = ingest_answer(s, "ok".to_string()).expect("ingest");
        let segments = restored_view(s, answer).expect("restored");
        assert!(!format!("{segments:?}").contains("ok"), "{segments:?}");
    }
}

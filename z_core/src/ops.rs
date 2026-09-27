//! The work behind the contract.
//!
//! `api.rs` is kept as a bare surface — one line per function — so that the
//! gates can read every signature and so the contract is easy to see whole.
//! What each call actually does lives here.

use crate::api::{
    ApiError, ApiResult, AnswerId, DocumentView, Mark, MarkState, PayloadHandle, PayloadView,
    ProviderId, Revision, SessionId, Span,
};
use crate::payload::SafePayload;
use crate::session::{with_core, with_session, Session};
use crate::text;

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
    with_session(session.id, |s| {
        s.original = text_in;
        // A new document means the old protections describe nothing. Payloads
        // are kept so an old handle can still explain itself as stale.
        s.protections.clear();
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
        let span: Span = text::bytes_to_span(&s.original, p.start, p.end)?;
        marks.push(Mark {
            span,
            state: MarkState::Protected,
            token: Some(p.token.clone()),
            kind: p.kind,
            source: p.source,
            source_detail: p.source_detail.clone(),
        });
    }
    marks.sort_by_key(|m| m.span.start);
    Ok(DocumentView {
        text: s.original.clone(),
        marks,
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
    // M6 opens the network. Until then the door is honestly closed.
    Err(ApiError::ProviderUnavailable {
        provider: provider.id,
    })
}

/// Look a handle up and check it twice: the stored payload must be built on the
/// session's current revision, and the handle itself must name that same
/// revision. The store is trusted, never the handle.
fn with_payload<R>(handle: PayloadHandle, f: impl FnOnce(&SafePayload) -> R) -> ApiResult<R> {
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

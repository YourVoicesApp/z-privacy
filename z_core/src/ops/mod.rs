//! The work behind the contract.
//!
//! `api.rs` is kept as a bare surface — one line per function — so that the
//! gates can read every signature and so the contract is easy to see whole.
//! What each call actually does lives here.

mod vault;
mod snapshots;

pub(crate) use vault::*;
pub(crate) use snapshots::*;

use std::collections::BTreeMap;

use crate::api::{
    ApiError, ApiResult, AnswerId, DocumentKind, Finding, FindingAnswer, LayerCount, Segment, DocumentView, Kind,
    Explanation, Mark, MarkState, PackRow, PayloadHandle, PayloadView, ProtectOutcome, ProviderId,
    ProviderRow, RevealedValue, SelectionView,
    RescanOutcome, Revision, ScanReport, Scope, SessionId, Source, Span, SwitchOutcome, TokenRow,
    UndoOutcome,
};
use crate::secret::Secret;
use crate::vault::model::ProviderLogin;
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
    ingest_answer(handle, raw)
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
        let connected = login
            .as_ref()
            .is_some_and(|l| login_is_usable(provider.as_ref(), l));
        rows.push(ProviderRow {
            id: provider.id().to_string(),
            label: provider.label().to_string(),
            connected,
            session_only: connected && sealed.is_none() && in_session.is_some(),
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
        return Err(ApiError::ImportRefused {
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
fn login_for(id: &str) -> ApiResult<ProviderLogin> {
    let found = login_in_vault(id).or_else(|| with_core(|core| core.session_logins.get(id).cloned()));
    let login = found.ok_or_else(|| crate::providers::not_connected(id))?;
    let provider = crate::providers::find(id)?;
    if !login_is_usable(provider.as_ref(), &login) {
        return Err(crate::providers::not_connected(id));
    }
    Ok(login)
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
            });
        }

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
            scanner::scan(&selected, &s.pack_id, &vault_hints)
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
            kind: guessed.or(from_mark).unwrap_or(Kind::Custom),
            matches: occurrences(s.original_str(), &selected).len() as u32,
            protected_as: exact.map(|p| p.token.clone()),
            protected_by: exact.map(|p| p.source),
            protected_detail: exact.map(|p| p.source_detail.clone()).unwrap_or_default(),
            entities,
            snaps_to,
        })
    })
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

        let headline = match (p.source, p.decided) {
            (Source::Hand, _) => "You protected this by hand",
            (Source::Vault, _) => "You taught Z Privacy this value",
            (Source::LanguagePack, true) => "A German privacy rule found it, and you agreed",
            (Source::LanguagePack, false) => "A German privacy rule",
            (Source::GeneralRule, true) => "A shape that needs no language, and you agreed",
            (Source::GeneralRule, false) => "A shape that needs no language",
        }
        .to_string();

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
                "What found this no longer claims it — the value was forgotten, or the pack                  changed. It stays protected here so that taking it back does not expose it.                  «Remove protection» is the way to take it back."
                    .to_string(),
            );
        }

        let applies = match p.scope {
            Scope::Once => "This one place".to_string(),
            Scope::Conversation => "This conversation".to_string(),
            Scope::Profile => match &s.profile_id {
                Some(id) => format!("Profile — {id}"),
                None => "This conversation".to_string(),
            },
            Scope::Always => "Everywhere".to_string(),
        };

        Ok(Explanation {
            headline,
            because,
            kind: p.kind,
            scope: p.scope,
            applies,
            decided: p.decided,
            token: p.token.clone(),
            learned_at: known.as_ref().map(|k| k.learned_at).unwrap_or(0),
            entity: known.as_ref().map(|k| k.entity),
            value_id: known.as_ref().map(|k| k.value_id),
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

pub(crate) fn protect(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
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
        return Err(ApiError::ImportRefused {
            reason: "this conversation is not in a profile, so there is no profile to remember it                      for — choose «always», or open a profile first"
                .to_string(),
        });
    }
    let wanted = if profile_only { profile } else { None };
    crate::ops::learn_value(wanted, kind, text)
}

pub(crate) fn protect_all_matches(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    if matches!(scope, Scope::Always | Scope::Profile) {
        require_open_vault()?;
    }
    remember_in_vault(session, span, scope, kind)?;
    let outcome = protect_inner(session, span, scope, kind, true)?;
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
            let minted = s.mint.mint(kind, &s.tokens);
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
    with_session(session.id, |s| match s.tokens.get(&token) {
        Some(entry) => Ok(RevealedValue {
            token,
            // Handed over because the user asked to see it, for a moment, locally.
            value: entry.value.expose().to_string(),
            aliases: entry.aliases.iter().map(|a| a.expose().to_string()).collect(),
            ttl_ms,
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

pub(crate) fn ingest_answer(payload: PayloadHandle, raw: String) -> ApiResult<AnswerId> {
    with_payload_record(payload, |_| ())?;
    let out = with_session(payload.session, |s| {
        let id = s.take_answer_id();
        s.answers.insert(
            id,
            AnswerRecord {
                id,
                session: payload.session,
                payload: payload.id,
                raw,
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

pub(crate) fn scan(session: SessionId) -> ApiResult<ScanReport> {
    let report = with_core(|core| {
        let vault_state = core.vault.state();
        let (s, vault) = core.session_and_vault(session.id).ok_or(ApiError::InvalidSession)?;
        if s.original.is_empty() {
            return Err(ApiError::NothingToSend);
        }
        let pack = s.pack_id.clone();
        // Empty while the vault is locked: the layer is skipped by having nothing
        // to say, not by a flag someone could forget to check.
        let hints = vault.hints(s.profile_id.as_deref());
        rescan_with(s, &pack, &hints);
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
fn rescan_with(s: &mut Session, pack: &str, hints: &[crate::vault::model::VaultHint]) -> u32 {
    let candidates = scanner::scan(s.original_str(), pack, hints);

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
                    match protect_range(s, c.start, c.end, c.kind, Scope::Conversation, c.source, &c.source_detail, act, false) {
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
                s.findings.remove(index);
                s.bump();
                Ok(report_of(s, vault_state))
            }
            FindingAnswer::Protect | FindingAnswer::Always => {
                let act = s.take_act_id();
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
                    // A person answered. This is what keeps it through a rescan.
                    true,
                );
                if protected.is_none() {
                    return Err(ApiError::BadSpan {
                        reason: "that place is already covered by another protection".to_string(),
                    });
                }
                if let Some(f) = s.findings.get_mut(index) {
                    f.state = MarkState::Protected;
                    // A person decided. This is what carries it through a
                    // rescan, and what puts it under «protected by you».
                    f.decided = true;
                    f.reason = match answer {
                        FindingAnswer::Always => format!("{} · confirmed by you, and kept in the vault", f.reason),
                        _ => format!("{} · confirmed by you", f.reason),
                    };
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
        let kept_tokens = s.tokens_in_use().len() as u32;
        // The same rule as the Rescan button, because they are the same act:
        // look again, and take nothing back.
        let orphaned = rescan_with(s, pack, &hints);
        Ok((kept_tokens, orphaned))
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

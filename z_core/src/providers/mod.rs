//! The network — one door, and the only reader of the outgoing text.
//!
//! Everything about this module is a boundary rather than a feature:
//!
//! * [`SafePayload::wire_text`](crate::payload::SafePayload::wire_text) has existed
//!   since M2 with no caller at all. It gets one here, and gate **G16** fails the
//!   build if the name appears anywhere outside this folder. The text was built
//!   first and audited first; the wire was only then allowed to stand behind it.
//! * One HTTP client, named in one file ([`http`]), and gate **G1** keeps it there.
//! * A provider is given a credential, an address, a model and the safe text.
//!   It is not given the session, the vault, the original, or the token table.
//!
//! What this module does **not** claim: it protects what is written in a document,
//! not the fact that a request was made. See §1 of `docs/SECURITY_INVARIANTS.md`.

#[cfg(feature = "fake_provider")]
pub(crate) mod fake;
mod http;
mod openai;

use zeroize::Zeroizing;

use crate::api::{ApiError, ApiResult, NetworkRefusal, PayloadHandle};

/// How much outgoing text a provider accepts, before a socket is opened.
///
/// Not about leaking — the audit already answered that — but about not turning a
/// large document into an unreasonable request, or into a second copy of itself in
/// memory for no purpose. A provider may raise or lower it; this is the default.
const DEFAULT_REQUEST_BYTES: usize = 512 * 1024;

/// What every provider must be able to do, and nothing more.
pub(crate) trait Provider {
    fn id(&self) -> &'static str;
    fn label(&self) -> &'static str;
    fn default_base(&self) -> &'static str;
    fn default_model(&self) -> &'static str;

    /// The outgoing limit for this provider. One place to change per provider the
    /// day a model's context makes a different number the right one.
    fn max_request_bytes(&self) -> usize {
        DEFAULT_REQUEST_BYTES
    }
    /// One question, one answer. `text` is the safe payload; there is no argument
    /// through which anything else could be passed.
    fn ask(&self, credential: &str, base: &str, model: &str, text: &str) -> ApiResult<String>;
}

/// Every provider this build knows, in the order the UI should list them.
pub(crate) fn known() -> Vec<Box<dyn Provider>> {
    // `mut` is used only in a build that has the echo provider.
    #[allow(unused_mut)]
    let mut out: Vec<Box<dyn Provider>> = vec![Box::new(openai::OpenAiCompatible)];
    // Only in a build made for the tests. A release has no echo provider to pick.
    #[cfg(feature = "fake_provider")]
    out.push(Box::new(fake::Echo));
    out
}

pub(crate) fn find(id: &str) -> ApiResult<Box<dyn Provider>> {
    known()
        .into_iter()
        .find(|p| p.id() == id)
        .ok_or_else(|| ApiError::ProviderUnavailable { provider: id.to_string() })
}

/// Ask a provider the question a payload holds.
///
/// The text is copied out of the store while the core's lock is held, and the
/// lock is released before the socket opens: a slow provider must not freeze
/// every other call in the program for a minute.
pub(crate) fn ask(handle: PayloadHandle, id: &str, credential: &str, base: &str, model: &str) -> ApiResult<String> {
    let provider = find(id)?;
    let text = crate::ops::with_payload(handle, |p| Zeroizing::new(p.wire_text().to_string()))?;
    check_size(text.len(), provider.as_ref())?;
    provider.ask(credential, base, model, &text)
}

/// The outgoing limit, checked before a socket is opened and before a body is
/// built — so nothing large is copied in order to discover it was too large.
fn check_size(bytes: usize, provider: &dyn Provider) -> ApiResult<()> {
    let limit = provider.max_request_bytes();
    if bytes > limit {
        return Err(refuse(
            NetworkRefusal::PayloadTooLarge {
                kib: (bytes / 1024) as u32,
                limit_kib: (limit / 1024) as u32,
            },
            format!(
                "this text is {} KiB and {} accepts {} KiB in one request",
                bytes / 1024,
                provider.label(),
                limit / 1024
            ),
        ));
    }
    Ok(())
}

/// The connection test. Sends the word `ping` — none of the user's words.
pub(crate) fn ping(id: &str, credential: &str, base: &str, model: &str) -> ApiResult<u32> {
    let provider = find(id)?;
    let started = std::time::Instant::now();
    provider.ask(credential, base, model, "ping")?;
    Ok(started.elapsed().as_millis().min(u128::from(u32::MAX)) as u32)
}

/// Check an address the way a request would, before a credential is stored.
pub(crate) fn check_url_for(base: &str) -> ApiResult<()> {
    http::check_url(base)
}

/// The one refusal that is not about the network at all: nothing was connected.
pub(crate) fn not_connected(id: &str) -> ApiError {
    refuse(
        NetworkRefusal::NotConnected,
        format!("{id} has no credential in this run"),
    )
}

/// A refusal with a detail built from names and numbers, never from a response.
pub(crate) fn refuse(reason: NetworkRefusal, detail: impl Into<String>) -> ApiError {
    ApiError::NetworkRefused {
        reason,
        detail: detail.into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_provider_has_an_https_default_and_a_model() {
        for p in known() {
            assert!(!p.id().is_empty(), "a provider without an id");
            assert!(!p.label().is_empty(), "provider {} has no label", p.id());
            assert!(!p.default_model().is_empty(), "provider {} has no model", p.id());
            let base = p.default_base();
            assert!(
                base.starts_with("https://") || http::is_loopback_url(base),
                "provider {} defaults to {base}, which is neither https nor this machine",
                p.id()
            );
        }
    }

    #[test]
    fn a_text_past_the_outgoing_limit_is_refused_before_any_socket() {
        let provider = openai::OpenAiCompatible;
        let limit = provider.max_request_bytes();
        assert!(check_size(limit, &provider).is_ok(), "exactly at the limit is allowed");
        match check_size(limit + 1, &provider) {
            Err(ApiError::NetworkRefused {
                reason: NetworkRefusal::PayloadTooLarge { kib, limit_kib },
                detail,
            }) => {
                assert_eq!(limit_kib, (limit / 1024) as u32);
                assert_eq!(kib, (limit / 1024) as u32, "one byte over rounds to the same KiB");
                assert!(detail.contains("KiB"), "{detail}");
            }
            other => panic!("expected PayloadTooLarge, got {other:?}"),
        }
    }

    #[test]
    fn an_unknown_provider_is_named_not_guessed() {
        match find("definitely-not-a-provider").map(|p| p.id()) {
            Err(ApiError::ProviderUnavailable { provider }) => assert_eq!(provider, "definitely-not-a-provider"),
            other => panic!("expected ProviderUnavailable, got {other:?}"),
        }
    }
}

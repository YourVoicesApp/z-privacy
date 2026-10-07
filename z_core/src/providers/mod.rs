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
mod anthropic;
mod deepseek;
mod google;
mod http;
mod moonshot;
mod openai;
mod xai;

use zeroize::Zeroizing;

use crate::api::{ApiError, ApiResult, NetworkRefusal, PayloadHandle};

pub(crate) struct ProviderAttempt<T> {
    pub result: ApiResult<T>,
    pub consume_handle: bool,
}

impl<T> ProviderAttempt<T> {
    pub(crate) fn sent(value: T) -> Self {
        Self {
            result: Ok(value),
            consume_handle: true,
        }
    }

    pub(crate) fn not_sent(error: ApiError) -> Self {
        Self {
            result: Err(error),
            consume_handle: false,
        }
    }

    pub(crate) fn maybe_sent(error: ApiError) -> Self {
        Self {
            result: Err(error),
            consume_handle: true,
        }
    }

    pub(crate) fn map<U>(self, f: impl FnOnce(T) -> ApiResult<U>) -> ProviderAttempt<U> {
        match self.result {
            Ok(value) => match f(value) {
                Ok(mapped) => ProviderAttempt {
                    result: Ok(mapped),
                    consume_handle: self.consume_handle,
                },
                Err(error) => ProviderAttempt {
                    result: Err(error),
                    consume_handle: self.consume_handle,
                },
            },
            Err(error) => ProviderAttempt {
                result: Err(error),
                consume_handle: self.consume_handle,
            },
        }
    }
}

/// How much outgoing text a provider accepts, before a socket is opened.
///
/// Not about leaking — the audit already answered that — but about not turning a
/// large document into an unreasonable request, or into a second copy of itself in
/// memory for no purpose. A provider may raise or lower it; this is the default.
const DEFAULT_REQUEST_BYTES: usize = 512 * 1024;

/// What a provider said, and what it reported the request cost.
///
/// Units as the provider states them, and `0` where it states nothing — a
/// figure we were not given is not a figure we invent. Nothing of the prompt is
/// in this type: a usage record that carried the question would be a second
/// copy of the document, kept for accounting.
pub(crate) struct Said {
    pub text: String,
    pub input_units: u32,
    pub output_units: u32,
}

impl Said {
    /// An answer whose cost the provider did not state.
    ///
    /// Only the echo provider has nothing to report, and it exists only in a
    /// build made for the tests — so this exists there too, and a release
    /// carries neither.
    #[cfg(feature = "fake_provider")]
    pub(crate) fn text(text: String) -> Self {
        Self { text, input_units: 0, output_units: 0 }
    }
}

/// One model, as the provider states it.
///
/// Static because V1's catalogue is a list this build carries: asking a
/// provider over the network what it offers is a network call during
/// configuration, and this phase does not add one.
pub(crate) struct ModelFacts {
    pub id: &'static str,
    pub display: &'static str,
    pub capabilities: &'static [crate::api::ModelCapability],
    /// Thousands of tokens of context, or 0 where the provider does not say.
    pub context_k: u32,
}

/// What every provider must be able to do, and nothing more.
pub(crate) trait Provider {
    /// The models this provider offers, in the order a person should see them.
    ///
    /// A provider with an empty list still works: its model is whatever the
    /// person configured, which is how a model on this machine is used.
    fn models(&self) -> &'static [ModelFacts] {
        &[]
    }

    fn id(&self) -> &'static str;
    fn label(&self) -> &'static str;
    fn default_base(&self) -> &'static str;
    fn default_model(&self) -> &'static str;

    /// The outgoing limit for this provider. One place to change per provider the
    /// day a model's context makes a different number the right one.
    fn max_request_bytes(&self) -> usize {
        DEFAULT_REQUEST_BYTES
    }

    /// How this provider wants the credential presented.
    ///
    /// A property of the company, not of the network layer. The default is the
    /// one most APIs use; Anthropic wants `x-api-key` and a version header, and
    /// saying so is this method and nothing else. An empty credential yields an
    /// empty value, and `http::post_json` leaves such a header off — which is
    /// how a model on this machine is reached with no key at all.
    fn authorisation(&self, credential: &str) -> Vec<(String, String)> {
        vec![("authorization".to_string(), if credential.is_empty() { String::new() } else { format!("Bearer {credential}") })]
    }

    /// Does this provider need a credential **at this address**?
    ///
    /// A property of the provider, not an assumption made everywhere (the
    /// owner, 27 September). The default says what is true today: a model on
    /// this machine needs no key, and everything reachable over a network does.
    /// A provider that authorises some other way overrides this and nothing
    /// above it changes.
    fn credential_required(&self, base: &str) -> bool {
        !http::is_loopback_url(base)
    }
    /// One question, one answer.
    ///
    /// `text` is what the person's document became — the safe payload on the
    /// protected path, and the document itself on the direct one. Which of the
    /// two it is was decided two layers up, by the type of the request's body,
    /// and a provider is not told: its job is to speak to one company's API.
    ///
    /// `instructions` is what the workspace and the conversation told the
    /// model. It is never the document.
    fn ask(
        &self,
        credential: &str,
        base: &str,
        model: &str,
        text: &str,
        instructions: &str,
    ) -> ProviderAttempt<Said>;
}

/// Every provider this build knows, in the order the UI should list them.
pub(crate) fn known() -> Vec<Box<dyn Provider>> {
    // `mut` is used only in a build that has the echo provider.
    #[allow(unused_mut)]
    let mut out: Vec<Box<dyn Provider>> = vec![
        Box::new(openai::OpenAiCompatible),
        // The second provider, added one file at a time as the owner asked —
        // official API, no aggregator.
        Box::new(anthropic::Anthropic),
        // 046/H, the owner: the chat screen carries a chosen list of models
        // that is to become a subscribable bundle. Four more companies, each a
        // file, each the company's own API and no aggregator — and all four
        // documenting the same chat-completions request, so what they share is
        // `openai::ask_chat_completions` and what differs stays in their own
        // files.
        //
        // **Only the first two have ever been called.** The owner's keys are
        // for OpenAI and Anthropic; these four are in the catalogue awaiting a
        // key, which is what `ModelDescriptor::available` reports and what the
        // screen draws. Nothing here implies a key exists.
        Box::new(xai::Xai),
        Box::new(deepseek::DeepSeek),
        Box::new(moonshot::Moonshot),
        Box::new(google::Google),
    ];
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
pub(crate) fn ask(
    handle: PayloadHandle,
    id: &str,
    credential: &str,
    base: &str,
    model: &str,
    instructions: &str,
) -> ApiResult<Said> {
    let provider = find(id)?;
    let text = crate::ops::reserve_payload_for_send(handle, |p| Zeroizing::new(p.wire_text().to_string()))?;
    let attempt = match check_size(text.len(), provider.as_ref()) {
        Ok(()) => provider.ask(credential, base, model, &text, instructions),
        Err(error) => ProviderAttempt::not_sent(error),
    };
    crate::ops::finish_payload_send(handle, attempt.consume_handle);
    attempt.result
}

/// Direct Mode: the text the person chose to send, as it stands.
///
/// A different function from [`ask`], taking a different argument, reached from
/// a different body type — and that is the whole of the separation. There is no
/// handle here because nothing was protected, and there is no path from a
/// failed [`ask`] to this function: a protected request that fails is reported
/// as a protected request that failed.
///
/// What it still does: TLS unless the address is this machine, the same size
/// limit, the same sanitised errors. Direct is «not redacted», and it is never
/// «not encrypted».
pub(crate) fn ask_direct(
    id: &str,
    credential: &str,
    base: &str,
    model: &str,
    text: &str,
    instructions: &str,
) -> ApiResult<Said> {
    let provider = find(id)?;
    check_size(text.len(), provider.as_ref())?;
    provider.ask(credential, base, model, text, instructions).result
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
    provider.ask(credential, base, model, "ping", "").result?;
    Ok(started.elapsed().as_millis().min(u128::from(u32::MAX)) as u32)
}

/// Is this address on the machine the program is running on?
///
/// The same test the network door uses to decide whether plain `http` is
/// allowed — so «Local AI» on a screen and «loopback only» in the rules are
/// one fact, and cannot drift into disagreeing.
pub(crate) fn is_on_this_computer(base: &str) -> bool {
    http::is_loopback_url(base)
}

/// Check an address the way a request would, before a credential is stored.
pub(crate) fn check_url_for(base: &str) -> ApiResult<()> {
    http::check_url(base)
}

/// The normalized destination a credential is bound to.
pub(crate) fn destination_of(base: &str) -> ApiResult<String> {
    http::destination_of(base)
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

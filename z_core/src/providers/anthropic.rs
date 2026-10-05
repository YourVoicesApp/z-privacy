//! The second provider: Anthropic's Messages API.
//!
//! It exists to answer one question — is a provider a file, or is it a change
//! to the core? The answer, measured: one file, one trait implementation, and
//! **one method added to the contract** (`authorisation`), because
//! `authorization: Bearer …` had been written into the network layer where it
//! did not belong. Anthropic wants `x-api-key` and a version header; saying so
//! is four lines here, and the socket did not move.
//!
//! What else differs, and is all in this file: the path is `/v1/messages`, the
//! system prompt is a field of its own rather than a message, `max_tokens` is
//! required, and the answer arrives as a list of content blocks. None of that
//! reaches the gateway, which knows a provider, a model, a credential and some
//! text.

use serde_json::{json, Value};

use crate::api::{ApiResult, ModelCapability as Capability, NetworkRefusal};

use super::{http, refuse, ModelFacts, Provider, ProviderAttempt, Said};

/// How many tokens to allow in an answer when nothing says otherwise.
///
/// Anthropic requires the field. It is a ceiling on the answer, not a limit on
/// the question, and it is here rather than in the gateway because it is this
/// company's requirement and no other's.
const ANSWER_TOKENS: u32 = 4096;

/// The version of the API this build speaks, as Anthropic requires it.
const API_VERSION: &str = "2023-06-01";

pub(crate) struct Anthropic;

impl Provider for Anthropic {
    fn id(&self) -> &'static str {
        "anthropic"
    }

    fn label(&self) -> &'static str {
        "Anthropic"
    }

    fn default_base(&self) -> &'static str {
        "https://api.anthropic.com"
    }

    fn default_model(&self) -> &'static str {
        "claude-haiku-4-5-20251001"
    }

    fn models(&self) -> &'static [ModelFacts] {
        &[
            ModelFacts {
                id: "claude-haiku-4-5-20251001",
                display: "Claude Haiku 4.5",
                capabilities: &[Capability::Text, Capability::Vision, Capability::Tools],
                context_k: 200,
            },
            ModelFacts {
                id: "claude-sonnet-5-5",
                display: "Claude Sonnet 5.5",
                capabilities: &[Capability::Text, Capability::Vision, Capability::Tools, Capability::Reasoning],
                context_k: 200,
            },
            ModelFacts {
                id: "claude-opus-5-5",
                display: "Claude Opus 5.5",
                capabilities: &[Capability::Text, Capability::Vision, Capability::Tools, Capability::Reasoning],
                context_k: 200,
            },
        ]
    }

    /// `x-api-key`, and the API version this build speaks.
    fn authorisation(&self, credential: &str) -> Vec<(String, String)> {
        vec![
            ("x-api-key".to_string(), credential.to_string()),
            ("anthropic-version".to_string(), API_VERSION.to_string()),
        ]
    }

    fn ask(
        &self,
        credential: &str,
        base: &str,
        model: &str,
        text: &str,
        instructions: &str,
    ) -> ProviderAttempt<Said> {
        if credential.is_empty() && !http::is_loopback_url(base) {
            return ProviderAttempt::not_sent(refuse(
                NetworkRefusal::NotConnected,
                "this provider has no credential in this run".to_string(),
            ));
        }
        let url = endpoint(base);

        // Three things and no fourth: the model, what the workspace said, and
        // the text. The system prompt is a field here rather than a message,
        // which is this company's shape and stays in this file.
        let body = if instructions.is_empty() {
            json!({
                "model": model,
                "max_tokens": ANSWER_TOKENS,
                "messages": [{ "role": "user", "content": text }],
            })
        } else {
            json!({
                "model": model,
                "max_tokens": ANSWER_TOKENS,
                "system": instructions,
                "messages": [{ "role": "user", "content": text }],
            })
        }
        .to_string();

        http::post_json(&url, &self.authorisation(credential), &body).map(|answer| {
            if answer.status != 200 {
                return Err(refuse(
                    NetworkRefusal::BadStatus { status: answer.status },
                    said_what(answer.status),
                ));
            }
            let (input, output) = units_of(&answer.body);
            content_of(&answer.body).map(|text| Said {
                text,
                input_units: input,
                output_units: output,
            })
        })
    }
}

/// Where the request goes. Forgiving about a trailing slash and about an
/// address already ending in the path, for the same reason the first provider
/// is: a person pasting an address should not have to debug it.
fn endpoint(base: &str) -> String {
    let trimmed = base.trim().trim_end_matches('/');
    if trimmed.ends_with("/v1/messages") {
        return trimmed.to_string();
    }
    if trimmed.ends_with("/v1") {
        return format!("{trimmed}/messages");
    }
    format!("{trimmed}/v1/messages")
}

/// What a status means, in our own words. The provider's own message is not
/// shown: it is their text about our request, and it has been known to quote
/// the request back.
fn said_what(status: u32) -> String {
    match status {
        401 | 403 => "the provider refused the credential".to_string(),
        404 => "that model or address was not found at this provider".to_string(),
        413 => "the provider says the request is too large".to_string(),
        429 => "the provider is rate-limiting this key".to_string(),
        400..=499 => format!("the provider refused the request ({status})"),
        500..=599 => format!("the provider had an error of its own ({status})"),
        other => format!("the provider answered {other}"),
    }
}

/// The first text block of the answer.
fn content_of(body: &str) -> ApiResult<String> {
    let value: Value = serde_json::from_str(body).map_err(|_| unreadable())?;
    let blocks = value.get("content").and_then(Value::as_array).ok_or_else(unreadable)?;
    let text = blocks
        .iter()
        .filter(|block| block.get("type").and_then(Value::as_str) == Some("text"))
        .filter_map(|block| block.get("text").and_then(Value::as_str))
        .collect::<Vec<&str>>()
        .join("");
    if text.is_empty() {
        return Err(unreadable());
    }
    Ok(text)
}

fn unreadable() -> crate::api::ApiError {
    refuse(
        NetworkRefusal::Unreadable,
        "the provider's answer was not in a shape this build reads".to_string(),
    )
}

/// `usage.input_tokens` and `usage.output_tokens` — this company's own names.
fn units_of(body: &str) -> (u32, u32) {
    let Ok(value) = serde_json::from_str::<Value>(body) else { return (0, 0) };
    let at = |name: &str| {
        value
            .get("usage")
            .and_then(|u| u.get(name))
            .and_then(Value::as_u64)
            .unwrap_or(0)
            .min(u64::from(u32::MAX)) as u32
    };
    (at("input_tokens"), at("output_tokens"))
}

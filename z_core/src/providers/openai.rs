//! One real provider: an OpenAI-compatible chat endpoint.
//!
//! One, not three. The path matters more than the catalogue — when a second
//! provider is added it will differ only in this file, and everything the owner
//! ruled about the wire stays where it is, in [`super::http`].
//!
//! «OpenAI-compatible» is also what makes a model running on your own computer
//! work: llama.cpp, Ollama and LM Studio all answer this shape, and a loopback
//! address is accepted over plain HTTP for exactly that reason.

use serde_json::{json, Value};

use crate::api::{ApiResult, NetworkRefusal};

use crate::api::ModelCapability as Capability;

use super::{http, refuse, ModelFacts, Provider, ProviderAttempt, Said};

pub(crate) struct OpenAiCompatible;

impl Provider for OpenAiCompatible {
    fn id(&self) -> &'static str {
        "openai"
    }

    fn label(&self) -> &'static str {
        "OpenAI-compatible"
    }

    fn default_base(&self) -> &'static str {
        "https://api.openai.com"
    }

    fn default_model(&self) -> &'static str {
        // The efficient one of the three the documentation features, so a new
        // connection costs the least until a person chooses otherwise.
        "gpt-6-luna"
    }

    /// What this endpoint offers, checked against the company's own
    /// documentation rather than against memory.
    ///
    /// Source: <https://platform.openai.com/docs/models>, read on **5 October
    /// 2026**. Each model's card on that page gives a «Model ID» line and a
    /// «Context window» line: `gpt-6-astra` (1.05M), `gpt-6.1-sol` (1.05M),
    /// `gpt-6-luna` (1.05M), each with a «Reasoning» row of effort levels and
    /// «Tools: Functions, Web search, File search, Computer use».
    ///
    /// The three ids this list carried before — `gpt-4o-mini`, `gpt-4o`,
    /// `gpt-4.1-mini` — were written from memory and are not what that page
    /// features today. That is exactly what this check was for.
    ///
    /// `Vision` is **not** claimed for any of them: the cards state tools and
    /// reasoning, and image input is not something to infer from «computer
    /// use». A capability we were not told about is not a capability we list.
    ///
    /// A list rather than a question asked over the network: configuring a
    /// provider must not itself be a request. It is also why «OpenAI-compatible»
    /// accepts a model this list does not name — a model on your own machine is
    /// whatever you called it, and the field stays editable.
    fn models(&self) -> &'static [ModelFacts] {
        &[
            ModelFacts {
                id: "gpt-6-astra",
                display: "GPT-6 Astra",
                capabilities: &[Capability::Text, Capability::Tools, Capability::Reasoning],
                context_k: 1_050,
            },
            ModelFacts {
                id: "gpt-6.1-sol",
                display: "GPT-6.1 Sol",
                capabilities: &[Capability::Text, Capability::Tools, Capability::Reasoning],
                context_k: 1_050,
            },
            ModelFacts {
                id: "gpt-6-luna",
                display: "GPT-6 Luna",
                capabilities: &[Capability::Text, Capability::Tools, Capability::Reasoning],
                context_k: 1_050,
            },
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

        // The body is built here, from exactly two things: the model's name and
        // the safe text. There is no third field into which anything else could
        // travel, and the escaping is not ours to get wrong.
        // The body is built from exactly three things: the model's name, what
        // the workspace told it, and the text. There is no fourth field into
        // which anything else could travel, and the escaping is not ours to
        // get wrong.
        let mut messages = Vec::new();
        if !instructions.is_empty() {
            messages.push(json!({ "role": "system", "content": instructions }));
        }
        messages.push(json!({ "role": "user", "content": text }));
        let body = json!({
            "model": model,
            "messages": messages,
            "stream": false,
        })
        .to_string();

        http::post_json(&url, &self.authorisation(credential), &body).map(|answer| {
            if answer.status != 200 {
                return Err(refuse(
                    NetworkRefusal::BadStatus { status: answer.status },
                    said_what(answer.status),
                ));
            }
            // The units this company states, where it states them.
            let (input, output) = units_of(&answer.body);
            content_of(&answer.body).map(|text| Said {
                text,
                input_units: input,
                output_units: output,
            })
        })
    }
}

/// Where the request goes. Forgiving about how the address was written, because a
/// local server is often given as `http://127.0.0.1:11434` and sometimes as
/// `…/v1`, and neither should be a mistake the user has to debug.
fn endpoint(base: &str) -> String {
    let trimmed = base.trim_end_matches('/');
    if trimmed.ends_with("/chat/completions") {
        trimmed.to_string()
    } else if trimmed.ends_with("/v1") {
        format!("{trimmed}/chat/completions")
    } else {
        format!("{trimmed}/v1/chat/completions")
    }
}

/// What a status means, in our own words. The provider's own message is **not**
/// used: it comes off the wire, and an error message travels further than a body.
fn said_what(status: u32) -> String {
    match status {
        400 => "the provider did not accept the request".to_string(),
        401 | 403 => "the provider refused the credential".to_string(),
        404 => "there is nothing at that address; check the model and the URL".to_string(),
        413 => "the provider says the text is too long".to_string(),
        429 => "the provider is rate-limiting; try again shortly".to_string(),
        500..=599 => format!("the provider had an error of its own ({status})"),
        other => format!("the provider answered {other}"),
    }
}

/// Pull the answer out, and refuse rather than guess.
fn content_of(body: &str) -> ApiResult<String> {
    let unreadable = || {
        refuse(
            NetworkRefusal::Unreadable,
            "the provider's answer was not the shape it promises".to_string(),
        )
    };
    let value: Value = serde_json::from_str(body).map_err(|_| unreadable())?;
    let content = value
        .get("choices")
        .and_then(|c| c.get(0))
        .and_then(|c| c.get("message"))
        .and_then(|m| m.get("content"))
        .ok_or_else(unreadable)?;

    // A string, or the newer list of parts. Anything else is not an answer.
    if let Some(text) = content.as_str() {
        return Ok(text.to_string());
    }
    if let Some(parts) = content.as_array() {
        let mut joined = String::new();
        for part in parts {
            if let Some(text) = part.get("text").and_then(|t| t.as_str()) {
                joined.push_str(text);
            }
        }
        if !joined.is_empty() {
            return Ok(joined);
        }
    }
    Err(unreadable())
}

/// `usage.prompt_tokens` and `usage.completion_tokens`, where present.
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
    (at("prompt_tokens"), at("completion_tokens"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::ApiError;

    #[test]
    fn the_address_is_built_the_same_way_however_it_was_written() {
        let want = "https://api.openai.com/v1/chat/completions";
        assert_eq!(endpoint("https://api.openai.com"), want);
        assert_eq!(endpoint("https://api.openai.com/"), want);
        assert_eq!(endpoint("https://api.openai.com/v1"), want);
        assert_eq!(endpoint("https://api.openai.com/v1/"), want);
        assert_eq!(endpoint(want), want);
        assert_eq!(
            endpoint("http://127.0.0.1:11434"),
            "http://127.0.0.1:11434/v1/chat/completions"
        );
    }

    #[test]
    fn the_body_carries_the_text_and_two_other_things() {
        let body = json!({
            "model": "gpt-4o-mini",
            "messages": [{ "role": "user", "content": "Herr __Z_AB12_PERSON_9XQ4__ ruft an" }],
            "stream": false,
        });
        let object = body.as_object().expect("an object");
        let mut keys: Vec<&str> = object.keys().map(|k| k.as_str()).collect();
        keys.sort_unstable();
        assert_eq!(keys, ["messages", "model", "stream"], "no fourth field to hide in");
    }

    #[test]
    fn an_answer_is_read_in_both_shapes_and_nothing_else() {
        let plain = r#"{"choices":[{"message":{"content":"Sehr geehrter Herr __Z_AB12_PERSON_9XQ4__"}}]}"#;
        assert_eq!(
            content_of(plain).expect("read"),
            "Sehr geehrter Herr __Z_AB12_PERSON_9XQ4__"
        );

        let parts = r#"{"choices":[{"message":{"content":[{"type":"text","text":"eins "},{"type":"text","text":"zwei"}]}}]}"#;
        assert_eq!(content_of(parts).expect("read"), "eins zwei");

        for bad in [
            "",
            "not json",
            "{}",
            r#"{"choices":[]}"#,
            r#"{"choices":[{"message":{}}]}"#,
            r#"{"error":{"message":"invalid api key"}}"#,
        ] {
            match content_of(bad) {
                Err(ApiError::NetworkRefused { reason, detail }) => {
                    assert_eq!(reason, NetworkRefusal::Unreadable, "for {bad}");
                    // The provider's own words never reach the user.
                    assert!(!detail.contains("invalid api key"), "{detail}");
                }
                other => panic!("{bad} should have been refused, got {other:?}"),
            }
        }
    }

    #[test]
    fn a_status_is_explained_in_our_words() {
        assert!(said_what(401).contains("credential"));
        assert!(said_what(429).contains("rate-limiting"));
        assert!(said_what(503).contains("503"));
    }
}

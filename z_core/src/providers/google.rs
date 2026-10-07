//! Google — Gemini, through the OpenAI-compatible endpoint Google documents.
//!
//! See [`super::xai`] for what a file like this is and is not. **Never called
//! live**: no credential for it exists in this build.
//!
//! The address is the one thing here that is not like the others. Google's own
//! native API is a different shape, and the page below gives a base URL for use
//! with the OpenAI libraries — so this provider speaks the shared shape at
//! *that* address, and nothing in the gateway had to learn a second protocol.

use crate::api::ModelCapability as Capability;

use super::{openai::ask_chat_completions, ModelFacts, Provider, ProviderAttempt, Said};

pub(crate) struct Google;

impl Provider for Google {
    fn id(&self) -> &'static str {
        "google"
    }

    fn label(&self) -> &'static str {
        "Google (Gemini)"
    }

    fn default_base(&self) -> &'static str {
        // <https://ai.google.dev/gemini-api/docs/openai>, read 7 October 2026:
        // «the base_url to use with the OpenAI libraries». The trailing slash
        // of the published value is dropped; `openai::endpoint` knows this
        // shape by its `/openai` tail and appends only `/chat/completions`.
        "https://generativelanguage.googleapis.com/v1beta/openai"
    }

    fn default_model(&self) -> &'static str {
        "gemini-3.8-flash"
    }

    /// Source: each model's **own page** under
    /// <https://ai.google.dev/gemini-api/docs/models>, read **7 October 2026**.
    /// The catalogue page lists dozens of ids and states no token limits at
    /// all; the per-model pages give an «Input token limit» line, and that line
    /// is where each figure below comes from:
    ///
    /// ```text
    ///     gemini-3.1-pro-preview   1,048,576
    ///     gemini-3.8-flash         1,048,576
    ///     gemini-2.5-pro           1,048,576
    /// ```
    ///
    /// **Why this list is three names long out of dozens**: the lead's rule for
    /// this task is that a model ships only with a figure quoted from a page
    /// that published it, one page per model and no crawling past it. These
    /// three are the chat models whose pages were read. The rest of that
    /// catalogue — the live, tts, transcribe, image, video, embedding and
    /// robotics rows, and the other flash and lite variants — are not here
    /// because nobody has read their pages yet, and not because they do not
    /// exist. That is a list this file can grow; it is not a number anyone may
    /// invent.
    ///
    /// A `context_k` of `0` was the other option and it is refused: the field
    /// means «thousands of tokens», a screen that drew it would draw «0K», and
    /// a number shaped like a fact is the one thing this product may never
    /// print. Nothing in the Flutter app draws the figure today — measured, not
    /// assumed — and the rule holds anyway, because it is about what the field
    /// means rather than about who reads it this week.
    fn models(&self) -> &'static [ModelFacts] {
        &[
            ModelFacts {
                id: "gemini-3.8-flash",
                display: "Gemini 3.8 Flash",
                capabilities: &[Capability::Text],
                context_k: 1_024,
            },
            ModelFacts {
                id: "gemini-3.1-pro-preview",
                display: "Gemini 3.1 Pro (preview)",
                capabilities: &[Capability::Text],
                context_k: 1_024,
            },
            ModelFacts {
                id: "gemini-2.5-pro",
                display: "Gemini 2.5 Pro",
                capabilities: &[Capability::Text],
                context_k: 1_024,
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
        ask_chat_completions(self, credential, base, model, text, instructions)
    }
}

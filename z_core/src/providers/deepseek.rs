//! DeepSeek, at the company's own address.
//!
//! See [`super::xai`] for what a file like this is and is not. **Never called
//! live**: no credential for it exists in this build, and the catalogue says
//! so rather than implying a key is there.

use crate::api::ModelCapability as Capability;

use super::{openai::ask_chat_completions, ModelFacts, Provider, ProviderAttempt, Said};

pub(crate) struct DeepSeek;

impl Provider for DeepSeek {
    fn id(&self) -> &'static str {
        "deepseek"
    }

    fn label(&self) -> &'static str {
        "DeepSeek"
    }

    fn default_base(&self) -> &'static str {
        // <https://api-docs.deepseek.com/>, read 7 October 2026: «the
        // OpenAI-compatible base URL» is given as this.
        "https://api.deepseek.com"
    }

    fn default_model(&self) -> &'static str {
        "deepseek-flash"
    }

    /// Source: <https://api-docs.deepseek.com/> and its pricing page, read
    /// **7 October 2026**. Two models, each with a stated context length of
    /// **1M tokens**: `deepseek-flash` (DeepSeek-V4.1-Flash) and
    /// `deepseek-v4-pro` (DeepSeek-V4-Pro-0813).
    ///
    /// The page says the retired names `deepseek-v4-flash` and
    /// `deepseek-v4-flash-vision-exp` are still accepted and served by Flash.
    /// They are not in this list: a catalogue is what to choose today, and a
    /// retired name that still answers is a kindness of theirs, not an offer.
    ///
    /// `Vision` **is** claimed for Flash and not for Pro, because that page
    /// states it of one and withholds it of the other in the same table. Both
    /// are said to support tool calls there, so `Tools` is on both.
    fn models(&self) -> &'static [ModelFacts] {
        &[
            ModelFacts {
                id: "deepseek-flash",
                display: "DeepSeek Flash",
                capabilities: &[Capability::Text, Capability::Vision, Capability::Tools],
                context_k: 1_000,
            },
            ModelFacts {
                id: "deepseek-v4-pro",
                display: "DeepSeek V4 Pro",
                capabilities: &[Capability::Text, Capability::Tools],
                context_k: 1_000,
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

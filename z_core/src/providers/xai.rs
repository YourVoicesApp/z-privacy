//! xAI — Grok, at the company's own address.
//!
//! A file, as Phase 4's contract asks: the shape of the request is shared with
//! every other company that documents chat-completions ([`super::openai`]), and
//! what is here is what is xAI's — its id, its address, its catalogue, and how
//! it wants a key presented.
//!
//! **Called live, and it answered.** The owner put an xAI key into Z Privacy
//! and asked Grok through it, and the exchange worked. So this file's own note
//! is corrected rather than left standing: it said «never called live — this
//! build has no xAI credential and none is being obtained», which was true
//! when it was written and became a sentence about a thing that had happened.
//!
//! No code changed with this note, and nothing here is a claim about a date:
//! the run is his and the day of it is not written down anywhere this file can
//! read. What the catalogue reports is unchanged and always was a question
//! about the credential it finds, never about this comment: `available` is
//! true where a key is, and the screen says «awaiting a key» where there is
//! none.

use crate::api::ModelCapability as Capability;

use super::{openai::ask_chat_completions, ModelFacts, Provider, ProviderAttempt, Said};

pub(crate) struct Xai;

impl Provider for Xai {
    fn id(&self) -> &'static str {
        "xai"
    }

    fn label(&self) -> &'static str {
        "xAI (Grok)"
    }

    fn default_base(&self) -> &'static str {
        // <https://docs.x.ai/docs/api-reference>, read 7 October 2026: the page
        // sets `base_url` to this for the OpenAI clients it shows.
        "https://api.x.ai/v1"
    }

    fn default_model(&self) -> &'static str {
        "grok-4.7"
    }

    /// Read from the company's own page, not from memory.
    ///
    /// Source: <https://docs.x.ai/docs/models>, read **7 October 2026**. Its
    /// text-API table gives: `grok-4.7` (500k context), `grok-4.6` (500k),
    /// `grok-4.5` (500k), `grok-4.3` (1M).
    ///
    /// What the same page lists and this does not: the dated snapshot rows
    /// (`grok-4.20-0309-reasoning`, `grok-4.20-0309-non-reasoning`,
    /// `grok-4.20-multi-agent-0309`, `grok-build-0.1`), and the image, video
    /// and voice models. The snapshots are pins of a release rather than names
    /// a person chooses, and the rest are not chat models — a catalogue of
    /// models that cannot answer a question is a longer list and a worse one.
    ///
    /// `Tools` and `Reasoning` are **not** claimed: that table states a context
    /// figure and nothing else about these four, and a capability we were not
    /// told about is not a capability we list. The same rule left `Vision` off
    /// every OpenAI row.
    fn models(&self) -> &'static [ModelFacts] {
        &[
            ModelFacts {
                id: "grok-4.7",
                display: "Grok 4.7",
                capabilities: &[Capability::Text],
                context_k: 500,
            },
            ModelFacts {
                id: "grok-4.6",
                display: "Grok 4.6",
                capabilities: &[Capability::Text],
                context_k: 500,
            },
            ModelFacts {
                id: "grok-4.5",
                display: "Grok 4.5",
                capabilities: &[Capability::Text],
                context_k: 500,
            },
            ModelFacts {
                id: "grok-4.3",
                display: "Grok 4.3",
                capabilities: &[Capability::Text],
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

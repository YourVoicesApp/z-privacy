//! Moonshot AI — Kimi, at the company's own address.
//!
//! See [`super::xai`] for what a file like this is and is not. **Never called
//! live**: no credential for it exists in this build.
//!
//! One thing worth recording, because it is the kind of fact that rots: the
//! documentation that used to live at `platform.moonshot.ai` answers a 301 to
//! `platform.kimi.ai` as of 7 October 2026. The API address below is the one
//! that page itself gives, which is not the same host as its documentation.

use crate::api::ModelCapability as Capability;

use super::{openai::ask_chat_completions, ModelFacts, Provider, ProviderAttempt, Said};

pub(crate) struct Moonshot;

impl Provider for Moonshot {
    fn id(&self) -> &'static str {
        "moonshot"
    }

    fn label(&self) -> &'static str {
        "Moonshot (Kimi)"
    }

    fn default_base(&self) -> &'static str {
        // <https://platform.kimi.ai/docs/api/chat>, read 7 October 2026: its
        // OpenAI-client examples set `base_url` to this.
        "https://api.moonshot.ai/v1"
    }

    fn default_model(&self) -> &'static str {
        "kimi-k3"
    }

    /// Source: <https://platform.kimi.ai/docs/pricing/chat>, read **7 October
    /// 2026**. Each row there gives a context window in tokens: `kimi-k3`
    /// (1,048,576), `kimi-k2.7-code` (262,144), `kimi-k2.7-code-highspeed`
    /// (262,144), `kimi-k2.6` (262,144).
    ///
    /// The figures are exact powers of two, so `context_k` is the exact
    /// thousand-token figure — 1,048,576 is 1024K and 262,144 is 256K — and not
    /// a rounded «1M». The OpenAI rows next door read 1,050 because that page
    /// writes «1.05M»; each list says what its own page says.
    fn models(&self) -> &'static [ModelFacts] {
        &[
            ModelFacts {
                id: "kimi-k3",
                display: "Kimi K3",
                capabilities: &[Capability::Text],
                context_k: 1_024,
            },
            ModelFacts {
                id: "kimi-k2.7-code",
                display: "Kimi K2.7 Code",
                capabilities: &[Capability::Text],
                context_k: 256,
            },
            ModelFacts {
                id: "kimi-k2.7-code-highspeed",
                display: "Kimi K2.7 Code (high speed)",
                capabilities: &[Capability::Text],
                context_k: 256,
            },
            ModelFacts {
                id: "kimi-k2.6",
                display: "Kimi K2.6",
                capabilities: &[Capability::Text],
                context_k: 256,
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

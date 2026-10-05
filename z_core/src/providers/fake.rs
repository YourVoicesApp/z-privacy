//! The provider that opens no socket.
//!
//! It exists so the whole path — build, audit, send, answer, restore — can be
//! proven without a network and without a credential anyone pays for. It echoes
//! the safe text back inside a sentence, which makes it a strict test: if a
//! single token failed to be replaced on the way out, the restored answer shows
//! the real value on the way back in, and the test fails.
//!
//! It is behind the `fake_provider` feature, so a release build has no echo
//! provider to pick at all: `providers()` does not list it and `find()` cannot
//! return it.

use super::{Provider, ProviderAttempt, Said};

pub(crate) struct Echo;

impl Provider for Echo {
    fn id(&self) -> &'static str {
        "fake"
    }

    fn label(&self) -> &'static str {
        "Echo (tests only)"
    }

    fn default_base(&self) -> &'static str {
        "http://127.0.0.1/echo"
    }

    fn default_model(&self) -> &'static str {
        "echo"
    }

    fn ask(
        &self,
        _credential: &str,
        _base: &str,
        _model: &str,
        text: &str,
        instructions: &str,
    ) -> ProviderAttempt<Said> {
        // The echo says what it was told as well as what it was asked, so a
        // test can see that the instructions travelled and that the document
        // did not travel inside them.
        let said = if instructions.is_empty() {
            String::new()
        } else {
            format!("[instructions: {instructions}]\n")
        };
        ProviderAttempt::sent(Said::text(format!(
            "{said}Verstanden. Ihr Text lautet:\n{text}\n— Ende der Antwort."
        )))
    }
}

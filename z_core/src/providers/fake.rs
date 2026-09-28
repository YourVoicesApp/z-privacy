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

use super::{Provider, ProviderAttempt};

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

    fn ask(&self, _credential: &str, _base: &str, _model: &str, text: &str) -> ProviderAttempt<String> {
        ProviderAttempt::sent(format!("Verstanden. Ihr Text lautet:\n{text}\n— Ende der Antwort."))
    }
}

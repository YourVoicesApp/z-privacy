//! **The web build's stand-in for `http.rs`** — paper 122 §2.2.
//!
//! No socket, no client, no request: every function answers a refusal or
//! «no», by name, so the provider code that is compiled on the web can never
//! reach a network. G1c keeps the client's name out of this file, and G1g
//! reads the built `.wasm` for any import that could.

use super::{refuse, ProviderAttempt};
use crate::api::{ApiResult, NetworkRefusal};

/// The shape `http.rs` answers in; never filled on the web.
pub(crate) struct Answer {
    pub status: u32,
    pub body: String,
}

const NOT_ON_THE_WEB: &str = "connecting to a model needs the app";

pub(crate) fn is_loopback_url(_url: &str) -> bool {
    false
}

pub(crate) fn destination_of(_base: &str) -> ApiResult<String> {
    Err(refuse(NetworkRefusal::InsecureUrl, NOT_ON_THE_WEB))
}

pub(crate) fn check_url(_url: &str) -> ApiResult<()> {
    Err(refuse(NetworkRefusal::InsecureUrl, NOT_ON_THE_WEB))
}

pub(crate) fn post_json(_url: &str, _headers: &[(String, String)], _body: &str) -> ProviderAttempt<Answer> {
    ProviderAttempt::not_sent(refuse(NetworkRefusal::InsecureUrl, NOT_ON_THE_WEB))
}

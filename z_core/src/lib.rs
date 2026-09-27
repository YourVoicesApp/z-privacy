//! # Z Privacy core
//!
//! Flutter sees and shows; this crate reads, protects, seals, sends and rebuilds.
//!
//! Two rules shape every line here, and both are checked by `scripts/gates.sh`:
//!
//! 1. **Only this crate builds the text that leaves the device.** The outgoing
//!    text is a [`payload::SafePayload`] built here, handed out as an opaque
//!    handle, and never accepted back as a string.
//! 2. **No panic crosses the boundary.** Every function on the API surface
//!    returns [`api::ApiResult`]; `unwrap`, `expect` and `panic!` are denied by
//!    the workspace lints.
//!
//! See `docs/SECURITY_INVARIANTS.md` for what this design does and does not
//! promise.

#![cfg_attr(test, allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing))]

pub mod api;
mod documents;
mod ops;
mod payload;
mod scanner;
mod secret;
mod session;
mod text;
mod tokens;
mod vault;

/// Version of the core, shown by the UI so a build can be identified on sight.
pub fn core_version() -> String {
    format!("z_core {}", env!("CARGO_PKG_VERSION"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_names_the_crate() {
        assert!(core_version().starts_with("z_core 0."));
    }
}

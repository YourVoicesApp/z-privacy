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
mod config;
mod payload;
mod providers;
mod scanner;
mod secret;
mod secure_file;
mod session;
mod text;
mod tokens;
mod vault;

/// The second door of that kind, and the same shape: the vault's idle clock.
///
/// Auto-lock is a promise about elapsed time, and the shortest limit a person
/// can set is one minute — so a test that waits for the real clock costs the
/// suite a minute per case, and a suite that slow has `#[ignore]` written on it
/// within the month. A test ages the vault instead.
///
/// It opens **one way**: unused for longer, never for less. There is no call
/// here that pushes a lock away, so this door cannot be used to make the
/// product less safe. Compiled only under `test_clock`, which is never a
/// default feature and never reaches the bridge — gate G23.
#[cfg(feature = "test_clock")]
pub mod test_clock {
    /// Pretend the open vault has been sitting unused for `seconds` longer.
    pub fn age_vault_unused(seconds: u32) {
        crate::session::with_core(|core| core.vault.age_unused(seconds));
    }
}

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

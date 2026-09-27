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

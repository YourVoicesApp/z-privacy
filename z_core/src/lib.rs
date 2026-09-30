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

/// One door, opened for the test suite on Windows and nowhere else.
///
/// `secure_file::windows` is private because nothing in the product ever needs
/// to read an access list back — it writes one and moves on. The test for the
/// first storage contract does need to: the whole point of that contract is to
/// check what was written rather than trust that it was. This is the narrowest
/// way to let it, and it only reads.
#[cfg(windows)]
pub mod testing {
    /// The file's access list, as SDDL.
    pub fn dacl_sddl(path: &std::path::Path) -> std::io::Result<String> {
        crate::secure_file::windows::dacl_sddl(path)
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

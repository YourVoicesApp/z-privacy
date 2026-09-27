//! Thin wrappers over `z_core`, exposed to Dart by flutter_rust_bridge.
//!
//! Rules for this file, checked by `scripts/gates.sh`:
//! * no logic — every body is a single call into `z_core`;
//! * no function takes text that is meant to leave the device;
//! * no function takes or returns a key.

/// Shown by the UI so a build can be identified on sight. Proof that the
/// Flutter window is reading from Rust and not from a Dart constant.
#[flutter_rust_bridge::frb(sync)]
pub fn core_version() -> String {
    z_core::core_version()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities: panic handler and logging on the Rust side, so a bug
    // shows up as a message rather than a silent death of the isolate.
    flutter_rust_bridge::setup_default_user_utils();
}

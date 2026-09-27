//! The bridge surface.
//!
//! Every function here is a thin wrapper over `z_core`. No logic lives in this
//! crate — it exists so that `z_core` stays free of bridge dependencies and can
//! be tested, fuzzed and compiled to WASM on its own.
pub mod core;

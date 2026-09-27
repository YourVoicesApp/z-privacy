//! The bridge surface.
//!
//! `z_core` owns the contract; this crate only carries it across to Dart:
//!
//! * [`core`] — the two functions that belong to the bridge itself.
//! * [`mirrors`] — generated shape declarations, so Dart gets real classes for
//!   `z_core::api` types instead of opaque handles. Never edited by hand; see
//!   `scripts/gen_mirrors.py` and gate G12.
//!
//! Everything else the UI calls is generated straight from `z_core::api`, so the
//! contract has exactly one source of truth.
pub mod core;
pub mod mirrors;

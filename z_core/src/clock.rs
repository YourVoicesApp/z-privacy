//! **The one clock** — paper 122 §2.2, the lead's decision 2.
//!
//! Every reader of time in the core asks here, and nowhere else: a duration
//! (`Instant`) and the wall (`unix_seconds`, `subsec_nanos`).
//!
//! - **Native:** `Instant` *is* `std::time::Instant`, and the wall is
//!   `std::time::SystemTime` — the same calls the core made before this file,
//!   so the native build's behaviour does not move.
//! - **Web** (`feature = "web"`, on `wasm32-unknown-unknown`): the standard
//!   library has no clock there and panics when asked, which is what made
//!   `import_text` trap in the measurement of §2.1. Durations come from the
//!   page's `performance.now()` and the wall from `Date.now()`, both through
//!   wasm-bindgen; these two are the only clock imports the web build has
//!   (gate G1g lists them by name). The time limits stay limits: a document's
//!   reading `Budget` is still a safety limit on the web.

#[cfg(not(feature = "web"))]
pub(crate) use std::time::Instant;

#[cfg(feature = "web")]
pub(crate) use web::Instant;

/// Seconds since 1970, from the wall clock.
pub(crate) fn unix_seconds() -> u64 {
    #[cfg(not(feature = "web"))]
    {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0)
    }
    #[cfg(feature = "web")]
    {
        web::wall_millis().max(0.0) as u64 / 1000
    }
}

/// The sub-second nanoseconds of the wall clock — only for `tokens`'
/// fallback when the system gives no randomness.
pub(crate) fn subsec_nanos() -> u32 {
    #[cfg(not(feature = "web"))]
    {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.subsec_nanos())
            .unwrap_or(0)
    }
    #[cfg(feature = "web")]
    {
        ((web::wall_millis().max(0.0) % 1000.0) * 1_000_000.0) as u32
    }
}

#[cfg(feature = "web")]
mod web {
    use std::time::Duration;

    use wasm_bindgen::prelude::wasm_bindgen;

    #[wasm_bindgen]
    extern "C" {
        /// `performance.now()`: milliseconds, monotonic, since the page began.
        #[wasm_bindgen(js_namespace = performance, js_name = now)]
        fn performance_now() -> f64;
    }

    /// `Date.now()`: milliseconds since 1970.
    pub(super) fn wall_millis() -> f64 {
        js_sys::Date::now()
    }

    /// A moment, as `performance.now()` gives it — the part of
    /// `std::time::Instant`'s surface the core uses, and nothing more.
    #[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
    pub(crate) struct Instant {
        millis: f64,
    }

    impl Instant {
        pub(crate) fn now() -> Self {
            Self {
                millis: performance_now(),
            }
        }

        pub(crate) fn elapsed(&self) -> Duration {
            Self::now().saturating_duration_since(*self)
        }

        pub(crate) fn saturating_duration_since(&self, earlier: Self) -> Duration {
            let millis = (self.millis - earlier.millis).max(0.0);
            Duration::from_secs_f64(millis / 1000.0)
        }

        pub(crate) fn checked_sub(&self, by: Duration) -> Option<Self> {
            Some(Self {
                millis: self.millis - by.as_secs_f64() * 1000.0,
            })
        }
    }

    impl std::ops::Add<Duration> for Instant {
        type Output = Self;

        fn add(self, by: Duration) -> Self {
            Self {
                millis: self.millis + by.as_secs_f64() * 1000.0,
            }
        }
    }
}

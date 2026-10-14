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
mod conversation;
mod data_dir;
mod gateway;
mod payload;
mod returning;
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

/// The third door of that kind, and the narrowest: **the word search an
/// instrument asks**, so that a measurement is the product's number and not a
/// script's.
///
/// Paper 086 measures what the reader hands over for Arabic, and the whole
/// worth of such a measurement is that it counts places the way the product
/// counts them: case-blind, across a hyphen the page put inside a word, and
/// with the attached clitics Arabic writes in front of a name — `دمنة` inside
/// `ولدمنة` is a place and inside `مدمنة` is not. A `contains` written beside
/// the product answers a different question and looks like an answer to this
/// one.
///
/// So an instrument borrows the function rather than keeping a second copy of
/// the rule, which is the defect this project has already paid for twice. It is
/// pure: a string the caller already owns goes in, byte ranges come out. No
/// session is read, no vault is opened, nothing is changed.
///
/// **And it is not in the product.** Compiled only under `measuring`, which is
/// never a default feature and which nothing but `examples/what_arrives.rs`
/// asks for — that example names it in `required-features`, so without the
/// feature the instrument is not built and this module does not exist. The
/// lead's ruling of 14 Oct, and the right one: a door that exists only to
/// measure should not stand in the surface the product ships.
#[cfg(feature = "measuring")]
pub mod measuring {
    /// Every **whole-word** place `needle` stands in `haystack`, as byte ranges
    /// into `haystack` itself.
    pub fn whole_word_places(haystack: &str, needle: &str) -> Vec<(usize, usize)> {
        crate::text::occurrences(haystack, needle)
    }
}

/// The build that is running, shown by the UI so it can be named on sight.
///
/// `z_core 0.1.0 · 2026-10-04 · fb9cfb8` — the version, the day it was built,
/// and the commit it was built from. The last two are written in by
/// `build.rs`; see the head of that file for why a version alone was not
/// enough to tell two builds of one afternoon apart.
pub fn core_version() -> String {
    format!(
        "z_core {} · {} · {}",
        env!("CARGO_PKG_VERSION"),
        env!("ZCORE_BUILD_DATE"),
        env!("ZCORE_COMMIT")
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_names_the_crate() {
        assert!(core_version().starts_with("z_core 0."));
    }

    /// The owner looked at the download page and thought the old build was
    /// still there, because `z_core 0.1.0` has been the whole of what the
    /// screen says since the first day and the installer is called `v1`
    /// whatever is inside it. Two builds of the same afternoon were
    /// indistinguishable by anything but a SHA-256 nobody reads aloud.
    ///
    /// So the version names the build that is running: the version, the day it
    /// was built, and the commit it was built from.
    #[test]
    fn the_version_names_the_build_that_is_running() {
        let stamp = core_version();
        let parts: Vec<&str> = stamp.split(" · ").collect();
        assert_eq!(parts.len(), 3, "the stamp is version, date and commit: «{stamp}»");
        assert!(parts[0].starts_with("z_core 0."), "«{stamp}»");

        let date = parts[1];
        assert_eq!(date.len(), 10, "a date is ten characters: «{date}»");
        assert!(
            date.char_indices().all(|(i, c)| if i == 4 || i == 7 { c == '-' } else { c.is_ascii_digit() }),
            "one shape of date and one only, YYYY-MM-DD: «{date}»"
        );

        let commit = parts[2];
        // Built outside a checkout — from a crates tarball, say — there is no
        // commit to name, and a stamp that invents one is worse than a stamp
        // that says it does not know. Here, in the repository, it must be real.
        let in_a_checkout = std::path::Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../.git")).exists();
        if in_a_checkout {
            assert_eq!(commit.len(), 7, "seven of them, as git prints: «{commit}»");
            assert!(
                commit.chars().all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase()),
                "a commit is lowercase hexadecimal: «{commit}»"
            );
        } else {
            assert_eq!(commit, "unknown", "no checkout, so nothing may be claimed: «{commit}»");
        }
    }

    /// **The door is the product's search, not a search that looks like it.**
    ///
    /// Three cases, and a `contains` written inside an instrument answers all
    /// three wrongly: it would find a word inside a longer one, miss the same
    /// name shouted, and refuse a name Arabic has written a particle in front
    /// of. A measurement built on any of those three would be reported as the
    /// product's number. So this is the guard that reddens if the door is ever
    /// reimplemented instead of forwarded.
    ///
    /// It stands under the same feature as the door, which is the price of the
    /// door not being in the product: the gate's own `cargo test` does not run
    /// it, and the seal runs the suite a second time with `--features
    /// measuring` so that it is watched rather than assumed.
    #[cfg(feature = "measuring")]
    #[test]
    fn the_word_search_an_instrument_asks_is_the_products_own() {
        let places = |haystack: &str, needle: &str| measuring::whole_word_places(haystack, needle).len();

        // A substring of a longer word is not a place: `contains` says 2.
        assert_eq!(places("Sandström och Sand i akten", "Sand"), 1);
        // The same name shouted — 041-R, the owner's own file.
        assert_eq!(places("TEXT: CRISTINA LEIFLAND", "Leifland"), 1);
        // And the rule no instrument of ours would carry: the clitics Arabic
        // writes in front of a name, which is the whole reason paper 086's
        // numbers have to come from here.
        assert_eq!(places("كليلة ودمنة", "دمنة"), 1);
        assert_eq!(places("مدمنة", "دمنة"), 0);
    }
}

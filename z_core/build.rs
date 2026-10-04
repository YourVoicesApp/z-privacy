//! The build's own name, injected once, at build time.
//!
//! The owner looked at the download page and thought yesterday's build was
//! still live, because `z_core 0.1.0` is all the screen has ever said and the
//! installer is called `v1` whatever is inside it. Two builds of one afternoon
//! were told apart only by a SHA-256, which is not something a person reads.
//!
//! So three things are written into the binary here: the day it was built, and
//! the commit it was built from. No new dependency — `git` is asked directly,
//! and the date is arithmetic.
//!
//! Both have an honest fallback. Outside a checkout the commit is `unknown`,
//! because a stamp that invents a commit is worse than one that admits it does
//! not know; and `SOURCE_DATE_EPOCH` is honoured first, so a reproducible build
//! gets the date it asks for rather than the date it happens to run on.

use std::path::Path;
use std::process::Command;

fn main() {
    println!("cargo:rustc-env=ZCORE_COMMIT={}", commit());
    println!("cargo:rustc-env=ZCORE_BUILD_DATE={}", build_date());

    // Rebuild when the checkout moves to another commit, so the stamp cannot
    // go stale while the code around it changes.
    println!("cargo:rerun-if-env-changed=SOURCE_DATE_EPOCH");
    for path in ["../.git/HEAD", "../.git/refs/heads", "../.git/index"] {
        if Path::new(path).exists() {
            println!("cargo:rerun-if-changed={path}");
        }
    }
}

/// `git rev-parse --short=7 HEAD`, or `unknown`.
///
/// Normalised to seven: git lengthens a short name when seven would be
/// ambiguous, and a stamp of a changing width is a stamp nobody can read at a
/// glance.
fn commit() -> String {
    let said = Command::new("git")
        .args(["rev-parse", "--short=7", "HEAD"])
        .output()
        .ok()
        .filter(|out| out.status.success())
        .and_then(|out| String::from_utf8(out.stdout).ok());
    let Some(said) = said else { return "unknown".to_string() };
    let trimmed = said.trim().to_lowercase();
    if trimmed.len() >= 7 && trimmed.chars().all(|c| c.is_ascii_hexdigit()) {
        trimmed.chars().take(7).collect()
    } else {
        "unknown".to_string()
    }
}

/// The day, UTC, as `YYYY-MM-DD`.
fn build_date() -> String {
    let seconds = std::env::var("SOURCE_DATE_EPOCH")
        .ok()
        .and_then(|v| v.trim().parse::<u64>().ok())
        .unwrap_or_else(|| {
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|since| since.as_secs())
                .unwrap_or(0)
        });
    civil_from_days((seconds / 86_400) as i64)
}

/// Days since 1970-01-01 → a civil date. Howard Hinnant's algorithm, which is
/// exact arithmetic and the reason this file needs no calendar crate.
fn civil_from_days(days: i64) -> String {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let day_of_era = z - era * 146_097;
    let year_of_era =
        (day_of_era - day_of_era / 1_460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let year = year_of_era + era * 400;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_prime = (5 * day_of_year + 2) / 153;
    let day = day_of_year - (153 * month_prime + 2) / 5 + 1;
    let month = if month_prime < 10 { month_prime + 3 } else { month_prime - 9 };
    let year = if month <= 2 { year + 1 } else { year };
    format!("{year:04}-{month:02}-{day:02}")
}

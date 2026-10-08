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
//!
//! ## Why the watch list is asked for and not guessed (task 052)
//!
//! This file used to name the paths it wanted cargo to watch:
//!
//! ```text
//! ../.git/HEAD        ../.git/refs/heads        ../.git/index
//! ```
//!
//! Those are right in a plain checkout and wrong in a git **worktree**, where
//! `.git` is a file and the real paths live under `.git/worktrees/<name>/`.
//! None of the three existed, so no `rerun-if-changed` was emitted — and
//! because emitting **any** `rerun-if-*` line switches off cargo's default of
//! re-running a build script whenever a file in the package changes, the single
//! surviving `rerun-if-env-changed` line was enough to freeze the stamp at
//! whatever HEAD happened to be the first time the crate compiled there.
//!
//! Every build we make is made in a worktree. The guard failed in the only
//! configuration we use, it failed in silence, and a protected payroll PDF left
//! the machine carrying a commit seven behind its own code.
//!
//! So git is asked where its files are. And if it cannot say, nothing is
//! stamped but `unknown`: a stamp that can go stale without anyone noticing is
//! the defect itself, not a lesser version of it.

use std::path::Path;
use std::process::Command;

fn main() {
    // The watch list is settled *before* anything is stamped, because what can
    // be stamped honestly depends on whether this script can be woken again.
    let can_be_woken = watch_the_commit();

    let commit = if can_be_woken { commit() } else { "unknown".to_string() };
    println!("cargo:rustc-env=ZCORE_COMMIT={commit}");
    println!("cargo:rustc-env=ZCORE_BUILD_DATE={}", build_date());
    println!("cargo:rerun-if-env-changed=SOURCE_DATE_EPOCH");
}

/// Ask cargo to re-run this script when HEAD moves. Returns whether `HEAD`
/// itself is being watched — the one path that cannot be skipped.
///
/// Three things move a commit, and they move different files:
///
/// * `HEAD` — a checkout, or any move of a detached head.
/// * `refs/heads` — a commit on the branch HEAD points at, which leaves the
///   `HEAD` file itself untouched. Watched as a directory, so a branch tip that
///   was packed and is now loose again still counts as a change.
/// * `index` — staging. It cannot change the commit, so it is not required; it
///   is watched because it is nearly free and it keeps `--short` from being
///   recomputed on a tree that has moved underneath it.
fn watch_the_commit() -> bool {
    let mut watching_head = false;
    for (name, decisive) in [("HEAD", true), ("refs/heads", false), ("index", false)] {
        if let Some(path) = git_path(name) {
            println!("cargo:rerun-if-changed={path}");
            watching_head |= decisive;
        }
    }
    watching_head
}

/// Where git keeps one of its own files, or `None`.
///
/// `git rev-parse --git-path` answers correctly in a plain checkout (`.git/HEAD`,
/// relative to the directory it is asked from — which for a build script is the
/// package root, so it can be emitted as it stands), in a worktree (an absolute
/// path under `.git/worktrees/`) and in a submodule.
///
/// A path git names but that does not exist is treated as no answer: cargo would
/// take a missing file as a reason to re-run for ever.
fn git_path(name: &str) -> Option<String> {
    let out = Command::new("git")
        .args(["rev-parse", "--git-path", name])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let said = String::from_utf8(out.stdout).ok()?.trim().to_string();
    if said.is_empty() || said.contains('\n') || !Path::new(&said).exists() {
        return None;
    }
    Some(said)
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

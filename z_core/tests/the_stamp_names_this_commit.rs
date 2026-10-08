//! The stamp in the corner of the screen, and in the foot of every protected
//! document, must name the commit this binary was actually built from.
//!
//! The owner exported a protected payroll PDF and its footer said `f362761`.
//! The bundle was byte-identical to the `82d5858` release — seven commits
//! later. Task 052.
//!
//! The cause is not that `build.rs` asks git the wrong question; it asks the
//! right one. It is that `build.rs` told cargo to watch three paths that do not
//! exist in a git **worktree**, where `.git` is a file and not a directory:
//!
//! ```text
//! ../.git/HEAD        ../.git/refs/heads        ../.git/index
//! ```
//!
//! Emitting **any** `cargo:rerun-if-*` line switches off cargo's default of
//! re-running a build script whenever a file in the package changes. So the one
//! surviving line — `rerun-if-env-changed=SOURCE_DATE_EPOCH` — was enough to
//! freeze the stamp at whatever HEAD happened to be the first time the crate
//! compiled in that worktree, and nothing ever thawed it.
//!
//! Every build any of us makes is made in a worktree. **The guard failed in the
//! only configuration we use, and it failed in silence.**
//!
//! This test is the thaw detector. It is deliberately not a unit test: it has to
//! see the stamp as a consumer sees it, through the public `core_version()`.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::process::Command;

/// `git rev-parse --short=7 HEAD`, or `None` when this is not a checkout —
/// a release tarball, a vendored build, a CI image without `.git`.
fn head() -> Option<String> {
    let out = Command::new("git")
        .args(["rev-parse", "--short=7", "HEAD"])
        .current_dir(env!("CARGO_MANIFEST_DIR"))
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let said = String::from_utf8(out.stdout).ok()?.trim().to_string();
    if said.is_empty() {
        None
    } else {
        Some(said)
    }
}

/// The commit out of `z_core 0.1.0 · 2026-10-08 · 1e5c2a1`.
fn stamped_commit() -> String {
    z_core::core_version()
        .rsplit(" · ")
        .next()
        .expect("core_version always has a last field")
        .to_string()
}

#[test]
fn the_stamp_names_the_commit_this_was_built_from() {
    let Some(head) = head() else {
        // Outside a checkout there is nothing to compare against, and `unknown`
        // is the honest answer the build script is supposed to give.
        return;
    };

    let stamped = stamped_commit();

    assert_ne!(
        stamped, "unknown",
        "this is a checkout at {head}, so the build script could have asked git and did not; \
         `unknown` is only honest when git cannot be reached"
    );

    assert_eq!(
        stamped, head,
        "the stamp names {stamped} but this tree is at {head}. The build script did not re-run \
         when HEAD moved — check that `cargo:rerun-if-changed` is emitted for the paths \
         `git rev-parse --git-path HEAD` and `--git-path index` actually report, which in a \
         worktree are **not** `../.git/...`. See docs/TASKS/052."
    );
}

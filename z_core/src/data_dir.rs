//! Where the two files Z Privacy writes are allowed to live.
//!
//! This was decided in Dart, in one line:
//!
//! ```dart
//! final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
//! ...  ZShell(dataDir: '$home/.local/share/zprivacy')
//! ```
//!
//! On Linux that is right. On Windows `HOME` is usually not set at all — the
//! variables are `LOCALAPPDATA` and `USERPROFILE` — so the fallback took over
//! and the vault would have been written into the temp directory: a place the
//! system empties, other processes write to, and backups skip. An encrypted
//! vault in the bin is still a vault you lost.
//!
//! So the choice moved here, for two reasons. The core owns these files, and
//! it is the half of the program a Windows machine can actually test.
//!
//! The one rule that is not negotiable: **never the temp directory**. If a
//! platform cannot say where its per-user data belongs, this refuses and says
//! so, because a refusal a person can read beats a vault in a folder that
//! disappears.

use std::path::PathBuf;

use crate::api::{ApiError, ApiResult};

fn refused(reason: &str) -> ApiError {
    ApiError::StorageRefused {
        reason: format!("data directory: {reason}"),
    }
}

/// The per-user folder for this machine's Z Privacy files.
///
/// Windows  `%LOCALAPPDATA%\ZPrivacy`, falling back to
///          `%USERPROFILE%\AppData\Local\ZPrivacy` — never roaming, because the
///          vault is this machine's and should not be copied between them by a
///          profile service.
/// macOS    `~/Library/Application Support/ZPrivacy`, which is where a user's
///          own application data belongs there.
/// Linux    `$XDG_DATA_HOME/zprivacy`, else `~/.local/share/zprivacy`, which is
///          what the app has always used and what existing installs hold.
pub(crate) fn default_data_dir() -> ApiResult<PathBuf> {
    #[cfg(windows)]
    {
        if let Some(local) = non_empty("LOCALAPPDATA") {
            return Ok(PathBuf::from(local).join("ZPrivacy"));
        }
        if let Some(profile) = non_empty("USERPROFILE") {
            return Ok(PathBuf::from(profile).join("AppData").join("Local").join("ZPrivacy"));
        }
        Err(refused(
            "neither LOCALAPPDATA nor USERPROFILE is set, so there is no per-user folder to use",
        ))
    }
    #[cfg(target_os = "macos")]
    {
        match non_empty("HOME") {
            Some(home) => Ok(PathBuf::from(home)
                .join("Library")
                .join("Application Support")
                .join("ZPrivacy")),
            None => Err(refused("HOME is not set, so there is no per-user folder to use")),
        }
    }
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        if let Some(xdg) = non_empty("XDG_DATA_HOME") {
            return Ok(PathBuf::from(xdg).join("zprivacy"));
        }
        match non_empty("HOME") {
            Some(home) => Ok(PathBuf::from(home).join(".local").join("share").join("zprivacy")),
            None => Err(refused("HOME is not set, so there is no per-user folder to use")),
        }
    }
    #[cfg(not(any(windows, unix)))]
    {
        Err(refused("this platform has no per-user folder Z Privacy knows about"))
    }
}

/// A variable that is set and not empty. An empty one is the same as missing,
/// and treating it as a path would put the vault at the filesystem root.
fn non_empty(name: &str) -> Option<String> {
    match std::env::var(name) {
        Ok(v) if !v.trim().is_empty() => Some(v),
        _ => None,
    }
}

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

fn refused(which: &str, reason: &str) -> ApiError {
    ApiError::StorageRefused {
        reason: format!("{which}: {reason}"),
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
            "data directory",
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
            None => Err(refused("data directory", "HOME is not set, so there is no per-user folder to use")),
        }
    }
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        if let Some(xdg) = non_empty("XDG_DATA_HOME") {
            return Ok(PathBuf::from(xdg).join("zprivacy"));
        }
        match non_empty("HOME") {
            Some(home) => Ok(PathBuf::from(home).join(".local").join("share").join("zprivacy")),
            None => Err(refused("data directory", "HOME is not set, so there is no per-user folder to use")),
        }
    }
    #[cfg(not(any(windows, unix)))]
    {
        Err(refused("data directory", "this platform has no per-user folder Z Privacy knows about"))
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

/// The folder a protected PDF is saved into when the person has not chosen
/// another one. The *second* place this product writes, and until tonight the
/// only one the screen still guessed at:
///
/// ```dart
/// final home = Platform.environment['HOME'];
/// if (home == null || home.isEmpty) return '';
/// return '$home/Documents/zprivacy';
/// ```
///
/// On Windows `HOME` is not set for a program with a window, so that returned
/// the empty string and every «Save as PDF» ended in a refusal: the third exit
/// did not exist on the second platform. It is the same mistake this file was
/// written to delete, made again a month later for the other folder — which is
/// why the answer belongs here beside its sister and not in the screen.
///
/// Windows  `%USERPROFILE%\Documents\ZPrivacy`, capitalised to match
///          `%LOCALAPPDATA%\ZPrivacy` — a folder a person opens, in the
///          spelling that platform writes.
/// macOS    `$HOME/Documents/zprivacy`.
/// Linux    `$HOME/Documents/zprivacy`, exactly what the screen has always
///          said, so the files anybody already has stay where they are.
///
/// **What this does not do yet.** Windows lets a person move Documents — to
/// OneDrive, most often — and only `SHGetKnownFolderPath(FOLDERID_Documents)`
/// knows about that; `%USERPROFILE%\Documents` would then be a second folder
/// they never look in. Reading it needs the one `unsafe` boundary this
/// workspace allows, which G4a proves is `secure_file/windows.rs` and nothing
/// else, so widening it is the lead's decision and not this commit's. Named,
/// not hidden: 074/W1b.
pub(crate) fn default_documents_dir() -> ApiResult<PathBuf> {
    #[cfg(windows)]
    {
        match non_empty("USERPROFILE") {
            Some(profile) => Ok(PathBuf::from(profile).join("Documents").join("ZPrivacy")),
            None => Err(refused(
                "documents directory",
                "USERPROFILE is not set, so there is no Documents folder to use",
            )),
        }
    }
    #[cfg(unix)]
    {
        match non_empty("HOME") {
            Some(home) => Ok(PathBuf::from(home).join("Documents").join("zprivacy")),
            None => Err(refused(
                "documents directory",
                "HOME is not set, so there is no Documents folder to use",
            )),
        }
    }
    #[cfg(not(any(windows, unix)))]
    {
        Err(refused(
            "documents directory",
            "this platform has no documents folder Z Privacy knows about",
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// **074/W1 — the two folders are two folders, and the saved files are not
    /// in the vault's.**
    ///
    /// The environment is read, never written: setting `HOME` here would pull
    /// the rug from under every other test running beside this one — the golden
    /// document finders read that same variable — which is why `vault_layer.rs`
    /// carries a `serial()` lock for the things that must touch shared state.
    /// So this measures the shape of the answer, on whatever machine it runs.
    #[test]
    fn the_saved_files_and_the_vault_do_not_share_a_folder() {
        let docs = default_documents_dir().expect("a documents folder on this machine");
        let data = default_data_dir().expect("a data folder on this machine");

        assert!(
            docs.to_string_lossy().to_lowercase().ends_with("zprivacy"),
            "the folder must be ours, not the whole of someone's documents: {docs:?}"
        );
        assert!(
            docs.components().any(|c| c.as_os_str().eq_ignore_ascii_case("Documents")),
            "a person must be able to find it where documents live: {docs:?}"
        );
        assert_ne!(
            docs, data,
            "the vault and the files a person saves may not share one folder"
        );
    }
}

//! Files that belong to Z Privacy itself.
//!
//! Documents still arrive from memory and never touch disk in this crate. This
//! module is only for the two local files the owner allowed: the sealed vault
//! and the small settings file. The hard rule is that an attacker may not turn a
//! save into "write these bytes through a symlink somewhere else".

use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use crate::api::{ApiError, ApiResult};

#[cfg(unix)]
// G15-ok: Unix-only flags used to protect ZVLT and ZCFG filesystem access.
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};

#[cfg(target_os = "linux")]
const O_NOFOLLOW: i32 = 0o400000;

// The only module in this workspace that may contain `unsafe`, and G4a proves
// it is the only one. What it buys: a file born with an access list that grants
// nothing to other accounts and inherits nothing from the folder above it.
#[cfg(windows)]
pub(crate) mod windows;

fn refused(label: &str, reason: impl Into<String>) -> ApiError {
    ApiError::StorageRefused {
        reason: format!("{label}: {}", reason.into()),
    }
}

#[cfg(unix)]
pub(crate) fn secure_dir(dir: &Path, label: &str) -> ApiResult<()> {
    match dir.symlink_metadata() {
        Ok(meta) if meta.file_type().is_symlink() => {
            return Err(refused(label, "the data directory is a symlink"));
        }
        Ok(meta) if !meta.is_dir() => {
            return Err(refused(label, "the data directory is not a directory"));
        }
        Ok(_) => {}
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            // G15-ok: creating the private folder that holds ZVLT and ZCFG.
            std::fs::create_dir_all(dir)
                .map_err(|e| refused(label, format!("the data directory could not be created: {e}")))?;
        }
        Err(e) => {
            return Err(refused(
                label,
                format!("the data directory could not be inspected: {e}"),
            ))
        }
    }

    // G15-ok: checking the private folder itself, not any document.
    let meta = std::fs::symlink_metadata(dir)
        .map_err(|e| refused(label, format!("the data directory could not be inspected: {e}")))?;
    if meta.file_type().is_symlink() {
        return Err(refused(label, "the data directory is a symlink"));
    }
    if !meta.is_dir() {
        return Err(refused(label, "the data directory is not a directory"));
    }

    // G15-ok: narrowing the private folder that holds ZVLT and ZCFG.
    std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700))
        .map_err(|e| refused(label, format!("the data directory permissions could not be set: {e}")))?;
    Ok(())
}

#[cfg(unix)]
pub(crate) fn read_no_follow(path: &Path, label: &str) -> ApiResult<Option<Vec<u8>>> {
    // G15-ok: opening ZVLT or ZCFG without following a symlink.
    let mut file = match std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(O_NOFOLLOW)
        .open(path)
    {
        Ok(file) => file,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => {
            return Err(refused(
                label,
                format!("the file could not be opened without following links: {e}"),
            ))
        }
    };
    let meta = file
        .metadata()
        .map_err(|e| refused(label, format!("the file could not be inspected: {e}")))?;
    if !meta.file_type().is_file() {
        return Err(refused(label, "the path is not a regular file"));
    }
    let mut bytes = Vec::with_capacity(meta.len().min(1024 * 1024) as usize);
    file.read_to_end(&mut bytes)
        .map_err(|e| refused(label, format!("the file could not be read: {e}")))?;
    Ok(Some(bytes))
}

#[cfg(unix)]
pub(crate) fn replace_atomically(path: &Path, temp_extension: &str, bytes: &[u8], label: &str) -> ApiResult<()> {
    let parent = path
        .parent()
        .ok_or_else(|| refused(label, "the file has no parent directory"))?;
    secure_dir(parent, label)?;
    let temp = temp_path(path, temp_extension);

    // G15-ok: creating a private temp file for ZVLT or ZCFG, exclusively.
    let mut file = match std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .custom_flags(O_NOFOLLOW)
        .open(&temp)
    {
        Ok(file) => file,
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
            return Err(refused(label, "the temporary file already exists"));
        }
        Err(e) => {
            return Err(refused(
                label,
                format!("the temporary file could not be created safely: {e}"),
            ))
        }
    };

    // G15-ok: narrowing the already-open temp file before any final rename.
    file.set_permissions(std::fs::Permissions::from_mode(0o600))
        .map_err(|e| refused(label, format!("the temporary file permissions could not be set: {e}")))?;
    file.write_all(bytes)
        .map_err(|e| refused(label, format!("the complete file could not be written: {e}")))?;
    file.sync_all()
        .map_err(|e| refused(label, format!("the temporary file could not be synced: {e}")))?;
    drop(file);

    // G15-ok: replacing ZVLT or ZCFG with the complete temp file in the same folder.
    std::fs::rename(&temp, path)
        .map_err(|e| refused(label, format!("the complete file could not be put in place: {e}")))?;
    // G15-ok: opening the private parent directory so the rename can be synced.
    let parent_dir = std::fs::File::open(parent)
        .map_err(|e| refused(label, format!("the data directory could not be opened for sync: {e}")))?;
    parent_dir
        .sync_all()
        .map_err(|e| refused(label, format!("the data directory could not be synced: {e}")))?;
    Ok(())
}

fn temp_path(path: &Path, temp_extension: &str) -> PathBuf {
    path.with_extension(temp_extension)
}

#[cfg(not(unix))]
pub(crate) fn secure_dir(dir: &Path, label: &str) -> ApiResult<()> {
    // G15-ok: non-Unix fallback for the private folder that holds ZVLT and ZCFG.
    std::fs::create_dir_all(dir)
        .map_err(|e| refused(label, format!("the data directory could not be created: {e}")))?;
    Ok(())
}

#[cfg(not(unix))]
pub(crate) fn read_no_follow(path: &Path, label: &str) -> ApiResult<Option<Vec<u8>>> {
    // G15-ok: non-Unix fallback read for ZVLT or ZCFG.
    match std::fs::read(path) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(refused(label, format!("the file could not be read: {e}"))),
    }
}

/// A brand-new file that no other account may reach.
///
/// On Windows that means an explicit access list and no inheritance, which
/// takes the one `unsafe` boundary this workspace allows. Elsewhere off Unix
/// there is nothing to say yet, and pretending otherwise would be the lie this
/// whole exercise exists to avoid — `create_new` at least refuses to write into
/// something already sitting in the path.
#[cfg(not(unix))]
// G15-ok: the one place off Unix that creates ZVLT or ZCFG's temp file.
fn create_private_new(temp: &Path, label: &str) -> ApiResult<std::fs::File> {
    #[cfg(windows)]
    {
        windows::create_new_owner_only(temp).map_err(|e| {
            if e.kind() == std::io::ErrorKind::AlreadyExists {
                refused(label, "the temporary file already exists")
            } else {
                refused(label, format!("the temporary file could not be created safely: {e}"))
            }
        })
    }
    #[cfg(not(windows))]
    {
        // G15-ok: non-Unix, non-Windows fallback temp file for ZVLT or ZCFG.
        std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(temp)
            .map_err(|e| refused(label, format!("the temporary file could not be created: {e}")))
    }
}

#[cfg(not(unix))]
pub(crate) fn replace_atomically(path: &Path, temp_extension: &str, bytes: &[u8], label: &str) -> ApiResult<()> {
    let parent = path
        .parent()
        .ok_or_else(|| refused(label, "the file has no parent directory"))?;
    secure_dir(parent, label)?;
    let temp = temp_path(path, temp_extension);
    let mut file = create_private_new(&temp, label)?;
    file.write_all(bytes)
        .map_err(|e| refused(label, format!("the complete file could not be written: {e}")))?;
    file.sync_all()
        .map_err(|e| refused(label, format!("the temporary file could not be synced: {e}")))?;
    drop(file);
    // G15-ok: non-Unix fallback rename for ZVLT or ZCFG.
    std::fs::rename(&temp, path)
        .map_err(|e| refused(label, format!("the complete file could not be put in place: {e}")))?;
    Ok(())
}

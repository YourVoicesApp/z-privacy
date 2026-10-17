//! Files that belong to Z Privacy itself.
//!
//! Documents still arrive from memory and never touch disk in this crate. This
//! module is only for the two local files the owner allowed: the sealed vault
//! and the small settings file. The hard rule is that an attacker may not turn a
//! save into "write these bytes through a symlink somewhere else".

// `Write` is used by both halves; `Read` only by the Unix one, which reads
// through a handle opened with O_NOFOLLOW. Unsplit, it was an unused import on
// Windows — a warning no Linux run could show, because there the import is
// used and `-D warnings` has nothing to say. Found by compiling for the target.
#[cfg(unix)]
use std::io::Read;
// The type of the one handle this module holds open besides the vault's own:
// the lock two copies of the program take turns at. A type and not an act —
// every act on it carries its own line below.
// G15-ok: the lock's type, named here so the acts below read as acts.
use std::fs::File;
use std::io::Write;
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

/// **The folder said no, and that is not the same as «this place cannot be used
/// safely».** 058's refusal, in the words the Unix half already uses.
///
/// Unix reads the folder's mode *before* writing and can say what it is set to.
/// Windows has no mode to read: it learns the same fact from the attempt, when
/// `CreateFileW` comes back with ERROR_ACCESS_DENIED. One contract, one name,
/// each platform proving it in its own terms — so the variant and the sentence
/// are the same here, and only the way they were found differs.
#[cfg(not(unix))]
fn kept(label: &str) -> ApiError {
    ApiError::StoragePermissionsKept {
        reason: format!("{label}: the folder that holds it refused a write"),
    }
}

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

    // **Narrow in silence, never widen in silence** (058).
    //
    // This line used to set `0o700` unconditionally, on every write path. From
    // `0o755` that is a mend — the mode a folder gets from the default umask,
    // nobody's decision, and nothing to tell anyone about. From `0o500` it was
    // the opposite: Z handed itself back the write permission the owner of the
    // machine had taken off, and said nothing, under a comment that called the
    // line «narrowing». For a product whose claim is that nothing happens to
    // your data without your word, «the app re-granted itself a permission I
    // had removed» is a sentence that loses a room.
    //
    // It also made a read-only folder useless as a test lever: Z mended the
    // folder and wrote anyway, so `chmod 500` bought a **false green**. The
    // lever that works is a leftover `vault.zv.new`, which is what a write
    // killed half-way leaves behind — see
    // `a_create_that_cannot_reach_the_disk_keeps_nothing` in `vault/mod.rs`.
    let mode = meta.permissions().mode() & 0o777;
    if mode & 0o700 != 0o700 {
        // Z **could** write here. It is declining to, because the person said
        // otherwise — which is a different sentence from «that place cannot be
        // used safely», and so a different variant.
        return Err(ApiError::StoragePermissionsKept {
            reason: format!("{label}: the folder that holds it is set to {mode:03o}"),
        });
    }
    if mode != 0o700 {
        // G15-ok: narrowing the private folder that holds ZVLT and ZCFG.
        std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700)).map_err(|e| {
            refused(label, format!("the data directory permissions could not be set: {e}"))
        })?;
    }
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

/// **One copy of this program writes at a time** — the independent attacker's
/// م5 and خ9, 17 October 2026.
///
/// He ran two copies against one vault, forty trials, each creating an
/// identity: in three of them **both said ok and the disk held one**. The
/// window is between `Vault::ensure_disk_unchanged` and the `rename` inside
/// `replace_atomically`, and the session file had no comparison at all — its
/// write was a read, a change and a replace with nothing between them, so the
/// later `rename` simply won.
///
/// **Why a lock and not «run one copy only».** The product already promises
/// that two copies may run: `VaultChangedElsewhere` exists, and the sentence
/// `messages.dart` words for it — «Another copy of Z Privacy changed this
/// vault. Close that window, or lock and unlock here to take in its work» —
/// *invites* the person to resolve it. Refusing to start a second copy would
/// delete a promise the owner's own wording makes, and it would not fix the
/// session file, where the right answer is not a refusal at all: the second
/// copy should read the newest turns and add to them, which is what happens
/// once the read and the write cannot be split.
///
/// **Why the operating system's lock and not a file with a pid in it.**
/// `std::fs::File::lock` is `flock` on Unix and `LockFileEx` on Windows —
/// Windows is the next platform, and this is the one shape that needs no
/// `unsafe`, no dependency and no second implementation. And the property a
/// lock *file* cannot promise: **the OS releases it when the process dies**,
/// so a copy that crashes mid-write leaves nothing behind for the next one to
/// puzzle out, and there is no stale lock to break — which would be the one
/// place this program could be argued into deleting something it did not write.
///
/// It is **taken for the whole of a core call** (`session::with_core`), not
/// around each write, because the loss was never in one write: it was in a
/// read and a write with a gap between them. Inside a process the core's own
/// mutex already serialises those calls, so this is never taken twice at once
/// by one copy.
///
/// `None` means there is nothing to lock yet — no data directory, so nothing
/// on disk to lose — or that the lock could not be taken at all. A folder that
/// refuses it leaves the old behaviour exactly as it was, and the vault's own
/// `ensure_disk_unchanged` still stands between two copies: this narrows a
/// window to nothing, and is not the only thing watching it.
pub(crate) struct OneWriter {
    /// Dropped last: closing the handle is what releases the lock.
    _file: File,
}

pub(crate) fn one_writer_at_a_time(dir: Option<&Path>) -> Option<OneWriter> {
    let dir = dir?;
    if secure_dir(dir, "writing.lock").is_err() {
        return None;
    }
    let path = dir.join("writing.lock");
    let file = open_the_lock(&path)?;
    // Blocking on purpose: the other copy is milliseconds from finishing, and
    // a refusal here would be a sentence about a state that is about to end.
    // What it must never do is proceed as if it held the lock.
    file.lock().ok()?;
    Some(OneWriter { _file: file })
}

#[cfg(unix)]
fn open_the_lock(path: &Path) -> Option<File> {
    // G15-ok: the lock one copy holds while it writes ZVLT or a session file.
    std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .open(path)
        .ok()
}

#[cfg(not(unix))]
fn open_the_lock(path: &Path) -> Option<File> {
    // The same lock off Unix, where the folder's own permissions are what
    // protects it.
    // G15-ok: opening the one-writer lock beside ZVLT.
    std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(path)
        .ok()
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
    #[cfg(windows)]
    {
        // The same sentence Unix gives, because it is the same refusal: what is
        // standing at this path was not followed, so nothing was read.
        windows::read_no_reparse(path)
            .map_err(|e| refused(label, format!("the file could not be opened without following links: {e}")))
    }
    #[cfg(not(windows))]
    {
        // G15-ok: non-Unix, non-Windows fallback read for ZVLT or ZCFG.
        match std::fs::read(path) {
            Ok(bytes) => Ok(Some(bytes)),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(e) => Err(refused(label, format!("the file could not be read: {e}"))),
        }
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
        windows::create_new_owner_only(temp).map_err(|e| match e.kind() {
            std::io::ErrorKind::AlreadyExists => refused(label, "the temporary file already exists"),
            std::io::ErrorKind::PermissionDenied => kept(label),
            _ => refused(label, format!("the temporary file could not be created safely: {e}")),
        })
    }
    #[cfg(not(windows))]
    {
        // G15-ok: non-Unix, non-Windows fallback temp file for ZVLT or ZCFG.
        std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(temp)
            .map_err(|e| match e.kind() {
                std::io::ErrorKind::PermissionDenied => kept(label),
                _ => refused(label, format!("the temporary file could not be created: {e}")),
            })
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

#[cfg(all(test, unix))]
mod tests {
    use super::*;

    fn test_dir(name: &str) -> PathBuf {
        // G15-ok: a test's own folder, for the two files this module is allowed.
        let dir = std::env::temp_dir().join(format!("zprivacy-perm-{name}-{}", std::process::id()));
        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
        // G15-ok: making a test's own folder.
        std::fs::create_dir_all(&dir).expect("make the folder");
        dir
    }

    fn mode_of(dir: &Path) -> u32 {
        // G15-ok: reading the mode of a test's own folder.
        std::fs::metadata(dir).expect("stat").permissions().mode() & 0o777
    }

    fn set_mode(dir: &Path, mode: u32) {
        // G15-ok: setting the mode of a test's own folder.
        std::fs::set_permissions(dir, std::fs::Permissions::from_mode(mode)).expect("chmod");
    }

    /// **058, the guard that would have caught it: a refused write leaves the
    /// folder exactly as the person set it.**
    ///
    /// `secure_dir` ran `set_permissions(dir, 0o700)` unconditionally on every
    /// write path, so from `0o500` Z gave itself back the write bit the owner
    /// of the machine had removed — and said nothing. Found while building a
    /// lever for 050/C: a read-only folder does not make a write fail, because
    /// Z mends the folder and writes anyway.
    #[test]
    fn a_folder_the_person_locked_is_left_exactly_as_it_was() {
        let dir = test_dir("locked");
        set_mode(&dir, 0o500);

        let refused = replace_atomically(&dir.join("vault.zv"), "zv.new", b"a vault", "vault.zv");

        assert_eq!(
            mode_of(&dir),
            0o500,
            "Z changed a permission the person set, which is the whole of 058"
        );
        match refused {
            Err(ApiError::StoragePermissionsKept { reason }) => {
                assert!(
                    reason.contains("vault.zv") && reason.contains("500"),
                    "the refusal must name which folder and what it is set to: «{reason}»"
                );
            }
            other => panic!("a folder the person locked gave {other:?}"),
        }
        assert!(
            !dir.join("vault.zv").exists(),
            "nothing was written, and the refusal must not have lied about it"
        );

        set_mode(&dir, 0o700);
        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// **And the other half, which must stay silent.** A folder made by the
    /// default umask is `0o755`, which is the common case and a mend, not a
    /// decision of the person's. Narrow in silence.
    #[test]
    fn a_folder_wider_than_it_should_be_is_narrowed_without_a_word() {
        let dir = test_dir("wide");
        set_mode(&dir, 0o755);

        replace_atomically(&dir.join("vault.zv"), "zv.new", b"a vault", "vault.zv")
            .expect("a folder nobody locked is written to");

        assert_eq!(mode_of(&dir), 0o700, "a world-readable folder was left as it was");
        assert!(dir.join("vault.zv").exists());

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// A folder already exactly right is not touched at all — there is nothing
    /// to mend, and a syscall on every write that changes nothing is a syscall
    /// that can fail for nothing.
    #[test]
    fn a_folder_already_right_is_left_alone() {
        let dir = test_dir("exact");
        set_mode(&dir, 0o700);
        replace_atomically(&dir.join("vault.zv"), "zv.new", b"a vault", "vault.zv").expect("write");
        assert_eq!(mode_of(&dir), 0o700);
        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }
}

#[cfg(all(test, windows))]
mod windows_tests {
    use super::*;
    use std::process::Command;

    fn test_dir(name: &str) -> PathBuf {
        // G15-ok: a test's own folder, for the two files this module is allowed.
        let dir = std::env::temp_dir().join(format!("zprivacy-perm-{name}-{}", std::process::id()));
        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
        // G15-ok: making a test's own folder.
        std::fs::create_dir_all(&dir).expect("make the folder");
        dir
    }

    /// What Windows itself says the folder grants, as text. Compared with
    /// itself before and after the act: the question is only whether Z changed
    /// it, so the exact spelling does not matter as long as it is the same
    /// spelling both times.
    fn acl_of(dir: &Path) -> String {
        let out = Command::new("icacls")
            .arg(dir)
            .output()
            .expect("icacls is on every Windows machine");
        String::from_utf8_lossy(&out.stdout).to_string()
    }

    fn icacls(args: &[&str]) -> std::process::Output {
        Command::new("icacls").args(args).output().expect("icacls ran")
    }

    /// **058 on Windows — the same contract as the Unix test of the same name.**
    ///
    /// A folder the person has taken the write permission off is left exactly as
    /// they set it, and the write is refused in words rather than mended and
    /// carried out. Unix measures it with `chmod 500`; here the lever is
    /// `icacls /deny`, and the refusal must be the same variant, because the
    /// promise is the product's and not the platform's.
    #[test]
    fn a_folder_the_person_locked_is_left_exactly_as_it_was() {
        let dir = test_dir("locked");
        let who = std::env::var("USERNAME").expect("USERNAME names the account these tests run as");

        // Every precondition is its own assertion with its own reason: a red
        // that means «the lever did not work» must not read like «the contract
        // is broken».
        let denied = icacls(&[&dir.to_string_lossy(), "/deny", &format!("{who}:(WD,AD)")]);
        assert!(
            denied.status.success(),
            "the lever itself failed, so nothing below was measured: {}",
            String::from_utf8_lossy(&denied.stderr)
        );
        let locked = acl_of(&dir);

        let refused = replace_atomically(&dir.join("vault.zv"), "zv.new", b"a vault", "vault.zv");
        let after = acl_of(&dir);
        let written = dir.join("vault.zv").exists();

        // Put the folder back before anything can panic, or the temp folder
        // cannot be cleaned and the next run inherits it.
        let _ = icacls(&[&dir.to_string_lossy(), "/remove:d", &who]);
        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);

        assert_eq!(
            after, locked,
            "Z changed an access list the person set, which is the whole of 058"
        );
        match refused {
            Err(ApiError::StoragePermissionsKept { reason }) => {
                assert!(
                    reason.contains("vault.zv"),
                    "the refusal must name which file it is about: «{reason}»"
                );
            }
            other => panic!("a folder the person locked gave {other:?}"),
        }
        assert!(
            !written,
            "nothing was written, and the refusal must not have lied about it"
        );
    }
}

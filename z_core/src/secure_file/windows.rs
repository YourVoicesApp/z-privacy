//! The one place in Z Privacy where `unsafe` is allowed to live.
//!
//! Everything else in this workspace is `unsafe_code = "deny"`, and G4a proves
//! that this file is the only one carrying an exception. That is the trade the
//! owner made, deliberately: a small boundary we wrote and can read, guarded by
//! a gate, rather than the same calls hidden inside a dependency nobody here
//! audits.
//!
//! # What it is for
//!
//! On Unix, a file the vault lives in is protected by `0600` and `O_NOFOLLOW`.
//! Windows has neither. A file created with the ordinary API inherits whatever
//! the folder above it grants, which on a shared or misconfigured machine can
//! be a great deal more than its owner.
//!
//! So the contract here is stated in Windows' own terms, and no wider than it
//! can be kept:
//!
//! > the file's access list grants nothing to other user accounts, and does
//! > not inherit wider permissions from the folder it sits in.
//!
//! It deliberately does **not** claim "nobody but the owner can read it".
//! Administrators and SYSTEM hold privileges (SeBackupPrivilege,
//! SeTakeOwnershipPrivilege) that no access list can refuse, and a promise that
//! ignores that would be false on the platform it is made about.
//!
//! # How
//!
//! One security descriptor, written as SDDL and parsed by Windows itself:
//!
//! ```text
//! D:P(A;;FA;;;OW)
//!  │ │ │  │    └── OW — Owner Rights. The account that creates the file is its
//!  │ │ │  │          owner, so this is the user and nobody else.
//!  │ │ │  └─────── FA — full access, for that one entry.
//!  │ │ └────────── A  — an allow entry. There are no others; anything not
//!  │ │                  named here is denied by absence.
//!  │ └──────────── P  — protected: inheritance from the parent folder is cut,
//!  │                    which is the second half of the contract.
//!  └────────────── D  — this is the DACL.
//! ```
//!
//! Letting Windows parse it is the point: the alternative is building a SID, an
//! ACL and a descriptor by hand across four more `unsafe` calls, each one a
//! place to get a length or a pointer wrong.
#![allow(unsafe_code)]

use std::ffi::c_void;
use std::os::windows::ffi::OsStrExt;
use std::path::Path;

use windows_sys::Win32::Foundation::{LocalFree, HANDLE, INVALID_HANDLE_VALUE};
use windows_sys::Win32::Security::Authorization::{
    ConvertSecurityDescriptorToStringSecurityDescriptorW, ConvertStringSecurityDescriptorToSecurityDescriptorW,
    GetNamedSecurityInfoW, SDDL_REVISION_1, SE_FILE_OBJECT,
};
use windows_sys::Win32::Security::{DACL_SECURITY_INFORMATION, PSECURITY_DESCRIPTOR, SECURITY_ATTRIBUTES};
use windows_sys::Win32::Storage::FileSystem::CreateFileW;

// Flags, written out rather than imported. Their values are fixed by the
// Windows API and have not changed in thirty years; their *paths* inside
// `windows-sys` have moved between releases, and a build that breaks because a
// constant was re-homed teaches nothing about this file.
const GENERIC_WRITE: u32 = 0x4000_0000;
const FILE_SHARE_READ: u32 = 0x0000_0001;
const CREATE_NEW: u32 = 1;
const FILE_ATTRIBUTE_NORMAL: u32 = 0x0000_0080;
// The whole of the second contract, in one flag. Without it CreateFileW walks
// a reparse point — a symlink, a junction, a mount point — and creates or
// opens whatever is on the far side. With it, the call is about the entry at
// this path and nothing else, so CREATE_NEW meets the reparse point itself and
// refuses. It is Windows' O_NOFOLLOW.
const FILE_FLAG_OPEN_REPARSE_POINT: u32 = 0x0020_0000;
const ERROR_FILE_EXISTS: i32 = 80;

/// The access list every file this crate creates is born with.
///
/// Read the module header for what each letter means. It is a constant so that
/// the test can name the same string the writer uses, and so that changing the
/// policy is one visible edit rather than a rebuilt structure.
pub(crate) const OWNER_ONLY_SDDL: &str = "D:P(A;;FA;;;OW)";

fn wide(s: &str) -> Vec<u16> {
    std::ffi::OsStr::new(s).encode_wide().chain(std::iter::once(0)).collect()
}

fn wide_path(p: &Path) -> Vec<u16> {
    p.as_os_str().encode_wide().chain(std::iter::once(0)).collect()
}

/// A descriptor parsed from [`OWNER_ONLY_SDDL`], freed when it drops.
struct Descriptor(PSECURITY_DESCRIPTOR);

impl Drop for Descriptor {
    fn drop(&mut self) {
        if !self.0.is_null() {
            // SAFETY: `self.0` came from ConvertStringSecurityDescriptorToSecurityDescriptorW,
            // which documents LocalFree as the way to release it. It is non-null
            // here, freed exactly once because Drop runs once, and never used
            // afterwards because `self` is being destroyed.
            unsafe { LocalFree(self.0 as *mut c_void) };
        }
    }
}

impl Descriptor {
    fn owner_only() -> Result<Self, std::io::Error> {
        let sddl = wide(OWNER_ONLY_SDDL);
        let mut psd: PSECURITY_DESCRIPTOR = std::ptr::null_mut();
        // SAFETY: `sddl` is a NUL-terminated UTF-16 buffer that outlives the
        // call. `psd` is a live out-parameter the call fills on success. The
        // size out-parameter is optional and null is documented as "not
        // wanted". On failure psd is untouched and stays null.
        let ok = unsafe {
            ConvertStringSecurityDescriptorToSecurityDescriptorW(
                sddl.as_ptr(),
                SDDL_REVISION_1,
                &mut psd,
                std::ptr::null_mut(),
            )
        };
        if ok == 0 {
            return Err(std::io::Error::last_os_error());
        }
        Ok(Self(psd))
    }
}

/// Create a file that does not exist yet, with the owner-only access list and
/// inheritance cut.
///
/// Fails if anything is already at the path — including a reparse point, which
/// is not followed. That is the same refusal `create_new(true)` plus
/// `O_NOFOLLOW` gives on Unix, and for the same reason: a save must never write
/// into something an attacker put in its place, nor into whatever that thing
/// points at.
// G15-ok: creating ZVLT or ZCFG's temp file, with its access list.
pub(crate) fn create_new_owner_only(path: &Path) -> Result<std::fs::File, std::io::Error> {
    use std::os::windows::io::FromRawHandle;

    let descriptor = Descriptor::owner_only()?;
    let mut attributes = SECURITY_ATTRIBUTES {
        nLength: std::mem::size_of::<SECURITY_ATTRIBUTES>() as u32,
        lpSecurityDescriptor: descriptor.0,
        bInheritHandle: 0,
    };
    let wide = wide_path(path);

    // SAFETY: `wide` is a NUL-terminated path that outlives the call.
    // `attributes` is a fully initialised SECURITY_ATTRIBUTES whose nLength is
    // its own size and whose descriptor pointer is owned by `descriptor`, alive
    // for this whole function. CREATE_NEW means the call either creates the
    // file or fails; it never opens an existing one. The template handle is
    // null, which the API documents as "none".
    let handle: HANDLE = unsafe {
        CreateFileW(
            wide.as_ptr(),
            GENERIC_WRITE,
            FILE_SHARE_READ,
            &mut attributes,
            CREATE_NEW,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT,
            std::ptr::null_mut(),
        )
    };
    if handle == INVALID_HANDLE_VALUE {
        let err = std::io::Error::last_os_error();
        if err.raw_os_error() == Some(ERROR_FILE_EXISTS) {
            return Err(std::io::Error::new(std::io::ErrorKind::AlreadyExists, err));
        }
        return Err(err);
    }
    // SAFETY: `handle` is a valid, open file handle this function just created
    // and has not given to anyone else; File takes ownership and will close it.
    // G15-ok: wrapping the handle just opened for ZVLT or ZCFG.
    Ok(unsafe { std::fs::File::from_raw_handle(handle as *mut c_void) })
}

/// The file's access list, back as SDDL, so a test can read what was written
/// rather than trust that it was.
pub(crate) fn dacl_sddl(path: &Path) -> Result<String, std::io::Error> {
    let wide = wide_path(path);
    let mut psd: PSECURITY_DESCRIPTOR = std::ptr::null_mut();

    // SAFETY: `wide` is a NUL-terminated path alive across the call. The four
    // null out-parameters are documented as "do not want this piece". `psd`
    // receives a descriptor that must be released with LocalFree, which the
    // Descriptor wrapper below does.
    let status = unsafe {
        GetNamedSecurityInfoW(
            wide.as_ptr(),
            SE_FILE_OBJECT,
            DACL_SECURITY_INFORMATION,
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            &mut psd,
        )
    };
    if status != 0 {
        return Err(std::io::Error::from_raw_os_error(status as i32));
    }
    let owned = Descriptor(psd);

    let mut text: *mut u16 = std::ptr::null_mut();
    let mut len: u32 = 0;
    // SAFETY: `owned.0` is the live descriptor just returned. `text` and `len`
    // are out-parameters the call fills on success; the string it allocates is
    // released with LocalFree below, exactly once.
    let ok = unsafe {
        ConvertSecurityDescriptorToStringSecurityDescriptorW(
            owned.0,
            SDDL_REVISION_1,
            DACL_SECURITY_INFORMATION,
            &mut text,
            &mut len,
        )
    };
    if ok == 0 {
        return Err(std::io::Error::last_os_error());
    }
    // SAFETY: on success `text` points at `len` UTF-16 units, not counting the
    // terminator, and stays valid until the LocalFree on the next line.
    let out = unsafe { std::slice::from_raw_parts(text, len as usize) };
    let out = String::from_utf16_lossy(out);
    // SAFETY: `text` was allocated by the call above, which documents LocalFree
    // as its release, and is not used after this point.
    unsafe { LocalFree(text as *mut c_void) };
    Ok(out)
}

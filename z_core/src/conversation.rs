//! **One session's own file** — 064.
//!
//! The vault keeps a session's number, its handle and its 32 bytes. The
//! conversation itself is here, in a file of its own, sealed under a key
//! derived from those bytes.
//!
//! **Why not inside `vault.zv`:** that body is re-sealed whole on every change
//! (`vault::format::encode` → `reseal_body`). A conversation inside it would
//! rewrite every byte a person owns on every save, and grow without a ceiling.
//! That is 062 §A, and 064's guard 5 measures it: write a long conversation and
//! `vault.zv` is unchanged in size. Bytes on disk, readable twice — the one
//! instrument in this task that cannot go quiet.
//!
//! **Three version numbers exist and this file owns the third.** The fence is
//! written out in full above `vault::format::MODEL_VERSION`; in short:
//!
//! * `vault::crypto::FORMAT_VERSION` — the vault file's envelope: Argon2
//!   parameters, the wrapped master key, the nonce. 064 does not move it.
//! * `vault::format::MODEL_VERSION` — the vault body, where a session's number,
//!   handle and sealed key live. 064 moved it to 12.
//! * [`SESSION_FORMAT_VERSION`] — this file, below. A different format in a
//!   different file, and it must never borrow either number above.

use crate::api::{ApiError, ApiResult};
use crate::vault::crypto::{self, Purpose, SecretKey};

/// Bumped when the shape below changes. Read from the file, never assumed.
///
/// * 1 — the turns of one conversation: what was asked, what came back, when.
///
/// This is **not** `vault::format::MODEL_VERSION` and must never be compared
/// with it. A session file written by a newer build is refused by naming both
/// numbers, exactly as a newer vault body is.
pub(crate) const SESSION_FORMAT_VERSION: u16 = 1;

/// The folder each session's file sits in, under the data directory.
const FOLDER: &str = "sessions";

/// One exchange, as the session keeps it.
///
/// What is kept follows where the conversation happened, which is the owner's
/// own division (062 §F):
///
/// * **inside the app** — every turn, because the app saw every turn;
/// * **outside it** — the question that was copied and the answer that was
///   brought back, because that pair is the least that restores and we do not
///   pretend to hold what we never saw.
///
/// Both are the same two strings, which is why one shape serves both. `answer`
/// is empty for a question that was copied and never answered — a real state,
/// not a missing one: the person may close the app between the two.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Turn {
    /// What was asked. The person's own writing, so it is as private as the
    /// document — and it is why this file is sealed rather than merely written.
    pub question: String,
    /// What came back, raw, exactly as it arrived. Kept raw so «AI View» can
    /// show what the model actually said and a restore can be redone at any
    /// time, which is the same reason `session::AnswerRecord` keeps it raw.
    pub answer: String,
    /// Seconds since 1970 — the vault's unit, not a second one.
    pub at: u64,
}

/// Everything one session's file holds.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct Body {
    pub turns: Vec<Turn>,
}

impl Body {
    pub(crate) fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&SESSION_FORMAT_VERSION.to_be_bytes());
        out.extend_from_slice(&(self.turns.len() as u32).to_be_bytes());
        for turn in &self.turns {
            put_str(&mut out, &turn.question);
            put_str(&mut out, &turn.answer);
            out.extend_from_slice(&turn.at.to_be_bytes());
        }
        out
    }

    pub(crate) fn from_bytes(bytes: &[u8]) -> ApiResult<Self> {
        let mut at = 0usize;
        let version = u16::from_be_bytes(array::<2>(bytes, &mut at)?);
        // Named both ways round, as a newer vault body is: a person who is told
        // only «too new» cannot tell whether to upgrade or to restore.
        if version > SESSION_FORMAT_VERSION {
            return Err(ApiError::PayloadRefused {
                reason: format!(
                    "this session was written by a newer version (session format {version}, \
                     this build knows {SESSION_FORMAT_VERSION})"
                ),
            });
        }
        let count = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
        let mut turns = Vec::new();
        for _ in 0..count {
            let question = string(bytes, &mut at)?;
            let answer = string(bytes, &mut at)?;
            let when = u64::from_be_bytes(array::<8>(bytes, &mut at)?);
            turns.push(Turn { question, answer, at: when });
        }
        Ok(Self { turns })
    }
}

/// Where session `number`'s file lives.
///
/// The number and nothing the person typed: a handle may contain a slash, a
/// newline, two dots, or another session's name, and a file path built from one
/// is a path a name can steer. The handle lives in the vault, where it is only
/// ever read as text.
fn path(dir: &std::path::Path, number: u32) -> std::path::PathBuf {
    dir.join(FOLDER).join(format!("{number}.zs"))
}

/// Seal this body under the session's key and put it on disk, atomically.
///
/// The key is the session's 32 bytes; what actually seals is
/// `Purpose::SessionSeal` derived from them, so the bytes in the vault and the
/// bytes that encrypt the file are never the same bytes.
pub(crate) fn write(
    dir: &std::path::Path,
    number: u32,
    key: &SecretKey,
    body: &Body,
) -> ApiResult<()> {
    let folder = dir.join(FOLDER);
    crate::secure_file::secure_dir(&folder, "session")?;
    let sealed = crypto::seal_for(key, Purpose::SessionSeal, &body.to_bytes())?;
    crate::secure_file::replace_atomically(&path(dir, number), "zs.new", &sealed, "session")
}

/// Read one session's file back. `None` means there is no file — a session that
/// was named and has not yet been written to, which is an ordinary state.
pub(crate) fn read(dir: &std::path::Path, number: u32, key: &SecretKey) -> ApiResult<Option<Body>> {
    let Some(sealed) = crate::secure_file::read_no_follow(&path(dir, number), "session")? else {
        return Ok(None);
    };
    let plain = crypto::open_for(key, Purpose::SessionSeal, &sealed)?;
    Body::from_bytes(&plain).map(Some)
}

/// **Destroy one session's file.**
///
/// The key dies with the record in the vault; this removes the ciphertext it
/// opened. Neither is recoverable, which is what makes the owner's deletion
/// warning a fact and not a caution: nothing derives anything afterwards.
///
/// A file that is already gone is not an error — the act's promise is that it is
/// not there when this returns, and that promise is kept either way.
pub(crate) fn remove(dir: &std::path::Path, number: u32) -> ApiResult<()> {
    let at = path(dir, number);
    // Destroying one session's sealed file, which is the whole of the owner's
    // «delete the session» act. The marker below is one line on purpose: the
    // gate reads the line **directly above** the call and nothing further up,
    // so a two-line comment beginning with it reads correctly and satisfies
    // nothing. That mistake was made in 058 and twice again here.
    // G15-ok: destroying one session's sealed file.
    match std::fs::remove_file(&at) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(ApiError::PayloadRefused {
            reason: format!("session {number} could not be deleted: {e}"),
        }),
    }
}

fn put_str(out: &mut Vec<u8>, text: &str) {
    out.extend_from_slice(&(text.len() as u32).to_be_bytes());
    out.extend_from_slice(text.as_bytes());
}

fn array<const N: usize>(bytes: &[u8], at: &mut usize) -> ApiResult<[u8; N]> {
    let end = at.checked_add(N).ok_or_else(short)?;
    let slice = bytes.get(*at..end).ok_or_else(short)?;
    *at = end;
    slice.try_into().map_err(|_| short())
}

fn string(bytes: &[u8], at: &mut usize) -> ApiResult<String> {
    let len = u32::from_be_bytes(array::<4>(bytes, at)?) as usize;
    let end = at.checked_add(len).ok_or_else(short)?;
    let slice = bytes.get(*at..end).ok_or_else(short)?;
    *at = end;
    String::from_utf8(slice.to_vec()).map_err(|_| ApiError::PayloadRefused {
        reason: "a session file holds text that is not UTF-8".to_string(),
    })
}

fn short() -> ApiError {
    ApiError::PayloadRefused {
        reason: "a session file ends in the middle of what it promised".to_string(),
    }
}

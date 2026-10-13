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
/// * 2 — each turn also carries **the tokens the payload it left in allowed**.
///   Without them a stored turn could only be restored by trusting every token
///   the session ever minted, which is invariant G9 traded away for a field:
///   «a real token from elsewhere in the session is left exactly as it
///   arrived». A turn now carries its own permission and restores under the
///   same rule the live answer does.
///
/// * 3 — each turn says **what answered it**: through a key of ours and which
///   model, or that the person carried the answer in by hand, or that the turn
///   is older than the question. Three states and not two, because an empty
///   name could not tell «you pasted this» from «we do not know» (075c).
/// * 4 — and **what it was about**: a file by name, or that the person typed
///   the text, or not recorded. The same three-state shape, for the same
///   reason, and the name lives here rather than in the vault's record because
///   the record keeps a hash — «is this the same file?» and not «which file?».
///
/// 3 and 4 landed within the hour, which is worth saying so that nobody reads a
/// gap into it: the second was a separate ruling of the owner's second pillar,
/// taken while the first was still being written. A version number costs a byte
/// and a `match` arm; collapsing two decisions into one bump to look tidier
/// would have cost the distinction one of them exists to keep.
///
/// A version 1 file still reads: its turns come back with an empty allowed
/// list, which restores nothing and says so, rather than restoring everything.
/// A version 2 turn reads as «not recorded» for both of the fields above, and a
/// version 3 turn for the second — never as «there was none».
///
/// This is **not** `vault::format::MODEL_VERSION` and must never be compared
/// with it. A session file written by a newer build is refused by naming both
/// numbers, exactly as a newer vault body is.
pub(crate) const SESSION_FORMAT_VERSION: u16 = 4;

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
    /// **The tokens the payload this turn left in was allowed to carry** — G9.
    ///
    /// `restore` replaces a token only if it is in this list *and* in the
    /// session's store, so a token the model invented and a real token from
    /// another conversation are both left exactly as they arrived. The live
    /// path reads that list from the payload record; a turn read back a week
    /// later has no payload to ask, so it keeps its own.
    ///
    /// Empty is a real state and restores nothing: a direct send (the text
    /// left as it stands, so there is nothing to put back) and a version 1
    /// file (written before turns carried this) are both honestly empty.
    pub allowed: Vec<String>,
    /// **Which key and which model this exchange ran through** — 075c, the
    /// owner's first pillar: «الاسم الذي رآه الإنسان، لا السر أبداً». Never the
    /// credential, which is sealed in the vault and has no business in a
    /// conversation's file.
    ///
    /// Three states and not two, which is why it is an enum: a turn older than
    /// the question, a turn the person carried out and back by hand, and a turn
    /// that names what answered it. An empty string could carry only two of
    /// them, and the lead's ruling was that the file hold all three — «لا نعرف»
    /// ليست «لم يكن هناك».
    pub via: crate::api::TurnVia,
    /// **What this exchange was about** — format 4, the owner's second pillar.
    /// A file by name, or that the person typed the text, or not recorded. Three
    /// states for the same reason as `via`: an absence has more than one cause.
    ///
    /// It arrives from the bench the payload was built on, and it lives here
    /// rather than in the vault's record because the record keeps a *hash* — an
    /// answer to «is this the same file?» and not to «which file was it?» — and
    /// because the vault body is resealed whole on every change while a session
    /// file is not (062 §A).
    pub document: crate::api::TurnDocument,
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
            out.extend_from_slice(&(turn.allowed.len() as u32).to_be_bytes());
            for token in &turn.allowed {
                put_str(&mut out, token);
            }
            // Format 3. A kind byte, and the names only when there are
            // names: 0 is «older than the question», 1 is «the person carried
            // it», 2 is «through this key». A reader of an old file gets 0
            // because the byte is simply not there, which is the one mapping
            // that needs no decision.
            match &turn.via {
                crate::api::TurnVia::NotRecorded => out.push(0),
                crate::api::TurnVia::Pasted => out.push(1),
                crate::api::TurnVia::Through { provider, model } => {
                    out.push(2);
                    put_str(&mut out, provider);
                    put_str(&mut out, model);
                }
            }
            // Format 4, the same shape: a kind byte, and a name only when there
            // is one.
            match &turn.document {
                crate::api::TurnDocument::NotRecorded => out.push(0),
                crate::api::TurnDocument::Typed => out.push(1),
                crate::api::TurnDocument::Named { name } => {
                    out.push(2);
                    put_str(&mut out, name);
                }
            }
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
            // Read from the version this file declares, never from the constant
            // above: a version 1 file has no allowed list after `at`, and
            // reading one would take the next turn's question length as a count
            // and refuse a file that is perfectly good.
            let mut allowed = Vec::new();
            if version >= 2 {
                let how_many = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                for _ in 0..how_many {
                    allowed.push(string(bytes, &mut at)?);
                }
            }
            // A format-2 turn stops above: it was written before a turn
            // could say what answered it, so it is `NotRecorded` — which is a
            // different state from `Pasted`, and that difference is the whole
            // reason the byte exists.
            let via = if version >= 3 {
                match array::<1>(bytes, &mut at)?[0] {
                    0 => crate::api::TurnVia::NotRecorded,
                    1 => crate::api::TurnVia::Pasted,
                    2 => crate::api::TurnVia::Through {
                        provider: string(bytes, &mut at)?,
                        model: string(bytes, &mut at)?,
                    },
                    other => {
                        return Err(ApiError::PayloadRefused {
                            reason: format!("a turn says it ran through an unknown kind {other}"),
                        })
                    }
                }
            } else {
                crate::api::TurnVia::NotRecorded
            };
            // A format-3 turn stops above, exactly as a format-2 one stops
            // before `via`: it is `NotRecorded`, which is not «the person typed
            // it» — the distinction formats 3 and 4 both exist to keep.
            let document = if version >= 4 {
                match array::<1>(bytes, &mut at)?[0] {
                    0 => crate::api::TurnDocument::NotRecorded,
                    1 => crate::api::TurnDocument::Typed,
                    2 => crate::api::TurnDocument::Named { name: string(bytes, &mut at)? },
                    other => {
                        return Err(ApiError::PayloadRefused {
                            reason: format!("a turn says its document is an unknown kind {other}"),
                        })
                    }
                }
            } else {
                crate::api::TurnDocument::NotRecorded
            };
            turns.push(Turn { question, answer, at: when, allowed, via, document });
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

#[cfg(test)]
mod tests {
    use super::*;

    /// **A version 1 file still reads, and its turns are honestly empty.**
    ///
    /// The claim is made in a doc comment above `SESSION_FORMAT_VERSION`, so it
    /// is measured here rather than believed: version 1 wrote no allowed list
    /// after `at`, and a reader that looked for one would take the next turn's
    /// question length as a count and refuse a file that is perfectly good.
    ///
    /// Hand-built bytes and not a round trip, because the writer cannot produce
    /// a version 1 file any more — which is the whole reason this is the only
    /// instrument that can say the older format is still readable.
    #[test]
    fn a_version_one_file_reads_with_no_allowed_list() {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&1u16.to_be_bytes());
        bytes.extend_from_slice(&2u32.to_be_bytes());
        for (q, a) in [("asked", "answered"), ("asked again", "")] {
            bytes.extend_from_slice(&(q.len() as u32).to_be_bytes());
            bytes.extend_from_slice(q.as_bytes());
            bytes.extend_from_slice(&(a.len() as u32).to_be_bytes());
            bytes.extend_from_slice(a.as_bytes());
            bytes.extend_from_slice(&7u64.to_be_bytes());
        }

        let body = Body::from_bytes(&bytes).expect("a version 1 file is readable");
        assert_eq!(body.turns.len(), 2);
        assert_eq!(body.turns[0].question, "asked");
        assert_eq!(body.turns[1].answer, "");
        assert!(
            body.turns.iter().all(|t| t.allowed.is_empty()),
            "a version 1 turn carries no permission, so it restores nothing — \
             which is the safe direction, not the convenient one"
        );
    }

    /// The control for the test above: what the writer writes, the reader reads
    /// back whole — the allowed list and, since format 3, which key answered.
    /// If this were red the reader would be broken and the version 1 result
    /// would mean nothing.
    #[test]
    fn a_round_trip_keeps_everything_a_turn_carries() {
        let body = Body {
            turns: vec![Turn {
                question: "who is __Z_1111_PERSON_2222__".to_string(),
                answer: "__Z_1111_PERSON_2222__ is".to_string(),
                at: 9,
                allowed: vec!["__Z_1111_PERSON_2222__".to_string()],
                via: crate::api::TurnVia::Through {
                    provider: "fake".to_string(),
                    model: "the-model-the-person-saw".to_string(),
                },
                document: crate::api::TurnDocument::Named { name: "Brev.txt".to_string() },
            }],
        };
        let back = Body::from_bytes(&body.to_bytes()).expect("round trip");
        assert_eq!(back, body);
    }

    /// **A format 3 turn knows what answered it and not what it was about.**
    ///
    /// The pair with the test below: each format bump leaves the older files
    /// readable, and each older file is honest about the field it never had.
    /// Hand-built, because the writer can only produce format 4 now — and the
    /// `via` assertion is the control: if that came back wrong the document
    /// result would mean nothing, because the reader would simply be lost in
    /// the bytes.
    #[test]
    fn a_format_three_turn_was_about_a_file_it_cannot_name() {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&3u16.to_be_bytes());
        bytes.extend_from_slice(&1u32.to_be_bytes());
        let (q, a) = ("asked", "answered");
        bytes.extend_from_slice(&(q.len() as u32).to_be_bytes());
        bytes.extend_from_slice(q.as_bytes());
        bytes.extend_from_slice(&(a.len() as u32).to_be_bytes());
        bytes.extend_from_slice(a.as_bytes());
        bytes.extend_from_slice(&7u64.to_be_bytes());
        bytes.extend_from_slice(&0u32.to_be_bytes()); // an empty allowed list
        bytes.push(2); // it ran through a key…
        let (p, m) = ("fake", "a-model");
        bytes.extend_from_slice(&(p.len() as u32).to_be_bytes());
        bytes.extend_from_slice(p.as_bytes());
        bytes.extend_from_slice(&(m.len() as u32).to_be_bytes());
        bytes.extend_from_slice(m.as_bytes());
        // …and then the file simply ends: format 3 had no document byte.

        let body = Body::from_bytes(&bytes).expect("a format 3 file is readable");
        let turn = body.turns.first().expect("one turn");
        assert_eq!(
            turn.via,
            crate::api::TurnVia::Through { provider: p.to_string(), model: m.to_string() },
            "the control failed: a format 3 turn's own field did not read back, so \
             nothing below is measuring what it claims"
        );
        assert_eq!(
            turn.document,
            crate::api::TurnDocument::NotRecorded,
            "a turn older than format 4 was told which file it was about"
        );
    }

    /// **A format 2 turn says «not recorded», not «whatever is configured
    /// today»** — 075c, the owner's first pillar at the format's edge.
    ///
    /// Hand-built bytes again, because the writer cannot produce a format 2
    /// file any more. The pair is the point: a turn from before the field
    /// existed and a turn whose answer was pasted are both honestly unknown,
    /// and a turn that names a model keeps naming it. Reading the configured
    /// provider into an old turn would be a guess about the one thing the field
    /// exists to state.
    #[test]
    fn a_format_two_turn_names_no_key_and_says_so() {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&2u16.to_be_bytes());
        bytes.extend_from_slice(&1u32.to_be_bytes());
        let (q, a) = ("asked", "answered");
        bytes.extend_from_slice(&(q.len() as u32).to_be_bytes());
        bytes.extend_from_slice(q.as_bytes());
        bytes.extend_from_slice(&(a.len() as u32).to_be_bytes());
        bytes.extend_from_slice(a.as_bytes());
        bytes.extend_from_slice(&7u64.to_be_bytes());
        bytes.extend_from_slice(&0u32.to_be_bytes()); // an empty allowed list

        let body = Body::from_bytes(&bytes).expect("a format 2 file is readable");
        let turn = body.turns.first().expect("one turn");
        assert_eq!(turn.answer, "answered", "the older format stopped being readable");
        assert_eq!(
            turn.via,
            crate::api::TurnVia::NotRecorded,
            "a turn older than format 3 was given a state it never had — and «older \
             than the question» is not «the person carried it»"
        );
        assert_eq!(
            turn.document,
            crate::api::TurnDocument::NotRecorded,
            "nor was it about a file it could name"
        );
    }
}

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
/// * 5 — **the documents the preview holds** (089 rule 9, the owner's rule of
///   15 October: «عنصرنا هو البلوك لا المستند»). Documents are not saved — their
///   owner has them on his own disk — with one exception: what is in the
///   preview and has not left it, with the decisions made on it, so that a
///   power cut finds it as it was left. A file pulled from the computer is
///   `doc1`, `doc2`…; a text written with the AI and moved to the preview is
///   `chat1`, `chat2`…. Leaving by a door takes it out and retires its number.
///   A version 4 file reads with none, which is every session written before
///   this round.
/// * 6 — **which chat each turn belongs to, and which saved document it
///   carried** (rules 67–69, the owner's «نعم» of
///   17 October: «لا أستطيع أن أتابع الشات معه على نفس الموضوع»). A chat is the
///   run of turns a question and its follow-ups make; it ends when the person
///   ends it or the application closes. Every turn names its chat, and the
///   session names the chat that is open. A version 5 file reads with every
///   turn in **chat 0** — no numbered chat at all — and the open chat 1, which
///   is the truth about it: those turns were asked before chats were counted
///   and the application has been closed since, so none of them belongs to the
///   one that is open now. Its turns name no saved document either, which is
///   the same honest zero: the number was not written down when they were
///   asked, and rule 69's «sent · answered» is drawn from that number because
///   after rule 9 it is all that is left of a document that went out.
pub(crate) const SESSION_FORMAT_VERSION: u16 = 6;

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
    /// **Which chat of this session this exchange belongs to** — rules 67–68,
    /// format 6.
    ///
    /// Rule 67 sends the earlier turns with every later question, and rule 68
    /// says where that stops: a chat ends when the person ends it or the
    /// application closes. So the boundary is **written down beside the turn**,
    /// not worked out from the clock or from how far apart two turns are — the
    /// history a question carries is the turns of the open chat and no others.
    ///
    /// `0` is a turn older than this round. It belongs to no numbered chat, and
    /// chats are numbered from 1, so an old turn can never be read as part of
    /// the chat that is open — which «chat 1» as a default would have done, and
    /// it would have handed a new question yesterday's conversation.
    ///
    /// **Not [`Kept::chat`]**, which is a `bool` two fields below and means
    /// something else entirely: whether a saved document was written here with
    /// the AI (`chat1`) or pulled off the computer (`doc1`). One word, two
    /// meanings, so they are spelled apart.
    pub chat_number: u32,
    /// **Which saved document this exchange carried** — its number, `0` for
    /// none, and whether that number is a `chatN` or a `docN` (rule 54-ج's two
    /// sequences).
    ///
    /// Rule 69 draws «sent · answered» under the document that came in, and
    /// after rule 9 the **number is all that is left of it**: the preview's
    /// copy goes the moment the text leaves, so a room that matched on the
    /// name would be matching on something a person may rename, and on
    /// something two documents may share.
    ///
    /// It is stamped on the **payload** when that was built, not read off the
    /// bench when the answer arrives — the two differ exactly where it
    /// matters: a person who copies the text out and comes back with an answer
    /// from a browser has already had the copy taken out of the list, and the
    /// bench holds nothing to name.
    ///
    /// `0` is «no saved document», which is the honest state of a follow-up
    /// question: it carried no document (rule 67), so it names none. What ties
    /// it to the one the chat began with is `chat_number` above.
    pub kept_number: u32,
    pub kept_chat: bool,
}

/// **One mark on a saved document** — the decision, not the value.
///
/// The value is **not** written: it is the text under `start..end` in the
/// document's own text, which this file already holds. One fact, one place —
/// and a mark whose value disagreed with the text under it would be a
/// protection pointing at the wrong word.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct KeptMark {
    /// Byte offsets into the saved text.
    pub start: u32,
    pub end: u32,
    pub token: String,
    pub kind: crate::api::Kind,
    pub scope: crate::api::Scope,
    pub source: crate::api::Source,
    pub detail: String,
    pub decided: bool,
    pub orphaned: bool,
}

/// **One document the preview holds** — 089 rule 9.
///
/// Its number is the `N` of `docN` or `chatN`: the identity, never reused, and
/// never the name. `name` is what the person reads and may change («Rename»),
/// which is why the two are separate fields — the same division the vault's
/// `Conversation` keeps between its number and its handle.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Kept {
    pub number: u32,
    /// `chat1` rather than `doc1`: a text written with the AI and moved to the
    /// preview, rather than a file pulled from the computer. Two sequences,
    /// because the owner wrote both of them starting at one.
    pub chat: bool,
    pub name: String,
    /// The document as the app read it — the text the marks point into.
    pub text: String,
    /// **What it was**, so a restored PDF does not call itself a text file on
    /// the band. The kind, how many pages the reader found, the size of the
    /// file as it arrived and the lowest readable share of any page: four
    /// facts the core already reports about a document, and a copy that
    /// dropped them would re-open as a different document from the one that
    /// was put away.
    ///
    /// **What is not kept is `places`** — where each run sits on which page.
    /// The marks carry their own offsets into the text above, which is what a
    /// mark needs; a place is a fact about the *file*, measured by the reader
    /// that opened it, and a copy that claimed page numbers it had not
    /// measured would be inventing them. So a restored document's marks say
    /// «no place recorded», which is the honest absence the question composer
    /// already uses, and not «page 1».
    pub kind: crate::api::DocumentKind,
    pub pages: u32,
    pub bytes: u32,
    pub readable: u32,
    pub marks: Vec<KeptMark>,
    /// The values a person said «Leave it» about, so re-opening does not ask
    /// again. The same list `Session::dismissed` holds.
    pub dismissed: Vec<String>,
    pub at: u64,
}

/// **The persistence codes of a scope and a source**, for this file only.
///
/// A code may never be reused: an old session would read «everywhere» as «this
/// one place», or a word the person selected as one a rule found. New variants
/// take the next free number, always — the same contract
/// `vault::format::kind_code` carries, and the kinds themselves are read
/// through that one table rather than copied into a second.
/// The persistence code of a document's kind, for this file only — and a code
/// may never be reused, like every other table in this house: an old session
/// would re-open a PDF as a Word file.
fn document_kind_code(kind: crate::api::DocumentKind) -> u8 {
    match kind {
        crate::api::DocumentKind::Txt => 1,
        crate::api::DocumentKind::Pdf => 2,
        crate::api::DocumentKind::Docx => 3,
    }
}

fn document_kind_of(code: u8) -> ApiResult<crate::api::DocumentKind> {
    Ok(match code {
        1 => crate::api::DocumentKind::Txt,
        2 => crate::api::DocumentKind::Pdf,
        3 => crate::api::DocumentKind::Docx,
        other => {
            return Err(ApiError::PayloadRefused {
                reason: format!("a saved document is of a kind ({other}) this build does not know"),
            })
        }
    })
}

fn scope_code(scope: crate::api::Scope) -> u8 {
    match scope {
        crate::api::Scope::Once => 1,
        crate::api::Scope::Conversation => 2,
        crate::api::Scope::Profile => 3,
        crate::api::Scope::Always => 4,
    }
}

fn scope_of(code: u8) -> ApiResult<crate::api::Scope> {
    Ok(match code {
        1 => crate::api::Scope::Once,
        2 => crate::api::Scope::Conversation,
        3 => crate::api::Scope::Profile,
        4 => crate::api::Scope::Always,
        other => {
            return Err(ApiError::PayloadRefused {
                reason: format!("a saved document holds a reach ({other}) this build does not know"),
            })
        }
    })
}

fn source_code(source: crate::api::Source) -> u8 {
    match source {
        crate::api::Source::GeneralRule => 1,
        crate::api::Source::LanguagePack => 2,
        crate::api::Source::Vault => 3,
        crate::api::Source::Hand => 4,
    }
}

fn source_of(code: u8) -> ApiResult<crate::api::Source> {
    Ok(match code {
        1 => crate::api::Source::GeneralRule,
        2 => crate::api::Source::LanguagePack,
        3 => crate::api::Source::Vault,
        4 => crate::api::Source::Hand,
        other => {
            return Err(ApiError::PayloadRefused {
                reason: format!("a saved document holds a finder ({other}) this build does not know"),
            })
        }
    })
}

/// Everything one session's file holds.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Body {
    pub turns: Vec<Turn>,
    /// **The documents the preview holds** — 089 rule 9. Empty is the ordinary
    /// state: a document that left by a door is not here, and that is the rule
    /// rather than a loss.
    pub kept: Vec<Kept>,
    /// The next `docN`, and the next `chatN`. They only ever go up: a number a
    /// document took is spent for ever, so a stale reference to `doc1` cannot
    /// land on somebody else's document — the same rule the vault's session
    /// numbers follow.
    pub next_doc: u32,
    pub next_chat: u32,
    /// **The chat that is open in this session** — rule 68, format 6.
    ///
    /// Numbered from 1, and it only ever goes up, for the same reason the two
    /// numbers above do: a chat that has ended must never be written into
    /// again, and a number spent for ever is how that is made true rather than
    /// remembered. `end_the_chat` spends one; so does the first time this
    /// session is opened in a run, because closing the application ends the
    /// chat and a new run cannot find one open.
    pub chat_now: u32,
}

/// **The numbers start at one, not at zero** — and that is why this is written
/// out rather than derived. A derived default would hand the first document
/// `doc0`, and zero is the one number that must never name a document: a
/// reference nobody filled in reads as zero, and it would land on the first
/// document a person ever opened. The vault's session numbers start at one for
/// the same reason.
impl Default for Body {
    fn default() -> Self {
        Self { turns: Vec::new(), kept: Vec::new(), next_doc: 1, next_chat: 1, chat_now: 1 }
    }
}

impl Body {
    /// The next number for a document of this kind, spent as it is handed out.
    pub(crate) fn take_number(&mut self, chat: bool) -> u32 {
        let next = if chat { &mut self.next_chat } else { &mut self.next_doc };
        let number = *next;
        *next = next.saturating_add(1);
        number
    }

    /// What a saved document is called in the list: `doc3`, `chat1`.
    pub(crate) fn handle_of(kept: &Kept) -> String {
        Self::handle_spelling(kept.number, kept.chat)
    }

    /// **The same spelling, from the two facts that make it** — because a turn
    /// names the document it carried by number and flag (rule 69) and has no
    /// `Kept` to hand: the copy it points at has usually left the list by then.
    /// One function, so the list and the chat cannot spell one document two
    /// ways.
    pub(crate) fn handle_spelling(number: u32, chat: bool) -> String {
        format!("{}{}", if chat { "chat" } else { "doc" }, number)
    }

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
            // Format 6 — which chat this turn belongs to, at the end of the
            // turn's own record, so a format 5 file's turns are read whole by
            // the reader below and simply belong to no numbered chat.
            out.extend_from_slice(&turn.chat_number.to_be_bytes());
            out.extend_from_slice(&turn.kept_number.to_be_bytes());
            out.push(u8::from(turn.kept_chat));
        }
        // Format 5 — the documents the preview holds, after the turns, so that
        // a build which stops above reads every turn it knows and simply holds
        // no document. Nothing already written moves.
        out.extend_from_slice(&self.next_doc.to_be_bytes());
        out.extend_from_slice(&self.next_chat.to_be_bytes());
        out.extend_from_slice(&(self.kept.len() as u32).to_be_bytes());
        for kept in &self.kept {
            out.extend_from_slice(&kept.number.to_be_bytes());
            out.push(u8::from(kept.chat));
            put_str(&mut out, &kept.name);
            put_str(&mut out, &kept.text);
            out.extend_from_slice(&kept.at.to_be_bytes());
            out.push(document_kind_code(kept.kind));
            out.extend_from_slice(&kept.pages.to_be_bytes());
            out.extend_from_slice(&kept.bytes.to_be_bytes());
            out.extend_from_slice(&kept.readable.to_be_bytes());
            out.extend_from_slice(&(kept.marks.len() as u32).to_be_bytes());
            for mark in &kept.marks {
                out.extend_from_slice(&mark.start.to_be_bytes());
                out.extend_from_slice(&mark.end.to_be_bytes());
                put_str(&mut out, &mark.token);
                out.push(crate::vault::format::kind_code(mark.kind));
                out.push(scope_code(mark.scope));
                out.push(source_code(mark.source));
                put_str(&mut out, &mark.detail);
                out.push(u8::from(mark.decided));
                out.push(u8::from(mark.orphaned));
            }
            out.extend_from_slice(&(kept.dismissed.len() as u32).to_be_bytes());
            for value in &kept.dismissed {
                put_str(&mut out, value);
            }
        }
        // Format 6 — the chat that is open, last of all, after everything
        // format 5 wrote. Nothing already written moves, which is the rule
        // every version here has followed.
        out.extend_from_slice(&self.chat_now.to_be_bytes());
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
            // A format-5 turn stops above, as a format-3 one stops before its
            // document: it belongs to **no numbered chat** (0), which is not
            // «the chat that is open» — the distinction format 6 exists to
            // keep, because reading an old turn as part of today's chat would
            // send a stranger's conversation with the next question.
            let (chat_number, kept_number, kept_chat) = if version >= 6 {
                (
                    u32::from_be_bytes(array::<4>(bytes, &mut at)?),
                    u32::from_be_bytes(array::<4>(bytes, &mut at)?),
                    array::<1>(bytes, &mut at)?[0] != 0,
                )
            } else {
                (0, 0, false)
            };
            turns.push(Turn {
                question,
                answer,
                at: when,
                allowed,
                via,
                document,
                chat_number,
                kept_number,
                kept_chat,
            });
        }
        // Format 5. A session written before this round stops above and holds
        // no document — which is the truth about it, not a document lost.
        let mut kept = Vec::new();
        let (mut next_doc, mut next_chat) = (1u32, 1u32);
        if version >= 5 {
            next_doc = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
            next_chat = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
            let how_many = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
            for _ in 0..how_many {
                let number = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                let chat = array::<1>(bytes, &mut at)?[0] != 0;
                let name = string(bytes, &mut at)?;
                let text = string(bytes, &mut at)?;
                let when = u64::from_be_bytes(array::<8>(bytes, &mut at)?);
                let kind = document_kind_of(array::<1>(bytes, &mut at)?[0])?;
                let pages = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                let file_bytes = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                let readable = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                let marks_count = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                let mut marks = Vec::new();
                for _ in 0..marks_count {
                    let start = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                    let end = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                    let token = string(bytes, &mut at)?;
                    let kind = crate::vault::format::kind_of(array::<1>(bytes, &mut at)?[0])?;
                    let scope = scope_of(array::<1>(bytes, &mut at)?[0])?;
                    let source = source_of(array::<1>(bytes, &mut at)?[0])?;
                    let detail = string(bytes, &mut at)?;
                    let decided = array::<1>(bytes, &mut at)?[0] != 0;
                    let orphaned = array::<1>(bytes, &mut at)?[0] != 0;
                    marks.push(KeptMark {
                        start,
                        end,
                        token,
                        kind,
                        scope,
                        source,
                        detail,
                        decided,
                        orphaned,
                    });
                }
                let dismissed_count = u32::from_be_bytes(array::<4>(bytes, &mut at)?);
                let mut dismissed = Vec::new();
                for _ in 0..dismissed_count {
                    dismissed.push(string(bytes, &mut at)?);
                }
                kept.push(Kept {
                    number,
                    chat,
                    name,
                    text,
                    kind,
                    pages,
                    bytes: file_bytes,
                    readable,
                    marks,
                    dismissed,
                    at: when,
                });
            }
        }
        // Format 6. A session written before this round holds no chat number,
        // and the chat that is open in it is **1** — the first one anybody
        // will write into. Its own turns are in chat 0, so the first question
        // asked of an old session carries nothing of what was asked before the
        // application last closed, which is rule 68 read backwards.
        let chat_now = if version >= 6 {
            u32::from_be_bytes(array::<4>(bytes, &mut at)?)
        } else {
            1
        };
        Ok(Self { turns, kept, next_doc, next_chat, chat_now })
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
                chat_number: 3,
                kept_number: 2,
                kept_chat: true,
            }],
            chat_now: 3,
            ..Body::default()
        };
        let back = Body::from_bytes(&body.to_bytes()).expect("round trip");
        assert_eq!(back, body);
    }

    /// **A format 5 file still reads, and none of its turns is in today's
    /// chat** — the claim in the doc comment above `SESSION_FORMAT_VERSION`,
    /// measured rather than believed.
    ///
    /// Hand-built bytes, like the version 1 instrument above and for the same
    /// reason: the writer cannot produce a format 5 file any more, so this is
    /// the only thing that can say an older one is read whole. What it has to
    /// prove is not only that the bytes parse — it is that an old turn comes
    /// back in **chat 0** while the open chat is **1**, because a turn read as
    /// part of the open chat would be sent with the next question (rule 67) to
    /// a model that was never shown it.
    #[test]
    fn a_format_five_file_reads_and_its_turns_belong_to_no_chat() {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&5u16.to_be_bytes());
        bytes.extend_from_slice(&1u32.to_be_bytes());
        // One turn, as format 5 wrote it: question, answer, when, no allowed
        // tokens, «through this key», «the person typed it».
        for s in ["asked", "answered"] {
            bytes.extend_from_slice(&(s.len() as u32).to_be_bytes());
            bytes.extend_from_slice(s.as_bytes());
        }
        bytes.extend_from_slice(&11u64.to_be_bytes());
        bytes.extend_from_slice(&0u32.to_be_bytes());
        bytes.push(2);
        for s in ["fake", "echo"] {
            bytes.extend_from_slice(&(s.len() as u32).to_be_bytes());
            bytes.extend_from_slice(s.as_bytes());
        }
        bytes.push(1);
        // Format 5's tail: the two next-numbers and no saved document.
        bytes.extend_from_slice(&1u32.to_be_bytes());
        bytes.extend_from_slice(&1u32.to_be_bytes());
        bytes.extend_from_slice(&0u32.to_be_bytes());

        let body = Body::from_bytes(&bytes).expect("a format 5 file is readable");
        assert_eq!(body.turns.len(), 1, "the turn a format 5 file holds was lost");
        assert_eq!(body.turns[0].question, "asked");
        assert_eq!(
            body.turns[0].chat_number, 0,
            "a turn written before chats were counted was read as part of a numbered chat"
        );
        assert_eq!(
            body.chat_now, 1,
            "an old session's open chat must be the first one anybody writes into"
        );
        assert_ne!(
            body.turns[0].chat_number, body.chat_now,
            "an old turn landed in the open chat, so the next question would carry it"
        );
        assert_eq!(
            body.turns[0].kept_number, 0,
            "an old turn named a saved document nobody wrote down, which rule 69 \
             would then draw «sent · answered» under"
        );
    }

    /// **A saved document survives the file with every decision on it** —
    /// 089 rule 9, on disk.
    ///
    /// The marks are the point: a document that came back with its text and
    /// without its protections would re-open as an unprotected document, which
    /// is the one state this rule exists to prevent. The value under each mark
    /// is **not** stored — it is the text the mark points into — so the
    /// assertion below reads it back out of the text, which is also the proof
    /// that the offsets survived.
    #[test]
    fn a_saved_document_keeps_its_decisions() {
        const TEXT: &str = "Hej Stefan Keller, ditt konto är öppet.";
        let at = TEXT.find("Stefan Keller").expect("the fixture");
        let body = Body {
            turns: Vec::new(),
            kept: vec![Kept {
                number: 3,
                chat: false,
                name: "Brev_Keller.txt".to_string(),
                text: TEXT.to_string(),
                kind: crate::api::DocumentKind::Pdf,
                pages: 17,
                bytes: 90_210,
                readable: 100,
                marks: vec![KeptMark {
                    start: at as u32,
                    end: (at + "Stefan Keller".len()) as u32,
                    token: "__Z_F610_PERSON_343AD503__".to_string(),
                    kind: crate::api::Kind::Person,
                    scope: crate::api::Scope::Conversation,
                    source: crate::api::Source::Hand,
                    detail: "selected by you".to_string(),
                    decided: true,
                    orphaned: false,
                }],
                dismissed: vec!["Stadtwerke".to_string()],
                at: 1_760_000_000,
            }],
            next_doc: 4,
            next_chat: 1,
            chat_now: 1,
        };
        let back = Body::from_bytes(&body.to_bytes()).expect("round trip");
        assert_eq!(back, body);
        let kept = back.kept.first().expect("the document");
        assert_eq!(Body::handle_of(kept), "doc3", "the handle is not the number it was given");
        // **What it was survives too**, so a restored PDF does not call itself
        // a text file on the band.
        assert_eq!(kept.kind, crate::api::DocumentKind::Pdf, "the document's kind did not survive");
        assert_eq!(kept.pages, 17, "the page count did not survive");
        assert_eq!(kept.bytes, 90_210);
        assert_eq!(kept.readable, 100);
        let mark = kept.marks.first().expect("the mark");
        assert_eq!(
            kept.text.get(mark.start as usize..mark.end as usize),
            Some("Stefan Keller"),
            "the mark no longer points at the word it was made on"
        );
        // And the numbers are spent, never handed out twice.
        let mut again = back.clone();
        assert_eq!(again.take_number(false), 4);
        assert_eq!(again.take_number(false), 5);
        assert_eq!(again.take_number(true), 1, "the two sequences are not one");
    }

    /// **A session written before rule 9 holds no document, and says so.**
    #[test]
    fn a_format_four_file_holds_no_saved_document() {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&4u16.to_be_bytes());
        bytes.extend_from_slice(&0u32.to_be_bytes()); // no turns
        let body = Body::from_bytes(&bytes).expect("a format 4 file opens");
        assert!(body.kept.is_empty(), "a document was read out of a file that has none");
        assert_eq!((body.next_doc, body.next_chat), (1, 1), "the numbers did not start at one");
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

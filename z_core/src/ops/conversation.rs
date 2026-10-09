//! **The owner's sessions** — 064.
//!
//! A session is born of the act that needs it: Copy, a PDF, a question sent to
//! a model, while none is open. The name is asked once, then; entering an old
//! session asks nothing; **there is no «new session» button**, which is why
//! there is no argument about where one would live.
//!
//! The word in code is `Conversation` because `session::Session` already means
//! one document's bench and the API's `session: u32` is that bench's id. Task
//! 066 pays the rename.

use crate::api::{ApiError, ApiResult, ConversationRow, SessionId};
use crate::session::with_core;

/// The handle, cleaned. Empty after cleaning is refused rather than stored: a
/// session with no name is a row a person cannot tell from another row, and the
/// name is asked exactly once so there is no second chance to fix it.
fn clean(name: &str) -> ApiResult<String> {
    let name = name.trim();
    if name.is_empty() {
        // **`InputRefused`, not `PayloadRefused`** — one variant per next move.
        // Nothing is wrong with a payload here; what is missing is a word the
        // person has not typed yet, and the move is to type it. The screen's
        // sentence follows the variant, so the variant has to be the one whose
        // sentence tells them what to do.
        return Err(ApiError::InputRefused {
            reason: "a session needs a name — it is the only thing that tells two apart"
                .to_string(),
        });
    }
    // One line. A handle is shown in a list, and a newline in it would redraw
    // the list rather than name a row.
    Ok(name.split_whitespace().collect::<Vec<_>>().join(" "))
}

/// **Begin one, and give the bench its names.**
///
/// The re-derivation is the whole of the lead's ruling: the names that leave are
/// the session's names. Copy is the first exit, so a token that changes here has
/// broken no promise to anybody.
pub(crate) fn begin(name: String, bench: Option<SessionId>) -> ApiResult<ConversationRow> {
    let name = clean(&name)?;
    with_core(|core| {
        // **A birth with a document open must name it** — 064f. Without the
        // bench nothing is re-derived, and the payload that leaves afterwards is
        // stamped with this session while its text still wears pre-birth names.
        // Refused here rather than guessed at: with several benches the core
        // cannot know which document the person is looking at, and picking one
        // would be a guess about the only thing that matters.
        if bench.is_none() {
            if let Some(live) = core.a_live_bench() {
                return Err(ApiError::SessionWithoutItsDocument {
                    reason: format!(
                        "a document is open (bench {live}) and this call did not name it, so its \
                         protected names could not be moved into the new session"
                    ),
                });
            }
        }
        let document = bench
            .and_then(|b| core.get(b.id))
            .map(|s| s.original_str().to_string())
            .filter(|text| !text.is_empty());
        let number = core.vault.begin_conversation(&name, document.as_deref())?;
        core.open_conversation = Some(number);
        let renamed = take_the_names(core, number, bench);
        // An empty file, written now rather than at the first turn, so that a
        // session which exists in the vault also exists on disk: a record with
        // no file would be a session whose deletion has nothing to destroy.
        write_body(core, number, &crate::conversation::Body::default())?;
        Ok(ConversationRow {
            number,
            name,
            began_at: core
                .vault
                .conversations()
                .into_iter()
                .find(|(n, _, _)| *n == number)
                .map(|(_, _, at)| at)
                .unwrap_or(0),
            turns: 0,
            renamed_tokens: renamed,
        })
    })
}

/// **Enter an existing one.** Asks nothing, by the owner's rule — and gives the
/// bench this session's names, which is the same act as a birth minus the key.
pub(crate) fn enter(number: u32, bench: Option<SessionId>) -> ApiResult<ConversationRow> {
    with_core(|core| {
        let Some((_, name, began_at)) = core
            .vault
            .conversations()
            .into_iter()
            .find(|(n, _, _)| *n == number)
        else {
            return Err(ApiError::PayloadRefused {
                reason: format!("there is no session {number}"),
            });
        };
        core.open_conversation = Some(number);
        let renamed = take_the_names(core, number, bench);
        let turns = match body(core, number) {
            Ok(Some(body)) => body.turns.len() as u32,
            _ => 0,
        };
        Ok(ConversationRow {
            number,
            name,
            began_at,
            turns,
            renamed_tokens: renamed,
        })
    })
}

/// Which session is open, if any.
///
/// **Asked of the vault's state as well as of the number**, so that an
/// auto-lock — which fires inside the tick and drops the master key without
/// anybody calling `vault_lock` — cannot leave a number standing that no key
/// opens. One fact, one source: a session is open when a number is held *and*
/// there is a key to open it with.
pub(crate) fn open() -> ApiResult<Option<u32>> {
    Ok(with_core(|core| {
        if core.vault.state() == crate::api::VaultState::Unlocked {
            core.open_conversation
        } else {
            None
        }
    }))
}

/// Every session: number, handle, when, and how many turns its file holds.
pub(crate) fn rows() -> ApiResult<Vec<ConversationRow>> {
    with_core(|core| {
        let mut out = Vec::new();
        for (number, name, began_at) in core.vault.conversations() {
            let turns = match body(core, number) {
                Ok(Some(body)) => body.turns.len() as u32,
                _ => 0,
            };
            out.push(ConversationRow {
                number,
                name,
                began_at,
                turns,
                renamed_tokens: 0,
            });
        }
        Ok(out)
    })
}

pub(crate) fn rename(number: u32, name: String) -> ApiResult<()> {
    let name = clean(&name)?;
    with_core(|core| core.vault.rename_conversation(number, &name))
}

/// **Delete one, key and ciphertext together.**
///
/// They cannot be separated — the key *is* the map — so they are not offered
/// separately (064 §4). The record goes first: if the file could not be removed
/// the key is already gone, and a ciphertext nobody can open is a better
/// leftover than a key for a conversation the person believes is deleted.
pub(crate) fn forget(number: u32) -> ApiResult<String> {
    with_core(|core| {
        let name = core.vault.forget_conversation(number)?;
        if core.open_conversation == Some(number) {
            core.open_conversation = None;
        }
        if let Some(dir) = core.vault.dir() {
            crate::conversation::remove(dir, number)?;
        }
        Ok(name)
    })
}

/// Add one exchange to the open session's file.
///
/// `answer` may be empty: a question copied out and not yet answered is a real
/// state, and the person may close the app between the two halves.
pub(crate) fn record(question: String, answer: String) -> ApiResult<u32> {
    with_core(|core| {
        let Some(number) = core.open_conversation else {
            return Err(ApiError::PayloadRefused {
                reason: "there is no session open to write to".to_string(),
            });
        };
        record_in(core, number, question, answer, Vec::new())
    })
}

/// Add one exchange to session `number`'s file, holding the core already.
///
/// Separate from `record` above because **the send path cannot call `record`**:
/// `with_core` is not re-entrant (the comment above `bump_truth` says so), and
/// an answer arrives inside a core borrow that is already open. So the write
/// takes a `&mut Core` and the two doors share one implementation instead of
/// each growing its own.
///
/// `allowed` is the tokens the payload this turn left in was permitted to
/// carry. It is stored with the turn because a turn read back next week has no
/// payload record to ask, and restoring it against the whole session's store
/// would hand back tokens G9 exists to leave alone.
pub(crate) fn record_in(
    core: &mut crate::session::Core,
    number: u32,
    question: String,
    answer: String,
    allowed: Vec<String>,
) -> ApiResult<u32> {
    let mut body = body(core, number)?.unwrap_or_default();
    body.turns.push(crate::conversation::Turn {
        question,
        answer,
        at: crate::vault::model::now_seconds(),
        allowed,
    });
    write_body(core, number, &body)?;
    Ok(body.turns.len() as u32)
}

/// **Every turn session `number` holds, restored.**
///
/// The number is a parameter and not «whichever session is open», so a screen
/// showing one row's history cannot be reading another row's file, and a guard
/// that passes a number measures the file it names.
///
/// **What crosses the boundary is restored text, never a stored token.** The
/// file keeps both halves as they left — the question in the form that
/// travelled, the answer exactly as it arrived — so what is on disk resolves
/// to a name only through the session's own store. Putting the names back is
/// therefore the core's work: a screen handed the stored form would print
/// `__Z_5CDD_IBAN_5B32__` in the middle of the model's sentence, which is the
/// lie 046/U was written to end.
///
/// `bench` is the workbench whose store holds the values. Without one — the
/// room opened before any document is loaded — nothing resolves, and every
/// token is reported in `unresolved` rather than passed off as prose. An empty
/// store is the honest instrument here: `restore` already reports what it
/// cannot place, so one implementation serves both cases and they cannot
/// disagree.
pub(crate) fn turns(number: u32, bench: Option<SessionId>) -> ApiResult<Vec<crate::api::TurnRow>> {
    with_core(|core| {
        let Some(body) = body(core, number)? else {
            // No file: a session named and not yet written to. An ordinary
            // state, and an empty list is the true answer to «what does it
            // hold» — not an error to be shown to anybody.
            return Ok(Vec::new());
        };
        // Borrowed, never moved out. An earlier draft took the store with
        // `mem::take` and put it back at the end, which reads as a read and is
        // not one: any `?` added between the two lines later would leave the
        // bench without its tokens, and a person's protection would vanish
        // because somebody added an error case to a getter.
        let nothing = crate::tokens::TokenStore::default();
        let store: &crate::tokens::TokenStore = match bench.and_then(|b| core.get(b.id)) {
            Some(s) => &s.tokens,
            None => &nothing,
        };
        let mut rows = Vec::new();
        for turn in &body.turns {
            let question = crate::tokens::restore(&turn.question, store, &turn.allowed);
            let answer = crate::tokens::restore(&turn.answer, store, &turn.allowed);
            let mut unresolved = question.unknown;
            for name in answer.unknown {
                if !unresolved.contains(&name) {
                    unresolved.push(name);
                }
            }
            rows.push(crate::api::TurnRow {
                question: question.segments,
                answer: answer.segments,
                at: turn.at,
                unresolved,
            });
        }
        Ok(rows)
    })
}

/// Does the open session still belong to the document on this bench? — 062 §C.
///
/// `Ok(None)` when there is nothing to compare: no session, no document, or a
/// session that kept no document. A caller that reads `None` as «yes» is the
/// defect this returns an `Option` to prevent.
pub(crate) fn document_matches(bench: SessionId) -> ApiResult<Option<bool>> {
    with_core(|core| {
        let Some(number) = core.open_conversation else {
            return Ok(None);
        };
        let Some(text) = core.get(bench.id).map(|s| s.original_str().to_string()) else {
            return Ok(None);
        };
        if text.is_empty() {
            return Ok(None);
        }
        Ok(core.vault.conversation_matches(number, &text))
    })
}

// ------------------------------------------------------------------ the inside

/// Give one bench the open session's names, and say how many moved.
fn take_the_names(
    core: &mut crate::session::Core,
    number: u32,
    bench: Option<SessionId>,
) -> u32 {
    let Some(naming) = core.vault.naming_of(number) else {
        return 0;
    };
    let Some(bench) = bench else { return 0 };
    match core.get(bench.id) {
        Some(s) => s.names_again_from(naming) as u32,
        None => 0,
    }
}

fn write_body(
    core: &mut crate::session::Core,
    number: u32,
    body: &crate::conversation::Body,
) -> ApiResult<()> {
    let Some(dir) = core.vault.dir().map(|d| d.to_path_buf()) else {
        return Err(ApiError::PayloadRefused {
            reason: "there is no data directory to keep a session in".to_string(),
        });
    };
    let Some(key) = core.vault.conversation_key(number) else {
        return Err(ApiError::VaultLocked);
    };
    crate::conversation::write(&dir, number, &key, body)
}

fn body(
    core: &mut crate::session::Core,
    number: u32,
) -> ApiResult<Option<crate::conversation::Body>> {
    let Some(dir) = core.vault.dir().map(|d| d.to_path_buf()) else {
        return Ok(None);
    };
    let Some(key) = core.vault.conversation_key(number) else {
        return Ok(None);
    };
    crate::conversation::read(&dir, number, &key)
}

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
    with_core(|core| begin_in(core, name, bench))
}

/// **The birth itself, with the core already in hand.**
///
/// Split out of [`begin`] for rule 55: the door a document enters the preview
/// by is already inside `with_core`, and `with_core` does not nest. The name is
/// cleaned by its caller — the only two are [`begin`], which was handed one by
/// a person, and [`a_session_is_born`], which writes the house's own.
fn begin_in(
    core: &mut crate::session::Core,
    name: String,
    bench: Option<SessionId>,
) -> ApiResult<ConversationRow> {
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
    // **The language is taken at the birth, from the bench that named it.**
    // One place in the core, rather than at «the first document», which is
    // two doors in the screen and two chances to forget. With no bench
    // there is nothing to take and the row stays «never asked».
    let born_with = bench.and_then(|b| core.get(b.id)).map(|s| s.pack_id.clone());
    // **The floor is looked at before the number is spent** — paper 102 §3.
    //
    // The number comes from the vault model's own counter, so a **new** vault
    // in a folder an older one left files in counts from 1 and this function
    // used to write its empty body straight over `sessions/1.zs`. That file
    // cannot be opened with this vault's keys and it is not this window's to
    // destroy: the birth refuses by name instead, and the person's next move
    // is to move the folder or open the vault the file belongs to.
    //
    // Asked here rather than at the write below, because `begin_conversation`
    // spends a number and reseals the vault: a refusal after it would leave a
    // session record whose file was never written, which is the one state
    // «a session that exists in the vault also exists on disk» forbids.
    if let (Some(dir), Some(next)) =
        (core.vault.dir().map(|d| d.to_path_buf()), core.vault.the_next_conversation_number())
    {
        if crate::conversation::bytes_on_disk(&dir, next)?.is_some()
            && !core.session_as_read.contains_key(&next)
        {
            return Err(ApiError::SessionChangedElsewhere);
        }
    }
    let number =
        core.vault
            .begin_conversation(&name, document.as_deref(), born_with.as_deref())?;
    core.open_conversation = Some(number);
    // An empty file, written now rather than at the first turn, so that a
    // session which exists in the vault also exists on disk: a record with
    // no file would be a session whose deletion has nothing to destroy.
    //
    // **Before the names are taken, and the order is now load-bearing**
    // (089 rule 9): taking the names also keeps the document in the
    // preview, which writes this very file. Written afterwards, as it was
    // until 15 October, this empty body overwrote the document that had
    // just been saved — measured, as «the document that waited for a
    // session was lost».
    write_body(core, number, &crate::conversation::Body::default())?;
    // **And its chat is the one this run opened** — rule 68. Nothing is spent
    // here: the body a line above has chat 1 open and no turn in it.
    the_chat_of_this_run(core, number)?;
    let renamed = take_the_names(core, number, bench);
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
        pack_id: born_with,
    })
}

/// **The name a session nobody named carries** — «Session 1», «Session 2»…
///
/// 081, where the owner had the name field at the exit deleted — «أبسط من
/// البساطة ذاتها» — so a press that needs a session gets one called by its own
/// number. The glass spells the same two words in `nameForSession`, and G37
/// measures that the two agree: one of them saying «Sitzung 2» would be a
/// session the send sheet cannot tell from one a person named.
pub(crate) fn a_session_called(number: u32) -> String {
    format!("{A_SESSION_CALLED} {number}")
}

const A_SESSION_CALLED: &str = "Session";

/// **The session the house begins for itself** — rule 55c, the owner's answer
/// of 16 October 2026, and rule 55-و, his answer of 18 October: «نعم» twice.
///
/// A *conversation* is what the person writes to a model. A **session** is the
/// container, and a container exists the moment it holds something — so the
/// instant a document enters the preview with nothing open, one is born. Not at
/// the first message, not at the first exit: those were the two instants this
/// house had, and a document that arrived before either of them had nowhere to
/// take a number from and was kept nowhere.
///
/// **One birth, two causes.** 55-و adds the second: a question that leaves
/// with no document in the app at all (rule 72's surface) is a session too —
/// «the chat without a document is a whole session». The cause is different and
/// the birth is this one function, because a birth is a number spent, a name
/// written, every token of the bench re-derived and the blocks written down,
/// and a second copy of that sequence is a second answer to «what is a
/// session» the day either changes. The second cause is wired at the exits
/// (`ops::a_session_for_what_leaves`), not here.
///
/// **The number is the vault's to hand out**, so it cannot be known before the
/// birth — the name follows it, exactly as it has at the exit door since 081. A
/// rename that fails leaves «Session», which is less than was wanted and still
/// true, and the session is there, which is what the document needed.
///
/// It names the bench on its way through ([`take_the_names`]), which is also
/// where the blocks are written and this very document kept: the birth is the
/// first instant at which a word's token is this session's own.
pub(crate) fn a_session_is_born(
    core: &mut crate::session::Core,
    bench: SessionId,
) -> ApiResult<u32> {
    let row = begin_in(core, A_SESSION_CALLED.to_string(), Some(bench))?;
    core.vault.rename_conversation(row.number, &a_session_called(row.number))?;
    Ok(row.number)
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
        // **The chat the person left behind is over** — rule 68, when this is
        // the first time this run has opened this session.
        the_chat_of_this_run(core, number)?;
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
            pack_id: core.vault.pack_of(number),
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
    Ok(with_core(open_in))
}

/// **The same question, with the core already in hand** — and the one place
/// that answers it.
///
/// A number is held in the core; a **session** is a number *and* a key that
/// opens it. The two come apart for real: the vault locked or replaced, the
/// session forgotten, a data directory changed under a running app. Then the
/// held number names a session this vault does not have — and a caller that
/// trusted the number writes into a file it has no key for.
///
/// **Measured on 16 October**, as rule 55 was built: a bench imported a
/// document while a stale «1» was held from another vault, and the import came
/// back `VaultLocked` — an import refused because of a number nobody could
/// have known was wrong. So the stale number is dropped here rather than
/// answered twice: one fact, one source, and the next document is born into a
/// session that exists.
pub(crate) fn open_in(core: &mut crate::session::Core) -> Option<u32> {
    let held = core.open_conversation?;
    if core.vault.state() == crate::api::VaultState::Unlocked
        && core.vault.conversation_key(held).is_some()
    {
        return Some(held);
    }
    // A shut vault is not an empty one: the number stands and comes back when
    // the key does, which is 064's own promise and why this only forgets a
    // number the **open** vault does not hold.
    if core.vault.state() == crate::api::VaultState::Unlocked {
        core.open_conversation = None;
    }
    None
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
                pack_id: core.vault.pack_of(number),
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
pub(crate) fn record(
    question: String,
    answer: String,
    via: crate::api::TurnVia,
    document: crate::api::TurnDocument,
) -> ApiResult<u32> {
    with_core(|core| {
        let Some(number) = core.open_conversation else {
            return Err(ApiError::PayloadRefused {
                reason: "there is no session open to write to".to_string(),
            });
        };
        // **No anchor from this door.** It is the by-hand door, called with two
        // strings and no payload, so there is no saved document it can name
        // and inventing one would be the guess rule 69's number exists to
        // refuse.
        record_in(
            core,
            number,
            Exchange { question, answer, allowed: Vec::new(), via, document, kept: None },
        )
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
///
/// `via` is what answered, and it is a parameter rather than something read
/// from the core here: the only places that know are the doors, and a value
/// worked out at this depth would be «whatever is configured now» about an
/// exchange that has already happened.
///
/// **One struct and not six parameters**, and clippy's count is the smaller
/// half of why: `question` and `answer` are both `String`, and two strings side
/// by side in a call are a swap waiting to happen — a defect that shows itself
/// a month later as an answer standing where the question should be. Named
/// fields cannot be swapped silently.
pub(crate) struct Exchange {
    /// What was asked, in the form it left in.
    pub question: String,
    /// What came back, exactly as it arrived. Empty is a real state: a question
    /// copied out and not yet answered.
    pub answer: String,
    /// The tokens the payload this turn left in was permitted to carry — G9.
    pub allowed: Vec<String>,
    /// Which key answered, or that the person carried it — 075c.
    pub via: crate::api::TurnVia,
    /// What it was about: a file by name, or that the person typed it.
    pub document: crate::api::TurnDocument,
    /// **The saved document the payload carried**, stamped on it when it was
    /// built — rule 69's anchor. It comes from the door for the same reason
    /// `via` does: the door knows what left, and a number worked out at this
    /// depth would be «whatever is in the preview now» about an exchange that
    /// has already happened.
    pub kept: Option<crate::session::KeptHandle>,
}

pub(crate) fn record_in(
    core: &mut crate::session::Core,
    number: u32,
    exchange: Exchange,
) -> ApiResult<u32> {
    let Exchange { question, answer, allowed, via, document, kept } = exchange;
    let mut body = body(core, number)?.unwrap_or_default();
    // **Which chat it belongs to is the file's own answer** — rule 67, and it
    // is taken from the body that is about to be written rather than passed in
    // by a door. A door knows what was asked; the chat a session is in the
    // middle of is the session's fact, and a parameter for it would be one more
    // thing every door has to get right (`via` is a parameter for the opposite
    // reason: only the door knows what answered).
    let chat_number = body.chat_now;
    body.turns.push(crate::conversation::Turn {
        question,
        answer,
        at: crate::vault::model::now_seconds(),
        allowed,
        via,
        document,
        chat_number,
        kept_number: kept.map_or(0, |k| k.number),
        kept_chat: kept.is_some_and(|k| k.chat),
    });
    write_body(core, number, &body)?;
    Ok(body.turns.len() as u32)
}

/// **The request part of a question that carried a document** — 110.
///
/// A first turn's question is the payload as it left: the document, the request
/// line, then the request. Carrying it whole would send the document a second
/// time, which is the one thing rule 67's other half already forbids at the
/// payload's own door — so what travels is what follows the line. A follow-up
/// has no line in it and travels whole, which is also exactly what left.
///
/// **The last line and not the first.** A document may hold these very words
/// itself. Cutting at the first would carry the tail of the document into the
/// next question; cutting at the last can only ever carry *less* of the
/// person's own request. Of the two ways to be wrong, one sends their document
/// and the other sends less of their sentence.
fn the_request_part(question: &str) -> &str {
    const LINE: &str = crate::session::Session::THE_REQUEST_LINE;
    match question.rfind(LINE) {
        Some(at) => &question[at + LINE.len()..],
        None => question,
    }
}

/// **The label on an earlier request, and on an earlier answer.**
///
/// English, like every other string that leaves this device — the payload's own
/// `--- Request ---` says why — and deliberately *not* those two words: the
/// first turn's question **is** a whole payload, `--- Request ---` and all, so
/// a history that labelled it with the same words would hand the model the
/// label twice and nothing to tell one turn's text from the next one's.
const AN_EARLIER_REQUEST: &str = "--- Earlier request ---";
const AN_EARLIER_ANSWER: &str = "--- Earlier answer ---";

/// **The one exchange before, in the form it travelled in** — rule 67 (the
/// owner's «لا أستطيع أن أتابع الشات معه على نفس الموضوع», 17 October 2026),
/// **amended by his ruling of 24 October 2026**: «نوقف إرسال الجلسة أو سياق
/// الجلسة… فقط السؤال السابق مع الإجابة بدون الوثيقة… يكفي لأن الإجابة تُبنى
/// بالتتابع».
///
/// Rule 67 as written on 17 October carried **every** earlier turn of the open
/// chat, so what one chat sent grew with the square of its length: the tenth
/// question carried nine exchanges, and the person paid a provider for every
/// word of it. Since 110 the text is the **previous question and its answer**
/// and nothing older — an answer is built in sequence, and the exchange just
/// before is the context that matters.
///
/// **And never the document.** A first turn's question *is* the payload as it
/// left — document, request line, request (`ingest_answer` says so where it
/// stores it) — so what is carried from such a turn is its request part alone
/// (`the_request_part`).
///
/// **Nothing older is lost**: every earlier turn stays in the sealed session
/// file and is read there (rule 69). What changed is what leaves.
///
/// One entry per side of the one turn, labelled. **One builder, and one door
/// that adds it**: `ops::ask_model`. Both doors send the same payload — the
/// question as it would leave, protected — and the in-app one puts this one
/// exchange on top of it, because the model holds nothing of the chat while a
/// person's own chat holds its thread. `ops::chat_to_take_out` reads this
/// answer for its **tokens and its anchor** (`allowed`, `kept`) and takes its
/// text from the payload itself. One function assembles every history there
/// is, which is what G46 holds.
///
/// **Nothing is restored and nothing is protected again.** What the file holds
/// is what travelled — the question as it left, the answer as it arrived — and
/// a restore here would put the person's own names into the next request,
/// which is the single thing this program exists to prevent. Protecting it
/// again would mint tokens for tokens.
///
/// **Only the open chat.** Rule 68 ends a chat when the person says so or the
/// application closes, and `Turn::chat_number` is where that boundary is
/// written down. A turn from a chat that ended is in the session's room
/// (rule 69) and not in this list.
///
/// No session open, or no file yet: nothing, and that is the truth rather than
/// an absence — a question asked with no session open writes no turn either
/// (`ops::ingest_answer`), so there is nothing earlier for it to carry.
pub(crate) fn the_chat_so_far(core: &mut crate::session::Core) -> ApiResult<TheChatSoFar> {
    let Some(number) = open_in(core) else { return Ok(TheChatSoFar::default()) };
    let Some(body) = body(core, number)? else { return Ok(TheChatSoFar::default()) };
    let mut out = TheChatSoFar::default();
    let its: Vec<&crate::conversation::Turn> =
        body.turns.iter().filter(|t| t.chat_number == body.chat_now).collect();
    // **The text is the one exchange before, and nothing older** — 110. The
    // last turn of the open chat: the question as it left, with the document
    // cut off it, and the answer as it arrived.
    if let Some(turn) = its.last() {
        if !turn.question.trim().is_empty() {
            out.lines.push(format!("{AN_EARLIER_REQUEST}\n{}", the_request_part(&turn.question)));
        }
        if !turn.answer.trim().is_empty() {
            out.lines.push(format!("{AN_EARLIER_ANSWER}\n{}", turn.answer));
        }
    }
    // **The tokens and the anchor are still read over the whole chat** — G9
    // and rule 69, and this is the one place 110 does *not* narrow. What may
    // come back is wider than what stands in the text: an answer the person
    // brings back by hand against the copy may name a token born in the first
    // question, and
    // `an_answer_against_the_chats_own_copy_asks_nothing_new_and_restores_every_name`
    // measures that it comes home in their own name. Narrowing this list with
    // the text reddened that guard at once, which is the measurement that
    // settled the shape: the text narrows, the permission does not.
    for turn in &its {
        for token in &turn.allowed {
            if !out.allowed.contains(token) {
                out.allowed.push(token.clone());
            }
        }
        // **The document this chat began with** — rule 69, the first turn that
        // names one. An answer brought back against the chat's copy belongs
        // under the document the chat began with, and since 110 the copy no
        // longer holds that document's text — so this handle is the whole of
        // what anchors it, and it is read over every turn rather than off the
        // one that is carried.
        if out.kept.is_none() && turn.kept_number > 0 {
            out.kept = Some(crate::session::KeptHandle {
                session: number,
                number: turn.kept_number,
                chat: turn.kept_chat,
            });
        }
    }
    Ok(out)
}

/// **What the open chat holds**: its text, and the tokens it was allowed to
/// carry.
///
/// Two facts from one walk over the turns, in one answer, because they are read
/// together and must agree. A second function for the tokens would walk the
/// same file for the same chat and could be given a different filter — and a
/// follow-up question allowed a token the history never carried would restore a
/// name the model was never shown.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct TheChatSoFar {
    /// **One entry per side of the one exchange before** — 110. The previous
    /// question, with the document cut off it, and the previous answer.
    ///
    /// Read by `ask_model` alone: the clipboard door takes the current point
    /// and not the history (the owner, 24 October 2026).
    ///
    /// It was every turn of the open chat until 24 October 2026 (rule 67 as
    /// first written), which is why the field is a list and not a pair: the
    /// shape outlived the law, and a pair would have to be unpacked again the
    /// day a ruling widens it.
    pub lines: Vec<String>,
    /// **Every token the turns of this chat were allowed to carry** — G9.
    ///
    /// What may come back in the answer to the next question, which is wider
    /// than what stands in that question: three words leave, and the answer to
    /// them names what the first request showed the model.
    pub allowed: Vec<String>,
    /// **The saved document this chat began with** — rule 69's anchor for a
    /// copy of the chat. `None` when no turn of it named one.
    pub kept: Option<crate::session::KeptHandle>,
}

/// **End the chat** — rule 68, by the person's own hand.
///
/// The number is spent: `chat_now` goes up and never comes back, so the turns
/// that were in it are not in the open one and the next question carries none
/// of them. The turns themselves **stay**: a chat that ended is not a chat that
/// was deleted, and rule 69 shows them under the document in the session's
/// room.
///
/// Answers with the number of the chat that is open now, so a screen draws the
/// boundary from the core's own count instead of adding one for itself.
pub(crate) fn end_the_chat(number: u32) -> ApiResult<u32> {
    with_core(|core| {
        let mut body = body(core, number)?.unwrap_or_default();
        body.chat_now = body.chat_now.saturating_add(1);
        let now = body.chat_now;
        write_body(core, number, &body)?;
        Ok(now)
    })
}

/// **Which chat of this session is open** — the number every row is compared
/// against.
///
/// A session with no file yet is in chat 1: nothing has been written, so the
/// first chat is the one that is open. Asked of the file and nowhere else, so
/// a screen and the next question cannot disagree about where the boundary is.
pub(crate) fn the_open_chat(number: u32) -> ApiResult<u32> {
    with_core(|core| Ok(body(core, number)?.map_or(1, |b| b.chat_now)))
}

/// **A chat begins when a session is opened in a new run** — rule 68, the half
/// the person does not do by hand.
///
/// «The chat ends when the application closes», so a run that did not open this
/// session must not find a chat open in it. `Core::chats_opened` is empty when
/// the process starts, which is the whole of how that is kept: the first
/// opening here spends the number the last run was writing into, and a second
/// opening of the same session in the same run finds it in the list and changes
/// nothing — looking at another session and coming back is neither of the two
/// things rule 68 says ends a chat, and neither is an auto-lock.
///
/// **A chat with no turn in it is not spent**, which is why there is no special
/// case for a newborn session: its file was written a line ago with chat 1 open
/// and nothing in it, and nothing is what there is to end. A person who typed a
/// question and never sent it has had no chat.
fn the_chat_of_this_run(core: &mut crate::session::Core, number: u32) -> ApiResult<()> {
    if core.chats_opened.contains(&number) {
        return Ok(());
    }
    if let Some(mut body) = body(core, number)? {
        if body.turns.iter().any(|t| t.chat_number == body.chat_now) {
            body.chat_now = body.chat_now.saturating_add(1);
            // Written before the number is remembered, so a write that fails
            // is tried again at the next opening rather than being recorded as
            // done: remembering first would leave the previous run's chat open
            // for ever, and a new question would carry turns the person
            // finished with yesterday.
            write_body(core, number, &body)?;
        }
    }
    core.chats_opened.push(number);
    Ok(())
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
        // **Read, both of them** — the bench immutably so that the vault can be
        // held beside it. `core.get` takes the core mutably and would have made
        // these two borrows a conflict; nothing here writes, so nothing here
        // needs a mutable borrow.
        let store: &crate::tokens::TokenStore = match bench.and_then(|b| core.sessions_get(b.id)) {
            Some(s) => &s.tokens,
            None => &nothing,
        };
        // **And the blocks behind it** — the lead's ruling of 15 October. A
        // turn read a week later has no bench to ask, and every word it
        // carries is a block (089 rule 1). The question is built here, where
        // the vault is in hand, and only a question crosses into `tokens`.
        let vault = &core.vault;
        let ask = |token: &str| vault.block_value_for(token);
        let values = crate::tokens::Values::and_blocks(store, &ask);
        let mut rows = Vec::new();
        for turn in &body.turns {
            let question = crate::tokens::restore(&turn.question, &values, &turn.allowed);
            let answer = crate::tokens::restore(&turn.answer, &values, &turn.allowed);
            let mut unresolved = question.unknown;
            for name in answer.unknown {
                if !unresolved.contains(&name) {
                    unresolved.push(name);
                }
            }
            rows.push(crate::api::TurnRow {
                via: turn.via.clone(),
                document: turn.document.clone(),
                chat_number: turn.chat_number,
                // **The number, spelled by the one function that spells it** —
                // rule 69. `None` is «this exchange carried no document», which
                // is a follow-up question's truth and an old turn's.
                kept_handle: (turn.kept_number > 0).then(|| {
                    crate::conversation::Body::handle_spelling(turn.kept_number, turn.kept_chat)
                }),
                // **Both sides as they are stored, beside both sides restored**
                // — rule 66: the chat draws every turn **coded**, and the
                // bubble behind «Show the text» draws it restored. One call
                // gives a screen both, out of one read of one file, so the
                // thread and the bubble cannot be two different exchanges.
                question_as_it_left: turn.question.clone(),
                answer_as_written: turn.answer.clone(),
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

/// **The session's language, written by number** — 080, and the whole of it is
/// the refusal and one write.
///
/// `known` rather than `has_rules`: 041-Q settled that a language with no
/// dictionary of its own is still a language — the general rules, the vault and
/// the person's own list do the work — so what is refused here is a code this
/// build has never heard of, and nothing else.
pub(crate) fn set_pack(number: u32, pack_id: String) -> ApiResult<()> {
    if !crate::scanner::languages::known(&pack_id) {
        return Err(ApiError::NotFound {
            reason: format!("«{pack_id}» is not a language this build knows"),
        });
    }
    with_core(|core| core.vault.set_pack(number, &pack_id))
}

// ------------------------------------------------- the documents in the preview

/// **Keep what is in the preview** — 089 rule 9, the owner's rule of 15 October:
/// «عنصرنا هو البلوك لا المستند».
///
/// Documents are not saved — their owner has them on his own disk, unencrypted
/// — with **one exception**: the document in the preview that has not left it,
/// with the decisions made on it, so that a power cut finds it as it was left.
/// It is sealed under the conversation's key, in the conversation's own file,
/// exactly as the questions are.
///
/// **Called after the scan, at both import doors.** The marks the scan made are
/// decisions too: a copy saved before the scan would re-open as a document
/// nobody had looked at.
///
/// **Nothing happens without a conversation**, because the number is a number
/// *in* a conversation and there is nowhere else to write it. The birth asks
/// again (`take_the_names`), so a document opened before the session existed is
/// kept the moment it does rather than lost — the same shape the blocks follow.
///
/// **`doc` or `chat` is read, not guessed:** `import_document` puts the file's
/// name on the bench and `import_text` leaves it empty, so an empty name is a
/// text that was written or pasted into the preview and a name is a file pulled
/// from the computer. Two sequences, as the owner wrote them.
/// **A cover the person's own hand put on the request** — rule 55-ز's half of
/// «an act worth keeping», asked in one place so the birth and the write
/// cannot disagree about what one is.
fn the_hand_covered_the_request(s: &crate::session::Session) -> bool {
    s.question_protections.iter().any(|p| p.source == crate::api::Source::Hand)
}

/// One protection, as the session file keeps it. The document's covers and the
/// request's are the same shape in two different strings' offsets, so they are
/// written by one hand here as they are encoded by one layout there.
fn a_kept_cover(p: &crate::session::Protection) -> crate::conversation::KeptMark {
    crate::conversation::KeptMark {
        start: p.start.min(u32::MAX as usize) as u32,
        end: p.end.min(u32::MAX as usize) as u32,
        token: p.token.clone(),
        kind: p.kind,
        scope: p.scope,
        source: p.source,
        detail: p.source_detail.clone(),
        decided: p.decided,
        orphaned: p.orphaned,
    }
}

pub(crate) fn keep_the_preview(core: &mut crate::session::Core, bench: u32) -> ApiResult<()> {
    // **Nothing worth keeping, nothing to keep — and nothing to be born
    // either.** One question for both facts, asked once: «no empty sessions»
    // (rule 55) and «nothing to save» are the same question, and a second copy
    // of it is a second chance for the list to hold a session holding nothing.
    //
    // **Two acts are worth keeping, since rule 55-ز** (the owner's «نعم» of
    // 22 October 2026): a document in the preview, **or** a cover the person's
    // own hand put on the request. Until then this asked only about the
    // document's text — a condition that named one concrete thing where the
    // rule means «anything the person has done here» — and a bench whose whole
    // work was a typed request wrote nothing at all: not the blocks, because
    // the bench never took a session's naming, and not the file, because this
    // returned above. Thirteen minutes of the owner's own work, twice, with
    // «Protected as …» on both glasses.
    //
    // **The hand's covers and not the scan's**, and that boundary is pinned:
    // `set_question` protects what the scan finds the instant a sentence is
    // typed, so a session born of *that* would be a session born of typing —
    // which is the one thing rule 55 forbids, and what
    // `a_question_that_never_leaves_is_born_into_nothing` has measured since
    // rule 55-و. A hand is a decision; a scan is a reading.
    //
    // Trimmed, because `import_text` itself reads a preview of white space as
    // no text at all — a person who opened an empty preview has not started
    // anything.
    let worth_keeping = core
        .sessions_get(bench)
        .is_some_and(|s| !s.original_str().trim().is_empty() || the_hand_covered_the_request(s));
    if !worth_keeping {
        return Ok(());
    }
    let number = match open_in(core) {
        Some(number) => number,
        // **The session is born here** — rule 55c. The birth keeps this
        // document on its way through, and the rest of this function writes it
        // again: the same number, the same marks, no number spent twice. An
        // early return instead would be this function trusting what another
        // one did, which is the coupling this house pays for later.
        //
        // With no vault open there is no key to seal a session with, so the
        // document waits exactly as its blocks do — and the import it arrived
        // by is never refused because a session could not be born.
        None => match a_session_is_born(core, SessionId { id: bench }) {
            Ok(number) => number,
            Err(ApiError::VaultLocked) => return Ok(()),
            Err(other) => return Err(other),
        },
    };
    // **A document is in one session's list.** The copy exists *because* the
    // document is in the preview, so it lives wherever the preview's session
    // is: when the bench moves — a session begun by hand over an open document,
    // another one entered from the list — the copy moves with it rather than
    // standing in two lists at once (measured, before this: one document in
    // three). The number it had stays spent in the session it leaves, because
    // `take_number` only ever goes up.
    let moved = core.sessions_get(bench).and_then(|s| s.kept).filter(|k| k.session != number);
    if let Some(gone) = moved {
        take_the_copy_out(core, gone);
        if let Some(s) = core.get(bench) {
            s.kept = None;
        }
    }
    let Some(s) = core.sessions_get(bench) else { return Ok(()) };
    // **Written again on every act, not once when the document arrived.** «A
    // power cut finds it as it was left» is a promise about the *decisions*,
    // and a copy written once would hold the state the document had before the
    // person did anything to it. So this is called wherever a decision is
    // written down — the same places the blocks are written
    // (`ops::the_decisions_are_written`) — and it replaces the copy's marks
    // rather than making a second document: the number this bench already
    // holds is the one it keeps.
    let already = s.kept;
    let chat = already.map(|k| k.chat).unwrap_or_else(|| s.doc_name.is_empty());
    let kept_now = crate::conversation::Kept {
        // Filled in below, once the body says what the next number is.
        number: 0,
        chat,
        name: s.doc_name.clone(),
        text: s.original_str().to_string(),
        kind: s.doc_kind,
        pages: s.pages,
        bytes: s.doc_bytes,
        readable: s.readable,
        marks: s.protections.iter().map(a_kept_cover).collect(),
        dismissed: s.dismissed.iter().map(|d| d.value.expose().to_string()).collect(),
        at: crate::vault::model::now_seconds(),
        // **And the request, with its own covers** — rule 55-ز, format 7. It
        // is kept whether or not there is a document above it: the two are one
        // bench and one act, and a record that held only the document would
        // lose the hand's work in the box the moment the window closed.
        request: s.question.expose().to_string(),
        request_marks: s.question_protections.iter().map(a_kept_cover).collect(),
    };
    let mut body = body(core, number)?.unwrap_or_default();
    let given = match already {
        Some(handle) => handle.number,
        None => body.take_number(chat),
    };
    let fresh = crate::conversation::Kept { number: given, ..kept_now };
    match body.kept.iter_mut().find(|k| k.number == given && k.chat == chat) {
        // The same document, as it stands now. `at` is kept from the first
        // save: it is when this document came into the preview, and a list
        // ordered by it must not reshuffle itself every time a word is
        // protected.
        Some(kept) => {
            let at = kept.at;
            *kept = crate::conversation::Kept { at, ..fresh };
        }
        None => body.kept.push(fresh),
    }
    write_body(core, number, &body)?;
    if let Some(s) = core.get(bench) {
        s.kept = Some(crate::session::KeptHandle { session: number, number: given, chat });
    }
    Ok(())
}

/// **It left by a door: the copy is deleted and the number is retired** — rule 9.
///
/// Send, copy, pull, PDF: four presses on the glass, and in the core the doors
/// that take text out of the machine — G28's own census, which reads them from
/// what they do: `payload_to_take_out`, `send`, `ask_model` and, since rule 65,
/// `chat_to_take_out`. Its **blocks stay in the vault**: what leaves the
/// conversation is the copy of the document, never what the person protected.
///
/// **Three of the four call this, and the fourth is named for its reason.**
/// `chat_to_take_out` hands out the turns of a chat, and every one of them left
/// this machine through one of the other three — which took the preview's copy
/// with it then. Calling this there would delete the copy of whatever document
/// is on the bench **now**, which may be one that has never left: measured as a
/// document losing its decisions because the person copied an older chat.
///
/// The number is retired by never being handed out again: `Body::take_number`
/// only goes up, so `doc1` is spent for ever and a stale reference to it cannot
/// land on another document.
///
/// Infallible on purpose. The text has already left the machine by the time
/// this runs, and a refusal here would say «it did not leave» about something
/// that did. A failed write leaves the copy in the file, where the next exit or
/// the next read finds it — never a lie about where the text is.
pub(crate) fn the_preview_has_left(core: &mut crate::session::Core, bench: u32) {
    let Some(handle) = core.sessions_get(bench).and_then(|s| s.kept) else { return };
    take_the_copy_out(core, handle);
    if let Some(s) = core.get(bench) {
        s.kept = None;
    }
}

/// **The one hand that takes a saved document out of a list.**
///
/// Two acts reach it and they are the same act — the copy is no longer in this
/// list: the text left the machine by a door (`the_preview_has_left`), or the
/// bench moved to another session and took the copy with it
/// (`keep_the_preview`). A second place that could remove a person's preview
/// would be a deletion nobody measures, which is the rule the blocks have for
/// the same reason (G35, G36).
///
/// **The handle's own session, not the open one.** They are the same at a door
/// and different the instant a bench moves, and the list the copy is in is the
/// one it has to be taken out of.
fn take_the_copy_out(core: &mut crate::session::Core, handle: crate::session::KeptHandle) {
    if let Ok(Some(mut body)) = body(core, handle.session) {
        let before = body.kept.len();
        body.kept.retain(|k| !(k.number == handle.number && k.chat == handle.chat));
        if body.kept.len() != before {
            let _ = write_body(core, handle.session, &body);
        }
    }
}

/// **The documents one conversation is holding**, newest first.
///
/// A count and a handle and a name — never the text, which is what the
/// preview is for. The rows are the core's: a screen that worked out «doc3»
/// for itself would be a second place that knows how a number becomes a name.
pub(crate) fn kept_documents(number: u32) -> ApiResult<Vec<crate::api::KeptRow>> {
    with_core(|core| {
        let Some(body) = body(core, number)? else { return Ok(Vec::new()) };
        let mut rows: Vec<crate::api::KeptRow> = body
            .kept
            .iter()
            .map(|k| crate::api::KeptRow {
                number: k.number,
                chat: k.chat,
                handle: crate::conversation::Body::handle_of(k),
                name: k.name.clone(),
                at: k.at,
                // **The document's covers and the request's both** — rule
                // 55-ز. The row exists so a person choosing between two saved
                // copies is choosing between two states of *work*, and a
                // typed-only copy's whole work is in its request: counting the
                // document's marks alone said «0 protected places» about the
                // one the person had just protected by hand.
                protected: k
                    .marks
                    .len()
                    .saturating_add(k.request_marks.len())
                    .min(u32::MAX as usize) as u32,
            })
            .collect();
        rows.sort_by(|a, b| b.at.cmp(&a.at).then(b.number.cmp(&a.number)));
        Ok(rows)
    })
}

/// **Rename one** — the name changes and the number never does (rule 9).
pub(crate) fn rename_kept(number: u32, which: u32, chat: bool, name: String) -> ApiResult<()> {
    let name = clean(&name)?;
    with_core(|core| {
        let Some(mut body) = body(core, number)? else {
            return Err(ApiError::NotFound {
                reason: format!("session {number} holds no documents"),
            });
        };
        let Some(kept) = body.kept.iter_mut().find(|k| k.number == which && k.chat == chat) else {
            return Err(ApiError::NotFound {
                reason: format!("this session is not holding {}{which}", if chat { "chat" } else { "doc" }),
            });
        };
        kept.name = name;
        write_body(core, number, &body)
    })
}

/// **Open one in the preview, as it was left** — rule 9.
///
/// The text goes back on the bench with every decision that was on it, and
/// **nothing is scanned**: a rescan would ask again about the words the person
/// answered, which is the whole of what «as it was left» rules out. The token
/// store is rebuilt from the marks and the text — the value of a mark is the
/// text under it, so there is one copy of every value and no second place for
/// them to disagree.
pub(crate) fn open_kept(number: u32, which: u32, chat: bool, bench: SessionId) -> ApiResult<()> {
    with_core(|core| {
        let Some(body) = body(core, number)? else {
            return Err(ApiError::NotFound {
                reason: format!("session {number} holds no documents"),
            });
        };
        let Some(kept) = body.kept.iter().find(|k| k.number == which && k.chat == chat).cloned() else {
            return Err(ApiError::NotFound {
                reason: format!("this session is not holding {}{which}", if chat { "chat" } else { "doc" }),
            });
        };
        let Some(s) = core.get(bench.id) else { return Err(ApiError::InvalidSession) };
        s.put_back_the_preview(&kept);
        s.kept = Some(crate::session::KeptHandle { session: number, number: which, chat });
        Ok(())
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
    let moved = match core.get(bench.id) {
        Some(s) => s.names_again_from(naming) as u32,
        None => 0,
    };
    // **And the blocks are written here, at the birth** — 089 rule 1.
    //
    // This is the first instant at which a word's token is the conversation's
    // own: everything protected before it wore a random name and has just been
    // renamed. `blocks_from_this_bench` writes nothing for a bench that does
    // not name from the vault's key, so a word protected before this moment
    // has waited for it rather than been lost — which is why the owner's
    // letter, protected whole before the session was born, is a vault full of
    // blocks one line later.
    // **The blocks and the preview's copy, in the one call that writes both** —
    // 089 rules 1–2 and rule 9. This is the instant a conversation exists: a
    // document opened before it had no conversation to be numbered in, and a
    // word protected before it wore a name that has just been re-derived.
    //
    // A document that is leaving as the session is born spends a number and
    // loses it again at the exit a line later, which is the rule as the owner
    // wrote it: a number is spent for ever, and what left is not kept.
    crate::ops::the_decisions_are_written(core, bench.id);
    moved
}

/// **Replace this session's file, and only what this run has read** — paper
/// 102 §3, the session file's own `ensure_disk_unchanged`.
///
/// The vault has refused to write over bytes it had not read since 050/A, and
/// this file was replaced whatever was there.
///
/// **The example that stood here was read wrong, and the owner named its author
/// on 24 October 2026.** It said: `sessions/1.zs` held a document and eleven
/// decisions at 21:35:03 and held an empty body at 21:35:11 while `vault.zv`
/// did not move at all, so one of two windows wrote a body it had not read. In
/// that same second he had saved a protected PDF — «أنا حفظت جميع الملفات عن
/// طريق حفظ نسخة PDF» — and the Windows session's entry of 24 October
/// (commit `e36c92c`) records the 16 751-byte z-pdf written into
/// Documents\ZPrivacy at exactly 21:35:11. The PDF is a door, 089 rule 9 takes
/// the preview's copy out at every door, and a session holding no turns and no
/// copy **is** an empty body — `the_manual_door_takes_it_out` measures that
/// door doing it. Nothing was lost there.
///
/// **The guard below is not weakened by losing that example**, because it
/// answers a class and not an incident: a body written over bytes this run
/// never read is another owner's file whatever happened in October.
///
/// **And this is what it reaches, said here because nobody had said it:** every
/// writer of a body reads the file first, inside this same lock — `body()` a
/// line or two above each call of this function — so what the guard catches is
/// a read that went **stale between a read and a write**, and never a press
/// that reads as it writes. A test built to drive it the other way round, by
/// moving the file before the act, would assert a refusal that cannot happen
/// and stay green for ever; the shape is held by a census instead, read by gate
/// `G36`: this is the only function in `z_core/src` that calls
/// `crate::conversation::write`. A guard whose stated reason turns out to be
/// something else is a guard nobody can reason about later, which is why the
/// reason is corrected here rather than quietly left standing.
///
/// So a write is allowed in exactly two states, and in no third:
///
///   * the bytes on the disk are the bytes this run last read for this number
///     — the ordinary act, where `body()` read a moment ago inside this very
///     lock;
///   * there is **nothing** on the disk and this run has read nothing either —
///     a birth, which creates and destroys nothing.
///
/// Anything else is another owner's file: another copy of Z Privacy that wrote
/// in between, or a file an older vault left at this number in this folder. It
/// is refused by name (`SessionChangedElsewhere`), and the refusal reaches the
/// glass — §2 — rather than being swallowed by the one caller that discards it.
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
    let on_disk = crate::conversation::bytes_on_disk(&dir, number)?;
    match core.session_as_read.get(&number) {
        // Read, and nothing has moved since: this body is built on what is
        // there. (`None` as a value is «there was no file», which is a read
        // too — a birth that read an empty floor may write it.)
        Some(as_read) if *as_read == on_disk => {}
        // Nothing read, nothing there: a birth writes its first body.
        None if on_disk.is_none() => {}
        _ => return Err(ApiError::SessionChangedElsewhere),
    }
    let sealed = crate::conversation::write(&dir, number, &key, body)?;
    // What this run has read of that file is now what it just wrote, so the
    // next act compares against the truth and not against a stale read.
    core.session_as_read.insert(number, Some(sealed));
    Ok(())
}

/// **Read this session's file, and remember what was there** — the other half
/// of the guard above: a body is handed to a caller together with the fact
/// that these were the bytes it came from.
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
    match crate::conversation::read(&dir, number, &key)? {
        Some((body, sealed)) => {
            core.session_as_read.insert(number, Some(sealed));
            Ok(Some(body))
        }
        None => {
            core.session_as_read.insert(number, None);
            Ok(None)
        }
    }
}

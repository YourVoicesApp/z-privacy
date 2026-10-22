// **What the hand protected must reach the disk, and what the disk refused
// must reach the glass** — paper 102, from the two-window eye round on the
// `78988fd` artefacts (the tenth report in `docs/INBOX/to-linux.md`, with the
// owner's own minute table).
//
// Three faults were measured there with a one-second size-and-mtime watch over
// a test folder, and this file pins all three **before** anything is fixed: a
// pin that cannot be shown red at the base commit is a claim and not a
// measurement.
//
// **The instrument is the one the owner's machine used: the bytes of
// `vault.zv` and of `sessions/<n>.zs`.** Every one of these faults is a fault
// of the disk — the core's memory was right the whole evening, which is why
// the glass said «Protected as …» and meant it. A test that asked the core
// what it holds would therefore have passed on all three, and three of them
// are what the person loses when the window closes.
//
// Each test states the invariant it holds the product to, not the mechanism:
// «either the word is on the disk or the press said it is not» is true of a
// cure that writes and of a cure that refuses out loud, and this file does not
// choose between them for the fix.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for the disk to be measured";

/// A document with two names no dictionary knows, so a hand is the only thing
/// that can protect them — the shape of the owner's own round.
const DOC: &str = "Payroll run, February\nPrepared by: Hedvig Palmgren\nChecked by: Ingmar Takala\nAmount: 42 500\n";

/// What the person types with no document above it. «Rückruf» is in no list we
/// ship: the automatic scan does not offer it, so a token over it is the hand's
/// own work and nothing else's.
const REQUEST: &str = "Herr Thomas Müller bittet um Rückruf";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

/// **Every bench this file opened**, so that a test can be run after one that
/// failed.
///
/// The core holds its benches for the life of the process, and a bench with a
/// document on it is what `conversation_begin` refuses to be asked past
/// (064f). A test that panicked never reached its own close, so without this
/// the *next* test in the file reads a refusal about somebody else's document
/// — which is how the first run of this file reported the wrong red.
static BENCHES: OnceLock<Mutex<Vec<SessionId>>> = OnceLock::new();

fn benches() -> MutexGuard<'static, Vec<SessionId>> {
    match BENCHES.get_or_init(|| Mutex::new(Vec::new())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

/// A bench, remembered so it can be closed whatever this test does next.
fn a_bench() -> SessionId {
    let s = open_session(None, "de".to_string()).expect("a bench");
    benches().push(s);
    s
}

fn close_every_bench() {
    let open: Vec<SessionId> = benches().drain(..).collect();
    for s in open {
        let _ = close_session(s);
    }
}

/// A folder of this test's own, with a vault in it, and the folder handed back
/// so the file can be read as the owner's watch read it.
fn fresh_vault(name: &str) -> PathBuf {
    close_every_bench();
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-disk-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("the data directory");
    vault_create_with_passphrase(PASS.to_string()).expect("a vault");
    dir
}

fn vault_file(dir: &Path) -> PathBuf {
    dir.join("vault.zv")
}

fn session_file(dir: &Path, number: u32) -> PathBuf {
    dir.join("sessions").join(format!("{number}.zs"))
}

/// The bytes of a file that may not exist yet. `None` is «there is nothing
/// there», which is a state this file measures rather than an error.
fn bytes_of(path: &Path) -> Option<Vec<u8>> {
    std::fs::read(path).ok()
}

/// A span over a text, by the word's own characters, in the UTF-16 units the
/// api speaks.
fn span_of(whole: &str, word: &str) -> Span {
    let at = whole.find(word).expect("the word is in the text");
    let start = whole[..at].encode_utf16().count() as u32;
    Span { start, end: start + word.encode_utf16().count() as u32 }
}

/// **How many words the vault on the disk keeps as blocks.**
///
/// Asked by closing the vault and opening it again, because that is the one
/// way this api re-reads the file: a count taken without it is the count this
/// copy holds in memory, which is the one thing these faults never put in doubt.
fn blocks_on_disk() -> u32 {
    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    vault_snapshot().expect("the vault room").block_count
}

// ------------------------------------- R1 · what the hand typed and protected

/// **R1 — a hand protection in the request reaches the vault.**
///
/// The owner's round 1: no document, a sentence typed in the one box, one word
/// protected by hand in each of two windows, «Protected as __Z_…_CUSTOM_…__»
/// on both glasses — and not one byte written in thirteen minutes.
///
/// A session is open before the bench is made, on purpose: that is the state
/// the evening was measured in, and the state in which nothing is ever written
/// rather than written late — the bench never takes the session's naming, so
/// the words never become blocks at all (rule 54-أ, and 089 rule 1).
#[test]
fn a_hand_protection_in_the_request_reaches_the_vault() {
    let _g = serial();
    let dir = fresh_vault("request");
    conversation_begin("one".to_string(), None).expect("a session of the owner's own");
    let s = a_bench();
    set_question(s, REQUEST.to_string()).expect("the request");

    let before = bytes_of(&vault_file(&dir));
    let outcome = protect(s, span_of(REQUEST, "Rückruf"), Scope::Conversation, Kind::Person)
        .expect("the hand in the request");
    let after = bytes_of(&vault_file(&dir));

    assert!(
        matches!(outcome, ProtectOutcome::Applied { .. }),
        "the press did not protect at all, so this file is measuring the wrong thing: {outcome:?}"
    );
    // The bytes are compared and never printed: a failure here says what did
    // not happen, and a vault's ciphertext in a test log is noise at best.
    assert!(
        before != after,
        "«Protected as …» was answered and `vault.zv` did not move: the word the hand \
         protected in the request is in no block, which is rule 54-أ and 089 rule 1 both"
    );
    assert!(
        blocks_on_disk() > 0,
        "the vault on the disk holds no block at all after a hand protection"
    );
}

/// **R1, the other half — what was typed survives the window being closed.**
///
/// «Documents are saved, typed text is not» was the owner's first sentence of
/// the night. The session record has no field for the request or for its
/// protections, so a typed-only session is not kept by the writer that keeps
/// documents: this measures the person's side of that, which is that the work
/// is in the session after the bench is closed.
#[test]
fn a_typed_request_that_was_protected_survives_the_close() {
    let _g = serial();
    let dir = fresh_vault("survives");
    let row = conversation_begin("one".to_string(), None).expect("a session");
    let s = a_bench();
    set_question(s, REQUEST.to_string()).expect("the request");
    protect(s, span_of(REQUEST, "Rückruf"), Scope::Conversation, Kind::Person)
        .expect("the hand in the request");

    close_session(s).expect("the window closes");

    assert!(
        bytes_of(&session_file(&dir, row.number)).is_some(),
        "session {} has no file on the disk at all",
        row.number
    );
    let kept = kept_documents(row.number).expect("the session's own list");
    assert!(
        !kept.is_empty(),
        "the session kept nothing of a request that was typed and protected in it, \
         so closing the window took the work with it"
    );
}

/// **And it comes back as a request, into the box it was typed in** — rule
/// 55-ز's other half: «survives a close» is a promise to a person, and a
/// promise kept only on the disk is kept to nobody.
///
/// The whole way round, through the doors the glass uses: typed, protected by
/// hand, the bench closed, the session entered again, the kept copy opened on
/// a new bench — and the request is in the request, with its cover on it and
/// the token it had.
#[test]
fn the_kept_request_comes_back_into_the_box_with_its_cover() {
    let _g = serial();
    let dir = fresh_vault("comes-back");
    let row = conversation_begin("one".to_string(), None).expect("a session");
    let s = a_bench();
    set_question(s, REQUEST.to_string()).expect("the request");
    let applied = protect(s, span_of(REQUEST, "Rückruf"), Scope::Conversation, Kind::Person)
        .expect("the hand in the request");
    let token = match applied {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("the hand protected nothing: {other:?}"),
    };
    assert!(
        bytes_of(&session_file(&dir, row.number)).is_some(),
        "the session has no file to come back from"
    );
    close_session(s).expect("the window closes");

    let kept = kept_documents(row.number).expect("the list");
    let it = kept.first().expect("the typed request is in the session's list");
    assert!(it.chat, "a typed request was kept as a file, which it never was");
    assert!(it.protected > 0, "the list says nothing was protected on it");

    let again = a_bench();
    open_kept_document(row.number, it.number, it.chat, again).expect("open it again");
    let back = question(again).expect("the request as it came back");
    assert!(
        back.text.contains(&token),
        "the request came back without the token the hand put in it: «{}»",
        back.text
    );
    assert!(
        !back.text.contains("Rückruf"),
        "the word the hand covered came back in the clear: «{}»",
        back.text
    );
}

// --------------------------------- R2 and R3 · a copy whose vault fell behind

/// A bench with a document on it, in a folder where **another copy of this
/// program has since written an older state of the vault** — the two-window
/// case, reproduced through the file rather than through a second process:
/// what makes a write refuse is that the bytes on the disk are not the bytes
/// this copy last wrote, and an earlier state of this very vault is exactly
/// what the other window would have written.
fn a_copy_whose_vault_fell_behind(name: &str) -> (PathBuf, SessionId) {
    let dir = fresh_vault(name);
    let s = a_bench();
    import_text(s, DOC.to_string()).expect("the document");
    protect(s, span_of(DOC, "Palmgren"), Scope::Conversation, Kind::Person).expect("one hand");

    let aside = dir.join("what-the-other-copy-still-holds");
    std::fs::copy(vault_file(&dir), &aside).expect("the other copy's state");
    protect(s, span_of(DOC, "Takala"), Scope::Conversation, Kind::Person).expect("another hand");
    std::fs::copy(&aside, vault_file(&dir)).expect("the other copy writes");

    (dir, s)
}

/// **R2 — a press whose vault was refused may not answer «protected».**
///
/// Measured: twenty-four minutes of work in B, «Protected as …, in 5 places»
/// on the glass, eighteen tokens in the panel, and `vault.zv` untouched. The
/// refusal exists and is published — «Another copy of Z Privacy changed this
/// vault…» — and it never reached the glass, because the block write answers
/// a count and `0` means both «nothing new» and «the disk refused me».
///
/// The invariant, which does not choose the cure: after the press, either the
/// vault on the disk moved, or the press said it did not.
#[test]
fn a_press_whose_vault_was_refused_does_not_answer_protected() {
    let _g = serial();
    let (dir, s) = a_copy_whose_vault_fell_behind("refused");

    let before = bytes_of(&vault_file(&dir));
    let said = protect(s, span_of(DOC, "42 500"), Scope::Conversation, Kind::Custom);
    let after = bytes_of(&vault_file(&dir));

    // **Where «the press said it did not land» lives**: the verdict the glass
    // reads on every act, and not an error returned once. The press did
    // protect, in memory, and saying otherwise would be the opposite untruth;
    // what the person needs is the one thing they can act on, standing until
    // it is no longer true.
    let verdict = workspace_snapshot(s).expect("the screen's one read").the_disk_refused;
    assert!(
        matches!(verdict, Some(ApiError::VaultChangedElsewhere)) || before != after,
        "the press answered {said:?} with verdict {verdict:?} while the vault on the disk \
         did not move: the person is told a word is protected for ever by a file that never \
         heard of it"
    );
}

/// **And the verdict clears when the disk is healed** — the other way round,
/// so the guard above cannot be green for the wrong reason.
///
/// A copy heals by locking and unlocking: `lock` drops the sealed envelope, so
/// the next look re-reads the file (`load_sealed` returns early while it holds
/// one, which is why nothing else heals it). After that a press must land —
/// and the verdict must go.
#[test]
fn the_verdict_goes_when_the_copy_has_read_the_file_again() {
    let _g = serial();
    let (dir, s) = a_copy_whose_vault_fell_behind("healed");
    let _ = protect(s, span_of(DOC, "42 500"), Scope::Conversation, Kind::Custom);
    assert!(
        workspace_snapshot(s).expect("one read").the_disk_refused.is_some(),
        "nothing was refused, so this test is not measuring a heal"
    );

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    // The bench's session was entered again by the unlock (the number a lock
    // keeps, 18 October), so this press writes into the same session file.
    let before = bytes_of(&vault_file(&dir));
    protect(s, span_of(DOC, "Takala"), Scope::Conversation, Kind::Person).expect("a press");
    let after = bytes_of(&vault_file(&dir));

    assert!(before != after, "the press after the heal still wrote nothing to the vault");
    assert!(
        workspace_snapshot(s).expect("one read").the_disk_refused.is_none(),
        "the verdict outlived the refusal it was about, so the band would stand for ever"
    );
}

/// **R3 — the two halves of one act land together or not at all.**
///
/// The sharpest of the three, because the glass stays green: the session copy
/// was written while the blocks were refused, so `sessions/1.zs` names
/// protected places whose blocks are absent from `vault.zv` — and
/// `open_kept` rebuilds the token store from the marks and the text, so the
/// document comes back **showing those places protected**. A document whose
/// values own no block, with nothing on the screen to say so.
///
/// `the_decisions_are_written` exists so that the two facts cannot be written
/// by two different numbers of doors (G35, G36). It guarantees they are
/// *called* together; this measures that they *land* together.
#[test]
fn the_session_copy_is_not_written_while_the_blocks_are_refused() {
    let _g = serial();
    let (dir, s) = a_copy_whose_vault_fell_behind("half");
    let number = conversations().expect("the room")[0].number;

    let vault_before = bytes_of(&vault_file(&dir));
    let session_before = bytes_of(&session_file(&dir, number));
    let _ = protect(s, span_of(DOC, "42 500"), Scope::Conversation, Kind::Custom);
    let vault_after = bytes_of(&vault_file(&dir));
    let session_after = bytes_of(&session_file(&dir, number));

    let the_copy_was_written = session_before != session_after;
    let the_blocks_were_written = vault_before != vault_after;
    assert!(
        !(the_copy_was_written && !the_blocks_were_written),
        "the session copy was written and the blocks were refused, so the disk now holds a \
         document whose protected places have no block behind them"
    );
}

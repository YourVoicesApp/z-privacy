// 064 · A session carries its own key.
//
// The owner: «كل جلسة لها تشفيرها. وإلا لماذا الجلسات. نفس الاسم في جلستين
// يأخذ رمزين مختلفين.»
//
// One random 32-byte key per session, sealed in the vault beside the session's
// number and name, with the conversation itself in a sealed file of its own.
// Three keys hang off it — the file's seal, the token namespace, the token
// tails — and that deliberately replaces 046/U's `profile ‖ document-text`
// namespace. So the same person protected in two documents of **one** session
// is one token, and in two sessions is two: 046/U's rule that stability across
// days and linkability across requests are the same property is not repealed,
// it is handed to the person to choose.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för en session";

/// Two documents that share one name and share nothing else — so a token that
/// is the same across them can only be the same because of the session.
const ONE: &str = "Kund: Hedvig Palmgren betalar i oktober.";
const TWO: &str = "Mötesanteckning. Hedvig Palmgren kommer på fredag igen.";
const NAME: &str = "Hedvig Palmgren";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-session-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    dir
}

/// Protect the name by hand, so the token exists because this test asked for it
/// and not because a pack happened to find it.
fn bench_with(doc: &str) -> SessionId {
    let s = open_session(None, "sv".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    let at = doc.find(NAME).expect("the fixture must contain the name");
    protect(
        s,
        Span { start: at as u32, end: (at + NAME.len()) as u32 },
        Scope::Conversation,
        Kind::Person,
    )
    .expect("protect");
    s
}

/// Every `__Z_…__` token in what would actually leave.
fn tokens_leaving(s: SessionId) -> Vec<String> {
    let text = payload_view(build_payload(s).expect("build")).expect("view").text;
    let mut out = Vec::new();
    let mut rest = text.as_str();
    while let Some(start) = rest.find("__Z_") {
        let after = &rest[start + 4..];
        match after.find("__") {
            Some(end) => {
                out.push(format!("__Z_{}__", &after[..end]));
                rest = &after[end + 2..];
            }
            None => break,
        }
    }
    out
}

fn the_one_token(s: SessionId) -> String {
    let found = tokens_leaving(s);
    assert_eq!(
        found.len(),
        1,
        "the fixture must put exactly one token on the wire, or nothing below is comparable: {found:?}"
    );
    found[0].clone()
}

/// The four hex between `__Z_` and the kind — the namespace, which is what the
/// session's key decides.
fn namespace_of(token: &str) -> String {
    token.trim_start_matches("__Z_").split('_').next().unwrap_or("").to_string()
}

// ------------------------------------------- 1 · two sessions, two tokens

/// **The owner's own sentence, measured:** the same name in two sessions takes
/// two different tokens.
#[test]
fn the_same_name_in_two_sessions_takes_two_tokens() {
    let _g = serial();
    fresh_vault("two-sessions");

    let first = bench_with(ONE);
    conversation_begin("oktober".to_string(), Some(first)).expect("begin");
    let a = the_one_token(first);
    close_session(first).ok();

    let second = bench_with(ONE);
    conversation_begin("november".to_string(), Some(second)).expect("begin");
    let b = the_one_token(second);
    close_session(second).ok();

    assert_ne!(
        a, b,
        "the same name took the same token in two sessions, which is «وإلا لماذا الجلسات»"
    );
    assert_ne!(
        namespace_of(&a),
        namespace_of(&b),
        "the two sessions share a namespace, so the tokens differ only by luck of the tail"
    );
}

// --------------------------------------- 2 · one session, one token, two docs

/// **The finding, and the guard the whole task turns on.** Before 064 the
/// namespace was keyed on the document's own text, so one person in two
/// documents of one session carried two names and a model could not tell they
/// were one. 046/U wrote that cost down and could not pay it.
#[test]
fn the_same_name_in_two_documents_of_one_session_takes_one_token() {
    let _g = serial();
    fresh_vault("one-session");

    let first = bench_with(ONE);
    let row = conversation_begin("granskning".to_string(), Some(first)).expect("begin");
    let a = the_one_token(first);
    close_session(first).ok();

    // The second document, in the same session. Entering asks nothing.
    let second = bench_with(TWO);
    conversation_enter(row.number, Some(second)).expect("enter");
    let b = the_one_token(second);
    close_session(second).ok();

    assert_eq!(
        a, b,
        "one person in two documents of one session took two tokens — which is the defect 064 \
         exists to remove, and what a model cannot see through"
    );
}

// --------------------------------------- 3 · a deleted session refuses by name

/// **The owner's warning, made literally true.** Delete a session and nothing
/// protected in it can ever be unprotected again: the key is destroyed, so
/// nothing derives anything — not us, not anybody. The refusal says which
/// session, by the name he gave it, because «session 3 is gone» is not what he
/// called it.
#[test]
fn an_answer_from_a_deleted_session_refuses_and_names_it() {
    let _g = serial();
    fresh_vault("deleted");

    let bench = bench_with(ONE);
    let row = conversation_begin("Weber-underlaget".to_string(), Some(bench)).expect("begin");
    let handle = build_payload(bench).expect("build");
    let token = the_one_token(bench);

    // An answer that came back wearing this session's token.
    let answer = ingest_answer(handle, format!("Jag har tittat på {token} i detalj."))
        .expect("ingest");
    let before = restored_view(bench, answer).expect("restores while the session lives");
    assert!(
        before.iter().any(|seg| matches!(seg.piece, Piece::Restored)),
        "nothing was restored before the deletion, so the refusal below proves nothing: {before:?}"
    );

    let name = conversation_forget(row.number).expect("forget");
    assert_eq!(name, "Weber-underlaget");

    match restored_view(bench, answer) {
        Err(ApiError::PayloadRefused { reason }) => {
            assert!(
                reason.contains("Weber-underlaget"),
                "the refusal does not name the session the owner named: «{reason}»"
            );
            assert!(
                reason.contains("deleted"),
                "the refusal does not say what happened: «{reason}»"
            );
        }
        other => panic!("a deleted session's answer still restored: {other:?}"),
    }
    close_session(bench).ok();
}

// ------------------------------- a name is asked once, so it must be asked for

/// **An empty name is refused as input, and the sentence says what to do.**
///
/// The owner's rule is that the name is asked **once**, at the moment a session
/// is born — so there is no second chance to fix a nameless row, and a session
/// with no name is a line in the list that cannot be told from another line.
///
/// `InputRefused` and not `PayloadRefused`: one variant per next move. Nothing
/// is wrong with a payload; a word has not been typed, and the move is to type
/// it. The screen's sentence follows the variant, which is why the variant is
/// part of the promise and not an implementation detail.
#[test]
fn a_session_with_no_name_is_refused_as_input() {
    let _g = serial();
    fresh_vault("nameless");

    let bench = bench_with(ONE);
    for empty in ["", "   ", "\t\n "] {
        match conversation_begin(empty.to_string(), Some(bench)) {
            Err(ApiError::InputRefused { reason }) => assert!(
                reason.contains("needs a name"),
                "the refusal does not say what is missing: «{reason}»"
            ),
            other => panic!("«{empty}» was accepted as a session name: {other:?}"),
        }
    }
    // And nothing was half-made on the way out of the refusal.
    assert!(
        conversations().expect("rows").is_empty(),
        "a refused name still left a session in the vault"
    );
    assert_eq!(conversation_open().expect("open"), None, "a refused name still opened a session");
    close_session(bench).ok();
}

// ------------------------------- 6b · the payload says whose session it is

/// **A payload with no session says so, on itself** — 064d.
///
/// The failure this closes is the one thing in 064 that was silent. The core
/// does not force a session to be born at an exit (94 call sites would have had
/// to pass one), so the screen asks — and a screen that forgot would have sent
/// text with no session while every guard stayed green. No guard can cover the
/// join between a press and the core: a core call started in a widget callback
/// does not complete under `testWidgets`, measured. So the fact is moved onto
/// the payload, where a guard reads it and a screen can show it.
#[test]
fn a_payload_says_which_session_it_belongs_to() {
    let _g = serial();
    fresh_vault("marked");

    // Built before any session exists — the state a forgotten line leaves.
    let bench = bench_with(ONE);
    let bare = payload_view(build_payload(bench).expect("build")).expect("view");
    assert!(
        bare.session.is_none(),
        "a payload built with no session open claims one: {:?}",
        bare.session
    );

    // And after a birth it carries the session's number **and** its name, so a
    // screen can say which one without asking a second question.
    let row = conversation_begin("höstgranskningen".to_string(), Some(bench)).expect("begin");
    let marked = payload_view(build_payload(bench).expect("build")).expect("view");
    let Some(whose) = marked.session else {
        panic!("a payload built inside a session does not name it");
    };
    assert_eq!(whose.number, row.number, "the payload names another session");
    assert_eq!(whose.name, "höstgranskningen", "the payload does not carry the name");
    // **Two states, not three.** There is no «some of these names predate the
    // session» to report — see `a_second_bench_is_named_into_the_open_session`
    // for the mechanism that makes it unreachable, and for what would have to
    // break before a screen needed a third sentence.
    close_session(bench).ok();
}

/// **There is no «these names predate the session» state, and here is why.**
///
/// A count of names not made for the open session was built, guarded, and then
/// removed, because it **could not rise**. The lever that should have produced a
/// straggler — a second bench, never entered into the session, minting its own
/// random names while the session is open — produces none: `protect` calls
/// `name_tokens_from_the_vault` before it mints, and so does `scan`, so a bench
/// that mints anything while a session is open is given that session's naming
/// first. The other direction is already covered: `begin` and `enter` re-derive
/// every token already on a bench.
///
/// So this test records the mechanism rather than a number. If either of those
/// two calls is ever removed from the head of `protect` or `scan`, this goes red
/// — and the screen will need a third sentence it does not need today.
#[test]
fn a_second_bench_is_named_into_the_open_session() {
    let _g = serial();
    fresh_vault("stragglers");

    let first = bench_with(ONE);
    conversation_begin("granskning".to_string(), Some(first)).expect("begin");
    let a = the_one_token(first);
    close_session(first).ok();

    // A second bench, and nobody enters the session on it. Under 046/U this
    // would have been a different namespace — the document's text decided it.
    let second = open_session(None, "sv".to_string()).expect("open");
    import_text(second, TWO.to_string()).expect("import");
    let at = TWO.find(NAME).expect("the fixture must contain the name");
    protect(
        second,
        Span { start: at as u32, end: (at + NAME.len()) as u32 },
        Scope::Conversation,
        Kind::Person,
    )
    .expect("protect");
    let b = the_one_token(second);

    assert_eq!(
        namespace_of(&a),
        namespace_of(&b),
        "a bench that minted inside an open session did not take the session's namespace, so a \
         payload can now carry names the session never made and nothing reports it"
    );
    // And the payload says whose it is, with no third state to report.
    let view = payload_view(build_payload(second).expect("build")).expect("view");
    assert_eq!(
        view.session.map(|w| w.number),
        Some(1),
        "the payload does not belong to the open session"
    );
    close_session(second).ok();
}

// ------------------------------------------------- 4 · a lock is not a power cut

/// 062 §D: the sealed file survives a lock; only the key is forgotten, and the
/// next unlock brings it back. An auto-lock must not undo the whole task.
#[test]
fn a_session_survives_the_vault_being_locked() {
    let _g = serial();
    fresh_vault("locked");

    let bench = bench_with(ONE);
    let row = conversation_begin("innan låset".to_string(), Some(bench)).expect("begin");
    let before = the_one_token(bench);
    close_session(bench).ok();

    vault_lock().expect("lock");
    assert_eq!(
        conversation_open().expect("open"),
        None,
        "the lock left a session open, so the key outlived the lock"
    );
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");

    let rows = conversations().expect("rows");
    assert!(
        rows.iter().any(|r| r.number == row.number && r.name == "innan låset"),
        "the session did not survive the lock: {rows:?}"
    );

    // And its names come back, which is what «survives» has to mean.
    let again = bench_with(ONE);
    conversation_enter(row.number, Some(again)).expect("enter");
    let after = the_one_token(again);
    close_session(again).ok();
    assert_eq!(before, after, "the session came back with different names, so nothing restores");
}

// ------------------------------------------- 5 · the vault does not grow

/// The conversation is its own file, so `vault.zv` does not grow with it.
/// **Bytes on disk** — an instrument that can be read twice, in any order, on
/// any tree, which is the opposite of a warning that reports once.
#[test]
fn a_long_conversation_does_not_grow_the_vault() {
    let _g = serial();
    let dir = fresh_vault("size");

    let bench = bench_with(ONE);
    conversation_begin("långt samtal".to_string(), Some(bench)).expect("begin");
    close_session(bench).ok();

    let vault_file = dir.join("vault.zv");
    let before = std::fs::metadata(&vault_file).expect("vault on disk").len();

    let long = "x".repeat(4096);
    for _ in 0..24 {
        conversation_record(long.clone(), long.clone()).expect("record");
    }

    let after = std::fs::metadata(&vault_file).expect("vault still on disk").len();
    assert_eq!(
        before, after,
        "the vault grew with the conversation: {before} → {after} bytes. The conversation belongs \
         in its own file precisely because this body is re-sealed whole on every change."
    );
    // And the control: the conversation really was written somewhere.
    let kept = conversations().expect("rows");
    assert_eq!(
        kept.first().map(|r| r.turns),
        Some(24),
        "nothing was recorded, so the size above proves nothing: {kept:?}"
    );
}

// --------------------------------------------- 6 · the payload's purity

/// **The failure mode of «the names that leave are the session's names» is a
/// mixed payload**, and nothing in the other guards would see it: protect
/// before the session exists, then copy, and one stray pre-birth name rides out
/// beside the derived ones.
#[test]
fn every_token_that_leaves_belongs_to_the_session() {
    let _g = serial();
    fresh_vault("purity");

    // Protected before any session exists — so these names are the random
    // fallback, which is exactly the state the re-derivation has to clean up.
    let bench = bench_with(ONE);
    let before = the_one_token(bench);
    let fallback = namespace_of(&before);

    let row = conversation_begin("rening".to_string(), Some(bench)).expect("begin");
    assert!(
        row.renamed_tokens >= 1,
        "the birth renamed nothing, so there was no re-derivation to measure"
    );

    let leaving = tokens_leaving(bench);
    assert!(!leaving.is_empty(), "nothing left, so purity is vacuous");

    let wanted = namespace_of(&the_one_token(bench));
    assert_ne!(
        wanted, fallback,
        "the namespace did not change at the birth, so the names that left are the pre-birth ones"
    );
    for token in &leaving {
        assert_eq!(
            namespace_of(token),
            wanted,
            "a token left under another namespace — a mixed payload: {leaving:?}"
        );
        assert_ne!(
            namespace_of(token),
            fallback,
            "a pre-birth name left beside the derived ones: {leaving:?}"
        );
    }
    close_session(bench).ok();
}

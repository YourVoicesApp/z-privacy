// 075c · The three pillars a session must hold across a restart.
//
// The owner, 10 Oct 2026: «ثلاثة أمور في الجلسة: المفتاح، الملفات المرسلة إلى
// الشات أو القادمة من الشات، ولغة الجلسة... وما دون ذلك رفاهية ليس هناك مشكلة
// إذا لم تظهر». Close the app, reopen, open the session: the three stand.
//
// **Measured before any of this was written** (two processes against one data
// directory, which is what closing and reopening actually means): the turns
// came back — the answer in segments, with an unresolved token named one by one
// rather than silently dropped — and the row came back with its number, handle
// and when. The language did not: it lived in `StoredSettings.pack_id`, one
// value for the whole application, while the per-bench argument died with the
// bench, and a bench is born again for every file. The key and the model did
// not either: a provider's credential and model are global to the provider.
//
// **An absence that means something, and one that does not.** The first probe
// reported «question = 0 segments» and it looked like a loss. It was not:
// `question_safe` is the question a person types in words, and that probe typed
// none. A correct absence read as a defect sends somebody hunting a bug that
// was never there — which is why `pack_id` below is an `Option` and never an
// empty string. `None` is «nobody has been asked yet»; `Some("")` would be a
// language called nothing.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för en session";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-three-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    dir
}

/// **A bench that closes itself even when a test panics.**
///
/// Without this, a test that fails half way leaves its bench live, and the next
/// test's birth-with-no-document is *refused* — because a birth that does not
/// name an open document is refused on purpose (064f). The second red then has
/// nothing to do with its own claim, and a red downstream of another red stands
/// in front of the one that matters. Found by sabotaging the header switch and
/// watching two tests fail for one cause.
struct Bench(SessionId);

impl Drop for Bench {
    fn drop(&mut self) {
        close_session(self.0).ok();
    }
}

/// **As close to closing the application as one process gets.** The bench is
/// closed, the vault is locked — which drops the master key, the decoded body
/// and the open session's number — and then it is unlocked, which reads the
/// file from disk again. What this does *not* reset is anything else the core
/// holds in memory, so it is a stand-in and said to be one; the measurement
/// that justified these guards was made with two real processes.
fn close_the_app_and_reopen(bench: SessionId) {
    close_session(bench).ok();
    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
}

fn row(number: u32) -> ConversationRow {
    conversations()
        .expect("rows")
        .into_iter()
        .find(|r| r.number == number)
        .expect("the session is not in the vault at all")
}

/// **Pillar three: the language the session was born into survives.**
#[test]
fn the_language_a_session_was_born_into_outlives_the_application() {
    let _guard = serial();
    let dir = fresh_vault("born");

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    let bench = held.0;
    import_text(bench, "Hej Hedvig Palmgren, tack för ditt brev.".to_string()).expect("import");
    let born = conversation_begin("vad säger brevet".to_string(), Some(bench)).expect("begin");
    assert_eq!(
        born.pack_id.as_deref(),
        Some("sv"),
        "the birth did not take the language from the bench that named it"
    );

    close_the_app_and_reopen(bench);

    assert_eq!(
        row(born.number).pack_id.as_deref(),
        Some("sv"),
        "the session forgot its language when the application closed"
    );
    // And entering it reports the same thing, because a screen may ask either.
    let entered = conversation_enter(born.number, None).expect("enter");
    assert_eq!(entered.pack_id.as_deref(), Some("sv"), "enter and list disagree");

    let _ = std::fs::remove_dir_all(&dir);
}

/// **A session born with no bench has never been asked**, and that is a third
/// state the screen is allowed to see. Not an empty string, not a default: the
/// designer's half of 075d asks once exactly when this is `None`.
#[test]
fn a_session_born_with_no_document_has_never_been_asked() {
    let _guard = serial();
    let dir = fresh_vault("unasked");

    let born = conversation_begin("a session with no document".to_string(), None).expect("begin");
    assert_eq!(born.pack_id, None, "a birth with no bench invented a language");

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert_eq!(
        row(born.number).pack_id, None,
        "«never asked» turned into something else across a restart"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **The header is the one place a language changes, and the record follows.**
/// The owner keeps that control; what he must not get is the question again.
#[test]
fn changing_the_language_in_the_header_reaches_the_open_session() {
    let _guard = serial();
    let dir = fresh_vault("switch");

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    let bench = held.0;
    import_text(bench, "Hej Hedvig Palmgren, tack för ditt brev.".to_string()).expect("import");
    let born = conversation_begin("vad säger brevet".to_string(), Some(bench)).expect("begin");
    assert_eq!(born.pack_id.as_deref(), Some("sv"), "the fixture starts in Swedish");

    switch_pack(bench, "de".to_string()).expect("switch");
    assert_eq!(
        row(born.number).pack_id.as_deref(),
        Some("de"),
        "the header changed the language and the session did not hear it"
    );

    close_the_app_and_reopen(bench);
    assert_eq!(
        row(born.number).pack_id.as_deref(),
        Some("de"),
        "the change was only in memory"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

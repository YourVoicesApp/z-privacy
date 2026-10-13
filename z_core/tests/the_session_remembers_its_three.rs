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
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

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

/// **The designer's path, end to end: a session that had no language gets one
/// from its first document, and keeps it.**
///
/// His half of 075d asks once, exactly when `pack_id` is `None`, and then tells
/// the core through `switchPack` **after** the bench is open. A birth with no
/// document is allowed, so this is not a corner: it is what happens whenever
/// somebody starts a session before opening a file.
#[test]
fn the_first_document_of_a_session_born_without_one_writes_its_language() {
    let _guard = serial();
    let dir = fresh_vault("first-document");

    let born = conversation_begin("a session before any file".to_string(), None).expect("begin");
    assert_eq!(born.pack_id, None, "a birth with no bench must leave the question unasked");

    // The screen asks once, opens the bench with the answer, and tells the core.
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, "Sehr geehrte Frau Anna Weber, danke für Ihren Brief.".to_string())
        .expect("import");
    switch_pack(held.0, "de".to_string()).expect("switch");

    assert_eq!(
        row(born.number).pack_id.as_deref(),
        Some("de"),
        "the first document did not write the session's language"
    );

    close_the_app_and_reopen(held.0);
    assert_eq!(
        row(born.number).pack_id.as_deref(),
        Some("de"),
        "the language the first document chose did not outlive the application"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **The call that looks redundant is the only one that writes.**
///
/// `Workbench.switchPack` on the Dart side returns at once when the pack has
/// not changed, which is why the screen calls `z.switchPack` directly with the
/// pack the bench was *just opened with*. So this core call must write the
/// session's language even when nothing about the bench changes — and an
/// «optimisation» here that returns early on an unchanged pack would silently
/// stop the language ever being recorded for a session that had none. This is
/// that invariant, pinned, so the optimisation reds instead of shipping.
#[test]
fn switching_to_the_language_a_bench_already_has_still_writes_it() {
    let _guard = serial();
    let dir = fresh_vault("same-pack");

    let born = conversation_begin("a session before any file".to_string(), None).expect("begin");
    assert_eq!(born.pack_id, None, "the fixture starts unasked");

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    import_text(held.0, "Hej Hedvig Palmgren, tack för ditt brev.".to_string()).expect("import");
    // The bench is already «sv». The screen says «sv» again on purpose.
    switch_pack(held.0, "sv".to_string()).expect("switch");

    assert_eq!(
        row(born.number).pack_id.as_deref(),
        Some("sv"),
        "a switch to the pack the bench already had wrote nothing, so a session \
         born without a language can never get one"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

// ---------------------------------------------------------------- pillar one
//
// «المفتاح: هوية المفتاح والموديل الذي جرت به المحادثة — الاسم الذي رآه
// الإنسان، لا السر أبداً.» Measured as missing before it was written: a
// provider's credential and model are global to the provider, so nothing said
// which key or model a given exchange ran through, and switching the model left
// every past conversation claiming nothing at all.

const MODEL: &str = "the-model-the-person-saw";

fn the_fake_provider() {
    connect_provider(
        ProviderId { id: "fake".to_string() },
        "k".to_string(),
        None,
        Some(MODEL.to_string()),
    )
    .expect("the echo provider");
}

/// A bench with one protected name, ready to send: the open suggestions are
/// answered because the send door refuses while one stands, which is its own
/// guard and not this file's business.
fn ready_to_send(bench: SessionId) {
    import_text(bench, "Hej Hedvig Palmgren, tack för ditt brev om kontot.".to_string())
        .expect("import");
    let findings = list_findings(bench).expect("findings");
    for (i, f) in findings.iter().enumerate() {
        let answer = if i == 0 { FindingAnswer::Protect } else { FindingAnswer::Skip };
        answer_finding(bench, f.id, answer).expect("answer");
    }
}

/// **Pillar one: a turn remembers which key and which model answered it, and
/// keeps remembering after the application closes.**
///
/// The model is asked for as `None` on purpose — the gateway then resolves the
/// provider's own model, and what must be recorded is **what answered**, not
/// what was requested. A record of the request would say nothing at all here.
#[test]
fn a_turn_remembers_which_key_and_model_answered_it() {
    let _guard = serial();
    let dir = fresh_vault("via");
    the_fake_provider();

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    ready_to_send(held.0);
    let born = conversation_begin("vad säger brevet".to_string(), Some(held.0)).expect("begin");
    let handle = build_payload(held.0).expect("payload");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new(), Vec::new())
        .expect("the echo answers");

    close_the_app_and_reopen(held.0);

    let turns = conversation_turns(born.number, None).expect("turns");
    let turn = turns.first().expect("the session kept no turn at all");
    assert_eq!(
        turn.via,
        TurnVia::Through { provider: "fake".to_string(), model: MODEL.to_string() },
        "the turn does not say what answered it, though the gateway resolved a model"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **And an answer the person carried says exactly that** — not «no key», and
/// not «unknown».
///
/// This is the state the lead ruled a byte for: a turn the person took out of
/// the application and brought back by hand is a *known* fact about that turn,
/// and folding it into «we do not know» would report it as though it were a
/// turn older than the question. The control is the connected provider: with
/// none configured, «no key» would be an accident rather than a measurement.
#[test]
fn an_answer_the_person_carried_says_the_person_carried_it() {
    let _guard = serial();
    let dir = fresh_vault("pasted");
    the_fake_provider();

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    ready_to_send(held.0);
    let born = conversation_begin("vad säger brevet".to_string(), Some(held.0)).expect("begin");
    let handle = build_payload(held.0).expect("payload");
    ingest_answer(handle, "brought back from a browser".to_string()).expect("paste");

    assert!(
        providers()
            .expect("providers")
            .iter()
            .any(|p| p.id == "fake" && p.connected),
        "the control is void: no provider is connected, so «no key» proves nothing"
    );

    close_the_app_and_reopen(held.0);

    let turns = conversation_turns(born.number, None).expect("turns");
    let turn = turns.first().expect("the session kept no turn at all");
    assert_eq!(
        turn.via,
        TurnVia::Pasted,
        "an answer the person carried by hand was recorded as something else"
    );
    assert_ne!(
        turn.via,
        TurnVia::NotRecorded,
        "«the person carried it» collapsed into «we do not know», which is the \
         distinction the kind byte exists for"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **Both kinds in one file, told apart after a restart.**
///
/// The three states are only worth a byte if they survive together: a session
/// where one answer came through a key and the next was carried in by hand must
/// read back as two different things, in the order they happened. This is the
/// guard that would have caught a writer that stamped every turn with whatever
/// answered the last one.
#[test]
fn a_session_holding_both_kinds_of_turn_keeps_them_apart() {
    let _guard = serial();
    let dir = fresh_vault("both");
    the_fake_provider();

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    ready_to_send(held.0);
    let born = conversation_begin("vad säger brevet".to_string(), Some(held.0)).expect("begin");

    // One through a key of ours…
    let first = build_payload(held.0).expect("payload");
    ask_model(first, ProviderId { id: "fake".to_string() }, None, Vec::new(), Vec::new())
        .expect("the echo answers");
    // …and one the person carried back.
    let second = build_payload(held.0).expect("payload again");
    ingest_answer(second, "brought back from a browser".to_string()).expect("paste");

    close_the_app_and_reopen(held.0);

    let turns = conversation_turns(born.number, None).expect("turns");
    assert_eq!(turns.len(), 2, "the session did not keep both exchanges");
    assert_eq!(
        turns[0].via,
        TurnVia::Through { provider: "fake".to_string(), model: MODEL.to_string() },
        "the first exchange lost what answered it"
    );
    assert_eq!(
        turns[1].via,
        TurnVia::Pasted,
        "the second exchange was stamped with what answered the first"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

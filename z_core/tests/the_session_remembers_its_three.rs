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

/// **A bench with a document on it, ready to send.**
///
/// Not «with one protected name», which is what this said until 075e measured
/// it: importing does not scan. `import_text` sets `ScanOrigin::NotScanned` and
/// clears what the last document found, and a screen asks for the scan itself —
/// so this list is empty, nothing here is protected, and the loop below answers
/// nothing. The four guards that use it are about what a turn *says*, which
/// does not depend on a protection standing; the guards that need one standing
/// scan and protect by hand, with the scope named.
///
/// The loop stays all the same: the day a pack does find something in this
/// line, an unanswered suggestion would refuse the send, and these guards would
/// go red for a reason that has nothing to do with what they claim.
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

// ---------------------------------------------------------------- pillar two
//
// «الجلسة تحفظ الملفات التي ذهبت والإجابات.» The turns were already kept. What
// was missing was which file an exchange was about: the vault's record holds a
// *hash*, which answers «is this the same file?» and not «which file was it?»,
// and the only name available after a restart came from the live bench — that
// is, from whatever is open now, which is a different question again.
//
// The lead's three bounds, and each is measured rather than promised: the name
// lives in the session's own sealed file (so deleting the session destroys it
// with the key), it is for the glass only, and it never reaches a report or a
// log. The last one has two guards already standing: `gates.sh` refuses any
// print in `z_core/src` at all, and the report's grammar admits nothing in its
// `file` line but a bare extension.

/// **Pillar two: the name of the file an exchange was about survives.**
#[test]
fn a_turn_remembers_which_file_it_was_about() {
    let _guard = serial();
    let dir = fresh_vault("named");
    the_fake_provider();

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    import_document(
        held.0,
        "Brev_Lindqvist.txt".to_string(),
        b"Hej Hedvig Palmgren, tack for ditt brev om kontot.".to_vec(),
        DocumentKind::Txt,
    )
    .expect("import");
    for (i, f) in list_findings(held.0).expect("findings").iter().enumerate() {
        let answer = if i == 0 { FindingAnswer::Protect } else { FindingAnswer::Skip };
        answer_finding(held.0, f.id, answer).expect("answer");
    }
    let born = conversation_begin("vad säger brevet".to_string(), Some(held.0)).expect("begin");
    let handle = build_payload(held.0).expect("payload");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new(), Vec::new())
        .expect("the echo answers");

    close_the_app_and_reopen(held.0);

    let turns = conversation_turns(born.number, None).expect("turns");
    let turn = turns.first().expect("the session kept no turn at all");
    assert_eq!(
        turn.document,
        TurnDocument::Named { name: "Brev_Lindqvist.txt".to_string() },
        "the session cannot say which file this exchange was about"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **And text the person typed says so** — «Typed», not «we do not know».
///
/// `import_text` sets no name because there is no file, and the honest answer
/// to «which file was this about» is «none, you typed it». Folding that into
/// «not recorded» would report it as though the turn were older than the
/// question.
#[test]
fn text_the_person_typed_says_there_was_no_file() {
    let _guard = serial();
    let dir = fresh_vault("typed");
    the_fake_provider();

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    ready_to_send(held.0); // import_text: typed, with no file name
    let born = conversation_begin("vad säger texten".to_string(), Some(held.0)).expect("begin");
    let handle = build_payload(held.0).expect("payload");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new(), Vec::new())
        .expect("the echo answers");

    close_the_app_and_reopen(held.0);

    let turns = conversation_turns(born.number, None).expect("turns");
    let turn = turns.first().expect("the session kept no turn at all");
    assert_eq!(turn.document, TurnDocument::Typed, "typed text was given a file it never had");
    assert_ne!(
        turn.document,
        TurnDocument::NotRecorded,
        "«you typed this» collapsed into «we do not know»"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **The lead's bound, measured across two doors: the session knows the name
/// and the report still does not.**
///
/// The name is for the glass. A report is the thing a person pastes into an
/// e-mail to us, so a file name in it would leave the machine — which is why
/// the report's `file` line carries an extension and nothing else. One session
/// holding the name and one report refusing to show it, in the same test,
/// because each alone proves only half of it.
#[test]
fn the_report_still_names_no_file_though_the_session_knows_it() {
    let _guard = serial();
    let dir = fresh_vault("report");
    the_fake_provider();

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    import_document(
        held.0,
        "Brev_Lindqvist.txt".to_string(),
        b"Hej Hedvig Palmgren, tack for ditt brev om kontot.".to_vec(),
        DocumentKind::Txt,
    )
    .expect("import");
    for (i, f) in list_findings(held.0).expect("findings").iter().enumerate() {
        let answer = if i == 0 { FindingAnswer::Protect } else { FindingAnswer::Skip };
        answer_finding(held.0, f.id, answer).expect("answer");
    }
    let born = conversation_begin("vad säger brevet".to_string(), Some(held.0)).expect("begin");
    let handle = build_payload(held.0).expect("payload");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new(), Vec::new())
        .expect("the echo answers");

    // The session holds it…
    let turns = conversation_turns(born.number, Some(held.0)).expect("turns");
    assert_eq!(
        turns.first().map(|t| t.document.clone()),
        Some(TurnDocument::Named { name: "Brev_Lindqvist.txt".to_string() }),
        "the control is void: the session does not hold the name, so the report \
         proves nothing by lacking it"
    );
    // …and the report does not.
    let report = import_report(ReportSubject::Imported { session: held.0 }).expect("report");
    assert!(
        !report.contains("Brev_Lindqvist"),
        "the file name reached the report, which is the one place it may never go"
    );
    assert!(report.contains("file        .txt"), "the report stopped naming the extension");

    let _ = std::fs::remove_dir_all(&dir);
}

// ---------------------------------------------------------------- honest naming
//
// 075e · «جلسةٌ أُعيد فتحُها تُظهرُ أدوارَها، وتُسمّي ما لا تستطيعُ إرجاعَه،
// ويُشفى منها ما حفظته الخزنةُ وحدَه.»
//
// The pillars above are about what a session *keeps*. These two are about what
// it owes for what it cannot keep: to say so **by the name the person saw**,
// rather than show the stored form as though it were prose — the lie 046/U was
// written to end — and rather than drop it, which takes a word out of a
// sentence and tells nobody.
//
// **The numbers below are a measurement of the three reaches these two tests
// choose, and not a constant about the product.** Three values are protected,
// as «always», «this conversation» and «here only», and exactly one of the
// three is written anywhere outside the session's own sealed file. Protect a
// fourth with `Scope::Profile` and both numbers move — and they should.
//
// Measured 13 Oct 2026, in one process, in this order:
//
//   read through the bench that made it     0 named of 3
//   read with no bench at all               3 named of 3
//   read through a new bench on the file     2 named of 3
//
// The one that heals is the one the vault was told to keep, and it heals
// without being asked a second time: `scan` applies a vault value by itself —
// `auto`, `Source::Vault` — so a person does not answer the same question
// about the same name once per file. The two that do not heal are not a defect
// of the reader: the values were never written down, by the person's own
// choice, and the reader says their names rather than inventing them.
//
// **`Scope::Conversation` is measured here, not decided here.** Its name
// promises the conversation's life and it dies with the process. Whether that
// promise is to be kept in the vault is the owner's word and not this file's;
// the number is pinned so that the day it changes, this guard says so first.

const THREE: &str = "Hej Hedvig Palmgren, tack för ditt brev om kontot. \
                     Ingmar Sjöberg skrev under och Åsa Bergkvist bevittnade.";

/// `Scope::Always` — the one value written into the vault.
const KEPT: &str = "Hedvig Palmgren";
/// `Scope::Conversation` — every appearance here, and nothing written down.
const THIS_CONVERSATION: &str = "Ingmar Sjöberg";
/// `Scope::Once` — this one place.
const HERE_ONLY: &str = "Åsa Bergkvist";

const FILE: &str = "Brev_Lindqvist.txt";

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("the fixture does not contain its own needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

fn read(segments: &[Segment]) -> String {
    segments.iter().map(|s| s.text.as_str()).collect()
}

fn whole_turn(turn: &TurnRow) -> String {
    format!("{} {}", read(&turn.question), read(&turn.answer))
}

/// **One document, three reaches, one exchange** — the fixture both guards read
/// against, so that a difference between them is about the reading and never
/// about the writing. Returns the session's number.
///
/// The scopes are chosen by hand rather than through `answer_finding`, because
/// the scope is the thing being measured: the review list offers «protect» and
/// «always» only, so `Once` and `Conversation` would be unreachable from there.
fn three_reaches(bench: SessionId) -> u32 {
    import_document(bench, FILE.to_string(), THREE.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("import");
    // Importing does not scan — it sets `NotScanned` and clears what the last
    // document found — so the scan is asked for here, as a screen asks for it.
    let report = scan(bench).expect("scan");
    assert_eq!(
        report.suggested, 0,
        "the scanner now suggests {} names in this line, and an unanswered \
         suggestion is a different document from the one these numbers were \
         measured on: answer them here before reading the counts below",
        report.suggested
    );
    for (needle, scope) in [
        (KEPT, Scope::Always),
        (THIS_CONVERSATION, Scope::Conversation),
        (HERE_ONLY, Scope::Once),
    ] {
        protect(bench, span_of(THREE, needle), scope, Kind::Person).expect("protect");
    }
    let born = conversation_begin("vad säger brevet".to_string(), Some(bench)).expect("begin");
    let handle = build_payload(bench).expect("payload");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new(), Vec::new())
        .expect("the echo answers");
    born.number
}

/// **A reopened session shows its turn, and names every value it cannot bring
/// back** — by the token the person saw, with the token still standing where
/// the value stood.
///
/// Read with no document, nothing can resolve: the store that held the values
/// died with the bench. The two wrong answers are to print the stored form as
/// though the model had written it, and to quietly drop it. Both leave a person
/// reading a sentence that is not the one that was sent.
#[test]
fn a_reopened_session_names_every_value_it_cannot_bring_back() {
    let _guard = serial();
    let dir = fresh_vault("named-back");
    the_fake_provider();

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    let number = three_reaches(held.0);

    // **The control, taken before anything closes**: through the bench that
    // made these names, all three resolve. Without it, the cold read below
    // would prove only that something, somewhere, went wrong.
    let warm = conversation_turns(number, Some(held.0)).expect("turns");
    let warm_turn = warm.first().expect("the session kept no turn at all");
    assert!(
        warm_turn.unresolved.is_empty(),
        "the control is void: the bench that minted these names cannot read them \
         back, so a cold read naming them proves nothing"
    );
    for value in [KEPT, THIS_CONVERSATION, HERE_ONLY] {
        let whole = whole_turn(warm_turn);
        assert!(whole.contains(value), "the control is void: «{value}» never reached the turn");
    }

    close_the_app_and_reopen(held.0);

    let cold = conversation_turns(number, None).expect("turns");
    let turn = cold.first().expect("the session kept no turn at all");

    // It shows the turn: what answered it, which file it was about, and when.
    assert_eq!(
        turn.via,
        TurnVia::Through { provider: "fake".to_string(), model: MODEL.to_string() },
        "a reopened session cannot say what answered its own turn"
    );
    assert_eq!(
        turn.document,
        TurnDocument::Named { name: FILE.to_string() },
        "a reopened session cannot say which file its own turn was about"
    );
    assert!(turn.at > 0, "a restored turn carries no time at all");

    // And it names what it cannot bring back — all three, not two.
    assert_eq!(
        turn.unresolved.len(),
        3,
        "read with no document, this turn must name all three protected values; \
         it named {:?}",
        turn.unresolved
    );
    // Named, and still standing: a token the reader could not resolve stays
    // where the value stood, marked as itself, so the screen shows a gap it can
    // explain instead of a sentence with a word missing.
    let pieces: Vec<&Segment> = turn
        .question
        .iter()
        .chain(turn.answer.iter())
        .filter(|s| s.piece == Piece::Unresolved)
        .collect();
    for name in &turn.unresolved {
        assert!(
            name.starts_with("__Z_") && name.ends_with("__"),
            "«{name}» is not the name the person saw on the glass"
        );
        assert!(
            pieces.iter().any(|s| s.text.contains(name.as_str())),
            "«{name}» is in the list of what could not be brought back, and nowhere \
             in the turn: it was dropped out of the sentence and only counted"
        );
    }
    // The values themselves are nowhere. This is the whole reason the list is a
    // list of names and not of values.
    let text = whole_turn(turn);
    for value in [KEPT, THIS_CONVERSATION, HERE_ONLY] {
        assert!(
            !text.contains(value),
            "a session read without its document gave «{value}» back as prose"
        );
    }

    let _ = std::fs::remove_dir_all(&dir);
}

/// **Only what the vault kept comes back when the document is opened again** —
/// one of three, and the other two are still named.
///
/// This is the whole promise of «always» measured end to end, and the whole
/// limit of the other two stated in the same breath: restoration is possible
/// for what the person chose to keep, and impossible for what they chose not
/// to. Nothing here asks the person a second time — `scan` applies a vault
/// value by itself, and entering the session renames the bench's token to the
/// name the session's own file holds.
#[test]
fn only_what_the_vault_kept_comes_back_when_the_document_opens_again() {
    let _guard = serial();
    let dir = fresh_vault("healed");
    the_fake_provider();

    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    let number = three_reaches(held.0);

    // **The control: the vault holds exactly one of the three.** Without it,
    // «only what the vault kept» would be a sentence about nothing.
    let in_the_vault: u32 = entities(None).expect("entities").iter().map(|e| e.values).sum();
    assert_eq!(
        in_the_vault, 1,
        "the vault holds {in_the_vault} values, not the one «always» was told to \
         keep, so this test is not measuring what it says"
    );

    close_the_app_and_reopen(held.0);

    // The same file, opened again on a new bench — which is what a person does
    // the next morning.
    let again = Bench(open_session(None, "sv".to_string()).expect("open again"));
    import_document(again.0, FILE.to_string(), THREE.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("import again");
    let report = scan(again.0).expect("scan");
    assert_eq!(
        report.auto, 1,
        "the scan put back {} values by itself; «always» promises exactly the one \
         it was taught, found without being asked again",
        report.auto
    );
    assert!(
        report
            .by_layer
            .iter()
            .any(|l| l.source == Source::Vault && l.count == 1),
        "the one value that came back was not credited to the vault, so it came \
         back for some other reason and the promise is still unmeasured"
    );

    // Entering the session gives this bench the session's own names.
    let entered = conversation_enter(number, Some(again.0)).expect("enter");
    assert_eq!(
        entered.renamed_tokens, 1,
        "entering renamed {} tokens; the bench's name for a value is derived \
         fresh and must be moved onto the session's name, or the turn cannot \
         resolve it however well the vault remembered it",
        entered.renamed_tokens
    );

    let turns = conversation_turns(number, Some(again.0)).expect("turns");
    let turn = turns.first().expect("the session kept no turn at all");
    let text = whole_turn(turn);
    assert!(
        text.contains(KEPT),
        "the value the vault was told to keep did not come back, though the scan \
         put it back on the bench and the session renamed it"
    );
    assert_eq!(
        turn.unresolved.len(),
        2,
        "two of the three were never written down and must still be named; this \
         turn names {:?}",
        turn.unresolved
    );
    for value in [THIS_CONVERSATION, HERE_ONLY] {
        assert!(
            !text.contains(value),
            "«{value}» came back although nothing kept it — a value restored by \
             guess is worse than a name"
        );
    }

    let _ = std::fs::remove_dir_all(&dir);
}

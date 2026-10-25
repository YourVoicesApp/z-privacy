// **Rule 55 · the session is the container, and it is born at its first
// document** — the owner's answer of 16 October 2026: «المحادثة لا علاقة
// بالوثائق… ولكن عند إدخال الوثائق نحفظها كما اتفقنا» — «نعم» to the question
// this house left open the day before.
//
// A *conversation* is only what the person writes to the AI. The **session** is
// the container: it holds the conversation, if there is one, and the documents
// that were saved. So a document does not wait for a conversation to exist:
// **every document is saved the moment it enters the preview**, even the first
// one in a brand-new session in which nothing has been written to a model, and
// **the session appears in the list at that instant** — not at the first
// message, not at the first exit.
//
// What this file measures is the reversal. Until today an import with no
// session open kept nothing and created nothing: `keep_the_preview` read
// `core.open_conversation`, found `None`, and returned — which the sibling
// guard `a_document_opened_before_the_session_is_kept_at_the_birth` asserted on
// purpose, because the birth was the only instant at which a number could be
// written. Rule 55 moves that instant to the document itself.
//
// The code's word for the container stays `Conversation` — the owner's word is
// now «session» and the rename is still task 066's to pay.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein genügend langes kennwort für die erste seite";
const MODEL: &str = "the-model-the-person-saw";

/// A German line the pack finds two names and an identifier in, so the first
/// document of a session carries real decisions.
const LETTER: &str = "Kundennummer 8841-2270 für Herrn Stefan Keller, Nordstern Consulting GmbH.";

/// A second document, so «the next number» is measured on a real one.
const SECOND: &str = "Rechnung an Frau Katrin Sommer, Stadtwerke Lindenau GmbH.";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

struct Ground(std::path::PathBuf);

impl Ground {
    fn fresh(name: &str) -> Self {
        let _ = vault_lock();
        let dir =
            std::env::temp_dir().join(format!("zprivacy-055-born-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
        vault_create_with_passphrase(PASS.to_string()).expect("vault");
        Self(dir)
    }

    /// A restart, as far as anything stored can tell: the vault locked — which
    /// drops the key and the open session's number — and opened again, which
    /// reads the files from the disk.
    fn restart(&self) {
        vault_lock().expect("lock");
        vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    }
}

impl Drop for Ground {
    fn drop(&mut self) {
        let _ = vault_lock();
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

struct Bench(SessionId);

impl Drop for Bench {
    fn drop(&mut self) {
        close_session(self.0).ok();
    }
}

fn the_fake_provider() {
    connect_provider(
        ProviderId { id: "fake".to_string() },
        "k".to_string(),
        None,
        Some(MODEL.to_string()),
    )
    .expect("the echo provider");
}

/// Every word that waits, answered, so an exit is not refused for it.
fn answer_everything(bench: SessionId) {
    for f in list_findings(bench).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(bench, f.id, FindingAnswer::Protect).ok();
        }
    }
}

/// **A brand-new session: a bench, a document, and nothing written to any
/// model.** No `conversation_begin`, no `conversation_enter` — which is the
/// whole point of the rule.
fn the_first_document(text: &str, name: Option<&str>) -> Bench {
    let bench = Bench(open_session(None, "de".to_string()).expect("open"));
    match name {
        Some(name) => {
            import_document(bench.0, name.to_string(), text.as_bytes().to_vec(), DocumentKind::Txt)
                .expect("import a file");
        }
        None => {
            import_text(bench.0, text.to_string()).expect("import a text");
        }
    }
    bench
}

/// Where a word starts, counted the way the glass counts — in UTF-16 units,
/// which is what a `Span` holds.
fn utf16_of(text: &str, word: &str) -> u32 {
    let at = text.find(word).expect("the fixture holds the word");
    text[..at].chars().map(char::len_utf16).sum::<usize>() as u32
}

fn kept(number: u32) -> Vec<KeptRow> {
    kept_documents(number).expect("the kept documents")
}

/// **The first document of a new session is in the list, and comes back after a
/// restart with every decision on it** — rule 55b and 55c, and the lead's
/// first guard.
#[test]
fn the_first_document_of_a_new_session_is_kept_and_listed() {
    let _guard = serial();
    let ground = Ground::fresh("first");
    let held = the_first_document(LETTER, Some("Mahnung.txt"));
    // **«Leave it», the decision that is not a protection.** The pack protects
    // the customer number and the two names by rule and asks about the company;
    // that question is answered «not sensitive», so the copy carries one of
    // each kind of answer on it.
    let company_at = utf16_of(LETTER, "Nordstern");
    let left_alone = list_findings(held.0)
        .expect("findings")
        .into_iter()
        .find(|f| f.state == MarkState::Suggested && f.span.start == company_at)
        .map(|f| f.id)
        .expect("the pack asks about the company");
    answer_finding(held.0, left_alone, FindingAnswer::NotSensitive).expect("leave it");
    answer_everything(held.0);

    // **The session exists**, without anybody having written a word to a model.
    let number = conversation_open()
        .expect("open")
        .expect("no session was born when the first document entered the preview");
    let rows = conversations().expect("the list");
    assert_eq!(rows.len(), 1, "the list holds {} sessions, not one: {rows:?}", rows.len());
    assert_eq!(rows[0].number, number);
    assert_eq!(rows[0].turns, 0, "a session with no conversation in it reports exchanges");

    // **And it is holding the document**, as `doc1`, with its decisions.
    let held_rows = kept(number);
    assert_eq!(held_rows.len(), 1, "the first document was not kept: {held_rows:?}");
    assert_eq!(held_rows[0].handle, "doc1", "a file from the computer is not a docN");
    assert_eq!(held_rows[0].name, "Mahnung.txt", "the file's own name was not kept");
    let protected = held_rows[0].protected;
    assert!(protected >= 3, "{protected} places were kept for a line that protects three");

    // **«Here» and «Leave it», the two decisions that are not a protection.**
    let keller = LETTER.find("Keller").expect("the fixture");
    let kstart: usize = LETTER[..keller].chars().map(char::len_utf16).sum();
    let one = Span {
        start: kstart as u32,
        end: (kstart + "Keller".chars().map(char::len_utf16).sum::<usize>()) as u32,
    };
    let undone = unprotect(held.0, one).expect("here");
    assert!(matches!(undone, UndoOutcome::Undone { .. }), "{undone:?}");
    let on_the_bench = document_view(held.0).expect("the document").marks.len() as u32;
    assert!(on_the_bench < protected, "«here» uncovered nothing");
    assert_eq!(
        kept(number)[0].protected, on_the_bench,
        "the copy was not written again after «here», so it holds {} marks and the bench {on_the_bench}",
        kept(number)[0].protected
    );
    let after = on_the_bench;

    // **The app closes and opens again.**
    drop(held);
    ground.restart();
    let rows = conversations().expect("the list");
    assert_eq!(rows.len(), 1, "the session did not survive the restart: {rows:?}");
    let held_rows = kept(number);
    assert_eq!(held_rows.len(), 1, "the saved document did not survive the restart");
    assert_eq!(held_rows[0].protected, after, "the decisions on it did not survive");

    // **And it opens as it was left**, with nothing asked again.
    let again = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(again.0)).expect("enter");
    open_kept_document(number, held_rows[0].number, held_rows[0].chat, again.0).expect("open it");
    let view = document_view(again.0).expect("the document");
    assert_eq!(view.marks.len() as u32, after, "it came back in a state nobody left it in");
    assert_eq!(view.name, "Mahnung.txt", "it came back under another name");
    assert!(
        list_findings(again.0).expect("findings").iter().all(|f| f.state != MarkState::Suggested),
        "re-opening asked again about a word the person had answered with «leave it»"
    );
    assert!(
        view.marks.iter().all(|m| m.span.start != company_at),
        "the word the person left alone came back protected"
    );
}

/// **A text written with the model and moved into the preview is `chat1`** —
/// the second sequence, in a session nobody had begun. The lead's second guard.
#[test]
fn a_chat_in_a_new_session_is_kept_as_chat1() {
    let _guard = serial();
    let _ground = Ground::fresh("chat");
    let held = the_first_document("Frau Katrin Sommer hat angerufen.", None);
    answer_everything(held.0);

    let number = conversation_open()
        .expect("open")
        .expect("no session was born when the text entered the preview");
    let rows = kept(number);
    assert_eq!(rows.len(), 1, "the text was not kept: {rows:?}");
    assert_eq!(
        rows[0].handle, "chat1",
        "a text moved into the preview did not take the chat sequence"
    );
    assert!(rows[0].chat, "a text written into the preview was kept as a file");
    assert!(rows[0].protected >= 1, "it was kept with no decision on it");
}

/// **A session that holds only documents is listed, and named by its own
/// number** — the lead's third guard, which asks what name it shows.
///
/// «Session N» is the house's one spelling for a session nobody named (081,
/// where the owner had the name field deleted: «أبسط من البساطة ذاتها»). It is
/// written in the core now, because the core is where the birth happens; the
/// Dart guard beside this one measures that the glass still spells it the same.
///
/// **And since 117 the spelling is the birth language's**: this bench reads
/// German, so the name is «Sitzung N». The owner asked for it after the Arabic
/// screens handed him «Session 1» in the middle of his own language, and
/// `the_session_names_itself.rs` measures all four words and the fallback. What
/// did not change is that the name never moves again — it is data (G37).
#[test]
fn a_session_of_documents_only_is_named_by_its_number() {
    let _guard = serial();
    let _ground = Ground::fresh("named");
    let held = the_first_document(LETTER, Some("Mahnung.txt"));
    answer_everything(held.0);

    let rows = conversations().expect("the list");
    assert_eq!(rows.len(), 1, "{rows:?}");
    assert_eq!(
        rows[0].name, "Sitzung 1",
        "a session born of its first document on a German bench shows «{}»",
        rows[0].name
    );
    assert_eq!(rows[0].turns, 0, "nothing was written to a model, and it says there was");
    // It is a real session, not a row: it can be renamed, entered and asked
    // what it holds.
    conversation_rename(rows[0].number, "Die Mahnungen".to_string()).expect("rename");
    assert_eq!(conversations().expect("the list")[0].name, "Die Mahnungen");
}

/// **The first document's number is spent for ever at each of the three doors**
/// — the lead's fourth guard.
///
/// Each door is pressed by its own press on its own fresh vault, never assumed
/// to share the first one's line: a law written at one door out of three is
/// this house's most expensive trap, and the door this table had fourth was
/// found by a census rather than remembered.
///
/// **That fourth door is deleted** — rule 62, 17 October: it sent the document
/// as it stands, the owner deleted the choice, and the row went with it. The
/// count in the type below is the census, so a door that comes back without
/// this line moving does not compile.
#[test]
fn the_first_number_is_retired_at_every_door() {
    let _guard = serial();
    /// One press on one door, so the table below reads as the three doors it is.
    type Press = fn(SessionId);
    let doors: [(&str, Press); 3] = [
        ("copy, pull and the PDF", |bench| {
            payload_to_take_out(bench).expect("the exit opens");
        }),
        ("send", |bench| {
            let handle = build_payload(bench).expect("payload");
            send(handle, ProviderId { id: "fake".to_string() }).expect("the echo answers");
        }),
        ("a question to a model", |bench| {
            let handle = build_payload(bench).expect("payload");
            ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new())
                .expect("the echo answers");
        }),
    ];

    for (which, (door, press)) in doors.into_iter().enumerate() {
        let _ground = Ground::fresh(&format!("door{which}"));
        the_fake_provider();
        let held = the_first_document(LETTER, Some("Mahnung.txt"));
        answer_everything(held.0);
        let number = conversation_open()
            .expect("open")
            .expect("no session was born when the document entered the preview");
        assert_eq!(kept(number)[0].handle, "doc1", "the first document is not doc1 at «{door}»");
        let blocks = vault_snapshot().expect("snapshot").block_count;
        assert!(blocks > 0, "nothing was protected, so «its blocks stay» measures nothing");

        press(held.0);
        assert!(
            kept(number).is_empty(),
            "the text left by «{door}» and its copy stayed in the session: {:?}",
            kept(number)
        );
        assert_eq!(
            vault_snapshot().expect("snapshot").block_count,
            blocks,
            "leaving by «{door}» took the blocks with it"
        );
        drop(held);

        // **And the number is retired**: the next document is doc2, for ever.
        let next = Bench(open_session(None, "de".to_string()).expect("open"));
        conversation_enter(number, Some(next.0)).expect("enter");
        import_document(
            next.0,
            "Rechnung.txt".to_string(),
            SECOND.as_bytes().to_vec(),
            DocumentKind::Txt,
        )
        .expect("import");
        let rows = kept(number);
        assert_eq!(rows.len(), 1, "{rows:?}");
        assert_eq!(rows[0].handle, "doc2", "a new document took the number «{door}» retired");
        assert_eq!(
            conversations().expect("the list").len(),
            1,
            "a second document began a second session"
        );
    }
}

/// **No empty sessions** — the lead's fifth guard, and the other half of the
/// rule: the container exists because it holds something.
///
/// Opening the app creates nothing. Opening a bench creates nothing. The
/// composer's own empty import — which happens whenever a preview opens with no
/// text in it — creates nothing.
#[test]
fn nothing_is_born_without_a_document() {
    let _guard = serial();
    let _ground = Ground::fresh("empty");
    assert!(conversations().expect("the list").is_empty(), "a fresh vault holds a session");

    let bench = Bench(open_session(None, "de".to_string()).expect("open"));
    assert!(
        conversations().expect("the list").is_empty(),
        "opening a bench with no document in it began a session"
    );
    assert!(conversation_open().expect("open").is_none());

    import_text(bench.0, String::new()).expect("an empty preview is not a refusal");
    assert!(
        conversations().expect("the list").is_empty(),
        "an empty preview began a session: {:?}",
        conversations().expect("the list")
    );
    assert!(conversation_open().expect("open").is_none());
    assert!(
        import_text(bench.0, "   \n  ".to_string()).is_ok(),
        "white space is not a refusal either"
    );
    assert!(
        conversations().expect("the list").is_empty(),
        "white space began a session: {:?}",
        conversations().expect("the list")
    );
}

/// **The saved copy carries the session's own tokens** — the seam inside the
/// birth, and the reason its order is load-bearing.
///
/// A birth re-derives every token on the bench from the session's key
/// (`take_the_names`). A copy written *before* that would hold the names the
/// document wore for the half-second before the session existed — and the
/// person would re-open their document to tokens that no longer match the one
/// the model saw. So the birth comes first and the copy after it, and this
/// guard reds the moment that order is swapped.
#[test]
fn the_saved_copy_carries_the_session_s_own_tokens() {
    let _guard = serial();
    let _ground = Ground::fresh("tokens");
    let held = the_first_document(LETTER, Some("Mahnung.txt"));
    answer_everything(held.0);
    let number = conversation_open().expect("open").expect("one is open");

    let mut on_the_bench: Vec<String> = document_view(held.0)
        .expect("the document")
        .marks
        .iter()
        .filter_map(|m| m.token.clone())
        .collect();
    on_the_bench.sort();
    assert!(!on_the_bench.is_empty(), "nothing is protected, so this measures nothing");
    drop(held);

    let again = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(again.0)).expect("enter");
    open_kept_document(number, 1, false, again.0).expect("open it");
    let mut in_the_copy: Vec<String> = document_view(again.0)
        .expect("the document")
        .marks
        .iter()
        .filter_map(|m| m.token.clone())
        .collect();
    in_the_copy.sort();
    assert_eq!(
        in_the_copy, on_the_bench,
        "the copy was written before the session named the bench, so it holds other tokens"
    );
}

/// **One document is in one session's list, never in two** — the seam this
/// round opens, found by asking what a document's copy belongs to.
///
/// Until rule 55 an import with nothing open kept nothing, so a session begun
/// by hand over an open document — the panel's deliberate clean break, with the
/// bench named — kept it for the first time. Now the document already has a
/// session, and the measurement before this guard was flipped said: «session 1
/// holds doc1, session 2 holds doc1, session 3 holds doc1» — one document, one
/// preview, three lists.
///
/// The copy exists **because** the document is in the preview, so it lives
/// where the preview's session is: when the bench moves, the copy moves with
/// it, and the number it had stays spent in the session it left — a number only
/// ever goes up (rule 54هـ).
#[test]
fn a_document_is_in_one_session_at_a_time() {
    let _guard = serial();
    let _ground = Ground::fresh("onelist");
    let held = the_first_document(LETTER, Some("Mahnung.txt"));
    answer_everything(held.0);
    let first = conversation_open().expect("open").expect("born");
    assert_eq!(kept(first)[0].handle, "doc1");

    // The panel's own door: a session begun by hand, with the bench named.
    conversation_begin("eine andere".to_string(), Some(held.0)).expect("begin");
    let second = conversation_open().expect("open").expect("the second");
    assert_ne!(second, first);
    assert_eq!(
        kept(second).len(),
        1,
        "the document did not move into the session the person began"
    );
    assert_eq!(kept(second)[0].name, "Mahnung.txt");
    assert!(
        kept(first).is_empty(),
        "the document is in two lists at once: session {first} still holds {:?}",
        kept(first)
    );

    // And back again: the number it spent in the first session is spent for
    // ever, so it returns as doc2 rather than taking doc1 twice.
    conversation_enter(first, Some(held.0)).expect("enter");
    assert_eq!(kept(second).len(), 0, "it stayed behind in the session it left");
    let back = kept(first);
    assert_eq!(back.len(), 1, "it did not come back with the bench");
    assert_eq!(back[0].handle, "doc2", "it took a number this session had already spent");
}

/// **A document that arrives with the vault shut has no session — and that is
/// the state 081's birth at the exit still exists for.**
///
/// The census the lead asked for on 16 October: rule 55 made every document in
/// the preview bring a session with it, so «a text that leaves with no
/// session» looked unreachable, and rule 35 («أبسط من البساطة ذاتها») would
/// then have the exit-born session deleted rather than kept as a net.
///
/// It is reachable. A session's key lives in the vault, so there is nowhere to
/// put one while the vault is shut — the birth refuses with `VaultLocked` and
/// the preview keeps the document anyway, which is 089 rule 9's promise and
/// does not depend on the vault. The exits stay live in that state (protection
/// never needed the vault), and the moment the person opens the vault the
/// glass is in exactly the state `Ground.aSessionWouldBeBorn` reports: a
/// document in front of them, no session, and a press that must not refuse.
///
/// So the net is kept, and this is the measurement that says why. If a later
/// round makes the import wait for the vault, or gives the unlock its own
/// birth, this guard is the one that will go red and ask the question again.
#[test]
fn a_document_that_arrives_with_the_vault_shut_has_no_session() {
    let _guard = serial();
    let ground = Ground::fresh("shut");
    vault_lock().expect("lock");

    let bench = the_first_document(LETTER, Some("doc1.txt"));
    assert_eq!(
        conversation_open().expect("ask"),
        None,
        "a session was born with nowhere to keep its key"
    );
    // The document is there, and the exits are live: what is missing is only
    // the drawer to file it in.
    assert!(
        !document_view(bench.0).expect("view").text.is_empty(),
        "the preview lost the document because the vault was shut"
    );

    // The person opens the vault. Nothing has rescanned yet, and nothing
    // begins a session on its own — this is the state the exit's birth is for.
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert_eq!(
        conversation_open().expect("ask"),
        None,
        "unlocking the vault began a session by itself, which would make 081's net unreachable"
    );

    // And the first act that writes a decision gives it one, by rule 55 —
    // which is why the net is a net and not the ordinary path.
    scan(bench.0).expect("scan");
    assert!(
        conversation_open().expect("ask").is_some(),
        "the first act after the vault opened left the document with no session"
    );
    drop(bench);
    drop(ground);
}

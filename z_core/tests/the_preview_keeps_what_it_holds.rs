// 089 rule 9 · **the saved document** — the owner's rule of 15 October 2026,
// late evening: «عنصرنا هو البلوك لا المستند».
//
// Documents are not saved. Their owner has them on his own disk, unencrypted,
// and Z keeps what it protects rather than what it was shown. **The one
// exception is the document in the preview that has not left it**: it is kept
// with the decisions made on it, sealed in the conversation's own file, so that
// a power cut finds it as it was left. Leaving by a door — send, copy, pull,
// PDF — takes it out of the conversation and retires its number for ever. Its
// blocks stay in the vault.
//
// What is measured here is every clause of that rule, including the one that is
// easiest to write and hardest to keep: **each** door that takes text out
// takes the copy with it. The core has three such doors (G28's own census), and
// each of them is driven by its own guard below, because a law written at one
// door out of three is this house's most expensive trap.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein genügend langes kennwort für die vorschau";
const MODEL: &str = "the-model-the-person-saw";

/// A German line the pack finds two names and an identifier in, so a kept
/// document has real decisions on it rather than an empty mark list.
const LETTER: &str = "Kundennummer 8841-2270 für Herrn Stefan Keller, Nordstern Consulting GmbH.";

/// A second document, so «the next number» is measured on a real second one.
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
            std::env::temp_dir().join(format!("zprivacy-089-preview-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
        vault_create_with_passphrase(PASS.to_string()).expect("vault");
        Self(dir)
    }

    /// A restart, as far as anything stored can tell: every bench closed, the
    /// vault locked — which drops the key and the open session's number — and
    /// opened again, which reads the files from the disk.
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

/// **A conversation that already exists, and a document opened into it.**
///
/// The order is the owner's own: a session is entered (or born) and *then* a
/// document is opened. A document opened before any session exists is kept at
/// the birth instead, which is measured in its own guard below.
fn a_conversation_holding(text: &str, name: Option<&str>) -> (Bench, u32) {
    let first = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_begin("die Mahnung".to_string(), Some(first.0)).expect("begin");
    let number = conversation_open().expect("open").expect("one is open");
    drop(first);

    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(held.0)).expect("enter");
    match name {
        Some(name) => {
            import_document(held.0, name.to_string(), text.as_bytes().to_vec(), DocumentKind::Txt)
                .expect("import a file");
        }
        None => {
            import_text(held.0, text.to_string()).expect("import a text");
        }
    }
    answer_everything(held.0);
    (held, number)
}

fn kept(number: u32) -> Vec<KeptRow> {
    kept_documents(number).expect("the kept documents")
}

/// **A document in the preview survives a restart with every decision on it.**
#[test]
fn the_preview_survives_a_restart_with_its_decisions() {
    let _guard = serial();
    let ground = Ground::fresh("restart");
    let (held, number) = a_conversation_holding(LETTER, Some("Mahnung.txt"));

    let rows = kept(number);
    assert_eq!(rows.len(), 1, "the preview was not kept: {rows:?}");
    assert_eq!(rows[0].handle, "doc1", "a file from the computer is not a docN");
    assert!(!rows[0].chat, "a file pulled from the computer was kept as a chat");
    assert_eq!(rows[0].name, "Mahnung.txt", "the file's own name was not kept");
    let marks = rows[0].protected;
    assert!(marks >= 3, "{marks} protected places were kept for a line that protects three");

    // The app closes and opens again. Nothing of this run is left.
    drop(held);
    ground.restart();
    let rows = kept(number);
    assert_eq!(rows.len(), 1, "the saved document did not survive the file");
    assert_eq!(rows[0].protected, marks, "the decisions on it did not survive");

    // And it opens as it was left: the same text, the same marks, and **no
    // question is asked again** — nothing waits for a word.
    let again = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(again.0)).expect("enter");
    open_kept_document(number, rows[0].number, rows[0].chat, again.0).expect("open it");
    let view = document_view(again.0).expect("the document");
    assert_eq!(
        view.marks.len() as u32, marks,
        "it came back with {} marks, not the {marks} it was left with",
        view.marks.len()
    );
    assert!(
        list_findings(again.0).expect("findings").iter().all(|f| f.state != MarkState::Suggested),
        "re-opening asked again about a word the person had already answered"
    );
    // **And it is the document it was**: a restored file does not describe
    // itself as something else. The name is the one it had, which the row
    // already said, and the band reads the kind and the pages from here.
    assert_eq!(view.name, "Mahnung.txt", "it came back under another name");
    assert_eq!(view.kind, DocumentKind::Txt, "it came back as another kind of file");
    assert_eq!(view.pages, 1, "it came back with a page count it never had");
    // The protected text is the text that would leave, so the names are still
    // under their tokens: the store was rebuilt from the marks.
    let out = payload_to_take_out(again.0).expect("the exit opens");
    assert!(!out.text.contains("Stefan"), "a protected name came back in the clear");
    assert!(out.text.contains("__Z_"), "nothing in the restored document is protected");
}

/// **The copy follows the decisions — including «Here»** — rule 9, and rule 6's
/// other half: «Here» uncovers one place, and it is remembered with the saved
/// document.
///
/// A copy written once, when the document arrived, would hold the state it had
/// before the person did anything to it — and «a power cut finds it as it was
/// left» is a promise about exactly what they did. So: one more word protected
/// by hand, then one place uncovered, and the copy says so after a restart,
/// with no number spent on either act.
#[test]
fn the_copy_follows_every_decision() {
    let _guard = serial();
    let ground = Ground::fresh("follows");
    let (held, number) = a_conversation_holding(LETTER, Some("Mahnung.txt"));
    let first = kept(number);
    assert_eq!(first.len(), 1);
    let was = first[0].protected;

    // One more word, by hand — a word no rule found: the company's town.
    let at = LETTER.find("Nordstern").expect("the fixture");
    let start: usize = LETTER[..at].chars().map(char::len_utf16).sum();
    let span = Span {
        start: start as u32,
        end: (start + "Nordstern".chars().map(char::len_utf16).sum::<usize>()) as u32,
    };
    // It is inside a protected item, so this is the reach the glass offers for
    // it: whatever the outcome, the copy must say the same as the bench.
    let _ = protect(held.0, span, Scope::Conversation, Kind::Company);
    let on_the_bench = document_view(held.0).expect("the document").marks.len() as u32;
    let rows = kept(number);
    assert_eq!(rows.len(), 1, "a second act made a second document");
    assert_eq!(rows[0].handle, "doc1", "a second act spent a second number");
    assert_eq!(
        rows[0].protected, on_the_bench,
        "the copy holds {} marks and the bench {on_the_bench}: it was written once and left behind",
        rows[0].protected
    );
    assert!(was > 0, "nothing was protected to begin with, so this measures nothing");

    // **«Here»** — one place uncovered, and the copy remembers that too.
    let keller = LETTER.find("Keller").expect("the fixture");
    let kstart: usize = LETTER[..keller].chars().map(char::len_utf16).sum();
    let one = Span {
        start: kstart as u32,
        end: (kstart + "Keller".chars().map(char::len_utf16).sum::<usize>()) as u32,
    };
    let undone = unprotect(held.0, one).expect("here");
    assert!(matches!(undone, UndoOutcome::Undone { .. }), "{undone:?}");
    let after = document_view(held.0).expect("the document").marks.len() as u32;
    assert!(after < on_the_bench, "«here» uncovered nothing on the bench");
    assert_eq!(
        kept(number)[0].protected, after,
        "«here» was not remembered with the saved document"
    );

    // And after a restart it opens with exactly that state.
    drop(held);
    ground.restart();
    let again = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(again.0)).expect("enter");
    open_kept_document(number, 1, false, again.0).expect("open it");
    assert_eq!(
        document_view(again.0).expect("the document").marks.len() as u32,
        after,
        "it came back in a state the person never left it in"
    );
}

/// **A second document gets the next number, and a chat has its own sequence.**
#[test]
fn a_second_document_takes_the_next_number() {
    let _guard = serial();
    let _ground = Ground::fresh("numbers");
    let (first, number) = a_conversation_holding(LETTER, Some("Mahnung.txt"));
    drop(first);

    // A second file, in the same conversation.
    let second = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(second.0)).expect("enter");
    import_document(second.0, "Rechnung.txt".to_string(), SECOND.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("import");
    answer_everything(second.0);
    drop(second);

    // And a text written into the preview rather than pulled from the computer.
    let chat = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(chat.0)).expect("enter");
    import_text(chat.0, "Frau Katrin Sommer hat angerufen.".to_string()).expect("import");
    answer_everything(chat.0);
    drop(chat);

    let rows = kept(number);
    let handles: Vec<&str> = rows.iter().map(|r| r.handle.as_str()).collect();
    assert_eq!(rows.len(), 3, "the conversation holds {} documents, not three", rows.len());
    assert!(handles.contains(&"doc1"), "{handles:?}");
    assert!(handles.contains(&"doc2"), "{handles:?}");
    assert!(
        handles.contains(&"chat1"),
        "a text moved into the preview did not take the chat sequence: {handles:?}"
    );
}

/// **Going back from the preview does not take it out** — and nothing is asked.
///
/// «Back» is the absence of an act: the bench is closed and the copy stays. So
/// what is measured is that closing a bench — which is what going back does on
/// the glass — leaves the document in the conversation.
#[test]
fn going_back_keeps_it() {
    let _guard = serial();
    let _ground = Ground::fresh("back");
    let (held, number) = a_conversation_holding(LETTER, Some("Mahnung.txt"));
    assert_eq!(kept(number).len(), 1);
    drop(held); // the bench closes, which is «back»
    assert_eq!(kept(number).len(), 1, "going back took the document out of the conversation");
}

/// **Leaving by the manual door takes it out and retires its number** — copy,
/// pull and the PDF all come through `payload_to_take_out`.
#[test]
fn the_manual_door_takes_it_out() {
    let _guard = serial();
    let _ground = Ground::fresh("manual");
    let (held, number) = a_conversation_holding(LETTER, Some("Mahnung.txt"));
    assert_eq!(kept(number)[0].handle, "doc1");
    let blocks = vault_snapshot().expect("snapshot").block_count;
    assert!(blocks > 0, "nothing was protected, so «its blocks stay» measures nothing");

    payload_to_take_out(held.0).expect("the exit opens");
    assert!(
        kept(number).is_empty(),
        "the text left and its copy stayed in the conversation: {:?}",
        kept(number)
    );
    // **Its blocks stay in the vault.** What leaves the conversation is the
    // copy of the document, never what the person protected.
    assert_eq!(
        vault_snapshot().expect("snapshot").block_count,
        blocks,
        "leaving by a door took the blocks with it"
    );
    drop(held);

    // **And the number is retired**: the next document in this conversation is
    // doc2, never doc1 again.
    let next = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(next.0)).expect("enter");
    import_document(next.0, "Rechnung.txt".to_string(), SECOND.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("import");
    let rows = kept(number);
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].handle, "doc2", "a new document took a retired number");
}

/// **The same law at the send door** — the second of the three, driven by its
/// own press rather than assumed to share the first one's line.
#[test]
fn the_send_door_takes_it_out() {
    let _guard = serial();
    let _ground = Ground::fresh("send");
    the_fake_provider();
    let (held, number) = a_conversation_holding(LETTER, Some("Mahnung.txt"));
    assert_eq!(kept(number).len(), 1);

    let handle = build_payload(held.0).expect("payload");
    send(handle, ProviderId { id: "fake".to_string() }).expect("the echo answers");
    assert!(
        kept(number).is_empty(),
        "the document went to a model and its copy stayed behind: {:?}",
        kept(number)
    );
}

/// **And at the third door** — `ask_model`, the protected door with a question.
#[test]
fn the_model_door_takes_it_out() {
    let _guard = serial();
    let _ground = Ground::fresh("askmodel");
    the_fake_provider();
    let (held, number) = a_conversation_holding(LETTER, Some("Mahnung.txt"));
    assert_eq!(kept(number).len(), 1);

    let handle = build_payload(held.0).expect("payload");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new(), Vec::new())
        .expect("the echo answers");
    assert!(
        kept(number).is_empty(),
        "the document went through the gateway and its copy stayed behind: {:?}",
        kept(number)
    );
}

// **The fourth door is deleted, and the census is three** — rule 62, the owner
// on 17 October.
//
// A guard stood here for the door that sent the document as it stands: the
// census of 089 rule 9 found it after the other three had been written, and it
// took the preview's copy with it like every other exit. The owner deleted the
// choice behind it, so the door is gone from the core and this guard with it —
// what is left are the three above, and G36 counts them by what they do rather
// than from a list anybody keeps.

/// **«Rename» changes the name and not the number.**
#[test]
fn rename_changes_the_name_and_not_the_number() {
    let _guard = serial();
    let ground = Ground::fresh("rename");
    let (held, number) = a_conversation_holding(LETTER, Some("Mahnung.txt"));
    drop(held);

    rename_kept_document(number, 1, false, "  Die zweite Mahnung  ".to_string()).expect("rename");
    ground.restart();
    let rows = kept(number);
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].name, "Die zweite Mahnung", "the name was not cleaned and kept");
    assert_eq!(rows[0].handle, "doc1", "the number moved with the name");
    assert_eq!(rows[0].number, 1);

    // A name with nothing in it is refused rather than stored: a row a person
    // cannot tell from another row is the defect a handle exists to prevent.
    assert!(rename_kept_document(number, 1, false, "   ".to_string()).is_err());
    // And a document this conversation is not holding is refused by name.
    assert!(rename_kept_document(number, 9, false, "nichts".to_string()).is_err());
}

/// **A session begun by hand over an open document keeps that document.**
///
/// The birth takes the bench's names, and the same call keeps what the bench is
/// holding — so a document in the preview is in the list of whichever session
/// the person is in, by the one act rather than by two that could disagree.
///
/// **This guard was reversed on 16 October** (rule 55). Until then it measured
/// the opposite half of the same law: an import with no session open kept
/// nothing, because a number is a number *in* a session and there was none —
/// and the birth was the first instant one could be written. The owner moved
/// that instant to the document itself: a document now births the session it
/// is kept in, which `the_session_is_born_at_the_first_document.rs` measures.
/// What is left here is the hand-written birth, which is still a real door —
/// the panel's deliberate clean break, with the bench named.
#[test]
fn a_session_begun_by_hand_keeps_the_open_document() {
    let _guard = serial();
    let _ground = Ground::fresh("birth");
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_document(held.0, "Mahnung.txt".to_string(), LETTER.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("import");
    answer_everything(held.0);

    conversation_begin("die Mahnung".to_string(), Some(held.0)).expect("begin");
    let number = conversation_open().expect("open").expect("one is open");
    let rows = kept(number);
    assert_eq!(rows.len(), 1, "the document on the bench is not in the session that was begun");
    assert_eq!(rows[0].handle, "doc1");
    assert_eq!(rows[0].name, "Mahnung.txt");
    assert!(rows[0].protected >= 3, "it was kept without the decisions on it");
}

/// **A session written before this round holds no documents, and says so.**
#[test]
fn an_older_session_holds_none() {
    let _guard = serial();
    let _ground = Ground::fresh("older");
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_begin("die Mahnung".to_string(), Some(held.0)).expect("begin");
    let number = conversation_open().expect("open").expect("one is open");
    assert!(
        kept(number).is_empty(),
        "a conversation with no document on the bench is holding one"
    );
    // And a number no session has is an empty answer rather than a refusal:
    // the Sessions room asks about every row it draws.
    assert!(kept_documents(9999).expect("no such session").is_empty());
}

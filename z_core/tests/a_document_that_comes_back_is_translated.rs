// 079 · **A document that comes back** — the import side, and the other half of
// the answer page the export side prints.
//
// A z-pdf leaves this machine with the conversation's tokens standing where the
// values stood, and a last page whose top line is «Z-pdf : » and the session's
// own token for «Zprivacy-svara». What comes back — the same pages with the
// answer written on them, a reply typed under them, a model's rewrite — carries
// those tokens, and until today nothing read them: the import door scanned the
// text (item 3), left every token alone (item 5, 079 rule 5), and handed back a
// German letter with `__Z_7F3A_PERSON_…__` standing in it as prose.
//
// What is measured here is the door, on the owner's own German fixture:
//
//   * **the same bench** — the conversation whose store minted the names is
//     still in memory, so every one of them comes back;
//   * **another bench of the same conversation, with the vault taught
//     nothing** — every name still comes back, because every word that took a
//     token is a block in the vault and a block is never deleted (089, the
//     owner's rule of 15 October). The two guards below were the other way
//     round until that rule landed: they asserted that a name nobody taught
//     came back from nowhere, which was the trade the owner rejected —
//     «أعتقد أنني كنت واضحاً أن الحماية ستكون دائمة»;
//   * **the answer page still proves where the document came from**, which is
//     the one thing that needs no block and no bench: its word is known in
//     advance;
//   * **another machine's namespace** — named by its four hex digits, because a
//     document from a conversation this vault does not hold is a true thing to
//     be told and not an error;
//   * **two namespaces in one document** — grouped, and each resolved against
//     its own conversation;
//   * and **the door writes nothing**: not a turn, not the vault, not a
//     protection, and the revision does not move.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein genügend langes kennwort für eine antwortseite";

/// The owner's own second reminder — a real German letter, not a string built
/// to be convenient. Eight values are protected by the pack and five more wait
/// for a word; the ones that wait are answered before anything leaves, because
/// the exit's own law refuses while a word waits (083a).
const LETTER: &str = include_str!("fixtures/Mahnung_Keller.txt");

/// The word the answer page protects. Written out rather than imported: the
/// core keeps it crate-private, and a change to it belongs in a red here.
const WORD: &str = "Zprivacy-svara";

/// What the person's correspondent writes under the protected pages. Two
/// sentences of ordinary German, so that «nothing was brought back» can be told
/// from «nothing is here».
const REPLY: &str = "\nIhre Zahlung ist bei uns eingegangen. Wir haben den Vorgang abgeschlossen.\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-079-back-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    dir
}

/// A bench that closes itself even when a test panics.
struct Bench(SessionId);

impl Drop for Bench {
    fn drop(&mut self) {
        close_session(self.0).ok();
    }
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("the fixture does not contain its own needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

/// Every token in a text, by its marks and in the order they stand.
fn tokens_in(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut at = 0usize;
    while let Some(rest) = text.get(at..) {
        let Some(open) = rest.find("__Z_") else { break };
        let start = at + open;
        let after = start + "__Z_".len();
        let Some(close) = text[after..].find("__") else { break };
        let end = after + close + "__".len();
        if !out.contains(&text[start..end].to_string()) {
            out.push(text[start..end].to_string());
        }
        at = end;
    }
    out
}

fn read(segments: &[Segment]) -> String {
    segments.iter().map(|s| s.text.as_str()).collect()
}

/// Say «protect» to every word that waits, so the exit's own law opens.
fn answer_everything(bench: SessionId) {
    let waiting: Vec<u32> = list_findings(bench)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| f.id)
        .collect();
    for id in waiting {
        answer_finding(bench, id, FindingAnswer::Protect).expect("answer");
    }
}

/// The letter on a bench, every word answered, and what the exit hands out.
///
/// The five suggestions are protected rather than skipped: this is the document
/// a person actually sends, and the exit refuses while one of them waits.
fn a_letter_that_has_left() -> (Bench, String, String) {
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, LETTER.to_string()).expect("import");
    // The scan came with the document (item 3). What **waits** is answered —
    // `list_findings` hands back every mark it made, and five of the thirteen
    // are the ones a person has to say a word about.
    let waiting: Vec<Finding> = list_findings(held.0)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .collect();
    assert_eq!(waiting.len(), 5, "this fixture leaves five words waiting, not {}", waiting.len());
    for finding in waiting {
        answer_finding(held.0, finding.id, FindingAnswer::Protect).expect("answer");
    }
    let view = payload_to_take_out(held.0).expect("nothing waits, so the exit opens");
    let token = view
        .answer_page_token
        .clone()
        .expect("the exit handed out no token for the answer page");
    (held, view.text, token)
}

/// The document that comes back: the protected pages, the correspondent's
/// reply, and the answer page's own line at the end.
fn what_came_back(safe: &str, answer_page: &str) -> String {
    format!("{safe}{REPLY}\nZ-pdf : {answer_page}\n")
}

/// **The conversation that sent it is still open: every name comes back.**
#[test]
fn the_same_conversation_reads_every_name_back() {
    let _guard = serial();
    let dir = fresh_vault("same");
    let (held, _, _) = a_letter_that_has_left();
    conversation_begin("die Mahnung".to_string(), Some(held.0)).expect("begin");
    // The birth renames every token, so the text that left is the text after it.
    let taken = payload_to_take_out(held.0).expect("take out");
    let safe = taken.text.clone();
    let page = taken.answer_page_token.clone().expect("a page token after the birth");
    let names = tokens_in(&safe);
    // Sixteen marks, fourteen names: the IBAN and the invoice number each stand
    // twice, and one value is one token. **Three more than when this was first
    // measured**, because 085 ruling 1 landed on the rules the next day: each
    // of the letter's three people is a given name and a surname, and a token
    // never covers more than one word.
    assert_eq!(names.len(), 14, "the letter left with {} names, not 14", names.len());

    // The answer arrives on this same bench — a pasted page, which is the one
    // door that does not open a new one.
    let back = what_came_back(&safe, &page);
    import_text(held.0, back.clone()).expect("the answer is imported");
    let seen = returning_document(held.0).expect("read it back");

    // Places, with the page's own: the letter's sixteen marks and the page.
    assert_eq!(seen.tokens, 17, "the returning document holds {} places", seen.tokens);
    assert_eq!(seen.names, names.len() as u32, "it holds {} names", seen.names);
    assert_eq!(seen.brought_back, names.len() as u32, "not every name came back");
    assert_eq!(
        seen.names,
        seen.brought_back + seen.unresolved.len() as u32,
        "a name fell between «came back» and «did not»"
    );
    assert!(seen.unresolved.is_empty(), "names were left as tokens: {:?}", seen.unresolved);
    assert!(seen.unknown_namespaces.is_empty(), "{:?}", seen.unknown_namespaces);
    assert_eq!(seen.conversations.len(), 1, "{:?}", seen.conversations);
    let from = &seen.conversations[0];
    assert_eq!(from.name, "die Mahnung");
    assert!(from.answer_page, "the answer page's token did not prove the origin");
    assert_eq!(from.brought_back, names.len() as u32);
    assert_eq!(from.unresolved, 0);

    // The reading is the letter the person wrote, their correspondent's reply,
    // and the page's own word — no token left standing anywhere in it.
    let text = read(&seen.restored);
    assert!(text.contains("Stefan Keller"), "the person's own name did not come back");
    assert!(text.contains("DE89 3704 0044 0532 0130 00"), "the IBAN did not come back");
    assert!(text.contains("b.hoffmann@muster-handel.de"), "the address did not come back");
    assert!(text.contains("Ihre Zahlung ist bei uns eingegangen"), "the reply was dropped");
    assert!(text.ends_with(&format!("Z-pdf : {WORD}\n")), "the page did not read as its own word");
    assert!(!text.contains("__Z_"), "a token is still standing in the reading");

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **The bench that protected it is gone, and nothing was ever taught: every
/// name comes back.**
///
/// 089 rule 1, the owner's own: «كل كلمة يأخذ رمزاً… هي بلوك غير قابل للحذف من
/// خزنة المستخدم». Every word this letter protected — by the pack, by a
/// confirmed suggestion, by a hand — is a block in `vault.zv`, so the door back
/// is a lookup and not a search. **Nothing is taught here**: this used to teach
/// two values and assert that the other twelve names came back from nowhere,
/// and that assertion was the trade of 083e/079 which the owner withdrew.
///
/// The two taught values stay in the run as the control: a word the vault holds
/// as a value *and* as a block comes back once, by either road.
#[test]
fn every_protected_name_comes_back_after_the_bench_is_gone() {
    let _guard = serial();
    let dir = fresh_vault("taught");

    // Taught before anything is protected, under an identity, as the vault
    // screen teaches one: the policy is `Always`, which is what «remember this»
    // means on that screen.
    let who = create_entity(EntityKind::Person, "Stefan Keller".to_string(), None).expect("entity");
    set_value(who, None, Kind::Person, "Stefan Keller".to_string(), Policy::Always).expect("value");
    let account = create_entity(EntityKind::Company, "Muster Handel".to_string(), None).expect("entity");
    set_value(
        account,
        None,
        Kind::Iban,
        "DE89 3704 0044 0532 0130 00".to_string(),
        Policy::Always,
    )
    .expect("value");

    let (held, _, _) = a_letter_that_has_left();
    conversation_begin("die Mahnung".to_string(), Some(held.0)).expect("begin");
    let taken = payload_to_take_out(held.0).expect("take out");
    let safe = taken.text.clone();
    let page = taken.answer_page_token.clone().expect("a page token");
    let names = tokens_in(&safe);
    let back = what_came_back(&safe, &page);
    let number = conversation_open().expect("open").expect("a session is open");

    // The bench that minted them is closed — which is what opening the answer
    // as a document does on the glass — and the conversation is entered again.
    drop(held);
    let next = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(next.0)).expect("enter");
    import_text(next.0, back).expect("the answer is imported");
    let seen = returning_document(next.0).expect("read it back");

    assert_eq!(seen.conversations.len(), 1, "{:?}", seen.conversations);
    assert!(seen.conversations[0].answer_page, "the page did not prove the origin");
    assert_eq!(seen.conversations[0].number, number);
    assert_eq!(
        seen.brought_back,
        names.len() as u32,
        "{} of {} names came back after the bench was gone",
        seen.brought_back,
        names.len()
    );
    assert_eq!(
        seen.names,
        seen.brought_back + seen.unresolved.len() as u32,
        "a name fell between «came back» and «did not»"
    );
    assert!(
        seen.unresolved.is_empty(),
        "a word that took a token did not become a block: {:?}",
        seen.unresolved
    );
    let text = read(&seen.restored);
    assert!(text.contains("Stefan Keller"), "the taught name did not come back");
    assert!(text.contains("DE89 3704 0044 0532 0130 00"), "the taught IBAN did not come back");
    assert!(
        text.contains("Beate Hoffmann"),
        "a name nobody taught the vault did not come back, so its block was never made"
    );
    assert!(!text.contains("__Z_"), "a token is still standing in the reading");
    // The pieces and the numbers are one fact, and now they say the same thing
    // from the other side: not one piece of this reading is a token left
    // standing, and the restored pieces are more than the names because two of
    // those names stand twice.
    let standing: Vec<String> = seen
        .restored
        .iter()
        .filter(|s| s.piece == Piece::Unresolved)
        .map(|s| s.text.clone())
        .collect();
    assert!(standing.is_empty(), "a token was left standing in the pieces: {standing:?}");
    let restored = seen.restored.iter().filter(|s| s.piece == Piece::Restored).count();
    assert!(
        restored > names.len(),
        "{restored} pieces came back for {} names, so a place was missed",
        names.len()
    );

    drop(next);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **The answer page proves the origin on its own** — with nothing taught and
/// the bench gone, the page's word is read from no block at all.
///
/// Its word is known in advance (`ANSWER_PAGE_WORD`), so one derivation under
/// each conversation's key names the origin. That is why this guard keeps its
/// own run now that the blocks bring the names back: the page must still speak
/// where nothing else could, and it is **not counted** among the names.
#[test]
fn the_answer_page_proves_the_origin_on_its_own() {
    let _guard = serial();
    let dir = fresh_vault("untaught");
    let (held, _, _) = a_letter_that_has_left();
    conversation_begin("die Mahnung".to_string(), Some(held.0)).expect("begin");
    let taken = payload_to_take_out(held.0).expect("take out");
    let safe = taken.text.clone();
    let page = taken.answer_page_token.clone().expect("a page token");
    let names = tokens_in(&safe);
    let back = what_came_back(&safe, &page);
    let number = conversation_open().expect("open").expect("a session is open");
    drop(held);

    let next = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(next.0)).expect("enter");
    import_text(next.0, back).expect("import");
    let seen = returning_document(next.0).expect("read it back");

    assert_eq!(
        seen.brought_back,
        names.len() as u32,
        "the blocks did not bring back every name: {:?}",
        seen.unresolved
    );
    assert_eq!(seen.names, names.len() as u32);
    assert_eq!(seen.conversations.len(), 1, "{:?}", seen.conversations);
    assert!(
        seen.conversations[0].answer_page,
        "the page is the proof of origin that needs nothing stored — and it did not speak"
    );
    assert_eq!(seen.conversations[0].unresolved, 0);
    // The page's own word is read and **not counted**: the names in that number
    // are the person's, and this one is ours.
    assert_eq!(seen.conversations[0].brought_back, names.len() as u32);
    assert!(seen.unknown_namespaces.is_empty(), "its own namespace was called unknown");
    // The page's own word is still read, because it is ours and known in
    // advance: the person sees «Z-pdf : Zprivacy-svara» and not a token.
    assert!(read(&seen.restored).contains(&format!("Z-pdf : {WORD}")));

    drop(next);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **A namespace this vault does not hold is named, not swallowed.**
#[test]
fn a_document_from_another_machine_says_so() {
    let _guard = serial();
    let dir = fresh_vault("elsewhere");
    let next = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_begin("eine neue Sitzung".to_string(), Some(next.0)).expect("begin");
    import_text(
        next.0,
        "Sehr geehrter Herr __Z_7f3a_PERSON_9b21__,\n\nIhre IBAN __Z_7f3a_IBAN_4c18__ ist notiert.\n"
            .to_string(),
    )
    .expect("import");
    let seen = returning_document(next.0).expect("read it back");

    assert_eq!(seen.tokens, 2);
    assert_eq!(seen.names, 2);
    assert_eq!(seen.brought_back, 0);
    assert_eq!(seen.unresolved.len(), 2);
    assert!(seen.conversations.is_empty(), "{:?}", seen.conversations);
    assert_eq!(
        seen.unknown_namespaces,
        vec!["7f3a".to_string()],
        "the namespace no conversation here names was not said out loud"
    );
    assert!(
        read(&seen.restored).contains("__Z_7f3a_PERSON_9b21__"),
        "a token that could not be read was dropped from the reading"
    );

    drop(next);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **Two conversations in one document: grouped by namespace, each resolved
/// against its own.**
///
/// The owner's «قارن هذا بذاك» in its hardest form — one page carrying the
/// names of two sessions. The one whose bench is open reads; the other is
/// named, with its own count, and the two are never mixed.
#[test]
fn two_namespaces_are_two_conversations() {
    let _guard = serial();
    let dir = fresh_vault("two");

    // The first conversation sends its letter and is then closed.
    let first = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(first.0, "Kundennummer 8841-2270 für Herrn Stefan Keller.".to_string())
        .expect("import");
    answer_everything(first.0);
    conversation_begin("die erste".to_string(), Some(first.0)).expect("begin");
    let theirs = payload_to_take_out(first.0).expect("take out").text;
    let their_names = tokens_in(&theirs);
    assert!(!their_names.is_empty(), "the first conversation protected nothing");
    drop(first);

    // The second protects a value of its own and keeps its bench open.
    let second = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(second.0, "Ansprechpartnerin ist Frau Beate Hoffmann.".to_string())
        .expect("import");
    answer_everything(second.0);
    conversation_begin("die zweite".to_string(), Some(second.0)).expect("begin");
    let ours = payload_to_take_out(second.0).expect("take out").text;
    let our_names = tokens_in(&ours);
    assert!(!our_names.is_empty(), "the second conversation protected nothing");

    // One page carrying both.
    import_text(second.0, format!("{theirs}\n{ours}\n")).expect("import");
    let seen = returning_document(second.0).expect("read it back");

    assert_eq!(seen.conversations.len(), 2, "{:?}", seen.conversations);
    let open = seen.conversations.iter().find(|c| c.name == "die zweite").expect("the second");
    let shut = seen.conversations.iter().find(|c| c.name == "die erste").expect("the first");
    assert_eq!(open.brought_back, our_names.len() as u32, "the open conversation read nothing");
    assert_eq!(open.unresolved, 0);
    // **The closed conversation reads too, and from its blocks.** It did until
    // today only while its bench was in memory; now the words it protected are
    // blocks, and a block belongs to the person rather than to a bench.
    assert_eq!(
        shut.brought_back, their_names.len() as u32,
        "the closed conversation's names did not come back: {} of {}",
        shut.brought_back,
        their_names.len()
    );
    assert_eq!(shut.unresolved, 0);
    assert!(!open.answer_page && !shut.answer_page, "no page was in this document");
    let text = read(&seen.restored);
    assert!(text.contains("Beate Hoffmann"), "the open conversation's own name did not come back");
    assert!(text.contains("Stefan Keller"), "the closed conversation's name did not come back");
    assert!(text.contains("8841-2270"), "the closed conversation's identifier did not come back");
    assert!(!text.contains("__Z_"), "a token is still standing in the reading");

    drop(second);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **The door reads: no turn is written, the vault is untouched, nothing is
/// protected, and the revision does not move.**
///
/// The lead's ruling, measured rather than asserted in prose: if a later round
/// offers «open this conversation to bring back the rest», it is a button and
/// not a side effect of looking.
#[test]
fn the_door_only_reads() {
    let _guard = serial();
    let dir = fresh_vault("reads");
    let (held, _, _) = a_letter_that_has_left();
    conversation_begin("die Mahnung".to_string(), Some(held.0)).expect("begin");
    let number = conversation_open().expect("open").expect("a session is open");
    let taken = payload_to_take_out(held.0).expect("take out");
    let page = taken.answer_page_token.clone().expect("a page token");
    let back = what_came_back(&taken.text, &page);
    import_text(held.0, back).expect("import");

    let before_turns = conversation_turns(number, Some(held.0)).expect("turns").len();
    let before_tokens = list_tokens(held.0).expect("tokens").len();
    let before_marks = document_view(held.0).expect("view").marks.len();
    let before_revision = session_revision(held.0).expect("revision").n;
    let vault_file = dir.join("vault.zv");
    let before_bytes = std::fs::read(&vault_file).expect("the vault file");

    let once = returning_document(held.0).expect("read");
    let twice = returning_document(held.0).expect("read again");
    assert_eq!(read(&once.restored), read(&twice.restored), "reading it twice read two things");
    assert_eq!(once.brought_back, twice.brought_back);

    assert_eq!(
        conversation_turns(number, Some(held.0)).expect("turns").len(),
        before_turns,
        "the door wrote a turn"
    );
    assert_eq!(list_tokens(held.0).expect("tokens").len(), before_tokens, "the door minted a token");
    assert_eq!(
        document_view(held.0).expect("view").marks.len(),
        before_marks,
        "the door protected something"
    );
    assert_eq!(
        session_revision(held.0).expect("revision").n,
        before_revision,
        "the door moved the revision, so every handle built before it went stale"
    );
    assert_eq!(
        std::fs::read(&vault_file).expect("the vault file"),
        before_bytes,
        "the door wrote to the vault"
    );

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **With the vault shut the door names nothing, and says that it is shut.**
///
/// The namespace is four hex of a key derived from the conversation's own 32
/// bytes, and a locked vault has forgotten the master key those hang off — so
/// there is no conversation to compare a namespace with. Reporting it as one
/// «this vault does not hold» would be a false fact written in the core and
/// read out by every screen; `vault` says why instead.
///
/// And the places are still counted, because they are a property of the text:
/// a person is told there are names of ours in this document and which act
/// would read them.
#[test]
fn with_the_vault_shut_nothing_is_named_and_nothing_is_called_unknown() {
    let _guard = serial();
    let dir = fresh_vault("shut");
    let (held, _, _) = a_letter_that_has_left();
    conversation_begin("die Mahnung".to_string(), Some(held.0)).expect("begin");
    let taken = payload_to_take_out(held.0).expect("take out");
    let safe = taken.text.clone();
    let page = taken.answer_page_token.clone().expect("a page token");
    let names = tokens_in(&safe);
    let back = what_came_back(&safe, &page);
    // The bench that minted them is gone, and the vault is shut behind it.
    drop(held);
    vault_lock().expect("lock");

    let next = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(next.0, back.clone()).expect("import");
    let shut = returning_document(next.0).expect("read it back");
    assert_ne!(shut.vault, VaultState::Unlocked, "the vault did not lock");
    assert_eq!(shut.tokens, 17, "the places are a property of the text, and were not counted");
    // **Fifteen names, not fourteen** — and the extra one is the answer page's own
    // token. It is told from the others by deriving the word it protects under
    // the conversation's key, which is exactly what a shut vault cannot do, so
    // with no vault open it is a token like any other. Measured rather than
    // smoothed over: it is the honest answer, and the sentence a person reads
    // is «unlock or create your vault and Z can look for them».
    assert_eq!(shut.names, names.len() as u32 + 1);
    assert_eq!(shut.brought_back, 0);
    assert!(shut.conversations.is_empty(), "a conversation was named with no key to name it by");
    assert!(
        shut.unknown_namespaces.is_empty(),
        "a namespace was called one this vault does not hold, with no vault open to hold it: {:?}",
        shut.unknown_namespaces
    );

    // And the moment the vault opens, the same text names its conversation and
    // reads every name back — which is the control twice over: «nothing was
    // named» above is the lock and not a dead door, and the blocks that answer
    // here are the ones the lock was keeping from us. 089: a locked vault is a
    // standing door, and the sentence on the glass says to unlock it.
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    let open = returning_document(next.0).expect("read it again");
    assert_eq!(open.vault, VaultState::Unlocked);
    assert_eq!(open.conversations.len(), 1, "{:?}", open.conversations);
    assert_eq!(open.conversations[0].name, "die Mahnung");
    assert!(open.conversations[0].answer_page, "the page did not prove the origin");
    assert_eq!(
        open.brought_back,
        names.len() as u32,
        "the unlocked vault did not read its own blocks back: {:?}",
        open.unresolved
    );

    drop(next);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **A document with no token in it is not a returning document**, and the door
/// says so in one number rather than leaving a screen to compare two lists.
#[test]
fn an_ordinary_document_is_not_one() {
    let _guard = serial();
    let dir = fresh_vault("ordinary");
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, LETTER.to_string()).expect("import");
    let seen = returning_document(held.0).expect("read");
    assert_eq!(seen.tokens, 0, "the owner's own letter was read as a returning document");
    assert_eq!(seen.names, 0);
    assert_eq!(seen.brought_back, 0);
    assert!(seen.unresolved.is_empty());
    assert!(seen.conversations.is_empty());
    assert!(seen.unknown_namespaces.is_empty());
    // The reading is the document, whole and in one piece.
    assert_eq!(read(&seen.restored), LETTER);
    assert_eq!(seen.restored.len(), 1);
    assert_eq!(seen.restored[0].piece, Piece::Words);
    // And the one thing a reader must not be able to mistake: this says nothing
    // about what the document holds. The letter is protected as it always was.
    assert!(span_of(LETTER, "Stefan Keller").end > 0);
    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

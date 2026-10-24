// 089 rule 5 · **z-pdf, the explicit door back** — 079 rule 3, built at last.
//
// Until today the only way a returning document could be read was to open it as
// a document: a bench, a scan, a banner under the band, and a press. That door
// stays (079 rule 4 — «the person who forgot the explicit door is not lost»).
// This is the one the owner asked for twice, on 13 and again on 15 October:
// «خيار يدعى z-pdf يقوم بعكس العملية، يبحث عن الكود ليحوله إلى اسم».
//
// What is measured here is the door's own promise, and the promise is a shape
// rather than a rule: **it takes no session.** So «never re-protected and never
// re-scanned as fresh content» (079 rule 5, *forbidden, absolutely*) is not a
// branch anybody has to take — there is no bench for a protection to land on,
// nothing to install a document on, and nothing to scan. Gate G34 reads the
// signature; these guards read the behaviour on the two file kinds the owner's
// own acceptance names, a .txt and a .pdf.
//
// **Nothing here asserts a line shape**, by the lead's instruction of 15
// October: Z's reader hands a real z-pdf back with every word on its own line
// (195 of 195 on «ألماني»), and that is the reader's own item. What is counted
// is names brought back and token places — neither of which a newline moves.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein genügend langes kennwort für die tür zurück";

/// The owner's own second reminder, as the other 079 guards use it: a real
/// German letter with eleven names in it, not a string built to be convenient.
const LETTER: &str = include_str!("fixtures/Mahnung_Keller.txt");

/// What the person's correspondent writes under the protected pages, so that
/// «nothing came back» can be told from «nothing is here».
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
    let dir = std::env::temp_dir().join(format!("zprivacy-089-door-{name}-{}", std::process::id()));
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

/// How many token **places** stand in a text — the number the door reports, and
/// the one that would move if anything were protected over a token.
fn places_in(text: &str) -> usize {
    let mut count = 0usize;
    let mut at = 0usize;
    while let Some(rest) = text.get(at..) {
        let Some(open) = rest.find("__Z_") else { break };
        let start = at + open;
        let after = start + "__Z_".len();
        let Some(close) = text[after..].find("__") else { break };
        at = after + close + "__".len();
        count += 1;
        let _ = start;
    }
    count
}

fn read(segments: &[Segment]) -> String {
    segments.iter().map(|s| s.text.as_str()).collect()
}

/// The letter on a bench, every word answered, born into a conversation, and
/// the text that would leave — which is the text a z-pdf carries.
///
/// The five suggestions are protected rather than skipped: this is the document
/// a person actually sends, and the exit refuses while one of them waits.
fn a_letter_that_has_left(name: &str) -> (Bench, u32, String, String) {
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, LETTER.to_string()).expect("import");
    let waiting: Vec<u32> = list_findings(held.0)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| f.id)
        .collect();
    for id in waiting {
        answer_finding(held.0, id, FindingAnswer::Protect).expect("answer");
    }
    conversation_begin(name.to_string(), Some(held.0)).expect("begin");
    let number = conversation_open().expect("open").expect("a session is open");
    // After the birth, because the birth renames every token: the text that
    // leaves is the text a z-pdf is made of.
    let taken = payload_to_take_out(held.0).expect("nothing waits, so the exit opens");
    let page = taken.answer_page_token.clone().expect("a page token");
    (held, number, taken.text, page)
}

/// The file that comes back: the protected pages, the correspondent's reply,
/// and the answer page's own line at the end.
fn what_came_back(safe: &str, answer_page: &str) -> String {
    format!("{safe}{REPLY}\nZ-pdf : {answer_page}\n")
}

/// **The door reads a file, and no bench of its own is needed for it** — the
/// whole shape of 089 rule 5.
///
/// The conversation's bench is still open here, so every name comes back: that
/// is the positive control, and it says the door reaches the same three sources
/// `returning_document` reaches. What it proves beyond that is that a **file's
/// bytes** are the input — no session, no import, no scan.
#[test]
fn the_door_back_reads_a_file_with_no_bench_of_its_own() {
    let _guard = serial();
    let dir = fresh_vault("afile");
    let (held, number, safe, page) = a_letter_that_has_left("die Mahnung");
    let names = tokens_in(&safe);
    // **Fourteen, not eleven, since 085 ruling 1** (15 October): each of this
    // letter's three people is a given name and a surname, and a token never
    // covers more than one word of what the app read for itself. The same
    // number moved in `a_document_that_comes_back_is_translated`, which is the
    // door this one is the control for — the two rounds met here, and the gate
    // is what said so.
    assert_eq!(names.len(), 14, "the letter left with {} names, not 14", names.len());
    let back = what_came_back(&safe, &page);

    let seen = read_a_document_that_came_back(back.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("the door reads a text file that came back");

    assert_eq!(
        seen.tokens as usize,
        places_in(&back),
        "the door counted {} token places where the file holds {}",
        seen.tokens,
        places_in(&back)
    );
    assert_eq!(seen.names, names.len() as u32, "it holds {} names", seen.names);
    assert_eq!(
        seen.brought_back,
        names.len() as u32,
        "with the conversation's own bench open, {} of {} names came back",
        seen.brought_back,
        names.len()
    );
    assert_eq!(
        seen.names,
        seen.brought_back + seen.unresolved.len() as u32,
        "a name fell between «came back» and «did not»"
    );
    assert_eq!(seen.conversations.len(), 1, "{:?}", seen.conversations.len());
    assert_eq!(seen.conversations[0].number, number);
    assert_eq!(seen.conversations[0].name, "die Mahnung");
    assert!(
        seen.conversations[0].answer_page,
        "the answer page's token did not prove where the file came from"
    );
    let text = read(&seen.restored);
    assert!(text.contains("Stefan Keller"), "the person's own name did not come back");
    assert!(text.contains("DE89 3704 0044 0532 0130 00"), "the IBAN did not come back");
    assert!(text.contains("Ihre Zahlung ist bei uns eingegangen"), "the reply was dropped");
    assert!(!text.contains("__Z_"), "a token is still standing in the reading");

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **A file one session protected is read back while another is open: the vault
/// is the boundary, and the reading names the session** — the owner's own
/// Windows test of 24 October 2026, brought into the tree by paper 111.
///
/// He built a second session in the test vault, saved a protected PDF from it,
/// ended the process and started it again to rule out memory, unlocked, stood
/// in **Session 1** — and read that file through this door. All twenty names
/// came back, naming the session they came from. He had expected a wall, and
/// our own sentence had let him expect one («Each session has its own
/// encryption…»); his verdict on the behaviour was «I think the vault works
/// excellently», so the behaviour stays and C-09's words moved. This is that
/// measurement, here, where a sentence can be held to it.
///
/// The lock and unlock in the middle are his restart: the key is dropped and
/// read from the file again, so nothing below is answered out of memory.
#[test]
fn the_door_back_reads_a_file_another_session_protected() {
    let _guard = serial();
    let dir = fresh_vault("othersession");
    let (first, number, safe, page) = a_letter_that_has_left("die erste Mahnung");
    let names = tokens_in(&safe);
    assert!(!names.is_empty(), "the letter left with no names, so this measures nothing");
    let back = what_came_back(&safe, &page);
    drop(first);

    // A second session, and it is the one that is open when the file is read.
    let other_bench = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(other_bench.0, "Ein zweiter Brief von Frau Katrin Sommer.".to_string())
        .expect("import");
    conversation_begin("die zweite Mahnung".to_string(), Some(other_bench.0)).expect("begin");
    let other = conversation_open().expect("open").expect("a session is open");
    assert_ne!(other, number, "no second session was born, so this measures nothing");

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");

    let seen = read_a_document_that_came_back(back.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("the door reads a file another session protected");

    assert_eq!(
        seen.brought_back,
        names.len() as u32,
        "{} of {} names came back from a file another session protected",
        seen.brought_back,
        names.len()
    );
    assert!(
        seen.unresolved.is_empty(),
        "names stayed tokens although the vault holds the session that made them: {:?}",
        seen.unresolved
    );
    // **And the reading says which session they came from**, which is the half
    // the owner read on his own screen.
    assert_eq!(seen.conversations.len(), 1, "{:?}", seen.conversations);
    assert_eq!(
        seen.conversations[0].number, number,
        "the reading names another session than the one that protected the file"
    );
    assert_eq!(seen.conversations[0].name, "die erste Mahnung");
    let text = read(&seen.restored);
    assert!(text.contains("Stefan Keller"), "the person's own name did not come back");
    assert!(!text.contains("__Z_"), "a token is still standing in the reading");

    drop(other_bench);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **The bench that minted the names is gone, and what the vault was taught
/// still comes back** — 079 rule 8's other half, through this door.
///
/// The identity `names == brought_back + unresolved` is asserted rather than
/// the count of what the vault was never taught: that count is what 089 rules
/// 1–2 are about, it is measured in one place
/// (`a_taught_value_comes_back_after_the_bench_is_gone`), and a second copy of
/// it here would make the storage round red twice for one change.
#[test]
fn the_door_back_brings_a_taught_value_back_after_the_bench_is_gone() {
    let _guard = serial();
    let dir = fresh_vault("taught");
    let who = create_entity(EntityKind::Person, "Stefan Keller".to_string(), None).expect("entity");
    set_value(who, None, Kind::Person, "Stefan Keller".to_string(), Policy::Always).expect("value");

    let (held, number, safe, page) = a_letter_that_has_left("die Mahnung");
    let names = tokens_in(&safe);
    let back = what_came_back(&safe, &page);
    // The bench that minted them is closed — which is what closing the document
    // does on the glass — and no other bench is opened: the door needs none.
    drop(held);

    let seen = read_a_document_that_came_back(back.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("the door reads it with no bench anywhere");

    assert_eq!(seen.vault, VaultState::Unlocked, "the vault was not open for this reading");
    assert_eq!(seen.conversations.len(), 1, "the conversation was not named");
    assert_eq!(seen.conversations[0].number, number);
    assert!(
        seen.conversations[0].answer_page,
        "with the bench gone the page is the proof of origin, and it did not speak"
    );
    assert_eq!(
        seen.names,
        seen.brought_back + seen.unresolved.len() as u32,
        "a name fell between «came back» and «did not»"
    );
    assert_eq!(seen.names, names.len() as u32);
    assert!(
        seen.brought_back >= 1,
        "the value the vault was taught did not come back: {} of {}",
        seen.brought_back,
        names.len()
    );
    let text = read(&seen.restored);
    assert!(text.contains("Stefan Keller"), "the taught name did not come back");
    // Every token that stayed a token is marked where it stands and named once.
    let standing: Vec<String> = seen
        .restored
        .iter()
        .filter(|s| s.piece == Piece::Unresolved)
        .map(|s| s.text.clone())
        .collect();
    let mut distinct = standing.clone();
    distinct.sort();
    distinct.dedup();
    assert_eq!(
        distinct.len(),
        seen.unresolved.len(),
        "the pieces and the names disagree about what is still a token"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **The owner's two files, and the door answers the same about both** — the
/// acceptance of 089 is a .pdf and a .txt of one German reply.
///
/// The numbers are compared and the prose is not: a .pdf arrives through a
/// reader that lays its text out its own way, and the line shape is e2's item.
/// Names and token places are what a person is told, and neither moves.
#[test]
fn the_door_back_reads_a_pdf_and_a_text_file_the_same_way() {
    let _guard = serial();
    let dir = fresh_vault("twofiles");
    let (held, _, safe, page) = a_letter_that_has_left("die Mahnung");
    let back = what_came_back(&safe, &page);

    let from_text = read_a_document_that_came_back(back.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("the text file");
    // One line per line of the reply, which is how the builder lays a page out.
    // The brackets a PDF uses for its own strings are taken out of the lines,
    // not out of the tokens: a token carries neither.
    let lines: Vec<String> = back
        .lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| l.replace(['(', ')', '\\'], ""))
        .collect();
    let from_pdf = read_a_document_that_came_back(pdf_of(&lines), DocumentKind::Pdf)
        .expect("the pdf");

    assert_eq!(
        from_pdf.tokens, from_text.tokens,
        "the two files carry the same tokens and the door counted {} in the pdf against {} in the text",
        from_pdf.tokens, from_text.tokens
    );
    assert_eq!(from_pdf.names, from_text.names, "the two files hold the same names");
    assert_eq!(
        from_pdf.brought_back, from_text.brought_back,
        "the pdf brought back {} of its names and the text file {}",
        from_pdf.brought_back, from_text.brought_back
    );
    assert_eq!(from_pdf.unresolved, from_text.unresolved);
    assert_eq!(
        from_pdf.conversations.len(),
        from_text.conversations.len(),
        "the two files name a different number of conversations"
    );
    assert!(
        from_pdf.brought_back > 0,
        "nothing came back from either file, so the comparison says nothing"
    );
    // And the values really are in the pdf's reading, not merely counted.
    assert!(read(&from_pdf.restored).contains("Stefan Keller"));

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **The door reads, and nothing of the person's is touched** — the control
/// that the mode really is restore.
///
/// A bench is open while the door is used, because that is the honest case: a
/// person with a document in front of them presses «z-pdf» in the + menu. What
/// is measured is everything a protection or a scan would move — the bench's
/// tokens, its marks, its review, its revision — and the vault's own bytes.
#[test]
fn the_door_back_leaves_the_bench_and_the_vault_untouched() {
    let _guard = serial();
    let dir = fresh_vault("untouched");
    let (held, _, safe, page) = a_letter_that_has_left("die Mahnung");
    let back = what_came_back(&safe, &page);

    // **And no bench is opened inside the door either.** A session's id is the
    // next number the core has not handed out, so two benches opened either
    // side of the door are consecutive if and only if the door opened none —
    // which is the one thing the «untouched» assertions below could not see:
    // a door that opened a bench of its own and scanned *that* would leave this
    // bench exactly as it is and still be the door 079 rule 5 forbids.
    let before_bench = open_session(None, "de".to_string()).expect("open");
    close_session(before_bench).expect("close");

    let before_tokens = list_tokens(held.0).expect("tokens").len();
    let before_marks = document_view(held.0).expect("view").marks.len();
    let before_findings = list_findings(held.0).expect("findings").len();
    let before_revision = session_revision(held.0).expect("revision").n;
    let vault_file = dir.join("vault.zv");
    let before_bytes = std::fs::read(&vault_file).expect("the vault file");
    assert!(before_tokens > 0 && before_marks > 0, "the control bench holds nothing to disturb");

    let once = read_a_document_that_came_back(back.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("read");
    let twice = read_a_document_that_came_back(back.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("read again");
    assert_eq!(read(&once.restored), read(&twice.restored), "reading it twice read two things");
    assert_eq!(once.brought_back, twice.brought_back);
    assert_eq!(
        once.tokens as usize,
        places_in(&back),
        "a token place was lost or added between the file and the reading"
    );

    let after_bench = open_session(None, "de".to_string()).expect("open");
    close_session(after_bench).expect("close");
    assert_eq!(
        after_bench.id,
        before_bench.id + 1,
        "the door opened {} bench(es) of its own between these two",
        after_bench.id.saturating_sub(before_bench.id).saturating_sub(1)
    );

    assert_eq!(list_tokens(held.0).expect("tokens").len(), before_tokens, "the door minted a token");
    assert_eq!(
        document_view(held.0).expect("view").marks.len(),
        before_marks,
        "the door protected something"
    );
    assert_eq!(
        list_findings(held.0).expect("findings").len(),
        before_findings,
        "the door scanned what came back: the review has a new row in it"
    );
    assert_eq!(
        session_revision(held.0).expect("revision").n,
        before_revision,
        "the door moved the bench's revision, so every handle built before it went stale"
    );
    assert_eq!(
        std::fs::read(&vault_file).expect("the vault file"),
        before_bytes,
        "the door wrote to the vault"
    );

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **A locked vault is a standing door** — 079 rule 8, at the explicit door.
///
/// The places are still counted, because they are a property of the file: a
/// person is told there are names of ours in it and which act would read them.
/// Nothing is called «a conversation this vault does not hold», because with
/// the vault shut there is nothing to compare a namespace with.
#[test]
fn a_locked_vault_leaves_the_door_back_standing() {
    let _guard = serial();
    let dir = fresh_vault("locked");
    let (held, _, safe, page) = a_letter_that_has_left("die Mahnung");
    let back = what_came_back(&safe, &page);
    // The bench goes first and the vault is shut behind it, which is what
    // closing the app and opening it again leaves: a file, and a locked vault.
    drop(held);
    vault_lock().expect("lock");

    let seen = read_a_document_that_came_back(back.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("a locked vault is not a refusal — it is an answer");

    assert_eq!(seen.vault, VaultState::Locked, "the reading did not say the vault is shut");
    assert_eq!(
        seen.tokens as usize,
        places_in(&back),
        "the places were not counted with the vault shut"
    );
    assert_eq!(seen.brought_back, 0, "a name came back through a locked vault");
    assert!(seen.conversations.is_empty(), "a conversation was named with no key to name it by");
    assert!(
        seen.unknown_namespaces.is_empty(),
        "a namespace was called one this vault does not hold, when the truth is that the vault is shut: {:?}",
        seen.unknown_namespaces
    );
    assert!(
        read(&seen.restored).contains("__Z_"),
        "the tokens were dropped from the reading instead of left standing"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **A file the door cannot read is refused by name**, as it is at every other
/// door: a scanned page with no text layer is a different problem from a
/// corrupt file, and the person is owed which.
#[test]
fn a_file_the_door_back_cannot_read_is_refused_by_name() {
    let _guard = serial();
    let dir = fresh_vault("refused");
    // Two causes, each named by its own word: a file with nothing in it, and a
    // page that holds together and carries no text — the owner's photographed
    // document, which is the one this house refuses rather than guesses at.
    for (what, bytes, expected) in [
        ("a file with nothing in it", Vec::new(), Refusal::EmptyDocument),
        (
            "a page with no text layer",
            pdf_of(&[String::new()]),
            Refusal::ScannedPdfNoTextLayer { pages: 1 },
        ),
    ] {
        match read_a_document_that_came_back(bytes, DocumentKind::Pdf) {
            Err(ApiError::DocumentRefused { reason, .. }) => assert_eq!(
                reason, expected,
                "the door named the wrong cause for {what}"
            ),
            Err(other) => panic!("the door refused {what} with the wrong kind of answer: {other:?}"),
            Ok(seen) => panic!("{what} was read: {} token places", seen.tokens),
        }
    }
    let _ = std::fs::remove_dir_all(&dir);
}

// ------------------------------------------------------- the file builder
//
// A .pdf written here by hand, so the door is driven with bytes laid out the
// way a writer lays them out rather than with our own idea of a file. Copied
// from `document_journey`, where the readers themselves are measured.

fn latin1(text: &str) -> Vec<u8> {
    text.chars().map(|c| u8::try_from(u32::from(c)).unwrap_or(b'?')).collect()
}

fn pdf_of(lines: &[String]) -> Vec<u8> {
    let mut out = String::from("%PDF-1.4\n");
    let count = lines.len();
    let kids: Vec<String> = (0..count).map(|i| format!("{} 0 R", 3 + i * 2)).collect();
    out.push_str("1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
    out.push_str(&format!(
        "2 0 obj\n<< /Type/Pages /Count {count} /Kids[{}] >>\nendobj\n",
        kids.join(" ")
    ));
    for (index, line) in lines.iter().enumerate() {
        let page_id = 3 + index * 2;
        let content_id = page_id + 1;
        out.push_str(&format!(
            "{page_id} 0 obj\n<< /Type/Page /Parent 2 0 R /Contents {content_id} 0 R /Resources << /Font << /F1 100 0 R >> >> >>\nendobj\n"
        ));
        let stream = latin1(&format!("BT /F1 12 Tf 72 700 Td ({line}) Tj ET"));
        out.push_str(&format!("{content_id} 0 obj\n<< /Length {} >>\nstream\n", stream.len()));
        out.push_str(&stream.iter().map(|b| char::from(*b)).collect::<String>());
        out.push_str("\nendstream\nendobj\n");
    }
    out.push_str("100 0 obj\n<< /Type/Font /Subtype/Type1 /BaseFont/Helvetica >>\nendobj\n");
    out.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");
    latin1(&out)
}

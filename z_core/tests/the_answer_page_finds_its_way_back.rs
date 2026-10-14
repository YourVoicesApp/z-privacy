// 079 · The answer page of a z-pdf — the core's half of the export.
//
// The owner, 13 Oct 2026, evening: every z-pdf ends with one extra page whose
// top line is «Z-pdf : Zprivacy-svara», and the word is **protected with the
// same session key as the document** — «لا أقصد أنها تحصل على المفتاح، أقصد أنها
// تحصل رمزاً ثابتاً يمكن العودة إليه». So the page carries an ordinary token of
// that session: no key on paper, no new grammar, and a name that restores to
// exactly the word in the session that printed it and to nothing anywhere else.
//
// The page itself is drawn in Dart (`protected_pdf.dart`), and read back
// through our own PDF reader in `the_answer_page_test.dart`. What is measured
// here is the token the core hands the page, at the door every exit asks:
//
//   * it exists only once the law lets the text out — a refused exit mints
//     nothing;
//   * it is a token of this session, and an answer carrying it — tied to the
//     payload the person's answer is really tied to, which was built before
//     the exit — restores it to the word and only the word;
//   * in another session it is named unknown and restores nothing;
//   * a birth renames it with every other token;
//   * it is not counted in the footer's tally;
//   * and, measured rather than assumed: two documents in one session print
//     the same token.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för en svarssida";

/// The word the page protects. Written out here and not imported: the core
/// keeps it crate-private, and a change to it should be a red in this file.
const WORD: &str = "Zprivacy-svara";

/// Two documents, each with one value put there by hand, in a line the Swedish
/// pack suggests nothing in — so the tokens in the text are the ones made here.
const LINE: &str = "Hej Hedvig Palmgren, tack för ditt brev om kontot.";
const VALUE: &str = "Hedvig Palmgren";
const OTHER_LINE: &str = "Hej Sigrid Holmqvist, svaret kommer på fredag.";
const OTHER_VALUE: &str = "Sigrid Holmqvist";

/// A letter with a company the rules offer and never take: one word waits.
const WAITING: &str = "Kunde: Nordstern Consulting GmbH\n\
    Ansprechpartner: Herr Thomas Müller\n\
    IBAN: DE89370400440532013000\n\
    Wir bitten um eine Verlängerung des Zahlungsziels.";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-079-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    dir
}

/// A bench that closes itself even when a test panics: a live bench left
/// behind makes the next test's birth refuse, and a red downstream of another
/// red stands in front of the one that matters.
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

/// Every token in a text, by its marks.
fn tokens_in(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut at = 0usize;
    while let Some(rest) = text.get(at..) {
        let Some(open) = rest.find("__Z_") else { break };
        let start = at + open;
        let after = start + "__Z_".len();
        let Some(close) = text[after..].find("__") else { break };
        let end = after + close + "__".len();
        out.push(text[start..end].to_string());
        at = end;
    }
    out
}

/// `__Z_8F3A_` — the part of a token that names its session.
fn namespace_of(token: &str) -> &str {
    &token[..9]
}

fn read(segments: &[Segment]) -> String {
    segments.iter().map(|s| s.text.as_str()).collect()
}

/// A bench on `text` with `value` protected by hand and nothing waiting.
fn a_bench(text: &str, value: &str) -> Bench {
    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    import_text(held.0, text.to_string()).expect("import");
    let report = scan(held.0).expect("scan");
    assert_eq!(
        report.suggested, 0,
        "the scanner suggests {} words in this line, so the fixture is not the one written here",
        report.suggested
    );
    protect(held.0, span_of(text, value), Scope::Once, Kind::Person).expect("protect");
    held
}

/// What the exit hands out, with its answer page token — which must be there.
fn taken_out(bench: SessionId) -> (PayloadView, String) {
    let view = payload_to_take_out(bench).expect("nothing waits, so the exit opens");
    let token = view
        .answer_page_token
        .clone()
        .expect("the exit handed out no token for the answer page");
    (view, token)
}

/// **The exit hands out a token of this session, and it restores to the word**
/// — through the payload the person's answer is really tied to.
///
/// That payload is the bench's last snapshot, built **before** the exit was
/// pressed, which is the case that fails quietly: a token only the exit's own
/// payload allowed would come back unknown in the session that printed it.
#[test]
fn the_answer_pages_token_restores_to_the_word_in_its_own_session() {
    let _guard = serial();
    let dir = fresh_vault("own");
    let held = a_bench(LINE, VALUE);
    conversation_begin("one session".to_string(), Some(held.0)).expect("begin");

    // The snapshot the person's answer will be tied to, built before the exit.
    let before = build_payload(held.0).expect("the snapshot");
    let document = tokens_in(&payload_view(before).expect("view").text);
    assert_eq!(document.len(), 1, "the fixture protected {} values, not one", document.len());

    let (view, token) = taken_out(held.0);
    assert_eq!(tokens_in(&token), vec![token.clone()], "«{token}» is not one token by its marks");
    assert!(token.contains("_CUSTOM_"), "«{token}» does not carry the kind it was minted with");
    assert_eq!(
        namespace_of(&token),
        namespace_of(&document[0]),
        "the answer page wears another namespace than the document it closes"
    );
    assert!(!view.text.contains(&token), "the answer page's token was put into the document's text");
    assert!(!view.text.contains(WORD) && !token.contains(WORD), "the word stands in the clear");

    // Back through the snapshot built before the exit, and through one built
    // after it: both are this bench's, and both must restore it.
    let after = build_payload(held.0).expect("a snapshot after the exit");
    for (which, handle) in [("before the exit", before), ("after the exit", after)] {
        let answer = ingest_answer(handle, format!("Z-pdf : {token}")).expect("the answer is taken");
        let snap = answer_snapshot(held.0, answer).expect("read it back");
        assert!(
            snap.unknown_tokens.is_empty(),
            "through the payload built {which}, the page's own token is unknown: {:?}",
            snap.unknown_tokens
        );
        assert_eq!(
            read(&snap.restored),
            format!("Z-pdf : {WORD}"),
            "through the payload built {which}, the token did not restore to exactly the word"
        );
    }

    // And the same exit twice is the same page.
    let (_, again) = taken_out(held.0);
    assert_eq!(again, token, "the second exit of one bench printed another answer token");

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **In another session the token is foreign** — named, and restored to
/// nothing. The control stands in the same answer: the other session's own
/// answer token restores, so «nothing came back» is isolation and not a dead
/// restorer.
#[test]
fn the_answer_pages_token_is_unknown_in_another_session() {
    let _guard = serial();
    let dir = fresh_vault("foreign");

    let first = a_bench(LINE, VALUE);
    conversation_begin("the first session".to_string(), Some(first.0)).expect("begin");
    let (_, theirs) = taken_out(first.0);
    drop(first);

    let second = a_bench(LINE, VALUE);
    conversation_begin("the second session".to_string(), Some(second.0)).expect("begin");
    let (_, ours) = taken_out(second.0);
    assert_ne!(ours, theirs, "two sessions printed one answer token, so there is nothing to isolate");

    let handle = build_payload(second.0).expect("payload");
    let answer = ingest_answer(handle, format!("{theirs} / {ours}")).expect("the answer is taken");
    let snap = answer_snapshot(second.0, answer).expect("read it back");
    assert_eq!(
        snap.unknown_tokens,
        vec![theirs.clone()],
        "the first session's answer token was not named unknown in the second"
    );
    assert_eq!(
        read(&snap.restored),
        format!("{theirs} / {WORD}"),
        "the foreign token was restored or dropped, or the control did not restore"
    );

    drop(second);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **A refused exit mints nothing** — the 083a law holds with the page. The
/// token is minted after the law, so a word waiting leaves no answer page
/// behind it: no token on the payloads, nothing in the store to restore.
#[test]
fn a_refused_exit_mints_no_answer_page() {
    let _guard = serial();
    let dir = fresh_vault("refused");
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, WAITING.to_string()).expect("import");
    let report = scan(held.0).expect("scan");
    assert_eq!(report.suggested, 1, "the fixture must leave exactly one word waiting");

    match payload_to_take_out(held.0) {
        Err(ApiError::OpenSuggestions { count }) => assert_eq!(count, 1),
        other => panic!("the exit was not refused for the waiting word: {other:?}"),
    }
    let snapshot = payload_view(build_payload(held.0).expect("the column still builds")).expect("view");
    assert_eq!(
        snapshot.answer_page_token, None,
        "a refused exit minted an answer page token"
    );

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **A birth renames the page with everything else.** Taken out before any
/// session — the order the exits really follow: the law is asked first, the
/// session is born second — and then again after the birth: the token now
/// wears the session's namespace, and the old name restores nothing.
#[test]
fn a_birth_renames_the_answer_page_with_the_rest() {
    let _guard = serial();
    let dir = fresh_vault("birth");
    let held = a_bench(LINE, VALUE);

    let (_, before) = taken_out(held.0);
    let row = conversation_begin("born at the exit".to_string(), Some(held.0)).expect("begin");
    // **The count the person reads is the document's names.** «N names became
    // this session's» is said at the exit, and the answer page's token is not
    // a name anybody chose to protect — it moves, and it is not counted.
    assert_eq!(
        row.renamed_tokens, 1,
        "the birth says it renamed {} names; the document has one",
        row.renamed_tokens
    );
    let (view, after) = taken_out(held.0);
    let document = tokens_in(&view.text);
    assert_eq!(document.len(), 1);
    assert_eq!(
        namespace_of(&after),
        namespace_of(&document[0]),
        "after the birth the answer page does not wear the session's namespace"
    );

    let answer = ingest_answer(build_payload(held.0).expect("payload"), format!("{before} {after}"))
        .expect("the answer is taken");
    let snap = answer_snapshot(held.0, answer).expect("read it back");
    if before != after {
        assert_eq!(
            snap.unknown_tokens,
            vec![before.clone()],
            "the pre-birth name still restores, or the session's own did not"
        );
        assert_eq!(read(&snap.restored), format!("{before} {WORD}"));
    } else {
        // Four hex of randomness can draw the derived name; then the two are
        // one token, and it must restore.
        assert_eq!(read(&snap.restored), format!("{WORD} {WORD}"));
    }

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **The footer states what stands in the text, and the page's token does not
/// stand there.** The tally and the count of places are the ones the same
/// payload had before any page was minted.
#[test]
fn the_answer_page_is_not_counted_in_the_footer() {
    let _guard = serial();
    let dir = fresh_vault("tally");
    let held = a_bench(LINE, VALUE);
    conversation_begin("one session".to_string(), Some(held.0)).expect("begin");

    let before = payload_view(build_payload(held.0).expect("payload")).expect("view");
    let (after, _) = taken_out(held.0);
    assert_eq!(after.protected_count, before.protected_count, "the page's token was counted as a place");
    assert_eq!(after.by_kind, before.by_kind, "the page's token was counted as a value of the text");
    assert!(
        after.by_kind.iter().all(|t| t.kind != Kind::Custom),
        "the footer's tally lists the answer page's kind"
    );

    drop(held);
    let _ = std::fs::remove_dir_all(&dir);
}

/// **Measured: two documents in one session print one answer token.**
///
/// Paper 079 says the token is fixed per session. An older paper (046/U)
/// derived names from the document's text, and 064 says the session's key is
/// now the whole input. This does not choose between them by reading: it opens
/// two different documents in one session and compares what their exits hand
/// the page. The control beside it — the two documents' own values are
/// different and must take different tokens in the same namespace — so «one
/// token» is about the word, and not about a mint that names everything alike.
#[test]
fn two_documents_of_one_session_print_one_answer_token() {
    let _guard = serial();
    let dir = fresh_vault("fixed");

    let first = a_bench(LINE, VALUE);
    let row = conversation_begin("one session, two documents".to_string(), Some(first.0)).expect("begin");
    let (view_a, a) = taken_out(first.0);
    drop(first);

    let second = a_bench(OTHER_LINE, OTHER_VALUE);
    conversation_enter(row.number, Some(second.0)).expect("enter");
    let (view_b, b) = taken_out(second.0);

    let doc_a = tokens_in(&view_a.text);
    let doc_b = tokens_in(&view_b.text);
    println!("measured · answer page: {a} | {b} · documents: {doc_a:?} | {doc_b:?}");
    assert_eq!(doc_a.len(), 1);
    assert_eq!(doc_b.len(), 1);
    assert_ne!(doc_a, doc_b, "two different values took one token — the control");
    assert_eq!(
        namespace_of(&doc_a[0]),
        namespace_of(&doc_b[0]),
        "the two documents are not in one namespace, so they are not in one session"
    );
    assert_eq!(a, b, "the answer page's token differs between two documents of one session");

    drop(second);
    let _ = std::fs::remove_dir_all(&dir);
}

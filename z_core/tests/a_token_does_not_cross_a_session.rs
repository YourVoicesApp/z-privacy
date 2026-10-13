// **C6 · Session isolation** — the first conformance vector of the Z contract,
// and it was «unverified on both sides».
//
// The contract, v0, sealed in the library at `1d56868`:
//
//   **C6** «A token from one session never restores in another, even on the
//   same device, even for the same value — unless the session that holds it
//   does the restoring (C1, C4).»
//
//   **C1** «The node that holds the original is the only one that can reveal
//   it. Holding a token never implies the authority to restore it.»
//
//   **C4** a string is restored only if all four hold: it is a well-formed
//   token, it is in the allowed list of the payload the response answers, it
//   is present in the local state, and its kind segment equals the kind of the
//   value it maps to. A well-formed token that fails any other condition is
//   **unknown**: left exactly as it arrived, named to the person, never
//   guessed and never matched by similarity.
//
// Its conformance row said, for the app and for the library: «token from
// session A does not restore in B — unverified». The mechanism was described
// on both sides and measured on neither, which is the state in which a promise
// is kept by accident.
//
// **This file is a negative guard**, so it carries its own controls: every
// «nothing restored» stands beside a «this did restore», in the same answer,
// through the same door. Without them a restorer that resolves *nothing* —
// broken, not isolated — would read exactly like a product that keeps C6.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för två jlsessioner";

/// One value, and a line the Swedish pack suggests nothing in — so the
/// protections are exactly the ones put here by hand, and a count is a count.
const LINE: &str = "Hej Hedvig Palmgren, tack för ditt brev om kontot.";
const VALUE: &str = "Hedvig Palmgren";

/// A text of the same session with no value of its own: the payload built for
/// it allows no token, which is C4's second condition and nothing else.
const OTHER: &str = "Tack för svaret, allt är klart nu.";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-c6-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    dir
}

/// A bench that closes itself even when a test panics: a live bench left
/// behind makes the *next* test's birth-with-no-document refuse, and a red
/// downstream of another red stands in front of the one that matters.
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

/// Every token in a text, found the way `restore` finds one — by the marks and
/// never by whitespace, because a token stands where a name stood and a name is
/// followed by a comma as often as by a space.
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

fn read(segments: &[Segment]) -> String {
    segments.iter().map(|s| s.text.as_str()).collect()
}

/// **One session with one protected value, ready to answer.** Returns its
/// bench, the session's number and the tokens standing in its safe text.
fn a_session(name: &str, text: &str) -> (Bench, u32, Vec<String>) {
    let held = Bench(open_session(None, "sv".to_string()).expect("open"));
    import_text(held.0, text.to_string()).expect("import");
    let report = scan(held.0).expect("scan");
    assert_eq!(
        report.suggested, 0,
        "the scanner now suggests {} names in this line, so the count of protections below \
         is no longer the count of things put here by hand",
        report.suggested
    );
    if text.contains(VALUE) {
        protect(held.0, span_of(text, VALUE), Scope::Once, Kind::Person).expect("protect");
    }
    let row = conversation_begin(name.to_string(), Some(held.0)).expect("begin");
    let handle = build_payload(held.0).expect("payload");
    let view = payload_view(handle).expect("view");
    assert!(
        !view.text.contains(VALUE),
        "the value stands in the safe text, so this fixture proves nothing about tokens"
    );
    (held, row.number, tokens_in(&view.text))
}

/// **An answer built in another session resolves nothing of it, and names
/// every token it could not resolve** — C6, with its control in the same
/// answer.
#[test]
fn an_answer_from_another_session_names_every_token_and_restores_none() {
    let _guard = serial();
    let dir = fresh_vault("across");

    // Session A, and then session B **on the same value**: C6 says «even for
    // the same value», so a fixture where the two texts differ would measure
    // nothing but luck.
    let (a, _a_number, a_tokens) = a_session("the first session", LINE);
    assert_eq!(a_tokens.len(), 1, "the fixture protected {} values, not one", a_tokens.len());
    close_session(a.0).ok();

    let (b, _b_number, b_tokens) = a_session("the second session", LINE);
    assert_eq!(b_tokens.len(), 1, "the second fixture protected {} values", b_tokens.len());

    // **The first half of C6, and the control for everything below**: one
    // value, two sessions, two different names. If these were equal, «A's
    // token does not restore in B» would be a sentence about nothing.
    assert_ne!(
        a_tokens[0], b_tokens[0],
        "the same value took the same token in two sessions, so there is no isolation to measure"
    );

    // One answer carrying both: A's token, which must stay unknown, and B's
    // own, which must come back. Both through B's door, in one read.
    let raw = format!(
        "Jag har läst brevet. {} och {} nämns båda.",
        a_tokens[0], b_tokens[0]
    );
    let handle = build_payload(b.0).expect("payload for B");
    let answer = ingest_answer(handle, raw).expect("B takes the answer");
    let snap = answer_snapshot(b.0, answer).expect("B reads it");

    // **All of them, not some** — by the count and then by the name.
    assert_eq!(
        snap.unknown_tokens.len(),
        a_tokens.len(),
        "B resolved or dropped a token from A: it named {:?} of {:?}",
        snap.unknown_tokens,
        a_tokens
    );
    for token in &a_tokens {
        assert!(
            snap.unknown_tokens.contains(token),
            "«{token}» came from another session and B did not name it as unresolved"
        );
    }

    // **The value is counted, not looked for.** Both sessions protected the
    // *same* value — C6 says «even for the same value» — so «the restored text
    // contains it» is true of a correct product: B's own token restores to it.
    // The first reading of this guard asserted the absence and went red on the
    // product for a reason that was the fixture's, which is a red that proves
    // nothing. What the law says is **once**: B's, and not A's.
    let restored = read(&snap.restored);
    assert_eq!(
        restored.matches(VALUE).count(),
        1,
        "the value stands {} times in the restored answer; B's own token is one, and a \
         second would be A's token restored in a session that never minted it:\n{restored}",
        restored.matches(VALUE).count()
    );
    // The control, in the same read: B's own token came back, so «A's did not»
    // is isolation and not a dead restorer.
    assert!(
        !restored.contains(&b_tokens[0]),
        "B left its own token standing in the text it restored, so nothing was restored at all"
    );
    // And A's token is still there, word for word, where the value would have
    // gone — named, not dropped (C4).
    assert!(
        restored.contains(&a_tokens[0]),
        "A's token was dropped out of the answer instead of being left as it arrived"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// **Holding another session's handle, or its answer, is not authority** — C1.
///
/// Two doors, one law. Neither refusal is allowed to carry the value in its
/// own words, which is the other half of what a refusal must not do.
///
/// **The refusal of a foreign answer id has three layers, and that was
/// measured rather than assumed.** `answer_snapshot`'s own index lookup was
/// broken on purpose — made to read the answer out of whichever bench happens
/// to hold it, which is authority by possession — and this guard stayed green,
/// because `restoration` and `ai_view` each look the id up in *this* bench's
/// map and refuse it separately. So a bite that does not bite is the finding
/// here: the law is kept in three places, and this guard sees a refusal while
/// any one of them stands. What it cannot tell is which — and it does not need
/// to: the contract says «refused», not «refused here».
#[test]
fn a_handle_or_an_answer_of_another_session_is_refused() {
    let _guard = serial();
    let dir = fresh_vault("authority");

    let (a, _a_number, a_tokens) = a_session("the first session", LINE);
    // Two payloads in A, so that A holds an id B will not have.
    let a_second = build_payload(a.0).expect("a second payload in A");
    let a_answer = ingest_answer(a_second, format!("Jo, {} står där.", a_tokens[0]))
        .expect("A takes its own answer");
    close_session(a.0).ok();

    let (b, _b_number, _b_tokens) = a_session("the second session", LINE);

    // **A forged handle**: A's payload id, pointed at B's bench. Nothing in the
    // product builds this; a caller that keeps a handle and changes one field
    // does, and the door has to answer for it.
    let forged = PayloadHandle {
        id: a_second.id,
        session: b.0.id,
        revision: a_second.revision,
    };
    match ingest_answer(forged, format!("Jo, {} står där.", a_tokens[0])) {
        Err(e) => {
            let said = format!("{e:?}");
            assert!(
                !said.contains(VALUE),
                "the refusal carries the value in its own words: {said}"
            );
        }
        Ok(answer) => {
            // Not refused is only acceptable if nothing of A came back — the
            // contract forbids the restoration, not a particular error.
            let snap = answer_snapshot(b.0, answer).expect("read it back");
            assert!(
                !read(&snap.restored).contains(VALUE),
                "a forged handle restored another session's value"
            );
            assert!(
                snap.unknown_tokens.contains(&a_tokens[0]),
                "a forged handle was accepted and the foreign token was not even named"
            );
        }
    }

    // **A's answer, read from B.** An answer id is a number; holding it is not
    // authority over what it holds.
    match answer_snapshot(b.0, a_answer) {
        Err(e) => {
            let said = format!("{e:?}");
            assert!(
                !said.contains(VALUE),
                "the refusal carries the value in its own words: {said}"
            );
        }
        Ok(snap) => panic!(
            "B read an answer of A's: «{}»",
            read(&snap.restored)
        ),
    }

    let _ = std::fs::remove_dir_all(&dir);
}

/// **The session's own token, through a payload that did not allow it, stays
/// unknown** — C4's second condition, inside one session.
///
/// This is the half that cannot be explained by the key: the store still holds
/// the value, the names match, the session is the same one — and the answer
/// still may not resolve it, because the payload it answers never carried it.
#[test]
fn a_token_this_payload_did_not_allow_stays_unknown_in_its_own_session() {
    let _guard = serial();
    let dir = fresh_vault("allowed");

    let (held, _number, tokens) = a_session("one session, two texts", LINE);

    // The control first: through the payload that **did** allow it, the token
    // comes back. Measured before the refusal, so a dead restorer cannot pass
    // the refusal off as a law.
    let allowed = build_payload(held.0).expect("payload for the letter");
    let answer = ingest_answer(allowed, format!("Jo, {} står där.", tokens[0]))
        .expect("the answer is taken");
    let snap = answer_snapshot(held.0, answer).expect("read");
    assert!(
        read(&snap.restored).contains(VALUE),
        "the token did not restore through the payload that allowed it, so nothing below is a law"
    );
    assert!(snap.unknown_tokens.is_empty(), "its own token was named unresolved");

    // Now the same session, another text: the store still holds the value and
    // the name is still the session's own, but this payload allowed nothing.
    import_text(held.0, OTHER.to_string()).expect("another text");
    let not_allowed = build_payload(held.0).expect("payload for the other text");
    let view = payload_view(not_allowed).expect("view");
    assert!(
        tokens_in(&view.text).is_empty(),
        "the second text carries a token, so its payload allows one and this measures nothing"
    );

    let second = ingest_answer(not_allowed, format!("Jo, {} står där.", tokens[0]))
        .expect("the answer is taken");
    let snap = answer_snapshot(held.0, second).expect("read");
    assert!(
        !read(&snap.restored).contains(VALUE),
        "a token the payload never allowed was restored because the session happened to know it"
    );
    assert_eq!(
        snap.unknown_tokens,
        vec![tokens[0].clone()],
        "the unresolved token was not named: {:?}",
        snap.unknown_tokens
    );

    let _ = std::fs::remove_dir_all(&dir);
}

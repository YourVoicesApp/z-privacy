// Paper 123 §2.3, rule 87 (ب) · **a token whose shape the chat page changed**.
//
// The owner's first preview of the web trial, 14 November: one Arabic run kept
// its codes. The lead then ran the built module over every way a chat page
// changes a token on its way back (paper 123 §0), and found the comma glued to
// a token harmless and the token's own shape the harm: a rendered chat eats the
// `__` around it as markdown bold, and a markdown source escapes every `_`.
//
// Every row of that table is a test here. The rows the ruling reads — the `__`
// eaten on either side or both, every `_` escaped — restore. The rows it does
// not read (one `_` lost, a space inside, lower case, a direction mark) are
// pinned as they are: text. And the two controls hold the ruling's own limits:
// a reshaped token is read only when it is in **this payload's** allowed list
// and stands at a word boundary, so an eaten look-alike from another namespace
// and an eaten token this payload never carried both stay text.
//
// **Pinned first**: the eaten row was written asserting today's plain text,
// green on `67cd2a9` and red the moment the reading landed, then turned.
//
// No vault and no data directory: the trial's own state.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

/// Invented: no such person, number or address.
const LETTER: &str = "مرحباً، اسمي سمير الحداد وأسكن في مدينة حلب. رقم هاتفي 0701234567 وبريدي samir.test@example.com.";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

/// A bench with the letter protected, the payload that left, and its tokens
/// in the order they stand.
struct Sent {
    bench: SessionId,
    payload: PayloadHandle,
    tokens: Vec<String>,
    text: String,
}

impl Drop for Sent {
    fn drop(&mut self) {
        close_session(self.bench).ok();
    }
}

fn sent() -> Sent {
    let bench = open_session(None, "ar".to_string()).expect("open");
    import_text(bench, LETTER.to_string()).expect("import");
    for f in list_findings(bench).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(bench, f.id, FindingAnswer::Protect).ok();
        }
    }
    let payload = build_payload(bench).expect("payload");
    let text = payload_view(payload).expect("view").text;
    let mut tokens: Vec<String> = Vec::new();
    let mut rest = text.as_str();
    while let Some(at) = rest.find("__Z_") {
        let after = &rest[at + 4..];
        let Some(close) = after.find("__") else { break };
        let token = format!("__Z_{}__", &after[..close]);
        if !tokens.contains(&token) {
            tokens.push(token);
        }
        rest = &after[close + 2..];
    }
    assert!(tokens.len() >= 2, "the letter protected fewer than two values: {} token(s)", tokens.len());
    Sent { bench, payload, tokens, text }
}

/// What came back from `answer`: the pieces that are not plain words, and the
/// whole text as the person reads it.
fn back(s: &Sent, answer: &str) -> (Vec<Piece>, String) {
    let id = ingest_answer(s.payload, answer.to_string()).expect("ingest");
    let segments = restored_view(s.bench, id).expect("restored");
    let pieces = segments.iter().map(|x| x.piece).filter(|p| *p != Piece::Words).collect();
    let text = segments.iter().map(|x| x.text.as_str()).collect();
    (pieces, text)
}

fn bare(token: &str) -> &str {
    token.trim_start_matches("__").trim_end_matches("__")
}

/// The value a token stands for, read back from the letter by restoring it.
fn value(s: &Sent, token: &str) -> String {
    let (pieces, text) = back(s, token);
    assert_eq!(pieces, vec![Piece::Restored], "the control token itself did not restore");
    text
}

fn restores(s: &Sent, answer: &str, n: usize) {
    let (pieces, text) = back(s, answer);
    assert_eq!(pieces, vec![Piece::Restored; n], "not restored: {answer:?}");
    for token in &s.tokens[..n.min(s.tokens.len())] {
        assert!(!text.contains(bare(token)), "a code is still in the text: {text:?}");
    }
}

fn stays_text(s: &Sent, answer: &str) {
    let (pieces, text) = back(s, answer);
    assert!(pieces.is_empty(), "read as a token: {answer:?} -> {pieces:?}");
    assert_eq!(text, answer, "the text was changed");
}

// ---------------------------------------------------------------- read today

#[test]
fn spaces_around_restore() {
    let _g = serial();
    let s = sent();
    let (t1, t2) = (&s.tokens[0], &s.tokens[1]);
    restores(&s, &format!("أهلاً {t1} ، رقمك {t2} ."), 2);
}

#[test]
fn glued_punctuation_restores() {
    let _g = serial();
    let s = sent();
    let (t1, t2) = (&s.tokens[0], &s.tokens[1]);
    restores(&s, &format!("أهلاً {t1}، رقمك {t2}."), 2);
    restores(&s, &format!("أهلاً {t1}, رقمك {t2}."), 2);
    restores(&s, &format!("الاسم:{t1} ({t2})"), 2);
}

#[test]
fn backticks_and_bold_markers_restore() {
    let _g = serial();
    let s = sent();
    let (t1, t2) = (&s.tokens[0], &s.tokens[1]);
    restores(&s, &format!("أهلاً `{t1}`، رقمك `{t2}`"), 2);
    restores(&s, &format!("أهلاً **{t1}**، رقمك {t2}"), 2);
}

// ---------------------------------------------------------------- the ruling

/// The row the owner met. Pinned first as `stays_text`, which was green on
/// `67cd2a9` and red once the reading landed.
#[test]
fn the_eaten_underscores_restore() {
    let _g = serial();
    let s = sent();
    let (t1, t2) = (&s.tokens[0], &s.tokens[1]);
    restores(&s, &format!("أهلاً {}، رقمك {}.", bare(t1), bare(t2)), 2);
}

#[test]
fn eaten_on_one_side_restores() {
    let _g = serial();
    let s = sent();
    let (t1, t2) = (&s.tokens[0], &s.tokens[1]);
    // The close eaten, then the open: and an intact token after the first,
    // whose opening `__` the old walk took for the first one's close.
    restores(&s, &format!("أهلاً __{}، رقمك {t2}.", bare(t1)), 2);
    restores(&s, &format!("أهلاً {}__، رقمك {t2}.", bare(t1)), 2);
}

#[test]
fn escaped_underscores_restore() {
    let _g = serial();
    let s = sent();
    let (t1, t2) = (&s.tokens[0], &s.tokens[1]);
    restores(&s, &format!("أهلاً {}، رقمك {t2}", t1.replace('_', "\\_")), 2);
}

#[test]
fn the_restored_names_are_the_letters_own() {
    let _g = serial();
    let s = sent();
    let t1 = s.tokens[0].clone();
    let name = value(&s, &t1);
    assert!(LETTER.contains(&name), "the value is not from the letter");
    let (_, text) = back(&s, &format!("أهلاً {}.", bare(&t1)));
    assert_eq!(text, format!("أهلاً {name}."));
    let (_, text) = back(&s, &format!("أهلاً {}.", t1.replace('_', "\\_")));
    assert_eq!(text, format!("أهلاً {name}."));
}

// ---------------------------------------------------------------- pinned as they are

#[test]
fn one_leading_underscore_lost_stays_text() {
    let _g = serial();
    let s = sent();
    let t1 = &s.tokens[0];
    stays_text(&s, &format!("أهلاً _{}__، شكراً", bare(t1)));
}

#[test]
fn a_space_inside_stays_text() {
    let _g = serial();
    let s = sent();
    let t1 = &s.tokens[0];
    let split = t1.replacen('_', "_ ", 3);
    stays_text(&s, &format!("أهلاً {split}، شكراً"));
}

#[test]
fn lower_case_stays_text() {
    let _g = serial();
    let s = sent();
    let t1 = &s.tokens[0];
    stays_text(&s, &format!("أهلاً {}، شكراً", t1.to_lowercase()));
    stays_text(&s, &format!("أهلاً {}، شكراً", bare(t1).to_lowercase()));
}

#[test]
fn a_direction_mark_inside_stays_text() {
    let _g = serial();
    let s = sent();
    let t1 = &s.tokens[0];
    stays_text(&s, &format!("أهلاً {}، شكراً", t1.replacen("_Z_", "_Z\u{200F}_", 1)));
    stays_text(&s, &format!("أهلاً {}، شكراً", bare(t1).replacen("Z_", "Z\u{200F}_", 1)));
}

// ---------------------------------------------------------------- the controls

/// **An eaten look-alike of another namespace stays text** — and is not even
/// reported: only an intact token is a claim worth naming.
#[test]
fn an_eaten_token_of_another_namespace_stays_text() {
    let _g = serial();
    let s = sent();
    let t1 = bare(&s.tokens[0]);
    let namespace = &t1[2..6];
    let other = if namespace == "0000" { "1111" } else { "0000" };
    let foreign = t1.replacen(namespace, other, 1);
    stays_text(&s, &format!("أهلاً {foreign}، شكراً"));
    stays_text(&s, &format!("أهلاً {}، شكراً", format!("__{foreign}__").replace('_', "\\_")));
}

/// **The allowed list decides by itself**: a token of this very bench, with a
/// value in its store, that this payload never carried — eaten or escaped, it
/// stays text; intact, it is reported as today.
#[test]
fn an_eaten_token_this_payload_never_carried_stays_text() {
    let _g = serial();
    let s = sent();
    // A word protected after the payload was built: its token is this bench's
    // and is not in that payload's allowed list.
    let at = LETTER.find("حلب").expect("the city");
    let start = LETTER[..at].encode_utf16().count() as u32;
    let end = start + "حلب".encode_utf16().count() as u32;
    let later = match protect(s.bench, Span { start, end }, Scope::Once, Kind::Address).expect("protect") {
        ProtectOutcome::Applied { token, .. } => token,
        other => panic!("not applied: {other:?}"),
    };
    assert!(!s.text.contains(&later), "the control token left with the payload, so it measures nothing");
    stays_text(&s, &format!("أهلاً {}، شكراً", bare(&later)));
    stays_text(&s, &format!("أهلاً {}، شكراً", later.replace('_', "\\_")));
    let (pieces, _) = back(&s, &format!("أهلاً {later}، شكراً"));
    assert_eq!(pieces, vec![Piece::Unresolved], "the intact token is no longer reported");
}

/// **A word boundary**: a letter or digit glued to an eaten token, before or
/// after, and it stays text. Punctuation is not glue.
#[test]
fn an_eaten_token_glued_to_a_word_stays_text() {
    let _g = serial();
    let s = sent();
    let t1 = bare(&s.tokens[0]);
    stays_text(&s, &format!("أهلاً x{t1}، شكراً"));
    stays_text(&s, &format!("أهلاً {t1}9، شكراً"));
    stays_text(&s, &format!("أهلاً ب{t1}، شكراً"));
    stays_text(&s, &format!("أهلاً {t1}ب، شكراً"));
}

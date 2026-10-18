// **The word that names a field is not a value** — the attacker's second
// report, finding B1-3, measured on `84832a0` and reproduced unchanged on
// `34ed785`.
//
// What he did: a German dunning letter, protected to the end (no open
// suggestion left), then the question a person would actually type about it:
//
// ```text
//   Was schuldet Stefan Keller Frau Beate Hoffmann? IBAN DE89 3704 0044 0532 0130 00
// ```
//
// What he measured — the probe is in this file as the first two guards:
//
// * the question left with the names and the account as the tokens the
//   document had already minted, which is the promise of 046/N, **and with a
//   fifth, fresh `PERSON` token whose value is the four letters «IBAN»**. The
//   salutation's walk crossed the question mark, reached a third name-shaped
//   word, and a label became a person.
// * the next `build_payload` then refused — `a protected value still stands 5
//   time(s) where at most 2 was expected` — because the exit audit counts
//   those four letters **inside our own `__Z_…_IBAN_…__` tokens**. Copy, Save
//   as PDF, pull and send were all closed on that document until the person
//   undid a protection nobody had asked for. On `34ed785` the same question is
//   a follow-up in the chat, so it closed the chat too.
//
// **Two faults, and they are independent — each has its own guard here.**
//
// 1. A form word is not a name. The house wrote the rule twice already («a
//    label at Auto is paid for with its own shape», «a keyword is a token, not
//    a string»): where a kind has a shape the product can check, ask the same
//    function the arithmetic rule asks. The vocabulary that says «IBAN» names a
//    field is `rules::is_label_word` — the boundary the grouped validator stops
//    its own number at, so «…0130 00, BIC COBADEFFXXX» does not swallow the
//    next field. The scanner now asks that same function before any layer's
//    candidate becomes a finding. And the walk that reached the word at all
//    stops at the end of a sentence, which is the second guard below: `?` and
//    `!` were simply missing from the list of marks that already ended it.
// 2. A search can land inside our own token — this house has paid for that one
//    too, on the bar (`_` is not alphanumeric, so `PERSON` between two
//    underscores stands alone). The exit audit counted a value's places by
//    plain substring over the payload, and our tokens spell their kind in
//    capital letters. It now measures both sides outside the tokens this
//    program minted, by the same `tokens::token_spans` the scanner uses to
//    refuse a finding standing on one.
//
// The fourth guard is the whole of B1-3 end to end: the attacker's question,
// and every door still open after it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a label";

/// The lead's own German letter, already in this tree for
/// `an_iban_ends_where_the_number_ends`: it writes its account in a sentence
/// («auf die IBAN DE89 …») and again in the footer («, IBAN DE89 …, BIC …»),
/// which is the shape the report was measured on. The label stands in the
/// clear there twice — that is what makes the audit's arithmetic in this file
/// the arithmetic of a real document.
const LETTER: &str = include_str!("fixtures/Mahnung_Keller.txt");

/// The attacker's sentence, with this letter's two people in it.
const THE_QUESTION: &str =
    "Was schuldet Stefan Keller Frau Beate Hoffmann? IBAN DE89 3704 0044 0532 0130 00";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-label-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");
}

/// The letter in a session, every suggestion answered, nothing waiting — the
/// state a person is in when they type a question about what they are reading.
///
/// **The control is inside the fixture**, because a round of this house was
/// spent on guards that measured an unprotected document: if nothing here was
/// protected, every claim below about a value standing in the clear would be
/// true of a document that never left the clear at all.
fn ready() -> SessionId {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, LETTER.to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    let view = payload_view(build_payload(s).expect("a payload before the question"))
        .expect("the view of it");
    assert!(
        view.protected_count >= 4,
        "the fixture protected {} things, so nothing below would measure a protected document",
        view.protected_count
    );
    s
}

/// The text with our own tokens taken out of it.
///
/// Every claim in this file about a word standing «in the clear» is made over
/// this string and never over the raw one: the tokens spell their kind in
/// capitals, so `text.contains("IBAN")` is answered by the token that protects
/// the account — the other half of the very fault being measured.
fn in_the_clear(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    while let Some(at) = rest.find("__Z_") {
        out.push_str(&rest[..at]);
        let tail = &rest[at + 4..];
        match tail.find("__") {
            Some(end) => rest = &tail[end + 2..],
            None => {
                rest = tail;
                break;
            }
        }
    }
    out.push_str(rest);
    out
}

/// What the person typed, between the marks the core drew over it.
fn marked(marks: &[Mark], over: &str) -> Vec<(String, Kind)> {
    let units: Vec<u16> = over.encode_utf16().collect();
    marks
        .iter()
        .map(|m| {
            (
                String::from_utf16_lossy(&units[m.span.start as usize..m.span.end as usize]),
                m.kind,
            )
        })
        .collect()
}

/// Where a word stands in the letter, in the units a `Span` is counted in.
fn span_of(needle: &str) -> Span {
    let at = LETTER.find(needle).expect("the letter writes it");
    let start = LETTER[..at].encode_utf16().count() as u32;
    Span { start, end: start + needle.encode_utf16().count() as u32 }
}

// ------------------------------------------------- 1 · a label is not a value

/// **The attacker's own measurement, as a guard.** The question names an
/// account by its label; the label is not a person and leaves in the clear.
#[test]
fn the_word_that_names_a_field_is_not_a_person() {
    let _g = serial();
    fresh_vault("field");
    let s = ready();
    let view = set_question(s, THE_QUESTION.to_string()).expect("the question");
    let drawn = marked(&view.marks, THE_QUESTION);
    assert!(
        !drawn.iter().any(|(word, _)| word == "IBAN"),
        "the question's protection took the label «IBAN» as a value: {drawn:?}"
    );
    // The names and the number are still protected — a guard that only said
    // «IBAN is not protected» would be green for a question that protected
    // nothing at all.
    assert!(
        drawn.iter().filter(|(_, kind)| *kind == Kind::Person).count() >= 4,
        "the two people this question names must leave as tokens: {drawn:?}"
    );
    assert!(
        drawn.iter().any(|(_, kind)| *kind == Kind::Iban),
        "the account number itself must leave as a token: {drawn:?}"
    );
    // And the word stands where the person wrote it.
    let clear = in_the_clear(&view.text);
    assert!(
        clear.contains("IBAN"),
        "the label itself is text, and belongs in the question the model reads: {clear}"
    );
    assert!(
        !clear.contains("DE89"),
        "the account number may not stand in the clear: {clear}"
    );
}

/// **A name after a salutation ends where the sentence ends.**
///
/// The walk already stopped at a word carrying a comma, a full stop, a
/// semicolon, a colon or a closing bracket — `?` and `!` were missing from that
/// same enumeration, and in German every noun is capitalised, so the first
/// word of the next sentence is name-shaped whatever it means. This is the
/// label law's sibling and not a repetition of it: `Zahlungsziel` is in no
/// label vocabulary, and nothing but the sentence boundary keeps it out of the
/// question's tokens.
#[test]
fn a_name_after_a_salutation_ends_with_the_sentence() {
    let _g = serial();
    fresh_vault("sentence");
    let s = ready();
    let typed = "Was sagt Frau Beate Hoffmann? Zahlungsziel ist der 24. Oktober";
    let view = set_question(s, typed.to_string()).expect("the question");
    let drawn = marked(&view.marks, typed);
    assert!(
        !drawn.iter().any(|(word, _)| word == "Zahlungsziel"),
        "the walk crossed the question mark and made the next sentence's first noun a \
         person: {drawn:?}"
    );
    assert!(
        drawn.iter().any(|(word, _)| word == "Hoffmann"),
        "the person the question does name must still leave as a token: {drawn:?}"
    );
}

// --------------------------------------- 2 · the audit outside our own tokens

/// **A value may be protected even where its letters also spell one of our
/// kinds.**
///
/// A person reading this letter selects the word «IBAN» in the footer and
/// presses Protect for every place of it — their own hand, their own will,
/// 085's own ruling. Both labels are then replaced and nothing of the value
/// stands in the clear; the exit audit still refused to build, because the two
/// account tokens spell `IBAN` between their underscores and it counted them as
/// places the value stands.
///
/// This is the fault of B1-3's second half on its own, with no question in it
/// at all: the first fix does not reach it, and without the second one this
/// person's document can never leave again.
#[test]
fn the_exit_audit_does_not_count_a_value_inside_our_own_token() {
    let _g = serial();
    fresh_vault("audit");
    let s = ready();
    let outcome = protect(s, span_of("IBAN"), Scope::Conversation, Kind::Iban).expect("protect");
    let places = match outcome {
        ProtectOutcome::Applied { places, .. } => places,
        other => panic!("the hand's own protection: {other:?}"),
    };
    assert_eq!(places, 2, "the letter writes the word twice");
    let view = payload_view(build_payload(s).expect("the document may still leave"))
        .expect("the view of it");
    let clear = in_the_clear(&view.text);
    assert!(
        !clear.contains("IBAN"),
        "the person protected the word, so no place of it stands in the clear: {clear}"
    );
}

// ------------------------------------------------------- 3 · B1-3 end to end

/// **Every door is still open after the question.** The report's own sentence:
/// «Copy, PDF, pull and send are then all closed on this document.»
#[test]
fn the_attackers_question_leaves_and_every_door_stays_open() {
    let _g = serial();
    fresh_vault("doors");
    let s = ready();
    set_question(s, THE_QUESTION.to_string()).expect("the question");
    let handle = build_payload(s).expect("the send door");
    assert!(
        payload_view(handle).expect("the view").open_suggestions == 0,
        "the question opened a review queue of its own"
    );
    let taken = payload_to_take_out(s).expect("the copy door");
    assert!(
        !in_the_clear(&taken.text).contains("DE89"),
        "the account number left the machine in the clear"
    );
    let answer = ask_model(
        handle,
        ProviderId { id: "fake".to_string() },
        None,
        Vec::new(),
    )
    .expect("the model door");
    assert!(!answer.text.is_empty(), "the echo provider answered nothing");
}

/// **And the label law is the one that holds, not the sentence boundary.**
///
/// Written because the first guard above could be kept green by either fix: the
/// walk stopping at the question mark hides the label law and the label law
/// hides the walk. A person who types the same question with no punctuation in
/// it at all — and people do — gives the walk three name-shaped words to take,
/// honestly, and nothing but the vocabulary says the third one is a field name.
#[test]
fn a_label_a_walk_may_honestly_reach_is_still_not_a_name() {
    let _g = serial();
    fresh_vault("reach");
    let s = ready();
    let typed = "Was schuldet Stefan Keller Frau Beate Hoffmann IBAN DE89 3704 0044 0532 0130 00";
    let view = set_question(s, typed.to_string()).expect("the question");
    let drawn = marked(&view.marks, typed);
    assert!(
        !drawn.iter().any(|(word, _)| word == "IBAN"),
        "with no mark to end the sentence, the walk reached the label and protected it: {drawn:?}"
    );
    assert!(
        in_the_clear(&view.text).contains("IBAN"),
        "the label itself is text: {}",
        in_the_clear(&view.text)
    );
    build_payload(s).expect("and the exit is open");
}

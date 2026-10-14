// Contract C3 · no unanswered suggestion leaves in the clear — 083a.
//
// The owner, 13 Oct 2026: «أي تحديد هو تشفير» — and the other half of that
// model, ruled on the 14th: **a paragraph is not left until its words' fate is
// decided.** The review is how that is lived; this file is how it is
// guaranteed.
//
// Until this round the guarantee was written at **one** of three exits. A send
// through a key refused with `OpenSuggestions` (G12), and the two manual exits
// — Copy Protected and Save as PDF — asked the core for nothing at all: they
// took the text off the workspace snapshot and put it on the clipboard or in a
// file, with the waiting word standing in it exactly as the person wrote it.
// That is contract item C3, open on the app's side since the contract was
// sealed (`docs/CONFORMANCE_LEDGER.md`, `d882c5f`).
//
// ## Where the law sits, and why not in `build_payload`
//
// `build_payload` is **not** the exit. It is the instrument the workspace
// snapshot builds the Safe column with, on every read (`ops/snapshots.rs:61`),
// and the Safe column is what the person reads *while* answering — 083 rule 4
// moves both columns to the waiting word, and 084 rules 8–10 wash that word in
// both of them. A refusal there would blank the right-hand column for the
// whole of every review, which is the one moment it is needed.
//
// So the law sits at the door where text **leaves**: `payload_to_take_out`,
// which every exit now asks, and `no_word_waits` is the one function the three
// of them share. `build_payload` keeps telling the truth, including the truth
// that a word is still waiting (`PayloadView::open_suggestions`) — which is
// the fact `the_payload_counts_what_the_session_counts` in `no_leak.rs` stands
// on, and which a refusal here would have taken away from it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// A letter with a name a rule suggests and values the rules protect by
/// themselves — so every guard below has a **control**: something that must be
/// in the text that leaves, beside the thing that must not.
const LETTER: &str = "Kunde: Nordstern Consulting GmbH\n\
    Ansprechpartner: Herr Thomas Müller\n\
    IBAN: DE89370400440532013000\n\
    Wir bitten um eine Verlängerung des Zahlungsziels.";

/// The same letter with a second company, for the count.
const TWO_COMPANIES: &str = "Kunde: Nordstern Consulting GmbH\n\
    Ansprechpartner: Herr Thomas Müller\n\
    Auftraggeber: Südwind Logistik GmbH\n\
    IBAN: DE89370400440532013000\n\
    Wir bitten um eine Verlängerung des Zahlungsziels.";

/// The word under a span, read the way Flutter would hand it back: the core
/// speaks UTF-16 offsets at its edge, so this is the inverse of `span_of` in
/// the other test files.
fn word_at(doc: &str, span: Span) -> String {
    let units: Vec<u16> = doc.encode_utf16().collect();
    String::from_utf16_lossy(&units[span.start as usize..span.end as usize])
}

fn waiting(session: SessionId) -> Vec<Finding> {
    list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .collect()
}

/// A scanned letter with **exactly one** word still waiting for an answer, and
/// the word itself.
///
/// Measured, not assumed: this build's rules protect the person and the IBAN by
/// themselves and suggest the company — 2 auto, 1 waiting, 11 normal. The two
/// asserts below are the control: a build that changes its mind about any of
/// the three says so here by name instead of quietly proving nothing.
fn one_word_waiting() -> (SessionId, String) {
    let (s, mut words) = waiting_in(LETTER);
    assert_eq!(words.len(), 1, "the fixture must leave exactly one word waiting");
    (s, words.remove(0))
}

/// The same letter with a second company in it: two words waiting, so the
/// number in the refusal is read as a **count** and not as a 1 that happens to
/// be right.
fn two_words_waiting() -> (SessionId, Vec<String>) {
    let (s, words) = waiting_in(TWO_COMPANIES);
    assert_eq!(words.len(), 2, "the fixture must leave exactly two words waiting");
    (s, words)
}

fn waiting_in(text: &str) -> (SessionId, Vec<String>) {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, text.to_string()).expect("import");
    let report = scan(s).expect("scan");
    assert!(
        report.auto >= 1,
        "the fixture must protect something by itself — the control string of every guard below"
    );
    let doc = document_view(s).expect("view").text;
    let words = waiting(s)
        .iter()
        .map(|f| word_at(&doc, f.span))
        .collect::<Vec<String>>();
    assert_eq!(
        words.len() as u32,
        report.suggested,
        "the scan's own count and the findings disagree"
    );
    (s, words)
}

/// **The exit refuses, and says how many words are waiting** — 083, rule 11.
#[test]
fn no_text_leaves_while_a_word_waits() {
    let (s, word) = one_word_waiting();

    match payload_to_take_out(s) {
        Err(ApiError::OpenSuggestions { count }) => assert_eq!(
            count, 1,
            "the refusal must carry the number the person is about to be shown"
        ),
        Err(other) => panic!("the exit refused for the wrong reason: {other:?}"),
        Ok(view) => panic!(
            "the exit handed out {} characters while a word waited, and the word {} in them",
            view.text.chars().count(),
            if view.text.contains(&word) { "stands" } else { "does not stand" }
        ),
    }

    // The control, and the whole of why the refusal is worth having: the text
    // the exit would have handed out holds the waiting word exactly as the
    // person wrote it. Read through the snapshot's own instrument, which is
    // allowed to build while a word waits — see the head of this file.
    let would_have = payload_view(build_payload(s).expect("the Safe column still builds"))
        .expect("view")
        .text;
    assert!(
        would_have.contains(&word),
        "the fixture is not a leak at all: the waiting word is already protected in the text"
    );
}

/// **One law, not three** — the lead's condition for 083a: no exit carries its
/// own copy, so none of them can be fixed while the others are forgotten.
#[test]
fn every_door_that_takes_text_out_refuses_with_the_same_number() {
    let (s, _) = one_word_waiting();
    let handle = build_payload(s).expect("build");

    let doors: Vec<(&str, ApiError)> = vec![
        (
            "payload_to_take_out",
            payload_to_take_out(s).expect_err("the manual exits' door"),
        ),
        (
            "send",
            send(handle, ProviderId { id: "openai".to_string() }).expect_err("the send"),
        ),
        (
            "ask_model",
            ask_model(
                handle,
                ProviderId { id: "openai".to_string() },
                None,
                vec!["Summarise it.".to_string()],
                vec![],
            )
            .expect_err("the gateway"),
        ),
    ];

    for (name, err) in doors {
        match err {
            ApiError::OpenSuggestions { count } => assert_eq!(
                count, 1,
                "{name} refused with the wrong number of waiting words"
            ),
            other => panic!("{name} did not refuse for the waiting word: {other:?}"),
        }
    }
    // Neither refusal reached a provider: no credential was ever set in this
    // process, so a door that had got as far as the wire would have come back
    // `ProviderUnavailable` instead — which is what the two `send` doors answer
    // once nothing is waiting, below.
}

/// **The number in the refusal is the number waiting** — two words, not one.
///
/// A count that is right for «one» and wrong for «some» would reach the person
/// as a sentence naming the wrong number of their own words.
#[test]
fn the_refusal_carries_the_number_of_words_waiting() {
    let (s, words) = two_words_waiting();
    match payload_to_take_out(s) {
        Err(ApiError::OpenSuggestions { count }) => assert_eq!(count, 2),
        other => panic!("two words waiting, and the exit answered {other:?}"),
    }
    // Answer one of the two: the number falls by one, and the exit stays shut.
    let first = waiting(s)[0].id;
    answer_finding(s, first, FindingAnswer::Protect).expect("answer one");
    match payload_to_take_out(s) {
        Err(ApiError::OpenSuggestions { count }) => assert_eq!(count, 1),
        other => panic!("one word left waiting, and the exit answered {other:?}"),
    }
    assert_eq!(words.len(), 2, "the fixture named two words");
}

/// **Answer it, and the exit opens** — the same press, nothing else changed.
#[test]
fn the_word_answered_the_exit_opens() {
    let (s, word) = one_word_waiting();
    let left = waiting(s);
    answer_finding(s, left[0].id, FindingAnswer::Protect).expect("protect it");

    let view = payload_to_take_out(s).expect("the exit opens once nothing waits");
    assert_eq!(view.open_suggestions, 0);
    assert!(
        !view.text.contains(&word),
        "the word that was waiting stands in the text that left"
    );
    assert!(
        !view.text.contains("DE89370400440532013000"),
        "the IBAN the rules protected by themselves stands in the text that left"
    );
    // The control string: the search above works, and the text is the letter
    // rather than an empty string that would satisfy every absence.
    assert!(
        view.text.contains("Verlängerung"),
        "the text that left is not the letter at all"
    );
    assert!(
        view.protected_count >= 2,
        "the text that left claims {} protected places, and the letter had at least two",
        view.protected_count
    );

    // And the other two doors are past the law too: they now fail on the thing
    // this process genuinely has not got — a provider — and not on a word.
    for err in [
        send(build_payload(s).expect("build"), ProviderId { id: "openai".to_string() })
            .expect_err("no credential in this process"),
        ask_model(
            build_payload(s).expect("build"),
            ProviderId { id: "openai".to_string() },
            None,
            vec!["Summarise it.".to_string()],
            vec![],
        )
        .expect_err("no credential in this process"),
    ] {
        assert!(
            !matches!(err, ApiError::OpenSuggestions { .. }),
            "a door still says a word is waiting after the last one was answered"
        );
    }
}

/// **The Safe column keeps its text while a word waits** — deliberately, and
/// measured here so that nobody closes C3 a second time by blanking it.
///
/// 083 rule 4 moves both columns to the waiting word; 084 rules 8–10 wash that
/// word in both of them. Both need a right-hand column to exist mid-review, and
/// it is `build_payload` that makes one (`ops/snapshots.rs:61`).
#[test]
fn the_column_the_person_reads_while_answering_still_builds() {
    let (s, word) = one_word_waiting();
    let view = payload_view(build_payload(s).expect("build")).expect("view");
    assert_eq!(
        view.open_suggestions, 1,
        "the column must say how many words are waiting — the badge and the column agree or one lies"
    );
    assert!(
        view.text.contains(&word),
        "the waiting word is not in the column the person is about to answer it in"
    );
}

// 041-K · A hand-drawn selection takes whole words.
//
// From the owner's live run on the Swedish attachment, 6 October: manual
// protections came out as `J__Z_…`, `S__Z_…` and `Björn __Z_…` — a token with
// the first letter of the name still standing in front of it. The owner named
// the cause before anybody read the code: «the page margin does not let the
// first character be taken, so it disappears».
//
// It is not aim. At the left edge of the column the pointer lands *after* the
// first character every time, and a rule that depends on a steady hand is not
// a rule. So a selection grows out to whole words before it becomes anything.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// Three cases in one sentence each: a name at the start of a line, a name
/// with a mark after it, and a surname with a given name in front of it.
const DOC: &str = "Jonas Bjarne skrev avtalet.\n\
                   Kontakta Sandström, tack.\n\
                   Hälsningar, Björn Sandström\n\
                   Telefon: +46 8 123 456\n";

fn span_of(doc: &str, needle: &str) -> Span {
    let at = doc.find(needle).unwrap_or_else(|| panic!("«{needle}» is not in the document"));
    let start = doc[..at].chars().map(char::len_utf16).sum::<usize>() as u32;
    Span {
        start,
        end: start + needle.chars().map(char::len_utf16).sum::<usize>() as u32,
    }
}

fn text_of(session: SessionId, span: Span) -> String {
    let text = document_view(session).expect("view").text;
    let units: Vec<u16> = text.encode_utf16().collect();
    String::from_utf16_lossy(units.get(span.start as usize..span.end as usize).unwrap_or_default())
}

fn a_document() -> SessionId {
    let session = open_session(None, "sv".to_string()).expect("open");
    import_text(session, DOC.to_string()).expect("import");
    scan(session).expect("scan");
    session
}

/// The owner's own case, with his words for a name: the drag starts after the
/// first character of the first word on a line, and the whole word is taken.
#[test]
fn a_selection_that_starts_after_the_first_character_still_takes_the_word() {
    let session = a_document();
    let late = span_of(DOC, "onas Bjarne");

    // Before anything is pressed, the bubble is told the truth.
    let view = inspect_selection(session, late).expect("view");
    assert_eq!(text_of(session, view.word_span), "Jonas Bjarne", "the J was left behind");

    protect(session, late, Scope::Once, Kind::Person).expect("protect");
    let safe = payload_view(build_payload(session).expect("payload")).expect("view").text;

    assert!(
        !safe.contains("J__Z_"),
        "the first letter of the name is still in what would leave: {:?}",
        safe.lines().next().unwrap_or_default()
    );
    assert!(safe.starts_with("__Z_"), "the line does not begin with the token: {safe:?}");
    let _ = close_session(session);
}

/// A drag that overshoots takes the mark with it. The mark is not part of the
/// name, and a token with a comma inside it is a token nothing matches.
#[test]
fn the_marks_a_sentence_leaves_at_the_edges_are_dropped() {
    let session = a_document();
    let with_comma = span_of(DOC, "Sandström, ");

    let view = inspect_selection(session, with_comma).expect("view");
    assert_eq!(text_of(session, view.word_span), "Sandström", "the comma and the space came too");

    protect(session, with_comma, Scope::Once, Kind::Person).expect("protect");
    let safe = payload_view(build_payload(session).expect("payload")).expect("view").text;
    assert!(safe.contains("__Z_"), "nothing was protected at all");
    assert!(
        safe.contains(", tack."),
        "the comma was swallowed by the token: {:?}",
        safe.lines().nth(1).unwrap_or_default()
    );
    let _ = close_session(session);
}

/// And what is **not** done: the given name in front is offered, never taken.
/// «Björn Sandström» is two decisions, and the second one is the person's.
#[test]
fn the_capitalised_word_before_is_offered_and_never_taken() {
    let session = a_document();
    let surname = span_of(DOC, "Sandström\n");

    let view = inspect_selection(session, surname).expect("view");
    assert_eq!(text_of(session, view.word_span), "Sandström");
    let offered = view.also_before.expect("the given name in front was not offered");
    assert_eq!(text_of(session, offered), "Björn", "the wrong word was offered");

    // Protect takes only what was selected…
    protect(session, surname, Scope::Once, Kind::Person).expect("protect");
    let safe = payload_view(build_payload(session).expect("payload")).expect("view").text;
    assert!(
        safe.contains("Björn __Z_"),
        "the word in front was taken without being asked: {:?}",
        safe.lines().nth(2).unwrap_or_default()
    );

    let _ = close_session(session);

    // …and the offer, answered before the act rather than after it, takes both
    // as one. A fresh document, because answering is a thing a person does
    // instead of pressing Protect, not after it.
    let session = a_document();
    let view = inspect_selection(session, surname).expect("view");
    let offered = view.also_before.expect("offered");
    let both = Span {
        start: offered.start,
        end: view.word_span.end,
    };
    assert_eq!(text_of(session, both), "Björn Sandström");
    protect(session, both, Scope::Once, Kind::Person).expect("protect both");
    let safe = payload_view(build_payload(session).expect("payload")).expect("view").text;
    assert!(
        !safe.contains("Björn"),
        "answering the offer did not take the given name: {:?}",
        safe.lines().nth(2).unwrap_or_default()
    );
    let _ = close_session(session);
}

/// The marks a **value** is made of stay. A telephone number begins with `+`,
/// and a rule that tidies edges must know the difference between a mark around
/// a word and a mark inside a value.
#[test]
fn the_marks_a_value_is_made_of_are_kept() {
    let session = a_document();
    let phone = span_of(DOC, "+46 8 123 456");

    let view = inspect_selection(session, phone).expect("view");
    assert_eq!(text_of(session, view.word_span), "+46 8 123 456", "the plus was tidied away");

    protect(session, phone, Scope::Once, Kind::Phone).expect("protect");
    let safe = payload_view(build_payload(session).expect("payload")).expect("view").text;
    assert!(
        !safe.contains("+__Z_"),
        "the plus was left standing in front of the token: {:?}",
        safe.lines().nth(3).unwrap_or_default()
    );
    let _ = close_session(session);
}

/// A selection that is already whole is not moved. The rule only ever repairs.
#[test]
fn a_selection_that_is_already_whole_is_left_alone() {
    let session = a_document();
    for exact in ["Jonas Bjarne", "Sandström", "avtalet"] {
        let span = span_of(DOC, exact);
        let view = inspect_selection(session, span).expect("view");
        assert_eq!(view.word_span, span, "«{exact}» was moved although it was already whole");
    }
    let _ = close_session(session);
}

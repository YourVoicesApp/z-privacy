// **084 · what the search bar reads** — the owner's bar, 14 Oct: «وجدت ما كان
// ينقصنا في كل هذه العملية… شريط بحث في الوثيقة».
//
// One function answers the whole bar: the count, the two washes and all four
// acts come from this list, so the bar cannot come to disagree with itself.
//
// **The reading this file pins, and it corrected the paper:** a place's state
// is the state of **what covers it** — a protection, a finding nobody has
// answered, or nothing — and not the state of the word. One «Lindqvist» can be
// all three in one document, and `inspect_selection` could not tell the third
// from the second, because its `snaps_to` is built from protections alone.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// The word in five whole-word places: one inside a name a person protected,
/// one inside a company the pack still asks about, and three alone.
const DOC: &str = "Anna Lindqvist skrev avtalet.\n\
                   Kontakta Lindqvist i dag.\n\
                   Lindqvist AB levererar på fredag.\n\
                   Hälsningar till Lindqvist.\n\
                   Telefon: 070 123 45 67\n";

fn span_of(needle: &str) -> Span {
    let at = DOC.find(needle).expect("needle");
    let start = DOC[..at].chars().map(char::len_utf16).sum::<usize>() as u32;
    Span {
        start,
        end: start + needle.chars().map(char::len_utf16).sum::<usize>() as u32,
    }
}

fn a_document() -> SessionId {
    let session = open_session(None, "sv".to_string()).expect("open");
    import_text(session, DOC.to_string()).expect("import");
    scan(session).expect("scan");
    session
}

fn states(places: &[FoundPlace]) -> (usize, usize, usize) {
    (
        places.iter().filter(|p| p.state == FoundState::Protected).count(),
        places.iter().filter(|p| p.state == FoundState::Waiting).count(),
        places.iter().filter(|p| p.state == FoundState::Clear).count(),
    )
}

/// **The count guard** — the bar reports the places and, for each, the state of
/// what covers it.
#[test]
fn the_bar_counts_the_places_and_says_what_covers_each() {
    let session = a_document();
    // Before anything is protected: the pack asks about the name and the
    // company, so two places are waiting and the rest stand in the clear.
    let found = find_in_document(session, "Lindqvist".to_string()).expect("find");
    assert_eq!(found.len(), 4, "the word stands in four whole-word places");
    assert_eq!(states(&found), (0, 2, 2));

    // A person protects the name by hand — one place of the searched word.
    protect(session, span_of("Anna Lindqvist"), Scope::Conversation, Kind::Person).expect("protect");
    let found = find_in_document(session, "Lindqvist".to_string()).expect("find");
    assert_eq!(found.len(), 4);
    assert_eq!(states(&found), (1, 1, 2), "{found:?}");

    // **And what covers a place may be wider than what was typed** — 084's
    // ruling (c) rests on this being visible.
    let protected = found.iter().find(|p| p.state == FoundState::Protected).expect("one");
    assert_eq!(protected.covered_by, Some(span_of("Anna Lindqvist")));
    assert!(protected.token.is_some(), "a protected place without its token");
    assert_eq!(protected.kind, Kind::Person);

    let waiting = found.iter().find(|p| p.state == FoundState::Waiting).expect("one");
    assert_eq!(waiting.covered_by, Some(span_of("Lindqvist AB")));
    assert_eq!(waiting.kind, Kind::Company, "the kind of the cover, not of the word");
    assert!(waiting.token.is_none(), "a waiting place cannot have a token");

    let clear = found.iter().find(|p| p.state == FoundState::Clear).expect("one");
    assert_eq!(clear.covered_by, None);
    assert_eq!(clear.token, None);

    let _ = close_session(session);
}

/// The places come back **in reading order**, which is what «Next 1/12» walks.
#[test]
fn the_places_come_back_in_reading_order() {
    let session = a_document();
    let found = find_in_document(session, "Lindqvist".to_string()).expect("find");
    let starts: Vec<u32> = found.iter().map(|p| p.span.start).collect();
    let mut sorted = starts.clone();
    sorted.sort_unstable();
    assert_eq!(starts, sorted, "the bar would walk them in the scan's order");
    assert_eq!(found[0].span, span_of("Lindqvist"), "the first place is the first in the text");
    let _ = close_session(session);
}

/// **Whole-word and case-blind, because it is the product's own search** — the
/// same `occurrences` the scanner and the vault use. Part of a word finds
/// nothing, which is what the completion is for.
#[test]
fn the_search_is_the_products_own_whole_word_and_case_blind() {
    let session = a_document();
    assert_eq!(find_in_document(session, "LINDQVIST".to_string()).expect("find").len(), 4);
    assert_eq!(find_in_document(session, "lindqvist".to_string()).expect("find").len(), 4);
    assert!(find_in_document(session, "Lind".to_string()).expect("find").is_empty());
    assert!(find_in_document(session, "qvist".to_string()).expect("find").is_empty());
    // A number the pack protected by itself is found by its own text too, with
    // the token beside it — «the bar searches the original column».
    let phone = find_in_document(session, "070 123 45 67".to_string()).expect("find");
    assert_eq!(phone.len(), 1);
    assert_eq!(phone[0].state, FoundState::Protected);
    assert_eq!(phone[0].kind, Kind::Phone);
    let _ = close_session(session);
}

/// A blank search is nothing to search for — an empty list, not a refusal: the
/// bar may ask on every Enter.
#[test]
fn a_blank_search_is_nothing_and_not_a_refusal() {
    let session = a_document();
    for blank in ["", " ", "\t\n", "   "] {
        assert!(
            find_in_document(session, blank.to_string()).expect("find").is_empty(),
            "«{blank:?}» came back as something"
        );
    }
    assert!(find_in_document(session, "Nordstern".to_string()).expect("find").is_empty());
    let _ = close_session(session);
}

/// And a word inside a protection **and** inside the finding that was answered
/// to make it reads as **protected**: that is the state a person acts on, and
/// the two acts the bar offers for it are the two un-protections.
#[test]
fn a_place_covered_by_both_reads_as_protected() {
    let session = a_document();
    // Answering the company's suggestion protects it, and the finding stays in
    // the session as a decided one.
    let company = list_findings(session)
        .expect("findings")
        .into_iter()
        .find(|f| f.kind == Kind::Company)
        .expect("the company is asked about");
    answer_finding(session, company.id, FindingAnswer::Protect).expect("answer");

    let found = find_in_document(session, "Lindqvist".to_string()).expect("find");
    let inside = found
        .iter()
        .find(|p| p.covered_by == Some(span_of("Lindqvist AB")))
        .expect("the place inside the company");
    assert_eq!(inside.state, FoundState::Protected);
    assert!(inside.token.is_some());
    let _ = close_session(session);
}

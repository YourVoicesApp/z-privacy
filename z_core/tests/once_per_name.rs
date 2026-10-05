// 041-B · one decision per name.
//
// The owner, on the published build: the same value is suggested in two places
// and he answered it twice. `answer_finding` protected one range — the range of
// the finding whose button was pressed — while the hand path has spread across
// every occurrence since M5 and says «in 3 places» when it does.
//
// Measured on DE-1 (`Brief_Weber.txt`) before this was written: 28 findings, 8
// of them suggested, and two of those values stand twice — «2026-04471» as a
// Contract and «Lindenstraße 8, 86150 Augsburg» as an Address. Eight presses to
// clear the review; six once a decision carries.
//
// The people of DE-1 are not in that list at all: all seven are protected
// automatically, which is why the repeats here are a contract number and an
// address rather than a name. The rule is the same — same text, same kind.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const DE1: &str = "tests/fixtures/Brief_Weber.txt";

fn de1() -> (SessionId, String) {
    let session = open_session(None, "de".to_string()).expect("session");
    let text = std::fs::read_to_string(DE1).expect("the DE-1 fixture");
    import_text(session, text.clone()).expect("import");
    scan(session).expect("scan");
    (session, text)
}

fn suggested(session: SessionId) -> Vec<Finding> {
    list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .collect()
}

fn text_of(whole: &str, f: &Finding) -> String {
    whole
        .chars()
        .skip(f.span.start as usize)
        .take((f.span.end - f.span.start) as usize)
        .collect()
}

/// The two places the owner answered twice, and the count the card must show.
#[test]
fn a_repeated_value_is_one_decision_and_says_how_many_places() {
    let (session, text) = de1();
    let open = suggested(session);
    assert_eq!(open.len(), 8, "DE-1's review is not the eight it was measured at");

    let twins: Vec<Finding> = open
        .iter()
        .filter(|f| text_of(&text, f) == "2026-04471")
        .cloned()
        .collect();
    assert_eq!(twins.len(), 2, "«2026-04471» is not suggested twice any more");

    // The card says what one press will do, and the core is what counts it.
    for f in &twins {
        assert_eq!(f.occurrences, 2, "a finding that stands twice says {}", f.occurrences);
    }
    let lone = open
        .iter()
        .find(|f| text_of(&text, f) == "Weber Elektrotechnik GmbH")
        .expect("the company that stands once");
    assert_eq!(lone.occurrences, 1, "a value that stands once says otherwise");

    // One press, both places.
    answer_finding(session, twins[0].id, FindingAnswer::Protect).expect("protect");
    let left = suggested(session);
    assert_eq!(left.len(), 6, "one decision did not clear both places: {} left", left.len());
    assert!(
        !left.iter().any(|f| text_of(&text, f) == "2026-04471"),
        "the twin is still waiting for its own press"
    );

    // And both are really protected, not merely unlisted.
    let protected: Vec<Finding> = list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Protected && text_of(&text, f) == "2026-04471")
        .collect();
    assert_eq!(protected.len(), 2, "only one place was protected");
    for f in &protected {
        assert!(f.decided, "a place the person did not press is not marked as decided by them");
    }
}

/// «Not sensitive» carries the same way: the value is dismissed, not the range.
#[test]
fn not_sensitive_clears_every_place_of_that_value() {
    let (session, text) = de1();
    let address = suggested(session)
        .into_iter()
        .find(|f| text_of(&text, f) == "Lindenstraße 8, 86150 Augsburg")
        .expect("the address that stands twice");
    assert_eq!(address.occurrences, 2);

    answer_finding(session, address.id, FindingAnswer::NotSensitive).expect("not sensitive");
    let left = suggested(session);
    assert_eq!(left.len(), 6, "one «not sensitive» left {} suggestions", left.len());
    assert!(
        !left.iter().any(|f| text_of(&text, f) == "Lindenstraße 8, 86150 Augsburg"),
        "the second place still asks"
    );
    // Nothing was protected by saying «no».
    assert!(
        !list_findings(session)
            .expect("findings")
            .iter()
            .any(|f| f.state == MarkState::Protected && text_of(&text, f) == "Lindenstraße 8, 86150 Augsburg"),
        "«not sensitive» protected something"
    );
}

/// Skip is about this place, and stays about this place: it is how a person
/// says «not now», and nothing about the other places follows from that.
#[test]
fn skip_stays_where_it_was_pressed() {
    let (session, text) = de1();
    let twins: Vec<Finding> = suggested(session)
        .into_iter()
        .filter(|f| text_of(&text, f) == "2026-04471")
        .collect();
    assert_eq!(twins.len(), 2);

    answer_finding(session, twins[0].id, FindingAnswer::Skip).expect("skip");
    let left = suggested(session);
    assert_eq!(left.len(), 8, "skipping decided something");
    assert_eq!(
        left.iter().filter(|f| text_of(&text, f) == "2026-04471").count(),
        2,
        "skipping one place took the other with it"
    );
}

/// The press count the owner feels, before and after, on the measured document.
#[test]
fn de1_costs_six_presses_instead_of_eight() {
    let (session, text) = de1();
    let mut presses = 0;
    loop {
        let open = suggested(session);
        let Some(next) = open.first().cloned() else { break };
        answer_finding(session, next.id, FindingAnswer::Protect).expect("protect");
        presses += 1;
        assert!(presses <= 8, "the review does not end");
        let _ = &text;
    }
    assert_eq!(presses, 6, "DE-1 still costs {presses} presses");
}

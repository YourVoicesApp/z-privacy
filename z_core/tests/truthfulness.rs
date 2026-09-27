// Truthfulness — a category of its own, named by the owner on 27 September.
//
//   > Any field the interface shows as a fact must have a real source of truth.
//   > In a privacy application, the honesty of the interface is part of the
//   > security.
//
// It is not a UX concern. Four times now a screen has stated something that was
// not so, and none of it was caught by a test that only asked «does the code
// work»:
//
//   «0 suggestions»              `open_suggestions` was hard-coded to 0 from M2
//   «0 tries left»               `attempts_left` was hard-coded to 0
//   «Vault unlocked»             two screens could have read two sources
//   «exactly what will be sent»  said while `send` was refusing the payload
//
// The shape of every test below is the same, and it is what makes the category
// work: **two independent reports of one fact must agree.** A single number can
// be wrong quietly forever; two numbers that must match cannot.
//
// Nothing here touches the vault. The vault is one per process, and a test that
// made one would change the fourth layer under the others' feet — which is how
// this file first went red. Its vault-side truthfulness test lives in
// `vault_layer.rs`, beside the lock that serialises them.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const DOC: &str = "Kunde: Nordstern Consulting GmbH\n\
Ansprechpartner: Herr Thomas Müller\n\
E-Mail: t.mueller@nordstern-consulting.de\n\
IBAN: DE89370400440532013000\n\
Frau Anna Weber vertritt ihn.";

/// Everything a screen would draw about one session, asked for separately.
struct AsReported {
    report_auto: u32,
    report_suggested: u32,
    findings_protected: u32,
    findings_suggested: u32,
    payload_protected: u32,
    payload_open: u32,
    tokens: u32,
    marks_protected: u32,
    marks_suggested: u32,
    report_vault: VaultState,
    asked_vault: VaultState,
    send_refused_for: Option<u32>,
}

/// `report` is the one the core last handed over — from `scan` or from
/// `answer_finding`. Looking must not rescan: a rescan renumbers the findings,
/// so an observer that rescanned would be changing what it came to measure.
fn look(s: SessionId, report: &ScanReport) -> AsReported {
    let findings = list_findings(s).expect("findings");
    let doc = document_view(s).expect("document");
    let handle = build_payload(s).expect("build");
    let payload = payload_view(handle).expect("payload");
    let send_refused_for = match send(handle, ProviderId { id: "openai".to_string() }) {
        Err(ApiError::OpenSuggestions { count }) => Some(count),
        _ => None,
    };
    AsReported {
        report_auto: report.auto,
        report_suggested: report.suggested,
        findings_protected: findings.iter().filter(|f| f.state == MarkState::Protected).count() as u32,
        findings_suggested: findings.iter().filter(|f| f.state == MarkState::Suggested).count() as u32,
        payload_protected: payload.protected_count,
        payload_open: payload.open_suggestions,
        tokens: list_tokens(s).expect("tokens").len() as u32,
        marks_protected: doc.marks.iter().filter(|m| m.state == MarkState::Protected).count() as u32,
        marks_suggested: doc.marks.iter().filter(|m| m.state == MarkState::Suggested).count() as u32,
        report_vault: report.vault,
        asked_vault: vault_state().expect("vault"),
        send_refused_for,
    }
}

/// Every pair that must agree, in one place, so a new state is checked against
/// all of them at once.
fn must_agree(at: &str, r: &AsReported) {
    assert_eq!(
        r.report_suggested, r.findings_suggested,
        "{at}: the review badge and the review list disagree"
    );
    assert_eq!(
        r.report_suggested, r.payload_open,
        "{at}: the review badge and the Safe column disagree — this is the «0 suggestions» lie"
    );
    assert_eq!(
        r.report_suggested, r.marks_suggested,
        "{at}: the count and the marks drawn on the document disagree"
    );
    assert_eq!(
        r.report_auto, r.findings_protected,
        "{at}: «protected automatically» and the list of them disagree"
    );
    assert_eq!(
        r.payload_protected, r.marks_protected,
        "{at}: the Safe column says it replaced {} values, the document shows {} protected",
        r.payload_protected, r.marks_protected
    );
    assert_eq!(
        r.report_vault, r.asked_vault,
        "{at}: the band's vault state and the vault's own state disagree"
    );
    // «This is exactly what the AI will receive» is only true when send agrees.
    match r.send_refused_for {
        Some(count) => assert_eq!(
            count, r.payload_open,
            "{at}: send refuses for a different number than the screen shows"
        ),
        None => assert_eq!(
            r.payload_open, 0,
            "{at}: the screen shows open suggestions but send would not refuse"
        ),
    }
    // Every protected mark stands for a token, and there are no spare tokens.
    assert!(
        r.tokens <= r.marks_protected,
        "{at}: {} tokens for {} protected places — a token nothing points at",
        r.tokens,
        r.marks_protected
    );
}

#[test]
fn every_number_two_places_report_agrees_in_every_state() {
    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");

    // 1 · straight after the scan on import.
    let report = scan(s).expect("scan");
    let after_scan = look(s, &report);
    assert!(after_scan.report_suggested > 0, "the fixture leaves something open");
    assert!(after_scan.report_auto > 0, "and protects something by itself");
    must_agree("after the scan", &after_scan);

    // 2 · one suggestion answered, the rest still open. The state that caught
    // the first lie, because it is the only one where the two numbers differ.
    let open: Vec<u32> = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| f.id)
        .collect();
    let report = answer_finding(s, open[0], FindingAnswer::Protect).expect("answer");
    must_agree("with one answered", &look(s, &report));

    // 3 · one skipped: still open, still counted — skipping is not deciding.
    let still: Vec<u32> = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| f.id)
        .collect();
    if let Some(id) = still.first() {
        let before = report.suggested;
        let report = answer_finding(s, *id, FindingAnswer::Skip).expect("skip");
        let after = look(s, &report);
        assert_eq!(after.report_suggested, before, "a skip changed a count");
        must_agree("with one skipped", &after);
    }

    // 4 · everything answered. Now «exactly what will be sent» may be said.
    let mut report = report;
    for id in still {
        report = answer_finding(s, id, FindingAnswer::Protect).expect("answer");
    }
    let settled = look(s, &report);
    assert_eq!(settled.report_suggested, 0);
    assert!(settled.send_refused_for.is_none(), "nothing is waiting, so nothing refuses");
    must_agree("with everything answered", &settled);

    // 5 · a protection by hand, and then taken back. Both move every number.
    let span = Span { start: 0, end: 5 };
    protect(s, span, Scope::Conversation, Kind::Custom).expect("protect");
    // A hand protection does not produce a report, so the one to compare with
    // is the fresh scan — which is also what the Rescan button would show.
    let report = scan(s).expect("rescan");
    must_agree("after protecting by hand", &look(s, &report));
    undo_last_protection(s).expect("undo");
    let report = scan(s).expect("rescan");
    must_agree("after undoing it", &look(s, &report));

    close_session(s).expect("close");
}

#[test]
fn the_safe_column_is_the_string_that_would_be_sent() {
    // «This is exactly what the AI will receive» is a claim about identity, not
    // about similarity. The only honest check is character for character.
    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }

    let handle = build_payload(s).expect("build");
    let shown = payload_view(handle).expect("view").text;

    // The same handle asked twice is the same string: a view is not a snapshot
    // of a moment, it is the payload.
    assert_eq!(payload_view(handle).expect("again").text, shown);

    // And a *new* payload built from an unchanged session says the same thing.
    let again = build_payload(s).expect("build again");
    assert_eq!(payload_view(again).expect("view").text, shown);

    // Change the session and the old handle is refused rather than showing a
    // stale truth — the screen cannot keep claiming «exactly what will be sent»
    // about a document that has moved on.
    protect(s, Span { start: 0, end: 5 }, Scope::Once, Kind::Custom).expect("protect");
    assert!(matches!(
        send(handle, ProviderId { id: "openai".to_string() }),
        Err(ApiError::StalePayload { .. })
    ));
    assert!(matches!(payload_view(handle), Err(ApiError::StalePayload { .. })));

    close_session(s).expect("close");
}

#[test]
fn no_number_on_a_screen_is_a_constant() {
    // The shape all four lies had: a field that never changed, whatever
    // happened. Anything reported as a fact must move when the fact moves.
    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");

    let mut seen_open = Vec::new();
    let mut seen_protected = Vec::new();

    scan(s).expect("scan");
    let start = payload_view(build_payload(s).expect("build")).expect("view");
    seen_open.push(start.open_suggestions);
    seen_protected.push(start.protected_count);

    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
            let now = payload_view(build_payload(s).expect("build")).expect("view");
            seen_open.push(now.open_suggestions);
            seen_protected.push(now.protected_count);
        }
    }

    seen_open.dedup();
    seen_protected.dedup();
    assert!(
        seen_open.len() > 1,
        "open_suggestions never changed across the whole review: {seen_open:?}"
    );
    assert!(
        seen_protected.len() > 1,
        "protected_count never changed while things were being protected: {seen_protected:?}"
    );
    assert_eq!(*seen_open.last().expect("last"), 0, "and it ends at zero honestly");

    close_session(s).expect("close");
}

#[test]
fn a_rescan_does_not_take_back_an_answer_you_gave() {
    // «A token once given is never silently taken back» — the behaviour board.
    //
    // Until task 033 a rescan kept only what `source == Hand`, so an answered
    // suggestion — whose source is the pack that found it — was dropped and
    // asked again. A person would answer two questions, press Rescan, and find
    // both back in the clear with the badge at 2. Found by the truthfulness
    // tests, because the marks and the count stopped agreeing.
    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    let first = scan(s).expect("scan");
    assert!(first.suggested > 0, "there is something to answer");

    let mut tokens_given = Vec::new();
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    for row in list_tokens(s).expect("tokens") {
        tokens_given.push(row.token);
    }
    let settled = scan(s).expect("rescan");

    assert_eq!(settled.suggested, 0, "a rescan asked the answered questions again");
    let after: Vec<String> = list_tokens(s).expect("tokens").into_iter().map(|t| t.token).collect();
    for token in &tokens_given {
        assert!(after.contains(token), "the rescan took back {token}");
    }

    // And the review list still says who **found** each one — the decision did
    // not rewrite the reason into «you».
    let from_a_layer = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.source != Source::Hand)
        .count();
    assert!(from_a_layer > 0, "the pack is still credited with finding them");

    close_session(s).expect("close");
}

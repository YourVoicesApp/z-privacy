// The golden fixture: one document that never changes, so the scanner's numbers
// are a regression test and not an opinion.
//
// `7 auto · 2 suggest · 428 normal` is asserted **here**, never written into the
// code: the core counts what it finds, and this test says what that count was on
// the day the fixture was frozen. If a rule changes tomorrow, this test is the
// thing that notices.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const FIXTURE: &str = include_str!("fixtures/Vertrag_Nordstern.txt");

fn scanned_session() -> (SessionId, ScanReport) {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, FIXTURE.to_string()).expect("import");
    let report = scan(s).expect("scan");
    (s, report)
}

#[test]
fn golden_counts_do_not_move() {
    let (_s, report) = scanned_session();
    assert_eq!(
        (report.auto, report.suggested, report.normal),
        (7, 2, 428),
        "the golden fixture's counts moved: {report:?}"
    );
}

#[test]
fn golden_every_finding_says_what_and_why() {
    let (s, _) = scanned_session();
    let findings = list_findings(s).expect("findings");
    assert_eq!(findings.len(), 9, "seven protected and two waiting");

    for f in &findings {
        assert!(f.span.end > f.span.start, "a finding must point somewhere");
        assert!(!f.reason.is_empty(), "a finding with no reason is not allowed");
        // Every field the owner asked for: kind, state, source, reason, span.
        match f.state {
            MarkState::Protected | MarkState::Suggested => {}
        }
        match f.source {
            Source::GeneralRule | Source::LanguagePack => {}
            other => panic!("no vault or hand finding can exist in M3: {other:?}"),
        }
    }
}

#[test]
fn golden_auto_is_only_what_can_be_proven() {
    let (s, _) = scanned_session();
    let findings = list_findings(s).expect("findings");

    let protected: Vec<&Finding> = findings.iter().filter(|f| f.state == MarkState::Protected).collect();
    let open: Vec<&Finding> = findings.iter().filter(|f| f.state == MarkState::Suggested).collect();

    // Protected on sight: a bank account, a BIC, an e-mail, a telephone number in
    // international form, a customer number, a tax id — each one either carries a
    // checksum or stands after a label that says what it is.
    let mut kinds: Vec<Kind> = protected.iter().map(|f| f.kind).collect();
    kinds.sort_by_key(|k| format!("{k:?}"));
    assert_eq!(
        kinds,
        vec![
            Kind::Bic,
            Kind::CustomerNo,
            Kind::Email,
            Kind::Iban,
            Kind::Phone,
            Kind::TaxId,
            Kind::TaxId
        ],
        "the automatic set changed"
    );

    // Left for the user: a person's name after a salutation, and a company name
    // ending in a legal form. Both are habits of the language, not proofs.
    let mut open_kinds: Vec<Kind> = open.iter().map(|f| f.kind).collect();
    open_kinds.sort_by_key(|k| format!("{k:?}"));
    assert_eq!(open_kinds, vec![Kind::Company, Kind::Person]);
    for f in open {
        assert_eq!(f.source, Source::LanguagePack, "only a pack guesses");
    }
}

#[test]
fn golden_one_value_two_layers_one_token() {
    // The owner's extra test for M3. The IBAN is seen twice: the general rule
    // proves it by its checksum, and the German pack sees the label «IBAN:». The
    // result must be ONE finding and ONE token — not two overlapping protections.
    let (s, _) = scanned_session();

    let findings = list_findings(s).expect("findings");
    let ibans: Vec<&Finding> = findings
        .iter()
        .filter(|f| f.kind == Kind::Iban && f.reason.contains("mod-97"))
        .collect();
    assert_eq!(ibans.len(), 1, "one value, one finding: {ibans:?}");
    let only = ibans[0];
    assert!(
        only.reason.contains("agreed as well"),
        "the review list must be able to say both layers saw it: {}",
        only.reason
    );

    // And in the payload: the number appears once, as one token.
    let text = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert!(!text.contains("DE89 3704"), "the account is still in the payload");
    let tokens = list_tokens(s).expect("tokens");
    let iban_tokens: Vec<&TokenRow> = tokens.iter().filter(|t| t.token.contains("_IBAN_")).collect();
    assert_eq!(iban_tokens.len(), 1, "the IBAN is one token, not two: {iban_tokens:?}");
    // And the BIC carries its own kind: a bank's identifier is not an account.
    assert_eq!(
        tokens.iter().filter(|t| t.token.contains("_BIC_")).count(),
        1,
        "a BIC must not be labelled IBAN, in the token or anywhere else"
    );
}

#[test]
fn golden_a_rescan_keeps_what_you_did_by_hand() {
    let (s, _) = scanned_session();
    // Protect something the scanner did not ask about: the word «Bankgarantie».
    let byte = FIXTURE.find("Bankgarantie").expect("word");
    let start: usize = FIXTURE[..byte].chars().map(char::len_utf16).sum();
    let span = Span {
        start: start as u32,
        end: (start + "Bankgarantie".chars().map(char::len_utf16).sum::<usize>()) as u32,
    };
    protect(s, span, Scope::Conversation, Kind::Custom).expect("protect by hand");

    let again = scan(s).expect("rescan");
    assert_eq!((again.auto, again.suggested), (7, 2), "the layers found the same");

    let text = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert!(
        !text.contains("Bankgarantie"),
        "a rescan must never undo what the user protected by hand"
    );
}

#[test]
fn golden_answering_the_two_clears_the_way_to_send() {
    let (s, report) = scanned_session();
    assert_eq!(report.suggested, 2);

    // Invariant G12: while a suggestion is open, nothing can be sent.
    let handle = build_payload(s).expect("build");
    match send(handle, ProviderId { id: "openai".to_string() }) {
        Err(ApiError::OpenSuggestions { count }) => assert_eq!(count, 2),
        other => panic!("a send with open suggestions must be refused, got {other:?}"),
    }

    // Answer both: one is protected, one is not sensitive.
    let open: Vec<u32> = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| f.id)
        .collect();
    let after_first = answer_finding(s, open[0], FindingAnswer::Protect).expect("protect it");
    assert_eq!(after_first.suggested, 1);
    let after_second = answer_finding(s, open[1], FindingAnswer::NotSensitive).expect("leave it");
    assert_eq!(after_second.suggested, 0);
    assert_eq!(after_second.auto, 8, "the confirmed one joined the protected set");

    // A payload built after the answers may go as far as the provider door.
    let fresh = build_payload(s).expect("build");
    assert!(matches!(
        send(fresh, ProviderId { id: "openai".to_string() }),
        Err(ApiError::ProviderUnavailable { .. })
    ));
}

#[test]
fn golden_by_layer_says_who_caught_what() {
    let (_s, report) = scanned_session();
    let total: u32 = report.by_layer.iter().map(|l| l.count).sum();
    assert_eq!(total, report.auto, "every protected item belongs to a layer");
    assert!(
        report.by_layer.iter().any(|l| l.source == Source::GeneralRule),
        "arithmetic caught some: {:?}",
        report.by_layer
    );
    assert!(
        report
            .by_layer
            .iter()
            .any(|l| l.source == Source::LanguagePack && l.detail == "de"),
        "the German pack caught some, and names itself: {:?}",
        report.by_layer
    );
}

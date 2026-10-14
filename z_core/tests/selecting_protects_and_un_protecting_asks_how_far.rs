// **083c and 083d in the core** — the owner's rulings 1 and 3, 13–14 Oct.
//
// «أي تحديد هو تشفير… الخيارات هي في فك التشفير»: a selection protects with no
// question, and the only choices left are the two that **undo** it — here, or
// in this conversation. There is no «everywhere».
//
// Two laws are measured here, and each one was watched failing against the
// tree that was green before it:
//
//   * **the kind of a hand selection** is what the scanner found on exactly
//     that stretch, or `Custom` — never a guess from a second classifier
//     (the lead's ruling of 14 Oct on the question paper 083 left open);
//   * **un-protection by the token**: «here» leaves every other place
//     protected under the same token, and «in this conversation» takes them
//     all — and in both directions what leaves the device stays true (C4).
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// Three places of one name, and a label the Swedish pack knows, so the
/// document has both a found value and an unfound one.
const DOC: &str = "Kontakta Lindqvist i dag.\n\
                   Lindqvist skrev avtalet.\n\
                   Hälsningar till Lindqvist.\n\
                   Telefon: 070 123 45 67\n";

fn span_of(doc: &str, needle: &str, nth: usize) -> Span {
    let at = doc.match_indices(needle).nth(nth).expect("that place").0;
    let start = doc[..at].chars().map(char::len_utf16).sum::<usize>() as u32;
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

/// **The kind is the scanner's own, on exactly this stretch — or honestly
/// unknown.**
///
/// What was here until 14 Oct: the scanner run over the selected text alone,
/// then the kind of a mark that merely overlapped, then a shape test on the
/// words («one or two capitalised words is a person»). Each is a second
/// classifier, and the kind travels **inside the token**, where a model reads
/// it. An honest unknown beats a confident guess: in German every noun is
/// capitalised, so the shape test would have called every one of them a person.
#[test]
fn the_kind_of_a_hand_selection_is_what_the_scanner_found_or_nothing() {
    let session = a_document();

    // The phone number, which the pack proved from its label: exactly that
    // stretch is a finding, so the kind is the finding's.
    let phone = span_of(DOC, "070 123 45 67", 0);
    assert_eq!(inspect_selection(session, phone).expect("view").kind, Kind::Phone);

    // A name no list knows, selected by hand: **`Custom`, and that is the
    // ruling.** This is the case hand selection exists for, and the honest
    // answer is «we do not know what this is».
    let name = span_of(DOC, "Lindqvist", 0);
    assert_eq!(
        inspect_selection(session, name).expect("view").kind,
        Kind::Custom,
        "a guess came back: the kind must be the scanner's finding or nothing"
    );

    // And half of a value the scanner *did* find is not that value's kind: the
    // finding covers «070 123 45 67», not «123».
    let part = span_of(DOC, "123", 0);
    assert_eq!(inspect_selection(session, part).expect("view").kind, Kind::Custom);

    let _ = close_session(session);
}

/// **A hand selection protects every place of it, in this conversation** —
/// ruling 1 with 083b's ruling 7: one decision per word per conversation.
#[test]
fn one_hand_selection_protects_every_place_under_one_token() {
    let session = a_document();
    let outcome = protect_all_matches(
        session,
        span_of(DOC, "Lindqvist", 0),
        Scope::Conversation,
        Kind::Custom,
    )
    .expect("protect");
    let token = match outcome {
        ProtectOutcome::Applied { places, token } => {
            assert_eq!(places, 3);
            token
        }
        other => panic!("the hand path did not take every place: {other:?}"),
    };
    // **One token over the three places**, which is the point — and measured on
    // the payload rather than by counting the panel's rows: this document also
    // has a telephone number the scan protected by itself, so «how many tokens
    // are there» answers a different question than «how many does the name
    // have». (My own first assertion said «three places, three tokens» and was
    // red for that reason, not for the product's.)
    let safe = payload_view(build_payload(session).expect("payload")).expect("view").text;
    assert_eq!(safe.matches(&token).count(), 3);
    assert!(!safe.contains("Lindqvist"), "a place was left in the clear: {safe:?}");
    let _ = close_session(session);
}

/// **«Here» — this one place, and the others keep their protection and their
/// token.** And what would leave the device stays true: the payload carries the
/// token where it is still protected, the uncovered place reads as the document
/// reads, and a model answer that quotes the token still restores (C4).
#[test]
fn un_protecting_here_leaves_the_other_places_and_their_token_alone() {
    let session = a_document();
    protect_all_matches(session, span_of(DOC, "Lindqvist", 0), Scope::Conversation, Kind::Person)
        .expect("protect");
    let token = list_tokens(session).expect("tokens")[0].token.clone();

    let undone = unprotect(session, span_of(DOC, "Lindqvist", 1)).expect("unprotect");
    match undone {
        UndoOutcome::Undone { places, .. } => assert_eq!(places, 1, "«here» reached further than here"),
        other => panic!("nothing was undone: {other:?}"),
    }

    let safe = payload_view(build_payload(session).expect("payload")).expect("view").text;
    assert_eq!(safe.matches(&token).count(), 2, "the other places lost their token");
    assert_eq!(
        safe.matches("Lindqvist").count(),
        1,
        "the uncovered place does not read as the document reads"
    );

    // **The restore still works where the protection stayed** — the question
    // the lead asked for before this was built.
    let answer = ingest_answer(
        build_payload(session).expect("payload"),
        format!("Jag kontaktar {token} i morgon."),
    )
    .expect("ingest");
    let restored: String = restored_view(session, answer)
        .expect("restored")
        .iter()
        .map(|s| s.text.clone())
        .collect();
    assert!(
        restored.contains("Lindqvist"),
        "a model answer quoting the token no longer restores: {restored:?}"
    );
    let _ = close_session(session);
}

/// **«In this conversation» — every place that carries the token, and no other
/// conversation.**
#[test]
fn un_protecting_in_this_conversation_takes_every_place_of_that_token() {
    let session = a_document();
    protect_all_matches(session, span_of(DOC, "Lindqvist", 0), Scope::Conversation, Kind::Person)
        .expect("protect");
    // A second value protected beside it, to prove the breadth is the token's
    // and not «everything in the document».
    protect(session, span_of(DOC, "070 123 45 67", 0), Scope::Conversation, Kind::Phone)
        .expect("protect the phone");
    assert_eq!(list_tokens(session).expect("tokens").len(), 2);

    let undone = unprotect_every_place(session, span_of(DOC, "Lindqvist", 2)).expect("unprotect");
    match undone {
        UndoOutcome::Undone { places, .. } => assert_eq!(places, 3, "it did not take every place"),
        other => panic!("nothing was undone: {other:?}"),
    }

    let safe = payload_view(build_payload(session).expect("payload")).expect("view").text;
    assert_eq!(safe.matches("Lindqvist").count(), 3, "a place stayed protected");
    assert_eq!(
        list_tokens(session).expect("tokens").len(),
        1,
        "the token nothing points at any more is still in the panel, or the phone's went with it"
    );
    assert!(!safe.contains("070 123 45 67"), "the phone was uncovered too");

    // And the other conversation is untouched — the only scope un-protection
    // has is this one. A second session over the same text keeps its own.
    let other = a_document();
    protect_all_matches(other, span_of(DOC, "Lindqvist", 0), Scope::Conversation, Kind::Person)
        .expect("protect");
    let before = list_tokens(other).expect("tokens").len();
    let _ = unprotect_every_place(session, span_of(DOC, "Lindqvist", 0));
    assert_eq!(list_tokens(other).expect("tokens").len(), before, "it reached another conversation");

    let _ = close_session(session);
    let _ = close_session(other);
}

/// **How many places the card may say** — `Explanation.places`, which is what
/// puts the number in the broad act's own name. The direction that uncovers
/// says how many, the same law «Skip all» keeps.
#[test]
fn the_card_knows_how_many_places_the_broad_act_would_uncover() {
    let session = a_document();
    protect_all_matches(session, span_of(DOC, "Lindqvist", 0), Scope::Conversation, Kind::Person)
        .expect("protect");
    protect(session, span_of(DOC, "070 123 45 67", 0), Scope::Conversation, Kind::Phone)
        .expect("protect the phone");

    let why = explain(session, span_of(DOC, "Lindqvist", 1)).expect("explain");
    assert_eq!(why.places, 3);
    let why = explain(session, span_of(DOC, "070 123 45 67", 0)).expect("explain");
    assert_eq!(why.places, 1, "a value that stands once must not offer a batch act");

    let _ = close_session(session);
}

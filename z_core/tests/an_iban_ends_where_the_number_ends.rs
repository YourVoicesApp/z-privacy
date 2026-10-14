// **A bank value ends where the value ends** — the detection round of 14
// October, item 1, and the Conformance Ledger's line for `d882c5f`.
//
// A German letter writes its account in a sentence and again in the footer:
//
// ```text
//   … auf die IBAN DE.. …. …. …. …. .. zu überweisen …
//   Bankverbindung: Commerzbank AG, IBAN DE.. … .. , BIC COBADEFFXXX
// ```
//
// The label rule took the number and kept going. `Validator::Grouped` asked
// only whether the next word was letters and digits, and «zu», «BIC» and the
// BIC's own value are letters. So the token that left the machine carried a
// word of German prose, or the next field entirely — measured by the lead on
// two invented letters («…0130 00, BIC», «…3249 31 zu») and on the film
// («…7466 on 2»).
//
// zprivacy-lib does not do this: V1-G ends the span at the last group of the
// number. The ledger calls that *library ahead*, and this is the app catching
// up — so these guards are written against the library's behaviour, not
// against ours.
//
// The fixture is a letter, not a string: the shape only exists in a document
// where the number stands inside a sentence and inside a footer line.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const LETTER: &str = include_str!("fixtures/Mahnung_Keller.txt");

/// The account number as the letter writes it. Nothing is printed by a guard:
/// a failure says how many characters too many were taken, never the value.
const ACCOUNT: &str = "DE89 3704 0044 0532 0130 00";

fn scanned() -> SessionId {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, LETTER.to_string()).expect("import");
    // **Said out loud, because leaving it out made two of these guards green
    // while they measured nothing**: an import does not scan — item 3 of this
    // same round — so `list_findings` is empty until this line runs.
    scan(s).expect("scan");
    s
}

fn word_at(span: Span) -> String {
    let units: Vec<u16> = LETTER.encode_utf16().collect();
    String::from_utf16_lossy(&units[span.start as usize..span.end as usize])
}

fn of_kind(session: SessionId, kind: Kind) -> Vec<String> {
    list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == kind)
        .map(|f| word_at(f.span))
        .collect()
}

#[test]
fn an_iban_is_the_number_and_not_the_words_after_it() {
    let s = scanned();
    let found = of_kind(s, Kind::Iban);
    assert_eq!(found.len(), 2, "the letter writes its account twice: {found:?}");
    for taken in &found {
        assert_eq!(
            taken.chars().count(),
            ACCOUNT.chars().count(),
            "the IBAN token took {} characters too many — the number is {} long and the \
             rule kept reading past it",
            taken.chars().count() as i64 - ACCOUNT.chars().count() as i64,
            ACCOUNT.chars().count()
        );
        assert_eq!(taken, ACCOUNT, "the IBAN token is not the account number");
    }
}

#[test]
fn a_bank_value_carries_no_word_of_prose() {
    let s = scanned();
    // The law, said once over both kinds: a group of a bank value is letters
    // and digits, and a word of prose is neither. «zu», «bei», «on» — the
    // three the lead measured — are all lowercase, and an account number has
    // no lowercase letter in it anywhere.
    for kind in [Kind::Iban, Kind::Bic] {
        for taken in of_kind(s, kind) {
            assert!(
                !taken.chars().any(|c| c.is_ascii_lowercase()),
                "a {kind:?} finding carries a lowercase word — {} characters of prose went \
                 into the token",
                taken.chars().filter(|c| c.is_ascii_lowercase()).count()
            );
        }
    }
}

#[test]
fn an_iban_in_a_footer_line_stops_before_the_next_label() {
    let s = scanned();
    // «Bankverbindung: Commerzbank AG, IBAN DE.. … .., BIC COBADEFFXXX» is one
    // line and two fields. The account number took the comma, the word «BIC»
    // and the BIC itself — 17 characters past the end of the number — and the
    // boundary that was supposed to stop it only knew a label by its colon.
    for taken in of_kind(s, Kind::Iban) {
        assert!(
            !taken.contains("BIC"),
            "the IBAN swallowed the field beside it: {} characters past the number",
            taken.chars().count() - ACCOUNT.chars().count()
        );
    }
}

#[test]
fn the_bic_in_a_footer_line_is_read_as_a_bic() {
    let s = scanned();
    // And the field it swallowed is still protected, by its own rule and under
    // its own kind. A label whose value is written in capitals and is eight
    // characters or more is shaped like a value even without its colon — which
    // is what a footer line writes.
    let bics = of_kind(s, Kind::Bic);
    assert_eq!(
        bics.len(),
        1,
        "the letter's BIC is not a finding of its own: {} found",
        bics.len()
    );
    assert!(
        bics.first().is_some_and(|b| b.chars().all(|c| c.is_ascii_uppercase())),
        "what was taken for the BIC is not a BIC"
    );
}

#[test]
fn the_rest_of_the_letter_did_not_move() {
    let s = scanned();
    let report = scan(s).expect("scan again, for the numbers");
    // The anchor for this fixture, written down the day it was frozen: the two
    // bank values are protected, and the words the IBAN used to swallow are
    // ordinary words again.
    assert_eq!(
        (report.auto, report.suggested, report.normal),
        (8, 5, 86),
        "the letter's counts moved: {report:?}"
    );
}

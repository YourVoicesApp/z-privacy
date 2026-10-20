// **What an English letter still carried after its review was finished** —
// 095, خ4, the outside model's third serious finding (19 October 2026).
//
// It imported the owner's own «إنجليزي 2» with pack `en`, answered the single
// suggestion the scan offered, and then searched the text that leaves. Seven
// things were still in it: the person's given name, a date of birth, an
// employee number, a National Insurance number, a payment card number, a
// street line and a postcode. Every one of them under its own English label,
// in a letter whose German twin has had rules for each of those fields for a
// month.
//
// **The fixture here is the same shape with invented values**
// (`fixtures/Grievance_Whitaker.txt`): a grievance letter that writes «Mr
// Whitaker» in its salutation — so the surname is protected and the given name
// stands alone, which is the model's own «half a name» — and carries each of
// the six labelled fields. The card number is the Visa test number, which
// belongs to nobody.
//
// **The counts this moves, named here and in the commit:** this is a new
// fixture, so no golden count moves because of it. The German letter's own
// counts move by two (the box and the bank) and that is خ5's business, written
// there.
//
// **And the limits this round keeps, measured rather than promised:** a date of
// birth written out in words («12 April 1985») is **not** taken, because a
// month-name list is language data this round did not add; the last test here
// holds that line so nobody reads خ4's fix as «every date».
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const LETTER: &str = include_str!("fixtures/Grievance_Whitaker.txt");

fn found(doc: &str) -> Vec<(MarkState, Kind, String)> {
    let s = open_session(None, "en".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    let out = list_findings(s)
        .expect("findings")
        .into_iter()
        .map(|f| {
            let text = String::from_utf16_lossy(
                units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
            );
            (f.state, f.kind, text)
        })
        .collect();
    close_session(s).ok();
    out
}

/// The letter after a finished review — every suggestion answered Protect,
/// nothing waiting — and the text the manual doors would hand out.
fn what_leaves(doc: &str) -> String {
    let s = open_session(None, "en".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    let out = payload_to_take_out(s).expect("the copy door").text;
    close_session(s).ok();
    out
}

/// Is there a finding of this kind covering this text?
fn taken(doc: &str, kind: Kind, needle: &str) -> bool {
    found(doc).iter().any(|(_, k, text)| *k == kind && text.contains(needle))
}

// ------------------------------------------------- 1 · the model's own needles

/// **The whole of خ4 in one test**: after the review is finished, none of the
/// seven stands in the text that leaves.
#[test]
fn nothing_the_model_found_is_still_in_the_clear() {
    let left = what_leaves(LETTER);
    for needle in [
        "James",
        "12/04/1985",
        "NGE-20417",
        "QQ 12 34 56 C",
        "4111 1111 1111 1111",
        "7 Elm Terrace",
        "LS6 2PQ",
    ] {
        assert!(
            !left.contains(needle),
            "«{needle}» is still in the text that leaves, after every suggestion was answered"
        );
    }
}

// --------------------------------------------------------- 2 · each by itself

/// **Half a name is not a protected name.** The salutation gives «Whitaker»;
/// the given name beside it belongs to the same person.
#[test]
fn the_given_name_beside_a_protected_surname_is_taken_too() {
    let people: Vec<_> = found(LETTER)
        .into_iter()
        .filter(|(_, kind, text)| *kind == Kind::Person && text == "James")
        .collect();
    assert!(
        !people.is_empty(),
        "«James» stands beside a protected «Whitaker» three times and is no finding"
    );
}

#[test]
fn a_national_insurance_number_admits_its_letters() {
    assert!(
        taken(LETTER, Kind::SocialInsuranceNo, "QQ 12 34 56 C"),
        "the NI number under its own label is not a finding; `en-34` exists and \
         asked for a number, and this one carries letters"
    );
}

#[test]
fn a_payment_card_is_found_by_its_own_arithmetic() {
    assert!(
        taken(LETTER, Kind::Account, "4111 1111 1111 1111"),
        "the card number in the body is not a finding, and the English rules \
         have said «card» in a comment with no detector behind it"
    );
}

#[test]
fn a_date_of_birth_under_its_label_is_a_birthdate() {
    assert!(
        taken(LETTER, Kind::Birthdate, "12/04/1985"),
        "the date of birth under «Date of birth:» is not a finding"
    );
}

#[test]
fn an_employee_number_under_its_label_is_taken() {
    assert!(
        taken(LETTER, Kind::EmployeeNo, "NGE-20417"),
        "the employee number under its own label is not a finding, and the kind \
         exists for it"
    );
}

#[test]
fn a_uk_address_line_is_an_address() {
    let all = found(LETTER);
    assert!(
        all.iter().any(|(_, kind, text)| *kind == Kind::Address && text.contains("Elm Terrace")),
        "the street line is no address: {all:?}"
    );
    assert!(
        all.iter().any(|(_, kind, text)| *kind == Kind::Address && text.contains("LS6 2PQ")),
        "the postcode is no address: {all:?}"
    );
}

// ---------------------------------------------------------- 3 · the controls

/// **A label at `Auto` is paid for with its own shape.** The same labels with
/// a value of the wrong shape take nothing.
#[test]
fn a_label_with_a_value_of_the_wrong_shape_takes_nothing() {
    let doc = "Date of birth: unknown\nEmployee number: pending\n\
               National Insurance number: not on file\n";
    let taken = found(doc);
    assert!(
        taken.is_empty(),
        "a label took a word that is not the shape it names: {taken:?}"
    );
}

/// **And a number that is not a card is not a card.** Luhn is the whole of
/// what makes the card rule honest: sixteen digits are a reference number, an
/// order id, a serial.
#[test]
fn sixteen_digits_that_fail_luhn_are_not_a_card() {
    let doc = "Order reference 4111 1111 1111 1112 was shipped on 2 October.\n";
    let taken: Vec<_> = found(doc)
        .into_iter()
        .filter(|(_, kind, _)| *kind == Kind::Account)
        .collect();
    assert!(
        taken.is_empty(),
        "a number that fails its own checksum was protected as a card: {taken:?}"
    );
}

/// **The limit, measured: a date written out in words is still missed.** The
/// month names are language data and this round did not add them, so «12 April
/// 1985» under the same label is not taken. Written here so that the next
/// reader of خ4 knows what was fixed and what was not.
#[test]
fn a_date_of_birth_written_out_in_words_is_still_missed() {
    let doc = "Date of birth: 12 April 1985\n";
    let dates: Vec<_> = found(doc)
        .into_iter()
        .filter(|(_, kind, _)| *kind == Kind::Birthdate)
        .collect();
    assert!(
        dates.is_empty(),
        "the written-out date is taken now — good, and this test is the one to \
         rewrite with the month list's own limit measured: {dates:?}"
    );
}

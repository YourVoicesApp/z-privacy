// 038-G · what a German payroll document is made of.
//
// The first real user keeps his clients' payroll accounts. A payslip and a
// ledger carry four things this build could not read: the social-insurance
// number, the eleven-digit tax identification number, the personnel number,
// and a table whose header names what stands under it. Each is its own commit
// and its own measurement; this file is where the arithmetic is held to
// account, on numbers nobody was ever issued.
//
// Every number below is invented. The valid ones were computed with the
// published algorithms and the broken ones differ from them by one digit, so a
// rule that stopped checking would fail here before it reached a document.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

fn found(doc: &str) -> Vec<(MarkState, Kind, String)> {
    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    list_findings(session)
        .expect("findings")
        .into_iter()
        .map(|f| {
            (
                f.state,
                f.kind,
                String::from_utf16_lossy(
                    units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
                ),
            )
        })
        .collect()
}

fn kinds_of(doc: &str, kind: Kind) -> Vec<(MarkState, String)> {
    found(doc).into_iter().filter(|(_, k, _)| *k == kind).map(|(s, _, t)| (s, t)).collect()
}

/// A Sozialversicherungsnummer is `NN DDMMYY L NNN`: an area number, the
/// bearer's birth date, the first letter of their birth name, a serial, and a
/// check digit over all of it. Nothing else has that shape, which is why it is
/// a general rule and not a German one — and why it is Auto.
#[test]
fn a_social_insurance_number_is_proven_by_its_own_check_digit() {
    for number in ["15 030578 K 037", "28 111290 W 479", "04 010160 B 993"] {
        let doc = format!("Die Nummer {number} steht im Antrag.");
        let got = kinds_of(&doc, Kind::SocialInsuranceNo);
        assert_eq!(got.len(), 1, "«{number}» was not read as a social-insurance number: {got:?}");
        assert_eq!(got[0].0, MarkState::Protected, "«{number}» was only offered");
        assert_eq!(got[0].1, number, "the span is not the whole number");
    }
    // Written without its spaces, as a form writes it.
    let got = kinds_of("SVNR 15030578K037 liegt vor.", Kind::SocialInsuranceNo);
    assert_eq!(got.len(), 1, "the compact form is not read: {got:?}");
    assert_eq!(got[0].1, "15030578K037");
}

#[test]
fn a_number_that_fails_its_check_is_not_one() {
    for number in [
        "15 030578 K 038", // one off the check digit
        "28 111290 W 470",
        "04 010160 B 994",
        "15 320578 K 037", // the 32nd of March
        "15 031378 K 037", // the thirteenth month
    ] {
        let doc = format!("Die Nummer {number} steht im Antrag.");
        let got = kinds_of(&doc, Kind::SocialInsuranceNo);
        assert!(got.is_empty(), "«{number}» passed as a social-insurance number: {got:?}");
    }
}

/// And it is not a telephone number, an IBAN, or anything else that happens to
/// be digits with a space in it.
#[test]
fn what_a_social_insurance_number_is_not() {
    let doc = "Telefon 089 1234 5699, IBAN DE89 3704 0044 0532 0130 00.";
    assert!(
        kinds_of(doc, Kind::SocialInsuranceNo).is_empty(),
        "a phone or an IBAN was read as a social-insurance number"
    );
}

// ------------------------------------------------------- the eleven digits

/// The *steuerliche Identifikationsnummer*: eleven digits that carry their own
/// proof. Two rules together, both published by the BZSt — a check digit
/// (ISO 7064, MOD 11,10) and a structure (among the first ten, exactly one
/// digit appears twice or three times, at least one digit is missing, and the
/// first is not zero). Eleven digits that pass both are not a coincidence.
#[test]
fn a_tax_identification_number_is_proven_by_its_check_and_its_shape() {
    for number in ["98 765 432 114", "25 813 794 623", "98765432114"] {
        let doc = format!("Steuerliche Identifikationsnummer {number}.");
        let got = kinds_of(&doc, Kind::TaxId);
        assert_eq!(got.len(), 1, "«{number}» was not read as a tax ID: {got:?}");
        assert_eq!(got[0].0, MarkState::Protected, "«{number}» was only offered");
        assert_eq!(got[0].1, number, "the span is not the whole number");
    }
}

#[test]
fn eleven_digits_that_fail_either_rule_are_not_a_tax_id() {
    for (number, why) in [
        ("98 765 432 115", "one off the check digit"),
        ("12 345 678 903", "no digit appears twice, so it is not one of these"),
        ("08 765 432 116", "a tax ID never begins with zero"),
        ("98 765 432 11", "ten digits"),
    ] {
        let doc = format!("Nummer {number} steht im Formular.");
        let got = kinds_of(&doc, Kind::TaxId);
        assert!(got.is_empty(), "«{number}» passed as a tax ID — {why}: {got:?}");
    }
}

/// And the eleven digits of something else are not it either.
#[test]
fn what_eleven_digits_are_not() {
    let doc = "IBAN DE89 3704 0044 0532 0130 00 und Telefon 089 1234 5699.";
    assert!(kinds_of(doc, Kind::TaxId).is_empty(), "an IBAN or a phone was read as a tax ID");
}

// ------------------------------------------------------- the phone stops

/// A date is not a telephone number, and a payslip is full of dates.
///
/// Measured on DE-6 before this: «01.02.2019», «02.11.1979» and «09.05.1985»
/// were offered as local telephone numbers, because a German date that begins
/// with a zero is eight digits with separators between them — which is exactly
/// what the local-phone shape is. Three false questions on one page, each of
/// them a date the document says is a date.
#[test]
fn a_german_date_is_never_a_telephone_number() {
    for date in ["01.02.2019", "02.11.1979", "09.05.1985", "08.12.2026", "01.01.2000"] {
        let doc = format!("Eintrittsdatum: {date} laut Vertrag.");
        let got = kinds_of(&doc, Kind::Phone);
        assert!(got.is_empty(), "«{date}» was offered as a telephone number: {got:?}");
    }
}

/// And the telephone numbers are still telephone numbers.
#[test]
fn the_real_numbers_still_read_as_numbers() {
    let doc = "Durchwahl 089 1234 5699, mobil +49 171 2345678.";
    let got = kinds_of(doc, Kind::Phone);
    assert_eq!(got.len(), 2, "a real number stopped being one: {got:?}");
    assert!(got.iter().any(|(state, text)| *state == MarkState::Protected && text == "+49 171 2345678"));
    assert!(got.iter().any(|(_, text)| text == "089 1234 5699"));
}

// ------------------------------------------------------- the payroll labels

/// A ledger calls its people by a personnel number, and nothing else follows
/// that word. It is pack data, like «Kundennummer» — and it is **not**
/// `CustomerNo`: the kind's word is read twice, in the explain card and in the
/// token the model is asked about, and «customer number» is wrong in both on a
/// payslip.
#[test]
fn a_personnel_number_is_named_by_its_label() {
    for label in ["Personal-Nr.", "Personalnummer", "Pers.-Nr.", "Personalnr."] {
        let doc = format!("{label}: 004711\nKostenstelle: 2100\n");
        let got = kinds_of(&doc, Kind::EmployeeNo);
        assert_eq!(got.len(), 1, "«{label}» named no personnel number: {got:?}");
        assert_eq!(got[0], (MarkState::Protected, "004711".to_string()));
    }
    // The label stays a label: the number is protected, the word is not.
    let doc = "Personal-Nr.: 004711";
    assert!(
        found(doc).iter().all(|(_, _, text)| !text.contains("Personal")),
        "the label itself was protected"
    );
}

/// And the label that begins with the same letters is still itself: an identity
/// card is not a personnel number.
#[test]
fn the_identity_card_label_is_not_shadowed() {
    let doc = "Personalausweisnummer L01X00T47 liegt vor.";
    let got = kinds_of(doc, Kind::IdCard);
    assert_eq!(got.len(), 1, "the identity card was lost to a longer label list: {got:?}");
    assert!(kinds_of(doc, Kind::EmployeeNo).is_empty(), "an identity card became a personnel number");
}

/// The two identifier labels a payslip writes, for the numbers that cannot
/// prove themselves — a tax ID written in a form the check cannot reach, or a
/// social-insurance number from another country's office.
#[test]
fn the_payroll_labels_name_their_kinds() {
    let doc = "Sozialversicherungsnummer: 65 140388 L 516\nSteuer-ID: 86 095 742 719\n";
    assert_eq!(kinds_of(doc, Kind::SocialInsuranceNo).len(), 1);
    assert_eq!(kinds_of(doc, Kind::TaxId).len(), 1);
}

// ------------------------------------------------------- the reversed pair

/// «Reinhardt, Tobias» is a person, and a ledger writes its people that way.
///
/// Phase 2 could only *discover* that form: the rule fired when the word before
/// the comma was a surname **nobody knew**, and offered it as a name to look at.
/// 038-H then made it worse by knowing more: «Demir» is a given name in three
/// city registers now, so the comma rule walked past it and the person vanished
/// from the review entirely — knowing more names found fewer people.
///
/// So the reversed pair becomes a rule of its own. The evidence is the **given**
/// name after the comma; the word before it is a surname whether this build has
/// heard of it or not. Offered, never protected — a list may not decide that a
/// word is somebody's name.
#[test]
fn a_ledger_writes_its_people_backwards_and_they_are_still_people() {
    // No header: this is the rule on its own, and what it offers it offers.
    // A column headed «Name» is another rule and protects outright — that is
    // 038-G/6, and it has its own test.
    let page = "004712        Reinhardt, Tobias     02.11.1979\n\
        004713        Haddad, Amira         23.07.1991\n\
        004714        Demir, Yusuf          09.05.1985\n";
    let people: Vec<(MarkState, String)> = kinds_of(page, Kind::Person);
    for who in ["Reinhardt, Tobias", "Haddad, Amira", "Demir, Yusuf"] {
        assert!(
            people.iter().any(|(_, text)| text == who),
            "«{who}» is not a person here: {people:?}"
        );
    }
    for (state, text) in &people {
        assert_eq!(*state, MarkState::Suggested, "«{text}» was protected by a dictionary pair");
    }
}

/// What it must not do: a comma between two ordinary words is still a comma.
#[test]
fn a_comma_is_not_a_person() {
    for doc in [
        "Berlin, Hauptstadt der Bundesrepublik.",
        "Anlage 3, Seite 7 des Vertrags.",
        "Vorfinanzierung, da Material und Fertigung vorher bezahlt werden.",
        "Krankheiten des Ösophagus, des Magens und des Duodenums (K20).",
    ] {
        let got = kinds_of(doc, Kind::Person);
        assert!(got.is_empty(), "«{doc}» named a person: {got:?}");
    }
}

/// And after a label it is still protected outright, as it was.
#[test]
fn the_labelled_reversed_pair_is_still_auto() {
    let got = kinds_of("Name: Lindemann, Katharina\n", Kind::Person);
    assert_eq!(got.len(), 1, "the labelled form stopped working: {got:?}");
    assert_eq!(got[0].0, MarkState::Protected);
}

// ------------------------------------------------------- a column of values

/// A table says what its columns are, once, at the top — and then never again.
///
/// A ledger's four birth dates stand under the word «Geburtsdatum» and carry no
/// label of their own; so do its four personnel numbers. A label rule reads the
/// word before a value, and in a table the word before a value is the value in
/// the column to its left. The header is the label, and it labels a column.
#[test]
fn a_header_names_the_column_under_it() {
    let page = "Personal-Nr.  Name                  Geburtsdatum  Eintritt\n\
        004712        Reinhardt, Tobias     02.11.1979    01.03.2019\n\
        004713        Haddad, Amira         23.07.1991    15.08.2020\n\
        004714        Demir, Yusuf          09.05.1985    01.02.2019\n";
    let dates = kinds_of(page, Kind::Birthdate);
    assert_eq!(dates.len(), 3, "the birth-date column was not read: {dates:?}");
    for (state, text) in &dates {
        assert_eq!(*state, MarkState::Protected, "«{text}» was only offered");
        assert!(["02.11.1979", "23.07.1991", "09.05.1985"].contains(&text.as_str()), "«{text}»");
    }
    let staff = kinds_of(page, Kind::EmployeeNo);
    assert_eq!(staff.len(), 3, "the personnel-number column was not read: {staff:?}");

    // The column beside it is not a birth date: «Eintritt» is nobody's label.
    assert!(
        !dates.iter().any(|(_, text)| text == "01.03.2019"),
        "a date from another column was read as a birth date"
    );
}

/// What it must not do: prose is not a table, and a line that happens to have
/// two spaces in it is not a column.
#[test]
fn prose_is_not_a_table() {
    let page = "Geburtsdatum des Kindes\n\
        Die Lieferung erfolgt am 14.03.1988 und am 02.11.1979.\n\
        Der Vertrag läuft weiter.\n";
    let dates = kinds_of(page, Kind::Birthdate);
    assert!(dates.is_empty(), "a sentence under a word became a column: {dates:?}");
}

/// And a table of codes has no header this build knows, so nothing happens to
/// it — which is what keeps 734 pages of ICD-10 out of this rule.
#[test]
fn a_table_whose_header_is_not_a_label_is_left_alone() {
    let page = "Kode      Bezeichnung                  Seite\n\
        A00.0     Cholera, durch Vibrio cholerae    17\n\
        A00.1     Cholera, durch Vibrio eltor       18\n";
    assert!(found(page).iter().all(|(_, kind, _)| *kind != Kind::Birthdate));
    assert!(found(page).iter().all(|(_, kind, _)| *kind != Kind::EmployeeNo));
}

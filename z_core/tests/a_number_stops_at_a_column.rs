// 046/M · a number ends where the column ends.
//
// Found by the lead by **printing** the findings on the film's own English
// payroll sheet, not by counting them — the counts said 61 of 61 protected and
// nothing waiting, which was true and told nobody anything. The texts said:
//
// ```text
//     Account:«7210»
//     Account:«7210     42 500»     ← and the same for all eight ledger rows
// ```
//
// Section B of that sheet reads
//
// ```text
//     25 February 2027   Hedvig Palmgren      account 7210     42 500
// ```
//
// and the `account` label row took the amount with the code. So **every ledger
// amount went to the model inside a token** — and the demo's whole point is
// that the model finds a 2 400 difference by arithmetic on amounts and dates
// while seeing no names. It was being asked to do that with half the numbers
// gone. The reconciliation lines at the foot survive, so it might have answered
// anyway, which is worse than failing: a demo that works by luck.
//
// It is also wrong on its own terms. `7210` is a **ledger account code**, not
// anybody's bank account; protecting it is noise, and the amount beside it is
// not personal data at all.
//
// **The rule, and the whole of it:** one space continues a grouped number —
// `42 500`, `9999 000 01` — and two or more spaces, or a tab, end it. That is a
// column boundary, not a thousands separator. 038-G/3's family («the phone rule
// stops where a grouped id stands») arriving from the other side.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for one column";

/// A ledger laid out in columns, invented, in the shape the owner's sheet uses.
const LEDGER: &str = "\
25 February 2027   Hedvig Palmgren      account 7210     42 500\n\
25 February 2027   Tobias Nyqvist       account 7210     34 800\n\
12 February 2027   Nadia Berglind       account 7210      2 400\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-column-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

fn scanned(doc: &str, pack: &str) -> SessionId {
    let s = open_session(None, pack.to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    s
}

fn of_kind(session: SessionId, doc: &str, kind: Kind) -> Vec<String> {
    let mut out: Vec<String> = list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == kind)
        .map(|f| {
            doc.chars()
                .skip(f.span.start as usize)
                .take((f.span.end - f.span.start) as usize)
                .collect::<String>()
        })
        .collect();
    out.sort();
    out.dedup();
    out
}

fn leaves(session: SessionId) -> String {
    payload_view(build_payload(session).expect("payload")).expect("view").text
}

// ------------------------------------------------------------- 1 · the climax

/// **The acceptance: the code is taken, the amount is not.**
#[test]
fn a_ledger_code_does_not_take_the_amount_beside_it() {
    let _g = serial();
    fresh_vault("ledger");
    let s = scanned(LEDGER, "en");
    assert_eq!(
        of_kind(s, LEDGER, Kind::Account),
        vec!["7210".to_string()],
        "the account row crossed the column gap"
    );
    close_session(s).ok();
}

/// **And every amount reaches the model**, which is the only thing the demo
/// actually needs: the arithmetic is the point and the names are not.
#[test]
fn every_amount_reaches_the_model() {
    let _g = serial();
    fresh_vault("amounts");
    let s = scanned(LEDGER, "en");
    let out = leaves(s);
    for amount in ["42 500", "34 800", "2 400"] {
        assert!(out.contains(amount), "«{amount}» went to the model inside a token: {out:?}");
    }
    close_session(s).ok();
}

// -------------------------------------------------------------- 2 · the line

/// **One space is still a thousands separator.** The rule is about two, and a
/// rule that broke `42 500` into `42` would have traded one defect for a worse
/// one.
#[test]
fn one_space_still_holds_a_grouped_number_together() {
    let _g = serial();
    fresh_vault("one-space");
    const DOC: &str = "Account number: 9999 000 01\nIBAN: GB29 NWBK 6016 1331 9268 19\n";
    let s = scanned(DOC, "en");
    assert_eq!(
        of_kind(s, DOC, Kind::Account),
        vec!["9999 000 01".to_string()],
        "a single space broke a grouped account number"
    );
    assert_eq!(
        of_kind(s, DOC, Kind::Iban),
        vec!["GB29 NWBK 6016 1331 9268 19".to_string()],
        "a single space broke an IBAN"
    );
    close_session(s).ok();
}

/// A tab is a column boundary too, and it is the one a spreadsheet writes.
#[test]
fn a_tab_is_a_column_boundary() {
    let _g = serial();
    fresh_vault("tab");
    const DOC: &str = "Account number: 440821\t42 500\n";
    let s = scanned(DOC, "en");
    assert_eq!(of_kind(s, DOC, Kind::Account), vec!["440821".to_string()]);
    close_session(s).ok();
}

/// **A name may be laid out in columns and is not a number**, so the rule is
/// only for the two validators that read a run of digits across spaces. A
/// table of people with two spaces inside a name must keep the name whole.
#[test]
fn a_name_is_not_cut_by_a_column_gap() {
    let _g = serial();
    fresh_vault("name");
    const DOC: &str = "Contact person: Eleanor  Whitfield\n";
    let s = scanned(DOC, "en");
    assert_eq!(
        of_kind(s, DOC, Kind::Person),
        vec!["Eleanor  Whitfield".to_string()],
        "the column rule reached a name"
    );
    close_session(s).ok();
}

/// And the first word after the label is always taken, however it is spaced:
/// `Account number:` followed by two spaces and then the value is a form laid
/// out neatly, not a column boundary before anything.
#[test]
fn the_space_after_the_label_is_not_a_boundary() {
    let _g = serial();
    fresh_vault("after-label");
    const DOC: &str = "Account number:    61920447\n";
    let s = scanned(DOC, "en");
    assert_eq!(of_kind(s, DOC, Kind::Account), vec!["61920447".to_string()]);
    close_session(s).ok();
}

// -------------------------------------------------------------- 3 · the debt

/// **What the same print showed by its absence, written as a debt.**
///
/// The nine account numbers of the sheet's section A — `9999 000 01` to `08` —
/// are in **no finding at all**, before 046/J or after. Their header is
/// `account no.`, but the values sit in a **table column**, and
/// `Boundary::AfterLabelSameField` never reaches them — exactly as it never
/// reached the national identity numbers.
///
/// Those were saved by a **shape** rule. An account number has no shape of its
/// own: `9999 000 01` is eleven digits in three groups and so is a hundred
/// other things. So only the header-column rule reaches these, which is
/// **038-G/6**, and it is not this task's.
///
/// This test fails the day it lands, and that is what it is for.
#[test]
fn a_number_under_a_column_header_is_still_missed() {
    let _g = serial();
    fresh_vault("header");
    const TABLE: &str = "\
date               name                 account no.    amount\n\
25 February 2027   Hedvig Palmgren      9999 000 01    42 500\n";
    let s = scanned(TABLE, "en");
    assert!(
        of_kind(s, TABLE, Kind::Account).is_empty(),
        "an account number under a column header is now found — if 038-G/6 has \
         landed, this test has done its job and should become the number it \
         finds: {:?}",
        of_kind(s, TABLE, Kind::Account)
    );
    // And the control, or this says nothing: the same value **after a label**
    // is found, so what is missing is the header and nothing else.
    const LABELLED: &str = "Account no.: 9999 000 01\n";
    let c = scanned(LABELLED, "en");
    assert_eq!(
        of_kind(c, LABELLED, Kind::Account),
        vec!["9999 000 01".to_string()],
        "the control is broken: the value is not found even after a label"
    );
    close_session(c).ok();
    close_session(s).ok();
}

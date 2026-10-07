// 046/Q · the line is the unit, and a column is reached by example.
//
// **The owner, 8 October:** «بشأن الأعمدة، نحن لا نحتاج الأعمدة. نعتمد فقط على
// الأسطر — في حال تحديد الكل نحسب كم سطر في النص.»
//
// He cancelled the column rule 038-G item 6 after it had been measured, and
// the measurement (048) is why his sentence is the better design:
//
//   * a header-driven rule would have reached **eight values in one column of
//     one document** — the whole yield — and would have missed a table with no
//     header, a header in a language this build does not carry, and a header
//     that is not a label at all;
//   * the cell can only be identified by **order**, because the PDF reader
//     emits every gap as exactly two spaces: 429 lines of 1813 in his own bank
//     statement, widest run two. Position is a proxy for order that survives a
//     `.txt` and dies in a PDF.
//
// So: he selects the lines, clicks **one** value, and the same cell is
// protected in all of them. One click for eight account numbers, and he saw
// what he was doing. No inference, so it cannot be wrong about what a column
// means — and it reaches every table a header list never could.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a column";

/// A ledger in the shape the owner's own sheet uses: a header, then rows whose
/// cells are separated by two or more spaces. The amounts repeat on purpose —
/// two rows pay 28 400 — because a value that appears twice is what broke the
/// old column rule's spans (048 item 4).
const LEDGER: &str = "\
date               name                 account no.    amount\n\
25 February 2027   Hedvig Palmgren      9999 000 01    42 500\n\
25 February 2027   Tobias Nyqvist       9999 000 02    34 800\n\
25 February 2027   Amina Saleh          9999 000 03    31 200\n\
25 February 2027   Jonatan Ferm         9999 000 04    28 400\n\
25 February 2027   Linnea Bohlin        9999 000 05    28 400\n\
25 February 2027   Rasmus Kallio        9999 000 06    27 900\n\
25 February 2027   Nadia Berglind       9999 000 07    26 500\n\
25 February 2027   Oskar Hedström       9999 000 08    26 500\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-example-{name}-{}", std::process::id()));
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

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

fn protected(session: SessionId, doc: &str) -> Vec<String> {
    let mut out: Vec<String> = document_view(session)
        .expect("view")
        .marks
        .iter()
        .filter(|m| m.state == MarkState::Protected)
        .map(|m| {
            doc.chars()
                .skip(m.span.start as usize)
                .take((m.span.end - m.span.start) as usize)
                .collect::<String>()
        })
        .collect();
    out.sort();
    out
}

fn leaves(session: SessionId) -> String {
    payload_view(build_payload(session).expect("payload")).expect("view").text
}

// ------------------------------------------------------------ 1 · one click

/// **The acceptance, and its real subject is the last clause.**
///
/// Eight selected lines, a click on one account number, all eight protected —
/// each with its own token — **and the amounts in the same rows still in the
/// clear and still readable by a model.** That last part is what 046/M was
/// about: a demo whose point is that the model does arithmetic on amounts
/// while seeing no names.
#[test]
fn one_click_protects_the_cell_in_every_selected_line() {
    let _g = serial();
    fresh_vault("one-click");
    let s = scanned(LEDGER, "en");

    // Lines 1..8 are the rows; line 0 is the header.
    let outcome = protect_cell_in_lines(
        s,
        span_of(LEDGER, "9999 000 01"),
        1,
        8,
        Scope::Conversation,
        Kind::Account,
    )
    .expect("the cell in every line");
    match outcome {
        ProtectOutcome::Applied { places, .. } => assert_eq!(
            places, 8,
            "one click reached {places} of the eight account numbers"
        ),
        other => panic!("expected it to apply, got {other:?}"),
    }

    let marks = protected(s, LEDGER);
    for n in 1..=8 {
        let want = format!("9999 000 0{n}");
        assert!(marks.contains(&want), "«{want}» was not reached: {marks:?}");
    }

    // **And the amounts are still there**, in the text that leaves.
    let out = leaves(s);
    for amount in ["42 500", "34 800", "31 200", "28 400", "27 900", "26 500"] {
        assert!(out.contains(amount), "«{amount}» was swallowed: {out:?}");
    }
    // As are the dates, and the header itself.
    assert!(out.contains("25 February 2027"), "{out:?}");
    assert!(out.contains("account no."), "{out:?}");
    close_session(s).ok();
}

/// **Each value its own token**, never the line as one.
///
/// A line taken whole would destroy the row and take the amounts with it —
/// 046/M's defect arriving by another door — and eight values sharing one
/// token would tell the model that eight different accounts are the same
/// account.
#[test]
fn eight_values_are_eight_tokens() {
    let _g = serial();
    fresh_vault("tokens");
    let s = scanned(LEDGER, "en");
    protect_cell_in_lines(
        s,
        span_of(LEDGER, "9999 000 01"),
        1,
        8,
        Scope::Conversation,
        Kind::Account,
    )
    .expect("act");
    let out = leaves(s);
    let mut tokens: Vec<&str> = out
        .split_whitespace()
        .filter(|w| w.starts_with("__Z_"))
        .collect();
    tokens.sort();
    tokens.dedup();
    assert_eq!(tokens.len(), 8, "eight accounts became {} token(s): {out:?}", tokens.len());
    close_session(s).ok();
}

/// **A repeated value marks its own cell**, which is the defect 048 found in
/// the old column rule: it located a cell by searching the row for the value's
/// text, so two rows paying «28 400» would have marked the wrong one.
///
/// Here the amount column is the one clicked, and each of the two rows paying
/// the same amount must carry its own mark.
#[test]
fn a_repeated_value_marks_each_of_its_own_rows() {
    let _g = serial();
    fresh_vault("repeat");
    let s = scanned(LEDGER, "en");
    protect_cell_in_lines(
        s,
        span_of(LEDGER, "42 500"),
        1,
        8,
        Scope::Conversation,
        Kind::Account,
    )
    .expect("act");
    let marks = protected(s, LEDGER);
    assert_eq!(
        marks.iter().filter(|m| *m == "28 400").count(),
        2,
        "the two rows paying the same amount did not each get a mark: {marks:?}"
    );
    assert_eq!(
        marks.iter().filter(|m| *m == "26 500").count(),
        2,
        "nor did the other pair: {marks:?}"
    );
    close_session(s).ok();
}

// ------------------------------------------------------- 2 · what it reaches

/// **A table with no header at all**, which a header-driven rule could never
/// have reached. This is 048's own list of four, answered.
#[test]
fn a_table_with_no_header_is_reached() {
    let _g = serial();
    fresh_vault("headless");
    const BARE: &str = "\
Hedvig Palmgren      9999 000 01    42 500\n\
Tobias Nyqvist       9999 000 02    34 800\n\
Amina Saleh          9999 000 03    31 200\n";
    let s = scanned(BARE, "en");
    let outcome = protect_cell_in_lines(
        s,
        span_of(BARE, "9999 000 01"),
        0,
        2,
        Scope::Conversation,
        Kind::Account,
    )
    .expect("act");
    assert!(matches!(outcome, ProtectOutcome::Applied { places: 3, .. }), "{outcome:?}");
    close_session(s).ok();
}

/// And a heading in a language this build does not carry, which is the other
/// half of the same argument.
#[test]
fn a_heading_in_a_language_we_do_not_have_is_reached() {
    let _g = serial();
    fresh_vault("other-tongue");
    const OTHER: &str = "\
tarih              isim                 hesap no       tutar\n\
25 Şubat 2027      Hedvig Palmgren      9999 000 01    42 500\n\
25 Şubat 2027      Tobias Nyqvist       9999 000 02    34 800\n";
    let s = scanned(OTHER, "en");
    let outcome = protect_cell_in_lines(
        s,
        span_of(OTHER, "9999 000 01"),
        1,
        2,
        Scope::Conversation,
        Kind::Account,
    )
    .expect("act");
    assert!(matches!(outcome, ProtectOutcome::Applied { places: 2, .. }), "{outcome:?}");
    close_session(s).ok();
}

// -------------------------------------------------------- 3 · the two counts

/// **The count is said out loud**, and with it the two numbers that decide
/// what an act over those lines is worth.
#[test]
fn a_selection_says_how_many_lines_and_what_is_in_them() {
    let _g = serial();
    fresh_vault("counts");
    let s = scanned(LEDGER, "en");
    let all = line_selection(s, 0, 8).expect("selection");
    assert_eq!(all.lines, 9, "the header and its eight rows are nine lines");

    let rows = line_selection(s, 1, 8).expect("selection");
    assert_eq!(rows.lines, 8);
    // Nothing in this ledger is protected before anything is done to it: the
    // control for the number below.
    assert_eq!(rows.protected, 0, "{rows:?}");

    protect_cell_in_lines(
        s,
        span_of(LEDGER, "9999 000 01"),
        1,
        8,
        Scope::Conversation,
        Kind::Account,
    )
    .expect("act");
    let after = line_selection(s, 1, 8).expect("selection");
    assert_eq!(after.protected, 8, "the count did not follow the act: {after:?}");
    assert_eq!(after.lines, 8);

    // And the order of the two line numbers does not matter: a person may drag
    // upwards.
    assert_eq!(line_selection(s, 8, 1).expect("backwards").lines, 8);
    close_session(s).ok();
}

/// A line number that is not in the document is refused in words, not clamped
/// into something that happens to work.
#[test]
fn a_line_that_is_not_there_is_refused() {
    let _g = serial();
    fresh_vault("off-the-end");
    let s = scanned(LEDGER, "en");
    match line_selection(s, 0, 999) {
        Err(ApiError::BadSpan { reason }) => assert!(reason.contains("not in this document"), "{reason}"),
        other => panic!("a line past the end was accepted: {other:?}"),
    }
    close_session(s).ok();
}

/// **A click that is not in a cell is refused**, rather than guessing which
/// column was meant. A selection in the whitespace between two columns names
/// no cell, and naming one for the person would be the inference this whole
/// design exists to avoid.
#[test]
fn a_click_outside_a_cell_is_refused() {
    let _g = serial();
    fresh_vault("between");
    const TINY: &str = "a      b\nc      d\n";
    let s = scanned(TINY, "en");
    // The three spaces in the middle of the first line.
    let gap = Span { start: 2, end: 4 };
    match protect_cell_in_lines(s, gap, 0, 1, Scope::Conversation, Kind::Custom) {
        Err(ApiError::BadSpan { reason }) => assert!(reason.contains("inside a cell"), "{reason}"),
        other => panic!("a click between columns chose a column anyway: {other:?}"),
    }
    close_session(s).ok();
}

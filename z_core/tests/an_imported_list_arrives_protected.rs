// 046/F · a book of client names protects from the first document.
//
// `add_user_name` has carried «always» from the start: a name typed by hand can
// be protection or a question. `import_user_names` had no such word and wrote
// every row as a suggestion with nobody asked, so a client book read from a
// file could only ever become a pile of cards.
//
// Measured on the owner's own payroll sheet, in his own company's name:
//
// ```text
//                               findings   auto   asked   person questions
// the sheet, cold                     35     31       4                  2
// after importing his 21 names         51     31      20                 18
// the same import, as a book           51     50       1                  0
// ```
//
// **Those 18 becoming 0 is the whole of F** — and the one question left is the
// company's own street address, which is in no list.
//
// The reach is the app's own `Scope`, not a flag of this function's own, so the
// review screen the owner has settled on can hand it through unchanged (the
// lead, 7 Oct). What the four values mean for a book is in `book_reach`, and
// the two that are about a place in a document are refused rather than guessed
// at.
//
// **What this file holds in every direction**, because a reach that could only
// ever grow would not be a question worth asking a person: the book protects at
// `Profile` and at `Always`, it only offers with no scope at all, `Profile`
// reaches one client and not the next, and a short name in a book still takes
// only itself.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för en lista";

/// Two rows, the two kinds that become a value in the vault.
const LIST: &str = "name,type\nHedvig Palmgren,person\nFaruk AB,company\n";

/// A line from a payroll sheet, holding both of them.
const DOC: &str = "Lönekörning: Hedvig Palmgren arbetar hos Faruk AB.\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-book-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// A client, made from a Swedish session so its language is Swedish (046/A).
fn client(name: &str) -> String {
    let s = open_session(None, "sv".to_string()).expect("open");
    let p = create_profile(name.to_string(), Some(s)).expect("profile");
    close_session(s).ok();
    p
}

fn scanned(profile: Option<&str>, doc: &str) -> SessionId {
    let s = open_session(profile.map(str::to_string), "sv".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    s
}

/// What this document carries, in the state it carries it in.
fn marks(session: SessionId, doc: &str, state: MarkState) -> Vec<String> {
    let mut out: Vec<String> = document_view(session)
        .expect("view")
        .marks
        .iter()
        .filter(|m| m.state == state)
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

fn refusal(result: ApiResult<NameImport>) -> String {
    match result {
        Err(ApiError::InputRefused { reason }) => reason,
        other => panic!("expected a refusal in words, got {other:?}"),
    }
}

// ---------------------------------------------------------------- 1 · the film

/// **The acceptance: imported as this client's book, found protected.**
#[test]
fn a_book_protects_from_the_first_document() {
    let _g = serial();
    fresh_vault("profile");
    let p = client("Faruk AB");
    let report = import_user_names(
        LIST.to_string(),
        Some(p.clone()),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");
    assert_eq!((report.added, report.refused), (2, 0), "{report:?}");

    let s = scanned(Some(&p), DOC);
    assert_eq!(
        marks(s, DOC, MarkState::Protected),
        vec!["Faruk AB".to_string(), "Hedvig Palmgren".to_string()],
        "the book did not protect from the first document"
    );
    assert!(
        marks(s, DOC, MarkState::Suggested).is_empty(),
        "something was still asked about after «protect these»"
    );
    close_session(s).ok();
}

/// **And the sentence the product is sold on: this client's, not every
/// client's.**
///
/// The same book, the same document, a different client — and nothing is
/// protected. «What you learn about one of them does not become a rule about
/// all of them» is a claim, and this is the measurement under it.
#[test]
fn a_book_kept_for_one_client_reaches_no_other() {
    let _g = serial();
    fresh_vault("one-client");
    let mine = client("Faruk AB");
    let other = client("Nordstern Consulting");
    import_user_names(
        LIST.to_string(),
        Some(mine.clone()),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");

    let s = scanned(Some(&other), DOC);
    assert!(
        marks(s, DOC, MarkState::Protected).is_empty(),
        "one client's book protected another client's document: {:?}",
        marks(s, DOC, MarkState::Protected)
    );
    close_session(s).ok();
    // The control, or the test above proves only that nothing works: the same
    // document inside the book's own client is protected.
    let own = scanned(Some(&mine), DOC);
    assert_eq!(marks(own, DOC, MarkState::Protected).len(), 2);
    close_session(own).ok();
}

/// «Everywhere» is the other answer, and it is kept with no client at all —
/// so it reaches a client who did not exist when the book was read.
#[test]
fn a_book_kept_everywhere_reaches_a_client_made_afterwards() {
    let _g = serial();
    fresh_vault("everywhere");
    import_user_names(LIST.to_string(), None, "sv".to_string(), Some(Scope::Always))
        .expect("import");
    let later = client("A Client Who Did Not Exist Yet");
    let s = scanned(Some(&later), DOC);
    assert_eq!(marks(s, DOC, MarkState::Protected).len(), 2);
    close_session(s).ok();
}

/// **The other direction, which is what makes the reach a question.**
///
/// No scope at all is «offer them and I decide»: the names are knowledge and
/// nothing more. Without this test the reach would be proved in one direction
/// only, and an answer that cannot be «no» is not a question.
#[test]
fn a_book_with_no_scope_is_only_offered() {
    let _g = serial();
    fresh_vault("offer");
    let p = client("Faruk AB");
    import_user_names(LIST.to_string(), Some(p.clone()), "sv".to_string(), None)
        .expect("import");

    let s = scanned(Some(&p), DOC);
    assert!(
        marks(s, DOC, MarkState::Protected).is_empty(),
        "«offer them» protected without being asked: {:?}",
        marks(s, DOC, MarkState::Protected)
    );
    let offered = marks(s, DOC, MarkState::Suggested);
    assert!(
        offered.iter().any(|o| o == "Hedvig Palmgren") && offered.iter().any(|o| o == "Faruk AB"),
        "the book was not even offered: {offered:?}"
    );
    close_session(s).ok();
}

/// A word row — `given` or `family` — gets its «always» twin, exactly as the
/// hand-typed path does: the dictionary learns the word so the rules can read
/// a whole name around it, **and** the vault learns the value so the word is
/// protected on sight.
#[test]
fn a_word_row_in_a_book_gets_its_twin() {
    let _g = serial();
    fresh_vault("twin");
    let p = client("Faruk AB");
    let report = import_user_names(
        "name,type\nPalmgren,family\n".to_string(),
        Some(p.clone()),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");
    assert_eq!(report.added, 1, "{report:?}");

    // The row the person sees says «always», because both halves are there.
    let rows = user_names(Some(p.clone())).expect("rows");
    assert!(
        rows.iter().any(|r| r.text == "Palmgren" && r.always),
        "the word was learned without its «always» twin: {rows:?}"
    );

    const WORD: &str = "Enligt Palmgren är siffrorna klara.\n";
    let s = scanned(Some(&p), WORD);
    assert_eq!(marks(s, WORD, MarkState::Protected), vec!["Palmgren".to_string()]);
    close_session(s).ok();
}

// ---------------------------------------------------------------- 2 · refusals

/// **A scope nobody can honour refuses the whole file, in words.**
///
/// «This one place» and «this conversation» are answers about a document, and
/// a list of names has no places in it. Guessing one of them — writing the
/// book as a suggestion and saying nothing — is the shape of defect this task
/// exists to remove, so the refusal comes **before** the file is read and the
/// vault is left exactly as it was.
#[test]
fn a_scope_about_a_place_is_refused_and_nothing_is_written() {
    let _g = serial();
    fresh_vault("place");
    let p = client("Faruk AB");
    for scope in [Scope::Once, Scope::Conversation] {
        let said = refusal(import_user_names(
            LIST.to_string(),
            Some(p.clone()),
            "sv".to_string(),
            Some(scope),
        ));
        assert!(
            said.contains("no places in it"),
            "the refusal does not say why «{scope:?}» cannot answer for a list: {said}"
        );
    }
    assert!(
        user_names(Some(p)).expect("rows").is_empty(),
        "a refused file wrote something anyway"
    );
}

/// «This client» with no client open is refused, and the sentence names both
/// ways out. The same shape `protect` has had since task 034 — and, after
/// 046/D, with no run of spaces in it.
#[test]
fn this_client_with_no_client_is_refused_in_a_sentence() {
    let _g = serial();
    fresh_vault("no-client");
    let said = refusal(import_user_names(
        LIST.to_string(),
        None,
        "sv".to_string(),
        Some(Scope::Profile),
    ));
    assert!(said.contains("open a client first"), "{said}");
    assert!(said.contains("everywhere"), "the other way out is not named: {said}");
    assert!(!said.contains("  "), "the refusal carries a run of spaces: {said:?}");
}

// ---------------------------------------------------------------- 3 · the cost

/// **What a short name in a book must not blacken.**
///
/// A one-word value from a book is a value like any other, and a staff list
/// has short Swedish names in it. «Vik» may not take «Viken», and it may not
/// take the «Vik» inside «Vikingaskeppet». The Swedish surname endings make it
/// sharper: «Berg» is a name **and** the tail of «Bergström», so twenty staff
/// names would otherwise blacken half a page of ordinary Swedish.
///
/// A minimum length for a value in a book is 047's, and this is the number it
/// will start from: with the word boundary alone, these two cost nothing.
#[test]
fn a_short_name_in_a_book_takes_only_itself() {
    let _g = serial();
    fresh_vault("short");
    let p = client("Faruk AB");
    import_user_names(
        "name,type\nVik,person\nBerg,person\n".to_string(),
        Some(p.clone()),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");

    const SHORT: &str = "Vik ligger vid Viken, och Vikingaskeppet stod i Bergström.\nBerg kom.\n";
    let s = scanned(Some(&p), SHORT);
    assert_eq!(
        marks(s, SHORT, MarkState::Protected),
        vec!["Berg".to_string(), "Vik".to_string()],
        "a short name from a book took a word that merely contains it"
    );
    close_session(s).ok();
}

/// The count-back sentence still says three numbers, and a refused row is
/// still refused by its line — the reach changes what a row becomes, never
/// whether the file is read.
#[test]
fn the_count_back_sentence_is_unchanged() {
    let _g = serial();
    fresh_vault("count");
    let p = client("Faruk AB");
    let report = import_user_names(
        "name,type\nHedvig Palmgren,person\nStockholm,city\n,person\n".to_string(),
        Some(p),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");
    assert_eq!((report.added, report.refused), (1, 2), "{report:?}");
    assert_eq!(report.reasons.len(), 2, "{report:?}");
    assert!(
        report.reasons.iter().any(|r| r.contains("line 3")),
        "a refused row no longer names its line: {report:?}"
    );
}

// ---------------------------------------------------------------- 4 · the line

/// **What this change does not do, pinned so it is a decision.**
///
/// A name the book already holds is counted `already_known` and keeps the
/// reach it has, even when the file is imported again at a wider one. The
/// scope decides what a row **becomes**, not what an existing record is
/// changed into — raising a value's reach is the act the vault screen owns,
/// and doing it silently from a file would overwrite a decision the person
/// made by hand.
///
/// The number that matters: importing the same book twice, the second time as
/// «this client», leaves its names unprotected, and the sentence a person
/// reads says «already known» — which is true of the name and not of its
/// reach. If that is the wrong line, this test is where it moves.
#[test]
fn an_already_known_name_keeps_the_reach_it_had() {
    let _g = serial();
    fresh_vault("already");
    let p = client("Faruk AB");
    import_user_names(LIST.to_string(), Some(p.clone()), "sv".to_string(), None).expect("first");
    let second = import_user_names(
        LIST.to_string(),
        Some(p.clone()),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("second");
    assert_eq!(
        (second.added, second.already_known),
        (0, 2),
        "the second import did not recognise the names: {second:?}"
    );

    let s = scanned(Some(&p), DOC);
    assert!(
        marks(s, DOC, MarkState::Protected).is_empty(),
        "a second import raised the reach of names already in the book — if that is \
         now wanted, this test is the place the line moves: {:?}",
        marks(s, DOC, MarkState::Protected)
    );
    close_session(s).ok();
}

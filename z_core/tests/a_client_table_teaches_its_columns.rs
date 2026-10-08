// 056 · A client table teaches only its names, and says nothing about the rest.
//
// `import_user_names` reads the header and takes `name` and `type` (both
// required) and `source`/`licence` if present. **Every other column is
// ignored, and the report does not mention it.**
//
// The lead measured it on 82d5858 with a client table of
// `name,type,kundnummer,avtal` against a receivables page:
//
// ```text
//                              the client's own numbers leaving in the clear
//   before the import                                              3 of 3
//   import → Ok(added: 2, refused: 0)
//   after the import                                               3 of 3
// ```
//
// **Nothing changed, and the report said everything succeeded.** The name is
// the easy half — shapes and packs often find a person anyway. The hard half is
// exactly what the table drops: a customer number, a contract id, an internal
// account, which no shape rule knows and no pack will ever learn.
//
// This is 054's defect in a second place. One rule covers both: **nothing is
// discarded quietly.**
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för en kundbok";

/// A client book as a real one is shaped: one row per client, and the columns
/// that matter — the customer number and the contract.
const TABLE: &str = "name,type,kundnummer,avtal\n\
                     Hedvig Palmgren,person,448217,AVT-2026-118\n\
                     Faruk AB,company,449073,AVT-2026-204\n";

/// A receivables page: **three of the client's own numbers and not one name.**
/// This is the document the table exists for, and the one it does nothing about.
const PAGE: &str = "Kundfordringar per 2026-09-30\n\
                    Kundnr 448217   Avtal AVT-2026-118   12 400,00 SEK   förfallen\n\
                    Kundnr 449073                         3 150,00 SEK   ej förfallen\n\
                    Summa utestående 15 550,00 SEK\n";

/// The three numbers on that page, which belong to his clients.
const NUMBERS: &[&str] = &["448217", "AVT-2026-118", "449073"];

/// Left in the clear on purpose. Without it a silent payload would prove
/// nothing but that the search is broken.
const CONTROL: &str = "Summa utestående";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-table-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

fn client(name: &str) -> String {
    let s = open_session(None, "sv".to_string()).expect("open");
    let p = create_profile(name.to_string(), Some(s)).expect("profile");
    close_session(s).ok();
    p
}

/// **What actually leaves.** Not what is marked — what a provider would read.
fn what_leaves(profile: Option<&str>, doc: &str) -> String {
    let s = open_session(profile.map(str::to_string), "sv".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let text = payload_view(build_payload(s).expect("build")).expect("view").text;
    close_session(s).ok();
    text
}

/// How many of the three are still readable.
fn in_the_clear(text: &str) -> Vec<String> {
    assert!(
        text.contains(CONTROL),
        "the control string «{CONTROL}» is missing, so this count cannot be trusted:\n{text}"
    );
    NUMBERS.iter().filter(|n| text.contains(**n)).map(|n| (*n).to_string()).collect()
}

// ------------------------------------------------- 1 · the guard that must bite

/// **The lead's guard: after the table, the page comes out with 0 of 3.**
///
/// Red on 82d5858 — the two name cells were learned and the four number cells
/// were dropped without a word, so this page left exactly as it arrived.
#[test]
fn the_receivables_page_keeps_no_number_in_the_clear() {
    let _g = serial();
    fresh_vault("receivables");
    let p = client("Faruk AB");

    // Before: the baseline this fix has to move.
    let before = in_the_clear(&what_leaves(Some(&p), PAGE));
    assert_eq!(
        before.len(),
        3,
        "the baseline is not 3 of 3 — a shape rule already finds one of these, \
         so this fixture cannot measure what a table teaches: {before:?}"
    );

    let report = import_user_names(
        TABLE.to_string(),
        Some(p.clone()),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");
    assert_eq!(report.refused, 0, "{report:?}");

    let after = in_the_clear(&what_leaves(Some(&p), PAGE));
    assert!(
        after.is_empty(),
        "the table was imported and {} of 3 of his clients' numbers still left in the clear: {after:?}",
        after.len()
    );
}

// ------------------------------------------------- 2 · nothing is discarded quietly

/// **A column nobody can place is named, not dropped.**
///
/// The report carries the header words this build could not name a kind for, so
/// a person can see the difference between «imported» and «imported the names».
/// Red on 82d5858: the report had nowhere to say it.
#[test]
fn a_column_that_names_no_kind_is_said_out_loud() {
    let _g = serial();
    fresh_vault("unused");
    let p = client("Faruk AB");
    let report = import_user_names(
        "name,type,Kundnummer,Handläggare,Rabattkod\n\
         Hedvig Palmgren,person,448217,Erik,A7\n"
            .to_string(),
        Some(p),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");

    // **In his own spelling**, and a header is matched without case: this
    // file writes its columns capitalised, as a spreadsheet does.
    assert_eq!(report.columns_not_used, vec!["Handläggare", "Rabattkod"], "{report:?}");
    assert_eq!(
        (report.added, report.values),
        (1, 1),
        "the one column this build can place is the one it counted: {report:?}"
    );
    assert_eq!(report.refused, 0, "a column it cannot place is not a refused row: {report:?}");
}

/// **A row whose number cell is empty is not a refusal.** A client without a
/// contract is still a client, and a table with a gap in it is an ordinary
/// table.
#[test]
fn a_client_without_a_contract_is_still_a_client() {
    let _g = serial();
    fresh_vault("gap");
    let p = client("Faruk AB");
    let report = import_user_names(
        "name,type,kundnummer,avtal\n\
         Hedvig Palmgren,person,448217,\n\
         Faruk AB,company,,AVT-2026-204\n"
            .to_string(),
        Some(p),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");
    assert_eq!(
        (report.added, report.values, report.refused),
        (2, 2, 0),
        "a gap in the table was counted as something: {report:?}"
    );
}

/// **The list says what it holds, and says the two things apart.**
///
/// «21 names» and «2 names and 4 numbers» are different answers to «what did
/// that file teach me?». A count that mixed them would be the same untruth in
/// a smaller place.
#[test]
fn the_list_counts_the_numbers_apart_from_the_names() {
    let _g = serial();
    fresh_vault("counts");
    let p = client("Faruk AB");
    import_user_names(
        TABLE.to_string(),
        Some(p),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");

    let lists = user_lists().expect("lists");
    assert_eq!(lists.len(), 1, "{lists:?}");
    assert_eq!((lists[0].names, lists[0].values), (2, 4), "{lists:?}");
}

/// **And the panel does not call a customer number a person.**
///
/// A new defect of this very change: the names panel reads every value in the
/// book a person wrote, and before the table there was nothing in it but
/// people and companies. A number listed as a person would be the panel lying
/// about the vault — which is the shape 046/G was paid for.
#[test]
fn the_names_panel_lists_names_and_not_numbers() {
    let _g = serial();
    fresh_vault("panel");
    let p = client("Faruk AB");
    import_user_names(
        TABLE.to_string(),
        Some(p.clone()),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("import");

    let rows = user_names(Some(p)).expect("names");
    let shown: Vec<String> = rows.iter().map(|r| r.text.clone()).collect();
    assert!(
        shown.contains(&"Hedvig Palmgren".to_string()) && shown.contains(&"Faruk AB".to_string()),
        "the panel lost the names it did import: {shown:?}"
    );
    for number in NUMBERS {
        assert!(
            !shown.contains(&(*number).to_string()),
            "«{number}» is a customer number and the names panel calls it a name: {shown:?}"
        );
    }
}

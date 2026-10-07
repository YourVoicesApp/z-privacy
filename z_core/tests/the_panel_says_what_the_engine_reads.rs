// 046/G · the list on screen is the list the scanner reads.
//
// Found while delivering 046/F and measured before it was touched. The owner's
// own 21-name book, imported into his own client:
//
// ```text
// added 21 · already 0 · refused 0
// rows the panel would draw = 0 of 21
// ```
//
// Two separate halves, and both are the same shape of defect — **the screen
// claiming less than the engine does**, which is the family this project has
// paid for more than once:
//
//   1. `user_names(Some(client))` returned the client's rows alone, while the
//      scan reads the client's vault **and** the global one. So a book
//      imported «everywhere» with a client open protected correctly and
//      appeared nowhere.
//   2. A whole person or company is a value and belongs to no dictionary list,
//      and the panel drew only rows that fell under a list head. So a book of
//      whole names was invisible **in its own client too** — the half that
//      stood on the film's own path.
//
// This file holds the first half, which is the core's. The second is the
// panel's, and `your_own_names_test.dart` holds it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för panelen";
const BOOK: &str = "name,type\nHedvig Palmgren,person\nFaruk AB,company\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-panel-{name}-{}", std::process::id()));
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

/// **A book kept everywhere is on the screen while a client is open.**
///
/// The acceptance, and the number that was 0: the scan protects these two
/// inside the client, so the list a person reads has to hold them.
#[test]
fn an_everywhere_book_is_visible_inside_a_client() {
    let _g = serial();
    fresh_vault("everywhere");
    import_user_names(BOOK.to_string(), None, "sv".to_string(), Some(Scope::Always))
        .expect("import");
    let p = client("Faruk AB");

    let rows = user_names(Some(p)).expect("rows");
    assert_eq!(
        rows.len(),
        2,
        "the client's panel shows {} of the 2 names the scanner reads: {rows:?}",
        rows.len()
    );
    // And each row says which of the two vaults it is in, so «Forget» is not a
    // press into the dark: a global row forgotten is forgotten for every
    // client, and the screen can only say so if the fact is here.
    assert!(
        rows.iter().all(|r| r.profile_id.is_none()),
        "a global row does not say it is global: {rows:?}"
    );
}

/// The client's own rows and the global ones in one list, each still naming
/// its own vault — because they are two different promises and a person acting
/// on one of them must be able to see which.
#[test]
fn the_two_vaults_are_one_list_and_still_two_facts() {
    let _g = serial();
    fresh_vault("both");
    let p = client("Faruk AB");
    import_user_names(
        "name,type\nHedvig Palmgren,person\n".to_string(),
        Some(p.clone()),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("the client's");
    import_user_names(
        "name,type\nFaruk AB,company\n".to_string(),
        None,
        "sv".to_string(),
        Some(Scope::Always),
    )
    .expect("everywhere");

    let rows = user_names(Some(p.clone())).expect("rows");
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert_eq!(
        rows.iter().filter(|r| r.profile_id == Some(p.clone())).count(),
        1,
        "the client's own row is not named as the client's: {rows:?}"
    );
    assert_eq!(
        rows.iter().filter(|r| r.profile_id.is_none()).count(),
        1,
        "the global row is not named as global: {rows:?}"
    );
}

/// **And the other client still sees only what reaches it.**
///
/// The control, without which the test above would be satisfied by a list that
/// simply shows everything: one client's own book must not appear in another
/// client's panel, because it does not protect there either.
#[test]
fn another_client_sees_the_global_rows_and_not_the_first_clients() {
    let _g = serial();
    fresh_vault("other");
    let mine = client("Faruk AB");
    let other = client("Nordstern Consulting");
    import_user_names(
        "name,type\nHedvig Palmgren,person\n".to_string(),
        Some(mine),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("mine");
    import_user_names(
        "name,type\nFaruk AB,company\n".to_string(),
        None,
        "sv".to_string(),
        Some(Scope::Always),
    )
    .expect("everywhere");

    let rows = user_names(Some(other)).expect("rows");
    assert_eq!(
        rows.iter().map(|r| r.text.clone()).collect::<Vec<_>>(),
        vec!["Faruk AB".to_string()],
        "the other client's panel does not match what reaches it"
    );
}

/// **What an import means did not change with it.**
///
/// `import_user_names` asks «is this name already in the book I am writing?»,
/// and that is a narrower question than the one the panel asks. A name taught
/// everywhere is not a reason to refuse a row for one client — reading the
/// panel's wider answer would have made this fix change what an import does,
/// quietly, which is the thing it exists to stop.
#[test]
fn a_global_name_does_not_block_a_clients_own_row() {
    let _g = serial();
    fresh_vault("dedupe");
    import_user_names(
        "name,type\nHedvig Palmgren,person\n".to_string(),
        None,
        "sv".to_string(),
        Some(Scope::Always),
    )
    .expect("everywhere");
    let p = client("Faruk AB");
    let report = import_user_names(
        "name,type\nHedvig Palmgren,person\n".to_string(),
        Some(p),
        "sv".to_string(),
        Some(Scope::Profile),
    )
    .expect("the client's");
    assert_eq!(
        (report.added, report.already_known),
        (1, 0),
        "a name taught everywhere refused the same name for one client: {report:?}"
    );
}

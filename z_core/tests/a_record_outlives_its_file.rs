// 046/S · a record of what was produced, and it outlives the file.
//
// **The owner, 7 October:** «نحتاج إلى زرٍّ داخل التطبيق يعرض وثائق PDF
// المحفوظة» — a button inside the app that shows the saved PDF documents.
//
// And the lead's answer to the question he asked with it, which is what gives
// this file its shape: the file is **fingerprinted, not sealed.** The footer
// inside it states the build stamp, the counts by kind and a sha256 of the
// protected text, and every one of those a reader can check for themselves.
// What a fingerprint cannot answer is «did this app produce this, and when» —
// and that is the question a client or a regulator asks. A fingerprint proves
// the **content**; a record proves the **act**.
//
// So the list does not come from scanning a folder. A folder can be moved,
// emptied or synced away; a record is evidence. The case this file exists for
// is the **row that outlives its file**, and it is the easy one to forget.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for a documents room";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

/// A fresh vault on its own data directory, and the path it lives at.
fn fresh_vault(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-room-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    dir
}

fn a_record(path: &str) -> u32 {
    record_produced_document(
        "Lohnabrechnung_Weber.txt".to_string(),
        12,
        vec![
            KindCount { kind: Kind::Person, count: 3 },
            KindCount { kind: Kind::Account, count: 8 },
        ],
        "f".repeat(64),
        path.to_string(),
    )
    .expect("the record")
}

/// **The case the design exists for.** The file is written, the record is
/// written, and then the file is gone — moved to a USB stick, swept up by a
/// sync, deleted by somebody tidying a Downloads folder. The record stays,
/// with the path it was last known at, because «this document was produced on
/// 7 October and the file is no longer there» is an answer and a missing row
/// is not.
#[test]
fn the_row_outlives_its_file() {
    let _g = serial();
    let dir = fresh_vault("outlives");
    let file = dir.join("Weber-protected-2026-10-07.pdf");
    std::fs::write(&file, b"%PDF-1.4 not really").expect("write");
    let id = a_record(&file.to_string_lossy());

    std::fs::remove_file(&file).expect("remove");
    assert!(!file.exists(), "the file is still on disk, so this proves nothing");

    let rows = produced_documents().expect("the list");
    let row = rows.iter().find(|r| r.id == id).expect("the row went with the file");
    assert_eq!(row.path, file.to_string_lossy(), "the path it was last known at is gone");
    assert_eq!(row.places, 12);
    assert_eq!(row.from_document, "Lohnabrechnung_Weber.txt");
    assert_eq!(row.sha256.len(), 64);
    // Whether the file is there is a question about a disk, and this crate
    // writes to no disk but the vault's own (G15). The screen answers it.
    vault_lock().ok();
}

/// It survives the vault being closed and opened, because that is what «a
/// record» means. A list held in memory would have answered the first test.
#[test]
fn the_row_survives_a_lock_and_an_unlock() {
    let _g = serial();
    fresh_vault("survives");
    let id = a_record("/tmp/zprivacy-gone/Weber.pdf");
    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");

    let rows = produced_documents().expect("the list");
    let row = rows.iter().find(|r| r.id == id).expect("the row did not survive the lock");
    assert_eq!(row.places, 12);
    let by_kind: Vec<(Kind, u32)> = row.by_kind.iter().map(|k| (k.kind, k.count)).collect();
    assert!(by_kind.contains(&(Kind::Person, 3)), "{by_kind:?}");
    assert!(by_kind.contains(&(Kind::Account, 8)), "{by_kind:?}");
    vault_lock().ok();
}

/// **A locked vault means no list** — the same rule as everything else in
/// there. The rows name a document and a path, which is as much a person's
/// business as the names inside it.
#[test]
fn a_locked_vault_lists_nothing() {
    let _g = serial();
    fresh_vault("locked");
    a_record("/tmp/zprivacy-gone/Weber.pdf");
    vault_lock().expect("lock");
    match produced_documents() {
        Err(ApiError::VaultLocked) => {}
        other => panic!("a locked vault answered: {other:?}"),
    }
    match record_produced_document("x".to_string(), 1, vec![], "a".repeat(64), "/tmp/x.pdf".to_string()) {
        Err(ApiError::VaultLocked | ApiError::VaultRequired) => {}
        other => panic!("a locked vault was written to: {other:?}"),
    }
}

/// **Newest first**, because a person looking for what they just made is
/// looking at the top of the list.
#[test]
fn the_newest_is_first() {
    let _g = serial();
    fresh_vault("order");
    let first = a_record("/tmp/one.pdf");
    let second = a_record("/tmp/two.pdf");
    let rows = produced_documents().expect("the list");
    assert_eq!(rows.first().map(|r| r.id), Some(second), "the newest is not first");
    assert_eq!(rows.get(1).map(|r| r.id), Some(first));
    vault_lock().ok();
}

/// **A serial can be added later without a migration** (044).
///
/// The field is written from this model's first version and is empty today, so
/// the day a document gets a serial the bytes already have a place for it. A
/// field added to a record afterwards is a model version and a migration; a
/// field written empty costs five bytes.
#[test]
fn there_is_a_place_for_a_serial_already() {
    let _g = serial();
    fresh_vault("serial");
    let id = a_record("/tmp/serial.pdf");
    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    let rows = produced_documents().expect("the list");
    let row = rows.iter().find(|r| r.id == id).expect("the row");
    assert_eq!(row.serial, "", "a serial is 044's, and this build invents none");
    vault_lock().ok();
}

/// A record needs a path and a digest to be evidence of anything.
#[test]
fn a_record_with_nothing_in_it_is_refused() {
    let _g = serial();
    fresh_vault("refused");
    match record_produced_document("x".to_string(), 1, vec![], "a".repeat(64), "  ".to_string()) {
        Err(ApiError::InputRefused { reason }) => assert!(reason.contains("path"), "{reason}"),
        other => panic!("a record with no path was kept: {other:?}"),
    }
    match record_produced_document("x".to_string(), 1, vec![], String::new(), "/tmp/x.pdf".to_string()) {
        Err(ApiError::InputRefused { reason }) => assert!(reason.contains("sha256"), "{reason}"),
        other => panic!("a record with no digest was kept: {other:?}"),
    }
    vault_lock().ok();
}

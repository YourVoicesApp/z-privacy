// 041-Q · A language with no rules of its own is still a language.
//
// The owner, 6 October, on a build whose vault already held an Arabic list:
// he could not choose Arabic. «The language list holds every language; we have
// no problem with the language rules — we will not include them all.»
//
// So the list and the rules stopped being the same question. Measured on AR-1,
// the invented Arabic letter:
//
//     pack        before        after
//     de          5 auto · 2    5 auto · 2
//     ar          4 auto · 2    5 auto · 2     ← and it can be chosen at all
//
// The one that was missing under a bare language was a **BIC**, found only
// because the German rule set happens to carry the row `de-11 bic`. `BIC`,
// `SWIFT` and `IBAN` are ISO abbreviations and belong to no language, so they
// moved to `sets/world.rs` and run whatever language is chosen. German is
// unchanged: two layers finding the same thing settle into one finding.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const AR1: &str = include_str!("fixtures/Risala_Alharbi.txt");
const PASS: &str = "كلمة سر طويلة بما يكفي للخزنة";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

fn fresh(tag: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-language-choice-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
}

fn scan_under(pack: &str, text: &str) -> (u32, u32) {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, text.to_string()).expect("import");
    let report = scan(session).expect("scan");
    let out = (report.auto, report.suggested);
    let _ = close_session(session);
    out
}

/// The owner's own case: Arabic reads the Arabic letter as well as German did.
#[test]
fn a_language_with_no_pack_reads_as_well_as_one_with() {
    let _guard = serial();
    fresh("arabic");
    assert_eq!(scan_under("de", AR1), (5, 2), "the German baseline moved");
    assert_eq!(
        scan_under("ar", AR1),
        (5, 2),
        "a bare Arabic session finds less than German on an Arabic letter"
    );
}

/// And it can be chosen — which is the whole defect.
#[test]
fn a_session_can_be_switched_to_a_language_with_no_pack() {
    let _guard = serial();
    fresh("switch");
    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, AR1.to_string()).expect("import");
    switch_pack(session, "ar".to_string()).expect("Arabic was refused");
    switch_pack(session, "ja".to_string()).expect("Japanese was refused");
    // An invented code is still refused: a list is a language, and only one
    // this build has heard of.
    assert!(
        switch_pack(session, "klingon".to_string()).is_err(),
        "a language that does not exist was accepted"
    );
    let _ = close_session(session);
}

/// The table is the one list, and it says which half of the screen a language
/// belongs on.
#[test]
fn the_table_names_every_language_in_its_own_language() {
    let _guard = serial();
    fresh("table");
    let rows = languages().expect("languages");
    assert!(rows.len() > 60, "the table holds only {} languages", rows.len());

    let find = |id: &str| rows.iter().find(|r| r.id == id).unwrap_or_else(|| panic!("no «{id}»"));
    assert_eq!(find("ar").label, "العربية", "Arabic is not named in Arabic");
    assert_eq!(find("ja").label, "日本語");
    assert_eq!(find("de").label, "Deutsch");
    assert!(find("de").has_rules, "German is said to have no rules");
    assert!(find("sv").has_rules, "Swedish is said to have no rules");
    assert!(!find("ar").has_rules, "this build is claiming Arabic rules it does not have");

    // The ones with rules come first, so the line on the screen is one split.
    let first_without = rows.iter().position(|r| !r.has_rules).expect("some have none");
    assert!(
        rows.iter().take(first_without).all(|r| r.has_rules),
        "the two halves are interleaved, and the line cannot be drawn"
    );
}

/// A name taught in an Arabic session goes into the Arabic list — 041-I/2's
/// rule, now that Arabic is a language a session can be in.
#[test]
fn a_name_taught_in_a_bare_language_goes_into_that_language_s_list() {
    let _guard = serial();
    fresh("list");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    let session = open_session(None, "ar".to_string()).expect("open");
    import_text(session, AR1.to_string()).expect("import");

    teach_name("الحربي".to_string(), true, None, Some(session)).expect("teach");

    let lists: Vec<(String, u32)> = user_lists()
        .expect("lists")
        .into_iter()
        .map(|l| (l.name, l.names))
        .collect();
    assert_eq!(lists, vec![("ar".to_string(), 1)], "the Arabic name is not in an Arabic list: {lists:?}");
    let _ = close_session(session);
}

/// And the guard that matters most: choosing another language does not leave
/// German's dictionary running.
#[test]
fn choosing_a_language_turns_the_other_dictionaries_off() {
    let _guard = serial();
    fresh("guard");
    // A German letter, read as Arabic: the general rules still find what they
    // find, and the German dictionary finds nothing because it is not running.
    let german = "Sehr geehrter Herr Thomas Müller,\nmit freundlichen Grüßen\nAnna Weber\n";
    let (auto_de, _) = scan_under("de", german);
    let (auto_ar, _) = scan_under("ar", german);
    assert!(auto_de > auto_ar, "German found {auto_de} and bare Arabic {auto_ar}: the dictionary is still on");
    assert_eq!(auto_ar, 0, "something German was found in an Arabic session: {auto_ar}");
}

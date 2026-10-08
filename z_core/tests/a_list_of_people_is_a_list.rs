// 054 · A list of people is never a list.
//
// One function, one `list` parameter, **two fates**:
//
// - a row typed `given` or `family` goes to `teach_name_into(…, list)` and the
//   list is kept — and an unknown list name is **refused out loud**;
// - a row typed `person` or `company` goes to `put_own_value(…)`, which takes
//   no list at all, so the name the person chose is **accepted and thrown away
//   in silence**.
//
// A client book is people and companies. So **the only kind of list the owner
// will ever import is the kind that never becomes a list.** Measured by the
// lead on 82d5858 with the owner's own `FarukAB_people.csv`: `added: 21`, then
// `user_lists()` → `[]`.
//
// What that costs, all of it visible to him: no row, no count, and
// `UserListRow.enabled` — «off means the scanner is not told about them» —
// unreachable for the only list he has. Import the wrong file and the way back
// is deleting twenty-one values by hand.
//
// The rule: **nothing is discarded quietly.** Its second place is 056.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för en lista";

/// His own file's shape: people and companies, which is what a client book is.
const BOOK: &str = "name,type\nHedvig Palmgren,person\nFaruk AB,company\n";

/// One given name, so the two fates can be compared inside one test.
const WORD: &str = "name,type\nHedvig,given\n";

const DOC: &str = "Lönekörning: Hedvig Palmgren arbetar hos Faruk AB. Utbetalning i oktober.\n";

const CONTROL: &str = "Utbetalning i oktober";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-list-{name}-{}", std::process::id()));
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

/// **What actually leaves**, so a switch is judged by the wire and not by a row.
fn what_leaves(profile: Option<&str>, doc: &str) -> String {
    let s = open_session(profile.map(str::to_string), "sv".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let text = payload_view(build_payload(s).expect("build")).expect("view").text;
    close_session(s).ok();
    text
}

fn in_the_clear(text: &str) -> Vec<String> {
    assert!(
        text.contains(CONTROL),
        "the control string «{CONTROL}» is missing, so this count cannot be trusted:\n{text}"
    );
    ["Hedvig Palmgren", "Faruk AB"]
        .iter()
        .filter(|n| text.contains(**n))
        .map(|n| (*n).to_string())
        .collect()
}

fn refusal(result: ApiResult<NameImport>) -> String {
    match result {
        Err(ApiError::InputRefused { reason }) => reason,
        other => panic!("expected a refusal in words, got {other:?}"),
    }
}

// ------------------------------------------------------- 1 · the list exists

/// **A person and a company join the list they were given.**
///
/// Red on 82d5858: `added: 2`, `user_lists()` → `[]`.
#[test]
fn a_person_joins_the_list_it_was_given() {
    let _g = serial();
    fresh_vault("joins");
    let p = client("Faruk AB");
    let report =
        import_user_names(BOOK.to_string(), Some(p), "sv".to_string(), Some(Scope::Profile))
            .expect("import");
    assert_eq!((report.added, report.refused), (2, 0), "{report:?}");

    let lists = user_lists().expect("lists");
    assert_eq!(
        lists.len(),
        1,
        "two names were added and the list they were given does not exist: {lists:?}"
    );
    assert_eq!(lists[0].name, "sv");
    assert_eq!(
        lists[0].names, 2,
        "the list has no count, so «how many did that file teach me?» has no answer: {lists:?}"
    );
}

// ------------------------------------------------- 2 · the same refusal, both

/// **An unknown list name is refused for a person row, in the sentence a given
/// row already gets.**
///
/// Red on 82d5858: the given row refused and the person row was accepted, so
/// the same file answered differently depending on a column.
#[test]
fn an_unknown_list_name_is_refused_on_both_paths() {
    let _g = serial();
    fresh_vault("refusal");
    let p = client("Faruk AB");

    let for_a_word = refusal(import_user_names(
        WORD.to_string(),
        Some(p.clone()),
        "svenska namn".to_string(),
        Some(Scope::Profile),
    ));
    let for_a_person = refusal(import_user_names(
        BOOK.to_string(),
        Some(p),
        "svenska namn".to_string(),
        Some(Scope::Profile),
    ));
    assert_eq!(
        for_a_word, for_a_person,
        "the same unknown list is refused for a word and accepted for a person"
    );
    assert!(
        for_a_person.contains("a list is a language"),
        "the refusal lost its sentence: «{for_a_person}»"
    );
    assert!(
        user_lists().expect("lists").is_empty(),
        "a refused file left a list behind"
    );
}

// ------------------------------------------------------- 3 · the switch bites

/// **Switch the list off and the names come back into the clear; switch it on
/// and they are protected again.**
///
/// A switch that does not change what leaves is worse than no switch — it is a
/// promise the wire does not keep. Red on 82d5858 twice over: the list did not
/// exist to be switched, and `hints_for` never asked whether it was on.
#[test]
fn the_switch_changes_what_leaves() {
    let _g = serial();
    fresh_vault("switch");
    let p = client("Faruk AB");
    import_user_names(BOOK.to_string(), Some(p.clone()), "sv".to_string(), Some(Scope::Profile))
        .expect("import");

    assert!(
        in_the_clear(&what_leaves(Some(&p), DOC)).is_empty(),
        "the book did not protect, so the switch below would prove nothing"
    );

    set_user_list_enabled("sv".to_string(), false).expect("off");
    assert_eq!(
        in_the_clear(&what_leaves(Some(&p), DOC)),
        vec!["Hedvig Palmgren".to_string(), "Faruk AB".to_string()],
        "the list was switched off and the names were still taken out"
    );

    set_user_list_enabled("sv".to_string(), true).expect("on");
    assert!(
        in_the_clear(&what_leaves(Some(&p), DOC)).is_empty(),
        "the list came back on and the names stayed in the clear"
    );
}

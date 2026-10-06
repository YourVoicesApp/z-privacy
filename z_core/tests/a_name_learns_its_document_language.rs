// 041-I/2 · A name learns the language of the document it was taught from.
//
// The owner, 6 October, from a live run: working on a Swedish attachment, the
// bar saying «Svenska (SV)» after switching the session's pack, 75 surnames
// taught from the names panel — and all 75 landed under «German (DE) 75».
//
// The defect was one line: `teach_name` read the **settings** pack, which is
// the language this device starts with, not the language of the document in
// front of the person. The session knows better, and from here it is asked.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett tillräckligt långt lösenord";

/// The core is process-global, so the tests in this file take turns.
fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// A device set up in German — as the owner's is — with an open vault.
fn a_german_device(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-doc-language-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    let mut settings = settings().expect("settings");
    settings.pack_id = "de".to_string();
    save_settings(settings).expect("save");
}

fn list_of(text: &str) -> String {
    user_names(None)
        .expect("names")
        .into_iter()
        .find(|n| n.text == text)
        .map(|n| n.list)
        .unwrap_or_else(|| panic!("«{text}» was not taught at all"))
}

fn sizes() -> Vec<(String, u32)> {
    user_lists()
        .expect("lists")
        .into_iter()
        .map(|l| (l.name, l.names))
        .collect()
}

/// The owner's case, in miniature: a German device, a Swedish document, and a
/// surname taught from the panel while it is open.
#[test]
fn a_name_taught_from_a_document_goes_into_that_document_s_language() {
    let _guard = serial();
    a_german_device("session");

    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, "Hej, Lars Reinholdsson skriver.\n".to_string()).expect("import");
    switch_pack(session, "sv".to_string()).expect("switch");

    teach_name("Reinholdsson".to_string(), true, None, Some(session)).expect("teach");

    assert_eq!(
        list_of("Reinholdsson"),
        "sv",
        "the name went into the device's language instead of the document's"
    );
    // And the German list was not created by a Swedish name.
    assert!(
        !sizes().iter().any(|(name, _)| name == "de"),
        "a German list was made for a Swedish name: {:?}",
        sizes()
    );
    let _ = close_session(session);
}

/// With no document open there is no document language, and the device's own
/// is the only answer there is.
#[test]
fn with_no_session_the_device_s_own_language_is_the_list() {
    let _guard = serial();
    a_german_device("no-session");

    teach_name("Okonkwo".to_string(), true, None, None).expect("teach");

    assert_eq!(list_of("Okonkwo"), "de", "the settings pack is the answer when nothing is open");
}

/// And the repair for the 75 already in the wrong place: one move, one answer.
#[test]
fn a_list_moves_to_another_language_in_one_act() {
    let _guard = serial();
    a_german_device("move");

    for name in ["Pettersson", "Bergström", "Lindqvist"] {
        teach_name(name.to_string(), true, None, None).expect("teach");
    }
    assert_eq!(user_list_plan("de".to_string()).expect("plan"), 3, "the three are not in de");

    let moved = move_user_list("de".to_string(), "sv".to_string()).expect("move");

    assert_eq!(moved, 3, "the move did not carry every name");
    for name in ["Pettersson", "Bergström", "Lindqvist"] {
        assert_eq!(list_of(name), "sv", "«{name}» stayed behind");
    }
    // The emptied list is gone rather than left as an empty box with a name.
    assert!(
        !sizes().iter().any(|(name, _)| name == "de"),
        "the list it left is still there: {:?}",
        sizes()
    );
    assert_eq!(sizes(), vec![("sv".to_string(), 3)], "the lists after the move: {:?}", sizes());
}

/// A move into a language this build has never heard of is refused, the same
/// way teaching into one is: a list is a language, and only a known one.
#[test]
fn a_move_into_something_that_is_not_a_language_is_refused() {
    let _guard = serial();
    a_german_device("refused");
    teach_name("Holgersson".to_string(), true, None, None).expect("teach");

    let refused = move_user_list("de".to_string(), "klingon".to_string());

    assert!(refused.is_err(), "a list was moved into a language that does not exist");
    assert_eq!(list_of("Holgersson"), "de", "a refused move moved something anyway");
}

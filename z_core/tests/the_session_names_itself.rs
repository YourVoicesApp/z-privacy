//! **A session is named in the language it was born with** — paper 117 item 1,
//! the owner's word of 25 October 2026, looking at the Arabic screens he had
//! just been given: a person working in Arabic was handed a list of sessions
//! called «Session 1», «Session 2» in the middle of their own language.
//!
//! Two laws, and they pull against each other, which is why both are measured
//! here:
//!
//!   * the name a session is **given** is in the language of its birth —
//!     «جلسة 1», «Sitzung 1», «Session 1»;
//!   * the name a session **has** never moves again. It is data (G37): the
//!     interface may be switched a minute later, and a house that rewrote the
//!     name would be rewriting a string it cannot tell from the person's own
//!     words.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};
use z_core::api::*;

const AR: &str = "السيد طارق بن سعود الريحاني كتب إلينا بتاريخ 3 مارس.";
const PASS: &str = "كلمة سر طويلة بما يكفي للخزنة";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// A vault of this test's own, because a session's name is written into one.
fn fresh(tag: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-names-itself-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// The birth this paper is about: a document entering the preview with nothing
/// open, on a bench reading `language`.
fn a_session_born_reading(language: &str, text: &str) -> ConversationRow {
    let session = open_session(None, language.to_string()).expect("open");
    import_text(session, text.to_string()).expect("import");
    let rows = conversations().expect("rows");
    assert_eq!(rows.len(), 1, "one document, one session: {rows:?}");
    let _ = close_session(session);
    rows.into_iter().next().expect("the row")
}

/// **Born in Arabic, stored in Arabic.**
#[test]
fn a_session_born_in_arabic_is_called_a_session_in_arabic() {
    let _guard = serial();
    fresh("arabic");
    let row = a_session_born_reading("ar", AR);
    assert_eq!(row.name, format!("جلسة {}", row.number), "a session born in Arabic is «{}»", row.name);
    assert_eq!(row.pack_id.as_deref(), Some("ar"), "the birth did not record its language");
}

/// **And in German, and in English, and in Swedish — which spells it as
/// English does.**
///
/// Swedish is the row a reader might take for an omission: it is the word
/// Swedish uses, and `check_the_one_list.py` already names it among the four
/// values that language shares with the source list.
#[test]
fn every_language_the_interface_speaks_names_its_own_sessions() {
    let _guard = serial();
    for (language, word) in [("de", "Sitzung"), ("en", "Session"), ("sv", "Session")] {
        fresh(language);
        let row = a_session_born_reading(language, "Herr Thomas Müller hat geschrieben.");
        assert_eq!(
            row.name,
            format!("{word} {}", row.number),
            "a session born in «{language}» is «{}»",
            row.name
        );
    }
}

/// **A language the interface does not speak is named in the source's own
/// word**, which is the answer `theLocaleOf` gives such a code everywhere else
/// (rule 56-أ). Japanese is a scanner language with no sentences of its own.
#[test]
fn a_language_the_glass_does_not_speak_falls_back_to_the_source() {
    let _guard = serial();
    fresh("japanese");
    let row = a_session_born_reading("ja", AR);
    assert_eq!(row.name, format!("Session {}", row.number), "«{}»", row.name);
    assert_eq!(row.pack_id.as_deref(), Some("ja"), "the language was not recorded");
}

/// **The stored name does not move when the language does** — the name is data.
///
/// The person switches the open session's language in the header, which the
/// core records on the row (075c). The name stays exactly as it was written:
/// read back from the vault, not from memory, by locking and opening again —
/// the restart a person's own hand makes.
#[test]
fn the_name_stays_as_it_was_written_when_the_language_moves() {
    let _guard = serial();
    fresh("moves");
    let session = open_session(None, "ar".to_string()).expect("open");
    import_text(session, AR.to_string()).expect("import");
    let before = conversations().expect("rows").into_iter().next().expect("the row");
    assert_eq!(before.name, format!("جلسة {}", before.number));

    // The header's own act: this session reads German from now on.
    switch_pack(session, "de".to_string()).expect("the language was refused");
    let after = conversations().expect("rows").into_iter().next().expect("the row");
    assert_eq!(after.pack_id.as_deref(), Some("de"), "the switch did not reach the row");
    assert_eq!(
        after.name, before.name,
        "the stored name followed the language: «{}» became «{}»",
        before.name, after.name
    );

    // And off the disk, after the vault has been shut and opened — which is
    // what a person's restart is.
    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    let read_back = conversations().expect("rows").into_iter().next().expect("the row");
    assert_eq!(
        read_back.name,
        format!("جلسة {}", before.number),
        "the name read back from the vault is «{}»",
        read_back.name
    );
    let _ = close_session(session);
}

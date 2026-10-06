// 041-P · A piece of a word is not the word.
//
// From the owner's own recording of a Swedish page, 6 October: he selected
// «Sven», the placeholder bug that 041-K closed put «ven» into the library,
// and the matcher then found «ven» inside «Svensk» and «svenska» and wrote
// `S__Z_2DD1_PERSON_DC2F__sk` into the text three times. 041-K closed where
// the fragment came from; this closes what a fragment can do.
//
// Measured on one Swedish line holding «Sven», «svensk» and «Svensk»:
//
//     taught    before    after
//     «ven»     3         0
//     «Sven»    2         1        (one of the two was inside «Svensk»)
//
// And in Arabic the rule has a second half, because Arabic attaches its small
// words to the next one. Measured on the book of Kalila and Dimna through the
// §4.3 path (poppler's text, folded to NFKC), five characters taught as Person
// · always: **462 places before and 462 after** — §4.3's contract is 461, and
// the one extra is this machine's own count, not a change made here.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

/// The core is process-global, so these take turns.
fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

const PASS: &str = "ett tillräckligt långt lösenord";

fn fresh(tag: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-whole-values-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
}

/// One value in the vault, protected on sight.
fn teach(text: &str) {
    let entity = create_entity(EntityKind::Client, "X".to_string(), None).expect("entity");
    set_value(entity, None, Kind::Person, text.to_string(), Policy::Always).expect("value");
}

fn protected_places(pack: &str, doc: &str) -> Vec<(u32, u32)> {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let places = document_view(session)
        .expect("view")
        .marks
        .iter()
        .filter(|m| m.state == MarkState::Protected)
        .map(|m| (m.span.start, m.span.end))
        .collect();
    let _ = close_session(session);
    places
}

const SWEDISH: &str = "Sven Nelander är svensk och arbetar i Svensk Handel.\n";

/// The owner's case: the fragment matches nothing at all now.
#[test]
fn a_fragment_of_a_word_matches_nothing() {
    let _guard = serial();
    fresh("fragment");
    teach("ven");
    assert_eq!(
        protected_places("sv", SWEDISH),
        Vec::new(),
        "a three-letter fragment is still being protected inside whole words"
    );
}

/// And the whole word matches itself, once — not twice because another word
/// happens to contain it.
#[test]
fn a_whole_word_matches_itself_and_not_the_word_it_hides_in() {
    let _guard = serial();
    fresh("whole");
    teach("Sven");
    assert_eq!(
        protected_places("sv", SWEDISH),
        vec![(0, 4)],
        "«Sven» matched something other than the name at the start of the line"
    );
}

/// Arabic attaches «و», «ب», «ل», «ف» and «ك» to the word that follows, so a
/// value may carry them in front and still be that value. «مدمنة» is a
/// different word, and `م` is the difference.
#[test]
fn the_arabic_clitics_stay_attached_and_the_name_still_matches() {
    let _guard = serial();
    fresh("clitics");
    teach("دمنة");
    // ودمنة · ولدمنة · دمنة · ومدمنة · ودمنةٌ — four of the five are the name.
    let line = "ودمنة ولدمنة ثم دمنة ومدمنة ودمنةٌ\n";
    let places = protected_places("ar", line);
    assert_eq!(
        places.len(),
        4,
        "the clitics or the vowel mark broke the match: {places:?}"
    );
    // The one that is not: «ومدمنة», whose letters only happen to end in the
    // name. Its offset is the fourth candidate's, and it is absent.
    let units: Vec<u16> = line.encode_utf16().collect();
    for (start, end) in &places {
        let got = String::from_utf16_lossy(units.get(*start as usize..*end as usize).unwrap_or_default());
        assert_eq!(got, "دمنة", "a match covers something other than the name");
        let before = start.saturating_sub(1) as usize;
        let letter = String::from_utf16_lossy(units.get(before..*start as usize).unwrap_or_default());
        assert_ne!(letter, "م", "«مدمنة» was taken as the name with a letter in front");
    }
}

/// A vowel mark is part of the letter it sits on, not the start of another
/// word. §4.3 of `docs/THE_NUMBERS.md` counts 101 occurrences that carry one,
/// and a rule that read them as letters would lose every one.
#[test]
fn a_vowel_mark_does_not_end_a_word() {
    let _guard = serial();
    fresh("harakat");
    teach("دمنة");
    assert_eq!(
        protected_places("ar", "قال دمنةُ للأسد\n").len(),
        1,
        "the name was lost because a damma stands on its last letter"
    );
}

/// Chinese and Japanese put no space between words, so there is no edge to
/// test and a substring is the only thing a match can be. The rule knows that
/// about a script rather than applying a Latin habit to it.
#[test]
fn a_script_without_spaces_keeps_matching_inside_the_line() {
    let _guard = serial();
    fresh("cjk");
    teach("田中");
    assert_eq!(
        protected_places("en", "担当は田中さんです。\n").len(),
        1,
        "a Japanese name stopped matching because it has no space around it"
    );
}

/// One or two capitalised words are offered as a person — the last guess of
/// all, after the pack and the findings, and only a default in a dialog.
#[test]
fn the_hand_drawn_selection_is_offered_as_a_person() {
    let _guard = serial();
    fresh("kind");
    let session = open_session(None, "sv".to_string()).expect("open");
    let doc = "Protokoll 2026\nBjörn Sandström ringde klockan 14 om fakturan 55123.\n";
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");

    let span = |needle: &str| {
        let at = doc.find(needle).expect("needle");
        let start = doc[..at].chars().map(char::len_utf16).sum::<usize>() as u32;
        Span {
            start,
            end: start + needle.chars().map(char::len_utf16).sum::<usize>() as u32,
        }
    };

    // Two capitalised words: a person, so the dialog opens on the kind the
    // model understands instead of on «Custom».
    assert_eq!(
        inspect_selection(session, span("Björn Sandström")).expect("view").kind,
        Kind::Person,
        "a hand-drawn name is still offered as Custom"
    );
    // One capitalised word is the same case.
    assert_eq!(
        inspect_selection(session, span("Protokoll")).expect("view").kind,
        Kind::Person
    );
    // And what is not a name stays what it was: a number, a lower-case word,
    // and a stretch of prose are all still Custom.
    for not_a_name in ["55123", "ringde", "om fakturan 55123"] {
        assert_eq!(
            inspect_selection(session, span(not_a_name)).expect("view").kind,
            Kind::Custom,
            "«{not_a_name}» was offered as a person"
        );
    }
    let _ = close_session(session);
}

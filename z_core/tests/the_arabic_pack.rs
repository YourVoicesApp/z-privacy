//! **The Arabic pack** — paper 115, 25 October 2026, and the measurement that
//! earns every line of `scanner/packs/ar.rs`.
//!
//! The owner handed over his own library of Arabic names and the doctrine that
//! goes with it: the sentences, a bounded library, and a few rules that can be
//! measured. So this file measures them, on `fixtures/Risala_Alharbi.txt`
//! (AR-1) — the Arabic letter this house already had, which is why it is the
//! fixture: it was written before the pack existed and it was not written for
//! it.
//!
//! **The numbers, on AR-1:**
//!
//! ```text
//!     before 115            5 auto ·  2 waiting      not one of its 8 people
//!     after 115            19 auto ·  6 waiting
//!     after 117 item 5     19 auto ·  5 waiting      one courtesy phrase out
//! ```
//!
//! The fourteen that moved are the name words of the seven people a salutation
//! or a title introduces; the four that joined the waiting list are three
//! ordinary words the owner's library also holds as names — a street named
//! after a prince, «صاحب» in «اسم صاحب الحساب», «فائق» in «فائق الاحترام» — and
//! the internal extension the letter writes in Arabic-Indic digits, which
//! nothing in this program could see before.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};
use z_core::api::*;

const AR1: &str = include_str!("fixtures/Risala_Alharbi.txt");

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
    let dir = std::env::temp_dir().join(format!("zprivacy-arabic-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
}

/// Every finding of one scan, as the text it points at — read through UTF-16
/// offsets, which is what a span counts (`Span` is what Dart's `String`
/// measures, and slicing those as bytes panics inside an Arabic letter).
fn found_in(pack: &str, text: &str) -> Vec<(String, MarkState, Kind)> {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, text.to_string()).expect("import");
    scan(session).expect("scan");
    let units: Vec<u16> = text.encode_utf16().collect();
    let out = list_findings(session)
        .expect("findings")
        .into_iter()
        .map(|f| {
            (
                String::from_utf16_lossy(&units[f.span.start as usize..f.span.end as usize]),
                f.state,
                f.kind,
            )
        })
        .collect();
    let _ = close_session(session);
    out
}

fn counts(pack: &str, text: &str) -> (u32, u32) {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, text.to_string()).expect("import");
    let report = scan(session).expect("scan");
    let out = (report.auto, report.suggested);
    let _ = close_session(session);
    out
}

/// **The seven people a form word introduces are protected, by name.**
///
/// Not by a count: a count moves when the library grows and says nothing about
/// whom it found. «كاترين لندمان» is the one that matters most — a Latin name
/// transcribed into Arabic, in **no** Arabic name library and in none that will
/// ever be written — and it is protected because a salutation stands in front
/// of it. That is the whole of what `ar-1` is for.
///
/// One finding per word, which is the owner's own law (085: one token is one
/// word) and is exactly how the German pack reports «Thomas Müller» — measured
/// beside it in `a_german_name_is_reported_the_same_way` below, so that nobody
/// reads this shape as an Arabic quirk.
#[test]
fn a_name_after_an_arabic_salutation_is_protected() {
    let _guard = serial();
    fresh("salutation");
    let found = found_in("ar", AR1);
    let protected: Vec<&str> = found
        .iter()
        .filter(|(_, state, kind)| *state == MarkState::Protected && *kind == Kind::Person)
        .map(|(text, _, _)| text.as_str())
        .collect();
    for name in [
        "كاترين", "لندمان",          // السيدة الفاضلة …
        "طارق", "بن", "سعود", "الريحاني", // السيد …
        "أميرة", "الحداد",            // الدكتورة …
        "يوسف", "العمري",             // الأستاذ …
        "سارة", "البراك",             // المهندسة …
        "يونس", "دمير",               // السائق السيد …
    ] {
        assert!(protected.contains(&name), "«{name}» is in the clear: {protected:?}");
    }
    // And the courtesy words around them are **not** protected: the sentence
    // still reads, which is the same law a German salutation keeps.
    for form in ["السيدة", "الفاضلة", "المحترمة", "الدكتورة", "الأستاذ", "المهندسة", "السيد"] {
        assert!(!protected.contains(&form), "«{form}» is a form word and was protected");
    }
}

/// **A given name in the owner's library waits for his word, and never protects
/// itself.**
///
/// The two below are the measured cost of a 2,414-name library on one letter:
/// «سلطان» is a street named after a prince and «صاحب» is the word for an
/// account holder. Both are real names in Arabic and real words in the sentence
/// they stand in — which is why a dictionary hit is a question here and a
/// verdict nowhere.
///
/// **«فائق» was the third until 117 item 5**: it is half of «فائق الاحترام»,
/// and the word after it is the only thing that can say so. It is in
/// `a_name_in_a_courtesy_phrase_is_not_offered` now, with the control that it
/// is still offered where it really is a name.
#[test]
fn a_name_the_library_knows_waits_for_your_word() {
    let _guard = serial();
    fresh("library");
    let found = found_in("ar", AR1);
    let waiting: Vec<&str> = found
        .iter()
        .filter(|(_, state, _)| *state == MarkState::Suggested)
        .map(|(text, _, _)| text.as_str())
        .collect();
    for word in ["سلطان", "صاحب"] {
        assert!(waiting.contains(&word), "«{word}» is not waiting: {waiting:?}");
    }
    // A form word is never offered either — the fault this file found on its
    // first run: «السيدة» is a given name in the owner's own library, so the
    // salutation of AR-1's opening line was offered as a person to look at.
    for form in ["السيدة", "السيد"] {
        assert!(!waiting.contains(&form), "«{form}» was offered as a name");
    }
}

/// **Harakat match both ways, measured through the library and not through a
/// salutation.**
///
/// The owner writes 856 of his names in a form that carries a vowel mark and
/// **nowhere without it** — «بُجير» is in his library and «بجير» is not — so a
/// document that writes the name bare finds it only if the index is folded. And
/// the other way: «سعود» is in the library bare, and a letter that writes
/// «سَعُود» finds it only if the **word** is folded before it is looked up.
///
/// **The first draft of this guard measured nothing**, and the way it was
/// caught is worth keeping: it wrote the name after «السيد», so `ar-1` found it
/// whatever the fold did, and the guard stayed green with the fold deleted.
/// A control that does not bite is a finding — so both halves below stand in a
/// sentence with no form word in it, where the library is the only thing that
/// can speak.
#[test]
fn a_name_is_found_with_its_marks_and_without_them() {
    let _guard = serial();
    fresh("harakat");
    // The library holds «بُجير» only; the document writes it bare.
    let found = found_in("ar", "وصل بجير إلى المكتب أمس.");
    assert!(
        found.iter().any(|(t, state, kind)| t == "بجير"
            && *state == MarkState::Suggested
            && *kind == Kind::Person),
        "a name the library carries only with its marks was not found bare: {found:?}"
    );
    // The library holds «سعود» bare; the document writes it with marks.
    let found = found_in("ar", "وصل سَعُود إلى المكتب أمس.");
    assert!(
        found.iter().any(|(t, state, kind)| t == "سَعُود"
            && *state == MarkState::Suggested
            && *kind == Kind::Person),
        "a name written with marks was not found in a bare library: {found:?}"
    );
    // And the control: a word that is no name in either form finds nothing.
    let found = found_in("ar", "وصل المكتب إلى الطابق أمس.");
    assert!(
        found.iter().all(|(_, _, kind)| *kind != Kind::Person),
        "an ordinary sentence produced a person: {found:?}"
    );
}

/// **A long number in Arabic-Indic digits is a number** — and nothing in this
/// program could see one before this paper.
///
/// AR-1 writes an internal extension as «٠١٢١٢٣٤٥٩٩», ten digits of a person's
/// own line, while the three telephone numbers written in ASCII on the page
/// above it were all found. The general rules walk bytes and ask
/// `is_ascii_digit`, which is false for «٠».
#[test]
fn a_number_in_arabic_digits_is_seen_at_all() {
    let _guard = serial();
    fresh("digits");
    let found = found_in("ar", AR1);
    assert!(
        found.iter().any(|(t, state, kind)| t == "٠١٢١٢٣٤٥٩٩"
            && *state == MarkState::Suggested
            && *kind == Kind::Phone),
        "the extension written in Arabic-Indic digits is in the clear: {found:?}"
    );
    // A date in the same digits is **not** a number to look at: its slashes cut
    // it into runs of two, two and four, and the window is eight to fifteen.
    let found = found_in("ar", "من مواليد ٢٧/١١/١٩٧٩ في الطائف.");
    assert!(
        found.iter().all(|(t, _, _)| t != "٢٧/١١/١٩٧٩"),
        "a date was read as a long number: {found:?}"
    );
}

/// **A name inside a fixed courtesy phrase is not offered, and the same name
/// standing alone still is** — paper 117 item 5, the owner's own finding on the
/// Arabic screens.
///
/// Both halves, because one without the other is a different rule: a list that
/// only silenced «فائق» would be a list that deleted a name from the library,
/// and that is not what he asked for. What decides is the word **after** it,
/// which is why `FIXED_COURTESIES` is a list of pairs and never «any word
/// followed by a noun».
#[test]
fn a_name_in_a_courtesy_phrase_is_not_offered() {
    let _guard = serial();
    fresh("courtesy");
    // AR-1's own closing line: «وتفضلوا بقبول فائق الاحترام،».
    let found = found_in("ar", AR1);
    assert!(
        found.iter().all(|(t, _, _)| t != "فائق"),
        "the first word of a courtesy phrase was offered as a person: {found:?}"
    );
    // The same word, as a name: offered, and waiting for the person's word.
    let found = found_in("ar", "وصل فائق إلى المكتب أمس.");
    assert!(
        found.iter().any(|(t, state, kind)| t == "فائق"
            && *state == MarkState::Suggested
            && *kind == Kind::Person),
        "a real name was silenced by the courtesy list: {found:?}"
    );
    // And a phrase this list does not hold is not silenced by it: «جزيل» is no
    // name in the library, so «جزيل الشكر» was never a question to begin with —
    // what is measured here is that the list did not grow a rule of its own.
    let found = found_in("ar", "ولكم خالص الشكر على تعاونكم.");
    assert!(
        found.iter().all(|(t, _, _)| t != "خالص"),
        "«خالص الشكر» is in the list and «خالص» was still offered: {found:?}"
    );
}

/// **What the pack is worth on AR-1, in one line each way.**
///
/// The counts are here and nowhere else — a number in a comment is a number
/// nobody asks. They move the day the library grows or a rule is added, and
/// that is what they are for: a drop in either of them is a rule that stopped
/// working.
#[test]
fn the_arabic_letter_reads_better_than_it_did() {
    let _guard = serial();
    fresh("counts");
    assert_eq!(
        counts("ar", AR1),
        (19, 5),
        "AR-1 under the Arabic pack — (5, 2) with no pack at all, (19, 6) before \
         117 item 5 took the courtesy phrase out of the waiting list"
    );
    // **The German pack on the same letter is unchanged**, which is the control
    // that says the Arabic rules are Arabic's: nothing was added to the shared
    // engine, so a pack that is not asked for contributes nothing.
    assert_eq!(counts("de", AR1), (5, 2), "the German baseline on AR-1 moved");
}

/// **A German two-word name is reported the same way**, so that «one finding
/// per word» is read as this house's law and not as something the Arabic rules
/// do.
#[test]
fn a_german_name_is_reported_the_same_way() {
    let _guard = serial();
    fresh("control-de");
    let found = found_in("de", "Sehr geehrter Herr Thomas Müller, wir schreiben Ihnen heute.");
    let protected: Vec<&str> = found
        .iter()
        .filter(|(_, state, _)| *state == MarkState::Protected)
        .map(|(t, _, _)| t.as_str())
        .collect();
    assert_eq!(protected, vec!["Thomas", "Müller"], "{found:?}");
}

/// **An Arabic document under another pack finds no Arabic names**, and an
/// Arabic session finds nothing German: a pack is asked for, never ambient.
#[test]
fn the_arabic_rules_run_only_when_arabic_is_asked_for() {
    let _guard = serial();
    fresh("asked");
    let under_english = found_in("en", AR1);
    assert!(
        under_english.iter().all(|(_, _, kind)| *kind != Kind::Person),
        "an English session found a person in an Arabic letter: {under_english:?}"
    );
    let german = "Sehr geehrter Herr Thomas Müller, wir schreiben Ihnen heute.";
    let found = found_in("ar", german);
    assert!(
        found.iter().all(|(_, _, kind)| *kind != Kind::Person),
        "an Arabic session found a German person: {found:?}"
    );
}

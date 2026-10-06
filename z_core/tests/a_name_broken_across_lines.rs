// 038-I · a name the page broke in two.
//
// From the owner's file, 6 October, measured before anything was changed. The
// payload carried this:
//
// ```text
// Professor __Z_…PERSON…__ Yn-
// nerman leder gruppen.
// ```
//
// The given name was protected and **both halves of the surname went to the
// model in the clear**. That is worse than finding nothing: «Yn-» and «nerman»
// together are the name, and the token beside them says which name it is.
//
// Three shapes were in his file and all three are here: a surname broken at a
// hyphen the page added (`Yn-/nerman`), a company name broken the same way
// (`Ingenjörs-/vetenskapsakademien`), and a first name and surname split by a
// plain line break with no hyphen at all (`Sven/Nelander`).
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett tillräckligt långt lösenord igen";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-broken-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

fn teach(kind: Kind, value: &str) {
    let e = create_entity(EntityKind::Person, format!("K{}", value.len()), None).expect("entity");
    set_value(e, None, kind, value.to_string(), Policy::Always).expect("value");
}

fn scanned(doc: &str, pack: &str) -> SessionId {
    let s = open_session(None, pack.to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    s
}

fn marks(session: SessionId, doc: &str, state: MarkState) -> Vec<String> {
    document_view(session)
        .expect("view")
        .marks
        .iter()
        .filter(|m| m.state == state)
        .map(|m| {
            doc.chars()
                .skip(m.span.start as usize)
                .take((m.span.end - m.span.start) as usize)
                .collect()
        })
        .collect()
}

fn payload_of(session: SessionId) -> String {
    let h = build_payload(session).expect("payload");
    payload_view(h).expect("view").text
}

// ---------------------------------------------------------------- 1 · his case

/// **The surname the page broke, and what leaves the device afterwards.**
#[test]
fn a_surname_broken_at_a_line_end_is_one_name() {
    let _g = serial();
    fresh_vault("surname");
    teach(Kind::Person, "Ynnerman");
    const DOC: &str = "Professor Anders Yn-\nnerman leder gruppen.\n";
    let s = scanned(DOC, "sv");
    // One mark, and it covers **both halves and the break between them**.
    assert_eq!(
        marks(s, DOC, MarkState::Protected),
        vec!["Yn-\nnerman".to_string()],
        "the two halves were not taken as one name"
    );

    // And the whole of it leaves as one token: no hyphen, no half, no twice.
    let out = payload_of(s);
    assert!(!out.contains("Yn-"), "half a surname went to the model: {out:?}");
    assert!(!out.contains("nerman"), "the other half went to the model: {out:?}");
    assert_eq!(
        out.matches("__Z_").count(),
        1,
        "the name left as {} tokens, not one",
        out.matches("__Z_").count()
    );
    close_session(s).ok();
}

/// A company name, broken the same way, and more than one word long — so the
/// space in the value has to survive being a line break as well.
#[test]
fn a_company_name_survives_both_a_space_and_a_break() {
    let _g = serial();
    fresh_vault("company");
    teach(Kind::Company, "Kungl. Ingenjörsvetenskapsakademien");
    const DOC: &str = "Kungl.\nIngenjörs-\nvetenskapsakademien bidrar.\n";
    let s = scanned(DOC, "sv");
    assert_eq!(
        marks(s, DOC, MarkState::Protected),
        vec!["Kungl.\nIngenjörs-\nvetenskapsakademien".to_string()]
    );
    assert_eq!(payload_of(s).matches("__Z_").count(), 1);
    close_session(s).ok();
}

/// A name that owns its hyphen, printed with the break at that very hyphen.
#[test]
fn a_hyphenated_name_broken_at_its_own_hyphen_is_still_itself() {
    let _g = serial();
    fresh_vault("own-hyphen");
    teach(Kind::Person, "Anna-Lena Bergström");
    const DOC: &str = "Hälsningar Anna-\nLena Bergström\n";
    let s = scanned(DOC, "sv");
    assert_eq!(
        marks(s, DOC, MarkState::Protected),
        vec!["Anna-\nLena Bergström".to_string()]
    );
    close_session(s).ok();
}

/// **And the hyphen that is the word's own is not thrown away.**
///
/// This is the line the owner's rule draws: the next line beginning with a
/// capital is a new word, so the hyphen in front of it belongs to the text. A
/// value with no hyphen must not be found across one.
#[test]
fn a_value_without_a_hyphen_is_not_found_across_a_real_one() {
    let _g = serial();
    fresh_vault("keep-hyphen");
    teach(Kind::Person, "AnnaLena");
    const DOC: &str = "Hälsningar Anna-\nLena\n";
    let s = scanned(DOC, "sv");
    assert!(
        marks(s, DOC, MarkState::Protected).is_empty(),
        "«Anna-Lena» was read as «AnnaLena» — the capital after the break was ignored"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 2 · the pair

/// **A wrapped line no longer breaks a given name from its surname.**
///
/// Nothing is taught here: this is the pack's own pair rule, which is what has
/// to carry the names that are in nobody's list. It used to refuse the pair for
/// the line break alone.
#[test]
fn the_pair_rule_reads_across_a_wrapped_line() {
    let _g = serial();
    fresh_vault("pair");
    const DOC: &str = "Der Vorgang wurde von Thomas\nMüller geprüft und freigegeben.\n";
    let s = scanned(DOC, "de");
    let offered = marks(s, DOC, MarkState::Suggested);
    assert!(
        offered.iter().any(|o| o == "Thomas\nMüller"),
        "the pair was not offered across the line break: {offered:?}"
    );
    close_session(s).ok();
}

/// **But a page break is not a wrapped line.**
///
/// The last word of one page and the first of the next are not neighbours,
/// whatever the whitespace between them looks like — a header, a footer and a
/// page number stood there on the page a person read.
#[test]
fn the_pair_rule_does_not_read_across_a_page() {
    let _g = serial();
    fresh_vault("pages");
    const DOC: &str = "Der Vorgang wurde von Thomas\u{c}Müller geprüft.\n";
    let s = scanned(DOC, "de");
    let offered = marks(s, DOC, MarkState::Suggested);
    assert!(
        !offered.iter().any(|o| o.contains('\u{c}')),
        "a pair was formed across a page boundary: {offered:?}"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 3 · the line

/// A break inside a word does not make two ordinary words into one.
///
/// The narrow rules this change rests on, stated as a test: whitespace is
/// crossed only where the value itself has whitespace, or right after a hyphen
/// — never merely because two words sit on two lines.
#[test]
fn two_words_on_two_lines_are_still_two_words() {
    let _g = serial();
    fresh_vault("two-words");
    teach(Kind::Person, "SvenNelander");
    const DOC: &str = "Kontakt: Sven\nNelander svarar.\n";
    let s = scanned(DOC, "sv");
    assert!(
        marks(s, DOC, MarkState::Protected).is_empty(),
        "«Sven» and «Nelander» were run together into one word"
    );
    close_session(s).ok();
}

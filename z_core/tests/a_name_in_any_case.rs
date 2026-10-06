// 041-R · a name is the same name shouted.
//
// From the owner's own file, 6 October, on the published build: «Leifland» and
// «Wihlborg» were in his Swedish list and protected in the running text — and
// left in the clear in «TEXT: CRISTINA LEIFLAND» and «TEXT: ANNIKA WIHLBORG».
// Six places in ten pages.
//
// **The measurement that shaped the fix:** there was not one comparison but
// two, and they were the same code written twice — `scanner::occurrences` for
// the vault layer and `ops::occurrences` for «protect every place». Making one
// of them case-blind would have left the app finding a name that it would then
// refuse to protect everywhere, which is worse than the defect. They are now
// one function, `text::occurrences`.
//
// And the thing these tests exist to hold apart: **case is still a signal.**
// German marks a noun with a capital and the packs read that. What changed is
// only how a value the app was *given* is found in a document.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett tillräckligt långt lösenord här";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-case-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// Teach one value, found by itself from now on.
fn teach(kind: Kind, value: &str) -> u32 {
    let e = create_entity(EntityKind::Person, "Kontakt".to_string(), None).expect("entity");
    set_value(e, None, kind, value.to_string(), Policy::Always).expect("value");
    e
}

/// What is protected in this document, as the text it covers.
fn protected(session: SessionId, doc: &str) -> Vec<String> {
    let view = document_view(session).expect("view");
    let mut out = Vec::new();
    for mark in &view.marks {
        if mark.state != MarkState::Protected {
            continue;
        }
        let text: String = doc
            .chars()
            .skip(mark.span.start as usize)
            .take((mark.span.end - mark.span.start) as usize)
            .collect();
        out.push(text);
    }
    out
}

fn scanned(doc: &str) -> SessionId {
    let s = open_session(None, "sv".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    s
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

// ---------------------------------------------------------------- 1 · his case

/// **The acceptance, in the owner's own words and shapes.**
#[test]
fn a_taught_name_is_found_in_every_case() {
    let _g = serial();
    fresh_vault("three");
    teach(Kind::Person, "Leifland");

    const DOC: &str = "Leifland skrev rapporten.\n\
                       TEXT: CRISTINA LEIFLAND\n\
                       Enligt leifland är det klart.\n";
    let s = scanned(DOC);

    let found = protected(s, DOC);
    assert_eq!(
        found.len(),
        3,
        "the same name in three cases was protected {} time(s): {found:?}",
        found.len()
    );
    // And each is the document's own spelling, not the vault's: what a person
    // reads on the page is what is marked on the page.
    assert!(found.contains(&"Leifland".to_string()));
    assert!(found.contains(&"LEIFLAND".to_string()));
    assert!(found.contains(&"leifland".to_string()));
    close_session(s).ok();
}

/// The second name from the same file, in the same shape.
#[test]
fn the_shouted_line_in_his_file_is_protected() {
    let _g = serial();
    fresh_vault("wihlborg");
    teach(Kind::Person, "Wihlborg");
    const DOC: &str = "TEXT: ANNIKA WIHLBORG\nWihlborg är redaktör.\n";
    let s = scanned(DOC);
    assert_eq!(protected(s, DOC).len(), 2);
    close_session(s).ok();
}

// ---------------------------------------------------------------- 2 · the trap

/// **The offsets stay the document's, even when lowercasing changes a length.**
///
/// `İ` (U+0130) lowercases to two code points, `i` followed by a combining dot.
/// So a value held as the lowercase form is **one byte longer** than the text it
/// matches. Had this been done by lowercasing both sides and taking the
/// needle's own length, the protection would have ended one byte late — inside
/// the next character — which is the family of mistake this project has paid
/// for twice.
#[test]
fn a_longer_lowercase_does_not_move_the_span() {
    let _g = serial();
    fresh_vault("dotted");
    // Held in the vault as the lowercase form, with its combining dot.
    teach(Kind::Company, "i\u{307}stanbul Tekstil");
    const DOC: &str = "Leverantör: \u{130}stanbul Tekstil AB\n";
    // Control: the two really are different lengths, or this proves nothing.
    assert_ne!(
        "i\u{307}stanbul Tekstil".len(),
        "\u{130}stanbul Tekstil".len(),
        "the fixture no longer exercises a length change"
    );

    let s = scanned(DOC);
    let found = protected(s, DOC);
    assert_eq!(found, vec!["\u{130}stanbul Tekstil".to_string()],
        "the span is not the document's own characters");
    close_session(s).ok();
}

/// What this does **not** claim, pinned so the gap is a decision and not a
/// surprise: `char::to_lowercase` is the simple mapping, and German `ß` is not
/// `SS` under it.
#[test]
fn full_case_folding_is_not_claimed() {
    let _g = serial();
    fresh_vault("sharp-s");
    teach(Kind::Person, "Wei\u{df}");
    const DOC: &str = "Wei\u{df} und WEISS und WEI\u{df}.\n";
    let s = scanned(DOC);
    let found = protected(s, DOC);
    assert!(
        found.contains(&"Wei\u{df}".to_string()) && found.contains(&"WEI\u{df}".to_string()),
        "the ß spellings are the ones this rule does cover: {found:?}"
    );
    assert!(
        !found.contains(&"WEISS".to_string()),
        "«SS» is now matched as «ß» — the rule grew a claim, and the note in \
         text::occurrences has to grow with it"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 3 · one rule

/// **«Protect every place» reads case the same way the scan does.**
///
/// This is the half that was a second copy of the same code. If the two ever
/// part again, the app will find a name and then decline to protect it
/// everywhere — and there is no sentence that makes that honest.
#[test]
fn protecting_every_place_is_case_blind_too() {
    let _g = serial();
    fresh_vault("every-place");
    const DOC: &str = "Keller svarade.\nTEXT: GREGOR KELLER\nenligt keller.\n";
    let s = open_session(None, "sv".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");

    // Taken from the page by hand, in the case it happens to be written in.
    let outcome = protect_all_matches(s, span_of(DOC, "keller"), Scope::Once, Kind::Person)
        .expect("protect every place");
    match outcome {
        ProtectOutcome::Applied { places, .. } => assert_eq!(
            places, 3,
            "«every place» found {places} of the three cases"
        ),
        other => panic!("expected it to apply, got {other:?}"),
    }
    assert_eq!(protected(s, DOC).len(), 3);
    close_session(s).ok();
}

// ---------------------------------------------------------------- 4 · the line

/// **A capital is still a signal.** The two uses of case are different jobs and
/// this is the test that keeps them apart: the German pack reads a capital to
/// decide whether a word could be a name at all, and that did not change.
///
/// `enligt` and `skrev` are ordinary lowercase words beside a taught name. If
/// case-blindness had leaked from «find what I was given» into «decide what
/// looks like a name», they would be candidates here.
#[test]
fn a_lowercase_word_is_still_not_a_name() {
    let _g = serial();
    fresh_vault("signal");
    teach(Kind::Person, "Leifland");
    const DOC: &str = "enligt Leifland skrev rapporten om anders och sven.\n";
    let s = scanned(DOC);

    let found = protected(s, DOC);
    assert_eq!(found, vec!["Leifland".to_string()], "something else was taken as a name");
    // And nothing lowercase was even offered.
    let offered: Vec<String> = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| {
            DOC.chars()
                .skip(f.span.start as usize)
                .take((f.span.end - f.span.start) as usize)
                .collect::<String>()
        })
        .collect();
    for word in ["enligt", "skrev", "anders", "sven", "om"] {
        assert!(
            !offered.iter().any(|o| o == word),
            "«{word}» was offered as a name: {offered:?}"
        );
    }
    close_session(s).ok();
}

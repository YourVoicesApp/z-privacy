// Where does the token stand?
//
// The owner protected «Dr. Gerhard Renner» by hand on page 15 of a 734-page
// Austrian ICD-10 document and said: «the encryption happens in reverse, on the
// wrong part of the text». On the safe side a person's token stood in front of
// «. Petra Paretta, Dr. Florian Röthlin…» and a company's token in front of a
// colon — nowhere near what he had selected.
//
// So this holds the one thing that cannot be allowed to drift. For a single
// protection, the text that leaves is the text that arrived with that one
// stretch replaced — character for character, and nothing else moved:
//
//     payload == original[..start] + token + original[end..]
//
// It is checked on a letter of 227 words, on a 146-page book, and on the
// owner's own 734-page file, because the thing that moves an offset is the
// character before it: an «ö» is one character, two bytes, one UTF-16 unit, and
// every boundary between those three is a place a span can be read wrongly.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use std::path::PathBuf;

use z_core::api::*;

fn book() -> Option<PathBuf> {
    let path = PathBuf::from(std::env::var("HOME").ok()?).join("Downloads/tysk1.pdf");
    path.is_file().then_some(path)
}

/// What the text that leaves must be: the text that arrived, with every
/// protected stretch replaced by its own token and nothing else touched.
///
/// Rebuilt from the marks the core itself reports, so it is the core checked
/// against the core — the only comparison that can catch an offset read in the
/// wrong units, since both sides would otherwise be wrong together.
fn expected_payload(session: SessionId) -> String {
    let view = document_view(session).expect("view");
    let units: Vec<u16> = view.text.encode_utf16().collect();
    let mut protected: Vec<(usize, usize, String)> = view
        .marks
        .iter()
        .filter(|m| m.state == MarkState::Protected)
        .filter_map(|m| {
            m.token
                .clone()
                .map(|t| (m.span.start as usize, m.span.end as usize, t))
        })
        .collect();
    protected.sort_by_key(|(start, _, _)| *start);

    let mut out = String::new();
    let mut at = 0usize;
    for (start, end, token) in protected {
        if start < at {
            continue; // overlapping marks: the first one wins, as the core does
        }
        out.push_str(&String::from_utf16_lossy(units.get(at..start).unwrap_or_default()));
        out.push_str(&token);
        at = end;
    }
    out.push_str(&String::from_utf16_lossy(units.get(at..).unwrap_or_default()));
    // 041-J — the page's edge is for the person reading, not for the model, so
    // the payload turns each form feed into an ordinary line break on the way
    // out. One character for one character: this comparison still holds the
    // whole text to account, position by position.
    out.replace('\u{c}', "\n")
}

/// Protect one stretch, named by its text, the way a person selects it: by
/// what it says, converted to the UTF-16 units the screen counts in.
fn protect_by_text(session: SessionId, phrase: &str) {
    let original = document_view(session).expect("view").text;
    let at = original.find(phrase).unwrap_or_else(|| panic!("«{phrase}» is not in this document"));
    let start = original.get(..at).unwrap_or_default().encode_utf16().count() as u32;
    let end = start + phrase.encode_utf16().count() as u32;
    protect(session, Span { start, end }, Scope::Once, Kind::Person).expect("protect");
}

fn check(name: &str, session: SessionId, phrase: &str) {
    protect_by_text(session, phrase);
    let expected = expected_payload(session);
    let handle = build_payload(session).expect("build");
    let payload = payload_view(handle).expect("payload").text;

    if payload == expected {
        return;
    }
    // Where they part company, and the thirty characters either side. Compared
    // as whole strings on purpose: looking for each token on its own cannot
    // tell one occurrence of a repeated value from another, and a value that
    // appears twice is the ordinary case, not the exception.
    let at = payload
        .char_indices()
        .zip(expected.char_indices())
        .find(|((_, a), (_, b))| a != b)
        .map(|((i, _), _)| i)
        .unwrap_or_else(|| payload.len().min(expected.len()));
    let window = |text: &str| {
        let from = text
            .char_indices()
            .map(|(i, _)| i)
            .filter(|i| *i <= at)
            .nth_back(30.min(at))
            .unwrap_or(0);
        let to = text.char_indices().map(|(i, _)| i).find(|i| *i > at + 60).unwrap_or(text.len());
        text.get(from..to).unwrap_or_default().replace('\n', "⏎")
    };
    panic!(
        "{name}: the text that leaves is not the text that arrived with its values replaced.\n\
         They part at character {at} of {} (expected {}).\n\
         leaves  : …{}…\n\
         expected: …{}…",
        payload.chars().count(),
        expected.chars().count(),
        window(&payload),
        window(&expected)
    );
}

#[test]
fn a_hand_protection_in_a_letter_replaces_what_was_selected() {
    let session = open_session(None, "de".to_string()).expect("open");
    let letter = std::fs::read(concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/Brief_Weber.txt")).expect("letter");
    import_document(session, "Brief_Weber.txt".to_string(), letter, DocumentKind::Txt).expect("import");
    // The app scans on import, so the hand protection joins twenty others —
    // which is the state the owner was in when he pressed Protect.
    scan(session).expect("scan");
    check("the letter", session, "Markus Weber");
}

#[test]
fn a_hand_protection_in_a_public_book_replaces_what_was_selected() {
    let path = match std::env::var("ZPRIVACY_SECOND_GOLDEN") {
        Ok(name) => PathBuf::from(name),
        Err(_) => PathBuf::from(std::env::var("HOME").unwrap_or_default()).join("Documents/steuern-von-a-z.pdf"),
    };
    if !path.is_file() {
        println!("the tax book is not on this machine — nothing was measured");
        return;
    }
    let session = open_session(None, "de".to_string()).expect("open");
    import_document(session, "steuern-von-a-z.pdf".to_string(), std::fs::read(&path).expect("book"), DocumentKind::Pdf)
        .expect("import");
    scan(session).expect("scan");
    // A word out of the middle of 146 pages of prose, chosen by hand the way a
    // person would choose one.
    check("the tax book", session, "Bundesministerium");
}

#[test]
fn a_hand_protection_after_many_umlauts_replaces_what_was_selected() {
    let session = open_session(None, "de".to_string()).expect("open");
    let Some(path) = book() else {
        println!("tysk1.pdf is not on this machine — nothing was measured");
        return;
    };
    let bytes = std::fs::read(&path).expect("the book");
    import_document(session, "tysk1.pdf".to_string(), bytes, DocumentKind::Pdf).expect("import");
    scan(session).expect("scan");
    check("the Austrian document", session, "Gerhard Renner");
}

// 053 · And the same property, on a span the person drew two characters too far.
//
// Measuring this case first said something about the file rather than about the
// bug. `check` above rebuilds what it expects from the marks the core reports,
// so when the core grew a span over a line break the **expectation grew with
// it**, and the comparison was green on a payload that had joined two of the
// owner's lines into one. That is not a flaw in it: core against core is what
// catches an offset read in the wrong units, and both sides being wrong
// together is exactly the case it was built for. It is simply not a guard
// against a span read too wide.
//
// So the overshoot is held to the document instead: the text that leaves is the
// text that arrived with **the value's own stretch** replaced — the stretch a
// person would say they had selected, not the one the core settled on.
// Measured on 82d5858, before 053's rule 0: red, with
// `Organisationsnummer: __Z_…__: Storgatan 1, 100 00 Stockholm` standing where
// two lines of his file used to be.

/// The two lines of the owner's payroll file that the overshoot joined.
const PAYROLL: &str = "FARUK AB — LÖNEKÖRNING FEBRUARI 2027\n\
                       Organisationsnummer: 559000-0000\n\
                       Adress: Storgatan 1, 100 00 Stockholm\n\
                       E-post: ekonomi@farukab.example\n";

#[test]
fn a_hand_protection_drawn_two_characters_too_far_replaces_only_the_value() {
    // The owner's own configuration: the English pack on a Swedish file, which
    // is why he is protecting this organisation number by hand at all.
    let session = open_session(None, "en".to_string()).expect("open");
    import_text(session, PAYROLL.to_string()).expect("import");

    let value = "559000-0000";
    let at = PAYROLL.find(value).expect("the organisation number");
    let start = PAYROLL.get(..at).unwrap_or_default().encode_utf16().count() as u32;
    let drawn = Span { start, end: start + value.encode_utf16().count() as u32 + 2 };
    protect(session, drawn, Scope::Once, Kind::Custom).expect("protect");

    let payload = payload_view(build_payload(session).expect("build")).expect("payload").text;
    let token = payload
        .split_whitespace()
        .find(|word| word.starts_with("__Z_"))
        .expect("a token in the payload")
        .to_string();
    let expected = format!(
        "{}{token}{}",
        PAYROLL.get(..at).unwrap_or_default(),
        PAYROLL.get(at + value.len()..).unwrap_or_default()
    );

    assert_eq!(
        payload, expected,
        "the text that leaves is not the text that arrived with its value replaced: the \
         selection overshot by two characters and the act followed it onto the next line",
    );
    // And the file's own property holds on this case too, now that there is
    // nothing for the two sides to be wrong about together.
    assert_eq!(payload, expected_payload(session), "the core against the core");
}

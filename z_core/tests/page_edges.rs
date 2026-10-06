// 041-L · the two columns show the same pages.
//
// The owner, 6 October, on the published build: «ترتيب الصفحات غير متماثل؛ أعمل
// على الشاشة الأولى ولا أجد عملي في الشاشة الثانية؛ شاشة فيها رقم الصفحات وشاشة
// لا» — one column numbers its pages and the other does not.
//
// The cause is in `payload.rs` and was deliberate: the reader leaves a form feed
// between page and page so the Original column can draw where one falls, and the
// builder turns it into an ordinary line break because a control character is of
// no use to a model. After that the payload has nothing to tell one break from
// any other newline. So the builder now says where they went.
//
// What these tests hold to account is not the drawing — that is Dart's — but the
// one thing that must never move: **the bytes that leave the device.** The last
// test is the control, and it is measured, not asserted from belief.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_dir(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-edges-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
}

/// Three pages, invented, with a person on the first so there is a token to
/// move the offsets that follow it.
const THREE: &str = "Seite eins\n\nKunde: Nordstern Consulting GmbH\n\u{c}Seite zwei\n\nRechnung an Thomas Müller\n\u{c}Seite drei\n\nMit freundlichen Grüßen\n";

/// UTF-16 offset of the nth occurrence of a character, counting from 0.
fn utf16_of(s: &str, needle: char, nth: usize) -> u32 {
    let mut units = 0u32;
    let mut seen = 0usize;
    for ch in s.chars() {
        if ch == needle {
            if seen == nth {
                return units;
            }
            seen += 1;
        }
        units += ch.len_utf16() as u32;
    }
    panic!("{needle:?} does not occur {} times", nth + 1);
}

fn unit_at(s: &str, at: u32) -> u16 {
    s.encode_utf16().nth(at as usize).expect("offset inside the text")
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

fn payload_of(session: SessionId) -> PayloadView {
    let handle = build_payload(session).expect("payload");
    payload_view(handle).expect("view")
}

// ---------------------------------------------------------------- 1

/// Three pages, two edges, and the numbers a person reads.
#[test]
fn a_three_page_document_hands_over_two_edges() {
    let _g = serial();
    fresh_dir("three");
    let s = open_session(None, "de".to_string()).expect("open");
    let view = import_text(s, THREE.to_string()).expect("import");
    assert_eq!(view.pages, 3, "the reader did not see three pages");
    assert_eq!(view.text.matches('\u{c}').count(), 2, "the document keeps its breaks");
    scan(s).expect("scan");

    let payload = payload_of(s);

    // Two boundaries for three pages, numbered for the page they begin.
    assert_eq!(payload.page_edges.len(), 2);
    assert_eq!(payload.page_edges[0].page, 2, "the first edge begins page two");
    assert_eq!(payload.page_edges[1].page, 3);

    // The edge is **the break itself** in the payload: the newline that stands
    // where the form feed stood. If an offset were one out, this is where it
    // would show — and an offset that is one out is the mistake this project
    // will not make twice.
    for edge in &payload.page_edges {
        assert_eq!(
            unit_at(&payload.text, edge.at),
            0x0a,
            "page {} does not begin at a line break",
            edge.page
        );
    }

    // And nothing that leaves carries a control character.
    assert_eq!(
        payload.text.matches('\u{c}').count(),
        0,
        "a form feed travelled to a model"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 2

/// The offsets are the **payload's**, not the document's.
///
/// This is the whole of the task in one assertion: a token is not the same
/// length as the name it replaced, so every edge after it sits somewhere else
/// in the payload than it does in the document. A screen handed the document's
/// offsets would draw its rules in the wrong place, and the more tokens above
/// them the further wrong.
#[test]
fn a_token_moves_every_edge_after_it() {
    let _g = serial();
    fresh_dir("moved");
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, THREE.to_string()).expect("import");
    scan(s).expect("scan");
    // By hand, so the test owns what is protected rather than reading it from
    // whatever the pack decided today.
    protect(s, span_of(THREE, "Nordstern Consulting GmbH"), Scope::Once, Kind::Company)
        .expect("protect the company on page one");

    let payload = payload_of(s);
    assert_eq!(payload.page_edges.len(), 2);

    let token = list_tokens(s)
        .expect("tokens")
        .into_iter()
        .map(|t| t.token)
        .next()
        .expect("one token");
    let grew = token.chars().map(char::len_utf16).sum::<usize>() as i64
        - "Nordstern Consulting GmbH".chars().map(char::len_utf16).sum::<usize>() as i64;
    // Measured, and the direction is not the point: `__Z_XXXX_COMPANY_XXXX__`
    // is 23 units and the company's name is 25, so here the edges move **back**
    // by two. A long name shortens the payload and a short one lengthens it;
    // either way the document's offset is the wrong one to draw with.
    assert_eq!(grew, -2, "the token's length changed, so this test's arithmetic has to be re-measured");

    for (i, edge) in payload.page_edges.iter().enumerate() {
        let in_document = utf16_of(THREE, '\u{c}', i) as i64;
        assert_eq!(
            edge.at as i64,
            in_document + grew,
            "page {} is {} units out in the payload",
            edge.page,
            edge.at as i64 - (in_document + grew)
        );
        assert_eq!(unit_at(&payload.text, edge.at), 0x0a);
    }
    close_session(s).ok();
}

// ---------------------------------------------------------------- 3

/// A protection that swallows a break: the edge is gone, the numbers are not.
///
/// A selection may cross a page boundary, and then the whole stretch leaves as
/// one token and that break is not in the payload at all. The page after it
/// still has the number it has in the document — which is why an edge carries
/// its number rather than its position in the list.
#[test]
fn a_swallowed_break_does_not_renumber_the_pages() {
    let _g = serial();
    fresh_dir("swallowed");
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, THREE.to_string()).expect("import");
    scan(s).expect("scan");

    // One stretch, from before the first break to after it.
    let across = Span {
        start: utf16_of(THREE, '\u{c}', 0) - 6,
        end: utf16_of(THREE, '\u{c}', 0) + 6,
    };
    protect(s, across, Scope::Once, Kind::Custom).expect("protect across the break");

    let payload = payload_of(s);
    assert_eq!(
        payload.page_edges.len(),
        1,
        "the swallowed break is still being reported"
    );
    assert_eq!(
        payload.page_edges[0].page, 3,
        "page three was renumbered to two because an edge above it went"
    );
    assert_eq!(unit_at(&payload.text, payload.page_edges[0].at), 0x0a);
    assert_eq!(payload.text.matches('\u{c}').count(), 0);
    close_session(s).ok();
}

// ---------------------------------------------------------------- 4 · the control

/// Blind the two random groups in every token, keeping its kind and its place.
///
/// A token id is new on every run, so a digest of the raw payload differs from
/// itself — measured: two runs of **identical** code gave two different digests.
/// This leaves every other byte, and every token's position and kind, exactly
/// where they were, and so can answer the only question that matters here.
fn mask_tokens(s: &str) -> String {
    let chars: Vec<char> = s.chars().collect();
    let mut out = String::with_capacity(s.len());
    let mut i = 0usize;
    while i < chars.len() {
        if chars[i..].starts_with(&['_', '_', 'Z', '_']) {
            let rest: String = chars[i..].iter().collect();
            if let Some(end) = rest[4..].find("__") {
                let body = &rest[4..4 + end];
                let parts: Vec<&str> = body.split('_').collect();
                if parts.len() == 3 && parts[0].len() == 4 && parts[2].len() == 4 {
                    out.push_str("__Z_XXXX_");
                    out.push_str(parts[1]);
                    out.push_str("_XXXX__");
                    i += 4 + end + 2;
                    continue;
                }
            }
        }
        out.push(chars[i]);
        i += 1;
    }
    out
}

fn fnv1a(s: &str) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for b in s.as_bytes() {
        h ^= u64::from(*b);
        h = h.wrapping_mul(0x100_0000_01b3);
    }
    h
}

/// **The control: what leaves the device did not move by one byte.**
///
/// Measured on DE-4 (734 pages) on the build **before** 041-L and on this one,
/// with the token ids blinded so the digest is comparable at all:
///
/// ```text
/// before 041-L   len 1618464   masked fnv fdc1d4c0179450cf
/// after  041-L   len 1618464   masked fnv fdc1d4c0179450cf
/// ```
///
/// The numbers below are that measurement, not a hope. If a later change moves
/// them, it changed the outgoing text and has to say so.
#[test]
fn the_payload_is_what_it_was_before_the_edges_were_reported() {
    let _g = serial();
    let path = match std::env::var("ZPRIVACY_THIRD_GOLDEN") {
        Ok(name) => std::path::PathBuf::from(name),
        Err(_) => match std::env::var("HOME") {
            Ok(home) => std::path::PathBuf::from(home).join("Downloads/tysk1.pdf"),
            Err(_) => return,
        },
    };
    if !path.is_file() {
        println!("the third golden is not on this machine — the wire was not measured");
        return;
    }
    fresh_dir("wire");
    let bytes = std::fs::read(&path).expect("the document");
    let s = open_session(None, "de".to_string()).expect("open");
    let view = import_document(s, "tysk1.pdf".to_string(), bytes, DocumentKind::Pdf).expect("import");
    assert_eq!(view.pages, 734);
    scan(s).expect("scan");

    let payload = payload_of(s);
    assert_eq!(payload.text.len(), 1_618_464, "the outgoing text changed length");
    assert_eq!(
        format!("{:016x}", fnv1a(&mask_tokens(&payload.text))),
        "fdc1d4c0179450cf",
        "the outgoing text changed content"
    );
    assert_eq!(payload.text.matches('\u{c}').count(), 0);

    // 734 pages have 733 boundaries, and page one begins where no rule is drawn.
    assert_eq!(payload.page_edges.len(), 733);
    assert_eq!(payload.page_edges[0].page, 2);
    assert_eq!(payload.page_edges[732].page, 734);
    for edge in &payload.page_edges {
        assert_eq!(unit_at(&payload.text, edge.at), 0x0a);
    }
    close_session(s).ok();
}

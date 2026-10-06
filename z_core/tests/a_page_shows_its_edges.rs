// 041-J · «while reviewing, the page must show its beginning and its end».
//
// The owner, 7 October. A PDF of 734 pages arrived as one scroll with no edge
// in it anywhere, so «page 17» was a label on a list and not a place on a page.
//
// The reader puts **one form feed** between page and page. `\f` and not a line
// of dashes: it is the character that has meant «new page» since the
// teleprinter, it is one byte, every reader treats it as whitespace, and a
// PDF's own text never carries one by accident.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// A form feed is whitespace to every rule, so nothing is found across one and
/// nothing is lost beside one.
#[test]
fn a_page_edge_is_whitespace_to_the_scanner() {
    let doc = "Seite eins mit Herr Thomas Müller.\n\u{c}Seite zwei mit Frau Sophie Schneider.\n\u{c}Seite drei: IBAN DE89370400440532013000.\n";
    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    let report = scan(session).expect("scan");
    assert_eq!(report.auto, 3, "the three pages did not all read: {report:?}");

    let units: Vec<u16> = doc.encode_utf16().collect();
    let found: Vec<String> = list_findings(session)
        .expect("findings")
        .into_iter()
        .map(|f| {
            String::from_utf16_lossy(units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default())
        })
        .collect();
    for who in ["Thomas Müller", "Sophie Schneider"] {
        assert!(found.iter().any(|t| t == who), "«{who}» was lost at a page edge: {found:?}");
    }
    // And no finding carries the edge itself.
    assert!(
        found.iter().all(|t| !t.contains('\u{c}')),
        "a page edge was protected as if it were a value: {found:?}"
    );
}

/// The edge is for the person reading, and it does not travel.
#[test]
fn a_page_edge_never_leaves_the_device() {
    let doc = "Seite eins mit Herr Thomas Müller.\n\u{c}Seite zwei mit Frau Sophie Schneider.\n";
    let session = open_session(None, "de".to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let handle = build_payload(session).expect("payload");
    let text = payload_view(handle).expect("view").text;
    assert!(
        !text.contains('\u{c}'),
        "the page edge went to the model: {text:?}"
    );
    // Measured, and worth naming: what stands in its place is a blank line, so
    // the shape of the document survives without the control character.
    assert!(text.contains("\n\n"), "the page edge left nothing at all: {text:?}");
}

/// Three pages, two edges. Counted here so that a reader that stopped putting
/// them in, or started putting two, is caught by a number.
#[test]
fn a_document_of_three_pages_has_two_edges() {
    let doc = "eins\n\u{c}zwei\n\u{c}drei\n";
    let session = open_session(None, "de".to_string()).expect("open");
    let view = import_text(session, doc.to_string()).expect("import");
    assert_eq!(view.text.matches('\u{c}').count(), 2);
}

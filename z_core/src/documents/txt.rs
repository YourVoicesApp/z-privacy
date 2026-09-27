//! Plain text.
//!
//! The simplest reader, and it still refuses rather than guesses: bytes that are
//! not UTF-8 are [`Refusal::UnsupportedEncoding`], not text with holes in it.
//! A form feed (`\f`) is a page break, because that is what it has meant in plain
//! text since printers had paper.

use crate::api::{ApiResult, Refusal};

use super::{refuse, Budget, Builder, Extracted};

pub(crate) fn extract(bytes: &[u8], budget: &Budget) -> ApiResult<Extracted> {
    let text = std::str::from_utf8(strip_bom(bytes)).map_err(|e| {
        refuse(
            // Not a page problem: the whole file is in the wrong encoding.
            Refusal::UnsupportedEncoding {
                page: 0,
                readable_percent: 0,
            },
            format!(
                "this file is not UTF-8 (byte {} is not valid) — save it as UTF-8 and it will read",
                e.valid_up_to()
            ),
        )
    })?;

    let mut out = Builder::new();
    let mut page = 1u32;
    let mut paragraph = 1u32;

    for (index, block) in text.split("\n\n").enumerate() {
        budget.check()?;
        if index > 0 {
            out.push_break("\n\n");
        }
        // A form feed inside a block moves to the next page.
        let mut first = true;
        for piece in block.split('\u{c}') {
            if !first {
                page = page.saturating_add(1);
                paragraph = 1;
                out.push_break("\n");
            }
            first = false;
            out.push(piece, page, paragraph)?;
        }
        paragraph = paragraph.saturating_add(1);
    }
    out.finish()
}

fn strip_bom(bytes: &[u8]) -> &[u8] {
    match bytes.strip_prefix(&[0xEF, 0xBB, 0xBF]) {
        Some(rest) => rest,
        None => bytes,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::{ApiError, Place};

    fn read(text: &[u8]) -> ApiResult<Extracted> {
        extract(text, &Budget::new())
    }

    #[test]
    fn paragraphs_are_counted_and_the_text_is_kept_whole() {
        let doc = "Kunde: Nordstern GmbH\n\nHerr Thomas Müller ruft an.\n\nMit Grüßen";
        let out = read(doc.as_bytes()).expect("read");
        assert_eq!(out.text, doc, "not one character is changed");
        assert_eq!(out.pages, 1);

        let at = out.text.find("Thomas").expect("the name");
        assert_eq!(out.place_of(at), Some(Place { page: 1, paragraph: 2 }));
    }

    #[test]
    fn a_form_feed_turns_the_page() {
        let doc = "Seite eins\n\nnoch eins\u{c}Seite zwei mit Müller";
        let out = read(doc.as_bytes()).expect("read");
        assert_eq!(out.pages, 2);
        let at = out.text.find("Müller").expect("the name");
        assert_eq!(out.place_of(at).map(|p| p.page), Some(2));
    }

    #[test]
    fn a_byte_order_mark_is_not_part_of_the_text() {
        let mut doc = vec![0xEF, 0xBB, 0xBF];
        doc.extend_from_slice("Kunde: Nordstern".as_bytes());
        let out = read(&doc).expect("read");
        assert!(out.text.starts_with("Kunde"), "{:?}", out.text);
    }

    #[test]
    fn bytes_that_are_not_utf8_are_refused_by_name() {
        // Latin-1 «Müller» — a real case from an old export.
        let latin1 = [b'M', 0xFC, b'l', b'l', b'e', b'r'];
        match read(&latin1) {
            Err(ApiError::DocumentRefused { reason, detail }) => {
                assert!(matches!(reason, Refusal::UnsupportedEncoding { .. }), "{reason:?}");
                assert!(detail.contains("UTF-8"), "{detail}");
            }
            other => panic!("expected a refusal, got {other:?}"),
        }
    }
}

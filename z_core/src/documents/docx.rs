//! DOCX: a zip with one XML part that holds the words.
//!
//! The reader walks `word/document.xml` looking for three things and ignoring
//! everything else: `<w:p>` starts a paragraph, `<w:t>` holds text, and a page
//! break moves the page on. No XML library: the shape being looked for is small,
//! and a tolerant scan cannot be tripped by parts of the format we do not read.
//!
//! One honest limit, written here so nobody has to discover it: **a DOCX has no
//! real pages.** Word decides them when it lays the document out. So `page`
//! counts *explicit* breaks — the ones a person inserted — and `paragraph` is
//! exact. For a document with no manual breaks, everything is page 1, and the
//! paragraph number is what Review should jump to.

use crate::api::{ApiResult, Refusal};

use super::{refuse, zip, Budget, Builder, Extracted};

const PART: &str = "word/document.xml";

pub(crate) fn extract(bytes: &[u8], budget: &Budget) -> ApiResult<Extracted> {
    let part = zip::read_entry(bytes, PART)?.ok_or_else(|| {
        refuse(
            Refusal::MalformedDocument,
            format!("this file is a zip but has no {PART}, so it is not a Word document"),
        )
    })?;
    budget.check()?;
    let xml = String::from_utf8(part).map_err(|_| {
        refuse(
            Refusal::UnsupportedEncoding {
                page: 0,
                readable_percent: 0,
            },
            format!("{PART} is not UTF-8, which every DOCX is supposed to be"),
        )
    })?;
    read_xml(&xml, budget)
}

/// The scan. Every branch here answers one question: does this tag carry words,
/// end a paragraph, or turn the page?
fn read_xml(xml: &str, budget: &Budget) -> ApiResult<Extracted> {
    let mut out = Builder::new();
    let mut page = 1u32;
    let mut paragraph = 0u32;
    let mut in_text = false;
    let mut pending = String::new();
    let mut first_paragraph = true;

    let bytes = xml.as_bytes();
    let mut at = 0usize;
    let mut checked = 0usize;

    while at < bytes.len() {
        // The clock is checked every few thousand tags, not every byte.
        if at - checked > 50_000 {
            budget.check()?;
            checked = at;
        }
        match bytes.get(at) {
            Some(b'<') => {
                let end = match xml.get(at..).and_then(|rest| rest.find('>')) {
                    Some(found) => at + found,
                    None => break, // a tag that never closes: stop, keep what we have
                };
                let tag = xml.get(at + 1..end).unwrap_or_default();
                let name = tag_name(tag);

                match name {
                    "w:p" => {
                        if !first_paragraph {
                            out.push_break("\n\n");
                        }
                        first_paragraph = false;
                        paragraph = paragraph.saturating_add(1);
                    }
                    "w:t" => {
                        in_text = !tag.ends_with('/');
                        pending.clear();
                    }
                    "/w:t" => {
                        if in_text {
                            out.push(&decode_entities(&pending), page, paragraph.max(1))?;
                            pending.clear();
                        }
                        in_text = false;
                    }
                    "w:tab" => out.push_break("\t"),
                    "w:br" | "w:lastRenderedPageBreak" => {
                        if name == "w:lastRenderedPageBreak" || tag.contains("w:type=\"page\"") {
                            page = page.saturating_add(1);
                            out.push_break("\n");
                        } else {
                            out.push_break("\n");
                        }
                    }
                    _ => {}
                }
                at = end + 1;
            }
            Some(_) => {
                let next = match xml.get(at..).and_then(|rest| rest.find('<')) {
                    Some(found) => at + found,
                    None => bytes.len(),
                };
                if in_text {
                    pending.push_str(xml.get(at..next).unwrap_or_default());
                }
                at = next;
            }
            None => break,
        }
    }
    out.finish()
}

/// `w:t xml:space="preserve"` → `w:t`, and `w:br/` → `w:br`.
fn tag_name(tag: &str) -> &str {
    let cut = tag
        .find(|c: char| c.is_whitespace() || c == '/')
        .unwrap_or(tag.len());
    // A closing tag keeps its slash, so «/w:t» is distinguishable.
    if tag.starts_with('/') {
        let inner = tag.get(1..).unwrap_or_default();
        let inner_cut = inner
            .find(|c: char| c.is_whitespace() || c == '/')
            .unwrap_or(inner.len());
        return tag.get(..inner_cut + 1).unwrap_or_default();
    }
    tag.get(..cut).unwrap_or_default()
}

/// The five XML entities, and numeric ones. Anything else is left as written.
fn decode_entities(text: &str) -> String {
    if !text.contains('&') {
        return text.to_string();
    }
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    while let Some(at) = rest.find('&') {
        out.push_str(rest.get(..at).unwrap_or_default());
        let tail = rest.get(at..).unwrap_or_default();
        let Some(semi) = tail.find(';') else {
            out.push('&');
            rest = rest.get(at + 1..).unwrap_or_default();
            continue;
        };
        let name = tail.get(1..semi).unwrap_or_default();
        match name {
            "amp" => out.push('&'),
            "lt" => out.push('<'),
            "gt" => out.push('>'),
            "quot" => out.push('"'),
            "apos" => out.push('\''),
            numeric if numeric.starts_with('#') => {
                let (radix, digits) = match numeric.strip_prefix("#x").or(numeric.strip_prefix("#X")) {
                    Some(hex) => (16, hex),
                    None => (10, numeric.get(1..).unwrap_or_default()),
                };
                match u32::from_str_radix(digits, radix).ok().and_then(char::from_u32) {
                    Some(c) => out.push(c),
                    None => out.push_str(tail.get(..=semi).unwrap_or_default()),
                }
            }
            _ => out.push_str(tail.get(..=semi).unwrap_or_default()),
        }
        rest = tail.get(semi + 1..).unwrap_or_default();
    }
    out.push_str(rest);
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::{ApiError, Place};

    /// A DOCX as Word writes one, cut down to what a reader needs.
    fn docx(body: &str) -> Vec<u8> {
        let xml = format!(
            r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>{body}</w:body></w:document>"#
        );
        super::zip::tests::zip_with(PART, xml.as_bytes(), true)
    }

    fn para(text: &str) -> String {
        format!(r#"<w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">{text}</w:t></w:r></w:p>"#)
    }

    #[test]
    fn the_words_come_out_and_the_markup_does_not() {
        let file = docx(&format!("{}{}", para("Kunde: Nordstern Consulting GmbH"), para("Herr Thomas Müller")));
        let out = extract(&file, &Budget::new()).expect("read");
        assert_eq!(out.text, "Kunde: Nordstern Consulting GmbH\n\nHerr Thomas Müller");
        assert!(!out.text.contains("w:"), "no markup leaked into the text");
    }

    #[test]
    fn paragraphs_are_numbered_so_review_can_jump() {
        let file = docx(&format!("{}{}{}", para("eins"), para("zwei"), para("Herr Thomas Müller")));
        let out = extract(&file, &Budget::new()).expect("read");
        let at = out.text.find("Thomas").expect("the name");
        assert_eq!(out.place_of(at), Some(Place { page: 1, paragraph: 3 }));
    }

    #[test]
    fn an_explicit_page_break_turns_the_page() {
        let file = docx(&format!(
            "{}{}{}",
            para("Seite eins"),
            r#"<w:p><w:r><w:br w:type="page"/></w:r></w:p>"#,
            para("Müller auf Seite zwei")
        ));
        let out = extract(&file, &Budget::new()).expect("read");
        assert_eq!(out.pages, 2);
        let at = out.text.find("Müller").expect("the name");
        assert_eq!(out.place_of(at).map(|p| p.page), Some(2));
    }

    #[test]
    fn entities_and_tabs_read_as_written() {
        let file = docx(&para("M&#252;ller &amp; S&#xF6;hne<w:tab/>GmbH"));
        let out = extract(&file, &Budget::new()).expect("read");
        assert!(out.text.contains("Müller & Söhne"), "{:?}", out.text);
    }

    #[test]
    fn a_zip_without_a_word_part_is_refused_by_name() {
        let file = super::zip::tests::zip_with("other.xml", b"<x/>", false);
        match extract(&file, &Budget::new()) {
            Err(ApiError::DocumentRefused { reason, detail }) => {
                assert_eq!(reason, Refusal::MalformedDocument);
                assert!(detail.contains("Word"), "{detail}");
            }
            other => panic!("expected a refusal, got {other:?}"),
        }
    }

    #[test]
    fn a_docx_with_no_words_is_refused_not_imported_empty() {
        let file = docx(&para("   "));
        match extract(&file, &Budget::new()) {
            Err(ApiError::DocumentRefused { reason, .. }) => assert_eq!(reason, Refusal::EmptyDocument),
            other => panic!("expected a refusal, got {other:?}"),
        }
    }
}

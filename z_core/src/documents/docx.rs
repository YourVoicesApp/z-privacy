//! DOCX: a zip with one XML part that holds the words.
//!
//! The reader walks `word/document.xml` looking for three things and ignoring
//! everything else: `<w:p>` starts a paragraph, `<w:t>` holds text, and a page
//! break moves the page on. The XML is still parsed as XML, not as a tolerant
//! byte scan: if the document part is truncated or not well-formed, the whole
//! DOCX is refused rather than returning partial text.
//!
//! One honest limit, written here so nobody has to discover it: **a DOCX has no
//! real pages.** Word decides them when it lays the document out. So `page`
//! counts *explicit* breaks — the ones a person inserted — and `paragraph` is
//! exact. For a document with no manual breaks, everything is page 1, and the
//! paragraph number is what Review should jump to.

use crate::api::{ApiResult, Refusal};
use quick_xml::escape::resolve_xml_entity;
use quick_xml::events::{BytesRef, BytesStart, Event};
use quick_xml::Reader;

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
    let mut reader = Reader::from_str(xml);
    {
        let cfg = reader.config_mut();
        cfg.trim_text(false);
        cfg.enable_all_checks(true);
    }

    let mut out = Builder::new();
    let mut page = 1u32;
    let mut paragraph = 0u32;
    let mut in_text = false;
    let mut pending = String::new();
    let mut first_paragraph = true;
    let mut opened: Vec<Vec<u8>> = Vec::new();
    let mut checked = 0u64;

    loop {
        // The clock is checked every few thousand tags, not every byte.
        let at = reader.buffer_position();
        if at.saturating_sub(checked) > 50_000 {
            budget.check()?;
            checked = at;
        }

        match reader.read_event() {
            Ok(Event::Start(tag)) => {
                opened.push(tag.name().as_ref().to_vec());
                start_tag(
                    &tag,
                    &mut out,
                    &mut page,
                    &mut paragraph,
                    &mut in_text,
                    &mut pending,
                    &mut first_paragraph,
                )?;
            }
            Ok(Event::Empty(tag)) => {
                empty_tag(
                    &tag,
                    &mut out,
                    &mut page,
                    &mut paragraph,
                    &mut pending,
                    &mut first_paragraph,
                )?;
            }
            Ok(Event::End(tag)) => {
                let name = tag.name().as_ref().to_vec();
                let Some(expected) = opened.pop() else {
                    return Err(malformed("an element ended before one was opened"));
                };
                if expected != name {
                    return Err(malformed(format!(
                        "closing tag </{}> does not match <{}>",
                        String::from_utf8_lossy(&name),
                        String::from_utf8_lossy(&expected)
                    )));
                }
                if name == b"w:t" {
                    flush_text(&mut out, &mut pending, page, paragraph)?;
                    in_text = false;
                }
            }
            Ok(Event::Text(text)) => {
                if in_text {
                    let decoded = text.xml_content().map_err(|e| malformed(e.to_string()))?;
                    pending.push_str(&decoded);
                }
            }
            Ok(Event::CData(text)) => {
                if in_text {
                    let decoded = text.xml_content().map_err(|e| malformed(e.to_string()))?;
                    pending.push_str(&decoded);
                }
            }
            Ok(Event::GeneralRef(r)) => {
                if in_text {
                    append_ref(&mut pending, &r)?;
                }
            }
            Ok(Event::Eof) => {
                if let Some(unclosed) = opened.last() {
                    return Err(malformed(format!(
                        "unclosed tag <{}>",
                        String::from_utf8_lossy(unclosed)
                    )));
                }
                break;
            }
            Ok(Event::Decl(_)) | Ok(Event::PI(_)) | Ok(Event::Comment(_)) | Ok(Event::DocType(_)) => {}
            Err(e) => return Err(malformed(e.to_string())),
        }
    }
    out.finish()
}

fn start_tag(
    tag: &BytesStart<'_>,
    out: &mut Builder,
    page: &mut u32,
    paragraph: &mut u32,
    in_text: &mut bool,
    pending: &mut String,
    first_paragraph: &mut bool,
) -> ApiResult<()> {
    match tag.name().as_ref() {
        b"w:p" => open_paragraph(out, paragraph, first_paragraph),
        b"w:t" => {
            *in_text = true;
            pending.clear();
        }
        b"w:br" | b"w:lastRenderedPageBreak" => break_tag(tag, out, page, *paragraph, pending)?,
        _ => {}
    }
    Ok(())
}

fn empty_tag(
    tag: &BytesStart<'_>,
    out: &mut Builder,
    page: &mut u32,
    paragraph: &mut u32,
    pending: &mut String,
    first_paragraph: &mut bool,
) -> ApiResult<()> {
    match tag.name().as_ref() {
        b"w:p" => open_paragraph(out, paragraph, first_paragraph),
        b"w:tab" => {
            flush_text(out, pending, *page, *paragraph)?;
            out.push_break("\t");
        }
        b"w:br" | b"w:lastRenderedPageBreak" => break_tag(tag, out, page, *paragraph, pending)?,
        _ => {}
    }
    Ok(())
}

fn open_paragraph(out: &mut Builder, paragraph: &mut u32, first_paragraph: &mut bool) {
    if !*first_paragraph {
        out.push_break("\n\n");
    }
    *first_paragraph = false;
    *paragraph = paragraph.saturating_add(1);
}

fn break_tag(
    tag: &BytesStart<'_>,
    out: &mut Builder,
    page: &mut u32,
    paragraph: u32,
    pending: &mut String,
) -> ApiResult<()> {
    flush_text(out, pending, *page, paragraph)?;
    if tag.name().as_ref() == b"w:lastRenderedPageBreak" || is_page_break(tag)? {
        *page = page.saturating_add(1);
    }
    out.push_break("\n");
    Ok(())
}

fn is_page_break(tag: &BytesStart<'_>) -> ApiResult<bool> {
    for attr in tag.attributes() {
        let attr = attr.map_err(|e| malformed(e.to_string()))?;
        if attr.key.as_ref() == b"w:type" {
            let value = attr
                .decode_and_unescape_value(tag.decoder())
                .map_err(|e| malformed(e.to_string()))?;
            return Ok(value.as_ref() == "page");
        }
    }
    Ok(false)
}

fn flush_text(out: &mut Builder, pending: &mut String, page: u32, paragraph: u32) -> ApiResult<()> {
    if !pending.is_empty() {
        out.push(pending, page, paragraph.max(1))?;
        pending.clear();
    }
    Ok(())
}

/// Predefined XML entities and numeric character references only. Anything else
/// is a named refusal: a DOCX is not allowed to invent entities, and an
/// unterminated `&` is not well-formed.
fn append_ref(pending: &mut String, r: &BytesRef<'_>) -> ApiResult<()> {
    if let Some(ch) = r.resolve_char_ref().map_err(|e| malformed(e.to_string()))? {
        pending.push(ch);
        return Ok(());
    }
    let name = r.decode().map_err(|e| malformed(e.to_string()))?;
    match resolve_xml_entity(&name) {
        Some(s) => {
            pending.push_str(s);
            Ok(())
        }
        None => Err(malformed(format!("unknown entity &{name};"))),
    }
}

fn malformed(detail: impl Into<String>) -> crate::api::ApiError {
    refuse(
        Refusal::MalformedDocument,
        format!("{PART} is not well-formed XML: {}", detail.into()),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::{ApiError, Place};

    /// A DOCX as Word writes one, cut down to what a reader needs.
    fn docx(body: &str) -> Vec<u8> {
        zip_xml(&wrap_body(body), true)
    }

    fn wrap_body(body: &str) -> String {
        format!(
            r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>{body}</w:body></w:document>"#
        )
    }

    fn zip_xml(xml: &str, deflate: bool) -> Vec<u8> {
        super::zip::tests::zip_with(PART, xml.as_bytes(), deflate)
    }

    fn para(text: &str) -> String {
        format!(
            r#"<w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">{text}</w:t></w:r></w:p>"#
        )
    }

    fn assert_malformed(file: &[u8]) {
        match extract(file, &Budget::new()) {
            Err(ApiError::DocumentRefused { reason, .. }) => {
                assert_eq!(reason, Refusal::MalformedDocument);
            }
            Ok(out) => panic!("expected MalformedDocument, got partial text {:?}", out.text),
            other => panic!("expected MalformedDocument, got {other:?}"),
        }
    }

    #[test]
    fn the_words_come_out_and_the_markup_does_not() {
        let file = docx(&format!(
            "{}{}",
            para("Kunde: Nordstern Consulting GmbH"),
            para("Herr Thomas Müller")
        ));
        let out = extract(&file, &Budget::new()).expect("read");
        assert_eq!(out.text, "Kunde: Nordstern Consulting GmbH\n\nHerr Thomas Müller");
        assert!(!out.text.contains("w:"), "no markup leaked into the text");
    }

    #[test]
    fn paragraphs_are_numbered_so_review_can_jump() {
        let file = docx(&format!(
            "{}{}{}",
            para("eins"),
            para("zwei"),
            para("Herr Thomas Müller")
        ));
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
        assert!(out.text.contains('\t'), "{:?}", out.text);
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

    #[test]
    fn an_unclosed_tag_is_malformed_not_partially_read() {
        // Well-started document.xml whose last open element never closes.
        let xml = concat!(
            r#"<?xml version="1.0" encoding="UTF-8"?>"#,
            r#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">"#,
            r#"<w:body><w:p><w:t>ZXQ-DOCX-PARTIAL-77220</w:t></w:p></w:body>"#,
        );
        assert_malformed(&zip_xml(xml, false));
    }

    #[test]
    fn a_document_truncated_mid_element_is_malformed() {
        let xml = concat!(
            r#"<?xml version="1.0" encoding="UTF-8"?>"#,
            r#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">"#,
            r#"<w:body><w:p><w:t>ZXQ-DOCX-PARTIAL-77220"#,
        );
        assert_malformed(&zip_xml(xml, false));
    }

    #[test]
    fn a_document_truncated_after_visible_text_is_malformed() {
        // The red-team shape: document.xml starts correctly, visible text is
        // already there, then the file is cut. Returning that text as Ok is the
        // bug; the whole DOCX must be refused.
        let xml = concat!(
            r#"<?xml version="1.0" encoding="UTF-8"?>"#,
            r#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">"#,
            r#"<w:body><w:p><w:t>ZXQ-DOCX-PARTIAL-77220</w:t></w:p><unclosed"#,
        );
        match extract(&zip_xml(xml, false), &Budget::new()) {
            Err(ApiError::DocumentRefused { reason, .. }) => {
                assert_eq!(reason, Refusal::MalformedDocument);
            }
            Ok(out) => panic!("must not return a partial DocumentView, got {:?}", out.text),
            other => panic!("expected MalformedDocument, got {other:?}"),
        }
    }

    #[test]
    fn a_broken_entity_is_malformed() {
        let unknown = wrap_body(&para("hello &notanentity;"));
        assert_malformed(&zip_xml(&unknown, false));

        let unterminated = wrap_body(&para("hello &amp"));
        assert_malformed(&zip_xml(&unterminated, false));
    }

    #[test]
    fn a_mismatched_closing_tag_is_malformed() {
        let xml = concat!(
            r#"<?xml version="1.0" encoding="UTF-8"?>"#,
            r#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">"#,
            r#"<w:body><w:p><w:t>hello</w:p></w:t></w:body></w:document>"#,
        );
        assert_malformed(&zip_xml(xml, false));
    }
}

// The journey the owner asked for, as close to real use as a test can be:
//
//   a twenty-page document → import → extract with page mapping → scan →
//   vault + German pack → build_payload → no real name in the payload
//
// and then the question that matters for the interface: a finding on page 17 must
// still say **page 17** after everything around it has been replaced — not an
// offset into one enormous string.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für die Reise";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// A PDF of `lines.len()` pages, one line of text per page, uncompressed.
///
/// Written here by hand so that the reader is tested against bytes laid out the
/// way a PDF writer lays them out, not against its own idea of a file.
fn pdf_of(lines: &[String]) -> Vec<u8> {
    let mut out = String::from("%PDF-1.4\n");
    let count = lines.len();
    let kids: Vec<String> = (0..count).map(|i| format!("{} 0 R", 3 + i * 2)).collect();
    out.push_str("1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
    out.push_str(&format!(
        "2 0 obj\n<< /Type/Pages /Count {count} /Kids[{}] >>\nendobj\n",
        kids.join(" ")
    ));
    for (index, line) in lines.iter().enumerate() {
        let page_id = 3 + index * 2;
        let content_id = page_id + 1;
        out.push_str(&format!(
            "{page_id} 0 obj\n<< /Type/Page /Parent 2 0 R /Contents {content_id} 0 R /Resources << /Font << /F1 100 0 R >> >> >>\nendobj\n"
        ));
        let stream = format!("BT /F1 12 Tf 72 700 Td ({line}) Tj ET");
        out.push_str(&format!(
            "{content_id} 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n",
            stream.len()
        ));
    }
    out.push_str("100 0 obj\n<< /Type/Font /Subtype/Type1 /BaseFont/Helvetica >>\nendobj\n");
    out.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");
    out.into_bytes()
}

/// Twenty pages of ordinary contract prose, with the things that matter placed on
/// purpose: the client on page 1, the bank details on page 3, and the contact on
/// **page 17**.
fn twenty_pages() -> Vec<String> {
    let mut pages = Vec::new();
    for page in 1..=20u32 {
        let line = match page {
            1 => "Kunde: Nordstern Consulting GmbH — Rahmenvertrag 2026".to_string(),
            3 => "IBAN: DE89 3704 0044 0532 0130 00 und Kundennummer: 41-88203".to_string(),
            17 => "Ansprechpartner: Herr Thomas Müller, erreichbar unter +49 171 2345678".to_string(),
            other => format!(
                "Seite {other}: die Lieferfristen und Zahlungsbedingungen bleiben unveraendert."
            ),
        };
        pages.push(line);
    }
    pages
}

fn fresh_vault(name: &str) {
    let dir = std::env::temp_dir().join(format!("zprivacy-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    if vault_state().expect("state") == VaultState::Absent {
        vault_create_with_passphrase(PASS.to_string()).expect("create");
    }
}

#[test]
fn a_twenty_page_document_walks_the_whole_journey() {
    let _guard = serial();
    fresh_vault("journey");

    // The vault knows this client's contact by name — the fourth layer.
    let profile = create_profile("Client Nordstern".to_string()).expect("profile");
    let contact = create_entity(EntityKind::Person, "Kontakt Nordstern".to_string(), Some(profile.clone()))
        .expect("entity");
    let value = set_value(contact, None, Kind::Person, "Thomas Müller".to_string(), Policy::Always)
        .expect("value");
    add_value_alias(contact, value, "Herr Müller".to_string()).expect("alias");

    let pdf = pdf_of(&twenty_pages());
    let session = open_session(Some(profile), "de".to_string()).expect("open");

    // 1. Import: read here, from bytes, with pages counted.
    let view = import_document(session, "Vertrag_20_Seiten.pdf".to_string(), pdf, DocumentKind::Pdf)
        .expect("import");
    assert_eq!(view.pages, 20, "twenty pages came in as twenty");
    assert_eq!(view.name, "Vertrag_20_Seiten.pdf");
    assert_eq!(view.kind, DocumentKind::Pdf);

    // 2. Scan: three layers over a document nobody has touched.
    let report = scan(session).expect("scan");
    assert_eq!(report.vault, VaultState::Unlocked);
    assert!(report.auto >= 4, "the bank details, the number and the contact: {report:?}");
    assert!(
        report.by_layer.iter().any(|l| l.source == Source::Vault),
        "the vault took part: {:?}",
        report.by_layer
    );

    // 3. The question for the interface: where is the contact?
    let findings = list_findings(session).expect("findings");
    let person = findings
        .iter()
        .find(|f| f.kind == Kind::Person)
        .expect("the contact was found");
    assert_eq!(person.state, MarkState::Protected, "the vault knew him, so he is protected");
    assert_eq!(
        person.place.map(|p| p.page),
        Some(17),
        "a finding must know its page, not just an offset: {:?}",
        person.place
    );
    assert_eq!(person.entities.len(), 1, "and which identity it belongs to");

    let iban = findings
        .iter()
        .find(|f| f.kind == Kind::Iban)
        .expect("the account was found");
    assert_eq!(iban.place.map(|p| p.page), Some(3));

    // 4. The payload: nothing real left in it.
    let handle = build_payload(session).expect("build");
    let safe = payload_view(handle).expect("view").text;
    for secret in [
        "Thomas Müller",
        "DE89 3704 0044 0532 0130 00",
        "41-88203",
        "+49 171 2345678",
    ] {
        assert!(!safe.contains(secret), "«{secret}» is still in the payload");
    }
    // The ordinary prose of page 9 is untouched: only what was found is replaced.
    assert!(safe.contains("Seite 9"), "the rest of the document went as written");

    // 5. And after all that replacing, the place is still the place.
    let after = list_findings(session).expect("findings");
    let person_again = after
        .iter()
        .find(|f| f.kind == Kind::Person)
        .expect("still there");
    assert_eq!(
        person_again.place.map(|p| p.page),
        Some(17),
        "page 17 is still page 17 after protection"
    );
    let marks = document_view(session).expect("view").marks;
    assert!(
        marks.iter().any(|m| m.place.map(|p| p.page) == Some(17)),
        "and the mark on the left-hand side knows it too"
    );

    close_session(session).expect("close");
}

#[test]
fn twenty_scanned_pages_are_refused_and_that_is_the_success() {
    let _guard = serial();
    fresh_vault("scanned");

    // Twenty pages that hold an image and no text layer at all.
    let mut pdf = String::from("%PDF-1.4\n");
    let kids: Vec<String> = (0..20).map(|i| format!("{} 0 R", 3 + i * 2)).collect();
    pdf.push_str("1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
    pdf.push_str(&format!(
        "2 0 obj\n<< /Type/Pages /Count 20 /Kids[{}] >>\nendobj\n",
        kids.join(" ")
    ));
    for index in 0..20 {
        let page_id = 3 + index * 2;
        let content_id = page_id + 1;
        pdf.push_str(&format!(
            "{page_id} 0 obj\n<< /Type/Page /Parent 2 0 R /Contents {content_id} 0 R /Resources << /XObject << /Im1 200 0 R >> >> >>\nendobj\n"
        ));
        let stream = "q 595 0 0 842 0 0 cm /Im1 Do Q";
        pdf.push_str(&format!(
            "{content_id} 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n",
            stream.len()
        ));
    }
    pdf.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");

    let session = open_session(None, "de".to_string()).expect("open");
    match import_document(session, "Scan.pdf".to_string(), pdf.into_bytes(), DocumentKind::Pdf) {
        Err(ApiError::DocumentRefused { reason, detail }) => {
            assert_eq!(reason, Refusal::ScannedPdfNoTextLayer { pages: 20 }, "and it counted them");
            assert!(detail.contains("20 pages"), "{detail}");
            assert!(detail.contains("scan"), "and it says what it thinks this is: {detail}");
        }
        other => panic!("a scan must be refused, not imported: {other:?}"),
    }
    // And nothing was half-imported: the session is as empty as it was.
    assert!(matches!(build_payload(session), Err(ApiError::NothingToSend)));
    close_session(session).expect("close");
}

#[test]
fn the_document_that_was_refused_leaves_no_trace_on_disk() {
    let _guard = serial();
    fresh_vault("no-trace");
    // G15, as a test rather than a promise: reading a document writes nothing.
    // The only file the core may write is the sealed vault.
    let dir = std::env::temp_dir().join(format!("zprivacy-no-trace-{}", std::process::id()));
    let before: Vec<String> = std::fs::read_dir(&dir)
        .map(|entries| {
            entries
                .filter_map(|e| e.ok())
                .map(|e| e.file_name().to_string_lossy().to_string())
                .collect()
        })
        .unwrap_or_default();

    let session = open_session(None, "de".to_string()).expect("open");
    let pdf = pdf_of(&twenty_pages());
    import_document(session, "Vertrag.pdf".to_string(), pdf, DocumentKind::Pdf).expect("import");
    scan(session).expect("scan");
    build_payload(session).expect("build");

    let after: Vec<String> = std::fs::read_dir(&dir)
        .map(|entries| {
            entries
                .filter_map(|e| e.ok())
                .map(|e| e.file_name().to_string_lossy().to_string())
                .collect()
        })
        .unwrap_or_default();
    assert_eq!(before, after, "reading a document must write nothing at all");
    close_session(session).expect("close");
}

#[test]
fn a_docx_journey_keeps_its_paragraph_numbers() {
    let _guard = serial();
    fresh_vault("docx");

    // A DOCX has no pages of its own, so the promise there is the paragraph.
    let mut body = String::new();
    for i in 1..=12 {
        let text = if i == 9 {
            "Ansprechpartner: Herr Thomas Müller, IBAN: DE89 3704 0044 0532 0130 00".to_string()
        } else {
            format!("Absatz {i}: die Bedingungen bleiben unveraendert.")
        };
        body.push_str(&format!(
            r#"<w:p><w:r><w:t xml:space="preserve">{text}</w:t></w:r></w:p>"#
        ));
    }
    let xml = format!(
        r#"<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="x"><w:body>{body}</w:body></w:document>"#
    );
    let docx = zip_one("word/document.xml", xml.as_bytes());

    let session = open_session(None, "de".to_string()).expect("open");
    let view = import_document(session, "Vertrag.docx".to_string(), docx, DocumentKind::Docx)
        .expect("import");
    assert_eq!(view.kind, DocumentKind::Docx);
    scan(session).expect("scan");

    let iban = list_findings(session)
        .expect("findings")
        .into_iter()
        .find(|f| f.kind == Kind::Iban)
        .expect("the account");
    assert_eq!(iban.place.map(|p| p.paragraph), Some(9), "paragraph nine, exactly");
    assert_eq!(iban.place.map(|p| p.page), Some(1), "and page one, honestly");

    let safe = payload_view(build_payload(session).expect("build")).expect("view").text;
    assert!(!safe.contains("DE89 3704"), "the account did not go out");
    close_session(session).expect("close");
}

/// F-07: a truncated document.xml must not install a half-read document.
#[test]
fn a_malformed_docx_does_not_install_a_partial_document() {
    let _guard = serial();

    let session = open_session(None, "de".to_string()).expect("open");
    let before = document_view(session).expect("view");
    let before_rev = session_revision(session).expect("rev");
    assert!(before.text.is_empty(), "a new session has no document");

    match import_document(
        session,
        "malformed.docx".to_string(),
        malformed_docx_bytes(),
        DocumentKind::Docx,
    ) {
        Err(ApiError::DocumentRefused { reason, .. }) => {
            assert_eq!(reason, Refusal::MalformedDocument);
        }
        Ok(view) => panic!(
            "must not return a DocumentView, got {} bytes named {:?}",
            view.text.len(),
            view.name
        ),
        other => panic!("expected MalformedDocument, got {other:?}"),
    }

    let after = document_view(session).expect("view after refusal");
    assert_eq!(after.text, before.text);
    assert_eq!(after.name, before.name);
    assert!(!after.text.contains("ZXQ-DOCX-PARTIAL-77220"));
    assert_eq!(session_revision(session).expect("rev").n, before_rev.n);
    close_session(session).expect("close");
}

/// The same refusal must not replace a document that was already in the session.
#[test]
fn a_malformed_docx_leaves_the_current_document_untouched() {
    let _guard = serial();

    let session = open_session(None, "de".to_string()).expect("open");
    let kept = import_text(session, "Kunde: Nordstern Consulting GmbH".to_string()).expect("import");
    let kept_rev = session_revision(session).expect("rev");

    match import_document(
        session,
        "malformed.docx".to_string(),
        malformed_docx_bytes(),
        DocumentKind::Docx,
    ) {
        Err(ApiError::DocumentRefused { reason, .. }) => {
            assert_eq!(reason, Refusal::MalformedDocument);
        }
        Ok(view) => panic!("must not return a DocumentView, got {} bytes", view.text.len()),
        other => panic!("expected MalformedDocument, got {other:?}"),
    }

    let after = document_view(session).expect("view after refusal");
    assert_eq!(after.text, kept.text);
    assert_eq!(after.name, kept.name);
    assert_eq!(after.kind, kept.kind);
    assert!(!after.text.contains("ZXQ-DOCX-PARTIAL-77220"));
    assert_eq!(session_revision(session).expect("rev").n, kept_rev.n);
    close_session(session).expect("close");
}

/// The red-team fixture when it is on disk; otherwise the same XML reconstructed.
fn malformed_docx_bytes() -> Vec<u8> {
    let path = std::path::Path::new("/home/monopeaks/zprivacy-redteam-2026-09-28/harness/malformed.docx");
    if let Ok(bytes) = std::fs::read(path) {
        return bytes;
    }
    let xml = concat!(
        r#"<?xml version="1.0" encoding="UTF-8"?>"#,
        r#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">"#,
        r#"<w:body><w:p><w:t>ZXQ-DOCX-PARTIAL-77220</w:t></w:p><unclosed"#,
    );
    zip_one("word/document.xml", xml.as_bytes())
}

/// A one-entry zip, stored uncompressed — enough to be a DOCX.
fn zip_one(name: &str, content: &[u8]) -> Vec<u8> {
    let crc = crc32(content);
    let mut out = Vec::new();
    out.extend_from_slice(&0x0403_4b50u32.to_le_bytes());
    out.extend_from_slice(&20u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes()); // stored
    out.extend_from_slice(&0u32.to_le_bytes());
    out.extend_from_slice(&crc.to_le_bytes());
    out.extend_from_slice(&(content.len() as u32).to_le_bytes());
    out.extend_from_slice(&(content.len() as u32).to_le_bytes());
    out.extend_from_slice(&(name.len() as u16).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(name.as_bytes());
    out.extend_from_slice(content);

    let central_at = out.len();
    out.extend_from_slice(&0x0201_4b50u32.to_le_bytes());
    out.extend_from_slice(&20u16.to_le_bytes());
    out.extend_from_slice(&20u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes());
    out.extend_from_slice(&crc.to_le_bytes());
    out.extend_from_slice(&(content.len() as u32).to_le_bytes());
    out.extend_from_slice(&(content.len() as u32).to_le_bytes());
    out.extend_from_slice(&(name.len() as u16).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes());
    out.extend_from_slice(name.as_bytes());

    let central_size = out.len() - central_at;
    out.extend_from_slice(&0x0605_4b50u32.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes());
    out.extend_from_slice(&(central_size as u32).to_le_bytes());
    out.extend_from_slice(&(central_at as u32).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out
}

fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xFFFF_FFFFu32;
    for byte in data {
        crc ^= u32::from(*byte);
        for _ in 0..8 {
            let mask = if crc & 1 == 1 { 0xEDB8_8320 } else { 0 };
            crc = (crc >> 1) ^ mask;
        }
    }
    !crc
}

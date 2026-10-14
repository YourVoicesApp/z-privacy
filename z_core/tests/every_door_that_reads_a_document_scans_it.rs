// **A document arrives scanned, through every door it can arrive by** — the
// detection round of 14 October, item 3.
//
// `import_text` and `import_document` installed the text, cleared the findings,
// wrote `ScanOrigin::NotScanned` and returned. So:
//
// * `list_findings` right after an import was empty, and the review a person
//   opens on their first press had nothing in it;
// * a value the vault already knows — taught once, `Policy::Always`, never to
//   be asked about again — was not protected, because the layer that puts it
//   back runs inside the scan;
// * and a test that imported and then answered findings answered nothing.
//   `the_session_remembers_its_three` claimed «a bench with one protected
//   name» for four guards and had none.
//
// Two Dart doors remembered to call `scan` and nothing made them. This round
// puts the scan at the door, where no caller can forget it — and these guards
// never call `scan` themselves, which is the whole point of them.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const LETTER: &str = include_str!("fixtures/Brief_Weber.txt");
const PASS: &str = "ein gutes Passwort für die Reise";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(tag: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-arrives-scanned-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// Every door is asked the same two questions, and neither of them is «scan».
fn what_arrived(session: SessionId) -> (ScanOrigin, usize, usize) {
    let snap = workspace_snapshot(session).expect("snapshot");
    let findings = list_findings(session).expect("findings").len();
    (snap.scan_origin, findings, snap.findings.len() + snap.auto_protected as usize)
}

#[test]
fn text_typed_in_arrives_scanned() {
    let s = open_session(None, "de".to_string()).expect("open");
    let view = import_text(s, LETTER.to_string()).expect("import");
    let (origin, findings, marked) = what_arrived(s);
    assert_eq!(origin, ScanOrigin::OnImport, "the letter was not scanned on the way in");
    assert!(findings > 0, "a German letter arrived with no findings at all");
    assert!(marked > 0, "nothing on the snapshot is marked");
    assert!(
        !view.marks.is_empty(),
        "the view the door handed back carries no mark, though the document is scanned"
    );
    close_session(s).expect("close");
}

#[test]
fn a_text_file_arrives_scanned() {
    let s = open_session(None, "de".to_string()).expect("open");
    import_document(s, "Brief.txt".to_string(), LETTER.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("import");
    let (origin, findings, _) = what_arrived(s);
    assert_eq!(origin, ScanOrigin::OnImport, "a .txt file was not scanned on the way in");
    assert!(findings > 0, "a .txt file arrived with no findings");
    close_session(s).expect("close");
}

#[test]
fn a_word_file_arrives_scanned() {
    let s = open_session(None, "de".to_string()).expect("open");
    let xml = format!(
        r#"<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="x"><w:body>{}</w:body></w:document>"#,
        LETTER
            .lines()
            .map(|l| format!(r#"<w:p><w:r><w:t xml:space="preserve">{}</w:t></w:r></w:p>"#, l.replace('&', "&amp;")))
            .collect::<String>()
    );
    import_document(s, "Brief.docx".to_string(), zip_one("word/document.xml", xml.as_bytes()), DocumentKind::Docx)
        .expect("import");
    let (origin, findings, _) = what_arrived(s);
    assert_eq!(origin, ScanOrigin::OnImport, "a .docx was not scanned on the way in");
    assert!(findings > 0, "a .docx arrived with no findings");
    close_session(s).expect("close");
}

#[test]
fn a_pdf_arrives_scanned() {
    let s = open_session(None, "de".to_string()).expect("open");
    let lines: Vec<String> = LETTER.lines().filter(|l| !l.is_empty()).map(|l| l.replace(['(', ')'], "")).collect();
    import_document(s, "Brief.pdf".to_string(), pdf_of(&lines), DocumentKind::Pdf).expect("import");
    let (origin, findings, _) = what_arrived(s);
    assert_eq!(origin, ScanOrigin::OnImport, "a .pdf was not scanned on the way in");
    assert!(findings > 0, "a .pdf arrived with no findings");
    close_session(s).expect("close");
}

#[test]
fn a_second_document_in_the_same_session_arrives_scanned_too() {
    // The shape that was measured on 13 October while 075e was being written:
    // «findings after the second import: 0». The first document had been
    // scanned by hand; the second one replaced it and the scan was not run
    // again, so the session looked as though the vault had lost what it knew.
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, LETTER.to_string()).expect("first");
    import_text(s, LETTER.to_string()).expect("second");
    let (origin, findings, _) = what_arrived(s);
    assert_eq!(origin, ScanOrigin::OnImport, "the second document was not scanned");
    assert!(findings > 0, "the second import left the session with no findings");
    close_session(s).expect("close");
}

#[test]
fn a_value_the_vault_knows_comes_back_protected_and_is_never_asked_about() {
    let _guard = serial();
    fresh_vault("vault-value");
    let entity = create_entity(EntityKind::Client, "Weber".to_string(), None).expect("entity");
    set_value(entity, None, Kind::Person, "Katharina Lindemann".to_string(), Policy::Always)
        .expect("value");

    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, LETTER.to_string()).expect("import");
    // No scan here, on purpose: this is the lead's own sentence — a vault value
    // comes back as `auto`, never as a question — and before this round it came
    // back as neither.
    let asked = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.source == Source::Vault && f.state == MarkState::Suggested)
        .count();
    let snap = workspace_snapshot(s).expect("snapshot");
    let protected = snap
        .tokens
        .iter()
        .filter(|t| t.source == Source::Vault)
        .count();
    assert!(
        protected > 0,
        "the value the vault was taught is not protected after an import: {} tokens, {} questions",
        snap.tokens.len(),
        asked
    );
    assert_eq!(asked, 0, "a value the vault knows was put as a question, not as an answer");
    close_session(s).expect("close");
    let _ = vault_lock();
}

#[test]
fn an_empty_import_is_not_a_refusal() {
    // The composer opens a conversation by importing an empty string, and an
    // empty document is nothing to scan rather than something that failed.
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, String::new()).expect("an empty import must not be refused");
    let (origin, findings, _) = what_arrived(s);
    assert_eq!(origin, ScanOrigin::NotScanned, "an empty document reports a scan it never had");
    assert_eq!(findings, 0, "an empty document found something");
    close_session(s).expect("close");
}

// ------------------------------------------------------- the file builders
//
// A .docx and a .pdf written here by hand, so the doors are driven with bytes
// laid out the way a writer lays them out rather than with our own idea of a
// file. Copied from `document_journey`, which is where the readers themselves
// are measured.

fn latin1(text: &str) -> Vec<u8> {
    text.chars().map(|c| u8::try_from(u32::from(c)).unwrap_or(b'?')).collect()
}

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
        let stream = latin1(&format!("BT /F1 12 Tf 72 700 Td ({line}) Tj ET"));
        out.push_str(&format!("{content_id} 0 obj\n<< /Length {} >>\nstream\n", stream.len()));
        out.push_str(&stream.iter().map(|b| char::from(*b)).collect::<String>());
        out.push_str("\nendstream\nendobj\n");
    }
    out.push_str("100 0 obj\n<< /Type/Font /Subtype/Type1 /BaseFont/Helvetica >>\nendobj\n");
    out.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");
    latin1(&out)
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

    let central_len = out.len() - central_at;
    out.extend_from_slice(&0x0605_4b50u32.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes());
    out.extend_from_slice(&(central_len as u32).to_le_bytes());
    out.extend_from_slice(&(central_at as u32).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out
}

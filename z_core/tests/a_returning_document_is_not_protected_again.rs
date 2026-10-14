// **A token is not a candidate** — 079 rule 5, measured at every door a
// document can come back through.
//
// Until 14 October nothing scanned on import, so nothing could re-protect a
// returning document; the moment the scan moved to the door (item 3 of the
// detection round) three layers could read a token as a value. Measured on a
// German answer carrying five tokens, before this law existed:
//
//   * `E-Mail: __Z_7f3a_EMAIL_…__` — the label's value is one word, so the
//     token was **protected outright** and a second token minted over it. The
//     text that left no longer carried the identifier the other session can
//     resolve, and restoring would have handed back a token instead of an
//     address;
//   * `Ansprechpartner: __Z_7f3a_PERSON_…__` — a token starts with a capital,
//     so a person was **asked about a token** whether it is a person;
//   * and the vault layer, had a token ever stood in it.
//
// What did *not* bite, and is worth writing down because it is the reason this
// was two findings and not five: a salutation needs a name-shaped word and an
// underscore is not one; a grouped value needs groups (the IBAN item, the same
// round); a number needs digits.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// A document that has come back: well-formed tokens of an earlier session, in
/// the shapes a German letter writes them in, and one value of its own — the
/// invoice number — so that a guard can tell «nothing is found» from «nothing
/// is found **on a token**».
const RETURNED: &str = "Betreff: Antwort zu Rechnung Nr. 2026-10518\n\
\n\
Sehr geehrter Herr __Z_7f3a_PERSON_9b21__,\n\
\n\
wir haben Ihre Zahlung auf die IBAN __Z_7f3a_IBAN_4c18__ erhalten. Ihre Kundennummer __Z_7f3a_CUSTOMERNO_77a2__ bleibt unverändert.\n\
Ansprechpartner: __Z_7f3a_PERSON_1d44__\n\
E-Mail: __Z_7f3a_EMAIL_8e07__\n\
Telefon: __Z_7f3a_PHONE_2b55__\n\
\n\
Mit freundlichen Grüßen\n\
\n\
__Z_7f3a_PERSON_9b21__\n";

fn word_at(span: Span) -> String {
    let units: Vec<u16> = RETURNED.encode_utf16().collect();
    String::from_utf16_lossy(&units[span.start as usize..span.end as usize])
}

/// The two questions every door is asked, and neither of them is «scan».
fn what_arrived(session: SessionId) -> (usize, usize, String) {
    let findings = list_findings(session).expect("findings");
    let on_a_token = findings
        .iter()
        .filter(|f| word_at(f.span).contains("__Z_"))
        .count();
    let payload = payload_view(build_payload(session).expect("build")).expect("view").text;
    (findings.len(), on_a_token, payload)
}

fn assert_untouched(name: &str, session: SessionId) {
    let (found, on_a_token, payload) = what_arrived(session);
    assert_eq!(
        on_a_token, 0,
        "{name}: {on_a_token} of {found} findings stand on a token of the session this \
         document came back from"
    );
    assert_eq!(
        payload, RETURNED,
        "{name}: the text that would leave is not the text that came in — a token was \
         protected over"
    );
    assert_eq!(
        found, 1,
        "{name}: the invoice number is this letter's own value and the only thing to find \
         in it, so {found} findings means the law above is a mute button"
    );
}

#[test]
fn a_document_typed_or_pasted_back_keeps_its_tokens() {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, RETURNED.to_string()).expect("import");
    assert_untouched("typed or pasted", s);
    close_session(s).expect("close");
}

#[test]
fn a_text_file_coming_back_keeps_its_tokens() {
    let s = open_session(None, "de".to_string()).expect("open");
    import_document(s, "Antwort.txt".to_string(), RETURNED.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("import");
    assert_untouched("a .txt file", s);
    close_session(s).expect("close");
}

#[test]
fn a_word_file_coming_back_keeps_its_tokens() {
    let s = open_session(None, "de".to_string()).expect("open");
    let xml = format!(
        r#"<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="x"><w:body>{}</w:body></w:document>"#,
        RETURNED
            .lines()
            .map(|l| format!(r#"<w:p><w:r><w:t xml:space="preserve">{}</w:t></w:r></w:p>"#, l.replace('&', "&amp;")))
            .collect::<String>()
    );
    import_document(s, "Antwort.docx".to_string(), zip_one("word/document.xml", xml.as_bytes()), DocumentKind::Docx)
        .expect("import");
    // A .docx is read paragraph by paragraph, so the text is not the fixture
    // byte for byte; the law is still exactly the law.
    let findings = list_findings(s).expect("findings");
    let on_a_token = findings
        .iter()
        .filter_map(|f| document_view(s).ok().map(|v| (f.span, v.text)))
        .filter(|(span, text)| {
            let units: Vec<u16> = text.encode_utf16().collect();
            String::from_utf16_lossy(&units[span.start as usize..span.end as usize]).contains("__Z_")
        })
        .count();
    assert_eq!(on_a_token, 0, "a .docx came back and a token was read as a value");
    let payload = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert_eq!(
        payload.matches("__Z_7f3a_").count(),
        7,
        "all seven places the document's own tokens stand in must still be there in what \
         leaves: {payload}"
    );
    close_session(s).expect("close");
}

#[test]
fn a_pdf_coming_back_keeps_its_tokens() {
    let s = open_session(None, "de".to_string()).expect("open");
    let lines: Vec<String> = RETURNED
        .lines()
        .filter(|l| !l.is_empty())
        .map(|l| l.replace(['(', ')'], ""))
        .collect();
    import_document(s, "Antwort.pdf".to_string(), pdf_of(&lines), DocumentKind::Pdf).expect("import");
    let payload = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert_eq!(
        payload.matches("__Z_7f3a_").count(),
        7,
        "a .pdf came back and lost a token to a protection: {payload}"
    );
    close_session(s).expect("close");
}

#[test]
fn a_rescan_does_not_find_a_token_either() {
    // The button, a pack changed, a name taught: the same law, because it is
    // written where the layers settle rather than at the import door.
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, RETURNED.to_string()).expect("import");
    scan(s).expect("rescan");
    scan(s).expect("and again");
    assert_untouched("after two rescans", s);
    close_session(s).expect("close");
}

#[test]
fn a_hand_drawn_over_a_token_still_takes_it_and_that_is_079s_door() {
    // **Pinned, deliberately, because the fix is a later item** (the owner's
    // rule). A selection drawn over a token is `Applied` today: a second token
    // is minted and the first one disappears from the text, so what comes back
    // from the model restores to a token rather than to a value.
    //
    // It is not this round's to fix: refusing it needs a word on the glass
    // («this is already protected text — Z put it there»), and that word
    // belongs to 079's returning-document door, which the lead has assigned as
    // the next round. The day it is built, this guard goes red and says so.
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, RETURNED.to_string()).expect("import");
    let token = "__Z_7f3a_PHONE_2b55__";
    let at = RETURNED.find(token).expect("the token");
    let start: usize = RETURNED[..at].chars().map(char::len_utf16).sum();
    let span = Span { start: start as u32, end: (start + token.chars().count()) as u32 };
    match protect(s, span, Scope::Conversation, Kind::Phone).expect("protect") {
        ProtectOutcome::Applied { token: minted, .. } => {
            assert_ne!(minted, token, "it minted a token over a token");
        }
        other => panic!(
            "a hand over a token no longer mints one — 079's door is built, so this guard \
             must now assert the refusal: {other:?}"
        ),
    }
    close_session(s).expect("close");
}

// ------------------------------------------------------- the file builders
//
// Copied from `document_journey`, where the readers themselves are measured: a
// .docx and a .pdf written by hand, so these doors are driven with bytes laid
// out the way a writer lays them out.

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

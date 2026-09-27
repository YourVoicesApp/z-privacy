// The most important test in M6: what actually crossed the wire.
//
// A server on this machine records the request **byte for byte** — request line,
// headers and body — answers with a chat completion, and hands the bytes back.
// Then this test reads them and proves the owner's claim:
//
//   * the body's `content` is *literally* the SafePayload, character for
//     character, and not a rebuilt or re-escaped version of it;
//   * no original value and no vault value appears anywhere in the request —
//     not in the body, not in a header, not in the URL;
//   * the answer comes home and restores against the token store.
//
// And one thing it proves that is **not** a success: the request carries a Host
// header, a time and an address. That is the honest limit written in §1 of
// docs/SECURITY_INVARIANTS.md — we protect what is in the document, not the fact
// that you asked.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::io::{Read, Write};
use std::net::TcpListener;
use std::thread::JoinHandle;

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für den Test";
const CREDENTIAL: &str = "sk-test-not-a-real-credential-0001";

/// Every real value in the document below. None of these may leave.
const SECRETS: &[&str] = &[
    "Nordstern Consulting GmbH",
    "Nordstern",
    "Thomas Müller",
    "Müller",
    "thomas.mueller@nordstern.example",
    "DE89370400440532013000",
    "+49 171 2345678",
];

const DOC: &str = "Kunde: Nordstern Consulting GmbH\n\
Ansprechpartner: Herr Thomas Müller\n\
E-Mail: thomas.mueller@nordstern.example\n\
Telefon: +49 171 2345678\n\
IBAN: DE89370400440532013000\n\
Bitte prüfen Sie den Vertrag und antworten Sie kurz.";

/// A server that keeps the request and gives back one answer.
fn recording_server(answer: String) -> (String, JoinHandle<Vec<u8>>) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
    let port = listener.local_addr().expect("addr").port();
    let handle = std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept");
        let mut buf: Vec<u8> = Vec::new();
        let mut chunk = [0u8; 4096];

        // Headers first, then exactly as much body as was announced.
        let head_end = loop {
            match find(&buf, b"\r\n\r\n") {
                Some(at) => break at,
                None => {
                    let n = stream.read(&mut chunk).expect("read");
                    assert!(n > 0, "the client closed before sending a request");
                    buf.extend_from_slice(&chunk[..n]);
                }
            }
        };
        let head = String::from_utf8_lossy(&buf[..head_end]).to_string();
        let want = content_length(&head);
        while buf.len() < head_end + 4 + want {
            let n = stream.read(&mut chunk).expect("read");
            if n == 0 {
                break;
            }
            buf.extend_from_slice(&chunk[..n]);
        }

        let response = format!(
            "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{answer}",
            answer.len()
        );
        stream.write_all(response.as_bytes()).expect("write");
        stream.flush().expect("flush");
        buf
    });
    (format!("http://127.0.0.1:{port}"), handle)
}

fn find(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack.windows(needle.len()).position(|w| w == needle)
}

fn content_length(head: &str) -> usize {
    for line in head.lines() {
        let lower = line.to_ascii_lowercase();
        if let Some(value) = lower.strip_prefix("content-length:") {
            return value.trim().parse().unwrap_or(0);
        }
    }
    0
}

/// Answer every open suggestion, so G12 is satisfied honestly rather than
/// sidestepped. There is no «send anyway»; there never was.
fn settle_the_review(s: SessionId) {
    loop {
        let open: Vec<u32> = list_findings(s)
            .expect("findings")
            .into_iter()
            .filter(|f| f.state == MarkState::Suggested)
            .map(|f| f.id)
            .collect();
        if open.is_empty() {
            break;
        }
        for id in open {
            answer_finding(s, id, FindingAnswer::Protect).expect("protect it");
        }
    }
}

#[test]
fn the_server_receives_the_safe_payload_and_nothing_else() {
    // A vault of this test's own, with one identity the document mentions, so the
    // fourth layer is in play and its value is on the forbidden list too.
    let dir = std::env::temp_dir().join(format!("zprivacy-wire-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    let entity = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("entity");
    let value = set_value(
        entity,
        None,
        Kind::Company,
        "Nordstern Consulting GmbH".to_string(),
        Policy::Always,
    )
    .expect("value");
    add_value_alias(entity, value, "Nordstern".to_string()).expect("alias");

    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    settle_the_review(s);

    let handle = build_payload(s).expect("build");
    let safe = payload_view(handle).expect("view").text;
    for secret in SECRETS {
        assert!(!safe.contains(secret), "«{secret}» is still in the safe text: {safe}");
    }

    // The server's answer quotes the safe text back, which makes the round trip
    // strict: a token that failed to be replaced on the way out would come home
    // as a real value here.
    let answer_text = format!("Verstanden:\\n{}\\n— Ende.", safe.replace('\n', "\\n"));
    let canned = format!(r#"{{"choices":[{{"message":{{"role":"assistant","content":"{answer_text}"}}}}]}}"#);
    let (base, server) = recording_server(canned);

    let row = connect_provider(
        ProviderId { id: "openai".to_string() },
        CREDENTIAL.to_string(),
        Some(base),
    )
    .expect("connect");
    assert!(row.connected, "the row says connected");
    assert!(!row.session_only, "with an open vault the credential is sealed, not temporary");

    let answer = send(handle, ProviderId { id: "openai".to_string() }).expect("send");
    let raw = server.join().expect("the server thread");
    let request = String::from_utf8_lossy(&raw).to_string();

    // ------------------------------------------------- the control string first
    // A list of things that are *not* in a body proves nothing until the search
    // is shown to work. Two things that must be found: a label, which is not a
    // secret and travels in the clear, and a token, which is what replaced the
    // values. If either of these is missing, every assertion below is vacuous.
    assert!(
        request.contains("Ansprechpartner:"),
        "the search cannot see the document text, so the rest of this test means nothing"
    );
    let tokens = list_tokens(s).expect("tokens");
    assert!(!tokens.is_empty(), "nothing was protected, so nothing is being proven");
    for row in &tokens {
        assert!(
            request.contains(&row.token),
            "token {} never reached the wire, so something else went instead",
            row.token
        );
    }

    // ---------------------------------------------------------------- the claim
    for secret in SECRETS {
        assert!(
            !request.contains(secret),
            "«{secret}» reached the wire. The whole product is this line."
        );
    }

    let (head, body) = request.split_once("\r\n\r\n").expect("a request with a body");
    let request_line = head.lines().next().expect("a request line").to_string();
    assert_eq!(request_line, "POST /v1/chat/completions HTTP/1.1", "{request_line}");
    assert!(!request_line.contains('?'), "nothing travels in a query string");

    let sent: serde_json::Value = serde_json::from_str(body).expect("the body is the JSON we built");
    let content = sent["messages"][0]["content"].as_str().expect("the content");
    assert_eq!(
        content, safe,
        "what the server received must be the SafePayload, character for character"
    );
    let fields: Vec<&str> = sent.as_object().expect("object").keys().map(|k| k.as_str()).collect();
    assert_eq!(fields.len(), 3, "three fields and no fourth to hide in: {fields:?}");

    // Headers: the credential is there, addressed to this host, and nothing else
    // of the user's is.
    let lower = head.to_ascii_lowercase();
    assert!(lower.contains(&format!("authorization: bearer {}", CREDENTIAL.to_ascii_lowercase())));
    assert_eq!(lower.matches("authorization:").count(), 1, "one credential, once");
    assert!(lower.contains("content-type: application/json"));

    // The honest limit, as a test rather than a sentence: the provider learns the
    // host, the time and the size of what you asked. That is not content.
    assert!(lower.contains("host: 127.0.0.1"), "a request always names its host");

    // ---------------------------------------------------------------- coming home
    let raw_answer = ai_view(s, answer).expect("the model's own words");
    assert!(raw_answer.contains("Verstanden"), "the answer arrived: {raw_answer}");
    for secret in SECRETS {
        assert!(!raw_answer.contains(secret), "the raw answer holds no real value either");
    }
    let restored: String = restored_view(s, answer)
        .expect("restore")
        .into_iter()
        .map(|seg| seg.text)
        .collect();
    assert!(
        restored.contains("Nordstern Consulting GmbH"),
        "restore puts the real value back locally: {restored}"
    );
    assert!(restored.contains("Thomas Müller"), "{restored}");

    // ---------------------------------------------------------------- forgetting
    let gone = disconnect_provider(ProviderId { id: "openai".to_string() }).expect("disconnect");
    assert!(!gone.connected, "a disconnected provider is not connected");
    vault_lock().expect("lock");
    let rows = providers().expect("rows");
    let openai = rows.iter().find(|r| r.id == "openai").expect("the row");
    assert!(!openai.connected, "a locked vault knows no credential");

    close_session(s).expect("close");
    let _ = std::fs::remove_dir_all(&dir);
}

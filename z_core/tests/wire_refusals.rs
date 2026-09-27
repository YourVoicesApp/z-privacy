// What the wire refuses, proven against a server on this machine.
//
// Each of these is one of the owner's M6 rules. They are here as tests and not as
// sentences in a document because a rule nobody can break is a rule nobody has to
// remember: «no blind redirects» is a redirect that is refused *and* a second
// listener that is never connected to.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::io::{ErrorKind, Read, Write};
use std::net::TcpListener;
use std::sync::{Mutex, MutexGuard, OnceLock};
use std::thread::JoinHandle;

use z_core::api::*;

const DOC: &str = "Kunde: Nordstern Consulting GmbH\nIBAN: DE89370400440532013000";

/// The core is one per process and so is a provider's address. One test at a time.
fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// A server that answers one request with exactly these bytes.
///
/// It reads the **whole** request before answering, and that is not politeness:
/// closing a socket that still holds unread bytes sends a reset, and a reset
/// throws away the reply that was already on its way. A server that skips this
/// makes its own flaky test and blames the client.
fn serve_once(response: String) -> (String, JoinHandle<bool>) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
    let port = listener.local_addr().expect("addr").port();
    let handle = std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept");
        drain_request(&mut stream);
        let written = stream.write_all(response.as_bytes()).is_ok();
        let _ = stream.flush();
        written
    });
    (format!("http://127.0.0.1:{port}"), handle)
}

/// Read one HTTP request: the headers, then exactly as much body as announced.
fn drain_request(stream: &mut std::net::TcpStream) {
    let mut buf: Vec<u8> = Vec::new();
    let mut chunk = [0u8; 4096];
    let head_end = loop {
        if let Some(at) = buf.windows(4).position(|w| w == b"\r\n\r\n") {
            break at;
        }
        match stream.read(&mut chunk) {
            Ok(0) | Err(_) => return,
            Ok(n) => buf.extend_from_slice(&chunk[..n]),
        }
    };
    let head = String::from_utf8_lossy(&buf[..head_end]).to_string();
    let mut want = 0usize;
    for line in head.lines() {
        let lower = line.to_ascii_lowercase();
        if let Some(value) = lower.strip_prefix("content-length:") {
            want = value.trim().parse().unwrap_or(0);
        }
    }
    while buf.len() < head_end + 4 + want {
        match stream.read(&mut chunk) {
            Ok(0) | Err(_) => return,
            Ok(n) => buf.extend_from_slice(&chunk[..n]),
        }
    }
}

fn body(content: &str) -> String {
    format!(
        "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{content}",
        content.len()
    )
}

/// A session with something to send, and a provider pointed at `base`.
fn ready(base: String) -> (SessionId, PayloadHandle) {
    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
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
            answer_finding(s, id, FindingAnswer::Protect).expect("protect");
        }
    }
    let handle = build_payload(s).expect("build");
    connect_provider(
        ProviderId { id: "openai".to_string() },
        "sk-test-not-a-real-credential".to_string(),
        Some(base),
        None,
    )
    .expect("connect");
    (s, handle)
}

fn openai() -> ProviderId {
    ProviderId { id: "openai".to_string() }
}

#[test]
fn a_redirect_is_refused_and_the_other_host_is_never_contacted() {
    let _guard = serial();

    // The host a 302 would send us to. Nothing may ever connect to it.
    let elsewhere = TcpListener::bind("127.0.0.1:0").expect("bind");
    elsewhere.set_nonblocking(true).expect("nonblocking");
    let elsewhere_port = elsewhere.local_addr().expect("addr").port();

    let (base, server) = serve_once(format!(
        "HTTP/1.1 302 Found\r\nlocation: http://127.0.0.1:{elsewhere_port}/v1/chat/completions\r\ncontent-length: 0\r\nconnection: close\r\n\r\n"
    ));
    let (s, handle) = ready(base);

    match send(handle, openai()) {
        Err(ApiError::NetworkRefused {
            reason: NetworkRefusal::Redirected { status },
            detail,
        }) => {
            assert_eq!(status, 302);
            assert!(detail.contains("redirect"), "{detail}");
            assert!(
                !detail.contains(&elsewhere_port.to_string()),
                "the refusal does not even repeat where it was sent: {detail}"
            );
        }
        other => panic!("a redirect must be refused, got {other:?}"),
    }
    let _ = server.join();

    // The whole point: the safe payload and the credential went nowhere else.
    match elsewhere.accept() {
        Err(e) if e.kind() == ErrorKind::WouldBlock => {}
        Ok(_) => panic!("the request was sent to the redirect target — this is the leak we forbid"),
        Err(e) => panic!("unexpected: {e}"),
    }
    close_session(s).expect("close");
}

#[test]
fn a_provider_error_is_named_by_its_status_and_never_by_its_body() {
    let _guard = serial();
    let page = r#"{"error":{"message":"Incorrect API key provided: sk-test-not-a-real-credential"}}"#;
    let (base, server) = serve_once(format!(
        "HTTP/1.1 401 Unauthorized\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{page}",
        page.len()
    ));
    let (s, handle) = ready(base);

    match send(handle, openai()) {
        Err(ApiError::NetworkRefused {
            reason: NetworkRefusal::BadStatus { status },
            detail,
        }) => {
            assert_eq!(status, 401);
            assert!(detail.contains("credential"), "{detail}");
            // The provider quoted our credential back at us. It stops here.
            assert!(!detail.contains("sk-test"), "the response body reached the error: {detail}");
            assert!(!detail.contains("Incorrect API key"), "{detail}");
        }
        other => panic!("expected a named status, got {other:?}"),
    }
    let _ = server.join();
    close_session(s).expect("close");
}

#[test]
fn an_answer_longer_than_the_limit_is_refused_rather_than_read() {
    let _guard = serial();
    let huge = format!(r#"{{"choices":[{{"message":{{"content":"{}"}}}}]}}"#, "x".repeat(3 * 1024 * 1024));
    let (base, server) = serve_once(body(&huge));
    let (s, handle) = ready(base);

    match send(handle, openai()) {
        Err(ApiError::NetworkRefused {
            reason: NetworkRefusal::ResponseTooLarge { limit_kib },
            ..
        }) => assert_eq!(limit_kib, 2048),
        other => panic!("expected a size refusal, got {other:?}"),
    }
    let _ = server.join();
    close_session(s).expect("close");
}

#[test]
fn an_answer_that_is_not_an_answer_is_refused_without_being_quoted() {
    let _guard = serial();
    let (base, server) = serve_once(body("this is not JSON, and it mentions Nordstern"));
    let (s, handle) = ready(base);

    match send(handle, openai()) {
        Err(ApiError::NetworkRefused {
            reason: NetworkRefusal::Unreadable,
            detail,
        }) => assert!(!detail.contains("Nordstern"), "the body reached the error: {detail}"),
        other => panic!("expected an unreadable answer, got {other:?}"),
    }
    let _ = server.join();
    close_session(s).expect("close");
}

#[test]
fn a_plain_http_address_off_this_machine_is_refused_when_it_is_given() {
    let _guard = serial();
    // Refused at the moment it is typed, not the first time Send is pressed.
    for bad in ["http://api.openai.com", "http://192.168.1.50:8000", "ftp://example.com"] {
        match connect_provider(openai(), "sk-test".to_string(), Some(bad.to_string()), None) {
            Err(ApiError::NetworkRefused {
                reason: NetworkRefusal::InsecureUrl,
                ..
            }) => {}
            other => panic!("{bad} should have been refused, got {other:?}"),
        }
    }
    // And https is accepted, so the rule is a rule and not a wall.
    let row = connect_provider(openai(), "sk-test".to_string(), Some("https://api.openai.com".to_string()), None).expect("connect");
    assert_eq!(row.base_url, "https://api.openai.com");
    disconnect_provider(openai()).expect("disconnect");
}

#[test]
fn a_model_on_this_machine_needs_no_credential_and_everything_else_does() {
    let _guard = serial();

    // The most private provider there is: no key, no account, no request that
    // leaves the machine. Refusing this door for want of an API key would shut
    // the product to exactly the people it is for.
    let row = connect_provider(
        openai(),
        String::new(),
        Some("http://127.0.0.1:11434".to_string()),
        Some("llama3.2".to_string()),
    )
    .expect("a local model connects without a credential");
    assert!(row.connected);
    assert_eq!(row.model, "llama3.2", "the model is a setting, and it was taken");

    // The model can be changed afterwards without the credential coming back —
    // the UI never had one and must not need one to edit a setting.
    let changed = configure_provider(openai(), None, Some("qwen2.5".to_string())).expect("configure");
    assert_eq!(changed.model, "qwen2.5");
    assert_eq!(changed.base_url, "http://127.0.0.1:11434", "the address was left alone");

    // Anywhere else, an empty credential connects nothing and says why.
    disconnect_provider(openai()).expect("disconnect");
    match connect_provider(openai(), String::new(), Some("https://api.openai.com".to_string()), None) {
        Err(ApiError::ImportRefused { reason }) => assert!(reason.contains("credential"), "{reason}"),
        other => panic!("expected a refusal, got {other:?}"),
    }
    // And a configure with nothing stored is «connect first», not a silent one.
    match configure_provider(openai(), Some("https://api.openai.com".to_string()), None) {
        Err(ApiError::NetworkRefused {
            reason: NetworkRefusal::NotConnected,
            ..
        }) => {}
        other => panic!("expected NotConnected, got {other:?}"),
    }
}

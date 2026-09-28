// A provider credential is not portable from one destination to another.
//
// The exploit this closes is small and sharp: enter a key for one endpoint,
// change only the endpoint, then send. The key must not follow.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::io::{ErrorKind, Read, Write};
use std::net::TcpListener;
use std::sync::{Mutex, MutexGuard, OnceLock};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use z_core::api::*;

const CREDENTIAL: &str = "sk-rebind-test-not-real-22007";
const DOC: &str = "Please summarize this harmless sentence.";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

fn openai() -> ProviderId {
    ProviderId {
        id: "openai".to_string(),
    }
}

fn unused_loopback_base() -> (String, TcpListener) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
    let port = listener.local_addr().expect("addr").port();
    (format!("http://127.0.0.1:{port}"), listener)
}

fn recording_server(wait: Duration) -> (String, JoinHandle<Option<Vec<u8>>>) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
    listener.set_nonblocking(true).expect("nonblocking");
    let port = listener.local_addr().expect("addr").port();
    let handle = std::thread::spawn(move || {
        let started = Instant::now();
        loop {
            match listener.accept() {
                Ok((mut stream, _)) => {
                    let request = read_request(&mut stream);
                    let answer = r#"{"choices":[{"message":{"content":"ok"}}]}"#;
                    let response = format!(
                        "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{answer}",
                        answer.len()
                    );
                    stream.write_all(response.as_bytes()).expect("write");
                    let _ = stream.flush();
                    return Some(request);
                }
                Err(e) if e.kind() == ErrorKind::WouldBlock && started.elapsed() < wait => {
                    std::thread::sleep(Duration::from_millis(10));
                }
                Err(e) if e.kind() == ErrorKind::WouldBlock => return None,
                Err(e) => panic!("accept failed: {e}"),
            }
        }
    });
    (format!("http://127.0.0.1:{port}"), handle)
}

fn read_request(stream: &mut std::net::TcpStream) -> Vec<u8> {
    let mut buf: Vec<u8> = Vec::new();
    let mut chunk = [0u8; 4096];
    let head_end = loop {
        if let Some(at) = buf.windows(4).position(|w| w == b"\r\n\r\n") {
            break at;
        }
        let n = stream.read(&mut chunk).expect("read");
        assert!(n > 0, "the client closed before sending a request");
        buf.extend_from_slice(&chunk[..n]);
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
    buf
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

fn payload() -> (SessionId, PayloadHandle) {
    let session = open_session(None, "de".to_string()).expect("session");
    import_text(session, DOC.to_string()).expect("import");
    scan(session).expect("scan");
    let handle = build_payload(session).expect("payload");
    (session, handle)
}

#[test]
fn a_credential_does_not_follow_an_endpoint_change() {
    let _guard = serial();
    let (session, handle) = payload();
    let (old_base, _old_listener) = unused_loopback_base();
    let (new_base, server) = recording_server(Duration::from_millis(300));

    let connected = connect_provider(openai(), CREDENTIAL.to_string(), Some(old_base), None).expect("connect");
    assert!(connected.connected, "the control setup really had a credential");

    let changed = configure_provider(openai(), Some(new_base.clone()), None).expect("configure");
    assert_eq!(changed.base_url, new_base);
    assert!(!changed.connected, "a changed destination needs a fresh credential");

    match send(handle, openai()) {
        Err(ApiError::NetworkRefused {
            reason: NetworkRefusal::NotConnected,
            ..
        }) => {}
        other => panic!("the rebound credential must be refused before the wire, got {other:?}"),
    }
    assert!(
        server.join().expect("server").is_none(),
        "the changed endpoint must not be contacted at all",
    );

    disconnect_provider(openai()).expect("disconnect");
    close_session(session).expect("close");
}

#[test]
fn an_unchanged_destination_still_sends_the_authorization_header() {
    let _guard = serial();
    let (session, handle) = payload();
    let (base, server) = recording_server(Duration::from_secs(5));

    let connected = connect_provider(openai(), CREDENTIAL.to_string(), Some(base), None).expect("connect");
    assert!(connected.connected, "the provider is connected");

    send(handle, openai()).expect("send");
    let request = String::from_utf8_lossy(&server.join().expect("server").expect("request")).to_string();
    assert!(
        request
            .to_ascii_lowercase()
            .contains(&format!("authorization: bearer {CREDENTIAL}")),
        "the control must prove the header exists when the destination did not change: {request}",
    );

    disconnect_provider(openai()).expect("disconnect");
    close_session(session).expect("close");
}

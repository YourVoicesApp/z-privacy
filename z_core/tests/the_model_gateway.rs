// The Model Gateway, on the wire.
//
// The owner's framing for this phase: «this is not a stage where two models are
// added to Z; this is the first time we are building a piece of GAZA itself».
// Workspace ↓ Gateway ↓ Provider/Model — so what is tested here is the door,
// not a chat screen: every request in this file is made by a plain Rust
// function, which is the whole of the reusability claim.
//
// A server on this machine records what crossed the wire, byte for byte, and
// the tests read those bytes. Nothing here trusts a return value about what
// was sent.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::io::{Read, Write};
use std::net::TcpListener;
use std::thread::JoinHandle;

use z_core::api::*;

const CREDENTIAL: &str = "sk-test-not-a-real-credential-0002";
const OTHER_CREDENTIAL: &str = "sk-test-not-a-real-credential-0003";

/// Three documents, three languages. The gateway must not know the difference.
const GERMAN: &str = "Kunde: Nordstern Consulting GmbH\n\
    Ansprechpartner: Herr Thomas Müller\n\
    IBAN: DE89370400440532013000\n";
const SWEDISH: &str = "Kund: Lindgren & Söner AB\n\
    Kontaktperson: Herr Lars Andersson\n\
    Telefon: 08 123 456 78\n";
const ENGLISH: &str = "Please summarise the attached contract in three lines.";

fn recording_server(answer: String) -> (String, JoinHandle<Vec<u8>>) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
    let port = listener.local_addr().expect("addr").port();
    let handle = std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept");
        let mut buf: Vec<u8> = Vec::new();
        let mut chunk = [0u8; 4096];
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

fn reply(text: &str) -> String {
    // With the usage block this company sends, so the gateway's own numbers can
    // be checked against what crossed the wire rather than against a guess.
    format!(
        "{{\"choices\":[{{\"message\":{{\"role\":\"assistant\",\"content\":\"{text}\"}}}}],\
         \"usage\":{{\"prompt_tokens\":41,\"completion_tokens\":7}}}}"
    )
}

/// Answer every open suggestion: G12 stops a send while one is open, and there
/// is no «send anyway» anywhere in this program.
fn settle(s: SessionId) {
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

/// A caller that is **not** a chat screen: the whole of item 13.
///
/// It takes a document and a target, protects it, asks the gateway, and hands
/// back what came home. A coding workspace would be this function with another
/// task; nothing in it knows what a widget is.
fn a_workspace_asks(pack: &str, doc: &str, provider: &str, model: Option<&str>) -> (ModelAnswer, SessionId) {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    settle(session);
    let handle = build_payload(session).expect("build");
    let answer = ask_model(
        handle,
        ProviderId { id: provider.to_string() },
        model.map(str::to_string),
        vec!["You are helping with a contract.".to_string()],
        vec![],
    )
    .expect("the gateway answers");
    (answer, session)
}

/// The matrix, in order, in one process.
///
/// One test and not seven, for the same reason `teach_once_protect_everywhere`
/// is one test: a provider's address is one row in this process, so two tests
/// running at once would send one's request to the other's server. The sections
/// below are the owner's test matrix, each with its own name in a comment.
#[test]
fn the_matrix() {
    // ---- the protected door sends the safe payload and the document stays here
    {
        let (base, server) = recording_server(reply("Verstanden."));
        connect_provider(
            ProviderId { id: "openai".to_string() },
            CREDENTIAL.to_string(),
            Some(base),
            Some("gpt-4o-mini".to_string()),
        )
        .expect("connect");

        let (answer, session) = a_workspace_asks("de", GERMAN, "openai", Some("gpt-4o-mini"));
        let bytes = server.join().expect("the server");
        let wire = String::from_utf8_lossy(&bytes).to_string();

        // What the model saw is what the core built, and nothing of the document.
        let safe = payload_view(build_payload(session).expect("again")).expect("view").text;
        for secret in ["Nordstern Consulting GmbH", "Thomas Müller", "DE89370400440532013000"] {
            assert!(!wire.contains(secret), "«{secret}» crossed the wire");
        }
        assert!(wire.contains("__Z_"), "no token on the wire, so nothing was protected");
        assert!(
            safe.contains("__Z_"),
            "the payload itself carries no token, so this test proves nothing"
        );
        // The workspace's instructions travelled, and they are not the document.
        assert!(wire.contains("You are helping with a contract."), "the instructions did not travel");
        assert!(wire.contains("\\\"role\\\":\\\"system\\\"") || wire.contains("\"role\":\"system\""));

        // And the answer came home with its usage.
        assert_eq!(answer.text, "Verstanden.");
        assert!(answer.answer.is_some(), "a protected answer is kept, so it can be restored");
        assert_eq!(answer.usage.provider_id, "openai");
        assert_eq!(answer.usage.model_id, "gpt-4o-mini");
        assert!(answer.usage.ok);
        // The units the provider stated, carried and not estimated.
        assert_eq!((answer.usage.input_units, answer.usage.output_units), (41, 7));
        assert!(answer.usage.millis < 60_000, "a duration nobody measured");
        let _ = close_session(session);
    }

    // ---- the direct door sends what the person chose and says so
    {
        let (base, server) = recording_server(reply("Summarised."));
        connect_provider(
            ProviderId { id: "openai".to_string() },
            CREDENTIAL.to_string(),
            Some(base),
            Some("gpt-4o".to_string()),
        )
        .expect("connect");

        let session = open_session(None, "en".to_string()).expect("open");
        import_text(session, ENGLISH.to_string()).expect("import");
        let answer = ask_model_directly(
            session,
            ENGLISH.to_string(),
            ProviderId { id: "openai".to_string() },
            None,
            vec![],
            vec![],
        )
        .expect("direct");

        let wire = String::from_utf8_lossy(&server.join().expect("the server")).to_string();
        // Direct Mode is what it says: the text as it stands, because it was asked
        // for. No token, because nothing was protected.
        assert!(wire.contains("Please summarise the attached contract"), "the text did not travel");
        assert!(!wire.contains("__Z_"), "a direct request carried a token: {wire}");
        // Nothing is kept to restore, because there is nothing to restore.
        assert!(answer.answer.is_none());
        assert_eq!(answer.usage.model_id, "gpt-4o", "the configured model answered");
        let _ = close_session(session);
    }

    // ---- a protected request that fails is never sent the other way
    {
        // A provider that is not connected at all: the protected door refuses, and
        // nothing in the core turns that into a direct send.
        let session = open_session(None, "de".to_string()).expect("open");
        import_text(session, GERMAN.to_string()).expect("import");
        scan(session).expect("scan");
        settle(session);
        let handle = build_payload(session).expect("build");
        let refused = ask_model(
            handle,
            ProviderId { id: "nothing-here".to_string() },
            None,
            vec![],
            vec![],
        );
        assert!(refused.is_err(), "an unknown provider answered");
        // The payload is still here, unspent: a failed send consumed nothing.
        assert!(payload_view(handle).is_ok(), "the payload was consumed by a refusal");
        let _ = close_session(session);
    }

    // ---- the gateway knows no language
    {
        // German protected, Swedish protected, English direct — one door, three
        // documents, and no language anywhere in the provider or the gateway.
        for (pack, doc) in [("de", GERMAN), ("sv", SWEDISH)] {
            let (base, server) = recording_server(reply("Ok."));
            connect_provider(
                ProviderId { id: "openai".to_string() },
                CREDENTIAL.to_string(),
                Some(base),
                Some("gpt-4o-mini".to_string()),
            )
            .expect("connect");
            let (answer, session) = a_workspace_asks(pack, doc, "openai", None);
            let wire = String::from_utf8_lossy(&server.join().expect("server")).to_string();
            assert!(wire.contains("__Z_"), "{pack}: nothing was protected");
            assert_eq!(answer.text, "Ok.");
            // The names of both languages stayed at home.
            for secret in ["Thomas Müller", "Lars Andersson", "Nordstern Consulting GmbH", "Lindgren"] {
                assert!(!wire.contains(secret), "{pack}: «{secret}» crossed the wire");
            }
            let _ = close_session(session);
        }
    }

    // ---- one provider never sees another s credential
    {
        let (base_a, server_a) = recording_server(reply("A."));
        connect_provider(
            ProviderId { id: "openai".to_string() },
            CREDENTIAL.to_string(),
            Some(base_a),
            None,
        )
        .expect("connect the first");
        // The echo provider exists only in a test build, and it is the second
        // provider here: a different id, a different login row.
        connect_provider(
            ProviderId { id: "fake".to_string() },
            OTHER_CREDENTIAL.to_string(),
            None,
            None,
        )
        .expect("connect the second");

        let (_, session) = a_workspace_asks("de", GERMAN, "openai", None);
        let wire = String::from_utf8_lossy(&server_a.join().expect("server")).to_string();
        assert!(wire.contains(CREDENTIAL), "the first provider was not given its own credential");
        assert!(
            !wire.contains(OTHER_CREDENTIAL),
            "one provider was handed another's credential"
        );
        let _ = close_session(session);
    }
    // ---- the second provider is a file and the door did not move
    // The second provider, on the wire: a different company, the same door.
    //
    // What this proves is the architecture's claim — a provider is a file. The
    // gateway was not touched to add it, the test above it was not rewritten, and
    // what differs is all in `providers/anthropic.rs`: `x-api-key` instead of a
    // bearer token, `/v1/messages` instead of `/v1/chat/completions`, a system
    // field instead of a system message, and content blocks instead of choices.
    {
        let answer = "{\"content\":[{\"type\":\"text\",\"text\":\"Verstanden.\"}]}";
        let (base, server) = recording_server(answer.to_string());
        connect_provider(
            ProviderId { id: "anthropic".to_string() },
            CREDENTIAL.to_string(),
            Some(base),
            Some("claude-haiku-4-5-20251001".to_string()),
        )
        .expect("connect");

        let (got, session) = a_workspace_asks("de", GERMAN, "anthropic", None);
        let wire = String::from_utf8_lossy(&server.join().expect("server")).to_string();

        // Its own way of being spoken to, and nothing of the document.
        assert!(wire.contains("x-api-key"), "the company's own header is missing: {wire}");
        assert!(!wire.to_lowercase().contains("authorization:"), "a bearer token was sent as well");
        assert!(wire.contains("anthropic-version"), "the API version is missing");
        assert!(wire.contains("/v1/messages"), "the wrong path: {wire}");
        assert!(wire.contains("max_tokens"), "this company requires it");
        assert!(wire.contains("__Z_"), "nothing was protected");
        for secret in ["Thomas Müller", "Nordstern Consulting GmbH", "DE89370400440532013000"] {
            assert!(!wire.contains(secret), "«{secret}» crossed the wire");
        }

        // And the answer comes home through the same gateway, with usage naming
        // this provider and this model.
        assert_eq!(got.text, "Verstanden.");
        assert_eq!(got.usage.provider_id, "anthropic");
        assert_eq!(got.usage.model_id, "claude-haiku-4-5-20251001");
        assert!(got.answer.is_some(), "a protected answer is kept");
        let _ = close_session(session);
    }
    // ---- one task two providers and the workflow does not change
    // The same task, through two providers, with the workflow untouched.
    {
        let mut said = Vec::new();
        for (provider, model, answer) in [
            ("openai", "gpt-4o-mini", reply("A.")),
            (
                "anthropic",
                "claude-sonnet-5-5",
                "{\"content\":[{\"type\":\"text\",\"text\":\"B.\"}]}".to_string(),
            ),
        ] {
            let (base, server) = recording_server(answer);
            connect_provider(
                ProviderId { id: provider.to_string() },
                CREDENTIAL.to_string(),
                Some(base),
                Some(model.to_string()),
            )
            .expect("connect");
            // The *same* call, with a different target. This is the whole of what
            // «changing provider does not change the workflow» means.
            let (got, session) = a_workspace_asks("de", GERMAN, provider, Some(model));
            let wire = String::from_utf8_lossy(&server.join().expect("server")).to_string();
            assert!(wire.contains("__Z_"), "{provider}: nothing was protected");
            assert!(!wire.contains("Thomas Müller"), "{provider}: a name crossed the wire");
            assert_eq!(got.usage.model_id, model);
            said.push(got.text);
            let _ = close_session(session);
        }
        assert_eq!(said, vec!["A.".to_string(), "B.".to_string()]);
    }
}



/// The catalogue touches no network and no global row, so it is its own test.
#[test]
fn the_catalogue_is_what_the_providers_say_and_not_what_a_screen_knows() {
    let models = models().expect("the catalogue");
    assert!(!models.is_empty());
    for model in &models {
        assert!(!model.provider_id.is_empty() && !model.model_id.is_empty());
        assert!(!model.display_name.is_empty(), "a model a person cannot read is not a choice");
        assert!(
            model.capabilities.contains(&ModelCapability::Text),
            "every model in V1 answers text: {:?}",
            model.capabilities
        );
    }
    // One provider, several models, and the UI picks from this list.
    let openai: Vec<&ModelDescriptor> = models.iter().filter(|m| m.provider_id == "openai").collect();
    assert!(openai.len() >= 2, "a catalogue with one model is a hard-coded model");
}

use z_core::api::{self, DocumentKind, Kind, PayloadHandle, ProviderId, Scope, Span};

fn main() {
    let s = api::open_session(None, "de".into()).expect("session");
    let original = "Replay marker and john@example.invalid".to_string();
    api::import_text(s, original.clone()).expect("import");
    let start = original.find("john@example.invalid").unwrap() as u32;
    api::protect(
        s,
        Span { start, end: start + "john@example.invalid".len() as u32 },
        Scope::Conversation,
        Kind::Email,
    ).expect("protect");
    let handle = api::build_payload(s).expect("payload");
    let token = api::list_tokens(s).expect("tokens")[0].token.clone();

    for (name, forged) in [
        ("bad_id", PayloadHandle { id: handle.id + 999, ..handle }),
        ("bad_session", PayloadHandle { session: handle.session + 999, ..handle }),
        ("bad_revision", PayloadHandle { revision: handle.revision + 1, ..handle }),
    ] {
        println!("FORGE_{name}={:?}", api::payload_view(forged));
    }

    let injected = format!("provider replayed {token} twice: {token}; fake __Z_FAKE_ATTACKER__");
    let answer = api::ingest_answer(s, injected).expect("answer");
    let restored: String = api::restored_view(s, answer).expect("restore")
        .into_iter().map(|part| part.text).collect();
    println!("RESTORED={restored}");

    let s2 = api::open_session(None, "de".into()).expect("session2");
    api::import_text(s2, "other session".into()).expect("import2");
    let a2 = api::ingest_answer(s2, format!("cross session {token}")).expect("answer2");
    let restored2: String = api::restored_view(s2, a2).expect("restore2")
        .into_iter().map(|part| part.text).collect();
    println!("CROSS_SESSION={restored2}");

    api::connect_provider(
        ProviderId { id: "openai".into() },
        "ZXQ-REBIND-KEY-22007".into(),
        Some("http://127.0.0.1:18080".into()),
        Some("gpt-4o-mini".into()),
    ).expect("connect");
    api::configure_provider(
        ProviderId { id: "openai".into() },
        Some("http://127.0.0.1:18081".into()),
        Some("gpt-4o-mini".into()),
    ).expect("rebind");
    let provider = ProviderId { id: "openai".into() };
    println!("SEND_ONE={:?}", api::send(handle, provider.clone()));
    println!("SEND_TWO={:?}", api::send(handle, provider));

    if let Some(path) = std::env::args().nth(1) {
        let bytes = std::fs::read(path).expect("docx bytes");
        let ds = api::open_session(None, "de".into()).expect("doc session");
        let result = api::import_document(ds, "malformed.docx".into(), bytes, DocumentKind::Docx);
        println!("MALFORMED_DOCX={result:?}");
    }
}

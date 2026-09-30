//! F-06 in isolation. In the original main.rs the double-send was masked by
//! F-01 refusing first, so that run proves nothing about the handle. Here the
//! destination is NEVER rebound, so the credential is valid and the only thing
//! that can stop the second send is the handle being consumed.
use z_core::api::{self, Kind, ProviderId, Scope, Span};

fn main() {
    let s = api::open_session(None, "de".into()).expect("session");
    let original = "One shot marker and john@example.invalid".to_string();
    api::import_text(s, original.clone()).expect("import");
    let start = original.find("john@example.invalid").unwrap() as u32;
    api::protect(s, Span { start, end: start + "john@example.invalid".len() as u32 },
                 Scope::Conversation, Kind::Email).expect("protect");
    let handle = api::build_payload(s).expect("payload");

    api::connect_provider(
        ProviderId { id: "openai".into() },
        "ZXQ-ONESHOT-KEY-31415".into(),
        Some("http://127.0.0.1:18080".into()),
        Some("gpt-4o-mini".into()),
    ).expect("connect");
    let p = ProviderId { id: "openai".into() };
    println!("SEND_ONE={:?}", api::send(handle, p.clone()));
    println!("SEND_TWO={:?}", api::send(handle, p.clone()));
    println!("SEND_THREE={:?}", api::send(handle, p));
}

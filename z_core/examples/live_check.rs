//! The live acceptance check for the Model Gateway — one request per provider,
//! against the real endpoints, with synthetic data only.
//!
//!     ZPRIVACY_LIVE_OPENAI=sk-… ZPRIVACY_LIVE_ANTHROPIC=sk-ant-… \
//!         cargo run -p z_core --example live_check
//!
//! **Run it yourself.** The keys are read from the environment of the terminal
//! it is started in, so a credential never passes through anybody else's hands
//! to get here. With no keys set, it still runs the checks that need none: a
//! fabricated credential against the real host, which proves the address is
//! reached over TLS and that what comes back is said in our own words.
//!
//! What it prints is results: whether a name appeared, how many tokens, how
//! many milliseconds. Never a key, never a line of the document, and the
//! document is invented anyway — «Zyxwaria Qmblorf» is nobody.

use z_core::api::*;

/// A name no person has, so that finding it anywhere is proof and not a
/// coincidence. The instruction asks the model to repeat the text, which is the
/// strongest test there is of what actually reached it.
const NAME: &str = "Zyxwaria Qmblorf";
const DOC: &str = "Kunde: Qmblorf Handels GmbH\n\
    Ansprechpartner: Herr Zyxwaria Qmblorf\n\
    IBAN: DE02120300000000202051\n\
    Bitte geben Sie den Text wortwörtlich zurück.";
const INSTRUCTION: &str = "Repeat the user's text back, verbatim, with no commentary.";

fn settle(session: SessionId) {
    loop {
        let open: Vec<u32> = list_findings(session)
            .unwrap_or_default()
            .into_iter()
            .filter(|f| f.state == MarkState::Suggested)
            .map(|f| f.id)
            .collect();
        if open.is_empty() {
            return;
        }
        for id in open {
            let _ = answer_finding(session, id, FindingAnswer::Protect);
        }
    }
}

fn say(label: &str, ok: bool, detail: &str) {
    println!("  [{}] {label}{}", if ok { "ok  " } else { "FAIL" }, if detail.is_empty() { String::new() } else { format!(" — {detail}") });
}

/// One provider, one protected request, one direct request.
fn check(provider: &str, credential: Option<String>) {
    println!("\n== {provider} ==");
    let Some(credential) = credential else {
        // No key: the wrong-credential path is still a real check against the
        // real host, and it needs no valid key to be worth running.
        wrong_credential(provider);
        return;
    };

    if let Err(e) = connect_provider(
        ProviderId { id: provider.to_string() },
        credential,
        None,
        None,
    ) {
        say("connect", false, &format!("{e}"));
        return;
    }
    say("connect", true, "credential held for this run only (no vault open)");

    // ---- protected
    let session = match open_session(None, "de".to_string()) {
        Ok(s) => s,
        Err(e) => return say("open a session", false, &format!("{e}")),
    };
    if let Err(e) = import_text(session, DOC.to_string()) {
        return say("import", false, &format!("{e}"));
    }
    let _ = scan(session);
    settle(session);
    let handle = match build_payload(session) {
        Ok(h) => h,
        Err(e) => return say("build the payload", false, &format!("{e}")),
    };
    let safe = payload_view(handle).map(|v| v.text).unwrap_or_default();
    say(
        "the payload carries tokens and not the name",
        safe.contains("__Z_") && !safe.contains(NAME),
        &format!("{} token(s)", safe.matches("__Z_").count()),
    );

    match ask_model(
        handle,
        ProviderId { id: provider.to_string() },
        None,
        vec![INSTRUCTION.to_string()],
        vec![],
    ) {
        Ok(answer) => {
            say("the protected request answered", true, &format!("{} ms", answer.usage.millis));
            // The model was asked to repeat the text. If the name comes back,
            // the name went.
            say(
                "the model never saw the name",
                !answer.text.contains(NAME),
                if answer.text.contains("__Z_") { "it repeated the tokens" } else { "it did not repeat the text" },
            );
            say(
                "usage was reported",
                answer.usage.input_units > 0 || answer.usage.output_units > 0,
                &format!("{} in, {} out", answer.usage.input_units, answer.usage.output_units),
            );
            if let Some(id) = answer.answer {
                let restored = restored_view(session, id)
                    .map(|segments| segments.iter().map(|s| s.text.clone()).collect::<String>())
                    .unwrap_or_default();
                say(
                    "and the name is back in the restored view, here",
                    restored.contains(NAME) || !answer.text.contains("__Z_"),
                    if restored.contains(NAME) { "restored locally" } else { "nothing to restore: the answer carried no token" },
                );
            }
        }
        Err(e) => say("the protected request answered", false, &format!("{e}")),
    }

    // ---- direct, and only because this line chose it
    match ask_model_directly(
        session,
        DOC.to_string(),
        ProviderId { id: provider.to_string() },
        None,
        vec![INSTRUCTION.to_string()],
        vec![],
    ) {
        Ok(answer) => say(
            "the direct request answered, by explicit choice",
            true,
            &format!("{} ms, the model {} the name back", answer.usage.millis, if answer.text.contains(NAME) { "did give" } else { "did not give" }),
        ),
        Err(e) => say("the direct request answered", false, &format!("{e}")),
    }
    let _ = close_session(session);

    wrong_credential(provider);
}

/// A fabricated credential against the real host. No valid key is needed for
/// this to be worth running: it proves the address is reached and that the
/// refusal is said in our own words.
fn wrong_credential(provider: &str) {
    let made_up = "sk-not-a-real-credential-0000000000000000";
    if connect_provider(
        ProviderId { id: provider.to_string() },
        made_up.to_string(),
        None,
        None,
    )
    .is_err()
    {
        return say("a wrong credential is refused", false, "the provider would not even be configured");
    }
    let session = match open_session(None, "de".to_string()) {
        Ok(s) => s,
        Err(_) => return,
    };
    let _ = import_text(session, "Ein Satz ohne Namen.".to_string());
    let _ = scan(session);
    settle(session);
    let Ok(handle) = build_payload(session) else { return };
    match ask_model(handle, ProviderId { id: provider.to_string() }, None, vec![], vec![]) {
        Ok(_) => say("a wrong credential is refused", false, "it was accepted"),
        Err(e) => {
            let said = format!("{e}");
            let clean = !said.contains(made_up) && !said.contains("Ein Satz");
            say("a wrong credential is refused, in our own words", clean, &said);
        }
    }
    let _ = close_session(session);
}

fn main() {
    println!("{}", z_core::core_version());
    // Its own folder: the live check never touches the application's store, so
    // it cannot read a vault or leave anything behind in one.
    let dir = std::env::temp_dir().join(format!("zprivacy-live-{}", std::process::id()));
    let _ = std::fs::create_dir_all(&dir);
    if let Err(e) = set_data_dir(dir.to_string_lossy().to_string()) {
        println!("no data dir: {e}");
        return;
    }
    check("openai", std::env::var("ZPRIVACY_LIVE_OPENAI").ok().filter(|k| !k.trim().is_empty()));
    check("anthropic", std::env::var("ZPRIVACY_LIVE_ANTHROPIC").ok().filter(|k| !k.trim().is_empty()));
    let _ = std::fs::remove_dir_all(&dir);
    println!("\nSynthetic data only. No key and no document line is printed above.");
}

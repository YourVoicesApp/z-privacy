//! The journey, in two separate runs of the program.
//!
//!     cargo run -p z_core --example journey -- <folder> first
//!     cargo run -p z_core --example journey -- <folder> again
//!
//! Every in-process test shares one `Core`. This one does not: `first` makes a
//! vault, teaches it a client and protects a document; the process then **ends**,
//! and `again` is a new process that opens the same folder and checks that
//! everything survived. It is the one thing 148 in-process tests cannot say.
//!
//! Prints numbers and names of its own making — never a line of a document.

// An example, not the core: it may shout and stop. The core may not.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const PASS: &str = "ein langes Passwort für die Reise";

const DOC: &str = "Angebot 2026-114\n\
Kunde: Nordstern Consulting GmbH\n\
Ansprechpartner: Herr Thomas Müller\n\
E-Mail: t.mueller@nordstern-consulting.de\n\
Telefon: +49 171 2345678\n\
IBAN: DE89370400440532013000\n\
USt-IdNr.: DE811728394\n\
Wir bitten um eine Verlängerung des Zahlungsziels von 30 auf 60 Tage.\n\
Frau Anna Weber vertritt Herrn Müller im Urlaub.";

fn say(step: &str, what: String) {
    println!("  {step:<26} {what}");
}

fn main() {
    let mut args = std::env::args().skip(1);
    let dir = args.next().expect("a folder");
    let step = args.next().unwrap_or_else(|| "first".to_string());
    set_data_dir(dir).expect("data dir");

    match step.as_str() {
        "first" => first(),
        "again" => again(),
        other => println!("unknown step {other}"),
    }
}

fn first() {
    println!("\nRUN ONE — a new device");
    say("vault before", format!("{:?}", vault_state().expect("state")));
    vault_create_with_passphrase(PASS.to_string()).expect("create");

    // A new client, taught by hand, as a person would on their first day.
    let profile = create_profile("Client Nordstern".to_string()).expect("profile");
    let client = create_entity(EntityKind::Client, "Nordstern".to_string(), Some(profile.clone()))
        .expect("entity");
    let company = set_value(
        client,
        None,
        Kind::Company,
        "Nordstern Consulting GmbH".to_string(),
        Policy::Always,
    )
    .expect("value");
    add_value_alias(client, company, "Nordstern".to_string()).expect("alias");
    let person = create_entity(EntityKind::Person, "Thomas Müller".to_string(), Some(profile.clone()))
        .expect("entity");
    let name = set_value(person, None, Kind::Person, "Thomas Müller".to_string(), Policy::Always)
        .expect("value");
    add_value_alias(person, name, "Herr Müller".to_string()).expect("alias");

    let mut config = settings().expect("settings");
    config.first_run_done = true;
    config.language = "de".to_string();
    save_settings(config).expect("save");

    say("identities taught", format!("{}", entities(None).expect("entities").len()));

    // The document, scanned on import as the app does it.
    let s = open_session(Some(profile), "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    let report = scan(s).expect("scan");
    say(
        "scan",
        format!("{} auto · {} to review · {} normal", report.auto, report.suggested, report.normal),
    );
    for layer in &report.by_layer {
        say(&format!("  by {:?}", layer.source), format!("{}", layer.count));
    }

    // Answer the review, as the product insists.
    let open: Vec<u32> = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| f.id)
        .collect();
    say("answered", format!("{}", open.len()));
    for id in open {
        answer_finding(s, id, FindingAnswer::Protect).expect("answer");
    }

    let handle = build_payload(s).expect("build");
    let view = payload_view(handle).expect("view");
    say("payload", format!("{} chars · {} replaced", view.text.len(), view.protected_count));

    // The claim, checked here as well as in the tests: nothing of the original.
    let leaked: Vec<&str> = [
        "Nordstern Consulting GmbH",
        "Thomas Müller",
        "DE89370400440532013000",
        "t.mueller@nordstern-consulting.de",
        "DE811728394",
        "+49 171 2345678",
    ]
    .into_iter()
    .filter(|v| view.text.contains(v))
    .collect();
    say("values in the payload", format!("{} (must be 0)", leaked.len()));

    // The manual door: the answer comes back by hand, and restores.
    let answer = ingest_answer(s, format!("Zusammenfassung:\n{}", view.text)).expect("ingest");
    let restored: String = restored_view(s, answer)
        .expect("restore")
        .into_iter()
        .map(|seg| seg.text)
        .collect();
    say(
        "restored holds the name",
        format!("{}", restored.contains("Thomas Müller")),
    );

    vault_lock().expect("lock");
    say("vault at the end", format!("{:?}", vault_state().expect("state")));
    println!("\n  (this process now ends — nothing is kept but the vault file)\n");
}

fn again() {
    println!("RUN TWO — the same folder, a new process");
    say("vault found", format!("{:?}", vault_state().expect("state")));
    match vault_unlock_with_passphrase("das falsche Passwort".to_string()) {
        Err(ApiError::VaultAuthenticationFailed) => say("could not authenticate", "refused".to_string()),
        other => say("could not authenticate", format!("UNEXPECTED {other:?}")),
    }
    match vault_unlock_with_passphrase(PASS.to_string()).expect("unlock") {
        VaultUnlockOutcome::Unlocked { identities, values } => {
            say("opened", format!("{identities} identities · {values} values"))
        }
    }

    let config = settings().expect("settings");
    say(
        "settings survived",
        format!(
            "first_run_done={} language={} session_only={}",
            config.first_run_done, config.language, config.session_only
        ),
    );

    let profile = profiles().expect("profiles").first().map(|p| p.id.clone());
    say("profiles", format!("{}", profiles().expect("profiles").len()));
    say("search «Herr»", format!("{}", search_vault("Herr".to_string()).expect("search").len()));

    // The same document again: what was taught by hand is found by itself now.
    let s = open_session(profile, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    let report = scan(s).expect("scan");
    say(
        "scan after restart",
        format!("{} auto · {} to review · {} normal", report.auto, report.suggested, report.normal),
    );
    for layer in &report.by_layer {
        say(&format!("  by {:?}", layer.source), format!("{}", layer.count));
    }
    println!();
}

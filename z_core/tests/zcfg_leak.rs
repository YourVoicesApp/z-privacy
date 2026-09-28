// ZCFG after a whole journey: what is in the one unencrypted file we write.
//
// The owner allowed this file on 27 September and drew the line himself:
//
//   > If the information could say anything about the user's work or their
//   > clients, it does not belong in ZCFG.
//
// So this test does the work first — a vault, a client taught by hand, a German
// document, protections, a payload, an answer, settings saved — and only then
// opens the file and reads it. Everything the user touched is on the forbidden
// list; the four allowed names are the control strings, because a search that
// finds nothing proves nothing until it is shown to find something.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const PASS: &str = "ein langes Passwort für diese Reise";

const DOC: &str = "Angebot 2026-114\n\
Kunde: Nordstern Consulting GmbH\n\
Ansprechpartner: Herr Thomas Müller\n\
E-Mail: t.mueller@nordstern-consulting.de\n\
IBAN: DE89370400440532013000\n\
Frau Anna Weber vertritt ihn im Urlaub.";

/// Everything a person touched in the journey below. None of it may be in the file.
const NOTHING_OF_THIS: &[&str] = &[
    "Nordstern",
    "Consulting",
    "Thomas",
    "Müller",
    "Anna",
    "Weber",
    "t.mueller@nordstern-consulting.de",
    "DE89370400440532013000",
    "Angebot",
    "Vertrag",
    "2026-114",
    "Client",
    "sk-",
    "__Z_",
];

#[test]
fn nothing_of_the_user_s_work_reaches_the_settings_file() {
    let dir = std::env::temp_dir().join(format!("zprivacy-zcfg-journey-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");

    // ---------------------------------------------------------- the journey
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    let profile = create_profile("Client Nordstern".to_string()).expect("profile");
    let client = create_entity(EntityKind::Client, "Nordstern".to_string(), Some(profile.clone()))
        .expect("entity");
    let value = set_value(
        client,
        None,
        Kind::Company,
        "Nordstern Consulting GmbH".to_string(),
        Policy::Always,
    )
    .expect("value");
    add_value_alias(client, value, "Nordstern".to_string()).expect("alias");

    let s = open_session(Some(profile), "de".to_string()).expect("session");
    import_document(
        s,
        "Angebot_Nordstern_2026-114.txt".to_string(),
        DOC.as_bytes().to_vec(),
        DocumentKind::Txt,
    )
    .expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    let handle = build_payload(s).expect("build");
    let view = payload_view(handle).expect("view");
    let answer = ingest_answer(handle, format!("Danke.\n{}", view.text)).expect("answer");
    let _ = restored_view(s, answer).expect("restore");
    connect_provider(
        ProviderId { id: "openai".to_string() },
        "sk-test-not-a-real-credential".to_string(),
        Some("https://api.openai.com".to_string()),
        Some("gpt-4o-mini".to_string()),
    )
    .expect("connect");
    search_vault("Müller".to_string()).expect("search");

    let mut config = settings().expect("settings");
    config.first_run_done = true;
    config.language = "de".to_string();
    save_settings(config).expect("save");

    // ---------------------------------------------------------- the file
    let path = dir.join("settings.zcfg");
    let text = std::fs::read_to_string(&path).expect("the settings file exists");

    // Control strings first: the search has to be able to find what is there.
    for allowed in ["ZCFG1", "schema_version=1", "first_run_completed=true", "ui_language=de"] {
        assert!(text.contains(allowed), "«{allowed}» is missing:\n{text}");
    }
    // And a second control: the tokens really were minted, so «no __Z_ in the
    // file» is a statement about the file and not about an empty journey.
    assert!(!list_tokens(s).expect("tokens").is_empty(), "the journey protected nothing");
    assert!(view.text.contains("__Z_"), "the payload holds tokens");

    // The claim.
    for secret in NOTHING_OF_THIS {
        assert!(
            !text.contains(secret),
            "«{secret}» reached the unencrypted settings file:\n{text}"
        );
    }
    // And the shape: a header and exactly the four allowed names.
    let keys: Vec<&str> = text
        .lines()
        .skip(1)
        .filter_map(|l| l.split_once('=').map(|(k, _)| k))
        .collect();
    assert_eq!(
        keys,
        ["schema_version", "first_run_completed", "ui_language", "default_privacy_pack"],
        "the file holds the allowlist and nothing else"
    );

    // The vault file beside it is the opposite case: it holds everything, and
    // holds it sealed. Saying so here keeps the two straight.
    let vault_bytes = std::fs::read(dir.join("vault.zv")).expect("the vault file exists");
    for secret in ["Nordstern", "Müller", "DE89370400440532013000", "sk-test"] {
        assert!(
            !vault_bytes
                .windows(secret.len())
                .any(|w| w == secret.as_bytes()),
            "«{secret}» is readable in the vault file"
        );
    }

    let _ = std::fs::remove_dir_all(&dir);
}

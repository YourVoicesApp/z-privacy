// The vault as the fourth layer, and the owner's four rules for M4.
//
// The vault is one per device, so these tests share it: each one takes the lock
// below, points the core at its own folder, and builds the vault it needs.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für den Test";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// A fresh, empty vault in a folder of this test's own.
fn fresh_vault(name: &str) -> String {
    let dir = std::env::temp_dir().join(format!("zprivacy-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    let path = dir.to_string_lossy().to_string();
    set_data_dir(path.clone()).expect("data dir");
    assert_eq!(vault_state().expect("state"), VaultState::Absent);
    match vault_create_with_passphrase(PASS.to_string()).expect("create") {
        VaultUnlockOutcome::Unlocked { identities, values } => assert_eq!((identities, values), (0, 0)),
        other => panic!("expected a new vault, got {other:?}"),
    }
    path
}

/// An identity holding one value, with its spellings.
fn identity(label: &str, profile: Option<&str>, kind: Kind, value: &str, aliases: &[&str], policy: Policy) -> u32 {
    let id = create_entity(EntityKind::Client, label.to_string(), profile.map(str::to_string)).expect("entity");
    let value_id = set_value(id, None, kind, value.to_string(), policy).expect("value");
    for alias in aliases {
        add_value_alias(id, value_id, (*alias).to_string()).expect("alias");
    }
    id
}

const DOC: &str = "Kunde: Nordstern Consulting GmbH\nAnsprechpartner: Herr Thomas Müller\nFrau Anna Weber vertritt ihn.";

fn scanned(profile: Option<&str>) -> (SessionId, ScanReport) {
    let s = open_session(profile.map(str::to_string), "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    let report = scan(s).expect("scan");
    (s, report)
}

fn states(s: SessionId) -> (Vec<String>, Vec<String>) {
    let findings = list_findings(s).expect("findings");
    let text_of = |f: &Finding| {
        DOC.chars()
            .skip(f.span.start as usize)
            .take((f.span.end - f.span.start) as usize)
            .collect::<String>()
    };
    let auto = findings
        .iter()
        .filter(|f| f.state == MarkState::Protected)
        .map(text_of)
        .collect();
    let open = findings
        .iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(text_of)
        .collect();
    (auto, open)
}

#[test]
fn rule_one_a_locked_vault_skips_its_layer_and_says_so() {
    let _guard = serial();
    fresh_vault("rule-one");
    identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);

    // Open: the vault recognises its own client.
    let (_s, open_report) = scanned(None);
    assert_eq!(open_report.vault, VaultState::Unlocked);
    assert!(open_report.auto >= 1, "the vault knows the company: {open_report:?}");

    // Locked: the same document, the same rules and pack — but nobody is known.
    vault_lock().expect("lock");
    let (locked_session, locked_report) = scanned(None);
    assert_eq!(locked_report.vault, VaultState::Locked, "the report says it out loud");
    let (auto, open) = states(locked_session);
    assert!(
        auto.is_empty(),
        "nothing in this document can be proven without the vault: {auto:?}"
    );
    assert_eq!(open.len(), 3, "the pack still guesses: two names and a company");
}

#[test]
fn rule_two_only_what_the_vault_actually_holds_becomes_automatic() {
    let _guard = serial();
    fresh_vault("rule-two");
    // The vault knows the company and Thomas Müller. It has never heard of Anna Weber.
    identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);
    identity("Kontakt", None, Kind::Person, "Thomas Müller", &["Herr Müller"], Policy::Always);

    let (s, report) = scanned(None);
    let (auto, open) = states(s);
    assert_eq!(report.vault, VaultState::Unlocked);
    assert!(auto.contains(&"Nordstern Consulting GmbH".to_string()), "{auto:?}");
    assert!(auto.contains(&"Thomas Müller".to_string()), "{auto:?}");
    assert_eq!(
        open,
        vec!["Anna Weber".to_string()],
        "a name the vault does not hold stays a question: opening the vault is not a blank cheque"
    );

    // And the identity is named in the finding, so the UI can say «from CLIENT #1».
    let company = list_findings(s)
        .expect("findings")
        .into_iter()
        .find(|f| f.kind == Kind::Company)
        .expect("the company");
    assert_eq!(company.source, Source::Vault);
    assert_eq!(company.entities, vec!["CLIENT #01".to_string()]);
    assert!(company.reason.contains("your vault knows this"), "{}", company.reason);
}

#[test]
fn rule_two_a_value_in_another_profile_is_not_loaded() {
    let _guard = serial();
    fresh_vault("rule-two-profile");
    let other = create_profile("Client Andere".to_string()).expect("profile");
    identity("Andere", Some(&other), Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);

    // No profile active: an entity that belongs to one profile is not loaded.
    let (s, _) = scanned(None);
    let (auto, open) = states(s);
    assert!(auto.is_empty(), "{auto:?}");
    assert!(open.contains(&"Nordstern Consulting GmbH".to_string()), "still only a guess");

    // With that profile active, the same value is recognised.
    let (s2, _) = scanned(Some(&other));
    let (auto2, _) = states(s2);
    assert!(auto2.contains(&"Nordstern Consulting GmbH".to_string()), "{auto2:?}");
}

#[test]
fn rule_three_one_spelling_two_identities_is_a_conflict_not_a_choice() {
    let _guard = serial();
    fresh_vault("rule-three");
    // Two clients, and the same short spelling on both. A real case: two companies
    // whose short name is the same word.
    identity("Erste", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);
    identity("Zweite", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);

    let (s, report) = scanned(None);
    let findings = list_findings(s).expect("findings");
    let company = findings
        .iter()
        .find(|f| f.kind == Kind::Company && f.source == Source::Vault)
        .expect("the company");

    assert_eq!(company.state, MarkState::Suggested, "a conflict is never settled silently");
    assert_eq!(company.entities.len(), 2, "both claimants are named: {:?}", company.entities);
    assert!(company.reason.contains("two identities"), "{}", company.reason);
    assert!(report.suggested >= 1);

    // And because it is open, nothing can be sent yet — G12 covers the conflict too.
    let handle = build_payload(s).expect("build");
    assert!(matches!(
        send(handle, ProviderId { id: "openai".to_string() }),
        Err(ApiError::OpenSuggestions { .. })
    ));
}

#[test]
fn rule_four_the_passphrase_can_change_and_the_vault_still_opens() {
    let _guard = serial();
    let dir = fresh_vault("rule-four");
    let id = identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &["Nordstern"], Policy::Always);

    vault_change_passphrase(PASS.to_string(), "ein anderes langes Passwort".to_string()).expect("change");
    vault_lock().expect("lock");

    // The old passphrase is dead; the new one opens the same contents.
    assert!(matches!(
        vault_unlock_with_passphrase(PASS.to_string()).expect("answer"),
        VaultUnlockOutcome::WrongPassphrase
    ));
    match vault_unlock_with_passphrase("ein anderes langes Passwort".to_string()).expect("unlock") {
        VaultUnlockOutcome::Unlocked { identities, values } => assert_eq!((identities, values), (1, 1)),
        other => panic!("expected the vault to open, got {other:?}"),
    }

    let card = entity(id).expect("the identity");
    assert_eq!(card.label, "Nordstern");
    assert_eq!(card.values.len(), 1);
    assert_eq!(card.values[0].aliases, 1);
    assert_eq!(card.values[0].policy, Policy::Always);

    // The value itself needs asking for, by name.
    let shown = reveal_value(id, card.values[0].id).expect("reveal");
    assert_eq!(shown.value, "Nordstern Consulting GmbH");
    assert!(shown.ttl_ms > 0);
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
fn a_manual_value_is_kept_but_never_hunted() {
    let _guard = serial();
    fresh_vault("manual");
    identity("Eigene", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Manual);

    let (s, _) = scanned(None);
    let findings = list_findings(s).expect("findings");
    assert!(
        !findings.iter().any(|f| f.source == Source::Vault),
        "Manual means: kept here, found by nobody"
    );
}

#[test]
fn the_vault_list_and_its_cards_never_print_a_value() {
    let _guard = serial();
    fresh_vault("redaction");
    let id = identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);

    // G11 again, at this level: the list and the card are safe to log.
    let rows = entities(None).expect("entities");
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].policy_summary, "1 always");
    assert!(!format!("{rows:?}").contains("Nordstern"), "{rows:?}");
    let card = entity(id).expect("card");
    assert!(!format!("{card:?}").contains("Nordstern"), "{card:?}");
}

#[test]
fn switching_a_profile_keeps_the_tokens_already_given() {
    let _guard = serial();
    fresh_vault("switch");
    let p1 = create_profile("Client Eins".to_string()).expect("profile");
    let p2 = create_profile("Client Zwei".to_string()).expect("profile");
    identity("Eins", Some(&p1), Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);

    let (s, _) = scanned(Some(&p1));
    let before = list_tokens(s).expect("tokens");
    assert_eq!(before.len(), 1, "the company was recognised");
    let token_before = before[0].token.clone();

    // Switch to a profile that knows nothing: what was protected stays protected.
    let outcome = switch_profile(s, p2.clone()).expect("switch");
    assert_eq!(outcome.kept_tokens, 1);
    let after = list_tokens(s).expect("tokens");
    assert!(
        after.iter().any(|t| t.token == token_before),
        "a token once given is never silently taken back: {after:?}"
    );
    let safe = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert!(!safe.contains("Nordstern Consulting GmbH"));
}

/// The turn the owner described: with the vault open, the golden document has
/// nothing left to ask about.
#[test]
fn the_golden_document_with_an_open_vault_asks_nothing() {
    let _guard = serial();
    fresh_vault("golden");
    let fixture = include_str!("fixtures/Vertrag_Nordstern.txt");

    let profile = create_profile("Client Nordstern".to_string()).expect("profile");
    identity(
        "Nordstern Consulting",
        Some(&profile),
        Kind::Company,
        "Nordstern Consulting GmbH",
        &["Nordstern"],
        Policy::Always,
    );
    identity(
        "Thomas Müller",
        Some(&profile),
        Kind::Person,
        "Thomas Müller",
        &["Herr Müller", "T. Müller"],
        Policy::Always,
    );

    let s = open_session(Some(profile), "de".to_string()).expect("open");
    import_text(s, fixture.to_string()).expect("import");
    let report = scan(s).expect("scan");

    assert_eq!(report.vault, VaultState::Unlocked);
    assert_eq!(
        (report.auto, report.suggested),
        (9, 0),
        "seven by arithmetic and label, two more because the vault knows them: {report:?}"
    );

    // The two that were questions in M3 are now answered by the vault itself.
    let findings = list_findings(s).expect("findings");
    let from_vault: Vec<&Finding> = findings.iter().filter(|f| f.source == Source::Vault).collect();
    assert_eq!(from_vault.len(), 2, "{from_vault:?}");
    assert!(from_vault.iter().all(|f| f.state == MarkState::Protected));
    assert!(from_vault.iter().all(|f| f.entities.len() == 1));

    // And so the document can go, with nothing left in the clear.
    let handle = build_payload(s).expect("build");
    let safe = payload_view(handle).expect("view").text;
    assert!(!safe.contains("Nordstern"), "{safe}");
    assert!(!safe.contains("Müller"), "{safe}");
    assert!(matches!(
        send(handle, ProviderId { id: "openai".to_string() }),
        Err(ApiError::NetworkRefused {
            reason: NetworkRefusal::NotConnected,
            ..
        })
    ));

    // The by-layer summary now names three layers, the vault among them.
    assert!(report.by_layer.iter().any(|l| l.source == Source::Vault && l.count == 2), "{:?}", report.by_layer);
}

// ---------------------------------------------------------------- M7.8
// The vault as a room the user manages, not only a layer the scanner reads.

#[test]
fn an_identity_can_be_renamed_moved_and_pruned() {
    let _lock = serial();
    fresh_vault("manage");
    let profile = create_profile("Client A".to_string()).expect("profile");
    let id = identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &["Nordstern"], Policy::Always);

    rename_entity(id, "Nordstern Consulting".to_string()).expect("rename");
    assert_eq!(entity(id).expect("card").label, "Nordstern Consulting");
    assert!(rename_entity(id, "   ".to_string()).is_err(), "an identity needs a name");

    // Moving to a profile that does not exist is refused, not silently done:
    // an identity in a profile nobody can pick is a value never found again.
    match move_entity(id, Some("p-does-not-exist".to_string())) {
        Err(ApiError::ImportRefused { reason }) => assert!(reason.contains("profile"), "{reason}"),
        other => panic!("expected a refusal, got {other:?}"),
    }
    move_entity(id, Some(profile.clone())).expect("move");
    assert_eq!(entity(id).expect("card").profile_id, Some(profile));
    move_entity(id, None).expect("back to everywhere");
    assert_eq!(entity(id).expect("card").profile_id, None);

    // One value, one spelling, each removable on its own.
    let value = entity(id).expect("card").values[0].id;
    add_value_alias(id, value, "NC GmbH".to_string()).expect("alias");
    assert_eq!(reveal_value(id, value).expect("reveal").aliases.len(), 2);
    remove_value_alias(id, value, "NC GmbH".to_string()).expect("forget a spelling");
    assert_eq!(reveal_value(id, value).expect("reveal").aliases, vec!["Nordstern".to_string()]);
    assert!(remove_value_alias(id, value, "never written".to_string()).is_err());

    delete_value(id, value).expect("forget the value");
    assert!(entity(id).expect("card").values.is_empty(), "the identity stays, the value goes");
    assert!(delete_value(id, value).is_err(), "and twice is an error, not a silent no-op");
}

#[test]
fn searching_the_vault_finds_by_value_and_says_nothing_about_why() {
    let _lock = serial();
    fresh_vault("search");
    let nordstern = identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &["NC"], Policy::Always);
    let mueller = identity("Müller", None, Kind::Person, "Thomas Müller", &["Herr Müller"], Policy::Always);
    set_value(mueller, None, Kind::Iban, "DE89370400440532013000".to_string(), Policy::Always).expect("iban");

    // By label, by value, by alias — and the IBAN, which no label mentions.
    assert_eq!(search_vault("nordstern".to_string()).expect("search").len(), 1);
    assert_eq!(search_vault("Thomas".to_string()).expect("search")[0].id, mueller);
    assert_eq!(search_vault("herr".to_string()).expect("search")[0].id, mueller);
    assert_eq!(search_vault("DE8937".to_string()).expect("search")[0].id, mueller);
    assert_eq!(search_vault("NC".to_string()).expect("search")[0].id, nordstern);
    assert!(search_vault("nothing like this".to_string()).expect("search").is_empty());
    assert_eq!(search_vault("  ".to_string()).expect("search").len(), 2, "an empty query is everything");

    // The row says who, and nothing about what matched — a result that read
    // «matched on its IBAN» would print a fact about a secret.
    let row = &search_vault("DE8937".to_string()).expect("search")[0];
    assert!(!format!("{row:?}").contains("DE89"), "{row:?}");
}

#[test]
fn the_kinds_are_a_list_the_core_hands_over_not_a_set_the_screen_knows() {
    let rows = kinds().expect("kinds");
    assert!(rows.len() >= 14, "every kind is listed");
    assert!(rows.iter().all(|k| !k.label.is_empty()), "each one is named by the core");
    assert!(rows.iter().all(|k| !k.custom), "no user-made kinds yet, and the field says so");
    // The escape hatch exists and is named for a person, not for a programmer.
    let other = rows.iter().find(|k| k.kind == Kind::Custom).expect("Custom is in the list");
    assert_eq!(other.label, "Something else");
}

#[test]
fn settings_live_in_the_vault_and_say_when_they_do_not() {
    let _lock = serial();
    // No vault yet: the settings are this run's, and they admit it.
    set_data_dir(std::env::temp_dir().join(format!("zprivacy-settings-{}", std::process::id())).to_string_lossy().to_string())
        .expect("dir");
    let before = settings().expect("settings");
    assert!(before.session_only, "with no vault, nothing is remembered and the row says so");
    assert!(before.scan_on_import, "nobody has to press anything to be protected");
    assert!(!before.first_run_done);

    // A vault, and they have somewhere to live.
    fresh_vault("settings");
    let mut want = settings().expect("settings");
    assert!(!want.session_only, "an open vault keeps them");
    want.first_run_done = true;
    want.language = "de".to_string();
    want.auto_lock_minutes = 7;
    // Out-of-range numbers are bounded here, not trusted: a screen's bug must
    // not become a policy.
    want.reveal_seconds = 100_000;
    let saved = save_settings(want).expect("save");
    assert_eq!(saved.reveal_seconds, 300, "clamped, not taken as written");
    assert_eq!(saved.auto_lock_minutes, 7);
    assert!(saved.first_run_done);

    // Locked and opened again: they came back from the file.
    vault_lock().expect("lock");
    assert!(settings().expect("settings").session_only, "a locked vault keeps nothing readable");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    let back = settings().expect("settings");
    assert_eq!(back.language, "de");
    assert_eq!(back.auto_lock_minutes, 7);
    assert!(back.first_run_done, "the first run is remembered because there was a vault to remember it");
}

#[test]
fn auto_lock_is_the_vault_s_own_promise_not_a_timer_in_a_screen() {
    let _lock = serial();
    fresh_vault("autolock");
    identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);
    assert_eq!(vault_state().expect("state"), VaultState::Unlocked);

    // A limit that has already passed. No screen is involved, and no timer runs:
    // the next way in checks the clock, which is what makes this a promise the
    // vault keeps rather than one the UI remembers to keep.
    let mut s = settings().expect("settings");
    s.auto_lock_minutes = 1;
    save_settings(s).expect("save");
    assert_eq!(vault_state().expect("state"), VaultState::Unlocked, "one minute has not passed");

    // And zero means never, which must not be read as «lock at once».
    let mut s = settings().expect("settings");
    s.auto_lock_minutes = 0;
    save_settings(s).expect("save");
    assert_eq!(vault_state().expect("state"), VaultState::Unlocked);
    assert_eq!(entities(None).expect("entities").len(), 1, "and the vault is still readable");
}

#[test]
fn zcfg_remembers_the_first_run_on_a_device_with_no_vault() {
    let _lock = serial();
    let dir = std::env::temp_dir().join(format!("zprivacy-zcfg-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");

    // No vault, and none is going to be made. This is the case the owner
    // allowed the file for: a person may work in copy-and-paste for years.
    assert_eq!(vault_state().expect("state"), VaultState::Absent);
    let before = settings().expect("settings");
    assert!(!before.first_run_done);

    let mut want = before;
    want.first_run_done = true;
    want.language = "de".to_string();
    let saved = save_settings(want).expect("save");
    assert!(saved.first_run_done);
    assert!(saved.session_only, "the behaviour settings still need a vault, and say so");

    // Point the core somewhere else and back: the file is read again from disk,
    // which is as close to a restart as one process can get.
    let elsewhere = dir.join("elsewhere");
    set_data_dir(elsewhere.to_string_lossy().to_string()).expect("dir");
    assert!(!settings().expect("settings").first_run_done, "a different folder knows nothing");
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    let back = settings().expect("settings");
    assert!(back.first_run_done, "and the first folder remembers");
    assert_eq!(back.language, "de");

    // The file itself: readable, and holding only the four allowed names.
    let text = std::fs::read_to_string(dir.join("settings.zcfg")).expect("the file exists");
    assert!(text.starts_with("ZCFG1"));
    for name in ["schema_version", "first_run_completed", "ui_language", "default_privacy_pack"] {
        assert!(text.contains(name), "{name} is missing from {text}");
    }
    assert_eq!(text.lines().count(), 5, "a header and four settings, nothing else:\n{text}");

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn zcfg_refuses_a_value_that_could_name_a_client() {
    let _lock = serial();
    let dir = std::env::temp_dir().join(format!("zprivacy-zcfg-bad-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");

    let mut want = settings().expect("settings");
    want.language = "Nordstern Consulting GmbH".to_string();
    match save_settings(want) {
        Err(ApiError::ImportRefused { reason }) => {
            assert!(reason.contains("plain tag"), "{reason}");
        }
        other => panic!("a client's name must not be writable to ZCFG, got {other:?}"),
    }
    assert!(
        !dir.join("settings.zcfg").exists(),
        "and nothing was written at all"
    );
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn a_wrong_passphrase_reports_nothing_it_does_not_know() {
    let _lock = serial();
    // The «0 tries left» lie, as a rule rather than a fix: the refusal carries
    // no number, because there is no counter to carry one from.
    let dir = std::env::temp_dir().join(format!("zprivacy-truth-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase("ein gutes Passwort für den Test".to_string()).expect("create");
    vault_lock().expect("lock");

    // Wrong, three times. Nothing counts down, and the third try is as welcome
    // as the first — which is the honest behaviour for a local file.
    for _ in 0..3 {
        assert_eq!(
            vault_unlock_with_passphrase("falsch".to_string()).expect("unlock"),
            VaultUnlockOutcome::WrongPassphrase
        );
    }
    assert!(matches!(
        vault_unlock_with_passphrase("ein gutes Passwort für den Test".to_string()).expect("unlock"),
        VaultUnlockOutcome::Unlocked { .. }
    ));
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn always_and_profile_actually_reach_the_vault() {
    let _lock = serial();
    fresh_vault("scope");
    let profile = create_profile("Client Nordstern".to_string()).expect("profile");

    // «Always» — every profile. The dialog has promised this since M7.3 and
    // nothing wrote it down until task 034.
    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, "Ansprechpartner: Herr Thomas Müller ruft an.".to_string()).expect("import");
    scan(s).expect("scan");
    protect(s, Span { start: 22, end: 35 }, Scope::Always, Kind::Person).expect("always");
    assert_eq!(
        search_vault("Thomas Müller".to_string()).expect("search").len(),
        1,
        "«always» did not put the name in the vault"
    );
    close_session(s).expect("close");

    // And the proof it was a promise about tomorrow: a **new** conversation,
    // which has never seen this name, finds it by itself.
    let tomorrow = open_session(None, "de".to_string()).expect("session");
    import_text(tomorrow, "Thomas Müller hat angerufen.".to_string()).expect("import");
    let report = scan(tomorrow).expect("scan");
    assert!(
        report.by_layer.iter().any(|l| l.source == Source::Vault && l.count > 0),
        "the vault layer did not find what «always» taught it: {:?}",
        report.by_layer
    );
    close_session(tomorrow).expect("close");

    // «Profile» — this client only. The level a firm with several clients
    // needs: what you learn about one does not become a rule about all.
    let theirs = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(theirs, "Kunde: Nordstern Consulting GmbH ist zufrieden.".to_string()).expect("import");
    scan(theirs).expect("scan");
    protect(theirs, Span { start: 7, end: 32 }, Scope::Profile, Kind::Company).expect("profile");
    close_session(theirs).expect("close");

    // In that client's profile it is known.
    let same_client = open_session(Some(profile), "de".to_string()).expect("session");
    import_text(same_client, "Nordstern Consulting GmbH meldet sich.".to_string()).expect("import");
    let inside = scan(same_client).expect("scan");
    assert!(
        inside.by_layer.iter().any(|l| l.source == Source::Vault && l.count > 0),
        "the client's own profile does not know its own client: {:?}",
        inside.by_layer
    );
    close_session(same_client).expect("close");

    // In another client's, it is not — and that is the whole point of the scope.
    let other = create_profile("Client B".to_string()).expect("profile");
    let elsewhere = open_session(Some(other), "de".to_string()).expect("session");
    import_text(elsewhere, "Nordstern Consulting GmbH meldet sich.".to_string()).expect("import");
    let outside = scan(elsewhere).expect("scan");
    assert!(
        !outside.by_layer.iter().any(|l| l.source == Source::Vault && l.count > 0),
        "one client's value became a rule about another: {:?}",
        outside.by_layer
    );
    close_session(elsewhere).expect("close");
}

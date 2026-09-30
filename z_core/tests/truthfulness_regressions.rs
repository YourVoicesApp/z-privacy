// The ten lies of the human run, as a regression suite.
//
// Each test is named after the lie it makes impossible. The screen now draws
// a snapshot; these tests pin the snapshot facts that used to drift.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const DOC: &str = "Kunde: Nordstern Consulting GmbH\n\
Ansprechpartner: Herr Thomas Müller\n\
IBAN: DE89370400440532013000";
const PASS: &str = "ein gutes Passwort für die Reise";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

fn fresh_dir(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-lie-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
}

fn session_with_doc() -> SessionId {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    s
}

fn span_of(doc: &str, needle: &str) -> Span {
    let start = doc.find(needle).expect("needle") as u32;
    Span {
        start,
        end: start + needle.len() as u32,
    }
}

#[test]
fn lie_always_without_vault_names_which_vault_is_missing() {
    let _g = serial();
    fresh_dir("always");
    let s = session_with_doc();
    scan(s).expect("scan");

    // Nothing on this device: the next move is to **make** a vault, so the
    // refusal has to be the one that says that. `VaultRequired` named the act's
    // need and left the person to guess whether there was a vault to open at
    // all — and the screen it reached could only repeat the guess.
    match protect(s, span_of(DOC, "Thomas Müller"), Scope::Always, Kind::Person) {
        Err(ApiError::VaultAbsent) => {}
        other => panic!("absent, by protect: got {other:?}"),
    }
    // The same for the button a person actually presses in the review.
    let open = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| f.id)
        .collect::<Vec<_>>();
    assert!(!open.is_empty(), "the document has something to answer");
    match answer_finding(s, open[0], FindingAnswer::Always) {
        Err(ApiError::VaultAbsent) => {}
        other => panic!("absent, by Always: got {other:?}"),
    }

    // A vault that exists and is shut is a different sentence and a different
    // next move: unlock it. One refusal for two states could be neither.
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    vault_lock().expect("lock");
    match answer_finding(s, open[0], FindingAnswer::Always) {
        Err(ApiError::VaultLocked) => {}
        other => panic!("locked, by Always: got {other:?}"),
    }
    close_session(s).ok();
}

#[test]
fn lie_missing_credential_never_claims_a_home() {
    let _g = serial();
    fresh_dir("cred");
    let _ = disconnect_provider(ProviderId { id: "openai".to_string() });
    for p in provider_snapshot().expect("snap").providers {
        if p.credential_state == CredentialState::Missing {
            assert!(!p.configured);
        }
    }
}

#[test]
fn lie_why_matches_the_core_right_now() {
    let _g = serial();
    fresh_dir("why");
    let s = session_with_doc();
    scan(s).expect("scan");
    protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person).expect("protect");
    let why = explain(s, span_of(DOC, "Thomas Müller")).expect("explain");
    assert_eq!(why.scope, Scope::Conversation);
    close_session(s).ok();
}

#[test]
fn lie_forget_refreshes_the_explanation() {
    let _g = serial();
    fresh_dir("forget");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    let entity = create_entity(EntityKind::Person, "Kontakt".to_string(), None).expect("e");
    let value = set_value(entity, None, Kind::Person, "Thomas Müller".to_string(), Policy::Always).expect("v");
    let s = session_with_doc();
    scan(s).expect("scan");
    let before = explain(s, span_of(DOC, "Thomas Müller")).expect("before");
    forget_value(entity, value, true).expect("forget");
    let after = explain(s, span_of(DOC, "Thomas Müller")).expect("after");
    assert!(
        after.entity != before.entity || after.value_id != Some(value) || after.headline != before.headline,
        "forgetting must change what Why says"
    );
    close_session(s).ok();
}

#[test]
fn lie_undo_availability_matches_undo() {
    let _g = serial();
    fresh_dir("undo");
    let s = session_with_doc();
    scan(s).expect("scan");
    let can = workspace_snapshot(s).expect("snap").can_undo;
    match undo_last_protection(s).expect("undo") {
        UndoOutcome::NothingToUndo => assert!(!can),
        UndoOutcome::Undone { .. } => assert!(can),
    }
    close_session(s).ok();
}

#[test]
fn lie_connect_is_visible_on_the_next_snapshot() {
    let _g = serial();
    fresh_dir("connect");
    let _ = disconnect_provider(ProviderId { id: "openai".to_string() });
    connect_provider(
        ProviderId { id: "openai".to_string() },
        "sk-test".to_string(),
        Some("https://api.openai.com".to_string()),
        None,
    )
    .expect("connect");
    let p = provider_snapshot()
        .expect("snap")
        .providers
        .into_iter()
        .find(|p| p.id == "openai")
        .expect("openai");
    assert!(p.configured);
    assert_ne!(p.credential_state, CredentialState::Missing);
    disconnect_provider(ProviderId { id: "openai".to_string() }).ok();
}

#[test]
fn lie_protected_counts_are_one_canonical_set() {
    let _g = serial();
    fresh_dir("counts");
    let s = session_with_doc();
    scan(s).expect("scan");
    let snap = workspace_snapshot(s).expect("snap");
    let auto = snap.findings.iter().filter(|f| f.state == MarkState::Protected && !f.decided).count() as u32;
    let user = snap.findings.iter().filter(|f| f.state == MarkState::Protected && f.decided).count() as u32;
    let open = snap.findings.iter().filter(|f| f.state == MarkState::Suggested).count() as u32;
    assert_eq!(snap.auto_protected, auto);
    assert_eq!(snap.user_protected, user);
    assert_eq!(snap.open_suggestions, open);
    close_session(s).ok();
}

#[test]
fn lie_vault_header_and_body_share_one_snapshot() {
    let _g = serial();
    fresh_dir("vault");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    let e = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("e");
    set_value(e, None, Kind::Company, "Nordstern Consulting GmbH".to_string(), Policy::Always).expect("v");
    let snap = vault_snapshot().expect("snap");
    assert_eq!(snap.identity_count as usize, 1);
    assert_eq!(snap.value_count as usize, snap.taught_values.len());
    let home = home_snapshot().expect("home");
    assert_eq!(home.identity_count, snap.identity_count);
    assert_eq!(home.value_count, snap.value_count);
}

#[test]
fn lie_rescan_is_named_a_rescan() {
    let _g = serial();
    fresh_dir("rescan");
    let s = session_with_doc();
    scan(s).expect("import scan");
    assert_eq!(workspace_snapshot(s).unwrap().scan_origin, ScanOrigin::OnImport);
    scan(s).expect("rescan");
    assert_eq!(workspace_snapshot(s).unwrap().scan_origin, ScanOrigin::Rescan);
    close_session(s).ok();
}

#[test]
fn lie_taught_values_are_not_search_results() {
    let _g = serial();
    fresh_dir("taught");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    let a = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("a");
    set_value(a, None, Kind::Company, "Nordstern Consulting GmbH".to_string(), Policy::Always).expect("v");
    let b = create_entity(EntityKind::Person, "Kontakt".to_string(), None).expect("b");
    set_value(b, None, Kind::Person, "Thomas Müller".to_string(), Policy::Always).expect("v2");
    let snap = vault_snapshot().expect("snap");
    let hits = search_vault("Thomas".to_string()).expect("search");
    assert_eq!(snap.value_count, 2);
    assert_eq!(hits.len(), 1);
}

#[test]
fn a_displayed_mutation_bumps_state_revision() {
    let _g = serial();
    fresh_dir("rev");
    let s = session_with_doc();
    let before = workspace_snapshot(s).unwrap().state_revision;
    scan(s).expect("scan");
    assert!(workspace_snapshot(s).unwrap().state_revision > before);
    close_session(s).ok();
}

/// P2-4 — the eleventh lie: a login record is not a credential.
///
/// Connecting a model on this machine stores a login with an empty credential.
/// The snapshot used to read «is there a record?» and answer `EncryptedInVault`,
/// so the vault card claimed to hold a key for the one door whose own text is
/// «No key, no account», and the form offered to forget it.
#[test]
fn lie_a_keyless_login_claims_a_key() {
    let _g = serial();
    fresh_dir("keyless");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    let openai = ProviderId {
        id: "openai".to_string(),
    };
    let _ = disconnect_provider(openai.clone());

    // A model on this machine: an address, a model, and no credential at all.
    connect_provider(
        openai.clone(),
        String::new(),
        Some("http://127.0.0.1:11434".to_string()),
        Some("llama3.2".to_string()),
    )
    .expect("a local model needs no key");

    let p = provider_snapshot()
        .expect("snap")
        .providers
        .into_iter()
        .find(|p| p.id == "openai")
        .expect("openai");

    // Connected, and holding nothing. Both at once — that is the whole point.
    assert!(p.connected, "a local model with no key is still reachable");
    assert!(p.on_this_computer);
    assert!(!p.credential_required);
    assert_eq!(
        p.credential_state,
        CredentialState::Missing,
        "an empty credential was given a home in the vault"
    );
    assert!(
        !p.configured,
        "`configured` means a credential is stored, and none is"
    );

    // And the vault was open, so this is not «it fell back to memory».
    assert_eq!(vault_state().expect("vault state"), VaultState::Unlocked);

    // A real key, at an address that needs one, still reports where it lives.
    connect_provider(
        openai.clone(),
        "sk-test-not-a-real-key".to_string(),
        Some("https://api.openai.com".to_string()),
        Some("gpt-4o-mini".to_string()),
    )
    .expect("connect");
    let p = provider_snapshot()
        .expect("snap")
        .providers
        .into_iter()
        .find(|p| p.id == "openai")
        .expect("openai");
    assert_eq!(p.credential_state, CredentialState::EncryptedInVault);
    assert!(p.configured);

    disconnect_provider(openai).ok();
}

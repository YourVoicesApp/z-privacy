// Truth snapshots: one read per screen, counts derived from a canonical set.
//
// Flutter will draw these. The tests below pin the facts the ten lies used to
// get wrong: header vs body, storage vs connected, scan origin, Always without
// a vault, and a revision that moves when displayed truth moves.
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
    let dir = std::env::temp_dir().join(format!("zprivacy-snap-{name}-{}", std::process::id()));
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
fn vault_header_and_body_are_the_same_object() {
    let _guard = serial();
    fresh_dir("vault");
    vault_create_with_passphrase(PASS.to_string()).expect("create");

    let snap = vault_snapshot().expect("vault");
    assert_eq!(snap.vault, VaultState::Unlocked);
    assert_eq!(snap.identity_count, 0);
    assert_eq!(snap.value_count, 0);
    assert_eq!(snap.taught_values.len() as u32, snap.value_count);
    assert!(!snap.can_forget);

    let entity = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("entity");
    set_value(entity, None, Kind::Company, "Nordstern Consulting GmbH".to_string(), Policy::Always)
        .expect("value");

    let snap = vault_snapshot().expect("vault after teach");
    let home = home_snapshot().expect("home");
    assert_eq!(snap.identity_count, 1);
    assert_eq!(snap.value_count, 1);
    assert_eq!(snap.taught_values.len(), 1);
    assert_eq!(home.identity_count, snap.identity_count);
    assert_eq!(home.value_count, snap.value_count);
    assert!(snap.can_forget);

    vault_lock().expect("lock");
    let snap = vault_snapshot().expect("locked");
    assert_eq!(snap.vault, VaultState::Locked);
    assert_eq!(snap.identity_count, 0);
    assert_eq!(snap.value_count, 0);
    assert!(snap.taught_values.is_empty());
}

#[test]
fn taught_values_are_not_a_search_result() {
    let _guard = serial();
    fresh_dir("taught");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    let a = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("a");
    set_value(a, None, Kind::Company, "Nordstern Consulting GmbH".to_string(), Policy::Always).expect("v");
    let b = create_entity(EntityKind::Person, "Kontakt".to_string(), None).expect("b");
    set_value(b, None, Kind::Person, "Thomas Müller".to_string(), Policy::Always).expect("v2");

    let snap = vault_snapshot().expect("vault");
    let filtered = search_vault("Thomas".to_string()).expect("search");
    assert_eq!(snap.value_count, 2, "the snapshot holds everything taught");
    assert_eq!(filtered.len(), 1, "search is a different question");
}

#[test]
fn a_missing_credential_never_claims_a_home() {
    let _guard = serial();
    fresh_dir("cred-missing");
    let _ = disconnect_provider(ProviderId { id: "openai".to_string() });
    let snap = provider_snapshot().expect("providers");
    for p in &snap.providers {
        if p.credential_state == CredentialState::Missing {
            assert!(!p.configured);
            // «No key» no longer means «not reachable»: a model on this machine
            // is connected and holds none. What must still hold is that nothing
            // needing a key is called connected without one.
            assert!(!p.connected || !p.credential_required);
        }
    }
}

#[test]
fn connect_shows_up_on_the_next_snapshot() {
    let _guard = serial();
    fresh_dir("connect");
    let _ = disconnect_provider(ProviderId { id: "openai".to_string() });
    let before = provider_snapshot().expect("before");
    let openai = before
        .providers
        .iter()
        .find(|p| p.id == "openai")
        .expect("openai");
    assert_eq!(openai.credential_state, CredentialState::Missing);
    let rev = before.state_revision;

    connect_provider(
        ProviderId { id: "openai".to_string() },
        "sk-test-not-a-real-key".to_string(),
        Some("https://api.openai.com".to_string()),
        Some("gpt-4o-mini".to_string()),
    )
    .expect("connect");

    let after = provider_snapshot().expect("after");
    assert!(after.state_revision > rev);
    let openai = after
        .providers
        .iter()
        .find(|p| p.id == "openai")
        .expect("openai");
    assert!(openai.configured);
    assert_eq!(openai.credential_state, CredentialState::SessionOnly);

    disconnect_provider(ProviderId { id: "openai".to_string() }).expect("forget");
}

#[test]
fn workspace_counts_come_from_findings() {
    let _guard = serial();
    fresh_dir("ws-counts");
    let s = session_with_doc();
    scan(s).expect("scan");
    let snap = workspace_snapshot(s).expect("snap");
    let auto = snap.findings.iter().filter(|f| f.state == MarkState::Protected && !f.decided).count() as u32;
    let user = snap.findings.iter().filter(|f| f.state == MarkState::Protected && f.decided).count() as u32;
    let open = snap.findings.iter().filter(|f| f.state == MarkState::Suggested).count() as u32;
    assert_eq!(snap.auto_protected, auto);
    assert_eq!(snap.user_protected, user);
    assert_eq!(snap.open_suggestions, open);
    assert_eq!(snap.scan_origin, ScanOrigin::OnImport);
    close_session(s).expect("close");
}

#[test]
fn workspace_snapshot_names_the_active_profile_and_rename_keeps_the_id() {
    let _guard = serial();
    fresh_dir("profiles");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    let client_a = create_profile("Client A".to_string(), None).expect("a");
    let client_b = create_profile("Client B".to_string(), None).expect("b");
    let s = open_session(Some(client_a.clone()), "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");

    let snap = workspace_snapshot(s).expect("snapshot");
    assert_eq!(snap.profile_id.as_deref(), Some(client_a.as_str()));
    assert_eq!(
        home_snapshot()
            .expect("home")
            .profiles
            .iter()
            .find(|p| p.id == client_a)
            .map(|p| p.name.as_str()),
        Some("Client A")
    );

    rename_profile(client_a.clone(), "Nordstern".to_string()).expect("rename");
    let profiles = profiles().expect("profiles");
    let renamed = profiles.iter().find(|p| p.id == client_a).expect("renamed");
    assert_eq!(renamed.name, "Nordstern");

    switch_profile(s, Some(client_b.clone())).expect("switch to b");
    assert_eq!(
        workspace_snapshot(s).expect("after b").profile_id.as_deref(),
        Some(client_b.as_str())
    );
    switch_profile(s, None).expect("switch everywhere");
    assert_eq!(workspace_snapshot(s).expect("everywhere").profile_id, None);
    close_session(s).expect("close");
}

#[test]
fn a_second_scan_is_a_rescan() {
    let _guard = serial();
    fresh_dir("rescan");
    let s = session_with_doc();
    scan(s).expect("first");
    assert_eq!(workspace_snapshot(s).expect("one").scan_origin, ScanOrigin::OnImport);
    scan(s).expect("second");
    assert_eq!(workspace_snapshot(s).expect("two").scan_origin, ScanOrigin::Rescan);
    close_session(s).expect("close");
}

#[test]
fn always_without_a_vault_is_a_named_failure_and_changes_nothing() {
    let _guard = serial();
    fresh_dir("always");
    let s = session_with_doc();
    scan(s).expect("scan");
    let before = workspace_snapshot(s).expect("before");
    match protect(s, span_of(DOC, "Thomas Müller"), Scope::Always, Kind::Person) {
        Err(ApiError::VaultAbsent) => {}
        other => panic!("expected VaultAbsent, got {other:?}"),
    }
    let after = workspace_snapshot(s).expect("after");
    assert_eq!(after.token_count, before.token_count);
    assert_eq!(after.user_protected, before.user_protected);
    close_session(s).expect("close");
}

#[test]
fn a_mutation_that_changes_displayed_truth_bumps_state_revision() {
    let _guard = serial();
    fresh_dir("rev");
    let s = session_with_doc();
    let before = workspace_snapshot(s).expect("before").state_revision;
    scan(s).expect("scan");
    let after = workspace_snapshot(s).expect("after").state_revision;
    assert!(after > before, "a scan is a displayed fact");
    close_session(s).expect("close");
}

#[test]
fn can_undo_matches_what_undo_would_do() {
    let _guard = serial();
    fresh_dir("undo");
    let s = session_with_doc();
    scan(s).expect("scan");
    let snap = workspace_snapshot(s).expect("snap");
    if snap.can_undo {
        match undo_last_protection(s).expect("undo") {
            UndoOutcome::Undone { .. } => {}
            other => panic!("can_undo was true, undo said {other:?}"),
        }
    } else {
        match undo_last_protection(s).expect("undo") {
            UndoOutcome::NothingToUndo => {}
            other => panic!("can_undo was false, undo said {other:?}"),
        }
    }
    close_session(s).expect("close");
}

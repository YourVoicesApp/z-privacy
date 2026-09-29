// My Privacy Rules: user-taught values and durable exceptions live in the
// encrypted vault, are scoped by profile/everywhere, and are read through one
// truth snapshot.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für die Listen";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

fn fresh(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-user-lists-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte_start = doc.find(needle).expect("needle");
    let prefix = &doc[..byte_start];
    let start = prefix.chars().map(char::len_utf16).sum::<usize>() as u32;
    let end = start + needle.chars().map(char::len_utf16).sum::<usize>() as u32;
    Span { start, end }
}

fn byte_of_utf16(s: &str, target: u32) -> usize {
    if target == 0 {
        return 0;
    }
    let mut units = 0u32;
    for (byte, ch) in s.char_indices() {
        if units == target {
            return byte;
        }
        units += ch.len_utf16() as u32;
    }
    s.len()
}

fn text_for_span(s: &str, span: Span) -> Option<&str> {
    let start = byte_of_utf16(s, span.start);
    let end = byte_of_utf16(s, span.end);
    s.get(start..end)
}

fn scan_text(profile: Option<String>, text: &str) -> (SessionId, WorkspaceSnapshot) {
    let s = open_session(profile, "de".to_string()).expect("session");
    import_text(s, text.to_string()).expect("import");
    scan(s).expect("scan");
    let snap = workspace_snapshot(s).expect("snapshot");
    (s, snap)
}

fn has_vault_claim(snap: &WorkspaceSnapshot, needle: &str) -> bool {
    snap.findings.iter().any(|f| {
        f.source == Source::Vault
            && text_for_span(&snap.document.text, f.span).is_some_and(|found| found == needle)
    })
}

fn suggested_id(snap: &WorkspaceSnapshot, kind: Kind, needle: &str) -> u32 {
    snap.findings
        .iter()
        .find(|f| {
            f.kind == kind
                && f.state == MarkState::Suggested
                && text_for_span(&snap.document.text, f.span).is_some_and(|found| found == needle)
        })
        .map(|f| f.id)
        .unwrap_or_else(|| panic!("no suggested {kind:?} for {needle}: {:?}", snap.findings))
}

#[test]
fn values_and_exceptions_are_vault_knowledge_with_profile_scope() {
    let _guard = serial();
    fresh("journey");
    let profile_a = create_profile("Client A".to_string()).expect("a");
    let profile_b = create_profile("Client B".to_string()).expect("b");

    let doc = "Kunde: Nordstern Consulting GmbH";
    let s = open_session(Some(profile_a.clone()), "de".to_string()).expect("session");
    import_text(s, doc.to_string()).expect("import");
    protect(
        s,
        span_of(doc, "Nordstern Consulting GmbH"),
        Scope::Profile,
        Kind::Company,
    )
    .expect("teach profile value");
    close_session(s).expect("close");

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");

    let (inside, inside_snap) = scan_text(Some(profile_a.clone()), "Nordstern Consulting GmbH meldet sich.");
    assert!(has_vault_claim(&inside_snap, "Nordstern Consulting GmbH"));
    close_session(inside).expect("close");

    let (outside, outside_snap) = scan_text(Some(profile_b.clone()), "Nordstern Consulting GmbH meldet sich.");
    assert!(
        !outside_snap.findings.iter().any(|f| f.source == Source::Vault),
        "profile A's taught value leaked into profile B: {:?}",
        outside_snap.findings
    );
    close_session(outside).expect("close");

    let doc = "Ansprechpartner: Thomas Müller";
    let s = open_session(Some(profile_a.clone()), "de".to_string()).expect("session");
    import_text(s, doc.to_string()).expect("import");
    protect(s, span_of(doc, "Thomas Müller"), Scope::Always, Kind::Person).expect("teach global value");
    close_session(s).expect("close");

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    for profile in [profile_a.clone(), profile_b.clone()] {
        let (session, snap) = scan_text(Some(profile), "Thomas Müller ruft an.");
        assert!(has_vault_claim(&snap, "Thomas Müller"));
        close_session(session).expect("close");
    }

    let phone_doc = "Bitte 0171 2345678 notieren.";
    let (a_session, a_snap) = scan_text(Some(profile_a.clone()), phone_doc);
    let phone = suggested_id(&a_snap, Kind::Phone, "0171 2345678");
    teach_exception(a_session, phone, Scope::Profile).expect("profile exception");
    scan(a_session).expect("rescan after exception");
    let after_exception = list_findings(a_session).expect("after exception");
    assert!(
        !after_exception
            .iter()
            .any(|f| f.kind == Kind::Phone && f.source == Source::GeneralRule),
        "profile exception did not suppress the phone rule in A: {:?}",
        after_exception
    );
    close_session(a_session).expect("close");

    let (b_session, b_snap) = scan_text(Some(profile_b.clone()), phone_doc);
    assert!(
        b_snap
            .findings
            .iter()
            .any(|f| f.kind == Kind::Phone && f.source == Source::GeneralRule),
        "profile exception in A suppressed profile B too: {:?}",
        b_snap.findings
    );
    close_session(b_session).expect("close");

    let rules = privacy_rules_snapshot(Some(profile_a.clone())).expect("rules");
    assert!(rules.values.iter().any(|row| row.value == "Nordstern Consulting GmbH"));
    assert!(rules.values.iter().any(|row| row.value == "Thomas Müller"));
    assert!(rules.exceptions.iter().any(|row| row.value == "0171 2345678"));
    assert!(!rules.rules_built, "phase A must not pretend rule builder exists");

    let nordstern = rules
        .values
        .iter()
        .find(|row| row.value == "Nordstern Consulting GmbH")
        .expect("nordstern row");
    forget_value(nordstern.entity_id, nordstern.value_id, false).expect("forget taught value");
    let rules = privacy_rules_snapshot(Some(profile_a.clone())).expect("rules after forget");
    assert!(
        !rules.values.iter().any(|row| row.value == "Nordstern Consulting GmbH"),
        "forgotten value still appears in My Privacy Rules"
    );
    let (session, snap) = scan_text(Some(profile_a), "Nordstern Consulting GmbH meldet sich.");
    assert!(
        !snap.findings.iter().any(|f| f.source == Source::Vault),
        "forgotten value is still known by the vault: {:?}",
        snap.findings
    );
    close_session(session).expect("close");
}

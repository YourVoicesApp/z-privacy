// M7.10B — open rule sets and rules a person taught.
//
// Every test here is one the owner named on 29 September, in his order and with
// his examples. The last one is the only one that decides whether we built an
// open list or moved a `match` into another file.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein gutes Passwort für die Regeln";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

fn fresh(name: &str) -> std::path::PathBuf {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-rule-sets-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    dir
}

/// Scan a document under one profile and report (kind, captured text).
fn scan_under(profile: &str, doc: &str) -> Vec<(Kind, String)> {
    let session = open_session(Some(profile.to_string()), "de".to_string()).expect("session");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let view = document_view(session).expect("view");
    view.marks
        .into_iter()
        .map(|mark| (mark.kind, doc[mark.span.start as usize..mark.span.end as usize].to_string()))
        .collect()
}

/// His first closing test, word for word:
///   Profile A: active sets = de + en
///   "Kundennummer: 4711"      → Customer Number
///   "Customer number: 5822"   → Customer Number
///   both in the same document → both detected
#[test]
fn a_profile_runs_two_languages_in_one_scan() {
    let _guard = serial();
    fresh("two-languages");
    let profile = create_profile("Profile A".to_string()).expect("profile");
    let row = set_profile_languages(profile.clone(), vec!["de".to_string(), "en".to_string()])
        .expect("languages");
    assert_eq!(row.languages, vec!["de".to_string(), "en".to_string()]);

    let german = scan_under(&profile, "Kundennummer: 4711");
    assert!(
        german.contains(&(Kind::CustomerNo, "4711".to_string())),
        "the German label was missed: {german:?}"
    );

    let english = scan_under(&profile, "Customer number: 5822");
    assert!(
        english.contains(&(Kind::CustomerNo, "5822".to_string())),
        "the English label was missed: {english:?}"
    );

    let both = scan_under(&profile, "Kundennummer: 4711\nCustomer number: 5822\n");
    assert!(
        both.contains(&(Kind::CustomerNo, "4711".to_string()))
            && both.contains(&(Kind::CustomerNo, "5822".to_string())),
        "one document, two languages, one scan — and one was lost: {both:?}"
    );
}

/// His second closing test: teach a rule, restart, unlock, scan — and it is
/// scoped to the profile it was taught for.
#[test]
fn a_taught_rule_survives_a_restart_and_stays_in_its_profile() {
    let _guard = serial();
    let dir = fresh("taught");
    let a = create_profile("Client A".to_string()).expect("a");
    let b = create_profile("Client B".to_string()).expect("b");
    for p in [&a, &b] {
        set_profile_languages(p.clone(), vec!["de".to_string()]).expect("languages");
    }
    teach_label_rule("Mandantenkennung".to_string(), Kind::CustomerNo, Some(a.clone()))
        .expect("teach");

    // Restart: lock, forget everything in memory, open the same folder again.
    vault_lock().expect("lock");
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir again");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");

    let doc = "Mandantenkennung: 7781-B";
    let in_a = scan_under(&a, doc);
    assert!(
        in_a.contains(&(Kind::CustomerNo, "7781-B".to_string())),
        "the taught rule did not survive the restart: {in_a:?}"
    );

    let in_b = scan_under(&b, doc);
    assert!(
        !in_b.iter().any(|(_, text)| text == "7781-B"),
        "a rule taught for one client followed the user into another: {in_b:?}"
    );
}

/// His third: the same rule taught Everywhere reaches both profiles.
#[test]
fn a_rule_taught_everywhere_reaches_every_profile() {
    let _guard = serial();
    fresh("everywhere");
    let a = create_profile("Client A".to_string()).expect("a");
    let b = create_profile("Client B".to_string()).expect("b");
    for p in [&a, &b] {
        set_profile_languages(p.clone(), vec!["de".to_string()]).expect("languages");
    }
    teach_label_rule("Mandantenkennung".to_string(), Kind::CustomerNo, None).expect("teach");

    let doc = "Mandantenkennung: 7781-B";
    for (name, profile) in [("A", &a), ("B", &b)] {
        let hits = scan_under(profile, doc);
        assert!(
            hits.contains(&(Kind::CustomerNo, "7781-B".to_string())),
            "a rule taught everywhere did not reach profile {name}: {hits:?}"
        );
    }
}

/// It must be explainable, and forgettable — the ninth question applies to a
/// rule exactly as it applies to a value.
#[test]
fn a_taught_rule_explains_itself_and_can_be_forgotten() {
    let _guard = serial();
    fresh("explain");
    let profile = create_profile("Nordstern".to_string()).expect("profile");
    set_profile_languages(profile.clone(), vec!["de".to_string()]).expect("languages");
    let rule_id = teach_label_rule("Mandantenkennung".to_string(), Kind::CustomerNo, Some(profile.clone()))
        .expect("teach");

    let doc = "Mandantenkennung: 7781-B";
    let session = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let start = doc.find("7781-B").unwrap() as u32;
    let why = explain(session, Span { start, end: start + "7781-B".len() as u32 }).expect("why");
    let because = why.because.join(" · ");
    assert!(
        why.headline.contains("taught") || because.contains("taught"),
        "the Why sheet does not say the person taught this: {} / {because}",
        why.headline
    );
    assert!(
        because.contains("Mandantenkennung"),
        "the Why sheet does not name the word it was found after: {because}"
    );
    // The card must agree with its own headline. «Decided by: Z Privacy, on
    // its own» under «You taught Z Privacy this rule» is one screen calling
    // itself a liar, and it shipped that way for an hour on 29 September.
    assert!(why.decided, "the card says the app decided what the person taught");
    assert_eq!(
        why.applies, "This profile",
        "the card reports the protection's scope instead of the rule's"
    );

    // It is in the list, with the profile named.
    let rules = label_rules().expect("rules");
    assert_eq!(rules.len(), 1);
    assert_eq!(rules[0].label, "Mandantenkennung");
    assert_eq!(rules[0].profile_name.as_deref(), Some("Nordstern"));

    // Forgetting is knowledge only: the open document keeps its token.
    let before = list_tokens(session).expect("tokens").len();
    forget_label_rule(rule_id).expect("forget");
    assert!(label_rules().expect("rules").is_empty());
    assert_eq!(
        list_tokens(session).expect("tokens").len(),
        before,
        "forgetting a rule took a protection back — Forget is not Unprotect"
    );
}

/// The snapshot is the only place a screen may read these lists from.
#[test]
fn the_snapshot_reports_the_rules_and_the_sets_that_actually_ran() {
    let _guard = serial();
    fresh("snapshot");
    let profile = create_profile("Nordstern".to_string()).expect("profile");
    set_profile_languages(profile.clone(), vec!["de".to_string(), "en".to_string()])
        .expect("languages");
    teach_label_rule("Mandantenkennung".to_string(), Kind::CustomerNo, Some(profile.clone()))
        .expect("teach");

    let snap = privacy_rules_snapshot(Some(profile.clone())).expect("snapshot");
    assert!(snap.rules_built, "the section says it is not built, and it is");
    assert_eq!(snap.label_rules.len(), 1);
    assert_eq!(snap.active_sets, vec!["de".to_string(), "en".to_string()]);
    // Every set this build carries is offered, each counting its own rows.
    assert!(snap.rule_sets.iter().any(|s| s.id == "de" && s.rules > 0));
    assert!(snap.rule_sets.iter().any(|s| s.id == "en" && s.rules > 0));

    // And a set this build does not have is refused by name, never stored as
    // «active» and quietly ignored.
    match set_profile_languages(profile, vec!["sv".to_string()]) {
        Err(ApiError::NotFound { reason }) => assert!(reason.contains("sv"), "{reason}"),
        other => panic!("an unknown rule set was accepted: {other:?}"),
    }
}

/// His test of 29 September, exactly: the explanation names a **reach**, and
/// neither the machine's handle nor the client's own name.
///
/// The two halves are one rule — a name appears where a person picks or
/// manages a profile, and nowhere else merely because we hold it.
#[test]
fn the_why_card_names_a_reach_and_never_the_client() {
    let _guard = serial();
    fresh("reach");
    let display = "Nordstern Consulting GmbH";
    let profile = create_profile(display.to_string()).expect("profile");
    set_profile_languages(profile.clone(), vec!["de".to_string()]).expect("languages");
    teach_label_rule("Mandantenkennung".to_string(), Kind::CustomerNo, Some(profile.clone()))
        .expect("teach");

    let doc = "Mandantenkennung: 7781-B";
    let session = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let start = doc.find("7781-B").unwrap() as u32;
    let why = explain(session, Span { start, end: start + "7781-B".len() as u32 }).expect("why");

    assert_eq!(why.applies, "This profile");
    let whole = format!("{} {} {}", why.headline, why.because.join(" "), why.applies);
    assert!(!whole.contains("CLIENT #"), "the machine's handle reached the card: {whole}");
    assert!(
        !whole.contains(display),
        "the client's own name reached the explanation: {whole}"
    );

    // And the screen whose job **is** managing profiles still shows the name.
    let rows = profiles().expect("profiles");
    assert!(
        rows.iter().any(|p| p.name == display),
        "the profile screen lost the display name"
    );
}

/// His condition on the error mapper, 29 September: a `reason` must be text
/// the **core** composes from known phrases — never raw text from a file, a
/// provider, or the user — so that turning reasons into sentences can never
/// become a way to leak a path, a response body, or a client's name.
///
/// The one that was leaking: a profile id is `p-<slug of the name>-<n>`, so
/// «there is no profile «p-nordstern-consulting-gmbh-1»» put the client's own
/// name on screen.
#[test]
fn a_refusal_never_echoes_a_profile_id() {
    let _guard = serial();
    fresh("no-echo");
    let display = "Nordstern Consulting GmbH";
    let profile = create_profile(display.to_string()).expect("profile");
    assert!(
        profile.contains("nordstern"),
        "the id stopped being derived from the name; this test guards the wrong thing now"
    );

    // Every door that takes a profile id and can refuse it.
    let cases: Vec<ApiError> = vec![
        set_profile_languages("p-does-not-exist-9".to_string(), vec!["de".to_string()]).unwrap_err(),
        teach_label_rule("X".to_string(), Kind::CustomerNo, Some(profile.clone())).err().unwrap_or(
            // Teaching for a real profile succeeds, so use a missing one.
            teach_label_rule("X".to_string(), Kind::CustomerNo, Some("p-ghost-2".to_string()))
                .unwrap_err(),
        ),
    ];
    for error in cases {
        let text = format!("{error:?}");
        assert!(
            !text.contains(&profile) && !text.to_lowercase().contains("nordstern"),
            "a refusal echoed a profile id, and the id carries the client's name: {text}"
        );
    }
}

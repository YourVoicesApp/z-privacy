// P2-5 — the three acts, and the three different things they leave behind.
//
// His rule, 30 September:
//
//     Action + scope must be readable from the name of the act itself. Helper
//     text explains, but it may not carry the information the decision needs.
//
// A name can only carry a scope if the scope is a **fact** the core reports, so
// `Explanation::taught_reach` is pinned here beside the acts it names. And the
// three scenarios below are his, in his order: what each act changes, and — the
// part a person is actually afraid of — what each act does **not** change.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein langes Passwort für die Reichweiten";
const DOC: &str = "Kunde: Nordstern Consulting GmbH";
const VALUE: &str = "Nordstern Consulting GmbH";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-scope-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

/// Teach one value, either to a profile or to every profile.
fn teach(profile: Option<&str>) -> (u32, u32) {
    let entity = create_entity(
        EntityKind::Client,
        "Nordstern".to_string(),
        profile.map(str::to_string),
    )
    .expect("entity");
    let value = set_value(
        entity,
        None,
        Kind::Company,
        VALUE.to_string(),
        Policy::Always,
    )
    .expect("value");
    (entity, value)
}

/// A scanned document, in the profile given.
fn scanned(profile: Option<&str>) -> SessionId {
    let s = open_session(profile.map(str::to_string), "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    s
}

/// Is that span protected right now? Asked of the core: «why is this
/// protected» refuses with `BadSpan` when nothing there is.
fn protected(s: SessionId, span: Span) -> bool {
    match explain(s, span) {
        Ok(_) => true,
        Err(ApiError::BadSpan { .. }) => false,
        Err(other) => panic!("explain answered {other:?}"),
    }
}

/// Does a **fresh** document in this profile still recognise the value? The
/// question «what does Z Privacy still know», asked the way a person would ask
/// it: by opening a new document and looking.
fn a_new_document_knows_it(profile: Option<&str>) -> bool {
    let s = scanned(profile);
    let knows = protected(s, span_of(DOC, VALUE));
    close_session(s).ok();
    knows
}

fn values_in_vault() -> u32 {
    vault_snapshot().expect("vault").value_count
}

// ---------------------------------------------------------------- 1

/// **Remove protection here** — changes this document, and nothing else.
#[test]
fn remove_protection_here_leaves_the_knowledge_alone() {
    let _g = serial();
    fresh_vault("remove-here");
    let profile = create_profile("A".to_string(), None).expect("profile");
    teach(Some(&profile));

    let s = scanned(Some(&profile));
    let span = span_of(DOC, VALUE);
    assert!(protected(s, span), "the taught value was not protected on import");

    unprotect(s, span).expect("unprotect");

    assert!(!protected(s, span), "the span is still protected here");
    assert_eq!(values_in_vault(), 1, "removing a protection erased knowledge");
    close_session(s).ok();

    assert!(
        a_new_document_knows_it(Some(&profile)),
        "the value was not protected again in a new document"
    );
}

// ---------------------------------------------------------------- 2

/// **Forget from this profile** — erases the knowledge, and leaves this
/// document exactly as it is.
#[test]
fn forget_from_this_profile_keeps_the_protection_already_applied() {
    let _g = serial();
    fresh_vault("forget-profile");
    let profile = create_profile("A".to_string(), None).expect("profile");
    let (entity, value) = teach(Some(&profile));

    let s = scanned(Some(&profile));
    let span = span_of(DOC, VALUE);
    assert!(protected(s, span));

    // The name of the button is a fact, not a guess: the core says this
    // knowledge lives in one profile, so «from this profile» is true of it.
    let why = explain(s, span).expect("why");
    assert_eq!(why.taught_reach, Some(TaughtReach::ThisProfile));
    assert_eq!(why.entity, Some(entity));
    assert_eq!(why.value_id, Some(value));

    forget_value(entity, value, false).expect("forget");

    assert_eq!(values_in_vault(), 0, "the taught value survived in profile A");
    assert!(
        protected(s, span),
        "forgetting reached into a protection already applied in this document"
    );
    close_session(s).ok();

    assert!(
        !a_new_document_knows_it(Some(&profile)),
        "a new document in A still recognised the forgotten value"
    );
}

// ---------------------------------------------------------------- 3

/// **Forget everywhere** — the same two promises, one profile wider.
#[test]
fn forget_everywhere_reaches_profiles_that_do_not_exist_yet() {
    let _g = serial();
    fresh_vault("forget-everywhere");
    let first = create_profile("A".to_string(), None).expect("profile");
    // Taught to no profile, so every profile knows it.
    let (entity, value) = teach(None);

    let s = scanned(Some(&first));
    let span = span_of(DOC, VALUE);
    assert!(protected(s, span), "global knowledge did not reach profile A");

    let why = explain(s, span).expect("why");
    assert_eq!(
        why.taught_reach,
        Some(TaughtReach::Everywhere),
        "knowledge that belongs to no profile was called profile-scoped"
    );

    forget_value(entity, value, true).expect("forget");

    assert_eq!(values_in_vault(), 0);
    assert!(
        protected(s, span),
        "forgetting reached into a protection already applied in this document"
    );
    close_session(s).ok();

    // A profile made **after** the act. The promise «everywhere» is about
    // tomorrow's documents as much as today's.
    let later = create_profile("B".to_string(), None).expect("profile B");
    assert!(
        !a_new_document_knows_it(Some(&later)),
        "a profile created after «Forget everywhere» still recognised the value"
    );
    assert!(!a_new_document_knows_it(None));
}

// ---------------------------------------------------------------- the fact

/// A protection nobody taught has no reach to name, and the sheet must not
/// offer a «Forget» for it at all.
#[test]
fn nothing_taught_reports_no_reach() {
    let _g = serial();
    fresh_vault("no-reach");
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    let span = span_of(DOC, VALUE);
    protect(s, span, Scope::Once, Kind::Company).expect("protect by hand");

    let why = explain(s, span).expect("why");
    assert_eq!(why.entity, None);
    assert_eq!(why.value_id, None);
    assert_eq!(
        why.taught_reach, None,
        "a reach was reported for knowledge that does not exist"
    );
    close_session(s).ok();
}

/// The reach follows the knowledge, not the document: the same value, moved to
/// another profile, changes the name of the act that would forget it.
#[test]
fn moving_an_identity_changes_the_name_of_the_act() {
    let _g = serial();
    fresh_vault("reach-moves");
    let profile = create_profile("A".to_string(), None).expect("profile");
    let (entity, _) = teach(None);

    let s = scanned(Some(&profile));
    let span = span_of(DOC, VALUE);
    assert_eq!(
        explain(s, span).expect("why").taught_reach,
        Some(TaughtReach::Everywhere)
    );

    move_entity(entity, Some(profile.clone())).expect("move");
    assert_eq!(
        explain(s, span).expect("why").taught_reach,
        Some(TaughtReach::ThisProfile),
        "the reach was remembered from before the move"
    );
    close_session(s).ok();
}

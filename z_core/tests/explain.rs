// «Why is this protected?» — the owner's ninth question, 28 September.
//
//   > If I taught Z Privacy something today, can I know tomorrow exactly what
//   > it learned, why, where it applies — and make it forget completely?
//
// «Source: Vault» is technically true and answers nobody. The rule these tests
// keep is the one he set for the next phase:
//
//   **Everything Z Privacy learns from the user must be visible, explainable,
//   editable and forgettable.**
//
// And the danger they exist to prevent is worse than any of the eight lies:
// local knowledge piling up until nobody can say why the app behaves as it
// does — a privacy product quietly becoming a black box.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein langes Passwort für diese Fragen";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("zprivacy-explain-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    dir
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

#[test]
fn every_protection_can_say_where_it_came_from() {
    let _lock = serial();
    let dir = fresh_vault("why");

    // One value taught by hand, so the vault layer has something to find.
    let client = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("entity");
    let value = set_value(
        client,
        None,
        Kind::Company,
        "Nordstern Consulting GmbH".to_string(),
        Policy::Always,
    )
    .expect("value");
    add_value_alias(client, value, "Nordstern".to_string()).expect("alias");

    const DOC: &str = "Kunde: Nordstern Consulting GmbH\n\
IBAN: DE89370400440532013000\n\
Ansprechpartner: Herr Thomas Müller\n\
Projektname Apollo steht fest.";

    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    // One by hand, so all four kinds of origin are on this page at once.
    protect(s, span_of(DOC, "Apollo"), Scope::Once, Kind::Project).expect("by hand");

    // THE RULE: nothing protected may be unable to say where it came from.
    let doc = document_view(s).expect("document");
    let protected: Vec<Mark> = doc
        .marks
        .into_iter()
        .filter(|m| m.state == MarkState::Protected)
        .collect();
    assert!(protected.len() >= 3, "the fixture protects several things");

    for mark in &protected {
        let why = explain(s, mark.span).expect("every protection explains itself");
        assert!(!why.headline.is_empty(), "a protection with no headline");
        assert!(!why.because.is_empty(), "a protection with nothing to say about itself");
        assert!(!why.applies.is_empty(), "a protection that does not say where it applies");
        assert_eq!(why.token, mark.token.clone().unwrap_or_default());
        // «Source: Vault» is what this replaces: the headline is a sentence.
        assert!(why.headline.len() > 6, "«{}» is not an answer", why.headline);
    }

    // The vault's own, in full — this is the shape the owner wrote out.
    let taught = explain(s, span_of(DOC, "Nordstern Consulting GmbH")).expect("explain");
    assert_eq!(taught.headline, "You taught Z Privacy this value");
    assert_eq!(taught.kind, Kind::Company);
    assert_eq!(taught.entity, Some(client));
    assert_eq!(taught.value_id, Some(value));
    assert_eq!(taught.aliases, vec!["Nordstern".to_string()]);
    assert!(taught.learned_at > 0, "a value taught today has a date");
    assert!(
        taught.because.iter().any(|b| b.contains("since")),
        "it says when it was taught: {:?}",
        taught.because
    );

    // A rule's own, which is a different answer and says so.
    let iban = explain(s, span_of(DOC, "DE89370400440532013000")).expect("explain");
    assert!(iban.headline.contains("shape"), "{}", iban.headline);
    assert!(iban.entity.is_none(), "a rule taught nobody anything");
    assert_eq!(iban.learned_at, 0, "and there is no date to give");

    // And the hand's, which says «this one place» and means it.
    let hand = explain(s, span_of(DOC, "Apollo")).expect("explain");
    assert_eq!(hand.headline, "You protected this by hand");
    assert!(hand.decided);
    assert_eq!(hand.applies, "This one place");

    close_session(s).expect("close");
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn forget_shows_what_it_will_take_and_then_takes_exactly_that() {
    let _lock = serial();
    let dir = fresh_vault("forget");

    let client = create_entity(EntityKind::Client, "Nordstern".to_string(), None).expect("entity");
    let value = set_value(
        client,
        None,
        Kind::Company,
        "Nordstern Consulting GmbH".to_string(),
        Policy::Always,
    )
    .expect("value");
    add_value_alias(client, value, "Nordstern".to_string()).expect("alias");
    add_value_alias(client, value, "NC GmbH".to_string()).expect("alias");

    // Control string: before forgetting, the scanner really does know it.
    const DOC: &str = "Kunde: Nordstern Consulting GmbH bittet um Auskunft.";
    let before = open_session(None, "de".to_string()).expect("session");
    import_text(before, DOC.to_string()).expect("import");
    let found = scan(before).expect("scan");
    assert!(
        found.by_layer.iter().any(|l| l.source == Source::Vault && l.count > 0),
        "the vault does not know it yet, so forgetting proves nothing: {:?}",
        found.by_layer
    );
    close_session(before).expect("close");

    // The plan, shown before anything happens.
    let plan = forget_plan(client, value, true).expect("plan");
    assert_eq!(plan.what, "Nordstern Consulting GmbH");
    assert_eq!(plan.values, 1);
    assert_eq!(plan.aliases, 2);
    assert_eq!(plan.identities, 1, "the identity would be left holding nothing");
    assert!(!plan.keeps.is_empty(), "it says what it does NOT touch");
    assert!(
        plan.keeps.iter().any(|k| k.contains("already protected")),
        "{:?}",
        plan.keeps
    );
    // And the field means one thing at both moments: what would still know it
    // **afterwards**. Nothing would, so it is empty before the act as well.
    assert!(
        plan.still_known_by.is_empty(),
        "a plan that removes everything leaves nothing knowing it: {:?}",
        plan.still_known_by
    );

    // Nothing has changed yet: a plan is a plan.
    assert_eq!(entity(client).expect("card").values.len(), 1);

    // The act, and it matches the plan it showed.
    let done = forget_value(client, value, true).expect("forget");
    assert_eq!((done.values, done.aliases, done.identities), (1, 2, 1));
    assert!(
        done.still_known_by.is_empty(),
        "«forget» left something that still recognises it: {:?}",
        done.still_known_by
    );

    // And the proof that forget means forget: the same document, again.
    let after = open_session(None, "de".to_string()).expect("session");
    import_text(after, DOC.to_string()).expect("import");
    let now = scan(after).expect("scan");
    assert!(
        !now.by_layer.iter().any(|l| l.source == Source::Vault && l.count > 0),
        "the vault still recognises what it was told to forget: {:?}",
        now.by_layer
    );
    close_session(after).expect("close");

    assert!(entity(client).is_err(), "an identity holding nothing is not kept as a shell");
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn forgetting_for_one_client_leaves_another_client_alone() {
    let _lock = serial();
    let dir = fresh_vault("scoped");

    // The same text, learned separately by two clients. Forgetting it for one
    // must not reach into the other — which is the whole reason `Scope::Profile`
    // exists, tested from the other end.
    let a = create_profile("Client A".to_string()).expect("profile");
    let b = create_profile("Client B".to_string()).expect("profile");
    let ea = create_entity(EntityKind::Client, "A".to_string(), Some(a)).expect("entity");
    let va = set_value(ea, None, Kind::Project, "Apollo".to_string(), Policy::Always).expect("value");
    let eb = create_entity(EntityKind::Client, "B".to_string(), Some(b.clone())).expect("entity");
    let vb = set_value(eb, None, Kind::Project, "Apollo".to_string(), Policy::Always).expect("value");

    let plan = forget_plan(ea, va, false).expect("plan");
    assert_eq!(plan.values, 1, "only this client's record is in the plan");
    // And the preview says, before anything happens, that the other client
    // would still recognise it — which is the useful half of the strictness.
    assert_eq!(plan.still_known_by.len(), 1, "{:?}", plan.still_known_by);
    assert!(
        plan.keeps.iter().any(|k| k.contains("Other profiles")),
        "and it says so: {:?}",
        plan.keeps
    );

    forget_value(ea, va, false).expect("forget");
    assert!(entity(eb).is_ok(), "the other client lost its identity");
    assert_eq!(entity(eb).expect("card").values[0].id, vb, "and its value");

    // Now everywhere, which does reach both — and says it did.
    let all = forget_value(eb, vb, true).expect("forget everywhere");
    assert!(all.still_known_by.is_empty());
    assert!(
        all.keeps.iter().any(|k| k.contains("Nothing else on this device")),
        "{:?}",
        all.keeps
    );
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn forgetting_does_not_unprotect_the_document_that_is_open() {
    // The owner's own test, written out step by step on 28 September — because
    // making «Forget» pull the protection out of the open document would show
    // the value in the Safe column a moment after the user asked the app to be
    // *more* careful.
    //
    //   Forget    = erase the knowledge
    //   Unprotect = change the protection decision in this document
    //
    // Neither is a gentle name for the other.
    let _lock = serial();
    let dir = fresh_vault("forget-vs-unprotect");

    const DOC: &str = "Kunde: Nordstern Consulting GmbH bittet um Auskunft.";

    // Taught → Always.
    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    protect(
        s,
        span_of(DOC, "Nordstern Consulting GmbH"),
        Scope::Always,
        Kind::Company,
    )
    .expect("always");

    // A fresh conversation finds it by itself — that is what «always» bought.
    let auto = open_session(None, "de".to_string()).expect("session");
    import_text(auto, DOC.to_string()).expect("import");
    scan(auto).expect("scan");
    let token = list_tokens(auto)
        .expect("tokens")
        .into_iter()
        .find(|t| t.source == Source::Vault)
        .map(|t| t.token)
        .expect("the vault protected it by itself");
    let before = payload_view(build_payload(auto).expect("build")).expect("view").text;
    assert!(before.contains(&token));
    assert!(!before.contains("Nordstern Consulting GmbH"));

    // Forget everywhere.
    let known = search_vault("Nordstern Consulting GmbH".to_string()).expect("search");
    assert_eq!(known.len(), 1);
    let card = entity(known[0].id).expect("card");
    let done = forget_value(known[0].id, card.values[0].id, true).expect("forget");
    assert!(done.still_known_by.is_empty());

    // 1 · the vault no longer knows it.
    assert!(search_vault("Nordstern Consulting GmbH".to_string()).expect("search").is_empty());

    // 2 · **the open document is still protected**, and the safe text still
    //     carries the token. This is the line that matters.
    let after = payload_view(build_payload(auto).expect("build")).expect("view").text;
    assert!(after.contains(&token), "forgetting took the protection out of the open document");
    assert!(
        !after.contains("Nordstern Consulting GmbH"),
        "forgetting exposed the value in the Safe column"
    );

    // 3 · and it survives a rescan too — because Rescan is one button away, and
    //     a protection that vanishes on the next press was never protected.
    scan(auto).expect("rescan");
    let rescanned = payload_view(build_payload(auto).expect("build")).expect("view").text;
    assert!(
        !rescanned.contains("Nordstern Consulting GmbH"),
        "a rescan after forgetting exposed the value"
    );

    // 4 · a new conversation does not know it any more.
    let tomorrow = open_session(None, "de".to_string()).expect("session");
    import_text(tomorrow, DOC.to_string()).expect("import");
    let now = scan(tomorrow).expect("scan");
    assert!(
        !now.by_layer.iter().any(|l| l.source == Source::Vault && l.count > 0),
        "a new conversation still knows it: {:?}",
        now.by_layer
    );

    close_session(s).expect("close");
    close_session(auto).expect("close");
    close_session(tomorrow).expect("close");
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn remove_protection_is_a_different_act_from_forget_and_says_so() {
    let _lock = serial();
    let dir = fresh_vault("unprotect");
    // A codename no rule would ever catch — so that forgetting it really does
    // leave the protection with nothing behind it. «Nordstern Consulting GmbH»
    // would not do: the German pack claims anything ending in GmbH, and the
    // protection would simply change hands.
    const DOC: &str = "Das Projekt Apollo läuft weiter.";

    // Taught in one conversation…
    let taught = open_session(None, "de".to_string()).expect("session");
    import_text(taught, DOC.to_string()).expect("import");
    scan(taught).expect("scan");
    protect(taught, span_of(DOC, "Apollo"), Scope::Always, Kind::Project).expect("always");
    close_session(taught).expect("close");

    // …and found by itself in the next. **This** protection has no reason of
    // its own beyond the vault: a hand protection never orphans, because «you
    // selected it» does not expire.
    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    let span = span_of(DOC, "Apollo");
    assert!(
        document_view(s)
            .expect("document")
            .marks
            .iter()
            .any(|m| m.source == Source::Vault && m.state == MarkState::Protected),
        "the vault should have protected it by itself"
    );

    // Forget: the knowledge goes, the protection stays — and after it, the
    // explanation says why a protection is standing with nothing behind it.
    let known = search_vault("Apollo".to_string()).expect("search");
    let card = entity(known[0].id).expect("card");
    forget_value(known[0].id, card.values[0].id, true).expect("forget");
    scan(s).expect("rescan");

    let why = explain(s, span).expect("explain");
    assert!(
        why.because.iter().any(|b| b.contains("no longer claims it")),
        "an orphaned protection must say so: {:?}",
        why.because
    );
    assert!(
        why.because.iter().any(|b| b.contains("Remove protection")),
        "and name the act that would take it back: {:?}",
        why.because
    );
    let safe = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert!(!safe.contains("Apollo"), "an orphaned protection still protects");

    // Remove protection: this is the act that changes the document, and only
    // this one.
    match unprotect(s, span).expect("unprotect") {
        UndoOutcome::Undone { places, .. } => assert_eq!(places, 1),
        other => panic!("expected it to be taken back, got {other:?}"),
    }
    let after = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert!(
        after.contains("Apollo"),
        "«remove protection» did not remove the protection"
    );
    assert!(
        list_tokens(s).expect("tokens").iter().all(|t| !t.token.contains("PROJECT")),
        "a token nothing points at was kept"
    );

    // And asking again on a place with nothing protected is «nothing to undo»,
    // not an error and not a surprise.
    assert_eq!(unprotect(s, span).expect("again"), UndoOutcome::NothingToUndo);

    close_session(s).expect("close");
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn still_known_by_means_tomorrow_not_today() {
    // The owner's stricter definition, 28 September: an empty `still_known_by`
    // means «nothing kept on this device will recognise this value again» —
    // **not** «this value is nowhere in the program». The open conversation's
    // token store still holds it, and that is today's work, not knowledge for
    // tomorrow.
    let _lock = serial();
    let dir = fresh_vault("strict");
    const DOC: &str = "Kunde: Nordstern Consulting GmbH bittet um Auskunft.";

    let s = open_session(None, "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    protect(s, span_of(DOC, "Nordstern Consulting GmbH"), Scope::Always, Kind::Company)
        .expect("always");

    let known = search_vault("Nordstern Consulting GmbH".to_string()).expect("search");
    let card = entity(known[0].id).expect("card");
    let done = forget_value(known[0].id, card.values[0].id, true).expect("forget");

    // Empty — nothing permanent will know it again.
    assert!(done.still_known_by.is_empty());
    // And the plan says in words what that does and does not mean.
    assert!(
        done.keeps.iter().any(|k| k.contains("does not remove protection already applied")),
        "{:?}",
        done.keeps
    );

    // Meanwhile the value is very much still in this conversation — which is
    // exactly what «empty» does not claim.
    assert_eq!(
        reveal(s, list_tokens(s).expect("tokens")[0].token.clone())
            .expect("reveal")
            .value,
        "Nordstern Consulting GmbH",
        "today's token store still holds it, and should"
    );

    close_session(s).expect("close");
    let _ = std::fs::remove_dir_all(&dir);
}

// The vault as the fourth layer, and the owner's four rules for M4.
//
// The vault is one per device, so these tests share it: each one takes the lock
// below, points the core at its own folder, and builds the vault it needs.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

#[cfg(unix)]
use std::os::unix::fs::{symlink, PermissionsExt};

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

/// **What a block names itself** — the stand-in the core puts where an identity
/// would be, because nobody taught a block and there is no identity behind it.
/// It is how these tests tell rule 58 from the law it amends: a block crosses
/// every profile, a **taught value** still names the identity it came from and
/// still crosses nothing.
const A_BLOCK: &str = "a word you protected";

/// Every identity a vault-sourced finding names, with the blocks left out.
/// Empty means: the vault layer spoke, and nothing it said came from knowledge
/// taught about a client.
fn identities_claiming(s: SessionId) -> Vec<String> {
    let mut named: Vec<String> = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.source == Source::Vault)
        .flat_map(|f| f.entities)
        .filter(|who| who != A_BLOCK)
        .collect();
    named.sort();
    named.dedup();
    named
}

fn scanned(profile: Option<&str>) -> (SessionId, ScanReport) {
    let s = open_session(profile.map(str::to_string), "de".to_string()).expect("open");
    import_text(s, DOC.to_string()).expect("import");
    let report = scan(s).expect("scan");
    (s, report)
}

/// What the **vault layer** claimed, and nothing else.
///
/// Since 3 October a German salutation proves a person on its own, so «what is
/// protected» is no longer the same question as «what did the vault know». These
/// tests are about the vault, so they ask about the vault.
fn from_vault(s: SessionId) -> Vec<String> {
    let findings = list_findings(s).expect("findings");
    findings
        .iter()
        .filter(|f| f.state == MarkState::Protected && f.source == Source::Vault)
        .map(|f| {
            DOC.chars()
                .skip(f.span.start as usize)
                .take((f.span.end - f.span.start) as usize)
                .collect::<String>()
        })
        .collect()
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

#[cfg(unix)]
fn mode(path: impl AsRef<std::path::Path>) -> u32 {
    std::fs::metadata(path).expect("metadata").permissions().mode() & 0o777
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
    let (_, open) = states(locked_session);
    let claimed = from_vault(locked_session);
    assert!(
        claimed.is_empty(),
        "the vault layer claimed something while the vault was locked: {claimed:?}"
    );
    // The two names are proven by their salutations since 3 October; the
    // company is still the pack's guess.
    assert_eq!(open.len(), 1, "the pack still guesses at the company: {open:?}");
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
    // Anna Weber is protected — a salutation says so since 3 October — but the
    // vault never claimed her, and that is what «not a blank cheque» means.
    let claimed = from_vault(s);
    assert!(
        !claimed.contains(&"Anna Weber".to_string()),
        "the vault claimed a name it has never held: {claimed:?}"
    );
    let _ = open;

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
/// **Rule two still stands, and it is about knowledge** — amended 16 October
/// by the owner's rule 58, which answered the question this guard was parked
/// on: «البلوك يعبر من ملف عميل إلى ملف عميل… فالبلوك في خزنة المستخدم لا في
/// ملف العميل».
///
/// A **taught value** of one client is not loaded for another: that is rule
/// two (079) and nothing in this round touches it. A **block** — a word the
/// person has already protected somewhere — crosses every profile, because it
/// lives in their vault and not in a client's file. The two are not in
/// contradiction and a reader must not take them for one: this guard measures
/// the first, and `always_and_profile_actually_reach_the_vault` measures the
/// second.
///
/// **Why this file needed re-reading at all.** The taught company is scoped to
/// another profile and stays unloaded; what appeared beside it was «Thomas»,
/// «Müller», «Anna», «Weber» — words the German pack protected on the import's
/// own scan (an import scans, since 14 October), which made them blocks, which
/// the explicit scan below then found. So the guard's old line — «the vault
/// claimed nothing at all» — was measuring the blocks of this very reading and
/// not the profile law. The law is asked about by name now.
fn rule_two_a_value_in_another_profile_is_not_loaded() {
    let _guard = serial();
    fresh_vault("rule-two-profile");
    let other = create_profile("Client Andere".to_string(), None).expect("profile");
    identity("Andere", Some(&other), Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);

    // No profile active: an entity that belongs to one profile is not loaded.
    let (s, _) = scanned(None);
    let (_, open) = states(s);
    let claimed = from_vault(s);
    assert!(
        !claimed.contains(&"Nordstern Consulting GmbH".to_string()),
        "the vault loaded another profile's taught value: {claimed:?}"
    );
    assert!(
        identities_claiming(s).is_empty(),
        "a client's own knowledge went hunting outside that client: {:?}",
        identities_claiming(s)
    );
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
        vault_unlock_with_passphrase(PASS.to_string()),
        Err(ApiError::VaultAuthenticationFailed)
    ));
    match vault_unlock_with_passphrase("ein anderes langes Passwort".to_string()).expect("unlock") {
        VaultUnlockOutcome::Unlocked { identities, values } => assert_eq!((identities, values), (1, 1)),
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

/// **A Manual value is kept here and hunted by nobody** — and «nobody» means
/// the vault's own knowledge, which is what `Policy::Manual` is a policy about.
///
/// **Amended 16 October**, by the owner's rule of the day before (089 rule 1):
/// every word that takes a token is a block in his vault, and a block is put
/// back wherever that word stands. The German pack protects this company by its
/// legal form, so the word takes a token on the first reading and is a block
/// from then on — and the vault layer puts blocks back, which is why a
/// vault-sourced finding appears here now where none did before.
///
/// The promise that remains is the one the policy makes, and it is measured by
/// what the finding **is**: a block carries no identity behind it (there is
/// nothing taught and nobody to name), while a taught value that went hunting
/// names the identity it came from. So a Manual value may never produce the
/// second kind, and the floor below keeps this from passing for the empty
/// reason.
#[test]
fn a_manual_value_is_kept_but_never_hunted() {
    let _guard = serial();
    fresh_vault("manual");
    identity("Eigene", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Manual);

    let (s, _) = scanned(None);
    let findings = list_findings(s).expect("findings");
    assert!(
        DOC.contains("Nordstern Consulting GmbH"),
        "the Manual value is not even in the document, so this measures nothing"
    );
    //
    // A block names itself «a word you protected» — the stand-in the core puts
    // where an identity would be, because nobody taught it and there is no
    // identity behind it. A taught value that went hunting names the identity
    // it came from, and that is the thing this policy forbids.
    assert!(
        !findings
            .iter()
            .any(|f| f.source == Source::Vault && f.entities.iter().any(|e| e != A_BLOCK)),
        "Manual means: kept here, found by nobody — and a taught identity went hunting: {findings:?}"
    );
    assert!(
        findings.iter().any(|f| f.source == Source::Vault),
        "nothing came from the vault at all, so the line above would hold over an empty list"
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
    let p1 = create_profile("Client Eins".to_string(), None).expect("profile");
    let p2 = create_profile("Client Zwei".to_string(), None).expect("profile");
    identity("Eins", Some(&p1), Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);

    let (s, _) = scanned(Some(&p1));
    let before = list_tokens(s).expect("tokens");
    let company = before
        .iter()
        .find(|t| t.kind == Kind::Company)
        .expect("the company was recognised");
    let token_before = company.token.clone();

    // Switch to a profile that knows nothing: what was protected stays protected.
    let outcome = switch_profile(s, Some(p2.clone())).expect("switch");
    assert_eq!(
        outcome.kept_tokens, 5,
        "the company the vault knew and the two names, one token a word, the salutations proved"
    );
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

    let profile = create_profile("Client Nordstern".to_string(), None).expect("profile");
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
        // Eleven since 085 ruling 1 (15 October): the contract's two people are
        // a given name and a surname each. The value the **vault** was taught,
        // «Thomas Müller», is exempt and stays one — which is why this number
        // rose by one and not by two.
        // **Thirteen since 16 October**, and the two that joined are the rule
        // the owner gave on the 15th: «Abteilung» and «Vertragswesen» stand
        // twice in this contract, the pack protects the first place of each
        // as a person, and from that instant the word is a block — so the
        // second place of each comes back protected too (089 rules 1 and 3).
        // Rule 55 is what makes it show here: a document in the preview now
        // always has a session, which is what a block is written from.
        (13, 0),
        "nine by arithmetic, label and salutation, one more because the vault knows it, \
         and two more because a protected word is protected wherever it stands: {report:?}"
    );

    // The two that were questions in M3 are now answered by the vault itself —
    // **and since 089 rule 1 the vault layer also puts back every word that has
    // ever taken a token here**, which is the rest of this list. The two taught
    // identities are still the two that name an identity; a block names itself
    // «a word you protected», because nobody taught it.
    const A_BLOCK: &str = "a word you protected";
    let findings = list_findings(s).expect("findings");
    let from_vault: Vec<&Finding> = findings.iter().filter(|f| f.source == Source::Vault).collect();
    let taught: Vec<&&Finding> =
        from_vault.iter().filter(|f| f.entities.iter().any(|e| e != A_BLOCK)).collect();
    assert_eq!(taught.len(), 2, "the two taught identities are not the two the vault knows: {taught:?}");
    assert!(from_vault.iter().all(|f| f.state == MarkState::Protected));
    assert!(from_vault.iter().all(|f| f.entities.len() == 1));
    assert!(
        from_vault.len() > taught.len(),
        "nothing came back from a block, so the distinction above measures nothing"
    );

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

    // The by-layer summary now names three layers, the vault among them — and
    // it counts the blocks too, because they are the vault's own hints (089
    // rule 3). Ten: the two it was taught, and the eight words this reading
    // protected and kept.
    assert!(
        report.by_layer.iter().any(|l| l.source == Source::Vault && l.count == 10),
        "{:?}",
        report.by_layer
    );
}

// ---------------------------------------------------------------- M7.8
// The vault as a room the user manages, not only a layer the scanner reads.

#[test]
fn an_identity_can_be_renamed_moved_and_pruned() {
    let _lock = serial();
    fresh_vault("manage");
    let profile = create_profile("Client A".to_string(), None).expect("profile");
    let id = identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &["Nordstern"], Policy::Always);

    rename_entity(id, "Nordstern Consulting".to_string()).expect("rename");
    assert_eq!(entity(id).expect("card").label, "Nordstern Consulting");
    assert!(rename_entity(id, "   ".to_string()).is_err(), "an identity needs a name");

    // Moving to a profile that does not exist is refused, not silently done:
    // an identity in a profile nobody can pick is a value never found again.
    match move_entity(id, Some("p-does-not-exist".to_string())) {
        Err(ApiError::NotFound { reason }) => assert!(reason.contains("profile"), "{reason}"),
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

    // The file itself: readable, and holding only the allowed names. 041-F
    // added the fifth — where the handle between the two columns was left —
    // which is a window's preference and names nothing of anybody's work.
    let text = std::fs::read_to_string(dir.join("settings.zcfg")).expect("the file exists");
    assert!(text.starts_with("ZCFG1"));
    for name in [
        "schema_version",
        "first_run_completed",
        "ui_language",
        "default_privacy_pack",
        "original_pane_percent",
        "columns_in_step",
        // 046/K: the Safe column's and the panel's own widths. They are here
        // for the reason the owner's rule makes unavoidable — a state that only
        // a person's press may change has to survive the app closing, or
        // closing it would change it for them — and they are each one bit that
        // names nothing: not a document, not a page, not a person.
        "safe_column_open",
        "review_panel_wide",
    ] {
        assert!(text.contains(name), "{name} is missing from {text}");
    }
    // The count, and not only the names: a line this list does not know about
    // is a setting nobody declared. The number moves when `ALLOWED` does, and
    // gate G18a is what keeps `ALLOWED` honest about its own length.
    assert_eq!(text.lines().count(), 9, "a header and eight settings, nothing else:\n{text}");

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
        Err(ApiError::InputRefused { reason }) => {
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

#[cfg(unix)]
#[test]
fn local_files_are_private_on_fresh_install() {
    let _lock = serial();
    let dir = std::env::temp_dir().join(format!("zprivacy-fs-private-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");

    let mut s = settings().expect("settings");
    s.first_run_done = true;
    save_settings(s).expect("save settings");

    assert_eq!(mode(&dir), 0o700, "the data directory is private");
    assert_eq!(mode(dir.join("vault.zv")), 0o600, "the sealed vault is private");
    assert_eq!(mode(dir.join("settings.zcfg")), 0o600, "the settings file is private");
    let _ = std::fs::remove_dir_all(&dir);
}

/// The same contract as the Unix test above, in the only terms Windows can
/// keep it in.
///
/// Not «nobody but the owner can read it»: Administrators and SYSTEM hold
/// privileges no access list can refuse, and a promise that ignored that would
/// be false on the platform it is made about. What is promised, and checked:
/// the file's access list names no other account, and it does not inherit
/// whatever the folder above it grants.
///
/// It carries the Unix test's name on purpose. One contract, one name, each
/// platform proving it in its own terms — which is what lets G22 ask for it
/// without knowing which platform it is standing on.
#[cfg(windows)]
#[test]
fn local_files_are_private_on_fresh_install() {
    let _lock = serial();
    let dir = std::env::temp_dir().join(format!("zprivacy-fs-private-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");

    let mut s = settings().expect("settings");
    s.first_run_done = true;
    save_settings(s).expect("save settings");

    for name in ["vault.zv", "settings.zcfg"] {
        let sddl = z_core::testing::dacl_sddl(&dir.join(name)).expect("read the access list");

        // «P» — protected. Without it the file takes whatever the folder gives,
        // which is the half of the contract that has nothing to do with us.
        assert!(
            sddl.starts_with("D:P"),
            "{name} inherits permissions from its folder: {sddl}"
        );
        // One allow entry, for the owner. Anything not named is denied by
        // absence, so counting the entries is the whole check.
        assert_eq!(
            sddl.matches('(').count(),
            1,
            "{name} names more than one account: {sddl}"
        );
        assert!(
            sddl.contains(";OW)") || sddl.contains(";CO)"),
            "{name}'s single entry is not the owner's: {sddl}"
        );
    }
    let _ = std::fs::remove_dir_all(&dir);
}

#[cfg(unix)]
#[test]
fn vault_temp_symlink_is_refused_and_victim_is_unchanged() {
    let _lock = serial();
    let root = std::env::temp_dir().join(format!("zprivacy-fs-vault-link-{}", std::process::id()));
    let data = root.join("data");
    let victim = root.join("victim.txt");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&data).expect("data dir");
    std::fs::write(&victim, b"ZXQ-VICTIM-VAULT-ORIGINAL").expect("victim");
    symlink(&victim, data.join("vault.zv.new")).expect("temp symlink");

    set_data_dir(data.to_string_lossy().to_string()).expect("dir");
    match vault_create_with_passphrase(PASS.to_string()) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("the temp symlink must be refused, got {other:?}"),
    }
    assert_eq!(std::fs::read(&victim).expect("victim"), b"ZXQ-VICTIM-VAULT-ORIGINAL");
    assert!(!data.join("vault.zv").exists(), "a failed create does not invent a final vault");
    let _ = std::fs::remove_dir_all(&root);
}

/// The second contract on Windows, and «symlink» is too small a word for it
/// there: a symlink, a junction and a mount point are all reparse points, and
/// any of them in the path would make a write land somewhere else.
///
/// Two cases, because one of them passes by accident. With the link pointing at
/// a file that exists, CREATE_NEW refuses even without the flag — the target is
/// already there, so the call fails for the wrong reason and the test would go
/// green over an unguarded build. The second case is the real one: a link to a
/// path that does **not** exist. Follow it and the victim is created and
/// written; refuse to follow it and nothing appears at all.
#[cfg(windows)]
#[test]
fn vault_temp_symlink_is_refused_and_victim_is_unchanged() {
    use std::os::windows::fs::symlink_file;

    let _lock = serial();
    let root = std::env::temp_dir().join(format!("zprivacy-fs-vault-link-{}", std::process::id()));
    let data = root.join("data");
    let victim = root.join("victim.txt");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&data).expect("data dir");
    std::fs::write(&victim, b"ZXQ-VICTIM-VAULT-ORIGINAL").expect("victim");

    // Creating one needs SeCreateSymbolicLinkPrivilege or Developer Mode. If
    // this machine has neither, say so and stop — a contract that quietly skips
    // itself is the thing G22 exists to make impossible.
    if let Err(e) = symlink_file(&victim, data.join("vault.zv.new")) {
        panic!("this machine cannot create a reparse point, so the contract cannot be measured here: {e}");
    }

    set_data_dir(data.to_string_lossy().to_string()).expect("dir");
    match vault_create_with_passphrase(PASS.to_string()) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("the temp reparse point must be refused, got {other:?}"),
    }
    assert_eq!(std::fs::read(&victim).expect("victim"), b"ZXQ-VICTIM-VAULT-ORIGINAL");
    assert!(!data.join("vault.zv").exists(), "a failed create does not invent a final vault");

    // The case that proves the flag: the link points nowhere. Following it
    // would create that path and write the vault into it.
    //
    // From a data root of its own, because the case above left a vault behind
    // and a second create would be answered `VaultAlreadyExists` — a correct
    // refusal from a layer above this one, which never reaches the file at all.
    // That is exactly what this run reported, and it was the test's fault, not
    // the guard's.
    let second = root.join("data2");
    std::fs::create_dir_all(&second).expect("second data dir");
    let nowhere = root.join("not-there-yet.txt");
    symlink_file(&nowhere, second.join("vault.zv.new")).expect("dangling reparse point");
    set_data_dir(second.to_string_lossy().to_string()).expect("second dir");
    match vault_create_with_passphrase(PASS.to_string()) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("a dangling reparse point must be refused, got {other:?}"),
    }
    assert!(
        !nowhere.exists(),
        "following the reparse point created the file it pointed at"
    );

    let _ = std::fs::remove_dir_all(&root);
}

#[cfg(unix)]
#[test]
fn settings_temp_symlink_is_refused_and_victim_is_unchanged() {
    let _lock = serial();
    let root = std::env::temp_dir().join(format!("zprivacy-fs-zcfg-link-{}", std::process::id()));
    let data = root.join("data");
    let victim = root.join("victim.txt");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&data).expect("data dir");
    std::fs::write(&victim, b"ZXQ-VICTIM-CONFIG-ORIGINAL").expect("victim");
    symlink(&victim, data.join("settings.zcfg.new")).expect("temp symlink");

    set_data_dir(data.to_string_lossy().to_string()).expect("dir");
    let mut s = settings().expect("settings");
    s.first_run_done = true;
    match save_settings(s) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("the temp symlink must be refused, got {other:?}"),
    }
    assert_eq!(std::fs::read(&victim).expect("victim"), b"ZXQ-VICTIM-CONFIG-ORIGINAL");
    assert!(!data.join("settings.zcfg").exists(), "a failed save does not invent a final settings file");
    let _ = std::fs::remove_dir_all(&root);
}

/// The same contract as the vault's, for the file beside it.
///
/// No new guard was needed: `replace_atomically` is one function and both files
/// go through it, so closing the vault's path closed this one at the same
/// moment. That is worth a test rather than an assumption — a shared guard is
/// exactly the kind that gets specialised later and quietly stops covering the
/// second caller.
///
/// Two cases again, and for the same reason: pointed at a file that exists the
/// call refuses even unguarded, so the dangling link is the one that proves it.
#[cfg(windows)]
#[test]
fn settings_temp_symlink_is_refused_and_victim_is_unchanged() {
    use std::os::windows::fs::symlink_file;

    let _lock = serial();
    let root = std::env::temp_dir().join(format!("zprivacy-fs-zcfg-link-{}", std::process::id()));
    let data = root.join("data");
    let victim = root.join("victim.txt");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&data).expect("data dir");
    std::fs::write(&victim, b"ZXQ-VICTIM-CONFIG-ORIGINAL").expect("victim");
    if let Err(e) = symlink_file(&victim, data.join("settings.zcfg.new")) {
        panic!("this machine cannot create a reparse point, so the contract cannot be measured here: {e}");
    }

    set_data_dir(data.to_string_lossy().to_string()).expect("dir");
    let mut s = settings().expect("settings");
    s.first_run_done = true;
    match save_settings(s) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("the temp reparse point must be refused, got {other:?}"),
    }
    assert_eq!(std::fs::read(&victim).expect("victim"), b"ZXQ-VICTIM-CONFIG-ORIGINAL");
    assert!(
        !data.join("settings.zcfg").exists(),
        "a failed save does not invent a final settings file"
    );

    // The dangling case, from a data root of its own so nothing above this
    // layer answers first.
    let second = root.join("data2");
    std::fs::create_dir_all(&second).expect("second data dir");
    let nowhere = root.join("not-there-yet.txt");
    symlink_file(&nowhere, second.join("settings.zcfg.new")).expect("dangling reparse point");
    set_data_dir(second.to_string_lossy().to_string()).expect("second dir");
    let mut s = settings().expect("settings");
    s.first_run_done = true;
    match save_settings(s) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("a dangling reparse point must be refused, got {other:?}"),
    }
    assert!(
        !nowhere.exists(),
        "following the reparse point created the file it pointed at"
    );

    let _ = std::fs::remove_dir_all(&root);
}

#[cfg(unix)]
#[test]
fn final_vault_symlink_is_not_read_as_a_vault() {
    let _lock = serial();
    let source = fresh_vault("fs-source-vault");
    vault_lock().expect("lock source");
    let source_path = std::path::Path::new(&source).join("vault.zv");

    let root = std::env::temp_dir().join(format!("zprivacy-fs-final-link-{}", std::process::id()));
    let data = root.join("data");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&data).expect("data dir");
    symlink(&source_path, data.join("vault.zv")).expect("final symlink");

    set_data_dir(data.to_string_lossy().to_string()).expect("dir");
    assert_eq!(vault_state().expect("state"), VaultState::Locked);
    match vault_unlock_with_passphrase(PASS.to_string()) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("following links"), "{reason}"),
        other => panic!("a final vault symlink must not be followed, got {other:?}"),
    }
    let _ = std::fs::remove_dir_all(&root);
    let _ = std::fs::remove_dir_all(source);
}

/// The other half of the guard: not writing through a doorway, but refusing to
/// read one as though it were the vault.
///
/// Without this, a reparse point standing where `vault.zv` belongs is followed
/// straight through. Z Privacy opens some other file, finds a sealed vault in
/// it, and reports a vault on this device that belongs to another — then asks
/// for the passphrase to it.
///
/// The refusal carries the same words as the Unix one, «following links»,
/// because it is the same refusal: what was at this path was not followed, so
/// nothing was read.
#[cfg(windows)]
#[test]
fn final_vault_symlink_is_not_read_as_a_vault() {
    use std::os::windows::fs::symlink_file;

    let _lock = serial();
    let source = fresh_vault("fs-source-vault");
    vault_lock().expect("lock source");
    let source_path = std::path::Path::new(&source).join("vault.zv");

    let root = std::env::temp_dir().join(format!("zprivacy-fs-final-link-{}", std::process::id()));
    let data = root.join("data");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&data).expect("data dir");
    if let Err(e) = symlink_file(&source_path, data.join("vault.zv")) {
        panic!("this machine cannot create a reparse point, so the contract cannot be measured here: {e}");
    }

    set_data_dir(data.to_string_lossy().to_string()).expect("dir");
    assert_eq!(vault_state().expect("state"), VaultState::Locked);
    match vault_unlock_with_passphrase(PASS.to_string()) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("following links"), "{reason}"),
        other => panic!("a final vault reparse point must not be followed, got {other:?}"),
    }
    let _ = std::fs::remove_dir_all(&root);
    let _ = std::fs::remove_dir_all(source);
}

#[cfg(unix)]
#[test]
fn normal_secure_vault_and_config_writes_still_work() {
    let _lock = serial();
    let dir = fresh_vault("fs-normal");
    identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);
    let mut s = settings().expect("settings");
    s.first_run_done = true;
    s.language = "de".to_string();
    save_settings(s).expect("save");

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert_eq!(entities(None).expect("entities").len(), 1);

    let elsewhere = std::path::Path::new(&dir).join("elsewhere");
    set_data_dir(elsewhere.to_string_lossy().to_string()).expect("elsewhere");
    assert!(!settings().expect("settings").first_run_done);
    set_data_dir(dir.clone()).expect("back");
    assert!(settings().expect("settings").first_run_done);
    let _ = std::fs::remove_dir_all(&dir);
}

/// The last of the six: a write that fails leaves yesterday's file untouched.
///
/// This is what «atomic» has to mean in practice. The new bytes go to a temp
/// file first and only replace the real one once they are all there, so a
/// failure anywhere before that moment costs nothing — the vault that was on
/// disk a second ago is still the vault on disk now, byte for byte, and no
/// half-written file is left sitting where the real one belongs.
///
/// The failure is caused the way an attacker would cause it: a reparse point in
/// the temp file's place, which the second contract taught the writer to refuse.
/// So this test also proves the refusal happens *early* — before anything was
/// done to the file that already existed.
///
/// Nothing was changed to make it pass. The write path is as it was.
#[cfg(windows)]
#[test]
fn failed_secure_writes_leave_old_files_intact() {
    use std::os::windows::fs::symlink_file;

    let _lock = serial();
    let dir = fresh_vault("fs-fail-intact");
    let path = std::path::Path::new(&dir);

    let mut s = settings().expect("settings");
    s.first_run_done = true;
    save_settings(s).expect("initial settings");
    let old_vault = std::fs::read(path.join("vault.zv")).expect("old vault");
    let old_settings = std::fs::read(path.join("settings.zcfg")).expect("old settings");
    let vault_victim = path.join("vault-victim.txt");
    let settings_victim = path.join("settings-victim.txt");
    std::fs::write(&vault_victim, b"ZXQ-OLD-FINAL-VAULT-VICTIM").expect("vault victim");
    std::fs::write(&settings_victim, b"ZXQ-OLD-FINAL-CONFIG-VICTIM").expect("settings victim");

    if let Err(e) = symlink_file(&vault_victim, path.join("vault.zv.new")) {
        panic!("this machine cannot create a reparse point, so the contract cannot be measured here: {e}");
    }
    match create_entity(EntityKind::Client, "Nordstern".to_string(), None) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("the vault write should fail before replacing the old file, got {other:?}"),
    }
    assert_eq!(std::fs::read(path.join("vault.zv")).expect("vault"), old_vault);
    assert_eq!(
        std::fs::read(&vault_victim).expect("vault victim"),
        b"ZXQ-OLD-FINAL-VAULT-VICTIM"
    );
    std::fs::remove_file(path.join("vault.zv.new")).expect("remove vault temp");

    symlink_file(&settings_victim, path.join("settings.zcfg.new")).expect("settings temp reparse point");
    let mut s = settings().expect("settings");
    s.language = "de".to_string();
    match save_settings(s) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("the settings write should fail before replacing the old file, got {other:?}"),
    }
    assert_eq!(std::fs::read(path.join("settings.zcfg")).expect("settings"), old_settings);
    assert_eq!(
        std::fs::read(&settings_victim).expect("settings victim"),
        b"ZXQ-OLD-FINAL-CONFIG-VICTIM"
    );
    let _ = std::fs::remove_dir_all(&dir);
}

/// The contract that checks the guards did not win by breaking the product.
///
/// Four refusals are in place now. This one asks whether an ordinary save still
/// goes through, and — the part that matters on Windows — whether a **second**
/// one does. Every write here replaces a file that already exists, which is
/// where `rename` behaves differently than it does on Unix.
///
/// Nothing was changed to make this pass. If it falls, the fall is the report.
#[cfg(windows)]
#[test]
fn normal_secure_vault_and_config_writes_still_work() {
    let _lock = serial();
    let dir = fresh_vault("fs-normal");
    identity("Nordstern", None, Kind::Company, "Nordstern Consulting GmbH", &[], Policy::Always);
    let mut s = settings().expect("settings");
    s.first_run_done = true;
    s.language = "de".to_string();
    save_settings(s).expect("save");

    // The second save of each file: the first created it, this one must replace
    // it. On Unix that is one rename and nothing to say about it.
    identity("Zweiter", None, Kind::Company, "Zweite Firma GmbH", &[], Policy::Always);
    let mut s = settings().expect("settings");
    s.language = "en".to_string();
    save_settings(s).expect("save a second time over an existing file");

    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert_eq!(entities(None).expect("entities").len(), 2);
    assert_eq!(settings().expect("settings").language, "en");

    let elsewhere = std::path::Path::new(&dir).join("elsewhere");
    set_data_dir(elsewhere.to_string_lossy().to_string()).expect("elsewhere");
    assert!(!settings().expect("settings").first_run_done);
    set_data_dir(dir.clone()).expect("back");
    assert!(settings().expect("settings").first_run_done);
    let _ = std::fs::remove_dir_all(&dir);
}

#[cfg(unix)]
#[test]
fn failed_secure_writes_leave_old_files_intact() {
    let _lock = serial();
    let dir = fresh_vault("fs-fail-intact");
    let path = std::path::Path::new(&dir);

    let mut s = settings().expect("settings");
    s.first_run_done = true;
    save_settings(s).expect("initial settings");
    let old_vault = std::fs::read(path.join("vault.zv")).expect("old vault");
    let old_settings = std::fs::read(path.join("settings.zcfg")).expect("old settings");
    let vault_victim = path.join("vault-victim.txt");
    let settings_victim = path.join("settings-victim.txt");
    std::fs::write(&vault_victim, b"ZXQ-OLD-FINAL-VAULT-VICTIM").expect("vault victim");
    std::fs::write(&settings_victim, b"ZXQ-OLD-FINAL-CONFIG-VICTIM").expect("settings victim");

    symlink(&vault_victim, path.join("vault.zv.new")).expect("vault temp symlink");
    match create_entity(EntityKind::Client, "Nordstern".to_string(), None) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("the vault write should fail before replacing the old file, got {other:?}"),
    }
    assert_eq!(std::fs::read(path.join("vault.zv")).expect("vault"), old_vault);
    assert_eq!(std::fs::read(&vault_victim).expect("vault victim"), b"ZXQ-OLD-FINAL-VAULT-VICTIM");
    std::fs::remove_file(path.join("vault.zv.new")).expect("remove vault temp");

    symlink(&settings_victim, path.join("settings.zcfg.new")).expect("settings temp symlink");
    let mut s = settings().expect("settings");
    s.language = "de".to_string();
    match save_settings(s) {
        Err(ApiError::StorageRefused { reason }) => assert!(reason.contains("temporary file"), "{reason}"),
        other => panic!("the settings write should fail before replacing the old file, got {other:?}"),
    }
    assert_eq!(std::fs::read(path.join("settings.zcfg")).expect("settings"), old_settings);
    assert_eq!(std::fs::read(&settings_victim).expect("settings victim"), b"ZXQ-OLD-FINAL-CONFIG-VICTIM");
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn unlock_after_lock_sees_that_the_vault_file_was_deleted() {
    let _lock = serial();
    let dir = fresh_vault("cache-delete");
    let path = std::path::Path::new(&dir).join("vault.zv");
    vault_lock().expect("lock");
    assert_eq!(vault_state().expect("state"), VaultState::Locked, "state may look, but must not become unlock cache");
    std::fs::remove_file(&path).expect("delete vault");

    match vault_unlock_with_passphrase(PASS.to_string()) {
        // «there is no vault» no longer carries a string to be searched: the
        // variant itself is the whole fact, so nothing can word it wrongly.
        Err(ApiError::VaultAbsent) => {}
        other => panic!("unlock must reread the missing file from disk, got {other:?}"),
    }
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn unlock_after_lock_sees_that_the_vault_file_was_modified() {
    let _lock = serial();
    let dir = fresh_vault("cache-mutated");
    let path = std::path::Path::new(&dir).join("vault.zv");
    vault_lock().expect("lock");
    assert_eq!(vault_state().expect("state"), VaultState::Locked, "state may look, but must not become unlock cache");
    let mut bytes = std::fs::read(&path).expect("read vault");
    let last = bytes.len() - 1;
    bytes[last] ^= 0x01;
    std::fs::write(&path, bytes).expect("write mutated vault");

    match vault_unlock_with_passphrase(PASS.to_string()) {
        Err(ApiError::VaultAuthenticationFailed) => {}
        other => panic!("unlock must fail on the modified file from disk, got {other:?}"),
    }
    let _ = std::fs::remove_dir_all(&dir);
}

/// **A vault file of no bytes is a way out, not a trap** — the independent
/// attacker's خ6, 17 October 2026.
///
/// He wrote `vault.zv` to zero bytes and met three true-sounding answers with
/// no next move between them: the state said `Locked`, unlocking said «this
/// vault file is truncated» — which tells a person their identities are half
/// there — and creating said `VaultAlreadyExists`. The file could neither be
/// opened nor replaced.
///
/// The one ground on which this program may write over a file it finds is that
/// the file holds **nothing of the person's**, and «no bytes at all» is that
/// ground measured rather than assumed. So an empty file is not a vault: the
/// state is `Absent`, the room offers the one act that changes it, and the
/// create replaces zero bytes with a vault.
///
/// The second half is the control, and it is the half that must never move: a
/// **damaged** file holds bytes that may be the person's only copy, and it
/// keeps every old answer — `Locked`, a refusal by name, and not one byte
/// touched.
#[test]
fn an_empty_vault_file_is_not_a_vault_and_a_damaged_one_is_never_written_over() {
    let _lock = serial();
    let dir = fresh_vault("empty-file");
    let path = std::path::Path::new(&dir).join("vault.zv");
    let real = std::fs::read(&path).expect("read the vault this test made");
    vault_lock().expect("lock");

    // 1 · zero bytes: not a vault, and the door out is open.
    std::fs::write(&path, b"").expect("write an empty vault file");
    assert_eq!(
        vault_state().expect("state"),
        VaultState::Absent,
        "a file of no bytes answered as a vault, so the room offers «unlock» for nothing to unlock"
    );
    match vault_create_with_passphrase(PASS.to_string()) {
        Ok(_) => {}
        other => panic!("a file of no bytes refused to be replaced: {other:?}"),
    }
    assert!(
        std::fs::metadata(&path).expect("metadata").len() > 0,
        "the create reported success and wrote nothing"
    );
    assert_eq!(vault_state().expect("state"), VaultState::Unlocked);

    // 2 · the control: a file that holds bytes is never written over, and the
    // refusal still names itself.
    vault_lock().expect("lock");
    let mut damaged = real.clone();
    damaged.truncate(real.len() / 2);
    std::fs::write(&path, &damaged).expect("write a damaged vault file");
    assert_eq!(
        vault_state().expect("state"),
        VaultState::Locked,
        "a damaged vault file stopped being a vault, and a create would write over it"
    );
    match vault_create_with_passphrase(PASS.to_string()) {
        Err(ApiError::VaultAlreadyExists) => {}
        other => panic!("a damaged vault file was written over: {other:?}"),
    }
    assert_eq!(
        std::fs::read(&path).expect("read back"),
        damaged,
        "a byte of the person's own file was changed"
    );
    // And the refusal to open it says what it is, and never «truncated» about
    // a file that holds nothing — the two states have two sentences.
    match vault_unlock_with_passphrase(PASS.to_string()) {
        Err(ApiError::PayloadRefused { reason }) => {
            assert!(
                !reason.contains("no bytes"),
                "a damaged file is reported as an empty one: {reason}"
            );
        }
        other => panic!("expected a refusal naming the file, got {other:?}"),
    }

    // 3 · a path whose bytes cannot be read **at all** is not an empty file:
    // the symlink guard above (`final_vault_symlink_is_not_read_as_a_vault`)
    // measures that state, and it reds if this one is ever written as «bytes
    // that are there and are not empty» instead of «it was read and held
    // nothing». Named here because the two live one line apart.

    // 4 · and the empty file's own sentence names what it is.
    vault_lock().expect("lock");
    std::fs::write(&path, b"").expect("write an empty vault file");
    match vault_unlock_with_passphrase(PASS.to_string()) {
        Err(ApiError::PayloadRefused { reason }) => assert!(
            reason.contains("no bytes"),
            "an empty vault file is reported as something else: {reason}"
        ),
        // `Absent` is the honest answer here too: the state says there is no
        // vault, so a door that asks the file to open may answer either way,
        // as long as it does not call nothing «truncated».
        Err(ApiError::VaultAbsent) => {}
        other => panic!("expected a refusal naming the file, got {other:?}"),
    }

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn unlock_after_lock_still_opens_an_unchanged_vault_file() {
    let _lock = serial();
    let dir = fresh_vault("cache-control");
    identity("Cache Control", None, Kind::Company, "Cache Control GmbH", &[], Policy::Always);
    vault_lock().expect("lock");
    assert_eq!(vault_state().expect("state"), VaultState::Locked, "state may look, but must not become unlock cache");

    match vault_unlock_with_passphrase(PASS.to_string()).expect("unlock") {
        VaultUnlockOutcome::Unlocked { identities, values } => assert_eq!((identities, values), (1, 1)),
    }
    assert_eq!(entities(None).expect("entities")[0].label, "Cache Control");
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn unlock_after_lock_opens_the_replacement_vault_file_on_disk() {
    let _lock = serial();
    let replacement_dir = fresh_vault("cache-replacement-source");
    identity("Replacement Vault", None, Kind::Company, "Replacement GmbH", &[], Policy::Always);
    vault_lock().expect("lock replacement");
    let replacement = std::fs::read(std::path::Path::new(&replacement_dir).join("vault.zv")).expect("replacement bytes");

    let dir = fresh_vault("cache-replacement-target");
    identity("Cached Old Vault", None, Kind::Company, "Cached Old GmbH", &[], Policy::Always);
    let path = std::path::Path::new(&dir).join("vault.zv");
    vault_lock().expect("lock target");
    assert_eq!(vault_state().expect("state"), VaultState::Locked, "state may look, but must not become unlock cache");
    std::fs::write(&path, replacement).expect("replace vault");

    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock replacement");
    let rows = entities(None).expect("entities");
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].label, "Replacement Vault", "unlock used the file now on disk");

    let _ = std::fs::remove_dir_all(&dir);
    let _ = std::fs::remove_dir_all(&replacement_dir);
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
        assert!(matches!(
            vault_unlock_with_passphrase("falsch".to_string()),
            Err(ApiError::VaultAuthenticationFailed)
        ));
    }
    assert!(matches!(
        vault_unlock_with_passphrase("ein gutes Passwort für den Test".to_string()).expect("unlock"),
        VaultUnlockOutcome::Unlocked { .. }
    ));
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
/// **«Always» and «Profile» reach the vault — and a block reaches every
/// profile** (rule 58, the owner, 16 October).
///
/// The last section of this guard used to end «one client's value became a
/// rule about another», and the owner has now ruled that for a **block** it
/// is no rule about a client at all: the word is in his vault, he protected
/// it, and it comes back wherever he reads it. What he scoped to one client is
/// the **knowledge** — the identity, its label, its other spellings — and that
/// still does not cross: the finding in the other client's document names no
/// identity, only [`A_BLOCK`].
///
/// Measured before the flip: `by_layer` reported `Vault count 1` in the other
/// profile, with `entities: ["a word you protected"]`.
fn always_and_profile_actually_reach_the_vault() {
    let _lock = serial();
    fresh_vault("scope");
    let profile = create_profile("Client Nordstern".to_string(), None).expect("profile");

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

    // In another client's, the word comes back — from the block, which is the
    // person's own and carries no client. Rule 58.
    let other = create_profile("Client B".to_string(), None).expect("profile");
    let elsewhere = open_session(Some(other), "de".to_string()).expect("session");
    import_text(elsewhere, "Nordstern Consulting GmbH meldet sich.".to_string()).expect("import");
    let outside = scan(elsewhere).expect("scan");
    assert!(
        outside.by_layer.iter().any(|l| l.source == Source::Vault && l.count > 0),
        "a word the person protected did not cross to another client (rule 58): {:?}",
        outside.by_layer
    );
    // **And it is the block that crossed, not the client's knowledge** — the
    // half of rule two that stands. A taught value names the identity it came
    // from; a block names nobody, because nobody taught it.
    assert!(
        identities_claiming(elsewhere).is_empty(),
        "one client's own knowledge went hunting in another's document: {:?}",
        identities_claiming(elsewhere)
    );
    close_session(elsewhere).expect("close");
}

/// Where the vault is allowed to live, asked of the core on whatever machine is
/// running this.
///
/// It replaces one line of Dart — `HOME ?? systemTemp` — that was right on
/// Linux and wrong everywhere else: Windows does not set `HOME`, so the
/// fallback took over and the vault would have been written into the temp
/// directory. The test is not cfg-gated, so it is measured on every platform
/// the suite runs on, and it asserts the thing that actually matters first.
#[test]
fn the_vault_never_lives_in_the_temp_directory() {
    let chosen = default_data_dir().expect("this platform must be able to say where its data goes");
    let chosen = std::path::PathBuf::from(&chosen);
    let temp = std::env::temp_dir();

    assert!(
        !chosen.starts_with(&temp),
        "the vault would live under the temp directory: {chosen:?} is inside {temp:?}"
    );
    assert!(chosen.is_absolute(), "a relative data directory depends on where the app was started: {chosen:?}");
    assert!(
        chosen.file_name().is_some(),
        "the data directory must name a folder of ours, not a drive root: {chosen:?}"
    );

    // And it is the platform's own place, not merely «not temp».
    #[cfg(windows)]
    {
        let local = std::env::var("LOCALAPPDATA").or_else(|_| std::env::var("USERPROFILE"));
        let local = local.expect("a Windows session has LOCALAPPDATA or USERPROFILE");
        assert!(
            chosen.starts_with(&local),
            "{chosen:?} is not under this user's local application data ({local})"
        );
        assert!(
            !chosen.to_string_lossy().to_lowercase().contains("roaming"),
            "the vault belongs to this machine and must not roam between them: {chosen:?}"
        );
    }
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        let home = std::env::var("XDG_DATA_HOME").or_else(|_| std::env::var("HOME")).expect("HOME");
        assert!(chosen.starts_with(&home), "{chosen:?} is not under {home}");
    }
    #[cfg(target_os = "macos")]
    {
        let home = std::env::var("HOME").expect("HOME");
        assert!(chosen.starts_with(&home), "{chosen:?} is not under {home}");
    }
}

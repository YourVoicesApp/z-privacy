// 046/J · a label finds a name no list of ours will ever hold.
//
// The worst class of defect this project has, found on the page a camera was
// going to point at. Measured on the owner's own payroll sheet with **only the
// name in the managing director's slot changed**:
//
// ```text
//     «Sven Hallgren»      52 findings · 50 protected · 2 asked   → offered
//     «Anas Alhaddad»      51 findings · 50 protected · 1 asked   → nothing
//     «Mohammed Barakat»   51 findings · 50 protected · 1 asked   → nothing
// ```
//
// «Sven» is one of the 150 Swedish given names this build carries, so the pair
// rule had a known half to work from and the name was at least **offered**. An
// Arabic given name is in no list we carry; there was no row for
// «Verkställande direktör:»; and the pair rule needs a known half. So the name
// left the device with **no card, no question and no mark at all** — and the
// owner, whose name sits in that slot, is Arabic-speaking.
//
// A longer dictionary could never be the answer to that. The answer is a rule
// that does not care where a name comes from, and a **label** is exactly such
// a rule: whoever writes «Sammanställd av:» has told us the next words are a
// person, in any language that word belongs to.
//
// So this file's fixtures use names that are **deliberately in no list this
// build carries** — that is the whole subject. If one of them ever enters a
// dictionary, the test stops measuring what it was written for, and the
// control at the end is what says so.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord långt nog för en etikett";

/// A payroll sheet's head, invented line for line, in the shape a Swedish one
/// is written — and every name in it is in no list this build holds.
const SHEET: &str = "\
NORDVIK LOGISTIK AB — LÖNEKÖRNING\n\
Organisationsnummer: 556000-0000\n\
Verkställande direktör: Anas Alhaddad\n\
Personnummer: 19700101-0000\n\
\n\
Sammanställd av: Mohammed Barakat, Löneassistent\n\
Attesterad av: Fatima Zahra\n\
Godkänd av: Youssef Mansour\n\
Handläggare: Layla Haddad\n\
Kontaktperson: Omar Chahine\n";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-label-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

fn scanned(doc: &str, pack: &str) -> SessionId {
    let s = open_session(None, pack.to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    s
}

fn people(session: SessionId, doc: &str, state: MarkState) -> Vec<String> {
    let mut out: Vec<String> = list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == Kind::Person && f.state == state)
        .map(|f| {
            doc.chars()
                .skip(f.span.start as usize)
                .take((f.span.end - f.span.start) as usize)
                .collect::<String>()
        })
        .collect();
    out.sort();
    out.dedup();
    out
}

fn leaves_in_the_clear(session: SessionId) -> String {
    payload_view(build_payload(session).expect("payload")).expect("view").text
}

// ---------------------------------------------------------------- 1 · the leak

/// **The acceptance: five names no list knows, each protected by its label.**
#[test]
fn a_label_protects_a_name_no_dictionary_of_ours_holds() {
    let _g = serial();
    fresh_vault("labels");
    let s = scanned(SHEET, "sv");
    let protected = people(s, SHEET, MarkState::Protected);
    for who in [
        "Anas Alhaddad",     // Verkställande direktör:
        "Mohammed Barakat",  // Sammanställd av:
        "Fatima Zahra",      // Attesterad av:
        "Youssef Mansour",   // Godkänd av:
        "Layla Haddad",      // Handläggare:
    ] {
        assert!(
            protected.iter().any(|p| p == who),
            "«{who}» was named by its label and is not protected: {protected:?}"
        );
    }
    close_session(s).ok();
}

/// And nothing the labels **decided** leaves — the question the owner's film
/// actually asks.
///
/// The sixth name is deliberately not in this list, and the reason is the
/// product's own promise rather than an omission: «Kontaktperson» is a
/// question, so «Omar Chahine» is marked and **waits**. It would leave this
/// payload, and it is the next test that says why it cannot leave the app —
/// the send is blocked while a suggestion is unanswered, which is the one
/// thing Z promises. Writing it into the list above would have been a test
/// asserting that a question behaves like an answer.
#[test]
fn not_one_of_them_leaves_the_device() {
    let _g = serial();
    fresh_vault("leaves");
    let s = scanned(SHEET, "sv");
    let out = leaves_in_the_clear(s);
    for who in [
        "Anas Alhaddad",
        "Mohammed Barakat",
        "Fatima Zahra",
        "Youssef Mansour",
        "Layla Haddad",
    ] {
        assert!(!out.contains(who), "«{who}» left the device in the clear");
    }
    // And the labels themselves stay: a model that is not told it is reading a
    // payroll sheet writes a worse answer, and «Verkställande direktör» is
    // nobody's secret.
    assert!(out.contains("Verkställande direktör"), "the label was swallowed: {out:?}");
    assert!(out.contains("Löneassistent"), "the role was swallowed: {out:?}");
    close_session(s).ok();
}

/// **And the one that is only offered is counted, so the send is blocked.**
///
/// The half of the promise the test above deliberately leaves out: a name the
/// app is unsure of is in the payload, and the payload cannot be sent. One
/// unanswered name is one closed door.
///
/// Counted by **kind**, not as a total: the fixture's own company name is a
/// question too, and asserting a total of one was a test about this sheet
/// rather than about the rule. It failed the moment the company line earned
/// its own question, which is the right reason for a test to fail and the
/// wrong reason to have written it that way.
#[test]
fn the_offered_name_holds_the_door_shut() {
    let _g = serial();
    fresh_vault("door");
    let s = scanned(SHEET, "sv");
    assert_eq!(
        people(s, SHEET, MarkState::Suggested),
        vec!["Omar Chahine".to_string()],
        "exactly one name on this sheet should be waiting for an answer"
    );
    // And it is in the payload, which is what makes the door matter: the
    // value is there and the send is refused until the question is answered.
    let view = payload_view(build_payload(s).expect("payload")).expect("view");
    assert!(
        view.open_suggestions >= 1,
        "nothing is counted as unanswered, so nothing holds the door"
    );
    assert!(view.text.contains("Omar Chahine"), "the offered name is not in the payload");
    close_session(s).ok();
}

/// **The control this file needs, or it proves nothing.**
///
/// Every name above must be unknown to every list this build carries —
/// otherwise the pair rule would be doing the work and the label rows would be
/// untested. Measured by running the same sheet with the **labels taken off**:
/// nothing is found at all.
#[test]
fn with_the_labels_gone_not_one_of_them_is_found() {
    let _g = serial();
    fresh_vault("control");
    const BARE: &str = "\
Anas Alhaddad\n\
Mohammed Barakat\n\
Fatima Zahra\n\
Youssef Mansour\n\
Layla Haddad\n\
Omar Chahine\n";
    let s = scanned(BARE, "sv");
    let found: Vec<String> = people(s, BARE, MarkState::Protected)
        .into_iter()
        .chain(people(s, BARE, MarkState::Suggested))
        .collect();
    assert!(
        found.is_empty(),
        "one of these names is in a list this build carries, so the label rows are \
         not what the tests above are measuring: {found:?}"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 2 · the line

/// **«Kontaktperson» stays a question, and that is the one row of this task
/// that does.**
///
/// The owner ruled on 29 September that «Ansprechpartner» — the same word in
/// German — names a person the way a salutation does and is still a question.
/// One language may not quietly answer differently from another about the same
/// concept. The other rows are an **office** or an **act**: «Verkställande
/// direktör:» names who holds the post and «Godkänd av:» names who did the
/// thing, and neither is a slot somebody might fill with a department.
///
/// It is `Validator::Name` now rather than `Any`, because `Any` took the first
/// word only — «Kontaktperson: Omar Chahine» offered «Omar» and left the
/// surname in the clear, which is half a name and the shape 038-I was about.
#[test]
fn a_contact_person_is_offered_whole_and_not_decided() {
    let _g = serial();
    fresh_vault("contact");
    const DOC: &str = "Kontaktperson: Omar Chahine\n";
    let s = scanned(DOC, "sv");
    assert_eq!(
        people(s, DOC, MarkState::Suggested),
        vec!["Omar Chahine".to_string()],
        "the contact person is not offered whole"
    );
    assert!(
        people(s, DOC, MarkState::Protected).is_empty(),
        "a contact person was decided, and German's answer to the same word is a question"
    );
    close_session(s).ok();
}

/// **German reads none of this**, and not by an `if` about German: these are
/// rows in the Swedish set, and the one way to say so that cannot drift is to
/// run the same sheet through the German pack.
#[test]
fn the_german_pack_reads_none_of_these_labels() {
    let _g = serial();
    fresh_vault("german");
    let s = scanned(SHEET, "de");
    let found: Vec<String> = people(s, SHEET, MarkState::Protected)
        .into_iter()
        .chain(people(s, SHEET, MarkState::Suggested))
        .collect();
    assert!(
        found.is_empty(),
        "the German pack read a Swedish payroll label: {found:?}"
    );
    close_session(s).ok();
}

/// A label that names a person must not take a word that is not one. «Vakant»
/// — the post is empty — is the case a payroll sheet actually writes, and it is
/// the cost this row would pay if it paid any.
///
/// What is measured is **what it costs, not that it costs nothing**: the word
/// is taken, because the row cannot tell a name from a Swedish adjective and
/// nothing in this build can. It is one false protection on a line that holds
/// no person, so nothing is exposed and nothing is lost — the model reads a
/// token where a sheet said «empty». Named here so it is a decision; it closes
/// with a list of non-name words in the pack, which is pack data and another
/// task's.
#[test]
fn an_empty_post_is_taken_and_that_is_the_price() {
    let _g = serial();
    fresh_vault("vacant");
    const DOC: &str = "Verkställande direktör: Vakant\n";
    let s = scanned(DOC, "sv");
    assert_eq!(
        people(s, DOC, MarkState::Protected),
        vec!["Vakant".to_string()],
        "the price of this row has changed — read the note above before accepting it"
    );
    close_session(s).ok();
}

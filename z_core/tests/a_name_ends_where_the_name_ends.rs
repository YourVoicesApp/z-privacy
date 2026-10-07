// 046/C · a name ends where the name ends.
//
// Measured by the lead on `fad220f`, and still true on `a7eab34`: the only
// person found in either English film document was this, as one finding, with
// the job title inside the token —
//
// ```text
//     Contact person: Eleanor Whitfield, Finance Director
//                     └──────── one Person ────────────┘
// ```
//
// `bare()` strips a trailing comma before the word is judged, so «Whitfield,»
// reads as «Whitfield», and «Finance» and «Director» are capitalised too. The
// run simply kept going. What leaves the device is then a token that swallowed
// a job title, and the model loses a word it needed to write the sentence —
// the same cost as a salutation taken into a name, which is why honorifics
// were taken out of this run on 29 September.
//
// **What this may not break, and both are named below as tests rather than as
// comments:** the German reversed pair «Nachname, Vorname» and the Swedish
// «X, <role>» rule read across a comma *on purpose*. They live in
// `packs/people.rs` and not in the label path this change touches, and the
// only way to know that is still true is to run them.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "a passphrase long enough for one name";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-ends-{name}-{}", std::process::id()));
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

/// The people in this document, whatever state they are in, as the text they
/// cover.
fn people(session: SessionId, doc: &str) -> Vec<String> {
    let mut out: Vec<String> = list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == Kind::Person)
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

// ---------------------------------------------------------------- 1 · the film

/// **The acceptance, from the owner's own film document.**
#[test]
fn a_job_title_after_a_comma_is_not_part_of_the_name() {
    let _g = serial();
    fresh_vault("title");
    const DOC: &str = "Contact person: Eleanor Whitfield, Finance Director\nEmail: e@x.co.uk\n";
    let s = scanned(DOC, "en");
    assert_eq!(
        people(s, DOC),
        vec!["Eleanor Whitfield".to_string()],
        "the name did not end at the comma"
    );
    close_session(s).ok();
}

/// And the job title stays **in the clear**, which is the other half: a model
/// that is not told it is writing to a finance director writes a worse letter,
/// and the title is nobody's secret.
#[test]
fn the_job_title_still_reaches_the_model() {
    let _g = serial();
    fresh_vault("clear");
    const DOC: &str = "Contact person: Eleanor Whitfield, Finance Director\n";
    let s = scanned(DOC, "en");
    let out = payload_view(build_payload(s).expect("payload")).expect("view").text;
    assert!(
        out.contains("Finance Director"),
        "the job title was swallowed by the token: {out:?}"
    );
    assert!(!out.contains("Whitfield"), "the name leaked: {out:?}");
    assert_eq!(out.matches("__Z_").count(), 1, "the name left as more than one token: {out:?}");
    close_session(s).ok();
}

/// A name already ended at the end of its line, and it still does. The control
/// for the change: if this ever failed, the comma rule would have been written
/// as a replacement for the line rule rather than beside it.
#[test]
fn a_name_still_ends_at_the_end_of_its_line() {
    let _g = serial();
    fresh_vault("line");
    const DOC: &str = "Contact person: Eleanor Whitfield\nFinance Director of the group\n";
    let s = scanned(DOC, "en");
    assert_eq!(people(s, DOC), vec!["Eleanor Whitfield".to_string()]);
    close_session(s).ok();
}

/// Three capitalised words before the comma are three words of a name. The
/// rule is about the comma, not about a length.
#[test]
fn the_comma_ends_the_name_whatever_its_length() {
    let _g = serial();
    fresh_vault("three");
    const DOC: &str = "Contact: Mary Anne Whitfield, Partner\n";
    let s = scanned(DOC, "en");
    assert_eq!(people(s, DOC), vec!["Mary Anne Whitfield".to_string()]);
    close_session(s).ok();
}

/// **A name with a lowercase particle is a separate gap, and it is not this
/// one.**
///
/// `Validator::Name` asks every word of the run to start with a capital, so
/// «Maria de Vries» ends at «Maria». Measured while writing the test above,
/// which first used that name and failed for a reason that had nothing to do
/// with a comma. Pinned here so the next person meets it as a number rather
/// than as a surprise — «van», «de», «von», «bin» and «al-» are all this
/// shape, and the fix is a list of particles in the pack, which is pack data
/// and another task's.
#[test]
fn a_lowercase_particle_still_ends_the_name_and_that_is_a_known_gap() {
    let _g = serial();
    fresh_vault("particle");
    const DOC: &str = "Contact: Maria de Vries, Partner\n";
    let s = scanned(DOC, "en");
    assert_eq!(
        people(s, DOC),
        vec!["Maria".to_string()],
        "the particle gap has moved — if a pack now carries particles, this test \
         should become «Maria de Vries»"
    );
    close_session(s).ok();
}

/// **What the comma rule costs, named so it is a decision.**
///
/// «Label: Surname, Role» — one name and a role — keeps the role inside the
/// name, because a comma after **one** word is the German reversed pair
/// «Nachname, Vorname» and behind a label this rule is the only thing that
/// covers it. Stopping at every comma left «Thomas» in the clear beside a
/// protected «Müller», which is the exact shape of the defect the owner met in
/// 038-I — worse than a job title inside a token.
///
/// Measured: not one of the four film documents writes «Label: Surname, Role».
/// The day one does, the answer is to let `reversed_pairs` read behind a label
/// so the dictionary can tell a given name from a role, and then this test
/// becomes «Müller».
#[test]
fn a_one_word_name_before_a_comma_keeps_what_follows() {
    let _g = serial();
    fresh_vault("one-word");
    const DOC: &str = "Ansprechpartner: Müller, Geschäftsführer\n";
    let s = scanned(DOC, "de");
    assert_eq!(
        people(s, DOC),
        vec!["Müller, Geschäftsführer".to_string()],
        "the one-word case has changed — read the note above before accepting it"
    );
    close_session(s).ok();
}

/// **And the role rule's own span, which this task had to fix to measure
/// anything in German.**
///
/// Mine, from 038-B/2, and reachable on prose with no label rule in it at all:
/// the «X, <role>» shape walked back over every name-shaped word — **including
/// a label**, a word ending in a colon — and then took the pair *starting*
/// there, which is a different pair once the run is longer than two.
///
/// ```text
///     Der Vorgang: Thomas Müller, Geschäftsführer
///         └── «Vorgang: Thomas» offered as a person ──┘
/// ```
///
/// Two names joined from a label and a given name, offered to a person as
/// somebody's name. The shape is two words, so it is the comma's word and the
/// one before it, or it is not this shape.
#[test]
fn the_role_rule_takes_the_two_words_the_comma_ends() {
    let _g = serial();
    fresh_vault("role-span");
    const DOC: &str = "Der Vorgang: Thomas Müller, Geschäftsführer\n";
    let s = scanned(DOC, "de");
    let found = people(s, DOC);
    assert_eq!(
        found,
        vec!["Thomas Müller".to_string()],
        "the role rule is reading the wrong two words"
    );
    assert!(
        !found.iter().any(|p| p.contains("Vorgang")),
        "a label word is inside a person's name: {found:?}"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 2 · the line

/// **The German reversed pair reads across a comma on purpose.**
///
/// «Müller, Thomas» is a list of people written the way lists of people are
/// written, and the word before the comma is the surname. It is found by
/// `packs::people::reversed_pairs` and not by the label path, so the change
/// cannot reach it — and this test is the only thing that knows that for
/// certain.
#[test]
fn the_german_reversed_pair_is_untouched() {
    let _g = serial();
    fresh_vault("reversed");
    const DOC: &str = "Ansprechpartner: Müller, Thomas\nTelefon: 030 1234\n";
    let s = scanned(DOC, "de");
    let found = people(s, DOC);
    assert!(
        found.iter().any(|p| p == "Müller, Thomas"),
        "the reversed pair stopped reading across its comma: {found:?}"
    );
    close_session(s).ok();
}

/// **And the Swedish «X, <role>» rule, which is 038-B/2's.**
///
/// «Anna Nilsson, programchef» offers the pair because the role after the
/// comma is the evidence. A comma rule written in the wrong place would have
/// taken the evidence away.
#[test]
fn the_swedish_role_after_a_comma_is_untouched() {
    let _g = serial();
    fresh_vault("role");
    const DOC: &str = "Anna Nilsson, programchef\nberättar om satsningen.\n";
    let s = scanned(DOC, "sv");
    let found = people(s, DOC);
    assert!(
        found.iter().any(|p| p == "Anna Nilsson"),
        "the Swedish role rule lost its pair: {found:?}"
    );
    close_session(s).ok();
}

/// The German label path has the same shape as the English one, so the change
/// has to be measured there too — and a German letter writes a job title after
/// a comma exactly as an English one does.
#[test]
fn the_german_label_path_stops_at_the_comma_too() {
    let _g = serial();
    fresh_vault("german-label");
    const DOC: &str = "Ansprechpartner: Thomas Müller, Geschäftsführer\n";
    let s = scanned(DOC, "de");
    let found = people(s, DOC);
    assert!(
        found.iter().any(|p| p == "Thomas Müller"),
        "the German label did not stop at the comma: {found:?}"
    );
    assert!(
        !found.iter().any(|p| p.contains("Geschäftsführer")),
        "a German job title is inside the name: {found:?}"
    );
    close_session(s).ok();
}

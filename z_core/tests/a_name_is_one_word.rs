// 085 ruling 1, over the rules that find names — the owner's law of 14 October:
// «التشفير لا يأخذ أكثر من كلمة».
//
// It was built into the **selection** that day, and the scanner was left as it
// was. The owner's own test of 15 October found the half that was missed: in
// «Falls Sie Fragen haben, erreichen Sie Ihre Sachbearbeiterin Frau Katrin
// Sommer…» the salutation rule handed back one Person covering two words, and
// the signature rule handed back the same two words again at the bottom of the
// page. One token stood where two names stood, twice.
//
// **The limit of the law is in here too**, because it is the part that is easy
// to lose: the owner corrected the lead the same day — «التحديد له قوانينه لأنه
// مرتبط بإرادة المستخدم». A value the **person** settled is one value however
// many words it has, and the vault is the only layer whose values come from the
// person. So the law binds what the app read out of a document, and not what
// the person gave it.
//
// And it is a law about **names**. An address spanning two lines is paper 088's
// open question and waits for the owner; a company's legal form is part of its
// name; a number may span spaces by ruling 2 of this same paper, by kind. Each
// of those is measured here as **unchanged**, so that the law cannot quietly
// grow past what it says.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const FELDMANN: &str = include_str!("fixtures/Mahnung_Feldmann.txt");
const WEBER: &str = include_str!("fixtures/Brief_Weber.txt");
const KELLER: &str = include_str!("fixtures/Mahnung_Keller.txt");
const LINDQVIST: &str = include_str!("fixtures/Brev_Lindqvist.txt");
const NORDSTERN: &str = include_str!("fixtures/Vertrag_Nordstern.txt");
const LOHN: &str = include_str!("fixtures/Lohnabrechnung_Weber.txt");
const PASS: &str = "ein ausreichend langes Passwort hierfür";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn found(doc: &str, lang: &str) -> Vec<(MarkState, Kind, String, String)> {
    // **This reading is the packs' own, and it says so** — the core's vault
    // state is global to the process, so a vault another test in this file
    // created is still open when this one runs. Harmless until 16 October,
    // when rule 55 gave every import a session to write blocks from: a
    // vault-sourced hint then answers for a word this file is measuring a pack
    // on, and the reading becomes the vault's. So the premise is stated rather
    // than inherited: the vault is shut and the directory is this file's own
    // and empty.
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-one-word-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    let s = open_session(None, lang.to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    let out = list_findings(s)
        .expect("findings")
        .into_iter()
        .map(|f| {
            let text = String::from_utf16_lossy(
                units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
            );
            (f.state, f.kind, text, f.reason)
        })
        .collect();
    close_session(s).ok();
    out
}

fn people(doc: &str, lang: &str) -> Vec<(MarkState, String)> {
    found(doc, lang)
        .into_iter()
        .filter(|(_, kind, _, _)| *kind == Kind::Person)
        .map(|(state, _, text, _)| (state, text))
        .collect()
}

fn names_only(doc: &str, lang: &str) -> Vec<String> {
    people(doc, lang).into_iter().map(|(_, text)| text).collect()
}

// --------------------------------------------------- 1 · the owner's own case

/// **«Frau Katrin Sommer» is two names, so it is two tokens.**
///
/// His letter, at the place he looked: the salutation rule names the person who
/// follows it, and two of them follow it.
#[test]
fn a_salutation_names_each_word_of_the_name_it_introduces() {
    let _g = serial();
    let one = "erreichen Sie Ihre Sachbearbeiterin Frau Katrin Sommer unter 0341 2208 4417";
    let names = names_only(one, "de");
    assert_eq!(names, vec!["Katrin".to_string(), "Sommer".to_string()], "{names:?}");
    // And the reason is still the salutation's own sentence on both of them:
    // splitting the span may not cost a person the «why».
    for (_, _, _, reason) in found(one, "de").iter().filter(|f| f.1 == Kind::Person) {
        assert!(reason.contains("a salutation names the person who follows it"), "{reason}");
    }
}

/// **The signature rule, the second place in his letter** — and it is the same
/// law, not a second one: both rules are answered in one place.
#[test]
fn a_signature_names_each_word_of_the_name_it_stands_for() {
    let _g = serial();
    let signed = "Mit freundlichen Grüßen\n\nKatrin Sommer\nKundenservice\n";
    assert_eq!(
        names_only(signed, "de"),
        vec!["Katrin".to_string(), "Sommer".to_string()]
    );
}

/// **A title chain** — «Dr. Heike Brandt», from his second German letter.
#[test]
fn a_title_names_each_word_of_the_name_it_introduces() {
    let _g = serial();
    assert_eq!(
        names_only("Unterschrieben von Dr. Heike Brandt am Montag.", "de"),
        vec!["Heike".to_string(), "Brandt".to_string()]
    );
}

/// **The dictionary pair**, which offers rather than protects — and offers each
/// word, because a person answering «is this a name?» is answering about a word.
#[test]
fn the_dictionary_pair_offers_each_word() {
    let _g = serial();
    assert_eq!(
        people("Markus Feldmann kommt.", "de"),
        vec![
            (MarkState::Suggested, "Markus".to_string()),
            (MarkState::Suggested, "Feldmann".to_string())
        ]
    );
}

/// **The reversed pair**, the shape a list of people is written in.
#[test]
fn the_reversed_pair_offers_each_word() {
    let _g = serial();
    assert_eq!(
        names_only("Feldmann, Markus\nSommer, Katrin\n", "de"),
        vec![
            "Feldmann".to_string(),
            "Markus".to_string(),
            "Sommer".to_string(),
            "Katrin".to_string()
        ]
    );
}

// ------------------------------------------------- 2 · every rule, not these five

/// **The law is asked once, so no rule can be the one that forgot it.**
///
/// The fault this file exists for was two rules making the same mistake in two
/// places, and the trap named in
/// `a_rule_written_in_place_is_not_applied_to_its_second_case` is that a sixth
/// rule written tomorrow makes it a third time. So this sweeps **every** Person
/// finding of every fixture in the tree — six documents, four languages — and
/// asks one thing of all of them: no name a rule found covers a space.
#[test]
fn no_name_the_app_found_covers_more_than_one_word() {
    let _g = serial();
    for (what, doc, lang) in [
        ("Mahnung_Feldmann", FELDMANN, "de"),
        ("Brief_Weber", WEBER, "de"),
        ("Mahnung_Keller", KELLER, "de"),
        ("Brev_Lindqvist", LINDQVIST, "sv"),
        ("Vertrag_Nordstern", NORDSTERN, "de"),
        ("Lohnabrechnung_Weber", LOHN, "de"),
    ] {
        for (_, name) in people(doc, lang) {
            assert!(
                !name.chars().any(char::is_whitespace),
                "{what}: «{}» is more than one word",
                name.replace('\n', "⏎")
            );
        }
    }
}

// ----------------------------------------------------------- 3 · what it is not

/// **The limit, and it is the half that is easy to lose.**
///
/// The person taught «Anna-Lena Bergström» as one value. That is their will
/// about a value, which is the very thing 085's own correction exempts, and the
/// vault is the only layer whose values come from the person. One finding, one
/// token, two words — and 038-I's three guards rest on this line too.
#[test]
fn a_value_the_person_taught_stays_one_value() {
    let _g = serial();
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-one-word-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
    let e = create_entity(EntityKind::Person, "Klient".to_string(), None).expect("entity");
    set_value(e, None, Kind::Person, "Anna-Lena Bergström".to_string(), Policy::Always)
        .expect("value");

    let doc = "Hälsningar Anna-Lena Bergström\n";
    let s = open_session(None, "sv".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    let names: Vec<String> = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == Kind::Person)
        .map(|f| {
            String::from_utf16_lossy(
                units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
            )
        })
        .collect();
    assert_eq!(names, vec!["Anna-Lena Bergström".to_string()], "{names:?}");
    close_session(s).ok();
    let _ = vault_lock();
}

/// **A company's legal form is part of its name**, and an address that spans two
/// lines is paper 088's open question — neither is a name, and the law says
/// «name». Measured as unchanged, so the law cannot grow past its own words.
#[test]
fn the_other_kinds_are_left_exactly_as_they_were() {
    let _g = serial();
    let other: Vec<(Kind, String)> = found(FELDMANN, "de")
        .into_iter()
        .filter(|(_, kind, _, _)| *kind != Kind::Person)
        .map(|(_, kind, text, _)| (kind, text))
        .collect();
    assert!(
        other.iter().any(|(k, t)| *k == Kind::Company && t == "Stadtwerke Lindenau GmbH"),
        "{other:?}"
    );
    assert!(
        other.iter().any(|(k, t)| *k == Kind::Iban && t == "DE89 3704 0044 0532 0130 00"),
        "{other:?}"
    );
    assert!(
        other.iter().any(|(k, t)| *k == Kind::Address && t.contains('\n')),
        "{other:?}"
    );
}

// ------------------------------------------------- 4 · what the law costs

/// **How far a decision reaches, and where it stops** — the lead's ruling of
/// 15 October, made necessary by the law above.
///
/// A decision now reaches as far as a **word**, because the unit of a token is
/// a word. That is what the owner wanted: one answer about «Feldmann» covers
/// «Herr Feldmann», «Markus Feldmann» and «Feldmann» alike.
///
/// And in DE-1 it reached one word too far. «Katharina Lindemann» is the
/// client, her employer is «Lindemann & Partner GmbH», and protecting the
/// surname took the company's own first word — with `_PERSON_` inside the
/// token — so the company line stopped waiting for the answer it was waiting
/// for. Two of DE-1's eight questions were being settled by a decision about
/// something else.
///
/// **The rule:** a decision about a word reaches every place where that word
/// **stands alone**, and never a place lying inside a finding of another kind.
/// That finding keeps its own question, and the person's answer then decides it
/// whole — one COMPANY token over «Lindemann & Partner GmbH», or left in the
/// clear. One answer may never silently answer a question of another kind,
/// which is C3's spirit: nothing leaves, and nothing is settled, without the
/// person's word.
///
/// The class of fault is **older than the law** — a salutation that names only
/// a surname has always protected one word with the reach of the conversation —
/// and the law turned it from rare into ordinary, so it is answered in the same
/// round.
#[test]
fn a_surname_inside_a_company_name_keeps_the_companys_own_question() {
    let _g = serial();
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, WEBER.to_string()).expect("import");
    scan(s).expect("scan");

    // The company is still a question, and it is whole.
    let waiting: Vec<String> = found(WEBER, "de")
        .into_iter()
        .filter(|(state, kind, _, _)| *state == MarkState::Suggested && *kind == Kind::Company)
        .map(|(_, _, text, _)| text)
        .collect();
    assert!(
        waiting.iter().any(|c| c == "Lindemann & Partner GmbH"),
        "the company's question was settled by a decision about a person: {waiting:?}"
    );

    // And its own first word is in the clear until that question is answered —
    // where before the ruling a `_PERSON_` token stood in it.
    let out = payload_view(build_payload(s).expect("payload")).expect("view").text;
    let line = out
        .lines()
        .find(|l| l.contains("& Partner GmbH"))
        .expect("the account holder's line");
    assert!(
        line.contains("Lindemann & Partner GmbH"),
        "a decision about a person reached inside a company's name: {line:?}"
    );
    close_session(s).ok();
}

// ------------------------------------------------- 5 · the selection door

/// **A hand drawn over the whole of a name is told it is ours** — the lead's
/// ruling of 15 October, and the other half of the law's cost.
///
/// `inspect_selection` matched a finding **exactly**, so the moment a name
/// became two findings a drag over the whole of it matched neither: the kind
/// the pack had found went missing, and a value entirely ours was reported as
/// ordinary words. The answer is read at the same finer grain instead of
/// guessed at — the spans must lie inside the selection, agree on their kind,
/// and leave nothing in it but whitespace — and the view **lists** the tokens
/// rather than the button growing a sixth state.
#[test]
fn a_hand_over_the_whole_of_a_name_is_told_it_is_already_ours() {
    let _g = serial();
    let doc = "Ihre Sachbearbeiterin Frau Katrin Sommer ist da.\n";
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let at = |needle: &str| {
        let byte = doc.find(needle).expect("needle");
        let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
        Span {
            start: start as u32,
            end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
        }
    };

    // The whole name: ours, two tokens, and the pack's own kind.
    let whole = inspect_selection(s, at("Katrin Sommer")).expect("inspect");
    assert_eq!(whole.protected_as.len(), 2, "{:?}", whole.protected_as);
    assert_eq!(whole.kind, Kind::Person);
    assert!(whole.snaps_to.is_empty(), "{:?}", whole.snaps_to);

    // One word of it: ours, one token — which is what «one token one word»
    // means at this door too.
    let half = inspect_selection(s, at("Sommer")).expect("inspect");
    assert_eq!(half.protected_as.len(), 1, "{:?}", half.protected_as);
    assert_eq!(half.kind, Kind::Person);

    // A word nobody named, inside the drag: then the selection is not ours,
    // and the button offers the snap it always offered.
    let more = inspect_selection(s, at("Katrin Sommer ist")).expect("inspect");
    assert!(more.protected_as.is_empty(), "{:?}", more.protected_as);
    assert_eq!(more.kind, Kind::Custom);
    assert_eq!(more.snaps_to.len(), 2, "{:?}", more.snaps_to);

    // And a click **inside** a word is unchanged: a part of a value is not the
    // value, which is the line the lead drew on 14 October.
    let inside = inspect_selection(s, Span { start: at("Sommer").start, end: at("Sommer").start + 3 })
        .expect("inspect");
    assert!(inside.protected_as.is_empty(), "{:?}", inside.protected_as);
    assert_eq!(inside.kind, Kind::Custom);
    close_session(s).ok();
}

/// **And the hand door itself still makes one token for two words.**
///
/// 085's own correction, at the place it was ruled about: «النقرتان تصنعان
/// كوداً واحداً بأمر من المستخدم». A name no rule of ours found, drawn by hand,
/// is one value and one token — measured here so the law above can never reach
/// it.
#[test]
fn a_hand_selection_of_a_name_nobody_found_is_still_one_token() {
    let _g = serial();
    let doc = "Protokoll 2026: Xander Qvistbergh ringde.\n";
    let s = open_session(None, "sv".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let byte = doc.find("Xander Qvistbergh").expect("needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    let span = Span {
        start: start as u32,
        end: (start + "Xander Qvistbergh".chars().map(char::len_utf16).sum::<usize>()) as u32,
    };
    protect(s, span, Scope::Conversation, Kind::Person).expect("protect by hand");
    let view = inspect_selection(s, span).expect("inspect");
    assert_eq!(view.protected_as.len(), 1, "{:?}", view.protected_as);
    let out = payload_view(build_payload(s).expect("payload")).expect("view").text;
    assert_eq!(out.matches("__Z_").count(), 1, "{out:?}");
    close_session(s).ok();
}

// -------------------------------------------------------------- 6 · the payload

/// **And what leaves the device**: two tokens where the two names stood, and no
/// half of the name in the clear beside them.
#[test]
fn the_name_leaves_as_two_tokens_and_no_half_of_it_stays() {
    let _g = serial();
    let one = "erreichen Sie Ihre Sachbearbeiterin Frau Katrin Sommer unter.";
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, one.to_string()).expect("import");
    scan(s).expect("scan");
    let out = payload_view(build_payload(s).expect("payload")).expect("view").text;
    assert!(!out.contains("Katrin"), "a name went to the model: {out:?}");
    assert!(!out.contains("Sommer"), "a name went to the model: {out:?}");
    assert_eq!(out.matches("__Z_").count(), 2, "{out:?}");
    close_session(s).ok();
}

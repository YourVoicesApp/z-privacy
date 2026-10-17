// **A reason a person reads has to be true** — the detection round of 14
// October, item 2.
//
// «Ltd» is not a German legal form; it is English. But the sentence that says
// so is written in `packs/people.rs`, the shared half of every pack — the file
// whose own first line says that not one word in it is German, Swedish or
// English — and it had the word «German» typed into three of its reasons. So a
// Swedish letter was told that «AB» is a German legal form, that «Hej
// Katarina» is a German salutation, and that Katarina Lindqvist is in the
// German name dictionary.
//
// And the numbers in that third sentence were a year out of date in the
// language it *was* written for: it says «the 300 given names and the ten
// surnames», and the dictionary this build ships for German holds 5,712 and
// 3,246. A reason that names a number must read it from the thing it is
// counting.
//
// Measured on two real letters, one Swedish and one German, because a reason is
// only wrong in front of a document.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const SWEDISH: &str = include_str!("fixtures/Brev_Lindqvist.txt");
const GERMAN: &str = include_str!("fixtures/Brief_Weber.txt");

/// Every language this build carries, by the English name a reason would use.
const LANGUAGES: &[&str] = &["German", "Swedish", "English"];

/// **A word of the person's own, as a reason now quotes it** — 17 October: the
/// core isolates every such word (`text::their_own_word`), so «AB» inside a
/// sentence of ours now stands between `U+2068` and `U+2069`. The guards below
/// ask for the word in the sentence, and the sentence is what changed; this is
/// what they ask with, in one place rather than four.
///
/// The pair is written as escapes and never as the characters themselves:
/// rustc denies a direction codepoint in a literal, for the same reason this
/// whole law exists — a file somebody reads should not have its own order
/// changed by what it quotes.
fn quoted(word: &str) -> String {
    format!("«\u{2068}{word}\u{2069}»")
}

fn reasons(pack: &str, text: &str) -> Vec<String> {
    let s = open_session(None, pack.to_string()).expect("open");
    import_text(s, text.to_string()).expect("import");
    scan(s).expect("scan");
    list_findings(s)
        .expect("findings")
        .into_iter()
        .map(|f| f.reason)
        .collect()
}

/// The counts the pack's own dictionary reports, so this guard holds no second
/// copy of a number that lives in a CSV.
fn dictionary_of(pack: &str) -> (u32, u32) {
    let row = packs()
        .expect("packs")
        .into_iter()
        .find(|p| p.id == pack)
        .expect("the pack is installed");
    (row.given, row.family)
}

#[test]
fn a_swedish_letter_is_never_told_its_words_are_german() {
    for reason in reasons("sv", SWEDISH) {
        assert!(
            !reason.contains("German"),
            "a Swedish document is given a German reason: {reason}"
        );
    }
}

#[test]
fn a_company_form_belongs_to_the_language_that_lists_it() {
    // «AB» is Swedish, «GmbH» is German, and the sentence is the same sentence.
    let swedish = reasons("sv", SWEDISH);
    assert!(
        swedish.iter().any(|r| r.contains(&quoted("AB")) && r.contains("legal form in Swedish")),
        "no reason says «AB» is a legal form in Swedish: {swedish:?}"
    );
    let german = reasons("de", GERMAN);
    assert!(
        german.iter().any(|r| r.contains(&quoted("GmbH")) && r.contains("legal form in German")),
        "no reason says «GmbH» is a legal form in German: {german:?}"
    );
}

/// **And a greeting belongs to it too, which is the half this guard could not
/// show until today.**
///
/// It used to assert the **absence** of the word «salutation» from every
/// Swedish reason, and said why in prose: the letter opens with «Hej», and
/// `packs/sv.rs` listed «Herr», «Fru», «Fröken» and no greeting, so its first
/// name was offered by the dictionary rule and protected by nothing. Reported
/// as a finding of its own on 14 October.
///
/// That absence is exactly the shape `a_guard_green_for_the_wrong_reason`
/// names: when the greeting list arrived on 15 October, the Swedish letter
/// gained a reason reading «in Swedish a greeting …», which holds no «salutation»
/// either — so the old assertion would have stayed green while measuring
/// nothing. Both lists are asked by name now, and each is asked to name its own
/// language.
#[test]
fn a_salutation_belongs_to_the_language_that_lists_it() {
    let german = reasons("de", GERMAN);
    assert!(
        german.iter().any(|r| r.contains("in German a salutation")),
        "the German salutation rule no longer names its own language: {german:?}"
    );
    // The Swedish letter's own opening, by the second list — «in Swedish a
    // greeting», and never «in German» and never «a salutation».
    let swedish = reasons("sv", SWEDISH);
    assert!(
        swedish.iter().any(|r| r.contains("in Swedish a greeting")),
        "the Swedish greeting rule no longer names its own language: {swedish:?}"
    );
    assert!(
        !swedish.iter().any(|r| r.contains("salutation")),
        "a greeting is being called a salutation, or a Swedish salutation now \
         fires and this guard must assert «in Swedish a salutation» too: {swedish:?}"
    );
    // And the German letter, the other way round: it opens formally, so no
    // reason in it may call that a greeting.
    assert!(
        !german.iter().any(|r| r.contains("a greeting")),
        "a German salutation is being called a greeting: {german:?}"
    );
}

#[test]
fn the_name_dictionary_counts_the_names_it_actually_holds() {
    for (pack, text) in [("sv", SWEDISH), ("de", GERMAN)] {
        let (given, family) = dictionary_of(pack);
        let said: Vec<String> = reasons(pack, text)
            .into_iter()
            .filter(|r| r.contains("name dictionary"))
            .collect();
        assert!(!said.is_empty(), "the dictionary rule found nobody in the {pack} letter");
        for reason in said {
            assert!(
                reason.contains(&format!("{given} given names")),
                "the reason names a number of given names the dictionary does not have \
                 ({given} shipped): {reason}"
            );
            assert!(
                reason.contains(&format!("{family} surnames")),
                "the reason names a number of surnames the dictionary does not have \
                 ({family} shipped): {reason}"
            );
        }
    }
}

#[test]
fn no_reason_names_a_language_the_document_is_not_read_with() {
    // The law, over every pack this build carries: the shared rules may name a
    // language, and it is always the one whose words they just read.
    for (pack, text, mine) in [("sv", SWEDISH, "Swedish"), ("de", GERMAN, "German")] {
        for reason in reasons(pack, text) {
            for other in LANGUAGES.iter().filter(|l| **l != mine) {
                assert!(
                    !reason.contains(other),
                    "a document read with the {pack} pack carries a reason about {other}: {reason}"
                );
            }
        }
    }
}

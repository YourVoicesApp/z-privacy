// **A greeting is not a salutation** — the lead's approved shape of 14 October,
// built 15 October: *«one rule, two lists — `greetings` beside `salutations`,
// one walk reading both, and the only difference the confidence each carries
// and the clause that says which.»*
//
// Why it exists: the owner's Swedish letters all open «Hej», and `packs/sv.rs`
// listed «Herr», «Fru», «Fröken» and no greeting — so a Swedish letter's first
// name was carried by the name dictionary or by nothing at all. That was
// reported as a finding of its own on 14 October and pinned as the absence of
// the word «salutation» from every Swedish reason.
//
// **Why it offers and never protects.** A salutation is proof: nothing but a
// person follows «Frau». A greeting is read by the same shape and proves
// nothing — «Hej alla», «Hej och tack», «Hallo zusammen». The reason says so in
// the owner's own distinction: *a greeting is often followed by a name, which
// is not the same as naming one.*
//
// **What it buys, and what it only re-offers.** On the owner's first Swedish
// letter it adds «Anna», whom nothing found before. On `Brev_Lindqvist.txt` it
// adds nothing — «Katarina Lindqvist» is already offered by the pair rule, two
// known names in a row — and that is measured here rather than left unsaid,
// because a rule that only re-offers is a thing to know about. In English it
// buys most, because English ships the smallest name bank of the three.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const SWEDISH: &str = include_str!("fixtures/Brev_Lindqvist.txt");

fn found(doc: &str, lang: &str) -> Vec<(MarkState, String, String)> {
    let s = open_session(None, lang.to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    let out = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == Kind::Person)
        .map(|f| {
            let text = String::from_utf16_lossy(
                units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
            );
            (f.state, text, f.reason)
        })
        .collect();
    close_session(s).ok();
    out
}

/// What the greeting rule itself said, and nothing another layer said.
fn by_the_greeting(doc: &str, lang: &str) -> Vec<(MarkState, String)> {
    found(doc, lang)
        .into_iter()
        .filter(|(_, _, reason)| reason.contains("a greeting is often followed by a name"))
        .map(|(state, text, _)| (state, text))
        .collect()
}

// ---------------------------------------------------------- 1 · the acceptance

/// **A name after a greeting is offered, word by word, and never protected.**
#[test]
fn a_name_after_a_swedish_greeting_is_offered() {
    assert_eq!(
        by_the_greeting("Hej Yusuf Demir,\n\nTack för ert brev.\n", "sv"),
        vec![
            (MarkState::Suggested, "Yusuf".to_string()),
            (MarkState::Suggested, "Demir".to_string()),
        ]
    );
    // A given name alone, which is the ordinary Swedish opening.
    assert_eq!(
        by_the_greeting("Hej Birgitta,\n\nTack.\n", "sv"),
        vec![(MarkState::Suggested, "Birgitta".to_string())]
    );
}

/// **And the sentence says which list it came from, in the pack's language.**
#[test]
fn the_reason_names_the_language_and_says_a_greeting_is_not_proof() {
    let reasons: Vec<String> = found("Hej Yusuf Demir,\n\nTack.\n", "sv")
        .into_iter()
        .map(|(_, _, reason)| reason)
        .collect();
    assert!(!reasons.is_empty());
    for reason in reasons {
        assert!(reason.contains("in Swedish a greeting"), "{reason}");
        assert!(
            reason.contains("which is not the same as naming one"),
            "the reason does not say why it is only an offer: {reason}"
        );
        assert!(
            !reason.contains("salutation"),
            "a greeting is being called a salutation: {reason}"
        );
    }
}

/// **The two lists are one walk**, so the title chain, the three-word reach and
/// the word shape are the same for both — measured and not assumed.
///
/// And the title is the stronger evidence, so it is the title that is reported:
/// `settle` keeps the proven finding and names the greeting beside it. That is
/// the measurement this test is really after — the greeting reached the same
/// two words, and nothing had to teach it the title.
#[test]
fn a_greeting_steps_over_a_title_exactly_as_a_salutation_does() {
    let found = found("Hej dr. Amira Haddad,\n\nTack.\n", "sv");
    assert_eq!(
        found.iter().map(|(s, w, _)| (*s, w.clone())).collect::<Vec<_>>(),
        vec![
            (MarkState::Protected, "Amira".to_string()),
            (MarkState::Protected, "Haddad".to_string()),
        ],
        "{found:?}"
    );
    for (_, who, reason) in &found {
        assert!(
            reason.contains("a title introduces the person who follows it"),
            "«{who}»: the title is not what was reported: {reason}"
        );
        assert!(
            reason.contains("sv:greeting agreed as well"),
            "«{who}»: the greeting did not reach past the title: {reason}"
        );
    }
}

/// **A greeting in front of a salutation hands the name over, and the
/// salutation word is not part of it.**
///
/// Found by measurement the moment the two lists stood beside each other:
/// «Hej Herr Lars Andersson,» offered **«Herr»** as a person, because the walk
/// reaches up to three name-shaped words and nothing had told it that one of
/// them was a form word. A salutation is never part of a name — that is the
/// whole reason the word is in that list — so `name_shaped` refuses it, once,
/// for every rule that asks what a name looks like.
#[test]
fn a_greeting_in_front_of_a_salutation_does_not_make_the_salutation_a_name() {
    let both = found("Hej Herr Lars Andersson,\n\nTack.\n", "sv");
    assert_eq!(
        both.iter().map(|(s, w, _)| (*s, w.clone())).collect::<Vec<_>>(),
        vec![
            (MarkState::Protected, "Lars".to_string()),
            (MarkState::Protected, "Andersson".to_string()),
        ],
        "{both:?}"
    );
    // The salutation is the proof, so it is the salutation that is reported.
    for (_, who, reason) in &both {
        assert!(
            reason.contains("a salutation names the person who follows it"),
            "«{who}»: {reason}"
        );
    }
}

// ------------------------------------------------------------- 2 · the controls

/// **«Hej alla» stays bare** — the control the lead asked for by name.
///
/// And it stays bare by the **word's own case**, not by a list of exceptions:
/// `name_shaped` asks for a capital letter, so every lower-case word that can
/// follow a greeting is answered at once and none of them has to be listed.
#[test]
fn a_greeting_followed_by_no_name_finds_nothing() {
    for bare in [
        "Hej alla,\n\nTack för ert brev.\n",
        "Hej och tack för brevet.\n",
        "Hej igen,\n\nTack.\n",
    ] {
        assert!(
            found(bare, "sv").is_empty(),
            "«{}» named somebody: {:?}",
            bare.lines().next().unwrap_or(""),
            found(bare, "sv")
        );
    }
}

/// **A greeting alone on its line does not name the next line, and a salutation
/// does.**
///
/// Found by measurement the moment the two lists stood beside each other: with
/// the crossing shared, a letter opening «Hej!» and then a paragraph offered
/// **«Tack»** as a person. A salutation alone on its line is an address block;
/// a greeting alone on its line is a letter's first line, and what follows it is
/// a sentence.
#[test]
fn only_a_salutation_alone_on_its_line_reaches_the_next_one() {
    assert!(
        found("Hej!\n\nTack för ditt brev.\n", "sv").is_empty(),
        "{:?}",
        found("Hej!\n\nTack för ditt brev.\n", "sv")
    );
    // The salutation's own case, which is `a_salutation_alone_on_its_line_names_the_next`
    // and is kept here as the control for the line above.
    assert!(
        !found("Herrn\nMarkus Feldmann\n", "de").is_empty(),
        "the salutation stopped crossing its line too"
    );
}

/// **Never protected, however many layers agree.** A greeting's own answer is
/// always an offer; if the name is protected it is because something else
/// proved it, and the state is that other decision's.
#[test]
fn a_greeting_alone_never_protects() {
    for doc in [
        "Hej Yusuf Demir,\n\nTack.\n",
        "Hej Birgitta,\n\nTack.\n",
        "Hi Rachel Thornton,\n\nThanks.\n",
    ] {
        let lang = if doc.starts_with("Hej") { "sv" } else { "en" };
        for (state, who) in by_the_greeting(doc, lang) {
            assert_eq!(state, MarkState::Suggested, "«{who}» was protected by a greeting");
        }
    }
}

// --------------------------------------------- 3 · what it adds, and what it does not

/// **On the owner's own Swedish letter it adds nothing**, and the number is the
/// point: «Katarina Lindqvist» is two names the Swedish dictionary already
/// knows, so the pair rule had it. The greeting agrees with it and says so.
#[test]
fn on_the_swedish_letter_the_greeting_only_re_offers_a_name_the_pair_had() {
    let greeted = by_the_greeting(SWEDISH, "sv");
    assert_eq!(
        greeted.iter().map(|(_, who)| who.clone()).collect::<Vec<_>>(),
        vec!["Katarina".to_string(), "Lindqvist".to_string()],
        "{greeted:?}"
    );
    // And the second layer is named on both of them, which is how a person is
    // told two rules agreed rather than being left to parse one sentence.
    for (_, who, reason) in found(SWEDISH, "sv")
        .into_iter()
        .filter(|(_, _, r)| r.contains("a greeting is often followed by a name"))
    {
        assert!(
            reason.contains("sv:name-dictionary agreed as well"),
            "«{who}» does not say the pair rule agreed: {reason}"
        );
    }
}

/// **And in English it buys what nothing else could.**
///
/// The English pack ships the smallest bank of the three — 149 given names and
/// 150 surnames — so the pair rule covers least there and a form word carries
/// most. Measured: this line found **nothing at all** before the list existed.
#[test]
fn an_english_greeting_finds_a_name_no_list_of_ours_knows() {
    assert_eq!(
        by_the_greeting("Hi Rowan Pellbrook,\n\nThanks for the drawings.\n", "en"),
        vec![
            (MarkState::Suggested, "Rowan".to_string()),
            (MarkState::Suggested, "Pellbrook".to_string()),
        ]
    );
    assert!(
        found("Hello everyone,\n\nThanks.\n", "en").is_empty(),
        "«Hello everyone» named somebody"
    );
}

/// **German: it costs nothing and proves nothing new**, which is also a result.
///
/// Every German document in this tree opens «Sehr geehrte(r)» with a
/// salutation, so the list never fires on one; and on the shape it is for, the
/// German bank of 5,712 given names already offers the pair.
#[test]
fn a_german_greeting_agrees_with_the_pair_rule_rather_than_adding_to_it() {
    let both = found("Hallo Markus Feldmann,\n\nDanke.\n", "de");
    assert_eq!(both.len(), 2, "{both:?}");
    for (state, who, reason) in both {
        assert_eq!(state, MarkState::Suggested, "«{who}» was protected");
        assert!(
            reason.contains("name dictionary") || reason.contains("a greeting is often followed"),
            "«{who}»: {reason}"
        );
    }
    assert!(
        found("Hallo zusammen,\n\nDanke.\n", "de").is_empty(),
        "«Hallo zusammen» named somebody"
    );
}

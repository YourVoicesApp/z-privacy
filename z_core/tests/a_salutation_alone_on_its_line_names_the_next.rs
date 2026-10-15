// **The German address block** — the owner's test of 15 October, and the most
// common shape there is on a letter in that language:
//
// ```text
// Herrn
// Markus Feldmann
// Gartenstraße 17
// 04155 Leipzig
// ```
//
// «Markus» was caught by **nothing**. He had to protect it by hand, and
// «Feldmann» was only hidden because «Sehr geehrter Herr Feldmann» stood
// fourteen lines further down and brought him in.
//
// **Why, and it is not about the line.** Two rules, each correct on its own:
// `dictionary_names` sees a salutation on the word before the pair and
// **yields** — «another rule owns this name and has already protected it» —
// and the salutation rule then stops at the line edge and never takes it. A
// hand-off to a rule that declines, and the name falls into the seam.
//
// So both halves are answered here, and the second one is the lead's ruling of
// the same day: *«its seam must be impossible, not fixed once»*. The salutation
// crosses one break when it stands alone on its line, **and** the pair rule
// stops guessing what another rule will do — `settle` already knows, because it
// folds an overlapping offer into a proven finding and writes «agreed as well».
//
// The controls are in here beside it, because what measures the fix is that
// the shapes which already worked still work and the shape that must stay
// silent stays silent.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const FELDMANN: &str = include_str!("fixtures/Mahnung_Feldmann.txt");

fn people(doc: &str) -> Vec<(MarkState, String, String)> {
    let s = open_session(None, "de".to_string()).expect("open");
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

fn names(doc: &str) -> Vec<String> {
    people(doc).into_iter().map(|(_, text, _)| text).collect()
}

// ------------------------------------------------------ 1 · the owner's block

/// **A salutation standing alone on its line names the next line.**
#[test]
fn the_address_block_of_a_german_letter_names_the_person_in_it() {
    let block = "Herrn\nMarkus Feldmann\nGartenstraße 17\n04155 Leipzig\n";
    assert_eq!(
        people(block).iter().map(|(s, t, _)| (*s, t.clone())).collect::<Vec<_>>(),
        vec![
            (MarkState::Protected, "Markus".to_string()),
            (MarkState::Protected, "Feldmann".to_string()),
        ],
        "{:?}",
        people(block)
    );
    // And it is the salutation that says so, in the pack's own words.
    for (_, _, reason) in people(block) {
        assert!(
            reason.contains("a salutation names the person who follows it"),
            "{reason}"
        );
    }
}

/// **And in his whole letter**, where «Markus» was in the clear until today.
#[test]
fn markus_is_no_longer_left_in_the_clear_in_the_owners_letter() {
    let found = names(FELDMANN);
    for who in ["Markus", "Feldmann", "Katrin", "Sommer"] {
        assert!(found.iter().any(|n| n == who), "«{who}» is not found: {found:?}");
    }
    // The letter's three people, by word, and no place twice over.
    assert!(
        people(FELDMANN).iter().all(|(state, _, _)| *state == MarkState::Protected),
        "a name in this letter is still only offered: {:?}",
        people(FELDMANN)
    );
}

// ----------------------------------------------------------- 2 · the controls

/// **The shapes that already worked, and still do.**
///
/// Measured before anything was changed, and this is the whole of why the cause
/// was findable: the pair rule was not silent about a line holding two names —
/// it was silent about a **salutation on the line above**.
#[test]
fn the_shapes_that_worked_before_work_now() {
    // An ordinary word above the pair: the dictionary offers it, as it did.
    let hallo = people("Hallo\nMarkus Feldmann\nTschüss\n");
    assert_eq!(
        hallo.iter().map(|(s, t, _)| (*s, t.clone())).collect::<Vec<_>>(),
        vec![
            (MarkState::Suggested, "Markus".to_string()),
            (MarkState::Suggested, "Feldmann".to_string()),
        ],
        "{hallo:?}"
    );

    // A preposition above it — the shape of an address block that writes «An»
    // instead of a salutation. Offered, never protected: nothing here proves a
    // person.
    let an = people("An\nMarkus Feldmann\n");
    assert_eq!(
        an.iter().map(|(s, t, _)| (*s, t.clone())).collect::<Vec<_>>(),
        vec![
            (MarkState::Suggested, "Markus".to_string()),
            (MarkState::Suggested, "Feldmann".to_string()),
        ],
        "{an:?}"
    );

    // And the salutation on the same line, which was never the broken case.
    assert_eq!(
        names("Herrn Markus Feldmann\n"),
        vec!["Markus".to_string(), "Feldmann".to_string()]
    );
}

/// **A salutation that merely ends its line is not this rule** — the sibling
/// measured and not taken.
///
/// «An Herrn⏎Markus Feldmann» and «Sehr geehrter Herr⏎Feldmann,» are the same
/// shape one step wider: a salutation as the **last** word of a line. The
/// lead's ruling says «standing alone on its line», and a rule that is wider
/// than its ruling is a rule nobody measured. So this holds today's answer, and
/// reddens the day the ruling grows — which is how it should be found.
#[test]
fn a_salutation_that_only_ends_its_line_still_takes_nothing() {
    assert!(
        names("Sehr geehrter Herr\nFeldmann,\n").is_empty(),
        "{:?}",
        names("Sehr geehrter Herr\nFeldmann,\n")
    );
    // «An Herrn» is the other half of it, and the pair rule still offers the
    // name there — so nothing is lost by the narrow reading, only proven less.
    let an_herrn = people("An Herrn\nMarkus Feldmann\n");
    assert!(
        an_herrn.iter().all(|(state, _, _)| *state == MarkState::Suggested),
        "a salutation ending a line proved a person: {an_herrn:?}"
    );
}

/// **A title on the next line is crossed too**, because the chain already
/// allowed one break and nothing here narrows it.
#[test]
fn a_title_after_a_salutation_alone_on_its_line_is_stepped_over() {
    assert_eq!(
        names("Herrn\nDr. Markus Feldmann\n"),
        vec!["Markus".to_string(), "Feldmann".to_string()]
    );
}

// -------------------------------------------------- 3 · the seam, made impossible

/// **The pair rule no longer guesses what another rule will do.**
///
/// `settle` is where «two layers saw the same thing» is answered, and it
/// answers it better than a guess can: it keeps the proven finding, folds the
/// offer into it and says «agreed as well» — which is an answer a person is
/// owed. The guess that stood in `dictionary_names` could only ever be right
/// about rules it could not see.
#[test]
fn two_layers_on_one_name_are_one_finding_and_both_are_named() {
    let found = people("Sehr geehrter Herr Markus Feldmann, danke.");
    assert_eq!(found.len(), 2, "one finding per word, and not two per word: {found:?}");
    for (state, _, reason) in &found {
        assert_eq!(*state, MarkState::Protected);
        assert!(
            reason.contains("a salutation names the person who follows it"),
            "the proven rule is not the one that won: {reason}"
        );
        assert!(
            reason.contains("de:name-dictionary agreed as well"),
            "the second layer is not named, so a person cannot be told two rules agreed: {reason}"
        );
    }
}

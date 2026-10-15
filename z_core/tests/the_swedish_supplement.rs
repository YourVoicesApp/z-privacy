// SV-16 · the Swedish supplement, ten pages of a research magazine.
//
// The owner's own file, and the first Swedish document with a guard of its own.
// It is his, and five megabytes of it, so it does not live in the repository:
// when it is absent this test says so and stops, and `scripts/gates.sh` prints
// that as a skip and never as a pass — the same contract as the German goldens.
//
// **Why it needed a guard on 7 October.** 038-B/2 was measured here, and the
// numbers moved by name, not only by count:
//
// ```text
//                 before   after
// auto                 3      13
// suggested           28      27
// people found        27      36
// ```
//
// Ten of those became protected without being asked — five photographers who
// had been in the clear («Gonzalo Irigoyen» twice, «Anja Callius», «Jenny
// Widén», «Johan Lindvall»), and five who had only been *offered* before and
// are now proof because the credit label names them («Erik Cronberg», «Jesper
// Berg», «Magnus Bergström», «Mikael Wallerstedt» twice). Four more are offered
// for a word, each beside what the person does: «Cicek Cavdar», «Eva Schelin»,
// «Lars Hultman», «Sven Nelander».
//
// Nothing was lost, and no German number moved.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

fn document() -> Option<std::path::PathBuf> {
    let path = match std::env::var("ZPRIVACY_SWEDISH_SUPPLEMENT") {
        Ok(name) => std::path::PathBuf::from(name),
        Err(_) => std::path::PathBuf::from(std::env::var("HOME").ok()?)
            .join("Documents/framtidens-forskning-p1-10.pdf"),
    };
    path.is_file().then_some(path)
}

#[test]
fn the_credits_are_protected_and_the_captions_are_not() {
    let Some(path) = document() else {
        println!("the Swedish supplement is not on this machine — nothing was measured");
        return;
    };
    let dir = std::env::temp_dir().join(format!("zprivacy-sv16-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");

    let bytes = std::fs::read(&path).expect("the document");
    let s = open_session(None, "sv".to_string()).expect("open");
    let view = import_document(s, "sv16.pdf".to_string(), bytes, DocumentKind::Pdf)
        .expect("ten pages of a magazine are readable");
    assert_eq!(view.pages, 10);
    assert_eq!(
        view.text.chars().count(),
        // 50_125 since «a line is a y» (15 October): 30 characters more, where
        // the reader was cutting a line at a text-object boundary.
        50_125,
        "the reader gives a different text than the one these numbers were measured on"
    );

    let report = scan(s).expect("scan");
    assert_eq!(
        (report.auto, report.suggested),
        // **(27, 51) since 085 ruling 1** (15 October), from (13, 27): a name
        // the app read for itself is one finding per word, and this supplement
        // is a magazine full of credits and bylines. What 038-B/2 measured is
        // unchanged in substance — the credits are protected and the captions
        // are not — and it is the same people, counted by word.
        (27, 51),
        "038-B/2 measured 13 and 27 here, from 3 and 28: {report:?}"
    );

    let mut people: Vec<(MarkState, String)> = list_findings(s)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == Kind::Person)
        .map(|f| {
            (
                f.state,
                view.text
                    .chars()
                    .skip(f.span.start as usize)
                    .take((f.span.end - f.span.start) as usize)
                    .collect::<String>(),
            )
        })
        .collect();
    // `MarkState` is not ordered, so sort by what a person reads.
    people.sort_by(|a, b| a.1.cmp(&b.1));
    // 74 since 085 ruling 1 (15 October), from 36: the same people, one
    // finding per word of each name.
    assert_eq!(people.len(), 74, "27 people were found before 038-B/2, 36 after, 74 by word");

    // The three the owner's own reading found in the clear.
    for who in ["Gonzalo", "Irigoyen", "Anja", "Callius"] {
        assert!(
            people.iter().any(|(state, text)| *state == MarkState::Protected && text == who),
            "«{who}» is credited beside a picture and is not protected"
        );
    }
    assert!(
        people
            .iter()
            .any(|(state, text)| *state == MarkState::Suggested && text.contains("Cavdar")),
        "«Projektledare är Cicek Cavdar» is not even offered"
    );

    // And the rule that pays for Auto: no caption became a person.
    //
    // **Said by shape and not by word count since 085 ruling 1** (15 October).
    // Until then every Person here was two words, and «two words or more» was
    // the cheapest way to say «a rule saw evidence and not one capitalised
    // word». Now every one of them is one word by law, so the count says
    // nothing and the shape has to say it instead: a name is at least two
    // letters, and it carries no digit and no bracket. That is the clause the
    // owner's ICD-10 catalogue bought — 28,853 chapter letters protected as
    // people — and it is the one this file was really leaning on.
    for (_, text) in &people {
        assert!(
            text.chars().count() >= 2
                && !text.chars().any(|c| c.is_ascii_digit() || c == '(' || c == ')'),
            "a single letter or a code was taken as a person: {text:?}"
        );
    }
    close_session(s).ok();
    let _ = std::fs::remove_dir_all(&dir);
}

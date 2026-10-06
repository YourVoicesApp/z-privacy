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
        50_095,
        "the reader gives a different text than the one these numbers were measured on"
    );

    let report = scan(s).expect("scan");
    assert_eq!(
        (report.auto, report.suggested),
        (13, 27),
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
    assert_eq!(people.len(), 36, "27 people were found before 038-B/2, 36 after");

    // The three the owner's own reading found in the clear.
    for who in ["Gonzalo Irigoyen", "Anja Callius"] {
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
    for (_, text) in &people {
        assert!(
            text.split_whitespace().count() >= 2 || text.contains('\n'),
            "a single word was taken as a person: {text:?}"
        );
    }
    close_session(s).ok();
    let _ = std::fs::remove_dir_all(&dir);
}

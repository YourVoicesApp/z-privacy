// The third golden: 734 pages of Austrian medical German.
//
// The first golden is a letter we wrote, full of values. The second is a public
// book, where almost nothing is anybody's. This one is the case between them —
// a government document that is mostly code tables, with one page in the middle
// that names two dozen doctors. It holds both halves of the promise at once:
// the people on that page are protected without being asked, and the hundred
// thousand ICD-10 codes around them are left alone.
//
// It caught both failures of 3 October. Before the titles were understood, the
// only person protected on the team page was the word «Mag» — the title, while
// «Gudrun Spitzwieser» stayed in the clear — and four ICD codes were protected
// as people («bei der Frau (N95.1)»). After the titles were understood but
// before a name had to be two letters long, the chapter letters G, K, N, P and
// W were protected 28,853 times and the payload's own audit refused to build.
//
// The file is the owner's and five megabytes of it, so it does not live in the
// repository. When it is absent this test says so and stops; `scripts/gates.sh`
// prints that as a skip, never as a pass.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::collections::BTreeMap;
use std::path::PathBuf;

use z_core::api::*;

fn document() -> Option<PathBuf> {
    let path = match std::env::var("ZPRIVACY_THIRD_GOLDEN") {
        Ok(name) => PathBuf::from(name),
        Err(_) => PathBuf::from(std::env::var("HOME").ok()?).join("Downloads/tysk1.pdf"),
    };
    path.is_file().then_some(path)
}

#[test]
fn the_team_page_is_protected_and_the_code_tables_are_not() {
    let Some(path) = document() else {
        println!("the third golden is not on this machine — nothing was measured");
        return;
    };
    let bytes = std::fs::read(&path).expect("the document");
    let session = open_session(None, "de".to_string()).expect("open");
    let view = import_document(session, "tysk1.pdf".to_string(), bytes, DocumentKind::Pdf)
        .expect("734 pages of a Word export are readable");
    assert_eq!(view.pages, 734);
    assert!(
        view.text.chars().count() > 1_500_000,
        "only {} characters came out of it",
        view.text.chars().count()
    );

    let report = scan(session).expect("scan");
    assert_eq!(
        (report.auto, report.suggested),
        (18, 2),
        "the people on the team page, the company and the person offered for a word: {report:?}"
    );
    // 038-H moved the second number, and upwards: «Gregor Keller» is on the
    // team page and was in the clear until the name bank carried both halves
    // of him. One more real person offered, no false protection anywhere on
    // 734 pages, and the code tables and chapter letters are still untouched —
    // which the rest of this test checks line by line.

    let units: Vec<u16> = view.text.encode_utf16().collect();
    let findings = list_findings(session).expect("findings");
    let mut shape: BTreeMap<String, usize> = BTreeMap::new();
    for finding in &findings {
        *shape.entry(format!("{:?} {:?}", finding.state, finding.kind)).or_default() += 1;
    }

    for finding in &findings {
        let text = String::from_utf16_lossy(
            units.get(finding.span.start as usize..finding.span.end as usize).unwrap_or_default(),
        );
        // Not an ICD-10 code, and not a chapter letter: a name is at least two
        // letters, and it carries no digit and no bracket.
        if finding.kind == Kind::Person {
            assert!(
                text.chars().count() >= 2
                    && !text.chars().any(|c| c.is_ascii_digit() || c == '(' || c == ')'),
                "«{text}» is not a person's name"
            );
        }
    }
    assert_eq!(
        shape.iter().map(|(k, n)| format!("{k} ×{n}")).collect::<Vec<_>>(),
        [
            "Protected Email ×1",
            "Protected Person ×16",
            "Protected Phone ×1",
            "Suggested Company ×1",
            // 038-H: «Gregor Keller», offered and not protected — a dictionary
            // hit is a signal, never a verdict, on 734 pages as anywhere else.
            "Suggested Person ×1",
        ],
        "the shape of what it found has changed"
    );

    // And the payload builds. It did not when 28,853 single letters were
    // protected — the audit refused it, which is the invariant doing its work,
    // and a document a person cannot send is a document they cannot use.
    let handle = build_payload(session).expect("the payload builds");
    let safe = payload_view(handle).expect("view").text;
    assert_eq!(safe.matches("__Z_").count(), 20, "one token per place, and no more");
    for name in ["Gudrun Spitzwieser", "Ludwig Neuner", "Florian Röthlin", "Gerhard Renner"] {
        assert!(!safe.contains(name), "«{name}» is still in the clear");
    }
    // The code tables are untouched: this is a reference work, and a reader of
    // the safe text must still be able to use it.
    for code in ["N95.1", "N81.0", "Q64.7", "L90.1"] {
        assert!(safe.contains(code), "the code «{code}» was taken out of a code table");
    }
}

// The report a person copies when something is wrong.
//
// Its whole promise is negative: a tester in another country can send us this
// instead of the document, and it must be safe to paste into an e-mail, an
// issue, a chat. So the test is written the same way — not «does it contain the
// numbers» alone, but «does it contain nothing else».
//
// The letter is the right file to hold it to: it is nothing but values. Seven
// people, a date of birth, an identity card, a plate, a tax number, a customer
// number, three addresses, two companies, an invoice number. If a report can
// leak, it leaks here.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use z_core::api::*;

fn letter() -> Vec<u8> {
    std::fs::read(concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/Brief_Weber.txt")).expect("the letter")
}

// ---------------------------------------------------------------- the grammar
//
// **Why the report is read line by line instead of searched as one blob.**
//
// 9 October 2026, the closing measurement of 074: this test failed on commit
// `6c83089`. The report's build line read `z_core 0.1.0 · 2026-10-09 · 6c83089`,
// and `089` is a word of a Munich telephone number the scanner finds in the
// letter — so «is a value's word in the report?» answered yes, about seven
// hexadecimal characters that were minted before the document existed. It had
// been green the commit before because that hash happened not to collide: the
// green was the luck of a fingerprint, not a proof about a report.
//
// The product was honest. The *test's* claim was too wide — its search space
// included lines nobody could leak into. And the same lottery sits in every
// other column we write: `words 227` collides with a three-character value word
// «227», `characters 1627` with «162». Fencing the build line alone would have
// killed tonight's draw and left the family.
//
// So every line is classified, and nothing is left over:
//
//   * **Fenced** — ours, pinned to its exact shape. A leaked value cannot live
//     here, because it breaks the shape: `file` must be a dotted extension,
//     `size` digits and `KiB`, a count must be digits, the stamp must be
//     `z_core <semver> · <date> · <7 hex>` and nothing else.
//   * **Free** — a value we did not write, like a refusal's own words, which
//     name a font or a filter. The paranoid substring search lives here, where
//     a leak could actually hide.
//   * **Unknown** — a failure. A line added to the report must be classified
//     before this test passes again, which is the point: the grammar is total.
//
// The enum words are taken from the product rather than a list kept by hand —
// the document's kind as it was imported, and the finding kinds the scanner
// itself reported. A hand-list would rot, and a shape like «a capitalised word»
// would let «Weber ×1» pass for a kind.
#[derive(Debug, PartialEq)]
enum Shape {
    /// The title, exactly as written.
    Title,
    /// Ours, and proven to be nothing else.
    Fenced,
    /// Not ours: searched, word by word.
    Free(String),
    /// Fits no class. The test fails on it.
    Unknown,
}

fn digits(s: &str) -> bool {
    !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit())
}

/// `z_core 0.1.0 · 2026-10-09 · 9dc8fc8` — three fields, each pinned, and no
/// fourth. Written with iterators rather than indexes: `clippy::indexing_slicing`
/// is denied across this workspace, and a guard that can panic while proving a
/// report cannot leak is a poor sort of guard.
fn stamp_is_only_a_stamp(value: &str) -> bool {
    let mut fields = value.split(" · ");
    let (Some(name), Some(date), Some(commit), None) =
        (fields.next(), fields.next(), fields.next(), fields.next())
    else {
        return false;
    };
    let Some(version) = name.strip_prefix("z_core ") else {
        return false;
    };
    let semver = version.split('.').count() == 3 && version.split('.').all(digits);
    let mut ymd = date.split('-');
    let day = match (ymd.next(), ymd.next(), ymd.next(), ymd.next()) {
        (Some(y), Some(m), Some(d), None) => {
            y.len() == 4 && m.len() == 2 && d.len() == 2 && digits(y) && digits(m) && digits(d)
        }
        _ => false,
    };
    let seven =
        commit.len() == 7 && commit.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase());
    semver && day && seven
}

/// `.txt` — a dot and a short lower-case extension, never a name.
fn only_an_extension(value: &str) -> bool {
    match value.strip_prefix('.') {
        Some(ext) => {
            !ext.is_empty()
                && ext.len() <= 8
                && ext.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
        }
        None => false,
    }
}

/// `21   (Person ×8, Phone ×3)` — a count, then kinds the scanner itself named.
fn count_and_known_kinds(value: &str, kinds: &[String]) -> bool {
    let Some((count, rest)) = value.split_once('(') else {
        return digits(value.trim());
    };
    let Some(inside) = rest.trim_end().strip_suffix(')') else {
        return false;
    };
    digits(count.trim())
        && inside.split(", ").all(|item| match item.split_once(" ×") {
            Some((kind, n)) => kinds.iter().any(|k| k == kind) && digits(n),
            None => false,
        })
}

/// Which class a line of the report belongs to. `doc_kind` is the kind as it was
/// imported and `kinds` the finding kinds the scanner reported — both read off
/// the product, so neither can be a word of anybody's document.
fn shape_of(line: &str, doc_kind: Option<&str>, kinds: &[String]) -> Shape {
    if line == "Z Privacy — document report" {
        return Shape::Title;
    }
    if line.chars().count() < 12 {
        return Shape::Unknown;
    }
    // The label column is `{:<12}`, so the value begins at the twelfth char.
    let label: String = line.chars().take(12).collect();
    let value: String = line.chars().skip(12).collect();
    let value = value.trim_end();
    let fenced = match label.trim() {
        "build" => stamp_is_only_a_stamp(value),
        "file" => only_an_extension(value),
        "size" => value.strip_suffix(" KiB").is_some_and(digits),
        "kind" => doc_kind == Some(value),
        "pages" | "words" | "characters" | "tokens" => digits(value),
        "readable" => value.strip_suffix('%').is_some_and(digits),
        "protected" | "waiting" => count_and_known_kinds(value, kinds),
        // A refusal says what the file is, in its own words: a font, a filter,
        // a page number. Not ours, so it is searched rather than fenced.
        "refused" => return Shape::Free(value.to_string()),
        _ => return Shape::Unknown,
    };
    if fenced {
        Shape::Fenced
    } else {
        Shape::Unknown
    }
}

/// Everything in the report that is not pinned by its shape, which is what the
/// word search below is allowed to be about. A line that fits no class panics
/// here rather than being quietly searched or quietly skipped.
fn free_text(text: &str, doc_kind: Option<&str>, kinds: &[String]) -> String {
    let mut free = String::new();
    for line in text.lines() {
        match shape_of(line, doc_kind, kinds) {
            Shape::Title | Shape::Fenced => {}
            Shape::Free(value) => {
                free.push_str(&value);
                free.push('\n');
            }
            Shape::Unknown => panic!(
                "a line of the report fits no class, so nothing proves what is in it: «{line}»"
            ),
        }
    }
    free
}

#[test]
fn the_report_carries_the_numbers_and_none_of_the_words() {
    let session = open_session(None, "de".to_string()).expect("open");
    import_document(session, "/home/anas/Dokumente/Brief_Weber.txt".to_string(), letter(), DocumentKind::Txt)
        .expect("import");
    let report = scan(session).expect("scan");
    let text = import_report(ReportSubject::Imported { session }).expect("report");

    // The numbers are there, and they are the core's own.
    // The extension and not the name: a file name carries the client's.
    assert!(text.contains("file        .txt"), "{text}");
    assert!(!text.contains("Brief_Weber"), "the report is named after the person: {text}");
    assert!(text.contains(&format!("protected   {:<5}", report.auto)), "{text}");
    assert!(text.contains(&format!("waiting     {:<5}", report.suggested)), "{text}");
    assert!(text.contains("readable    100%"), "{text}");
    assert!(text.contains("Person ×"), "the kinds are counted by name: {text}");

    // And the path it was opened from is not, because that says which folders a
    // person keeps their work in.
    assert!(!text.contains("Dokumente"), "the report carries the path: {text}");

    // Now the promise, in two halves. First the grammar: every line is ours and
    // pinned to its shape, or not ours and handed to the search below. A line
    // that fits neither fails inside `free_text`.
    let units: Vec<u16> = document_view(session).expect("view").text.encode_utf16().collect();
    let findings = list_findings(session).expect("findings");
    assert!(findings.len() >= 20, "the letter should be full of them: {}", findings.len());
    let kinds: Vec<String> = findings.iter().map(|f| format!("{:?}", f.kind)).collect();
    let free = free_text(&text, Some("Txt"), &kinds);

    // For an imported document there is nothing left over, and **that is the
    // proof**: a value of the person's cannot sit in a line whose shape it would
    // break. The loop below therefore has nothing to chew on here — it stays
    // because the refused report does carry free text, and because the day
    // somebody adds a free-text line to this report, it starts applying to it.
    assert!(
        free.is_empty(),
        "a report about an imported document should be nothing but ours: «{free}»"
    );
    for finding in &findings {
        let value = String::from_utf16_lossy(
            units.get(finding.span.start as usize..finding.span.end as usize).unwrap_or_default(),
        );
        for word in value.split_whitespace().filter(|w| w.chars().count() > 2) {
            assert!(
                !free.contains(word),
                "«{word}» is in the part of the report we did not write ({:?})",
                finding.kind
            );
        }
    }
    // Said once by name as well, because this is the one it was written for.
    assert!(!text.contains("Weber"), "the report names the person: {text}");
}

#[test]
fn a_refused_file_still_has_a_report() {
    // No session, because nothing was imported: a refusal is exactly the moment
    // a person needs something to send.
    let text = import_report(ReportSubject::Refused {
        name: "C:\\Users\\Jonas\\Desktop\\Rechnung.pdf".to_string(),
        bytes: 5_109_029,
        refusal: Refusal::UnsupportedEncoding { page: 14, readable_percent: 41 },
    })
    .expect("a report about a file we would not read");

    assert!(text.contains("file        .pdf"), "{text}");
    assert!(
        !text.contains("Jonas") && !text.contains("Desktop") && !text.contains("Rechnung"),
        "the Windows path or the file's name is in it: {text}"
    );
    assert!(text.contains("4989 KiB"), "{text}");
    assert!(text.contains("UnsupportedEncoding"), "the refusal is named: {text}");
    assert!(text.contains("page: 14") && text.contains("41"), "with its own numbers: {text}");
    assert!(text.contains("z_core"), "and the build that refused it: {text}");
    // The stamp, whole: a report from a tester in another country is worth
    // having only if it can be put back to the build that wrote it.
    assert!(
        text.contains(&z_core::core_version()),
        "the report does not name its own build: {text}"
    );
    let stamp = text.lines().find(|l| l.starts_with("build")).unwrap_or_default();
    assert_eq!(stamp.split(" · ").count(), 3, "version, date, commit: «{stamp}»");

    // And the same grammar. Here there is free text — the refusal's own words,
    // which name a filter and a page — and it is the one place in either report
    // that the word search is about.
    let free = free_text(&text, None, &[]);
    assert!(
        free.contains("UnsupportedEncoding"),
        "the refusal's own words are the free part of a refused report: «{free}»"
    );
    for word in ["Jonas", "Desktop", "Rechnung"] {
        assert!(!free.contains(word), "«{word}» reached the free text: «{free}»");
    }
}

/// **Each fence, broken once on purpose.** A classifier nobody has watched fail
/// is a classifier that might be returning `Fenced` for everything — the same
/// finding as a guard that fires on healthy code, wearing the other glove. So
/// every class is handed a line with a value planted in it, the way a leak would
/// look, and must refuse to call it ours.
#[test]
fn each_fence_falls_when_a_value_is_planted_in_it() {
    let kinds = vec!["Person".to_string(), "Phone".to_string()];
    let doc = Some("Txt");

    // The real lines, as the product prints them, are ours.
    for line in [
        "Z Privacy — document report",
        "build       z_core 0.1.0 · 2026-10-09 · 9dc8fc8",
        "file        .txt",
        "size        4989 KiB",
        "kind        Txt",
        "pages       1",
        "words       227",
        "characters  1627",
        "readable    100%",
        "protected   21   (Person ×8, Phone ×3)",
        "tokens      22",
        // The draw that failed on 9 October, named: this exact stamp is ours.
        "build       z_core 0.1.0 · 2026-10-09 · 6c83089",
    ] {
        let shape = shape_of(line, doc, &kinds);
        assert!(
            shape == Shape::Fenced || shape == Shape::Title,
            "the grammar does not recognise a line the product really prints: «{line}» gave {shape:?}"
        );
    }

    // And a value planted in each fenced column breaks its shape. Every one of
    // these is a line the product cannot produce — which is the point.
    for (line, what) in [
        ("build       z_core 0.1.0 · 2026-10-09 · Weber12", "a commit that is not hexadecimal"),
        ("build       Weber", "a stamp with no fields"),
        ("build       z_core 0.1.0 · 2026-10-09 · 9dc8fc8 Weber", "a stamp with something after it"),
        ("file        .Brief_Weber", "a name where the extension goes"),
        ("file        Brief_Weber.txt", "a whole file name"),
        ("size        Weber KiB", "a word where the kilobytes go"),
        ("kind        Weber", "a word that is not the kind that was imported"),
        ("pages       1 Weber", "a count with a word beside it"),
        ("words       227Weber", "a count with a word glued to it"),
        ("readable    Weber%", "a word where the percentage goes"),
        ("protected   21   (Weber ×1)", "a word standing in for a kind"),
        ("protected   Weber   (Person ×8)", "a word where the count goes"),
        ("tokens      Weber", "a word where the token count goes"),
        ("signature   Markus Weber", "a line nobody classified"),
    ] {
        assert_eq!(
            shape_of(line, doc, &kinds),
            Shape::Unknown,
            "the grammar called this ours, and it is {what}: «{line}»"
        );
    }

    // **The regression itself, not a paraphrase of it.** A report whose stamp
    // carries `6c83089` has no free text at all, so «089» — a word of a Munich
    // telephone number in the letter — cannot be found in it however hard the
    // search looks. The second assertion is the control string: a fixture that
    // does not actually carry the digits would make the first one prove nothing.
    let drawn = "Z Privacy — document report\n\
                 build       z_core 0.1.0 · 2026-10-09 · 6c83089\n\
                 file        .txt\n\
                 words       227\n";
    assert!(drawn.contains("089"), "the control itself must carry the collision");
    assert!(
        free_text(drawn, doc, &kinds).is_empty(),
        "the stamp's own hexadecimal is being offered to the word search again"
    );
}

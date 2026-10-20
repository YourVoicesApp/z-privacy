// **A name is read the way a person reads it** — 095, خ3, from the outside
// model's attack on `2b4fad9` (19 October 2026, graded SERIOUS).
//
// Its probes, byte for byte, with the answers it got:
//
// ```text
//   Sehr geehrter Herr Mar<U+200B>kus Weber,      → nothing found
//   Sehr geehrter Herr Markus<U+200D>Weber,       → nothing found
//   Kontakt: Thomas<U+200C>Müller unterschreibt.  → nothing found
//   Sehr geehrter Herr Thomas Mu<U+0308>ller,     → Thomas only
//   Sehr geehrter Herr Thomas Müller,  (NFC)      → Thomas and Müller
// ```
//
// **The cause, in one line of this house's own code:** `name_shaped` in
// `scanner/packs/people.rs` asks `char::is_alphabetic` of every character of
// the word. A combining diaeresis (U+0308) is not alphabetic, and neither is a
// zero-width space — so a name with an invisible character in it, or spelled in
// NFD, is not shaped like a name at all and every rule that asks that question
// walks past it. One function, five callers, four rules blinded at once.
//
// **Why it matters more than it looks.** G3 holds that NFC and NFD are one
// value — the leak audit folds both before it counts — so the product already
// says these two spellings are the same word. The scanner said they were not.
// And a zero-width space is not an exotic attack: Word writes them, PDF
// extraction leaves them, and a copy from a web page carries them.
//
// **What this fixes and what it deliberately does not.** The shape test reads
// the word as a person reads it: NFC-folded **for the test only**, with
// `Cf` format characters skipped. The span it reports stays the original's,
// byte for byte, so the token replaces exactly what stood in the document and
// the document reads as it read («protection may not change how a document
// reads»). Never NFKC: that one adds a space to Arabic mark forms
// (`nfkc_inserts_a_space_on_arabic_mark_forms`) and would cut words in two —
// which is why the ligature `ﬁscher` of the model's last probe is **still**
// missed, and the last test here measures that limit rather than hoping about
// it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// The findings over one text, as (state, kind, the exact characters the span
/// covers) — the span read back out of the **original** string, which is how
/// this file measures that a span still names what stood there.
fn found(doc: &str, pack: &str) -> Vec<(MarkState, Kind, String)> {
    let s = open_session(None, pack.to_string()).expect("open");
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
            (f.state, f.kind, text)
        })
        .collect();
    close_session(s).ok();
    out
}

fn people(doc: &str, pack: &str) -> Vec<(MarkState, String)> {
    found(doc, pack)
        .into_iter()
        .filter(|(_, kind, _)| *kind == Kind::Person)
        .map(|(state, _, text)| (state, text))
        .collect()
}

/// The control every probe below is measured against: the same letter with
/// nothing hidden in it. If this one ever changes, nothing else in this file
/// means what it says.
const NFC: &str = "Sehr geehrter Herr Thomas Müller,\n";

// ------------------------------------------------------------ 1 · the control

#[test]
fn the_plain_letter_is_the_measure_of_the_rest() {
    assert_eq!(
        people(NFC, "de"),
        vec![
            (MarkState::Protected, "Thomas".to_string()),
            (MarkState::Protected, "Müller".to_string()),
        ],
        "the control itself moved, so no probe in this file measures anything"
    );
}

// --------------------------------------------- 2 · a character nobody can see

/// **A zero-width space inside a given name.** The model's first probe.
#[test]
fn a_zero_width_space_inside_a_name_does_not_hide_it() {
    let doc = "Sehr geehrter Herr Mar\u{200B}kus Weber,\n";
    let names = people(doc, "de");
    assert_eq!(
        names.len(),
        2,
        "the salutation found {} names where the plain letter finds two: {names:?}",
        names.len()
    );
    // **And the span is the original's, byte for byte.** The character is still
    // in the document; what the token replaces is exactly the stretch that
    // stood there, invisible character and all, or the line a person reads
    // would come back shorter than they wrote it.
    assert!(
        names.iter().any(|(_, text)| text.contains('\u{200B}')),
        "the span dropped the invisible character instead of covering it: {names:?}"
    );
}

/// **A soft hyphen, which is what a word processor leaves behind at a line
/// break it later un-breaks.**
#[test]
fn a_soft_hyphen_inside_a_name_does_not_hide_it() {
    let doc = "Sehr geehrter Herr Mar\u{00AD}kus Weber,\n";
    assert_eq!(
        people(doc, "de").len(),
        2,
        "a soft hyphen hid a name the plain letter protects: {:?}",
        people(doc, "de")
    );
}

/// **A zero-width joiner between two names.** Said out loud because the answer
/// is not «two names»: with the invisible character skipped the two words are
/// one word to any reader, and that is what gets protected — one token over
/// the whole stretch, which hides both names and no more.
#[test]
fn a_zero_width_joiner_between_two_names_hides_neither() {
    let doc = "Sehr geehrter Herr Markus\u{200D}Weber,\n";
    let names = people(doc, "de");
    assert!(!names.is_empty(), "nothing at all was found: {names:?}");
    let covered: String = names.iter().map(|(_, text)| text.clone()).collect();
    assert!(
        covered.contains("Markus") && covered.contains("Weber"),
        "a name is left in the clear on either side of the joiner: {names:?}"
    );
}

// ------------------------------------------------- 3 · one value, two foldings

/// **NFD is the same value as NFC** — G3's own law, now true in the scanner too.
#[test]
fn a_name_spelled_in_nfd_is_the_name() {
    let doc = "Sehr geehrter Herr Thomas Mu\u{0308}ller,\n";
    let names = people(doc, "de");
    assert_eq!(
        names.len(),
        2,
        "NFD found {} of the two names the same letter in NFC protects: {names:?}",
        names.len()
    );
    assert!(
        names.iter().any(|(_, text)| text.contains('\u{0308}')),
        "the span cut the combining mark off the name it covers: {names:?}"
    );
}

// --------------------------------------------------------- 4 · and the limits

/// **A word of nothing but invisible characters is not a name.** The cheapest
/// way to turn a shape test into a machine that protects punctuation is to let
/// an empty reading count as two letters.
#[test]
fn a_word_of_invisible_characters_is_not_a_name() {
    let doc = "Sehr geehrter Herr \u{200B}\u{200C}\u{200D} Weber,\n";
    let names = people(doc, "de");
    assert!(
        !names.iter().any(|(_, text)| text.trim().chars().all(|c| c == '\u{200B}' || c == '\u{200C}' || c == '\u{200D}')),
        "a stretch of invisible characters was taken for a name: {names:?}"
    );
}

/// **The limit, measured rather than promised: a typographic ligature is still
/// missed.** `ﬁscher` folds to `fischer` only under NFKC, and NFKC is forbidden
/// in this house — it adds a space to the Arabic mark forms and cuts words in
/// two. So this stays a known miss, written here so that nobody reads خ3's fix
/// as «every spelling now».
#[test]
fn a_ligature_is_still_missed_and_that_is_written_down() {
    let doc = "Dear Mr Thomas \u{FB01}scher,\n";
    let names = people(doc, "en");
    assert!(
        !names.iter().any(|(_, text)| text.contains('\u{FB01}')),
        "the ligature is protected now — good news, and this test is the one to \
         rewrite, with NFKC's own limit measured: {names:?}"
    );
}

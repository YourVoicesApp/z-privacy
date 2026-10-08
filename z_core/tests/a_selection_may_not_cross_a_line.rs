// 053 · A selection may not cross a line.
//
// The owner, from a live run on his own Swedish payroll file, looking at his
// screen: «here is our selection problem — if there is no dot or anything it
// takes the space, and then the same value becomes hard to find anywhere
// else.»
//
// He is right, and it is worse than he said. `whole_words` grows each edge of a
// hand-drawn selection outward while it stands in the middle of a word, and
// nothing ever asked which line that word was on. Two characters past
// «559000-0000» the growth walked into the *next* line and took the whole of
// «Adress» with it. Measured on 82d5858, through the same door the bubble uses:
//
//     end   +0  →  "559000-0000"
//     end   +1  →  "559000-0000"              the newline alone is tidied away
//     end   +2  →  "559000-0000\nAdress"      and here it stops being a value
//     start -0  →  "Adress"
//     start -2  →  "559000-0000\nAdress"      the same, mirrored
//
// Three harms, and the second is the one that reaches the model: two lines of
// the owner's document became one and the word «Adress» left his machine
// missing from a table a model was asked to reconcile. That is the rule adopted
// 7 October — **protection may not change how a document reads** — broken by
// the act that exists to keep it.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::path::PathBuf;

use z_core::api::*;

/// The head of the owner's file, character for character: the two lines the
/// overshoot joined, and a line above and below them so neither edge of the
/// measurement sits at the edge of the document.
const DOC: &str = "FARUK AB — LÖNEKÖRNING FEBRUARI 2027\n\
                   Organisationsnummer: 559000-0000\n\
                   Adress: Storgatan 1, 100 00 Stockholm\n\
                   E-post: ekonomi@farukab.example\n";

/// His real file, when it is on this machine. The guard runs on the inline copy
/// above in every case, so the gates never need the owner's documents.
fn film() -> Option<String> {
    let path = PathBuf::from(std::env::var("HOME").ok()?)
        .join("Documents/film/FarukAB_lonekorning_feb2027.txt");
    std::fs::read_to_string(path).ok()
}

fn units(s: &str) -> u32 {
    s.encode_utf16().count() as u32
}

/// Where a phrase starts, counted the way the screen counts: UTF-16 units.
fn at(doc: &str, needle: &str) -> u32 {
    units(&doc[..doc.find(needle).unwrap_or_else(|| panic!("«{needle}» is not in this document"))])
}

fn a_document(doc: &str) -> SessionId {
    // The owner's own configuration on the day: the English pack on a Swedish
    // file, which is why he has to protect the organisation number by hand at
    // all. 038-B is that half; this item is what happens when he does.
    let session = open_session(None, "en".to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    session
}

/// What Protect will really take — the span the core hands back to the bubble.
fn what_protect_would_take(session: SessionId, span: Span) -> String {
    let view = inspect_selection(session, span).expect("inspect");
    let text = document_view(session).expect("view").text;
    let u: Vec<u16> = text.encode_utf16().collect();
    String::from_utf16_lossy(&u[view.word_span.start as usize..view.word_span.end as usize])
}

/// A selection of `needle`, drawn `past` characters too far at the end.
fn overshooting_the_end(doc: &str, needle: &str, past: u32) -> Span {
    let start = at(doc, needle);
    Span { start, end: start + units(needle) + past }
}

/// A selection of `needle`, drawn `before` characters too far back at the start
/// — the owner's commonest case, because at the left margin the pointer lands
/// after the first character every time.
fn overshooting_the_start(doc: &str, needle: &str, before: u32) -> Span {
    let start = at(doc, needle);
    Span { start: start - before, end: start + units(needle) }
}

// ---------------------------------------------------------------- at the unit

/// The owner's own case: two characters past the organisation number.
#[test]
fn two_characters_past_a_value_is_still_that_value() {
    let session = a_document(DOC);
    assert_eq!(
        what_protect_would_take(session, overshooting_the_end(DOC, "559000-0000", 2)),
        "559000-0000",
        "the selection crossed a line and took the first word of the next one",
    );
}

/// The same overshoot, mirrored, at the edge the function exists to serve.
#[test]
fn two_characters_back_from_a_value_is_still_that_value() {
    let session = a_document(DOC);
    assert_eq!(
        what_protect_would_take(session, overshooting_the_start(DOC, "Adress", 2)),
        "Adress",
        "the selection reached backwards over a line break and took the line above",
    );
}

/// The three readings that were already right, so a fix cannot quietly change
/// them: an exact selection, and the overshoot of exactly one character that
/// rule 2 tidies away and that hid the rest of this for a day.
#[test]
fn an_exact_selection_and_an_overshoot_of_one_are_unchanged() {
    let session = a_document(DOC);
    for (span, expected, what) in [
        (overshooting_the_end(DOC, "559000-0000", 0), "559000-0000", "exact, at the end"),
        (overshooting_the_end(DOC, "559000-0000", 1), "559000-0000", "the newline alone"),
        (overshooting_the_start(DOC, "Adress", 0), "Adress", "exact, at the start"),
    ] {
        assert_eq!(what_protect_would_take(session, span), expected, "{what}");
    }
}

/// 041-K, unchanged: inside one line the growth is still outward, and a drag
/// that starts one letter late still takes the whole name. The fix must not buy
/// one rule with another.
#[test]
fn inside_one_line_a_selection_still_grows_to_whole_words() {
    let doc = "Jonas Bjarne skrev avtalet.\nKontakta Sandström, tack.\n";
    let session = a_document(doc);
    assert_eq!(
        what_protect_would_take(session, overshooting_the_start(doc, "onas Bjarne", 0)),
        "Jonas Bjarne",
        "the J was left behind",
    );
    assert_eq!(
        what_protect_would_take(session, overshooting_the_end(doc, "Sandström", 1)),
        "Sandström",
        "the comma came with it",
    );
}

/// What the lead asked the fix to be — and it was already true on 82d5858,
/// which is why it is written down here as an anchor and not as the guard. A
/// newline is not a word character, so `cuts_a_word` was always false at a line
/// boundary and the growth never *crossed* one. The harm was the growth that
/// happens entirely on the far side of a break the person had already drawn
/// across.
#[test]
fn growth_stops_at_a_line_break_and_always_did() {
    let session = a_document(DOC);
    // A selection that ends exactly at the end of its line does not reach on to
    // the next word, with or without this item's change.
    assert_eq!(
        what_protect_would_take(session, overshooting_the_end(DOC, "559000-0000", 0)),
        "559000-0000",
    );
}

// --------------------------------------------------------------- end to end

/// The guard that matters: after the overshoot, the document that leaves still
/// reads the way it arrived.
fn the_line_below_survives(doc: &str, where_from: &str) {
    let session = a_document(doc);
    protect(session, overshooting_the_end(doc, "559000-0000", 2), Scope::Once, Kind::Custom)
        .expect("protect");
    let payload = payload_view(build_payload(session).expect("build")).expect("view").text;

    assert!(
        payload.contains("\nAdress: Storgatan 1, 100 00 Stockholm\n"),
        "{where_from}: «Adress: Storgatan 1, 100 00 Stockholm» is no longer its own line in \
         the text that leaves — two lines of the owner's document were joined by protecting \
         the line above",
    );
    assert!(
        payload.contains("Organisationsnummer: __Z_"),
        "{where_from}: the token does not stand where the organisation number stood",
    );
    assert!(
        !payload.contains("559000-0000"),
        "{where_from}: the organisation number is still in the clear",
    );
}

#[test]
fn the_document_that_leaves_still_reads_the_way_it_arrived() {
    the_line_below_survives(DOC, "the inline copy");
}

/// And on his own file, when it is here. 2,545 bytes of Swedish payroll with
/// eight people in a table under the two lines in question, so a span read in
/// the wrong units has somewhere to go wrong.
#[test]
fn on_the_owners_own_file() {
    match film() {
        Some(doc) => the_line_below_survives(&doc, "the owner's own file"),
        None => println!("~/Documents/film/FarukAB_lonekorning_feb2027.txt is not on this machine"),
    }
}

/// Harm 1, at the place it is recorded: whatever the core wrote down as the
/// protected value, it is a thing on one line. A value with a line break inside
/// it never matches that organisation number again — not in this document, not
/// in tomorrow's, not under «Profile» or «Always».
#[test]
fn a_value_that_was_remembered_is_a_thing_on_one_line() {
    let session = a_document(DOC);
    protect(session, overshooting_the_end(DOC, "559000-0000", 2), Scope::Once, Kind::Custom)
        .expect("protect");
    let view = document_view(session).expect("view");
    let text: Vec<u16> = view.text.encode_utf16().collect();
    let protected: Vec<String> = view
        .marks
        .iter()
        .filter(|m| m.state == MarkState::Protected)
        .map(|m| String::from_utf16_lossy(&text[m.span.start as usize..m.span.end as usize]))
        .collect();
    assert!(!protected.is_empty(), "nothing was protected at all");
    for value in &protected {
        assert!(!value.contains('\n'), "the value remembered was {value:?}, which is two lines");
    }
}

// ------------------------------------- the two decisions inside «most of it»

/// «The line it holds most of» is counted in characters, not in bytes.
///
/// Arabic is two bytes a letter, so a four-letter Arabic piece is eight bytes
/// and a six-letter Swedish piece is six. Counted in bytes the Arabic piece
/// wins a comparison it should lose, and a selection that overshot *into*
/// «Adress» would protect the chief's name on the line above instead. Z's
/// Arabic is a script family — Persian and Urdu arrive by the same door — so
/// this is not one document's curiosity.
#[test]
fn the_longest_piece_is_measured_in_characters_and_not_in_bytes() {
    let doc = "Chef: محمد\nAdress: Storgatan 1\n";
    let session = a_document(doc);
    let start = at(doc, "محمد");
    let end = at(doc, "Adress") + units("Adress");
    assert_eq!(
        what_protect_would_take(session, Span { start, end }),
        "Adress",
        "four Arabic letters are eight bytes and outweighed six Swedish ones",
    );
}

/// A piece that is only spaces is not a candidate, however long it is.
///
/// The owner's payroll table is laid out in columns, so a run of spaces can be
/// the longest thing between two line breaks. Chosen, it survives rule 1 and is
/// then tidied away to nothing by rule 2 — and a span that comes back empty is
/// handed back **as drawn**, which is the whole overshoot again by another road.
#[test]
fn a_run_of_spaces_is_never_the_line_the_person_meant() {
    let doc = "Organisationsnummer: 559000-0000\n            \nAdress: Storgatan 1\n";
    let session = a_document(doc);
    let start = at(doc, "0000\n");
    let end = at(doc, "Adress") + units("Adr");
    assert_eq!(
        what_protect_would_take(session, Span { start, end }),
        "559000-0000",
        "twelve spaces were taken for the line the person was aiming at",
    );
}

// ------------------------------------------- what the rule costs, pinned here

/// The cost, asserted on purpose: a value the **document** wrapped across two
/// lines is now protected by its longer half alone.
///
/// A person who selects «Sven\nNelander» — a name an extracted PDF broke over a
/// line end — gets «Nelander» protected and «Sven» left standing in the clear.
/// That is a leak this item introduces, and it is written down as a test rather
/// than as a sentence in a commit because a property nobody wrote down is a
/// property nobody can prove changed.
///
/// Why it is still the right trade: the harm it replaces was silent and
/// constant — every slightly long drag joined two lines of the document and
/// stored a value that could never match again — while this one is **visible**.
/// `session_state.dart` sets `selection = view.wordSpan` when a drag ends, so
/// the person sees «Nelander» highlighted, not what they drew, and can take the
/// other half with a second drag.
///
/// What would change it: a rule that clips only when an edge cuts a word, which
/// would keep this selection whole — and would also let a deliberate two-line
/// selection through, which is the harm. That is the owner's call, not this
/// item's.
#[test]
fn a_value_the_document_itself_wrapped_is_protected_by_its_longer_half() {
    let doc = "Handläggare för ärendet är Sven\nNelander, Stockholm\n";
    let session = a_document(doc);
    let start = at(doc, "Sven");
    let span = Span { start, end: start + units("Sven\nNelander") };

    assert_eq!(what_protect_would_take(session, span), "Nelander", "the cost has changed");

    protect(session, span, Scope::Once, Kind::Person).expect("protect");
    let payload = payload_view(build_payload(session).expect("build")).expect("view").text;
    assert!(payload.contains("är Sven\n__Z_"), "the cost has changed: {payload:?}");
    assert!(!payload.contains("Nelander"), "the half that was taken is still in the clear");
}

/// A page break is a line break as well, and that took a measurement to settle.
///
/// 041-L says «a selection may cross a page boundary, and then the whole stretch
/// leaves as one token and that break is not in the payload at all», and the
/// reader leaves a form feed with an ordinary newline beside it — so every
/// crossing of a page break is a crossing of a line break and the two rules
/// meet head on. Carving a hole in this one would have been the easy answer and
/// the wrong one: the crossing was 041-L's **setup**, never its subject, which
/// is the page numbering. Measured: a break is still swallowed with no hand
/// drawn across it, by «protect every place this value appears» — the matcher
/// reads an exact value over any run of whitespace, a form feed included — so
/// 041-L keeps its claim, its test keeps its subject, and this rule has no
/// exception.
///
/// The three now say one coherent thing. The scanner's pair rule refuses to
/// read across a page break (038-I: «the last word of one page and the first of
/// the next are not neighbours»). A hand selection refuses too, here. An exact
/// value the person pointed at still crosses it — because that is a value and
/// the other two are guesses.
#[test]
fn an_overshoot_across_a_page_break_is_clipped_like_any_other() {
    let doc = "Kund: Nordstern AB\n\u{c}Sida tv\u{e5}: Storgatan 1\n";
    let session = a_document(doc);
    let start = at(doc, "Nordstern AB");
    // Three characters too far: the newline, the page break, and one letter of
    // the first word on the page below.
    let span = Span { start, end: start + units("Nordstern AB") + 3 };
    assert_eq!(
        what_protect_would_take(session, span),
        "Nordstern AB",
        "the overshoot walked onto the next page",
    );
}

/// And the act that still crosses a page break, because 041-L leans on it:
/// every place an exact value appears.
///
/// The value stands once on a line of its own and once straddling the break.
/// One hand selection, crossing nothing, protects both — and the form feed
/// between the halves of the second one leaves with the token.
#[test]
fn every_place_an_exact_value_appears_still_reads_across_a_page() {
    let doc = "Sida ett\n\nKontakt: Sven Nelander\n\nFr\u{e5}gor till Sven\u{c}Nelander svarar.\n";
    let session = a_document(doc);
    let outcome =
        protect_all_matches(session, Span {
            start: at(doc, "Sven Nelander"),
            end: at(doc, "Sven Nelander") + units("Sven Nelander"),
        }, Scope::Once, Kind::Person)
        .expect("protect every place");
    assert!(
        matches!(outcome, ProtectOutcome::Applied { places: 2, .. }),
        "the place straddling the page break was not found: {outcome:?}",
    );
    let payload = payload_view(build_payload(session).expect("build")).expect("view").text;
    assert!(!payload.contains('\u{c}'), "the swallowed page break is still in the payload");
    assert!(!payload.contains("Nelander"), "half the name is still in the clear: {payload:?}");
}

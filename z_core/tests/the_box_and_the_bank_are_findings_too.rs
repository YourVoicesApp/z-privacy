// **The post-office box and the bank's own name** — 095, خ5, the finding two
// attackers measured on the same German letter and nobody closed: the
// independent attacker's B1-1 and B1-2 of 17 October, and the outside model's
// خ5 of 19 October, both graded serious.
//
// **What was measured, twice.** `Mahnung_Feldmann.txt` — the in-tree twin of
// the owner's own «ألماني 1» — with pack `de`, every suggestion answered and
// zero open:
//
// ```text
//   Kundenservice · Postfach 4410 · 04179 Leipzig
//   Bankverbindung: Sparkasse Leipzig, IBAN DE89 … 00, BIC COBADEFFXXX
// ```
//
// The address finding covered `04179 Leipzig` and stopped. `Postfach 4410`
// was never a finding at all, so the line that left the machine still said
// which box to write to — and a PO box is the address a letter is answered
// to, which is the whole of what an address protects. On the footer line the
// scanner cut the IBAN and the BIC out of the middle of the sentence and
// walked past the bank's own name, although the GmbH on the letterhead of the
// same letter **is** offered.
//
// **What this file holds to.** Both are findings now: `Postfach 4410` as a
// postal identity of kind address, and `Sparkasse Leipzig` as a company
// offered exactly as the letterhead's GmbH is offered — and after a finished
// review neither stands in the text that leaves.
//
// **The limits, kept as they were written.** The amount and the city on the
// date line are context, not identities (the review's ن14), and this round does
// not touch them. And the label stays in the clear beside its value, as every
// label in this product does: «a label is not a value» is G48's own law, so
// `Postfach` is text and `4410` is the identity.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const LETTER: &str = include_str!("fixtures/Mahnung_Feldmann.txt");

/// Every finding over a text, as (state, kind, the characters the span covers).
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

/// The letter after a finished review: every suggestion protected, nothing
/// waiting, and the text that the manual doors would hand out.
fn what_leaves(doc: &str) -> String {
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    for f in list_findings(s).expect("findings") {
        if f.state == MarkState::Suggested {
            answer_finding(s, f.id, FindingAnswer::Protect).expect("answer");
        }
    }
    let out = payload_to_take_out(s).expect("the copy door").text;
    close_session(s).ok();
    out
}

// ------------------------------------------------------------- 1 · the box

#[test]
fn the_post_office_box_is_a_finding() {
    let box_findings: Vec<_> = found(LETTER, "de")
        .into_iter()
        .filter(|(_, kind, text)| *kind == Kind::Address && text.contains("4410"))
        .collect();
    assert_eq!(
        box_findings.len(),
        1,
        "the box number is {} findings; the line says «Postfach 4410» and a box is an address",
        box_findings.len()
    );
}

#[test]
fn the_box_number_does_not_leave_after_a_finished_review() {
    let left = what_leaves(LETTER);
    assert!(
        !left.contains("4410"),
        "the box number left the machine after every suggestion was answered"
    );
    // The label is text and stays: a reader must still be able to see that a
    // box number was there, exactly as «IBAN» stays beside its token.
    assert!(
        left.contains("Postfach"),
        "the label went with the value — a label is not a value, and the \
         sentence no longer reads as the person wrote it"
    );
}

// ------------------------------------------------------------ 2 · the bank

#[test]
fn the_banks_own_name_is_offered_as_the_letterhead_company_is() {
    let all = found(LETTER, "de");
    let bank: Vec<_> = all
        .iter()
        .filter(|(_, kind, text)| *kind == Kind::Company && text.contains("Sparkasse"))
        .collect();
    assert_eq!(
        bank.len(),
        1,
        "the bank's name is {} findings on a line whose IBAN and BIC are both cut out of it: {all:?}",
        bank.len()
    );
    let (state, _, text) = bank[0];
    assert_eq!(
        *state,
        MarkState::Suggested,
        "the bank's name is «{text}» at {state:?}; the GmbH on the letterhead of the \
         same letter is offered, and one kind of company is not two kinds of claim"
    );
    assert_eq!(
        text.trim(),
        "Sparkasse Leipzig",
        "the span is «{text}» — the bank's name and nothing of the field beside it"
    );
}

#[test]
fn the_banks_name_does_not_leave_after_a_finished_review() {
    let left = what_leaves(LETTER);
    assert!(
        !left.contains("Sparkasse"),
        "the bank's name left the machine after every suggestion was answered"
    );
    assert!(
        left.contains("Bankverbindung"),
        "the label went with the value"
    );
}

// ---------------------------------------------------------- 3 · the controls

/// **A label at `Auto` is paid for with its own shape.** «Postfach» with no
/// number after it is a word in a sentence, and this product does not protect
/// words in sentences.
#[test]
fn the_label_alone_takes_nothing() {
    let doc = "Unser Postfach wurde geschlossen.\nBankverbindung folgt.\n";
    let taken = found(doc, "de");
    assert!(
        taken.is_empty(),
        "a label with no value after it took something: {taken:?}"
    );
}

/// **And a bank-shaped name on an ordinary line is not a bank.** The row reads
/// a field, not a word: without its label the same two words are prose.
#[test]
fn a_company_name_without_its_label_is_not_taken_by_these_rules() {
    let doc = "Die Sparkasse Leipzig hat heute geschlossen.\n";
    let taken: Vec<_> = found(doc, "de")
        .into_iter()
        .filter(|(_, kind, text)| *kind == Kind::Company && text.contains("Sparkasse"))
        .collect();
    assert!(
        taken.is_empty(),
        "a sentence about a bank was read as a bank field: {taken:?}"
    );
}

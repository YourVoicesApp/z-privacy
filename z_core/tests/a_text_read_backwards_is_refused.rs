//! **A text Z read backwards is not protected** — paper 119, the owner's rule
//! of 26 October 2026: «عندما لا يستطيع Z الوثوقَ بأمانة النصّ المستخرج، لا
//! يعرض نجاحَ الحماية كأن النصّ قُرئ صحيحاً».
//!
//! The fault this closes was measured on five fixtures of our own making
//! (paper 118, kept at `~/work-now/zprivacy-arabic-pdf-fixtures/`): an Arabic
//! PDF written in **display order** — which is what a layout engine emits — was
//! imported, never refused, and matched almost nothing. 4 marks where plain
//! text gets 26, not one of the letter's eight people, the customer number
//! read as «0219-3377», and — the part that made it a defect rather than a
//! shortcoming — **an e-mail address protected backwards**:
//! `as.iramola-batkam@iramola.fesuoy`. A token stood for a string nobody wrote,
//! while the real address was nowhere in the text and could be neither
//! protected nor restored. The person was shown a successful protection of a
//! document that had been read wrong.
//!
//! **What is refused is not «Arabic» and not «right to left».** The same letter
//! written in logical order is read exactly as well as plain text — 19 values
//! protected, 5 waiting — and is not refused. What is refused is a text whose
//! letters are the **shapes a drawing chose**, because an engine that chose the
//! shapes chose the order too.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};
use z_core::api::*;

const AR1: &str = include_str!("fixtures/Risala_Alharbi.txt");

/// AR-1's own opening, as a layout engine hands it over: every letter replaced
/// by its display form and the line reversed, which is what
/// `case1_visual.pdf` extracts to.
const DRAWN: &str = "17440-6202 ﻡﻕﺭ ﻡﻙﺕﺭﻭﺕﺍﻑ ﻥﻉ ﺭﺍﺱﻑﺕﺱﺍ :ﻉﻭﺽﻭﻡﻝﺍ";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    let lock = LOCK.get_or_init(|| Mutex::new(()));
    match lock.lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh(tag: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-backwards-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
}

fn percent_of(e: &ApiError) -> Option<u32> {
    match e {
        ApiError::DocumentRefused { reason: Refusal::TextInDisplayForms { percent }, .. } => Some(*percent),
        _ => None,
    }
}

/// **The file road.** A document whose Arabic is display forms is refused by
/// name, and the refusal carries its share and its sentence.
#[test]
fn a_file_read_backwards_is_refused_by_name() {
    let _g = serial();
    fresh("file");
    let session = open_session(None, "ar".to_string()).expect("open");
    let err = import_document(
        session,
        "drawn.txt".to_string(),
        DRAWN.as_bytes().to_vec(),
        DocumentKind::Txt,
    )
    .expect_err("a text read backwards was imported");
    let percent = percent_of(&err).unwrap_or_else(|| panic!("refused by the wrong name: {err:?}"));
    assert!(percent >= 33, "the share it refused on was {percent}%");
    if let ApiError::DocumentRefused { detail, .. } = &err {
        // The two things a person can act on: what went wrong, and what does
        // not go wrong that way.
        assert!(detail.contains("backwards"), "{detail}");
        assert!(detail.contains("Word file") || detail.contains("plain-text"), "{detail}");
    }
    let _ = close_session(session);
}

/// **The paste road, closed in the same breath** — and the reason is the
/// refusal above: it tells a person their document was read backwards, and the
/// shortest thing they can do next is open it in a viewer and paste. That is
/// the same reversed text by the one road that was never checked.
#[test]
fn a_paste_read_backwards_is_refused_too() {
    let _g = serial();
    fresh("paste");
    let session = open_session(None, "ar".to_string()).expect("open");
    let err = import_text(session, DRAWN.to_string()).expect_err("a pasted reversal was taken");
    assert!(percent_of(&err).is_some(), "refused by the wrong name: {err:?}");
    let _ = close_session(session);
}

/// **And the whole point of the paper: the logical letter is never refused.**
///
/// The same words, written the way a keyboard writes them. The numbers are the
/// product's own, measured on this fixture since paper 117: 19 protected
/// automatically, 5 waiting for the person's word.
#[test]
fn the_same_letter_written_forwards_is_read_as_well_as_ever() {
    let _g = serial();
    fresh("forwards");
    let session = open_session(None, "ar".to_string()).expect("open");
    let view = import_document(
        session,
        "letter.txt".to_string(),
        AR1.as_bytes().to_vec(),
        DocumentKind::Txt,
    )
    .expect("the logical letter must never be refused");
    assert!(view.text.contains("استفسار"), "the text came through changed");
    let report = scan(session).expect("scan");
    assert_eq!(
        (report.auto, report.suggested),
        (19, 5),
        "the Arabic pack's own numbers on AR-1 moved"
    );
    // And typed Arabic, which is what a keyboard writes.
    let typed = import_text(session, "السيد طارق بن سعود الريحاني كتب إلينا.".to_string());
    assert!(typed.is_ok(), "typed Arabic was refused: {typed:?}");
    let _ = close_session(session);
}

/// **The two numbers of the signal, and the four shapes they were chosen
/// from** — the threshold is a measurement, not an opinion.
#[test]
fn the_signal_reads_both_sides() {
    let _g = serial();
    fresh("signal");
    let session = open_session(None, "ar".to_string()).expect("open");
    // A page of drawing: refused.
    assert!(import_text(session, DRAWN.to_string()).is_err());
    // A page of writing: taken.
    assert!(import_text(session, AR1.to_string()).is_ok());
    // **The one ligature real Arabic writing does use**, among ordinary words:
    // «ﷺ» stands in the same compatibility block and is a share of nothing.
    let honest = format!("{AR1}\nقال النبي ﷺ ما شاء الله، ﻻ إله إلا الله.");
    assert!(
        import_text(session, honest).is_ok(),
        "a page using «ﷺ» was read as a drawing"
    );
    // **And a share means nothing over three letters**: one Arabic word, and
    // that word a ligature, is 100% display forms and perfectly honest.
    assert!(
        import_text(session, "Mr Tarek — ﷺ".to_string()).is_ok(),
        "a short line was judged on a share of nothing"
    );
    // But a reversed name inside an English letter carries enough to judge.
    let reversed_name = "Mr Tarek — ﻁﺍﺭﻕ ﺍﻝﺭﻱﺡﺍﻥﻱ";
    assert!(
        import_text(session, reversed_name.to_string()).is_err(),
        "a reversed Arabic name in an English letter escaped the floor"
    );
    let _ = close_session(session);
}

/// **The five cases of paper 118, measured again** — item 5 of this paper.
///
/// The fixtures are ours and invented (AR-1 set in DejaVu by `mkpdf.py`), and
/// they live **outside the tree** at `~/work-now/zprivacy-arabic-pdf-fixtures/`
/// with their sha256 beside them. A guard cannot carry 1.6 MB of embedded font
/// into the repository for one measurement, so this says out loud when they are
/// not on the machine rather than pretending to have measured them — the shape
/// `a_z_pdf_reads_back_its_lines` uses for the owner's own three files. What is
/// measured **everywhere** is the four guards above, which need no fixture at
/// all.
///
/// Expected, and all five were read before this paper and again after it:
///
/// ```text
///     case1_logical.pdf        19 auto · 5 waiting      unchanged — never refused
///     case2_mixed.pdf           8 auto · 2 waiting      unchanged — never refused
///     case1_no_tounicode.pdf   refused: UnreadableStructure      (as before)
///     case3_scan.pdf           refused: ScannedPdfNoTextLayer    (as before)
///     case1_visual.pdf         refused: TextInDisplayForms, 96%  (this paper)
/// ```
#[test]
fn the_five_fixtures_read_as_this_paper_says() {
    let _g = serial();
    let dir = std::path::Path::new("/home/monopeaks/work-now/zprivacy-arabic-pdf-fixtures");
    if !dir.is_dir() {
        println!(
            "the five fixtures of paper 118 are not on this machine ({}), so this guard \
             measured nothing — the four above need no fixture",
            dir.display()
        );
        return;
    }
    let read = |file: &str| -> Result<(u32, u32), ApiError> {
        fresh(file);
        let bytes = std::fs::read(dir.join(file)).expect("the fixture");
        let session = open_session(None, "ar".to_string()).expect("open");
        let out = import_document(session, file.to_string(), bytes, DocumentKind::Pdf)
            .and_then(|_| scan(session))
            .map(|r| (r.auto, r.suggested));
        let _ = close_session(session);
        out
    };

    // The two that read, and their numbers are the product's own.
    assert_eq!(read("case1_logical.pdf").expect("logical"), (19, 5));
    assert_eq!(read("case2_mixed.pdf").expect("mixed"), (8, 2));

    // The two that were already refused, by the same names as before.
    match read("case1_no_tounicode.pdf") {
        Err(ApiError::DocumentRefused { reason: Refusal::UnreadableStructure { page }, .. }) => {
            assert_eq!(page, 1);
        }
        other => panic!("a font with no character map: {other:?}"),
    }
    match read("case3_scan.pdf") {
        Err(ApiError::DocumentRefused { reason: Refusal::ScannedPdfNoTextLayer { pages }, .. }) => {
            assert_eq!(pages, 1);
        }
        other => panic!("an image with no text layer: {other:?}"),
    }

    // And the one this paper is for.
    match read("case1_visual.pdf") {
        Err(ApiError::DocumentRefused { reason: Refusal::TextInDisplayForms { percent }, .. }) => {
            assert_eq!(percent, 96, "the share measured on the display-order fixture");
        }
        other => panic!("the display-order page was not refused by name: {other:?}"),
    }
}

//! Reading a document — from memory, within limits, or not at all.
//!
//! Four rules from the owner shape this module, and each one is a line of code
//! rather than an intention:
//!
//! 1. **No intermediate files.** Every reader takes `&[u8]` and returns text. The
//!    original never touches the disk, not for a millisecond. Gate G15 forbids the
//!    filesystem here at all.
//! 2. **A position map.** Text arrives with `page` and `paragraph` for every run,
//!    so a review list can say «page 17» after everything has been replaced.
//! 3. **Named refusals.** [`crate::api::Refusal`] says *which* problem it was; a
//!    scanned page and a corrupt zip are not the same news.
//! 4. **Limits from the first day.** A document is untrusted input. Size, pages,
//!    decompressed text and time are all bounded, and refusing a file is always
//!    better than letting one eat the machine.

pub(crate) mod docx;
pub(crate) mod pdf;
pub(crate) mod txt;
pub(crate) mod zip;

use std::cell::{Cell, RefCell};
use std::collections::BTreeSet;
use std::time::{Duration, Instant};

#[cfg(test)]
use crate::api::Place;
use crate::api::{ApiError, ApiResult, DocumentKind, Refusal};

/// Limits. Deliberately modest: a working document, not a library.
pub(crate) mod limits {
    /// The file itself.
    pub(crate) const FILE_BYTES: usize = 25 * 1024 * 1024;
    /// Pages in one document.
    ///
    /// Measured, not chosen: the owner's 734-page Word export holds 1,589,783
    /// characters — 1,589,050 of its own and 733 page edges, one between every
    /// two pages — which is 2,166 a page, and `TEXT_BYTES` below stops at
    /// 1,937 pages of that density. So the real guard is the text, and this
    /// number is set where the text runs out rather than under it — a document
    /// of 600 pages was refused by a limit of 500 that defended nothing.
    pub(crate) const PAGES: u32 = 2000;
    /// Text after decompression — the defence against a small file that swells.
    pub(crate) const TEXT_BYTES: usize = 4 * 1024 * 1024;
    /// One entry inside a zip, decompressed.
    pub(crate) const ZIP_ENTRY_BYTES: usize = 8 * 1024 * 1024;
    /// Parts listed inside one zip. A DOCX has tens, not thousands.
    pub(crate) const ZIP_ENTRIES: u32 = 512;
    /// How much bigger a part may be than its compressed form. A zip bomb is a
    /// few kilobytes that unpack into gigabytes; a document is well under this.
    ///
    /// **Measured on what this reader actually unpacks** (17 October), because
    /// the same number now holds a PDF's streams too: the worst swell in any
    /// stream the PDF reader opens, over the owner's three golden documents and
    /// his five z-pdfs, is **95.7×** — one object stream in the 146-page tax
    /// book. The 1020× stream in his 734-page catalogue is an **image**, and
    /// this reader never opens one. So 200 leaves a factor of two over the
    /// worst real document and still refuses the attacker's 946×.
    pub(crate) const MAX_RATIO: u32 = 200;
    /// One Flate stream inside a PDF, decoded — V1-J's number, and the same
    /// one a zip entry gets, for the same reason: no single part of a document
    /// is this big. Measured: the biggest stream this reader opens in any of
    /// the owner's documents is 784,761 bytes, in the tax book.
    pub(crate) const PDF_STREAM_BYTES: usize = 8 * 1024 * 1024;
    /// What **one whole document** may unpack to, counted over every Flate
    /// stream this reader opens, whatever its role.
    ///
    /// **Two numbers and not one, and the reason is a measurement.** V1-J puts
    /// a flat ceiling of 16 MiB on the whole document, and it can: it refuses
    /// every object stream before loading one, so nothing it reads is a Word
    /// file. This reader must read them — the page tree of seven Swedish
    /// e-documents on this machine is packed in one — and the owner's 734-page
    /// catalogue unpacks to **39.50 MiB** out of a 4.87 MiB file. A flat 16 MiB
    /// would refuse his own golden document, and the house already paid for
    /// that lesson once with `PAGES`: a limit that refuses a real document
    /// defends nothing.
    ///
    /// So the law is the ratio rule again, at the document's own scale: a
    /// document does not swell more than thirty-twofold over all its streams
    /// together — his worst real file swells **8.1×**, which leaves a factor of
    /// four — and never less than V1-J's 16 MiB, so a small file gets exactly
    /// the library's number. The attacker's 49 KiB object-stream bomb asks for
    /// 48 MiB, which is 1,000×.
    pub(crate) const PDF_UNPACKED_SWELL: usize = 32;
    pub(crate) const PDF_UNPACKED_FLOOR: usize = 16 * 1024 * 1024;
    /// How long reading may take before we stop and say so.
    ///
    /// Measured on the biggest files we accept. The 734-page export reads in
    /// 136 ms in release and 1,049 ms in a debug build — 215 ms per megabyte —
    /// so the 25 MB a `FILE_BYTES` allows would take about 5.4 seconds to read
    /// in debug and 0.7 in release. The old 5,000 would have refused a large
    /// but perfectly ordinary document for being slow. This is four times the
    /// measured worst case, and still a ceiling no real file comes near.
    pub(crate) const MILLIS: u64 = 20_000;
}

/// One run of text, and where it sits.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct PlaceSpan {
    /// Byte range in the extracted text.
    pub start: usize,
    pub end: usize,
    pub page: u32,
    pub paragraph: u32,
}

/// What a reader produces: the text, the map, and how many pages there were.
#[derive(Debug, Clone)]
pub(crate) struct Extracted {
    pub text: String,
    pub places: Vec<PlaceSpan>,
    pub pages: u32,
    /// The lowest share of one page that decoded into characters, as a
    /// percentage. 100 where every byte was already text. Carried out of the
    /// reader because it is the one number that says whether a document was
    /// read or merely accepted — and the report a person copies shows it.
    pub readable: u32,
}

impl Extracted {
    /// Where a byte range in the text came from.
    ///
    /// The session keeps its own copy of the map once a document is imported, so
    /// in the crate this is the readers' own way of checking themselves.
    #[cfg(test)]
    pub(crate) fn place_of(&self, start: usize) -> Option<Place> {
        self.places
            .iter()
            .find(|p| p.start <= start && start < p.end)
            .map(|p| Place {
                page: p.page,
                paragraph: p.paragraph,
            })
    }
}

/// Builds the text and its map together, so the two can never drift apart.
#[derive(Debug, Default)]
pub(crate) struct Builder {
    text: String,
    places: Vec<PlaceSpan>,
    pages: u32,
    readable: Option<u32>,
}

impl Builder {
    pub(crate) fn new() -> Self {
        Self::default()
    }

    /// Add one run of text, saying where it came from.
    pub(crate) fn push(&mut self, run: &str, page: u32, paragraph: u32) -> ApiResult<()> {
        if run.is_empty() {
            return Ok(());
        }
        if self.text.len().saturating_add(run.len()) > limits::TEXT_BYTES {
            return Err(refuse(
                Refusal::TextTooLarge {
                    limit_mib: (limits::TEXT_BYTES / 1024 / 1024) as u32,
                },
                format!("the text passed {} MiB while being read", limits::TEXT_BYTES / 1024 / 1024),
            ));
        }
        let start = self.text.len();
        self.text.push_str(run);
        self.places.push(PlaceSpan {
            start,
            end: self.text.len(),
            page,
            paragraph,
        });
        self.pages = self.pages.max(page);
        Ok(())
    }

    /// What share of one page decoded into characters. The lowest one wins: an
    /// average hides the single page that failed, and that is the page with the
    /// name on it.
    pub(crate) fn saw_readable(&mut self, percent: u32) {
        self.readable = Some(self.readable.map_or(percent, |lowest| lowest.min(percent)));
    }

    /// Text that belongs to no particular place: a separator between runs.
    pub(crate) fn push_break(&mut self, separator: &str) {
        if self.text.len().saturating_add(separator.len()) <= limits::TEXT_BYTES {
            self.text.push_str(separator);
        }
    }

    pub(crate) fn finish(self) -> ApiResult<Extracted> {
        if self.text.trim().is_empty() {
            return Err(refuse(
                Refusal::EmptyDocument,
                "there is no text in this document to protect".to_string(),
            ));
        }
        Ok(Extracted {
            text: self.text,
            places: self.places,
            readable: self.readable.unwrap_or(100),
            pages: self.pages.max(1),
        })
    }
}

/// A clock and a size, checked while reading rather than after.
///
/// **One budget for one document.** It is made once, where the file arrives,
/// and handed down to every reader and every stream inside it: the clock bounds
/// the work, and the meter below bounds what may be unpacked out of the file in
/// all. A limit that lives in the loop that inflates can stop a bomb while it
/// is inflating; one applied afterwards has already lost.
#[derive(Debug)]
pub(crate) struct Budget {
    started: Instant,
    limit: Duration,
    /// The file's own size — what every «how much may come out of it» is
    /// measured against.
    file_bytes: usize,
    /// What has been unpacked out of it so far.
    unpacked: Cell<usize>,
    /// The streams already counted, by object number. A page's font is read
    /// again on every page that names it, and the owner's 734-page catalogue
    /// names its own fonts 734 times: counting those bytes again each time
    /// would measure the **reader's** repeated work and not the document's
    /// size, and would refuse his file for a cost the file never asked for.
    /// Reading one stream twice is work, and the clock above is what answers
    /// for work.
    counted: RefCell<BTreeSet<u32>>,
}

impl Budget {
    pub(crate) fn new(file_bytes: usize) -> Self {
        Self {
            started: Instant::now(),
            limit: Duration::from_millis(limits::MILLIS),
            file_bytes,
            unpacked: Cell::new(0),
            counted: RefCell::new(BTreeSet::new()),
        }
    }

    pub(crate) fn check(&self) -> ApiResult<()> {
        if self.started.elapsed() > self.limit {
            return Err(refuse(
                Refusal::TookTooLong {
                    millis: limits::MILLIS as u32,
                },
                format!("reading this document passed {} ms", limits::MILLIS),
            ));
        }
        Ok(())
    }

    /// What this file's own bytes allow to be unpacked out of it, in all.
    pub(crate) fn unpacked_ceiling(&self) -> usize {
        limits::PDF_UNPACKED_FLOOR.max(self.file_bytes.saturating_mul(limits::PDF_UNPACKED_SWELL))
    }

    /// Room left for one stream to inflate into. Asked **before** a byte is
    /// inflated, so that the decompressor itself is stopped at the ceiling.
    pub(crate) fn room_for(&self, object: u32) -> usize {
        if self.counted.borrow().contains(&object) {
            // Already paid for: its own limit still holds it, the document's
            // ceiling is not charged twice.
            return limits::PDF_STREAM_BYTES;
        }
        self.unpacked_ceiling().saturating_sub(self.unpacked.get())
    }

    /// Write down what one stream really unpacked to, once per object.
    pub(crate) fn unpacked(&self, object: u32, bytes: usize) {
        if self.counted.borrow_mut().insert(object) {
            self.unpacked.set(self.unpacked.get().saturating_add(bytes));
        }
    }

    pub(crate) fn unpacked_so_far(&self) -> usize {
        self.unpacked.get()
    }

    pub(crate) fn file_bytes(&self) -> usize {
        self.file_bytes
    }
}

pub(crate) fn refuse(reason: Refusal, detail: String) -> ApiError {
    ApiError::DocumentRefused { reason, detail }
}

/// **Why a document is being read** — paper 119, and the one argument that
/// makes the boundary of the next function nameable.
///
/// The owner's rule, 26 October 2026: «عندما لا يستطيع Z الوثوقَ بأمانة النصّ
/// المستخرج، لا يعرض نجاحَ الحماية كأن النصّ قُرئ صحيحاً» — when Z cannot trust
/// that the extracted text is what was written, it does not present a
/// successful protection as though the text had been read correctly.
///
/// That rule is about **protection**, so the check belongs to the road that
/// ends in a bench and not to reading a file back into its own names: the
/// z-pdf door scans nothing, protects nothing and sends nothing, and a file it
/// cannot read faithfully is a reading a person can see is wrong, not a secret
/// slipping out in text nobody checked. So the two roads say which they are,
/// **here, at the call**, and a third road has to choose — which is the whole
/// reason this is an argument and not a flag somebody could forget to pass.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum WhatFor {
    /// The text will be scanned, protected, and may leave this machine.
    Protecting,
    /// The text is being read back into the names it already carries — the
    /// z-pdf door (`ops::read_a_document_that_came_back`).
    ReadingItBack,
}

/// **How much of a document's Arabic may be written in the display blocks** —
/// paper 119, and both numbers below are measurements rather than opinions.
///
/// Unicode's Arabic Presentation Forms (`U+FB50–FDFF`, `U+FE70–FEFF`) are a
/// **compatibility** block: they exist so that text from older encodings can be
/// round-tripped, and nothing writes in them on purpose. A layout engine emits
/// them because it has already chosen each letter's shape — and an engine that
/// has chosen the shapes has also chosen the **order**, which is the order the
/// line is drawn in and not the order it was written in. That is why this share
/// is the signal: it does not say «this is Arabic» and it does not say «this is
/// right to left» — neither of those is a fault. It says the text we are
/// holding came out of a drawing, and a drawing's order is its own.
///
/// **Measured on the five fixtures of paper 118** (kept, with their numbers, at
/// `~/work-now/zprivacy-arabic-pdf-fixtures/`):
///
/// ```text
///     the letter as .txt                    934 Arabic chars ·   0 shaped ·  0%
///     the same letter, logical-order PDF    934 ·   0 ·  0%
///     the mixed Arabic/English/digits PDF    69 ·   0 ·  0%
///     the same letter, display-order PDF    934 · 897 · 96%
///     a page using «ﷺ» and a lam-alef       964 ·   2 ·  0%  (0.2%)
/// ```
///
/// So the two sides are **0.2% and 96%**, and a third of a page is a line
/// drawn through the empty space between them: it cannot be reached by the
/// handful of ligatures real Arabic writing does use — «ﷺ», a lam-alef — and it
/// is reached by every page that came out of a shaper.
const DISPLAY_FORM_SHARE: usize = 33;

/// **And a share means nothing over three letters.** A page holding one Arabic
/// word, and that word «ﷺ», is 100% display forms and perfectly honest. Eight
/// is the floor, measured the other way: a *reversed* Arabic name inside an
/// English letter — «Mr Tarek — ﻁﺍﺭﻕ ﺍﻝﺭﻱﺡﺍﻥﻱ» — carries fifteen, so the floor
/// has to sit well below that or the one shape this is most likely to meet in
/// the owner's post escapes it.
const ENOUGH_ARABIC_TO_JUDGE: usize = 8;

/// **The one check between a text and a bench** — paper 119.
///
/// **Two roads reach a bench, and both are closed with this one function.** The
/// first is a file (`extract` under [`WhatFor::Protecting`]); the second is the
/// box a person types or **pastes** into (`ops::import_text`, which reads its
/// text through `txt::extract` and never through `extract`). The second had to
/// be closed in the same breath as the first, and the measurement says why: the
/// refusal below tells a person their document was read backwards, and the
/// shortest thing they can then do is open it in a viewer and paste the text —
/// which is the same reversed text, arriving by the one road nothing checked.
/// Closing one road and advertising the other would have been worse than
/// closing neither.
///
/// Typed Arabic is never touched by it: a keyboard writes `U+06xx`, and the
/// display blocks are what a **drawing** is made of.
///
/// What it refuses is
/// not «Arabic» and not «right to left»: it is a document whose letters are the
/// shapes a layout engine chose, which means the order we extracted is the
/// order of the drawing. Measured on the owner's own kind of letter: the digits
/// come out reversed («2026-04471» as «17440-6202»), an e-mail address comes
/// out as «as.iramola-batkam@iramola.fesuoy» — **and was protected**, so a
/// token stood for a string nobody wrote while the real address was nowhere in
/// the text and could be neither protected nor restored. That false calm is the
/// thing this refusal exists to refuse.
pub(crate) fn the_order_cannot_be_trusted(text: &str) -> Option<u32> {
    let arabic = |c: char| {
        matches!(c,
            '\u{0600}'..='\u{06FF}' | '\u{0750}'..='\u{077F}' | '\u{08A0}'..='\u{08FF}'
            | '\u{FB50}'..='\u{FDFF}' | '\u{FE70}'..='\u{FEFF}')
    };
    let drawn = |c: char| matches!(c, '\u{FB50}'..='\u{FDFF}' | '\u{FE70}'..='\u{FEFF}');
    let total = text.chars().filter(|c| arabic(*c)).count();
    if total < ENOUGH_ARABIC_TO_JUDGE {
        return None;
    }
    let shaped = text.chars().filter(|c| drawn(*c)).count();
    let percent = shaped.saturating_mul(100) / total;
    (percent >= DISPLAY_FORM_SHARE).then_some(percent as u32)
}

/// **The refusal's own words, written once** — both roads say the same thing,
/// because it is the same fault and the same answer: a file saved as Word or as
/// plain text is read in the order it was written.
pub(crate) fn the_sentence(percent: u32) -> String {
    format!(
        "{percent}% of this text's Arabic is written in the display forms a layout engine \
         draws, so what was read is in the order it was drawn and not the order it was \
         written — the words and the digits come out reversed. It is refused rather than \
         half-read: a name read backwards cannot be protected, and protecting the reversal \
         would be worse than refusing it. A Word file or a plain-text file is read in the \
         order it was written"
    )
}

/// Read a document of `kind` from bytes. The only entry point.
pub(crate) fn extract(bytes: &[u8], kind: DocumentKind, what_for: WhatFor) -> ApiResult<Extracted> {
    if bytes.len() > limits::FILE_BYTES {
        return Err(refuse(
            Refusal::DocumentTooLarge {
                // **Never rounded down** — the independent attacker's ن16, 17
                // October: a file of 25 MiB **and one byte** was reported as
                // `mib: 25` against `limit_mib: 25`, which reads as a refusal
                // of a file that is exactly the size allowed. A division
                // towards zero is the wrong direction for a number whose whole
                // job is to say «past the limit», so this rounds up: the
                // figure may overstate by less than a megabyte and can never
                // understate.
                mib: bytes.len().div_ceil(1024 * 1024) as u32,
                limit_mib: (limits::FILE_BYTES / 1024 / 1024) as u32,
            },
            // And the detail carries the exact count, because it is read by
            // somebody looking for a cause and a rounded number there answers
            // a different question.
            format!(
                "{} bytes is past the {} MiB limit for one document ({} bytes)",
                bytes.len(),
                limits::FILE_BYTES / 1024 / 1024,
                limits::FILE_BYTES
            ),
        ));
    }
    if bytes.is_empty() {
        return Err(refuse(Refusal::EmptyDocument, "the file is empty".to_string()));
    }
    let budget = Budget::new(bytes.len());
    let extracted = match kind {
        DocumentKind::Txt => txt::extract(bytes, &budget),
        DocumentKind::Docx => docx::extract(bytes, &budget),
        DocumentKind::Pdf => pdf::extract(bytes, &budget),
    }?;
    if extracted.pages > limits::PAGES {
        return Err(refuse(
            Refusal::TooManyPages {
                pages: extracted.pages,
                limit: limits::PAGES,
            },
            format!("{} pages is past the limit of {}", extracted.pages, limits::PAGES),
        ));
    }
    // **The last thing before the text is handed over, and only on the road to
    // a bench** — paper 119. Here rather than inside `pdf::extract`, because
    // the rule is about what may be protected and the same reader serves the
    // door that only reads a file back.
    if what_for == WhatFor::Protecting {
        if let Some(percent) = the_order_cannot_be_trusted(&extracted.text) {
            return Err(refuse(
                Refusal::TextInDisplayForms { percent },
                the_sentence(percent),
            ));
        }
    }
    Ok(extracted)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_map_and_the_text_are_built_together() {
        let mut b = Builder::new();
        b.push("Kunde: Nordstern", 1, 1).expect("push");
        b.push_break("\n");
        b.push("Herr Thomas Müller", 17, 4).expect("push");
        let out = b.finish().expect("finish");

        assert_eq!(out.pages, 17);
        assert_eq!(out.place_of(0), Some(Place { page: 1, paragraph: 1 }));
        let at = out.text.find("Thomas").expect("the name is in the text");
        assert_eq!(out.place_of(at), Some(Place { page: 17, paragraph: 4 }));
        // The separator belongs to no page, and says so rather than lying.
        assert_eq!(out.place_of(out.text.find('\n').expect("break")), None);
    }

    #[test]
    fn a_document_with_no_text_is_refused_not_imported_empty() {
        let mut b = Builder::new();
        b.push("   \n  ", 1, 1).expect("push");
        match b.finish() {
            Err(ApiError::DocumentRefused { reason, .. }) => assert_eq!(reason, Refusal::EmptyDocument),
            other => panic!("expected a refusal, got {other:?}"),
        }
    }

    #[test]
    fn a_file_past_the_size_limit_is_refused_by_name() {
        // **One byte past it** — the independent attacker's own fixture (ن16).
        let big = vec![b'a'; limits::FILE_BYTES + 1];
        match extract(&big, DocumentKind::Txt, WhatFor::Protecting) {
            Err(ApiError::DocumentRefused { reason, detail }) => {
                let Refusal::DocumentTooLarge { mib, limit_mib } = reason else {
                    panic!("expected DocumentTooLarge, got {reason:?}")
                };
                assert_eq!(limit_mib, 25, "the limit this build applies is not the one it names");
                // **The figure may never understate.** It was a division
                // towards zero, so this file was reported as `mib: 25` against
                // `limit_mib: 25` — a refusal that reads as the refusal of a
                // file exactly the size allowed.
                assert!(
                    mib > limit_mib,
                    "a file past the limit is reported as {mib} MiB against a {limit_mib} MiB limit"
                );
                // And the detail carries the exact count, because it is read
                // by somebody looking for a cause.
                assert!(
                    detail.contains(&format!("{} bytes", limits::FILE_BYTES + 1)),
                    "{detail}"
                );
                assert!(detail.contains("limit"), "{detail}");
            }
            other => panic!("expected a refusal, got {other:?}"),
        }
    }

    #[test]
    fn text_that_swells_past_the_limit_is_refused_while_being_read() {
        let mut b = Builder::new();
        let chunk = "x".repeat(1024);
        let mut pushed = 0usize;
        loop {
            match b.push(&chunk, 1, 1) {
                Ok(()) => pushed += chunk.len(),
                Err(ApiError::DocumentRefused { reason, .. }) => {
                    assert!(matches!(reason, Refusal::TextTooLarge { .. }), "{reason:?}");
                    assert!(pushed <= limits::TEXT_BYTES);
                    return;
                }
                other => panic!("unexpected: {other:?}"),
            }
        }
    }
}

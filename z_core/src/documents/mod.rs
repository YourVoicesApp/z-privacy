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

use std::time::{Duration, Instant};

#[cfg(test)]
use crate::api::Place;
use crate::api::{ApiError, ApiResult, DocumentKind, Refusal};

/// Limits. Deliberately modest: a working document, not a library.
pub(crate) mod limits {
    /// The file itself.
    pub(crate) const FILE_BYTES: usize = 25 * 1024 * 1024;
    /// Pages in one document.
    pub(crate) const PAGES: u32 = 500;
    /// Text after decompression — the defence against a small file that swells.
    pub(crate) const TEXT_BYTES: usize = 4 * 1024 * 1024;
    /// One entry inside a zip, decompressed.
    pub(crate) const ZIP_ENTRY_BYTES: usize = 8 * 1024 * 1024;
    /// How long reading may take before we stop and say so.
    pub(crate) const MILLIS: u64 = 5_000;
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
                Refusal::TextTooLarge,
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
            pages: self.pages.max(1),
        })
    }
}

/// A clock and a size, checked while reading rather than after.
#[derive(Debug)]
pub(crate) struct Budget {
    started: Instant,
    limit: Duration,
}

impl Budget {
    pub(crate) fn new() -> Self {
        Self {
            started: Instant::now(),
            limit: Duration::from_millis(limits::MILLIS),
        }
    }

    pub(crate) fn check(&self) -> ApiResult<()> {
        if self.started.elapsed() > self.limit {
            return Err(refuse(
                Refusal::TookTooLong,
                format!("reading this document passed {} ms", limits::MILLIS),
            ));
        }
        Ok(())
    }
}

pub(crate) fn refuse(reason: Refusal, detail: String) -> ApiError {
    ApiError::DocumentRefused { reason, detail }
}

/// Read a document of `kind` from bytes. The only entry point.
pub(crate) fn extract(bytes: &[u8], kind: DocumentKind) -> ApiResult<Extracted> {
    if bytes.len() > limits::FILE_BYTES {
        return Err(refuse(
            Refusal::DocumentTooLarge,
            format!(
                "{} MiB is past the {} MiB limit for one document",
                bytes.len() / 1024 / 1024,
                limits::FILE_BYTES / 1024 / 1024
            ),
        ));
    }
    if bytes.is_empty() {
        return Err(refuse(Refusal::EmptyDocument, "the file is empty".to_string()));
    }
    let budget = Budget::new();
    let extracted = match kind {
        DocumentKind::Txt => txt::extract(bytes, &budget),
        DocumentKind::Docx => docx::extract(bytes, &budget),
        DocumentKind::Pdf => pdf::extract(bytes, &budget),
    }?;
    if extracted.pages > limits::PAGES {
        return Err(refuse(
            Refusal::TooManyPages,
            format!("{} pages is past the limit of {}", extracted.pages, limits::PAGES),
        ));
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
        let big = vec![b'a'; limits::FILE_BYTES + 1];
        match extract(&big, DocumentKind::Txt) {
            Err(ApiError::DocumentRefused { reason, detail }) => {
                assert_eq!(reason, Refusal::DocumentTooLarge);
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
                    assert_eq!(reason, Refusal::TextTooLarge);
                    assert!(pushed <= limits::TEXT_BYTES);
                    return;
                }
                other => panic!("unexpected: {other:?}"),
            }
        }
    }
}

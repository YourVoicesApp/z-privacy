// **What is cut is not read, and what is not read is not protected.**
//
// The independent attacker's B3, 17 October, on the lead's own line: a PDF
// whose Flate content stream inflates to 9 MiB was **imported** — one page,
// seventeen characters, «100% readable» — because the reader stopped the
// inflation at 8 MiB and handed back what it had. The marker the attacker put
// after the eighth megabyte was simply gone. A document read to its middle and
// called whole is the worst of the three outcomes: worse than a refusal, worse
// than a crash, because a name we never saw is a name we never protect, and
// the screen said the file was fine.
//
// Beside it, three more of the same family:
//
// * a page stream of 256 KiB of zeros, 946× its compressed size, was refused —
//   correctly — but **named a scan**: «all 1 pages are images with no text
//   layer». The refusal was right and the sentence was false;
// * twelve object streams of 4 MiB each, a 49 KiB file, were unpacked and kept:
//   75 MiB of memory for a file the size of a photograph;
// * and the limits the library sealed in V1-J — 8 MiB a stream, 200× a stream,
//   a ceiling for the whole document — reached the PDF reader at none of its
//   four doors: a page's content, a form, a font's `/ToUnicode`, an object
//   stream.
//
// So every Flate stream this reader opens now passes **one hand** and **one
// budget**, whatever its role, the stop happens *while* it inflates, and
// passing a limit is a refusal **by its own name**. What this file asserts is
// each limit biting on the shape that crossed it — and, just as much, that the
// shapes a real file has are read exactly as they were: an object stream is
// budgeted, never refused for being one, and so is a compressed
// cross-reference.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::io::Write;

use flate2::write::ZlibEncoder;
use flate2::Compression;

use z_core::api::*;

// ------------------------------------------------------------ the builders
//
// Written by hand, as bytes: a stream is bytes, and a compressed one holds
// every value a byte can take — laying one out through a `String` is how a
// fixture stops being the thing it was meant to measure.

fn deflate(raw: &[u8], level: Compression) -> Vec<u8> {
    let mut encoder = ZlibEncoder::new(Vec::new(), level);
    encoder.write_all(raw).expect("deflate the fixture");
    encoder.finish().expect("finish the fixture")
}

/// A PDF written object by object, in the order given.
#[derive(Default)]
struct Pdf {
    out: Vec<u8>,
}

impl Pdf {
    fn new() -> Self {
        Self { out: b"%PDF-1.5\n".to_vec() }
    }

    fn obj(mut self, number: u32, dict: &str, stream: Option<&[u8]>) -> Self {
        self.out.extend_from_slice(format!("{number} 0 obj\n<< {dict}").as_bytes());
        match stream {
            Some(raw) => {
                self.out
                    .extend_from_slice(format!(" /Length {} >>\nstream\n", raw.len()).as_bytes());
                self.out.extend_from_slice(raw);
                self.out.extend_from_slice(b"\nendstream\nendobj\n");
            }
            None => self.out.extend_from_slice(b" >>\nendobj\n"),
        }
        self
    }

    fn finish(mut self) -> Vec<u8> {
        self.out.extend_from_slice(b"trailer\n<< /Root 1 0 R >>\n%%EOF\n");
        self.out
    }
}

/// The skeleton every fixture here shares: a catalogue, one page, a font.
fn one_page(page_dict: &str) -> Pdf {
    Pdf::new()
        .obj(1, "/Type /Catalog /Pages 2 0 R", None)
        .obj(2, "/Type /Pages /Count 1 /Kids [3 0 R]", None)
        .obj(3, page_dict, None)
        .obj(100, "/Type /Font /Subtype /Type1 /BaseFont /Helvetica", None)
}

fn says(marker: &str) -> Vec<u8> {
    format!("BT /F1 12 Tf 72 700 Td ({marker}) Tj ET\n").into_bytes()
}

/// A stream that inflates to `mib` megabytes and swells enormously doing it.
fn a_swelling_stream(marker: &str, mib: usize, tail: &str) -> Vec<u8> {
    let mut plain = says(marker);
    plain.extend(std::iter::repeat_n(b'A', mib * 1024 * 1024));
    plain.extend_from_slice(&says(tail));
    plain
}

/// A stream that inflates to about `mib` megabytes while swelling by about
/// ninety — under the 200 one stream may, over the thirty-two the whole
/// document may, so that only the document's own ceiling can stop it.
fn a_stream_that_swells_but_little(marker: &str, mib: usize) -> Vec<u8> {
    let mut plain = says(marker);
    let mut seed = 0x2545_f491_4f6c_dd1du64;
    while plain.len() < mib * 1024 * 1024 {
        // Thirty-two bytes nothing can pack, then a run that packs to nothing.
        for _ in 0..32 {
            seed = seed.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
            plain.push((seed >> 33) as u8);
        }
        plain.extend(std::iter::repeat_n(b'A', 4064));
    }
    plain
}

fn read(bytes: Vec<u8>) -> ApiResult<DocumentView> {
    let session = open_session(None, "de".to_string()).expect("a session");
    let out = import_document(session, "fixture.pdf".to_string(), bytes, DocumentKind::Pdf);
    close_session(session).ok();
    out
}

fn refusal_of(out: ApiResult<DocumentView>, what: &str) -> (Refusal, String) {
    match out {
        Err(ApiError::DocumentRefused { reason, detail }) => (reason, detail),
        Err(other) => panic!("{what} was refused with the wrong kind of answer: {other:?}"),
        Ok(view) => panic!(
            "{what} was imported: {} pages, {} characters — a document that was cut is not a document that was read",
            view.pages,
            view.text.chars().count()
        ),
    }
}

// ------------------------------------------------------------ one stream

#[test]
fn the_attackers_own_nine_megabyte_stream_is_refused_and_its_tail_never_imported() {
    // His fixture, byte for byte in shape: `START_MARKER_B3`, nine megabytes,
    // `END_MARKER_B3` after the eighth. It imported as one page of seventeen
    // characters — the start marker and nothing else — and said «100%
    // readable». It is both too big for one stream and a bomb by its swell,
    // and either name is the truth; what may never happen again is the import.
    let plain = a_swelling_stream("START_MARKER", 9, "END_MARKER");
    let bytes = one_page("/Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 100 0 R >> >>")
        .obj(4, "/Filter /FlateDecode", Some(&deflate(&plain, Compression::best())))
        .finish();
    assert!(bytes.len() < 64 * 1024, "the fixture is a small file: {} bytes", bytes.len());

    let (reason, _) = refusal_of(read(bytes), "a stream that inflates to 9 MiB");
    assert!(
        matches!(
            reason,
            Refusal::TextTooLarge { .. } | Refusal::CompressionBomb { .. }
        ),
        "nine megabytes in nine kilobytes is refused by one of the two rules, not by neither: {reason:?}"
    );
}

#[test]
fn a_page_stream_past_eight_mib_is_refused_by_name_and_not_cut() {
    // The same fault with the swell taken out of it, so that the per-stream
    // limit is the one rule left to bite: nine megabytes written in about a
    // hundred kilobytes, a swell of ninety, under the 200 a stream may.
    let plain = a_stream_that_swells_but_little("START_MARKER", 9);
    let packed = deflate(&plain, Compression::fast());
    let swell = plain.len() / packed.len().max(1);
    assert!(swell < 200, "the fixture must not be stopped by the swell rule: {swell}×");
    let bytes = one_page("/Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 100 0 R >> >>")
        .obj(4, "/Filter /FlateDecode", Some(&packed))
        .finish();

    let (reason, detail) = refusal_of(read(bytes), "a stream that inflates to 9 MiB");
    assert_eq!(reason, Refusal::TextTooLarge { limit_mib: 8 });
    assert!(detail.contains('8'), "the refusal does not say the limit it hit: {detail}");
}

#[test]
fn a_stream_that_swells_past_two_hundred_times_is_a_bomb_and_never_a_scan() {
    // The attacker's own shape: 256 KiB of zeros, 946× the bytes it is written
    // in. It is not a picture of a page, and the screen may not say it is.
    let plain = vec![0u8; 256 * 1024];
    let bytes = one_page("/Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 100 0 R >> >>")
        .obj(4, "/Filter /FlateDecode", Some(&deflate(&plain, Compression::best())))
        .finish();

    let (reason, detail) = refusal_of(read(bytes), "a stream of 256 KiB of zeros");
    match reason {
        Refusal::CompressionBomb { ratio } => {
            assert!(ratio > 200, "the ratio in the refusal is the one measured: {ratio}")
        }
        other => panic!("a compression bomb was refused as {other:?}"),
    }
    assert!(
        !detail.contains("scan") && !detail.contains("image"),
        "the refusal calls a bomb a scanned page: {detail}"
    );
}

#[test]
fn an_object_stream_that_swells_is_stopped_by_the_same_rule() {
    // Twelve object streams of 4 MiB each in a file of 50 KiB: accepted before
    // this round, and 75 MiB of memory for it.
    let payload = {
        let mut plain = b"1000 0 ".to_vec();
        plain.extend(std::iter::repeat_n(b'A', 4 * 1024 * 1024));
        plain
    };
    let packed = deflate(&payload, Compression::best());
    let mut pdf = one_page(
        "/Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 100 0 R >> >>",
    )
    .obj(4, "", Some(&says("PAGE_MARKER")));
    for i in 0..12u32 {
        pdf = pdf.obj(
            200 + i,
            "/Type /ObjStm /N 1 /First 7 /Filter /FlateDecode",
            Some(&packed),
        );
    }

    let (reason, _) = refusal_of(read(pdf.finish()), "twelve object streams of 4 MiB");
    assert!(
        matches!(reason, Refusal::CompressionBomb { .. }),
        "an object stream that swells is not stopped: {reason:?}"
    );
}

#[test]
fn a_fonts_character_map_passes_the_same_budget() {
    // A `/ToUnicode` map is a stream like any other, and it is read before a
    // single character of the page is believed.
    let plain = a_swelling_stream("CMAP_MARKER", 9, "CMAP_TAIL");
    let bytes = one_page("/Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 101 0 R >> >>")
        .obj(4, "", Some(&says("PAGE_MARKER")))
        .obj(101, "/Type /Font /Subtype /Type0 /BaseFont /X /Encoding /Identity-H /ToUnicode 102 0 R", None)
        .obj(102, "/Filter /FlateDecode", Some(&deflate(&plain, Compression::best())))
        .finish();

    let (reason, _) = refusal_of(read(bytes), "a /ToUnicode map of 9 MiB");
    assert!(
        matches!(
            reason,
            Refusal::TextTooLarge { .. } | Refusal::CompressionBomb { .. }
        ),
        "a font's map is read outside the budget: {reason:?}"
    );
}

#[test]
fn a_form_drawn_on_the_page_passes_the_same_budget() {
    let plain = a_swelling_stream("FORM_MARKER", 9, "FORM_TAIL");
    let mut content = says("PAGE_MARKER");
    content.extend_from_slice(b"/Fm0 Do\n");
    let bytes = one_page(
        "/Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 100 0 R >> /XObject << /Fm0 103 0 R >> >>",
    )
    .obj(4, "", Some(&content))
    .obj(103, "/Type /XObject /Subtype /Form /Filter /FlateDecode", Some(&deflate(&plain, Compression::best())))
    .finish();

    let (reason, _) = refusal_of(read(bytes), "a form of 9 MiB");
    assert!(
        matches!(
            reason,
            Refusal::TextTooLarge { .. } | Refusal::CompressionBomb { .. }
        ),
        "a form is read outside the budget: {reason:?}"
    );
}

// ------------------------------------------------------------ one document

#[test]
fn nine_pages_may_not_spend_the_documents_budget_one_page_at_a_time() {
    // Every stream here is inside both of the rules above — about 2 MiB each,
    // swelling about ninetyfold — so only the document's own ceiling can stop
    // the nine of them together. This is the half of the law the per-stream
    // limit cannot see, and the shape the attacker named
    // «pdf_flate_cumul_16mib».
    let pages = 9u32;
    let plain = a_stream_that_swells_but_little("PAGE_MARKER", 2);
    let packed = deflate(&plain, Compression::fast());
    let swell = plain.len() / packed.len().max(1);
    assert!(
        (33..200).contains(&swell),
        "the fixture must swell more than the document allows and less than one stream may: {swell}×"
    );
    assert!(plain.len() < 8 * 1024 * 1024, "each stream is inside the per-stream limit");

    let kids: Vec<String> = (0..pages).map(|i| format!("{} 0 R", 10 + i)).collect();
    let mut pdf = Pdf::new()
        .obj(1, "/Type /Catalog /Pages 2 0 R", None)
        .obj(
            2,
            &format!("/Type /Pages /Count {pages} /Kids [{}]", kids.join(" ")),
            None,
        )
        .obj(100, "/Type /Font /Subtype /Type1 /BaseFont /Helvetica", None);
    for i in 0..pages {
        pdf = pdf
            .obj(
                10 + i,
                &format!("/Type /Page /Parent 2 0 R /Contents {} 0 R /Resources << /Font << /F1 100 0 R >> >>", 30 + i),
                None,
            )
            .obj(30 + i, "/Filter /FlateDecode", Some(&packed));
    }
    let bytes = pdf.finish();

    let (reason, detail) = refusal_of(read(bytes), "nine pages of 2 MiB each");
    assert!(
        matches!(reason, Refusal::CompressionBomb { .. }),
        "the document's own ceiling never bit: {reason:?}"
    );
    assert!(
        detail.contains("in all"),
        "the refusal does not say it was the document and not one stream: {detail}"
    );
}

#[test]
fn one_page_may_not_hold_more_content_than_one_stream_may() {
    // The same stored stream, named twenty times in one page's /Contents. No
    // byte of it is compressed, so no Flate rule can see it — and the page
    // would be read as 20 MiB of content out of a 1 MiB file.
    let mut plain = says("PAGE_MARKER");
    plain.extend(std::iter::repeat_n(b' ', 1024 * 1024));
    let refs: Vec<String> = std::iter::repeat_n("4 0 R".to_string(), 20).collect();
    let bytes = one_page(&format!(
        "/Type /Page /Parent 2 0 R /Contents [{}] /Resources << /Font << /F1 100 0 R >> >>",
        refs.join(" ")
    ))
    .obj(4, "", Some(&plain))
    .finish();

    let (reason, _) = refusal_of(read(bytes), "one page naming the same 1 MiB stream twenty times");
    assert!(
        matches!(reason, Refusal::TextTooLarge { .. }),
        "a page's content is unbounded: {reason:?}"
    );
}

// ------------------------------------------------- and what must still read

#[test]
fn an_object_stream_is_budgeted_and_not_refused_for_being_one() {
    // The library refuses every object stream before it loads one, and may:
    // nothing it reads is a Word file. This reader must read them — the page
    // tree of seven Swedish e-documents on this machine is packed in one — so
    // the budget is what holds them, not a refusal.
    let inner = b"<< /Type /Pages /Count 1 /Kids [3 0 R] >> << /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 100 0 R >> >> >>";
    let header = b"2 0 3 41 ";
    let mut payload = header.to_vec();
    payload.extend_from_slice(inner);
    let bytes = Pdf::new()
        .obj(1, "/Type /Catalog /Pages 2 0 R", None)
        .obj(
            10,
            &format!("/Type /ObjStm /N 2 /First {} /Filter /FlateDecode", header.len()),
            Some(&deflate(&payload, Compression::best())),
        )
        .obj(4, "", Some(&says("PACKED_PAGE")))
        .obj(100, "/Type /Font /Subtype /Type1 /BaseFont /Helvetica", None)
        .finish();

    let view = read(bytes).expect("a page packed in an object stream is still a page");
    assert!(
        view.text.contains("PACKED_PAGE"),
        "the packed page tree was not followed: {} characters",
        view.text.chars().count()
    );
}

#[test]
fn a_compressed_cross_reference_does_not_refuse_the_file() {
    // Word and Google both write one. This reader scans objects and never
    // follows the cross-reference, so the stream is simply never opened — and
    // that is still the answer a real file needs: read, not refused.
    let xref = deflate(&vec![0u8; 4096], Compression::best());
    let bytes = one_page("/Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 100 0 R >> >>")
        .obj(4, "", Some(&says("PLAIN_PAGE")))
        .obj(9, "/Type /XRef /W [1 2 1] /Size 10 /Filter /FlateDecode", Some(&xref))
        .finish();

    let view = read(bytes).expect("a compressed cross-reference is not a reason to refuse");
    assert!(view.text.contains("PLAIN_PAGE"), "the page beside the xref stream was lost");
}

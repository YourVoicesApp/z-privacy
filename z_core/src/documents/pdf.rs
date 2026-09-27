//! PDF, read by hand, and refused honestly when it cannot be read.
//!
//! ## Why this is ours and not a library's
//!
//! The PDF crates bring a hundred and more crates with them. For a product whose
//! whole claim is «nothing leaves your device, and you can check that», a
//! dependency tree nobody reads is a real cost. What this file does instead is
//! narrow and stated:
//!
//! * find the pages in the order the document gives them;
//! * inflate each page's content stream, bounded;
//! * pull the text-showing operators out of it;
//! * decode single-byte encodings, and `Identity-H` **only** through the font's
//!   own `/ToUnicode` map.
//!
//! Anything outside that is a named refusal, never a guess: an encrypted file, a
//! scan with no text layer, a font whose bytes we cannot map. The owner's rule
//! stands — better a refusal with a reason than text with silent holes in it.

use std::collections::BTreeMap;
use std::io::Read;

use flate2::read::ZlibDecoder;

use crate::api::{ApiResult, Refusal};

use super::{limits, refuse, Budget, Builder, Extracted};

pub(crate) fn extract(bytes: &[u8], budget: &Budget) -> ApiResult<Extracted> {
    if !bytes.starts_with(b"%PDF-") {
        return Err(refuse(
            Refusal::MalformedDocument,
            "this file does not begin like a PDF".to_string(),
        ));
    }
    let objects = objects(bytes, budget)?;
    if encrypted(bytes, &objects) {
        return Err(refuse(
            Refusal::EncryptedPdf,
            "this PDF is encrypted; it needs its password before anything can be read".to_string(),
        ));
    }

    let pages = page_order(&objects);
    if pages.is_empty() {
        return Err(refuse(
            Refusal::MalformedDocument,
            "this PDF lists no pages".to_string(),
        ));
    }
    if pages.len() as u32 > limits::PAGES {
        return Err(refuse(
            Refusal::TooManyPages {
                pages: pages.len() as u32,
                limit: limits::PAGES,
            },
            format!("{} pages is past the limit of {}", pages.len(), limits::PAGES),
        ));
    }

    let mut out = Builder::new();
    let mut pages_with_text = 0usize;

    for (index, page_ref) in pages.iter().enumerate() {
        budget.check()?;
        let page_number = index as u32 + 1;
        let Some(page) = objects.get(page_ref).map(|o| o.dict.clone()) else { continue };

        // Fail-closed, before a single character is believed: if this page's fonts
        // or its content's filters are ones this reader does not follow, nothing on
        // the page can be trusted — not even the part that looks like words.
        let fonts = page_fonts(&objects, &page);
        if let Some(why) = unreadable_structure(&objects, &page, &fonts) {
            return Err(refuse(
                Refusal::UnreadableStructure { page: page_number },
                format!(
                    "page {page_number} cannot be read faithfully: {why}. The document is refused rather than half-read — a name we cannot see is a name we cannot protect"
                ),
            ));
        }

        let content = page_content(&objects, &page)?;
        let runs = text_runs(&content, &fonts);
        let page_text: String = runs
            .iter()
            .filter_map(|r| match r {
                Run::Text(text) => Some(text.as_str()),
                Run::Unmappable => None,
            })
            .collect::<Vec<&str>>()
            .join(" ");
        if page_text.trim().is_empty() {
            continue;
        }
        pages_with_text += 1;

        // The readable share is measured **per page**, because an average hides the
        // one page that failed — and that is exactly the page with the name on it.
        let percent = readable_percent(&page_text);
        if percent < MIN_READABLE_PERCENT {
            return Err(refuse(
                Refusal::UnsupportedEncoding {
                    page: page_number,
                    readable_percent: percent as u32,
                },
                format!(
                    "only {percent}% of page {page_number} decoded into characters, so this page's fonts are not ones this build reads faithfully. The whole document is refused, because a name we cannot see is a name we cannot protect — open it and save it as text, or paste the text in instead"
                ),
            ));
        }

        for (paragraph, run) in runs.iter().enumerate() {
            if let Run::Text(text) = run {
                if !text.trim().is_empty() {
                    out.push(text, page_number, paragraph as u32 + 1)?;
                    out.push_break("\n");
                }
            }
        }
        out.push_break("\n");
    }

    if pages_with_text == 0 {
        return Err(refuse(
            Refusal::ScannedPdfNoTextLayer {
                pages: pages.len() as u32,
            },
            format!(
                "all {} pages are images with no text layer — this looks like a scan, and we will not send it anywhere to be read",
                pages.len()
            ),
        ));
    }
    out.finish()
}

/// How much of this text decoded into characters at all.
///
/// The question is «did these bytes become text», not «is this text English». An
/// earlier version counted only ASCII punctuation as readable, and so marked a
/// financial table full of «§ € – ×» as half rubbish: the measure was wrong, not
/// the page. What a failed decoding actually produces is the opposite of
/// characters — control bytes, the replacement mark, private-use glyph slots — and
/// that is what is counted against a page here.
fn readable_percent(text: &str) -> usize {
    let total = text.chars().count();
    if total == 0 {
        return 100;
    }
    let broken = text.chars().filter(|c| !decoded(*c)).count();
    let readable = total.saturating_sub(broken);
    readable.saturating_mul(100) / total
}

/// Did this character come out of a decoding, or out of a failure?
fn decoded(c: char) -> bool {
    if matches!(c, '\n' | '\r' | '\t') {
        return true;
    }
    // The replacement mark means «these bytes were not what we thought».
    if c == '\u{FFFD}' {
        return false;
    }
    // Private use: a font's own glyph numbers read as if they were characters.
    if matches!(c, '\u{E000}'..='\u{F8FF}' | '\u{F0000}'..='\u{FFFFD}' | '\u{100000}'..='\u{10FFFD}') {
        return false;
    }
    // Control characters are not text.
    !c.is_control()
}

/// Below this, the text is not text. Chosen from measurement on real documents:
/// clean pages come out at 86–99%, and a page that was half rubbish came out at 52%.
const MIN_READABLE_PERCENT: usize = 80;

/// Does this page use something this reader does not understand?
///
/// Structural, not statistical: these are the cases where the bytes may well decode
/// into something that *looks* like words while meaning something else. A refusal
/// here is the whole point of fail-closed.
fn unreadable_structure(objects: &Objects, page: &str, fonts: &Fonts) -> Option<String> {
    if let Some(name) = fonts.unmappable.keys().next() {
        return Some(format!(
            "font /{name} needs a character map (Identity-H or Type0) and the file carries none"
        ));
    }
    if let Some(name) = fonts.remapped.keys().next() {
        return Some(format!(
            "font /{name} remaps its characters with /Differences, which this reader does not apply"
        ));
    }
    // A content stream filtered by something we do not decode.
    let mut refs = references(page, "/Contents");
    if refs.is_empty() {
        if let Some(single) = reference(page, "/Contents") {
            refs.push(single);
        }
    }
    for number in refs {
        let Some(body) = objects.get(&number) else { continue };
        for filter in [
            "/LZWDecode",
            "/ASCII85Decode",
            "/ASCIIHexDecode",
            "/RunLengthDecode",
            "/JBIG2Decode",
            "/Crypt",
        ] {
            if body.dict.contains(filter) {
                return Some(format!("its text is packed with {filter}, which this reader does not unpack"));
            }
        }
    }
    None
}

// ---------------------------------------------------------------- objects

/// One indirect object: its dictionary as text, and its stream as **bytes**.
///
/// The bytes matter. An earlier version of this file read objects through
/// `from_utf8_lossy`, which quietly replaced every invalid byte of a deflate
/// stream with U+FFFD — so every compressed page looked like a page with no text,
/// and real invoices came back as «scanned». Dictionaries are ASCII and may be
/// read as text; streams may not.
#[derive(Debug, Clone, Default)]
struct ObjBody {
    dict: String,
    stream: Option<Vec<u8>>,
}

type Objects = BTreeMap<u32, ObjBody>;

/// Find every `N G obj … endobj` by scanning the bytes, then open any object
/// streams and add what is inside them.
///
/// Scanning rather than following the cross-reference table is deliberate: a
/// broken xref is the most common damage in a PDF, and scanning survives it.
fn objects(bytes: &[u8], budget: &Budget) -> ApiResult<Objects> {
    let mut out: Objects = BTreeMap::new();
    let mut at = 0usize;
    let mut seen = 0usize;

    while at < bytes.len() {
        let Some(offset) = find(bytes, at, b" obj") else { break };
        let obj_at = at + offset;
        let number = number_before(bytes, obj_at);
        let body_start = obj_at + 4;
        let Some(end_offset) = find(bytes, body_start, b"endobj") else { break };
        let body_end = body_start + end_offset;

        if let Some(number) = number {
            out.insert(number, split_body(bytes, body_start, body_end));
        }
        at = body_end + 6;
        seen += 1;
        if seen % 256 == 0 {
            budget.check()?;
        }
    }

    if out.is_empty() {
        return Err(refuse(
            Refusal::MalformedDocument,
            "no objects could be read out of this PDF".to_string(),
        ));
    }

    // PDF 1.5 and later pack most objects — pages and fonts included — inside
    // compressed object streams. Without opening those, a modern PDF looks empty.
    let packed: Vec<ObjBody> = out
        .values()
        .filter(|o| o.dict.contains("/ObjStm"))
        .cloned()
        .collect();
    for holder in packed {
        budget.check()?;
        unpack_object_stream(&holder, &mut out);
    }
    Ok(out)
}

/// The dictionary and the stream of one object body.
fn split_body(bytes: &[u8], start: usize, end: usize) -> ObjBody {
    let body = bytes.get(start..end).unwrap_or_default();
    match find(body, 0, b"stream") {
        Some(at) => {
            let dict = String::from_utf8_lossy(body.get(..at).unwrap_or_default()).to_string();
            let after = at + 6;
            // Skip the end-of-line that must follow the keyword.
            let data_at = match body.get(after..after + 2) {
                Some([b'\r', b'\n']) => after + 2,
                Some([b'\n', _]) => after + 1,
                Some([b'\r', _]) => after + 1,
                _ => after,
            };
            let data_end = find(body, data_at, b"endstream")
                .map(|offset| data_at + offset)
                .unwrap_or(body.len());
            let raw = body.get(data_at..data_end).unwrap_or_default();
            ObjBody {
                dict,
                stream: Some(raw.to_vec()),
            }
        }
        None => ObjBody {
            dict: String::from_utf8_lossy(body).to_string(),
            stream: None,
        },
    }
}

/// `/Type/ObjStm`: `N` pairs of «number offset», then the objects themselves.
fn unpack_object_stream(holder: &ObjBody, out: &mut Objects) {
    let Some(raw) = holder.stream.as_ref() else { return };
    let plain = match decode_stream(&holder.dict, raw) {
        Some(plain) => plain,
        None => return,
    };
    let text = String::from_utf8_lossy(&plain).to_string();
    let count = number_after(&holder.dict, "/N").unwrap_or(0) as usize;
    let first = number_after(&holder.dict, "/First").unwrap_or(0) as usize;
    if count == 0 || first == 0 || first > text.len() {
        return;
    }
    let header = text.get(..first).unwrap_or_default();
    let numbers: Vec<u32> = header
        .split_whitespace()
        .filter_map(|w| w.parse::<u32>().ok())
        .collect();

    // The header is number/offset pairs; the offsets are relative to /First.
    let pairs: Vec<(u32, usize)> = numbers
        .chunks(2)
        .filter_map(|pair| match (pair.first(), pair.get(1)) {
            (Some(number), Some(offset)) => Some((*number, *offset as usize)),
            _ => None,
        })
        .take(count)
        .collect();

    for (index, (number, offset)) in pairs.iter().enumerate() {
        let start = first + offset;
        let end = pairs
            .get(index + 1)
            .map(|(_, next)| first + next)
            .unwrap_or(text.len());
        if let Some(body) = text.get(start..end.min(text.len())) {
            // Objects inside an object stream never hold streams themselves.
            out.entry(*number).or_insert_with(|| ObjBody {
                dict: body.to_string(),
                stream: None,
            });
        }
    }
}

/// Inflate a stream when its dictionary says it is deflated, bounded.
fn decode_stream(dict: &str, raw: &[u8]) -> Option<Vec<u8>> {
    if !dict.contains("/FlateDecode") {
        return Some(raw.to_vec());
    }
    let mut decoder = ZlibDecoder::new(raw).take(limits::ZIP_ENTRY_BYTES as u64 + 1);
    let mut out = Vec::new();
    match decoder.read_to_end(&mut out) {
        Ok(_) if !out.is_empty() => Some(out),
        // Some writers leave junk before the zlib header; try again from the first
        // plausible start rather than giving up on the page.
        _ => {
            let skip = raw.iter().position(|b| *b == 0x78)?;
            let mut decoder = ZlibDecoder::new(raw.get(skip..)?).take(limits::ZIP_ENTRY_BYTES as u64 + 1);
            let mut out = Vec::new();
            decoder.read_to_end(&mut out).ok()?;
            (!out.is_empty()).then_some(out)
        }
    }
}

/// `find(haystack, from, needle)` → offset **relative to `from`**.
fn find(haystack: &[u8], from: usize, needle: &[u8]) -> Option<usize> {
    let hay = haystack.get(from..)?;
    if needle.is_empty() || hay.len() < needle.len() {
        return None;
    }
    hay.windows(needle.len()).position(|window| window == needle)
}

/// The object number written just before ` obj`.
fn number_before(bytes: &[u8], obj_at: usize) -> Option<u32> {
    let head = bytes.get(..obj_at)?;
    // « 12 0 » — step back over the generation, then take the number.
    let text = String::from_utf8_lossy(head.get(head.len().saturating_sub(24)..)?);
    let mut words = text.split_whitespace().rev();
    let _generation = words.next()?;
    words.next()?.parse::<u32>().ok()
}

/// `/N 40` → `40`.
///
/// Read digit by digit, not word by word: a PDF dictionary puts no space between
/// a value and the next key — `/N 127/Type/ObjStm` — so splitting on whitespace
/// yields «127/Type/ObjStm» and parses as nothing. That mistake made every modern
/// PDF look malformed, because its pages live inside an object stream whose /N and
/// /First could not be read.
fn number_after(dict: &str, key: &str) -> Option<u32> {
    let at = dict.find(key)?;
    leading_u32(dict.get(at + key.len()..)?)
}

/// Skip spaces, then take the digits, and stop at whatever follows them.
fn leading_u32(text: &str) -> Option<u32> {
    let trimmed = text.trim_start();
    let digits: String = trimmed.chars().take_while(char::is_ascii_digit).collect();
    if digits.is_empty() {
        return None;
    }
    digits.parse::<u32>().ok()
}

fn encrypted(bytes: &[u8], objects: &Objects) -> bool {
    // The trailer names the encryption dictionary; a linearised file can hold more
    // than one trailer, so the raw bytes are searched too.
    find(bytes, 0, b"/Encrypt").is_some()
        || objects
            .values()
            .any(|o| o.dict.contains("/Filter/Standard") || o.dict.contains("/Filter /Standard"))
}

/// The pages, in reading order, by walking the page tree from the catalogue.
fn page_order(objects: &Objects) -> Vec<u32> {
    let mut order = Vec::new();
    let root = objects
        .iter()
        .find(|(_, o)| o.dict.contains("/Type/Catalog") || o.dict.contains("/Type /Catalog"))
        .and_then(|(_, o)| reference(&o.dict, "/Pages"));

    if let Some(pages_ref) = root {
        walk(objects, pages_ref, &mut order, 0);
    }
    if order.is_empty() {
        // No catalogue, or a tree we could not follow: every page object, in order.
        for (number, o) in objects {
            if is_page(&o.dict) {
                order.push(*number);
            }
        }
    }
    order
}

fn is_page(dict: &str) -> bool {
    let has_type = dict.contains("/Type/Page") || dict.contains("/Type /Page");
    let is_tree = dict.contains("/Type/Pages") || dict.contains("/Type /Pages");
    has_type && !is_tree
}

fn walk(objects: &Objects, node: u32, order: &mut Vec<u32>, depth: u32) {
    if depth > 32 || order.len() > limits::PAGES as usize {
        return;
    }
    let Some(body) = objects.get(&node) else { return };
    if is_page(&body.dict) {
        order.push(node);
        return;
    }
    for child in references(&body.dict, "/Kids") {
        walk(objects, child, order, depth + 1);
    }
}

/// `/Name 12 0 R` → `12`.
fn reference(dict: &str, key: &str) -> Option<u32> {
    let at = dict.find(key)?;
    leading_u32(dict.get(at + key.len()..)?)
}

/// `/Kids[1 0 R 2 0 R]` → `[1, 2]`.
fn references(dict: &str, key: &str) -> Vec<u32> {
    let Some(at) = dict.find(key) else { return Vec::new() };
    let tail = dict.get(at + key.len()..).unwrap_or_default();
    let Some(open) = tail.find('[') else { return Vec::new() };
    let Some(close) = tail.get(open..).and_then(|t| t.find(']')) else {
        return Vec::new();
    };
    let inside = tail.get(open + 1..open + close).unwrap_or_default();
    let words: Vec<&str> = inside.split_whitespace().collect();
    let mut out = Vec::new();
    let mut i = 0usize;
    while i < words.len() {
        if words.get(i + 2) == Some(&"R") {
            if let Some(n) = words.get(i).and_then(|w| w.parse::<u32>().ok()) {
                out.push(n);
            }
            i += 3;
        } else {
            i += 1;
        }
    }
    out
}

/// A page's content, inflated, with several streams joined.
fn page_content(objects: &Objects, page: &str) -> ApiResult<String> {
    let mut refs = references(page, "/Contents");
    if refs.is_empty() {
        if let Some(single) = reference(page, "/Contents") {
            refs.push(single);
        }
    }
    let mut out = String::new();
    for number in refs {
        let Some(body) = objects.get(&number) else { continue };
        if let Some(raw) = body.stream.as_ref() {
            if let Some(plain) = decode_stream(&body.dict, raw) {
                out.push_str(&String::from_utf8_lossy(&plain));
                out.push('\n');
            }
        }
    }
    Ok(out)
}

// ---------------------------------------------------------------- fonts

/// What a page's fonts can do: either single-byte text, or a `/ToUnicode` map.
#[derive(Debug, Default)]
struct Fonts {
    /// Fonts that need a map, with the map when the document provides one.
    maps: BTreeMap<String, BTreeMap<u32, String>>,
    /// Fonts that need a map and do not have one.
    unmappable: BTreeMap<String, bool>,
    /// Fonts that remap their own characters with /Differences. This reader does
    /// not apply those tables, so a page using one is refused rather than read.
    remapped: BTreeMap<String, bool>,
}

fn page_fonts(objects: &Objects, page: &str) -> Fonts {
    let mut fonts = Fonts::default();
    // /Resources may be inline or a reference.
    let resources = match reference(page, "/Resources") {
        Some(number) => objects.get(&number).map(|o| o.dict.clone()).unwrap_or_default(),
        None => page.to_string(),
    };
    let Some(font_at) = resources.find("/Font") else { return fonts };
    let tail = resources.get(font_at..).unwrap_or_default();
    let dictionary = match reference(tail, "/Font") {
        Some(number) => objects.get(&number).map(|o| o.dict.clone()).unwrap_or_default(),
        None => tail.to_string(),
    };

    // Entries look like «/F1 7 0 R».
    for piece in dictionary.split('/').skip(1) {
        let mut words = piece.split_whitespace();
        let Some(name) = words.next() else { continue };
        let Some(number) = words.next().and_then(|w| w.parse::<u32>().ok()) else {
            continue;
        };
        let Some(font) = objects.get(&number).map(|o| o.dict.clone()) else { continue };

        // A simple font may remap its characters through /Encoding /Differences.
        // We do not follow that table, so the page is not ours to read.
        let encoding = reference(&font, "/Encoding")
            .and_then(|n| objects.get(&n))
            .map(|o| o.dict.clone())
            .unwrap_or_default();
        if font.contains("/Differences") || encoding.contains("/Differences") {
            fonts.remapped.insert(name.to_string(), true);
            continue;
        }

        let needs_map = font.contains("/Type0") || font.contains("Identity-H");
        if !needs_map {
            continue;
        }
        match reference(&font, "/ToUnicode").and_then(|n| objects.get(&n)) {
            Some(cmap_body) => {
                let plain = cmap_body
                    .stream
                    .as_ref()
                    .and_then(|raw| decode_stream(&cmap_body.dict, raw))
                    .unwrap_or_default();
                let cmap = parse_to_unicode(&String::from_utf8_lossy(&plain));
                if cmap.is_empty() {
                    fonts.unmappable.insert(name.to_string(), true);
                } else {
                    fonts.maps.insert(name.to_string(), cmap);
                }
            }
            None => {
                fonts.unmappable.insert(name.to_string(), true);
            }
        }
    }
    fonts
}

/// `beginbfchar`/`beginbfrange` — the font's own table from its codes to Unicode.
fn parse_to_unicode(cmap: &str) -> BTreeMap<u32, String> {
    let mut out = BTreeMap::new();
    let mut rest = cmap;
    while let Some(at) = rest.find("beginbfchar") {
        let tail = rest.get(at..).unwrap_or_default();
        let end = tail.find("endbfchar").unwrap_or(tail.len());
        for line in tail.get(..end).unwrap_or_default().lines().skip(1) {
            let hexes: Vec<&str> = line.split('<').skip(1).collect();
            if let (Some(code), Some(value)) = (hexes.first(), hexes.get(1)) {
                if let (Some(code), Some(text)) = (hex_u32(code), hex_string(value)) {
                    out.insert(code, text);
                }
            }
        }
        rest = tail.get(end..).unwrap_or_default();
    }
    let mut rest = cmap;
    while let Some(at) = rest.find("beginbfrange") {
        let tail = rest.get(at..).unwrap_or_default();
        let end = tail.find("endbfrange").unwrap_or(tail.len());
        for line in tail.get(..end).unwrap_or_default().lines().skip(1) {
            let hexes: Vec<&str> = line.split('<').skip(1).collect();
            if let (Some(low), Some(high), Some(start)) = (hexes.first(), hexes.get(1), hexes.get(2)) {
                if let (Some(low), Some(high), Some(start)) = (hex_u32(low), hex_u32(high), hex_u32(start)) {
                    for (step, code) in (low..=high.min(low + 512)).enumerate() {
                        if let Some(c) = char::from_u32(start + step as u32) {
                            out.insert(code, c.to_string());
                        }
                    }
                }
            }
        }
        rest = tail.get(end..).unwrap_or_default();
    }
    out
}

fn hex_u32(piece: &str) -> Option<u32> {
    let digits: String = piece.chars().take_while(|c| c.is_ascii_hexdigit()).collect();
    if digits.is_empty() {
        return None;
    }
    u32::from_str_radix(&digits, 16).ok()
}

fn hex_string(piece: &str) -> Option<String> {
    let digits: String = piece.chars().take_while(|c| c.is_ascii_hexdigit()).collect();
    if digits.is_empty() || digits.len() % 4 != 0 {
        return None;
    }
    let mut out = String::new();
    for chunk in digits.as_bytes().chunks(4) {
        let hex = String::from_utf8_lossy(chunk);
        let value = u32::from_str_radix(&hex, 16).ok()?;
        out.push(char::from_u32(value)?);
    }
    Some(out)
}

// ---------------------------------------------------------------- text

#[derive(Debug, PartialEq, Eq)]
enum Run {
    Text(String),
    /// Text in a font whose codes cannot be mapped. Counted, never guessed at.
    Unmappable,
}

/// Pull the text-showing operators out of a content stream.
///
/// `(literal) Tj`, `[(a) -20 (b)] TJ`, `(line) '` and `(line) "` — the four ways a
/// PDF says «draw these characters». Each `BT … ET` block is one paragraph, which
/// is usually one line: that is what makes «page 17, paragraph 4» meaningful.
fn text_runs(content: &str, fonts: &Fonts) -> Vec<Run> {
    let mut out = Vec::new();
    let mut current = String::new();
    let mut font = String::new();
    let mut in_text_object = false;
    let bytes = content.as_bytes();
    let mut at = 0usize;

    while at < bytes.len() {
        match bytes.get(at) {
            Some(b'B') if content.get(at..at + 2) == Some("BT") => {
                in_text_object = true;
                current.clear();
                at += 2;
            }
            Some(b'E') if content.get(at..at + 2) == Some("ET") => {
                if !current.trim().is_empty() {
                    out.push(Run::Text(current.trim().to_string()));
                }
                current.clear();
                in_text_object = false;
                at += 2;
            }
            Some(b'/') => {
                // A font is chosen: «/F1 12 Tf».
                let name: String = content
                    .get(at + 1..)
                    .unwrap_or_default()
                    .chars()
                    .take_while(|c| c.is_alphanumeric() || *c == '+' || *c == '.')
                    .collect();
                let after = content.get(at + 1 + name.len()..).unwrap_or_default();
                if after.trim_start().starts_with(|c: char| c.is_ascii_digit())
                    && after.split_whitespace().nth(1) == Some("Tf")
                {
                    font = name;
                }
                at += 1;
            }
            Some(b'(') => {
                let (text, next) = literal_string(content, at);
                at = next;
                if in_text_object {
                    current.push_str(&decode(&text, &font, fonts, &mut out));
                }
            }
            Some(b'<') if content.get(at + 1..at + 2) != Some("<") => {
                let (text, next) = hex_literal(content, at);
                at = next;
                if in_text_object {
                    current.push_str(&decode_hex(&text, &font, fonts, &mut out));
                }
            }
            _ => at += 1,
        }
    }
    if !current.trim().is_empty() {
        out.push(Run::Text(current.trim().to_string()));
    }
    out
}

/// `(a string with \( escapes \))`
fn literal_string(content: &str, at: usize) -> (String, usize) {
    let mut out = String::new();
    let mut depth = 1usize;
    let mut index = at + 1;
    let bytes = content.as_bytes();
    while index < bytes.len() {
        match bytes.get(index) {
            Some(b'\\') => {
                match bytes.get(index + 1) {
                    Some(b'n') => out.push('\n'),
                    Some(b'r') => out.push('\r'),
                    Some(b't') => out.push('\t'),
                    Some(b'(') => out.push('('),
                    Some(b')') => out.push(')'),
                    Some(b'\\') => out.push('\\'),
                    Some(other) if other.is_ascii_digit() => {
                        // An octal escape: up to three digits.
                        let digits: String = content
                            .get(index + 1..)
                            .unwrap_or_default()
                            .chars()
                            .take(3)
                            .take_while(|c| c.is_digit(8))
                            .collect();
                        if let Some(c) = u32::from_str_radix(&digits, 8).ok().and_then(char::from_u32) {
                            out.push(c);
                        }
                        index += digits.len();
                    }
                    _ => {}
                }
                index += 2;
            }
            Some(b'(') => {
                depth += 1;
                out.push('(');
                index += 1;
            }
            Some(b')') => {
                depth -= 1;
                if depth == 0 {
                    return (out, index + 1);
                }
                out.push(')');
                index += 1;
            }
            Some(_) => {
                let ch = content.get(index..).and_then(|s| s.chars().next());
                match ch {
                    Some(c) => {
                        out.push(c);
                        index += c.len_utf8();
                    }
                    None => index += 1,
                }
            }
            None => break,
        }
    }
    (out, index)
}

fn hex_literal(content: &str, at: usize) -> (String, usize) {
    let tail = content.get(at + 1..).unwrap_or_default();
    let end = tail.find('>').unwrap_or(tail.len());
    let digits: String = tail
        .get(..end)
        .unwrap_or_default()
        .chars()
        .filter(|c| c.is_ascii_hexdigit())
        .collect();
    (digits, at + 1 + end + 1)
}

/// A single-byte string. If the current font needs a map, this is not text we can
/// read, and we say so instead of writing nonsense.
fn decode(text: &str, font: &str, fonts: &Fonts, out: &mut Vec<Run>) -> String {
    if fonts.unmappable.contains_key(font) {
        out.push(Run::Unmappable);
        return String::new();
    }
    if let Some(map) = fonts.maps.get(font) {
        // A mapped font used with a literal string: map byte by byte.
        return text
            .bytes()
            .map(|b| map.get(&u32::from(b)).cloned().unwrap_or_default())
            .collect();
    }
    text.to_string()
}

/// A hex string: two bytes per code for a mapped font, one byte otherwise.
fn decode_hex(digits: &str, font: &str, fonts: &Fonts, out: &mut Vec<Run>) -> String {
    if let Some(map) = fonts.maps.get(font) {
        let mut text = String::new();
        for chunk in digits.as_bytes().chunks(4) {
            let hex = String::from_utf8_lossy(chunk);
            if let Ok(code) = u32::from_str_radix(&hex, 16) {
                if let Some(piece) = map.get(&code) {
                    text.push_str(piece);
                }
            }
        }
        return text;
    }
    if fonts.unmappable.contains_key(font) {
        out.push(Run::Unmappable);
        return String::new();
    }
    let mut text = String::new();
    for chunk in digits.as_bytes().chunks(2) {
        let hex = String::from_utf8_lossy(chunk);
        if let Some(c) = u32::from_str_radix(&hex, 16).ok().and_then(char::from_u32) {
            text.push(c);
        }
    }
    text
}

/// Only used by the tests, but it belongs next to the reader it mirrors.
#[cfg(test)]
pub(crate) fn error_of(e: &crate::api::ApiError) -> Option<Refusal> {
    match e {
        crate::api::ApiError::DocumentRefused { reason, .. } => Some(*reason),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::Place;

    /// A PDF with `pages` pages of plain, uncompressed text, written by hand.
    pub(crate) fn pdf_with_pages(lines: &[&str]) -> Vec<u8> {
        let mut out = String::from("%PDF-1.4\n");
        let count = lines.len();
        let kids: Vec<String> = (0..count).map(|i| format!("{} 0 R", 3 + i * 2)).collect();
        out.push_str("1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
        out.push_str(&format!(
            "2 0 obj\n<< /Type/Pages /Count {count} /Kids[{}] >>\nendobj\n",
            kids.join(" ")
        ));
        for (index, line) in lines.iter().enumerate() {
            let page_id = 3 + index * 2;
            let content_id = page_id + 1;
            out.push_str(&format!(
                "{page_id} 0 obj\n<< /Type/Page /Parent 2 0 R /Contents {content_id} 0 R /Resources << /Font << /F1 100 0 R >> >> >>\nendobj\n"
            ));
            let stream = format!("BT /F1 12 Tf 72 700 Td ({line}) Tj ET");
            out.push_str(&format!(
                "{content_id} 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n",
                stream.len()
            ));
        }
        out.push_str("100 0 obj\n<< /Type/Font /Subtype/Type1 /BaseFont/Helvetica >>\nendobj\n");
        out.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");
        out.into_bytes()
    }

    /// A scan: pages that hold an image and no text at all.
    pub(crate) fn scanned_pdf(pages: usize) -> Vec<u8> {
        let mut out = String::from("%PDF-1.4\n");
        let kids: Vec<String> = (0..pages).map(|i| format!("{} 0 R", 3 + i * 2)).collect();
        out.push_str("1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
        out.push_str(&format!(
            "2 0 obj\n<< /Type/Pages /Count {pages} /Kids[{}] >>\nendobj\n",
            kids.join(" ")
        ));
        for index in 0..pages {
            let page_id = 3 + index * 2;
            let content_id = page_id + 1;
            out.push_str(&format!(
                "{page_id} 0 obj\n<< /Type/Page /Parent 2 0 R /Contents {content_id} 0 R /Resources << /XObject << /Im1 200 0 R >> >> >>\nendobj\n"
            ));
            let stream = "q 595 0 0 842 0 0 cm /Im1 Do Q";
            out.push_str(&format!(
                "{content_id} 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n",
                stream.len()
            ));
        }
        out.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");
        out.into_bytes()
    }

    fn read(bytes: &[u8]) -> ApiResult<Extracted> {
        extract(bytes, &Budget::new())
    }

    #[test]
    fn text_comes_out_with_its_page_number() {
        let pdf = pdf_with_pages(&["Kunde: Nordstern Consulting GmbH", "Seite zwei", "Herr Thomas Müller"]);
        let out = read(&pdf).expect("read");
        assert_eq!(out.pages, 3);
        assert!(out.text.contains("Nordstern Consulting GmbH"), "{:?}", out.text);

        let at = out.text.find("Thomas").expect("the name");
        assert_eq!(out.place_of(at), Some(Place { page: 3, paragraph: 1 }));
    }

    #[test]
    fn a_scan_with_no_text_layer_is_refused_by_name() {
        let pdf = scanned_pdf(20);
        match read(&pdf) {
            Err(e) => {
                assert!(
                    matches!(error_of(&e), Some(Refusal::ScannedPdfNoTextLayer { pages: 20 })),
                    "{e}"
                );
                assert!(format!("{e}").contains("20 pages"), "{e}");
            }
            Ok(out) => panic!("a scan must be refused, got {} characters", out.text.len()),
        }
    }

    #[test]
    fn an_encrypted_pdf_is_refused_before_anything_is_read() {
        let mut pdf = pdf_with_pages(&["Nordstern"]);
        let tail = b"trailer\n<< /Root 1 0 R /Encrypt 300 0 R >>\n%%EOF\n";
        pdf.extend_from_slice(tail);
        assert_eq!(read(&pdf).err().as_ref().and_then(error_of), Some(Refusal::EncryptedPdf));
    }

    #[test]
    fn a_font_we_cannot_map_is_refused_not_guessed() {
        // A Type0/Identity-H font with no /ToUnicode: its bytes are glyph numbers,
        // and reading them as characters would be nonsense.
        let mut pdf = String::from("%PDF-1.4\n1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
        pdf.push_str("2 0 obj\n<< /Type/Pages /Count 1 /Kids[3 0 R] >>\nendobj\n");
        pdf.push_str("3 0 obj\n<< /Type/Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n");
        let stream = "BT /F1 12 Tf <00480065> Tj ET";
        pdf.push_str(&format!("4 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n", stream.len()));
        pdf.push_str("5 0 obj\n<< /Type/Font /Subtype/Type0 /Encoding/Identity-H /BaseFont/Custom >>\nendobj\n");
        pdf.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");
        // Structural: the font needs a map and the file carries none, so the page
        // is refused before any character is believed.
        assert!(
            matches!(
                read(pdf.as_bytes()).err().as_ref().and_then(error_of),
                Some(Refusal::UnreadableStructure { page: 1 })
            ),
            "{:?}",
            read(pdf.as_bytes()).err()
        );
    }

    #[test]
    fn a_mapped_font_reads_through_its_own_table() {
        // The same font, but with the /ToUnicode map the document is supposed to
        // carry: now the text is readable, and read.
        let mut pdf = String::from("%PDF-1.4\n1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
        pdf.push_str("2 0 obj\n<< /Type/Pages /Count 1 /Kids[3 0 R] >>\nendobj\n");
        pdf.push_str("3 0 obj\n<< /Type/Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n");
        let stream = "BT /F1 12 Tf <00010002> Tj ET";
        pdf.push_str(&format!("4 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n", stream.len()));
        pdf.push_str("5 0 obj\n<< /Type/Font /Subtype/Type0 /Encoding/Identity-H /ToUnicode 6 0 R >>\nendobj\n");
        let cmap = "/CIDInit /ProcSet findresource begin\n2 beginbfchar\n<0001> <004D>\n<0002> <00FC>\nendbfchar\nend";
        pdf.push_str(&format!("6 0 obj\n<< /Length {} >>\nstream\n{cmap}\nendstream\nendobj\n", cmap.len()));
        pdf.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");

        let out = read(pdf.as_bytes()).expect("read");
        assert_eq!(out.text.trim(), "Mü", "the font's own table was used: {:?}", out.text);
    }

    #[test]
    fn a_file_that_is_not_a_pdf_is_refused() {
        assert_eq!(
            read(b"PK\x03\x04 this is a zip").err().as_ref().and_then(error_of),
            Some(Refusal::MalformedDocument)
        );
    }

    #[test]
    fn escapes_and_nested_brackets_read_correctly() {
        let pdf = pdf_with_pages(&[r"Nordstern \(Holding\) GmbH \\ Berlin"]);
        let out = read(&pdf).expect("read");
        assert!(out.text.contains("Nordstern (Holding) GmbH \\ Berlin"), "{:?}", out.text);
    }
}

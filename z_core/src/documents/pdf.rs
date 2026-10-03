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

        let runs = runs_of(&objects, &page, &fonts, budget)?;
        let page_text: String = runs
            .iter()
            .filter_map(|r| match r {
                Run::Text(text) => Some(text.as_str()),
                Run::Unmappable(_) => None,
            })
            .collect::<Vec<&str>>()
            .join(" ");
        let unmapped: usize = runs
            .iter()
            .map(|r| match r {
                Run::Unmappable(count) => *count,
                Run::Text(_) => 0,
            })
            .sum();
        // A page with nothing on it at all is a page with nothing on it. A page
        // whose codes all failed is a different thing, and it is not skipped:
        // it goes on to be refused by its share, which says what happened.
        if page_text.trim().is_empty() && unmapped == 0 {
            continue;
        }
        pages_with_text += 1;

        // The readable share is measured **per page**, because an average hides the
        // one page that failed — and that is exactly the page with the name on it.
        let percent = readable_percent(&page_text, unmapped);
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
fn readable_percent(text: &str, unmapped: usize) -> usize {
    let total = text.chars().count() + unmapped;
    if total == 0 {
        return 100;
    }
    let broken = text.chars().filter(|c| !decoded(*c)).count() + unmapped;
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
/// How deep a form may draw another form before we stop following.
const FORM_DEPTH: u32 = 8;

/// Every text run a page draws — its own, and the ones inside the forms it calls.
///
/// A page may hold no text of its own and draw all of it through `… /Fm1 Do`.
/// Measured on a 221-page book: 225 of its page streams say only that, and 209
/// forms hold the text. Reading the page stream alone and then calling the file
/// a scan is how a whole book became «this looks like a scan, and we will not
/// send it anywhere».
///
/// An image stays an image: `/Subtype /Image` is not followed, so a real scan
/// is still refused by name.
fn runs_of(objects: &Objects, page: &str, fonts: &Fonts, budget: &Budget) -> ApiResult<Vec<Run>> {
    let content = page_content(objects, page)?;
    let mut walk = Walk {
        objects,
        budget,
        path: Vec::new(),
        out: Vec::new(),
    };
    walk.collect(page, &content, fonts, 0)?;
    Ok(walk.out)
}

/// What the walk carries down: where it is reading from, what it may spend,
/// the forms it is inside, and the runs it has found.
struct Walk<'a> {
    objects: &'a Objects,
    budget: &'a Budget,
    /// The forms on the way down. A path and not a set on purpose: the same
    /// header form drawn twice on a page is read twice, but a form that draws
    /// itself — or a ring of them — ends the walk instead of the process.
    path: Vec<u32>,
    out: Vec<Run>,
}

impl Walk<'_> {
    fn collect(&mut self, dict: &str, content: &str, fonts: &Fonts, depth: u32) -> ApiResult<()> {
        self.budget.check()?;
        self.out.extend(text_runs(content, fonts));
        if depth >= FORM_DEPTH {
            return Ok(());
        }
        let resources = resources_of(self.objects, dict);
        for (name, number) in named_refs(&sub_dict(self.objects, &resources, "/XObject")) {
            if self.path.contains(&number) || !drawn(content, &name) {
                continue;
            }
            let Some(body) = self.objects.get(&number) else { continue };
            if !body.dict.contains("/Form") {
                continue;
            }
            let Some(plain) = body.stream.as_ref().and_then(|raw| decode_stream(&body.dict, raw)) else {
                continue;
            };
            // The form's own fonts sit over the page's: a form with no
            // /Resources inherits them, and one with its own names them itself.
            let mut inner = fonts.clone();
            inner.absorb(page_fonts(self.objects, &body.dict));
            let dict = body.dict.clone();
            self.path.push(number);
            self.collect(&dict, &String::from_utf8_lossy(&plain), &inner, depth + 1)?;
            self.path.pop();
        }
        Ok(())
    }
}

/// Is this name actually drawn — `/Fm1 Do` — rather than merely listed?
fn drawn(content: &str, name: &str) -> bool {
    let wanted = format!("/{name}");
    let mut previous = "";
    for token in content.split_whitespace() {
        if token == "Do" && previous == wanted {
            return true;
        }
        previous = token;
    }
    false
}

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
/// One font's own table, and how wide the codes in it are.
///
/// `Identity-H` writes two bytes to a code; a simple font writes one. The same
/// table read at the wrong width gives the wrong characters, so the width
/// travels with the table rather than being assumed where it is used.
#[derive(Debug, Clone)]
struct FontMap {
    table: BTreeMap<u32, String>,
    two_byte: bool,
}

#[derive(Debug, Default, Clone)]
struct Fonts {
    /// Fonts that need a map, with the map when the document provides one.
    maps: BTreeMap<String, FontMap>,
    /// Fonts that need a map and do not have one.
    unmappable: BTreeMap<String, bool>,
    /// Fonts that remap their own characters with /Differences. This reader does
    /// not apply those tables, so a page using one is refused rather than read.
    remapped: BTreeMap<String, bool>,
}

impl Fonts {
    /// Lay another set over this one: the form's own names win, and the page's
    /// stay for the names the form does not define.
    fn absorb(&mut self, other: Fonts) {
        self.maps.extend(other.maps);
        self.unmappable.extend(other.unmappable);
        self.remapped.extend(other.remapped);
    }
}

/// A page's or a form's `/Resources`, which may be inline or a reference.
fn resources_of(objects: &Objects, dict: &str) -> String {
    match reference(dict, "/Resources") {
        Some(number) => objects.get(&number).map(|o| o.dict.clone()).unwrap_or_default(),
        None => dict.to_string(),
    }
}

/// One named sub-dictionary of a resources dictionary — `/Font`, `/XObject` —
/// whether it is written inline or kept in an object of its own.
fn sub_dict(objects: &Objects, resources: &str, key: &str) -> String {
    let Some(at) = resources.find(key) else { return String::new() };
    let tail = resources.get(at..).unwrap_or_default();
    match reference(tail, key) {
        Some(number) => objects.get(&number).map(|o| o.dict.clone()).unwrap_or_default(),
        None => tail.to_string(),
    }
}

/// The entries of such a dictionary: «/F1 7 0 R» → `("F1", 7)`.
fn named_refs(dictionary: &str) -> Vec<(String, u32)> {
    let mut out = Vec::new();
    for piece in dictionary.split('/').skip(1) {
        let mut words = piece.split_whitespace();
        let Some(name) = words.next() else { continue };
        let Some(number) = words.next().and_then(|w| w.parse::<u32>().ok()) else {
            continue;
        };
        out.push((name.to_string(), number));
    }
    out
}

fn page_fonts(objects: &Objects, page: &str) -> Fonts {
    let mut fonts = Fonts::default();
    let dictionary = sub_dict(objects, &resources_of(objects, page), "/Font");
    for (name, number) in named_refs(&dictionary) {
        let name = name.as_str();
        let Some(font) = objects.get(&number).map(|o| o.dict.clone()) else { continue };

        // A simple font may remap its characters through /Encoding /Differences.
        // We do not follow that table, so the page is not ours to read.
        let encoding = reference(&font, "/Encoding")
            .and_then(|n| objects.get(&n))
            .map(|o| o.dict.clone())
            .unwrap_or_default();
        // A simple font may remap its characters through /Encoding /Differences.
        // We do not read that table — but a font that carries one usually also
        // carries /ToUnicode, and that one says outright what each code means.
        //
        // Measured on a 146-page book of German tax terms (InDesign, eight
        // fonts, four of them remapped and every one of the four with its own
        // /ToUnicode): the reader refused page 1 and with it the whole file,
        // because a cover page in a font with fifteen remapped glyph names was
        // enough. The refusal now waits until there is really nothing to read
        // the font by.
        let remapped = font.contains("/Differences") || encoding.contains("/Differences");
        let needs_map = font.contains("/Type0") || font.contains("Identity-H");
        if !remapped && !needs_map {
            continue;
        }
        let cmap = reference(&font, "/ToUnicode")
            .and_then(|n| objects.get(&n))
            .map(|body| {
                let plain = body
                    .stream
                    .as_ref()
                    .and_then(|raw| decode_stream(&body.dict, raw))
                    .unwrap_or_default();
                parse_to_unicode(&String::from_utf8_lossy(&plain))
            })
            .unwrap_or_default();
        if cmap.is_empty() {
            if remapped {
                fonts.remapped.insert(name.to_string(), true);
            } else {
                fonts.unmappable.insert(name.to_string(), true);
            }
            continue;
        }
        fonts.maps.insert(
            name.to_string(),
            FontMap {
                table: cmap,
                // One byte to a code in a simple font, two in `Identity-H`.
                two_byte: needs_map,
            },
        );
    }
    fonts
}

/// `beginbfchar`/`beginbfrange` — the font's own table from its codes to Unicode.
///
/// Read by **token**, not by line, and measured on three real documents before
/// it was rewritten:
///
/// * entries share a line — 6 to 11 such lines per map in one file — and the
///   old reader took one entry from each line and dropped the rest. When the
///   `beginbfchar` itself shared the line, it dropped them all;
/// * ranges run to 897, 8125 and 65535 codes, and the old reader stopped at
///   513, leaving the rest of the page as holes;
/// * a range may name its destinations one by one in a list. Read as a single
///   destination it does not leave a hole — it puts **the wrong character** on
///   the screen, which is worse.
///
/// What it still will not do is guess: a destination it cannot decode is left
/// out, and the page's readable share falls, which is the refusal path.
fn parse_to_unicode(cmap: &str) -> BTreeMap<u32, String> {
    let mut out = BTreeMap::new();
    for block in blocks(cmap, "beginbfchar", "endbfchar") {
        let items = items(block);
        let mut at = 0;
        while let (Some(Item::Hex(code)), Some(Item::Hex(value))) = (items.get(at), items.get(at + 1)) {
            if let (Some(code), Some(text)) = (hex_u32(code), hex_string(value)) {
                if out.len() >= MAX_CMAP_ENTRIES {
                    return out;
                }
                // `<0000>` is what a table says when it has nothing to say about
                // a glyph — the Swedish annual report says it of ten codes in
                // each of its two fonts. It is not a character, so it is not a
                // mapping, and the code it names stays unmapped and counted.
                if names_a_character(&text) {
                    out.insert(code, text);
                }
            }
            at += 2;
        }
    }
    for block in blocks(cmap, "beginbfrange", "endbfrange") {
        let items = items(block);
        let mut at = 0;
        while at + 2 < items.len() + 1 {
            let (Some(Item::Hex(low)), Some(Item::Hex(high))) = (items.get(at), items.get(at + 1)) else {
                break;
            };
            let (Some(low), Some(high)) = (hex_u32(low), hex_u32(high)) else { break };
            at += 2;
            match items.get(at) {
                // `<low> <high> [<d1> <d2> …]` — one destination for each code.
                Some(Item::Open) => {
                    at += 1;
                    let mut code = low;
                    while let Some(Item::Hex(value)) = items.get(at) {
                        if let Some(text) = hex_string(value).filter(|t| names_a_character(t)) {
                            if out.len() >= MAX_CMAP_ENTRIES {
                                return out;
                            }
                            out.insert(code, text);
                        }
                        code = code.saturating_add(1);
                        at += 1;
                    }
                    if matches!(items.get(at), Some(Item::Close)) {
                        at += 1;
                    }
                }
                // `<low> <high> <start>` — the destination counts up with the code.
                Some(Item::Hex(start)) => {
                    at += 1;
                    let Some(units) = hex_units(start) else { continue };
                    for (step, code) in (low..=high).enumerate() {
                        if out.len() >= MAX_CMAP_ENTRIES {
                            return out;
                        }
                        let Ok(step) = u16::try_from(step) else { break };
                        let mut units = units.clone();
                        let Some(last) = units.last_mut() else { break };
                        let Some(moved) = last.checked_add(step) else { break };
                        *last = moved;
                        if let Some(text) = utf16_string(&units).filter(|t| names_a_character(t)) {
                            out.insert(code, text);
                        }
                    }
                }
                _ => break,
            }
        }
    }
    out
}

/// Does this destination name a character a person could read?
///
/// The owner's rule, in one line: **a code with no real character is an
/// unreadable code.** A table that answers `<0000>` — or any control or
/// private-use slot — has not told us what the glyph is, and pretending it has
/// puts a byte in the text that nobody typed.
fn names_a_character(text: &str) -> bool {
    !text.is_empty() && text.chars().all(decoded)
}

/// A code map is at most a two-byte space, so this is a bound and not a policy:
/// it exists so that a malformed range cannot ask for memory without end.
const MAX_CMAP_ENTRIES: usize = 70_000;

/// One piece of a CMap block: a `<hex>` string, or a bracket around a list.
enum Item {
    Hex(String),
    Open,
    Close,
}

/// The text between each `begin…`/`end…` pair.
fn blocks<'a>(cmap: &'a str, begin: &str, end: &str) -> Vec<&'a str> {
    let mut out = Vec::new();
    let mut rest = cmap;
    while let Some(at) = rest.find(begin) {
        let tail = rest.get(at + begin.len()..).unwrap_or_default();
        let stop = tail.find(end).unwrap_or(tail.len());
        out.push(tail.get(..stop).unwrap_or_default());
        rest = tail.get(stop..).unwrap_or_default();
    }
    out
}

/// The `<…>` groups and the brackets of a block, in the order they are written.
fn items(block: &str) -> Vec<Item> {
    let mut out = Vec::new();
    let mut chars = block.char_indices();
    while let Some((at, c)) = chars.next() {
        match c {
            '[' => out.push(Item::Open),
            ']' => out.push(Item::Close),
            '<' => {
                let tail = block.get(at + 1..).unwrap_or_default();
                let stop = tail.find('>').unwrap_or(tail.len());
                let digits: String = tail
                    .get(..stop)
                    .unwrap_or_default()
                    .chars()
                    .filter(|c| c.is_ascii_hexdigit())
                    .collect();
                out.push(Item::Hex(digits));
                for _ in 0..stop {
                    chars.next();
                }
            }
            _ => {}
        }
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

/// A destination, as UTF-16 code units — which is what a CMap writes.
fn hex_units(piece: &str) -> Option<Vec<u16>> {
    let digits: String = piece.chars().take_while(|c| c.is_ascii_hexdigit()).collect();
    if digits.is_empty() || digits.len() % 4 != 0 {
        return None;
    }
    let mut out = Vec::new();
    for chunk in digits.as_bytes().chunks(4) {
        let hex = String::from_utf8_lossy(chunk);
        out.push(u16::from_str_radix(&hex, 16).ok()?);
    }
    Some(out)
}

/// UTF-16 units into text — **pairs included**. The old reader took every four
/// hex digits for a character of its own, so a destination written as a
/// surrogate pair decoded to nothing and the whole entry was dropped.
fn utf16_string(units: &[u16]) -> Option<String> {
    let mut out = String::new();
    for c in char::decode_utf16(units.iter().copied()) {
        out.push(c.ok()?);
    }
    Some(out)
}

fn hex_string(piece: &str) -> Option<String> {
    utf16_string(&hex_units(piece)?)
}

// ---------------------------------------------------------------- text

#[derive(Debug, PartialEq, Eq)]
enum Run {
    Text(String),
    /// Codes that came out as no character at all — a font with no table, a
    /// code the table does not mention, or one the table maps to nothing.
    ///
    /// It carries **how many**, because that is the whole of its use: a code
    /// with no character is an unreadable code, and it is counted against the
    /// page exactly as a broken character is. Dropped silently — as it was —
    /// a page of them came out empty and was called a picture of a page.
    Unmappable(usize),
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
        // Two bytes to the code, so that is how many codes went unread.
        out.push(Run::Unmappable(text.chars().count().div_ceil(2)));
        return String::new();
    }
    if let Some(map) = fonts.maps.get(font) {
        // A mapped font is a two-byte font: `Identity-H` says so by name, and
        // every code map measured on real documents carries a two-byte
        // codespace. So a literal string holds **codes**, not bytes, and they
        // are read in pairs.
        //
        // Read one byte at a time — as this did — a line of such a font comes
        // out as «NUL K NUL L»: the high byte of each code looks up the map's
        // entry for code 0, which an identity table gives as U+0000. Measured
        // on two real documents: 578 of 1225 characters on one page, 174 of
        // 841 on another, every one of them a NUL, and the page refused at 52%
        // and 79% readable for a reason that was ours and not the file's.
        let codes: Vec<u32> = text.chars().map(u32::from).collect();
        let mut read = String::new();
        let mut missed = 0usize;
        // One byte to a code, or two, as the font's own table says.
        let width = if map.two_byte { 2 } else { 1 };
        for pair in codes.chunks(width) {
            let code = match pair {
                [high, low] => (high << 8) | low,
                [only] => *only,
                _ => continue,
            };
            match map.table.get(&code) {
                Some(piece) => read.push_str(piece),
                // Not a character, so not silence either: it is counted.
                None => missed += 1,
            }
        }
        if missed > 0 {
            out.push(Run::Unmappable(missed));
        }
        return read;
    }
    text.to_string()
}

/// A hex string: two bytes per code for a mapped font, one byte otherwise.
fn decode_hex(digits: &str, font: &str, fonts: &Fonts, out: &mut Vec<Run>) -> String {
    if let Some(map) = fonts.maps.get(font) {
        let mut text = String::new();
        let mut missed = 0usize;
        let width = if map.two_byte { 4 } else { 2 };
        for chunk in digits.as_bytes().chunks(width) {
            let hex = String::from_utf8_lossy(chunk);
            match u32::from_str_radix(&hex, 16).ok().and_then(|code| map.table.get(&code)) {
                Some(piece) => text.push_str(piece),
                None => missed += 1,
            }
        }
        if missed > 0 {
            out.push(Run::Unmappable(missed));
        }
        return text;
    }
    if fonts.unmappable.contains_key(font) {
        out.push(Run::Unmappable(digits.len().div_ceil(4)));
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

    /// A page that draws its text through a form, and holds none of its own.
    ///
    /// This is what ilovepdf, «print to PDF» and some Word exports write: the
    /// page stream is `… /Fm1 Do` and every `Tj` lives inside the form. The
    /// form carries its own `/Resources`, so its font names are its own.
    pub(crate) fn pdf_with_form(line: &str, form_stream: Option<&str>) -> Vec<u8> {
        let inner = form_stream
            .map(|s| s.to_string())
            .unwrap_or_else(|| format!("BT /FA 12 Tf 72 700 Td ({line}) Tj ET"));
        let mut out = String::from("%PDF-1.4\n");
        out.push_str("1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
        out.push_str("2 0 obj\n<< /Type/Pages /Count 1 /Kids[3 0 R] >>\nendobj\n");
        out.push_str(
            "3 0 obj\n<< /Type/Page /Parent 2 0 R /Contents 4 0 R \
             /Resources << /XObject << /Fm1 5 0 R >> >> >>\nendobj\n",
        );
        let page_stream = "q 1 0 0 1 0 0 cm /Fm1 Do Q";
        out.push_str(&format!(
            "4 0 obj\n<< /Length {} >>\nstream\n{page_stream}\nendstream\nendobj\n",
            page_stream.len()
        ));
        out.push_str(&format!(
            "5 0 obj\n<< /Type/XObject /Subtype/Form /Length {} \
             /Resources << /Font << /FA 100 0 R >> /XObject << /Fm1 5 0 R >> >> >>\nstream\n{inner}\nendstream\nendobj\n",
            inner.len()
        ));
        out.push_str("100 0 obj\n<< /Type/Font /Subtype/Type1 /BaseFont/Helvetica >>\nendobj\n");
        out.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");
        out.into_bytes()
    }

    fn read(bytes: &[u8]) -> ApiResult<Extracted> {
        extract(bytes, &Budget::new())
    }

    /// Measured on a 221-page book: 225 page streams that say only `… Do`, and
    /// 209 forms holding the `Tj`s. The reader called the whole book a scan.
    #[test]
    fn text_drawn_through_a_form_is_read_rather_than_called_a_scan() {
        let pdf = pdf_with_form("Kunde: Nordstern Consulting GmbH", None);
        let out = read(&pdf).expect("a page that draws a form is not a scan");
        assert_eq!(out.pages, 1);
        assert!(
            out.text.contains("Nordstern Consulting GmbH"),
            "the text inside the form never arrived: {} chars",
            out.text.chars().count()
        );
    }

    /// A form may draw another form. One that draws itself must end the walk,
    /// not the process.
    #[test]
    fn a_form_that_draws_itself_stops_instead_of_spinning() {
        let pdf = pdf_with_form("", Some("q /Fm1 Do Q"));
        match read(&pdf) {
            Err(e) => assert!(
                matches!(error_of(&e), Some(Refusal::ScannedPdfNoTextLayer { .. })),
                "a form with no text is a page with no text"
            ),
            Ok(out) => assert_eq!(out.text.trim(), "", "there was no text to find"),
        }
    }

    /// An image is still an image: following forms must not turn a scan into a
    /// page that looks readable.
    #[test]
    fn an_image_xobject_is_still_a_scan() {
        let pdf = scanned_pdf(3);
        let e = read(&pdf).expect_err("a scan is refused");
        assert!(matches!(
            error_of(&e),
            Some(Refusal::ScannedPdfNoTextLayer { pages: 3 })
        ));
    }

    /// A page drawn in one mapped font, with the codes and the table given.
    ///
    /// `codes` is the hex string the page shows; `pairs` is what the font's
    /// own `/ToUnicode` says about them.
    pub(crate) fn pdf_with_map(codes: &str, pairs: &[(&str, &str)]) -> Vec<u8> {
        let mut pdf = String::from("%PDF-1.4\n1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
        pdf.push_str("2 0 obj\n<< /Type/Pages /Count 1 /Kids[3 0 R] >>\nendobj\n");
        pdf.push_str(
            "3 0 obj\n<< /Type/Page /Parent 2 0 R /Contents 4 0 R \
             /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n",
        );
        let stream = format!("BT /F1 12 Tf <{codes}> Tj ET");
        pdf.push_str(&format!(
            "4 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n",
            stream.len()
        ));
        pdf.push_str("5 0 obj\n<< /Type/Font /Subtype/Type0 /Encoding/Identity-H /ToUnicode 6 0 R >>\nendobj\n");
        let rows: String = pairs.iter().map(|(c, v)| format!("<{c}> <{v}>\n")).collect();
        let cmap = format!(
            "/CIDInit /ProcSet findresource begin\n{} beginbfchar\n{rows}endbfchar\nend",
            pairs.len()
        );
        pdf.push_str(&format!(
            "6 0 obj\n<< /Length {} >>\nstream\n{cmap}\nendstream\nendobj\n",
            cmap.len()
        ));
        pdf.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");
        pdf.into_bytes()
    }

    /// A table may say «this glyph has no Unicode» — `<0000>` — and a real
    /// document does: the Swedish annual report says it of ten codes in each of
    /// its two fonts, and uses them 174 times on one page.
    ///
    /// That is not a character. It must not reach the text as a NUL byte the
    /// person never typed, and it must be counted against the page rather than
    /// quietly dropped, or a page with five of them in a thousand would pass at
    /// 99.5% carrying five NULs into what gets sent.
    #[test]
    fn a_code_the_table_maps_to_nothing_never_reaches_the_text() {
        let pdf = pdf_with_map(
            "00010002000300040005000600070008000900 0A",
            &[
                ("0001", "0041"),
                ("0002", "0042"),
                ("0003", "0043"),
                ("0004", "0044"),
                ("0005", "0045"),
                ("0006", "0046"),
                ("0007", "0047"),
                ("0008", "0048"),
                // The two the document itself says nothing about.
                ("0009", "0000"),
                ("000A", "0000"),
            ],
        );
        let out = read(&pdf).expect("eight of ten codes are characters, which is 80%");
        assert!(
            !out.text.contains('\u{0}'),
            "a NUL reached the text: {} chars",
            out.text.chars().count()
        );
        assert_eq!(out.text.trim(), "ABCDEFGH");
    }

    /// And when the whole page is such codes, the refusal is the one that says
    /// what happened — the share that decoded — not «this looks like a scan».
    #[test]
    fn a_page_of_codes_with_no_characters_is_refused_by_its_share() {
        let pdf = pdf_with_map(
            "00010002000300040005",
            &[
                ("0001", "0000"),
                ("0002", "0000"),
                ("0003", "0000"),
                ("0004", "0000"),
                ("0005", "0000"),
            ],
        );
        // A table all of whose entries name nothing is a table with nothing in
        // it, so the font has no map at all and the page is refused before a
        // character is believed. Either refusal is honest; what must never be
        // said is «this is a picture of a page», because it is not.
        let e = read(&pdf).expect_err("a page of nothing is refused");
        match error_of(&e) {
            Some(Refusal::UnsupportedEncoding { page, .. }) => assert_eq!(page, 1),
            Some(Refusal::UnreadableStructure { page }) => assert_eq!(page, 1),
            other => panic!("refused as {other:?}, which tells the person the wrong thing"),
        }
    }

    /// A simple font that remaps its glyphs, with the table that says what they
    /// mean.
    ///
    /// Measured on a 146-page book of German tax terms: eight fonts, four of
    /// them remapped by `/Differences` and **every one of the four carrying its
    /// own `/ToUnicode`**. The reader refused page 1 — a cover page with fifteen
    /// remapped glyph names — and with it all 146 pages, while the answer was
    /// in the file the whole time.
    #[test]
    fn a_remapped_font_is_read_by_its_own_table() {
        let mut pdf = String::from("%PDF-1.4\n1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
        pdf.push_str("2 0 obj\n<< /Type/Pages /Count 1 /Kids[3 0 R] >>\nendobj\n");
        pdf.push_str(
            "3 0 obj\n<< /Type/Page /Parent 2 0 R /Contents 4 0 R \
             /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n",
        );
        let stream = "BT /F1 12 Tf <414243> Tj ET";
        pdf.push_str(&format!(
            "4 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n",
            stream.len()
        ));
        pdf.push_str(
            "5 0 obj\n<< /Type/Font /Subtype/Type1 /BaseFont/AGaramondPro \
             /Encoding << /Differences [65 /f_i 66 /one.lt 67 /arrowright] >> /ToUnicode 6 0 R >>\nendobj\n",
        );
        // One byte to a code, because a simple font writes one.
        let cmap = "/CIDInit /ProcSet findresource begin\n3 beginbfchar\n<41> <0046>\n<42> <0031>\n<43> <2192>\nendbfchar\nend";
        pdf.push_str(&format!(
            "6 0 obj\n<< /Length {} >>\nstream\n{cmap}\nendstream\nendobj\n",
            cmap.len()
        ));
        pdf.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");

        let out = read(pdf.as_bytes()).expect("the font says what its glyphs mean");
        assert_eq!(out.text.trim(), "F1→", "the table was not used: {:?}", out.text);
    }

    /// And when it carries no table, the refusal stands: we do not read a
    /// remapped font by guessing what its glyph names meant.
    #[test]
    fn a_remapped_font_with_no_table_is_still_refused() {
        let mut pdf = String::from("%PDF-1.4\n1 0 obj\n<< /Type/Catalog /Pages 2 0 R >>\nendobj\n");
        pdf.push_str("2 0 obj\n<< /Type/Pages /Count 1 /Kids[3 0 R] >>\nendobj\n");
        pdf.push_str(
            "3 0 obj\n<< /Type/Page /Parent 2 0 R /Contents 4 0 R \
             /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n",
        );
        let stream = "BT /F1 12 Tf (ABC) Tj ET";
        pdf.push_str(&format!(
            "4 0 obj\n<< /Length {} >>\nstream\n{stream}\nendstream\nendobj\n",
            stream.len()
        ));
        pdf.push_str(
            "5 0 obj\n<< /Type/Font /Subtype/Type1 /BaseFont/AGaramondPro \
             /Encoding << /Differences [65 /f_i] >> >>\nendobj\n",
        );
        pdf.push_str("trailer\n<< /Root 1 0 R >>\n%%EOF\n");

        let e = read(pdf.as_bytes()).expect_err("a remapped font with no table is refused");
        assert!(matches!(error_of(&e), Some(Refusal::UnreadableStructure { page: 1 })));
    }

    /// The other silent hole: codes the table never mentions at all.
    ///
    /// They looked up as nothing and were dropped — no character, no count, no
    /// word about them. A page made only of those came out empty and was
    /// refused as «a picture of a page», which tells the person something that
    /// is not true about their document.
    #[test]
    fn codes_the_table_never_mentions_are_counted_not_dropped() {
        let pdf = pdf_with_map("00010002000300040005", &[("00FF", "0041")]);
        let e = read(&pdf).expect_err("nothing on the page could be read");
        match error_of(&e) {
            Some(Refusal::UnsupportedEncoding { page, readable_percent }) => {
                assert_eq!(page, 1);
                assert_eq!(readable_percent, 0, "none of it decoded, and the number says so");
            }
            other => panic!("refused as {other:?}, which is not what happened"),
        }
    }

    /// A two-byte font's literal string holds codes, not bytes.
    ///
    /// Measured on two real documents before it was believed: every unreadable
    /// character on the refused pages was a NUL — 578 of 1225 on one, 174 of
    /// 841 on the other — because the high byte of each code was looked up on
    /// its own and an identity table answers code 0 with U+0000.
    #[test]
    fn a_literal_string_in_a_two_byte_font_is_read_in_pairs() {
        let mut fonts = Fonts::default();
        let mut map = BTreeMap::new();
        // What an identity /ToUnicode really says about code 0.
        map.insert(0x0000, "\u{0}".to_string());
        map.insert(0x0041, "K".to_string());
        map.insert(0x0042, "L".to_string());
        fonts.maps.insert("F1".to_string(), FontMap { table: map, two_byte: true });

        let mut out = Vec::new();
        let text = decode("\u{0}A\u{0}B", "F1", &fonts, &mut out);

        assert_eq!(
            text, "KL",
            "the codes were read one byte at a time, so every other character came out a NUL"
        );
        assert!(out.is_empty(), "nothing here is unmappable");
    }

    /// Measured: ranges of 897, 8125 and 65535 codes in three real documents.
    /// The reader stopped at 513 and the rest of the page came out as holes.
    #[test]
    fn a_long_bfrange_maps_all_of_itself() {
        let cmap = "1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n\
                    1 beginbfrange\n<0000> <0FFF> <0041>\nendbfrange\n";
        let map = parse_to_unicode(cmap);
        // 4096 codes, less the 33 whose destination lands in the control block
        // at U+007F..U+009F: those name no character, so they are not mappings.
        assert_eq!(map.len(), 4096 - 33, "a 4096-code range came back cut short");
        let last = char::from_u32(0x0041 + 0x0FFF).map(|c| c.to_string());
        assert_eq!(map.get(&0x0FFF), last.as_ref(), "the last code of the range is not where it should be");
    }

    /// Measured: 6 to 11 lines per map in a real document carry more than one
    /// entry. The reader read the first on each line and dropped the rest.
    #[test]
    fn several_entries_on_one_line_are_all_read() {
        let cmap = "2 beginbfchar <01> <0041> <02> <0042> endbfchar\n\
                    2 beginbfrange <10> <11> <0061> <20> <21> <0071> endbfrange\n";
        let map = parse_to_unicode(cmap);
        assert_eq!(map.get(&0x01).map(String::as_str), Some("A"));
        assert_eq!(map.get(&0x02).map(String::as_str), Some("B"), "the second entry on the line was dropped");
        assert_eq!(map.get(&0x11).map(String::as_str), Some("b"));
        assert_eq!(map.get(&0x21).map(String::as_str), Some("r"), "the second range on the line was dropped");
    }

    /// `<low> <high> [<d1> <d2> <d3>]` names a destination for each code, and
    /// they need not be consecutive. Read as a single destination it does not
    /// leave a hole — it puts **the wrong character** on the screen.
    #[test]
    fn a_bfrange_with_a_list_of_destinations_takes_each_one() {
        let cmap = "1 beginbfrange\n<01> <03> [<0041> <0062> <0043>]\nendbfrange\n";
        let map = parse_to_unicode(cmap);
        assert_eq!(map.get(&0x01).map(String::as_str), Some("A"));
        assert_eq!(map.get(&0x02).map(String::as_str), Some("b"), "the second destination was invented, not read");
        assert_eq!(map.get(&0x03).map(String::as_str), Some("C"));
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

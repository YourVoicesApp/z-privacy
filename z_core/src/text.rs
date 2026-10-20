//! Offsets. The contract counts UTF-16 code units because Dart does; Rust
//! counts bytes. Every crossing goes through here, and a span that would cut a
//! character is refused rather than trimmed.

use unicode_normalization::char::is_combining_mark;
use unicode_normalization::UnicodeNormalization;

use crate::api::{ApiError, ApiResult, Span};

/// One Unicode composition, so that «Müller» written two ways is one value.
///
/// Invariant G3 compares values in this form: a leak test that compares raw
/// bytes can be fooled by a decomposed «u + combining diaeresis».
pub(crate) fn nfc(s: &str) -> String {
    s.nfc().collect()
}

/// **The characters a reader cannot see** — 095, خ3.
///
/// Unicode's `Cf` (format) class, as much of it as a document this product
/// reads can carry. A list and not a category test, for the reason this house
/// enumerates everything else: there is no category API in the standard
/// library, and a list can be **counted** rather than found by reading.
///
/// Every one of these was measured in a document, not imagined: Word writes a
/// soft hyphen where it un-breaks a line, PDF extraction leaves zero-width
/// spaces, a copy from a web page carries joiners, and the bidi marks arrive
/// with any text that has ever been near an Arabic or Hebrew paragraph — ours
/// included, since `their_own_word` writes the isolates itself.
const INVISIBLE: [char; 13] = [
    '\u{00AD}', // soft hyphen
    '\u{200B}', // zero-width space
    '\u{200C}', // zero-width non-joiner
    '\u{200D}', // zero-width joiner
    '\u{200E}', // left-to-right mark
    '\u{200F}', // right-to-left mark
    '\u{202A}', // left-to-right embedding
    '\u{202B}', // right-to-left embedding
    '\u{202C}', // pop directional formatting
    '\u{202D}', // left-to-right override
    '\u{202E}', // right-to-left override
    '\u{2060}', // word joiner
    '\u{FEFF}', // zero-width no-break space (a byte-order mark in the middle)
];

/// **How a person reads a word** — one folding, asked by every rule that wants
/// to know what a word *is* rather than where it stands.
///
/// NFC, so that «Müller» written as `u` + combining diaeresis is the same word
/// as «Müller» — which G3 has always held of a value and the scanner did not
/// hold of a name (خ3: NFD found one of two names in the owner's own
/// salutation). And the invisible characters dropped, so that
/// `Mar<U+200B>kus` is «Markus» to a shape test as it is to an eye.
///
/// **This is a reading, never a replacement.** What comes back is used to
/// decide — is this a name, is it in the dictionary — and never to build the
/// text that leaves or the span that is protected: the span stays the
/// original's, byte for byte, because «protection may not change how a
/// document reads» and a token over a shortened stretch would change it.
///
/// **Never NFKC**, and that is a rule of this house with its own measurement:
/// NFKC decomposes the Arabic isolated mark forms into space + mark and cuts
/// words in two (`nfkc_inserts_a_space_on_arabic_mark_forms`). So the
/// typographic ligature «ﬁscher» stays a known miss, written down in
/// `a_name_is_read_as_a_person_reads_it.rs` rather than hoped about.
pub(crate) fn as_a_person_reads_it(word: &str) -> String {
    if word.is_ascii() {
        // The common case, and it cannot hold either fault: ASCII has no
        // combining marks and no format characters.
        return word.to_string();
    }
    nfc(&word.chars().filter(|c| !INVISIBLE.contains(c)).collect::<String>())
}

/// **A word of the person's own, isolated so the sentence keeps its order** —
/// the owner's test of 16 October 2026, and the same pair of characters the
/// glass uses (`theirOwnWord` in `messages.dart`).
///
/// `U+2068 FIRST STRONG ISOLATE` before it and `U+2069 POP DIRECTIONAL
/// ISOLATE` after. The bidirectional algorithm then takes the word's direction
/// from its own first strong character and lays the whole of it out as one
/// unit, so the English around it stays where the sentence put it. His session
/// «ألماني 1» inside an English line drew as «This document came back from «11
/// .«ألماني names stay…» — every word right and the order nonsense.
///
/// **Why the core and not only the screen.** A sentence the core writes
/// arrives at the glass finished: the app is handed a string and has nothing
/// left to isolate. So wherever the core quotes something that came from the
/// person — a label they taught, a line of their CSV, a word in their
/// document, a name inside their file — it wraps it here.
///
/// **Our own words never go through this**: a language id, a pack, a rule
/// set's name, a kind. They are ours, they are already in the sentence's
/// direction, and isolating them would be a pair of characters with nothing to
/// do. G44 reads both halves of that rule out of the source.
pub(crate) fn their_own_word(word: &str) -> String {
    format!("\u{2068}{word}\u{2069}")
}

/// Length of `s` in UTF-16 code units — what Dart's `String.length` returns.
#[allow(dead_code)] // reached once protect() lands in 005
pub(crate) fn utf16_len(s: &str) -> usize {
    s.chars().map(char::len_utf16).sum()
}

/// UTF-16 code-unit offset → byte offset.
///
/// `Err(BadSpan)` if the offset is past the end or lands inside a character
/// (the low half of a surrogate pair — an emoji cut in two).
#[allow(dead_code)] // reached once protect() lands in 005
pub(crate) fn utf16_to_byte(s: &str, target: usize) -> ApiResult<usize> {
    if target == 0 {
        return Ok(0);
    }
    let mut units = 0usize;
    for (byte_idx, ch) in s.char_indices() {
        if units == target {
            return Ok(byte_idx);
        }
        if units > target {
            return Err(ApiError::BadSpan {
                reason: format!("offset {target} falls inside a character"),
            });
        }
        units += ch.len_utf16();
    }
    if units == target {
        Ok(s.len())
    } else {
        Err(ApiError::BadSpan {
            reason: format!("offset {target} is past the end of the text ({units} units)"),
        })
    }
}

/// Byte offset → UTF-16 code-unit offset. Used when handing marks to the UI.
pub(crate) fn byte_to_utf16(s: &str, target: usize) -> ApiResult<usize> {
    if target > s.len() {
        return Err(ApiError::BadSpan {
            reason: format!("byte offset {target} is past the end"),
        });
    }
    let mut units = 0usize;
    for (byte_idx, ch) in s.char_indices() {
        if byte_idx == target {
            return Ok(units);
        }
        if byte_idx > target {
            return Err(ApiError::BadSpan {
                reason: format!("byte offset {target} falls inside a character"),
            });
        }
        units += ch.len_utf16();
    }
    Ok(units)
}

/// A span from the UI, checked and turned into a byte range.
#[allow(dead_code)] // reached once protect() lands in 005
pub(crate) fn span_to_bytes(s: &str, span: Span) -> ApiResult<(usize, usize)> {
    if span.end <= span.start {
        return Err(ApiError::BadSpan {
            reason: format!("empty or reversed selection ({}..{})", span.start, span.end),
        });
    }
    let start = utf16_to_byte(s, span.start as usize)?;
    let end = utf16_to_byte(s, span.end as usize)?;
    Ok((start, end))
}

/// A byte range turned back into a span for the UI.
pub(crate) fn bytes_to_span(s: &str, start: usize, end: usize) -> ApiResult<Span> {
    Ok(Span {
        start: byte_to_utf16(s, start)? as u32,
        end: byte_to_utf16(s, end)? as u32,
    })
}

/// The marks a selection drops from its own edges — **every mark the keyboard
/// has** (paper 085, ruling 3, the owner on 14 Oct 2026).
///
/// > «وبالنسبة للرموز لا أقصد فقط هذه الرموز… بل جميع الرموز الموجودة في
/// > الكيبورد.»
///
/// This replaces a written-out list of twenty-seven. That list was defended on
/// purpose — «`+` opens a telephone number, `@` holds an address together, `/`
/// and `#` carry a reference number» — and the owner overruled it: a mark is a
/// mark. The defence was not wrong about numbers, it was wrong about *where*
/// they are answered; ruling 2 of the same paper says **numbers are not words**
/// and gives them their own rules in their own paper, by kind, instead of by an
/// exception hidden in an edge list. What a `+` costs today is measured in
/// `a_plus_in_front_of_a_number_leaves_the_value_now`.
///
/// So the law is written as a complement, which is the only form that can mean
/// «every mark» without a list to keep:
///
///  * a **letter or a digit** is a word's own, anywhere in the world;
///  * a **combining mark** belongs to the letter in front of it — this is the
///    clause that keeps the Arabic harakat inside a name, and it is the whole
///    reason this is not the one-liner `!c.is_alphanumeric()`;
///  * **whitespace** is not a mark, and the callers handle it themselves;
///  * everything else is a mark, and at an edge it leaves.
///
/// `unicode-normalization` is already in the tree for NFC, so «what Unicode
/// calls a combining mark» costs no new crate.
fn is_edge_mark(c: char) -> bool {
    !c.is_alphanumeric() && !c.is_whitespace() && !is_combining_mark(c)
}

/// Is this character part of a word?
///
/// A letter or a digit anywhere in the world, and the two marks that stand
/// **inside** names rather than around them: «Al-Hassan» is one word and so is
/// «O'Brien». At an edge those two are dropped like any other mark, which is
/// why this answers about the character and `whole_words` decides about the
/// position.
fn is_word(c: char) -> bool {
    c.is_alphanumeric() || c == '_'
}

/// Does this character join two word characters into one word?
fn joins_a_word(c: char) -> bool {
    matches!(c, '-' | '\'' | '’' | '.' | '/')
}

/// Is this position inside a word rather than between two of them?
///
/// True when a word character stands on both sides of it — and a joining mark
/// counts as one when a word character stands on *its* far side, so `Al-Hassan`
/// and `O'Brien` are each one word while `Müller,` ends at the comma.
fn cuts_a_word(s: &str, at: usize) -> bool {
    let before = match s.get(..at).and_then(|h| h.chars().next_back()) {
        Some(c) => c,
        None => return false,
    };
    let after = match s.get(at..).and_then(|t| t.chars().next()) {
        Some(c) => c,
        None => return false,
    };
    let word_side = |c: char, far: Option<char>| is_word(c) || (joins_a_word(c) && far.is_some_and(is_word));
    let far_before = s.get(..at - before.len_utf8()).and_then(|h| h.chars().next_back());
    let far_after = s.get(at + after.len_utf8()..).and_then(|t| t.chars().next());
    word_side(before, far_before) && word_side(after, far_after)
}

/// The one line a hand-drawn selection is about, when it was drawn across more
/// than one.
///
/// A value is a thing on one line: 046/C says a name ends where the name ends,
/// and the owner's own file says a drag does too. A selection that crosses a
/// line break is an overshoot at one end of it — the person was aiming at one of
/// the two lines, never at both — so this answers which line it is an overshoot
/// *of*: the one it holds the most of, and the first of them when two hold the
/// same. A piece that is only spaces has nothing in it to be aiming at and is
/// not a candidate.
///
/// Counted in characters and not in bytes, because a line of Arabic is two bytes
/// a letter and would otherwise outweigh a longer line of Swedish — and only
/// the characters that are not space, because a column of padding and the form
/// feed that marks a page are not what anybody is aiming at.
///
/// `None` when the selection stays on one line, which is almost every selection.
fn one_line_of(s: &str, start: usize, end: usize) -> Option<(usize, usize)> {
    let drawn = s.get(start..end)?;
    // **A line ends at `\n` or at `\r`** — the second case of one rule, found
    // while the owner's white-space ruling of 14 Oct was being built. The
    // readers hand a document over as it is, so a Windows file keeps its
    // `\r\n`: before this, the `\r` was whitespace and nothing else, and a
    // selection drawn across a lone carriage return — a classic Mac line, and
    // what a `\r\n` looks like to anything reading one character at a time —
    // was not recognised as crossing a line at all. A `\r\n` gives an empty
    // piece between the two, which the skip below already drops.
    if !drawn.contains(['\n', '\r']) {
        return None;
    }
    let mut best: Option<(usize, usize, usize)> = None;
    let mut at = start;
    for piece in drawn.split(['\n', '\r']) {
        let (from, to) = (at, at + piece.len());
        at = to + 1;
        if piece.trim().is_empty() {
            continue;
        }
        let characters = piece.chars().filter(|c| !c.is_whitespace()).count();
        if best.is_none_or(|(_, _, most)| characters > most) {
            best = Some((from, to, characters));
        }
    }
    best.map(|(from, to, _)| (from, to))
}

/// Grow a selection out to whole words, and drop the marks at its edges.
///
/// The owner, 6 October, from a live run: protections came out as `J__Z_…`,
/// `S__Z_…` and `Björn __Z_…`, and a token with a stray letter in front of it
/// is a leak of the first letter of a name. The cause is not the person's aim —
/// at the left margin the mouse lands *after* the first character, every time —
/// and the fix is not to ask them to aim better.
///
/// Three rules, in this order:
///
/// 0. **One line.** A selection drawn across a line break is cut down to the
///    line it holds most of, before anything grows. Without this, rule 1 grows
///    the overshoot outward into a whole word on the *other* line: two
///    characters past «559000-0000» on the owner's payroll file protected
///    «559000-0000\nAdress», which joined two of his lines into one, took the
///    word «Adress» out of what the model receives, and stored a value that is
///    never that organisation number again. Protection may not change how a
///    document reads. A **page** break counts as a line break here: the
///    scanner's pair rule already refuses to read across one (038-I), and what
///    still crosses it is an exact value the person pointed at, which is a
///    different kind of claim from a drag.
/// 1. **Out, never in.** Each end moves outward while the character beside it
///    belongs to the same word, so a drag that starts one letter late still
///    takes the whole name. A selection that already covers whole words does
///    not move at all.
/// 2. **Then the edges are tidied**, of the marks a sentence puts around a word
///    and never of the ones a value is made of. So «Müller,» becomes «Müller»
///    and «+49 228» stays exactly as it was drawn.
///
/// **The words inside one stretch**, each tidied of the marks around it.
///
/// The other half of `whole_words`, and written from the same two clauses so
/// that the answers cannot drift apart: whitespace separates words, and at an
/// edge a mark leaves. What this adds is only the question — `whole_words` asks
/// «which word is this?» about a place a person pointed at, and this asks
/// «which words are these?» about a stretch a rule handed back.
///
/// Byte offsets into `s`, in order, and a run that is nothing but marks is not
/// a word and is not returned — so «Lindemann, Katharina» is two words and the
/// comma between them belongs to neither.
pub(crate) fn words_in(s: &str, start: usize, end: usize) -> Vec<(usize, usize)> {
    let (start, end) = (start.min(s.len()), end.min(s.len()));
    let Some(slice) = s.get(start..end) else { return Vec::new() };
    let mut runs: Vec<(usize, usize)> = Vec::new();
    let mut run: Option<(usize, usize)> = None;
    for (at, c) in slice.char_indices() {
        if c.is_whitespace() {
            runs.extend(run.take());
            continue;
        }
        match &mut run {
            Some((_, stop)) => *stop = at + c.len_utf8(),
            None => run = Some((at, at + c.len_utf8())),
        }
    }
    runs.extend(run.take());
    runs.into_iter()
        .filter_map(|(mut from, mut to)| {
            while let Some(c) = slice.get(from..to).and_then(|t| t.chars().next()) {
                if !is_edge_mark(c) {
                    break;
                }
                from += c.len_utf8();
            }
            while let Some(c) = slice.get(from..to).and_then(|t| t.chars().next_back()) {
                if !is_edge_mark(c) {
                    break;
                }
                to -= c.len_utf8();
            }
            (from < to).then_some((start + from, start + to))
        })
        .collect()
}

/// Returns byte offsets into `s`, and never returns an empty range: a selection
/// of nothing but marks is handed back untouched for the caller to refuse.
pub(crate) fn whole_words(s: &str, start: usize, end: usize) -> (usize, usize) {
    let (mut start, mut end) = (start.min(s.len()), end.min(s.len()));
    if start >= end {
        return (start, end);
    }

    // 0. One line, chosen before any edge moves. The growth in rule 1 is what
    //    turns a two-character overshoot into a whole word on the next line,
    //    and it cannot be stopped at the break: by the time it runs, the break
    //    is already inside the span the person drew.
    if let Some((line_start, line_end)) = one_line_of(s, start, end) {
        start = line_start;
        end = line_end;
    }

    // 1. Outward, but only while the edge stands **in the middle of a word**.
    //    An edge that already sits on a space or a mark is where the person
    //    put it, and moving it would swallow the next word — «Sandström, »
    //    must not become «Sandström, tack».
    while cuts_a_word(s, start) {
        match s.get(..start).and_then(|head| head.chars().next_back()) {
            Some(c) => start -= c.len_utf8(),
            None => break,
        }
    }
    while cuts_a_word(s, end) {
        match s.get(end..).and_then(|tail| tail.chars().next()) {
            Some(c) => end += c.len_utf8(),
            None => break,
        }
    }

    // 2. Inward, over the marks a sentence leaves at an edge — and over the
    //    space a drag picks up past the end of a word.
    let tidy = |c: char| is_edge_mark(c) || c.is_whitespace();
    while let Some(c) = s.get(start..end).and_then(|t| t.chars().next()) {
        if !tidy(c) {
            break;
        }
        start += c.len_utf8();
    }
    while let Some(c) = s.get(start..end).and_then(|t| t.chars().next_back()) {
        if !tidy(c) {
            break;
        }
        end -= c.len_utf8();
    }
    if start >= end {
        return (start.min(end), end.max(start));
    }
    (start, end)
}

/// The one-letter words Arabic writes **attached** to the next word.
///
/// «ودمنة» is «and Dimna»; «لدمنة» is «for Dimna». The name is the same name,
/// and a reader sees one word. So a value may carry exactly one of these in
/// front of it and still be that value — and nothing may be attached after it,
/// because what follows a name in Arabic is a different word or a vowel mark.
///
/// «مدمنة» is not «م + دمنة»: `م` is not one of these, and that is the whole
/// difference between a clitic and the first letter of another word.
const ARABIC_CLITICS: &[char] = &['و', 'ب', 'ل', 'ف', 'ك'];

/// Which rule about word edges a script keeps.
enum Edges {
    /// Written with spaces between words: a value must stand between them.
    BetweenSpaces,
    /// The same, but one attached clitic may stand in front.
    ArabicClitics,
    /// Written without spaces between words, so there is no edge to test and
    /// a substring is the only thing a match can be. Chinese, Japanese, Thai.
    None,
}

fn edges_of(value: &str) -> Edges {
    for c in value.chars() {
        if !c.is_alphabetic() {
            continue;
        }
        return match c {
            // Arabic, and its supplements and presentation forms.
            '\u{0600}'..='\u{06FF}'
            | '\u{0750}'..='\u{077F}'
            | '\u{08A0}'..='\u{08FF}'
            | '\u{FB50}'..='\u{FDFF}'
            | '\u{FE70}'..='\u{FEFF}' => Edges::ArabicClitics,
            // The scripts that put no space between words.
            '\u{0E00}'..='\u{0E7F}'
            | '\u{1000}'..='\u{109F}'
            | '\u{1780}'..='\u{17FF}'
            | '\u{2E80}'..='\u{9FFF}'
            | '\u{AC00}'..='\u{D7AF}'
            | '\u{F900}'..='\u{FAFF}' => Edges::None,
            _ => Edges::BetweenSpaces,
        };
    }
    // Digits and marks only — an account number, a date. Those have edges.
    Edges::BetweenSpaces
}

/// A mark that belongs to the letter beside it rather than standing as a
/// letter of its own: the Arabic harakat, and the combining accents.
///
/// Unicode gives the harakat the **Alphabetic** property, so `دمنةٌ` ends in
/// something `char::is_alphanumeric` calls a letter. Reading that as the start
/// of another word would undo a measured part of the contract: §4.3 of
/// `docs/THE_NUMBERS.md` says a taught value must match *through* the vowel
/// marks, and 101 of the book's occurrences carry one.
fn is_attached_mark(c: char) -> bool {
    matches!(c,
        '\u{0300}'..='\u{036F}'      // combining accents
        | '\u{064B}'..='\u{065F}'    // Arabic harakat
        | '\u{0670}'
        | '\u{06D6}'..='\u{06ED}'    // Quranic marks
        | '\u{0E31}' | '\u{0E34}'..='\u{0E3A}' | '\u{0E47}'..='\u{0E4E}'
    )
}

/// The letter standing before this position, with any marks attached to it
/// stepped over.
fn letter_before(s: &str, at: usize) -> Option<char> {
    s.get(..at)?.chars().rev().find(|c| !is_attached_mark(*c))
}

/// The letter standing after this position, likewise.
fn letter_after(s: &str, at: usize) -> Option<char> {
    s.get(at..)?.chars().find(|c| !is_attached_mark(*c))
}

/// Does the text at `start..end` stand as a value of its own, or is it a piece
/// of a longer word?
///
/// The owner, 6 October, from a live run on a Swedish page: he selected «Sven»
/// and — through the placeholder bug 041-K closed — «ven» reached the library.
/// The matcher then found it inside «Svensk» and «svenska» and wrote
/// `S__Z_…sk` into the text three times. 041-K closed the source of the
/// fragment; this closes what a fragment can do.
///
/// Measured, 6 October, on one Swedish line holding «Sven», «svensk» and
/// «Svensk»: «ven» taught matched **3** places and now matches **0**; «Sven»
/// taught matched 2 (one of them inside «Svensk») and now matches 1. And on
/// the Arabic book through the §4.3 path, the five taught characters matched
/// **462** places and still match 462 — the clitics are the reason the rule
/// has an Arabic half at all.
/// Every place `needle` stands in `haystack`, as byte ranges, left to right and
/// without overlapping — **whatever case either of them is written in**.
///
/// 041-R, from the owner's own file: «Leifland» and «Wihlborg» were in his list
/// and protected in the running text, and left in the clear in
/// «TEXT: CRISTINA LEIFLAND». Six places. A name is the same name shouted.
///
/// **Two things this is careful about, and both are the reason it is not a
/// `to_lowercase()` on each side and a `find`:**
///
/// * **The range returned is the haystack's own.** Lowercasing can change a
///   string's length (`İ` becomes two code points), so a span measured on a
///   lowercased copy can land in the middle of a character of the original.
///   An offset that is one out is a protection in the wrong place — the
///   mistake this project will not make twice. So the haystack is walked as it
///   is, and only the comparison is case-blind.
/// * **A match must end on a character boundary.** If a haystack character
///   expands to two lowercase ones and the needle only wants the first, that is
///   not a match: there would be no honest byte to end it at.
///
/// **What it does not claim:** this is `char::to_lowercase`, the simple
/// mapping, not full Unicode case folding. Measured consequence — German `ß`
/// and `SS` are *not* the same here (`'ß'.to_lowercase()` is `ß`), so a vault
/// value «Weiß» is not found in «WEISS». That is a real gap and it is written
/// down rather than implied; closing it needs a folding table, and the owner's
/// Swedish and German lists do not need one today.
///
/// Case is read as a **signal** by the packs — a capital is how German marks a
/// noun — and none of that changes: this function is what the vault layer and
/// «protect every place» use to find a value they were *given*, never what a
/// rule uses to decide whether a word looks like a name.
pub(crate) fn occurrences(haystack: &str, needle: &str) -> Vec<(usize, usize)> {
    let mut out = Vec::new();
    let Some(first) = needle.chars().next().and_then(|c| c.to_lowercase().next()) else {
        return out;
    };
    let mut from = 0usize;
    while from < haystack.len() {
        let Some(here) = haystack.get(from..).and_then(|r| r.chars().next()) else {
            break;
        };
        // A cheap gate before the character-by-character walk: on a 200,000-word
        // document the walk is asked at every position otherwise.
        if here.to_lowercase().next() == Some(first) {
            if let Some(len) = case_blind_match(haystack, from, needle) {
                let end = from + len;
                if stands_alone(haystack, from, end) {
                    out.push((from, end));
                }
                // Past this one either way: a fragment inside a word does not
                // become a match by being looked at again.
                from = end;
                continue;
            }
        }
        from += here.len_utf8();
    }
    out
}

/// How many **haystack bytes** `needle` takes starting at `start`, comparing
/// without regard to case and across the breaks a page puts inside a word, or
/// `None` if it is not there.
fn case_blind_match(haystack: &str, start: usize, needle: &str) -> Option<usize> {
    let want: Vec<char> = needle.chars().flat_map(char::to_lowercase).collect();
    let mut w = 0usize;
    let mut at = start;
    // The lowercase characters of the haystack character we are part way
    // through, in reverse so the next one is the last.
    let mut pending: Vec<char> = Vec::new();

    while let Some(&wanted) = want.get(w) {
        if pending.is_empty() {
            // **A word the page broke.** 038-I: `Yn-` at the end of a line and
            // `nerman` at the start of the next are one surname, and half a
            // protected name travelling to a model is worse than none. Skipped
            // only where the value itself has no hyphen there, so «Anna-Lena»
            // broken after its own hyphen is still «Anna-Lena» and not
            // «AnnaLena».
            if wanted != '-' {
                if let Some(skip) = line_break_hyphen(haystack, at) {
                    at += skip;
                    continue;
                }
            } else if haystack
                .get(at..)
                .and_then(|r| r.chars().next())
                .is_some_and(|c| matches!(c, '-' | '\u{2010}' | '\u{ad}'))
            {
                // **A name's own hyphen, broken at exactly that hyphen.**
                // «Anna-Lena» printed as «Anna-\nLena» is still «Anna-Lena»:
                // the hyphen is matched as itself, and the line break behind it
                // is the page's, not the name's. Narrow on purpose — only ever
                // right after a hyphen the value itself asked for, so two
                // ordinary words on two lines are never run together.
                let c = haystack.get(at..)?.chars().next()?;
                at += c.len_utf8();
                w += 1;
                // Only where the value does not ask for the break itself.
                //
                // **Measured, and it cost a wrong diagnosis:** the automatic
                // path re-protects every place the matched text appears by
                // handing that text back here as the needle — so a needle may
                // arrive already carrying `-\n`. Eating the break here left
                // «Yn-\nnerman» unable to find itself, and the whole finding
                // vanished rather than failing loudly.
                if want.get(w).is_some_and(|c| !c.is_whitespace()) {
                    at += whitespace_run(haystack, at);
                }
                continue;
            }
            // **A space in the value is any run of space in the text**, so a
            // value of more than one word survives being wrapped. The run is
            // taken whole: a line break between two words is one gap, not two.
            if wanted.is_whitespace() {
                let run = whitespace_run(haystack, at);
                if run > 0 {
                    at += run;
                    while want.get(w).is_some_and(|c| c.is_whitespace()) {
                        w += 1;
                    }
                    continue;
                }
            }
            let c = haystack.get(at..)?.chars().next()?;
            at += c.len_utf8();
            pending = c.to_lowercase().collect();
            pending.reverse();
        }
        if pending.pop()? != wanted {
            return None;
        }
        w += 1;
    }
    // The needle is spent. It has to have ended where a haystack character
    // ends, or there is no byte to call the end.
    pending.is_empty().then_some(at - start)
}

/// A hyphen that is there because the line ended, and how many bytes it and the
/// break after it take.
///
/// The owner's rule, and it is what tells a break from a real compound: the
/// hyphen is the last thing on its line, and **the next line begins with a
/// small letter**. A line that begins with a capital is a new word, so the
/// hyphen before it is the word's own.
fn line_break_hyphen(haystack: &str, at: usize) -> Option<usize> {
    let rest = haystack.get(at..)?;
    let mut chars = rest.char_indices();
    // Any of the three a reader may leave behind: the ordinary hyphen-minus,
    // the typographic hyphen, and the soft hyphen that means exactly this.
    let (_, first) = chars.next()?;
    if !matches!(first, '-' | '\u{2010}' | '\u{ad}') {
        return None;
    }
    let mut seen_break = false;
    for (offset, c) in chars {
        match c {
            '\n' | '\r' => seen_break = true,
            // **Any white-space between the hyphen and the break**, not the two
            // kinds that happened to be written here — the owner's rule of
            // 14 Oct, in the third place this file decides what a space is. A
            // PDF that writes a no-break space or a thin space before the line
            // end is ordinary, and before this it made the hyphen «belong to
            // the text» and left the name broken in half.
            // **Any white-space between the hyphen and the break**, not the two
            // kinds that happened to be written here — the owner's rule of
            // 14 Oct, in the third place this file decides what a space is. A
            // PDF that writes a no-break space or a thin space before the line
            // end is ordinary, and before this it made the hyphen «belong to
            // the text» and left the name broken in half.
            _ if c.is_whitespace() => {}
            _ if seen_break => {
                // The first real character of the next line decides.
                return c.is_lowercase().then_some(offset);
            }
            // Something other than space between the hyphen and the end of the
            // line: this hyphen belongs to the text.
            _ => return None,
        }
    }
    None
}

/// How many bytes of whitespace start here.
fn whitespace_run(haystack: &str, at: usize) -> usize {
    haystack
        .get(at..)
        .map(|rest| {
            rest.chars()
                .take_while(|c| c.is_whitespace())
                .map(char::len_utf8)
                .sum()
        })
        .unwrap_or(0)
}

pub(crate) fn stands_alone(s: &str, start: usize, end: usize) -> bool {
    let Some(value) = s.get(start..end) else {
        return false;
    };
    let before = letter_before(s, start);
    let after = letter_after(s, end);
    let open = |c: Option<char>| c.is_none_or(|c| !c.is_alphanumeric());

    match edges_of(value) {
        Edges::None => true,
        Edges::BetweenSpaces => open(before) && open(after),
        Edges::ArabicClitics => {
            if !open(after) {
                return false;
            }
            if open(before) {
                return true;
            }
            // What is attached in front must be clitics and nothing else, all
            // the way back to a space. «ودمنة» and «ولدمنة» are both the name
            // with words attached; «مدمنة» is another word, because `م` is not
            // one of the five. The leader's rule said one letter; Arabic writes
            // «ولـ» and «وبـ» as readily as «وـ», and measured on the book the
            // two readings give the same 462 — so the faithful one is here,
            // and narrowing it back is one line.
            let mut at = start;
            loop {
                match letter_before(s, at) {
                    None => return true,
                    Some(c) if ARABIC_CLITICS.contains(&c) => at -= c.len_utf8(),
                    Some(c) => return !c.is_alphanumeric(),
                }
            }
        }
    }
}

/// The whole word standing immediately before this one, when it is capitalised
/// and only a single space away — «Björn» before «Sandström».
///
/// A question, never an act: a surname selected on its own is the commonest
/// thing a person does, and taking the given name with it unasked would protect
/// a word nobody chose. The screen offers it; the core only finds it.
pub(crate) fn capitalised_word_before(s: &str, start: usize) -> Option<(usize, usize)> {
    let head = s.get(..start)?;
    let gap = head.chars().next_back()?;
    if gap != ' ' {
        return None;
    }
    let end = start - gap.len_utf8();
    let (word_start, word_end) = whole_words(s, end.checked_sub(1)?, end);
    let word = s.get(word_start..word_end)?;
    let first = word.chars().next()?;
    if !first.is_uppercase() || word.chars().count() < 2 {
        return None;
    }
    Some((word_start, word_end))
}

#[cfg(test)]
mod tests {
    use super::*;

    const GERMAN: &str = "Herr Thomas Müller";
    // "Müller" holds a two-byte ü; the emoji is two UTF-16 units and four bytes.
    const MIXED: &str = "Kunde 🏭 Müller";

    #[test]
    fn utf16_and_bytes_agree_on_ascii() {
        assert_eq!(utf16_len("Herr"), 4);
        assert_eq!(utf16_to_byte(GERMAN, 5), Ok(5));
        assert_eq!(bytes_to_span(GERMAN, 5, 11), Ok(Span { start: 5, end: 11 }));
    }

    #[test]
    fn a_two_byte_character_shifts_the_byte_offset_but_not_the_span() {
        // Dart sees "Müller" starting at unit 12; in bytes it is also 12, but
        // its end differs: 6 units, 7 bytes.
        let start_units = 12;
        let start_bytes = utf16_to_byte(GERMAN, start_units).expect("start");
        assert_eq!(&GERMAN[start_bytes..], "Müller");
        assert_eq!(utf16_len("Müller"), 6);
        assert_eq!("Müller".len(), 7);
    }

    #[test]
    fn an_emoji_counts_two_units_and_cannot_be_cut() {
        assert_eq!(utf16_len(MIXED), 15);
        let emoji_at = utf16_to_byte(MIXED, 6).expect("emoji start");
        assert!(MIXED[emoji_at..].starts_with('🏭'));
        // Unit 7 is the middle of the surrogate pair: refused, not trimmed.
        assert!(matches!(utf16_to_byte(MIXED, 7), Err(ApiError::BadSpan { .. })));
    }

    #[test]
    fn past_the_end_is_refused() {
        assert!(matches!(utf16_to_byte(GERMAN, 999), Err(ApiError::BadSpan { .. })));
        assert_eq!(utf16_to_byte(GERMAN, utf16_len(GERMAN)), Ok(GERMAN.len()));
    }

    #[test]
    fn reversed_and_empty_selections_are_refused() {
        assert!(matches!(
            span_to_bytes(GERMAN, Span { start: 5, end: 5 }),
            Err(ApiError::BadSpan { .. })
        ));
        assert!(matches!(
            span_to_bytes(GERMAN, Span { start: 9, end: 4 }),
            Err(ApiError::BadSpan { .. })
        ));
    }

    /// What `occurrences` finds, as the text it covers — the pure function on
    /// its own, before any vault, pack or screen is involved.
    fn found<'a>(haystack: &'a str, needle: &str) -> Vec<&'a str> {
        occurrences(haystack, needle)
            .into_iter()
            .map(|(a, b)| &haystack[a..b])
            .collect()
    }

    #[test]
    fn a_value_is_found_whatever_its_case() {
        assert_eq!(
            found("Leifland och LEIFLAND och leifland", "Leifland"),
            vec!["Leifland", "LEIFLAND", "leifland"]
        );
    }

    #[test]
    fn a_word_the_page_broke_is_one_word() {
        assert_eq!(found("Anders Yn-\nnerman leder", "Ynnerman"), vec!["Yn-\nnerman"]);
        // The indent the next line may carry goes with it.
        assert_eq!(found("Yn-\n   nerman", "Ynnerman"), vec!["Yn-\n   nerman"]);
    }

    /// **What this finds, it must be able to find again.**
    ///
    /// The automatic path protects every place the matched text appears by
    /// handing that text back as the needle, so a needle may arrive already
    /// carrying the break the page put in it. A matcher that cannot find its
    /// own answer drops the finding altogether — which is how this was found,
    /// as zero marks rather than as a wrong one.
    #[test]
    fn what_it_finds_it_can_find_again() {
        let doc = "Professor Anders Yn-\nnerman leder gruppen.\n";
        let first = found(doc, "Ynnerman");
        assert_eq!(first, vec!["Yn-\nnerman"]);
        assert_eq!(found(doc, first[0]), first, "the matcher cannot find its own answer");

        let own = "H\u{e4}lsningar Anna-\nLena Bergstr\u{f6}m\n";
        let hit = found(own, "Anna-Lena Bergstr\u{f6}m");
        assert_eq!(hit, vec!["Anna-\nLena Bergstr\u{f6}m"]);
        assert_eq!(found(own, hit[0]), hit);
    }

    #[test]
    fn a_capital_after_the_break_keeps_the_hyphen() {
        assert!(found("Anna-\nLena", "AnnaLena").is_empty());
        assert_eq!(found("Anna-\nLena", "Anna-Lena"), vec!["Anna-\nLena"]);
    }

    #[test]
    fn a_space_in_the_value_is_any_space_in_the_text() {
        assert_eq!(
            found("Kungl.\nIngenj\u{f6}rs", "Kungl. Ingenj\u{f6}rs"),
            vec!["Kungl.\nIngenj\u{f6}rs"]
        );
        // But a gap the value does not ask for is not crossed.
        assert!(found("Sven\nNelander", "SvenNelander").is_empty());
    }

    #[test]
    fn the_range_is_the_haystack_s_own_even_when_lowercase_is_longer() {
        // `\u{130}` lowercases to two code points, so the value is a byte
        // longer than the text it matches.
        assert_eq!(found("Fabrik \u{130}stanbul AB", "i\u{307}stanbul"), vec!["\u{130}stanbul"]);
    }

    #[test]
    fn a_piece_of_a_word_is_not_the_word() {
        assert!(found("Nordsternstra\u{df}e", "Nordstern").is_empty());
    }

    /// 053 — a newline was never a word character, so rule 1's growth has
    /// always stopped *at* a line break. Both of these were already false on
    /// 82d5858, before this item changed anything, which is why rule 0 had to
    /// exist: the harm was never growth across a break, it was growth on the far
    /// side of a break the person had already drawn across.
    #[test]
    fn a_line_break_never_cut_a_word() {
        assert!(!cuts_a_word("0\nA", 1), "the boundary before the break");
        assert!(!cuts_a_word("0\nA", 2), "the boundary after it");
        assert!(cuts_a_word("0\nAd", 3), "and inside the word on the next line it did");
    }

    /// Rule 0's own answer: the line the selection holds most of.
    #[test]
    fn one_line_of_picks_the_line_the_selection_holds_most_of() {
        let s = "Organisationsnummer: 559000-0000\nAdress: Storgatan 1\n";
        let value = s.find("559000-0000").expect("the value");
        // Two characters past the end of the organisation number.
        assert_eq!(one_line_of(s, value, value + 13), Some((value, value + 11)));
        // The same overshoot backwards, from inside the line below.
        let adress = s.find("Adress").expect("the label");
        assert_eq!(one_line_of(s, adress - 2, adress + 6), Some((adress, adress + 6)));
        // A selection that stays on one line is not this function's business.
        assert_eq!(one_line_of(s, value, value + 11), None);
        // Two halves of the same size: the one the selection started on, so the
        // answer does not depend on which way the person dragged.
        assert_eq!(one_line_of("AB\nCD\n", 0, 5), Some((0, 2)));
        // A page break is a line break as well. 041-L used to need the
        // opposite — a hand selection drawn across a page boundary — and that
        // was its *setup*, not its subject: a break is still swallowed by «every
        // place this value appears», because the matcher reads an exact value
        // across any run of whitespace. So this rule has no exception.
        assert_eq!(one_line_of("AB\n\u{c}CD\n", 0, 6), Some((0, 2)));
    }

    /// **A carriage return ends a line too** — the second case of the owner's
    /// white-space ruling of 14 Oct, in the one place the core decides what a
    /// line is.
    ///
    /// The readers hand a document over as it is, measured: a Windows file
    /// keeps its `\r\n`. Before this, `\r` was whitespace like any other and a
    /// lone one was not a line at all — so a drag across it took both sides.
    #[test]
    fn a_carriage_return_ends_a_line_as_a_newline_does() {
        // Windows: the `\r\n` leaves an empty piece between the two lines, and
        // the answer is the same as for `\n` alone.
        assert_eq!(one_line_of("AB\r\nCDE\r\n", 0, 7), Some((4, 7)));
        // And a lone carriage return, which is what the old rule could not see.
        assert_eq!(one_line_of("AB\rCDE\r", 0, 6), Some((3, 6)));
        // One line is still not this function's business, `\r` or no `\r`.
        assert_eq!(one_line_of("AB\r\nCDE\r\n", 4, 7), None);
    }

    /// **The third place, and the same rule**: any white-space may stand
    /// between a hyphen and the line break it was written for.
    ///
    /// `line_break_hyphen` knew `' '` and `'\t'`. A PDF that puts a no-break
    /// space or a thin space there is ordinary, and the old reading called the
    /// hyphen the text's own — so «Yn-\u{a0}\nnerman» stayed two halves and the
    /// name was never found.
    #[test]
    fn any_white_space_may_stand_between_a_hyphen_and_the_break() {
        for gap in ["", " ", "\t", "\u{a0}", " \u{2009}", "\u{3000}"] {
            let s = format!("Yn-{gap}\nnerman");
            let at = s.find('-').expect("the hyphen");
            assert!(
                line_break_hyphen(&s, at).is_some(),
                "«{gap:?}» between the hyphen and the break"
            );
            assert_eq!(
                occurrences(&s, "Ynnerman").len(),
                1,
                "«{gap:?}»: the name broken by the page was not found whole"
            );
        }
        // And what is not white-space still means the hyphen is the text's own.
        let s = "Anna-Lena\nkommt";
        assert_eq!(occurrences(s, "AnnaLena").len(), 0);
    }

    /// **Every kind of white-space is one boundary, and a run of it is one** —
    /// the owner, 14 Oct. The core already read it that way through
    /// `char::is_whitespace`; this is the guard that says so, beside the glass's
    /// own (`a_click_takes_one_word_test.dart`), because the two must agree
    /// about what a space is or 085's defect comes back with a different list.
    #[test]
    fn a_run_of_any_white_space_is_one_boundary() {
        for gap in ["  ", "\t", "\u{a0}", " \t ", "\u{2000}", "\u{3000}", "   \u{a0}\t"] {
            let s = format!("Herr{gap}Mueller");
            let end = s.len();
            // A drag that takes the whole of it keeps the whole of it: the run
            // is inside the span, not at an edge.
            assert_eq!(whole_words(&s, 0, end), (0, end), "«{gap:?}» inside");
            // A drag that overshoots into the run is tidied back to the word,
            // whatever the run is made of.
            let four = "Herr".len();
            assert_eq!(
                whole_words(&s, 0, four + gap.len()),
                (0, four),
                "«{gap:?}» at an edge"
            );
        }
        // And the one that is not a space to Unicode: the byte-order mark is a
        // **mark**, so it is trimmed as one rather than being a boundary.
        assert!(is_edge_mark('\u{feff}'));
        assert!(!is_edge_mark('\u{a0}'));
    }
}

#[cfg(test)]
mod the_marks_a_hand_selection_leaves_behind {
    //! **076 — the edges of a value a hand drew.**
    //!
    //! The owner sealed the rule on 13 Oct: the marks `. , - \' " : ; ,` are
    //! left **outside** the value when a space touches them, and the start and
    //! end of a line count as a space (the lead's reading, measured here). The
    //! person never trims a selection by hand.
    //!
    //! These are guards on the rule that already exists — `whole_words` — and
    //! not a second rule: two functions for one law is the «one fact, two
    //! sources» defect this project has paid for twice. Each case here was
    //! measured against the function before it was written down.
    use super::whole_words;

    /// What the value is after the selection the person drew is tidied.
    fn value<'a>(text: &'a str, drawn: &str) -> &'a str {
        let start = text.find(drawn).expect("the sample must contain its selection");
        let (a, b) = whole_words(text, start, start + drawn.len());
        &text[a..b]
    }

    #[test]
    fn a_mark_the_sentence_left_at_an_edge_stays_out_of_the_value() {
        for mark in ['.', '\u{060C}', '\'', '"', ':', ';', ','] {
            let text = format!("Herr Mueller{mark} bitte");
            let drawn = format!("Mueller{mark}");
            assert_eq!(value(&text, &drawn), "Mueller", "trailing {mark:?}");

            let text = format!("Herr {mark}Mueller bitte");
            let drawn = format!("{mark}Mueller");
            assert_eq!(value(&text, &drawn), "Mueller", "leading {mark:?}");
        }
    }

    /// **The hyphen's pin is closed by the owner, not by us.**
    ///
    /// 076 recorded a divergence: his sealed list named the plain hyphen and
    /// the core's list held only the em and en dashes, so `Mueller-` kept its
    /// dash. Paper 085's ruling 3 — «every mark on the keyboard» — answers it
    /// and this guard now asserts the answer rather than the divergence.
    #[test]
    fn a_hyphen_at_an_edge_leaves_the_value() {
        assert_eq!(value("Herr Mueller- bitte", "Mueller-"), "Mueller");
        assert_eq!(value("Herr -Mueller bitte", "-Mueller"), "Mueller");
        assert_eq!(value("call Mueller-\nNext", "Mueller-"), "Mueller");
        // And inside a word it is still part of it, which is the whole point of
        // «only when a space touches it».
        assert_eq!(value("Anne-Marie Berg", "Anne-Marie"), "Anne-Marie");
    }

    /// **Ruling 3, 085: every mark the keyboard has.**
    ///
    /// The owner, 14 Oct: «وبالنسبة للرموز لا أقصد فقط هذه الرموز… بل جميع
    /// الرموز الموجودة في الكيبورد». The lead's reading is everything Unicode
    /// calls punctuation or a symbol, and the law is written as its complement:
    /// a mark is whatever is **not** a letter, a digit, a space, or a mark that
    /// belongs to the letter before it.
    #[test]
    fn every_mark_the_keyboard_has_leaves_an_edge() {
        for mark in [
            '!', '?', '(', ')', '[', ']', '{', '}', '<', '>', '@', '#', '$', '%', '&', '*', '+',
            '=', '/', '\\', '|', '~', '^', '_', '\u{A7}', '\u{B4}', '\u{A8}', '\u{2026}',
            '\u{AB}', '\u{BB}', '\u{201E}', '\u{201C}', '\u{201D}', '\u{2019}', '\u{2014}',
            '\u{2013}', '\u{60C}', '\u{61B}', '\u{61F}',
        ] {
            let text = format!("Herr Mueller{mark} bitte");
            let drawn = format!("Mueller{mark}");
            assert_eq!(value(&text, &drawn), "Mueller", "trailing {mark:?}");

            let text = format!("Herr {mark}Mueller bitte");
            let drawn = format!("{mark}Mueller");
            assert_eq!(value(&text, &drawn), "Mueller", "leading {mark:?}");
        }
    }

    /// **A diacritic is not a mark around a word; it is part of the letter.**
    ///
    /// This is the guard that forbids the cheap reading of ruling 3. «Every
    /// mark on the keyboard» written as «anything that is not a letter or a
    /// digit» would strip the Arabic harakat from the end of a name — and Z's
    /// Arabic is a whole script family. A combining mark is excluded by name,
    /// and `unicode-normalization` is already in the tree for NFC, so the
    /// answer costs no new crate.
    #[test]
    fn a_diacritic_belongs_to_the_word_and_is_not_an_edge_mark() {
        // «ويلسونَ» — the fatha at the end of the name stays in the value.
        let text = "\u{627}\u{62A}\u{635}\u{644} \u{648}\u{64A}\u{644}\u{633}\u{648}\u{646}\u{64E} \u{63A}\u{62F}\u{627}";
        let drawn = "\u{648}\u{64A}\u{644}\u{633}\u{648}\u{646}\u{64E}";
        assert_eq!(value(text, drawn), drawn);
        // A Latin letter written as letter + combining acute keeps its accent.
        assert_eq!(value("Herr Jose\u{301} bitte", "Jose\u{301}"), "Jose\u{301}");
    }

    /// **Measured, and the owner may want it back: a leading `+` leaves too.**
    ///
    /// The old list was written with a reason — «`+` opens a telephone number,
    /// `@` holds an address together, `/` and `#` carry a reference number» —
    /// and ruling 3 overrules it for a hand selection. So `+49 228` drawn by
    /// hand now yields `49 228`. Paper 085's ruling 2 is what makes this
    /// bearable: **numbers are not words** and get their own rules in their own
    /// paper, where the `+` can be given back to them by kind rather than by
    /// accident of the edge list. Until then this records what the glass does.
    #[test]
    fn a_plus_in_front_of_a_number_leaves_the_value_now() {
        assert_eq!(value("tel +49 228 oder", "+49 228"), "49 228");
        assert_eq!(value("ref #4711 bitte", "#4711"), "4711");
        // Interior, and therefore untouched: an address is still one value.
        assert_eq!(value("mail anas@mono-peak.com heute", "anas@mono-peak.com"), "anas@mono-peak.com");
    }

    #[test]
    fn the_start_and_the_end_of_a_line_count_as_a_space() {
        assert_eq!(value("call Margaret.\nNext line", "Margaret."), "Margaret");
        assert_eq!(value("Margaret, called\nlater", "Margaret,"), "Margaret");
    }

    #[test]
    fn an_arabic_comma_at_the_end_of_a_right_to_left_line() {
        assert_eq!(value("\u{645}\u{627}\u{631}\u{63A}\u{631}\u{64A}\u{62A} \u{648}\u{64A}\u{644}\u{633}\u{648}\u{646}\u{60C} \u{634}\u{62E}\u{635}",
                         "\u{648}\u{64A}\u{644}\u{633}\u{648}\u{646}\u{60C}"),
                   "\u{648}\u{64A}\u{644}\u{633}\u{648}\u{646}");
    }

    #[test]
    fn a_mark_a_value_is_made_of_is_not_an_edge_mark() {
        assert_eq!(value("Anne-Marie Berg", "Anne-Marie"), "Anne-Marie");
        assert_eq!(value("O\'Brien and Sons", "O\'Brien"), "O\'Brien");
        assert_eq!(value("Margaret Wilson,person", "Wilson,person"), "Wilson,person");
        // The `+` is at an edge, so ruling 3 takes it; the space inside the
        // number is not a mark and the digits stay whole. Named on its own in
        // `a_plus_in_front_of_a_number_leaves_the_value_now`.
        assert_eq!(value("tel +49 228 oder", "+49 228"), "49 228");
    }

    #[test]
    fn one_click_on_a_name_in_a_cell_takes_the_name() {
        assert_eq!(value("Margaret Wilson,person", "Margaret"), "Margaret");
        assert_eq!(value("Margaret Wilson,person", "Wilson"), "Wilson");
    }
}

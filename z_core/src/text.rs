//! Offsets. The contract counts UTF-16 code units because Dart does; Rust
//! counts bytes. Every crossing goes through here, and a span that would cut a
//! character is refused rather than trimmed.

use unicode_normalization::UnicodeNormalization;

use crate::api::{ApiError, ApiResult, Span};

/// One Unicode composition, so that «Müller» written two ways is one value.
///
/// Invariant G3 compares values in this form: a leak test that compares raw
/// bytes can be fooled by a decomposed «u + combining diaeresis».
pub(crate) fn nfc(s: &str) -> String {
    s.nfc().collect()
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

/// The marks a selection drops from its own edges.
///
/// Not «every punctuation character»: `+` opens a telephone number, `@` holds
/// an address together, `/` and `#` carry a reference number, and a selection
/// that includes one meant to. These are the marks a sentence puts **around** a
/// word — the ones a person's drag catches by accident at the end of a line or
/// the start of a quote — and each one here was written down on purpose.
const EDGE_MARKS: &[char] = &[
    '.', ',', ';', ':', '!', '?', '…', '"', '\'', '«', '»', '(', ')', '[', ']', '{', '}', '„', '“',
    '”', '‘', '’', '—', '–', '،', '؛', '؟',
];

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

/// Grow a selection out to whole words, and drop the marks at its edges.
///
/// The owner, 6 October, from a live run: protections came out as `J__Z_…`,
/// `S__Z_…` and `Björn __Z_…`, and a token with a stray letter in front of it
/// is a leak of the first letter of a name. The cause is not the person's aim —
/// at the left margin the mouse lands *after* the first character, every time —
/// and the fix is not to ask them to aim better.
///
/// Two rules, in this order:
///
/// 1. **Out, never in.** Each end moves outward while the character beside it
///    belongs to the same word, so a drag that starts one letter late still
///    takes the whole name. A selection that already covers whole words does
///    not move at all.
/// 2. **Then the edges are tidied**, of the marks a sentence puts around a word
///    and never of the ones a value is made of. So «Müller,» becomes «Müller»
///    and «+49 228» stays exactly as it was drawn.
///
/// Returns byte offsets into `s`, and never returns an empty range: a selection
/// of nothing but marks is handed back untouched for the caller to refuse.
pub(crate) fn whole_words(s: &str, start: usize, end: usize) -> (usize, usize) {
    let (mut start, mut end) = (start.min(s.len()), end.min(s.len()));
    if start >= end {
        return (start, end);
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
    let tidy = |c: char| EDGE_MARKS.contains(&c) || c.is_whitespace();
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
            ' ' | '\t' => {}
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
}

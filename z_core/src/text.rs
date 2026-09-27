//! Offsets. The contract counts UTF-16 code units because Dart does; Rust
//! counts bytes. Every crossing goes through here, and a span that would cut a
//! character is refused rather than trimmed.

use crate::api::{ApiError, ApiResult, Span};

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
}

//! Just enough zip to open one entry of a DOCX, in memory.
//!
//! Hand-rolled for two reasons that both matter here: the read loop is ours, so
//! the decompressed-size limit is enforced **where the bytes arrive** rather than
//! after a library has already allocated them; and a document is untrusted input,
//! so the less code between the file and us, the better. The only decompressor is
//! `flate2`.
//!
//! What is not supported is refused by name, never guessed at: zip64, encrypted
//! entries, anything but store and deflate.

use std::io::Read;

use flate2::read::DeflateDecoder;

use crate::api::{ApiResult, Refusal};

use super::{limits, refuse};

const EOCD_SIG: u32 = 0x0605_4b50;
const CENTRAL_SIG: u32 = 0x0201_4b50;
const LOCAL_SIG: u32 = 0x0403_4b50;
const METHOD_STORED: u16 = 0;
const METHOD_DEFLATE: u16 = 8;
/// Bit 0 of the general purpose flags: the entry is encrypted.
const FLAG_ENCRYPTED: u16 = 1;

fn malformed(detail: &str) -> crate::api::ApiError {
    refuse(Refusal::MalformedDocument, detail.to_string())
}

fn u16_at(bytes: &[u8], at: usize) -> ApiResult<u16> {
    let slice = bytes.get(at..at + 2).ok_or_else(|| malformed("the zip ends mid-field"))?;
    Ok(u16::from_le_bytes([
        *slice.first().unwrap_or(&0),
        *slice.get(1).unwrap_or(&0),
    ]))
}

fn u32_at(bytes: &[u8], at: usize) -> ApiResult<u32> {
    let slice = bytes.get(at..at + 4).ok_or_else(|| malformed("the zip ends mid-field"))?;
    Ok(u32::from_le_bytes([
        *slice.first().unwrap_or(&0),
        *slice.get(1).unwrap_or(&0),
        *slice.get(2).unwrap_or(&0),
        *slice.get(3).unwrap_or(&0),
    ]))
}

/// Read one entry by name. `None` when the zip is sound but holds no such entry.
pub(crate) fn read_entry(bytes: &[u8], wanted: &str) -> ApiResult<Option<Vec<u8>>> {
    let eocd = find_eocd(bytes)?;
    let entries = u16_at(bytes, eocd + 10)?;
    let central_offset = u32_at(bytes, eocd + 16)? as usize;

    let mut at = central_offset;
    for _ in 0..entries {
        if u32_at(bytes, at)? != CENTRAL_SIG {
            return Err(malformed("the zip's central directory is not where it says"));
        }
        let flags = u16_at(bytes, at + 8)?;
        let method = u16_at(bytes, at + 10)?;
        let compressed = u32_at(bytes, at + 20)? as usize;
        let uncompressed = u32_at(bytes, at + 24)? as usize;
        let name_len = u16_at(bytes, at + 28)? as usize;
        let extra_len = u16_at(bytes, at + 30)? as usize;
        let comment_len = u16_at(bytes, at + 32)? as usize;
        let local_offset = u32_at(bytes, at + 42)? as usize;
        let name_bytes = bytes
            .get(at + 46..at + 46 + name_len)
            .ok_or_else(|| malformed("an entry name runs past the end of the file"))?;

        if name_bytes == wanted.as_bytes() {
            if flags & FLAG_ENCRYPTED != 0 {
                return Err(refuse(
                    Refusal::EncryptedPdf,
                    format!("«{wanted}» inside this file is password-protected"),
                ));
            }
            if compressed == u32::MAX as usize || uncompressed == u32::MAX as usize {
                return Err(malformed("this is a zip64 file, which this build does not read"));
            }
            if uncompressed > limits::ZIP_ENTRY_BYTES {
                return Err(refuse(
                    Refusal::TextTooLarge,
                    format!(
                        "«{wanted}» would be {} MiB once unpacked, past the {} MiB limit",
                        uncompressed / 1024 / 1024,
                        limits::ZIP_ENTRY_BYTES / 1024 / 1024
                    ),
                ));
            }
            return Ok(Some(read_at_local(bytes, local_offset, method, compressed)?));
        }
        at = at
            .checked_add(46 + name_len + extra_len + comment_len)
            .ok_or_else(|| malformed("the central directory loops back on itself"))?;
    }
    Ok(None)
}

/// The end-of-central-directory record, searched for from the back.
fn find_eocd(bytes: &[u8]) -> ApiResult<usize> {
    if bytes.len() < 22 {
        return Err(malformed("too short to be a zip file"));
    }
    // The record is 22 bytes plus a comment of at most 64 KiB.
    let earliest = bytes.len().saturating_sub(22 + 65_535);
    let mut at = bytes.len() - 22;
    loop {
        if u32_at(bytes, at)? == EOCD_SIG {
            return Ok(at);
        }
        if at == earliest {
            return Err(malformed("this file has no zip directory — it may not be a DOCX"));
        }
        at -= 1;
    }
}

fn read_at_local(bytes: &[u8], offset: usize, method: u16, compressed: usize) -> ApiResult<Vec<u8>> {
    if u32_at(bytes, offset)? != LOCAL_SIG {
        return Err(malformed("an entry is not where the directory says it is"));
    }
    let name_len = u16_at(bytes, offset + 26)? as usize;
    let extra_len = u16_at(bytes, offset + 28)? as usize;
    let start = offset
        .checked_add(30 + name_len + extra_len)
        .ok_or_else(|| malformed("an entry header runs past the end"))?;
    let end = start
        .checked_add(compressed)
        .ok_or_else(|| malformed("an entry is longer than the file"))?;
    let raw = bytes
        .get(start..end)
        .ok_or_else(|| malformed("an entry runs past the end of the file"))?;

    match method {
        METHOD_STORED => Ok(raw.to_vec()),
        METHOD_DEFLATE => inflate_bounded(raw),
        other => Err(malformed(&format!(
            "this file packs its parts with method {other}, which this build does not read"
        ))),
    }
}

/// Inflate, stopping at the limit rather than trusting the header's promise.
fn inflate_bounded(raw: &[u8]) -> ApiResult<Vec<u8>> {
    let mut decoder = DeflateDecoder::new(raw).take(limits::ZIP_ENTRY_BYTES as u64 + 1);
    let mut out = Vec::new();
    decoder
        .read_to_end(&mut out)
        .map_err(|e| malformed(&format!("a part of this file could not be unpacked: {e}")))?;
    if out.len() > limits::ZIP_ENTRY_BYTES {
        return Err(refuse(
            Refusal::TextTooLarge,
            format!(
                "a part of this file unpacks to more than {} MiB",
                limits::ZIP_ENTRY_BYTES / 1024 / 1024
            ),
        ));
    }
    Ok(out)
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use crate::api::ApiError;
    use std::io::Write;

    /// A one-entry zip, written by hand so the reader is tested against bytes
    /// nobody generated for it.
    pub(crate) fn zip_with(name: &str, content: &[u8], deflate: bool) -> Vec<u8> {
        let stored: Vec<u8> = if deflate {
            let mut encoder = flate2::write::DeflateEncoder::new(Vec::new(), flate2::Compression::default());
            encoder.write_all(content).expect("deflate");
            encoder.finish().expect("finish")
        } else {
            content.to_vec()
        };
        let method: u16 = if deflate { METHOD_DEFLATE } else { METHOD_STORED };
        let crc = crc32(content);

        let mut out = Vec::new();
        // local header
        out.extend_from_slice(&LOCAL_SIG.to_le_bytes());
        out.extend_from_slice(&20u16.to_le_bytes()); // version needed
        out.extend_from_slice(&0u16.to_le_bytes()); // flags
        out.extend_from_slice(&method.to_le_bytes());
        out.extend_from_slice(&0u32.to_le_bytes()); // time+date
        out.extend_from_slice(&crc.to_le_bytes());
        out.extend_from_slice(&(stored.len() as u32).to_le_bytes());
        out.extend_from_slice(&(content.len() as u32).to_le_bytes());
        out.extend_from_slice(&(name.len() as u16).to_le_bytes());
        out.extend_from_slice(&0u16.to_le_bytes()); // extra
        out.extend_from_slice(name.as_bytes());
        let data_at = out.len();
        out.extend_from_slice(&stored);

        // central directory
        let central_at = out.len();
        out.extend_from_slice(&CENTRAL_SIG.to_le_bytes());
        out.extend_from_slice(&20u16.to_le_bytes()); // version made by
        out.extend_from_slice(&20u16.to_le_bytes()); // version needed
        out.extend_from_slice(&0u16.to_le_bytes()); // flags
        out.extend_from_slice(&method.to_le_bytes());
        out.extend_from_slice(&0u32.to_le_bytes());
        out.extend_from_slice(&crc.to_le_bytes());
        out.extend_from_slice(&(stored.len() as u32).to_le_bytes());
        out.extend_from_slice(&(content.len() as u32).to_le_bytes());
        out.extend_from_slice(&(name.len() as u16).to_le_bytes());
        out.extend_from_slice(&0u16.to_le_bytes()); // extra
        out.extend_from_slice(&0u16.to_le_bytes()); // comment
        out.extend_from_slice(&0u16.to_le_bytes()); // disk
        out.extend_from_slice(&0u16.to_le_bytes()); // internal attrs
        out.extend_from_slice(&0u32.to_le_bytes()); // external attrs
        out.extend_from_slice(&((data_at - name.len() - 30) as u32).to_le_bytes()); // local offset
        out.extend_from_slice(name.as_bytes());

        // end of central directory
        let central_size = out.len() - central_at;
        out.extend_from_slice(&EOCD_SIG.to_le_bytes());
        out.extend_from_slice(&0u16.to_le_bytes()); // this disk
        out.extend_from_slice(&0u16.to_le_bytes()); // disk with central
        out.extend_from_slice(&1u16.to_le_bytes()); // entries here
        out.extend_from_slice(&1u16.to_le_bytes()); // entries total
        out.extend_from_slice(&(central_size as u32).to_le_bytes());
        out.extend_from_slice(&(central_at as u32).to_le_bytes());
        out.extend_from_slice(&0u16.to_le_bytes()); // comment length
        out
    }

    fn crc32(data: &[u8]) -> u32 {
        let mut crc = 0xFFFF_FFFFu32;
        for byte in data {
            crc ^= u32::from(*byte);
            for _ in 0..8 {
                let mask = if crc & 1 == 1 { 0xEDB8_8320 } else { 0 };
                crc = (crc >> 1) ^ mask;
            }
        }
        !crc
    }

    #[test]
    fn a_stored_entry_reads_back() {
        let zip = zip_with("word/document.xml", b"<w:t>Nordstern</w:t>", false);
        let out = read_entry(&zip, "word/document.xml").expect("read").expect("present");
        assert_eq!(out, b"<w:t>Nordstern</w:t>");
    }

    #[test]
    fn a_deflated_entry_reads_back() {
        let content = "Herr Thomas Müller ".repeat(50);
        let zip = zip_with("word/document.xml", content.as_bytes(), true);
        assert!(zip.len() < content.len(), "the fixture really is compressed");
        let out = read_entry(&zip, "word/document.xml").expect("read").expect("present");
        assert_eq!(out, content.as_bytes());
    }

    #[test]
    fn a_missing_entry_is_not_an_error() {
        let zip = zip_with("word/document.xml", b"x", false);
        assert!(read_entry(&zip, "word/other.xml").expect("read").is_none());
    }

    #[test]
    fn a_file_that_is_not_a_zip_is_refused_by_name() {
        match read_entry(b"this is just text, and rather short", "word/document.xml") {
            Err(ApiError::DocumentRefused { reason, .. }) => {
                assert_eq!(reason, Refusal::MalformedDocument);
            }
            other => panic!("expected a refusal, got {other:?}"),
        }
    }

    #[test]
    fn a_truncated_zip_is_refused_not_half_read() {
        let zip = zip_with("word/document.xml", b"Nordstern Consulting GmbH", false);
        let half = &zip[..zip.len() / 2];
        assert!(matches!(
            read_entry(half, "word/document.xml"),
            Err(ApiError::DocumentRefused { .. })
        ));
    }
}

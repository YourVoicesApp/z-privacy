//! The wire itself. The only file in the program that names an HTTP client.
//!
//! Every rule the owner set for M6 is a line of code here, not an intention:
//!
//! | rule | how |
//! |---|---|
//! | no blind redirects | `max_redirects(0)`, and a 3xx is refused by name |
//! | `https`, or a **literal** loopback address | [`check_url`] before a socket is opened |
//! | timeouts | connect and whole-call, both set |
//! | a bounded answer | the read loop below is ours, and stops at `RESPONSE_BYTES` |
//! | nothing off the wire in an error | no response text is ever put in a detail |
//!
//! The last one is why the mapping below throws the client's own error away and
//! builds a message from names and numbers: a provider's error page can quote the
//! request back at you, and an error message travels further than a body does.

use std::io::Read;
use std::time::Duration;

use ureq::http::Uri;

use crate::api::{ApiResult, NetworkRefusal};

use super::refuse;

/// End to end, including the model thinking about it.
const CALL_MILLIS: u64 = 120_000;
/// Getting as far as the host.
const CONNECT_MILLIS: u64 = 15_000;
/// How much answer we accept. A refusal is better than a full machine.
const RESPONSE_BYTES: u64 = 2 * 1024 * 1024;
/// How much header we accept before the body even starts.
const HEADER_BYTES: usize = 32 * 1024;

/// What came back. Deliberately not a `ureq` type: nothing of the client's
/// vocabulary leaves this file.
pub(crate) struct Answer {
    pub status: u32,
    pub body: String,
}

/// Is this address on this very machine? Plain HTTP is allowed there and nowhere
/// else, because a model running on your own computer is the most private
/// provider there is — and because a loopback socket leaves no network.
///
/// The rule is deliberately dumb, by the owner's amendment of 27 September: the
/// host must be a **literal loopback IP address**. A *name* that claims to be
/// local is not accepted, because accepting one means trusting DNS to decide
/// whether plaintext is safe — and `localhost` can be pointed anywhere in a hosts
/// file. So `127.0.0.1` yes, `127.5.5.5` yes, `::1` yes; `localhost` no.
pub(crate) fn is_loopback_url(url: &str) -> bool {
    match Uri::try_from(url) {
        Ok(uri) => uri.host().is_some_and(is_loopback_host),
        Err(_) => false,
    }
}

/// A literal loopback address, and nothing that merely looks like one.
fn is_loopback_host(host: &str) -> bool {
    // IPv6 arrives in brackets inside a URL authority.
    let bare = host.strip_prefix('[').and_then(|h| h.strip_suffix(']')).unwrap_or(host);
    match bare.parse::<std::net::IpAddr>() {
        Ok(std::net::IpAddr::V4(v4)) => v4.is_loopback(),
        Ok(std::net::IpAddr::V6(v6)) => v6.is_loopback(),
        // Not an IP literal at all — a name. Names are never loopback here.
        Err(_) => false,
    }
}

/// The address is checked before anything is sent, so that a mistyped `http://`
/// is a refusal rather than a payload in the clear.
pub(crate) fn check_url(url: &str) -> ApiResult<()> {
    let uri = Uri::try_from(url).map_err(|_| {
        refuse(
            NetworkRefusal::InsecureUrl,
            "that address cannot be read as a URL".to_string(),
        )
    })?;
    match uri.scheme_str() {
        Some("https") => Ok(()),
        Some("http") if is_loopback_url(url) => Ok(()),
        _ => Err(refuse(
            NetworkRefusal::InsecureUrl,
            "an address must be https — plain http only for a literal loopback address such as http://127.0.0.1:11434".to_string(),
        )),
    }
}

/// POST a JSON body with a bearer credential, and read a bounded answer.
pub(crate) fn post_json(url: &str, credential: &str, body: &str) -> ApiResult<Answer> {
    check_url(url)?;

    let config = ureq::config::Config::builder()
        // A redirect is refused, not followed: the safe payload and the
        // credential were addressed to this host and go to no other.
        .max_redirects(0)
        // We read the status ourselves, so that a 4xx does not arrive as an
        // error carrying the body someone else wrote.
        .http_status_as_error(false)
        .timeout_connect(Some(Duration::from_millis(CONNECT_MILLIS)))
        .timeout_global(Some(Duration::from_millis(CALL_MILLIS)))
        .max_response_header_size(HEADER_BYTES)
        .user_agent("z-privacy")
        .build();

    let mut request = config.new_agent().post(url).header("content-type", "application/json");
    if !credential.is_empty() {
        request = request.header("authorization", format!("Bearer {credential}"));
    }
    let mut response = request.send(body).map_err(sent_badly)?;

    let status = u32::from(response.status().as_u16());
    if (300..400).contains(&status) {
        // Read nothing, keep nothing. The location is not followed and is not
        // repeated back either.
        return Err(refuse(
            NetworkRefusal::Redirected { status },
            format!("the host answered with a redirect ({status}); we do not follow one"),
        ));
    }

    // The limit is ours rather than the client's: one byte past it is read on
    // purpose, so that «exactly at the limit» and «too long» are distinguishable
    // and a refusal is never a truncated answer quietly accepted.
    let mut buffer = Vec::new();
    response
        .body_mut()
        .as_reader()
        .take(RESPONSE_BYTES + 1)
        .read_to_end(&mut buffer)
        .map_err(came_back_badly)?;
    if buffer.len() as u64 > RESPONSE_BYTES {
        return Err(refuse(
            NetworkRefusal::ResponseTooLarge {
                limit_kib: (RESPONSE_BYTES / 1024) as u32,
            },
            format!("the answer was longer than {} KiB", RESPONSE_BYTES / 1024),
        ));
    }
    let text = String::from_utf8(buffer)
        .map_err(|_| refuse(NetworkRefusal::Unreadable, "the answer was not text".to_string()))?;

    Ok(Answer { status, body: text })
}

/// The request did not complete. The client's own error text is dropped here on
/// purpose: it can contain the address, and in some clients the body.
fn sent_badly(e: ureq::Error) -> crate::api::ApiError {
    match e {
        ureq::Error::Timeout(_) => refuse(
            NetworkRefusal::Timeout {
                millis: CALL_MILLIS as u32,
            },
            format!("nothing came back within {} seconds", CALL_MILLIS / 1000),
        ),
        ureq::Error::HostNotFound => refuse(
            NetworkRefusal::Unreachable,
            "that host could not be found".to_string(),
        ),
        ureq::Error::ConnectionFailed | ureq::Error::Io(_) => refuse(
            NetworkRefusal::Unreachable,
            "the connection to that host did not open".to_string(),
        ),
        ureq::Error::Tls(_) | ureq::Error::TlsRequired => refuse(
            NetworkRefusal::InsecureUrl,
            "the encrypted connection could not be established".to_string(),
        ),
        ureq::Error::TooManyRedirects | ureq::Error::RedirectFailed => refuse(
            NetworkRefusal::Redirected { status: 0 },
            "the host tried to send this request somewhere else".to_string(),
        ),
        _ => refuse(
            NetworkRefusal::Unreachable,
            "the request did not reach that host".to_string(),
        ),
    }
}

/// The answer stopped part-way. A timeout is named as one; anything else is an
/// answer we could not read, and the reader's own message is not repeated.
fn came_back_badly(e: std::io::Error) -> crate::api::ApiError {
    if e.kind() == std::io::ErrorKind::TimedOut || e.kind() == std::io::ErrorKind::WouldBlock {
        return refuse(
            NetworkRefusal::Timeout {
                millis: CALL_MILLIS as u32,
            },
            format!("the answer stopped arriving after {} seconds", CALL_MILLIS / 1000),
        );
    }
    refuse(NetworkRefusal::Unreadable, "the answer could not be read".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::ApiError;

    #[test]
    fn plain_http_is_refused_unless_the_host_is_a_literal_loopback_address() {
        assert!(check_url("https://api.openai.com/v1/chat/completions").is_ok());
        assert!(check_url("http://127.0.0.1:11434/v1/chat/completions").is_ok());
        assert!(check_url("http://127.0.0.1/v1").is_ok());
        assert!(check_url("http://127.5.5.5:8080/v1").is_ok(), "the whole 127/8 range is this machine");
        assert!(check_url("http://[::1]:8080/v1").is_ok());
        // https is fine anywhere, including by name on this machine.
        assert!(check_url("https://localhost:8443/v1").is_ok());

        for bad in [
            "http://api.openai.com/v1/chat/completions",
            "http://192.168.1.10/v1/chat/completions",
            "ftp://example.com/",
            "not a url at all",
            // A name is never trusted to mean «this machine», however it reads:
            // a hosts file or a DNS answer would be deciding whether plaintext is
            // safe, and that is not a decision we hand out.
            "http://localhost:8080/v1/chat/completions",
            "http://localhost.localdomain:8080/v1",
            "http://127.0.0.1.evil.example.com/v1",
            "http://localhost.evil.example.com/v1",
            // Not loopback, however close it looks.
            "http://126.0.0.1/v1",
            "http://0.0.0.0/v1",
            "http://[::2]/v1",
        ] {
            match check_url(bad) {
                Err(ApiError::NetworkRefused { reason, .. }) => {
                    assert_eq!(reason, NetworkRefusal::InsecureUrl, "for {bad}")
                }
                other => panic!("{bad} should have been refused, got {other:?}"),
            }
        }
    }

    #[test]
    fn a_refusal_carries_numbers_and_never_a_body() {
        let err = refuse(
            NetworkRefusal::BadStatus { status: 429 },
            "the provider answered 429".to_string(),
        );
        let shown = format!("{err}");
        assert!(shown.contains("429"), "{shown}");
        // The whole point: this text was built here, not read off the wire.
        assert!(!shown.contains("Bearer"), "{shown}");
    }
}

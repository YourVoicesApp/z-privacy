//! The safe payload: the only text that may leave the device, and the only
//! thing the send path will accept.
//!
//! It is built here from the original plus its protections, kept here, and given
//! out as a [`crate::api::PayloadHandle`]. Nothing in the contract can hand a
//! payload back in as text, which is why a bug in the UI cannot send the
//! original — there is no signature for it.

use crate::api::{ApiError, ApiResult, PageEdge, PayloadHandle, PayloadView};
use crate::session::Session;
use std::fmt;

use crate::text::nfc;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum PayloadSendState {
    Ready,
    InFlight,
    Consumed,
}

/// One built request, remembered with the revision it was built on.
#[derive(Clone)]
pub(crate) struct SafePayload {
    pub id: u32,
    pub session: u32,
    pub revision: u32,
    /// What will go over the wire. Crate-private: only the provider module may
    /// read it, and the UI only ever sees it through [`Self::view`].
    text: String,
    pub allowed_token_ids: Vec<String>,
    pub protected: u32,
    pub open_suggestions: u32,
    /// Where the pages begin in `text`, recorded while it was built. Read by
    /// the Safe column so it can draw the same edges the Original draws; never
    /// written into `text`, so the bytes that leave are the bytes that left
    /// before 041-L.
    page_edges: Vec<PageEdge>,
    send_state: PayloadSendState,
}

impl fmt::Debug for SafePayload {
    /// G11: even the safe text is the user's writing. Debug says what it is, not
    /// what it says.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SafePayload")
            .field("id", &self.id)
            .field("session", &self.session)
            .field("revision", &self.revision)
            .field("bytes", &self.text.len())
            .field("allowed_tokens", &self.allowed_token_ids.len())
            .field("protected", &self.protected)
            .field("open_suggestions", &self.open_suggestions)
            .field("pages", &(self.page_edges.len() + 1))
            .field("send_state", &self.send_state)
            .finish()
    }
}

/// Copy a stretch of the document into the payload, counting the pages it
/// crosses and remembering where each one begins **in the payload**.
///
/// Separate from `build` only because it is called from two places in it, and
/// a page edge found by two different pieces of arithmetic would be the kind
/// of disagreement this file exists to prevent.
fn keep(
    slice: &str,
    text: &mut String,
    page: &mut u32,
    written: &mut usize,
    edges: &mut Vec<PageEdge>,
) {
    for ch in slice.chars() {
        if ch == '\u{c}' {
            *page = page.saturating_add(1);
            // The offset of the break itself, before its own length is added —
            // the same character the Original column draws its rule across.
            edges.push(PageEdge {
                at: *written as u32,
                page: *page,
            });
        }
        *written += ch.len_utf16();
    }
    text.push_str(slice);
}

impl SafePayload {
    /// Build the outgoing text: the original with every protected range replaced
    /// by its token.
    ///
    /// Protections are applied in order and are expected not to overlap; an
    /// overlapping one is skipped rather than corrupting the text, because a
    /// wrong replacement could leave half a real name in the payload.
    pub(crate) fn build(session: &Session, id: u32) -> Self {
        let mut ranges: Vec<&crate::session::Protection> = session.protections.iter().collect();
        ranges.sort_by_key(|p| p.start);

        let mut text = String::with_capacity(session.original.len());
        let mut allowed_token_ids = Vec::new();
        let mut cursor = 0usize;
        let mut applied = 0u32;

        // The page count and the payload's own offsets, kept **here** because
        // this loop is the one place that walks the document and the payload
        // together. `page` counts every form feed in the document, whether it
        // survives or not, so a page keeps its number even when a protection
        // swallows the break before it; `written` counts what has gone into
        // the payload, in the UTF-16 units the UI uses.
        let mut page = 1u32;
        let mut written = 0usize;
        let mut page_edges: Vec<PageEdge> = Vec::new();

        for p in ranges {
            if p.start < cursor || p.end > session.original.len() || p.start >= p.end {
                continue;
            }
            match session.original_str().get(cursor..p.start) {
                Some(before) => {
                    keep(before, &mut text, &mut page, &mut written, &mut page_edges);
                }
                None => continue,
            }
            // A protected stretch leaves the payload as one token. Any page
            // break inside it is gone from the text, so the page is counted
            // and no edge is recorded — the next page still knows its number.
            if let Some(swallowed) = session.original_str().get(p.start..p.end) {
                page = page.saturating_add(swallowed.matches('\u{c}').count() as u32);
            }
            text.push_str(&p.token);
            written += crate::text::utf16_len(&p.token);
            if !allowed_token_ids.iter().any(|t| t == &p.token) {
                allowed_token_ids.push(p.token.clone());
            }
            cursor = p.end;
            applied = applied.saturating_add(1);
        }
        if let Some(rest) = session.original_str().get(cursor..) {
            keep(rest, &mut text, &mut page, &mut written, &mut page_edges);
        }

        // **The page's edge is for the person reading, not for the model.**
        //
        // Since 041-J the readers keep a form feed between page and page so the
        // Original column can draw where one ends. A model has no use for a
        // control character, and this text is the one thing that leaves the
        // device, so the edge becomes an ordinary line break here — one
        // character for one character, which leaves every offset where it was.
        // One character for one character, so every offset above — including
        // each `page_edges.at` — still points at what it pointed at.
        let text = text.replace('\u{c}', "\n");

        // **The question joins what leaves** (046/N).
        //
        // The decision, and the invariant it rests on: the promise is that the
        // **left** column is the document byte for byte. The right column
        // means **everything that leaves**. So a question that leaves and is
        // not in that column would make the column a lie — the one shape this
        // round has spent itself removing, a screen claiming less than the
        // engine does.
        //
        // With a separator and a label, because the model is being handed two
        // different things and so is the person reading the column: this is a
        // request about a document, not a line of it. The label is in English
        // because every string that leaves this device is, and because a model
        // reads it.
        //
        // Its tokens are already minted — `set_question` did that, since
        // minting needs the session mutably and a payload may not change the
        // conversation it is a view of — so here they are only **allowed**, by
        // the same list the document's own tokens enter.
        let text = if session.question_safe.trim().is_empty() {
            text
        } else {
            format!("{text}\n\n--- Request ---\n{}\n", session.question_safe)
        };
        for token in &session.question_tokens {
            if !allowed_token_ids.iter().any(|t| t == token) {
                allowed_token_ids.push(token.clone());
            }
        }
        debug_assert!(
            page_edges.iter().all(|e| (e.at as usize) < crate::text::utf16_len(&text)),
            "a page edge landed outside the payload"
        );

        Self {
            id,
            session: session.id,
            revision: session.revision,
            text,
            allowed_token_ids,
            protected: applied,
            // How many suggestions are still unanswered **at the moment this was
            // built**. It was hard-coded to 0 from M2 until task 025, which meant
            // `PayloadView` told the Safe column «this is exactly what the AI will
            // receive» while `send` was refusing the same payload for open
            // suggestions. Two screens, two answers, and the reassuring one wrong.
            open_suggestions: session.open_suggestions(),
            page_edges,
            send_state: PayloadSendState::Ready,
        }
    }

    pub(crate) fn handle(&self) -> PayloadHandle {
        PayloadHandle {
            id: self.id,
            session: self.session,
            revision: self.revision,
        }
    }

    /// What the right-hand column shows. The same string that will be sent.
    pub(crate) fn view(&self) -> PayloadView {
        PayloadView {
            text: self.text.clone(),
            protected_count: self.protected,
            open_suggestions: self.open_suggestions,
            page_edges: self.page_edges.clone(),
        }
    }

    /// Read the outgoing text. Only the network gateway calls this (M6).
    #[allow(dead_code)]
    pub(crate) fn wire_text(&self) -> &str {
        &self.text
    }

    /// The core's own check that this payload leaks nothing, run on every build.
    ///
    /// The rule is an upper bound, and deliberately so: a value may legitimately
    /// stand in the payload when the user protected only one of its places
    /// (`Scope::Once`). What must never happen is that a value appears **more**
    /// times than the places left unprotected — that would mean a replacement
    /// silently failed. An upper bound can miss a nested spelling; it can never
    /// refuse an honest build, which is what makes it safe to run in production.
    pub(crate) fn audit(&self, session: &Session) -> ApiResult<()> {
        let payload_nfc = nfc(&self.text);
        let original_nfc = nfc(session.original_str());
        for spelling in session.tokens.all_secrets() {
            if spelling.is_empty() {
                continue;
            }
            let spelling = nfc(&spelling);
            let in_original = count(&original_nfc, &spelling);
            // Count by INTENT, not by what the range happens to cover: a
            // protection whose token stands for this spelling is meant to hide
            // one of its places. If such a protection exists and the value is
            // still there in full, a replacement went astray.
            let replaced = session
                .protections
                .iter()
                .filter(|p| {
                    session
                        .tokens
                        .get(&p.token)
                        .is_some_and(|e| e.matches(&spelling))
                })
                .count();
            let allowed = in_original.saturating_sub(replaced);
            let actual = count(&payload_nfc, &spelling);
            if actual > allowed {
                return Err(ApiError::PayloadRefused {
                    reason: format!(
                        "a protected value still stands {actual} time(s) where at most {allowed} was expected"
                    ),
                });
            }
        }
        Ok(())
    }

    /// Is this payload still the one the session would build now?
    pub(crate) fn check_fresh(&self, session_revision: u32) -> ApiResult<()> {
        if self.revision == session_revision {
            Ok(())
        } else {
            Err(ApiError::StalePayload {
                expected: session_revision,
                got: self.revision,
            })
        }
    }

    pub(crate) fn reserve_send(&mut self, session_revision: u32, handle_revision: u32) -> ApiResult<()> {
        self.check_fresh(session_revision)?;
        if handle_revision != self.revision {
            return Err(ApiError::StalePayload {
                expected: session_revision,
                got: handle_revision,
            });
        }
        match self.send_state {
            PayloadSendState::Ready => {
                self.send_state = PayloadSendState::InFlight;
                Ok(())
            }
            PayloadSendState::InFlight | PayloadSendState::Consumed => Err(ApiError::PayloadAlreadySent),
        }
    }

    pub(crate) fn finish_send(&mut self, consume: bool) {
        self.send_state = if consume {
            PayloadSendState::Consumed
        } else {
            PayloadSendState::Ready
        };
    }
}

/// Non-overlapping occurrences of `needle` in `haystack`.
fn count(haystack: &str, needle: &str) -> usize {
    if needle.is_empty() {
        return 0;
    }
    let mut n = 0usize;
    let mut from = 0usize;
    while let Some(rest) = haystack.get(from..) {
        match rest.find(needle) {
            Some(at) => {
                n += 1;
                from = from + at + needle.len();
            }
            None => break,
        }
    }
    n
}

#[cfg(test)]
mod tests {
    use crate::api::{Kind, Scope, Span};
    use crate::ops;
    use crate::session::with_session;

    const DOC: &str = "Ansprechpartner: Thomas Müller, Nordstern GmbH.";

    fn span_of(doc: &str, needle: &str) -> Span {
        let byte = doc.find(needle).expect("needle");
        let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
        let len: usize = needle.chars().map(char::len_utf16).sum();
        Span {
            start: start as u32,
            end: (start + len) as u32,
        }
    }

    /// The control string of invariant G3: prove the audit can actually fail.
    ///
    /// A check that never fires is worth nothing, and a green test suite around
    /// a broken check is worse than no check. So here a protection is bent out of
    /// place on purpose — exactly the misalignment bug the audit exists for — and
    /// the build must refuse rather than hand out a payload with the name in it.
    #[test]
    fn no_leak_audit_refuses_a_sabotaged_protection() {
        let s = ops::open_session(None, "de".to_string()).expect("open");
        ops::import_text(s, DOC.to_string()).expect("import");
        ops::protect(s, span_of(DOC, "Thomas Müller"), Scope::Conversation, Kind::Person)
            .expect("protect");

        // An honest build passes.
        ops::build_payload(s).expect("the honest payload must build");

        // Now point that protection at a different word, as a wrong offset would:
        // the token still stands for the name, but the name itself survives whole.
        let elsewhere = DOC.find("Ansprechpartner").expect("word");
        with_session(s.id, |session| {
            if let Some(p) = session.protections.first_mut() {
                p.start = elsewhere;
                p.end = elsewhere + "Ansprechpartner".len();
            }
        })
        .expect("session");

        match ops::build_payload(s) {
            Err(crate::api::ApiError::PayloadRefused { reason }) => {
                assert!(!reason.is_empty(), "the refusal must say what it saw");
            }
            other => panic!("the audit did not fire on a sabotaged protection: {other:?}"),
        }
    }

    #[test]
    fn no_leak_audit_allows_a_value_the_user_left_in_the_clear() {
        // Scope::Once means once. The audit must not second-guess the user, or
        // it would block honest builds — which is why it checks an upper bound.
        let doc = "Thomas Müller und Thomas Müller.";
        let s = ops::open_session(None, "de".to_string()).expect("open");
        ops::import_text(s, doc.to_string()).expect("import");
        ops::protect(s, span_of(doc, "Thomas Müller"), Scope::Once, Kind::Person).expect("protect");

        let handle = ops::build_payload(s).expect("a partly protected build is honest");
        let view = ops::payload_view(handle).expect("view");
        assert_eq!(view.text.matches("Thomas Müller").count(), 1);
    }
}

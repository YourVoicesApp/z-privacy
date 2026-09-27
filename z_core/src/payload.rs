//! The safe payload: the only text that may leave the device, and the only
//! thing the send path will accept.
//!
//! It is built here from the original plus its protections, kept here, and given
//! out as a [`crate::api::PayloadHandle`]. Nothing in the contract can hand a
//! payload back in as text, which is why a bug in the UI cannot send the
//! original — there is no signature for it.

use crate::api::{ApiError, ApiResult, PayloadHandle, PayloadView};
use crate::session::Session;
use std::fmt;

use crate::text::nfc;

/// One built request, remembered with the revision it was built on.
#[derive(Clone)]
pub(crate) struct SafePayload {
    pub id: u32,
    pub session: u32,
    pub revision: u32,
    /// What will go over the wire. Crate-private: only the provider module may
    /// read it, and the UI only ever sees it through [`Self::view`].
    text: String,
    pub protected: u32,
    pub open_suggestions: u32,
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
            .field("protected", &self.protected)
            .field("open_suggestions", &self.open_suggestions)
            .finish()
    }
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
        let mut cursor = 0usize;
        let mut applied = 0u32;

        for p in ranges {
            if p.start < cursor || p.end > session.original.len() || p.start >= p.end {
                continue;
            }
            match session.original_str().get(cursor..p.start) {
                Some(before) => text.push_str(before),
                None => continue,
            }
            text.push_str(&p.token);
            cursor = p.end;
            applied = applied.saturating_add(1);
        }
        if let Some(rest) = session.original_str().get(cursor..) {
            text.push_str(rest);
        }

        Self {
            id,
            session: session.id,
            revision: session.revision,
            text,
            protected: applied,
            // M3 fills this in; until the scanner exists nothing is suggested.
            open_suggestions: 0,
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

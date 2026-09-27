//! The safe payload: the only text that may leave the device, and the only
//! thing the send path will accept.
//!
//! It is built here from the original plus its protections, kept here, and given
//! out as a [`crate::api::PayloadHandle`]. Nothing in the contract can hand a
//! payload back in as text, which is why a bug in the UI cannot send the
//! original — there is no signature for it.

use crate::api::{ApiError, ApiResult, PayloadHandle, PayloadView};
use crate::session::Session;

/// One built request, remembered with the revision it was built on.
#[derive(Debug, Clone)]
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
            match session.original.get(cursor..p.start) {
                Some(before) => text.push_str(before),
                None => continue,
            }
            text.push_str(&p.token);
            cursor = p.end;
            applied = applied.saturating_add(1);
        }
        if let Some(rest) = session.original.get(cursor..) {
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

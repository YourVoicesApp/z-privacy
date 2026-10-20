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

/// **What a payload holds**, which decides two things no caller should have to
/// remember: what the turn an answer writes calls its question, and which saved
/// document that turn is anchored to (rule 69).
///
/// Three kinds and not a flag, because they are three different acts: the first
/// question of a chat goes with its document; a later one goes alone (rule 67);
/// and the chat's own copy goes out holding **nothing new** — every line of it
/// left by another door already.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum WhatThePayloadIs {
    /// The document and the request under it — `--- Request ---` between them.
    ADocumentAndItsRequest,
    /// A question that follows another, travelling by itself (rule 67).
    AQuestionAlone,
    /// **The chat itself**, for the person to take away (rule 65). An answer
    /// brought back against this writes a turn with **no question of its own**:
    /// nothing new was asked, and writing the transcript back into the file
    /// would put the chat inside itself and carry it twice to the next model.
    TheChatItself,
}

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
    /// **Which of the owner's sessions this payload belongs to**, recorded when
    /// it was built — 064d. `None` is a payload built with none open, which is
    /// a real state and the one worth being able to see.
    conversation: Option<crate::api::PayloadSession>,
    /// **How many distinct tokens of each kind stand in `text`** — 068, counted
    /// in the same breath as the text was assembled. See `api::PayloadView`'s
    /// own comment for why the figure may not be worked out anywhere else.
    by_kind: Vec<crate::api::KindTally>,
    /// **The answer page's token, when this bench has printed one** — 079.
    /// Allowed beside the text's own tokens and never part of the text.
    answer_page: Option<String>,
    /// **Which saved document this payload carried** — rule 69's anchor,
    /// stamped when the payload was built and for the same reason the session
    /// is (064d): it is a fact about the snapshot.
    ///
    /// Read when the answer arrives, out of this record rather than off the
    /// bench, because the two differ exactly where it matters: a person who
    /// copies the text out and comes back with an answer from a browser has
    /// had the preview's copy taken out in between (rule 9), so the bench then
    /// holds nothing to name while this still does.
    ///
    /// `None` for a payload that carried no document: the question alone
    /// (rule 67). The chat's own copy **does** carry one — the document its
    /// first turn went out with, which is in the transcript word for word.
    kept: Option<crate::session::KeptHandle>,
    /// Which of the three things this is, so that the door which writes the
    /// turn asks the payload instead of remembering.
    what_it_is: WhatThePayloadIs,
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
    pub(crate) fn build(
        session: &Session,
        id: u32,
        conversation: Option<crate::api::PayloadSession>,
    ) -> Self {
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

        // **The kinds, from the very list that governs what may come back.**
        //
        // `allowed_token_ids` *is* the set of distinct tokens standing in
        // `text`: the loop above pushed one for each protection it applied, and
        // the question's own tokens were added beside them. So the tally needs
        // no search of the text and no second opinion about what is in it —
        // which is the whole point. A kind with no token here does not appear,
        // rather than appearing as zero: the footer lists what is hidden, not
        // what is not.
        let by_kind = tally(session, &allowed_token_ids);

        // **The answer page's token is allowed, and counted nowhere** — 079.
        //
        // After the tally on purpose: `by_kind` states what stands in the text,
        // and this token stands on a page of its own. Allowed, because an
        // answer that carries it back — a returned page, a model that echoes
        // it — must restore it like any other name of this session; and allowed
        // by every payload from the moment it exists, because the one the
        // person's answer is tied to was usually built before the exit minted
        // it (`Session::answer_page_token` says the other half).
        let answer_page = session.answer_page.clone();
        if let Some(token) = &answer_page {
            if !allowed_token_ids.iter().any(|t| t == token) {
                allowed_token_ids.push(token.clone());
            }
        }

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
            conversation,
            by_kind,
            answer_page,
            kept: session.kept,
            what_it_is: WhatThePayloadIs::ADocumentAndItsRequest,
            send_state: PayloadSendState::Ready,
        }
    }

    /// **A payload whose text the core assembled out of text that has already
    /// been protected** — the question alone (rule 67) and the chat as it left
    /// (rule 65's copy).
    ///
    /// [`Self::build`] walks a document and its protections together, so it
    /// knows what it put into the text and needs no search of it. This one is
    /// handed strings that have been through that already, and the honest way
    /// to say which tokens stand in them is to **look**: `allowed` is what may
    /// come back, which is wider than what stands here on purpose — a
    /// follow-up question is three words long and the answer to it names what
    /// the first request showed the model. So `by_kind` and `protected` count
    /// the tokens that are actually in `text`, and the rest are allowed and
    /// counted nowhere, exactly as the answer page's token has been since 079.
    ///
    /// **No page edges.** A page is a fact about a file the reader opened, and
    /// neither of these two texts is one; «page 1» here would be a measurement
    /// nobody took, which is what a saved document's own comment refuses for
    /// the same reason.
    /// **The question alone** (rule 67): what `set_question` protected, with
    /// every token this chat has carried allowed back. It carries no document,
    /// so it anchors none.
    pub(crate) fn of_the_question_alone(
        session: &Session,
        id: u32,
        conversation: Option<crate::api::PayloadSession>,
        text: String,
        allowed: Vec<String>,
    ) -> Self {
        Self::of_assembled_text(
            session,
            id,
            conversation,
            text,
            allowed,
            None,
            WhatThePayloadIs::AQuestionAlone,
        )
    }

    /// **The chat, for the person to take away** (rule 65). `kept` is the
    /// document its first turn went out with: the transcript holds that
    /// document word for word, so an answer brought back against this copy
    /// belongs under the same document in the session's room (rule 69).
    pub(crate) fn of_the_chat(
        session: &Session,
        id: u32,
        conversation: Option<crate::api::PayloadSession>,
        text: String,
        allowed: Vec<String>,
        kept: Option<crate::session::KeptHandle>,
    ) -> Self {
        Self::of_assembled_text(
            session,
            id,
            conversation,
            text,
            allowed,
            kept,
            WhatThePayloadIs::TheChatItself,
        )
    }

    /// Which of the three things this payload is — asked by the door that
    /// writes the turn, so that nothing there has to remember.
    pub(crate) fn what_it_is(&self) -> WhatThePayloadIs {
        self.what_it_is
    }

    fn of_assembled_text(
        session: &Session,
        id: u32,
        conversation: Option<crate::api::PayloadSession>,
        text: String,
        allowed: Vec<String>,
        kept: Option<crate::session::KeptHandle>,
        what_it_is: WhatThePayloadIs,
    ) -> Self {
        let mut allowed_token_ids: Vec<String> = Vec::new();
        for token in allowed {
            if !allowed_token_ids.contains(&token) {
                allowed_token_ids.push(token);
            }
        }
        let standing: Vec<String> = allowed_token_ids
            .iter()
            .filter(|t| text.contains(t.as_str()))
            .cloned()
            .collect();
        let by_kind = tally(session, &standing);
        let answer_page = session.answer_page.clone();
        if let Some(token) = &answer_page {
            if !allowed_token_ids.iter().any(|t| t == token) {
                allowed_token_ids.push(token.clone());
            }
        }
        Self {
            id,
            session: session.id,
            revision: session.revision,
            text,
            allowed_token_ids,
            protected: standing.len().min(u32::MAX as usize) as u32,
            open_suggestions: session.open_suggestions(),
            page_edges: Vec::new(),
            conversation,
            by_kind,
            answer_page,
            kept,
            what_it_is,
            send_state: PayloadSendState::Ready,
        }
    }

    /// Which saved document this payload carried, for the turn the answer
    /// writes — rule 69.
    pub(crate) fn kept(&self) -> Option<crate::session::KeptHandle> {
        self.kept
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
            by_kind: self.by_kind.clone(),
            session: self.conversation.clone(),
            answer_page_token: self.answer_page.clone(),
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
        // **The original is everything that entered** — 096, rule 72-ب, and a
        // seam this round had to close: the payload is built from the document
        // **and** the request, so a bound measured against the document alone
        // counts a word the person typed as a word that was never there.
        //
        // Measured: a hand covers «Rückruf» in the request and takes the cover
        // back. The token stays in the store (089: protection is permanent),
        // the word stands in the request again, and the old bound said «a
        // protected value still stands 1 time where at most 0 was expected» —
        // the exits closed on a word the person had deliberately uncovered.
        // Both sides of the bound are the one entered text now.
        let entered = session.entered_text();
        let original_nfc = nfc(&entered);
        // **Our own tokens are not places a value stands** — the attacker's
        // B1-3 of 17 October, the second half.
        //
        // A token spells its kind in capitals between two underscores
        // (`__Z_9A2A_IBAN_20583538__`), so a plain substring count over the
        // payload finds the value «IBAN» in every account this document
        // protected. He reached it through a question; a person reaches it with
        // their own hand, by protecting the word «IBAN» in their letter: both
        // labels are replaced, nothing of the value stands in the clear, and
        // the audit refused — «a protected value still stands 4 time(s) where
        // at most 0 was expected». Copy, PDF, pull and send are all this
        // function's doors, so the document could never leave again.
        //
        // The spans come from the same `tokens::token_spans` the scanner uses
        // to refuse a finding standing on a token (079 rule 5), and **both
        // sides are measured the same way**: an upper bound that counted the
        // original's places by one definition and the payload's by another
        // would not be comparing one thing, and the error would land on
        // whichever side counted higher. A returning document carries tokens
        // of its own, which is exactly where the two sides differ.
        //
        // **One call over both texts, and that is the point**, not a saving:
        // «where a value stands» is one definition here, and the two sides of a
        // bound measured by two expressions is how they drift apart. It is also
        // what G31 asks of a fourth asker of this law — which act it is.
        let [ours_in_original, ours_in_payload] =
            [&original_nfc, &payload_nfc].map(|text| crate::tokens::token_spans(text));
        for spelling in session.tokens.all_secrets() {
            if spelling.is_empty() {
                continue;
            }
            let spelling = nfc(&spelling);
            let in_original = count(&original_nfc, &spelling, &ours_in_original);
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
            let actual = count(&payload_nfc, &spelling, &ours_in_payload);
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

/// **How many distinct tokens of each kind stand in a text** — 068.
///
/// One function because two builders need it and the figure may not be worked
/// out in two places: the footer lists what is hidden, and two tallies that
/// disagreed would be two answers to «what is in this text». Ordered by the
/// kind's own persistence code, so two builds of one payload list them in one
/// order and a screen never reshuffles.
///
/// A kind with no token here does not appear, rather than appearing as zero.
fn tally(session: &Session, tokens: &[String]) -> Vec<crate::api::KindTally> {
    let mut tallies: std::collections::BTreeMap<u8, (crate::api::Kind, u32)> =
        std::collections::BTreeMap::new();
    for token in tokens {
        if let Some(entry) = session.tokens.get(token) {
            let slot = tallies
                .entry(crate::vault::format::kind_code(entry.kind))
                .or_insert((entry.kind, 0));
            slot.1 = slot.1.saturating_add(1);
        }
    }
    tallies
        .into_values()
        .map(|(kind, count)| crate::api::KindTally { kind, count })
        .collect()
}

/// Non-overlapping occurrences of `needle` in `haystack`, **outside the
/// stretches this program minted**.
///
/// `ours` is `tokens::token_spans` over this same string. A place that lies
/// inside one of our tokens is not a place the value stands: the token spells
/// its kind in capital letters, and nothing between those underscores is the
/// person's text. Passed in rather than computed here because the caller asks
/// this question once per protected value and the spans are a property of the
/// string.
fn count(haystack: &str, needle: &str, ours: &[(usize, usize)]) -> usize {
    if needle.is_empty() {
        return 0;
    }
    let mut n = 0usize;
    let mut from = 0usize;
    while let Some(rest) = haystack.get(from..) {
        match rest.find(needle) {
            Some(at) => {
                let start = from + at;
                let end = start + needle.len();
                if !ours.iter().any(|(s, e)| start < *e && *s < end) {
                    n += 1;
                }
                from = end;
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

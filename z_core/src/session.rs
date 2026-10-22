//! Sessions, and the one piece of state the whole core hangs off.
//!
//! The important thing in this file is [`Session::bump`]. Every change that
//! could alter the safe text raises the revision, and a payload built on an
//! older revision is refused by [`crate::api::send`]. That is invariant G6, and
//! it is the reason a stale Send cannot happen: not a rule the programmer has to
//! remember, but a number that stops matching.

use std::collections::BTreeMap;
use std::sync::{Mutex, OnceLock};

use crate::api::{DocumentKind, Kind, MarkState, Place, Scope, Source};
use crate::documents::PlaceSpan;
use crate::secret::Secret;
use crate::payload::SafePayload;
use crate::tokens::{TokenMint, TokenStore};

/// One protected stretch of the original, and the token standing in for it.
#[derive(Debug, Clone)]
pub(crate) struct Protection {
    /// Byte range in the original text.
    pub start: usize,
    pub end: usize,
    pub token: String,
    /// Which act of protection put it here. "Protect all matches" is one act,
    /// so one Undo takes all of its places back together.
    pub act: u32,
    pub kind: Kind,
    #[allow(dead_code)] // read by the tokens panel in 005
    pub scope: Scope,
    /// Which layer **found** it — the "why" the UI shows beside the mark.
    pub source: Source,
    pub source_detail: String,
    /// True when a person decided this, rather than a layer.
    ///
    /// Kept apart from `source` because the two are different questions: the
    /// pack may have *found* a name while *you* decided to protect it, and a
    /// review list that said «you found this» would be wrong. It exists because
    /// a rescan used to drop everything whose source was not `Hand` — so
    /// pressing Rescan took back every answer given in the review, which is the
    /// board's «a token once given is never silently taken back», broken.
    /// (Task 033.)
    pub decided: bool,
    /// The layer that found this no longer claims it — the pack changed, the
    /// profile changed, or the value was forgotten from the vault — **and it is
    /// kept protected anyway**.
    ///
    /// Because taking it back would expose, in the Safe column, a value that
    /// was hidden a moment ago. «Forget» erases knowledge; only «Remove
    /// protection» changes what is protected here, and one is not a gentle name
    /// for the other. (Task 037, the ninth.)
    pub orphaned: bool,
}

/// One thing the scanner found, and why. Carried whole so the UI can always say
/// *why* an item is hidden — or why it is being asked about.
#[derive(Debug, Clone)]
#[allow(dead_code)] // every field is read by the scanner and the review, in M3
pub(crate) struct FindingRecord {
    pub id: u32,
    pub start: usize,
    pub end: usize,
    pub kind: Kind,
    /// Who found it.
    pub source: Source,
    pub source_detail: String,
    pub reason: String,
    pub state: MarkState,
    /// Whether a person decided it. A decided finding survives a rescan with
    /// its id, its reason and its place — the review row does not move under
    /// the user's hand, and the decision is not asked again.
    pub decided: bool,
    /// The vault identities that claim it; more than one is a conflict.
    pub entities: Vec<String>,
    /// Other layers that saw the same thing and called it the same kind.
    pub also: Vec<String>,
}

/// A value the user said is not sensitive, in this conversation.
///
/// Kept because a rescan would otherwise ask again as if nothing had been said
/// — the owner's rule of 27 September: a `NotSensitive` answer must not come
/// back in the same scope. The scope of this one is the conversation, which is
/// where the answer was given.
#[derive(Debug)]
pub(crate) struct Dismissed {
    pub value: crate::secret::Secret,
}

/// **The saved document a bench is holding** — 089 rule 9.
///
/// The number *and* whether it is a chat, because a `docN` and a `chatN` may
/// share a number: two sequences, as the owner wrote them.
///
/// **And which session's list it is in** — rule 55, 16 October. A number is a
/// number *in* a session, so a handle without one names a row in a file nobody
/// said which: a document moved to another session was written into the new
/// list and left standing in the old one, measured as «1 holds doc1, 2 holds
/// doc1, 3 holds doc1» for one document in one preview. With the session in
/// the handle the wrong state cannot be written down.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct KeptHandle {
    pub session: u32,
    pub number: u32,
    pub chat: bool,
}

/// One answer, tied to the exact payload that produced it.
#[derive(Clone)]
pub(crate) struct AnswerRecord {
    pub id: u32,
    pub session: u32,
    pub payload: u32,
    pub raw: String,
    /// **Which of the owner's sessions this answer was taken in** — 064: the
    /// number, and the handle as it read at that moment.
    ///
    /// The handle is copied rather than looked up, because the look-up is
    /// exactly what fails: once the session is deleted there is nothing left to
    /// ask for its name, and «session 3 is gone» is not what a person called it.
    /// The number alone could not carry the refusal the owner asked for.
    ///
    /// `None` is an answer taken with no session open — reachable only when
    /// something left without the UI asking first, which is the named limit of
    /// birth-at-the-exit.
    pub conversation: Option<(u32, String)>,
}

impl std::fmt::Debug for AnswerRecord {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("AnswerRecord")
            .field("id", &self.id)
            .field("session", &self.session)
            .field("payload", &self.payload)
            .field("conversation", &self.conversation.as_ref().map(|(n, _)| *n))
            .field("bytes", &self.raw.len())
            .finish()
    }
}

/// One conversation.
#[derive(Debug)]
pub(crate) struct Session {
    pub id: u32,
    pub revision: u32,
    #[allow(dead_code)] // read by the vault layer in M4
    pub profile_id: Option<String>,
    #[allow(dead_code)] // read by the scanner in M3
    pub pack_id: String,
    /// The user's own text. It never leaves this crate except as a view, and it
    /// never prints itself (G11).
    pub original: Secret,
    /// What the user called the document, and what it was.
    pub doc_name: String,
    /// The size of the file as it arrived, in bytes, and the lowest readable
    /// share of any of its pages. Kept for one reason: the report a person can
    /// copy is written by the core, and these are two of its numbers.
    pub doc_bytes: u32,
    pub readable: u32,
    pub doc_kind: DocumentKind,
    pub pages: u32,
    /// Where every run of the text came from: page and paragraph.
    pub places: Vec<PlaceSpan>,
    pub protections: Vec<Protection>,
    /// What the scanner found: protected ones and open suggestions alike, so the
    /// review list can show all three states with their reasons.
    pub findings: Vec<FindingRecord>,
    /// Values the user called not sensitive here. Survives a rescan.
    pub dismissed: Vec<Dismissed>,
    /// **Which saved document this bench is holding** — 089 rule 9.
    ///
    /// `Some(n)` is the `docN`/`chatN` of the copy in the conversation's own
    /// file, which this bench must delete when its text leaves by a door.
    /// `None` is a bench with nothing saved behind it: no conversation was
    /// open when the document arrived, or it has already left.
    ///
    /// It is the **number** and not a copy of anything: the copy lives in the
    /// file, and two copies of a document is the shape that lets them differ.
    pub kept: Option<KeptHandle>,
    /// Ordinary words left over at the last scan. Counted, never hard-coded.
    pub normal_words: u32,
    /// The id of the next finding.
    next_finding: u32,
    /// What every token in this conversation stands for.
    pub tokens: TokenStore,
    /// This session's own token namespace and randomness.
    pub mint: TokenMint,
    pub payloads: BTreeMap<u32, SafePayload>,
    /// Answers as they arrived, by id, tied to the payload that produced them.
    /// Kept raw so «AI View» can show exactly what came back, and restore can be
    /// redone at any time.
    pub answers: BTreeMap<u32, AnswerRecord>,
    next_payload: u32,
    next_act: u32,
    next_answer: u32,
    /// How this document last came to be scanned. The workspace band reads it.
    pub scan_origin: crate::api::ScanOrigin,
    /// Which tokens are shown locally right now, and until when. The value is
    /// not here: it is in `tokens`, and it was handed over once when asked for.
    pub revealed: BTreeMap<String, ShownToken>,
    /// **What the person is asking the model to do with this document**
    /// (046/N).
    ///
    /// The owner, 7 October: «ليس لدينا شات — شات مع نموذج… لا يوجد خيار مثلاً
    /// مباشرة إلى الشات.» Before this the document reached the model bare, with
    /// `Context { workspace, history }` both empty, so whatever came back was
    /// the model's own guess at what was wanted.
    ///
    /// Three fields and not one, because the three say different things:
    ///
    ///   * `question` is what he typed. It is his own writing, so it is a
    ///     `Secret` and it never prints itself, exactly as `original` does not.
    ///   * `question_safe` is what leaves. It is built once, when the question
    ///     is set, because protecting it mints tokens and that may not happen
    ///     on every keystroke or inside the payload builder, which holds the
    ///     session immutably.
    ///   * `question_tokens` is what the payload must allow, or an answer that
    ///     echoes one of them would come back as the token instead of the name.
    pub question: Secret,
    pub question_safe: String,
    pub question_tokens: Vec<String>,
    /// **What is protected inside the request, as records** — 096, rule 72-ب.
    ///
    /// `question_safe` used to be the only trace of the request's protections:
    /// a string with the tokens already substituted, built once. A hand cannot
    /// undo a substitution, so the request's covers are kept the way the
    /// document's are — as records, with byte offsets into `question` — and
    /// **`question_safe` is derived from them** (`the_request_as_it_leaves`).
    /// One fact, one source: the records are the fact and the safe text is a
    /// view of it, so a hand protecting or undoing in the request rebuilds the
    /// one string rather than patching it.
    ///
    /// They go when the request goes: a new question is new text, and a record
    /// over text nobody wrote any more would move a token onto a word the
    /// person never covered.
    pub question_protections: Vec<Protection>,
    /// **The token the answer page of a z-pdf prints** — 079. `None` until an
    /// exit mints it; see [`Session::answer_page_token`].
    pub answer_page: Option<String>,
}

impl Session {
    fn new(id: u32, profile_id: Option<String>, pack_id: String) -> Self {
        Self {
            id,
            // Revisions start at 1 so that 0 can never be mistaken for a valid
            // one in a handle that was never filled in.
            revision: 1,
            profile_id,
            pack_id,
            original: Secret::default(),
            doc_name: String::new(),
            doc_bytes: 0,
            readable: 100,
            doc_kind: DocumentKind::Txt,
            pages: 1,
            places: Vec::new(),
            protections: Vec::new(),
            findings: Vec::new(),
            dismissed: Vec::new(),
            kept: None,
            normal_words: 0,
            next_finding: 1,
            tokens: TokenStore::default(),
            mint: TokenMint::new(),
            payloads: BTreeMap::new(),
            answers: BTreeMap::new(),
            next_payload: 1,
            next_act: 1,
            next_answer: 1,
            scan_origin: crate::api::ScanOrigin::NotScanned,
            revealed: BTreeMap::new(),
            // Empty is a real answer: a document may be sent with no request,
            // and the sheet says so rather than inventing one (046/N).
            question: Secret::new(String::new()),
            question_safe: String::new(),
            question_tokens: Vec::new(),
            question_protections: Vec::new(),
            answer_page: None,
        }
    }

    /// **Put a saved document back on this bench, as it was left** — 089 rule 9.
    ///
    /// The text, the marks, and the «Leave it»s. Three things are rebuilt here
    /// rather than stored twice:
    ///
    ///   * **the values** — each one is the text under its own mark, so the
    ///     file keeps one copy of every value and a mark cannot come to
    ///     disagree with the word it points at;
    ///   * **the token store** — built from those pairs, so the Safe column and
    ///     every reveal answer as they did before the app closed;
    ///   * **the act ids** — one act for the whole restoration, because a step
    ///     back from here is not an undo of something the person just did.
    ///
    /// **Nothing is scanned and no finding is made.** The review list is built
    /// by a scan, and a scan would ask again about the words this document
    /// already answered for. What a person sees is what they left: the marks,
    /// and the Rescan button if they want more.
    pub(crate) fn put_back_the_preview(&mut self, kept: &crate::conversation::Kept) {
        self.original = Secret::new(kept.text.clone());
        // **No places**, and the reason is written where they are not kept: a
        // place is a fact about the file the reader opened, and a restored
        // document that claimed page numbers it had not measured would be
        // inventing them. The marks carry their own offsets into the text.
        self.places = Vec::new();
        self.doc_name = kept.name.clone();
        self.doc_kind = kept.kind;
        self.pages = kept.pages;
        self.doc_bytes = kept.bytes;
        self.readable = kept.readable;
        self.protections.clear();
        self.findings.clear();
        self.tokens = TokenStore::default();
        self.dismissed = kept
            .dismissed
            .iter()
            .map(|value| Dismissed { value: Secret::new(value.clone()) })
            .collect();
        let act = self.take_act_id();
        for mark in &kept.marks {
            let (start, end) = (mark.start as usize, mark.end as usize);
            let Some(value) = kept.text.get(start..end) else { continue };
            if self.tokens.get(&mark.token).is_none() {
                self.tokens.insert(
                    mark.token.clone(),
                    crate::tokens::TokenEntry {
                        value: Secret::new(value.to_string()),
                        aliases: Vec::new(),
                        kind: mark.kind,
                        scope: mark.scope,
                        source: mark.source,
                        decided: mark.decided,
                        source_detail: mark.detail.clone(),
                    },
                );
            }
            self.protections.push(Protection {
                start,
                end,
                token: mark.token.clone(),
                act,
                kind: mark.kind,
                scope: mark.scope,
                source: mark.source,
                source_detail: mark.detail.clone(),
                decided: mark.decided,
                orphaned: mark.orphaned,
            });
        }
        self.protections.sort_by_key(|p| p.start);
        // **And the request comes back as a request** — rule 55-ز, format 7.
        //
        // The copy carries what was typed under the document and the covers on
        // it, in the request's own offsets, so this restores them where they
        // belong: in the box the person wrote them in, and not as a second
        // document. A typed-only session is the case this was written for —
        // `kept.text` is empty there and the whole of the work is here.
        //
        // The token store is filled from these marks as it is from the
        // document's, because the value of a cover is the text under it (there
        // is one copy of every value and no second place for them to disagree)
        // — and a word covered in both halves takes one entry, which is the
        // same «one value, one token» the live bench keeps.
        self.question = Secret::new(kept.request.clone());
        self.question_protections.clear();
        self.question_tokens.clear();
        for mark in &kept.request_marks {
            let (start, end) = (mark.start as usize, mark.end as usize);
            let Some(value) = kept.request.get(start..end) else { continue };
            if self.tokens.get(&mark.token).is_none() {
                self.tokens.insert(
                    mark.token.clone(),
                    crate::tokens::TokenEntry {
                        value: Secret::new(value.to_string()),
                        aliases: Vec::new(),
                        kind: mark.kind,
                        scope: mark.scope,
                        source: mark.source,
                        decided: mark.decided,
                        source_detail: mark.detail.clone(),
                    },
                );
            }
            self.question_protections.push(Protection {
                start,
                end,
                token: mark.token.clone(),
                act,
                kind: mark.kind,
                scope: mark.scope,
                source: mark.source,
                source_detail: mark.detail.clone(),
                decided: mark.decided,
                orphaned: mark.orphaned,
            });
            if !self.question_tokens.contains(&mark.token) {
                self.question_tokens.push(mark.token.clone());
            }
        }
        self.question_protections.sort_by_key(|p| p.start);
        // Derived from the records, never remembered: the one function that
        // builds what leaves builds it here too.
        self.question_safe = self.the_request_as_it_leaves();
        // **Scanned, and the band must say so**: the marks on this document
        // were made by the scan that came with it and by hand, before it was
        // put away, so «not scanned yet» over a document full of marks would be
        // the band contradicting the column beside it. `OnImport` is the truth
        // about where they came from — the scan this document arrived with.
        self.scan_origin = crate::api::ScanOrigin::OnImport;
        self.payloads.clear();
        self.bump();
    }

    /// **Name every token again, from the session's key** — 064's re-derivation
    /// at the moment the owner's session is born.
    ///
    /// Five places hold a token as a string and all five move together: the
    /// store's keys, each `Protection`, the `revealed` map, `question_tokens`,
    /// and the safe question's own text. Payloads built before this instant are
    /// dropped rather than rewritten — a payload is a snapshot of what would
    /// leave, and a snapshot of names that no longer exist is worse than none.
    ///
    /// **An answer taken before the session was born keeps the names it was
    /// taken with**, so its tokens will no longer resolve and 046/U item 1 will
    /// *report* them instead of passing them through as prose. That is visible,
    /// not silent, and it is reachable only when something left the machine
    /// without the UI asking for a session first — the named limit of
    /// birth-at-the-exit. Nothing here can repair an answer already in
    /// somebody's hand, and pretending otherwise is what item 1 exists to stop.
    pub(crate) fn names_again_from(&mut self, naming: crate::tokens::Naming) -> usize {
        let pairs = self.mint.rename_all(naming, &mut self.tokens);
        if pairs.is_empty() {
            return 0;
        }
        let moved: std::collections::BTreeMap<&str, &str> =
            pairs.iter().map(|(old, new)| (old.as_str(), new.as_str())).collect();

        for protection in &mut self.protections {
            if let Some(new) = moved.get(protection.token.as_str()) {
                protection.token = (*new).to_string();
            }
        }

        let shown = std::mem::take(&mut self.revealed);
        self.revealed = shown
            .into_iter()
            .map(|(token, what)| match moved.get(token.as_str()) {
                Some(new) => ((*new).to_string(), what),
                None => (token, what),
            })
            .collect();

        for token in &mut self.question_tokens {
            if let Some(new) = moved.get(token.as_str()) {
                *token = (*new).to_string();
            }
        }
        // **The fourth list, and the one that was left behind** — paper 102 §5.
        //
        // The request's own records carry a token each, exactly as the
        // document's do above, and they were the one list this rename never
        // touched. What a session born at its first exit then did to a word
        // protected by hand in the request afterwards: `question_safe` is
        // derived from these records on every later act in the request
        // (`the_request_as_it_leaves`), so the **pre-birth** name came back
        // into what leaves — a token in the payload that this session's key
        // cannot resolve and the door back cannot open.
        //
        // The same family as the traps in this house's own notes: a rule
        // applied to a list of records and its sister left, measured four
        // times before this one.
        for protection in &mut self.question_protections {
            if let Some(new) = moved.get(protection.token.as_str()) {
                protection.token = (*new).to_string();
            }
        }
        for (old, new) in &pairs {
            self.question_safe = self.question_safe.replace(old, new);
        }
        // The answer page's token is a sixth place, and it moves with the rest:
        // a page minted before the birth would otherwise print a name the
        // session's key never made.
        //
        // **It moves and it is not counted.** The number returned is the one
        // the exit says aloud — «N names became this session's» — and the page's
        // token is no name the person chose to protect. Counted, it put one name
        // too many in that sentence the first time an exit minted it before the
        // birth, which is the order every exit follows (`the_name_at_the_exit`).
        let page_moved = match self.answer_page.as_deref().and_then(|t| moved.get(t)) {
            Some(new) => {
                self.answer_page = Some((*new).to_string());
                1
            }
            None => 0,
        };

        self.payloads.clear();
        self.bump();
        pairs.len().saturating_sub(page_moved)
    }

    /// **The token the answer page of a z-pdf prints, minted once** — 079.
    ///
    /// The owner, 13 Oct: «Zprivacy-svara» is protected **like any other
    /// word**, with the same session key as the document. So it is minted by
    /// this bench's own mint, into this bench's own store, and nothing about it
    /// is special after that: with a session open its name is derived from the
    /// session's key — `__Z_<ns>_CUSTOM_<tail>__`, where neither the namespace
    /// nor the tail has the document in its input (`Naming::of_session`) — and
    /// a birth renames it with every other token.
    ///
    /// **A kind of its own, `Custom`, and never a token borrowed from the
    /// document.** A document that happened to protect the same spelling as a
    /// person would otherwise lend the page *its* token, and the page would
    /// stop being the same in every export of the session.
    ///
    /// Every payload already built is taught it here, and every payload built
    /// after allows it by itself (`SafePayload::build`). The first half is not
    /// tidiness: the payload a pasted answer is tied to is the bench's last
    /// snapshot, built before the exit was pressed — without this, the token
    /// the page printed would come back unknown in the session that printed it.
    ///
    /// The revision does not move. What would leave as the document's text is
    /// unchanged, so no handle goes stale and no send is refused for it.
    pub(crate) fn answer_page_token(&mut self) -> String {
        let word = crate::tokens::ANSWER_PAGE_WORD;
        let kept = self
            .answer_page
            .clone()
            .filter(|t| self.tokens.get(t).is_some_and(|e| e.kind == Kind::Custom && e.matches(word)));
        let token = match kept {
            Some(token) => token,
            None => {
                let token = self.mint.mint(Kind::Custom, word, &self.tokens);
                self.tokens.insert(
                    token.clone(),
                    crate::tokens::TokenEntry {
                        value: Secret::new(word.to_string()),
                        aliases: Vec::new(),
                        kind: Kind::Custom,
                        scope: Scope::Conversation,
                        source: Source::GeneralRule,
                        decided: false,
                        source_detail: "the answer page of a z-pdf".to_string(),
                    },
                );
                self.answer_page = Some(token.clone());
                token
            }
        };
        for payload in self.payloads.values_mut() {
            if !payload.allowed_token_ids.iter().any(|t| t == &token) {
                payload.allowed_token_ids.push(token.clone());
            }
        }
        token
    }

    /// Something changed that affects the safe text: every handle built before
    /// this moment is now stale.
    pub(crate) fn bump(&mut self) {
        self.revision = self.revision.saturating_add(1);
    }

    /// The id of the next protection act.
    /// The original text. Reading it is a deliberate act, by name.
    pub(crate) fn original_str(&self) -> &str {
        self.original.expose()
    }

    /// **The one line between what entered and what was asked about it** —
    /// spelled once, read by the payload that sends it and by the entered text
    /// the person's hand addresses.
    pub(crate) const THE_REQUEST_LINE: &'static str = "\n\n--- Request ---\n";

    /// **The one text the person entered** — 096, rule 72-ب: what is written
    /// in the box is a thing that enters, like the document.
    ///
    /// The document, the line, then the request — and the request alone when
    /// there is no document (rule 72's surface). Every hand door addresses
    /// **this** text, which is why the document comes first: its offsets are
    /// unchanged, so no protection, finding or page edge moves, and where a
    /// span lands is arithmetic rather than a claim a caller could get wrong.
    pub(crate) fn entered_text(&self) -> String {
        let document = self.original_str();
        let request = self.question.expose();
        if document.is_empty() {
            return request.to_string();
        }
        if request.trim().is_empty() {
            return document.to_string();
        }
        format!("{document}{}{request}", Self::THE_REQUEST_LINE)
    }

    /// Where the request begins in the entered text, in **bytes**. `None` when
    /// there is no request in it at all.
    pub(crate) fn request_begins_at(&self) -> Option<usize> {
        if self.question.expose().trim().is_empty() {
            return None;
        }
        let document = self.original_str();
        if document.is_empty() {
            return Some(0);
        }
        Some(document.len() + Self::THE_REQUEST_LINE.len())
    }

    /// **The request as it leaves** — the raw request with every record's own
    /// stretch replaced by its token, which is what `question_safe` holds.
    ///
    /// Walked from the start, records sorted, so a token never lands inside the
    /// text another record covers.
    pub(crate) fn the_request_as_it_leaves(&self) -> String {
        let raw = self.question.expose();
        let mut records: Vec<&Protection> = self.question_protections.iter().collect();
        records.sort_by_key(|p| p.start);
        let mut out = String::with_capacity(raw.len());
        let mut cursor = 0usize;
        for record in records {
            if record.start < cursor || record.end > raw.len() || record.start >= record.end {
                continue;
            }
            if let Some(before) = raw.get(cursor..record.start) {
                out.push_str(before);
            }
            out.push_str(&record.token);
            cursor = record.end;
        }
        if let Some(rest) = raw.get(cursor..) {
            out.push_str(rest);
        }
        out
    }

    /// Where a byte offset in the text sits in the document it came from.
    ///
    /// This is what lets a finding still say «page 17» after the text around it
    /// has been replaced by tokens: the map is kept against the **original**, and
    /// the original does not move.
    pub(crate) fn place_of(&self, start: usize) -> Option<Place> {
        self.places
            .iter()
            .find(|p| p.start <= start && start < p.end)
            .map(|p| Place {
                page: p.page,
                paragraph: p.paragraph,
            })
    }

    /// How many suggestions are still unanswered. Invariant G12: a payload from a
    /// session with any of these cannot be sent, however it was built.
    /// Did the user call this stretch's text not sensitive?
    ///
    /// Compared by **value**, not by place: saying «Anna Weber is not
    /// sensitive» and then being asked about the second Anna Weber two lines
    /// down would be the same answer demanded twice.
    pub(crate) fn is_dismissed(&self, start: usize, end: usize) -> bool {
        let Some(text) = self.original_str().get(start..end) else {
            return false;
        };
        let wanted = crate::text::nfc(text);
        self.dismissed
            .iter()
            .any(|d| crate::text::nfc(d.value.expose()) == wanted)
    }

    pub(crate) fn open_suggestions(&self) -> u32 {
        self.findings
            .iter()
            .filter(|f| f.state == MarkState::Suggested)
            .count() as u32
    }

    pub(crate) fn take_finding_id(&mut self) -> u32 {
        let id = self.next_finding;
        self.next_finding = self.next_finding.saturating_add(1);
        id
    }

    pub(crate) fn take_act_id(&mut self) -> u32 {
        let id = self.next_act;
        self.next_act = self.next_act.saturating_add(1);
        id
    }

    /// The tokens standing in the document right now, newest act first.
    pub(crate) fn tokens_in_use(&self) -> Vec<String> {
        let mut seen: Vec<String> = Vec::new();
        for p in &self.protections {
            if !seen.iter().any(|t| t == &p.token) {
                seen.push(p.token.clone());
            }
        }
        seen
    }

    pub(crate) fn take_answer_id(&mut self) -> u32 {
        let id = self.next_answer;
        self.next_answer = self.next_answer.saturating_add(1);
        id
    }

    pub(crate) fn take_payload_id(&mut self) -> u32 {
        let id = self.next_payload;
        self.next_payload = self.next_payload.saturating_add(1);
        id
    }

    /// Old payloads are kept on purpose: a handle that is no longer fresh must
    /// come back as [`crate::api::ApiError::StalePayload`], which needs the old
    /// revision, not as "no such payload". Only the oldest are dropped.
    pub(crate) fn trim_payloads(&mut self) {
        const KEEP: usize = 16;
        while self.payloads.len() > KEEP {
            let used_by_answer = |id: u32| self.answers.values().any(|a| a.payload == id);
            let oldest = match self.payloads.keys().next().copied() {
                Some(k) => k,
                None => break,
            };
            if used_by_answer(oldest) {
                let Some(drop) = self.payloads.keys().copied().find(|id| !used_by_answer(*id)) else {
                    break;
                };
                self.payloads.remove(&drop);
                continue;
            }
            self.payloads.remove(&oldest);
        }
    }
}

/// Milliseconds left until `until`, and 0 the moment it is past.
///
/// One function for both kinds of reveal, so there is one clock and not two.
pub(crate) fn ms_left(until: std::time::Instant) -> u32 {
    let now = std::time::Instant::now();
    if now >= until {
        return 0;
    }
    until.saturating_duration_since(now).as_millis().min(u128::from(u32::MAX)) as u32
}

/// One token shown in the safe column, and what ends it.
///
/// It lives in the session because the value it stands for does: `tokens` is
/// the session's, and closing the session ends both. Before this, the core
/// handed over a `ttl_ms` and forgot — and «the showing lives in the UI» was
/// written in `ops::hide` as if it were a design and not a gap.
#[derive(Debug, Clone, Copy)]
pub(crate) struct ShownToken {
    pub until: std::time::Instant,
    /// The vault's lock count when this was revealed. A lock — by hand or by
    /// the clock — moves the count on, and this record is then stale. The rule
    /// is about the **moment** of a lock, not the state of being locked: a
    /// token can still be revealed while the vault is shut.
    pub locks_at: u64,
}

/// One reveal, and the moment it runs out.
///
/// It is held by the vault it came from — [`crate::vault::OpenVault`] — and not
/// here, so that locking the vault ends it with nothing to remember.
#[derive(Debug, Clone, Copy)]
pub(crate) struct Revealed {
    pub entity: u32,
    pub value_id: u32,
    pub until: std::time::Instant,
}

impl Revealed {
    /// Milliseconds left, and 0 the instant it is over. Read from the clock
    /// every time rather than counted down, so a process that was suspended
    /// wakes up with the reveal already finished.
    pub(crate) fn remaining_ms(&self) -> u32 {
        let now = std::time::Instant::now();
        if now >= self.until {
            return 0;
        }
        self.until.saturating_duration_since(now).as_millis().min(u128::from(u32::MAX)) as u32
    }
}

/// Everything the core holds, for the life of the process.
#[derive(Debug)]
pub(crate) struct Core {
    sessions: BTreeMap<u32, Session>,
    next_session: u32,
    /// One vault per device, shared by every session.
    pub vault: crate::vault::VaultStore,
    /// The non-secret settings file — the only thing this program writes that
    /// is not encrypted, and it holds four scalars from a closed list.
    pub config: crate::config::ConfigStore,
    /// Provider logins that exist only for this run, because there was no open
    /// vault to seal them into. Memory only: there is deliberately no path from
    /// here to a file. The owner's rule — no fallback to a text file; say the
    /// credential is session-only instead — is this field and nothing else.
    pub session_logins: std::collections::BTreeMap<String, crate::vault::model::ProviderLogin>,
    /// Settings for this run, used when no vault is open to keep them in. Same
    /// two homes as a credential, for the same reason: G15 lets the core write
    /// one file, and it is the sealed vault.
    pub session_settings: crate::vault::model::StoredSettings,
    /// Bumped when a displayed fact changes. A check, not a source of drawing.
    pub state_revision: u32,
    /// **Which of the owner's sessions is open** — 064, by its number.
    ///
    /// `None` is «no session», which is the state a person is in until the
    /// first exit: tokens then carry the random names they always have, exactly
    /// as they do while the vault is shut. It is not a session's *bench*: the
    /// benches are in `sessions` above and one owner-session may hold several,
    /// which is the whole of the owner's «same name, two documents, one token».
    ///
    /// Forgotten on lock, like the master key, and restored by entering a
    /// session again — 062 §D: the sealed file survives the lock, only the key
    /// is forgotten, so an auto-lock must not become the power cut again.
    pub open_conversation: Option<u32>,
    /// **The sessions whose chat this run has already opened** — rule 68, «the
    /// chat ends when the application closes».
    ///
    /// Memory only, and that is the whole of how the rule is kept: a chat
    /// cannot be found open by a run that did not open it, because this list
    /// is empty when the process starts. The first time a session is opened
    /// here its chat number is spent and a new one begins; entering it again —
    /// after a look at another session, after an auto-lock — finds its number
    /// in this list and continues the chat the person is in the middle of.
    ///
    /// A list and not a flag per session: the number of sessions a run touches
    /// is the number of rows a person clicks, and a `Vec` of `u32` at that size
    /// is cheaper to read than a map is to keep.
    pub chats_opened: Vec<u32>,
    /// **The session a lock took away, kept so the unlock can give it back** —
    /// 18 October 2026, the owner, whose second question after an Unlock was
    /// answered into a session born on the spot while the chat he was looking
    /// at stayed in the one before it.
    ///
    /// A number, not a key: this is the one fact about an open session that the
    /// master key has nothing to do with. `vault_lock` clears
    /// `open_conversation` because the *way into* the file goes with the key
    /// (064), and the number went with it as a side effect of that line rather
    /// than as a law of its own. Kept here, the unlock can enter the session
    /// again by the same door a person would — so «unlock plus an enter»
    /// becomes «unlock», and no screen has to carry a number across a lock it
    /// did not cause.
    ///
    /// It is taken, not read: an unlock spends it, so a second unlock with
    /// nothing locked in between enters nothing. And it is cleared with the
    /// data directory, for `chats_opened`'s own reason — session 1 here is not
    /// session 1 in another folder.
    pub conversation_before_the_lock: Option<u32>,
    /// **What each session's file held when this run last read it** — paper
    /// 102 §3, 22 October 2026, and the session file's own
    /// `ensure_disk_unchanged`.
    ///
    /// The vault has had that guard since 050/A; `conversation::write`
    /// replaced whatever was on the disk, and the two-window round measured
    /// what that costs — a session file that held a document and eleven
    /// decisions came back holding nothing at all. A write is now allowed only
    /// when the bytes it is replacing are the bytes its body was read from, or
    /// when there is nothing there to lose.
    ///
    /// `None` **as a value** means «there was no file when this was read»,
    /// which is a different fact from a number that is absent from the map:
    /// absent means this run has not read that session's file at all, and a
    /// write with nothing read behind it may only create.
    pub session_as_read: BTreeMap<u32, Option<Vec<u8>>>,
    /// **What the disk said about the last act that tried to write** — paper
    /// 102 §2.
    ///
    /// A state and not an event, because the fault it was written for is a
    /// state: a copy whose vault fell behind refuses **every** write until it
    /// is healed, and an answer that was only returned once would be gone by
    /// the time the person pressed again. `None` is «everything landed», which
    /// is also what a successful write puts back — the heal is measured, not
    /// assumed.
    ///
    /// It holds the refusal itself rather than a flag, so the sentence the
    /// glass shows is the one that names *this* cause: a vault another copy
    /// changed, a session file this window does not own, a shut vault and a
    /// folder that refused are four different next moves for a person.
    pub the_disk_refused: Option<crate::api::ApiError>,
}

impl Core {
    fn new() -> Self {
        Self {
            sessions: BTreeMap::new(),
            next_session: 1,
            vault: crate::vault::VaultStore::default(),
            config: crate::config::ConfigStore::default(),
            session_logins: std::collections::BTreeMap::new(),
            session_settings: crate::vault::model::StoredSettings::default(),
            state_revision: 1,
            open_conversation: None,
            chats_opened: Vec::new(),
            conversation_before_the_lock: None,
            session_as_read: BTreeMap::new(),
            the_disk_refused: None,
        }
    }

    /// Re-hide every token shown in every session. One loop, so the caller
    /// does not have to know how many conversations are open.
    pub(crate) fn hide_every_token(&mut self) {
        for session in self.sessions.values_mut() {
            session.revealed.clear();
        }
    }

    pub(crate) fn bump_truth(&mut self) {
        self.state_revision = self.state_revision.saturating_add(1);
    }

    /// **What the disk said, remembered or forgotten** — paper 102 §2.
    ///
    /// Called by `ops::the_decisions_are_written` and by nobody else, which is
    /// the same discipline the blocks and the preview's copy are written
    /// under: one place where a verdict is recorded cannot disagree with
    /// itself. A landed write clears it, so the state is the disk's and not a
    /// memory of the worst thing that ever happened.
    pub(crate) fn the_disk_said(&mut self, refusal: Option<crate::api::ApiError>) {
        if self.the_disk_refused != refusal {
            self.bump_truth();
        }
        self.the_disk_refused = refusal;
    }

    pub(crate) fn open(&mut self, profile_id: Option<String>, pack_id: String) -> u32 {
        let id = self.next_session;
        self.next_session = self.next_session.saturating_add(1);
        self.sessions.insert(id, Session::new(id, profile_id, pack_id));
        id
    }

    pub(crate) fn close(&mut self, id: u32) -> bool {
        self.sessions.remove(&id).is_some()
    }

    /// **A bench with a document on it, if there is one** — 064f.
    ///
    /// Asked before a session is born: a birth has to re-derive the names
    /// already on an open document, and a call that did not say which document
    /// cannot. The core refuses rather than letting the screen paper over it,
    /// so the answer to «is a document open» has to come from here, where the
    /// benches actually are.
    pub(crate) fn a_live_bench(&self) -> Option<u32> {
        self.sessions
            .values()
            .find(|s| !s.original.is_empty())
            .map(|s| s.id)
    }

    /// One bench, read only. `get` below hands out a mutable one, which a
    /// caller that is also holding the vault cannot have.
    pub(crate) fn sessions_get(&self, id: u32) -> Option<&Session> {
        self.sessions.get(&id)
    }

    pub(crate) fn get(&mut self, id: u32) -> Option<&mut Session> {
        self.sessions.get_mut(&id)
    }

    /// **Every bench, read only** — 079, the import side.
    ///
    /// A document that comes back carries the tokens of the conversation it
    /// left, and a bench of that conversation still in memory is the one place
    /// a token nobody taught the vault resolves. Which bench that is cannot be
    /// asked by id: the door is handed a text and not a session, and one
    /// conversation may hold several benches. It is asked by namespace, which
    /// is derived from the conversation's key and sits inside every token.
    pub(crate) fn benches(&self) -> impl Iterator<Item = &Session> {
        self.sessions.values()
    }

    /// Borrow one session and the vault together: the scan needs both, and they
    /// live behind the same lock.
    pub(crate) fn session_and_vault(
        &mut self,
        id: u32,
    ) -> Option<(&mut Session, &mut crate::vault::VaultStore)> {
        let session = self.sessions.get_mut(&id)?;
        Some((session, &mut self.vault))
    }
}

static CORE: OnceLock<Mutex<Core>> = OnceLock::new();

/// Borrow the core for one operation.
///
/// A poisoned lock is stepped over rather than unwrapped: a panic in one call
/// must not turn every later call into a panic. Nothing here can panic, so
/// nothing here can bring down the isolate.
pub(crate) fn with_core<R>(f: impl FnOnce(&mut Core) -> R) -> R {
    let cell = CORE.get_or_init(|| Mutex::new(Core::new()));
    let mut guard = match cell.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    };
    // **And one copy of this program writes at a time** — the independent
    // attacker's م5 and خ9, 17 October 2026.
    //
    // The mutex above makes this process one writer; this makes the **machine**
    // one writer. Two copies lost a write between them in three of his forty
    // trials, and the session file could lose one every time: in both cases the
    // loss was not in a write but in a *read and a write with a gap between
    // them* — `ensure_disk_unchanged` … `rename`, and `body()` … `write_body()`.
    //
    // So it is taken here, at the one boundary every such pair is already
    // inside, rather than at each write. Nothing nests: the mutex above is not
    // re-entrant and this crate's own rule says so, so there is never a second
    // acquisition to deadlock against. It is dropped when the call returns —
    // and by the operating system if this copy dies holding it, which is the
    // property no lock *file* can promise.
    //
    // With no data directory there is nothing on disk to lose and nothing to
    // lock; `one_writer_at_a_time` answers `None` and the call runs as before.
    let _one_writer = crate::secure_file::one_writer_at_a_time(guard.vault.dir());
    f(&mut guard)
}

/// Borrow one session, or say it does not exist.
pub(crate) fn with_session<R>(id: u32, f: impl FnOnce(&mut Session) -> R) -> Option<R> {
    with_core(|core| core.get(id).map(f))
}

/// A displayed fact changed. Call from outside `with_core` — the lock is not re-entrant.
pub(crate) fn bump_truth() {
    with_core(|core| core.bump_truth());
}

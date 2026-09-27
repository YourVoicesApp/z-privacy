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
    /// Ordinary words left over at the last scan. Counted, never hard-coded.
    pub normal_words: u32,
    /// The id of the next finding.
    next_finding: u32,
    /// What every token in this conversation stands for.
    pub tokens: TokenStore,
    /// This session's own token namespace and randomness.
    pub mint: TokenMint,
    pub payloads: BTreeMap<u32, SafePayload>,
    /// Answers as they arrived, by id. Kept raw so «AI View» can show exactly
    /// what came back, and restore can be redone at any time.
    pub answers: BTreeMap<u32, String>,
    next_payload: u32,
    next_act: u32,
    next_answer: u32,
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
            doc_kind: DocumentKind::Txt,
            pages: 1,
            places: Vec::new(),
            protections: Vec::new(),
            findings: Vec::new(),
            dismissed: Vec::new(),
            normal_words: 0,
            next_finding: 1,
            tokens: TokenStore::default(),
            mint: TokenMint::new(),
            payloads: BTreeMap::new(),
            answers: BTreeMap::new(),
            next_payload: 1,
            next_act: 1,
            next_answer: 1,
        }
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
            let oldest = match self.payloads.keys().next().copied() {
                Some(k) => k,
                None => break,
            };
            self.payloads.remove(&oldest);
        }
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
        }
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

    pub(crate) fn get(&mut self, id: u32) -> Option<&mut Session> {
        self.sessions.get_mut(&id)
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
    f(&mut guard)
}

/// Borrow one session, or say it does not exist.
pub(crate) fn with_session<R>(id: u32, f: impl FnOnce(&mut Session) -> R) -> Option<R> {
    with_core(|core| core.get(id).map(f))
}

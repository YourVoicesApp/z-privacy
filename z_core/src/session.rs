//! Sessions, and the one piece of state the whole core hangs off.
//!
//! The important thing in this file is [`Session::bump`]. Every change that
//! could alter the safe text raises the revision, and a payload built on an
//! older revision is refused by [`crate::api::send`]. That is invariant G6, and
//! it is the reason a stale Send cannot happen: not a rule the programmer has to
//! remember, but a number that stops matching.

use std::collections::BTreeMap;
use std::sync::{Mutex, OnceLock};

use crate::api::{Kind, Scope, Source};
use crate::payload::SafePayload;

/// One protected stretch of the original, and the token standing in for it.
#[derive(Debug, Clone)]
pub(crate) struct Protection {
    /// Byte range in the original text.
    pub start: usize,
    pub end: usize,
    pub token: String,
    pub kind: Kind,
    #[allow(dead_code)] // read by the tokens panel in 005
    pub scope: Scope,
    /// Which layer decided — the "why" the UI shows beside the mark.
    pub source: Source,
    pub source_detail: String,
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
    /// The user's own text. It never leaves this crate except as a view.
    pub original: String,
    pub protections: Vec<Protection>,
    pub payloads: BTreeMap<u32, SafePayload>,
    next_payload: u32,
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
            original: String::new(),
            protections: Vec::new(),
            payloads: BTreeMap::new(),
            next_payload: 1,
        }
    }

    /// Something changed that affects the safe text: every handle built before
    /// this moment is now stale.
    pub(crate) fn bump(&mut self) {
        self.revision = self.revision.saturating_add(1);
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
}

impl Core {
    fn new() -> Self {
        Self {
            sessions: BTreeMap::new(),
            next_session: 1,
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

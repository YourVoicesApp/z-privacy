//! **The trial's sessions, held in memory** — paper 123 §2.1, the lead's cut.
//!
//! Compiled for the `web` build only (gate G1i reads the compiler's own list of
//! files and refuses this one in the native build). The app keeps a session in
//! the vault — a record with its own key — and its turns in a sealed file
//! beside it. The trial has no vault and no files (rule 85 (ب)), and without
//! them a chat could not exist at all: no turn was written, so a second
//! question carried nothing and an answer pasted against it restored nothing.
//!
//! So the web keeps the same two things here, in this page's memory and
//! nowhere else:
//!
//! * [`MemorySessions`] — the vault's list of sessions (number, name, when,
//!   language, **and its key**), held by `VaultStore` in place of the sealed
//!   records. The key is 32 random bytes, as the app's, and lives in this
//!   page's memory only: it seals nothing — there is nothing to seal — and it
//!   names the session's tokens as the app's key does (046/U), so one value is
//!   one token for the whole session, protected again or not;
//! * [`MemoryBodies`] — each session's `Body` (turns, the open chat, the
//!   preview's copy), held by `Core` in place of `sessions/N.zs`.
//!
//! * **the blocks** (089) — every word a person protected, with its tokens, in
//!   an unsealed `Vault` model that holds nothing else. The app's blocks are
//!   what make protection permanent: a rescan protects a protected value at
//!   every whole-word place it stands, with its token, and a token in an
//!   answer is read back by them. Without them the trial sent a value in the
//!   clear beside its own token (paper 123, measured on the es letter). They
//!   are asked through the vault's own methods (`hints_for`, `remember_block`,
//!   `exempt_block`, `block_value_for`), so they behave as the app's do, and
//!   they leave memory with the session (`forget`).
//!
//! Everything above the storage — `record_in`, `the_chat_so_far`, `turns`,
//! `end_the_chat`, the turn `ingest_answer` writes, G9's allowed lists — is the
//! app's own code, unchanged. A reload or «Start over» (`web::close`) and it is
//! gone.

use std::collections::BTreeMap;

use crate::api::{ApiError, ApiResult};
use crate::conversation::Body;

/// One session of the trial: what the vault's record holds, less the key.
#[derive(Debug, Clone)]
struct Row {
    number: u32,
    key: crate::vault::crypto::SecretKey,
    name: String,
    began_at: u64,
    pack_id: Option<String>,
}

/// The sessions this page has begun, in the order they began.
#[derive(Debug)]
pub(crate) struct MemorySessions {
    rows: Vec<Row>,
    /// The blocks, in the vault's own model and nothing else of it.
    pub(crate) blocks: crate::vault::model::Vault,
    /// Spent for ever, as the vault's counter is: a number is never given twice
    /// in one page, so an old reference cannot land on a new session.
    next: u32,
}

impl Default for MemorySessions {
    fn default() -> Self {
        Self { rows: Vec::new(), next: 1, blocks: crate::vault::model::Vault::default() }
    }
}

fn no_such(number: u32) -> ApiError {
    ApiError::PayloadRefused { reason: format!("there is no session {number}") }
}

impl MemorySessions {
    pub(crate) fn begin(&mut self, name: &str, pack_id: Option<&str>) -> ApiResult<u32> {
        let key = crate::vault::crypto::random_key()?;
        let number = self.next;
        self.next = self.next.saturating_add(1);
        self.rows.push(Row {
            number,
            key,
            name: name.to_string(),
            began_at: crate::vault::model::now_seconds(),
            pack_id: pack_id.map(str::to_string),
        });
        Ok(number)
    }

    /// The session's key, for naming its tokens. Never sealed with, never
    /// written: it dies with the page or with «Start over».
    pub(crate) fn key_of(&self, number: u32) -> Option<crate::vault::crypto::SecretKey> {
        self.rows.iter().find(|r| r.number == number).map(|r| r.key.clone())
    }

    pub(crate) fn holds(&self, number: u32) -> bool {
        self.rows.iter().any(|r| r.number == number)
    }

    pub(crate) fn rows(&self) -> Vec<(u32, String, u64)> {
        self.rows.iter().map(|r| (r.number, r.name.clone(), r.began_at)).collect()
    }

    pub(crate) fn rename(&mut self, number: u32, name: &str) -> ApiResult<()> {
        let row = self.rows.iter_mut().find(|r| r.number == number).ok_or_else(|| no_such(number))?;
        row.name = name.to_string();
        Ok(())
    }

    pub(crate) fn pack_of(&self, number: u32) -> Option<String> {
        self.rows.iter().find(|r| r.number == number).and_then(|r| r.pack_id.clone())
    }

    pub(crate) fn set_pack(&mut self, number: u32, pack_id: &str) -> ApiResult<()> {
        let row = self.rows.iter_mut().find(|r| r.number == number).ok_or_else(|| no_such(number))?;
        row.pack_id = Some(pack_id.to_string());
        Ok(())
    }

    /// The session goes, and **the blocks go with it**: the trial holds one
    /// session at a time, and «Start over» promises that nothing of the old
    /// text reaches the new one — no value of it is protected in, and no
    /// token of it is read back from, the next session's text.
    pub(crate) fn forget(&mut self, number: u32) -> ApiResult<String> {
        let at = self.rows.iter().position(|r| r.number == number).ok_or_else(|| no_such(number))?;
        self.blocks.blocks.clear();
        Ok(self.rows.remove(at).name)
    }
}

/// Each session's file, as the body it would hold — in memory, unsealed.
#[derive(Debug, Default)]
pub(crate) struct MemoryBodies {
    bodies: BTreeMap<u32, Body>,
}

impl MemoryBodies {
    pub(crate) fn get(&self, number: u32) -> Option<Body> {
        self.bodies.get(&number).cloned()
    }

    pub(crate) fn put(&mut self, number: u32, body: &Body) {
        self.bodies.insert(number, body.clone());
    }

    pub(crate) fn remove(&mut self, number: u32) {
        self.bodies.remove(&number);
    }
}

//! The vault: identities, the values inside them, and the envelope that seals
//! them on this device.
//!
//! The rule that shapes every function here is the owner's first one for M4:
//! **while the vault is locked, the vault layer does not exist.** The general
//! rules and the language pack still run — an IBAN is still an IBAN — but the app
//! cannot recognise *your* people, and it says so rather than quietly finding
//! less.

pub(crate) mod crypto;
pub(crate) mod format;
pub(crate) mod model;

use std::path::PathBuf;
use std::time::{Duration, Instant};

use crate::api::{ApiError, ApiResult, VaultState};
use crate::vault::crypto::{SealedVault, SecretKey};
use crate::vault::model::{UserException, Vault, VaultHint};

const FILE_NAME: &str = "vault.zv";

/// Where the vault is, whether it is open, and what it holds when it is.
#[derive(Debug, Default)]
pub(crate) struct VaultStore {
    dir: Option<PathBuf>,
    /// The file as it sits on disk, whether or not it is open.
    sealed: Option<SealedVault>,
    /// The exact bytes `sealed` came from on disk, if it came from disk.
    ///
    /// Two desktop instances have two `VaultStore`s. Atomic replace protects the
    /// file from being torn in half, but not from "last writer wins"; this keeps
    /// an unlocked copy from overwriting a vault another copy has changed since.
    disk_bytes: Option<Vec<u8>>,
    /// A file was present, but could not be parsed. Kept so `state()` can stay
    /// infallible and `unlock()` can still name the refusal.
    sealed_error: Option<ApiError>,
    /// Present only while unlocked. Wiped on lock.
    master: Option<SecretKey>,
    /// The decrypted model and the one value revealed from it. Present only
    /// while unlocked — see [`OpenVault`].
    open: Option<OpenVault>,
    /// When the vault was last used, and how long it may sit unused.
    ///
    /// Auto-lock is enforced **here** rather than by a timer in the UI (task
    /// 030). A screen that forgot to count would leave the vault open and
    /// nobody would know; this way every way in checks the clock first.
    touched: Option<Instant>,
    idle_limit: Option<Duration>,
    /// How many times this vault has been closed in this run.
    ///
    /// It is how «a reveal does not live past a lock» holds for a token in the
    /// safe column, whose value is the session's and not the vault's. Each
    /// reveal remembers the count it was born under and the read door drops
    /// anything older — so the vault never reaches into a session to clear
    /// anything, and the auto-lock is covered because that door judges the
    /// clock before it answers.
    locks: u64,
}

/// The open vault, and the one value revealed from it.
///
/// The reveal lives **inside** the open state rather than beside it, and that
/// is the whole fix of this file: it used to sit in `Core`, so `lock()` closed
/// the vault and left the reveal standing. The lock a person presses was only
/// half of it — the auto-lock fires inside [`VaultStore::judge_idle`] and never
/// passes through `vault_lock()` at all, so a second place would have had to
/// remember too. Here there is no way to write down a revealed value without an
/// open vault, and `lock()` drops both in one move.
///
/// The core owns it because the core must: Flutter used to keep the plaintext
/// in a map and let a `Timer` decide when the reveal was over. A screen cannot
/// be the authority on how long a secret stays on screen — a paused isolate, a
/// dropped timer or a rebuilt widget would each quietly extend it.
///
/// And it is not part of [`Vault`]: that is the decrypted content, and
/// `with_open_mut` seals it and writes the file. A reveal belongs to this run
/// and must never reach the disk.
#[derive(Debug)]
pub(crate) struct OpenVault {
    vault: Vault,
    /// `None` means nothing is revealed. One at a time, on purpose.
    revealed: Option<crate::session::Revealed>,
}

impl VaultStore {
    pub(crate) fn set_dir(&mut self, dir: PathBuf) -> ApiResult<()> {
        crate::secure_file::secure_dir(&dir, "vault.zv")?;
        self.dir = Some(dir);
        // Forget anything that was open for the old folder.
        self.lock();
        self.sealed = None;
        self.sealed_error = None;
        self.load_sealed();
        Ok(())
    }

    fn path(&self) -> Option<PathBuf> {
        self.dir.as_ref().map(|d| d.join(FILE_NAME))
    }

    /// Read the file if it is there. A broken file is left for `unlock` to
    /// complain about, so that `state()` never fails.
    fn load_sealed(&mut self) {
        if self.sealed.is_some() {
            return;
        }
        let Some(path) = self.path() else { return };
        match crate::secure_file::read_no_follow(&path, "vault.zv") {
            Ok(Some(bytes)) => match SealedVault::from_bytes(&bytes) {
                Ok(sealed) => {
                    self.sealed = Some(sealed);
                    self.disk_bytes = Some(bytes);
                    self.sealed_error = None;
                }
                Err(err) => {
                    self.sealed = None;
                    self.disk_bytes = Some(bytes);
                    self.sealed_error = Some(err);
                }
            },
            Ok(None) => {
                self.disk_bytes = None;
            }
            Err(err) => {
                self.sealed = None;
                self.disk_bytes = None;
                self.sealed_error = Some(err);
            }
        }
    }

    /// How long the vault may sit unused, in minutes. 0 means never.
    pub(crate) fn set_idle_limit(&mut self, minutes: u32) {
        self.idle_limit = (minutes > 0).then(|| Duration::from_secs(u64::from(minutes) * 60));
        self.touched = Some(Instant::now());
    }

    /// Tests only: make the vault look as though it had been sitting unused for
    /// `seconds` longer than it has.
    ///
    /// One direction, on purpose: this brings the auto-lock **closer** and has
    /// no way to push it away. And when the clock cannot go back that far,
    /// «older than the clock itself» is older than any limit, so the honest
    /// answer is to judge it unused now rather than to leave it as it was.
    #[cfg(feature = "test_clock")]
    pub(crate) fn age_unused(&mut self, seconds: u32) {
        let by = Duration::from_secs(u64::from(seconds));
        match self.touched.and_then(|t| t.checked_sub(by)) {
            Some(older) => self.touched = Some(older),
            None => {
                if self.idle_limit.is_some() {
                    self.lock();
                }
            }
        }
    }

    /// Lock it if it has been sitting too long — and nothing else.
    ///
    /// **Judging is not using.** `touched` is never renewed here, which is what
    /// lets a screen ask about a reveal four times a second without holding the
    /// vault open for as long as the value is on it.
    fn judge_idle(&mut self) {
        if self.open.is_none() {
            return;
        }
        if let (Some(limit), Some(touched)) = (self.idle_limit, self.touched) {
            if touched.elapsed() > limit {
                self.lock();
            }
        }
    }

    /// Every way *into* the open vault: judge the clock first, then note that
    /// it is being used.
    ///
    /// Called by every such way, so «auto-lock» is a property of the vault and
    /// not of whoever remembered to set a timer.
    fn tick(&mut self) {
        self.judge_idle();
        if self.open.is_some() {
            self.touched = Some(Instant::now());
        }
    }

    pub(crate) fn state(&mut self) -> VaultState {
        self.tick();
        self.load_sealed();
        if self.open.is_some() {
            VaultState::Unlocked
        } else if self.sealed.is_some() || self.sealed_error.is_some() {
            VaultState::Locked
        } else {
            VaultState::Absent
        }
    }

    /// Make a vault here. Refuses to write over one that already exists.
    pub(crate) fn create(&mut self, passphrase: &str) -> ApiResult<(u32, u32)> {
        self.load_sealed();
        if self.sealed.is_some() {
            return Err(ApiError::VaultAlreadyExists);
        }
        let model = Vault::new();
        // The master key has to exist before the body can be encoded, because the
        // body now holds things sealed with keys derived from it (task 021). So the
        // envelope is made first and the body written into it immediately after.
        let (mut sealed, master) = SealedVault::create(passphrase, &[])?;
        let body = format::encode(&model, &master)?;
        sealed.reseal_body(&master, &body)?;
        crypto::wipe(body);
        let minutes = model.settings.auto_lock_minutes;
        // **The file before the memory** (050/C). These four fields used to be
        // set first, so a `create` that failed for any reason afterwards left
        // this copy holding an open vault that is **not on disk**, under a
        // passphrase the file does not know. A read-only folder shows it with
        // no race involved, which is the point: the defect was never timing.
        //
        // And a file that appeared since `load_sealed` above is a vault that
        // already exists. That is the true cause and the name the person
        // needs — not «this place cannot be used», which is what the generic
        // look would have said about a folder that is perfectly fine.
        let mut on_disk = None;
        if let Some(path) = self.path() {
            if crate::secure_file::read_no_follow(&path, "vault.zv")?.is_some() {
                return Err(ApiError::VaultAlreadyExists);
            }
            let bytes = sealed.to_bytes();
            crate::secure_file::replace_atomically(&path, "zv.new", &bytes, "vault.zv")?;
            on_disk = Some(bytes);
        }
        self.sealed = Some(sealed);
        self.master = Some(master);
        self.open = Some(OpenVault { vault: model, revealed: None });
        self.disk_bytes = on_disk;
        self.set_idle_limit(minutes);
        Ok((0, 0))
    }

    /// Open it: derive, unwrap the master key, decrypt the contents.
    pub(crate) fn unlock(&mut self, passphrase: &str) -> ApiResult<(u32, u32)> {
        self.sealed = None;
        self.sealed_error = None;
        self.load_sealed();
        if let Some(err) = self.sealed_error.clone() {
            return Err(err);
        }
        let sealed = self.sealed.as_ref().ok_or(ApiError::VaultAbsent)?;
        let master = sealed.unwrap_master(passphrase)?;
        let body = sealed.open_body(&master)?;
        let model = format::decode(&body, &master, sealed.credentials_are_sealed())?;
        let counts = (
            model.entities.len() as u32,
            model.entities.iter().map(|e| e.values.len() as u32).sum(),
        );
        let minutes = model.settings.auto_lock_minutes;
        self.master = Some(master);
        self.open = Some(OpenVault { vault: model, revealed: None });
        self.set_idle_limit(minutes);
        Ok(counts)
    }

    /// Close it. The master key is dropped — and `SecretKey` wipes itself — and
    /// the decrypted contents go with it, and so does whatever was revealed:
    /// that lives inside [`OpenVault`], so there is nothing here to remember.
    /// The count of locks so far — after judging the clock, so an auto-lock
    /// that was due is counted before the answer and not after it.
    ///
    /// Asking is not using: this never renews `touched`.
    pub(crate) fn locks_so_far(&mut self) -> u64 {
        self.judge_idle();
        self.locks
    }

    pub(crate) fn lock(&mut self) {
        self.sealed = None;
        self.sealed_error = None;
        // Counted only when there was something to close. A press on «Lock»
        // with nothing open is not a lock, and must not take down a reveal
        // that no key was turned on.
        if self.open.is_some() {
            self.locks = self.locks.saturating_add(1);
        }
        self.master = None;
        self.open = None;
        self.touched = None;
    }

    pub(crate) fn change_passphrase(&mut self, old: &str, replacement: &str) -> ApiResult<()> {
        self.load_sealed();
        if let Some(err) = self.sealed_error.clone() {
            return Err(err);
        }
        self.ensure_disk_unchanged()?;
        let sealed = self.sealed.as_mut().ok_or(ApiError::VaultAbsent)?;
        sealed.change_passphrase(old, replacement)?;
        self.write_to_disk()
    }

    /// Read the open vault, or say it is locked.
    pub(crate) fn with_open<R>(&mut self, f: impl FnOnce(&Vault) -> R) -> ApiResult<R> {
        self.tick();
        match self.open.as_ref() {
            Some(open) => Ok(f(&open.vault)),
            None => Err(ApiError::VaultLocked),
        }
    }

    /// Read the open vault with a closure that can fail on its own.
    pub(crate) fn read<R>(&mut self, f: impl FnOnce(&Vault) -> ApiResult<R>) -> ApiResult<R> {
        self.tick();
        match self.open.as_ref() {
            Some(open) => f(&open.vault),
            None => Err(ApiError::VaultLocked),
        }
    }

    /// Change the open vault and seal it again. Nothing here can leave the device.
    pub(crate) fn with_open_mut<R>(&mut self, f: impl FnOnce(&mut Vault) -> ApiResult<R>) -> ApiResult<R> {
        self.tick();
        // **This copy's own state first, and the disk after it** (050/A). The
        // other order told a copy whose vault was *locked* that the file had
        // changed and it should lock — advice to lock, given to someone already
        // locked, about a copy that is not open. A call that cannot happen at
        // all has nothing to say about another window.
        if self.open.is_none() || self.master.is_none() {
            return Err(ApiError::VaultLocked);
        }
        self.ensure_disk_unchanged()?;
        let (Some(open), Some(master)) = (self.open.as_mut(), self.master.as_ref()) else {
            return Err(ApiError::VaultLocked);
        };
        let vault = &mut open.vault;
        let out = f(vault)?;
        let body = format::encode(vault, master)?;
        let sealed = self.sealed.as_mut().ok_or(ApiError::VaultLocked)?;
        sealed.reseal_body(master, &body)?;
        crypto::wipe(body);
        self.write_to_disk()?;
        Ok(out)
    }

    /// What is revealed right now, if anything.
    ///
    /// The clock is judged on the way in — a vault that should have locked
    /// locks here — but asking is **not** using, so nothing is postponed. An
    /// expired reveal is dropped on the way out, so the core does not hold a
    /// finished one until someone asks again.
    pub(crate) fn revealed_now(&mut self) -> Option<crate::session::Revealed> {
        self.judge_idle();
        let open = self.open.as_mut()?;
        let live = open.revealed.filter(|r| r.remaining_ms() > 0);
        open.revealed = live;
        live
    }

    /// Read the open vault and set what it is revealing, in one pass.
    ///
    /// A way *in* — a person pressed the eye — so the clock is renewed. It
    /// writes no file: a reveal is state for this run, and `with_open_mut` is
    /// the only door that seals and saves.
    pub(crate) fn with_reveal<R>(
        &mut self,
        f: impl FnOnce(&Vault, &mut Option<crate::session::Revealed>) -> ApiResult<R>,
    ) -> ApiResult<R> {
        self.tick();
        match self.open.as_mut() {
            Some(open) => {
                let OpenVault { vault, revealed } = open;
                f(vault, revealed)
            }
            None => Err(ApiError::VaultLocked),
        }
    }

    /// End a reveal now. Infallible on purpose: a locked vault has none to end,
    /// and a person pressing «Hide» a second after it locked itself must not be
    /// answered with a refusal about the vault.
    pub(crate) fn end_reveal(&mut self) {
        if let Some(open) = self.open.as_mut() {
            open.revealed = None;
        }
    }

    /// What the scanner may recognise: this profile's values, and nothing while
    /// the vault is locked.
    pub(crate) fn hints(&mut self, active_profile: Option<&str>) -> Vec<VaultHint> {
        self.tick();
        match self.open.as_ref() {
            Some(open) => open.vault.hints_for(active_profile),
            // Locked: the layer is skipped entirely, by having nothing to say.
            None => Vec::new(),
        }
    }

    /// Durable exceptions effective for this profile, and none while locked.
    pub(crate) fn exceptions(&mut self, active_profile: Option<&str>) -> Vec<UserException> {
        self.tick();
        match self.open.as_ref() {
            Some(open) => open.vault.exceptions_for(active_profile),
            None => Vec::new(),
        }
    }

    /// The label rules this person taught, effective for this profile. Empty
    /// while locked, for the same reason the hints are: a rule is knowledge.
    /// The names the person taught, as the rules want them: the word and
    /// whether it is a surname. Empty while the vault is locked — the layer is
    /// skipped by having nothing to say, not by a flag someone could forget.
    pub(crate) fn taught_names(&mut self, active_profile: Option<&str>) -> Vec<(String, bool)> {
        self.tick();
        match self.open.as_ref() {
            Some(open) => open
                .vault
                .taught_names_for(active_profile)
                .iter()
                .map(|n| (n.text.clone(), n.family))
                .collect(),
            None => Vec::new(),
        }
    }

    /// The rule sets switched on for one profile. Empty when the vault is
    /// locked or the profile is unknown — and the caller then falls back to the
    /// session's own pack rather than scanning with nothing.
    ///
    /// (This comment sat *below* this function and above `naming_for`, which it
    /// did not describe. Deleting `naming_for` in 064 left it dangling and so
    /// found it; it is put where it belongs rather than deleted.)
    pub(crate) fn label_rules(&mut self, active_profile: Option<&str>) -> Vec<crate::scanner::rules::LabelRule> {
        self.tick();
        match self.open.as_ref() {
            Some(open) => open
                .vault
                .label_rules_for(active_profile)
                .iter()
                .map(|r| r.as_rule())
                .collect(),
            None => Vec::new(),
        }
    }

    // ------------------------------------------------- the owner's sessions, 064

    /// The private folder the vault's own file sits in, which is where each
    /// session's sealed file goes too. `None` before a data directory is set.
    pub(crate) fn dir(&self) -> Option<&std::path::Path> {
        self.dir.as_deref()
    }

    /// Every session: number, handle, when it began. **The key is not here**,
    /// and no accessor hands it out — the two things that need it, the naming
    /// and the file's seal, are both below.
    pub(crate) fn conversations(&self) -> Vec<(u32, String, u64)> {
        self.open
            .as_ref()
            .map(|o| {
                o.vault
                    .conversations
                    .iter()
                    .map(|c| (c.number, c.name.clone(), c.began_at))
                    .collect()
            })
            .unwrap_or_default()
    }

    /// **Begin one** — 32 bytes from the operating system, a number that is
    /// never handed out twice, and the handle the person was asked for once.
    ///
    /// `document` is the text of what is on the bench, hashed under this
    /// session's own key, so a restored session can tell that its document
    /// moved and refuse instead of guessing (062 §C). Keyed rather than plain
    /// because it is only ever compared inside the session that wrote it, and a
    /// keyed hash says nothing to anybody else.
    pub(crate) fn begin_conversation(&mut self, name: &str, document: Option<&str>) -> ApiResult<u32> {
        let key = crypto::random_key()?;
        let hash = match document {
            Some(text) => Some(crypto::mac(&key, b"document", text.as_bytes())?),
            None => None,
        };
        let name = name.to_string();
        // `Zeroizing<[u8; 32]>` derefs to a slice through `as_ref`; the array
        // itself is what the record keeps, so take it by value.
        let bytes: [u8; 32] = *key;
        self.with_open_mut(|vault| {
            let number = vault.take_conversation_number();
            vault.conversations.push(crate::vault::model::Conversation {
                number,
                name,
                key: bytes,
                began_at: crate::vault::model::now_seconds(),
                document: hash,
            });
            Ok(number)
        })
    }

    /// Rename one. The number is the identity and never moves; the handle is a
    /// handle, and the owner may change it whenever he likes (062 §0).
    pub(crate) fn rename_conversation(&mut self, number: u32, name: &str) -> ApiResult<()> {
        let name = name.to_string();
        self.with_open_mut(|vault| {
            match vault.conversations.iter_mut().find(|c| c.number == number) {
                Some(talk) => {
                    talk.name = name;
                    Ok(())
                }
                None => Err(ApiError::PayloadRefused {
                    reason: format!("there is no session {number}"),
                }),
            }
        })
    }

    /// **Destroy one's key and record.** The sealed file is removed by the
    /// caller, which owns the data directory — and the key dying here is what
    /// makes the owner's warning a fact: nothing derives anything afterwards.
    pub(crate) fn forget_conversation(&mut self, number: u32) -> ApiResult<String> {
        self.with_open_mut(|vault| {
            let Some(at) = vault.conversations.iter().position(|c| c.number == number) else {
                return Err(ApiError::PayloadRefused {
                    reason: format!("there is no session {number}"),
                });
            };
            let gone = vault.conversations.remove(at);
            Ok(gone.name)
        })
    }

    /// This session's key, for sealing its own file. Private to the crate and
    /// handed out nowhere else.
    pub(crate) fn conversation_key(&self, number: u32) -> Option<crypto::SecretKey> {
        let talk = self.open.as_ref()?.vault.conversation(number)?;
        Some(zeroize::Zeroizing::new(talk.key))
    }

    /// **The naming this session's tokens come from** — 064, and what replaced
    /// `naming_for`'s profile-and-document namespace.
    ///
    /// `None` while the vault is shut or the number is unknown, which is the
    /// same honest answer `naming_for` gave: with no key there is nothing for a
    /// stable name to be stable for, the tokens fall back to random ones, and
    /// an older answer is reported rather than passed through.
    pub(crate) fn naming_of(&mut self, number: u32) -> Option<crate::tokens::Naming> {
        if self.state() != VaultState::Unlocked {
            return None;
        }
        let key = self.conversation_key(number)?;
        crate::tokens::Naming::of_session(&key).ok()
    }

    /// Does this session still belong to the document on the bench? — 062 §C.
    ///
    /// `None` when the session kept no document, which today cannot happen and
    /// is still not treated as «yes»: a build that can open a session with no
    /// document must not find a zeroed hash and believe it.
    pub(crate) fn conversation_matches(&self, number: u32, document: &str) -> Option<bool> {
        let key = self.conversation_key(number)?;
        let kept = self.open.as_ref()?.vault.conversation(number)?.document?;
        let now = crypto::mac(&key, b"document", document.as_bytes()).ok()?;
        Some(kept == now)
    }

    pub(crate) fn languages_of(&self, profile_id: &str) -> Vec<String> {
        self.open
            .as_ref()
            .and_then(|o| o.vault.profiles.iter().find(|p| p.id == profile_id))
            .map(|p| p.languages.clone())
            .unwrap_or_default()
    }

    /// Has the file moved underneath this copy since it read it?
    ///
    /// The refusal is `VaultChangedElsewhere` and carries no reason (050/A).
    /// It used to be `StorageRefused`, which the app renders as «Z Privacy
    /// will not use that location» — and the location is fine: the folder is
    /// writable, the file is intact, and a second window of this program
    /// wrote to it. One sentence, worded in `messages.dart` and nowhere else.
    fn ensure_disk_unchanged(&self) -> ApiResult<()> {
        let Some(path) = self.path() else {
            return Ok(());
        };
        let current = crate::secure_file::read_no_follow(&path, "vault.zv")?;
        if current != self.disk_bytes {
            return Err(ApiError::VaultChangedElsewhere);
        }
        Ok(())
    }

    fn write_to_disk(&mut self) -> ApiResult<()> {
        let (Some(path), Some(sealed)) = (self.path(), self.sealed.as_ref()) else {
            // No folder set: the vault lives for this run only. Used by tests and
            // by a first run before the app has told us where to put it.
            return Ok(());
        };
        let bytes = sealed.to_bytes();
        crate::secure_file::replace_atomically(&path, "zv.new", &bytes, "vault.zv")?;
        self.disk_bytes = Some(bytes);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::{EntityKind, Kind, Policy};
    use crate::secret::Secret;
    use crate::vault::model::{Entity, ValueRecord};

    fn test_dir(name: &str) -> PathBuf {
        // G15-ok: a test's own folder, for the vault file only.
        let dir = std::env::temp_dir().join(format!("zprivacy-test-{name}-{}", std::process::id()));
        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
        dir
    }

    fn cheap_entity(id: u32) -> Entity {
        Entity {
            id,
            kind: EntityKind::Client,
            label: Secret::new("Nordstern Consulting"),
            profile_id: None,
            values: vec![ValueRecord {
                learned_at: crate::vault::model::now_seconds(),
                id: 1,
                kind: Kind::Company,
                value: Secret::new("Nordstern Consulting GmbH"),
                aliases: vec![Secret::new("Nordstern")],
                policy: Policy::Always,
                list: None,
            }],
        }
    }

    #[test]
    fn a_locked_vault_has_nothing_to_say() {
        // Invariant of M4, rule one: locked means the layer does not exist.
        let mut store = VaultStore::default();
        assert_eq!(store.state(), VaultState::Absent);
        assert!(store.hints(None).is_empty());
        assert!(matches!(store.with_open(|_| ()), Err(ApiError::VaultLocked)));
    }

    #[test]
    fn it_survives_being_closed_and_opened_again() {
        let dir = test_dir("reload");
        let pass = "ein gutes Passwort für den Test";

        let mut store = VaultStore::default();
        store.set_dir(dir.clone()).expect("dir");
        assert_eq!(store.state(), VaultState::Absent);
        store.create(pass).expect("create");
        assert_eq!(store.state(), VaultState::Unlocked);

        store
            .with_open_mut(|vault| {
                vault.entities.push(cheap_entity(17));
                vault.next_entity = 18;
                Ok(())
            })
            .expect("add an identity");

        // Lock, and the layer goes silent.
        store.lock();
        assert_eq!(store.state(), VaultState::Locked);
        assert!(store.hints(None).is_empty(), "a locked vault recognises nobody");

        // A fresh store, as if the app had been restarted.
        let mut again = VaultStore::default();
        again.set_dir(dir.clone()).expect("dir");
        assert_eq!(again.state(), VaultState::Locked, "the file is there, sealed");
        assert!(matches!(
            again.unlock("das falsche Passwort"),
            Err(ApiError::VaultAuthenticationFailed)
        ));
        let (entities, values) = again.unlock(pass).expect("unlock");
        assert_eq!((entities, values), (1, 1));

        let hints = again.hints(None);
        assert_eq!(hints.len(), 2, "the value and its alias");
        assert_eq!(hints[0].entity_handle, "CLIENT #17");

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// **050/A · a locked copy is not told to lock.**
    ///
    /// `with_open_mut` looked at the disk before it looked at its own state, so
    /// a copy whose vault was **locked** over a changed file was refused with
    /// «the vault file changed on disk while this copy was open; lock and
    /// unlock before changing it» — advice to lock, given to someone already
    /// locked, about a copy that is not open. The true answer is one word:
    /// `VaultLocked`.
    #[test]
    fn a_locked_copy_over_a_changed_file_says_it_is_locked() {
        let dir = test_dir("locked-and-changed");
        let pass = "ein gutes Passwort für den Test";

        let mut first = VaultStore::default();
        first.set_dir(dir.clone()).expect("dir");
        first.create(pass).expect("create");

        let mut copy = VaultStore::default();
        copy.set_dir(dir.clone()).expect("dir copy");
        copy.unlock(pass).expect("unlock copy");

        // The control: locked, disk untouched. If this were anything but
        // `VaultLocked` the test below would prove nothing about the disk.
        copy.lock();
        match copy.with_open_mut(|_| Ok(())) {
            Err(ApiError::VaultLocked) => {}
            other => panic!("locked with the disk untouched gave {other:?}"),
        }

        // And now the disk moves underneath it. The copy is still locked, and
        // that is still the whole of what is wrong with the call.
        first
            .with_open_mut(|vault| {
                vault.entities.push(cheap_entity(17));
                vault.next_entity = 18;
                Ok(())
            })
            .expect("the other copy writes");
        match copy.with_open_mut(|_| Ok(())) {
            Err(ApiError::VaultLocked) => {}
            other => panic!("a locked copy over a changed file was told to lock: {other:?}"),
        }

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// **050/A · the conflict has its own name, and its own sentence.**
    ///
    /// `StorageRefused` renders as «Z Privacy will not use that location», and
    /// the location is fine — another window of Z wrote. The variant above it
    /// carries the contract this broke: *the fault is in a location, and the
    /// reason names which one and why*.
    #[test]
    fn a_conflict_is_named_for_the_other_window_not_for_the_folder() {
        let dir = test_dir("named-conflict");
        let pass = "ein gutes Passwort für den Test";

        let mut first = VaultStore::default();
        first.set_dir(dir.clone()).expect("dir");
        first.create(pass).expect("create");
        let mut copy = VaultStore::default();
        copy.set_dir(dir.clone()).expect("dir copy");
        copy.unlock(pass).expect("unlock copy");

        first
            .with_open_mut(|vault| {
                vault.entities.push(cheap_entity(17));
                vault.next_entity = 18;
                Ok(())
            })
            .expect("the other copy writes");

        match copy.with_open_mut(|vault| {
            vault.entities.push(cheap_entity(18));
            Ok(())
        }) {
            Err(ApiError::VaultChangedElsewhere) => {}
            other => panic!("the conflict is still named after a folder: {other:?}"),
        }

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// **050/C, the part that is real: a `create` that fails must leave the copy
    /// as it was.**
    ///
    /// The paper's own case — a second copy pressing create minutes later —
    /// does **not** reproduce: `create` calls `load_sealed()` first, which
    /// re-reads whenever nothing is held, so it is refused with
    /// `VaultAlreadyExists` before anything is touched. That is measured in
    /// `a_refused_create_leaves_the_copy_as_it_was`, which was green before a
    /// line of 050/C was written.
    ///
    /// What is real is the ordering underneath it: `master` and `open` were set
    /// **before** the disk was written, so a `create` that failed for any
    /// reason left memory holding an open vault that is not on disk, under a
    /// passphrase the file does not know. No race is needed to show it, which
    /// is the point — the defect was never about timing.
    ///
    /// The lever is a leftover `vault.zv.new`, which is what a write killed
    /// half-way through leaves behind: `replace_atomically` opens its temp file
    /// with `create_new`, so it refuses rather than write over one. A read-only
    /// folder is **not** a lever, and that is worth knowing — `secure_dir`
    /// repairs the folder to 0o700 on the way past, so Z mends its own
    /// permissions before it writes.
    #[test]
    fn a_create_that_cannot_reach_the_disk_keeps_nothing() {
        let dir = test_dir("create-no-disk");
        // `set_dir` makes the folder itself, through `secure_dir` — so this
        // test touches the filesystem once, for the leftover below, and G15
        // has one exemption to count rather than two.
        let mut store = VaultStore::default();
        store.set_dir(dir.clone()).expect("dir");
        assert_eq!(store.state(), VaultState::Absent);

        // G15-ok: a test's own folder, standing in for a half-written file.
        std::fs::write(dir.join("vault.zv.new"), b"half a vault").expect("the leftover");

        let refused = store.create("ein gutes Passwort für den Test");
        assert!(refused.is_err(), "a create that could not write said {refused:?}");
        assert_eq!(
            store.state(),
            VaultState::Absent,
            "a create that never reached the disk left this copy holding an open vault"
        );
        assert!(
            !dir.join(FILE_NAME).exists(),
            "there is no vault on disk, and the copy must not pretend otherwise"
        );

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// **050/C · a copy that was started first does not create into memory.**
    ///
    /// A copy opened while no vault existed still shows the create screen after
    /// another copy has made one. The person types a passphrase and presses
    /// create — and `master` and `open` were set before anything looked at the
    /// disk, so a refusal left memory holding an open vault that is not on disk
    /// under a passphrase the file does not know.
    ///
    /// What this asserts is the only thing a person can check: **`state()` is
    /// exactly what it was before the press.**
    #[test]
    fn a_refused_create_leaves_the_copy_as_it_was() {
        let dir = test_dir("refused-create");
        let pass = "ein gutes Passwort für den Test";

        // The copy that was started first, while there was nothing here. It
        // asks once — which is what a first run does — and finds nothing.
        let mut early = VaultStore::default();
        early.set_dir(dir.clone()).expect("dir early");
        let before = early.state();
        assert_eq!(before, VaultState::Absent, "the early copy saw a vault that was not there");

        // Another copy creates one.
        let mut other = VaultStore::default();
        other.set_dir(dir.clone()).expect("dir other");
        other.create(pass).expect("create");

        // The early copy still shows its create screen, and the person presses.
        match early.create("ein ganz anderes Passwort") {
            Err(ApiError::VaultAlreadyExists) => {}
            other => panic!("the second create gave {other:?}"),
        }
        assert_eq!(
            early.state(),
            VaultState::Locked,
            "a refused create left this copy holding something: {:?}",
            early.state()
        );

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn two_open_copies_do_not_overwrite_each_other() {
        let dir = test_dir("two-copies");
        let pass = "ein gutes Passwort für den Test";

        let mut first = VaultStore::default();
        first.set_dir(dir.clone()).expect("dir");
        first.create(pass).expect("create");

        let mut copy_a = VaultStore::default();
        copy_a.set_dir(dir.clone()).expect("dir a");
        copy_a.unlock(pass).expect("unlock a");

        let mut copy_b = VaultStore::default();
        copy_b.set_dir(dir.clone()).expect("dir b");
        copy_b.unlock(pass).expect("unlock b");

        copy_a
            .with_open_mut(|vault| {
                vault.entities.push(cheap_entity(17));
                vault.next_entity = 18;
                Ok(())
            })
            .expect("copy a writes");

        match copy_b.with_open_mut(|vault| {
            vault.entities.push(cheap_entity(18));
            Ok(())
        }) {
            // It refused with `StorageRefused { "…changed on disk…" }` when this
            // guard was written, and 050/A gave the conflict its own name: the
            // place was never the trouble. The property it measures — a stale
            // copy does not overwrite — has not changed at all.
            Err(ApiError::VaultChangedElsewhere) => {}
            other => panic!("a stale open copy must not overwrite the vault: {other:?}"),
        }

        let mut again = VaultStore::default();
        again.set_dir(dir.clone()).expect("dir again");
        again.unlock(pass).expect("unlock again");
        again
            .with_open(|vault| {
                assert_eq!(vault.entities.len(), 1, "the first writer's change survived");
                assert_eq!(vault.entities[0].id, 17);
            })
            .expect("read again");

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn the_file_on_disk_never_holds_the_words() {
        let dir = test_dir("bytes");
        let mut store = VaultStore::default();
        store.set_dir(dir.clone()).expect("dir");
        store.create("ein gutes Passwort für den Test").expect("create");
        store
            .with_open_mut(|vault| {
                vault.entities.push(cheap_entity(17));
                Ok(())
            })
            .expect("add");

        // G15-ok: the test reads the vault file to prove it is encrypted.
        let bytes = std::fs::read(dir.join(FILE_NAME)).expect("read the file");
        let as_text = String::from_utf8_lossy(&bytes);
        assert!(!as_text.contains("Nordstern"), "the vault file is not encrypted");
        assert!(bytes.starts_with(b"ZVLT"), "and it names its own format");

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn unlock_names_an_unsupported_kdf_file() {
        let dir = test_dir("kdf-refusal");
        let pass = "ein gutes Passwort für den Test";

        let mut store = VaultStore::default();
        store.set_dir(dir.clone()).expect("dir");
        store.create(pass).expect("create");
        store.lock();

        let path = dir.join(FILE_NAME);
        // G15-ok: the test mutates its own sealed vault file.
        let mut bytes = std::fs::read(&path).expect("read the vault");
        bytes[7..11].copy_from_slice(&1_000_000u32.to_be_bytes());
        // G15-ok: the test writes back its own mutated sealed vault file.
        std::fs::write(&path, bytes).expect("write the mutated vault");

        let mut again = VaultStore::default();
        again.set_dir(dir.clone()).expect("dir");
        assert_eq!(again.state(), VaultState::Locked, "the file is present but unsupported");
        match again.unlock(pass) {
            Err(ApiError::UnsupportedKdfParameters { reason }) => assert!(reason.contains("m_cost")),
            other => panic!("expected UnsupportedKdfParameters, got {other:?}"),
        }

        // G15-ok: cleaning a test's own folder.
        let _ = std::fs::remove_dir_all(&dir);
    }
}

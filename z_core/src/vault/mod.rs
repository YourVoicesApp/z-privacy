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
    /// A file was present, but could not be parsed. Kept so `state()` can stay
    /// infallible and `unlock()` can still name the refusal.
    sealed_error: Option<ApiError>,
    /// Present only while unlocked. Wiped on lock.
    master: Option<SecretKey>,
    /// The decrypted model. Present only while unlocked.
    open: Option<Vault>,
    /// When the vault was last used, and how long it may sit unused.
    ///
    /// Auto-lock is enforced **here** rather than by a timer in the UI (task
    /// 030). A screen that forgot to count would leave the vault open and
    /// nobody would know; this way every way in checks the clock first.
    touched: Option<Instant>,
    idle_limit: Option<Duration>,
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
                    self.sealed_error = None;
                }
                Err(err) => {
                    self.sealed = None;
                    self.sealed_error = Some(err);
                }
            },
            Ok(None) => {}
            Err(err) => {
                self.sealed = None;
                self.sealed_error = Some(err);
            }
        }
    }

    /// How long the vault may sit unused, in minutes. 0 means never.
    pub(crate) fn set_idle_limit(&mut self, minutes: u32) {
        self.idle_limit = (minutes > 0).then(|| Duration::from_secs(u64::from(minutes) * 60));
        self.touched = Some(Instant::now());
    }

    /// Lock it if it has been sitting too long, and note that it is being used.
    ///
    /// Called by every way into the open vault, so «auto-lock» is a property of
    /// the vault and not of whoever remembered to set a timer.
    fn tick(&mut self) {
        if self.open.is_none() {
            return;
        }
        if let (Some(limit), Some(touched)) = (self.idle_limit, self.touched) {
            if touched.elapsed() > limit {
                self.lock();
                return;
            }
        }
        self.touched = Some(Instant::now());
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
            return Err(ApiError::ImportRefused {
                reason: "a vault already exists on this device".to_string(),
            });
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
        self.sealed = Some(sealed);
        self.master = Some(master);
        self.open = Some(model);
        self.set_idle_limit(minutes);
        self.write_to_disk()?;
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
        let sealed = self.sealed.as_ref().ok_or(ApiError::ImportRefused {
            reason: "there is no vault on this device yet".to_string(),
        })?;
        let master = sealed.unwrap_master(passphrase)?;
        let body = sealed.open_body(&master)?;
        let model = format::decode(&body, &master, sealed.credentials_are_sealed())?;
        let counts = (
            model.entities.len() as u32,
            model.entities.iter().map(|e| e.values.len() as u32).sum(),
        );
        let minutes = model.settings.auto_lock_minutes;
        self.master = Some(master);
        self.open = Some(model);
        self.set_idle_limit(minutes);
        Ok(counts)
    }

    /// Close it. The master key is dropped — and `SecretKey` wipes itself — and
    /// the decrypted contents go with it.
    pub(crate) fn lock(&mut self) {
        self.sealed = None;
        self.sealed_error = None;
        self.master = None;
        self.open = None;
        self.touched = None;
    }

    pub(crate) fn change_passphrase(&mut self, old: &str, replacement: &str) -> ApiResult<()> {
        self.load_sealed();
        if let Some(err) = self.sealed_error.clone() {
            return Err(err);
        }
        let sealed = self.sealed.as_mut().ok_or(ApiError::ImportRefused {
            reason: "there is no vault on this device yet".to_string(),
        })?;
        sealed.change_passphrase(old, replacement)?;
        self.write_to_disk()
    }

    /// Read the open vault, or say it is locked.
    pub(crate) fn with_open<R>(&mut self, f: impl FnOnce(&Vault) -> R) -> ApiResult<R> {
        self.tick();
        match self.open.as_ref() {
            Some(vault) => Ok(f(vault)),
            None => Err(ApiError::VaultLocked),
        }
    }

    /// Read the open vault with a closure that can fail on its own.
    pub(crate) fn read<R>(&mut self, f: impl FnOnce(&Vault) -> ApiResult<R>) -> ApiResult<R> {
        self.tick();
        match self.open.as_ref() {
            Some(vault) => f(vault),
            None => Err(ApiError::VaultLocked),
        }
    }

    /// Change the open vault and seal it again. Nothing here can leave the device.
    pub(crate) fn with_open_mut<R>(&mut self, f: impl FnOnce(&mut Vault) -> ApiResult<R>) -> ApiResult<R> {
        self.tick();
        let (Some(vault), Some(master)) = (self.open.as_mut(), self.master.as_ref()) else {
            return Err(ApiError::VaultLocked);
        };
        let out = f(vault)?;
        let body = format::encode(vault, master)?;
        let sealed = self.sealed.as_mut().ok_or(ApiError::VaultLocked)?;
        sealed.reseal_body(master, &body)?;
        crypto::wipe(body);
        self.write_to_disk()?;
        Ok(out)
    }

    /// What the scanner may recognise: this profile's values, and nothing while
    /// the vault is locked.
    pub(crate) fn hints(&mut self, active_profile: Option<&str>) -> Vec<VaultHint> {
        self.tick();
        match self.open.as_ref() {
            Some(vault) => vault.hints_for(active_profile),
            // Locked: the layer is skipped entirely, by having nothing to say.
            None => Vec::new(),
        }
    }

    /// Durable exceptions effective for this profile, and none while locked.
    pub(crate) fn exceptions(&mut self, active_profile: Option<&str>) -> Vec<UserException> {
        self.tick();
        match self.open.as_ref() {
            Some(vault) => vault.exceptions_for(active_profile),
            None => Vec::new(),
        }
    }

    /// The label rules this person taught, effective for this profile. Empty
    /// while locked, for the same reason the hints are: a rule is knowledge.
    pub(crate) fn label_rules(&mut self, active_profile: Option<&str>) -> Vec<crate::scanner::rules::LabelRule> {
        self.tick();
        match self.open.as_ref() {
            Some(vault) => vault
                .label_rules_for(active_profile)
                .iter()
                .map(|r| r.as_rule())
                .collect(),
            None => Vec::new(),
        }
    }

    /// The rule sets switched on for one profile. Empty when the vault is
    /// locked or the profile is unknown — and the caller then falls back to the
    /// session's own pack rather than scanning with nothing.
    pub(crate) fn languages_of(&self, profile_id: &str) -> Vec<String> {
        self.open
            .as_ref()
            .and_then(|v| v.profiles.iter().find(|p| p.id == profile_id))
            .map(|p| p.languages.clone())
            .unwrap_or_default()
    }

    fn write_to_disk(&self) -> ApiResult<()> {
        let (Some(path), Some(sealed)) = (self.path(), self.sealed.as_ref()) else {
            // No folder set: the vault lives for this run only. Used by tests and
            // by a first run before the app has told us where to put it.
            return Ok(());
        };
        let bytes = sealed.to_bytes();
        crate::secure_file::replace_atomically(&path, "zv.new", &bytes, "vault.zv")?;
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

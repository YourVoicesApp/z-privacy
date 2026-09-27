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

use crate::api::{ApiError, ApiResult, VaultState};
use crate::vault::crypto::{SealedVault, SecretKey};
use crate::vault::model::{Vault, VaultHint};

const FILE_NAME: &str = "vault.zv";

/// Where the vault is, whether it is open, and what it holds when it is.
#[derive(Debug, Default)]
pub(crate) struct VaultStore {
    dir: Option<PathBuf>,
    /// The file as it sits on disk, whether or not it is open.
    sealed: Option<SealedVault>,
    /// Present only while unlocked. Wiped on lock.
    master: Option<SecretKey>,
    /// The decrypted model. Present only while unlocked.
    open: Option<Vault>,
}

impl VaultStore {
    pub(crate) fn set_dir(&mut self, dir: PathBuf) -> ApiResult<()> {
        if !dir.is_dir() {
            // G15-ok: the folder for the sealed vault, never for a document.
            std::fs::create_dir_all(&dir).map_err(|e| ApiError::ImportRefused {
                reason: format!("this folder cannot be used for the vault: {e}"),
            })?;
        }
        self.dir = Some(dir);
        // Forget anything that was open for the old folder.
        self.lock();
        self.sealed = None;
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
        // G15-ok: reading the sealed vault file.
        if let Ok(bytes) = std::fs::read(&path) {
            self.sealed = SealedVault::from_bytes(&bytes).ok();
        }
    }

    pub(crate) fn state(&mut self) -> VaultState {
        self.load_sealed();
        if self.open.is_some() {
            VaultState::Unlocked
        } else if self.sealed.is_some() {
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
        let body = format::encode(&model);
        let (sealed, master) = SealedVault::create(passphrase, &body)?;
        self.sealed = Some(sealed);
        self.master = Some(master);
        self.open = Some(model);
        self.write_to_disk()?;
        Ok((0, 0))
    }

    /// Open it: derive, unwrap the master key, decrypt the contents.
    pub(crate) fn unlock(&mut self, passphrase: &str) -> ApiResult<(u32, u32)> {
        self.load_sealed();
        let sealed = self.sealed.as_ref().ok_or(ApiError::ImportRefused {
            reason: "there is no vault on this device yet".to_string(),
        })?;
        let master = sealed.unwrap_master(passphrase)?;
        let body = sealed.open_body(&master)?;
        let model = format::decode(&body)?;
        let counts = (
            model.entities.len() as u32,
            model.entities.iter().map(|e| e.values.len() as u32).sum(),
        );
        self.master = Some(master);
        self.open = Some(model);
        Ok(counts)
    }

    /// Close it. The master key is dropped — and `SecretKey` wipes itself — and
    /// the decrypted contents go with it.
    pub(crate) fn lock(&mut self) {
        self.master = None;
        self.open = None;
    }

    pub(crate) fn change_passphrase(&mut self, old: &str, replacement: &str) -> ApiResult<()> {
        self.load_sealed();
        let sealed = self.sealed.as_mut().ok_or(ApiError::ImportRefused {
            reason: "there is no vault on this device yet".to_string(),
        })?;
        sealed.change_passphrase(old, replacement)?;
        self.write_to_disk()
    }

    /// Read the open vault, or say it is locked.
    pub(crate) fn with_open<R>(&mut self, f: impl FnOnce(&Vault) -> R) -> ApiResult<R> {
        match self.open.as_ref() {
            Some(vault) => Ok(f(vault)),
            None => Err(ApiError::VaultLocked),
        }
    }

    /// Read the open vault with a closure that can fail on its own.
    pub(crate) fn read<R>(&mut self, f: impl FnOnce(&Vault) -> ApiResult<R>) -> ApiResult<R> {
        match self.open.as_ref() {
            Some(vault) => f(vault),
            None => Err(ApiError::VaultLocked),
        }
    }

    /// Change the open vault and seal it again. Nothing here can leave the device.
    pub(crate) fn with_open_mut<R>(&mut self, f: impl FnOnce(&mut Vault) -> ApiResult<R>) -> ApiResult<R> {
        let (Some(vault), Some(master)) = (self.open.as_mut(), self.master.as_ref()) else {
            return Err(ApiError::VaultLocked);
        };
        let out = f(vault)?;
        let body = format::encode(vault);
        let sealed = self.sealed.as_mut().ok_or(ApiError::VaultLocked)?;
        sealed.reseal_body(master, &body)?;
        crypto::wipe(body);
        self.write_to_disk()?;
        Ok(out)
    }

    /// What the scanner may recognise: this profile's values, and nothing while
    /// the vault is locked.
    pub(crate) fn hints(&self, active_profile: Option<&str>) -> Vec<VaultHint> {
        match self.open.as_ref() {
            Some(vault) => vault.hints_for(active_profile),
            // Locked: the layer is skipped entirely, by having nothing to say.
            None => Vec::new(),
        }
    }

    fn write_to_disk(&self) -> ApiResult<()> {
        let (Some(path), Some(sealed)) = (self.path(), self.sealed.as_ref()) else {
            // No folder set: the vault lives for this run only. Used by tests and
            // by a first run before the app has told us where to put it.
            return Ok(());
        };
        let bytes = sealed.to_bytes();
        // Write beside it and rename, so a crash cannot leave half a vault.
        let temporary = path.with_extension("zv.new");
        // G15-ok: the sealed vault is the only file this crate writes.
        std::fs::write(&temporary, &bytes).map_err(|e| ApiError::ImportRefused {
            reason: format!("the vault could not be written: {e}"),
        })?;
        // G15-ok: rename into place, so a crash cannot leave half a vault.
        std::fs::rename(&temporary, &path).map_err(|e| ApiError::ImportRefused {
            reason: format!("the vault could not be put in place: {e}"),
        })?;
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
        assert!(matches!(again.unlock("das falsche Passwort"), Err(ApiError::VaultLocked)));
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
}

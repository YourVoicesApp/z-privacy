//! The vault's side of the contract.
//!
//! Nothing here can put a value on the wire: the vault's job is to *recognise*,
//! and recognising happens by handing the scanner a flat list of hints for the
//! active profile. That is why the owner's second rule is true by construction —
//! opening the vault does not make every name automatic; only a value the vault
//! actually holds, in the profile that is actually active, becomes automatic.

use std::path::PathBuf;

use crate::api::{
    ApiError, ApiResult, EntityCard, EntityKind, EntityRow, Kind, Policy, RevealedValue, VaultState,
    VaultUnlockOutcome, ValueRow,
};
use crate::secret::Secret;
use crate::session::with_core;
use crate::vault::model::{Entity, ValueRecord};

/// How long a revealed vault value stays on screen. The same 20 seconds as a
/// revealed token: one habit, not two.
const REVEAL_TTL_MS: u32 = 20_000;

pub(crate) fn set_data_dir(dir: String) -> ApiResult<()> {
    with_core(|core| core.vault.set_dir(PathBuf::from(dir)))
}

pub(crate) fn vault_state() -> ApiResult<VaultState> {
    Ok(with_core(|core| core.vault.state()))
}

pub(crate) fn vault_create(passphrase: String) -> ApiResult<VaultUnlockOutcome> {
    if passphrase.chars().count() < 8 {
        return Err(ApiError::ImportRefused {
            reason: "a vault passphrase needs at least eight characters".to_string(),
        });
    }
    let (identities, values) = with_core(|core| core.vault.create(&passphrase))?;
    Ok(VaultUnlockOutcome::Unlocked { identities, values })
}

pub(crate) fn vault_unlock(passphrase: String) -> ApiResult<VaultUnlockOutcome> {
    match with_core(|core| core.vault.unlock(&passphrase)) {
        Ok((identities, values)) => Ok(VaultUnlockOutcome::Unlocked { identities, values }),
        // A wrong passphrase is not an error to shout about; it is an answer.
        // No attempt counter yet: rate limiting arrives with the UI in M7.
        Err(ApiError::VaultLocked) => Ok(VaultUnlockOutcome::WrongPassphrase { attempts_left: 0 }),
        Err(other) => Err(other),
    }
}

pub(crate) fn vault_lock() -> ApiResult<()> {
    with_core(|core| core.vault.lock());
    Ok(())
}

pub(crate) fn vault_change_passphrase(old: String, replacement: String) -> ApiResult<()> {
    if replacement.chars().count() < 8 {
        return Err(ApiError::ImportRefused {
            reason: "a vault passphrase needs at least eight characters".to_string(),
        });
    }
    with_core(|core| core.vault.change_passphrase(&old, &replacement))
}

// ---------------------------------------------------------------- identities

pub(crate) fn entities(profile_id: Option<String>) -> ApiResult<Vec<EntityRow>> {
    with_core(|core| {
        core.vault.with_open(|vault| {
            vault
                .entities
                .iter()
                .filter(|e| match (&profile_id, &e.profile_id) {
                    (None, _) => true,
                    (Some(wanted), Some(mine)) => wanted == mine,
                    (Some(_), None) => true, // an entity of no profile belongs everywhere
                })
                .map(|e| EntityRow {
                    id: e.id,
                    kind: e.kind,
                    label: e.label.expose().to_string(),
                    profile_id: e.profile_id.clone(),
                    values: e.values.len() as u32,
                    policy_summary: e.policy_summary(),
                })
                .collect::<Vec<EntityRow>>()
        })
    })
}

pub(crate) fn entity(entity_id: u32) -> ApiResult<EntityCard> {
    with_core(|core| {
        core.vault.read(|vault| {
            let e = vault.entity(entity_id).ok_or(ApiError::UnknownToken)?;
            Ok(EntityCard {
                id: e.id,
                kind: e.kind,
                label: e.label.expose().to_string(),
                profile_id: e.profile_id.clone(),
                values: e
                    .values
                    .iter()
                    .map(|v| ValueRow {
                        id: v.id,
                        kind: v.kind,
                        aliases: v.aliases.len() as u32,
                        policy: v.policy,
                    })
                    .collect(),
            })
        })
    })
}

pub(crate) fn create_entity(kind: EntityKind, label: String, profile_id: Option<String>) -> ApiResult<u32> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let id = vault.take_entity_id();
            vault.entities.push(Entity {
                id,
                kind,
                label: Secret::new(label),
                profile_id,
                values: Vec::new(),
            });
            Ok(id)
        })
    })
}

pub(crate) fn delete_entity(entity_id: u32) -> ApiResult<()> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let before = vault.entities.len();
            vault.entities.retain(|e| e.id != entity_id);
            if vault.entities.len() == before {
                return Err(ApiError::UnknownToken);
            }
            Ok(())
        })
    })
}

pub(crate) fn set_value(
    entity: u32,
    value_id: Option<u32>,
    kind: Kind,
    text: String,
    policy: Policy,
) -> ApiResult<u32> {
    if text.is_empty() {
        return Err(ApiError::ImportRefused {
            reason: "an empty value would match everything and protect nothing".to_string(),
        });
    }
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let fresh_id = vault.take_value_id();
            let target = vault.entity_mut(entity).ok_or(ApiError::UnknownToken)?;
            match value_id {
                Some(id) => {
                    let existing = target
                        .values
                        .iter_mut()
                        .find(|v| v.id == id)
                        .ok_or(ApiError::UnknownToken)?;
                    existing.kind = kind;
                    existing.value = Secret::new(text);
                    existing.policy = policy;
                    Ok(id)
                }
                None => {
                    target.values.push(ValueRecord {
                        id: fresh_id,
                        kind,
                        value: Secret::new(text),
                        aliases: Vec::new(),
                        policy,
                    });
                    Ok(fresh_id)
                }
            }
        })
    })
}

pub(crate) fn add_value_alias(entity: u32, value_id: u32, alias: String) -> ApiResult<()> {
    if alias.is_empty() {
        return Err(ApiError::ImportRefused {
            reason: "an empty spelling is not a spelling".to_string(),
        });
    }
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let target = vault.entity_mut(entity).ok_or(ApiError::UnknownToken)?;
            let value = target
                .values
                .iter_mut()
                .find(|v| v.id == value_id)
                .ok_or(ApiError::UnknownToken)?;
            if !value.matches(&alias) {
                value.aliases.push(Secret::new(alias));
            }
            Ok(())
        })
    })
}

pub(crate) fn reveal_value(entity: u32, value_id: u32) -> ApiResult<RevealedValue> {
    with_core(|core| {
        core.vault.read(|vault| {
            let e = vault.entity(entity).ok_or(ApiError::UnknownToken)?;
            let v = e
                .values
                .iter()
                .find(|v| v.id == value_id)
                .ok_or(ApiError::UnknownToken)?;
            Ok(RevealedValue {
                // Named by its identity, not by a token: this is the vault, not a
                // conversation.
                token: format!("{} · value {}", e.handle(), v.id),
                value: v.value.expose().to_string(),
                ttl_ms: REVEAL_TTL_MS,
            })
        })
    })
}

// ---------------------------------------------------------------- profiles

pub(crate) fn create_profile(name: String) -> ApiResult<String> {
    if name.is_empty() {
        return Err(ApiError::ImportRefused {
            reason: "a profile needs a name you will recognise".to_string(),
        });
    }
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            // An id made from the name, so a log line names a client only as the
            // user already named them — never a value from inside the vault.
            let slug: String = name
                .chars()
                .map(|c| if c.is_alphanumeric() { c.to_ascii_lowercase() } else { '-' })
                .collect();
            let id = format!("p-{}-{}", slug.trim_matches('-'), vault.profiles.len() + 1);
            vault.profiles.push(crate::vault::model::Profile {
                id: id.clone(),
                name,
            });
            Ok(id)
        })
    })
}

/// `id\tname` per profile — one line the UI can split, without a new type.
pub(crate) fn profiles() -> ApiResult<Vec<String>> {
    with_core(|core| {
        core.vault.with_open(|vault| {
            vault
                .profiles
                .iter()
                .map(|p| format!("{}\t{}", p.id, p.name))
                .collect::<Vec<String>>()
        })
    })
}

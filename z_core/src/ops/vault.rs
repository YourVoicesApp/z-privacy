//! The vault's side of the contract.
//!
//! Nothing here can put a value on the wire: the vault's job is to *recognise*,
//! and recognising happens by handing the scanner a flat list of hints for the
//! active profile. That is why the owner's second rule is true by construction —
//! opening the vault does not make every name automatic; only a value the vault
//! actually holds, in the profile that is actually active, becomes automatic.

use std::path::PathBuf;

use crate::api::{
    ApiError, ApiResult, EntityCard, EntityKind, EntityRow, Kind, KindRow, Policy, ProfileRow,
    ForgetPlan, RevealedValue, Settings, VaultState, VaultUnlockOutcome, ValueRow,
};
use crate::secret::Secret;
use crate::session::with_core;
use crate::vault::model::{Entity, StoredSettings, ValueRecord};

pub(crate) fn set_data_dir(dir: String) -> ApiResult<()> {
    let path = PathBuf::from(dir);
    with_core(|core| {
        core.vault.set_dir(path.clone())?;
        // The settings file lives beside the vault, and is read at once so a
        // first run is known before anything else is asked.
        core.config.set_dir(&path)?;
        Ok(())
    })
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
    crate::session::bump_truth();
    Ok(VaultUnlockOutcome::Unlocked { identities, values })
}

pub(crate) fn vault_unlock(passphrase: String) -> ApiResult<VaultUnlockOutcome> {
    match with_core(|core| core.vault.unlock(&passphrase)) {
        Ok((identities, values)) => {
            crate::session::bump_truth();
            Ok(VaultUnlockOutcome::Unlocked { identities, values })
        }
        Err(other) => Err(other),
    }
}

pub(crate) fn vault_lock() -> ApiResult<()> {
    with_core(|core| core.vault.lock());
    crate::session::bump_truth();
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
                        learned_at: crate::vault::model::now_seconds(),
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
    // Before the lock: see the note in `ops::reveal`.
    let ttl_ms = reveal_ttl_ms();
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
                aliases: v.aliases.iter().map(|a| a.expose().to_string()).collect(),
                ttl_ms,
            })
        })
    })
}

/// Rename an identity.
pub(crate) fn rename_entity(entity_id: u32, label: String) -> ApiResult<()> {
    let label = label.trim().to_string();
    if label.is_empty() {
        return Err(ApiError::ImportRefused {
            reason: "an identity needs a name".to_string(),
        });
    }
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let e = vault.entity_mut(entity_id).ok_or(ApiError::UnknownToken)?;
            e.label = Secret::new(label);
            Ok(())
        })
    })
}

/// Move an identity between profiles. `None` means everywhere.
///
/// It refuses a profile that does not exist rather than quietly making the
/// identity invisible: an entity scoped to a profile nobody can select is a
/// value the scanner will never find again.
pub(crate) fn move_entity(entity_id: u32, profile_id: Option<String>) -> ApiResult<()> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            if let Some(wanted) = &profile_id {
                if !vault.profiles.iter().any(|p| &p.id == wanted) {
                    return Err(ApiError::ImportRefused {
                        reason: format!("there is no profile «{wanted}»"),
                    });
                }
            }
            let e = vault.entity_mut(entity_id).ok_or(ApiError::UnknownToken)?;
            e.profile_id = profile_id;
            Ok(())
        })
    })
}

/// Forget one value, keeping its identity.
pub(crate) fn delete_value(entity: u32, value_id: u32) -> ApiResult<()> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let e = vault.entity_mut(entity).ok_or(ApiError::UnknownToken)?;
            let before = e.values.len();
            e.values.retain(|v| v.id != value_id);
            if e.values.len() == before {
                return Err(ApiError::UnknownToken);
            }
            Ok(())
        })
    })
}

/// Forget one spelling. The value itself is never removed this way — a value
/// with no spellings would be a value the scanner could not match.
pub(crate) fn remove_value_alias(entity: u32, value_id: u32, alias: String) -> ApiResult<()> {
    let wanted = crate::text::nfc(&alias);
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let e = vault.entity_mut(entity).ok_or(ApiError::UnknownToken)?;
            let v = e
                .values
                .iter_mut()
                .find(|v| v.id == value_id)
                .ok_or(ApiError::UnknownToken)?;
            let before = v.aliases.len();
            v.aliases.retain(|a| crate::text::nfc(a.expose()) != wanted);
            if v.aliases.len() == before {
                return Err(ApiError::UnknownToken);
            }
            Ok(())
        })
    })
}

/// Search the vault, here, in memory.
///
/// It looks at labels, values and every spelling — so it reads secrets — and
/// hands back **rows only**. Which field matched is deliberately not reported:
/// a result that said «matched on its IBAN» would print a fact about a secret
/// onto a screen that was only asked «who is this».
pub(crate) fn search_vault(query: String) -> ApiResult<Vec<EntityRow>> {
    let needle = crate::text::nfc(query.trim()).to_lowercase();
    with_core(|core| {
        core.vault.with_open(|vault| {
            if needle.is_empty() {
                return rows_of(vault.entities.iter());
            }
            let hit = |text: &str| crate::text::nfc(text).to_lowercase().contains(&needle);
            rows_of(vault.entities.iter().filter(|e| {
                hit(e.label.expose())
                    || e.values
                        .iter()
                        .any(|v| v.spellings().iter().any(|s| hit(s)))
            }))
        })
    })
}

fn rows_of<'a>(entities: impl Iterator<Item = &'a crate::vault::model::Entity>) -> Vec<EntityRow> {
    entities
        .map(|e| EntityRow {
            id: e.id,
            kind: e.kind,
            label: e.label.expose().to_string(),
            profile_id: e.profile_id.clone(),
            values: e.values.len() as u32,
            policy_summary: e.policy_summary(),
        })
        .collect()
}

/// Every kind this build knows, with the core's own label for it.
///
/// A list, not an enumeration a screen performs on `Kind::values`: the day a
/// user-made kind exists it is one more row here and nothing above changes.
pub(crate) fn kinds() -> ApiResult<Vec<KindRow>> {
    Ok([
        (Kind::Person, "Person"),
        (Kind::Company, "Company"),
        (Kind::Client, "Client"),
        (Kind::Project, "Project"),
        (Kind::Contract, "Contract"),
        (Kind::Email, "E-mail"),
        (Kind::Phone, "Phone"),
        (Kind::Address, "Address"),
        (Kind::Iban, "IBAN"),
        (Kind::Bic, "BIC"),
        (Kind::Account, "Account number"),
        (Kind::TaxId, "Tax ID"),
        (Kind::CustomerNo, "Customer number"),
        (Kind::Custom, "Something else"),
    ]
    .into_iter()
    .map(|(kind, label)| KindRow {
        kind,
        label: label.to_string(),
        // No user-made kinds yet. The field is here so that the screen reading
        // it is already written for the day there are.
        custom: false,
    })
    .collect())
}

/// What the app has been told to do by itself.
///
/// From the vault when one is open, from this run's memory otherwise — and the
/// answer always says which, so a screen can tell the user that a setting will
/// not survive the app closing.
pub(crate) fn settings() -> ApiResult<Settings> {
    with_core(|core| {
        let file = core.config.get();
        let kept_for_this_run = core.vault.with_open(|v| v.settings.clone()).is_err();
        let behaviour = match core.vault.with_open(|v| v.settings.clone()) {
            Ok(stored) => stored,
            Err(_) => core.session_settings.clone(),
        };
        Ok(Settings {
            // From the vault, or from this run if there is none.
            scan_on_import: behaviour.scan_on_import,
            reveal_seconds: behaviour.reveal_seconds,
            auto_lock_minutes: behaviour.auto_lock_minutes,
            // From ZCFG, which does not need a vault — which is the whole
            // reason the owner allowed the file: a person may use Z Privacy for
            // years in copy-and-paste and never make a vault, and showing them
            // the first-run page every launch would be loyalty to a rule at the
            // user's expense.
            pack_id: file.default_privacy_pack,
            language: file.ui_language,
            first_run_done: file.first_run_completed,
            // Says only what it has always said: whether the settings that need
            // a vault will survive the app closing. The three above always do.
            session_only: kept_for_this_run,
        })
    })
}

/// Change them. They go to the vault if one is open, and to memory if not.
pub(crate) fn save_settings(settings: Settings) -> ApiResult<Settings> {
    let stored = StoredSettings {
        scan_on_import: settings.scan_on_import,
        // Bounded here rather than trusted: a reveal that lasted an hour, or
        // zero seconds, would both be a screen's bug becoming a policy.
        reveal_seconds: settings.reveal_seconds.clamp(3, 300),
        auto_lock_minutes: settings.auto_lock_minutes.min(24 * 60),
        pack_id: settings.pack_id,
        language: settings.language,
        first_run_done: settings.first_run_done,
    };
    // The three non-secret ones go to ZCFG. It refuses a value that does not
    // look like a setting, so a client's name cannot arrive through a field
    // that happens to be on the list.
    let file = crate::config::AppConfig {
        first_run_completed: settings.first_run_done,
        ui_language: stored.language.clone(),
        default_privacy_pack: stored.pack_id.clone(),
    };
    let written = with_core(|core| core.config.save(file))?;

    let sealed = with_core(|core| {
        core.vault
            .with_open_mut(|vault| {
                vault.settings = stored.clone();
                Ok(())
            })
            .is_ok()
    });
    // The memory copy is kept either way: it is what a later call reads if the
    // vault is locked in the meantime, and it is never a second *answer* —
    // `settings()` reads the vault first whenever the vault is open.
    with_core(|core| {
        core.session_settings = stored.clone();
        core.vault.set_idle_limit(stored.auto_lock_minutes);
    });
    Ok(Settings {
        scan_on_import: stored.scan_on_import,
        reveal_seconds: stored.reveal_seconds,
        auto_lock_minutes: stored.auto_lock_minutes,
        pack_id: written.default_privacy_pack,
        language: written.ui_language,
        first_run_done: written.first_run_completed,
        session_only: !sealed,
    })
}

/// How long a revealed value may stand, as the settings say.
pub(crate) fn reveal_ttl_ms() -> u32 {
    with_core(|core| {
        let seconds = match core.vault.with_open(|v| v.settings.reveal_seconds) {
            Ok(n) => n,
            Err(_) => core.session_settings.reveal_seconds,
        };
        seconds.saturating_mul(1000)
    })
}

/// Put a value into the vault so it is found by itself from now on.
///
/// This is what `Scope::Profile` and `Scope::Always` are **for**. It goes into
/// a catch-all identity — one per profile, and one for «everywhere» — because
/// the Workspace does not know whose value it is and stopping to ask would turn
/// one decision into two. The vault room can rename that identity, move it, or
/// take values out of it; what matters here is that the promise is kept at the
/// moment it is made, not at the moment the user gets round to tidying.
pub(crate) fn learn_value(profile_id: Option<String>, kind: Kind, text: String) -> ApiResult<()> {
    let text = text.trim().to_string();
    if text.is_empty() {
        return Ok(());
    }
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            // Already known? Then it is already found by itself, and saying it
            // twice would give one value two records.
            if vault
                .entities
                .iter()
                .filter(|e| e.profile_id == profile_id)
                .any(|e| e.values.iter().any(|v| v.matches(&text)))
            {
                return Ok(());
            }
            let label = match &profile_id {
                Some(_) => "Learned from this client's documents",
                None => "Learned from your documents",
            };
            let entity_id = match vault
                .entities
                .iter()
                .find(|e| e.profile_id == profile_id && e.label.expose() == label)
                .map(|e| e.id)
            {
                Some(id) => id,
                None => {
                    let id = vault.take_entity_id();
                    vault.entities.push(Entity {
                        id,
                        kind: EntityKind::Custom,
                        label: Secret::new(label),
                        profile_id: profile_id.clone(),
                        values: Vec::new(),
                    });
                    id
                }
            };
            let value_id = vault.take_value_id();
            if let Some(e) = vault.entity_mut(entity_id) {
                e.values.push(ValueRecord {
                    learned_at: crate::vault::model::now_seconds(),
                    id: value_id,
                    kind,
                    value: Secret::new(text),
                    aliases: Vec::new(),
                    policy: Policy::Always,
                });
            }
            Ok(())
        })
    })
}

/// The vault record whose value or spelling is exactly this text.
pub(crate) fn value_matching(text: &str) -> Option<crate::ops::KnownValue> {
    with_core(|core| {
        core.vault
            .with_open(|vault| {
                for e in &vault.entities {
                    for v in &e.values {
                        if v.matches(text) {
                            return Some(crate::ops::KnownValue {
                                entity: e.id,
                                value_id: v.id,
                                learned_at: v.learned_at,
                                aliases: v.aliases.iter().map(|a| a.expose().to_string()).collect(),
                            });
                        }
                    }
                }
                None
            })
            .ok()
            .flatten()
    })
}

/// What forgetting this value would take away.
///
/// Counted before anything happens, and counted the same way the act counts —
/// one function decides, so the sheet cannot promise one thing and the button
/// do another.
pub(crate) fn forget_plan(entity: u32, value_id: u32, everywhere: bool) -> ApiResult<ForgetPlan> {
    plan(entity, value_id, everywhere, false)
}

/// Forget it, and then check that nothing still recognises it.
pub(crate) fn forget_value(entity: u32, value_id: u32, everywhere: bool) -> ApiResult<ForgetPlan> {
    plan(entity, value_id, everywhere, true)
}

fn plan(entity: u32, value_id: u32, everywhere: bool, act: bool) -> ApiResult<ForgetPlan> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let target = vault
                .entity(entity)
                .and_then(|e| e.values.iter().find(|v| v.id == value_id))
                .ok_or(ApiError::UnknownToken)?;
            let what = target.value.expose().to_string();
            let spellings = target.spellings();
            let home_profile = vault.entity(entity).and_then(|e| e.profile_id.clone());

            // Every record this text is known by. «Everywhere» takes them all;
            // otherwise only the ones in the same profile — because forgetting
            // one client's fact must not reach into another's.
            let mut hits: Vec<(u32, u32)> = Vec::new();
            let mut aliases = 0u32;
            let mut profiles: Vec<String> = Vec::new();
            for e in &vault.entities {
                if !everywhere && e.profile_id != home_profile {
                    continue;
                }
                for v in &e.values {
                    if spellings.iter().any(|sp| v.matches(sp)) {
                        hits.push((e.id, v.id));
                        aliases += v.aliases.len() as u32;
                        if let Some(p) = &e.profile_id {
                            let name = vault
                                .profiles
                                .iter()
                                .find(|pr| &pr.id == p)
                                .map(|pr| pr.name.clone())
                                .unwrap_or_else(|| p.clone());
                            if !profiles.contains(&name) {
                                profiles.push(name);
                            }
                        } else if !profiles.contains(&"Everywhere".to_string()) {
                            profiles.push("Everywhere".to_string());
                        }
                    }
                }
            }

            // Identities that would be left holding nothing.
            let mut emptied = 0u32;
            for e in &vault.entities {
                let losing = e.values.iter().filter(|v| hits.contains(&(e.id, v.id))).count();
                if losing > 0 && losing == e.values.len() {
                    emptied += 1;
                }
            }

            if act {
                for (eid, vid) in &hits {
                    if let Some(e) = vault.entity_mut(*eid) {
                        e.values.retain(|v| v.id != *vid);
                    }
                }
                // An identity with nothing left is not kept as a shell: it would
                // sit in the list saying nothing and meaning nothing.
                vault.entities.retain(|e| !e.values.is_empty());
            }

            // What would still recognise it **afterwards** — the same meaning
            // whether this is a plan or the act itself.
            //
            // It used to mean «what matches now», which made the field say one
            // thing before the act and another after, and a screen reading it
            // before could only be wrong. One field, one meaning: permanent
            // knowledge that will recognise this value in future.
            let mut still: Vec<String> = Vec::new();
            for e in &vault.entities {
                for v in &e.values {
                    if hits.contains(&(e.id, v.id)) {
                        continue;
                    }
                    if spellings.iter().any(|sp| v.matches(sp)) && !still.contains(&e.handle()) {
                        still.push(e.handle());
                    }
                }
            }

            Ok(ForgetPlan {
                what,
                values: hits.len() as u32,
                aliases,
                identities: emptied,
                profiles,
                keeps: vec![
                    // The owner's own words, 28 September. Forgetting erases
                    // knowledge for the future; it does not reach into a
                    // document that is open, because doing so would show a
                    // value in the Safe column one press after the user asked
                    // the app to be more careful.
                    "Forgetting removes what Z Privacy learned for future use — it does not \
                     remove protection already applied in this document"
                        .to_string(),
                    "Documents you have already protected keep their tokens".to_string(),
                    "Answers you have already received are unchanged".to_string(),
                    if everywhere {
                        "Nothing else on this device knows this value".to_string()
                    } else {
                        "Other profiles that know it separately are left alone".to_string()
                    },
                ],
                still_known_by: still,
            })
        })
    })
}

// ---------------------------------------------------------------- profiles

pub(crate) fn create_profile(name: String) -> ApiResult<String> {
    let name = name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::ImportRefused {
            reason: "a profile needs a name you will recognise".to_string(),
        });
    }
    let id = with_core(|core| {
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
    })?;
    crate::session::bump_truth();
    Ok(id)
}

pub(crate) fn rename_profile(profile_id: String, name: String) -> ApiResult<()> {
    let name = name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::ImportRefused {
            reason: "a profile needs a name you will recognise".to_string(),
        });
    }
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let profile = vault
                .profiles
                .iter_mut()
                .find(|p| p.id == profile_id)
                .ok_or(ApiError::ImportRefused {
                    reason: format!("there is no profile «{profile_id}»"),
                })?;
            profile.name = name;
            Ok(())
        })
    })?;
    crate::session::bump_truth();
    Ok(())
}

/// `id\tname` per profile — one line the UI can split, without a new type.
pub(crate) fn profiles() -> ApiResult<Vec<ProfileRow>> {
    with_core(|core| {
        core.vault.with_open(|vault| {
            vault
                .profiles
                .iter()
                .map(|p| ProfileRow {
                    id: p.id.clone(),
                    name: p.name.clone(),
                })
                .collect::<Vec<ProfileRow>>()
        })
    })
}

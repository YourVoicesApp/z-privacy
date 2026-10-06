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
    ForgetPlan, RevealedValue, RevealState, Settings, VaultState, VaultUnlockOutcome, ValueRow,
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
        return Err(ApiError::InputRefused {
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

/// How many times the vault has been closed in this run, judged now.
///
/// Read **before** the session lock is taken wherever a session needs it: the
/// core's mutex is not re-entrant, and this takes it.
pub(crate) fn vault_locks_now() -> u64 {
    with_core(|core| core.vault.locks_so_far())
}

pub(crate) fn vault_lock() -> ApiResult<()> {
    with_core(|core| core.vault.lock());
    crate::session::bump_truth();
    Ok(())
}

pub(crate) fn vault_change_passphrase(old: String, replacement: String) -> ApiResult<()> {
    if replacement.chars().count() < 8 {
        return Err(ApiError::InputRefused {
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
        return Err(ApiError::InputRefused {
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
        return Err(ApiError::InputRefused {
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
        core.vault.with_reveal(|vault, revealed| {
            let e = vault.entity(entity).ok_or(ApiError::UnknownToken)?;
            let v = e
                .values
                .iter()
                .find(|v| v.id == value_id)
                .ok_or(ApiError::UnknownToken)?;
            // Recorded once the value is found, and inside the vault's own open
            // state: a fresh press gets a fresh TTL and replaces whatever was
            // revealed before — one at a time — and a press that found nothing
            // reveals nothing, with no rollback to forget.
            *revealed = Some(crate::session::Revealed {
                entity,
                value_id,
                until: std::time::Instant::now() + std::time::Duration::from_millis(u64::from(ttl_ms)),
            });
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

/// How much longer the current reveal lasts, and what it is showing.
///
/// This is the whole point of P1-4: the screen asks rather than counts. Its
/// own countdown is for the person to read, never permission to keep a value
/// on screen — when this says 0 the value is gone whatever a timer thinks.
pub(crate) fn reveal_state() -> ApiResult<RevealState> {
    Ok(with_core(|core| {
        // Asking is not using. `revealed_now` judges the idle clock on the way
        // in — a vault whose minutes have run out locks right here, and takes
        // the reveal with it — and it never renews that clock, so a screen
        // polling four times a second cannot hold the vault open.
        match core.vault.revealed_now() {
            Some(r) => RevealState {
                entity: Some(r.entity),
                value_id: Some(r.value_id),
                remaining_ms: r.remaining_ms(),
            },
            None => RevealState { entity: None, value_id: None, remaining_ms: 0 },
        }
    }))
}

/// Stop revealing now, before the time is up.
pub(crate) fn hide_value() -> ApiResult<()> {
    // Not a way in, and never an error: a locked vault has nothing to hide.
    with_core(|core| core.vault.end_reveal());
    Ok(())
}

/// Rename an identity.
pub(crate) fn rename_entity(entity_id: u32, label: String) -> ApiResult<()> {
    let label = label.trim().to_string();
    if label.is_empty() {
        return Err(ApiError::InputRefused {
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
                    return Err(ApiError::NotFound {
                        reason: no_such_profile(),
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
        // A kind the scanner can find and a person cannot choose is half a
        // kind: these five were added to the detection side in October and
        // never to this list, so a person could not hold one in the vault by
        // hand. 038-G added the last two and found the other three missing.
        (Kind::IdCard, "Identity card number"),
        (Kind::Birthdate, "Date of birth"),
        (Kind::Vehicle, "Vehicle plate"),
        (Kind::SocialInsuranceNo, "Social-insurance number"),
        (Kind::EmployeeNo, "Personnel number"),
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
            original_pane_percent: file.original_pane_percent,
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
        // Bounded here as the reveal is: a screen that sent 0 would hide a
        // column, and the one thing this product may not do is stop a person
        // comparing the two sides.
        original_pane_percent: settings.original_pane_percent.clamp(20, 80),
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
        original_pane_percent: written.original_pane_percent,
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
                                // Whether it belongs to one profile — not which
                                // one. That is all a button needs to name its
                                // own scope, and the name itself stays here.
                                in_profile: e.profile_id.is_some(),
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

pub(crate) fn forget_exception(id: u32) -> ApiResult<()> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let before = vault.exceptions.len();
            vault.exceptions.retain(|exception| exception.id != id);
            if vault.exceptions.len() == before {
                return Err(ApiError::UnknownToken);
            }
            Ok(())
        })
    })?;
    crate::session::bump_truth();
    Ok(())
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
                    // The clause «does not remove protection already applied in
                    // this document» used to live here too. It is now said once,
                    // in the sheet's closing sentence, in the owner's own words
                    // of 29 September — two widgets carrying one promise is
                    // noise, and a widget test caught the duplication.
                    "Documents you have already protected keep their tokens".to_string(),
                    "Answers you have already received are unchanged".to_string(),
                    if everywhere {
                        // Not «nothing on this device». F-02: an older valid
                        // vault copy may be restored and bring the value back,
                        // and this list may not quietly contradict a limit the
                        // invariants state out loud.
                        "No other identity in this vault knows this value".to_string()
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

/// «That profile is not in this vault» — and **never the id**.
///
/// A profile id is `p-<slug of the name>-<n>`, and the name is the client's
/// own. Echoing the id back in an error would put the very thing the vault
/// protects into a sentence on screen — the same rule that took the name out
/// of the Why card (the owner, 29 September). The id also tells a person
/// nothing: they never typed it.
fn no_such_profile() -> String {
    "that profile is not in this vault".to_string()
}

pub(crate) fn create_profile(name: String) -> ApiResult<String> {
    let name = name.trim().to_string();
    if name.is_empty() {
        return Err(ApiError::InputRefused {
            reason: "a profile needs a name you will recognise".to_string(),
        });
    }
    // Read BEFORE the lock, never inside it: `default_pack_id` takes the core
    // mutex, and calling it from within the closure below is exactly the
    // deadlock G19 exists to forbid. It cost this milestone one hung test run
    // to prove the rule is not theoretical.
    let starting_pack = crate::ops::default_pack_id();
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
                // A new profile starts with the pack the device already uses,
                // and the person adds languages from the profile screen. An
                // empty list would silently mean «no label rules at all».
                languages: vec![starting_pack.clone()],
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
        return Err(ApiError::InputRefused {
            reason: "a profile needs a name you will recognise".to_string(),
        });
    }
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let profile = vault
                .profiles
                .iter_mut()
                .find(|p| p.id == profile_id)
                .ok_or(ApiError::NotFound {
                    reason: no_such_profile(),
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
                    languages: p.languages.clone(),
                })
                .collect::<Vec<ProfileRow>>()
        })
    })
}

// ------------------------------------------------- rule sets and taught rules

/// Every rule set this build carries, each counting its own rows.
pub(crate) fn rule_sets() -> ApiResult<Vec<crate::api::RuleSetRow>> {
    Ok(crate::scanner::sets::all()
        .into_iter()
        .map(|s| crate::api::RuleSetRow {
            id: s.id.to_string(),
            label: s.label.to_string(),
            rules: s.rules.len() as u32,
        })
        .collect())
}

/// Switch a profile's rule sets. Unknown ids are refused by name rather than
/// stored and silently ignored — «active» has to mean «ran».
pub(crate) fn set_profile_languages(profile_id: String, languages: Vec<String>) -> ApiResult<ProfileRow> {
    let known = crate::scanner::sets::known_of(&languages);
    if let Some(missing) = languages.iter().find(|l| !known.iter().any(|k| k == *l)) {
        return Err(ApiError::NotFound {
            reason: format!("there is no rule set called «{missing}»"),
        });
    }
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let profile = vault
                .profiles
                .iter_mut()
                .find(|p| p.id == profile_id)
                .ok_or(ApiError::InvalidSession)?;
            profile.languages = languages.clone();
            Ok(())
        })
    })?;
    crate::session::bump_truth();
    profiles()?
        .into_iter()
        .find(|p| p.id == profile_id)
        .ok_or(ApiError::InvalidSession)
}

/// Teach a label rule: «after this word comes a value of this kind».
/// Teach a name: «Al-Hassan is a family name».
///
/// The user layer of the name dictionary. It does **not** protect the word —
/// that is what Add Person does, and it goes to the vault as a value. This
/// says what kind of word it is, so the rules that already know how names are
/// written can see it: «Mahmoud Al-Hassan» becomes a pair, «Herr Al-Hassan» a
/// name a salutation introduces.
pub(crate) fn teach_name(
    text: String,
    family: bool,
    profile_id: Option<String>,
    session: Option<crate::api::SessionId>,
) -> ApiResult<u32> {
    teach_name_into(text, family, profile_id, learning_language(session))
}

/// Which list a name learned right now belongs in.
///
/// The owner, 6 October, from a live run: working on a Swedish attachment with
/// the bar saying «Svenska (SV)», 75 surnames taught from the panel — and all
/// 75 under «German (DE)», because this answer used to be the **settings**
/// pack. The settings pack is the language this device starts with; it is not
/// the language of the document in front of the person, and after a switch the
/// two are different on purpose.
///
/// So the session answers whenever there is one. With no document open there
/// is no document language, and the device's own is the only answer there is.
fn learning_language(session: Option<crate::api::SessionId>) -> String {
    let of_the_session = session
        .and_then(|s| crate::session::with_session(s.id, |s| s.pack_id.clone()))
        .filter(|pack| !pack.is_empty());
    of_the_session.unwrap_or_else(|| with_core(|core| core.config.get().default_privacy_pack))
}

/// The same, into a list a person named.
pub(crate) fn teach_name_into(
    text: String,
    family: bool,
    profile_id: Option<String>,
    list: String,
) -> ApiResult<u32> {
    let list = clean_list_name(list)?;
    let text = crate::text::nfc(text.trim()).to_string();
    if text.is_empty() {
        return Err(ApiError::InputRefused {
            reason: "a name needs a word".to_string(),
        });
    }
    // One word. A name of two words is two decisions, and the rules match word
    // by word — teaching «Anna Weber» as one name would teach nothing at all.
    if text.split_whitespace().count() != 1 {
        return Err(ApiError::InputRefused {
            reason: "teach one word at a time: a first name and a surname are two names".to_string(),
        });
    }
    let id = with_core(|core| {
        core.vault.with_open_mut(|vault| {
            if let Some(owner) = profile_id.as_deref() {
                if !vault.profiles.iter().any(|p| p.id == owner) {
                    return Err(ApiError::NotFound {
                        reason: no_such_profile(),
                    });
                }
            }
            // Taught twice is taught once: the same word for the same reach
            // keeps the id it already has.
            if let Some(existing) = vault.taught_names.iter().find(|n| {
                n.text.eq_ignore_ascii_case(&text) && n.family == family && n.profile_id == profile_id
            }) {
                return Ok(existing.id);
            }
            // A list exists the moment a name is put in it.
            if !vault.lists.iter().any(|l| l.name == list) {
                vault.lists.push(crate::vault::model::UserList {
                    name: list.clone(),
                    enabled: true,
                });
            }
            let id = vault.next_taught_name;
            vault.next_taught_name = vault.next_taught_name.saturating_add(1);
            vault.taught_names.push(crate::vault::model::UserName {
                id,
                text: text.clone(),
                family,
                profile_id: profile_id.clone(),
                learned_at: crate::vault::model::now_seconds(),
                source: None,
                licence: None,
                list: list.clone(),
            });
            Ok(id)
        })
    })?;
    crate::session::bump_truth();
    Ok(id)
}

/// Unlearn a name. Knowledge only: an open document keeps every token it has.
pub(crate) fn forget_name(id: u32) -> ApiResult<()> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let before = vault.taught_names.len();
            vault.taught_names.retain(|n| n.id != id);
            if vault.taught_names.len() == before {
                return Err(ApiError::NotFound {
                    reason: "no taught name with that id".to_string(),
                });
            }
            Ok(())
        })
    })?;
    crate::session::bump_truth();
    Ok(())
}

/// Every name the person taught, newest first.
pub(crate) fn taught_names() -> ApiResult<Vec<crate::api::TaughtNameRow>> {
    with_core(|core| {
        core.vault.with_open(|vault| {
            let mut rows: Vec<crate::api::TaughtNameRow> = vault
                .taught_names
                .iter()
                .map(|n| crate::api::TaughtNameRow {
                    id: n.id,
                    text: n.text.clone(),
                    family: n.family,
                    profile_id: n.profile_id.clone(),
                    learned_at: n.learned_at,
                })
                .collect();
            rows.sort_by(|a, b| b.learned_at.cmp(&a.learned_at).then(b.id.cmp(&a.id)));
            rows
        })
    })
}

pub(crate) fn teach_label_rule(label: String, kind: Kind, profile_id: Option<String>) -> ApiResult<u32> {
    let label = crate::text::nfc(label.trim()).to_string();
    if label.is_empty() {
        return Err(ApiError::InputRefused {
            reason: "a rule needs a word to look for".to_string(),
        });
    }
    let id = with_core(|core| {
        core.vault.with_open_mut(|vault| {
            if let Some(owner) = profile_id.as_deref() {
                if !vault.profiles.iter().any(|p| p.id == owner) {
                    return Err(ApiError::NotFound {
                        reason: no_such_profile(),
                    });
                }
            }
            let id = vault.next_label_rule;
            vault.next_label_rule = vault.next_label_rule.saturating_add(1);
            vault.label_rules.push(crate::vault::model::UserLabelRule {
                id,
                label: label.clone(),
                kind,
                profile_id: profile_id.clone(),
                learned_at: crate::vault::model::now_seconds(),
            });
            Ok(id)
        })
    })?;
    crate::session::bump_truth();
    Ok(id)
}

/// Forget a taught rule. Forgetting knowledge, never a protection: a document
/// open now keeps every token it already has (§3 of the invariants).
pub(crate) fn forget_label_rule(id: u32) -> ApiResult<()> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let before = vault.label_rules.len();
            vault.label_rules.retain(|r| r.id != id);
            if vault.label_rules.len() == before {
                return Err(ApiError::NotFound {
                    reason: "there is no rule with that number".to_string(),
                });
            }
            Ok(())
        })
    })?;
    crate::session::bump_truth();
    Ok(())
}

/// Every rule the person taught, newest first, with its profile named.
pub(crate) fn label_rules() -> ApiResult<Vec<crate::api::LabelRuleRow>> {
    with_core(|core| {
        core.vault.with_open(|vault| {
            let mut rows: Vec<crate::api::LabelRuleRow> = vault
                .label_rules
                .iter()
                .map(|r| crate::api::LabelRuleRow {
                    id: r.id,
                    label: r.label.clone(),
                    kind: r.kind,
                    profile_id: r.profile_id.clone(),
                    profile_name: r.profile_id.as_ref().and_then(|id| {
                        vault.profiles.iter().find(|p| &p.id == id).map(|p| p.name.clone())
                    }),
                    learned_at: r.learned_at,
                })
                .collect();
            rows.sort_by_key(|r| std::cmp::Reverse(r.id));
            rows
        })
    })
}

// ------------------------------------------------- the names a person adds

/// The identity that holds the values a person typed in themselves.
///
/// Its own, and not the one `learn_value` fills from the review: forgetting a
/// name a person added must never reach into what the review learned, and the
/// two are told apart by the label they were created with.
const OWN_NAMES: &str = "Names you added";

fn own_names_entity(vault: &mut crate::vault::model::Vault, profile_id: Option<&str>) -> u32 {
    let owner = profile_id.map(str::to_string);
    if let Some(id) = vault
        .entities
        .iter()
        .find(|e| e.profile_id == owner && e.label.expose() == OWN_NAMES)
        .map(|e| e.id)
    {
        return id;
    }
    let id = vault.take_entity_id();
    vault.entities.push(Entity {
        id,
        kind: EntityKind::Custom,
        label: Secret::new(OWN_NAMES.to_string()),
        profile_id: owner,
        values: Vec::new(),
    });
    id
}

/// Put one value in that identity, or say it was already there.
fn put_own_value(
    vault: &mut crate::vault::model::Vault,
    profile_id: Option<&str>,
    kind: Kind,
    text: &str,
    policy: Policy,
) -> Option<u32> {
    let entity_id = own_names_entity(vault, profile_id);
    // Already known anywhere in this profile's vault? Then it is already found
    // by itself, and saying it twice would give one value two records.
    if vault
        .entities
        .iter()
        .filter(|e| e.profile_id.as_deref() == profile_id)
        .any(|e| e.values.iter().any(|v| v.matches(text)))
    {
        return None;
    }
    let id = vault.take_value_id();
    let target = vault.entities.iter_mut().find(|e| e.id == entity_id)?;
    target.values.push(ValueRecord {
        id,
        kind,
        value: Secret::new(text.to_string()),
        aliases: Vec::new(),
        policy,
        learned_at: crate::vault::model::now_seconds(),
    });
    Some(id)
}

/// Add a name a person typed, with what it is and how far it reaches.
///
/// The kind decides the store — a word for the dictionary, a value for the
/// vault — and `always` decides what Z does with it. A given or family name
/// taught as «always» is both: the dictionary learns the word so the rules can
/// read a full name around it, and the vault learns the value so the word is
/// protected on sight without waiting to be asked about.
pub(crate) fn add_user_name(
    text: String,
    kind: crate::api::UserNameKind,
    always: bool,
    profile_id: Option<String>,
    list: String,
) -> ApiResult<u32> {
    use crate::api::UserNameKind as K;
    let text = crate::text::nfc(text.trim()).to_string();
    if text.is_empty() {
        return Err(ApiError::InputRefused {
            reason: "a name needs a word".to_string(),
        });
    }
    match kind {
        K::Given | K::Family => {
            // `teach_name` holds the one-word rule, and holds it alone.
            let id = teach_name_into(text.clone(), matches!(kind, K::Family), profile_id.clone(), list.clone())?;
            if always {
                let owner = profile_id.clone();
                with_core(|core| {
                    core.vault.with_open_mut(|vault| {
                        put_own_value(vault, owner.as_deref(), Kind::Person, &text, Policy::Always);
                        Ok(())
                    })
                })?;
                crate::session::bump_truth();
            }
            Ok(id)
        }
        K::Person | K::Company => {
            let value_kind = if matches!(kind, K::Company) { Kind::Company } else { Kind::Person };
            let policy = if always { Policy::Always } else { Policy::Suggest };
            let owner = profile_id.clone();
            let id = with_core(|core| {
                core.vault.with_open_mut(|vault| {
                    Ok(put_own_value(vault, owner.as_deref(), value_kind, &text, policy))
                })
            })?;
            crate::session::bump_truth();
            // Already there is not an error: the person's wish is already true.
            Ok(id.unwrap_or(0))
        }
    }
}

/// Everything this device knows because a person said so, newest first.
pub(crate) fn user_names(profile_id: Option<String>) -> ApiResult<Vec<crate::api::UserNameRow>> {
    use crate::api::{UserNameKind as K, UserNameRow};
    with_core(|core| {
        core.vault.with_open(|vault| {
            let owner = profile_id.clone();
            let mut rows: Vec<UserNameRow> = Vec::new();
            // The words. A word that is also an «always» value of the same
            // spelling is one name to the person who typed it, so it is one row
            // here, and that row says «always».
            let own: Vec<&Entity> = vault
                .entities
                .iter()
                .filter(|e| e.profile_id == owner && e.label.expose() == OWN_NAMES)
                .collect();
            for name in vault.taught_names.iter().filter(|n| n.profile_id == owner) {
                let always = own
                    .iter()
                    .any(|e| e.values.iter().any(|v| v.policy == Policy::Always && v.matches(&name.text)));
                rows.push(UserNameRow {
                    id: name.id,
                    entity_id: None,
                    text: name.text.clone(),
                    kind: if name.family { K::Family } else { K::Given },
                    always,
                    profile_id: name.profile_id.clone(),
                    learned_at: name.learned_at,
                    list: name.list.clone(),
                });
            }
            // The values, except the ones that are a word's «always» twin.
            for entity in &own {
                for value in &entity.values {
                    let text = value.value.expose().to_string();
                    if vault
                        .taught_names
                        .iter()
                        .any(|n| n.profile_id == owner && n.text.eq_ignore_ascii_case(&text))
                    {
                        continue;
                    }
                    rows.push(UserNameRow {
                        id: value.id,
                        entity_id: Some(entity.id),
                        text,
                        kind: if value.kind == Kind::Company { K::Company } else { K::Person },
                        always: value.policy == Policy::Always,
                        profile_id: entity.profile_id.clone(),
                        learned_at: value.learned_at,
                        // A whole person or a company is a value in the vault,
                        // not a word in a dictionary, so it is in no list: the
                        // lists are the name dictionary's, and the vault room
                        // is where a value is managed.
                        list: crate::vault::model::DEFAULT_LIST.to_string(),
                    });
                }
            }
            rows.sort_by(|a, b| b.learned_at.cmp(&a.learned_at).then(a.text.cmp(&b.text)));
            rows
        })
    })
}

/// Take one back. A word goes from the dictionary, and its «always» twin with
/// it: one row on the screen is one name, and one press takes the whole of it.
pub(crate) fn forget_user_name(id: u32, entity_id: Option<u32>) -> ApiResult<()> {
    match entity_id {
        Some(entity) => delete_value(entity, id),
        None => {
            let text = with_core(|core| {
                core.vault
                    .with_open(|vault| vault.taught_names.iter().find(|n| n.id == id).map(|n| (n.text.clone(), n.profile_id.clone())))
            })?;
            forget_name(id)?;
            if let Some((text, owner)) = text {
                with_core(|core| {
                    core.vault.with_open_mut(|vault| {
                        for entity in vault
                            .entities
                            .iter_mut()
                            .filter(|e| e.profile_id == owner && e.label.expose() == OWN_NAMES)
                        {
                            entity.values.retain(|v| !v.matches(&text));
                        }
                        Ok(())
                    })
                })?;
                crate::session::bump_truth();
            }
            Ok(())
        }
    }
}

/// Read a list of names: a CSV whose first line names its columns.
///
/// `name` and `type` are required, `source` and `licence` are kept when they
/// are there. The whole file is read before anything is written, so a file
/// that is refused leaves the vault exactly as it was.
pub(crate) fn import_user_names(
    csv: String,
    profile_id: Option<String>,
    list: String,
) -> ApiResult<crate::api::NameImport> {
    use crate::api::{NameImport, UserNameKind as K};
    let mut lines = csv.lines().filter(|l| !l.trim().is_empty());
    let Some(header) = lines.next() else {
        return Err(ApiError::InputRefused {
            reason: "that file is empty".to_string(),
        });
    };
    let columns: Vec<String> = split_row(header).into_iter().map(|c| c.trim().to_lowercase()).collect();
    let at = |want: &str| columns.iter().position(|c| c == want);
    let (Some(name_at), Some(type_at)) = (at("name"), at("type")) else {
        return Err(ApiError::InputRefused {
            reason: "the first line must name the columns, and must include «name» and «type» — \
                     for example: name,type or name,type,source,licence"
                .to_string(),
        });
    };
    let source_at = at("source");
    let licence_at = at("licence");

    let mut plan: Vec<(String, K, Option<String>, Option<String>)> = Vec::new();
    let mut reasons: Vec<String> = Vec::new();
    for (number, line) in lines.enumerate() {
        let row = split_row(line);
        let at_row = |i: Option<usize>| i.and_then(|i| row.get(i)).map(|c| c.trim().to_string());
        let text = at_row(Some(name_at)).unwrap_or_default();
        let kind_word = at_row(Some(type_at)).unwrap_or_default().to_lowercase();
        let line_no = number + 2; // the header is line 1, and people count from 1
        if text.is_empty() {
            reasons.push(format!("line {line_no}: no name"));
            continue;
        }
        let kind = match kind_word.as_str() {
            "given" => K::Given,
            "family" => K::Family,
            "person" => K::Person,
            "company" => K::Company,
            "" => {
                reasons.push(format!("line {line_no}: «{text}» has no type"));
                continue;
            }
            other => {
                reasons.push(format!(
                    "line {line_no}: «{text}» is a «{other}», and the types are given, family, person and company"
                ));
                continue;
            }
        };
        if matches!(kind, K::Given | K::Family) && text.split_whitespace().count() != 1 {
            reasons.push(format!(
                "line {line_no}: «{text}» is two words — a given name and a family name are two rows"
            ));
            continue;
        }
        plan.push((text, kind, at_row(source_at), at_row(licence_at)));
    }

    let mut added = 0u32;
    let mut already = 0u32;
    for (text, kind, source, licence) in plan {
        let known = user_names(profile_id.clone())?
            .into_iter()
            .any(|row| row.text.eq_ignore_ascii_case(&text) && row.kind == kind);
        let _ = &list;
        if known {
            already = already.saturating_add(1);
            continue;
        }
        // Imported names are knowledge, not protection: a list is a dictionary,
        // and a dictionary suggests. «Always» stays a decision per name.
        match add_user_name(text.clone(), kind, false, profile_id.clone(), list.clone()) {
            Ok(id) => {
                added = added.saturating_add(1);
                if (source.is_some() || licence.is_some()) && matches!(kind, K::Given | K::Family) {
                    with_core(|core| {
                        core.vault.with_open_mut(|vault| {
                            if let Some(name) = vault.taught_names.iter_mut().find(|n| n.id == id) {
                                name.source = source.clone().filter(|s| !s.is_empty());
                                name.licence = licence.clone().filter(|s| !s.is_empty());
                            }
                            Ok(())
                        })
                    })?;
                }
            }
            Err(ApiError::InputRefused { reason }) => reasons.push(format!("«{text}»: {reason}")),
            Err(other) => return Err(other),
        }
    }
    crate::session::bump_truth();
    Ok(NameImport {
        added,
        already_known: already,
        refused: reasons.len() as u32,
        reasons,
    })
}

/// One CSV row into its cells. Commas and semicolons both separate — a list
/// exported by a German spreadsheet uses semicolons — and a quoted cell keeps
/// whatever is inside it.
fn split_row(line: &str) -> Vec<String> {
    let separator = if line.contains(';') && !line.contains(',') { ';' } else { ',' };
    let mut cells = Vec::new();
    let mut cell = String::new();
    let mut quoted = false;
    for c in line.chars() {
        match c {
            '"' => quoted = !quoted,
            x if x == separator && !quoted => cells.push(std::mem::take(&mut cell)),
            other => cell.push(other),
        }
    }
    cells.push(cell);
    cells
}

// ------------------------------------------------- the lists (041-I)

/// The lists a person keeps their names in, with the count and the switch.
///
/// The owner, 6 October: «we make it possible to create lists inside the vault,
/// for example Arabic, English, German and so on». A list is a name and a
/// switch: turning it off stops its names being used without forgetting one of
/// them, which is what makes a list worth having — a person can try a document
/// with and without a dictionary and see the difference.
pub(crate) fn user_lists() -> ApiResult<Vec<crate::api::UserListRow>> {
    with_core(|core| {
        core.vault.with_open(|vault| {
            let mut rows: Vec<crate::api::UserListRow> = Vec::new();
            let mut seen: Vec<String> = Vec::new();
            for list in &vault.lists {
                seen.push(list.name.clone());
                rows.push(crate::api::UserListRow {
                    name: list.name.clone(),
                    names: vault.taught_names.iter().filter(|n| n.list == list.name).count() as u32,
                    enabled: list.enabled,
                });
            }
            // A list a name claims without a row of its own is still a list.
            for name in &vault.taught_names {
                if !seen.iter().any(|s| s == &name.list) {
                    seen.push(name.list.clone());
                    rows.push(crate::api::UserListRow {
                        name: name.list.clone(),
                        names: vault.taught_names.iter().filter(|n| n.list == name.list).count() as u32,
                        enabled: true,
                    });
                }
            }
            // A list exists when its first name does, so an empty vault has
            // no lists at all — and the screen says «nothing yet» rather than
            // offering an empty box called something.
            rows.sort_by(|a, b| a.name.cmp(&b.name));
            rows
        })
    })
}

/// Turn a list off, or on. Off is **not** forgotten: every name is still here.
pub(crate) fn set_user_list_enabled(name: String, enabled: bool) -> ApiResult<()> {
    with_core(|core| {
        core.vault.with_open_mut(|vault| {
            match vault.lists.iter_mut().find(|l| l.name == name) {
                Some(list) => list.enabled = enabled,
                // A list that only exists because names claim it gets its row
                // the moment somebody switches it.
                None => vault.lists.push(crate::vault::model::UserList {
                    name: name.clone(),
                    enabled,
                }),
            }
            Ok(())
        })
    })?;
    crate::session::bump_truth();
    Ok(())
}

/// How many names forgetting this list would take with it.
///
/// Asked before it is done, the way `forget_plan` is: a list is a thing a
/// person built, and the app says what it costs before it takes it.
pub(crate) fn user_list_plan(name: String) -> ApiResult<u32> {
    with_core(|core| {
        core.vault
            .with_open(|vault| vault.taught_names.iter().filter(|n| n.list == name).count() as u32)
    })
}

/// Forget a list and the names in it — and nothing else.
pub(crate) fn forget_user_list(name: String) -> ApiResult<u32> {
    let gone: u32 = with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let before = vault.taught_names.len();
            vault.taught_names.retain(|n| n.list != name);
            vault.lists.retain(|l| l.name != name);
            Ok(before.saturating_sub(vault.taught_names.len()) as u32)
        })
    })?;
    crate::session::bump_truth();
    Ok(gone)
}

/// Move every name in one list into another language's list, in one act.
///
/// The repair the owner needed the day the defect was found: 75 Swedish
/// surnames sitting in the German list, and no appetite for teaching them
/// again one at a time. It asks once and moves all of them, and it is not a
/// rename — the destination may already have names of its own, and they stay.
///
/// What comes back is how many names moved. An emptied list is taken off the
/// screen rather than left as a box with a language's name and nothing in it,
/// because a list exists here the moment its first name does.
pub(crate) fn move_user_list(from: String, to: String) -> ApiResult<u32> {
    let from = clean_list_name(from)?;
    let to = clean_list_name(to)?;
    if from == to {
        return Err(ApiError::InputRefused {
            reason: "that list is already this language".to_string(),
        });
    }
    let moved: u32 = with_core(|core| {
        core.vault.with_open_mut(|vault| {
            let mut moved = 0u32;
            for name in vault.taught_names.iter_mut().filter(|n| n.list == from) {
                name.list = to.clone();
                moved = moved.saturating_add(1);
            }
            if moved > 0 && !vault.lists.iter().any(|l| l.name == to) {
                vault.lists.push(crate::vault::model::UserList {
                    name: to.clone(),
                    enabled: true,
                });
            }
            // What it left behind holds nothing now, and an empty list is not a
            // list — the same rule `user_lists` reads by.
            vault.lists.retain(|l| l.name != from);
            Ok(moved)
        })
    })?;
    crate::session::bump_truth();
    Ok(moved)
}

/// A list is a **language**, and only one this build has heard of.
///
/// Installed or planned: a person builds their Arabic list by hand long before
/// an Arabic pack exists, which is the whole of «the Arabic names are self
/// training». Anything else is refused, so a list cannot be invented by a
/// caller and the one-list-per-language rule holds by construction.
fn clean_list_name(name: String) -> ApiResult<String> {
    let name = crate::text::nfc(name.trim()).to_lowercase();
    let known = crate::scanner::packs::installed().into_iter().any(|p| p.id == name)
        || crate::scanner::packs::planned().into_iter().any(|p| p.id == name);
    if !known {
        return Err(ApiError::InputRefused {
            reason: format!(
                "«{name}» is not a language this build knows; a list is a language, one for each"
            ),
        });
    }
    Ok(name)
}

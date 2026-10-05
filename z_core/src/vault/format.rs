//! The vault's contents, as bytes.
//!
//! Hand-rolled and length-prefixed, with its own version number. Two reasons:
//! a serialisation dependency would widen what has to be audited for the sake of
//! writing a few numbers, and the codes below are a **persistence contract** — a
//! kind's number may never be reused, or an old vault would read a bank account
//! as a person's name.
//!
//! Adding a kind means adding a number at the end. Nothing else may move.

use std::collections::BTreeMap;
use crate::vault::model::UserName;

use crate::api::{ApiError, ApiResult, EntityKind, Kind, Policy};
use crate::secret::Secret;
use crate::vault::crypto::{self, Purpose, SecretKey};

use super::model::{Entity, Profile, ProviderLogin, StoredSettings, UserException, UserLabelRule, ValueRecord, Vault};

/// Bumped when the shape below changes. Read from the file, never assumed.
///
/// * 9 — where an imported name list came from, and under what licence.
/// * 8 — the names the person taught.
/// * 7 — a profile's active rule sets, and the label rules a person taught.
/// * 6 — user-taught exceptions are sealed with the rest of the vault.
/// * 5 — provider credentials are bound to a normalized destination.
/// * 4 — each value carries when it was taught (task 036).
/// * 3 — the settings, appended after the credentials (task 030).
/// * 1 — identities, values, profiles.
/// * 2 — provider credentials appended at the end (task 020). A version-1 vault
///   simply stops before that section and opens with no credentials, which is
///   why new sections go at the end and nothing already written ever moves.
///
/// Note that a **credential is sealed inside this body** with its own derived key
/// (task 021), so the bytes written here are ciphertext even though the body as a
/// whole is already encrypted. Whether they are sealed is decided by the *file's*
/// format version, not this one — see `crypto::SealedVault::credentials_are_sealed`.
pub(crate) const MODEL_VERSION: u16 = 9;

// ---------------------------------------------------------------- stable codes

fn kind_code(kind: Kind) -> u8 {
    match kind {
        Kind::Person => 1,
        Kind::Company => 2,
        Kind::Email => 3,
        Kind::Phone => 4,
        Kind::Iban => 5,
        Kind::TaxId => 6,
        Kind::CustomerNo => 7,
        Kind::Address => 8,
        Kind::Contract => 9,
        Kind::Project => 10,
        Kind::Client => 11,
        Kind::Custom => 12,
        // Added in task 012. New kinds take the next free number, always.
        Kind::Bic => 13,
        Kind::Account => 14,
        // Added 3 October, for the German letter: an identity card, a date of
        // birth, a vehicle plate.
        Kind::IdCard => 15,
        Kind::Birthdate => 16,
        Kind::Vehicle => 17,
    }
}

fn kind_of(code: u8) -> ApiResult<Kind> {
    Ok(match code {
        1 => Kind::Person,
        2 => Kind::Company,
        3 => Kind::Email,
        4 => Kind::Phone,
        5 => Kind::Iban,
        6 => Kind::TaxId,
        7 => Kind::CustomerNo,
        8 => Kind::Address,
        9 => Kind::Contract,
        10 => Kind::Project,
        11 => Kind::Client,
        12 => Kind::Custom,
        13 => Kind::Bic,
        14 => Kind::Account,
        15 => Kind::IdCard,
        16 => Kind::Birthdate,
        17 => Kind::Vehicle,
        other => {
            return Err(ApiError::PayloadRefused {
                reason: format!("this vault holds a kind ({other}) this build does not know"),
            })
        }
    })
}

fn entity_kind_code(kind: EntityKind) -> u8 {
    match kind {
        EntityKind::Client => 1,
        EntityKind::Person => 2,
        EntityKind::Company => 3,
        EntityKind::Project => 4,
        EntityKind::Custom => 5,
    }
}

fn entity_kind_of(code: u8) -> ApiResult<EntityKind> {
    Ok(match code {
        1 => EntityKind::Client,
        2 => EntityKind::Person,
        3 => EntityKind::Company,
        4 => EntityKind::Project,
        5 => EntityKind::Custom,
        other => {
            return Err(ApiError::PayloadRefused {
                reason: format!("this vault holds an identity kind ({other}) this build does not know"),
            })
        }
    })
}

fn policy_code(policy: Policy) -> u8 {
    match policy {
        Policy::Always => 1,
        Policy::Suggest => 2,
        Policy::Manual => 3,
    }
}

fn policy_of(code: u8) -> ApiResult<Policy> {
    Ok(match code {
        1 => Policy::Always,
        2 => Policy::Suggest,
        3 => Policy::Manual,
        other => {
            return Err(ApiError::PayloadRefused {
                reason: format!("this vault holds a policy ({other}) this build does not know"),
            })
        }
    })
}

// ---------------------------------------------------------------- writing

pub(crate) fn encode(vault: &Vault, master: &SecretKey) -> ApiResult<Vec<u8>> {
    let mut out = Vec::new();
    out.extend_from_slice(&MODEL_VERSION.to_be_bytes());
    out.extend_from_slice(&vault.next_entity.to_be_bytes());
    out.extend_from_slice(&vault.next_value.to_be_bytes());

    out.extend_from_slice(&(vault.profiles.len() as u32).to_be_bytes());
    for profile in &vault.profiles {
        put_str(&mut out, &profile.id);
        put_str(&mut out, &profile.name);
    }

    out.extend_from_slice(&(vault.entities.len() as u32).to_be_bytes());
    for entity in &vault.entities {
        out.extend_from_slice(&entity.id.to_be_bytes());
        out.push(entity_kind_code(entity.kind));
        put_str(&mut out, entity.label.expose());
        match &entity.profile_id {
            Some(id) => {
                out.push(1);
                put_str(&mut out, id);
            }
            None => out.push(0),
        }
        out.extend_from_slice(&(entity.values.len() as u32).to_be_bytes());
        for value in &entity.values {
            out.extend_from_slice(&value.id.to_be_bytes());
            out.push(kind_code(value.kind));
            out.push(policy_code(value.policy));
            put_str(&mut out, value.value.expose());
            out.extend_from_slice(&(value.aliases.len() as u32).to_be_bytes());
            for alias in &value.aliases {
                put_str(&mut out, alias.expose());
            }
            // Model 4. Inside the value's own record, because it belongs to the
            // value — a section at the end would have to be matched up again.
            out.extend_from_slice(&value.learned_at.to_be_bytes());
        }
    }

    // Model 2. Last, so that everything above stays byte-for-byte where it was.
    out.extend_from_slice(&(vault.provider_logins.len() as u32).to_be_bytes());
    for (id, login) in &vault.provider_logins {
        put_str(&mut out, id);
        // The credential gets its own key. If the decoded body ever escapes — a
        // stray dump, a bug, a core file — this is still ciphertext.
        let sealed = crypto::seal_for(master, Purpose::Provider, login.credential.expose().as_bytes())?;
        out.extend_from_slice(&(sealed.len() as u32).to_be_bytes());
        out.extend_from_slice(&sealed);
        put_str(&mut out, &login.base);
        put_str(&mut out, &login.model);
        put_str(&mut out, &login.bound_to);
    }

    // Model 3. At the end again, for the same reason as model 2.
    let st = &vault.settings;
    out.push(u8::from(st.scan_on_import));
    out.extend_from_slice(&st.reveal_seconds.to_be_bytes());
    out.extend_from_slice(&st.auto_lock_minutes.to_be_bytes());
    put_str(&mut out, &st.pack_id);
    put_str(&mut out, &st.language);
    out.push(u8::from(st.first_run_done));

    // Model 6. Also at the end: an exception is durable user knowledge, but old
    // vaults simply had none.
    out.extend_from_slice(&vault.next_exception.to_be_bytes());
    out.extend_from_slice(&(vault.exceptions.len() as u32).to_be_bytes());
    for exception in &vault.exceptions {
        out.extend_from_slice(&exception.id.to_be_bytes());
        out.push(kind_code(exception.kind));
        match &exception.profile_id {
            Some(id) => {
                out.push(1);
                put_str(&mut out, id);
            }
            None => out.push(0),
        }
        put_str(&mut out, exception.value.expose());
        out.extend_from_slice(&exception.learned_at.to_be_bytes());
    }

    // Model 7, appended for the same reason the block above was: a vault
    // written by model 6 has no languages and no taught rules, and reads
    // perfectly without these bytes.
    out.extend_from_slice(&(vault.profiles.len() as u32).to_be_bytes());
    for profile in &vault.profiles {
        out.extend_from_slice(&(profile.languages.len() as u32).to_be_bytes());
        for language in &profile.languages {
            put_str(&mut out, language);
        }
    }
    out.extend_from_slice(&vault.next_label_rule.to_be_bytes());
    out.extend_from_slice(&(vault.label_rules.len() as u32).to_be_bytes());
    for rule in &vault.label_rules {
        out.extend_from_slice(&rule.id.to_be_bytes());
        out.push(kind_code(rule.kind));
        match &rule.profile_id {
            Some(id) => {
                out.push(1);
                put_str(&mut out, id);
            }
            None => out.push(0),
        }
        put_str(&mut out, &rule.label);
        out.extend_from_slice(&rule.learned_at.to_be_bytes());
    }
    // Model 8 — the names the person taught. Appended, like every model before
    // it: an older build reads up to its own version and stops, and a vault
    // written by this build loses nothing when read by the next.
    out.extend_from_slice(&vault.next_taught_name.to_be_bytes());
    out.extend_from_slice(&(vault.taught_names.len() as u32).to_be_bytes());
    for name in &vault.taught_names {
        out.extend_from_slice(&name.id.to_be_bytes());
        out.push(u8::from(name.family));
        match &name.profile_id {
            Some(id) => {
                out.push(1);
                put_str(&mut out, id);
            }
            None => out.push(0),
        }
        put_str(&mut out, &name.text);
        out.extend_from_slice(&name.learned_at.to_be_bytes());
    }
    // Model 9 — the provenance of imported names, as its own section rather
    // than two more fields inside model 8's records. A section can be stopped
    // before; a wider record cannot, and an older build reading model 8's names
    // record by record would walk straight into the new bytes.
    let with_provenance: Vec<&crate::vault::model::UserName> = vault
        .taught_names
        .iter()
        .filter(|n| n.source.is_some() || n.licence.is_some())
        .collect();
    out.extend_from_slice(&(with_provenance.len() as u32).to_be_bytes());
    for name in with_provenance {
        out.extend_from_slice(&name.id.to_be_bytes());
        put_opt_str(&mut out, name.source.as_deref());
        put_opt_str(&mut out, name.licence.as_deref());
    }
    Ok(out)
}

fn put_opt_str(out: &mut Vec<u8>, text: Option<&str>) {
    match text {
        Some(t) => {
            out.push(1);
            put_str(out, t);
        }
        None => out.push(0),
    }
}

fn put_str(out: &mut Vec<u8>, text: &str) {
    let bytes = text.as_bytes();
    out.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
    out.extend_from_slice(bytes);
}

// ---------------------------------------------------------------- reading

pub(crate) fn decode(bytes: &[u8], master: &SecretKey, credentials_sealed: bool) -> ApiResult<Vault> {
    let mut r = Reader::new(bytes);
    let version = u16::from_be_bytes(r.array::<2>()?);
    if version > MODEL_VERSION {
        return Err(ApiError::PayloadRefused {
            reason: format!(
                "this vault's contents were written by a newer version (model {version}, this build knows {MODEL_VERSION})"
            ),
        });
    }
    let next_entity = u32::from_be_bytes(r.array::<4>()?);
    let next_value = u32::from_be_bytes(r.array::<4>()?);

    let profile_count = u32::from_be_bytes(r.array::<4>()?);
    let mut profiles = Vec::new();
    for _ in 0..profile_count {
        profiles.push(Profile {
            id: r.string()?,
            name: r.string()?,
            languages: Vec::new(),
        });
    }

    let entity_count = u32::from_be_bytes(r.array::<4>()?);
    let mut entities = Vec::new();
    for _ in 0..entity_count {
        let id = u32::from_be_bytes(r.array::<4>()?);
        let kind = entity_kind_of(r.byte()?)?;
        let label = Secret::new(r.string()?);
        let profile_id = match r.byte()? {
            0 => None,
            _ => Some(r.string()?),
        };
        let value_count = u32::from_be_bytes(r.array::<4>()?);
        let mut values = Vec::new();
        for _ in 0..value_count {
            let value_id = u32::from_be_bytes(r.array::<4>()?);
            let value_kind = kind_of(r.byte()?)?;
            let policy = policy_of(r.byte()?)?;
            let value = Secret::new(r.string()?);
            let alias_count = u32::from_be_bytes(r.array::<4>()?);
            let mut aliases = Vec::new();
            for _ in 0..alias_count {
                aliases.push(Secret::new(r.string()?));
            }
            let learned_at = if version >= 4 {
                u64::from_be_bytes(r.array::<8>()?)
            } else {
                // Taught before the vault kept dates. Said as «unknown», never
                // guessed as «today».
                0
            };
            values.push(ValueRecord {
                id: value_id,
                kind: value_kind,
                value,
                aliases,
                policy,
                learned_at,
            });
        }
        entities.push(Entity {
            id,
            kind,
            label,
            profile_id,
            values,
        });
    }
    // A model-1 vault has nothing here, and that is not an error.
    let mut provider_logins = BTreeMap::new();
    if version >= 2 {
        let count = u32::from_be_bytes(r.array::<4>()?);
        for _ in 0..count {
            let id = r.string()?;
            // A format-1 file wrote this in the clear; from format 2 it is sealed.
            let credential = if credentials_sealed {
                let blob = r.block()?;
                let plain = crypto::open_for(master, Purpose::Provider, &blob)?;
                Secret::new(String::from_utf8(plain.to_vec()).map_err(|_| ApiError::PayloadRefused {
                    reason: "a stored credential is not valid UTF-8".to_string(),
                })?)
            } else {
                Secret::new(r.string()?)
            };
            let base = r.string()?;
            let model = r.string()?;
            let bound_to = if version >= 5 {
                r.string()?
            } else {
                crate::providers::destination_of(&base)?
            };
            provider_logins.insert(
                id,
                ProviderLogin {
                    credential,
                    base,
                    bound_to,
                    model,
                },
            );
        }
    }

    // A vault written before model 3 simply gets today's defaults.
    let settings = if version >= 3 {
        StoredSettings {
            scan_on_import: r.byte()? != 0,
            reveal_seconds: u32::from_be_bytes(r.array::<4>()?),
            auto_lock_minutes: u32::from_be_bytes(r.array::<4>()?),
            pack_id: r.string()?,
            language: r.string()?,
            first_run_done: r.byte()? != 0,
        }
    } else {
        StoredSettings::default()
    };

    let (next_exception, exceptions) = if version >= 6 {
        let next_exception = u32::from_be_bytes(r.array::<4>()?);
        let count = u32::from_be_bytes(r.array::<4>()?);
        let mut exceptions = Vec::new();
        for _ in 0..count {
            let id = u32::from_be_bytes(r.array::<4>()?);
            let kind = kind_of(r.byte()?)?;
            let profile_id = match r.byte()? {
                0 => None,
                _ => Some(r.string()?),
            };
            let value = Secret::new(r.string()?);
            let learned_at = u64::from_be_bytes(r.array::<8>()?);
            exceptions.push(UserException {
                id,
                kind,
                value,
                profile_id,
                learned_at,
            });
        }
        (next_exception, exceptions)
    } else {
        (1, Vec::new())
    };

    // Model 7 — each profile's active rule sets, then the taught label rules.
    let (next_label_rule, label_rules) = if version >= 7 {
        let count = u32::from_be_bytes(r.array::<4>()?) as usize;
        for index in 0..count {
            let n = u32::from_be_bytes(r.array::<4>()?);
            let mut languages = Vec::new();
            for _ in 0..n {
                languages.push(r.string()?);
            }
            if let Some(profile) = profiles.get_mut(index) {
                profile.languages = languages;
            }
        }
        let next_label_rule = u32::from_be_bytes(r.array::<4>()?);
        let count = u32::from_be_bytes(r.array::<4>()?);
        let mut label_rules = Vec::new();
        for _ in 0..count {
            let id = u32::from_be_bytes(r.array::<4>()?);
            let kind = kind_of(r.byte()?)?;
            let profile_id = match r.byte()? {
                0 => None,
                _ => Some(r.string()?),
            };
            let label = r.string()?;
            let learned_at = u64::from_be_bytes(r.array::<8>()?);
            label_rules.push(UserLabelRule { id, label, kind, profile_id, learned_at });
        }
        (next_label_rule, label_rules)
    } else {
        (1, Vec::new())
    };

    // Model 8 — the taught names.
    let (next_taught_name, taught_names) = if version >= 8 {
        let next_taught_name = u32::from_be_bytes(r.array::<4>()?);
        let count = u32::from_be_bytes(r.array::<4>()?);
        let mut taught_names = Vec::new();
        for _ in 0..count {
            let id = u32::from_be_bytes(r.array::<4>()?);
            let family = r.byte()? != 0;
            let profile_id = match r.byte()? {
                0 => None,
                _ => Some(r.string()?),
            };
            let text = r.string()?;
            let learned_at = u64::from_be_bytes(r.array::<8>()?);
            taught_names.push(UserName {
                id,
                text,
                family,
                profile_id,
                learned_at,
                source: None,
                licence: None,
            });
        }
        (next_taught_name, taught_names)
    } else {
        (1, Vec::new())
    };

    // Model 9 — the provenance of the names that came from a list.
    let mut taught_names = taught_names;
    if version >= 9 {
        let count = u32::from_be_bytes(r.array::<4>()?);
        for _ in 0..count {
            let id = u32::from_be_bytes(r.array::<4>()?);
            let source = match r.byte()? {
                0 => None,
                _ => Some(r.string()?),
            };
            let licence = match r.byte()? {
                0 => None,
                _ => Some(r.string()?),
            };
            if let Some(name) = taught_names.iter_mut().find(|n| n.id == id) {
                name.source = source;
                name.licence = licence;
            }
        }
    }

    Ok(Vault {
        entities,
        profiles,
        next_entity,
        next_value,
        next_exception,
        exceptions,
        next_label_rule,
        label_rules,
        next_taught_name,
        taught_names,
        settings,
        provider_logins,
    })
}

struct Reader<'a> {
    bytes: &'a [u8],
    at: usize,
}

impl<'a> Reader<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, at: 0 }
    }

    fn take(&mut self, n: usize) -> ApiResult<&'a [u8]> {
        let end = self.at.checked_add(n).ok_or_else(truncated)?;
        let slice = self.bytes.get(self.at..end).ok_or_else(truncated)?;
        self.at = end;
        Ok(slice)
    }

    fn array<const N: usize>(&mut self) -> ApiResult<[u8; N]> {
        self.take(N)?.try_into().map_err(|_| truncated())
    }

    fn byte(&mut self) -> ApiResult<u8> {
        Ok(self.array::<1>()?[0])
    }

    fn block(&mut self) -> ApiResult<Vec<u8>> {
        let len = u32::from_be_bytes(self.array::<4>()?) as usize;
        Ok(self.take(len)?.to_vec())
    }

    fn string(&mut self) -> ApiResult<String> {
        let len = u32::from_be_bytes(self.array::<4>()?) as usize;
        let bytes = self.take(len)?;
        String::from_utf8(bytes.to_vec()).map_err(|_| ApiError::PayloadRefused {
            reason: "this vault holds text that is not valid UTF-8".to_string(),
        })
    }
}

fn truncated() -> ApiError {
    ApiError::PayloadRefused {
        reason: "the vault's contents are truncated".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use zeroize::Zeroizing;

    /// A fixed key, so a test's bytes are reproducible. Never a real master key.
    fn test_master() -> SecretKey {
        Zeroizing::new([7u8; 32])
    }

    fn enc(v: &Vault) -> Vec<u8> {
        encode(v, &test_master()).expect("encode")
    }

    fn dec(bytes: &[u8]) -> ApiResult<Vault> {
        decode(bytes, &test_master(), true)
    }

    /// A file as an older model wrote one, **built by hand**.
    ///
    /// It used to be made by taking today's bytes and chopping the tail, which
    /// worked only while every change was an append. Model 4 put eight bytes
    /// *inside* each value's record, and the chopping quietly stopped meaning
    /// anything — so the compatibility tests were testing arithmetic, not
    /// compatibility. An old file is written out here, field by field, as the
    /// build that made it would have written it.
    fn a_file_from_model(version: u16) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&version.to_be_bytes());
        out.extend_from_slice(&2u32.to_be_bytes()); // next_entity
        out.extend_from_slice(&2u32.to_be_bytes()); // next_value
        out.extend_from_slice(&0u32.to_be_bytes()); // no profiles
        out.extend_from_slice(&1u32.to_be_bytes()); // one entity
        out.extend_from_slice(&1u32.to_be_bytes()); // its id
        out.push(entity_kind_code(EntityKind::Client));
        put_str(&mut out, "Nordstern");
        out.push(0); // no profile
        out.extend_from_slice(&1u32.to_be_bytes()); // one value
        out.extend_from_slice(&1u32.to_be_bytes()); // its id
        out.push(kind_code(Kind::Company));
        out.push(policy_code(Policy::Always));
        put_str(&mut out, "Nordstern Consulting GmbH");
        out.extend_from_slice(&0u32.to_be_bytes()); // no aliases
        if version >= 4 {
            out.extend_from_slice(&0u64.to_be_bytes());
        }
        if version >= 2 {
            out.extend_from_slice(&0u32.to_be_bytes()); // no credentials
        }
        if version >= 3 {
            out.push(1);
            out.extend_from_slice(&20u32.to_be_bytes());
            out.extend_from_slice(&15u32.to_be_bytes());
            put_str(&mut out, "de");
            put_str(&mut out, "en");
            out.push(0);
        }
        if version >= 6 {
            out.extend_from_slice(&1u32.to_be_bytes()); // next exception
            out.extend_from_slice(&0u32.to_be_bytes()); // no exceptions
        }
        if version >= 7 {
            // One profile is written above, so one language list follows.
            out.extend_from_slice(&1u32.to_be_bytes()); // profiles with languages
            out.extend_from_slice(&1u32.to_be_bytes()); // one language
            put_str(&mut out, "de");
            out.extend_from_slice(&1u32.to_be_bytes()); // next label rule
            out.extend_from_slice(&0u32.to_be_bytes()); // no taught rules
        }
        if version >= 8 {
            out.extend_from_slice(&1u32.to_be_bytes()); // next taught name
            out.extend_from_slice(&0u32.to_be_bytes()); // none taught
        }
        if version >= 9 {
            out.extend_from_slice(&0u32.to_be_bytes()); // no name carries a provenance
        }
        out
    }

    fn sample() -> Vault {
        let mut v = Vault::new();
        v.profiles.push(Profile {
            id: "p-nordstern".to_string(),
            name: "Client Nordstern".to_string(),
            languages: vec!["de".to_string(), "en".to_string()],
        });
        v.entities.push(Entity {
            id: 17,
            kind: EntityKind::Client,
            label: Secret::new("Nordstern Consulting"),
            profile_id: Some("p-nordstern".to_string()),
            values: vec![
                ValueRecord {
                    learned_at: 1_759_000_000,
                    id: 1,
                    kind: Kind::Company,
                    value: Secret::new("Nordstern Consulting GmbH"),
                    aliases: vec![Secret::new("Nordstern"), Secret::new("NC GmbH")],
                    policy: Policy::Always,
                },
                ValueRecord {
                    learned_at: 1_759_000_000,
                    id: 2,
                    kind: Kind::Bic,
                    value: Secret::new("COBADEFFXXX"),
                    aliases: Vec::new(),
                    policy: Policy::Suggest,
                },
            ],
        });
        v.next_entity = 18;
        v.next_value = 3;
        v
    }

    #[test]
    fn everything_survives_the_round_trip() {
        let before = sample();
        let bytes = enc(&before);
        let after = dec(&bytes).expect("decode");

        assert_eq!(after.next_entity, 18);
        assert_eq!(after.next_value, 3);
        assert_eq!(after.profiles.len(), 1);
        assert_eq!(after.profiles[0].name, "Client Nordstern");

        let entity = after.entity(17).expect("the identity");
        assert_eq!(entity.handle(), "CLIENT #17");
        assert_eq!(entity.label.expose(), "Nordstern Consulting");
        assert_eq!(entity.values.len(), 2);
        assert_eq!(entity.values[0].value.expose(), "Nordstern Consulting GmbH");
        assert_eq!(entity.values[0].aliases.len(), 2);
        assert_eq!(entity.values[0].policy, Policy::Always);
        assert_eq!(entity.values[1].kind, Kind::Bic, "a BIC is still a BIC after a reload");
    }

    #[test]
    fn a_credential_survives_the_round_trip_and_an_older_vault_still_opens() {
        let mut before = sample();
        before.provider_logins.insert(
            "openai".to_string(),
            ProviderLogin {
                credential: Secret::new("sk-not-a-real-key"),
                base: "https://api.openai.com".to_string(),
                bound_to: "https://api.openai.com:443".to_string(),
                model: "gpt-4o-mini".to_string(),
            },
        );
        let bytes = enc(&before);
        let after = dec(&bytes).expect("decode");
        let login = after.provider_logins.get("openai").expect("the login");
        assert_eq!(login.credential.expose(), "sk-not-a-real-key");
        assert_eq!(login.base, "https://api.openai.com");
        assert_eq!(login.bound_to, "https://api.openai.com:443");
        assert_eq!(login.model, "gpt-4o-mini");

        // A model-1 file, as a model-1 build wrote one.
        let opened = dec(&a_file_from_model(1)).expect("a model-1 vault still opens");
        assert!(opened.provider_logins.is_empty(), "and simply has no credentials");
        assert_eq!(opened.entities.len(), 1, "everything older than model 2 is intact");
        assert_eq!(opened.entities[0].values.len(), 1);
    }

    #[test]
    fn a_credential_is_ciphertext_even_inside_the_decrypted_body() {
        // The point of the provider key (task 021). The body as a whole is already
        // encrypted on disk; this is about what a *decoded* body holds, because
        // that is what a stray dump or a bug would expose.
        const CREDENTIAL: &str = "sk-live-0123456789abcdef";
        let mut vault = sample();
        vault.provider_logins.insert(
            "openai".to_string(),
            ProviderLogin {
                credential: Secret::new(CREDENTIAL),
                base: "https://api.openai.com".to_string(),
                bound_to: "https://api.openai.com:443".to_string(),
                model: "gpt-4o-mini".to_string(),
            },
        );
        let body = enc(&vault);

        // Control string first: things that are meant to be readable *are*.
        let readable = String::from_utf8_lossy(&body);
        assert!(readable.contains("openai"), "the provider id is plain, so this search works");
        assert!(readable.contains("api.openai.com"), "the address is not a secret");
        // And the credential is not.
        assert!(
            !readable.contains(CREDENTIAL),
            "the credential is readable inside the decrypted body"
        );
        assert!(
            !body.windows(CREDENTIAL.len()).any(|w| w == CREDENTIAL.as_bytes()),
            "the credential's bytes are in the decrypted body"
        );

        // And it comes back intact for the one thing allowed to read it.
        let back = dec(&body).expect("decode");
        assert_eq!(back.provider_logins["openai"].credential.expose(), CREDENTIAL);
    }

    #[test]
    fn the_settings_survive_and_an_older_vault_takes_the_defaults() {
        let mut before = sample();
        before.settings.auto_lock_minutes = 3;
        before.settings.language = "de".to_string();
        before.settings.first_run_done = true;
        before.settings.scan_on_import = false;
        let after = dec(&enc(&before)).expect("decode");
        assert_eq!(after.settings, before.settings);

        // Model 9 — a list's provenance survives the round trip, and a name
        // without one costs nothing. Nothing shows these yet; they are kept so
        // that a name can still say where it came from after the file it came
        // from is gone.
        let mut with_lists = sample();
        with_lists.taught_names.push(crate::vault::model::UserName {
            id: 1,
            text: "Lindqvist".to_string(),
            family: true,
            profile_id: None,
            learned_at: 0,
            source: Some("SCB 2024".to_string()),
            licence: Some("CC0".to_string()),
        });
        with_lists.taught_names.push(crate::vault::model::UserName {
            id: 2,
            text: "Anneli".to_string(),
            family: false,
            profile_id: None,
            learned_at: 0,
            source: None,
            licence: None,
        });
        let read = dec(&enc(&with_lists)).expect("decode");
        assert_eq!(read.taught_names.len(), 2);
        assert_eq!(read.taught_names[0].source.as_deref(), Some("SCB 2024"));
        assert_eq!(read.taught_names[0].licence.as_deref(), Some("CC0"));
        assert_eq!(read.taught_names[1].source, None, "a name without a list grew one");

        // A model-2 file, as a model-2 build wrote one.
        let opened = dec(&a_file_from_model(2)).expect("a model-2 vault still opens");
        assert_eq!(opened.settings, StoredSettings::default(), "and takes today's defaults");
        assert_eq!(opened.entities.len(), 1, "with nothing else lost");

        // And every model this build claims to read, read in one place — so
        // «an old vault still opens» is a statement about all of them.
        for version in 1..=MODEL_VERSION {
            let v = dec(&a_file_from_model(version))
                .unwrap_or_else(|e| panic!("model {version} did not open: {e}"));
            assert_eq!(v.entities.len(), 1, "model {version} lost its identity");
            assert_eq!(
                v.entities[0].values[0].value.expose(),
                "Nordstern Consulting GmbH",
                "model {version} lost its value"
            );
            // The date is known only from model 4 — and «unknown» is 0, never
            // today's date guessed in.
            assert_eq!(v.entities[0].values[0].learned_at, 0);
        }
    }

    #[test]
    fn a_kinds_number_is_a_promise() {
        // If one of these ever changes, an old vault reads one thing as another.
        // Adding a kind means adding a number, never moving one.
        assert_eq!(kind_code(Kind::Person), 1);
        assert_eq!(kind_code(Kind::Iban), 5);
        assert_eq!(kind_code(Kind::Custom), 12);
        assert_eq!(kind_code(Kind::Bic), 13);
        assert_eq!(kind_code(Kind::Account), 14);
        for code in 1..=14u8 {
            assert_eq!(kind_code(kind_of(code).expect("known")), code, "code {code}");
        }
        assert!(kind_of(200).is_err(), "an unknown kind is refused, not guessed");
    }

    #[test]
    fn truncated_or_future_contents_are_refused() {
        let bytes = enc(&sample());
        assert!(matches!(
            dec(&bytes[..bytes.len() / 2]),
            Err(ApiError::PayloadRefused { .. })
        ));
        let mut future = bytes.clone();
        future[0] = 0xFF;
        match dec(&future) {
            Err(ApiError::PayloadRefused { reason }) => assert!(reason.contains("newer version")),
            other => panic!("expected a refusal, got {other:?}"),
        }
    }
}

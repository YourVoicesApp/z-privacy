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

use crate::api::{ApiError, ApiResult, EntityKind, Kind, Policy};
use crate::secret::Secret;

use super::model::{Entity, Profile, ProviderLogin, ValueRecord, Vault};

/// Bumped when the shape below changes. Read from the file, never assumed.
///
/// * 1 — identities, values, profiles.
/// * 2 — provider credentials appended at the end (task 020). A version-1 vault
///   simply stops before that section and opens with no credentials, which is
///   why new sections go at the end and nothing already written ever moves.
pub(crate) const MODEL_VERSION: u16 = 2;

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

pub(crate) fn encode(vault: &Vault) -> Vec<u8> {
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
        }
    }

    // Model 2. Last, so that everything above stays byte-for-byte where it was.
    out.extend_from_slice(&(vault.provider_logins.len() as u32).to_be_bytes());
    for (id, login) in &vault.provider_logins {
        put_str(&mut out, id);
        put_str(&mut out, login.credential.expose());
        put_str(&mut out, &login.base);
        put_str(&mut out, &login.model);
    }
    out
}

fn put_str(out: &mut Vec<u8>, text: &str) {
    let bytes = text.as_bytes();
    out.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
    out.extend_from_slice(bytes);
}

// ---------------------------------------------------------------- reading

pub(crate) fn decode(bytes: &[u8]) -> ApiResult<Vault> {
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
            values.push(ValueRecord {
                id: value_id,
                kind: value_kind,
                value,
                aliases,
                policy,
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
            provider_logins.insert(
                id,
                ProviderLogin {
                    credential: Secret::new(r.string()?),
                    base: r.string()?,
                    model: r.string()?,
                },
            );
        }
    }

    Ok(Vault {
        entities,
        profiles,
        next_entity,
        next_value,
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

    fn sample() -> Vault {
        let mut v = Vault::new();
        v.profiles.push(Profile {
            id: "p-nordstern".to_string(),
            name: "Client Nordstern".to_string(),
        });
        v.entities.push(Entity {
            id: 17,
            kind: EntityKind::Client,
            label: Secret::new("Nordstern Consulting"),
            profile_id: Some("p-nordstern".to_string()),
            values: vec![
                ValueRecord {
                    id: 1,
                    kind: Kind::Company,
                    value: Secret::new("Nordstern Consulting GmbH"),
                    aliases: vec![Secret::new("Nordstern"), Secret::new("NC GmbH")],
                    policy: Policy::Always,
                },
                ValueRecord {
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
        let bytes = encode(&before);
        let after = decode(&bytes).expect("decode");

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
                model: "gpt-4o-mini".to_string(),
            },
        );
        let bytes = encode(&before);
        let after = decode(&bytes).expect("decode");
        let login = after.provider_logins.get("openai").expect("the login");
        assert_eq!(login.credential.expose(), "sk-not-a-real-key");
        assert_eq!(login.base, "https://api.openai.com");
        assert_eq!(login.model, "gpt-4o-mini");

        // What a model-1 file looks like: the same bytes without the last section.
        let plain = encode(&sample());
        let mut old_file = plain.clone();
        old_file.truncate(plain.len() - 4); // drop the (empty) credential count
        old_file[0..2].copy_from_slice(&1u16.to_be_bytes());
        let opened = decode(&old_file).expect("a model-1 vault still opens");
        assert!(opened.provider_logins.is_empty(), "and simply has no credentials");
        assert_eq!(opened.entities.len(), 1, "everything older than model 2 is intact");
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
        let bytes = encode(&sample());
        assert!(matches!(
            decode(&bytes[..bytes.len() / 2]),
            Err(ApiError::PayloadRefused { .. })
        ));
        let mut future = bytes.clone();
        future[0] = 0xFF;
        match decode(&future) {
            Err(ApiError::PayloadRefused { reason }) => assert!(reason.contains("newer version")),
            other => panic!("expected a refusal, got {other:?}"),
        }
    }
}

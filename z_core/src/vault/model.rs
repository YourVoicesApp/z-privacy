//! What the vault knows: identities, and the values inside them.
//!
//! The two levels are the owner's distinction, and the whole point of M4:
//!
//! * an **entity** is an identity — `CLIENT #17`, how a person thinks;
//! * a **value** is what the scanner matches — the company name, the contact, the
//!   IBAN — each with its own spellings, its own policy and its own token.
//!
//! After this, the app stops knowing only *the shape of a secret* and starts
//! knowing *whose secret it is*.

use std::collections::BTreeMap;

use crate::api::{EntityKind, Kind, Policy};
use crate::secret::Secret;
use crate::text::nfc;

/// Seconds since 1970, for «added on». The clock is not a secret and not a
/// document: reading it breaks no invariant.
pub(crate) fn now_seconds() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

/// One spelling-aware value.
#[derive(Debug, Clone)]
pub(crate) struct ValueRecord {
    pub id: u32,
    pub kind: Kind,
    pub value: Secret,
    /// Other ways the same thing is written. All resolve to one token.
    pub aliases: Vec<Secret>,
    pub policy: Policy,
    /// When this was taught, in seconds since 1970. 0 for a value written
    /// before the vault kept the date (model 4, task 036).
    ///
    /// «Added 27 Sep 2026» is part of the answer to «why is this protected?»,
    /// and a person cannot judge a rule they cannot date.
    pub learned_at: u64,
}

impl ValueRecord {
    /// Every spelling, primary first.
    pub(crate) fn spellings(&self) -> Vec<String> {
        let mut out = vec![self.value.expose().to_string()];
        out.extend(self.aliases.iter().map(|a| a.expose().to_string()));
        out
    }

    pub(crate) fn matches(&self, text: &str) -> bool {
        let wanted = nfc(text);
        self.spellings().iter().any(|s| nfc(s) == wanted)
    }
}

/// One identity.
#[derive(Debug, Clone)]
pub(crate) struct Entity {
    pub id: u32,
    pub kind: EntityKind,
    pub label: Secret,
    pub profile_id: Option<String>,
    pub values: Vec<ValueRecord>,
}

impl Entity {
    /// «CLIENT #17» — the handle the UI shows and the logs may carry, because it
    /// names nobody.
    pub(crate) fn handle(&self) -> String {
        let word = match self.kind {
            EntityKind::Client => "CLIENT",
            EntityKind::Person => "PERSON",
            EntityKind::Company => "COMPANY",
            EntityKind::Project => "PROJECT",
            EntityKind::Custom => "CUSTOM",
        };
        format!("{word} #{:02}", self.id)
    }

    pub(crate) fn policy_summary(&self) -> String {
        let count = |p: Policy| self.values.iter().filter(|v| v.policy == p).count();
        let mut parts = Vec::new();
        for (policy, word) in [
            (Policy::Always, "always"),
            (Policy::Suggest, "suggest"),
            (Policy::Manual, "manual only"),
        ] {
            let n = count(policy);
            if n > 0 {
                parts.push(format!("{n} {word}"));
            }
        }
        parts.join(" · ")
    }
}

/// One client's dictionary.
#[derive(Debug, Clone)]
pub(crate) struct Profile {
    pub id: String,
    pub name: String,
}

/// Everything the vault holds, once it is open.
#[derive(Debug, Clone, Default)]
pub(crate) struct Vault {
    pub entities: Vec<Entity>,
    pub profiles: Vec<Profile>,
    pub next_entity: u32,
    pub next_value: u32,
    /// What the app has been told to do by itself. In the vault because the
    /// vault is the only file we write (G15), and because a setting that
    /// survives a restart has to live somewhere that does. Written in task 030.
    pub settings: StoredSettings,
    /// How to reach each AI provider, by provider id. It lives here because the
    /// vault is the one thing this program encrypts before writing, and because
    /// nothing outside the core can read it back: `providers()` reports only
    /// whether a row has a credential. Written in task 020.
    pub provider_logins: BTreeMap<String, ProviderLogin>,
}

/// The settings, as they are kept. `session_only` is not here: whether these
/// came from the vault or from memory is not a property of the settings, it is
/// a property of where they were found.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct StoredSettings {
    pub scan_on_import: bool,
    pub reveal_seconds: u32,
    pub auto_lock_minutes: u32,
    pub pack_id: String,
    pub language: String,
    pub first_run_done: bool,
}

impl Default for StoredSettings {
    fn default() -> Self {
        Self {
            // Nobody has to press anything to be protected.
            scan_on_import: true,
            reveal_seconds: 20,
            // Fifteen minutes of not being used. Long enough not to annoy,
            // short enough that a walk to the kitchen is covered.
            auto_lock_minutes: 15,
            pack_id: "de".to_string(),
            language: "en".to_string(),
            first_run_done: false,
        }
    }
}

/// What it takes to reach one provider: a credential, an address, a model.
///
/// The three travel together and have one lifetime — a credential sealed in the
/// vault keeps the address it was given for, and a credential that exists only
/// for this run takes its address with it when the app closes.
#[derive(Debug, Clone)]
pub(crate) struct ProviderLogin {
    pub credential: Secret,
    pub base: String,
    pub model: String,
}

/// One thing the vault can recognise, handed to the scanner.
///
/// The scanner never sees the vault itself: it is given a flat list for the active
/// profile only, which is how «opening the vault does not make every name Auto»
/// becomes true by construction.
#[derive(Debug, Clone)]
pub(crate) struct VaultHint {
    pub text: String,
    pub kind: Kind,
    pub policy: Policy,
    /// Kept for M7: the review list will open the identity from a finding.
    #[allow(dead_code)]
    pub entity_id: u32,
    pub entity_handle: String,
}

impl Vault {
    pub(crate) fn new() -> Self {
        Self {
            entities: Vec::new(),
            profiles: Vec::new(),
            next_entity: 1,
            next_value: 1,
            settings: StoredSettings::default(),
            provider_logins: BTreeMap::new(),
        }
    }

    pub(crate) fn entity(&self, id: u32) -> Option<&Entity> {
        self.entities.iter().find(|e| e.id == id)
    }

    pub(crate) fn entity_mut(&mut self, id: u32) -> Option<&mut Entity> {
        self.entities.iter_mut().find(|e| e.id == id)
    }

    pub(crate) fn take_entity_id(&mut self) -> u32 {
        let id = self.next_entity;
        self.next_entity = self.next_entity.saturating_add(1);
        id
    }

    pub(crate) fn take_value_id(&mut self) -> u32 {
        let id = self.next_value;
        self.next_value = self.next_value.saturating_add(1);
        id
    }

    /// What the vault can recognise **in this profile**.
    ///
    /// An entity with no profile belongs everywhere; one with a profile is loaded
    /// only while that profile is active. `Manual` values are left out entirely:
    /// they exist so their aliases and token stay stable, not to be found.
    pub(crate) fn hints_for(&self, active_profile: Option<&str>) -> Vec<VaultHint> {
        let mut out = Vec::new();
        for entity in &self.entities {
            let in_scope = match (&entity.profile_id, active_profile) {
                (None, _) => true,
                (Some(mine), Some(active)) => mine == active,
                (Some(_), None) => false,
            };
            if !in_scope {
                continue;
            }
            for value in &entity.values {
                if value.policy == Policy::Manual {
                    continue;
                }
                for spelling in value.spellings() {
                    if spelling.is_empty() {
                        continue;
                    }
                    out.push(VaultHint {
                        text: spelling,
                        kind: value.kind,
                        policy: value.policy,
                        entity_id: entity.id,
                        entity_handle: entity.handle(),
                    });
                }
            }
        }
        // Longest first, so «Nordstern Consulting GmbH» wins over «Nordstern».
        out.sort_by_key(|h| std::cmp::Reverse(h.text.len()));
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn client_with(label: &str, profile: Option<&str>, values: Vec<(Kind, &str, Policy)>) -> Entity {
        Entity {
            id: 17,
            kind: EntityKind::Client,
            label: Secret::new(label),
            profile_id: profile.map(str::to_string),
            values: values
                .into_iter()
                .enumerate()
                .map(|(i, (kind, text, policy))| ValueRecord {
                    learned_at: now_seconds(),
                    id: i as u32 + 1,
                    kind,
                    value: Secret::new(text),
                    aliases: Vec::new(),
                    policy,
                })
                .collect(),
        }
    }

    #[test]
    fn an_identity_names_itself_without_naming_anyone() {
        let e = client_with("Nordstern Consulting", None, vec![]);
        assert_eq!(e.handle(), "CLIENT #17");
        assert!(!format!("{e:?}").contains("Nordstern"), "G11: {e:?}");
    }

    #[test]
    fn only_the_active_profile_is_loaded() {
        let mut v = Vault::new();
        v.entities.push(client_with(
            "Nordstern",
            Some("p-nordstern"),
            vec![(Kind::Company, "Nordstern Consulting GmbH", Policy::Always)],
        ));
        let mut other = client_with("Andere", Some("p-other"), vec![(Kind::Company, "Andere AG", Policy::Always)]);
        other.id = 18;
        v.entities.push(other);

        let hints = v.hints_for(Some("p-nordstern"));
        assert_eq!(hints.len(), 1);
        assert_eq!(hints[0].text, "Nordstern Consulting GmbH");

        // No profile active: only the entities that belong everywhere.
        assert!(v.hints_for(None).is_empty());
    }

    #[test]
    fn manual_values_are_not_hints_at_all() {
        let mut v = Vault::new();
        v.entities.push(client_with(
            "Eigene",
            None,
            vec![
                (Kind::Company, "Faruk AB", Policy::Manual),
                (Kind::Iban, "DE89 3704 0044 0532 0130 00", Policy::Always),
            ],
        ));
        let hints = v.hints_for(None);
        assert_eq!(hints.len(), 1, "a Manual value is kept, not hunted: {hints:?}");
        assert_eq!(hints[0].kind, Kind::Iban);
    }

    #[test]
    fn every_spelling_becomes_a_hint_longest_first() {
        let mut v = Vault::new();
        let mut e = client_with("Nordstern", None, vec![(Kind::Company, "Nordstern Consulting GmbH", Policy::Always)]);
        if let Some(value) = e.values.first_mut() {
            value.aliases.push(Secret::new("Nordstern"));
            value.aliases.push(Secret::new("NC GmbH"));
        }
        v.entities.push(e);

        let hints = v.hints_for(None);
        assert_eq!(hints.len(), 3);
        assert_eq!(hints[0].text, "Nordstern Consulting GmbH", "longest first");
        assert!(hints.iter().all(|h| h.entity_handle == "CLIENT #17"));
    }

    #[test]
    fn the_summary_reads_like_the_vault_list() {
        let e = client_with(
            "Nordstern",
            None,
            vec![
                (Kind::Company, "a", Policy::Always),
                (Kind::Person, "b", Policy::Always),
                (Kind::Email, "c", Policy::Suggest),
            ],
        );
        assert_eq!(e.policy_summary(), "2 always · 1 suggest");
    }
}

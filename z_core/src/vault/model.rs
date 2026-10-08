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
    /// Which imported list this value arrived in, if it arrived in one.
    ///
    /// `None` is a value a person taught by hand or accepted in a document, and
    /// no switch can silence it: they asked for this one by itself. `Some(list)`
    /// came from a file, and the list's switch governs it exactly as it governs
    /// a taught word — which is the whole of 054's third guard. Model 11.
    pub list: Option<String>,
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
    /// The rule sets switched on for this client's documents. A firm that works
    /// in two languages runs both **in the same scan**, which is why this is a
    /// list and not a setting. Empty means «whatever the session's pack says» —
    /// the shape a vault written before 29 September has.
    pub languages: Vec<String>,
}

/// A durable «do not protect this as that» decision.
///
/// Unlike a session dismissal, this is knowledge and therefore lives in the
/// encrypted vault. It is deliberately value/kind exact: phase A teaches values
/// and exceptions, not patterns.
#[derive(Debug, Clone)]
pub(crate) struct UserException {
    pub id: u32,
    pub kind: Kind,
    pub value: Secret,
    pub profile_id: Option<String>,
    pub learned_at: u64,
}

impl UserException {
    pub(crate) fn matches(&self, kind: Kind, text: &str) -> bool {
        self.kind == kind && nfc(self.value.expose()) == nfc(text)
    }
}

/// A label rule a person taught: «after Mandantenkennung comes a customer
/// number». Knowledge, so it lives in the encrypted vault beside the values and
/// the exceptions — and it is visible, explainable, editable and forgettable
/// like everything else the app learns (the owner's ninth question).
#[derive(Debug, Clone)]
pub(crate) struct UserLabelRule {
    pub id: u32,
    /// The word as the person typed it, kept for the screen and the `Why?`.
    pub label: String,
    pub kind: Kind,
    /// `None` is everywhere; `Some(profile)` is this client only.
    pub profile_id: Option<String>,
    pub learned_at: u64,
}

/// A name the person taught: «Al-Hassan is a family name».
///
/// Knowledge, not a value — the same kind of thing as a taught label rule and
/// stored the same way. It does not protect the word; it tells the rules that
/// the word is a name, so that «Mahmoud Al-Hassan» becomes a pair they can see
/// and «Herr Al-Hassan» becomes a name a salutation introduces.
///
/// In the vault, encrypted, because the surname of a person's client is as much
/// theirs as the client's address.
/// The list a name goes into when nothing says otherwise: the pack the
/// settings hold. A list **is a language** — the owner, 6 October: «the
/// language list is what establishes the word lists inside the vault: if you
/// choose Arabic an Arabic list is made, and one list per language». So there
/// is no list called «My names»: there is `de`, `sv`, `ar`, and a person builds
/// their Arabic list by hand long before an Arabic pack exists.
pub(crate) const DEFAULT_LIST: &str = "de";

/// **One of the owner's sessions, as the vault keeps it** — 064, model 12.
///
/// The word in code is `Conversation` and the word a person reads is
/// «session», because `session::Session` already means one document's bench
/// and the API's `session: u32` is that bench's id. Two nouns were wearing one
/// word; task 066 pays the rename, and until it does this is the fence between
/// them. Precedent for a code name a person never sees: `p-<slug>-<n>`.
///
/// What is here is only what must survive: the number, the handle, the key, and
/// when it began. **The conversation itself is not here** — it is a sealed file
/// of its own, because `vault.zv` is re-sealed whole on every change
/// (`format::encode` → `reseal_body`) and a conversation inside this body would
/// rewrite every byte a person owns on every save, without a ceiling. That is
/// 062 §A, and guard 5 measures it in bytes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Conversation {
    /// **The identity, and it never changes.** Numbers are not reused: a
    /// deleted session's number is spent for ever, so a stale reference to it
    /// cannot land on somebody else's conversation.
    pub number: u32,
    /// **The handle, and it may be changed at any time.** The owner's rule is
    /// the first three words of the *question* — not of the document, whose
    /// name is already shown beside the row, because two sessions on one
    /// document are told apart only by what was asked (062 §0).
    pub name: String,
    /// **The 32 bytes everything in this session hangs off**, sealed inside
    /// this body under `Purpose::Session` exactly as a provider credential has
    /// been since task 021 — so a leak of the *decoded* body is still not a
    /// leak of a conversation. Without that sealing 062 §A's sentence was
    /// simply false, which is why the fourth purpose exists.
    ///
    /// Deleting a session destroys these 32 bytes, and that is what makes the
    /// owner's warning a **fact** rather than a caution: the key dies, and
    /// nothing derives anything. No token in any document protected in this
    /// session can be resolved again by anyone, including us.
    pub key: [u8; 32],
    /// When it began — **seconds** since 1970, the same unit and the same
    /// helper as `UserName::learned_at`, because two units for one kind of fact
    /// is two places that can disagree. `now_seconds()` is a few lines above.
    pub began_at: u64,
    /// **Which document this session belongs to** — 062 §C, and the reason a
    /// restored session can refuse instead of guessing.
    ///
    /// The document's own text, hashed, never its path or its name. `None` is a
    /// session born before any document was on the bench, which the birth-at-
    /// Copy rule makes impossible today and which is still written as `Option`
    /// rather than as a lie: the first build that can open a session with no
    /// document must not find a zeroed hash and believe it.
    pub document: Option<[u8; 32]>,
}

/// A list of names a person keeps, and whether it is in use.
///
/// It exists as a row of its own so that an empty list can exist: «New list»
/// has to be pressable before there is anything to put in it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct UserList {
    pub name: String,
    pub enabled: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct UserName {
    pub id: u32,
    /// The word as the person taught it.
    pub text: String,
    /// A surname, or a given name.
    pub family: bool,
    /// `None` is everywhere; `Some(profile)` is this client only.
    pub profile_id: Option<String>,
    pub learned_at: u64,
    /// Where an imported list came from, and under what licence — the two
    /// optional columns of the CSV, kept with the name they arrived with.
    ///
    /// Nothing shows them yet. They are kept because a list's provenance is the
    /// owner's to answer for, and a name that outlives the file it came from
    /// without its provenance is a name nobody can account for. Model 9.
    pub source: Option<String>,
    pub licence: Option<String>,
    /// Which list this name belongs to — **a language id**: `de`, `sv`, `ar`.
    ///
    /// The owner, 6 October: «the language list is what establishes the word
    /// lists inside the vault: if you choose Arabic an Arabic list is made,
    /// then if you move to another language and so on — but one list per
    /// language». So a list is not a thing a person names; it is the language
    /// they were working in when they taught the name, and a list exists the
    /// moment its first name does.
    ///
    /// The switch is per language: turn Arabic off and its names stop being
    /// used, without forgetting one of them. Model 10; a name taught before
    /// there were lists belongs to the pack the settings held when the vault
    /// was last written.
    pub list: String,
}

impl UserLabelRule {
    /// The engine's row for this taught rule.
    pub(crate) fn as_rule(&self) -> crate::scanner::rules::LabelRule {
        crate::scanner::rules::LabelRule::taught(
            format!("u{}", self.id),
            self.label.clone(),
            self.kind,
        )
    }
}

/// Everything the vault holds, once it is open.
#[derive(Debug, Clone, Default)]
pub(crate) struct Vault {
    pub entities: Vec<Entity>,
    pub profiles: Vec<Profile>,
    pub next_entity: u32,
    pub next_value: u32,
    pub next_exception: u32,
    pub exceptions: Vec<UserException>,
    pub next_label_rule: u32,
    /// Label rules the person taught. Same shape of scoping as an exception:
    /// everywhere, or one profile.
    pub label_rules: Vec<UserLabelRule>,
    pub next_taught_name: u32,
    /// Names the person taught — the user layer of the name dictionary, kept
    /// apart from the lists this build ships with and from the candidates
    /// nobody has decided about yet. Written in Phase 2.
    pub taught_names: Vec<UserName>,
    /// The lists those names are kept in, with the switch on each. Model 10.
    pub lists: Vec<UserList>,
    /// What the app has been told to do by itself. In the vault because the
    /// vault is the only file we write (G15), and because a setting that
    /// survives a restart has to live somewhere that does. Written in task 030.
    pub settings: StoredSettings,
    /// How to reach each AI provider, by provider id. It lives here because the
    /// vault is the one thing this program encrypts before writing, and because
    /// nothing outside the core can read it back: `providers()` reports only
    /// whether a row has a credential. Written in task 020.
    pub provider_logins: BTreeMap<String, ProviderLogin>,
    /// The owner's sessions — number, handle, key, when. Model 12. The
    /// conversations themselves are their own sealed files; see
    /// [`Conversation`].
    pub conversations: Vec<Conversation>,
    /// The next session number, and it only ever goes up. A deleted number is
    /// never handed out again: see [`Conversation::number`].
    pub next_conversation: u32,
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
    pub bound_to: String,
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
            next_exception: 1,
            next_label_rule: 1,
            label_rules: Vec::new(),
            next_taught_name: 1,
            taught_names: Vec::new(),
            lists: Vec::new(),
            exceptions: Vec::new(),
            settings: StoredSettings::default(),
            provider_logins: BTreeMap::new(),
            conversations: Vec::new(),
            // 1, not 0, for the same reason a revision starts at 1: zero must
            // never be mistakable for a session that exists.
            next_conversation: 1,
        }
    }

    /// The next session number. It only goes up, and a deleted one is spent.
    pub(crate) fn take_conversation_number(&mut self) -> u32 {
        let number = self.next_conversation;
        self.next_conversation = self.next_conversation.saturating_add(1);
        number
    }

    pub(crate) fn conversation(&self, number: u32) -> Option<&Conversation> {
        self.conversations.iter().find(|c| c.number == number)
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

    pub(crate) fn take_exception_id(&mut self) -> u32 {
        let id = self.next_exception;
        self.next_exception = self.next_exception.saturating_add(1);
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
                // **The switch, for values, where it has to be.** A list that
                // is off is not a list that was forgotten. Before 054 only
                // taught words asked this question, so the switch on the only
                // list a client book ever makes changed nothing that left.
                if let Some(list) = &value.list {
                    if !self.list_is_on(list) {
                        continue;
                    }
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

    /// Durable exceptions effective in this profile.
    pub(crate) fn exceptions_for(&self, active_profile: Option<&str>) -> Vec<UserException> {
        self.exceptions
            .iter()
            .filter(|ex| match (&ex.profile_id, active_profile) {
                (None, _) => true,
                (Some(mine), Some(active)) => mine == active,
                (Some(_), None) => false,
            })
            .cloned()
            .collect()
    }

    /// The taught label rules that apply: everywhere, plus this profile's own.
    ///
    /// Same rule as a hint — a rule taught for one client does not follow the
    /// user into another client's document.
    /// The names taught everywhere, plus the ones taught for this client.
    pub(crate) fn taught_names_for(&self, active_profile: Option<&str>) -> Vec<UserName> {
        self.taught_names
            .iter()
            .filter(|n| match n.profile_id.as_deref() {
                None => true,
                Some(owner) => Some(owner) == active_profile,
            })
            // **The switch, where it has to be.** A list that is off is not a
            // list that was forgotten: its names are all still here, and the
            // scanner is simply not told about them. This is the one place that
            // decides it, so no caller can forget to ask.
            .filter(|n| self.list_is_on(&n.list))
            .cloned()
            .collect()
    }

    /// Is this list in use? A list nobody has written a row for is on: a name
    /// cannot be silenced by a list that does not exist.
    pub(crate) fn list_is_on(&self, list: &str) -> bool {
        self.lists
            .iter()
            .find(|l| l.name == list)
            .map(|l| l.enabled)
            .unwrap_or(true)
    }

    pub(crate) fn label_rules_for(&self, active_profile: Option<&str>) -> Vec<UserLabelRule> {
        self.label_rules
            .iter()
            .filter(|r| match (&r.profile_id, active_profile) {
                (None, _) => true,
                (Some(owner), Some(active)) => owner == active,
                (Some(_), None) => false,
            })
            .cloned()
            .collect()
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
                    list: None,
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

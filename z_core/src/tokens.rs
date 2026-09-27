//! The token engine.
//!
//! A token stands in for one value. Three things about its shape are decisions,
//! not accidents:
//!
//! * **Its kind is in the name** — `__Z_8F3A_PERSON_91C7__`. The model has to
//!   know it is answering about a person and not a bank account, or the answer
//!   is useless. The kind leaks on purpose; the value never does.
//! * **Every session has its own namespace** (`8F3A` here), drawn at random when
//!   the session opens. The same name in two conversations gets two different
//!   tokens, so nobody can line up one chat against another.
//! * **One value, one token** — every spelling of the same thing (an alias)
//!   resolves to the same token, or the model would read them as two people.

use std::collections::BTreeMap;

use crate::api::{Kind, Scope, Segment, Source, TokenRow};

/// splitmix64. Small, deterministic when seeded, good enough for identifiers
/// that must be unpredictable but are not secrets.
///
/// M4 brings a real CSPRNG along with the vault's crypto; the seed here comes
/// from the OS through `RandomState`, which is how std seeds its hashers.
#[derive(Debug)]
pub(crate) struct Prng(u64);

impl Prng {
    pub(crate) fn from_os_entropy() -> Self {
        use std::collections::hash_map::RandomState;
        use std::hash::{BuildHasher, Hasher};
        let mut h = RandomState::new().build_hasher();
        h.write_u64(0x5A5A_5A5A_5A5A_5A5A);
        Self(h.finish() | 1)
    }

    #[cfg(test)]
    pub(crate) fn from_seed(seed: u64) -> Self {
        Self(seed | 1)
    }

    fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    /// Four uppercase hex digits — short enough to read aloud, 65 536 apart.
    fn hex4(&mut self) -> String {
        format!("{:04X}", (self.next_u64() >> 17) as u16)
    }
}

/// Mints the tokens of one session.
#[derive(Debug)]
pub(crate) struct TokenMint {
    namespace: String,
    rng: Prng,
}

impl TokenMint {
    pub(crate) fn new() -> Self {
        let mut rng = Prng::from_os_entropy();
        let namespace = rng.hex4();
        Self { namespace, rng }
    }

    #[cfg(test)]
    pub(crate) fn seeded(seed: u64) -> Self {
        let mut rng = Prng::from_seed(seed);
        let namespace = rng.hex4();
        Self { namespace, rng }
    }

    /// Only the tests read this; the namespace's job is to sit inside the tokens.
    #[cfg(test)]
    pub(crate) fn namespace(&self) -> &str {
        &self.namespace
    }

    /// A fresh token of this kind, not already in `taken`.
    pub(crate) fn mint(&mut self, kind: Kind, taken: &TokenStore) -> String {
        for _ in 0..64 {
            let token = format!("__Z_{}_{}_{}__", self.namespace, kind_word(kind), self.rng.hex4());
            if !taken.contains(&token) {
                return token;
            }
        }
        // 64 collisions in a row is not a thing, but the contract says no panic:
        // fall back to something that cannot collide.
        format!("__Z_{}_{}_{:X}__", self.namespace, kind_word(kind), taken.len())
    }
}

/// The word that carries the kind into the token, and into the model's answer.
pub(crate) fn kind_word(kind: Kind) -> &'static str {
    match kind {
        Kind::Person => "PERSON",
        Kind::Company => "COMPANY",
        Kind::Email => "EMAIL",
        Kind::Phone => "PHONE",
        Kind::Iban => "IBAN",
        Kind::TaxId => "TAXID",
        Kind::CustomerNo => "CUSTNO",
        Kind::Address => "ADDR",
        Kind::Contract => "CONTRACT",
        Kind::Project => "PROJECT",
        Kind::Client => "CLIENT",
        Kind::Custom => "CUSTOM",
    }
}

/// What one token stands for. The value in here is the thing that must never
/// appear in a payload.
#[derive(Debug, Clone)]
pub(crate) struct TokenEntry {
    pub value: String,
    /// Other spellings of the same thing, all resolving to this one token.
    pub aliases: Vec<String>,
    pub kind: Kind,
    pub scope: Scope,
    pub source: Source,
    pub source_detail: String,
}

impl TokenEntry {
    /// Does `text` name this entry, in any of its spellings?
    pub(crate) fn matches(&self, text: &str) -> bool {
        self.value == text || self.aliases.iter().any(|a| a == text)
    }
}

/// The tokens of one session.
#[derive(Debug, Default)]
pub(crate) struct TokenStore {
    entries: BTreeMap<String, TokenEntry>,
}

impl TokenStore {
    pub(crate) fn contains(&self, token: &str) -> bool {
        self.entries.contains_key(token)
    }

    pub(crate) fn len(&self) -> usize {
        self.entries.len()
    }

    pub(crate) fn insert(&mut self, token: String, entry: TokenEntry) {
        self.entries.insert(token, entry);
    }

    pub(crate) fn get(&self, token: &str) -> Option<&TokenEntry> {
        self.entries.get(token)
    }

    /// The token already standing for this text, under any spelling.
    pub(crate) fn token_for(&self, text: &str) -> Option<&str> {
        self.entries
            .iter()
            .find(|(_, e)| e.matches(text))
            .map(|(t, _)| t.as_str())
    }

    /// Teach a token another spelling. `false` if there is no such token.
    pub(crate) fn add_alias(&mut self, token: &str, alias: String) -> bool {
        match self.entries.get_mut(token) {
            Some(entry) => {
                if entry.value != alias && !entry.aliases.contains(&alias) {
                    entry.aliases.push(alias);
                }
                true
            }
            None => false,
        }
    }

    pub(crate) fn remove(&mut self, token: &str) {
        self.entries.remove(token);
    }

    /// The rows of the tokens panel: never a value, only what it is and why.
    pub(crate) fn rows(&self, only: &[String]) -> Vec<TokenRow> {
        self.entries
            .iter()
            .filter(|(t, _)| only.iter().any(|u| u == *t))
            .map(|(token, e)| TokenRow {
                token: token.clone(),
                kind: e.kind,
                scope: e.scope,
                source: e.source,
                source_detail: e.source_detail.clone(),
            })
            .collect()
    }

    /// Every value and alias held here — what a payload must never contain.
    /// Used by the no-leak tests, and by nothing else.
    pub(crate) fn all_secrets(&self) -> Vec<String> {
        let mut out = Vec::new();
        for e in self.entries.values() {
            out.push(e.value.clone());
            out.extend(e.aliases.iter().cloned());
        }
        out
    }
}

/// Put the values back into an answer — and nothing else.
///
/// Only tokens that this session actually minted are replaced. Anything that
/// merely looks like a token (`__Z_FAKE_123__`, a model inventing one) is left
/// exactly as it arrived: the core does not guess, and does not pretend to know
/// what it does not know. That is invariant G9.
pub(crate) fn restore(raw: &str, store: &TokenStore) -> Vec<Segment> {
    const OPEN: &str = "__Z_";
    const CLOSE: &str = "__";

    let mut out: Vec<Segment> = Vec::new();
    let mut plain = String::new();
    let mut cursor = 0usize;

    while let Some(rest) = raw.get(cursor..) {
        let Some(at) = rest.find(OPEN) else {
            plain.push_str(rest);
            break;
        };
        let start = cursor + at;
        // Everything before the candidate is ordinary text.
        if let Some(before) = raw.get(cursor..start) {
            plain.push_str(before);
        }
        let after_open = start + OPEN.len();
        let end = match raw.get(after_open..).and_then(|tail| tail.find(CLOSE)) {
            Some(found) => after_open + found + CLOSE.len(),
            None => {
                // No closing mark: the rest is text.
                if let Some(tail) = raw.get(start..) {
                    plain.push_str(tail);
                }
                break;
            }
        };
        let candidate = raw.get(start..end).unwrap_or_default();
        match store.get(candidate) {
            Some(entry) => {
                if !plain.is_empty() {
                    out.push(Segment { text: std::mem::take(&mut plain), restored: false });
                }
                out.push(Segment { text: entry.value.clone(), restored: true });
            }
            // Not ours: it stays word for word.
            None => plain.push_str(candidate),
        }
        cursor = end;
    }
    if !plain.is_empty() {
        out.push(Segment { text: plain, restored: false });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_token_carries_its_kind_and_its_session() {
        let mut mint = TokenMint::seeded(42);
        let store = TokenStore::default();
        let token = mint.mint(Kind::Person, &store);
        assert!(token.starts_with("__Z_"), "{token}");
        assert!(token.ends_with("__"), "{token}");
        assert!(token.contains("_PERSON_"), "{token}");
        assert!(token.contains(mint.namespace()), "{token}");
        // Shape: __Z_ NS _ KIND _ RAND __
        let middle = token.trim_start_matches("__Z_").trim_end_matches("__");
        let parts: Vec<&str> = middle.split('_').collect();
        assert_eq!(parts.len(), 3, "{token}");
        assert_eq!(parts[0].len(), 4);
        assert_eq!(parts[2].len(), 4);
    }

    #[test]
    fn session_namespace_differs_between_sessions() {
        // Two mints from different entropy must not share a namespace, or the
        // same name could be lined up across conversations.
        let a = TokenMint::seeded(1);
        let b = TokenMint::seeded(2);
        assert_ne!(a.namespace(), b.namespace());

        let live_a = TokenMint::new();
        let live_b = TokenMint::new();
        assert_ne!(
            live_a.namespace(),
            live_b.namespace(),
            "two live sessions drew the same namespace"
        );
    }

    #[test]
    fn two_tokens_of_the_same_kind_differ() {
        let mut mint = TokenMint::seeded(7);
        let mut store = TokenStore::default();
        let first = mint.mint(Kind::Company, &store);
        store.insert(first.clone(), entry("Nordstern GmbH", Kind::Company));
        let second = mint.mint(Kind::Company, &store);
        assert_ne!(first, second);
    }

    #[test]
    fn every_spelling_finds_the_same_token() {
        let mut store = TokenStore::default();
        let token = "__Z_ABCD_PERSON_1234__".to_string();
        let mut e = entry("Thomas Müller", Kind::Person);
        e.aliases = vec!["Herr Müller".into(), "T. Müller".into()];
        store.insert(token.clone(), e);

        for spelling in ["Thomas Müller", "Herr Müller", "T. Müller"] {
            assert_eq!(store.token_for(spelling), Some(token.as_str()), "{spelling}");
        }
        assert_eq!(store.token_for("Anna Weber"), None);
        assert!(store.add_alias(&token, "Thomas M.".into()));
        assert_eq!(store.token_for("Thomas M."), Some(token.as_str()));
        assert!(!store.add_alias("__Z_NOPE_PERSON_0000__", "x".into()));
    }

    fn entry(value: &str, kind: Kind) -> TokenEntry {
        TokenEntry {
            value: value.to_string(),
            aliases: Vec::new(),
            kind,
            scope: Scope::Conversation,
            source: Source::Hand,
            source_detail: String::new(),
        }
    }
}

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

use crate::api::{Kind, Piece, Scope, Segment, Source, TokenRow};
use crate::secret::Secret;
use crate::text::nfc;

/// Four uppercase hex digits drawn from the operating system.
///
/// The owner's ruling: since linking tokens across sessions is the threat, there
/// is no interim weaker stage. This asks the OS every time (`getrandom`), so the
/// semantics never change later. Tokens are identifiers, not secrets — but they
/// are unpredictable from the first commit.
///
/// If the OS refuses (it does not, on any platform we ship), the fallback mixes
/// the clock rather than panicking: the contract says no panic, ever.
fn os_hex4() -> String {
    let mut bytes = [0u8; 2];
    match getrandom::fill(&mut bytes) {
        Ok(()) => {}
        Err(_) => {
            let nanos = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.subsec_nanos())
                .unwrap_or(0);
            bytes = [(nanos >> 8) as u8, nanos as u8];
        }
    }
    format!("{:02X}{:02X}", bytes[0], bytes[1])
}

/// **Where a document's token names come from** — 046/U item 2.
///
/// A key derived from the vault's master key, and the namespace this document
/// already hashes to. Both are computed once, when the vault is open, and the
/// key never leaves this crate.
///
/// The derivation is keyed BLAKE2b, the same primitive and the same reasoning
/// as the key ladder it hangs off: already in the tree, so domain separation
/// costs nothing new to audit.
pub(crate) struct Naming {
    key: crate::vault::crypto::SecretKey,
    namespace: String,
}

impl std::fmt::Debug for Naming {
    /// No key and no namespace in a log line. The namespace is not a secret,
    /// but it is the handle by which two requests about one document can be
    /// lined up, and a debug print is the one place nobody audits.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("Naming { .. }")
    }
}

impl Naming {
    /// **Keyed on the client and the document's own bytes.**
    ///
    /// The client, so two clients never share a name for the same spelling —
    /// a property the per-session prefix was only providing by accident, and
    /// losing it would be a real leak between them.
    ///
    /// The document's **own content**, never its path or its name: a file moved
    /// or renamed still restores, and an edited file is a different document
    /// and honestly gets different names. 046/U item 1 is what makes that safe
    /// — the old answer says «2 tokens this conversation does not know»
    /// instead of passing them through as prose.
    ///
    /// **The content is the text the reader extracted, not the file's bytes**,
    /// and that is the better of the two: a PDF re-saved with new metadata, or
    /// the same letter exported twice by Word, reads as the same document and
    /// keeps its names. It is also the only one available — the core holds the
    /// text and drops the bytes, which is why nothing here can be told from a
    /// file it has not read.
    ///
    /// **The cost, named here because a later round will meet it:** when one
    /// conversation spans two documents — «compare this payroll with last
    /// month's» — the same person carries two different names and a model
    /// cannot tell they are one. Nothing is lost today, because
    /// `Context.workspace` goes out empty. Whoever builds multi-document
    /// context has to decide this deliberately rather than discover it.
    pub(crate) fn derive(
        master: &crate::vault::crypto::SecretKey,
        profile: Option<&str>,
        document: &str,
    ) -> crate::api::ApiResult<Self> {
        let key = crate::vault::crypto::derive(master, crate::vault::crypto::Purpose::TokenName)?;
        // Length-prefixed, so «ab» + «c» and «a» + «bc» are different inputs.
        // A separator alone would let a profile id ending in the separator
        // forge another profile's names.
        let mut message: Vec<u8> = Vec::new();
        let profile = profile.unwrap_or("");
        message.extend_from_slice(&(profile.len() as u64).to_be_bytes());
        message.extend_from_slice(profile.as_bytes());
        message.extend_from_slice(&(document.len() as u64).to_be_bytes());
        message.extend_from_slice(document.as_bytes());
        let namespace = hex_of(&crate::vault::crypto::mac(&key, b"namespace", &message)?, 4);
        Ok(Self { key, namespace })
    }

    /// The tail for one value: eight hex digits, not four.
    ///
    /// Four would be 65 536 names, and fifty values in one document collide
    /// about two times in a hundred — which for a **derived** name is not a
    /// retry but a lost promise, because the retry would depend on the order
    /// the values happened to be protected in and the order is not the same
    /// next time. Eight is 4.3 billion: fifty values collide about once in a
    /// million documents, and that one falls back to a random name, where item
    /// 1 reports it rather than restoring the wrong thing.
    fn tail(&self, value: &str) -> Option<String> {
        let value = nfc(value);
        let mut message: Vec<u8> = Vec::new();
        message.extend_from_slice(&(value.len() as u64).to_be_bytes());
        message.extend_from_slice(value.as_bytes());
        crate::vault::crypto::mac(&self.key, b"value", &message)
            .ok()
            .map(|out| hex_of(&out, 8))
    }
}

fn hex_of(bytes: &[u8], digits: usize) -> String {
    let mut out = String::with_capacity(digits);
    for byte in bytes.iter().take(digits.div_ceil(2)) {
        out.push_str(&format!("{byte:02X}"));
    }
    out.truncate(digits);
    out
}

/// Mints the tokens of one session.
#[derive(Debug)]
pub(crate) struct TokenMint {
    namespace: String,
    /// Set once, when the vault is open and a document is in hand. `None`
    /// keeps the random names this mint has always made.
    naming: Option<Naming>,
}

impl TokenMint {
    pub(crate) fn new() -> Self {
        Self {
            namespace: os_hex4(),
            naming: None,
        }
    }

    /// Only the tests read this; the namespace's job is to sit inside the tokens.
    #[cfg(test)]
    pub(crate) fn namespace(&self) -> &str {
        &self.namespace
    }

    /// Does this mint name tokens from the vault's key already?
    pub(crate) fn names_from_the_vault(&self) -> bool {
        self.naming.is_some()
    }

    /// Take the naming for this document. Called once; calling it again with a
    /// different document would rename tokens already minted, so the caller
    /// asks `names_from_the_vault` first.
    pub(crate) fn name_from(&mut self, naming: Naming) {
        self.namespace = naming.namespace.clone();
        self.naming = Some(naming);
    }

    /// A token of this kind for this value, not already in `taken`.
    ///
    /// **Derived when the vault is open**, so the same value in the same file
    /// in the same client is the same token for ever, with nothing stored.
    /// Random otherwise — see `Naming::derive` for why that is the honest
    /// fallback and not a weaker one.
    pub(crate) fn mint(&mut self, kind: Kind, value: &str, taken: &TokenStore) -> String {
        if let Some(naming) = self.naming.as_ref() {
            if let Some(tail) = naming.tail(value) {
                let token = format!("__Z_{}_{}_{}__", self.namespace, kind_word(kind), tail);
                // Taken by this very value already is not a collision: one
                // value, one token, which is the store's own rule.
                if !taken.contains(&token) {
                    return token;
                }
            }
        }
        for _ in 0..64 {
            let token = format!("__Z_{}_{}_{}__", self.namespace, kind_word(kind), os_hex4());
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
        Kind::Bic => "BIC",
        Kind::Account => "ACCOUNT",
        Kind::TaxId => "TAXID",
        Kind::CustomerNo => "CUSTNO",
        Kind::Address => "ADDR",
        Kind::IdCard => "IDCARD",
        Kind::Birthdate => "BORN",
        Kind::Vehicle => "PLATE",
        Kind::SocialInsuranceNo => "SVNR",
        Kind::EmployeeNo => "EMPNO",
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
    pub value: Secret,
    /// Other spellings of the same thing, all resolving to this one token.
    pub aliases: Vec<Secret>,
    pub kind: Kind,
    pub scope: Scope,
    /// Who found the value.
    pub source: Source,
    /// Whether a person decided to protect it. Shown in the tokens panel, and
    /// the reason a rescan leaves it alone.
    pub decided: bool,
    pub source_detail: String,
}

impl TokenEntry {
    /// Does `text` name this entry, in any of its spellings?
    ///
    /// Compared in NFC: one value written in two Unicode compositions is one
    /// value, here and in the leak audit.
    pub(crate) fn matches(&self, text: &str) -> bool {
        let wanted = nfc(text);
        nfc(self.value.expose()) == wanted || self.aliases.iter().any(|a| nfc(a.expose()) == wanted)
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
                let fresh = nfc(entry.value.expose()) != nfc(&alias)
                    && !entry.aliases.iter().any(|a| nfc(a.expose()) == nfc(&alias));
                if fresh {
                    entry.aliases.push(Secret::new(alias));
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
                decided: e.decided,
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
            out.push(e.value.expose().to_string());
            out.extend(e.aliases.iter().map(|a| a.expose().to_string()));
        }
        out
    }
}

/// Put the values back into an answer — and nothing else.
///
/// Only tokens that this session actually minted **and** that appeared in the
/// originating payload are replaced. Anything that merely looks like a token
/// (`__Z_FAKE_123__`, a model inventing one), or a real token from elsewhere in
/// the session, is left exactly as it arrived: the core does not guess, and does
/// not pretend to know what it does not know. That is invariant G9.
/// A restored answer, and what could not be restored in it.
///
/// Two fields rather than one return value, because the names are the thing a
/// person is told and the pieces are the thing they read. Collecting the names
/// from the pieces at the screen would be a second count of the same fact.
pub(crate) struct Restoration {
    pub segments: Vec<Segment>,
    pub unknown: Vec<String>,
}

pub(crate) fn restore(raw: &str, store: &TokenStore, allowed: &[String]) -> Restoration {
    const OPEN: &str = "__Z_";
    const CLOSE: &str = "__";

    let mut out: Vec<Segment> = Vec::new();
    let mut unknown: Vec<String> = Vec::new();
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
        let allowed_here = allowed.iter().any(|t| t == candidate);
        match allowed_here.then(|| store.get(candidate)).flatten() {
            Some(entry) => {
                if !plain.is_empty() {
                    out.push(Segment { text: std::mem::take(&mut plain), piece: Piece::Words });
                }
                out.push(Segment {
                    text: entry.value.expose().to_string(),
                    piece: Piece::Restored,
                });
            }
            // **Not ours — and that is now said out loud** (046/U).
            //
            // This line used to read «it stays word for word» and push the
            // token into the plain text, which is how an answer from another
            // conversation came back looking like the model's own sentence
            // with `__Z_5CDD_IBAN_5B32__` in the middle of it. No error, no
            // warning: the lie the owner met after days away.
            //
            // It still stays word for word, because the model really did write
            // it and dropping it would be a second lie. What changes is that
            // it is a piece of its own, and its name is reported.
            //
            // A candidate that merely **looks** like a token is text: the
            // shape test is `is_token`, so the model is free to write about
            // tokens without raising a false alarm a person cannot act on.
            None => {
                if is_token(candidate) {
                    if !plain.is_empty() {
                        out.push(Segment {
                            text: std::mem::take(&mut plain),
                            piece: Piece::Words,
                        });
                    }
                    out.push(Segment {
                        text: candidate.to_string(),
                        piece: Piece::Unresolved,
                    });
                    if !unknown.iter().any(|t| t == candidate) {
                        unknown.push(candidate.to_string());
                    }
                } else {
                    plain.push_str(candidate);
                }
            }
        }
        cursor = end;
    }
    if !plain.is_empty() {
        out.push(Segment { text: plain, piece: Piece::Words });
    }
    Restoration { segments: out, unknown }
}

/// Is this candidate one of **our** token names?
///
/// By shape and nothing else: `__Z_` + four of the namespace + `_` + a kind in
/// capitals + `_` + four more + `__`, which is what `TokenMint` writes. It says
/// nothing about whether this conversation knows it — that is the caller's
/// question, and the whole point of 046/U is that the two are different.
///
/// Deliberately strict. A loose test would turn «tokens look like __Z_ and end
/// in __» into two warnings about an answer that is perfectly fine.
///
/// **The tail is four to eight**, and that range is not slack. A random name's
/// tail is four; a derived one's is eight (046/U item 2, and the reason is in
/// `Naming::tail`). When item 2 landed, this function still demanded exactly
/// four — so every derived token it met was «not a token» and went straight
/// back into the plain text, which is the silent pass-through item 1 exists to
/// kill, returned by the hand that was supposed to be building on it. Item 1's
/// own test caught it within the minute.
///
/// It also has to keep accepting four for ever: an answer written before item
/// 2 carries four-character tails, and that answer is exactly the one a person
/// pastes days later.
fn is_token(candidate: &str) -> bool {
    let Some(middle) = candidate.strip_prefix("__Z_").and_then(|m| m.strip_suffix("__")) else {
        return false;
    };
    let mut parts = middle.split('_');
    let (Some(namespace), Some(kind), Some(tail), None) =
        (parts.next(), parts.next(), parts.next(), parts.next())
    else {
        return false;
    };
    namespace.len() == 4
        && namespace.bytes().all(|b| b.is_ascii_alphanumeric())
        && !kind.is_empty()
        && kind.bytes().all(|b| b.is_ascii_uppercase() || b.is_ascii_digit())
        && (4..=8).contains(&tail.len())
        && tail.bytes().all(|b| b.is_ascii_alphanumeric())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_token_carries_its_kind_and_its_session() {
        let mut mint = TokenMint::new();
        let store = TokenStore::default();
        let token = mint.mint(Kind::Person, "Thomas Müller", &store);
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
        let mut mint = TokenMint::new();
        let mut store = TokenStore::default();
        let first = mint.mint(Kind::Company, "Nordstern GmbH", &store);
        store.insert(first.clone(), entry("Nordstern GmbH", Kind::Company));
        let second = mint.mint(Kind::Company, "Nordstern GmbH", &store);
        assert_ne!(first, second);
    }

    #[test]
    fn every_spelling_finds_the_same_token() {
        let mut store = TokenStore::default();
        let token = "__Z_ABCD_PERSON_1234__".to_string();
        let mut e = entry("Thomas Müller", Kind::Person);
        e.aliases = vec![Secret::new("Herr Müller"), Secret::new("T. Müller")];
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
            value: Secret::new(value),
            aliases: Vec::new(),
            kind,
            scope: Scope::Conversation,
            source: Source::Hand,
            decided: true,
            source_detail: String::new(),
        }
    }
}

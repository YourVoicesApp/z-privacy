//! The vault's envelope.
//!
//! The owner's rule, and the reason the design is shaped this way:
//!
//! ```text
//! passphrase → Argon2id → key-encryption key → unwraps a random MASTER key
//!                                                      ↓
//!                                        the master key is a KDF root, never a
//!                                        cipher key. From it, by domain:
//!                                          ├── data      → seals the vault body
//!                                          ├── provider  → seals a credential
//!                                          └── profile   → reserved, task 021
//! ```
//!
//! The owner's amendment of 27 September, and the reason: the master key must not
//! become the one AEAD key behind every purpose in the vault forever. Each purpose
//! gets its own key, derived with its own domain string, so a future purpose — or
//! a future cipher — is added without any existing key doing two jobs.
//!
//! Changing the passphrase re-wraps **32 bytes**, not the whole vault. The body's
//! ciphertext is not touched, and a test asserts those bytes are identical
//! afterwards — otherwise this design would only be a claim.
//!
//! Every vault carries its own random salt and its own KDF parameters, written
//! beside a format version. The cost can be raised for new vaults tomorrow
//! without locking anyone out of an old one: the numbers used to open a vault are
//! the numbers stored inside it.

use argon2::{Algorithm, Argon2, Params, Version};
use blake2::digest::consts::U32;
use blake2::digest::Mac;
use blake2::Blake2bMac;
use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{ChaCha20Poly1305, Nonce};
use zeroize::{Zeroize, Zeroizing};

use crate::api::{ApiError, ApiResult};

/// Bumped only when the bytes on disk change shape. An old file keeps opening
/// because its own version, salt and costs are read from it.
///
/// * 1 — the master key sealed the body itself, and a credential sat in the body
///   in the clear.
/// * 2 — the master key derives per-purpose keys (task 021): the body is sealed by
///   the **data** key, and each credential by the **provider** key, so a leak of
///   the decoded body is still not a leak of a credential. A format-1 vault opens
///   here and is written as format 2 the next time anything changes.
pub(crate) const FORMAT_VERSION: u16 = 2;
const MAGIC: &[u8; 4] = b"ZVLT";
const KEY_LEN: usize = 32;
const NONCE_LEN: usize = 12;
const SALT_LEN: usize = 16;

/// Argon2id costs. These are today's numbers for a new vault; an existing vault
/// opens with whatever numbers are written in it.
const DEFAULT_M_COST: u32 = 64 * 1024; // 64 MiB
const DEFAULT_T_COST: u32 = 3;
const DEFAULT_P_COST: u32 = 1;
/// The KDF range this build supports when reading a vault file.
///
/// The floor admits every historical vault format this build can still open,
/// including the format-1 test vector at m=8, t=1, p=1. The ceiling admits a
/// deliberate near-term cost raise, but refuses attacker-chosen memory sizes
/// before Argon2 is constructed.
const MIN_M_COST: u32 = 8;
const MAX_M_COST: u32 = 128 * 1024; // 128 MiB
const MIN_T_COST: u32 = 1;
const MAX_T_COST: u32 = 8;
const MIN_P_COST: u32 = 1;
const MAX_P_COST: u32 = 4;
const MIN_M_COST_PER_LANE: u32 = 8;

/// A key that wipes itself when it goes out of scope.
pub(crate) type SecretKey = Zeroizing<[u8; KEY_LEN]>;

/// What each derived key is *for*. The string is part of the format: changing one
/// changes the key, so these are as fixed as the kind codes in `format.rs`.
///
/// A new purpose takes a new string. No string is ever reused for a second
/// purpose, and no purpose ever borrows another's key.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Purpose {
    /// Seals the vault body: identities, values, profiles.
    Data,
    /// Seals one provider credential, inside that body.
    Provider,
    /// Reserved. Named here so the string is claimed and cannot be re-used for
    /// something else later — the owner's `future-profile key`.
    #[allow(dead_code)]
    Profile,
    /// **Seals one session's 32-byte key, inside the vault body** — 064.
    ///
    /// Exactly the shape task 021 gave a provider credential, and for exactly
    /// the same reason. 062 §A claimed that a leak of the decoded vault body
    /// was still not a leak of a conversation. As first specified that was
    /// false: the session key lay in the body, and whoever held the decoded
    /// body held the key and therefore the conversation sealed under it. One
    /// more derived key makes the sentence true — the body's bytes for this
    /// field are ciphertext even though the body as a whole is already
    /// encrypted.
    Session,
    /// **Reserved since 064, and the string stays claimed.**
    ///
    /// This named the tokens of one document — 046/U item 2 — from
    /// `profile ‖ document-text`. 064 replaced that with the session's own key,
    /// so nothing derives this any more. The variant stays for the reason
    /// `Profile` does: a purpose string is never reused, and deleting the
    /// variant would leave `z-privacy/vault/1/token-name` free for somebody to
    /// claim for something else. The code that used it is gone; the string is
    /// spent for ever.
    #[allow(dead_code)]
    ///
    /// Nothing is sealed with this key and nothing is stored under it: a token
    /// name is derived from it every time, out of the client, the document's
    /// own bytes and the value. That is what makes the same file in the same
    /// client give the same token for ever with no record kept, and it is why
    /// the key must never leave this crate — a name derived under a key that
    /// did leave would be a value anybody could test a guess against.
    TokenName,
    /// **Seals one session's own file** — 064. Derived from the *session* key,
    /// not from the vault's master.
    SessionSeal,
    /// **Names the tokens of one session** — 064, and this is what replaces
    /// 046/U's `profile ‖ document-text` namespace.
    ///
    /// Derived from the session key, so the same person protected in two
    /// documents of one session carries **one** token, and in two sessions
    /// carries two. 046/U's rule — that stability across days and linkability
    /// across requests are the same property — is not repealed by this; it is
    /// handed to the person, who makes a clean break by starting a session and
    /// keeps continuity by staying in one.
    SessionNamespace,
    /// **The tails of one session's tokens** — 064. Derived from the session
    /// key, never from the master: two sessions must not be able to produce the
    /// same tail for the same spelling.
    SessionValue,
}

impl Purpose {
    fn domain(self) -> &'static [u8] {
        match self {
            Self::Data => b"z-privacy/vault/1/data",
            Self::Provider => b"z-privacy/vault/1/provider-credential",
            Self::Profile => b"z-privacy/vault/1/profile",
            Self::TokenName => b"z-privacy/vault/1/token-name",
            Self::Session => b"z-privacy/vault/1/session-key",
            // These three hang off a **session** key, so they are named for the
            // session ladder and not the vault's. The number in the path is the
            // ladder's version, as it is above — not a session's number, which
            // must never enter a domain string: one session's key deriving
            // another's by counting is precisely what the separate random keys
            // exist to prevent.
            Self::SessionSeal => b"z-privacy/session/1/seal",
            Self::SessionNamespace => b"z-privacy/session/1/namespace",
            Self::SessionValue => b"z-privacy/session/1/value",
        }
    }
}

/// One purpose's key, from a key above it in the ladder.
///
/// Usually the vault's master key. Since 064 it is also called with a
/// **session** key for the three `Session*` purposes — the function is a PRF
/// and does not care which key it is given, but the caller must: a purpose
/// string belongs to exactly one ladder, and mixing them would let a session
/// key produce a vault-level key or the reverse. The variants say which.
///
/// Keyed BLAKE2b — a PRF, used the way libsodium's `crypto_kdf` uses it: the
/// master key is the key, the domain string is the message, the output is 32
/// bytes. HKDF would do the same job; BLAKE2b is chosen because `blake2` is
/// **already in the tree** (Argon2 is built on it), so domain separation costs
/// zero new dependencies to audit. G1's rule about justified dependencies cuts
/// both ways: the cheapest correct option wins.
pub(crate) fn derive(master: &SecretKey, purpose: Purpose) -> ApiResult<SecretKey> {
    let mut mac = <Blake2bMac<U32> as Mac>::new_from_slice(master.as_ref()).map_err(|_| ApiError::PayloadRefused {
        reason: "the master key has the wrong length for key derivation".to_string(),
    })?;
    mac.update(purpose.domain());
    let out = mac.finalize().into_bytes();
    let bytes: [u8; KEY_LEN] = out.as_slice().try_into().map_err(|_| ApiError::PayloadRefused {
        reason: "key derivation produced the wrong length".to_string(),
    })?;
    Ok(Zeroizing::new(bytes))
}

/// **A keyed tag over a message** — the same primitive as `derive`, used as a
/// MAC rather than as a KDF.
///
/// `label` separates one use of the same key from another, so «the namespace
/// of this document» and «the tail of this value» can share a key without
/// one being computable from the other. Both are length-prefixed by the
/// caller, because a separator alone lets an input ending in it forge another.
///
/// 046/U item 2 is the only caller. Nothing sealed, nothing stored: the output
/// is a name, derived again every time it is needed.
pub(crate) fn mac(key: &SecretKey, label: &[u8], message: &[u8]) -> ApiResult<[u8; KEY_LEN]> {
    let mut mac = <Blake2bMac<U32> as Mac>::new_from_slice(key.as_ref()).map_err(|_| ApiError::PayloadRefused {
        reason: "the key has the wrong length for a tag".to_string(),
    })?;
    mac.update(&(label.len() as u64).to_be_bytes());
    mac.update(label);
    mac.update(message);
    let out = mac.finalize().into_bytes();
    out.as_slice().try_into().map_err(|_| ApiError::PayloadRefused {
        reason: "a tag came out the wrong length".to_string(),
    })
}

/// Seal something with a purpose's key. Used by `format.rs` for a credential.
pub(crate) fn seal_for(master: &SecretKey, purpose: Purpose, plaintext: &[u8]) -> ApiResult<Vec<u8>> {
    seal(&derive(master, purpose)?, plaintext)
}

/// Open something sealed with a purpose's key.
pub(crate) fn open_for(master: &SecretKey, purpose: Purpose, sealed: &[u8]) -> ApiResult<Zeroizing<Vec<u8>>> {
    open(&derive(master, purpose)?, sealed)
}

/// What the KDF was asked to do, kept with the vault so it can be repeated — and
/// so the cost can rise for new vaults without breaking old ones.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct KdfParams {
    pub format: u16,
    pub m_cost: u32,
    pub t_cost: u32,
    pub p_cost: u32,
    pub salt: [u8; SALT_LEN],
}

impl KdfParams {
    fn fresh() -> ApiResult<Self> {
        Self::new(
            FORMAT_VERSION,
            DEFAULT_M_COST,
            DEFAULT_T_COST,
            DEFAULT_P_COST,
            random_array::<SALT_LEN>()?,
        )
    }

    fn new(format: u16, m_cost: u32, t_cost: u32, p_cost: u32, salt: [u8; SALT_LEN]) -> ApiResult<Self> {
        validate_kdf_params(m_cost, t_cost, p_cost)?;
        Ok(Self {
            format,
            m_cost,
            t_cost,
            p_cost,
            salt,
        })
    }

    fn with_salt(&self, salt: [u8; SALT_LEN]) -> ApiResult<Self> {
        Self::new(self.format, self.m_cost, self.t_cost, self.p_cost, salt)
    }
}

fn validate_kdf_params(m_cost: u32, t_cost: u32, p_cost: u32) -> ApiResult<()> {
    let unsupported = |reason: String| ApiError::UnsupportedKdfParameters { reason };
    if !(MIN_M_COST..=MAX_M_COST).contains(&m_cost) {
        return Err(unsupported(format!(
            "m_cost {m_cost} is outside the supported range {MIN_M_COST}..={MAX_M_COST}"
        )));
    }
    if !(MIN_T_COST..=MAX_T_COST).contains(&t_cost) {
        return Err(unsupported(format!(
            "t_cost {t_cost} is outside the supported range {MIN_T_COST}..={MAX_T_COST}"
        )));
    }
    if !(MIN_P_COST..=MAX_P_COST).contains(&p_cost) {
        return Err(unsupported(format!(
            "p_cost {p_cost} is outside the supported range {MIN_P_COST}..={MAX_P_COST}"
        )));
    }
    let min_memory = MIN_M_COST_PER_LANE * p_cost;
    if m_cost < min_memory {
        return Err(unsupported(format!(
            "m_cost {m_cost} is too small for p_cost {p_cost}; at least {min_memory} is required"
        )));
    }
    Ok(())
}

/// The whole file: what it takes to open the vault, and the vault itself.
#[derive(Debug, Clone)]
pub(crate) struct SealedVault {
    pub params: KdfParams,
    /// The master key, sealed by the key derived from the passphrase.
    pub wrapped_master: Vec<u8>,
    /// The vault's contents, sealed by the master key.
    pub body: Vec<u8>,
}

/// **A session's own 32 bytes** — 064. Asked of the operating system, never
/// derived from anything: no path may lead from one session's key to another's,
/// which is the same property the domain strings keep by refusing to carry a
/// session number.
pub(crate) fn random_key() -> ApiResult<SecretKey> {
    Ok(Zeroizing::new(random_array::<KEY_LEN>()?))
}

fn random_array<const N: usize>() -> ApiResult<[u8; N]> {
    let mut out = [0u8; N];
    getrandom::fill(&mut out).map_err(|_| ApiError::PayloadRefused {
        reason: "the operating system would not give us randomness".to_string(),
    })?;
    Ok(out)
}

/// passphrase + this vault's salt and costs → the key-encryption key.
fn derive_kek(passphrase: &str, params: &KdfParams) -> ApiResult<SecretKey> {
    let argon_params = Params::new(params.m_cost, params.t_cost, params.p_cost, Some(KEY_LEN)).map_err(|e| {
        ApiError::PayloadRefused {
            reason: format!("the vault's stored KDF parameters are not usable: {e}"),
        }
    })?;
    let argon = Argon2::new(Algorithm::Argon2id, Version::V0x13, argon_params);
    let mut key = Zeroizing::new([0u8; KEY_LEN]);
    argon
        .hash_password_into(passphrase.as_bytes(), &params.salt, key.as_mut())
        .map_err(|e| ApiError::PayloadRefused {
            reason: format!("the passphrase could not be turned into a key: {e}"),
        })?;
    Ok(key)
}

fn seal(key: &SecretKey, plaintext: &[u8]) -> ApiResult<Vec<u8>> {
    let cipher = ChaCha20Poly1305::new(key.as_ref().into());
    let nonce_bytes = random_array::<NONCE_LEN>()?;
    let nonce = Nonce::from_slice(&nonce_bytes);
    let mut out = nonce_bytes.to_vec();
    let mut sealed = cipher.encrypt(nonce, plaintext).map_err(|_| ApiError::PayloadRefused {
        reason: "sealing failed".to_string(),
    })?;
    out.append(&mut sealed);
    Ok(out)
}

fn open(key: &SecretKey, sealed: &[u8]) -> ApiResult<Zeroizing<Vec<u8>>> {
    if sealed.len() <= NONCE_LEN {
        return Err(ApiError::PayloadRefused {
            reason: "this vault file is truncated".to_string(),
        });
    }
    let (nonce_bytes, body) = sealed.split_at(NONCE_LEN);
    let cipher = ChaCha20Poly1305::new(key.as_ref().into());
    let plain = cipher
        .decrypt(Nonce::from_slice(nonce_bytes), body)
        .map_err(|_| ApiError::VaultAuthenticationFailed)?;
    Ok(Zeroizing::new(plain))
}

impl SealedVault {
    /// A brand new vault: a random master key, sealed under a key derived from
    /// this passphrase, and an empty body sealed under the master key.
    pub(crate) fn create(passphrase: &str, body_plain: &[u8]) -> ApiResult<(Self, SecretKey)> {
        let params = KdfParams::fresh()?;
        let kek = derive_kek(passphrase, &params)?;
        let master: SecretKey = Zeroizing::new(random_array::<KEY_LEN>()?);
        let wrapped_master = seal(&kek, master.as_ref())?;
        let body = seal(&derive(&master, Purpose::Data)?, body_plain)?;
        Ok((
            Self {
                params,
                wrapped_master,
                body,
            },
            master,
        ))
    }

    /// Open the envelope. A wrong passphrase and a modified vault both become
    /// [`ApiError::VaultAuthenticationFailed`]: the AEAD tag simply does not
    /// verify, and nothing else is learned.
    pub(crate) fn unwrap_master(&self, passphrase: &str) -> ApiResult<SecretKey> {
        let kek = derive_kek(passphrase, &self.params)?;
        let plain = open(&kek, &self.wrapped_master)?;
        let bytes: [u8; KEY_LEN] = plain.as_slice().try_into().map_err(|_| ApiError::PayloadRefused {
            reason: "the wrapped master key has the wrong length".to_string(),
        })?;
        Ok(Zeroizing::new(bytes))
    }

    /// Open the body with the key its own format says was used. A format-1 file
    /// was sealed by the master key itself; from format 2 it is the data key.
    pub(crate) fn open_body(&self, master: &SecretKey) -> ApiResult<Zeroizing<Vec<u8>>> {
        if self.params.format < 2 {
            return open(master, &self.body);
        }
        open(&derive(master, Purpose::Data)?, &self.body)
    }

    /// Write the body — always in today's format. A vault opened as format 1 is
    /// upgraded here, on the first change, with no separate migration step and no
    /// moment where the file says one thing and holds another.
    pub(crate) fn reseal_body(&mut self, master: &SecretKey, body_plain: &[u8]) -> ApiResult<()> {
        self.body = seal(&derive(master, Purpose::Data)?, body_plain)?;
        self.params.format = FORMAT_VERSION;
        Ok(())
    }

    /// Whether a credential inside the body is sealed (format 2) or was written in
    /// the clear (format 1). `format.rs` asks, so that an old vault still reads.
    pub(crate) fn credentials_are_sealed(&self) -> bool {
        self.params.format >= 2
    }

    /// Change the passphrase by re-wrapping the master key. The body is not read,
    /// not decrypted and not rewritten — which is the whole point of the envelope.
    pub(crate) fn change_passphrase(&mut self, old: &str, new_passphrase: &str) -> ApiResult<()> {
        let master = self.unwrap_master(old)?;
        // A new salt, so the new passphrase gets its own derivation — but the
        // vault keeps its own costs. Changing a passphrase must not silently
        // change how expensive the vault is to open; raising the cost is a
        // separate, deliberate act (and old vaults keep working either way).
        let params = self.params.with_salt(random_array::<SALT_LEN>()?)?;
        let kek = derive_kek(new_passphrase, &params)?;
        self.wrapped_master = seal(&kek, master.as_ref())?;
        self.params = params;
        Ok(())
    }

    // ------------------------------------------------------------ on disk

    /// The file, byte for byte. Length-prefixed and versioned by hand: the shape
    /// is small enough to read in one sitting, and adding a dependency to write
    /// four numbers would widen what has to be audited.
    pub(crate) fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(self.body.len() + 128);
        out.extend_from_slice(MAGIC);
        out.extend_from_slice(&self.params.format.to_be_bytes());
        out.push(1); // 1 = Argon2id, ChaCha20-Poly1305
        out.extend_from_slice(&self.params.m_cost.to_be_bytes());
        out.extend_from_slice(&self.params.t_cost.to_be_bytes());
        out.extend_from_slice(&self.params.p_cost.to_be_bytes());
        out.extend_from_slice(&self.params.salt);
        put_block(&mut out, &self.wrapped_master);
        put_block(&mut out, &self.body);
        out
    }

    pub(crate) fn from_bytes(bytes: &[u8]) -> ApiResult<Self> {
        let mut r = Reader::new(bytes);
        if r.take(4)? != MAGIC {
            return Err(ApiError::PayloadRefused {
                reason: "this is not a Z Privacy vault file".to_string(),
            });
        }
        let format = u16::from_be_bytes(r.array::<2>()?);
        if format > FORMAT_VERSION {
            return Err(ApiError::PayloadRefused {
                reason: format_error(format),
            });
        }
        let suite = r.byte()?;
        if suite != 1 {
            return Err(ApiError::PayloadRefused {
                reason: format!("this vault uses cipher suite {suite}, which this build does not know"),
            });
        }
        let m_cost = u32::from_be_bytes(r.array::<4>()?);
        let t_cost = u32::from_be_bytes(r.array::<4>()?);
        let p_cost = u32::from_be_bytes(r.array::<4>()?);
        let salt = r.array::<SALT_LEN>()?;
        let params = KdfParams::new(format, m_cost, t_cost, p_cost, salt)?;
        let wrapped_master = r.block()?;
        let body = r.block()?;
        r.finish()?;
        Ok(Self {
            params,
            wrapped_master,
            body,
        })
    }
}

fn format_error(found: u16) -> String {
    format!(
        "this vault was written by a newer version of Z Privacy (format {found}, this build knows {FORMAT_VERSION})"
    )
}

fn put_block(out: &mut Vec<u8>, block: &[u8]) {
    out.extend_from_slice(&(block.len() as u32).to_be_bytes());
    out.extend_from_slice(block);
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
        let slice = self.take(N)?;
        slice.try_into().map_err(|_| truncated())
    }

    fn byte(&mut self) -> ApiResult<u8> {
        Ok(self.array::<1>()?[0])
    }

    fn block(&mut self) -> ApiResult<Vec<u8>> {
        let len = u32::from_be_bytes(self.array::<4>()?) as usize;
        Ok(self.take(len)?.to_vec())
    }

    fn finish(&self) -> ApiResult<()> {
        if self.at == self.bytes.len() {
            Ok(())
        } else {
            Err(ApiError::TrailingVaultData)
        }
    }
}

fn truncated() -> ApiError {
    ApiError::PayloadRefused {
        reason: "this vault file is truncated".to_string(),
    }
}

/// Wipe a plain `Vec<u8>` that held plaintext.
pub(crate) fn wipe(mut bytes: Vec<u8>) {
    bytes.zeroize();
}

#[cfg(test)]
mod tests {
    use super::*;

    const PASS: &str = "ein langes und gutes Passwort";
    const BODY: &[u8] = b"CLIENT #17 / Nordstern Consulting / Thomas Mueller";

    /// Argon2id at 64 MiB is deliberately slow; these tests use small costs so the
    /// suite stays fast, and the real numbers are exercised once below.
    fn cheap_vault() -> (SealedVault, SecretKey) {
        // Create with cheap parameters from the start, so unwrapping matches.
        let mut params = KdfParams::fresh().expect("params");
        params.m_cost = 8;
        params.t_cost = 1;
        let kek = derive_kek(PASS, &params).expect("kek");
        let master: SecretKey = Zeroizing::new(random_array::<KEY_LEN>().expect("master"));
        let wrapped_master = seal(&kek, master.as_ref()).expect("wrap");
        // Today's format: the body is sealed by the data key, not the master.
        let body = seal(&derive(&master, Purpose::Data).expect("data key"), BODY).expect("seal body");
        (
            SealedVault {
                params,
                wrapped_master,
                body,
            },
            master,
        )
    }

    /// A vault as format 1 wrote one: the master key sealed the body itself.
    fn format_one_vault() -> SealedVault {
        let mut params = KdfParams::fresh().expect("params");
        params.m_cost = 8;
        params.t_cost = 1;
        params.format = 1;
        let kek = derive_kek(PASS, &params).expect("kek");
        let master: SecretKey = Zeroizing::new(random_array::<KEY_LEN>().expect("master"));
        let wrapped_master = seal(&kek, master.as_ref()).expect("wrap");
        let body = seal(&master, BODY).expect("seal body");
        SealedVault {
            params,
            wrapped_master,
            body,
        }
    }

    fn bytes_with_kdf(m_cost: u32, t_cost: u32, p_cost: u32) -> Vec<u8> {
        let (vault, _) = cheap_vault();
        let mut bytes = vault.to_bytes();
        bytes[7..11].copy_from_slice(&m_cost.to_be_bytes());
        bytes[11..15].copy_from_slice(&t_cost.to_be_bytes());
        bytes[15..19].copy_from_slice(&p_cost.to_be_bytes());
        bytes
    }

    fn assert_unsupported_kdf(bytes: &[u8], wanted: &str) {
        match SealedVault::from_bytes(bytes) {
            Err(ApiError::UnsupportedKdfParameters { reason }) => assert!(
                reason.contains(wanted),
                "the refusal should name {wanted}, got {reason}"
            ),
            other => panic!("expected UnsupportedKdfParameters, got {other:?}"),
        }
    }

    #[test]
    fn each_purpose_gets_its_own_key_and_the_master_is_not_one_of_them() {
        let master: SecretKey = Zeroizing::new([3u8; KEY_LEN]);
        let data = derive(&master, Purpose::Data).expect("data");
        let provider = derive(&master, Purpose::Provider).expect("provider");
        let profile = derive(&master, Purpose::Profile).expect("profile");

        assert_ne!(data.as_ref(), provider.as_ref(), "two purposes, two keys");
        assert_ne!(data.as_ref(), profile.as_ref());
        assert_ne!(provider.as_ref(), profile.as_ref());
        assert_ne!(
            data.as_ref(),
            master.as_ref(),
            "the master key is a root, not a cipher key"
        );

        // Derivation is a function, not a random draw: the same vault must open
        // tomorrow. This is what makes the domain strings part of the format.
        assert_eq!(derive(&master, Purpose::Data).expect("again").as_ref(), data.as_ref());

        // And a different master gives different keys, obviously — but say it, so
        // that a constant accidentally left in place would fail here.
        let other: SecretKey = Zeroizing::new([4u8; KEY_LEN]);
        assert_ne!(derive(&other, Purpose::Data).expect("other").as_ref(), data.as_ref());
    }

    #[test]
    fn something_sealed_for_one_purpose_does_not_open_with_another() {
        let master: SecretKey = Zeroizing::new([9u8; KEY_LEN]);
        let sealed = seal_for(&master, Purpose::Provider, b"sk-not-a-real-credential").expect("seal");
        let back = open_for(&master, Purpose::Provider, &sealed).expect("open");
        assert_eq!(back.as_slice(), b"sk-not-a-real-credential");

        // The whole reason for domain separation, as a test.
        match open_for(&master, Purpose::Data, &sealed) {
            Err(ApiError::VaultAuthenticationFailed) => {}
            other => panic!("a credential must not open with the data key: {other:?}"),
        }
    }

    #[test]
    fn a_format_one_vault_still_opens_and_is_written_forward() {
        let vault = format_one_vault();
        let vault = SealedVault::from_bytes(&vault.to_bytes()).expect("a format-1 file still reads");
        let master = vault.unwrap_master(PASS).expect("unwrap");
        assert!(
            !vault.credentials_are_sealed(),
            "format 1 held credentials in the clear"
        );
        assert_eq!(
            vault.open_body(&master).expect("an old vault still opens").as_slice(),
            BODY,
            "nothing older is left behind"
        );

        // The first change upgrades it, with no migration step of its own.
        let mut vault = vault;
        vault.reseal_body(&master, BODY).expect("reseal");
        assert_eq!(vault.params.format, FORMAT_VERSION);
        assert!(vault.credentials_are_sealed());
        assert_eq!(vault.open_body(&master).expect("body").as_slice(), BODY);

        // And the upgraded body is no longer readable with the master key itself.
        assert!(matches!(
            open(&master, &vault.body),
            Err(ApiError::VaultAuthenticationFailed)
        ));
    }

    #[test]
    fn a_vault_opens_with_its_passphrase_and_not_otherwise() {
        let (vault, _) = cheap_vault();
        let master = vault.unwrap_master(PASS).expect("the right passphrase opens it");
        let body = vault.open_body(&master).expect("body");
        assert_eq!(body.as_slice(), BODY);

        match vault.unwrap_master("das falsche Passwort") {
            Err(ApiError::VaultAuthenticationFailed) => {}
            other => panic!("a wrong passphrase must be indistinguishable from modification: {other:?}"),
        }
    }

    #[test]
    fn changing_the_passphrase_does_not_touch_the_body() {
        // The envelope's whole purpose, as a byte comparison.
        let (mut vault, _) = cheap_vault();
        let body_before = vault.body.clone();
        let wrapped_before = vault.wrapped_master.clone();

        vault.change_passphrase(PASS, "ein neues Passwort").expect("change");
        assert_eq!(vault.params.m_cost, 8, "the vault keeps its own costs");

        assert_eq!(
            vault.body, body_before,
            "the body was re-encrypted: the envelope is pointless"
        );
        assert_ne!(
            vault.wrapped_master, wrapped_before,
            "the master key must be re-wrapped"
        );

        // The old passphrase is dead, the new one works, and the body still reads.
        assert!(matches!(
            vault.unwrap_master(PASS),
            Err(ApiError::VaultAuthenticationFailed)
        ));
        let master = vault.unwrap_master("ein neues Passwort").expect("new passphrase");
        assert_eq!(vault.open_body(&master).expect("body").as_slice(), BODY);
    }

    #[test]
    fn the_file_carries_its_own_salt_and_costs() {
        let (vault, _) = cheap_vault();
        let bytes = vault.to_bytes();
        let read = SealedVault::from_bytes(&bytes).expect("round trip");

        assert_eq!(read.params, vault.params, "salt and costs come back unchanged");
        assert_eq!(read.params.format, FORMAT_VERSION);
        // And it opens after the round trip, which is what the numbers are for.
        let master = read.unwrap_master(PASS).expect("unwrap");
        assert_eq!(read.open_body(&master).expect("body").as_slice(), BODY);

        // Two vaults never share a salt.
        let (other, _) = cheap_vault();
        assert_ne!(other.params.salt, vault.params.salt);
    }

    #[test]
    fn unsupported_kdf_parameters_are_refused_before_argon2() {
        assert_unsupported_kdf(
            &bytes_with_kdf(MAX_M_COST + 1, DEFAULT_T_COST, DEFAULT_P_COST),
            "m_cost",
        );
        assert_unsupported_kdf(
            &bytes_with_kdf(DEFAULT_M_COST, MAX_T_COST + 1, DEFAULT_P_COST),
            "t_cost",
        );
        assert_unsupported_kdf(
            &bytes_with_kdf(DEFAULT_M_COST, DEFAULT_T_COST, MAX_P_COST + 1),
            "p_cost",
        );
        assert_unsupported_kdf(&bytes_with_kdf(0, DEFAULT_T_COST, DEFAULT_P_COST), "m_cost");
        assert_unsupported_kdf(&bytes_with_kdf(DEFAULT_M_COST, 0, DEFAULT_P_COST), "t_cost");
        assert_unsupported_kdf(&bytes_with_kdf(DEFAULT_M_COST, DEFAULT_T_COST, 0), "p_cost");
        assert_unsupported_kdf(&bytes_with_kdf(8, DEFAULT_T_COST, 2), "too small");
        assert_unsupported_kdf(&bytes_with_kdf(1_000_000, DEFAULT_T_COST, DEFAULT_P_COST), "m_cost");
    }

    #[test]
    fn a_broken_or_foreign_file_is_refused_with_a_reason() {
        let (vault, _) = cheap_vault();
        let bytes = vault.to_bytes();

        assert!(matches!(
            SealedVault::from_bytes(b"not a vault at all"),
            Err(ApiError::PayloadRefused { .. })
        ));
        assert!(matches!(
            SealedVault::from_bytes(&bytes[..bytes.len() / 2]),
            Err(ApiError::PayloadRefused { .. })
        ));

        // A file from a future format is refused, and says so rather than guessing.
        let mut future = bytes.clone();
        future[4] = 0xFF;
        match SealedVault::from_bytes(&future) {
            Err(ApiError::PayloadRefused { reason }) => assert!(reason.contains("newer version")),
            other => panic!("expected a refusal, got {other:?}"),
        }
    }

    #[test]
    fn trailing_vault_bytes_are_refused_for_every_supported_format() {
        let mut current = cheap_vault().0.to_bytes();
        current.push(b'!');
        assert!(matches!(
            SealedVault::from_bytes(&current),
            Err(ApiError::TrailingVaultData)
        ));

        let mut current_many = cheap_vault().0.to_bytes();
        current_many.extend_from_slice(b"ZXQ_TRAILER");
        assert!(matches!(
            SealedVault::from_bytes(&current_many),
            Err(ApiError::TrailingVaultData)
        ));

        let mut format_one = format_one_vault().to_bytes();
        format_one.push(0);
        assert!(matches!(
            SealedVault::from_bytes(&format_one),
            Err(ApiError::TrailingVaultData)
        ));
    }

    #[test]
    fn authentication_failure_does_not_claim_to_know_the_cause() {
        let vault = cheap_vault().0;
        let mut bytes = vault.to_bytes();
        let last = bytes.len() - 1;
        bytes[last] ^= 0x01;
        let changed = SealedVault::from_bytes(&bytes).expect("the structure still parses");
        let master = changed.unwrap_master(PASS).expect("passphrase still unwraps master");
        assert!(matches!(
            changed.open_body(&master),
            Err(ApiError::VaultAuthenticationFailed)
        ));

        assert!(matches!(
            vault.unwrap_master("das falsche Passwort"),
            Err(ApiError::VaultAuthenticationFailed)
        ));
    }

    #[test]
    fn the_real_cost_is_what_a_new_vault_gets() {
        // Runs the actual parameters once, so nobody can lower them by accident.
        let params = KdfParams::fresh().expect("params");
        assert_eq!(params.m_cost, 64 * 1024, "64 MiB");
        assert_eq!(params.t_cost, 3);
        assert_eq!(params.format, FORMAT_VERSION);
        let (vault, master) = SealedVault::create("ein echtes Passwort", BODY).expect("create");
        assert_eq!(vault.open_body(&master).expect("body").as_slice(), BODY);
        let read = SealedVault::from_bytes(&vault.to_bytes()).expect("a normal current vault reads");
        let master = read
            .unwrap_master("ein echtes Passwort")
            .expect("a normal current vault opens");
        assert_eq!(read.open_body(&master).expect("body").as_slice(), BODY);
    }
}

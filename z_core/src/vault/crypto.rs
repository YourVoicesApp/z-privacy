//! The vault's envelope.
//!
//! The owner's rule, and the reason the design is shaped this way:
//!
//! ```text
//! passphrase → Argon2id → key-encryption key → unwraps a random MASTER key
//!                                                      ↓
//!                                          the master key seals the vault body
//! ```
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
use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{ChaCha20Poly1305, Nonce};
use zeroize::{Zeroize, Zeroizing};

use crate::api::{ApiError, ApiResult};

/// Bumped only when the bytes on disk change shape. An old file keeps opening
/// because its own version, salt and costs are read from it.
pub(crate) const FORMAT_VERSION: u16 = 1;
const MAGIC: &[u8; 4] = b"ZVLT";
const KEY_LEN: usize = 32;
const NONCE_LEN: usize = 12;
const SALT_LEN: usize = 16;

/// Argon2id costs. These are today's numbers for a new vault; an existing vault
/// opens with whatever numbers are written in it.
const DEFAULT_M_COST: u32 = 64 * 1024; // 64 MiB
const DEFAULT_T_COST: u32 = 3;
const DEFAULT_P_COST: u32 = 1;

/// A key that wipes itself when it goes out of scope.
pub(crate) type SecretKey = Zeroizing<[u8; KEY_LEN]>;

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
        Ok(Self {
            format: FORMAT_VERSION,
            m_cost: DEFAULT_M_COST,
            t_cost: DEFAULT_T_COST,
            p_cost: DEFAULT_P_COST,
            salt: random_array::<SALT_LEN>()?,
        })
    }
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

fn random_array<const N: usize>() -> ApiResult<[u8; N]> {
    let mut out = [0u8; N];
    getrandom::fill(&mut out).map_err(|_| ApiError::PayloadRefused {
        reason: "the operating system would not give us randomness".to_string(),
    })?;
    Ok(out)
}

/// passphrase + this vault's salt and costs → the key-encryption key.
fn derive_kek(passphrase: &str, params: &KdfParams) -> ApiResult<SecretKey> {
    let argon_params = Params::new(params.m_cost, params.t_cost, params.p_cost, Some(KEY_LEN))
        .map_err(|e| ApiError::PayloadRefused {
            reason: format!("the vault's stored KDF parameters are not usable: {e}"),
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
    let mut sealed = cipher
        .encrypt(nonce, plaintext)
        .map_err(|_| ApiError::PayloadRefused {
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
        .map_err(|_| ApiError::VaultLocked)?;
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
        let body = seal(&master, body_plain)?;
        Ok((
            Self {
                params,
                wrapped_master,
                body,
            },
            master,
        ))
    }

    /// Open the envelope. A wrong passphrase is [`ApiError::VaultLocked`] — the
    /// AEAD tag simply does not verify, and nothing else is learned.
    pub(crate) fn unwrap_master(&self, passphrase: &str) -> ApiResult<SecretKey> {
        let kek = derive_kek(passphrase, &self.params)?;
        let plain = open(&kek, &self.wrapped_master)?;
        let bytes: [u8; KEY_LEN] = plain
            .as_slice()
            .try_into()
            .map_err(|_| ApiError::PayloadRefused {
                reason: "the wrapped master key has the wrong length".to_string(),
            })?;
        Ok(Zeroizing::new(bytes))
    }

    pub(crate) fn open_body(&self, master: &SecretKey) -> ApiResult<Zeroizing<Vec<u8>>> {
        open(master, &self.body)
    }

    pub(crate) fn reseal_body(&mut self, master: &SecretKey, body_plain: &[u8]) -> ApiResult<()> {
        self.body = seal(master, body_plain)?;
        Ok(())
    }

    /// Change the passphrase by re-wrapping the master key. The body is not read,
    /// not decrypted and not rewritten — which is the whole point of the envelope.
    pub(crate) fn change_passphrase(&mut self, old: &str, new_passphrase: &str) -> ApiResult<()> {
        let master = self.unwrap_master(old)?;
        // A new salt, so the new passphrase gets its own derivation — but the
        // vault keeps its own costs. Changing a passphrase must not silently
        // change how expensive the vault is to open; raising the cost is a
        // separate, deliberate act (and old vaults keep working either way).
        let params = KdfParams {
            salt: random_array::<SALT_LEN>()?,
            ..self.params.clone()
        };
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
        let wrapped_master = r.block()?;
        let body = r.block()?;
        Ok(Self {
            params: KdfParams {
                format,
                m_cost,
                t_cost,
                p_cost,
                salt,
            },
            wrapped_master,
            body,
        })
    }
}

fn format_error(found: u16) -> String {
    format!("this vault was written by a newer version of Z Privacy (format {found}, this build knows {FORMAT_VERSION})")
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
        let body = seal(&master, BODY).expect("seal body");
        (
            SealedVault {
                params,
                wrapped_master,
                body,
            },
            master,
        )
    }

    #[test]
    fn a_vault_opens_with_its_passphrase_and_not_otherwise() {
        let (vault, _) = cheap_vault();
        let master = vault.unwrap_master(PASS).expect("the right passphrase opens it");
        let body = vault.open_body(&master).expect("body");
        assert_eq!(body.as_slice(), BODY);

        match vault.unwrap_master("das falsche Passwort") {
            Err(ApiError::VaultLocked) => {}
            other => panic!("a wrong passphrase must say only «locked»: {other:?}"),
        }
    }

    #[test]
    fn changing_the_passphrase_does_not_touch_the_body() {
        // The envelope's whole purpose, as a byte comparison.
        let (mut vault, _) = cheap_vault();
        let body_before = vault.body.clone();
        let wrapped_before = vault.wrapped_master.clone();

        vault
            .change_passphrase(PASS, "ein neues Passwort")
            .expect("change");
        assert_eq!(vault.params.m_cost, 8, "the vault keeps its own costs");

        assert_eq!(vault.body, body_before, "the body was re-encrypted: the envelope is pointless");
        assert_ne!(vault.wrapped_master, wrapped_before, "the master key must be re-wrapped");

        // The old passphrase is dead, the new one works, and the body still reads.
        assert!(matches!(vault.unwrap_master(PASS), Err(ApiError::VaultLocked)));
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
    fn the_real_cost_is_what_a_new_vault_gets() {
        // Runs the actual parameters once, so nobody can lower them by accident.
        let params = KdfParams::fresh().expect("params");
        assert_eq!(params.m_cost, 64 * 1024, "64 MiB");
        assert_eq!(params.t_cost, 3);
        assert_eq!(params.format, FORMAT_VERSION);
        let (vault, master) = SealedVault::create("ein echtes Passwort", BODY).expect("create");
        assert_eq!(vault.open_body(&master).expect("body").as_slice(), BODY);
    }
}

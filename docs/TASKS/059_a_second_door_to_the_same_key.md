# 059 · A second door to the same key

**Status:** the owner's design, reviewed. Not built. Deferred past the freeze of 8 Oct.
**Decides:** whether a vault can be opened a second way, and what that costs.
**Measured against:** `z_core/src/vault/crypto.rs`, and the owner's own `vault.zv`
(4538 bytes, 8 Oct).

---

## What exists today, measured

`~/.local/share/zprivacy/vault.zv`, read byte for byte:

```
5a56 4c54   ZVLT
0002        format 2
01          suite 1 = Argon2id + ChaCha20-Poly1305
0001 0000   m_cost 65536  (64 MiB per guess)
0000 0003   t_cost 3
0000 0001   p_cost 1
<16 bytes>  this vault's own salt
0000 003c   wrapped_master = 60 bytes = 12 nonce + 32 key + 16 tag
<4 bytes>   body length, then the body
```

Two files are written and no third: `vault.zv` (sealed) and `settings.zcfg`
(clear, a closed list, no client and no value). 36.4 % of the vault body is
printable; random bytes are ≈ 37 %. The only readable run in the file is the
magic. There is no recovery, no escrow and no second copy of anything.

`change_passphrase` already re-wraps **32 bytes** and never reads the body. The
proposal below is that same move with a different key, which is why it is cheap.

---

## The design (the owner's, 8 Oct)

A 256-bit random Recovery Key, generated at creation, wrapping the **same**
master key in a second independent envelope. Shown once. Never written to
`vault.zv` or `settings.zcfg`. Optional at creation:

* **Maximum isolation** — one door. Forget the passphrase, lose the vault.
* **Recovery enabled** — two doors, the second kept off the machine.

Recovery = unwrap the master with the recovery key, choose a new passphrase,
re-wrap 32 bytes. The body is never decrypted.

**The design is right and it fits the envelope we already have.** What follows
is what it still needs before it can be built.

---

## A · The recovery key must NOT go through Argon2id

Argon2 exists to make guessing a **human** secret expensive. A 256-bit random
secret cannot be guessed; 64 MiB per attempt buys nothing and costs a recovery
on a weak machine.

Use the derivation already in the tree — keyed BLAKE2b, `crypto.rs:111` — under
a **new** domain string that is never reused:

```
z-privacy/vault/1/recovery
```

The `Purpose` rule in `crypto.rs:76` already says a string is claimed for ever.
This adds one variant and **zero dependencies**.

## B · The key is generated, never chosen

If a user may type their own recovery phrase, the vault's strength silently
becomes the weaker of two doors while the screen still says it is safe. The
length is a format constant, not a setting. `getrandom` is already in the tree.

## C · ZREC needs a check digit, and we already have the rule for it

A key read off paper will be mistyped. Without a check digit the program cannot
tell *mistyped* from *not this vault's key*, and will say the wrong thing at the
worst moment a person ever has with this product.

This is the rule adopted 8 Oct — **a check digit raises the explanation, not the
finding** — pointing the other way: here its whole job is to raise the
explanation. The tree already carries mod-97 and Luhn in
`scanner/general_rules.rs`; Crockford base32 plus a truncated BLAKE2b digit is
~30 lines and **no new crate**.

## D · The file now says that a recovery key exists — unless we stop it

The header is not encrypted. Add a second block and anyone holding `vault.zv`
learns that a recovery key exists somewhere in this person's life, which tells a
coercive reader *what to demand*. That is a real fact leaked by a privacy
product.

The fix is not to hide it — a hidden thing is a lie we cannot keep — but to make
the two choices **the same shape on disk**: always write two blocks, and under
*Maximum isolation* fill the second with 60 bytes that nothing can ever open.
Same size, same shape, no information. 60 bytes buys deniability.

The consequence, and it is the right one: a vault with no recovery key and a
vault whose recovery key is lost fail **identically**. That is the house rule
already proven at `crypto.rs:587` — a wrong passphrase and a modified vault are
one error.

**This is the owner's decision, not to be built on my word.**

## E · Rotation must exist on day one

A key shown once is a key that may have been photographed. The user must be able
to generate a new one and void the old, **while unlocked with the passphrase and
without the old key**. Same 32-byte re-wrap. Likewise turning recovery on or off
after creation.

## F · Where this will actually fail is the screen, not the cipher

People confirm that they saved it without saving it.

* Do not accept a click. Ask them to type back two groups, chosen at random —
  not the whole key, which only teaches copy-paste.
* "Save to file" must refuse to write into the data directory. Make the
  dangerous choice impossible, not merely discouraged. That is a guard a test
  can bite: write the recovery file into `~/.local/share/zprivacy/` and expect a
  refusal.
* A QR photographed by a phone is in a cloud backup within the minute. If we
  offer QR, the screen says that in its own words.

## G · Two version numbers, and they are not the same number

This changes the bytes on disk: `FORMAT_VERSION` 2 → 3 in `vault/crypto.rs`.
It does **not** touch `MODEL_VERSION` in `vault/format.rs`, which is going
10 → 11 today and which 046/S wants at 12. Wherever two places can disagree
about a fact, one is already wrong — so this is written down before anyone
confuses the envelope's version with the model's.

An old build meeting a new vault already refuses with a plain sentence
(`format_error`). Measured, not assumed.

## H · The enterprise case costs nothing to defer

2-of-3 is Shamir **over the recovery key**, entirely outside the file: the vault
still holds exactly one recovery wrap. So we must **not** add a
"several recovery blocks" field to the format in anticipation. Keeping it at two
wraps is what keeps the enterprise door open.

---

## The ordering, and why it is not the owner's

The owner proposed: better passphrase policy **and** an optional recovery key,
both later.

The order matters. **A length rule without a way back manufactures the behaviour
it is trying to prevent** — it moves the risk from "forgot it" to "wrote it on a
note beside the machine", and the second is worse because it is silent. Today
the only requirement is 8 characters (`ops/vault.rs:35`), and that is honest
*precisely because* forgetting is fatal.

So: **recovery first, policy second.** The policy is only safe once forgetting
is survivable.

---

## Awaiting the owner's word

1. Item D — two blocks always, or one block when there is no recovery key.
2. Whether *Maximum isolation* is the default at creation.

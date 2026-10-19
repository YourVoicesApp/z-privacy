# B6 — build / distribution

Commit `84832a015f74952556f5d512187a8d5f99673d9d`. Installed tree `/home/monopeaks/.local/opt/zprivacy` (BUILD-INFO: built 2026-10-17T17:21:29+02:00, `scripts/package_linux.sh`, rustc 1.98.0, Flutter 3.44.2).

`zprivacy` sha256 `2f5e8398454b249e6555879220019aec4a517cbc390efd14f440ce898e9777af`  
`lib/libz_bridge.so` sha256 `3a6674c216000c94e80dce9e4feb1e7401c89181545ca00c4382b535df45beaf`

---

## Defects

### B6-1 · rustls is one patch behind four 2026-10-14 advisories

What I did: `cargo-audit` is not installed on this machine. Read `src/Cargo.lock`: `rustls 0.23.45`, `rustls-webpki 0.103.15`, `ring 0.17.14`. Compared with rustls v0.23.46 (released 2026-10-14) and the RUSTSEC/GHSA list.

What should happen: a release built 2026-10-17 either sits on 0.23.46 or names why it does not. CI would run `cargo audit`.

What happened: the lock is 0.23.45. 0.23.46 patches GHSA-h2v8-394m-p7vv (brotli 1 GiB alloc), GHSA-c8m5-c952-6cm4 (Debug of session values prints TLS secrets), GHSA-w44r-93j7-qv28 (unauthenticated ServerHello can drop later connections to classical X25519), GHSA-vp88-798v-h67f (ECH: buffered app data sent after rejection). This product: ureq with `default-features = false, features = ["rustls"]`, rustls linked to **ring** (not aws-lc-rs), no `brotli` feature in the lock, no ECH. So brotli and ECH do not apply. The Debug leak needs a custom `ClientSessionStore` that prints `Debug`. The PQ-downgrade advisory applies only if MLKEM shares are offered; ring’s usual groups are classical. Still: the lock is not on the patched crate, and nothing here runs `cargo audit`.

Grade: ملاحظة

### B6-2 · Flutter lock has older transitive zip/image crates; `http` rides in with file_selector

What I did: `flutter pub outdated` in `apps/flutter_app` of the copy.

What should happen: the shipped app’s lock either current or justified. No HTTP stack in the UI tree unless it is used.

What happened: every *direct* dependency is current. Six locked transitives can move: `archive 4.3.0` → 4.5.2, `image 4.10.1` → 4.12.0 (both via `pdf`), plus plugin/dev noise. `http 1.6.0` is in `pubspec.lock` as a transitive of `file_selector_platform_interface`. `pubspec.yaml` does not name it; `lib/` does not import it; G5 still passes. The Linux file picker is the GTK plugin, not Dart `http`.

Grade: ملاحظة

### B6-3 · Installed README names a different mailbox than the site

What I did: read `/home/monopeaks/.local/opt/zprivacy/README.txt` against `site/en/index.html` and `site/en/privacy/`.

What should happen: the address a stranger writes to is one address.

What happened: the archive says `yourvoices.app@mono-peak.com`. The site and the privacy page say `zprivacy@mono-peak.com`. First-run does not print either. Two public mailboxes for one product.

Grade: ملاحظة

### B6-4 · Dart snapshot still names the repo path, after home was remapped

What I did: `strings` on the installed `lib/libapp.so`, `libz_bridge.so`, `zprivacy`.

What should happen: the archive names no builder and no tree. `package_linux.sh` remaps `$HOME` to a same-length `/build/z…` and strips ELF.

What happened: no `/home/monopeaks`, no `/home/`, no fixtures, no `sk-`, no private keys. All four ELFs are `stripped` (`file(1)`). `libapp.so` still contains:

`file:///build/zzzzzzzz/mono-privacy/apps/flutter_app/.dart_tool/flutter_build/dart_plugin_registrant.dart`

The user name is gone; the repository folder `mono-privacy` is not.

Grade: ملاحظة

### B6-5 · Panic across the FRB bridge is policy plus a generated unwrap, not a catch_unwind in the wrapper

What I did: read `bridges/native/z_bridge/src/api/core.rs`, `frb_generated.rs`, gate G7, workspace clippy.

What should happen: G7 — every contract function returns `ApiResult` (plain: `core_version`, `init_app`). A panic in Rust must not kill the isolate with a secret on the stack.

What happened: `init_app` calls `flutter_rust_bridge::setup_default_user_utils()` (FRB’s panic hook + logging). Workspace `panic = "deny"`, `unwrap_used = "deny"` on product code. `Secret` / `RevealedValue` `Debug` print `[REDACTED]` (G11). There is **no** `catch_unwind` in `z_bridge/src`. Generated `frb_generated.rs` uses `.unwrap()` on the codec (malformed FFI → panic). A panic then depends on FRB’s default hook, not on a wrapper this repo owns.

Grade: ملاحظة

---

## What held

### cargo audit / RUSTSEC (measured without the tool)

| crate | lock | notes |
|---|---|---|
| rustls | 0.23.45 | 0.23.45 is the GHSA-2mjx handshake-alignment fix (0.23.13–0.23.44). 0.23.46 is the next four. |
| rustls-webpki | 0.103.15 | RUSTSEC-2026-0104 patched in ≥0.103.13; RUSTSEC-2026-0049 in ≥0.103.10. |
| ring | 0.17.14 | rustls crypto provider in this lock. |

### Installed archive contents

```
zprivacy                    ELF pie, stripped, 19136 bytes (runner)
lib/libz_bridge.so          ELF, stripped, 11919200 bytes
lib/libapp.so               ELF, stripped, 8274832 bytes
lib/libflutter_linux_gtk.so ELF, stripped
lib/libfile_selector_linux_plugin.so
data/flutter_assets/        brand pngs, DejaVuSans.ttf, MaterialIcons, shaders
icons/                      16…512 png
BUILD-INFO.txt LICENSE README.txt third-party/ zprivacy.desktop install-shortcut.sh
```

No test fixtures, no `Mahnung_Feldmann`, no `ألماني`, no `sk-` keys, no `/home/monopeaks`. `Feldmann` / `Sommer` / `Markus` / `Katrin` occur in `libz_bridge.so` as rows of the shipped `de_names_v2.csv` (Wikidata / city registers), twice (two embeddings of the bank). `Lindenau`, `Stadtwerke`, `Gartenstra`, `Mahnung` are absent.

`package_linux.sh` sets `--remap-path-prefix` for cargo/registry/rustup/this tree and `strip --strip-unneeded` on every ELF. `[profile.release] strip = "symbols"`.

### Provider API key (G8 / G11)

- Enters only at `connect_provider(…, credential: String, …)` and the vault passphrase doors.
- Never returned. `ProviderRow` has `connected`, `session_only`, `base_url`, `model` — no credential field. Gate G8 forbids `key`/`secret`/`seed` in any public signature.
- Vault open → sealed in `vault.zv` with a purpose-derived key (`Purpose::Provider`), not as UTF-8 inside the decrypted body (`vault/format.rs` test `a_credential_is_ciphertext_even_inside_the_decrypted_body`).
- Vault locked → RAM for this run, `session_only: true`. No third home. Not in `settings.zcfg`.
- Probe wrote `sk-probe-not-a-real-provider-key-0001` into an open vault, locked, searched `vault.zv` / `settings.zcfg` / `*.zs` in UTF-8 and UTF-16: no hit.

### Panic / secrets in logs

G11: `Secret` Debug/Display are `[REDACTED]`. `RevealedValue` Debug redacts `value`. `EntityRow.label` likewise. Product clippy denies `panic!` / `unwrap`.

---

## Coverage checklist

- [x] `cargo audit` — not installed; Cargo.lock vs rustls/RUSTSEC by hand
- [x] `flutter pub outdated` in `apps/flutter_app` of the copy
- [x] Installed archive: no fixtures, no `/home/monopeaks`, no keys
- [x] Stripped ELFs (`file`, no `.symtab` / `.debug` in `readelf -S`)
- [x] Panic across FRB: G7 `ApiResult`, FRB default utils, generated unwrap, no `catch_unwind` in wrapper
- [x] Where the provider API key is stored (G8/G11): sealed vault or session RAM, never zcfg, never a getter
- [x] No product source written

# B6 — build / distribution on 2b4fad9

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**This review did not rebuild the Linux archive.** The installed binary at `/home/monopeaks/.local/opt/zprivacy` is still `84832a0`. Path-leak ن9 is **NOT TESTED** on this commit's archive. Source of `scripts/package_linux.sh` was read.

`cargo-audit`: **absent** on this machine (`which cargo-audit` empty). Product lock vs rustls/RUSTSEC by hand.

`flutter pub outdated --no-dev-dependencies` was run on a **copy** of `pubspec.yaml` + `pubspec.lock` under `scratch/b567/pub` with a dummy `z_bridge` at the locked version `0.0.1`. The worktree lockfiles were not written. Log: `logs/b567/pub-outdated.txt`.

---

## Defects

### B6-1 · NOTE — rustls still 0.23.45, one patch behind 0.23.46

What I did: read `/home/monopeaks/z-attack-2b4fad9/Cargo.lock`. crates.io latest stable rustls is **0.23.46** (2026-10-14). `cargo-audit` is not installed.

What should happen: a tree merged 2026-10-19 either sits on 0.23.46 or names why it does not. CI would run `cargo audit`.

What happened: product lock is still `rustls 0.23.45`, `rustls-webpki 0.103.15`, `ring 0.17.14`. 0.23.46 patches GHSA-h2v8-394m-p7vv (brotli 1 GiB alloc), GHSA-c8m5-c952-6cm4 (Debug of session values prints TLS secrets), GHSA-w44r-93j7-qv28 (unauthenticated ServerHello can drop later connections to classical X25519), GHSA-vp88-798v-h67f (ECH: buffered app data sent after rejection). This product: ureq with rustls, crypto provider **ring**, no brotli feature in the lock, no ECH. Brotli and ECH do not apply. The Debug leak needs a custom `ClientSessionStore` that prints `Debug`. The PQ-downgrade advisory applies if MLKEM shares are offered; ring's usual groups are classical. Still: the lock is not on the patched crate, and nothing here runs `cargo audit`.

(The probes' own `Cargo.lock` resolved rustls 0.23.46 because that package is not the product lock. B6 measures the product.)

Grade: ملاحظة (ن7)

### B6-2 · NOTE — Flutter lock has older transitive zip/image crates; `http` still rides in with file_selector

What I did: `flutter pub outdated` on the copy. Direct dependencies: only `intl *0.20.2` vs latest `0.20.3` (not upgradable/resolvable in this SDK pin). Three upgradable transitives locked older: `archive 4.3.0` → 4.5.2, `image 4.10.1` → 4.12.0, `clock 1.1.2` → 1.1.3. `http 1.6.0` is current (latest 1.6.0) and still a transitive of `file_selector_platform_interface`. `pubspec.yaml` does not name it; G5 still the same story. Linux picker is GTK, not Dart `http`.

Grade: ملاحظة

### B6-3 · NOTE — packaging README mailbox still disagrees with the site

What I did: `packaging/linux/README.txt` vs `site/en/index.html` and `site/en/privacy/`. Root `README.md` too.

What should happen: one public address.

What happened: archive and root README: `yourvoices.app@mono-peak.com`. Site and privacy page: `zprivacy@mono-peak.com`. First-run still prints neither. Same split as 84832a0.

Grade: ملاحظة (ن8)

### B6-4 · NOTE — ن9 NOT TESTED on this commit's archive; source still remaps `$HOME` only

What I did: read `scripts/package_linux.sh`. Did not run it. Did not `strings` the installed `84832a0` tree as if it were this commit.

What the script does on this commit:

- `RUSTFLAGS --remap-path-prefix` for `$HOME/.cargo/registry/src` → `/crates`, rustup → `/rust`, pub-cache → `/pub`, **`$ROOT` → `/zprivacy`**.
- After copy: `strip --strip-unneeded` on every ELF.
- Python rewrite: every byte string equal to `$HOME` replaced in-place with `/build/` + `z` padding of the same length.

The Dart snapshot path is still rewritten only for `$HOME`. A builder whose tree is `$HOME/mono-privacy/...` still leaves the folder name `mono-privacy` after the rewrite (`file:///build/zzzzzzzz/mono-privacy/apps/flutter_app/.dart_tool/...` on 84832a0). This commit's `$ROOT` remap is for rustc, not for the Dart snapshot. **Installed-binary path-leak on 2b4fad9: NOT TESTED.**

Grade: ملاحظة (source inspected; archive not built)

### B6-5 · NOTE — panic across FRB is still policy plus generated unwrap, not `catch_unwind` in the wrapper

What I did: `bridges/native/z_bridge/src/api/core.rs`, grep `catch_unwind` in `z_bridge/src` (zero hits), generated `frb_generated.rs`.

What happened: `init_app` still calls `flutter_rust_bridge::setup_default_user_utils()`. No `catch_unwind` in the wrapper this repo owns. Generated codec still `.unwrap()`. Same as 84832a0.

Grade: ملاحظة (ن10)

---

## What held

| crate | product lock | notes |
|---|---|---|
| rustls | 0.23.45 | 0.23.46 is the four-advisory patch, 2026-10-14 |
| rustls-webpki | 0.103.15 | RUSTSEC-2026-0104 patched ≥0.103.13 |
| ring | 0.17.14 | rustls crypto provider in this lock |

Packaging README language: «The interface is English. The detection packs are German, Swedish and English.» Packs sentence is true. Interface sentence is stale now that German is a written list (see A1-2).

---

## Coverage checklist

- [x] `cargo audit` — not installed; Cargo.lock vs rustls/RUSTSEC by hand
- [x] `flutter pub outdated` on a copy of the lock; worktree lockfiles unchanged
- [ ] Installed archive of **this** commit — not built; ن9 NOT TESTED
- [x] `package_linux.sh` HOME remap + ROOT rustc remap + in-place `$HOME` rewrite
- [x] Panic across FRB: G7 `ApiResult`, FRB default utils, generated unwrap, no `catch_unwind`
- [x] No product source written

**Grades here:** مانع 0 · خطير 0 · ملاحظة 5

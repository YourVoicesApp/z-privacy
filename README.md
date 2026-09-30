# Z Privacy

Protect what you send to AI. Restore it on your device.

Z Privacy sits between you and an AI provider. You bring in a document, it is
scanned before you read it, and every sensitive value is replaced by a token.
You see the exact text that will leave the machine before it leaves. The
answer comes back with the tokens still in it, and the real values are put back
here, locally.

> Z Privacy minimizes the sensitive content you send. **It does not make you
> anonymous to the AI provider.** The provider still sees the ordinary facts of
> a connection — your address, the time, the model.

## What stays, and what leaves

```text
ORIGINAL — LOCAL ONLY          SAFE — AI WILL RECEIVE
your document, unchanged       the request itself, not a preview of it
never sent                     the only thing that leaves
```

* Your originals stay on this device unless you explicitly export restored text.
* The vault is one encrypted file, written here and nowhere else.
* No account, and no Z Privacy server for your documents.
* Once you copy restored text, the clipboard is outside Z Privacy.

The path a person walks:

```text
Import → Scan → Review → Protect → Review what will leave → AI → Restore
```

## Status

**V1.** Linux x86_64 desktop. The interface is English; the detection packs are
German and English. Private beta.

There is no Windows or macOS build: the app has only a `linux/` runner, and no
gate has ever run on another platform. A port is a platform, not a repackaging.

The site that carries the release is built in `site/` and is served at
z-privacy.com — one static page in English, German and Arabic, no JavaScript,
no analytics, and no third-party request.

## Build from source

Needs Rust ≥ 1.85, Flutter with Dart SDK ≥ 3.12.2, and the GTK3 development
headers. Built and tested with rustc 1.98.0 and Flutter 3.44.2 on Linux
x86_64.

```bash
cd apps/flutter_app
flutter build linux --release      # build/linux/x64/release/bundle/
```

The Rust core is built for you by the Flutter build. To work on the core alone:

```bash
cargo test --workspace --features fake_provider
```

`fake_provider` compiles an echo provider that exists only in a build made for
the tests, so the network path can be exercised without a network.

Changing `z_core/src/api.rs` invalidates the generated bridge. After it:

```bash
python3 scripts/gen_mirrors.py
cd apps/flutter_app && flutter_rust_bridge_codegen generate
flutter build linux --debug        # the Dart tests need this library
```

## How this is held to account

The promise of a privacy product is not kept by intention. It is kept by
things that fail the build.

```bash
bash scripts/gates.sh              # exit status is the verdict
```

108 checks, and none of them reviewed by eye. 32 are the gates themselves —
one HTTP client in one package, no send function that accepts text, every
contract function returning a typed result, no key in any signature, nothing in
the core that prints, every type holding the user's words redacting its own
`Debug`, no filesystem access outside the vault and the settings file, and the
whole contract called from Dart without a panic. The other 76 check that named
tests still exist, because a green suite proves nothing if the test that held
an invariant was quietly deleted with it. What each gate defends is written in
`docs/SECURITY_INVARIANTS.md`.

Under them: 251 Rust tests and 62 Dart tests. The Dart ones pump the
real screens against the real library and compare what is drawn with what the
core says when asked directly — because the rule for the interface is that no
number on screen is invented in Dart.

And beyond both, the part no compiler reaches: whether a person believes what
the app tells them. `docs/HUMAN_RUN.md` is the record of walking the product
as a human, four stages, no fixing during the walk, recording only
`EXPOSURE · LIE · MISSING · FRICTION`. Nine lies it caught are listed there
with the tests that now make each one impossible.

## Layout

```text
z_core/                 the core, in Rust — scanning, tokens, vault, providers
  src/                  13,568 lines
  tests/                 6,063 lines
bridges/native/z_bridge/ the FFI bridge; its mirrors are generated, not written
apps/flutter_app/        the Linux desktop app
  lib/                   9,527 lines of Dart
scripts/gates.sh         the gates
scripts/gen_mirrors.py   regenerates the bridge mirrors from the contract
docs/                    the working record, including the human run
boards/                  the design boards the product was drawn on
redteam/                 the attacker, kept as it was written and guarded by G21
site/                    z-privacy.com, static, three languages
```

## Licence

Apache License 2.0 — the full text is in [`LICENSE`](LICENSE).

Z Privacy ships and serves other people's work: the Flutter engine under
BSD-3-Clause, 142 Rust crates under their own licences, and four typefaces
under the SIL Open Font License 1.1. Every one is listed with its notice in
`site/third-party/`.

## Publisher

Faruk AB — Aktiebolag (AB), Sweden. Org.nr 559473-3494.
Hotellgatan 3, 311 31 Falkenberg, Sweden.
Contact: yourvoices.app@mono-peak.com

© 2026 Faruk AB. Licensed under the Apache License 2.0.

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

## Download

The first public beta was published on 25 October 2026, and Arabic joined it
the same day. Download it from
https://z-privacy.com/en/download/, or from this repository's
[Releases](https://github.com/YourVoicesApp/z-privacy/releases).

| File | SHA-256 |
|---|---|
| `zprivacy-v1-linux-x86_64.tar.gz` — Linux x86_64 (GTK3) | `b180bc49898fb1aa7f49b449ee756ab72cbaf16682a488f10bc27893b361ffe6` |
| `zprivacy-v1-windows-x86_64-setup.exe` — Windows 10/11 x86_64 | `ba56b81b7484ae233274fdea00630ddc50f2d802d8ff017d54768119fcfc46d9` |

Both were built from `4920398`. The Windows installer is not signed yet, so
Windows shows «Windows protected your PC» the first time: «More info», then
«Run anyway». The fingerprint is what says the file is ours.

## What stays, and what leaves

```text
ORIGINAL — LOCAL ONLY          SAFE — AI WILL RECEIVE
your document, unchanged       the request itself, not a preview of it
never sent                     the only thing that leaves
```

* Your originals stay on this device unless you explicitly export restored text.
* Your names live in one encrypted vault file, written here and nowhere else.
  Beside it Z Privacy writes each session's own encrypted file and your
  settings — `docs/CLAIMS.md` (C-06) names every one of them. Beside those,
  Z Privacy writes only what you ask for by name: a protected copy, and — since
  24 October 2026 — the restored document as an ordinary PDF where you choose
  it, which holds your values in the clear and claims no protection.
* No account, and no Z Privacy server for your documents.
* Once you copy restored text, the clipboard is outside Z Privacy.

The path a person walks:

```text
Import → Scan → Review → Protect → Choose who answers → AI → Restore
```

## Status

**V1, public beta** since 25 October 2026, for Linux x86_64 and Windows 10/11
x86_64. Every sentence the interface shows is gathered
in one list, and no screen writes one of its own: the count is
`python3 scripts/check_the_one_list.py`, where it is measured rather than
remembered — C-15 in `docs/CLAIMS.md` is the one other place it is written
down, and a gate holds that place to this command. The interface is English,
German, Swedish and Arabic: the Swedish words were written on 23 October 2026
and the Arabic words on 25 October 2026, and the first screen offers both
because the gates measure that their sentences are not the English ones —
**neither has been read by a native speaker yet**, and that review is a round
of its own. The Arabic is measured the same way as the Swedish: 696 of 702
values say something other than the English, and the six that do not are names
and product spellings the law allows in every language. **Arabic is the first
language here that is read right to left**, so choosing it mirrors every
screen; the document keeps its own direction, which is the text's and not the
interface's. The detection packs are German, English, Swedish and Arabic.

Windows is built from git by `.github/workflows/windows-core.yml`, by hand from
the Actions tab. The core's tests, the nine storage contracts, the one-writer
measurement and the whole Dart suite run there, and the job writes a zip, an
installer and an MSIX. The published installer comes from run 40207163367, on
the same commit as the Linux archive. The MSIX is not distributed: it does not
yet carry every file the installer does, and the workflow says so. What is
still Linux's alone is `docs/MEASURED_ON_LINUX.txt`, the numbers every gate run
is compared against: no Windows run has written numbers of its own into it.
There is no macOS, iOS or Android build. A port is a platform, not a
repackaging.

The site that carries the release is built in `site/` and is served at
z-privacy.com: static pages in English, German and Arabic, no JavaScript,
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

None of the checks is reviewed by eye. Some are the gates themselves: one HTTP
client in one package, no send function that accepts text, every contract
function returning a typed result, no key in any signature, nothing in the core
that prints, every type holding the user's words redacting its own `Debug`, no
filesystem access outside the files the app names, and the whole contract
called from Dart without a panic. The rest check that named tests still exist,
because a green suite proves nothing if the test that held an invariant was
quietly deleted with it. What each gate defends is written in
`docs/SECURITY_INVARIANTS.md`.

The numbers are not typed here, because a typed number goes stale: they live in
`docs/MEASURED_ON_LINUX.txt`, written by the hand that merges and compared
against every run. At the first public release they read 643 checks, 844 Rust
tests and 445 Dart tests, with 0 failed. The Dart tests pump the
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
bridges/native/z_bridge/ the FFI bridge; its mirrors are generated, not written
apps/flutter_app/        the desktop app, in Flutter (Linux and Windows)
scripts/gates.sh         the gates
scripts/gen_mirrors.py   regenerates the bridge mirrors from the contract
docs/                    the working record, including the human run
boards/                  the design boards the product was drawn on
redteam/                 the attacker, kept as it was written and guarded by G21
site/                    z-privacy.com, static, three languages
```

## Licence

Apache License 2.0 — the full text is in [`LICENSE`](LICENSE). Use it as you
like, in a company or alone, with nobody to ask: the one condition is the one
the licence already carries in [`NOTICE`](NOTICE) — a product built on this code
says so where it lists what it is built on (Apache 2.0 §4(d)). That binds a
product’s notices, its documentation or its «About» screen; it does not bind
advertising, which is said here because it was asked and answered.

Z Privacy ships and serves other people's work: the Flutter engine under
BSD-3-Clause, 142 Rust crates under their own licences, and four typefaces
under the SIL Open Font License 1.1. Every one is listed with its notice in
`site/third-party/`.

## Publisher

Faruk AB — Aktiebolag (AB), Sweden. Org.nr 559473-3494.
Hotellgatan 3, 311 31 Falkenberg, Sweden.
Contact: zprivacy@mono-peak.com

© 2026 Faruk AB. Licensed under the Apache License 2.0, and attributed as
[`NOTICE`](NOTICE) asks.

# tests/cycle — comparison copy only

Tools for a later side-by-side cycle. They live only in this folder. They do
not change application code.

This copy is `/home/monopeaks/mono-privacy-comparison-20261013-022102` on
branch `comparison/local-cycle`. Do not run them against `~/mono-privacy`.

## What the app actually speaks

Z Privacy is a **Linux desktop app** (Flutter + `z_core` over FFI). It is not
an HTTP service.

| Assumption | Actual interface |
|---|---|
| `POST /analyze` | **Does not exist.** Do not invent it. |
| `POST /pdf` | Saving a protected PDF is a UI action; default folder `$HOME/Documents/zprivacy`. |
| Provider | OpenAI-compatible `POST {base}/v1/chat/completions`, user-agent `z-privacy`. |
| Tokens | `__Z_<namespace>_<KIND>_<tail>__` (see `z_core/src/tokens.rs`), not `[FULLNAME_1]`. |
| Loopback | Literal IP only (`http://127.0.0.1:8081`). `localhost` is refused. Empty key is allowed on loopback. |

How a person runs it (after isolation, not before):

```bash
# isolated — use this copy's wrapper, never a bare flutter run
bash tests/cycle/run_app_isolated.sh
```

The wrapper executes the already-built release bundle:

`apps/flutter_app/build/linux/x64/release/bundle/zprivacy`

Path a person walks: Import → Scan → Review → Protect → Review what will leave → Connect → Send → Restore.

## Isolation (required before any run)

The original install already has files at:

- `~/.local/share/zprivacy/vault.zv`
- `~/.local/share/zprivacy/settings.zcfg`
- `~/.local/share/zprivacy/sessions/*.zs`
- `~/Documents/zprivacy/*.pdf`

The core reads:

- data: `$XDG_DATA_HOME/zprivacy`, else `$HOME/.local/share/zprivacy`
- PDFs: `$HOME/Documents/zprivacy`

`env.sh` remaps `HOME` and `XDG_DATA_HOME` into `tests/cycle/sandbox/`. Check:

```bash
bash tests/cycle/isolation_check.sh
bash tests/cycle/run_app_isolated.sh --dry-run
```

`run_cycle.sh` does **not** start the app.

Plugin symlink `linux/flutter/ephemeral/.plugin_symlinks/z_bridge` was retargeted
from the original tree to this copy's `rust_builder` (gitignored ephemeral).
`file_selector_*` still points at `~/.pub-cache` (shared package, not vault data).
`redteam/2026-09-28/original/Cargo.toml` still names `/home/monopeaks/mono-privacy/z_core`;
do not run that harness from here.

## Automated part (mock only)

```bash
bash tests/cycle/run_cycle.sh
bash tests/cycle/check_results.sh
```

The **found** 20:07 bundle was not HEAD. This copy was rebuilt at 02:39.
See `BUNDLE_IDENTITY.md`. Attribute a UI cycle to product `d882c5f` /
stamp `61fa27b`, never to the origin 20:07 binary.

While `capture_server/app.py` is bound to `127.0.0.1:8081` for the isolated
app, do not run `run_cycle.sh` — it would reset the request log.

UI steps for the real app (not automated): `MANUAL_UI.md`.

This starts the capture server on `127.0.0.1:8081`, posts one leaky
chat-completions body, one tokenized body, and one `stream: true` body, and checks that:

- raw names/IBANs are logged as leaks and never copied into the reply
- a confirmed `__Z_…__` token is the only thing substituted for `{{ph}}`
- `stream: true` is answered as `text/event-stream` (Z itself sends `stream: false`)

Stdlib Python. No pip. No Docker. No real provider.

## Manual once the app is isolated

These need the desktop UI. The tools will not pretend the app has HTTP
export/import.

1. Start capture: `python3 tests/cycle/capture_server/app.py`
2. Start the app: `bash tests/cycle/run_app_isolated.sh`
3. First run in the sandbox (empty vault).
4. Import `tests/cycle/fixtures/synthetic.txt` (invented names; not a client).
5. Protect. Confirm the safe column holds `__Z_…__` tokens, not Alice / the IBAN.
6. Settings → AI: Connect OpenAI-compatible to `http://127.0.0.1:8081`, empty key.
7. Send. Inspect `GET http://127.0.0.1:8081/requests`:
   - fail if the body contains `Alice Jensen` or the IBAN
   - pass if it contains tokens and the user-agent is `z-privacy`
8. Restore locally; the sandbox UI should show the invented names again.
9. Session persistence: lock/quit/reopen **this** isolated process; open the
   same sandbox session. Do not touch `~/.local/share/zprivacy`.
10. Wrong-session: create a second vault/session in the sandbox and open the
    first session's protected PDF without its mapping. Expect no restore of
    the first session's values.

Alias-joining (Alice / Alicia as one person, two people both named Alice
Jensen) is also UI-only.

Rizzo and Secret Guard are other products. Their `/analyze` URLs are probed
and skipped when absent. This folder does not start them.

## Dummy key

Use an empty key on loopback, or the string `cycle-dummy-key` if a field
refuses to stay empty. Never a real provider credential.

# Last run

## Capture server (tools only) — PASS

`bash tests/cycle/run_cycle.sh` earlier, then a live probe of the isolated
capture on `127.0.0.1:8081` (2026-10-13 02:44).

- `POST /v1/chat/completions` `stream: false` → `application/json` with
  `choices[0].message.content` (the field `z_core` `content_of` reads)
- `stream: true` → `text/event-stream` with `data:` chunks, `delta.content`,
  and `[DONE]`. Z itself still sends `stream: false`.
- leaky body: raw name/IBAN logged, never copied into the reply
- `/analyze` on 5005/5006/5007: **SKIPPED**
- after the probe, `POST /reset` so the UI cycle starts with `[]`

Do not run `run_cycle.sh` while this capture is bound to 8081: it would
`/prepare` and clear the log the app is about to fill.

## Desktop app — not yet a cycle PASS

Isolated process is running (pid was 111995 at this writing):

- wrapper: `bash tests/cycle/run_app_isolated.sh`
- bundle: rebuilt 02:39, hash `a9b9f4e3…`, stamp `z_core 0.1.0 · 2026-10-13 · 61fa27b`
- `HOME` / `XDG_DATA_HOME` inside `tests/cycle/sandbox/`
- sandbox has `settings.zcfg` (`first_run_completed=true`, `ui_language=en`)
  and **no** `vault.zv`
- AT-SPI tree is the vault form: Passphrase, Confirm passphrase, Create the vault
- original `~/.local/share/zprivacy/vault.zv` still size 742 mtime 1791828743
- `GET /requests` is `[]` — the app has not sent yet

AT-SPI can *read* the Flutter tree. It cannot drive it: `set_text_contents`
returns true but the match line never appears, extents time out, and there is
no Wayland click/type tool. Cycle 1–2 stay on `MANUAL_UI.md`.

Rizzo and Secret Guard were not started.

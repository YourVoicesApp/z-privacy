# Last run

## Capture server (tools only) — PASS

Live capture restarted on `127.0.0.1:8081` after the echo-all-tokens fix
(pid 190902). Mixed probe: both tokens echoed, originals stripped to
`<LEFT_CLEAR>`, `leftover_clear` recorded, then `POST /reset` → `[]`.

- `POST /v1/chat/completions` `stream: false` → `application/json` with
  `choices[0].message.content` (the field `z_core` `content_of` reads)
- `stream: true` → `text/event-stream` with `data:` chunks, `delta.content`,
  and `[DONE]`. Z itself still sends `stream: false`.
- leaky body: raw name/IBAN logged, never copied into the reply
- `/analyze` on 5005/5006/5007: **SKIPPED**
- after the probe, `POST /reset` so the UI cycle starts with `[]`

Default reply (after the tool fix): echo every token in the last user
message; strip leftover clear; record `leftover_clear`. Do not run
`run_cycle.sh` while this capture is bound to 8081: it would occupy the
port and reset the log the app is about to fill.

## Desktop app — textual cycle done; PDF reopen waiting on Open

Isolated process pid **195385**: stamp `z_core 0.1.0 · 2026-10-13 · 61fa27b`.
Sandbox vault `vault.zv` 992 bytes 03:08, session `sessions/1.zs` (title
**الاختبار الأول**, namespace `1F52`), 1 identity / 19 values, 0 profiles.
Protected PDF already under sandbox `Documents/zprivacy/` (outside save).
`GET /requests` is `[]` — Send to Local AI has not hit 8081.
The seven-token restore was Copy Protected / Paste AI answer, a textual result.

Word-protection scope, document save location, and session restore key are
recorded as three facts. Restore after PDF reopen is scored with the matching
session key. Scope buttons are not used to predict restore.

**Z test expansion stopped (2026-10-13).** The deliverable is the three-axis
study in `Z_COMPARISON.md` (original ten projects). PDF reopen and further
tooling are out of that delivery. Translation of the study is a later task.

Rizzo and Secret Guard were not started. Secret Guard remains
github.com/luochen1990/secret-guard. Lead measurement 13 Oct 2026 on
`d882c5f`: Always/Profile persist in ValueRecord and heal when the same
document is reopened; Once/Conversation die with process death (TokenStore
RAM). Probe: 3 protections → cold restart 3 unresolved → same document
reopened 2 unresolved. Session key alone is insufficient (confirmed).
Selection and returning-document axes added for the original ten.
Returning a different exported PDF with one placeholder is not found as a
product path in any of the ten, including Z. Comparison sheet:
`Z_COMPARISON.md`.

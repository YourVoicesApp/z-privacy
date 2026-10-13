# Last mock-cycle run

`bash tests/cycle/run_cycle.sh` → capture **PASS**, app **not** started.

- leaky POST `/v1/chat/completions`: 1 IBAN + 3 name hits logged; reply did not echo them
- tokenized POST (`stream: false`, Z's actual wire): placeholder substituted; 0 leaks
- tokenized POST `stream: true`: `text/event-stream` with `data:` chunks and `[DONE]`; tokens only
- `http://127.0.0.1:5005/analyze` (and 5006, 5007): **SKIPPED**
- original `~/.local/share/zprivacy` and `~/Documents/zprivacy` not used
- no push, no real provider, dummy values only

The found desktop bundle is **not HEAD**. See `BUNDLE_IDENTITY.md`.

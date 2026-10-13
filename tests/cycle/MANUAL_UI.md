# Precise UI steps — isolated Z cycle

The desktop app has no `/analyze` HTTP API. These steps are the product as a
person meets it. Dummy values only. Isolated process only.

Isolation:

```bash
python3 tests/cycle/capture_server/app.py
bash tests/cycle/run_app_isolated.sh
```

Confirm the window is the isolated copy: first run (empty sandbox), not the
original vault. Original data stays in `~/.local/share/zprivacy` — do not open
or unlock that.

Passphrase for the **sandbox vault only**: `cycle-dummy-pass-not-real`

**Where the isolated window is now (2026-10-13):** language is already English
and first-run is marked complete. AT-SPI shows **Z Vault** / **There is no
vault yet** / passphrase fields / **Create the vault**. Start at step 2.
Do not click an original Z Privacy window if one is also open.

## Cycle 1 — import → scan → review → protect → send → restore

1. First run (already done in this sandbox): **English**, then **Start**, then **Create a vault**.
2. Passphrase / Confirm passphrase: the dummy above. **Create the vault**.
3. Home composer (`Write or paste your text here…`): paste the whole of
   `tests/cycle/fixtures/synthetic.txt`.
4. Press **Open and scan** (this is import+scan of typed text; the paperclip
   file picker is the other door and is not required).
5. Review the two columns. Protect any row that still “needs your word”
   (Always / This conversation / Leave). Send stays locked until those are
   answered. Record how many were automatic vs asked.
6. Name the session when asked (`This conversation has no session yet` /
   `What is this one about?`): `cycle-one`.
7. Settings → **Local AI** (not Direct API):
   - Address: `http://127.0.0.1:8081` (not `localhost`, not `:11434`)
   - Model: `cycle-mock`
   - no key
   - **Connect**
8. Back to the document. Open **Review what will leave**.
9. Under Direct API / Local AI press **Send to Local AI**.
10. On the answer screen, switch **Restored**. Confirm Alice Jensen / Alicia
    Jensen / the IBAN are back locally.
11. Leave the app open. In another terminal:

```bash
curl -s http://127.0.0.1:8081/requests | python3 -m json.tool
```

Pass only if the captured body has `__Z_…__` tokens, user-agent `z-privacy`,
`stream: false`, and none of: `Alice Jensen`, `Alicia Jensen`,
`IT60X0542811101000000123456`.

## Cycle 2 — protected PDF, restart, right session, then a second session

12. Still in session `cycle-one`, **Review what will leave** → **Save as PDF**.
    Isolated path must be:
    `…/tests/cycle/sandbox/home/Documents/zprivacy/`
    If it writes under `~/Documents/zprivacy`, stop — isolation failed.
13. Quit **only** this isolated window. Do not quit any original Z Privacy.
14. Start again: `bash tests/cycle/run_app_isolated.sh`
15. Unlock with the same dummy passphrase. Open session **cycle-one**.
16. Import the PDF from step 12 (paperclip → that sandbox file). Confirm the
    tokens still restore under this session.
17. Settings → Sessions → **New session**, name `cycle-two`, **Begin**.
    Do not copy or export keys from cycle-one.
18. Import the **same** PDF again in cycle-two. Expected: the file’s tokens
    are not restored to Alice / the IBAN, because this session has its own
    key. Record what the app actually says.

Connect stays on loopback `127.0.0.1:8081`. Never a real provider.

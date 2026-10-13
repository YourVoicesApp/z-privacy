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

**Where the isolated window is now (2026-10-13, after restart):**
language English, vault open, session title **الاختبار الأول** (`sessions/1.zs`,
namespace `1F52`). Protected PDF already at
`tests/cycle/sandbox/home/Documents/zprivacy/text-protected-2026-10-13.pdf`.
Composer is empty. Capture `/requests` is unused for this PDF reopen.
A GTK **Open File** chooser is already standing on this isolated window.
Current folder is the app bundle; the file
`text-protected-2026-10-13.pdf` is in that list (same bytes as the sandbox
PDF). **Next required click is step 16.** Do not click an original
Z Privacy window if one is also open. Do not Cancel unless the chooser is
the wrong app.

## Cycle 1 — import → scan → review → protect → send → restore

1. First run (already done in this sandbox): **English**, then **Start**, then **Create a vault**.
2. Passphrase / Confirm passphrase: the dummy above. **Create the vault**.
3. Home composer (`Write or paste your text here…`): paste the whole of
   `tests/cycle/fixtures/synthetic.txt`. Use paste, not the paperclip.
4. Press **Open and scan** (this is import+scan of typed text; the paperclip
   file picker is the other door and is not required).
5. **Record findings before answering them.** Copy the banner
   `N protected automatically · M by you · K need your word · P normal`.
   For each of: Alice Jensen, Alicia Jensen, the second Alice Jensen, the
   IBAN, the email, the phone — write auto / asked / left clear.
   Alice and Alicia are **not** joined unless the app asks (alias / “new
   spelling” / one identity) and you answer. If it does not ask, leave them
   as two spellings.
   For a row that needs a word: **Protect** = this conversation;
   **Always** = vault, every later document. Keep at least one conversation
   value. One Always (for example the email) is enough to compare scopes in
   session two. Do not press Always on everything unless that is the case
   you want.
6. Name the session when asked (`This conversation has no session yet` /
   `What is this one about?`): `cycle-one`.
7. Settings → **Local AI** (not Direct API):
   - Address: `http://127.0.0.1:8081` (not `localhost`, not `:11434`)
   - Model: `cycle-mock`
   - no key
   - **Connect**
8. Back to the document. Open **Review what will leave**.
   **Screenshot the protected text** (what would leave) before any send.
9. Under Direct API / Local AI press **Send to Local AI**.
10. On the answer screen, switch **Restored**. **Screenshot the restored
    view.** Restore is scored only for tokens the mock actually echoed
    (the whole last user message when the request was already tokenised).
11. Leave the app open. In another terminal:

```bash
curl -s http://127.0.0.1:8081/requests | python3 -m json.tool
```

Pass only if the captured body has `__Z_…__` tokens, user-agent `z-privacy`,
`stream: false`, and none of: `Alice Jensen`, `Alicia Jensen`,
`IT60X0542811101000000123456`.

## Cycle 2 — protected PDF, restart, right session, then a second session

12. **Already done.** PDF:
    `…/tests/cycle/sandbox/home/Documents/zprivacy/text-protected-2026-10-13.pdf`
    Isolation held (origin `~/Documents/zprivacy` unchanged).
13. **Already done.** Isolated window was closed (this copy only).
14. **Already done.** Isolated app restarted (`run_app_isolated.sh`, pid 195385).
15. **Already done.** Vault unlocked; session **الاختبار الأول** is the open one.
    Dummy passphrase if a lock screen returns: `cycle-dummy-pass-not-real`.
16. **Do this now, one click.** In the isolated **Open File** chooser, select
    `text-protected-2026-10-13.pdf` (16.2 kB, already in the list) and press
    **Open**. Stay in **الاختبار الأول**. Do not create a new session yet.
    After it is open: say which tokens came back as original values, which
    stayed as `__Z_1F52_…__`, and which banner the Review/Tokens panel shows.
    Split by scope if the UI names one (Just here / This conversation /
    Remember everywhere). Leftover clear stays leftover; that is not a fail.
17. Settings → Sessions → **New session**. Name it (for example `cycle-two`).
    **Begin**. Do not copy or export keys from الاختبار الأول.
18. Import the **same** PDF again in the new session. Record restore **by
    scope**: conversation/once values should not come back; Always/vault
    values may. Unprotected text is still in the clear. Do not require every
    restore to fail.

Connect stays on loopback `127.0.0.1:8081`. Never a real provider.

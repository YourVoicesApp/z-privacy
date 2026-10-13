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

Three facts that stay separate. Do not infer one from a button that names
another.

1. **Word-protection scope** is about the **word**: where its protection is
   re-applied when it appears again, according to the choice the person makes
   (Just here / This conversation / Remember for a client / Remember
   everywhere). Protect and Always on a review row are this kind of choice.
2. **Document save location** is about the **document**: inside the app
   (session file) or outside it (exported PDF), according to the owner.
   Product decision: copies kept **in sessions** are the **protected** copies,
   not the clear copies, because session files live **outside the vault**.
3. **Session restore key** is what restores protected segments of a saved
   document. Record restore with **that session’s own key**. A scope button
   does not predict restore.

**Where the isolated window is now (2026-10-13):**
language English, vault open, Settings → **Sessions** is on screen, session
title **الاختبار الأول** (`sessions/1.zs`, namespace `1F52`, “the one you are
in”). Composer is empty. Protected PDF already at
`tests/cycle/sandbox/home/Documents/zprivacy/text-protected-2026-10-13.pdf`.
Capture `/requests` is unused for this PDF reopen.
A GTK **Open File** chooser is standing on this isolated window. Path bar is
inside **flutter_assets** (list shows `assets` / `fonts` / `shaders`). The
PDF is in the **bundle** folder of this copy, same bytes as the sandbox
file. **Next required click is step 16.** Do not click an original Z Privacy
window if one is also open. Do not Cancel unless the chooser is the wrong
app. Do not use Nautilus “Documents” (that is origin `~/Documents`). Do not
press Create / Rename on the chooser overlay.

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
   For a row that needs a word: **Protect** = this conversation (re-apply the
   word in this conversation); **Always** = vault, re-apply the word in later
   documents. Those buttons are **word-protection scope**. They are not a
   restore prediction and they are not a save-location choice. Keep at least
   one conversation-scoped word. One Always (for example the email) is enough
   to see later **re-apply** of that word. Do not press Always on everything
   unless that is the case you want.
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

## Cycle 2 — protected PDF, restart, matching session key, then a second session

12. **Already done.** PDF (the **outside** save of the protected document):
    `…/tests/cycle/sandbox/home/Documents/zprivacy/text-protected-2026-10-13.pdf`
    Isolation held (origin `~/Documents/zprivacy` unchanged).
13. **Already done.** Isolated window was closed (this copy only).
14. **Already done.** Isolated app restarted (`run_app_isolated.sh`, pid 195385).
15. **Already done.** Vault unlocked; session **الاختبار الأول** is the open one.
    Dummy passphrase if a lock screen returns: `cycle-dummy-pass-not-real`.
16. **Do this now, path then Open.** Isolated window only. In the **Open File**
    chooser, click the **bundle** segment on the path bar (it currently sits in
    `flutter_assets`). Select `text-protected-2026-10-13.pdf` (16.2 kB) and
    press **Open**. Stay in **الاختبار الأول**. Do not Begin a new session yet.

    After it is open, write three separate records:

    - **Word-protection scope** — only if the UI names a scope for a span
      (Just here / This conversation / Remember everywhere). That is where
      protection is re-applied when the word appears again.
    - **Document save** — this file is the **outside** copy. The copy a
      session keeps is the **protected** form, because sessions live outside
      the vault (`sessions/1.zs` beside `vault.zv`, not inside it).
    - **Restore with this session’s key** (`1.zs`, namespace `1F52`) — for
      each token: original value came back, stayed `__Z_1F52_…__`, or
      unresolved. Leftover clear stays leftover; that is not a fail.

    Do not score restore from Protect / Always / Just here.

17. Settings → Sessions → **New session**. Name it (for example `cycle-two`).
    **Begin**. Do not copy or export keys from الاختبار الأول.
18. Import the **same** PDF again in the new session. Record restore with
    **the new session’s key**. These are different events if they happen:

    - a `1F52` token resolved by the new key
    - a `1F52` token left unresolved
    - leftover **clear** text that stayed clear
    - leftover **clear** words that the vault **re-protected** as new tokens
      (that is word-scope re-apply, not restore of the PDF’s `1F52` names)

    Do not require every restore to fail. Do not require Always words to
    restore. Unprotected text is still in the clear.

Connect stays on loopback `127.0.0.1:8081`. Never a real provider.

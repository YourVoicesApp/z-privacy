# 122 — Z on the web, for trying it

**Owner of the paper:** the lead. The owner reviews the Arabic summary before anyone builds.
**Builders:** ed builds the core in the browser (part A). e2 builds the screen, the notice and the document (part B).
**Source:** rules 85 (a)–(h) and 86 in `docs/RULES_AR.md`. Read both first, then rules 62, 80 and 56.

## 0 · What is there today (measured by the lead, 12 Nov)

**The site:**
- `site/` in `~/z/mono-privacy` at `db4cb71` is the live site. The five front pages (`en ar de fr es`) are byte-identical to z-privacy.com.
- The site has no Swedish pages.
- `site/_headers` sends `Content-Security-Policy: default-src 'none'; …`. The site runs no script today.

**The app:**
- It builds for Linux and Windows only. `apps/flutter_app` has no `web/` folder.
- Six interface languages are offered (`language_list.dart:68`): `ar de en es fr sv`. **Swedish is already written:** `app_sv.arb` has the same 704 keys as English, 12 of them identical (names). The scanner has a Swedish pack (`z_core/src/scanner/packs/sv.rs`).
- Three files import `dart:io`: `main.dart`, `core/protected_pdf.dart` and `core/the_system_browser.dart`.
- The `pdf` package (^3.13.0) is already a dependency.

**The bridge and the core:**
- flutter_rust_bridge 2.13.0 exposes `z_core::api` whole.
- The doors the trial needs are already there: `import_text`, `scan`, `protect`, `unprotect`, `build_payload`, `payload_to_take_out`, `ingest_answer` and `restored_view`.
- The core can already hold a chat with no session open. The app's own sentence says that such an answer «disappears when you close the app».
- The network lives in one file, `z_core/src/providers/http.rs` (`ureq` with rustls; gate G1). The vault, `data_dir` and `secure_file` write files.
- `getrandom` is 0.3. On `wasm32` it needs its `wasm_js` backend.
- No `wasm32` target is installed on this machine.

## 1 · What the visitor sees

1. **The page opens on Z's chat** (rule 85).
   - A notice band is always visible, in the page's language: «This is a trial of Z on the web. Do not write important information here. For real use, install the app.» It links to the download page.
2. **Writing and protecting.** The visitor writes or pastes text. Z finds names and values, and a press protects or unprotects a word, as in the app.
3. **Copying.** «Copy protected» copies the protected version, and only that version. The visitor pastes it into any model they use.
4. **Pasting the answer.** The visitor pastes the model's answer into the page, and Z restores the real names.
5. **The document** (rule 85 (b)). A PDF is shown inside the page. It holds:
   - the visitor's text exactly as written, unprotected;
   - then the model's answer with the real names restored.

   It has two buttons:
   - **Copy**;
   - **Save to my device.** Under it is the sentence: «This copy is yours now. The site cannot erase it.»
6. **Leaving the page keeps nothing.**
   - There is no localStorage, IndexedDB, cookie or Cache Storage, and no service worker.
   - A reload starts empty.
7. **The providers and keys** (rule 85 (g)).
   - The list is drawn as in the app.
   - A press on any provider or key field shows at once: «Connecting to a model directly needs the app. Install it first.», with the download link.
   - No field takes a key.
8. **What is not in the trial:** the vault, conversations, kept documents, settings rooms, z-pdf, user lists and profiles.
   - The language follows the page's address (`/en/`, `/ar/`, `/sv/` and so on).
   - The scanner's language is chosen as in the app's head.

## 2 · Part A (ed): the core in the browser

1. **Measure first, and report before you build.**
   - Which modules of `z_core` must be cut for `wasm32-unknown-unknown`?
   - Does each door of §0 run there?
   - What size is the `.wasm`?
2. **A `web` build of the core, by Cargo features, not by a copy:**
   - no `providers` and no `ureq`;
   - no vault, files or `data_dir`;
   - `getrandom` with `wasm_js`;
   - a session held in memory only.

   The native build must not change by one byte of behaviour.
3. **A gate:**
   - The web build has no network code: G1 extended to the `web` feature set.
   - A build for `wasm32` with `ureq` reachable fails.
4. **Parity tests.** For the fixtures in each of the six languages, the web build and the native build give:
   - the same findings;
   - the same protected text;
   - the same restored text.

   Use fixtures only.

## 3 · Part B (e2): the screen

1. **A web target in the same app.**
   - Add `flutter create --platforms=web .`.
   - Add an entry point, `lib/main_web.dart`, that shows the chat and nothing else.
   - Keep `dart:io` out of the web build by conditional imports. Do not delete what the desktop uses.
2. **The trial PDF** is new, small and built in memory with the `pdf` package.
   - It is not a z-pdf, and it carries no token, no token map and no session number.
   - Arabic text in it reads right to left.
3. **New sentences:** the notice band, the key message, the Save sentence and the document's two headings.
   - Write them in all six `.arb` files.
   - Swedish and Arabic come from the lead. French and Spanish are marked as written with AI, as in paper 121.
4. **The browser enforces the promise.** The page is served with:
   - `connect-src 'self'`, so no host outside our own can be reached from the page;
   - `script-src 'self' 'wasm-unsafe-eval'`;
   - no `unsafe-inline`.

   Name any header Flutter's web renderer needs (COOP/COEP) and why.
5. **Tests:**
   - **Pin first:** a widget test that finds today's desktop shell in the web entry point (red against 85).
   - The full flow on fixtures, from write to the restored PDF.
   - The key press shows the message and opens no field.
   - Nothing is written to storage, checked in a browser test after a full flow.
   - The notice band is present on every screen state.
   - Right to left in Arabic.
6. **Shots:** English, Arabic and Swedish, at 390 px (phone) and at 1440 px.

## 4 · The preview (rule 86): nothing goes live

- The web build is written to `site-trial/`, a new folder next to `site/`. **`site/` is not touched**: it is the live site's tree.
- `scripts/preview_trial.sh` serves `site-trial/` on `127.0.0.1` only, with the same headers the server will send. The owner opens it on this machine.
- The owner reviews the trial on their machine and, after their word, publishes it themselves. Where the trial sits on the site is the owner's word (see §6).

## 5 · Gates

`scripts/gates.sh` all green, with counts. This includes the new web gate and the parity tests. Commit after the gates, never while they run. Do not push, and do not deploy.

**Order:**
1. ed measures and reports (§2.1).
2. ed builds part A.
3. e2 builds part B on it, and may start the screen against the doors' shapes.
4. The lead merges both and builds `site-trial/`.
5. The owner previews.

## 6 · Open, and settled

- ~~**The front page.**~~ **Settled by the owner, 12 Nov («نعم»):** the chat is the first screen, and what the front page says today (what Z is, download, guide) stays as it is, reached by one small line at the top of the trial.
- **The Swedish site pages, the privacy page among them** (rule 86 (e)): a separate paper, after this one.
- **Finnish:** a separate paper that measures name endings first.

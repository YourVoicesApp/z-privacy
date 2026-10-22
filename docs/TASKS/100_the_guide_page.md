# 100 — The guide page: how Z is used, written once, live before publishing day

**Owner, 22 October (rule 83, «نعم»):** «كتابة طريقة استخدام التطبيق، التحديد بضغطة» — and the site carries it **from now**, because the site is already open to people; only the download section waits for publishing day (rule 81).
**Base:** lead line at `78988fd` or later. Branch `feat/the-guide-page`. Builder: **e2** (site and glass are the second seat's). No push; the lead merges; the deploy is the owner's hand (rsync is classifier-blocked for the lead).
**Law:** one text in one place — the page on the site, a single line in the app's Settings that opens it in the browser; no second copy inside the app to maintain twice. Every control the page names must exist in the one list (686 sentences at `78988fd`), and the gate reads that. Screenshots come from fixtures (`Brief_Weber.txt`, `Mahnung_Keller.txt`), never a real document. Every sentence on the page is a claim; the outside-model claims review reads this page too (`CLAIMS_REVIEW_PROMPT.md` gains one line naming it).

## 1 · Where it lives

- `site/<lang>/guide/index.html` for `de`, `en`, `ar` — same skeleton, same `_headers`, same look as `privacy` and `terms`.
- The front page's «How it works» button points to `/<lang>/guide` (today it scrolls to the idea section; the idea section stays, the button goes to the page that shows the hands).
- In the app: one sentence in Settings → Language & rules (or beside the version line — e2 says which fits the room), through the one list: «How to use Z Privacy — z-privacy.com/guide», opening the system browser at the session's language. A dead link is a dead control (rule 35), so the link carries the language the app is in.

## 2 · The text (English source — the owner approves this before e2 builds; de and ar follow it)

Each quoted control below is a one-list sentence at `78988fd`, named by key in brackets so the gate can read the pairing. The gate reads the keys from a comment block in the page source, not the prose.

### Bring something in
Z is one screen. At the top you bring in a document — PDF, Word or text [`addADocumentPdfWordOrText`] — or write to the AI directly in the first part, with no document at all [`addADocumentOrWriteToTheAi`]. Nothing leaves this screen by itself: «Only the protected version is sent to AI through Z Privacy» [`onlyTheProtectedVersionIsSent`], and «Your original data stays on this device unless you explicitly copy restored content» [`originalDataStaysHere`].

### Read the two columns
The document stands twice: «Original — local only» [`originalLocalOnly`] and «Safe — AI will receive» [`safeAiWillReceive`]. What an AI would receive stands beside the original, word for word, before anything is sent [`whatAnAiWouldReceiveStandsHere`]. The footer counts what the scan found: protected automatically, waiting for your word, normal [`protectedAutomaticallyNeedYourWord`].

### Protect with one press
Press a word in the original and it is protected — the Safe column shows a token in its place, and the bar says «Protected as …» [`protectedAs`]. Press a protected word and «Undo protection» takes it back [`undoProtection`]; nothing was learned from pressing — you protected it here, and Undo takes it back [`nothingWasLearnedYouProtectedIt`]. Some words wait for your word rather than act alone: «Suggest: Z marks it and waits for your word» [`suggestMarksAndWaits`], and the footer says how many wait [`wordsWait`].

### Select with your hand
Drag across words to protect exactly what you chose — two clicks are one token, because a selection is your will. A hand selection never crosses a line break, and it never cuts into protected text: if it would, nothing changes and the bar says what it would have snapped to [`pressCutsIntoProtectedTextOne`]. In a table, press a value to protect the same cell in every held line [`pressAValueToProtectEveryHeldLine`].

### Ask, and bring the answer back
Choose who answers in the middle [`chooseWhoAnswersInTheMiddleFirst`]; write your question [`askAQuestionOrPasteALetter`]. Your request rides in the Safe column with its values replaced [`yourRequestValuesReplaced`]. «Copy the chat» puts the protected conversation on your clipboard [`copyTheChat`, `theChatIsOnYourClipboard`]; paste it to any AI you use; bring what it said back with «Add an answer» [`addAnAnswer`] and the names come back from your sessions [`namesCameBackFrom`]. The first answer opens the chat here, and every question after it carries what was already said [`theFirstAnswerOpensTheChatHere`].

### Keep a protected copy
«Save as PDF» writes a protected copy, marked «z-pdf · protected copy» [`saveAsPdf`, `zPdfProtectedCopy`]; its added page carries facts about the file and never a real value (rule 80). In Settings, «z-pdf — read a protected document back» opens such a file and restores the names your vault knows [`zPdfReadBack`].

### Your vault
Everything protected is one block per value in your vault, on this device [`yourVault`, `yourVaultIsIn`]. The vault opens with your passphrase and locks with «Lock now» [`lockNow`]. If a second copy of Z writes while one is open, the next write here answers: «Another copy of Z Privacy changed this vault. Close that window, or lock and unlock here to take in its work.» [`troubleVaultChangedElsewhere`] — nothing is lost silently.

### The rooms
Settings holds the rooms by name: Language & rules, Vault & security, Sessions [`roomLanguageAndRules`, `roomVaultAndSecurity`, `roomSessions`] — and your identity card, where a list is a CSV with a «name» and a «type» column [`aListIsACsv`].

## 3 · Screenshots

Four, from the Linux build at the measured commit, fixtures only: (1) the way in at the top, empty; (2) `Brief_Weber.txt` in two columns with one word just protected and the «Protected as …» bar visible; (3) the send sheet with «Safe — AI will receive»; (4) the z-pdf room. Each `<img>`'s `alt` says in one sentence what the eye should find. The commit they were taken at is written under the last one, as the terms page names its commit.

## 4 · The gate (e2, in `scripts/check_site.sh` or beside it)

- The three guide pages exist and name the same set of one-list keys in their comment block; every key exists in `lib/l10n/app_en.arb`; pinned red by renaming one key in a scratch copy.
- The front page's button href is the guide page; the Settings line's URL is the same path — one spelling, both read.
- No sentence in the page claims what CLAIMS.md does not; the claims-review prompt names the page.

## 5 · Not in this round

Video (the owner has not decided); the download section (rule 81, publishing day); any second in-app copy of the text.

## Measurement

e2: `bash scripts/gates.sh` green including the new site checks; the three pages open from `file://` with the shared CSS; the lead walks the English page against the installed app at the same commit, sentence by sentence, before the owner's «نعم» on the text; the owner's own walk on Windows after the next install is the second eye. Deploy by the owner's hand after the merge, and `check_site.sh` against the live site closes the item.

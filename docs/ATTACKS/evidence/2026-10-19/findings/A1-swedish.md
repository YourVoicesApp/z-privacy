# A1 — Swedish first-run law on 2b4fad9

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**Stamp:** not from a live window. Core probes on this tree print `z_core 0.1.0 · 2026-10-19 · 2b4fad9`.  
**Merge claim (do not assume):** one law in `core/sentences.dart` with three readers, so Svenska stays one choice (080) and no longer hands an English interface under a Swedish name; the dead Interface card deleted.

Live `flutter test` was **not** run in this worktree (it would write `.dart_tool`). The seven promise keys were unit-compared from the ARB files. The three readers were read in source. The first-run guard in `vault_screen_test.dart` and the 56-أ guard in `the_sentences_are_in_one_list_test.dart` name the same measurements.

The real vault at `/home/monopeaks/.local/share/zprivacy` was not opened. Probe data dirs were under `scratch/b567/tmp-data-*`.

---

## The seven promise keys

| key | en | sv == en | de == en |
|---|---|---|---|
| `noAccount` | No account. | yes | no (Kein Konto.) |
| `noAds` | No ads. | yes | no |
| `noAnalytics` | No analytics. | yes | no |
| `noZPrivacyServer` | No Z Privacy server. | yes | no |
| `originalDataStaysHere` | Your original data stays… | yes | no |
| `onlyTheProtectedVersionIsSent` | Only the protected version… | yes | no |
| `theseRulesWillBeEnabled` | The English privacy rules will be enabled. | yes | no (Die deutschen Datenschutzregeln werden aktiviert.) |

`app_sv.arb` has 314 keys, same count as English and German. **The only Swedish value that differs from English is `thisLanguageName`: `Svenska` vs `English`.** `languageWord` is still `Language`. `theseRulesWillBeEnabled` under `sv` still names **English** privacy rules.

`theListIsWrittenIn` compares exactly those seven keys against `AppLocalizationsEn`. `thisLanguageName` is not in the comparison. So `theListIsWrittenIn('sv')` is **false**. `theListIsWrittenIn('de')` is **true**. `theListIsWrittenIn('en')` is **true** by definition. `theListIsWrittenIn('fr')` is **false** (no list).

`theLocaleOf('sv')` therefore returns `Locale('en')`.

---

## The three readers

### 1. First screen (`first_run.dart`)

`_languagesThisPageSpeaks()` = `offeredLanguages.where(theListIsWrittenIn)`. With sv unwritten, the page offers **Deutsch** and **English** only. There is no Svenska button.

`_promiseOf` still looks up `Locale(code)` directly. If sv were offered, the panel would be: name `Svenska`, four English «no» lines, two English paragraphs, and «The English privacy rules will be enabled.» That is the P2-6 hole. The filter is what stops it. The product's own guard (`vault_screen_test.dart`) asserts `find.text('Svenska')` is nothing, and that `offeredLanguages` still contains `'sv'`.

### 2. Session / settings list (`language_list.dart`)

`offeredLanguages = ['de', 'en', 'sv']` unchanged. Rule 56 still shows Swedish wherever a **session** language is chosen (`TheLanguageOfANewSession`, the Language room, the document head). Pack label from the core is `Svenska` (`z_core/src/scanner/packs/sv.rs`).

A Svenska button **still exists** in those rooms. It is a scanner choice, not a first-run promise panel. Pressing it in Settings writes `packId` and `language` both to `sv` (080). The root then calls `theLocaleOf`, which answers English, so the glass speaks English. A disclosure line is drawn for every offered pack whose list is unwritten:

> `{language}: the detection pack is {language}; the interface is English until its sentences are translated.`

German wording of the same sentence exists. Swedish wording is the English copy.

### 3. Dead Interface card (`settings.dart`)

Gone. After the App language card the next card is `myPrivacyRules`. Comment at the deletion: rule 35, 19 October 2026. The first-run sentence «Die übrige Benutzeroberfläche ist derzeit auf Englisch» is also gone (092 made it false for German). Guard in `vault_screen_test.dart` asserts `Interface translation is coming later` is absent.

---

## README / packaging language claims

- `packaging/linux/README.txt`: «The interface is English. The detection packs are German, Swedish and English.» Mailbox: `yourvoices.app@mono-peak.com`.
- Root `README.md`: contact `yourvoices.app@mono-peak.com`. No pack list.
- Site (`site/en/index.html`, privacy): `zprivacy@mono-peak.com`.

The pack sentence is true of the scanner. The interface sentence is **now stale in the other direction**: German is a written list (314/314 values differ from English). Swedish is not.

---

## Defects

### A1-1 · NOTE — first screen still has no Svenska; that is now 56-أ, not an omitted button

What I did: compared the seven ARB keys; read `_languagesThisPageSpeaks`, `offeredLanguages`, `theLocaleOf`, the Language card, packaging README.

What should happen (original خ1 / rule 56): Swedish where a language is chosen, **or** the first screen honest about two interface languages.

What happened: the merge did not translate Swedish and did not put Svenska on the first screen. It wrote 56-أ: a language whose promise is still the English source is not offered **on this page**. Session/settings still offer `sv`. `theLocaleOf('sv')` is English. The Language card says so in one line. A Svenska button on the first screen would still hand English promises under a Swedish name — including «The English privacy rules will be enabled.» — and that button is not drawn.

The English-under-Swedish-name hole the merge named is **closed** on the first screen (by omission) and **closed** on the locale path (by fallback + disclosure). The original «offer Swedish at first run» complaint is now an explicit unwritten-interface debt, not a silent lie.

Grade: ملاحظة (the SERIOUS lie is gone; the missing Swedish UI is owed work)

### A1-2 · NOTE — packaging README still says the interface is English

German is a complete column. A person who reads the archive README and then taps Deutsch gets a German glass. The first screen already draws both promises. The README is the quieter copy.

Grade: ملاحظة

---

## Answers to the measurement questions

| question | measured |
|---|---|
| `theListIsWrittenIn('sv')` | **false** (7/7 promise strings identical to English) |
| First screen offer Svenska? | **no** |
| Session list still offer sv? | **yes** (`offeredLanguages` = de, en, sv) |
| `theLocaleOf('sv')` return en? | **yes** |
| Svenska button still hand English promises under a Swedish name? | **Not on first-run** (no button). `_promiseOf('sv')` would. Settings button is a scanner pick + English glass + disclosure. |
| Dead Interface card gone? | **yes** |

**Grades here:** مانع 0 · خطير 0 · ملاحظة 2

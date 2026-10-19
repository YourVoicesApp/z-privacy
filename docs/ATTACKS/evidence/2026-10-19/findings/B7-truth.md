# B7 — screen truth on 2b4fad9

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**Stamp:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**Probe:** `harnesses/probes/src/bin/b7.rs` → `logs/b567/b7-truth.txt`  
**Data:** `scratch/b567/tmp-data-b7` (not the real vault)  
**Contract §2:** two independent reports of one fact must agree.

Document: the same constant as `truthfulness.rs` (`Kunde: Nordstern… Herr Thomas Müller…`).

---

## Ten numbers, each from two sources

| # | what the glass would show | source A | source B | after scan | after Protect |
|---|---|---|---|---|---|
| 1 | «N protected automatically» | `WorkspaceSnapshot.auto_protected` | findings: `Protected && !decided` | 6 = 6 | 6 = 6 |
| 2 | «M need your word» | `ScanReport.suggested` | `list_findings` Suggested = `PayloadView.open_suggestions` = marks Suggested = `send` → `OpenSuggestions{count}` | 1 = 1 = 1 = Some(1) | 0 = 0 |
| 3 | «K normal» | `ScanReport.normal` | `WorkspaceSnapshot.normal` | 8 = 8 | 8 = 8 |
| 4 | «N values were replaced» | `PayloadView.protected_count` | marks Protected | 6 = 6 | 7 = 7 |
| 5 | identities on Home / Vault | `HomeSnapshot.identity_count` | `VaultSnapshot.identity_count` = `entities(None).len()` | 0 = 0 = 0 | — |
| 6 | values | `HomeSnapshot.value_count` | `VaultSnapshot.value_count` = `taught_values.len()` | 0 = 0 = 0 | — |
| 7 | files / profiles | `home.profiles.length` | `profiles().len()` | 0 = 0 | — |
| 8 | token badge | `list_tokens().len()` | `WorkspaceSnapshot.token_count` | 6 = 6 | — |
| 9 | PDF/send footer by kind | `PayloadView.by_kind` | tokens by Kind (Person 4, Email 1, Iban 1) | matches payload | — |
| 10 | vault state in the band | `ScanReport.vault` | `vault_state()` = `HomeSnapshot.vault` = `WorkspaceSnapshot.vault` | Unlocked = Unlocked | — |

`core_version()` is the window stamp: `z_core 0.1.0 · 2026-10-19 · 2b4fad9`.

Every pair agreed. The numbers moved with scan and answer (not frozen zeros).

### Split after confirm (ن4) — still there

```
ScanReport.auto            = 7
snapshot.auto_protected    = 6
snapshot.user_protected    = 1
payload.protected_count    = 7
BAND  : «6 protected automatically · 0 need your word · 8 normal»
FOOTER: «7 values were replaced»
WHERE_EVERY_NUMBER_COMES_FROM.md still names the band as ScanReport.auto (= 7)
workspace.dart:1696 still draws snap.autoProtected (= 6)
```

The labels on the glass are true of two different facts. The paper still names the wrong source for the band.

---

## Refusal messages — still named

`messages.dart` `humanMessage` is still the only interpreter. `_everyError` in `messages_test.dart` still lists **27** `ApiError`, **12** `Refusal`, **9** `NetworkRefusal`. No `_ =>` under the reader limits.

| type | sentence | real cause? | next step? |
|---|---|---|---|
| OpenSuggestions | «N words wait… nothing left Z.» | yes | review opens |
| VaultLocked / Absent / Required | unlock/create | yes | yes |
| VaultChangedElsewhere | another copy; close or lock/unlock | yes | yes |
| StoragePermissionsKept | will not change a permission you set | yes | change it or pick another folder |
| EncryptedPdf | remove the password | yes | yes |
| UnsupportedEncoding | percent + page + save as text | yes | yes |
| StalePayload | review then send again | yes | yes |
| Network NotConnected | add address and key | yes | yes |
| Network Unreachable | nothing answered; check network and address | yes | yes |
| InvalidSession | «That session is no longer open. Start a new one.» | yes, word is session | yes |
| DocumentTooLarge | about 26 MiB / limit 25 | yes | implicit |
| CompressionBomb (stream) | more than N times … stopped unpacking | yes | yes |
| ScannedPdf one page | pictures, will not import | yes | yes |
| **ScannedPdf N pages** | «N pages of pictures… nothing could be read.» | yes | **next step only on the one-page sentence** |
| **CompressionBomb (document ceiling)** | «A **part** of this file unpacks to more than $ratio times» | ratio is the file; «part» is not | stop — 16 MiB unsaid |
| **UnknownToken** | «not in this session» | close | no next step |
| **UnreadableStructure** | the page cannot be read | yes | no (Encoding says: save as text) |
| **TrailingVaultData** | extra data after the end, not opened | yes | no |
| **UnsupportedKdfParameters** | «unsupported security settings» | drops core `reason` (m_cost…) | no |
| **PayloadRefused** | sentence from `reason` | yes | no |

`UnsupportedKdfParameters` still maps to `sentences.troubleUnsupportedKdfParameters` and drops the measured `reason`. CompressionBomb on the glass is still one sentence about a **part**.

---

## Defects

### B7-1 · NOTE — two definitions of «auto» after confirm; the paper names the wrong source
Band 6, footer 7, `ScanReport.auto` 7. Glass is honest if you read its labels. Anyone copying `WHERE_EVERY_NUMBER_COMES_FROM.md` puts 7 under «protected automatically». `workspace.dart` still reads `snap.autoProtected`.

### B7-2 · NOTE — cumulative-ceiling bomb on the glass says «part»
Unchanged wording: `refusalCompressionBomb` = «A part of this file unpacks to more than {ratio} times…». Core can mean the sum past 16 MiB.

### B7-3 · NOTE — some refusals still have no next step; KDF drops the measured reason
TrailingVaultData, UnsupportedKdfParameters, UnreadableStructure, UnknownToken, ScannedPdf for N pages. Same list as 84832a0.

---

## Coverage checklist

- [x] ten numbers from two independent sources (b7.rs)
- [x] band and footer after scan and after answer
- [x] kind footer from the payload
- [x] vault state from scan report and `vault_state()`
- [x] ApiError 27 + Refusal 12 + NetworkRefusal 9 in the Dart map
- [ ] live window not run (section A was source + ARB)

**Grades here:** مانع 0 · خطير 0 · ملاحظة 3

# ب٧ · صدق الشاشة

**Commit:** `84832a015f74952556f5d512187a8d5f99673d9d`  
**Probe:** `fixtures/probes/src/bin/b7.rs` → `logs/b7-truth.txt`  
**عقد §٢:** تقريران مستقلان لحقيقة واحدة يجب أن يتفقا.  
**Stamp:** `z_core 0.1.0 · 2026-10-17 · 84832a0`

خزنة القياس تحت `fixtures/tmp-data-b7`. لم تُمسّ الخزنة الحقيقية (`sha256 1931180a…`).

---

## عشرة أرقام، كلٌّ من مصدرين

الوثيقة: نفس ثابت `truthfulness.rs` (`Kunde: Nordstern… Herr Thomas Müller…`).

| # | ما تراه الشاشة | المصدر أ | المصدر ب | بعد المسح | بعد إجابة الاقتراح |
|---|---|---|---|---|---|
| 1 | «N protected automatically» في شريط Workspace | `WorkspaceSnapshot.auto_protected` | findings: `Protected && !decided` | 6 = 6 | 6 = 6 |
| 2 | «M need your word» | `ScanReport.suggested` | `list_findings` Suggested = `PayloadView.open_suggestions` = marks Suggested = `send` → `OpenSuggestions{count}` | 1 = 1 = 1 = Some(1) | 0 = 0 |
| 3 | «K normal» | `ScanReport.normal` | `WorkspaceSnapshot.normal` | 8 = 8 | 8 = 8 |
| 4 | «N values were replaced» في ذيل العمود الآمن | `PayloadView.protected_count` | marks Protected | 6 = 6 | 7 = 7 |
| 5 | عدد الهويات في Home / Vault | `HomeSnapshot.identity_count` | `VaultSnapshot.identity_count` = `entities(None).len()` | 0 = 0 = 0 | — |
| 6 | عدد القيم | `HomeSnapshot.value_count` | `VaultSnapshot.value_count` = `taught_values.len()` | 0 = 0 = 0 | — |
| 7 | عدد الملفّات | `home.profiles.length` | `profiles().len()` | 0 = 0 | — |
| 8 | شارة الرموز | `list_tokens().len()` | `WorkspaceSnapshot.token_count` | 6 = 6 | — |
| 9 | تذييل PDF/الإرسال حسب النوع | `PayloadView.by_kind` | عدّ tokens حسب Kind (Person 4، Email 1، Iban 1) | يتطابق مع الحمولة | — |
| 10 | حالة الخزنة في الشريط | `ScanReport.vault` | `vault_state()` = `HomeSnapshot.vault` = `WorkspaceSnapshot.vault` | Unlocked = Unlocked | — |

`core_version()` هو ختم النافذة نفسه: `z_core 0.1.0 · 2026-10-17 · 84832a0`.

كل زوج اتفق. الأرقام تحركت مع المسح والإجابة (ليست أصفاراً مثبتة من أكذوبات §٢).

### انقسام مقيس، ليس كذبة الشاشة

بعد Protect على الاقتراح الوحيد:

```
ScanReport.auto            = 7   (كل المحمي، بما فيه ما أكّدته)
snapshot.auto_protected    = 6   (Protected && !decided)
snapshot.user_protected    = 1
payload.protected_count    = 7
BAND  : «6 protected automatically · 0 need your word»
FOOTER: «7 values were replaced»
```

`WHERE_EVERY_NUMBER_COMES_FROM.md` يقول إن الشريط من `ScanReport.auto`. الكود يرسم `snap.autoProtected` (`workspace.dart:1348`). الاثنان ليسا نفس العدد بعد التأكيد. **التسمية على الشاشة صادقة** (6 تلقائي، 1 بيدك، 7 استُبدلت). الاختبارات لا تصطدم: `truthfulness.rs` يقارن `report.auto` بكل Protected؛ `snapshots.rs` يقارن `auto_protected` بـ`!decided`. زوجان، تعريفان.

### B7-1 · ملاحظة — تعريفان لـ«auto» بعد التأكيد، والوثيقة تسمي المصدر الخطأ
- قست الشريط والذيل بعد `answer_finding(…, Protect)` ثم `scan`.
- رقم واحد على الشاشة، مصدر واحد في النواة، والورقة تطابقه.
- الشريط 6 والذيل 7 والـScanReport 7. الشاشة لا تكذب إن قُرئت تسميتها. الورقة تقول ScanReport.auto بينما `workspace.dart:1348` يقرأ snapshot. من ينسخ الورقة يضع 7 تحت «protected automatically».

---

## رسائل الرفض — السبب الحقيقي والخطوة التالية

عينة من `ApiError` في `api.rs` × `humanMessage` في `messages.dart` × `_everyError` في `messages_test.dart`.

ما أُغلق من الجولة السابقة على `5f5bef1`:

| السابق | على `5f5bef1` | على `84832a0` |
|---|---|---|
| Unreachable بلا جملة | «The connection… did not work.» و`_everyNetworkRefusal` بلا التاسع | «That address could not be reached at all — nothing answered. Check that you are online and that the address is right. Nothing was sent.» والاختبار يمشي التسعة. |
| InvalidSession «conversation» (55-هـ) | «That conversation is no longer open.» | «That session is no longer open. Start a new one.» |
| UnknownToken «conversation» | «not in this conversation» | «That protected value is not in this session.» |
| MalformedDocument يسقط التفصيل | جملة واحدة «damaged or incomplete» | التفصيل يصل الزجاج؛ بلا تفصيل تبقى الجملة العامة. |
| حدود القارئ بلا رقم | «could not be opened safely» | 26 ضد 25، 8 MiB، 201×، 512 جزء، 20 ثانية — كلّها في الجملة. |
| قنبلة باسم مسح | `ScannedPdfNoTextLayer` على 946× | `CompressionBomb`؛ اختبار Dart يمنع كلمتي picture/scan في جملة القنبلة. |

| النوع | الجملة | سبب حقيقي؟ | ماذا بعد؟ |
|---|---|---|---|
| OpenSuggestions | «N words wait… nothing left Z.» | نعم، العدد من النواة | المراجعة تُفتح (083a) |
| VaultLocked / Absent / Required | unlock/create | نعم | نعم |
| VaultChangedElsewhere | نسخة أخرى؛ أغلق أو lock/unlock | نعم | نعم |
| StoragePermissionsKept | لن نغيّر إذناً أنت وضعته | نعم + الوعد | غيّر الإذن أو مجلداً آخر |
| EncryptedPdf | أزل كلمة السر | نعم | نعم |
| UnsupportedEncoding | النسبة والصفحة + احفظ نصاً | نعم | نعم |
| StalePayload | راجع ثم أعد الإرسال | نعم | نعم |
| Network NotConnected | أضف عنواناً ومفتاحاً | نعم | نعم |
| Network Unreachable | لم يُجَب شيء؛ تحقّق من الشبكة والعنوان | نعم | نعم |
| InvalidSession | «That session is no longer open. Start a new one.» | نعم، والكلمة session (55-هـ) | نعم |
| DocumentTooLarge | about 26 MiB / حد 25 | نعم، والرقم لا يساوي الحدّ | ضمني: الملف أكبر من المسموح |
| CompressionBomb (مجرى) | more than N times … stopped unpacking | نعم | نعم: توقّف بدل ملء الآلة |
| ScannedPdf صفحة واحدة | صور بلا نص ولن نستورد ما لا نراه | نعم | نعم |
| **ScannedPdf N صفحات** | «N pages of pictures… nothing could be read.» | نعم | **الخطوة في حالة الصفحة الواحدة فقط** |
| **CompressionBomb (سقف الوثيقة)** | «A **part** of this file unpacks to more than 64 times» | الرقم 64 صحيح كالنسبة على الملف؛ «part» لا | توقّف — بلا 16 MiB |
| **UnknownToken** | «not in this session» | قريب | لا خطوة |
| **UnreadableStructure** | الصفحة لا تُقرأ | نعم | لا (Encoding يقول: احفظ نصاً) |
| **TrailingVaultData** | بيانات زائدة بعد نهاية الملف ولم يُفتح | نعم | لا (لا «استرجع نسخة») |
| **UnsupportedKdfParameters** | «unsupported security settings» | يُسقط `reason` من النواة (m_cost…) | لا |
| **PayloadRefused** | جملة من `reason` | نعم | لا (عطل داخلي) |

`messages_test` يمشي 27 بديلاً لـApiError (العدد يطابق النواة) و12 Refusal و9 NetworkRefusal. لا `_ =>` تحت حدود القارئ.

### B7-2 · ملاحظة — قنبلة السقف التراكمي على الزجاج «جزء» لا «المجموع»
- استوردت `pdf_nine_pages_cumul.pdf`. الـcore: «the parts of this PDF unpack to more than 17 MiB in all … past the 16 MiB».
- الشاشة تفرّق قنبلة عن مسح، وتذكر رقماً.
- `Refusal_CompressionBomb` جملة واحدة: «A part of this file unpacks to more than $ratio times». هنا $ratio=64 هو نسبة **الملف**، لا جزء واحد، وسقف 16 MiB لا يُقال. الرفض صادق؛ التشخيص على الزجاج أنقص من التفصيل.

### B7-3 · ملاحظة — رفض بلا خطوة تالية، وKDF يسقط السبب المقاس
- قارنت `TrailingVaultData` و`UnsupportedKdfParameters { reason }` و`UnreadableStructure` و`UnknownToken` و`ScannedPdfNoTextLayer` لـ N صفحات بـ`humanMessage`.
- EncryptedPdf وUnsupportedEncoding وUnreachable وInvalidSession هم النموذج: سبب + ماذا تفعل.
- الخزنة المقطوعة تقول إن الملف لم يُفتح ولا تقول ماذا يفعل الإنسان بنسخة سليمة. KDF يخفي `m_cost`/`t_cost` التي قاستها النواة. UnreadableStructure لا يقول «احفظ نصاً» رغم أن الجار Encoding يقوله. UnknownToken يسمّي session ولا يقترح جلسة جديدة. مسح N صفحات يسقط جملة «will not import» الموجودة للصفحة الواحدة.

---

## قائمة التغطية

- [x] عشرة أرقام من مصدرين مستقلين (b7.rs + snapshots في النواة)
- [x] الشريط والذيل بعد المسح وبعد الإجابة
- [x] تذييل الأنواع من الحمولة لا من المقعد
- [x] حالة الخزنة من تقرير المسح ومن `vault_state()`
- [x] عيّنة ApiError كاملة العدد (27) + Refusal (12) + NetworkRefusal (9)
- [x] خريطة Flutter الوحيدة (`messages.dart`) — لا وِدجت تفسّر الخطأ وحدها (P1-1)
- [x] InvalidSession / UnknownToken: كلمة session لا conversation (55-هـ)
- [x] Unreachable: جملة خاصة
- [x] DocumentTooLarge: 26 ضد 25 على الزجاج
- [x] CompressionBomb ليست مسحاً
- [x] TrailingVaultData: سبب على الزجاج (بلا خطوة)
- [ ] لم أُشغّل الشاشة الحية (قسم أ)؛ الأرقام من النواة والعقد كما ترسمها الشاشات في الكود

**الدرجات هنا:** مانع 0 · خطير 0 · ملاحظة 3

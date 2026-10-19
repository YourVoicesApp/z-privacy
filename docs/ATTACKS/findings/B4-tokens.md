# B4 · الرموز والعودة

**Commit:** `84832a015f74952556f5d512187a8d5f99673d9d`  
**الختم:** `z_core 0.1.0 · 2026-10-17 · 84832a0`  
**الأداة:** `fixtures/b4-driver` (يستدعي عقد `z_core` فقط)  
**السجل:** `/home/monopeaks/z-attack-final/logs/B4-run.txt`  
**خزنتا التجربة:** `fixtures/vault-b4/{a,b}` — ليستا `~/.local/share/zprivacy`

G9: الاستعادة لا تخمّن. G10: لكل جلسة namespace. القاعدة 51: z-pdf يعيد كل رمز إلى اسمه من بلوكات الخزنة. لا اسم إلى غير صاحبه.

PASS=23 FAIL=0 في هذا التشغيل. لا عيب.

---

## العيوب

لا عيوب في هذا القسم على `84832a0`.

م4 السابق (مانع): جملة الشاشة كانت تقول إن الرمز «حُمي قبل أن تبدأ Z بحفظ كل كلمة» عن ملف عُبث بذيله. الجملة الآن تسمّي سببين ولا تدّعي علماً لم يثبته الـcore — قيست أدناه وليست عيباً.

---

## ما نجح

### رموز مزوّرة — لا يعود اسم إلى غير صاحبه

من جلسة A بعد الولادة: `__Z_A2AC_PERSON_FA85FE31__` (Thomas) و`__Z_A2AC_PERSON_6CB91A28__` (Anna). `ingest_answer` ثم `restored_view`.

| الهجوم | النتيجة |
|---|---|
| namespace غريب `__Z_FFFF_PERSON_91C7ABCD__` | يبقى رمزاً؛ Thomas لا يُستعاد منه. إن وُجد الرمز الحقيقي في الجملة نفسها يعود Thomas وحده. |
| ذيل مقطوع (2 hex) / بلا إغلاق | ليس بالشكل (`parts_of`)؛ لا استعادة من المزور. |
| رمز داخل رمز (التفاف) | الرمز الحقيقي الداخلي قد يُلتقط إن بقي `__Z_…__` سليماً — ويعود **صاحبه**. إن ابتلع الإغلاق الخارجي الداخلي، لا يعود أحد. |
| حروف كيريلية مكان Latin في NS أو KIND | ليست ASCII؛ تُترك نصاً. |
| عرض صفري داخل NS / قبل الإغلاق / بعد `__Z_` | ليست بالشكل؛ لا استعادة. |
| نفس الشكل وذيل آخر | لا يُستعاد أحد غير الرموز المسموحة. |
| KIND مُبدَّل ونفس الذيل (`…_IBAN_FA85FE31__`) عبر `ingest_answer` | القائمة المسموحة حرفية (G9)؛ لا استعادة. |
| ذيل بحروف صغيرة `__Z_A2AC_PERSON_fa85fe31__` | لا يُطابق المفتاح؛ لا Thomas. |
| namespace بحروف صغيرة | لا يُطابق؛ لا Thomas. |

### z-pdf من خزنة أخرى — لا يعود شيء

خزنة B (Stefan / Beate). `read_a_document_that_came_back` لنص/PDF جلسة A:

```
brought_back=0
unresolved=[رمز Thomas، رمز Anna، رمز صفحة الإجابة]
unknown_namespaces=["A2AC"]
conversations=[]
```

النص المستعاد يُبقي الرموز. لا `Thomas` ولا `Anna`. جملة الشاشة (`whatCameBack`):

«This document carries 3 names from a session this vault does not hold (A2AC). Nothing here can put them back: the key that made them is not in this vault.»

### z-pdf سليم من الخزنة نفسها

`brought_back=2` · `answer_page=true` · النص `Thomas arbeitet mit Anna.` و`Z-pdf : Zprivacy-svara`. PDF يدوي بسطر الرموز سلك الباب نفسه.

تعديل نثر غير الرمز (`arbeitet` → `ARBEITET`): الاسمان يعودان. الشاشة: «2 names came back from «session-a».»

### z-pdf معدَّل بعد التصدير — ماذا تقول الشاشة

صدّرت نص جلسة A. غيّرت رقم hex واحد في ذيل رمز Thomas (`…FA85FE31` → `…FA85FE30`). أعدت الملف من باب `read_a_document_that_came_back`.

- **الـcore:** `brought_back=1` (Anna) · `unresolved=["__Z_A2AC_PERSON_FA85FE30__"]` · `unknown_ns=[]`. لا Thomas من الرمز المزور. لا اسم إلى غير صاحبه.
- **الشاشة** (`whatCameBack` في `messages.dart:310`، قيست من نفس `ReturnedDocument`):

«One name came back from «session-a». One name stays as a token, and two different things do that: the word was protected before Z Privacy began keeping every protected word, or this token was changed after the file left. Open that document in its session and protect the name again — if it comes back from then on it was the first, and if it does not, this file is not the one Z Privacy wrote.»

لا تدّعي سبباً واحداً لم يثبته الـcore. م4 السابق أُغلق.

### جواب مزوّد يكرر الرمز 100 مرّة، أو يقطعه

- 100 تكرار: `thomas_places=100` · `anna_wrong=false` · `panic_like=false` · `text_len=700`. لا panic.
- قطع في المنتصف: `begin __Z_A2AC_PERS CUT ON_FA85FE31__ end` — لا استعادة.
- نصف الرمز فقط: لا استعادة.

---

## قائمة التغطية

- [x] رموز مزوّرة: namespace غريب، ذيل مقطوع، رمز داخل رمز، حروف شبيهة لاتينية، عرض صفري داخل الرمز — لا اسم إلى غير صاحبه
- [x] z-pdf من خزنة أخرى: لا يعود شيء
- [x] z-pdf معدَّل بعد التصدير: ماذا يقول — الـcore يُسمّي الرمز غير المحلول؛ الشاشة تسمّي سببين ولا تكذب
- [x] جواب يكرر رمزاً 100 مرّة، أو يقطعه في منتصفه: لا ينكسر شيء ولا يتسرّب شيء

**العدّ:** مانع 0 · خطير 0 · ملاحظة 0

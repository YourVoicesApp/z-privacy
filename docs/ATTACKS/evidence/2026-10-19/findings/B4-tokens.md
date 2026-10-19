# B4 · الرموز والعودة

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**الختم:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**الأداة:** `harnesses/b4-driver` (يستدعي عقد `z_core` فقط؛ `CARGO_TARGET_DIR=…/target-b4`)  
**السجل:** `/home/monopeaks/z-attack-2b4fad9-evidence/logs/B4-run.txt`  
**خزنتا التجربة:** `scratch/b4/{a,b}` — ليستا `~/.local/share/zprivacy`  
**الخزنة الحقيقية:** `sha256 760da2625e3b23e02a24509326af5c6c2c5e9257c25ff66359153c3b725bc203` قبل وبعد. لم تُمس.

G9: الاستعادة لا تخمّن. G10: لكل جلسة namespace. القاعدة 51: z-pdf يعيد كل رمز إلى اسمه من بلوكات الخزنة. لا اسم إلى غير صاحبه.

PASS=29 FAIL=0 في هذا التشغيل. لا عيب في الاستعادة. ملاحظة واحدة على جملة الشاشة (ن1).

---

## العيوب

### ن1 · جملة العودة بعد رمز مُعدَّل ما زالت تسمّي «قبل أن تبدأ Z بحفظ كل كلمة»

**باقٍ — ملاحظة. م4 (مانع) ما زال مغلقاً.**

انظر `RETEST-B4.md`. النواة صادقة. الشاشة تسمّي سببين. السبب التاريخي ما زال يُعرض كاحتمال على ذيل عُبث به في **هذا** البناء بعد أن وُجدت البلوكات (`block_count=2`).

لم أرفعها إلى خطير: `ReturnedDocument` لا يفرّق، وسبب ما قبل 089 ما زال ممكناً لملف قديم، والتجربة المعطاة تفرّق. لم أُسقطها: الجملة ما زالت تضع تاريخ بناء لم يقع على قياس اليوم.

---

## ما نجح

### رموز مزوّرة — لا يعود اسم إلى غير صاحبه

من جلسة A بعد الولادة: `__Z_EE64_PERSON_371E1E6C__` (Thomas) و`__Z_EE64_PERSON_09AFD4B2__` (Anna). `ingest_answer` ثم `restored_view`. `block_count=2`.

| الهجوم | النتيجة |
|---|---|
| namespace غريب `__Z_FFFF_PERSON_91C7ABCD__` | يبقى رمزاً؛ إن وُجد الرمز الحقيقي في الجملة نفسها يعود Thomas وحده. |
| ذيل مقطوع (2 hex) / بلا إغلاق | ليس بالشكل (`parts_of`)؛ لا استعادة من المزور. |
| رمز داخل رمز (التفاف، الإغلاق الداخلي سليم) | الرمز الحقيقي الداخلي يُلتقط ويعود **صاحبه**. |
| رمز داخل رمز يبتلع الإغلاق | لا يعود أحد. |
| حروف كيريلية مكان Latin في NS أو KIND أو الذيل | ليست ASCII؛ تُترك نصاً. |
| عرض صفري داخل NS / قبل الإغلاق / بعد `__Z_` / داخل الذيل | ليست بالشكل؛ لا استعادة. |
| نفس الشكل وذيل آخر | لا يُستعاد أحد غير الرموز المسموحة. |
| KIND مُبدَّل ونفس الذيل (`…_IBAN_371E1E6C__`) عبر `ingest_answer` | القائمة المسموحة حرفية (G9)؛ لا استعادة. |
| KIND مُبدَّل عبر `read_a_document_that_came_back` | `unresolved=["__Z_EE64_IBAN_371E1E6C__"]` · Anna تعود · Thomas لا. |
| ذيل بحروف صغيرة `__Z_EE64_PERSON_371e1e6c__` | لا يُطابق المفتاح؛ لا Thomas. |
| namespace بحروف صغيرة | لا يُطابق؛ لا Thomas. |

حالة «O مكان 0 في الذيل» كانت لا-عملية في هذا التشغيل: الذيل `371E1E6C` لا يحتوي `0`. ليست دليلاً على قبول الشكل المزور.

### z-pdf من خزنة أخرى — لا يعود شيء

خزنة B (Stefan / Beate). `read_a_document_that_came_back` لنص/PDF جلسة A:

```
brought_back=0
unresolved=[رمز Thomas، رمز Anna، رمز صفحة الإجابة]
unknown_namespaces=["EE64"]
conversations=[]
```

النص المستعاد يُبقي الرموز. لا `Thomas` ولا `Anna`. فروع `whatCameBack` (`messages.dart:298`): `unresolved + here==0` ثم `unknown_namespaces`. جملة الشاشة:

«This document carries 3 names from a session this vault does not hold (EE64). Nothing here can put them back: the key that made them is not in this vault.»

### z-pdf سليم من الخزنة نفسها

`brought_back=2` · `answer_page=true` · النص `Thomas arbeitet mit Anna.` و`Z-pdf : Zprivacy-svara`. PDF يدوي بسطر الرموز سلك الباب نفسه.

تعديل نثر غير الرمز (`arbeitet` → `ARBEITET`): الاسمان يعودان. الشاشة: «2 names came back from «⁨session-a⁩».» (عوازل U+2068/U+2069 حول الاسم).

### z-pdf معدَّل بعد التصدير — ماذا تقول الشاشة

صدّرت نص جلسة A. غيّرت رقم hex واحد في ذيل رمز Thomas (`…371E1E6C` → `…371E1E60`). أعدت الملف من باب `read_a_document_that_came_back`. البلوكات موجودة (`block_count=2`).

- **الـcore:** `brought_back=1` (Anna) · `unresolved=["__Z_EE64_PERSON_371E1E60__"]` · `unknown_ns=[]` · `conversations=[#2 session-a back=1 unresolved=1]`. لا Thomas من الرمز المزور. لا اسم إلى غير صاحبه.
- **فروع `whatCameBack`:** `brought_back>0` ثم `unresolved + here>0 → two-causes`.
- **الشاشة** (`messages.dart:298` / `oneNameStaysATokenTwoCauses` في `app_en.arb:290`، قيست من نفس `ReturnedDocument`):

«One name came back from «⁨session-a⁩». One name stays as a token, and two different things do that: the word was protected before Z Privacy began keeping every protected word, or this token was changed after the file left. Open that document in its session and protect the name again — if it comes back from then on it was the first, and if it does not, this file is not the one Z Privacy wrote.»

لا تدّعي سبباً واحداً لم يثبته الـcore. م4 السابق أُغلق. السبب التاريخي ما زال يُسمّى — ن1.

### جواب مزوّد يكرر الرمز 100 مرّة، أو يقطعه

- 100 تكرار: `thomas_places=100` · `anna_wrong=false` · `panic_like=false` · `text_len=700`. لا panic (`catch_unwind` لم يُثر).
- قطع في المنتصف: `begin __Z_EE64_PERS CUT ON_371E1E6C__ end` — لا استعادة.
- نصف الرمز فقط: لا استعادة.

---

## قائمة التغطية

- [x] رموز مزوّرة: namespace غريب، ذيل مقطوع، رمز داخل رمز، حروف شبيهة لاتينية، عرض صفري داخل الرمز — لا اسم إلى غير صاحبه
- [x] z-pdf من خزنة أخرى: لا يعود شيء
- [x] z-pdf معدَّل بعد التصدير: ماذا يقول — الـcore يُسمّي الرمز غير المحلول؛ الشاشة تسمّي سببين ولا تكذب بسبب واحد
- [x] جواب يكرر رمزاً 100 مرّة، أو يقطعه في منتصفه: لا ينكسر شيء ولا يتسرّب شيء

**العدّ:** مانع 0 · خطير 0 · ملاحظة 1 (ن1)

**م4:** مغلق. **ن1:** باقٍ ملاحظة.

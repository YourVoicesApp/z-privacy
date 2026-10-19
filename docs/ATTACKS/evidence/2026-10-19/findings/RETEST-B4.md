# إعادة قياس B4 / م4 / ن1 — 2b4fad9

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**الختم:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**المصدر:** `/home/monopeaks/z-attack-2b4fad9` (قراءة فقط)  
**الأداة:** `/home/monopeaks/z-attack-2b4fad9-evidence/harnesses/b4-driver`  
**السجل:** `/home/monopeaks/z-attack-2b4fad9-evidence/logs/B4-run.txt`  
**لم يُمس:** `~/.local/share/zprivacy` (`vault.zv` `760da2625e3b23e02a24509326af5c6c2c5e9257c25ff66359153c3b725bc203`) · `~/mono-privacy` · نسخة الهجوم.

السابق: `mono-privacy-papers/docs/ATTACKS/findings/B4-tokens.md` على `84832a0` أغلق م4 كمانع بعد جملة السببين، وعدّها ليست عيباً. `REPORT_2_on_84832a0.md` أبقاها ملاحظة ن1. `RETEST-previous.md` البند 4 رفعها إلى **خطير**.

هذا القياس يعيد البند 4 وحده على هذا البناء، وجملة `whatCameBack` كما هي في `apps/flutter_app/lib/core/messages.dart:298`.

PASS=29 FAIL=0 على هجوم الرموز كاملاً.

---

## م4 · جملة كاذبة بسبب واحد على رمز مُعدَّل

**مغلق — لم يُفتح من جديد.**

الجملة لا تقول إن الرمز «حُمي قبل أن تبدأ Z بحفظ كل كلمة» سبباً وحيداً. تسمّي سببين وتجربة. اختبار المنتج `the_way_back_says_what_to_do_test.dart` («two causes… م4») ما زال يفرض النصّين `changed after the file left` و`protect the name again`.

---

## ن1 / البند 4 السابق · الشاشة ما زالت تسمّي السبب التاريخي على ذيل عُبث به في هذا البناء

**باقٍ — ملاحظة. لم أرفعها إلى خطير.**

1. **ماذا فعلت:** خزنة مؤقتة تحت `scratch/b4/a`. استوردت `Thomas arbeitet mit Anna.` وحميت الاسمين (`Scope::Conversation`). بعد الحماية `vault_snapshot().block_count=2` — البلوكات موجودة. `payload_to_take_out` أعطى `__Z_EE64_PERSON_371E1E6C__` (Thomas) و`…09AFD4B2__` (Anna). غيّرت آخر رقم hex: `…371E1E6C` → `…371E1E60`. `read_a_document_that_came_back`. ثم طبّقت فروع `whatCameBack` في `messages.dart:298-421` على الحقول المقيسة (العوازل U+2068/U+2069 حول اسم الجلسة كـ`theirOwnWord`).
2. **ماذا كان يجب:** ألا يعود Thomas من الرمز المزور (وهذا حصل). وأن لا تُستعاد Anna إلى غير صاحبها. الشاشة: إن لم يفرّق الـcore بين سببين، لا تدّعي واحداً لم يُقس. الجملة التي تسمّي الاثنين وتجربة التمييز تفي بقانون «جملة لا تثبت سبباً لم يثبته الـcore». إسقاط السبب الأول يكذب على ملف ما قبل 089. إبقاؤه على ذيل عُبث به اليوم يضع تاريخ بناء لم يقع بجانب الحقيقة.
3. **ماذا حدث في النواة:** `brought_back=1` · `unresolved=["__Z_EE64_PERSON_371E1E60__"]` · `unknown_ns=[]` · `conversations=[#2 session-a back=1 unresolved=1]` · `vault=Unlocked` · النص `«__Z_EE64_PERSON_371E1E60__ arbeitet mit Anna.»` · `thomas_back=false` · `anna_back=true`. لا اسم إلى غير صاحبه.  
   **الفروع:** `brought_back>0` ثم `unresolved + here>0 → two-causes` (`here=1`). لا `unknown_namespaces`.  
   **ماذا تقول الشاشة:**  
   «One name came back from «⁨session-a⁩». One name stays as a token, and two different things do that: **the word was protected before Z Privacy began keeping every protected word**, or this token was changed after the file left. Open that document in its session and protect the name again — if it comes back from then on it was the first, and if it does not, this file is not the one Z Privacy wrote.»  
   السبب الأول كاذب على هذا القياس: Thomas حُمي في هذه الجلسة بعد أن صارت البلوكات تُحفظ. السبب الثاني هو الذي وقع. الشاشة ما زالت تعرضه **كأحد اثنين** لأن `ReturnedDocument` لا يفرّق.

**لماذا ليست خطيراً في هذا البناء:** رفع `RETEST-previous` إلى خطير يُحمّل الجملة إيحاءً (السبب الأول احتمال حيّ) أكثر مما تقوله. القانون الذي كتبه المنتج بعد م4 هو ألا تُثبَت علة لم تُقس — وجملة «أو» مع التجربة تفي به. التجربة نفسها تفرّق: إعادة الحماية في الوثيقة الأصلية تكتب بلوكاً للرمز الحقيقي؛ الملف المعبوث ذيله يبقى بلا مطابقة، فيُقرأ «هذه ليست الملف الذي كتبته Z». إسقاط السبب التاريخي يكذب على من يحمل ملفاً من قبل 089. عيب جديد يتطلّب حقلاً في القراءة يفصل «لم يُسكّ قط» عن «عُبث بعد الخروج» — تغيير عقد لا قياس كذب واحد.

**الدرجة: ملاحظة (ن1). م4 مغلق.**

---

## الحالة

| البند | السابق على 84832a0 | RETEST-previous | هذا البناء 2b4fad9 |
|---|---|---|---|
| م4 مانع (سبب واحد كاذب) | أُغلق | أُغلق | **مغلق** |
| ن1 جملة السببين على ذيل مُعبث | ملاحظة في التقرير، ليست عيباً في B4 | **خطير** | **ملاحظة** (لم أوافق على الرفع) |

**العدّ من B4 على 2b4fad9:** مانع 0 · خطير 0 · ملاحظة 1.

# إعادة قياس الموانع السابقة — 84832a0

**Commit (نسخة الهجوم والتثبيت):** `84832a015f74952556f5d512187a8d5f99673d9d`  
**الختم:** `z_core 0.1.0 · 2026-10-17 · 84832a0`  
**الثنائي:** `/home/monopeaks/.local/opt/zprivacy` · `BUILD-INFO.txt` يطابق الختم.  
**المصدر:** `/home/monopeaks/z-attack-final/src` (detached على ذلك الـcommit)  
**لم يُمس:** `~/.local/share/zprivacy` · `~/mono-privacy` · `~/Documents/zprivacy` · ZPrivacy-lib.

الأدوات: `z_core --example check_document` (release) · `fixtures/retest-harness` · `fixtures/b2-harness` (40 تجربة، path-dep على النسخة) · `cargo test -p z_core --test two_copies_never_lose_a_write --release` · `strings` على المكتبات المثبّتة · AT-SPI قراءة فقط على النافذة الحية `com.monopeak.zprivacy` (`XDG_DATA_HOME=/home/monopeaks/z-attack-data`) — بلا نقر Close وبلا إنشاء خزنة.

السجلات: `logs/check_document-84832a0.txt` · `logs/retest-harness-84832a0.txt` · `logs/b2-race-84832a0.txt` · `logs/atspi-firstrun-84832a0.txt`

`chat_to_take_out` غير موجود في هذا الـcommit (على HEAD `e7f1ad9` فقط). لم يُهاجَم.

---

## الستة الموانع

### 1. Direct Mode مقابل وعد أول تشغيل «Only the protected version is sent»

**FIXED**

1. **ماذا فعلت:** بحثت `ask_model_directly` · `Body::Direct` · `sendOriginal` · `askModelDirectly` · `The original text` في العقد (`api.rs`) والبوابة (`gateway.rs`) وFlutter (`send_sheet.dart` · `session_state.dart`) والثنائي المثبّت (`libz_bridge.so` · `libapp.so` · `zprivacy`). مشيت كل باب `send`/`ask` عام. AT-SPI للنافذة الحية ما زال يعرض الوعد.
2. **ماذا كان يجب:** إن وُعد «لا يُرسل إلا المحمي»، لا باب يرسل الأصل. وإلا تسمّيه الجملة.
3. **ماذا حدث:** الأبواب محذوفة من العقد والبوابة والتطبيق والثنائي (صفر سلاسل). الباقي ثلاثة أبواب وكلها بمقبض: `send(PayloadHandle)` · `ask_model(PayloadHandle, …)` · `payload_to_take_out(SessionId)` (محلي، لا شبكة). `Request.payload` في البوابة حقل مقبض واحد. الشريحة «The original text» غير مرسومة. النافذة الحية ما زالت تقول «Only the protected version is sent to AI through Z Privacy» / «Über Z Privacy wird nur die geschützte Version an eine KI gesendet» — والوعد يطابق الأبواب في 84832a0.

---

### 2. PDF Flate فوق 8 MiB يُقطَع ويُستورَد 100% مقروءاً

**FIXED**

1. **ماذا فعلت:** شغّلت `check_document` release من النسخة على `fixtures/pdf_flate_over_8mib.pdf` (9 KiB، مجرى يفكّ إلى 9 MiB، `START_MARKER_B3` في الرأس و`END_MARKER_B3` بعد 8 MiB) تحت `XDG_DATA_HOME=…/fixtures/tmp-xdg-check`. ثم `import_document` من الـharness.
2. **ماذا كان يجب:** الرفض باسمه، لا قراءة نصف مجرى تُعرض كاملة.
3. **ماذا حدث:** `refused: CompressionBomb { ratio: 201 }` — «a page's content unpacks to more than 201× the bytes it is written in, which no document does». الاستيراد لم ينجح. لا `pages=1` ولا `100% readable` ولا ذيل ساقط. السقف يوقف عند 200×+1 فيُسمّى القنبلة قبل حدّ 8 MiB. `decode_stream`/`inflate_bounded` يرفضان المجرى المقطوع.

---

### 3. قنبلة Flate بنسبة ~946 تُرفَض بوصفها صورة ممسوحة

**FIXED**

1. **ماذا فعلت:** `check_document` + `import_document` على `fixtures/pdf_flate_ratio_200.pdf` (262144 صفراً → 277 بايت مضغوط، نسبة 946). شاهد: `pdf_scanned_no_text.pdf` (3 صفحات صور).
2. **ماذا كان يجب:** `CompressionBomb` (أو اسم صادق عن النسبة)، لا «this is a scan».
3. **ماذا حدث:** القنبلة: `CompressionBomb { ratio: 201 }`. المسح الحقيقي: `ScannedPdfNoTextLayer { pages: 3 }`. الاسمان انفصلا. Flutter يرسم `Refusal_CompressionBomb` بجملة النسبة لا جملة الصورة (`messages.dart`).

---

### 4. رمز مُعدَّل: whatCameBack يقول «protected before Z Privacy began keeping every protected word»

**باقٍ — خُفِّض من مانع إلى خطير**

أضافوا سبباً ثانياً. القياس يثبت أن الجملة المزدوجة ما زالت تُقال على ذيل مُعبث به في جلسة **هذا** البناء (بعد 089، والبلوك موجود).

1. **ماذا فعلت:** خزنة مؤقتة تحت `fixtures/retest-work/mutated`. استوردت `Thomas arbeitet mit Anna.` وحميت الاسمين (`Scope::Conversation`). `payload_to_take_out` أعطى `__Z_D393_PERSON_9ADD7D48__` (Thomas) و`…FC76447C__` (Anna). غيّرت آخر رقم hex: `…9ADD7D48` → `…9ADD7D40`. `read_a_document_that_came_back`. ثم طبّقت فروع `whatCameBack` في `messages.dart:310-398` على الحقول المقيسة.
2. **ماذا كان يجب:** ألا يعود Thomas من الرمز المزوّر (وهذا حصل). وأن تقول الشاشة إن الرمز لا يطابق بلوكاً / تغيّر بعد التصدير — لا أن تخترع تاريخ بناء لم يقع. النواة لا تحمل حقلاً يفصل السببين؛ جملة لا تثبت سبباً لم تُقس.
3. **ماذا حدث في النواة:** `brought_back=1` · `unresolved=["__Z_D393_PERSON_9ADD7D40__"]` · `unknown_ns=[]` · `conversations=[#2 session-a back=1 unresolved=1]` · النص `«__Z_D393_PERSON_9ADD7D40__ arbeitet mit Anna.»` · `thomas_back=false` · `anna_back=true`. لا اسم إلى غير صاحبه.  
   **ماذا تقول الشاشة** (`here=1`, vault مفتوح):  
   «One name stays as a token, and two different things do that: **the word was protected before Z Privacy began keeping every protected word**, or this token was changed after the file left. Open that document in its session and protect the name again…»  
   السبب الأول كاذب على هذا القياس: Thomas حُمي في هذه الجلسة بعد أن صارت البلوكات تُحفظ (`blocks` عُمل بها). السبب الثاني هو الذي وقع. الشاشة ما زالت تعرض تاريخ بناء لم يحدث، جنباً إلى جنب مع الحقيقة، لأن `ReturnedDocument` لا يفرّق.

**الدرجة: خطير**

---

### 5. نسختان تكتبان: 3/40 كتابات تُفقد بصمت

**FIXED**

1. **ماذا فعلت:** نسخت سباق العمليتين إلى `fixtures/b2-harness` (path-dep على `z-attack-final/src/z_core`). 40 تجربة: خزنة بـ40 هوية حشو، عمليتان `create_entity` بعد حاجز ملف. ثم 20 تجربة على `conversation_record` لملف `.zs`. ثم اختبارهم `two_copies_never_lose_a_write.rs` release (`test-threads=1`).
2. **ماذا كان يجب:** لا كتابة تُفقد بصمت. إما الاثنتان على القرص، أو رفض باسم `VaultChangedElsewhere`.
3. **ماذا حدث:**  
   - الخزنة، 40/40: `both=0` · `a_only=19` · `b_only=21` · `SILENT lost writes=0` · `honest VaultChangedElsewhere=40`. من قال `ok` هو من بقي على القرص؛ الآخر `err VaultChangedElsewhere`.  
   - الجلسة، 20/20: `both_on_disk=20` · `silent_lost=0` (التجربة 0: `asked=["erste", "turn-B-0", "turn-A-0"]`).  
   - اختبارهم: `3 passed` (`two_copies_never_lose_a_write` · `two_copies_never_lose_a_turn` · العامل).  
   الآلة: `writing.lock` + `File::lock` داخل `with_core` (`secure_file.rs` / `session.rs`). `conversation::write` ما زال بلا مقارنة `disk_bytes`، لكن `body()` يعيد القراءة من القرص والقفل يمنع الفجوة: القياس لا فقد صامت.

---

### 6. حوار Delete identity يكذب؛ الوثيقة التالية تُحمى وحدها

**FIXED**

1. **ماذا فعلت:** هوية قيمتها `ZxqvBlockNeedle` بسياسة Always. استيراد → `protected=1` · `blocks=1`. `delete_entity` كما يفعل الزر. ثم استيراد الاسم في جلسة جديدة، ثم بعد `lock`/`unlock` وجلسة ثالثة.
2. **ماذا كان يجب:** «Documents already protected keep their tokens; the next document will not recognise these values again». النسيان يعفي البلوك ولا يمسحه.
3. **ماذا حدث:** بعد الحذف `entities=0` · `blocks=1` (لم يُمسح — القاعدة 50). الجلسة الجديدة: `protected=0` · `suggested=0` · `findings=[]`. بعد القفل وإعادة الفتح: كذلك. الحوار في `entity_detail.dart:343-347` يطابق الباب: `delete_entity` يجمع الهجاء ثم `forget_the_blocks_of`.

---

## الخطير السابق — أُعيد قياسه

### أول تشغيل: Deutsch + English فقط، و`offeredLanguages` فيها sv

**باقٍ — خطير**

1. **ماذا فعلت:** قرأت `first_run.dart` (زران: Deutsch / English، الوعد من `_de` و`_en` فقط). `language_list.dart:42` `offeredLanguages = ['de','en','sv']`. AT-SPI للنافذة الحية `com.monopeak.zprivacy` (قراءة، بلا نقر): لوحات DEUTSCH / ENGLISH / Deutsch / English. لا Svenska ولا Swedish ولا sv.
2. **ماذا كان يجب:** لغة تُعرض حزمةً في الجلسة تُعرض حيث يُختار الدخول، أو تُسمّى الشاشة الأولى لغتين فقط بصدق عن الحزم.
3. **ماذا حدث:** الحزمة السويدية منتج (`sv_names_v1.csv`، README الإطلاق يقول German, Swedish and English). شاشة البداية لا تقدّمها. الاختيار بعد الدخول في قائمة الجلسة لا يُصلح الصفحة التي يراها أول مرة.

**الدرجة: خطير**

---

### مسارات المضيف في الثنائيات (كان 195 `/home/monopeaks` في libz_bridge)

**FIXED**

1. **ماذا فعلت:** `strings` على `/home/monopeaks/.local/opt/zprivacy/lib/libz_bridge.so` و`libapp.so`.
2. **ماذا كان يجب:** لا مسار من جهاز البناء في ثنائي الإطلاق.
3. **ماذا حدث:** `/home/monopeaks` = 0 في الاثنين. `/home/` = 0. `cargo/registry` = 0. بقيت سلاسل `rustc-demangle` تحت `/rust/deps/…` بلا اسم مستخدم.

---

### ملف خزنة فارغ = فخ VaultAlreadyExists

**FIXED**

1. **ماذا فعلت:** أنشأت خزنة، كتبت `vault.zv` صفراً، ثم `vault_state` / `unlock` / `create`. ثم ملف مقطوع (نصف البايتات) كشاهد.
2. **ماذا كان يجب:** ملف بلا بايتات ليس خزنة. باب يخرج منه. ملف متضرر لا يُكتب فوقه.
3. **ماذا حدث:** الفارغ: `state=Absent` · unlock «this vault file holds no bytes at all» · `create => created` وكتب 235 بايت. المقطوع: `Locked` · `create => VaultAlreadyExists` · البايتات لم تتغيّر · unlock «this vault file is truncated».

---

### رقم الحجم يُقطع فيساوي الحد (25==25)

**FIXED**

1. **ماذا فعلت:** `pdf_over_25mib.pdf` = 26214401 بايت (25 MiB + 1) وملف مُركَّب بنفس الطول. شاهد: `pdf_at_25mib.pdf` = 26214400 يُقبل.
2. **ماذا كان يجب:** الرسالة تميّز الحجم عن الحد.
3. **ماذا حدث:** `DocumentTooLarge { mib: 26, limit_mib: 25 }` والتفصيل `26214401 bytes is past the 25 MiB limit`. `div_ceil`. عند الحد تماماً يُقبل.

---

### Flutter «could not be opened safely» تُسقط اسم الحد

**FIXED** (شيفرة)

1. **ماذا فعلت:** قرأت `_document` في `messages.dart` بعد فروع الرفض الاثني عشر. الـcore يرفض `pdf_over_25mib` بـ`DocumentTooLarge` والقنبلة بـ`CompressionBomb`.
2. **ماذا كان يجب:** الحد يُطبَّق ويُقال.
3. **ماذا حدث:** لا `_ =>` تحت هذه الفروع. `DocumentTooLarge` → «This file is about $mib MiB, and Z Privacy opens documents up to $limitMib MiB.» · `CompressionBomb` تسمّي النسبة · `TextTooLarge` / `TooManyParts` / `TookTooLong` / `EmptyDocument` لكلٍّ جملة. `messages_test.dart` يمشي الاثني عشر.

---

### كتابة `.zs` بلا فحص بايتات القرص

**FIXED** (قياس؛ الشيفرة ما زالت بلا `disk_bytes`)

1. **ماذا فعلت:** 20 سباق عمليتين على `conversation_record` بعد `conversation_enter`، وحاجز ملف. واختبارهم `two_copies_never_lose_a_turn` (6 تجارب، 300 هوية).
2. **ماذا كان يجب:** لا تُفقد نوبة بصمت.
3. **ماذا حدث:** 20/20 النوبتان على القرص، `silent_lost=0`. اختبارهم نجح. `conversation::write` ما زال `seal_for` ثم `replace_atomically` بلا مقارنة. القفل حول `with_core` و`body()` التي تعيد القراءة من القرص يجعلان الثانية تقرأ نوبة الأولى ثم تضيف. القانون مُقاس.

---

## ملاحظة إضافية (لم تُطلب ضمن الستة، قيست مع القارئ)

`pdf_objstm_bomb.pdf` (49 KiB) كان يُقبل بـ~75 MiB RSS. الآن: `CompressionBomb { ratio: 201 }` — «an object stream unpacks…». `pdf_flate_cumul_16mib.pdf` كذلك يُرفض. ليس إعادة فتح للعيب السابق.

---

## العدّ

| السابق | الآن |
|---|---|
| Direct Mode (مانع) | **FIXED** |
| PDF Flate >8 MiB (مانع) | **FIXED** |
| قنبلة Flate كمسح (مانع) | **FIXED** |
| whatCameBack رمز مُعدَّل (مانع) | **خطير** (جملة سببين؛ السبب الأول ما زال يُقال على ذيل مُعبث في هذا البناء) |
| نسختان تكتبان (مانع) | **FIXED** (0/40 فقد صامت) |
| Delete identity (مانع) | **FIXED** |
| أول تشغيل بلا سويدية (خطير) | **خطير** (AT-SPI حيّ: Deutsch/English فقط) |
| مسارات المضيف (خطير) | **FIXED** (0 `/home/monopeaks`) |
| خزنة فارغة فخ (خطير) | **FIXED** |
| تقريب 25==25 (ملاحظة) | **FIXED** (`mib: 26`) |
| «could not be opened safely» (خطير) | **FIXED** |
| كتابة `.zs` (خطير) | **FIXED** بالقياس |

**مفتوح من هذه الجولة:** خطير 2 (whatCameBack · أول تشغيل بلا Svenska) · مانع 0.

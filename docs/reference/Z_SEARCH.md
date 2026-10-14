# جولة مقارنة — شريط البحث داخل الوثيقة

نسخة العمل `/home/monopeaks/mono-privacy-comparison-20261013-022102` · الفرع `comparison/local-cycle`.
Z Privacy: المنتج HEAD `d882c5f` · الختم `z_core 0.1.0 · 2026-10-13 · 61fa27b`.
تاريخ الأدلة: 2026-10-14.

**اختبارات Z وتجهيزاتها متوقفة.** لا تعديل للمنتج. الكوميتات محصورة في `tests/cycle/`. بلا دفع، بلا فرع على GitHub. القائد ينقل هذا الملف إلى الأوراق.

الأصل، والنسخة الاحتياطية، وGitHub، ومكتبة ZPrivacy-lib: بلا كتابة.

**القائمة:** المشاريع العشرة في `Z_COMPARISON.md` + أداتا مرجع خارج القائمة: Adobe Acrobat **Find text to redact**، وبحث Word. هما المعيار الذي يعرفه الناس.

**وسوم الدليل:** موثقة · مؤكدة من الكود · مختبرة · غير معلومة.
«غير موجود» يذكر أين نُظر. غياب `/analyze` من دليل مشروع لا يثبت غياب وظيفته. تشغيل المشاريع العشرة ليس شرطًا.

---

## السؤال

كيف تبحث التطبيقات الأخرى عن كلمة داخل وثيقة، وماذا تفعل بالنتيجة؟

لكل أداة، ستة أسئلة:

1. هل في الوثيقة شريط بحث أصلاً؟
2. ماذا يُطابق: الكلمة كاملة أم جزءًا منها؟ هل يفرّق بين الحروف الكبيرة والصغيرة؟ هل يقبل أنماطًا (regex)؟
3. عرض النتائج: هل يضيء كل المطابقات معًا؟ هل يعرض العدد (3 من 12)؟ هل فيه «التالي / السابق»؟
4. بعد البحث: هل يحمي/يحجب كل النتائج بضغطة واحدة؟ أم واحدة واحدة؟ هل يمكن استثناء موضع من الحماية؟
5. هل يُحفظ ما بحثت عنه؟ (تاريخ البحث يحفظ أسماء بنص واضح، وهذا يمسّ الخصوصية)
6. في واجهة بعمودين (أصل / ناتج): في أي عمود يقع البحث؟ وهل يمكن البحث عن رمز في العمود المحمي؟

---

## أين نُظر

**Z:** `apps/flutter_app/lib/screens/workspace.dart` (اختصارات لوحة المفاتيح، العمودان، حقل السؤال)، `document_text.dart` (العلامات الملوّنة)، `acts.dart` (Protect all matches)، `review.dart` / `bits.dart` (in N places)، `screens/vault.dart` (شريط بحث الخزنة)، `session_state.dart` (vaultQuery، suggested/automatic)، `z_core/src/text.rs` (`occurrences` / `stands_alone` / `whole_words`)، `ops/mod.rs` (`inspect_selection`، `protect_all_matches`، المسار التلقائي)، `ops/vault.rs` (`search_vault`)، `api.rs`، `config.rs` (منع تاريخ البحث)، `scanner/mod.rs` و`packs/people.rs` و`general_rules.rs` (Auto مقابل Suggest). بحث `search` / `Ctrl+F` / `keyF` في شجرة Flutter: لا ربط لشريط Find داخل الوثيقة. **لم يُختبَر شريط بحث في الواجهة** لأن اختبارات Z متوقفة.

**Acrobat:** [How to redact a PDF](https://www.adobe.com/acrobat/resources/how-to-redact-a-pdf.html) (صفحة Adobe، تاريخ الجلب 2026-10-14)؛ [How to search a PDF](https://www.adobe.com/acrobat/resources/how-to-search-pdf.html)؛ Experience League [Remove sensitive information](https://experienceleague.adobe.com/en/docs/document-cloud-learn/acrobat-learning/advanced-tasks/protect/redact) آخر تحديث 28 حزيران 2026؛ ملخصات Adobe Help «Search and redact text in Acrobat Pro» آخر تحديث 23 أيلول 2025 و5 تشرين الثاني 2025 (صفحات helpx رُفض جلب نصّها الكامل من هذا المضيف، فالاعتراف من مقتطفات الفهرس + الصفحات أعلاه)؛ [Creating and Using Custom Redaction Patterns](https://blog.adobe.com/en/publish/2011/05/11/creating-and-using-custom-redact) (regex في XML).

**Word:** [Find.Execute](https://learn.microsoft.com/en-us/office/vba/api/word.find.execute) (Microsoft Learn، `updated_at` 2024-01-23)؛ [Find text in a document](https://support.microsoft.com/en-us/word/find-text-in-a-document) (Word للويب)؛ [Find what you need with Microsoft Search](https://support.microsoft.com/en-us/office/foundations-experiences/find-what-you-need-with-microsoft-search) (تاريخ بحث Microsoft Search، وهو سطح غير Find داخل الوثيقة).

**العشرة:** README/إصدارات GitHub كما في `Z_COMPARISON.md`. بحث `search`/`find`/`Ctrl` في وثائق كل مشروع. لا استنساخ ولا تشغيل.

ما لا دليل عليه مكتوب **غير معلوم**.

---

## جدول مختصر

| # | الأداة | 1. شريط بحث في الوثيقة | 2. المطابقة | 3. العرض | 4. بعد البحث | 5. حفظ الاستعلام | 6. عمودان |
|---|---|---|---|---|---|---|---|
| — | **Z Privacy** `d882c5f` | لا في الوثيقة. نعم في شاشة الخزنة. | حماية التحديد: كلمة كاملة، بلا تفريق حالة، بلا regex. بحث الخزنة: جزء من النص، بلا حالة. | كل علامات المسح معًا؛ «in N places»؛ لا 3 من 12 ولا التالي/السابق كبحث. | Protect all matches ضغطة واحدة؛ استثناء صف مراجعة أو Not sensitive. | الخزنة: ذاكرة الجلسة فقط. ZCFG يمنع تاريخ البحث. | البحث ليس في أي عمود وثيقة. لا بحث عن رمز في العمود المحمي. |
| R1 | **Acrobat Find text to redact** · Acrobat Pro | نعم: حوار Search & Remove Text + شريط Find (Ctrl+F). | كلمة/عبارة؛ خيار كلمة كاملة أو جزء؛ Patterns جاهزة؛ regex عبر ملف XML. حالة Find العادي: خيار. حالة حوار الحجب: غير معلومة في الصفحات الحديثة. | قائمة مواضع مع مربعات؛ Check All؛ النقر يعرض الموضع. شريط Find: تكرار الحدوث واقتراحات. | Mark checked ثم Apply؛ يمكن إلغاء تحديد موضع. | اقتراحات أثناء الكتابة موثّقة. استمرار التاريخ: غير معلوم. | ليست واجهة أصل/ناتج. البحث على PDF الجاري حجبه. |
| R2 | **Word Find** · Word لسطح المكتب / Microsoft 365 | نعم: Ctrl+F لوحة التنقل. | افتراضيًا جزء من كلمة؛ Match case وWhole word اختياريان؛ Wildcards (ليست regex كاملة). | Highlight all افتراضي؛ أسهم التالي/السابق؛ قائمة نتائج. عدّاد «3 من 12»: غير معلوم من وثيقة Microsoft الأولى. | البحث لا يحمي. Replace / Replace All يستبدل. تخطي موضع: Find Next دون Replace. | Microsoft Search (Alt+Q) يحفظ تاريخًا. قائمة Find what: غير معلوم من وثيقة أولى. | ليست واجهة أصل/محمي. |
| 1 | OpenAI privacy-filter | لا (CLI/مكتبة). | مصنّف رموز 8 فئات، لا شريط Find. | لا. | لا مسار بحث→حماية. | لا. | لا. |
| 2 | packyme/privacy-filter | لا (مكتبة/بوابة). | regex + gitleaks على النص كاملًا. | لا. | POST `/redact` على الجسم كله. | لا. | لا. |
| 3 | Masquerade | لا شريط موثّق. | نموذج خارجي على نص PDF. | غير معلوم. | حجب PDF بعد الوسم. استثناء موضع من بحث: غير موجود في README. | غير معلوم. | لا عمودين أصل/ناتج موثّقين. |
| 4 | Presidio | لا (مكتبة/HTTP). | Recognizers (NER/regex). | لا. | OperatorConfig على النوع، لا على موضع بحث. | لا جلسات. | لا. |
| 5 | BentoPDF v2.8.8 | نعم في PDF Editor: search؛ Find & replace في تحرير النص. Redact أداة منفصلة يدوية. | Find & replace: تفاصيل الحالة/regex غير معلومة. | غير معلوم (وجود الأداة موثّق، سلوك العداد غير موثّق). | Redact Content حذف دائم بالنقر/المساحة، ليس «احمِ نتائج البحث». | غير معلوم. | ليست أصل/محمي. |
| 6 | OpenMed | لا (REST). | `extract_pii`. | لا. | anonymize على النص. | غير معلوم. | لا. |
| 7 | rizzo-pii 2.0.0 | **غير موجود** في README/`src/app` كما وُصف: لا Ctrl+F. | الوسم من النموذج+regex. | تظليل الوسوم الملوّنة؛ فلتر وسم على النوع. | إيقاف وسم يبقي النوع مكشوفًا (مستوى النوع لا الموضع). | غير معلوم. | يسار أصل (Anteprima/Testo)، يمين anonymized + PDF censurato. لا بحث عن رمز موثّق. |
| 8 | Censgate Redact v0.12.4 | لا (بوابة HTTP). | 61 نوعًا + NER اختياري. | لا. | `--entities` / `--disable` مستوى النوع. | جلسة الرموز مخزن منفصل، ليست تاريخ بحث. | لا. |
| 9 | Worka PII 0.1.0 | لا (crate). | regex/قواميس/NER. | لا. | operators لكل كيان. | غير معلوم. | لا. |
| 10 | Secret Guard luochen1990 0.1.0 | لا (بوابة شات). | أسرار معلنة في toml، مطابقة القيمة المعلنة. | لا. | الاستبدال على السلك لكل ورود السر المعلن. | القائمة على القرص بنص واضح (أسرار، ليست استعلامات بحث). | لا. |

---

## Z Privacy · `d882c5f` · مؤكدة من الكود

### 1. هل في الوثيقة شريط بحث؟

**لا.** مساحة العمل ليس فيها حقل Find ولا اختصار Ctrl+F.

- `workspace.dart` يربط Alt+Left وEscape فقط (`CallbackShortcuts` نحو 182–187). لا `LogicalKeyboardKey.keyF`.
- الحقل النصي في أسفل العمود الأصلي هو «What should the AI do with this?» (`workspace.dart` نحو 1950–1960)، ليس بحثًا.
- `document_text.dart` يرسم العلامات والتحديد، بلا `search`.
- بحث `search` في `lib/widgets`: لا شريط Find.

**نعم في شاشة أخرى:** الخزنة. `screens/vault.dart` نحو 238–264: `TextField` hint «Search this device — names, values, spellings»، يؤخر 180ms ثم `searchVaultFor`. ذلك بحث في الهويات المخزونة، لا في نص الوثيقة المفتوحة.

### 2. ماذا يُطابق؟

ليس هناك استعلام يكتبه المستخدم في الوثيقة. المسار البديل: **تحديد كلمة ثم عدّ المواضع**.

| القاعدة | الدليل | الوسم |
|---|---|---|
| التحديد ينمو إلى كلمات كاملة ثم يُنظَّف من علامات الحافة | `text.rs` `whole_words` 213–264، `EDGE_MARKS` 103–106 | مؤكدة من الكود |
| عدّ المواضع: `occurrences`، مقارنة **بلا تفريق حالة** (`case_blind_match`)، و**كلمة قائمة وحدها** (`stands_alone`) | `text.rs` 389–416 و543–577؛ `inspect_selection` يضع `matches: occurrences(...).len()` في `ops/mod.rs` 1271 | مؤكدة من الكود |
| جزء داخل كلمة لا يُعدّ مطابقة | `occurrences`: إن لم يقف وحده يتخطّى (`stands_alone`) | مؤكدة من الكود |
| regex من المستخدم | **غير موجود** في واجهة الوثيقة ولا في `inspect_selection` | مؤكدة من الكود (بحث `regex` كخيار بحث للمستخدم: لا) |
| بحث الخزنة: `contains` بعد NFC و`to_lowercase` — جزء من الحقل، بلا حالة | `ops/vault.rs` 378–393 | مؤكدة من الكود |

`SelectionView.matches` (`api.rs` 387–390): عدد المواضع التي يقف فيها **نفس النص** في هذه الوثيقة. الزر «Protect all matches» يظهر إذا كان العدد > 1 (`acts.dart` 59–65).

### 3. عرض النتائج

| السلوك | ماذا يفعل Z | الدليل |
|---|---|---|
| إضاءة كل المطابقات معًا | علامات المسح كلها تُرسم على العمود الأصلي في آن. التركيز أقوى غسلة | `document_text.dart` `_marked` 683–722؛ `focus` 293–297 |
| عدّاد 3 من 12 | **لا.** العدد هو «in N places» على صف المراجعة عندما N>1، أو شارة الزر `matches` | `review.dart` 272–273؛ `bits.dart` 393–394؛ `acts.dart` 61–64 |
| التالي / السابق | **لا** كبحث. قائمة المراجعة تنقل التركيز وتُمرّر العمود إلى العلامة | `workspace.dart` `_jumpIfMoved` 136–150؛ `focusOn` |

### 4. بعد «البحث» (بعد التحديد أو بعد المسح)

- **كل المواضع ضغطة واحدة:** `protect_all_matches` (`api.rs` 1934–1937) يحمي كل `occurrences` تحت **رمز واحد** (`ops/mod.rs` 1846–1871). الزر «Protect all matches».
- **موضع واحد:** Protect بلا `allMatches` (`acts.dart` 194–196).
- **استثناء موضع:** صف المراجعة: Protect / Always / Not sensitive / Later (`review.dart` `_Answers`). «Protect all N» على الاقتراحات المفتوحة، و«Leave all N in the clear» (`review.dart` 389–405). `teachException` يستثني قيمة من المسح لاحقًا (`api.rs` 1971–1974). Auto يحمي كل ورود النص في هذه الوثيقة بـ `Scope::Conversation` (`ops/mod.rs` 2446–2462).

هذا **ليس** «ابحث عن كلمة ثم احمِ النتائج». هو تحديد أو مسح، ثم حماية المواضع المطابقة.

### 5. هل يُحفظ ما بحثت عنه؟

**لا في ملف الإعداد.** `config.rs` 16–18: ZCFG «may never hold … or a search history». الملف خمسة حقول سلمية؛ لا خريطة تُكتب فيها استعلامات.

استعلام الخزنة يعيش في `Ground.vaultQuery` (`session_state.dart` 310–332)، ذاكرة العملية. لا تسلسل إلى `.zcfg` ولا إلى الجلسة. بحث الوثيقة غير موجود أصلًا فلا تاريخ له.

### 6. العمودان

من رأس `workspace.dart` 8–16: اليسار الأصل بعلامات المسح (لا استبدال، لا شبكة)؛ اليمين الطلب الذي سيُرسل.

- شريط بحث الوثيقة **لا يقع في أي عمود**.
- بحث الخزنة شاشة مستقلة.
- العمود المحمي (`SafeText` في `document_text.dart` 733–854) يرسم الرموز `__Z_…__` كرقائق أو نص. `SelectableText` بلا Find. لوحة Tokens تسرد الرموز (`acts.dart` 109–114) وليست بحثًا.
- **البحث عن رمز في العمود المحمي: غير موجود.**

---

## سؤال الأمس — الكلمة الملوّنة: تُحمى مباشرة أم تُقترح؟

**الاثنان، بلونين ولون ثالث لمن قرر.** ليست كل كلمة ملوّنة محمية.

القاعدة في الماسح (`scanner/mod.rs` 24–31): `Auto` = «لا يمكن أن يكون شيئًا آخر» فيحمي وحده؛ كل ما يحتاج نظرة ثانية = `Suggest`.

| اللون / الخط على الكلمة | المعنى | متى | تُحمى؟ |
|---|---|---|---|
| موجة كهرمانية (wavy amber) | `MarkState.suggested` — ما زالت النص الحقيقي، تنتظر كلمة الشخص | زوج قاموس الأسماء؛ تعارض هويتين في الخزنة | **تُقترح.** لا حماية حتى Protect / Always / Not sensitive |
| خط متقطع صلصالي (dashed clay) | طبقة قررت وحدها (`decided == false`) | IBAN/بريد/هاتف بتحقق؛ تحية+اسم؛ لقب+اسم؛ توقيع | **تُحمى مباشرة** بـ `Scope::Conversation` لكل ورود النص |
| خط متصل صلصالي (solid clay) | شخص قرر (`decided`) | Protect من التحديد أو من المراجعة | محمية بقرار اليد |
| غسلة نهرية (river wash) | الخزنة عرفت القيمة | `Source.vault` وAlways | Auto إن لم يكن تعارضًا |

الدليل البصري: `document_text.dart` 665–721. «Waiting beats the source»: الاقتراح موجة حتى لو وجدته طبقة.

أمثلة من الكود:

- IBAN/بريد/هاتف: `general_rules.rs` 1–10 و`Confidence::Auto` على المطابقة ذات التحقق.
- «Herr … / Dr. …»: `people.rs` `salutations` 401–407 و`titled_names` 441–448 → **Auto**.
- زوج القاموس «Thomas Müller»: `dictionary_names` 573–630 → **Suggest دائمًا** («offered, never protected»، «Never Auto»).
- المسار التلقائي يكتب الحماية: `ops/mod.rs` 2446–2462.

الملفان المظلَّلان Word وPDF: **لم يُرسَلا في هذه الجولة.** اختبارات Z متوقفة؛ لا توسيع التقاط ولا تشغيل معزول. يبقيان حين يتيسّر إرسال ملفَي عيّنة.

---

## أداتا المرجع

### R1 · Adobe Acrobat — Find text to redact · Acrobat Pro / Premium / Studio

وسم الوقائع أدناه: **موثقة**. لم تُختبَر على هذا المضيف. Find text and redact متاح في Acrobat Pro (وPremium/Studio) حسب Experience League 28 حزيران 2026.

**1. شريط بحث؟ نعم، اثنان.**

- مسار الحجب: All tools → Redact a PDF → **Find text and redact** → Search & Remove Text ([Experience League](https://experienceleague.adobe.com/en/docs/document-cloud-learn/acrobat-learning/advanced-tasks/protect/redact)؛ [How to redact a PDF](https://www.adobe.com/acrobat/resources/how-to-redact-a-pdf.html) الخطوة «Find Text & Redact»).
- بحث القراءة/التحرير: شريط Find، Ctrl+F / Command+F ([How to search a PDF](https://www.adobe.com/acrobat/resources/how-to-search-pdf.html)).

**2. المطابقة.**

- حوار الحجب: كلمة أو عبارة واحدة؛ كلمات متعددة (أو استيراد قائمة)؛ **Patterns** جاهزة: هاتف، بطاقة، بريد، رقم ضمان اجتماعي، تواريخ. لغة الأنماط من التفضيلات.
- **Redaction Mark Options:** وسم الكلمة كاملة أو جزء منها (عدد الأحرف ومكانها) — مفيد لترك آخر أرقام البطاقة ظاهرة. ملخص Adobe Help 23 أيلول 2025 + دليل Acrobat الأقدم «Removing sensitive content».
- Regex للمستخدم داخل الحوار: **لا** كمربّع «regex». الأنماط المخصّصة: تعديل `SearchRedactPatterns.xml` بحقل `regEx` ([مقالة Adobe 2011](https://blog.adobe.com/en/publish/2011/05/11/creating-and-using-custom-redact)).
- شريط Find العادي: خيار Whole words only وCase sensitivity ([How to search a PDF](https://www.adobe.com/acrobat/resources/how-to-search-pdf.html)). Stemming وBoolean في البحث المتقدم متعدد الملفات. حالة حوار الحجب تحديدًا في الواجهة الحديثة: **غير معلومة** من الصفحات المجلبة (دليل Acrobat X ذكر خيار capitalization؛ الصفحة الحالية لا تعيده صراحة).

**3. العرض.**

- قائمة نتائج تحت اسم الملف؛ + لفتح كل ورود؛ النقر على بند يعرضه في الصفحة؛ Check All / مربعات فردية.
- شريط Find: «frequency of occurrences» واقتراحات أثناء الكتابة. أسهم التالي/السابق في شريط Find **موثقة** كسلوك شريط البحث العام. عدّاد بصيغة «3 من 12»: **غير معلوم** من الصفحات المجلبة.
- AI Assistant (مسار حديث منفصل): يبرز المطابقات ويعرض عددها، مع Don’t redact this / Redact all. ذلك **ليس** حوار Find text to redact الكلاسيكي.

**4. بعد البحث.**

- تحديد المواضع → **Mark checked results for redaction** → **Apply**. الحذف النهائي عند الحفظ. Sanitize اختياري.
- استثناء موضع: إلغاء تحديد مربّعه قبل الوسم، أو حذف علامة الحجب قبل الحفظ (دليل Acrobat: Delete على العلامة إن لم يُحفظ الملف).
- Check All ثم استثناء: نعم عبر المربعات.

**5. حفظ الاستعلام.**

- اقتراحات أثناء الكتابة موثّقة على شريط Find. هل تُكتب أسماء العملاء في تاريخ دائم: **غير معلوم**.
- نتائج البحث يمكن حفظها PDF أو CSV في دليل Acrobat X (Rick’s Acrobat X Redaction Guide)؛ استمرار ذلك في الواجهة الحالية: **غير معلوم**.

**6. عمودان.** Acrobat يعرض PDF واحدًا تُعلَّم عليه الحجب. ليست أصل/ناتج جنبا إلى جنب. البحث يقع على المستند الجاري حجبه. البحث عن رمز حماية كـ `__Z_…__`: غير منطبق على منتج Acrobat.

---

### R2 · Microsoft Word — Find · Word لسطح المكتب / Microsoft 365

وسم الوقائع: **موثقة**. لم تُختبَر هنا.

**1. شريط بحث؟ نعم.** Ctrl+F يفتح لوحة التنقل وحقل البحث في الوثيقة ([Find text in a document](https://support.microsoft.com/en-us/word/find-text-in-a-document) لـ Word على الويب؛ نفس الاختصار على سطح المكتب يفتح Navigation pane — Microsoft Q&A وVBA `Find.Execute` يصفان حوار Find and Replace).

**2. المطابقة.** [Find.Execute](https://learn.microsoft.com/en-us/office/vba/api/word.find.execute):

- `MatchWholeWord`: كلمة كاملة فقط.
- `MatchCase`: تفريق الحالة.
- `MatchWildcards`: عوامل خاصة (`*`, `?`, `[]`…). **ليست regex كاملة** (Microsoft لا تسميها regex؛ التعليق في Learn: «special search operator»).
- كذلك Sounds like، All word forms، Match prefix/suffix، Ignore space/punct.
- الافتراضي بلا هذه الأعلام: جزء من كلمة، بلا حالة.

**3. العرض.**

- Highlight all خيار افتراضي في لوحة التنقل الحديثة (Office Watch 2023 يصف الخيار كافتراضي Microsoft؛ ليست صفحة Learn. الوسم هنا: موثقة كوصف شائع، **غير مختبرة**).
- أسهم التالي/السابق في اللوحة؛ قائمة نتائج الفقرات.
- إغلاق اللوحة يزيل الإبراز المؤقت (وصف طرف ثالث). عدّاد «3 من 12» كرقم صريح: **غير معلوم** من Microsoft Learn. وجود قائمة نتائج وأسهم: موثّق سلوكًا.

**4. بعد البحث.**

- Find **لا يحمي ولا يحجب**. Replace وReplace All (`WdReplace`) يستبدلان النص.
- تخطي موضع: Find Next دون Replace، أو Replace واحدًا واحدًا مقابل Replace All.
- Reading Highlight يبرز للقراءة؛ ليس حماية.

**5. حفظ الاستعلام.**

- **Microsoft Search** (مربع أعلى التطبيق، Alt+Q) يحفظ تاريخ بحث يمكن تنزيله أو مسحه من إعدادات الخصوصية ([Find what you need with Microsoft Search](https://support.microsoft.com/en-us/office/foundations-experiences/find-what-you-need-with-microsoft-search)). ذلك سطح أوامر/ملفات، وقد يحتوي كلمات من الوثيقة إن بُحث عنها هناك.
- قائمة «Find what» في حوار Advanced Find كقائمة أحدث استخدام: **غير معلوم** من وثيقة Microsoft الأولى (سلوك شائع غير مثبت هنا).
- إبراز Find في اللوحة يزول عند إغلاقها؛ الاستعلام نفسه ليس بالضرورة مكتوبًا في الملف.

**6. عمودان.** Word وثيقة واحدة. لا عمود محمي. لا بحث عن رمز حماية.

---

## المشاريع العشرة

لكل صف: أين نُظر. تشغيل المشروع ليس شرطًا. غياب شريط البحث من README **لا** يُوسَّع إلى «المشروع لا يستطيع مطابقة نص» — المطابقة عند معظمهم محرّك إخفاء، لا Find للمستخدم.

### 1 · OpenAI privacy-filter

[openai/privacy-filter](https://github.com/openai/privacy-filter) · إعلان 22 نيسان 2026.

نظر: README الرئيسي (جلب سابق في الدراسة). CLI `opf`، مصنّف محلي 8 فئات. لا تطبيق وثيقة، لا Ctrl+F، لا حوار Find.

1 لا. 2 المطابقة تصنيف رموز لا استعلام مستخدم. 3 لا. 4 لا «احمِ نتائج البحث». 5 لا. 6 لا.
**موثقة · غير مختبرة.**

### 2 · packyme/privacy-filter

[packyme/privacy-filter](https://github.com/packyme/privacy-filter) · README 2026-10-13.

نظر: README. regex + gitleaks، `POST /redact`. «no un-redaction».

1 لا شريط وثيقة. 2 المحرّك regex على الجسم. 3 لا إبراز مواضع للمستخدم. 4 الطلب يعالج النص كله. استثناء موضع من نتائج بحث: غير موجود. 5 لا. 6 لا.
**موثقة · غير مختبرة.**

### 3 · Masquerade · postralai/masquerade

README 2026-10-13. PDF→نص ثم Tinfoil Llama ثم حجب PDF.

نظر: README وfaq.md في الجولة السابقة. لا ذكر لشريط Find داخل المعاينة. الحجب ناتج النموذج لا ناتج استعلام.

1 **غير موجود** في README/faq كما نُظرا. 2 غير منطبق كبحث مستخدم. 3 غير معلوم. 4 الحجب على ما وسمه النموذج؛ استثناء موضع من بحث: غير موجود في الدليل. 5 غير معلوم. 6 لا عمودين أصل/ناتج موثّقين.
**موثقة في حدود الدليل · غير مختبرة.**

### 4 · Presidio · data-privacy-stack/presidio

دليل [anonymizer](https://presidio.dataprivacystack.org/anonymizer/) 2026-10-13.

مكتبة/HTTP. «does not store or maintain stateful sessions».

1 لا. 2 recognizers. 3 لا. 4 OperatorConfig على **نوع** الكيان. 5 لا تاريخ بحث؛ لا جلسات. 6 لا.
**موثقة · غير مختبرة.**

### 5 · BentoPDF · alam00000/bentopdf · [v2.8.8](https://github.com/alam00000/bentopdf/releases/tag/v2.8.8) 29 آب 2026 `f96cd4e`

نظر: README؛ [Tools Reference](https://www.bentopdf.com/docs/tools/)؛ ملاحظات v2.8.8.

- PDF Editor: «Annotate, highlight, redact, comment, add shapes/images, **search**, and view PDFs» (README جدول Edit).
- v2.8.8: «**Find & replace** across the document» في تحرير النص.
- **Redact Content** أداة منفصلة: حذف دائم بالنقر/المساحة. Sanitize لا يحذف الكلمات الظاهرة.

1 **نعم** search في المحرّر، وFind & replace في تحرير النص. ذلك شريط بحث وثيقة. **ليس** مربوطًا صراحة بأداة Redact كـ Acrobat Find text to redact.
2 تفاصيل whole-word / case / regex لـ Find & replace: **غير معلومة** (وجود الأداة موثّق، قواعد المطابقة لا).
3 العداد والتالي/السابق: **غير معلوم**.
4 Redact يدوي. Find & replace يستبدل نصًا، لا يحجب. ربط «نتائج البحث → Redact all»: **غير موجود** في ملاحظات الإصدار.
5 غير معلوم.
6 ليست أصل/محمي. البحث في المحرّر على PDF الواحد.
**موثقة (وجود Find) · تفاصيل السلوك غير معلومة · غير مختبرة.**

### 6 · OpenMed · maziyarpanahi/openmed

[`docs/anonymization.md`](https://github.com/maziyarpanahi/openmed/blob/master/docs/anonymization.md) 2026-10-13.

REST `extract_pii` / anonymize / `reidentify`. يشق `first_name` / `last_name`.

1 لا شريط وثيقة. 2 المحرّك نموذجي. 3 لا. 4 anonymize على النص/الأنواع. 5 الخريطة عند المستدعي إن `keep_mapping`؛ ليست تاريخ بحث. 6 لا.
**موثقة · غير مختبرة.**

### 7 · rizzo-pii · Rizzo-AI-Academy/rizzo-pii · تطبيق 2.0.0 · نموذج v1.5.0

نظر: README الرئيسي 2026-10-14 (جلب كامل، كلمتا «search» مرتان: إحداهما «values too short to search safely»، والأخرى ليست شريط Find). لا `Ctrl` ولا `find` في README. وصف العمودين: يسار Anteprima PDF / Testo؛ بعد الإخفاء يمين highlighted preview + raw + **PDF censurato**. فلتر الوسوم: كل وسم من 23 يمكن إطفاؤه فيبقى مكشوفًا (مستوى **النوع**).

1 **غير موجود** في README كما نُظر. الواجهة وثيقة نعم، شريط Find لا دليل عليه.
2 المطابقة نموذج+regex/checksum، لا استعلام مستخدم.
3 تظليل الوسوم الملوّنة في المعاينة. لا عدّاد 3 من 12 موثّق. لا التالي/السابق كبحث.
4 إيقاف وسم = استثناء **نوع** لا موضع. لا «احمِ نتائج هذا البحث».
5 غير معلوم.
6 نعم عمودان (ثلاثة عروض بعد الإخفاء). البحث عن `[FULLNAME_1]` في العمود المحمي: **غير موجود** في README.
**موثقة · غير مختبرة.** واجهة وُصفت ولم تُشغَّل.

### 8 · Censgate Redact · censgate/redact · بوابة v0.12.4 · redact-core 0.12.5

نظر: README وtokenization.md في الدراسة السابقة. HTTP `/v1/redact` و`/v1/restore`. لا تطبيق وثيقة.

1 لا. 2 كاشف أنواع. 3 لا. 4 `--entities` / `--disable`. 5 TokenMapStore جلسة رموز، ليست استعلامات. 6 لا.
**موثقة · غير مختبرة.**

### 9 · Worka PII · worka-ai/pii · crate 0.1.0

نظر: README في الدراسة السابقة. مكتبة نص.

1 لا. 2 regex/قواميس/NER. 3 لا. 4 operators. 5 أثر تدقيق بالذاكرة؛ تاريخ بحث: غير معلوم / غير منطبق. 6 لا.
**موثقة · غير مختبرة.**

### 10 · Secret Guard · [luochen1990/secret-guard](https://github.com/luochen1990/secret-guard) · secret-guard-rs 0.1.0 · [v0.1.0](https://github.com/luochen1990/secret-guard/releases/tag/v0.1.0) 23 أيلول 2026 `50bbdf5`

نظر: README وdocs/configuration.md في الدراسة السابقة. بوابة شات؛ أسرار معلنة `[[secrets.entries]]`. لا عارض وثيقة.

1 لا. 2 مطابقة القيمة المعلنة (طول/مجموعة أحرف للـ Mock). ليست Find. 3 لا. 4 كل ورود السر المعلن على السلك. لا استثناء موضع من نتائج بحث. 5 `secret-guard.toml` و`secret-guard.state.toml` يحفظان **الأسرار بنص واضح** — خصوصية، لكنها قائمة أسرار لا تاريخ بحث. 6 لا.
**موثقة · غير مختبرة.**

مشروع Codeberg llm-secretguard إضافة حادية عشرة كما في `Z_COMPARISON.md`، خارج هذه الجولة.

---

## سجل ادّعاءات Z — ملف وسطر

| الادّعاء | الملف | الوسم |
|---|---|---|
| لا Ctrl+F / لا Find في مساحة العمل | `workspace.dart` 182–187 (Alt+Left, Escape فقط) | مؤكدة من الكود |
| حقل النص في الوثيقة سؤال للنموذج | `workspace.dart` 1944–1960 | مؤكدة من الكود |
| شريط بحث الخزنة | `vault.dart` 238–264؛ `api.rs` 2247–2254؛ `ops/vault.rs` 372–393 | مؤكدة من الكود |
| بحث الخزنة لا يفشي أي حقل طابق | `ops/vault.rs` 374–377؛ `api.rs` 2249–2252 | مؤكدة من الكود |
| `occurrences` بلا حالة + كلمة وحدها | `text.rs` 389–416، 543–577 | مؤكدة من الكود |
| `matches` عدد المواضع | `api.rs` 387–390؛ `ops/mod.rs` 1271 | مؤكدة من الكود |
| Protect all matches رمز واحد | `api.rs` 1934–1937؛ `ops/mod.rs` 1846–1871؛ `acts.dart` 59–65 | مؤكدة من الكود |
| in N places | `review.dart` 272–273 | مؤكدة من الكود |
| إبراز كل العلامات؛ التركيز أقوى | `document_text.dart` 665–722 | مؤكدة من الكود |
| ZCFG يمنع تاريخ البحث | `config.rs` 16–18 | مؤكدة من الكود |
| vaultQuery ذاكرة فقط | `session_state.dart` 310–332 | مؤكدة من الكود |
| العمودان أصل / طلب | `workspace.dart` 8–16، 1400–1413 | مؤكدة من الكود |
| العمود الآمن رقائق رموز بلا Find | `document_text.dart` 733–854 | مؤكدة من الكود |
| Auto يحمي؛ Suggest ينتظر | `scanner/mod.rs` 24–31؛ `ops/mod.rs` 2446–2462؛ `people.rs` 573–630 | مؤكدة من الكود |
| الموجة = مقترح؛ المتقطع = طبقة؛ المتصل = شخص | `document_text.dart` 674–720 | مؤكدة من الكود |

اختبار شريط البحث في الواجهة: **غير مختبر** (التوسعة متوقفة).

---

## الخاتمة

### ما تفعله أداة واحدة على الأقل، ولا يفعله Z

1. **شريط Find داخل الوثيقة** (Ctrl+F، حقل، التالي/السابق). Word وAcrobat يفعلانه. BentoPDF يوثّق search وFind & replace في محرّر PDF. Z لا يربط Ctrl+F ولا يضع حقلًا على النص.
2. **البحث ثم الحجب من قائمة نتائج بمربعات.** Acrobat Find text to redact: Search & Remove Text → Check All أو فكّ موضع → Mark checked → Apply. Z يحمي من **تحديد** أو من **مسح**، لا من استعلام مكتوب.
3. **أنماط جاهزة وregex للمستخدم.** Acrobat Patterns (هاتف، بطاقة، بريد، SSN، تاريخ) وregex عبر XML. Word Wildcards. Z لا يقدّم regex في الواجهة.
4. **كلمة كاملة أو جزء، وخيار الحالة، كإعدادات بحث.** Word `MatchWholeWord` / `MatchCase`. Acrobat شريط Find. مطابقة حماية Z كلمة كاملة بلا حالة **دائمًا**، بلا مفتاح يفتح الجزء.
5. **Replace All على نص الوثيقة.** Word. BentoPDF Find & replace. Z يستبدل بقيمة رمز حماية، لا يستبدل النص الظاهر في الأصل.
6. **حجب جزء من المطابقة** (آخر أرقام البطاقة). Acrobat Redaction Mark Options / partial words. Z يحمي الامتداد كاملًا بعد `whole_words`.
7. **البحث في مجلد من الملفات.** Acrobat Search panel: current PDF أو كل PDF في موقع. Z يبحث الخزنة على هذا الجهاز، لا مجلد وثائق.
8. **تاريخ بحث قد يحمل أسماء.** Microsoft Search يحفظ استعلامات. Acrobat يقترح أثناء الكتابة. Z يمنع كتابة تاريخ البحث في الملف غير المعمّى — وذلك فرق سياسة، لا فرق «شريط».

### ما يفعله Z وحده (بين الاثني عشر على هذا المحور)

لا يُدَّعى اختراع مبدأ «اعثر ثم احمِ». Acrobat يفعل ذلك صراحة. ما لم يُرَ مجتمعا عند الآخرين في هذه الجولة:

1. **بحث خزنة يقرأ الأسرار ويعيد صفوف هويات فقط، بلا ذكر أي حقل طابق.** Acrobat وWord يعرضان المطابقة نفسها على الشاشة. rizzo يعرض الوسم الملوّن. لا أداة في العشرة وثّقت بحثًا على قيم مخزونة بهذا العقد.
2. **منع تاريخ البحث بالنص الواضح في عقد ملف الإعداد** (`config.rs`: الحقل غير موجود فلا يُكتب). Word/Acrobat لا يعلنان هذا المنع على Find.
3. **مطابقة مواضع من التحديد، كلمة كاملة، بلا حالة، عبر كسر السطر، ثم حماية كل المواضع برمز واحد، مع استثناء صف مراجعة أو قيمة من المسح.** المسار ليس شريط بحث؛ هو التحديد + `occurrences` + `protect_all_matches` + Review. Acrobat يقترب (قائمة + مربعات) لكنه يحذف نهائيًا ولا يصدر رمز استرداد.
4. **عمودان أصل / ما سيُرسل، والبحث متعمَّد الغياب عن كليهما.** لا بحث عن `__Z_…__` في العمود المحمي. الرموز تُقرأ كرقائق أو من لوحة Tokens. rizzo له عمودان لكنه لا يوثّق بحثًا عن `[TAG_n]` في الناتج.
5. **لغة لونية تفصل المقترَح عن المحمي تلقائيًا عن المحمي باليد** (موجة / متقطع / متصل). ذلك جواب سؤال الأمس، وليس شريط بحث، وهو ما لا تفعله Word (إبراز مؤقت لكل المطابقات باللون نفسه) ولا Acrobat (علامات حجب موحّدة بعد الوسم).

### قراءة المنتج

معيار الناس (Word / Acrobat) هو: **اكتب كلمة، انظر المواضع، تحرّك بينها، ثم (عند Acrobat) احجب ما اخترت.** Z اختار مسارًا آخر: **الماسح يلوّن، واليد تحدّد، و«كل المواضع» زر على التحديد.** شريط البحث داخل الوثيقة غائب. بحث الخزنة حاضر ومحكوم بعقد خصوصية (لا يفشي الحقل، لا يُؤرَّخ في ZCFG).

أقرب منتج في العشرة إلى «واجهة وثيقة ذات عمودين» هو **rizzo-pii** (أصل / ناتج مظلّل) بلا شريط Find موثّق. أقرب منتج في العشرة إلى «Find داخل PDF» هو **BentoPDF** (search + Find & replace) بلا ربط موثّق من البحث إلى الحجب الجماعي. المعيار الذي يعرفه الناس لهذا السؤال يبقى Acrobat Find text to redact.

لا تفوّق ولا تفرّد لمبدأ الإيجاد. الفرق المدعوم: Z لا يقدّم Find الوثيقة، ويقدّم بحث خزنة صامتًا عن سبب المطابقة، ويمنع أرشفة الاستعلام في الملف الواضح.

# دراسة مقارنة — ثلاثة محاور · القائمة الأصلية لعشرة مشاريع

نسخة العمل `/home/monopeaks/mono-privacy-comparison-20261013-022102` · الفرع `comparison/local-cycle`.
Z Privacy: المنتج HEAD `d882c5f` · الختم `z_core 0.1.0 · 2026-10-13 · 61fa27b`.
تاريخ الأدلة: 2026-10-13. هذه النسخة تصحّح استمرارية Z وفق قياس 13 تشرين الأول على `d882c5f` (Always/Profile تعيش؛ Once/Conversation تموت)، وتضيف محورَي **الاختيار** و**الوثائق العائدة** للمشاريع العشرة.

**اختبارات Z وتجهيزاتها متوقفة.** لا تعديل للمنتج. الكوميتات محصورة في `tests/cycle/`. بلا دفع.

الأصل، والنسخة الاحتياطية، وGitHub، ومكتبة ZPrivacy-lib: بلا كتابة. المكتبة خارج المقارنة.

**وسوم الدليل:** موثقة · مؤكدة من الكود · مختبرة · غير معلومة. «غير موجود» يذكر أين نُظر.
غياب `/analyze` من دليل مشروع لا يثبت غياب وظيفته. تشغيل المشاريع العشرة ليس شرطًا للتسليم. لم يُستبدل أي اسم في القائمة الأصلية. مشروع Codeberg يُذكر كإضافة حادية عشرة، لا كبديل عن الصف العاشر.

**رأي المنتج:** مبدأ الاستبدال ثم الاسترداد مشترك. Always يعيش في الخزنة وConversation يموت مع العملية: ذلك مقيس. لا مشروع في العشرة يوثّق استيراد وثيقة مصدَّرة مختلفة تحمل عنصرًا نائبًا واحدًا واسترداد قيمته من مفاتيح المنتج. ذلك مرشّح لفرق Z الأوضح، ولم يُثبت بعد كمسار منتج عند Z نفسه على PDF عائد مختلف.

---

## المحاور الثلاثة

1. **إيجاد مناطق الحماية:** نموذج محلي أو خارجي، قواعد، قوائم، أو تحديد يدوي.
2. **الحماية والاسترداد:** حذف أو استبدال أو تشفير؛ كيف تُستعاد القيم وأين تُحفظ المفاتيح أو الخرائط.
3. **النطاق:** شات، PDF، أو كلاهما. **دعم مباشر** = مسار المنتج نفسه. **تكامل يدوي** = نسخ/لصق أو رفع لاحق أو بوابة يركّبها المدمج.

في محور الحماية عند Z تبقى ثلاثة أمور مستقلة: نطاق إعادة حماية **الكلمة**، مكان حفظ **الوثيقة**، ومفتاح استرداد **الجلسة**. لا يُستنتج أحدها من زر يخص الآخر. حفظ مفتاح الجلسة وحده لا يثبت إمكانية الاسترداد بعد إغلاق التطبيق.

---

## مفاتيح الجلسات وخرائط القيم — لا تُطوى في مفهوم واحد

الاسترداد القابل للعكس يظهر في خمسة منتجات من القائمة (+Z). الشكل مختلف، فلا يُقال إن كلها «خريطة قيم» أو كلها «مفتاح جلسة».

| المنتج | ماذا يُحفظ | أين يعيش | ماذا يلزم للاسترداد | متى يختفي |
|---|---|---|---|---|
| **Z Privacy** `d882c5f` | الخزنة تحفظ رقم الجلسة ومقبضها و**32 بايت**. ملف `sessions/N.zs` (صيغة v2) يحفظ السؤال والجواب الخام و**أسماء الرموز المسموحة** (`Turn.allowed: Vec<String>`)، لا خريطة القيم. Always/Profile: `ValueRecord` في جسم الخزنة عبر `learn_value`. | `sessions/*.zs` **خارج** `vault.zv`. **TokenStore حي في ذاكرة منصة الوثيقة** (`session.rs:157`، يولد فارغًا في `:217`، لا يُسلسل؛ `vault/format.rs` بلا رموز). | `restore(raw, store, allowed)` يعيد القيمة إن كان الرمز في القائمة **و** في TokenStore. الاسم MAC أحادي الاتجاه. **المفتاح وحده لا يكفي** (مؤكد قياسًا وكودًا). Always يُشفى عند إعادة فتح **نفس الوثيقة** ذات النص الواضح. | Once/Conversation تموت مع إغلاق التطبيق. Always/Profile تبقى في الخزنة. بعد إعادة تشغيل باردة: كل الرموز `unresolved` حتى تُفتح الوثيقة. |
| **rizzo-pii** تطبيق 2.0.0 / نموذج v1.5.0 | قاموس محلي `placeholder → قيمة`. | على القرص داخل العملية؛ يمكن إطفاؤه. | القاموس. `POST /pdf` يبنيه داخليًا **ولا يرسله على السلك**. | `PII_MAPPING=0` / `--no-mapping` / `include_mapping: false`: لا تُبنى خريطة، ولا تُعاد القيم الأصلية في `segments`. عندها لا يوجد مفتاح استرداد. |
| **OpenMed** `docs/anonymization.md` | JSON `mapping` يُرجع مع `keep_mapping=True`. | عند **المستدعي**، منفصلًا. | `reidentify(text, mapping)`. التكرار يأخذ أرقامًا (`[first_name]`, `[first_name_2]`). | بلا `keep_mapping` الطريقة نفسها غير عكسية. `SurrogateVault` يخزن HMAC→بديل لا السطح الخام؛ ذلك ثبات أسماء مستعارة عبر وثائق، لا مفتاح استرداد للأصل. |
| **Censgate Redact** `redact-core` 0.12.5 / بوابة v0.12.4 | `TokenMapping` مختوم AES-256-GCM. المخزن يرى ciphertext فقط. | `TokenMapStore` تحت `(tenant, session)`: `off` (افتراضي) أو `memory` TTL أو `vault_kv2`. | `POST /v1/restore` بـ `session_id` (أو alias `vault.context_id`) + DEK العملية (`CENSGATE_TOKEN_DEK`). على مسار الرد إن `restore_responses`. | `off`: داخل الطلب الذي أنشأ الرموز فقط، بلا `/v1/restore` لاحق. `memory`: لا يعيش إعادة التشغيل. TTL افتراضي 3600 ث. |
| **Secret Guard** [luochen1990/secret-guard](https://github.com/luochen1990/secret-guard) `secret-guard-rs` **0.1.0** | قائمة أسرار **معلنة**: `[[secrets.entries]]` في `secret-guard.toml`، والحالة الديناميكية في `secret-guard.state.toml` (**أسرار بنص واضح**). الـ Mock حتمي ومستقر عبر الجولات. | ملفان TOML على القرص عند المضيف. السجل في الذاكرة (`records_capacity` افتراضي 1024). | الاسترداد = عكس الـ Mock إلى القيمة المعلنة في القائمة. FWD-1 / RED-* في العقود. | ما دامت القائمة في الإعداد. حذف `state.toml` يعيد الإعداد التصريحي. كشف الأسرار غير المعلنة **خارطة طريق** (تنبيه لا استبدال تلقائي). |

**ما ليس خريطة جلسة:** packyme يعلن «no un-redaction». OpenAI privacy-filter لا يوثّق خزنة استرداد. Presidio يعيد **التشفير AES** بمفتاح في `OperatorConfig` لدى المستدعي، ويصرّح أنه لا يحفظ جلسات. BentoPDF حذف دائم. Worka يسجّل الأصل بجانب البديل في أثر تدقيق بالذاكرة؛ خريطة جلسات دائمة غير موثّقة.

**ليسا صف القائمة:** [diff-lab-com/secret-guard](https://github.com/diff-lab-com/secret-guard) crates.io **0.1.0** (HMAC `SG1:` + سجل عند المضيف) سرق اسم crates.io `secret-guard` في 2026-09-09 حسب تعليق Cargo.toml عند luochen؛ لذلك نُشر الأصل باسم `secret-guard-rs`. [codeberg.org/roobai/llm-secretguard](https://codeberg.org/roobai/llm-secretguard) v0.3.6 إضافة حادية عشرة أدناه، لا بديلاً عن الصف العاشر.

---

## مسار استرداد Z بعد إعادة التشغيل — سجل مصحّح 13 تشرين الأول 2026

قياس على `z_core` `d882c5f`. مسبار هيكلي + سلوكي متفقان. **المفتاح وحده لا يكفي:** مؤكد.

### الحكم

| النطاق | بعد إغلاق التطبيق | الآلية | الوسم |
|---|---|---|---|
| **Always** و **Profile** | تعيش وتُسترد بعد إعادة التشغيل **عند إعادة فتح نفس الوثيقة** ذات النص الواضح | `learn_value` يكتب `ValueRecord` في جسم الخزنة (`ops/vault.rs`). المسح `vault_pass` يجد النص في `original_str` بثقة Auto (`scanner/mod.rs` سياسة `Policy::Always`) فيعيد `protect_range` إدخال القيمة في TokenStore. | مؤكدة من الكود · **مختبرة** (مسبار القائد) |
| **Once** و **Conversation** | **تموت** عند إغلاق التطبيق | TokenStore ذاكرة فقط: `session.rs:157`، يولد فارغًا `:217`، بلا `Serialize`. `vault/format.rs` لا يحمل رموزًا (بحث `tokens` في الملف: صفر). ملف الجلسة يحفظ أسماء `allowed` فقط. | مؤكدة من الكود · **مختبرة** (مسبار القائد) |

### أرقام المسبار (13 تشرين الأول، `d882c5f`)

ثلاث حمايات → إعادة تشغيل باردة: **3 unresolved** (كلٌّ باسمه) → إعادة فتح **نفس الوثيقة**: **2 unresolved** (Always شُفي).

ذلك يوافق الكود: بعد البرد المخزن فارغ فكل الرموز غير محلولة؛ إعادة فتح الأصل الواضح تعيد إدخال قيمة Always فقط.

### ما ثبت من الكود (`d882c5f`)

| المادة | أين تُحفظ | كيف تُحمَّل مجددًا | الوسم |
|---|---|---|---|
| مفتاح الجلسة 32 بايت | سجل `Conversation` في `vault.zv` | `enter` / `naming_of` يشتق `Naming` | مؤكدة من الكود |
| أسماء الرموز المسموحة | `sessions/N.zs` v2، `Turn.allowed` | `conversation::read` | مؤكدة من الكود |
| السؤال والجواب الخام | نفس `.zs` | نفس المسار | مؤكدة من الكود |
| Always / Profile | `ValueRecord` في كيانات الخزنة (`vault/model.rs:29`) | `hints_for` → `vault_pass` ضد النص الحي → `protect_range` يملأ TokenStore | مؤكدة من الكود |
| TokenStore | RAM على منصة الوثيقة | لا مسار تسلسل. `name_tokens_from_the_vault` يضبط الاشتقاق فقط | مؤكدة من الكود |

تعليق `session.rs` نحو 476 يخص `open_conversation` لا TokenStore.

`turns()` بلا منصة مملوءة: كل رمز `unresolved`. `Naming::tail` أحادي الاتجاه: المفتاح لا يعكس الرمز.

### ما ثبت من التجربة السابقة (دورة المقارنة)

- استرداد سبعة رموز في الشات داخل العملية الحية: **مختبرة**.
- تصدير PDF محمي 28 رمزًا نطاق `1F52`: **مختبرة** استخراجًا.

استيراد **PDF محمي** (رموز بلا قيم واضحة) بعد البرد: المسح يبحث عن نص Always في `original_str`. إن كان الأصل رموزًا، لا مسار في الكود يملأ TokenStore من `ValueRecord` بإعادة اشتقاق الأسماء دون ظهور القيمة. **غير موجود** في `scan` / `restore` / `enter` / `name_tokens_from_the_vault`.

---

## الجدول

| # | المشروع والإصدار | 1. إيجاد مناطق الحماية | 2. الحماية والاسترداد | 3. النطاق | الوسم |
|---|---|---|---|---|---|
| — | **Z Privacy** · `d882c5f` · `z_core 0.1.0` | قواعد محلية + قوائم أسماء + سحب/نقر على كلمة + قائمة مراجعة. IBAN/بريد/هاتف تلقائيًا؛ الأسماء تحتاج قرارًا. | استبدال `__Z_<ns>_<KIND>_<tail>__`. Always/Profile: `ValueRecord` في الخزنة وتُشفى بعد إعادة فتح نفس الوثيقة. Once/Conversation تموت مع العملية. المفتاح وحده لا يكفي. مسبار: 3 حمايات → برد: 3 unresolved → إعادة فتح الوثيقة: 2 unresolved. | شات: إرسال داخل التطبيق (**مباشر**). PDF: تصدير صفحة محمية (**مباشر**). استيراد PDF عائد مختلف يحمل عنصرًا نائبًا: **غير موجود** في مسار الاستيراد. | إيجاد/حفظ: **مؤكدة من الكود**. شات وPDF المصدَّر: **مختبرة**. الاستمرارية: **مختبرة** (مسبار 13 تشرين الأول). |
| 1 | **OpenAI privacy-filter** · [openai/privacy-filter](https://github.com/openai/privacy-filter) · إعلان [22 Apr 2026](https://openai.com/index/introducing-openai-privacy-filter/) · أوزان [huggingface.co/openai/privacy-filter](https://huggingface.co/openai/privacy-filter) | نموذج **محلي**، 8 فئات، BIOES + Viterbi. CLI `opf`. | إخفاء/حجب للنطاقات. لا خريطة استرداد ولا خزنة جلسات في README. | محرك نص/CLI. الشات وPDF = **تكامل يدوي**. | **موثقة** · **غير مختبرة** |
| 2 | **packyme/privacy-filter** · [packyme/privacy-filter](https://github.com/packyme/privacy-filter) · README الرئيسي 2026-10-13 | regex (بريد، هاتف، هوية، بطاقة Luhn، IP) + gitleaks/entropy. **بلا** NER للأسماء. | استبدال نوعي `[邮箱]`… **غير قابل للعكس** («no un-redaction»). | بوابة: مكتبة / `POST /redact` :8088 / gRPC :8089 (**مباشر** للنص). PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 3 | **Masquerade** · [postralai/masquerade](https://github.com/postralai/masquerade) · README 2026-10-13 | PDF→نص ثم نموذج **خارجي**: Tinfoil Llama 3.3 70B. | حجب داخل PDF. استرداد الأصل بعد الاستعلام: **غير معلوم**. | PDF عبر MCP (**مباشر** للحجب). الاستعلام: **تكامل يدوي** (رفع الملف المحجوب إلى Claude). شات داخل المنتج: لا. | **موثقة** · **غير مختبرة** |
| 4 | **Presidio** · [data-privacy-stack/presidio](https://github.com/data-privacy-stack/presidio) · دليل [anonymizer](https://presidio.dataprivacystack.org/anonymizer/) 2026-10-13 | NER محلي + regex + checksum + recognizers. صور عبر Image Redactor. | replace / mask / redact / hash / **encrypt**. الاسترداد: `DeanonymizeEngine` + **Decrypt** AES؛ المفتاح عند المستدعي. «Presidio does not store or maintain stateful sessions». | مكتبة/HTTP/Docker. الشات وPDF = **تكامل يدوي**. مسار PDF كوثيقة دردشة: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 5 | **BentoPDF** · [alam00000/bentopdf](https://github.com/alam00000/bentopdf) · [v2.8.8](https://github.com/alam00000/bentopdf/releases/tag/v2.8.8) 29 Aug 2026 | **تحديد يدوي**. لا ماسح PII في README. | **Redact Content**: حذف دائم. Sanitize / Remove Metadata. لا استرداد. | PDF في المتصفح (**مباشر**). شات: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 6 | **OpenMed** · [maziyarpanahi/openmed](https://github.com/maziyarpanahi/openmed) · [`docs/anonymization.md`](https://github.com/maziyarpanahi/openmed/blob/master/docs/anonymization.md) 2026-10-13 | نموذج **محلي** `extract_pii`؛ يمكن توجيه `openai/privacy-filter`. | mask / remove / replace / hash / shift_dates. الاسترداد: `keep_mapping=True` ثم `reidentify`. الخريطة JSON عند المستدعي. | REST `/analyze` و `/pii/*` (**مباشر** للنص). PDF كمنتج: **غير معلوم**. شات: **تكامل يدوي**. | **موثقة** · **غير مختبرة** |
| 7 | **rizzo-pii** · [Rizzo-AI-Academy/rizzo-pii](https://github.com/Rizzo-AI-Academy/rizzo-pii) · التطبيق 2.0.0 · النموذج `rizzo-pii-0.3B` **v1.5.0** · [`src/app/app.py`](https://github.com/Rizzo-AI-Academy/rizzo-pii/blob/main/src/app/app.py) | نموذج **محلي** mmBERT ≈0.3B + شبكة regex/checksum. استبعاد وسم يبقيه مكشوفًا. | `[FULLNAME_1]`… + قاموس قرص يمكن إطفاؤه. | شات: نسخ ثم استرداد محلي (**تكامل يدوي**). PDF: `POST /pdf` حجب في التيار (**مباشر**). HTTP `POST /analyze` :5005. | **موثقة** · **مؤكدة من الكود** · **غير مختبرة** |
| 8 | **Censgate Redact** · [censgate/redact](https://github.com/censgate/redact) · `redact-core` **0.12.5** · بوابة [v0.12.4](https://github.com/censgate/redact/releases/tag/v0.12.4) `46996f8` 12 Sep 2026 | 61 نوعًا مُجمَّعًا + NER اختياري ONNX. | mask/replace/hash/encrypt/tokenize. الاسترداد: `POST /v1/restore` + `TokenMapStore`. | شات: بوابة `POST /v1/chat/completions` و `POST /v1/redact` (**مباشر**). REST `POST /api/v1/analyze`. PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 9 | **Worka PII** · [worka-ai/pii](https://github.com/worka-ai/pii) · crate `pii` **0.1.0** | regex + validator + قواميس + NER اختياري Candle. | redact / mask / replace / hash. أثر تدقيق بالذاكرة. خريطة جلسات دائمة: **غير معلومة**. | مكتبة نص = **تكامل يدوي**. لا تطبيق شات. PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 10 | **Secret Guard** · [luochen1990/secret-guard](https://github.com/luochen1990/secret-guard) · crate `secret-guard-rs` **0.1.0** · إصدار [v0.1.0](https://github.com/luochen1990/secret-guard/releases/tag/v0.1.0) 23 Sep 2026 `50bbdf5` | أسرار **معلنة يدويًا** في `[[secrets.entries]]`. لا ماسح PII/أسماء في هذا الإصدار. كشف الأسرار غير المعلنة (NER/regex/entropy) **خارطة طريق** كتنبيه، بلا استبدال تلقائي. | استبدال بـ Mock واقعي بنفس الطول ونفس مجموعة الأحرف؛ الاسترداد عكس تام على الرد (SSE ووسائط tool-call مشمولة). القائمة على القرص بنص واضح في toml/state. | شات: بوابة محلية افتراضي `127.0.0.1:8787`، المسار `/{proto_short}/{provider_id}/*` (`o` OpenAI، `a` Anthropic، `g` Gemini، `l` Ollama، `r` Responses) (**مباشر**). PDF: **غير معلوم**. سقالة الدورة `:5007/analyze` **افتراض سقالة**، ليست باب المنتج. | **موثقة**. PDF والدورة `:5007`: **غير معلومة**. **غير مختبرة**. |

Z Privacy صف مرجعي فوق القائمة، لا بديلًا عن أي مشروع.

---

## سجل الادعاءات — رابط الملف والإصدار لكل معلومة

كل صف: الادعاء · المصدر · الإصدار/التاريخ · الوسم.

### Z Privacy · المنتج `d882c5f` · `z_core 0.1.0`

| الادعاء | الملف | الوسم |
|---|---|---|
| ملف الجلسة صيغة v2 يحفظ `allowed` أسماء لا قيمًا؛ قائمة فارغة لا تسترد | [`z_core/src/conversation.rs`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/z_core/src/conversation.rs) `SESSION_FORMAT_VERSION` و`Turn.allowed` | مؤكدة من الكود |
| الجلسة خارج `vault.zv` لأن الجسم يُعاد ختمه كاملًا | نفس الملف، التعليق الافتتاحي | مؤكدة من الكود |
| مفتاح الجلسة 32 بايت في سجل Conversation؛ هاش الوثيقة لا جسمها | [`z_core/src/vault/model.rs`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/z_core/src/vault/model.rs) `Conversation` | مؤكدة من الكود |
| TokenStore `BTreeMap` في منصة الوثيقة؛ جلسة جديدة مخزن فارغ | [`z_core/src/session.rs`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/z_core/src/session.rs) `Session.tokens` و`Session::new` | مؤكدة من الكود |
| لا `Serialize` على TokenStore | [`z_core/src/tokens.rs`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/z_core/src/tokens.rs) بنية `TokenStore` | مؤكدة من الكود |
| `tokens.insert` عند الحماية من النص الحي فقط | [`z_core/src/ops/mod.rs`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/z_core/src/ops/mod.rs) نحو 692 و1828 و1909 | مؤكدة من الكود |
| ذيل الرمز MAC أحادي الاتجاه؛ المفتاح وحده لا يعكس القيمة | `tokens.rs` `Naming::tail` | مؤكدة من الكود |
| «nothing stored» يخص اشتقاق الاسم لا القيم | `tokens.rs` `TokenMint::mint` و`rename_all` | مؤكدة من الكود |
| `enter` يعيد التسمية ولا يعيد بناء المخزن | [`z_core/src/ops/conversation.rs`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/z_core/src/ops/conversation.rs) `enter` / `take_the_names` | مؤكدة من الكود |
| `name_tokens_from_the_vault` يضبط الاشتقاق فقط | `ops/mod.rs` 2320–2356 | مؤكدة من الكود |
| قراءة الأدوار بلا مخزن مملوء → كل رمز `unresolved` | `ops/conversation.rs` `turns()` 234–289 | مؤكدة من الكود |
| تعليق القفل/النسيان يخص `open_conversation` لا TokenStore | `session.rs` نحو 476–479 | مؤكدة من الكود |
| Always عبر `learn_value` في جسم الخزنة؛ المسح يقرأ hints ضد النص الحي | `ops/vault.rs` `learn_value`؛ `ops/mod.rs` `scan` | مؤكدة من الكود |
| `restore` يشترط القائمة **و** TokenStore وإلا `Unresolved` | `tokens.rs` الدالة `restore` | مؤكدة من الكود |
| مفاتيح الجلسات في الخزنة والمحادثات لم تكن فيها | [`apps/flutter_app/lib/screens/settings.dart`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/apps/flutter_app/lib/screens/settings.dart) نص Sessions | مؤكدة من الكود |
| شات OpenAI-متوافق داخل التطبيق | `z_core/src/openai.rs` · `POST /v1/chat/completions` | مؤكدة من الكود |
| PDF صفحة محمية محلية بلا شبكة | `apps/flutter_app/lib/protected_pdf.dart` | مؤكدة من الكود |
| تصدير PDF رملي 28 رمزًا نطاق `1F52` | `tests/cycle/sandbox/home/Documents/zprivacy/text-protected-2026-10-13.pdf` sha256 `1776f077…` | مختبرة (استخراج) |
| استرداد سبعة رموز في الشات كنص معروض | تجربة يدوية 2026-10-13؛ `GET /requests` بقي `[]` | مختبرة كنص معروض، ليست التقاط سلك |
| Always/Profile تبقى في `ValueRecord`؛ Once/Conversation تموت مع العملية | `session.rs:157,:217` · `vault/format.rs` بلا tokens · `learn_value` | مؤكدة من الكود |
| مسبار: 3 حمايات → برد 3 unresolved → إعادة فتح الوثيقة 2 unresolved (Always شُفي) | قياس القائد 13 تشرين الأول 2026 على `d882c5f` | مختبرة |
| المفتاح وحده لا يكفي | `Naming::tail` + المسبار | مؤكدة من الكود · مختبرة |
| سحب يكبّر إلى كلمات كاملة ثم يُزيل علامات الحافة `EDGE_MARKS` | `z_core/src/text.rs` `whole_words` · `session_state.dart` `select` → `wordSpan` | مؤكدة من الكود |
| الاسم الأول والعائلة زوج واحد يُعرض لا يُحمى تلقائيًا؛ «Also the word before» عرض لا ضم قسري | `scanner/packs/people.rs` `dictionary_names` · `acts.dart` | مؤكدة من الكود |
| `teach_name(..., family: bool)` كلمة قاموس واحدة لا حمايتان | `api.rs` `teach_name` | مؤكدة من الكود |

### 1. OpenAI privacy-filter

| الادعاء | الملف | الوسم |
|---|---|---|
| نموذج محلي 8 فئات BIOES+Viterbi، CLI `opf` | [README.md](https://raw.githubusercontent.com/openai/privacy-filter/main/README.md) · أوزان [huggingface.co/openai/privacy-filter](https://huggingface.co/openai/privacy-filter) · إعلان [22 Apr 2026](https://openai.com/index/introducing-openai-privacy-filter/) | موثقة |
| لا خريطة استرداد في الدليل | README أعلاه، أقسام How To Use / Model Details | موثقة (غياب في الدليل ≠ برهان غياب وظيفة مخفية؛ لا دليل إيجابي) |
| شات/PDF تكامل يدوي | README: محرك نص/CLI | موثقة |

### 2. packyme/privacy-filter

| الادعاء | الملف | الوسم |
|---|---|---|
| regex + gitleaks، بلا NER أسماء | [README.md](https://raw.githubusercontent.com/packyme/privacy-filter/main/README.md) جدول الطبقتين وفقرة «No person / place / organization» | موثقة |
| عناصر نوعية غير عكسية | نفس README: «irreversible (no un-redaction)» | موثقة |
| `POST /redact` :8088 وgRPC :8089 | نفس README، Usage | موثقة |
| PDF | لا ذكر | غير معلوم |

### 3. Masquerade (postralai/masquerade)

| الادعاء | الملف | الوسم |
|---|---|---|
| PDF→نص ثم Tinfoil Llama 3.3 70B | [README.md](https://raw.githubusercontent.com/postralai/masquerade/main/README.md) Architecture | موثقة |
| حجب PDF ثم رفع يدوي إلى Claude | نفس README How to use | موثقة |
| استرداد القيم الأصلية | لا ذكر في README | غير معلوم |

### 4. Presidio

| الادعاء | الملف | الوسم |
|---|---|---|
| عوامل replace/mask/redact/hash/encrypt/keep | [Anonymizer docs](https://presidio.dataprivacystack.org/anonymizer/) جدول Built-in operators، جُلب 2026-10-13 | موثقة |
| DeanonymizeEngine decrypt AES بمفتاح المستدعي | نفس الصفحة، مثال `DeanonymizeEngine` | موثقة |
| لا جلسات محفوظة؛ hash ملح افتراضي عشوائي منذ 2.2.361 | نفس الصفحة، ملاحظة Hash operator | موثقة |
| المستودع الحالي data-privacy-stack | [github.com/data-privacy-stack/presidio](https://github.com/data-privacy-stack/presidio) | موثقة |

### 5. BentoPDF v2.8.8

| الادعاء | الملف | الوسم |
|---|---|---|
| تحديد يدوي، Redact Content حذف دائم، على الجهاز | [README.md](https://raw.githubusercontent.com/alam00000/bentopdf/main/README.md) جدول Edit: «Permanently remove sensitive content»؛ Why BentoPDF: client-side | موثقة |
| الإصدار | [v2.8.8](https://github.com/alam00000/bentopdf/releases/tag/v2.8.8) 29 Aug 2026 | موثقة |
| شات / ماسح PII | لا ذكر لماسح PII ولا شات | غير معلوم (الشات) / موثّق الغياب لماسح PII في README |

### 6. OpenMed

| الادعاء | الملف | الوسم |
|---|---|---|
| خمس طرق mask/remove/replace/hash/shift_dates | [docs/anonymization.md](https://raw.githubusercontent.com/maziyarpanahi/openmed/master/docs/anonymization.md) | موثقة |
| `keep_mapping=True` ثم `reidentify`؛ أرقام عند تكرار النوع | نفس الملف، «Reversing a de-identification» | موثقة |
| SurrogateVault يخزن HMAC لا السطح الخام | نفس الملف، «Cross-document surrogate vaults» | موثقة |
| يمكن تشغيل عائلة OpenAI Privacy Filter | نفس الملف، «Privacy-filter family» | موثقة |
| PDF كمنتج | لا ذكر في هذا الدليل | غير معلوم |

### 7. rizzo-pii · تطبيق 2.0.0 · نموذج v1.5.0

| الادعاء | الملف | الوسم |
|---|---|---|
| `APP_VERSION = "2.0.0"` و`APP_MODEL_VERSION = "1.5.0"` | [src/app/app.py](https://raw.githubusercontent.com/Rizzo-AI-Academy/rizzo-pii/main/src/app/app.py) | مؤكدة من الكود |
| نموذج محلي + regex/checksum؛ استبعاد وسم يبقي القيمة | نفس الملف docstring و`analyze()` | مؤكدة من الكود |
| قاموس `mapping[ph] = val` فقط إن `mapping_enabled` | `analyze()` في app.py | مؤكدة من الكود |
| `POST /analyze` و`POST /pdf`؛ القاموس لا يسافر مع PDF | docstring الملف ودالة `_build_anonymized_pdf` | مؤكدة من الكود |
| الشات نسخ/لصق ثم استرداد محلي | docstring «COPIA / RIPRISTINA» | موثقة |
| افتراضي `http://127.0.0.1:5005` | docstring الملف | مؤكدة من الكود |

### 8. Censgate Redact · 0.12.5 / v0.12.4 `46996f8`

| الادعاء | الملف | الوسم |
|---|---|---|
| 61 نوعًا؛ `redact-core` 0.12.5 | [README.md](https://raw.githubusercontent.com/censgate/redact/main/README.md) | موثقة |
| بوابة `POST /v1/redact` و`POST /v1/chat/completions` | [docs/gateway/getting-started.md](https://raw.githubusercontent.com/censgate/redact/v0.12.4/docs/gateway/getting-started.md) على وسم v0.12.4 | موثقة |
| Token map: off/memory/vault_kv2؛ ختم AES-256-GCM؛ DEK | [docs/gateway/tokenization.md](https://raw.githubusercontent.com/censgate/redact/v0.12.4/docs/gateway/tokenization.md) | موثقة |
| `POST /v1/restore` بـ `session_id` / `vault.context_id` | نفس الملف + [ملاحظات v0.12.4](https://github.com/censgate/redact/releases/tag/v0.12.4) | موثقة |
| REST `POST /api/v1/analyze` | README Embed the engine | موثقة |
| PDF | لا ذكر | غير معلوم |

### 9. Worka PII · crate 0.1.0

| الادعاء | الملف | الوسم |
|---|---|---|
| regex/validator/قواميس + NER اختياري Candle | [README.md](https://raw.githubusercontent.com/worka-ai/pii/main/README.md) Features وSupported Entity Types | موثقة |
| عوامل redact/mask/replace/hash؛ أثر تدقيق أصل↔بديل | نفس README، مثال Custom Operators + Audit Log | موثقة |
| خريطة جلسات دائمة / شات / PDF | لا ذكر | غير معلوم |

### 10. Secret Guard = luochen1990/secret-guard · `secret-guard-rs` 0.1.0

هوية الصف: المستودع الأصلي للقائمة [github.com/luochen1990/secret-guard](https://github.com/luochen1990/secret-guard). بوابة LLM محلية: الأسرار المعلنة تُستبدل بـ Mock ثم تُسترد في الرد. سقالة الدورة على GitHub تذكر «Secret Guard — gateway mode» على `:5007` **بلا رابط مستودع**. باب المنتج الموثّق `127.0.0.1:8787` والمسار `/{proto_short}/{provider_id}/*`. مسار الدورة `:5007/analyze` **افتراض سقالة**. غياب `/analyze` الحرفي لا ينفي الوظيفة.

| الادعاء | الملف | الوسم |
|---|---|---|
| بوابة محلية: outbound Mock، inbound استرداد؛ LLM لا يرى السر الحقيقي | [README.md](https://raw.githubusercontent.com/luochen1990/secret-guard/master/README.md) How it works | موثقة |
| crate نشر `secret-guard-rs` **0.1.0**؛ الثنائي `secret-guard`؛ المستودع github.com/luochen1990/secret-guard | [Cargo.toml](https://raw.githubusercontent.com/luochen1990/secret-guard/master/Cargo.toml) جُلب 2026-10-13 من `master` | مؤكدة من الكود |
| اسم crates.io `secret-guard` سُجّل لطرف ثالث 2026-09-09 (`diff-lab-com` / bigdong89) | تعليق رأس Cargo.toml | موثقة من المصدر |
| إصدار [v0.1.0](https://github.com/luochen1990/secret-guard/releases/tag/v0.1.0) 23 Sep 2026 commit `50bbdf5` | صفحة الإصدار | موثقة |
| أسرار معلنة `[[secrets.entries]]`؛ الإعداد التصريحي مقابل `secret-guard.state.toml` بنص واضح | [docs/configuration.md](https://raw.githubusercontent.com/luochen1990/secret-guard/master/docs/configuration.md) | موثقة |
| الاستماع الافتراضي `127.0.0.1:8787` / `SG_PORT` | README Quick Start و`[server] port` في configuration.md | موثقة |
| المسار `/{proto_short}/{provider_id}/*` (`o`/`a`/`g`/`l`/`r`) | README Routing convention | موثقة |
| Mock حتمي مستقر عبر الجولات (صديق لـ prefix-cache) | README Why you can trust it | موثقة |
| FWD-1 byte-exact redact/restore؛ RED-* قابلية العكس | [docs/design/contracts.md](https://raw.githubusercontent.com/luochen1990/secret-guard/master/docs/design/contracts.md) | موثقة |
| كشف الأسرار غير المعلنة NER/regex/entropy خارطة طريق كتنبيه بلا استبدال تلقائي | README Roadmap · [#252](https://git.lambda.lc/lc-studio/secret-guard/issues/252) | موثقة |
| PDF | لا ذكر في README ولا في configuration.md | غير معلوم |
| سقالة الدورة تتوقع `:5007` gateway | [tests/cycle/README.md](https://raw.githubusercontent.com/YourVoicesApp/z-privacy/tests/cycle/tests/cycle/README.md) فرع `tests/cycle` `b42cf0e` | موثقة (سقالة ≠ هوية المنتج) |

**ليسا صف هذه القائمة (مذكوران حتى لا يُستبدلا):**

| الاسم | لماذا ليس الصف | المصدر |
|---|---|---|
| [chintanshah35/secretguard](https://github.com/chintanshah35/secretguard) | ماسح CI/`npx secretguard`؛ لا وكيل LLM ولا خزنة استرداد محادثة | [README](https://raw.githubusercontent.com/chintanshah35/secretguard/main/README.md) |
| [diff-lab-com/secret-guard](https://github.com/diff-lab-com/secret-guard) crates.io **0.1.0** (نشر 2026-09-09 حسب Cargo.toml عند luochen) | مكتبة+CLI `scan\|surrogate\|restore --pairs`؛ HMAC `SG1:`؛ بلا HTTP بوابة. «blueprint artifact (a)» لـ shannon-mono. هذا ما أخذ اسم crates.io `secret-guard`. | [README](https://raw.githubusercontent.com/diff-lab-com/secret-guard/main/README.md) |

---

## 11. إضافة منفصلة — LLM SecretGuard (Codeberg)

ليست صف القائمة الأصلية. تُذكر لأن نسخة سابقة وضعتها خطأً مكان الصف العاشر، ولأن شكل عملها (مسح + عنصر نائب + وكيل شات + خزنة عملية) أقرب إلى بعض محاور Z من بوابة الأسرار المعلنة.

**[codeberg.org/roobai/llm-secretguard](https://codeberg.org/roobai/llm-secretguard)** مساحة العمل **v0.3.6**.

| الادعاء | الملف | الوسم |
|---|---|---|
| اسم المنتج LLM SecretGuard؛ وكيل محلي `:8080`؛ عناصر `[GUARD:type:hash]`؛ TTL 300ث؛ سياسة Allow/Redact/Drop | [README.md](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/README.md) | موثقة |
| مساحة العمل الإصدار **0.3.6** | [Cargo.toml](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/Cargo.toml) `[workspace.package] version = "0.3.6"` جُلب 2026-10-13 | مؤكدة من الكود |
| خزنة ثنائية، `VAULT_STORE` DashMap، TTL، zeroize | [crates/guard-core/src/vault.rs](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/crates/guard-core/src/vault.rs) | مؤكدة من الكود |
| مسار PII `/v1/pii/analyze` يستبدل بـ `[REDACTED:label]` بلا خزنة الوكيل | [crates/guard-pii/src/model.rs](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/crates/guard-pii/src/model.rs) `redact_text` | مؤكدة من الكود |
| PDF | لا ذكر | غير معلوم |

خزنة هذا المشروع في ذاكرة العملية TTL 300ث؛ لا تُخلط مع قائمة toml عند luochen1990.

---

## Z Privacy — ملخص الأدلة (بلا توسيع اختبار)

**إيجاد (محور 1).** `scanner/mod.rs` · `general_rules.rs` · `people.rs`. تلقائي لما «لا يُعقل أن يكون غير ذلك» (IBAN+checksum، بريد، هاتف…). أسماء القاموس لا تُحمى تلقائيًا. التحديد اليدوي من الحوار. **مؤكدة من الكود.** التجربة الألمانية: حماية يدوية لمقاطع، لا إثباتًا للكشف التلقائي. **مختبرة** كنص معروض.

**حماية واسترداد (محور 2).** الرمز من مفتاح الجلسة. `.zs` يخزن أسماءً لا قيمًا. TokenStore RAM. Always/Profile: `ValueRecord` في الخزنة وتُشفى عند إعادة فتح نفس الوثيقة. Once/Conversation تموت مع العملية. المفتاح وحده لا يكفي. مسبار 13 تشرين الأول: 3 → برد 3 unresolved → إعادة فتح الوثيقة 2 unresolved. **مؤكدة من الكود · مختبرة.**

**نطاق (محور 3).** شات داخل التطبيق. PDF عبر `protected_pdf.dart`. الملف الرملي `text-protected-2026-10-13.pdf`، 28 قيمة، نطاق `1F52`. **مختبرة** استخراجًا.

تجربة PDF بعد إغلاق النافذة المعزولة لم تُستكمل؛ أُوقف التوسيع هنا.

---

## أقرب المشاريع إلى Z

القرب تشابه في **شكل العمل** على المحاور الثلاثة، لا ترتيب جودة. بعد تصحيح هوية Secret Guard صار الصف العاشر بوابة أسرار معلنة، لا ماسح وثيقة.

1. **rizzo-pii** — أقرب تشابه للمنتج ككل: إيجاد محلي → عنصر نائب → نموذج يرى الرموز → استرداد محلي، مع واجهة وثيقة وPDF محمي. الفرق الجوهري: قاموس قيم على القرص يمكن إطفاؤه، مقابل مفتاح جلسة وأسماء مسموحة عند Z. Conversation عند Z تموت مع العملية (**مختبرة**). قاموس rizzo يعيش على القرص (**مؤكدة من الكود**).
2. **Censgate Redact** — أقرب تشابه لمسار الشات + مفتاح سياق: بوابة OpenAI-متوافقة و`/v1/restore` و`TokenMapStore` تحت `session_id`. الخريطة مختومة؛ الافتراضي `off` يجعل الاسترداد داخل الطلب فقط. `memory` لا يعيش إعادة التشغيل (موثّق).
3. **OpenMed** — أقرب تشابه لمحرك النص القابل للعكس: `keep_mapping` + `reidentify` لدى المستدعي. بلا تطبيق سطح مكتب وبلا PDF موثّق. استمرارية الخريطة عند من يحفظ ملف JSON.
4. **Secret Guard (luochen1990)** — أقرب تشابه **لمبدأ** الاستبدال ثم الاسترداد على مسار الشات، مع استمرارية موثّقة لأن القيم في قائمة toml. الإيجاد يدوي/معلن، لا مسح وثيقة ولا PDF. يتقاطع مع Censgate/packyme أكثر مما يتقاطع مع منتج «امسح وثيقة ثم احمِ ثم أرسل».

**إضافة 11، ليست من العشرة:** LLM SecretGuard (Codeberg) أقرب في شكل المسح+العنصر النائب+خزنة العملية من luochen؛ خزنته ذاكرة TTL 300ث. لا تُستخدم لإثبات تفرّد Z ولا لاستبدال الصف العاشر.

هذه المشاريع تغطي معًا: إيجادًا محليًا أو معلنًا، عنصرًا نائبًا، إرسالًا إلى نموذج، واستردادًا. لذلك **لا يثبت** من هذه القائمة أن جمع تلك الخطوات متفرد عند Z، ولا أن Z اخترع مبدأ الاستبدال والاسترداد. ما يتجه إليه Z كمنتج (مفتاح جلسة مشتق، فصل نطاق الكلمة عن حفظ الوثيقة، سطح مكتب، PDF صفحة جديدة، خزنة Always) اتجاه بناء يخدم المستخدم، بلا حاجة لحكم تفرّد.

---

## المشترك المدعوم بالأدلة

- **عنصر نائب ثم استرداد (المبدأ):** Z (مفتاح جلسة + أسماء مسموحة + TokenStore حي)، rizzo-pii (قاموس قرص)، OpenMed (JSON المستدعي)، Censgate (`TokenMapStore` + `/v1/restore`)، Secret Guard luochen (قائمة أسرار معلنة ↔ Mock). Presidio يعيد التشفير AES فقط إن اختير encrypt. الإضافة 11 Codeberg: خزنة وكيل في الذاكرة.
- **إيجاد محلي بلا رفع الوثيقة إلى مزوّد النموذج:** Z، OpenAI PF، packyme، Presidio، OpenMed، rizzo-pii، Censgate، Worka، BentoPDF. Secret Guard luochen يعمل على الحلقة المحلية لكن الإيجاد قائمة معلنة لا ماسح وثيقة. Masquerade يرسل النص إلى Tinfoil للكشف.
- **قواعد/checksum للحقول المنظمة:** Z، packyme، Presidio، rizzo-pii، Censgate، Worka. Secret Guard luochen: لا في هذا الإصدار (الكشف غير المعلن خارطة طريق).
- **نموذج تصنيف محلي للأسماء:** OpenAI PF، Presidio، OpenMed، rizzo-pii؛ Censgate/Worka اختياريًا. Z في هذا البناء: قوائم + يدوي. luochen: بلا NER في الإصدار الحالي.
- **PDF كملف محمي:** Z (صفحة جديدة)، rizzo-pii (حجب في التيار)، BentoPDF وMasquerade (داخل الملف). Secret Guard luochen: غير معلوم.
- **شات كمسار منتج:** Z إرسال داخلي؛ Censgate وpackyme وSecret Guard luochen بوابة/وكيل؛ rizzo-pii وMasquerade نسخ/رفع يدوي.

---

## الفروق المدعومة بالأدلة

| الفرق | الدليل |
|---|---|
| مفتاح جلسة مقابل خريطة قيم مقابل قائمة معلنة | Z يخزن أسماءً ومفتاحًا لا القيم في `.zs`؛ القيم في RAM. rizzo يخزن القيم على القرص ويمكن إطفاء ذلك. OpenMed يسلّم JSON للمستدعي. Censgate يخزن ciphertext تحت session. Secret Guard luochen يخزن الأسرار بنص واضح في toml. |
| استمرارية الاسترداد بعد إعادة التشغيل | rizzo: القاموس على القرص. luochen: القائمة في toml. Censgate `memory`: لا يعيش إعادة التشغيل. Z Conversation/Once: تموت مع العملية (**مختبرة**). Z Always/Profile: تعيش في الخزنة وتُشفى عند إعادة فتح نفس الوثيقة (**مختبرة**، 3→3→2). |
| نطاق إعادة حماية الكلمة | Z: Just here / This conversation / Remember everywhere (وأحيانًا Remember for client). لا يُستنتج منه الاسترداد. الباقي لا يصف هذا التقسيم الرباعي. |
| الشات | Z وCensgate وSecret Guard luochen: مسار مباشر. packyme: بوابة نص. rizzo: لصق. Masquerade: رفع بعد الحجب. |
| شكل PDF | Z: صفّ جديد + تذييل. rizzo: استبدال في content stream. BentoPDF/Masquerade: تحرير الأصل. Secret Guard/Censgate/OpenMed: غير موثّق كمنتج PDF. |
| الكشف عن الأسماء | rizzo/OpenAI PF/OpenMed/Presidio: نموذج. packyme: بلا أسماء. BentoPDF: يدوي. Masquerade: Llama خارجي. Z: قاموس + قرار يدوي. luochen: قائمة أسرار معلنة. |
| الباب HTTP | rizzo/Presidio/OpenMed/Censgate REST: `/analyze` أو مكافئ. packyme: `/redact`. Censgate gateway: `/v1/redact` + `/v1/restore`. Secret Guard luochen: `/{proto}/{provider}/*` على `:8787`. Z: `/v1/chat/completions` للإرسال، بلا `/analyze`. الباب ≠ الوظيفة. |
| عمر الاسترداد داخل العملية | Z: ما دام المخزن الحي مملوءًا. rizzo: ما دام القاموس. Censgate memory: TTL 3600ث. OpenMed: ما دام ملف الخريطة عند المستدعي. luochen: ما دامت قائمة الأسرار في الإعداد. |

---

## أ. الاختيار — كيف يختار الشخص ما يُخفى

السؤال: نقر على كلمة، سحب، قائمة/مربعات، regex، لا شيء؟ هل يُقصّ الترقيم عند الحافة؟ هل يُفصل الاسم الأول عن العائلة كقيمتين؟

| # | المشروع | كيف يختار الشخص | ترقيم الحافة | اسم أول / عائلة | أين نُظر | الوسم |
|---|---|---|---|---|---|---|
| — | **Z Privacy** | سحب/نقر في عمود الأصل → `inspect_selection` → Protect. قائمة مراجعة (Protect / Always / Not sensitive). «Protect all matches». «Also the word before» عرض. | نعم: `whole_words` يكبّر إلى الكلمة ثم يزيل `EDGE_MARKS` (`.` `,` `;` `:` `!` `?` اقتباس أقواس…). «Müller,» → «Müller»؛ «+49 228» يبقى. | الزوج «Thomas Müller» **قيمة واحدة** تُعرض (`Confidence::Suggest`) ولا تُحمى تلقائيًا. القاموس يفرّق given/family لتعليم الكلمة (`teach_name(..., family)`)، لا لحماية منفصلة. الضم التلقائي ممنوع: «two decisions». | `text.rs` `EDGE_MARKS`/`whole_words` · `session_state.dart` `select` · `acts.dart` · `people.rs` `dictionary_names` · `api.rs` `teach_name` | مؤكدة من الكود |
| 1 | OpenAI PF | لا نقر ولا سحب. CLI يحجب كل ما يتنبأ به النموذج. لا سياسة تسميات وقت التشغيل («does not support configuring label policies dynamically»). `--output-mode typed\|redacted`. | `--trim-whitespace` افتراضي على حدود **النطاق المتنبَّأ** (مسافة)، لا ترقيم جملة. | فئة واحدة `private_person`. لا فصل first/family في التصنيف الثمانية. | [README](https://raw.githubusercontent.com/openai/privacy-filter/main/README.md) · [opf/_cli/common.py](https://raw.githubusercontent.com/openai/privacy-filter/main/opf/_cli/common.py) `TRIM_WHITESPACE_HELP` · Model card «Static Label Policy» | موثقة |
| 2 | packyme | لا اختيار يدوي. `f.Redact(text)` يحجب كل الطبقات. لا أعلام كيان في README. | غير مذكور. | «No person / place / organization». | README الرئيسي 2026-10-13، الطبقتان وفقرة الأسماء | موثقة. الترقيم: **غير موجود** في README/`filter.go` المذكور |
| 3 | Masquerade | لا نقر في المنتج. المسار: أعطِ مسار PDF لـ Claude؛ الكشف عند Tinfoil؛ الحجب تلقائي. | غير مذكور. | غير مذكور كقيمتين. | README Architecture / How to use · `docs/faq.md` | موثقة. الترقيم والأسماء: **غير موجود** في README وfaq.md |
| 4 | Presidio | اختيار **نوع كيان** عبر `entities=` / `OperatorConfig` لكل نوع. لا نقر على كلمة في المكتبة. Image Redactor للصور. | غير مذكور كقص حافة كلمة. | نوع `PERSON` واحد في العوامل الافتراضية. | [anonymizer](https://presidio.dataprivacystack.org/anonymizer/) · Analyzer `entities` في الدليل | موثقة. قص الترقيم: **غير موجود** في صفحة anonymizer 2026-10-13 |
| 5 | BentoPDF | تحديد يدوي في المحرر: Redact Content يحذف المحتوى تحت العلامة. FAQ: الحجب دائم. محرر النص: نقر على فقرة للتحرير (أداة أخرى). | غير مذكور لـ Redact. | لا ماسح أسماء. | README جدول Edit · [bentopdf.com/edit-pdf](https://www.bentopdf.com/edit-pdf) «Is the redaction permanent?» | موثقة. الترقيم/الأسماء: **غير موجود** في README |
| 6 | OpenMed | لا نقر. المستدعي يختار `method` وكيانات النموذج. | غير مذكور. | **نعم يفصل:** النموذج الافتراضي SuperClinical يخرج `[first_name]` و`[last_name]` لا `[NAME]`. التكرار يرقّم (`[first_name_2]`). | [docs/anonymization.md](https://raw.githubusercontent.com/maziyarpanahi/openmed/master/docs/anonymization.md) فقرة mask | موثقة |
| 7 | rizzo-pii | قائمة/مربعات **حسب الوسم**: أيقونة 🏷️ أو `--exclude-tags` / `exclude_tags` يبقي النوع مكشوفًا. لا نقر على كلمة واحدة في النص. FULLNAME وسم واحد. | غير مذكور. | وسم `FULLNAME` («Mario Rossi») لا first/family منفصلين في TASSONOMIA_TAG. | [src/app/app.py](https://raw.githubusercontent.com/Rizzo-AI-Academy/rizzo-pii/main/src/app/app.py) `analyze(excluded=)` · [docs/TASSONOMIA_TAG.md](https://raw.githubusercontent.com/Rizzo-AI-Academy/rizzo-pii/main/docs/TASSONOMIA_TAG.md) | مؤكدة من الكود (الاستبعاد) · موثقة (التسمية) |
| 8 | Censgate | CLI `--entities` / `--disable`؛ بوابة `{ action: allow }` على النوع. لا نقر على كلمة. | غير مذكور كقص حافة. | NER يدمج أجزاء الاسم المتجاورة قبل tokenize (ملاحظات v0.12.2)؛ سطح PERSON واحد لكل تطبيع. | README `--disable` · [v0.12.2](https://github.com/censgate/redact/releases) «adjacent same-type fragments of one word (ONNX split names) merge» | موثقة |
| 9 | Worka PII | `AnonymizeConfig.per_entity` عامل لكل نوع. Regex مخصّص. لا UI نقر. | غير مذكور. | `Person` نوع NER اختياري واحد. | [README](https://raw.githubusercontent.com/worka-ai/pii/main/README.md) Custom Operators + Supported Entity Types | موثقة |
| 10 | Secret Guard luochen | قائمة معلنة `[[secrets.entries]]` (يدوي في toml/WebUI). لا نقر في وثيقة. لا regex كشف في هذا الإصدار (خارطة طريق تنبيه). | غير منطبق (قيمة السر كاملة). | غير منطبق (أسرار لا أسماء). | [docs/configuration.md](https://raw.githubusercontent.com/luochen1990/secret-guard/master/docs/configuration.md) · README Roadmap | موثقة |

Z هو المنتج الوحيد في العشرة الذي يوثّق **سحب كلمة في وثيقة** مع قص ترقيم الحافة وقرار منفصل لضم الاسم السابق. OpenMed الوحيد الذي يوثّق فصل first/family كعنصرين نائبين.

---

## ب. الوثائق العائدة — هل يعود ملف مصدَّر وتُسترد عناصره النائبة؟

السؤال: هل يصدّر أي منتج وثيقة يمكن أن **تعود** إليه (مثل محامٍ يعيد PDF مختلفًا يحمل عنصرًا نائبًا واحدًا) فتسترد القيم الحقيقية؟ أم كل تصدير باتجاه واحد؟

تعريف المسار المطلوب: تصدير وثيقة بعناصر نائبة → استيراد **تلك الوثيقة أو وثيقة أخرى** تحمل العنصر → استرداد القيمة من مفاتيح/خريطة **يملكها المنتج**.

| # | المشروع | تصدير وثيقة؟ | هل تعود وتُسترد؟ | أين نُظر | الوسم |
|---|---|---|---|---|---|
| — | **Z Privacy** | نعم: Save as PDF يكتب النص المحمي (رموز `__Z_…__`) صفحة جديدة. النسخ داخل الجلسات محمية. | استرداد **إجابات الجلسة** داخل العملية: نعم. بعد برد + إعادة فتح **نفس الأصل الواضح**: Always يُشفى (مسبار 3→3→2). مسار «محامٍ يعيد PDF مختلفًا يحمل عنصرًا نائبًا»: المسح يبحث عن **النص الواضح** في `original_str`؛ الرموز لا تطابق `ValueRecord`. لا دالة تملأ TokenStore من الخزنة باشتقاق الأسماء دون ظهور القيمة. **غير موجود** في `protected_pdf.dart` (كتابة فقط) و`scan`/`restore`/`enter`. | `protected_pdf.dart` «handed to a model or to a person» · `scanner/mod.rs` `vault_pass` · مسبار 13 تشرين الأول | مؤكدة من الكود · مختبرة (البرد) |
| 1 | OpenAI PF | نص محجوب إلى stdout/ملف. | لا خريطة استرداد في README. **غير موجود** في README وOUTPUT_SCHEMAS.md. | README How To Use · OUTPUT_SCHEMAS.md | موثقة (غياب إيجابي في الدليل) |
| 2 | packyme | نص `Redacted`. | يعلن «irreversible (no un-redaction)». | README الطبقتان | موثقة |
| 3 | Masquerade | PDF محجوب على القرص. | الاستعلام: رفع الملف المحجوب إلى Claude. استرداد الأصل: **غير موجود** في README وfaq.md. | README الخطوة 6 · faq.md | موثقة |
| 4 | Presidio | نص/صورة حسب المستدعي. | `DeanonymizeEngine` decrypt AES يحتاج المفتاح **وقائمة الكيانات بمواضعها**. وثيقة أخرى بمواضع مختلفة لا تُفكّ من الملف وحده. «does not store or maintain stateful sessions». | anonymizer DeanonymizeEngine | موثقة |
| 5 | BentoPDF | PDF محجوب. | «Applying a redaction removes the content… can't be recovered by copying or searching.» اتجاه واحد. | bentopdf.com/edit-pdf FAQ | موثقة |
| 6 | OpenMed | نص `deidentified_text`؛ Agent يمكنه `export_format="pdf"` كصور مقنعة بلا طبقة نص (Agent docs). | `reidentify(text, mapping)` على **أي نص** إن بقيت خريطة JSON عند المستدعي. الخريطة منفصلة عن الملف. لا استيراد PDF منتج يعيد القيم من خزنة داخلية. | anonymization.md · skills/reidentifying-text · agent.openmed.life/docs/privacy | موثقة |
| 7 | rizzo-pii | `POST /pdf`: حجب في التيار؛ القاموس **لا يسافر** مع الملف («يموت مع الطلب»). | تبويب RIPRISTINA يلصق **إجابة LLM** على القاموس المحلي. إعادة استيراد PDF المحجوب كوثيقة أصل لاسترداد القيم: **غير موجود** في docstring التدفق (ANONIMIZZA / COPIA / RIPRISTINA) ولا في تعليق `_build_anonymized_pdf`. لصق نص فيه `[FULLNAME_1]` قد يُسترد إن بقي القاموس — ذلك لصق نص لا استيراد وثيقة. | app.py docstring · `_build_anonymized_pdf` | مؤكدة من الكود |
| 8 | Censgate | لا تصدير PDF موثّق. `/v1/redact` يعيد نصًا. | `/v1/restore` على نص فيه رموز + `session_id`. يعمل على أي نص إن عاش المخزن (`vault_kv2`). الافتراضي `off`/`memory` لا يعيش ملفًا عائدًا بعد إعادة التشغيل. لا مسار «استورد PDF». | docs/gateway/tokenization.md · README | موثقة |
| 9 | Worka | لا تصدير وثيقة. | لا `reidentify`. أثر التدقيق في الذاكرة. **غير موجود** في README. | README Features / Audit Log | موثقة |
| 10 | Secret Guard luochen | لا PDF. الاسترداد على **رد LLM** في الوكيل. | Mock في ردود الأدوات يعود للقيمة المعلنة. وثيقة مصدَّرة عائدة: **غير موجود** في README وconfiguration.md. | README How it works · configuration.md | موثقة |

**الخلاصة على السؤال ب:** لا أحد من العشرة يوثّق مسار منتج «صدّر وثيقة → استلم وثيقة أخرى تحمل عنصرًا نائبًا واحدًا → استوردها → استرد القيمة من مفاتيح يملكها المنتج». أقرب المسارات استرداد **نص** منفصل عن الملف (rizzo لصق، OpenMed `reidentify` + JSON، Censgate `/v1/restore` + session). Z يسترد إجابات الجلسة ويشفي Always على **نفس الأصل الواضح** بعد البرد؛ PDF عائد مختلف يحمل الرمز وحده **غير موجود** في الكود. ذلك يبقى أوضح فجوة منتج مرشّحة لـ Z، لا تفرّدًا مثبتًا بعد.

---

## Presidio — الروابط المذكورة

| الرابط | HTTP في 2026-10-13 | النتيجة |
|---|---|---|
| https://github.com/microsoft/presidio | 200 | تحويل إلى data-privacy-stack/presidio |
| https://microsoft.github.io/presidio/ | 200 | إشعار نقل |
| https://data-privacy-stack.github.io/presidio/ | 200 | → presidio.dataprivacystack.org |
| https://github.com/data-privacy-stack/presidio | 200 | المستودع الحالي |
| https://presidio.dataprivacystack.org/anonymizer/ | 200 | دليل العوامل وDeanonymizeEngine |

تعذّر الوصول المستمر (404) **لم يستمر** على هذه الروابط.

---

## الخلاصة

مبدأ الاستبدال ثم الاسترداد مشترك. سجل الاستمرارية عند Z محسوم قياسًا على `d882c5f`: Always/Profile تعيش في `ValueRecord` وتُشفى عند إعادة فتح نفس الوثيقة؛ Once/Conversation تموت مع العملية لأن TokenStore ذاكرة فقط. المفتاح وحده لا يكفي. المسبار: 3 حمايات → برد 3 unresolved → إعادة فتح الوثيقة 2 unresolved.

في الاختيار، Z ينفرد في هذه القائمة بسحب كلمة مع قص ترقيم الحافة وقرار صريح لضم الاسم السابق. OpenMed ينفرد بفصل first_name / last_name كعنصرين نائبين.

لا مشروع في العشرة يوثّق عودة وثيقة مصدَّرة مختلفة تحمل عنصرًا نائبًا واسترداد قيمته من مفاتيح المنتج. ذلك مرشّح لأوضح فرق يمكن لـ Z أن يبنيه؛ وهو اليوم **غير موجود** في مسار استيراد PDF عند Z نفسه.

لا حاجة لادعاء اختراع المبدأ. لا يُفترض التفوق ولا التفرّد بين العشرة.

---

## خارج النطاق · لاحقًا

- لا تدقيق شامل لأي منتج، ولا تحسين Z، ولا إدخال المكتبة.
- **مسار الترجمة** لهذه الدراسة: **مهمة لاحقة فقط**، غير منجزة هنا.
- تشغيل rizzo-pii وSecret Guard وبقية التسعة: غير مطلوب لهذا التسليم.
- استكمال دورة PDF المعزولة: متوقف.
- لا ادّعاء تفرّد لجمع الميزات بين العشرة، ولا ادّعاء اختراع مبدأ الاستبدال والاسترداد.

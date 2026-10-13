# دراسة مقارنة — ثلاثة محاور · القائمة الأصلية لعشرة مشاريع

نسخة العمل `/home/monopeaks/mono-privacy-comparison-20261013-022102` · الفرع `comparison/local-cycle`.
Z Privacy: المنتج HEAD `d882c5f` · الختم `z_core 0.1.0 · 2026-10-13 · 61fa27b`.
تاريخ الأدلة: 2026-10-13. هذه النسخة تكمل صف Secret Guard وتفصل مفاتيح الجلسات عن خرائط القيم.

**اختبارات Z وتجهيزاتها متوقفة عند هذا التسليم.** إعادة فتح PDF بعد الإغلاق، والجلسة الثانية، وتوسيع الأدوات، ليست جزءًا من هذه النتيجة. لم يُعدَّل التطبيق.

الأصل، والنسخة الاحتياطية، وGitHub، ومكتبة ZPrivacy-lib: بلا كتابة. المكتبة خارج المقارنة.

**وسوم الدليل:** موثقة · مؤكدة من الكود · مختبرة · غير معلومة.
غياب `/analyze` من دليل مشروع لا يثبت غياب وظيفته. تشغيل المشاريع العشرة ليس شرطًا للتسليم. لم يُستبدل أي اسم في القائمة الأصلية.

**رأي المنتج من النتائج الحالية:** لـ Z اتجاه منتج واضح يستحق البناء (جلسة بمفتاحها، نطاق إعادة حماية الكلمة، شات داخل التطبيق، PDF محمي، خزنة Always). جمع هذه الميزات **ليس مثبتًا كمتفرد** بين العشرة: أربعة مشاريع قريبة تغطي إيجادًا محليًا ثم عنصرًا نائبًا ثم إرسالًا ثم استردادًا بطرق متداخلة. لا يُفترض تفوق Z ولا تفرّده.

---

## المحاور الثلاثة

1. **إيجاد مناطق الحماية:** نموذج محلي أو خارجي، قواعد، قوائم، أو تحديد يدوي.
2. **الحماية والاسترداد:** حذف أو استبدال أو تشفير؛ كيف تُستعاد القيم وأين تُحفظ المفاتيح أو الخرائط.
3. **النطاق:** شات، PDF، أو كلاهما. **دعم مباشر** = مسار المنتج نفسه. **تكامل يدوي** = نسخ/لصق أو رفع لاحق أو بوابة يركّبها المدمج.

في محور الحماية عند Z تبقى ثلاثة أمور مستقلة: نطاق إعادة حماية **الكلمة**، مكان حفظ **الوثيقة**، ومفتاح استرداد **الجلسة**. لا يُستنتج أحدها من زر يخص الآخر.

---

## مفاتيح الجلسات وخرائط القيم — لا تُطوى في مفهوم واحد

الاسترداد القابل للعكس يظهر في خمسة منتجات من القائمة (+Z). الشكل مختلف، فلا يُقال إن كلها «خريطة قيم» أو كلها «مفتاح جلسة».

| المنتج | ماذا يُحفظ | أين يعيش | ماذا يلزم للاسترداد | متى يختفي |
|---|---|---|---|---|
| **Z Privacy** `d882c5f` | الخزنة تحفظ رقم الجلسة ومقبضها و**32 بايت**. ملف `sessions/N.zs` (صيغة v2) يحفظ السؤال والجواب الخام و**أسماء الرموز المسموحة** (`Turn.allowed: Vec<String>`)، لا خريطة القيم. القيم في TokenStore الحي. | `sessions/*.zs` **خارج** `vault.zv` لأن جسم الخزنة يُعاد ختمه كاملًا. الواجهة: «A session keeps its own key, and the keys are in the vault» و«the conversations themselves were never in it». | `restore(raw, store, allowed)` يعيد القيمة فقط إن كان الرمز في قائمة المسموح **و** في TokenStore. قائمة فارغة لا تسترد شيئًا. الاسم يُشتق من بايتات الجلسة وحدها (`Naming::of_session` → نطاق 4 hex + مفتاح قيمة). | جلسة أخرى = نطاق آخر؛ رمز أجنبي = `Piece::Unresolved`. |
| **rizzo-pii** تطبيق 2.0.0 / نموذج v1.5.0 | قاموس محلي `placeholder → قيمة`. | على القرص داخل العملية؛ يمكن إطفاؤه. | القاموس. `POST /pdf` يبنيه داخليًا **ولا يرسله على السلك**. | `PII_MAPPING=0` / `--no-mapping` / `include_mapping: false`: لا تُبنى خريطة، ولا تُعاد القيم الأصلية في `segments`. عندها لا يوجد مفتاح استرداد. |
| **OpenMed** `docs/anonymization.md` | JSON `mapping` يُرجع مع `keep_mapping=True`. | عند **المستدعي**، منفصلًا. | `reidentify(text, mapping)`. التكرار يأخذ أرقامًا (`[first_name]`, `[first_name_2]`). | بلا `keep_mapping` الطريقة نفسها غير عكسية. `SurrogateVault` يخزن HMAC→بديل لا السطح الخام؛ ذلك ثبات أسماء مستعارة عبر وثائق، لا مفتاح استرداد للأصل. |
| **Censgate Redact** `redact-core` 0.12.5 / بوابة v0.12.4 | `TokenMapping` مختوم AES-256-GCM. المخزن يرى ciphertext فقط. | `TokenMapStore` تحت `(tenant, session)`: `off` (افتراضي) أو `memory` TTL أو `vault_kv2`. | `POST /v1/restore` بـ `session_id` (أو alias `vault.context_id`) + DEK العملية (`CENSGATE_TOKEN_DEK`). على مسار الرد إن `restore_responses`. | `off`: داخل الطلب الذي أنشأ الرموز فقط، بلا `/v1/restore` لاحق. `memory`: لا يعيش إعادة التشغيل. TTL افتراضي 3600 ث. |
| **LLM SecretGuard** مساحة العمل **0.3.6** | خزنة ثنائية الاتجاه `secret ↔ [GUARD:type:hash]` (BLAKE3، 12 hex). | ذاكرة العملية: `VAULT_STORE` (`DashMap<u64, Vault>`) بمفتاح `vault_id`. | مسار **الوكيل**: `SecretGuard::restore(vault_id, text)` قبل إعادة الرد للعميل. | TTL افتراضي **300 ث**؛ بعده لا يُسترد. `Drop` يصفر الذاكرة. مسار HTTP **PII** (`/v1/pii/analyze`) يستبدل بـ `[REDACTED:label]` عبر `redact_text` **بلا هذه الخزنة**. المساران لا يُطويان. |

**ما ليس خريطة جلسة:** packyme يعلن «no un-redaction». OpenAI privacy-filter لا يوثّق خزنة استرداد. Presidio يعيد **التشفير AES** بمفتاح في `OperatorConfig` لدى المستدعي، ويصرّح أنه لا يحفظ جلسات. BentoPDF حذف دائم. Worka يسجّل الأصل بجانب البديل في أثر تدقيق بالذاكرة؛ خريطة جلسات دائمة غير موثّقة.

**diff-lab-com/secret-guard 0.1.0** (ليس صف القائمة): HMAC `SG1:` + سجل `surrogate→secret` يملكه المضيف + `restore --pairs map.json`. خريطة قيم عند المضيف، بلا بوابة HTTP. يُذكر هنا حتى لا يُخلط مع Secret Guard الصحيح.

---

## الجدول

| # | المشروع والإصدار | 1. إيجاد مناطق الحماية | 2. الحماية والاسترداد | 3. النطاق | الوسم |
|---|---|---|---|---|---|
| — | **Z Privacy** · `d882c5f` · `z_core 0.1.0` | قواعد محلية + قوائم أسماء + تحديد يدوي للنطاق. لا نموذج NER خارجي في هذا البناء. IBAN/بريد/هاتف تلقائيًا؛ الأسماء تحتاج قرارًا. | استبدال `__Z_<ns>_<KIND>_<tail>__`. الاسترداد بمفتاح الجلسة + قائمة الأسماء المسموحة (القيم ليست في `.zs`). خزنة للكلمات Always. النسخ داخل الجلسات محمية لأن الجلسات خارج جسم الخزنة. | شات: إرسال OpenAI-متوافق داخل التطبيق (**مباشر**). PDF: تصدير صفحة محمية جديدة (**مباشر**). | إيجاد/حفظ: **مؤكدة من الكود**. شات نصي وPDF المصدَّر: **مختبرة**. استرداد PDF بعد إعادة الفتح: **غير معلومة**. |
| 1 | **OpenAI privacy-filter** · [openai/privacy-filter](https://github.com/openai/privacy-filter) · إعلان [22 Apr 2026](https://openai.com/index/introducing-openai-privacy-filter/) · أوزان [huggingface.co/openai/privacy-filter](https://huggingface.co/openai/privacy-filter) | نموذج **محلي**، 8 فئات، BIOES + Viterbi. CLI `opf`. | إخفاء/حجب للنطاقات. لا خريطة استرداد ولا خزنة جلسات في README. | محرك نص/CLI. الشات وPDF = **تكامل يدوي**. | **موثقة** · **غير مختبرة** |
| 2 | **packyme/privacy-filter** · [packyme/privacy-filter](https://github.com/packyme/privacy-filter) · README الرئيسي 2026-10-13 | regex (بريد، هاتف، هوية، بطاقة Luhn، IP) + gitleaks/entropy. **بلا** NER للأسماء. | استبدال نوعي `[邮箱]`… **غير قابل للعكس** («no un-redaction»). | بوابة: مكتبة / `POST /redact` :8088 / gRPC :8089 (**مباشر** للنص). PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 3 | **Masquerade** · [postralai/masquerade](https://github.com/postralai/masquerade) · README 2026-10-13 | PDF→نص ثم نموذج **خارجي**: Tinfoil Llama 3.3 70B. | حجب داخل PDF. استرداد الأصل بعد الاستعلام: **غير معلوم**. | PDF عبر MCP (**مباشر** للحجب). الاستعلام: **تكامل يدوي** (رفع الملف المحجوب إلى Claude). شات داخل المنتج: لا. | **موثقة** · **غير مختبرة** |
| 4 | **Presidio** · [data-privacy-stack/presidio](https://github.com/data-privacy-stack/presidio) · دليل [anonymizer](https://presidio.dataprivacystack.org/anonymizer/) 2026-10-13 | NER محلي + regex + checksum + recognizers. صور عبر Image Redactor. | replace / mask / redact / hash / **encrypt**. الاسترداد: `DeanonymizeEngine` + **Decrypt** AES؛ المفتاح عند المستدعي. «Presidio does not store or maintain stateful sessions». | مكتبة/HTTP/Docker. الشات وPDF = **تكامل يدوي**. مسار PDF كوثيقة دردشة: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 5 | **BentoPDF** · [alam00000/bentopdf](https://github.com/alam00000/bentopdf) · [v2.8.8](https://github.com/alam00000/bentopdf/releases/tag/v2.8.8) 29 Aug 2026 | **تحديد يدوي**. لا ماسح PII في README. | **Redact Content**: حذف دائم. Sanitize / Remove Metadata. لا استرداد. | PDF في المتصفح (**مباشر**). شات: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 6 | **OpenMed** · [maziyarpanahi/openmed](https://github.com/maziyarpanahi/openmed) · [`docs/anonymization.md`](https://github.com/maziyarpanahi/openmed/blob/master/docs/anonymization.md) 2026-10-13 | نموذج **محلي** `extract_pii`؛ يمكن توجيه `openai/privacy-filter`. | mask / remove / replace / hash / shift_dates. الاسترداد: `keep_mapping=True` ثم `reidentify`. الخريطة JSON عند المستدعي. | REST `/analyze` و `/pii/*` (**مباشر** للنص). PDF كمنتج: **غير معلوم**. شات: **تكامل يدوي**. | **موثقة** · **غير مختبرة** |
| 7 | **rizzo-pii** · [Rizzo-AI-Academy/rizzo-pii](https://github.com/Rizzo-AI-Academy/rizzo-pii) · التطبيق 2.0.0 · النموذج `rizzo-pii-0.3B` **v1.5.0** · [`src/app/app.py`](https://github.com/Rizzo-AI-Academy/rizzo-pii/blob/main/src/app/app.py) | نموذج **محلي** mmBERT ≈0.3B + شبكة regex/checksum. استبعاد وسم يبقيه مكشوفًا. | `[FULLNAME_1]`… + قاموس قرص يمكن إطفاؤه. | شات: نسخ ثم استرداد محلي (**تكامل يدوي**). PDF: `POST /pdf` حجب في التيار (**مباشر**). HTTP `POST /analyze` :5005. | **موثقة** · **مؤكدة من الكود** · **غير مختبرة** |
| 8 | **Censgate Redact** · [censgate/redact](https://github.com/censgate/redact) · `redact-core` **0.12.5** · بوابة [v0.12.4](https://github.com/censgate/redact/releases/tag/v0.12.4) `46996f8` 12 Sep 2026 | 61 نوعًا مُجمَّعًا + NER اختياري ONNX. | mask/replace/hash/encrypt/tokenize. الاسترداد: `POST /v1/restore` + `TokenMapStore`. | شات: بوابة `POST /v1/chat/completions` و `POST /v1/redact` (**مباشر**). REST `POST /api/v1/analyze`. PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 9 | **Worka PII** · [worka-ai/pii](https://github.com/worka-ai/pii) · crate `pii` **0.1.0** | regex + validator + قواميس + NER اختياري Candle. | redact / mask / replace / hash. أثر تدقيق بالذاكرة. خريطة جلسات دائمة: **غير معلومة**. | مكتبة نص = **تكامل يدوي**. لا تطبيق شات. PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 10 | **Secret Guard** = **LLM SecretGuard** · [codeberg.org/roobai/llm-secretguard](https://codeberg.org/roobai/llm-secretguard) · مساحة العمل **v0.3.6** | أسرار: 222 gitleaks + entropy (`guard-core`). PII (ميزة): NER SecretGuard v3 + 70 recognizer. | مسار الوكيل: `[GUARD:type:hash]` + خزنة ذاكرة `vault_id` TTL 300ث + `restore`. مسار `/v1/pii/analyze`: `[REDACTED:label]` **بلا** تلك الخزنة. سياسة Allow/Redact/Drop/HardDrop. | شات: وكيل عكسي افتراضي `:8080` إلى Anthropic/OpenAI (**مباشر**). PDF: **غير معلوم**. الباب الموثّق للتحليل: `POST /v1/pii/analyze` لا `:5007/analyze`. | إيجاد/وكيل/خزنة: **موثقة** و**مؤكدة من الكود**. PDF والدورة `:5007`: **غير معلومة**. **غير مختبرة**. |

Z Privacy صف مرجعي فوق القائمة، لا بديلًا عن أي مشروع.

---

## سجل الادعاءات — رابط الملف والإصدار لكل معلومة

كل صف: الادعاء · المصدر · الإصدار/التاريخ · الوسم.

### Z Privacy · المنتج `d882c5f` · `z_core 0.1.0`

| الادعاء | الملف | الوسم |
|---|---|---|
| ملف الجلسة صيغة v2 يحفظ `allowed` أسماء لا قيمًا؛ قائمة فارغة لا تسترد | [`z_core/src/conversation.rs`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/z_core/src/conversation.rs) `SESSION_FORMAT_VERSION` و`Turn.allowed` | مؤكدة من الكود |
| الجلسة خارج `vault.zv` لأن الجسم يُعاد ختمه كاملًا | نفس الملف، التعليق الافتتاحي | مؤكدة من الكود |
| مفتاح الجلسة 32 بايت يشتق النطاق ومفتاح القيمة | [`z_core/src/tokens.rs`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/z_core/src/tokens.rs) `Naming::of_session` | مؤكدة من الكود |
| `restore` يشترط القائمة **و** TokenStore وإلا `Unresolved` | نفس الملف، الدالة `restore` | مؤكدة من الكود |
| مفاتيح الجلسات في الخزنة والمحادثات لم تكن فيها | [`apps/flutter_app/lib/screens/settings.dart`](file:///home/monopeaks/mono-privacy-comparison-20261013-022102/apps/flutter_app/lib/screens/settings.dart) نص Sessions | مؤكدة من الكود |
| شات OpenAI-متوافق داخل التطبيق | `z_core/src/openai.rs` · `POST /v1/chat/completions` | مؤكدة من الكود |
| PDF صفحة محمية محلية بلا شبكة | `apps/flutter_app/lib/protected_pdf.dart` | مؤكدة من الكود |
| تصدير PDF رملي 28 رمزًا نطاق `1F52` | `tests/cycle/sandbox/home/Documents/zprivacy/text-protected-2026-10-13.pdf` sha256 `1776f077…` | مختبرة (استخراج) |
| استرداد سبعة رموز في الشات كنص معروض | تجربة يدوية 2026-10-13؛ `GET /requests` بقي `[]` | مختبرة كنص معروض، ليست التقاط سلك |
| استرداد PDF بعد إعادة فتح النافذة | لم تُرصد | غير معلومة |

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

### 10. Secret Guard = LLM SecretGuard v0.3.6

هوية الصف: المنتج المسمّى SecretGuard ذو **وضع بوابة/وكيل** وتحليل PII. سقالة الدورة على GitHub تذكر «Secret Guard — gateway mode» على `:5007` **بلا رابط مستودع**. المستودع المطابق بالاسم والبوابة والتحليل هو Codeberg أدناه. مسار الدورة `:5007/analyze` **افتراض سقالة**؛ المنتج يعلن `:8080` و`POST /v1/pii/analyze`. غياب `/analyze` الحرفي لا ينفي الوظيفة.

| الادعاء | الملف | الوسم |
|---|---|---|
| اسم المنتج LLM SecretGuard؛ وكيل محلي `:8080`؛ عناصر `[GUARD:type:hash]`؛ TTL 300ث؛ سياسة Allow/Redact/Drop | [README.md](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/README.md) How It Works / Policy / Limitations | موثقة |
| مساحة العمل الإصدار **0.3.6** | [Cargo.toml](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/Cargo.toml) `[workspace.package] version = "0.3.6"` جُلب 2026-10-13 من `main` | مؤكدة من الكود |
| 222 gitleaks + vault BLAKE3/DashMap في guard-core | README Architecture؛ [crates/guard-core/src/lib.rs](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/crates/guard-core/src/lib.rs) | موثقة / مؤكدة من الكود |
| خزنة ثنائية، `VAULT_STORE`، `redact`→`[GUARD:…:12hex]`، `restore`، TTL، zeroize | [crates/guard-core/src/vault.rs](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/crates/guard-core/src/vault.rs) | مؤكدة من الكود |
| `scan_outbound` يخزن الخزنة؛ `SecretGuard::restore(vault_id, text)` | [guard-core/src/lib.rs](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/crates/guard-core/src/lib.rs) | مؤكدة من الكود |
| مسارات `/v1/pii/analyze` و`/v1/scan` و`/v1/redact` وfallback وكيل | [crates/guard-proxy/src/lib.rs](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/crates/guard-proxy/src/lib.rs) `build_router` | مؤكدة من الكود |
| `pii_analyze` يجمع detect+redact+stats؛ النموذج `secretguard-ner-v3` | [crates/guard-proxy/src/pii.rs](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/crates/guard-proxy/src/pii.rs) | مؤكدة من الكود |
| `/v1/scan` و`/v1/redact` يفوّضان حاليًا إلى PII فقط (TODO ماسح الأسرار) | نفس `pii.rs` تعليقات `combined_scan` / `combined_redact` | مؤكدة من الكود |
| مسار PII يستبدل بـ `[REDACTED:label]` بلا خزنة الوكيل | [crates/guard-pii/src/model.rs](https://codeberg.org/roobai/llm-secretguard/raw/branch/main/crates/guard-pii/src/model.rs) `redact_text` | مؤكدة من الكود |
| PII: NER v3 + 70 recognizer؛ أوزان Hugging Face | README PII Detection؛ `GLINER_REPO` في guard-pii | موثقة |
| الشات مباشر عبر الوكيل إلى Anthropic/OpenAI | README How It Works وConfigure your agent | موثقة |
| PDF | لا ذكر في README ولا في مسارات الوكيل | غير معلوم |
| سقالة الدورة تتوقع `:5007` gateway | [tests/cycle/README.md](https://raw.githubusercontent.com/YourVoicesApp/z-privacy/tests/cycle/tests/cycle/README.md) فرع `tests/cycle` `b42cf0e` | موثقة (سقالة ≠ هوية المنتج) |

**ليسا صف هذه القائمة (مذكوران حتى لا يُستبدلا):**

| الاسم | لماذا ليس الصف | المصدر |
|---|---|---|
| [chintanshah35/secretguard](https://github.com/chintanshah35/secretguard) | ماسح CI/`npx secretguard`؛ لا وكيل LLM ولا خزنة استرداد محادثة | [README](https://raw.githubusercontent.com/chintanshah35/secretguard/main/README.md) |
| [diff-lab-com/secret-guard](https://github.com/diff-lab-com/secret-guard) crates.io **0.1.0** (نشر مذكور 2026-09) | مكتبة+CLI `scan|surrogate|restore --pairs`؛ HMAC `SG1:`؛ بلا HTTP بوابة. «blueprint artifact (a)» لـ shannon-mono | [README](https://raw.githubusercontent.com/diff-lab-com/secret-guard/main/README.md) |

---

## Z Privacy — ملخص الأدلة (بلا توسيع اختبار)

**إيجاد (محور 1).** `scanner/mod.rs` · `general_rules.rs` · `people.rs`. تلقائي لما «لا يُعقل أن يكون غير ذلك» (IBAN+checksum، بريد، هاتف…). أسماء القاموس لا تُحمى تلقائيًا. التحديد اليدوي من الحوار. **مؤكدة من الكود.** التجربة الألمانية: حماية يدوية لمقاطع، لا إثباتًا للكشف التلقائي. **مختبرة** كنص معروض.

**حماية واسترداد (محور 2).** الرمز من مفتاح الجلسة (`Naming::of_session`). ملف الجلسة يخزن **أسماء** مسموحة لا خريطة قيم. `restore()` يعيد القيمة إن وُجد الرمز في TokenStore وفي القائمة. الخزنة تحفظ مفتاح الجلسة المختوم وكلمات Always. **مؤكدة من الكود.** استرداد سبعة رموز في الشات بعد لصق الإجابة: **مختبرة** كنص معروض. استرداد رموز PDF بعد إعادة الفتح: **غير معلومة**.

**نطاق (محور 3).** شات داخل التطبيق. PDF عبر `protected_pdf.dart`. الملف الرملي `text-protected-2026-10-13.pdf`، 28 قيمة، نطاق `1F52`. **مختبرة** استخراجًا.

تجربة PDF بعد إغلاق النافذة المعزولة لم تُستكمل؛ أُوقف التوسيع هنا.

---

## أقرب المشاريع إلى Z

القرب تشابه في **شكل العمل** على المحاور الثلاثة، لا ترتيب جودة. بعد إكمال Secret Guard صارت أربعة، لا ثلاثة.

1. **rizzo-pii** — أقرب تشابه للمنتج ككل: إيجاد محلي → عنصر نائب → نموذج يرى الرموز → استرداد محلي، مع واجهة وثيقة وPDF محمي. الفرق الجوهري: قاموس قيم على القرص يمكن إطفاؤه، مقابل مفتاح جلسة وأسماء مسموحة عند Z.
2. **Censgate Redact** — أقرب تشابه لمسار الشات + مفتاح سياق: بوابة OpenAI-متوافقة و`/v1/restore` و`TokenMapStore` تحت `session_id`. الخريطة مختومة؛ الافتراضي `off` يجعل الاسترداد داخل الطلب فقط.
3. **LLM SecretGuard** — أقرب تشابه لوكيل الشات + خزنة عملية: يعترض الطلب، يستبدل، يمرّر، يسترد قبل العميل. الخزنة ذاكرة TTL 300ث بمفتاح `vault_id`. مسار `/v1/pii/analyze` منفصل وغير عكسي بالخزنة. PDF غير موثّق.
4. **OpenMed** — أقرب تشابه لمحرك النص القابل للعكس: `keep_mapping` + `reidentify` لدى المستدعي. بلا تطبيق سطح مكتب وبلا PDF موثّق.

هذه الأربعة تغطي معًا: إيجادًا محليًا، عنصرًا نائبًا، إرسالًا إلى نموذج، واستردادًا محليًا. لذلك **لا يثبت** من هذه القائمة أن جمع تلك الخطوات متفرد عند Z. ما يتجه إليه Z كمنتج (مفتاح جلسة مشتق، فصل نطاق الكلمة عن حفظ الوثيقة، سطح مكتب، PDF صفحة جديدة، خزنة Always) اتجاه بناء، لا حكم تفرّد بين العشرة.

---

## المشترك المدعوم بالأدلة

- **عنصر نائب ثم استرداد:** Z (مفتاح جلسة + أسماء مسموحة)، rizzo-pii (قاموس قرص)، OpenMed (JSON المستدعي)، Censgate (`TokenMapStore` + `/v1/restore`)، Secret Guard (خزنة ذاكرة الوكيل). Presidio يعيد التشفير AES فقط إن اختير encrypt.
- **إيجاد محلي بلا رفع الوثيقة إلى مزوّد النموذج:** Z، OpenAI PF، packyme، Presidio، OpenMed، rizzo-pii، Censgate، Worka، BentoPDF، Secret Guard (الوكيل على الحلقة المحلية). Masquerade يرسل النص إلى Tinfoil للكشف.
- **قواعد/checksum للحقول المنظمة:** Z، packyme، Presidio، rizzo-pii، Censgate، Worka، Secret Guard (recognizers + gitleaks).
- **نموذج تصنيف محلي للأسماء:** OpenAI PF، Presidio، OpenMed، rizzo-pii؛ Censgate/Worka/Secret Guard اختياريًا أو بميزة. Z في هذا البناء: قوائم + يدوي.
- **PDF كملف محمي:** Z (صفحة جديدة)، rizzo-pii (حجب في التيار)، BentoPDF وMasquerade (داخل الملف). Secret Guard: غير معلوم.
- **شات كمسار منتج:** Z إرسال داخلي؛ Censgate وpackyme وSecret Guard بوابة/وكيل؛ rizzo-pii وMasquerade نسخ/رفع يدوي.

---

## الفروق المدعومة بالأدلة

| الفرق | الدليل |
|---|---|
| مفتاح جلسة مقابل خريطة قيم | انظر القسم أعلاه. Z يخزن أسماءً ومفتاحًا لا القيم في `.zs`. rizzo يخزن القيم ويمكن إطفاء ذلك. OpenMed يسلّم JSON للمستدعي. Censgate يخزن ciphertext تحت session. Secret Guard يخزن القيم في DashMap TTL. |
| مساران داخل Secret Guard | وكيل: `[GUARD:…]` + vault_id. HTTP PII: `[REDACTED:label]` بلا vault. لا يُستنتج الاسترداد من وجود `/v1/pii/analyze`. |
| أين يعيش النص المحفوظ | Z: الجلسات خارج الخزنة والنسخة فيها محمية؛ PDF خارج التطبيق. rizzo: القاموس محلي والـ PDF بلا قاموس على السلك. Censgate: اختياري off/memory/KV. Secret Guard: ذاكرة عملية. |
| نطاق إعادة حماية الكلمة | Z: Just here / This conversation / Remember everywhere (وأحيانًا Remember for client). لا يُستنتج منه الاسترداد. الباقي لا يصف هذا التقسيم الرباعي. |
| الشات | Z وCensgate وSecret Guard: مسار مباشر. packyme: بوابة نص. rizzo: لصق. Masquerade: رفع بعد الحجب. |
| شكل PDF | Z: صفّ جديد + تذييل. rizzo: استبدال في content stream. BentoPDF/Masquerade: تحرير الأصل. Secret Guard/Censgate/OpenMed: غير موثّق كمنتج PDF. |
| الكشف عن الأسماء | rizzo/OpenAI PF/OpenMed/Presidio/Secret Guard-NER: نموذج. packyme: بلا أسماء. BentoPDF: يدوي. Masquerade: Llama خارجي. Z: قاموس + قرار يدوي. |
| الباب HTTP | rizzo/Presidio/OpenMed/Censgate REST: `/analyze` أو مكافئ. packyme: `/redact`. Censgate gateway: `/v1/redact` + `/v1/restore`. Secret Guard: `/v1/pii/analyze` ووكيل `/*`. Z: `/v1/chat/completions` للإرسال، بلا `/analyze`. الباب ≠ الوظيفة. |
| عمر الاسترداد | Z: ما دامت الجلسة ومخزنها. rizzo: ما دام القاموس. Censgate memory: TTL 3600ث. Secret Guard vault: TTL 300ث. OpenMed: ما دام ملف الخريطة عند المستدعي. |

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

## خارج النطاق · لاحقًا

- لا تدقيق شامل لأي منتج، ولا تحسين Z، ولا إدخال المكتبة.
- **مسار الترجمة** لهذه الدراسة: **مهمة لاحقة فقط**، غير منجزة هنا.
- تشغيل rizzo-pii وSecret Guard وبقية التسعة: غير مطلوب لهذا التسليم.
- استكمال دورة PDF المعزولة: متوقف.
- لا ادّعاء تفرّد لجمع الميزات بين العشرة؛ الأدلة تُظهر تداخلًا مع أربعة مشاريع قريبة.

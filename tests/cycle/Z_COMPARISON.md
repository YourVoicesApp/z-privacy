# دراسة مقارنة — ثلاثة محاور · القائمة الأصلية لعشرة مشاريع

نسخة العمل `/home/monopeaks/mono-privacy-comparison-20261013-022102` · الفرع `comparison/local-cycle`.
Z Privacy: المنتج HEAD `d882c5f` · الختم `z_core 0.1.0 · 2026-10-13 · 61fa27b`.
تاريخ الأدلة: 2026-10-13.

**اختبارات Z وتجهيزاتها متوقفة عند هذا التسليم.** إعادة فتح PDF بعد الإغلاق، والجلسة الثانية، وتوسيع الأدوات، ليست جزءًا من هذه النتيجة.

الأصل، والنسخة الاحتياطية، وGitHub، ومكتبة ZPrivacy-lib: بلا كتابة. المكتبة خارج المقارنة.

**وسوم الدليل:** موثقة · مؤكدة من الكود · مختبرة · غير معلومة.
غياب `/analyze` من دليل مشروع لا يثبت غياب وظيفته. تشغيل المشاريع العشرة ليس شرطًا للتسليم. لم يُستبدل أي اسم في القائمة الأصلية.

---

## المحاور الثلاثة

1. **إيجاد مناطق الحماية:** نموذج محلي أو خارجي، قواعد، قوائم، أو تحديد يدوي.
2. **الحماية والاسترداد:** حذف أو استبدال أو تشفير؛ كيف تُستعاد القيم وأين تُحفظ المفاتيح أو الخرائط.
3. **النطاق:** شات، PDF، أو كلاهما. **دعم مباشر** = مسار المنتج نفسه. **تكامل يدوي** = نسخ/لصق أو رفع لاحق أو بوابة يركّبها المدمج.

في محور الحماية عند Z تبقى ثلاثة أمور مستقلة: نطاق إعادة حماية **الكلمة**، مكان حفظ **الوثيقة**، ومفتاح استرداد **الجلسة**. لا يُستنتج أحدها من زر يخص الآخر.

---

## الجدول

| # | المشروع والإصدار | 1. إيجاد مناطق الحماية | 2. الحماية والاسترداد | 3. النطاق | الوسم |
|---|---|---|---|---|---|
| — | **Z Privacy** · `d882c5f` · `z_core 0.1.0` | قواعد محلية + قوائم أسماء + تحديد يدوي للنطاق. لا نموذج NER خارجي في هذا البناء. IBAN/بريد/هاتف تلقائيًا؛ الأسماء تحتاج قرارًا. | استبدال برموز `__Z_<ns>_<KIND>_<tail>__`. الاسترداد بمفتاح الجلسة الموافقة + قائمة الأسماء المسموحة. خزنة للكلمات Always. النسخ داخل الجلسات محمية لأن `sessions/*.zs` خارج جسم الخزنة. | شات: إرسال OpenAI-متوافق داخل التطبيق (**مباشر**). PDF: تصدير صفحة محمية جديدة (**مباشر**). | إيجاد/حفظ: **مؤكدة من الكود**. شات نصي وPDF المصدَّر: **مختبرة**. استرداد PDF بعد إعادة الفتح: **غير معلومة** (لم تُرصد). |
| 1 | **OpenAI privacy-filter** · [github.com/openai/privacy-filter](https://github.com/openai/privacy-filter) · إعلان [22 Apr 2026](https://openai.com/index/introducing-openai-privacy-filter/) · أوزان [huggingface.co/openai/privacy-filter](https://huggingface.co/openai/privacy-filter) · 1.5B / 50M نشط · Apache 2.0 | نموذج **محلي** لتصنيف الرموز، 8 فئات، BIOES + Viterbi. CLI `opf`. | إخفاء/حجب للنطاقات. لا خريطة استرداد ولا خزنة جلسات في الدليل. | محرك نص/CLI. الشات وPDF = **تكامل يدوي** لمُدمِج. | **موثقة** · **غير مختبرة** |
| 2 | **packyme/privacy-filter** · [github.com/packyme/privacy-filter](https://github.com/packyme/privacy-filter) · README الرئيسي | قواعد regex (بريد، هاتف، هوية، بطاقة Luhn، IP) + gitleaks/entropy. **بلا** NER للأسماء/الأماكن/المؤسسات (مذكور صراحة). | استبدال بعناصر نوعية `[邮箱]` `[电话]` … **غير قابلة للعكس** («no un-redaction»). | بوابة LLM: مكتبة / `POST /redact` :8088 / gRPC :8089 (**مباشر** للنص في البوابة). PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 3 | **Masquerade** · [github.com/postralai/masquerade](https://github.com/postralai/masquerade) · README + `docs/faq.md` | PDF→نص ثم نموذج **خارجي**: Tinfoil Llama 3.3 70B. | حجب داخل PDF (PyMuPDF). المعاينة ثم الرفع. استرداد القيم الأصلية بعد الاستعلام: **غير معلوم** في README. سكربت `pseudonymize_data.py` يستبدل بقيم جديدة عبر LLM. المستندات المحمية/الممسوحة لا تُعالج. | PDF عبر MCP (**مباشر** للحجب). الاستعلام: **تكامل يدوي** (رفع الملف المحجوب إلى Claude). شات داخل المنتج: لا. | **موثقة** · **غير مختبرة** |
| 4 | **Presidio** · [github.com/data-privacy-stack/presidio](https://github.com/data-privacy-stack/presidio) بعد نقل microsoft/presidio · دليل [presidio.dataprivacystack.org](https://presidio.dataprivacystack.org/) · 2026-10-13 | NER محلي + regex + checksum + قوائم/recognizers مخصصة. صور عبر Image Redactor + OCR. | عوامل: replace / mask / redact / hash / **encrypt**. الاسترداد: `DeanonymizeEngine` + **Decrypt** AES؛ المفتاح في `OperatorConfig` لدى المستدعي. الاستبدال العادي بلا خريطة. | مكتبة/HTTP/Docker. الشات وPDF = **تكامل يدوي**. Image Redactor للصور/DICOM. مسار PDF كوثيقة دردشة: **غير معلوم**. | **موثقة** · **غير مختبرة**. روابط Microsoft القديمة: 200 مع تحويل/إشعار نقل، لا 404 مستمر |
| 5 | **BentoPDF** · [github.com/alam00000/bentopdf](https://github.com/alam00000/bentopdf) · الإصدار [v2.8.8](https://github.com/alam00000/bentopdf/releases/tag/v2.8.8) · 29 Aug 2026 | **تحديد يدوي**. لا ماسح PII في README. | **Redact Content**: حذف دائم من الملف. Sanitize / Remove Metadata. لا استرداد للنص المحذوف. | PDF في المتصفح (**مباشر**، على الجهاز). شات: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 6 | **OpenMed** · [github.com/maziyarpanahi/openmed](https://github.com/maziyarpanahi/openmed) · `docs/anonymization.md` + skills `deidentifying-clinical-text` / `reidentifying-text` | نموذج **محلي** سريري `extract_pii`؛ سياسات HIPAA/GDPR؛ يمكن توجيه `openai/privacy-filter`. | mask / remove / replace / hash / shift_dates. الاسترداد: `deidentify(..., keep_mapping=True)` ثم `reidentify`. الخريطة JSON يحتفظ بها المستدعي منفصلة ومشفّرة. | REST `/analyze` و `/pii/*` (**مباشر** للنص). PDF كمنتج: **غير معلوم**. شات: **تكامل يدوي**. | **موثقة** · **غير مختبرة** |
| 7 | **rizzo-pii** · [github.com/Rizzo-AI-Academy/rizzo-pii](https://github.com/Rizzo-AI-Academy/rizzo-pii) · التطبيق 2.0.0 · النموذج `rizzo-pii-0.3B` **v1.5.0** · [README](https://github.com/Rizzo-AI-Academy/rizzo-pii/blob/main/README.md) | نموذج **محلي** mmBERT ≈0.3B (22 وسمًا) + شبكة regex/checksum (IBAN/CF/PIVA/Luhn). استبعاد وسم يبقيه مكشوفًا. | استبدال `[FULLNAME_1]`… + **قاموس محلي على القرص**. يمكن إغلاق القاموس (`PII_MAPPING=0`) فلا تُبنى خريطة. | شات: نسخ إلى LLM ثم استرداد محلي (**تكامل يدوي**). PDF: `POST /pdf` حجب داخل تيار المحتوى (**مباشر**). HTTP `POST /analyze` :5005. | **موثقة** · **غير مختبرة** |
| 8 | **Censgate Redact** · [github.com/censgate/redact](https://github.com/censgate/redact) · crates `redact-core` **0.12.5** · ملاحظات [v0.12.4](https://github.com/censgate/redact/releases/tag/v0.12.4) 12 Sep 2026 | 61 نوعًا مُجمَّعًا (قواعد) + NER اختياري ONNX. | mask/replace/hash/encrypt. الاسترداد: `POST /v1/restore` مع `session_id` / `vault.context_id`. الخريطة في `TokenMapStore` (ذاكرة أو `vault_kv2`). | شات: بوابة OpenAI-متوافقة `POST /v1/redact` (**مباشر**). REST `POST /api/v1/analyze`. PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 9 | **Worka PII** · [github.com/worka-ai/pii](https://github.com/worka-ai/pii) · crate `pii` **0.1.0** · [worka.ai/docs/pii](https://worka.ai/docs/pii) | regex + validator + قواميس + NER اختياري Candle. أنواع مدمجة للبريد/الهاتف/IBAN/…؛ PERSON/LOCATION/ORG مع NER. | redact / mask / replace / hash. سجل تدقيق يحتفظ بالأصل بجانب البديل في الذاكرة. خريطة جلسات دائمة: **غير معلومة**. | مكتبة لنص (بما فيه المطالبات) = **تكامل يدوي**. لا تطبيق شات. PDF: **غير معلوم**. | **موثقة** · **غير مختبرة** |
| 10 | **Secret Guard** · هدف الدورة `POST http://localhost:5007/analyze` (GitHub `tests/cycle` `b42cf0e`) | **غير معلوم** لهذا الهدف. لا مستودع مؤكد. | **غير معلوم**. | **غير معلوم**. | **غير معلوم**. [chintanshah35/secretguard](https://github.com/chintanshah35/secretguard) ماسح CI مختلف؛ **ليس** بديل الصف |

Z Privacy صف مرجعي فوق القائمة، لا بديلًا عن أي مشروع.

---

## Z Privacy — ملخص الأدلة (بلا توسيع اختبار)

**إيجاد (محور 1).** `scanner/mod.rs` · `general_rules.rs` · `people.rs`. تلقائي لما «لا يُعقل أن يكون غير ذلك» (IBAN+checksum، بريد، هاتف…). أسماء القاموس لا تُحمى تلقائيًا. التحديد اليدوي من الحوار. **مؤكدة من الكود.** التجربة الألمانية: حماية يدوية لمقاطع، لا إثباتًا للكشف التلقائي. **مختبرة** كنص معروض.

**حماية واسترداد (محور 2).** الرمز من مفتاح الجلسة (`tokens.rs` `Naming::of_session`). `restore()` يعيد القيمة إن وُجد الرمز في TokenStore الجلسة وفي قائمة المسموح. ملف `sessions/N.zs` يحفظ السؤال بالشكل الذي سافر (رموز) لا خريطة القيم. الخزنة تحفظ مفتاح الجلسة المختوم وكلمات Always. **مؤكدة من الكود.** استرداد سبعة رموز في الشات بعد لصق الإجابة: **مختبرة** كنص معروض (ليست التقاط سلك؛ `GET /requests` بقي `[]`). استرداد رموز PDF بعد إعادة الفتح: **غير معلومة**.

**نطاق (محور 3).** شات داخل التطبيق (`openai.rs`، `POST /v1/chat/completions`). PDF عبر `protected_pdf.dart`: صفحة جديدة + تذييل. الملف الرملي `text-protected-2026-10-13.pdf`، 28 قيمة، نطاق `1F52`. **مختبرة** استخراجًا. لا شبكة في كتابة PDF.

تجربة PDF بعد إغلاق النافذة المعزولة لم تُستكمل؛ أُوقف التوسيع هنا.

---

## أقرب المشاريع إلى Z

القرب هنا تشابه في **شكل العمل** على المحاور الثلاثة، لا ترتيب جودة.

1. **rizzo-pii** — أقرب تشابه للمنتج ككل: إيجاد محلي → عنصر نائب → نموذج خارجي يرى الرموز فقط → استرداد محلي، مع واجهة وثيقة وPDF محمي.
2. **Censgate Redact** — أقرب تشابه لمسار الشات + خريطة جلسة: بوابة OpenAI-متوافقة و`/v1/restore` بمفتاح سياق.
3. **OpenMed** — أقرب تشابه لمحرك النص القابل للعكس: `keep_mapping` + `reidentify`، بلا تطبيق سطح مكتب وبلا PDF موثّق.

لا يُفترض تفوق Z ولا تفرّده. الثلاثة أعلاه تغطي أجزاء من العمل نفسه بطرق أخرى.

---

## المشترك المدعوم بالأدلة

- **عنصر نائب ثم استرداد محلي:** Z (`__Z_…__` + مفتاح جلسة)، rizzo-pii (`[TAG_n]` + قاموس قرص)، OpenMed (`keep_mapping` + `reidentify`)، Censgate (`TokenMapStore` + `/v1/restore`). Presidio يعيد التشفير AES فقط إن اختير عامل encrypt.
- **إيجاد محلي بلا رفع الوثيقة إلى مزوّد النموذج:** Z، OpenAI privacy-filter، packyme، Presidio، OpenMed، rizzo-pii، Censgate، Worka، BentoPDF. Masquerade يرسل النص إلى Tinfoil للكشف.
- **قواعد/checksum للحقول المنظمة:** Z، packyme، Presidio، rizzo-pii، Censgate، Worka.
- **نموذج تصنيف محلي للأسماء والسياق:** OpenAI privacy-filter، Presidio، OpenMed، rizzo-pii؛ Censgate/Worka اختياريًا. Z يعتمد قوائم + يدوي للأسماء في هذا البناء.
- **PDF كملف محمي:** Z (صفحة جديدة)، rizzo-pii (حجب في التيار)، BentoPDF وMasquerade (داخل الملف الأصلي).
- **شات كمسار منتج:** Z إرسال داخلي؛ Censgate وpackyme بوابة؛ rizzo-pii وMasquerade نسخ/رفع يدوي.

---

## الفروق المدعومة بالأدلة

| الفرق | الدليل |
|---|---|
| خريطة الاسترداد | Z: مفتاح جلسة مشتق، القيم ليست في ملف الجلسة. rizzo-pii: قاموس `placeholder → قيمة` على القرص ويمكن إطفاؤه. OpenMed: JSON عند المستدعي. Censgate: `TokenMapStore` / OpenBao KV. Presidio encrypt: مفتاح AES في الإعداد. packyme: بلا عكس. BentoPDF: حذف دائم. |
| أين يعيش النص المحفوظ | Z: الجلسات خارج الخزنة والنسخة فيها محمية؛ PDF خارج التطبيق. rizzo-pii: القاموس محلي والـ PDF يُعاد من الخادم دون القاموس على السلك. |
| نطاق إعادة حماية الكلمة | Z: Just here / This conversation / Remember everywhere (وأحيانًا Remember for client). لا يُستنتج منه الاسترداد. الباقي لا يصف هذا التقسيم الرباعي في أدلته. |
| الشات | Z وCensgate: مسار مباشر. rizzo-pii: لصق. Masquerade: رفع يدوي بعد الحجب. OpenAI PF / Presidio / OpenMed / Worka: محركات للمُدمِج. |
| شكل PDF | Z: صفّ جديد للنص المحمي + تذييل. rizzo-pii: استبدال في content stream. BentoPDF/Masquerade: تحرير الملف الأصلي. |
| الكشف عن الأسماء | rizzo/OpenAI PF/OpenMed/Presidio: نموذج. packyme: بلا أسماء. BentoPDF: يدوي. Masquerade: Llama خارجي. Z: قاموس + قرار يدوي. |
| الباب HTTP | rizzo/Presidio/OpenMed/Censgate REST: `/analyze` أو مكافئ. packyme: `/redact`. Censgate gateway: `/v1/redact` + `/v1/restore`. Z: `/v1/chat/completions` للإرسال، بلا `/analyze`. الباب ≠ الوظيفة. |

---

## Presidio — الروابط المذكورة

| الرابط | HTTP في 2026-10-13 | النتيجة |
|---|---|---|
| https://github.com/microsoft/presidio | 200 | تحويل إلى data-privacy-stack/presidio |
| https://microsoft.github.io/presidio/ | 200 | إشعار نقل |
| https://data-privacy-stack.github.io/presidio/ | 200 | → presidio.dataprivacystack.org |
| https://github.com/data-privacy-stack/presidio | 200 | المستودع الحالي |

تعذّر الوصول المستمر (404) **لم يستمر** على هذه الروابط.

---

## خارج النطاق · لاحقًا

- لا تدقيق شامل لأي منتج، ولا تحسين Z، ولا إدخال المكتبة.
- **مسار الترجمة** لهذه الدراسة: **مهمة لاحقة فقط**، غير منجزة هنا.
- تشغيل rizzo-pii وSecret Guard وبقية التسعة: غير مطلوب لهذا التسليم.
- استكمال دورة PDF المعزولة: متوقف.

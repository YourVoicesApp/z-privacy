# ب٥ · جودة الكشف

**Commit:** `84832a015f74952556f5d512187a8d5f99673d9d`  
**Probe:** `/home/monopeaks/z-attack-final/fixtures/probes` (`b5` · `b5_escapes`)  
**Logs:** `logs/b5-scan.txt` · `logs/b5-escapes.txt`  
**Stamp:** `z_core 0.1.0 · 2026-10-17 · 84832a0`

ليست أماناً بالمعنى الضيق: قيمة فاتت بعد أن يجيب الإنسان على كل سؤال تخرج إن أُرسلت. هذا دين مقيس، لا crash. والعقد نفسه يقول إن Z لا يعد بإخفاء الهوية من السياق كله.

القياس بلا خزنة (إلّا مساري تعليم صريحين في الإفلات). نصوص التجربة نُسخت إلى `fixtures/docs/experiment/`؛ الذهبية قُرئت من `ZPrivacy-lib/parity-corpus/fixtures` للقراءة فقط.

---

## القياس على الوثائق الذهبية الخمس

الـcorpus في `ZPrivacy-lib/parity-corpus` مجمَّد على `d882c5f`. الأعداد أدناه من **هذا** الـcommit، بعد الإجابة على كل اقتراح (Protect)، ثم البحث في الحمولة عمّا بقي مكشوفاً.

| الوثيقة | لغة | auto | asked | بعد الإجابة: tokens | hidden | missed |
|---|---|---:|---:|---:|---:|---:|
| Vertrag_Nordstern.txt | de | 11 | 1 | 14 | 10 | 0 |
| Brief_Weber.txt | de | 29 | 8 | 38 | 32 | 0 |
| Lohnabrechnung_Weber.txt | de | 34 | 5 | 39 | 32 | 1 |
| Brev_Lindqvist.txt | sv | 14 | 6 | 23 | 19 | 12 |
| Risala_Alharbi.txt | ar/de | 5 | 2 | 7 | 7 | 14 |

نفس عدّ Risala تحت `de` و`ar`: 5 auto · 2 waiting (كما وعدت `languages.rs`).

### بالأنواع — ماذا حُمي / ماذا فات (بعد إجابة كل سؤال)

**Vertrag_Nordstern (de)** — لا فاتت قيمة من القائمة. IBAN/BIC/Email/Phone/TaxId/CustomerNo/Thomas/Müller/GmbH حُميت. إيجابية كاذبة Auto: التوقيع أخذ «Abteilung» و«Vertragswesen» شخصين.

**Brief_Weber (de)** — لا فاتت قيمة من خطاب المالك بعد الإجابة (الأسماء، الميلاد، الهوية، اللوحة، العميل، الضريبة، IBAN/BIC/بريد/هواتف). العناوين تُعرض سؤالاً وتُحمى إن أُجيب.

**Lohnabrechnung (de)** — Person / EmployeeNo / Birthdate / SV / TaxId / Iban / Bic / Email / Phone كما في 038-G. فات: عنوان الترويسة «Lindenstraße 8» (السطر بلا رقم بريدي مكتمل كحقل عنوان؛ «86150 Augsburg» و«Bahnhofstraße 27…» عُرضا).

**Brev_Lindqvist (sv)** — حُمي: Katarina/Lindqvist (تحية)، Amira Haddad، Jonas Pettersson، Markus Lindqvist (توقيع)، IBAN/BIC/Org.nr/personnummer/بريد/هواتف/شركات.  
فات: Tobias Reinholdsson، Sofia Brandt، Yusuf Demir (لا تحية ولا المعجم السويدي)، Bankgiro 5555-5555، لوحة ABC 123، ثلاثة عناوين، Moms SE556123456701.

**Risala_Alharbi** — لا حزمة عربية. القواعد العامة + `sets/world.rs`: IBAN/BIC/بريد/+966 وهواتف محلية كسؤال.  
فات: كل الأسماء العربية السبعة، رقم العميل، السجل التجاري، رقم الهوية 1012345678، رقمان ضريبيان، الميلاد، اللوحة.

---

## القياس على `~/نصوص التجربة` (نسخة `fixtures/docs/experiment`)

| الوثيقة | لغة | auto | asked | hidden | missed | أبرز ما فات بعد الإجابة |
|---|---|---:|---:|---:|---:|---|
| ألماني 1 | de | 12 | 5 | 12 | 0 | — |
| ألماني 2 | de | 15 | 3 | 11 | 2 | Versichertennummer A123456780؛ Rosenweg 3 |
| ألماني 3 | de | 11 | 1 | 6 | 0 | — |
| إنجليزي 1 | en | 7 | 3 | 9 | 4 | Daniel Okafor؛ HVS-55120؛ 22 Clifton Road |
| إنجليزي 2 | en | 9 | 1 | 8 | 6 | James (الاسم الأول)؛ DOB؛ NGE-20417؛ NI؛ PAN؛ العنوان |
| سويدي 1 | sv | 6 | 6 | 11 | 2 | bankgiro 5050-1055؛ Storgatan 12 |
| سويدي 2 | sv | 5 | 11 | 12 | 1 | Kungsgatan 44 |
| عربي 1 | de | 2 | 1 | 3 | 4 | كل الأسماء والشركة |
| عربي 2 | de | 1 | 1 | 2 | 5 | كل الأسماء؛ الهوية 1023456789 |

ألماني 1: «Herrn» ثم سطر ثم «Markus Feldmann» — الزوج عبر السطر Auto.  
ألماني 2: «Sehr geehrter Herr Kollege Albrecht» حمى «Kollege» شخصاً Auto، ثم Albrecht.  
إنجليزي 1: الشركة قُطعت إلى ASK «Hale Design Ltd» بدل «Thornton & Hale Design Ltd» (Thornton حُمي شخصاً من التحية، فالجملة الكاملة تختفي من الحمولة بعد الإجابة لكن العرض كان ناقصاً).  
إنجليزي 2: بعد إجابة السؤال الوحيد (الشركة) بقيت في الحمولة: `James`، `12/04/1985`، `NGE-20417`، `QQ 12 34 56 C`، `4111 1111 1111 1111`، `7 Elm Terrace`. «Mr Whitaker» حمى اللقب وحده. الزوج «James Whitaker» كسلسلة متصلة اختفى لأن Whitaker رُمز؛ الاسم الأول بقي ثلاث مرات.

---

## طرق الإفلات (pack فقط، بلا خزنة) — `logs/b5-escapes.txt`

| المسار | النتيجة |
|---|---|
| اسم مكسور بسطر: `Thomas\nMüller` | ASK على الكلمتين (يُحمى إن أُجيب) |
| لقب مكسور بشرطة صفحة: `Yn-\nnerman` | لا شيء — بلا تعليم |
| `Sven\nNelander` بلا تعليم | لا شيء |
| ZWSP داخل Markus بعد Herr | لا شيء — اللقب Weber أيضاً لم يُؤخذ |
| ZWJ بين Markus وWeber | لا شيء |
| ZWNJ بين Thomas وMüller | لا شيء |
| NFD: `Mu`+◌̈+`ller` بعد Herr | Thomas Auto؛ Müller فات |
| NFC Müller بعد Herr | الاثنان Auto |
| ligature `ﬁscher` | Thomas Auto؛ ﬁscher فات |
| fullwidth Ｔｈｏｍａｓ بعد Herr | Auto (salutation لا تحتاج المعجم) |
| ALL CAPS `THOMAS MÜLLER` في جملة | ASK (المعجم case-blind) |
| ALL CAPS بعد Herr | Auto |
| `CRISTINA LEIFLAND` بلا تعليم sv | لا شيء |
| نقطة في آخر السطر `Müller.` | ASK (bare يقطع النقطة) |
| `Müller,person` بلا مسافة | لا شيء — الزوج كله يسقط |
| `Müller/Vertrieb` | ASK على «Müller/Vertrieb» (يبتلع القسم) |
| `Müller—Vertrieb` | ASK على الكلمة كلها مع الشرطة |
| `(Thomas Müller)` | ASK |
| `Ms.Thornton` ملصوق | لا شيء — `Ms Thornton` Auto |
| PAN 4111… / 5500… | لا شيء |
| `National Insurance number: QQ 12 34 56 C` | لا شيء رغم صف en-34 Auto |
| `Date of birth: 12/04/1985` | لا شيء |
| `Employee number: NGE-20417` | لا شيء |
| `bankgiro 5050-1055` | لا شيء |
| `Momsregistreringsnummer SE556…` | لا شيء |
| هوية عربية 10 أرقام | لا شيء |
| جوال 0501234567 تحت ar | ASK (شكل محلي) |
| `Yn-\nnerman` بعد تعليم Always | AUTO القيمة المكسورة كوحدة |
| `LEIFLAND` بعد تعليم Leifland | AUTO |

تعليم الخزنة يجد المكسور بشرطة والقبعات. الإفلات أعلاه هو ما يفعله الماسح وحده.

---

## العيوب

### B5-1 · خطير — عرض صفري يُعمي التحية عن الشخص كله
- فتحت `Sehr geehrter Herr Mar<ZWSP>kus Weber,` بحزمة de بلا خزنة.
- التحية Auto تحمي الاسم الذي يلي Herr، كما تحمي Markus Weber في الخطاب الذهبي.
- لا finding. ZWJ وZWNJ بين الاسمين كذلك. حرف بعرض صفر في الاسم الأول يُسقط اللقب أيضاً لأن المشي يتوقف عند أول كلمة لا تُشبه اسماً (`name_shaped` يرفض غير الحروف).

### B5-2 · خطير — تركيب يونيكود NFD
- كتبت Müller بعد Herr بصيغة NFD (`u` + combining diaeresis، 8 بايت) مقابل NFC (7 بايت).
- الاثنان قيمة واحدة في G3/`text::nfc` للخزنة ومراجعة التسريب.
- Thomas Auto؛ Müller NFD لا يُحمى. `name_shaped` يطلب `char::is_alphabetic` على كل حرف، وعلامة الجمع ليست حرفاً. PDF/قارئ قد يُخرج NFD.

### B5-3 · خطير — رقم بطاقة دفع يغادر بعد أن يجيب الإنسان
- مسحت «إنجليزي 2» وأجبت السؤال الوحيد، ثم `Please charge 4111 1111 1111 1111`.
- `languages.rs` يقول إن القواعد العامة تشمل «card». شكل Luhn عالمي كـIBAN.
- لا Kind ولا قاعدة. PAN يبقى في الحمولة. التعليق يعدّ بالكشف؛ الكود لا يملك كاشف بطاقة.

### B5-4 · خطير — صف NI الإنجليزي موجود والمصادِق يرفض القيمة
- `National Insurance number: QQ 12 34 56 C` تحت pack en.
- الصف `en-34` «national insurance number» Auto / `Validator::Number` كُتب أصلاً لهذا الشكل.
- لا finding. `is_numberish` يرفض الحروف. الصف يطابق التسمية ثم يسقط القيمة في صمت — أضعف من غياب الصف: الشاشة لا تسأل. وعد Auto وسقط بلا سؤال.

### B5-5 · خطير — نصف اسم: James يبقى، Whitaker يُحمى
- «إنجليزي 2»: `Name: James Whitaker` و`Mr Whitaker` و`Re: … James Whitaker`.
- بعد الإجابة لا يبقى لقب مكشوف كزوج؛ الاسم الكامل لا يُترك نصفه (038-I).
- «Mr Whitaker» Auto على اللقب وحده. لا صف `Name:` في en يأخذ الزوج. `James` يبقى في الحمولة.

### B5-6 · خطير — تاريخ ميلاد ورقم موظف مكتوبان بتسمية إنجليزية ولا صف لهما
- `Date of birth: 12/04/1985` و`Employee number: NGE-20417` في جلسة en.
- الألمانية تحمي `Geburtsdatum:` و`Personal-Nr.:` Auto (`de-28` · `de-32`). حزمة en تملك صفوف NI/SSN ولا تملك تاريخ الميلاد ولا رقم الموظف.
- لا سؤال ولا علامة. القيمة تغادر مع من أجاب كل ما سُئل عنه.

### B5-7 · ملاحظة — إفلات الشكل: شرطة سطر، لصق ترقيم، ligature
- قست `Yn-\nnerman` بلا تعليم، `Ms.Thornton`، `Müller,person`، `ﬁscher`.
- المكسور بشرطة يُوجد إن عُلّم؛ الترقيم الطرفي يُقطع بـ`bare`؛ الزوج المعجمي يقرأ عبر سطر.
- بلا تعليم: لا شيء على Yn-/nerman. `Ms.Thornton` كلمة واحدة. الفاصلة بلا مسافة تُسقط الزوج كلّه. ligature لا تطابق fischer. `/` و`—` يجعلان «Müller/Vertrieb» قيمة واحدة إن أُكّدت.

### B5-8 · ملاحظة — المعجم السويدي أضيق من الخطاب الذهبي السويدي
- Brev_Lindqvist تحت sv، بعد إجابة كل سؤال.
- الأسماء بعد تحية/لقب/توقيع تُحمى كما في الألماني.
- Tobias Reinholdsson، Sofia Brandt، Yusuf Demir بقيت. Bankgiro وMoms ولوحة `ABC 123` ليست أنواعاً.

### B5-9 · ملاحظة — العربية بلا حزمة (قاعدة 56) والقواعد العامة لا ترى الأسماء ولا الهوية الوطنية
- Risala + عربي 1 و2 تحت `ar` و`de`.
- IBAN/BIC/بريد/+هواتف تُحمى بلا لغة. القاعدة 56 توقف العربية حتى يقول المالك.
- 7+3+4 أسماء، هويتان 10 أرقام، أرقام ضريبية، لوحة — صفر findings. دين معلن، لا يزال ديناً على الوثائق الذهبية.

### B5-10 · ملاحظة — إيجابيات كاذبة وقطع شركة
- Vertrag: التوقيع Auto على «Abteilung» و«Vertragswesen».
- ألماني 2: «Herr Kollege Albrecht» Auto على «Kollege».
- إنجليزي 1: ASK «Hale Design Ltd» لا «Thornton & Hale Design Ltd».
- يجب ألا يُحمى قسمٌ أو كلمة «Kollege» كشخص، ولا تُقطع شركة من عند &.

---

## قائمة التغطية

- [x] الوثائق الذهبية الخمس في parity-corpus (قراءة فقط)
- [x] نصوص التجربة (txt؛ نُسخت إلى fixtures ثم `import_text`)
- [x] بالأنواع: Person/Company/Email/Phone/Iban/Bic/TaxId/CustomerNo/Address/Birthdate/IdCard/Vehicle/EmployeeNo/SocialInsuranceNo/Contract
- [x] سطر مكسور في الاسم
- [x] حروف بعرض صفري (ZWSP/ZWJ/ZWNJ)
- [x] NFC/NFD وligature وfullwidth
- [x] ALL CAPS بلا خزنة ومعها
- [x] أسماء ملتصقة بترقيم (نقطة، فاصلة، شرطة، أقواس، Ms.)
- [x] بطاقة دفع، NI بريطاني، DOB إنجليزي، رقم موظف، bankgiro، هوية عربية

**الدرجات هنا:** مانع 0 · خطير 6 · ملاحظة 4

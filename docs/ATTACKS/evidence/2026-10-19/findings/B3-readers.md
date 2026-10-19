# B3 · قارئ الملفات

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**الختم:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**الأداة:** `z_core --example check_document` (release، `CARGO_TARGET_DIR=…/target-b3`) + `harnesses/probes` `b3` (`import_document`)  
**السجلات:** `/home/monopeaks/z-attack-2b4fad9-evidence/logs/B3-time.txt` · `B3-check.txt` · `B3-import.txt` · `B3-xxe.txt`  
**التجهيزات:** `/home/monopeaks/z-attack-2b4fad9-evidence/fixtures/`  
**الذاكرة:** `/usr/bin/time -f maxrss_kb=%M` (كيلوبايت، ذروة RSS للعملية) — عملية واحدة لكل ملف.

لم تُفتح شبكة إلا مستمع محلي `127.0.0.1:17931` لعدّ XXE. لم يُمسّ `~/.local/share/zprivacy` (`vault.zv` `sha256 760da262…` قبل وبعد، نفس `mtime`). لم يُصلَح شيء في `/home/monopeaks/z-attack-2b4fad9` ولا في `mono-privacy`. خزنة القياس تحت `scratch/b3` (`XDG_DATA_HOME` + `set_data_dir`). الـharness أُشير مسار بياناته فقط (من `z-attack-final` إلى `scratch/b3`)؛ العقد لم يتغيّر.

حدود هذا البناء (`z_core/src/documents/mod.rs`): ملف 25 MiB · نص 4 MiB · مدخل zip 8 MiB · نسبة 200× · أجزاء zip 512 · مجرى PDF 8 MiB · سقف تراكمي `max(16 MiB, حجم_الملف × 32)`. كل مجرى Flate يمرّ بيد واحدة: `inflate_bounded` يوقف الفك **أثناء** التضخم عند أصغر السقوف الثلاثة، وما قُطع يُرفض باسمه.

---

## ما أُغلق من الجولة السابقة (commit `84832a0`) وما زال مغلقاً على `2b4fad9`

| السابق | على `84832a0` | على `2b4fad9` |
|---|---|---|
| م2 مانع: مجرى 9 MiB يُقطَع ويُستورَد | `CompressionBomb { ratio: 201 }` | نفسه. لا استيراد. لا `START_MARKER_B3`/`END_MARKER_B3`. لا `100% readable`. RSS 5688 KiB. |
| م3 مانع: قنبلة 946× تُسمّى مسحاً | `CompressionBomb { ratio: 201 }` | نفسه — ليست `ScannedPdfNoTextLayer`. المسح الحقيقي (3 صفحات) بقي باسمه. RSS 3540 KiB. |
| خ4 خطير: ObjStm 49 KiB → 75 MiB RSS | `CompressionBomb { ratio: 201 }` RSS ≈ 4.7 MiB | نفسه على «an object stream». RSS 4868 KiB — ليست ~75 MiB. |
| خ5 خطير: الشاشة «could not be opened safely» | كل حدّ له جملة برقم | نفسه. `DocumentTooLarge` / `TextTooLarge` / `CompressionBomb` / `TooManyParts` / `ScannedPdfNoTextLayer` تُسمّى بأرقامها. |
| ن16 ملاحظة: `mib: 25` ضد `limit_mib: 25` | `mib: 26, limit_mib: 25` | نفسه. `eq25=false`. التفصيل «26214401 bytes is past the 25 MiB limit». الشاشة: «about 26 MiB … up to 25 MiB». |

قطع المجرى عند 8 MiB **من دون** أن تربط النسبة 200× أُعيد قياسه بـ`pdf_stream_over_8mib_low_ratio.pdf` (8.06 MiB، نسبة 1.000): `TextTooLarge { limit_mib: 8 }`، التفصيل «a page's content in this PDF unpacks to more than 8 MiB»، لا علامات في نصّ مستورد. RSS 36436 KiB.

السقف التراكمي 16 MiB أُعيد قياسه بـ`pdf_nine_pages_cumul.pdf` (262428 بايت، تسعة مجاري): `CompressionBomb { ratio: 64 }`، التفصيل «the parts of this PDF unpack to more than 17 MiB in all — 64× the file's own size, past the 16 MiB a file of 256 KiB may ask for». RSS 10472 KiB. الشاشة ما زالت تقول «جزء» — انظر ب٣-١.

---

## العيوب المتبقية

### B3-1 · ملاحظة — جملة الشاشة للقنبلة التراكمية تقول «جزء» والـcore يقول «المجموع»

1. **ماذا فعلت:** استوردت `pdf_nine_pages_cumul.pdf` (262428 بايت، تسعة مجاري محتوى) بـ`check_document` و`import_document`.
2. **ماذا كان يجب:** ما تراه الشاشة يحمل السبب نفسه: أن **مجموع** ما فُكّ تجاوز سقف الوثيقة (16 MiB)، لا أن «جزءاً» واحداً تضخّم 64×. الرقم 64 هو نسبة الملف كلّه (17 MiB / 256 KiB)، لا نسبة مجرى.
3. **ماذا حدث:** الـcore رفض: `CompressionBomb { ratio: 64 }` والتفصيل يسمّي «the parts … in all» و«past the 16 MiB». `messages.dart` فرع `Refusal_CompressionBomb` جملة واحدة لكل أشكال القنبلة: «A part of this file unpacks to more than $ratio times the space it takes up.» (الألمانية: «Ein Teil dieser Datei…»). الرفض صحيح ومسمّى؛ الجملة تسقط «in all» ورقم 16 MiB. ليست كذبة المسح السابقة.

**الدرجة:** ملاحظة (ن5، باقية)

**الدليل:** `logs/B3-import.txt` `pdf_nine_pages_cumul.pdf` · `apps/flutter_app/lib/core/messages.dart` `_document` / `Refusal_CompressionBomb` · `l10n/app_en.arb` `refusalCompressionBomb`.

---

### B3-2 · ملاحظة — تفصيل zip لمدخل 8 MiB+1 ما زال يُقطع للأسفل

1. **ماذا فعلت:** `docx_entry_over_8mib_store.docx` و`docx_entry_over_8mib.docx` (غير مضغوط 8388609 بايت = 8 MiB+1).
2. **ماذا كان يجب:** الرقم الذي يقول «تجاوز الحدّ» لا يساوي الحدّ (نفس اتجاه ن16 على الملف 25 MiB: `div_ceil` لا القسمة نحو الصفر).
3. **ماذا حدث:** الرفض `TextTooLarge { limit_mib: 8 }` صحيح والشاشة تقول «more than 8 MiB». تفصيل الـcore: «would be 8 MiB once unpacked, past the 8 MiB limit» لأن `uncompressed / 1024 / 1024` يقطع للأسفل (8388609 → 8). الحقل الذي ترسمه الشاشة لا يحمل الحجم المقاس، فالكذبة لا تصل الزجاج؛ تبقى في التفصيل الذي يطبعه `check_document`. PDF عند نفس الاتجاه يستخدم `div_ceil`؛ zip لم يُلحق.

**الدرجة:** ملاحظة (ن6، باقية)

**الدليل:** `logs/B3-check.txt` · `z_core/src/documents/zip.rs` حوالي السطر 105.

---

## ما نجح

RSS من `/usr/bin/time -f maxrss_kb=%M` على `check_document` release إلا حيث يُذكر خلاف ذلك.

| الهجوم | النتيجة | RSS KiB |
|---|---|---:|
| PDF Flate فوق 8 MiB (`pdf_flate_over_8mib.pdf`، 9 MiB مع `START_MARKER_B3`/`END_MARKER_B3`) | `CompressionBomb 201` — لا استيراد، لا علامة، لا 100% readable | 5688 |
| PDF Flate نسبة 946× (`pdf_flate_ratio_200.pdf`) | `CompressionBomb 201` — ليست مسحاً | 3540 |
| PDF ObjStm 12×4 MiB في 49 KiB | `CompressionBomb 201` على object stream | 4868 |
| PDF مجريان ~8 MiB (`pdf_flate_cumul_16mib.pdf`) | `CompressionBomb 201` (النسبة تربط أولاً) | 5640 |
| PDF مجرى 8.06 MiB بنسبة 1.0 | `TextTooLarge 8` — القطع رفض لا قراءة | 36436 |
| PDF 9 صفحات × 2 MiB، نسبة 72 | `CompressionBomb 64` سقف الوثيقة 16 MiB | 10472 |
| PDF ممسوح بلا طبقة نص (3 صفحات) | `ScannedPdfNoTextLayer { pages: 3 }` — يقول ذلك ولا يدّعي قراءة | 3612 |
| PDF عند 25 MiB تماماً (26214400) | يُقبل (صفحة Hello، 100% readable) | 58244 |
| PDF فوق 25 MiB (بايت واحد، 26214401) | `DocumentTooLarge { mib: 26, limit_mib: 25 }` `eq25=false` | 53840 |
| TXT عند 4 MiB / فوق 4 / فوق 25 | قبول / `TextTooLarge 4` / `DocumentTooLarge 26` | 31572 / 11020 / 53828 |
| DOCX zip bomb، الترويسة 986× | `CompressionBomb { ratio: 986 }` قبل الفك | 3104 |
| DOCX ترويسة كاذبة ثم فك 934× | `CompressionBomb { ratio: 934 }` بعد القياس | 7232 |
| DOCX مدخل 8 MiB store | يُقبل؛ النص من `w:t` فقط («AT8MIB») | 27556 |
| DOCX مدخل 8 MiB+1 store | `TextTooLarge { limit_mib: 8 }` | 18928 |
| XXE `file:///etc/passwd` و`http://127.0.0.1:17931/xxe-probe` | `MalformedDocument`: unknown entity `&xxe;` — **صفر** طلبات على المستمع | 3128 / 3216 |
| Billion laughs | `unknown entity &d;` — الـDTD لا تُعرَّف | 3076 |
| علاقات خارجية `TargetMode=External` | تُستخرج الكلمتان من `w:t` فقط («external-ref» / «click»)؛ لا جلب | 7472 |
| ماكرو `word/vbaProject.bin` | يُقرأ `document.xml` فقط؛ «macro-host Thomas» | 7160 |
| 521 جزء zip | `TooManyParts { parts: 521, limit: 512 }` | 3392 |
| XRef مضغوط (`pdf_xref_flate.pdf`) | هذا القارئ يمسح الكائنات؛ الملف يُقرأ (Hello). ليست قنبلة هنا | 7416 |

`check_document` و`import_document` أعادا الأسماء نفسها على القنابل. الشاشة (`messages.dart` / `app_en.arb`) تسمّي الحدّ: 26/25، 8، 201، 521/512، 3 صفحات صور. الزجاج للقنبلة التراكمية يسقط «in all» كما فوق.

---

## قائمة التغطية

- [x] PDF: قنابل V1-J (XRef، ObjStm، Flate بنسبة 200، حدود 8 و16 MiB) على **هذا** القارئ، مع قياس الذاكرة
- [x] قطع المجرى عند 8 MiB بنسبة منخفضة (لا يُمرَّر النصف)
- [x] سقف الوثيقة التراكمي 16 MiB على ملف صغير (تسعة مجاري)
- [x] PDF بلا طبقة نص: يقول ذلك ولا يدّعي قراءة
- [x] DOCX: zip bomb، مراجع خارجية، XXE (مستمع محلي بلا ضربة)، ماكرو — لا شبكة، لا انفجار ذاكرة
- [x] ملف عند حدّ القبول وملف فوقه بقليل: الحدّ يُطبَّق **ويُقال** على الزجاج بأرقامه
- [x] TXT عند 4 MiB / فوق 4 / فوق 25 MiB

**العدّ:** مانع 0 · خطير 0 · ملاحظة 2

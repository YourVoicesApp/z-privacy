# B3 · قارئ الملفات

**Commit:** `84832a015f74952556f5d512187a8d5f99673d9d`  
**الختم:** `z_core 0.1.0 · 2026-10-17 · 84832a0`  
**الأداة:** `z_core --example check_document` (release، النسخة تحت `z-attack-final/src`) + `fixtures/probes` `b3`  
**السجلات:** `/home/monopeaks/z-attack-final/logs/B3-time.txt` · `B3-check.txt` · `B3-xxe.txt`  
**التجهيزات:** `/home/monopeaks/z-attack-final/fixtures/`  
**الذاكرة:** `/usr/bin/time -f maxrss_kb=%M` (كيلوبايت، ذروة RSS للعملية)

لم تُفتح شبكة. لم يُمسّ `~/.local/share/zprivacy` (`sha256 1931180a…` كما قبل التشغيل). لم يُصلَح شيء. خزنة القياس تحت `fixtures/tmp-data-b3` و`fixtures/xdg-check`.

حدود هذا البناء (`z_core/src/documents/mod.rs`): ملف 25 MiB · نص 4 MiB · مدخل zip 8 MiB · نسبة 200× · أجزاء zip 512 · مجرى PDF 8 MiB · سقف تراكمي `max(16 MiB, حجم_الملف × 32)`. كل مجرى Flate يمرّ بيد واحدة: `inflate_bounded` يوقف الفك **أثناء** التضخم عند أصغر السقوف الثلاثة، وما قُطع يُرفض باسمه.

---

## ما أُغلق من الجولة السابقة (commit `5f5bef1`)

| السابق | على `5f5bef1` | على `84832a0` |
|---|---|---|
| B3-1 مانع: مجرى 9 MiB يُقطَع ويُستورَد | `OK` · `START_MARKER` بلا ذيل · «100% readable» | `CompressionBomb { ratio: 201 }` — لا استيراد. RSS 5404 KiB. |
| B3-2 مانع: قنبلة 946× تُسمّى مسحاً | `ScannedPdfNoTextLayer` | `CompressionBomb { ratio: 201 }` — التفصيل «a page's content unpacks to more than 201×». الشاشة لا تقول صورة. RSS 3572 KiB. |
| B3-3 خطير: ObjStm 49 KiB → 75 MiB RSS | `OK` Hello · `maxrss_kb=77204` | `CompressionBomb { ratio: 201 }` على «an object stream». RSS 4696 KiB. |
| B3-4 خطير: الشاشة «could not be opened safely» | `_ =>` في `messages.dart` | كل حدّ له جملة برقم. `DocumentTooLarge` / `TextTooLarge` / `CompressionBomb` / `TooManyParts` تُسمّى. |
| B3-5 ملاحظة: `mib: 25` ضد `limit_mib: 25` | قسم للأسفل | `DocumentTooLarge { mib: 26, limit_mib: 25 }` و«26214401 bytes is past the 25 MiB limit». الشاشة: «about 26 MiB … up to 25 MiB». |

قطع المجرى عند 8 MiB **من دون** أن تربط النسبة 200× أُعيد قياسه بتجهيزة مستقلة `pdf_stream_over_8mib_low_ratio.pdf` (8.06 MiB غير قابلة للضغط، نسبة 1.000): `TextTooLarge { limit_mib: 8 }`، التفصيل «a page's content in this PDF unpacks to more than 8 MiB»، لا `START_MARKER` ولا `END_MARKER` في نصّ مستورد. RSS 36248 KiB (حجم الملف ~8.1 MiB + `take(8 MiB+1)` ثم الرفض).

السقف التراكمي 16 MiB أُعيد قياسه بـ`pdf_nine_pages_cumul.pdf` (9 صفحات × ~2 MiB، نسبة المجرى 72× تحت 200): `CompressionBomb { ratio: 64 }`، التفصيل «the parts of this PDF unpack to more than 17 MiB in all — 64× the file's own size, past the 16 MiB a file of 256 KiB may ask for». RSS 9916 KiB. القنابل القديمة عالية الضغط تموت عند 200× للمجرى قبل أن تبلغ المجموع؛ هذا الشكل هو الذي يلامس سقف الوثيقة.

---

## العيوب المتبقية

### B3-1 · ملاحظة — جملة الشاشة للقنبلة التراكمية تقول «جزء» والـcore يقول «المجموع»

1. **ماذا فعلت:** استوردت `pdf_nine_pages_cumul.pdf` (262428 بايت، تسعة مجاري محتوى). الـcore رفض: `CompressionBomb { ratio: 64 }` والتفصيل يسمّي «the parts … in all» و«past the 16 MiB».
2. **ماذا كان يجب:** ما تراه الشاشة يحمل السبب نفسه: أن **مجموع** ما فُكّ تجاوز سقف الوثيقة، لا أن «جزءاً» واحداً تضخّم 64×. الرقم 64 هو نسبة الملف كلّه (17 MiB / 256 KiB)، لا نسبة مجرى.
3. **ماذا حدث:** `messages.dart` فرع `Refusal_CompressionBomb` جملة واحدة لكل أشكال القنبلة: «A part of this file unpacks to more than $ratio times the space it takes up.» الرفض صحيح ومسمّى؛ الجملة تسقط «in all» ورقم 16 MiB. ليست كذبة المسح السابقة.

**الدليل:** `logs/B3-time.txt` `pdf_nine_pages_cumul.pdf` · `apps/flutter_app/lib/core/messages.dart` `_document` / `Refusal_CompressionBomb`.

---

### B3-2 · ملاحظة — تفصيل zip لمدخل 8 MiB+1 ما زال يُقطع للأسفل

1. **ماذا فعلت:** `docx_entry_over_8mib_store.docx` و`docx_entry_over_8mib.docx` (غير مضغوط 8388609 بايت).
2. **ماذا كان يجب:** الرقم الذي يقول «تجاوز الحدّ» لا يساوي الحدّ (نفس اتجاه ن16 على الملف 25 MiB).
3. **ماذا حدث:** الرفض `TextTooLarge { limit_mib: 8 }` صحيح والشاشة تقول «more than 8 MiB». تفصيل الـcore: «would be 8 MiB once unpacked, past the 8 MiB limit» لأن `uncompressed / 1024 / 1024` يقطع للأسفل. الحقل الذي ترسمه الشاشة لا يحمل الحجم المقاس، فالكذبة لا تصل الزجاج؛ تبقى في التفصيل الذي يطبعه `check_document`.

**الدليل:** `logs/B3-time.txt` · `documents/zip.rs` حوالي السطر 105.

---

## ما نجح

| الهجوم | النتيجة | RSS KiB |
|---|---|---:|
| PDF Flate فوق 8 MiB (`pdf_flate_over_8mib.pdf`) | `CompressionBomb 201` — لا استيراد، لا علامة نهاية | 5404 |
| PDF Flate نسبة 946× | `CompressionBomb 201` — ليست مسحاً | 3572 |
| PDF ObjStm 12×4 MiB في 49 KiB | `CompressionBomb 201` على object stream | 4696 |
| PDF مجريان ~8 MiB (`pdf_flate_cumul_16mib.pdf`) | `CompressionBomb 201` (النسبة تربط أولاً) | 5548 |
| PDF مجرى 8.06 MiB بنسبة 1.0 | `TextTooLarge 8` — القطع رفض لا قراءة | 36248 |
| PDF 9 صفحات × 2 MiB، نسبة 72 | `CompressionBomb 64` سقف الوثيقة 16 MiB | 9916 |
| PDF ممسوح بلا طبقة نص (3 صفحات) | `ScannedPdfNoTextLayer { pages: 3 }` — يقول ذلك ولا يدّعي قراءة | 3348 |
| PDF عند 25 MiB تماماً | يُقبل (صفحة Hello) | 58340 |
| PDF فوق 25 MiB (بايت واحد) | `DocumentTooLarge { mib: 26, limit_mib: 25 }` | 54232 |
| TXT عند 4 MiB / فوق 4 / فوق 25 | قبول / `TextTooLarge 4` / `DocumentTooLarge 26` | — |
| DOCX zip bomb، الترويسة 986× | `CompressionBomb { ratio: 986 }` قبل الفك | 3336 |
| DOCX ترويسة كاذبة ثم فك 934× | `CompressionBomb { ratio: 934 }` بعد القياس | 7564 |
| DOCX مدخل 8 MiB store | يُقبل؛ النص من `w:t` فقط («AT8MIB») | 27632 |
| DOCX مدخل 8 MiB+1 store | `TextTooLarge { limit_mib: 8 }` | 19416 |
| XXE `file:///etc/passwd` و`http://127.0.0.1:17931/xxe-probe` | `MalformedDocument`: unknown entity `&xxe;` — **صفر** طلبات على المستمع | 3312 |
| Billion laughs | `unknown entity &d;` — الـDTD لا تُعرَّف | 3388 |
| علاقات خارجية `TargetMode=External` | تُستخرج الكلمتان من `w:t` فقط؛ لا جلب | 7364 |
| ماكرو `word/vbaProject.bin` | يُقرأ `document.xml` فقط؛ «macro-host Thomas» | 7008 |
| 521 جزء zip | `TooManyParts { parts: 521, limit: 512 }` | 3060 |
| XRef مضغوط | هذا القارئ يمسح الكائنات؛ الملف يُقرأ (Hello). ليست قنبلة هنا | 7384 |

`check_document` (release) أعاد الأسماء نفسها على القنابل. الشاشة (`messages.dart`) تسمّي الحدّ: 26/25، 8، 201، 521/512، 3 صفحات صور.

---

## قائمة التغطية

- [x] PDF: قنابل V1-J (XRef، ObjStm، Flate بنسبة 200، حدود 8 و16 MiB) على **هذا** القارئ، مع قياس الذاكرة
- [x] قطع المجرى عند 8 MiB بنسبة منخفضة (لا يُمرَّر النصف)
- [x] سقف الوثيقة التراكمي 16 MiB على ملف صغير (تسعة مجاري)
- [x] PDF بلا طبقة نص: يقول ذلك ولا يدّعي قراءة
- [x] DOCX: zip bomb، مراجع خارجية، XXE (مستمع محلي بلا ضربة)، ماكرو — لا شبكة، لا انفجار ذاكرة
- [x] ملف عند حدّ القبول وملف فوقه بقليل: الحدّ يُطبَّق **ويُقال** على الزجاج بأرقامه

**العدّ:** مانع 0 · خطير 0 · ملاحظة 2

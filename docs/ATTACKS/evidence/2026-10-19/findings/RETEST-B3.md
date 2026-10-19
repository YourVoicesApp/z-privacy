# إعادة قياس ب٣ — القرّاء — `2b4fad9`

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**الختم:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**المصدر:** `/home/monopeaks/z-attack-2b4fad9` (detached، بلا تعديل)  
**لم يُمس:** `~/.local/share/zprivacy` · `~/mono-privacy` · وثائق المالك.

الأدوات: `cargo run -p z_core --example check_document --release` تحت `CARGO_TARGET_DIR=/home/monopeaks/z-attack-2b4fad9-evidence/target-b3` · `harnesses/probes --bin b3` (`import_document` + جملة الزجاج من `messages.dart`) · `/usr/bin/time -f maxrss_kb=%M` · مستمع TCP `127.0.0.1:17931`.

السجلات: `logs/B3-check.txt` · `B3-import.txt` · `B3-time.txt` · `B3-xxe.txt` · `B3-vault-before.txt` / `B3-vault-after.txt`.

`XDG_DATA_HOME=/home/monopeaks/z-attack-2b4fad9-evidence/scratch/b3/xdg`. الـprobe يكتب تحت `scratch/b3/tmp-data-b3`.

---

## أوضاع العيوب السابقة (م2 م3 خ4 خ5 ن16 ن5 ن6)

| الرمز | الدرجة الأصلية | على `84832a0` | على `2b4fad9` |
|---|---|---|---|
| م2 PDF Flate يُقطَع ويُستورَد 100% مقروءاً | مانع | FIXED | **FIXED** |
| م3 قنبلة Flate تُسمَّى مسحاً | مانع | FIXED | **FIXED** |
| خ4 ObjStm ~75 MiB RSS | خطير | FIXED | **FIXED** |
| خ5 جملة الحجم عامة | خطير | FIXED | **FIXED** |
| ن16 تقريب `mib == limit_mib` عند 25 MiB+1 | ملاحظة | FIXED | **FIXED** |
| ن5 جملة القنبلة التراكمية على الشاشة تقول «جزء» | ملاحظة | OPEN | **OPEN** — ملاحظة |
| ن6 تفصيل zip لمدخل 8 MiB+1 يُقطع للأسفل | ملاحظة | OPEN | **OPEN** — ملاحظة |

**العدّ على هذا البناء:** مانع 0 · خطير 0 · ملاحظة 2.

---

### م2 · PDF Flate فوق 8 MiB يُقطَع ويُستورَد

**FIXED**

1. **ماذا فعلت:** `check_document` ثم `import_document` على `fixtures/pdf_flate_over_8mib.pdf` (9684 بايت؛ المولِّد يضع `START_MARKER_B3` في رأس مجرى 9 MiB و`END_MARKER_B3` بعد 8 MiB).
2. **ماذا كان يجب:** رفض باسمه. لا نصف مجرى يُعرض «100% readable».
3. **ماذا حدث:** `refused: CompressionBomb { ratio: 201 }` — «a page's content unpacks to more than 201× the bytes it is written in». الاستيراد لم ينجح. لا `pages=` ولا `100% readable` ولا `start=true`/`end=true`. RSS `maxrss_kb=5688`.

---

### م3 · قنبلة Flate بنسبة ~946 تُرفَض بوصفها صورة ممسوحة

**FIXED**

1. **ماذا فعلت:** نفس الأداتين على `pdf_flate_ratio_200.pdf` (262144 صفراً → 277 بايت مضغوط، نسبة 946). شاهد: `pdf_scanned_no_text.pdf` (3 صفحات صور).
2. **ماذا كان يجب:** `CompressionBomb` للقنبلة؛ `ScannedPdfNoTextLayer` للمسح الحقيقي.
3. **ماذا حدث:** القنبلة: `CompressionBomb { ratio: 201 }` — ليست مسحاً. المسح: `ScannedPdfNoTextLayer { pages: 3 }`، الزجاج: «This PDF is 3 pages of pictures with no text in them, so nothing could be read.» الاسمان ما زالا منفصلين.

---

### خ4 · ObjStm 49 KiB → ~75 MiB RSS

**FIXED**

1. **ماذا فعلت:** `pdf_objstm_bomb.pdf` (50767 بايت) مع `/usr/bin/time -f maxrss_kb=%M`.
2. **ماذا كان يجب:** رفض قبل أن يبلغ RSS عشرات الميبيبايت.
3. **ماذا حدث:** `CompressionBomb { ratio: 201 }` على «an object stream». `maxrss_kb=4868` (`import` 4660). ليست ~75 MiB.

---

### خ5 · الشاشة «could not be opened safely»

**FIXED**

1. **ماذا فعلت:** نسخت جملة الزجاج من فروع `messages.dart` `_document` (كما في `b3.rs` / `app_en.arb`) على كل رفض مسمّى في هذه الجولة.
2. **ماذا كان يجب:** كل حدّ بجملة رقمه، بلا `_ =>` عام.
3. **ماذا حدث:**  
   - `DocumentTooLarge { 26, 25 }` → «This file is about 26 MiB, and Z Privacy opens documents up to 25 MiB.»  
   - `TextTooLarge { 8 }` → «Unpacked, a part of this file is more than 8 MiB — … none of it was imported.»  
   - `CompressionBomb { 201 }` → جملة النسبة.  
   - `TooManyParts { 521, 512 }` → «lists 521 parts … opens up to 512.»  
   - `ScannedPdfNoTextLayer { 3 }` → جملة الصور.  
   لا «could not be opened safely». (ن5 تخصّ كلمة «part» على القنبلة التراكمية، لا سقوط الاسم.)

---

### ن16 · ملف 25 MiB+1 يُبلَّغ `mib: 25` ضد `limit_mib: 25`

**FIXED**

1. **ماذا فعلت:** `pdf_over_25mib.pdf` و`txt_over_25mib.txt` (كلاهما 26214401 بايت). شاهد القبول: `pdf_at_25mib.pdf` (26214400).
2. **ماذا كان يجب:** الرقم المقاس لا يساوي الحدّ. الملف عند الحدّ يُقبل.
3. **ماذا حدث:** `DocumentTooLarge { mib: 26, limit_mib: 25 }`، `eq25=false`، التفصيل يحمل `26214401 bytes is past the 25 MiB limit for one document (26214400 bytes)`. الزجاج: «about 26 MiB … up to 25 MiB». `pdf_at_25mib.pdf`: OK، Hello، 1 صفحة.

---

### ن5 · جملة القنبلة التراكمية على الشاشة تقول «جزء»

**OPEN — ملاحظة**

1. **ماذا فعلت:** `pdf_nine_pages_cumul.pdf` (262428 بايت).
2. **ماذا كان يجب:** الزجاج يقول إن **المجموع** تجاوز 16 MiB / 64× حجم الملف، لا أن جزءاً واحداً تضخّم 64×.
3. **ماذا حدث:** الـcore صادق: `CompressionBomb { ratio: 64 }`، «the parts of this PDF unpack to more than 17 MiB in all — 64× the file's own size, past the 16 MiB a file of 256 KiB may ask for». الزجاج (`refusalCompressionBomb`): «A part of this file unpacks to more than 64 times the space it takes up.» الألمانية: «Ein Teil dieser Datei…». الرفض صحيح؛ الجملة تسقط «in all» ورقم السقف.

---

### ن6 · تفصيل zip لمدخل 8 MiB+1 يُقطع للأسفل

**OPEN — ملاحظة**

1. **ماذا فعلت:** `docx_entry_over_8mib_store.docx` و`docx_entry_over_8mib.docx` (ترويسة `uncompressed=8388609`).
2. **ماذا كان يجب:** رقم «تجاوز الحدّ» لا يساوي الحدّ (`div_ceil`، كـن16).
3. **ماذا حدث:** الرفض `TextTooLarge { limit_mib: 8 }` صحيح. الزجاج: «more than 8 MiB» — صادق. التفصيل: «would be 8 MiB once unpacked, past the 8 MiB limit» لأن `zip.rs:105` `uncompressed / 1024 / 1024` (8388609 → 8). الكذبة لا تصل الزجاج.

مدخل 8 MiB تماماً (`docx_entry_at_8mib_store.docx`، 8388608 بايت store) ما زال يُقبل («AT8MIB»).

---

## قياس إضافي طُلب في هذه الجولة

| الملف | المطلوب | الحاصل |
|---|---|---|
| `pdf_flate_over_8mib.pdf` | CompressionBomb، لا استيراد، لا 100% readable | نعم |
| `pdf_flate_ratio_200.pdf` | CompressionBomb لا ScannedPdfNoTextLayer | نعم |
| `pdf_scanned_no_text.pdf` | ScannedPdfNoTextLayer | نعم، 3 صفحات |
| `pdf_objstm_bomb.pdf` | CompressionBomb، RSS ليست ~75 MiB | نعم، 4868 KiB |
| `pdf_over_25mib.pdf` | DocumentTooLarge، `mib != limit` | نعم، 26 ≠ 25 |
| `pdf_at_25mib.pdf` | قبول | نعم، Hello |
| `pdf_stream_over_8mib_low_ratio.pdf` | قطع 8 MiB بنسبة منخفضة = رفض | `TextTooLarge 8` |
| `pdf_nine_pages_cumul.pdf` | ملاحظة الشاشة مقابل الـcore | core «in all» / زجاج «A part» |
| `docx_xxe` / `docx_xxe_listener` | 0 اتصالات | 0 |
| zip bombs / مدخل 8 MiB+1 / 521 جزءاً / ماكرو | رفض أو قراءة `w:t` فقط | كما في `B3-readers.md` |
| `txt_over_4mib` / `txt_over_25mib` | TextTooLarge 4 / DocumentTooLarge 26 | نعم |

الخزنة الحقيقية: `sha256 760da2625e3b23e02a24509326af5c6c2c5e9257c25ff66359153c3b725bc203` قبل وبعد. `diff` الملفات والـmtimes: رأس التاريخ فقط.

# B2 · الخزنة وملفات الجلسات

**المهاجم:** مستقل، الهجوم النهائي القسم ب٢  
**الـcommit المقصود:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**الختم:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**المصدر المقروء:** `/home/monopeaks/z-attack-2b4fad9` (immutable)  
**الأداة:** `/home/monopeaks/z-attack-2b4fad9-evidence/harnesses/b2-harness` (path-dep على `z-attack-2b4fad9/z_core`) · `harnesses/argon_bench` (release)  
**CARGO_TARGET_DIR:** `/home/monopeaks/z-attack-2b4fad9-evidence/target-b2`  
**السجلات:** `logs/B2-harness.txt` · `logs/B2-block-search.txt` · `logs/B2-two-copies-test.txt` · `logs/B2-block-never-deleted.txt` · `logs/B2-model15-unit.txt` · `logs/argon-bench.log`  
**العمل:** `scratch/b2` — خزنات مصنوعة للهجوم فقط

لم يُمسّ `~/.local/share/zprivacy` (mtime `vault.zv` بقي `2026-10-19 06:17:31 +0200`). لم تُكتب شجرة `mono-privacy`. لا إصلاحات في المصدر.

الجهاز: AMD Ryzen 9 9950X3D 16-core / 32 خيط.

---

## العيوب

### 1. إن فشل فتح `writing.lock` سارت النسختان بلا قفل (ثقب الاحتياط باقٍ)

**الدرجة:** ملاحظة  
**الدليل:**
- `z_core/src/secure_file.rs:248-259` (`one_writer_at_a_time`: `open_the_lock(&path)?` ثم `file.lock().ok()?` — أي فشل يعيد `None`)
- `z_core/src/session.rs:817` (`with_core` يأخذ القفل إن وُجد ويتابع بدونه إن عاد `None`)
- التعليق في `secure_file.rs:238-242`: «A folder that refuses it leaves the old behaviour exactly as it was»
- `logs/B2-harness.txt` القسم 5c

- **ماذا فعلت:** بعد إنشاء خزنة جعلت `writing.lock` مجلداً (فتح الملف يفشل بـ EISDIR). ثم فتحت عمليتين تضيفان هوية في الوقت نفسه، ثماني تجارب.
- **وماذا كان يجب أن يحدث:** القانون الذي قاسه الهجوم السابق: لا تضيع كتابة بصمت. إن تعذّر القفل فالجملة الصادقة (`VaultChangedElsewhere`) أو الرفض — لا العودة إلى السباق القديم بلا خبر.
- **وماذا حدث:** ثماني تجارب، `silent_lost=0`. التجربة 0: الثانية رُفضت بـ `VaultChangedElsewhere` والقرص احتفظ بكاتب واحد. `ensure_disk_unchanged` (`vault/mod.rs:791-799`) وقف في هذه العيّنة. المسار العادي — ملف القفل موجود — قيس أربعين مرة بلا فقد (انظر التغطية). الثقب في الاحتياط باقٍ في المصدر: نسختان صادقتان لا تصنعان المجلد، لكن القياس على 8 تجارب لم يُعد إنتاج الفقد الصامت الذي سُجّل سابقاً (1/8 على 84832a0).

---

## قائمة التغطية

### 1. خزنة مقطوعة / بايت واحد مغيَّر / ملف فارغ
**النتيجة:** نجح. يُرفض، ولا يُمسح شيء. الملف الفارغ `Absent` ويُسمح بالإنشاء فوق صفر بايت.

| الحالة | الحالة (state) | الرفض | الجملة | البصمة بعد المحاولة |
|---|---|---|---|---|
| ملف فارغ (0B) | `Absent` | unlock: `PayloadRefused` · create: **نجح** | `this vault file holds no bytes at all, so there is nothing in it to open` | كُتب خزناً جديداً فوق صفر بايت (235B) |
| مقطوع إلى 132B | `Locked` | `PayloadRefused` · create: `VaultAlreadyExists` | `this vault file is truncated` | لم تتغيّر |
| آخر بايت xor 1 | `Locked` | `VaultAuthenticationFailed` | passphrase/corrupted/modified | لم تتغيّر |
| البايت الأول (السحر) xor 1 | — | `PayloadRefused` | `this is not a Z Privacy vault file` | لم تتغيّر |
| بايت زائد في الذيل | — | `TrailingVaultData` | data after the end of the ZVLT structure | لم تتغيّر |

المصدر: `vault/mod.rs:187-233` · `vault/mod.rs:262-271` · `vault/crypto.rs:441-452` · `logs/B2-harness.txt` القسم 1.

### 2. نسخة أقدم تفتح خزنة النموذج 15
**النتيجة:** نجح. تُرفض بالجملة المطلوبة.

`format.rs:484-488`: إن `version > MODEL_VERSION` → `this vault's contents were written by a newer version (model {version}, this build knows {MODEL_VERSION})`. البناء الحالي `MODEL_VERSION=15`. قارئة بـ14 أمام جسم 15 ترفض وفي الجملة «written by a newer version».

اختبار الوحدة `truncated_or_future_contents_are_refused`: نجح (قارئ 15 أمام نموذج 16، نفس الباب). `logs/B2-model15-unit.txt`.

### 3. ترقية خزنة نموذج 14 فيها إعفاءات
**النتيجة:** نجح. الإعفاء يبقى.

`format.rs:823-843`: نموذج 14 كتب رقم المحادثة بلا وسم؛ يُقرأ `Exemption::Conversation(n)`. جسم فيه الرقم 7: بعد القراءة `reaches=["Conversation(7)"]`، وهو نفسه بعد ترقية الشكل الموسوم. `a_file_from_model(14)` يكتب الرقم 7 بلا تاج.

`the_settings_survive_and_an_older_vault_takes_the_defaults` يفتح `a_file_from_model(14)`: نجح. `a_block_keeps_its_tokens_and_its_exemptions` (Conversation(7) عبر encode/decode الحالي): نجح.

### 4. كلفة تخمين الرقم السري
**النتيجة:** قيس. ليس عيباً.

معاملات خزنة جديدة (`vault/crypto.rs:54-58`):

- Argon2id · Version 0x13
- `m_cost = 65536` KiB (64 MiB)
- `t_cost = 3`
- `p_cost = 1`
- الخرج 32 بايت · الملح 16 بايت

على هذا الجهاز، **release** (`logs/argon-bench.log`): **0.0679 ثا/محاولة · 14.72 محاولة/ثا**. تخمين رقم من 8 أرقام: نحو 78.6 يوماً. لا عدّاد محاولات، وهذا مقصود.

### 5. نسختان تكتبان الخزنة معاً
**النتيجة:** نجح على المسار العادي. انظر العيب 1 إن جُعل القفل مجلداً.

قياس مستقل، عمليتان حقيقيتان، 40 تجربة، 40 هوية حشو، حاجز `ready` ثم `GO` (لا نوم ثابت):

```
trials=40 both=0 a_only=15 b_only=25 neither=0
honest VaultChangedElsewhere refusals: 40
SILENT lost writes: 0
```

اختبار المنتج `two_copies_never_lose_a_write` (BULK=300، 6 تجارب): **3/3 نجح** في 5.73 ثا (`logs/B2-two-copies-test.txt`).

القفل: `writing.lock` + `std::fs::File::lock` عبر `with_core`. الثانية تُرفض بجملة `VaultChangedElsewhere` («another copy of Z Privacy changed this vault»).

### 5ب. كتابة ملف الجلسة `.zs`
**النتيجة:** نجح.

20 تجربة، نسختان تُسجّلان دوراً بعد `conversation_enter` على الحاجز نفسه:

```
turn trials=20 both_on_disk=20 silent_lost=0
```

التجربة 0: `asked=["erste", "turn-B-0", "turn-A-0"]` — الدور السابق والدوران الجديد على القرص. `conversation::record_in` يعيد قراءة الملف تحت القفل. اختبار المنتج `two_copies_never_lose_a_turn`: نجح.

### 6. جلسة منسيّة، ورقم الوثيقة الخارجة
**النتيجة:** نجح.

- قبل النسيان: `sessions/1.zs` و`2.zs`. بعد `conversation_forget`: بقي `1.zs`. ملف المنسيّة فُكّ ربطه (`conversation::remove`).
- إبر النص الواضح في كل ملف تحت مجلد العمل، صفر إصابات: `ATTACK_SESSION_NEEDLE` · `ATTACK_QUESTION_NEEDLE_SECRET` · `ATTACK_ANSWER_NEEDLE` · `ZxqvSessionNeedle`.
- أرقام الوثائق: بعد خروج `chat1` الوثيقة التالية `chat2`. الرقم الخارج لا يُعاد.

### 7. لا طريق يمسح بلوكاً (القاعدة 50) · `delete_entity` يعفي
**النتيجة:** نجح على المسح وعلى الإعفاء.

بحث مستقل (`logs/B2-block-search.txt`):

- نمط G35: `.blocks.(remove|retain|clear|pop|drain|truncate|swap_remove|dedup|split_off)` و`.blocks =` — لا مطابقة على `Vault.blocks` في `z_core/src` (المطابقة الوحيدة: `let mut blocks = Vec::new()` عند القراءة، و`blocks` في ردّ Anthropic).
- أنماط زائدة: `mem::take` / `splice` / `resize` على `blocks` — لا مطابقة.
- الكتّاب: `blocks.push` في `remember_block` فقط · `exempt.push` في `exempt_block` / decode فقط.
- `a_block_is_never_deleted`: 10/10.

قياس الباب (`delete_entity`):

```
after import with identity: protected_findings=1 blocks=1
after delete_entity: entities=0 blocks=1 (block deleted? false)
new document after deleting the identity: protected_findings=0 suggested=0
```

البلوك بقي (القاعدة 50) ولم يعمل في الوثيقة التالية (`forget_the_blocks_of` في `ops/vault.rs:238`).

---

## اختبارات النسخة (لم تُرقَّع)

| الاختبار | النتيجة |
|---|---|
| `truncated_or_future_contents_are_refused` | 1/1 |
| `the_settings_survive_and_an_older_vault_takes_the_defaults` | 1/1 |
| `a_block_keeps_its_tokens_and_its_exemptions` | 1/1 |
| `a_block_is_never_deleted` | 10/10 |
| `two_copies_never_lose_a_write` | 3/3 |

---

## العدّ

| الدرجة | العدد |
|---|---|
| مانع | 0 |
| خطير | 0 |
| ملاحظة | 1 |

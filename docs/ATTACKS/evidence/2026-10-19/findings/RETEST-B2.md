# إعادة قياس B2 — 2b4fad9

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**الختم:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**المصدر:** `/home/monopeaks/z-attack-2b4fad9` (detached، لم يُمس)  
**لم يُمس:** `~/.local/share/zprivacy` (mtime `vault.zv` = 2026-10-19 06:17:31 +0200) · `~/mono-privacy`

الأدوات: `harnesses/b2-harness` (release، path-dep) · `harnesses/argon_bench` (release) · `cargo test -p z_core --test two_copies_never_lose_a_write --release` · `cargo test -p z_core --lib` لثلاثة اختبارات النموذج · `cargo test -p z_core --test a_block_is_never_deleted --release`  
`CARGO_TARGET_DIR=/home/monopeaks/z-attack-2b4fad9-evidence/target-b2`

السجلات: `logs/B2-harness.txt` · `logs/argon-bench.log` · `logs/B2-two-copies-test.txt` · `logs/B2-model15-unit.txt` · `logs/B2-block-search.txt` · `logs/B2-block-never-deleted.txt`

السابق المقاس عليه: `/home/monopeaks/mono-privacy-papers/docs/ATTACKS/findings/B2-vault.md` على 84832a0.

---

## الحالات المطلوبة

### 1. Empty vault trap

**FIXED** (أُعيد تأكيده)

1. **ماذا فعلت:** خزنة مؤقتة تحت `scratch/b2/corrupt`. كتبت `vault.zv` صفراً، ثم `vault_state` / `unlock` / `create`. ثم ملف مقطوع (132B) وشاهدَي byte-flip وذيل زائد.
2. **ماذا كان يجب:** ملف بلا بايتات ليس خزنة (`Absent`)، والإنشاء مسموح. ملف متضرر لا يُكتب فوقه.
3. **ماذا حدث:** الفارغ: `state=Absent` · unlock «this vault file holds no bytes at all» · `create => created` وكتب 235 بايت. المقطوع: `Locked` · `create => VaultAlreadyExists` · البايتات لم تتغيّر · unlock «this vault file is truncated». آخر بايت xor 1: `VaultAuthenticationFailed`، لم تتغيّر. السحر xor 1: «this is not a Z Privacy vault file»، لم تتغيّر. ذيل زائد: `TrailingVaultData`، لم تتغيّر.

**الدرجة:** — (ليس عيباً)

---

### 2. Two-copies silent loss

**FIXED** (أُعيد تأكيده)

1. **ماذا فعلت:** 40 تجربة عمليتين `create_entity` بعد حاجز ملف، 40 هوية حشو. ثم 20 تجربة على `conversation_record`. ثم اختبارهم `two_copies_never_lose_a_write.rs` release (`--test-threads=1`).
2. **ماذا كان يجب:** لا كتابة تُفقد بصمت. إما الاثنتان على القرص، أو رفض باسم `VaultChangedElsewhere`.
3. **ماذا حدث:**
   - الخزنة، 40/40: `both=0` · `a_only=15` · `b_only=25` · `SILENT lost writes=0` · `honest VaultChangedElsewhere=40`. من قال `ok` هو من بقي على القرص؛ الآخر `err VaultChangedElsewhere`.
   - الجلسة، 20/20: `both_on_disk=20` · `silent_lost=0` (التجربة 0: `asked=["erste", "turn-B-0", "turn-A-0"]`).
   - اختبارهم: `3 passed` (`two_copies_never_lose_a_write` · `two_copies_never_lose_a_turn` · العامل) في 5.73 ثا.

**الدرجة:** — (ليس عيباً على المسار العادي)

---

### 3. delete_entity lie

**FIXED** (أُعيد تأكيده)

1. **ماذا فعلت:** هوية قيمتها `ZxqvBlockNeedle` بسياسة Always. استيراد → `protected=1` · `blocks=1`. `delete_entity` كما يفعل الزر. ثم استيراد الاسم في جلسة جديدة.
2. **ماذا كان يجب:** النسيان يعفي البلوك ولا يمسحه. الوثيقة التالية لا تحمي القيمة من الهوية المحذوفة.
3. **ماذا حدث:** بعد الحذف `entities=0` · `blocks=1` (لم يُمسح — القاعدة 50). الجلسة الجديدة: `protected=0` · `suggested=0`. بحث المصدر: لا `blocks.remove/retain/clear/pop/drain` على بلوكات الخزنة. `a_block_is_never_deleted`: 10/10.

**الدرجة:** — (ليس عيباً)

---

### 4. writing.lock-as-dir

**باقٍ — ملاحظة**

القياس على 8 تجارب لم يُعد إنتاج فقد صامت؛ المصدر ما زال يتابع بلا قفل إن فشل الفتح.

1. **ماذا فعلت:** بعد الإنشاء حوّلت `writing.lock` إلى مجلد. عمليتان تضيفان هوية، 8 تجارب.
2. **ماذا كان يجب:** إن تعذّر القفل: رفض صادق أو جملة باسمها — لا السباق القديم.
3. **ماذا حدث:** `lock-bypass trials=8 silent_lost=0`. التجربة 0: `A=err VaultChangedElsewhere` · `B=ok 21` · القرص احتفظ بـ B. `ensure_disk_unchanged` وقف هنا. السابق على 84832a0: `silent_lost=1/8`. الثقب في `open_the_lock(...).ok()?` / `file.lock().ok()?` → `None` → `with_core` بلا `flock` لم يُغلق.

**الدرجة:** ملاحظة

---

### 5. Argon cost

**قيس. ليس عيباً.**

المصدر (`vault/crypto.rs:54-58`): Argon2id v0x13 · `m=65536` KiB · `t=3` · `p=1` · hash 32 · salt 16.

release على هذا الجهاز (`logs/argon-bench.log`): **0.0679 ثا/محاولة · 14.72 محاولة/ثا**. رقم من 8 أرقام: نحو **78.6 يوماً**. لا عدّاد محاولات (مقصود).

**الدرجة:** —

---

### 6. Model 14/15

**نجح.**

- `MODEL_VERSION = 15` (`format.rs:91`).
- قارئ أقدم (14) أمام جسم 15: الجملة تحتوي «written by a newer version». الباب: `format.rs:484-488`.
- وحدة `truncated_or_future_contents_are_refused`: 1/1 (قارئ 15 أمام نموذج 16، يسمّي الرقمين).
- نموذج 14 كتب Conversation بلا وسم؛ `a_file_from_model(14)` يضع الرقم 7؛ decode يقرأه `Exemption::Conversation(7)`. نفس الإعفاء بعد الشكل الموسوم.
- `the_settings_survive_and_an_older_vault_takes_the_defaults`: 1/1 (يفتح كل نموذج حتى 15).
- `a_block_keeps_its_tokens_and_its_exemptions`: 1/1 (`Conversation(7)` يعيش encode/decode).

**الدرجة:** —

---

## العدّ من هذه الجولة

| السابق (84832a0) | الآن (2b4fad9) |
|---|---|
| Empty vault trap (FIXED) | **FIXED** |
| Two-copies silent loss (FIXED) | **FIXED** (0/40) |
| delete_entity lie (FIXED) | **FIXED** |
| writing.lock-as-dir (NOTE، silent_lost=1/8) | **NOTE** (silent_lost=0/8؛ الثقب في المصدر باقٍ) |
| Argon cost (قيس) | قيس · 14.72/ثا |
| Model 14/15 (نجح) | **نجح** · MODEL_VERSION=15 |

**مفتوح من هذه الجولة:** ملاحظة 1 (writing.lock مجلد → بلا flock). مانع 0 · خطير 0.

# من أين نكمل — نقطة التسليم، ٢٨ سبتمبر ٢٠٢٦

> اقرأ هذه الورقة أوّلاً، ثمّ `docs/M7_HARDENING.md`.
> **لا كود كُتب بعد في مرحلة التقسية.** ما تحت «الحالة» صحيحٌ بالضبط.

## الحالة

```text
HEAD                8548c45   040 — ورقة مرحلة التقسية
النقطة المرجعيّة     audit/pre-redteam-2026-09-28 → b4cdfed  (كودها 96b8f51 بحرفه)
المستودع            بلا remote — الوسم محليّ
شجرة العمل          نظيفة، ولا إصلاح واحد بدأ
```

**الميزات مجمَّدة.** لا Mono-3D، ولا `My Privacy Rules`، ولا M8 — حتى تُغلق
`F-01…F-11`.

## المهاجم محفوظ — لا يُعاد كتابته

كان في `/tmp` وكان سيُمسح. نُقل كما هو إلى:

```text
~/zprivacy-redteam-2026-09-28/harness/     مصدر المهاجم + Cargo.lock  (٧٦ ك.ب)
~/zprivacy-redteam-2026-09-28/evidence/    اللقطات والسجلّات الصغيرة
```

حُذف `target/` وحده (٥٥١ م.ب من cache البناء). و`Cargo.toml` يشير إلى
`/home/monopeaks/mono-privacy/z_core` بمسارٍ مطلق، فيُبنى من مكانه:

```bash
cd ~/zprivacy-redteam-2026-09-28/harness && cargo run --bin url
cargo run --bin kdf      # F-03
cargo run --bin fs       # F-04
cargo run --bin rollback # F-02
cargo run --bin trailing # F-09
cargo run                # main: F-01 · F-05 · F-06، و F-07 بتمرير malformed.docx
```

**شرط الخروج: يُعاد تشغيل هذا بعينه، بلا تعديلٍ لصالحنا.** لا تُلطّف أسيرة
ولا يُضاف استثناء لأنّنا صرنا نعرف أين يقع.

## الترتيب (قراره)

```text
 1. F-01  ربط الاعتماد بالوجهة          ← ابدأ من هنا
 2. F-03  حدود Argon2 قبل أيّ allocation
 3. F-04  أذونات الملفّ / symlink / الكتابة الذرّيّة
 4. F-08  القفل يُسقط cache الخزنة فعلاً
 5. F-09  قراءة ZVLT صارمة + رسالة صادقة
 6. F-05  الاستعادة مربوطة بالـpayload/الجواب
 7. F-06  المقبض one-shot بعد إرسالٍ ناجح
 8. F-07  DOCX مشوّه يفشل مغلقاً
 9. F-11  الحافظة
10. TruthSnapshot + الكذبات العشر
11. عائق 1280×720 بحلٍّ بنيويّ
12. MISSING   13. بقيّة FRICTION
```

**قاعدة ثابتة: commit مستقلّ لكلّ Finding، ومعه اختبار إغلاقه.** لا دمج.

---

## F-01 — جاهزة للتنفيذ

### الهجوم بالضبط (من `harness/src/main.rs`، الأسطر ٣٨–٥٠)

```rust
connect_provider(openai, "ZXQ-REBIND-KEY-22007", Some("http://127.0.0.1:18080"), …)
configure_provider(openai, Some("http://127.0.0.1:18081"), …)   // بلا إعادة إدخال
send(handle, openai)                                            // المفتاح يصل إلى :18081
```

### أين العطب

`z_core/src/ops/mod.rs:329` — `configure_provider`. تعليقها نفسه يشرح النيّة:
«تغيير العنوان يجب ألّا يعني كتابة المفتاح ثانيةً». صحيحةٌ للـmodel، وخاطئةٌ
للوجهة. السطر:

```rust
Some(l) => ProviderLogin { credential: l.credential.clone(), base, … }
```

يحمل الاعتماد إلى `base` جديد بلا أيّ فحص.

### الإصلاح (حكمه: لا popup — الـcore نفسه لا يملك اعتماداً صالحاً للوجهة الجديدة)

1. **`z_core/src/providers/http.rs`** — دالّة جديدة بجانب `check_url` و
   `is_loopback_url` (وG1c يُبقي عمل الـURL هنا):
   ```rust
   /// هويّة الوجهة: scheme + host بحروفٍ صغيرة + المنفذ صريحاً.
   pub(crate) fn destination_of(base: &str) -> String
   ```
   `https://api.x.com` و`https://API.x.com:443/` ⇒ نفس الهويّة.
   `:18080` و`:18081` ⇒ هويّتان.

2. **`z_core/src/vault/model.rs`** — `ProviderLogin` يكسب حقلاً:
   ```rust
   pub bound_to: String,   // هويّة الوجهة التي أُدخل المفتاح لأجلها
   ```
   ونموذج الجسم **٤ → ٥**. الهجرة: ملفٌّ بنموذج ٤ يشتقّ `bound_to` من
   `base` المخزَّن — فاليقين لا يُفقَد ولا يُدّعى.

3. **`z_core/src/ops/mod.rs`**
   - `connect_provider`: `bound_to = destination_of(&base)`.
   - `configure_provider`: إن اختلفت `destination_of(&base)` عن
     `l.bound_to` ⇒ **الاعتماد لا يُنقل**. تُكتب وجهةٌ جديدة بلا مفتاح،
     فيعود الصفّ `connected: false`.
   - `login_for` (يستعمله `send` و`test_provider`): يرفض إن كانت
     `destination_of(&login.base) != login.bound_to` ⇒ `not_connected`.
     طبقةٌ ثانية: حتى لو كتب مسارٌ آخر الـlogin، لا يخرج مفتاحٌ لوجهةٍ
     لم يُدخَل لها.
   - الرسالة تسمّي السبب لا المفتاح: «الاعتماد أُدخل لـ‹الوجهة القديمة›».

### اختبار الإغلاق — `z_core/tests/credential_binding.rs`

على نمط `tests/wire_capture.rs` (خادمٌ يسجّل البايتات):

```text
١ · الأسيرة    connect :18080 بمفتاح → configure :18081 → send
               ⇒ لا ترويسة Authorization على :18081 إطلاقاً
٢ · التحكّم    نفسها بلا تغيير الوجهة ⇒ الترويسة موجودة
               (بلا هذه، قد ينجح الاختبار لأنّ شيئاً آخر انكسر)
٣ · وحدة       destination_of: منفذٌ ضمنيّ · حروفٌ كبيرة · شرطةٌ أخيرة ⇒ تساوٍ
               واختلاف المنفذ وحده ⇒ اختلاف
```

### ما سينكسر ويجب إصلاحه معه

- اختبار التوافق الخلفيّ للخزنة: `a_file_from_model(version)` يحتاج ٥.
- **G17** يعدّ دوالّ العقد (٥٨). هذا الإصلاح **لا يضيف دالّة عامّة**،
  فالعدد يبقى ٥٨. إن تغيّر فقد وسّعتَ العقد بلا قصد.
- `cargo test -p z_core --features fake_provider` كاملةً، ثمّ
  `scripts/gates.sh` — و**احكم على رمز الخروج لا على المخرَج**.

---

## F-02 — مغلقةٌ بلا كود (قراره)

لا generation في ZCFG ولا في ZVLT. تُغلق في M7 بـ:

```text
Accepted limitation — explicitly documented
```

النصّ مكتوبٌ بالعربيّة في `SECURITY_INVARIANTS.md §٠`. **الباقي عليك**:
إضافة الصيغة الإنجليزيّة كما كتبها، ودقّةٌ ثالثة قالها ولم تُكتب بعد:

> Forget يحذف القيمة من **الخزنة الحاليّة**، والنظام الحاليّ لم يعد يعرفها.
> ولا ندّعي أنّ من يملك نسخةً قديمة من الخزنة لا يستطيع إعادتها.

## F-12 — لا يُصلَح بذكاءٍ جديد

السرّان اللذان وصلا لم يكونا مصنَّفين ولا محميّين، وهذا خارج الوعد. يُقسَم
اختبار التاج إلى اثنين فقط (الجدول في `M7_HARDENING.md §٢`). **لا نفتح باب
«ليكتشف Z Privacy كلّ شيء».**

## قبل أيّ سطر

```bash
cd ~/mono-privacy && git status --short        # يجب أن تكون نظيفة
cargo test -p z_core --features fake_provider  # ١٧١ خضراء قبل أن تبدأ
```

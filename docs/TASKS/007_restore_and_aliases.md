# 007 · الاستعادة و«قلب المنتج»

**المرحلة:** M2 — **تمّت، وبها يكتمل قلب Z Privacy** (نفس commit 005)

## القاعدة (قرار المالك)
الاستعادة تستبدل **فقط** رموز `TokenStore` لهذه الجلسة. `__Z_FAKE_123__` يبقى حرفاً حرفاً، ولا يحاول Rust تفسيره.

## ما دخل
- `tokens::restore` — يعيد `Vec<Segment>`، لكلّ مقطع `restored: bool`، فتعرف الواجهة أيّ كلمة أعادتها محلّيّاً (العلامة المنقّطة في اللوحة).
- `ingest_answer` — الباب الداخل وحده حتى M6. ولا يرفع الـrevision: الوارد لا يغيّر ما سيخرج، فالمقبض يبقى سليماً.
- `restored_view` و`ai_view`.

## «تمّ» يعني — وهذا ما طلبتَ أن نراه
```
cargo run -p z_core --example round_trip

ORIGINAL   Herr Thomas Müller arbeitet bei Nordstern GmbH.
SAFE       Herr __Z_04C6_PERSON_5001__ arbeitet bei __Z_04C6_COMPANY_4C4F__.
AI VIEW    Bitte kontaktieren Sie __Z_04C6_PERSON_5001__ bei __Z_04C6_COMPANY_4C4F__. __Z_FAKE_123__ ist unbekannt.
RESTORED   Bitte kontaktieren Sie Thomas Müller bei Nordstern GmbH. __Z_FAKE_123__ ist unbekannt.
```
بلا ماسح، وبلا خزنة، وبلا واجهة.

و`tests/round_trip.rs` ستّة اختبارات: الرحلة كاملةً · الرمز المجهول يبقى (وثلاثة أشكال منه: مختلق، وناقص الإغلاق، وعلى شكلنا لكنّه ليس لنا) · **جلسة لا تقرأ رموز جلسة أخرى** · كلّ تهجئة تعود إلى الاسم الأوّل للكيان · وجوابٌ وارد لا يُبطل مقبضاً.

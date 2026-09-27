# 001 · الأرض

**المرحلة:** M0 · **الحالة:** تمّت

## المطلوب
مستودع يبني، وقواعد تحكم الكود من أوّل commit — لا تُضاف بعد أن يكبر.

## ما دخل
- `git init` على `main` في `~/mono-privacy`، و`boards/` تبقى داخله مرجعاً غير تنفيذي.
- workspace فيه `z_core` وحده، و`[workspace.lints]` تُطبّق على الكلّ:
  `unsafe_code = forbid` · `clippy::{unwrap_used, expect_used, panic} = deny`.
- `z_core` **بلا اعتماديات إطلاقاً** حتى M4. لا شيء يُراجَع هو أرخص مراجعة.
- `core_version()` — أوّل شيء ستراه الواجهة قادماً من Rust.
- `docs/SECURITY_INVARIANTS.md`: أحد عشر ثابتاً، ولكلٍّ فحصه، وفي رأسها ما **لا** يَعِد به المنتج.
- `scripts/gates.sh`: البوّابات تعمل من اليوم، وتتخطّى بأدب ما لم يُبنَ بعد.

## المعرّفات المثبّتة (قرار المالك ٢٧ سبتمبر)
- اسم المنتج: `Z Privacy` · معرّف التطبيق: `com.monopeak.zprivacy`
- المنصّة الأولى: Linux desktop، ثمّ Windows/macOS، ثمّ Android/iOS، ثمّ الويب.

## «تمّ» يعني
```
cargo test --workspace   → أخضر
./scripts/gates.sh       → all gates passed
```

# 002 · الجسر

**المرحلة:** M0 · **الحالة:** تمّت

## المطلوب
أن يثبت الطريق كلّه قبل أن يُكتب فيه منطق: Dart → جسر → Rust، وسطرٌ واحد من Rust يُرى في نافذة Flutter.

## ما دخل
- `flutter_rust_bridge_codegen 2.13.0`، وتطبيق Flutter عند `apps/flutter_app`
  (`--org com.monopeak --project-name zprivacy` ⇒ معرّف التطبيق `com.monopeak.zprivacy`)، لينكس أوّلاً.
- **صندوقان لا واحد:**
  - `z_core` — المنطق، **بلا أيّ اعتمادية**، ولا يعرف الجسر أصلاً. يُختبر ويُبنى وحده، وسيُبنى لـWASM لاحقاً كما هو.
  - `bridges/native/z_bridge` — غلافٌ رقيق: كلّ دالّة فيه سطرٌ واحد ينادي `z_core`. هنا وحده يُسمح بـ`unsafe` لأنّ كود frb المولّد يحتاجه؛ ولذلك بقي خارج `[workspace.lints]`.
- cargokit يبني `libz_bridge.so` ويضعها في حزمة التطبيق تلقائياً مع كلّ `flutter build`.
- `core_version()` بـ`#[frb(sync)]`: أوّل ما تراه النافذة قادمٌ من Rust، لا ثابتاً في Dart.

## «تمّ» يعني — وقد رُئي
```
flutter build linux --debug        → ✓ Built …/bundle/zprivacy
ls bundle/lib                      → libz_bridge.so  (مبنيّة من z_core)
xvfb-run ./zprivacy                → bridge ok — z_core 0.1.0
```
السطر الأخير خرج من Dart بعد أن سأل Rust. الطريق مفتوح في الاتّجاهين.

## ملاحظتان للمستقبل
- `cargo expand` غير مثبّت؛ frb يحذّر ويكمل. يلزم فقط إن استعملنا ماكرو داخل `api`.
- تشغيل النافذة هنا كان على شاشة وهمية (`xvfb`) لئلّا تُفتح نافذة على شاشة المالك بلا إذن. على جهازه: `cd apps/flutter_app && flutter run -d linux`.

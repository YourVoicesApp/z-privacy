# Z Privacy — خطة العمل

٢٧ سبتمبر ٢٠٢٦ · المبرمج يكتب، والمالك يحكم.
المرجع البصري: `boards/` (٢١ لوحاً) — واللوح الحيّ: https://claude.ai/artifact/67zw3izEV2SLnGK8opzXaz
المرجع السلوكي: `boards/Behaviour1-3.dc.html` — حالات كلّ زرّ.

---

## ١ · القرار المعماري (ثابت)

> **Flutter يرى ويعرض؛ Rust يقرأ ويحمي ويشفّر ويرسل ويعيد بناء المعلومات.**

وأضيف بنداً واحداً يُقوّي قاعدتك «Rust وحده يبني النصّ الذي يغادر الجهاز»، ويجعلها **غير قابلة للخطأ** لا مجرّد اتّفاق:

> **لا دالّة إرسال تقبل نصّاً. `send` يأخذ مقبضاً: `PayloadHandle`.**

الحِمْل الآمن يُبنى في Rust ويبقى في Rust؛ Flutter يتلقّى منه *صورة للعرض* فقط (`PayloadView`). فحتى لو أخطأ مبرمج الواجهة، أو أُسيء استخدام الجسر، **لا يوجد توقيع دالّة في الـAPI يقبل نصّاً للإرسال**. الخطأ يصبح مستحيل التعبير عنه، لا مجرّد ممنوع.

```
Flutter Original (عرض)          ← نسخة للعرض، من Rust
        ↓ protect/scan/review   ← أوامر، لا نصّ منقول للشبكة
Rust Privacy Core
        ↓
Rust SafePayload  →  PayloadHandle(id)
        ↓ preview               ← PayloadView للعرض في العمود الأيمن
Flutter Send(handle)
        ↓
Rust Network Gateway            ← المكان الوحيد الذي يعرف الشبكة
```

---

## ٢ · شكل المستودع

```
mono-privacy/
├── z_core/                     # الصندوق الواحد — كلّ المنطق
│   ├── src/
│   │   ├── lib.rs
│   │   ├── api.rs              # سطح العقد الوحيد لـ Flutter (frb)
│   │   ├── payload.rs          # SafePayload · PayloadStore · PayloadHandle
│   │   ├── tokens/             # create · protect · restore · rotate
│   │   ├── scanner/
│   │   │   ├── general_rules/  # IBAN · email · phone · postcode
│   │   │   └── packs/de.rs     # ثمّ en.rs · sv.rs · ar.rs
│   │   ├── vault/              # entities · values · aliases · profiles · storage
│   │   ├── documents/          # txt · docx · pdf
│   │   ├── providers/          # openai · anthropic · google · custom
│   │   └── crypto/             # keys · sealing · os_keystore
│   └── tests/                  # golden + property + no-leak
├── apps/flutter_app/           # الواجهة فقط
├── bridges/native/             # مولّد frb (لا يُحرّر بيد)
├── bridges/wasm/               # المرحلة الأخيرة
├── docs/
│   ├── PLAN.md                 # هذه الورقة
│   ├── API.md                  # العقد، مولّد من api.rs
│   ├── SECURITY_INVARIANTS.md  # الخمس التي تفشل البناء
│   └── TASKS/NNN_*.md          # مهمّة واحدة لكلّ commit
└── boards/                     # التصميم المرجعي
```

قاعدة العمل: **مهمّة واحدة لكلّ commit**، وملفّ مهمّة في `docs/TASKS/` قبل الكود.

---

## ٣ · المراحل — ولكلٍّ معيار «تمّ» يُفحَص لا يُدَّعى

| # | المرحلة | «تمّ» = هذا يعمل ويُرى |
|---|---|---|
| **M0** | الأرض | `git init` + workspace يبني، و`flutter run -d linux` يعرض نصّاً **قادماً من Rust** (`z_core 0.1.0`)، و`cargo test` أخضر. الجسر مُثبت قبل أيّ منطق. |
| **M1** | العقد | كلّ دوالّ `api.rs` بتوقيعاتها وأنواعها، أجسامها `todo!()`، و`API.md` مولّد. Flutter يستدعي **كلّ** دالّة فتُرجع «not implemented» مرتّباً بلا انهيار. |
| **M2** | القلب | tokens + SafePayload + restore. برهانان بالاختبار: (أ) **لا تسريب**: الحِمْل لا يحوي أيّ قيمة محميّة — مع *سلسلة تحكّم* تُثبت أنّ الفحص نفسه يعمل؛ (ب) `restore` يعيد القيم تماماً، وكلّ aliases الكيان → **رمز واحد**. |
| **M3** | الماسح | `general_rules` ثمّ `german_pack`، بثلاث حالات (auto · suggest · none) ومصدر لكلّ عنصر. ملفّ ذهبي `Vertrag_Nordstern.txt` يعطي **٧ auto · ٢ suggest · ٤٢٨ normal** بالضبط، كما في اللوحات. |
| **M4** | الخزنة | entities/values/aliases/profiles + تشفير + قفل وقفل تلقائي. دورة كاملة: أنشئ → أغلق التطبيق → افتح بالمفتاح. والقاعدة المرسومة: **مقفلة ⇒ طبقة الخزنة تُتخطّى** والشريط يقولها بالكلمات. |
| **M5** | المستندات | txt → docx → pdf. وPDF ممسوح بلا طبقة نصّ **يُرفض بسببه**، لا يُستورد فارغاً. |
| **M6** | البوّابة | providers + المفاتيح في مخزن النظام + الإرسال بالمقبض. طلب حقيقي إلى مزوّد واحد، ومحاولة تمرير نصّ أصلي **لا يمكن كتابتها** في الـAPI. |
| **M7** | الواجهة | Workspace أوّلاً بسلوك ألواح Behaviour حرفاً حرفاً (خمس حالات لـ Protect، ومموّج «?» يبقى مكشوفاً)، ثمّ الغرف: Vault · Profiles · Providers · Settings. |
| **M8** | الويب | نفس الصندوق إلى WASM. مفاتيح الجلسة فقط، ولا مخزن نظام — وحدوده مكتوبة في الواجهة لا مخفيّة. |

**ترتيب المنصّات:** Linux desktop أوّلاً (أسرع حلقة، وهو مقاس التصميم ١٤٤٠×٩٠٠) ← Windows/macOS ← Android/iOS ← الويب.

**سبب الترتيب داخلياً:** M2 قبل M3 لأنّ الماسح بلا محرّك رموز يُنتج نتائج لا يمكن التحقّق منها؛ وM2 قبل الواجهة لأنّ العمودين بلا `SafePayload` حقيقي يصيران زينة.

---

## ٤ · العقد (`api.rs`) — ما تستدعيه الواجهة، لا أكثر

مأخوذ من ألواح Behaviour مباشرة، ولا شيء فيه يُرجع نصّاً للشبكة:

```
جلسة     open_session(profile_id, pack_id) -> SessionId
مستند    import_document(session, bytes, kind) -> DocumentView | ImportRefused{reason}
          document_view(session) -> DocumentView            // النصّ الأصلي للعرض فقط
فحص      scan(session, options?) -> ScanReport{auto, suggested, normal, by_layer}
حماية    protect(session, span, scope, category?) -> ProtectOutcome
              // ProtectOutcome = Applied | AlreadyProtected{token, source}
              //               | BelongsToEntity{entity, choices} | SnappedTo{spans}
          protect_all_matches(session, span) -> {count, token}
          undo_last_protection(session) -> UndoOutcome{also_created_entity?}
مراجعة   list_findings(session) -> [Finding{state, kind, source, reason, token?}]
          answer_finding(session, finding_id, Protect|Always|NotSensitive|Skip)
كشف      reveal(session, token) -> RevealedValue{ttl_ms}   // لا يلمس الحِمْل
          hide(session, token)
          list_tokens(session) -> [TokenRow{token, kind, scope, source}]
حِمْل      build_payload(session) -> PayloadHandle
          payload_view(handle) -> PayloadView{text, protected_count, open_suggestions}
إرسال    send(handle, provider_id) -> AnswerId | SendRefused{open_suggestions|no_provider}
جواب     restored_view(answer) -> [Segment{text, restored: bool}]
          ai_view(answer) -> String                         // كما وصل، برموزه
خزنة     vault_unlock(key) · vault_lock() · vault_state()
          entities(filter) · entity(id) · upsert_value(...) · add_alias(...)
ملفّات    profiles() · switch_profile(id) -> SwitchOutcome{kept_tokens}
حزم      packs() · switch_pack(id) -> RescanOutcome{changed_to_manual}
مزوّدون   providers() · connect_provider(...) · test_provider(id)
```

`DocumentView` و`PayloadView` **بنيتان للعرض**: Flutter يرسمهما ولا يملك سلطة على مصدرهما.

---

## ٥ · البوابات الخمس — تفشل البناء، لا تُراجَع بالعين

1. `reqwest`/`hyper`/أي عميل HTTP **ممنوع خارج** `z_core::providers` — فحص على شجرة الاعتماديات + grep على الوحدات.
2. كلّ `send_*` توقيعها `PayloadHandle` — اختبار يقرأ التوقيعات ويفشل إن ظهر `String` أو `&str` في مدخل إرسال.
3. خاصيّة **لا تسريب**: لكلّ قيمة في الخزنة ولكلّ عنصر محميّ، الحِمْل لا يحويها — مع سلسلة تحكّم مزروعة تُثبت أنّ الفحص يكتشف التسريب فعلاً حين يوجد.
4. `#![forbid(unsafe_code)]` في كلّ شيء خارج الجسر، و`deny(clippy::unwrap_used)` في `crypto` و`payload`.
5. `pubspec.yaml` بلا `http`/`dio`/`web_socket_channel` إطلاقاً — الواجهة لا تعرف الشبكة أصلاً.

---

## ٦ · الأرض كما قستُها اليوم

| موجود | الإصدار |
|---|---|
| rustc · cargo · rustup | 1.98.0 |
| Flutter · Dart | 3.44.2 stable · 3.12.2 |
| Linux desktop (GTK3) | مفعّل، والاعتماديات موجودة |
| Android SDK + NDK + cargo-ndk | NDK 28.2.13676358 |
| web (Flutter) | مفعّل |
| أهداف Rust | linux-gnu · linux-musl · aarch64-linux-android · aarch64-apple-ios |

| ناقص | متى يلزم |
|---|---|
| `flutter_rust_bridge_codegen` | **M0** — `cargo install flutter_rust_bridge_codegen` |
| `wasm32-unknown-unknown` + `wasm-pack` | M8 فقط |
| أهداف أندرويد الأخرى (`armv7`, `x86_64`) | حين نبني للهاتف |

---

## ٧ · ما ينتظر كلمتك (ولا يعطّل M0–M2)

1. **سطح مكتب أوّلاً؟** أفترض: لينكس أوّلاً، ثمّ ويندوز/ماك، والهاتف لاحقاً.
2. **اسم التطبيق ومعرّفه**: أفترض `Z Privacy` و`app.zprivacy` حتى تقول غيره.
3. **المستودع**: أفترض `git init` هنا في `~/mono-privacy` على فرع `main`، والتصميم `boards/` يبقى داخله مرجعاً.
4. **«Send anyway»**: مرسوم مطفأً. هل يُسمح بتشغيله أصلاً، أم أحذف المفتاح من الكود؟
5. **حزمة واحدة للتطبيق، أم حزمة لكلّ ملفّ عمل؟** مرسوم: واحدة في الإعدادات.

---

## ٨ · الخطوة التالية مباشرة (M0، ثلاث مهامّ)

- `docs/TASKS/001_ground.md` — `git init`، workspace، `z_core` يبني، `.gitignore`، قواعد الـlint والبوابات ١ و٤ منذ أوّل commit.
- `docs/TASKS/002_bridge.md` — تثبيت `flutter_rust_bridge_codegen`، توليد `bridges/native`، وتطبيق Flutter فارغ يعرض سطراً واحداً من Rust.
- `docs/TASKS/003_contract.md` — `api.rs` كاملاً بتوقيعاته و`todo!()`، و`API.md` مولّد، وبوابة ٢ و٥ في CI.

بعدها M1 يكون قد تمّ فعلاً، ونفتح M2 — القلب.

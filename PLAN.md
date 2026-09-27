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
| **M1** | العقد | ✅ كلّ دوالّ `api.rs` بتوقيعاتها، وأجسام غير المبنيّة `Err(ApiError::NotImplemented)` — **لا `todo!()`** لأنّه panic عبر FFI (تصحيح المالك). Flutter يستدعي **الثلاثين** فتُرجع خطأً مكتوباً بلا انهيار. |
| **M2** | القلب | tokens + SafePayload + restore. برهانان بالاختبار: (أ) **لا تسريب**: الحِمْل لا يحوي أيّ قيمة محميّة — مع *سلسلة تحكّم* تُثبت أنّ الفحص نفسه يعمل؛ (ب) `restore` يعيد القيم تماماً، وكلّ aliases الكيان → **رمز واحد**. |
| **M3** | الماسح | ✅ `general_rules` ثمّ `german_pack`، بثلاث حالات (auto · suggest · none) ومصدر لكلّ عنصر. ملفّ ذهبي `Vertrag_Nordstern.txt` يعطي **٧ auto · ٢ suggest · ٤٢٨ normal** بالضبط، كما في اللوحات. |
| **M4** | الخزنة | ✅ entities/values/aliases/profiles + تشفير + قفل وقفل تلقائي. دورة كاملة: أنشئ → أغلق التطبيق → افتح بالمفتاح. والقاعدة المرسومة: **مقفلة ⇒ طبقة الخزنة تُتخطّى** والشريط يقولها بالكلمات. |
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

## ٧ · الخمسة — محسومة بكلمتك (٢٧ سبتمبر)

1. **لينكس أوّلاً** دون تردّد، ثمّ ويندوز/ماك، ثمّ أندرويد/iOS، ثمّ الويب.
2. المنتج `Z Privacy`، والمعرّف **`com.monopeak.zprivacy`** (مثبّت في `linux/CMakeLists.txt`).
3. المستودع هنا على `main`، و`boards/` داخله مرجعاً غير تنفيذي.
4. **«Send anyway» محذوف من النسخة الأولى** — لا مفتاح ولا إعداد. المقترح يُجاب عنه بـ Protect أو Not Sensitive، ثمّ يصير العدد صفراً.
5. الحزمة على ثلاث درجات: **App default → Profile override → Session override**، والعقد يحملها أصلاً في `open_session(profile_id, pack_id)` و`switch_pack`.

---

## ٨ · الخطوة التالية مباشرة (M0، ثلاث مهامّ)

- `docs/TASKS/001_ground.md` — `git init`، workspace، `z_core` يبني، `.gitignore`، قواعد الـlint والبوابات ١ و٤ منذ أوّل commit.
- `docs/TASKS/002_bridge.md` — تثبيت `flutter_rust_bridge_codegen`، توليد `bridges/native`، وتطبيق Flutter فارغ يعرض سطراً واحداً من Rust.
- `docs/TASKS/003_contract.md` — `api.rs` كاملاً بتوقيعاته و`todo!()`، و`API.md` مولّد، وبوابة ٢ و٥ في CI.

بعدها M1 يكون قد تمّ فعلاً، ونفتح M2 — القلب.


---

## ٨ · ما نُفّذ فعلاً — ٢٧ سبتمبر

سبع مهامّ، أربع commits، **٣١ اختباراً**، واثنتا عشرة بوّابة خضراء (`./scripts/gates.sh` → `all gates passed`).

| ما يعمل اليوم | كيف تراه بنفسك |
|---|---|
| قلب المنتج: أصل → حماية → حِمْل آمن → جواب بالرموز → استعادة | `cargo run -p z_core --example round_trip` |
| الجسر: نافذة Flutter تقرأ من Rust | `cd apps/flutter_app && flutter run -d linux` |
| العقد كلّه (٣٠ دالّة) من Dart بلا panic | `cd apps/flutter_app && LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib flutter test` |
| كلّ الثوابت | `./scripts/gates.sh` |

**تصحيحاتك الأربعة، كلّها في الكود:** `ApiResult` لا `todo!()` · المقبض يبطل بالـrevision (G6) · البوّابة G5 تمنع APIs الشبكة في Dart لا الحزم فقط · `vault_unlock_with_passphrase` والمفتاح الرئيسي لا يعبر الجسر (G8).

**وشيئان أضفتُهما وأنت لم تطلبهما، فقُل إن أردت عكسهما:**
1. **الفحص يعمل في الإنتاج لا في الاختبار فقط**: `audit` في كلّ `build_payload`، وحِمْلٌ يُسرّب لا يُسلَّم (`PayloadRefused`).
2. **المقبض لا يُصدَّق فوق السجلّ**: يُفحَص رقمه مع الجلسة ومع الحِمْل المحفوظ معاً.

**ما لم يُبنَ بعد (ويقول عن نفسه ذلك):** المستندات (M5) · الشبكة (M6) · الواجهة (M7) · الويب (M8).
كلّ دالّة منها تُرجع `NotImplemented`، وجدول الاختبارات في `stale_payload.rs` يحاسبها تلقائياً يوم تنزل.


---

## ٩ · M3 تمّت — ٢٧ سبتمبر

ثلاث مهامّ (009 القواعد العامّة · 010 الحزمة الألمانية · 011 الملفّ الذهبي)، و**٦٠ اختباراً**، و**٢٦ فحص بوّابة**.

```
cargo run -p z_core --example scan_document
✓ 7 protected automatically   ? 2 need review   ○ 428 normal text items
send is refused: 2 suggestions are still unanswered.
```

**الطبقات الثلاث الموجودة اليوم:** قواعد عامّة (IBAN بحسابه · بريد · هاتف دولي) · حزمة `de` (عناوين القيم ⇒ `Auto`؛ تحيّات وأشكال شركات وعناوين بريديّة ⇒ `Suggest`) · ويدك. والخزنة هي الطبقة الرابعة في M4، ويومها يصير اسم العميل وجهة الاتّصال `Auto` بدل `Suggest`.

**التالي M4 — الخزنة:** كيانات · هويّات · aliases · ملفّات عمل · تشفير ومفتاح من passphrase (Argon2id) · وقفل، وقاعدته المرسومة: **مقفلة ⇒ طبقة الخزنة تُتخطّى والشريط يقولها**.


---

## ١٠ · M4 تمّت — ٢٧ سبتمبر

أربع مهامّ (012 تصحيح BIC · 013 المظروف · 014 الهويّات والقيم · 015 الطبقة الرابعة)، و**٨٥ اختباراً**، و**٢٨ فحص بوّابة**.

| ما يعمل | كيف تراه |
|---|---|
| مستند يحمي نفسه بثلاث طبقات | `cargo run -p z_core --example scan_document` |
| القلب كاملاً: أصل ← حِمْل ← جواب ← استعادة | `cargo run -p z_core --example round_trip` |
| الخزنة: مظروف · هويّات · تعارض · قفل | `cargo test -p z_core --test vault_layer` |
| العقد كلّه (٤١ دالّة) من Dart | `cd apps/flutter_app && LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib flutter test` |

**الطبقات الأربع كلّها موجودة الآن**، والترتيب: حساب ← خزنة ← حزمة لغة ← يدك. والملفّ الذهبي مع خزنةٍ تعرف العميل: **٩ auto · ٠ suggest**.

**التالي M5 — المستندات:** txt ثمّ docx ثمّ pdf، ومعها **البوّابة G15** التي كتبتَها ولم تُفعَّل بعد: لا نصّ أصلي على `/tmp` ولا ملفّات وسيطة غير مشفّرة أثناء المعالجة. ورفضُ PDF ممسوح بلا طبقة نصّ بسببه، لا استيرادٌ فارغ.

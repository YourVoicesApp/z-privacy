# من أين جاء كلّ رقم على الشاشة

سؤالك: **«هل هناك أيّ رقم أو حالة أو label لا أستطيع أن أشرح من أين جاء؟»** — وإن لم نعرف مصدره فهو مرشَّح للحذف حتى يثبت العكس.

هذه الورقة جوابه، شاشةً شاشة. اكتُبت بالمشي على كلّ نصّ في `apps/flutter_app/lib` وتتبّعه إلى نداء في العقد. ما لم أستطع تتبّعه **أُصلح**، لا أُدرج.

> القاعدة التي تحكمها: كلّ ما في العمود الأيمن نداءٌ في `z_core::api`. إن وجدتَ في رحلتك رقماً ليس له سطرٌ هنا، فهو الثامنة.

## Home

| ما تراه | مصدره |
|---|---|
| `z_core 0.1.0` | `core_version()` |
| «None / Locked / 124» + سطره | `vault_state()`، والعدّ من `entities(None)` |
| عدد الملفّات | `profiles()` |
| «N connected of M» | `providers()` — `connected` لكلّ صفّ |
| «DE · German (DE) · scan on import» | `settings().pack_id` مقابل `packs()`، والجملة من `settings().scan_on_import` |
| «Conversations are not saved…» | ليس رقماً بل **وصفٌ صحيح**: الـcore لا يحفظ جلسةً بين تشغيلين |

## الشريط العلويّ في Workspace

| ما تراه | مصدره |
|---|---|
| اسم الملفّ وعدد الصفحات | `document_view()` — `name` · `pages` |
| Profile | `session.profile_id` مقابل `profiles()` |
| Pack | `packs()` بالمُعرِّف الذي فُتحت به الجلسة |
| Vault | **`ScanReport.vault`**، لا `vault_state()` — مصدرٌ واحد فلا يتناقض شريطان |

## الشريط تحته

| ما تراه | مصدره |
|---|---|
| «N protected · M need your word · K normal» | `ScanReport.auto` · `.suggested` · `.normal` |
| «Vault locked — rules and pack ran…» | `ScanReport.vault` |

## العمودان

| ما تراه | مصدره |
|---|---|
| نصّ اليسار | `DocumentView.text` — **حرفاً حرفاً**، ومُختبَر بالمقارنة |
| العلامات المملوءة | `DocumentView.marks` بحالة `Protected` |
| العلامات المتموّجة | `DocumentView.marks` بحالة `Suggested` |
| لون الخزنة (أزرق) | `Mark.source == Vault` |
| نصّ اليمين | `PayloadView.text` — **هو الطلب**، ومُختبَر بالمقارنة مع ما يصل الخادم |
| «N values were replaced» | `PayloadView.protected_count` |
| «N suggestions are still open» | `PayloadView.open_suggestions` |

## أشرطة الأفعال

| ما تراه | مصدره |
|---|---|
| حالة زرّ Protect الخمس | `inspect_selection()` — لا تُستنتَج في Dart |
| «Protect all N matches» | `SelectionView.matches` |
| «Already protected as …, from …» | `SelectionView.protected_as` · `protected_by` · `protected_detail` |
| شارة Review | `ScanReport.suggested` — وتختفي عند الصفر، لا تصير صفراً |
| شارة Tokens | `list_tokens().length` |
| كلّ جملة بعد فعل | من `ProtectOutcome` / `UndoOutcome` بأرقامهما |

## المراجعة

| ما تراه | مصدره |
|---|---|
| المجموعات الثلاث | `Finding.state` و**`Finding.decided`** — لا `source` |
| «found by pack / rule / vault» | `Finding.source` |
| «you decided» | `Finding.decided` |
| السبب | `Finding.reason` |
| `Page 3 · ¶7` | `Finding.place` — يحفظه الـcore عبر الحماية |
| «N identities claim it» | `Finding.entities.length` |

## الرموز

| ما تراه | مصدره |
|---|---|
| الرمز | `TokenRow.token` |
| النوع | `kinds()` — **لا `switch` على `Kind` في Dart** |
| المدى | `TokenRow.scope` |
| القيمة المكشوفة ومدّتها | `reveal()` — `value` · `aliases` · `ttl_ms` |

## الجواب · الخزنة · الإعدادات

| ما تراه | مصدره |
|---|---|
| المستعاد | `restored_view()` — `Segment`s تُبنى في Rust |
| كما كتبه النموذج | `ai_view()` |
| قائمة الهويّات | `search_vault()` — يعمل في Rust ويعيد صفوفاً |
| «N identities · M values» | `entities()` وعدد قيم كلٍّ |
| حالة الاعتماد | `ProviderRow.connected` · `session_only` · `credential_required` |
| كلّ إعداد | `settings()`، والحدود من الـcore لا من الشاشة |

## ثلاثة أشياء على الشاشة **ليست** أرقاماً، وتقول عن نفسها ذلك

- **«Token rotation»** و**«My privacy rules»** و**«Device-bound protection»** في الإعدادات: تظهر بأسمائها **وتقول إنّها لم تُبنَ**. مكانٌ محجوز بصراحة، لا ميزةٌ يوحي وجودها بأنّها تعمل.
- **«Interface: Deutsch»** معطَّل ومعه سببه: الترجمة لم تُكتب.
- **الـscopes التي تحتاج خزنة** معطَّلة ومعها سببها حين تكون مقفلة.

## وثمانية أُصلحت قبل أن تصل إليك

| # | ما قالته الشاشة | لماذا لم يُكتشَف |
|---|---|---|
| ١ | «0 suggestions» | كلّ اختبار أجاب المقترحات قبل أن يقيس |
| ٢ | «0 tries left» | لم يطبعه أحد قبل الرحلة |
| ٣ | «Vault unlocked» من مصدرين | لم يقارنهما أحد |
| ٤ | «exactly what will be sent» مع رفض `send` | الرقم الكاذب الأوّل |
| ٥ | مقترحٌ بلا علامة على المستند | `MarkState::Suggested` لا يُنتجها شيء |
| ٦ | Rescan يسحب إجاباتك | `source` و`decided` كانا سؤالاً واحداً |
| ٧ | «Always — kept in the vault» ولا شيء يُكتب | `Scope::Always` لم تكن تُقرأ أصلاً |
| ٨ | «DE · scan on import» مهما كانت الإعدادات | صحيحةٌ اليوم **بالمصادفة** |

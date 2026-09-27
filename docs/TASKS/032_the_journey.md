# ٠٣٢ — الرحلة في عمليّتين، وكذبةٌ ثانية من نفس العائلة

توقّفنا عن الإضافة، كما قلت. وهذه أوّل خطوة من «شغّله كإنسان»: ما أستطيع أنا أن أفعله منه.

## ما لا تستطيع ١٤٨ اختباراً أن تقوله

كلّها تشترك في `Core` واحد داخل عمليّة واحدة. فأُضيف `examples/journey.rs`، يُشغَّل **مرّتين، في عمليّتين**:

```text
cargo run -p z_core --example journey -- <folder> first
cargo run -p z_core --example journey -- <folder> again
```

`first` يصنع خزنة، **يعلّمها عميلاً جديداً بيد** (شركة باسمها المستعار، وشخصاً بلقبه)، يستورد مستنداً ألمانيّاً، يفحصه، يجيب المراجعة، يبني الحِمْل، يتحقّق أنّ لا قيمة أصليّة فيه، **يُعيد الجواب يدويّاً** ويستعيد — ثمّ **تنتهي العمليّة**. و`again` عمليّةٌ جديدة تفتح المجلّد نفسه.

النتيجة:

```text
RUN ONE — a new device
  vault before               Absent
  identities taught          2
  scan                       6 auto · 2 to review · 26 normal
    by GeneralRule 3 · by LanguagePack 1 · by Vault 2
  payload                    361 chars · 8 replaced
  values in the payload      0 (must be 0)
  restored holds the name    true
  vault at the end           Locked

RUN TWO — the same folder, a new process
  vault found                Locked
  wrong passphrase           refused
  opened                     2 identities · 2 values
  settings survived          first_run_done=true language=de session_only=false
  profiles                   1
  search «Herr»              1
  scan after restart         6 auto · 2 to review · 26 normal
```

**الفحص بعد إعادة التشغيل مطابقٌ رقماً برقم**، والطبقة الرابعة تعمل من ملفٍّ قُرئ من القرص. وهذا ما طلبتَه بـ«إعادة تشغيل التطبيق».

## والكذبة الثانية

`VaultUnlockOutcome::WrongPassphrase { attempts_left }` كانت **صفراً دائماً**. لم يلحظها أحد حتى طبعتْها الرحلة:

```text
wrong passphrase   refused · 0 tries left
```

مستخدمٌ أخطأ في الكتابة كان سيقرأ «لم يبقَ لك محاولات» ويظنّ خزنته ضاعت. نفس عائلة `open_suggestions = 0`: **حقلٌ يبدو معلومةً وليس كذلك**.

حُذف الحقل، ولم يُنفَّذ عدّاد محاولات — **لأنّه لا ينبغي أن يوجد**. قفلُ ملفٍّ **محلّيّ** بعد ثلاث محاولات لا يحمي أحداً: مَن يملك الملفّ لا يستعمل نافذتنا؛ بينما إنسانٌ أخطأ الكتابة يُحرَم من خزنته للأبد. وثمن التخمين هو Argon2id بـ٦٤ ميغابايت للمحاولة، وهو دفاعٌ لا يُلتَفّ حوله. والسبب مكتوب فوق النوع.

## يعني «تمّت» أنّ

1. `./scripts/gates.sh ; echo $?` ⇒ `0`. ١٤٨ اختبار Rust + ١٨ Dart.
2. الرحلة تعبر حدّ العمليّة: خزنة وهويّات وملفّات وإعدادات، كلّها تعود.

## ما لا أستطيع أنا فعله، وهو دورك

لا توجد على هذا الجهاز أداة تحريك ماوس (`xdotool` غير مثبّت)، فرأيتُ **Home وFirst Run بعينيّ** فقط؛ بقيّة الشاشات رأيتُها في صور بخطّ الاختبار — التخطيط واضح، النصّ لا. والحكم على ما يحدث حين يجلس إنسان أمامها حكمُك.

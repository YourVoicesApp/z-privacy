# ٠٣٦ — «لماذا حميت هذا؟» والنسيان الذي يعني النسيان

سؤالك التاسع، وقاعدة المرحلة التي وضعتها:

> **كلّ ما يتعلّمه Z Privacy من المستخدم يجب أن يكون مرئيّاً، قابلاً للتفسير، قابلاً للتعديل، وقابلاً للنسيان.**

## ١ · «Source: Vault» صحيحةٌ تقنيّاً ولا تجيب إنساناً

صار في العقد `explain(session, span)`، والجواب جملةٌ لا تصنيف:

```text
You taught Z Privacy this value
  your vault knows this, under CLIENT #3
  Kept in your vault since 28 Sep 2026

What it is        Company
Where it applies  Everywhere
Decided by        You
Taught on         28 Sep 2026
Token             __Z_7B2C_COMPANY_D41__
▸ 1 other spelling
```

والعناوين الأربعة كما كتبتَها: «You taught this value» · «A German privacy rule» · «You protected this by hand» · «A shape that needs no language» — ومعها «X rules agree» حين تتّفق طبقتان. والاتّفاق صار **قائمةً** في `Candidate.also` لا جملةً تُقرأ بالتحليل: جوابٌ لا يُستخرَج من نصّ.

**والقاعدة اختباراً:** الاختبار يمشي على **كلّ** علامة محميّة في مستندٍ فيه الأربعة، ويطلب من كلٍّ عنواناً وسبباً ومكاناً. لا حماية لا تستطيع أن تقول من أين جاءت.

والتهجئات الأخرى تنتظر أن تُطلَب — نفس عادة كلّ قيمة في هذا التطبيق. مكتوبٌ في الاختبار أنّها ليست على الشاشة قبل الضغط.

## ٢ · «Taught on» احتاج تاريخاً

`ValueRecord.learned_at` (موديل ٤). و**غير المعروف صفرٌ، لا تاريخ اليوم مخمَّناً** — قيمةٌ عُلِّمت قبل أن تحفظ الخزنة التواريخ تقول «لا أعرف».

> وهنا سقط اختباران قديمان بطريقة تستحقّ الذكر: كانا يصنعان «ملفّاً قديماً» بقصّ ذيل بايتات اليوم. الحيلة تعمل ما دام كلّ تغيير إضافةً في النهاية؛ وموديل ٤ وضع ثماني بايتات **داخل** كلّ قيمة، فصار القصّ يختبر حسابياً لا توافقاً. الآن يُكتَب الملفّ القديم **حقلاً حقلاً** كما كتبه البناء الذي صنعه، وتُفتَح **كلّ** الموديلات في حلقةٍ واحدة.

## ٣ · Forget يعني Forget

```text
Forget «Nordstern Consulting GmbH»?

THIS WILL REMOVE
  ✕ 1 protected value
  ✕ 2 spellings
  ✕ 1 identity left holding nothing

IT WILL NOT CHANGE
  – Documents you have already protected keep their tokens
  – Answers you have already received are unchanged
  – Nothing else on this device knows this value

[Cancel]  [Forget everywhere]
```

**دالّة واحدة تحسب الخطّة وتنفّذها** (`plan(.., act: bool)`) — فلا تَعِد الورقة بشيء ويفعل الزرّ غيره.

و`ForgetPlan.still_known_by` هو الإثبات لا الادّعاء: قائمة ما **سيبقى** يعرفها. قبل الفعل هي ما سيُحذَف؛ **بعده يجب أن تكون فارغة**، والواجهة تقول للمستخدم إن لم تكن بدل أن تطمئنه.

**وسلسلة التحكّم:** الاختبار يفحص قبل النسيان أنّ طبقة الخزنة تجد القيمة فعلاً — ثمّ بعده أنّها لا تجدها. نفيٌ بعد إثبات.

و«انسَ هنا» لا تمسّ عميلاً آخر تعلّم نفس القيمة بنفسه: `forget_plan(.., everywhere: false)` يبقى داخل ملفّه، ويقول ذلك في «It will NOT change». هذا هو `Scope::Profile` مُختبَراً من الطرف الآخر.

## ٤ · My Privacy Rules — ثلاث مجموعات، واحدةٌ منها موجودة

```text
WHAT Z PRIVACY HAS LEARNED FROM YOU
  3   Values I taught       names, companies, numbers
  —   Rules I taught        not built yet · «after Projekt-Nr. → project code»
  —   Exceptions I taught   not built yet · «after Rechnungsnummer, not a phone»
```

المجموعتان غير المبنيّتين **تظهران بأسمائهما وتقولان إنّهما لم تُبنيا**. شاشةٌ تعرض «Values I taught» وحدها توحي بأنّ القيم هي كلّ ما يتعلّمه هذا التطبيق، ويوم تصل القواعد لا يعرف أحدٌ أين ذهبت.

## يعني «تمّت» أنّ

1. `./scripts/gates.sh ; echo $?` ⇒ `0`. **١٦٨ اختبار Rust + ٢١ Dart**.
2. كلّ علامة محميّة في مستندٍ بأربعة مصادر تشرح نفسها — مُختبَرٌ بالمرور عليها كلّها، لا بعيّنة.
3. النسيان يُري كلفته أوّلاً، وينفّذ ما أراه بالضبط، **ثمّ يثبت أنّ لا شيء يعرفها**.
4. G17 أمسكت نفسها: العقد صار ٥٧ واختبار Dart عند ٥٤ — وهي البوّابة المكتوبة لهذا بالذات.

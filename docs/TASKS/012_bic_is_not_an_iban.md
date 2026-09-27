# 012 · الـBIC ليس IBAN

**المرحلة:** تصحيح قبل M4 · **الحالة:** تمّت

## ما لاحظتَه
```
BIC: __Z_2D9C_IBAN_C6A7__
```
نوعٌ دلاليٌّ خاطئ داخل الرمز — وهو لا يبقى هناك: يسافر إلى `Finding.kind`، وإلى لوحة Tokens، وإلى أيّ تحليل لاحق.

## ما دخل
نوعان صادقان بدل واحدٍ كاذب:
- `Kind::Bic` ⇒ `__Z_…_BIC_…__` — معرّف بنك (SWIFT/BIC)، لا حساب.
- `Kind::Account` ⇒ `__Z_…_ACCOUNT_…__` — رقم حساب كما يكتبه خطابٌ ألماني بعد `Kontonummer:`، وهو أيضاً لم يكن IBAN.

الحزمة الألمانية عُدّلت: `bic` → `Bic`، و`kontonummer`/`konto` → `Account`، و`iban` وحدها تبقى `Iban`.

## «تمّ» يعني
- الملفّ الذهبي: مجموعة السبعة صارت `Bic · CustomerNo · Email · Iban · Phone · TaxId · TaxId`، والاختبار يؤكّد أنّ رمز `_IBAN_` واحدٌ لا اثنان، وأنّ هناك رمز `_BIC_` واحداً.
- ومن Dart: اختبار يتأكّد أنّ `Kind.bic` يصل إلى الواجهة وأنّ الرمز يحمل `_BIC_`.
- الجسر ومرايا Dart أُعيد توليدها، و`contract_test.dart` كبر: لم يبقَ يتوقّع `NotImplemented` من الجميع (فذلك صار كذباً بعد M3)، بل **يُثبت G7 مباشرة**: كلّ نداء يُجيب بقيمة أو بخطأٍ مكتوب، وما ليس مبنيّاً يُطبَع قائمةً —
  `still NotImplemented (8): [vaultState, vaultUnlock, vaultLock, profiles, switchProfile, switchPack, providers, testProvider]`
- وأضيف اختبار Dart ثالث: **مستند يحمي نفسه من الواجهة** — ٣ auto · ١ suggest، والإرسال مرفوض بمقترحٍ مفتوح، ثمّ يصل إلى باب المزوّد بعد الإجابة.

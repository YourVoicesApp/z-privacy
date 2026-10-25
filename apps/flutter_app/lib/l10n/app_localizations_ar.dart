// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get theKeyIsBehindTheLockedVault =>
      'لا يستطيع Z Privacy الوصول إلى مفتاح والخزنة مقفلة. افتح الخزنة، أو أعطِ مفتاحاً يبقى ما دام التطبيق مفتوحاً.';

  @override
  String get theChatKeepsNothing =>
      'هذا الجواب على شاشتك ولا في مكان آخر: لا جلسة مفتوحة تحفظه، فإغلاق التطبيق ينهيه مع المحادثة.';

  @override
  String get theTokenIsAlreadyOurs => 'هذا محميٌّ أصلاً — Z وضعه هنا.';

  @override
  String get unnamedTrouble => 'حدث خطأ. لم يُكمل Z Privacy العمل.';

  @override
  String exactlyWhatWouldLeave(int replaced) {
    return 'هذا ما يخرج من وثيقتك — وداخل التطبيق يسافر معه التبادل الذي قبله. استُبدلت $replaced قيمة.';
  }

  @override
  String get noLanguageAndASessionIsOpen =>
      'لم يُقرأ شيء. يُقرأ النصّ بعادات لغةٍ واحدة، وهذه الجلسة لم تُعطَ لغةً قطّ — فلم يختر Z Privacy مكانك. أعِدْ قراءته وأجب، أو أعطِ الجلسة لغتها في الإعدادات.';

  @override
  String get noLanguageAndNoSession =>
      'لم يُقرأ شيء. يُقرأ النصّ بعادات لغةٍ واحدة، ولم تُختَر لغة — فلم يُقرأ شيءٌ ولم تُصنع جلسة. حاول مرّةً أخرى واختر لغة.';

  @override
  String get troubleNotImplemented => 'هذا الجزء من Z Privacy لم يُبنَ بعد.';

  @override
  String get troubleInvalidSession =>
      'تلك الجلسة لم تبقَ مفتوحة. ابدأ جلسةً جديدة.';

  @override
  String get troubleInvalidHandle =>
      'هذا الطلب لم يبقَ الطلبَ الحاليّ. راجع النصّ مرّةً أخرى قبل الإرسال.';

  @override
  String get troubleStalePayload =>
      'تغيّرت الوثيقة بعد تحضير هذا الطلب. راجعها مرّةً أخرى، ليكون ما تُرسله هو ما رأيته آخراً.';

  @override
  String get troubleVaultLocked => 'خزنتك مقفلة. افتحها لتستفيد بما تعرفه.';

  @override
  String get troubleVaultRequired =>
      'افتح خزنتك أو أنشئها قبل حفظ هذا للاستعمال لاحقاً.';

  @override
  String get troubleVaultAuthenticationFailed =>
      'لم تُفتح الخزنة. قد تكون عبارة المرور خطأً، أو تكون الخزنة تالفةً أو مُعدَّلة.';

  @override
  String get troubleUnsupportedKdfParameters =>
      'هذه الخزنة تستعمل إعدادات أمانٍ غير مدعومة.';

  @override
  String get troubleTrailingVaultData =>
      'ملفّ هذه الخزنة يحمل بياناتٍ زائدةً بعد نهايته، فلم يُفتح.';

  @override
  String get troubleProviderUnavailable =>
      'ذلك المزوّد غير متوفّر في هذه النسخة.';

  @override
  String get oneWordWaits => 'كلمةٌ واحدة تنتظر كلمتك — ولم يخرج شيءٌ من Z.';

  @override
  String wordsWait(int count) {
    return '$count كلمة تنتظر كلمتك — ولم يخرج شيءٌ من Z.';
  }

  @override
  String get troubleVaultAbsent =>
      'لا خزنة على هذا الجهاز بعد. أنشئ واحدةً لتحفظ شيئاً للغد.';

  @override
  String get troubleVaultAlreadyExists =>
      'توجد خزنةٌ على هذا الجهاز، ولن يكتب Z Privacy فوقها.';

  @override
  String troubleStorageRefused(String reason) {
    return 'لن يستعمل Z Privacy ذلك المكان — $reason';
  }

  @override
  String get everyCellWasAlreadyProtected =>
      'كلّ خليّةٍ في ذلك العمود كانت محميّةً أصلاً.';

  @override
  String protectedOneCell(String token) {
    return 'حُمِيت خليّةٌ واحدة، كـ$token.';
  }

  @override
  String protectedCellsDownTheColumn(int places, String token) {
    return 'حُمِيت $places خليّة في ذلك العمود، أوّلها كـ$token.';
  }

  @override
  String protectedAs(String token) {
    return 'حُمِيت كـ$token.';
  }

  @override
  String protectedAsInPlaces(String token, int places) {
    return 'حُمِيت كـ$token، في $places موضعاً.';
  }

  @override
  String alreadyProtectedBy(String token, String who) {
    return 'محميّةٌ أصلاً كـ$token، بواسطة $who.';
  }

  @override
  String belongsToEntity(String entity, String token) {
    return 'هذه تنتمي إلى $entity وتحفظ رمزها $token.';
  }

  @override
  String pressCutsIntoProtectedTextOne(String what) {
    return '$what يقطع في نصٍّ محميّ، فلم يتغيّر شيء. كان سيتّسع إلى عنصرٍ كاملٍ واحد.';
  }

  @override
  String pressCutsIntoProtectedTextMany(String what, int items) {
    return '$what يقطع في نصٍّ محميّ، فلم يتغيّر شيء. كان سيتّسع إلى $items عنصراً كاملاً.';
  }

  @override
  String get theSelection => 'التحديد';

  @override
  String get thatCell => 'تلك الخليّة';

  @override
  String get thatPlace => 'ذلك الموضع';

  @override
  String get sourceRule => 'قاعدة';

  @override
  String get sourcePack => 'حزمة';

  @override
  String get sourceVault => 'الخزنة';

  @override
  String get sourceYou => 'أنت';

  @override
  String get answeredByHand => 'أُرجِع باليد';

  @override
  String get answeredNotRecorded => 'غير مُسجَّل';

  @override
  String get oneNameCameBack => 'عاد اسمٌ واحد.';

  @override
  String namesCameBack(int count) {
    return 'عاد $count اسماً.';
  }

  @override
  String oneNameCameBackFrom(String sessions) {
    return 'عاد اسمٌ واحد من $sessions.';
  }

  @override
  String namesCameBackFrom(int count, String sessions) {
    return 'عاد $count اسماً من $sessions.';
  }

  @override
  String thisDocumentCameBackFrom(String sessions) {
    return 'عادت هذه الوثيقة من $sessions.';
  }

  @override
  String get oneNameIsStillATokenVaultShut =>
      'اسمٌ واحد لا يزال رمزاً: افتح خزنتك أو أنشئها ليبحث Z عنه.';

  @override
  String namesAreStillTokensVaultShut(int count) {
    return '$count اسماً لا تزال رموزاً: افتح خزنتك أو أنشئها ليبحث Z عنها.';
  }

  @override
  String get oneNameStaysATokenTwoCauses =>
      'اسمٌ واحد يبقى رمزاً، ولذلك سببان مختلفان: إمّا أنّ الكلمة حُمِيت قبل أن يبدأ Z Privacy بحفظ كلّ كلمةٍ محميّة، وإمّا أنّ هذا الرمز تغيّر بعد خروج الملفّ. افتح تلك الوثيقة في جلستها واحمِ الاسم مرّةً أخرى — فإن عاد من حينها فالسبب الأوّل، وإن لم يعد فهذا الملفّ ليس الذي كتبه Z Privacy.';

  @override
  String namesStayTokensTwoCauses(int count) {
    return '$count اسماً تبقى رموزاً، ولذلك سببان مختلفان: إمّا أنّها حُمِيت قبل أن يبدأ Z Privacy بحفظ كلّ كلمةٍ محميّة، وإمّا أنّ الرموز تغيّرت بعد خروج الملفّ. افتح تلك الوثائق في جلستها واحمِ الأسماء مرّةً أخرى — فإن عادت من حينها فالسبب الأوّل، وإن لم تعد فهذا الملفّ ليس الذي كتبه Z Privacy.';
  }

  @override
  String get refusalMalformedDocument => 'هذه الوثيقة تالفةٌ أو ناقصة.';

  @override
  String get refusalEncryptedPdf =>
      'ملفّ PDF هذا محميٌّ بكلمة سر. أزِل كلمة السر وحاول مرّةً أخرى.';

  @override
  String get refusalScannedOnePage =>
      'ملفّ PDF هذا صورةُ صفحةٍ لا نصَّ فيها، فلم يُقرأ شيء — ولن يُدخِل Z Privacy وثيقةً لا يراها.';

  @override
  String refusalScannedPages(int pages) {
    return 'ملفّ PDF هذا $pages صفحةً من الصور لا نصَّ فيها، فلم يُقرأ شيء.';
  }

  @override
  String refusalUnsupportedEncoding(int readablePercent, int page) {
    return 'لم يُفكَّ إلى محارف إلّا $readablePercent% من الصفحة $page، فهذه الوثيقة مرفوضةٌ بدلاً من أن تُقرأ نصفها. افتحها واحفظها نصّاً، أو ألصِق النصّ.';
  }

  @override
  String refusalUnreadableStructure(int page) {
    return 'الصفحة $page مبنيّةٌ على نحوٍ لا تقرأه هذه النسخة.';
  }

  @override
  String refusalDocumentTooLarge(int mib, int limitMib) {
    return 'حجم هذا الملفّ نحو $mib MiB، وZ Privacy يفتح وثائق حتّى $limitMib MiB.';
  }

  @override
  String refusalTooManyPages(int pages, int limit) {
    return 'في هذه الوثيقة $pages صفحة، وZ Privacy يفتح حتّى $limit في وثيقةٍ واحدة.';
  }

  @override
  String refusalTextTooLarge(int limitMib) {
    return 'بعد فكّ الضغط، جزءٌ من هذا الملفّ أكبر من $limitMib MiB — أكبر ممّا يقرأه Z Privacy في وثيقةٍ واحدة، فلم يُدخَل منه شيء.';
  }

  @override
  String refusalCompressionBomb(int ratio) {
    return 'جزءٌ من هذا الملفّ يُفكّ إلى أكثر من $ratio ضعفاً من الحجم الذي يشغله. لا تفعل ذلك وثيقةٌ حقيقيّة، فأوقف Z Privacy فكَّه بدلاً من أن يملأ الجهاز.';
  }

  @override
  String refusalTooManyParts(int parts, int limit) {
    return 'يُدرِج هذا الملفّ $parts جزءاً داخله، وللوثيقة عشراتٌ لا آلاف — وZ Privacy يفتح حتّى $limit.';
  }

  @override
  String refusalTookTooLong(int seconds) {
    return 'كانت قراءة هذا الملفّ ما زالت جاريةً بعد $seconds ثانية، فأوقفها Z Privacy. ولم يُدخَل منه شيء.';
  }

  @override
  String get refusalEmptyDocument => 'لا نصَّ في هذا الملفّ ليحميَه Z Privacy.';

  @override
  String get networkNotConnected =>
      'لا مزوّد ذكاءٍ اصطناعيٍّ موصول. أضِف عنواناً ومفتاحاً أوّلاً.';

  @override
  String get networkInsecureUrl => 'ذلك العنوان غير آمنٍ للإرسال إليه.';

  @override
  String get networkRedirected =>
      'أحالنا ذلك العنوان إلى مكانٍ آخر. ولا يتبع Z Privacy الإحالات بنصّك، فلم يُرسَل شيء.';

  @override
  String networkBadStatus(int status) {
    return 'رفض المزوّد الطلب بالحالة $status. ولم يحفظ Z Privacy شيئاً من وثيقتك.';
  }

  @override
  String get networkTimeout => 'لم يُجب المزوّد في الوقت. ولم يُرسَل شيءٌ آخر.';

  @override
  String networkResponseTooLarge(int limitKib) {
    return 'كان الجواب أكبر من $limitKib KiB فلم يُقرأ.';
  }

  @override
  String networkPayloadTooLarge(int kib, int limitKib) {
    return 'حجم هذا النصّ $kib KiB، والمزوّد يقبل $limitKib KiB في طلبٍ واحد.';
  }

  @override
  String get networkUnreadable => 'أجاب المزوّد بشيءٍ ليس جواباً.';

  @override
  String get networkUnreachable =>
      'لم يُمكن الوصول إلى ذلك العنوان أصلاً — لم يُجب شيء. تأكّد أنّك متّصلٌ بالإنترنت وأنّ العنوان صحيح. ولم يُرسَل شيء.';

  @override
  String get troubleVaultChangedElsewhere =>
      'نسخةٌ أخرى من Z Privacy غيّرت هذه الخزنة. أغلِق تلك النافذة، أو اقفل هنا وافتح لتأخذ عملها.';

  @override
  String get troubleSessionChangedElsewhere =>
      'ملفُّ هذه الجلسة على قرصك لم تكتبه هذه النافذة، فلم يكتب Z Privacy فوقه. أغلِق النسخة الأخرى، أو اقفل هنا وافتح لتقرأ ما كتبته.';

  @override
  String troubleStoragePermissionsKept(String reason) {
    return 'لن يغيّر Z Privacy صلاحيّةً ضبطتَها أنت، فلم يُحفظ شيء — $reason. غيّر الصلاحيّة بنفسك، أو اختر مجلّداً آخر.';
  }

  @override
  String get troubleBadSpan =>
      'لم يُمكن قراءة ذلك التحديد. حاول تحديد الكلمات مرّةً أخرى.';

  @override
  String get troubleBetweenColumns =>
      'وقعت تلك الضغطة في الفراغ بين عمودين، فلا تسمّي قيمة — ولن يختار Z Privacy عموداً مكانك.';

  @override
  String get troubleUnknownToken => 'تلك القيمة المحميّة ليست في هذه الجلسة.';

  @override
  String get troubleNothingToSend =>
      'لا شيء للإرسال بعد. أدخِل وثيقةً أو اكتب نصّاً.';

  @override
  String get troubleSessionWithoutItsDocument =>
      'لم تبدأ الجلسة، لأنّ Z Privacy لم يعرف أيَّ وثيقةٍ فتحتَ — والجلسة عليها أن تُعيد تسمية ما هو محميٌّ فيها أصلاً. لم يتغيّر شيء. افتح الوثيقة وابدأ الجلسة من هناك.';

  @override
  String get troublePayloadAlreadySent =>
      'أُرسل هذا الطلب مرّةً. حضِّره مرّةً أخرى لترسله ثانيةً.';

  @override
  String get theReasonWasNotReported => 'لم يُذكر السبب.';

  @override
  String get carriesFirst => 'هذه الوثيقة تحمل';

  @override
  String get carriesAlso => 'وتحمل أيضاً';

  @override
  String carriesOneNameFromElsewhere(String also, String which) {
    return '$also اسماً واحداً من جلسةٍ لا تحملها هذه الخزنة ($which). ولا شيء هنا يستطيع إرجاعه: المفتاح الذي صنعه ليس في هذه الخزنة.';
  }

  @override
  String carriesNamesFromOneSessionElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count اسماً من جلسةٍ لا تحملها هذه الخزنة ($which). ولا شيء هنا يستطيع إرجاعها: المفتاح الذي صنعها ليس في هذه الخزنة.';
  }

  @override
  String carriesNamesFromSessionsElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count اسماً من جلساتٍ لا تحملها هذه الخزنة ($which). ولا شيء هنا يستطيع إرجاعها: المفاتيح التي صنعتها ليست في هذه الخزنة.';
  }

  @override
  String carriesNamesFromElsewhereWithNoCount(
    String also,
    String whose,
    String which,
    String keys,
  ) {
    return '$also أسماءً من $whose ($which). ولا شيء هنا يستطيع إرجاعها: $keys في هذه الخزنة.';
  }

  @override
  String get aSessionThisVaultDoesNotHold => 'جلسةٍ لا تحملها هذه الخزنة';

  @override
  String get sessionsThisVaultDoesNotHold => 'جلساتٍ لا تحملها هذه الخزنة';

  @override
  String get theKeyThatMadeThemIs => 'المفاتيح التي صنعتها ليست';

  @override
  String get andBetweenNames => ' و';

  @override
  String get thisLanguageName => 'العربية';

  @override
  String get languageWord => 'اللغة';

  @override
  String get chooseALanguage => 'اختر لغةً للمتابعة.';

  @override
  String get noAccount => 'لا حساب.';

  @override
  String get noAds => 'لا إعلانات.';

  @override
  String get noAnalytics => 'لا تحليلات.';

  @override
  String get noZPrivacyServer => 'لا خادم لـZ Privacy.';

  @override
  String get originalDataStaysHere =>
      'تبقى بياناتك الأصلية على هذا الجهاز ما لم تنسخ المحتوى المستعاد صراحةً.';

  @override
  String get onlyTheProtectedVersionIsSent =>
      'لا تُرسَل إلى الذكاء الاصطناعي عبر Z Privacy إلّا النسخةُ المحميّة.';

  @override
  String get theseRulesWillBeEnabled => 'ستُفعَّل قواعد الخصوصية العربية.';

  @override
  String get start => 'ابدأ';

  @override
  String get yourVault => 'خزنتك';

  @override
  String get createAVault => 'أنشئ خزنة';

  @override
  String get vaultWhy =>
      'كلُّ كلمةٍ تحميها تعيش هنا، ما بقيت هذه الخزنة لك: الأسماء التي تضيفها، والقيم التي تعلّمها، ومفاتيح أيّ ذكاءٍ اصطناعيٍّ تصله. تبقى على هذا الحاسوب، ولا يُكتب شيءٌ في أيّ مكانٍ آخر.';

  @override
  String get onePassphrase =>
      'عبارةُ مرورٍ واحدة، تبقى على هذا الجهاز. وكلُّ ما يتعلّمه Z وأنت تعمل — أسماؤك، وقوائمك، وقراراتك — يُحفظ فيها.';

  @override
  String get byYourVoices => 'من YourVoices';

  @override
  String pageHasNothingMarked(int page) {
    return 'الصفحة $page لا تحمل شيئاً وسمه الفحص.';
  }

  @override
  String get addADocumentPdfWordOrText => 'أضِف وثيقة — PDF أو Word أو نصّاً';

  @override
  String get addADocumentOrWriteToTheAi =>
      'أضِف وثيقة — أو اكتب إلى الذكاء الاصطناعي في الجزء الأوّل، بلا وثيقةٍ أصلاً.';

  @override
  String get originalLocalOnly => 'الأصل — محلّيٌّ فقط';

  @override
  String get neverSentToAiSendCannotRead =>
      'لا يُرسَل إلى الذكاء الاصطناعي أبداً · الإرسال لا يقرأ هذا الجانب';

  @override
  String get yourDocumentArrivesHere =>
      'تصل وثيقتك هنا كما هي مكتوبة. ولا شيء في هذا الجانب يستطيع الوصول إلى الشبكة.';

  @override
  String get safeAiWillReceive => 'المحميّ — هذا ما سيتلقّاه الذكاء الاصطناعي';

  @override
  String get theRequestItselfNotAPreview => 'الطلب نفسه، لا معاينةً له';

  @override
  String get whatAnAiWouldReceiveStandsHere =>
      'ما سيتلقّاه الذكاء الاصطناعي يقف هنا بجانب الأصل، كلمةً بكلمة، قبل أن يُرسَل أيُّ شيء.';

  @override
  String get theChatTitle => 'المحادثة';

  @override
  String get yourQuestionsAndWhatCameBack => 'أسئلتك، وما عاد منها';

  @override
  String get theChatOpensHereWithTheFirstAnswer =>
      'تُفتح المحادثة هنا بالجواب الأوّل، وكلُّ سؤالٍ بعده يحمل التبادل الذي قبله.';

  @override
  String get typedText => 'نصٌّ مكتوب';

  @override
  String get onePage => 'صفحةٌ واحدة';

  @override
  String pagesCount(int pages) {
    return '$pages صفحة';
  }

  @override
  String get vaultLabel => 'الخزنة';

  @override
  String get vaultIsUnlocked => 'مفتوحة';

  @override
  String get vaultIsLocked => 'مقفلة';

  @override
  String get vaultIsNone => 'لا خزنة';

  @override
  String get yourVaultIsIn => 'خزنتك في';

  @override
  String get aVaultHereWouldBeIn => 'خزنةٌ هنا ستكون في';

  @override
  String get openZVault => 'افتح خزنة Z';

  @override
  String get lockNow => 'اقفل الآن';

  @override
  String get openZVaultOrLockItNow => 'افتح خزنة Z، أو اقفلها الآن';

  @override
  String get goToAPage => 'اذهب إلى صفحة';

  @override
  String pageNumber(int page) {
    return 'الصفحة $page';
  }

  @override
  String get pageWord => 'صفحة';

  @override
  String get chooseTheAiAndWhatTravels =>
      'اختر الذكاء الاصطناعي وما يسافر إليه';

  @override
  String get readThisDocumentWithAnotherRuleSet =>
      'اقرأ هذه الوثيقة بمجموعة قواعد أخرى';

  @override
  String get generalRulesOnly => 'القواعد العامّة فقط';

  @override
  String get packLabel => 'الحزمة';

  @override
  String packWithGeneralRules(String pack) {
    return '$pack · القواعد العامّة';
  }

  @override
  String get everywhere => 'في كل مكان';

  @override
  String get profile => 'ملف شخصي';

  @override
  String get profiles => 'الملفّات الشخصية';

  @override
  String get chooseWhichClientDictionary =>
      'اختر قاموس العميل الذي تستعمله هذه الجلسة. معرّف الملفّ الشخصيّ يبقى داخل الخزنة؛ والاسم المعروض هو ما يراه الناس.';

  @override
  String get onlyIdentitiesForEveryProfile =>
      'الهويّات والقواعد التي تنطبق على كلّ ملفٍّ شخصيٍّ فقط.';

  @override
  String get createProfile => 'أنشئ ملفاً شخصيّاً';

  @override
  String get done => 'تمّ';

  @override
  String get rename => 'أعِد التسمية';

  @override
  String get profileActive => 'نشط';

  @override
  String get profileSwitch => 'بدِّل';

  @override
  String get readItBack => 'أعِد قراءته';

  @override
  String get scanning => 'جارٍ الفحص…';

  @override
  String get notScannedYet => 'لم يُفحص بعد';

  @override
  String get asItWasKept => 'كما حُفظ';

  @override
  String lastScanNote(String note) {
    return 'آخر فحص: $note';
  }

  @override
  String get scannedAsYouTyped => 'فُحص وأنت تكتب';

  @override
  String get scannedOnImport => 'فُحص عند الإدخال';

  @override
  String get lastScanManualRescan => 'آخر فحص: إعادة فحصٍ باليد';

  @override
  String alreadyProtectedNothingScanned(int marks) {
    return '$marks محميّةٌ أصلاً · لم يُفحص شيءٌ في هذه المرّة';
  }

  @override
  String protectedAutomaticallyNeedYourWord(int auto, int open, int normal) {
    return '$auto محميّةٌ تلقائيّاً · $open تنتظر كلمتك · $normal عاديّة';
  }

  @override
  String get vaultLockedRulesAndPackRan =>
      'الخزنة مقفلة — عملت القواعد والحزمة، ولم تعمل طبقة الخزنة';

  @override
  String get noVaultNothingRecognisedByName => 'لا خزنة — لا شيء يُعرَف بالاسم';

  @override
  String get unlock => 'افتح';

  @override
  String get removeTheDocument => 'أزِل الوثيقة';

  @override
  String get nothingIsOpen => 'لا شيء مفتوح.';

  @override
  String get thereIsNothingToSendYet => 'لا شيء للإرسال بعد.';

  @override
  String get readingWhatThoseLinesHold => 'جارٍ قراءة ما تحمله تلك السطور…';

  @override
  String oneLineProtectedOpen(int protected, int open) {
    return 'سطرٌ واحد · $protected محميّةٌ فيه · $open تنتظر';
  }

  @override
  String linesProtectedOpen(int lines, int protected, int open) {
    return '$lines سطراً · $protected محميّةٌ فيها · $open تنتظر';
  }

  @override
  String get pressAValueToProtectEveryHeldLine =>
      'اضغط قيمةً لتحميَ الخليّة نفسها في كلّ سطرٍ محفوظ.';

  @override
  String get letTheLinesGo => 'أطلِق السطور';

  @override
  String get inStep => 'متزامنان';

  @override
  String get apart => 'منفصلان';

  @override
  String get drawnAsChips => 'شرائح';

  @override
  String get drawnPlain => 'عاديّ';

  @override
  String get oneSuggestionStillOpen =>
      'اقتراحٌ واحد ما زال مفتوحاً. وإلى أن تجيبه يقف هنا كما كُتب — نصٌّ حقيقيٌّ في هذا الجانب.';

  @override
  String suggestionsStillOpen(int open) {
    return '$open اقتراحاً ما زالت مفتوحة. وإلى أن تجيبها تقف هنا كما كُتبت — النصُّ الحقيقيُّ الوحيد في هذا الجانب.';
  }

  @override
  String get chooseWhoAnswers => 'اختر من يُجيب';

  @override
  String get showTheChat => 'أظهِر المحادثة';

  @override
  String get whatWouldYouLikeToAskTheAi =>
      'ما الذي تريد أن تسأله الذكاءَ الاصطناعيّ؟';

  @override
  String get whatShouldTheAiDoWithThis =>
      'ما الذي تريد من الذكاء الاصطناعي أن يفعله بهذا؟';

  @override
  String get askAQuestionOrPasteALetter =>
      'اسأل سؤالاً، أو ألصِق رسالةً كاملةً هنا.';

  @override
  String get reconcileSectionAgainstSection =>
      'قابِلْ القسم A بالقسم B وأخبرني أين الاختلاف.';

  @override
  String get inWhatWillLeave => 'في ما سيخرج';

  @override
  String get addItToWhatWillLeave => 'أضِفه إلى ما سيخرج';

  @override
  String get aDocumentCanBeSentWithNoRequest =>
      'يمكن إرسال وثيقةٍ بلا طلب، وحينها لا يُعطى النموذجُ أيَّ تعليمات';

  @override
  String get takeItOut => 'أخرِجه';

  @override
  String get yourRequestNothingToProtect =>
      'طلبك في العمود المحميّ، ولا شيء فيه ليُحمى.';

  @override
  String get yourRequestOneValueReplaced =>
      'طلبك في العمود المحميّ، وقيمةٌ واحدة فيه مُستبدَلة.';

  @override
  String yourRequestValuesReplaced(int count) {
    return 'طلبك في العمود المحميّ، و$count قيمة فيه مُستبدَلة.';
  }

  @override
  String get oneRequestAtATime =>
      'طلبٌ واحد في المرّة — سؤالٌ جديد يحلّ محلّ هذا، والمحادثة تحفظ كلّ تبادل.';

  @override
  String get oneQuestionLeftGoToIt => 'بقي سؤالٌ واحد — اذهب إليه';

  @override
  String questionsLeftGoToTheFirst(int open) {
    return 'بقي $open سؤالاً — اذهب إلى أوّلها';
  }

  @override
  String get protectIt => 'احمِها';

  @override
  String get leaveItInTheClear => 'اتركها ظاهرة';

  @override
  String theOneLeftIsKind(String kind) {
    return 'الباقية $kind.';
  }

  @override
  String get showWhatTheAiWillReceive => 'أظهِر ما سيتلقّاه الذكاء الاصطناعي';

  @override
  String get hideThisColumn => 'أخفِ هذا العمود';

  @override
  String get narrowThisPanel => 'ضيِّق هذه اللوحة';

  @override
  String get widenThisPanel => 'وسِّع هذه اللوحة';

  @override
  String get oneExchangeCarriedIntoTheNext =>
      'تبادلٌ واحد، يُحمل إلى السؤال التالي.';

  @override
  String exchangesCarriedIntoTheNext(int count) {
    return '$count تبادلاً، تُحمل إلى السؤال التالي.';
  }

  @override
  String get putTheChatAwayItIsNotEnded => 'اطوِ المحادثة — ولم تنتهِ';

  @override
  String get theFirstAnswerOpensTheChatHere =>
      'الجوابُ الأوّل يفتح المحادثة هنا. وكلُّ سؤالٍ بعده يحمل التبادلَ الذي قبله — لا المحادثةَ كلَّها، ولا الوثيقةَ مرّةً أخرى.';

  @override
  String get askSomethingElseAboutThis => 'اسأل شيئاً آخر عن هذا…';

  @override
  String get pasteTheAnswerYouWereGiven => 'ألصِق الجواب الذي أُعطيته…';

  @override
  String get addItToTheChat => 'أضِفه إلى المحادثة';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get copyTheChat => 'انسخ المحادثة';

  @override
  String get addAnAnswer => 'أضِف جواباً';

  @override
  String get endTheChat => 'أنهِ المحادثة';

  @override
  String get theChatIsOnYourClipboard =>
      'ما سيخرج في حافظتك، محميّاً — السؤالُ كما يتلقّاه الذكاءُ الاصطناعيّ. أرجِعِ الجوابَ بـ«أضِف جواباً».';

  @override
  String get couldNotReadTheClipboard => 'لم يستطع Z Privacy قراءة الحافظة.';

  @override
  String get thereIsNoTextOnTheClipboard => 'لا نصَّ في الحافظة.';

  @override
  String get hideTheText => 'أخفِ النصّ';

  @override
  String get showTheText => 'أظهِر النصّ';

  @override
  String get theTextWithYourNamesBack => 'النصّ، وأسماؤك فيه — على هذا الجهاز';

  @override
  String get thisAnswerCarriesOneUnknownToken =>
      'هذا الجواب يحمل رمزاً واحداً لا تعرفه هذه الجلسة — صُنع في جلسةٍ أخرى.';

  @override
  String thisAnswerCarriesUnknownTokens(int count) {
    return 'هذا الجواب يحمل $count رمزاً لا تعرفها هذه الجلسة — صُنعت في جلسةٍ أخرى.';
  }

  @override
  String get copyRestored => 'نسخ النص المستعاد';

  @override
  String get theMarkedWordsWerePutBackHere =>
      'الكلماتُ الموسومة أُرجعت هنا، على هذا الجهاز. ولم يرَها النموذج قطّ.';

  @override
  String get theDottedWordsWerePutBackHere =>
      'الكلماتُ المنقّطة أُرجعت هنا، على هذا الجهاز. والمشطوبةُ رموزٌ لا تستطيع هذه الجلسة إرجاعها.';

  @override
  String get copyRestoredTextQuestion => 'نسخ النصّ المستعاد؟';

  @override
  String get thisWillPlaceTheRealValues =>
      'سيضع هذا القيمَ المحميّة الحقيقيّة في حافظة نظامك. وقد تستطيع تطبيقاتٌ أخرى قراءة الحافظة.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get restoredTextCopied => 'نُسخ النصّ المستعاد إلى حافظة النظام.';

  @override
  String get chooseWhoAnswersInTheMiddleFirst =>
      'اختر من يُجيب في العمود الأوسط أوّلاً';

  @override
  String sendThisQuestionTo(String name) {
    return 'أرسِل هذا السؤال إلى $name';
  }

  @override
  String get writeAQuestionFirst => 'اكتب سؤالاً أوّلاً.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get roomPrivacy => 'الخصوصية';

  @override
  String get roomLanguageAndRules => 'اللغة والقواعد';

  @override
  String get roomVaultAndSecurity => 'الخزنة والأمان';

  @override
  String get roomSessions => 'الجلسات';

  @override
  String get languageAndRulesWhat =>
      'حزمةُ الخصوصية محرّكُ كشفٍ لا لغةُ واجهة — وأكثرُ من حزمةٍ تستطيع العمل في فحصٍ واحد، فهذا نقطةُ بداية لا القواعدَ المسموحةَ وحدها.';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get appLanguageWhat =>
      'اللغةُ التي تُقرأ بها الجلسةُ حين لا لغةَ لها، وأيُّ العادات يعرفها الفحصُ فيها: صيغُ المخاطبة، وأشكالُ الشركات، وطريقةُ كتابة رقم العميل. والجلسةُ التي أُنشئت بلغةٍ خاصّةٍ بها تحفظها؛ وهذه هي التي يُقرأ بها كلُّ نصٍّ آخر. والواجهةُ تتبع هذا الاختيار.';

  @override
  String theInterfaceIsEnglishUntilTranslated(String language) {
    return '$language: حزمةُ الكشف $language؛ والواجهةُ إنجليزيّةٌ حتّى تُترجَم جملُها.';
  }

  @override
  String get myPrivacyRules => 'قواعد خصوصيّتي';

  @override
  String get myPrivacyRulesWhat =>
      'لم يُبنَ بعد. القواعدُ التي تكتبها بنفسك — صيغةُ رقم عميلٍ لا يستعملها إلّا مكتبك، أو اسمٌ رمزيٌّ لمشروع — ستعيش هنا، بجانب الحزمة لا داخلها.';

  @override
  String get vaultAndSecurityWhat =>
      'المفتاح، والقفل، وأين تعيش بيانات الدخول.';

  @override
  String get zVault => 'خزنة Z';

  @override
  String get vaultOpenWhat =>
      'مفتوحة. هويّاتك محمَّلة، وطبقةُ الكشف الرابعةُ تعمل.';

  @override
  String get vaultLockedWhat =>
      'مقفلة. القواعدُ والحزمةُ ما زالت تعمل — ورقمُ الحساب المصرفيّ يُكتشَف — أمّا صاحبُه فلا.';

  @override
  String get vaultAbsentWhat =>
      'لم تُنشأ على هذا الجهاز. ولا شيء يُعرَف بالاسم.';

  @override
  String unlockedWithIdentities(int count) {
    return 'مفتوحة · $count هويّة';
  }

  @override
  String get zPdfReadBack => 'z-pdf — اقرأ وثيقةً محميّةً إلى أصلها';

  @override
  String get zPdfWhat =>
      'الفعلُ المعاكس. الوثيقةُ التي خرجت من هذا التطبيق وفيها رموزٌ تُقرأ هنا إلى أسمائها، من خزنتك — ولا تُفحَص قطّ، ولا تُحمى، ولا تُوضع على منضدة. ولا يُرسَل منها شيءٌ إلى أيّ مكان.';

  @override
  String get openThisPanelFromTheApp =>
      'افتح هذه اللوحة من التطبيق لتختار ملفاً.';

  @override
  String get chooseAZPdfFile => 'اختر ملفّ z-pdf';

  @override
  String get lockTheVaultAfter => 'اقفل الخزنة بعد';

  @override
  String get minutesUnusedZeroIsNever => 'دقيقة بلا استعمال · 0 = أبداً';

  @override
  String get lockTheVaultAfterWhat =>
      'تحفظه الخزنةُ نفسُها، لا مؤقّتٌ في شاشة: فكلُّ طريقٍ إليها يسأل الساعةَ أوّلاً، فلا يستطيع خطأٌ في الواجهة أن يتركها مفتوحة.';

  @override
  String get encryptedLocalCredentialStorage =>
      'حفظُ بيانات الدخول محليّاً ومشفّراً';

  @override
  String get credentialHomesWhat =>
      'لمفتاح المزوّد مسكنان ولا ثالث: مختوماً داخل الخزنة إن كانت مفتوحة، أو في الذاكرة ما دام التطبيق مفتوحاً إن لم تكن. لا ملفّاً ظاهراً أبداً، ولا يُرجَع إلى الواجهة أبداً — فليس في العقد كلِّه نداءٌ يُعيده.';

  @override
  String get credentialSealedInTheVault => 'مختومٌ في الخزنة';

  @override
  String get credentialInMemory => 'في الذاكرة، يذهب بإغلاق التطبيق';

  @override
  String get credentialNoKeyStored => 'لا مفتاح محفوظ';

  @override
  String get noProviderHoldsACredential => 'لا مزوّد يحمل بيانات دخول.';

  @override
  String get deviceBoundProtection => 'حمايةٌ مرتبطةٌ بالجهاز';

  @override
  String get deviceBoundWhat =>
      'لم يُبنَ بعد. مفتاحٌ مرتبطٌ بتوثيق هذا الجهاز نفسِه سيقف فوق الطبقة التي فوق، بلا تغييرٍ في ما هو محفوظ — السجلّاتُ نفسُها، وقفلٌ واحدٌ زائد.';

  @override
  String get sessionsWhat => 'الجلسةُ تحفظ مفتاحها، والمفاتيحُ في الخزنة.';

  @override
  String get theVaultIsShutNoSessions =>
      'الخزنةُ مغلقة، فلا جلساتٌ تُعرَض. افتحها فتعود — أمّا المحادثاتُ نفسُها فلم تكن فيها قطّ.';

  @override
  String get eachSessionHasItsOwnEncryption =>
      'لكلّ جلسةٍ تشفيرُها الخاصّ. فالاسمُ نفسُه في جلستين يأخذ رمزين مختلفين، وفي جلسةٍ واحدةٍ يأخذ الرمزَ نفسَه حيث وقع — فالجلسةُ هي كيف تختار ما يستطيع الذكاءُ الاصطناعيُّ أن يصفّه وما لا يستطيع. والمفاتيحُ كلُّها في خزنتك، فقراءةُ ملفٍّ محميٍّ إلى أصله بابُ الخزنة نفسِها لا بابُ جلسة: فكلُّ ما حُفظ من أيّ جلسةٍ في هذه الخزنة يعود بأسمائه الحقيقيّة، والقراءةُ تقول من أيّ جلسةٍ جاءت.';

  @override
  String get newSession => 'جلسة جديدة';

  @override
  String get newSessionWhat =>
      'اسمٌ ولغة، وكلاهما لك تختاره: اللغةُ هي كيف يقرأ Z كلَّ نصٍّ في هذه الجلسة، وتُسأل مرّةً واحدةً هنا. وتصبح هي الجلسةَ التي تعمل فيها في الحال. وكلُّ ما هو محميٌّ أصلاً على الوثيقة أمامك يُعاد تسميتُه فيها — ولم يُرسَل شيءٌ بعد، فلا يتأثّر شيءٌ ممّا خرج.';

  @override
  String get whatIsThisOneAbout => 'عمّ هذه الجلسة؟';

  @override
  String get begin => 'ابدأ';

  @override
  String get noSessionsYet => 'لا جلسات بعد';

  @override
  String get noSessionsYetWhat =>
      'تُولد الجلسةُ أوّلَ مرّةٍ تنسخ فيها نصّاً محميّاً أو تطلب PDF — ولا تُرفض لأنّها بلا اسم، بل تأخذ رقمها بدلاً من الاسم، وتستطيع أن تسمّيها هنا. ولا يلزمك أن تصنع واحدةً بيدك أوّلاً.';

  @override
  String theOneYouAreIn(String when, String exchanges) {
    return '$when · $exchanges · التي تعمل فيها';
  }

  @override
  String get workInThisSession => 'اعمل في هذه الجلسة';

  @override
  String get enter => 'ادخل';

  @override
  String get renameThisSession => 'أعِد تسمية هذه الجلسة';

  @override
  String get deleteThisSession => 'احذف هذه الجلسة';

  @override
  String get oneExchange => 'تبادلٌ واحد';

  @override
  String exchangesCount(int count) {
    return '$count تبادلاً';
  }

  @override
  String renameSessionNumber(int number) {
    return 'إعادة تسمية الجلسة $number؟';
  }

  @override
  String theNumberStaysWhatItIs(int number) {
    return 'يبقى الرقم $number — فهو ما هذه الجلسة، ولا يتغيّر شيءٌ ممّا حُمِي فيها. وإنّما تتغيّر الكلمةُ على السطر.';
  }

  @override
  String get keepTheName => 'أبقِ الاسم';

  @override
  String get renameIt => 'أعِد تسميتها';

  @override
  String deleteNamed(String name) {
    return 'حذف «$name»؟';
  }

  @override
  String get thisDestroysTheKey =>
      'هذا يُهلِك المفتاحَ الذي حُمِيت به هذه الجلسة.';

  @override
  String get everyDocumentCanNeverBeUnprotected =>
      'ما خرج من هذه الجلسة محميّاً لا يمكن أن تُرفع حمايتُه أبداً — لا بك، ولا بـZ Privacy. فالمفتاحُ كان الشيءَ الوحيد الذي يفعل ذلك، ولن يكون. و«Undo protection» ترفع غطاءً عن النصّ الذي أمامك، لا عمّا خرج.';

  @override
  String get anythingYouSentStaysAsItWas =>
      'كلُّ ما أرسلتَه من هذه الجلسة يبقى كما كان بالضبط. والذاهبُ هو طريقُ العودة منه.';

  @override
  String get keepIt => 'أبقِها';

  @override
  String get deleteTheSession => 'احذف الجلسة';

  @override
  String get oneProtectedPlace => 'موضعٌ محميٌّ واحد';

  @override
  String protectedPlacesCount(int count) {
    return '$count موضعاً محميّاً';
  }

  @override
  String get renameThisDocument => 'أعِد تسمية هذه الوثيقة';

  @override
  String renameHandle(String handle) {
    return 'إعادة تسمية $handle؟';
  }

  @override
  String theNameIsWhatYouRead(String handle) {
    return 'الاسمُ هو ما تقرأه في هذه القائمة. و$handle يبقى ما هو: الرقمُ يُصرَف مرّةً ولا يُعطى لوثيقةٍ أخرى أبداً.';
  }

  @override
  String get aNameForThisDocument => 'اسمٌ لهذه الوثيقة';

  @override
  String get roomAi => 'الذكاء الاصطناعي';

  @override
  String get aiWhat => 'ثلاثُ طرقٍ لسؤال نموذج. والأولى لا تحتاج حساباً أصلاً.';

  @override
  String get manualAi => 'ذكاءٌ اصطناعيٌّ باليد';

  @override
  String get manualAiWhat =>
      'استعمِل محادثةَ ذكاءٍ اصطناعيٍّ تملكها أصلاً. انسخ النصَّ المحميَّ من مساحة العمل، وألصِقه في أيّ نموذجٍ تستعمله، وأرجِعِ الجواب. لا شيء لتضبطه، ولا شيء لتدفعه، والاستعادةُ تعمل كما هي تماماً.';

  @override
  String get alwaysAvailableFirstDoor =>
      'متاحٌ دائماً — وهو أوّلُ بابٍ في لوحة «اختر من يُجيب».';

  @override
  String get directApi => 'واجهةٌ مباشرة';

  @override
  String get directApiWhat =>
      'اتّصِل بمزوّد ذكاءٍ اصطناعيٍّ بعيدٍ ببيانات دخولك. المفتاحُ يدخل مرّةً ولا يخرج أبداً — فلا شاشةَ في هذا التطبيق تستطيع أن تُظهِره لك مرّةً أخرى.';

  @override
  String get atThisAddressNoCredential => 'في هذا العنوان لا تلزم بيانات دخول.';

  @override
  String get protocol => 'البروتوكول';

  @override
  String get connectedKeySealed => 'موصول · المفتاح مختومٌ في الخزنة';

  @override
  String get connectedKeyThisRunOnly =>
      'موصول · المفتاح محفوظٌ ما دام التطبيق مفتوحاً';

  @override
  String get connectedNoKeyNeeded => 'موصول · لا يلزم مفتاح';

  @override
  String get notConnected => 'غير موصول';

  @override
  String get localAi => 'ذكاءٌ اصطناعيٌّ محليّ';

  @override
  String get localAiWhat =>
      'يعمل عبر خدمة ذكاءٍ اصطناعيٍّ على هذا الحاسوب — llama.cpp أو Ollama أو LM Studio، أو أيّ شيءٍ يُجيب الشكلَ نفسَه. لا مفتاح، ولا حساب، ولا يغادر الطلبُ هذا الحاسوبَ أبداً. ولا يُقبل http الظاهر إلّا لعنوانٍ محليٍّ صريح.';

  @override
  String get models => 'النماذج';

  @override
  String get privacyWhat =>
      'ما يفعله التطبيق من تلقاء نفسه، وإلى أيّ حدٍّ يذهب بلا سؤال.';

  @override
  String get noVaultSoThisRunOnly =>
      'لا خزنةَ مفتوحة، فهذه لهذه المرّة وحدها — فبلا خزنةٍ لا شيء يحفظها.';

  @override
  String get scanOnArrival => 'افحص الوثيقة لحظةَ وصولها';

  @override
  String get scanOnArrivalWhat =>
      'لا نافذةَ سؤال، ولا زِرّ. وإطفاءُ هذا يعني أنّ الوثيقة تقف غير محميّةٍ حتّى تضغط «أعِد الفحص» — وهي اللحظةُ التي كُتبت الألواحُ لتجنّبها بالضبط.';

  @override
  String get answerEverySuggestion => 'أجب كلَّ اقتراحٍ قبل الإرسال';

  @override
  String get answerEverySuggestionWhat =>
      'ليس إعداداً. فالاقتراحُ الذي لم يُجَب لا يُعَدُّ آمناً في صمتٍ أبداً، ولا يوجد «أرسِلْ على أيّ حال» — لا هنا، ولا في علمٍ مخفيّ، ولا في أيّ موضعٍ من الكود.';

  @override
  String get aRevealedValueStaysFor => 'تبقى القيمةُ المعروضة';

  @override
  String get aRevealedValueStaysForWhat =>
      'الإظهارُ يرسم على الشاشة ولا يكتب في ما يخرج أبداً. وهذا مقدارُ بقائه مرسوماً فقط.';

  @override
  String get tokenRotation => 'تدوير الرموز';

  @override
  String get tokenRotationWhat =>
      'لم يُبنَ بعد. وحين يُبنى سيعيش هنا: هل يحفظ الرمزُ الدائمُ رقمَه عبر الجلسات، أم يُسحب من جديدٍ كلَّ مرّةٍ فلا تستطيع جلستان أن تُربَطا به.';

  @override
  String get back => 'رجوع';

  @override
  String get allIdentities => 'كلّ الهويّات';

  @override
  String identitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هويّة',
      few: '$count هويّات',
      two: 'هويّتان',
      one: 'هويّةٌ واحدة',
    );
    return '$_temp0';
  }

  @override
  String valuesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قيمة',
      few: '$count قيم',
      two: 'قيمتان',
      one: 'قيمةٌ واحدة',
    );
    return '$_temp0';
  }

  @override
  String protectedWordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كلمةً محميّة',
      few: '$count كلماتٍ محميّة',
      two: 'كلمتان محميّتان',
      one: 'كلمةٌ محميّةٌ واحدة',
    );
    return '$_temp0';
  }

  @override
  String get notCreatedOnThisDevice => 'لم تُنشأ على هذا الجهاز';

  @override
  String get changePassphrase => 'غيِّر عبارة المرور';

  @override
  String get lockTheVault => 'اقفل';

  @override
  String get theVaultIsLocked => 'الخزنة مقفلة';

  @override
  String get thereIsNoVaultYet => 'لا خزنةَ بعد';

  @override
  String get yourIdentitiesAreSealed =>
      'هويّاتك على هذا الجهاز، مختومة. وإلى أن تُفتح يبقى الفحصُ يُشغّل قواعدَه وحزمتَه — ورقمُ الحساب المصرفيّ يُكتشَف — أمّا صاحبُه فلا.';

  @override
  String get yourNamesLiveInOneVaultFile =>
      'أسماؤك تعيش في ملفّ خزنةٍ واحدٍ مشفّر. يحمل أشخاصك وقيمَهم، مشفّرةً بعبارة مرورٍ لا تغادر هذا الجهاز. وبلا خزنةٍ لا شيء يُعرَف بالاسم.';

  @override
  String get searchThisDevice => 'ابحث في هذا الجهاز — أسماء، وقيم، وهِجاءات';

  @override
  String get newIdentity => 'هويّةٌ جديدة';

  @override
  String get filterAll => 'الكلّ';

  @override
  String get sessionProfile => 'ملفُّ الجلسة الشخصيّ';

  @override
  String get newProfile => 'ملفٌّ شخصيٌّ جديد';

  @override
  String get noIdentitiesYet =>
      'لا هويّاتٍ بعد. والأولى عادةً هي العميلُ الذي تعمل على وثائقه.';

  @override
  String nothingMatchesQuery(String query) {
    return 'لا شيء في هذا الجهاز يطابق «$query».';
  }

  @override
  String get valuesITaught => 'القيم التي علّمتها';

  @override
  String get valuesITaughtWhat =>
      'أسماءٌ وشركاتٌ وأرقام — تُعرَف بنفسها من الآن';

  @override
  String get rulesITaught => 'القواعد التي علّمتها';

  @override
  String get rulesITaughtWhat =>
      'كلماتٌ تقول ما يأتي بعدها — «بعد Mandantenkennung → رقم عميل»';

  @override
  String get exceptionsITaught => 'الاستثناءات التي علّمتها';

  @override
  String get exceptionsITaughtWhat => 'قيمٌ استثنيتَها من الحماية صراحةً';

  @override
  String get noTaughtValuesYet => 'لا قيمَ مُعلَّمةً بعد.';

  @override
  String get noRulesTaughtYet => 'لا قواعدَ مُعلَّمةً بعد.';

  @override
  String get noSavedExceptionsYet => 'لا استثناءاتٍ محفوظةً بعد.';

  @override
  String kindScopeTaughtOn(String kind, String scope, String date) {
    return '$kind · $scope · عُلِّم: $date';
  }

  @override
  String doNotProtectAsKindScopeTaughtOn(
    String kind,
    String scope,
    String date,
  ) {
    return 'لا تحمِها كـ$kind · $scope · عُلِّم: $date';
  }

  @override
  String get reveal => 'إظهار';

  @override
  String get hide => 'إخفاء';

  @override
  String get theExceptionGoes =>
      'الاستثناء — وستُعرَض هذه القيمةُ للحماية مرّةً أخرى';

  @override
  String get theRuleGoes =>
      'القاعدة — وسيكفّ Z Privacy عن حماية ما يأتي بعد تلك الكلمة';

  @override
  String get openIdentity => 'افتح';

  @override
  String profileNamed(String name) {
    return 'الملفّ الشخصيّ: $name';
  }

  @override
  String get taughtOnUnknown => 'غير معروف';

  @override
  String afterLabelProtectAs(String label, String kind) {
    return 'بعد «$label:» → $kind';
  }

  @override
  String get teachARule => 'علِّم قاعدة';

  @override
  String get kindClient => 'عميل';

  @override
  String get kindPerson => 'شخص';

  @override
  String get kindCompany => 'شركة';

  @override
  String get kindProject => 'مشروع';

  @override
  String get kindSomethingElse => 'شيءٌ آخر';

  @override
  String vaultFileNotChanged(String said) {
    return '$said لم يغيّر Z Privacy الملفّ. فإن كانت لك نسخةٌ احتياطيّةٌ من الخزنة فأعِدها إلى مكانها؛ وإلّا فانقل هذا الملفّ إلى مكانٍ آخر لتُصنع خزنةٌ جديدةٌ هنا.';
  }

  @override
  String get changeThePassphrase => 'غيِّر عبارة المرور';

  @override
  String get onlyThirtyTwoBytes =>
      'لا يُعاد تغليفُ إلّا 32 بايتاً — فالخزنةُ نفسُها لا تُفكُّ ولا تُكتب من جديد. وكلُّ ما فيها يبقى في موضعه بالضبط.';

  @override
  String get currentPassphrase => 'عبارة المرور الحالية';

  @override
  String get passphrase => 'عبارة المرور';

  @override
  String get newPassphrase => 'عبارة مرورٍ جديدة';

  @override
  String get confirmPassphrase => 'أكّد عبارة المرور';

  @override
  String get confirmNewPassphrase => 'أكّد عبارة المرور الجديدة';

  @override
  String get passphrasesMatch => 'عبارتا المرور متطابقتان';

  @override
  String get passphrasesDoNotMatch => 'عبارتا المرور غير متطابقتين';

  @override
  String atLeastCharacters(int count) {
    return '$count محرفاً على الأقلّ — ولن تُصنع الخزنةُ بأقلّ.';
  }

  @override
  String get thereIsNoWayBack =>
      'لا طريقَ للعودة. لا أحد يحمل نسخةً من هذه، ولا توجد إعادةُ ضبط — فعبارةُ المرور لا تغادر هذا الجهاز، ولا شيء في جهتنا يستطيع استرجاع الخزنة بدونها.';

  @override
  String get working => 'جارٍ العمل…';

  @override
  String get changeIt => 'غيِّرها';

  @override
  String get createTheVault => 'أنشئ الخزنة';

  @override
  String get unlockTheVault => 'افتح';

  @override
  String hideNamed(String label) {
    return 'أخفِ $label';
  }

  @override
  String showNamed(String label) {
    return 'أظهِر $label';
  }

  @override
  String get aNewIdentity => 'هويّةٌ جديدة';

  @override
  String get anIdentityIsHowAPersonThinks =>
      'الهويّةُ هي كيف يفكّر الإنسان — «العميل Nordstern» — والقيمُ داخلها هي ما يطابقه الفحص.';

  @override
  String get nameField => 'الاسم';

  @override
  String get sortField => 'الترتيب';

  @override
  String get loadedIn => 'محمَّلٌ في';

  @override
  String get exampleClientNordstern => 'العميل Nordstern';

  @override
  String get exampleCompanyName => 'Nordstern Consulting GmbH';

  @override
  String get cancelForm => 'إلغاء';

  @override
  String get createIt => 'أنشئ';

  @override
  String get aNewValue => 'قيمةٌ جديدة';

  @override
  String get editThisValue => 'حرِّر هذه القيمة';

  @override
  String get theValue => 'القيمة';

  @override
  String get readingItFromTheVault => 'جارٍ قراءتها من الخزنة…';

  @override
  String get whatItIs => 'ما هي';

  @override
  String get howToTreatIt => 'كيف تُعامَل';

  @override
  String get alwaysProtect => 'احمِ دائماً';

  @override
  String get alwaysProtectWhat => 'تُعرَف بنفسها وتُستبدَل، بلا سؤال.';

  @override
  String get suggestPolicy => 'اقترِح';

  @override
  String get suggestPolicyWhat => 'تُعرَف، وتُعرَض عليك قبل أن يُرسَل شيء.';

  @override
  String get keepDoNotHunt => 'احفظ، ولا تبحث';

  @override
  String get keepDoNotHuntWhat =>
      'تُحفظ ليبقى هِجاؤها ورمزُها ثابتين — ولا تُطلَب.';

  @override
  String get saveIt => 'احفظ';

  @override
  String get aNewProfile => 'ملفٌّ شخصيٌّ جديد';

  @override
  String get renameProfile => 'أعِد تسمية الملفّ الشخصيّ';

  @override
  String get oneDictionaryPerClient =>
      'قاموسٌ واحد لكلّ عميل. ولا تُحمَّل إلّا هويّاتُ الملفّ الشخصيّ الذي تفتحه — ففتحُ الخزنة ليس شيكاً على بياض.';

  @override
  String get theProfileIdStaysTheSame =>
      'معرّفُ الملفّ الشخصيّ يبقى كما هو. وإنّما يتغيّر الاسمُ الذي يقرأه الإنسان.';

  @override
  String get languagesUsedInDocuments => 'اللغات المستعملة في الوثائق';

  @override
  String get moreThanOneMayBeOn =>
      'أكثرُ من واحدةٍ قد تكون مشغَّلة. فالوثيقةُ التي فيها عنوانٌ ألمانيٌّ وآخرُ إنجليزيٌّ تُقرأ بهما في فحصٍ واحد.';

  @override
  String get renameIt2 => 'أعِد التسمية';

  @override
  String get teachARuleHead => 'علِّم قاعدة';

  @override
  String get aRuleIsAWordAndWhatComesAfter =>
      'القاعدةُ كلمةٌ وما يأتي بعدها. يحمي Z Privacy القيمةَ التي تتبعها ويتوقّف عند نهاية ذلك الحقل.';

  @override
  String get whenZPrivacySees => 'حين يرى Z Privacy';

  @override
  String get exampleMandantenkennung => 'Mandantenkennung';

  @override
  String get protectTheValueAfterItAs => 'احمِ القيمةَ التي بعدها كـ';

  @override
  String get whereField => 'أين';

  @override
  String profileNamedDash(String name) {
    return 'ملفٌّ شخصيّ — $name';
  }

  @override
  String get saveRule => 'احفظ القاعدة';

  @override
  String get removeProtectionHere => 'أزِل الحماية هنا';

  @override
  String removeItInThisSession(int places) {
    return 'أزِلها في هذه الجلسة ($places موضعاً)';
  }

  @override
  String get forgetFromThisProfile => 'انسَ من هذا الملفّ الشخصيّ';

  @override
  String get forgetEverywhere => 'نسيان في كل مكان';

  @override
  String get protectThisColumnInTheLineHeld =>
      'احمِ هذا العمود في السطر المحفوظ';

  @override
  String protectThisColumnInLinesHeld(int lines) {
    return 'احمِ هذا العمود في السطور المحفوظة $lines';
  }

  @override
  String get whyIsThisProtected => 'لماذا هذه محميّة؟';

  @override
  String get theSameCellOfEveryHeldLine =>
      'الخليّةُ نفسُها من كلّ سطرٍ محفوظ، ولكلّ قيمةٍ رمزُها. وهذه محميّةٌ أصلاً وتبقى كما هي.';

  @override
  String get whatItIsRow => 'ما هي';

  @override
  String get whereItApplies => 'أين تنطبق';

  @override
  String get decidedBy => 'قرّرها';

  @override
  String get decidedByYou => 'أنت';

  @override
  String get decidedByZPrivacy => 'Z Privacy، من تلقاء نفسه';

  @override
  String get taughtOnRow => 'عُلِّمت في';

  @override
  String get tokenRow => 'الرمز';

  @override
  String otherSpellingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هِجاءً آخر',
      few: '$count هِجاءاتٍ أخرى',
      two: 'هِجاءان آخران',
      one: 'هِجاءٌ آخرُ واحد',
    );
    return '$_temp0';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get uncoversThisOnePlace =>
      'يكشف هذا الموضعَ وحده. وكلُّ موضعٍ آخر يحفظ حمايتَه ورمزَه.';

  @override
  String get theValueStaysInYourRules =>
      'تبقى القيمةُ في قواعد خصوصيّتك وقد تُحمى مرّةً أخرى لاحقاً.';

  @override
  String get uncoversEveryPlaceInThisSession =>
      'يكشف كلَّ موضعٍ يقف فيه هذا الرمز، في هذه الجلسة.';

  @override
  String get thereIsNoEverywhere =>
      'لا «في كل مكان» هنا: رفعُ الحماية لا يبلغ أبعدَ من جلسةٍ واحدة.';

  @override
  String get removesWhatZLearnedForThisProfile =>
      'يُزيل ما تعلّمه Z Privacy لهذا الملفّ الشخصيّ.';

  @override
  String get protectionAlreadyAppliedStays =>
      'تبقى الحمايةُ المطبَّقةُ في هذه الوثيقة في موضعها.';

  @override
  String get removesWhatZLearnedEverywhere =>
      'يُزيل ما تعلّمه Z Privacy، في كلّ ملفٍّ شخصيّ.';

  @override
  String get forgetThisRule => 'انسَ هذه القاعدة';

  @override
  String get theRuleItselfIsKept => 'القاعدةُ نفسُها محفوظةٌ في خزنتك.';

  @override
  String get forgetItInZVaultRules =>
      'انسَها في خزنة Z → قواعد خصوصيّتي → القواعد التي علّمتها.';

  @override
  String get nothingWasLearnedYouProtectedIt =>
      'لم يُتعلَّم من هذا شيء — أنت حميتَها هنا، والتراجعُ يُرجعها.';

  @override
  String get nothingWasLearnedARuleSawIt =>
      'لم يُتعلَّم من هذا شيء. قاعدةٌ عرفت الشكل، ولم يُحفظ له سِجلّ.';

  @override
  String forgottenButStillKnownBy(String who) {
    return 'مُنسيّة، لكنّ $who ما زال يعرفها. أخبرنا من فضلك — فهذا لا ينبغي أن يكون ممكناً.';
  }

  @override
  String forgetNamed(String what) {
    return 'نسيان «$what»؟';
  }

  @override
  String get thisWillRemove => 'سيُزيل هذا';

  @override
  String protectedValuesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قيمةً محميّة',
      few: '$count قيمٍ محميّة',
      two: 'قيمتان محميّتان',
      one: 'قيمةٌ محميّةٌ واحدة',
    );
    return '$_temp0';
  }

  @override
  String spellingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هِجاءً',
      few: '$count هِجاءات',
      two: 'هِجاءان',
      one: 'هِجاءٌ واحد',
    );
    return '$_temp0';
  }

  @override
  String identitiesLeftHoldingNothing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هويّة',
      few: '$count هويّات',
      two: 'هويّتان',
      one: 'هويّةٌ واحدة',
    );
    return '$_temp0 تبقى بلا شيءٍ تحمله';
  }

  @override
  String itsPlaceIn(String profile) {
    return 'موضعها في $profile';
  }

  @override
  String get itWillNotChange => 'ولن يتغيّر';

  @override
  String get forgetRemovesFromThisVault =>
      'النسيانُ يُزيل هذه القيمة من الخزنة الحالية ومن معرفة تلك الخزنة بها لاحقاً. ولا يُزيل الحمايةَ المطبَّقةَ أصلاً في هذه الوثيقة، وقد تُرجِع نسخةٌ أقدمُ صالحةٌ من الخزنة القيمةَ في وقتٍ لاحق.';

  @override
  String wouldStillRecogniseIt(String who) {
    return '$who سيبقى يعرفها — فالنسيانُ هنا لا يبلغ سجلّاتِ عميلٍ آخر.';
  }

  @override
  String get thisCannotBeUndone => 'لا رجوعَ عن هذا.';

  @override
  String get noValuesYet =>
      'لا قيمَ بعد. والقيمةُ هي ما يطابقه الفحص — اسمٌ أو شركةٌ أو رقمُ حسابٍ مصرفيّ.';

  @override
  String valuesEachWithItsOwnPolicy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قيمة',
      few: '$count قيم',
      two: 'قيمتان',
      one: 'قيمةٌ واحدة',
    );
    return '$_temp0، لكلٍّ منها هِجاؤها وسياستُها.';
  }

  @override
  String get moveIt => 'انقل';

  @override
  String get deleteIt => 'احذف';

  @override
  String get addAValue => 'أضِف قيمة';

  @override
  String get policyKeptNotHunted => 'محفوظة، لا مطلوبة';

  @override
  String get addASpelling => 'أضِف هِجاءً';

  @override
  String get editIt => 'حرِّر';

  @override
  String get alsoWritten => 'وتُكتب أيضاً';

  @override
  String get anotherSpelling => 'هِجاءٌ آخر';

  @override
  String get anotherSpellingWhat =>
      'القيمةُ نفسُها مكتوبةً على نحوٍ آخر — «Herr Müller»، «T. Müller». وكلُّ هِجاءٍ يحفظ الرمزَ نفسَه، فيقرأ النموذجُ شخصاً واحداً لا ثلاثة.';

  @override
  String get exampleSpelling => 'Herr Müller';

  @override
  String get renameHead => 'إعادة التسمية';

  @override
  String get whatToCallThisIdentity => 'بماذا تُسمّى هذه الهويّة.';

  @override
  String get moveThisIdentity => 'انقل هذه الهويّة';

  @override
  String get anIdentityInAProfile =>
      'الهويّةُ في ملفٍّ شخصيٍّ لا تُحمَّل إلّا حين يكون ذلك الملفُّ مفتوحاً. وما ينتمي إلى كلّ مكانٍ محمَّلٌ دائماً.';

  @override
  String get deleteThisIdentity => 'حذف هذه الهويّة؟';

  @override
  String identityAndItsValuesAreRemoved(String name, String values) {
    return 'تُزال «$name» و$values من الخزنة. والوثائقُ المحميّةُ أصلاً تحفظ رموزها؛ أمّا الوثيقةُ التالية فلن تعرف هذه القيم مرّةً أخرى.';
  }

  @override
  String get keepItIdentity => 'أبقِها';

  @override
  String get noNamesToLookAt => 'لا أسماءَ للنظر فيها';

  @override
  String namesToLookAtCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اسماً للنظر فيه',
      few: '$count أسماءٍ للنظر فيها',
      two: 'اسمان للنظر فيهما',
      one: 'اسمٌ واحد للنظر فيه',
    );
    return '$_temp0';
  }

  @override
  String get zKnowsEveryName => 'يعرف Z كلَّ اسمٍ تستعمله هذه الوثيقة.';

  @override
  String get wordsThisDocumentUsesAsNames =>
      'كلماتٌ تستعملها هذه الوثيقةُ أسماءً، ولا يعرفها Z بعد.';

  @override
  String placesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موضعاً',
      few: '$count مواضع',
      two: 'موضعان',
      one: 'موضعٌ واحد',
    );
    return '$_temp0';
  }

  @override
  String pagesCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صفحةً',
      few: '$count صفحات',
      two: 'صفحتان',
      one: 'صفحةٌ واحدة',
    );
    return '$_temp0';
  }

  @override
  String get addAsFamilyName => 'أضِفه اسمَ عائلة';

  @override
  String get addAsGivenName => 'أضِفه اسماً شخصيّاً';

  @override
  String get ignoreIt => 'تجاهَل';

  @override
  String get unlockTheVaultAct => 'افتح الخزنة';

  @override
  String get needsAVault => 'يلزمه خزنة';

  @override
  String get nameListsFileType => 'قوائم الأسماء';

  @override
  String get whichLanguageAreTheseNames => 'بأيّ لغةٍ هذه الأسماء؟';

  @override
  String get yourNames => 'أسماؤك';

  @override
  String get namesThisDeviceKnows =>
      'أسماءٌ يعرفها هذا الجهاز لأنّك قلتَها. تُحفظ في خزنتك، على هذا الحاسوب.';

  @override
  String get addAName => 'أضِف اسماً';

  @override
  String get importAList => 'أدخِل قائمة';

  @override
  String actNeedsTheVault(String act, String needs) {
    return '$act · $needs';
  }

  @override
  String get aListIsACsv =>
      'القائمةُ ملفُّ CSV فيه عمودُ «name» وعمودُ «type»: given أو family أو person أو company.';

  @override
  String get yourNamesLiveInTheVault =>
      'أسماؤك تعيش في الخزنة، فإضافةُ اسمٍ تحتاجها مفتوحة.';

  @override
  String get exampleSurname => 'Lindqvist';

  @override
  String get pickSuggest => 'اقترِح';

  @override
  String get pickAlways => 'دائمًا';

  @override
  String get alwaysProtectedTheMoment =>
      'دائمًا: يُحمى لحظةَ ظهوره، في كلّ وثيقة.';

  @override
  String get suggestMarksAndWaits => 'اقترِح: يَسِمه Z وينتظر كلمتك.';

  @override
  String get addAct => 'أضِف';

  @override
  String get nothingYet => 'لا شيء بعد.';

  @override
  String get wholeNamesKeptInTheVault => 'أسماءٌ كاملة، محفوظةٌ في الخزنة';

  @override
  String get aWholePersonIsAValue =>
      'الشخصُ الكامل أو الشركةُ الكاملة قيمةٌ لا كلمةَ قاموس، فليست في قائمة لغةٍ أصلاً. وخزنةُ Z هي حيث يُدار كلٌّ منها.';

  @override
  String get reachEverywhere => 'في كل مكان';

  @override
  String get reachThisClient => 'هذا العميل';

  @override
  String forgetNamedShort(String what) {
    return 'نسيان «$what»';
  }

  @override
  String get kindGivenName => 'اسم شخصيّ';

  @override
  String get kindFamilyName => 'اسم عائلة';

  @override
  String get kindPersonName => 'شخص';

  @override
  String get kindCompanyName => 'شركة';

  @override
  String namesAndValuesInAList(String names, int values) {
    return '$names · $values قيمة';
  }

  @override
  String get listIsOff => 'موقوفة';

  @override
  String get stopUsingTheseNames => 'أوقِف استعمال هذه الأسماء';

  @override
  String get useTheseNamesAgain => 'استعمِل هذه الأسماء مرّةً أخرى';

  @override
  String whatToDoWithList(String name) {
    return 'ما العمل بـ«$name»';
  }

  @override
  String get moveToDots => 'انقل إلى…';

  @override
  String get exportCsv => 'صدِّر CSV';

  @override
  String get removeList => 'أزِل القائمة';

  @override
  String removeNamedList(String name) {
    return 'إزالة «$name»؟';
  }

  @override
  String namesGoWithItCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يذهب معها $count اسماً. ولا يُمَسّ شيءٌ آخر.',
      few: 'تذهب معها $count أسماء. ولا يُمَسّ شيءٌ آخر.',
      two: 'يذهب معها اسمان. ولا يُمَسّ شيءٌ آخر.',
      one: 'يذهب معها اسمٌ واحد. ولا يُمَسّ شيءٌ آخر.',
    );
    return '$_temp0';
  }

  @override
  String get removeAct => 'أزِل';

  @override
  String moveNamesFromTo(int count, String from) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'انقل $count اسماً من $from إلى…',
      few: 'انقل $count أسماء من $from إلى…',
      two: 'انقل اسمين من $from إلى…',
      one: 'انقل اسماً واحداً من $from إلى…',
    );
    return '$_temp0';
  }

  @override
  String get howFarDoTheseNamesReach => 'إلى أين تبلغ هذه الأسماء؟';

  @override
  String get protectingThemMeans =>
      'حمايتها تعني أنّ Z يُسوّدها لحظةَ ظهورها، بلا سؤال. وعرضُها يعني أنّ Z يَسِمها وينتظرك.';

  @override
  String get youCanChangeAnyOneAfterwards =>
      'وتستطيع أن تغيّر أيّاً منها بعد ذلك، اسماً اسماً.';

  @override
  String get offerThemAndIDecide => 'اعرِضها وأنا أقرّر';

  @override
  String get protectThemEverywhere => 'احمِها في كل مكان';

  @override
  String protectThemForClient(String client) {
    return 'احمِها لـ$client';
  }

  @override
  String get couldNotBuildThePdf =>
      'لم يستطع Z Privacy بناء ملفّ PDF — فصفحةُ الجواب فيه بلا رمز. ولم يُكتب شيء.';

  @override
  String get whoAnswers => 'من يُجيب';

  @override
  String get thereIsNothingToSend => 'لا شيء للإرسال.';

  @override
  String valuesReplacedCharacters(int values, int characters) {
    return '$values قيمة مُستبدَلة · $characters محرفاً ستغادر هذا الجهاز.';
  }

  @override
  String sessionNumber(int number) {
    return 'جلسة $number';
  }

  @override
  String sessionNumberNamed(int number, String name) {
    return 'جلسة $number «$name»';
  }

  @override
  String theseNamesAreThisSessions(String named) {
    return '$named · هذه الأسماء لهذه الجلسة';
  }

  @override
  String get noSessionNamesForThisDocument =>
      'لا جلسة — هذه الأسماء صُنعت لهذه الوثيقة وحدها.';

  @override
  String get noSessionYetAnyDoorBeginsOne =>
      'لا جلسةَ بعد — وأيُّ بابٍ هنا يبدأ واحدة.';

  @override
  String get nothingLeftTheMachine => 'لم يخرج شيءٌ من الجهاز.';

  @override
  String get oneSuggestionStillOpenSend =>
      'اقتراحٌ واحد ما زال مفتوحاً. يقف في النصّ كما كُتب، ولا يُرسَل شيءٌ حتّى تجيبه. ولا يوجد «أرسِلْ على أيّ حال».';

  @override
  String suggestionsStillOpenSend(int open) {
    return '$open اقتراحاً ما زالت مفتوحة. تقف في النصّ كما كُتبت، ولا يُرسَل شيءٌ حتّى تجيبها. ولا يوجد «أرسِلْ على أيّ حال».';
  }

  @override
  String get manualAiSheetWhat =>
      'استعمِل محادثةَ ذكاءٍ اصطناعيٍّ تملكها أصلاً. خُذِ النصَّ أعلاه — إلى الحافظة، أو ملفَّ PDF محفوظاً على هذا الجهاز — وألصِقه في أيّ نموذجٍ تحبّ، وأرجِعِ الجواب بـ«أضِف جواباً» تحت المحادثة. والاستعادةُ تعمل كما هي في الطريقين — بلا حساب، وبلا مفتاح. ولا يُرسِل أيٌّ منهما شيئاً من هنا.';

  @override
  String get copied => 'نُسخ';

  @override
  String get copyProtected => 'نسخ النص المحمي';

  @override
  String get saving => 'جارٍ الحفظ…';

  @override
  String get saveAsPdf => 'احفظ كملفّ PDF';

  @override
  String savedToWhere(String where) {
    return 'حُفظ في $where';
  }

  @override
  String get whatThePdfHolds =>
      'النصُّ المحميّ، ومعه ختمُ البناء والأعداد وبصمةُ sha256 لذلك النصّ في التذييل، وصفحةٌ أخيرةٌ للجواب. ولم يُرسَل شيء.';

  @override
  String get directApiSheetWhatRemote =>
      'اتّصِل بمزوّد ذكاءٍ اصطناعيٍّ بعيدٍ ببيانات دخولك. ولن يسافر إلّا النصُّ أعلاه؛ ويبقى المزوّدُ يرى حقائقَ الاتّصال العاديّة — عنوانَك، والوقتَ، والنموذج.';

  @override
  String get directApiSheetWhatConnected =>
      'يخرج الطلبُ من هذا التطبيق. ولا يسافر إلّا النصُّ أعلاه؛ ويبقى المزوّدُ يرى حقائقَ الاتّصال العاديّة — عنوانَك، والوقتَ، والنموذج.';

  @override
  String get noProviderIsConnected =>
      'لا مزوّد موصول. العنوانُ والمفتاحُ يُعطيان مرّةً واحدةً في الإعدادات — وهذه الشاشةُ لا تسألهما أبداً.';

  @override
  String get sending => 'جارٍ الإرسال…';

  @override
  String sendToNamed(String where) {
    return 'أرسِل إلى $where';
  }

  @override
  String get providerKeyThisRunOnly =>
      '  (المفتاح محفوظٌ ما دام التطبيق مفتوحاً)';

  @override
  String get theAddressTheModelTheKey =>
      'العنوانُ والنموذجُ والمفتاحُ تُغيَّر في الإعدادات.';

  @override
  String get localAiSheetWhat =>
      'استعمِل خدمةَ ذكاءٍ اصطناعيٍّ تعمل على هذا الحاسوب — llama.cpp أو Ollama أو LM Studio، أو أيّ شيءٍ يُجيب الشكلَ نفسَه. لا مفتاح، ولا حساب، ولا يغادر الطلبُ هذا الحاسوبَ أبداً. وهو الطريقُ الوحيد الذي لا يرى شيئاً من الحقائق العاديّة أعلاه.';

  @override
  String get aModelOnThisComputer =>
      'النموذجُ على هذا الحاسوب يُضبَط في الإعدادات — ولا مفتاحَ يُعطى.';

  @override
  String get openSettings => 'افتح الإعدادات';

  @override
  String get modelLabel => 'النموذج';

  @override
  String get fileKindDocuments => 'الوثائق';

  @override
  String onlyTheseKindsAreRead(String name) {
    return 'تقرأ هذه النسخةُ ملفّات PDF وWord والنصّ. و«$name» ليس منها.';
  }

  @override
  String get generalRulesOnlyNoDictionary =>
      'القواعدُ العامّةُ فقط — لا قاموسَ بعد';

  @override
  String get whichLanguageIsThisText => 'بأيّ لغةٍ هذا النصّ؟';

  @override
  String get theSessionLanguageExplained =>
      'يقرأه Z بعادات تلك اللغة: كيف يُخاطَب الناس، وكيف تُكتب الشركة، وكيف يبدو رقمُ العميل. وهذه لغةُ الجلسة من الآن، ولن تُسأل عنها فيها مرّةً أخرى.';

  @override
  String allLinesHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كلُّ السطور $count',
      few: 'كلُّ السطور $count',
      two: 'السطران كلاهما',
      one: 'السطرُ الواحد كلُّه',
    );
    return '$_temp0';
  }

  @override
  String get revealHidden => 'مخفي';

  @override
  String revealedForSeconds(int seconds) {
    return 'معروضة · $secondsث';
  }

  @override
  String get alsoTheWordBefore => 'والكلمةُ التي قبلها أيضاً';

  @override
  String get alsoTheWordBeforeHint =>
      'يأخذ أيضاً الكلمةَ التي أمام التحديد إن بدأت بحرفٍ كبير';

  @override
  String get undoProtection => 'ارفع الحماية';

  @override
  String get nothingToUndoHint => 'لا شيء لِيُرفَع';

  @override
  String get rescanAct => 'أعِد الفحص';

  @override
  String nextOfWaitingCount(int at, int total) {
    return 'التالي $at/$total';
  }

  @override
  String get reviewAct => 'مراجعة';

  @override
  String get namesAct => 'الأسماء';

  @override
  String get zKnowsEveryNameHere => 'يعرف Z كلَّ اسمٍ تستعمله هذه الوثيقة';

  @override
  String get tokensAct => 'الرموز';

  @override
  String get nothingIsProtectedYetHint => 'لا شيء محميٌّ بعد';

  @override
  String get selectionCutsIntoProtected =>
      'ذلك التحديدُ يقطع في شيءٍ محميٍّ أصلاً. والحمايةُ ستأخذ العنصرَ كلَّه بدلاً من ذلك.';

  @override
  String selectionSpansProtectedItems(int count) {
    return 'ذلك التحديدُ يمتدّ على $count عنصراً محميّاً. والحمايةُ ستأخذ كلَّ واحدٍ منها كاملاً، برمزه الخاصّ.';
  }

  @override
  String get protectAct => 'احمِ';

  @override
  String get selectTextThenProtect => 'حدِّد نصّاً، ثمّ احمِ';

  @override
  String get alreadyProtectedSeeBelow => 'محميٌّ أصلاً — انظر أدناه';

  @override
  String get protectWholeItems => 'احمِ العناصر كاملةً';

  @override
  String get thereWasNothingToUndo => 'لم يكن هناك شيءٌ لِيُرفَع.';

  @override
  String tookBackTokens(String tokens) {
    return 'رُفِع $tokens.';
  }

  @override
  String tookBackTokensInPlaces(String tokens, int places) {
    return 'رُفِع $tokens، في المواضع $places كلّها — دخل فعلاً واحداً، فخرج فعلاً واحداً.';
  }

  @override
  String tookBackTokensIdentityStays(String tokens, String identity) {
    return 'رُفِع $tokens. والهويّةُ $identity ما زالت في الخزنة.';
  }

  @override
  String scannedAgainReport(int auto, int byYou, int waiting, int normal) {
    return 'فُحص مرّةً أخرى: $auto محميّةٌ تلقائيّاً · $byYou بك · $waiting تنتظر كلمتك · $normal عاديّة.';
  }

  @override
  String alreadyProtectedAsTokens(String tokens) {
    return 'محميٌّ أصلاً كـ$tokens.';
  }

  @override
  String alreadyProtectedAsFrom(String tokens, String source, String detail) {
    return 'محميٌّ أصلاً كـ$tokens، من $source$detail.';
  }

  @override
  String get readBackPanel => 'القراءة إلى الأصل';

  @override
  String get whatStayedAToken => 'ما بقي رمزاً';

  @override
  String theSearchWasRefused(String why) {
    return 'رُفض البحث: $why';
  }

  @override
  String get findAWordInThisDocument => 'ابحث عن كلمةٍ في هذه الوثيقة';

  @override
  String get tabTakesIt => 'Tab يأخذها';

  @override
  String get findAct => 'ابحث';

  @override
  String notInThisDocument(String word) {
    return '«$word» ليست في هذه الوثيقة';
  }

  @override
  String countProtected(int count) {
    return '$count محميّة';
  }

  @override
  String countWaiting(int count) {
    return '$count تنتظر';
  }

  @override
  String countInTheClear(int count) {
    return '$count ظاهرة';
  }

  @override
  String placesInsideWaitingWords(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موضعاً يقع',
      few: '$count مواضع تقع',
      two: 'موضعان يقعان',
      one: 'موضعٌ واحد يقع',
    );
    return '$_temp0 داخل كلماتٍ ما زالت تنتظر كلمتك: $list. والحمايةُ تترك تلك للمراجعة.';
  }

  @override
  String get goToIt => 'اذهب إليه';

  @override
  String get unProtectHere => 'ارفع الحماية هنا';

  @override
  String unProtectInThisSession(int places) {
    return 'ارفع الحماية في هذه الجلسة ($places موضعاً)';
  }

  @override
  String get nothingIsWaitingForYou => 'لا شيء ينتظرك.';

  @override
  String thingsWaitingForYourWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شيئاً ينتظر كلمتك.',
      few: '$count أشياء تنتظر كلمتك.',
      two: 'شيئان ينتظران كلمتك.',
      one: 'شيءٌ واحد ينتظر كلمتك.',
    );
    return '$_temp0';
  }

  @override
  String get theScanFoundNothingHere => 'لم يجد الفحصُ شيئاً في هذه الوثيقة.';

  @override
  String get nothingIsWaitingWhatIsProtected =>
      'لا شيء ينتظر. وما هو محميٌّ في النصّ، موسومٌ حيث يقف.';

  @override
  String foundBySource(String source) {
    return 'عُثر عليه بواسطة $source';
  }

  @override
  String get youDecided => 'أنت قرّرت';

  @override
  String pageAndParagraph(int page, int paragraph) {
    return 'الصفحة $page · ¶$paragraph';
  }

  @override
  String inPlacesCount(int count) {
    return 'في $count موضعاً';
  }

  @override
  String identitiesClaimIt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هويّة تطلبها',
      few: '$count هويّات تطلبها',
      two: 'هويّتان تطلبانها',
      one: 'هويّةٌ واحدة تطلبها',
    );
    return '$_temp0';
  }

  @override
  String leaveWordsInTheClearQuestion(int count) {
    return 'تُترك $count كلمة ظاهرةً؟';
  }

  @override
  String leaveAllInTheClearExplained(int count) {
    return 'ستُرسَل $count كلمةً كلُّها كما هي مكتوبةٌ بالضبط. ولن يُبدِل Z واحدةً منها، لا في هذه الوثيقة ولا في الطلب الذي يخرج من هذا الحاسوب.';
  }

  @override
  String yesLeaveAllInTheClear(int count) {
    return 'نعم — اترك $count كلمةً كلَّها ظاهرة';
  }

  @override
  String get protectAll => 'احمِ الكلّ';

  @override
  String get skipAll => 'تجاوَز الكلّ';

  @override
  String get leaveIt => 'اتركها';

  @override
  String get activeZTokens => 'رموز Z النشطة';

  @override
  String get nothingIsProtectedYetSentence => 'لا شيء محميٌّ بعد.';

  @override
  String valuesStandBehindTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قيمةً تقف',
      few: '$count قيمٍ تقف',
      two: 'قيمتان تقفان',
      one: 'قيمةٌ واحدة تقف',
    );
    return '$_temp0 خلف رمزٍ في هذه الجلسة.';
  }

  @override
  String get aTokenAppearsWhenProtected => 'يظهر الرمزُ هنا لحظةَ حمايةِ شيء.';

  @override
  String get revealingChangesNothing =>
      'الإظهارُ يُبدي قيمةً على هذه الشاشة لحظةً. ولا يغيّر شيئاً في العمود المحميّ — فالذي يخرج من الجهاز هو النصُّ نفسُه قبلَه وبعدَه.';

  @override
  String get copyTheToken => 'انسخ الرمز';

  @override
  String get scopeJustHere => 'هنا فقط';

  @override
  String get scopeThisSession => 'هذه الجلسة';

  @override
  String get scopeRememberedForClient => 'محفوظٌ لهذا العميل';

  @override
  String get scopeRememberedEverywhere => 'محفوظٌ في كل مكان';

  @override
  String get copyReport => 'انسخ التقرير';

  @override
  String sessionNamesAreThisSessions(int number) {
    return 'جلسة $number · الأسماء في هذا العمل لهذه الجلسة';
  }

  @override
  String get asEachProviderIsConfigured => 'بحسب ضبط كلّ مزوّد';

  @override
  String get noAiConnected => 'لا ذكاءَ اصطناعيّاً موصولاً';

  @override
  String get connectAnAiInSettings => 'صِلْ ذكاءً اصطناعيّاً في الإعدادات';

  @override
  String get chooseWhichModelAnswers => 'اختر أيّ نموذجٍ يُجيب';

  @override
  String get nothingSentFromThisSessionYet =>
      'لم يُرسَل شيءٌ من هذه الجلسة بعد. وما يذهب إلى نموذجٍ وما يعود منه مكتوبان هنا، في ملفّ هذه الجلسة المختوم.';

  @override
  String get youAsked => 'أنت سألت';

  @override
  String get nothingWasAskedDocumentWentAlone =>
      'لم يُسأل شيء — ذهبت الوثيقةُ وحدها.';

  @override
  String get itAnswered => 'وأجاب';

  @override
  String namesBelongToAnotherSession(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اسماً في هذا التبادل يتبع جلسةً أخرى فلم يُستعَد: $list.',
      few: '$count أسماءٍ في هذا التبادل تتبع جلسةً أخرى فلم تُستعَد: $list.',
      two: 'اسمان في هذا التبادل يتبعان جلسةً أخرى فلم يُستعادا: $list.',
      one: 'اسمٌ واحد في هذا التبادل يتبع جلسةً أخرى فلم يُستعَد: $list.',
    );
    return '$_temp0';
  }

  @override
  String get andTheClipboardIsEmptySentence => 'لم يُنسخ شيء — الحافظة فارغة.';

  @override
  String get nothingWasPasted => 'لم يُلصَق شيء.';

  @override
  String get copyTheSafeTextFirst =>
      'انسخ النصَّ المحميَّ أوّلاً، ليُربَط الجوابُ بتلك الحمولة.';

  @override
  String profileIsInUseAgain(String name) {
    return '«$name» مستعملٌ مرّةً أخرى.';
  }

  @override
  String profileIsOffNamesRemain(String name) {
    return '«$name» موقوف — وأسماؤه ما زالت هنا.';
  }

  @override
  String movedNamesToLanguage(int count, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نُقل $count اسماً إلى $to.',
      few: 'نُقلت $count أسماء إلى $to.',
      two: 'نُقل اسمان إلى $to.',
      one: 'نُقل اسمٌ واحد إلى $to.',
    );
    return '$_temp0';
  }

  @override
  String forgotProfileAndItsNames(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اسماً',
      few: '$count أسماء',
      two: 'اسمان',
      one: 'اسمٌ واحد',
    );
    return 'نُسي «$name» و$_temp0.';
  }

  @override
  String addedValueNamed(String value) {
    return 'أُضيفت «$value».';
  }

  @override
  String forgotValueNamed(String value) {
    return 'نُسيت «$value».';
  }

  @override
  String get afterTheVaultOpened => 'بعد فتح الخزنة';

  @override
  String importAddedCount(int count) {
    return '$count أُضيفت';
  }

  @override
  String importAlreadyKnownCount(int count) {
    return '$count معروفةٌ أصلاً';
  }

  @override
  String importRefusedCount(int count) {
    return '$count مرفوضة';
  }

  @override
  String importValuesCount(int count) {
    return '$count قيمة';
  }

  @override
  String get begunNoNameNeededRenaming =>
      'بدأت. ولم يحتج اسمٌ على هذه الوثيقة إلى إعادة تسمية.';

  @override
  String get begunNoDocumentOpen =>
      'بدأت. ولا وثيقةَ مفتوحة، فلم يكن هناك ما يُعاد تسميتُه.';

  @override
  String begunAndNamesMovedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بدأت، وانتقل إليها $count اسماً على هذه الوثيقة.',
      few: 'بدأت، وانتقلت إليها $count أسماء على هذه الوثيقة.',
      two: 'بدأت، وانتقل إليها اسمان على هذه الوثيقة.',
      one: 'بدأت، وانتقل إليها اسمٌ واحد على هذه الوثيقة.',
    );
    return '$_temp0';
  }

  @override
  String get theSessionWasNotBegun => 'لم تبدأ الجلسة، فلم يُخرَج شيء.';

  @override
  String get closeAndOpenAgain =>
      'أغلِق هذا وافتحه مرّةً أخرى — تغيّر شيءٌ وهو مفتوح.';

  @override
  String get sentToAiAnswered => 'أُرسل إلى الذكاء الاصطناعي · أُجيب';

  @override
  String get sentToAiNoAnswerYet => 'أُرسل إلى الذكاء الاصطناعي · لا جوابَ بعد';

  @override
  String columnsNotUsedSaid(int count, String which) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count عموداً لم يُستعمل: $which — سمِّ نوعَ كلٍّ منها، أو تبقى خارجاً.',
      few:
          '$count أعمدةٍ لم تُستعمل: $which — سمِّ نوعَ كلٍّ منها، أو تبقى خارجاً.',
      two:
          'عمودان لم يُستعملا: $which — سمِّ نوعَ كلٍّ منهما، أو يبقيان خارجاً.',
      one: 'عمودٌ واحد لم يُستعمل: $which — سمِّ نوعَه، أو يبقى خارجاً.',
    );
    return '$_temp0';
  }

  @override
  String get addressLabel => 'العنوان';

  @override
  String get plainHttpOnlyLoopback =>
      'لا يُقبل http الظاهر إلّا لعنوانٍ محليٍّ صريح — 127.0.0.1 أو ::1. أمّا اسمٌ مثل «localhost» فمرفوض، لأنّ ملفَّ hosts سيكون حينها هو الذي يقرّر إن كان النصُّ الظاهر آمناً.';

  @override
  String get theModelToAsk => 'النموذجُ الذي يُسأل';

  @override
  String get apiKeyLabel => 'مفتاح الواجهة';

  @override
  String get pastedOnceNeverShownAgain =>
      'يُلصَق مرّةً، ولا يُعرَض بعدها أبداً';

  @override
  String get thisKeyIsSealedInTheVault => 'هذا المفتاح مختومٌ في الخزنة.';

  @override
  String get thisKeyIsInMemoryOnly =>
      'هذا المفتاح محفوظٌ في الذاكرة ما دام التطبيق مفتوحاً — ويذهب بإغلاقه.';

  @override
  String get noKeyIsNeededHere => 'لا يلزم مفتاحٌ في هذا العنوان.';

  @override
  String get noKeyYetWillSeal =>
      'لا مفتاحَ محفوظاً بعد. والوصلُ سيختمه في الخزنة.';

  @override
  String get noKeyYetMemoryOnly =>
      'لا مفتاحَ محفوظاً بعد. والوصلُ سيحفظه في الذاكرة ما دام التطبيق مفتوحاً.';

  @override
  String get connectingNow => 'جارٍ الوصل…';

  @override
  String get connectAct => 'صِلْ';

  @override
  String get forgetTheKey => 'انسَ المفتاح';

  @override
  String get disconnectAct => 'افصِل';

  @override
  String get couldNotTellWhereDocumentsFolderIs =>
      'لم يعرف Z Privacy أين مجلّدُ وثائقك، فلم يُخمّن. ولم يُكتب شيء.';

  @override
  String thereAreAlready200Files(String stem, String into) {
    return 'يوجد أصلاً 200 ملفٍّ باسم $stem في $into.';
  }

  @override
  String couldNotWriteInto(String into, String why) {
    return 'لم يستطع Z Privacy الكتابةَ في $into — $why.';
  }

  @override
  String couldNotBuildThePdfBecause(String why) {
    return 'لم يستطع Z Privacy بناءَ ملفّ PDF — $why. ولم يُكتب شيء.';
  }

  @override
  String get zPdfProtectedCopy => 'z-pdf · نسخةٌ محميّة';

  @override
  String placesReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موضعاً مُستبدَلاً',
      few: '$count مواضعَ مُستبدَلة',
      two: 'موضعان مُستبدَلان',
      one: 'موضعٌ واحد مُستبدَل',
    );
    return '$_temp0';
  }

  @override
  String valuesOfTheseKinds(int count, String kinds) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قيمةً ($kinds)',
      few: '$count قيمٍ ($kinds)',
      two: 'قيمتان ($kinds)',
      one: 'قيمةٌ واحدة ($kinds)',
    );
    return '$_temp0';
  }

  @override
  String get noKindsAtAll => 'لا شيء';

  @override
  String sha256OfTheProtectedText(String digest) {
    return 'بصمة sha256 للنصّ المحميّ $digest';
  }

  @override
  String zPdfAnswerLine(String token) {
    return 'Z-pdf : $token';
  }

  @override
  String couldNotAskWhereToSaveIt(String why) {
    return 'لم يستطع Z Privacy فتحَ نافذةِ الحفظ في نظامك — $why. ولم يُكتب شيء.';
  }

  @override
  String get nameThisDocument => 'سمِّ هذه الوثيقة';

  @override
  String get whatIsThisDocumentCalled => 'ما اسمُ هذه الوثيقة؟';

  @override
  String get theFileNameIsNotProtected =>
      'يبقى اسمُ الملفّ كما تكتبه بالضبط. ويخرج مع الملفّ، فلا تضع فيه أسماءً حقيقيّة.';

  @override
  String get aNameIsNeededForThisDocument => 'يلزم اسم — فالملفُّ يُسمّى به.';

  @override
  String get saveAsAPlainPdf => 'احفظ كملفّ PDF عاديّ';

  @override
  String get aPlainPdfOfTheRestoredText =>
      'يحفظ هذا الوثيقةَ أعلاه وأسماؤها فيها، ملفَّ PDF عاديّاً — لا صفحةَ جواب، ولا تذييل، ولا شيءَ يدّعي حماية. والقيمُ فيه ظاهرة.';

  @override
  String get copyTheAddressAndWriteToUs =>
      'انسخ هذا العنوان واكتب إلينا من بريدك. وZ Privacy لا يفتح شيئاً ولا يُرسِل شيئاً: فلا نموذجَ هنا ولا اتّصالَ بنا.';

  @override
  String get writeToUs => 'اكتب إلينا';

  @override
  String get describeTheProblemNotYourDocuments =>
      'صِفِ المشكلة، ولا تُرسِل وثائقك: فما يصل إلى صندوقنا ليس شيئاً نستطيع حمايته. و«انسخ التقرير»، على الشريط فوق عملك، تكتب أرقاماً عن الوثيقة ولا كلمةً منها.';

  @override
  String get howToUseZPrivacy => 'طريقة استخدام Z Privacy';

  @override
  String get theGuideOpensInYourBrowser =>
      'تُفتح الصفحةُ في متصفّحك، باللغة التي عليها هذه الواجهة. ولا يذهب شيءٌ من وثيقتك أو خزنتك مع الضغطة: متصفّحك يطلب من الموقع صفحةً، كأيّ زيارةٍ أخرى.';

  @override
  String get couldNotOpenYourBrowser =>
      'لم يستطع Z Privacy فتحَ متصفّحك. والعنوانُ على الضغطة يُفتح في أيّ متصفّحٍ باليد.';
}

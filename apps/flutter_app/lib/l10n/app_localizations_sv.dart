// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get theKeyIsBehindTheLockedVault =>
      'Z Privacy kan inte nå någon nyckel så länge valvet är låst. Lås upp det, eller ange en nyckel bara för den här gången.';

  @override
  String get theChatKeepsNothing =>
      'Det här svaret står på din skärm och ingen annanstans: ingen session är öppen som kan bevara det, så när du stänger appen försvinner det tillsammans med chatten.';

  @override
  String get theTokenIsAlreadyOurs =>
      'Det här är redan skyddat — Z satte det dit.';

  @override
  String get unnamedTrouble =>
      'Något gick fel. Z Privacy slutförde inte åtgärden.';

  @override
  String exactlyWhatWouldLeave(int replaced) {
    return 'Det här är precis vad AI:n får. $replaced värden ersattes.';
  }

  @override
  String get noLanguageAndASessionIsOpen =>
      'Ingenting lästes. En text läses med ett språks vanor, och den här sessionen har aldrig fått något — Z Privacy valde därför inte för dig. Läs den igen och svara, eller ge sessionen sitt språk i Inställningar.';

  @override
  String get noLanguageAndNoSession =>
      'Ingenting lästes. En text läses med ett språks vanor, och inget valdes — därför lästes ingenting och ingen session skapades. Försök igen och välj ett.';

  @override
  String get troubleNotImplemented =>
      'Den här delen av Z Privacy är inte byggd än.';

  @override
  String get troubleInvalidSession =>
      'Den sessionen är inte öppen längre. Börja en ny.';

  @override
  String get troubleInvalidHandle =>
      'Den här förfrågan är inte aktuell längre. Gå igenom texten igen innan du skickar.';

  @override
  String get troubleStalePayload =>
      'Dokumentet ändrades efter att den här förfrågan förbereddes. Gå igenom det igen, så att det du skickar är det du senast såg.';

  @override
  String get troubleVaultLocked =>
      'Ditt valv är låst. Lås upp det för att använda vad det vet.';

  @override
  String get troubleVaultRequired =>
      'Lås upp eller skapa ditt valv innan du sparar det här för framtida bruk.';

  @override
  String get troubleVaultAuthenticationFailed =>
      'Kunde inte låsa upp valvet. Lösenfrasen kan vara fel, eller valvet kan vara skadat eller ändrat.';

  @override
  String get troubleUnsupportedKdfParameters =>
      'Det här valvet använder säkerhetsinställningar som inte stöds.';

  @override
  String get troubleTrailingVaultData =>
      'Den här valvfilen har extra data efter sitt slut och öppnades inte.';

  @override
  String get troubleProviderUnavailable =>
      'Den AI-leverantören är inte tillgänglig i den här versionen.';

  @override
  String get oneWordWaits =>
      'Ett ord väntar på ditt svar — ingenting har lämnat Z.';

  @override
  String wordsWait(int count) {
    return '$count ord väntar på ditt svar — ingenting har lämnat Z.';
  }

  @override
  String get troubleVaultAbsent =>
      'Det finns inget valv på den här enheten än. Skapa ett för att bevara något till i morgon.';

  @override
  String get troubleVaultAlreadyExists =>
      'Det finns redan ett valv på den här enheten, och Z Privacy skriver inte över det.';

  @override
  String troubleStorageRefused(String reason) {
    return 'Z Privacy använder inte den platsen — $reason';
  }

  @override
  String get everyCellWasAlreadyProtected =>
      'Varje cell i den kolumnen var redan skyddad.';

  @override
  String protectedOneCell(String token) {
    return 'Skyddade en cell, som $token.';
  }

  @override
  String protectedCellsDownTheColumn(int places, String token) {
    return 'Skyddade $places celler nedåt i kolumnen, den första som $token.';
  }

  @override
  String protectedAs(String token) {
    return 'Skyddat som $token.';
  }

  @override
  String protectedAsInPlaces(String token, int places) {
    return 'Skyddat som $token, på $places ställen.';
  }

  @override
  String alreadyProtectedBy(String token, String who) {
    return 'Redan skyddat som $token, av $who.';
  }

  @override
  String belongsToEntity(String entity, String token) {
    return 'Det hör till $entity och behåller sin platshållare $token.';
  }

  @override
  String pressCutsIntoProtectedTextOne(String what) {
    return '$what skär in i skyddad text, därför ändrades ingenting. Den skulle utvidgas till 1 helt element.';
  }

  @override
  String pressCutsIntoProtectedTextMany(String what, int items) {
    return '$what skär in i skyddad text, därför ändrades ingenting. Den skulle utvidgas till $items hela element.';
  }

  @override
  String get theSelection => 'Markeringen';

  @override
  String get thatCell => 'Den cellen';

  @override
  String get thatPlace => 'Det stället';

  @override
  String get sourceRule => 'Regel';

  @override
  String get sourcePack => 'Språkpaket';

  @override
  String get sourceVault => 'Valv';

  @override
  String get sourceYou => 'Du';

  @override
  String get answeredByHand => 'återförd för hand';

  @override
  String get answeredNotRecorded => 'inte antecknat';

  @override
  String get oneNameCameBack => 'Ett namn kom tillbaka.';

  @override
  String namesCameBack(int count) {
    return '$count namn kom tillbaka.';
  }

  @override
  String oneNameCameBackFrom(String sessions) {
    return 'Ett namn kom tillbaka från $sessions.';
  }

  @override
  String namesCameBackFrom(int count, String sessions) {
    return '$count namn kom tillbaka från $sessions.';
  }

  @override
  String thisDocumentCameBackFrom(String sessions) {
    return 'Det här dokumentet kom tillbaka från $sessions.';
  }

  @override
  String get oneNameIsStillATokenVaultShut =>
      'Ett namn är fortfarande en platshållare: lås upp eller skapa ditt valv, då kan Z leta efter det.';

  @override
  String namesAreStillTokensVaultShut(int count) {
    return '$count namn är fortfarande platshållare: lås upp eller skapa ditt valv, då kan Z leta efter dem.';
  }

  @override
  String get oneNameStaysATokenTwoCauses =>
      'Ett namn förblir en platshållare, och två olika saker gör det: ordet skyddades innan Z Privacy började bevara varje skyddat ord, eller den här platshållaren ändrades efter att filen lämnade enheten. Öppna dokumentet i dess session och skydda namnet igen — kommer det tillbaka från då och framåt var det det första, och kommer det inte tillbaka är den här filen inte den som Z Privacy skrev.';

  @override
  String namesStayTokensTwoCauses(int count) {
    return '$count namn förblir platshållare, och två olika saker gör det: de skyddades innan Z Privacy började bevara varje skyddat ord, eller platshållarna ändrades efter att filen lämnade enheten. Öppna de dokumenten i deras session och skydda namnen igen — kommer de tillbaka från då och framåt var det det första, och kommer de inte tillbaka är den här filen inte den som Z Privacy skrev.';
  }

  @override
  String get refusalMalformedDocument =>
      'Det här dokumentet är skadat eller ofullständigt.';

  @override
  String get refusalEncryptedPdf =>
      'Den här PDF-filen är skyddad med ett lösenord. Ta bort lösenordet och försök igen.';

  @override
  String get refusalScannedOnePage =>
      'Den här PDF-filen är en bild av en sida utan text i, så ingenting kunde läsas — och Z Privacy importerar inte ett dokument det inte kan se.';

  @override
  String refusalScannedPages(int pages) {
    return 'Den här PDF-filen är $pages sidor med bilder utan text i, så ingenting kunde läsas.';
  }

  @override
  String refusalUnsupportedEncoding(int readablePercent, int page) {
    return 'Bara $readablePercent% av sidan $page gick att omvandla till tecken, därför avvisas det här dokumentet i stället för att läsas till hälften. Öppna det och spara det som text, eller klistra in texten.';
  }

  @override
  String refusalUnreadableStructure(int page) {
    return 'Sidan $page är uppbyggd på ett sätt som den här versionen inte kan läsa.';
  }

  @override
  String refusalDocumentTooLarge(int mib, int limitMib) {
    return 'Den här filen är omkring $mib MiB, och Z Privacy öppnar dokument upp till $limitMib MiB.';
  }

  @override
  String refusalTooManyPages(int pages, int limit) {
    return 'Det här dokumentet har $pages sidor, och Z Privacy öppnar upp till $limit i ett dokument.';
  }

  @override
  String refusalTextTooLarge(int limitMib) {
    return 'Uppackad är en del av den här filen större än $limitMib MiB — mer än Z Privacy läser i ett dokument, därför importerades ingenting av den.';
  }

  @override
  String refusalCompressionBomb(int ratio) {
    return 'En del av den här filen packas upp till mer än $ratio gånger den plats den tar. Inget verkligt dokument gör det, så Z Privacy slutade packa upp den i stället för att fylla datorn.';
  }

  @override
  String refusalTooManyParts(int parts, int limit) {
    return 'Den här filen räknar upp $parts delar inuti sig, och ett dokument har tiotal, inte tusental — Z Privacy öppnar upp till $limit.';
  }

  @override
  String refusalTookTooLong(int seconds) {
    return 'Läsningen av den här filen pågick fortfarande efter $seconds sekunder, så Z Privacy slutade. Ingenting av den importerades.';
  }

  @override
  String get refusalEmptyDocument =>
      'Det finns ingen text i den här filen som Z Privacy kan skydda.';

  @override
  String get networkNotConnected =>
      'Ingen AI-leverantör är ansluten. Ange en adress och en nyckel först.';

  @override
  String get networkInsecureUrl =>
      'Det går inte att skicka säkert till den adressen.';

  @override
  String get networkRedirected =>
      'Den adressen skickade oss någon annanstans. Z Privacy följer inga omdirigeringar med din text, så ingenting skickades.';

  @override
  String networkBadStatus(int status) {
    return 'Leverantören avvisade förfrågan med status $status. Z Privacy bevarade ingenting av ditt dokument.';
  }

  @override
  String get networkTimeout =>
      'Leverantören svarade inte i tid. Ingenting mer skickades.';

  @override
  String networkResponseTooLarge(int limitKib) {
    return 'Svaret var större än $limitKib KiB och lästes inte.';
  }

  @override
  String networkPayloadTooLarge(int kib, int limitKib) {
    return 'Den här texten är $kib KiB och leverantören tar emot $limitKib KiB i en förfrågan.';
  }

  @override
  String get networkUnreadable =>
      'Leverantören svarade med något som inte är ett svar.';

  @override
  String get networkUnreachable =>
      'Den adressen gick inte att nå alls — ingenting svarade. Kontrollera att du är ansluten och att adressen är rätt. Ingenting skickades.';

  @override
  String get troubleVaultChangedElsewhere =>
      'En annan kopia av Z Privacy har ändrat det här valvet. Stäng det fönstret, eller lås och lås upp här för att ta in dess arbete.';

  @override
  String get troubleSessionChangedElsewhere =>
      'Den här sessionens fil på din disk skrevs inte av det här fönstret, därför skrev Z Privacy inte över den. Stäng den andra kopian, eller lås och lås upp här för att läsa vad den skrev.';

  @override
  String troubleStoragePermissionsKept(String reason) {
    return 'Z Privacy ändrar inte en behörighet du har satt, därför sparades ingenting — $reason. Ändra behörigheten själv, eller välj en annan mapp.';
  }

  @override
  String get troubleBadSpan =>
      'Den markeringen kunde inte läsas. Försök markera orden igen.';

  @override
  String get troubleBetweenColumns =>
      'Klicket landade i utrymmet mellan två kolumner och namnger därför inget värde — och Z Privacy väljer ingen kolumn för dig.';

  @override
  String get troubleUnknownToken =>
      'Det skyddade värdet finns inte i den här sessionen.';

  @override
  String get troubleNothingToSend =>
      'Det finns ingenting att skicka än. Ta in ett dokument eller skriv någon text.';

  @override
  String get troubleSessionWithoutItsDocument =>
      'Sessionen startades inte, eftersom Z Privacy inte kunde avgöra vilket dokument du har öppet — och en session måste byta namn på det som redan är skyddat i det. Ingenting ändrades. Öppna dokumentet och starta sessionen därifrån.';

  @override
  String get troublePayloadAlreadySent =>
      'Den här förfrågan har redan skickats. Förbered den igen för att skicka en gång till.';

  @override
  String get theReasonWasNotReported => 'orsaken rapporterades inte.';

  @override
  String get carriesFirst => 'Det här dokumentet bär';

  @override
  String get carriesAlso => 'Det bär också';

  @override
  String carriesOneNameFromElsewhere(String also, String which) {
    return '$also 1 namn från en session som det här valvet inte har ($which). Ingenting här kan återställa det: nyckeln som skapade det finns inte i det här valvet.';
  }

  @override
  String carriesNamesFromOneSessionElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count namn från en session som det här valvet inte har ($which). Ingenting här kan återställa dem: nyckeln som skapade dem finns inte i det här valvet.';
  }

  @override
  String carriesNamesFromSessionsElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count namn från sessioner som det här valvet inte har ($which). Ingenting här kan återställa dem: nycklarna som skapade dem finns inte i det här valvet.';
  }

  @override
  String carriesNamesFromElsewhereWithNoCount(
    String also,
    String whose,
    String which,
    String keys,
  ) {
    return '$also namn från $whose ($which). Ingenting här kan återställa dem: $keys inte i det här valvet.';
  }

  @override
  String get aSessionThisVaultDoesNotHold =>
      'en session som det här valvet inte har';

  @override
  String get sessionsThisVaultDoesNotHold =>
      'sessioner som det här valvet inte har';

  @override
  String get theKeyThatMadeThemIs => 'nycklarna som skapade dem finns';

  @override
  String get andBetweenNames => ' och ';

  @override
  String get thisLanguageName => 'Svenska';

  @override
  String get languageWord => 'Språk';

  @override
  String get chooseALanguage => 'Välj ett språk för att fortsätta.';

  @override
  String get noAccount => 'Inget konto.';

  @override
  String get noAds => 'Inga annonser.';

  @override
  String get noAnalytics => 'Ingen analys- eller spårningsdata.';

  @override
  String get noZPrivacyServer => 'Ingen Z Privacy-server.';

  @override
  String get originalDataStaysHere =>
      'Dina originaldata stannar på den här enheten om du inte uttryckligen kopierar återställt innehåll.';

  @override
  String get onlyTheProtectedVersionIsSent =>
      'Bara den skyddade versionen skickas till AI:n via Z Privacy.';

  @override
  String get theseRulesWillBeEnabled =>
      'De svenska integritetsreglerna aktiveras.';

  @override
  String get start => 'Starta';

  @override
  String get yourVault => 'Ditt valv';

  @override
  String get createAVault => 'Skapa ett valv';

  @override
  String get vaultWhy =>
      'Varje ord du skyddar lever här, så länge du behåller det här valvet: namnen du lägger till, värdena du lär ut, och nycklarna till varje AI du ansluter. Det stannar på den här datorn, och ingenting skrivs någon annanstans.';

  @override
  String get onePassphrase =>
      'En lösenfras, bevarad på den här enheten. Allt Z lär sig medan du arbetar — dina namn, dina listor, dina beslut — bevaras i den.';

  @override
  String get byYourVoices => 'av YourVoices';

  @override
  String pageHasNothingMarked(int page) {
    return 'På sidan $page har granskningen inte markerat något.';
  }

  @override
  String get addADocumentPdfWordOrText =>
      'Lägg till ett dokument — PDF, Word eller text';

  @override
  String get addADocumentOrWriteToTheAi =>
      'Lägg till ett dokument — eller skriv till AI:n i den första delen, helt utan dokument.';

  @override
  String get originalLocalOnly => 'Original — bara lokalt';

  @override
  String get neverSentToAiSendCannotRead =>
      'Skickas aldrig till AI:n · Skicka kan inte läsa den här sidan';

  @override
  String get yourDocumentArrivesHere =>
      'Ditt dokument kommer hit, så som det är skrivet. Ingenting på den här sidan kan nå nätet.';

  @override
  String get safeAiWillReceive => 'Skyddat — det här får AI:n';

  @override
  String get theRequestItselfNotAPreview =>
      'Förfrågan själv, ingen förhandsvisning av den';

  @override
  String get whatAnAiWouldReceiveStandsHere =>
      'Vad en AI skulle få står här vid sidan av originalet, ord för ord, innan något skickas.';

  @override
  String get theChatTitle => 'Chatten';

  @override
  String get yourQuestionsAndWhatCameBack =>
      'Dina frågor, och vad som kom tillbaka';

  @override
  String get theChatOpensHereWithTheFirstAnswer =>
      'Chatten öppnas här med det första svaret, och varje fråga efter den bär med sig utbytet före den.';

  @override
  String get typedText => 'Inskriven text';

  @override
  String get onePage => '1 sida';

  @override
  String pagesCount(int pages) {
    return '$pages sidor';
  }

  @override
  String get vaultLabel => 'Valv';

  @override
  String get vaultIsUnlocked => 'Upplåst';

  @override
  String get vaultIsLocked => 'Låst';

  @override
  String get vaultIsNone => 'Inget';

  @override
  String get yourVaultIsIn => 'Ditt valv ligger i';

  @override
  String get aVaultHereWouldBeIn => 'Ett valv skulle här ligga i';

  @override
  String get openZVault => 'Öppna Z-valvet';

  @override
  String get lockNow => 'Lås nu';

  @override
  String get openZVaultOrLockItNow => 'Öppna Z-valvet, eller lås det nu';

  @override
  String get goToAPage => 'Gå till en sida';

  @override
  String pageNumber(int page) {
    return 'Sida $page';
  }

  @override
  String get pageWord => 'Sida';

  @override
  String get chooseTheAiAndWhatTravels => 'Välj AI:n och vad som går till den';

  @override
  String get readThisDocumentWithAnotherRuleSet =>
      'Läs det här dokumentet med en annan regeluppsättning';

  @override
  String get generalRulesOnly => 'Bara allmänna regler';

  @override
  String get packLabel => 'Språkpaket';

  @override
  String packWithGeneralRules(String pack) {
    return '$pack · allmänna regler';
  }

  @override
  String get everywhere => 'Överallt';

  @override
  String get profile => 'Profil';

  @override
  String get profiles => 'Profiler';

  @override
  String get chooseWhichClientDictionary =>
      'Välj vilket kundregister den här sessionen använder. Profil-ID:t stannar inne i valvet; visningsnamnet är vad människor ser.';

  @override
  String get onlyIdentitiesForEveryProfile =>
      'Bara identiteter och regler som gäller för varje profil.';

  @override
  String get createProfile => 'Skapa profil';

  @override
  String get done => 'Klart';

  @override
  String get rename => 'Byt namn';

  @override
  String get profileActive => 'Aktiv';

  @override
  String get profileSwitch => 'Byt';

  @override
  String get readItBack => 'Läs tillbaka';

  @override
  String get scanning => 'Granskar…';

  @override
  String get notScannedYet => 'Inte granskat än';

  @override
  String get asItWasKept => 'Som det bevarades';

  @override
  String lastScanNote(String note) {
    return 'Senaste granskning: $note';
  }

  @override
  String get scannedAsYouTyped => 'Granskat medan du skrev';

  @override
  String get scannedOnImport => 'Granskat vid import';

  @override
  String get lastScanManualRescan =>
      'Senaste granskning: granskad igen för hand';

  @override
  String alreadyProtectedNothingScanned(int marks) {
    return '$marks redan skyddade · ingenting granskat i den här omgången';
  }

  @override
  String protectedAutomaticallyNeedYourWord(int auto, int open, int normal) {
    return '$auto automatiskt skyddade · $open behöver ditt ord · $normal normala';
  }

  @override
  String get vaultLockedRulesAndPackRan =>
      'Valvet låst — regler och språkpaket kördes, valvskiktet inte';

  @override
  String get noVaultNothingRecognisedByName =>
      'Inget valv — ingenting känns igen på namnet';

  @override
  String get unlock => 'Lås upp';

  @override
  String get removeTheDocument => 'Ta bort dokumentet';

  @override
  String get nothingIsOpen => 'Ingenting är öppet.';

  @override
  String get thereIsNothingToSendYet => 'Det finns ingenting att skicka än.';

  @override
  String get readingWhatThoseLinesHold => 'Läser vad de raderna innehåller…';

  @override
  String oneLineProtectedOpen(int protected, int open) {
    return '1 rad · $protected skyddade i den · $open öppna';
  }

  @override
  String linesProtectedOpen(int lines, int protected, int open) {
    return '$lines rader · $protected skyddade i dem · $open öppna';
  }

  @override
  String get pressAValueToProtectEveryHeldLine =>
      'Tryck på ett värde för att skydda samma cell i varje hållen rad.';

  @override
  String get letTheLinesGo => 'Släpp raderna';

  @override
  String get inStep => 'I takt';

  @override
  String get apart => 'Var för sig';

  @override
  String get drawnAsChips => 'Brickor';

  @override
  String get drawnPlain => 'Enkel';

  @override
  String get oneSuggestionStillOpen =>
      'Ett förslag är fortfarande öppet. Tills du svarar på det står det här som skrivet — verklig text på den här sidan.';

  @override
  String suggestionsStillOpen(int open) {
    return '$open förslag är fortfarande öppna. Tills du svarar på dem står de här som skrivna — den enda verkliga texten på den här sidan.';
  }

  @override
  String get chooseWhoAnswers => 'Välj vem som svarar';

  @override
  String get showTheChat => 'Visa chatten';

  @override
  String get whatWouldYouLikeToAskTheAi => 'Vad vill du fråga AI:n?';

  @override
  String get whatShouldTheAiDoWithThis => 'Vad ska AI:n göra med det här?';

  @override
  String get askAQuestionOrPasteALetter =>
      'Ställ en fråga, eller klistra in ett helt brev här.';

  @override
  String get reconcileSectionAgainstSection =>
      'Jämför avsnitt A med avsnitt B och säg var skillnaden ligger.';

  @override
  String get inWhatWillLeave => 'I det som går ut';

  @override
  String get addItToWhatWillLeave => 'Lägg till det i det som går ut';

  @override
  String get aDocumentCanBeSentWithNoRequest =>
      'Ett dokument kan skickas utan förfrågan, och då får modellen ingen instruktion';

  @override
  String get takeItOut => 'Ta ut det';

  @override
  String get yourRequestNothingToProtect =>
      'Din förfrågan står i den skyddade kolumnen, utan något i den att skydda.';

  @override
  String get yourRequestOneValueReplaced =>
      'Din förfrågan står i den skyddade kolumnen, med ett ersatt värde.';

  @override
  String yourRequestValuesReplaced(int count) {
    return 'Din förfrågan står i den skyddade kolumnen, med $count ersatta värden.';
  }

  @override
  String get oneRequestAtATime =>
      'En förfrågan i taget — en ny fråga ersätter den här, och chatten behåller varje utbyte.';

  @override
  String get oneQuestionLeftGoToIt => '1 fråga kvar — gå dit';

  @override
  String questionsLeftGoToTheFirst(int open) {
    return '$open frågor kvar — gå till den första';
  }

  @override
  String get protectIt => 'Skydda';

  @override
  String get leaveItInTheClear => 'Lämna i klartext';

  @override
  String theOneLeftIsKind(String kind) {
    return 'Den som återstår är $kind.';
  }

  @override
  String get showWhatTheAiWillReceive => 'Visa vad AI:n får';

  @override
  String get hideThisColumn => 'Göm den här kolumnen';

  @override
  String get narrowThisPanel => 'Gör det här fältet smalare';

  @override
  String get widenThisPanel => 'Gör det här fältet bredare';

  @override
  String get oneExchangeCarriedIntoTheNext =>
      'Ett utbyte, som tas med in i nästa fråga.';

  @override
  String exchangesCarriedIntoTheNext(int count) {
    return '$count frågor och svar, som tas med in i nästa fråga.';
  }

  @override
  String get putTheChatAwayItIsNotEnded =>
      'Lägg chatten åt sidan — den är inte avslutad';

  @override
  String get theFirstAnswerOpensTheChatHere =>
      'Det första svaret öppnar chatten här. Varje fråga efter den bär med sig utbytet före den — inte hela chatten, och aldrig dokumentet igen.';

  @override
  String get askSomethingElseAboutThis => 'Fråga något annat om det här…';

  @override
  String get pasteTheAnswerYouWereGiven => 'Klistra in svaret du fick…';

  @override
  String get addItToTheChat => 'Lägg till det i chatten';

  @override
  String get notNow => 'Inte nu';

  @override
  String get copyTheChat => 'Kopiera chatten';

  @override
  String get addAnAnswer => 'Lägg till ett svar';

  @override
  String get endTheChat => 'Avsluta chatten';

  @override
  String get theChatIsOnYourClipboard =>
      'Det som skulle lämna ligger skyddat i ditt urklipp — frågan som en AI skulle få den. Hämta tillbaka svaret med «Lägg till ett svar».';

  @override
  String get couldNotReadTheClipboard => 'Z Privacy kunde inte läsa urklippet.';

  @override
  String get thereIsNoTextOnTheClipboard => 'Det finns ingen text i urklippet.';

  @override
  String get hideTheText => 'Göm texten';

  @override
  String get showTheText => 'Visa texten';

  @override
  String get theTextWithYourNamesBack =>
      'Texten, med dina namn tillbaka — på den här enheten';

  @override
  String get thisAnswerCarriesOneUnknownToken =>
      'Det här svaret innehåller 1 platshållare som den här sessionen inte känner — den skapades i en annan session.';

  @override
  String thisAnswerCarriesUnknownTokens(int count) {
    return 'Det här svaret innehåller $count platshållare som den här sessionen inte känner — de skapades i en annan session.';
  }

  @override
  String get copyRestored => 'Kopiera återställt';

  @override
  String get theMarkedWordsWerePutBackHere =>
      'De markerade orden sattes tillbaka här, på den här enheten. Modellen såg dem aldrig.';

  @override
  String get theDottedWordsWerePutBackHere =>
      'De punktade orden sattes tillbaka här, på den här enheten. De överstrukna är platshållare som den här sessionen inte kan hämta tillbaka.';

  @override
  String get copyRestoredTextQuestion => 'Kopiera återställd text?';

  @override
  String get thisWillPlaceTheRealValues =>
      'Det här lägger de verkliga skyddade värdena i systemets urklipp. Andra program kan möjligen läsa urklippet.';

  @override
  String get cancel => 'Avbryt';

  @override
  String get restoredTextCopied =>
      'Återställd text kopierad till systemets urklipp.';

  @override
  String get chooseWhoAnswersInTheMiddleFirst =>
      'Välj först i mittenkolumnen vem som svarar';

  @override
  String sendThisQuestionTo(String name) {
    return 'Skicka den här frågan till $name';
  }

  @override
  String get writeAQuestionFirst => 'Skriv en fråga först.';

  @override
  String get settings => 'Inställningar';

  @override
  String get roomPrivacy => 'Integritet';

  @override
  String get roomLanguageAndRules => 'Språk & regler';

  @override
  String get roomVaultAndSecurity => 'Valv & säkerhet';

  @override
  String get roomSessions => 'Sessioner';

  @override
  String get languageAndRulesWhat =>
      'Ett integritetspaket är en igenkänningsmotor, inte gränssnittets språk — och fler än ett paket kan köras i en och samma granskning, så det här är en utgångspunkt och inte de enda tillåtna reglerna.';

  @override
  String get appLanguage => 'Appens språk';

  @override
  String get appLanguageWhat =>
      'Språket en session läses med när den inte har något eget — och vilka vanor granskningen känner i det: hälsningar, bolagsformer, sättet ett kundnummer skrivs. En session som skapats med ett eget språk behåller det; allt annat läses med det här. Gränssnittet följer det här valet.';

  @override
  String theInterfaceIsEnglishUntilTranslated(String language) {
    return '$language: igenkänningspaketet är $language; gränssnittet är engelskt tills dess satser är översatta.';
  }

  @override
  String get myPrivacyRules => 'Mina integritetsregler';

  @override
  String get myPrivacyRulesWhat =>
      'Inte byggt än. Regler du skriver själv — ett kundnummerformat som bara ditt kontor använder, ett projektkodnamn — kommer att leva här, vid sidan av paketet och inte inuti det.';

  @override
  String get vaultAndSecurityWhat =>
      'Nyckeln, låset, och var inloggningsuppgifter ligger.';

  @override
  String get zVault => 'Z-valvet';

  @override
  String get vaultOpenWhat =>
      'Upplåst. Dina identiteter är inlästa och det fjärde igenkänningsskiktet körs.';

  @override
  String get vaultLockedWhat =>
      'Låst. Reglerna och paketet körs fortfarande — ett IBAN fångas fortfarande — men inte vem det tillhör.';

  @override
  String get vaultAbsentWhat =>
      'Inte skapat på den här enheten. Ingenting känns igen på namnet.';

  @override
  String unlockedWithIdentities(int count) {
    return 'Upplåst · $count identiteter';
  }

  @override
  String get zPdfReadBack => 'z-pdf — läs tillbaka ett skyddat dokument';

  @override
  String get zPdfWhat =>
      'Den omvända handlingen. Ett dokument som lämnat den här appen med platshållare i läses här tillbaka till sina egna namn ur ditt valv — och det granskas aldrig, skyddas aldrig och läggs aldrig på en arbetsbänk. Ingenting av det skickas någonstans.';

  @override
  String get openThisPanelFromTheApp =>
      'Öppna det här fältet från appen för att välja en fil.';

  @override
  String get chooseAZPdfFile => 'Välj en z-pdf-fil';

  @override
  String get lockTheVaultAfter => 'Lås valvet efter';

  @override
  String get minutesUnusedZeroIsNever => 'minuter utan användning · 0 = aldrig';

  @override
  String get lockTheVaultAfterWhat =>
      'Hålls av valvet självt, inte av en timer i en skärm: varje väg in i det läser klockan först, så ett fel i gränssnittet kan inte lämna det öppet.';

  @override
  String get encryptedLocalCredentialStorage =>
      'Krypterad lokal lagring av inloggningsuppgifter';

  @override
  String get credentialHomesWhat =>
      'En leverantörsnyckel har två hem och inget tredje: förseglad inne i valvet när ett är öppet, eller i minnet så länge appen är öppen när det inte finns något. Aldrig en fil i klartext, och aldrig tillbaka till gränssnittet — det finns inget anrop i hela kontraktet som ger en tillbaka.';

  @override
  String get credentialSealedInTheVault => 'förseglad i valvet';

  @override
  String get credentialInMemory => 'i minnet, borta när appen stängs';

  @override
  String get credentialNoKeyStored => 'ingen nyckel sparad';

  @override
  String get noProviderHoldsACredential =>
      'Ingen leverantör håller några inloggningsuppgifter.';

  @override
  String get deviceBoundProtection => 'Enhetsbundet skydd';

  @override
  String get deviceBoundWhat =>
      'Inte byggt än. En nyckel som är bunden till den här enhetens egen autentisering skulle ligga ovanpå skiktet ovan, utan att ändra vad som lagras — samma uppgifter, ett lås till.';

  @override
  String get sessionsWhat =>
      'En session har sin egen nyckel, och nycklarna ligger i valvet.';

  @override
  String get theVaultIsShutNoSessions =>
      'Valvet är låst, så det finns inga sessioner att visa. Lås upp det och de kommer tillbaka — samtalen själva låg aldrig i det.';

  @override
  String get eachSessionHasItsOwnEncryption =>
      'Varje session har sin egen kryptering. Samma namn tar två olika platshållare i två sessioner, och i en session samma överallt — en session är alltså hur du väljer vad en AI kan lägga samman och vad den inte kan.';

  @override
  String get newSession => 'Ny session';

  @override
  String get newSessionWhat =>
      'Ett namn och ett språk, båda dina att välja: språket är hur Z läser varje text i den här sessionen, och det frågas en gång här. Den blir med en gång den session du arbetar i. Det som redan är skyddat på dokumentet framför dig byter namn in i den — ingenting har skickats än, så ingenting som lämnat enheten påverkas.';

  @override
  String get whatIsThisOneAbout => 'Vad handlar den här om?';

  @override
  String get begin => 'Börja';

  @override
  String get noSessionsYet => 'Inga sessioner än';

  @override
  String get noSessionsYetWhat =>
      'En föds första gången du kopierar skyddad text eller ber om en PDF — den avvisas inte för att den saknar namn, den tar sitt eget nummer som namn, och du kan byta namn på den här. Du behöver aldrig skapa en för hand först.';

  @override
  String theOneYouAreIn(String when, String exchanges) {
    return '$when · $exchanges · den du är i';
  }

  @override
  String get workInThisSession => 'Arbeta i den här sessionen';

  @override
  String get enter => 'Gå in';

  @override
  String get renameThisSession => 'Byt namn på den här sessionen';

  @override
  String get deleteThisSession => 'Ta bort den här sessionen';

  @override
  String get oneExchange => '1 utbyte';

  @override
  String exchangesCount(int count) {
    return '$count frågor och svar';
  }

  @override
  String renameSessionNumber(int number) {
    return 'Byt namn på session $number?';
  }

  @override
  String theNumberStaysWhatItIs(int number) {
    return 'Numret förblir $number — det är vad den här sessionen är, och ingenting som skyddades i den ändras. Bara ordet på raden gör det.';
  }

  @override
  String get keepTheName => 'Behåll namnet';

  @override
  String get renameIt => 'Byt namn';

  @override
  String deleteNamed(String name) {
    return 'Ta bort «$name»?';
  }

  @override
  String get thisDestroysTheKey =>
      'Det här förstör nyckeln som den här sessionen skyddades med.';

  @override
  String get everyDocumentCanNeverBeUnprotected =>
      'Det som redan har lämnat den här sessionen skyddat kan aldrig befrias från sitt skydd igen — inte av dig, och inte av Z Privacy. Nyckeln var det enda som hade kunnat göra det, och den kommer inte att finnas. «Ta tillbaka skyddet» tar bort en täckning från texten framför dig, aldrig från det som redan är borta.';

  @override
  String get anythingYouSentStaysAsItWas =>
      'Det du har skickat ut ur den här sessionen förblir precis som det var. Det som försvinner är vägen tillbaka från det.';

  @override
  String get keepIt => 'Behåll';

  @override
  String get deleteTheSession => 'Ta bort sessionen';

  @override
  String get oneProtectedPlace => '1 skyddat ställe';

  @override
  String protectedPlacesCount(int count) {
    return '$count skyddade ställen';
  }

  @override
  String get renameThisDocument => 'Byt namn på det här dokumentet';

  @override
  String renameHandle(String handle) {
    return 'Byt namn på $handle?';
  }

  @override
  String theNameIsWhatYouRead(String handle) {
    return 'Namnet är vad du läser i den här listan. $handle förblir vad det är: ett nummer ges ut en gång och ges aldrig till ett annat dokument.';
  }

  @override
  String get aNameForThisDocument => 'Ett namn för det här dokumentet';

  @override
  String get roomAi => 'AI';

  @override
  String get aiWhat =>
      'Tre vägar att fråga en modell. Den första behöver inget konto alls.';

  @override
  String get manualAi => 'Manuell AI';

  @override
  String get manualAiWhat =>
      'Använd en AI-chatt du redan har. Kopiera den skyddade texten ur arbetsytan, klistra in den i vilken modell du nu använder, och hämta tillbaka svaret. Ingenting att ställa in, ingenting att betala för, och återställningen fungerar precis likadant.';

  @override
  String get alwaysAvailableFirstDoor =>
      'Alltid tillgänglig — det är bladet «Välj vem som svarar», första dörren.';

  @override
  String get directApi => 'Direkt API';

  @override
  String get directApiWhat =>
      'Anslut till en AI-leverantör på distans med dina API-uppgifter. Nyckeln går in en gång och kommer aldrig ut igen — ingen skärm i den här appen kan visa den för dig på nytt.';

  @override
  String get atThisAddressNoCredential =>
      'På den här adressen behövs inga inloggningsuppgifter.';

  @override
  String get protocol => 'Protokoll';

  @override
  String get connectedKeySealed => 'Ansluten · nyckeln förseglad i valvet';

  @override
  String get connectedKeyThisRunOnly =>
      'Ansluten · nyckeln bevarad bara så länge appen är öppen';

  @override
  String get connectedNoKeyNeeded => 'Ansluten · ingen nyckel behövs';

  @override
  String get notConnected => 'Inte ansluten';

  @override
  String get localAi => 'AI på den här datorn';

  @override
  String get localAiWhat =>
      'Körs genom en AI-tjänst på den här datorn — llama.cpp, Ollama, LM Studio, allt som svarar i samma form. Ingen nyckel, inget konto, och förfrågan lämnar aldrig den här datorn. Vanlig http accepteras bara för en bokstavlig loopback-adress.';

  @override
  String get models => 'Modeller';

  @override
  String get privacyWhat =>
      'Vad appen gör av sig själv, och hur långt den går utan att fråga.';

  @override
  String get noVaultSoThisRunOnly =>
      'Det finns inget öppet valv, så det här gäller bara så länge appen är öppen — utan valv finns det ingenting att bevara det i.';

  @override
  String get scanOnArrival =>
      'Granska ett dokument i samma stund det kommer in';

  @override
  String get scanOnArrivalWhat =>
      'Ingen dialog, ingen knapp. Att stänga av det här betyder att ett dokument ligger oskyddat tills du trycker «Granska igen» — precis det ögonblick som utkasten skrevs för att undvika.';

  @override
  String get answerEverySuggestion => 'Svara på varje förslag innan du skickar';

  @override
  String get answerEverySuggestionWhat =>
      'Ingen inställning. Ett förslag som inte har besvarats behandlas aldrig tyst som säkert, och det finns inget «skicka ändå» — inte här, inte i en gömd inställning, ingenstans i koden.';

  @override
  String get aRevealedValueStaysFor => 'Ett avtäckt värde står kvar i';

  @override
  String get aRevealedValueStaysForWhat =>
      'Att avtäcka ritar på skärmen och skriver aldrig in i det som går ut. Det här är bara hur länge det står ritat.';

  @override
  String get tokenRotation => 'Byte av platshållare';

  @override
  String get tokenRotationWhat =>
      'Inte byggt än. När det kommer kommer det att leva här: om en varaktig platshållare behåller sitt nummer över sessioner, eller dras på nytt varje gång så att två sessioner inte kan knytas samman genom den.';

  @override
  String get back => 'Tillbaka';

  @override
  String get allIdentities => 'Alla identiteter';

  @override
  String identitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identiteter',
      one: '1 identitet',
    );
    return '$_temp0';
  }

  @override
  String valuesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count värden',
      one: '1 värde',
    );
    return '$_temp0';
  }

  @override
  String protectedWordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skyddade ord',
      one: '1 skyddat ord',
    );
    return '$_temp0';
  }

  @override
  String get notCreatedOnThisDevice => 'Inte skapat på den här enheten';

  @override
  String get changePassphrase => 'Byt lösenfras';

  @override
  String get lockTheVault => 'Lås';

  @override
  String get theVaultIsLocked => 'Valvet är låst';

  @override
  String get thereIsNoVaultYet => 'Det finns inget valv än';

  @override
  String get yourIdentitiesAreSealed =>
      'Dina identiteter ligger på den här enheten, förseglade. Tills det är öppet kör granskningen fortfarande sina regler och sitt språkpaket — ett IBAN fångas fortfarande — men inte vem.';

  @override
  String get yourNamesLiveInOneVaultFile =>
      'Dina namn lever i en enda krypterad valvfil. Den innehåller dina människor och deras värden, krypterade med en lösenfras som aldrig lämnar den här enheten. Utan en känns ingenting igen på namnet.';

  @override
  String get searchThisDevice =>
      'Sök på den här enheten — namn, värden, skrivningar';

  @override
  String get newIdentity => 'Ny identitet';

  @override
  String get filterAll => 'Alla';

  @override
  String get sessionProfile => 'Sessionens profil';

  @override
  String get newProfile => 'Ny profil';

  @override
  String get noIdentitiesYet =>
      'Inga identiteter än. Den första är oftast kunden vars dokument du arbetar med.';

  @override
  String nothingMatchesQuery(String query) {
    return 'Ingenting på den här enheten passar «$query».';
  }

  @override
  String get valuesITaught => 'Värden jag lärt ut';

  @override
  String get valuesITaughtWhat =>
      'namn, företag, nummer — hittas av sig själva från och med nu';

  @override
  String get rulesITaught => 'Regler jag lärt ut';

  @override
  String get rulesITaughtWhat =>
      'ord som säger vad som kommer efter dem — «efter Mandantenkennung → kundnummer»';

  @override
  String get exceptionsITaught => 'Undantag jag lärt ut';

  @override
  String get exceptionsITaughtWhat =>
      'värden du uttryckligen har undantagit från skydd';

  @override
  String get noTaughtValuesYet => 'Inga utlärda värden än.';

  @override
  String get noRulesTaughtYet => 'Inga utlärda regler än.';

  @override
  String get noSavedExceptionsYet => 'Inga sparade undantag än.';

  @override
  String kindScopeTaughtOn(String kind, String scope, String date) {
    return '$kind · $scope · Inlärt: $date';
  }

  @override
  String doNotProtectAsKindScopeTaughtOn(
    String kind,
    String scope,
    String date,
  ) {
    return 'Skydda inte som $kind · $scope · Inlärt: $date';
  }

  @override
  String get reveal => 'Avtäck';

  @override
  String get hide => 'Dölj';

  @override
  String get theExceptionGoes =>
      'undantaget — det här värdet kommer att erbjudas för skydd igen';

  @override
  String get theRuleGoes =>
      'regeln — Z Privacy slutar skydda det som kommer efter det ordet';

  @override
  String get openIdentity => 'Öppna';

  @override
  String profileNamed(String name) {
    return 'Profil: $name';
  }

  @override
  String get taughtOnUnknown => 'okänt';

  @override
  String afterLabelProtectAs(String label, String kind) {
    return 'Efter «$label:» → $kind';
  }

  @override
  String get teachARule => 'Lär ut en regel';

  @override
  String get kindClient => 'Kund';

  @override
  String get kindPerson => 'Person';

  @override
  String get kindCompany => 'Företag';

  @override
  String get kindProject => 'Projekt';

  @override
  String get kindSomethingElse => 'Något annat';

  @override
  String vaultFileNotChanged(String said) {
    return '$said Z Privacy har inte ändrat filen. Om du har en säkerhetskopia av valvet, lägg tillbaka den; annars flytta den här filen någon annanstans, och ett nytt valv kan skapas här.';
  }

  @override
  String get changeThePassphrase => 'Byt lösenfrasen';

  @override
  String get onlyThirtyTwoBytes =>
      'Bara 32 byte packas om — valvet självt dekrypteras inte och skrivs inte om. Allt i det ligger kvar precis där det är.';

  @override
  String get currentPassphrase => 'Nuvarande lösenfras';

  @override
  String get passphrase => 'Lösenfras';

  @override
  String get newPassphrase => 'Ny lösenfras';

  @override
  String get confirmPassphrase => 'Bekräfta lösenfrasen';

  @override
  String get confirmNewPassphrase => 'Bekräfta den nya lösenfrasen';

  @override
  String get passphrasesMatch => 'Lösenfraserna stämmer';

  @override
  String get passphrasesDoNotMatch => 'Lösenfraserna stämmer inte';

  @override
  String atLeastCharacters(int count) {
    return 'Minst $count tecken — med färre skapas inte valvet.';
  }

  @override
  String get thereIsNoWayBack =>
      'Det finns ingen väg tillbaka. Ingen har en kopia av den här, och det finns ingen återställning — lösenfrasen lämnar aldrig den här enheten, och ingenting på vår sida skulle kunna rädda valvet utan den.';

  @override
  String get working => 'Arbetar…';

  @override
  String get changeIt => 'Byt';

  @override
  String get createTheVault => 'Skapa valvet';

  @override
  String get unlockTheVault => 'Lås upp';

  @override
  String hideNamed(String label) {
    return 'Dölj $label';
  }

  @override
  String showNamed(String label) {
    return 'Visa $label';
  }

  @override
  String get aNewIdentity => 'En ny identitet';

  @override
  String get anIdentityIsHowAPersonThinks =>
      'En identitet är hur en människa tänker — «Kund Nordstern» — och värdena i den är vad granskningen känner igen.';

  @override
  String get nameField => 'Namn';

  @override
  String get sortField => 'Typ';

  @override
  String get loadedIn => 'Inläst i';

  @override
  String get exampleClientNordstern => 'Kund Nordstern';

  @override
  String get exampleCompanyName => 'Nordstern Consulting GmbH';

  @override
  String get cancelForm => 'Avbryt';

  @override
  String get createIt => 'Skapa';

  @override
  String get aNewValue => 'Ett nytt värde';

  @override
  String get editThisValue => 'Redigera det här värdet';

  @override
  String get theValue => 'Värdet';

  @override
  String get readingItFromTheVault => 'läses ur valvet…';

  @override
  String get whatItIs => 'Vad det är';

  @override
  String get howToTreatIt => 'Hur det ska hanteras';

  @override
  String get alwaysProtect => 'Skydda alltid';

  @override
  String get alwaysProtectWhat =>
      'Hittas av sig själv och ersätts, utan fråga.';

  @override
  String get suggestPolicy => 'Föreslå';

  @override
  String get suggestPolicyWhat =>
      'Hittas och läggs fram för dig innan något skickas.';

  @override
  String get keepDoNotHunt => 'Behåll, leta inte';

  @override
  String get keepDoNotHuntWhat =>
      'Behålls så att dess skrivningar och dess platshållare förblir stabila — men letas inte efter.';

  @override
  String get saveIt => 'Spara';

  @override
  String get aNewProfile => 'En ny profil';

  @override
  String get renameProfile => 'Byt namn på profilen';

  @override
  String get oneDictionaryPerClient =>
      'Ett register per kund. Bara identiteterna i den profil du öppnar läses in — att öppna valvet är ingen blankocheck.';

  @override
  String get theProfileIdStaysTheSame =>
      'Profil-ID:t förblir detsamma. Bara namnet en människa läser ändras.';

  @override
  String get languagesUsedInDocuments => 'Språk i dokumenten';

  @override
  String get moreThanOneMayBeOn =>
      'Fler än ett kan vara på. Ett dokument med ett tyskt och ett engelskt fältnamn läses av båda i en och samma granskning.';

  @override
  String get renameIt2 => 'Byt namn';

  @override
  String get teachARuleHead => 'Lär ut en regel';

  @override
  String get aRuleIsAWordAndWhatComesAfter =>
      'En regel är ett ord och vad som kommer efter det. Z Privacy skyddar värdet som följer och slutar vid slutet av det fältet.';

  @override
  String get whenZPrivacySees => 'När Z Privacy ser';

  @override
  String get exampleMandantenkennung => 'Mandantenkennung';

  @override
  String get protectTheValueAfterItAs => 'Skydda värdet efter det som';

  @override
  String get whereField => 'Var';

  @override
  String profileNamedDash(String name) {
    return 'Profil — $name';
  }

  @override
  String get saveRule => 'Spara regeln';

  @override
  String get removeProtectionHere => 'Ta bort skyddet här';

  @override
  String removeItInThisSession(int places) {
    return 'Ta bort det i den här sessionen ($places ställen)';
  }

  @override
  String get forgetFromThisProfile => 'Glöm från den här profilen';

  @override
  String get forgetEverywhere => 'Glöm överallt';

  @override
  String get protectThisColumnInTheLineHeld =>
      'Skydda den här kolumnen i den hållna raden';

  @override
  String protectThisColumnInLinesHeld(int lines) {
    return 'Skydda den här kolumnen i de $lines hållna raderna';
  }

  @override
  String get whyIsThisProtected => 'Varför är det här skyddat?';

  @override
  String get theSameCellOfEveryHeldLine =>
      'Samma cell i varje hållen rad, varje värde med sin egen platshållare. Den här är redan skyddad och förblir som den är.';

  @override
  String get whatItIsRow => 'Vad det är';

  @override
  String get whereItApplies => 'Var det gäller';

  @override
  String get decidedBy => 'Beslutat av';

  @override
  String get decidedByYou => 'Du';

  @override
  String get decidedByZPrivacy => 'Z Privacy, av sig själv';

  @override
  String get taughtOnRow => 'Inlärt den';

  @override
  String get tokenRow => 'Platshållare';

  @override
  String otherSpellingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count andra skrivningar',
      one: '1 annan skrivning',
    );
    return '$_temp0';
  }

  @override
  String get close => 'Stäng';

  @override
  String get uncoversThisOnePlace =>
      'Avtäcker det här enda stället. Varje annat ställe behåller sitt skydd, och sin platshållare.';

  @override
  String get theValueStaysInYourRules =>
      'Värdet stannar i dina integritetsregler och kan skyddas igen senare.';

  @override
  String get uncoversEveryPlaceInThisSession =>
      'Avtäcker varje ställe den här platshållaren står på, i den här sessionen.';

  @override
  String get thereIsNoEverywhere =>
      'Det finns inget «överallt»: att ta bort skyddet räcker inte längre än en session.';

  @override
  String get removesWhatZLearnedForThisProfile =>
      'Tar bort vad Z Privacy har lärt sig för den här profilen.';

  @override
  String get protectionAlreadyAppliedStays =>
      'Skydd som redan tillämpats i det här dokumentet ligger kvar.';

  @override
  String get removesWhatZLearnedEverywhere =>
      'Tar bort vad Z Privacy har lärt sig, i varje profil.';

  @override
  String get forgetThisRule => 'Glöm den här regeln';

  @override
  String get theRuleItselfIsKept => 'Regeln själv behålls i ditt valv.';

  @override
  String get forgetItInZVaultRules =>
      'Glöm den i Z-valvet → Mina integritetsregler → Regler jag lärt ut.';

  @override
  String get nothingWasLearnedYouProtectedIt =>
      'Ingenting lärdes av det här — du skyddade det här, och «Ta tillbaka skyddet» tar tillbaka det.';

  @override
  String get nothingWasLearnedARuleSawIt =>
      'Ingenting lärdes av det här. En regel kände igen formen, och ingenting av den bevarades.';

  @override
  String forgottenButStillKnownBy(String who) {
    return 'Glömt, men $who känner fortfarande igen det. Säg det till oss — det här ska inte vara möjligt.';
  }

  @override
  String forgetNamed(String what) {
    return 'Glöm «$what»?';
  }

  @override
  String get thisWillRemove => 'Det här tar bort';

  @override
  String protectedValuesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skyddade värden',
      one: '1 skyddat värde',
    );
    return '$_temp0';
  }

  @override
  String spellingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skrivningar',
      one: '1 skrivning',
    );
    return '$_temp0';
  }

  @override
  String identitiesLeftHoldingNothing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identiteter',
      one: '1 identitet',
    );
    return '$_temp0 som då inte innehåller något';
  }

  @override
  String itsPlaceIn(String profile) {
    return 'dess plats i $profile';
  }

  @override
  String get itWillNotChange => 'Det här ändrar det INTE';

  @override
  String get forgetRemovesFromThisVault =>
      'Att glömma tar bort det här värdet ur det nuvarande valvet och ur valvets framtida igenkänning. Det tar inte bort skydd som redan tillämpats i det här dokumentet, och en äldre giltig kopia av valvet kan återställa värdet senare.';

  @override
  String wouldStillRecogniseIt(String who) {
    return '$who skulle fortfarande känna igen det — att glömma här räcker inte in i en annan kunds uppgifter.';
  }

  @override
  String get thisCannotBeUndone => 'Det här kan inte göras ogjort.';

  @override
  String get noValuesYet =>
      'Inga värden än. Ett värde är vad granskningen känner igen — ett namn, ett företag, ett IBAN.';

  @override
  String valuesEachWithItsOwnPolicy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count värden',
      one: '1 värde',
    );
    return '$_temp0, vart och ett med egna skrivningar och egen regel.';
  }

  @override
  String get moveIt => 'Flytta';

  @override
  String get deleteIt => 'Ta bort';

  @override
  String get addAValue => 'Lägg till ett värde';

  @override
  String get policyKeptNotHunted => 'Behålls, letas inte efter';

  @override
  String get addASpelling => 'Lägg till en skrivning';

  @override
  String get editIt => 'Redigera';

  @override
  String get alsoWritten => 'Skrivs också';

  @override
  String get anotherSpelling => 'En annan skrivning';

  @override
  String get anotherSpellingWhat =>
      'Samma värde skrivet annorlunda — «Herr Müller», «T. Müller». Varje skrivning behåller samma platshållare, så att modellen läser en person och inte tre.';

  @override
  String get exampleSpelling => 'Herr Müller';

  @override
  String get renameHead => 'Byt namn';

  @override
  String get whatToCallThisIdentity => 'Vad den här identiteten ska heta.';

  @override
  String get moveThisIdentity => 'Flytta den här identiteten';

  @override
  String get anIdentityInAProfile =>
      'En identitet i en profil läses in bara när den profilen är öppen. En som hör överallt läses alltid in.';

  @override
  String get deleteThisIdentity => 'Ta bort den här identiteten?';

  @override
  String identityAndItsValuesAreRemoved(String name, String values) {
    return '«$name» och dess $values tas bort ur valvet. Redan skyddade dokument behåller sina platshållare; nästa dokument känner inte igen de här värdena på nytt.';
  }

  @override
  String get keepItIdentity => 'Behåll';

  @override
  String get noNamesToLookAt => 'Inga namn att se på';

  @override
  String namesToLookAtCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count namn att se på',
      one: '1 namn att se på',
    );
    return '$_temp0';
  }

  @override
  String get zKnowsEveryName =>
      'Z känner varje namn det här dokumentet använder.';

  @override
  String get wordsThisDocumentUsesAsNames =>
      'Ord som det här dokumentet använder som namn, och som Z inte känner än.';

  @override
  String placesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ställen',
      one: '1 ställe',
    );
    return '$_temp0';
  }

  @override
  String pagesCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sidor',
      one: '1 sida',
    );
    return '$_temp0';
  }

  @override
  String get addAsFamilyName => 'Lägg till som efternamn';

  @override
  String get addAsGivenName => 'Lägg till som förnamn';

  @override
  String get ignoreIt => 'Förbigå';

  @override
  String get unlockTheVaultAct => 'Lås upp valvet';

  @override
  String get needsAVault => 'Behöver ett valv';

  @override
  String get nameListsFileType => 'Namnlistor';

  @override
  String get whichLanguageAreTheseNames => 'Vilket språk är de här namnen på?';

  @override
  String get yourNames => 'Dina namn';

  @override
  String get namesThisDeviceKnows =>
      'Namn som den här enheten känner därför att du har sagt det. De bevaras i ditt valv, på den här datorn.';

  @override
  String get addAName => 'Lägg till ett namn';

  @override
  String get importAList => 'Importera en lista';

  @override
  String actNeedsTheVault(String act, String needs) {
    return '$act · $needs';
  }

  @override
  String get aListIsACsv =>
      'En lista är en CSV med en kolumn «name» och en kolumn «type»: given, family, person eller company.';

  @override
  String get yourNamesLiveInTheVault =>
      'Dina namn lever i valvet, så att lägga till ett kräver att det är öppet.';

  @override
  String get exampleSurname => 'Lindqvist';

  @override
  String get pickSuggest => 'Föreslå';

  @override
  String get pickAlways => 'Alltid';

  @override
  String get alwaysProtectedTheMoment =>
      'Alltid: skyddat i samma stund det dyker upp, i varje dokument.';

  @override
  String get suggestMarksAndWaits =>
      'Föreslå: Z markerar det och väntar på ditt ord.';

  @override
  String get addAct => 'Lägg till';

  @override
  String get nothingYet => 'Ingenting än.';

  @override
  String get wholeNamesKeptInTheVault => 'Hela namn, bevarade i valvet';

  @override
  String get aWholePersonIsAValue =>
      'En hel person eller ett helt företag är ett värde, inte ett ordboksord, och står därför i ingen språklista. Z-valvet är där var och en sköts.';

  @override
  String get reachEverywhere => 'överallt';

  @override
  String get reachThisClient => 'den här kunden';

  @override
  String forgetNamedShort(String what) {
    return 'Glöm «$what»';
  }

  @override
  String get kindGivenName => 'förnamn';

  @override
  String get kindFamilyName => 'efternamn';

  @override
  String get kindPersonName => 'person';

  @override
  String get kindCompanyName => 'företag';

  @override
  String namesAndValuesInAList(String names, int values) {
    return '$names · $values värden';
  }

  @override
  String get listIsOff => 'av';

  @override
  String get stopUsingTheseNames => 'Använd inte de här namnen längre';

  @override
  String get useTheseNamesAgain => 'Använd de här namnen igen';

  @override
  String whatToDoWithList(String name) {
    return 'Vad som ska göras med «$name»';
  }

  @override
  String get moveToDots => 'Flytta till…';

  @override
  String get exportCsv => 'Exportera CSV';

  @override
  String get removeList => 'Ta bort listan';

  @override
  String removeNamedList(String name) {
    return 'Ta bort «$name»?';
  }

  @override
  String namesGoWithItCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count namn följer med. Ingenting annat berörs.',
      one: 'Ett namn följer med. Ingenting annat berörs.',
    );
    return '$_temp0';
  }

  @override
  String get removeAct => 'Ta bort';

  @override
  String moveNamesFromTo(int count, String from) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Flytta $count namn från $from till…',
      one: 'Flytta ett namn från $from till…',
    );
    return '$_temp0';
  }

  @override
  String get howFarDoTheseNamesReach => 'Hur långt räcker de här namnen?';

  @override
  String get protectingThemMeans =>
      'Att skydda dem betyder att Z svartar dem i samma stund de dyker upp, utan fråga. Att erbjuda dem betyder att Z markerar dem och väntar på dig.';

  @override
  String get youCanChangeAnyOneAfterwards =>
      'Du kan ändra vilket som helst av dem efteråt, namn för namn.';

  @override
  String get offerThemAndIDecide => 'Erbjud dem, och jag bestämmer';

  @override
  String get protectThemEverywhere => 'Skydda dem överallt';

  @override
  String protectThemForClient(String client) {
    return 'Skydda dem för $client';
  }

  @override
  String get couldNotBuildThePdf =>
      'Z Privacy kunde inte skapa PDF:en — dess svarssida hade ingen platshållare. Ingenting skrevs.';

  @override
  String get whoAnswers => 'Vem som svarar';

  @override
  String get thereIsNothingToSend => 'Det finns ingenting att skicka.';

  @override
  String valuesReplacedCharacters(int values, int characters) {
    return '$values värden ersatta · $characters tecken skulle lämna den här enheten.';
  }

  @override
  String sessionNumber(int number) {
    return 'Session $number';
  }

  @override
  String sessionNumberNamed(int number, String name) {
    return 'Session $number «$name»';
  }

  @override
  String theseNamesAreThisSessions(String named) {
    return '$named · de här namnen hör till den här sessionen';
  }

  @override
  String get noSessionNamesForThisDocument =>
      'Ingen session — de här namnen skapades bara för det här dokumentet.';

  @override
  String get noSessionYetAnyDoorBeginsOne =>
      'Ingen session än — varje dörr här börjar en.';

  @override
  String get nothingLeftTheMachine => 'Ingenting har lämnat enheten.';

  @override
  String get oneSuggestionStillOpenSend =>
      'Ett förslag är fortfarande öppet. Det står i texten som skrivet, och ingenting kan skickas förrän du svarar på det. Det finns inget «skicka ändå».';

  @override
  String suggestionsStillOpenSend(int open) {
    return '$open förslag är fortfarande öppna. De står i texten som skrivna, och ingenting kan skickas förrän du svarar på dem. Det finns inget «skicka ändå».';
  }

  @override
  String get manualAiSheetWhat =>
      'Använd en AI-chatt du redan har. Ta texten ovan — till urklippet, eller som en PDF sparad på den här datorn — klistra in den i vilken modell du vill, och hämta tillbaka svaret med «Lägg till ett svar» under chatten. Återställningen fungerar likadant båda vägarna — inget konto, ingen nyckel. Ingen av vägarna skickar något härifrån.';

  @override
  String get copied => 'Kopierat';

  @override
  String get copyProtected => 'Kopiera skyddad text';

  @override
  String get saving => 'Sparar…';

  @override
  String get saveAsPdf => 'Spara som PDF';

  @override
  String savedToWhere(String where) {
    return 'Sparat till $where';
  }

  @override
  String get whatThePdfHolds =>
      'Den skyddade texten, med byggstämpeln, siffrorna och en sha256 av den texten i sidfoten, och en sista sida för svaret. Ingenting skickades.';

  @override
  String get directApiSheetWhatRemote =>
      'Anslut till en AI-leverantör på distans med dina API-uppgifter. Bara texten ovan skulle resa; leverantören ser fortfarande de vanliga fakta om en anslutning — din adress, tiden, modellen.';

  @override
  String get directApiSheetWhatConnected =>
      'Förfrågan går från den här appen. Bara texten ovan reser; leverantören ser fortfarande de vanliga fakta om en anslutning — din adress, tiden, modellen.';

  @override
  String get noProviderIsConnected =>
      'Ingen leverantör är ansluten. Adressen och nyckeln anges en gång, i Inställningar — den här skärmen frågar aldrig efter dem.';

  @override
  String get sending => 'Skickar…';

  @override
  String sendToNamed(String where) {
    return 'Skicka till $where';
  }

  @override
  String get providerKeyThisRunOnly =>
      '   (nyckeln bevarad bara så länge appen är öppen)';

  @override
  String get theAddressTheModelTheKey =>
      'Adressen, modellen och nyckeln ändras i Inställningar.';

  @override
  String get localAiSheetWhat =>
      'Använd en AI-tjänst som körs på den här datorn — llama.cpp, Ollama, LM Studio, allt som svarar i samma form. Ingen nyckel, inget konto, och förfrågan lämnar aldrig den här datorn. Det är den enda vägen som inte ser något av de vanliga fakta ovan.';

  @override
  String get aModelOnThisComputer =>
      'En modell på den här datorn ställs in i Inställningar — det finns ingen nyckel att ange.';

  @override
  String get openSettings => 'Öppna Inställningar';

  @override
  String get modelLabel => 'Modell';

  @override
  String get fileKindDocuments => 'Dokument';

  @override
  String onlyTheseKindsAreRead(String name) {
    return 'Den här versionen läser PDF-, Word- och textfiler. «$name» är ingen av dem.';
  }

  @override
  String get generalRulesOnlyNoDictionary =>
      'Bara allmänna regler — inget register än';

  @override
  String get whichLanguageIsThisText => 'Vilket språk är den här texten på?';

  @override
  String get theSessionLanguageExplained =>
      'Z läser den med det språkets vanor: hur människor hälsas, hur ett företag skrivs, hur ett kundnummer ser ut. Det är sessionens språk från och med nu, och i den blir du inte frågad igen.';

  @override
  String allLinesHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alla $count rader',
      one: 'Alla 1 rad',
    );
    return '$_temp0';
  }

  @override
  String get revealHidden => 'Dolt';

  @override
  String revealedForSeconds(int seconds) {
    return 'Avtäckt · ${seconds}s';
  }

  @override
  String get alsoTheWordBefore => 'Även ordet före';

  @override
  String get alsoTheWordBeforeHint =>
      'Tar även med det stora ordet framför markeringen';

  @override
  String get undoProtection => 'Ta tillbaka skyddet';

  @override
  String get nothingToUndoHint => 'Ingenting att ta tillbaka';

  @override
  String get rescanAct => 'Granska igen';

  @override
  String nextOfWaitingCount(int at, int total) {
    return 'Nästa $at/$total';
  }

  @override
  String get reviewAct => 'Gå igenom';

  @override
  String get namesAct => 'Namn';

  @override
  String get zKnowsEveryNameHere =>
      'Z känner varje namn det här dokumentet använder';

  @override
  String get tokensAct => 'Platshållare';

  @override
  String get nothingIsProtectedYetHint => 'Ingenting är skyddat än';

  @override
  String get selectionCutsIntoProtected =>
      'Den markeringen skär in i något som redan är skyddat. Skydda skulle ta hela elementet i stället.';

  @override
  String selectionSpansProtectedItems(int count) {
    return 'Den markeringen omfattar $count skyddade element. Skydda skulle ta vart och ett av dem helt, under sin egen platshållare.';
  }

  @override
  String get protectAct => 'Skydda';

  @override
  String get selectTextThenProtect => 'Markera text, sedan Skydda';

  @override
  String get alreadyProtectedSeeBelow => 'Redan skyddat — se nedan';

  @override
  String get protectWholeItems => 'Skydda hela element';

  @override
  String get thereWasNothingToUndo => 'Det fanns ingenting att ta tillbaka.';

  @override
  String tookBackTokens(String tokens) {
    return 'Tog tillbaka $tokens.';
  }

  @override
  String tookBackTokensInPlaces(String tokens, int places) {
    return 'Tog tillbaka $tokens, på alla $places ställen — det gick in som ett steg, så det kom ut som ett.';
  }

  @override
  String tookBackTokensIdentityStays(String tokens, String identity) {
    return 'Tog tillbaka $tokens. Identiteten $identity ligger kvar i valvet.';
  }

  @override
  String scannedAgainReport(int auto, int byYou, int waiting, int normal) {
    return 'Granskat igen: $auto automatiskt skyddade · $byYou av dig · $waiting behöver ditt ord · $normal normala.';
  }

  @override
  String alreadyProtectedAsTokens(String tokens) {
    return 'Redan skyddat som $tokens.';
  }

  @override
  String alreadyProtectedAsFrom(String tokens, String source, String detail) {
    return 'Redan skyddat som $tokens, från $source$detail.';
  }

  @override
  String get readBackPanel => 'Tillbakaläst';

  @override
  String get whatStayedAToken => 'Vad som förblev en platshållare';

  @override
  String theSearchWasRefused(String why) {
    return 'Sökningen avvisades: $why';
  }

  @override
  String get findAWordInThisDocument => 'Hitta ett ord i det här dokumentet';

  @override
  String get tabTakesIt => 'Tab tar det';

  @override
  String get findAct => 'Sök';

  @override
  String notInThisDocument(String word) {
    return '«$word» står inte i det här dokumentet';
  }

  @override
  String countProtected(int count) {
    return '$count skyddade';
  }

  @override
  String countWaiting(int count) {
    return '$count väntar';
  }

  @override
  String countInTheClear(int count) {
    return '$count i klartext';
  }

  @override
  String placesInsideWaitingWords(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ställen ligger',
      one: 'Ett ställe ligger',
    );
    return '$_temp0 i ord som fortfarande väntar på ditt ord: $list. Skydda lämnar dem till genomgången.';
  }

  @override
  String get goToIt => 'Gå dit';

  @override
  String get unProtectHere => 'Ta bort skyddet här';

  @override
  String unProtectInThisSession(int places) {
    return 'Ta bort skyddet i den här sessionen ($places ställen)';
  }

  @override
  String get nothingIsWaitingForYou => 'Ingenting väntar på dig.';

  @override
  String thingsWaitingForYourWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker väntar på ditt ord.',
      one: 'En sak väntar på ditt ord.',
    );
    return '$_temp0';
  }

  @override
  String get theScanFoundNothingHere =>
      'Granskningen hittade ingenting i det här dokumentet.';

  @override
  String get nothingIsWaitingWhatIsProtected =>
      'Ingenting väntar. Det som är skyddat står i texten, markerat där det står.';

  @override
  String foundBySource(String source) {
    return 'hittat av $source';
  }

  @override
  String get youDecided => 'beslutat av dig';

  @override
  String pageAndParagraph(int page, int paragraph) {
    return 'Sida $page · ¶$paragraph';
  }

  @override
  String inPlacesCount(int count) {
    return 'på $count ställen';
  }

  @override
  String identitiesClaimIt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identiteter gör anspråk på det',
      one: 'En identitet gör anspråk på det',
    );
    return '$_temp0';
  }

  @override
  String leaveWordsInTheClearQuestion(int count) {
    return 'Lämna $count ord i klartext?';
  }

  @override
  String leaveAllInTheClearExplained(int count) {
    return 'Alla $count skickas precis som de är skrivna. Z ersätter inget av dem, varken i det här dokumentet eller i förfrågan som lämnar den här datorn.';
  }

  @override
  String yesLeaveAllInTheClear(int count) {
    return 'Ja — lämna alla $count i klartext';
  }

  @override
  String get protectAll => 'Skydda alla';

  @override
  String get skipAll => 'Hoppa över alla';

  @override
  String get leaveIt => 'Lämna så';

  @override
  String get activeZTokens => 'Aktiva Z-platshållare';

  @override
  String get nothingIsProtectedYetSentence => 'Ingenting är skyddat än.';

  @override
  String valuesStandBehindTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count värden står',
      one: '1 värde står',
    );
    return '$_temp0 bakom en platshållare i den här sessionen.';
  }

  @override
  String get aTokenAppearsWhenProtected =>
      'En platshållare dyker upp här i samma stund något skyddas.';

  @override
  String get revealingChangesNothing =>
      'Att avtäcka visar ett värde på den här skärmen ett ögonblick. I den skyddade kolumnen ändrar det ingenting — vad som lämnar enheten är samma teckenföljd före och efter.';

  @override
  String get copyTheToken => 'Kopiera platshållaren';

  @override
  String get scopeJustHere => 'Bara här';

  @override
  String get scopeThisSession => 'Den här sessionen';

  @override
  String get scopeRememberedForClient => 'Minns för den här kunden';

  @override
  String get scopeRememberedEverywhere => 'Minns överallt';

  @override
  String get copyReport => 'Kopiera rapporten';

  @override
  String sessionNamesAreThisSessions(int number) {
    return 'Session $number · namnen i det här arbetet hör till den här sessionen';
  }

  @override
  String get asEachProviderIsConfigured =>
      'Beroende på hur varje leverantör är inställd';

  @override
  String get noAiConnected => 'Ingen AI ansluten';

  @override
  String get connectAnAiInSettings => 'Anslut en AI i Inställningar';

  @override
  String get chooseWhichModelAnswers => 'Välj vilken modell som svarar';

  @override
  String get nothingSentFromThisSessionYet =>
      'Ingenting har skickats från den här sessionen än. Vad som går till en modell och vad som kommer tillbaka står här, i sessionens egen förseglade fil.';

  @override
  String get youAsked => 'Du frågade';

  @override
  String get nothingWasAskedDocumentWentAlone =>
      'Ingenting frågades — dokumentet gick ensamt.';

  @override
  String get itAnswered => 'Den svarade';

  @override
  String namesBelongToAnotherSession(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count namn i det här utbytet hör till en annan session och kunde inte återställas: $list.',
      one:
          'Ett namn i det här utbytet hör till en annan session och kunde inte återställas: $list.',
    );
    return '$_temp0';
  }

  @override
  String get andTheClipboardIsEmptySentence =>
      'Ingenting kopierades — urklippet är tomt.';

  @override
  String get nothingWasPasted => 'Ingenting klistrades in.';

  @override
  String get copyTheSafeTextFirst =>
      'Kopiera den skyddade texten först, så att svaret kan knytas till den sändningen.';

  @override
  String profileIsInUseAgain(String name) {
    return '«$name» är i bruk igen.';
  }

  @override
  String profileIsOffNamesRemain(String name) {
    return '«$name» är av — dess namn finns fortfarande här.';
  }

  @override
  String movedNamesToLanguage(int count, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Flyttade $count namn till $to.',
      one: 'Flyttade ett namn till $to.',
    );
    return '$_temp0';
  }

  @override
  String forgotProfileAndItsNames(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count namn',
      one: '1 namn',
    );
    return 'Glömde «$name» och $_temp0.';
  }

  @override
  String addedValueNamed(String value) {
    return 'Lade till «$value».';
  }

  @override
  String forgotValueNamed(String value) {
    return 'Glömde «$value».';
  }

  @override
  String get afterTheVaultOpened => 'efter att valvet låstes upp';

  @override
  String importAddedCount(int count) {
    return '$count tillagda';
  }

  @override
  String importAlreadyKnownCount(int count) {
    return '$count redan kända';
  }

  @override
  String importRefusedCount(int count) {
    return '$count avvisade';
  }

  @override
  String importValuesCount(int count) {
    return '$count värden';
  }

  @override
  String get begunNoNameNeededRenaming =>
      'Påbörjad. Inget namn i det här dokumentet behövde byta namn.';

  @override
  String get begunNoDocumentOpen =>
      'Påbörjad. Inget dokument är öppet, så det fanns ingenting att byta namn på.';

  @override
  String begunAndNamesMovedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Påbörjad, och $count namn i det här dokumentet flyttade in i den.',
      one: 'Påbörjad, och ett namn i det här dokumentet flyttade in i den.',
    );
    return '$_temp0';
  }

  @override
  String get theSessionWasNotBegun =>
      'Sessionen påbörjades inte, så ingenting togs ut.';

  @override
  String get closeAndOpenAgain =>
      'Stäng det här och öppna det igen — något ändrades medan det var öppet.';

  @override
  String get sentToAiAnswered => 'skickat till AI:n · besvarat';

  @override
  String get sentToAiNoAnswerYet => 'skickat till AI:n · inget svar än';

  @override
  String columnsNotUsedSaid(int count, String which) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count kolumner användes inte: $which — namnge typen för var och en, annars stannar de utanför.',
      one:
          'En kolumn användes inte: $which — namnge dess typ, annars stannar den utanför.',
    );
    return '$_temp0';
  }

  @override
  String get addressLabel => 'Adress';

  @override
  String get plainHttpOnlyLoopback =>
      'Vanlig http accepteras bara för en bokstavlig loopback-adress — 127.0.0.1 eller ::1. Ett namn som «localhost» avvisas, för då skulle en hosts-fil avgöra om klartext är säkert.';

  @override
  String get theModelToAsk => 'modellen som frågas';

  @override
  String get apiKeyLabel => 'API-nyckel';

  @override
  String get pastedOnceNeverShownAgain =>
      'inklistrad en gång, visas aldrig igen';

  @override
  String get thisKeyIsSealedInTheVault =>
      'Den här nyckeln är förseglad i valvet.';

  @override
  String get thisKeyIsInMemoryOnly =>
      'Den här nyckeln hålls i minnet bara så länge appen är öppen — den är borta när appen stängs.';

  @override
  String get noKeyIsNeededHere => 'På den här adressen behövs ingen nyckel.';

  @override
  String get noKeyYetWillSeal =>
      'Ingen nyckel är sparad än. Att ansluta förseglar den i valvet.';

  @override
  String get noKeyYetMemoryOnly =>
      'Ingen nyckel är sparad än. Att ansluta håller den i minnet bara så länge appen är öppen.';

  @override
  String get connectingNow => 'Ansluter…';

  @override
  String get connectAct => 'Anslut';

  @override
  String get forgetTheKey => 'Glöm nyckeln';

  @override
  String get disconnectAct => 'Koppla ifrån';

  @override
  String get couldNotTellWhereDocumentsFolderIs =>
      'Z Privacy kunde inte avgöra var din dokumentmapp ligger, och har inte gissat. Ingenting skrevs.';

  @override
  String thereAreAlready200Files(String stem, String into) {
    return 'Det finns redan 200 filer som heter $stem i $into.';
  }

  @override
  String couldNotWriteInto(String into, String why) {
    return 'Z Privacy kunde inte skriva i $into — $why.';
  }

  @override
  String couldNotBuildThePdfBecause(String why) {
    return 'Z Privacy kunde inte skapa PDF:en — $why. Ingenting skrevs.';
  }

  @override
  String get zPdfProtectedCopy => 'z-pdf · skyddad kopia';

  @override
  String placesReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ställen ersatta',
      one: '1 ställe ersatt',
    );
    return '$_temp0';
  }

  @override
  String valuesOfTheseKinds(int count, String kinds) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count värden ($kinds)',
      one: '1 värde ($kinds)',
    );
    return '$_temp0';
  }

  @override
  String get noKindsAtAll => 'inga';

  @override
  String sha256OfTheProtectedText(String digest) {
    return 'sha256 av den skyddade texten $digest';
  }

  @override
  String zPdfAnswerLine(String token) {
    return 'Z-pdf : $token';
  }

  @override
  String couldNotAskWhereToSaveIt(String why) {
    return 'Z Privacy kunde inte öppna systemets spara-dialog — $why. Ingenting skrevs.';
  }

  @override
  String get nameThisDocument => 'Ge det här dokumentet ett namn';

  @override
  String get whatIsThisDocumentCalled => 'Vad heter det här dokumentet?';

  @override
  String get theFileNameIsNotProtected =>
      'Filnamnet står kvar precis som du skriver det. Det följer med filen ut — skriv därför inga verkliga namn i det.';

  @override
  String get aNameIsNeededForThisDocument =>
      'Ett namn behövs — filen namnges efter det.';

  @override
  String get saveAsAPlainPdf => 'Spara som vanlig PDF';

  @override
  String get aPlainPdfOfTheRestoredText =>
      'Sparar dokumentet ovan med namnen tillbaka i det, som en vanlig PDF — ingen svarssida, ingen fotrad, ingenting som påstår ett skydd. Värdena står i klartext i den.';

  @override
  String get copyTheAddressAndWriteToUs =>
      'Kopiera den här adressen och skriv till oss från din egen e-post. Z Privacy öppnar ingenting och skickar ingenting: här finns inget formulär och ingen förbindelse till oss.';

  @override
  String get writeToUs => 'Skriv till oss';

  @override
  String get describeTheProblemNotYourDocuments =>
      'Beskriv problemet, och skicka inte med dina dokument: det som kommer in i vår brevlåda kan vi inte skydda. «Kopiera rapporten» i listen över ditt arbete skriver tal om ett dokument och inte ett ord ur det.';

  @override
  String get howToUseZPrivacy => 'Så använder du Z Privacy';

  @override
  String get theGuideOpensInYourBrowser =>
      'Sidan öppnas i din webbläsare, på det språk det här gränssnittet är på. Med trycket går ingenting från ditt dokument och ingenting från ditt valv med: din webbläsare ber webbplatsen om en sida, som vid vilket annat besök som helst.';

  @override
  String get couldNotOpenYourBrowser =>
      'Z Privacy kunde inte öppna din webbläsare. Adressen på knappen går att öppna i vilken webbläsare som helst för hand.';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get theKeyIsBehindTheLockedVault =>
      'Z Privacy kann keinen Schlüssel erreichen, solange der Tresor verschlossen ist. Öffnen Sie ihn, oder geben Sie einen Schlüssel nur für dieses Mal an.';

  @override
  String get theChatKeepsNothing =>
      'Diese Antwort steht auf Ihrem Bildschirm und nirgendwo sonst: Es ist keine Sitzung offen, die sie aufbewahren könnte — mit dem Schließen der App endet sie zusammen mit dem Chat.';

  @override
  String get theTokenIsAlreadyOurs =>
      'Das ist bereits geschützt — Z hat es dort eingesetzt.';

  @override
  String get unnamedTrouble =>
      'Etwas ist schiefgegangen. Z Privacy hat die Aktion nicht abgeschlossen.';

  @override
  String exactlyWhatWouldLeave(int replaced) {
    return 'Genau das erhält die KI. $replaced Werte wurden ersetzt.';
  }

  @override
  String get noLanguageAndASessionIsOpen =>
      'Es wurde nichts gelesen. Ein Text wird mit den Gewohnheiten einer Sprache gelesen, und diese Sitzung hat noch keine erhalten — Z Privacy hat deshalb nicht für Sie gewählt. Lesen Sie ihn erneut und antworten Sie, oder geben Sie der Sitzung ihre Sprache in den Einstellungen.';

  @override
  String get noLanguageAndNoSession =>
      'Es wurde nichts gelesen. Ein Text wird mit den Gewohnheiten einer Sprache gelesen, und es wurde keine gewählt — es wurde deshalb nichts gelesen und keine Sitzung angelegt. Versuchen Sie es erneut und wählen Sie eine.';

  @override
  String get troubleNotImplemented =>
      'Dieser Teil von Z Privacy ist noch nicht gebaut.';

  @override
  String get troubleInvalidSession =>
      'Diese Sitzung ist nicht mehr offen. Beginnen Sie eine neue.';

  @override
  String get troubleInvalidHandle =>
      'Diese Anfrage ist nicht mehr aktuell. Prüfen Sie den Text erneut, bevor Sie senden.';

  @override
  String get troubleStalePayload =>
      'Das Dokument hat sich geändert, nachdem diese Anfrage vorbereitet wurde. Prüfen Sie es erneut, damit Sie senden, was Sie zuletzt gesehen haben.';

  @override
  String get troubleVaultLocked =>
      'Ihr Tresor ist verschlossen. Öffnen Sie ihn, um zu nutzen, was er weiß.';

  @override
  String get troubleVaultRequired =>
      'Öffnen oder erstellen Sie Ihren Tresor, bevor Sie dies für später speichern.';

  @override
  String get troubleVaultAuthenticationFailed =>
      'Der Tresor konnte nicht geöffnet werden. Die Passphrase kann falsch sein, oder der Tresor ist beschädigt oder verändert.';

  @override
  String get troubleUnsupportedKdfParameters =>
      'Dieser Tresor verwendet nicht unterstützte Sicherheitseinstellungen.';

  @override
  String get troubleTrailingVaultData =>
      'Diese Tresordatei enthält zusätzliche Daten nach ihrem Ende und wurde nicht geöffnet.';

  @override
  String get troubleProviderUnavailable =>
      'Dieser KI-Anbieter ist in dieser Version nicht verfügbar.';

  @override
  String get oneWordWaits =>
      'Ein Wort wartet auf Ihre Antwort — nichts hat Z verlassen.';

  @override
  String wordsWait(int count) {
    return '$count Wörter warten auf Ihre Antwort — nichts hat Z verlassen.';
  }

  @override
  String get troubleVaultAbsent =>
      'Auf diesem Gerät gibt es noch keinen Tresor. Erstellen Sie einen, um etwas für morgen aufzubewahren.';

  @override
  String get troubleVaultAlreadyExists =>
      'Auf diesem Gerät gibt es bereits einen Tresor, und Z Privacy schreibt ihn nicht über.';

  @override
  String troubleStorageRefused(String reason) {
    return 'Z Privacy verwendet diesen Ort nicht — $reason';
  }

  @override
  String get everyCellWasAlreadyProtected =>
      'Jede Zelle in dieser Spalte war bereits geschützt.';

  @override
  String protectedOneCell(String token) {
    return 'Eine Zelle geschützt, als $token.';
  }

  @override
  String protectedCellsDownTheColumn(int places, String token) {
    return '$places Zellen in dieser Spalte geschützt, die erste als $token.';
  }

  @override
  String protectedAs(String token) {
    return 'Geschützt als $token.';
  }

  @override
  String protectedAsInPlaces(String token, int places) {
    return 'Geschützt als $token, an $places Stellen.';
  }

  @override
  String alreadyProtectedBy(String token, String who) {
    return 'Bereits geschützt als $token, durch $who.';
  }

  @override
  String belongsToEntity(String entity, String token) {
    return 'Das gehört zu $entity und behält seinen Platzhalter $token.';
  }

  @override
  String pressCutsIntoProtectedTextOne(String what) {
    return '$what schneidet in geschützten Text, es wurde deshalb nichts geändert. Es würde auf 1 ganzes Element ausgedehnt.';
  }

  @override
  String pressCutsIntoProtectedTextMany(String what, int items) {
    return '$what schneidet in geschützten Text, es wurde deshalb nichts geändert. Es würde auf $items ganze Elemente ausgedehnt.';
  }

  @override
  String get theSelection => 'Die Auswahl';

  @override
  String get thatCell => 'Diese Zelle';

  @override
  String get thatPlace => 'Diese Stelle';

  @override
  String get sourceRule => 'Regel';

  @override
  String get sourcePack => 'Sprachpaket';

  @override
  String get sourceVault => 'Tresor';

  @override
  String get sourceYou => 'Sie';

  @override
  String get answeredByHand => 'von Hand zurückgebracht';

  @override
  String get answeredNotRecorded => 'nicht festgehalten';

  @override
  String get oneNameCameBack => 'Ein Name ist zurückgekommen.';

  @override
  String namesCameBack(int count) {
    return '$count Namen sind zurückgekommen.';
  }

  @override
  String oneNameCameBackFrom(String sessions) {
    return 'Ein Name ist aus $sessions zurückgekommen.';
  }

  @override
  String namesCameBackFrom(int count, String sessions) {
    return '$count Namen sind aus $sessions zurückgekommen.';
  }

  @override
  String thisDocumentCameBackFrom(String sessions) {
    return 'Dieses Dokument ist aus $sessions zurückgekommen.';
  }

  @override
  String get oneNameIsStillATokenVaultShut =>
      'Ein Name ist noch ein Platzhalter: Öffnen oder erstellen Sie Ihren Tresor, dann kann Z danach suchen.';

  @override
  String namesAreStillTokensVaultShut(int count) {
    return '$count Namen sind noch Platzhalter: Öffnen oder erstellen Sie Ihren Tresor, dann kann Z danach suchen.';
  }

  @override
  String get oneNameStaysATokenTwoCauses =>
      'Ein Name bleibt ein Platzhalter, und dafür gibt es zwei verschiedene Gründe: Das Wort wurde geschützt, bevor Z Privacy begann, jedes geschützte Wort aufzubewahren, oder dieser Platzhalter wurde verändert, nachdem die Datei das Gerät verlassen hat. Öffnen Sie dieses Dokument in seiner Sitzung und schützen Sie den Namen erneut — kommt er von da an zurück, war es der erste Grund; kommt er nicht zurück, ist diese Datei nicht die, die Z Privacy geschrieben hat.';

  @override
  String namesStayTokensTwoCauses(int count) {
    return '$count Namen bleiben Platzhalter, und dafür gibt es zwei verschiedene Gründe: Sie wurden geschützt, bevor Z Privacy begann, jedes geschützte Wort aufzubewahren, oder die Platzhalter wurden verändert, nachdem die Datei das Gerät verlassen hat. Öffnen Sie diese Dokumente in ihrer Sitzung und schützen Sie die Namen erneut — kommen sie von da an zurück, war es der erste Grund; kommen sie nicht zurück, ist diese Datei nicht die, die Z Privacy geschrieben hat.';
  }

  @override
  String get refusalMalformedDocument =>
      'Dieses Dokument ist beschädigt oder unvollständig.';

  @override
  String get refusalEncryptedPdf =>
      'Diese PDF-Datei ist mit einem Passwort geschützt. Entfernen Sie das Passwort und versuchen Sie es erneut.';

  @override
  String get refusalScannedOnePage =>
      'Diese PDF-Datei ist ein Bild einer Seite ohne Text darin, es konnte deshalb nichts gelesen werden — und Z Privacy importiert kein Dokument, das es nicht sehen kann.';

  @override
  String refusalScannedPages(int pages) {
    return 'Diese PDF-Datei besteht aus $pages Seiten mit Bildern ohne Text, es konnte deshalb nichts gelesen werden.';
  }

  @override
  String refusalUnsupportedEncoding(int readablePercent, int page) {
    return 'Nur $readablePercent% von Seite $page ließen sich in Zeichen umwandeln, dieses Dokument wird deshalb abgelehnt statt halb gelesen. Öffnen Sie es und speichern Sie es als Text, oder fügen Sie den Text hier ein.';
  }

  @override
  String refusalUnreadableStructure(int page) {
    return 'Seite $page ist so aufgebaut, dass diese Version sie nicht lesen kann.';
  }

  @override
  String refusalDocumentTooLarge(int mib, int limitMib) {
    return 'Diese Datei ist etwa $mib MiB groß, und Z Privacy öffnet Dokumente bis $limitMib MiB.';
  }

  @override
  String refusalTooManyPages(int pages, int limit) {
    return 'Dieses Dokument hat $pages Seiten, und Z Privacy öffnet bis zu $limit in einem Dokument.';
  }

  @override
  String refusalTextTooLarge(int limitMib) {
    return 'Entpackt ist ein Teil dieser Datei größer als $limitMib MiB — mehr als Z Privacy in einem Dokument liest, es wurde deshalb nichts davon importiert.';
  }

  @override
  String refusalCompressionBomb(int ratio) {
    return 'Ein Teil dieser Datei entpackt sich auf mehr als das $ratio-Fache seines Platzes. Kein echtes Dokument tut das, Z Privacy hat das Entpacken deshalb abgebrochen, statt den Rechner zu füllen.';
  }

  @override
  String refusalTooManyParts(int parts, int limit) {
    return 'Diese Datei führt $parts Teile in sich, und ein Dokument hat Dutzende, nicht Tausende — Z Privacy öffnet bis zu $limit.';
  }

  @override
  String refusalTookTooLong(int seconds) {
    return 'Das Lesen dieser Datei lief nach $seconds Sekunden noch, Z Privacy hat deshalb abgebrochen. Es wurde nichts davon importiert.';
  }

  @override
  String get refusalEmptyDocument =>
      'In dieser Datei ist kein Text, den Z Privacy schützen könnte.';

  @override
  String get networkNotConnected =>
      'Es ist kein KI-Anbieter verbunden. Geben Sie zuerst eine Adresse und einen Schlüssel ein.';

  @override
  String get networkInsecureUrl =>
      'An diese Adresse kann nicht sicher gesendet werden.';

  @override
  String get networkRedirected =>
      'Diese Adresse hat uns weitergeleitet. Z Privacy folgt mit Ihrem Text keiner Weiterleitung, es wurde deshalb nichts gesendet.';

  @override
  String networkBadStatus(int status) {
    return 'Der Anbieter hat die Anfrage mit Status $status abgelehnt. Z Privacy hat nichts von Ihrem Dokument aufbewahrt.';
  }

  @override
  String get networkTimeout =>
      'Der Anbieter hat nicht rechtzeitig geantwortet. Es wurde nichts weiter gesendet.';

  @override
  String networkResponseTooLarge(int limitKib) {
    return 'Die Antwort war größer als $limitKib KiB und wurde nicht gelesen.';
  }

  @override
  String networkPayloadTooLarge(int kib, int limitKib) {
    return 'Dieser Text ist $kib KiB groß, und der Anbieter akzeptiert $limitKib KiB in einer Anfrage.';
  }

  @override
  String get networkUnreadable =>
      'Der Anbieter hat mit etwas geantwortet, das keine Antwort ist.';

  @override
  String get networkUnreachable =>
      'Diese Adresse war überhaupt nicht erreichbar — nichts hat geantwortet. Prüfen Sie, ob Sie online sind und ob die Adresse stimmt. Es wurde nichts gesendet.';

  @override
  String get troubleVaultChangedElsewhere =>
      'Eine andere Kopie von Z Privacy hat diesen Tresor geändert. Schließen Sie jenes Fenster, oder verschließen und öffnen Sie den Tresor hier, um dessen Arbeit zu übernehmen.';

  @override
  String troubleStoragePermissionsKept(String reason) {
    return 'Z Privacy ändert keine von Ihnen gesetzte Berechtigung, es wurde deshalb nichts gespeichert — $reason. Ändern Sie die Berechtigung selbst, oder wählen Sie einen anderen Ordner.';
  }

  @override
  String get troubleBadSpan =>
      'Diese Auswahl konnte nicht gelesen werden. Wählen Sie die Wörter erneut aus.';

  @override
  String get troubleBetweenColumns =>
      'Dieser Klick lag im Zwischenraum zweier Spalten und benennt deshalb keinen Wert — und Z Privacy wählt keine Spalte für Sie aus.';

  @override
  String get troubleUnknownToken =>
      'Dieser geschützte Wert ist nicht in dieser Sitzung.';

  @override
  String get troubleNothingToSend =>
      'Es gibt noch nichts zu senden. Bringen Sie ein Dokument herein oder schreiben Sie einen Text.';

  @override
  String get troubleSessionWithoutItsDocument =>
      'Die Sitzung wurde nicht begonnen, weil Z Privacy nicht erkennen konnte, welches Dokument Sie offen haben — und eine Sitzung muss umbenennen, was darauf schon geschützt ist. Es wurde nichts geändert. Öffnen Sie das Dokument und beginnen Sie die Sitzung von dort.';

  @override
  String get troublePayloadAlreadySent =>
      'Diese Anfrage wurde bereits gesendet. Bereiten Sie sie erneut vor, um noch einmal zu senden.';

  @override
  String get theReasonWasNotReported => 'der Grund wurde nicht gemeldet.';

  @override
  String get carriesFirst => 'Dieses Dokument trägt';

  @override
  String get carriesAlso => 'Es trägt außerdem';

  @override
  String carriesOneNameFromElsewhere(String also, String which) {
    return '$also 1 Namen aus einer Sitzung, die dieser Tresor nicht hat ($which). Nichts hier kann ihn zurückholen: Der Schlüssel, der ihn erzeugt hat, ist nicht in diesem Tresor.';
  }

  @override
  String carriesNamesFromOneSessionElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count Namen aus einer Sitzung, die dieser Tresor nicht hat ($which). Nichts hier kann sie zurückholen: Der Schlüssel, der sie erzeugt hat, ist nicht in diesem Tresor.';
  }

  @override
  String carriesNamesFromSessionsElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count Namen aus Sitzungen, die dieser Tresor nicht hat ($which). Nichts hier kann sie zurückholen: Die Schlüssel, die sie erzeugt haben, sind nicht in diesem Tresor.';
  }

  @override
  String carriesNamesFromElsewhereWithNoCount(
    String also,
    String whose,
    String which,
    String keys,
  ) {
    return '$also Namen aus $whose ($which). Nichts hier kann sie zurückholen: $keys nicht in diesem Tresor.';
  }

  @override
  String get aSessionThisVaultDoesNotHold =>
      'einer Sitzung, die dieser Tresor nicht hat';

  @override
  String get sessionsThisVaultDoesNotHold =>
      'Sitzungen, die dieser Tresor nicht hat';

  @override
  String get theKeyThatMadeThemIs =>
      'die Schlüssel, die sie erzeugt haben, sind';

  @override
  String get andBetweenNames => ' und ';

  @override
  String get thisLanguageName => 'Deutsch';

  @override
  String get languageWord => 'Sprache';

  @override
  String get chooseALanguage => 'Wählen Sie eine Sprache, um fortzufahren.';

  @override
  String get noAccount => 'Kein Konto.';

  @override
  String get noAds => 'Keine Werbung.';

  @override
  String get noAnalytics => 'Keine Analyse- oder Tracking-Daten.';

  @override
  String get noZPrivacyServer => 'Kein Z-Privacy-Server.';

  @override
  String get originalDataStaysHere =>
      'Ihre Originaldaten bleiben auf diesem Gerät, es sei denn, Sie kopieren ausdrücklich wiederhergestellte Inhalte.';

  @override
  String get onlyTheProtectedVersionIsSent =>
      'Nur die geschützte Version wird über Z Privacy an die KI gesendet.';

  @override
  String get theseRulesWillBeEnabled =>
      'Die deutschen Datenschutzregeln werden aktiviert.';

  @override
  String get start => 'Starten';

  @override
  String get yourVault => 'Ihr Tresor';

  @override
  String get createAVault => 'Tresor erstellen';

  @override
  String get vaultWhy =>
      'Jedes Wort, das Sie schützen, lebt hier, solange Sie diesen Tresor behalten: die Namen, die Sie hinzufügen, die Werte, die Sie beibringen, und die Schlüssel zu jeder KI, die Sie verbinden. Er bleibt auf diesem Computer, und nichts wird irgendwo anders geschrieben.';

  @override
  String get onePassphrase =>
      'Eine Passphrase, auf diesem Gerät aufbewahrt. Alles, was Z lernt, während Sie arbeiten — Ihre Namen, Ihre Listen, Ihre Entscheidungen — wird darin aufbewahrt.';

  @override
  String get byYourVoices => 'von YourVoices';

  @override
  String pageHasNothingMarked(int page) {
    return 'Auf Seite $page hat der Scanner nichts markiert.';
  }

  @override
  String get addADocumentPdfWordOrText =>
      'Dokument hinzufügen — PDF, Word oder Text';

  @override
  String get addADocumentOrWriteToTheAi =>
      'Fügen Sie ein Dokument hinzu — oder schreiben Sie im ersten Teil an die KI, ganz ohne Dokument.';

  @override
  String get originalLocalOnly => 'Original — nur lokal';

  @override
  String get neverSentToAiSendCannotRead =>
      'Wird nie an die KI gesendet · Senden kann diese Seite nicht lesen';

  @override
  String get yourDocumentArrivesHere =>
      'Ihr Dokument kommt hier an, so wie es geschrieben ist. Nichts auf dieser Seite kann das Netz erreichen.';

  @override
  String get safeAiWillReceive => 'Geschützt — das erhält die KI';

  @override
  String get theRequestItselfNotAPreview =>
      'Die Anfrage selbst, keine Vorschau davon';

  @override
  String get whatAnAiWouldReceiveStandsHere =>
      'Was eine KI erhalten würde, steht hier neben dem Original, Wort für Wort, bevor etwas gesendet wird.';

  @override
  String get theChatTitle => 'Der Chat';

  @override
  String get yourQuestionsAndWhatCameBack => 'Ihre Fragen, und was zurückkam';

  @override
  String get theChatOpensHereWithTheFirstAnswer =>
      'Der Chat öffnet sich hier mit der ersten Antwort, und jede Frage danach trägt mit, was schon gesagt wurde.';

  @override
  String get typedText => 'Eingegebener Text';

  @override
  String get onePage => '1 Seite';

  @override
  String pagesCount(int pages) {
    return '$pages Seiten';
  }

  @override
  String get vaultLabel => 'Tresor';

  @override
  String get vaultIsUnlocked => 'Offen';

  @override
  String get vaultIsLocked => 'Verschlossen';

  @override
  String get vaultIsNone => 'Keiner';

  @override
  String get openZVault => 'Z-Tresor öffnen';

  @override
  String get lockNow => 'Jetzt verschließen';

  @override
  String get openZVaultOrLockItNow => 'Z-Tresor öffnen oder jetzt verschließen';

  @override
  String get goToAPage => 'Zu einer Seite springen';

  @override
  String pageNumber(int page) {
    return 'Seite $page';
  }

  @override
  String get pageWord => 'Seite';

  @override
  String get chooseTheAiAndWhatTravels => 'Die KI wählen und was an sie geht';

  @override
  String get readThisDocumentWithAnotherRuleSet =>
      'Dieses Dokument mit einem anderen Regelsatz lesen';

  @override
  String get generalRulesOnly => 'Nur allgemeine Regeln';

  @override
  String get packLabel => 'Sprachpaket';

  @override
  String packWithGeneralRules(String pack) {
    return '$pack · allgemeine Regeln';
  }

  @override
  String get everywhere => 'Überall';

  @override
  String get profile => 'Profil';

  @override
  String get profiles => 'Profile';

  @override
  String get chooseWhichClientDictionary =>
      'Wählen Sie, welches Kundenverzeichnis diese Sitzung verwendet. Die Profil-ID bleibt im Tresor; der Anzeigename ist, was Menschen sehen.';

  @override
  String get onlyIdentitiesForEveryProfile =>
      'Nur Identitäten und Regeln, die für jedes Profil gelten.';

  @override
  String get createProfile => 'Profil erstellen';

  @override
  String get done => 'Fertig';

  @override
  String get rename => 'Umbenennen';

  @override
  String get profileActive => 'Aktiv';

  @override
  String get profileSwitch => 'Wechseln';

  @override
  String get readItBack => 'Zurücklesen';

  @override
  String get scanning => 'Wird geprüft…';

  @override
  String get notScannedYet => 'Noch nicht geprüft';

  @override
  String get asItWasKept => 'Wie es aufbewahrt wurde';

  @override
  String lastScanNote(String note) {
    return 'Letzte Prüfung: $note';
  }

  @override
  String get scannedOnImport => 'Beim Import geprüft';

  @override
  String get lastScanManualRescan => 'Letzte Prüfung: manuell erneut geprüft';

  @override
  String alreadyProtectedNothingScanned(int marks) {
    return '$marks schon geschützt · in diesem Durchgang nichts geprüft';
  }

  @override
  String protectedAutomaticallyNeedYourWord(int auto, int open, int normal) {
    return '$auto automatisch geschützt · $open brauchen Ihr Wort · $normal normal';
  }

  @override
  String get vaultLockedRulesAndPackRan =>
      'Tresor verschlossen — Regeln und Sprachpaket liefen, die Tresor-Schicht nicht';

  @override
  String get noVaultNothingRecognisedByName =>
      'Kein Tresor — nichts wird am Namen erkannt';

  @override
  String get unlock => 'Öffnen';

  @override
  String get removeTheDocument => 'Das Dokument entfernen';

  @override
  String get nothingIsOpen => 'Nichts ist geöffnet.';

  @override
  String get thereIsNothingToSendYet => 'Es gibt noch nichts zu senden.';

  @override
  String get readingWhatThoseLinesHold =>
      'Was diese Zeilen enthalten, wird gelesen…';

  @override
  String oneLineProtectedOpen(int protected, int open) {
    return '1 Zeile · $protected darin geschützt · $open offen';
  }

  @override
  String linesProtectedOpen(int lines, int protected, int open) {
    return '$lines Zeilen · $protected darin geschützt · $open offen';
  }

  @override
  String get pressAValueToProtectEveryHeldLine =>
      'Drücken Sie einen Wert, um dieselbe Zelle in jeder gehaltenen Zeile zu schützen.';

  @override
  String get letTheLinesGo => 'Die Zeilen loslassen';

  @override
  String get inStep => 'Im Gleichschritt';

  @override
  String get apart => 'Getrennt';

  @override
  String get drawnAsChips => 'Plättchen';

  @override
  String get drawnPlain => 'Einfach';

  @override
  String get oneSuggestionStillOpen =>
      'Ein Vorschlag ist noch offen. Bis Sie ihn beantworten, steht er hier wie geschrieben — echter Text auf dieser Seite.';

  @override
  String suggestionsStillOpen(int open) {
    return '$open Vorschläge sind noch offen. Bis Sie sie beantworten, stehen sie hier wie geschrieben — der einzige echte Text auf dieser Seite.';
  }

  @override
  String get chooseWhoAnswers => 'Wählen, wer antwortet';

  @override
  String get showTheChat => 'Den Chat zeigen';

  @override
  String get whatWouldYouLikeToAskTheAi => 'Was möchten Sie die KI fragen?';

  @override
  String get whatShouldTheAiDoWithThis => 'Was soll die KI damit tun?';

  @override
  String get askAQuestionOrPasteALetter =>
      'Stellen Sie eine Frage, oder fügen Sie hier einen ganzen Brief ein.';

  @override
  String get reconcileSectionAgainstSection =>
      'Vergleichen Sie Abschnitt A mit Abschnitt B und sagen Sie mir, wo der Unterschied liegt.';

  @override
  String get inWhatWillLeave => 'In dem, was hinausgeht';

  @override
  String get addItToWhatWillLeave => 'Zu dem hinzufügen, was hinausgeht';

  @override
  String get aDocumentCanBeSentWithNoRequest =>
      'Ein Dokument kann ohne Anfrage gesendet werden, und dann erhält das Modell keine Anweisung';

  @override
  String get takeItOut => 'Herausnehmen';

  @override
  String get yourRequestNothingToProtect =>
      'Ihre Anfrage steht in der geschützten Spalte, mit nichts darin zu schützen.';

  @override
  String get yourRequestOneValueReplaced =>
      'Ihre Anfrage steht in der geschützten Spalte, mit einem ersetzten Wert.';

  @override
  String yourRequestValuesReplaced(int count) {
    return 'Ihre Anfrage steht in der geschützten Spalte, mit $count ersetzten Werten.';
  }

  @override
  String get oneRequestAtATime =>
      'Eine Anfrage nach der anderen — eine neue Frage ersetzt diese, und der Chat behält jeden Austausch.';

  @override
  String get oneQuestionLeftGoToIt => '1 Frage offen — dorthin gehen';

  @override
  String questionsLeftGoToTheFirst(int open) {
    return '$open Fragen offen — zur ersten gehen';
  }

  @override
  String get protectIt => 'Schützen';

  @override
  String get leaveItInTheClear => 'Im Klartext lassen';

  @override
  String theOneLeftIsKind(String kind) {
    return 'Die verbleibende ist $kind.';
  }

  @override
  String get showWhatTheAiWillReceive => 'Zeigen, was die KI erhält';

  @override
  String get hideThisColumn => 'Diese Spalte verbergen';

  @override
  String get narrowThisPanel => 'Dieses Feld schmaler machen';

  @override
  String get widenThisPanel => 'Dieses Feld breiter machen';

  @override
  String get oneExchangeCarriedIntoTheNext =>
      'Ein Austausch, der in die nächste Frage mitgenommen wird.';

  @override
  String exchangesCarriedIntoTheNext(int count) {
    return '$count Fragen und Antworten, die in die nächste Frage mitgenommen werden.';
  }

  @override
  String get putTheChatAwayItIsNotEnded =>
      'Den Chat beiseitelegen — er ist nicht beendet';

  @override
  String get theFirstAnswerOpensTheChatHere =>
      'Die erste Antwort öffnet den Chat hier. Jede Frage danach trägt mit, was schon gesagt wurde.';

  @override
  String get askSomethingElseAboutThis => 'Fragen Sie etwas anderes dazu…';

  @override
  String get pasteTheAnswerYouWereGiven =>
      'Fügen Sie die Antwort ein, die Sie erhalten haben…';

  @override
  String get addItToTheChat => 'Zum Chat hinzufügen';

  @override
  String get notNow => 'Jetzt nicht';

  @override
  String get copyTheChat => 'Den Chat kopieren';

  @override
  String get addAnAnswer => 'Eine Antwort hinzufügen';

  @override
  String get endTheChat => 'Den Chat beenden';

  @override
  String get theChatIsOnYourClipboard =>
      'Der Chat liegt geschützt in Ihrer Zwischenablage — bringen Sie die Antwort mit «Eine Antwort hinzufügen» zurück.';

  @override
  String get couldNotReadTheClipboard =>
      'Z Privacy konnte die Zwischenablage nicht lesen.';

  @override
  String get thereIsNoTextOnTheClipboard =>
      'Es ist kein Text in der Zwischenablage.';

  @override
  String get hideTheText => 'Den Text verbergen';

  @override
  String get showTheText => 'Den Text zeigen';

  @override
  String get theTextWithYourNamesBack =>
      'Der Text, mit Ihren Namen zurück — auf diesem Gerät';

  @override
  String get thisAnswerCarriesOneUnknownToken =>
      'Diese Antwort enthält 1 Platzhalter, den diese Sitzung nicht kennt — er wurde in einer anderen Sitzung erzeugt.';

  @override
  String thisAnswerCarriesUnknownTokens(int count) {
    return 'Diese Antwort enthält $count Platzhalter, die diese Sitzung nicht kennt — sie wurden in einer anderen Sitzung erzeugt.';
  }

  @override
  String get copyRestored => 'Wiederhergestelltes kopieren';

  @override
  String get theMarkedWordsWerePutBackHere =>
      'Die markierten Wörter wurden hier wieder eingesetzt, auf diesem Gerät. Das Modell hat sie nie gesehen.';

  @override
  String get theDottedWordsWerePutBackHere =>
      'Die punktierten Wörter wurden hier wieder eingesetzt, auf diesem Gerät. Die durchgestrichenen sind Platzhalter, die diese Sitzung nicht zurückholen kann.';

  @override
  String get copyRestoredTextQuestion => 'Wiederhergestellten Text kopieren?';

  @override
  String get thisWillPlaceTheRealValues =>
      'Dies legt die echten geschützten Werte in Ihre System-Zwischenablage. Andere Anwendungen können die Zwischenablage möglicherweise lesen.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get restoredTextCopied =>
      'Wiederhergestellter Text in die System-Zwischenablage kopiert.';

  @override
  String get chooseWhoAnswersInTheMiddleFirst =>
      'Wählen Sie zuerst in der mittleren Spalte, wer antwortet';

  @override
  String sendThisQuestionTo(String name) {
    return 'Diese Frage an $name senden';
  }

  @override
  String get writeAQuestionFirst => 'Schreiben Sie zuerst eine Frage.';

  @override
  String get settings => 'Einstellungen';

  @override
  String get roomPrivacy => 'Datenschutz';

  @override
  String get roomLanguageAndRules => 'Sprache & Regeln';

  @override
  String get roomVaultAndSecurity => 'Tresor & Sicherheit';

  @override
  String get roomSessions => 'Sitzungen';

  @override
  String get languageAndRulesWhat =>
      'Ein Datenschutzpaket ist ein Erkennungsmodul, nicht die Sprache der Benutzeroberfläche — und in einem Durchgang kann mehr als ein Paket laufen, das hier ist also ein Ausgangspunkt und nicht die einzigen erlaubten Regeln.';

  @override
  String get appLanguage => 'Sprache der App';

  @override
  String get appLanguageWhat =>
      'Die Sprache, in der eine Sitzung gelesen wird, wenn sie keine eigene hat — und welche Gewohnheiten der Scanner darin kennt: Anreden, Firmenformen, die Art, wie eine Kundennummer geschrieben wird. Eine Sitzung, die mit eigener Sprache erstellt wurde, behält diese; alles andere wird in dieser gelesen. Die Benutzeroberfläche folgt dieser Wahl.';

  @override
  String theInterfaceIsEnglishUntilTranslated(String language) {
    return '$language: Das Erkennungspaket ist $language; die Benutzeroberfläche bleibt Englisch, bis ihre Sätze übersetzt sind.';
  }

  @override
  String get myPrivacyRules => 'Meine Datenschutzregeln';

  @override
  String get myPrivacyRulesWhat =>
      'Noch nicht gebaut. Regeln, die Sie selbst schreiben — ein Kundennummernformat, das nur Ihr Büro verwendet, ein Projektcodename — werden hier leben, neben dem Paket und nicht darin.';

  @override
  String get vaultAndSecurityWhat =>
      'Der Schlüssel, das Schloss, und wo Zugangsdaten liegen.';

  @override
  String get zVault => 'Z-Tresor';

  @override
  String get vaultOpenWhat =>
      'Offen. Ihre Identitäten sind geladen und die vierte Erkennungsschicht läuft.';

  @override
  String get vaultLockedWhat =>
      'Verschlossen. Die Regeln und das Paket laufen weiter — eine IBAN wird weiter erkannt — aber nicht, zu wem sie gehört.';

  @override
  String get vaultAbsentWhat =>
      'Auf diesem Gerät nicht erstellt. Nichts wird am Namen erkannt.';

  @override
  String unlockedWithIdentities(int count) {
    return 'Offen · $count Identitäten';
  }

  @override
  String get zPdfReadBack => 'z-pdf — ein geschütztes Dokument zurücklesen';

  @override
  String get zPdfWhat =>
      'Die umgekehrte Handlung. Ein Dokument, das diese App mit Platzhaltern verlassen hat, wird hier aus Ihrem Tresor wieder in seine eigenen Namen zurückgelesen — und es wird nie geprüft, nie geschützt und nie auf eine Werkbank gelegt. Nichts davon wird irgendwohin gesendet.';

  @override
  String get openThisPanelFromTheApp =>
      'Öffnen Sie dieses Feld aus der App, um eine Datei zu wählen.';

  @override
  String get chooseAZPdfFile => 'Eine z-pdf-Datei wählen';

  @override
  String get lockTheVaultAfter => 'Den Tresor verschließen nach';

  @override
  String get minutesUnusedZeroIsNever => 'Minuten ohne Nutzung · 0 = nie';

  @override
  String get lockTheVaultAfterWhat =>
      'Vom Tresor selbst gehalten, nicht von einem Zeitgeber in einem Bildschirm: jeder Weg hinein prüft zuerst die Uhr, ein Fehler in der Benutzeroberfläche kann ihn also nicht offen lassen.';

  @override
  String get encryptedLocalCredentialStorage =>
      'Verschlüsselte lokale Speicherung von Zugangsdaten';

  @override
  String get credentialHomesWhat =>
      'Ein Anbieterschlüssel hat zwei Orte und keinen dritten: versiegelt im Tresor, wenn einer offen ist, oder im Speicher, solange die App offen ist, wenn es keinen gibt. Nie eine Datei im Klartext, und nie zurück an die Benutzeroberfläche — es gibt im ganzen Vertrag keinen Aufruf, der einen zurückgibt.';

  @override
  String get credentialSealedInTheVault => 'versiegelt im Tresor';

  @override
  String get credentialInMemory => 'im Speicher, weg, sobald die App schließt';

  @override
  String get credentialNoKeyStored => 'kein Schlüssel gespeichert';

  @override
  String get noProviderHoldsACredential => 'Kein Anbieter hält Zugangsdaten.';

  @override
  String get deviceBoundProtection => 'Gerätegebundener Schutz';

  @override
  String get deviceBoundWhat =>
      'Noch nicht gebaut. Ein Schlüssel, der an die Authentifizierung dieses Geräts gebunden ist, würde über der Schicht darüber liegen, ohne zu ändern, was gespeichert wird — dieselben Aufzeichnungen, ein Schloss mehr.';

  @override
  String get sessionsWhat =>
      'Eine Sitzung hat ihren eigenen Schlüssel, und die Schlüssel liegen im Tresor.';

  @override
  String get theVaultIsShutNoSessions =>
      'Der Tresor ist verschlossen, es gibt also keine Sitzungen zu zeigen. Öffnen Sie ihn, und sie kommen zurück — die Gespräche selbst waren nie darin.';

  @override
  String get eachSessionHasItsOwnEncryption =>
      'Jede Sitzung hat ihre eigene Verschlüsselung. Derselbe Name nimmt in zwei Sitzungen zwei verschiedene Platzhalter, und in einer Sitzung überall denselben — eine Sitzung ist also, wie Sie wählen, was eine KI zusammenführen kann und was nicht.';

  @override
  String get newSession => 'Neue Sitzung';

  @override
  String get newSessionWhat =>
      'Ein Name und eine Sprache, beide Ihre Wahl: die Sprache ist, wie Z jeden Text in dieser Sitzung liest, und sie wird hier einmal gefragt. Sie wird sofort die Sitzung, in der Sie arbeiten. Was auf dem Dokument vor Ihnen schon geschützt ist, wird in sie umbenannt — gesendet wurde noch nichts, also ist nichts betroffen, was das Gerät verlassen hat.';

  @override
  String get whatIsThisOneAbout => 'Worum geht es hier?';

  @override
  String get begin => 'Beginnen';

  @override
  String get noSessionsYet => 'Noch keine Sitzungen';

  @override
  String get noSessionsYetWhat =>
      'Eine entsteht, sobald Sie zum ersten Mal geschützten Text kopieren oder ein PDF verlangen — sie wird nicht aus Mangel an einem Namen abgelehnt, sie nimmt ihre eigene Nummer als Namen, und Sie können sie hier umbenennen. Sie müssen nie zuerst eine von Hand anlegen.';

  @override
  String theOneYouAreIn(String when, String exchanges) {
    return '$when · $exchanges · die, in der Sie sind';
  }

  @override
  String get workInThisSession => 'In dieser Sitzung arbeiten';

  @override
  String get enter => 'Betreten';

  @override
  String get renameThisSession => 'Diese Sitzung umbenennen';

  @override
  String get deleteThisSession => 'Diese Sitzung löschen';

  @override
  String get oneExchange => '1 Austausch';

  @override
  String exchangesCount(int count) {
    return '$count Fragen und Antworten';
  }

  @override
  String renameSessionNumber(int number) {
    return 'Sitzung $number umbenennen?';
  }

  @override
  String theNumberStaysWhatItIs(int number) {
    return 'Die Nummer bleibt $number — sie ist, was diese Sitzung ist, und nichts, was darin geschützt wurde, ändert sich. Nur das Wort in der Zeile.';
  }

  @override
  String get keepTheName => 'Den Namen behalten';

  @override
  String get renameIt => 'Umbenennen';

  @override
  String deleteNamed(String name) {
    return '«$name» löschen?';
  }

  @override
  String get thisDestroysTheKey =>
      'Dies zerstört den Schlüssel, mit dem diese Sitzung geschützt wurde.';

  @override
  String get everyDocumentCanNeverBeUnprotected =>
      'Jedes Dokument und jede Nachricht, die darin geschützt wurde, kann nie wieder von seinem Schutz befreit werden — nicht von Ihnen und nicht von Z Privacy. Der Schlüssel war das Einzige, was es hätte tun können, und er wird nicht mehr existieren.';

  @override
  String get anythingYouSentStaysAsItWas =>
      'Was Sie aus dieser Sitzung gesendet haben, bleibt genau so, wie es war. Was verschwindet, ist der Weg zurück.';

  @override
  String get keepIt => 'Behalten';

  @override
  String get deleteTheSession => 'Die Sitzung löschen';

  @override
  String get oneProtectedPlace => '1 geschützte Stelle';

  @override
  String protectedPlacesCount(int count) {
    return '$count geschützte Stellen';
  }

  @override
  String get renameThisDocument => 'Dieses Dokument umbenennen';

  @override
  String renameHandle(String handle) {
    return '$handle umbenennen?';
  }

  @override
  String theNameIsWhatYouRead(String handle) {
    return 'Der Name ist, was Sie in dieser Liste lesen. $handle bleibt, was es ist: eine Nummer wird einmal ausgegeben und nie einem anderen Dokument gegeben.';
  }

  @override
  String get aNameForThisDocument => 'Ein Name für dieses Dokument';

  @override
  String get roomAi => 'KI';

  @override
  String get aiWhat =>
      'Drei Wege, ein Modell zu fragen. Der erste braucht überhaupt kein Konto.';

  @override
  String get manualAi => 'KI von Hand';

  @override
  String get manualAiWhat =>
      'Nutzen Sie einen KI-Chat, den Sie schon haben. Kopieren Sie den geschützten Text aus der Arbeitsfläche, fügen Sie ihn in das Modell ein, das Sie verwenden, und bringen Sie die Antwort zurück. Nichts einzurichten, nichts zu bezahlen, und das Zurückholen funktioniert genau gleich.';

  @override
  String get alwaysAvailableFirstDoor =>
      'Immer verfügbar — es ist das Blatt «Wählen, wer antwortet», die erste Tür.';

  @override
  String get directApi => 'Direkte API';

  @override
  String get directApiWhat =>
      'Verbinden Sie sich mit einem entfernten KI-Anbieter mit Ihren API-Zugangsdaten. Der Schlüssel geht einmal hinein und kommt nie wieder heraus — kein Bildschirm in dieser App kann ihn Ihnen wieder zeigen.';

  @override
  String get atThisAddressNoCredential =>
      'An dieser Adresse sind keine Zugangsdaten nötig.';

  @override
  String get protocol => 'Protokoll';

  @override
  String get connectedKeySealed => 'Verbunden · Schlüssel im Tresor versiegelt';

  @override
  String get connectedKeyThisRunOnly =>
      'Verbunden · Schlüssel nur, solange die App offen ist';

  @override
  String get connectedNoKeyNeeded => 'Verbunden · kein Schlüssel nötig';

  @override
  String get notConnected => 'Nicht verbunden';

  @override
  String get localAi => 'KI auf diesem Computer';

  @override
  String get localAiWhat =>
      'Läuft über einen KI-Dienst auf diesem Computer — llama.cpp, Ollama, LM Studio, alles, was in derselben Form antwortet. Kein Schlüssel, kein Konto, und die Anfrage verlässt diesen Computer nie. Einfaches http wird nur für eine wörtliche Loopback-Adresse akzeptiert.';

  @override
  String get models => 'Modelle';

  @override
  String get privacyWhat =>
      'Was die App von selbst tut, und wie weit sie ohne zu fragen geht.';

  @override
  String get noVaultSoThisRunOnly =>
      'Es ist kein Tresor offen, das hier gilt also nur, solange die App offen ist. Der Tresor ist die eine Datei, die diese App schreibt — ohne ihn wird nichts erinnert.';

  @override
  String get scanOnArrival => 'Ein Dokument prüfen, sobald es ankommt';

  @override
  String get scanOnArrivalWhat =>
      'Kein Dialog, kein Knopf. Dies auszuschalten heißt, dass ein Dokument ungeschützt daliegt, bis Sie «Erneut prüfen» drücken — genau der Augenblick, den die Entwürfe vermeiden sollten.';

  @override
  String get answerEverySuggestion =>
      'Jeden Vorschlag beantworten, bevor gesendet wird';

  @override
  String get answerEverySuggestionWhat =>
      'Keine Einstellung. Ein Vorschlag, der nicht beantwortet wurde, wird nie stillschweigend als sicher behandelt, und es gibt kein «trotzdem senden» — nicht hier, nicht in einem versteckten Schalter, nirgends im Code.';

  @override
  String get aRevealedValueStaysFor => 'Ein aufgedeckter Wert bleibt für';

  @override
  String get aRevealedValueStaysForWhat =>
      'Aufdecken zeichnet auf den Bildschirm und schreibt nie in das, was hinausgeht. Dies ist nur, wie lange es gezeichnet bleibt.';

  @override
  String get tokenRotation => 'Platzhalter-Wechsel';

  @override
  String get tokenRotationWhat =>
      'Noch nicht gebaut. Wenn es kommt, wird es hier leben: ob ein dauerhafter Platzhalter seine Nummer über Sitzungen hinweg behält oder jedes Mal neu gezogen wird, damit zwei Sitzungen nicht darüber verbunden werden können.';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get theKeyIsBehindTheLockedVault =>
      'Z Privacy ne peut pas accéder à une clé tant que le coffre est verrouillé. Déverrouillez-le, ou indiquez une clé pour cette fois.';

  @override
  String get theChatKeepsNothing =>
      'Cette réponse est sur votre écran et nulle part ailleurs : aucune session n’est ouverte pour la conserver, donc fermer l’application la fait disparaître avec la discussion.';

  @override
  String get theTokenIsAlreadyOurs => 'Ceci est déjà protégé — Z l’a placé là.';

  @override
  String get unnamedTrouble =>
      'Une erreur s’est produite. Z Privacy n’a pas terminé l’action.';

  @override
  String exactlyWhatWouldLeave(int replaced) {
    return 'Voici ce qui sort de votre document — et, dans l’application, l’échange qui le précède part avec lui. $replaced valeurs ont été remplacées.';
  }

  @override
  String get noLanguageAndASessionIsOpen =>
      'Rien n’a été lu. Un texte se lit avec les habitudes d’une langue, et cette session n’en a jamais reçu — Z Privacy n’a donc pas choisi à votre place. Relancez la lecture et répondez, ou donnez sa langue à la session dans les Paramètres.';

  @override
  String get noLanguageAndNoSession =>
      'Rien n’a été lu. Un texte se lit avec les habitudes d’une langue, et aucune n’a été choisie — rien n’a donc été lu et aucune session n’a été créée. Réessayez et choisissez-en une.';

  @override
  String get troubleNotImplemented =>
      'Cette partie de Z Privacy n’est pas encore construite.';

  @override
  String get troubleInvalidSession =>
      'Cette session n’est plus ouverte. Démarrez-en une nouvelle.';

  @override
  String get troubleInvalidHandle =>
      'Cette demande n’est plus à jour. Vérifiez de nouveau le texte avant de l’envoyer.';

  @override
  String get troubleStalePayload =>
      'Le document a changé après la préparation de cette demande. Vérifiez-le de nouveau, pour que ce que vous envoyez soit ce que vous avez vu en dernier.';

  @override
  String get troubleVaultLocked =>
      'Votre coffre est verrouillé. Déverrouillez-le pour utiliser ce qu’il connaît.';

  @override
  String get troubleVaultRequired =>
      'Déverrouillez ou créez votre coffre avant d’enregistrer ceci pour plus tard.';

  @override
  String get troubleVaultAuthenticationFailed =>
      'Impossible de déverrouiller le coffre. La phrase secrète est peut-être incorrecte, ou le coffre est peut-être endommagé ou modifié.';

  @override
  String get troubleUnsupportedKdfParameters =>
      'Ce coffre utilise des paramètres de sécurité non pris en charge.';

  @override
  String get troubleTrailingVaultData =>
      'Ce fichier de coffre contient des données supplémentaires après sa fin et n’a pas été ouvert.';

  @override
  String get troubleProviderUnavailable =>
      'Ce fournisseur d’IA n’est pas disponible dans cette version.';

  @override
  String get oneWordWaits =>
      'Un mot attend votre réponse — rien n’est sorti de Z.';

  @override
  String wordsWait(int count) {
    return '$count mots attendent votre réponse — rien n’est sorti de Z.';
  }

  @override
  String get troubleVaultAbsent =>
      'Il n’y a pas encore de coffre sur cet appareil. Créez-en un pour conserver quoi que ce soit pour plus tard.';

  @override
  String get troubleVaultAlreadyExists =>
      'Un coffre existe déjà sur cet appareil, et Z Privacy ne l’écrasera pas.';

  @override
  String troubleStorageRefused(String reason) {
    return 'Z Privacy n’utilisera pas cet emplacement — $reason';
  }

  @override
  String get everyCellWasAlreadyProtected =>
      'Toutes les cellules de cette colonne étaient déjà protégées.';

  @override
  String protectedOneCell(String token) {
    return 'Une cellule protégée, sous $token.';
  }

  @override
  String protectedCellsDownTheColumn(int places, String token) {
    return '$places cellules protégées dans cette colonne, la première sous $token.';
  }

  @override
  String protectedAs(String token) {
    return 'Protégé sous $token.';
  }

  @override
  String protectedAsInPlaces(String token, int places) {
    return 'Protégé sous $token, à $places endroits.';
  }

  @override
  String alreadyProtectedBy(String token, String who) {
    return 'Déjà protégé sous $token, par $who.';
  }

  @override
  String belongsToEntity(String entity, String token) {
    return 'Cela appartient à $entity et garde son jeton $token.';
  }

  @override
  String pressCutsIntoProtectedTextOne(String what) {
    return '$what coupe un texte protégé ; rien n’a donc changé. L’ajustement prendrait 1 élément entier.';
  }

  @override
  String pressCutsIntoProtectedTextMany(String what, int items) {
    return '$what coupe un texte protégé ; rien n’a donc changé. L’ajustement prendrait $items éléments entiers.';
  }

  @override
  String get theSelection => 'La sélection';

  @override
  String get thatCell => 'Cette cellule';

  @override
  String get thatPlace => 'Cet endroit';

  @override
  String get sourceRule => 'Règle';

  @override
  String get sourcePack => 'Module de langue';

  @override
  String get sourceVault => 'Coffre';

  @override
  String get sourceYou => 'Vous';

  @override
  String get answeredByHand => 'rapportée à la main';

  @override
  String get answeredNotRecorded => 'non enregistré';

  @override
  String get oneNameCameBack => 'Un nom est revenu.';

  @override
  String namesCameBack(int count) {
    return '$count noms sont revenus.';
  }

  @override
  String oneNameCameBackFrom(String sessions) {
    return 'Un nom est revenu de $sessions.';
  }

  @override
  String namesCameBackFrom(int count, String sessions) {
    return '$count noms sont revenus de $sessions.';
  }

  @override
  String thisDocumentCameBackFrom(String sessions) {
    return 'Ce document est revenu de $sessions.';
  }

  @override
  String get oneNameIsStillATokenVaultShut =>
      'Un nom est encore un jeton : déverrouillez ou créez votre coffre, et Z pourra le rechercher.';

  @override
  String namesAreStillTokensVaultShut(int count) {
    return '$count noms sont encore des jetons : déverrouillez ou créez votre coffre, et Z pourra les rechercher.';
  }

  @override
  String get oneNameStaysATokenTwoCauses =>
      'Un nom reste un jeton, et deux choses différentes produisent cela : le mot a été protégé avant que Z Privacy ne commence à conserver chaque mot protégé, ou ce jeton a été modifié après la sortie du fichier. Ouvrez ce document dans sa session et protégez de nouveau le nom — s’il revient désormais, c’était la première cause ; s’il ne revient pas, ce fichier n’est pas celui qu’a écrit Z Privacy.';

  @override
  String namesStayTokensTwoCauses(int count) {
    return '$count noms restent des jetons, et deux choses différentes produisent cela : ils ont été protégés avant que Z Privacy ne commence à conserver chaque mot protégé, ou les jetons ont été modifiés après la sortie du fichier. Ouvrez ces documents dans leur session et protégez de nouveau les noms — s’ils reviennent désormais, c’était la première cause ; s’ils ne reviennent pas, ce fichier n’est pas celui qu’a écrit Z Privacy.';
  }

  @override
  String get refusalMalformedDocument =>
      'Ce document est endommagé ou incomplet.';

  @override
  String get refusalEncryptedPdf =>
      'Ce PDF est protégé par un mot de passe. Retirez le mot de passe et réessayez.';

  @override
  String get refusalScannedOnePage =>
      'Ce PDF est l’image d’une page sans texte, donc rien n’a pu être lu — et Z Privacy n’importera pas un document qu’il ne peut pas voir.';

  @override
  String refusalScannedPages(int pages) {
    return 'Ce PDF compte $pages pages d’images sans texte, donc rien n’a pu être lu.';
  }

  @override
  String refusalUnsupportedEncoding(int readablePercent, int page) {
    return 'Seuls $readablePercent % de la page $page ont pu être décodés en caractères ; ce document est donc refusé plutôt que lu à moitié. Ouvrez-le et enregistrez-le en texte, ou collez-en le texte.';
  }

  @override
  String refusalUnreadableStructure(int page) {
    return 'La page $page est construite d’une manière que cette version ne sait pas lire.';
  }

  @override
  String refusalTextInDisplayForms(int percent) {
    return '$percent % de l’arabe de ce texte est écrit dans les formes d’affichage que dessine un logiciel de mise en page ; ce que Z a lu est donc dans l’ordre où il a été dessiné, et non dans l’ordre où il a été écrit — les mots et les nombres sortent à l’envers. Z ne protégera pas un texte qu’il a lu à l’envers : un nom lu à l’envers est un nom qu’il ne peut pas protéger. Un fichier Word ou un fichier texte brut se lit dans l’ordre où il a été écrit.';
  }

  @override
  String refusalDocumentTooLarge(int mib, int limitMib) {
    return 'Ce fichier fait environ $mib Mio, et Z Privacy ouvre les documents jusqu’à $limitMib Mio.';
  }

  @override
  String refusalTooManyPages(int pages, int limit) {
    return 'Ce document compte $pages pages, et Z Privacy en ouvre jusqu’à $limit dans un même document.';
  }

  @override
  String refusalTextTooLarge(int limitMib) {
    return 'Une fois décompressée, une partie de ce fichier dépasse $limitMib Mio — plus que ce que Z Privacy lit dans un même document ; rien n’en a donc été importé.';
  }

  @override
  String refusalCompressionBomb(int ratio) {
    return 'Une partie de ce fichier se décompresse en plus de $ratio fois la place qu’elle occupe. Aucun vrai document ne fait cela ; Z Privacy a donc arrêté de la décompresser au lieu de remplir la machine.';
  }

  @override
  String refusalTooManyParts(int parts, int limit) {
    return 'Ce fichier déclare $parts parties, et un document en compte des dizaines, pas des milliers — Z Privacy en ouvre jusqu’à $limit.';
  }

  @override
  String refusalTookTooLong(int seconds) {
    return 'La lecture de ce fichier durait encore après $seconds secondes ; Z Privacy l’a donc arrêtée. Rien n’en a été importé.';
  }

  @override
  String get refusalEmptyDocument =>
      'Ce fichier ne contient aucun texte que Z Privacy puisse protéger.';

  @override
  String get networkNotConnected =>
      'Aucun fournisseur d’IA n’est connecté. Ajoutez d’abord une adresse et une clé.';

  @override
  String get networkInsecureUrl =>
      'Cette adresse n’est pas sûre pour un envoi.';

  @override
  String get networkRedirected =>
      'Cette adresse nous a renvoyés ailleurs. Z Privacy ne suit pas les redirections avec votre texte ; rien n’a donc été envoyé.';

  @override
  String networkBadStatus(int status) {
    return 'Le fournisseur a refusé la demande avec le statut $status. Z Privacy n’a rien conservé de votre document.';
  }

  @override
  String get networkTimeout =>
      'Le fournisseur n’a pas répondu à temps. Rien d’autre n’a été envoyé.';

  @override
  String networkResponseTooLarge(int limitKib) {
    return 'La réponse dépassait $limitKib Kio et n’a pas été lue.';
  }

  @override
  String networkPayloadTooLarge(int kib, int limitKib) {
    return 'Ce texte fait $kib Kio et le fournisseur accepte $limitKib Kio par demande.';
  }

  @override
  String get networkUnreadable =>
      'Le fournisseur a renvoyé quelque chose qui n’est pas une réponse.';

  @override
  String get networkUnreachable =>
      'Cette adresse est restée injoignable — rien n’a répondu. Vérifiez que vous êtes en ligne et que l’adresse est correcte. Rien n’a été envoyé.';

  @override
  String get troubleVaultChangedElsewhere =>
      'Une autre copie de Z Privacy a modifié ce coffre. Fermez cette fenêtre-là, ou verrouillez puis déverrouillez ici pour reprendre son travail.';

  @override
  String get troubleSessionChangedElsewhere =>
      'Le fichier de cette session sur votre disque n’a pas été écrit par cette fenêtre ; Z Privacy ne l’a donc pas écrasé. Fermez l’autre copie, ou verrouillez puis déverrouillez ici pour lire ce qu’elle a écrit.';

  @override
  String troubleStoragePermissionsKept(String reason) {
    return 'Z Privacy ne modifiera pas une autorisation que vous avez définie ; rien n’a donc été enregistré — $reason. Modifiez l’autorisation vous-même, ou choisissez un autre dossier.';
  }

  @override
  String get troubleBadSpan =>
      'Cette sélection n’a pas pu être lue. Sélectionnez de nouveau les mots.';

  @override
  String get troubleBetweenColumns =>
      'Ce clic est tombé dans l’espace entre deux colonnes ; il ne désigne donc aucune valeur — et Z Privacy ne choisira pas une colonne à votre place.';

  @override
  String get troubleUnknownToken =>
      'Cette valeur protégée n’est pas dans cette session.';

  @override
  String get troubleNothingToSend =>
      'Il n’y a encore rien à envoyer. Ajoutez un document ou écrivez un texte.';

  @override
  String get troubleSessionWithoutItsDocument =>
      'La session n’a pas été démarrée, car Z Privacy n’a pas pu déterminer quel document vous avez ouvert — et une session doit renommer ce qui y est déjà protégé. Rien n’a été modifié. Ouvrez le document et démarrez la session à partir de lui.';

  @override
  String get troublePayloadAlreadySent =>
      'Cette demande a déjà été envoyée. Préparez-la de nouveau pour l’envoyer encore une fois.';

  @override
  String get theReasonWasNotReported => 'la raison n’a pas été indiquée.';

  @override
  String get carriesFirst => 'Ce document contient';

  @override
  String get carriesAlso => 'Il contient aussi';

  @override
  String carriesOneNameFromElsewhere(String also, String which) {
    return '$also 1 nom provenant d’une session que ce coffre ne détient pas ($which). Rien ici ne peut le remettre : la clé qui l’a créé n’est pas dans ce coffre.';
  }

  @override
  String carriesNamesFromOneSessionElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count noms provenant d’une session que ce coffre ne détient pas ($which). Rien ici ne peut les remettre : la clé qui les a créés n’est pas dans ce coffre.';
  }

  @override
  String carriesNamesFromSessionsElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count noms provenant de sessions que ce coffre ne détient pas ($which). Rien ici ne peut les remettre : les clés qui les ont créés ne sont pas dans ce coffre.';
  }

  @override
  String carriesNamesFromElsewhereWithNoCount(
    String also,
    String whose,
    String which,
    String keys,
  ) {
    return '$also des noms provenant $whose ($which). Rien ici ne peut les remettre : $keys pas dans ce coffre.';
  }

  @override
  String get aSessionThisVaultDoesNotHold =>
      'd’une session que ce coffre ne détient pas';

  @override
  String get sessionsThisVaultDoesNotHold =>
      'de sessions que ce coffre ne détient pas';

  @override
  String get theKeyThatMadeThemIs => 'les clés qui les ont créés ne sont';

  @override
  String get andBetweenNames => ' et ';

  @override
  String get thisLanguageName => 'Français';

  @override
  String get languageWord => 'Langue';

  @override
  String get chooseALanguage => 'Choisissez une langue pour continuer.';

  @override
  String get noAccount => 'Aucun compte.';

  @override
  String get noAds => 'Aucune publicité.';

  @override
  String get noAnalytics => 'Aucune mesure d’audience ni donnée de suivi.';

  @override
  String get noZPrivacyServer => 'Aucun serveur Z Privacy.';

  @override
  String get originalDataStaysHere =>
      'Vos données originales restent sur cet appareil, sauf si vous copiez explicitement un contenu restauré.';

  @override
  String get onlyTheProtectedVersionIsSent =>
      'Seule la version protégée est envoyée à l’IA via Z Privacy.';

  @override
  String get theseRulesWillBeEnabled =>
      'Les règles de confidentialité françaises seront activées.';

  @override
  String get start => 'Commencer';

  @override
  String get yourVault => 'Votre coffre';

  @override
  String get createAVault => 'Créer un coffre';

  @override
  String get vaultWhy =>
      'Chaque mot que vous protégez est conservé ici, aussi longtemps que vous gardez ce coffre : les noms que vous ajoutez, les valeurs que vous enseignez et les clés de toute IA que vous connectez. Il reste sur cet ordinateur, et rien n’est écrit ailleurs.';

  @override
  String get onePassphrase =>
      'Une seule phrase secrète, conservée sur cet appareil. Tout ce que Z apprend pendant que vous travaillez — vos noms, vos listes, vos décisions — y est conservé.';

  @override
  String get byYourVoices => 'par YourVoices';

  @override
  String pageHasNothingMarked(int page) {
    return 'La page $page ne contient rien que l’analyseur ait marqué.';
  }

  @override
  String get addADocumentPdfWordOrText =>
      'Ajouter un document — PDF, Word ou texte';

  @override
  String get addADocumentOrWriteToTheAi =>
      'Ajoutez un document — ou écrivez à l’IA dans la première partie, sans aucun document.';

  @override
  String get originalLocalOnly => 'Original — local uniquement';

  @override
  String get neverSentToAiSendCannotRead =>
      'Jamais envoyé à l’IA · L’envoi ne peut pas lire ce côté';

  @override
  String get yourDocumentArrivesHere =>
      'Votre document arrive ici, tel qu’il est écrit. Rien de ce côté ne peut atteindre le réseau.';

  @override
  String get safeAiWillReceive => 'Protégé — ce que l’IA recevra';

  @override
  String get theRequestItselfNotAPreview =>
      'La demande elle-même, pas un aperçu';

  @override
  String get whatAnAiWouldReceiveStandsHere =>
      'Ce qu’une IA recevrait s’affiche ici, à côté de l’original, mot pour mot, avant tout envoi.';

  @override
  String get theChatTitle => 'La discussion';

  @override
  String get yourQuestionsAndWhatCameBack =>
      'Vos questions, et ce qui est revenu';

  @override
  String get theChatOpensHereWithTheFirstAnswer =>
      'La discussion s’ouvre ici avec la première réponse, et chaque question suivante emporte l’échange qui la précède.';

  @override
  String get typedText => 'Texte saisi';

  @override
  String get onePage => '1 page';

  @override
  String pagesCount(int pages) {
    return '$pages pages';
  }

  @override
  String get vaultLabel => 'Coffre';

  @override
  String get vaultIsUnlocked => 'Déverrouillé';

  @override
  String get vaultIsLocked => 'Verrouillé';

  @override
  String get vaultIsNone => 'Aucun';

  @override
  String get yourVaultIsIn => 'Votre coffre se trouve dans';

  @override
  String get aVaultHereWouldBeIn => 'Un coffre créé ici se trouverait dans';

  @override
  String get openZVault => 'Ouvrir Z Vault';

  @override
  String get lockNow => 'Verrouiller maintenant';

  @override
  String get openZVaultOrLockItNow =>
      'Ouvrir Z Vault, ou le verrouiller maintenant';

  @override
  String get goToAPage => 'Aller à une page';

  @override
  String pageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get pageWord => 'Page';

  @override
  String get chooseTheAiAndWhatTravels =>
      'Choisir l’IA et ce qui lui est envoyé';

  @override
  String get readThisDocumentWithAnotherRuleSet =>
      'Lire ce document avec un autre jeu de règles';

  @override
  String get generalRulesOnly => 'Règles générales uniquement';

  @override
  String get packLabel => 'Module de langue';

  @override
  String packWithGeneralRules(String pack) {
    return '$pack · règles générales';
  }

  @override
  String get everywhere => 'Partout';

  @override
  String get profile => 'Profil';

  @override
  String get profiles => 'Profils';

  @override
  String get chooseWhichClientDictionary =>
      'Choisissez le dictionnaire client qu’utilise cette session. L’identifiant du profil reste dans le coffre ; le nom affiché est ce que les gens voient.';

  @override
  String get onlyIdentitiesForEveryProfile =>
      'Uniquement les identités et les règles qui s’appliquent à tous les profils.';

  @override
  String get createProfile => 'Créer un profil';

  @override
  String get done => 'Terminé';

  @override
  String get rename => 'Renommer';

  @override
  String get profileActive => 'Actif';

  @override
  String get profileSwitch => 'Basculer';

  @override
  String get readItBack => 'Relire';

  @override
  String get scanning => 'Analyse…';

  @override
  String get notScannedYet => 'Pas encore analysé';

  @override
  String get asItWasKept => 'Tel qu’il a été conservé';

  @override
  String lastScanNote(String note) {
    return 'Dernière analyse : $note';
  }

  @override
  String get scannedAsYouTyped => 'Analysé pendant la saisie';

  @override
  String get scannedOnImport => 'Analysé à l’importation';

  @override
  String get lastScanManualRescan => 'Dernière analyse : relancée manuellement';

  @override
  String alreadyProtectedNothingScanned(int marks) {
    return '$marks déjà protégés · rien d’analysé lors de ce passage';
  }

  @override
  String protectedAutomaticallyNeedYourWord(int auto, int open, int normal) {
    return '$auto protégés automatiquement · $open attendent votre avis · $normal normaux';
  }

  @override
  String get vaultLockedRulesAndPackRan =>
      'Coffre verrouillé — les règles et le module de langue ont été appliqués, la couche du coffre non';

  @override
  String get noVaultNothingRecognisedByName =>
      'Aucun coffre — rien n’est reconnu par son nom';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get removeTheDocument => 'Retirer le document';

  @override
  String get nothingIsOpen => 'Rien n’est ouvert.';

  @override
  String get thereIsNothingToSendYet => 'Il n’y a encore rien à envoyer.';

  @override
  String get readingWhatThoseLinesHold => 'Lecture du contenu de ces lignes…';

  @override
  String oneLineProtectedOpen(int protected, int open) {
    return '1 ligne · $protected protégés dedans · $open en attente';
  }

  @override
  String linesProtectedOpen(int lines, int protected, int open) {
    return '$lines lignes · $protected protégés dedans · $open en attente';
  }

  @override
  String get pressAValueToProtectEveryHeldLine =>
      'Cliquez sur une valeur pour protéger la même cellule dans chaque ligne retenue.';

  @override
  String get letTheLinesGo => 'Relâcher les lignes';

  @override
  String get inStep => 'Synchronisé';

  @override
  String get apart => 'Séparé';

  @override
  String get drawnAsChips => 'Pastilles';

  @override
  String get drawnPlain => 'Texte brut';

  @override
  String get oneSuggestionStillOpen =>
      'Une suggestion est encore en attente. Tant que vous n’y avez pas répondu, elle figure ici telle qu’elle est écrite — du vrai texte de ce côté.';

  @override
  String suggestionsStillOpen(int open) {
    return '$open suggestions sont encore en attente. Tant que vous n’y avez pas répondu, elles figurent ici telles qu’elles sont écrites — le seul vrai texte de ce côté.';
  }

  @override
  String get chooseWhoAnswers => 'Choisir qui répond';

  @override
  String get showTheChat => 'Afficher la discussion';

  @override
  String get whatWouldYouLikeToAskTheAi => 'Que voulez-vous demander à l’IA ?';

  @override
  String get whatShouldTheAiDoWithThis => 'Que doit faire l’IA avec ceci ?';

  @override
  String get askAQuestionOrPasteALetter =>
      'Posez une question, ou collez ici une lettre entière.';

  @override
  String get reconcileSectionAgainstSection =>
      'Rapprochez la section A de la section B et dites-moi où se trouve la différence.';

  @override
  String get inWhatWillLeave => 'Dans ce qui sortira';

  @override
  String get addItToWhatWillLeave => 'L’ajouter à ce qui sortira';

  @override
  String get aDocumentCanBeSentWithNoRequest =>
      'Un document peut être envoyé sans demande ; le modèle ne reçoit alors aucune instruction';

  @override
  String get takeItOut => 'La retirer';

  @override
  String get yourRequestNothingToProtect =>
      'Votre demande figure dans la colonne Protégé, sans rien à protéger.';

  @override
  String get yourRequestOneValueReplaced =>
      'Votre demande figure dans la colonne Protégé, avec une valeur remplacée.';

  @override
  String yourRequestValuesReplaced(int count) {
    return 'Votre demande figure dans la colonne Protégé, avec $count valeurs remplacées.';
  }

  @override
  String get oneRequestAtATime =>
      'Une demande à la fois — une nouvelle question remplace celle-ci, et la discussion garde chaque échange.';

  @override
  String get oneQuestionLeftGoToIt => '1 question restante — y aller';

  @override
  String questionsLeftGoToTheFirst(int open) {
    return '$open questions restantes — aller à la première';
  }

  @override
  String get protectIt => 'Le protéger';

  @override
  String get leaveItInTheClear => 'Le laisser en clair';

  @override
  String theOneLeftIsKind(String kind) {
    return 'Celui qui reste est de type $kind.';
  }

  @override
  String get showWhatTheAiWillReceive => 'Afficher ce que l’IA recevra';

  @override
  String get hideThisColumn => 'Masquer cette colonne';

  @override
  String get narrowThisPanel => 'Réduire ce panneau';

  @override
  String get widenThisPanel => 'Élargir ce panneau';

  @override
  String get oneExchangeCarriedIntoTheNext =>
      'Un échange, emporté dans la question suivante.';

  @override
  String exchangesCarriedIntoTheNext(int count) {
    return '$count échanges, emportés dans la question suivante.';
  }

  @override
  String get putTheChatAwayItIsNotEnded =>
      'Ranger la discussion — elle n’est pas terminée';

  @override
  String get theFirstAnswerOpensTheChatHere =>
      'La première réponse ouvre la discussion ici. Chaque question suivante emporte l’échange qui la précède — pas toute la discussion, et jamais de nouveau le document.';

  @override
  String get askSomethingElseAboutThis => 'Demander autre chose à ce sujet…';

  @override
  String get pasteTheAnswerYouWereGiven =>
      'Collez la réponse que vous avez reçue…';

  @override
  String get addItToTheChat => 'L’ajouter à la discussion';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get copyTheChat => 'Copier la discussion';

  @override
  String get addAnAnswer => 'Ajouter une réponse';

  @override
  String get endTheChat => 'Terminer la discussion';

  @override
  String get theChatIsOnYourClipboard =>
      'Ce qui sortirait est dans votre presse-papiers, protégé — la question telle qu’une IA la recevrait. Rapportez la réponse avec « Ajouter une réponse ».';

  @override
  String get couldNotReadTheClipboard =>
      'Z Privacy n’a pas pu lire le presse-papiers.';

  @override
  String get thereIsNoTextOnTheClipboard =>
      'Le presse-papiers ne contient aucun texte.';

  @override
  String get hideTheText => 'Masquer le texte';

  @override
  String get showTheText => 'Afficher le texte';

  @override
  String get theTextWithYourNamesBack =>
      'Le texte, avec vos noms remis — sur cet appareil';

  @override
  String get thisAnswerCarriesOneUnknownToken =>
      'Cette réponse contient 1 jeton que cette session ne connaît pas — il a été créé dans une autre session.';

  @override
  String thisAnswerCarriesUnknownTokens(int count) {
    return 'Cette réponse contient $count jetons que cette session ne connaît pas — ils ont été créés dans une autre session.';
  }

  @override
  String get copyRestored => 'Copier le texte restauré';

  @override
  String get theMarkedWordsWerePutBackHere =>
      'Les mots marqués ont été remis ici, sur cet appareil. Le modèle ne les a jamais vus.';

  @override
  String get theDottedWordsWerePutBackHere =>
      'Les mots soulignés en pointillé ont été remis ici, sur cet appareil. Les mots barrés sont des jetons que cette session ne peut pas remettre.';

  @override
  String get copyRestoredTextQuestion => 'Copier le texte restauré ?';

  @override
  String get thisWillPlaceTheRealValues =>
      'Cette action placera les vraies valeurs protégées dans le presse-papiers de votre système. D’autres applications pourront peut-être lire le presse-papiers.';

  @override
  String get cancel => 'Annuler';

  @override
  String get restoredTextCopied =>
      'Texte restauré copié dans le presse-papiers du système.';

  @override
  String get chooseWhoAnswersInTheMiddleFirst =>
      'Choisissez d’abord qui répond, dans la colonne du milieu';

  @override
  String sendThisQuestionTo(String name) {
    return 'Envoyer cette question à $name';
  }

  @override
  String get writeAQuestionFirst => 'Écrivez d’abord une question.';

  @override
  String get settings => 'Paramètres';

  @override
  String get roomPrivacy => 'Confidentialité';

  @override
  String get roomLanguageAndRules => 'Langue et règles';

  @override
  String get roomVaultAndSecurity => 'Coffre et sécurité';

  @override
  String get roomSessions => 'Sessions';

  @override
  String get languageAndRulesWhat =>
      'Un module de langue est un moteur de détection, pas la langue de l’interface — et plusieurs modules de langue peuvent fonctionner dans une même analyse ; ceci est donc un point de départ, pas les seules règles autorisées.';

  @override
  String get appLanguage => 'Langue de l’application';

  @override
  String get appLanguageWhat =>
      'La langue avec laquelle une session est lue quand elle n’en a pas une à elle — et les habitudes que l’analyseur y connaît : formules de politesse, formes juridiques des sociétés, façon d’écrire un numéro client. Une session créée avec sa propre langue garde celle-ci ; c’est avec celle-ci que tout autre texte est lu. L’interface suit ce choix.';

  @override
  String theInterfaceIsEnglishUntilTranslated(String language) {
    return '$language : le module de langue est $language ; l’interface reste en anglais jusqu’à ce que ses phrases soient traduites.';
  }

  @override
  String get myPrivacyRules => 'Mes règles de confidentialité';

  @override
  String get myPrivacyRulesWhat =>
      'Pas encore construit. Les règles que vous écrivez vous-même — un format de numéro client propre à votre cabinet, un nom de code de projet — figureront ici, à côté du module de langue et non à l’intérieur.';

  @override
  String get vaultAndSecurityWhat =>
      'La clé, le verrou, et l’endroit où se trouve un identifiant d’accès.';

  @override
  String get zVault => 'Coffre Z';

  @override
  String get vaultOpenWhat =>
      'Ouvert. Vos identités sont chargées et la quatrième couche de détection fonctionne.';

  @override
  String get vaultLockedWhat =>
      'Verrouillé. Les règles et le module de langue fonctionnent toujours — un IBAN est toujours repéré — mais pas l’identité de son titulaire.';

  @override
  String get vaultAbsentWhat =>
      'Pas créé sur cet appareil. Rien n’est reconnu par son nom.';

  @override
  String unlockedWithIdentities(int count) {
    return 'Déverrouillé · $count identités';
  }

  @override
  String get zPdfReadBack => 'z-pdf — relire un document protégé';

  @override
  String get zPdfWhat =>
      'L’opération inverse. Un document sorti de cette application avec des jetons est relu avec ses propres noms, ici, à partir de votre coffre — et il n’est jamais analysé, jamais protégé et jamais placé sur le plan de travail. Rien de lui n’est envoyé nulle part.';

  @override
  String get openThisPanelFromTheApp =>
      'Ouvrez ce panneau depuis l’application pour choisir un fichier.';

  @override
  String get chooseAZPdfFile => 'Choisir un fichier z-pdf';

  @override
  String get lockTheVaultAfter => 'Verrouiller le coffre après';

  @override
  String get minutesUnusedZeroIsNever => 'minutes d’inactivité · 0 = jamais';

  @override
  String get lockTheVaultAfterWhat =>
      'Assuré par le coffre lui-même, pas par une minuterie dans un écran : chaque accès au coffre vérifie d’abord l’heure, donc un défaut de l’interface ne peut pas le laisser ouvert.';

  @override
  String get encryptedLocalCredentialStorage =>
      'Stockage local chiffré des identifiants';

  @override
  String get credentialHomesWhat =>
      'Une clé de fournisseur a deux emplacements et pas de troisième : scellée dans le coffre quand il est ouvert, ou en mémoire pour cette exécution quand il n’y en a pas. Jamais dans un fichier en clair, et jamais renvoyée à l’interface — aucun appel de tout le contrat ne la restitue.';

  @override
  String get credentialSealedInTheVault => 'scellée dans le coffre';

  @override
  String get credentialInMemory =>
      'en mémoire, effacée à la fermeture de l’application';

  @override
  String get credentialNoKeyStored => 'aucune clé enregistrée';

  @override
  String get noProviderHoldsACredential =>
      'Aucun fournisseur ne détient d’identifiant.';

  @override
  String get deviceBoundProtection => 'Protection liée à l’appareil';

  @override
  String get deviceBoundWhat =>
      'Pas encore construit. Une clé liée à l’authentification propre à cet appareil s’ajouterait au-dessus de la couche supérieure, sans changer ce qui est stocké — les mêmes données, un verrou de plus.';

  @override
  String get sessionsWhat =>
      'Une session a sa propre clé, et les clés sont dans le coffre.';

  @override
  String get theVaultIsShutNoSessions =>
      'Le coffre est fermé, il n’y a donc aucune session à afficher. Ouvrez-le et elles reviennent — les discussions elles-mêmes n’y ont jamais été.';

  @override
  String get eachSessionHasItsOwnEncryption =>
      'Chaque session a son propre chiffrement. Le même nom dans deux sessions prend deux jetons différents, et dans une même session il prend le même partout où il apparaît — une session est donc la manière de choisir ce qu’une IA peut rapprocher et ce qu’elle ne peut pas rapprocher. Les clés sont toutes dans votre coffre ; relire un fichier protégé passe donc par le coffre lui-même et non par une session : tout ce qui a été enregistré depuis n’importe quelle session de ce coffre revient avec ses vrais noms, et la lecture indique de quelle session ils viennent.';

  @override
  String get newSession => 'Nouvelle session';

  @override
  String get newSessionWhat =>
      'Un nom et une langue, que vous choisissez tous deux : la langue est la manière dont Z lit chaque texte de cette session, et elle n’est demandée qu’une fois, ici. Elle devient aussitôt la session dans laquelle vous travaillez. Tout ce qui est déjà protégé dans le document devant vous y est renommé — rien n’a encore été envoyé, donc rien de ce qui est sorti n’est concerné.';

  @override
  String get whatIsThisOneAbout => 'De quoi s’agit-il ?';

  @override
  String get begin => 'Commencer';

  @override
  String get noSessionsYet => 'Aucune session pour l’instant';

  @override
  String get noSessionsYetWhat =>
      'Une session naît la première fois que vous copiez un texte protégé ou demandez un PDF — elle n’est pas refusée faute de nom, elle prend son propre numéro comme nom, et vous pouvez la renommer ici. Vous n’avez jamais besoin d’en créer une à la main au préalable.';

  @override
  String theOneYouAreIn(String when, String exchanges) {
    return '$when · $exchanges · celle où vous êtes';
  }

  @override
  String get workInThisSession => 'Travailler dans cette session';

  @override
  String get enter => 'Entrer';

  @override
  String get renameThisSession => 'Renommer cette session';

  @override
  String get deleteThisSession => 'Supprimer cette session';

  @override
  String get oneExchange => '1 échange';

  @override
  String exchangesCount(int count) {
    return '$count échanges';
  }

  @override
  String renameSessionNumber(int number) {
    return 'Renommer la session $number ?';
  }

  @override
  String theNumberStaysWhatItIs(int number) {
    return 'Le numéro reste $number — c’est ce qu’est cette session, et rien de ce qui y a été protégé ne change. Seul le mot affiché sur la ligne change.';
  }

  @override
  String get keepTheName => 'Garder le nom';

  @override
  String get renameIt => 'Renommer';

  @override
  String deleteNamed(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get thisDestroysTheKey =>
      'Cette action détruit la clé avec laquelle cette session a été protégée.';

  @override
  String get everyDocumentCanNeverBeUnprotected =>
      'Ce qui est déjà sorti de cette session sous forme protégée ne pourra plus jamais être déprotégé — ni par vous, ni par Z Privacy. La clé était la seule chose qui aurait pu le faire, et elle n’existera plus. « Annuler la protection » retire une couverture du texte devant vous, jamais de ce qui est parti.';

  @override
  String get anythingYouSentStaysAsItWas =>
      'Tout ce que vous avez envoyé depuis cette session reste exactement tel quel. Ce qui disparaît, c’est le chemin du retour.';

  @override
  String get keepIt => 'La garder';

  @override
  String get deleteTheSession => 'Supprimer la session';

  @override
  String get oneProtectedPlace => '1 endroit protégé';

  @override
  String protectedPlacesCount(int count) {
    return '$count endroits protégés';
  }

  @override
  String get renameThisDocument => 'Renommer ce document';

  @override
  String renameHandle(String handle) {
    return 'Renommer $handle ?';
  }

  @override
  String theNameIsWhatYouRead(String handle) {
    return 'Le nom est ce que vous lisez dans cette liste. $handle reste ce qu’il est : un numéro ne sert qu’une fois et n’est jamais attribué à un autre document.';
  }

  @override
  String get aNameForThisDocument => 'Un nom pour ce document';

  @override
  String get roomAi => 'IA';

  @override
  String get aiWhat =>
      'Trois façons d’interroger un modèle. La première ne demande aucun compte.';

  @override
  String get manualAi => 'IA manuelle';

  @override
  String get manualAiWhat =>
      'Utilisez une discussion d’IA que vous avez déjà. Copiez le texte protégé depuis l’espace de travail, collez-le dans le modèle que vous utilisez, et rapportez la réponse. Rien à configurer, rien à payer, et la restauration fonctionne exactement de la même façon.';

  @override
  String get alwaysAvailableFirstDoor =>
      'Toujours disponible — c’est la première option de la feuille « Choisir qui répond ».';

  @override
  String get directApi => 'API directe';

  @override
  String get directApiWhat =>
      'Connectez-vous à un fournisseur d’IA distant avec votre identifiant d’API. La clé est saisie une fois et n’en ressort jamais — aucun écran de cette application ne peut vous la montrer de nouveau.';

  @override
  String get atThisAddressNoCredential =>
      'À cette adresse, aucun identifiant n’est nécessaire.';

  @override
  String get protocol => 'Protocole';

  @override
  String get connectedKeySealed => 'Connecté · clé scellée dans le coffre';

  @override
  String get connectedKeyThisRunOnly =>
      'Connecté · clé conservée pour cette exécution uniquement';

  @override
  String get connectedNoKeyNeeded => 'Connecté · aucune clé nécessaire';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get localAi => 'IA locale';

  @override
  String get localAiWhat =>
      'Fonctionne via un service d’IA sur cet ordinateur — llama.cpp, Ollama, LM Studio, tout ce qui répond au même format. Aucune clé, aucun compte, et la demande ne quitte jamais cet ordinateur. Le http simple n’est accepté que pour une adresse de bouclage littérale.';

  @override
  String get models => 'Modèles';

  @override
  String get privacyWhat =>
      'Ce que l’application fait d’elle-même, et jusqu’où elle va sans demander.';

  @override
  String get noVaultSoThisRunOnly =>
      'Aucun coffre n’est ouvert ; ces réglages valent donc pour cette exécution uniquement — sans coffre, il n’y a rien pour les conserver.';

  @override
  String get scanOnArrival => 'Analyser un document dès son arrivée';

  @override
  String get scanOnArrivalWhat =>
      'Aucune boîte de dialogue, aucun bouton. Désactiver ceci signifie qu’un document reste non protégé jusqu’à ce que vous appuyiez sur Réanalyser — précisément le moment que la conception voulait éviter.';

  @override
  String get answerEverySuggestion =>
      'Répondre à chaque suggestion avant l’envoi';

  @override
  String get answerEverySuggestionWhat =>
      'Ce n’est pas un réglage. Une suggestion sans réponse n’est jamais traitée en silence comme sûre, et il n’existe pas d’« envoyer quand même » — ni ici, ni dans une option cachée, ni nulle part dans le code.';

  @override
  String get aRevealedValueStaysFor =>
      'Une valeur révélée reste affichée pendant';

  @override
  String get aRevealedValueStaysForWhat =>
      'Révéler affiche à l’écran et n’écrit jamais dans ce qui sort. Ceci indique seulement combien de temps elle reste affichée.';

  @override
  String get tokenRotation => 'Rotation des jetons';

  @override
  String get tokenRotationWhat =>
      'Pas encore construit. Quand ce le sera, ce sera ici : un jeton permanent garde-t-il son numéro d’une session à l’autre, ou est-il tiré de nouveau chaque fois, pour que deux sessions ne puissent pas être reliées par lui.';

  @override
  String get back => 'Retour';

  @override
  String get allIdentities => 'Toutes les identités';

  @override
  String identitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identités',
      one: '1 identité',
    );
    return '$_temp0';
  }

  @override
  String valuesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valeurs',
      one: '1 valeur',
    );
    return '$_temp0';
  }

  @override
  String protectedWordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots protégés',
      one: '1 mot protégé',
    );
    return '$_temp0';
  }

  @override
  String get notCreatedOnThisDevice => 'Pas créé sur cet appareil';

  @override
  String get changePassphrase => 'Changer la phrase secrète';

  @override
  String get lockTheVault => 'Verrouiller';

  @override
  String get theVaultIsLocked => 'Le coffre est verrouillé';

  @override
  String get thereIsNoVaultYet => 'Il n’y a pas encore de coffre';

  @override
  String get yourIdentitiesAreSealed =>
      'Vos identités sont sur cet appareil, scellées. Tant que le coffre n’est pas ouvert, l’analyseur applique toujours ses règles et son module de langue — un IBAN est toujours repéré — mais pas à qui il appartient.';

  @override
  String get yourNamesLiveInOneVaultFile =>
      'Vos noms sont conservés dans un fichier de coffre chiffré. Il contient vos personnes et leurs valeurs, chiffrées avec une phrase secrète qui ne quitte jamais cet appareil. Sans coffre, rien n’est reconnu par son nom.';

  @override
  String get searchThisDevice =>
      'Rechercher sur cet appareil — noms, valeurs, graphies';

  @override
  String get newIdentity => 'Nouvelle identité';

  @override
  String get filterAll => 'Tous';

  @override
  String get sessionProfile => 'Profil de la session';

  @override
  String get newProfile => 'Nouveau profil';

  @override
  String get noIdentitiesYet =>
      'Aucune identité pour l’instant. La première est généralement le client dont vous traitez les documents.';

  @override
  String nothingMatchesQuery(String query) {
    return 'Rien sur cet appareil ne correspond à « $query ».';
  }

  @override
  String get valuesITaught => 'Valeurs que j’ai enseignées';

  @override
  String get valuesITaughtWhat =>
      'noms, sociétés, numéros — repérés d’eux-mêmes désormais';

  @override
  String get rulesITaught => 'Règles que j’ai enseignées';

  @override
  String get rulesITaughtWhat =>
      'des mots qui disent ce qui les suit — « après Mandantenkennung → numéro client »';

  @override
  String get exceptionsITaught => 'Exceptions que j’ai enseignées';

  @override
  String get exceptionsITaughtWhat =>
      'des valeurs que vous avez explicitement exclues de la protection';

  @override
  String get noTaughtValuesYet => 'Aucune valeur enseignée pour l’instant.';

  @override
  String get noRulesTaughtYet => 'Aucune règle enseignée pour l’instant.';

  @override
  String get noSavedExceptionsYet =>
      'Aucune exception enregistrée pour l’instant.';

  @override
  String kindScopeTaughtOn(String kind, String scope, String date) {
    return '$kind · $scope · Enseignée le : $date';
  }

  @override
  String doNotProtectAsKindScopeTaughtOn(
    String kind,
    String scope,
    String date,
  ) {
    return 'Ne pas protéger comme $kind · $scope · Enseignée le : $date';
  }

  @override
  String get reveal => 'Révéler';

  @override
  String get hide => 'Masquer';

  @override
  String get theExceptionGoes =>
      'l’exception — cette valeur sera de nouveau proposée à la protection';

  @override
  String get theRuleGoes =>
      'la règle — Z Privacy cessera de protéger ce qui suit ce mot';

  @override
  String get openIdentity => 'Ouvrir';

  @override
  String profileNamed(String name) {
    return 'Profil : $name';
  }

  @override
  String get taughtOnUnknown => 'inconnue';

  @override
  String afterLabelProtectAs(String label, String kind) {
    return 'Après « $label : » → $kind';
  }

  @override
  String get teachARule => 'Enseigner une règle';

  @override
  String get kindClient => 'Client';

  @override
  String get kindPerson => 'Personne';

  @override
  String get kindCompany => 'Société';

  @override
  String get kindProject => 'Projet';

  @override
  String get kindSomethingElse => 'Autre chose';

  @override
  String vaultFileNotChanged(String said) {
    return '$said Z Privacy n’a pas modifié le fichier. Si vous avez une sauvegarde du coffre, remettez-la en place ; sinon, déplacez ce fichier ailleurs et un nouveau coffre pourra être créé ici.';
  }

  @override
  String get changeThePassphrase => 'Changer la phrase secrète';

  @override
  String get onlyThirtyTwoBytes =>
      'Seuls 32 octets sont rechiffrés — le coffre lui-même n’est ni déchiffré ni réécrit. Tout ce qu’il contient reste exactement à sa place.';

  @override
  String get currentPassphrase => 'Phrase secrète actuelle';

  @override
  String get passphrase => 'Phrase secrète';

  @override
  String get newPassphrase => 'Nouvelle phrase secrète';

  @override
  String get confirmPassphrase => 'Confirmer la phrase secrète';

  @override
  String get confirmNewPassphrase => 'Confirmer la nouvelle phrase secrète';

  @override
  String get passphrasesMatch => 'Les phrases secrètes correspondent';

  @override
  String get passphrasesDoNotMatch =>
      'Les phrases secrètes ne correspondent pas';

  @override
  String atLeastCharacters(int count) {
    return 'Au moins $count caractères — le coffre ne sera pas créé avec moins.';
  }

  @override
  String get thereIsNoWayBack =>
      'Aucun retour en arrière n’est possible. Personne n’en détient de copie, et aucune réinitialisation n’existe — la phrase secrète ne quitte jamais cet appareil et rien de notre côté ne pourrait récupérer le coffre sans elle.';

  @override
  String get working => 'En cours…';

  @override
  String get changeIt => 'La changer';

  @override
  String get createTheVault => 'Créer le coffre';

  @override
  String get unlockTheVault => 'Déverrouiller';

  @override
  String hideNamed(String label) {
    return 'Masquer $label';
  }

  @override
  String showNamed(String label) {
    return 'Afficher $label';
  }

  @override
  String get aNewIdentity => 'Une nouvelle identité';

  @override
  String get anIdentityIsHowAPersonThinks =>
      'Une identité, c’est la façon dont une personne pense — « Client Nordstern » — et les valeurs qu’elle contient sont ce que l’analyseur reconnaît.';

  @override
  String get nameField => 'Nom';

  @override
  String get sortField => 'Type';

  @override
  String get loadedIn => 'Chargée dans';

  @override
  String get exampleClientNordstern => 'Client Nordstern';

  @override
  String get exampleCompanyName => 'Nordstern Consulting GmbH';

  @override
  String get cancelForm => 'Annuler';

  @override
  String get createIt => 'Créer';

  @override
  String get aNewValue => 'Une nouvelle valeur';

  @override
  String get editThisValue => 'Modifier cette valeur';

  @override
  String get theValue => 'La valeur';

  @override
  String get readingItFromTheVault => 'lecture depuis le coffre…';

  @override
  String get whatItIs => 'Ce que c’est';

  @override
  String get howToTreatIt => 'Comment la traiter';

  @override
  String get alwaysProtect => 'Toujours protéger';

  @override
  String get alwaysProtectWhat =>
      'Repérée d’elle-même et remplacée, sans question.';

  @override
  String get suggestPolicy => 'Suggérer';

  @override
  String get suggestPolicyWhat =>
      'Repérée, et soumise à vous avant tout envoi.';

  @override
  String get keepDoNotHunt => 'Garder, ne pas rechercher';

  @override
  String get keepDoNotHuntWhat =>
      'Gardée pour que ses graphies et son jeton restent stables — mais pas recherchée.';

  @override
  String get saveIt => 'Enregistrer';

  @override
  String get aNewProfile => 'Un nouveau profil';

  @override
  String get renameProfile => 'Renommer le profil';

  @override
  String get oneDictionaryPerClient =>
      'Un dictionnaire par client. Seules les identités du profil que vous ouvrez sont chargées — ouvrir le coffre n’est pas un chèque en blanc.';

  @override
  String get theProfileIdStaysTheSame =>
      'L’identifiant du profil reste le même. Seul le nom que les gens lisent change.';

  @override
  String get languagesUsedInDocuments => 'Langues utilisées dans les documents';

  @override
  String get moreThanOneMayBeOn =>
      'Plusieurs peuvent être activées. Un document avec un libellé allemand et un libellé anglais est lu par les deux en une seule analyse.';

  @override
  String get renameIt2 => 'Renommer';

  @override
  String get teachARuleHead => 'Enseigner une règle';

  @override
  String get aRuleIsAWordAndWhatComesAfter =>
      'Une règle, c’est un mot et ce qui le suit. Z Privacy protège la valeur qui suit et s’arrête à la fin de ce champ.';

  @override
  String get whenZPrivacySees => 'Quand Z Privacy voit';

  @override
  String get exampleMandantenkennung => 'Mandantenkennung';

  @override
  String get protectTheValueAfterItAs => 'Protéger la valeur qui suit comme';

  @override
  String get whereField => 'Où';

  @override
  String profileNamedDash(String name) {
    return 'Profil — $name';
  }

  @override
  String get saveRule => 'Enregistrer la règle';

  @override
  String get removeProtectionHere => 'Retirer la protection ici';

  @override
  String removeItInThisSession(int places) {
    return 'La retirer dans cette session ($places endroits)';
  }

  @override
  String get forgetFromThisProfile => 'Oublier dans ce profil';

  @override
  String get forgetEverywhere => 'Oublier partout';

  @override
  String get protectThisColumnInTheLineHeld =>
      'Protéger cette colonne dans la ligne retenue';

  @override
  String protectThisColumnInLinesHeld(int lines) {
    return 'Protéger cette colonne dans les $lines lignes retenues';
  }

  @override
  String get whyIsThisProtected => 'Pourquoi ceci est-il protégé ?';

  @override
  String get theSameCellOfEveryHeldLine =>
      'La même cellule de chaque ligne retenue, chaque valeur avec son propre jeton. Celle-ci est déjà protégée et reste telle quelle.';

  @override
  String get whatItIsRow => 'Ce que c’est';

  @override
  String get whereItApplies => 'Où elle s’applique';

  @override
  String get decidedBy => 'Décidé par';

  @override
  String get decidedByYou => 'Vous';

  @override
  String get decidedByZPrivacy => 'Z Privacy, de lui-même';

  @override
  String get taughtOnRow => 'Enseignée le';

  @override
  String get tokenRow => 'Jeton';

  @override
  String otherSpellingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres graphies',
      one: '1 autre graphie',
    );
    return '$_temp0';
  }

  @override
  String get close => 'Fermer';

  @override
  String get uncoversThisOnePlace =>
      'Découvre cet endroit-ci uniquement. Tous les autres endroits gardent leur protection, et leur jeton.';

  @override
  String get theValueStaysInYourRules =>
      'La valeur reste dans vos règles de confidentialité et pourra de nouveau être protégée plus tard.';

  @override
  String get uncoversEveryPlaceInThisSession =>
      'Découvre chaque endroit où figure ce jeton, dans cette session.';

  @override
  String get thereIsNoEverywhere =>
      'Il n’y a pas de « partout » : le retrait de la protection ne va pas au-delà d’une session.';

  @override
  String get removesWhatZLearnedForThisProfile =>
      'Supprime ce que Z Privacy a appris pour ce profil.';

  @override
  String get protectionAlreadyAppliedStays =>
      'La protection déjà appliquée dans ce document reste en place.';

  @override
  String get removesWhatZLearnedEverywhere =>
      'Supprime ce que Z Privacy a appris, dans tous les profils.';

  @override
  String get forgetThisRule => 'Oublier cette règle';

  @override
  String get theRuleItselfIsKept =>
      'La règle elle-même reste dans votre coffre.';

  @override
  String get forgetItInZVaultRules =>
      'Oubliez-la dans Z Vault → Mes règles de confidentialité → Règles que j’ai enseignées.';

  @override
  String get nothingWasLearnedYouProtectedIt =>
      'Rien n’a été appris de ceci — vous l’avez protégé ici, et Annuler le reprend.';

  @override
  String get nothingWasLearnedARuleSawIt =>
      'Rien n’a été appris de ceci. Une règle a reconnu la forme, et aucune trace n’en a été conservée.';

  @override
  String forgottenButStillKnownBy(String who) {
    return 'Oublié, mais $who le reconnaît encore. Merci de nous le signaler — cela ne devrait pas être possible.';
  }

  @override
  String forgetNamed(String what) {
    return 'Oublier « $what » ?';
  }

  @override
  String get thisWillRemove => 'Ceci supprimera';

  @override
  String protectedValuesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valeurs protégées',
      one: '1 valeur protégée',
    );
    return '$_temp0';
  }

  @override
  String spellingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count graphies',
      one: '1 graphie',
    );
    return '$_temp0';
  }

  @override
  String identitiesLeftHoldingNothing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identités',
      one: '1 identité',
    );
    return '$_temp0 laissées vides';
  }

  @override
  String itsPlaceIn(String profile) {
    return 'sa place dans $profile';
  }

  @override
  String get itWillNotChange => 'Ceci ne changera PAS';

  @override
  String get forgetRemovesFromThisVault =>
      'Oublier supprime cette valeur du coffre actuel et de toute reconnaissance future par ce coffre. Cela ne supprime pas la protection déjà appliquée dans ce document, et une copie valide plus ancienne du coffre pourra restaurer la valeur plus tard.';

  @override
  String wouldStillRecogniseIt(String who) {
    return '$who la reconnaîtrait encore — oublier ici n’atteint pas les données d’un autre client.';
  }

  @override
  String get thisCannotBeUndone => 'Cette action est irréversible.';

  @override
  String get noValuesYet =>
      'Aucune valeur pour l’instant. Une valeur est ce que l’analyseur reconnaît — un nom, une société, un IBAN.';

  @override
  String valuesEachWithItsOwnPolicy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valeurs',
      one: '1 valeur',
    );
    return '$_temp0, chacune avec ses propres graphies et sa propre règle de traitement.';
  }

  @override
  String get moveIt => 'Déplacer';

  @override
  String get deleteIt => 'Supprimer';

  @override
  String get addAValue => 'Ajouter une valeur';

  @override
  String get policyKeptNotHunted => 'Gardée, non recherchée';

  @override
  String get addASpelling => 'Ajouter une graphie';

  @override
  String get editIt => 'Modifier';

  @override
  String get alsoWritten => 'Aussi écrit';

  @override
  String get anotherSpelling => 'Une autre graphie';

  @override
  String get anotherSpellingWhat =>
      'La même valeur écrite autrement — « Herr Müller », « T. Müller ». Chaque graphie garde le même jeton, pour que le modèle lise une seule personne et non trois.';

  @override
  String get exampleSpelling => 'Herr Müller';

  @override
  String get renameHead => 'Renommer';

  @override
  String get whatToCallThisIdentity => 'Le nom à donner à cette identité.';

  @override
  String get moveThisIdentity => 'Déplacer cette identité';

  @override
  String get anIdentityInAProfile =>
      'Une identité placée dans un profil n’est chargée que lorsque ce profil est ouvert. Une identité qui appartient à « Partout » est toujours chargée.';

  @override
  String get deleteThisIdentity => 'Supprimer cette identité ?';

  @override
  String identityAndItsValuesAreRemoved(String name, String values) {
    return '« $name » et ses $values sont supprimées du coffre. Les documents déjà protégés gardent leurs jetons ; le prochain document ne reconnaîtra plus ces valeurs.';
  }

  @override
  String get keepItIdentity => 'La garder';

  @override
  String get noNamesToLookAt => 'Aucun nom à examiner';

  @override
  String namesToLookAtCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noms à examiner',
      one: '1 nom à examiner',
    );
    return '$_temp0';
  }

  @override
  String get zKnowsEveryName =>
      'Z connaît chaque nom utilisé dans ce document.';

  @override
  String get wordsThisDocumentUsesAsNames =>
      'Les mots que ce document utilise comme noms et que Z ne connaît pas encore.';

  @override
  String placesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits',
      one: '1 endroit',
    );
    return '$_temp0';
  }

  @override
  String pagesCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get addAsFamilyName => 'Ajouter comme nom de famille';

  @override
  String get addAsGivenName => 'Ajouter comme prénom';

  @override
  String get ignoreIt => 'Ignorer';

  @override
  String get unlockTheVaultAct => 'Déverrouiller le coffre';

  @override
  String get needsAVault => 'Nécessite un coffre';

  @override
  String get nameListsFileType => 'Listes de noms';

  @override
  String get whichLanguageAreTheseNames => 'De quelle langue sont ces noms ?';

  @override
  String get yourNames => 'Vos noms';

  @override
  String get namesThisDeviceKnows =>
      'Les noms que cet appareil connaît parce que vous les lui avez indiqués. Ils sont conservés dans votre coffre, sur cet ordinateur.';

  @override
  String get addAName => 'Ajouter un nom';

  @override
  String get importAList => 'Importer une liste';

  @override
  String actNeedsTheVault(String act, String needs) {
    return '$act · $needs';
  }

  @override
  String get aListIsACsv =>
      'Une liste est un fichier CSV avec une colonne « name » et une colonne « type » : given, family, person ou company.';

  @override
  String get yourNamesLiveInTheVault =>
      'Vos noms sont conservés dans le coffre ; en ajouter un nécessite donc qu’il soit ouvert.';

  @override
  String get exampleSurname => 'Lindqvist';

  @override
  String get pickSuggest => 'Suggérer';

  @override
  String get pickAlways => 'Toujours';

  @override
  String get alwaysProtectedTheMoment =>
      'Toujours : protégé dès qu’il apparaît, dans chaque document.';

  @override
  String get suggestMarksAndWaits =>
      'Suggérer : Z le marque et attend votre avis.';

  @override
  String get addAct => 'Ajouter';

  @override
  String get nothingYet => 'Rien pour l’instant.';

  @override
  String get wholeNamesKeptInTheVault =>
      'Noms complets, conservés dans le coffre';

  @override
  String get aWholePersonIsAValue =>
      'Une personne ou une société entière est une valeur, pas un mot de dictionnaire ; elle ne figure donc dans aucune liste de langue. Chacune se gère dans Z Vault.';

  @override
  String get reachEverywhere => 'partout';

  @override
  String get reachThisClient => 'ce client';

  @override
  String forgetNamedShort(String what) {
    return 'Oublier « $what »';
  }

  @override
  String get kindGivenName => 'prénom';

  @override
  String get kindFamilyName => 'nom de famille';

  @override
  String get kindPersonName => 'personne';

  @override
  String get kindCompanyName => 'société';

  @override
  String namesAndValuesInAList(String names, int values) {
    return '$names · $values valeurs';
  }

  @override
  String get listIsOff => 'désactivée';

  @override
  String get stopUsingTheseNames => 'Ne plus utiliser ces noms';

  @override
  String get useTheseNamesAgain => 'Utiliser de nouveau ces noms';

  @override
  String whatToDoWithList(String name) {
    return 'Que faire de « $name »';
  }

  @override
  String get moveToDots => 'Déplacer vers…';

  @override
  String get exportCsv => 'Exporter en CSV';

  @override
  String get removeList => 'Retirer la liste';

  @override
  String removeNamedList(String name) {
    return 'Retirer « $name » ?';
  }

  @override
  String namesGoWithItCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noms partent avec elle. Rien d’autre n’est touché.',
      one: 'Un nom part avec elle. Rien d’autre n’est touché.',
    );
    return '$_temp0';
  }

  @override
  String get removeAct => 'Retirer';

  @override
  String moveNamesFromTo(int count, String from) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Déplacer $count noms de $from vers…',
      one: 'Déplacer un nom de $from vers…',
    );
    return '$_temp0';
  }

  @override
  String get howFarDoTheseNamesReach => 'Jusqu’où ces noms s’appliquent-ils ?';

  @override
  String get protectingThemMeans =>
      'Les protéger signifie que Z les noircit dès qu’ils apparaissent, sans question. Les proposer signifie que Z les marque et attend votre décision.';

  @override
  String get youCanChangeAnyOneAfterwards =>
      'Vous pourrez modifier chacun d’eux ensuite, nom par nom.';

  @override
  String get offerThemAndIDecide => 'Les proposer, et je décide';

  @override
  String get protectThemEverywhere => 'Les protéger partout';

  @override
  String protectThemForClient(String client) {
    return 'Les protéger pour $client';
  }

  @override
  String get couldNotBuildThePdf =>
      'Z Privacy n’a pas pu créer le PDF — sa page de réponse n’avait pas de jeton. Rien n’a été écrit.';

  @override
  String get whoAnswers => 'Qui répond';

  @override
  String get thereIsNothingToSend => 'Il n’y a rien à envoyer.';

  @override
  String valuesReplacedCharacters(int values, int characters) {
    return '$values valeurs remplacées · $characters caractères quitteraient cet appareil.';
  }

  @override
  String sessionNumber(int number) {
    return 'Session $number';
  }

  @override
  String sessionNumberNamed(int number, String name) {
    return 'Session $number « $name »';
  }

  @override
  String theseNamesAreThisSessions(String named) {
    return '$named · ces noms appartiennent à cette session';
  }

  @override
  String get noSessionNamesForThisDocument =>
      'Aucune session — ces noms ont été créés pour ce seul document.';

  @override
  String get noSessionYetAnyDoorBeginsOne =>
      'Pas encore de session — toute action ici en démarre une.';

  @override
  String get nothingLeftTheMachine => 'Rien n’a quitté la machine.';

  @override
  String get oneSuggestionStillOpenSend =>
      'Une suggestion est encore en attente. Elle figure dans le texte telle qu’elle est écrite, et rien ne peut être envoyé tant que vous n’y avez pas répondu. Il n’existe pas d’« envoyer quand même ».';

  @override
  String suggestionsStillOpenSend(int open) {
    return '$open suggestions sont encore en attente. Elles figurent dans le texte telles qu’elles sont écrites, et rien ne peut être envoyé tant que vous n’y avez pas répondu. Il n’existe pas d’« envoyer quand même ».';
  }

  @override
  String get manualAiSheetWhat =>
      'Utilisez une discussion d’IA que vous avez déjà. Prenez le texte ci-dessus — dans le presse-papiers, ou en PDF enregistré sur cette machine — collez-le dans le modèle de votre choix, et rapportez la réponse avec « Ajouter une réponse » sous la discussion. La restauration fonctionne de la même façon dans les deux cas — aucun compte, aucune clé. Aucune des deux façons n’envoie quoi que ce soit d’ici.';

  @override
  String get copied => 'Copié';

  @override
  String get copyProtected => 'Copier le texte protégé';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get saveAsPdf => 'Enregistrer en PDF';

  @override
  String savedToWhere(String where) {
    return 'Enregistré dans $where';
  }

  @override
  String get whatThePdfHolds =>
      'Le texte protégé, avec le tampon de version, les comptes et un sha256 de ce texte en pied de page, et une dernière page pour la réponse. Rien n’a été envoyé.';

  @override
  String get directApiSheetWhatRemote =>
      'Connectez-vous à un fournisseur d’IA distant avec votre identifiant d’API. Seul le texte ci-dessus serait transmis ; le fournisseur voit tout de même les éléments ordinaires d’une connexion — votre adresse, l’heure, le modèle.';

  @override
  String get directApiSheetWhatConnected =>
      'La demande part de cette application. Seul le texte ci-dessus est transmis ; le fournisseur voit tout de même les éléments ordinaires d’une connexion — votre adresse, l’heure, le modèle.';

  @override
  String get noProviderIsConnected =>
      'Aucun fournisseur n’est connecté. L’adresse et la clé s’indiquent une seule fois, dans les Paramètres — cet écran ne les demande jamais.';

  @override
  String get sending => 'Envoi…';

  @override
  String sendToNamed(String where) {
    return 'Envoyer à $where';
  }

  @override
  String get providerKeyThisRunOnly =>
      '  (clé conservée pour cette exécution uniquement)';

  @override
  String get theAddressTheModelTheKey =>
      'L’adresse, le modèle et la clé se modifient dans les Paramètres.';

  @override
  String get localAiSheetWhat =>
      'Utilisez un service d’IA qui fonctionne sur cet ordinateur — llama.cpp, Ollama, LM Studio, tout ce qui répond au même format. Aucune clé, aucun compte, et la demande ne quitte jamais cet ordinateur. C’est la seule voie qui ne voit aucun des éléments ordinaires ci-dessus.';

  @override
  String get aModelOnThisComputer =>
      'Un modèle sur cet ordinateur se configure dans les Paramètres — il n’y a aucune clé à fournir.';

  @override
  String get openSettings => 'Ouvrir les Paramètres';

  @override
  String get modelLabel => 'Modèle';

  @override
  String get fileKindDocuments => 'Documents';

  @override
  String onlyTheseKindsAreRead(String name) {
    return 'Cette version lit les fichiers PDF, Word et texte. « $name » n’est rien de cela.';
  }

  @override
  String get generalRulesOnlyNoDictionary =>
      'Règles générales uniquement — pas encore de dictionnaire';

  @override
  String get whichLanguageIsThisText => 'Dans quelle langue est ce texte ?';

  @override
  String get theSessionLanguageExplained =>
      'Z le lit avec les habitudes de cette langue : la façon de saluer, d’écrire le nom d’une société, la forme d’un numéro client. C’est désormais la langue de la session, et elle ne vous sera plus demandée dans cette session.';

  @override
  String allLinesHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count lignes',
      one: 'La ligne unique',
    );
    return '$_temp0';
  }

  @override
  String get revealHidden => 'Masquée';

  @override
  String revealedForSeconds(int seconds) {
    return 'Révélée · $seconds s';
  }

  @override
  String get alsoTheWordBefore => 'Aussi le mot précédent';

  @override
  String get alsoTheWordBeforeHint =>
      'Prend aussi le mot commençant par une majuscule devant la sélection';

  @override
  String get undoProtection => 'Annuler la protection';

  @override
  String get nothingToUndoHint => 'Rien à annuler';

  @override
  String get rescanAct => 'Réanalyser';

  @override
  String nextOfWaitingCount(int at, int total) {
    return 'Suivant $at/$total';
  }

  @override
  String get reviewAct => 'Vérifier';

  @override
  String get namesAct => 'Noms';

  @override
  String get zKnowsEveryNameHere =>
      'Z connaît chaque nom utilisé dans ce document';

  @override
  String get tokensAct => 'Jetons';

  @override
  String get nothingIsProtectedYetHint => 'Rien n’est encore protégé';

  @override
  String get selectionCutsIntoProtected =>
      'Cette sélection coupe un élément déjà protégé. Protéger prendrait l’élément entier à la place.';

  @override
  String selectionSpansProtectedItems(int count) {
    return 'Cette sélection couvre $count éléments protégés. Protéger prendrait chacun d’eux en entier, sous son propre jeton.';
  }

  @override
  String get protectAct => 'Protéger';

  @override
  String get selectTextThenProtect => 'Sélectionnez du texte, puis Protéger';

  @override
  String get alreadyProtectedSeeBelow => 'Déjà protégé — voir ci-dessous';

  @override
  String get protectWholeItems => 'Protéger les éléments entiers';

  @override
  String get thereWasNothingToUndo => 'Il n’y avait rien à annuler.';

  @override
  String tookBackTokens(String tokens) {
    return 'Retiré : $tokens.';
  }

  @override
  String tookBackTokensInPlaces(String tokens, int places) {
    return 'Retiré : $tokens, aux $places endroits — c’est entré en une seule action, c’est donc ressorti en une seule.';
  }

  @override
  String tookBackTokensIdentityStays(String tokens, String identity) {
    return 'Retiré : $tokens. L’identité $identity est toujours dans le coffre.';
  }

  @override
  String scannedAgainReport(int auto, int byYou, int waiting, int normal) {
    return 'Nouvelle analyse : $auto protégés automatiquement · $byYou par vous · $waiting attendent votre avis · $normal normaux.';
  }

  @override
  String alreadyProtectedAsTokens(String tokens) {
    return 'Déjà protégé sous $tokens.';
  }

  @override
  String alreadyProtectedAsFrom(String tokens, String source, String detail) {
    return 'Déjà protégé sous $tokens, source : $source$detail.';
  }

  @override
  String get readBackPanel => 'Relecture';

  @override
  String get whatStayedAToken => 'Ce qui est resté un jeton';

  @override
  String theSearchWasRefused(String why) {
    return 'La recherche a été refusée : $why';
  }

  @override
  String get findAWordInThisDocument => 'Rechercher un mot dans ce document';

  @override
  String get tabTakesIt => 'Tab pour accepter';

  @override
  String get findAct => 'Rechercher';

  @override
  String notInThisDocument(String word) {
    return '« $word » n’est pas dans ce document';
  }

  @override
  String countProtected(int count) {
    return '$count protégés';
  }

  @override
  String countWaiting(int count) {
    return '$count en attente';
  }

  @override
  String countInTheClear(int count) {
    return '$count en clair';
  }

  @override
  String placesInsideWaitingWords(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits se trouvent',
      one: 'Un endroit se trouve',
    );
    return '$_temp0 dans des mots qui attendent encore votre avis : $list. Protéger les laisse à la vérification.';
  }

  @override
  String get goToIt => 'Y aller';

  @override
  String get unProtectHere => 'Déprotéger ici';

  @override
  String unProtectInThisSession(int places) {
    return 'Déprotéger dans cette session ($places endroits)';
  }

  @override
  String get nothingIsWaitingForYou => 'Rien ne vous attend.';

  @override
  String thingsWaitingForYourWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments attendent votre avis.',
      one: 'Un élément attend votre avis.',
    );
    return '$_temp0';
  }

  @override
  String get theScanFoundNothingHere =>
      'L’analyse n’a rien trouvé dans ce document.';

  @override
  String get nothingIsWaitingWhatIsProtected =>
      'Rien n’est en attente. Ce qui est protégé figure dans le texte, marqué là où il se trouve.';

  @override
  String foundBySource(String source) {
    return 'trouvé par : $source';
  }

  @override
  String get youDecided => 'décidé par vous';

  @override
  String pageAndParagraph(int page, int paragraph) {
    return 'Page $page · ¶$paragraph';
  }

  @override
  String inPlacesCount(int count) {
    return 'à $count endroits';
  }

  @override
  String identitiesClaimIt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identités la revendiquent',
      one: 'Une identité la revendique',
    );
    return '$_temp0';
  }

  @override
  String leaveWordsInTheClearQuestion(int count) {
    return 'Laisser $count mots en clair ?';
  }

  @override
  String leaveAllInTheClearExplained(int count) {
    return 'Les $count seront tous envoyés exactement tels qu’ils sont écrits. Z n’en remplacera aucun, ni dans ce document ni dans la demande qui quitte cet ordinateur.';
  }

  @override
  String yesLeaveAllInTheClear(int count) {
    return 'Oui — laisser les $count en clair';
  }

  @override
  String get protectAll => 'Tout protéger';

  @override
  String get skipAll => 'Tout ignorer';

  @override
  String get leaveIt => 'Laisser';

  @override
  String get activeZTokens => 'Jetons Z actifs';

  @override
  String get nothingIsProtectedYetSentence => 'Rien n’est encore protégé.';

  @override
  String valuesStandBehindTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valeurs se trouvent',
      one: '1 valeur se trouve',
    );
    return '$_temp0 derrière un jeton dans cette session.';
  }

  @override
  String get aTokenAppearsWhenProtected =>
      'Un jeton apparaît ici dès que quelque chose est protégé.';

  @override
  String get revealingChangesNothing =>
      'Révéler affiche une valeur sur cet écran pendant un instant. Cela ne change rien dans la colonne Protégé — ce qui quitte l’appareil est la même chaîne avant et après.';

  @override
  String get copyTheToken => 'Copier le jeton';

  @override
  String get scopeJustHere => 'Ici seulement';

  @override
  String get scopeThisSession => 'Cette session';

  @override
  String get scopeRememberedForClient => 'Mémorisé pour ce client';

  @override
  String get scopeRememberedEverywhere => 'Mémorisé partout';

  @override
  String get copyReport => 'Copier le rapport';

  @override
  String sessionNamesAreThisSessions(int number) {
    return 'Session $number · les noms de ce travail appartiennent à cette session';
  }

  @override
  String get asEachProviderIsConfigured =>
      'Selon la configuration de chaque fournisseur';

  @override
  String get noAiConnected => 'Aucune IA connectée';

  @override
  String get connectAnAiInSettings => 'Connectez une IA dans les Paramètres';

  @override
  String get chooseWhichModelAnswers => 'Choisir le modèle qui répond';

  @override
  String get nothingSentFromThisSessionYet =>
      'Rien n’a encore été envoyé depuis cette session. Ce qui part vers un modèle et ce qui en revient est écrit ici, dans le fichier scellé propre à cette session.';

  @override
  String get youAsked => 'Vous avez demandé';

  @override
  String get nothingWasAskedDocumentWentAlone =>
      'Rien n’a été demandé — le document est parti seul.';

  @override
  String get itAnswered => 'Réponse reçue';

  @override
  String namesBelongToAnotherSession(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count noms de cet échange appartiennent à une autre session et n’ont pas pu être restaurés : $list.',
      one:
          'Un nom de cet échange appartient à une autre session et n’a pas pu être restauré : $list.',
    );
    return '$_temp0';
  }

  @override
  String get andTheClipboardIsEmptySentence =>
      'Rien n’a été copié — le presse-papiers est vide.';

  @override
  String get nothingWasPasted => 'Rien n’a été collé.';

  @override
  String get copyTheSafeTextFirst =>
      'Copiez d’abord le texte protégé, pour que la réponse puisse être rattachée à cette charge protégée.';

  @override
  String profileIsInUseAgain(String name) {
    return '« $name » est de nouveau utilisé.';
  }

  @override
  String profileIsOffNamesRemain(String name) {
    return '« $name » est désactivé — ses noms sont toujours là.';
  }

  @override
  String movedNamesToLanguage(int count, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noms déplacés vers $to.',
      one: 'Un nom déplacé vers $to.',
    );
    return '$_temp0';
  }

  @override
  String forgotProfileAndItsNames(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noms',
      one: '1 nom',
    );
    return '« $name » oublié, avec $_temp0.';
  }

  @override
  String addedValueNamed(String value) {
    return '« $value » ajouté.';
  }

  @override
  String forgotValueNamed(String value) {
    return '« $value » oublié.';
  }

  @override
  String get afterTheVaultOpened => 'après l’ouverture du coffre';

  @override
  String importAddedCount(int count) {
    return '$count ajoutés';
  }

  @override
  String importAlreadyKnownCount(int count) {
    return '$count déjà connus';
  }

  @override
  String importRefusedCount(int count) {
    return '$count refusés';
  }

  @override
  String importValuesCount(int count) {
    return '$count valeurs';
  }

  @override
  String get begunNoNameNeededRenaming =>
      'Démarrée. Aucun nom de ce document n’avait besoin d’être renommé.';

  @override
  String get begunNoDocumentOpen =>
      'Démarrée. Aucun document n’est ouvert ; il n’y avait donc rien à renommer.';

  @override
  String begunAndNamesMovedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Démarrée, et $count noms de ce document y ont été déplacés.',
      one: 'Démarrée, et un nom de ce document y a été déplacé.',
    );
    return '$_temp0';
  }

  @override
  String get theSessionWasNotBegun =>
      'La session n’a pas été démarrée ; rien n’a donc été retiré.';

  @override
  String get closeAndOpenAgain =>
      'Fermez ceci et rouvrez-le — quelque chose a changé pendant qu’il était ouvert.';

  @override
  String get sentToAiAnswered => 'envoyé à l’IA · répondu';

  @override
  String get sentToAiNoAnswerYet => 'envoyé à l’IA · pas encore de réponse';

  @override
  String columnsNotUsedSaid(int count, String which) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count colonnes n’ont pas été utilisées : $which — indiquez le type de chacune, sinon elles restent à l’écart.',
      one:
          'Une colonne n’a pas été utilisée : $which — indiquez-en le type, sinon elle reste à l’écart.',
    );
    return '$_temp0';
  }

  @override
  String get addressLabel => 'Adresse';

  @override
  String get plainHttpOnlyLoopback =>
      'Le http simple n’est accepté que pour une adresse de bouclage littérale — 127.0.0.1 ou ::1. Un nom comme « localhost » est refusé, car ce serait alors un fichier hosts qui déciderait si le texte en clair est sûr.';

  @override
  String get theModelToAsk => 'le modèle à interroger';

  @override
  String get apiKeyLabel => 'Clé d’API';

  @override
  String get pastedOnceNeverShownAgain => 'collée une fois, jamais réaffichée';

  @override
  String get thisKeyIsSealedInTheVault =>
      'Cette clé est scellée dans le coffre.';

  @override
  String get thisKeyIsInMemoryOnly =>
      'Cette clé est conservée en mémoire pour cette exécution uniquement — elle disparaît à la fermeture de l’application.';

  @override
  String get noKeyIsNeededHere =>
      'Aucune clé n’est nécessaire à cette adresse.';

  @override
  String get noKeyYetWillSeal =>
      'Aucune clé n’est encore enregistrée. La connexion la scellera dans le coffre.';

  @override
  String get noKeyYetMemoryOnly =>
      'Aucune clé n’est encore enregistrée. La connexion la conservera en mémoire pour cette exécution uniquement.';

  @override
  String get connectingNow => 'Connexion…';

  @override
  String get connectAct => 'Connecter';

  @override
  String get forgetTheKey => 'Oublier la clé';

  @override
  String get disconnectAct => 'Déconnecter';

  @override
  String get couldNotTellWhereDocumentsFolderIs =>
      'Z Privacy n’a pas pu déterminer où se trouve votre dossier Documents, et n’a donc rien deviné. Rien n’a été écrit.';

  @override
  String thereAreAlready200Files(String stem, String into) {
    return 'Il y a déjà 200 fichiers nommés $stem dans $into.';
  }

  @override
  String couldNotWriteInto(String into, String why) {
    return 'Z Privacy n’a pas pu écrire dans $into — $why.';
  }

  @override
  String couldNotBuildThePdfBecause(String why) {
    return 'Z Privacy n’a pas pu créer le PDF — $why. Rien n’a été écrit.';
  }

  @override
  String get zPdfProtectedCopy => 'z-pdf · copie protégée';

  @override
  String placesReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits remplacés',
      one: '1 endroit remplacé',
    );
    return '$_temp0';
  }

  @override
  String valuesOfTheseKinds(int count, String kinds) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valeurs ($kinds)',
      one: '1 valeur ($kinds)',
    );
    return '$_temp0';
  }

  @override
  String get noKindsAtAll => 'aucune';

  @override
  String sha256OfTheProtectedText(String digest) {
    return 'sha256 du texte protégé $digest';
  }

  @override
  String zPdfAnswerLine(String token) {
    return 'Z-pdf : $token';
  }

  @override
  String couldNotAskWhereToSaveIt(String why) {
    return 'Z Privacy n’a pas pu ouvrir la boîte de dialogue d’enregistrement de votre système — $why. Rien n’a été écrit.';
  }

  @override
  String get nameThisDocument => 'Nommer ce document';

  @override
  String get whatIsThisDocumentCalled => 'Comment s’appelle ce document ?';

  @override
  String get theFileNameIsNotProtected =>
      'Le nom du fichier reste exactement tel que vous le saisissez. Il part avec le fichier ; n’y mettez donc pas de vrais noms.';

  @override
  String get aNameIsNeededForThisDocument =>
      'Un nom est nécessaire — le fichier porte ce nom.';

  @override
  String get saveAsAPlainPdf => 'Enregistrer en PDF ordinaire';

  @override
  String get aPlainPdfOfTheRestoredText =>
      'Ceci enregistre le document ci-dessus avec ses noms remis, en PDF ordinaire — sans page de réponse, sans pied de page, sans rien qui prétende à une protection. Les valeurs y figurent en clair.';

  @override
  String get copyTheAddressAndWriteToUs =>
      'Copiez cette adresse et écrivez-nous depuis votre propre messagerie. Z Privacy n’ouvre rien et n’envoie rien : il n’y a ici aucun formulaire et aucune connexion vers nous.';

  @override
  String get writeToUs => 'Nous écrire';

  @override
  String get describeTheProblemNotYourDocuments =>
      'Décrivez le problème, et n’envoyez pas vos documents : ce qui arrive dans notre boîte de réception n’est pas quelque chose que nous pouvons protéger. « Copier le rapport », dans la barre au-dessus de votre travail, écrit des nombres sur un document et aucun de ses mots.';

  @override
  String get howToUseZPrivacy => 'Comment utiliser Z Privacy';

  @override
  String get theGuideOpensInYourBrowser =>
      'La page s’ouvre dans votre navigateur, dans la langue de cette interface. Rien de votre document ni de votre coffre ne part avec ce clic : votre navigateur demande une page au site, comme pour toute autre visite.';

  @override
  String get couldNotOpenYourBrowser =>
      'Z Privacy n’a pas pu ouvrir votre navigateur. L’adresse affichée sur le bouton s’ouvre à la main dans n’importe quel navigateur.';

  @override
  String thisTranslationWasMadeWithAi(String subject) {
    return 'Cette traduction a été réalisée avec l’IA. Pour signaler une erreur, écrivez à zprivacy@mono-peak.com avec l’objet « $subject ».';
  }

  @override
  String theCorrectionSubject(String code) {
    return 'Translation ($code)';
  }
}

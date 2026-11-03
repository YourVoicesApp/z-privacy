// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get theKeyIsBehindTheLockedVault =>
      'Z Privacy no puede acceder a una clave mientras la bóveda está bloqueada. Desbloquéela o indique una clave solo para esta vez.';

  @override
  String get theChatKeepsNothing =>
      'Esta respuesta está en su pantalla y en ningún otro sitio: no hay ninguna sesión abierta que la conserve, así que al cerrar la app desaparece junto con el chat.';

  @override
  String get theTokenIsAlreadyOurs => 'Esto ya está protegido — Z lo puso ahí.';

  @override
  String get unnamedTrouble =>
      'Algo salió mal. Z Privacy no completó la acción.';

  @override
  String exactlyWhatWouldLeave(int replaced) {
    return 'Esto es lo que sale de su documento — y, dentro de la app, el intercambio anterior viaja con él. Se sustituyeron $replaced valores.';
  }

  @override
  String get noLanguageAndASessionIsOpen =>
      'No se leyó nada. Un texto se lee con los hábitos de un idioma, y a esta sesión nunca se le ha asignado uno — por eso Z Privacy no eligió por usted. Léalo de nuevo y responda, o asigne a la sesión su idioma en Ajustes.';

  @override
  String get noLanguageAndNoSession =>
      'No se leyó nada. Un texto se lee con los hábitos de un idioma, y no se eligió ninguno — por eso no se leyó nada ni se creó ninguna sesión. Inténtelo de nuevo y elija uno.';

  @override
  String get troubleNotImplemented =>
      'Esta parte de Z Privacy aún no está construida.';

  @override
  String get troubleInvalidSession =>
      'Esa sesión ya no está abierta. Inicie una nueva.';

  @override
  String get troubleInvalidHandle =>
      'Esta solicitud ya no está vigente. Revise el texto de nuevo antes de enviarlo.';

  @override
  String get troubleStalePayload =>
      'El documento cambió después de preparar esta solicitud. Revíselo de nuevo, para que lo que envíe sea lo último que vio.';

  @override
  String get troubleVaultLocked =>
      'Su bóveda está bloqueada. Desbloquéela para usar lo que sabe.';

  @override
  String get troubleVaultRequired =>
      'Desbloquee o cree su bóveda antes de guardar esto para usarlo en el futuro.';

  @override
  String get troubleVaultAuthenticationFailed =>
      'No se pudo desbloquear la bóveda. Puede que la frase de contraseña sea incorrecta, o que la bóveda esté dañada o modificada.';

  @override
  String get troubleUnsupportedKdfParameters =>
      'Esta bóveda usa ajustes de seguridad no compatibles.';

  @override
  String get troubleTrailingVaultData =>
      'Este archivo de bóveda tiene datos adicionales después de su final y no se abrió.';

  @override
  String get troubleProviderUnavailable =>
      'Ese proveedor de IA no está disponible en esta versión.';

  @override
  String get oneWordWaits =>
      'Una palabra espera su respuesta — nada salió de Z.';

  @override
  String wordsWait(int count) {
    return '$count palabras esperan su respuesta — nada salió de Z.';
  }

  @override
  String get troubleVaultAbsent =>
      'Todavía no hay ninguna bóveda en este dispositivo. Cree una para conservar algo para mañana.';

  @override
  String get troubleVaultAlreadyExists =>
      'Ya existe una bóveda en este dispositivo, y Z Privacy no la sobrescribirá.';

  @override
  String troubleStorageRefused(String reason) {
    return 'Z Privacy no usará esa ubicación — $reason';
  }

  @override
  String get everyCellWasAlreadyProtected =>
      'Todas las celdas de esa columna ya estaban protegidas.';

  @override
  String protectedOneCell(String token) {
    return 'Se protegió una celda, como $token.';
  }

  @override
  String protectedCellsDownTheColumn(int places, String token) {
    return 'Se protegieron $places celdas a lo largo de esa columna, la primera como $token.';
  }

  @override
  String protectedAs(String token) {
    return 'Protegido como $token.';
  }

  @override
  String protectedAsInPlaces(String token, int places) {
    return 'Protegido como $token, en $places lugares.';
  }

  @override
  String alreadyProtectedBy(String token, String who) {
    return 'Ya protegido como $token, por $who.';
  }

  @override
  String belongsToEntity(String entity, String token) {
    return 'Eso pertenece a $entity y conserva su marcador $token.';
  }

  @override
  String pressCutsIntoProtectedTextOne(String what) {
    return '$what corta un texto protegido, así que no cambió nada. Se ajustaría a 1 elemento completo.';
  }

  @override
  String pressCutsIntoProtectedTextMany(String what, int items) {
    return '$what corta un texto protegido, así que no cambió nada. Se ajustaría a $items elementos completos.';
  }

  @override
  String get theSelection => 'La selección';

  @override
  String get thatCell => 'Esa celda';

  @override
  String get thatPlace => 'Ese lugar';

  @override
  String get sourceRule => 'Regla';

  @override
  String get sourcePack => 'Paquete de idioma';

  @override
  String get sourceVault => 'Bóveda';

  @override
  String get sourceYou => 'Usted';

  @override
  String get answeredByHand => 'traída de vuelta a mano';

  @override
  String get answeredNotRecorded => 'no registrado';

  @override
  String get oneNameCameBack => 'Volvió un nombre.';

  @override
  String namesCameBack(int count) {
    return 'Volvieron $count nombres.';
  }

  @override
  String oneNameCameBackFrom(String sessions) {
    return 'Volvió un nombre de $sessions.';
  }

  @override
  String namesCameBackFrom(int count, String sessions) {
    return 'Volvieron $count nombres de $sessions.';
  }

  @override
  String thisDocumentCameBackFrom(String sessions) {
    return 'Este documento volvió de $sessions.';
  }

  @override
  String get oneNameIsStillATokenVaultShut =>
      'Un nombre sigue siendo un marcador: desbloquee o cree su bóveda y Z podrá buscarlo.';

  @override
  String namesAreStillTokensVaultShut(int count) {
    return '$count nombres siguen siendo marcadores: desbloquee o cree su bóveda y Z podrá buscarlos.';
  }

  @override
  String get oneNameStaysATokenTwoCauses =>
      'Un nombre se queda como marcador, y dos cosas distintas producen eso: la palabra se protegió antes de que Z Privacy empezara a conservar cada palabra protegida, o este marcador se modificó después de que el archivo saliera. Abra ese documento en su sesión y proteja el nombre de nuevo — si a partir de entonces vuelve, era lo primero; si no vuelve, este archivo no es el que escribió Z Privacy.';

  @override
  String namesStayTokensTwoCauses(int count) {
    return '$count nombres se quedan como marcadores, y dos cosas distintas producen eso: se protegieron antes de que Z Privacy empezara a conservar cada palabra protegida, o los marcadores se modificaron después de que el archivo saliera. Abra esos documentos en su sesión y proteja los nombres de nuevo — si a partir de entonces vuelven, era lo primero; si no vuelven, este archivo no es el que escribió Z Privacy.';
  }

  @override
  String get refusalMalformedDocument =>
      'Este documento está dañado o incompleto.';

  @override
  String get refusalEncryptedPdf =>
      'Este PDF está protegido con contraseña. Quite la contraseña e inténtelo de nuevo.';

  @override
  String get refusalScannedOnePage =>
      'Este PDF es una imagen de una página sin texto, así que no se pudo leer nada — y Z Privacy no importará un documento que no puede ver.';

  @override
  String refusalScannedPages(int pages) {
    return 'Este PDF son $pages páginas de imágenes sin texto, así que no se pudo leer nada.';
  }

  @override
  String refusalUnsupportedEncoding(int readablePercent, int page) {
    return 'Solo el $readablePercent% de la página $page se pudo convertir en caracteres, así que este documento se rechaza en lugar de leerse a medias. Ábralo y guárdelo como texto, o pegue el texto.';
  }

  @override
  String refusalUnreadableStructure(int page) {
    return 'La página $page está construida de una forma que esta versión no puede leer.';
  }

  @override
  String refusalTextInDisplayForms(int percent) {
    return 'El $percent% del árabe de este texto está escrito en las formas de presentación que dibuja un programa de maquetación, así que lo que Z leyó está en el orden en que se dibujó y no en el orden en que se escribió — las palabras y los números salen al revés. Z no protegerá un texto que ha leído al revés: un nombre leído al revés es un nombre que no puede proteger. Un archivo de Word o un archivo de texto sin formato se leen en el orden en que se escribieron.';
  }

  @override
  String refusalDocumentTooLarge(int mib, int limitMib) {
    return 'Este archivo tiene unos $mib MiB, y Z Privacy abre documentos de hasta $limitMib MiB.';
  }

  @override
  String refusalTooManyPages(int pages, int limit) {
    return 'Este documento tiene $pages páginas, y Z Privacy abre hasta $limit en un solo documento.';
  }

  @override
  String refusalTextTooLarge(int limitMib) {
    return 'Una vez descomprimida, una parte de este archivo supera los $limitMib MiB — más de lo que Z Privacy lee en un solo documento, así que no se importó nada de él.';
  }

  @override
  String refusalCompressionBomb(int ratio) {
    return 'Una parte de este archivo se descomprime a más de $ratio veces el espacio que ocupa. Ningún documento real hace eso, así que Z Privacy dejó de descomprimirlo en lugar de llenar el equipo.';
  }

  @override
  String refusalTooManyParts(int parts, int limit) {
    return 'Este archivo enumera $parts partes en su interior, y un documento tiene decenas, no miles — Z Privacy abre hasta $limit.';
  }

  @override
  String refusalTookTooLong(int seconds) {
    return 'La lectura de este archivo seguía en curso después de $seconds segundos, así que Z Privacy se detuvo. No se importó nada de él.';
  }

  @override
  String get refusalEmptyDocument =>
      'En este archivo no hay ningún texto que Z Privacy pueda proteger.';

  @override
  String get networkNotConnected =>
      'No hay ningún proveedor de IA conectado. Añada primero una dirección y una clave.';

  @override
  String get networkInsecureUrl => 'No es seguro enviar a esa dirección.';

  @override
  String get networkRedirected =>
      'Esa dirección nos envió a otro sitio. Z Privacy no sigue redirecciones con su texto, así que no se envió nada.';

  @override
  String networkBadStatus(int status) {
    return 'El proveedor rechazó la solicitud con el estado $status. Z Privacy no conservó nada de su documento.';
  }

  @override
  String get networkTimeout =>
      'El proveedor no respondió a tiempo. No se envió nada más.';

  @override
  String networkResponseTooLarge(int limitKib) {
    return 'La respuesta superaba los $limitKib KiB y no se leyó.';
  }

  @override
  String networkPayloadTooLarge(int kib, int limitKib) {
    return 'Este texto tiene $kib KiB y el proveedor acepta $limitKib KiB por solicitud.';
  }

  @override
  String get networkUnreadable =>
      'El proveedor respondió con algo que no es una respuesta.';

  @override
  String get networkUnreachable =>
      'No se pudo llegar a esa dirección en absoluto — nada respondió. Compruebe que tiene conexión y que la dirección es correcta. No se envió nada.';

  @override
  String get troubleVaultChangedElsewhere =>
      'Otra copia de Z Privacy modificó esta bóveda. Cierre esa ventana, o bloquee y desbloquee aquí para incorporar su trabajo.';

  @override
  String get troubleSessionChangedElsewhere =>
      'El archivo de esta sesión en su disco no lo escribió esta ventana, así que Z Privacy no lo sobrescribió. Cierre la otra copia, o bloquee y desbloquee aquí para leer lo que escribió.';

  @override
  String troubleStoragePermissionsKept(String reason) {
    return 'Z Privacy no cambiará un permiso que usted haya establecido, así que no se guardó nada — $reason. Cambie el permiso usted mismo o elija otra carpeta.';
  }

  @override
  String get troubleBadSpan =>
      'No se pudo leer esa selección. Intente seleccionar las palabras de nuevo.';

  @override
  String get troubleBetweenColumns =>
      'Esa pulsación cayó en el espacio entre dos columnas, así que no indica ningún valor — y Z Privacy no elegirá una columna por usted.';

  @override
  String get troubleUnknownToken =>
      'Ese valor protegido no está en esta sesión.';

  @override
  String get troubleNothingToSend =>
      'Todavía no hay nada que enviar. Traiga un documento o escriba un texto.';

  @override
  String get troubleSessionWithoutItsDocument =>
      'La sesión no se inició, porque Z Privacy no pudo saber qué documento tiene abierto — y una sesión tiene que renombrar lo que ya está protegido en él. No se cambió nada. Abra el documento e inicie la sesión desde allí.';

  @override
  String get troublePayloadAlreadySent =>
      'Esta solicitud ya se envió. Prepárela de nuevo para enviarla otra vez.';

  @override
  String get theReasonWasNotReported => 'no se indicó el motivo.';

  @override
  String get carriesFirst => 'Este documento contiene';

  @override
  String get carriesAlso => 'También contiene';

  @override
  String carriesOneNameFromElsewhere(String also, String which) {
    return '$also 1 nombre de una sesión que esta bóveda no guarda ($which). Nada aquí puede devolverlo: la clave que lo creó no está en esta bóveda.';
  }

  @override
  String carriesNamesFromOneSessionElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count nombres de una sesión que esta bóveda no guarda ($which). Nada aquí puede devolverlos: la clave que los creó no está en esta bóveda.';
  }

  @override
  String carriesNamesFromSessionsElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count nombres de sesiones que esta bóveda no guarda ($which). Nada aquí puede devolverlos: las claves que los crearon no están en esta bóveda.';
  }

  @override
  String carriesNamesFromElsewhereWithNoCount(
    String also,
    String whose,
    String which,
    String keys,
  ) {
    return '$also nombres de $whose ($which). Nada aquí puede devolverlos: $keys no están en esta bóveda.';
  }

  @override
  String get aSessionThisVaultDoesNotHold =>
      'una sesión que esta bóveda no guarda';

  @override
  String get sessionsThisVaultDoesNotHold =>
      'sesiones que esta bóveda no guarda';

  @override
  String get theKeyThatMadeThemIs => 'las claves que los crearon';

  @override
  String get andBetweenNames => ' y ';

  @override
  String get thisLanguageName => 'Español';

  @override
  String get languageWord => 'Idioma';

  @override
  String get chooseALanguage => 'Elija un idioma para continuar.';

  @override
  String get noAccount => 'Sin cuenta.';

  @override
  String get noAds => 'Sin anuncios.';

  @override
  String get noAnalytics => 'Sin analíticas.';

  @override
  String get noZPrivacyServer => 'Sin servidor de Z Privacy.';

  @override
  String get originalDataStaysHere =>
      'Sus datos originales permanecen en este dispositivo, salvo que copie explícitamente contenido restaurado.';

  @override
  String get onlyTheProtectedVersionIsSent =>
      'A través de Z Privacy, a la IA solo se envía la versión protegida.';

  @override
  String get theseRulesWillBeEnabled =>
      'Se activarán las reglas de privacidad en español.';

  @override
  String get start => 'Empezar';

  @override
  String get yourVault => 'Su bóveda';

  @override
  String get createAVault => 'Crear una bóveda';

  @override
  String get vaultWhy =>
      'Cada palabra que usted protege vive aquí, mientras conserve esta bóveda: los nombres que añade, los valores que enseña y las claves de cualquier IA que conecte. Permanece en este equipo, y no se escribe nada en ningún otro lugar.';

  @override
  String get onePassphrase =>
      'Una frase de contraseña, guardada en este dispositivo. Todo lo que Z aprende mientras usted trabaja — sus nombres, sus listas, sus decisiones — se guarda en ella.';

  @override
  String get byYourVoices => 'por YourVoices';

  @override
  String pageHasNothingMarked(int page) {
    return 'La página $page no tiene nada marcado por el analizador.';
  }

  @override
  String get addADocumentPdfWordOrText =>
      'Añadir un documento — PDF, Word o texto';

  @override
  String get addADocumentOrWriteToTheAi =>
      'Añada un documento — o escriba a la IA en la primera parte, sin ningún documento.';

  @override
  String get originalLocalOnly => 'Original — solo local';

  @override
  String get neverSentToAiSendCannotRead =>
      'Nunca se envía a la IA · Enviar no puede leer este lado';

  @override
  String get yourDocumentArrivesHere =>
      'Su documento llega aquí, tal como está escrito. Nada de este lado puede llegar a la red.';

  @override
  String get safeAiWillReceive => 'Protegido — lo que recibirá la IA';

  @override
  String get theRequestItselfNotAPreview =>
      'La solicitud misma, no una vista previa de ella';

  @override
  String get whatAnAiWouldReceiveStandsHere =>
      'Lo que recibiría una IA aparece aquí junto al original, palabra por palabra, antes de que se envíe nada.';

  @override
  String get theChatTitle => 'El chat';

  @override
  String get yourQuestionsAndWhatCameBack => 'Sus preguntas, y lo que volvió';

  @override
  String get theChatOpensHereWithTheFirstAnswer =>
      'El chat se abre aquí con la primera respuesta, y cada pregunta posterior lleva consigo el intercambio anterior.';

  @override
  String get typedText => 'Texto escrito';

  @override
  String get onePage => '1 página';

  @override
  String pagesCount(int pages) {
    return '$pages páginas';
  }

  @override
  String get vaultLabel => 'Bóveda';

  @override
  String get vaultIsUnlocked => 'Desbloqueada';

  @override
  String get vaultIsLocked => 'Bloqueada';

  @override
  String get vaultIsNone => 'Ninguna';

  @override
  String get yourVaultIsIn => 'Su bóveda está en';

  @override
  String get aVaultHereWouldBeIn => 'Aquí, una bóveda estaría en';

  @override
  String get openZVault => 'Abrir la Bóveda Z';

  @override
  String get lockNow => 'Bloquear ahora';

  @override
  String get openZVaultOrLockItNow => 'Abra la Bóveda Z, o bloquéela ahora';

  @override
  String get goToAPage => 'Ir a una página';

  @override
  String pageNumber(int page) {
    return 'Página $page';
  }

  @override
  String get pageWord => 'Página';

  @override
  String get chooseTheAiAndWhatTravels =>
      'Elija la IA y lo que viaja hacia ella';

  @override
  String get readThisDocumentWithAnotherRuleSet =>
      'Leer este documento con otro conjunto de reglas';

  @override
  String get generalRulesOnly => 'Solo reglas generales';

  @override
  String get packLabel => 'Paquete de idioma';

  @override
  String packWithGeneralRules(String pack) {
    return '$pack · reglas generales';
  }

  @override
  String get everywhere => 'En todas partes';

  @override
  String get profile => 'Perfil';

  @override
  String get profiles => 'Perfiles';

  @override
  String get chooseWhichClientDictionary =>
      'Elija qué diccionario de cliente usa esta sesión. El ID del perfil se queda dentro de la bóveda; el nombre visible es lo que ve la gente.';

  @override
  String get onlyIdentitiesForEveryProfile =>
      'Solo las identidades y reglas que se aplican a todos los perfiles.';

  @override
  String get createProfile => 'Crear perfil';

  @override
  String get done => 'Listo';

  @override
  String get rename => 'Renombrar';

  @override
  String get profileActive => 'Activo';

  @override
  String get profileSwitch => 'Cambiar';

  @override
  String get readItBack => 'Volver a leerlo';

  @override
  String get scanning => 'Analizando…';

  @override
  String get notScannedYet => 'Aún sin analizar';

  @override
  String get asItWasKept => 'Tal como se guardó';

  @override
  String lastScanNote(String note) {
    return 'Último análisis: $note';
  }

  @override
  String get scannedAsYouTyped => 'Analizado mientras escribía';

  @override
  String get scannedOnImport => 'Analizado al importar';

  @override
  String get lastScanManualRescan => 'Último análisis: nuevo análisis manual';

  @override
  String alreadyProtectedNothingScanned(int marks) {
    return '$marks ya protegidos · no se analizó nada en esta ejecución';
  }

  @override
  String protectedAutomaticallyNeedYourWord(int auto, int open, int normal) {
    return '$auto protegidos automáticamente · $open necesitan su decisión · $normal normales';
  }

  @override
  String get vaultLockedRulesAndPackRan =>
      'Bóveda bloqueada — se aplicaron las reglas y el paquete de idioma, la capa de la bóveda no';

  @override
  String get noVaultNothingRecognisedByName =>
      'Sin bóveda — no se reconoce nada por su nombre';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get removeTheDocument => 'Quitar el documento';

  @override
  String get nothingIsOpen => 'No hay nada abierto.';

  @override
  String get thereIsNothingToSendYet => 'Todavía no hay nada que enviar.';

  @override
  String get readingWhatThoseLinesHold =>
      'Leyendo lo que contienen esas líneas…';

  @override
  String oneLineProtectedOpen(int protected, int open) {
    return '1 línea · $protected protegidos en ella · $open abiertos';
  }

  @override
  String linesProtectedOpen(int lines, int protected, int open) {
    return '$lines líneas · $protected protegidos en ellas · $open abiertos';
  }

  @override
  String get pressAValueToProtectEveryHeldLine =>
      'Pulse un valor para proteger la misma celda en todas las líneas fijadas.';

  @override
  String get letTheLinesGo => 'Soltar las líneas';

  @override
  String get inStep => 'A la par';

  @override
  String get apart => 'Por separado';

  @override
  String get drawnAsChips => 'Fichas';

  @override
  String get drawnPlain => 'Sin formato';

  @override
  String get oneSuggestionStillOpen =>
      'Todavía hay una sugerencia abierta. Hasta que la responda, aparece aquí tal como está escrita — texto real en este lado.';

  @override
  String suggestionsStillOpen(int open) {
    return 'Todavía hay $open sugerencias abiertas. Hasta que las responda, aparecen aquí tal como están escritas — el único texto real en este lado.';
  }

  @override
  String get chooseWhoAnswers => 'Elegir quién responde';

  @override
  String get showTheChat => 'Mostrar el chat';

  @override
  String get whatWouldYouLikeToAskTheAi =>
      '¿Qué le gustaría preguntar a la IA?';

  @override
  String get whatShouldTheAiDoWithThis => '¿Qué debe hacer la IA con esto?';

  @override
  String get askAQuestionOrPasteALetter =>
      'Haga una pregunta, o pegue aquí una carta entera.';

  @override
  String get reconcileSectionAgainstSection =>
      'Concilie la sección A con la sección B y dígame dónde está la diferencia.';

  @override
  String get inWhatWillLeave => 'En lo que saldrá';

  @override
  String get addItToWhatWillLeave => 'Añadirla a lo que saldrá';

  @override
  String get aDocumentCanBeSentWithNoRequest =>
      'Un documento puede enviarse sin solicitud, y entonces el modelo no recibe ninguna instrucción';

  @override
  String get takeItOut => 'Sacarla';

  @override
  String get yourRequestNothingToProtect =>
      'Su solicitud está en la columna «Protegido», sin nada que proteger en ella.';

  @override
  String get yourRequestOneValueReplaced =>
      'Su solicitud está en la columna «Protegido», con un valor sustituido.';

  @override
  String yourRequestValuesReplaced(int count) {
    return 'Su solicitud está en la columna «Protegido», con $count valores sustituidos.';
  }

  @override
  String get oneRequestAtATime =>
      'Una solicitud cada vez — una nueva pregunta sustituye a esta, y el chat conserva cada intercambio.';

  @override
  String get oneQuestionLeftGoToIt => 'Queda 1 pregunta — ir a ella';

  @override
  String questionsLeftGoToTheFirst(int open) {
    return 'Quedan $open preguntas — ir a la primera';
  }

  @override
  String get protectIt => 'Protegerla';

  @override
  String get leaveItInTheClear => 'Dejarla sin proteger';

  @override
  String theOneLeftIsKind(String kind) {
    return 'La que queda es $kind.';
  }

  @override
  String get showWhatTheAiWillReceive => 'Mostrar lo que recibirá la IA';

  @override
  String get hideThisColumn => 'Ocultar esta columna';

  @override
  String get narrowThisPanel => 'Estrechar este panel';

  @override
  String get widenThisPanel => 'Ensanchar este panel';

  @override
  String get oneExchangeCarriedIntoTheNext =>
      'Un intercambio, que pasa a la siguiente pregunta.';

  @override
  String exchangesCarriedIntoTheNext(int count) {
    return '$count intercambios, que pasan a la siguiente pregunta.';
  }

  @override
  String get putTheChatAwayItIsNotEnded => 'Apartar el chat — no se termina';

  @override
  String get theFirstAnswerOpensTheChatHere =>
      'La primera respuesta abre aquí el chat. Cada pregunta posterior lleva consigo el intercambio anterior — no el chat entero, y nunca de nuevo el documento.';

  @override
  String get askSomethingElseAboutThis => 'Pregunte algo más sobre esto…';

  @override
  String get pasteTheAnswerYouWereGiven => 'Pegue la respuesta que recibió…';

  @override
  String get addItToTheChat => 'Añadirla al chat';

  @override
  String get notNow => 'Ahora no';

  @override
  String get copyTheChat => 'Copiar el chat';

  @override
  String get addAnAnswer => 'Añadir una respuesta';

  @override
  String get endTheChat => 'Terminar el chat';

  @override
  String get theChatIsOnYourClipboard =>
      'Lo que saldría está en su portapapeles, protegido — la pregunta tal como la recibiría una IA. Traiga la respuesta de vuelta con «Añadir una respuesta».';

  @override
  String get couldNotReadTheClipboard =>
      'Z Privacy no pudo leer el portapapeles.';

  @override
  String get thereIsNoTextOnTheClipboard => 'No hay texto en el portapapeles.';

  @override
  String get hideTheText => 'Ocultar el texto';

  @override
  String get showTheText => 'Mostrar el texto';

  @override
  String get theTextWithYourNamesBack =>
      'El texto, con sus nombres de vuelta — en este dispositivo';

  @override
  String get thisAnswerCarriesOneUnknownToken =>
      'Esta respuesta contiene 1 marcador que esta sesión no conoce — se creó en otra sesión.';

  @override
  String thisAnswerCarriesUnknownTokens(int count) {
    return 'Esta respuesta contiene $count marcadores que esta sesión no conoce — se crearon en otra sesión.';
  }

  @override
  String get copyRestored => 'Copiar lo restaurado';

  @override
  String get theMarkedWordsWerePutBackHere =>
      'Las palabras marcadas se restauraron aquí, en este dispositivo. El modelo nunca las vio.';

  @override
  String get theDottedWordsWerePutBackHere =>
      'Las palabras punteadas se restauraron aquí, en este dispositivo. Las tachadas son marcadores que esta sesión no puede restaurar.';

  @override
  String get copyRestoredTextQuestion => '¿Copiar el texto restaurado?';

  @override
  String get thisWillPlaceTheRealValues =>
      'Esto pondrá los valores protegidos reales en el portapapeles de su sistema. Puede que otras aplicaciones puedan leer el portapapeles.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get restoredTextCopied =>
      'Texto restaurado copiado en el portapapeles del sistema.';

  @override
  String get chooseWhoAnswersInTheMiddleFirst =>
      'Elija primero quién responde en la columna central';

  @override
  String sendThisQuestionTo(String name) {
    return 'Enviar esta pregunta a $name';
  }

  @override
  String get writeAQuestionFirst => 'Escriba primero una pregunta.';

  @override
  String get settings => 'Ajustes';

  @override
  String get roomPrivacy => 'Privacidad';

  @override
  String get roomLanguageAndRules => 'Idioma y reglas';

  @override
  String get roomVaultAndSecurity => 'Bóveda y seguridad';

  @override
  String get roomSessions => 'Sesiones';

  @override
  String get languageAndRulesWhat =>
      'Un paquete de idioma de privacidad es un motor de detección, no el idioma de la interfaz — y en un solo análisis puede ejecutarse más de un paquete de idioma, así que esto es un punto de partida y no las únicas reglas permitidas.';

  @override
  String get appLanguage => 'Idioma de la app';

  @override
  String get appLanguageWhat =>
      'El idioma con el que se lee una sesión que no tiene uno propio — y qué hábitos conoce el analizador en él: saludos, formas societarias, la manera de escribir un número de cliente. Una sesión creada con un idioma propio conserva el suyo; con este se lee cualquier otro texto. La interfaz sigue esta elección.';

  @override
  String theInterfaceIsEnglishUntilTranslated(String language) {
    return '$language: el paquete de idioma de detección es $language; la interfaz está en inglés hasta que se traduzcan sus frases.';
  }

  @override
  String get myPrivacyRules => 'Mis reglas de privacidad';

  @override
  String get myPrivacyRulesWhat =>
      'Aún no está construido. Las reglas que escriba usted mismo — un formato de número de cliente que solo usa su oficina, el nombre en clave de un proyecto — vivirán aquí, junto al paquete de idioma y no dentro de él.';

  @override
  String get vaultAndSecurityWhat =>
      'La clave, el bloqueo y dónde vive una credencial.';

  @override
  String get zVault => 'Bóveda Z';

  @override
  String get vaultOpenWhat =>
      'Abierta. Sus identidades están cargadas y la cuarta capa de detección está en marcha.';

  @override
  String get vaultLockedWhat =>
      'Bloqueada. Las reglas y el paquete de idioma siguen funcionando — un IBAN se sigue detectando — pero no a quién pertenece.';

  @override
  String get vaultAbsentWhat =>
      'No se ha creado en este dispositivo. No se reconoce nada por su nombre.';

  @override
  String unlockedWithIdentities(int count) {
    return 'Desbloqueada · $count identidades';
  }

  @override
  String get zPdfReadBack => 'z-pdf — volver a leer un documento protegido';

  @override
  String get zPdfWhat =>
      'El acto inverso. Un documento que salió de esta app con marcadores se vuelve a leer con sus propios nombres, aquí, a partir de su bóveda — y nunca se analiza, nunca se protege y nunca se pone en la mesa de trabajo. Nada de él se envía a ningún sitio.';

  @override
  String get openThisPanelFromTheApp =>
      'Abra este panel desde la app para elegir un archivo.';

  @override
  String get chooseAZPdfFile => 'Elegir un archivo z-pdf';

  @override
  String get lockTheVaultAfter => 'Bloquear la bóveda después de';

  @override
  String get minutesUnusedZeroIsNever => 'minutos sin uso · 0 = nunca';

  @override
  String get lockTheVaultAfterWhat =>
      'Lo mantiene la propia bóveda, no un temporizador en una pantalla: cada vía de acceso a ella consulta primero el reloj, así que un fallo en la interfaz no puede dejarla abierta.';

  @override
  String get encryptedLocalCredentialStorage =>
      'Almacenamiento local cifrado de credenciales';

  @override
  String get credentialHomesWhat =>
      'Una clave de proveedor tiene dos lugares y ningún tercero: sellada dentro de la bóveda cuando hay una abierta, o en memoria durante esta ejecución cuando no la hay. Nunca un archivo sin cifrar, y nunca se devuelve a la interfaz — no hay ninguna llamada en todo el contrato que la devuelva.';

  @override
  String get credentialSealedInTheVault => 'sellada en la bóveda';

  @override
  String get credentialInMemory => 'en memoria, desaparece al cerrar la app';

  @override
  String get credentialNoKeyStored => 'ninguna clave guardada';

  @override
  String get noProviderHoldsACredential =>
      'Ningún proveedor tiene una credencial.';

  @override
  String get deviceBoundProtection => 'Protección vinculada al dispositivo';

  @override
  String get deviceBoundWhat =>
      'Aún no está construido. Una clave vinculada a la autenticación propia de este dispositivo se situaría por encima de la capa superior, sin cambiar lo que se guarda — los mismos registros, un cierre más.';

  @override
  String get sessionsWhat =>
      'Una sesión tiene su propia clave, y las claves están en la bóveda.';

  @override
  String get theVaultIsShutNoSessions =>
      'La bóveda está cerrada, así que no hay sesiones que mostrar. Ábrala y volverán — las conversaciones en sí nunca estuvieron en ella.';

  @override
  String get eachSessionHasItsOwnEncryption =>
      'Cada sesión tiene su propio cifrado. El mismo nombre en dos sesiones recibe dos marcadores distintos, y dentro de una sesión recibe el mismo dondequiera que aparezca — así, una sesión es la forma de elegir qué puede relacionar una IA y qué no. Todas las claves están en su bóveda, así que volver a leer un archivo protegido es una puerta de la propia bóveda y no de una sesión: todo lo guardado desde cualquier sesión de esta bóveda vuelve con sus nombres reales, y la lectura indica de qué sesión procede.';

  @override
  String get newSession => 'Nueva sesión';

  @override
  String get newSessionWhat =>
      'Un nombre y un idioma, ambos a su elección: el idioma es la forma en que Z lee cada texto de esta sesión, y se pregunta una sola vez, aquí. Se convierte de inmediato en la sesión en la que trabaja. Todo lo que ya esté protegido en el documento que tiene delante se renombra en ella — todavía no se ha enviado nada, así que nada de lo que salió se ve afectado.';

  @override
  String get whatIsThisOneAbout => '¿De qué trata esta?';

  @override
  String get begin => 'Comenzar';

  @override
  String get noSessionsYet => 'Todavía no hay sesiones';

  @override
  String get noSessionsYetWhat =>
      'Una nace la primera vez que copia texto protegido o pide un PDF — no se rechaza por falta de nombre, toma su propio número como nombre, y usted puede renombrarla aquí. Nunca tiene que crear una a mano antes.';

  @override
  String theOneYouAreIn(String when, String exchanges) {
    return '$when · $exchanges · en la que está';
  }

  @override
  String get workInThisSession => 'Trabajar en esta sesión';

  @override
  String get enter => 'Entrar';

  @override
  String get renameThisSession => 'Renombrar esta sesión';

  @override
  String get deleteThisSession => 'Eliminar esta sesión';

  @override
  String get oneExchange => '1 intercambio';

  @override
  String exchangesCount(int count) {
    return '$count intercambios';
  }

  @override
  String renameSessionNumber(int number) {
    return '¿Renombrar la sesión $number?';
  }

  @override
  String theNumberStaysWhatItIs(int number) {
    return 'El número sigue siendo $number — es lo que esta sesión es, y nada de lo que se protegió en ella cambia. Solo cambia la palabra de la fila.';
  }

  @override
  String get keepTheName => 'Conservar el nombre';

  @override
  String get renameIt => 'Renombrarla';

  @override
  String deleteNamed(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get thisDestroysTheKey =>
      'Esto destruye la clave con la que se protegió esta sesión.';

  @override
  String get everyDocumentCanNeverBeUnprotected =>
      'Lo que ya salió protegido de esta sesión nunca podrá volver a desprotegerse — ni por usted, ni por Z Privacy. La clave era lo único que podía hacerlo, y dejará de existir. «Deshacer protección» quita una cubierta del texto que tiene delante, nunca de lo que ya se fue.';

  @override
  String get anythingYouSentStaysAsItWas =>
      'Todo lo que envió desde esta sesión queda exactamente como estaba. Lo que desaparece es el camino de vuelta.';

  @override
  String get keepIt => 'Conservarla';

  @override
  String get deleteTheSession => 'Eliminar la sesión';

  @override
  String get oneProtectedPlace => '1 lugar protegido';

  @override
  String protectedPlacesCount(int count) {
    return '$count lugares protegidos';
  }

  @override
  String get renameThisDocument => 'Renombrar este documento';

  @override
  String renameHandle(String handle) {
    return '¿Renombrar $handle?';
  }

  @override
  String theNameIsWhatYouRead(String handle) {
    return 'El nombre es lo que usted lee en esta lista. $handle sigue siendo lo que es: un número se usa una sola vez y nunca se asigna a otro documento.';
  }

  @override
  String get aNameForThisDocument => 'Un nombre para este documento';

  @override
  String get roomAi => 'IA';

  @override
  String get aiWhat =>
      'Tres formas de preguntar a un modelo. La primera no necesita ninguna cuenta.';

  @override
  String get manualAi => 'IA manual';

  @override
  String get manualAiWhat =>
      'Use un chat de IA que ya tenga. Copie el texto protegido del espacio de trabajo, péguelo en el modelo que use y traiga la respuesta de vuelta. Nada que configurar, nada que pagar, y la restauración funciona exactamente igual.';

  @override
  String get alwaysAvailableFirstDoor =>
      'Siempre disponible — es la hoja «Elegir quién responde», primera puerta.';

  @override
  String get directApi => 'API directa';

  @override
  String get directApiWhat =>
      'Conéctese a un proveedor de IA remoto con su credencial de API. La clave entra una vez y nunca vuelve a salir — ninguna pantalla de esta app puede volver a mostrársela.';

  @override
  String get atThisAddressNoCredential =>
      'En esta dirección no se necesita ninguna credencial.';

  @override
  String get protocol => 'Protocolo';

  @override
  String get connectedKeySealed => 'Conectado · clave sellada en la bóveda';

  @override
  String get connectedKeyThisRunOnly =>
      'Conectado · clave guardada solo para esta ejecución';

  @override
  String get connectedNoKeyNeeded => 'Conectado · no se necesita clave';

  @override
  String get notConnected => 'No conectado';

  @override
  String get localAi => 'IA local';

  @override
  String get localAiWhat =>
      'Funciona a través de un servicio de IA en este equipo — llama.cpp, Ollama, LM Studio, cualquier cosa que responda con la misma forma. Sin clave, sin cuenta, y la solicitud nunca sale de este equipo. Solo se acepta http sin cifrar para una dirección de bucle local literal.';

  @override
  String get models => 'Modelos';

  @override
  String get privacyWhat =>
      'Lo que la app hace por sí sola, y hasta dónde llega sin preguntar.';

  @override
  String get noVaultSoThisRunOnly =>
      'No hay ninguna bóveda abierta, así que esto vale solo para esta ejecución — sin una bóveda no hay dónde guardarlo.';

  @override
  String get scanOnArrival => 'Analizar un documento en cuanto llega';

  @override
  String get scanOnArrivalWhat =>
      'Sin diálogo, sin botón. Desactivar esto significa que un documento queda sin proteger hasta que pulse «Volver a analizar» — que es justo el momento que los tableros se escribieron para evitar.';

  @override
  String get answerEverySuggestion =>
      'Responder a cada sugerencia antes de enviar';

  @override
  String get answerEverySuggestionWhat =>
      'No es un ajuste. Una sugerencia sin responder nunca se trata en silencio como protegida, y no existe «enviar de todos modos» — ni aquí, ni en un indicador oculto, ni en ninguna parte del código.';

  @override
  String get aRevealedValueStaysFor => 'Un valor mostrado permanece durante';

  @override
  String get aRevealedValueStaysForWhat =>
      'Mostrar dibuja en la pantalla y nunca escribe en lo que sale. Esto es solo cuánto tiempo permanece dibujado.';

  @override
  String get tokenRotation => 'Rotación de marcadores';

  @override
  String get tokenRotationWhat =>
      'Aún no está construido. Cuando lo esté, vivirá aquí: si un marcador permanente conserva su número entre sesiones, o se genera de nuevo cada vez para que dos sesiones no puedan vincularse a través de él.';

  @override
  String get back => 'Atrás';

  @override
  String get allIdentities => 'Todas las identidades';

  @override
  String identitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identidades',
      one: '1 identidad',
    );
    return '$_temp0';
  }

  @override
  String valuesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valores',
      one: '1 valor',
    );
    return '$_temp0';
  }

  @override
  String protectedWordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras protegidas',
      one: '1 palabra protegida',
    );
    return '$_temp0';
  }

  @override
  String get notCreatedOnThisDevice => 'No creada en este dispositivo';

  @override
  String get changePassphrase => 'Cambiar la frase de contraseña';

  @override
  String get lockTheVault => 'Bloquear';

  @override
  String get theVaultIsLocked => 'La bóveda está bloqueada';

  @override
  String get thereIsNoVaultYet => 'Todavía no hay ninguna bóveda';

  @override
  String get yourIdentitiesAreSealed =>
      'Sus identidades están en este dispositivo, selladas. Mientras no esté abierta, el analizador sigue aplicando sus reglas y su paquete de idioma — un IBAN se sigue detectando — pero no a quién pertenece.';

  @override
  String get yourNamesLiveInOneVaultFile =>
      'Sus nombres viven en un archivo de bóveda cifrado. Contiene sus personas y sus valores, cifrados con una frase de contraseña que nunca sale de este dispositivo. Sin una, no se reconoce nada por su nombre.';

  @override
  String get searchThisDevice =>
      'Buscar en este dispositivo — nombres, valores, grafías';

  @override
  String get newIdentity => 'Nueva identidad';

  @override
  String get filterAll => 'Todos';

  @override
  String get sessionProfile => 'Perfil de la sesión';

  @override
  String get newProfile => 'Nuevo perfil';

  @override
  String get noIdentitiesYet =>
      'Todavía no hay identidades. La primera suele ser el cliente con cuyos documentos trabaja.';

  @override
  String nothingMatchesQuery(String query) {
    return 'Nada en este dispositivo coincide con «$query».';
  }

  @override
  String get valuesITaught => 'Valores que enseñé';

  @override
  String get valuesITaughtWhat =>
      'nombres, empresas, números — a partir de ahora se encuentran solos';

  @override
  String get rulesITaught => 'Reglas que enseñé';

  @override
  String get rulesITaughtWhat =>
      'palabras que dicen lo que viene detrás — «tras Mandantenkennung → número de cliente»';

  @override
  String get exceptionsITaught => 'Excepciones que enseñé';

  @override
  String get exceptionsITaughtWhat =>
      'valores que excluyó explícitamente de la protección';

  @override
  String get noTaughtValuesYet => 'Todavía no hay valores enseñados.';

  @override
  String get noRulesTaughtYet => 'Todavía no hay reglas enseñadas.';

  @override
  String get noSavedExceptionsYet => 'Todavía no hay excepciones guardadas.';

  @override
  String kindScopeTaughtOn(String kind, String scope, String date) {
    return '$kind · $scope · Enseñado: $date';
  }

  @override
  String doNotProtectAsKindScopeTaughtOn(
    String kind,
    String scope,
    String date,
  ) {
    return 'No proteger como $kind · $scope · Enseñado: $date';
  }

  @override
  String get reveal => 'Mostrar';

  @override
  String get hide => 'Ocultar';

  @override
  String get theExceptionGoes =>
      'la excepción — este valor volverá a ofrecerse para su protección';

  @override
  String get theRuleGoes =>
      'la regla — Z Privacy dejará de proteger lo que sigue a esa palabra';

  @override
  String get openIdentity => 'Abrir';

  @override
  String profileNamed(String name) {
    return 'Perfil: $name';
  }

  @override
  String get taughtOnUnknown => 'desconocida';

  @override
  String afterLabelProtectAs(String label, String kind) {
    return 'Tras «$label:» → $kind';
  }

  @override
  String get teachARule => 'Enseñar una regla';

  @override
  String get kindClient => 'Cliente';

  @override
  String get kindPerson => 'Persona';

  @override
  String get kindCompany => 'Empresa';

  @override
  String get kindProject => 'Proyecto';

  @override
  String get kindSomethingElse => 'Otra cosa';

  @override
  String vaultFileNotChanged(String said) {
    return '$said Z Privacy no ha modificado el archivo. Si tiene una copia de seguridad de la bóveda, vuelva a ponerla en su sitio; si no, mueva este archivo a otro lugar y aquí se podrá crear una bóveda nueva.';
  }

  @override
  String get changeThePassphrase => 'Cambiar la frase de contraseña';

  @override
  String get onlyThirtyTwoBytes =>
      'Solo se vuelven a envolver 32 bytes — la bóveda en sí no se descifra ni se reescribe. Todo lo que contiene se queda exactamente donde está.';

  @override
  String get currentPassphrase => 'Frase de contraseña actual';

  @override
  String get passphrase => 'Frase de contraseña';

  @override
  String get newPassphrase => 'Nueva frase de contraseña';

  @override
  String get confirmPassphrase => 'Confirmar la frase de contraseña';

  @override
  String get confirmNewPassphrase => 'Confirmar la nueva frase de contraseña';

  @override
  String get passphrasesMatch => 'Las frases de contraseña coinciden';

  @override
  String get passphrasesDoNotMatch => 'Las frases de contraseña no coinciden';

  @override
  String atLeastCharacters(int count) {
    return 'Al menos $count caracteres — la bóveda no se creará con menos.';
  }

  @override
  String get thereIsNoWayBack =>
      'No hay vuelta atrás. Nadie guarda una copia de esto, y no existe ningún restablecimiento — la frase de contraseña nunca sale de este dispositivo y nada de nuestro lado podría recuperar la bóveda sin ella.';

  @override
  String get working => 'Procesando…';

  @override
  String get changeIt => 'Cambiarla';

  @override
  String get createTheVault => 'Crear la bóveda';

  @override
  String get unlockTheVault => 'Desbloquear';

  @override
  String hideNamed(String label) {
    return 'Ocultar $label';
  }

  @override
  String showNamed(String label) {
    return 'Mostrar $label';
  }

  @override
  String get aNewIdentity => 'Una nueva identidad';

  @override
  String get anIdentityIsHowAPersonThinks =>
      'Una identidad es como piensa una persona — «Cliente Nordstern» — y los valores que contiene son lo que busca el analizador.';

  @override
  String get nameField => 'Nombre';

  @override
  String get sortField => 'Tipo';

  @override
  String get loadedIn => 'Cargada en';

  @override
  String get exampleClientNordstern => 'Cliente Nordstern';

  @override
  String get exampleCompanyName => 'Nordstern Consulting GmbH';

  @override
  String get cancelForm => 'Cancelar';

  @override
  String get createIt => 'Crear';

  @override
  String get aNewValue => 'Un nuevo valor';

  @override
  String get editThisValue => 'Editar este valor';

  @override
  String get theValue => 'El valor';

  @override
  String get readingItFromTheVault => 'leyéndolo de la bóveda…';

  @override
  String get whatItIs => 'Qué es';

  @override
  String get howToTreatIt => 'Cómo tratarlo';

  @override
  String get alwaysProtect => 'Proteger siempre';

  @override
  String get alwaysProtectWhat =>
      'Se encuentra solo y se sustituye, sin preguntar.';

  @override
  String get suggestPolicy => 'Sugerir';

  @override
  String get suggestPolicyWhat =>
      'Se encuentra y se le presenta antes de enviar nada.';

  @override
  String get keepDoNotHunt => 'Conservar, sin buscar';

  @override
  String get keepDoNotHuntWhat =>
      'Se conserva para que sus grafías y su marcador sigan estables — pero no se busca.';

  @override
  String get saveIt => 'Guardar';

  @override
  String get aNewProfile => 'Un nuevo perfil';

  @override
  String get renameProfile => 'Renombrar el perfil';

  @override
  String get oneDictionaryPerClient =>
      'Un diccionario por cliente. Solo se cargan las identidades del perfil que abre — abrir la bóveda no es un cheque en blanco.';

  @override
  String get theProfileIdStaysTheSame =>
      'El ID del perfil sigue siendo el mismo. Solo cambia el nombre que lee una persona.';

  @override
  String get languagesUsedInDocuments => 'Idiomas usados en los documentos';

  @override
  String get moreThanOneMayBeOn =>
      'Puede haber más de uno activado. Un documento con una etiqueta en alemán y otra en inglés lo leen ambos en un solo análisis.';

  @override
  String get renameIt2 => 'Renombrar';

  @override
  String get teachARuleHead => 'Enseñar una regla';

  @override
  String get aRuleIsAWordAndWhatComesAfter =>
      'Una regla es una palabra y lo que viene detrás. Z Privacy protege el valor que sigue y se detiene al final de ese campo.';

  @override
  String get whenZPrivacySees => 'Cuando Z Privacy vea';

  @override
  String get exampleMandantenkennung => 'Mandantenkennung';

  @override
  String get protectTheValueAfterItAs => 'Proteger el valor que sigue como';

  @override
  String get whereField => 'Dónde';

  @override
  String profileNamedDash(String name) {
    return 'Perfil — $name';
  }

  @override
  String get saveRule => 'Guardar la regla';

  @override
  String get removeProtectionHere => 'Quitar la protección aquí';

  @override
  String removeItInThisSession(int places) {
    return 'Quitarla en esta sesión ($places lugares)';
  }

  @override
  String get forgetFromThisProfile => 'Olvidar en este perfil';

  @override
  String get forgetEverywhere => 'Olvidar en todas partes';

  @override
  String get protectThisColumnInTheLineHeld =>
      'Proteger esta columna en la línea fijada';

  @override
  String protectThisColumnInLinesHeld(int lines) {
    return 'Proteger esta columna en las $lines líneas fijadas';
  }

  @override
  String get whyIsThisProtected => '¿Por qué está protegido esto?';

  @override
  String get theSameCellOfEveryHeldLine =>
      'La misma celda de cada línea fijada, cada valor con su propio marcador. Este ya está protegido y se queda como está.';

  @override
  String get whatItIsRow => 'Qué es';

  @override
  String get whereItApplies => 'Dónde se aplica';

  @override
  String get decidedBy => 'Decidido por';

  @override
  String get decidedByYou => 'Usted';

  @override
  String get decidedByZPrivacy => 'Z Privacy, por sí solo';

  @override
  String get taughtOnRow => 'Enseñado el';

  @override
  String get tokenRow => 'Marcador';

  @override
  String otherSpellingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grafías más',
      one: '1 grafía más',
    );
    return '$_temp0';
  }

  @override
  String get close => 'Cerrar';

  @override
  String get uncoversThisOnePlace =>
      'Descubre solo este lugar. Todos los demás lugares conservan su protección, y su marcador.';

  @override
  String get theValueStaysInYourRules =>
      'El valor permanece en sus reglas de privacidad y puede volver a protegerse más adelante.';

  @override
  String get uncoversEveryPlaceInThisSession =>
      'Descubre cada lugar en el que aparece este marcador, en esta sesión.';

  @override
  String get thereIsNoEverywhere =>
      'No existe «en todas partes»: quitar la protección no llega más allá de una sesión.';

  @override
  String get removesWhatZLearnedForThisProfile =>
      'Elimina lo que Z Privacy aprendió para este perfil.';

  @override
  String get protectionAlreadyAppliedStays =>
      'La protección ya aplicada en este documento se mantiene.';

  @override
  String get removesWhatZLearnedEverywhere =>
      'Elimina lo que Z Privacy aprendió, en todos los perfiles.';

  @override
  String get forgetThisRule => 'Olvidar esta regla';

  @override
  String get theRuleItselfIsKept => 'La regla en sí se conserva en su bóveda.';

  @override
  String get forgetItInZVaultRules =>
      'Olvídela en Bóveda Z → Mis reglas de privacidad → Reglas que enseñé.';

  @override
  String get nothingWasLearnedYouProtectedIt =>
      'No se aprendió nada de esto — usted lo protegió aquí, y Deshacer lo revierte.';

  @override
  String get nothingWasLearnedARuleSawIt =>
      'No se aprendió nada de esto. Una regla reconoció la forma, y no se guardó ningún registro.';

  @override
  String forgottenButStillKnownBy(String who) {
    return 'Olvidado, pero $who aún lo reconoce. Por favor, avísenos — esto no debería ser posible.';
  }

  @override
  String forgetNamed(String what) {
    return '¿Olvidar «$what»?';
  }

  @override
  String get thisWillRemove => 'Esto eliminará';

  @override
  String protectedValuesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valores protegidos',
      one: '1 valor protegido',
    );
    return '$_temp0';
  }

  @override
  String spellingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grafías',
      one: '1 grafía',
    );
    return '$_temp0';
  }

  @override
  String identitiesLeftHoldingNothing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identidades',
      one: '1 identidad',
    );
    return '$_temp0 que se quedan sin contenido';
  }

  @override
  String itsPlaceIn(String profile) {
    return 'su lugar en $profile';
  }

  @override
  String get itWillNotChange => 'NO cambiará';

  @override
  String get forgetRemovesFromThisVault =>
      'Olvidar elimina este valor de la bóveda actual y del reconocimiento futuro por esa bóveda. No elimina la protección ya aplicada en este documento, y una copia válida más antigua de la bóveda puede restaurar el valor más adelante.';

  @override
  String wouldStillRecogniseIt(String who) {
    return '$who aún lo reconocería — olvidar aquí no llega a los registros de otro cliente.';
  }

  @override
  String get thisCannotBeUndone => 'Esto no se puede deshacer.';

  @override
  String get noValuesYet =>
      'Todavía no hay valores. Un valor es lo que busca el analizador — un nombre, una empresa, un IBAN.';

  @override
  String valuesEachWithItsOwnPolicy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valores',
      one: '1 valor',
    );
    return '$_temp0, cada uno con sus propias grafías y su propia política.';
  }

  @override
  String get moveIt => 'Mover';

  @override
  String get deleteIt => 'Eliminar';

  @override
  String get addAValue => 'Añadir un valor';

  @override
  String get policyKeptNotHunted => 'Conservado, sin buscar';

  @override
  String get addASpelling => 'Añadir una grafía';

  @override
  String get editIt => 'Editar';

  @override
  String get alsoWritten => 'También se escribe';

  @override
  String get anotherSpelling => 'Otra grafía';

  @override
  String get anotherSpellingWhat =>
      'El mismo valor escrito de otra forma — «Herr Müller», «T. Müller». Cada grafía conserva el mismo marcador, así que el modelo lee una persona y no tres.';

  @override
  String get exampleSpelling => 'Herr Müller';

  @override
  String get renameHead => 'Renombrar';

  @override
  String get whatToCallThisIdentity => 'Cómo llamar a esta identidad.';

  @override
  String get moveThisIdentity => 'Mover esta identidad';

  @override
  String get anIdentityInAProfile =>
      'Una identidad de un perfil solo se carga cuando ese perfil está abierto. Una que pertenece a todas partes se carga siempre.';

  @override
  String get deleteThisIdentity => '¿Eliminar esta identidad?';

  @override
  String identityAndItsValuesAreRemoved(String name, String values) {
    return '«$name» y sus $values se eliminan de la bóveda. Los documentos ya protegidos conservan sus marcadores; el próximo documento ya no reconocerá estos valores.';
  }

  @override
  String get keepItIdentity => 'Conservarla';

  @override
  String get noNamesToLookAt => 'No hay nombres que revisar';

  @override
  String namesToLookAtCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nombres que revisar',
      one: '1 nombre que revisar',
    );
    return '$_temp0';
  }

  @override
  String get zKnowsEveryName =>
      'Z conoce todos los nombres que usa este documento.';

  @override
  String get wordsThisDocumentUsesAsNames =>
      'Palabras que este documento usa como nombres y que Z aún no conoce.';

  @override
  String placesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lugares',
      one: '1 lugar',
    );
    return '$_temp0';
  }

  @override
  String pagesCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas',
      one: '1 página',
    );
    return '$_temp0';
  }

  @override
  String get addAsFamilyName => 'Añadir como apellido';

  @override
  String get addAsGivenName => 'Añadir como nombre de pila';

  @override
  String get ignoreIt => 'Ignorar';

  @override
  String get unlockTheVaultAct => 'Desbloquear la bóveda';

  @override
  String get needsAVault => 'Necesita una bóveda';

  @override
  String get nameListsFileType => 'Listas de nombres';

  @override
  String get whichLanguageAreTheseNames => '¿De qué idioma son estos nombres?';

  @override
  String get yourNames => 'Sus nombres';

  @override
  String get namesThisDeviceKnows =>
      'Nombres que este dispositivo conoce porque usted lo indicó. Se guardan en su bóveda, en este equipo.';

  @override
  String get addAName => 'Añadir un nombre';

  @override
  String get importAList => 'Importar una lista';

  @override
  String actNeedsTheVault(String act, String needs) {
    return '$act · $needs';
  }

  @override
  String get aListIsACsv =>
      'Una lista es un CSV con una columna «name» y una columna «type»: given, family, person o company.';

  @override
  String get yourNamesLiveInTheVault =>
      'Sus nombres viven en la bóveda, así que añadir uno requiere que esté abierta.';

  @override
  String get exampleSurname => 'Lindqvist';

  @override
  String get pickSuggest => 'Sugerir';

  @override
  String get pickAlways => 'Siempre';

  @override
  String get alwaysProtectedTheMoment =>
      'Siempre: se protege en cuanto aparece, en todos los documentos.';

  @override
  String get suggestMarksAndWaits =>
      'Sugerir: Z lo marca y espera su decisión.';

  @override
  String get addAct => 'Añadir';

  @override
  String get nothingYet => 'Todavía nada.';

  @override
  String get wholeNamesKeptInTheVault =>
      'Nombres completos, guardados en la bóveda';

  @override
  String get aWholePersonIsAValue =>
      'Una persona o empresa completa es un valor, no una palabra de diccionario, así que no está en ninguna lista de idioma. La Bóveda Z es donde se gestiona cada una.';

  @override
  String get reachEverywhere => 'en todas partes';

  @override
  String get reachThisClient => 'este cliente';

  @override
  String forgetNamedShort(String what) {
    return 'Olvidar «$what»';
  }

  @override
  String get kindGivenName => 'nombre de pila';

  @override
  String get kindFamilyName => 'apellido';

  @override
  String get kindPersonName => 'persona';

  @override
  String get kindCompanyName => 'empresa';

  @override
  String namesAndValuesInAList(String names, int values) {
    return '$names · $values valores';
  }

  @override
  String get listIsOff => 'desactivada';

  @override
  String get stopUsingTheseNames => 'Dejar de usar estos nombres';

  @override
  String get useTheseNamesAgain => 'Volver a usar estos nombres';

  @override
  String whatToDoWithList(String name) {
    return 'Qué hacer con «$name»';
  }

  @override
  String get moveToDots => 'Mover a…';

  @override
  String get exportCsv => 'Exportar CSV';

  @override
  String get removeList => 'Quitar la lista';

  @override
  String removeNamedList(String name) {
    return '¿Quitar «$name»?';
  }

  @override
  String namesGoWithItCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nombres se van con ella. No se toca nada más.',
      one: 'Un nombre se va con ella. No se toca nada más.',
    );
    return '$_temp0';
  }

  @override
  String get removeAct => 'Quitar';

  @override
  String moveNamesFromTo(int count, String from) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mover $count nombres de $from a…',
      one: 'Mover un nombre de $from a…',
    );
    return '$_temp0';
  }

  @override
  String get howFarDoTheseNamesReach => '¿Hasta dónde llegan estos nombres?';

  @override
  String get protectingThemMeans =>
      'Protegerlos significa que Z los tapa en cuanto aparecen, sin preguntar. Ofrecerlos significa que Z los marca y espera su decisión.';

  @override
  String get youCanChangeAnyOneAfterwards =>
      'Después puede cambiar cualquiera de ellos, nombre por nombre.';

  @override
  String get offerThemAndIDecide => 'Ofrecérmelos y yo decido';

  @override
  String get protectThemEverywhere => 'Protegerlos en todas partes';

  @override
  String protectThemForClient(String client) {
    return 'Protegerlos para $client';
  }

  @override
  String get couldNotBuildThePdf =>
      'Z Privacy no pudo generar el PDF — su página de respuesta no tenía marcador. No se escribió nada.';

  @override
  String get whoAnswers => 'Quién responde';

  @override
  String get thereIsNothingToSend => 'No hay nada que enviar.';

  @override
  String valuesReplacedCharacters(int values, int characters) {
    return '$values valores sustituidos · $characters caracteres saldrían de este dispositivo.';
  }

  @override
  String sessionNumber(int number) {
    return 'Sesión $number';
  }

  @override
  String sessionNumberNamed(int number, String name) {
    return 'Sesión $number «$name»';
  }

  @override
  String theseNamesAreThisSessions(String named) {
    return '$named · estos nombres son de esta sesión';
  }

  @override
  String get noSessionNamesForThisDocument =>
      'Sin sesión — estos nombres se crearon solo para este documento.';

  @override
  String get noSessionYetAnyDoorBeginsOne =>
      'Todavía no hay sesión — cualquier puerta de aquí inicia una.';

  @override
  String get nothingLeftTheMachine => 'Nada salió del equipo.';

  @override
  String get oneSuggestionStillOpenSend =>
      'Todavía hay una sugerencia abierta. Aparece en el texto tal como está escrita, y no se puede enviar nada hasta que la responda. No existe «enviar de todos modos».';

  @override
  String suggestionsStillOpenSend(int open) {
    return 'Todavía hay $open sugerencias abiertas. Aparecen en el texto tal como están escritas, y no se puede enviar nada hasta que las responda. No existe «enviar de todos modos».';
  }

  @override
  String get manualAiSheetWhat =>
      'Use un chat de IA que ya tenga. Lleve el texto de arriba — al portapapeles, o como PDF guardado en este equipo —, péguelo en el modelo que prefiera y traiga la respuesta de vuelta con «Añadir una respuesta» bajo el chat. La restauración funciona igual en ambos casos — sin cuenta, sin clave. Ninguna de las dos formas envía nada desde aquí.';

  @override
  String get copied => 'Copiado';

  @override
  String get copyProtected => 'Copiar lo protegido';

  @override
  String get saving => 'Guardando…';

  @override
  String get saveAsPdf => 'Guardar como PDF';

  @override
  String savedToWhere(String where) {
    return 'Guardado en $where';
  }

  @override
  String get whatThePdfHolds =>
      'El texto protegido, con el sello de la versión, los recuentos y un sha256 de ese texto en el pie de página, y una última página para la respuesta. No se envió nada.';

  @override
  String get directApiSheetWhatRemote =>
      'Conéctese a un proveedor de IA remoto con su credencial de API. Solo viajaría el texto de arriba; el proveedor sigue viendo los datos habituales de una conexión — su dirección, la hora, el modelo.';

  @override
  String get directApiSheetWhatConnected =>
      'La solicitud sale de esta app. Solo viaja el texto de arriba; el proveedor sigue viendo los datos habituales de una conexión — su dirección, la hora, el modelo.';

  @override
  String get noProviderIsConnected =>
      'No hay ningún proveedor conectado. La dirección y la clave se indican una sola vez, en Ajustes — esta pantalla nunca las pide.';

  @override
  String get sending => 'Enviando…';

  @override
  String sendToNamed(String where) {
    return 'Enviar a $where';
  }

  @override
  String get providerKeyThisRunOnly =>
      '  (clave guardada solo para esta ejecución)';

  @override
  String get theAddressTheModelTheKey =>
      'La dirección, el modelo y la clave se cambian en Ajustes.';

  @override
  String get localAiSheetWhat =>
      'Use un servicio de IA que se ejecute en este equipo — llama.cpp, Ollama, LM Studio, cualquier cosa que responda con la misma forma. Sin clave, sin cuenta, y la solicitud nunca sale de este equipo. Es la única vía que no ve ninguno de los datos habituales de arriba.';

  @override
  String get aModelOnThisComputer =>
      'Un modelo en este equipo se configura en Ajustes — no hay ninguna clave que dar.';

  @override
  String get openSettings => 'Abrir Ajustes';

  @override
  String get modelLabel => 'Modelo';

  @override
  String get fileKindDocuments => 'Documentos';

  @override
  String onlyTheseKindsAreRead(String name) {
    return 'Esta versión lee archivos PDF, de Word y de texto. «$name» no es ninguno de ellos.';
  }

  @override
  String get generalRulesOnlyNoDictionary =>
      'Solo reglas generales — todavía sin diccionario';

  @override
  String get whichLanguageIsThisText => '¿En qué idioma está este texto?';

  @override
  String get theSessionLanguageExplained =>
      'Z lo lee con los hábitos de ese idioma: cómo se saluda a la gente, cómo se escribe una empresa, qué aspecto tiene un número de cliente. A partir de ahora este es el idioma de la sesión, y no se le volverá a preguntar en ella.';

  @override
  String allLinesHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Las $count líneas',
      one: 'La 1 línea',
    );
    return '$_temp0';
  }

  @override
  String get revealHidden => 'Oculto';

  @override
  String revealedForSeconds(int seconds) {
    return 'Mostrado · $seconds s';
  }

  @override
  String get alsoTheWordBefore => 'También la palabra anterior';

  @override
  String get alsoTheWordBeforeHint =>
      'Incluye también la palabra con mayúscula delante de la selección';

  @override
  String get undoProtection => 'Deshacer protección';

  @override
  String get nothingToUndoHint => 'Nada que deshacer';

  @override
  String get rescanAct => 'Volver a analizar';

  @override
  String nextOfWaitingCount(int at, int total) {
    return 'Siguiente $at/$total';
  }

  @override
  String get reviewAct => 'Revisar';

  @override
  String get namesAct => 'Nombres';

  @override
  String get zKnowsEveryNameHere =>
      'Z conoce todos los nombres que usa este documento';

  @override
  String get tokensAct => 'Marcadores';

  @override
  String get nothingIsProtectedYetHint => 'Todavía no hay nada protegido';

  @override
  String get selectionCutsIntoProtected =>
      'Esa selección corta algo ya protegido. Proteger tomaría en su lugar el elemento completo.';

  @override
  String selectionSpansProtectedItems(int count) {
    return 'Esa selección abarca $count elementos protegidos. Proteger tomaría cada uno de ellos completo, con su propio marcador.';
  }

  @override
  String get protectAct => 'Proteger';

  @override
  String get selectTextThenProtect => 'Seleccione texto y pulse Proteger';

  @override
  String get alreadyProtectedSeeBelow => 'Ya protegido — vea abajo';

  @override
  String get protectWholeItems => 'Proteger elementos completos';

  @override
  String get thereWasNothingToUndo => 'No había nada que deshacer.';

  @override
  String tookBackTokens(String tokens) {
    return 'Revertido: $tokens.';
  }

  @override
  String tookBackTokensInPlaces(String tokens, int places) {
    return 'Revertido: $tokens, en los $places lugares — entró como un solo acto, así que salió como uno.';
  }

  @override
  String tookBackTokensIdentityStays(String tokens, String identity) {
    return 'Revertido: $tokens. La identidad $identity sigue en la bóveda.';
  }

  @override
  String scannedAgainReport(int auto, int byYou, int waiting, int normal) {
    return 'Analizado de nuevo: $auto protegidos automáticamente · $byYou por usted · $waiting necesitan su decisión · $normal normales.';
  }

  @override
  String alreadyProtectedAsTokens(String tokens) {
    return 'Ya protegido como $tokens.';
  }

  @override
  String alreadyProtectedAsFrom(String tokens, String source, String detail) {
    return 'Ya protegido como $tokens, por $source$detail.';
  }

  @override
  String get readBackPanel => 'Lectura de vuelta';

  @override
  String get whatStayedAToken => 'Lo que se quedó como marcador';

  @override
  String theSearchWasRefused(String why) {
    return 'Se rechazó la búsqueda: $why';
  }

  @override
  String get findAWordInThisDocument => 'Buscar una palabra en este documento';

  @override
  String get tabTakesIt => 'Tab la acepta';

  @override
  String get findAct => 'Buscar';

  @override
  String notInThisDocument(String word) {
    return '«$word» no está en este documento';
  }

  @override
  String countProtected(int count) {
    return '$count protegidos';
  }

  @override
  String countWaiting(int count) {
    return '$count en espera';
  }

  @override
  String countInTheClear(int count) {
    return '$count sin proteger';
  }

  @override
  String placesInsideWaitingWords(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lugares están',
      one: 'Un lugar está',
    );
    return '$_temp0 dentro de palabras que aún esperan su decisión: $list. Proteger deja esos a la revisión.';
  }

  @override
  String get goToIt => 'Ir allí';

  @override
  String get unProtectHere => 'Desproteger aquí';

  @override
  String unProtectInThisSession(int places) {
    return 'Desproteger en esta sesión ($places lugares)';
  }

  @override
  String get nothingIsWaitingForYou => 'No hay nada esperándole.';

  @override
  String thingsWaitingForYourWord(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cosas esperan su decisión.',
      one: 'Una cosa espera su decisión.',
    );
    return '$_temp0';
  }

  @override
  String get theScanFoundNothingHere =>
      'El análisis no encontró nada en este documento.';

  @override
  String get nothingIsWaitingWhatIsProtected =>
      'No hay nada en espera. Lo protegido está en el texto, marcado donde aparece.';

  @override
  String foundBySource(String source) {
    return 'encontrado por $source';
  }

  @override
  String get youDecided => 'usted decidió';

  @override
  String pageAndParagraph(int page, int paragraph) {
    return 'Página $page · ¶$paragraph';
  }

  @override
  String inPlacesCount(int count) {
    return 'en $count lugares';
  }

  @override
  String identitiesClaimIt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count identidades lo reclaman',
      one: 'Una identidad lo reclama',
    );
    return '$_temp0';
  }

  @override
  String leaveWordsInTheClearQuestion(int count) {
    return '¿Dejar $count palabras sin proteger?';
  }

  @override
  String leaveAllInTheClearExplained(int count) {
    return 'Las $count se enviarán exactamente como están escritas. Z no sustituirá ninguna de ellas, ni en este documento ni en la solicitud que sale de este equipo.';
  }

  @override
  String yesLeaveAllInTheClear(int count) {
    return 'Sí — dejar las $count sin proteger';
  }

  @override
  String get protectAll => 'Proteger todo';

  @override
  String get skipAll => 'Omitir todo';

  @override
  String get leaveIt => 'Dejarla';

  @override
  String get activeZTokens => 'Marcadores Z activos';

  @override
  String get nothingIsProtectedYetSentence => 'Todavía no hay nada protegido.';

  @override
  String valuesStandBehindTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valores están',
      one: '1 valor está',
    );
    return '$_temp0 detrás de un marcador en esta sesión.';
  }

  @override
  String get aTokenAppearsWhenProtected =>
      'Aquí aparece un marcador en cuanto algo se protege.';

  @override
  String get revealingChangesNothing =>
      'Mostrar enseña un valor en esta pantalla durante un momento. No cambia nada en la columna «Protegido» — lo que sale del dispositivo es la misma cadena antes y después.';

  @override
  String get copyTheToken => 'Copiar el marcador';

  @override
  String get scopeJustHere => 'Solo aquí';

  @override
  String get scopeThisSession => 'Esta sesión';

  @override
  String get scopeRememberedForClient => 'Recordado para este cliente';

  @override
  String get scopeRememberedEverywhere => 'Recordado en todas partes';

  @override
  String get copyReport => 'Copiar informe';

  @override
  String sessionNamesAreThisSessions(int number) {
    return 'Sesión $number · los nombres de este trabajo son de esta sesión';
  }

  @override
  String get asEachProviderIsConfigured =>
      'Según la configuración de cada proveedor';

  @override
  String get noAiConnected => 'Ninguna IA conectada';

  @override
  String get connectAnAiInSettings => 'Conecte una IA en Ajustes';

  @override
  String get chooseWhichModelAnswers => 'Elija qué modelo responde';

  @override
  String get nothingSentFromThisSessionYet =>
      'Todavía no se ha enviado nada desde esta sesión. Lo que va a un modelo y lo que vuelve se escribe aquí, en el archivo sellado propio de esta sesión.';

  @override
  String get youAsked => 'Usted preguntó';

  @override
  String get nothingWasAskedDocumentWentAlone =>
      'No se preguntó nada — el documento se envió solo.';

  @override
  String get itAnswered => 'Respondió';

  @override
  String namesBelongToAnotherSession(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count nombres de este intercambio pertenecen a otra sesión y no se pudieron restaurar: $list.',
      one:
          'Un nombre de este intercambio pertenece a otra sesión y no se pudo restaurar: $list.',
    );
    return '$_temp0';
  }

  @override
  String get andTheClipboardIsEmptySentence =>
      'No se copió nada — el portapapeles está vacío.';

  @override
  String get nothingWasPasted => 'No se pegó nada.';

  @override
  String get copyTheSafeTextFirst =>
      'Copie primero el texto protegido, para que la respuesta pueda vincularse a ese contenido protegido.';

  @override
  String profileIsInUseAgain(String name) {
    return '«$name» vuelve a estar en uso.';
  }

  @override
  String profileIsOffNamesRemain(String name) {
    return '«$name» está desactivado — sus nombres siguen aquí.';
  }

  @override
  String movedNamesToLanguage(int count, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se movieron $count nombres a $to.',
      one: 'Se movió un nombre a $to.',
    );
    return '$_temp0';
  }

  @override
  String forgotProfileAndItsNames(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nombres',
      one: '1 nombre',
    );
    return 'Se olvidó «$name» y $_temp0.';
  }

  @override
  String addedValueNamed(String value) {
    return 'Se añadió «$value».';
  }

  @override
  String forgotValueNamed(String value) {
    return 'Se olvidó «$value».';
  }

  @override
  String get afterTheVaultOpened => 'después de abrir la bóveda';

  @override
  String importAddedCount(int count) {
    return '$count añadidos';
  }

  @override
  String importAlreadyKnownCount(int count) {
    return '$count ya conocidos';
  }

  @override
  String importRefusedCount(int count) {
    return '$count rechazados';
  }

  @override
  String importValuesCount(int count) {
    return '$count valores';
  }

  @override
  String get begunNoNameNeededRenaming =>
      'Iniciada. Ningún nombre de este documento necesitaba renombrarse.';

  @override
  String get begunNoDocumentOpen =>
      'Iniciada. No hay ningún documento abierto, así que no había nada que renombrar.';

  @override
  String begunAndNamesMovedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Iniciada, y $count nombres de este documento pasaron a ella.',
      one: 'Iniciada, y un nombre de este documento pasó a ella.',
    );
    return '$_temp0';
  }

  @override
  String get theSessionWasNotBegun =>
      'La sesión no se inició, así que no se sacó nada.';

  @override
  String get closeAndOpenAgain =>
      'Cierre esto y vuelva a abrirlo — algo cambió mientras estaba abierto.';

  @override
  String get sentToAiAnswered => 'enviado a la IA · respondido';

  @override
  String get sentToAiNoAnswerYet => 'enviado a la IA · aún sin respuesta';

  @override
  String columnsNotUsedSaid(int count, String which) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'No se usaron $count columnas: $which — indique el tipo de cada una, o se quedan fuera.',
      one: 'No se usó una columna: $which — indique su tipo, o se queda fuera.',
    );
    return '$_temp0';
  }

  @override
  String get addressLabel => 'Dirección';

  @override
  String get plainHttpOnlyLoopback =>
      'Solo se acepta http sin cifrar para una dirección de bucle local literal — 127.0.0.1 o ::1. Un nombre como «localhost» se rechaza, porque entonces sería un archivo hosts el que decidiría si el texto sin cifrar es seguro.';

  @override
  String get theModelToAsk => 'el modelo al que preguntar';

  @override
  String get apiKeyLabel => 'Clave de API';

  @override
  String get pastedOnceNeverShownAgain =>
      'se pega una vez, nunca se vuelve a mostrar';

  @override
  String get thisKeyIsSealedInTheVault =>
      'Esta clave está sellada en la bóveda.';

  @override
  String get thisKeyIsInMemoryOnly =>
      'Esta clave se guarda en memoria solo para esta ejecución — desaparece al cerrar la app.';

  @override
  String get noKeyIsNeededHere =>
      'En esta dirección no se necesita ninguna clave.';

  @override
  String get noKeyYetWillSeal =>
      'Todavía no hay ninguna clave guardada. Al conectar, se sellará en la bóveda.';

  @override
  String get noKeyYetMemoryOnly =>
      'Todavía no hay ninguna clave guardada. Al conectar, se guardará en memoria solo para esta ejecución.';

  @override
  String get connectingNow => 'Conectando…';

  @override
  String get connectAct => 'Conectar';

  @override
  String get forgetTheKey => 'Olvidar la clave';

  @override
  String get disconnectAct => 'Desconectar';

  @override
  String get couldNotTellWhereDocumentsFolderIs =>
      'Z Privacy no pudo saber dónde está su carpeta de documentos, así que no la ha adivinado. No se escribió nada.';

  @override
  String thereAreAlready200Files(String stem, String into) {
    return 'Ya hay 200 archivos llamados $stem en $into.';
  }

  @override
  String couldNotWriteInto(String into, String why) {
    return 'Z Privacy no pudo escribir en $into — $why.';
  }

  @override
  String couldNotBuildThePdfBecause(String why) {
    return 'Z Privacy no pudo generar el PDF — $why. No se escribió nada.';
  }

  @override
  String get zPdfProtectedCopy => 'z-pdf · copia protegida';

  @override
  String placesReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lugares sustituidos',
      one: '1 lugar sustituido',
    );
    return '$_temp0';
  }

  @override
  String valuesOfTheseKinds(int count, String kinds) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valores ($kinds)',
      one: '1 valor ($kinds)',
    );
    return '$_temp0';
  }

  @override
  String get noKindsAtAll => 'ninguno';

  @override
  String sha256OfTheProtectedText(String digest) {
    return 'sha256 del texto protegido $digest';
  }

  @override
  String zPdfAnswerLine(String token) {
    return 'Z-pdf : $token';
  }

  @override
  String couldNotAskWhereToSaveIt(String why) {
    return 'Z Privacy no pudo abrir el diálogo de guardado de su sistema — $why. No se escribió nada.';
  }

  @override
  String get nameThisDocument => 'Ponga nombre a este documento';

  @override
  String get whatIsThisDocumentCalled => '¿Cómo se llama este documento?';

  @override
  String get theFileNameIsNotProtected =>
      'El nombre del archivo queda exactamente como lo escriba. Sale con el archivo, así que no ponga nombres reales en él.';

  @override
  String get aNameIsNeededForThisDocument =>
      'Se necesita un nombre — el archivo recibe ese nombre.';

  @override
  String get saveAsAPlainPdf => 'Guardar como PDF normal';

  @override
  String get aPlainPdfOfTheRestoredText =>
      'Esto guarda el documento de arriba con sus nombres de vuelta, como un PDF normal — sin página de respuesta, sin pie de página, nada que declare una protección. Los valores están en él sin proteger.';

  @override
  String get copyTheAddressAndWriteToUs =>
      'Copie esta dirección y escríbanos desde su propio correo electrónico. Z Privacy no abre nada ni envía nada: aquí no hay ningún formulario ni ninguna conexión con nosotros.';

  @override
  String get writeToUs => 'Escríbanos';

  @override
  String get describeTheProblemNotYourDocuments =>
      'Describa el problema, y no envíe sus documentos: lo que llega a nuestro buzón no es algo que podamos proteger. «Copiar informe», en la barra sobre su trabajo, escribe cifras sobre un documento y ninguna palabra de él.';

  @override
  String get howToUseZPrivacy => 'Cómo usar Z Privacy';

  @override
  String get theGuideOpensInYourBrowser =>
      'La página se abre en su navegador, en el idioma de esta interfaz. Nada de su documento ni de su bóveda acompaña la pulsación: su navegador pide una página al sitio, como en cualquier otra visita.';

  @override
  String get couldNotOpenYourBrowser =>
      'Z Privacy no pudo abrir su navegador. La dirección del botón se abre a mano en cualquier navegador.';

  @override
  String thisTranslationWasMadeWithAi(String subject) {
    return 'Esta traducción se ha hecho con IA. Para señalar un error, escriba a zprivacy@mono-peak.com con el asunto «$subject».';
  }

  @override
  String theCorrectionSubject(String code) {
    return 'Translation ($code)';
  }
}

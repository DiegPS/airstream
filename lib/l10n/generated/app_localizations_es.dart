// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get obsPageChatTitle => 'Chat de Airstream';

  @override
  String get obsPageAlertsTitle => 'Alertas de Airstream';

  @override
  String get obsPageCaptionsTitle => 'Subtítulos de Airstream';

  @override
  String get obsPageTimerTitle => 'Temporizador de Airstream';

  @override
  String get obsPagePollTitle => 'Encuesta de Airstream';

  @override
  String get textAndNames => 'Texto y nombres';

  @override
  String get chatFontFamily => 'Fuente tipográfica';

  @override
  String get chatFontWindows => 'Fuentes de Windows';

  @override
  String get chatFontGoogle => 'Fuentes de Google para OBS';

  @override
  String get chatFontOther => 'Otra fuente instalada';

  @override
  String get chatFontInvalid =>
      'Escribe de 1 a 48 letras (A–Z), números, espacios o guiones.';

  @override
  String get chatFontGoogleNote =>
      'La aplicación usa esta fuente si está instalada. Las páginas de OBS la descargan.';

  @override
  String get nameColorMode => 'Colores de nombres';

  @override
  String get nameColorPlatform => 'Color del espectador';

  @override
  String get nameColorPlatformThenGenerated =>
      'Color del espectador o generado';

  @override
  String get nameColorGenerated => 'Generado para todos';

  @override
  String get nameColorSingle => 'Un solo color';

  @override
  String get nameColorBrand => 'Color de marca de la plataforma';

  @override
  String get nameRoleColors => 'Colores de dueño, moderador y VIP';

  @override
  String get nameReadability => 'Mejorar la legibilidad';

  @override
  String get nameColorHex => 'Color hexadecimal';

  @override
  String get nameColorUse => 'Usar color';

  @override
  String get language => 'Idioma';

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get listeningForMessages => 'Escuchando mensajes...';

  @override
  String get channelsSavedStartPrompt =>
      'Canales guardados.\nPulsa Iniciar cuando quieras escuchar.';

  @override
  String get noChannelsConfigured =>
      'No hay canales configurados.\nConfigúralos en el menú lateral.';

  @override
  String get start => 'Iniciar';

  @override
  String get stop => 'Detener';

  @override
  String get hideSidebarTooltip => 'Ocultar menú lateral (Ctrl+B)';

  @override
  String get showSidebarTooltip => 'Mostrar menú lateral (Ctrl+B)';

  @override
  String get dashboard => 'Panel';

  @override
  String get clear => 'Limpiar';

  @override
  String get connections => 'Conexiones';

  @override
  String get youtubeInputLabel =>
      'Usuario, ID de canal, ID de video o URL de YouTube';

  @override
  String get youtubeDualMode => 'Horizontal + vertical';

  @override
  String get youtubeDualModeDescription =>
      'Conecta ambas transmisiones de YouTube al mismo tiempo';

  @override
  String get youtubeHorizontalUrl => 'URL de transmisión horizontal';

  @override
  String get youtubeVerticalUrl => 'URL de transmisión vertical';

  @override
  String get youtubeStreamUrlHint => 'https://youtube.com/watch?v=...';

  @override
  String get youtubeInvalidStreamUrl =>
      'Ingresa una URL directa de video o transmisión de YouTube';

  @override
  String get youtubeDuplicateStreamUrl => 'Usa la URL de otra transmisión';

  @override
  String get youtubeStreamBadges => 'Insignia horizontal / vertical';

  @override
  String get youtubeLiveAudience => 'Audiencia en vivo de YouTube';

  @override
  String get youtubeHorizontal => 'Horizontal';

  @override
  String get youtubeVertical => 'Vertical';

  @override
  String youtubeViewers(String count) {
    return '$count espectadores';
  }

  @override
  String youtubeTotalViewers(String count) {
    return '$count en total';
  }

  @override
  String get youtubeAudienceUnavailable => 'Audiencia no disponible';

  @override
  String get twitchChannel => 'Canal de Twitch';

  @override
  String get kickSlug => 'Identificador de Kick';

  @override
  String get startChat => 'Iniciar chat';

  @override
  String get appearance => 'Apariencia';

  @override
  String get fontSize => 'Tamaño de fuente';

  @override
  String get backgroundOpacity => 'Opacidad del fondo';

  @override
  String get bubbleOpacity => 'Opacidad de burbuja';

  @override
  String get borderRadius => 'Radio de borde';

  @override
  String get messageGap => 'Espacio entre mensajes';

  @override
  String get maxMessageWidth => 'Ancho máximo de mensaje';

  @override
  String get horizontalPadding => 'Margen horizontal';

  @override
  String get avatars => 'Avatares';

  @override
  String get platformIcon => 'Ícono de plataforma';

  @override
  String get badges => 'Insignias';

  @override
  String get timestamp => 'Hora';

  @override
  String get bubble => 'Burbuja';

  @override
  String get bubbleShadow => 'Sombra de burbuja';

  @override
  String get filters => 'Filtros';

  @override
  String get filtersDescription =>
      'Los usuarios y palabras bloqueados se eliminan del chat local, del TTS y de la superposición web.';

  @override
  String get blockedUsers => 'Usuarios bloqueados';

  @override
  String get blockedUsersHelp => 'Uno por línea. El prefijo @ es opcional.';

  @override
  String get blockedWordsOrPhrases => 'Palabras o frases bloqueadas';

  @override
  String get blockedWordsHelp =>
      'Las palabras sueltas respetan límites de token. Las frases se comparan después de normalizar.';

  @override
  String get ttsDescription =>
      'Lee mensajes del chat en voz alta con voz, idioma y comportamiento de comandos configurables.';

  @override
  String get enabled => 'Activado';

  @override
  String get membersOnly => 'Solo miembros';

  @override
  String get commandMode => 'Modo comando (prefijo personalizado)';

  @override
  String get commandPrefix => 'Prefijo del comando';

  @override
  String get commandPrefixHint => '!v';

  @override
  String get ignoreCommandCase => 'Ignorar mayúsculas/minúsculas en el prefijo';

  @override
  String get separatorText => 'Texto separador';

  @override
  String get voice => 'Voz';

  @override
  String get ttsEngine => 'Motor de voz';

  @override
  String get quality => 'Calidad';

  @override
  String get qualityFast => 'Rápida (4 pasos)';

  @override
  String get qualityHigh => 'Alta (6 pasos)';

  @override
  String get qualityBalanced => 'Equilibrada (8 pasos)';

  @override
  String get qualityMaximum => 'Máxima (12 pasos)';

  @override
  String get speed => 'Velocidad';

  @override
  String get removeTtsModel => 'Eliminar modelo descargado';

  @override
  String get downloadTtsModel => 'Descargar modelo';

  @override
  String get removeTtsModelConfirmation =>
      'El TTS se desactivará y el modelo seleccionado se eliminará de este dispositivo. Podrás descargarlo de nuevo después.';

  @override
  String removeTtsModelTitle(String model) {
    return '¿Eliminar $model?';
  }

  @override
  String removeTtsModelConfirmationNamed(String model) {
    return '$model se eliminará de este dispositivo y el TTS se desactivará. Podrás descargarlo nuevamente después.';
  }

  @override
  String get remove => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get ttsModelRemoved => 'El modelo TTS se eliminó.';

  @override
  String get ttsModelRemovalFailed => 'No se pudo eliminar el modelo TTS.';

  @override
  String get testText => 'Texto de prueba';

  @override
  String get playingTts => 'Reproduciendo TTS...';

  @override
  String get loadingTts => 'Cargando TTS...';

  @override
  String get testTts => 'Probar TTS';

  @override
  String get ttsDisabledHelp =>
      'Actívalo para configurar voz, idioma y probar la reproducción.';

  @override
  String get obsIntegration => 'Integración OBS';

  @override
  String get obsDescription =>
      'Conecta con OBS mediante WebSocket para mostrar el estado de la transmisión, la grabación y la escena dentro de AirStream.';

  @override
  String get webSocketHost => 'Servidor WebSocket';

  @override
  String get password => 'Contraseña';

  @override
  String get optionalPassword => 'Contraseña opcional';

  @override
  String get connectingToObs => 'Conectando con OBS...';

  @override
  String get disconnectObs => 'Desconectar OBS';

  @override
  String get reconnectObs => 'Reconectar OBS';

  @override
  String get connectObs => 'Conectar OBS';

  @override
  String get hudElements => 'Elementos del panel';

  @override
  String get globalHud => 'General';

  @override
  String get streamHud => 'Transmisión';

  @override
  String get recordingHud => 'Grabación';

  @override
  String get streamState => 'Estado de la transmisión';

  @override
  String get currentScene => 'Escena actual';

  @override
  String get bitrate => 'Tasa de bits';

  @override
  String get fps => 'FPS';

  @override
  String get droppedFrames => 'Fotogramas perdidos';

  @override
  String get recordingState => 'Estado de grabación';

  @override
  String get recordingDuration => 'Duración de grabación';

  @override
  String get recordingSize => 'Tamaño de grabación';

  @override
  String get obsDisabledHelp =>
      'Actívalo para ingresar el servidor, la contraseña y conectar cuando quieras.';

  @override
  String get overlayServer => 'Servidor de superposición';

  @override
  String get overlayServerDescription =>
      'Activa una fuente local de navegador para OBS. Cuando está habilitada, AirStream genera una URL de superposición que puedes pegar en OBS.';

  @override
  String get port => 'Puerto';

  @override
  String get chatObsUrl => 'URL de chat para OBS';

  @override
  String get chatObsUrlDescription =>
      'Usa este enlace como fuente de navegador para el chat en OBS.';

  @override
  String get chatOverlayUrlCopied => 'URL de la superposición del chat copiada';

  @override
  String get alertsObsUrl => 'URL de alertas para OBS';

  @override
  String get alertsObsUrlDescription =>
      'Úsalo como una fuente de navegador separada para Super Chats, membresías y los mensajes del chat que muestres en el directo.';

  @override
  String get alertsOverlayUrlCopied =>
      'URL de la superposición de alertas copiada';

  @override
  String get oneOverlayClientConnected =>
      '1 cliente de superposición conectado';

  @override
  String overlayClientsConnected(int count) {
    return '$count clientes de superposición conectados';
  }

  @override
  String get overlayReloadSent => 'Recarga de la superposición enviada';

  @override
  String get noOverlayClientConnected =>
      'No hay clientes de superposición conectados';

  @override
  String get reloadOverlay => 'Recargar superposición';

  @override
  String get alerts => 'Alertas';

  @override
  String get alertsDescription =>
      'Muestra Super Chats y membresías de YouTube, Bits, suscripciones, regalos y raids de Twitch, y suscripciones, regalos, hosts y Kicks de Kick en /alerts. Puedes desactivar cada tipo abajo.';

  @override
  String get alertFontSize => 'Tamaño de fuente de alerta';

  @override
  String get alertDuration => 'Duración de alerta';

  @override
  String get alertAvatars => 'Avatares de alerta';

  @override
  String get testAlertSent => 'Alerta de prueba enviada';

  @override
  String get openAlertsOverlayFirst =>
      'Abre primero la superposición de alertas en OBS o en el navegador';

  @override
  String get overlayMode => 'Modo de superposición';

  @override
  String get chromaKey => 'Clave de croma';

  @override
  String get showGrid => 'Mostrar cuadrícula';

  @override
  String get hideScrollbar => 'Ocultar barra de desplazamiento';

  @override
  String get chromaColor => 'Color de croma';

  @override
  String get platformDisplay => 'Visualización de plataformas';

  @override
  String get twitchAccent => 'Color distintivo de Twitch';

  @override
  String get kickAccent => 'Color distintivo de Kick';

  @override
  String get styleSettings => 'Ajustes de estilo';

  @override
  String get lineHeight => 'Altura de línea';

  @override
  String get fontWeight => 'Grosor de fuente';

  @override
  String get overlayBg => 'Fondo de la superposición';

  @override
  String get textShadow => 'Sombra de texto';

  @override
  String get textOutline => 'Contorno de texto';

  @override
  String get outlineColor => 'Color del contorno';

  @override
  String get messageDesign => 'Diseño de mensajes';

  @override
  String get bubbleBackground => 'Fondo de burbuja';

  @override
  String get textAlignment => 'Alineación de texto';

  @override
  String get cornerRadius => 'Radio de esquina';

  @override
  String get verticalGap => 'Espacio vertical';

  @override
  String get maxMessages => 'Máximo de mensajes';

  @override
  String get messageLifetime => 'Duración del mensaje';

  @override
  String get superChatColorBar => 'Barra de color SuperChat';

  @override
  String get superChatBarColor => 'Color de barra SuperChat';

  @override
  String get superChatWidth => 'Ancho SuperChat';

  @override
  String get animation => 'Animación';

  @override
  String get entrance => 'Entrada';

  @override
  String get duration => 'Duración';

  @override
  String get transform3d => 'Transformación 3D';

  @override
  String get enable3dEffect => 'Activar efecto 3D';

  @override
  String get perspective => 'Perspectiva';

  @override
  String get rotateX => 'Rotar X';

  @override
  String get rotateY => 'Rotar Y';

  @override
  String get rotateZ => 'Rotar Z';

  @override
  String get skewX => 'Inclinar X';

  @override
  String get scale => 'Escala';

  @override
  String get overlayDisabledHelp =>
      'Actívalo para elegir un puerto y mostrar la URL de OBS.';

  @override
  String get ready => 'Listo';

  @override
  String get checking => 'Comprobando';

  @override
  String get downloading => 'Descargando';

  @override
  String get loading => 'Cargando';

  @override
  String get error => 'Error';

  @override
  String get chatConnectionsFailed =>
      'AirStream no pudo conectarse a ningún chat configurado. Revisa los errores rojos de cada plataforma e inténtalo de nuevo.';

  @override
  String get retry => 'Reintentar';

  @override
  String get obsPasswordNotSaved => 'Contraseña de OBS sin guardar';

  @override
  String get youtubeBroadcastEnded => 'La transmisión de YouTube terminó';

  @override
  String get youtubePartiallyConnected =>
      'YouTube: una de las dos transmisiones no se pudo conectar';

  @override
  String retryPlatform(String platform) {
    return 'Reintentar $platform';
  }

  @override
  String get chatPartiallyConnected =>
      'Algunos chats están conectados. Revisa las plataformas marcadas en rojo.';

  @override
  String get overlayStarting => 'Iniciando el servidor local de superposición…';

  @override
  String overlayStartFailed(int port) {
    return 'No se pudo iniciar el servidor de superposición en el puerto $port. Es posible que el puerto esté ocupado o bloqueado.';
  }

  @override
  String get invalidOverlayPort => 'Introduce un puerto entre 1 y 65535.';

  @override
  String get ttsPlaybackFailed =>
      'No se pudo generar o reproducir la voz. Revisa el modelo seleccionado y la salida de audio.';

  @override
  String get voiceCommandFailed =>
      'No se pudo completar el comando de voz. Revisa la conexión con OBS e inténtalo de nuevo.';

  @override
  String get idle => 'Inactivo';

  @override
  String assetsProgress(int loaded, int total) {
    return '$loaded/$total archivos';
  }

  @override
  String currentFile(String file) {
    return 'Actual: $file';
  }

  @override
  String voiceStatus(String voice) {
    return 'Voz: $voice';
  }

  @override
  String maleVoice(String number) {
    return 'Masculina $number';
  }

  @override
  String femaleVoice(String number) {
    return 'Femenina $number';
  }

  @override
  String platformError(String platform, String error) {
    return 'Error de $platform: $error';
  }

  @override
  String get copy => 'Copiar';

  @override
  String get testAlerts => 'Probar alertas';

  @override
  String get superChat => 'SuperChat';

  @override
  String get noMessage => 'Sin mensaje';

  @override
  String get member => 'Miembro';

  @override
  String get voiceCloning => 'Clonación de voz (WAV)';

  @override
  String usingBundledVoice(String voice) {
    return 'Usando muestra incluida: $voice';
  }

  @override
  String get chooseWav => 'Elegir WAV';

  @override
  String voiceReferenceTooLarge(int limitMiB) {
    return 'Elige un archivo WAV de referencia de hasta $limitMiB MiB.';
  }

  @override
  String get voiceReferenceUnreadable =>
      'No se pudo leer el WAV de referencia. Elige otro archivo.';

  @override
  String get useBundledSample => 'Usar muestra incluida';

  @override
  String get referenceTranscript => 'Transcripción exacta del WAV';

  @override
  String get referenceTranscriptHint =>
      'Escribe exactamente lo que dice el audio…';

  @override
  String get localCaptions => 'Subtítulos locales';

  @override
  String get captionsDescription =>
      'Escucha el micrófono, detecta la voz y crea subtítulos o traducción en tiempo real sin enviar audio a Internet.';

  @override
  String get captionsEnabled => 'Activados';

  @override
  String get spokenLanguage => 'Idioma hablado';

  @override
  String get captionOutput => 'Salida / traducción';

  @override
  String get sendCaptionsToObs => 'Enviar a la superposición de OBS';

  @override
  String get noiseReduction => 'Reducir el ruido de fondo del micrófono';

  @override
  String get voiceCommandsObs => 'Comandos de voz para OBS';

  @override
  String get wakeWord => 'Palabra de activación';

  @override
  String get voiceCommandsExamples =>
      'Ejemplos: “Airstream inicia grabación”, “Airstream pausa grabación” o “Airstream cambia a escena cámara”. También en alemán y francés, por ejemplo «Airstream démarre l\'enregistrement».';

  @override
  String get voiceCommandsTranslationNote =>
      'Con la traducción de subtítulos activa, los comandos se leen del texto traducido. Los de grabación funcionan en español, inglés, alemán y francés; el nombre de una escena puede salir traducido.';

  @override
  String get captionModelManual => 'Subtítulos sin conexión · descarga manual';

  @override
  String get downloadCaptionModel => 'Descargar modelo de subtítulos';

  @override
  String get captionStatusIdle =>
      'Los subtítulos sin conexión están desactivados.';

  @override
  String get captionStatusMissingModel =>
      'Descarga el reconocimiento de voz para comenzar.';

  @override
  String get captionStatusDownloading =>
      'Descargando el reconocimiento de voz sin conexión…';

  @override
  String get captionStatusLoading =>
      'Preparando el reconocimiento de voz sin conexión…';

  @override
  String get captionStatusListening => 'Escuchando el micrófono…';

  @override
  String get captionStatusTranscribing => 'Creando subtítulos localmente…';

  @override
  String get captionStatusError =>
      'No se pudieron iniciar los subtítulos sin conexión.';

  @override
  String get obsCaptions => 'Subtítulos OBS';

  @override
  String get obsCaptionsDescription =>
      'Fuente de navegador independiente para subtítulos y traducción en vivo.';

  @override
  String get ttsAndVoice => 'TTS y voz';

  @override
  String get obsAndOverlay => 'OBS y superposición';

  @override
  String get systemTab => 'Sistema y ventana';

  @override
  String get desktopWindow => 'Ventana de escritorio';

  @override
  String get clickThrough => 'Ignorar clics';

  @override
  String get clickThroughDescription =>
      'Los clics llegan a la ventana que está detrás de Airstream. Pulsa Ctrl+Shift+C para desactivarlo.';

  @override
  String get alwaysOnTop => 'Siempre visible';

  @override
  String get alwaysOnTopDescription =>
      'Mantener sobre todas las demás ventanas';

  @override
  String get antiCapture => 'Protección de captura / Privacidad';

  @override
  String get antiCaptureDescription =>
      'Ocultar la ventana de capturas de pantalla y OBS';

  @override
  String get keyboardShortcuts => 'Atajos de teclado';

  @override
  String get toggleTopBarShortcut => 'Mostrar / Ocultar barra superior';

  @override
  String get toggleAlwaysOnTopShortcut => 'Alternar Siempre visible';

  @override
  String get toggleClickThroughShortcut => 'Alternar ignorar clics';

  @override
  String get globalClickThroughShortcutUnavailable =>
      'Para desactivar Ignorar clics hace falta Ctrl+Shift+C, y otra aplicación usa ese atajo. Ciérrala e inténtalo de nuevo.';

  @override
  String get alwaysOnTopActiveTooltip =>
      'Desactivar Siempre visible (Ctrl+Shift+P)';

  @override
  String get alwaysOnTopInactiveTooltip => 'Siempre visible (Ctrl+Shift+P)';

  @override
  String get clickThroughActiveTooltip =>
      'Ignorar clics está activo. Desactivar (Ctrl+Shift+C)';

  @override
  String get clickThroughInactiveTooltip =>
      'Activar ignorar clics (Ctrl+Shift+C)';

  @override
  String get antiCaptureActiveTooltip =>
      'Modo privacidad activo — ventana oculta de capturas/OBS';

  @override
  String get antiCaptureInactiveTooltip =>
      'Ocultar de capturas y pantalla compartida';

  @override
  String get minimize => 'Minimizar';

  @override
  String get maximize => 'Maximizar';

  @override
  String get restore => 'Restaurar';

  @override
  String get close => 'Cerrar';

  @override
  String get obsStatusConnecting => 'OBS: Conectando...';

  @override
  String get obsStatusDisconnected => 'OBS: Desconectado';

  @override
  String get obsStatusLiveAndRec => 'OBS: En vivo + Grabando';

  @override
  String get obsStatusLive => 'OBS: En vivo';

  @override
  String get obsStatusRecording => 'OBS: Grabando';

  @override
  String get obsStatusConnected => 'OBS: Conectado';

  @override
  String obsScenePrefix(String scene) {
    return 'Escena: $scene';
  }

  @override
  String get obsOutputLive => 'Salida: En vivo';

  @override
  String get obsOutputOffline => 'Salida: Fuera de línea';

  @override
  String get obsRecordingPaused => 'Grabación: Pausada';

  @override
  String get obsRecordingActive => 'Grabación: Activa';

  @override
  String get ttsCardTitle => 'Lector de voz (TTS)';

  @override
  String voiceStatusBadge(String status) {
    return 'Voz: $status';
  }

  @override
  String get voiceStatusNotDownloaded => 'Sin descargar';

  @override
  String get ttsSelectedModel => 'TTS';

  @override
  String ttsModelStatusBadge(String model, String status) {
    return '$model · $status';
  }

  @override
  String ttsModelTechnicalDetails(
      String download, String installed, String license, String version) {
    return 'Descarga $download · Instalado $installed · $license · Versión $version';
  }

  @override
  String ttsModelStorageDetails(String download, String installed) {
    return 'Descarga $download · Espacio en disco $installed';
  }

  @override
  String ttsModelVariant(String variant) {
    return 'Variante: $variant';
  }

  @override
  String get ttsModelSupertonicDescription =>
      '10 voces incluidas optimizadas para calidad y velocidad.';

  @override
  String get ttsModelPiperMexicoDescription =>
      'Síntesis rápida y eficiente con una sola voz.';

  @override
  String get ttsModelPiperSpainDescription =>
      'Síntesis rápida y eficiente con una sola voz.';

  @override
  String get ttsModelKittenDescription =>
      'Modelo compacto con cuatro voces femeninas y cuatro masculinas.';

  @override
  String get ttsModelKokoroDescription =>
      'Modelo expresivo con 11 voces identificadas.';

  @override
  String get ttsModelMatchaDescription =>
      'Síntesis suave y natural con una sola voz.';

  @override
  String get ttsModelPocketDescription =>
      'Clonación rápida de voz a partir de un WAV de referencia.';

  @override
  String get ttsModelZipVoiceDescription =>
      'Clonación avanzada mediante un WAV y su transcripción exacta.';

  @override
  String get spanishMexico => 'Español (México)';

  @override
  String get spanishSpain => 'Español (España)';

  @override
  String get ttsStatusIdleDescription =>
      'Descarga este modelo exacto cuando quieras utilizarlo.';

  @override
  String get ttsStatusCheckingDescription =>
      'Verificando los archivos locales y su integridad…';

  @override
  String get ttsStatusDownloadingDescription =>
      'Descargando archivos de modelo verificados…';

  @override
  String get ttsStatusLoadingDescription =>
      'Cargando el modelo seleccionado en memoria…';

  @override
  String get ttsStatusReadyDescription => 'Listo para síntesis local.';

  @override
  String get ttsStatusErrorDescription =>
      'No se pudo preparar el modelo seleccionado.';

  @override
  String ttsInferenceSteps(int count) {
    return '$count pasos de inferencia';
  }

  @override
  String get ttsTestTextHint => 'Escribe algo para probar el TTS seleccionado…';

  @override
  String get ttsDefaultTestText =>
      'Hola, esta es una prueba de la voz seleccionada.';

  @override
  String get separatorTextHint => 'dice';

  @override
  String get male => 'Masculina';

  @override
  String get female => 'Femenina';

  @override
  String get includedSample => 'Muestra incluida';

  @override
  String get youtubeInputHint => '@usuario · ID de canal · ID de video';

  @override
  String get channelNameHint => 'nombre_del_canal';

  @override
  String get channelIdentifierHint => 'identificador_del_canal';

  @override
  String get blockedUsersHint => '@nightbot\n@otro_usuario';

  @override
  String get blockedWordsHint => 'palabra\nfrase completa';

  @override
  String get chatError => 'No se pudieron cargar los mensajes del chat.';

  @override
  String platformConnectionFailed(String platform) {
    return 'No se pudo conectar con $platform. Revisa el canal y tu conexión a Internet.';
  }

  @override
  String get obsConnectionProblem =>
      'OBS no pudo completar la acción solicitada. Revisa la configuración de conexión.';

  @override
  String get defaultVoice => 'Predeterminada';

  @override
  String get newsVoice => 'Voz de noticias';

  @override
  String newsVoiceNumber(int number) {
    return 'Voz de noticias $number';
  }

  @override
  String get alignmentLeft => 'Izquierda';

  @override
  String get alignmentCenter => 'Centro';

  @override
  String get alignmentRight => 'Derecha';

  @override
  String get animationSlideUp => 'Deslizar hacia arriba';

  @override
  String get animationSlideLeft => 'Deslizar desde la derecha';

  @override
  String get animationFadeIn => 'Aparecer gradualmente';

  @override
  String get animationZoomIn => 'Acercar';

  @override
  String droppedFramesBadge(String percentage, int count) {
    return 'PERDIDOS $percentage% ($count)';
  }

  @override
  String get badgeOwner => 'DUEÑO';

  @override
  String get badgeModerator => 'MOD';

  @override
  String get badgeMember => 'MIEMBRO';

  @override
  String get badgeSubscriber => 'SUB';

  @override
  String get badgeVerified => 'VERIFICADO';

  @override
  String get badgeFirstMessage => 'PRIMER MENSAJE';

  @override
  String get badgeReturningChatter => 'HA VUELTO';

  @override
  String get badgeReward => 'RECOMPENSA';

  @override
  String get newSubscriberEvent => '¡Nuevo suscriptor!';

  @override
  String resubscriptionEvent(int months) {
    return 'Se resuscribió por $months meses';
  }

  @override
  String get giftSubscriptionEvent => 'Suscripción regalada';

  @override
  String get subscriptionUpdateEvent => 'Actualización de suscripción';

  @override
  String get membershipUpdateEvent => 'Actualización de membresía';

  @override
  String get chatSharedSource => 'COMPARTIDO';

  @override
  String get chatEventRaid => 'Raid';

  @override
  String get chatEventUnraid => 'Raid finalizado';

  @override
  String get chatEventPinnedMessage => 'Mensaje fijado';

  @override
  String get chatEventUnpinnedMessage => 'Mensaje desfijado';

  @override
  String get chatEventPoll => 'Encuesta';

  @override
  String get chatEventReward => 'Recompensa';

  @override
  String get chatEventSupport => 'Apoyo';

  @override
  String get chatEventHost => 'Alojamiento';

  @override
  String get chatEventGoal => 'Meta';

  @override
  String get chatEventNotice => 'Aviso';

  @override
  String get chatEventModiversary => 'Aniversario de moderador';

  @override
  String get chatEventViewerMilestone => 'Hito de audiencia';

  @override
  String get chatEventWatchStreak => 'Racha de visualización';

  @override
  String get chatEventSharedChat => 'Chat compartido';

  @override
  String get chatEventRoomState => 'Configuración del chat actualizada';

  @override
  String get chatEventStreamOnline => 'Transmisión iniciada';

  @override
  String get chatEventStreamOffline => 'Transmisión finalizada';

  @override
  String get eventBanners => 'Banners de eventos';

  @override
  String get eventBannersDescription =>
      'Elige qué avisos de las plataformas (raids, encuestas, mensajes fijados…) aparecen sobre el chat.';

  @override
  String get eventBannerDuration => 'Tiempo visible';

  @override
  String get chatEventUnknown => 'Evento';

  @override
  String get chatRoomEmoteOnly => 'Solo emotes';

  @override
  String chatRoomFollowersOnly(int minutes) {
    return 'Seguidores $minutes min';
  }

  @override
  String get chatRoomUnique => 'Chat único';

  @override
  String chatRoomSlowMode(int seconds) {
    return 'Modo lento $seconds s';
  }

  @override
  String get chatRoomSubscribersOnly => 'Solo suscriptores';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get languageBulgarian => 'Búlgaro';

  @override
  String get languageChinese => 'Chino';

  @override
  String get languageCroatian => 'Croata';

  @override
  String get languageCzech => 'Checo';

  @override
  String get languageDanish => 'Danés';

  @override
  String get languageDutch => 'Neerlandés';

  @override
  String get languageEstonian => 'Estonio';

  @override
  String get languageFinnish => 'Finés';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get languageGreek => 'Griego';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageHungarian => 'Húngaro';

  @override
  String get languageIndonesian => 'Indonesio';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageJapanese => 'Japonés';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languageLatvian => 'Letón';

  @override
  String get languageLithuanian => 'Lituano';

  @override
  String get languagePolish => 'Polaco';

  @override
  String get languagePortuguese => 'Portugués';

  @override
  String get languageRomanian => 'Rumano';

  @override
  String get languageRussian => 'Ruso';

  @override
  String get languageSlovak => 'Eslovaco';

  @override
  String get languageSlovenian => 'Esloveno';

  @override
  String get languageSwedish => 'Sueco';

  @override
  String get languageTurkish => 'Turco';

  @override
  String get languageUkrainian => 'Ucraniano';

  @override
  String get languageVietnamese => 'Vietnamita';

  @override
  String get noChannelsConfiguredMenuHidden =>
      'Todavía no hay canales configurados.';

  @override
  String get configureChannels => 'Configurar canales';

  @override
  String platformStatusConnected(String platform) {
    return '$platform: conectado';
  }

  @override
  String platformStatusConnecting(String platform) {
    return '$platform: conectando…';
  }

  @override
  String platformStatusIdle(String platform) {
    return '$platform: sin conectar';
  }

  @override
  String get clickThroughEnabledNotice =>
      'Ignorar clics activado: los clics llegan a la ventana de detrás. Pulsa Ctrl+Shift+C para desactivarlo.';

  @override
  String newChatMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes nuevos',
      one: '1 mensaje nuevo',
    );
    return '$_temp0';
  }

  @override
  String get silenceTts => 'Silenciar TTS (salta este mensaje y la cola)';

  @override
  String get youtubeWaitingForLive =>
      'Esperando a que empiece el directo de YouTube…';

  @override
  String get youtubeWaitingForLiveDetail =>
      'El canal todavía no está en directo. Airstream vuelve a comprobarlo cada 30 segundos.';

  @override
  String get connectChatOnLaunch => 'Iniciar el chat al abrir Airstream';

  @override
  String get obsConnectOnLaunch => 'Conectar a OBS al abrir Airstream';

  @override
  String get chatPreview => 'Vista previa';

  @override
  String get chatPreviewDescription =>
      'Muestra mensajes de ejemplo en el chat y en la superposición de OBS para probar estilos. Desaparecen al iniciar el chat.';

  @override
  String overlayPortFallback(int requested, int port) {
    return 'Otra aplicación usa el puerto $requested, así que la superposición usa el $port. Las URL de OBS de abajo ya lo incluyen.';
  }

  @override
  String get chatPreviewSwitch => 'Mostrar mensajes de ejemplo';

  @override
  String get highlights => 'Resaltados';

  @override
  String get highlightsDescription =>
      'Destaca en el chat de Airstream las menciones a tu canal y las palabras que elijas.';

  @override
  String get highlightMentions => 'Menciones a mi canal';

  @override
  String get highlightMentionsDescription =>
      'Mensajes que nombran tu canal de Twitch o Kick o tu @nombre de YouTube.';

  @override
  String get highlightWords => 'Palabras a resaltar';

  @override
  String get highlightWordsHint => 'Una palabra o frase por línea';

  @override
  String get highlightWordsHelp =>
      'Palabras completas; da igual mayúsculas o minúsculas.';

  @override
  String get highlightSound => 'Sonidos de resaltado';

  @override
  String get highlightSoundDescription =>
      'Los sonidos se reproducen como mucho una vez cada 3 segundos. Se silencian mientras habla el lector de voz.';

  @override
  String get badgeFirstInSession => 'Primer mensaje en el directo';

  @override
  String get highlightFirstMessages => 'Primer mensaje de cada persona';

  @override
  String get highlightFirstMessagesDescription =>
      'Marca el primer mensaje que envía cada persona desde que inicias el chat, para darle la bienvenida.';

  @override
  String get ttsUserCooldown => 'Pausa por persona';

  @override
  String get ttsUserCooldownHelp =>
      'Tras leer un mensaje, los siguientes de la misma persona esperan este tiempo. 0 s lo desactiva.';

  @override
  String get ttsMaxCharacters => 'Mensaje más largo que se lee';

  @override
  String get ttsIgnoredUsers => 'Usuarios que el lector de voz ignora';

  @override
  String get ttsIgnoredUsersHint => 'Uno por línea, por ejemplo nightbot';

  @override
  String get chatFilterTooltip =>
      'Filtrar el chat de Airstream (OBS sigue mostrando todo)';

  @override
  String get chatFilterPlatforms => 'Plataformas';

  @override
  String get chatFilterShowOnly => 'Mostrar';

  @override
  String get chatFilterAll => 'Todos los mensajes';

  @override
  String get chatFilterMembers => 'Solo miembros y suscriptores';

  @override
  String get chatFilterModerators => 'Solo moderadores';

  @override
  String get chatFilterHighlighted => 'Solo resaltados';

  @override
  String chatFilterActive(String filters) {
    return 'Mostrando: $filters';
  }

  @override
  String get chatFilterShowAll => 'Ver todo';

  @override
  String get chatFilterNoMatches =>
      'Ningún mensaje coincide con el filtro todavía.';

  @override
  String get messageShowOnStream => 'Mostrar en el directo';

  @override
  String get messageShowOnStreamNeedsOverlay =>
      'Activa el servidor de superposición y añade la URL de alertas a OBS';

  @override
  String get messageSentToOverlay => 'Enviado a la página de alertas de OBS';

  @override
  String get messageOverlayDisconnected =>
      'OBS cerró la página de alertas antes de mostrar el mensaje';

  @override
  String get messageNoAlertsOverlay =>
      'Abre la página de destacados o de alertas como fuente de navegador en OBS.';

  @override
  String get messageOverlayUnconfirmed =>
      'Enviado, pero OBS no confirmó que se mostrara';

  @override
  String get messageShownOnStream => 'Mostrado en el directo';

  @override
  String get messageCopy => 'Copiar mensaje';

  @override
  String get messageCopied => 'Mensaje copiado';

  @override
  String get pollTitle => 'Encuesta';

  @override
  String get pollDescription =>
      'Haz una pregunta en todos tus chats y elige cómo se vota.';

  @override
  String get pollMode => 'Modo de votación';

  @override
  String get pollModeNumbered => 'Numerada';

  @override
  String get pollModeWord => 'Por palabra';

  @override
  String get pollModeYesNo => 'Sí / No';

  @override
  String get pollModeRating => 'Valoración del 1 al 10';

  @override
  String get pollModeFreeAnswer => 'Respuesta libre';

  @override
  String get pollYes => 'Sí';

  @override
  String get pollNo => 'No';

  @override
  String get pollOptions => 'Opciones de votación';

  @override
  String get pollAllowed => 'Quién puede votar';

  @override
  String get pollAllowChange => 'Permitir cambiar el voto';

  @override
  String get pollHideResults => 'Ocultar resultados hasta el final';

  @override
  String get pollResultsHidden => 'Resultados al final';

  @override
  String get pollResultsHiddenOnPages =>
      'Los resultados se ocultan en las páginas hasta que termine la encuesta.';

  @override
  String get pollCommand => 'Comando de respuesta';

  @override
  String get pollInvalidCommand =>
      'Escribe un comando como !r que no esté reservado por la lista de turnos.';

  @override
  String get pollAmbiguousOptions =>
      'Escribe opciones que se distingan sin tildes, mayúsculas ni espacios de más.';

  @override
  String get pollOptionTooLong => 'Cada opción admite hasta 40 caracteres.';

  @override
  String get pollInvalidInput =>
      'Escribe una pregunta y completa al menos dos opciones si el modo lo requiere.';

  @override
  String get pollAverage => 'Promedio';

  @override
  String get pollDistinctAnswers => 'Respuestas distintas';

  @override
  String get pollHowToVote => 'Escribe en el chat';

  @override
  String get pollAnswerExample => 'tu respuesta';

  @override
  String get pollNoAnswers => 'Todavía no hay respuestas';

  @override
  String get galleryPollDescription =>
      'Muestra cómo votar, el recuento en directo y los resultados finales.';

  @override
  String get pollQuestionHint => 'Pregunta';

  @override
  String pollOptionHint(int number) {
    return 'Opción $number';
  }

  @override
  String get pollAddOption => 'Añadir opción';

  @override
  String get pollRemoveOption => 'Quitar opción';

  @override
  String get pollNoTimeLimit => 'Sin límite de tiempo';

  @override
  String pollMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get pollStart => 'Iniciar encuesta';

  @override
  String get pollEnd => 'Terminar encuesta';

  @override
  String get pollNew => 'Nueva encuesta';

  @override
  String get pollOpen => 'Votación abierta';

  @override
  String get pollClosed => 'Resultados finales';

  @override
  String pollSecondsLeft(int seconds) {
    return 'Quedan $seconds s';
  }

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
    );
    return '$_temp0';
  }

  @override
  String get pollOverlayOff =>
      'Activa el servidor de superposición para mostrarlo en OBS.';

  @override
  String pollOverlayUrl(String url) {
    return 'Añade $url a OBS como fuente de navegador para mostrarla.';
  }

  @override
  String get pollOverlayUrlCopied => 'URL de la encuesta copiada';

  @override
  String get copyUrl => 'Copiar URL';

  @override
  String get pollDuration => 'Duración';

  @override
  String get sessionSummary => 'Resumen de la sesión';

  @override
  String get sessionSummaryEmpty =>
      'Inicia el chat: el resumen reúne mensajes, personas y apoyos hasta que lo detengas.';

  @override
  String sessionSummaryLine(String duration, int messages, int chatters) {
    return '$duration · $messages mensajes · $chatters personas escribieron';
  }

  @override
  String get sessionDuration => 'Duración';

  @override
  String sessionDurationHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String sessionDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionMessagesLabel => 'Mensajes';

  @override
  String sessionMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes',
      one: '1 mensaje',
    );
    return '$_temp0';
  }

  @override
  String get sessionChatters => 'Personas que escribieron';

  @override
  String get sessionTopChatters => 'Más activos';

  @override
  String get sessionSupporters => 'Apoyos';

  @override
  String get sessionNoSupporters =>
      'Esta vez no hubo Super Chats, miembros ni raids.';

  @override
  String sessionSupportSuperChat(String name, String amount) {
    return '$name envió un Super Chat de $amount';
  }

  @override
  String sessionSupportBits(String name, String amount) {
    return '$name envió $amount';
  }

  @override
  String sessionSupportMember(String name, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$name: $months meses como miembro',
      one: '$name se hizo miembro',
    );
    return '$_temp0';
  }

  @override
  String sessionSupportSubscription(String name, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$name: $months meses suscrito',
      one: '$name se suscribió',
    );
    return '$_temp0';
  }

  @override
  String sessionSupportGift(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name regaló $count suscripciones',
      one: '$name regaló una suscripción',
    );
    return '$_temp0';
  }

  @override
  String sessionSupportGiftMembership(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name regaló $count membresías',
      one: '$name regaló una membresía',
    );
    return '$_temp0';
  }

  @override
  String sessionSupportRaid(String name, int count) {
    return '$name hizo una raid con $count espectadores';
  }

  @override
  String sessionSupportOther(String name) {
    return '$name envió un regalo';
  }

  @override
  String get sessionSummaryCopy => 'Copiar resumen';

  @override
  String get sessionSummaryCopied => 'Resumen copiado';

  @override
  String get profilesTitle => 'Perfiles';

  @override
  String get profilesDescription =>
      'Guarda tu configuración para cada tipo de directo y cámbiala con un clic. Los perfiles guardan estilo, lector de voz, superposición y resaltados; tus canales y OBS no cambian.';

  @override
  String get profilesEmpty => 'Todavía no hay perfiles.';

  @override
  String get profileNameHint => 'Nombre del perfil, por ejemplo Juegos';

  @override
  String get profileSave => 'Guardar';

  @override
  String get profileApply => 'Aplicar';

  @override
  String get profileDelete => 'Borrar perfil';

  @override
  String profileSaved(String name) {
    return 'Perfil \"$name\" guardado';
  }

  @override
  String profileApplied(String name) {
    return 'Perfil \"$name\" aplicado';
  }

  @override
  String get settingsBackupTitle => 'Copia de seguridad';

  @override
  String get settingsBackupDescription =>
      'Guarda todos los ajustes en un archivo, recupéralos en otro equipo o vuelve a los valores de fábrica. La contraseña de OBS nunca se guarda en el archivo.';

  @override
  String get settingsExport => 'Exportar';

  @override
  String get settingsImport => 'Importar';

  @override
  String get settingsReset => 'Restablecer';

  @override
  String get settingsExported => 'Ajustes exportados';

  @override
  String get settingsExportFailed =>
      'No se pudieron guardar los ajustes en ese archivo.';

  @override
  String get settingsImported => 'Ajustes importados';

  @override
  String get settingsImportFailed =>
      'Ese archivo no es un archivo de ajustes de Airstream.';

  @override
  String get settingsResetTitle => '¿Restablecer los ajustes?';

  @override
  String get settingsResetConfirmation =>
      'El estilo, el lector de voz, la superposición, los resaltados y lo demás vuelven a sus valores de fábrica. Tus canales, la conexión con OBS, el idioma y los perfiles se conservan.';

  @override
  String get settingsResetDone => 'Ajustes restablecidos';

  @override
  String get chatSearch => 'Buscar en el chat';

  @override
  String get chatSearchHint => 'Buscar mensajes o nombres';

  @override
  String get chatSearchClose => 'Cerrar búsqueda';

  @override
  String get chatLogTitle => 'Registro del chat';

  @override
  String get chatLogSave => 'Guardar el chat de cada sesión';

  @override
  String get chatLogDescription =>
      'Escribe cada mensaje en un archivo de texto en Documentos\\Airstream\\Chat mientras el chat está activo.';

  @override
  String get chatLogOpenFolder => 'Abrir carpeta';

  @override
  String get globalShortcutsTitle => 'Atajos globales';

  @override
  String get globalShortcutsDescription =>
      'Funcionan desde cualquier aplicación, por ejemplo durante una partida. Cada uno está desactivado hasta que lo asignes, para no quitarle atajos a otras aplicaciones.';

  @override
  String get globalShortcutSilenceTts => 'Silenciar el lector de voz';

  @override
  String get globalShortcutToggleTts => 'Activar o desactivar el lector de voz';

  @override
  String get globalShortcutNone => 'Asignar';

  @override
  String get globalShortcutPress => 'Pulsa las teclas…';

  @override
  String get globalShortcutClear => 'Quitar atajo';

  @override
  String get globalShortcutNeedsModifier =>
      'Usa Ctrl, Alt o Win junto con la tecla.';

  @override
  String get globalShortcutReserved =>
      'Ctrl + Shift + C está reservado para ignorar clics.';

  @override
  String get globalShortcutDuplicate => 'Otra acción ya usa este atajo.';

  @override
  String get globalShortcutInUse =>
      'Otra aplicación ya usa este atajo; elige otro.';

  @override
  String get alertTypes => 'Tipos de alerta';

  @override
  String get alertTypeSuperChat => 'Super Chats de YouTube';

  @override
  String get alertTypeMembership => 'Nuevos miembros de YouTube';

  @override
  String get alertTypeBits => 'Bits de Twitch';

  @override
  String get alertTypeSubscription => 'Suscripciones (Twitch y Kick)';

  @override
  String get alertTypeGift => 'Suscripciones y membresías regaladas';

  @override
  String get alertTypeRaid => 'Raids y hosts';

  @override
  String get alertTypeKicks => 'Kicks de Kick';

  @override
  String get testAlertBits => 'Bits';

  @override
  String get testAlertSubscription => 'Suscripción';

  @override
  String get testAlertGift => 'Regalo';

  @override
  String get testAlertRaid => 'Raid';

  @override
  String get testAlertKicks => 'Kicks';

  @override
  String get overlayStylePresetsTitle => 'Estilos listos';

  @override
  String get overlayStylePresetsDescription =>
      'Un toque cambia cómo se ven el chat y las alertas en OBS. Tus conexiones y demás ajustes no cambian.';

  @override
  String get overlayStyleCustom => 'Estilo personalizado';

  @override
  String overlayStyleApplied(String name) {
    return 'Estilo «$name» aplicado';
  }

  @override
  String get overlayStyleUndo => 'Deshacer';

  @override
  String get overlayStylePreviewHint =>
      'Activa la vista previa para verlo con mensajes de ejemplo.';

  @override
  String get overlayStyleClassic => 'Clásico';

  @override
  String get overlayStyleClassicDescription =>
      'El aspecto de siempre de Airstream.';

  @override
  String get overlayStyleCompactGaming => 'Compacto para juegos';

  @override
  String get overlayStyleCompactGamingDescription =>
      'Mensajes pequeños y juntos que tapan poco el juego.';

  @override
  String get overlayStyleBigBubbles => 'Burbujas grandes';

  @override
  String get overlayStyleBigBubblesDescription =>
      'Texto grande en burbujas redondeadas, fácil de leer.';

  @override
  String get overlayStyleCleanTransparent => 'Transparente minimalista';

  @override
  String get overlayStyleCleanTransparentDescription =>
      'Sin burbujas: texto con contorno sobre tu escena.';

  @override
  String get overlayStyleVertical => 'Vertical';

  @override
  String get overlayStyleVerticalDescription =>
      'Pensado para directos verticales como Shorts o TikTok.';

  @override
  String get alertPosition => 'Posición';

  @override
  String get alertPositionTop => 'Arriba';

  @override
  String get alertPositionCenter => 'Centro';

  @override
  String get alertPositionBottom => 'Abajo';

  @override
  String get alertLayout => 'Disposición';

  @override
  String get alertLayoutRow => 'Horizontal';

  @override
  String get alertLayoutStacked => 'Vertical';

  @override
  String get alertEntrance => 'Entrada';

  @override
  String get alertAnimationPop => 'Emergente';

  @override
  String get alertAnimationSlideUp => 'Subir';

  @override
  String get alertAnimationSlideDown => 'Bajar';

  @override
  String get alertAnimationFade => 'Aparecer';

  @override
  String get alertAnimationZoom => 'Zoom';

  @override
  String get alertTypeOptions => 'Opciones de este tipo';

  @override
  String get alertTypeOwnDuration => 'Duración propia';

  @override
  String get alertTypeUseGeneral => 'Usar la general';

  @override
  String get alertTypeCustomized => 'Personalizado';

  @override
  String get alertSound => 'Sonido';

  @override
  String get alertSoundNone => 'Sin sonido';

  @override
  String get alertSoundChime => 'Campanilla';

  @override
  String get alertSoundCoin => 'Moneda';

  @override
  String get alertSoundFanfare => 'Fanfarria';

  @override
  String get alertSoundCustom => 'Archivo propio';

  @override
  String get alertSoundChoose => 'Elegir…';

  @override
  String get alertSoundNoFile => 'Ningún archivo elegido';

  @override
  String get alertSoundInvalid =>
      'Usa un archivo WAV, MP3 u OGG de hasta 5 MB.';

  @override
  String get alertSoundVolume => 'Volumen de los sonidos de alerta';

  @override
  String get alertSoundObsHint =>
      'Los sonidos se reproducen desde la página de alertas. En OBS, activa «Controlar audio mediante OBS» en esa fuente de navegador para que tu audiencia los oiga.';

  @override
  String get alertTypeTest => 'Probar';

  @override
  String get recentAlertsAnonymousViewer => 'Alguien';

  @override
  String get recentAlertsTitle => 'Alertas recientes';

  @override
  String get recentAlertsDescription =>
      'Los apoyos de esta sesión que salieron en el directo. Puedes volver a mostrar cualquiera.';

  @override
  String get recentAlertsEmpty => 'Las alertas de esta sesión aparecerán aquí.';

  @override
  String get recentAlertsReplay => 'Volver a mostrar en el directo';

  @override
  String get recentAlertsReplayed =>
      'Repetición enviada a la página de alertas. Sale cuando le toque en la cola.';

  @override
  String get recentAlertsMember => 'Nuevo miembro';

  @override
  String get recentAlertsSubscription => 'Suscripción';

  @override
  String recentAlertsMonths(int count) {
    return '$count meses';
  }

  @override
  String recentAlertsGifted(int count) {
    return '$count regaladas';
  }

  @override
  String get recentAlertsRaid => 'Raid';

  @override
  String get recentAlertsHost => 'Host';

  @override
  String recentAlertsRaidViewers(int count) {
    return 'Raid · $count espectadores';
  }

  @override
  String recentAlertsHostViewers(int count) {
    return 'Host · $count espectadores';
  }

  @override
  String recentAlertsKicks(int count) {
    return '$count Kicks';
  }

  @override
  String get diagnosticsTitle => 'Diagnóstico';

  @override
  String get diagnosticsCopy => 'Copiar informe';

  @override
  String get diagnosticsCopied => 'Informe copiado';

  @override
  String get diagnosticsLogs => 'Abrir carpeta de registros';

  @override
  String get diagnosticsLogsFailed =>
      'No se pudo abrir la carpeta de registros';

  @override
  String diagnosticsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cosas necesitan atención',
      one: '1 cosa necesita atención',
      zero: 'Todo funciona bien',
    );
    return '$_temp0';
  }

  @override
  String diagnosticsMessage(String kind, String value) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'set': 'configurada',
        'off': 'Apagado',
        'idle': 'Sin conexión',
        'connected': 'Conectado',
        'partial':
            'Conectado, pero una de las dos transmisiones de YouTube falló',
        'connecting': 'Conectando / reconectando',
        'waiting': 'Esperando la transmisión en vivo',
        'verticalWaiting':
            'Horizontal en vivo; la vertical espera su transmisión',
        'horizontalWaiting':
            'Vertical en vivo; la horizontal espera su transmisión',
        'ended': 'Transmisión terminada',
        'failed': 'Error (detalles privados omitidos)',
        'portBusy': 'El puerto ya está en uso',
        'authentication': 'Error de autenticación',
        'refused': 'Conexión rechazada',
        'timeout': 'Tiempo de conexión agotado',
        'listeningPort': 'Escuchando en el puerto $value',
        'starting': 'Iniciando',
        'noAlerts': 'No hay página de alertas conectada en OBS',
        'pages': 'Páginas abiertas en OBS: $value',
        'loading': 'Cargando $value',
        'ready': 'Listo: $value',
        'listening': 'Escuchando',
        'downloading': 'Descargando $value',
        'missingModel': 'Se requiere descargar el modelo',
        'commandsOn': 'Comandos de voz activados',
        'commandsOff': 'Comandos de voz desactivados',
        'shortcutsOk': 'Sin asignar o todos registrados',
        'shortcutTaken': 'Atajo usado por otra aplicación: $value',
        'silenceTts': 'Silenciar lector de voz',
        'toggleTts': 'Alternar lector de voz',
        'channelSet': 'Canal configurado',
        'channelUnset': 'Canal sin configurar',
        'scene': 'Escena: $value',
        'metrics': '$value kbps / fotogramas perdidos',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String diagnosticsArea(String area) {
    String _temp0 = intl.Intl.selectLogic(
      area,
      {
        'youtube': 'YouTube',
        'twitch': 'Twitch',
        'kick': 'Kick',
        'obs': 'OBS',
        'server': 'Servidor de superposición',
        'tts': 'Lector de voz (TTS)',
        'captions': 'Subtítulos y comandos de voz',
        'shortcuts': 'Atajos globales',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String get giveawayTitle => 'Sorteo por palabra clave';

  @override
  String get giveawayDescription =>
      'Cada persona participa una vez escribiendo la palabra clave en el chat.';

  @override
  String get giveawayKeyword => 'Palabra clave';

  @override
  String get giveawayMembersOnly => 'Solo miembros o suscriptores';

  @override
  String get giveawayStart => 'Iniciar';

  @override
  String get giveawayClose => 'Cerrar participación';

  @override
  String get giveawayDraw => 'Sortear';

  @override
  String get giveawayRedraw => 'Volver a sortear';

  @override
  String get giveawayClear => 'Borrar';

  @override
  String get giveawayClosed => 'Participación cerrada';

  @override
  String get giveawayWinner => 'Ganador';

  @override
  String get giveawayDrawing => 'Sorteando…';

  @override
  String get giveawayPageTitle => 'Sorteo Airstream';

  @override
  String giveawayParticipants(int count) {
    return '$count participantes';
  }

  @override
  String get giveawayPageOff =>
      'Activa el servidor de superposición para mostrarlo en OBS.';

  @override
  String giveawayPageUrl(String url) {
    return 'Página para OBS: $url';
  }

  @override
  String get giveawayUrlCopied => 'URL de la página del sorteo copiada';

  @override
  String get goalsTitle => 'Metas';

  @override
  String get goalsDescription =>
      'Sigue los apoyos y ajusta el progreso durante tu directo.';

  @override
  String get goalsAdd => 'Añadir meta';

  @override
  String get goalsEdit => 'Editar';

  @override
  String get goalsDelete => 'Eliminar';

  @override
  String get goalsReset => 'Reiniciar a 0';

  @override
  String get goalsSave => 'Guardar';

  @override
  String get goalsName => 'Título';

  @override
  String get goalsType => 'Tipo';

  @override
  String get goalsTarget => 'Objetivo';

  @override
  String get goalsSubs => 'Suscripciones';

  @override
  String get goalsBits => 'Bits';

  @override
  String get goalsKicks => 'Kicks';

  @override
  String get goalsManual => 'Manual';

  @override
  String get goalsReached => '¡Meta cumplida!';

  @override
  String get goalsPageTitle => 'Metas Airstream';

  @override
  String get goalsInvalid =>
      'Escribe un título y un objetivo entre 1 y 1 000 000.';

  @override
  String get goalsPageOff =>
      'Activa el servidor de superposición para mostrarlo en OBS.';

  @override
  String goalsPageUrl(String url) {
    return 'Página para OBS: $url';
  }

  @override
  String get goalsUrlCopied => 'URL de la página de metas copiada';

  @override
  String get subathonTitle => 'Temporizador de subatón';

  @override
  String get subathonStartMinutes => 'Minutos iniciales';

  @override
  String get subathonStart => 'Iniciar';

  @override
  String get subathonPause => 'Pausar';

  @override
  String get subathonResume => 'Reanudar';

  @override
  String get subathonReset => 'Reiniciar';

  @override
  String get subathonRules => 'Reglas';

  @override
  String get subathonPerSub => 'Segundos por suscripción o regalo';

  @override
  String get subathonPerBits => 'Segundos por cada 100 Bits';

  @override
  String get subathonPerKicks => 'Segundos por cada 100 Kicks';

  @override
  String get subathonCap => 'Máximo de minutos restantes (0 = sin límite)';

  @override
  String get subathonIdle => 'Inactivo';

  @override
  String get subathonRunning => 'En marcha';

  @override
  String get subathonPaused => 'En pausa';

  @override
  String get subathonEnded => '¡Se acabó el tiempo!';

  @override
  String get subathonPageOff =>
      'Activa el servidor de superposición para mostrarlo en OBS.';

  @override
  String get subathonDescription =>
      'Añade tiempo con los apoyos durante tu directo.';

  @override
  String get subathonUrlCopied => 'URL de la página del temporizador copiada';

  @override
  String get mediaLibraryTitle => 'Biblioteca de medios';

  @override
  String mediaUsage(String used) {
    return '$used de 500 MB';
  }

  @override
  String get mediaAdd => 'Añadir archivos';

  @override
  String get mediaDelete => 'Eliminar';

  @override
  String get mediaRejectType =>
      'Tipo de archivo no admitido o contenido inválido.';

  @override
  String get mediaRejectSize =>
      'El archivo supera su límite (imágenes 10 MB, videos 50 MB, audio 5 MB).';

  @override
  String get mediaRejectTotal => 'La biblioteca superaría los 500 MB.';

  @override
  String get alertMedia => 'Imagen o video';

  @override
  String get mediaNone => 'Ninguno';

  @override
  String get alertMediaAudio => 'Reproducir el sonido del video';

  @override
  String mediaLibraryName(String name) {
    return 'Biblioteca: $name';
  }

  @override
  String get mediaImage => 'Imagen';

  @override
  String get mediaVideo => 'Video';

  @override
  String get mediaAudio => 'Audio';

  @override
  String get templatesTitle => 'Plantillas';

  @override
  String get templatesDescription =>
      'Una plantilla es una carpeta con HTML, CSS y JavaScript en Documentos\\Airstream\\Templates. Cada plantilla tiene su propia URL para OBS.';

  @override
  String get templatesNew => 'Nueva plantilla';

  @override
  String get templatesOpenFolder => 'Abrir carpeta';

  @override
  String get templatesTest => 'Enviar eventos de prueba';

  @override
  String get templatesTestSent =>
      'Eventos de prueba enviados a las páginas abiertas';

  @override
  String get templatesTestEmpty => 'Abre primero una plantilla en OBS';

  @override
  String get templatesEmpty => 'Aún no hay plantillas';

  @override
  String get templatesInternet => 'Acceso a internet';

  @override
  String get backupTemplateTrust =>
      'Estas plantillas contienen código que se ejecuta en OBS. Restaura solo plantillas de personas en las que confíes.';

  @override
  String get templatesCopy => 'Copiar URL';

  @override
  String get templatesCopied => 'URL copiada';

  @override
  String get templatesPreview => 'Vista previa';

  @override
  String get templatesEdit => 'Editar código';

  @override
  String get templatesDelete => 'Eliminar';

  @override
  String get templatesName => 'Nombre';

  @override
  String get templatesRequired => 'Escribe un nombre';

  @override
  String get templatesCreate => 'Crear';

  @override
  String get templatesCancel => 'Cancelar';

  @override
  String get templatesSave => 'Guardar';

  @override
  String get templatesSaved => 'Cambios guardados';

  @override
  String get templatesClose => 'Cerrar';

  @override
  String get templatesDiscard => 'Descartar cambios';

  @override
  String get templatesUnsaved => '¿Descartar los cambios sin guardar?';

  @override
  String get templatesLarge =>
      'Este archivo supera los 512 KB. Edítalo desde la carpeta.';

  @override
  String get templatesFailed =>
      'No se pudo completar la acción. Revisa la carpeta de la plantilla e inténtalo de nuevo.';

  @override
  String get templatesBlank => 'En blanco';

  @override
  String get templatesChat => 'Chat';

  @override
  String get templatesAlerts => 'Alertas';

  @override
  String get templatesGoal => 'Barra de meta';

  @override
  String get templatesBlankDescription => 'Muestra el último evento del SDK';

  @override
  String get templatesChatDescription =>
      'Mensajes en vivo con emoticonos y avatares';

  @override
  String get templatesAlertsDescription => 'Alertas animadas, una a la vez';

  @override
  String get templatesGoalDescription => 'Progreso hacia una de tus metas';

  @override
  String get templatesMissingIndex => 'Falta index.html';

  @override
  String get templatesInvalidManifest => 'template.json no es válido';

  @override
  String get templatesUnsupportedSdk => 'Versión del SDK no compatible';

  @override
  String get templatesOversizedIndex => 'index.html supera los 2 MB';

  @override
  String templatesOpenCount(int count) {
    return '$count abiertas en OBS';
  }

  @override
  String templatesError(String source, String line, String message) {
    return 'Error en $source:$line: $message';
  }

  @override
  String templatesDeleteConfirm(String name) {
    return '¿Eliminar «$name»? Se eliminará su carpeta y no se puede deshacer.';
  }

  @override
  String get templatesAi => 'Crear con IA';

  @override
  String get templatesAiSteps =>
      '1. Abre esta carpeta en tu herramienta de IA, por ejemplo OpenCode, Claude Code o Codex.\n2. Pega la instrucción.\n3. La plantilla aparece en esta lista: copia su URL en OBS.';

  @override
  String get templatesAiDescription => '¿Qué debe mostrar tu plantilla?';

  @override
  String get templatesAiCopy => 'Copiar instrucción';

  @override
  String get templatesAiCopied => 'Instrucción copiada';

  @override
  String templatesAiInstruction(String id, String description, String url) {
    return 'Lee primero AGENTS.md en esta carpeta. Crea una plantilla nueva en una carpeta nueva llamada $id.\nQué debe mostrar:\n$description\nPruébala en $url y corrige los errores de la consola del navegador. Al terminar, dime su URL para OBS y el tamaño recomendado.';
  }

  @override
  String get templateCustomize => 'Personalizar';

  @override
  String get templateReset => 'Restablecer valores predeterminados';

  @override
  String get templateFieldNone => 'Ninguno';

  @override
  String get templateFieldColorInvalid =>
      'Usa #rrggbb o #rrggbbaa. Este color no se ha guardado.';

  @override
  String get templateExport => 'Exportar .zip';

  @override
  String get templateImport => 'Importar .zip';

  @override
  String get templatePlatformImages =>
      'Sin acceso a Internet, esta plantilla aún puede cargar imágenes de YouTube, Twitch, Kick, 7TV, BetterTTV y FrankerFaceZ, y código y fuentes de CDN públicos. No queda aislada: su código recibe tu chat y puede abrir otros sitios web.';

  @override
  String get templateDuplicate => 'Duplicar';

  @override
  String get templateCopyWord => 'copia';

  @override
  String get templateArchiveDone => 'Plantilla guardada';

  @override
  String get templateTrust =>
      'Esta plantilla contiene código que se ejecuta en OBS. Importa solo plantillas de personas en las que confíes.';

  @override
  String templateArchiveSummary(int count, int bytes) {
    return '$count archivos · $bytes bytes';
  }

  @override
  String get templateRejectZip => 'El ZIP supera los 100 MB.';

  @override
  String get templateRejectCount => 'Más de 500 archivos.';

  @override
  String get templateRejectTotal =>
      'El contenido descomprimido supera los 100 MB.';

  @override
  String get templateRejectFile => 'Un archivo supera los 50 MB.';

  @override
  String get templateRejectPath => 'Ruta de archivo insegura o duplicada.';

  @override
  String get templateRejectLink =>
      'No se permiten enlaces ni archivos especiales.';

  @override
  String get templateRejectType => 'Tipo de archivo no permitido.';

  @override
  String get templateRejectLayout =>
      'Coloca los archivos en la raíz del ZIP o dentro de una sola carpeta.';

  @override
  String get templateRejectIndex => 'Falta index.html.';

  @override
  String get templateRejectSize =>
      'ZIP no válido, contenido dañado o límite de descompresión superado.';

  @override
  String get liveTab => 'En directo';

  @override
  String get liveServerOff => 'Servidor de superposición apagado';

  @override
  String get liveOpenObs => 'Ir a OBS y superposición';

  @override
  String get liveServerNotice =>
      'Para mostrar estas herramientas en OBS, activa el servidor de superposición.';

  @override
  String get templatesEmptyGuide =>
      'Empieza con un ejemplo\nPídeselo a un agente de IA\nImporta una plantilla compartida';

  @override
  String ruleLabel(String code) {
    String _temp0 = intl.Intl.selectLogic(
      code,
      {
        'krules': 'Reglas',
        'kdescription':
            'Cuando algo ocurre en tu directo, Airstream puede hacer cosas por ti.',
        'kautomation': 'Automatización activa',
        'knew': 'Nueva regla',
        'krecipes': 'Recetas',
        'kempty': 'Empieza con un ejemplo de Recetas.',
        'kempty2': 'O elige Nueva regla para crear la tuya.',
        'ktripped':
            'La automatización se pausó tras demasiadas ejecuciones en un minuto.',
        'kresume': 'Reanudar',
        'kinvalid': 'Esta regla necesita correcciones',
        'kpublicObs': 'Cualquiera en el chat puede cambiar OBS con esta regla',
        'kpublicChatText': 'Lo que escriba el chat saldrá en tu directo',
        'knoCooldown': 'Sin espera: el chat puede repetirla sin límite',
        'kedit': 'Editar',
        'kduplicate': 'Duplicar',
        'kdelete': 'Eliminar',
        'kcopy': 'copia',
        'kconfirmDelete': '¿Eliminar esta regla?',
        'kcancel': 'Cancelar',
        'kdiscard': '¿Descartar los cambios?',
        'kclose': 'Cerrar',
        'ksave': 'Guardar',
        'ksaveFailed': 'No se pudo guardar la regla. Inténtalo de nuevo.',
        'kname': 'Nombre',
        'kwhen': 'Cuando',
        'kif': 'Si',
        'kdo': 'Hacer',
        'klimits': 'Límites',
        'koverlap': 'Si ya se está ejecutando',
        'kaddAction': 'Añadir acción',
        'ktest': 'Probar',
        'ktestWith': 'Probar con',
        'krun': 'Ejecutar ahora',
        'kmatched': 'Coincide',
        'kaccepted': 'Ejecución aceptada',
        'khistory': 'Historial',
        'kclear': 'Limpiar',
        'knoHistory': 'Aún no hay ejecuciones.',
        'kup': 'Subir',
        'kdown': 'Bajar',
        'kfieldError': 'Revisa este valor y sus límites',
        'kcooldownSeconds': 'Espera (segundos, 0–3600)',
        'kuserCooldownSeconds': 'Espera por persona (segundos, 0–3600)',
        'kqueue': 'En cola: esperar a la ejecución anterior',
        'kskip': 'Omitir: ignorar si ya se está ejecutando',
        'konlyWhileStreaming': 'Solo mientras OBS transmite',
        'keveryone': 'Todos',
        'kmember': 'Miembros/suscriptores',
        'kmoderator': 'Moderadores',
        'kvip': 'VIP',
        'kowner': 'Propietario',
        'kchat': 'Chat',
        'ksupport': 'Apoyos',
        'klive': 'Herramientas del directo',
        'kobs': 'OBS',
        'ktime': 'Tiempo',
        'kmanual': 'Manual',
        'kflow': 'Flujo',
        'kvoice': 'Voz',
        'ksound': 'Sonido',
        'kpages': 'Páginas y plantillas',
        'kadd': 'Añadir',
        'kdone': 'Hecha ✓',
        'kskipped': 'Omitida',
        'kfailed': 'Fallida',
        'kuncertain': 'Incierta',
        'kcancelled': 'Cancelada',
        'kwouldRun': 'Se ejecutaría',
        'kpending': 'Pendiente',
        'kchat_message': 'Mensaje con texto',
        'kchat_command': 'Comando del chat',
        'kchat_firstMessage': 'Primer mensaje',
        'ksupport_superchat': 'Super Chat',
        'ksupport_bits': 'Bits',
        'ksupport_membership': 'Membresía / suscripción',
        'ksupport_gift': 'Suscripciones regaladas',
        'ksupport_raid': 'Raid',
        'ksupport_kicks': 'Kicks',
        'kgoal_reached': 'Meta cumplida',
        'kgiveaway_winner': 'Ganador del sorteo',
        'kpoll_ended': 'Encuesta terminada',
        'kclock_ended': 'Temporizador terminado',
        'ksubathon_ended': 'Subatón terminado',
        'kobs_streamStarted': 'Transmisión iniciada',
        'kobs_streamStopped': 'Transmisión detenida',
        'kobs_recordingStarted': 'Grabación iniciada',
        'kobs_recordingStopped': 'Grabación detenida',
        'kobs_sceneChanged': 'Escena cambiada',
        'kinterval': 'Cada N minutos',
        'kwait': 'Esperar',
        'kobs_scene': 'Cambiar escena',
        'kobs_previousScene': 'Volver a la escena anterior',
        'kobs_recording': 'Grabación',
        'kobs_source': 'Mostrar / ocultar fuente',
        'kobs_mute': 'Silenciar / activar audio',
        'kobs_text': 'Cambiar texto',
        'kobs_filter': 'Activar / desactivar filtro',
        'ktts_say': 'Leer en voz alta',
        'ksound_play': 'Reproducir sonido',
        'kalert_show': 'Mostrar alerta',
        'kfeatured': 'Destacar mensaje',
        'ktemplate_trigger': 'Activar plantilla',
        'kgoal_adjust': 'Ajustar meta',
        'kclock': 'Temporizador',
        'ksubathon_adjust': 'Ajustar subatón',
        'kgiveaway': 'Sorteo',
        'kcounter': 'Contador',
        'kcommand': 'Comando',
        'kmatch': 'Coincidencia',
        'ktext': 'Texto',
        'kminAmount': 'Importe mínimo',
        'kcurrency': 'Moneda',
        'kmin': 'Cantidad mínima',
        'kminMonths': 'Meses mínimos',
        'kgoalId': 'Meta',
        'kscene': 'Escena',
        'kminutes': 'Minutos',
        'kseconds': 'Segundos',
        'kstate': 'Estado',
        'ksource': 'Fuente',
        'kfilter': 'Filtro',
        'kvisible': 'Visibilidad',
        'kinput': 'Entrada de audio',
        'kmediaId': 'Medio de biblioteca',
        'ktitle': 'Título',
        'kdata': 'Datos',
        'kdelta': 'Cambio',
        'kop': 'Operación',
        'kkeyword': 'Palabra clave',
        'kmembersOnly': 'Solo miembros',
        'kvalue': 'Valor',
        'kcontains': 'Contiene',
        'kstartsWith': 'Empieza por',
        'kequals': 'Igual a',
        'kstart': 'Iniciar',
        'kstop': 'Detener',
        'kshow': 'Mostrar',
        'khide': 'Ocultar',
        'ktoggle': 'Alternar',
        'kmute': 'Silenciar',
        'kunmute': 'Activar audio',
        'kenable': 'Activar',
        'kdisable': 'Desactivar',
        'kbuiltin': 'Integrado',
        'klibrary': 'Biblioteca',
        'kchime': 'Campanilla',
        'kcoin': 'Moneda',
        'kfanfare': 'Fanfarria',
        'kset': 'Fijar',
        'kdraw': 'Sortear',
        'kautomationOff': 'Automatización desactivada',
        'kchainLimit': 'Límite de cadena alcanzado',
        'kinvalidRule': 'Regla inválida',
        'kruleDisabled': 'Regla desactivada',
        'kwrongTrigger': 'Otro disparador',
        'kplatform': 'La plataforma no coincide',
        'krole': 'El rol no coincide',
        'knotStreaming': 'OBS no está transmitiendo',
        'ktextMismatch': 'El texto no coincide',
        'kamountUnknown': 'Importe desconocido',
        'kcurrencyMismatch': 'La moneda no coincide',
        'kbelowMinimum': 'Por debajo del mínimo',
        'kcooldown': 'La regla está en espera',
        'kuserCooldown': 'La persona está en espera',
        'ktrippedReason': 'Automatización pausada por el límite de seguridad',
        'krunRateExceeded': 'Demasiadas ejecuciones en un minuto',
        'koverlapSkipped': 'Ya se está ejecutando',
        'kqueueFull': 'La cola está llena',
        'knoPreviousScene': 'No hay escena anterior guardada',
        'ktargetError': 'La acción falló',
        'ktimeout': 'La acción agotó el tiempo',
        'kdisposed': 'Motor cerrado',
        'knotConnected': 'OBS desconectado',
        'kttsOff': 'Lector de voz apagado o no preparado',
        'knoMessage': 'No hay mensaje de chat',
        'kgoalNotFound': 'Meta no encontrada',
        'ktimerNotRunning': 'El subatón no está activo',
        'kclockUnchanged': 'El temporizador ya está en ese estado',
        'ksubathonUnchanged': 'Ese tiempo no cambia el subathon',
        'knoReceiver': 'Sin receptor de plantillas conectado',
        'kinvalidKeyword': 'Palabra clave inválida',
        'kalreadyOpen': 'El sorteo ya está abierto',
        'knotOpen': 'El sorteo no está abierto',
        'knoEntrants': 'Sin participantes elegibles',
        'kqueue_joined': 'Alguien se unió a la lista',
        'kqueue_next': 'Siguientes jugadores',
        'kqueue_open': 'Abrir la lista',
        'kqueue_close': 'Cerrar la lista',
        'kqueue_pause': 'Pausar la lista',
        'kwinnerCount': 'Ganadores',
        'kcount': 'Jugadores',
        'krandom': 'Elegir al azar',
        'kqueueAlreadyOpen': 'La lista ya está abierta',
        'kqueueAlreadyPaused': 'La lista ya está en pausa',
        'kqueueAlreadyClosed': 'La lista ya está cerrada',
        'kqueueEmpty': 'No hay nadie en la lista',
        'kqueuePlayingFull': 'Ya hay diez jugando',
        'kcounterLimit': 'Límite de contadores alcanzado',
        'krecipe1': 'Recibir una raid',
        'krecipeDesc1': 'Muestra Raid durante 15 segundos y vuelve.',
        'krecipe2': 'Compartir tus redes',
        'krecipeDesc2': 'Activa redes y lee tus enlaces en voz alta.',
        'krecipe3': 'Leer Super Chats',
        'krecipeDesc3': 'Lee mensajes con importe mínimo de \$5.',
        'krecipe4': 'Recordatorio periódico',
        'krecipeDesc4': 'Activa recordatorio cada 20 minutos.',
        'krecipe5': 'Celebrar una meta',
        'krecipeDesc5': 'Muestra Celebración durante 10 segundos y vuelve.',
        'krecipe6': 'Contar muertes',
        'krecipeDesc6':
            'Los moderadores suman a muertes y activan una plantilla.',
        'krecipe7': 'Contador en pantalla',
        'krecipeDesc7':
            'Los moderadores suman a muertes y lo muestran en una fuente de texto.',
        'kdiscardAction': 'Descartar',
        'kbuttons': 'Botones de reglas',
        'knotFound': 'No se encontró el elemento',
        'knotTextSource': 'No es una fuente de texto',
        'knoAlertsPage': 'No hay una página de alertas conectada',
        'kwillCheckInObs': 'Se comprobará en OBS',
        'kwouldSkip': 'Se omitiría',
        'kwebhook': 'Nombre de acceso web (opcional)',
        'kwebhookConflict': 'Este nombre de acceso web ya está en uso.',
        'kwebhookTitle': 'Stream Deck y otras aplicaciones',
        'kwebhookEnable': 'Activar URL locales de reglas',
        'kwebhookHelp':
            'Stream Deck: usa la acción Sitio web con solicitud GET en segundo plano. Cualquier aplicación o script puede llamar a la URL.',
        'kwebhookSecretWarning':
            'Cualquier persona con la URL puede ejecutar estas reglas. Mantenla privada.',
        'kwebhookServerHelp':
            'Activa el servidor local en los ajustes de OBS para usar estas URL.',
        'khideToken': 'Ocultar token',
        'krevealToken': 'Mostrar token',
        'kcopyToken': 'Copiar token',
        'kregenerate': 'Regenerar',
        'kregenerateConfirm':
            '¿Regenerar el token? Los botones existentes dejarán de funcionar.',
        'kexportRules': 'Exportar reglas',
        'kimportRules': 'Importar reglas',
        'kimportReview': 'Revisar reglas importadas',
        'kimportDisabled':
            'Todas las reglas importadas estarán desactivadas. Revísalas antes de activarlas.',
        'kimportSkipped': 'Reglas omitidas (límite de 50)',
        'kwebhookCollision':
            'Nombre de acceso web eliminado porque ya está en uso:',
        'kobsNames': 'Comprueba que estos nombres existan en tu OBS:',
        'kmissingMedia':
            'Medio ausente en esta biblioteca (se conserva la acción):',
        'ktemplateName': 'Nombre del evento de plantilla:',
        'kunknownFormat': 'Formato de archivo de reglas desconocido.',
        'kunknownVersion': 'Versión del archivo de reglas no compatible.',
        'kmalformedJson': 'Archivo JSON de reglas no válido.',
        'kfileTooLarge': 'El archivo de reglas supera 1 MB.',
        'ksharingFailed': 'No se pudo leer o escribir el archivo de reglas.',
        'kobs_stream': 'Emisión',
        'kobs_replay': 'Búfer de repetición',
        'kobs_media': 'Controlar medio',
        'kobs_volume': 'Volumen',
        'kobs_refresh': 'Recargar fuente de navegador',
        'khttp_request': 'Llamar a una URL',
        'kstreamStart': 'Iniciar emisión',
        'kstreamStop': 'Detener emisión',
        'kreplaySave': 'Guardar repetición',
        'kplay': 'Reproducir',
        'kpause': 'Pausar',
        'kreset': 'Reiniciar',
        'krestart': 'Reiniciar',
        'kmode': 'Modo',
        'kchange': 'Cambiar',
        'kdb': 'dB',
        'kmethod': 'Método',
        'kget': 'GET',
        'kpost': 'POST',
        'kurl': 'URL',
        'kcontentType': 'Tipo de contenido',
        'kjson': 'JSON',
        'kbody': 'Cuerpo',
        'kstreamAlready': 'La emisión ya está en ese estado',
        'kpublicStreamControl':
            'Los espectadores no pueden iniciar ni detener la emisión. Elige un disparador manual, de temporizador, de emisión o de grabación, o limita los disparadores de chat, ingreso a la lista o aportes a moderadores o al propietario.',
        'kreplayOff': 'El búfer de repetición está apagado',
        'kreplayAlready': 'El búfer de repetición ya está en ese estado',
        'knotBrowserSource': 'No es una fuente de navegador',
        'knoUrl': 'Falta la URL',
        'kinvalidHttpUrl': 'Introduce una URL HTTP o HTTPS válida',
        'khttpStatus': 'La URL respondió con error',
        'khttpError': 'No se pudo conectar con la URL',
        'kresetHttpUrl': 'Vuelve a poner la URL en:',
        'krecipe8': 'Avisar en Discord',
        'krecipeDesc8':
            'Pega la URL de tu webhook de Discord para anunciar tu directo.',
        'other': '…',
      },
    );
    return '$_temp0';
  }

  @override
  String ruleSummary(String trigger, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count acciones',
      one: '1 acción',
    );
    return 'Cuando $trigger → $_temp0';
  }

  @override
  String get templatesGallery => 'Galería';

  @override
  String get galleryAdd => 'Añadir';

  @override
  String get galleryAddAgain => 'Añadir de nuevo';

  @override
  String get galleryNewVersion => 'Hay una versión nueva';

  @override
  String get galleryPreviewUnavailable =>
      'Inicia el servidor para ver las vistas previas.';

  @override
  String get galleryRecentSupport => 'Apoyos recientes';

  @override
  String get galleryRecentSupportDescription =>
      'Muestra los últimos apoyos de YouTube, Twitch y Kick.';

  @override
  String get galleryTheme => 'Tema';

  @override
  String get galleryFont => 'Fuente';

  @override
  String get galleryAccent => 'Color de acento';

  @override
  String get galleryLogo => 'Logotipo';

  @override
  String get galleryLanguage => 'Idioma';

  @override
  String get galleryHeading => 'Título personalizado';

  @override
  String get gallerySupportCount => 'Máximo de apoyos';

  @override
  String get galleryShowEmpty => 'Mostrar el aviso cuando no hay apoyos';

  @override
  String get galleryStartingSoon => 'Empezamos pronto';

  @override
  String get galleryStartingSoonDescription =>
      'Abre el directo con una cuenta atrás, mensajes rotativos y chat en vivo.';

  @override
  String get galleryBeRightBack => 'Vuelvo enseguida';

  @override
  String get galleryBeRightBackDescription =>
      'Muestra una pausa con cuenta atrás, chat en vivo y los últimos apoyos.';

  @override
  String get galleryStreamEnding => 'Fin del directo';

  @override
  String get galleryStreamEndingDescription =>
      'Da las gracias con las cifras del directo y la clasificación de apoyos.';

  @override
  String get galleryCredits => 'Créditos';

  @override
  String get galleryCreditsDescription =>
      'Despide el directo con créditos de apoyos, clasificaciones y un mensaje final.';

  @override
  String get galleryBackground => 'Fondo';

  @override
  String get galleryBackgroundMedia => 'Imagen o vídeo de fondo';

  @override
  String get galleryMessages => 'Mensajes rotativos (separa con |)';

  @override
  String get galleryScreenTitle =>
      'Título (déjalo vacío para usar el predeterminado)';

  @override
  String get gallerySubtitle => 'Subtítulo';

  @override
  String get galleryStartTime =>
      'Hora local de inicio (HH:MM en formato de 24 horas)';

  @override
  String get galleryShowChat => 'Mostrar el chat en vivo';

  @override
  String get galleryMinutes => 'Minutos de cuenta atrás (0 para ocultarla)';

  @override
  String get galleryShowDuration => 'Mostrar la duración del directo';

  @override
  String get galleryShowMessages => 'Mostrar el total de mensajes';

  @override
  String get galleryShowChatters => 'Mostrar el total de participantes';

  @override
  String get galleryShowSupporters => 'Mostrar cuántas personas apoyaron';

  @override
  String get galleryShowTopSupporters => 'Mostrar la clasificación de apoyos';

  @override
  String get galleryShowTopChatters => 'Mostrar quienes más escribieron';

  @override
  String get galleryCurrency =>
      'Moneda de Super Chat (vacío para elegir automáticamente)';

  @override
  String get galleryFinalText => 'Mensaje final';

  @override
  String get galleryCreditsSpeed =>
      'Velocidad de los créditos (píxeles por segundo)';

  @override
  String get galleryCreditsLoop => 'Repetir los créditos';

  @override
  String get galleryTicker => 'Barra informativa';

  @override
  String get galleryTickerDescription =>
      'Desplaza mensajes, apoyos recientes, metas y el tiempo de subatón durante el directo.';

  @override
  String get galleryLatestSupport => 'Último apoyo';

  @override
  String get galleryLatestSupportDescription =>
      'Destaca el apoyo más reciente o alterna entre los tipos de apoyo.';

  @override
  String get galleryTopSupporters => 'Top del directo';

  @override
  String get galleryTopSupportersDescription =>
      'Muestra los cinco primeros puestos por apoyos o mensajes del directo.';

  @override
  String get galleryTickerMessages => 'Mensajes de la barra (separados con |)';

  @override
  String get galleryTickerSpeed =>
      'Velocidad de desplazamiento (píxeles por segundo)';

  @override
  String get galleryTickerShowCustom => 'Mostrar mensajes personalizados';

  @override
  String get galleryTickerShowLatest => 'Mostrar el último apoyo de cada tipo';

  @override
  String get galleryTickerShowGoals => 'Mostrar el progreso de las metas';

  @override
  String get galleryTickerShowTimer =>
      'Mostrar el temporizador de subatón en marcha';

  @override
  String get galleryTickerShowEmpty =>
      'Mostrar el título de la barra cuando esté vacía';

  @override
  String get galleryLatestSupportMode => 'Modo de visualización de apoyos';

  @override
  String get galleryRotationSeconds => 'Segundos entre cambios';

  @override
  String get galleryRankingType => 'Tipo de clasificación';

  @override
  String get queueTitle => 'Lista de turnos';

  @override
  String get queueClosed => 'Cerrada';

  @override
  String get queueOpenStatus => 'Abierta';

  @override
  String get queuePaused => 'En pausa';

  @override
  String get queueOpen => 'Abrir';

  @override
  String get queuePause => 'Pausar';

  @override
  String get queueClose => 'Cerrar';

  @override
  String queueJoinHint(String command) {
    return 'Escribe $command para jugar';
  }

  @override
  String get queueEmpty => 'No hay nadie en espera';

  @override
  String get queueNext => 'Siguiente';

  @override
  String get queueNextCount => 'Jugadores';

  @override
  String get queueRandom => 'Al azar';

  @override
  String get queueClear => 'Vaciar';

  @override
  String get queueClearConfirm =>
      '¿Vaciar la lista y quitar a quienes están jugando?';

  @override
  String get queuePlaying => 'Jugando ahora';

  @override
  String get queueNobodyPlaying => 'No hay nadie jugando';

  @override
  String get queueSettings => 'Ajustes de la lista';

  @override
  String get queueMax => 'Tamaño máximo de la lista';

  @override
  String get queueRoles => 'Quién puede unirse';

  @override
  String get queueEveryone => 'Todos';

  @override
  String get queueMembers => 'Miembros y suscriptores';

  @override
  String get queueVip => 'VIP';

  @override
  String get queueModerators => 'Moderadores';

  @override
  String get queuePriority => 'Dar prioridad a miembros y suscriptores';

  @override
  String get queueRejoin => 'Permitir volver a unirse después de jugar';

  @override
  String get queueChatMods => 'Comandos de moderación en el chat';

  @override
  String get queueChatModsHint =>
      'Permite al dueño y a los moderadores gestionar la lista desde el chat.';

  @override
  String get queueCommand => 'Comando para unirse';

  @override
  String queueJoinWhenOpen(String command) {
    return 'Cuando abra, escribe $command para jugar';
  }

  @override
  String get queueReservedCommand => 'Este comando está reservado. Elige otro.';

  @override
  String get queueInvalidCommand =>
      'Usa ! seguido de 1 a 24 letras, números, guiones o guiones bajos.';

  @override
  String get queueSave => 'Guardar';

  @override
  String get queueRemove => 'Quitar';

  @override
  String get queueDone => 'Terminó';

  @override
  String get queuePlayingFull =>
      'Hay diez jugando. Marca a uno con Terminó para llamar a más.';

  @override
  String get galleryQueueDescription =>
      'Muestra quién está jugando y quién espera su turno.';

  @override
  String get galleryQueueCount => 'Turnos visibles';

  @override
  String get galleryQueueHideClosed => 'Ocultar cuando la lista esté cerrada';

  @override
  String get galleryQueueWaiting => 'En espera';

  @override
  String galleryQueueMore(String count) {
    return '+$count más';
  }

  @override
  String get alertQueuePause => 'Pausar alertas';

  @override
  String get alertQueueResume => 'Reanudar alertas';

  @override
  String get alertQueueSkip => 'Saltar alerta actual';

  @override
  String get alertQueueClear => 'Vaciar alertas en espera';

  @override
  String alertQueueWaiting(int count) {
    return '$count en espera';
  }

  @override
  String get alertQueueWaitingHint =>
      'Cola más larga entre las páginas de alertas abiertas';

  @override
  String get alertQueueNoPage =>
      'Abre la página de alertas para controlar la cola.';

  @override
  String get alertPlatformFilter => 'Alertas automáticas por plataforma';

  @override
  String get alertTiers => 'Tramos por importe';

  @override
  String get alertTierCurrency =>
      'Los Super Chats usan la moneda original sin conversión.';

  @override
  String get alertTierFrom => 'Desde';

  @override
  String get alertTierInvalid => 'Escribe un número mayor que cero.';

  @override
  String get alertTierAdd => 'Añadir tramo';

  @override
  String get alertTierRemove => 'Quitar tramo';

  @override
  String get alertTierInherit => 'Usar ajuste del tipo';

  @override
  String get alertTierAudioOn => 'Reproducir audio';

  @override
  String get alertTierAudioOff => 'Silenciar audio';

  @override
  String get featuredTitle => 'Mensaje destacado';

  @override
  String get featuredDescription =>
      'Muestra los mensajes que destacas en directo.';

  @override
  String get featuredUrlCopied => 'Enlace de la página de destacados copiado';

  @override
  String get featuredRemove => 'Quitar destacado';

  @override
  String get featuredFontScale => 'Tamaño del texto destacado';

  @override
  String get featuredKeepVisible => 'Mantener visible hasta quitarlo';

  @override
  String get ttsWhatToRead => 'Qué leer';

  @override
  String get ttsReaderRoles => 'Roles';

  @override
  String get ttsRoleEveryone => 'Todos';

  @override
  String get ttsRoleModerator => 'Moderador';

  @override
  String get ttsRoleVip => 'VIP';

  @override
  String get ttsRoleOwner => 'Dueño';

  @override
  String get ttsReaderPlatforms => 'Plataformas';

  @override
  String get ttsAlwaysReadSupport => 'Leer siempre los apoyos con importe';

  @override
  String get ttsSkipEmoteOnly => 'Omitir mensajes de solo emoticonos';

  @override
  String get ttsLinks => 'Enlaces';

  @override
  String get ttsLinksRead => 'Leer el mensaje';

  @override
  String get ttsLinksSay => 'Decir «enlace»';

  @override
  String get ttsLinksSkip => 'Omitir el mensaje';

  @override
  String get ttsSpokenLink => 'enlace';

  @override
  String get highlightSoundMention => 'Mención';

  @override
  String get highlightSoundWord => 'Palabra resaltada';

  @override
  String get highlightSoundFirstMessage => 'Primer mensaje';

  @override
  String get highlightSoundPriority =>
      'Si coinciden varios resaltados, tiene prioridad la mención, luego la palabra y por último el primer mensaje.';

  @override
  String get sessionExportChat => 'Exportar chat (CSV)';

  @override
  String get sessionExportParticipants => 'Exportar participantes (CSV)';

  @override
  String get sessionExportFailed => 'No se pudo guardar el archivo CSV.';

  @override
  String sessionExportChatScope(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'La exportación de chat se limita a los últimos $count mensajes conservados.',
      one: 'La exportación incluye 1 mensaje de chat conservado.',
      zero: 'No hay mensajes de chat conservados.',
    );
    return '$_temp0';
  }

  @override
  String get clockTitle => 'Temporizador';

  @override
  String get clockDescription =>
      'Muestra una cuenta atrás, un cronómetro o la hora local en el directo.';

  @override
  String get clockMode => 'Modo';

  @override
  String get clockCountdown => 'Cuenta atrás';

  @override
  String get clockStopwatch => 'Cronómetro';

  @override
  String get clockLocalTime => 'Hora local';

  @override
  String get clockLabel => 'Etiqueta';

  @override
  String get clockDuration => 'Duración en segundos (1–86 400)';

  @override
  String get clockSound => 'Sonido al terminar';

  @override
  String get clockSoundNone => 'Sin sonido';

  @override
  String get clockStyle => 'Estilo de la página';

  @override
  String get clockStyleBig => 'Grande';

  @override
  String get clockStyleCompact => 'Compacto';

  @override
  String get clockStyleRing => 'Anillo de progreso (cuenta atrás)';

  @override
  String get clockEnded => '¡Se acabó el tiempo!';

  @override
  String get clockPause => 'Pausar';

  @override
  String get clockReset => 'Reiniciar';

  @override
  String get clockPlusMinute => '+1 min';

  @override
  String get clockMinusMinute => '−1 min';

  @override
  String get pollSaveSetup => 'Guardar configuración actual';

  @override
  String get pollRenameSetup => 'Cambiar nombre de la encuesta guardada';

  @override
  String get pollDeleteSetup => 'Eliminar encuesta guardada';

  @override
  String get pollSetupName => 'Nombre de la configuración';

  @override
  String get pollSetupDuplicate => 'Ese nombre ya está en uso.';

  @override
  String get pollSavedSetups => 'Encuestas guardadas';

  @override
  String get pollSetupLimit =>
      'Elimina una encuesta guardada para agregar otra.';

  @override
  String get giveawayDrawCount => 'Ganadores por sorteo';

  @override
  String giveawayDrawMany(int count) {
    return 'Sacar $count ganadores';
  }

  @override
  String get giveawayHistory => 'Historial de sorteos';

  @override
  String get giveawayHistoryEmpty => 'Todavía no hay rondas terminadas.';

  @override
  String get giveawayClearHistory => 'Borrar historial';

  @override
  String giveawayStartedAt(String date) {
    return 'Inicio $date';
  }

  @override
  String giveawayEndedAt(String date) {
    return 'Fin $date';
  }

  @override
  String get giveawayNoWinners => 'Sin ganadores';

  @override
  String giveawayAllWinners(int count) {
    return 'Todos los ganadores de esta ronda ($count)';
  }

  @override
  String get galleryScoreboard => 'Marcador';

  @override
  String get galleryScoreboardDescription =>
      'Muestra los valores actuales de los contadores de reglas que elijas.';

  @override
  String get galleryScoreboardCounters =>
      'Nombres de los contadores separados por comas (hasta 8)';

  @override
  String get galleryScoreboardLabels =>
      'Etiquetas en el mismo orden, separadas por comas';

  @override
  String get galleryScoreboardLayout => 'Distribución';

  @override
  String get galleryWordCloud => 'Nube de palabras';

  @override
  String get galleryWordCloudDescription =>
      'Muestra las palabras más frecuentes de los últimos cinco minutos de chat.';

  @override
  String get galleryWordCloudMinLength => 'Longitud mínima de palabra';

  @override
  String get galleryWordCloudMaxWords => 'Máximo de palabras';

  @override
  String get galleryWordCloudRefresh => 'Intervalo de actualización (segundos)';

  @override
  String get galleryEmoteWall => 'Muro de emotes';

  @override
  String get galleryEmoteWallDescription =>
      'Haz flotar por la pantalla los emotes que llegan al chat.';

  @override
  String get galleryEmoteWallMax => 'Máximo de emotes en pantalla';

  @override
  String get galleryEmoteWallSize => 'Tamaño del emote (píxeles)';

  @override
  String get galleryEmoteWallLifetime => 'Tiempo en pantalla (segundos)';

  @override
  String get clockPaused => 'En pausa';

  @override
  String get galleryScoreboardHome => 'Local';

  @override
  String get galleryScoreboardAway => 'Visitante';

  @override
  String get galleryScoreboardRow => 'Fila';

  @override
  String get galleryScoreboardColumn => 'Columna';

  @override
  String get backupExportEverything => 'Exportar todo';

  @override
  String get backupRestoreEverything => 'Restaurar todo';

  @override
  String get backupFileType => 'Copia de Airstream';

  @override
  String get backupRestoreReview =>
      'Se reemplazarán tus ajustes, plantillas y biblioteca de medios. Airstream guardará antes una copia de tus datos actuales.';

  @override
  String get backupMissingExternalAudio =>
      'Faltan estos archivos de referencia de voz o de sonido de alertas. Elige otros después de restaurar.';

  @override
  String backupRestoreContents(
      int rules, int templates, int media, String created) {
    return 'Ajustes\nReglas: $rules\nPlantillas: $templates\nArchivos multimedia: $media\nFecha de creación: $created';
  }

  @override
  String get backupRestoreConfirm => 'Restaurar';

  @override
  String get backupExportDone => 'Se exportó la copia completa.';

  @override
  String get backupExportOmittedAudio =>
      'Estos archivos de audio superan el tamaño máximo por archivo y quedaron fuera de la copia de seguridad.';

  @override
  String get backupExportAudioSizeLimit =>
      'Estos archivos de audio superaron el límite por archivo o el espacio disponible en la copia de seguridad y quedaron fuera.';

  @override
  String get templateLibrarySizeLimit =>
      'La biblioteca de plantillas puede ocupar hasta 100 MB.';

  @override
  String get backupRestoreDone => 'Se restauró la copia completa.';

  @override
  String get backupExportError =>
      'No se pudo exportar la copia completa. Revisa el destino y los archivos de tus bibliotecas.';

  @override
  String get backupRestoreError =>
      'No se pudo restaurar la copia. Revisa el espacio disponible y cierra los programas que usan los archivos de las bibliotecas.';

  @override
  String get backupInvalid =>
      'El archivo está dañado o no es una copia completa de Airstream.';

  @override
  String get backupUnsupportedVersion =>
      'Esta versión de la copia no es compatible.';

  @override
  String get backupUnsafePath =>
      'La copia contiene una ruta de archivo que no es segura.';

  @override
  String get backupSizeLimit =>
      'Un archivo o una biblioteca supera los límites de la copia.';

  @override
  String get backupMediaInvalid =>
      'Falta un archivo multimedia o no coincide con su entrada en la biblioteca.';

  @override
  String get backupRollbackError =>
      'La restauración se interrumpió y no se pudo revertir de forma automática. La copia de seguridad y las carpetas originales siguen en el disco.';

  @override
  String get settingsSearchHint => 'Buscar ajustes';

  @override
  String get settingsSearchEmpty => 'No se encontraron ajustes';

  @override
  String get settingsSearchConnectionWords =>
      'cuentas canales sesión transmisión';

  @override
  String get settingsSearchVoiceWords => 'tts texto a voz lector narración';

  @override
  String get settingsSearchCaptionWords =>
      'subtítulos transcripción accesibilidad';

  @override
  String get settingsSearchBackupWords =>
      'archivo zip migración recuperación respaldo';

  @override
  String get settingsSearchMediaWords =>
      'recursos archivos mp3 mp4 imágenes video sonido';

  @override
  String get settingsSearchAppearanceWords => 'tema colores tipografía';

  @override
  String get settingsSearchRulesWords =>
      'automatización webhook botones acciones';

  @override
  String get mediaSearch => 'Buscar medios por nombre';

  @override
  String get mediaNoMatches => 'No se encontraron medios';

  @override
  String get mediaPreview => 'Vista previa';

  @override
  String get mediaPreviewUnavailable =>
      'No hay vista previa para este archivo.';

  @override
  String get mediaPreviewPlay => 'Reproducir';

  @override
  String get mediaPreviewStop => 'Detener';

  @override
  String get mediaRename => 'Cambiar nombre';

  @override
  String get mediaDisplayName => 'Nombre visible';

  @override
  String get mediaRenameInvalid =>
      'Escribe un nombre sin barras ni caracteres de control.';

  @override
  String get mediaRenameFailed => 'No se pudo guardar el nombre nuevo.';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

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
      'Handle, ID de canal, ID de video o URL de YouTube';

  @override
  String get twitchChannel => 'Canal de Twitch';

  @override
  String get kickSlug => 'Slug de Kick';

  @override
  String get startChat => 'Iniciar chat';

  @override
  String get stopChat => 'Detener chat';

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
  String get horizontalPadding => 'Padding horizontal';

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
      'Los usuarios y palabras bloqueados se filtran en el flujo de mensajes, por lo que se eliminan del chat local, TTS y el overlay Shelf.';

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
  String ttsModelRemovalFailed(String error) {
    return 'No se pudo eliminar el modelo TTS: $error';
  }

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
      'Conecta con OBS por WebSocket para mostrar el estado del stream, grabación y escena dentro de Airstream.';

  @override
  String get webSocketHost => 'Host WebSocket';

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
  String get hudElements => 'Elementos del HUD';

  @override
  String get globalHud => 'Global';

  @override
  String get streamHud => 'Stream';

  @override
  String get recordingHud => 'Grabación';

  @override
  String get streamState => 'Estado del stream';

  @override
  String get currentScene => 'Escena actual';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get fps => 'FPS';

  @override
  String get droppedFrames => 'Frames perdidos';

  @override
  String get recordingState => 'Estado de grabación';

  @override
  String get recordingDuration => 'Duración de grabación';

  @override
  String get recordingSize => 'Tamaño de grabación';

  @override
  String get obsDisabledHelp =>
      'Actívalo para ingresar el host, la contraseña y conectar cuando quieras.';

  @override
  String get overlayServer => 'Servidor de overlay';

  @override
  String get overlayServerDescription =>
      'Activa una fuente local de navegador para OBS. Cuando está activo, Airstream sirve una URL de overlay que puedes pegar en OBS.';

  @override
  String get port => 'Puerto';

  @override
  String get chatObsUrl => 'URL de chat para OBS';

  @override
  String get chatObsUrlDescription =>
      'Usa este enlace como Browser Source para el chat en OBS.';

  @override
  String get chatOverlayUrlCopied => 'URL del overlay de chat copiada';

  @override
  String get alertsObsUrl => 'URL de alertas para OBS';

  @override
  String get alertsObsUrlDescription =>
      'Úsalo como una Browser Source separada para Super Chats y membresías.';

  @override
  String get alertsOverlayUrlCopied => 'URL del overlay de alertas copiada';

  @override
  String get oneOverlayClientConnected => '1 cliente de overlay conectado';

  @override
  String overlayClientsConnected(int count) {
    return '$count clientes de overlay conectados';
  }

  @override
  String get overlayReloadSent => 'Recarga del overlay enviada';

  @override
  String get noOverlayClientConnected =>
      'No hay clientes de overlay conectados';

  @override
  String get reloadOverlay => 'Recargar overlay';

  @override
  String get alerts => 'Alertas';

  @override
  String get alertsDescription =>
      'Los Super Chats de YouTube y eventos de membresía se muestran en /alerts. El payload de alerta mantiene datos de plataforma para agregar Twitch y Kick más adelante.';

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
      'Abre primero el overlay de alertas en OBS/navegador';

  @override
  String get overlayMode => 'Modo overlay';

  @override
  String get chromaKey => 'Chroma key';

  @override
  String get showGrid => 'Mostrar grilla';

  @override
  String get hideScrollbar => 'Ocultar barra de desplazamiento';

  @override
  String get chromaColor => 'Color chroma';

  @override
  String get platformDisplay => 'Visualización de plataforma';

  @override
  String get twitchAccent => 'Acento Twitch';

  @override
  String get kickAccent => 'Acento Kick';

  @override
  String get styleSettings => 'Ajustes de estilo';

  @override
  String get lineHeight => 'Altura de línea';

  @override
  String get fontWeight => 'Grosor de fuente';

  @override
  String get overlayBg => 'Fondo del overlay';

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
  String get idle => 'Inactivo';

  @override
  String assetsProgress(int loaded, int total) {
    return '$loaded/$total assets';
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
  String get sendCaptionsToObs => 'Enviar al overlay de OBS';

  @override
  String get noiseReduction => 'Reducir el ruido de fondo del micrófono';

  @override
  String get voiceCommandsObs => 'Comandos de voz para OBS';

  @override
  String get wakeWord => 'Palabra de activación';

  @override
  String get voiceCommandsExamples =>
      'Ejemplos: “Airstream inicia grabación”, “Airstream pausa grabación” o “Airstream cambia a escena cámara”.';

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
  String get ttsAndVoice => 'TTS y Voz';

  @override
  String get obsAndOverlay => 'OBS y Overlay';

  @override
  String get systemTab => 'Sistema y Ventana';

  @override
  String get desktopWindow => 'Ventana de escritorio';

  @override
  String get frameless => 'Sin marco';

  @override
  String get framelessDescription =>
      'Sin barra de título, bordes transparentes';

  @override
  String get clickThrough => 'Click-Through';

  @override
  String get clickThroughDescription =>
      'Los clics pasan a través de la ventana (WS_EX_TRANSPARENT)';

  @override
  String get alwaysOnTop => 'Siempre visible';

  @override
  String get alwaysOnTopDescription =>
      'Mantener sobre todas las demás ventanas';

  @override
  String get antiCapture => 'Anti-Captura / Privacidad';

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
  String get toggleClickThroughShortcut => 'Alternar Click-Through';

  @override
  String get alwaysOnTopActiveTooltip =>
      'Desactivar Siempre visible (Ctrl+Shift+P)';

  @override
  String get alwaysOnTopInactiveTooltip => 'Siempre visible (Ctrl+Shift+P)';

  @override
  String get clickThroughActiveTooltip =>
      'Click-Through activo. Desactivar (Ctrl+Shift+C)';

  @override
  String get clickThroughInactiveTooltip =>
      'Activar Click-Through (Ctrl+Shift+C)';

  @override
  String get antiCaptureActiveTooltip =>
      'Modo privacidad activo — ventana oculta de capturas/OBS';

  @override
  String get antiCaptureInactiveTooltip => 'Ocultar de capturas / screen share';

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
  String get ttsCardTitle => 'Lector de Voz (TTS)';

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
}

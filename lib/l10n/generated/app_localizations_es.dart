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
  String get english => 'Ingles';

  @override
  String get spanish => 'Espanol';

  @override
  String get listeningForMessages => 'Escuchando mensajes...';

  @override
  String get channelsSavedStartPrompt =>
      'Canales guardados.\nPulsa Iniciar cuando quieras escuchar.';

  @override
  String get noChannelsConfigured =>
      'No hay canales configurados.\nConfiguralos en el menu lateral.';

  @override
  String get start => 'Iniciar';

  @override
  String get stop => 'Detener';

  @override
  String get hideSidebarTooltip => 'Ocultar menu lateral (Ctrl+B)';

  @override
  String get showSidebarTooltip => 'Mostrar menu lateral (Ctrl+B)';

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
  String get fontSize => 'Tamano de fuente';

  @override
  String get backgroundOpacity => 'Opacidad del fondo';

  @override
  String get bubbleOpacity => 'Opacidad de burbuja';

  @override
  String get borderRadius => 'Radio de borde';

  @override
  String get messageGap => 'Espacio entre mensajes';

  @override
  String get avatars => 'Avatares';

  @override
  String get platformIcon => 'Icono de plataforma';

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
  String get blockedUsersHelp => 'Uno por linea. El prefijo @ es opcional.';

  @override
  String get blockedWordsOrPhrases => 'Palabras o frases bloqueadas';

  @override
  String get blockedWordsHelp =>
      'Las palabras sueltas respetan limites de token. Las frases se comparan despues de normalizar.';

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
  String get separatorText => 'Texto separador';

  @override
  String get voice => 'Voz';

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
      'Activalo para configurar voz, idioma y probar la reproduccion.';

  @override
  String get obsIntegration => 'Integracion OBS';

  @override
  String get obsDescription =>
      'Conecta con OBS por WebSocket para mostrar el estado en vivo y la escena actual dentro de Airstream.';

  @override
  String get webSocketHost => 'Host WebSocket';

  @override
  String get password => 'Contrasena';

  @override
  String get optionalPassword => 'Contrasena opcional';

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
  String get obsDisabledHelp =>
      'Activalo para ingresar el host, la contrasena y conectar cuando quieras.';

  @override
  String get overlayServer => 'Servidor de overlay';

  @override
  String get overlayServerDescription =>
      'Activa una fuente local de navegador para OBS. Cuando esta activo, Airstream sirve una URL de overlay que puedes pegar en OBS.';

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
      'Usalo como una Browser Source separada para Super Chats y membresias.';

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
      'Los Super Chats de YouTube y eventos de membresia se muestran en /alerts. El payload de alerta mantiene datos de plataforma para agregar Twitch y Kick mas adelante.';

  @override
  String get alertFontSize => 'Tamano de fuente de alerta';

  @override
  String get alertDuration => 'Duracion de alerta';

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
  String get hideScrollbar => 'Ocultar scrollbar';

  @override
  String get chromaColor => 'Color chroma';

  @override
  String get platformDisplay => 'Visualizacion de plataforma';

  @override
  String get twitchAccent => 'Acento Twitch';

  @override
  String get kickAccent => 'Acento Kick';

  @override
  String get styleSettings => 'Ajustes de estilo';

  @override
  String get lineHeight => 'Altura de linea';

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
  String get messageDesign => 'Diseno de mensajes';

  @override
  String get bubbleBackground => 'Fondo de burbuja';

  @override
  String get textAlignment => 'Alineacion de texto';

  @override
  String get cornerRadius => 'Radio de esquina';

  @override
  String get verticalGap => 'Espacio vertical';

  @override
  String get maxMessages => 'Maximo de mensajes';

  @override
  String get messageLifetime => 'Duracion del mensaje';

  @override
  String get superChatColorBar => 'Barra de color SuperChat';

  @override
  String get superChatBarColor => 'Color de barra SuperChat';

  @override
  String get superChatWidth => 'Ancho SuperChat';

  @override
  String get animation => 'Animacion';

  @override
  String get entrance => 'Entrada';

  @override
  String get duration => 'Duracion';

  @override
  String get transform3d => 'Transformacion 3D';

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
      'Activalo para elegir un puerto y mostrar la URL de OBS.';

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
}

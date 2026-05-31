// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get listeningForMessages => 'Listening for messages...';

  @override
  String get channelsSavedStartPrompt =>
      'Channels saved.\nPress Start when you want to listen.';

  @override
  String get noChannelsConfigured =>
      'No channels configured.\nConfigure channels in the sidebar.';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get hideSidebarTooltip => 'Hide sidebar (Ctrl+B)';

  @override
  String get showSidebarTooltip => 'Show sidebar (Ctrl+B)';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get clear => 'Clear';

  @override
  String get connections => 'Connections';

  @override
  String get youtubeInputLabel =>
      'YouTube handle, channel ID, video ID, or URL';

  @override
  String get twitchChannel => 'Twitch channel';

  @override
  String get kickSlug => 'Kick slug';

  @override
  String get startChat => 'Start chat';

  @override
  String get stopChat => 'Stop chat';

  @override
  String get appearance => 'Appearance';

  @override
  String get fontSize => 'Font size';

  @override
  String get backgroundOpacity => 'Background opacity';

  @override
  String get bubbleOpacity => 'Bubble opacity';

  @override
  String get borderRadius => 'Border radius';

  @override
  String get messageGap => 'Message gap';

  @override
  String get avatars => 'Avatars';

  @override
  String get platformIcon => 'Platform icon';

  @override
  String get badges => 'Badges';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get bubble => 'Bubble';

  @override
  String get bubbleShadow => 'Bubble shadow';

  @override
  String get filters => 'Filters';

  @override
  String get filtersDescription =>
      'Blocked users and words are filtered in the message pipeline, so they are removed for your local chat view, TTS and the Shelf overlay.';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get blockedUsersHelp => 'One per line. Prefixing with @ is optional.';

  @override
  String get blockedWordsOrPhrases => 'Blocked words or phrases';

  @override
  String get blockedWordsHelp =>
      'Single words respect token boundaries. Phrases are matched after normalization.';

  @override
  String get ttsDescription =>
      'Read chat messages aloud with configurable voice, language and command behavior.';

  @override
  String get enabled => 'Enabled';

  @override
  String get membersOnly => 'Members only';

  @override
  String get commandMode => 'Command mode (custom prefix)';

  @override
  String get commandPrefix => 'Command prefix';

  @override
  String get separatorText => 'Separator text';

  @override
  String get voice => 'Voice';

  @override
  String get testText => 'Test text';

  @override
  String get playingTts => 'Playing TTS...';

  @override
  String get loadingTts => 'Loading TTS...';

  @override
  String get testTts => 'Test TTS';

  @override
  String get ttsDisabledHelp =>
      'Turn it on to configure voice, language and test playback.';

  @override
  String get obsIntegration => 'OBS Integration';

  @override
  String get obsDescription =>
      'Connect to OBS over WebSocket to show live status and the current program scene inside Airstream.';

  @override
  String get webSocketHost => 'WebSocket host';

  @override
  String get password => 'Password';

  @override
  String get optionalPassword => 'Optional password';

  @override
  String get connectingToObs => 'Connecting to OBS...';

  @override
  String get disconnectObs => 'Disconnect OBS';

  @override
  String get reconnectObs => 'Reconnect OBS';

  @override
  String get connectObs => 'Connect OBS';

  @override
  String get hudElements => 'HUD Elements';

  @override
  String get streamState => 'Stream state';

  @override
  String get currentScene => 'Current scene';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get fps => 'FPS';

  @override
  String get droppedFrames => 'Dropped frames';

  @override
  String get obsDisabledHelp =>
      'Turn it on to enter the OBS host, password and connect on demand.';

  @override
  String get overlayServer => 'Overlay Server';

  @override
  String get overlayServerDescription =>
      'Enable a local browser source for OBS. When active, Airstream serves an overlay URL that you can paste into OBS.';

  @override
  String get port => 'Port';

  @override
  String get chatObsUrl => 'Chat OBS URL';

  @override
  String get chatObsUrlDescription =>
      'Use this link as a Browser Source for chat in OBS.';

  @override
  String get chatOverlayUrlCopied => 'Chat overlay URL copied';

  @override
  String get alertsObsUrl => 'Alerts OBS URL';

  @override
  String get alertsObsUrlDescription =>
      'Use this as a separate Browser Source for Super Chats and memberships.';

  @override
  String get alertsOverlayUrlCopied => 'Alerts overlay URL copied';

  @override
  String get oneOverlayClientConnected => '1 overlay client connected';

  @override
  String overlayClientsConnected(int count) {
    return '$count overlay clients connected';
  }

  @override
  String get overlayReloadSent => 'Overlay reload sent';

  @override
  String get noOverlayClientConnected => 'No overlay client connected';

  @override
  String get reloadOverlay => 'Reload Overlay';

  @override
  String get alerts => 'Alerts';

  @override
  String get alertsDescription =>
      'YouTube Super Chats and membership events show on /alerts. The alert payload keeps platform data so Twitch and Kick can be added later.';

  @override
  String get alertFontSize => 'Alert font size';

  @override
  String get alertDuration => 'Alert duration';

  @override
  String get alertAvatars => 'Alert avatars';

  @override
  String get testAlertSent => 'Test alert sent';

  @override
  String get openAlertsOverlayFirst =>
      'Open the alerts overlay in OBS/browser first';

  @override
  String get overlayMode => 'Overlay Mode';

  @override
  String get chromaKey => 'Chroma key';

  @override
  String get showGrid => 'Show grid';

  @override
  String get hideScrollbar => 'Hide scrollbar';

  @override
  String get chromaColor => 'Chroma color';

  @override
  String get platformDisplay => 'Platform Display';

  @override
  String get twitchAccent => 'Twitch accent';

  @override
  String get kickAccent => 'Kick accent';

  @override
  String get styleSettings => 'Style Settings';

  @override
  String get lineHeight => 'Line height';

  @override
  String get fontWeight => 'Font weight';

  @override
  String get overlayBg => 'Overlay bg';

  @override
  String get textShadow => 'Text shadow';

  @override
  String get textOutline => 'Text outline';

  @override
  String get outlineColor => 'Outline color';

  @override
  String get messageDesign => 'Message Design';

  @override
  String get bubbleBackground => 'Bubble background';

  @override
  String get textAlignment => 'Text alignment';

  @override
  String get cornerRadius => 'Corner radius';

  @override
  String get verticalGap => 'Vertical gap';

  @override
  String get maxMessages => 'Max messages';

  @override
  String get messageLifetime => 'Message lifetime';

  @override
  String get superChatColorBar => 'SuperChat color bar';

  @override
  String get superChatBarColor => 'SuperChat bar color';

  @override
  String get superChatWidth => 'SuperChat width';

  @override
  String get animation => 'Animation';

  @override
  String get entrance => 'Entrance';

  @override
  String get duration => 'Duration';

  @override
  String get transform3d => '3D Transform';

  @override
  String get enable3dEffect => 'Enable 3D effect';

  @override
  String get perspective => 'Perspective';

  @override
  String get rotateX => 'Rotate X';

  @override
  String get rotateY => 'Rotate Y';

  @override
  String get rotateZ => 'Rotate Z';

  @override
  String get skewX => 'Skew X';

  @override
  String get scale => 'Scale';

  @override
  String get overlayDisabledHelp =>
      'Turn it on to choose a port and reveal the OBS URL.';

  @override
  String get ready => 'Ready';

  @override
  String get checking => 'Checking';

  @override
  String get downloading => 'Downloading';

  @override
  String get loading => 'Loading';

  @override
  String get error => 'Error';

  @override
  String get idle => 'Idle';

  @override
  String assetsProgress(int loaded, int total) {
    return '$loaded/$total assets';
  }

  @override
  String currentFile(String file) {
    return 'Current: $file';
  }

  @override
  String voiceStatus(String voice) {
    return 'Voice: $voice';
  }

  @override
  String maleVoice(String number) {
    return 'Male $number';
  }

  @override
  String femaleVoice(String number) {
    return 'Female $number';
  }

  @override
  String platformError(String platform, String error) {
    return '$platform error: $error';
  }

  @override
  String get copy => 'Copy';

  @override
  String get testAlerts => 'Test alerts';

  @override
  String get superChat => 'SuperChat';

  @override
  String get noMessage => 'No message';

  @override
  String get member => 'Member';
}

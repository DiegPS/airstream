// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get obsPageChatTitle => 'Airstream Overlay';

  @override
  String get obsPageAlertsTitle => 'Airstream Alerts';

  @override
  String get obsPageCaptionsTitle => 'Airstream Captions';

  @override
  String get obsPageTimerTitle => 'Airstream Timer';

  @override
  String get obsPagePollTitle => 'Airstream Poll';

  @override
  String get textAndNames => 'Text and names';

  @override
  String get chatFontFamily => 'Font family';

  @override
  String get chatFontWindows => 'Windows fonts';

  @override
  String get chatFontGoogle => 'Google Fonts for OBS';

  @override
  String get chatFontOther => 'Other installed font';

  @override
  String get chatFontInvalid =>
      'Enter 1–48 letters (A–Z), numbers, spaces or hyphens.';

  @override
  String get chatFontGoogleNote =>
      'In the app window this font is used only if it is installed; OBS pages download it';

  @override
  String get nameColorMode => 'Name colors';

  @override
  String get nameColorPlatform => 'Viewer’s color';

  @override
  String get nameColorPlatformThenGenerated => 'Viewer’s color or generated';

  @override
  String get nameColorGenerated => 'Generated for everyone';

  @override
  String get nameColorSingle => 'Single color';

  @override
  String get nameColorBrand => 'Platform brand color';

  @override
  String get nameRoleColors => 'Owner, moderator and VIP colors';

  @override
  String get nameReadability => 'Improve readability';

  @override
  String get nameColorHex => 'Hex color';

  @override
  String get nameColorUse => 'Use color';

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
  String get youtubeDualMode => 'Horizontal + vertical';

  @override
  String get youtubeDualModeDescription =>
      'Connect both YouTube broadcasts at the same time';

  @override
  String get youtubeHorizontalUrl => 'Horizontal stream URL';

  @override
  String get youtubeVerticalUrl => 'Vertical stream URL';

  @override
  String get youtubeStreamUrlHint => 'https://youtube.com/watch?v=...';

  @override
  String get youtubeInvalidStreamUrl =>
      'Enter a direct YouTube video or live URL';

  @override
  String get youtubeDuplicateStreamUrl => 'Use a different broadcast URL';

  @override
  String get youtubeStreamBadges => 'Horizontal / vertical badge';

  @override
  String get youtubeLiveAudience => 'YouTube live audience';

  @override
  String get youtubeHorizontal => 'Horizontal';

  @override
  String get youtubeVertical => 'Vertical';

  @override
  String youtubeViewers(String count) {
    return '$count viewers';
  }

  @override
  String youtubeTotalViewers(String count) {
    return '$count total';
  }

  @override
  String get youtubeAudienceUnavailable => 'Audience unavailable';

  @override
  String get twitchChannel => 'Twitch channel';

  @override
  String get kickSlug => 'Kick slug';

  @override
  String get startChat => 'Start chat';

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
  String get maxMessageWidth => 'Max message width';

  @override
  String get horizontalPadding => 'Horizontal padding';

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
      'Blocked users and words are removed from your chat, the TTS reader and the OBS overlay.';

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
  String get commandPrefixHint => '!v';

  @override
  String get ignoreCommandCase => 'Ignore uppercase/lowercase in prefix';

  @override
  String get separatorText => 'Separator text';

  @override
  String get voice => 'Voice';

  @override
  String get ttsEngine => 'Voice engine';

  @override
  String get quality => 'Quality';

  @override
  String get qualityFast => 'Fast (4 steps)';

  @override
  String get qualityHigh => 'High (6 steps)';

  @override
  String get qualityBalanced => 'Balanced (8 steps)';

  @override
  String get qualityMaximum => 'Maximum (12 steps)';

  @override
  String get speed => 'Speed';

  @override
  String get removeTtsModel => 'Remove downloaded model';

  @override
  String get downloadTtsModel => 'Download model';

  @override
  String get removeTtsModelConfirmation =>
      'TTS will be disabled and the selected model will be deleted from this device. It can be downloaded again later.';

  @override
  String removeTtsModelTitle(String model) {
    return 'Remove $model?';
  }

  @override
  String removeTtsModelConfirmationNamed(String model) {
    return '$model will be deleted from this device and TTS will be turned off. You can download it again later.';
  }

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

  @override
  String get ttsModelRemoved => 'The TTS model was removed.';

  @override
  String get ttsModelRemovalFailed => 'The TTS model could not be removed.';

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
      'Connect to OBS over WebSocket to show stream, recording and scene status inside Airstream.';

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
  String get globalHud => 'Global';

  @override
  String get streamHud => 'Stream';

  @override
  String get recordingHud => 'Recording';

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
  String get recordingState => 'Recording state';

  @override
  String get recordingDuration => 'Recording duration';

  @override
  String get recordingSize => 'Recording size';

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
      'Use this as a separate Browser Source for Super Chats, memberships and the chat messages you show on stream.';

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
      'Shows YouTube Super Chats and memberships, Twitch Bits, subscriptions, gifts and raids, and Kick subscriptions, gifts, hosts and Kicks on /alerts. Each type can be switched off below.';

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
  String get chatConnectionsFailed =>
      'AirStream could not connect to any configured chat. Review the red platform errors and try again.';

  @override
  String get retry => 'Retry';

  @override
  String get obsPasswordNotSaved => 'OBS password not saved';

  @override
  String get youtubeBroadcastEnded => 'YouTube broadcast ended';

  @override
  String get youtubePartiallyConnected =>
      'YouTube: one of the two streams could not connect';

  @override
  String retryPlatform(String platform) {
    return 'Retry $platform';
  }

  @override
  String get chatPartiallyConnected =>
      'Some chats are connected. Review the platforms marked in red.';

  @override
  String get overlayStarting => 'Starting the local overlay server…';

  @override
  String overlayStartFailed(int port) {
    return 'The overlay server could not start on port $port. The port may already be in use or blocked.';
  }

  @override
  String get invalidOverlayPort => 'Enter a port from 1 to 65535.';

  @override
  String get ttsPlaybackFailed =>
      'The voice could not be generated or played. Check the selected model and audio output.';

  @override
  String get voiceCommandFailed =>
      'The voice command could not be completed. Check the OBS connection and try again.';

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

  @override
  String get voiceCloning => 'Voice cloning (WAV)';

  @override
  String usingBundledVoice(String voice) {
    return 'Using bundled sample: $voice';
  }

  @override
  String get chooseWav => 'Choose WAV';

  @override
  String get useBundledSample => 'Use bundled sample';

  @override
  String get referenceTranscript => 'Exact WAV transcript';

  @override
  String get referenceTranscriptHint => 'Type exactly what the audio says…';

  @override
  String get localCaptions => 'Local captions';

  @override
  String get captionsDescription =>
      'Listens to your microphone, detects speech, and creates live captions or translations in real-time without sending audio to the Internet.';

  @override
  String get captionsEnabled => 'Enabled';

  @override
  String get spokenLanguage => 'Spoken language';

  @override
  String get captionOutput => 'Output / translation';

  @override
  String get sendCaptionsToObs => 'Send to OBS overlay';

  @override
  String get noiseReduction => 'Reduce microphone background noise';

  @override
  String get voiceCommandsObs => 'OBS voice commands';

  @override
  String get wakeWord => 'Wake word';

  @override
  String get voiceCommandsExamples =>
      'Examples: “Airstream start recording”, “Airstream pause recording”, or “Airstream switch to scene camera”. German and French work too, for example “Airstream starte die Aufnahme”.';

  @override
  String get voiceCommandsTranslationNote =>
      'With caption translation on, commands are read from the translated text. Recording commands work in English, Spanish, German and French; a scene name may come out translated.';

  @override
  String get captionModelManual => 'Offline captions · manual download';

  @override
  String get downloadCaptionModel => 'Download caption model';

  @override
  String get captionStatusIdle => 'Offline captions are off.';

  @override
  String get captionStatusMissingModel =>
      'Download offline speech recognition to begin.';

  @override
  String get captionStatusDownloading =>
      'Downloading offline speech recognition…';

  @override
  String get captionStatusLoading => 'Preparing offline speech recognition…';

  @override
  String get captionStatusListening => 'Listening to the microphone…';

  @override
  String get captionStatusTranscribing => 'Creating captions locally…';

  @override
  String get captionStatusError => 'Offline captions could not start.';

  @override
  String get obsCaptions => 'OBS captions';

  @override
  String get obsCaptionsDescription =>
      'Independent browser source for live captions and translation.';

  @override
  String get ttsAndVoice => 'TTS & Voice';

  @override
  String get obsAndOverlay => 'OBS & Overlay';

  @override
  String get systemTab => 'System & Window';

  @override
  String get desktopWindow => 'Desktop Window';

  @override
  String get clickThrough => 'Click-Through';

  @override
  String get clickThroughDescription =>
      'Clicks go to the window behind Airstream. Press Ctrl+Shift+C to turn it off.';

  @override
  String get alwaysOnTop => 'Always on Top';

  @override
  String get alwaysOnTopDescription => 'Keep on top of all other windows';

  @override
  String get antiCapture => 'Anti-Capture / Privacy';

  @override
  String get antiCaptureDescription =>
      'Hide window from screen capture and OBS';

  @override
  String get keyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get toggleTopBarShortcut => 'Toggle top bar';

  @override
  String get toggleAlwaysOnTopShortcut => 'Toggle Always on Top';

  @override
  String get toggleClickThroughShortcut => 'Toggle Click-Through';

  @override
  String get globalClickThroughShortcutUnavailable =>
      'Click-Through needs Ctrl+Shift+C to turn it back off, and another app is using that shortcut. Close that app and try again.';

  @override
  String get alwaysOnTopActiveTooltip => 'Disable Always on Top (Ctrl+Shift+P)';

  @override
  String get alwaysOnTopInactiveTooltip => 'Always on Top (Ctrl+Shift+P)';

  @override
  String get clickThroughActiveTooltip =>
      'Click-Through active. Disable (Ctrl+Shift+C)';

  @override
  String get clickThroughInactiveTooltip =>
      'Enable Click-Through (Ctrl+Shift+C)';

  @override
  String get antiCaptureActiveTooltip =>
      'Privacy mode active — window hidden from screen share/OBS';

  @override
  String get antiCaptureInactiveTooltip => 'Hide from screen share / captures';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restore => 'Restore';

  @override
  String get close => 'Close';

  @override
  String get obsStatusConnecting => 'OBS: Connecting...';

  @override
  String get obsStatusDisconnected => 'OBS: Disconnected';

  @override
  String get obsStatusLiveAndRec => 'OBS: Live + Rec';

  @override
  String get obsStatusLive => 'OBS: Live';

  @override
  String get obsStatusRecording => 'OBS: Recording';

  @override
  String get obsStatusConnected => 'OBS: Connected';

  @override
  String obsScenePrefix(String scene) {
    return 'Scene: $scene';
  }

  @override
  String get obsOutputLive => 'Output: Live';

  @override
  String get obsOutputOffline => 'Output: Offline';

  @override
  String get obsRecordingPaused => 'Recording: Paused';

  @override
  String get obsRecordingActive => 'Recording: Active';

  @override
  String get ttsCardTitle => 'Voice Reader (TTS)';

  @override
  String voiceStatusBadge(String status) {
    return 'Voice: $status';
  }

  @override
  String get voiceStatusNotDownloaded => 'Not downloaded';

  @override
  String get ttsSelectedModel => 'TTS';

  @override
  String ttsModelStatusBadge(String model, String status) {
    return '$model · $status';
  }

  @override
  String ttsModelTechnicalDetails(
      String download, String installed, String license, String version) {
    return 'Download $download · Installed $installed · $license · Version $version';
  }

  @override
  String ttsModelStorageDetails(String download, String installed) {
    return 'Download $download · Disk space $installed';
  }

  @override
  String ttsModelVariant(String variant) {
    return 'Variant: $variant';
  }

  @override
  String get ttsModelSupertonicDescription =>
      '10 built-in voices optimized for quality and speed.';

  @override
  String get ttsModelPiperMexicoDescription =>
      'Fast, efficient single-speaker synthesis.';

  @override
  String get ttsModelPiperSpainDescription =>
      'Fast, efficient single-speaker synthesis.';

  @override
  String get ttsModelKittenDescription =>
      'Compact model with four female and four male voices.';

  @override
  String get ttsModelKokoroDescription =>
      'Expressive model with 11 named voices.';

  @override
  String get ttsModelMatchaDescription =>
      'Smooth, natural single-voice synthesis.';

  @override
  String get ttsModelPocketDescription =>
      'Fast zero-shot voice cloning from a reference WAV.';

  @override
  String get ttsModelZipVoiceDescription =>
      'Advanced voice cloning using a WAV and its exact transcript.';

  @override
  String get spanishMexico => 'Spanish (Mexico)';

  @override
  String get spanishSpain => 'Spanish (Spain)';

  @override
  String get ttsStatusIdleDescription =>
      'Download this exact model when you want to use it.';

  @override
  String get ttsStatusCheckingDescription =>
      'Checking local model files and integrity…';

  @override
  String get ttsStatusDownloadingDescription =>
      'Downloading verified model files…';

  @override
  String get ttsStatusLoadingDescription =>
      'Loading the selected model into memory…';

  @override
  String get ttsStatusReadyDescription => 'Ready for local synthesis.';

  @override
  String get ttsStatusErrorDescription =>
      'The selected model could not be prepared.';

  @override
  String ttsInferenceSteps(int count) {
    return '$count inference steps';
  }

  @override
  String get ttsTestTextHint => 'Type something to test the selected TTS…';

  @override
  String get ttsDefaultTestText =>
      'Hello, this is a test of the selected voice.';

  @override
  String get separatorTextHint => 'says';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get includedSample => 'Included sample';

  @override
  String get youtubeInputHint => '@handle · channel ID · video ID';

  @override
  String get channelNameHint => 'channel_name';

  @override
  String get channelIdentifierHint => 'channel_identifier';

  @override
  String get blockedUsersHint => '@nightbot\n@another_user';

  @override
  String get blockedWordsHint => 'word\ncomplete phrase';

  @override
  String get chatError => 'Chat messages could not be loaded.';

  @override
  String platformConnectionFailed(String platform) {
    return '$platform could not connect. Check the channel and your Internet connection.';
  }

  @override
  String get obsConnectionProblem =>
      'OBS could not complete the requested action. Check the connection settings.';

  @override
  String get defaultVoice => 'Default';

  @override
  String get newsVoice => 'News voice';

  @override
  String newsVoiceNumber(int number) {
    return 'News voice $number';
  }

  @override
  String get alignmentLeft => 'Left';

  @override
  String get alignmentCenter => 'Center';

  @override
  String get alignmentRight => 'Right';

  @override
  String get animationSlideUp => 'Slide up';

  @override
  String get animationSlideLeft => 'Slide from right';

  @override
  String get animationFadeIn => 'Fade in';

  @override
  String get animationZoomIn => 'Zoom in';

  @override
  String droppedFramesBadge(String percentage, int count) {
    return 'DROP $percentage% ($count)';
  }

  @override
  String get badgeOwner => 'OWNER';

  @override
  String get badgeModerator => 'MOD';

  @override
  String get badgeMember => 'MEMBER';

  @override
  String get badgeSubscriber => 'SUB';

  @override
  String get badgeVerified => 'VERIFIED';

  @override
  String get badgeFirstMessage => 'FIRST MESSAGE';

  @override
  String get badgeReturningChatter => 'RETURNING';

  @override
  String get badgeReward => 'REWARD';

  @override
  String get newSubscriberEvent => 'New subscriber!';

  @override
  String resubscriptionEvent(int months) {
    return 'Resubscribed for $months months';
  }

  @override
  String get giftSubscriptionEvent => 'Gift subscription';

  @override
  String get subscriptionUpdateEvent => 'Subscription update';

  @override
  String get membershipUpdateEvent => 'Membership update';

  @override
  String get chatSharedSource => 'SHARED';

  @override
  String get chatEventRaid => 'Raid';

  @override
  String get chatEventUnraid => 'Raid ended';

  @override
  String get chatEventPinnedMessage => 'Pinned message';

  @override
  String get chatEventUnpinnedMessage => 'Message unpinned';

  @override
  String get chatEventPoll => 'Poll';

  @override
  String get chatEventReward => 'Reward';

  @override
  String get chatEventSupport => 'Support';

  @override
  String get chatEventHost => 'Host';

  @override
  String get chatEventGoal => 'Goal';

  @override
  String get chatEventNotice => 'Notice';

  @override
  String get chatEventModiversary => 'Moderator anniversary';

  @override
  String get chatEventViewerMilestone => 'Viewer milestone';

  @override
  String get chatEventWatchStreak => 'Watch streak';

  @override
  String get chatEventSharedChat => 'Shared chat';

  @override
  String get chatEventRoomState => 'Chat settings updated';

  @override
  String get chatEventStreamOnline => 'Stream online';

  @override
  String get chatEventStreamOffline => 'Stream offline';

  @override
  String get eventBanners => 'Event banners';

  @override
  String get eventBannersDescription =>
      'Choose which platform notices (raids, polls, pinned messages…) appear above chat.';

  @override
  String get eventBannerDuration => 'Visible duration';

  @override
  String get chatEventUnknown => 'Event';

  @override
  String get chatRoomEmoteOnly => 'Emote-only';

  @override
  String chatRoomFollowersOnly(int minutes) {
    return 'Followers $minutes min';
  }

  @override
  String get chatRoomUnique => 'Unique chat';

  @override
  String chatRoomSlowMode(int seconds) {
    return 'Slow mode $seconds s';
  }

  @override
  String get chatRoomSubscribersOnly => 'Subscribers-only';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageBulgarian => 'Bulgarian';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageCroatian => 'Croatian';

  @override
  String get languageCzech => 'Czech';

  @override
  String get languageDanish => 'Danish';

  @override
  String get languageDutch => 'Dutch';

  @override
  String get languageEstonian => 'Estonian';

  @override
  String get languageFinnish => 'Finnish';

  @override
  String get languageFrench => 'French';

  @override
  String get languageGerman => 'German';

  @override
  String get languageGreek => 'Greek';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageHungarian => 'Hungarian';

  @override
  String get languageIndonesian => 'Indonesian';

  @override
  String get languageItalian => 'Italian';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languageLatvian => 'Latvian';

  @override
  String get languageLithuanian => 'Lithuanian';

  @override
  String get languagePolish => 'Polish';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageRomanian => 'Romanian';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageSlovak => 'Slovak';

  @override
  String get languageSlovenian => 'Slovenian';

  @override
  String get languageSwedish => 'Swedish';

  @override
  String get languageTurkish => 'Turkish';

  @override
  String get languageUkrainian => 'Ukrainian';

  @override
  String get languageVietnamese => 'Vietnamese';

  @override
  String get noChannelsConfiguredMenuHidden => 'No channels configured yet.';

  @override
  String get configureChannels => 'Configure channels';

  @override
  String platformStatusConnected(String platform) {
    return '$platform: connected';
  }

  @override
  String platformStatusConnecting(String platform) {
    return '$platform: connecting…';
  }

  @override
  String platformStatusIdle(String platform) {
    return '$platform: not connected';
  }

  @override
  String get clickThroughEnabledNotice =>
      'Click-Through is on: clicks go to the window behind. Press Ctrl+Shift+C to turn it off.';

  @override
  String newChatMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '1 new message',
    );
    return '$_temp0';
  }

  @override
  String get silenceTts => 'Silence TTS (skip this message and the queue)';

  @override
  String get youtubeWaitingForLive =>
      'Waiting for the YouTube live stream to start…';

  @override
  String get youtubeWaitingForLiveDetail =>
      'The channel is not live yet. Airstream checks again every 30 seconds.';

  @override
  String get connectChatOnLaunch => 'Start the chat when Airstream opens';

  @override
  String get obsConnectOnLaunch => 'Connect to OBS when Airstream opens';

  @override
  String get chatPreview => 'Preview';

  @override
  String get chatPreviewDescription =>
      'Show sample messages in the chat and the OBS overlay to try styles. They disappear when the chat starts.';

  @override
  String overlayPortFallback(int requested, int port) {
    return 'Port $requested is in use by another app, so the overlay uses $port. The OBS URLs below already include it.';
  }

  @override
  String get chatPreviewSwitch => 'Show sample messages';

  @override
  String get highlights => 'Highlights';

  @override
  String get highlightsDescription =>
      'Make mentions of your channel and words you choose stand out in Airstream\'s chat.';

  @override
  String get highlightMentions => 'Mentions of my channel';

  @override
  String get highlightMentionsDescription =>
      'Messages that name your Twitch or Kick channel or your YouTube @name.';

  @override
  String get highlightWords => 'Words to highlight';

  @override
  String get highlightWordsHint => 'One word or phrase per line';

  @override
  String get highlightWordsHelp =>
      'Whole words; uppercase and lowercase are the same.';

  @override
  String get highlightSound => 'Highlight sounds';

  @override
  String get highlightSoundDescription =>
      'Sounds play at most once every 3 seconds. They stay silent while the voice reader speaks.';

  @override
  String get badgeFirstInSession => 'First message this stream';

  @override
  String get highlightFirstMessages => 'First message of each viewer';

  @override
  String get highlightFirstMessagesDescription =>
      'Mark the first message each viewer sends after you start the chat, to welcome them.';

  @override
  String get ttsUserCooldown => 'Pause per viewer';

  @override
  String get ttsUserCooldownHelp =>
      'After reading a message, the next ones from the same viewer wait this long. 0 s turns it off.';

  @override
  String get ttsMaxCharacters => 'Longest message read';

  @override
  String get ttsIgnoredUsers => 'Users the voice reader skips';

  @override
  String get ttsIgnoredUsersHint => 'One per line, for example nightbot';

  @override
  String get chatFilterTooltip =>
      'Filter Airstream\'s chat (OBS still shows every message)';

  @override
  String get chatFilterPlatforms => 'Platforms';

  @override
  String get chatFilterShowOnly => 'Show';

  @override
  String get chatFilterAll => 'All messages';

  @override
  String get chatFilterMembers => 'Only members and subscribers';

  @override
  String get chatFilterModerators => 'Only moderators';

  @override
  String get chatFilterHighlighted => 'Only highlighted';

  @override
  String chatFilterActive(String filters) {
    return 'Showing: $filters';
  }

  @override
  String get chatFilterShowAll => 'Show all';

  @override
  String get chatFilterNoMatches => 'No messages match the filter yet.';

  @override
  String get messageShowOnStream => 'Show on stream';

  @override
  String get messageShowOnStreamNeedsOverlay =>
      'Turn on the overlay server and add the alerts URL to OBS';

  @override
  String get messageSentToOverlay => 'Sent to the alerts page in OBS';

  @override
  String get messageOverlayDisconnected =>
      'OBS closed the alerts page before showing the message';

  @override
  String get messageNoAlertsOverlay =>
      'Open the featured or alerts page as a browser source in OBS.';

  @override
  String get messageOverlayUnconfirmed =>
      'Sent, but OBS did not confirm it was shown';

  @override
  String get messageShownOnStream => 'Shown on stream';

  @override
  String get messageCopy => 'Copy message';

  @override
  String get messageCopied => 'Message copied';

  @override
  String get pollTitle => 'Poll';

  @override
  String get pollDescription =>
      'Ask viewers across all your chats and choose how they vote.';

  @override
  String get pollMode => 'Voting mode';

  @override
  String get pollModeNumbered => 'Numbered';

  @override
  String get pollModeWord => 'By word';

  @override
  String get pollModeYesNo => 'Yes / No';

  @override
  String get pollModeRating => 'Rating 1–10';

  @override
  String get pollModeFreeAnswer => 'Free answer';

  @override
  String get pollYes => 'Yes';

  @override
  String get pollNo => 'No';

  @override
  String get pollOptions => 'Voting options';

  @override
  String get pollAllowed => 'Who can vote';

  @override
  String get pollAllowChange => 'Allow vote changes';

  @override
  String get pollHideResults => 'Hide results until the end';

  @override
  String get pollResultsHidden => 'Results at the end';

  @override
  String get pollResultsHiddenOnPages =>
      'Results are hidden from pages until the poll ends.';

  @override
  String get pollCommand => 'Answer command';

  @override
  String get pollInvalidCommand =>
      'Enter a command like !r that isn’t reserved by the queue.';

  @override
  String get pollAmbiguousOptions =>
      'Enter options that differ even without accents, case or extra spaces.';

  @override
  String get pollOptionTooLong => 'Each option can have up to 40 characters.';

  @override
  String get pollInvalidInput =>
      'Enter a question and fill in at least two options if required.';

  @override
  String get pollAverage => 'Average';

  @override
  String get pollDistinctAnswers => 'Distinct answers';

  @override
  String get pollHowToVote => 'Type in chat';

  @override
  String get pollAnswerExample => 'your answer';

  @override
  String get pollNoAnswers => 'No answers yet';

  @override
  String get galleryPollDescription =>
      'Show voting instructions, live tallies, and final results.';

  @override
  String get pollQuestionHint => 'Question';

  @override
  String pollOptionHint(int number) {
    return 'Option $number';
  }

  @override
  String get pollAddOption => 'Add option';

  @override
  String get pollRemoveOption => 'Remove option';

  @override
  String get pollNoTimeLimit => 'No time limit';

  @override
  String pollMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get pollStart => 'Start poll';

  @override
  String get pollEnd => 'End poll';

  @override
  String get pollNew => 'New poll';

  @override
  String get pollOpen => 'Voting open';

  @override
  String get pollClosed => 'Final results';

  @override
  String pollSecondsLeft(int seconds) {
    return '$seconds s left';
  }

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String get pollOverlayOff =>
      'Turn on the overlay server to show this in OBS.';

  @override
  String pollOverlayUrl(String url) {
    return 'Add $url to OBS as a Browser Source to show it.';
  }

  @override
  String get pollOverlayUrlCopied => 'Poll URL copied';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get pollDuration => 'Duration';

  @override
  String get sessionSummary => 'Session summary';

  @override
  String get sessionSummaryEmpty =>
      'Start the chat: the summary collects messages, viewers and support until you stop it.';

  @override
  String sessionSummaryLine(String duration, int messages, int chatters) {
    return '$duration · $messages messages · $chatters viewers wrote';
  }

  @override
  String get sessionDuration => 'Duration';

  @override
  String sessionDurationHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String sessionDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get sessionMessagesLabel => 'Messages';

  @override
  String sessionMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get sessionChatters => 'Viewers who wrote';

  @override
  String get sessionTopChatters => 'Most active';

  @override
  String get sessionSupporters => 'Support';

  @override
  String get sessionNoSupporters =>
      'No Super Chats, members or raids this time.';

  @override
  String sessionSupportSuperChat(String name, String amount) {
    return '$name sent a Super Chat of $amount';
  }

  @override
  String sessionSupportMember(String name, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$name: $months months as a member',
      one: '$name became a member',
    );
    return '$_temp0';
  }

  @override
  String sessionSupportSubscription(String name, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$name: $months months subscribed',
      one: '$name subscribed',
    );
    return '$_temp0';
  }

  @override
  String sessionSupportGift(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name gifted $count subscriptions',
      one: '$name gifted a subscription',
    );
    return '$_temp0';
  }

  @override
  String sessionSupportRaid(String name, int count) {
    return '$name raided with $count viewers';
  }

  @override
  String sessionSupportOther(String name) {
    return '$name sent a gift';
  }

  @override
  String get sessionSummaryCopy => 'Copy summary';

  @override
  String get sessionSummaryCopied => 'Summary copied';

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesDescription =>
      'Save your setup for each kind of stream and switch in one click. Profiles keep style, voice reader, overlay and highlights; your channels and OBS stay as they are.';

  @override
  String get profilesEmpty => 'No profiles yet.';

  @override
  String get profileNameHint => 'Profile name, for example Gaming';

  @override
  String get profileSave => 'Save';

  @override
  String get profileApply => 'Apply';

  @override
  String get profileDelete => 'Delete profile';

  @override
  String profileSaved(String name) {
    return 'Profile \"$name\" saved';
  }

  @override
  String profileApplied(String name) {
    return 'Profile \"$name\" applied';
  }

  @override
  String get settingsBackupTitle => 'Backup';

  @override
  String get settingsBackupDescription =>
      'Save all settings to a file, bring them back on another computer, or return to the defaults. The OBS password is never saved to the file.';

  @override
  String get settingsExport => 'Export';

  @override
  String get settingsImport => 'Import';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsExported => 'Settings exported';

  @override
  String get settingsExportFailed =>
      'The settings could not be saved to that file.';

  @override
  String get settingsImported => 'Settings imported';

  @override
  String get settingsImportFailed =>
      'That file is not an Airstream settings file.';

  @override
  String get settingsResetTitle => 'Reset settings?';

  @override
  String get settingsResetConfirmation =>
      'Style, voice reader, overlay, highlights and the rest go back to their defaults. Your channels, OBS connection, language and profiles stay.';

  @override
  String get settingsResetDone => 'Settings reset';

  @override
  String get chatSearch => 'Search the chat';

  @override
  String get chatSearchHint => 'Search messages or names';

  @override
  String get chatSearchClose => 'Close search';

  @override
  String get chatLogTitle => 'Chat log';

  @override
  String get chatLogSave => 'Save the chat of each session';

  @override
  String get chatLogDescription =>
      'Writes every message to a text file in Documents\\Airstream\\Chat while the chat runs.';

  @override
  String get chatLogOpenFolder => 'Open folder';

  @override
  String get globalShortcutsTitle => 'Global shortcuts';

  @override
  String get globalShortcutsDescription =>
      'They work from any app, for example during a game. Each one is off until you assign it, so other apps keep their shortcuts.';

  @override
  String get globalShortcutSilenceTts => 'Silence the voice reader';

  @override
  String get globalShortcutToggleTts => 'Turn the voice reader on or off';

  @override
  String get globalShortcutNone => 'Assign';

  @override
  String get globalShortcutPress => 'Press the keys…';

  @override
  String get globalShortcutClear => 'Remove shortcut';

  @override
  String get globalShortcutNeedsModifier =>
      'Use Ctrl, Alt or Win with the key.';

  @override
  String get globalShortcutReserved =>
      'Ctrl + Shift + C is reserved for click-through.';

  @override
  String get globalShortcutDuplicate =>
      'Another action already uses this shortcut.';

  @override
  String get globalShortcutInUse =>
      'Another app already uses this shortcut; choose a different one.';

  @override
  String get alertTypes => 'Alert types';

  @override
  String get alertTypeSuperChat => 'YouTube Super Chats';

  @override
  String get alertTypeMembership => 'YouTube new members';

  @override
  String get alertTypeBits => 'Twitch Bits';

  @override
  String get alertTypeSubscription => 'Subscriptions (Twitch and Kick)';

  @override
  String get alertTypeGift => 'Gifted subscriptions and memberships';

  @override
  String get alertTypeRaid => 'Raids and hosts';

  @override
  String get alertTypeKicks => 'Kick Kicks';

  @override
  String get testAlertBits => 'Bits';

  @override
  String get testAlertSubscription => 'Subscription';

  @override
  String get testAlertGift => 'Gift';

  @override
  String get testAlertRaid => 'Raid';

  @override
  String get testAlertKicks => 'Kicks';

  @override
  String get overlayStylePresetsTitle => 'Ready-made styles';

  @override
  String get overlayStylePresetsDescription =>
      'One tap sets how the chat and alerts look in OBS. Your connections and other settings stay as they are.';

  @override
  String get overlayStyleCustom => 'Custom style';

  @override
  String overlayStyleApplied(String name) {
    return 'Style “$name” applied';
  }

  @override
  String get overlayStyleUndo => 'Undo';

  @override
  String get overlayStylePreviewHint =>
      'Turn on the preview to see it with sample messages.';

  @override
  String get overlayStyleClassic => 'Classic';

  @override
  String get overlayStyleClassicDescription => 'Airstream\'s default look.';

  @override
  String get overlayStyleCompactGaming => 'Compact for gaming';

  @override
  String get overlayStyleCompactGamingDescription =>
      'Small, tight messages that cover little of the game.';

  @override
  String get overlayStyleBigBubbles => 'Big bubbles';

  @override
  String get overlayStyleBigBubblesDescription =>
      'Large text in rounded bubbles, easy to read.';

  @override
  String get overlayStyleCleanTransparent => 'Clean transparent';

  @override
  String get overlayStyleCleanTransparentDescription =>
      'No bubbles: outlined text over your scene.';

  @override
  String get overlayStyleVertical => 'Vertical';

  @override
  String get overlayStyleVerticalDescription =>
      'Made for vertical streams such as Shorts or TikTok.';

  @override
  String get alertPosition => 'Position';

  @override
  String get alertPositionTop => 'Top';

  @override
  String get alertPositionCenter => 'Centre';

  @override
  String get alertPositionBottom => 'Bottom';

  @override
  String get alertLayout => 'Layout';

  @override
  String get alertLayoutRow => 'Side by side';

  @override
  String get alertLayoutStacked => 'Stacked';

  @override
  String get alertEntrance => 'Entrance';

  @override
  String get alertAnimationPop => 'Pop';

  @override
  String get alertAnimationSlideUp => 'Slide up';

  @override
  String get alertAnimationSlideDown => 'Slide down';

  @override
  String get alertAnimationFade => 'Fade';

  @override
  String get alertAnimationZoom => 'Zoom';

  @override
  String get alertTypeOptions => 'Options for this type';

  @override
  String get alertTypeOwnDuration => 'Own duration';

  @override
  String get alertTypeUseGeneral => 'Use general';

  @override
  String get alertTypeCustomized => 'Custom';

  @override
  String get alertSound => 'Sound';

  @override
  String get alertSoundNone => 'None';

  @override
  String get alertSoundChime => 'Chime';

  @override
  String get alertSoundCoin => 'Coin';

  @override
  String get alertSoundFanfare => 'Fanfare';

  @override
  String get alertSoundCustom => 'Own file';

  @override
  String get alertSoundChoose => 'Choose…';

  @override
  String get alertSoundNoFile => 'No file chosen';

  @override
  String get alertSoundInvalid => 'Use a WAV, MP3 or OGG file of up to 5 MB.';

  @override
  String get alertSoundVolume => 'Alert sound volume';

  @override
  String get alertSoundObsHint =>
      'Sounds play from the alerts page. In OBS, turn on “Control audio via OBS” for that browser source so your viewers hear them.';

  @override
  String get alertTypeTest => 'Test';

  @override
  String get recentAlertsTitle => 'Recent alerts';

  @override
  String get recentAlertsDescription =>
      'Support events from this session that appeared on stream. Show any of them again.';

  @override
  String get recentAlertsEmpty => 'Alerts from this session will appear here.';

  @override
  String get recentAlertsReplay => 'Show on stream again';

  @override
  String get recentAlertsReplayed => 'Shown on stream again';

  @override
  String get recentAlertsMember => 'New member';

  @override
  String get recentAlertsSubscription => 'Subscription';

  @override
  String recentAlertsMonths(int count) {
    return '$count months';
  }

  @override
  String recentAlertsGifted(int count) {
    return '$count gifted';
  }

  @override
  String get recentAlertsRaid => 'Raid';

  @override
  String get recentAlertsHost => 'Host';

  @override
  String recentAlertsRaidViewers(int count) {
    return 'Raid · $count viewers';
  }

  @override
  String recentAlertsHostViewers(int count) {
    return 'Host · $count viewers';
  }

  @override
  String recentAlertsKicks(int count) {
    return '$count Kicks';
  }

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsCopy => 'Copy report';

  @override
  String get diagnosticsCopied => 'Report copied';

  @override
  String get diagnosticsLogs => 'Open logs folder';

  @override
  String get diagnosticsLogsFailed => 'Could not open logs folder';

  @override
  String diagnosticsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things need attention',
      one: '1 thing needs attention',
      zero: 'Everything looks fine',
    );
    return '$_temp0';
  }

  @override
  String diagnosticsMessage(String kind, String value) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'set': 'set',
        'off': 'Off',
        'idle': 'Not connected',
        'connected': 'Connected',
        'connecting': 'Connecting / reconnecting',
        'waiting': 'Waiting for live stream',
        'ended': 'Broadcast ended',
        'failed': 'Failed (private details omitted)',
        'portBusy': 'Port is already in use',
        'authentication': 'Authentication failed',
        'refused': 'Connection refused',
        'timeout': 'Connection timed out',
        'listeningPort': 'Listening on port $value',
        'starting': 'Starting',
        'noAlerts': 'No alerts page connected in OBS',
        'pages':
            'Pages: chat / alerts / poll / captions / giveaway / goals / timer: $value',
        'loading': 'Loading $value',
        'ready': 'Ready: $value',
        'listening': 'Listening',
        'downloading': 'Downloading $value',
        'missingModel': 'Model download required',
        'commandsOn': 'Voice commands on',
        'commandsOff': 'Voice commands off',
        'shortcutsOk': 'None assigned or all registered',
        'shortcutTaken': 'Shortcut taken by another app: $value',
        'silenceTts': 'Silence voice reader',
        'toggleTts': 'Toggle voice reader',
        'channelSet': 'Channel set',
        'channelUnset': 'Channel not set',
        'scene': 'Scene: $value',
        'metrics': '$value kbps / dropped frames',
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
        'server': 'Overlay server',
        'tts': 'Voice reader (TTS)',
        'captions': 'Captions and voice commands',
        'shortcuts': 'Global shortcuts',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String get giveawayTitle => 'Keyword giveaway';

  @override
  String get giveawayDescription =>
      'Viewers enter once by typing the keyword in chat.';

  @override
  String get giveawayKeyword => 'Keyword';

  @override
  String get giveawayMembersOnly => 'Members / subscribers only';

  @override
  String get giveawayStart => 'Start';

  @override
  String get giveawayClose => 'Close entries';

  @override
  String get giveawayDraw => 'Draw';

  @override
  String get giveawayRedraw => 'Draw again';

  @override
  String get giveawayClear => 'Clear';

  @override
  String get giveawayClosed => 'Entries closed';

  @override
  String get giveawayWinner => 'Winner';

  @override
  String get giveawayDrawing => 'Drawing…';

  @override
  String get giveawayPageTitle => 'Airstream Giveaway';

  @override
  String giveawayParticipants(int count) {
    return '$count participants';
  }

  @override
  String get giveawayPageOff =>
      'Turn on the overlay server to show this in OBS.';

  @override
  String giveawayPageUrl(String url) {
    return 'OBS page: $url';
  }

  @override
  String get giveawayUrlCopied => 'Giveaway page URL copied';

  @override
  String get goalsTitle => 'Goals';

  @override
  String get goalsDescription =>
      'Track support and adjust progress during your stream.';

  @override
  String get goalsAdd => 'Add goal';

  @override
  String get goalsEdit => 'Edit';

  @override
  String get goalsDelete => 'Delete';

  @override
  String get goalsReset => 'Reset to 0';

  @override
  String get goalsSave => 'Save';

  @override
  String get goalsName => 'Title';

  @override
  String get goalsType => 'Type';

  @override
  String get goalsTarget => 'Target';

  @override
  String get goalsSubs => 'Subscriptions';

  @override
  String get goalsBits => 'Bits';

  @override
  String get goalsKicks => 'Kicks';

  @override
  String get goalsManual => 'Manual';

  @override
  String get goalsReached => 'Goal reached!';

  @override
  String get goalsPageTitle => 'Airstream Goals';

  @override
  String get goalsInvalid => 'Enter a title and a target from 1 to 1,000,000.';

  @override
  String get goalsPageOff => 'Turn on the overlay server to show this in OBS.';

  @override
  String goalsPageUrl(String url) {
    return 'OBS page: $url';
  }

  @override
  String get goalsUrlCopied => 'Goals page URL copied';

  @override
  String get subathonTitle => 'Subathon timer';

  @override
  String get subathonStartMinutes => 'Start minutes';

  @override
  String get subathonStart => 'Start';

  @override
  String get subathonPause => 'Pause';

  @override
  String get subathonResume => 'Resume';

  @override
  String get subathonReset => 'Reset';

  @override
  String get subathonRules => 'Rules';

  @override
  String get subathonPerSub => 'Seconds per subscription or gifted sub';

  @override
  String get subathonPerBits => 'Seconds per 100 Bits';

  @override
  String get subathonPerKicks => 'Seconds per 100 Kicks';

  @override
  String get subathonCap => 'Maximum remaining minutes (0 = no limit)';

  @override
  String get subathonIdle => 'Idle';

  @override
  String get subathonRunning => 'Running';

  @override
  String get subathonPaused => 'Paused';

  @override
  String get subathonEnded => 'Time\'s up!';

  @override
  String get subathonPageOff =>
      'Turn on the overlay server to show this in OBS.';

  @override
  String get subathonDescription => 'Add time from support during your stream.';

  @override
  String get subathonUrlCopied => 'Timer page URL copied';

  @override
  String get mediaLibraryTitle => 'Media library';

  @override
  String mediaUsage(String used) {
    return '$used of 500 MB';
  }

  @override
  String get mediaAdd => 'Add files';

  @override
  String get mediaDelete => 'Delete';

  @override
  String get mediaRejectType =>
      'Unsupported file type or invalid file contents.';

  @override
  String get mediaRejectSize =>
      'File exceeds its size limit (images 10 MB, videos 50 MB, audio 5 MB).';

  @override
  String get mediaRejectTotal => 'The library would exceed 500 MB.';

  @override
  String get alertMedia => 'Image or video';

  @override
  String get mediaNone => 'None';

  @override
  String get alertMediaAudio => 'Play video sound';

  @override
  String mediaLibraryName(String name) {
    return 'Library: $name';
  }

  @override
  String get mediaImage => 'Image';

  @override
  String get mediaVideo => 'Video';

  @override
  String get mediaAudio => 'Audio';

  @override
  String get templatesTitle => 'Templates';

  @override
  String get templatesDescription =>
      'A template is a folder of HTML, CSS and JavaScript in Documents\\Airstream\\Templates. Each template has its own OBS URL.';

  @override
  String get templatesNew => 'New template';

  @override
  String get templatesOpenFolder => 'Open folder';

  @override
  String get templatesTest => 'Send test events';

  @override
  String get templatesTestSent => 'Test events sent to open template pages';

  @override
  String get templatesTestEmpty => 'Open a template in OBS first';

  @override
  String get templatesEmpty => 'No templates yet';

  @override
  String get templatesInternet => 'Internet access';

  @override
  String get templatesCopy => 'Copy URL';

  @override
  String get templatesCopied => 'URL copied';

  @override
  String get templatesPreview => 'Preview';

  @override
  String get templatesEdit => 'Edit code';

  @override
  String get templatesDelete => 'Delete';

  @override
  String get templatesName => 'Name';

  @override
  String get templatesRequired => 'Enter a name';

  @override
  String get templatesCreate => 'Create';

  @override
  String get templatesCancel => 'Cancel';

  @override
  String get templatesSave => 'Save';

  @override
  String get templatesSaved => 'Changes saved';

  @override
  String get templatesClose => 'Close';

  @override
  String get templatesDiscard => 'Discard changes';

  @override
  String get templatesUnsaved => 'Discard unsaved changes?';

  @override
  String get templatesLarge =>
      'This file is over 512 KB. Edit it from the folder instead.';

  @override
  String get templatesFailed =>
      'Could not complete the action. Check the template folder and try again.';

  @override
  String get templatesBlank => 'Blank';

  @override
  String get templatesChat => 'Chat';

  @override
  String get templatesAlerts => 'Alerts';

  @override
  String get templatesGoal => 'Goal bar';

  @override
  String get templatesBlankDescription => 'Show the last SDK event';

  @override
  String get templatesChatDescription =>
      'Live messages with emotes and avatars';

  @override
  String get templatesAlertsDescription => 'Animated alerts, one at a time';

  @override
  String get templatesGoalDescription => 'Progress towards one of your goals';

  @override
  String get templatesMissingIndex => 'Missing index.html';

  @override
  String get templatesInvalidManifest => 'Invalid template.json';

  @override
  String get templatesUnsupportedSdk => 'Unsupported SDK version';

  @override
  String get templatesOversizedIndex => 'index.html exceeds 2 MB';

  @override
  String templatesOpenCount(int count) {
    return '$count open in OBS';
  }

  @override
  String templatesError(String source, String line, String message) {
    return 'Error in $source:$line: $message';
  }

  @override
  String templatesDeleteConfirm(String name) {
    return 'Delete “$name”? This deletes its folder and cannot be undone.';
  }

  @override
  String get templatesAi => 'Create with AI';

  @override
  String get templatesAiSteps =>
      '1. Open this folder in your AI tool, for example OpenCode, Claude Code or Codex.\n2. Paste the instruction.\n3. The template appears in this list: copy its URL into OBS.';

  @override
  String get templatesAiDescription => 'What should your template show?';

  @override
  String get templatesAiCopy => 'Copy instruction';

  @override
  String get templatesAiCopied => 'Instruction copied';

  @override
  String templatesAiInstruction(String id, String description, String url) {
    return 'Read AGENTS.md in this folder first. Create a new template in a new folder named $id.\nWhat it must show:\n$description\nTest it at $url and fix browser console errors. When done, tell me its OBS URL and recommended size.';
  }

  @override
  String get templateCustomize => 'Customize';

  @override
  String get templateReset => 'Reset to defaults';

  @override
  String get templateFieldNone => 'None';

  @override
  String get templateFieldColorInvalid =>
      'Use #rrggbb or #rrggbbaa. This color has not been saved.';

  @override
  String get templateExport => 'Export .zip';

  @override
  String get templateImport => 'Import .zip';

  @override
  String get templateDuplicate => 'Duplicate';

  @override
  String get templateCopyWord => 'copy';

  @override
  String get templateArchiveDone => 'Template saved';

  @override
  String get templateTrust =>
      'This template contains code that runs in OBS. Import only templates from people you trust.';

  @override
  String templateArchiveSummary(int count, int bytes) {
    return '$count files · $bytes bytes';
  }

  @override
  String get templateRejectZip => 'ZIP exceeds 100 MB.';

  @override
  String get templateRejectCount => 'More than 500 files.';

  @override
  String get templateRejectTotal => 'Uncompressed content exceeds 100 MB.';

  @override
  String get templateRejectFile => 'A file exceeds 50 MB.';

  @override
  String get templateRejectPath => 'Unsafe or duplicate file path.';

  @override
  String get templateRejectLink => 'Links and special files are not allowed.';

  @override
  String get templateRejectType => 'Unsupported file type.';

  @override
  String get templateRejectLayout =>
      'Use files at the ZIP root or inside one folder.';

  @override
  String get templateRejectIndex => 'Missing index.html.';

  @override
  String get templateRejectSize =>
      'Invalid ZIP, damaged content or decompression size limit exceeded.';

  @override
  String get liveTab => 'Live';

  @override
  String get liveServerOff => 'Overlay server is off';

  @override
  String get liveOpenObs => 'Go to OBS & Overlay';

  @override
  String get liveServerNotice =>
      'To show these tools in OBS, turn on the overlay server.';

  @override
  String get templatesEmptyGuide =>
      'Start from an example\nAsk an AI agent\nImport a template someone shared';

  @override
  String ruleLabel(String code) {
    String _temp0 = intl.Intl.selectLogic(
      code,
      {
        'krules': 'Rules',
        'kdescription':
            'When something happens in your stream, Airstream can do things for you.',
        'kautomation': 'Automation on',
        'knew': 'New rule',
        'krecipes': 'Recipes',
        'kempty': 'Start with Recipes for an example.',
        'kempty2': 'Or choose New rule to build your own.',
        'ktripped': 'Automation paused itself after too many runs in a minute.',
        'kresume': 'Resume',
        'kinvalid': 'This rule needs fixing',
        'kpublicObs': 'Anyone in chat can change OBS with this rule',
        'kpublicChatText': 'Chat text will appear on your stream',
        'knoCooldown': 'No cooldown: chat can repeat it as fast as it wants',
        'kedit': 'Edit',
        'kduplicate': 'Duplicate',
        'kdelete': 'Delete',
        'kcopy': 'copy',
        'kconfirmDelete': 'Delete this rule?',
        'kcancel': 'Cancel',
        'kdiscard': 'Discard changes?',
        'kclose': 'Close',
        'ksave': 'Save',
        'ksaveFailed': 'Could not save the rule. Try again.',
        'kname': 'Name',
        'kwhen': 'When',
        'kif': 'If',
        'kdo': 'Do',
        'klimits': 'Limits',
        'koverlap': 'If it is already running',
        'kaddAction': 'Add action',
        'ktest': 'Test',
        'ktestWith': 'Test with',
        'krun': 'Run now',
        'kmatched': 'Matched',
        'kaccepted': 'Run accepted',
        'khistory': 'History',
        'kclear': 'Clear',
        'knoHistory': 'No runs yet.',
        'kup': 'Move up',
        'kdown': 'Move down',
        'kfieldError': 'Check this value and its limits',
        'kcooldownSeconds': 'Cooldown (seconds, 0–3600)',
        'kuserCooldownSeconds': 'Per-person cooldown (seconds, 0–3600)',
        'kqueue': 'Queue: wait for the previous run',
        'kskip': 'Skip: ignore while already running',
        'konlyWhileStreaming': 'Only while OBS is streaming',
        'keveryone': 'Everyone',
        'kmember': 'Members/subscribers',
        'kmoderator': 'Moderators',
        'kvip': 'VIPs',
        'kowner': 'Owner',
        'kchat': 'Chat',
        'ksupport': 'Support',
        'klive': 'Live tools',
        'kobs': 'OBS',
        'ktime': 'Time',
        'kmanual': 'Manual',
        'kflow': 'Flow',
        'kvoice': 'Voice',
        'ksound': 'Sound',
        'kpages': 'Pages and templates',
        'kadd': 'Add',
        'kdone': 'Done ✓',
        'kskipped': 'Skipped',
        'kfailed': 'Failed',
        'kuncertain': 'Uncertain',
        'kcancelled': 'Cancelled',
        'kwouldRun': 'Would run',
        'kpending': 'Pending',
        'kchat_message': 'Message contains text',
        'kchat_command': 'Chat command',
        'kchat_firstMessage': 'First message',
        'ksupport_superchat': 'Super Chat',
        'ksupport_bits': 'Bits',
        'ksupport_membership': 'Membership / subscription',
        'ksupport_gift': 'Gift subscriptions',
        'ksupport_raid': 'Raid',
        'ksupport_kicks': 'Kicks',
        'kgoal_reached': 'Goal reached',
        'kgiveaway_winner': 'Giveaway winner',
        'kpoll_ended': 'Poll ended',
        'kclock_ended': 'Timer ended',
        'ksubathon_ended': 'Subathon ended',
        'kobs_streamStarted': 'Stream started',
        'kobs_streamStopped': 'Stream stopped',
        'kobs_recordingStarted': 'Recording started',
        'kobs_recordingStopped': 'Recording stopped',
        'kobs_sceneChanged': 'Scene changed',
        'kinterval': 'Every N minutes',
        'kwait': 'Wait',
        'kobs_scene': 'Switch scene',
        'kobs_previousScene': 'Return to previous scene',
        'kobs_recording': 'Recording',
        'kobs_source': 'Show / hide source',
        'kobs_mute': 'Mute / unmute input',
        'kobs_text': 'Set text',
        'kobs_filter': 'Turn filter on / off',
        'ktts_say': 'Read aloud',
        'ksound_play': 'Play sound',
        'kalert_show': 'Show alert',
        'kfeatured': 'Feature message',
        'ktemplate_trigger': 'Trigger template',
        'kgoal_adjust': 'Adjust goal',
        'kclock': 'Timer',
        'ksubathon_adjust': 'Adjust subathon',
        'kgiveaway': 'Giveaway',
        'kcounter': 'Counter',
        'kcommand': 'Command',
        'kmatch': 'Match',
        'ktext': 'Text',
        'kminAmount': 'Minimum amount',
        'kcurrency': 'Currency',
        'kmin': 'Minimum count',
        'kminMonths': 'Minimum months',
        'kgoalId': 'Goal',
        'kscene': 'Scene',
        'kminutes': 'Minutes',
        'kseconds': 'Seconds',
        'kstate': 'State',
        'ksource': 'Source',
        'kfilter': 'Filter',
        'kvisible': 'Visibility',
        'kinput': 'Audio input',
        'kmediaId': 'Library media',
        'ktitle': 'Title',
        'kdata': 'Data',
        'kdelta': 'Change',
        'kop': 'Operation',
        'kkeyword': 'Keyword',
        'kmembersOnly': 'Members only',
        'kvalue': 'Value',
        'kcontains': 'Contains',
        'kstartsWith': 'Starts with',
        'kequals': 'Equals',
        'kstart': 'Start',
        'kstop': 'Stop',
        'kshow': 'Show',
        'khide': 'Hide',
        'ktoggle': 'Toggle',
        'kmute': 'Mute',
        'kunmute': 'Unmute',
        'kenable': 'Turn on',
        'kdisable': 'Turn off',
        'kbuiltin': 'Built in',
        'klibrary': 'Library',
        'kchime': 'Chime',
        'kcoin': 'Coin',
        'kfanfare': 'Fanfare',
        'kset': 'Set',
        'kdraw': 'Draw',
        'kautomationOff': 'Automation is off',
        'kchainLimit': 'Chain limit reached',
        'kinvalidRule': 'Invalid rule',
        'kruleDisabled': 'Rule is disabled',
        'kwrongTrigger': 'Different trigger',
        'kplatform': 'Platform does not match',
        'krole': 'Role does not match',
        'knotStreaming': 'OBS is not streaming',
        'ktextMismatch': 'Text does not match',
        'kamountUnknown': 'Amount is unknown',
        'kcurrencyMismatch': 'Currency does not match',
        'kbelowMinimum': 'Below the minimum',
        'kcooldown': 'Rule is cooling down',
        'kuserCooldown': 'Person is cooling down',
        'ktrippedReason': 'Automation paused by the safety limit',
        'krunRateExceeded': 'Too many runs in a minute',
        'koverlapSkipped': 'Already running',
        'kqueueFull': 'Queue is full',
        'knoPreviousScene': 'No previous scene saved',
        'ktargetError': 'Action failed',
        'ktimeout': 'Action timed out',
        'kdisposed': 'Engine is closed',
        'knotConnected': 'OBS is disconnected',
        'kttsOff': 'Voice reader is off or not ready',
        'knoMessage': 'No chat message available',
        'kgoalNotFound': 'Goal not found',
        'ktimerNotRunning': 'Subathon is not running',
        'knoReceiver': 'No template receiver connected',
        'kinvalidKeyword': 'Invalid keyword',
        'kalreadyOpen': 'Giveaway is already open',
        'knotOpen': 'Giveaway is not open',
        'knoEntrants': 'No eligible entrants',
        'kqueue_joined': 'Viewer joined the queue',
        'kqueue_next': 'Next players',
        'kqueue_open': 'Open the queue',
        'kqueue_close': 'Close the queue',
        'kqueue_pause': 'Pause the queue',
        'kwinnerCount': 'Winners',
        'kcount': 'Players',
        'krandom': 'Pick randomly',
        'kqueueAlreadyOpen': 'The queue is already open',
        'kqueueAlreadyPaused': 'The queue is already paused',
        'kqueueAlreadyClosed': 'The queue is already closed',
        'kqueueEmpty': 'Nobody is waiting in the queue',
        'kcounterLimit': 'Counter limit reached',
        'krecipe1': 'Welcome a raid',
        'krecipeDesc1': 'Show Raid for 15 seconds, then return.',
        'krecipe2': 'Share your socials',
        'krecipeDesc2': 'Trigger redes and read your links aloud.',
        'krecipe3': 'Read Super Chats',
        'krecipeDesc3': 'Read messages with an amount of at least \$5.',
        'krecipe4': 'Regular reminder',
        'krecipeDesc4': 'Trigger recordatorio every 20 minutes.',
        'krecipe5': 'Celebrate a goal',
        'krecipeDesc5': 'Show Celebración for 10 seconds, then return.',
        'krecipe6': 'Count deaths',
        'krecipeDesc6': 'Moderators add to muertes and trigger a template.',
        'krecipe7': 'Counter on screen',
        'krecipeDesc7':
            'Moderators add to muertes and show it in a text source.',
        'kdiscardAction': 'Discard',
        'kbuttons': 'Rule buttons',
        'knotFound': 'Item not found',
        'knotTextSource': 'Not a text source',
        'knoAlertsPage': 'No alerts page connected',
        'kwillCheckInObs': 'Will check in OBS',
        'kwouldSkip': 'Would be skipped',
        'kwebhook': 'Webhook name (optional)',
        'kwebhookConflict': 'This webhook name is already used.',
        'kwebhookTitle': 'Stream Deck and other apps',
        'kwebhookEnable': 'Enable local rule URLs',
        'kwebhookHelp':
            'Stream Deck: use the Website action with GET request in background. Any app or script can call the URL.',
        'kwebhookSecretWarning':
            'Anyone with the URL can run these rules. Keep it private.',
        'kwebhookServerHelp':
            'Enable the local server in OBS settings to use these URLs.',
        'khideToken': 'Hide token',
        'krevealToken': 'Reveal token',
        'kcopyToken': 'Copy token',
        'kregenerate': 'Regenerate',
        'kregenerateConfirm':
            'Regenerate token? Existing buttons will stop working.',
        'kexportRules': 'Export rules',
        'kimportRules': 'Import rules',
        'kimportReview': 'Review imported rules',
        'kimportDisabled':
            'All imported rules will be disabled. Review them before enabling.',
        'kimportSkipped': 'Rules skipped (50-rule limit)',
        'kwebhookCollision': 'Webhook name removed because it is already used:',
        'kobsNames': 'Check these names exist in your OBS:',
        'kmissingMedia': 'Library media missing here (action kept):',
        'ktemplateName': 'Template trigger name:',
        'kunknownFormat': 'Unknown rules file format.',
        'kunknownVersion': 'Unsupported rules file version.',
        'kmalformedJson': 'Invalid rules JSON file.',
        'kfileTooLarge': 'Rules file exceeds 1 MB.',
        'ksharingFailed': 'Could not read or write the rules file.',
        'kobs_stream': 'Streaming',
        'kobs_replay': 'Replay buffer',
        'kobs_media': 'Control media',
        'kobs_volume': 'Volume',
        'kobs_refresh': 'Refresh browser source',
        'khttp_request': 'Call a URL',
        'kstreamStart': 'Start stream',
        'kstreamStop': 'Stop stream',
        'kreplaySave': 'Save replay',
        'kplay': 'Play',
        'kpause': 'Pause',
        'kreset': 'Reset',
        'krestart': 'Restart',
        'kmode': 'Mode',
        'kchange': 'Change',
        'kdb': 'dB',
        'kmethod': 'Method',
        'kget': 'GET',
        'kpost': 'POST',
        'kurl': 'URL',
        'kcontentType': 'Content type',
        'kjson': 'JSON',
        'kbody': 'Body',
        'kstreamAlready': 'Stream is already in that state',
        'kpublicStreamControl':
            'Viewers cannot start or stop the stream. Choose a manual, timer or stream/recording trigger, or limit a chat, queue join or support trigger to moderators or the owner.',
        'kreplayOff': 'The replay buffer is off',
        'kreplayAlready': 'Replay buffer is already in that state',
        'knotBrowserSource': 'Not a browser source',
        'knoUrl': 'Missing URL',
        'kinvalidHttpUrl': 'Enter a valid HTTP or HTTPS URL',
        'khttpStatus': 'The URL returned an error',
        'khttpError': 'Could not connect to the URL',
        'kresetHttpUrl': 'Set the URL again in:',
        'krecipe8': 'Tell Discord you are live',
        'krecipeDesc8':
            'Paste your Discord webhook URL to announce your stream.',
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
      other: '$count actions',
      one: '1 action',
    );
    return 'When $trigger → $_temp0';
  }

  @override
  String get templatesGallery => 'Gallery';

  @override
  String get galleryAdd => 'Add';

  @override
  String get galleryAddAgain => 'Add again';

  @override
  String get galleryNewVersion => 'A new version is available';

  @override
  String get galleryPreviewUnavailable =>
      'Start the server to preview gallery items.';

  @override
  String get galleryRecentSupport => 'Recent support';

  @override
  String get galleryRecentSupportDescription =>
      'Show the latest support from YouTube, Twitch, and Kick.';

  @override
  String get galleryTheme => 'Theme';

  @override
  String get galleryFont => 'Font';

  @override
  String get galleryAccent => 'Accent color';

  @override
  String get galleryLogo => 'Logo';

  @override
  String get galleryLanguage => 'Language';

  @override
  String get galleryHeading => 'Custom heading';

  @override
  String get gallerySupportCount => 'Maximum entries';

  @override
  String get galleryShowEmpty => 'Show the empty message';

  @override
  String get galleryStartingSoon => 'Starting soon';

  @override
  String get galleryStartingSoonDescription =>
      'Open the stream with a countdown, rotating messages, and live chat.';

  @override
  String get galleryBeRightBack => 'Be right back';

  @override
  String get galleryBeRightBackDescription =>
      'Show a break timer alongside live chat and the latest support.';

  @override
  String get galleryStreamEnding => 'Stream ending';

  @override
  String get galleryStreamEndingDescription =>
      'Thank viewers with session totals and supporter rankings.';

  @override
  String get galleryCredits => 'Credits';

  @override
  String get galleryCreditsDescription =>
      'Roll end credits with supporters, rankings, and a farewell.';

  @override
  String get galleryBackground => 'Background';

  @override
  String get galleryBackgroundMedia => 'Background image or video';

  @override
  String get galleryMessages => 'Rotating messages (separate with |)';

  @override
  String get galleryScreenTitle => 'Title (leave blank for the default)';

  @override
  String get gallerySubtitle => 'Subtitle';

  @override
  String get galleryStartTime => 'Local start time (24-hour HH:MM)';

  @override
  String get galleryShowChat => 'Show live chat';

  @override
  String get galleryMinutes => 'Countdown minutes (0 for none)';

  @override
  String get galleryShowDuration => 'Show session duration';

  @override
  String get galleryShowMessages => 'Show message count';

  @override
  String get galleryShowChatters => 'Show chatter count';

  @override
  String get galleryShowSupporters => 'Show supporter count';

  @override
  String get galleryShowTopSupporters => 'Show top supporters';

  @override
  String get galleryShowTopChatters => 'Show top chatters';

  @override
  String get galleryCurrency => 'Super Chat currency (blank for automatic)';

  @override
  String get galleryFinalText => 'Final message';

  @override
  String get galleryCreditsSpeed => 'Roll speed (pixels per second)';

  @override
  String get galleryCreditsLoop => 'Repeat credits';

  @override
  String get galleryTicker => 'Ticker';

  @override
  String get galleryTickerDescription =>
      'Scroll messages, recent support, goals, and subathon time across the stream.';

  @override
  String get galleryLatestSupport => 'Latest support';

  @override
  String get galleryLatestSupportDescription =>
      'Spotlight the newest supporter or rotate through support types.';

  @override
  String get galleryTopSupporters => 'Top of the stream';

  @override
  String get galleryTopSupportersDescription =>
      'Show the five leading supporters or chatters in a session.';

  @override
  String get galleryTickerMessages => 'Ticker messages (separate with |)';

  @override
  String get galleryTickerSpeed => 'Scroll speed (pixels per second)';

  @override
  String get galleryTickerShowCustom => 'Show custom messages';

  @override
  String get galleryTickerShowLatest => 'Show the latest support by type';

  @override
  String get galleryTickerShowGoals => 'Show goal progress';

  @override
  String get galleryTickerShowTimer => 'Show the running subathon timer';

  @override
  String get galleryTickerShowEmpty => 'Show the ticker title when empty';

  @override
  String get galleryLatestSupportMode => 'Support display mode';

  @override
  String get galleryRotationSeconds => 'Seconds between entries';

  @override
  String get galleryRankingType => 'Leaderboard type';

  @override
  String get queueTitle => 'Queue';

  @override
  String get queueClosed => 'Closed';

  @override
  String get queueOpenStatus => 'Open';

  @override
  String get queuePaused => 'Paused';

  @override
  String get queueOpen => 'Open';

  @override
  String get queuePause => 'Pause';

  @override
  String get queueClose => 'Close';

  @override
  String queueJoinHint(String command) {
    return 'Type $command to play';
  }

  @override
  String get queueEmpty => 'Nobody is waiting';

  @override
  String get queueNext => 'Next';

  @override
  String get queueNextCount => 'Players';

  @override
  String get queueRandom => 'Random';

  @override
  String get queueClear => 'Clear';

  @override
  String get queueClearConfirm => 'Clear the queue and everyone playing?';

  @override
  String get queuePlaying => 'Playing now';

  @override
  String get queueNobodyPlaying => 'Nobody is playing';

  @override
  String get queueSettings => 'Queue settings';

  @override
  String get queueMax => 'Maximum queue size';

  @override
  String get queueRoles => 'Who can join';

  @override
  String get queueEveryone => 'Everyone';

  @override
  String get queueMembers => 'Members and subscribers';

  @override
  String get queueVip => 'VIPs';

  @override
  String get queueModerators => 'Moderators';

  @override
  String get queuePriority => 'Prioritize members and subscribers';

  @override
  String get queueRejoin => 'Allow joining again after playing';

  @override
  String get queueChatMods => 'Moderator chat commands';

  @override
  String get queueChatModsHint =>
      'Allows the owner and moderators to manage the queue from chat.';

  @override
  String get queueCommand => 'Join command';

  @override
  String queueJoinWhenOpen(String command) {
    return 'Type $command to play when the queue opens';
  }

  @override
  String get queueReservedCommand =>
      'This command is reserved. Choose another one.';

  @override
  String get queueInvalidCommand =>
      'Use ! followed by 1–24 letters, digits, hyphens or underscores.';

  @override
  String get queueSave => 'Save';

  @override
  String get queueRemove => 'Remove';

  @override
  String get queueDone => 'Done';

  @override
  String get galleryQueueDescription =>
      'Show who is playing and who is waiting for a turn.';

  @override
  String get galleryQueueCount => 'Queue entries to show';

  @override
  String get galleryQueueHideClosed => 'Hide when the queue is closed';

  @override
  String get galleryQueueWaiting => 'Up next';

  @override
  String galleryQueueMore(String count) {
    return '+$count more';
  }

  @override
  String get alertQueuePause => 'Pause alerts';

  @override
  String get alertQueueResume => 'Resume alerts';

  @override
  String get alertQueueSkip => 'Skip current alert';

  @override
  String get alertQueueClear => 'Clear waiting alerts';

  @override
  String alertQueueWaiting(int count) {
    return '$count waiting';
  }

  @override
  String get alertQueueWaitingHint => 'Largest queue across open alerts pages';

  @override
  String get alertQueueNoPage => 'Open the alerts page to control its queue.';

  @override
  String get alertPlatformFilter => 'Automatic alerts by platform';

  @override
  String get alertTiers => 'Tiers by amount';

  @override
  String get alertTierCurrency =>
      'Super Chats use the original currency without conversion.';

  @override
  String get alertTierFrom => 'From amount';

  @override
  String get alertTierInvalid => 'Enter a number greater than zero.';

  @override
  String get alertTierAdd => 'Add tier';

  @override
  String get alertTierRemove => 'Remove tier';

  @override
  String get alertTierInherit => 'Use alert type setting';

  @override
  String get alertTierAudioOn => 'Play audio';

  @override
  String get alertTierAudioOff => 'Mute audio';

  @override
  String get featuredTitle => 'Featured message';

  @override
  String get featuredDescription => 'Shows messages you feature on stream.';

  @override
  String get featuredUrlCopied => 'Featured page URL copied';

  @override
  String get featuredRemove => 'Remove featured';

  @override
  String get featuredFontScale => 'Featured text size';

  @override
  String get featuredKeepVisible => 'Keep visible until removed';

  @override
  String get ttsWhatToRead => 'What to read';

  @override
  String get ttsReaderRoles => 'Roles';

  @override
  String get ttsRoleEveryone => 'Everyone';

  @override
  String get ttsRoleModerator => 'Moderator';

  @override
  String get ttsRoleVip => 'VIP';

  @override
  String get ttsRoleOwner => 'Owner';

  @override
  String get ttsReaderPlatforms => 'Platforms';

  @override
  String get ttsAlwaysReadSupport => 'Always read paid support';

  @override
  String get ttsSkipEmoteOnly => 'Skip emote-only messages';

  @override
  String get ttsLinks => 'Links';

  @override
  String get ttsLinksRead => 'Read the message';

  @override
  String get ttsLinksSay => 'Say “link”';

  @override
  String get ttsLinksSkip => 'Skip the message';

  @override
  String get ttsSpokenLink => 'link';

  @override
  String get highlightSoundMention => 'Mention';

  @override
  String get highlightSoundWord => 'Highlighted word';

  @override
  String get highlightSoundFirstMessage => 'First message';

  @override
  String get highlightSoundPriority =>
      'If several highlights match, the mention takes priority, then the word, then the first message.';

  @override
  String get sessionExportChat => 'Export chat (CSV)';

  @override
  String get sessionExportParticipants => 'Export participants (CSV)';

  @override
  String get sessionExportFailed => 'Could not save the CSV file.';

  @override
  String sessionExportChatScope(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The chat export is limited to the last $count retained messages.',
      one: 'Chat export includes 1 retained message.',
      zero: 'No chat messages are retained.',
    );
    return '$_temp0';
  }

  @override
  String get clockTitle => 'Timer';

  @override
  String get clockDescription =>
      'Run a countdown, stopwatch, or local clock on stream.';

  @override
  String get clockMode => 'Mode';

  @override
  String get clockCountdown => 'Countdown';

  @override
  String get clockStopwatch => 'Stopwatch';

  @override
  String get clockLocalTime => 'Local time';

  @override
  String get clockLabel => 'Label';

  @override
  String get clockDuration => 'Duration in seconds (1–86,400)';

  @override
  String get clockSound => 'Sound at the end';

  @override
  String get clockSoundNone => 'No sound';

  @override
  String get clockStyle => 'Page style';

  @override
  String get clockStyleBig => 'Large';

  @override
  String get clockStyleCompact => 'Compact';

  @override
  String get clockStyleRing => 'Progress ring (countdown)';

  @override
  String get clockEnded => 'Time’s up!';

  @override
  String get clockPause => 'Pause';

  @override
  String get clockReset => 'Reset';

  @override
  String get clockPlusMinute => '+1 min';

  @override
  String get clockMinusMinute => '−1 min';

  @override
  String get pollSaveSetup => 'Save current setup';

  @override
  String get pollRenameSetup => 'Rename saved poll';

  @override
  String get pollDeleteSetup => 'Delete saved poll';

  @override
  String get pollSetupName => 'Name for this setup';

  @override
  String get pollSetupDuplicate => 'That name is already in use.';

  @override
  String get pollSavedSetups => 'Saved polls';

  @override
  String get pollSetupLimit => 'Delete a saved poll to make room for another.';

  @override
  String get giveawayDrawCount => 'Winners per draw';

  @override
  String giveawayDrawMany(int count) {
    return 'Draw $count winners';
  }

  @override
  String get giveawayHistory => 'Giveaway history';

  @override
  String get giveawayHistoryEmpty => 'No completed rounds yet.';

  @override
  String get giveawayClearHistory => 'Clear history';

  @override
  String giveawayStartedAt(String date) {
    return 'Started $date';
  }

  @override
  String giveawayEndedAt(String date) {
    return 'Ended $date';
  }

  @override
  String get giveawayNoWinners => 'No winners';

  @override
  String giveawayAllWinners(int count) {
    return 'All winners this round ($count)';
  }

  @override
  String get galleryScoreboard => 'Scoreboard';

  @override
  String get galleryScoreboardDescription =>
      'Show selected rule counters and their current values.';

  @override
  String get galleryScoreboardCounters =>
      'Counter names, separated by commas (up to 8)';

  @override
  String get galleryScoreboardLabels =>
      'Labels in the same order, separated by commas';

  @override
  String get galleryScoreboardLayout => 'Layout';

  @override
  String get galleryWordCloud => 'Word cloud';

  @override
  String get galleryWordCloudDescription =>
      'Display the most frequent words from the last five minutes of chat.';

  @override
  String get galleryWordCloudMinLength => 'Minimum word length';

  @override
  String get galleryWordCloudMaxWords => 'Maximum words';

  @override
  String get galleryWordCloudRefresh => 'Refresh interval (seconds)';

  @override
  String get galleryEmoteWall => 'Emote wall';

  @override
  String get galleryEmoteWallDescription =>
      'Float emotes from chat across the screen as they arrive.';

  @override
  String get galleryEmoteWallMax => 'Maximum emotes on screen';

  @override
  String get galleryEmoteWallSize => 'Emote size (pixels)';

  @override
  String get galleryEmoteWallLifetime => 'Time on screen (seconds)';

  @override
  String get clockPaused => 'Paused';

  @override
  String get galleryScoreboardHome => 'Home';

  @override
  String get galleryScoreboardAway => 'Away';

  @override
  String get galleryScoreboardRow => 'Row';

  @override
  String get galleryScoreboardColumn => 'Column';

  @override
  String get backupExportEverything => 'Export everything';

  @override
  String get backupRestoreEverything => 'Restore everything';

  @override
  String get backupFileType => 'Airstream backup';

  @override
  String get backupRestoreReview =>
      'This replaces your settings, templates and media library. Airstream saves a copy of your current data first.';

  @override
  String backupRestoreContents(
      int rules, int templates, int media, String created) {
    return 'Settings\nRules: $rules\nTemplates: $templates\nMedia files: $media\nCreated: $created';
  }

  @override
  String get backupRestoreConfirm => 'Restore';

  @override
  String get backupExportDone => 'Full backup exported.';

  @override
  String get backupRestoreDone => 'Full backup restored.';

  @override
  String get backupExportError =>
      'Could not export the full backup. Check the destination and the files in your libraries.';

  @override
  String get backupRestoreError =>
      'Could not restore the backup. Check disk space and close programs using the library files.';

  @override
  String get backupInvalid =>
      'This file is damaged or is not an Airstream full backup.';

  @override
  String get backupUnsupportedVersion =>
      'This backup version is not supported.';

  @override
  String get backupUnsafePath => 'The backup contains an unsafe file path.';

  @override
  String get backupSizeLimit =>
      'A file or library exceeds the backup size limits.';

  @override
  String get backupMediaInvalid =>
      'A media file is missing or does not match its library entry.';

  @override
  String get backupRollbackError =>
      'Restore was interrupted and automatic rollback failed. Your safety backup and original directories are still on disk.';

  @override
  String get settingsSearchHint => 'Search settings';

  @override
  String get settingsSearchEmpty => 'No matching settings';

  @override
  String get settingsSearchConnectionWords =>
      'accounts channels login streaming';

  @override
  String get settingsSearchVoiceWords => 'tts text to speech reader narration';

  @override
  String get settingsSearchCaptionWords =>
      'subtitles transcription accessibility';

  @override
  String get settingsSearchBackupWords => 'archive zip migration recovery';

  @override
  String get settingsSearchMediaWords =>
      'assets files mp3 mp4 images video sound';

  @override
  String get settingsSearchAppearanceWords => 'theme colors typography';

  @override
  String get settingsSearchRulesWords =>
      'automation webhook stream deck actions';

  @override
  String get mediaSearch => 'Search media by name';

  @override
  String get mediaNoMatches => 'No matching media';

  @override
  String get mediaPreview => 'Preview';

  @override
  String get mediaPreviewUnavailable => 'Preview unavailable for this file.';

  @override
  String get mediaPreviewPlay => 'Play';

  @override
  String get mediaPreviewStop => 'Stop';

  @override
  String get mediaRename => 'Rename';

  @override
  String get mediaDisplayName => 'Display name';

  @override
  String get mediaRenameInvalid =>
      'Enter a name without slashes or control characters.';

  @override
  String get mediaRenameFailed => 'Could not save the new name.';
}

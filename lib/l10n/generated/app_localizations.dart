import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @listeningForMessages.
  ///
  /// In en, this message translates to:
  /// **'Listening for messages...'**
  String get listeningForMessages;

  /// No description provided for @channelsSavedStartPrompt.
  ///
  /// In en, this message translates to:
  /// **'Channels saved.\nPress Start when you want to listen.'**
  String get channelsSavedStartPrompt;

  /// No description provided for @noChannelsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No channels configured.\nConfigure channels in the sidebar.'**
  String get noChannelsConfigured;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @hideSidebarTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide sidebar (Ctrl+B)'**
  String get hideSidebarTooltip;

  /// No description provided for @showSidebarTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show sidebar (Ctrl+B)'**
  String get showSidebarTooltip;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connections;

  /// No description provided for @youtubeInputLabel.
  ///
  /// In en, this message translates to:
  /// **'YouTube handle, channel ID, video ID, or URL'**
  String get youtubeInputLabel;

  /// No description provided for @twitchChannel.
  ///
  /// In en, this message translates to:
  /// **'Twitch channel'**
  String get twitchChannel;

  /// No description provided for @kickSlug.
  ///
  /// In en, this message translates to:
  /// **'Kick slug'**
  String get kickSlug;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Start chat'**
  String get startChat;

  /// No description provided for @stopChat.
  ///
  /// In en, this message translates to:
  /// **'Stop chat'**
  String get stopChat;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @backgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background opacity'**
  String get backgroundOpacity;

  /// No description provided for @bubbleOpacity.
  ///
  /// In en, this message translates to:
  /// **'Bubble opacity'**
  String get bubbleOpacity;

  /// No description provided for @borderRadius.
  ///
  /// In en, this message translates to:
  /// **'Border radius'**
  String get borderRadius;

  /// No description provided for @messageGap.
  ///
  /// In en, this message translates to:
  /// **'Message gap'**
  String get messageGap;

  /// No description provided for @maxMessageWidth.
  ///
  /// In en, this message translates to:
  /// **'Max message width'**
  String get maxMessageWidth;

  /// No description provided for @horizontalPadding.
  ///
  /// In en, this message translates to:
  /// **'Horizontal padding'**
  String get horizontalPadding;

  /// No description provided for @avatars.
  ///
  /// In en, this message translates to:
  /// **'Avatars'**
  String get avatars;

  /// No description provided for @platformIcon.
  ///
  /// In en, this message translates to:
  /// **'Platform icon'**
  String get platformIcon;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

  /// No description provided for @bubble.
  ///
  /// In en, this message translates to:
  /// **'Bubble'**
  String get bubble;

  /// No description provided for @bubbleShadow.
  ///
  /// In en, this message translates to:
  /// **'Bubble shadow'**
  String get bubbleShadow;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filtersDescription.
  ///
  /// In en, this message translates to:
  /// **'Blocked users and words are filtered in the message pipeline, so they are removed for your local chat view, TTS and the Shelf overlay.'**
  String get filtersDescription;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @blockedUsersHelp.
  ///
  /// In en, this message translates to:
  /// **'One per line. Prefixing with @ is optional.'**
  String get blockedUsersHelp;

  /// No description provided for @blockedWordsOrPhrases.
  ///
  /// In en, this message translates to:
  /// **'Blocked words or phrases'**
  String get blockedWordsOrPhrases;

  /// No description provided for @blockedWordsHelp.
  ///
  /// In en, this message translates to:
  /// **'Single words respect token boundaries. Phrases are matched after normalization.'**
  String get blockedWordsHelp;

  /// No description provided for @ttsDescription.
  ///
  /// In en, this message translates to:
  /// **'Read chat messages aloud with configurable voice, language and command behavior.'**
  String get ttsDescription;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @membersOnly.
  ///
  /// In en, this message translates to:
  /// **'Members only'**
  String get membersOnly;

  /// No description provided for @commandMode.
  ///
  /// In en, this message translates to:
  /// **'Command mode (custom prefix)'**
  String get commandMode;

  /// No description provided for @commandPrefix.
  ///
  /// In en, this message translates to:
  /// **'Command prefix'**
  String get commandPrefix;

  /// No description provided for @ignoreCommandCase.
  ///
  /// In en, this message translates to:
  /// **'Ignore uppercase/lowercase in prefix'**
  String get ignoreCommandCase;

  /// No description provided for @separatorText.
  ///
  /// In en, this message translates to:
  /// **'Separator text'**
  String get separatorText;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @ttsEngine.
  ///
  /// In en, this message translates to:
  /// **'Voice engine'**
  String get ttsEngine;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @qualityFast.
  ///
  /// In en, this message translates to:
  /// **'Fast (4 steps)'**
  String get qualityFast;

  /// No description provided for @qualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High (6 steps)'**
  String get qualityHigh;

  /// No description provided for @qualityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced (8 steps)'**
  String get qualityBalanced;

  /// No description provided for @qualityMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum (12 steps)'**
  String get qualityMaximum;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @removeTtsModel.
  ///
  /// In en, this message translates to:
  /// **'Remove downloaded model'**
  String get removeTtsModel;

  /// No description provided for @downloadTtsModel.
  ///
  /// In en, this message translates to:
  /// **'Download model'**
  String get downloadTtsModel;

  /// No description provided for @removeTtsModelConfirmation.
  ///
  /// In en, this message translates to:
  /// **'TTS will be disabled and the selected model will be deleted from this device. It can be downloaded again later.'**
  String get removeTtsModelConfirmation;

  /// No description provided for @removeTtsModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {model}?'**
  String removeTtsModelTitle(String model);

  /// No description provided for @removeTtsModelConfirmationNamed.
  ///
  /// In en, this message translates to:
  /// **'{model} will be deleted from this device and TTS will be turned off. You can download it again later.'**
  String removeTtsModelConfirmationNamed(String model);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ttsModelRemoved.
  ///
  /// In en, this message translates to:
  /// **'The TTS model was removed.'**
  String get ttsModelRemoved;

  /// No description provided for @ttsModelRemovalFailed.
  ///
  /// In en, this message translates to:
  /// **'The TTS model could not be removed: {error}'**
  String ttsModelRemovalFailed(String error);

  /// No description provided for @testText.
  ///
  /// In en, this message translates to:
  /// **'Test text'**
  String get testText;

  /// No description provided for @playingTts.
  ///
  /// In en, this message translates to:
  /// **'Playing TTS...'**
  String get playingTts;

  /// No description provided for @loadingTts.
  ///
  /// In en, this message translates to:
  /// **'Loading TTS...'**
  String get loadingTts;

  /// No description provided for @testTts.
  ///
  /// In en, this message translates to:
  /// **'Test TTS'**
  String get testTts;

  /// No description provided for @ttsDisabledHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn it on to configure voice, language and test playback.'**
  String get ttsDisabledHelp;

  /// No description provided for @obsIntegration.
  ///
  /// In en, this message translates to:
  /// **'OBS Integration'**
  String get obsIntegration;

  /// No description provided for @obsDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to OBS over WebSocket to show stream, recording and scene status inside Airstream.'**
  String get obsDescription;

  /// No description provided for @webSocketHost.
  ///
  /// In en, this message translates to:
  /// **'WebSocket host'**
  String get webSocketHost;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @optionalPassword.
  ///
  /// In en, this message translates to:
  /// **'Optional password'**
  String get optionalPassword;

  /// No description provided for @connectingToObs.
  ///
  /// In en, this message translates to:
  /// **'Connecting to OBS...'**
  String get connectingToObs;

  /// No description provided for @disconnectObs.
  ///
  /// In en, this message translates to:
  /// **'Disconnect OBS'**
  String get disconnectObs;

  /// No description provided for @reconnectObs.
  ///
  /// In en, this message translates to:
  /// **'Reconnect OBS'**
  String get reconnectObs;

  /// No description provided for @connectObs.
  ///
  /// In en, this message translates to:
  /// **'Connect OBS'**
  String get connectObs;

  /// No description provided for @hudElements.
  ///
  /// In en, this message translates to:
  /// **'HUD Elements'**
  String get hudElements;

  /// No description provided for @globalHud.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get globalHud;

  /// No description provided for @streamHud.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get streamHud;

  /// No description provided for @recordingHud.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingHud;

  /// No description provided for @streamState.
  ///
  /// In en, this message translates to:
  /// **'Stream state'**
  String get streamState;

  /// No description provided for @currentScene.
  ///
  /// In en, this message translates to:
  /// **'Current scene'**
  String get currentScene;

  /// No description provided for @bitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get bitrate;

  /// No description provided for @fps.
  ///
  /// In en, this message translates to:
  /// **'FPS'**
  String get fps;

  /// No description provided for @droppedFrames.
  ///
  /// In en, this message translates to:
  /// **'Dropped frames'**
  String get droppedFrames;

  /// No description provided for @recordingState.
  ///
  /// In en, this message translates to:
  /// **'Recording state'**
  String get recordingState;

  /// No description provided for @recordingDuration.
  ///
  /// In en, this message translates to:
  /// **'Recording duration'**
  String get recordingDuration;

  /// No description provided for @recordingSize.
  ///
  /// In en, this message translates to:
  /// **'Recording size'**
  String get recordingSize;

  /// No description provided for @obsDisabledHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn it on to enter the OBS host, password and connect on demand.'**
  String get obsDisabledHelp;

  /// No description provided for @overlayServer.
  ///
  /// In en, this message translates to:
  /// **'Overlay Server'**
  String get overlayServer;

  /// No description provided for @overlayServerDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable a local browser source for OBS. When active, Airstream serves an overlay URL that you can paste into OBS.'**
  String get overlayServerDescription;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @chatObsUrl.
  ///
  /// In en, this message translates to:
  /// **'Chat OBS URL'**
  String get chatObsUrl;

  /// No description provided for @chatObsUrlDescription.
  ///
  /// In en, this message translates to:
  /// **'Use this link as a Browser Source for chat in OBS.'**
  String get chatObsUrlDescription;

  /// No description provided for @chatOverlayUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Chat overlay URL copied'**
  String get chatOverlayUrlCopied;

  /// No description provided for @alertsObsUrl.
  ///
  /// In en, this message translates to:
  /// **'Alerts OBS URL'**
  String get alertsObsUrl;

  /// No description provided for @alertsObsUrlDescription.
  ///
  /// In en, this message translates to:
  /// **'Use this as a separate Browser Source for Super Chats and memberships.'**
  String get alertsObsUrlDescription;

  /// No description provided for @alertsOverlayUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Alerts overlay URL copied'**
  String get alertsOverlayUrlCopied;

  /// No description provided for @oneOverlayClientConnected.
  ///
  /// In en, this message translates to:
  /// **'1 overlay client connected'**
  String get oneOverlayClientConnected;

  /// No description provided for @overlayClientsConnected.
  ///
  /// In en, this message translates to:
  /// **'{count} overlay clients connected'**
  String overlayClientsConnected(int count);

  /// No description provided for @overlayReloadSent.
  ///
  /// In en, this message translates to:
  /// **'Overlay reload sent'**
  String get overlayReloadSent;

  /// No description provided for @noOverlayClientConnected.
  ///
  /// In en, this message translates to:
  /// **'No overlay client connected'**
  String get noOverlayClientConnected;

  /// No description provided for @reloadOverlay.
  ///
  /// In en, this message translates to:
  /// **'Reload Overlay'**
  String get reloadOverlay;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @alertsDescription.
  ///
  /// In en, this message translates to:
  /// **'YouTube Super Chats and membership events show on /alerts. The alert payload keeps platform data so Twitch and Kick can be added later.'**
  String get alertsDescription;

  /// No description provided for @alertFontSize.
  ///
  /// In en, this message translates to:
  /// **'Alert font size'**
  String get alertFontSize;

  /// No description provided for @alertDuration.
  ///
  /// In en, this message translates to:
  /// **'Alert duration'**
  String get alertDuration;

  /// No description provided for @alertAvatars.
  ///
  /// In en, this message translates to:
  /// **'Alert avatars'**
  String get alertAvatars;

  /// No description provided for @testAlertSent.
  ///
  /// In en, this message translates to:
  /// **'Test alert sent'**
  String get testAlertSent;

  /// No description provided for @openAlertsOverlayFirst.
  ///
  /// In en, this message translates to:
  /// **'Open the alerts overlay in OBS/browser first'**
  String get openAlertsOverlayFirst;

  /// No description provided for @overlayMode.
  ///
  /// In en, this message translates to:
  /// **'Overlay Mode'**
  String get overlayMode;

  /// No description provided for @chromaKey.
  ///
  /// In en, this message translates to:
  /// **'Chroma key'**
  String get chromaKey;

  /// No description provided for @showGrid.
  ///
  /// In en, this message translates to:
  /// **'Show grid'**
  String get showGrid;

  /// No description provided for @hideScrollbar.
  ///
  /// In en, this message translates to:
  /// **'Hide scrollbar'**
  String get hideScrollbar;

  /// No description provided for @chromaColor.
  ///
  /// In en, this message translates to:
  /// **'Chroma color'**
  String get chromaColor;

  /// No description provided for @platformDisplay.
  ///
  /// In en, this message translates to:
  /// **'Platform Display'**
  String get platformDisplay;

  /// No description provided for @twitchAccent.
  ///
  /// In en, this message translates to:
  /// **'Twitch accent'**
  String get twitchAccent;

  /// No description provided for @kickAccent.
  ///
  /// In en, this message translates to:
  /// **'Kick accent'**
  String get kickAccent;

  /// No description provided for @styleSettings.
  ///
  /// In en, this message translates to:
  /// **'Style Settings'**
  String get styleSettings;

  /// No description provided for @lineHeight.
  ///
  /// In en, this message translates to:
  /// **'Line height'**
  String get lineHeight;

  /// No description provided for @fontWeight.
  ///
  /// In en, this message translates to:
  /// **'Font weight'**
  String get fontWeight;

  /// No description provided for @overlayBg.
  ///
  /// In en, this message translates to:
  /// **'Overlay bg'**
  String get overlayBg;

  /// No description provided for @textShadow.
  ///
  /// In en, this message translates to:
  /// **'Text shadow'**
  String get textShadow;

  /// No description provided for @textOutline.
  ///
  /// In en, this message translates to:
  /// **'Text outline'**
  String get textOutline;

  /// No description provided for @outlineColor.
  ///
  /// In en, this message translates to:
  /// **'Outline color'**
  String get outlineColor;

  /// No description provided for @messageDesign.
  ///
  /// In en, this message translates to:
  /// **'Message Design'**
  String get messageDesign;

  /// No description provided for @bubbleBackground.
  ///
  /// In en, this message translates to:
  /// **'Bubble background'**
  String get bubbleBackground;

  /// No description provided for @textAlignment.
  ///
  /// In en, this message translates to:
  /// **'Text alignment'**
  String get textAlignment;

  /// No description provided for @cornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get cornerRadius;

  /// No description provided for @verticalGap.
  ///
  /// In en, this message translates to:
  /// **'Vertical gap'**
  String get verticalGap;

  /// No description provided for @maxMessages.
  ///
  /// In en, this message translates to:
  /// **'Max messages'**
  String get maxMessages;

  /// No description provided for @messageLifetime.
  ///
  /// In en, this message translates to:
  /// **'Message lifetime'**
  String get messageLifetime;

  /// No description provided for @superChatColorBar.
  ///
  /// In en, this message translates to:
  /// **'SuperChat color bar'**
  String get superChatColorBar;

  /// No description provided for @superChatBarColor.
  ///
  /// In en, this message translates to:
  /// **'SuperChat bar color'**
  String get superChatBarColor;

  /// No description provided for @superChatWidth.
  ///
  /// In en, this message translates to:
  /// **'SuperChat width'**
  String get superChatWidth;

  /// No description provided for @animation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get animation;

  /// No description provided for @entrance.
  ///
  /// In en, this message translates to:
  /// **'Entrance'**
  String get entrance;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @transform3d.
  ///
  /// In en, this message translates to:
  /// **'3D Transform'**
  String get transform3d;

  /// No description provided for @enable3dEffect.
  ///
  /// In en, this message translates to:
  /// **'Enable 3D effect'**
  String get enable3dEffect;

  /// No description provided for @perspective.
  ///
  /// In en, this message translates to:
  /// **'Perspective'**
  String get perspective;

  /// No description provided for @rotateX.
  ///
  /// In en, this message translates to:
  /// **'Rotate X'**
  String get rotateX;

  /// No description provided for @rotateY.
  ///
  /// In en, this message translates to:
  /// **'Rotate Y'**
  String get rotateY;

  /// No description provided for @rotateZ.
  ///
  /// In en, this message translates to:
  /// **'Rotate Z'**
  String get rotateZ;

  /// No description provided for @skewX.
  ///
  /// In en, this message translates to:
  /// **'Skew X'**
  String get skewX;

  /// No description provided for @scale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get scale;

  /// No description provided for @overlayDisabledHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn it on to choose a port and reveal the OBS URL.'**
  String get overlayDisabledHelp;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get checking;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @assetsProgress.
  ///
  /// In en, this message translates to:
  /// **'{loaded}/{total} assets'**
  String assetsProgress(int loaded, int total);

  /// No description provided for @currentFile.
  ///
  /// In en, this message translates to:
  /// **'Current: {file}'**
  String currentFile(String file);

  /// No description provided for @voiceStatus.
  ///
  /// In en, this message translates to:
  /// **'Voice: {voice}'**
  String voiceStatus(String voice);

  /// No description provided for @maleVoice.
  ///
  /// In en, this message translates to:
  /// **'Male {number}'**
  String maleVoice(String number);

  /// No description provided for @femaleVoice.
  ///
  /// In en, this message translates to:
  /// **'Female {number}'**
  String femaleVoice(String number);

  /// No description provided for @platformError.
  ///
  /// In en, this message translates to:
  /// **'{platform} error: {error}'**
  String platformError(String platform, String error);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @testAlerts.
  ///
  /// In en, this message translates to:
  /// **'Test alerts'**
  String get testAlerts;

  /// No description provided for @superChat.
  ///
  /// In en, this message translates to:
  /// **'SuperChat'**
  String get superChat;

  /// No description provided for @noMessage.
  ///
  /// In en, this message translates to:
  /// **'No message'**
  String get noMessage;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @voiceCloning.
  ///
  /// In en, this message translates to:
  /// **'Voice cloning (WAV)'**
  String get voiceCloning;

  /// No description provided for @usingBundledVoice.
  ///
  /// In en, this message translates to:
  /// **'Using bundled sample: {voice}'**
  String usingBundledVoice(String voice);

  /// No description provided for @chooseWav.
  ///
  /// In en, this message translates to:
  /// **'Choose WAV'**
  String get chooseWav;

  /// No description provided for @useBundledSample.
  ///
  /// In en, this message translates to:
  /// **'Use bundled sample'**
  String get useBundledSample;

  /// No description provided for @referenceTranscript.
  ///
  /// In en, this message translates to:
  /// **'Exact WAV transcript'**
  String get referenceTranscript;

  /// No description provided for @referenceTranscriptHint.
  ///
  /// In en, this message translates to:
  /// **'Type exactly what the audio says…'**
  String get referenceTranscriptHint;

  /// No description provided for @localCaptions.
  ///
  /// In en, this message translates to:
  /// **'Local captions'**
  String get localCaptions;

  /// No description provided for @captionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Listens to your microphone, detects speech, and creates live captions or translations in real-time without sending audio to the Internet.'**
  String get captionsDescription;

  /// No description provided for @captionsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get captionsEnabled;

  /// No description provided for @spokenLanguage.
  ///
  /// In en, this message translates to:
  /// **'Spoken language'**
  String get spokenLanguage;

  /// No description provided for @captionOutput.
  ///
  /// In en, this message translates to:
  /// **'Output / translation'**
  String get captionOutput;

  /// No description provided for @sendCaptionsToObs.
  ///
  /// In en, this message translates to:
  /// **'Send to OBS overlay'**
  String get sendCaptionsToObs;

  /// No description provided for @noiseReduction.
  ///
  /// In en, this message translates to:
  /// **'Reduce microphone background noise'**
  String get noiseReduction;

  /// No description provided for @voiceCommandsObs.
  ///
  /// In en, this message translates to:
  /// **'OBS voice commands'**
  String get voiceCommandsObs;

  /// No description provided for @wakeWord.
  ///
  /// In en, this message translates to:
  /// **'Wake word'**
  String get wakeWord;

  /// No description provided for @voiceCommandsExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples: “Airstream start recording”, “Airstream pause recording”, or “Airstream switch to scene camera”.'**
  String get voiceCommandsExamples;

  /// No description provided for @captionModelManual.
  ///
  /// In en, this message translates to:
  /// **'Offline captions · manual download'**
  String get captionModelManual;

  /// No description provided for @downloadCaptionModel.
  ///
  /// In en, this message translates to:
  /// **'Download caption model'**
  String get downloadCaptionModel;

  /// No description provided for @captionStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Offline captions are off.'**
  String get captionStatusIdle;

  /// No description provided for @captionStatusMissingModel.
  ///
  /// In en, this message translates to:
  /// **'Download offline speech recognition to begin.'**
  String get captionStatusMissingModel;

  /// No description provided for @captionStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading offline speech recognition…'**
  String get captionStatusDownloading;

  /// No description provided for @captionStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Preparing offline speech recognition…'**
  String get captionStatusLoading;

  /// No description provided for @captionStatusListening.
  ///
  /// In en, this message translates to:
  /// **'Listening to the microphone…'**
  String get captionStatusListening;

  /// No description provided for @captionStatusTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Creating captions locally…'**
  String get captionStatusTranscribing;

  /// No description provided for @captionStatusError.
  ///
  /// In en, this message translates to:
  /// **'Offline captions could not start.'**
  String get captionStatusError;

  /// No description provided for @obsCaptions.
  ///
  /// In en, this message translates to:
  /// **'OBS captions'**
  String get obsCaptions;

  /// No description provided for @obsCaptionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Independent browser source for live captions and translation.'**
  String get obsCaptionsDescription;

  /// No description provided for @ttsAndVoice.
  ///
  /// In en, this message translates to:
  /// **'TTS & Voice'**
  String get ttsAndVoice;

  /// No description provided for @obsAndOverlay.
  ///
  /// In en, this message translates to:
  /// **'OBS & Overlay'**
  String get obsAndOverlay;

  /// No description provided for @systemTab.
  ///
  /// In en, this message translates to:
  /// **'System & Window'**
  String get systemTab;

  /// No description provided for @desktopWindow.
  ///
  /// In en, this message translates to:
  /// **'Desktop Window'**
  String get desktopWindow;

  /// No description provided for @frameless.
  ///
  /// In en, this message translates to:
  /// **'Frameless'**
  String get frameless;

  /// No description provided for @framelessDescription.
  ///
  /// In en, this message translates to:
  /// **'No title bar, transparent borders'**
  String get framelessDescription;

  /// No description provided for @clickThrough.
  ///
  /// In en, this message translates to:
  /// **'Click-Through'**
  String get clickThrough;

  /// No description provided for @clickThroughDescription.
  ///
  /// In en, this message translates to:
  /// **'Clicks pass through the window (WS_EX_TRANSPARENT)'**
  String get clickThroughDescription;

  /// No description provided for @alwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Always on Top'**
  String get alwaysOnTop;

  /// No description provided for @alwaysOnTopDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep on top of all other windows'**
  String get alwaysOnTopDescription;

  /// No description provided for @antiCapture.
  ///
  /// In en, this message translates to:
  /// **'Anti-Capture / Privacy'**
  String get antiCapture;

  /// No description provided for @antiCaptureDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide window from screen capture and OBS'**
  String get antiCaptureDescription;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @toggleTopBarShortcut.
  ///
  /// In en, this message translates to:
  /// **'Toggle top bar'**
  String get toggleTopBarShortcut;

  /// No description provided for @toggleAlwaysOnTopShortcut.
  ///
  /// In en, this message translates to:
  /// **'Toggle Always on Top'**
  String get toggleAlwaysOnTopShortcut;

  /// No description provided for @toggleClickThroughShortcut.
  ///
  /// In en, this message translates to:
  /// **'Toggle Click-Through'**
  String get toggleClickThroughShortcut;

  /// No description provided for @alwaysOnTopActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disable Always on Top (Ctrl+Shift+P)'**
  String get alwaysOnTopActiveTooltip;

  /// No description provided for @alwaysOnTopInactiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Always on Top (Ctrl+Shift+P)'**
  String get alwaysOnTopInactiveTooltip;

  /// No description provided for @clickThroughActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Click-Through active. Disable (Ctrl+Shift+C)'**
  String get clickThroughActiveTooltip;

  /// No description provided for @clickThroughInactiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enable Click-Through (Ctrl+Shift+C)'**
  String get clickThroughInactiveTooltip;

  /// No description provided for @antiCaptureActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode active — window hidden from screen share/OBS'**
  String get antiCaptureActiveTooltip;

  /// No description provided for @antiCaptureInactiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide from screen share / captures'**
  String get antiCaptureInactiveTooltip;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @obsStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'OBS: Connecting...'**
  String get obsStatusConnecting;

  /// No description provided for @obsStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'OBS: Disconnected'**
  String get obsStatusDisconnected;

  /// No description provided for @obsStatusLiveAndRec.
  ///
  /// In en, this message translates to:
  /// **'OBS: Live + Rec'**
  String get obsStatusLiveAndRec;

  /// No description provided for @obsStatusLive.
  ///
  /// In en, this message translates to:
  /// **'OBS: Live'**
  String get obsStatusLive;

  /// No description provided for @obsStatusRecording.
  ///
  /// In en, this message translates to:
  /// **'OBS: Recording'**
  String get obsStatusRecording;

  /// No description provided for @obsStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'OBS: Connected'**
  String get obsStatusConnected;

  /// No description provided for @obsScenePrefix.
  ///
  /// In en, this message translates to:
  /// **'Scene: {scene}'**
  String obsScenePrefix(String scene);

  /// No description provided for @obsOutputLive.
  ///
  /// In en, this message translates to:
  /// **'Output: Live'**
  String get obsOutputLive;

  /// No description provided for @obsOutputOffline.
  ///
  /// In en, this message translates to:
  /// **'Output: Offline'**
  String get obsOutputOffline;

  /// No description provided for @obsRecordingPaused.
  ///
  /// In en, this message translates to:
  /// **'Recording: Paused'**
  String get obsRecordingPaused;

  /// No description provided for @obsRecordingActive.
  ///
  /// In en, this message translates to:
  /// **'Recording: Active'**
  String get obsRecordingActive;

  /// No description provided for @ttsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Reader (TTS)'**
  String get ttsCardTitle;

  /// No description provided for @voiceStatusBadge.
  ///
  /// In en, this message translates to:
  /// **'Voice: {status}'**
  String voiceStatusBadge(String status);

  /// No description provided for @voiceStatusNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get voiceStatusNotDownloaded;

  /// No description provided for @ttsSelectedModel.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get ttsSelectedModel;

  /// No description provided for @ttsModelStatusBadge.
  ///
  /// In en, this message translates to:
  /// **'{model} · {status}'**
  String ttsModelStatusBadge(String model, String status);

  /// No description provided for @ttsModelTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Download {download} · Installed {installed} · {license} · Version {version}'**
  String ttsModelTechnicalDetails(
      String download, String installed, String license, String version);

  /// No description provided for @ttsModelStorageDetails.
  ///
  /// In en, this message translates to:
  /// **'Download {download} · Disk space {installed}'**
  String ttsModelStorageDetails(String download, String installed);

  /// No description provided for @ttsModelVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant: {variant}'**
  String ttsModelVariant(String variant);

  /// No description provided for @ttsModelSupertonicDescription.
  ///
  /// In en, this message translates to:
  /// **'10 built-in voices optimized for quality and speed.'**
  String get ttsModelSupertonicDescription;

  /// No description provided for @ttsModelPiperMexicoDescription.
  ///
  /// In en, this message translates to:
  /// **'Fast, efficient single-speaker synthesis.'**
  String get ttsModelPiperMexicoDescription;

  /// No description provided for @ttsModelPiperSpainDescription.
  ///
  /// In en, this message translates to:
  /// **'Fast, efficient single-speaker synthesis.'**
  String get ttsModelPiperSpainDescription;

  /// No description provided for @ttsModelKittenDescription.
  ///
  /// In en, this message translates to:
  /// **'Compact model with four female and four male voices.'**
  String get ttsModelKittenDescription;

  /// No description provided for @ttsModelKokoroDescription.
  ///
  /// In en, this message translates to:
  /// **'Expressive model with 11 named voices.'**
  String get ttsModelKokoroDescription;

  /// No description provided for @ttsModelMatchaDescription.
  ///
  /// In en, this message translates to:
  /// **'Smooth, natural single-voice synthesis.'**
  String get ttsModelMatchaDescription;

  /// No description provided for @ttsModelPocketDescription.
  ///
  /// In en, this message translates to:
  /// **'Fast zero-shot voice cloning from a reference WAV.'**
  String get ttsModelPocketDescription;

  /// No description provided for @ttsModelZipVoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Advanced voice cloning using a WAV and its exact transcript.'**
  String get ttsModelZipVoiceDescription;

  /// No description provided for @spanishMexico.
  ///
  /// In en, this message translates to:
  /// **'Spanish (Mexico)'**
  String get spanishMexico;

  /// No description provided for @spanishSpain.
  ///
  /// In en, this message translates to:
  /// **'Spanish (Spain)'**
  String get spanishSpain;

  /// No description provided for @ttsStatusIdleDescription.
  ///
  /// In en, this message translates to:
  /// **'Download this exact model when you want to use it.'**
  String get ttsStatusIdleDescription;

  /// No description provided for @ttsStatusCheckingDescription.
  ///
  /// In en, this message translates to:
  /// **'Checking local model files and integrity…'**
  String get ttsStatusCheckingDescription;

  /// No description provided for @ttsStatusDownloadingDescription.
  ///
  /// In en, this message translates to:
  /// **'Downloading verified model files…'**
  String get ttsStatusDownloadingDescription;

  /// No description provided for @ttsStatusLoadingDescription.
  ///
  /// In en, this message translates to:
  /// **'Loading the selected model into memory…'**
  String get ttsStatusLoadingDescription;

  /// No description provided for @ttsStatusReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'Ready for local synthesis.'**
  String get ttsStatusReadyDescription;

  /// No description provided for @ttsStatusErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'The selected model could not be prepared.'**
  String get ttsStatusErrorDescription;

  /// No description provided for @ttsInferenceSteps.
  ///
  /// In en, this message translates to:
  /// **'{count} inference steps'**
  String ttsInferenceSteps(int count);

  /// No description provided for @ttsTestTextHint.
  ///
  /// In en, this message translates to:
  /// **'Type something to test the selected TTS…'**
  String get ttsTestTextHint;

  /// No description provided for @ttsDefaultTestText.
  ///
  /// In en, this message translates to:
  /// **'Hello, this is a test of the selected voice.'**
  String get ttsDefaultTestText;

  /// No description provided for @separatorTextHint.
  ///
  /// In en, this message translates to:
  /// **'says'**
  String get separatorTextHint;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @includedSample.
  ///
  /// In en, this message translates to:
  /// **'Included sample'**
  String get includedSample;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

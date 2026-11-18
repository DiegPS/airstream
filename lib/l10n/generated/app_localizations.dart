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

  /// No description provided for @textAndNames.
  ///
  /// In en, this message translates to:
  /// **'Text and names'**
  String get textAndNames;

  /// No description provided for @chatFontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font family'**
  String get chatFontFamily;

  /// No description provided for @chatFontWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows fonts'**
  String get chatFontWindows;

  /// No description provided for @chatFontGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google Fonts for OBS'**
  String get chatFontGoogle;

  /// No description provided for @chatFontOther.
  ///
  /// In en, this message translates to:
  /// **'Other installed font'**
  String get chatFontOther;

  /// No description provided for @chatFontInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 1–48 letters (A–Z), numbers, spaces or hyphens.'**
  String get chatFontInvalid;

  /// No description provided for @chatFontGoogleNote.
  ///
  /// In en, this message translates to:
  /// **'In the app window this font is used only if it is installed; OBS pages download it'**
  String get chatFontGoogleNote;

  /// No description provided for @nameColorMode.
  ///
  /// In en, this message translates to:
  /// **'Name colors'**
  String get nameColorMode;

  /// No description provided for @nameColorPlatform.
  ///
  /// In en, this message translates to:
  /// **'Viewer’s color'**
  String get nameColorPlatform;

  /// No description provided for @nameColorPlatformThenGenerated.
  ///
  /// In en, this message translates to:
  /// **'Viewer’s color or generated'**
  String get nameColorPlatformThenGenerated;

  /// No description provided for @nameColorGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated for everyone'**
  String get nameColorGenerated;

  /// No description provided for @nameColorSingle.
  ///
  /// In en, this message translates to:
  /// **'Single color'**
  String get nameColorSingle;

  /// No description provided for @nameColorBrand.
  ///
  /// In en, this message translates to:
  /// **'Platform brand color'**
  String get nameColorBrand;

  /// No description provided for @nameRoleColors.
  ///
  /// In en, this message translates to:
  /// **'Owner, moderator and VIP colors'**
  String get nameRoleColors;

  /// No description provided for @nameReadability.
  ///
  /// In en, this message translates to:
  /// **'Improve readability'**
  String get nameReadability;

  /// No description provided for @nameColorHex.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get nameColorHex;

  /// No description provided for @nameColorUse.
  ///
  /// In en, this message translates to:
  /// **'Use color'**
  String get nameColorUse;

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

  /// No description provided for @youtubeDualMode.
  ///
  /// In en, this message translates to:
  /// **'Horizontal + vertical'**
  String get youtubeDualMode;

  /// No description provided for @youtubeDualModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect both YouTube broadcasts at the same time'**
  String get youtubeDualModeDescription;

  /// No description provided for @youtubeHorizontalUrl.
  ///
  /// In en, this message translates to:
  /// **'Horizontal stream URL'**
  String get youtubeHorizontalUrl;

  /// No description provided for @youtubeVerticalUrl.
  ///
  /// In en, this message translates to:
  /// **'Vertical stream URL'**
  String get youtubeVerticalUrl;

  /// No description provided for @youtubeStreamUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://youtube.com/watch?v=...'**
  String get youtubeStreamUrlHint;

  /// No description provided for @youtubeInvalidStreamUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a direct YouTube video or live URL'**
  String get youtubeInvalidStreamUrl;

  /// No description provided for @youtubeDuplicateStreamUrl.
  ///
  /// In en, this message translates to:
  /// **'Use a different broadcast URL'**
  String get youtubeDuplicateStreamUrl;

  /// No description provided for @youtubeStreamBadges.
  ///
  /// In en, this message translates to:
  /// **'Horizontal / vertical badge'**
  String get youtubeStreamBadges;

  /// No description provided for @youtubeLiveAudience.
  ///
  /// In en, this message translates to:
  /// **'YouTube live audience'**
  String get youtubeLiveAudience;

  /// No description provided for @youtubeHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get youtubeHorizontal;

  /// No description provided for @youtubeVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get youtubeVertical;

  /// No description provided for @youtubeViewers.
  ///
  /// In en, this message translates to:
  /// **'{count} viewers'**
  String youtubeViewers(String count);

  /// No description provided for @youtubeTotalViewers.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String youtubeTotalViewers(String count);

  /// No description provided for @youtubeAudienceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audience unavailable'**
  String get youtubeAudienceUnavailable;

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
  /// **'Blocked users and words are removed from your chat, the TTS reader and the OBS overlay.'**
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

  /// No description provided for @commandPrefixHint.
  ///
  /// In en, this message translates to:
  /// **'!v'**
  String get commandPrefixHint;

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
  /// **'The TTS model could not be removed.'**
  String get ttsModelRemovalFailed;

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
  /// **'Use this as a separate Browser Source for Super Chats, memberships and the chat messages you show on stream.'**
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
  /// **'Shows YouTube Super Chats and memberships, Twitch Bits, subscriptions, gifts and raids, and Kick subscriptions, gifts, hosts and Kicks on /alerts. Each type can be switched off below.'**
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

  /// No description provided for @chatConnectionsFailed.
  ///
  /// In en, this message translates to:
  /// **'AirStream could not connect to any configured chat. Review the red platform errors and try again.'**
  String get chatConnectionsFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @retryPlatform.
  ///
  /// In en, this message translates to:
  /// **'Retry {platform}'**
  String retryPlatform(String platform);

  /// No description provided for @chatPartiallyConnected.
  ///
  /// In en, this message translates to:
  /// **'Some chats are connected. Review the platforms marked in red.'**
  String get chatPartiallyConnected;

  /// No description provided for @overlayStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting the local overlay server…'**
  String get overlayStarting;

  /// No description provided for @overlayStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The overlay server could not start on port {port}. The port may already be in use or blocked.'**
  String overlayStartFailed(int port);

  /// No description provided for @invalidOverlayPort.
  ///
  /// In en, this message translates to:
  /// **'Enter a port from 1 to 65535.'**
  String get invalidOverlayPort;

  /// No description provided for @ttsPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'The voice could not be generated or played. Check the selected model and audio output.'**
  String get ttsPlaybackFailed;

  /// No description provided for @voiceCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'The voice command could not be completed. Check the OBS connection and try again.'**
  String get voiceCommandFailed;

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
  /// **'Examples: “Airstream start recording”, “Airstream pause recording”, or “Airstream switch to scene camera”. German and French work too, for example “Airstream starte die Aufnahme”.'**
  String get voiceCommandsExamples;

  /// No description provided for @voiceCommandsTranslationNote.
  ///
  /// In en, this message translates to:
  /// **'With caption translation on, commands are read from the translated text. Recording commands work in English, Spanish, German and French; a scene name may come out translated.'**
  String get voiceCommandsTranslationNote;

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

  /// No description provided for @clickThrough.
  ///
  /// In en, this message translates to:
  /// **'Click-Through'**
  String get clickThrough;

  /// No description provided for @clickThroughDescription.
  ///
  /// In en, this message translates to:
  /// **'Clicks go to the window behind Airstream. Press Ctrl+Shift+C to turn it off.'**
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

  /// No description provided for @globalClickThroughShortcutUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Click-Through needs Ctrl+Shift+C to turn it back off, and another app is using that shortcut. Close that app and try again.'**
  String get globalClickThroughShortcutUnavailable;

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

  /// No description provided for @youtubeInputHint.
  ///
  /// In en, this message translates to:
  /// **'@handle · channel ID · video ID'**
  String get youtubeInputHint;

  /// No description provided for @channelNameHint.
  ///
  /// In en, this message translates to:
  /// **'channel_name'**
  String get channelNameHint;

  /// No description provided for @channelIdentifierHint.
  ///
  /// In en, this message translates to:
  /// **'channel_identifier'**
  String get channelIdentifierHint;

  /// No description provided for @blockedUsersHint.
  ///
  /// In en, this message translates to:
  /// **'@nightbot\n@another_user'**
  String get blockedUsersHint;

  /// No description provided for @blockedWordsHint.
  ///
  /// In en, this message translates to:
  /// **'word\ncomplete phrase'**
  String get blockedWordsHint;

  /// No description provided for @chatError.
  ///
  /// In en, this message translates to:
  /// **'Chat messages could not be loaded.'**
  String get chatError;

  /// No description provided for @platformConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'{platform} could not connect. Check the channel and your Internet connection.'**
  String platformConnectionFailed(String platform);

  /// No description provided for @obsConnectionProblem.
  ///
  /// In en, this message translates to:
  /// **'OBS could not complete the requested action. Check the connection settings.'**
  String get obsConnectionProblem;

  /// No description provided for @defaultVoice.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultVoice;

  /// No description provided for @newsVoice.
  ///
  /// In en, this message translates to:
  /// **'News voice'**
  String get newsVoice;

  /// No description provided for @newsVoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'News voice {number}'**
  String newsVoiceNumber(int number);

  /// No description provided for @alignmentLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get alignmentLeft;

  /// No description provided for @alignmentCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get alignmentCenter;

  /// No description provided for @alignmentRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get alignmentRight;

  /// No description provided for @animationSlideUp.
  ///
  /// In en, this message translates to:
  /// **'Slide up'**
  String get animationSlideUp;

  /// No description provided for @animationSlideLeft.
  ///
  /// In en, this message translates to:
  /// **'Slide from right'**
  String get animationSlideLeft;

  /// No description provided for @animationFadeIn.
  ///
  /// In en, this message translates to:
  /// **'Fade in'**
  String get animationFadeIn;

  /// No description provided for @animationZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get animationZoomIn;

  /// No description provided for @droppedFramesBadge.
  ///
  /// In en, this message translates to:
  /// **'DROP {percentage}% ({count})'**
  String droppedFramesBadge(String percentage, int count);

  /// No description provided for @badgeOwner.
  ///
  /// In en, this message translates to:
  /// **'OWNER'**
  String get badgeOwner;

  /// No description provided for @badgeModerator.
  ///
  /// In en, this message translates to:
  /// **'MOD'**
  String get badgeModerator;

  /// No description provided for @badgeMember.
  ///
  /// In en, this message translates to:
  /// **'MEMBER'**
  String get badgeMember;

  /// No description provided for @badgeSubscriber.
  ///
  /// In en, this message translates to:
  /// **'SUB'**
  String get badgeSubscriber;

  /// No description provided for @badgeVerified.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get badgeVerified;

  /// No description provided for @badgeFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'FIRST MESSAGE'**
  String get badgeFirstMessage;

  /// No description provided for @badgeReturningChatter.
  ///
  /// In en, this message translates to:
  /// **'RETURNING'**
  String get badgeReturningChatter;

  /// No description provided for @badgeReward.
  ///
  /// In en, this message translates to:
  /// **'REWARD'**
  String get badgeReward;

  /// No description provided for @newSubscriberEvent.
  ///
  /// In en, this message translates to:
  /// **'New subscriber!'**
  String get newSubscriberEvent;

  /// No description provided for @resubscriptionEvent.
  ///
  /// In en, this message translates to:
  /// **'Resubscribed for {months} months'**
  String resubscriptionEvent(int months);

  /// No description provided for @giftSubscriptionEvent.
  ///
  /// In en, this message translates to:
  /// **'Gift subscription'**
  String get giftSubscriptionEvent;

  /// No description provided for @subscriptionUpdateEvent.
  ///
  /// In en, this message translates to:
  /// **'Subscription update'**
  String get subscriptionUpdateEvent;

  /// No description provided for @membershipUpdateEvent.
  ///
  /// In en, this message translates to:
  /// **'Membership update'**
  String get membershipUpdateEvent;

  /// No description provided for @chatSharedSource.
  ///
  /// In en, this message translates to:
  /// **'SHARED'**
  String get chatSharedSource;

  /// No description provided for @chatEventRaid.
  ///
  /// In en, this message translates to:
  /// **'Raid'**
  String get chatEventRaid;

  /// No description provided for @chatEventUnraid.
  ///
  /// In en, this message translates to:
  /// **'Raid ended'**
  String get chatEventUnraid;

  /// No description provided for @chatEventPinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get chatEventPinnedMessage;

  /// No description provided for @chatEventUnpinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'Message unpinned'**
  String get chatEventUnpinnedMessage;

  /// No description provided for @chatEventPoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get chatEventPoll;

  /// No description provided for @chatEventReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get chatEventReward;

  /// No description provided for @chatEventSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get chatEventSupport;

  /// No description provided for @chatEventHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get chatEventHost;

  /// No description provided for @chatEventGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get chatEventGoal;

  /// No description provided for @chatEventNotice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get chatEventNotice;

  /// No description provided for @chatEventModiversary.
  ///
  /// In en, this message translates to:
  /// **'Moderator anniversary'**
  String get chatEventModiversary;

  /// No description provided for @chatEventViewerMilestone.
  ///
  /// In en, this message translates to:
  /// **'Viewer milestone'**
  String get chatEventViewerMilestone;

  /// No description provided for @chatEventWatchStreak.
  ///
  /// In en, this message translates to:
  /// **'Watch streak'**
  String get chatEventWatchStreak;

  /// No description provided for @chatEventSharedChat.
  ///
  /// In en, this message translates to:
  /// **'Shared chat'**
  String get chatEventSharedChat;

  /// No description provided for @chatEventRoomState.
  ///
  /// In en, this message translates to:
  /// **'Chat settings updated'**
  String get chatEventRoomState;

  /// No description provided for @chatEventStreamOnline.
  ///
  /// In en, this message translates to:
  /// **'Stream online'**
  String get chatEventStreamOnline;

  /// No description provided for @chatEventStreamOffline.
  ///
  /// In en, this message translates to:
  /// **'Stream offline'**
  String get chatEventStreamOffline;

  /// No description provided for @eventBanners.
  ///
  /// In en, this message translates to:
  /// **'Event banners'**
  String get eventBanners;

  /// No description provided for @eventBannersDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which platform notices (raids, polls, pinned messages…) appear above chat.'**
  String get eventBannersDescription;

  /// No description provided for @eventBannerDuration.
  ///
  /// In en, this message translates to:
  /// **'Visible duration'**
  String get eventBannerDuration;

  /// No description provided for @chatEventUnknown.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get chatEventUnknown;

  /// No description provided for @chatRoomEmoteOnly.
  ///
  /// In en, this message translates to:
  /// **'Emote-only'**
  String get chatRoomEmoteOnly;

  /// No description provided for @chatRoomFollowersOnly.
  ///
  /// In en, this message translates to:
  /// **'Followers {minutes} min'**
  String chatRoomFollowersOnly(int minutes);

  /// No description provided for @chatRoomUnique.
  ///
  /// In en, this message translates to:
  /// **'Unique chat'**
  String get chatRoomUnique;

  /// No description provided for @chatRoomSlowMode.
  ///
  /// In en, this message translates to:
  /// **'Slow mode {seconds} s'**
  String chatRoomSlowMode(int seconds);

  /// No description provided for @chatRoomSubscribersOnly.
  ///
  /// In en, this message translates to:
  /// **'Subscribers-only'**
  String get chatRoomSubscribersOnly;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageBulgarian.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian'**
  String get languageBulgarian;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageCroatian.
  ///
  /// In en, this message translates to:
  /// **'Croatian'**
  String get languageCroatian;

  /// No description provided for @languageCzech.
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get languageCzech;

  /// No description provided for @languageDanish.
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get languageDanish;

  /// No description provided for @languageDutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get languageDutch;

  /// No description provided for @languageEstonian.
  ///
  /// In en, this message translates to:
  /// **'Estonian'**
  String get languageEstonian;

  /// No description provided for @languageFinnish.
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get languageFinnish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageGreek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get languageGreek;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageHungarian.
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get languageHungarian;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesian;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageItalian;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languageLatvian.
  ///
  /// In en, this message translates to:
  /// **'Latvian'**
  String get languageLatvian;

  /// No description provided for @languageLithuanian.
  ///
  /// In en, this message translates to:
  /// **'Lithuanian'**
  String get languageLithuanian;

  /// No description provided for @languagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get languagePolish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageRomanian.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get languageRomanian;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageSlovak.
  ///
  /// In en, this message translates to:
  /// **'Slovak'**
  String get languageSlovak;

  /// No description provided for @languageSlovenian.
  ///
  /// In en, this message translates to:
  /// **'Slovenian'**
  String get languageSlovenian;

  /// No description provided for @languageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get languageSwedish;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// No description provided for @languageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get languageUkrainian;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnamese;

  /// No description provided for @noChannelsConfiguredMenuHidden.
  ///
  /// In en, this message translates to:
  /// **'No channels configured yet.'**
  String get noChannelsConfiguredMenuHidden;

  /// No description provided for @configureChannels.
  ///
  /// In en, this message translates to:
  /// **'Configure channels'**
  String get configureChannels;

  /// No description provided for @platformStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'{platform}: connected'**
  String platformStatusConnected(String platform);

  /// No description provided for @platformStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'{platform}: connecting…'**
  String platformStatusConnecting(String platform);

  /// No description provided for @platformStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'{platform}: not connected'**
  String platformStatusIdle(String platform);

  /// No description provided for @clickThroughEnabledNotice.
  ///
  /// In en, this message translates to:
  /// **'Click-Through is on: clicks go to the window behind. Press Ctrl+Shift+C to turn it off.'**
  String get clickThroughEnabledNotice;

  /// No description provided for @newChatMessages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new message} other{{count} new messages}}'**
  String newChatMessages(int count);

  /// No description provided for @silenceTts.
  ///
  /// In en, this message translates to:
  /// **'Silence TTS (skip this message and the queue)'**
  String get silenceTts;

  /// No description provided for @youtubeWaitingForLive.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the YouTube live stream to start…'**
  String get youtubeWaitingForLive;

  /// No description provided for @youtubeWaitingForLiveDetail.
  ///
  /// In en, this message translates to:
  /// **'The channel is not live yet. Airstream checks again every 30 seconds.'**
  String get youtubeWaitingForLiveDetail;

  /// No description provided for @connectChatOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Start the chat when Airstream opens'**
  String get connectChatOnLaunch;

  /// No description provided for @obsConnectOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Connect to OBS when Airstream opens'**
  String get obsConnectOnLaunch;

  /// No description provided for @chatPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get chatPreview;

  /// No description provided for @chatPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Show sample messages in the chat and the OBS overlay to try styles. They disappear when the chat starts.'**
  String get chatPreviewDescription;

  /// No description provided for @overlayPortFallback.
  ///
  /// In en, this message translates to:
  /// **'Port {requested} is in use by another app, so the overlay uses {port}. The OBS URLs below already include it.'**
  String overlayPortFallback(int requested, int port);

  /// No description provided for @chatPreviewSwitch.
  ///
  /// In en, this message translates to:
  /// **'Show sample messages'**
  String get chatPreviewSwitch;

  /// No description provided for @highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// No description provided for @highlightsDescription.
  ///
  /// In en, this message translates to:
  /// **'Make mentions of your channel and words you choose stand out in Airstream\'s chat.'**
  String get highlightsDescription;

  /// No description provided for @highlightMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions of my channel'**
  String get highlightMentions;

  /// No description provided for @highlightMentionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Messages that name your Twitch or Kick channel or your YouTube @name.'**
  String get highlightMentionsDescription;

  /// No description provided for @highlightWords.
  ///
  /// In en, this message translates to:
  /// **'Words to highlight'**
  String get highlightWords;

  /// No description provided for @highlightWordsHint.
  ///
  /// In en, this message translates to:
  /// **'One word or phrase per line'**
  String get highlightWordsHint;

  /// No description provided for @highlightWordsHelp.
  ///
  /// In en, this message translates to:
  /// **'Whole words; uppercase and lowercase are the same.'**
  String get highlightWordsHelp;

  /// No description provided for @highlightSound.
  ///
  /// In en, this message translates to:
  /// **'Highlight sounds'**
  String get highlightSound;

  /// No description provided for @highlightSoundDescription.
  ///
  /// In en, this message translates to:
  /// **'Sounds play at most once every 3 seconds. They stay silent while the voice reader speaks.'**
  String get highlightSoundDescription;

  /// No description provided for @badgeFirstInSession.
  ///
  /// In en, this message translates to:
  /// **'First message this stream'**
  String get badgeFirstInSession;

  /// No description provided for @highlightFirstMessages.
  ///
  /// In en, this message translates to:
  /// **'First message of each viewer'**
  String get highlightFirstMessages;

  /// No description provided for @highlightFirstMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Mark the first message each viewer sends after you start the chat, to welcome them.'**
  String get highlightFirstMessagesDescription;

  /// No description provided for @ttsUserCooldown.
  ///
  /// In en, this message translates to:
  /// **'Pause per viewer'**
  String get ttsUserCooldown;

  /// No description provided for @ttsUserCooldownHelp.
  ///
  /// In en, this message translates to:
  /// **'After reading a message, the next ones from the same viewer wait this long. 0 s turns it off.'**
  String get ttsUserCooldownHelp;

  /// No description provided for @ttsMaxCharacters.
  ///
  /// In en, this message translates to:
  /// **'Longest message read'**
  String get ttsMaxCharacters;

  /// No description provided for @ttsIgnoredUsers.
  ///
  /// In en, this message translates to:
  /// **'Users the voice reader skips'**
  String get ttsIgnoredUsers;

  /// No description provided for @ttsIgnoredUsersHint.
  ///
  /// In en, this message translates to:
  /// **'One per line, for example nightbot'**
  String get ttsIgnoredUsersHint;

  /// No description provided for @chatFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter Airstream\'s chat (OBS still shows every message)'**
  String get chatFilterTooltip;

  /// No description provided for @chatFilterPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Platforms'**
  String get chatFilterPlatforms;

  /// No description provided for @chatFilterShowOnly.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get chatFilterShowOnly;

  /// No description provided for @chatFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get chatFilterAll;

  /// No description provided for @chatFilterMembers.
  ///
  /// In en, this message translates to:
  /// **'Only members and subscribers'**
  String get chatFilterMembers;

  /// No description provided for @chatFilterModerators.
  ///
  /// In en, this message translates to:
  /// **'Only moderators'**
  String get chatFilterModerators;

  /// No description provided for @chatFilterHighlighted.
  ///
  /// In en, this message translates to:
  /// **'Only highlighted'**
  String get chatFilterHighlighted;

  /// No description provided for @chatFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Showing: {filters}'**
  String chatFilterActive(String filters);

  /// No description provided for @chatFilterShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get chatFilterShowAll;

  /// No description provided for @chatFilterNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No messages match the filter yet.'**
  String get chatFilterNoMatches;

  /// No description provided for @messageShowOnStream.
  ///
  /// In en, this message translates to:
  /// **'Show on stream'**
  String get messageShowOnStream;

  /// No description provided for @messageShowOnStreamNeedsOverlay.
  ///
  /// In en, this message translates to:
  /// **'Turn on the overlay server and add the alerts URL to OBS'**
  String get messageShowOnStreamNeedsOverlay;

  /// No description provided for @messageSentToOverlay.
  ///
  /// In en, this message translates to:
  /// **'Sent to the alerts page in OBS'**
  String get messageSentToOverlay;

  /// No description provided for @messageOverlayDisconnected.
  ///
  /// In en, this message translates to:
  /// **'OBS closed the alerts page before showing the message'**
  String get messageOverlayDisconnected;

  /// No description provided for @messageNoAlertsOverlay.
  ///
  /// In en, this message translates to:
  /// **'Open the featured or alerts page as a browser source in OBS.'**
  String get messageNoAlertsOverlay;

  /// No description provided for @messageOverlayUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Sent, but OBS did not confirm it was shown'**
  String get messageOverlayUnconfirmed;

  /// No description provided for @messageShownOnStream.
  ///
  /// In en, this message translates to:
  /// **'Shown on stream'**
  String get messageShownOnStream;

  /// No description provided for @messageCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy message'**
  String get messageCopy;

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied'**
  String get messageCopied;

  /// No description provided for @pollTitle.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get pollTitle;

  /// No description provided for @pollDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask viewers across all your chats and choose how they vote.'**
  String get pollDescription;

  /// No description provided for @pollMode.
  ///
  /// In en, this message translates to:
  /// **'Voting mode'**
  String get pollMode;

  /// No description provided for @pollModeNumbered.
  ///
  /// In en, this message translates to:
  /// **'Numbered'**
  String get pollModeNumbered;

  /// No description provided for @pollModeWord.
  ///
  /// In en, this message translates to:
  /// **'By word'**
  String get pollModeWord;

  /// No description provided for @pollModeYesNo.
  ///
  /// In en, this message translates to:
  /// **'Yes / No'**
  String get pollModeYesNo;

  /// No description provided for @pollModeRating.
  ///
  /// In en, this message translates to:
  /// **'Rating 1–10'**
  String get pollModeRating;

  /// No description provided for @pollModeFreeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Free answer'**
  String get pollModeFreeAnswer;

  /// No description provided for @pollYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get pollYes;

  /// No description provided for @pollNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get pollNo;

  /// No description provided for @pollOptions.
  ///
  /// In en, this message translates to:
  /// **'Voting options'**
  String get pollOptions;

  /// No description provided for @pollAllowed.
  ///
  /// In en, this message translates to:
  /// **'Who can vote'**
  String get pollAllowed;

  /// No description provided for @pollAllowChange.
  ///
  /// In en, this message translates to:
  /// **'Allow vote changes'**
  String get pollAllowChange;

  /// No description provided for @pollHideResults.
  ///
  /// In en, this message translates to:
  /// **'Hide results until the end'**
  String get pollHideResults;

  /// No description provided for @pollResultsHidden.
  ///
  /// In en, this message translates to:
  /// **'Results at the end'**
  String get pollResultsHidden;

  /// No description provided for @pollResultsHiddenOnPages.
  ///
  /// In en, this message translates to:
  /// **'Results are hidden from pages until the poll ends.'**
  String get pollResultsHiddenOnPages;

  /// No description provided for @pollCommand.
  ///
  /// In en, this message translates to:
  /// **'Answer command'**
  String get pollCommand;

  /// No description provided for @pollInvalidCommand.
  ///
  /// In en, this message translates to:
  /// **'Enter a command like !r that isn’t reserved by the queue.'**
  String get pollInvalidCommand;

  /// No description provided for @pollAmbiguousOptions.
  ///
  /// In en, this message translates to:
  /// **'Enter options that differ even without accents, case or extra spaces.'**
  String get pollAmbiguousOptions;

  /// No description provided for @pollOptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Each option can have up to 40 characters.'**
  String get pollOptionTooLong;

  /// No description provided for @pollInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Enter a question and fill in at least two options if required.'**
  String get pollInvalidInput;

  /// No description provided for @pollAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get pollAverage;

  /// No description provided for @pollDistinctAnswers.
  ///
  /// In en, this message translates to:
  /// **'Distinct answers'**
  String get pollDistinctAnswers;

  /// No description provided for @pollHowToVote.
  ///
  /// In en, this message translates to:
  /// **'Type in chat'**
  String get pollHowToVote;

  /// No description provided for @pollAnswerExample.
  ///
  /// In en, this message translates to:
  /// **'your answer'**
  String get pollAnswerExample;

  /// No description provided for @pollNoAnswers.
  ///
  /// In en, this message translates to:
  /// **'No answers yet'**
  String get pollNoAnswers;

  /// No description provided for @galleryPollDescription.
  ///
  /// In en, this message translates to:
  /// **'Show voting instructions, live tallies, and final results.'**
  String get galleryPollDescription;

  /// No description provided for @pollQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get pollQuestionHint;

  /// No description provided for @pollOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String pollOptionHint(int number);

  /// No description provided for @pollAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get pollAddOption;

  /// No description provided for @pollRemoveOption.
  ///
  /// In en, this message translates to:
  /// **'Remove option'**
  String get pollRemoveOption;

  /// No description provided for @pollNoTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'No time limit'**
  String get pollNoTimeLimit;

  /// No description provided for @pollMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String pollMinutes(int minutes);

  /// No description provided for @pollStart.
  ///
  /// In en, this message translates to:
  /// **'Start poll'**
  String get pollStart;

  /// No description provided for @pollEnd.
  ///
  /// In en, this message translates to:
  /// **'End poll'**
  String get pollEnd;

  /// No description provided for @pollNew.
  ///
  /// In en, this message translates to:
  /// **'New poll'**
  String get pollNew;

  /// No description provided for @pollOpen.
  ///
  /// In en, this message translates to:
  /// **'Voting open'**
  String get pollOpen;

  /// No description provided for @pollClosed.
  ///
  /// In en, this message translates to:
  /// **'Final results'**
  String get pollClosed;

  /// No description provided for @pollSecondsLeft.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s left'**
  String pollSecondsLeft(int seconds);

  /// No description provided for @pollVotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 vote} other{{count} votes}}'**
  String pollVotes(int count);

  /// No description provided for @pollOverlayOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on the overlay server to show this in OBS.'**
  String get pollOverlayOff;

  /// No description provided for @pollOverlayUrl.
  ///
  /// In en, this message translates to:
  /// **'Add {url} to OBS as a Browser Source to show it.'**
  String pollOverlayUrl(String url);

  /// No description provided for @pollOverlayUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Poll URL copied'**
  String get pollOverlayUrlCopied;

  /// No description provided for @copyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrl;

  /// No description provided for @pollDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get pollDuration;

  /// No description provided for @sessionSummary.
  ///
  /// In en, this message translates to:
  /// **'Session summary'**
  String get sessionSummary;

  /// No description provided for @sessionSummaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start the chat: the summary collects messages, viewers and support until you stop it.'**
  String get sessionSummaryEmpty;

  /// No description provided for @sessionSummaryLine.
  ///
  /// In en, this message translates to:
  /// **'{duration} · {messages} messages · {chatters} viewers wrote'**
  String sessionSummaryLine(String duration, int messages, int chatters);

  /// No description provided for @sessionDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sessionDuration;

  /// No description provided for @sessionDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String sessionDurationHours(int hours, int minutes);

  /// No description provided for @sessionDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sessionDurationMinutes(int minutes);

  /// No description provided for @sessionMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get sessionMessagesLabel;

  /// No description provided for @sessionMessages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String sessionMessages(int count);

  /// No description provided for @sessionChatters.
  ///
  /// In en, this message translates to:
  /// **'Viewers who wrote'**
  String get sessionChatters;

  /// No description provided for @sessionTopChatters.
  ///
  /// In en, this message translates to:
  /// **'Most active'**
  String get sessionTopChatters;

  /// No description provided for @sessionSupporters.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get sessionSupporters;

  /// No description provided for @sessionNoSupporters.
  ///
  /// In en, this message translates to:
  /// **'No Super Chats, members or raids this time.'**
  String get sessionNoSupporters;

  /// No description provided for @sessionSupportSuperChat.
  ///
  /// In en, this message translates to:
  /// **'{name} sent a Super Chat of {amount}'**
  String sessionSupportSuperChat(String name, String amount);

  /// No description provided for @sessionSupportMember.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{{name} became a member} other{{name}: {months} months as a member}}'**
  String sessionSupportMember(String name, int months);

  /// No description provided for @sessionSupportSubscription.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{{name} subscribed} other{{name}: {months} months subscribed}}'**
  String sessionSupportSubscription(String name, int months);

  /// No description provided for @sessionSupportGift.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{name} gifted a subscription} other{{name} gifted {count} subscriptions}}'**
  String sessionSupportGift(String name, int count);

  /// No description provided for @sessionSupportRaid.
  ///
  /// In en, this message translates to:
  /// **'{name} raided with {count} viewers'**
  String sessionSupportRaid(String name, int count);

  /// No description provided for @sessionSupportOther.
  ///
  /// In en, this message translates to:
  /// **'{name} sent a gift'**
  String sessionSupportOther(String name);

  /// No description provided for @sessionSummaryCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy summary'**
  String get sessionSummaryCopy;

  /// No description provided for @sessionSummaryCopied.
  ///
  /// In en, this message translates to:
  /// **'Summary copied'**
  String get sessionSummaryCopied;

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesTitle;

  /// No description provided for @profilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Save your setup for each kind of stream and switch in one click. Profiles keep style, voice reader, overlay and highlights; your channels and OBS stay as they are.'**
  String get profilesDescription;

  /// No description provided for @profilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet.'**
  String get profilesEmpty;

  /// No description provided for @profileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Profile name, for example Gaming'**
  String get profileNameHint;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get profileApply;

  /// No description provided for @profileDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get profileDelete;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile \"{name}\" saved'**
  String profileSaved(String name);

  /// No description provided for @profileApplied.
  ///
  /// In en, this message translates to:
  /// **'Profile \"{name}\" applied'**
  String profileApplied(String name);

  /// No description provided for @settingsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackupTitle;

  /// No description provided for @settingsBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Save all settings to a file, bring them back on another computer, or return to the defaults. The OBS password is never saved to the file.'**
  String get settingsBackupDescription;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExport;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImport;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// No description provided for @settingsExported.
  ///
  /// In en, this message translates to:
  /// **'Settings exported'**
  String get settingsExported;

  /// No description provided for @settingsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'The settings could not be saved to that file.'**
  String get settingsExportFailed;

  /// No description provided for @settingsImported.
  ///
  /// In en, this message translates to:
  /// **'Settings imported'**
  String get settingsImported;

  /// No description provided for @settingsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'That file is not an Airstream settings file.'**
  String get settingsImportFailed;

  /// No description provided for @settingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset settings?'**
  String get settingsResetTitle;

  /// No description provided for @settingsResetConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Style, voice reader, overlay, highlights and the rest go back to their defaults. Your channels, OBS connection, language and profiles stay.'**
  String get settingsResetConfirmation;

  /// No description provided for @settingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Settings reset'**
  String get settingsResetDone;

  /// No description provided for @chatSearch.
  ///
  /// In en, this message translates to:
  /// **'Search the chat'**
  String get chatSearch;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages or names'**
  String get chatSearchHint;

  /// No description provided for @chatSearchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get chatSearchClose;

  /// No description provided for @chatLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat log'**
  String get chatLogTitle;

  /// No description provided for @chatLogSave.
  ///
  /// In en, this message translates to:
  /// **'Save the chat of each session'**
  String get chatLogSave;

  /// No description provided for @chatLogDescription.
  ///
  /// In en, this message translates to:
  /// **'Writes every message to a text file in Documents\\Airstream\\Chat while the chat runs.'**
  String get chatLogDescription;

  /// No description provided for @chatLogOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get chatLogOpenFolder;

  /// No description provided for @globalShortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Global shortcuts'**
  String get globalShortcutsTitle;

  /// No description provided for @globalShortcutsDescription.
  ///
  /// In en, this message translates to:
  /// **'They work from any app, for example during a game. Each one is off until you assign it, so other apps keep their shortcuts.'**
  String get globalShortcutsDescription;

  /// No description provided for @globalShortcutSilenceTts.
  ///
  /// In en, this message translates to:
  /// **'Silence the voice reader'**
  String get globalShortcutSilenceTts;

  /// No description provided for @globalShortcutToggleTts.
  ///
  /// In en, this message translates to:
  /// **'Turn the voice reader on or off'**
  String get globalShortcutToggleTts;

  /// No description provided for @globalShortcutNone.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get globalShortcutNone;

  /// No description provided for @globalShortcutPress.
  ///
  /// In en, this message translates to:
  /// **'Press the keys…'**
  String get globalShortcutPress;

  /// No description provided for @globalShortcutClear.
  ///
  /// In en, this message translates to:
  /// **'Remove shortcut'**
  String get globalShortcutClear;

  /// No description provided for @globalShortcutNeedsModifier.
  ///
  /// In en, this message translates to:
  /// **'Use Ctrl, Alt or Win with the key.'**
  String get globalShortcutNeedsModifier;

  /// No description provided for @globalShortcutReserved.
  ///
  /// In en, this message translates to:
  /// **'Ctrl + Shift + C is reserved for click-through.'**
  String get globalShortcutReserved;

  /// No description provided for @globalShortcutDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Another action already uses this shortcut.'**
  String get globalShortcutDuplicate;

  /// No description provided for @globalShortcutInUse.
  ///
  /// In en, this message translates to:
  /// **'Another app already uses this shortcut; choose a different one.'**
  String get globalShortcutInUse;

  /// No description provided for @alertTypes.
  ///
  /// In en, this message translates to:
  /// **'Alert types'**
  String get alertTypes;

  /// No description provided for @alertTypeSuperChat.
  ///
  /// In en, this message translates to:
  /// **'YouTube Super Chats'**
  String get alertTypeSuperChat;

  /// No description provided for @alertTypeMembership.
  ///
  /// In en, this message translates to:
  /// **'YouTube new members'**
  String get alertTypeMembership;

  /// No description provided for @alertTypeBits.
  ///
  /// In en, this message translates to:
  /// **'Twitch Bits'**
  String get alertTypeBits;

  /// No description provided for @alertTypeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions (Twitch and Kick)'**
  String get alertTypeSubscription;

  /// No description provided for @alertTypeGift.
  ///
  /// In en, this message translates to:
  /// **'Gifted subscriptions and memberships'**
  String get alertTypeGift;

  /// No description provided for @alertTypeRaid.
  ///
  /// In en, this message translates to:
  /// **'Raids and hosts'**
  String get alertTypeRaid;

  /// No description provided for @alertTypeKicks.
  ///
  /// In en, this message translates to:
  /// **'Kick Kicks'**
  String get alertTypeKicks;

  /// No description provided for @testAlertBits.
  ///
  /// In en, this message translates to:
  /// **'Bits'**
  String get testAlertBits;

  /// No description provided for @testAlertSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get testAlertSubscription;

  /// No description provided for @testAlertGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get testAlertGift;

  /// No description provided for @testAlertRaid.
  ///
  /// In en, this message translates to:
  /// **'Raid'**
  String get testAlertRaid;

  /// No description provided for @testAlertKicks.
  ///
  /// In en, this message translates to:
  /// **'Kicks'**
  String get testAlertKicks;

  /// No description provided for @overlayStylePresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready-made styles'**
  String get overlayStylePresetsTitle;

  /// No description provided for @overlayStylePresetsDescription.
  ///
  /// In en, this message translates to:
  /// **'One tap sets how the chat and alerts look in OBS. Your connections and other settings stay as they are.'**
  String get overlayStylePresetsDescription;

  /// No description provided for @overlayStyleCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom style'**
  String get overlayStyleCustom;

  /// No description provided for @overlayStyleApplied.
  ///
  /// In en, this message translates to:
  /// **'Style “{name}” applied'**
  String overlayStyleApplied(String name);

  /// No description provided for @overlayStyleUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get overlayStyleUndo;

  /// No description provided for @overlayStylePreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on the preview to see it with sample messages.'**
  String get overlayStylePreviewHint;

  /// No description provided for @overlayStyleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get overlayStyleClassic;

  /// No description provided for @overlayStyleClassicDescription.
  ///
  /// In en, this message translates to:
  /// **'Airstream\'s default look.'**
  String get overlayStyleClassicDescription;

  /// No description provided for @overlayStyleCompactGaming.
  ///
  /// In en, this message translates to:
  /// **'Compact for gaming'**
  String get overlayStyleCompactGaming;

  /// No description provided for @overlayStyleCompactGamingDescription.
  ///
  /// In en, this message translates to:
  /// **'Small, tight messages that cover little of the game.'**
  String get overlayStyleCompactGamingDescription;

  /// No description provided for @overlayStyleBigBubbles.
  ///
  /// In en, this message translates to:
  /// **'Big bubbles'**
  String get overlayStyleBigBubbles;

  /// No description provided for @overlayStyleBigBubblesDescription.
  ///
  /// In en, this message translates to:
  /// **'Large text in rounded bubbles, easy to read.'**
  String get overlayStyleBigBubblesDescription;

  /// No description provided for @overlayStyleCleanTransparent.
  ///
  /// In en, this message translates to:
  /// **'Clean transparent'**
  String get overlayStyleCleanTransparent;

  /// No description provided for @overlayStyleCleanTransparentDescription.
  ///
  /// In en, this message translates to:
  /// **'No bubbles: outlined text over your scene.'**
  String get overlayStyleCleanTransparentDescription;

  /// No description provided for @overlayStyleVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get overlayStyleVertical;

  /// No description provided for @overlayStyleVerticalDescription.
  ///
  /// In en, this message translates to:
  /// **'Made for vertical streams such as Shorts or TikTok.'**
  String get overlayStyleVerticalDescription;

  /// No description provided for @alertPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get alertPosition;

  /// No description provided for @alertPositionTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get alertPositionTop;

  /// No description provided for @alertPositionCenter.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get alertPositionCenter;

  /// No description provided for @alertPositionBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get alertPositionBottom;

  /// No description provided for @alertLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get alertLayout;

  /// No description provided for @alertLayoutRow.
  ///
  /// In en, this message translates to:
  /// **'Side by side'**
  String get alertLayoutRow;

  /// No description provided for @alertLayoutStacked.
  ///
  /// In en, this message translates to:
  /// **'Stacked'**
  String get alertLayoutStacked;

  /// No description provided for @alertEntrance.
  ///
  /// In en, this message translates to:
  /// **'Entrance'**
  String get alertEntrance;

  /// No description provided for @alertAnimationPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get alertAnimationPop;

  /// No description provided for @alertAnimationSlideUp.
  ///
  /// In en, this message translates to:
  /// **'Slide up'**
  String get alertAnimationSlideUp;

  /// No description provided for @alertAnimationSlideDown.
  ///
  /// In en, this message translates to:
  /// **'Slide down'**
  String get alertAnimationSlideDown;

  /// No description provided for @alertAnimationFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get alertAnimationFade;

  /// No description provided for @alertAnimationZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get alertAnimationZoom;

  /// No description provided for @alertTypeOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for this type'**
  String get alertTypeOptions;

  /// No description provided for @alertTypeOwnDuration.
  ///
  /// In en, this message translates to:
  /// **'Own duration'**
  String get alertTypeOwnDuration;

  /// No description provided for @alertTypeUseGeneral.
  ///
  /// In en, this message translates to:
  /// **'Use general'**
  String get alertTypeUseGeneral;

  /// No description provided for @alertTypeCustomized.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get alertTypeCustomized;

  /// No description provided for @alertSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get alertSound;

  /// No description provided for @alertSoundNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get alertSoundNone;

  /// No description provided for @alertSoundChime.
  ///
  /// In en, this message translates to:
  /// **'Chime'**
  String get alertSoundChime;

  /// No description provided for @alertSoundCoin.
  ///
  /// In en, this message translates to:
  /// **'Coin'**
  String get alertSoundCoin;

  /// No description provided for @alertSoundFanfare.
  ///
  /// In en, this message translates to:
  /// **'Fanfare'**
  String get alertSoundFanfare;

  /// No description provided for @alertSoundCustom.
  ///
  /// In en, this message translates to:
  /// **'Own file'**
  String get alertSoundCustom;

  /// No description provided for @alertSoundChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get alertSoundChoose;

  /// No description provided for @alertSoundNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file chosen'**
  String get alertSoundNoFile;

  /// No description provided for @alertSoundInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a WAV, MP3 or OGG file of up to 5 MB.'**
  String get alertSoundInvalid;

  /// No description provided for @alertSoundVolume.
  ///
  /// In en, this message translates to:
  /// **'Alert sound volume'**
  String get alertSoundVolume;

  /// No description provided for @alertSoundObsHint.
  ///
  /// In en, this message translates to:
  /// **'Sounds play from the alerts page. In OBS, turn on “Control audio via OBS” for that browser source so your viewers hear them.'**
  String get alertSoundObsHint;

  /// No description provided for @alertTypeTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get alertTypeTest;

  /// No description provided for @recentAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent alerts'**
  String get recentAlertsTitle;

  /// No description provided for @recentAlertsDescription.
  ///
  /// In en, this message translates to:
  /// **'Support events from this session that appeared on stream. Show any of them again.'**
  String get recentAlertsDescription;

  /// No description provided for @recentAlertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Alerts from this session will appear here.'**
  String get recentAlertsEmpty;

  /// No description provided for @recentAlertsReplay.
  ///
  /// In en, this message translates to:
  /// **'Show on stream again'**
  String get recentAlertsReplay;

  /// No description provided for @recentAlertsReplayed.
  ///
  /// In en, this message translates to:
  /// **'Shown on stream again'**
  String get recentAlertsReplayed;

  /// No description provided for @recentAlertsMember.
  ///
  /// In en, this message translates to:
  /// **'New member'**
  String get recentAlertsMember;

  /// No description provided for @recentAlertsSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get recentAlertsSubscription;

  /// No description provided for @recentAlertsMonths.
  ///
  /// In en, this message translates to:
  /// **'{count} months'**
  String recentAlertsMonths(int count);

  /// No description provided for @recentAlertsGifted.
  ///
  /// In en, this message translates to:
  /// **'{count} gifted'**
  String recentAlertsGifted(int count);

  /// No description provided for @recentAlertsRaid.
  ///
  /// In en, this message translates to:
  /// **'Raid'**
  String get recentAlertsRaid;

  /// No description provided for @recentAlertsHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get recentAlertsHost;

  /// No description provided for @recentAlertsRaidViewers.
  ///
  /// In en, this message translates to:
  /// **'Raid · {count} viewers'**
  String recentAlertsRaidViewers(int count);

  /// No description provided for @recentAlertsHostViewers.
  ///
  /// In en, this message translates to:
  /// **'Host · {count} viewers'**
  String recentAlertsHostViewers(int count);

  /// No description provided for @recentAlertsKicks.
  ///
  /// In en, this message translates to:
  /// **'{count} Kicks'**
  String recentAlertsKicks(int count);

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get diagnosticsCopy;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Report copied'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsLogs.
  ///
  /// In en, this message translates to:
  /// **'Open logs folder'**
  String get diagnosticsLogs;

  /// No description provided for @diagnosticsLogsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open logs folder'**
  String get diagnosticsLogsFailed;

  /// No description provided for @diagnosticsHeader.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Everything looks fine} one{1 thing needs attention} other{{count} things need attention}}'**
  String diagnosticsHeader(int count);

  /// No description provided for @diagnosticsMessage.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, set{set} off{Off} idle{Not connected} connected{Connected} connecting{Connecting / reconnecting} waiting{Waiting for live stream} failed{Failed (private details omitted)} portBusy{Port is already in use} authentication{Authentication failed} refused{Connection refused} timeout{Connection timed out} listeningPort{Listening on port {value}} starting{Starting} noAlerts{No alerts page connected in OBS} pages{Pages: chat / alerts / poll / captions / giveaway / goals / timer: {value}} loading{Loading {value}} ready{Ready: {value}} listening{Listening} downloading{Downloading {value}} missingModel{Model download required} commandsOn{Voice commands on} commandsOff{Voice commands off} shortcutsOk{None assigned or all registered} shortcutTaken{Shortcut taken by another app: {value}} silenceTts{Silence voice reader} toggleTts{Toggle voice reader} channelSet{Channel set} channelUnset{Channel not set} scene{Scene: {value}} metrics{{value} kbps / dropped frames} other{}}'**
  String diagnosticsMessage(String kind, String value);

  /// No description provided for @diagnosticsArea.
  ///
  /// In en, this message translates to:
  /// **'{area, select, youtube{YouTube} twitch{Twitch} kick{Kick} obs{OBS} server{Overlay server} tts{Voice reader (TTS)} captions{Captions and voice commands} shortcuts{Global shortcuts} other{}}'**
  String diagnosticsArea(String area);

  /// No description provided for @giveawayTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyword giveaway'**
  String get giveawayTitle;

  /// No description provided for @giveawayDescription.
  ///
  /// In en, this message translates to:
  /// **'Viewers enter once by typing the keyword in chat.'**
  String get giveawayDescription;

  /// No description provided for @giveawayKeyword.
  ///
  /// In en, this message translates to:
  /// **'Keyword'**
  String get giveawayKeyword;

  /// No description provided for @giveawayMembersOnly.
  ///
  /// In en, this message translates to:
  /// **'Members / subscribers only'**
  String get giveawayMembersOnly;

  /// No description provided for @giveawayStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get giveawayStart;

  /// No description provided for @giveawayClose.
  ///
  /// In en, this message translates to:
  /// **'Close entries'**
  String get giveawayClose;

  /// No description provided for @giveawayDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get giveawayDraw;

  /// No description provided for @giveawayRedraw.
  ///
  /// In en, this message translates to:
  /// **'Draw again'**
  String get giveawayRedraw;

  /// No description provided for @giveawayClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get giveawayClear;

  /// No description provided for @giveawayClosed.
  ///
  /// In en, this message translates to:
  /// **'Entries closed'**
  String get giveawayClosed;

  /// No description provided for @giveawayWinner.
  ///
  /// In en, this message translates to:
  /// **'Winner'**
  String get giveawayWinner;

  /// No description provided for @giveawayDrawing.
  ///
  /// In en, this message translates to:
  /// **'Drawing…'**
  String get giveawayDrawing;

  /// No description provided for @giveawayPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Airstream Giveaway'**
  String get giveawayPageTitle;

  /// No description provided for @giveawayParticipants.
  ///
  /// In en, this message translates to:
  /// **'{count} participants'**
  String giveawayParticipants(int count);

  /// No description provided for @giveawayPageOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on the overlay server to show this in OBS.'**
  String get giveawayPageOff;

  /// No description provided for @giveawayPageUrl.
  ///
  /// In en, this message translates to:
  /// **'OBS page: {url}'**
  String giveawayPageUrl(String url);

  /// No description provided for @giveawayUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Giveaway page URL copied'**
  String get giveawayUrlCopied;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsTitle;

  /// No description provided for @goalsDescription.
  ///
  /// In en, this message translates to:
  /// **'Track support and adjust progress during your stream.'**
  String get goalsDescription;

  /// No description provided for @goalsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get goalsAdd;

  /// No description provided for @goalsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get goalsEdit;

  /// No description provided for @goalsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get goalsDelete;

  /// No description provided for @goalsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to 0'**
  String get goalsReset;

  /// No description provided for @goalsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get goalsSave;

  /// No description provided for @goalsName.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get goalsName;

  /// No description provided for @goalsType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get goalsType;

  /// No description provided for @goalsTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalsTarget;

  /// No description provided for @goalsSubs.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get goalsSubs;

  /// No description provided for @goalsBits.
  ///
  /// In en, this message translates to:
  /// **'Bits'**
  String get goalsBits;

  /// No description provided for @goalsKicks.
  ///
  /// In en, this message translates to:
  /// **'Kicks'**
  String get goalsKicks;

  /// No description provided for @goalsManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get goalsManual;

  /// No description provided for @goalsReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached!'**
  String get goalsReached;

  /// No description provided for @goalsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Airstream Goals'**
  String get goalsPageTitle;

  /// No description provided for @goalsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a title and a target from 1 to 1,000,000.'**
  String get goalsInvalid;

  /// No description provided for @goalsPageOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on the overlay server to show this in OBS.'**
  String get goalsPageOff;

  /// No description provided for @goalsPageUrl.
  ///
  /// In en, this message translates to:
  /// **'OBS page: {url}'**
  String goalsPageUrl(String url);

  /// No description provided for @goalsUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Goals page URL copied'**
  String get goalsUrlCopied;

  /// No description provided for @subathonTitle.
  ///
  /// In en, this message translates to:
  /// **'Subathon timer'**
  String get subathonTitle;

  /// No description provided for @subathonStartMinutes.
  ///
  /// In en, this message translates to:
  /// **'Start minutes'**
  String get subathonStartMinutes;

  /// No description provided for @subathonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get subathonStart;

  /// No description provided for @subathonPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get subathonPause;

  /// No description provided for @subathonResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get subathonResume;

  /// No description provided for @subathonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get subathonReset;

  /// No description provided for @subathonRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get subathonRules;

  /// No description provided for @subathonPerSub.
  ///
  /// In en, this message translates to:
  /// **'Seconds per subscription or gifted sub'**
  String get subathonPerSub;

  /// No description provided for @subathonPerBits.
  ///
  /// In en, this message translates to:
  /// **'Seconds per 100 Bits'**
  String get subathonPerBits;

  /// No description provided for @subathonPerKicks.
  ///
  /// In en, this message translates to:
  /// **'Seconds per 100 Kicks'**
  String get subathonPerKicks;

  /// No description provided for @subathonCap.
  ///
  /// In en, this message translates to:
  /// **'Maximum remaining minutes (0 = no limit)'**
  String get subathonCap;

  /// No description provided for @subathonIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get subathonIdle;

  /// No description provided for @subathonRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get subathonRunning;

  /// No description provided for @subathonPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get subathonPaused;

  /// No description provided for @subathonEnded.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up!'**
  String get subathonEnded;

  /// No description provided for @subathonPageOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on the overlay server to show this in OBS.'**
  String get subathonPageOff;

  /// No description provided for @subathonDescription.
  ///
  /// In en, this message translates to:
  /// **'Add time from support during your stream.'**
  String get subathonDescription;

  /// No description provided for @subathonUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Timer page URL copied'**
  String get subathonUrlCopied;

  /// No description provided for @mediaLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Media library'**
  String get mediaLibraryTitle;

  /// No description provided for @mediaUsage.
  ///
  /// In en, this message translates to:
  /// **'{used} of 500 MB'**
  String mediaUsage(String used);

  /// No description provided for @mediaAdd.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get mediaAdd;

  /// No description provided for @mediaDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get mediaDelete;

  /// No description provided for @mediaRejectType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type or invalid file contents.'**
  String get mediaRejectType;

  /// No description provided for @mediaRejectSize.
  ///
  /// In en, this message translates to:
  /// **'File exceeds its size limit (images 10 MB, videos 50 MB, audio 5 MB).'**
  String get mediaRejectSize;

  /// No description provided for @mediaRejectTotal.
  ///
  /// In en, this message translates to:
  /// **'The library would exceed 500 MB.'**
  String get mediaRejectTotal;

  /// No description provided for @alertMedia.
  ///
  /// In en, this message translates to:
  /// **'Image or video'**
  String get alertMedia;

  /// No description provided for @mediaNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get mediaNone;

  /// No description provided for @alertMediaAudio.
  ///
  /// In en, this message translates to:
  /// **'Play video sound'**
  String get alertMediaAudio;

  /// No description provided for @mediaLibraryName.
  ///
  /// In en, this message translates to:
  /// **'Library: {name}'**
  String mediaLibraryName(String name);

  /// No description provided for @mediaImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get mediaImage;

  /// No description provided for @mediaVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaVideo;

  /// No description provided for @mediaAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get mediaAudio;

  /// No description provided for @templatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templatesTitle;

  /// No description provided for @templatesDescription.
  ///
  /// In en, this message translates to:
  /// **'A template is a folder of HTML, CSS and JavaScript in Documents\\Airstream\\Templates. Each template has its own OBS URL.'**
  String get templatesDescription;

  /// No description provided for @templatesNew.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get templatesNew;

  /// No description provided for @templatesOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get templatesOpenFolder;

  /// No description provided for @templatesTest.
  ///
  /// In en, this message translates to:
  /// **'Send test events'**
  String get templatesTest;

  /// No description provided for @templatesTestSent.
  ///
  /// In en, this message translates to:
  /// **'Test events sent to open template pages'**
  String get templatesTestSent;

  /// No description provided for @templatesTestEmpty.
  ///
  /// In en, this message translates to:
  /// **'Open a template in OBS first'**
  String get templatesTestEmpty;

  /// No description provided for @templatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get templatesEmpty;

  /// No description provided for @templatesInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet access'**
  String get templatesInternet;

  /// No description provided for @templatesCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get templatesCopy;

  /// No description provided for @templatesCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied'**
  String get templatesCopied;

  /// No description provided for @templatesPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get templatesPreview;

  /// No description provided for @templatesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit code'**
  String get templatesEdit;

  /// No description provided for @templatesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get templatesDelete;

  /// No description provided for @templatesName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get templatesName;

  /// No description provided for @templatesRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get templatesRequired;

  /// No description provided for @templatesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get templatesCreate;

  /// No description provided for @templatesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get templatesCancel;

  /// No description provided for @templatesSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get templatesSave;

  /// No description provided for @templatesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get templatesSaved;

  /// No description provided for @templatesClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get templatesClose;

  /// No description provided for @templatesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get templatesDiscard;

  /// No description provided for @templatesUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get templatesUnsaved;

  /// No description provided for @templatesLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is over 512 KB. Edit it from the folder instead.'**
  String get templatesLarge;

  /// No description provided for @templatesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the action. Check the template folder and try again.'**
  String get templatesFailed;

  /// No description provided for @templatesBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank'**
  String get templatesBlank;

  /// No description provided for @templatesChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get templatesChat;

  /// No description provided for @templatesAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get templatesAlerts;

  /// No description provided for @templatesGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal bar'**
  String get templatesGoal;

  /// No description provided for @templatesBlankDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the last SDK event'**
  String get templatesBlankDescription;

  /// No description provided for @templatesChatDescription.
  ///
  /// In en, this message translates to:
  /// **'Live messages with emotes and avatars'**
  String get templatesChatDescription;

  /// No description provided for @templatesAlertsDescription.
  ///
  /// In en, this message translates to:
  /// **'Animated alerts, one at a time'**
  String get templatesAlertsDescription;

  /// No description provided for @templatesGoalDescription.
  ///
  /// In en, this message translates to:
  /// **'Progress towards one of your goals'**
  String get templatesGoalDescription;

  /// No description provided for @templatesMissingIndex.
  ///
  /// In en, this message translates to:
  /// **'Missing index.html'**
  String get templatesMissingIndex;

  /// No description provided for @templatesInvalidManifest.
  ///
  /// In en, this message translates to:
  /// **'Invalid template.json'**
  String get templatesInvalidManifest;

  /// No description provided for @templatesUnsupportedSdk.
  ///
  /// In en, this message translates to:
  /// **'Unsupported SDK version'**
  String get templatesUnsupportedSdk;

  /// No description provided for @templatesOversizedIndex.
  ///
  /// In en, this message translates to:
  /// **'index.html exceeds 2 MB'**
  String get templatesOversizedIndex;

  /// No description provided for @templatesOpenCount.
  ///
  /// In en, this message translates to:
  /// **'{count} open in OBS'**
  String templatesOpenCount(int count);

  /// No description provided for @templatesError.
  ///
  /// In en, this message translates to:
  /// **'Error in {source}:{line}: {message}'**
  String templatesError(String source, String line, String message);

  /// No description provided for @templatesDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? This deletes its folder and cannot be undone.'**
  String templatesDeleteConfirm(String name);

  /// No description provided for @templatesAi.
  ///
  /// In en, this message translates to:
  /// **'Create with AI'**
  String get templatesAi;

  /// No description provided for @templatesAiSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Open this folder in your AI tool, for example OpenCode, Claude Code or Codex.\n2. Paste the instruction.\n3. The template appears in this list: copy its URL into OBS.'**
  String get templatesAiSteps;

  /// No description provided for @templatesAiDescription.
  ///
  /// In en, this message translates to:
  /// **'What should your template show?'**
  String get templatesAiDescription;

  /// No description provided for @templatesAiCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy instruction'**
  String get templatesAiCopy;

  /// No description provided for @templatesAiCopied.
  ///
  /// In en, this message translates to:
  /// **'Instruction copied'**
  String get templatesAiCopied;

  /// No description provided for @templatesAiInstruction.
  ///
  /// In en, this message translates to:
  /// **'Read AGENTS.md in this folder first. Create a new template in a new folder named {id}.\nWhat it must show:\n{description}\nTest it at {url} and fix browser console errors. When done, tell me its OBS URL and recommended size.'**
  String templatesAiInstruction(String id, String description, String url);

  /// No description provided for @templateCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get templateCustomize;

  /// No description provided for @templateReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get templateReset;

  /// No description provided for @templateFieldNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get templateFieldNone;

  /// No description provided for @templateFieldColorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use #rrggbb or #rrggbbaa. This color has not been saved.'**
  String get templateFieldColorInvalid;

  /// No description provided for @templateExport.
  ///
  /// In en, this message translates to:
  /// **'Export .zip'**
  String get templateExport;

  /// No description provided for @templateImport.
  ///
  /// In en, this message translates to:
  /// **'Import .zip'**
  String get templateImport;

  /// No description provided for @templateDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get templateDuplicate;

  /// No description provided for @templateCopyWord.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get templateCopyWord;

  /// No description provided for @templateArchiveDone.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get templateArchiveDone;

  /// No description provided for @templateTrust.
  ///
  /// In en, this message translates to:
  /// **'This template contains code that runs in OBS. Import only templates from people you trust.'**
  String get templateTrust;

  /// No description provided for @templateArchiveSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} files · {bytes} bytes'**
  String templateArchiveSummary(int count, int bytes);

  /// No description provided for @templateRejectZip.
  ///
  /// In en, this message translates to:
  /// **'ZIP exceeds 100 MB.'**
  String get templateRejectZip;

  /// No description provided for @templateRejectCount.
  ///
  /// In en, this message translates to:
  /// **'More than 500 files.'**
  String get templateRejectCount;

  /// No description provided for @templateRejectTotal.
  ///
  /// In en, this message translates to:
  /// **'Uncompressed content exceeds 100 MB.'**
  String get templateRejectTotal;

  /// No description provided for @templateRejectFile.
  ///
  /// In en, this message translates to:
  /// **'A file exceeds 50 MB.'**
  String get templateRejectFile;

  /// No description provided for @templateRejectPath.
  ///
  /// In en, this message translates to:
  /// **'Unsafe or duplicate file path.'**
  String get templateRejectPath;

  /// No description provided for @templateRejectLink.
  ///
  /// In en, this message translates to:
  /// **'Links and special files are not allowed.'**
  String get templateRejectLink;

  /// No description provided for @templateRejectType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type.'**
  String get templateRejectType;

  /// No description provided for @templateRejectLayout.
  ///
  /// In en, this message translates to:
  /// **'Use files at the ZIP root or inside one folder.'**
  String get templateRejectLayout;

  /// No description provided for @templateRejectIndex.
  ///
  /// In en, this message translates to:
  /// **'Missing index.html.'**
  String get templateRejectIndex;

  /// No description provided for @templateRejectSize.
  ///
  /// In en, this message translates to:
  /// **'Invalid ZIP, damaged content or decompression size limit exceeded.'**
  String get templateRejectSize;

  /// No description provided for @liveTab.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveTab;

  /// No description provided for @liveServerOff.
  ///
  /// In en, this message translates to:
  /// **'Overlay server is off'**
  String get liveServerOff;

  /// No description provided for @liveOpenObs.
  ///
  /// In en, this message translates to:
  /// **'Go to OBS & Overlay'**
  String get liveOpenObs;

  /// No description provided for @liveServerNotice.
  ///
  /// In en, this message translates to:
  /// **'To show these tools in OBS, turn on the overlay server.'**
  String get liveServerNotice;

  /// No description provided for @templatesEmptyGuide.
  ///
  /// In en, this message translates to:
  /// **'Start from an example\nAsk an AI agent\nImport a template someone shared'**
  String get templatesEmptyGuide;

  /// No description provided for @ruleLabel.
  ///
  /// In en, this message translates to:
  /// **'{code, select, krules{Rules} kdescription{When something happens in your stream, Airstream can do things for you.} kautomation{Automation on} knew{New rule} krecipes{Recipes} kempty{Start with Recipes for an example.} kempty2{Or choose New rule to build your own.} ktripped{Automation paused itself after too many runs in a minute.} kresume{Resume} kinvalid{This rule needs fixing} kpublicObs{Anyone in chat can change OBS with this rule} kpublicChatText{Chat text will appear on your stream} knoCooldown{No cooldown: chat can repeat it as fast as it wants} kedit{Edit} kduplicate{Duplicate} kdelete{Delete} kcopy{copy} kconfirmDelete{Delete this rule?} kcancel{Cancel} kdiscard{Discard changes?} kclose{Close} ksave{Save} kname{Name} kwhen{When} kif{If} kdo{Do} klimits{Limits} koverlap{If it is already running} kaddAction{Add action} ktest{Test} ktestWith{Test with} krun{Run now} kmatched{Matched} kaccepted{Run accepted} khistory{History} kclear{Clear} knoHistory{No runs yet.} kup{Move up} kdown{Move down} kfieldError{Check this value and its limits} kcooldownSeconds{Cooldown (seconds, 0–3600)} kuserCooldownSeconds{Per-person cooldown (seconds, 0–3600)} kqueue{Queue: wait for the previous run} kskip{Skip: ignore while already running} konlyWhileStreaming{Only while OBS is streaming} keveryone{Everyone} kmember{Members/subscribers} kmoderator{Moderators} kvip{VIPs} kowner{Owner} kchat{Chat} ksupport{Support} klive{Live tools} kobs{OBS} ktime{Time} kmanual{Manual} kflow{Flow} kvoice{Voice} ksound{Sound} kpages{Pages and templates} kadd{Add} kdone{Done ✓} kskipped{Skipped} kfailed{Failed} kuncertain{Uncertain} kcancelled{Cancelled} kwouldRun{Would run} kpending{Pending} kchat_message{Message contains text} kchat_command{Chat command} kchat_firstMessage{First message} ksupport_superchat{Super Chat} ksupport_bits{Bits} ksupport_membership{Membership / subscription} ksupport_gift{Gift subscriptions} ksupport_raid{Raid} ksupport_kicks{Kicks} kgoal_reached{Goal reached} kgiveaway_winner{Giveaway winner} kpoll_ended{Poll ended} kclock_ended{Timer ended} ksubathon_ended{Subathon ended} kobs_streamStarted{Stream started} kobs_streamStopped{Stream stopped} kobs_recordingStarted{Recording started} kobs_recordingStopped{Recording stopped} kobs_sceneChanged{Scene changed} kinterval{Every N minutes} kwait{Wait} kobs_scene{Switch scene} kobs_previousScene{Return to previous scene} kobs_recording{Recording} kobs_source{Show / hide source} kobs_mute{Mute / unmute input} kobs_text{Set text} kobs_filter{Turn filter on / off} ktts_say{Read aloud} ksound_play{Play sound} kalert_show{Show alert} kfeatured{Feature message} ktemplate_trigger{Trigger template} kgoal_adjust{Adjust goal} kclock{Timer} ksubathon_adjust{Adjust subathon} kgiveaway{Giveaway} kcounter{Counter} kcommand{Command} kmatch{Match} ktext{Text} kminAmount{Minimum amount} kcurrency{Currency} kmin{Minimum count} kminMonths{Minimum months} kgoalId{Goal} kscene{Scene} kminutes{Minutes} kseconds{Seconds} kstate{State} ksource{Source} kfilter{Filter} kvisible{Visibility} kinput{Audio input} kmediaId{Library media} ktitle{Title} kdata{Data} kdelta{Change} kop{Operation} kkeyword{Keyword} kmembersOnly{Members only} kvalue{Value} kcontains{Contains} kstartsWith{Starts with} kequals{Equals} kstart{Start} kstop{Stop} kshow{Show} khide{Hide} ktoggle{Toggle} kmute{Mute} kunmute{Unmute} kenable{Turn on} kdisable{Turn off} kbuiltin{Built in} klibrary{Library} kchime{Chime} kcoin{Coin} kfanfare{Fanfare} kset{Set} kdraw{Draw} kautomationOff{Automation is off} kchainLimit{Chain limit reached} kinvalidRule{Invalid rule} kruleDisabled{Rule is disabled} kwrongTrigger{Different trigger} kplatform{Platform does not match} krole{Role does not match} knotStreaming{OBS is not streaming} ktextMismatch{Text does not match} kamountUnknown{Amount is unknown} kcurrencyMismatch{Currency does not match} kbelowMinimum{Below the minimum} kcooldown{Rule is cooling down} kuserCooldown{Person is cooling down} ktrippedReason{Automation paused by the safety limit} krunRateExceeded{Too many runs in a minute} koverlapSkipped{Already running} kqueueFull{Queue is full} knoPreviousScene{No previous scene saved} ktargetError{Action failed} ktimeout{Action timed out} kdisposed{Engine is closed} knotConnected{OBS is disconnected} kttsOff{Voice reader is off or not ready} knoMessage{No chat message available} kgoalNotFound{Goal not found} ktimerNotRunning{Subathon is not running} knoReceiver{No template receiver connected} kinvalidKeyword{Invalid keyword} kalreadyOpen{Giveaway is already open} knotOpen{Giveaway is not open} knoEntrants{No eligible entrants} kqueue_joined{Viewer joined the queue} kqueue_next{Next players} kqueue_open{Open the queue} kqueue_close{Close the queue} kqueue_pause{Pause the queue} kwinnerCount{Winners} kcount{Players} krandom{Pick randomly} kqueueAlreadyOpen{The queue is already open} kqueueAlreadyPaused{The queue is already paused} kqueueAlreadyClosed{The queue is already closed} kqueueEmpty{Nobody is waiting in the queue} kcounterLimit{Counter limit reached} krecipe1{Welcome a raid} krecipeDesc1{Show Raid for 15 seconds, then return.} krecipe2{Share your socials} krecipeDesc2{Trigger redes and read your links aloud.} krecipe3{Read Super Chats} krecipeDesc3{Read messages with an amount of at least \$5.} krecipe4{Regular reminder} krecipeDesc4{Trigger recordatorio every 20 minutes.} krecipe5{Celebrate a goal} krecipeDesc5{Show Celebración for 10 seconds, then return.} krecipe6{Count deaths} krecipeDesc6{Moderators add to muertes and trigger a template.} krecipe7{Counter on screen} krecipeDesc7{Moderators add to muertes and show it in a text source.} kdiscardAction{Discard} kbuttons{Rule buttons} knotFound{Item not found} knotTextSource{Not a text source} knoAlertsPage{No alerts page connected} kwillCheckInObs{Will check in OBS} kwouldSkip{Would be skipped} kwebhook{Webhook name (optional)} kwebhookConflict{This webhook name is already used.} kwebhookTitle{Stream Deck and other apps} kwebhookEnable{Enable local rule URLs} kwebhookHelp{Stream Deck: use the Website action with GET request in background. Any app or script can call the URL.} kwebhookSecretWarning{Anyone with the URL can run these rules. Keep it private.} kwebhookServerHelp{Enable the local server in OBS settings to use these URLs.} khideToken{Hide token} krevealToken{Reveal token} kcopyToken{Copy token} kregenerate{Regenerate} kregenerateConfirm{Regenerate token? Existing buttons will stop working.} kexportRules{Export rules} kimportRules{Import rules} kimportReview{Review imported rules} kimportDisabled{All imported rules will be disabled. Review them before enabling.} kimportSkipped{Rules skipped (50-rule limit)} kwebhookCollision{Webhook name removed because it is already used:} kobsNames{Check these names exist in your OBS:} kmissingMedia{Library media missing here (action kept):} ktemplateName{Template trigger name:} kunknownFormat{Unknown rules file format.} kunknownVersion{Unsupported rules file version.} kmalformedJson{Invalid rules JSON file.} kfileTooLarge{Rules file exceeds 1 MB.} ksharingFailed{Could not read or write the rules file.} kobs_stream{Streaming} kobs_replay{Replay buffer} kobs_media{Control media} kobs_volume{Volume} kobs_refresh{Refresh browser source} khttp_request{Call a URL} kstreamStart{Start stream} kstreamStop{Stop stream} kreplaySave{Save replay} kplay{Play} kpause{Pause} kreset{Reset} krestart{Restart} kmode{Mode} kchange{Change} kdb{dB} kmethod{Method} kget{GET} kpost{POST} kurl{URL} kcontentType{Content type} kjson{JSON} kbody{Body} kstreamAlready{Stream is already in that state} kpublicStreamControl{Public chat cannot start or stop the stream} kreplayOff{The replay buffer is off} kreplayAlready{Replay buffer is already in that state} knotBrowserSource{Not a browser source} knoUrl{Missing URL} kinvalidHttpUrl{Enter a valid HTTP or HTTPS URL} khttpStatus{The URL returned an error} khttpError{Could not connect to the URL} kresetHttpUrl{Set the URL again in:} krecipe8{Tell Discord you are live} krecipeDesc8{Paste your Discord webhook URL to announce your stream.} other{…}}'**
  String ruleLabel(String code);

  /// No description provided for @ruleSummary.
  ///
  /// In en, this message translates to:
  /// **'When {trigger} → {count, plural, =1{1 action} other{{count} actions}}'**
  String ruleSummary(String trigger, int count);

  /// No description provided for @templatesGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get templatesGallery;

  /// No description provided for @galleryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get galleryAdd;

  /// No description provided for @galleryAddAgain.
  ///
  /// In en, this message translates to:
  /// **'Add again'**
  String get galleryAddAgain;

  /// No description provided for @galleryNewVersion.
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get galleryNewVersion;

  /// No description provided for @galleryPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Start the server to preview gallery items.'**
  String get galleryPreviewUnavailable;

  /// No description provided for @galleryRecentSupport.
  ///
  /// In en, this message translates to:
  /// **'Recent support'**
  String get galleryRecentSupport;

  /// No description provided for @galleryRecentSupportDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the latest support from YouTube, Twitch, and Kick.'**
  String get galleryRecentSupportDescription;

  /// No description provided for @galleryTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get galleryTheme;

  /// No description provided for @galleryFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get galleryFont;

  /// No description provided for @galleryAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get galleryAccent;

  /// No description provided for @galleryLogo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get galleryLogo;

  /// No description provided for @galleryLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get galleryLanguage;

  /// No description provided for @galleryHeading.
  ///
  /// In en, this message translates to:
  /// **'Custom heading'**
  String get galleryHeading;

  /// No description provided for @gallerySupportCount.
  ///
  /// In en, this message translates to:
  /// **'Maximum entries'**
  String get gallerySupportCount;

  /// No description provided for @galleryShowEmpty.
  ///
  /// In en, this message translates to:
  /// **'Show the empty message'**
  String get galleryShowEmpty;

  /// No description provided for @galleryStartingSoon.
  ///
  /// In en, this message translates to:
  /// **'Starting soon'**
  String get galleryStartingSoon;

  /// No description provided for @galleryStartingSoonDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the stream with a countdown, rotating messages, and live chat.'**
  String get galleryStartingSoonDescription;

  /// No description provided for @galleryBeRightBack.
  ///
  /// In en, this message translates to:
  /// **'Be right back'**
  String get galleryBeRightBack;

  /// No description provided for @galleryBeRightBackDescription.
  ///
  /// In en, this message translates to:
  /// **'Show a break timer alongside live chat and the latest support.'**
  String get galleryBeRightBackDescription;

  /// No description provided for @galleryStreamEnding.
  ///
  /// In en, this message translates to:
  /// **'Stream ending'**
  String get galleryStreamEnding;

  /// No description provided for @galleryStreamEndingDescription.
  ///
  /// In en, this message translates to:
  /// **'Thank viewers with session totals and supporter rankings.'**
  String get galleryStreamEndingDescription;

  /// No description provided for @galleryCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get galleryCredits;

  /// No description provided for @galleryCreditsDescription.
  ///
  /// In en, this message translates to:
  /// **'Roll end credits with supporters, rankings, and a farewell.'**
  String get galleryCreditsDescription;

  /// No description provided for @galleryBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get galleryBackground;

  /// No description provided for @galleryBackgroundMedia.
  ///
  /// In en, this message translates to:
  /// **'Background image or video'**
  String get galleryBackgroundMedia;

  /// No description provided for @galleryMessages.
  ///
  /// In en, this message translates to:
  /// **'Rotating messages (separate with |)'**
  String get galleryMessages;

  /// No description provided for @galleryScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Title (leave blank for the default)'**
  String get galleryScreenTitle;

  /// No description provided for @gallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get gallerySubtitle;

  /// No description provided for @galleryStartTime.
  ///
  /// In en, this message translates to:
  /// **'Local start time (24-hour HH:MM)'**
  String get galleryStartTime;

  /// No description provided for @galleryShowChat.
  ///
  /// In en, this message translates to:
  /// **'Show live chat'**
  String get galleryShowChat;

  /// No description provided for @galleryMinutes.
  ///
  /// In en, this message translates to:
  /// **'Countdown minutes (0 for none)'**
  String get galleryMinutes;

  /// No description provided for @galleryShowDuration.
  ///
  /// In en, this message translates to:
  /// **'Show session duration'**
  String get galleryShowDuration;

  /// No description provided for @galleryShowMessages.
  ///
  /// In en, this message translates to:
  /// **'Show message count'**
  String get galleryShowMessages;

  /// No description provided for @galleryShowChatters.
  ///
  /// In en, this message translates to:
  /// **'Show chatter count'**
  String get galleryShowChatters;

  /// No description provided for @galleryShowSupporters.
  ///
  /// In en, this message translates to:
  /// **'Show supporter count'**
  String get galleryShowSupporters;

  /// No description provided for @galleryShowTopSupporters.
  ///
  /// In en, this message translates to:
  /// **'Show top supporters'**
  String get galleryShowTopSupporters;

  /// No description provided for @galleryShowTopChatters.
  ///
  /// In en, this message translates to:
  /// **'Show top chatters'**
  String get galleryShowTopChatters;

  /// No description provided for @galleryCurrency.
  ///
  /// In en, this message translates to:
  /// **'Super Chat currency (blank for automatic)'**
  String get galleryCurrency;

  /// No description provided for @galleryFinalText.
  ///
  /// In en, this message translates to:
  /// **'Final message'**
  String get galleryFinalText;

  /// No description provided for @galleryCreditsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Roll speed (pixels per second)'**
  String get galleryCreditsSpeed;

  /// No description provided for @galleryCreditsLoop.
  ///
  /// In en, this message translates to:
  /// **'Repeat credits'**
  String get galleryCreditsLoop;

  /// No description provided for @galleryTicker.
  ///
  /// In en, this message translates to:
  /// **'Ticker'**
  String get galleryTicker;

  /// No description provided for @galleryTickerDescription.
  ///
  /// In en, this message translates to:
  /// **'Scroll messages, recent support, goals, and subathon time across the stream.'**
  String get galleryTickerDescription;

  /// No description provided for @galleryLatestSupport.
  ///
  /// In en, this message translates to:
  /// **'Latest support'**
  String get galleryLatestSupport;

  /// No description provided for @galleryLatestSupportDescription.
  ///
  /// In en, this message translates to:
  /// **'Spotlight the newest supporter or rotate through support types.'**
  String get galleryLatestSupportDescription;

  /// No description provided for @galleryTopSupporters.
  ///
  /// In en, this message translates to:
  /// **'Top of the stream'**
  String get galleryTopSupporters;

  /// No description provided for @galleryTopSupportersDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the five leading supporters or chatters in a session.'**
  String get galleryTopSupportersDescription;

  /// No description provided for @galleryTickerMessages.
  ///
  /// In en, this message translates to:
  /// **'Ticker messages (separate with |)'**
  String get galleryTickerMessages;

  /// No description provided for @galleryTickerSpeed.
  ///
  /// In en, this message translates to:
  /// **'Scroll speed (pixels per second)'**
  String get galleryTickerSpeed;

  /// No description provided for @galleryTickerShowCustom.
  ///
  /// In en, this message translates to:
  /// **'Show custom messages'**
  String get galleryTickerShowCustom;

  /// No description provided for @galleryTickerShowLatest.
  ///
  /// In en, this message translates to:
  /// **'Show the latest support by type'**
  String get galleryTickerShowLatest;

  /// No description provided for @galleryTickerShowGoals.
  ///
  /// In en, this message translates to:
  /// **'Show goal progress'**
  String get galleryTickerShowGoals;

  /// No description provided for @galleryTickerShowTimer.
  ///
  /// In en, this message translates to:
  /// **'Show the running subathon timer'**
  String get galleryTickerShowTimer;

  /// No description provided for @galleryTickerShowEmpty.
  ///
  /// In en, this message translates to:
  /// **'Show the ticker title when empty'**
  String get galleryTickerShowEmpty;

  /// No description provided for @galleryLatestSupportMode.
  ///
  /// In en, this message translates to:
  /// **'Support display mode'**
  String get galleryLatestSupportMode;

  /// No description provided for @galleryRotationSeconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds between entries'**
  String get galleryRotationSeconds;

  /// No description provided for @galleryRankingType.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard type'**
  String get galleryRankingType;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueTitle;

  /// No description provided for @queueClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get queueClosed;

  /// No description provided for @queueOpenStatus.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get queueOpenStatus;

  /// No description provided for @queuePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get queuePaused;

  /// No description provided for @queueOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get queueOpen;

  /// No description provided for @queuePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get queuePause;

  /// No description provided for @queueClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get queueClose;

  /// No description provided for @queueJoinHint.
  ///
  /// In en, this message translates to:
  /// **'Type {command} to play'**
  String queueJoinHint(String command);

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody is waiting'**
  String get queueEmpty;

  /// No description provided for @queueNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get queueNext;

  /// No description provided for @queueNextCount.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get queueNextCount;

  /// No description provided for @queueRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get queueRandom;

  /// No description provided for @queueClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get queueClear;

  /// No description provided for @queueClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear the queue and everyone playing?'**
  String get queueClearConfirm;

  /// No description provided for @queuePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing now'**
  String get queuePlaying;

  /// No description provided for @queueNobodyPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nobody is playing'**
  String get queueNobodyPlaying;

  /// No description provided for @queueSettings.
  ///
  /// In en, this message translates to:
  /// **'Queue settings'**
  String get queueSettings;

  /// No description provided for @queueMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum queue size'**
  String get queueMax;

  /// No description provided for @queueRoles.
  ///
  /// In en, this message translates to:
  /// **'Who can join'**
  String get queueRoles;

  /// No description provided for @queueEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get queueEveryone;

  /// No description provided for @queueMembers.
  ///
  /// In en, this message translates to:
  /// **'Members and subscribers'**
  String get queueMembers;

  /// No description provided for @queueVip.
  ///
  /// In en, this message translates to:
  /// **'VIPs'**
  String get queueVip;

  /// No description provided for @queueModerators.
  ///
  /// In en, this message translates to:
  /// **'Moderators'**
  String get queueModerators;

  /// No description provided for @queuePriority.
  ///
  /// In en, this message translates to:
  /// **'Prioritize members and subscribers'**
  String get queuePriority;

  /// No description provided for @queueRejoin.
  ///
  /// In en, this message translates to:
  /// **'Allow joining again after playing'**
  String get queueRejoin;

  /// No description provided for @queueChatMods.
  ///
  /// In en, this message translates to:
  /// **'Moderator chat commands'**
  String get queueChatMods;

  /// No description provided for @queueChatModsHint.
  ///
  /// In en, this message translates to:
  /// **'Allows the owner and moderators to manage the queue from chat.'**
  String get queueChatModsHint;

  /// No description provided for @queueCommand.
  ///
  /// In en, this message translates to:
  /// **'Join command'**
  String get queueCommand;

  /// No description provided for @queueJoinWhenOpen.
  ///
  /// In en, this message translates to:
  /// **'Type {command} to play when the queue opens'**
  String queueJoinWhenOpen(String command);

  /// No description provided for @queueReservedCommand.
  ///
  /// In en, this message translates to:
  /// **'This command is reserved. Choose another one.'**
  String get queueReservedCommand;

  /// No description provided for @queueInvalidCommand.
  ///
  /// In en, this message translates to:
  /// **'Use ! followed by 1–24 letters, digits, hyphens or underscores.'**
  String get queueInvalidCommand;

  /// No description provided for @queueSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get queueSave;

  /// No description provided for @queueRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get queueRemove;

  /// No description provided for @queueDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get queueDone;

  /// No description provided for @galleryQueueDescription.
  ///
  /// In en, this message translates to:
  /// **'Show who is playing and who is waiting for a turn.'**
  String get galleryQueueDescription;

  /// No description provided for @galleryQueueCount.
  ///
  /// In en, this message translates to:
  /// **'Queue entries to show'**
  String get galleryQueueCount;

  /// No description provided for @galleryQueueHideClosed.
  ///
  /// In en, this message translates to:
  /// **'Hide when the queue is closed'**
  String get galleryQueueHideClosed;

  /// No description provided for @galleryQueueWaiting.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get galleryQueueWaiting;

  /// No description provided for @galleryQueueMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String galleryQueueMore(String count);

  /// No description provided for @alertQueuePause.
  ///
  /// In en, this message translates to:
  /// **'Pause alerts'**
  String get alertQueuePause;

  /// No description provided for @alertQueueResume.
  ///
  /// In en, this message translates to:
  /// **'Resume alerts'**
  String get alertQueueResume;

  /// No description provided for @alertQueueSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip current alert'**
  String get alertQueueSkip;

  /// No description provided for @alertQueueClear.
  ///
  /// In en, this message translates to:
  /// **'Clear waiting alerts'**
  String get alertQueueClear;

  /// No description provided for @alertQueueWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String alertQueueWaiting(int count);

  /// No description provided for @alertQueueWaitingHint.
  ///
  /// In en, this message translates to:
  /// **'Largest queue across open alerts pages'**
  String get alertQueueWaitingHint;

  /// No description provided for @alertQueueNoPage.
  ///
  /// In en, this message translates to:
  /// **'Open the alerts page to control its queue.'**
  String get alertQueueNoPage;

  /// No description provided for @alertPlatformFilter.
  ///
  /// In en, this message translates to:
  /// **'Automatic alerts by platform'**
  String get alertPlatformFilter;

  /// No description provided for @alertTiers.
  ///
  /// In en, this message translates to:
  /// **'Tiers by amount'**
  String get alertTiers;

  /// No description provided for @alertTierCurrency.
  ///
  /// In en, this message translates to:
  /// **'Super Chats use the original currency without conversion.'**
  String get alertTierCurrency;

  /// No description provided for @alertTierFrom.
  ///
  /// In en, this message translates to:
  /// **'From amount'**
  String get alertTierFrom;

  /// No description provided for @alertTierInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than zero.'**
  String get alertTierInvalid;

  /// No description provided for @alertTierAdd.
  ///
  /// In en, this message translates to:
  /// **'Add tier'**
  String get alertTierAdd;

  /// No description provided for @alertTierRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove tier'**
  String get alertTierRemove;

  /// No description provided for @alertTierInherit.
  ///
  /// In en, this message translates to:
  /// **'Use alert type setting'**
  String get alertTierInherit;

  /// No description provided for @alertTierAudioOn.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get alertTierAudioOn;

  /// No description provided for @alertTierAudioOff.
  ///
  /// In en, this message translates to:
  /// **'Mute audio'**
  String get alertTierAudioOff;

  /// No description provided for @featuredTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured message'**
  String get featuredTitle;

  /// No description provided for @featuredDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows messages you feature on stream.'**
  String get featuredDescription;

  /// No description provided for @featuredUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Featured page URL copied'**
  String get featuredUrlCopied;

  /// No description provided for @featuredRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove featured'**
  String get featuredRemove;

  /// No description provided for @featuredFontScale.
  ///
  /// In en, this message translates to:
  /// **'Featured text size'**
  String get featuredFontScale;

  /// No description provided for @featuredKeepVisible.
  ///
  /// In en, this message translates to:
  /// **'Keep visible until removed'**
  String get featuredKeepVisible;

  /// No description provided for @ttsWhatToRead.
  ///
  /// In en, this message translates to:
  /// **'What to read'**
  String get ttsWhatToRead;

  /// No description provided for @ttsReaderRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get ttsReaderRoles;

  /// No description provided for @ttsRoleEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get ttsRoleEveryone;

  /// No description provided for @ttsRoleModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get ttsRoleModerator;

  /// No description provided for @ttsRoleVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get ttsRoleVip;

  /// No description provided for @ttsRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get ttsRoleOwner;

  /// No description provided for @ttsReaderPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Platforms'**
  String get ttsReaderPlatforms;

  /// No description provided for @ttsAlwaysReadSupport.
  ///
  /// In en, this message translates to:
  /// **'Always read paid support'**
  String get ttsAlwaysReadSupport;

  /// No description provided for @ttsSkipEmoteOnly.
  ///
  /// In en, this message translates to:
  /// **'Skip emote-only messages'**
  String get ttsSkipEmoteOnly;

  /// No description provided for @ttsLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get ttsLinks;

  /// No description provided for @ttsLinksRead.
  ///
  /// In en, this message translates to:
  /// **'Read the message'**
  String get ttsLinksRead;

  /// No description provided for @ttsLinksSay.
  ///
  /// In en, this message translates to:
  /// **'Say “link”'**
  String get ttsLinksSay;

  /// No description provided for @ttsLinksSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip the message'**
  String get ttsLinksSkip;

  /// No description provided for @ttsSpokenLink.
  ///
  /// In en, this message translates to:
  /// **'link'**
  String get ttsSpokenLink;

  /// No description provided for @highlightSoundMention.
  ///
  /// In en, this message translates to:
  /// **'Mention'**
  String get highlightSoundMention;

  /// No description provided for @highlightSoundWord.
  ///
  /// In en, this message translates to:
  /// **'Highlighted word'**
  String get highlightSoundWord;

  /// No description provided for @highlightSoundFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'First message'**
  String get highlightSoundFirstMessage;

  /// No description provided for @highlightSoundPriority.
  ///
  /// In en, this message translates to:
  /// **'If several highlights match, the mention takes priority, then the word, then the first message.'**
  String get highlightSoundPriority;

  /// No description provided for @sessionExportChat.
  ///
  /// In en, this message translates to:
  /// **'Export chat (CSV)'**
  String get sessionExportChat;

  /// No description provided for @sessionExportParticipants.
  ///
  /// In en, this message translates to:
  /// **'Export participants (CSV)'**
  String get sessionExportParticipants;

  /// No description provided for @sessionExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the CSV file.'**
  String get sessionExportFailed;

  /// No description provided for @sessionExportChatScope.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No chat messages are retained.} =1{Chat export includes 1 retained message.} other{Chat export includes the {count} messages still in the chat buffer.}}'**
  String sessionExportChatScope(int count);

  /// No description provided for @clockTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get clockTitle;

  /// No description provided for @clockDescription.
  ///
  /// In en, this message translates to:
  /// **'Run a countdown, stopwatch, or local clock on stream.'**
  String get clockDescription;

  /// No description provided for @clockMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get clockMode;

  /// No description provided for @clockCountdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get clockCountdown;

  /// No description provided for @clockStopwatch.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get clockStopwatch;

  /// No description provided for @clockLocalTime.
  ///
  /// In en, this message translates to:
  /// **'Local time'**
  String get clockLocalTime;

  /// No description provided for @clockLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get clockLabel;

  /// No description provided for @clockDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration in seconds (1–86,400)'**
  String get clockDuration;

  /// No description provided for @clockSound.
  ///
  /// In en, this message translates to:
  /// **'Sound at the end'**
  String get clockSound;

  /// No description provided for @clockSoundNone.
  ///
  /// In en, this message translates to:
  /// **'No sound'**
  String get clockSoundNone;

  /// No description provided for @clockStyle.
  ///
  /// In en, this message translates to:
  /// **'Page style'**
  String get clockStyle;

  /// No description provided for @clockStyleBig.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get clockStyleBig;

  /// No description provided for @clockStyleCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get clockStyleCompact;

  /// No description provided for @clockStyleRing.
  ///
  /// In en, this message translates to:
  /// **'Progress ring (countdown)'**
  String get clockStyleRing;

  /// No description provided for @clockEnded.
  ///
  /// In en, this message translates to:
  /// **'Time’s up!'**
  String get clockEnded;

  /// No description provided for @clockPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get clockPause;

  /// No description provided for @clockReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get clockReset;

  /// No description provided for @clockPlusMinute.
  ///
  /// In en, this message translates to:
  /// **'+1 min'**
  String get clockPlusMinute;

  /// No description provided for @clockMinusMinute.
  ///
  /// In en, this message translates to:
  /// **'−1 min'**
  String get clockMinusMinute;

  /// No description provided for @pollSaveSetup.
  ///
  /// In en, this message translates to:
  /// **'Save current setup'**
  String get pollSaveSetup;

  /// No description provided for @pollRenameSetup.
  ///
  /// In en, this message translates to:
  /// **'Rename saved poll'**
  String get pollRenameSetup;

  /// No description provided for @pollDeleteSetup.
  ///
  /// In en, this message translates to:
  /// **'Delete saved poll'**
  String get pollDeleteSetup;

  /// No description provided for @pollSetupName.
  ///
  /// In en, this message translates to:
  /// **'Name for this setup'**
  String get pollSetupName;

  /// No description provided for @pollSetupDuplicate.
  ///
  /// In en, this message translates to:
  /// **'That name is already in use.'**
  String get pollSetupDuplicate;

  /// No description provided for @pollSavedSetups.
  ///
  /// In en, this message translates to:
  /// **'Saved polls'**
  String get pollSavedSetups;

  /// No description provided for @pollSetupLimit.
  ///
  /// In en, this message translates to:
  /// **'Delete a saved poll to make room for another.'**
  String get pollSetupLimit;

  /// No description provided for @giveawayDrawCount.
  ///
  /// In en, this message translates to:
  /// **'Winners per draw'**
  String get giveawayDrawCount;

  /// No description provided for @giveawayDrawMany.
  ///
  /// In en, this message translates to:
  /// **'Draw {count} winners'**
  String giveawayDrawMany(int count);

  /// No description provided for @giveawayHistory.
  ///
  /// In en, this message translates to:
  /// **'Giveaway history'**
  String get giveawayHistory;

  /// No description provided for @giveawayHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No completed rounds yet.'**
  String get giveawayHistoryEmpty;

  /// No description provided for @giveawayClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get giveawayClearHistory;

  /// No description provided for @giveawayStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String giveawayStartedAt(String date);

  /// No description provided for @giveawayEndedAt.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String giveawayEndedAt(String date);

  /// No description provided for @giveawayNoWinners.
  ///
  /// In en, this message translates to:
  /// **'No winners'**
  String get giveawayNoWinners;

  /// No description provided for @galleryScoreboard.
  ///
  /// In en, this message translates to:
  /// **'Scoreboard'**
  String get galleryScoreboard;

  /// No description provided for @galleryScoreboardDescription.
  ///
  /// In en, this message translates to:
  /// **'Show selected rule counters and their current values.'**
  String get galleryScoreboardDescription;

  /// No description provided for @galleryScoreboardCounters.
  ///
  /// In en, this message translates to:
  /// **'Counter names, separated by commas (up to 8)'**
  String get galleryScoreboardCounters;

  /// No description provided for @galleryScoreboardLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels in the same order, separated by commas'**
  String get galleryScoreboardLabels;

  /// No description provided for @galleryScoreboardLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get galleryScoreboardLayout;

  /// No description provided for @galleryWordCloud.
  ///
  /// In en, this message translates to:
  /// **'Word cloud'**
  String get galleryWordCloud;

  /// No description provided for @galleryWordCloudDescription.
  ///
  /// In en, this message translates to:
  /// **'Display the most frequent words from the last five minutes of chat.'**
  String get galleryWordCloudDescription;

  /// No description provided for @galleryWordCloudMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum word length'**
  String get galleryWordCloudMinLength;

  /// No description provided for @galleryWordCloudMaxWords.
  ///
  /// In en, this message translates to:
  /// **'Maximum words'**
  String get galleryWordCloudMaxWords;

  /// No description provided for @galleryWordCloudRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh interval (seconds)'**
  String get galleryWordCloudRefresh;

  /// No description provided for @galleryEmoteWall.
  ///
  /// In en, this message translates to:
  /// **'Emote wall'**
  String get galleryEmoteWall;

  /// No description provided for @galleryEmoteWallDescription.
  ///
  /// In en, this message translates to:
  /// **'Float emotes from chat across the screen as they arrive.'**
  String get galleryEmoteWallDescription;

  /// No description provided for @galleryEmoteWallMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum emotes on screen'**
  String get galleryEmoteWallMax;

  /// No description provided for @galleryEmoteWallSize.
  ///
  /// In en, this message translates to:
  /// **'Emote size (pixels)'**
  String get galleryEmoteWallSize;

  /// No description provided for @galleryEmoteWallLifetime.
  ///
  /// In en, this message translates to:
  /// **'Time on screen (seconds)'**
  String get galleryEmoteWallLifetime;

  /// No description provided for @clockPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get clockPaused;

  /// No description provided for @galleryScoreboardHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get galleryScoreboardHome;

  /// No description provided for @galleryScoreboardAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get galleryScoreboardAway;

  /// No description provided for @galleryScoreboardRow.
  ///
  /// In en, this message translates to:
  /// **'Row'**
  String get galleryScoreboardRow;

  /// No description provided for @galleryScoreboardColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get galleryScoreboardColumn;

  /// No description provided for @backupExportEverything.
  ///
  /// In en, this message translates to:
  /// **'Export everything'**
  String get backupExportEverything;

  /// No description provided for @backupRestoreEverything.
  ///
  /// In en, this message translates to:
  /// **'Restore everything'**
  String get backupRestoreEverything;

  /// No description provided for @backupFileType.
  ///
  /// In en, this message translates to:
  /// **'Airstream backup'**
  String get backupFileType;

  /// No description provided for @backupRestoreReview.
  ///
  /// In en, this message translates to:
  /// **'This replaces your settings, templates and media library. Airstream saves a copy of your current data first.'**
  String get backupRestoreReview;

  /// No description provided for @backupRestoreContents.
  ///
  /// In en, this message translates to:
  /// **'Settings\nRules: {rules}\nTemplates: {templates}\nMedia files: {media}\nCreated: {created}'**
  String backupRestoreContents(
      int rules, int templates, int media, String created);

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreConfirm;

  /// No description provided for @backupExportDone.
  ///
  /// In en, this message translates to:
  /// **'Full backup exported.'**
  String get backupExportDone;

  /// No description provided for @backupRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Full backup restored.'**
  String get backupRestoreDone;

  /// No description provided for @backupExportError.
  ///
  /// In en, this message translates to:
  /// **'Could not export the full backup. Check the destination and the files in your libraries.'**
  String get backupExportError;

  /// No description provided for @backupRestoreError.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the backup. Check disk space and close programs using the library files.'**
  String get backupRestoreError;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is damaged or is not an Airstream full backup.'**
  String get backupInvalid;

  /// No description provided for @backupUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'This backup version is not supported.'**
  String get backupUnsupportedVersion;

  /// No description provided for @backupUnsafePath.
  ///
  /// In en, this message translates to:
  /// **'The backup contains an unsafe file path.'**
  String get backupUnsafePath;

  /// No description provided for @backupSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'A file or library exceeds the backup size limits.'**
  String get backupSizeLimit;

  /// No description provided for @backupMediaInvalid.
  ///
  /// In en, this message translates to:
  /// **'A media file is missing or does not match its library entry.'**
  String get backupMediaInvalid;

  /// No description provided for @backupRollbackError.
  ///
  /// In en, this message translates to:
  /// **'Restore was interrupted and automatic rollback failed. Your safety backup and original directories are still on disk.'**
  String get backupRollbackError;

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// No description provided for @settingsSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching settings'**
  String get settingsSearchEmpty;

  /// No description provided for @settingsSearchConnectionWords.
  ///
  /// In en, this message translates to:
  /// **'accounts channels login streaming'**
  String get settingsSearchConnectionWords;

  /// No description provided for @settingsSearchVoiceWords.
  ///
  /// In en, this message translates to:
  /// **'tts text to speech reader narration'**
  String get settingsSearchVoiceWords;

  /// No description provided for @settingsSearchCaptionWords.
  ///
  /// In en, this message translates to:
  /// **'subtitles transcription accessibility'**
  String get settingsSearchCaptionWords;

  /// No description provided for @settingsSearchBackupWords.
  ///
  /// In en, this message translates to:
  /// **'archive zip migration recovery'**
  String get settingsSearchBackupWords;

  /// No description provided for @settingsSearchMediaWords.
  ///
  /// In en, this message translates to:
  /// **'assets files mp3 mp4 images video sound'**
  String get settingsSearchMediaWords;

  /// No description provided for @settingsSearchAppearanceWords.
  ///
  /// In en, this message translates to:
  /// **'theme colors typography'**
  String get settingsSearchAppearanceWords;

  /// No description provided for @settingsSearchRulesWords.
  ///
  /// In en, this message translates to:
  /// **'automation webhook stream deck actions'**
  String get settingsSearchRulesWords;

  /// No description provided for @mediaSearch.
  ///
  /// In en, this message translates to:
  /// **'Search media by name'**
  String get mediaSearch;

  /// No description provided for @mediaNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching media'**
  String get mediaNoMatches;

  /// No description provided for @mediaPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get mediaPreview;

  /// No description provided for @mediaPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable for this file.'**
  String get mediaPreviewUnavailable;

  /// No description provided for @mediaPreviewPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get mediaPreviewPlay;

  /// No description provided for @mediaPreviewStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get mediaPreviewStop;

  /// No description provided for @mediaRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get mediaRename;

  /// No description provided for @mediaDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get mediaDisplayName;

  /// No description provided for @mediaRenameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name without slashes or control characters.'**
  String get mediaRenameInvalid;

  /// No description provided for @mediaRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the new name.'**
  String get mediaRenameFailed;
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

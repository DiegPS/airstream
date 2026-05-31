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
  /// **'Connect to OBS over WebSocket to show live status and the current program scene inside Airstream.'**
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

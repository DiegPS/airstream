part of 'package:airstream/ui/chat_screen.dart';

class _SettingsFormControllers {
  _SettingsFormControllers(SettingsModel settings)
      : ytHandle = TextEditingController(
          text: settings.youtubeLiveId.trim().isNotEmpty
              ? settings.youtubeLiveId.trim()
              : settings.youtubeHandle,
        ),
        ytHorizontalUrl =
            TextEditingController(text: settings.youtubeHorizontalUrl),
        ytVerticalUrl =
            TextEditingController(text: settings.youtubeVerticalUrl),
        twitch = TextEditingController(text: settings.twitchChannel),
        kick = TextEditingController(text: settings.kickSlug),
        port = TextEditingController(text: settings.overlayPort.toString()),
        obsHost = TextEditingController(text: settings.obsHost),
        obsPassword = TextEditingController(text: settings.obsPassword),
        overlayChromaColor =
            TextEditingController(text: settings.overlayChromaColor),
        overlayTextStrokeColor =
            TextEditingController(text: settings.overlayTextStrokeColor),
        overlaySuperChatBarColor =
            TextEditingController(text: settings.overlaySuperChatBarColor),
        ttsTest = TextEditingController(),
        ttsPrefix = TextEditingController(text: settings.ttsCommandPrefix),
        ttsSeparator = TextEditingController(text: settings.ttsSeparatorText),
        ttsReferenceText =
            TextEditingController(text: settings.ttsReferenceText),
        voiceWakeWord =
            TextEditingController(text: settings.voiceCommandsWakeWord),
        blockedUsers =
            TextEditingController(text: settings.blockedUsers.join('\n')),
        blockedWords =
            TextEditingController(text: settings.blockedWords.join('\n'));

  final TextEditingController ytHandle;
  final TextEditingController ytHorizontalUrl;
  final TextEditingController ytVerticalUrl;
  final TextEditingController twitch;
  final TextEditingController kick;
  final TextEditingController port;
  final TextEditingController obsHost;
  final TextEditingController obsPassword;
  final TextEditingController overlayChromaColor;
  final TextEditingController overlayTextStrokeColor;
  final TextEditingController overlaySuperChatBarColor;
  final TextEditingController ttsTest;
  final TextEditingController ttsPrefix;
  final TextEditingController ttsSeparator;
  final TextEditingController ttsReferenceText;
  final TextEditingController voiceWakeWord;
  final TextEditingController blockedUsers;
  final TextEditingController blockedWords;

  final FocusNode ytFocus = FocusNode();
  final FocusNode ytHorizontalFocus = FocusNode();
  final FocusNode ytVerticalFocus = FocusNode();
  final FocusNode twitchFocus = FocusNode();
  final FocusNode kickFocus = FocusNode();
  final FocusNode portFocus = FocusNode();
  final FocusNode obsHostFocus = FocusNode();
  final FocusNode obsPasswordFocus = FocusNode();
  final FocusNode overlayChromaColorFocus = FocusNode();
  final FocusNode overlayTextStrokeColorFocus = FocusNode();
  final FocusNode overlaySuperChatBarColorFocus = FocusNode();
  final FocusNode ttsPrefixFocus = FocusNode();
  final FocusNode ttsSeparatorFocus = FocusNode();
  final FocusNode ttsReferenceTextFocus = FocusNode();
  final FocusNode voiceWakeWordFocus = FocusNode();
  final FocusNode blockedUsersFocus = FocusNode();
  final FocusNode blockedWordsFocus = FocusNode();

  List<FocusNode> get focusNodes => [
        ytFocus,
        ytHorizontalFocus,
        ytVerticalFocus,
        twitchFocus,
        kickFocus,
        portFocus,
        obsHostFocus,
        obsPasswordFocus,
        overlayChromaColorFocus,
        overlayTextStrokeColorFocus,
        overlaySuperChatBarColorFocus,
        ttsPrefixFocus,
        ttsSeparatorFocus,
        ttsReferenceTextFocus,
        voiceWakeWordFocus,
        blockedUsersFocus,
        blockedWordsFocus,
      ];

  List<TextEditingController> get textControllers => [
        ytHandle,
        ytHorizontalUrl,
        ytVerticalUrl,
        twitch,
        kick,
        port,
        obsHost,
        obsPassword,
        overlayChromaColor,
        overlayTextStrokeColor,
        overlaySuperChatBarColor,
        ttsTest,
        ttsPrefix,
        ttsSeparator,
        ttsReferenceText,
        voiceWakeWord,
        blockedUsers,
        blockedWords,
      ];

  void dispose() {
    for (final node in focusNodes) {
      node.dispose();
    }
    for (final controller in textControllers) {
      controller.dispose();
    }
  }
}

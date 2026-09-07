import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizes corrupt values without discarding valid preferences', () {
    final restored = SettingsModel.fromJson({
      'appLanguageCode': 'fr',
      'youtubeHandle': '@still-valid',
      'youtubeEnabled': 'not-a-bool',
      'overlayPort': -20,
      'maxMessages': -5,
      'bgOpacity': 4.2,
      'chatTextAlign': 'diagonal',
      'overlayAnimation': 'explode',
      'overlayScale': 99,
      'blockedUsers': ['Nightbot', 42, null],
    });

    expect(restored.youtubeHandle, '@still-valid');
    expect(restored.youtubeEnabled, isTrue);
    expect(restored.appLanguageCode, 'en');
    expect(restored.overlayPort, 1);
    expect(restored.maxMessages, 1);
    expect(restored.bgOpacity, 1);
    expect(restored.chatTextAlign, 'left');
    expect(restored.overlayAnimation, 'slide-up');
    expect(restored.overlayScale, 3);
    expect(restored.blockedUsers, ['Nightbot']);
  });

  test('uses safe defaults for a non-object settings payload', () {
    expect(SettingsModel.fromJsonString('[]').overlayEnabled, isFalse);
  });

  test('new installations keep the overlay disabled', () {
    expect(const SettingsModel().overlayEnabled, isFalse);
  });

  test('legacy settings without an overlay flag preserve the old default', () {
    expect(SettingsModel.fromJson(const {}).overlayEnabled, isTrue);
  });

  test('persists per-platform chat enablement', () {
    const settings = SettingsModel(
      youtubeEnabled: false,
      twitchEnabled: true,
      kickEnabled: false,
    );

    final restored = SettingsModel.fromJsonString(settings.toJsonString());

    expect(restored.youtubeEnabled, isFalse);
    expect(restored.twitchEnabled, isTrue);
    expect(restored.kickEnabled, isFalse);
  });

  test('persists YouTube horizontal and vertical mode', () {
    const settings = SettingsModel(
      youtubeDualStreamEnabled: true,
      youtubeHorizontalUrl: 'https://youtube.com/watch?v=dQw4w9WgXcQ',
      youtubeVerticalUrl: 'https://youtu.be/aqz-KE-bpKQ',
      showYoutubeStreamBadges: false,
      overlayShowYoutubeStreamBadges: false,
    );

    final restored = SettingsModel.fromJsonString(settings.toJsonString());

    expect(restored.youtubeDualStreamEnabled, isTrue);
    expect(restored.youtubeHorizontalUrl, settings.youtubeHorizontalUrl);
    expect(restored.youtubeVerticalUrl, settings.youtubeVerticalUrl);
    expect(restored.showYoutubeStreamBadges, isFalse);
    expect(restored.overlayShowYoutubeStreamBadges, isFalse);
  });

  test('persists local chat appearance settings', () {
    const settings = SettingsModel(
      chatTextAlign: 'right',
      chatMaxMessageWidth: 0.65,
      chatHorizontalPadding: 18,
      chatLineHeight: 1.25,
      chatFontWeight: 600,
      chatTextShadow: true,
      chatTextStroke: 1.5,
    );

    final restored = SettingsModel.fromJsonString(settings.toJsonString());

    expect(restored.chatTextAlign, 'right');
    expect(restored.chatMaxMessageWidth, 0.65);
    expect(restored.chatHorizontalPadding, 18);
    expect(restored.chatLineHeight, 1.25);
    expect(restored.chatFontWeight, 600);
    expect(restored.chatTextShadow, isTrue);
    expect(restored.chatTextStroke, 1.5);
  });

  test('persists and sanitizes provider event banner preferences', () {
    const settings = SettingsModel(
      providerEventBannerKinds: ['raid', 'support'],
      providerEventBannerSeconds: 12,
    );

    final restored = SettingsModel.fromJsonString(settings.toJsonString());
    final corrupt = SettingsModel.fromJson({
      'providerEventBannerKinds': ['poll', 'not-a-real-event', 42],
      'providerEventBannerSeconds': 999,
    });

    expect(restored.providerEventBannerKinds, ['raid', 'support']);
    expect(restored.providerEventBannerSeconds, 12);
    expect(corrupt.providerEventBannerKinds, ['poll']);
    expect(corrupt.providerEventBannerSeconds, 60);
  });

  test('persists OBS recording HUD settings', () {
    const settings = SettingsModel(
      obsShowRecordingState: false,
      obsShowRecordingDuration: false,
      obsShowRecordingSize: true,
    );

    final restored = SettingsModel.fromJsonString(settings.toJsonString());

    expect(restored.obsShowRecordingState, isFalse);
    expect(restored.obsShowRecordingDuration, isFalse);
    expect(restored.obsShowRecordingSize, isTrue);
  });

  test('never serializes the OBS password into ordinary preferences', () {
    const settings = SettingsModel(obsPassword: 'do-not-store-in-json');

    expect(settings.toJson(), isNot(contains('obsPassword')));
    expect(settings.toJsonString(), isNot(contains('do-not-store-in-json')));
  });

  test('still reads an OBS password from legacy preferences for migration', () {
    final restored = SettingsModel.fromJson(const {
      'obsPassword': 'legacy-password',
    });

    expect(restored.obsPassword, 'legacy-password');
  });

  test('uses practical OBS recording HUD defaults for older settings', () {
    final restored = SettingsModel.fromJson(const {});

    expect(restored.obsShowRecordingState, isTrue);
    expect(restored.obsShowRecordingDuration, isTrue);
    expect(restored.obsShowRecordingSize, isFalse);
  });

  test('persists TTS command case sensitivity setting', () {
    const settings = SettingsModel(ttsCommandIgnoreCase: false);

    final restored = SettingsModel.fromJsonString(settings.toJsonString());

    expect(restored.ttsCommandIgnoreCase, isFalse);
    expect(SettingsModel.fromJson(const {}).ttsCommandIgnoreCase, isTrue);
  });

  test('uses a neutral TTS command prefix and localized separator fallback',
      () {
    const settings = SettingsModel();
    final restored = SettingsModel.fromJson(const {});

    expect(settings.ttsCommandPrefix, '!v');
    expect(settings.ttsSeparatorText, isEmpty);
    expect(restored.ttsCommandPrefix, '!v');
    expect(restored.ttsSeparatorText, isEmpty);
  });

  test('persists the complete Sherpa TTS configuration', () {
    const settings = SettingsModel(
      ttsModelId: 'piper-es-sharvard-medium',
      ttsVoice: 'speaker-1',
      ttsLanguage: 'es',
      ttsSpeed: 1.25,
      ttsSteps: 12,
      ttsReferenceAudioPath: r'C:\voice\reference.wav',
      ttsReferenceText: 'Exact reference words.',
      liveCaptionsEnabled: true,
      liveCaptionsSourceLanguage: 'es',
      liveCaptionsTargetLanguage: 'en',
      liveCaptionsOverlayEnabled: false,
      liveCaptionsDenoiseEnabled: false,
      voiceCommandsEnabled: true,
      voiceCommandsWakeWord: 'computadora',
    );

    final restored = SettingsModel.fromJsonString(settings.toJsonString());

    expect(restored.ttsModelId, 'piper-es-sharvard-medium');
    expect(restored.ttsVoice, 'speaker-1');
    expect(restored.ttsLanguage, 'es');
    expect(restored.ttsSpeed, 1.25);
    expect(restored.ttsSteps, 12);
    expect(restored.ttsReferenceAudioPath, r'C:\voice\reference.wav');
    expect(restored.ttsReferenceText, 'Exact reference words.');
    expect(restored.liveCaptionsEnabled, isTrue);
    expect(restored.liveCaptionsSourceLanguage, 'es');
    expect(restored.liveCaptionsTargetLanguage, 'en');
    expect(restored.liveCaptionsOverlayEnabled, isFalse);
    expect(restored.liveCaptionsDenoiseEnabled, isFalse);
    expect(restored.voiceCommandsEnabled, isTrue);
    expect(restored.voiceCommandsWakeWord, 'computadora');
  });
}

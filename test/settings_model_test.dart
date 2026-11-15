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
    expect(restored.overlayScale, 2);
    expect(restored.blockedUsers, ['Nightbot']);
  });

  test('slider extremes survive a save and reload unchanged', () {
    const extremes = SettingsModel(
      overlayPerspective: 2500,
      overlayScale: 0.5,
      overlaySkewX: -45,
      ttsSpeed: 1.6,
      overlayMessageTtlSeconds: 120,
      alertFontSize: 56,
      chatHorizontalPadding: 64,
    );

    final reloaded = SettingsModel.fromJson(extremes.toJson());

    expect(reloaded.overlayPerspective, 2500);
    expect(reloaded.overlayScale, 0.5);
    expect(reloaded.overlaySkewX, -45);
    expect(reloaded.ttsSpeed, 1.6);
    expect(reloaded.overlayMessageTtlSeconds, 120);
    expect(reloaded.alertFontSize, 56);
    expect(reloaded.chatHorizontalPadding, 64);
  });

  test('stored values outside a slider are brought into its range', () {
    final restored = SettingsModel.fromJson({
      'ttsSpeed': 2.0,
      'overlayFontSize': 72,
      'overlayMessageTtlSeconds': 3600,
      'overlayPerspective': 100,
    });

    expect(restored.ttsSpeed, 1.6);
    expect(restored.overlayFontSize, 32);
    expect(restored.overlayMessageTtlSeconds, 120);
    expect(restored.overlayPerspective, 500);
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
    expect(corrupt.providerEventBannerSeconds, 20);
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

  test('voice reader limits survive a save and stay in range', () {
    const settings = SettingsModel(
      ttsUserCooldownSeconds: 15,
      ttsIgnoredUsers: ['nightbot'],
      ttsMaxCharacters: 120,
    );
    final restored = SettingsModel.fromJsonString(settings.toJsonString());
    expect(restored.ttsUserCooldownSeconds, 15);
    expect(restored.ttsIgnoredUsers, ['nightbot']);
    expect(restored.ttsMaxCharacters, 120);

    final clamped = SettingsModel.fromJson({
      'ttsUserCooldownSeconds': 500,
      'ttsMaxCharacters': 5,
    });
    expect(clamped.ttsUserCooldownSeconds, 60);
    expect(clamped.ttsMaxCharacters, 40);
    expect(const SettingsModel().ttsUserCooldownSeconds, 0,
        reason: 'off by default: reading stays as before');
    expect(const SettingsModel().ttsMaxCharacters, ttsMaxCharactersLimit);
  });

  test('disabled alert types persist, sanitize entries and default to empty',
      () {
    const defaults = SettingsModel();
    expect(defaults.alertDisabledTypes, isEmpty);
    expect(SettingsModel.fromJson(const {}).alertDisabledTypes, isEmpty);
    final settings =
        defaults.copyWith(alertDisabledTypes: ['raid', 'bits', 'future']);
    final restored = SettingsModel.fromJsonString(settings.toJsonString());
    expect(restored.alertDisabledTypes, ['raid', 'bits', 'future']);
    expect(
        SettingsModel.fromJson({
          'alertDisabledTypes': ['gift', 42, null, false, 'unknown'],
        }).alertDisabledTypes,
        ['gift', 'unknown']);
  });
  test('alert appearance defaults, validation and persistence', () {
    const defaults = SettingsModel();
    expect(defaults.alertPosition, 'center');
    expect(defaults.alertLayout, 'row');
    expect(defaults.alertAnimation, 'pop');
    expect(defaults.alertTypeOptions, isEmpty);
    for (final invalid in [null, 42, [], {}, 'unknown']) {
      final s = SettingsModel.fromJson({
        'alertPosition': invalid,
        'alertLayout': invalid,
        'alertAnimation': invalid
      });
      expect(s.alertPosition, 'center');
      expect(s.alertLayout, 'row');
      expect(s.alertAnimation, 'pop');
    }
    for (final position in ['top', 'center', 'bottom']) {
      for (final layout in ['row', 'stacked']) {
        for (final animation in [
          'pop',
          'slide-up',
          'slide-down',
          'fade',
          'zoom'
        ]) {
          final s = defaults.copyWith(
              alertPosition: position,
              alertLayout: layout,
              alertAnimation: animation);
          final restored = SettingsModel.fromJsonString(s.toJsonString());
          expect(restored.alertPosition, position);
          expect(restored.alertLayout, layout);
          expect(restored.alertAnimation, animation);
        }
      }
    }
  });
  test('alert sound volume defaults, persists and clamps', () {
    expect(const SettingsModel().alertSoundVolume, 70);
    for (final (raw, expected) in [(-1, 0), (101, 100), (42, 42)]) {
      final s = SettingsModel.fromJson({'alertSoundVolume': raw});
      expect(s.alertSoundVolume, expected);
      expect(SettingsModel.fromJsonString(s.toJsonString()).alertSoundVolume,
          expected);
    }
    expect(
        const SettingsModel().copyWith(alertSoundVolume: 25).alertSoundVolume,
        25);
  });
}

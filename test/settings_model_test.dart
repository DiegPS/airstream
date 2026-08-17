import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('persists the complete Sherpa TTS configuration', () {
    const settings = SettingsModel(
      ttsModelId: 'piper-es-sharvard-medium',
      ttsVoice: 'speaker-1',
      ttsLanguage: 'es',
      ttsSpeed: 1.25,
      ttsSteps: 12,
    );

    final restored = SettingsModel.fromJsonString(settings.toJsonString());

    expect(restored.ttsModelId, 'piper-es-sharvard-medium');
    expect(restored.ttsVoice, 'speaker-1');
    expect(restored.ttsLanguage, 'es');
    expect(restored.ttsSpeed, 1.25);
    expect(restored.ttsSteps, 12);
  });
}

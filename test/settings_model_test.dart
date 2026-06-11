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
}

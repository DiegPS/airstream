import 'package:airstream/application/name_colors.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/name_color_mode.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(
  Platform platform, {
  String name = 'Alex',
  String id = '',
  String? color,
  bool owner = false,
  bool moderator = false,
  bool vip = false,
}) =>
    ChatMessage(
      platform: platform,
      id: 'message',
      author: ChatAuthor(name: name, channelId: id, color: color),
      items: const [MessageItem.text('Hello')],
      isOwner: owner,
      isModerator: moderator,
      isVip: vip,
      timestamp: DateTime.utc(2026),
    );

String _color(ChatMessage message, [SettingsModel s = const SettingsModel()]) =>
    nameColorHex(resolveNameColor(message, s));

void main() {
  test('platform mode keeps supplied colors and platform fallbacks', () {
    expect(_color(_message(Platform.youtube)), '#FFFFFF');
    expect(_color(_message(Platform.twitch)), '#AF84FF');
    expect(_color(_message(Platform.kick)), '#B7FF8D');
    expect(_color(_message(Platform.twitch, color: '#89ABCD')), '#89ABCD');
  });

  test('roles win in every mode, including overlapping roles', () {
    for (final mode in NameColorMode.values) {
      final s = SettingsModel(
        nameColorMode: mode,
        overlayChromaMode: true,
        overlayChromaColor: '#FFFF00',
      );
      expect(
          _color(
              _message(Platform.youtube,
                  owner: true, moderator: true, vip: true, color: '#123456'),
              s),
          '#FFD700');
      expect(
          _color(
              _message(Platform.twitch,
                  moderator: true, vip: true, color: '#123456'),
              s),
          '#7EA4FF');
      expect(_color(_message(Platform.kick, vip: true, color: '#123456'), s),
          '#FF69D4');
      expect(
        _color(
            _message(Platform.youtube,
                owner: true, moderator: true, vip: true, color: '#89ABCD'),
            s.copyWith(nameRoleColors: false)),
        _color(_message(Platform.youtube, color: '#89ABCD'), s),
      );
    }
  });

  test('generated colors are stable by platform, normalized name and ID', () {
    const generated = SettingsModel(nameColorMode: NameColorMode.generated);
    expect(_color(_message(Platform.youtube), generated), '#AF84FF');
    expect(
        _color(_message(Platform.youtube, name: 'aLEX'), generated), '#AF84FF');
    expect(
        _color(_message(Platform.twitch, name: 'Sam'), generated), '#FF8A80');
    expect(
        _color(_message(Platform.youtube, name: 'Sam'), generated), '#96B7FF');
    expect(_color(_message(Platform.kick, name: 'Luz'), generated), '#96B7FF');
    expect(_color(_message(Platform.kick, id: 'User42'), generated), '#FF9FEE');
    expect(
      _color(
          _message(Platform.kick,
              id: 'User42', name: 'Renamed', color: '#89ABCD'),
          generated),
      '#FF9FEE',
    );
  });

  test('platform then generated uses a supplied color when available', () {
    const s = SettingsModel(nameColorMode: NameColorMode.platformThenGenerated);
    expect(_color(_message(Platform.youtube), s), '#AF84FF');
    expect(_color(_message(Platform.youtube, color: '#89ABCD'), s), '#89ABCD');
  });

  test('single and brand modes ignore supplied colors', () {
    const single = SettingsModel(
      nameColorMode: NameColorMode.single,
      nameColorSingle: '#FF8800',
    );
    const brand = SettingsModel(nameColorMode: NameColorMode.brand);
    for (final (platform, brandColor) in [
      (Platform.youtube, '#FF4E45'),
      (Platform.twitch, '#A970FF'),
      (Platform.kick, '#53FC18'),
    ]) {
      final message = _message(platform, color: '#89ABCD');
      expect(_color(message, single), '#FF8800');
      expect(_color(message, brand), brandColor);
    }
  });

  test('readability lightens to 3:1 over the bubble and leaves good colors',
      () {
    final message = _message(Platform.youtube, color: '#08002B');
    const s = SettingsModel(bgOpacity: 1, messageOpacity: 1);
    final background = chatBubbleBackground(message, s).computeLuminance();
    final original =
        resolveNameColor(message, s.copyWith(nameReadability: false));
    final adjusted = resolveNameColor(message, s);
    expect(nameColorHex(original), '#08002B');
    expect(
        adjusted.computeLuminance(), greaterThan(original.computeLuminance()));
    expect((adjusted.computeLuminance() + 0.05) / (background + 0.05),
        greaterThanOrEqualTo(3));
    expect(_color(_message(Platform.youtube, color: '#C6AFCC'), s), '#C6AFCC');
  });

  test(
      'one color reaches 3:1 on the app bubble and over black, ignoring the keyed-out chroma',
      () {
    const s = SettingsModel(
      overlayChromaMode: true,
      overlayChromaColor: '#007700',
      overlayShowBubble: false,
      messageOpacity: 1,
    );
    final message = _message(Platform.youtube, color: '#202020');
    final luminance = resolveNameColor(message, s).computeLuminance();
    for (final background in [
      chatBubbleBackground(message, s),
      // OBS removes the chroma color; the page estimate is over black.
      const Color(0xFF000000),
    ]) {
      expect((luminance + 0.05) / (background.computeLuminance() + 0.05),
          greaterThanOrEqualTo(3));
    }
  });
}

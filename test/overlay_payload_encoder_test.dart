import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay/overlay_payload_encoder.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlay settings payload never exposes application secrets', () {
    const settings = SettingsModel(
      obsPassword: 'top-secret',
      obsHost: 'private-host:4455',
      twitchChannel: 'private-channel',
      overlayFontSize: 27,
    );

    final payload = OverlayPayloadEncoder.settings(settings);

    expect(payload['fontSize'], 27);
    expect(payload.keys, isNot(contains('obsPassword')));
    expect(payload.keys, isNot(contains('obsHost')));
    expect(payload.keys, isNot(contains('twitchChannel')));
    expect(payload.values, isNot(contains('top-secret')));
  });

  test('overlay message payload preserves identity and structured content', () {
    final message = ChatMessage(
      platform: Platform.youtube,
      id: 'message-id',
      author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
      items: const [
        MessageItem.text('Hola '),
        MessageItem.emoji(EmojiItem(url: 'https://emoji', alt: ':wave:')),
      ],
      timestamp: DateTime.utc(2026, 9, 6),
    );

    final payload = OverlayPayloadEncoder.message(message);

    expect(payload['id'], 'message-id');
    expect(payload['text'], 'Hola :wave:');
    expect(payload['items'], hasLength(2));
  });
}

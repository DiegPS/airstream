import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
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
        MessageItem.emoji(
          EmojiItem(
            url: 'https://emoji',
            alt: ':wave:',
            isZeroWidth: true,
          ),
        ),
      ],
      membershipGiftCount: 5,
      reply: const ChatReplyContext(
        messageId: 'parent',
        authorName: 'Luis',
        text: 'Pregunta',
      ),
      sharedSource: const ChatSharedSource(
        messageId: 'source-message',
        channelId: 'shared-channel',
        messageType: 'chat',
        badges: {'vip': '1'},
        badgeInfo: {'subscriber': '5'},
        sourceOnly: true,
      ),
      isAction: true,
      providerRoomId: 'room-1',
      isFirstMessage: true,
      isReturningChatter: true,
      rewardId: 'reward-42',
      timestamp: DateTime.utc(2026, 9, 6),
    );

    final payload = OverlayPayloadEncoder.message(message);

    expect(payload['id'], 'message-id');
    expect(payload['text'], 'Hola :wave:');
    expect(payload['items'], hasLength(2));
    expect((payload['items'] as List)[1]['isZeroWidth'], isTrue);
    expect(payload['membershipGiftCount'], 5);
    expect((payload['reply'] as Map)['messageId'], 'parent');
    expect((payload['sharedSource'] as Map)['channelId'], 'shared-channel');
    expect(payload['isAction'], isTrue);
    expect(payload['providerRoomId'], 'room-1');
    expect(payload['isFirstMessage'], isTrue);
    expect(payload['isReturningChatter'], isTrue);
    expect(payload['rewardId'], 'reward-42');
    expect(payload['sharedSource'], {
      'messageId': 'source-message',
      'channelId': 'shared-channel',
      'messageType': 'chat',
      'badges': {'vip': '1'},
      'badgeInfo': {'subscriber': '5'},
      'sourceOnly': true,
    });
  });

  test('encodes moderation without losing its stream scope', () {
    const event = ChatModerationEvent.message(
      platform: Platform.youtube,
      messageId: 'deleted',
      youtubeStreamOrientation: YoutubeStreamOrientation.vertical,
    );

    expect(OverlayPayloadEncoder.moderation(event), {
      'platform': 'youtube',
      'scope': 'message',
      'messageId': 'deleted',
      'authorChannelId': '',
      'youtubeStreamOrientation': 'vertical',
    });
  });

  test('encodes provider events and their lossless data', () {
    final event = ChatProviderEvent(
      platform: Platform.twitch,
      kind: ChatProviderEventKind.roomState,
      id: 'roomstate:1',
      timestamp: DateTime.utc(2026, 9, 7),
      data: const {'slowModeSeconds': 5},
    );

    final payload = OverlayPayloadEncoder.providerEvent(event);
    expect(payload['kind'], 'roomState');
    expect((payload['data'] as Map)['slowModeSeconds'], 5);
  });
}

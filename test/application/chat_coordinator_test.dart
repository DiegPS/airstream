import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_fakes.dart';

void main() {
  late FakeYouTubeChatClient youtube;
  late FakeYouTubeChatClient horizontal;
  late FakeYouTubeChatClient vertical;
  late FakeChannelChatClient kick;
  late FakeChannelChatClient twitch;
  late ChatCoordinator coordinator;

  setUp(() {
    youtube = FakeYouTubeChatClient();
    horizontal = FakeYouTubeChatClient();
    vertical = FakeYouTubeChatClient();
    kick = FakeChannelChatClient();
    twitch = FakeChannelChatClient();
    coordinator = ChatCoordinator(
      youtube: youtube,
      youtubeHorizontal: horizontal,
      youtubeVertical: vertical,
      kick: kick,
      twitch: twitch,
    );
  });

  tearDown(() => coordinator.dispose());

  test('connects once, reconnects an errored service, and applies changes',
      () async {
    const initial = SettingsModel(
      twitchEnabled: true,
      twitchChannel: 'first',
    );
    coordinator.applySettings(initial, connectChats: true);
    await settleCoordinatorTasks();
    expect(twitch.connectCount, 1);
    expect(twitch.lastChannel, 'first');

    coordinator.applySettings(initial, connectChats: true);
    await settleCoordinatorTasks();
    expect(twitch.connectCount, 1);

    twitch.statusController.add((ServiceStatus.error, 'network'));
    coordinator.retryConnections();
    await settleCoordinatorTasks();
    expect(twitch.connectCount, 2);

    coordinator.applySettings(
      initial.copyWith(twitchChannel: 'second'),
      connectChats: true,
    );
    await settleCoordinatorTasks();
    expect(twitch.connectCount, 3);
    expect(twitch.lastChannel, 'second');
  });

  test('publishes connection failures and deduplicates source messages',
      () async {
    twitch.connectError = StateError('offline');
    final failure = coordinator.connectionStatusStream.firstWhere(
      (statuses) => statuses['twitch']?.$1 == ServiceStatus.error,
    );
    coordinator.applySettings(
      const SettingsModel(twitchEnabled: true, twitchChannel: 'channel'),
      connectChats: true,
    );
    expect((await failure)['twitch']?.$2, contains('offline'));

    final lists = <List<ChatMessage>>[];
    final subscription = coordinator.messageListStream.listen(lists.add);
    final message = ChatMessage(
      platform: Platform.twitch,
      id: 'same-id',
      author: const ChatAuthor(name: 'Author', channelId: 'author'),
      items: const [MessageItem.text('hello')],
      timestamp: DateTime.now().toUtc(),
    );
    twitch.messageController.add(message);
    twitch.messageController.add(message);
    await settleCoordinatorTasks();
    expect(lists.last, hasLength(1));
    expect(lists.where((messages) => messages.isNotEmpty), hasLength(1));
    await subscription.cancel();
  });

  test('disposes every owned dependency exactly once', () async {
    await coordinator.dispose();
    await coordinator.dispose();
    expect(youtube.disposed, isTrue);
    expect(horizontal.disposed, isTrue);
    expect(vertical.disposed, isTrue);
    expect(kick.disposed, isTrue);
    expect(twitch.disposed, isTrue);
  });

  test('aggregates horizontal and vertical YouTube audiences', () async {
    final summaryFuture = coordinator.youtubeMetadataStream.firstWhere(
      (summary) => summary.totalViewerCount == 1750,
    );

    horizontal.metadataController.add(const YoutubeLiveMetadata(
      liveId: 'horizontal-id',
      streamOrientation: YoutubeStreamOrientation.horizontal,
      viewerCount: 1200,
      title: 'Horizontal',
    ));
    vertical.metadataController.add(const YoutubeLiveMetadata(
      liveId: 'vertical-id',
      streamOrientation: YoutubeStreamOrientation.vertical,
      viewerCount: 550,
      title: 'Vertical',
    ));

    final summary = await summaryFuture;
    expect(summary.horizontal?.viewerCount, 1200);
    expect(summary.vertical?.viewerCount, 550);
    expect(summary.totalViewerCount, 1750);
  });

  test('removes moderated YouTube messages from the matching broadcast',
      () async {
    final timestamp = DateTime.utc(2026, 9, 6);
    horizontal.messageController.add(ChatMessage(
      platform: Platform.youtube,
      id: 'same-id',
      author: const ChatAuthor(name: 'Author', channelId: 'author'),
      items: const [MessageItem.text('Horizontal')],
      youtubeStreamOrientation: YoutubeStreamOrientation.horizontal,
      timestamp: timestamp,
    ));
    vertical.messageController.add(ChatMessage(
      platform: Platform.youtube,
      id: 'same-id',
      author: const ChatAuthor(name: 'Author', channelId: 'author'),
      items: const [MessageItem.text('Vertical')],
      youtubeStreamOrientation: YoutubeStreamOrientation.vertical,
      timestamp: timestamp,
    ));
    await settleCoordinatorTasks();

    final updated = coordinator.messageListStream.firstWhere(
      (messages) => messages.length == 1,
    );
    horizontal.moderationController.add(const ChatModerationEvent.message(
      platform: Platform.youtube,
      messageId: 'same-id',
      youtubeStreamOrientation: YoutubeStreamOrientation.horizontal,
    ));

    final messages = await updated;
    expect(messages.single.plainText, 'Vertical');
  });

  test('applies Twitch moderation without affecting other providers', () async {
    final timestamp = DateTime.utc(2026, 9, 6);
    twitch.messageController.add(ChatMessage(
      platform: Platform.twitch,
      id: 'twitch-message',
      author: const ChatAuthor(name: 'Author', channelId: 'author-id'),
      items: const [MessageItem.text('Twitch')],
      timestamp: timestamp,
    ));
    kick.messageController.add(ChatMessage(
      platform: Platform.kick,
      id: 'kick-message',
      author: const ChatAuthor(name: 'Author', channelId: 'author-id'),
      items: const [MessageItem.text('Kick')],
      timestamp: timestamp,
    ));
    await settleCoordinatorTasks();

    final updated = coordinator.messageListStream.firstWhere(
      (messages) => messages.length == 1,
    );
    twitch.moderationController.add(
      const ChatModerationEvent.platform(platform: Platform.twitch),
    );

    final messages = await updated;
    expect(messages.single.id, 'kick-message');
  });

  test('applies Kick moderation through the common pipeline', () async {
    kick.messageController.add(ChatMessage(
      platform: Platform.kick,
      id: 'kick-message',
      author: const ChatAuthor(name: 'Author', channelId: 'author-id'),
      items: const [MessageItem.text('Kick')],
      timestamp: DateTime.utc(2026, 9, 7),
    ));
    await settleCoordinatorTasks();
    final updated = coordinator.messageListStream.firstWhere(
      (messages) => messages.isEmpty,
    );

    kick.moderationController.add(const ChatModerationEvent.author(
      platform: Platform.kick,
      authorChannelId: 'author-id',
    ));

    expect(await updated, isEmpty);
  });

  test('forwards moderation even when the target is no longer buffered',
      () async {
    final forwarded = coordinator.moderationEvents.first;
    const event = ChatModerationEvent.message(
      platform: Platform.twitch,
      messageId: 'already-gone',
    );

    twitch.moderationController.add(event);

    expect(await forwarded, same(event));
  });

  test('forwards common provider events and live platform metadata', () async {
    final eventFuture = coordinator.providerEvents.first;
    final metadataFuture = coordinator.platformMetadataStream.firstWhere(
      (values) => values[Platform.kick]?.viewerCount == 84,
    );
    final now = DateTime.utc(2026, 9, 7);

    twitch.eventController.add(ChatProviderEvent(
      platform: Platform.twitch,
      kind: ChatProviderEventKind.raid,
      id: 'raid-1',
      timestamp: now,
      count: 42,
    ));
    kick.platformMetadataController.add(PlatformLiveMetadata(
      platform: Platform.kick,
      channel: 'creator',
      isLive: true,
      viewerCount: 84,
      title: 'Live',
      updatedAt: now,
    ));

    expect((await eventFuture).kind, ChatProviderEventKind.raid);
    expect((await metadataFuture)[Platform.kick]?.viewerCount, 84);
  });
}

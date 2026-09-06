import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
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
}

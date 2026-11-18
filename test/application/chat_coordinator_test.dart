import 'dart:async';

import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_fakes.dart';
import '../chat_queue_test.dart' show queueMessage;
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';

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
      youtubeLiveRetryInterval: const Duration(milliseconds: 20),
    );
  });

  tearDown(() => coordinator.dispose());

  test('a stale channel failure leaves the replacement connected', () async {
    final oldAttempt = Completer<void>();
    twitch.connectGate = oldAttempt;
    const settings = SettingsModel(twitchEnabled: true, twitchChannel: 'old');
    coordinator.applySettings(settings, connectChats: true);
    twitch.connectGate = null;
    coordinator.applySettings(settings.copyWith(twitchChannel: 'replacement'),
        connectChats: true);
    twitch.statusController.add((ServiceStatus.connected, null));
    expect(twitch.lastChannel, 'replacement');
    final disconnects = twitch.disconnectCount;

    oldAttempt.completeError(StateError('obsolete connection failed'));
    await Future<void>.delayed(Duration.zero);

    expect(twitch.disconnectCount, disconnects);
    final statuses = await coordinator.connectionStatusStream.first;
    expect(statuses['twitch']?.$1, ServiceStatus.connected);
  });

  test('channel changes preserve first-message tracking until chat restarts',
      () async {
    const settings = SettingsModel(twitchEnabled: true, twitchChannel: 'first');
    final messages = <ChatMessage>[];
    final subscription = coordinator.messages.listen(messages.add);
    addTearDown(subscription.cancel);
    coordinator.applySettings(settings, connectChats: true);
    twitch.messageController.add(queueMessage('Viewer', 'first', id: 'viewer'));
    await settleCoordinatorTasks();
    coordinator.applySettings(settings.copyWith(twitchChannel: 'second'),
        connectChats: true);
    twitch.messageController
        .add(queueMessage('Viewer', 'second', id: 'viewer'));
    await settleCoordinatorTasks();
    coordinator.applySettings(settings, connectChats: false);
    coordinator.applySettings(settings, connectChats: true);
    twitch.messageController.add(queueMessage('Viewer', 'third', id: 'viewer'));
    await settleCoordinatorTasks();
    expect(messages.map((message) => message.isFirstInSession),
        [true, false, true]);
  });

  test('invalid dual YouTube ignores late statuses and cannot retry', () async {
    const settings = SettingsModel(
      youtubeEnabled: true,
      youtubeDualStreamEnabled: true,
      youtubeHorizontalUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
      youtubeVerticalUrl: 'https://youtu.be/abcdefghijk',
    );
    coordinator.applySettings(settings, connectChats: true);
    horizontal.statusController.add((ServiceStatus.connecting, null));
    vertical.statusController.add((ServiceStatus.error, 'late failure'));
    coordinator.retryPlatform('youtubeHorizontal');
    coordinator.retryPlatform('youtubeVertical');
    coordinator.retryConnections();

    final statuses = await coordinator.connectionStatusStream.first;
    expect(statuses['youtubeHorizontal'], (ServiceStatus.idle, null));
    expect(statuses['youtubeVertical'], (ServiceStatus.idle, null));
    expect((horizontal.connectCount, vertical.connectCount), (0, 0));
  });

  test('dual YouTube waits and retries each pending broadcast independently',
      () {
    fakeAsync((fake) {
      horizontal.connectError =
          vertical.connectError = StateError('Live stream was not found');
      const settings = SettingsModel(
        youtubeEnabled: true,
        youtubeDualStreamEnabled: true,
        youtubeHorizontalUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
        youtubeVerticalUrl: 'https://www.youtube.com/watch?v=lmnopqrstuv',
      );
      coordinator.applySettings(settings, connectChats: true);
      fake.flushMicrotasks();
      expect((horizontal.connectCount, vertical.connectCount), (1, 1));

      horizontal.connectError = null;
      fake.elapse(const Duration(milliseconds: 20));
      expect((horizontal.connectCount, vertical.connectCount), (2, 2));
      vertical.connectError = null;
      fake.elapse(const Duration(milliseconds: 20));
      expect((horizontal.connectCount, vertical.connectCount), (2, 3));
      expect(youtube.connectCount, 0);
      coordinator.applySettings(settings, connectChats: false);
      fake.flushMicrotasks();
    });
  });

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

  test('changing another platform keeps the in-flight YouTube result',
      () async {
    final gate = Completer<void>();
    youtube.connectGate = gate;
    final badges = <String?>[];
    final sub = coordinator.youtubeBadgeValueStream.listen(badges.add);
    addTearDown(sub.cancel);
    const settings = SettingsModel(
      youtubeEnabled: true,
      youtubeHandle: '@creator',
      kickEnabled: true,
      kickSlug: 'kicker',
    );
    coordinator.applySettings(settings, connectChats: true);
    await settleCoordinatorTasks();

    // While YouTube is still looking up the stream, Twitch is added and Kick
    // is retried.
    coordinator.applySettings(
      settings.copyWith(twitchEnabled: true, twitchChannel: 'twitcher'),
      connectChats: true,
    );
    coordinator.retryPlatform('kick');
    gate.complete();
    await settleCoordinatorTasks();

    expect(badges.last, 'resolved-id');
  });

  test('a YouTube failure is still shown after another platform changes',
      () async {
    final gate = Completer<void>();
    youtube
      ..connectGate = gate
      ..connectError = Exception('stream offline');
    const settings = SettingsModel(
      youtubeEnabled: true,
      youtubeHandle: '@creator',
    );
    coordinator.applySettings(settings, connectChats: true);
    await settleCoordinatorTasks();

    coordinator.applySettings(
      settings.copyWith(kickEnabled: true, kickSlug: 'kicker'),
      connectChats: true,
    );
    gate.complete();
    await settleCoordinatorTasks();

    final statuses = await coordinator.connectionStatusStream.first;
    expect(statuses['youtube']?.$1, ServiceStatus.error);
    expect(statuses['youtube']?.$2, contains('stream offline'));
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

  test('waits for a YouTube channel that is not live yet', () async {
    final statuses = <(ServiceStatus, String?)>[];
    final subscription = coordinator.connectionStatusStream.listen(
      (all) {
        final youtubeStatus = all['youtube'];
        if (youtubeStatus != null) statuses.add(youtubeStatus);
      },
    );
    addTearDown(subscription.cancel);
    youtube.connectError = Exception('Live stream was not found');

    coordinator.applySettings(
      const SettingsModel(youtubeHandle: '@creator'),
      connectChats: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(
        statuses.last, (ServiceStatus.connecting, youtubeWaitingForLiveStatus));
    expect(statuses.map((status) => status.$1),
        isNot(contains(ServiceStatus.error)));

    // Keeps checking, and connects once the stream starts.
    youtube.connectError = null;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(youtube.connectCount, greaterThanOrEqualTo(2));
    final retries = youtube.connectCount;

    // Stopping the chat stops the checks.
    youtube.connectError = Exception('Live stream was not found');
    coordinator.applySettings(
      const SettingsModel(youtubeHandle: '@creator'),
      connectChats: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(youtube.connectCount, retries);
  });
}

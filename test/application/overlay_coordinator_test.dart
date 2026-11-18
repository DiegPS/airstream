import 'dart:async';

import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';

import 'coordinator_fakes.dart';

void main() {
  late FakeOverlayClient overlay;
  late OverlayCoordinator coordinator;
  late Stream<ChatMessage> messages;

  setUp(() {
    overlay = FakeOverlayClient();
    coordinator = OverlayCoordinator(overlay: overlay);
    messages = const Stream<ChatMessage>.empty();
  });

  tearDown(() => coordinator.dispose());

  test('starts once, updates settings, and restarts after a port change',
      () async {
    const initial = SettingsModel(overlayEnabled: true, overlayPort: 8080);
    coordinator.applySettings(initial, previous: null, messages: messages);
    await settleCoordinatorTasks();
    expect(overlay.startCount, 1);
    expect(coordinator.url, 'http://localhost:8080');

    coordinator.applySettings(
      initial,
      previous: initial,
      messages: messages,
    );
    await settleCoordinatorTasks();
    expect(overlay.startCount, 1);
    expect(overlay.settingsCount, 2);

    final changed = initial.copyWith(overlayPort: 9090);
    coordinator.applySettings(
      changed,
      previous: initial,
      messages: messages,
    );
    await settleCoordinatorTasks();
    expect(overlay.startCount, 2);
    expect(coordinator.url, 'http://localhost:9090');
  });

  test('turning off during a slow stop cancels a queued start', () async {
    const off = SettingsModel(overlayEnabled: false);
    final on = off.copyWith(overlayEnabled: true);
    overlay.stopGate = Completer<void>();
    try {
      coordinator.applySettings(off, previous: null, messages: messages);
      await settleCoordinatorTasks();
      expect(overlay.stopCount, 1);
      coordinator.applySettings(on, previous: off, messages: messages);
      await settleCoordinatorTasks();
      expect(overlay.startCount, 0);
      coordinator.applySettings(off, previous: on, messages: messages);
    } finally {
      overlay.stopGate!.complete();
    }
    await settleCoordinatorTasks();
    expect(overlay.startCount, 0);
    expect(overlay.stopCount, 2);
    expect(coordinator.url, isNull);
  });

  test('publishes startup errors and never exposes a false URL', () async {
    overlay.startError = StateError('port occupied');
    final failed = coordinator.stateStream.firstWhere(
      (state) => state.phase == OverlayServerPhase.error,
    );
    await settleCoordinatorTasks();
    coordinator.applySettings(
      const SettingsModel(overlayEnabled: true, overlayPort: 8080),
      previous: null,
      messages: messages,
    );
    expect((await failed).error.toString(), contains('port occupied'));
    expect(coordinator.url, isNull);
  });

  test('disposes its server only once', () async {
    await coordinator.dispose();
    await coordinator.dispose();
    expect(overlay.disposed, isTrue);
  });

  test('uses the next free port when the configured one is busy', () async {
    overlay.busyPorts = {18080, 18081};
    final ready = coordinator.stateStream.firstWhere(
      (state) => state.phase == OverlayServerPhase.ready,
    );
    await settleCoordinatorTasks();
    coordinator.applySettings(
      const SettingsModel(overlayEnabled: true, overlayPort: 18080),
      previous: null,
      messages: messages,
    );

    final state = await ready;
    expect(state.port, 18082);
    expect(state.requestedPort, 18080);
    expect(coordinator.url, 'http://localhost:18082');
  });

  test('reports the configured port when it is free', () async {
    final ready = coordinator.stateStream.firstWhere(
      (state) => state.phase == OverlayServerPhase.ready,
    );
    await settleCoordinatorTasks();
    coordinator.applySettings(
      const SettingsModel(overlayEnabled: true, overlayPort: 18080),
      previous: null,
      messages: messages,
    );

    final state = await ready;
    expect(state.port, 18080);
    expect(state.requestedPort, isNull);
  });

  test('features a message only while the overlay runs', () async {
    final message = ChatMessage(
      platform: Platform.twitch,
      id: 'm1',
      author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
      items: const [MessageItem.text('hola')],
      timestamp: DateTime.utc(2026, 11, 15),
    );
    expect(coordinator.featureMessage(message).status,
        FeaturedMessageStatus.noReceiver);

    final ready = coordinator.stateStream.firstWhere(
      (state) => state.phase == OverlayServerPhase.ready,
    );
    await settleCoordinatorTasks();
    coordinator.applySettings(
      const SettingsModel(overlayEnabled: true),
      previous: null,
      messages: messages,
    );
    await ready;

    expect(
        coordinator.featureMessage(message).status, FeaturedMessageStatus.sent);
    expect(overlay.featured.single.id, 'm1');
    overlay.hasClients = false;
    expect(coordinator.featureMessage(message).status,
        FeaturedMessageStatus.noReceiver);
  });
}

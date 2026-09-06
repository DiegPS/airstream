import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
